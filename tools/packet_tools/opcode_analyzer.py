#!/usr/bin/env python3
"""
opcode_analyzer.py -- TrinityCore Opcode Dictionary + Packet Capture Analyzer

Parses Opcodes.h/cpp to build a complete opcode dictionary, then cross-references
with World_parsed.txt packet captures to find unhandled, unknown, and filtered
opcodes.  Optionally validates against WowPacketParser's opcode map.

Usage:
    python opcode_analyzer.py                              # auto-detect capture
    python opcode_analyzer.py World_parsed.txt             # explicit capture
    python opcode_analyzer.py --lookup TRANSMOG             # search dictionary
    python opcode_analyzer.py --lookup 0x3A017C             # lookup by hex
    python opcode_analyzer.py --dict-only                   # dump full dictionary
    python opcode_analyzer.py --filter HOUSING              # focus on HOUSING opcodes
    python opcode_analyzer.py --top 20                      # 20 most-seen opcodes
    python opcode_analyzer.py --json                        # structured JSON output
    python opcode_analyzer.py --diff old.txt new.txt        # compare two captures
    python opcode_analyzer.py --wpp-validate                # cross-check vs WPP
"""

import re
import sys
import os
import json
import argparse
from collections import defaultdict

DEFAULT_PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OPCODES_H_REL = "src/server/game/Server/Protocol/Opcodes.h"
OPCODES_CPP_REL = "src/server/game/Server/Protocol/Opcodes.cpp"
CACHE_FILE = ".opcode_cache.json"

# Where World_parsed.txt usually lives
PACKET_LOG_CANDIDATES = [
    "out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/PacketLog/World_parsed.txt",
    "out/build/x64-Debug/bin/Debug/PacketLog/World_parsed.txt",
    "out/build/x64-RelWithDebInfo/bin/PacketLog/World_parsed.txt",
    "out/build/x64-Debug/bin/PacketLog/World_parsed.txt",
]

# WPP opcode map locations (newest first)
WPP_OPCODE_CANDIDATES = [
    r"C:\Users\atayl\VoxCore\ExtTools\WowPacketParser\WowPacketParser\Enums\Version\V12_0_1_65818\Opcodes.cs",
    r"C:\Users\atayl\VoxCore\ExtTools\WowPacketParser\WowPacketParser\Enums\Version\V12_0_0_65390\Opcodes.cs",
]


# ---------------------------------------------------------------------------
# 1. Parse Opcodes.h -- build name -> hex value mapping
# ---------------------------------------------------------------------------

def parse_opcodes_h(filepath):
    """Parse OpcodeClient and OpcodeServer enums from Opcodes.h.

    Returns dict  { name(str): value(int) }
    """
    opcodes = {}
    current_enum = None
    enum_re = re.compile(r'^\s*(\w+)\s*=\s*(.+?),?\s*(?://.*)?$')

    with open(filepath, 'r', encoding='latin1') as f:
        for line in f:
            stripped = line.strip()

            if 'enum OpcodeClient' in stripped:
                current_enum = 'client'
                continue
            elif 'enum OpcodeServer' in stripped:
                current_enum = 'server'
                continue
            elif current_enum and stripped.startswith('};'):
                current_enum = None
                continue

            if not current_enum:
                continue
            if not stripped or stripped.startswith('//') or stripped.startswith('constexpr'):
                continue

            m = enum_re.match(stripped)
            if not m:
                continue

            name = m.group(1)
            expr = m.group(2).strip().rstrip(',')

            hm = re.fullmatch(r'0[xX]([0-9A-Fa-f]+)', expr)
            if hm:
                opcodes[name] = int(hm.group(1), 16)
                continue

            dm = re.fullmatch(r'(\d+)', expr)
            if dm:
                opcodes[name] = int(dm.group(1))
                continue

            em = re.fullmatch(r'(\w+)\s*\+\s*(\d+)', expr)
            if em:
                base, offset = em.group(1), int(em.group(2))
                if base in opcodes:
                    opcodes[name] = opcodes[base] + offset
                else:
                    print(f"  [warn] Cannot resolve {name} = {base} + {offset}",
                          file=sys.stderr)
                continue

            am = re.fullmatch(r'(\w+)', expr)
            if am:
                ref = am.group(1)
                if ref in opcodes:
                    opcodes[name] = opcodes[ref]
                elif ref == 'UNKNOWN_OPCODE':
                    pass
                else:
                    print(f"  [warn] Cannot resolve {name} = {ref}", file=sys.stderr)
                continue

    return opcodes


# ---------------------------------------------------------------------------
# 2. Parse Opcodes.cpp -- build name -> handler metadata
# ---------------------------------------------------------------------------

def parse_opcodes_cpp(filepath):
    """Returns dict  { name: { status, handler|connection, type } }"""
    handlers = {}

    client_re = re.compile(
        r'\s*DEFINE_HANDLER\(\s*(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*,\s*&WorldSession::(\w+)\s*\)')
    server_re = re.compile(
        r'\s*DEFINE_SERVER_OPCODE_HANDLER\(\s*(\w+)\s*,\s*(\w+)\s*,\s*(\w+)\s*\)')

    with open(filepath, 'r', encoding='latin1') as f:
        for line in f:
            m = client_re.match(line)
            if m:
                handlers[m.group(1)] = {
                    'status': m.group(2),
                    'processing': m.group(3),
                    'handler': m.group(4),
                    'type': 'client',
                }
                continue
            m = server_re.match(line)
            if m:
                handlers[m.group(1)] = {
                    'status': m.group(2),
                    'connection': m.group(3),
                    'type': 'server',
                }

    return handlers


# ---------------------------------------------------------------------------
# 3. Parse WPP opcode map (C# BiDictionary)
# ---------------------------------------------------------------------------

def parse_wpp_opcodes(filepath):
    """Parse WowPacketParser Opcodes.cs (C# BiDictionary<Opcode, int>).

    Returns dict  { name(str): hex_value(int) }
    """
    opcodes = {}
    entry_re = re.compile(
        r'\{\s*Opcode\.(\w+)\s*,\s*0x([0-9A-Fa-f]+)\s*\}')

    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            m = entry_re.search(line)
            if m:
                opcodes[m.group(1)] = int(m.group(2), 16)

    return opcodes


def find_wpp_opcode_file():
    """Auto-detect the most recent WPP opcode file."""
    for p in WPP_OPCODE_CANDIDATES:
        if os.path.exists(p):
            return p
    return None


# ---------------------------------------------------------------------------
# 4. Merge into hex -> info dictionary (with JSON cache)
# ---------------------------------------------------------------------------

def build_opcode_dict(project_root, use_cache=True):
    cache_path = os.path.join(project_root, CACHE_FILE)
    h_path = os.path.join(project_root, OPCODES_H_REL)
    cpp_path = os.path.join(project_root, OPCODES_CPP_REL)

    for p in (h_path, cpp_path):
        if not os.path.exists(p):
            print(f"[error] Required file not found: {p}", file=sys.stderr)
            sys.exit(1)

    if use_cache and os.path.exists(cache_path):
        cache_mt = os.path.getmtime(cache_path)
        if cache_mt > os.path.getmtime(h_path) and cache_mt > os.path.getmtime(cpp_path):
            with open(cache_path, 'r') as f:
                cached = json.load(f)
            result = {int(k): v for k, v in cached.items()}
            print(f"[cache] Loaded {len(result)} opcodes from cache", file=sys.stderr)
            return result

    print("[parse] Building opcode dictionary from source...", file=sys.stderr)
    name_to_hex = parse_opcodes_h(h_path)
    name_to_handler = parse_opcodes_cpp(cpp_path)

    hex_to_info = {}
    for name, val in name_to_hex.items():
        info = {'name': name}
        if name in name_to_handler:
            info.update(name_to_handler[name])
        else:
            info['status'] = 'NO_HANDLER_ENTRY'
            info['type'] = 'client' if name.startswith('CMSG_') else 'server'
        hex_to_info[val] = info

    for name in name_to_handler:
        if name not in name_to_hex:
            print(f"  [warn] {name} in Opcodes.cpp but missing from Opcodes.h",
                  file=sys.stderr)

    try:
        with open(cache_path, 'w') as f:
            json.dump({str(k): v for k, v in hex_to_info.items()}, f, separators=(',', ':'))
        print(f"[cache] Wrote {len(hex_to_info)} opcodes", file=sys.stderr)
    except OSError as e:
        print(f"  [warn] Cache write failed: {e}", file=sys.stderr)

    n_cmsg = sum(1 for v in hex_to_info.values() if v.get('type') == 'client')
    n_smsg = sum(1 for v in hex_to_info.values() if v.get('type') == 'server')
    print(f"[parse] {n_cmsg} CMSG + {n_smsg} SMSG = {len(hex_to_info)} total", file=sys.stderr)
    return hex_to_info


# ---------------------------------------------------------------------------
# 5. Stream-parse World_parsed.txt
# ---------------------------------------------------------------------------

def parse_packet_capture(filepath):
    """Stream through a (potentially huge) World_parsed.txt.

    Returns dict  { hex_val(int): stats_dict }
    """
    stats = defaultdict(lambda: {
        'direction': None,
        'count': 0,
        'min_size': None,
        'max_size': None,
        'conn_idx': set(),          # feature 5: ConnIdx tracking
        'first_time': None,
        'last_time': None,
        'first_hex_dump': None,
        'wpp_name': None,
    })

    header_re = re.compile(
        r'^(ClientToServer|ServerToClient):\s+'
        r'(\S+)\s+'
        r'\(0x([0-9A-Fa-f]+)\)\s+'
        r'Length:\s+(\d+)\s+'
        r'(?:.*?ConnIdx:\s+(\d+)\s+)?'     # optional ConnIdx capture
        r'.*?Time:\s+(\S+\s+\S+)')

    hex_line_re = re.compile(r'^\|\s+([0-9A-Fa-f ]{2,}?)\s*\|')
    OFFSET_HEADER = "00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F"

    current_opcode = None
    hex_lines = []
    line_count = 0
    is_first_hex_block = True

    file_size = os.path.getsize(filepath)
    print(f"[parse] Streaming {filepath} ({file_size / 1048576:.1f} MB)", file=sys.stderr)

    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line_count += 1
            if line_count % 1_000_000 == 0:
                print(f"  ...{line_count:,} lines", file=sys.stderr)

            m = header_re.match(line)
            if m:
                # Flush previous hex dump
                if current_opcode is not None and hex_lines and is_first_hex_block:
                    stats[current_opcode]['first_hex_dump'] = '\n'.join(hex_lines[:32])

                direction = m.group(1)
                name_or_dec = m.group(2)
                hex_val = int(m.group(3), 16)
                length = int(m.group(4))
                conn_idx = m.group(5)       # may be None
                timestamp = m.group(6)

                current_opcode = hex_val
                hex_lines = []

                entry = stats[hex_val]
                entry['direction'] = direction
                entry['count'] += 1
                if entry['min_size'] is None or length < entry['min_size']:
                    entry['min_size'] = length
                if entry['max_size'] is None or length > entry['max_size']:
                    entry['max_size'] = length
                if conn_idx is not None:
                    entry['conn_idx'].add(int(conn_idx))
                if entry['first_time'] is None:
                    entry['first_time'] = timestamp
                entry['last_time'] = timestamp

                if not name_or_dec.isdigit():
                    entry['wpp_name'] = name_or_dec

                is_first_hex_block = entry['first_hex_dump'] is None
                continue

            if current_opcode is not None and is_first_hex_block:
                hm = hex_line_re.match(line)
                if hm:
                    captured = hm.group(1).rstrip()
                    if captured != OFFSET_HEADER:
                        hex_lines.append(captured)

    # Flush last packet
    if current_opcode is not None and hex_lines and is_first_hex_block:
        stats[current_opcode]['first_hex_dump'] = '\n'.join(hex_lines[:32])

    # Convert sets to sorted lists for JSON serialization
    for s in stats.values():
        s['conn_idx'] = sorted(s['conn_idx'])

    print(f"[parse] {line_count:,} lines, {len(stats)} unique opcodes, "
          f"{sum(s['count'] for s in stats.values()):,} total packets", file=sys.stderr)
    return dict(stats)


# ---------------------------------------------------------------------------
# 6. Report generation
# ---------------------------------------------------------------------------

def _size_range(ps):
    lo, hi = ps.get('min_size'), ps.get('max_size')
    if lo is None:
        return "0 bytes"
    return f"{lo} bytes" if lo == hi else f"{lo}-{hi} bytes"


def _conn_str(ps):
    """Format ConnIdx as 'realm', 'instance', or 'realm+instance'."""
    ci = ps.get('conn_idx', [])
    if not ci:
        return ""
    names = {0: 'realm', 1: 'instance'}
    return ','.join(names.get(c, str(c)) for c in ci)


def print_report(opcode_dict, packet_stats, highlight_opcode=None,
                 unhandled_only=False, filter_keyword=None, top_n=None):
    # -- Section 1: unhandled client opcodes --------------------------------
    print("\n" + "=" * 100)
    print("  UNHANDLED CLIENT OPCODES  (sent by client, server ignores)")
    print("=" * 100)

    unhandled = []
    for hx, ps in sorted(packet_stats.items()):
        if ps['direction'] != 'ClientToServer':
            continue
        info = opcode_dict.get(hx)
        if info and info.get('status') == 'STATUS_UNHANDLED':
            unhandled.append((hx, info, ps))

    if unhandled:
        for hx, info, ps in unhandled:
            tag = "  <-- NEEDS HANDLER" if 'TRANSMOG' in info['name'] else ""
            conn = f"  [{_conn_str(ps)}]" if ps.get('conn_idx') else ""
            print(f"  0x{hx:06X}  {info['name']:<50s} {info['status']:<20s}"
                  f" sent {ps['count']}x ({_size_range(ps)}){conn}{tag}")
    else:
        print("  (none)")

    if unhandled_only:
        return

    # -- Section 2: unknown opcodes -----------------------------------------
    print("\n" + "=" * 100)
    print("  UNKNOWN OPCODES  (not in Opcodes.h at all)")
    print("=" * 100)

    unknown = [(hx, ps) for hx, ps in sorted(packet_stats.items()) if hx not in opcode_dict]

    if unknown:
        for hx, ps in unknown:
            wpp = f"  WPP:{ps['wpp_name']}" if ps['wpp_name'] else ""
            conn = f"  [{_conn_str(ps)}]" if ps.get('conn_idx') else ""
            print(f"  0x{hx:06X}  {ps['direction']:<18s} sent {ps['count']}x ({_size_range(ps)})"
                  f"  first: {ps['first_time']}  last: {ps['last_time']}{conn}{wpp}")
    else:
        print("  (none)")

    # -- Section 3: filtered opcodes (transmog by default) ------------------
    kw = filter_keyword or "TRANSMOG"
    kw_upper = kw.upper()

    print("\n" + "=" * 100)
    print(f"  ALL '{kw_upper}' OPCODES  (from Opcodes.h)")
    print("=" * 100)

    filtered = {h: i for h, i in opcode_dict.items() if kw_upper in i['name']}

    for hx, info in sorted(filtered.items()):
        ps = packet_stats.get(hx)
        seen = f"seen: {ps['count']}x" if ps else "not seen"

        if info.get('type') == 'server':
            note = "(server-sent)"
        else:
            note = ""

        flag = ""
        if info.get('status') == 'STATUS_UNHANDLED' and info.get('type') == 'client':
            flag = "  <-- NEEDS HANDLER"
        elif info.get('handler') == 'Handle_NULL' and info.get('type') == 'client':
            flag = "  <-- NULL HANDLER"

        conn = ""
        if ps and ps.get('conn_idx'):
            conn = f"  [{_conn_str(ps)}]"

        print(f"  0x{hx:06X}  {info['name']:<50s} {info.get('status','?'):<20s}"
              f" {seen:<15s} {note}{conn}{flag}")

    if not filtered:
        print("  (none)")

    # -- Section 3b: top N opcodes by frequency -----------------------------
    if top_n and top_n > 0:
        print("\n" + "=" * 100)
        print(f"  TOP {top_n} OPCODES BY PACKET COUNT")
        print("=" * 100)

        ranked = sorted(packet_stats.items(), key=lambda kv: kv[1]['count'], reverse=True)
        for i, (hx, ps) in enumerate(ranked[:top_n], 1):
            info = opcode_dict.get(hx)
            name = info['name'] if info else f"UNKNOWN_{hx:06X}"
            status = info.get('status', '?') if info else '?'
            conn = f"  [{_conn_str(ps)}]" if ps.get('conn_idx') else ""
            print(f"  {i:3d}. 0x{hx:06X}  {name:<50s} {ps['direction']:<18s}"
                  f" {ps['count']:>6,}x  ({_size_range(ps)}){conn}")

    # -- Section 4: highlighted opcode detail -------------------------------
    if highlight_opcode is not None:
        hx = highlight_opcode
        print("\n" + "=" * 100)
        print(f"  OPCODE 0x{hx:06X} DETAIL")
        print("=" * 100)

        info = opcode_dict.get(hx)
        ps = packet_stats.get(hx)

        if info:
            print(f"  Name:       {info['name']}")
            print(f"  Status:     {info.get('status', '?')}")
            print(f"  Type:       {info.get('type', '?')}")
            if 'handler' in info:
                print(f"  Handler:    WorldSession::{info['handler']}")
            if 'processing' in info:
                print(f"  Processing: {info['processing']}")
            if 'connection' in info:
                print(f"  Connection: {info['connection']}")
        else:
            print(f"  NOT FOUND in Opcodes.h")

        if ps:
            print(f"  Direction:  {ps['direction']}")
            print(f"  Times seen: {ps['count']}")
            print(f"  Sizes:      {_size_range(ps)}")
            if ps.get('conn_idx'):
                print(f"  ConnIdx:    {_conn_str(ps)}")
            print(f"  First:      {ps['first_time']}")
            print(f"  Last:       {ps['last_time']}")
            if ps['first_hex_dump']:
                print(f"  Hex dump (first occurrence):")
                for hl in ps['first_hex_dump'].split('\n'):
                    print(f"    | {hl}")
        else:
            print(f"  NOT SEEN in packet capture")

    # -- Section 5: summary ------------------------------------------------
    print("\n" + "=" * 100)
    print("  SUMMARY")
    print("=" * 100)

    total = sum(s['count'] for s in packet_stats.values())
    n_c2s = sum(1 for s in packet_stats.values() if s['direction'] == 'ClientToServer')
    n_s2c = sum(1 for s in packet_stats.values() if s['direction'] == 'ServerToClient')
    n_cmsg = sum(1 for v in opcode_dict.values() if v.get('type') == 'client')
    n_smsg = sum(1 for v in opcode_dict.values() if v.get('type') == 'server')

    print(f"  Packets in capture:         {total:,}")
    print(f"  Unique opcodes seen:        {len(packet_stats)}  ({n_c2s} C->S,  {n_s2c} S->C)")
    print(f"  Dictionary size:            {len(opcode_dict)}  ({n_cmsg} CMSG, {n_smsg} SMSG)")
    print(f"  Unknown opcodes:            {len(unknown)}")
    print(f"  Unhandled client opcodes:   {len(unhandled)}")


# ---------------------------------------------------------------------------
# 7. JSON output
# ---------------------------------------------------------------------------

def build_json_report(opcode_dict, packet_stats, highlight_opcode=None,
                      filter_keyword=None, top_n=None):
    """Build a structured dict for JSON output."""

    unhandled = []
    for hx, ps in sorted(packet_stats.items()):
        if ps['direction'] != 'ClientToServer':
            continue
        info = opcode_dict.get(hx)
        if info and info.get('status') == 'STATUS_UNHANDLED':
            unhandled.append({
                'opcode': f"0x{hx:06X}",
                'name': info['name'],
                'status': info['status'],
                'count': ps['count'],
                'sizes': _size_range(ps),
                'conn_idx': ps.get('conn_idx', []),
            })

    unknown = []
    for hx, ps in sorted(packet_stats.items()):
        if hx not in opcode_dict:
            unknown.append({
                'opcode': f"0x{hx:06X}",
                'direction': ps['direction'],
                'count': ps['count'],
                'sizes': _size_range(ps),
                'conn_idx': ps.get('conn_idx', []),
                'first_time': ps['first_time'],
                'last_time': ps['last_time'],
                'wpp_name': ps.get('wpp_name'),
            })

    kw = filter_keyword or "TRANSMOG"
    kw_upper = kw.upper()
    filtered = []
    for hx, info in sorted(opcode_dict.items()):
        if kw_upper not in info['name']:
            continue
        ps = packet_stats.get(hx)
        filtered.append({
            'opcode': f"0x{hx:06X}",
            'name': info['name'],
            'status': info.get('status', '?'),
            'type': info.get('type', '?'),
            'handler': info.get('handler'),
            'count': ps['count'] if ps else 0,
            'conn_idx': ps.get('conn_idx', []) if ps else [],
        })

    top_list = None
    if top_n and top_n > 0:
        ranked = sorted(packet_stats.items(), key=lambda kv: kv[1]['count'], reverse=True)
        top_list = []
        for hx, ps in ranked[:top_n]:
            info = opcode_dict.get(hx)
            top_list.append({
                'opcode': f"0x{hx:06X}",
                'name': info['name'] if info else None,
                'direction': ps['direction'],
                'count': ps['count'],
                'sizes': _size_range(ps),
                'conn_idx': ps.get('conn_idx', []),
            })

    detail = None
    if highlight_opcode is not None:
        hx = highlight_opcode
        info = opcode_dict.get(hx)
        ps = packet_stats.get(hx)
        detail = {
            'opcode': f"0x{hx:06X}",
            'name': info['name'] if info else None,
            'status': info.get('status') if info else None,
            'type': info.get('type') if info else None,
            'handler': info.get('handler') if info else None,
            'direction': ps['direction'] if ps else None,
            'count': ps['count'] if ps else 0,
            'sizes': _size_range(ps) if ps else None,
            'conn_idx': ps.get('conn_idx', []) if ps else [],
            'first_time': ps['first_time'] if ps else None,
            'last_time': ps['last_time'] if ps else None,
        }

    total = sum(s['count'] for s in packet_stats.values())

    report = {
        'unhandled_client_opcodes': unhandled,
        'unknown_opcodes': unknown,
        f'filtered_{kw.lower()}_opcodes': filtered,
        'highlight_detail': detail,
        'summary': {
            'total_packets': total,
            'unique_opcodes_seen': len(packet_stats),
            'unique_c2s': sum(1 for s in packet_stats.values() if s['direction'] == 'ClientToServer'),
            'unique_s2c': sum(1 for s in packet_stats.values() if s['direction'] == 'ServerToClient'),
            'dictionary_size': len(opcode_dict),
            'unknown_count': len(unknown),
            'unhandled_count': len(unhandled),
        },
    }
    if top_list is not None:
        report['top_opcodes'] = top_list

    return report


# ---------------------------------------------------------------------------
# 8. Diff mode -- compare two captures
# ---------------------------------------------------------------------------

def do_diff(opcode_dict, file_a, file_b):
    """Compare two packet captures and report differences."""
    print(f"[diff] Parsing A: {file_a}", file=sys.stderr)
    stats_a = parse_packet_capture(file_a)
    print(f"[diff] Parsing B: {file_b}", file=sys.stderr)
    stats_b = parse_packet_capture(file_b)

    opcodes_a = set(stats_a.keys())
    opcodes_b = set(stats_b.keys())

    only_a = sorted(opcodes_a - opcodes_b)
    only_b = sorted(opcodes_b - opcodes_a)
    common = sorted(opcodes_a & opcodes_b)

    def _name(hx):
        info = opcode_dict.get(hx)
        return info['name'] if info else f"UNKNOWN_{hx:06X}"

    def _status(hx):
        info = opcode_dict.get(hx)
        return info.get('status', '?') if info else '?'

    print("\n" + "=" * 100)
    print(f"  OPCODES ONLY IN A  ({os.path.basename(file_a)})")
    print("=" * 100)
    if only_a:
        for hx in only_a:
            ps = stats_a[hx]
            print(f"  0x{hx:06X}  {_name(hx):<50s} {ps['direction']:<18s}"
                  f" {ps['count']:>5,}x  ({_size_range(ps)})  {_status(hx)}")
    else:
        print("  (none)")

    print("\n" + "=" * 100)
    print(f"  OPCODES ONLY IN B  ({os.path.basename(file_b)})")
    print("=" * 100)
    if only_b:
        for hx in only_b:
            ps = stats_b[hx]
            print(f"  0x{hx:06X}  {_name(hx):<50s} {ps['direction']:<18s}"
                  f" {ps['count']:>5,}x  ({_size_range(ps)})  {_status(hx)}")
    else:
        print("  (none)")

    print("\n" + "=" * 100)
    print("  COUNT DIFFERENCES  (common opcodes, sorted by biggest delta)")
    print("=" * 100)

    diffs = []
    for hx in common:
        ca, cb = stats_a[hx]['count'], stats_b[hx]['count']
        if ca != cb:
            diffs.append((hx, ca, cb, abs(ca - cb)))
    diffs.sort(key=lambda x: x[3], reverse=True)

    if diffs:
        for hx, ca, cb, delta in diffs[:30]:
            arrow = "+" if cb > ca else "-"
            print(f"  0x{hx:06X}  {_name(hx):<50s}  A:{ca:>5,}x  B:{cb:>5,}x  ({arrow}{delta})")
    else:
        print("  (all common opcodes have identical counts)")

    print("\n" + "=" * 100)
    print("  DIFF SUMMARY")
    print("=" * 100)
    total_a = sum(s['count'] for s in stats_a.values())
    total_b = sum(s['count'] for s in stats_b.values())
    print(f"  A: {len(stats_a)} unique opcodes, {total_a:,} packets  ({os.path.basename(file_a)})")
    print(f"  B: {len(stats_b)} unique opcodes, {total_b:,} packets  ({os.path.basename(file_b)})")
    print(f"  Only in A: {len(only_a)}   Only in B: {len(only_b)}   Common: {len(common)}")
    print(f"  Count diffs: {len(diffs)} opcodes differ in frequency")


# ---------------------------------------------------------------------------
# 9. WPP validation
# ---------------------------------------------------------------------------

def do_wpp_validate(opcode_dict, wpp_file):
    """Cross-reference TrinityCore opcodes with WPP opcode map."""
    print(f"[wpp] Parsing {wpp_file}", file=sys.stderr)
    wpp_opcodes = parse_wpp_opcodes(wpp_file)
    print(f"[wpp] {len(wpp_opcodes)} opcodes in WPP map", file=sys.stderr)

    # Build TC name->hex for comparison
    tc_by_name = {}
    for hx, info in opcode_dict.items():
        tc_by_name[info['name']] = hx

    only_tc = sorted(set(tc_by_name.keys()) - set(wpp_opcodes.keys()))
    only_wpp = sorted(set(wpp_opcodes.keys()) - set(tc_by_name.keys()))

    mismatched = []
    for name in sorted(set(tc_by_name.keys()) & set(wpp_opcodes.keys())):
        tc_val = tc_by_name[name]
        wpp_val = wpp_opcodes[name]
        if tc_val != wpp_val:
            mismatched.append((name, tc_val, wpp_val))

    print("\n" + "=" * 100)
    print("  HEX VALUE MISMATCHES  (TC vs WPP)")
    print("=" * 100)
    if mismatched:
        for name, tc_val, wpp_val in mismatched:
            print(f"  {name:<55s}  TC: 0x{tc_val:06X}  WPP: 0x{wpp_val:06X}")
    else:
        print("  (all matching -- hex values are identical)")

    print("\n" + "=" * 100)
    print(f"  OPCODES ONLY IN TRINITYCORE  ({len(only_tc)})")
    print("=" * 100)
    if only_tc:
        for name in only_tc[:50]:
            hx = tc_by_name[name]
            info = opcode_dict[hx]
            print(f"  0x{hx:06X}  {name:<55s} {info.get('status', '?')}")
        if len(only_tc) > 50:
            print(f"  ... and {len(only_tc) - 50} more")
    else:
        print("  (none)")

    print("\n" + "=" * 100)
    print(f"  OPCODES ONLY IN WPP  ({len(only_wpp)})")
    print("=" * 100)
    if only_wpp:
        for name in only_wpp[:50]:
            hx = wpp_opcodes[name]
            print(f"  0x{hx:06X}  {name}")
        if len(only_wpp) > 50:
            print(f"  ... and {len(only_wpp) - 50} more")
    else:
        print("  (none)")

    print("\n" + "=" * 100)
    print("  WPP VALIDATION SUMMARY")
    print("=" * 100)
    common = set(tc_by_name.keys()) & set(wpp_opcodes.keys())
    print(f"  TrinityCore opcodes:  {len(tc_by_name)}")
    print(f"  WPP opcodes:          {len(wpp_opcodes)}")
    print(f"  Common:               {len(common)}")
    print(f"  Hex mismatches:       {len(mismatched)}")
    print(f"  Only in TC:           {len(only_tc)}")
    print(f"  Only in WPP:          {len(only_wpp)}")
    print(f"  WPP file:             {wpp_file}")


# ---------------------------------------------------------------------------
# 10. Standalone lookup/dump helpers
# ---------------------------------------------------------------------------

def do_lookup(opcode_dict, query):
    """Look up by hex value, decimal value, or name substring."""
    q = query.strip()
    results = []

    if q.lower().startswith('0x'):
        try:
            val = int(q, 16)
        except ValueError:
            pass
        else:
            info = opcode_dict.get(val)
            if info:
                results.append((val, info))
            else:
                print(f"0x{val:06X}  not found in dictionary")
                return

    if not results and q.isdigit():
        val = int(q)
        info = opcode_dict.get(val)
        if info:
            results.append((val, info))

    if not results:
        upper = q.upper()
        results = [(h, i) for h, i in opcode_dict.items() if upper in i['name']]

    if not results:
        try:
            val = int(q, 16)
        except ValueError:
            pass
        else:
            info = opcode_dict.get(val)
            if info:
                results.append((val, info))

    if results:
        for hx, info in sorted(results):
            handler = info.get('handler', info.get('connection', 'N/A'))
            print(f"  0x{hx:06X}  {info['name']:<52s} {info.get('status','?'):<20s} {handler}")
    else:
        print(f"  No matches for '{query}'")


def do_dict_dump(opcode_dict, filter_type=None):
    for hx, info in sorted(opcode_dict.items()):
        if filter_type and info.get('type') != filter_type:
            continue
        handler = info.get('handler', info.get('connection', ''))
        print(f"0x{hx:06X}  {info['name']:<55s} {info.get('status','?'):<20s} {handler}")


# ---------------------------------------------------------------------------
# 11. Resolution helpers
# ---------------------------------------------------------------------------

def _resolve_opcode(text, opcode_dict):
    """Resolve user-provided opcode string to int hex value."""
    t = text.strip()

    if t.lower().startswith('0x'):
        try:
            return int(t, 16)
        except ValueError:
            print(f"[warn] '{t}' looks like hex but won't parse", file=sys.stderr)
            return None

    upper = t.upper()
    for hx, info in opcode_dict.items():
        if info['name'] == upper:
            return hx

    matches = sorted([(h, i) for h, i in opcode_dict.items() if upper in i['name']])
    if len(matches) == 1:
        return matches[0][0]
    elif matches:
        print(f"[warn] '{text}' matched {len(matches)} opcodes, "
              f"using: {matches[0][1]['name']}", file=sys.stderr)
        return matches[0][0]

    try:
        return int(t, 16)
    except ValueError:
        print(f"[warn] Cannot resolve '{text}' to any opcode", file=sys.stderr)
        return None


def find_packet_file(root):
    best = None
    best_mt = 0
    for rel in PACKET_LOG_CANDIDATES:
        p = os.path.join(root, rel)
        if os.path.exists(p):
            mt = os.path.getmtime(p)
            if mt > best_mt:
                best, best_mt = p, mt
    return best


# ---------------------------------------------------------------------------
# 12. Main
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(
        description="TrinityCore opcode dictionary + packet capture analyzer")

    # Positional
    ap.add_argument('packet_file', nargs='?',
                    help='World_parsed.txt  (auto-detected if omitted)')

    # Dictionary options
    ap.add_argument('--root', default=DEFAULT_PROJECT_ROOT,
                    help='Project root directory')
    ap.add_argument('--no-cache', action='store_true',
                    help='Rebuild opcode dictionary from source')
    ap.add_argument('--dict-only', action='store_true',
                    help='Dump the opcode dictionary and exit')
    ap.add_argument('--cmsg-only', action='store_true',
                    help='With --dict-only, show only client opcodes')
    ap.add_argument('--smsg-only', action='store_true',
                    help='With --dict-only, show only server opcodes')
    ap.add_argument('--lookup', metavar='QUERY',
                    help='Look up by hex value or name substring')

    # Report options
    ap.add_argument('--highlight', default='0x3A017C',
                    help='Opcode to detail (hex or name, default 0x3A017C)')
    ap.add_argument('--unhandled-only', action='store_true',
                    help='Only show unhandled client opcodes')
    ap.add_argument('--filter', metavar='KEYWORD', default=None,
                    help='Keyword to filter opcode section (default: TRANSMOG)')
    ap.add_argument('--top', type=int, metavar='N', default=None,
                    help='Show top N opcodes by packet count')
    ap.add_argument('--json', action='store_true',
                    help='Output structured JSON instead of text')

    # Diff mode
    ap.add_argument('--diff', nargs=2, metavar=('OLD', 'NEW'),
                    help='Compare two packet captures')

    # WPP validation
    ap.add_argument('--wpp-validate', action='store_true',
                    help='Cross-validate opcodes against WowPacketParser')
    ap.add_argument('--wpp-file', metavar='PATH', default=None,
                    help='Path to WPP Opcodes.cs (auto-detected if omitted)')

    args = ap.parse_args()

    # Build dictionary
    opcode_dict = build_opcode_dict(args.root, use_cache=not args.no_cache)

    # --lookup
    if args.lookup:
        do_lookup(opcode_dict, args.lookup)
        return

    # --dict-only
    if args.dict_only:
        ft = 'client' if args.cmsg_only else ('server' if args.smsg_only else None)
        do_dict_dump(opcode_dict, filter_type=ft)
        return

    # --wpp-validate
    if args.wpp_validate:
        wpp = args.wpp_file or find_wpp_opcode_file()
        if not wpp:
            ap.error("No WPP Opcodes.cs found. Pass --wpp-file PATH.")
        if not os.path.exists(wpp):
            ap.error(f"WPP file not found: {wpp}")
        do_wpp_validate(opcode_dict, wpp)
        return

    # --diff
    if args.diff:
        for f in args.diff:
            if not os.path.exists(f):
                ap.error(f"File not found: {f}")
        do_diff(opcode_dict, args.diff[0], args.diff[1])
        return

    # Full analysis mode
    pkt = args.packet_file
    if not pkt:
        pkt = find_packet_file(args.root)
        if pkt:
            print(f"[auto] {pkt}", file=sys.stderr)
        else:
            ap.error("No World_parsed.txt found. Pass it as argument or place in PacketLog/.")

    if not os.path.exists(pkt):
        print(f"[error] File not found: {pkt}", file=sys.stderr)
        sys.exit(1)

    highlight = _resolve_opcode(args.highlight, opcode_dict) if args.highlight else None

    packet_stats = parse_packet_capture(pkt)

    if args.json:
        report = build_json_report(opcode_dict, packet_stats,
                                   highlight_opcode=highlight,
                                   filter_keyword=args.filter,
                                   top_n=args.top)
        json.dump(report, sys.stdout, indent=2)
        print()
    else:
        print_report(opcode_dict, packet_stats, highlight_opcode=highlight,
                     unhandled_only=args.unhandled_only,
                     filter_keyword=args.filter,
                     top_n=args.top)


if __name__ == '__main__':
    main()

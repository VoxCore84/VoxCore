#!/usr/bin/env python3
"""Extract all transmog-related content from WPP packet log output files.

Produces a single output file with sections:
  1. Transmog Protocol Packets (CMSG_TRANSMOG*/SMSG_TRANSMOG*)
  2. TransmogBridge Addon Messages (TMOG_LOG, TMOG_BRIDGE, TSPY_LOG)
  3. Transmog-related UPDATE_OBJECT fields (ViewedOutfit, TransmogrifyDisabledSlotMask)
  4. Hotfix SQL tables (item_modified_appearance, transmog_illusion, transmog_set, etc.)
  5. Other SQL file mentions of transmog
  6. Errors file transmog entries

Usage:
  python3 extract_transmog_packets.py                          # Use default PacketLog dir
  python3 extract_transmog_packets.py --pkt-dir /path/to/dir   # Use custom dir
"""

import argparse
import re
import sys
from pathlib import Path
from collections import defaultdict

# --- Default config ---
DEFAULT_PKT_DIR = Path(r"C:\Dev\RoleplayCore\out\build\x64-RelWithDebInfo\bin\RelWithDebInfo\PacketLog")

# Patterns
PACKET_HEADER_RE = re.compile(r'^(ClientToServer|ServerToClient): (\S+)')
TRANSMOG_OPCODE_RE = re.compile(r'CMSG_TRANSMOG|SMSG_TRANSMOG|CMSG_TRANSMOGRIFY|SMSG_TRANSMOGRIFY')
ADDON_PREFIX_RE = re.compile(r'Prefix: (TMOG_LOG|TMOG_BRIDGE|TSPY_LOG)')
TRANSMOG_FIELD_RE = re.compile(r'(ViewedOutfit|TransmogrifyDisabledSlotMask|TransmogrifyDisabledSlot)')

# Hotfix SQL tables we care about
HOTFIX_TABLES = [
    'item_modified_appearance',
    'item_modified_appearance_extra',
    'item_appearance',
    'transmog_illusion',
    'transmog_set',
    'transmog_set_item',
    'transmog_set_group',
    'transmog_set_member',
]


def process_parsed_file(filepath):
    """Process World_parsed.txt via streaming — one packet block at a time."""
    transmog_packets = []
    addon_messages = []
    field_updates = []

    size_mb = filepath.stat().st_size / 1024 / 1024
    print(f"  Reading {filepath.name} ({size_mb:.1f} MB)...")

    current_block = []
    current_opcode = None

    def flush_block():
        nonlocal current_block, current_opcode
        if not current_block or not current_opcode:
            current_block = []
            current_opcode = None
            return

        if TRANSMOG_OPCODE_RE.search(current_opcode):
            transmog_packets.append(current_block)
        elif 'CMSG_CHAT_ADDON_MESSAGE' in current_opcode:
            block_text = ''.join(current_block)
            if ADDON_PREFIX_RE.search(block_text):
                addon_messages.append(current_block)
        elif 'SMSG_UPDATE_OBJECT' in current_opcode:
            if any(TRANSMOG_FIELD_RE.search(l) for l in current_block):
                field_updates.append(current_block)

        current_block = []
        current_opcode = None

    line_count = 0
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line_count += 1
            header_match = PACKET_HEADER_RE.match(line)
            if header_match:
                flush_block()
                current_opcode = header_match.group(2)
                current_block = [line]
            elif current_block:
                current_block.append(line)

    flush_block()

    print(f"  {line_count:,} lines scanned.")
    return transmog_packets, addon_messages, field_updates


def process_hotfixes_sql(filepath):
    """Extract transmog-related table INSERTs from hotfixes SQL."""
    sections = defaultdict(list)

    if not filepath.exists():
        print(f"  {filepath.name} not found — skipping.")
        return sections

    size_mb = filepath.stat().st_size / 1024 / 1024
    print(f"  Reading {filepath.name} ({size_mb:.1f} MB)...")

    current_table = None
    in_transmog_block = False

    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        for line in f:
            line_lower = line.lower()

            # Detect DELETE/INSERT for transmog tables
            for table in HOTFIX_TABLES:
                if f'`{table}`' in line_lower:
                    current_table = table
                    in_transmog_block = True
                    break

            if in_transmog_block:
                sections[current_table].append(line)
                # End of INSERT block (line ends with semicolon not inside values)
                if line.rstrip().endswith(';') and not line.strip().startswith('DELETE'):
                    in_transmog_block = False
                    current_table = None

    return sections


def process_sql_file(filepath):
    """Extract any transmog-related lines from a SQL file."""
    results = []
    if not filepath.exists():
        return results

    print(f"  Reading {filepath.name}...")
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        for line_num, line in enumerate(f, 1):
            if re.search(r'transmog|transmogrif|ViewedOutfit|ItemModifiedAppearance', line, re.IGNORECASE):
                results.append((line_num, line.rstrip()))
    return results


def process_errors_file(filepath):
    """Extract transmog-related error packets."""
    results = []
    if not filepath.exists():
        return results

    print(f"  Reading {filepath.name}...")
    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        for line_num, line in enumerate(f, 1):
            if re.search(r'transmog|transmogrif|TRANSMOG', line, re.IGNORECASE):
                results.append((line_num, line.rstrip()))
    return results


def find_sql_files(pkt_dir):
    """Dynamically find WPP-generated SQL files in the PacketLog directory."""
    hotfix_sqls = sorted(pkt_dir.glob("*_World.pkt*hotfixes.sql"))
    wpp_sqls = sorted(pkt_dir.glob("*_World.pkt*wpp.sql"))
    world_sqls = sorted(pkt_dir.glob("*_World.pkt*world.sql"))

    # Use the most recent match (last after sort), or a nonexistent placeholder
    return (
        hotfix_sqls[-1] if hotfix_sqls else pkt_dir / "NO_HOTFIXES.sql",
        wpp_sqls[-1] if wpp_sqls else pkt_dir / "NO_WPP.sql",
        world_sqls[-1] if world_sqls else pkt_dir / "NO_WORLD.sql",
    )


def write_output(output_path, pkt_dir, transmog_packets, addon_messages, field_updates,
                 hotfix_sections, wpp_lines, world_lines, error_lines):
    """Write all extracted content to a single output file."""
    total_items = 0

    with open(output_path, 'w', encoding='utf-8') as out:
        out.write("=" * 100 + "\n")
        out.write("  TRANSMOG PACKET EXTRACT\n")
        out.write(f"  Generated from WPP output files in: {pkt_dir}\n")
        out.write("=" * 100 + "\n\n")

        # --- Section 1: Transmog Protocol Packets ---
        out.write("=" * 100 + "\n")
        out.write(f"  SECTION 1: TRANSMOG PROTOCOL PACKETS ({len(transmog_packets)} packets)\n")
        out.write("  CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS, SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED, etc.\n")
        out.write("=" * 100 + "\n\n")
        for block in transmog_packets:
            for line in block:
                out.write(line if line.endswith('\n') else line + '\n')
            out.write('\n')
        total_items += len(transmog_packets)

        # --- Section 2: TransmogBridge Addon Messages ---
        out.write("=" * 100 + "\n")
        out.write(f"  SECTION 2: TRANSMOGBRIDGE ADDON MESSAGES ({len(addon_messages)} messages)\n")
        out.write("  TMOG_LOG, TMOG_BRIDGE, TSPY_LOG diagnostic addon messages\n")
        out.write("=" * 100 + "\n\n")
        for block in addon_messages:
            # Extract just the useful fields (skip the NullReferenceException noise)
            header = block[0].rstrip()
            prefix_line = ""
            text_line = ""
            for line in block:
                if 'Prefix:' in line:
                    prefix_line = line.strip()
                if 'Text:' in line:
                    text_line = line.strip()
            # Write compact form
            out.write(f"{header}\n")
            if prefix_line:
                out.write(f"  {prefix_line}\n")
            if text_line:
                out.write(f"  {text_line}\n")
            out.write('\n')
        total_items += len(addon_messages)

        # --- Section 3: UPDATE_OBJECT with Transmog Fields ---
        out.write("=" * 100 + "\n")
        out.write(f"  SECTION 3: UPDATE_OBJECT WITH TRANSMOG FIELDS ({len(field_updates)} packets)\n")
        out.write("  ViewedOutfit, TransmogrifyDisabledSlotMask from SMSG_UPDATE_OBJECT\n")
        out.write("=" * 100 + "\n\n")
        for block in field_updates:
            for line in block:
                out.write(line if line.endswith('\n') else line + '\n')
            out.write('\n')
        total_items += len(field_updates)

        # --- Section 4: Hotfix SQL Tables ---
        out.write("=" * 100 + "\n")
        out.write(f"  SECTION 4: HOTFIX SQL TABLES ({len(hotfix_sections)} tables)\n")
        out.write("  item_modified_appearance, transmog_illusion, transmog_set, etc.\n")
        out.write("=" * 100 + "\n\n")
        if hotfix_sections:
            for table_name, lines in sorted(hotfix_sections.items()):
                row_count = sum(1 for l in lines if l.strip().startswith('('))
                out.write(f"--- {table_name} ({row_count} rows, {len(lines)} SQL lines) ---\n")
                if row_count > 50:
                    # Write the DELETE + INSERT header
                    for line in lines:
                        if line.strip().startswith('('):
                            break
                        out.write(line)
                    data_rows = [l for l in lines if l.strip().startswith('(')]
                    out.write(f"-- First 10 of {row_count} rows:\n")
                    for row in data_rows[:10]:
                        out.write(row)
                    omitted = max(0, row_count - 20)
                    if omitted > 0:
                        out.write(f"-- ... ({omitted} rows omitted) ...\n")
                    out.write(f"-- Last 10 rows:\n")
                    for row in data_rows[-10:]:
                        out.write(row)
                    out.write('\n')
                else:
                    for line in lines:
                        out.write(line)
                    out.write('\n')
            total_items += sum(len(v) for v in hotfix_sections.values())
        else:
            out.write("  (no hotfix SQL files found or no transmog tables present)\n\n")

        # --- Section 5: WPP/World SQL Mentions ---
        out.write("=" * 100 + "\n")
        out.write(f"  SECTION 5: OTHER SQL FILE MENTIONS\n")
        out.write("=" * 100 + "\n\n")
        if wpp_lines:
            out.write(f"--- From _wpp.sql ({len(wpp_lines)} lines) ---\n")
            for line_num, line in wpp_lines:
                out.write(f"  L{line_num}: {line}\n")
            out.write('\n')
        if world_lines:
            out.write(f"--- From _world.sql ({len(world_lines)} lines) ---\n")
            for line_num, line in world_lines:
                out.write(f"  L{line_num}: {line}\n")
            out.write('\n')
        if not wpp_lines and not world_lines:
            out.write("  (no transmog-related content found)\n\n")

        # --- Section 6: Errors ---
        out.write("=" * 100 + "\n")
        out.write(f"  SECTION 6: ERRORS ({len(error_lines)} lines)\n")
        out.write("=" * 100 + "\n\n")
        if error_lines:
            for line_num, line in error_lines:
                out.write(f"  L{line_num}: {line}\n")
        else:
            out.write("  (no transmog-related errors found)\n")
        out.write('\n')

        # --- Summary ---
        out.write("=" * 100 + "\n")
        out.write("  SUMMARY\n")
        out.write("=" * 100 + "\n")
        out.write(f"  Transmog protocol packets:     {len(transmog_packets)}\n")
        out.write(f"  TransmogBridge addon messages:  {len(addon_messages)}\n")
        out.write(f"  UPDATE_OBJECT with transmog:    {len(field_updates)}\n")
        out.write(f"  Hotfix SQL tables:              {len(hotfix_sections)} tables\n")
        for table_name, lines in sorted(hotfix_sections.items()):
            row_count = sum(1 for l in lines if l.strip().startswith('('))
            out.write(f"    - {table_name}: {row_count} rows\n")
        out.write(f"  WPP SQL mentions:               {len(wpp_lines)}\n")
        out.write(f"  World SQL mentions:             {len(world_lines)}\n")
        out.write(f"  Error lines:                    {len(error_lines)}\n")

    return total_items


def main():
    parser = argparse.ArgumentParser(description="Extract transmog-related content from WPP output")
    parser.add_argument('--pkt-dir', type=Path, default=DEFAULT_PKT_DIR,
                        help='PacketLog directory containing World_parsed.txt')
    args = parser.parse_args()

    pkt_dir = args.pkt_dir
    parsed_file = pkt_dir / "World_parsed.txt"
    errors_file = pkt_dir / "World_errors.txt"
    output_file = pkt_dir / "transmog_extract.txt"

    print("Transmog Packet Extractor")
    print("=" * 50)
    print(f"  PacketLog dir: {pkt_dir}")

    if not parsed_file.exists():
        print(f"\n  ERROR: {parsed_file} not found.")
        sys.exit(1)

    # Discover SQL files dynamically
    hotfixes_sql, wpp_sql, world_sql = find_sql_files(pkt_dir)

    # Process all files
    print("\n[1/5] Processing parsed packet log...")
    transmog_packets, addon_messages, field_updates = process_parsed_file(parsed_file)

    print(f"  Found: {len(transmog_packets)} transmog packets, "
          f"{len(addon_messages)} addon messages, "
          f"{len(field_updates)} update objects")

    print("\n[2/5] Processing hotfixes SQL...")
    hotfix_sections = process_hotfixes_sql(hotfixes_sql)
    if hotfix_sections:
        for table, lines in sorted(hotfix_sections.items()):
            row_count = sum(1 for l in lines if l.strip().startswith('('))
            print(f"  {table}: {row_count} rows")
    else:
        print("  (no hotfix SQL found)")

    print("\n[3/5] Processing WPP SQL...")
    wpp_lines = process_sql_file(wpp_sql)
    print(f"  Found: {len(wpp_lines)} lines")

    print("\n[4/5] Processing world SQL...")
    world_lines = process_sql_file(world_sql)
    print(f"  Found: {len(world_lines)} lines")

    print("\n[5/5] Processing errors file...")
    error_lines = process_errors_file(errors_file)
    print(f"  Found: {len(error_lines)} lines")

    # Write output
    print(f"\nWriting output to {output_file}...")
    write_output(output_file, pkt_dir, transmog_packets, addon_messages, field_updates,
                 hotfix_sections, wpp_lines, world_lines, error_lines)

    size_mb = output_file.stat().st_size / 1024 / 1024
    print(f"\nDone! Output: {output_file} ({size_mb:.1f} MB)")


if __name__ == '__main__':
    main()

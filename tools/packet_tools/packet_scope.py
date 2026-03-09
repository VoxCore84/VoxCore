#!/usr/bin/env python3
"""PacketScope — WPP packet log analyzer with transmog-specific decoding.

Processes WowPacketParser (WPP) output files and produces a structured report:
  1.  Transmog Protocol Packets (CMSG_TRANSMOG*/SMSG_TRANSMOG*)
  1b. Decoded Transmog Protocol (structured decode of outfit packets)
  2.  TransmogBridge Addon Messages (TMOG_LOG, TMOG_BRIDGE, TSPY_LOG)
  3.  Transmog-related UPDATE_OBJECT fields (ViewedOutfit, TransmogrifyDisabledSlotMask)
  4.  Hotfix SQL tables (item_modified_appearance, transmog_illusion, transmog_set, etc.)
  5.  Other SQL file mentions of transmog
  6.  Errors file transmog entries

Usage:
  python3 packet_scope.py                          # Use default PacketLog dir
  python3 packet_scope.py --pkt-dir /path/to/dir   # Use custom dir
"""

import argparse
import re
import struct
import sys
from pathlib import Path
from collections import defaultdict

# --- Default config ---
DEFAULT_PKT_DIR = Path(r"C:\Users\atayl\VoxCore\out\build\x64-RelWithDebInfo\bin\RelWithDebInfo\PacketLog")

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

# --- Display Type mapping (from TransmogrificationPackets.cpp DisplayTypeToEquipSlot) ---
DISPLAY_TYPE_TO_SLOT = {
    0:  ('Head',       'EQUIPMENT_SLOT_HEAD'),
    1:  ('Shoulder',   'EQUIPMENT_SLOT_SHOULDERS'),
    2:  ('Shirt',      'EQUIPMENT_SLOT_BODY'),
    3:  ('Chest',      'EQUIPMENT_SLOT_CHEST'),
    4:  ('Waist',      'EQUIPMENT_SLOT_WAIST'),
    5:  ('Legs',       'EQUIPMENT_SLOT_LEGS'),
    6:  ('Feet',       'EQUIPMENT_SLOT_FEET'),
    7:  ('Wrists',     'EQUIPMENT_SLOT_WRISTS'),
    8:  ('Hands',      'EQUIPMENT_SLOT_HANDS'),
    9:  ('Back',       'EQUIPMENT_SLOT_BACK'),
    10: ('Tabard',     'EQUIPMENT_SLOT_TABARD'),
    11: ('MainHand',   'EQUIPMENT_SLOT_MAINHAND'),
    12: ('Ranged',     'EQUIPMENT_SLOT_MAINHAND'),
    13: ('Shield',     'EQUIPMENT_SLOT_OFFHAND'),
    15: ('OffHand',    'EQUIPMENT_SLOT_OFFHAND'),
}

# WPP header regex — captures direction, opcode name, hex opcode, length, optional ConnIdx, timestamp
WPP_HEADER_FULL_RE = re.compile(
    r'^(ClientToServer|ServerToClient):\s+'
    r'(\S+)\s+'
    r'\(0x([0-9A-Fa-f]+)\)\s+'
    r'Length:\s+(\d+)'
    r'(?:\s+ConnIdx:\s+(\d+))?'
    r'(?:\s+Time:\s+(.+))?'
)

# WPP hex dump line: | XX XX XX ... | (16 bytes per line)
WPP_HEX_LINE_RE = re.compile(r'^\|\s+((?:[0-9A-Fa-f]{2}\s*)+)\s*\|')

# WPP structured field lines
WPP_FIELD_RE = re.compile(r'^\s*(\S+?):\s+(.+)')
WPP_ARRAY_FIELD_RE = re.compile(r'^(\w+)\[(\d+)\]\.(\w+)$')


# ---------------------------------------------------------------------------
# Decoded packet data classes
# ---------------------------------------------------------------------------

class DecodedSlotEntry:
    """One decoded 16-byte slot entry from CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS or _NEW."""
    __slots__ = ('ordinal', 'option', 'imaid', 'display_type', 'raw_hex')

    def __init__(self, ordinal=0, option=0, imaid=0, display_type=0, raw_hex=''):
        self.ordinal = ordinal
        self.option = option
        self.imaid = imaid
        self.display_type = display_type
        self.raw_hex = raw_hex

    @property
    def slot_name(self):
        if self.imaid == 0 and self.display_type == 0:
            return '(empty)'
        info = DISPLAY_TYPE_TO_SLOT.get(self.display_type)
        return info[0] if info else f'DT={self.display_type}'

    @property
    def is_anomaly(self):
        """IMAID=0 but DisplayType != 0 is an anomaly (suspicious empty slot with routing data)."""
        return self.imaid == 0 and self.display_type != 0


class DecodedSituationEntry:
    """One decoded situation entry from CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS."""
    __slots__ = ('situation_id', 'spec_id', 'loadout_id', 'equipment_set_id')

    def __init__(self, situation_id=0, spec_id=0, loadout_id=0, equipment_set_id=0):
        self.situation_id = situation_id
        self.spec_id = spec_id
        self.loadout_id = loadout_id
        self.equipment_set_id = equipment_set_id


class DecodedPacket:
    """A decoded transmog packet with structured data."""
    __slots__ = ('direction', 'opcode_name', 'opcode_hex', 'length', 'conn_idx',
                 'timestamp', 'set_id', 'slot_count', 'slots', 'situations',
                 'anomalies', 'raw_fields', 'decode_method', 'packet_index',
                 'guid', 'ignore_mask_changed')

    def __init__(self):
        self.direction = ''
        self.opcode_name = ''
        self.opcode_hex = ''
        self.length = 0
        self.conn_idx = None
        self.timestamp = ''
        self.set_id = None
        self.slot_count = 0
        self.slots = []
        self.situations = []
        self.anomalies = []
        self.raw_fields = {}
        self.decode_method = 'unknown'
        self.packet_index = 0
        self.guid = None
        self.ignore_mask_changed = None


# ---------------------------------------------------------------------------
# Packet block decoder
# ---------------------------------------------------------------------------

def _parse_hex_dump(block_lines):
    """Extract raw bytes from WPP hex dump lines in a packet block."""
    raw_bytes = bytearray()
    for line in block_lines:
        m = WPP_HEX_LINE_RE.match(line)
        if m:
            hex_str = m.group(1).strip()
            for byte_str in hex_str.split():
                if len(byte_str) == 2:
                    try:
                        raw_bytes.append(int(byte_str, 16))
                    except ValueError:
                        pass
    return bytes(raw_bytes)


def _parse_structured_fields(block_lines):
    """Extract key: value pairs and array[idx].field patterns from WPP text output."""
    fields = {}
    arrays = defaultdict(lambda: defaultdict(dict))  # arrays[arrayName][idx][fieldName] = value

    for line in block_lines[1:]:  # skip header line
        m = WPP_FIELD_RE.match(line)
        if not m:
            continue
        key, value = m.group(1), m.group(2).strip()

        # Check if it's an array field: Appearances[0].ItemModifiedAppearanceID
        am = WPP_ARRAY_FIELD_RE.match(key)
        if am:
            array_name, idx_str, field_name = am.group(1), am.group(2), am.group(3)
            arrays[array_name][int(idx_str)][field_name] = value
        else:
            fields[key] = value

    return fields, arrays


def _safe_int(val, default=0):
    """Parse an integer from a string, handling hex (0x...) and decimal."""
    if val is None:
        return default
    val = val.strip()
    try:
        if val.startswith('0x') or val.startswith('0X'):
            return int(val, 16)
        return int(val)
    except (ValueError, TypeError):
        return default


def _decode_update_slots_from_hex(raw_bytes, pkt):
    """Decode CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS from raw packet bytes.

    Wire format (from TransmogrificationPackets.cpp):
      [SetID:u32][SlotCount:u32][PackedGuid: variable][skip bytes][N * 16-byte slot entries][1 trailing byte]
    """
    if len(raw_bytes) < 8:
        return False

    pkt.set_id = struct.unpack_from('<I', raw_bytes, 0)[0]
    slot_count = struct.unpack_from('<I', raw_bytes, 4)[0]
    pkt.slot_count = slot_count

    if slot_count > 256 or slot_count == 0:
        pkt.anomalies.append(f'Suspicious slot_count={slot_count}')
        return False

    # After SetID(4) + SlotCount(4) = 8 bytes, there's a packed GUID + skip bytes + slot data.
    # We can't reliably parse the packed GUID length, so search for the slot data
    # by looking for the expected pattern: 16-byte aligned blocks where byte[0] sequences are 1..30.
    expected_slot_bytes = slot_count * 16
    # The slot data must fit: we need at least expected_slot_bytes somewhere after offset 8
    remaining = raw_bytes[8:]

    # Try different offsets for the start of slot data
    best_offset = None
    for try_offset in range(0, len(remaining) - expected_slot_bytes + 1):
        # Check if byte[0] of first entry is 1 (ordinal starts at 1 for first slot)
        if remaining[try_offset] == 1:
            # Verify a few more ordinals are sequential
            valid = True
            check_count = min(slot_count, 5)
            for ci in range(check_count):
                ordinal = remaining[try_offset + ci * 16]
                if ordinal != ci + 1:
                    valid = False
                    break
            if valid:
                best_offset = try_offset
                break

    if best_offset is None:
        # Fallback: assume slot data starts right after a minimal packed guid
        # Packed guid is at least 1 byte (mask) + N bytes, try offsets 2..20
        for try_offset in range(2, min(40, len(remaining) - expected_slot_bytes + 1)):
            if try_offset + expected_slot_bytes <= len(remaining):
                best_offset = try_offset
                break

    if best_offset is None:
        pkt.anomalies.append(f'Could not locate slot data in {len(remaining)} remaining bytes')
        return False

    slot_data = remaining[best_offset:]
    for i in range(slot_count):
        offset = i * 16
        if offset + 16 > len(slot_data):
            pkt.anomalies.append(f'Slot data truncated at entry {i} (need {offset+16}, have {len(slot_data)})')
            break

        entry_bytes = slot_data[offset:offset + 16]
        entry = DecodedSlotEntry(
            ordinal=entry_bytes[0],
            option=entry_bytes[1],
            imaid=struct.unpack_from('<I', entry_bytes, 2)[0],
            display_type=struct.unpack_from('<H', entry_bytes, 6)[0],
            raw_hex=entry_bytes.hex(' '),
        )
        pkt.slots.append(entry)

        if entry.is_anomaly:
            pkt.anomalies.append(f'Slot ordinal={entry.ordinal}: IMAID=0 but DisplayType={entry.display_type}')

    if slot_count != 30:
        pkt.anomalies.append(f'Expected 30 entries, got {slot_count}')

    pkt.decode_method = 'hex'
    return True


def _decode_update_slots_from_fields(fields, arrays, pkt):
    """Decode CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS from WPP structured text fields.

    WPP may output these as:
      SetID: 1234
      Appearances[0].SlotIndex: 1
      Appearances[0].Option: 0
      Appearances[0].AppearanceID: 12345
      Appearances[0].DisplayType: 1
    Or alternative field names depending on WPP version.
    """
    pkt.set_id = _safe_int(fields.get('SetID') or fields.get('Set.SetID') or fields.get('SetId'))

    # Try multiple array names WPP might use
    slot_arrays = None
    for array_name in ('Appearances', 'Slots', 'SlotEntries', 'Items', 'Entries'):
        if array_name in arrays and arrays[array_name]:
            slot_arrays = arrays[array_name]
            break

    if not slot_arrays:
        return False

    pkt.slot_count = len(slot_arrays)

    for idx in sorted(slot_arrays.keys()):
        entry_fields = slot_arrays[idx]
        entry = DecodedSlotEntry(
            ordinal=_safe_int(entry_fields.get('SlotIndex') or entry_fields.get('Ordinal') or entry_fields.get('Slot', str(idx + 1))),
            option=_safe_int(entry_fields.get('Option') or entry_fields.get('WeaponOption', '0')),
            imaid=_safe_int(entry_fields.get('AppearanceID') or entry_fields.get('ItemModifiedAppearanceID') or entry_fields.get('IMAID', '0')),
            display_type=_safe_int(entry_fields.get('DisplayType') or entry_fields.get('WireDisplayType', '0')),
        )
        pkt.slots.append(entry)

        if entry.is_anomaly:
            pkt.anomalies.append(f'Slot ordinal={entry.ordinal}: IMAID=0 but DisplayType={entry.display_type}')

    if pkt.slot_count != 30:
        pkt.anomalies.append(f'Expected 30 entries, got {pkt.slot_count}')

    pkt.decode_method = 'structured'
    return True


def _decode_slots_updated_from_fields(fields, arrays, pkt):
    """Decode SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED from WPP structured text fields.

    Wire format: [SetID:u32][Guid:u64]
    """
    pkt.set_id = _safe_int(fields.get('SetID') or fields.get('SetId'))
    pkt.guid = fields.get('Guid') or fields.get('GUID')
    pkt.decode_method = 'structured'
    return pkt.set_id is not None


def _decode_slots_updated_from_hex(raw_bytes, pkt):
    """Decode SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED from raw bytes.

    Wire format: [SetID:u32][Guid:u64]
    """
    if len(raw_bytes) < 4:
        return False
    pkt.set_id = struct.unpack_from('<I', raw_bytes, 0)[0]
    if len(raw_bytes) >= 12:
        pkt.guid = str(struct.unpack_from('<Q', raw_bytes, 4)[0])
    pkt.decode_method = 'hex'
    return True


def _decode_update_situations_from_fields(fields, arrays, pkt):
    """Decode CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS from WPP structured text fields."""
    pkt.set_id = _safe_int(fields.get('SetID') or fields.get('SetId'))

    sit_arrays = None
    for array_name in ('Situations', 'Entries', 'SituationEntries'):
        if array_name in arrays and arrays[array_name]:
            sit_arrays = arrays[array_name]
            break

    if sit_arrays:
        for idx in sorted(sit_arrays.keys()):
            ef = sit_arrays[idx]
            entry = DecodedSituationEntry(
                situation_id=_safe_int(ef.get('SituationID', '0')),
                spec_id=_safe_int(ef.get('SpecID', '0')),
                loadout_id=_safe_int(ef.get('LoadoutID', '0')),
                equipment_set_id=_safe_int(ef.get('EquipmentSetID', '0')),
            )
            pkt.situations.append(entry)

    pkt.decode_method = 'structured'
    return pkt.set_id is not None


def _decode_update_situations_from_hex(raw_bytes, pkt):
    """Decode CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS from raw bytes.

    Wire format: [SetID:u32][PackedGuid: variable][Count:u32][Count * {SituationID:u32, SpecID:u32, LoadoutID:u32, EquipmentSetID:u32}]
    """
    if len(raw_bytes) < 4:
        return False
    pkt.set_id = struct.unpack_from('<I', raw_bytes, 0)[0]

    # After SetID + packed guid + count, each situation is 16 bytes.
    # Try to find the count field by scanning for a reasonable value.
    # The count should be small (0-20) and followed by exactly count*16 bytes.
    remaining = raw_bytes[4:]
    found = False
    for guid_len in range(1, min(20, len(remaining))):
        if guid_len + 4 > len(remaining):
            break
        count = struct.unpack_from('<I', remaining, guid_len)[0]
        if count > 100:
            continue
        expected_end = guid_len + 4 + count * 16
        if expected_end <= len(remaining) + 4:  # allow some slack for trailing bytes
            found = True
            data_start = guid_len + 4
            for i in range(count):
                off = data_start + i * 16
                if off + 16 > len(remaining):
                    break
                entry = DecodedSituationEntry(
                    situation_id=struct.unpack_from('<I', remaining, off)[0],
                    spec_id=struct.unpack_from('<I', remaining, off + 4)[0],
                    loadout_id=struct.unpack_from('<I', remaining, off + 8)[0],
                    equipment_set_id=struct.unpack_from('<I', remaining, off + 12)[0],
                )
                pkt.situations.append(entry)
            break

    pkt.decode_method = 'hex'
    return found or pkt.set_id is not None


def _decode_smsg_generic_from_fields(fields, arrays, pkt):
    """Decode any generic SMSG_TRANSMOG_OUTFIT_* (SetID + Guid)."""
    pkt.set_id = _safe_int(fields.get('SetID') or fields.get('SetId'))
    pkt.guid = fields.get('Guid') or fields.get('GUID')
    pkt.decode_method = 'structured'
    return pkt.set_id is not None


def _decode_smsg_generic_from_hex(raw_bytes, pkt):
    """Decode any generic SMSG_TRANSMOG_OUTFIT_* from raw bytes: [SetID:u32][Guid:u64]."""
    if len(raw_bytes) < 4:
        return False
    pkt.set_id = struct.unpack_from('<I', raw_bytes, 0)[0]
    if len(raw_bytes) >= 12:
        pkt.guid = str(struct.unpack_from('<Q', raw_bytes, 4)[0])
    pkt.decode_method = 'hex'
    return True


def decode_transmog_packets(transmog_packets):
    """Decode all collected transmog packet blocks into structured DecodedPacket objects.

    Tries structured field parsing first (for when WPP fully decodes the packet),
    then falls back to hex dump parsing (for unknown/partially-decoded opcodes).

    Returns a list of DecodedPacket objects.
    """
    decoded = []

    for pkt_idx, block in enumerate(transmog_packets):
        if not block:
            continue

        # Parse the header line
        header_line = block[0]
        header_match = WPP_HEADER_FULL_RE.match(header_line)
        if not header_match:
            # Try simpler match
            simple_match = PACKET_HEADER_RE.match(header_line)
            if not simple_match:
                continue
            direction = simple_match.group(1)
            opcode_name = simple_match.group(2)
            opcode_hex = ''
            length = 0
            conn_idx = None
            timestamp = ''
        else:
            direction = header_match.group(1)
            opcode_name = header_match.group(2)
            opcode_hex = header_match.group(3)
            length = int(header_match.group(4))
            conn_idx = header_match.group(5)
            timestamp = header_match.group(6) or ''

        # Filter: only decode transmog outfit packets
        DECODE_OPCODES = {
            'CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS',
            'CMSG_TRANSMOG_OUTFIT_NEW',
            'CMSG_TRANSMOG_OUTFIT_UPDATE_INFO',
            'CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS',
            'SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED',
            'SMSG_TRANSMOG_OUTFIT_INFO_UPDATED',
            'SMSG_TRANSMOG_OUTFIT_NEW_ENTRY_ADDED',
            'SMSG_TRANSMOG_OUTFIT_SITUATIONS_UPDATED',
            'CMSG_TRANSMOGRIFY_ITEMS',
            'SMSG_ACCOUNT_TRANSMOG_UPDATE',
            'SMSG_ACCOUNT_TRANSMOG_SET_FAVORITES_UPDATE',
        }
        if opcode_name not in DECODE_OPCODES:
            # Still create a minimal entry for statistics
            pkt = DecodedPacket()
            pkt.direction = direction
            pkt.opcode_name = opcode_name
            pkt.opcode_hex = opcode_hex
            pkt.length = length
            pkt.conn_idx = conn_idx
            pkt.timestamp = timestamp
            pkt.packet_index = pkt_idx
            pkt.decode_method = 'passthrough'
            decoded.append(pkt)
            continue

        pkt = DecodedPacket()
        pkt.direction = direction
        pkt.opcode_name = opcode_name
        pkt.opcode_hex = opcode_hex
        pkt.length = length
        pkt.conn_idx = conn_idx
        pkt.timestamp = timestamp
        pkt.packet_index = pkt_idx

        # Try structured field parsing first
        fields, arrays = _parse_structured_fields(block)
        raw_bytes = _parse_hex_dump(block)

        success = False

        if opcode_name in ('CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS', 'CMSG_TRANSMOG_OUTFIT_NEW'):
            if fields:
                success = _decode_update_slots_from_fields(fields, arrays, pkt)
            if not success and raw_bytes:
                success = _decode_update_slots_from_hex(raw_bytes, pkt)

        elif opcode_name == 'SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED':
            if fields:
                success = _decode_slots_updated_from_fields(fields, arrays, pkt)
            if not success and raw_bytes:
                success = _decode_slots_updated_from_hex(raw_bytes, pkt)

        elif opcode_name == 'CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS':
            if fields:
                success = _decode_update_situations_from_fields(fields, arrays, pkt)
            if not success and raw_bytes:
                success = _decode_update_situations_from_hex(raw_bytes, pkt)

        elif opcode_name in ('SMSG_TRANSMOG_OUTFIT_INFO_UPDATED',
                             'SMSG_TRANSMOG_OUTFIT_NEW_ENTRY_ADDED',
                             'SMSG_TRANSMOG_OUTFIT_SITUATIONS_UPDATED'):
            if fields:
                success = _decode_smsg_generic_from_fields(fields, arrays, pkt)
            if not success and raw_bytes:
                success = _decode_smsg_generic_from_hex(raw_bytes, pkt)

        elif opcode_name == 'CMSG_TRANSMOGRIFY_ITEMS':
            # Parse structured fields if available
            pkt.set_id = _safe_int(fields.get('SetID') or fields.get('Npc'))
            pkt.slot_count = len(arrays.get('Items', {}))
            pkt.decode_method = 'structured' if fields else 'minimal'
            success = True

        elif opcode_name in ('SMSG_ACCOUNT_TRANSMOG_UPDATE', 'SMSG_ACCOUNT_TRANSMOG_SET_FAVORITES_UPDATE'):
            pkt.decode_method = 'structured' if fields else 'minimal'
            pkt.raw_fields = fields
            success = True

        if not success:
            pkt.decode_method = 'failed'
            pkt.anomalies.append('Could not decode packet data')

        decoded.append(pkt)

    return decoded


def _correlate_cmsg_smsg_pairs(decoded_packets):
    """Correlate CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS with SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED.

    For each CMSG, find the matching SMSG (same SetID) within the next 5 packets.
    Returns list of (cmsg_pkt, smsg_pkt_or_None) tuples.
    """
    pairs = []
    used_smsg_indices = set()

    for i, pkt in enumerate(decoded_packets):
        if pkt.opcode_name not in ('CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS', 'CMSG_TRANSMOG_OUTFIT_NEW'):
            continue

        matched_smsg = None
        # Look forward up to 5 packets for matching SMSG
        for j in range(i + 1, min(i + 6, len(decoded_packets))):
            candidate = decoded_packets[j]
            if candidate.opcode_name == 'SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED' and j not in used_smsg_indices:
                if candidate.set_id == pkt.set_id or pkt.set_id is None or candidate.set_id is None:
                    matched_smsg = candidate
                    used_smsg_indices.add(j)
                    break

        # Also check generic SMSG types
        if matched_smsg is None:
            smsg_names = ('SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED', 'SMSG_TRANSMOG_OUTFIT_INFO_UPDATED',
                          'SMSG_TRANSMOG_OUTFIT_NEW_ENTRY_ADDED')
            for j in range(i + 1, min(i + 6, len(decoded_packets))):
                candidate = decoded_packets[j]
                if candidate.opcode_name in smsg_names and j not in used_smsg_indices:
                    if candidate.set_id == pkt.set_id or pkt.set_id is None or candidate.set_id is None:
                        matched_smsg = candidate
                        used_smsg_indices.add(j)
                        break

        pairs.append((pkt, matched_smsg))

    return pairs


def write_section_1b(out, decoded_packets):
    """Write Section 1b: Decoded Transmog Protocol to the output file."""
    # Separate packets by type for organized output
    update_slots_pkts = [p for p in decoded_packets
                         if p.opcode_name in ('CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS', 'CMSG_TRANSMOG_OUTFIT_NEW')
                         and p.decode_method != 'passthrough']
    slots_updated_pkts = [p for p in decoded_packets
                          if p.opcode_name == 'SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED'
                          and p.decode_method != 'passthrough']
    situation_pkts = [p for p in decoded_packets
                      if p.opcode_name == 'CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS'
                      and p.decode_method != 'passthrough']

    total_decoded = len(update_slots_pkts) + len(slots_updated_pkts) + len(situation_pkts)

    out.write("=" * 100 + "\n")
    out.write(f"  SECTION 1b: DECODED TRANSMOG PROTOCOL ({total_decoded} decoded packets)\n")
    out.write("  Structured decode of CMSG/SMSG outfit packets with slot-level detail\n")
    out.write("=" * 100 + "\n\n")

    if total_decoded == 0:
        out.write("  (no decodable transmog outfit packets found)\n\n")
        return

    # --- 1b.1: CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS ---
    if update_slots_pkts:
        out.write("-" * 80 + "\n")
        out.write(f"  1b.1  CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS / _NEW ({len(update_slots_pkts)} packets)\n")
        out.write("-" * 80 + "\n\n")

        for pkt in update_slots_pkts:
            out.write(f"  Packet #{pkt.packet_index}  {pkt.opcode_name}")
            if pkt.opcode_hex:
                out.write(f" (0x{pkt.opcode_hex})")
            out.write(f"  Length: {pkt.length}")
            if pkt.timestamp:
                out.write(f"  Time: {pkt.timestamp}")
            out.write(f"\n")
            out.write(f"    Decode method: {pkt.decode_method}\n")
            out.write(f"    SetID: {pkt.set_id}\n")
            out.write(f"    Slot count: {pkt.slot_count}")
            if pkt.slot_count != 30:
                out.write(f"  *** ANOMALY: Expected 30, got {pkt.slot_count} ***")
            out.write("\n")

            if pkt.slots:
                # Column headers
                out.write(f"    {'Ord':>3}  {'Opt':>3}  {'IMAID':>8}  {'DT':>3}  {'Slot Name':<12}  {'Flags':<20}  {'Raw Hex'}\n")
                out.write(f"    {'---':>3}  {'---':>3}  {'--------':>8}  {'---':>3}  {'----------':<12}  {'-----':<20}  {'-------'}\n")

                non_empty = 0
                for entry in pkt.slots:
                    flags = []
                    if entry.imaid == 0:
                        flags.append('EMPTY')
                    if entry.is_anomaly:
                        flags.append('ANOMALY')
                    if entry.display_type == 1 and entry.ordinal == 3:
                        flags.append('2ND-SHOULDER')
                    if entry.option > 0:
                        flags.append(f'WEAPON-OPT={entry.option}')
                    if entry.imaid > 0 and entry.display_type > 15:
                        flags.append(f'UNKNOWN-DT')
                    flag_str = ', '.join(flags) if flags else ''

                    out.write(f"    {entry.ordinal:>3}  {entry.option:>3}  {entry.imaid:>8}  {entry.display_type:>3}  "
                              f"{entry.slot_name:<12}  {flag_str:<20}  {entry.raw_hex}\n")
                    if entry.imaid != 0:
                        non_empty += 1

                out.write(f"    --- {non_empty} non-empty / {len(pkt.slots)} total entries ---\n")

            if pkt.anomalies:
                out.write(f"    ANOMALIES:\n")
                for anom in pkt.anomalies:
                    out.write(f"      *** {anom}\n")

            out.write("\n")

    # --- 1b.2: SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED ---
    if slots_updated_pkts:
        out.write("-" * 80 + "\n")
        out.write(f"  1b.2  SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED ({len(slots_updated_pkts)} packets)\n")
        out.write("-" * 80 + "\n\n")

        for pkt in slots_updated_pkts:
            out.write(f"  Packet #{pkt.packet_index}  {pkt.opcode_name}")
            if pkt.opcode_hex:
                out.write(f" (0x{pkt.opcode_hex})")
            out.write(f"  Length: {pkt.length}")
            if pkt.timestamp:
                out.write(f"  Time: {pkt.timestamp}")
            out.write(f"\n")
            out.write(f"    Decode method: {pkt.decode_method}\n")
            out.write(f"    SetID: {pkt.set_id}\n")
            if pkt.guid:
                out.write(f"    Guid: {pkt.guid}\n")
            out.write("\n")

    # --- 1b.3: CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS ---
    if situation_pkts:
        out.write("-" * 80 + "\n")
        out.write(f"  1b.3  CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS ({len(situation_pkts)} packets)\n")
        out.write("-" * 80 + "\n\n")

        for pkt in situation_pkts:
            out.write(f"  Packet #{pkt.packet_index}  {pkt.opcode_name}")
            if pkt.opcode_hex:
                out.write(f" (0x{pkt.opcode_hex})")
            out.write(f"  Length: {pkt.length}")
            if pkt.timestamp:
                out.write(f"  Time: {pkt.timestamp}")
            out.write(f"\n")
            out.write(f"    Decode method: {pkt.decode_method}\n")
            out.write(f"    SetID: {pkt.set_id}\n")
            out.write(f"    Situation count: {len(pkt.situations)}\n")

            if pkt.situations:
                out.write(f"    {'SitID':>8}  {'SpecID':>8}  {'LoadoutID':>10}  {'EquipSetID':>10}\n")
                out.write(f"    {'--------':>8}  {'--------':>8}  {'----------':>10}  {'----------':>10}\n")
                for sit in pkt.situations:
                    out.write(f"    {sit.situation_id:>8}  {sit.spec_id:>8}  {sit.loadout_id:>10}  {sit.equipment_set_id:>10}\n")

            out.write("\n")

    # --- 1b.4: CMSG/SMSG Correlation ---
    pairs = _correlate_cmsg_smsg_pairs(decoded_packets)
    if pairs:
        out.write("-" * 80 + "\n")
        out.write(f"  1b.4  CMSG -> SMSG PAIR CORRELATION ({len(pairs)} CMSG packets)\n")
        out.write("-" * 80 + "\n\n")

        matched_count = sum(1 for _, smsg in pairs if smsg is not None)
        unmatched_count = len(pairs) - matched_count

        for cmsg, smsg in pairs:
            out.write(f"  CMSG #{cmsg.packet_index}  {cmsg.opcode_name}  SetID={cmsg.set_id}")
            if cmsg.timestamp:
                out.write(f"  Time={cmsg.timestamp}")
            out.write("\n")

            if smsg:
                out.write(f"    -> SMSG #{smsg.packet_index}  {smsg.opcode_name}  SetID={smsg.set_id}")
                if smsg.timestamp:
                    out.write(f"  Time={smsg.timestamp}")
                if smsg.guid:
                    out.write(f"  Guid={smsg.guid}")
                out.write("  [MATCHED]\n")
            else:
                out.write(f"    -> *** NO MATCHING SMSG WITHIN 5 PACKETS ***  [UNMATCHED]\n")

            out.write("\n")

        out.write(f"  Correlation summary: {matched_count} matched, {unmatched_count} unmatched\n\n")

    # --- 1b.5: Summary Statistics ---
    out.write("-" * 80 + "\n")
    out.write(f"  1b.5  SUMMARY STATISTICS\n")
    out.write("-" * 80 + "\n\n")

    # Count by opcode
    opcode_counts = defaultdict(int)
    for pkt in decoded_packets:
        if pkt.decode_method != 'passthrough':
            opcode_counts[pkt.opcode_name] += 1

    if opcode_counts:
        out.write("  Packet counts by opcode:\n")
        for opcode, count in sorted(opcode_counts.items()):
            direction = 'CMSG' if opcode.startswith('CMSG') else 'SMSG'
            out.write(f"    {direction}  {opcode:<50}  {count}\n")
        cmsg_total = sum(c for op, c in opcode_counts.items() if op.startswith('CMSG'))
        smsg_total = sum(c for op, c in opcode_counts.items() if op.startswith('SMSG'))
        out.write(f"    ---\n")
        out.write(f"    Total CMSG: {cmsg_total}   Total SMSG: {smsg_total}\n\n")

    # Slot count stats for UPDATE_SLOTS
    slot_counts = [p.slot_count for p in update_slots_pkts if p.slot_count > 0]
    if slot_counts:
        out.write("  CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS slot counts:\n")
        out.write(f"    Min: {min(slot_counts)}  Max: {max(slot_counts)}  "
                  f"Avg: {sum(slot_counts) / len(slot_counts):.1f}  "
                  f"Count: {len(slot_counts)}\n")
        non_30 = [c for c in slot_counts if c != 30]
        if non_30:
            out.write(f"    *** {len(non_30)} packet(s) with non-standard count (not 30): {non_30}\n")
        else:
            out.write(f"    All packets have exactly 30 entries (standard)\n")
        out.write("\n")

    # Anomaly summary
    all_anomalies = []
    for pkt in decoded_packets:
        for anom in pkt.anomalies:
            all_anomalies.append((pkt.packet_index, pkt.opcode_name, anom))

    if all_anomalies:
        out.write(f"  Anomalies ({len(all_anomalies)} total):\n")
        for pkt_idx, opcode, anom in all_anomalies:
            out.write(f"    Packet #{pkt_idx}  {opcode}:  {anom}\n")
        out.write("\n")
    else:
        out.write("  No anomalies detected.\n\n")

    # Decode method summary
    method_counts = defaultdict(int)
    for pkt in decoded_packets:
        if pkt.decode_method != 'passthrough':
            method_counts[pkt.decode_method] += 1
    if method_counts:
        out.write("  Decode method breakdown:\n")
        for method, count in sorted(method_counts.items()):
            out.write(f"    {method:<15}  {count}\n")
        out.write("\n")


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
                 hotfix_sections, wpp_lines, world_lines, error_lines,
                 decoded_packets=None):
    """Write all extracted content to a single output file."""
    total_items = 0

    with open(output_path, 'w', encoding='utf-8') as out:
        out.write("=" * 100 + "\n")
        out.write("  PACKETSCOPE REPORT\n")
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

        # --- Section 1b: Decoded Transmog Protocol ---
        if decoded_packets is not None:
            write_section_1b(out, decoded_packets)

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
    parser = argparse.ArgumentParser(description="PacketScope — WPP packet log analyzer")
    parser.add_argument('--pkt-dir', type=Path, default=DEFAULT_PKT_DIR,
                        help='Directory containing *_parsed.txt (auto-detected)')
    args = parser.parse_args()

    pkt_dir = args.pkt_dir

    # Auto-detect parsed file: prefer World_parsed.txt, fall back to any *_parsed.txt
    parsed_file = pkt_dir / "World_parsed.txt"
    if not parsed_file.exists():
        candidates = sorted(pkt_dir.glob("*_parsed.txt"))
        if candidates:
            parsed_file = candidates[-1]  # most recent
        else:
            print(f"\n  ERROR: No *_parsed.txt found in {pkt_dir}")
            sys.exit(1)

    # Auto-detect errors file similarly
    errors_file = pkt_dir / "World_errors.txt"
    if not errors_file.exists():
        err_candidates = sorted(pkt_dir.glob("*_errors.txt"))
        if err_candidates:
            errors_file = err_candidates[-1]

    output_file = pkt_dir / "packetscope_report.txt"

    print("PacketScope — WPP Packet Log Analyzer")
    print("=" * 50)
    print(f"  Directory:    {pkt_dir}")
    print(f"  Parsed file:  {parsed_file.name}")

    # Discover SQL files dynamically
    hotfixes_sql, wpp_sql, world_sql = find_sql_files(pkt_dir)

    # Process all files
    print("\n[1/6] Processing parsed packet log...")
    transmog_packets, addon_messages, field_updates = process_parsed_file(parsed_file)

    print(f"  Found: {len(transmog_packets)} transmog packets, "
          f"{len(addon_messages)} addon messages, "
          f"{len(field_updates)} update objects")

    print("\n[2/6] Decoding transmog protocol packets...")
    decoded_packets = decode_transmog_packets(transmog_packets)
    decoded_count = sum(1 for p in decoded_packets if p.decode_method not in ('passthrough', 'failed'))
    failed_count = sum(1 for p in decoded_packets if p.decode_method == 'failed')
    anomaly_count = sum(len(p.anomalies) for p in decoded_packets)
    print(f"  Decoded: {decoded_count} packets ({failed_count} failed, {anomaly_count} anomalies)")

    print("\n[3/6] Processing hotfixes SQL...")
    hotfix_sections = process_hotfixes_sql(hotfixes_sql)
    if hotfix_sections:
        for table, lines in sorted(hotfix_sections.items()):
            row_count = sum(1 for l in lines if l.strip().startswith('('))
            print(f"  {table}: {row_count} rows")
    else:
        print("  (no hotfix SQL found)")

    print("\n[4/6] Processing WPP SQL...")
    wpp_lines = process_sql_file(wpp_sql)
    print(f"  Found: {len(wpp_lines)} lines")

    print("\n[5/6] Processing world SQL...")
    world_lines = process_sql_file(world_sql)
    print(f"  Found: {len(world_lines)} lines")

    print("\n[6/6] Processing errors file...")
    error_lines = process_errors_file(errors_file)
    print(f"  Found: {len(error_lines)} lines")

    # Write output
    print(f"\nWriting output to {output_file}...")
    write_output(output_file, pkt_dir, transmog_packets, addon_messages, field_updates,
                 hotfix_sections, wpp_lines, world_lines, error_lines,
                 decoded_packets=decoded_packets)

    size_mb = output_file.stat().st_size / 1024 / 1024
    print(f"\nDone! Output: {output_file} ({size_mb:.1f} MB)")


if __name__ == '__main__':
    main()

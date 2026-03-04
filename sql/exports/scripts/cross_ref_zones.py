#!/usr/bin/env python3
"""
Cross-reference Wowhead NPC zone data against actual spawn locations in the database
to find NPCs spawned in the wrong zone.

Data sources:
  - Wowhead spawn summary: C:/Users/atayl/source/wago/wowhead_data/npc/npc_spawn_summary.csv
  - MySQL world.creature table (zoneId, areaId columns)
  - AreaTable DB2 CSV for zone name resolution + hierarchy
  - creature_template for NPC names and flags

Output:
  - zone_mismatch_report.txt  — summary + detailed mismatches
  - npc_zone_fixes.sql        — conservative SQL fixes (only clear errors)
"""

import csv
import sys
from collections import defaultdict
from datetime import datetime

import pymysql

# ── Configuration ────────────────────────────────────────────────────────────
MYSQL_HOST = "127.0.0.1"
MYSQL_USER = "root"
MYSQL_PASS = "admin"
MYSQL_DB = "world"

WOWHEAD_CSV = r"C:\Users\atayl\source\wago\wowhead_data\npc\npc_spawn_summary.csv"
AREA_TABLE_CSV = r"C:\Users\atayl\source\wago\wago_csv\major_12\12.0.1.66220\enUS\AreaTable-enUS.csv"

REPORT_PATH = r"C:\Dev\RoleplayCore\sql\exports\cleanup\zone_mismatch_report.txt"
SQL_PATH = r"C:\Dev\RoleplayCore\sql\exports\cleanup\npc_zone_fixes.sql"

# NPC flag constants for identifying high-value NPCs
NPCFLAG_GOSSIP        = 0x0000001
NPCFLAG_QUESTGIVER    = 0x0000002
NPCFLAG_VENDOR        = 0x0000080
NPCFLAG_REPAIR        = 0x0001000
NPCFLAG_FLIGHTMASTER  = 0x0002000
NPCFLAG_INNKEEPER     = 0x0010000
NPCFLAG_BANKER        = 0x0020000
NPCFLAG_AUCTIONEER    = 0x0200000
NPCFLAG_STABLEMASTER  = 0x0400000
NPCFLAG_TRAINER       = 0x0000010

# ── DB Connection ────────────────────────────────────────────────────────────
_conn = None

def get_conn():
    global _conn
    if _conn is None or not _conn.open:
        _conn = pymysql.connect(
            host=MYSQL_HOST, user=MYSQL_USER, password=MYSQL_PASS,
            database=MYSQL_DB, charset='utf8mb4',
            cursorclass=pymysql.cursors.Cursor
        )
    return _conn


def run_query(query, args=None):
    """Execute a MySQL query and return rows as list of tuples."""
    conn = get_conn()
    with conn.cursor() as cur:
        cur.execute(query, args)
        return cur.fetchall()


def run_query_batched(query_template, ids, batch_size=5000):
    """Execute a query with IN clause in batches. query_template should have {placeholders}."""
    all_rows = []
    ids_list = sorted(ids)
    for i in range(0, len(ids_list), batch_size):
        batch = ids_list[i:i + batch_size]
        placeholders = ",".join(["%s"] * len(batch))
        query = query_template.format(placeholders=placeholders)
        rows = run_query(query, batch)
        all_rows.extend(rows)
    return all_rows


# ── Helper functions ─────────────────────────────────────────────────────────

def load_area_table():
    """Load AreaTable DB2 CSV -> {area_id: (name, parent_id, continent_id)}"""
    areas = {}
    with open(AREA_TABLE_CSV, encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            area_id = int(row['ID'])
            name = row['AreaName_lang']
            parent_id = int(row['ParentAreaID'])
            continent_id = int(row['ContinentID'])
            areas[area_id] = (name, parent_id, continent_id)
    return areas


def get_zone_ancestors(area_id, areas, max_depth=10):
    """Get the full chain of zone ancestors for an area ID.
    Returns a set of all zone IDs in the hierarchy (including self).
    """
    result = set()
    current = area_id
    depth = 0
    while current and current in areas and depth < max_depth:
        result.add(current)
        parent = areas[current][1]
        if parent == 0 or parent == current:
            break
        current = parent
        depth += 1
    return result


def get_top_level_zone(area_id, areas, max_depth=10):
    """Walk up AreaTable hierarchy to find the top-level zone (ParentAreaID=0)."""
    current = area_id
    depth = 0
    while current in areas and depth < max_depth:
        parent = areas[current][1]
        if parent == 0:
            return current
        current = parent
        depth += 1
    return area_id  # fallback


def zone_name(area_id, areas):
    """Get zone name or 'Unknown(id)'."""
    if area_id in areas:
        return areas[area_id][0]
    return f"Unknown({area_id})"


def npcflag_desc(flags):
    """Return a short description of NPC flags."""
    parts = []
    if flags & NPCFLAG_QUESTGIVER:   parts.append("QuestGiver")
    if flags & NPCFLAG_VENDOR:       parts.append("Vendor")
    if flags & NPCFLAG_REPAIR:       parts.append("Repair")
    if flags & NPCFLAG_FLIGHTMASTER: parts.append("FlightMaster")
    if flags & NPCFLAG_INNKEEPER:    parts.append("Innkeeper")
    if flags & NPCFLAG_BANKER:       parts.append("Banker")
    if flags & NPCFLAG_AUCTIONEER:   parts.append("Auctioneer")
    if flags & NPCFLAG_STABLEMASTER: parts.append("StableMaster")
    if flags & NPCFLAG_TRAINER:      parts.append("Trainer")
    return ", ".join(parts) if parts else ""


def main():
    print("=" * 70)
    print("Cross-Reference: Wowhead NPC Zones vs DB Spawn Locations")
    print("=" * 70)

    # ── Step 1: Load AreaTable ────────────────────────────────────────────
    print("\n[1/6] Loading AreaTable DB2 CSV...")
    areas = load_area_table()
    print(f"  Loaded {len(areas)} area definitions")

    # Build zone descendants map: top_level_zone -> set of all sub-area IDs
    zone_descendants = defaultdict(set)
    for aid in areas:
        top = get_top_level_zone(aid, areas)
        zone_descendants[top].add(aid)

    # ── Step 2: Load Wowhead spawn summary ────────────────────────────────
    print("\n[2/6] Loading Wowhead spawn summary...")
    wh_npc_zones = defaultdict(set)       # npc_id -> set of wowhead zone_ids
    wh_npc_coords = defaultdict(dict)     # npc_id -> {zone_id: total_coords}
    wh_zone_npcs = defaultdict(set)       # zone_id -> set of npc_ids

    with open(WOWHEAD_CSV, encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            npc_id = int(row['id'])
            zone_id = int(row['zone_id'])
            total_coords = int(row['total_coords'])
            wh_npc_zones[npc_id].add(zone_id)
            wh_npc_coords[npc_id][zone_id] = total_coords
            wh_zone_npcs[zone_id].add(npc_id)

    print(f"  Loaded {len(wh_npc_zones)} NPCs across {len(wh_zone_npcs)} zones")

    # ── Step 3: Query DB for creature spawns ──────────────────────────────
    print("\n[3/6] Querying DB for creature spawn data (batched)...")

    all_wh_ids = sorted(wh_npc_zones.keys())
    print(f"  Need to check {len(all_wh_ids)} Wowhead NPCs against DB")

    db_npc_zones = defaultdict(set)       # npc_id -> set of (zoneId, areaId) tuples
    db_npc_zone_counts = defaultdict(lambda: defaultdict(int))  # npc_id -> {zoneId: count}
    db_spawned_npcs = set()

    BATCH_SIZE = 10000
    total_batches = (len(all_wh_ids) + BATCH_SIZE - 1) // BATCH_SIZE
    for batch_idx in range(total_batches):
        start = batch_idx * BATCH_SIZE
        end = min(start + BATCH_SIZE, len(all_wh_ids))
        batch = all_wh_ids[start:end]
        placeholders = ",".join(["%s"] * len(batch))

        query = f"SELECT id, zoneId, areaId, COUNT(*) FROM creature WHERE id IN ({placeholders}) GROUP BY id, zoneId, areaId"
        rows = run_query(query, batch)

        for npc_id, zone_id, area_id, count in rows:
            db_npc_zones[npc_id].add((zone_id, area_id))
            db_npc_zone_counts[npc_id][zone_id] += count
            db_spawned_npcs.add(npc_id)

        if (batch_idx + 1) % 3 == 0 or batch_idx == total_batches - 1:
            print(f"  Batch {batch_idx + 1}/{total_batches} — {len(db_spawned_npcs)} NPCs with spawns")

    print(f"  Total NPCs with DB spawns: {len(db_spawned_npcs)}")

    # ── Step 4: Get creature_template info ────────────────────────────────
    print("\n[4/6] Loading creature_template for name/flags...")
    npc_info = {}  # npc_id -> (name, npcflag, subname, type)

    info_ids = sorted(db_spawned_npcs)
    total_info_batches = (len(info_ids) + BATCH_SIZE - 1) // BATCH_SIZE
    for batch_idx in range(total_info_batches):
        start = batch_idx * BATCH_SIZE
        end = min(start + BATCH_SIZE, len(info_ids))
        batch = info_ids[start:end]
        placeholders = ",".join(["%s"] * len(batch))

        query = f"SELECT entry, name, npcflag, subname, type FROM creature_template WHERE entry IN ({placeholders})"
        rows = run_query(query, batch)

        for entry, name, npcflag, subname, npc_type in rows:
            npc_info[entry] = (
                name or '',
                int(npcflag) if npcflag is not None else 0,
                subname or '',
                int(npc_type) if npc_type is not None else 0
            )

    print(f"  Loaded info for {len(npc_info)} NPCs")

    # ── Step 5: Cross-reference zones ─────────────────────────────────────
    print("\n[5/6] Cross-referencing zones...")

    mismatches = []
    no_spawn_count = 0
    matched_count = 0
    partial_match_count = 0
    full_mismatch_count = 0
    zero_zone_count = 0

    no_spawn_by_zone = defaultdict(int)

    for npc_id in sorted(wh_npc_zones.keys()):
        wh_zones = wh_npc_zones[npc_id]

        if npc_id not in db_spawned_npcs:
            no_spawn_count += 1
            for z in wh_zones:
                no_spawn_by_zone[z] += 1
            continue

        # Resolve Wowhead zones: collect all zone IDs in their hierarchy
        wh_zone_family = set()
        wh_top_zones = set()
        for wz in wh_zones:
            ancestors = get_zone_ancestors(wz, areas)
            wh_zone_family.update(ancestors)
            wh_top_zones.add(get_top_level_zone(wz, areas))
            # Also add all descendants of each Wowhead zone
            if wz in zone_descendants:
                wh_zone_family.update(zone_descendants[wz])

        # Collect DB zone info
        db_top_zones = set()
        db_all_zones = set()
        has_zero_zone = False
        for (zone_id, area_id) in db_npc_zones[npc_id]:
            if zone_id == 0 and area_id == 0:
                has_zero_zone = True
                continue
            if zone_id != 0:
                db_all_zones.add(zone_id)
                db_top_zones.add(get_top_level_zone(zone_id, areas))
            if area_id != 0:
                db_all_zones.add(area_id)
                db_top_zones.add(get_top_level_zone(area_id, areas))

        if has_zero_zone and not db_all_zones:
            zero_zone_count += 1
            continue

        # Check overlap
        direct_overlap = db_all_zones & wh_zone_family
        top_overlap = db_top_zones & wh_top_zones

        if direct_overlap or top_overlap:
            non_matching_top = db_top_zones - wh_top_zones
            if non_matching_top:
                partial_match_count += 1
                total_spawns = sum(db_npc_zone_counts[npc_id].values())
                wrong_zone_details = []
                for zt in non_matching_top:
                    count = 0
                    for (zid, aid) in db_npc_zones[npc_id]:
                        zone_top = get_top_level_zone(zid if zid else aid, areas)
                        if zone_top == zt:
                            count += db_npc_zone_counts[npc_id].get(zid, 0)
                    wrong_zone_details.append((zt, zone_name(zt, areas), count))

                if any(c > 0 for _, _, c in wrong_zone_details):
                    info = npc_info.get(npc_id, ('Unknown', 0, '', 0))
                    mismatches.append((npc_id, wh_top_zones, db_top_zones, "PARTIAL",
                                       info, wrong_zone_details, total_spawns))
            else:
                matched_count += 1
        else:
            # Full mismatch
            full_mismatch_count += 1
            info = npc_info.get(npc_id, ('Unknown', 0, '', 0))
            total_spawns = sum(db_npc_zone_counts[npc_id].values())
            zone_details = []
            for zt in db_top_zones:
                count = 0
                for (zid, aid) in db_npc_zones[npc_id]:
                    zone_top = get_top_level_zone(zid if zid else aid, areas)
                    if zone_top == zt:
                        count += db_npc_zone_counts[npc_id].get(zid, 0)
                zone_details.append((zt, zone_name(zt, areas), count))
            mismatches.append((npc_id, wh_top_zones, db_top_zones, "FULL",
                               info, zone_details, total_spawns))

    print(f"\n  Results:")
    print(f"    Matched:          {matched_count}")
    print(f"    Partial mismatch: {partial_match_count}")
    print(f"    Full mismatch:    {full_mismatch_count}")
    print(f"    DB zone=0 only:   {zero_zone_count}")
    print(f"    No DB spawns:     {no_spawn_count}")

    # ── Step 6: Generate report + SQL ─────────────────────────────────────
    print(f"\n[6/6] Generating report and SQL...")

    # Sort mismatches
    def mismatch_sort_key(m):
        npc_id, wh_zones, db_zones, severity, info, details, total = m
        name, npcflag, subname, npc_type = info
        importance = 0
        if npcflag & NPCFLAG_QUESTGIVER:   importance += 100
        if npcflag & NPCFLAG_VENDOR:       importance += 50
        if npcflag & NPCFLAG_FLIGHTMASTER: importance += 200
        if npcflag & NPCFLAG_INNKEEPER:    importance += 80
        if npcflag & NPCFLAG_TRAINER:      importance += 60
        if npcflag & NPCFLAG_REPAIR:       importance += 40
        if npcflag & NPCFLAG_BANKER:       importance += 70
        if npcflag & NPCFLAG_AUCTIONEER:   importance += 90
        severity_val = 0 if severity == "FULL" else 1
        return (severity_val, -importance, -total)

    mismatches.sort(key=mismatch_sort_key)

    no_spawn_zones_sorted = sorted(no_spawn_by_zone.items(), key=lambda x: -x[1])

    full_mismatches = [m for m in mismatches if m[3] == "FULL"]
    partial_mismatches = [m for m in mismatches if m[3] == "PARTIAL"]

    # ── Write report ─────────────────────────────────────────────────────
    with open(REPORT_PATH, 'w', encoding='utf-8') as f:
        f.write("=" * 80 + "\n")
        f.write("  NPC Zone Cross-Reference Report\n")
        f.write(f"  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 80 + "\n\n")

        # Summary
        f.write("SUMMARY\n")
        f.write("-" * 40 + "\n")
        f.write(f"Wowhead NPCs checked:    {len(wh_npc_zones):>8}\n")
        f.write(f"NPCs with DB spawns:     {len(db_spawned_npcs):>8}\n")
        f.write(f"NPCs without DB spawns:  {no_spawn_count:>8}\n")
        f.write(f"\n")
        f.write(f"Zone match results (for NPCs with spawns):\n")
        f.write(f"  Matched OK:            {matched_count:>8}\n")
        f.write(f"  Partial mismatch:      {partial_match_count:>8}\n")
        f.write(f"  Full mismatch:         {full_mismatch_count:>8}\n")
        f.write(f"  DB zoneId=0 only:      {zero_zone_count:>8}\n")
        f.write(f"\n")

        # Top mismatched zones
        f.write("\n" + "=" * 80 + "\n")
        f.write("TOP MISMATCHED ZONES (Full mismatches — where DB spawns are)\n")
        f.write("-" * 80 + "\n")
        zone_mismatch_counts = defaultdict(int)
        for m in full_mismatches:
            for zt, zname, count in m[5]:
                zone_mismatch_counts[zt] += 1
        for zt, cnt in sorted(zone_mismatch_counts.items(), key=lambda x: -x[1])[:30]:
            f.write(f"  {zone_name(zt, areas):40s} (ID {zt:>6}) -- {cnt} mismatched NPCs\n")

        # Top no-spawn zones
        f.write("\n" + "=" * 80 + "\n")
        f.write("TOP ZONES WITH NO-SPAWN NPCs (Wowhead has data, DB has no spawns)\n")
        f.write("-" * 80 + "\n")
        for zid, cnt in no_spawn_zones_sorted[:30]:
            f.write(f"  {zone_name(zid, areas):40s} (ID {zid:>6}) -- {cnt} NPCs without spawns\n")

        # High-value full mismatches
        f.write("\n" + "=" * 80 + "\n")
        f.write("HIGH-VALUE FULL MISMATCHES\n")
        f.write("(NPCs where ALL DB spawns are in zones NOT listed on Wowhead)\n")
        f.write("(Sorted by NPC importance: FlightMasters > QuestGivers > Vendors > ...)\n")
        f.write("-" * 80 + "\n\n")

        high_value_count = 0
        for m in full_mismatches:
            npc_id, wh_zones, db_zones, severity, info, details, total = m
            name, npcflag, subname, npc_type = info
            flags_str = npcflag_desc(npcflag)
            if not flags_str and total < 3:
                continue

            high_value_count += 1
            if high_value_count > 500:
                remaining = sum(1 for m2 in full_mismatches
                                if npcflag_desc(m2[4][1]) or m2[6] >= 3) - 500
                f.write(f"\n... ({remaining} more high-value full mismatches omitted)\n")
                break

            f.write(f"NPC {npc_id}: {name}")
            if subname:
                f.write(f" <{subname}>")
            f.write(f"\n")
            if flags_str:
                f.write(f"  Flags: {flags_str}\n")
            f.write(f"  Total DB spawns: {total}\n")

            f.write(f"  Wowhead zones: ")
            wh_parts = []
            for wz in sorted(wh_zones):
                coords = wh_npc_coords[npc_id].get(wz, 0)
                wh_parts.append(f"{zone_name(wz, areas)} ({wz}, {coords} coords)")
            f.write(", ".join(wh_parts) + "\n")

            f.write(f"  DB zones:      ")
            db_parts = []
            for zt, zname, count in sorted(details, key=lambda x: -x[2]):
                db_parts.append(f"{zname} ({zt}, {count} spawns)")
            f.write(", ".join(db_parts) + "\n")

            f.write("\n")

        # Partial mismatches (high-value only)
        f.write("\n" + "=" * 80 + "\n")
        f.write("HIGH-VALUE PARTIAL MISMATCHES\n")
        f.write("(NPCs with SOME spawns in correct zones, SOME in wrong zones)\n")
        f.write("-" * 80 + "\n\n")

        partial_hv_count = 0
        for m in partial_mismatches:
            npc_id, wh_zones, db_zones, severity, info, details, total = m
            name, npcflag, subname, npc_type = info
            flags_str = npcflag_desc(npcflag)
            if not flags_str:
                continue

            partial_hv_count += 1
            if partial_hv_count > 200:
                f.write(f"\n... (more partial mismatches omitted)\n")
                break

            f.write(f"NPC {npc_id}: {name}")
            if subname:
                f.write(f" <{subname}>")
            f.write(f"\n")
            f.write(f"  Flags: {flags_str}\n")
            f.write(f"  Total DB spawns: {total}\n")

            f.write(f"  Wowhead zones: ")
            wh_parts = []
            for wz in sorted(wh_zones):
                coords = wh_npc_coords[npc_id].get(wz, 0)
                wh_parts.append(f"{zone_name(wz, areas)} ({wz}, {coords} coords)")
            f.write(", ".join(wh_parts) + "\n")

            f.write(f"  DB zones:      ")
            db_parts = []
            for zt in sorted(db_zones):
                count = 0
                for (zid, aid) in db_npc_zones[npc_id]:
                    zone_top = get_top_level_zone(zid if zid else aid, areas)
                    if zone_top == zt:
                        count += db_npc_zone_counts[npc_id].get(zid, 0)
                # Check match
                is_match = zt in wh_top_zones
                if not is_match:
                    for wz in wh_zones:
                        anc = get_zone_ancestors(wz, areas)
                        if zt in anc:
                            is_match = True
                            break
                        if wz in zone_descendants and zt in zone_descendants[wz]:
                            is_match = True
                            break
                        wt = get_top_level_zone(wz, areas)
                        if zt == wt:
                            is_match = True
                            break
                marker = " *** MISMATCH" if not is_match else ""
                db_parts.append(f"{zone_name(zt, areas)} ({zt}, {count} spawns{marker})")
            f.write(", ".join(db_parts) + "\n")

            f.write("\n")

        # Zone pair analysis
        f.write("\n" + "=" * 80 + "\n")
        f.write("FULL MISMATCH ZONE PAIR ANALYSIS\n")
        f.write("(Wowhead Zone -> DB Zone pairs, showing potential systematic errors)\n")
        f.write("-" * 80 + "\n\n")

        zone_pair_counts = defaultdict(list)
        for m in full_mismatches:
            npc_id, wh_zones, db_zones, severity, info, details, total = m
            for wz in wh_zones:
                wt = get_top_level_zone(wz, areas)
                for zt, zname, count in details:
                    zone_pair_counts[(wt, zt)].append(npc_id)

        for (wt, dt), npc_ids in sorted(zone_pair_counts.items(), key=lambda x: -len(x[1]))[:50]:
            if len(npc_ids) < 2:
                continue
            f.write(f"  Wowhead: {zone_name(wt, areas):30s} ({wt:>6})  ->  DB: {zone_name(dt, areas):30s} ({dt:>6})  -- {len(npc_ids)} NPCs\n")
            for nid in npc_ids[:5]:
                info = npc_info.get(nid, ('Unknown', 0, '', 0))
                f.write(f"    NPC {nid}: {info[0]}\n")
            if len(npc_ids) > 5:
                f.write(f"    ... and {len(npc_ids) - 5} more\n")
            f.write("\n")

        f.write("\n" + "=" * 80 + "\n")
        f.write("END OF REPORT\n")
        f.write("=" * 80 + "\n")

    print(f"  Report written to: {REPORT_PATH}")

    # ── Generate SQL fixes ────────────────────────────────────────────────
    print("\n  Generating conservative SQL fixes...")

    # Section 2: Wowhead cross-ref review items
    sql_fixes = []
    for m in full_mismatches:
        npc_id, wh_zones, db_zones, severity, info, details, total = m
        name, npcflag, subname, npc_type = info
        flags_str = npcflag_desc(npcflag)

        if len(wh_zones) != 1:
            continue
        if total > 20:
            continue
        if not flags_str:
            continue
        if len(db_zones) > 1:
            continue

        wh_zone = list(wh_zones)[0]
        wh_top = get_top_level_zone(wh_zone, areas)
        db_top = list(db_zones)[0]

        sql_fixes.append(
            f"-- NPC {npc_id}: {name} ({flags_str})\n"
            f"-- Wowhead: {zone_name(wh_top, areas)} ({wh_top}), "
            f"DB: {zone_name(db_top, areas)} ({db_top}), {total} spawns\n"
            f"-- REVIEW: Spawns may be in wrong zone. Verify coordinates before fixing.\n"
            f"-- SELECT guid, id, map, zoneId, areaId, position_x, position_y, position_z "
            f"FROM creature WHERE id = {npc_id};\n\n"
        )

    # Section 1: zoneId/areaId inconsistencies
    print("  Checking for zoneId/areaId inconsistencies...")

    query = """
    SELECT c.id, c.zoneId, c.areaId, COUNT(*) as cnt,
           ct.name, ct.npcflag
    FROM creature c
    JOIN creature_template ct ON c.id = ct.entry
    WHERE c.zoneId != 0 AND c.areaId != 0
    GROUP BY c.id, c.zoneId, c.areaId
    """
    rows = run_query(query)

    zone_area_fixes = []
    for npc_id, zone_id, area_id, count, name, npcflag in rows:
        npc_id = int(npc_id)
        zone_id = int(zone_id)
        area_id = int(area_id)
        count = int(count)
        name = name or 'Unknown'
        npcflag = int(npcflag) if npcflag is not None else 0

        if area_id not in areas or zone_id not in areas:
            continue

        # Check: is zoneId an ancestor of areaId in the AreaTable hierarchy?
        # If not, the zoneId is inconsistent with the areaId.
        area_ancestors = get_zone_ancestors(area_id, areas)
        if zone_id not in area_ancestors and zone_id != area_id:
            # zoneId is not in the ancestry chain of areaId -- real inconsistency
            area_top = get_top_level_zone(area_id, areas)
            flags_str = npcflag_desc(npcflag)
            zone_area_fixes.append({
                'npc_id': npc_id,
                'name': name,
                'flags': flags_str,
                'zone_id': zone_id,
                'area_id': area_id,
                'correct_zone': area_top,
                'count': count
            })

    # Deduplicate
    seen_pairs = set()
    unique_za_fixes = []
    for fix in zone_area_fixes:
        key = (fix['npc_id'], fix['zone_id'], fix['area_id'])
        if key not in seen_pairs:
            seen_pairs.add(key)
            unique_za_fixes.append(fix)

    unique_za_fixes.sort(key=lambda x: (-1 if x['flags'] else 0, -x['count']))

    # Write SQL
    with open(SQL_PATH, 'w', encoding='utf-8') as f:
        f.write("-- ============================================================================\n")
        f.write("-- NPC Zone Mismatch Fixes\n")
        f.write(f"-- Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("-- REVIEW CAREFULLY before applying. These are conservative fixes only.\n")
        f.write("-- ============================================================================\n\n")

        if unique_za_fixes:
            f.write("-- ============================================================================\n")
            f.write("-- SECTION 1: zoneId/areaId Inconsistencies\n")
            f.write("-- The creature's areaId belongs to a different top-level zone than its zoneId.\n")
            f.write("-- Fix: Update zoneId to match the areaId's actual parent zone.\n")
            f.write(f"-- Total: {len(unique_za_fixes)} mismatched (npc, zone, area) combos\n")
            f.write("-- ============================================================================\n\n")

            pattern_groups = defaultdict(list)
            for fix in unique_za_fixes:
                pattern_groups[(fix['zone_id'], fix['correct_zone'])].append(fix)

            total_spawn_fixes = 0
            for (wrong_zone, correct_zone), fixes in sorted(pattern_groups.items(),
                                                             key=lambda x: -len(x[1])):
                total_affected = sum(fix['count'] for fix in fixes)
                total_spawn_fixes += total_affected
                f.write(f"-- Pattern: zoneId={wrong_zone} ({zone_name(wrong_zone, areas)}) "
                        f"-> should be {correct_zone} ({zone_name(correct_zone, areas)}) "
                        f"-- {len(fixes)} NPCs, {total_affected} spawns\n")

                for fix in fixes[:3]:
                    f.write(f"--   NPC {fix['npc_id']}: {fix['name']}"
                            f" (areaId={fix['area_id']}, {fix['count']} spawns)"
                            f"{' [' + fix['flags'] + ']' if fix['flags'] else ''}\n")
                if len(fixes) > 3:
                    f.write(f"--   ... and {len(fixes) - 3} more NPCs\n")

                area_list = ",".join(str(a) for a in sorted(set(fix['area_id'] for fix in fixes)))
                f.write(f"UPDATE creature SET zoneId = {correct_zone} "
                        f"WHERE zoneId = {wrong_zone} AND areaId IN ({area_list});\n\n")

        if sql_fixes:
            f.write("\n-- ============================================================================\n")
            f.write("-- SECTION 2: Wowhead Cross-Reference Review Items\n")
            f.write("-- NPCs whose DB spawn zone doesn't match Wowhead data at all.\n")
            f.write("-- These require MANUAL verification -- coordinates may need updating.\n")
            f.write(f"-- Total: {len(sql_fixes)} items for review\n")
            f.write("-- ============================================================================\n\n")
            for fix_sql in sql_fixes:
                f.write(fix_sql)

        f.write("\n-- ============================================================================\n")
        f.write(f"-- Summary:\n")
        f.write(f"--   Section 1 (zoneId/areaId fixes): {len(unique_za_fixes)} combos across "
                f"{len(pattern_groups) if unique_za_fixes else 0} patterns\n")
        f.write(f"--   Section 2 (review items):        {len(sql_fixes)} NPCs\n")
        f.write("-- ============================================================================\n")

    print(f"  SQL fixes written to: {SQL_PATH}")
    if unique_za_fixes:
        print(f"    Section 1: {len(unique_za_fixes)} zoneId/areaId inconsistencies "
              f"({len(pattern_groups)} patterns)")
    print(f"    Section 2: {len(sql_fixes)} Wowhead cross-ref review items")

    print("\nDone!")


if __name__ == '__main__':
    main()

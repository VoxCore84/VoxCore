#!/usr/bin/env python3
"""
Validate creature_template.faction values against the FactionTemplate DB2.

Checks:
  1. Invalid faction IDs (not in FactionTemplate DB2)
  2. NPCs with faction=0 (defaults to neutral — may be intentional or data gap)
  3. Service NPCs (vendor, trainer, innkeeper, etc.) with hostile-to-player factions

Data sources:
  - FactionTemplate DB2 CSV (12.0.1.66220)
  - Faction DB2 CSV (for human-readable names)
  - MySQL: world.creature_template

Outputs:
  - faction_validation_report.txt  (full report)
  - npc_faction_fixes.sql          (SQL fixes for clear errors only)
"""

import csv
import subprocess
import sys
import time
from collections import defaultdict

# ── Paths ──────────────────────────────────────────────────────────────────────
MYSQL = r"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
FACTION_TEMPLATE_CSV = (
    r"C:\Users\atayl\source\wago\wago_csv\major_12\12.0.1.66220\enUS"
    r"\FactionTemplate-enUS.csv"
)
FACTION_CSV = (
    r"C:\Users\atayl\source\wago\wago_csv\major_12\12.0.1.66220\enUS"
    r"\Faction-enUS.csv"
)
REPORT_OUT = r"C:\Dev\RoleplayCore\sql\exports\cleanup\faction_validation_report.txt"
SQL_OUT = r"C:\Dev\RoleplayCore\sql\exports\cleanup\npc_faction_fixes.sql"

# ── NPC flag bits for service NPCs ─────────────────────────────────────────────
SERVICE_FLAGS = {
    16:       "Trainer",
    128:      "Vendor",
    4096:     "Repair",
    8192:     "Flight Master",
    65536:    "Innkeeper",
    131072:   "Banker",
    2097152:  "Auctioneer",
    4194304:  "Stable Master",
}


def run_mysql(query):
    """Run a MySQL query and return tab-separated rows."""
    result = subprocess.run(
        [MYSQL, "-u", "root", "-padmin", "--batch", "--skip-column-names", "-e", query],
        capture_output=True
    )
    if result.returncode != 0:
        print(f"MySQL error: {result.stderr.decode('utf-8', errors='replace')}",
              file=sys.stderr)
        sys.exit(1)
    stdout = result.stdout.decode('utf-8', errors='replace')
    rows = []
    for line in stdout.strip().split('\n'):
        if line:
            rows.append(line.split('\t'))
    return rows


def load_faction_templates():
    """Load FactionTemplate DB2 CSV. Returns dict of ID -> row data."""
    templates = {}
    with open(FACTION_TEMPLATE_CSV, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            ft_id = int(row['ID'])
            templates[ft_id] = {
                'faction_id': int(row['Faction']),
                'flags': int(row['Flags']),
                'faction_group': int(row['FactionGroup']),
                'friend_group': int(row['FriendGroup']),
                'enemy_group': int(row['EnemyGroup']),
            }
    return templates


def load_faction_names():
    """Load Faction DB2 CSV for human-readable names. Returns dict ID -> name."""
    names = {}
    try:
        with open(FACTION_CSV, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                names[int(row['ID'])] = row['Name_lang']
    except FileNotFoundError:
        print("  Warning: Faction-enUS.csv not found, names will be unavailable")
    return names


def get_faction_name(faction_templates, faction_names, ft_id):
    """Get a human-readable name for a FactionTemplate ID."""
    ft = faction_templates.get(ft_id)
    if not ft:
        return f"(unknown FactionTemplate {ft_id})"
    faction_id = ft['faction_id']
    name = faction_names.get(faction_id, f"Faction#{faction_id}")
    return name


def describe_faction_group(fg):
    """Describe FactionGroup bits."""
    parts = []
    if fg & 1:
        parts.append("AlliancePlayer")
    if fg & 2:
        parts.append("HordePlayer")
    if fg & 4:
        parts.append("AllianceNPC")
    if fg & 8:
        parts.append("HordeNPC")
    return ", ".join(parts) if parts else "None"


def describe_enemy_group(eg):
    """Describe EnemyGroup bits."""
    parts = []
    if eg & 1:
        parts.append("AlliancePlayer")
    if eg & 2:
        parts.append("HordePlayer")
    if eg & 4:
        parts.append("AllianceNPC")
    if eg & 8:
        parts.append("HordeNPC")
    return ", ".join(parts) if parts else "None"


def get_service_roles(npcflag):
    """Return list of service role names from npcflag."""
    roles = []
    for bit, name in SERVICE_FLAGS.items():
        if npcflag & bit:
            roles.append(name)
    return roles


def is_hostile_to_players(ft_data):
    """
    Determine if a faction template is hostile to players.

    Hostile means:
    - EnemyGroup has bit 1 (hostile to Alliance players) AND bit 2 (hostile to Horde players)
    OR
    - EnemyGroup has bit 1 or 2 (hostile to at least one player faction)
      AND FactionGroup has neither bit 1 nor bit 2 (not friendly to any player faction)

    For service NPCs, being hostile to EITHER faction is a problem.
    Returns: 'both', 'alliance', 'horde', or None
    """
    eg = ft_data['enemy_group']
    hostile_alliance = bool(eg & 1)
    hostile_horde = bool(eg & 2)

    if hostile_alliance and hostile_horde:
        return 'both'
    elif hostile_alliance:
        return 'alliance'
    elif hostile_horde:
        return 'horde'
    return None


def main():
    start = time.time()

    # ── Step 1: Load DB2 data ──────────────────────────────────────────────────
    print("Loading FactionTemplate DB2...")
    faction_templates = load_faction_templates()
    valid_ft_ids = set(faction_templates.keys())
    print(f"  Loaded {len(valid_ft_ids)} valid FactionTemplate IDs")

    print("Loading Faction DB2 (names)...")
    faction_names = load_faction_names()
    print(f"  Loaded {len(faction_names)} faction names")

    # ── Step 2: Query all distinct factions from creature_template ─────────────
    print("Querying distinct factions from creature_template...")
    rows = run_mysql("SELECT DISTINCT faction FROM world.creature_template ORDER BY faction")
    db_factions = set()
    for row in rows:
        db_factions.add(int(row[0]))
    print(f"  Found {len(db_factions)} distinct faction values in creature_template")

    # ── Step 3: Find invalid faction IDs ───────────────────────────────────────
    invalid_factions = db_factions - valid_ft_ids
    # faction 0 is technically not in DB2 but is a special "no faction" value;
    # handle it separately
    if 0 in invalid_factions:
        invalid_factions.discard(0)
        has_faction_zero = True
    else:
        has_faction_zero = 0 in db_factions

    print(f"  Invalid faction IDs (not in FactionTemplate DB2): {len(invalid_factions)}")
    if has_faction_zero:
        print(f"  faction=0 present (special neutral default)")

    # ── Step 4: Get NPCs with invalid factions ────────────────────────────────
    invalid_npcs = {}  # faction -> list of (entry, name, npcflag)
    if invalid_factions:
        placeholders = ",".join(str(f) for f in sorted(invalid_factions))
        query = (
            f"SELECT entry, name, faction, npcflag "
            f"FROM world.creature_template "
            f"WHERE faction IN ({placeholders}) "
            f"ORDER BY faction, entry"
        )
        rows = run_mysql(query)
        for row in rows:
            entry, name, faction, npcflag = int(row[0]), row[1], int(row[2]), int(row[3])
            if faction not in invalid_npcs:
                invalid_npcs[faction] = []
            invalid_npcs[faction].append((entry, name, npcflag))
        total_invalid_npcs = sum(len(v) for v in invalid_npcs.values())
        print(f"  NPCs with invalid factions: {total_invalid_npcs}")

    # ── Step 5: Get faction=0 NPCs ────────────────────────────────────────────
    faction_zero_npcs = []
    if has_faction_zero:
        query = (
            "SELECT ct.entry, ct.name, ct.npcflag, "
            "  (SELECT COUNT(*) FROM world.creature c WHERE c.id = ct.entry) AS spawn_count "
            "FROM world.creature_template ct "
            "WHERE ct.faction = 0 "
            "ORDER BY ct.entry"
        )
        rows = run_mysql(query)
        for row in rows:
            entry, name, npcflag, spawns = int(row[0]), row[1], int(row[2]), int(row[3])
            faction_zero_npcs.append((entry, name, npcflag, spawns))
        print(f"  NPCs with faction=0: {len(faction_zero_npcs)} "
              f"({sum(1 for x in faction_zero_npcs if x[3] > 0)} spawned)")

    # ── Step 6: Find hostile service NPCs ─────────────────────────────────────
    print("Checking for hostile service NPCs...")

    # Build set of hostile-to-player faction template IDs
    hostile_ft_ids = set()
    for ft_id, ft_data in faction_templates.items():
        hostility = is_hostile_to_players(ft_data)
        if hostility:
            hostile_ft_ids.add(ft_id)

    print(f"  Hostile-to-player FactionTemplate IDs: {len(hostile_ft_ids)}")

    # Query service NPCs: have any service npcflag bits set
    # service bits: 16 | 128 | 4096 | 8192 | 65536 | 131072 | 2097152 | 4194304 = 6489104
    service_mask = sum(SERVICE_FLAGS.keys())
    query = (
        f"SELECT entry, name, faction, npcflag "
        f"FROM world.creature_template "
        f"WHERE (npcflag & {service_mask}) != 0 "
        f"ORDER BY faction, entry"
    )
    rows = run_mysql(query)
    hostile_service_npcs = []  # (entry, name, faction, npcflag, hostility, faction_name)
    for row in rows:
        entry, name, faction, npcflag = int(row[0]), row[1], int(row[2]), int(row[3])
        if faction in hostile_ft_ids:
            ft_data = faction_templates[faction]
            hostility = is_hostile_to_players(ft_data)
            fname = get_faction_name(faction_templates, faction_names, faction)
            hostile_service_npcs.append((entry, name, faction, npcflag, hostility, fname))

    print(f"  Service NPCs with hostile factions: {len(hostile_service_npcs)}")

    # ── Step 7: Generate report ───────────────────────────────────────────────
    print(f"\nWriting report to {REPORT_OUT}...")
    with open(REPORT_OUT, 'w', encoding='utf-8') as rpt:
        rpt.write("=" * 80 + "\n")
        rpt.write("FACTION VALIDATION REPORT\n")
        rpt.write(f"Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        rpt.write(f"FactionTemplate DB2: {len(valid_ft_ids)} valid IDs\n")
        rpt.write(f"creature_template: {len(db_factions)} distinct faction values\n")
        rpt.write("=" * 80 + "\n\n")

        # ── Section 1: Invalid faction IDs ─────────────────────────────────────
        rpt.write("-" * 80 + "\n")
        rpt.write("SECTION 1: INVALID FACTION IDs (not in FactionTemplate DB2)\n")
        rpt.write("-" * 80 + "\n\n")

        if invalid_factions:
            total_invalid_npcs = sum(len(v) for v in invalid_npcs.values())
            rpt.write(f"Found {len(invalid_factions)} invalid faction IDs "
                       f"affecting {total_invalid_npcs} NPCs:\n\n")

            for faction in sorted(invalid_factions):
                npcs = invalid_npcs.get(faction, [])
                rpt.write(f"  Faction {faction}: {len(npcs)} NPC(s)\n")
                for entry, name, npcflag in npcs:
                    roles = get_service_roles(npcflag)
                    role_str = f" [{', '.join(roles)}]" if roles else ""
                    rpt.write(f"    entry={entry:>8}  {name}{role_str}\n")
                rpt.write("\n")
        else:
            rpt.write("No invalid faction IDs found. All creature_template.faction values "
                       "reference valid FactionTemplate DB2 entries.\n\n")

        # ── Section 2: faction=0 NPCs ──────────────────────────────────────────
        rpt.write("-" * 80 + "\n")
        rpt.write("SECTION 2: NPCs WITH faction=0 (neutral default)\n")
        rpt.write("-" * 80 + "\n\n")

        if faction_zero_npcs:
            spawned = [x for x in faction_zero_npcs if x[3] > 0]
            unspawned = [x for x in faction_zero_npcs if x[3] == 0]
            rpt.write(f"Total NPCs with faction=0: {len(faction_zero_npcs)}\n")
            rpt.write(f"  Spawned in world: {len(spawned)}\n")
            rpt.write(f"  Not spawned (template only): {len(unspawned)}\n\n")

            if spawned:
                rpt.write("  Spawned NPCs with faction=0 (may need a real faction):\n")
                for entry, name, npcflag, spawns in spawned:
                    roles = get_service_roles(npcflag)
                    role_str = f" [{', '.join(roles)}]" if roles else ""
                    rpt.write(f"    entry={entry:>8}  spawns={spawns:>3}  {name}{role_str}\n")
                rpt.write("\n")

            if unspawned:
                rpt.write(f"  Unspawned NPCs with faction=0: {len(unspawned)} "
                           f"(omitted - template only, low priority)\n\n")
        else:
            rpt.write("No NPCs with faction=0.\n\n")

        # ── Section 3: Hostile service NPCs ────────────────────────────────────
        rpt.write("-" * 80 + "\n")
        rpt.write("SECTION 3: SERVICE NPCs WITH HOSTILE FACTIONS\n")
        rpt.write("-" * 80 + "\n\n")
        rpt.write("These NPCs have service flags (vendor/trainer/innkeeper/etc.)\n")
        rpt.write("but their faction is hostile to players. This is likely a data error.\n\n")

        if hostile_service_npcs:
            rpt.write(f"Found {len(hostile_service_npcs)} service NPCs "
                       f"with hostile factions:\n\n")

            # Group by faction for readability
            by_faction = defaultdict(list)
            for entry, name, faction, npcflag, hostility, fname in hostile_service_npcs:
                by_faction[faction].append((entry, name, npcflag, hostility, fname))

            for faction in sorted(by_faction.keys()):
                npcs = by_faction[faction]
                ft_data = faction_templates[faction]
                fname = npcs[0][4]  # faction name from first NPC
                rpt.write(f"  Faction {faction} ({fname}):\n")
                rpt.write(f"    FactionGroup: {describe_faction_group(ft_data['faction_group'])}\n")
                rpt.write(f"    EnemyGroup:   {describe_enemy_group(ft_data['enemy_group'])}\n")
                rpt.write(f"    NPCs ({len(npcs)}):\n")
                for entry, name, npcflag, hostility, _ in npcs:
                    roles = get_service_roles(npcflag)
                    hostile_str = f"hostile-to-{hostility}"
                    rpt.write(f"      entry={entry:>8}  {name}  "
                               f"[{', '.join(roles)}]  ({hostile_str})\n")
                rpt.write("\n")
        else:
            rpt.write("No service NPCs with hostile factions found.\n\n")

        # ── Section 4: Summary statistics ──────────────────────────────────────
        rpt.write("-" * 80 + "\n")
        rpt.write("SECTION 4: FACTION DISTRIBUTION SUMMARY\n")
        rpt.write("-" * 80 + "\n\n")

        # Categorize all used factions
        alliance_player = 0
        horde_player = 0
        both_player = 0
        alliance_npc_only = 0
        horde_npc_only = 0
        neutral = 0
        hostile_only = 0
        other = 0

        for f_id in sorted(db_factions):
            if f_id == 0:
                neutral += 1
                continue
            ft = faction_templates.get(f_id)
            if not ft:
                continue  # invalid, already reported
            fg = ft['faction_group']
            eg = ft['enemy_group']
            is_ally_player = bool(fg & 1)
            is_horde_player = bool(fg & 2)

            if is_ally_player and is_horde_player:
                both_player += 1
            elif is_ally_player:
                alliance_player += 1
            elif is_horde_player:
                horde_player += 1
            elif fg & 4 and not (fg & 8):
                alliance_npc_only += 1
            elif fg & 8 and not (fg & 4):
                horde_npc_only += 1
            elif eg:
                hostile_only += 1
            else:
                neutral += 1

        rpt.write(f"  Factions friendly to both players:    {both_player}\n")
        rpt.write(f"  Factions friendly to Alliance only:   {alliance_player}\n")
        rpt.write(f"  Factions friendly to Horde only:      {horde_player}\n")
        rpt.write(f"  Alliance NPC only (no player-friend): {alliance_npc_only}\n")
        rpt.write(f"  Horde NPC only (no player-friend):    {horde_npc_only}\n")
        rpt.write(f"  Neutral (no group bits):               {neutral}\n")
        rpt.write(f"  Hostile only (enemy bits, no friend):  {hostile_only}\n")
        rpt.write(f"  Invalid (not in DB2):                  {len(invalid_factions)}\n")
        rpt.write(f"  Total distinct factions used:          {len(db_factions)}\n")
        rpt.write("\n")

    # ── Step 8: Generate SQL fixes ────────────────────────────────────────────
    print(f"Writing SQL fixes to {SQL_OUT}...")
    fix_count = 0
    with open(SQL_OUT, 'w', encoding='utf-8') as sql:
        sql.write("-- ============================================================\n")
        sql.write("-- Faction Validation Fixes\n")
        sql.write(f"-- Generated: {time.strftime('%Y-%m-%d %H:%M:%S')}\n")
        sql.write("-- Only includes clear errors with safe fixes.\n")
        sql.write("-- ============================================================\n\n")

        # Fix 1: Invalid faction IDs -> set to faction 35 (Friendly / neutral-friendly)
        # Only auto-fix if the NPC is a service NPC (vendor/trainer/etc.)
        # because those MUST be interactable. Non-service NPCs with invalid factions
        # are listed in report but not auto-fixed (may need manual research).
        if invalid_npcs:
            sql.write("-- ── Invalid Faction IDs on Service NPCs ──\n")
            sql.write("-- These NPCs have faction values not in FactionTemplate DB2.\n")
            sql.write("-- Service NPCs are set to faction 35 (Friendly to all players).\n")
            sql.write("-- Non-service NPCs are listed in the report for manual review.\n\n")

            for faction in sorted(invalid_npcs.keys()):
                for entry, name, npcflag in invalid_npcs[faction]:
                    roles = get_service_roles(npcflag)
                    if roles:
                        sql.write(f"-- entry {entry}: {name} [{', '.join(roles)}] "
                                  f"had invalid faction {faction}\n")
                        sql.write(f"UPDATE creature_template SET faction = 35 "
                                  f"WHERE entry = {entry}; "
                                  f"-- was {faction} (invalid)\n")
                        fix_count += 1

            if fix_count > 0:
                sql.write("\n")

        # Fix 2: Hostile service NPCs
        # These are trickier -- we only auto-fix NPCs that are hostile to BOTH
        # player factions, since a vendor hostile to one faction could be intentional
        # (faction-specific vendor). For hostile-to-both, we check if there's a
        # non-hostile version of the same faction.
        hostile_both_fixes = 0
        if hostile_service_npcs:
            sql.write("-- ── Service NPCs with Hostile-to-Both-Players Factions ──\n")
            sql.write("-- These NPCs are vendors/trainers/etc. but hostile to ALL players.\n")
            sql.write("-- This is almost certainly a data error.\n")
            sql.write("-- Set to faction 35 (Friendly to all players).\n\n")

            for entry, name, faction, npcflag, hostility, fname in hostile_service_npcs:
                if hostility == 'both':
                    roles = get_service_roles(npcflag)
                    sql.write(f"-- entry {entry}: {name} [{', '.join(roles)}] "
                              f"was faction {faction} ({fname}, hostile to both)\n")
                    sql.write(f"UPDATE creature_template SET faction = 35 "
                              f"WHERE entry = {entry}; "
                              f"-- was {faction} (hostile to all players)\n")
                    hostile_both_fixes += 1
                    fix_count += 1

            if hostile_both_fixes > 0:
                sql.write("\n")

            # Summarize hostile-to-one-side (these are almost always intentional
            # faction-locked NPCs: Horde vendors hostile to Alliance, etc.)
            hostile_one_side = [
                x for x in hostile_service_npcs if x[4] != 'both'
            ]
            if hostile_one_side:
                hostile_ally = [x for x in hostile_one_side if x[4] == 'alliance']
                hostile_horde = [x for x in hostile_one_side if x[4] == 'horde']
                sql.write("-- ── Service NPCs Hostile to ONE Player Faction (summary) ──\n")
                sql.write("-- These are almost always intentional faction-locked NPCs\n")
                sql.write("-- (e.g. Horde vendors hostile to Alliance players).\n")
                sql.write(f"-- Hostile to Alliance only: {len(hostile_ally)} NPCs\n")
                sql.write(f"-- Hostile to Horde only:    {len(hostile_horde)} NPCs\n")
                sql.write("-- See faction_validation_report.txt for full per-NPC details.\n\n")

        if fix_count == 0:
            sql.write("-- No automatic fixes generated.\n")
            sql.write("-- See faction_validation_report.txt for full details.\n")

        sql.write(f"\n-- Total fixes: {fix_count}\n")

    elapsed = time.time() - start
    print(f"\nDone in {elapsed:.1f}s")
    print(f"  Report: {REPORT_OUT}")
    print(f"  SQL:    {SQL_OUT}")
    print(f"  Total fixes generated: {fix_count}")
    if invalid_factions:
        total_invalid_npcs = sum(len(v) for v in invalid_npcs.values())
        print(f"  Invalid faction IDs: {len(invalid_factions)} "
              f"affecting {total_invalid_npcs} NPCs")
    print(f"  Hostile service NPCs: {len(hostile_service_npcs)}")


if __name__ == '__main__':
    main()

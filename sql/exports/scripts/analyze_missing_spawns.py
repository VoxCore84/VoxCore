#!/usr/bin/env python3
"""
analyze_missing_spawns.py — Analyze and prioritize NPCs with Wowhead coords but zero DB spawns.

Data sources:
  - Wowhead spawn summary CSV (id, zone_id, total_coords)
  - Wowhead roles CSV (id, subtitle, detected_roles)
  - Wowhead subtitles CSV (id, subtitle)
  - MySQL world DB: creature_template, creature, creature_queststarter, creature_questender
  - AreaTable DB2 CSV for zone name resolution

Output: missing_spawns_report.txt with tiered priority breakdown.
"""

import csv
import subprocess
import sys
import os
from collections import defaultdict
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────────
WOWHEAD_DIR = "C:/Users/atayl/source/wago/wowhead_data/npc"
SPAWN_SUMMARY_CSV = os.path.join(WOWHEAD_DIR, "npc_spawn_summary.csv")
ROLES_CSV = os.path.join(WOWHEAD_DIR, "npc_roles.csv")
SUBTITLES_CSV = os.path.join(WOWHEAD_DIR, "npc_subtitles.csv")
AREA_TABLE_CSV = "C:/Users/atayl/source/wago/wago_csv/major_12/12.0.1.66220/enUS/AreaTable-enUS.csv"
REPORT_PATH = "C:/Dev/RoleplayCore/sql/exports/cleanup/missing_spawns_report.txt"
MYSQL_BIN = "C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe"
MYSQL_USER = "root"
MYSQL_PASS = "admin"
MYSQL_DB = "world"

# ── NPC type enum (TrinityCore creature_template.type) ─────────────────────────
NPC_TYPES = {
    0: "None",
    1: "Beast",
    2: "Dragonkin",
    3: "Demon",
    4: "Elemental",
    5: "Giant",
    6: "Undead",
    7: "Humanoid",
    8: "Critter",
    9: "Mechanical",
    10: "Not specified",
    11: "Totem",
    12: "Non-combat Pet",
    13: "Gas Cloud",
    14: "Wild Pet",
    15: "Aberration",
}

# ── Expansion map (RequiredExpansion -> name) ──────────────────────────────────
EXPANSION_NAMES = {
    -3: "Unknown (-3)",
    0: "Classic (Vanilla)",
    1: "The Burning Crusade",
    2: "Wrath of the Lich King",
    3: "Cataclysm",
    4: "Mists of Pandaria",
    5: "Warlords of Draenor",
    6: "Legion",
    7: "Battle for Azeroth",
    8: "Shadowlands",
    9: "Dragonflight",
    10: "The War Within",
    11: "Midnight",
}

# ── Npcflag bit definitions (relevant service NPCs) ───────────────────────────
NPCFLAG_GOSSIP          = 0x1
NPCFLAG_QUESTGIVER      = 0x2
NPCFLAG_TRAINER          = 0x10
NPCFLAG_VENDOR           = 0x80
NPCFLAG_REPAIR           = 0x1000
NPCFLAG_FLIGHTMASTER     = 0x2000
NPCFLAG_INNKEEPER        = 0x10000
NPCFLAG_BANKER           = 0x20000
NPCFLAG_AUCTIONEER       = 0x200000
NPCFLAG_STABLEMASTER     = 0x400000
NPCFLAG_MAILBOX          = 0x4000000
NPCFLAG_TRANSMOGRIFIER   = 0x10000000

# Zone-to-expansion heuristic ranges (AreaTable ID ranges by expansion)
# These are approximate — overlapping ranges exist, but good enough for bucketing
ZONE_EXPANSION_RANGES = [
    # (min_id, max_id, expansion_name)
    (0,     999,  "Classic"),
    (1000,  1999, "Classic"),
    (2000,  2999, "Classic"),
    (3000,  3599, "Classic / TBC"),
    (3430,  3430, "TBC"),        # Eversong Woods
    (3433,  3433, "TBC"),        # Ghostlands
    (3483,  3483, "TBC"),        # Hellfire Peninsula
    (3487,  3487, "TBC"),        # Silvermoon City
    (3518,  3518, "TBC"),        # Nagrand (Outland)
    (3519,  3519, "TBC"),        # Terokkar Forest
    (3520,  3520, "TBC"),        # Shadowmoon Valley (Outland)
    (3521,  3521, "TBC"),        # Zangarmarsh
    (3522,  3522, "TBC"),        # Blade's Edge Mountains
    (3523,  3523, "TBC"),        # Netherstorm
    (3524,  3524, "TBC"),        # Azuremyst Isle
    (3525,  3525, "TBC"),        # Bloodmyst Isle
    (3537,  3537, "TBC"),        # Shattrath City
    (3557,  3557, "TBC"),        # Exodar
    (3600,  3999, "TBC"),
    (4000,  4399, "WotLK"),
    (4395,  4395, "WotLK"),      # Dalaran (Northrend)
    (4400,  4799, "Cataclysm"),
    (4706,  4706, "Cataclysm"),  # Ruins of Gilneas
    (4714,  4714, "Cataclysm"),  # Gilneas
    (4720,  4720, "Cataclysm"),  # Lost Isles
    (4737,  4737, "Cataclysm"),  # Kezan
    (4800,  5599, "MoP"),
    (5600,  6799, "WoD"),
    (6800,  7999, "Legion"),
    (8000,  9499, "BfA"),
    (9500, 10999, "Shadowlands"),
    (11000, 13499, "Dragonflight"),
    (13500, 14999, "TWW"),
    (15000, 19999, "Midnight"),
]


def run_mysql(query):
    """Run a MySQL query and return rows as list of tuples.
    Uses a temp SQL file to avoid Windows command-line length limits.
    """
    import tempfile
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sql', delete=False, encoding='utf-8') as f:
        f.write(query)
        tmp_path = f.name
    try:
        cmd = [MYSQL_BIN, "-u", MYSQL_USER, f"-p{MYSQL_PASS}", "-N", "-B", MYSQL_DB]
        with open(tmp_path, 'r', encoding='utf-8') as sql_file:
            result = subprocess.run(cmd, stdin=sql_file, capture_output=True, text=True, timeout=120)
        if result.returncode != 0:
            print(f"MySQL error: {result.stderr}", file=sys.stderr)
            sys.exit(1)
        rows = []
        for line in result.stdout.strip().split('\n'):
            if line:
                rows.append(line.split('\t'))
        return rows
    finally:
        os.unlink(tmp_path)


def load_csv_dict(path, key_col='id'):
    """Load CSV into dict keyed by key_col (as int)."""
    data = {}
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                entry_id = int(row[key_col])
                data[entry_id] = row
            except (ValueError, KeyError):
                continue
    return data


def load_spawn_summary():
    """Load spawn summary: returns dict of entry -> list of (zone_id, total_coords)."""
    spawns = defaultdict(list)
    with open(SPAWN_SUMMARY_CSV, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                entry_id = int(row['id'])
                zone_id = int(row['zone_id'])
                total_coords = int(row['total_coords'])
                spawns[entry_id].append((zone_id, total_coords))
            except (ValueError, KeyError):
                continue
    return spawns


def load_area_table():
    """Load AreaTable DB2 CSV: returns dict of ID -> (ZoneName, AreaName)."""
    areas = {}
    with open(AREA_TABLE_CSV, 'r', encoding='utf-8', errors='replace') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                area_id = int(row['ID'])
                zone_name = row.get('ZoneName', '')
                area_name = row.get('AreaName_lang', '')
                parent_id = int(row.get('ParentAreaID', 0))
                areas[area_id] = {
                    'zone_name': zone_name,
                    'area_name': area_name,
                    'parent_id': parent_id,
                }
            except (ValueError, KeyError):
                continue
    return areas


def get_zone_expansion(zone_id, area_table):
    """Heuristically determine expansion from zone ID."""
    # Check specific known ranges
    for min_id, max_id, exp_name in sorted(ZONE_EXPANSION_RANGES, key=lambda x: (x[1] - x[0])):
        if min_id <= zone_id <= max_id:
            return exp_name
    if zone_id > 15000:
        return "Midnight+"
    return "Unknown"


def decode_npcflags(npcflag):
    """Decode npcflag bitmask into list of role strings."""
    roles = []
    if npcflag & NPCFLAG_QUESTGIVER:
        roles.append("questgiver")
    if npcflag & NPCFLAG_VENDOR:
        roles.append("vendor")
    if npcflag & NPCFLAG_TRAINER:
        roles.append("trainer")
    if npcflag & NPCFLAG_REPAIR:
        roles.append("repair")
    if npcflag & NPCFLAG_FLIGHTMASTER:
        roles.append("flight_master")
    if npcflag & NPCFLAG_INNKEEPER:
        roles.append("innkeeper")
    if npcflag & NPCFLAG_BANKER:
        roles.append("banker")
    if npcflag & NPCFLAG_AUCTIONEER:
        roles.append("auctioneer")
    if npcflag & NPCFLAG_STABLEMASTER:
        roles.append("stable_master")
    if npcflag & NPCFLAG_MAILBOX:
        roles.append("mailbox")
    if npcflag & NPCFLAG_TRANSMOGRIFIER:
        roles.append("transmogrifier")
    return roles


def classify_priority(npc):
    """
    Classify NPC into priority tier.
    Returns (tier, reason) where tier is 0=CRITICAL, 1=HIGH, 2=MEDIUM, 3=LOW.
    """
    has_quest = npc.get('has_quest', False)
    db_roles = npc.get('db_roles', [])
    wh_roles = npc.get('wh_roles', [])
    npc_type = npc.get('type', 10)
    name = npc.get('name', '')
    subtitle = npc.get('subtitle', '')
    classification = npc.get('classification', 0)

    all_roles = set(db_roles + wh_roles)

    # CRITICAL: Quest givers/enders with no spawn
    if has_quest:
        if 'questgiver' in all_roles or any(r in all_roles for r in ['vendor', 'trainer', 'flight_master']):
            return (0, f"Quest NPC + {', '.join(all_roles)}")
        return (0, "Quest NPC (starter/ender)")

    # HIGH: Service NPCs
    high_roles = {'vendor', 'trainer', 'flight_master', 'innkeeper', 'stable_master',
                  'repair', 'banker', 'auctioneer', 'transmogrifier', 'mailbox'}
    matching_high = all_roles & high_roles
    if matching_high:
        return (1, ', '.join(sorted(matching_high)))

    # Critters and non-combat pets are always LOW
    if npc_type in (8, 12):  # Critter, Non-combat Pet
        return (3, f"Critter/Pet (type={npc_type})")

    # Totems, gas clouds always LOW
    if npc_type in (11, 13):
        return (3, f"Totem/Gas Cloud (type={npc_type})")

    # MEDIUM: Named NPCs with subtitle or classification (rare/elite)
    if subtitle and subtitle not in ('(Normal)', 'Humanoid (Normal)', 'NPC'):
        return (2, f"Named NPC: {subtitle}")

    if classification in (1, 2, 3, 4):  # Elite, Rare Elite, Boss, Rare
        class_names = {1: "Elite", 2: "Rare Elite", 3: "Boss", 4: "Rare"}
        return (2, f"{class_names.get(classification, 'Special')} creature")

    # Humanoids with gossip flag are likely interactive NPCs
    if npc_type == 7 and 'gossip' not in str(db_roles):
        # Check if name looks like a named NPC (not generic)
        generic_patterns = ['Citizen', 'Guard', 'Grunt', 'Soldier', 'Footman',
                           'Peasant', 'Villager', 'Refugee', 'Militia',
                           'Defender', 'Protector', 'Sentinel', 'Watcher']
        is_generic = any(p.lower() in name.lower() for p in generic_patterns)
        if not is_generic and name and not name.startswith('['):
            return (2, "Named humanoid NPC")

    # LOW: Everything else
    return (3, f"Generic mob (type={NPC_TYPES.get(npc_type, 'Unknown')})")


def main():
    print("=" * 70)
    print("Missing NPC Spawn Analyzer")
    print("=" * 70)

    # ── Step 1: Load Wowhead data ──────────────────────────────────────────
    print("\n[1/7] Loading Wowhead spawn summary...")
    wh_spawns = load_spawn_summary()
    wh_entries = set(wh_spawns.keys())
    print(f"  Loaded {len(wh_entries):,} unique NPCs with Wowhead coordinates")

    print("[2/7] Loading Wowhead roles...")
    wh_roles = load_csv_dict(ROLES_CSV)
    print(f"  Loaded {len(wh_roles):,} role entries")

    print("[3/7] Loading Wowhead subtitles...")
    wh_subtitles = load_csv_dict(SUBTITLES_CSV)
    print(f"  Loaded {len(wh_subtitles):,} subtitle entries")

    print("[4/7] Loading AreaTable...")
    area_table = load_area_table()
    print(f"  Loaded {len(area_table):,} area entries")

    # ── Step 2: Query MySQL for spawned NPCs ───────────────────────────────
    print("[5/7] Querying MySQL for existing creature spawns...")
    # Get distinct entries that have at least one spawn
    rows = run_mysql("SELECT DISTINCT id FROM creature")
    spawned_entries = set(int(r[0]) for r in rows)
    print(f"  Found {len(spawned_entries):,} distinct NPC entries with spawns")

    # Find missing
    missing_entries = wh_entries - spawned_entries
    print(f"  >>> {len(missing_entries):,} NPCs have Wowhead coords but ZERO DB spawns")

    if not missing_entries:
        print("  No missing spawns found. Exiting.")
        return

    # ── Step 3: Get creature_template data for missing entries ─────────────
    print("[6/7] Querying creature_template for missing NPCs...")

    # Query in batches to avoid MySQL command-line length limits
    template_data = {}
    batch_size = 5000
    missing_list = sorted(missing_entries)

    for i in range(0, len(missing_list), batch_size):
        batch = missing_list[i:i + batch_size]
        ids_str = ','.join(str(e) for e in batch)
        query = (f"SELECT entry, REPLACE(IFNULL(name,''),'\\t',' '), "
                 f"REPLACE(IFNULL(subname,''),'\\t',' '), "
                 f"type, npcflag, Classification, RequiredExpansion "
                 f"FROM creature_template WHERE entry IN ({ids_str})")
        rows = run_mysql(query)
        for r in rows:
            if len(r) < 7:
                # Skip malformed rows
                continue
            entry = int(r[0])
            template_data[entry] = {
                'name': r[1],
                'subname': r[2],
                'type': int(r[3]),
                'npcflag': int(r[4]),
                'classification': int(r[5]),
                'expansion': int(r[6]),
            }
        print(f"  Batch {i // batch_size + 1}: fetched {len(rows)} templates "
              f"({i + len(batch)}/{len(missing_list)})")

    print(f"  Got template data for {len(template_data):,} of {len(missing_entries):,} missing NPCs")

    # Entries with Wowhead coords but NOT in creature_template at all
    no_template = missing_entries - set(template_data.keys())
    print(f"  {len(no_template):,} missing NPCs have NO creature_template entry (not in DB at all)")

    # ── Step 4: Get quest associations ─────────────────────────────────────
    print("[7/7] Querying quest associations...")
    quest_npcs = set()

    for table in ['creature_queststarter', 'creature_questender']:
        ids_str = ','.join(str(e) for e in sorted(template_data.keys()))
        if not ids_str:
            continue
        # Batch this too
        for i in range(0, len(missing_list), batch_size):
            batch = [e for e in missing_list[i:i + batch_size] if e in template_data]
            if not batch:
                continue
            ids_str = ','.join(str(e) for e in batch)
            query = f"SELECT DISTINCT id FROM {table} WHERE id IN ({ids_str})"
            rows = run_mysql(query)
            for r in rows:
                quest_npcs.add(int(r[0]))

    print(f"  Found {len(quest_npcs):,} missing NPCs with quest associations")

    # ── Build NPC records ──────────────────────────────────────────────────
    print("\nBuilding analysis records...")
    npcs = {}
    for entry in sorted(template_data.keys()):
        td = template_data[entry]
        # Wowhead roles
        wh_role_list = []
        if entry in wh_roles:
            roles_str = wh_roles[entry].get('detected_roles', '')
            if roles_str:
                wh_role_list = [r.strip() for r in roles_str.split(',') if r.strip()]

        # Subtitle from Wowhead or DB
        subtitle = ''
        if entry in wh_subtitles:
            subtitle = wh_subtitles[entry].get('subtitle', '')
        if not subtitle and td['subname']:
            subtitle = td['subname']

        # DB-derived roles from npcflag
        db_role_list = decode_npcflags(td['npcflag'])

        # Zone info from Wowhead
        zones = wh_spawns.get(entry, [])
        primary_zone = zones[0][0] if zones else 0
        total_coords = sum(z[1] for z in zones)

        npcs[entry] = {
            'entry': entry,
            'name': td['name'],
            'subtitle': subtitle,
            'type': td['type'],
            'npcflag': td['npcflag'],
            'classification': td['classification'],
            'expansion': td['expansion'],
            'db_roles': db_role_list,
            'wh_roles': wh_role_list,
            'has_quest': entry in quest_npcs,
            'zones': zones,
            'primary_zone': primary_zone,
            'total_coords': total_coords,
        }

    # ── Classify ───────────────────────────────────────────────────────────
    print("Classifying NPCs by priority...")
    tiers = {0: [], 1: [], 2: [], 3: []}  # CRITICAL, HIGH, MEDIUM, LOW
    tier_names = {0: "CRITICAL", 1: "HIGH", 2: "MEDIUM", 3: "LOW"}

    for entry, npc in npcs.items():
        tier, reason = classify_priority(npc)
        npc['tier'] = tier
        npc['tier_reason'] = reason
        tiers[tier].append(npc)

    # Sort each tier by entry ID
    for tier in tiers:
        tiers[tier].sort(key=lambda n: n['entry'])

    # ── Zone breakdown ─────────────────────────────────────────────────────
    print("Computing zone breakdown...")
    zone_counts = defaultdict(lambda: defaultdict(int))  # zone_id -> tier -> count
    zone_total = defaultdict(int)

    for entry, npc in npcs.items():
        for zone_id, _ in npc['zones']:
            zone_counts[zone_id][npc['tier']] += 1
            zone_total[zone_id] += 1

    # ── Expansion breakdown ────────────────────────────────────────────────
    print("Computing expansion breakdown...")
    exp_counts = defaultdict(lambda: defaultdict(int))  # expansion -> tier -> count

    for entry, npc in npcs.items():
        exp = npc['expansion']
        exp_name = EXPANSION_NAMES.get(exp, f"Unknown ({exp})")
        exp_counts[exp_name][npc['tier']] += 1

    # Also compute by zone-based expansion heuristic
    zone_exp_counts = defaultdict(lambda: defaultdict(int))
    for entry, npc in npcs.items():
        if npc['zones']:
            zone_id = npc['zones'][0][0]
            exp_name = get_zone_expansion(zone_id, area_table)
            zone_exp_counts[exp_name][npc['tier']] += 1

    # ── Generate Report ────────────────────────────────────────────────────
    print("\nGenerating report...")

    def zone_name(zone_id):
        if zone_id in area_table:
            a = area_table[zone_id]
            return a['area_name'] or a['zone_name'] or f"Zone {zone_id}"
        return f"Zone {zone_id}"

    def format_npc_line(npc):
        roles = sorted(set(npc['db_roles'] + npc['wh_roles']))
        role_str = ', '.join(roles) if roles else '-'
        zones = [zone_name(z[0]) for z in npc['zones'][:3]]
        zone_str = ' / '.join(zones)
        if len(npc['zones']) > 3:
            zone_str += f" (+{len(npc['zones']) - 3} more)"
        quest_flag = " [QUEST]" if npc['has_quest'] else ""
        sub = f" <{npc['subtitle']}>" if npc['subtitle'] else ""
        return (f"  {npc['entry']:>8}  {npc['name'][:40]:<40}{sub:<30} "
                f"Roles: {role_str:<30} Zone: {zone_str}{quest_flag}")

    lines = []
    lines.append("=" * 120)
    lines.append("MISSING NPC SPAWN ANALYSIS REPORT")
    lines.append(f"Generated: 2026-03-01")
    lines.append("=" * 120)

    # ── Summary ────────────────────────────────────────────────────────────
    lines.append("")
    lines.append("SUMMARY")
    lines.append("-" * 80)
    lines.append(f"Total NPCs with Wowhead coords:           {len(wh_entries):>8,}")
    lines.append(f"Total NPCs with DB spawns:                 {len(spawned_entries):>8,}")
    lines.append(f"Total missing spawns (Wowhead - DB):       {len(missing_entries):>8,}")
    lines.append(f"  - Have creature_template entry:           {len(template_data):>8,}")
    lines.append(f"  - No creature_template (unknown to DB):   {len(no_template):>8,}")
    lines.append(f"  - Have quest associations:                {len(quest_npcs):>8,}")
    lines.append("")

    # ── Priority Tier Counts ───────────────────────────────────────────────
    lines.append("PRIORITY TIER BREAKDOWN")
    lines.append("-" * 80)
    for tier in sorted(tiers.keys()):
        count = len(tiers[tier])
        pct = (count / len(npcs) * 100) if npcs else 0
        lines.append(f"  {tier_names[tier]:<10}  {count:>8,}  ({pct:5.1f}%)  ", )

    lines.append(f"  {'TOTAL':<10}  {len(npcs):>8,}")
    lines.append(f"  (+ {len(no_template):,} with no creature_template, not classified)")
    lines.append("")

    # ── CRITICAL tier detail ───────────────────────────────────────────────
    lines.append("")
    lines.append("=" * 120)
    lines.append(f"CRITICAL PRIORITY — Quest NPCs Missing Spawns ({len(tiers[0]):,} entries)")
    lines.append("=" * 120)
    lines.append("  These NPCs are quest starters or enders. Players CANNOT complete")
    lines.append("  these quests without a spawn.")
    lines.append("")
    lines.append(f"  {'Entry':>8}  {'Name':<40}{'Subtitle':<30} {'Roles':<30} {'Zone'}")
    lines.append(f"  {'-----':>8}  {'----':<40}{'--------':<30} {'-----':<30} {'----'}")

    for npc in tiers[0]:
        lines.append(format_npc_line(npc))

    # ── HIGH tier detail ───────────────────────────────────────────────────
    lines.append("")
    lines.append("=" * 120)
    lines.append(f"HIGH PRIORITY — Service NPCs Missing Spawns ({len(tiers[1]):,} entries)")
    lines.append("=" * 120)
    lines.append("  Vendors, trainers, flight masters, innkeepers, etc. without spawns.")
    lines.append("")
    lines.append(f"  {'Entry':>8}  {'Name':<40}{'Subtitle':<30} {'Roles':<30} {'Zone'}")
    lines.append(f"  {'-----':>8}  {'----':<40}{'--------':<30} {'-----':<30} {'----'}")

    for npc in tiers[1]:
        lines.append(format_npc_line(npc))

    # ── MEDIUM tier summary ────────────────────────────────────────────────
    lines.append("")
    lines.append("=" * 120)
    lines.append(f"MEDIUM PRIORITY — Named/Notable NPCs ({len(tiers[2]):,} entries)")
    lines.append("=" * 120)
    lines.append("  Named NPCs with subtitles, elites, rares, bosses. First 500 shown.")
    lines.append("")
    lines.append(f"  {'Entry':>8}  {'Name':<40}{'Subtitle':<30} {'Roles':<30} {'Zone'}")
    lines.append(f"  {'-----':>8}  {'----':<40}{'--------':<30} {'-----':<30} {'----'}")

    for npc in tiers[2][:500]:
        lines.append(format_npc_line(npc))

    if len(tiers[2]) > 500:
        lines.append(f"  ... and {len(tiers[2]) - 500:,} more MEDIUM priority NPCs not shown")

    # ── LOW tier summary (count only) ──────────────────────────────────────
    lines.append("")
    lines.append("=" * 120)
    lines.append(f"LOW PRIORITY — Generic Mobs/Critters ({len(tiers[3]):,} entries)")
    lines.append("=" * 120)
    lines.append("  Generic mobs, critters, ambient creatures. Not listed individually.")
    lines.append("")

    # Type breakdown within LOW
    low_type_counts = defaultdict(int)
    for npc in tiers[3]:
        low_type_counts[NPC_TYPES.get(npc['type'], f"Type {npc['type']}")] += 1
    lines.append("  Breakdown by creature type:")
    for type_name, count in sorted(low_type_counts.items(), key=lambda x: -x[1]):
        lines.append(f"    {type_name:<25} {count:>6,}")

    # ── Zone breakdown ─────────────────────────────────────────────────────
    lines.append("")
    lines.append("=" * 120)
    lines.append("ZONE BREAKDOWN — Top 100 zones by missing NPC count")
    lines.append("=" * 120)
    lines.append("")
    lines.append(f"  {'Zone':<45} {'Total':>7} {'CRIT':>6} {'HIGH':>6} {'MED':>6} {'LOW':>6}")
    lines.append(f"  {'-' * 45} {'-----':>7} {'----':>6} {'----':>6} {'---':>6} {'---':>6}")

    top_zones = sorted(zone_total.items(), key=lambda x: -x[1])[:100]
    for zone_id, total in top_zones:
        zn = zone_name(zone_id)[:45]
        c = zone_counts[zone_id]
        lines.append(f"  {zn:<45} {total:>7,} {c[0]:>6,} {c[1]:>6,} {c[2]:>6,} {c[3]:>6,}")

    # ── Expansion breakdown (from RequiredExpansion) ───────────────────────
    lines.append("")
    lines.append("=" * 120)
    lines.append("EXPANSION BREAKDOWN (from creature_template.RequiredExpansion)")
    lines.append("=" * 120)
    lines.append("")
    lines.append(f"  {'Expansion':<35} {'Total':>7} {'CRIT':>6} {'HIGH':>6} {'MED':>6} {'LOW':>6}")
    lines.append(f"  {'-' * 35} {'-----':>7} {'----':>6} {'----':>6} {'---':>6} {'---':>6}")

    for exp_name in sorted(exp_counts.keys()):
        c = exp_counts[exp_name]
        total = sum(c.values())
        lines.append(f"  {exp_name:<35} {total:>7,} {c[0]:>6,} {c[1]:>6,} {c[2]:>6,} {c[3]:>6,}")

    # ── Expansion breakdown (zone-based heuristic) ─────────────────────────
    lines.append("")
    lines.append("=" * 120)
    lines.append("EXPANSION BREAKDOWN (zone-based heuristic from Wowhead zone IDs)")
    lines.append("=" * 120)
    lines.append("")
    lines.append(f"  {'Expansion':<35} {'Total':>7} {'CRIT':>6} {'HIGH':>6} {'MED':>6} {'LOW':>6}")
    lines.append(f"  {'-' * 35} {'-----':>7} {'----':>6} {'----':>6} {'---':>6} {'---':>6}")

    for exp_name in sorted(zone_exp_counts.keys()):
        c = zone_exp_counts[exp_name]
        total = sum(c.values())
        lines.append(f"  {exp_name:<35} {total:>7,} {c[0]:>6,} {c[1]:>6,} {c[2]:>6,} {c[3]:>6,}")

    # ── Top CRITICAL zones ─────────────────────────────────────────────────
    lines.append("")
    lines.append("=" * 120)
    lines.append("TOP ZONES WITH CRITICAL MISSING NPCs")
    lines.append("=" * 120)
    lines.append("")

    crit_zones = defaultdict(list)
    for npc in tiers[0]:
        for zone_id, _ in npc['zones']:
            crit_zones[zone_id].append(npc)

    crit_zones_sorted = sorted(crit_zones.items(), key=lambda x: -len(x[1]))[:30]
    for zone_id, zone_npcs in crit_zones_sorted:
        zn = zone_name(zone_id)
        lines.append(f"  {zn} ({len(zone_npcs)} critical NPCs):")
        for npc in zone_npcs[:10]:
            roles = sorted(set(npc['db_roles'] + npc['wh_roles']))
            role_str = ', '.join(roles) if roles else '-'
            lines.append(f"    {npc['entry']:>8}  {npc['name']:<40} {role_str}")
        if len(zone_npcs) > 10:
            lines.append(f"    ... and {len(zone_npcs) - 10} more")
        lines.append("")

    # ── Actionable Stats ───────────────────────────────────────────────────
    lines.append("")
    lines.append("=" * 120)
    lines.append("ACTIONABLE STATISTICS")
    lines.append("=" * 120)
    lines.append("")

    crit_high = len(tiers[0]) + len(tiers[1])
    lines.append(f"  CRITICAL + HIGH combined:       {crit_high:>8,} NPCs need spawns urgently")
    lines.append(f"  Unique zones with CRITICAL:     {len(crit_zones):>8,} zones")

    # Wowhead coord counts for CRITICAL
    crit_coords = sum(npc['total_coords'] for npc in tiers[0])
    high_coords = sum(npc['total_coords'] for npc in tiers[1])
    lines.append(f"  Wowhead coords for CRITICAL:    {crit_coords:>8,} coordinate sets available")
    lines.append(f"  Wowhead coords for HIGH:        {high_coords:>8,} coordinate sets available")
    lines.append("")
    lines.append("  NOTE: Wowhead coordinates are map percentages (0-100), NOT world XYZ.")
    lines.append("  A separate coordinate transformation pipeline is needed to generate")
    lines.append("  INSERT statements for the creature table.")

    # ── No-template NPCs ──────────────────────────────────────────────────
    if no_template:
        lines.append("")
        lines.append("=" * 120)
        lines.append(f"NPCs WITH NO creature_template ({len(no_template):,} entries)")
        lines.append("=" * 120)
        lines.append("  These NPCs exist on Wowhead but have no creature_template row.")
        lines.append("  They may be entirely missing from the DB (need full template + spawn).")
        lines.append("")

        # Show zone breakdown for no-template NPCs
        no_tmpl_zones = defaultdict(int)
        for entry in no_template:
            for zone_id, _ in wh_spawns.get(entry, []):
                no_tmpl_zones[zone_id] += 1

        lines.append("  Top zones for no-template NPCs:")
        for zone_id, count in sorted(no_tmpl_zones.items(), key=lambda x: -x[1])[:30]:
            zn = zone_name(zone_id)
            lines.append(f"    {zn:<45} {count:>6,}")

        # Show some sample entries
        lines.append("")
        lines.append("  Sample entries (first 50):")
        for entry in sorted(no_template)[:50]:
            zones = [zone_name(z[0]) for z in wh_spawns.get(entry, [])[:2]]
            zone_str = ' / '.join(zones) if zones else 'unknown'
            lines.append(f"    {entry:>8}  Zone: {zone_str}")

    lines.append("")
    lines.append("=" * 120)
    lines.append("END OF REPORT")
    lines.append("=" * 120)

    # ── Write report ───────────────────────────────────────────────────────
    os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
    with open(REPORT_PATH, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    print(f"\nReport written to: {REPORT_PATH}")
    print(f"  Total lines: {len(lines):,}")
    print(f"\nQuick summary:")
    for tier in sorted(tiers.keys()):
        print(f"  {tier_names[tier]:<10}: {len(tiers[tier]):>8,}")
    print(f"  No template: {len(no_template):>8,}")


if __name__ == '__main__':
    main()

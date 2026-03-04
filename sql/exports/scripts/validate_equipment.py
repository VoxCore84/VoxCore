#!/usr/bin/env python3
"""
Validate creature_equip_template item IDs against ItemSparse DB2 and hotfixes.item.

Finds:
  - Invalid item IDs (not in ItemSparse or hotfixes.item)
  - Item type mismatches (weapon in offhand-only slot, shield in mainhand, etc.)
  - Prioritizes by whether the creature is spawned in the world

Outputs:
  - equipment_validation_report.txt  (full report)
  - npc_equipment_fixes.sql          (SQL to zero out invalid slots on spawned NPCs)
"""

import csv
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

# --- Configuration ---
MYSQL = r"C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe"
MYSQL_USER = "root"
MYSQL_PASS = "admin"

ITEMSPARSE_CSV = Path(
    r"C:/Users/atayl/source/wago/wago_csv/major_12/12.0.1.66220/enUS/ItemSparse-enUS.csv"
)

REPORT_PATH = Path(r"C:/Dev/RoleplayCore/sql/exports/cleanup/equipment_validation_report.txt")
SQL_PATH = Path(r"C:/Dev/RoleplayCore/sql/exports/cleanup/npc_equipment_fixes.sql")

# InventoryType enum (relevant subset)
INV_TYPE = {
    0: "Non-equip",
    1: "Head",
    2: "Neck",
    3: "Shoulder",
    4: "Body/Shirt",
    5: "Chest",
    6: "Waist",
    7: "Legs",
    8: "Feet",
    9: "Wrists",
    10: "Hands",
    11: "Finger",
    12: "Trinket",
    13: "One-Hand",
    14: "Shield",
    15: "Ranged",
    16: "Cloak",
    17: "Two-Hand",
    18: "Bag",
    20: "Robe",
    21: "Main Hand",
    22: "Off Hand",
    23: "Holdable",
    24: "Ammo",
    25: "Thrown",
    26: "Ranged Right",
    28: "Relic",
}

# Valid inventory types for each equipment slot
# Slot 1 = Main Hand: weapons + shields (some NPCs dual-wield shields for visuals)
# Slot 2 = Off Hand: shields, off-hand items, one-hand weapons (dual wield)
# Slot 3 = Ranged: ranged weapons
VALID_SLOT1_INVTYPES = {0, 13, 14, 15, 17, 21, 22, 23, 25, 26}  # weapons, shields (visual)
VALID_SLOT2_INVTYPES = {0, 13, 14, 15, 22, 23, 25, 26}  # offhand, shield, one-hand
VALID_SLOT3_INVTYPES = {0, 15, 25, 26}  # ranged


def run_mysql(query, database="world"):
    """Run a MySQL query and return rows as list of tuples."""
    cmd = [
        MYSQL, "-u", MYSQL_USER, f"-p{MYSQL_PASS}",
        "--batch", "--skip-column-names",
        "-e", query,
        database,
    ]
    result = subprocess.run(cmd, capture_output=True, encoding="latin1")
    if result.returncode != 0:
        print(f"MySQL error: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    rows = []
    stdout = result.stdout or ""
    for line in stdout.strip().split("\n"):
        if line:
            rows.append(tuple(line.split("\t")))
    return rows


def load_itemsparse():
    """Load ItemSparse CSV. Returns dict of {item_id: (name, inventory_type)}."""
    print(f"Loading ItemSparse from {ITEMSPARSE_CSV} ...")
    items = {}
    with open(ITEMSPARSE_CSV, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            item_id = int(row["ID"])
            name = row.get("Display_lang", "")
            inv_type = int(row.get("InventoryType", 0))
            items[item_id] = (name, inv_type)
    print(f"  Loaded {len(items):,} items from ItemSparse.")
    return items


def load_hotfixes_items():
    """Load hotfixes.item table. Returns dict of {item_id: (classID, subclassID, inventoryType)}."""
    print("Loading hotfixes.item from MySQL ...")
    rows = run_mysql("SELECT ID, ClassID, SubclassID, InventoryType FROM item;", "hotfixes")
    items = {}
    for row in rows:
        item_id = int(row[0])
        class_id = int(row[1])
        subclass_id = int(row[2])
        inv_type = int(row[3])
        items[item_id] = (class_id, subclass_id, inv_type)
    print(f"  Loaded {len(items):,} items from hotfixes.item.")
    return items


def load_equipment():
    """Load creature_equip_template. Returns list of dicts."""
    print("Loading creature_equip_template from MySQL ...")
    rows = run_mysql(
        "SELECT CreatureID, ID, ItemID1, ItemID2, ItemID3 FROM creature_equip_template;"
    )
    equip = []
    for row in rows:
        equip.append({
            "CreatureID": int(row[0]),
            "SetID": int(row[1]),
            "ItemID1": int(row[2]),
            "ItemID2": int(row[3]),
            "ItemID3": int(row[4]),
        })
    print(f"  Loaded {len(equip):,} equipment rows.")
    return equip


def load_spawned_creatures():
    """Load set of creature template IDs that have spawns in the creature table."""
    print("Loading spawned creature IDs from MySQL ...")
    rows = run_mysql("SELECT DISTINCT id FROM creature;")
    spawned = set()
    for row in rows:
        spawned.add(int(row[0]))
    print(f"  Found {len(spawned):,} distinct spawned creature template IDs.")
    return spawned


def load_creature_names():
    """Load creature names for reporting. Strip newlines from names to avoid parsing issues."""
    print("Loading creature names from MySQL ...")
    rows = run_mysql(
        "SELECT entry, REPLACE(REPLACE(IFNULL(name, ''), '\\n', ' '), '\\r', ' ') FROM creature_template;"
    )
    names = {}
    for row in rows:
        try:
            if len(row) >= 2:
                names[int(row[0])] = row[1]
            elif len(row) == 1:
                names[int(row[0])] = ""
        except (ValueError, IndexError):
            continue  # Skip rows with non-numeric entries (broken name data)
    print(f"  Loaded {len(names):,} creature template names.")
    return names


def get_inv_type(item_id, itemsparse, hotfix_items):
    """Get inventory type for an item, checking ItemSparse first, then hotfixes."""
    if item_id in itemsparse:
        return itemsparse[item_id][1]  # (name, inv_type)
    if item_id in hotfix_items:
        return hotfix_items[item_id][2]  # (classID, subclassID, inv_type)
    return None


def get_item_name(item_id, itemsparse):
    """Get item name from ItemSparse."""
    if item_id in itemsparse:
        return itemsparse[item_id][0]
    return "(unknown)"


def validate():
    # Load all data sources
    itemsparse = load_itemsparse()
    hotfix_items = load_hotfixes_items()
    equipment = load_equipment()
    spawned = load_spawned_creatures()
    creature_names = load_creature_names()

    # Combined valid item IDs (union of ItemSparse + hotfixes.item)
    all_valid_ids = set(itemsparse.keys()) | set(hotfix_items.keys())
    print(f"\nCombined valid item IDs: {len(all_valid_ids):,}")

    # --- Validation ---
    invalid_items = []      # (CreatureID, SetID, slot, item_id, is_spawned, creature_name)
    type_mismatches = []    # (CreatureID, SetID, slot, item_id, inv_type, inv_type_name, is_spawned, creature_name, item_name)

    stats = {
        "total_equip_rows": len(equipment),
        "total_item_refs": 0,
        "zero_item_refs": 0,
        "valid_item_refs": 0,
        "invalid_item_refs": 0,
        "type_mismatch_refs": 0,
        "invalid_spawned": 0,
        "invalid_unspawned": 0,
        "mismatch_spawned": 0,
        "mismatch_unspawned": 0,
    }

    for eq in equipment:
        cid = eq["CreatureID"]
        sid = eq["SetID"]
        is_spawned = cid in spawned
        cname = creature_names.get(cid, "(no template)")

        for slot_num, slot_key in [(1, "ItemID1"), (2, "ItemID2"), (3, "ItemID3")]:
            item_id = eq[slot_key]
            stats["total_item_refs"] += 1

            if item_id == 0:
                stats["zero_item_refs"] += 1
                continue

            if item_id not in all_valid_ids:
                stats["invalid_item_refs"] += 1
                if is_spawned:
                    stats["invalid_spawned"] += 1
                else:
                    stats["invalid_unspawned"] += 1
                invalid_items.append((cid, sid, slot_num, item_id, is_spawned, cname))
            else:
                stats["valid_item_refs"] += 1
                # Check type mismatch
                inv_type = get_inv_type(item_id, itemsparse, hotfix_items)
                if inv_type is not None:
                    mismatch = False
                    if slot_num == 1 and inv_type not in VALID_SLOT1_INVTYPES:
                        mismatch = True
                    elif slot_num == 2 and inv_type not in VALID_SLOT2_INVTYPES:
                        mismatch = True
                    elif slot_num == 3 and inv_type not in VALID_SLOT3_INVTYPES:
                        mismatch = True

                    if mismatch:
                        stats["type_mismatch_refs"] += 1
                        inv_name = INV_TYPE.get(inv_type, f"Unknown({inv_type})")
                        item_name = get_item_name(item_id, itemsparse)
                        if is_spawned:
                            stats["mismatch_spawned"] += 1
                        else:
                            stats["mismatch_unspawned"] += 1
                        type_mismatches.append((cid, sid, slot_num, item_id, inv_type, inv_name, is_spawned, cname, item_name))

    # Sort: spawned first, then by creature ID
    invalid_items.sort(key=lambda x: (not x[4], x[0], x[1], x[2]))
    type_mismatches.sort(key=lambda x: (not x[7], x[0], x[1], x[2]))

    # --- Generate Report ---
    print(f"\nGenerating report at {REPORT_PATH} ...")
    slot_names = {1: "MainHand", 2: "OffHand", 3: "Ranged"}

    with open(REPORT_PATH, "w", encoding="utf-8") as f:
        f.write("=" * 100 + "\n")
        f.write("CREATURE EQUIPMENT VALIDATION REPORT\n")
        f.write("=" * 100 + "\n\n")

        f.write("SUMMARY\n")
        f.write("-" * 60 + "\n")
        f.write(f"Total equipment rows:          {stats['total_equip_rows']:>8,}\n")
        f.write(f"Total item slot references:    {stats['total_item_refs']:>8,}\n")
        f.write(f"  Empty slots (item=0):        {stats['zero_item_refs']:>8,}\n")
        f.write(f"  Valid item references:        {stats['valid_item_refs']:>8,}\n")
        f.write(f"  Invalid item IDs:            {stats['invalid_item_refs']:>8,}\n")
        f.write(f"    Spawned NPCs:              {stats['invalid_spawned']:>8,}\n")
        f.write(f"    Unspawned NPCs:            {stats['invalid_unspawned']:>8,}\n")
        f.write(f"  Type mismatches:             {stats['type_mismatch_refs']:>8,}\n")
        f.write(f"    Spawned NPCs:              {stats['mismatch_spawned']:>8,}\n")
        f.write(f"    Unspawned NPCs:            {stats['mismatch_unspawned']:>8,}\n")
        f.write("\n")

        # Invalid items section
        f.write("=" * 100 + "\n")
        f.write(f"INVALID ITEM IDs ({stats['invalid_item_refs']} total)\n")
        f.write("Items that do not exist in ItemSparse DB2 or hotfixes.item\n")
        f.write("=" * 100 + "\n\n")

        if invalid_items:
            # Spawned first
            spawned_invalid = [x for x in invalid_items if x[4]]
            unspawned_invalid = [x for x in invalid_items if not x[4]]

            if spawned_invalid:
                f.write(f"--- SPAWNED NPCs ({len(spawned_invalid)} issues — VISIBLE TO PLAYERS) ---\n\n")
                f.write(f"{'CreatureID':>12}  {'Set':>3}  {'Slot':>10}  {'ItemID':>10}  Name\n")
                f.write(f"{'-'*12:>12}  {'-'*3:>3}  {'-'*10:>10}  {'-'*10:>10}  {'-'*40}\n")
                for cid, sid, slot, iid, _, cname in spawned_invalid:
                    f.write(f"{cid:>12}  {sid:>3}  {slot_names[slot]:>10}  {iid:>10}  {cname}\n")
                f.write("\n")

            if unspawned_invalid:
                f.write(f"--- UNSPAWNED NPCs ({len(unspawned_invalid)} issues — not visible) ---\n\n")
                f.write(f"{'CreatureID':>12}  {'Set':>3}  {'Slot':>10}  {'ItemID':>10}  Name\n")
                f.write(f"{'-'*12:>12}  {'-'*3:>3}  {'-'*10:>10}  {'-'*10:>10}  {'-'*40}\n")
                for cid, sid, slot, iid, _, cname in unspawned_invalid:
                    f.write(f"{cid:>12}  {sid:>3}  {slot_names[slot]:>10}  {iid:>10}  {cname}\n")
                f.write("\n")
        else:
            f.write("No invalid item IDs found.\n\n")

        # Type mismatches section — categorized
        f.write("=" * 100 + "\n")
        f.write(f"ITEM TYPE MISMATCHES ({stats['type_mismatch_refs']} total)\n")
        f.write("Items assigned to wrong equipment slot based on InventoryType\n")
        f.write("=" * 100 + "\n\n")

        if type_mismatches:
            # Categorize mismatches
            cat_profession = []   # InventoryType 29 = profession tool (Mining Pick, Blacksmith Hammer, etc.)
            cat_twohand_oh = []   # Two-Hand weapon in OffHand slot
            cat_mh_in_oh = []     # Main Hand weapon in OffHand slot
            cat_weapon_ranged = []  # Non-ranged weapon in Ranged slot
            cat_holdable_ranged = []  # Holdable in Ranged slot
            cat_other = []

            for entry in type_mismatches:
                cid, sid, slot, iid, invt, inv_name, is_spawned, cname, iname = entry
                if invt == 29:
                    cat_profession.append(entry)
                elif slot == 2 and invt == 17:  # Two-Hand in OffHand
                    cat_twohand_oh.append(entry)
                elif slot == 2 and invt == 21:  # Main Hand in OffHand
                    cat_mh_in_oh.append(entry)
                elif slot == 3 and invt in (13, 17, 21):  # Weapon in Ranged
                    cat_weapon_ranged.append(entry)
                elif slot == 3 and invt == 23:  # Holdable in Ranged
                    cat_holdable_ranged.append(entry)
                else:
                    cat_other.append(entry)

            f.write("BREAKDOWN BY CATEGORY:\n")
            f.write(f"  Profession tools (InvType 29) in MainHand:    {len(cat_profession):>5}  (intentional — visual props)\n")
            f.write(f"  Two-Hand weapon in OffHand:                   {len(cat_twohand_oh):>5}  (likely dual-wield visual)\n")
            f.write(f"  Main Hand weapon in OffHand:                  {len(cat_mh_in_oh):>5}  (likely dual-wield visual)\n")
            f.write(f"  Non-ranged weapon in Ranged slot:             {len(cat_weapon_ranged):>5}  (spear/javelin visual)\n")
            f.write(f"  Holdable in Ranged slot:                      {len(cat_holdable_ranged):>5}  (book/orb back visual)\n")
            f.write(f"  Other:                                        {len(cat_other):>5}\n")
            f.write("\n")
            f.write("NOTE: Most of these are intentional Blizzard data. NPCs hold profession tools,\n")
            f.write("      dual-wield weapons regardless of InventoryType, or carry spears on back.\n")
            f.write("      These are NOT broken visuals — the client renders them correctly.\n\n")

            spawned_mm = [x for x in type_mismatches if x[6]]
            unspawned_mm = [x for x in type_mismatches if not x[6]]

            if spawned_mm:
                f.write(f"--- SPAWNED NPCs ({len(spawned_mm)} issues) ---\n\n")
                f.write(f"{'CreatureID':>12}  {'Set':>3}  {'Slot':>10}  {'ItemID':>10}  {'InvType':>12}  Item Name / Creature\n")
                f.write(f"{'-'*12:>12}  {'-'*3:>3}  {'-'*10:>10}  {'-'*10:>10}  {'-'*12:>12}  {'-'*50}\n")
                for cid, sid, slot, iid, invt, inv_name, _, cname, iname in spawned_mm:
                    f.write(f"{cid:>12}  {sid:>3}  {slot_names[slot]:>10}  {iid:>10}  {inv_name:>12}  {iname} / {cname}\n")
                f.write("\n")

            if unspawned_mm:
                f.write(f"--- UNSPAWNED NPCs ({len(unspawned_mm)} issues) ---\n\n")
                f.write(f"{'CreatureID':>12}  {'Set':>3}  {'Slot':>10}  {'ItemID':>10}  {'InvType':>12}  Item Name / Creature\n")
                f.write(f"{'-'*12:>12}  {'-'*3:>3}  {'-'*10:>10}  {'-'*10:>10}  {'-'*12:>12}  {'-'*50}\n")
                for cid, sid, slot, iid, invt, inv_name, _, cname, iname in unspawned_mm:
                    f.write(f"{cid:>12}  {sid:>3}  {slot_names[slot]:>10}  {iid:>10}  {inv_name:>12}  {iname} / {cname}\n")
                f.write("\n")
        else:
            f.write("No type mismatches found.\n\n")

        # Unique invalid item IDs for reference
        unique_invalid = sorted(set(x[3] for x in invalid_items))
        f.write("=" * 100 + "\n")
        f.write(f"UNIQUE INVALID ITEM IDs ({len(unique_invalid)} unique)\n")
        f.write("=" * 100 + "\n")
        for iid in unique_invalid:
            uses = sum(1 for x in invalid_items if x[3] == iid)
            f.write(f"  ItemID {iid:>10}  used by {uses} creature(s)\n")
        f.write("\n")

    # --- Generate SQL Fixes ---
    # Only fix invalid items on SPAWNED creatures (visible to players)
    spawned_invalid = [x for x in invalid_items if x[4]]

    print(f"Generating SQL fixes at {SQL_PATH} ...")
    slot_col = {1: "ItemID1", 2: "ItemID2", 3: "ItemID3"}
    appearance_col = {1: "AppearanceModID1", 2: "AppearanceModID2", 3: "AppearanceModID3"}
    visual_col = {1: "ItemVisual1", 2: "ItemVisual2", 3: "ItemVisual3"}

    with open(SQL_PATH, "w", encoding="utf-8") as f:
        f.write("-- ============================================================\n")
        f.write("-- Creature Equipment Fixes: Remove invalid item IDs\n")
        f.write("-- Only for SPAWNED creatures (visible to players)\n")
        f.write(f"-- Generated by validate_equipment.py\n")
        f.write(f"-- Total fixes: {len(spawned_invalid)}\n")
        f.write("-- ============================================================\n\n")

        if not spawned_invalid:
            f.write("-- No fixes needed.\n")
        else:
            # Group by (CreatureID, SetID) to combine slot fixes in one UPDATE
            grouped = defaultdict(list)
            for cid, sid, slot, iid, _, cname in spawned_invalid:
                grouped[(cid, sid, cname)].append((slot, iid))

            for (cid, sid, cname), slots in sorted(grouped.items()):
                item_desc = ", ".join(f"{slot_col[s]}={iid}" for s, iid in slots)
                f.write(f"-- {cname} (CreatureID {cid}, Set {sid}): invalid {item_desc}\n")

                set_clauses = []
                for slot, _ in slots:
                    set_clauses.append(f"{slot_col[slot]} = 0")
                    set_clauses.append(f"{appearance_col[slot]} = 0")
                    set_clauses.append(f"{visual_col[slot]} = 0")

                f.write(f"UPDATE creature_equip_template SET {', '.join(set_clauses)} "
                        f"WHERE CreatureID = {cid} AND ID = {sid};\n\n")

    # Print summary
    print("\n" + "=" * 60)
    print("VALIDATION COMPLETE")
    print("=" * 60)
    print(f"Equipment rows scanned:      {stats['total_equip_rows']:>8,}")
    print(f"Item slot references:        {stats['total_item_refs']:>8,}")
    print(f"  Empty (0):                 {stats['zero_item_refs']:>8,}")
    print(f"  Valid:                     {stats['valid_item_refs']:>8,}")
    print(f"  INVALID item IDs:          {stats['invalid_item_refs']:>8,}")
    print(f"    On spawned NPCs:         {stats['invalid_spawned']:>8,}")
    print(f"    On unspawned NPCs:       {stats['invalid_unspawned']:>8,}")
    print(f"  Type mismatches:           {stats['type_mismatch_refs']:>8,}")
    print(f"    On spawned NPCs:         {stats['mismatch_spawned']:>8,}")
    print(f"    On unspawned NPCs:       {stats['mismatch_unspawned']:>8,}")
    print()
    print(f"Report: {REPORT_PATH}")
    print(f"SQL:    {SQL_PATH}")


if __name__ == "__main__":
    validate()

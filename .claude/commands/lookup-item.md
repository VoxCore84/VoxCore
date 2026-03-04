---
allowed-tools: Bash(python3:*)
description: Look up item IDs or search item names from the Wago ItemSparse DB2 CSV
---

## Context

The user wants to look up WoW item data. The source is the Wago DB2 export:
- CSV path (bash): `/c/Users/atayl/source/wago/wago_csv/major_12/12.0.1.66220/enUS/ItemSparse-enUS.csv`
- In Python, use `os.path.expanduser('~') + '/source/wago/wago_csv/major_12/12.0.1.66220/enUS/ItemSparse-enUS.csv'` to resolve the path correctly
- Key columns: `ID` (col 0), `Display_lang` (col 6, the item name), `OverallQualityID` (col 95), `InventoryType` (col 94), `ItemLevel` (col 85)
- ~171k rows, wide CSV — use Python csv.DictReader for reliable parsing

## Quality IDs
- 0=Poor (gray), 1=Common (white), 2=Uncommon (green), 3=Rare (blue), 4=Epic (purple), 5=Legendary (orange), 6=Artifact, 7=Heirloom

## Inventory Types
- 0=Non-equip, 1=Head, 2=Neck, 3=Shoulder, 4=Shirt, 5=Chest, 6=Waist, 7=Legs, 8=Feet, 9=Wrists, 10=Hands, 11=Finger, 12=Trinket, 13=One-Hand, 14=Shield, 15=Ranged, 16=Back, 17=Two-Hand, 18=Bag, 19=Tabard, 20=Robe, 21=Main Hand, 22=Off Hand, 23=Holdable, 24=Ammo, 25=Thrown, 26=Ranged Right

## Arguments

$ARGUMENTS can be:
- **A number** (e.g., `19019`) — look up that item ID
- **Multiple numbers** (e.g., `19019 25 32837`) — look up all of them
- **A text string** (e.g., `Thunderfury`) — search item names (case-insensitive)

## Your task

1. Parse $ARGUMENTS to determine if it's an ID lookup or a name search
2. Write a small Python script that:
   - Opens the CSV with `csv.DictReader`
   - For **ID lookup**: finds rows where `ID` matches, prints: `ID | Name | Quality | InventoryType | ItemLevel`
   - For **name search**: finds rows where `Display_lang` contains the search string (case-insensitive), limits to 25 results, shows total count
   - Maps QualityID and InventoryType to human-readable names using the tables above
3. Run the script and display results as a clean table
4. Keep output concise — just the table, no extra commentary

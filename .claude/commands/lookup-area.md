---
allowed-tools: Bash(python3:*), Bash(grep:*)
description: Look up area/zone IDs or search area names from Wago AreaTable DB2 CSV
---

## Context

The user wants to look up WoW area/zone data. The source is the Wago DB2 export:
- **AreaTable** (bash): `/c/Users/atayl/source/wago/wago_csv/major_12/12.0.1.66192/enUS/AreaTable-enUS.csv`
  - Key columns: `ID`, `ZoneName` (internal name), `AreaName_lang` (display name), `ContinentID`, `ParentAreaID`, `ContentTuningID`, `Flags_0`, `Flags_1`
  - ~9848 rows
- In Python, use `os.path.expanduser('~') + '/source/wago/wago_csv/major_12/12.0.1.66192/enUS/AreaTable-enUS.csv'` to resolve paths

## ContinentID values
- 0 = Eastern Kingdoms, 1 = Kalimdor, 530 = Outland, 571 = Northrend, 860 = Pandaria, 1116 = Draenor, 1220 = Broken Isles, 1643 = Kul Tiras, 1669 = Zandalar, 2222 = Shadowlands, 2444 = Dragon Isles, 2552 = Khaz Algar

## Arguments

$ARGUMENTS can be:
- **A number** (e.g., `1`) — look up that area ID
- **Multiple numbers** (e.g., `1 14 1519`) — look up all of them
- **A text string** (e.g., `Stormwind`) — search area names (case-insensitive)

## Your task

1. Parse $ARGUMENTS to determine if it's an ID lookup or a name search
2. Write a Python script that:
   - Opens the CSV with `csv.DictReader`
   - For **ID lookup**: finds rows where `ID` matches, prints: `ID | AreaName | ZoneName | ContinentID | ParentAreaID`
   - For **name search**: finds rows where `AreaName_lang` contains the search string (case-insensitive), limits to 25 results, shows total count
   - Maps ContinentID to readable name using the table above
3. Run the script and display results as a clean table
4. Keep output concise

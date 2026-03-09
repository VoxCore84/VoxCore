---
description: Lookup Area - Look up area/zone IDs or search area names from Wago AreaTable DB2 CSV
---

// turbo-all

## Context

The user wants to look up WoW area/zone data. The source is the Wago DB2 export:
- In Python, first: `import sys, os; sys.path.insert(0, os.path.expanduser('~/VoxCore/wago')); from wago_common import WAGO_CSV_DIR`
- Then use: `str(WAGO_CSV_DIR / 'AreaTable-enUS.csv')`
- Key columns: `ID`, `ZoneName` (internal name), `AreaName_lang` (display name), `ContinentID`, `ParentAreaID`, `ContentTuningID`, `Flags_0`, `Flags_1`
- ~9848 rows

## ContinentID values
- 0 = Eastern Kingdoms, 1 = Kalimdor, 530 = Outland, 571 = Northrend, 860 = Pandaria, 1116 = Draenor, 1220 = Broken Isles, 1643 = Kul Tiras, 1669 = Zandalar, 2222 = Shadowlands, 2444 = Dragon Isles, 2552 = Khaz Algar

## Your task

1. Parse arguments or user request to determine if it's an ID lookup or a name search.
2. Write a Python script to `/tmp/lookup_area.py` that:
   - Opens the CSV with `csv.DictReader`
   - For **ID lookup**: finds rows where `ID` matches, prints: `ID | AreaName | ZoneName | ContinentID | ParentAreaID`
   - For **name search**: finds rows where `AreaName_lang` contains the search string (case-insensitive), limits to 25 results, shows total count
   - Maps ContinentID to readable name using the table above
3. Run the script using `run_command` and display results as a clean table
4. Keep output concise

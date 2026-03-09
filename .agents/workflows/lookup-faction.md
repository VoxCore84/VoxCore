---
description: Lookup Faction - Look up faction template IDs or search faction names from Wago DB2 CSVs
---

// turbo-all

## Context

The user wants to look up WoW faction data. Two CSVs are needed:
- In Python, first: `import sys, os; sys.path.insert(0, os.path.expanduser('~/VoxCore/wago')); from wago_common import WAGO_CSV_DIR`
- Then use: `str(WAGO_CSV_DIR / 'FactionTemplate-enUS.csv')` and `str(WAGO_CSV_DIR / 'Faction-enUS.csv')`
- **FactionTemplate**: Columns: `ID`, `Faction` (FK to Faction.ID), `Flags`, `FactionGroup`, `FriendGroup`, `EnemyGroup`, `Enemies_0..7`, `Friend_0..7` (~1862 rows). The `ID` here is what `creature_template.faction` references.
- **Faction**: Columns: `ID`, `Name_lang`, `Description_lang`, `ReputationIndex`, `ParentFactionID`, `Expansion`, ... (~858 rows). Has readable names.

## FactionGroup flags
- 1 = Player (Alliance or Horde), 2 = Alliance, 4 = Horde

## Your task

1. Parse arguments or user request to determine if it's an ID lookup or a name search
2. Write a Python script to `/tmp/lookup_faction.py` that:
   - Loads both CSVs into dicts (Faction keyed by ID for name resolution)
   - For **ID lookup**: finds FactionTemplate rows matching the IDs, resolves `Faction` FK to get the Faction name, prints: `FactionTemplateID | FactionID | Name | FactionGroup | FriendGroup | EnemyGroup`
   - For **name search**: searches Faction `Name_lang`, then finds all FactionTemplate rows referencing those Faction IDs. Limits to 25 results, shows total.
   - Maps FactionGroup to readable: 0=Neutral/None, 1=Player, 2=Alliance, 3=Player+Alliance, 4=Horde, 5=Player+Horde, 6=Alliance+Horde, 7=All, 8=Monster
3. Run the script using `run_command` and display results as a clean table
4. Keep output concise — just the table, no extra commentary

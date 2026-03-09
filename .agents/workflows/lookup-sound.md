---
description: Lookup Sound - Look up SoundKit IDs from Wago DB2 CSV to validate they exist
---

// turbo-all

## Context

The user wants to look up or validate WoW SoundKit IDs. The source is the Wago DB2 export:
- In Python, first: `import sys, os; sys.path.insert(0, os.path.expanduser('~/VoxCore/wago')); from wago_common import WAGO_CSV_DIR`
- Then use: `str(WAGO_CSV_DIR / 'SoundKit-enUS.csv')`
- Columns: `ID`, `SoundType`, `VolumeFloat`, `Flags`, `MinDistance`, `DistanceCutoff`, `EAXDef`, `SoundKitAdvancedID`, `DialogType`, ...
- ~315k rows. No human-readable name column — SoundKit names are internal Blizzard filenames not in the DB2.

## SoundType values
- 1 = Spell, 2 = UI, 3 = Footsteps, 4 = Combat Impacts, 6 = NPC Combat, 10 = Zone Music, 12 = Zone Ambience, 13 = Doodad, 14 = Death, 16 = NPC Greetings, 17 = Emotes, 19 = Looping, 21 = Cinematic, 28 = Creature Loop, 50 = Zone Intro Music

## Your task

1. Parse user input
2. For **single/multiple ID lookup**:
   - Write a python script to `/tmp/lookup_sound.py` or use `grep -E "^(ID1|ID2|ID3)," <csv>` via `run_command`
   - Display results as: `ID | SoundType | Volume | DialogType`
   - Map SoundType to readable name using the table above
   - Report any IDs not found
3. For **`validate` mode**:
   - Write a python script to `/tmp/lookup_sound.py`
   - Load all SoundKit IDs into a set (Python for speed on large lists)
   - Report only the IDs that do NOT exist in the CSV
   - If all valid, say so
4. Keep output concise

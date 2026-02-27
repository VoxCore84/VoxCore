---
allowed-tools: Bash(grep:*), Bash(python3:*)
description: Look up SoundKit IDs from Wago DB2 CSV to validate they exist
---

## Context

The user wants to look up or validate WoW SoundKit IDs. The source is the Wago DB2 export:
- **SoundKit** (bash): `/c/Users/atayl/source/wago/wago_csv/major_12/12.0.1.66192/enUS/SoundKit-enUS.csv`
  - Columns: `ID`, `SoundType`, `VolumeFloat`, `Flags`, `MinDistance`, `DistanceCutoff`, `EAXDef`, `SoundKitAdvancedID`, `DialogType`, ...
  - ~315k rows. No human-readable name column — SoundKit names are internal Blizzard filenames not in the DB2.
- In Python, use `os.path.expanduser('~') + '/source/wago/wago_csv/major_12/12.0.1.66192/enUS/SoundKit-enUS.csv'` to resolve paths

## SoundType values
- 1 = Spell, 2 = UI, 3 = Footsteps, 4 = Combat Impacts, 6 = NPC Combat, 10 = Zone Music, 12 = Zone Ambience, 13 = Doodad, 14 = Death, 16 = NPC Greetings, 17 = Emotes, 19 = Looping, 21 = Cinematic, 28 = Creature Loop, 50 = Zone Intro Music

## Arguments

$ARGUMENTS can be:
- **A number** (e.g., `7894`) — look up that SoundKit ID
- **Multiple numbers** (e.g., `7894 7914 890`) — look up all of them, report which exist and which don't
- **`validate`** followed by numbers — bulk validate a list of IDs, only report missing ones

## Your task

1. Parse $ARGUMENTS
2. For **single/multiple ID lookup**:
   - Use grep to check existence: `grep -E "^(ID1|ID2|ID3)," <csv>`
   - Display results as: `ID | SoundType | Volume | DialogType`
   - Map SoundType to readable name using the table above
   - Report any IDs not found
3. For **`validate` mode**:
   - Load all SoundKit IDs into a set (Python for speed on large lists)
   - Report only the IDs that do NOT exist in the CSV
   - If all valid, say so
4. Keep output concise

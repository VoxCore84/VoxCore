---
description: Lookup Emote - Look up emote IDs or search emote names from Wago DB2 CSVs
---

// turbo-all

## Context

The user wants to look up WoW emote data. Two CSVs are relevant:
- In Python, first: `import sys, os; sys.path.insert(0, os.path.expanduser('~/VoxCore/wago')); from wago_common import WAGO_CSV_DIR`
- Then use: `str(WAGO_CSV_DIR / 'EmotesText-enUS.csv')` and `str(WAGO_CSV_DIR / 'Emotes-enUS.csv')`
- **EmotesText**: Columns: `ID`, `Name` (e.g., AGREE, AMAZE, WAVE), `EmoteID`. Small table — slash command emotes (/wave, /agree, etc.)
- **Emotes**: Columns: `ID`, `RaceMask`, `EmoteSlashCommand` (e.g., ONESHOT_NONE), `AnimID`, `EmoteFlags`, `EmoteSpecProc`, `EmoteSpecProcParam`, `EventSoundID`, `SpellVisualKitID`, `ClassMask`. ~494 rows — animation-level emotes used in SmartAI and creature_text.

## Your task

1. Parse arguments to determine if it's an ID lookup or a name search
2. Write a Python script to `/tmp/lookup_emote.py` that:
   - Loads both CSVs
   - For **ID lookup**: searches EmotesText by ID first, then Emotes by ID. Shows matches from both.
   - For **name search**: searches EmotesText `Name` and Emotes `EmoteSlashCommand` for the search term. Limits to 25 results per table.
   - Prints two sections if both have results:
     - **EmotesText** (slash commands): `ID | Name | EmoteID`
     - **Emotes** (animations): `ID | EmoteSlashCommand | AnimID | EventSoundID | SpellVisualKitID`
3. Run the script using `run_command` and display results.
4. Keep output concise

---
allowed-tools: Bash(grep:*), Bash(python3:*)
description: Look up emote IDs or search emote names from Wago DB2 CSVs
---

## Context

The user wants to look up WoW emote data. Two CSVs are relevant:
- **EmotesText** (bash): `/c/Users/atayl/source/wago/wago_csv/major_12/12.0.1.66192/enUS/EmotesText-enUS.csv`
  - Columns: `ID`, `Name` (e.g., AGREE, AMAZE, WAVE), `EmoteID`
  - Small table — these are the slash command emotes players use (/wave, /agree, etc.)
- **Emotes** (bash): `/c/Users/atayl/source/wago/wago_csv/major_12/12.0.1.66192/enUS/Emotes-enUS.csv`
  - Columns: `ID`, `RaceMask`, `EmoteSlashCommand` (e.g., ONESHOT_NONE), `AnimID`, `EmoteFlags`, `EmoteSpecProc`, `EmoteSpecProcParam`, `EventSoundID`, `SpellVisualKitID`, `ClassMask`
  - ~494 rows. These are animation-level emotes used in SmartAI and creature_text.
- In Python, use `os.path.expanduser('~') + '/source/wago/wago_csv/major_12/12.0.1.66192/enUS/<filename>'` to resolve paths

## Arguments

$ARGUMENTS can be:
- **A number** (e.g., `1`) — look up that emote ID (searches both tables)
- **Multiple numbers** (e.g., `1 5 22`) — look up all of them
- **A text string** (e.g., `wave`) — search emote names (case-insensitive, searches both tables)

## Your task

1. Parse $ARGUMENTS to determine if it's an ID lookup or a name search
2. Write a Python script that:
   - Loads both CSVs
   - For **ID lookup**: searches EmotesText by ID first, then Emotes by ID. Shows matches from both.
   - For **name search**: searches EmotesText `Name` and Emotes `EmoteSlashCommand` for the search term. Limits to 25 results per table.
   - Prints two sections if both have results:
     - **EmotesText** (slash commands): `ID | Name | EmoteID`
     - **Emotes** (animations): `ID | EmoteSlashCommand | AnimID | EventSoundID | SpellVisualKitID`
3. Run the script and display results
4. Keep output concise

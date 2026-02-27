---
allowed-tools: Bash(python3:*), Bash(grep:*), Bash(wc:*)
description: Look up spell IDs or search spell names from the Wago SpellName DB2 CSV
---

## Context

The user wants to look up WoW spell data. The source is the Wago DB2 export:
- CSV (bash path): `/c/Users/atayl/source/wago/wago_csv/major_12/12.0.1.66192/enUS/SpellName-enUS.csv`
- If using Python: `os.path.expanduser('~') + '/source/wago/wago_csv/major_12/12.0.1.66192/enUS/SpellName-enUS.csv'`
- Format: `ID,Name_lang` (2 columns, ~400k rows)
- Names may be quoted if they contain commas

## Arguments

$ARGUMENTS can be:
- **A number** (e.g., `1459`) — look up that spell ID
- **Multiple numbers** (e.g., `1459 8936 774`) — look up all of them
- **A text string** (e.g., `Rejuvenation`) — search spell names (case-insensitive)

## Your task

1. Parse $ARGUMENTS to determine if it's an ID lookup or a name search
2. For **ID lookup** (one or more numbers):
   - Use grep to find matching lines: `grep -E "^(ID1|ID2|ID3)," <csv>`
   - Display results as a clean table: `ID | Name`
   - If an ID is not found, say so
3. For **name search** (text):
   - Use grep case-insensitive: `grep -i "<search>" <csv>`
   - Limit output to first 25 matches
   - Show total match count if more than 25
   - Display as: `ID | Name`
4. Keep output concise — just the table, no extra commentary

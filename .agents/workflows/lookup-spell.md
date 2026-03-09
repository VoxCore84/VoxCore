---
description: Lookup Spell - Look up spell IDs or search spell names from the Wago SpellName DB2 CSV
---

// turbo-all

## Context

The user wants to look up WoW spell data. The source is the Wago DB2 export:
- In Python, first: `import sys, os; sys.path.insert(0, os.path.expanduser('~/VoxCore/wago')); from wago_common import WAGO_CSV_DIR`
- Then use: `str(WAGO_CSV_DIR / 'SpellName-enUS.csv')`
- Format: `ID,Name_lang` (2 columns, ~400k rows)
- Names may be quoted if they contain commas

## Your task

1. Parse user input to determine if it's an ID lookup or a name search
2. Write a small python script to `/tmp/lookup_spell.py`
3. For **ID lookup** (one or more numbers):
   - Have the script search the CSV for the IDs.
   - Display results as a clean table: `ID | Name`
   - If an ID is not found, say so
4. For **name search** (text):
   - Have the script search the CSV for the name string (case-insensitive)
   - Limit output to first 25 matches
   - Show total match count if more than 25
   - Display as: `ID | Name`
5. Print output and keep it concise — just the table, no extra commentary

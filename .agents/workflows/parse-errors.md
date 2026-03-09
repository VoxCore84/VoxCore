---
description: Parse Errors - Parse a worldserver error log and categorize errors by type with counts
---

// turbo-all

## Context

The user wants to parse a worldserver error log to categorize and count errors.

- Error logs are typically large (thousands of lines)
- Common error categories: invalid spell references, missing creatures, bad loot references, SmartAI errors, invalid display IDs, missing quest references, areatrigger issues
- Use a python script to process the errors instead of bash grep to avoid PCRE restrictions on Windows.

## Your task

1. Read the first 50 lines of the log using `view_file` or `run_command` head to understand the format (Location from arguments)
2. Write a Python script to `/tmp/parse_errors.py` to:
   - Read the full log
   - Categorize errors by type (group by error message pattern)
   - Count occurrences of each category
   - Extract affected IDs for each category
   - Output a summary sorted by count (highest first)
3. Run the script using `run_command` and present the summary

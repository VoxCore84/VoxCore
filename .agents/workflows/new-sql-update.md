---
description: New SQL Update - Create a new correctly-named SQL update file with the next sequence number
---

## Context

SQL update files follow the naming convention: `YYYY_MM_DD_NN_<db>.sql`
- `YYYY_MM_DD` — today's date
- `NN` — two-digit sequence number, starting at 00 for each day, incrementing
- `<db>` — the database name (world, auth, characters, hotfixes)
- Location: `sql/updates/<db>/master/`

## Your task

1. Parse the database name from user input. Validate it's one of: world, auth, characters, hotfixes. Also get the brief description.
2. Calculate today's date in `YYYY_MM_DD` format.
3. List existing files in `sql/updates/<db>/master/` using `list_dir` to determine the next sequence number:
   - Match files with today's date prefix
   - Find the maximum `NN` and increment by 1 (zero-padded)
   - If no files exist, use 00
4. Create the file at `sql/updates/<db>/master/YYYY_MM_DD_NN_<db>.sql` using `write_to_file` with content:
   ```
   -- YYYY_MM_DD_NN_<db>.sql
   -- <description if provided, otherwise empty>

   ```
5. Report the created file path so the user can start editing

---
description: Apply SQL - Apply a SQL file to a database (world, characters, auth, hotfixes, roleplay)
---

## Context

The user wants to apply a SQL file to a MySQL database.

- MySQL binary: `C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe`
- Credentials: root / admin
- Available databases: world, characters, auth, hotfixes, roleplay
- The worldserver may be running, so always prepend `SET innodb_lock_wait_timeout=120;`

## Your task

1. Verify the SQL file exists using view_file (first 20 lines to confirm content)
2. Verify the arguments provided a valid `<database>` and `<file_path>`
3. Apply it using run_command: `bash -c 'echo "SET innodb_lock_wait_timeout=120;" | cat - <file_path> | "C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -padmin <database>'`
4. Report success or failure concisely using the tool output. Use literal output to prove completion (Anti-Theater Protocol).

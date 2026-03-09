---
description: Lookup Creature - Look up creature template entries by ID or search by name from the world database
---

// turbo-all

## Context

The user wants to look up creature data from the world database.
- MySQL binary: `C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe`
- Credentials: root / admin
- Database: world
- Table: `creature_template` — columns include `entry`, `name`, `subname`, `faction`, `npcflag`, `unit_flags`, `unit_flags2`, `unit_flags3`, `Classification`, `KillCredit1`, `KillCredit2`
- NOTE: No `minlevel`/`maxlevel` columns in 12.x — level data is in `creature_template_difficulty`
- Classification: 0=Normal, 1=Elite, 2=Rare Elite, 3=World Boss, 4=Rare

## Your task

1. Parse arguments to determine if it's an ID lookup or a name search
2. For **ID lookup**:
   - Query: `SELECT entry, name, subname, faction, npcflag, Classification FROM creature_template WHERE entry IN (id1, id2, ...);`
3. For **name search**:
   - Query: `SELECT entry, name, subname, faction, npcflag, Classification FROM creature_template WHERE name LIKE '%search%' LIMIT 25;`
   - Also run a COUNT(*) to show total matches
4. Run queries using `run_command`: `"C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -padmin world -e "<query>" -t`
5. Print the table that is returned. Keep output concise — just the table, no extra commentary.

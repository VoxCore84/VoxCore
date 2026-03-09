# SQL Generation & Multi-Agent Lessons

## SQL Generation from Error Logs
- **Always `DESCRIBE` tables first** before writing SQL. Error log messages use different names than actual columns (e.g., log says "FactionID" but column is `faction`).
- **Use Python in main context** for large log parsing. Write a `.py` file, run it, delete it. Background agents can't reliably use bash for grep/awk pipelines.
- **`grep -P` (PCRE) doesn't work** in this bash env. Use `sed` or Python instead.
- **No `tail`/`head` commands** in this bash env. Use `python -c` for text slicing. Python is at `/c/Python314/python` (not `python3`).
- **`gh` API paths**: Use `MSYS_NO_PATHCONV=1` prefix to prevent MSYS path conversion on API endpoints starting with `/`
- **Heredocs + Python single quotes fail**: Write Python to a `.py` file then `python3 file.py`, don't inline in bash heredoc.
- **Batch size**: 500 IDs per IN clause is safe for MySQL.
- **Idempotent patterns**: DELETE WHERE IN, UPDATE with `AND col = old_val`, INSERT IGNORE, bitwise AND with mask.
- **Aura field manipulation**: `TRIM(REPLACE(CONCAT(' ', auras, ' '), ' SPELL_ID ', ' '))` removes one spell from space-separated list.
- **Flag masks** are in `src/server/game/Entities/Unit/UnitDefines.h` (UNIT_FLAG_ALLOWED, UNIT_FLAG2_ALLOWED, etc.)
- **mysqldump TSV escaping**: Data extracted from mysqldump SQL contains `\'` and `\\` escape sequences in string fields. When generating SQL from TSV, **unescape mysqldump conventions first** (`\'`→`'`, `\\`→`\`, `\n`→newline, etc.) then re-escape for SQL (`'`→`''`). Don't try to fix with sed — shell escaping layers make it unreliable. Write a Python `.py` file with `unescape_mysqldump()` + `escape_sql_string()` functions

## Applying SQL to Databases
- Command pattern: `"C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -padmin <dbname> < <file.sql>`
- To prepend settings: `echo "SET innodb_lock_wait_timeout=120;" | cat - <file.sql> | mysql ...`
- **Worldserver often running** — causes deadlocks on multi-table JOINed DELETEs against `smart_scripts`, `creature`, etc. Prepend `SET innodb_lock_wait_timeout=120;` to avoid timeouts
- **`mysql.procs_priv` fixed** (Feb 2026) — was corrupted due to 8.0→9.5 upgrade; fixed via `upgrade=FORCE` in my.ini. Stored procedures, functions, and triggers now work
- `SOURCE` command doesn't work with Unix-style paths from bash — use stdin redirect instead
- Always apply in sequence number order when files have dependencies
- Run one at a time to catch failures early
- **MySQL 8.0 error 1093**: `UPDATE t SET x WHERE col NOT IN (SELECT FROM t)` fails. Fix: `NOT IN (SELECT ID FROM (SELECT ID FROM t) AS sub)`

## Gameobject Dedup Lessons
- **`gameobject` table (175K rows)** has only PK on `guid`. Self-joins on `(id, map)` need a temp index or they run 30+ minutes. Add `idx_id_map (id, map)`, query, then drop it
- **Killing MySQL client doesn't kill server query**. Always `SHOW PROCESSLIST` → `KILL <thread_id>` after aborting a long-running client
- **Stacked gameobjects may use different entries**. The original dupe query (`g1.id = g2.id`) missed boards where different entries (206294 vs 281339) were at identical coords. Cross-entry stacking requires joining on position only
- **Modern zero-quest boards**: Entries with `data0=2824` (conditionID framework) may have no `gameobject_queststarter` rows — the old stacked board was providing quests. Always verify quest_count before deleting the "duplicate"

## Data Pipeline Patterns
- **Reimport procedure**: (1) DELETE WHERE VerifiedBuild=X, (2) re-export existing state to txt, (3) regenerate SQL, (4) import, (5) apply fix SQL, (6) QA verify
- **Chain fix must follow chain import**: quest_chain_gen.py fills empty slots, which can recreate circular pairs that were previously fixed. Always reapply fix_quest_chains.sql after reimporting chains
- **MySQL warning in export files**: `mysql -e "SELECT..." > file.txt` captures stderr warning "Using a password on the command line..." into the file. All loader scripts need try/except on int() parsing to handle this
- **INSERT ... ON DUPLICATE KEY UPDATE** for locale tables (PK includes VerifiedBuild). **INSERT IGNORE** for quest starters/enders (simple PK, idempotent)
- **Circular chain detection**: Self-refs (WHERE col=ID), 2-hop (A.Next=B AND B.Next=A), 3-hop (JOIN chain WHERE C.Next=A). Fix by clearing NextQuestID on highest-ID quest in each cycle
- **Dangling ref detection**: LEFT JOIN quest_template ON ref_col = ID WHERE ID IS NULL. For negative PrevQuestID: use ABS()
- **Locale dedup**: PK is (ID, locale, VerifiedBuild). DELETE via self-JOIN keeping higher VerifiedBuild
- **Orphan cleanup**: DELETE FROM child WHERE parent_id NOT IN (SELECT ID FROM parent). Use subquery, not JOIN, for simplicity

## Loot Table Gotchas
- **`creature_loot_template` and `gameobject_loot_template` have NO PRIMARY KEY** — only `KEY idx_primary (Entry,ItemType,Item)` which is non-unique. INSERT IGNORE does nothing on these tables.
- **Dedup via CSV round-trip**: Export TSV (`mysql --batch --raw`), `sort -u` data rows, TRUNCATE original, LOAD DATA LOCAL INFILE. Much faster than `SELECT DISTINCT` into temp table on multi-million row tables.
- **LOAD DATA LOCAL INFILE** requires `--local-infile=1` flag on mysql client
- **Legitimate same-key rows exist**: Same (Entry,ItemType,Item) with different Chance/GroupId/etc are valid multi-rule loot entries. Only exact full-row duplicates should be removed.
- **Loot Entry linkage**: creature_template_difficulty.LootID → creature_loot_template.Entry. Not creature_template directly.

## Column Mismatch Import Pattern
- TC adds new columns over time. LW (older fork) has fewer columns. Column mismatches prevent INSERT IGNORE on positional VALUES.
- **Fix**: Parse tuple boundaries (state machine for quoted strings/parens), append default values to each tuple.
- **Safe defaults**: `size=-1` (use template), `visibility=256` (standard range), `OverrideGoldCost=-1` (use item default)
- **Extra columns in source**: Use explicit column list INSERT, drop unknown columns
- **Always verify** with DESCRIBE before and after: count values in first tuple matches table column count

## Bulk Import Pipeline
- **Dependency ordering**: Spawns (creature/gameobject) before dependents (addon, formations, waypoints, pools, spawn_groups). Template-level tables (difficulty, spells, model_info) can go in any order.
- **Pre-import backup**: `mysqldump --single-transaction world > backup.sql` (888MB for full world DB)
- **Stuck queries block TRUNCATE**: MySQL metadata locks prevent DDL while DML is running. Check `SHOW PROCESSLIST` and KILL stuck queries before retrying.
- **Batch DELETE orphans**: For large tables, get orphan IDs first (`SELECT DISTINCT`), then `DELETE WHERE Entry IN (batch)` in groups of 500. Avoids 50-minute JOIN DELETEs.
- **Validation after each phase**: COUNT(*) before/after, orphan LEFT JOIN checks, zero-tolerance for dangling FKs

## Post-Import Cleanup Patterns
- **Spell validation**: JOIN against `hotfixes.spell_name` (400K rows, composite PK `(ID, VerifiedBuild)` — use `NOT EXISTS` not plain JOIN to avoid row multiplication) AND `world.serverside_spell` (4.4K rows, column is `Id` with lowercase d). A spell is valid if in EITHER table.
- **SmartAI unsupported types**: Confirmed UNUSED in `SmartScriptMgr.h` (marked `// UNUSED, DO NOT REUSE`): action types 18,19,75,104,105,106; event types 12,66. **Event type 47 (`SMART_EVENT_QUEST_ACCEPTED`) IS supported** — has ProcessEvent case handler.
- **`gameobject_loot_template` has NO `Reference` column** — only creature_loot_template has it (11 cols vs 10). Don't assume symmetric schemas between creature/gameobject loot.
- **Duplicate spawn detection via Python, not SQL**: Self-joins on creature (681K) or gameobject (193K) with `ABS(pos_x - pos_x) < 1.0` conditions can't use indexes — timed out at 17+ min. Export TSV, sort by (id, map, x, y, z), detect dupes in Python in seconds. Batch DELETE by 500 GUIDs.
- **Cascade cleanup**: Deleting spawns creates orphans in dependent tables (creature_addon, gameobject_addon, spawn_group, creature_formations, pool_members). Always run a second pass for newly-empty pool_templates after pool_members cleanup.

## Multi-Agent Workflow Pattern
- For large DB error triage: parse log → categorize → create workflow docs in `sql/fixes/` → generate SQL
- Sequence number ranges prevent file collisions (e.g., agent 1 gets _00-_09, agent 2 gets _10-_19)
- **Agents struggle with large data extraction** — extract IDs in main context with Python, have agents focus on source-code analysis and SQL strategy only
- Workflow docs at `sql/fixes/*.md` with README.md as master index
- **Codex CLI as parallel agent**: Write a detailed task spec in `.codex/TASK.md` (include inline code excerpts, wire formats, acceptance criteria), then run `npx @openai/codex exec --dangerously-bypass-approvals-and-sandbox 'Read .codex/TASK.md and implement all tasks'`. Runs locally using ChatGPT Pro plan at no extra API cost, much faster than Codex Cloud

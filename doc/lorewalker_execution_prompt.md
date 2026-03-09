# LoreWalker TDB Import — Generate All 7 SQL Files

## What This Is

A `lorewalker_world` database (935MB, build 66102, Mar 6 2026) has been loaded alongside our production `world` database (build 66263) on the same MySQL instance. You need to generate 7 SQL update files that selectively import missing data from LW into our world DB.

**MySQL**: `"C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -padmin`
**Output dir**: `sql/updates/world/master/`
**Filenames**: `2026_03_08_01_world.sql` through `2026_03_08_07_world.sql` (sequence 01-07)

## Execution Strategy

Use 3 parallel agents to generate the files simultaneously:
- **Agent 1**: Files 1, 2, 3, 7 (phases + templates + quests + backfill)
- **Agent 2**: File 4 (spawns)
- **Agent 3**: Files 5, 6 (behavioral + loot)

Each agent must DESCRIBE every table it touches in BOTH `world` and `lorewalker_world` before writing any SQL. Never guess column names.

After all agents complete, verify all 7 files exist and output a summary table of rows per file.

---

## MANDATORY RULES (every agent must follow)

1. **INSERT IGNORE** for tables WITH a primary key (idempotent).
2. **`INSERT INTO ... SELECT ... WHERE NOT EXISTS`** for tables WITHOUT a primary key — ALL `*_loot_template` tables have NO PK. `INSERT IGNORE` would blindly duplicate rows. Match on `(Entry, ItemType, Item)`.
3. **Explicit column lists** for any table where the two DBs differ. Known differences:
   - `world.creature` has extra column `size` (default -1) — exclude from SELECT
   - `world.gameobject` has extra columns `size` (default -1) and `visibility` (default 256) — exclude from SELECT
   - `world.npc_vendor` has extra column `OverrideGoldCost` (default -1) — exclude from SELECT
   - `lorewalker_world.scene_template` has extra column `RTComment` — exclude from SELECT
4. **VerifiedBuild = 0**: For tables that have a `VerifiedBuild` column, override it to `0` in the SELECT (marks as imported). Tables with VB: `creature_template`, `creature_template_difficulty`, `creature_template_model`, `gameobject_template`, `quest_template`, `quest_objectives`, `quest_details`, `quest_offer_reward`, `quest_request_items`, `creature`, `gameobject`, `npc_vendor`, `gossip_menu`, `gossip_menu_option`.
5. **Filter out LW custom range**: `entry/ID >= 9100000` on all imports that have an entry/ID column.
6. **Filter out corrupt GO GUIDs**: `guid >= 1913720832000` on gameobject imports only (41,911 seasonal artifacts).
7. **Filter out origin spawns**: `position_x = 0 AND position_y = 0 AND position_z = 0` on creature/gameobject imports.
8. **Filter out orphan spawns**: Use `EXISTS (SELECT 1 FROM world.creature_template ct WHERE ct.entry = l.id)` on creature imports (and equivalent for gameobjects) to ensure the template exists in OUR DB.
9. **Do NOT import SmartAI source_type=5** (526K rows of LW's custom scene system).
10. **Wrap Files 4, 5, 6 in** `SET autocommit=0;` at top and `COMMIT;` at bottom (large row counts).
11. Every SQL file starts with a comment block: what it does, table list, estimated row counts.
12. **Do NOT apply** any SQL files — only generate them.
13. **NEVER touch** these tables (we lead): `creature_loot_template`, `spell_script_names`, `trainer`, `trainer_spell`.

### Known Column Pitfalls
- All `*_loot_template` tables: the column is **`ItemType`**, NOT `Reference`. There is no `Reference` column.
- `waypoint_path`: has a `Velocity` column between `Flags` and `Comment` — include it.
- `creature_addon` AnimKit columns are `smallint signed` in world, `unsigned` in LW — INSERT IGNORE handles truncation.

---

## FILE 1: Phases (~1,279 rows) → `2026_03_08_01_world.sql`

**Tables**: `phase_area` (662), `phase_name` (617)

```sql
-- phase_area: PK is (AreaId, PhaseId)
INSERT IGNORE INTO world.phase_area (AreaId, PhaseId, Comment)
SELECT l.AreaId, l.PhaseId, l.Comment
FROM lorewalker_world.phase_area l
LEFT JOIN world.phase_area w ON l.AreaId = w.AreaId AND l.PhaseId = w.PhaseId
WHERE w.AreaId IS NULL;

-- phase_name: PK is (ID)
INSERT IGNORE INTO world.phase_name (ID, Name)
SELECT l.ID, l.Name
FROM lorewalker_world.phase_name l
LEFT JOIN world.phase_name w ON l.ID = w.ID
WHERE w.ID IS NULL;
```

---

## FILE 2: Templates (~4,450 rows) → `2026_03_08_02_world.sql`

| Table | ~Rows | PK | Notes |
|-------|-------|----|-------|
| creature_template | 10 | entry | VB=0, filter <9100000 |
| creature_template_difficulty | 20 | (Entry, DifficultyID) | VB=0, import ALL missing (not just new templates) |
| creature_template_model | 13 | (CreatureID, Idx) | VB=0 |
| creature_template_addon | 125 | (entry) | No VB |
| creature_template_spell | 163 | (CreatureID, \`Index\`) | Backtick `Index` — reserved word |
| creature_equip_template | 2,023 | (CreatureID, ID) | No VB |
| gameobject_template | 2,089 | (entry) | VB=0, filter <9100000 |
| gameobject_template_addon | ~10 | (entry) | No VB |

All use INSERT IGNORE with LEFT JOIN exclusion. DESCRIBE each table in both DBs first.

For `creature_template_difficulty`: import ALL missing rows (Entry < 9100000), not just rows for the 10 new templates. Some existing templates have difficulty rows in LW that we lack — File 7's ContentTuningID backfill depends on these rows existing.

---

## FILE 3: Quests (~98,000 rows) → `2026_03_08_03_world.sql`

| Table | ~Rows | PK | Notes |
|-------|-------|----|-------|
| quest_template | 198 | (ID) | VB=0, filter <9100000 |
| quest_template_addon | 57,611 | (QuestId) | No VB, ALL missing (not just new quests) |
| quest_objectives | 888 | (ID) | VB=0 |
| quest_details | 962 | (ID) | VB=0 |
| quest_offer_reward | 551 | (ID) | VB=0 |
| quest_request_items | 1,894 | (ID) | VB=0 |
| quest_poi | 10,424 | DESCRIBE to get PK | DESCRIBE first |
| quest_poi_points | 23,476 | DESCRIBE to get PK | DESCRIBE first |
| quest_visual_effect | 545 | DESCRIBE to get PK | DESCRIBE first |
| creature_queststarter | 889 | (quest, id) | INSERT IGNORE preserves ours |
| creature_questender | 714 | (quest, id) | INSERT IGNORE preserves ours |
| gameobject_queststarter | 154 | DESCRIBE | DESCRIBE first |
| gameobject_questender | 162 | DESCRIBE | DESCRIBE first |
| creature_questitem | 258 | DESCRIBE | DESCRIBE first |
| gameobject_questitem | 519 | DESCRIBE | DESCRIBE first |

All use INSERT IGNORE. `quest_template_addon`, `quest_details`, etc. import for ALL quests (new + existing that are missing metadata), not just the 198 new quests.

---

## FILE 4: Spawns (~132,000 rows) → `2026_03_08_04_world.sql`

**WRAP IN `SET autocommit=0;` / `COMMIT;`**

**DESCRIBE `creature` and `gameobject` in BOTH databases first** — our tables have extra columns that MUST be excluded.

| Table | ~Rows | PK | Notes |
|-------|-------|----|-------|
| creature | 101,018 | (guid) | VB=0, exclude `size` col, all 4 filters |
| gameobject | 1,290 | (guid) | VB=0, exclude `size`+`visibility`, all 4 filters + corrupt GUID |
| creature_addon | 16,640 | (guid) | Only for GUIDs existing in world.creature |
| gameobject_addon | ~200 | (guid) | Only for GUIDs existing in world.gameobject |
| creature_movement_override | ~100 | (SpawnId) | Only for SpawnIds existing in world.creature |
| spawn_group | 10,145 | DESCRIBE | DESCRIBE first |
| pool_template | 1,886 | (entry) | DESCRIBE first |
| pool_members | 240 | DESCRIBE | DESCRIBE first |
| creature_formations | 1,475 | (leaderGUID, memberGUID) | DESCRIBE first |
| game_event_creature | 1,376 | (guid, eventEntry) | |
| game_event_gameobject | 10,791 | (guid, eventEntry) | Filter corrupt GUIDs |

**Creature spawn pattern**:
```sql
INSERT IGNORE INTO world.creature (guid, id, map, zoneId, areaId, /* ...all cols except size... */, 0 /* VerifiedBuild */)
SELECT l.guid, l.id, l.map, l.zoneId, l.areaId, /* ... */, 0
FROM lorewalker_world.creature l
LEFT JOIN world.creature w ON l.guid = w.guid
WHERE w.guid IS NULL
  AND l.id < 9100000
  AND NOT (l.position_x = 0 AND l.position_y = 0 AND l.position_z = 0)
  AND EXISTS (SELECT 1 FROM world.creature_template ct WHERE ct.entry = l.id);
```

**Gameobject spawn pattern** — same but add `AND l.guid < 1913720832000` and exclude `size` + `visibility` columns, and use `gameobject_template` for orphan check.

For addon tables: only import addons where the GUID already exists in our world DB:
```sql
INSERT IGNORE INTO world.creature_addon (guid, /* cols */)
SELECT l.guid, /* cols */
FROM lorewalker_world.creature_addon l
LEFT JOIN world.creature_addon w ON l.guid = w.guid
WHERE w.guid IS NULL
  AND EXISTS (SELECT 1 FROM world.creature w2 WHERE w2.guid = l.guid);
```

---

## FILE 5: Behavioral (~176,000 rows) → `2026_03_08_05_world.sql`

**WRAP IN `SET autocommit=0;` / `COMMIT;`**

| Table | ~Rows | PK | Notes |
|-------|-------|----|-------|
| smart_scripts | 170,518 | (entryorguid, source_type, id, link) | source_type IN (0,1,2,9), entry filters |
| waypoint_path | 61 | (PathId) | Include `Velocity` column |
| waypoint_path_node | 87 | (PathId, NodeId) | Only for NEW paths |
| npc_vendor | 3,910 | (entry, item, ExtendedCost, type) | VB=0, exclude OverrideGoldCost |
| gossip_menu | 399 | (MenuID, TextID) | VB=0 |
| gossip_menu_option | 279 | (MenuID, OptionID) | VB=0, DESCRIBE first |
| npc_text | 343 | (ID) | DESCRIBE first |
| creature_text | 235 | (CreatureID, GroupID, ID) | DESCRIBE first |
| scene_template | 195 | (SceneId) | Exclude LW's `RTComment` |
| conditions | 1,044 | DESCRIBE — large composite PK | DESCRIBE first, complex JOIN |

**SmartAI pattern**:
```sql
INSERT IGNORE INTO world.smart_scripts (entryorguid, source_type, id, link, /* ...all cols... */)
SELECT l.entryorguid, l.source_type, l.id, l.link, /* ... */
FROM lorewalker_world.smart_scripts l
LEFT JOIN world.smart_scripts w
  ON l.entryorguid = w.entryorguid AND l.source_type = w.source_type
  AND l.id = w.id AND l.link = w.link
WHERE w.entryorguid IS NULL
  AND l.source_type IN (0, 1, 2, 9)
  AND l.entryorguid < 9100000
  AND l.entryorguid > -9100000;
```

**npc_vendor pattern** (explicit columns, our table has extra `OverrideGoldCost`):
```sql
INSERT IGNORE INTO world.npc_vendor
  (entry, slot, item, maxcount, incrtime, ExtendedCost, type, BonusListIDs, PlayerConditionID, IgnoreFiltering, VerifiedBuild)
SELECT l.entry, l.slot, l.item, l.maxcount, l.incrtime, l.ExtendedCost, l.type,
       l.BonusListIDs, l.PlayerConditionID, l.IgnoreFiltering, 0
FROM lorewalker_world.npc_vendor l
LEFT JOIN world.npc_vendor w
  ON l.entry = w.entry AND l.item = w.item AND l.ExtendedCost = w.ExtendedCost AND l.type = w.type
WHERE w.entry IS NULL AND l.entry < 9100000;
```

**scene_template** (exclude LW's extra `RTComment`):
```sql
INSERT IGNORE INTO world.scene_template (SceneId, Flags, ScriptPackageID, Encrypted, ScriptName)
SELECT l.SceneId, l.Flags, l.ScriptPackageID, l.Encrypted, l.ScriptName
FROM lorewalker_world.scene_template l
LEFT JOIN world.scene_template w ON l.SceneId = w.SceneId
WHERE w.SceneId IS NULL;
```

**waypoint_path** (include Velocity):
```sql
INSERT IGNORE INTO world.waypoint_path (PathId, MoveType, Flags, Velocity, Comment)
SELECT l.PathId, l.MoveType, l.Flags, l.Velocity, l.Comment
FROM lorewalker_world.waypoint_path l
LEFT JOIN world.waypoint_path w ON l.PathId = w.PathId
WHERE w.PathId IS NULL;
```

**waypoint_path_node** — only for paths that are NEW:
```sql
INSERT IGNORE INTO world.waypoint_path_node (PathId, NodeId, PositionX, PositionY, PositionZ, Orientation, Delay)
SELECT l.PathId, l.NodeId, l.PositionX, l.PositionY, l.PositionZ, l.Orientation, l.Delay
FROM lorewalker_world.waypoint_path_node l
WHERE l.PathId IN (
    SELECT lp.PathId FROM lorewalker_world.waypoint_path lp
    LEFT JOIN world.waypoint_path wp ON lp.PathId = wp.PathId
    WHERE wp.PathId IS NULL
);
```

---

## FILE 6: Loot Tables (~63,000 rows) → `2026_03_08_06_world.sql`

**WRAP IN `SET autocommit=0;` / `COMMIT;`**

**CRITICAL: ALL loot tables have NO PRIMARY KEY. Use `WHERE NOT EXISTS`, NOT `INSERT IGNORE`.**
**CRITICAL: The column is `ItemType`, NOT `Reference`.**

| Table | ~Rows | Notes |
|-------|-------|-------|
| reference_loot_template | 51 | Import FIRST — other loot tables reference these |
| gameobject_loot_template | 60,244 | Biggest |
| pickpocketing_loot_template | 1,389 | |
| skinning_loot_template | 402 | |
| item_loot_template | 110 | |
| spell_loot_template | 64 | |

DESCRIBE each table to verify columns. They should all have: `Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment`.

**Pattern for ALL loot tables**:
```sql
INSERT INTO world.gameobject_loot_template
  (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT l.Entry, l.ItemType, l.Item, l.Chance, l.QuestRequired, l.LootMode,
       l.GroupId, l.MinCount, l.MaxCount, l.Comment
FROM lorewalker_world.gameobject_loot_template l
WHERE NOT EXISTS (
    SELECT 1 FROM world.gameobject_loot_template w
    WHERE w.Entry = l.Entry AND w.ItemType = l.ItemType AND w.Item = l.Item
);
```

Repeat this pattern for each of the 6 loot tables, substituting the table name.

---

## FILE 7: ContentTuningID Backfill (~7,678 updates) → `2026_03_08_07_world.sql`

```sql
-- Backfill ContentTuningID from LoreWalker where ours is 0
-- LW is build 66102, we're 66263 — safe since we only fill gaps
UPDATE world.creature_template_difficulty w
JOIN lorewalker_world.creature_template_difficulty l
  ON w.Entry = l.Entry AND w.DifficultyID = l.DifficultyID
SET w.ContentTuningID = l.ContentTuningID
WHERE w.ContentTuningID = 0 AND l.ContentTuningID != 0;
```

Run a `SELECT COUNT(*)` first to confirm ~7,678 rows will be affected, then write the file.

---

## DO NOT
- Touch `creature_loot_template`, `spell_script_names`, `trainer`, `trainer_spell` (we lead)
- Import SmartAI `source_type=5` (LW custom, 526K rows)
- Import anything with entry/ID >= 9,100,000 (LW housing system)
- Use DELETE statements
- Apply any SQL files — only generate them
- Build C++ code — this is purely SQL work
- Use `SELECT *` for tables with column count mismatches
- Use `INSERT IGNORE` on loot tables (no PK — use `WHERE NOT EXISTS`)

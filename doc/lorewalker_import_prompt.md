# LoreWalker TDB Import — Claude Code Task Prompt

> **Paste this entire document into a Claude Code tab opened in `C:\Users\atayl\VoxCore\`.**
> Then tell the tab which Files to generate (e.g., "Generate Files 1, 2, 3, and 7").
> See `doc/lorewalker_tab_plan.md` for tab assignments.

---

## Task: Generate LoreWalker TDB Selective Import SQL Files

You are working on VoxCore, a TrinityCore-based WoW private server. A LoreWalker TDB dump (March 6 2026, build 66102) has been loaded into `lorewalker_world` on the same MySQL instance as our production `world` database. Your job is to generate SQL update files that selectively import missing data from LW into our world DB.

### Connection Info
- MySQL: `"C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -padmin`
- Source DB: `lorewalker_world` (935MB, 250 tables, build 66102)
- Target DB: `world` (our production world database, build 66263)
- SQL output dir: `sql/updates/world/master/` (naming: `2026_03_08_NN_world.sql`)
- Today's date: 2026-03-08

### Verified Analysis (3 QA passes, all counts confirmed against live DBs)

**Schema**: All LW tables exist in our world DB. 4 extra columns on OUR side only:
- `creature.size` (default -1)
- `gameobject.size` (default -1)
- `gameobject.visibility` (default 256)
- `npc_vendor.OverrideGoldCost` (default -1)

One extra column on LW side: `lorewalker_world.scene_template.RTComment` (we don't have it — exclude from SELECT).

**No collisions** with our custom ranges (creature_template 400000+, companions 500001-500005, spells 1900003+, portal GOs 620001-620011).

**Data quality filters** (apply to ALL imports):
- LW custom range: `entry/ID >= 9,100,000` (their housing system) → EXCLUDE
- Corrupt GO GUIDs: `guid >= 1,913,720,832,000` (41,911 seasonal artifacts) → EXCLUDE
- Origin spawns: `position_x = 0 AND position_y = 0 AND position_z = 0` (226 total) → EXCLUDE
- Orphan spawns: spawns referencing templates that don't exist in OUR world DB → EXCLUDE

---

## IMPORTANT RULES

1. **DESCRIBE every table in BOTH databases** before writing any INSERT. Never guess column names.
2. **Use INSERT IGNORE** for all tables that have a primary key (idempotent, safe to re-run).
3. **Use `INSERT INTO ... SELECT ... WHERE NOT EXISTS`** for tables with NO primary key (all `*_loot_template` tables). See File 6 for details.
4. **Explicit column lists** (no `SELECT *`) for any table where the two DBs have different column counts. For tables with identical schemas, `SELECT *` is acceptable.
5. **Filter out LW custom range** (`>= 9,100,000`) from every import that has an entry/ID column.
6. **For UPDATE operations** (File 7), use `UPDATE ... JOIN ... WHERE` to only touch rows that need it.
7. **NEVER delete or overwrite** data in tables where we lead: `creature_loot_template`, `spell_script_names`, `trainer`, `trainer_spell`.
8. **VerifiedBuild override**: For tables that have a `VerifiedBuild` column, emit `0 AS VerifiedBuild` in the SELECT instead of copying LW's value. This marks rows as imported.
9. **Performance**: Wrap Files 4, 5, and 6 in `SET autocommit=0;` at the top and `COMMIT;` at the bottom (100K+ row inserts).
10. Every SQL file must start with a comment block explaining what it does and listing estimated row counts.
11. **Do NOT apply** the SQL files — only generate them. User will review and apply manually.

### Tables with VerifiedBuild column (use `0 AS VerifiedBuild`):
creature_template, creature_template_difficulty, creature_template_model, gameobject_template, quest_template, quest_objectives, quest_details, quest_offer_reward, quest_request_items, creature, gameobject, npc_vendor, gossip_menu, gossip_menu_option

### Tables WITHOUT VerifiedBuild (copy all columns):
phase_area, phase_name, gameobject_template_addon, quest_template_addon, creature_addon, gameobject_addon, creature_movement_override, smart_scripts, waypoint_path, waypoint_path_node, scene_template, creature_text, npc_text, conditions, all `*_loot_template` tables, spawn_group, pool_template, pool_members, creature_formations, game_event_creature, game_event_gameobject, creature_equip_template, creature_template_addon, creature_template_spell, quest_poi, quest_poi_points, quest_visual_effect, creature_queststarter, creature_questender, gameobject_queststarter, gameobject_questender, creature_questitem, gameobject_questitem

### Known Schema Pitfalls
- **`gameobject_loot_template`** (and all `*_loot_template` tables): The column is **`ItemType`**, NOT `Reference`. There is NO `Reference` column.
- **`waypoint_path`**: Has a `Velocity` column between `Flags` and `Comment`. Include it in explicit column lists.
- **`creature_addon`**: AnimKit columns (`aiAnimKit`, `movementAnimKit`, `meleeAnimKit`) are `smallint signed` in world but `smallint unsigned` in LW. INSERT IGNORE handles this, but values >32767 would be truncated.
- **`lorewalker_world.scene_template`** has an extra `RTComment` column we don't have. Use explicit column list to exclude it.

---

## Execution Plan — 7 SQL Files

Check what sequence numbers already exist in `sql/updates/world/master/2026_03_08_*` and use the next 7 consecutive numbers.

---

### FILE 1: Phases (~1,279 rows)

**Tables**: `phase_area`, `phase_name`

```sql
-- Phase areas we're missing (662 rows)
INSERT IGNORE INTO world.phase_area (AreaId, PhaseId, Comment)
SELECT l.AreaId, l.PhaseId, l.Comment
FROM lorewalker_world.phase_area l
LEFT JOIN world.phase_area w ON l.AreaId = w.AreaId AND l.PhaseId = w.PhaseId
WHERE w.AreaId IS NULL;

-- Phase names we're missing (617 rows)
INSERT IGNORE INTO world.phase_name (ID, Name)
SELECT l.ID, l.Name
FROM lorewalker_world.phase_name l
LEFT JOIN world.phase_name w ON l.ID = w.ID
WHERE w.ID IS NULL;
```

DESCRIBE both tables first to verify column names match.

---

### FILE 2: Templates (~4,450 rows)

**Tables**: `creature_template`, `creature_template_difficulty`, `creature_template_model`, `creature_template_addon`, `creature_template_spell`, `creature_equip_template`, `gameobject_template`, `gameobject_template_addon`

Import NEW entries only (LEFT JOIN exclusion). Filter `entry < 9100000` on all.

**creature_template** (~10 new entries): DESCRIBE in both DBs. Our table is identical to LW — use explicit column list anyway for safety, with `0 AS VerifiedBuild`.

**creature_template_difficulty** (~20 rows): Import ALL missing rows (not just for new templates — some existing templates have difficulty rows in LW that we lack). This is important because File 7's ContentTuningID backfill needs the rows to exist. JOIN on `(Entry, DifficultyID)`. Override VerifiedBuild to 0.

**creature_template_model** (~13 rows): For new templates only. JOIN on `(CreatureID, Idx)`. Override VerifiedBuild to 0.

**creature_template_addon** (~125 rows): All missing rows. JOIN on `(entry)`.

**creature_template_spell** (~163 rows): All missing rows. JOIN on `(CreatureID, Index)`. Backtick `Index` — it's a reserved word.

**creature_equip_template** (~2,023 rows): All missing rows. JOIN on `(CreatureID, ID)`.

**gameobject_template** (~2,089 rows): DESCRIBE in both DBs. Override VerifiedBuild to 0.

**gameobject_template_addon** (~10 rows): For new GO templates.

DESCRIBE every table before writing. Use explicit column lists where schema differs.

---

### FILE 3: Quests (~98,000 rows)

**Tables**: `quest_template`, `quest_template_addon`, `quest_objectives`, `quest_details`, `quest_offer_reward`, `quest_request_items`, `quest_poi`, `quest_poi_points`, `quest_visual_effect`, `creature_queststarter`, `creature_questender`, `gameobject_queststarter`, `gameobject_questender`, `creature_questitem`, `gameobject_questitem`

**quest_template** (~198 new quests): Only new (LEFT JOIN on ID), filter `ID < 9100000`. Override VerifiedBuild to 0.

**quest_template_addon** (~57,611 rows): Import for ALL quests (new AND existing) that are missing addon data. LEFT JOIN on `(QuestId)`.

**quest_objectives** (~888 rows): All missing. LEFT JOIN on `(ID)`. Override VerifiedBuild to 0.

**quest_details** (~962 rows): All missing. LEFT JOIN on `(ID)`. Override VerifiedBuild to 0.

**quest_offer_reward** (~551 rows): All missing. LEFT JOIN on `(ID)`. Override VerifiedBuild to 0.

**quest_request_items** (~1,894 rows): All missing. LEFT JOIN on `(ID)`. Override VerifiedBuild to 0.

**quest_poi** (~10,424 rows): Quest map markers. DESCRIBE to get columns and PK. LEFT JOIN exclusion.

**quest_poi_points** (~23,476 rows): Map marker polygon vertices. DESCRIBE to get columns and PK. LEFT JOIN exclusion.

**quest_visual_effect** (~545 rows): DESCRIBE to get columns and PK.

**creature_queststarter** (~889 rows): INSERT IGNORE preserves our existing data while adding LW-only entries. LEFT JOIN on `(quest, id)`.

**creature_questender** (~714 rows): Same pattern as queststarter.

**gameobject_queststarter** (~154 rows), **gameobject_questender** (~162 rows): Same pattern.

**creature_questitem** (~258 rows), **gameobject_questitem** (~519 rows): DESCRIBE to get PKs.

DESCRIBE every table before writing.

---

### FILE 4: Spawns (~132,000 rows) — WRAP IN autocommit=0/COMMIT

**Tables**: `creature`, `gameobject`, `creature_addon`, `gameobject_addon`, `creature_movement_override`, `spawn_group`, `pool_template`, `pool_members`, `creature_formations`, `game_event_creature`, `game_event_gameobject`

**creature spawns** (~101,018 rows):
```sql
SET autocommit=0;

-- DESCRIBE world.creature and lorewalker_world.creature first!
-- Our creature table has extra column 'size' — use explicit column list excluding it.
INSERT IGNORE INTO world.creature (guid, id, map, zoneId, areaId, /* ...all cols except size... */)
SELECT l.guid, l.id, l.map, l.zoneId, l.areaId, /* ... */, 0 AS VerifiedBuild
FROM lorewalker_world.creature l
LEFT JOIN world.creature w ON l.guid = w.guid
WHERE w.guid IS NULL
  AND l.id < 9100000
  AND NOT (l.position_x = 0 AND l.position_y = 0 AND l.position_z = 0)
  AND EXISTS (SELECT 1 FROM world.creature_template ct WHERE ct.entry = l.id);
```

**gameobject spawns** (~1,290 rows): Same pattern as creature, plus:
- Extra columns to exclude: `size`, `visibility`
- Additional filter: `AND l.guid < 1913720832000` (corrupt GUID filter)
- Orphan filter: `AND EXISTS (SELECT 1 FROM world.gameobject_template gt WHERE gt.entry = l.id)`

**creature_addon** (~16,640 rows): Import all missing. LEFT JOIN on `(guid)`. Only import for GUIDs that exist in world.creature (use EXISTS).

**gameobject_addon** (~200 rows): Same pattern as creature_addon.

**creature_movement_override** (~100 rows): For GUIDs that exist in world.creature.

**spawn_group** (~10,145 rows): DESCRIBE to get columns and PK. LEFT JOIN exclusion.

**pool_template** (~1,886 rows): DESCRIBE. LEFT JOIN on `(entry)`.

**pool_members** (~240 rows): DESCRIBE. LEFT JOIN exclusion.

**creature_formations** (~1,475 rows): DESCRIBE. LEFT JOIN on `(leaderGUID, memberGUID)`.

**game_event_creature** (~1,376 rows): LEFT JOIN on `(guid, eventEntry)`.

**game_event_gameobject** (~10,791 rows): LEFT JOIN on `(guid, eventEntry)`. Apply corrupt GUID filter (`guid < 1913720832000`).

End file with `COMMIT;`

DESCRIBE `creature` and `gameobject` in BOTH databases — the extra columns MUST be excluded from the column lists.

---

### FILE 5: Behavioral (~176,000 rows) — WRAP IN autocommit=0/COMMIT

**Tables**: `smart_scripts`, `waypoint_path`, `waypoint_path_node`, `npc_vendor`, `gossip_menu`, `gossip_menu_option`, `npc_text`, `creature_text`, `scene_template`, `conditions`

**smart_scripts** (~170,518 rows):
```sql
SET autocommit=0;

INSERT IGNORE INTO world.smart_scripts
  (entryorguid, source_type, id, link, /* ...all columns... */)
SELECT l.entryorguid, l.source_type, l.id, l.link, /* ... */
FROM lorewalker_world.smart_scripts l
LEFT JOIN world.smart_scripts w
  ON l.entryorguid = w.entryorguid
  AND l.source_type = w.source_type
  AND l.id = w.id
  AND l.link = w.link
WHERE w.entryorguid IS NULL
  AND l.source_type IN (0, 1, 2, 9)   -- creature, gameobject, areatrigger, timed actionlist
  AND l.entryorguid < 9100000          -- exclude LW custom range
  AND l.entryorguid > -9100000;        -- exclude LW custom (negative = per-GUID)
```

**waypoint_path** (~61 rows): Include ALL columns — DESCRIBE first. Note: table has `Velocity` column between Flags and Comment.
```sql
INSERT IGNORE INTO world.waypoint_path (PathId, MoveType, Flags, Velocity, Comment)
SELECT l.PathId, l.MoveType, l.Flags, l.Velocity, l.Comment
FROM lorewalker_world.waypoint_path l
LEFT JOIN world.waypoint_path w ON l.PathId = w.PathId
WHERE w.PathId IS NULL;
```

**waypoint_path_node** (~87 rows): Nodes for NEW paths only.
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

**npc_vendor** (~3,910 rows): Explicit column list — our table has extra `OverrideGoldCost`.
```sql
INSERT IGNORE INTO world.npc_vendor
  (entry, slot, item, maxcount, incrtime, ExtendedCost, type, BonusListIDs, PlayerConditionID, IgnoreFiltering, VerifiedBuild)
SELECT l.entry, l.slot, l.item, l.maxcount, l.incrtime, l.ExtendedCost, l.type,
       l.BonusListIDs, l.PlayerConditionID, l.IgnoreFiltering, 0
FROM lorewalker_world.npc_vendor l
LEFT JOIN world.npc_vendor w
  ON l.entry = w.entry AND l.item = w.item AND l.ExtendedCost = w.ExtendedCost AND l.type = w.type
WHERE w.entry IS NULL
  AND l.entry < 9100000;
```

**gossip_menu** (~399 rows): Override VerifiedBuild to 0.
```sql
INSERT IGNORE INTO world.gossip_menu (MenuID, TextID, VerifiedBuild)
SELECT l.MenuID, l.TextID, 0
FROM lorewalker_world.gossip_menu l
LEFT JOIN world.gossip_menu w ON l.MenuID = w.MenuID AND l.TextID = w.TextID
WHERE w.MenuID IS NULL;
```

**gossip_menu_option** (~279 rows): DESCRIBE first. LEFT JOIN on `(MenuID, OptionID)`. Override VerifiedBuild to 0.

**npc_text** (~343 rows): DESCRIBE first. LEFT JOIN on `(ID)`.

**creature_text** (~235 rows): DESCRIBE first. LEFT JOIN on `(CreatureID, GroupID, ID)`.

**scene_template** (~195 rows): Use explicit column list — LW has extra `RTComment` we don't have.
```sql
INSERT IGNORE INTO world.scene_template (SceneId, Flags, ScriptPackageID, Encrypted, ScriptName)
SELECT l.SceneId, l.Flags, l.ScriptPackageID, l.Encrypted, l.ScriptName
FROM lorewalker_world.scene_template l
LEFT JOIN world.scene_template w ON l.SceneId = w.SceneId
WHERE w.SceneId IS NULL;
```

**conditions** (~1,044 rows): DESCRIBE first — conditions table has a large composite key. LEFT JOIN on all PK columns.

End file with `COMMIT;`

---

### FILE 6: Loot Tables (~63,000 rows) — SPECIAL: WHERE NOT EXISTS

**CRITICAL**: All `*_loot_template` tables have **NO primary key** and **NO unique index**. `INSERT IGNORE` would blindly insert all rows every time (nothing to collide on). Use `WHERE NOT EXISTS` for idempotency.

**CRITICAL**: The item type column is called **`ItemType`**, NOT `Reference`.

**WRAP IN autocommit=0/COMMIT.**

**reference_loot_template** (~51 rows) — import FIRST (other loot tables may reference these):
```sql
SET autocommit=0;

INSERT INTO world.reference_loot_template (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT l.Entry, l.ItemType, l.Item, l.Chance, l.QuestRequired, l.LootMode, l.GroupId, l.MinCount, l.MaxCount, l.Comment
FROM lorewalker_world.reference_loot_template l
WHERE NOT EXISTS (
    SELECT 1 FROM world.reference_loot_template w
    WHERE w.Entry = l.Entry AND w.ItemType = l.ItemType AND w.Item = l.Item
);
```

**gameobject_loot_template** (~60,244 rows):
```sql
INSERT INTO world.gameobject_loot_template (Entry, ItemType, Item, Chance, QuestRequired, LootMode, GroupId, MinCount, MaxCount, Comment)
SELECT l.Entry, l.ItemType, l.Item, l.Chance, l.QuestRequired, l.LootMode, l.GroupId, l.MinCount, l.MaxCount, l.Comment
FROM lorewalker_world.gameobject_loot_template l
WHERE NOT EXISTS (
    SELECT 1 FROM world.gameobject_loot_template w
    WHERE w.Entry = l.Entry AND w.ItemType = l.ItemType AND w.Item = l.Item
);
```

**pickpocketing_loot_template** (~1,389 rows), **skinning_loot_template** (~402 rows), **item_loot_template** (~110 rows), **spell_loot_template** (~64 rows): Same `WHERE NOT EXISTS` pattern. DESCRIBE each to verify column names match (they should all follow the same schema as gameobject_loot_template).

End file with `COMMIT;`

---

### FILE 7: ContentTuningID Backfill (~7,678 updates)

Use LW's ContentTuningID values to fill our CT=0 gaps.

```sql
-- Preview count first:
-- SELECT COUNT(*) FROM world.creature_template_difficulty w
-- JOIN lorewalker_world.creature_template_difficulty l
--   ON w.Entry = l.Entry AND w.DifficultyID = l.DifficultyID
-- WHERE w.ContentTuningID = 0 AND l.ContentTuningID != 0;

UPDATE world.creature_template_difficulty w
JOIN lorewalker_world.creature_template_difficulty l
  ON w.Entry = l.Entry AND w.DifficultyID = l.DifficultyID
SET w.ContentTuningID = l.ContentTuningID
WHERE w.ContentTuningID = 0 AND l.ContentTuningID != 0;
```

Run the SELECT COUNT first and report the result before writing the file.

---

## Build Version Note

LoreWalker is build 66102, we are build 66263. For ContentTuningID backfill (File 7) this is safe since we only fill CT=0 gaps. For other data, INSERT IGNORE / WHERE NOT EXISTS means our newer data always wins.

## Verification Steps (after each file is applied)

1. Apply with: `"C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -padmin world < filename.sql`
2. Check `DBErrors.log` for errors
3. Report: rows affected per statement

## Final Deliverable

7 SQL update files in `sql/updates/world/master/`, each with:
- Header comment block explaining contents and estimated row counts
- Idempotent INSERT IGNORE / WHERE NOT EXISTS / conditional UPDATE
- Explicit column lists for tables with schema differences
- All filters applied (corrupt GUIDs, origin spawns, orphans, LW custom range)
- VerifiedBuild = 0 for tables that have the column

After all files are generated, provide a summary table showing actual rows per statement.

## DO NOT:
- Overwrite tables where we lead: `creature_loot_template`, `spell_script_names`, `trainer`, `trainer_spell`
- Import SmartAI source_type=5 (LW custom scene extension, 526K rows)
- Import LW custom range (entry/ID >= 9,100,000)
- Use DELETE statements
- Apply the SQL files — only generate them
- Build any C++ code — this is purely SQL work

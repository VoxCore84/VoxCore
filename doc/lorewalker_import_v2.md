# LoreWalker TDB Import — Optimized Execution Prompt

> Paste this entire prompt into a Claude Code tab opened in `C:\Users\atayl\VoxCore\`.
> The tab generates 7 SQL files. All column lists are pre-baked — **do NOT run any DESCRIBE commands**.

## Task

Write 7 SQL update files to `sql/updates/world/master/`. Each file's complete SQL is provided below — your job is to write them to disk using the Write tool, then run verification queries.

## Connection

- MySQL: `"C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -padmin`
- Source: `lorewalker_world` (935MB, build 66102)
- Target: `world` (build 66263)

## Rules

1. **No DESCRIBEs** — all schemas are verified and baked into the SQL below
2. **No applying SQL** — only write the files
3. **No C++ builds** — purely SQL file generation
4. Check `sql/updates/world/master/2026_03_08_*` for existing sequence numbers, then use the next 7 consecutive (likely 01-07)
5. Write all 7 files (use Write tool), then run the verification queries at the bottom
6. Each file must start with the header comment shown

## Important Schema Notes (already handled in the SQL below)

- `world.creature` has extra column `size` (default -1) — excluded from INSERT
- `world.gameobject` has extra columns `size` (default -1), `visibility` (default 256) — excluded
- `world.npc_vendor` has extra column `OverrideGoldCost` (default -1) — excluded
- `lorewalker_world.scene_template` has extra column `RTComment` — excluded
- `creature_queststarter/questender`, `gameobject_queststarter/questender` have **VerifiedBuild in the PK** — dedup uses business-key NOT EXISTS instead of INSERT IGNORE
- All `*_loot_template` tables have **no primary key** — uses WHERE NOT EXISTS on (Entry, ItemType, Item)
- Column is `ItemType`, NOT `Reference`, on all loot tables

---

## FILE 1 — Phases

**Filename**: `2026_03_08_XX_world.sql` (replace XX with first available sequence number)

```sql
-- LoreWalker TDB Import — File 1: Phases
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- phase_area: ~662 rows | phase_name: ~617 rows

-- phase_area (PK: AreaId, PhaseId)
INSERT IGNORE INTO world.phase_area
SELECT * FROM lorewalker_world.phase_area;

-- phase_name (PK: ID)
INSERT IGNORE INTO world.phase_name
SELECT * FROM lorewalker_world.phase_name;
```

---

## FILE 2 — Templates

```sql
-- LoreWalker TDB Import — File 2: Templates
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- creature_template ~10, creature_template_difficulty ~20, creature_template_model ~13,
-- creature_template_addon ~125, creature_template_spell ~163, creature_equip_template ~2023,
-- gameobject_template ~2089, gameobject_template_addon ~10

-- creature_template (PK: entry, identical schema, VB override via temp table)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.creature_template WHERE entry < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.creature_template SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- creature_template_difficulty (PK: Entry,DifficultyID — import ALL missing, not just new templates)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.creature_template_difficulty WHERE Entry < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.creature_template_difficulty SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- creature_template_model (PK: CreatureID,Idx)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.creature_template_model WHERE CreatureID < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.creature_template_model SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- creature_template_addon (PK: entry, no VB column, identical schema)
INSERT IGNORE INTO world.creature_template_addon
SELECT * FROM lorewalker_world.creature_template_addon
WHERE entry < 9100000;

-- creature_template_spell (PK: CreatureID,`Index` — Index is reserved word, but SELECT * avoids it)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.creature_template_spell WHERE CreatureID < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.creature_template_spell SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- creature_equip_template (PK: CreatureID,ID)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.creature_equip_template WHERE CreatureID < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.creature_equip_template SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- gameobject_template (PK: entry, identical schema)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.gameobject_template WHERE entry < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.gameobject_template SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- gameobject_template_addon (PK: entry, no VB, identical schema)
INSERT IGNORE INTO world.gameobject_template_addon
SELECT * FROM lorewalker_world.gameobject_template_addon
WHERE entry < 9100000;
```

---

## FILE 3 — Quests

```sql
-- LoreWalker TDB Import — File 3: Quests
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- quest_template ~198, quest_template_addon ~57611, quest_objectives ~888,
-- quest_details ~962, quest_offer_reward ~551, quest_request_items ~1894,
-- quest_poi ~10424, quest_poi_points ~23476, quest_visual_effect ~545,
-- creature_queststarter ~889, creature_questender ~714,
-- gameobject_queststarter ~154, gameobject_questender ~162,
-- creature_questitem ~258, gameobject_questitem ~519

-- quest_template (PK: ID, 105 columns — temp table avoids listing them all)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.quest_template WHERE ID < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.quest_template SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- quest_template_addon (PK: ID, no VB, identical schema — import for ALL quests)
INSERT IGNORE INTO world.quest_template_addon
SELECT * FROM lorewalker_world.quest_template_addon
WHERE ID < 9100000;

-- quest_objectives (PK: ID)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.quest_objectives WHERE QuestID < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.quest_objectives SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- quest_details (PK: ID)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.quest_details WHERE ID < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.quest_details SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- quest_offer_reward (PK: ID)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.quest_offer_reward WHERE ID < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.quest_offer_reward SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- quest_request_items (PK: ID)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.quest_request_items WHERE ID < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.quest_request_items SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- quest_poi (PK: QuestID,BlobIndex,Idx1)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.quest_poi WHERE QuestID < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.quest_poi SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- quest_poi_points (PK: QuestID,Idx1,Idx2)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.quest_poi_points WHERE QuestID < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.quest_poi_points SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- quest_visual_effect (PK: ID,`Index`)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.quest_visual_effect;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.quest_visual_effect SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- creature_queststarter (PK: id,quest,VerifiedBuild — VB IS IN THE PK!)
-- Must dedup on business key (id,quest) only, ignoring VB
INSERT IGNORE INTO world.creature_queststarter (id, quest, VerifiedBuild)
SELECT l.id, l.quest, 0
FROM lorewalker_world.creature_queststarter l
WHERE NOT EXISTS (
  SELECT 1 FROM world.creature_queststarter w
  WHERE w.id = l.id AND w.quest = l.quest
);

-- creature_questender (PK: id,quest,VerifiedBuild — same VB-in-PK issue)
INSERT IGNORE INTO world.creature_questender (id, quest, VerifiedBuild)
SELECT l.id, l.quest, 0
FROM lorewalker_world.creature_questender l
WHERE NOT EXISTS (
  SELECT 1 FROM world.creature_questender w
  WHERE w.id = l.id AND w.quest = l.quest
);

-- gameobject_queststarter (PK: id,quest,VerifiedBuild)
INSERT IGNORE INTO world.gameobject_queststarter (id, quest, VerifiedBuild)
SELECT l.id, l.quest, 0
FROM lorewalker_world.gameobject_queststarter l
WHERE NOT EXISTS (
  SELECT 1 FROM world.gameobject_queststarter w
  WHERE w.id = l.id AND w.quest = l.quest
);

-- gameobject_questender (PK: id,quest,VerifiedBuild)
INSERT IGNORE INTO world.gameobject_questender (id, quest, VerifiedBuild)
SELECT l.id, l.quest, 0
FROM lorewalker_world.gameobject_questender l
WHERE NOT EXISTS (
  SELECT 1 FROM world.gameobject_questender w
  WHERE w.id = l.id AND w.quest = l.quest
);

-- creature_questitem (PK: CreatureEntry,DifficultyID,Idx — VB not in PK)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.creature_questitem WHERE CreatureEntry < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.creature_questitem SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- gameobject_questitem (PK: GameObjectEntry,Idx — VB not in PK)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.gameobject_questitem WHERE GameObjectEntry < 9100000;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.gameobject_questitem SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;
```

---

## FILE 4 — Spawns (WRAP IN autocommit/COMMIT)

```sql
-- LoreWalker TDB Import — File 4: Spawns
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- creature ~101018, gameobject ~1290, creature_addon ~16640, gameobject_addon ~200,
-- creature_movement_override ~100, spawn_group ~10145, pool_template ~1886,
-- pool_members ~240, creature_formations ~1475, game_event_creature ~1376,
-- game_event_gameobject ~10791

SET autocommit=0;

-- creature (PK: guid)
-- SCHEMA DIFF: world.creature has extra column 'size' — explicit column list required
INSERT IGNORE INTO world.creature
  (guid, id, map, zoneId, areaId, spawnDifficulties, phaseUseFlags, PhaseId, PhaseGroup,
   terrainSwapMap, modelid, equipment_id, position_x, position_y, position_z, orientation,
   spawntimesecs, wander_distance, currentwaypoint, curHealthPct, MovementType, npcflag,
   unit_flags, unit_flags2, unit_flags3, ScriptName, StringId, VerifiedBuild)
SELECT
  l.guid, l.id, l.map, l.zoneId, l.areaId, l.spawnDifficulties, l.phaseUseFlags, l.PhaseId,
  l.PhaseGroup, l.terrainSwapMap, l.modelid, l.equipment_id, l.position_x, l.position_y,
  l.position_z, l.orientation, l.spawntimesecs, l.wander_distance, l.currentwaypoint,
  l.curHealthPct, l.MovementType, l.npcflag, l.unit_flags, l.unit_flags2, l.unit_flags3,
  l.ScriptName, l.StringId, 0
FROM lorewalker_world.creature l
WHERE l.id < 9100000
  AND NOT (l.position_x = 0 AND l.position_y = 0 AND l.position_z = 0)
  AND EXISTS (SELECT 1 FROM world.creature_template ct WHERE ct.entry = l.id);

-- gameobject (PK: guid)
-- SCHEMA DIFF: world.gameobject has extra columns 'size', 'visibility'
INSERT IGNORE INTO world.gameobject
  (guid, id, map, zoneId, areaId, spawnDifficulties, phaseUseFlags, PhaseId, PhaseGroup,
   terrainSwapMap, position_x, position_y, position_z, orientation, rotation0, rotation1,
   rotation2, rotation3, spawntimesecs, animprogress, state, ScriptName, StringId, VerifiedBuild)
SELECT
  l.guid, l.id, l.map, l.zoneId, l.areaId, l.spawnDifficulties, l.phaseUseFlags, l.PhaseId,
  l.PhaseGroup, l.terrainSwapMap, l.position_x, l.position_y, l.position_z, l.orientation,
  l.rotation0, l.rotation1, l.rotation2, l.rotation3, l.spawntimesecs, l.animprogress,
  l.state, l.ScriptName, l.StringId, 0
FROM lorewalker_world.gameobject l
WHERE l.id < 9100000
  AND l.guid < 1913720832000
  AND NOT (l.position_x = 0 AND l.position_y = 0 AND l.position_z = 0)
  AND EXISTS (SELECT 1 FROM world.gameobject_template gt WHERE gt.entry = l.id);

-- creature_addon (PK: guid, no VB, identical schema)
-- Only for GUIDs that exist in world.creature (includes newly imported above)
INSERT IGNORE INTO world.creature_addon
SELECT l.* FROM lorewalker_world.creature_addon l
WHERE EXISTS (SELECT 1 FROM world.creature w WHERE w.guid = l.guid);

-- gameobject_addon (PK: guid, no VB, identical schema)
INSERT IGNORE INTO world.gameobject_addon
SELECT l.* FROM lorewalker_world.gameobject_addon l
WHERE EXISTS (SELECT 1 FROM world.gameobject w WHERE w.guid = l.guid);

-- creature_movement_override (PK: SpawnId, no VB, identical schema)
INSERT IGNORE INTO world.creature_movement_override
SELECT l.* FROM lorewalker_world.creature_movement_override l
WHERE EXISTS (SELECT 1 FROM world.creature w WHERE w.guid = l.SpawnId);

-- spawn_group (PK: groupId,spawnType,spawnId — no VB, identical schema)
INSERT IGNORE INTO world.spawn_group
SELECT * FROM lorewalker_world.spawn_group;

-- pool_template (PK: entry, no VB, identical schema)
INSERT IGNORE INTO world.pool_template
SELECT * FROM lorewalker_world.pool_template;

-- pool_members (PK: type,spawnId — no VB, identical schema)
INSERT IGNORE INTO world.pool_members
SELECT * FROM lorewalker_world.pool_members;

-- creature_formations (PK: memberGUID, no VB, identical schema)
INSERT IGNORE INTO world.creature_formations
SELECT l.* FROM lorewalker_world.creature_formations l
WHERE EXISTS (SELECT 1 FROM world.creature w WHERE w.guid = l.memberGUID);

-- game_event_creature (PK: guid,eventEntry — no VB, identical schema)
INSERT IGNORE INTO world.game_event_creature
SELECT l.* FROM lorewalker_world.game_event_creature l
WHERE EXISTS (SELECT 1 FROM world.creature w WHERE w.guid = l.guid);

-- game_event_gameobject (PK: guid,eventEntry — no VB, identical schema)
-- Also apply corrupt GUID filter
INSERT IGNORE INTO world.game_event_gameobject
SELECT l.* FROM lorewalker_world.game_event_gameobject l
WHERE l.guid < 1913720832000
  AND EXISTS (SELECT 1 FROM world.gameobject w WHERE w.guid = l.guid);

COMMIT;
```

---

## FILE 5 — Behavioral (WRAP IN autocommit/COMMIT)

```sql
-- LoreWalker TDB Import — File 5: Behavioral
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- smart_scripts ~170518, waypoint_path ~61, waypoint_path_node ~87,
-- npc_vendor ~3910, gossip_menu ~399, gossip_menu_option ~279,
-- npc_text ~343, creature_text ~235, scene_template ~195, conditions ~1044

SET autocommit=0;

-- smart_scripts (PK: entryorguid,source_type,id,link — no VB, identical schema)
-- source_type filter: 0=creature, 1=gameobject, 2=areatrigger, 9=timed, 12=spell
INSERT IGNORE INTO world.smart_scripts
SELECT * FROM lorewalker_world.smart_scripts
WHERE source_type IN (0, 1, 2, 9, 12)
  AND entryorguid < 9100000
  AND entryorguid > -9100000;

-- waypoint_path (PK: PathId, no VB, identical schema — includes Velocity column)
INSERT IGNORE INTO world.waypoint_path
SELECT * FROM lorewalker_world.waypoint_path;

-- waypoint_path_node (PK: PathId,NodeId — no VB, identical schema)
-- Conservative: only import nodes for all paths (INSERT IGNORE skips existing PathId+NodeId)
INSERT IGNORE INTO world.waypoint_path_node
SELECT * FROM lorewalker_world.waypoint_path_node;

-- npc_vendor (PK: entry,item,ExtendedCost,type — VB not in PK)
-- SCHEMA DIFF: world has extra 'OverrideGoldCost' column — explicit column list
INSERT IGNORE INTO world.npc_vendor
  (entry, slot, item, maxcount, incrtime, ExtendedCost, type,
   BonusListIDs, PlayerConditionID, IgnoreFiltering, VerifiedBuild)
SELECT
  l.entry, l.slot, l.item, l.maxcount, l.incrtime, l.ExtendedCost, l.type,
  l.BonusListIDs, l.PlayerConditionID, l.IgnoreFiltering, 0
FROM lorewalker_world.npc_vendor l
WHERE l.entry < 9100000;

-- gossip_menu (PK: MenuID,TextID — VB not in PK, identical schema)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.gossip_menu;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.gossip_menu SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- gossip_menu_option (PK: MenuID,OptionID — VB not in PK, identical schema)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.gossip_menu_option;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.gossip_menu_option SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- npc_text (PK: ID — VB not in PK, identical schema)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.npc_text;
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.npc_text SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- creature_text (PK: CreatureID,GroupID,ID — no VB, identical schema)
INSERT IGNORE INTO world.creature_text
SELECT * FROM lorewalker_world.creature_text
WHERE CreatureID < 9100000;

-- scene_template (PK: SceneId, no VB)
-- SCHEMA DIFF: LW has extra 'RTComment' column — explicit column list
INSERT IGNORE INTO world.scene_template (SceneId, Flags, ScriptPackageID, Encrypted, ScriptName)
SELECT SceneId, Flags, ScriptPackageID, Encrypted, ScriptName
FROM lorewalker_world.scene_template;

-- conditions (PK: 11-column composite — no VB, identical schema)
INSERT IGNORE INTO world.conditions
SELECT * FROM lorewalker_world.conditions;

COMMIT;
```

---

## FILE 6 — Loot Tables (WRAP IN autocommit/COMMIT)

**CRITICAL**: All `*_loot_template` tables have **NO primary key**. INSERT IGNORE cannot dedup. Use `WHERE NOT EXISTS` on `(Entry, ItemType, Item)` for idempotency.

```sql
-- LoreWalker TDB Import — File 6: Loot Tables
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- reference_loot_template ~51, gameobject_loot_template ~60244,
-- pickpocketing_loot_template ~1389, skinning_loot_template ~402,
-- item_loot_template ~110, spell_loot_template ~64
-- NOTE: creature_loot_template intentionally excluded (we lead with raidbots data)

SET autocommit=0;

-- reference_loot_template (MUST COME FIRST — referenced by other loot tables)
INSERT INTO world.reference_loot_template
SELECT l.* FROM lorewalker_world.reference_loot_template l
WHERE NOT EXISTS (
  SELECT 1 FROM world.reference_loot_template w
  WHERE w.Entry = l.Entry AND w.ItemType = l.ItemType AND w.Item = l.Item
);

-- gameobject_loot_template
INSERT INTO world.gameobject_loot_template
SELECT l.* FROM lorewalker_world.gameobject_loot_template l
WHERE NOT EXISTS (
  SELECT 1 FROM world.gameobject_loot_template w
  WHERE w.Entry = l.Entry AND w.ItemType = l.ItemType AND w.Item = l.Item
);

-- pickpocketing_loot_template
INSERT INTO world.pickpocketing_loot_template
SELECT l.* FROM lorewalker_world.pickpocketing_loot_template l
WHERE NOT EXISTS (
  SELECT 1 FROM world.pickpocketing_loot_template w
  WHERE w.Entry = l.Entry AND w.ItemType = l.ItemType AND w.Item = l.Item
);

-- skinning_loot_template
INSERT INTO world.skinning_loot_template
SELECT l.* FROM lorewalker_world.skinning_loot_template l
WHERE NOT EXISTS (
  SELECT 1 FROM world.skinning_loot_template w
  WHERE w.Entry = l.Entry AND w.ItemType = l.ItemType AND w.Item = l.Item
);

-- item_loot_template
INSERT INTO world.item_loot_template
SELECT l.* FROM lorewalker_world.item_loot_template l
WHERE NOT EXISTS (
  SELECT 1 FROM world.item_loot_template w
  WHERE w.Entry = l.Entry AND w.ItemType = l.ItemType AND w.Item = l.Item
);

-- spell_loot_template
INSERT INTO world.spell_loot_template
SELECT l.* FROM lorewalker_world.spell_loot_template l
WHERE NOT EXISTS (
  SELECT 1 FROM world.spell_loot_template w
  WHERE w.Entry = l.Entry AND w.ItemType = l.ItemType AND w.Item = l.Item
);

COMMIT;
```

---

## FILE 7 — ContentTuningID Backfill

```sql
-- LoreWalker TDB Import — File 7: ContentTuningID Backfill
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- Updates creature_template_difficulty.ContentTuningID where ours = 0 and LW has a value
-- Estimated: ~7,678 rows updated

UPDATE world.creature_template_difficulty w
JOIN lorewalker_world.creature_template_difficulty l
  ON w.Entry = l.Entry AND w.DifficultyID = l.DifficultyID
SET w.ContentTuningID = l.ContentTuningID
WHERE w.ContentTuningID = 0 AND l.ContentTuningID != 0;
```

---

## Verification

After writing all 7 files, run these queries to confirm row estimates. Report the results as a summary table.

```sql
-- Run all at once:
SELECT 'phase_area' AS tbl, COUNT(*) AS new_rows FROM lorewalker_world.phase_area l WHERE NOT EXISTS (SELECT 1 FROM world.phase_area w WHERE w.AreaId = l.AreaId AND w.PhaseId = l.PhaseId)
UNION ALL
SELECT 'phase_name', COUNT(*) FROM lorewalker_world.phase_name l WHERE NOT EXISTS (SELECT 1 FROM world.phase_name w WHERE w.ID = l.ID)
UNION ALL
SELECT 'creature_template', COUNT(*) FROM lorewalker_world.creature_template l WHERE l.entry < 9100000 AND NOT EXISTS (SELECT 1 FROM world.creature_template w WHERE w.entry = l.entry)
UNION ALL
SELECT 'gameobject_template', COUNT(*) FROM lorewalker_world.gameobject_template l WHERE l.entry < 9100000 AND NOT EXISTS (SELECT 1 FROM world.gameobject_template w WHERE w.entry = l.entry)
UNION ALL
SELECT 'quest_template', COUNT(*) FROM lorewalker_world.quest_template l WHERE l.ID < 9100000 AND NOT EXISTS (SELECT 1 FROM world.quest_template w WHERE w.ID = l.ID)
UNION ALL
SELECT 'quest_template_addon', COUNT(*) FROM lorewalker_world.quest_template_addon l WHERE l.ID < 9100000 AND NOT EXISTS (SELECT 1 FROM world.quest_template_addon w WHERE w.ID = l.ID)
UNION ALL
SELECT 'creature_spawns', COUNT(*) FROM lorewalker_world.creature l WHERE l.id < 9100000 AND NOT (l.position_x = 0 AND l.position_y = 0 AND l.position_z = 0) AND EXISTS (SELECT 1 FROM world.creature_template ct WHERE ct.entry = l.id) AND NOT EXISTS (SELECT 1 FROM world.creature w WHERE w.guid = l.guid)
UNION ALL
SELECT 'smart_scripts', COUNT(*) FROM lorewalker_world.smart_scripts l WHERE l.source_type IN (0,1,2,9,12) AND l.entryorguid < 9100000 AND l.entryorguid > -9100000 AND NOT EXISTS (SELECT 1 FROM world.smart_scripts w WHERE w.entryorguid = l.entryorguid AND w.source_type = l.source_type AND w.id = l.id AND w.link = l.link)
UNION ALL
SELECT 'go_loot', COUNT(*) FROM lorewalker_world.gameobject_loot_template l WHERE NOT EXISTS (SELECT 1 FROM world.gameobject_loot_template w WHERE w.Entry = l.Entry AND w.ItemType = l.ItemType AND w.Item = l.Item)
UNION ALL
SELECT 'ct_backfill', COUNT(*) FROM world.creature_template_difficulty w JOIN lorewalker_world.creature_template_difficulty l ON w.Entry = l.Entry AND w.DifficultyID = l.DifficultyID WHERE w.ContentTuningID = 0 AND l.ContentTuningID != 0;
```

Report the results, confirm they're in the expected ranges, and list all 7 filenames with their full paths.

## DO NOT

- Run any DESCRIBE commands (schemas are pre-baked)
- Apply the SQL files (user will review and apply manually)
- Build any C++ code
- Import `creature_loot_template` (we lead with raidbots data)
- Import SmartAI source_type 5 (LW custom scene extension)
- Import entries >= 9,100,000 (LW custom housing range)
- Use DELETE statements

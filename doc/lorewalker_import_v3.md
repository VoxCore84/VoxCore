# LoreWalker TDB Import — v3 (QA-Verified, Pre-Baked)

> Paste this entire prompt into a Claude Code tab opened in `C:\Users\atayl\VoxCore\`.
> Write all 7 SQL files using the Write tool. ALL SQL is provided verbatim — write it to disk exactly as shown.

## Task

Write 7 SQL files to `sql/updates/world/master/`. The complete SQL for each file is below.

## Setup

1. Run `ls sql/updates/world/master/2026_03_08_*` to find taken sequence numbers
2. Use next 7 consecutive numbers (likely 01-07)
3. Write each file using the Write tool (all 7 can be written in parallel — no dependencies between file creation)
4. Report: list all 7 filenames with full paths

## Rules

- **Do NOT run DESCRIBE** — all schemas are verified and baked in
- **Do NOT apply the SQL** — only write the files to disk
- **Do NOT modify the SQL** — write verbatim as shown
- **Do NOT build C++ code**

## Verified Row Counts (live queries, 2026-03-08)

| File | Description | Rows |
|------|-------------|------|
| 1 | Phases | 1,279 |
| 2 | Templates | 33,978 |
| 3 | Quests | 99,426 |
| 4 | Spawns | ~119,472 (post-import) |
| 5 | Behavioral | 177,712 |
| 6 | Loot | 62,260 |
| 7 | Backfill | 7,678 updates |
| **Total** | | **~501,805 inserts + 7,678 updates** |

---

## FILE 1 — Phases

```sql
-- LoreWalker TDB Import — File 1: Phases
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- phase_area: 662 rows | phase_name: 617 rows
-- Total: 1,279 rows

-- phase_area (PK: AreaId, PhaseId — no VerifiedBuild)
INSERT IGNORE INTO world.phase_area
SELECT * FROM lorewalker_world.phase_area;

-- phase_name (PK: ID — no VerifiedBuild)
INSERT IGNORE INTO world.phase_name
SELECT * FROM lorewalker_world.phase_name;
```

---

## FILE 2 — Templates

```sql
-- LoreWalker TDB Import — File 2: Templates
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- creature_template: 10 | creature_template_difficulty: 26,086
-- creature_template_model: 3,428 | creature_template_addon: 122
-- creature_template_spell: 163 | creature_equip_template: 2,023
-- gameobject_template: 2,089 | gameobject_template_addon: 57
-- Total: 33,978 rows

SET autocommit=0;

-- creature_template (PK: entry | identical schema | VB → 0)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.creature_template l
WHERE l.entry < 9100000
  AND NOT EXISTS (SELECT 1 FROM world.creature_template w WHERE w.entry = l.entry);
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.creature_template SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- creature_template_difficulty (PK: Entry,DifficultyID | VB → 0 | ALL missing rows, not just new templates)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.creature_template_difficulty l
WHERE l.Entry < 9100000
  AND NOT EXISTS (SELECT 1 FROM world.creature_template_difficulty w
                  WHERE w.Entry = l.Entry AND w.DifficultyID = l.DifficultyID);
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.creature_template_difficulty SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- creature_template_model (PK: CreatureID,Idx | 6 cols | VB → 0)
INSERT IGNORE INTO world.creature_template_model
  (CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability, VerifiedBuild)
SELECT l.CreatureID, l.Idx, l.CreatureDisplayID, l.DisplayScale, l.Probability, 0
FROM lorewalker_world.creature_template_model l
WHERE l.CreatureID < 9100000;

-- creature_template_addon (PK: entry | no VB | identical schema)
INSERT IGNORE INTO world.creature_template_addon
SELECT * FROM lorewalker_world.creature_template_addon
WHERE entry < 9100000;

-- creature_template_spell (PK: CreatureID,`Index` | 4 cols | VB → 0)
INSERT IGNORE INTO world.creature_template_spell
  (CreatureID, `Index`, Spell, VerifiedBuild)
SELECT l.CreatureID, l.`Index`, l.Spell, 0
FROM lorewalker_world.creature_template_spell l
WHERE l.CreatureID < 9100000;

-- creature_equip_template (PK: CreatureID,ID | 12 cols | VB → 0)
INSERT IGNORE INTO world.creature_equip_template
  (CreatureID, ID, ItemID1, AppearanceModID1, ItemVisual1,
   ItemID2, AppearanceModID2, ItemVisual2,
   ItemID3, AppearanceModID3, ItemVisual3, VerifiedBuild)
SELECT l.CreatureID, l.ID, l.ItemID1, l.AppearanceModID1, l.ItemVisual1,
       l.ItemID2, l.AppearanceModID2, l.ItemVisual2,
       l.ItemID3, l.AppearanceModID3, l.ItemVisual3, 0
FROM lorewalker_world.creature_equip_template l
WHERE l.CreatureID < 9100000;

-- gameobject_template (PK: entry | identical schema | VB → 0)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.gameobject_template l
WHERE l.entry < 9100000
  AND NOT EXISTS (SELECT 1 FROM world.gameobject_template w WHERE w.entry = l.entry);
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.gameobject_template SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- gameobject_template_addon (PK: entry | no VB | identical schema)
INSERT IGNORE INTO world.gameobject_template_addon
SELECT * FROM lorewalker_world.gameobject_template_addon
WHERE entry < 9100000;

COMMIT;
```

---

## FILE 3 — Quests

```sql
-- LoreWalker TDB Import — File 3: Quests
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- quest_template: 198 | quest_template_addon: 57,611 | quest_objectives: 888
-- quest_details: 962 | quest_offer_reward: 551 | quest_request_items: 1,894
-- quest_poi: 10,424 | quest_poi_points: 23,476 | quest_visual_effect: 545
-- creature_queststarter: 894 | creature_questender: 719
-- gameobject_queststarter: 256 | gameobject_questender: 264
-- creature_questitem: 232 | gameobject_questitem: 512
-- Total: 99,426 rows

SET autocommit=0;

-- quest_template (PK: ID | 105 cols | VB → 0)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.quest_template l
WHERE l.ID < 9100000
  AND NOT EXISTS (SELECT 1 FROM world.quest_template w WHERE w.ID = l.ID);
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.quest_template SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- quest_template_addon (PK: ID | no VB | identical schema | ALL missing quests)
INSERT IGNORE INTO world.quest_template_addon
SELECT * FROM lorewalker_world.quest_template_addon
WHERE ID < 9100000;

-- quest_objectives (PK: ID | 15 cols | VB → 0)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.quest_objectives l
WHERE l.QuestID < 9100000
  AND NOT EXISTS (SELECT 1 FROM world.quest_objectives w WHERE w.ID = l.ID);
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.quest_objectives SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- quest_details (PK: ID | 10 cols | VB → 0)
INSERT IGNORE INTO world.quest_details
  (ID, Emote1, Emote2, Emote3, Emote4,
   EmoteDelay1, EmoteDelay2, EmoteDelay3, EmoteDelay4, VerifiedBuild)
SELECT l.ID, l.Emote1, l.Emote2, l.Emote3, l.Emote4,
       l.EmoteDelay1, l.EmoteDelay2, l.EmoteDelay3, l.EmoteDelay4, 0
FROM lorewalker_world.quest_details l
WHERE l.ID < 9100000;

-- quest_offer_reward (PK: ID | 11 cols | VB → 0)
INSERT IGNORE INTO world.quest_offer_reward
  (ID, Emote1, Emote2, Emote3, Emote4,
   EmoteDelay1, EmoteDelay2, EmoteDelay3, EmoteDelay4, RewardText, VerifiedBuild)
SELECT l.ID, l.Emote1, l.Emote2, l.Emote3, l.Emote4,
       l.EmoteDelay1, l.EmoteDelay2, l.EmoteDelay3, l.EmoteDelay4, l.RewardText, 0
FROM lorewalker_world.quest_offer_reward l
WHERE l.ID < 9100000;

-- quest_request_items (PK: ID | 7 cols | VB → 0)
INSERT IGNORE INTO world.quest_request_items
  (ID, EmoteOnComplete, EmoteOnIncomplete,
   EmoteOnCompleteDelay, EmoteOnIncompleteDelay, CompletionText, VerifiedBuild)
SELECT l.ID, l.EmoteOnComplete, l.EmoteOnIncomplete,
       l.EmoteOnCompleteDelay, l.EmoteOnIncompleteDelay, l.CompletionText, 0
FROM lorewalker_world.quest_request_items l
WHERE l.ID < 9100000;

-- quest_poi (PK: QuestID,BlobIndex,Idx1 | 16 cols | VB → 0)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.quest_poi l
WHERE l.QuestID < 9100000
  AND NOT EXISTS (SELECT 1 FROM world.quest_poi w
                  WHERE w.QuestID = l.QuestID AND w.BlobIndex = l.BlobIndex AND w.Idx1 = l.Idx1);
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.quest_poi SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- quest_poi_points (PK: QuestID,Idx1,Idx2 | 7 cols | VB → 0)
INSERT IGNORE INTO world.quest_poi_points
  (QuestID, Idx1, Idx2, X, Y, Z, VerifiedBuild)
SELECT l.QuestID, l.Idx1, l.Idx2, l.X, l.Y, l.Z, 0
FROM lorewalker_world.quest_poi_points l
WHERE l.QuestID < 9100000;

-- quest_visual_effect (PK: ID,`Index` | 4 cols | VB → 0)
INSERT IGNORE INTO world.quest_visual_effect
  (ID, `Index`, VisualEffect, VerifiedBuild)
SELECT l.ID, l.`Index`, l.VisualEffect, 0
FROM lorewalker_world.quest_visual_effect l;

-- creature_queststarter (PK: id,quest,VerifiedBuild — VB IS IN PK!)
-- Must dedup on business key (id,quest) only. DISTINCT avoids sending 339 duplicate pairs.
INSERT IGNORE INTO world.creature_queststarter (id, quest, VerifiedBuild)
SELECT DISTINCT l.id, l.quest, 0
FROM lorewalker_world.creature_queststarter l
WHERE NOT EXISTS (
  SELECT 1 FROM world.creature_queststarter w
  WHERE w.id = l.id AND w.quest = l.quest
);

-- creature_questender (PK: id,quest,VerifiedBuild — VB IN PK)
INSERT IGNORE INTO world.creature_questender (id, quest, VerifiedBuild)
SELECT DISTINCT l.id, l.quest, 0
FROM lorewalker_world.creature_questender l
WHERE NOT EXISTS (
  SELECT 1 FROM world.creature_questender w
  WHERE w.id = l.id AND w.quest = l.quest
);

-- gameobject_queststarter (PK: id,quest,VerifiedBuild — VB IN PK)
INSERT IGNORE INTO world.gameobject_queststarter (id, quest, VerifiedBuild)
SELECT DISTINCT l.id, l.quest, 0
FROM lorewalker_world.gameobject_queststarter l
WHERE NOT EXISTS (
  SELECT 1 FROM world.gameobject_queststarter w
  WHERE w.id = l.id AND w.quest = l.quest
);

-- gameobject_questender (PK: id,quest,VerifiedBuild — VB IN PK)
INSERT IGNORE INTO world.gameobject_questender (id, quest, VerifiedBuild)
SELECT DISTINCT l.id, l.quest, 0
FROM lorewalker_world.gameobject_questender l
WHERE NOT EXISTS (
  SELECT 1 FROM world.gameobject_questender w
  WHERE w.id = l.id AND w.quest = l.quest
);

-- creature_questitem (PK: CreatureEntry,DifficultyID,Idx | 5 cols | VB → 0)
INSERT IGNORE INTO world.creature_questitem
  (CreatureEntry, DifficultyID, Idx, ItemId, VerifiedBuild)
SELECT l.CreatureEntry, l.DifficultyID, l.Idx, l.ItemId, 0
FROM lorewalker_world.creature_questitem l
WHERE l.CreatureEntry < 9100000;

-- gameobject_questitem (PK: GameObjectEntry,Idx | 4 cols | VB → 0)
INSERT IGNORE INTO world.gameobject_questitem
  (GameObjectEntry, Idx, ItemId, VerifiedBuild)
SELECT l.GameObjectEntry, l.Idx, l.ItemId, 0
FROM lorewalker_world.gameobject_questitem l
WHERE l.GameObjectEntry < 9100000;

COMMIT;
```

---

## FILE 4 — Spawns

**NOTE**: Spawn-dependent tables (creature_addon, creature_formations, game_event_*) run AFTER the creature/gameobject INSERTs. MySQL InnoDB sees its own uncommitted writes within the same transaction, so the EXISTS checks correctly find newly imported spawns. Post-import row counts are higher than pre-import counts.

```sql
-- LoreWalker TDB Import — File 4: Spawns
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- creature: 101,018 | gameobject: 1,290 | creature_addon: ~16,609 (post-import)
-- gameobject_addon: ~3 | spawn_group: 10,145 | pool_template: 1,886
-- pool_members: 240 | creature_formations: ~1,243 (post-import)
-- game_event_creature: ~257 (post-import) | game_event_gameobject: ~17 (post-import)
-- Total: ~119,472 rows (post-import estimates)

SET autocommit=0;

-- creature (PK: guid)
-- SCHEMA DIFF: world.creature has extra column 'size' (default -1) — excluded
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
  AND EXISTS (SELECT 1 FROM world.creature_template ct WHERE ct.entry = l.id)
  AND NOT EXISTS (SELECT 1 FROM world.creature w WHERE w.guid = l.guid);

-- gameobject (PK: guid)
-- SCHEMA DIFF: world.gameobject has extra columns 'size' (default -1), 'visibility' (default 256)
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
  AND EXISTS (SELECT 1 FROM world.gameobject_template gt WHERE gt.entry = l.id)
  AND NOT EXISTS (SELECT 1 FROM world.gameobject w WHERE w.guid = l.guid);

-- creature_addon (PK: guid | no VB | identical schema)
-- Runs AFTER creature INSERT — EXISTS picks up newly imported creatures
INSERT IGNORE INTO world.creature_addon
SELECT l.* FROM lorewalker_world.creature_addon l
WHERE EXISTS (SELECT 1 FROM world.creature w WHERE w.guid = l.guid);

-- gameobject_addon (PK: guid | no VB | identical schema)
INSERT IGNORE INTO world.gameobject_addon
SELECT l.* FROM lorewalker_world.gameobject_addon l
WHERE EXISTS (SELECT 1 FROM world.gameobject w WHERE w.guid = l.guid);

-- spawn_group (PK: groupId,spawnType,spawnId | no VB | identical schema)
INSERT IGNORE INTO world.spawn_group
SELECT * FROM lorewalker_world.spawn_group;

-- pool_template (PK: entry | no VB | identical schema)
INSERT IGNORE INTO world.pool_template
SELECT * FROM lorewalker_world.pool_template;

-- pool_members (PK: type,spawnId | no VB | identical schema)
INSERT IGNORE INTO world.pool_members
SELECT * FROM lorewalker_world.pool_members;

-- creature_formations (PK: memberGUID | no VB | identical schema)
-- Only import where the member creature exists (including newly imported)
INSERT IGNORE INTO world.creature_formations
SELECT l.* FROM lorewalker_world.creature_formations l
WHERE EXISTS (SELECT 1 FROM world.creature w WHERE w.guid = l.memberGUID);

-- game_event_creature (PK: guid,eventEntry | no VB | identical schema)
INSERT IGNORE INTO world.game_event_creature
SELECT l.* FROM lorewalker_world.game_event_creature l
WHERE EXISTS (SELECT 1 FROM world.creature w WHERE w.guid = l.guid);

-- game_event_gameobject (PK: guid,eventEntry | no VB | identical schema)
INSERT IGNORE INTO world.game_event_gameobject
SELECT l.* FROM lorewalker_world.game_event_gameobject l
WHERE l.guid < 1913720832000
  AND EXISTS (SELECT 1 FROM world.gameobject w WHERE w.guid = l.guid);

COMMIT;
```

---

## FILE 5 — Behavioral

**NOTE**: waypoint_path_node is inserted BEFORE waypoint_path. This is intentional — the NOT IN check identifies paths that don't yet exist in our DB. Inserting paths first would cause the check to miss newly added paths. There are no FK constraints between these tables.

```sql
-- LoreWalker TDB Import — File 5: Behavioral
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- smart_scripts: 171,162 | waypoint_path: 61 | waypoint_path_node: 87
-- npc_vendor: 3,910 | gossip_menu: 399 | gossip_menu_option: 279
-- npc_text: 343 | creature_text: 232 | scene_template: 195 | conditions: 1,044
-- Total: 177,712 rows

SET autocommit=0;

-- smart_scripts (PK: entryorguid,source_type,id,link | no VB | identical schema)
-- source_type filter: 0=creature, 1=gameobject, 2=areatrigger, 9=timed actionlist, 12=spell
-- Excludes: type 5 (LW custom scene extension, 526K rows)
INSERT IGNORE INTO world.smart_scripts
SELECT * FROM lorewalker_world.smart_scripts l
WHERE l.source_type IN (0, 1, 2, 9, 12)
  AND l.entryorguid < 9100000
  AND l.entryorguid > -9100000
  AND NOT EXISTS (SELECT 1 FROM world.smart_scripts w
    WHERE w.entryorguid = l.entryorguid AND w.source_type = l.source_type
    AND w.id = l.id AND w.link = l.link);

-- waypoint_path_node (PK: PathId,NodeId | no VB | identical schema)
-- MUST run BEFORE waypoint_path INSERT so NOT IN correctly identifies new paths
INSERT IGNORE INTO world.waypoint_path_node
SELECT * FROM lorewalker_world.waypoint_path_node l
WHERE l.PathId NOT IN (SELECT PathId FROM world.waypoint_path);

-- waypoint_path (PK: PathId | no VB | identical schema — includes Velocity column)
INSERT IGNORE INTO world.waypoint_path
SELECT * FROM lorewalker_world.waypoint_path;

-- npc_vendor (PK: entry,item,ExtendedCost,type | 11 cols | VB → 0)
-- SCHEMA DIFF: world has extra 'OverrideGoldCost' column (default -1) — excluded
INSERT IGNORE INTO world.npc_vendor
  (entry, slot, item, maxcount, incrtime, ExtendedCost, type,
   BonusListIDs, PlayerConditionID, IgnoreFiltering, VerifiedBuild)
SELECT l.entry, l.slot, l.item, l.maxcount, l.incrtime, l.ExtendedCost, l.type,
       l.BonusListIDs, l.PlayerConditionID, l.IgnoreFiltering, 0
FROM lorewalker_world.npc_vendor l
WHERE l.entry < 9100000;

-- gossip_menu (PK: MenuID,TextID | 3 cols | VB → 0)
INSERT IGNORE INTO world.gossip_menu (MenuID, TextID, VerifiedBuild)
SELECT l.MenuID, l.TextID, 0
FROM lorewalker_world.gossip_menu l;

-- gossip_menu_option (PK: MenuID,OptionID | 18 cols | VB → 0)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.gossip_menu_option l
WHERE NOT EXISTS (SELECT 1 FROM world.gossip_menu_option w
                  WHERE w.MenuID = l.MenuID AND w.OptionID = l.OptionID);
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.gossip_menu_option SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- npc_text (PK: ID | 18 cols | VB → 0)
DROP TEMPORARY TABLE IF EXISTS _imp;
CREATE TEMPORARY TABLE _imp AS
SELECT * FROM lorewalker_world.npc_text l
WHERE NOT EXISTS (SELECT 1 FROM world.npc_text w WHERE w.ID = l.ID);
UPDATE _imp SET VerifiedBuild = 0;
INSERT IGNORE INTO world.npc_text SELECT * FROM _imp;
DROP TEMPORARY TABLE IF EXISTS _imp;

-- creature_text (PK: CreatureID,GroupID,ID | no VB | identical schema)
INSERT IGNORE INTO world.creature_text
SELECT * FROM lorewalker_world.creature_text
WHERE CreatureID < 9100000;

-- scene_template (PK: SceneId | no VB)
-- SCHEMA DIFF: LW has extra 'RTComment' column — explicit column list excludes it
INSERT IGNORE INTO world.scene_template (SceneId, Flags, ScriptPackageID, Encrypted, ScriptName)
SELECT l.SceneId, l.Flags, l.ScriptPackageID, l.Encrypted, l.ScriptName
FROM lorewalker_world.scene_template l;

-- conditions (PK: 11-column composite | no VB | identical schema)
INSERT IGNORE INTO world.conditions
SELECT l.* FROM lorewalker_world.conditions l
WHERE NOT EXISTS (SELECT 1 FROM world.conditions w
  WHERE w.SourceTypeOrReferenceId = l.SourceTypeOrReferenceId
    AND w.SourceGroup = l.SourceGroup AND w.SourceEntry = l.SourceEntry
    AND w.SourceId = l.SourceId AND w.ElseGroup = l.ElseGroup
    AND w.ConditionTypeOrReference = l.ConditionTypeOrReference
    AND w.ConditionTarget = l.ConditionTarget
    AND w.ConditionValue1 = l.ConditionValue1
    AND w.ConditionValue2 = l.ConditionValue2
    AND w.ConditionValue3 = l.ConditionValue3);

COMMIT;
```

---

## FILE 6 — Loot Tables

**CRITICAL**: All `*_loot_template` tables have **NO primary key or unique index**. INSERT IGNORE cannot dedup — it would blindly insert all rows on re-run. Uses `WHERE NOT EXISTS` matching on `(Entry, ItemType, Item)` for idempotency. The column is **`ItemType`**, NOT `Reference`.

`creature_loot_template` is intentionally excluded — we lead with raidbots data (50K+ custom rows).

```sql
-- LoreWalker TDB Import — File 6: Loot Tables
-- Source: lorewalker_world (build 66102) → Target: world (build 66263)
-- reference_loot_template: 51 | gameobject_loot_template: 60,244
-- pickpocketing_loot_template: 1,389 | skinning_loot_template: 402
-- item_loot_template: 110 | spell_loot_template: 64
-- Total: 62,260 rows
-- NOTE: creature_loot_template intentionally excluded (we lead with raidbots data)

SET autocommit=0;

-- reference_loot_template (MUST come first — referenced by other loot tables)
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
-- Rows affected: 7,678

UPDATE world.creature_template_difficulty w
JOIN lorewalker_world.creature_template_difficulty l
  ON w.Entry = l.Entry AND w.DifficultyID = l.DifficultyID
SET w.ContentTuningID = l.ContentTuningID
WHERE w.ContentTuningID = 0 AND l.ContentTuningID != 0;
```

---

## Apply Order (for the user, AFTER reviewing generated files)

```
1 → 2 → 3 → 4 → 5 → 6 → 7
```

Apply with: `"C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -padmin world < filename.sql`

Check `DBErrors.log` after each file. Restart worldserver after all files are applied.

## DO NOT

- Run any DESCRIBE commands
- Apply the SQL files
- Build any C++ code
- Import `creature_loot_template` (we lead with raidbots data)
- Import SmartAI source_type 5 (LW custom scene extension)
- Import entries >= 9,100,000 (LW custom housing range)
- Use DELETE statements
- Modify the SQL in any way

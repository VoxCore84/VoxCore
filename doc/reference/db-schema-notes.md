# World DB Schema Notes (12.x / Midnight)

These are actual verified column/table names. **Always check these before writing SQL.**

## Tables That DON'T Exist in `world` (common mistakes)
- `item_template` — items are in `hotfixes.item` (column: `ID`)
- `broadcast_text` — lives in `hotfixes.broadcast_text` (column: `ID`)
- `pool_creature` / `pool_gameobject` / `pool_pool` — replaced by unified `pool_members`
- `spawn_group_member` — the table is just `spawn_group`

## Cross-DB References
- Items: `hotfixes.item.ID`
- Broadcast text: `hotfixes.broadcast_text.ID`
- When writing world DB SQL that needs item/broadcast lookups, use `hotfixes.<table>`

## Pool System
- `pool_template`: `entry`, `max_limit`, `description`
- `pool_members`: `type` (0=creature, 1=gameobject), `spawnId`, `poolSpawnId`, `chance`, `description`
- `poolSpawnId` references `pool_template.entry`

## Spawn Groups
- `spawn_group`: `groupId`, `spawnType` (0=creature, 1=gameobject), `spawnId`
- `spawn_group_template`: `groupId`, `groupName`, `groupFlags`

## Gameobject Table
- PK: `guid` (bigint unsigned)
- Lowercase columns: `id`, `map`, `spawnDifficulties` (varchar), `phaseGroup`, `terrainSwapMap`, `state`, `spawntimesecs`, `orientation`
- Rotation: `rotation0`-`rotation3` (float)
- Phase: `PhaseId` (capital P), `PhaseGroup` (but column is actually lowercase `phaseGroup`... MySQL is case-insensitive on Windows)

## Gameobject Template
- PK: `entry`
- `type` (tinyint), `displayId`, `name`, `size`
- Data fields: `Data0` through `Data34` (capital D — but case-insensitive on Windows)
- **Type 22 (SPELLCASTER)**: `Data0` = spell ID cast on player click. Must be a direct-effect spell (Effect 252 TELEPORT_WITH_VISUAL_LOADING_SCREEN for portals). Do NOT use Mage portal spells (Effect 50 TRANS_DOOR — those summon a GO, not teleport directly)

## Spell Target Position
- `spell_target_position`: `ID` (spell ID), `EffectIndex`, `OrderIndex`, `MapID`, `PositionX/Y/Z`, `Orientation`, `VerifiedBuild`
- Used when spell has ImplicitTarget2=17 (TARGET_DEST_DB)

## Creature Text
- `creature_text`: `CreatureID`, `GroupID`, `ID`, `Text`, **`Type`** (NOT TextType), `Language`, `Probability`, `Emote`, `Duration`, `Sound`, **`SoundPlayType`** (NOT PlayType), `BroadcastTextId`, `TextRange`

## Areatrigger
- `areatrigger`: PK is **`SpawnId`** (NOT guid), `AreaTriggerCreatePropertiesId`, `IsCustom`, `MapId`, **`SpawnDifficulties`** (capital S), `PosX/Y/Z`, `Orientation`, `PhaseUseFlags`, `PhaseId`, `PhaseGroup`
- `areatrigger_create_properties`: PK is (`Id`, `IsCustom`), has `Flags`, `Shape`, `ShapeData0-7`, `ScriptName`

## Conversation Actors
- `conversation_actors`: `ConversationId`, `ConversationActorId`, **`ConversationActorGuid`** (bigint — the creature GUID), `Idx`, `CreatureId`, `CreatureDisplayInfoId`, `NoActorObject`, `ActivePlayerObject`
- No `ActorType` or `SpawnId` column

## Gossip
- `gossip_menu`: `MenuID`, `TextID`
- `gossip_menu_option`: `MenuID`, `OptionID`, **`OptionNpc`** (NOT GossipOptionNpc), `ActionMenuID`, `Language`, `Flags`, `GossipNpcOptionID`

## NPC Vendor
- `npc_vendor`: `entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`, `type` (1=item), `BonusListIDs`, `PlayerConditionID`

## Conditions
- `conditions`: `SourceTypeOrReferenceId`, `SourceGroup`, `SourceEntry`, `SourceId`, `ElseGroup`, `ConditionTypeOrReference`, `ConditionTarget`, `ConditionValue1-3`, `ConditionStringValue1`, `ScriptName`
- Phase conditions: `SourceTypeOrReferenceId = 26`, `SourceGroup = PhaseId`, `SourceEntry = AreaId`

## Trainer
- `trainer_spell`: `TrainerId`, `SpellId`, `MoneyCost`, `ReqSkillLine`, `ReqSkillRank`, `ReqAbility1-3`, `ReqLevel`

## Spell Proc
- `spell_proc`: `SpellId`, `SchoolMask`, `SpellFamilyName`, `SpellFamilyMask0-3`, `ProcFlags`, `ProcFlags2`, `SpellTypeMask`, `SpellPhaseMask`, `HitMask`, `AttributesMask`, `DisableEffectsMask`, `ProcsPerMinute`, `Chance`, `Cooldown`, `Charges`

## Other Tables
- `phase_area`: `AreaId`, `PhaseId`
- `npc_text`: `ID`, `Probability0-7`, `BroadcastTextID0-7`
- `vehicle_template_accessory`: `entry`, ...
- `ui_map_quest_line`: `QuestLineId`, ...
- `spawn_tracking_quest_objective`: `QuestObjectiveId`, ...
- `skill_discovery_template`: `spellId`, ...
- `lfg_dungeon_template`: `dungeonId`, ...

## ContentTuning System (12.x Levels)
- `creature_template_difficulty`: `Entry`, `ContentTuningID`, `DifficultyID` (0=open world), `LootID`, etc.
- `hotfixes.content_tuning`: `ID`, `MinLevel`, `MaxLevel`, `MaxLevelType`, `Flags`
- MaxLevelType=2 = expansion cap (90 for Midnight)
- CT=0 or missing CTD row → creature stuck at level 1
- Key CTs: 864 (1-90), 2 (Classic 5-30), 1227 (BfA 10-60), 2151 (DF 10-70), 2677 (TWW 70-80), 3085 (Midnight 80-83)

## Creature Classification Enum (`SharedDefines.h:5121-5130`)
- 0=Normal, 1=Elite, 2=RareElite, 3=Obsolete, 4=Rare, 5=Trivial, **6=MinusMob** (valid, 6,100 entries)
- Wowhead uses different mapping: 0=Normal, 1=Elite, 2=Rare, 3=RareElite, 4=Boss

## Waypoint System
- `waypoint_path`: `PathId`, `MoveType`, `Flags`
- `waypoint_path_node`: `PathId`, `NodeId`, `PositionX/Y/Z`, `Orientation`, `Delay`
- Linked via `creature_addon.PathId` or `creature_template_addon.PathId`
- No `waypoint_data` table in modern TC

## Creature Spawn Table
- `creature`: PK `guid`, creature entry is column `id` (NOT `id1` — varies by TC branch)
- `modelid`: per-spawn display override. 0 = use template default

## Process Lesson
**Always DESCRIBE tables before writing SQL.** Run schema checks in parallel with error extraction, not after writing all files. A single round of `DESCRIBE` calls upfront saves an entire rewrite cycle.

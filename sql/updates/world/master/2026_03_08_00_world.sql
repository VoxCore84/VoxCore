-- 2026_03_08_00_world.sql
-- Draconic diff: missing phase_area + spawns for Stormwind City
-- Source: Draconic-WOW build 66263, cross-referenced via diff_draconic.py
-- QA: 3 passes — coordinate bounds, data quality, SQL validation

SET innodb_lock_wait_timeout = 120;

-- ============================================================================
-- SECTION 1: Missing phase_area entries (7 rows)
-- Without these, phases 45499-45562 never activate in Stormwind,
-- making phased NPCs (Genn, Velen, Anduin, embassy leaders) invisible.
-- ============================================================================

INSERT IGNORE INTO `phase_area` (`AreaId`, `PhaseId`, `Comment`) VALUES
(1519, 10061, 'Deprecated - See Alleria Windrunner in Stormwind Embassy'),
(1519, 27073, 'See Magister Umbric at The Old Town in Stormwind'),
(1519, 45499, 'Genn and Velen in Stormwind'),
(1519, 45500, 'Anduin at Cathedral'),
(1519, 45501, 'Anduin at Lion\'s Rest'),
(1519, 45502, 'Anduin at Stormwind Keep'),
(1519, 45562, 'Midnight: Intro Spawns');


-- ============================================================================
-- SECTION 2: Missing gameobject_template entries (7 rows)
-- Midnight-era decorations in Stormwind Old Town area
-- ============================================================================

INSERT IGNORE INTO `gameobject_template` (`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,`Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,`Data10`,`Data11`,`Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,`Data20`,`Data21`,`Data22`,`Data23`,`Data24`,`Data25`,`Data26`,`Data27`,`Data28`,`Data29`,`Data30`,`Data31`,`Data32`,`Data33`,`Data34`,`ContentTuningId`,`RequiredLevel`,`AIName`,`ScriptName`,`VerifiedBuild`) VALUES
(576391, 5, 40800, 'Bookshelf', '', '', '', 0.75, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, '', '', 0),
(576392, 5, 91439, 'Keg', '', '', '', 0.25, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, '', '', 0),
(576393, 5, 113681, 'Coil', '', '', '', 0.2, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, '', '', 0),
(576394, 5, 37499, 'Table', '', '', '', 0.65, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, '', '', 0),
(576395, 5, 77516, 'Chandelier', '', '', '', 0.2, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, '', '', 0),
(576396, 5, 113690, 'Furniture Cart', '', '', '', 1, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, '', '', 0),
(576463, 5, 12157, 'Fishing Pole', '', '', '', 1, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, '', '', 0);


-- ============================================================================
-- SECTION 3: Missing gameobject spawns (10 rows)
-- GUID range: 70000000326 - 70000000335
-- ============================================================================

-- Hero's Call Board (Old Town, zoneId=0 — server computes at runtime)
INSERT IGNORE INTO `gameobject` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`,`visibility`)
VALUES (70000000326, 206111, 0, 0, 0, '0', 0, 0, 0, -1, -8817.49, 629.623, 94.3614, 4.86191, 0, 0, -0.652318, 0.757946, 300, 255, 1, '', NULL, 0, -1, 256);

-- Portal to Hellfire Peninsula (Mage Tower area)
INSERT IGNORE INTO `gameobject` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`,`visibility`)
VALUES (70000000327, 195141, 0, 0, 0, '0', 0, 0, 0, -1, -9003.66, 855.323, 29.6207, 0.741286, 0, 0, 0.362215, 0.932095, 120, 255, 1, '', NULL, 0, -1, 256);

-- Portal to Valdrakken (Portal Room)
INSERT IGNORE INTO `gameobject` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`,`visibility`)
VALUES (70000000328, 383582, 0, 1519, 10523, '0', 0, 0, 0, -1, -9077.98, 873.447, 68.3226, 5.36689, 0, 0, -0.442288, 0.896873, 120, 255, 1, '', NULL, 0, -1, 256);

-- Midnight decorations in Old Town (areaId 5390): Fishing Pole, Bookshelf, Keg, Coil, Table, Chandelier, Furniture Cart
INSERT IGNORE INTO `gameobject` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`position_x`,`position_y`,`position_z`,`orientation`,`rotation0`,`rotation1`,`rotation2`,`rotation3`,`spawntimesecs`,`animprogress`,`state`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`,`visibility`)
VALUES
(70000000329, 576463, 0, 1519, 5390, '0', 0, 0, 0, -1, -8890.48, 744.894, 97.3371, 5.87291, -0.0928388, -0.472001, -0.175762, 0.858897, 120, 255, 1, '', NULL, 0, -1, 256),
(70000000330, 576391, 0, 1519, 5390, '0', 0, 0, 0, -1, -8886.07, 749.814, 96.2677, 5.11743, 0, 0, -0.550427, 0.834883, 120, 255, 1, '', NULL, 0, -1, 256),
(70000000331, 576392, 0, 1519, 5390, '0', 0, 0, 0, -1, -8890.52, 745.071, 97.1509, 1.53784, 0, 0, 0.695358, 0.718663, 120, 255, 1, '', NULL, 0, -1, 256),
(70000000332, 576393, 0, 1519, 5390, '0', 0, 0, 0, -1, -8885.95, 749.988, 97.4219, 1.53784, 0, 0, 0.695358, 0.718663, 120, 255, 1, '', NULL, 0, -1, 256),
(70000000333, 576394, 0, 1519, 5390, '0', 0, 0, 0, -1, -8887.59, 747.208, 96.3316, 5.47394, 0, 0, -0.393674, 0.91925, 120, 255, 1, '', NULL, 0, -1, 256),
(70000000334, 576395, 0, 1519, 5390, '0', 0, 0, 0, -1, -8889.21, 744.366, 97.0982, 1.53784, 0, 0, 0.695358, 0.718663, 120, 255, 1, '', NULL, 0, -1, 256),
(70000000335, 576396, 0, 1519, 5390, '0', 0, 0, 0, -1, -8890.52, 745.069, 96.4705, 6.12324, 0, 0, -0.0798864, 0.996804, 120, 255, 1, '', NULL, 0, -1, 256);


-- ============================================================================
-- SECTION 4: Missing creature spawns (15 rows)
-- GUID range: 3100000000 - 3100000014
-- ============================================================================

-- Larimaine Purdue (Mage Quarter NPC)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000000, 2485, 0, 1519, 5154, '0', 0, 0, 0, -1, 0, 1, -8991.9, 847.481, 29.704, 0.663225, 120, 0, 0, 100, 0, NULL, NULL, NULL, NULL, '', NULL, 0, -1);

-- Stormwind City Guard (Mage Tower patrol)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000001, 68, 0, 1519, 5154, '0', 0, 0, 0, -1, 0, 1, -9013.41, 869.081, 148.405, 5.30856, 120, 0, 0, 100, 2, NULL, NULL, NULL, NULL, '', NULL, 0, -1);

-- Second Chair Pawdo (Old Town tavern NPC)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000002, 252312, 0, 1519, 5390, '0', 0, 0, 0, -1, 0, 0, -8888.88, 748.491, 96.4219, 5.52866, 120, 0, 0, 100, 0, NULL, NULL, NULL, NULL, '', NULL, 0, -1);

-- Genn Greymane (PhaseId 45499 — phased version in Keep)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000003, 119338, 0, 0, 0, '0', 0, 45499, 0, -1, 0, 0, -8361.68, 237.258, 156.474, 4.5306, 300, 0, 0, 100, 0, NULL, 32768, NULL, NULL, '', NULL, 0, -1);

-- Prophet Velen (PhaseId 45499 — phased version in Keep)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000004, 119340, 0, 0, 0, '0', 0, 45499, 0, -1, 0, 0, -8367.95, 232.432, 156.502, 6.19407, 300, 0, 0, 100, 0, NULL, 32768, NULL, NULL, '', NULL, 0, -1);

-- Anduin Wrynn (PhaseId 45500 — at Cathedral)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000005, 119357, 0, 0, 0, '0', 0, 45500, 0, -1, 0, 0, -8516.73, 858.913, 109.845, 0.670391, 300, 0, 0, 100, 0, NULL, 32768, NULL, NULL, '', NULL, 0, -1);

-- Anduin Wrynn (PhaseId 45501 — at Lion's Rest / Harbor)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000006, 120268, 0, 0, 0, '0', 0, 45501, 0, -1, 0, 0, -8736.64, 1026.01, 79.4998, 1.56544, 300, 0, 0, 100, 0, NULL, 32768, NULL, NULL, '', NULL, 0, -1);

-- Prophet Velen (PhaseId 45502 — ceremony in Keep)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000007, 119340, 0, 0, 0, '0', 0, 45502, 0, -1, 0, 1, -8411.8, 218.563, 155.348, 4.03881, 300, 0, 0, 100, 0, NULL, 33280, NULL, NULL, '', NULL, 0, -1);

-- Genn Greymane (PhaseId 45502 — ceremony in Keep)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000008, 119338, 0, 0, 0, '0', 0, 45502, 0, -1, 0, 0, -8409.86, 216.766, 155.348, 3.82879, 300, 0, 0, 100, 0, NULL, 32768, NULL, NULL, '', NULL, 0, -1);

-- Anduin Wrynn (PhaseId 45502 — ceremony in Keep)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000009, 120268, 0, 0, 0, '0', 0, 45502, 0, -1, 0, 0, -8392.91, 227.265, 155.348, 3.59317, 300, 0, 0, 100, 0, NULL, 32768, NULL, NULL, '', NULL, 0, -1);

-- Image of Lady Liadrin (PhaseId 45562 — Midnight intro, embassy area)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000010, 241677, 0, 0, 0, '0', 0, 45562, 0, -1, 0, 0, -8626.75, 799.421, 97.1379, 3.78467, 300, 0, 0, 100, 0, NULL, NULL, NULL, NULL, '', NULL, 0, -1);

-- Lor'themar Theron (PhaseId 45562 — Midnight intro, embassy area)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000011, 249139, 0, 0, 0, '0', 0, 45562, 0, -1, 0, 0, -8624.15, 799.128, 97.1944, 3.773, 300, 0, 0, 100, 0, NULL, NULL, NULL, NULL, '', NULL, 0, -1);

-- High Exarch Turalyon (PhaseId 45562 — Midnight intro, embassy area)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES (3100000012, 245588, 0, 0, 0, '0', 0, 45562, 0, -1, 0, 0, -8627.49, 801.644, 97.0743, 4.19591, 300, 0, 0, 100, 0, NULL, NULL, NULL, NULL, '', NULL, 0, -1);

-- Silvermoon Mage x2 (Portal Room, unphased)
INSERT IGNORE INTO `creature` (`guid`,`id`,`map`,`zoneId`,`areaId`,`spawnDifficulties`,`phaseUseFlags`,`PhaseId`,`PhaseGroup`,`terrainSwapMap`,`modelid`,`equipment_id`,`position_x`,`position_y`,`position_z`,`orientation`,`spawntimesecs`,`wander_distance`,`currentwaypoint`,`curHealthPct`,`MovementType`,`npcflag`,`unit_flags`,`unit_flags2`,`unit_flags3`,`ScriptName`,`StringId`,`VerifiedBuild`,`size`)
VALUES
(3100000013, 68576, 0, 0, 0, '0', 0, 0, 0, -1, 0, 0, -9094.59, 875.104, 68.1472, 3.12784, 300, 0, 0, 100, 0, NULL, 32768, NULL, NULL, '', NULL, 0, -1),
(3100000014, 68576, 0, 0, 0, '0', 0, 0, 0, -1, 0, 0, -9097.7, 878.492, 68.1411, 4.60046, 300, 0, 0, 100, 0, NULL, 32768, NULL, NULL, '', NULL, 0, -1);


-- ============================================================================
-- SECTION 5: creature_addon for imported spawns (3 rows)
-- ============================================================================

-- Guard patrol path
INSERT IGNORE INTO `creature_addon` (`guid`,`PathId`,`mount`,`MountCreatureID`,`StandState`,`AnimTier`,`VisFlags`,`SheathState`,`PvPFlags`,`emote`,`aiAnimKit`,`movementAnimKit`,`meleeAnimKit`,`visibilityDistanceType`,`auras`)
VALUES (3100000001, 3291961461, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, '');

-- Silvermoon Mage auras (SpellVisualKit 392617)
INSERT IGNORE INTO `creature_addon` (`guid`,`PathId`,`mount`,`MountCreatureID`,`StandState`,`AnimTier`,`VisFlags`,`SheathState`,`PvPFlags`,`emote`,`aiAnimKit`,`movementAnimKit`,`meleeAnimKit`,`visibilityDistanceType`,`auras`)
VALUES
(3100000013, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, '392617'),
(3100000014, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, '392617');


-- ============================================================================
-- Summary:
--   7 phase_area entries INSERTED (enable phases 10061, 27073, 45499-45502, 45562)
--   7 gameobject_template entries INSERTED (Midnight decorations 576391-576396, 576463)
--  10 gameobject spawns INSERTED (GUIDs 70000000326-70000000335)
--  15 creature spawns INSERTED (GUIDs 3100000000-3100000014)
--   3 creature_addon entries INSERTED (patrol + auras)
-- ============================================================================

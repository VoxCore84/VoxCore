-- Fix miscellaneous DB errors from DBErrors.log
-- Categories: creature_model_info, npc_text, graveyard_zone, spell_totem_model,
--             lfg_dungeon_rewards, terrain_swap_defaults, creature_text

-- ============================================================
-- Fix: creature_model_info non-existent DisplayIDs (65 entries)
-- Error: Table creature_model_info has a non-existent DisplayID
-- ============================================================
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (0, 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 27, 43, 61, 66, 67, 255, 356, 395, 526, 579, 962, 993, 1168, 2939, 6162, 7954, 29525, 34276, 38043, 38961, 58640, 66129, 85414, 139384, 147318, 189981, 191143, 191659, 191683, 191686, 191840, 192126, 192809, 193405, 193417, 194336, 194544, 194551, 194744);
DELETE FROM `creature_model_info` WHERE `DisplayID` IN (195386, 198138, 198349, 198847, 198856, 199064, 199795, 199796, 199797, 199798, 200670, 213919, 213920, 1108053, 1121538);

-- ============================================================
-- Fix: NPCText probability set but no BroadcastTextID (103 entries)
-- Error: NPCText has a probability set, but no BroadcastTextID
-- Strategy: Set Probability to 0 where BroadcastTextID is 0 but Probability > 0
-- ============================================================
UPDATE `npc_text` SET `Probability0` = 0 WHERE `ID` IN (2, 2953, 2955, 2956, 2957, 2981, 7114, 7401, 8321, 8332, 9625, 9651, 9701, 9727, 10128, 10884, 11128, 13157, 14330, 15442, 26885, 28670, 30000, 30001, 40478, 40479, 40902, 40906, 40918, 40921, 40922, 40923, 40924, 40927, 40928, 40929, 40930, 41264, 41265, 41518, 41819, 41828, 42409, 60000, 100000, 100002, 100006, 100007, 100008, 300000, 300001, 300002, 600022, 600172, 600173, 600174, 600176, 600177, 610000, 610001, 610002, 610003, 610004, 610005, 688881, 700073, 724001, 724002, 724003, 724004, 724005, 802000, 802001, 900013, 900017, 900033, 900044, 900055, 900071, 900072, 900087) AND `BroadcastTextID0` = 0 AND `Probability0` > 0;
UPDATE `npc_text` SET `Probability1` = 0 WHERE `ID` IN (11428, 41518, 610000, 610001, 91204655, 912046581, 912046582, 912046583, 912046584) AND `BroadcastTextID1` = 0 AND `Probability1` > 0;
UPDATE `npc_text` SET `Probability2` = 0 WHERE `ID` IN (11428, 42410, 610000, 610001) AND `BroadcastTextID2` = 0 AND `Probability2` > 0;
UPDATE `npc_text` SET `Probability3` = 0 WHERE `ID` IN (11428, 610000, 610001) AND `BroadcastTextID3` = 0 AND `Probability3` > 0;
UPDATE `npc_text` SET `Probability4` = 0 WHERE `ID` IN (11428, 610000) AND `BroadcastTextID4` = 0 AND `Probability4` > 0;
UPDATE `npc_text` SET `Probability5` = 0 WHERE `ID` IN (11428, 41520) AND `BroadcastTextID5` = 0 AND `Probability5` > 0;
UPDATE `npc_text` SET `Probability6` = 0 WHERE `ID` IN (11428) AND `BroadcastTextID6` = 0 AND `Probability6` > 0;
UPDATE `npc_text` SET `Probability7` = 0 WHERE `ID` IN (11428) AND `BroadcastTextID7` = 0 AND `Probability7` > 0;

-- Note: NPCText entries with probability sum 0 and no valid BroadcastTextIDs
-- are empty/placeholder entries. The server skips them gracefully.

-- ============================================================
-- Fix: graveyard_zone references non-existing graveyards (19 entries)
-- Error: graveyard_zone has a record for non-existing graveyard
-- ============================================================
DELETE FROM `graveyard_zone` WHERE `ID` IN (529, 549, 669, 670, 671, 931, 932, 996, 997, 1295, 1296, 1297, 1364, 1365, 1366, 2287, 2293, 20047, 200079);

-- ============================================================
-- Fix: spell_totem_model references non-existing spell (1 entry)
-- Error: SpellID in spell_totem_model could not be found in dbc
-- ============================================================
DELETE FROM `spell_totem_model` WHERE `SpellID` IN (157153);

-- ============================================================
-- Fix: lfg_dungeon_rewards references non-existing dungeons (10 entries)
-- Error: Dungeon specified in lfg_dungeon_rewards does not exist
-- ============================================================
DELETE FROM `lfg_dungeon_rewards` WHERE `dungeonId` IN (258, 259, 260, 261, 262, 263, 264, 265, 266, 267);

-- ============================================================
-- Fix: creature_text incompatible BroadcastTextId (1 entry)
-- Error: CreatureTextMgr has non-existing or incompatible BroadcastTextId
-- ============================================================
UPDATE `creature_text` SET `BroadcastTextId` = 0 WHERE `CreatureID` = 246156 AND `GroupID` = 0 AND `ID` = 0 AND `BroadcastTextId` = 296405;

-- ============================================================
-- Fix: terrain_swap_defaults references non-existing TerrainSwapMap (1 entry)
-- Error: TerrainSwapMap defined in terrain_swap_defaults does not exist
-- ============================================================
DELETE FROM `terrain_swap_defaults` WHERE `TerrainSwapMap` IN (1090);

-- Fix remaining quest-related table errors
-- Generated from DBErrors.log analysis

-- Add UNIT_NPC_FLAG_QUESTGIVER (0x02) to creatures referenced in quest starter/ender (169 creatures)
UPDATE `creature_template` SET `npcflag` = `npcflag` | 0x02 WHERE `entry` IN (32974, 114908, 115342, 115499, 115506, 115524, 115798, 116256, 235389, 235405, 235411, 235471, 235486, 235502, 235503, 235504, 235522, 235530, 235532, 235535, 235606, 235633, 235648, 235649, 235652, 235662, 235697, 235713, 235715, 235717, 235724, 235726, 235763, 235765, 235787, 236087, 236099, 236100, 236126, 236132, 236140, 236143, 236147, 236155, 236162, 236363, 236391, 236436, 236468, 236485, 236522, 236540, 236541, 236542, 236559, 236568, 236570, 236572, 236588, 236610, 236611, 236612, 236659, 236692, 236693, 236704, 236716, 236730, 236737, 236739, 236743, 236779, 236896, 236903, 236906, 236944, 236945, 236954, 236961, 236964, 236974, 236978, 237224, 237234, 237236, 237240, 237253, 237268, 237277, 237278, 237284, 237295, 237325, 237332, 237345, 237356, 237361, 237465, 237480, 237483) AND (`npcflag` & 0x02) = 0;
UPDATE `creature_template` SET `npcflag` = `npcflag` | 0x02 WHERE `entry` IN (237510, 237511, 237565, 237567, 237594, 237602, 237786, 237787, 237860, 238296, 239574, 239650, 239795, 239810, 239826, 239827, 239828, 239944, 240033, 240034, 240186, 240215, 240216, 240240, 240523, 240533, 240691, 240714, 240747, 240839, 241045, 241068, 241070, 241109, 241205, 241206, 241272, 241308, 241311, 241654, 241677, 241704, 241742, 242120, 242143, 242433, 243091, 243884, 243886, 243984, 244422, 244438, 244588, 244592, 245004, 245186, 245270, 245271, 247299, 247414, 248263, 249653, 250839, 251355, 252312, 253125, 253988, 254884, 255822) AND (`npcflag` & 0x02) = 0;

-- Delete gameobject_queststarter entries for non-existing quests (97 entries)
DELETE FROM `gameobject_queststarter` WHERE `quest` IN (84567, 84568, 84572, 84575, 84579, 84580, 90069, 90070, 90071, 90072, 90080, 90082, 90090, 90091, 90092, 90104, 90105, 90106, 90107, 90116, 90117, 90118, 90155, 90167, 90168, 90169, 90173, 90187, 90188, 90222, 90223, 90224, 90225, 90226, 90227, 90228, 90229, 90235, 90246, 90252, 90253, 90254, 90255, 90256, 90259, 90263, 90264, 90265, 90267, 90268, 90269, 90271, 90272, 90273, 90274, 90275, 90297, 90298, 90299, 90300, 90302, 90309, 90310, 90311, 90316, 90317, 90318, 90319, 90320, 90321, 90322, 90338, 90339, 90341, 90342, 90343, 90359, 90360, 90361, 90362, 90363, 90367, 90379, 90383, 90384, 90385, 90386, 90400, 90401, 90412, 90413, 90414, 90430, 90431, 90432, 90433, 195924);

-- Delete gameobject_questender entries for non-existing quests (96 entries)
DELETE FROM `gameobject_questender` WHERE `quest` IN (84567, 84568, 84572, 84575, 84579, 84580, 90069, 90070, 90071, 90072, 90079, 90080, 90089, 90090, 90091, 90104, 90105, 90106, 90107, 90116, 90117, 90154, 90167, 90168, 90172, 90186, 90187, 90221, 90222, 90223, 90224, 90225, 90226, 90227, 90228, 90234, 90251, 90252, 90253, 90254, 90255, 90260, 90262, 90263, 90264, 90267, 90268, 90273, 90274, 90284, 90296, 90297, 90298, 90299, 90308, 90309, 90310, 90315, 90316, 90317, 90318, 90319, 90320, 90321, 90325, 90337, 90338, 90340, 90341, 90342, 90343, 90358, 90359, 90360, 90361, 90362, 90366, 90371, 90377, 90378, 90382, 90383, 90384, 90385, 90400, 90411, 90412, 90413, 90429, 90430, 90431, 90432, 90434, 90435, 90446, 196475);

-- Fix quest_offer_reward non-existing emotes (set to 0)
UPDATE `quest_offer_reward` SET `Emote1` = 0 WHERE `ID` IN (65287, 65371, 65711, 65761, 65778, 65953, 66262, 66299, 70132, 82700, 82701, 84721, 85876) AND `Emote1` = 65535;
UPDATE `quest_offer_reward` SET `Emote2` = 0 WHERE `ID` IN (72708, 84727) AND `Emote2` = 65535;
UPDATE `quest_offer_reward` SET `Emote3` = 0 WHERE `ID` IN (66055, 66056) AND `Emote3` = 65535;
UPDATE `quest_offer_reward` SET `Emote4` = 0 WHERE `ID` IN (66055, 66056) AND `Emote4` = 65535;

-- Fix quest_details non-existing emotes (set to 0)
UPDATE `quest_details` SET `Emote2` = 0 WHERE `ID` IN (1106, 12123) AND `Emote2` = 2000;
UPDATE `quest_details` SET `Emote2` = 0 WHERE `ID` IN (862) AND `Emote2` = 3000;
UPDATE `quest_details` SET `Emote3` = 0 WHERE `ID` IN (833, 857, 6182, 6183, 6184, 6186) AND `Emote3` = 2000;
UPDATE `quest_details` SET `Emote3` = 0 WHERE `ID` IN (11538) AND `Emote3` = 3000;
UPDATE `quest_details` SET `Emote3` = 0 WHERE `ID` IN (862) AND `Emote3` = 5000;
UPDATE `quest_details` SET `Emote4` = 0 WHERE `ID` IN (7441) AND `Emote4` = 1500;
UPDATE `quest_details` SET `Emote4` = 0 WHERE `ID` IN (857) AND `Emote4` = 2000;
UPDATE `quest_details` SET `Emote4` = 0 WHERE `ID` IN (6182, 6183, 6184, 6186, 11538) AND `Emote4` = 3000;

-- Delete gameobject_questitem entries with nonexistent items (7 entries)
DELETE FROM `gameobject_questitem` WHERE `GameObjectEntry` = 19868 AND `Idx` = 0 AND `ItemId` = 5798;
DELETE FROM `gameobject_questitem` WHERE `GameObjectEntry` = 19869 AND `Idx` = 0 AND `ItemId` = 5798;
DELETE FROM `gameobject_questitem` WHERE `GameObjectEntry` = 19870 AND `Idx` = 0 AND `ItemId` = 5798;
DELETE FROM `gameobject_questitem` WHERE `GameObjectEntry` = 19871 AND `Idx` = 0 AND `ItemId` = 5798;
DELETE FROM `gameobject_questitem` WHERE `GameObjectEntry` = 19872 AND `Idx` = 0 AND `ItemId` = 5798;
DELETE FROM `gameobject_questitem` WHERE `GameObjectEntry` = 19873 AND `Idx` = 0 AND `ItemId` = 5798;
DELETE FROM `gameobject_questitem` WHERE `GameObjectEntry` = 203396 AND `Idx` = 0 AND `ItemId` = 56249;

-- Fix loot template reference entries: clear QuestRequired on Reference type (ItemType=1)
-- creature_loot_template: 3510 entries
UPDATE `creature_loot_template` SET `QuestRequired` = 0 WHERE `ItemType` = 1 AND `QuestRequired` = 1;
-- gameobject_loot_template: 6 entries
UPDATE `gameobject_loot_template` SET `QuestRequired` = 0 WHERE `Entry` = 12883 AND `Item` = 12900 AND `ItemType` = 1 AND `QuestRequired` = 1;
UPDATE `gameobject_loot_template` SET `QuestRequired` = 0 WHERE `Entry` = 24154 AND `Item` = 12906 AND `ItemType` = 1 AND `QuestRequired` = 1;
UPDATE `gameobject_loot_template` SET `QuestRequired` = 0 WHERE `Entry` = 24156 AND `Item` = 12906 AND `ItemType` = 1 AND `QuestRequired` = 1;
UPDATE `gameobject_loot_template` SET `QuestRequired` = 0 WHERE `Entry` = 24157 AND `Item` = 12906 AND `ItemType` = 1 AND `QuestRequired` = 1;
UPDATE `gameobject_loot_template` SET `QuestRequired` = 0 WHERE `Entry` = 51307 AND `Item` = 12906 AND `ItemType` = 1 AND `QuestRequired` = 1;
UPDATE `gameobject_loot_template` SET `QuestRequired` = 0 WHERE `Entry` = 51309 AND `Item` = 12906 AND `ItemType` = 1 AND `QuestRequired` = 1;


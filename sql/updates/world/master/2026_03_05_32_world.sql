-- 2026_03_05_32_world.sql
-- Stormwind combat NPC equipment — 19 entries missing weapons
-- Based on archetype reference: guards=sword+shield, sentinels=glaive, etc.

-- Reference items used:
--   1899 = Stormwind Guard Sword (1H Sword)
--   143  = Stormwind Guard Shield
--   2179 = Sentinel Glaive (2H)
--   2550 = Sentinel Staff
--   5305 = Dagger (officers)
--   5278 = Marshal 2H Sword
--   1900 = Agent Shortsword
--   24014 = Vindicator Warhammer
--   2181 = Claymore

-- Stormwind Harbor Guard already has equipment (entry 29712 matched to 68 pattern)

-- Darnassus Sentinels (4 spawns) — Night Elf glaive
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(114465, 1, 2179, 0, 0, 0);

-- Summoned Guardian (2 spawns) — sword + shield
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(149121, 1, 1899, 143, 0, 0);

-- Scalecommander Azurathel (2 spawns) — Dracthyr paladin, warhammer
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(189603, 1, 24014, 0, 0, 0);

-- Field Marshal Stonebridge (1 spawn) — 2H sword
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(14721, 1, 5278, 0, 0, 0);

-- Field Marshal Cogspark (1 spawn) — rogue, dual daggers
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(125515, 1, 5305, 5305, 0, 0);

-- Carla Granger (1 spawn) — warrior, sword + shield
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(1291, 1, 1899, 143, 0, 0);

-- Captain Garrick (116160) — Alliance captain, sword + shield
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(116160, 1, 1899, 143, 0, 0);

-- Captain Garrick (163219) — different phase version
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(163219, 1, 1899, 143, 0, 0);

-- Captain Angelica (1 spawn) — captain, sword + shield
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(108920, 1, 1899, 143, 0, 0);

-- Captain Kerwin (1 spawn) — captain, sword + shield
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(64860, 1, 1899, 143, 0, 0);

-- Captain Day (1 spawn) — captain, sword + shield
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(64861, 1, 1899, 143, 0, 0);

-- Commander Sharp (1 spawn) — commander, sword + offhand
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(108896, 1, 2179, 143, 0, 0);

-- Knight Dameron (1 spawn) — knight, sword + shield
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(108916, 1, 1899, 143, 0, 0);

-- Officer Carven (1 spawn) — officer, sword
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(107936, 1, 1899, 0, 0, 0);

-- Officer Blythe (1 spawn) — officer, sword
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(107935, 1, 1899, 0, 0, 0);

-- Vindicator Minkey (1 spawn) — Draenei vindicator, warhammer
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(131334, 1, 24014, 0, 0, 0);

-- Agent Render (1 spawn) — SI:7 agent, daggers
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(199340, 1, 1900, 0, 0, 0);

-- Earthen Guardian (1 spawn) — paladin, warhammer + shield
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(154464, 1, 24014, 143, 0, 0);

-- Brave Researcher (6 spawns) — expedition warrior, sword
INSERT IGNORE INTO `creature_equip_template` (`CreatureID`, `ID`, `ItemID1`, `ItemID2`, `ItemID3`, `VerifiedBuild`) VALUES
(187193, 1, 1899, 0, 0, 0);

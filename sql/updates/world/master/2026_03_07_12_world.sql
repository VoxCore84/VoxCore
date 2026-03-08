-- ============================================================
-- Arcane Waygate — floating book NPC + hotfix spell
-- Spell 1900028: cast to open teleport gossip menu
-- NPC 400100: floating book creature (summoned by spell)
-- ============================================================

-- Creature template: passive, gossip-enabled, floating book
DELETE FROM `creature_template` WHERE `entry` = 400100;
INSERT INTO `creature_template` (`entry`, `name`, `subname`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `scale`, `Classification`, `unit_class`, `unit_flags`, `unit_flags2`, `type`, `AIName`, `flags_extra`, `ScriptName`) VALUES
(400100, 'Arcane Waygate', 'Teleporter', 35, 1, 1, 1, 1, 0, 1, 0x02000000, 0, 10, '', 0x80, 'npc_arcane_waygate');

-- Display model: invisible stalker (proven working, display 29886)
DELETE FROM `creature_template_model` WHERE `CreatureID` = 400100;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) VALUES
(400100, 0, 29886, 1, 1, 66263);

-- Clean up any old serverside spell entries (now a hotfix spell)
DELETE FROM `serverside_spell_effect` WHERE `SpellID` = 1900028;
DELETE FROM `serverside_spell` WHERE `Id` = 1900028;

-- Link spell 1900028 to its C++ SpellScript handler
DELETE FROM `spell_script_names` WHERE `spell_id` = 1900028;
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES (1900028, 'spell_arcane_waygate');

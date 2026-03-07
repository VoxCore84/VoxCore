-- =====================================================================
-- Spell Audit: Register missing spell_script_names for existing handlers
-- Generated: 2026-03-07
--
-- These spells have working C++ handler classes but were registered
-- under old (pre-Dragonflight) spell IDs. Adds current spell ID mappings.
-- =====================================================================

-- 260708 - Sweeping Strikes (Warrior Arms)
-- Handler: spell_warr_sweeping_strikes in spell_warrior.cpp:1976
-- Old registrations: 12328, 18765, 35429 (Cata/MoP era IDs)
DELETE FROM `spell_script_names` WHERE `spell_id` = 260708 AND `ScriptName` = 'spell_warr_sweeping_strikes';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES (260708, 'spell_warr_sweeping_strikes');

-- 53563 - Beacon of Light (Paladin Holy)
-- Handler: spell_pal_light_s_beacon in spell_paladin.cpp:1412
-- Old registration: 53651 (pre-Legion ID)
DELETE FROM `spell_script_names` WHERE `spell_id` = 53563 AND `ScriptName` = 'spell_pal_light_s_beacon';
INSERT INTO `spell_script_names` (`spell_id`, `ScriptName`) VALUES (53563, 'spell_pal_light_s_beacon');

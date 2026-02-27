-- Fix: Remove SPELL_AURA_CONTROL_VEHICLE auras from creature_addon (42 entries)
-- Error: Creature has SPELL_AURA_CONTROL_VEHICLE aura defined in auras field in creature_addon
-- Strategy: Use string replacement to remove specific spell IDs from space-separated auras field
-- Pattern: TRIM(REPLACE(CONCAT(' ', auras, ' '), ' SPELL_ID ', ' '))

-- Remove vehicle aura 46598 from 17 creatures
UPDATE `creature_addon` SET `auras` = TRIM(REPLACE(CONCAT(' ', `auras`, ' '), ' 46598 ', ' ')) WHERE `guid` IN (567669, 567670, 567679, 567680, 567718, 567720, 567762, 567763, 567764, 567765, 568592, 568593, 568594, 568614, 568615, 3000104483, 3000104487);

-- Remove vehicle aura 87978 from 21 creatures
UPDATE `creature_addon` SET `auras` = TRIM(REPLACE(CONCAT(' ', `auras`, ' '), ' 87978 ', ' ')) WHERE `guid` IN (567738, 567739, 567741, 567744, 567745, 567747, 567748, 567978, 567979, 567985, 567987, 567990, 567993, 567996, 568037, 568039, 568040, 568041, 568043, 568047, 568051);

-- Remove vehicle aura 122729 from 2 creatures
UPDATE `creature_addon` SET `auras` = TRIM(REPLACE(CONCAT(' ', `auras`, ' '), ' 122729 ', ' ')) WHERE `guid` IN (371271, 371273);

-- Remove vehicle aura 268221 from 2 creatures
UPDATE `creature_addon` SET `auras` = TRIM(REPLACE(CONCAT(' ', `auras`, ' '), ' 268221 ', ' ')) WHERE `guid` IN (3000037092, 3000037093);

-- Clean up: Set empty auras fields to NULL
UPDATE `creature_addon` SET `auras` = NULL WHERE `guid` IN (371271, 371273, 567669, 567670, 567679, 567680, 567718, 567720, 567738, 567739, 567741, 567744, 567745, 567747, 567748, 567762, 567763, 567764, 567765, 567978, 567979, 567985, 567987, 567990, 567993, 567996, 568037, 568039, 568040, 568041, 568043, 568047, 568051, 568592, 568593, 568594, 568614, 568615, 3000037092, 3000037093, 3000104483, 3000104487) AND (`auras` = '' OR `auras` = ' ');

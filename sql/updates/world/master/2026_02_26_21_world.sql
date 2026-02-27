-- Fix: creature_template non-existing faction templates (40 entries)
-- Error: Creature has non-existing faction template. This can lead to crashes, set to faction 35.
-- Strategy: Set faction to 35 (friendly to all) to match server runtime fix

-- Faction 0 -> 35 (11 creatures)
UPDATE `creature_template` SET `faction` = 35 WHERE `entry` IN (234687, 252008, 252598, 253982, 254218, 256197, 256422, 9100610, 9100611, 9100612, 9100613) AND `faction` = 0;

-- Faction 469 -> 35 (1 creatures)
UPDATE `creature_template` SET `faction` = 35 WHERE `entry` IN (144796) AND `faction` = 469;

-- Faction 1133 -> 35 (1 creatures)
UPDATE `creature_template` SET `faction` = 35 WHERE `entry` IN (142740) AND `faction` = 1133;

-- Faction 2517 -> 35 (20 creatures)
UPDATE `creature_template` SET `faction` = 35 WHERE `entry` IN (186317, 186324, 186326, 186331, 186429, 186447, 186763, 186764, 186765, 188445, 191014, 191015, 191021, 191038, 191039, 191042, 191043, 191044, 191851, 196995) AND `faction` = 2517;

-- Faction 2571 -> 35 (7 creatures)
UPDATE `creature_template` SET `faction` = 35 WHERE `entry` IN (181016, 186430, 186451, 187187, 187189, 189461, 189713) AND `faction` = 2571;

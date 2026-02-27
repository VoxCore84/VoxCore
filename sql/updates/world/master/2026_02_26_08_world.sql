-- 2026_02_26_08_world.sql
-- Fix creature_equip_template entries referencing unknown items
-- Item 53835 and 50127 do not exist in DB2 item data.
-- 8 rows affected across 8 creature entries.

-- Fix ItemID1 for 7 entries
UPDATE `creature_equip_template` SET `ItemID1` = 0 WHERE `CreatureID` = 10540 AND `ID` = 1 AND `ItemID1` != 0;
UPDATE `creature_equip_template` SET `ItemID1` = 0 WHERE `CreatureID` = 31649 AND `ID` = 1 AND `ItemID1` != 0;
UPDATE `creature_equip_template` SET `ItemID1` = 0 WHERE `CreatureID` = 39654 AND `ID` = 1 AND `ItemID1` != 0;
UPDATE `creature_equip_template` SET `ItemID1` = 0 WHERE `CreatureID` = 40391 AND `ID` = 1 AND `ItemID1` != 0;
UPDATE `creature_equip_template` SET `ItemID1` = 0 WHERE `CreatureID` = 42283 AND `ID` = 1 AND `ItemID1` != 0;
UPDATE `creature_equip_template` SET `ItemID1` = 0 WHERE `CreatureID` = 52924 AND `ID` = 1 AND `ItemID1` != 0;
UPDATE `creature_equip_template` SET `ItemID1` = 0 WHERE `CreatureID` = 53069 AND `ID` = 1 AND `ItemID1` != 0;

-- Fix ItemID3 for 1 entries
UPDATE `creature_equip_template` SET `ItemID3` = 0 WHERE `CreatureID` = 58765 AND `ID` = 1 AND `ItemID3` != 0;

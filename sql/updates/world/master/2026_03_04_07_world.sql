-- 2026_03_04_07_world.sql
-- RoleplayCore — Clear ScriptName='0' on imported scenario/delve entries
-- These 23 entries have ScriptName set to literal '0' instead of empty string.
-- TC can't match '0' as a script class — generates DB errors on startup.
-- All entries are in the 9100xxx custom import range + one at 99213894.

UPDATE `creature_template` SET `ScriptName` = '' WHERE `ScriptName` = '0';

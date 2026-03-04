-- 2026_03_04_09_world.sql
-- RoleplayCore — Clear orphan SmartAI AIName for 2 Stormwind NPCs
-- Olivia Jayne (43451) and Captain Garrick (116160) have AIName='SmartAI'
-- but zero smart_scripts rows for their entry or GUID. They load SmartAI
-- with no script to execute, making them completely inert.

UPDATE `creature_template` SET `AIName` = '' WHERE `entry` IN (43451, 116160);

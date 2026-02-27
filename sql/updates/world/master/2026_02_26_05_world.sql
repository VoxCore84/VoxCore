-- 2026_02_26_05_world.sql
-- Fix creature_template entries with speed_walk = 0 or speed_run = 0
-- These cause server warnings and get force-set to defaults at runtime.
-- speed_walk default = 1.0, speed_run default = 1.14286 (8/7)

-- Fix speed_walk = 0 -> 1
UPDATE `creature_template` SET `speed_walk` = 1 WHERE `speed_walk` = 0;

-- Fix speed_run = 0 -> 1.14286
UPDATE `creature_template` SET `speed_run` = 1.14286 WHERE `speed_run` = 0;

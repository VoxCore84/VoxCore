--
-- Delete creature loot entries with near-zero drop chance (< 0.01%)
-- TC skips these at load time with "low chance - skipped" warning.
-- Threshold matches LootMgr.cpp: `if (chance != 0 && chance < 0.0001f)`
-- Removes ~1654 dead rows that generate log warnings every startup.
--
DELETE FROM `creature_loot_template` WHERE `Chance` > 0 AND `Chance` < 0.0001 AND `ItemType` = 0;

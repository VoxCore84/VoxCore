-- Deduplicate creature_loot_template and gameobject_loot_template
-- Both tables had their data imported twice, resulting in ~3M duplicate rows in
-- creature_loot_template (6.2M -> 3.1M) and ~64K in gameobject_loot_template (129K -> 65K).
-- This caused ~880 "group chance > 100%" errors in DBErrors.log because grouped loot
-- entries had their chances counted twice.
--
-- Strategy: For each logical loot row (Entry, ItemType, Item, GroupId, LootMode, QuestRequired,
-- MinCount, MaxCount), keep only one row. When the same logical key has multiple Chance values
-- (from the two different data sources), keep the lower Chance (the normalized value).
-- When Comment differs, prefer the non-empty Comment.

SET @old_timeout = @@SESSION.innodb_lock_wait_timeout;
SET SESSION innodb_lock_wait_timeout = 300;

-- ============================================================
-- creature_loot_template deduplication
-- ============================================================

-- Step 1: Create clean table with same structure
DROP TABLE IF EXISTS `creature_loot_template_clean`;
CREATE TABLE `creature_loot_template_clean` LIKE `creature_loot_template`;

-- Step 2: Insert deduplicated data - one row per logical key, keeping MIN(Chance)
-- and preferring non-empty Comment
INSERT INTO `creature_loot_template_clean`
    (`Entry`, `ItemType`, `Item`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`, `Reference`)
SELECT
    `Entry`, `ItemType`, `Item`,
    MIN(`Chance`) AS `Chance`,
    `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`,
    -- Prefer non-empty comment: MAX will pick the longest/non-null one
    MAX(`Comment`) AS `Comment`,
    MAX(`Reference`) AS `Reference`
FROM `creature_loot_template`
GROUP BY `Entry`, `ItemType`, `Item`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`;

-- Step 3: Atomic swap
RENAME TABLE
    `creature_loot_template` TO `creature_loot_template_backup`,
    `creature_loot_template_clean` TO `creature_loot_template`;

-- Step 4: Drop backup (comment out if you want to keep it for safety)
DROP TABLE IF EXISTS `creature_loot_template_backup`;

-- ============================================================
-- gameobject_loot_template deduplication
-- ============================================================

-- Step 1: Create clean table with same structure
DROP TABLE IF EXISTS `gameobject_loot_template_clean`;
CREATE TABLE `gameobject_loot_template_clean` LIKE `gameobject_loot_template`;

-- Step 2: Insert deduplicated data (gameobject_loot_template has no Reference column)
INSERT INTO `gameobject_loot_template_clean`
    (`Entry`, `ItemType`, `Item`, `Chance`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`, `Comment`)
SELECT
    `Entry`, `ItemType`, `Item`,
    MIN(`Chance`) AS `Chance`,
    `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`,
    MAX(`Comment`) AS `Comment`
FROM `gameobject_loot_template`
GROUP BY `Entry`, `ItemType`, `Item`, `QuestRequired`, `LootMode`, `GroupId`, `MinCount`, `MaxCount`;

-- Step 3: Atomic swap
RENAME TABLE
    `gameobject_loot_template` TO `gameobject_loot_template_backup`,
    `gameobject_loot_template_clean` TO `gameobject_loot_template`;

-- Step 4: Drop backup
DROP TABLE IF EXISTS `gameobject_loot_template_backup`;

SET SESSION innodb_lock_wait_timeout = @old_timeout;

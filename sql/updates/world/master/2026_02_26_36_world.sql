--
-- Clear QuestRequired flag on reference loot entries (ItemType=1)
-- TC ignores QuestRequired on references and logs:
--   "quest required will be ignored"
-- Affects 3525 creature_loot_template + 6 gameobject_loot_template rows.
--
UPDATE `creature_loot_template` SET `QuestRequired` = 0 WHERE `ItemType` = 1 AND `QuestRequired` = 1;
UPDATE `gameobject_loot_template` SET `QuestRequired` = 0 WHERE `ItemType` = 1 AND `QuestRequired` = 1;

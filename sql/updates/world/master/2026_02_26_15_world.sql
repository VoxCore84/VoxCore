--
-- Remove quest_reward_display_spell entries referencing spells that don't exist in 12.x DBC/DB2.
-- These produce: "Table `quest_reward_display_spell` has non-existing Spell (X) set for quest Y. Skipped."
-- 5 rows affected: quests 1521, 6081, 6103, 62828, 72547 with spells 8071, 23357, 344819, 404683.
--

DELETE FROM `quest_reward_display_spell` WHERE (`QuestID`, `SpellID`) IN (
    (1521,  8071),
    (6081,  23357),
    (6103,  23357),
    (62828, 344819),
    (72547, 404683)
);

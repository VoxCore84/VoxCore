--
-- Remove conversation_line_template entries whose ConversationLine IDs don't exist in
-- the 12.x ConversationLine DBC/DB2.
-- These produce: "Table `conversation_line_template` has template for non existing
-- ConversationLine (ID: X), skipped"
-- 6 rows affected.
--
-- Note: 4 of these IDs (29386, 34207, 36347, 36369) are referenced as FirstLineId by
-- conversation_template rows (12076, 12084, 14514, 14520). Those conversations are
-- already non-functional since their first line can't load. Cleaning up the dependent
-- conversation_template and conversation_actors rows is left for a separate pass if
-- those produce their own errors.
--

DELETE FROM `conversation_line_template` WHERE `Id` IN (
    29386,
    29440,
    34207,
    36347,
    36369,
    36399
);

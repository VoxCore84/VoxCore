-- 2026_03_07_14_world.sql
-- Add missing achievement_reward entries for reputation achievements with title rewards

-- 60 Exalted Reputations → the Beloved (title 308)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(6742, 308, 308, 0, 0, '', '', 0);

-- 80 Exalted Reputations → the Admired (title 630)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(12864, 630, 630, 0, 0, '', '', 0);

-- 100 Exalted Reputations → Esteemed (title 629)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(12866, 629, 629, 0, 0, '', '', 0);

-- Avengers of Hyjal → Avenger of Hyjal (title 267)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(5827, 267, 267, 0, 0, '', '', 0);

-- The Shado-Master → Shado-Master (title 318)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(7479, 318, 318, 0, 0, '', '', 0);

-- Wakener → the Wakener (title 338)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(8023, 338, 338, 0, 0, '', '', 0);

-- Mantle of the Talon King → Talon King (415) / Talon Queen (416) — gender-based, stored as A/H
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(9072, 415, 416, 0, 0, '', '', 0);

-- Chromie Homie → Timelord (title 510)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(11941, 510, 510, 0, 0, '', '', 0);

-- Soupervisor → Soupervisor (title 732)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(16443, 732, 732, 0, 0, '', '', 0);

-- Loyalty to the Prince → Agent of the Black Prince (title 745)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(16494, 745, 745, 0, 0, '', '', 0);

-- The Obsidian Bloodline → Paragon of the Obsidian Brood (title 744)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(16760, 744, 744, 0, 0, '', '', 0);

-- The Grand Tapestry → Silksinger (title 847)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(40874, 847, 847, 0, 0, '', '', 0);

-- True Strength → Anub (title 848)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(40875, 848, 848, 0, 0, '', '', 0);

-- Vox Arachni → Hand of the Vizier (title 849)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(40876, 849, 849, 0, 0, '', '', 0);

-- Ally of Undermine → the Explosive (title 879)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(41086, 879, 879, 0, 0, '', '', 0);

-- A Long Fuse → Darkfuse Diplomat (title 882)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(41350, 882, 882, 0, 0, '', '', 0);

-- Trade-Duke → Trade-Duke (title 883)
INSERT IGNORE INTO `achievement_reward` (`ID`, `TitleA`, `TitleH`, `ItemID`, `Sender`, `Subject`, `Body`, `MailTemplateID`) VALUES
(41352, 883, 883, 0, 0, '', '', 0);

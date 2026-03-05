-- 2026_03_05_13_world.sql
-- quest reward text cleanup

-- Fix unconverted <name> tag in quest_offer_reward (ID 28089)
UPDATE `quest_offer_reward` SET `RewardText` = REPLACE(REPLACE(REPLACE(`RewardText`, '<name>', '$N'), '<Name>', '$N'), '<NAME>', '$N')
WHERE `RewardText` LIKE '%<name>%' OR `RewardText` LIKE '%<Name>%' OR `RewardText` LIKE '%<NAME>%';

-- Fix unconverted <name> tag in quest_request_items (ID 263)
UPDATE `quest_request_items` SET `CompletionText` = REPLACE(REPLACE(REPLACE(`CompletionText`, '<name>', '$N'), '<Name>', '$N'), '<NAME>', '$N')
WHERE `CompletionText` LIKE '%<name>%' OR `CompletionText` LIKE '%<Name>%' OR `CompletionText` LIKE '%<NAME>%';

-- Remove empty reward text placeholder rows (no useful data)
DELETE FROM `quest_offer_reward` WHERE `RewardText` = '' OR `RewardText` IS NULL;

-- Remove empty completion text rows from import (VerifiedBuild=0 only; TDB rows may carry emote data)
DELETE FROM `quest_request_items` WHERE (`CompletionText` = '' OR `CompletionText` IS NULL) AND `VerifiedBuild` = 0;

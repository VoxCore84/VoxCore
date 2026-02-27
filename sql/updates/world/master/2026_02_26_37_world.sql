--
-- Fix gameobject_loot_template entry 2277 groups with total chance > 100%
--
-- Group 2: 5 items each at 100% = 500% total -> normalize to 20% each
-- Group 4: 2 items each at 100% = 200% total -> normalize to 50% each
--
-- Note: entry 2277 appears orphaned (no gameobject_template references it),
-- but fixing the data is cleaner than deleting it in case it's used by
-- scripts or future content.
--

-- Group 2: set each of the 5 items from 100% to 20%
UPDATE `gameobject_loot_template`
SET `Chance` = 20
WHERE `Entry` = 2277 AND `GroupId` = 2 AND `Chance` = 100
  AND `Item` IN (2318, 2447, 2449, 2589, 2842);

-- Group 4: set each of the 2 items from 100% to 50%
UPDATE `gameobject_loot_template`
SET `Chance` = 50
WHERE `Entry` = 2277 AND `GroupId` = 4 AND `Chance` = 100
  AND `Item` IN (117, 159);

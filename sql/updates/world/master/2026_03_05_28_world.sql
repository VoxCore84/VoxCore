-- 2026_03_05_28_world.sql
-- Revert duplicate Hero's Call Board quest starters and remove overlapping spawn
--
-- GO 206111 (old Hero's Call Board) overlaps with GO 281339 (newer board) at the
-- same Stormwind location. 281339 already has all relevant quests + expansion
-- breadcrumbs. Remove the 28 quest starters added in _27 and the duplicate spawn.

-- Revert the 28 gameobject_queststarter rows added for GO 206111 in _27
DELETE FROM `gameobject_queststarter` WHERE `id`=206111 AND `quest` IN (27724,27726,27727,28551,28552,28558,28562,28563,28564,28576,28578,28579,28582,28666,28673,28675,28699,28702,28708,28709,28716,28825,29156,29387,29547,34398,36498,40519);

-- Remove the overlapping old board spawn (guid 171144, entry 206111) that sits
-- on top of the newer 281339 spawn (guid 301205) at -8817/629
DELETE FROM `gameobject` WHERE `guid`=171144 AND `id`=206111;

-- Clean up the 2 remaining orphan quest starters on the now-unspawned old board
DELETE FROM `gameobject_queststarter` WHERE `id`=206111;

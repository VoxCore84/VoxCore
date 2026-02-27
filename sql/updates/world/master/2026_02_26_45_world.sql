--
-- Add missing destructible_hitpoint records referenced by gameobject_template entries
--
-- 64 gameobjects (GoType 33 = DESTRUCTIBLE_BUILDING) reference 17 hitpoint record IDs
-- that don't exist in the destructible_hitpoint table. This causes ~64 errors at startup:
--   "GameObject (Entry: X) Has non existing Destructible Hitpoint Record Y."
--
-- No authoritative source (Wago DB2, LoreWalkerTDB, upstream TrinityCore) contains these
-- records. Existing records in the 48+ ID range are consistently (0, 0), indicating
-- non-destructible buildings. Inserting with (0, 0) matches current runtime behavior
-- (null hitpoint pointer = health 0 = building cannot be damaged) and silences the errors.
--
-- Missing IDs: 2, 7, 17, 19, 20, 68, 78, 84, 85, 86, 87, 88, 89, 90, 99, 100, 122
-- Affected GO entries include: Wintergrasp walls, Lava Bridge, Troll city walls,
-- IoTTK/MoP scenarios, Broken Shore buildings, Tomb of Sargeras Avatar floors,
-- Naglfar, Flagships, Auchindoun, Blackhand, and misc platforms/gates.
--

INSERT IGNORE INTO `destructible_hitpoint` (`Id`, `IntactNumHits`, `DamagedNumHits`) VALUES
(2, 0, 0),
(7, 0, 0),
(17, 0, 0),
(19, 0, 0),
(20, 0, 0),
(68, 0, 0),
(78, 0, 0),
(84, 0, 0),
(85, 0, 0),
(86, 0, 0),
(87, 0, 0),
(88, 0, 0),
(89, 0, 0),
(90, 0, 0),
(99, 0, 0),
(100, 0, 0),
(122, 0, 0);

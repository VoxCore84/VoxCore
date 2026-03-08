-- ============================================================================
-- Phase 1A: Verified Safe Cleanup
-- Date: 2026-03-07
-- ============================================================================
-- This script removes:
--   1. Corrupt gameobject spawns with impossibly large GUIDs (guid >= 71 billion)
--      and their linked game_event_gameobject rows. 36,641 gameobject rows +
--      10,386 game_event_gameobject rows. These are data corruption artifacts
--      with GUIDs in the 71B, 710B, and 4T+ ranges.
--   2. Duplicate Portal to Darnassus (id=293894) spawn at identical coords in
--      phase 0 (guid 9000001). The corrupt-range duplicates are caught by #1.
--   3. Duplicate Warchief's Command Board (id=206116) at identical position in
--      Orgrimmar (guid 219020, keeping guid 211261).
--   4. Super Shellkhan Gang (id=198147, guid 3000142692) stuck at Z=-2000.
--   5. Stormwind throne room duplicate lore NPCs: same-entry duplicates stacked
--      at nearly identical positions with no phase separation.
--
-- All targets verified by direct query. No addon, smart_scripts, pool, or
-- event data exists for any creature being deleted. Gameobject event rows
-- are cleaned first due to FK-like dependencies.
-- ============================================================================

-- ============================================================================
-- SECTION 1: Corrupt gameobject data (guid >= 71,000,000,000)
-- 36,641 gameobject rows + 10,386 game_event_gameobject rows
-- ============================================================================

-- 1a. Remove orphaned game_event_gameobject references first (10,386 rows)
DELETE FROM game_event_gameobject WHERE guid >= 71000000000;

-- 1b. Remove the corrupt gameobject spawns themselves (36,641 rows)
DELETE FROM gameobject WHERE guid >= 71000000000;

-- ============================================================================
-- SECTION 2: Portal to Darnassus (id=293894) duplicate
-- 3 valid-range spawns exist:
--   guid 400334 @ (-8645.39, 1308.28, 5.234) phaseId=6666 -- KEEP (RP phase)
--   guid 501812 @ (-8645.39, 1308.28, 5.234) phaseId=0    -- KEEP (default)
--   guid 9000001 @ (-8645.39, 1308.28, 5.234) phaseId=0   -- DELETE (duplicate)
-- The 3 corrupt-range dupes (71B/710B/4T) are already handled by Section 1.
-- ============================================================================

DELETE FROM gameobject WHERE guid = 9000001 AND id = 293894;

-- ============================================================================
-- SECTION 3: Warchief's Command Board (id=206116) duplicate
-- 2 spawns at identical position (1914.14, -4661.89, 33.6092) map=1, phaseId=0
--   guid 211261 -- KEEP (lower guid, original)
--   guid 219020 -- DELETE (exact duplicate)
-- Neither has event or pool links.
-- ============================================================================

DELETE FROM gameobject WHERE guid = 219020 AND id = 206116;

-- ============================================================================
-- SECTION 4: Super Shellkhan Gang (entry=198147) stuck at Z=-2000
-- guid 3000142692 @ (-8934.08, 1014.02, -2000) map=0
-- No creature_addon or smart_scripts linked.
-- ============================================================================

DELETE FROM creature WHERE guid = 3000142692 AND id = 198147;

-- ============================================================================
-- SECTION 5: Stormwind throne room duplicate lore NPCs
-- All in map=0, zoneId=1519, phaseId=0, phaseGroup=0.
-- No creature_addon or smart_scripts on any of these GUIDs.
--
-- King Varian Wrynn (entry=29611):
--   guid 3000215345 @ (-8368.82, 239.091, 155.76)  -- KEEP
--   guid 3000221238 @ (-8368.82, 235.616, 156.10)  -- DELETE (duplicate)
--
-- Anduin Wrynn (entry=165395):
--   guid 3000217040 @ (-8366.50, 239.091, 155.76)  -- KEEP
--   guid 3000221532 @ (-8366.50, 232.141, 156.50)  -- DELETE (duplicate)
--
-- Genn Greymane: Two different entries (45253 Cata-era, 165394 DF/TWW-era)
-- stacked at identical position (-8368.82, 235.616, 156.101).
-- Keep the modern version (165394), remove the obsolete one (45253).
--   guid 3000221260, entry=45253  -- DELETE (obsolete Cata version)
--   guid 3000221531, entry=165394 -- KEEP (modern version)
--
-- Master Mathias Shaw: Two different entries (111307, 111313) stacked at
-- identical position (-8718.63, 315.541, 105.593). Entry 111313 has
-- gossip (npcflag=3), entry 111307 does not. Keep the gossip version.
--   guid 3000221388, entry=111307 -- DELETE (no gossip, redundant)
--   guid 3000221389, entry=111313 -- KEEP (has gossip npcflag=3)
-- ============================================================================

-- King Varian Wrynn duplicate
DELETE FROM creature WHERE guid = 3000221238 AND id = 29611;

-- Anduin Wrynn duplicate
DELETE FROM creature WHERE guid = 3000221532 AND id = 165395;

-- Genn Greymane obsolete Cata version (keeping 165394 modern version)
DELETE FROM creature WHERE guid = 3000221260 AND id = 45253;

-- Master Mathias Shaw redundant version (keeping 111313 with gossip)
DELETE FROM creature WHERE guid = 3000221388 AND id = 111307;

-- ============================================================================
-- Summary:
--   game_event_gameobject deleted: ~10,386 rows
--   gameobject deleted:           ~36,642 rows (36,641 corrupt + 1 Portal dupe)
--   creature deleted:                   5 rows (1 Shellkhan + 4 throne room)
--   Total cleanup:               ~47,033 rows
-- ============================================================================

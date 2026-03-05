-- 2026_03_05_30_world.sql
-- Stormwind phase cleanup — Day of the Dead event gating + broken spawn removal

-- ============================================================
-- Problem A: 139 Day of the Dead NPCs visible year-round
-- 136 Ghostly Human Celebrant (35249) + Chapman (34382) + Catrina (34383) + Cheerful Human Spirit (34435)
-- All in phase 0 with no game_event_creature link — ghosts everywhere, all year
-- Fix: Link to game_event 51 (Day of the Dead)
-- ============================================================
INSERT IGNORE INTO `game_event_creature` (`eventEntry`, `guid`)
SELECT 51, `guid` FROM `creature` WHERE `guid` BETWEEN 3000089416 AND 3000089554 AND `zoneId` = 1519;

-- ============================================================
-- Problem C: 2 Darkmoon Faire NPCs at world origin (0, 0, 0)
-- Mystic Birdhat (62821) and Cousin Slowhands (62822) — broken coordinates
-- ============================================================
DELETE FROM `creature` WHERE `guid` IN (3000072300, 3000072301);
DELETE FROM `creature_addon` WHERE `guid` IN (3000072300, 3000072301);
DELETE FROM `game_event_creature` WHERE `guid` IN (3000072300, 3000072301);

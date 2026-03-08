-- ============================================================================
-- Fix faction=0 Midnight NPCs and clean up deprecated phase data
-- 2026-03-07
-- ============================================================================

-- ============================================================================
-- PART 1: Faction=0 fixes for spawned Midnight creatures
-- ============================================================================
-- All entries verified against same-name faction lookups in creature_template.
-- Faction 35 is the universal standard for Midnight (12.x) expansion NPCs.
-- Original Silvermoon Guard entries (241696, 241703, 248289, 251038, 251701)
-- all use faction 35, NOT the legacy Silvermoon City Guardian faction 1603.
-- ============================================================================

-- ----- Silvermoon City NPCs (map 0, Quel'Thalas region) -----

-- Silvermoon Guards (6 entries) — matches existing Silvermoon Guard faction 35
UPDATE creature_template SET faction = 35 WHERE entry IN (260436, 260475, 260573, 260638) AND faction = 0;

-- Silvermoon Residents (6 entries) — matches existing faction 35 (10 uses)
UPDATE creature_template SET faction = 35 WHERE entry IN (260464, 260476, 260572, 260625, 260640, 260672) AND faction = 0;

-- Silvermoon Nobles (5 entries) — matches existing faction 35
UPDATE creature_template SET faction = 35 WHERE entry IN (260479, 260576, 260621, 260639, 260677) AND faction = 0;

-- Silvermoon Citizens — matches existing faction 35 (7 uses, most recent entries)
UPDATE creature_template SET faction = 35 WHERE entry = 260382 AND faction = 0;

-- Silvermoon Children — matches existing faction 35 (2 uses)
UPDATE creature_template SET faction = 35 WHERE entry = 260454 AND faction = 0;

-- Silvermoon Dockworkers — matches existing faction 35 (3 uses)
UPDATE creature_template SET faction = 35 WHERE entry = 260652 AND faction = 0;

-- Household Attendant — matches existing faction 35
UPDATE creature_template SET faction = 35 WHERE entry = 260482 AND faction = 0;

-- Row Rat — matches existing faction 35 (14 uses)
UPDATE creature_template SET faction = 35 WHERE entry = 260519 AND faction = 0;

-- Row Bruiser — matches existing faction 35
UPDATE creature_template SET faction = 35 WHERE entry = 260535 AND faction = 0;

-- Doomsayer — matches existing faction 35 (7 uses, most common)
UPDATE creature_template SET faction = 35 WHERE entry = 260891 AND faction = 0;

-- Blood Knight Adept — matches existing faction 35 (6 uses, most common)
UPDATE creature_template SET faction = 35 WHERE entry = 260679 AND faction = 0;

-- Blood Knight Initiate — Wowhead shows H:Friendly only, Silvermoon City faction
UPDATE creature_template SET faction = 1604 WHERE entry = 260680 AND faction = 0;

-- ----- Named Silvermoon NPCs -----

-- Grand Magister Rommath — matches existing faction 35 (44 uses, overwhelmingly dominant)
UPDATE creature_template SET faction = 35 WHERE entry = 260415 AND faction = 0;

-- Halduron Brightwing — matches existing faction 35 (40 uses, overwhelmingly dominant)
UPDATE creature_template SET faction = 35 WHERE entry = 260416 AND faction = 0;

-- Sathren Azuredawn — same-name match has faction 1604 (Silvermoon), but for Midnight
-- context faction 35 is standard; 1604 is legacy BC
UPDATE creature_template SET faction = 35 WHERE entry = 259864 AND faction = 0;

-- Image of Astalor Bloodsworn — matches existing faction 35
UPDATE creature_template SET faction = 35 WHERE entry = 259865 AND faction = 0;

-- Archmage Celindra — matches existing faction 35 (4 uses, most common)
UPDATE creature_template SET faction = 35 WHERE entry = 261304 AND faction = 0;

-- Agmera — same-name match has faction 3407, but for Midnight NPC in Silvermoon, use 35
UPDATE creature_template SET faction = 35 WHERE entry = 261303 AND faction = 0;

-- ----- Quest/Story NPCs in Quel'Thalas -----

-- Bloomrotten Corpse (2 entries) — matches existing faction 35 (4 uses)
UPDATE creature_template SET faction = 35 WHERE entry IN (260465, 260489) AND faction = 0;

-- Docile Hawkstrider (beast) — matches existing faction 35
UPDATE creature_template SET faction = 35 WHERE entry = 260524 AND faction = 0;

-- Vaeli (4 entries, maps 0/2735/2736) — matches existing faction 35
UPDATE creature_template SET faction = 35 WHERE entry IN (260942, 260943, 260957, 260958) AND faction = 0;

-- ----- Ghostlands / Hinterlands / Troll NPCs -----

-- Witherbark Guard — all other Witherbark NPCs use faction 654 (Troll, Witherbark, hostile)
UPDATE creature_template SET faction = 654 WHERE entry = 260885 AND faction = 0;

-- Amani'Zar Defender — Wowhead shows A:Hostile H:Hostile, Amani Tribe faction
UPDATE creature_template SET faction = 1890 WHERE entry = 260886 AND faction = 0;

-- Kul'amara the Fierce — matches existing faction 35 (6 uses)
UPDATE creature_template SET faction = 35 WHERE entry = 260645 AND faction = 0;

-- Kapara Pup (beast) — matches existing faction 35 (5 uses)
UPDATE creature_template SET faction = 35 WHERE entry = 261115 AND faction = 0;

-- Loa Speaker Kinduru — matches existing faction 35 (5 uses)
UPDATE creature_template SET faction = 35 WHERE entry = 261198 AND faction = 0;

-- Zul'Aman bosses (cosmetic outdoor versions, NOT raid) — faction 35 (10+ uses each)
UPDATE creature_template SET faction = 35 WHERE entry IN (260999, 261000, 261001, 261002) AND faction = 0;

-- Twilight Warrior — matches existing faction 35
UPDATE creature_template SET faction = 35 WHERE entry = 262221 AND faction = 0;

-- ----- Silver Covenant / Quel'Danas NPCs -----

-- Captain Auric Sunchaser — Wowhead shows A:Friendly, Silver Covenant faction
UPDATE creature_template SET faction = 2025 WHERE entry = 260327 AND faction = 0;

-- Pathstalker Ralsir — matches existing faction 35 (2 uses, most common)
UPDATE creature_template SET faction = 35 WHERE entry = 260335 AND faction = 0;

-- Ranger Selone — matches existing faction 35 (2 uses)
UPDATE creature_template SET faction = 35 WHERE entry = 260336 AND faction = 0;

-- Rulen Lightsreap — matches existing faction 35 (2 uses)
UPDATE creature_template SET faction = 35 WHERE entry = 260337 AND faction = 0;

-- Matron Alesso — matches existing faction 35
UPDATE creature_template SET faction = 35 WHERE entry = 260339 AND faction = 0;

-- Arcanist Paharin — legacy faction 2027 (Sunreaver); for Midnight, use 35
UPDATE creature_template SET faction = 35 WHERE entry = 260340 AND faction = 0;

-- Silver Covenant Arcanist — Wowhead confirms A:Friendly H:Hostile, Silver Covenant faction
UPDATE creature_template SET faction = 2025 WHERE entry = 260350 AND faction = 0;

-- Silver Covenant Scout — has factions 2130/534/1732/35; for Midnight, use 35
UPDATE creature_template SET faction = 35 WHERE entry = 260351 AND faction = 0;

-- ----- Crafting / Service NPCs -----

-- Larissia (Crafting Orders) — legacy faction 1735 (Guild Vendor); Midnight uses 35
UPDATE creature_template SET faction = 35 WHERE entry = 260098 AND faction = 0;

-- Kinamisa (Crafting Orders) — legacy faction 1695 (Leatherworking); Midnight uses 35
UPDATE creature_template SET faction = 35 WHERE entry = 260100 AND faction = 0;

-- ----- Unique-name Midnight NPCs (no same-name match, all type 7 Humanoid) -----

-- Nyssira — unique name, Quel'Thalas NPC
UPDATE creature_template SET faction = 35 WHERE entry = 259883 AND faction = 0;

-- Acolyte Aselyn — unique name, Quel'Thalas NPC
UPDATE creature_template SET faction = 35 WHERE entry = 259893 AND faction = 0;

-- Adoree — unique name, Stormwind NPC (zoneId 1519)
UPDATE creature_template SET faction = 35 WHERE entry = 260064 AND faction = 0;

-- Lord Delevant — unique name, Quel'Thalas NPC
UPDATE creature_template SET faction = 35 WHERE entry = 260071 AND faction = 0;

-- Matron Selinore — unique name, Quel'Thalas NPC
UPDATE creature_template SET faction = 35 WHERE entry = 260073 AND faction = 0;

-- Aeliath — unique name, Quel'Thalas NPC
UPDATE creature_template SET faction = 35 WHERE entry = 260084 AND faction = 0;

-- Rykard Moonflare — unique name, Quel'Thalas NPC
UPDATE creature_template SET faction = 35 WHERE entry = 260085 AND faction = 0;

-- Terelia — unique name, Quel'Thalas NPC
UPDATE creature_template SET faction = 35 WHERE entry = 260086 AND faction = 0;

-- Beliam — unique name, Quel'Thalas NPC
UPDATE creature_template SET faction = 35 WHERE entry = 260087 AND faction = 0;

-- Maesh Emberdead — unique name, Quel'Thalas NPC
UPDATE creature_template SET faction = 35 WHERE entry = 260116 AND faction = 0;

-- University Groundskeeper — unique name, Quel'Thalas NPC
UPDATE creature_template SET faction = 35 WHERE entry = 260143 AND faction = 0;

-- Geraeld Advocaetsun — unique name, map 2601
UPDATE creature_template SET faction = 35 WHERE entry = 260145 AND faction = 0;

-- Zolaar — unique name, Quel'Thalas NPC
UPDATE creature_template SET faction = 35 WHERE entry = 260158 AND faction = 0;

-- Depthdiver Tu'nakit (Abyss Angler) — unique name
UPDATE creature_template SET faction = 35 WHERE entry = 260180 AND faction = 0;

-- Overwhelmed Recruit — unique name
UPDATE creature_template SET faction = 35 WHERE entry = 260245 AND faction = 0;

-- Kara Meldansen (Collector of Orange Animals) — unique name, map 2736
UPDATE creature_template SET faction = 35 WHERE entry = 261034 AND faction = 0;

-- ----- Other named NPCs with same-name matches -----

-- Carl — in Stormwind, type 7 Humanoid; same-name Carl has factions 14/2621/35
-- This is a Midnight-era Stormwind ambient NPC, use 35
UPDATE creature_template SET faction = 35 WHERE entry = 259970 AND faction = 0;

-- Scout — generic name with factions 84/2908/35; for Midnight context, use 35
UPDATE creature_template SET faction = 35 WHERE entry = 260171 AND faction = 0;

-- Winona — matches existing faction 35
UPDATE creature_template SET faction = 35 WHERE entry = 260172 AND faction = 0;

-- Terrified Citizen — factions 7/35/68; Midnight civilian, use 35
UPDATE creature_template SET faction = 35 WHERE entry = 260207 AND faction = 0;

-- Delas Moonfang — matches existing faction 35 (15 uses, overwhelmingly dominant)
UPDATE creature_template SET faction = 35 WHERE entry = 260830 AND faction = 0;

-- Lok'osh Rera — matches existing faction 35
UPDATE creature_template SET faction = 35 WHERE entry = 260829 AND faction = 0;

-- Higgs — matches existing faction 35, map 2735
UPDATE creature_template SET faction = 35 WHERE entry = 261058 AND faction = 0;

-- ----- Beasts / Elementals -----

-- Volatile Light Wyrm (beast, type 1) — unique name, Quel'Thalas; all nearby NPCs use 35
UPDATE creature_template SET faction = 35 WHERE entry = 260159 AND faction = 0;

-- Lightbloom Lasher (beast, type 1) — matches existing faction 35 (9 uses)
UPDATE creature_template SET faction = 35 WHERE entry = 260187 AND faction = 0;

-- Agitated Lightfed Growth (elemental, type 4) — other "Agitated" creatures use 35
UPDATE creature_template SET faction = 35 WHERE entry = 260201 AND faction = 0;


-- ============================================================================
-- PART 2: Phase cleanup — remove deprecated phase 10061
-- ============================================================================
-- Phase 10061 "Deprecated - See Alleria Windrunner in Stormwind Embassy"
-- has ZERO creature spawns and ZERO gameobject spawns globally.
-- It only exists as a phase_area entry for Stormwind (AreaId 1519).
-- Safe to remove the phase_area entry and its condition.
-- ============================================================================

-- Remove the unused phase_area entry
DELETE FROM phase_area WHERE PhaseId = 10061 AND AreaId = 1519;

-- Remove the associated condition (SourceEntry = 0 means global)
DELETE FROM conditions WHERE SourceTypeOrReferenceId = 26 AND SourceGroup = 10061 AND SourceEntry = 0;


-- ============================================================================
-- PART 3: Phase 22310 (Love is in the Air) — already properly conditioned
-- ============================================================================
-- VERIFIED: Phase 22310 already has a global condition (SourceEntry = 0):
--   ConditionTypeOrReference = 12 (game_event active)
--   ConditionValue1 = 8 (Love is in the Air, eventEntry = 8)
-- The initial query missed this because it only checked SourceEntry = 1519.
-- The global condition (SourceEntry = 0) applies to ALL areas including 1519.
-- NO ACTION NEEDED.
-- ============================================================================

-- ============================================================================
-- Fix ContentTuningID=0 on city and key NPCs
-- Uses Wowhead-verified ContentTuning values per entry, with bulk fallbacks
-- All updates restricted to DifficultyID=0 and ContentTuningID=0 (idempotent)
-- 2026-03-07
-- ============================================================================

-- ============================================================================
-- SECTION 1: STORMWIND — Wowhead-verified individual entries
-- ============================================================================

-- Stormwind City Guards (level 80) → CT 2888 [Wowhead-verified]
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 2888
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` IN (186180, 214423);

-- Genn Greymane (DB2 confirmed leader) → CT 781 [Wowhead-verified]
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 781
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` = 162204;

-- Falstad Wildhammer (boss/elite) → CT 781 [Wowhead-verified]
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 781
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` = 151079;

-- Flynn Fairwind (level 80) → CT 2888 [Wowhead-verified]
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 2888
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` = 198629;

-- Sergeant Willem (level 80) → CT 2888 [Wowhead-verified]
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 2888
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` = 198991;

-- Greyguard Elite (level 70) → CT 2078 [Wowhead-verified]
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 2078
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` = 212899;

-- Injured Soldier (level 80) → CT 2888 [Wowhead-verified]
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 2888
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` = 199970;

-- ============================================================================
-- SECTION 2: SILVERMOON — Wowhead-verified Midnight NPCs (260xxx entries)
-- ============================================================================

-- Silvermoon Guards (Elite, level 90) → CT 3320 [Wowhead-verified]
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 3320
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` IN (260436, 260475, 260573, 260638);

-- Silvermoon Residents, Nobles, Citizens, Children, Dockworkers, Blood Knights,
-- Household Attendants, Row Rats, Row Bruisers (level 80-90) → CT 3321 [Wowhead-verified]
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 3321
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` IN (
    260464, 260476, 260572, 260625, 260640, 260672, -- Silvermoon Residents
    260479, 260576, 260621, 260639, 260677,          -- Silvermoon Nobles
    260382,                                           -- Silvermoon Citizen
    260454,                                           -- Silvermoon Child
    260652,                                           -- Silvermoon Dockworker
    260482,                                           -- Household Attendant
    260519,                                           -- Row Rat
    260535,                                           -- Row Bruiser
    260679, 260680                                    -- Blood Knight Adept / Initiate
);

-- Named NPCs: Grand Magister Rommath, Halduron Brightwing → CT 3321 [Wowhead-verified]
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 3321
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` IN (260415, 260416);

-- ============================================================================
-- SECTION 3: EXODAR — DB2-confirmed individual entry
-- ============================================================================

-- Exodar Worker → CT 1281 [DB2-confirmed]
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 1281
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` = 210345;

-- ============================================================================
-- SECTION 4: EXILE'S REACH (zone 10424) — Level 1-10 tutorial NPCs → CT 1484
-- Corrected: These are Exile's Reach, NOT Dornogal. CT 1484 is the dominant
-- ContentTuning for zone 10424 (715 of ~844 existing entries use it).
-- ============================================================================

-- Thrall, Wrathion, Bo, Lana Jordan, Mithdran Dawntracker, Grunt Throg,
-- Cork Fizzlepop, Choppy Booster Mk. 5, Provisioner Jin'hake
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 1484
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` IN (
    166782, 167021, -- Thrall
    167126,         -- Wrathion
    166786, 166787, 167910, -- Bo
    166796, 166797, -- Lana Jordan
    166791, 166792, 167020, -- Mithdran Dawntracker
    166784,         -- Grunt Throg
    167019,         -- Cork Fizzlepop
    167027,         -- Choppy Booster Mk. 5
    166800,         -- Provisioner Jin'hake
    167912          -- Provisoner Jin'hake (typo in DB)
);

-- ============================================================================
-- SECTION 5: BULK ZONE FALLBACKS — remaining CT=0 entries not handled above
-- Excludes creature types: Critter (8), Totem (10), Non-combat Pet (11)
-- ============================================================================

-- -------------------------------------------------------
-- 5a. Stormwind (zone 1519) — Wowhead-verified CT 2888 entries
-- Guards, patrollers, adventurers, and combat NPCs (fixed level 80)
-- -------------------------------------------------------
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 2888
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` IN (
    214422, -- Stormwind City Patroller [Wowhead-verified]
    253181, -- Babbling Brawler          [Wowhead-verified]
    253183, -- Chatty Contender          [same brawler category as 253181]
    255073, -- Quel'Thalas Adventurer    [Wowhead-verified]
    259249  -- Jonathar Moonshore        [Wowhead-verified]
);

-- -------------------------------------------------------
-- 5b. Stormwind (zone 1519) remaining → CT 864 (84 entries)
-- Civilians, workers, event NPCs, named NPCs [zone-fallback]
-- CT 864 is the dominant ContentTuning for Stormwind (scaling 10-70)
-- -------------------------------------------------------
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 864
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` IN (
    101759, 163095, 165542, 165548, 171447, 174621, 185467, 185468,
    188151, 188342, 188521, 188523, 188678, 188679, 198147, 198579,
    198581, 198589, 198611, 198918, 199145, 199149, 201230, 202700,
    203229, 203243, 211802, 211803, 211812, 211864, 211871, 211872,
    211873, 211874, 211908, 211909, 211913, 211915, 211916, 211944,
    211945, 212517, 212583, 212584, 212587, 212669, 212670, 212737,
    212886, 212887, 213096, 213177, 213263, 213457, 213948, 214023,
    214032, 214040, 214042, 214120, 214259, 214540, 215144,
    215483, 215555, 216439, 242173, 242175, 242177, 242626, 246696,
    251867, 251875, 254603, 255099, 256071,
    256938, 259276, 259728, 259747, 259749, 259970, 260064,
    261231
);

-- -------------------------------------------------------
-- 5c. Orgrimmar (zone 1637) remaining → CT 864 (4 entries) [zone-fallback]
-- -------------------------------------------------------
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 864
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` IN (184664, 184666, 184786, 198552);

-- -------------------------------------------------------
-- 5d. Exodar (zone 3557) remaining → CT 864 (44 entries) [zone-fallback]
-- CT 864 is the dominant ContentTuning for Exodar (255 of ~436 existing entries).
-- Wowhead shows these BC NPCs at level 10-30 / fixed 30. CT 864 covers this range.
-- -------------------------------------------------------
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 864
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` IN (
    16657, 16705, 16708, 16710, 16713, 16714, 16716, 16718,
    16722, 16723, 16724, 16725, 16726, 16727, 16731, 16732,
    16736, 16739, 16740, 16741, 16742, 16743, 16747, 16750,
    16751, 16752, 16753, 16757, 16762, 16764, 16765, 16774,
    17504, 17510, 17512, 17520, 17773, 18350, 18917, 19778,
    20722, 21019, 34986, 34987
);

-- -------------------------------------------------------
-- 5e. Silvermoon (zone 3487) remaining legacy BC NPCs → CT 864 (75 entries)
-- [zone-fallback] CT 864 is the dominant ContentTuning for Silvermoon BC entries
-- (285 of ~431 existing entry<100000 entries). Wowhead confirms level 10-30.
-- These are legacy BC NPCs, NOT Midnight 260xxx entries (handled in Section 2).
-- -------------------------------------------------------
UPDATE `creature_template_difficulty` SET `ContentTuningID` = 864
WHERE `DifficultyID` = 0 AND `ContentTuningID` = 0
AND `Entry` IN (
    16191, 16442, 16611, 16612, 16613, 16615, 16616, 16618,
    16619, 16620, 16623, 16624, 16625, 16626, 16627, 16629,
    16631, 16633, 16635, 16636, 16637, 16638, 16639, 16640,
    16641, 16642, 16644, 16646, 16650, 16655, 16656, 16662,
    16663, 16664, 16666, 16667, 16668, 16669, 16670, 16671,
    16673, 16674, 16676, 16677, 16679, 16680, 16684, 16688,
    16689, 16690, 16691, 16692, 16693, 16780, 16782, 17627,
    17628, 17629, 17630, 17631, 17632, 17633, 18188, 18190,
    18191, 18761, 18790, 20087, 25149, 25152, 25202, 25207,
    34973, 40413, 44129
);

-- 2026_03_03_02_world.sql
-- Remove stacked/duplicate Hero's Call Board and Warchief's Command Board spawns
-- LoreWalker TDB imported old-framework boards (206294, 206116) on top of modern boards

-- ============================================================================
-- Phase 1: Delete stacked LoreWalker imports (206294 Hero's Call Board)
-- These 9 spawns are exact-position duplicates of modern Hero's Call Boards
-- ============================================================================
DELETE FROM gameobject WHERE guid IN (
    990000000101160999, -- map 0, Stormwind (-8823, 630) — stacked on 281339 guid 301205
    990000000101161000, -- map 0, Stormwind (-8341, 641) — stacked on 281339 guid 220456
    990000000101162010, -- map 0, Ironforge (-4937, -914) — stacked on 207320 guid 218253
    990000000101162012, -- map 0, Lakeshire (-3212, -5037) — stacked on 278575 guid 237258
    990000000101162019, -- map 0, (-1225, -2541) — stacked on 278575 guid 210413474
    990000000101162011, -- map 1, Darnassus (9951, 2496) — stacked on 207321 guid 219333
    990000000101162002, -- map 530, Exodar (-3942, -11651) — stacked on 207322 guid 309
    990000000101162000, -- map 571, Dalaran (5717, 742) — stacked on 208316 guid 81
    990000000101162015  -- map 646, (991, 562) — stacked on 278575 guid 301162
);

-- ============================================================================
-- Phase 2: Delete stacked LoreWalker imports (206116 Warchief's Command Board)
-- These 11 spawns are exact-position duplicates of modern Warchief's Command Boards
-- ============================================================================
DELETE FROM gameobject WHERE guid IN (
    990000000101162014, -- map 0, (-4846, -4846) — stacked on 278347 guid 237524
    990000000101162013, -- map 0, (-3679, -5275) — stacked on 278347 guid 237379
    990000000101162018, -- map 0, (-900, -3522) — stacked on 278347 guid 210413467
    990000000101162007, -- map 0, (-578, -1062) — stacked on 207279 guid 204287
    990000000101162006, -- map 0, (-45, -899) — stacked on 207279 guid 204216
    990000000101162005, -- map 0, (1557, 240) — stacked on 207324 guid 203440
    990000000101162009, -- map 1, Thunder Bluff (-1252, 76) — stacked on 207323 guid 214905
    990000000101162008, -- map 1, Orgrimmar (1600, -4369) — stacked on 206109 guid 211334
    990000000101162003, -- map 1, Orgrimmar (1609, -4386) — stacked on 206109 guid 171145
    990000000101162004, -- map 530, Silvermoon (9665, -7153) — stacked on 207325 guid 200628
    990000000101162001  -- map 571, Dalaran (5914, 564) — stacked on 208317 guid 82
);

-- ============================================================================
-- Phase 3: Delete extra 206294 spawns in Stormwind (triple-board situation)
-- These 2 spawns are ~5m offset from the stacked pairs, creating triple boards
-- ============================================================================
DELETE FROM gameobject WHERE guid IN (
    4000000000147665, -- map 0, Stormwind (-8823, 636) — near 281339 guid 301205
    4000000000147666  -- map 0, Stormwind (-8340, 643) — near 281339 guid 220456
);

-- ============================================================================
-- Phase 4: Delete orphan 206111 (Hero's Call Board with zero quests)
-- ============================================================================
DELETE FROM gameobject WHERE guid = 171144; -- map 0, Stormwind (-8817, 629) — entry 206111, 0 quests

-- ============================================================================
-- Phase 5: Delete 2 missed LoreWalker 206116 spawns (stacked on 278347/278457)
-- ============================================================================
DELETE FROM gameobject WHERE guid IN (
    990000000101162016, -- map 646, (1008, 481) — stacked on 278347 guid 301169
    990000000101162017  -- map 1220, (-769, 4346) — stacked on 278457 guid 210400013
);

-- ============================================================================
-- Phase 6: Copy quest associations to zero-quest modern boards
-- Entries 281339, 278575 (Hero) had 0 quests — the deleted 206294 was serving them
-- Entries 278347, 278457 (Warchief) had 0 quests — the deleted 206116 was serving them
-- ============================================================================

-- Hero's Call Board: copy 206294's 33 quests to 281339 and 278575
INSERT IGNORE INTO gameobject_queststarter (id, quest)
SELECT 281339, quest FROM gameobject_queststarter WHERE id = 206294;

INSERT IGNORE INTO gameobject_queststarter (id, quest)
SELECT 278575, quest FROM gameobject_queststarter WHERE id = 206294;

-- Warchief's Command Board: copy 206116's 29 quests to 278347 and 278457
INSERT IGNORE INTO gameobject_queststarter (id, quest)
SELECT 278347, quest FROM gameobject_queststarter WHERE id = 206116;

INSERT IGNORE INTO gameobject_queststarter (id, quest)
SELECT 278457, quest FROM gameobject_queststarter WHERE id = 206116;

-- Clean up gameobject_addon for deleted spawns
DELETE FROM gameobject_addon WHERE guid IN (
    990000000101160999, 990000000101161000, 990000000101162010,
    990000000101162012, 990000000101162019, 990000000101162011,
    990000000101162002, 990000000101162000, 990000000101162015,
    990000000101162014, 990000000101162013, 990000000101162018,
    990000000101162007, 990000000101162006, 990000000101162005,
    990000000101162009, 990000000101162008, 990000000101162003,
    990000000101162004, 990000000101162001, 990000000101162016,
    990000000101162017, 4000000000147665, 4000000000147666, 171144
);

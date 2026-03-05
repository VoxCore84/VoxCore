-- 2026_03_05_00_world.sql
-- Fix 26,745 creatures missing DifficultyID=0 rows (stuck at level 1 on outdoor maps)
-- Step 1a: Copy DifficultyID=2 rows to DifficultyID=0 for 24,070 creatures that only have Diff2
-- Step 1b: Copy from lowest available DifficultyID for 68 creatures with Diff1/3/14 but not Diff0/2
-- Step 2: Create default DifficultyID=0 rows for 2,607 creatures with no CTD rows at all

-- Step 1: Copy Diff2 -> Diff0
-- These creatures have heroic dungeon data but no normal-difficulty data.
-- On outdoor maps (difficulty=0), the server finds no Diff0 row and falls back to
-- a static default (ContentTuningID=0, all modifiers=1, no loot). Copying Diff2
-- gives them proper modifiers, loot IDs, gold, type flags, and CreatureDifficultyID.
INSERT INTO `creature_template_difficulty` (
    `Entry`, `DifficultyID`,
    `LevelScalingDeltaMin`, `LevelScalingDeltaMax`,
    `ContentTuningID`, `HealthScalingExpansion`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `DamageModifier`,
    `CreatureDifficultyID`, `TypeFlags`, `TypeFlags2`, `TypeFlags3`,
    `LootID`, `PickPocketLootID`, `SkinLootID`,
    `GoldMin`, `GoldMax`,
    `StaticFlags1`, `StaticFlags2`, `StaticFlags3`, `StaticFlags4`,
    `StaticFlags5`, `StaticFlags6`, `StaticFlags7`, `StaticFlags8`,
    `VerifiedBuild`
)
SELECT
    src.`Entry`, 0 AS `DifficultyID`,
    src.`LevelScalingDeltaMin`, src.`LevelScalingDeltaMax`,
    src.`ContentTuningID`, src.`HealthScalingExpansion`,
    src.`HealthModifier`, src.`ManaModifier`, src.`ArmorModifier`, src.`DamageModifier`,
    src.`CreatureDifficultyID`, src.`TypeFlags`, src.`TypeFlags2`, src.`TypeFlags3`,
    src.`LootID`, src.`PickPocketLootID`, src.`SkinLootID`,
    src.`GoldMin`, src.`GoldMax`,
    src.`StaticFlags1`, src.`StaticFlags2`, src.`StaticFlags3`, src.`StaticFlags4`,
    src.`StaticFlags5`, src.`StaticFlags6`, src.`StaticFlags7`, src.`StaticFlags8`,
    src.`VerifiedBuild`
FROM `creature_template_difficulty` src
WHERE src.`DifficultyID` = 2
AND NOT EXISTS (
    SELECT 1 FROM `creature_template_difficulty` existing
    WHERE existing.`Entry` = src.`Entry`
    AND existing.`DifficultyID` = 0
);

-- Step 1b: Copy from lowest available DifficultyID for creatures that had Diff1/3/14/etc. but not Diff2
-- (68 creatures — dungeon/raid creatures with only non-zero difficulty data)
INSERT INTO `creature_template_difficulty` (
    `Entry`, `DifficultyID`,
    `LevelScalingDeltaMin`, `LevelScalingDeltaMax`,
    `ContentTuningID`, `HealthScalingExpansion`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `DamageModifier`,
    `CreatureDifficultyID`, `TypeFlags`, `TypeFlags2`, `TypeFlags3`,
    `LootID`, `PickPocketLootID`, `SkinLootID`,
    `GoldMin`, `GoldMax`,
    `StaticFlags1`, `StaticFlags2`, `StaticFlags3`, `StaticFlags4`,
    `StaticFlags5`, `StaticFlags6`, `StaticFlags7`, `StaticFlags8`,
    `VerifiedBuild`
)
SELECT
    src.`Entry`, 0,
    src.`LevelScalingDeltaMin`, src.`LevelScalingDeltaMax`,
    src.`ContentTuningID`, src.`HealthScalingExpansion`,
    src.`HealthModifier`, src.`ManaModifier`, src.`ArmorModifier`, src.`DamageModifier`,
    src.`CreatureDifficultyID`, src.`TypeFlags`, src.`TypeFlags2`, src.`TypeFlags3`,
    src.`LootID`, src.`PickPocketLootID`, src.`SkinLootID`,
    src.`GoldMin`, src.`GoldMax`,
    src.`StaticFlags1`, src.`StaticFlags2`, src.`StaticFlags3`, src.`StaticFlags4`,
    src.`StaticFlags5`, src.`StaticFlags6`, src.`StaticFlags7`, src.`StaticFlags8`,
    src.`VerifiedBuild`
FROM `creature_template_difficulty` src
INNER JOIN (
    SELECT `Entry`, MIN(`DifficultyID`) AS `MinDiff`
    FROM `creature_template_difficulty`
    WHERE `Entry` NOT IN (
        SELECT `Entry` FROM `creature_template_difficulty` WHERE `DifficultyID` = 0
    )
    GROUP BY `Entry`
) best ON best.`Entry` = src.`Entry` AND best.`MinDiff` = src.`DifficultyID`;

-- Step 2: Create default Diff0 rows for creatures with NO difficulty rows at all
-- These get the same defaults as the C++ static fallback, but having an explicit row
-- normalizes the data and provides a place for future ContentTuningID enrichment.
INSERT INTO `creature_template_difficulty` (
    `Entry`, `DifficultyID`,
    `LevelScalingDeltaMin`, `LevelScalingDeltaMax`,
    `ContentTuningID`, `HealthScalingExpansion`,
    `HealthModifier`, `ManaModifier`, `ArmorModifier`, `DamageModifier`,
    `CreatureDifficultyID`, `TypeFlags`, `TypeFlags2`, `TypeFlags3`,
    `LootID`, `PickPocketLootID`, `SkinLootID`,
    `GoldMin`, `GoldMax`,
    `StaticFlags1`, `StaticFlags2`, `StaticFlags3`, `StaticFlags4`,
    `StaticFlags5`, `StaticFlags6`, `StaticFlags7`, `StaticFlags8`,
    `VerifiedBuild`
)
SELECT
    ct.`entry`, 0,
    0, 0,
    0, 0,
    1, 1, 1, 1,
    0, 0, 0, 0,
    0, 0, 0,
    0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0
FROM `creature_template` ct
WHERE NOT EXISTS (
    SELECT 1 FROM `creature_template_difficulty` ctd
    WHERE ctd.`Entry` = ct.`entry`
);

-- ============================================================
-- Arcane Waygate (ID: 1900028) — Hotfix spell (client-visible)
-- Instant cast, self-target DUMMY effect, arcane school
-- ============================================================

-- spell_name
REPLACE INTO `hotfixes`.`spell_name` (`ID`, `Name`, `VerifiedBuild`) VALUES (1900028, 'Arcane Waygate', 66263);
REPLACE INTO `hotfixes`.`hotfix_data` (`Id`, `UniqueId`, `TableHash`, `RecordId`, `Status`, `VerifiedBuild`) VALUES (1900200, 19002001, 1187407512, 1900028, 1, 66263);

-- spell (description text)
REPLACE INTO `hotfixes`.`spell` (`ID`, `NameSubtext`, `Description`, `AuraDescription`, `VerifiedBuild`) VALUES (1900028, NULL, 'Opens a magical portal menu to teleport anywhere in the world.', NULL, 66263);
REPLACE INTO `hotfixes`.`hotfix_data` (`Id`, `UniqueId`, `TableHash`, `RecordId`, `Status`, `VerifiedBuild`) VALUES (1900201, 19002012, 3776013982, 1900028, 1, 66263);

-- spell_misc (instant cast, no duration, self range, arcane school, portal icon)
REPLACE INTO `hotfixes`.`spell_misc` (`ID`,
  `Attributes1`, `Attributes2`, `Attributes3`, `Attributes4`, `Attributes5`,
  `Attributes6`, `Attributes7`, `Attributes8`, `Attributes9`, `Attributes10`,
  `Attributes11`, `Attributes12`, `Attributes13`, `Attributes14`, `Attributes15`,
  `Attributes16`, `Attributes17`,
  `DifficultyID`, `CastingTimeIndex`, `DurationIndex`, `PvPDurationIndex`,
  `RangeIndex`, `SchoolMask`, `Speed`, `LaunchDelay`, `MinDuration`,
  `SpellIconFileDataID`, `ActiveIconFileDataID`, `ContentTuningID`,
  `ShowFutureSpellPlayerConditionID`, `SpellVisualScript`, `ActiveSpellVisualScript`,
  `SpellID`, `VerifiedBuild`) VALUES (1900028,
  0, 0, 0, 0, 0,
  0, 0, 0, 0, 0,
  0, 0, 0, 0, 0,
  0, 0,
  0, 1, 0, 0,
  1, 64, 0, 0, 0,
  135744, 0, 0,
  0, 0, 0,
  1900028, 66263);
REPLACE INTO `hotfixes`.`hotfix_data` (`Id`, `UniqueId`, `TableHash`, `RecordId`, `Status`, `VerifiedBuild`) VALUES (1900202, 19002023, 3322146344, 1900028, 1, 66263);

-- spell_effect (DUMMY effect, self-target)
REPLACE INTO `hotfixes`.`spell_effect` (`ID`, `EffectAura`, `DifficultyID`,
  `EffectIndex`, `Effect`, `EffectAmplitude`, `EffectAttributes`, `EffectAuraPeriod`,
  `EffectBonusCoefficient`, `EffectChainAmplitude`, `EffectChainTargets`,
  `EffectItemType`, `EffectMechanic`, `EffectPointsPerResource`,
  `EffectPosFacing`, `EffectRealPointsPerLevel`, `EffectTriggerSpell`,
  `BonusCoefficientFromAP`, `PvpMultiplier`, `Coefficient`, `Variance`,
  `ResourceCoefficient`, `GroupSizeBasePointsCoefficient`,
  `EffectBasePoints`, `ScalingClass`, `TargetNodeGraph`,
  `EffectMiscValue1`, `EffectMiscValue2`,
  `EffectRadiusIndex1`, `EffectRadiusIndex2`,
  `EffectSpellClassMask1`, `EffectSpellClassMask2`, `EffectSpellClassMask3`, `EffectSpellClassMask4`,
  `ImplicitTarget1`, `ImplicitTarget2`,
  `SpellID`, `VerifiedBuild`) VALUES (1900028, 0, 0,
  0, 3, 0, 0, 0,
  0, 1, 0,
  0, 0, 0,
  0, 0, 0,
  0, 1, 0, 0,
  0, 1,
  0, 0, 0,
  0, 0,
  0, 0,
  0, 0, 0, 0,
  1, 0,
  1900028, 66263);
REPLACE INTO `hotfixes`.`hotfix_data` (`Id`, `UniqueId`, `TableHash`, `RecordId`, `Status`, `VerifiedBuild`) VALUES (1900203, 19002034, 4030871717, 1900028, 1, 66263);

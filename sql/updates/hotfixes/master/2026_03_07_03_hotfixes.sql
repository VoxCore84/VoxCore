-- ============================================================
-- Fix: Windrunner's Grace (1900003) & Chronal Surge (1900004)
-- Remove wrong passive attribute, make active-cast auras
-- ============================================================

-- Windrunner's Grace: clear Attributes1, keep instant/infinite/self
UPDATE `hotfixes`.`spell_misc` SET `Attributes1` = 0 WHERE `SpellID` = 1900003;

-- Chronal Surge: clear Attributes1, keep instant/infinite/self
UPDATE `hotfixes`.`spell_misc` SET `Attributes1` = 0 WHERE `SpellID` = 1900004;

-- Also fix all 23 RP fun spells (visual auras, scale, stealth had the same bad flag)
UPDATE `hotfixes`.`spell_misc` SET `Attributes1` = 0 WHERE `SpellID` BETWEEN 1900005 AND 1900017;

-- Costumes (1900018-1900027) already had Attributes1=0, no fix needed

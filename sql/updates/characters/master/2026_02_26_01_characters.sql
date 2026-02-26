-- 2026_02_26_01_characters.sql
-- Add secondary shoulder appearance persistence to character_transmog_outfits

ALTER TABLE `character_transmog_outfits`
  ADD COLUMN `secondaryShoulderAppearance` int NOT NULL DEFAULT 0 AFTER `offHandEnchant`,
  ADD COLUMN `secondaryShoulderSlot` int NOT NULL DEFAULT 0 AFTER `secondaryShoulderAppearance`;

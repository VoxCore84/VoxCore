-- 2026_02_26_07_world.sql
-- Remove disallowed flags_extra bit 0x10000000 (268435456) from creature_template
-- This flag is not in CREATURE_FLAG_EXTRA_DB_ALLOWED and gets stripped at runtime.
-- Affects 685 creature entries.

-- Clear bit 0x10000000 using bitwise AND with inverse mask
-- ~0x10000000 = 0xEFFFFFFF = 4026531839
UPDATE `creature_template` SET `flags_extra` = `flags_extra` & ~268435456
WHERE `flags_extra` & 268435456 != 0;

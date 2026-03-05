-- 2026_03_04_05_hotfixes.sql
-- Remove 137 orphaned hotfix_data entries for Creature DB2 (hash 0xC9D6B6B3)
-- Server has no hotfix table for this client-only DB2, so entries produce
-- "unknown DB2 store" warnings on every boot.

DELETE FROM `hotfix_data` WHERE `TableHash` = 3386291891;

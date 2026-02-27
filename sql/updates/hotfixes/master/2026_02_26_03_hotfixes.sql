-- Fix: hotfix_data references unknown DB2 store hashes (439 entries)
-- Error: hotfix_data references unknown DB2 store by hash
-- Three unknown hashes found:
--   0x0F992211 (261693969)  - 260 rows
--   0x8C3B7192 (2352705938) - 7 rows
--   0x5373CFEB (1400098795) - 172 rows

DELETE FROM `hotfix_data` WHERE `TableHash` IN (261693969, 2352705938, 1400098795);

-- 2026_03_05_01_world.sql
-- Clear AIName for 5,894 creatures with AIName='SmartAI' but no smart_scripts rows
-- These generate DB errors on every server startup and fall back to default AI anyway

UPDATE `creature_template` ct
SET ct.`AIName` = ''
WHERE ct.`AIName` = 'SmartAI'
AND NOT EXISTS (
    SELECT 1 FROM `smart_scripts` ss
    WHERE ss.`entryorguid` = ct.`entry` AND ss.`source_type` = 0
);

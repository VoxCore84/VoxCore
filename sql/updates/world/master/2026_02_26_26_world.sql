-- Remove creature_template_model rows referencing non-existing CreatureDisplayInfo IDs
-- These display IDs do not exist in the 12.x client DB2 (CreatureDisplayInfo) and cause
-- "Creature (Entry: X) lists non-existing CreatureDisplayID id (Y), this can crash the client."
-- errors on server startup (59 log lines, 55 unique pairs, 29 invalid display IDs, 31 creatures).
--
-- Analysis:
--   - All 29 display IDs confirmed missing from Wago CreatureDisplayInfo DB2 (build 12.0.1.66102)
--   - All 29 display IDs also absent from hotfixes.creature_display_info
--   - No affected creatures are in custom NPC range (400000-499999) or high range (9100000+)
--   - Every affected creature has at least one valid display ID remaining after cleanup
--   - Most bad rows have DisplayScale=47213 and Probability=0 (corrupted import data)
--   - Two creatures (188044, 192626) need Probability fix on their remaining row

-- Step 1: Delete all model rows with invalid CreatureDisplayID values
DELETE FROM creature_template_model WHERE CreatureDisplayID IN (
    38043,  38961,  85414,  147318, 189981, 191143, 191659, 191683,
    191686, 191840, 192126, 192809, 193405, 193417, 194336, 194544,
    194551, 194744, 195386, 198138, 198349, 198847, 198856, 199064,
    199795, 199796, 199797, 199798, 200670
);

-- Step 2: Fix Probability for creatures whose only remaining row had Probability=0
-- After removing bad rows, these creatures have a single valid model with Probability=0,
-- which means no model would be selected. Set to 1 so the creature actually renders.
UPDATE creature_template_model SET Probability = 1
WHERE CreatureID = 188044 AND Idx = 0 AND Probability = 0;

UPDATE creature_template_model SET Probability = 1
WHERE CreatureID = 192626 AND Idx = 0 AND Probability = 0;

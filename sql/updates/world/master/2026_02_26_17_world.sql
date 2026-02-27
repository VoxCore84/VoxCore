--
-- Remove areatrigger_teleport entries whose AreaTrigger IDs no longer exist in 12.x DBC/DB2.
-- These are legacy teleport targets for old arenas (Nagrand, Blade's Edge, Undercity),
-- mage portal endpoints (Stormwind), zone transitions (Ghostlands-EPL), and instance
-- entrances (Scarlet Monastery) that were removed or renumbered in modern clients.
-- These produce: "Area Trigger (ID: X) does not exist in AreaTrigger.dbc."
-- 23 rows affected.
--
-- Note: These IDs were verified to NOT appear in areatrigger_scripts, areatrigger_tavern,
-- areatrigger_involvedrelation, or quest_objectives — only areatrigger_teleport.
--

DELETE FROM `areatrigger_teleport` WHERE `ID` IN (
    702,
    704,
    4409,
    4917,
    4919,
    4921,
    4922,
    4923,
    4924,
    4925,
    4927,
    4928,
    4929,
    4930,
    4931,
    4932,
    4933,
    4934,
    4935,
    4936,
    4941,
    4944,
    45000
);

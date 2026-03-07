-- Stormwind cleanup: event NPCs, wandering Argent Crusade, broken Hero's Call Boards, portal fixes

-- 1. Remove Wickerman Revelers (51699) — Hallow's End event NPCs permanently spawned outside SW gates
DELETE FROM creature WHERE id = 51699;

-- 2. Remove Greymane Retainers (51701) — event NPCs permanently spawned outside SW gates
DELETE FROM creature WHERE id = 51701;

-- 3. Stop Argent Crusade NPCs from wandering (set stationary near SW main entrance)
--    Quartermaster Renick (165839), Commander Gregor (166383), Light's Hope Messenger (172510)
--    Courier Newland (167388) is already stationary
UPDATE creature SET MovementType = 0, wander_distance = 0
WHERE guid IN (3000218157, 3000216517, 3000216575);

-- 4. Remove broken Hero's Call Board spawns (entry 206111) with z=0 (in water/underground)
--    Proper Hero's Call Boards (entry 281339) at correct z remain
DELETE FROM gameobject WHERE id = 206111 AND map = 0 AND position_z = 0;

-- 5. Remove stale Portal to Dalaran - Northrend (191164) — stuck on ground floor (z=65)
--    Correct Dalaran portal already exists: entry 620475 "Portal to Dalaran (Crystalsong)" at z=68
DELETE FROM gameobject WHERE id = 191164 AND map = 0;

-- 6. Fix Portal to Silvermoon (621992) — invisible due to displayId 55666
--    Model 8fx_portalroom_silvermoon.m2 has mesh but NO texture BLP (BfA placeholder, never finished)
--    Change to displayId 6956 (MagePortal_Silvermoon.m2 — classic Silvermoon portal, confirmed working)
UPDATE gameobject_template SET displayId = 6956 WHERE entry = 621992;

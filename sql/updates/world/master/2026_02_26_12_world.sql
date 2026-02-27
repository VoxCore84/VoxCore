-- Fix npc_vendor errors from DBErrors.log
-- Three categories of vendor data quality issues.

-- Category 3a: Delete non-existing vendor items (243 unique vendor+item combos)
-- These items do not exist in the game client and are silently skipped by the server.
-- type=1: 243 combos, 87 unique items
DELETE FROM `npc_vendor` WHERE `type` = 1 AND `item` IN (50164,56162,60405,99712,99742,99743,99744,99745,99746,99747,99748,99749,99750,99751,99752,99753,99754,99755,99756,101538,102457,113193,128444,128475,128482,128490,137178,137401,139381,139382,139383,151060,156530,156724,156725,156726,156727,156758,156760,156761,156762,156763,156764,156765,156766,156767,156768,156769,156770,156771,156772,156773,156774,156775,156776,156777,156778,156779,156780,156781,156782,156783,156784,156785,156786,156787,156788,156789,156790,156791,156793,160105,160106,162355,168207,170540,185350,200918,200924,201000,201001,223284,224761,228913,231267,231269,231270);

-- Category 3b: Fix maxcount > 0 with incrtime = 0 (91 unique vendor+item combos)
-- When maxcount is set (limited stock), incrtime must be > 0 to define restock interval.
-- Setting incrtime to 3600 (1 hour restock) as a reasonable default.
-- Using blanket fix: any row with maxcount > 0 and incrtime = 0 gets incrtime = 3600
UPDATE `npc_vendor` SET `incrtime` = 3600 WHERE `maxcount` > 0 AND `incrtime` = 0;

-- Category 3c: Clear invalid PlayerConditionId (27 unique vendor+item combos)
-- These vendor items reference serverside PlayerConditionIds that have no matching
-- condition rows, so the condition check always fails silently. Setting to 0 (no condition).
UPDATE `npc_vendor` SET `PlayerConditionID` = 0 WHERE `PlayerConditionID` = 5201 AND `entry` IN (15127) AND `item` IN (20132);
UPDATE `npc_vendor` SET `PlayerConditionID` = 0 WHERE `PlayerConditionID` = 12249 AND `entry` IN (50484) AND `item` IN (67535);
UPDATE `npc_vendor` SET `PlayerConditionID` = 0 WHERE `PlayerConditionID` = 12250 AND `entry` IN (50484) AND `item` IN (64914,64915,64916);
UPDATE `npc_vendor` SET `PlayerConditionID` = 0 WHERE `PlayerConditionID` = 12252 AND `entry` IN (49877,108138) AND `item` IN (64901,64902,64903);
UPDATE `npc_vendor` SET `PlayerConditionID` = 0 WHERE `PlayerConditionID` = 19985 AND `entry` IN (69334) AND `item` IN (92071);
UPDATE `npc_vendor` SET `PlayerConditionID` = 0 WHERE `PlayerConditionID` = 102537 AND `entry` IN (196862) AND `item` IN (191579,194265);
UPDATE `npc_vendor` SET `PlayerConditionID` = 0 WHERE `PlayerConditionID` = 102538 AND `entry` IN (196862) AND `item` IN (194261,198895,201733,202117,202118,202119);
UPDATE `npc_vendor` SET `PlayerConditionID` = 0 WHERE `PlayerConditionID` = 103962 AND `entry` IN (188625) AND `item` IN (200970);
UPDATE `npc_vendor` SET `PlayerConditionID` = 0 WHERE `PlayerConditionID` = 103963 AND `entry` IN (188625) AND `item` IN (200971);
UPDATE `npc_vendor` SET `PlayerConditionID` = 0 WHERE `PlayerConditionID` = 103964 AND `entry` IN (188623,199036) AND `item` IN (200971);
UPDATE `npc_vendor` SET `PlayerConditionID` = 0 WHERE `PlayerConditionID` = 103968 AND `entry` IN (188623,199036) AND `item` IN (200970);
-- Entry 68993 item 1963229184 is garbage data (nonsensical item ID) -- delete entirely
DELETE FROM `npc_vendor` WHERE `entry` = 68993 AND `item` = 1963229184;

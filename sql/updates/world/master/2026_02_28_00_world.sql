-- 2026_02_28_00_world.sql
-- Fix Hero's Call Board / Warchief's Command Board duplicates
-- The "Best_Heros_Call_Fix" community patch added Uber Board spawns (206294/206116)
-- but failed to remove the old-ID boards, leaving duplicates stacked at every location.
-- This cleanup removes 23 old-ID boards + 2 duplicate Uber boards in Stormwind.
-- After this fix, each location has exactly ONE board (the correct Uber Board).

-- ============================================================================
-- 1. Remove old-ID Hero's Call Boards that have Uber Board replacements
-- ============================================================================

-- Stormwind Trade District: guid 171144 (206111) — old board at same spot as Uber 990...0999
DELETE FROM `gameobject` WHERE `guid` = 171144 AND `id` = 206111;
DELETE FROM `gameobject_addon` WHERE `guid` = 171144;

-- Stormwind Trade District: guid 301205 (281339) — duplicate at same coords as Uber
DELETE FROM `gameobject` WHERE `guid` = 301205 AND `id` = 281339;
DELETE FROM `gameobject_addon` WHERE `guid` = 301205;

-- Stormwind Dwarven District: guid 220456 (281339) — duplicate at same coords as Uber
DELETE FROM `gameobject` WHERE `guid` = 220456 AND `id` = 281339;
DELETE FROM `gameobject_addon` WHERE `guid` = 220456;

-- Stormwind: guid 4000000000147665 (Uber 206294) — extra Uber Board in Trade District
DELETE FROM `gameobject` WHERE `guid` = 4000000000147665 AND `id` = 206294;
DELETE FROM `gameobject_addon` WHERE `guid` = 4000000000147665;

-- Stormwind: guid 4000000000147666 (Uber 206294) — extra Uber Board in Dwarven District
DELETE FROM `gameobject` WHERE `guid` = 4000000000147666 AND `id` = 206294;
DELETE FROM `gameobject_addon` WHERE `guid` = 4000000000147666;

-- Ironforge: guid 218253 (207320) — old board, replaced by Uber 990...2010
DELETE FROM `gameobject` WHERE `guid` = 218253 AND `id` = 207320;
DELETE FROM `gameobject_addon` WHERE `guid` = 218253;

-- Twilight Highlands Alliance: guid 237258 (278575) — replaced by Uber 990...2012
DELETE FROM `gameobject` WHERE `guid` = 237258 AND `id` = 278575;
DELETE FROM `gameobject_addon` WHERE `guid` = 237258;

-- Hallowfall Alliance: guid 210413474 (278575) — replaced by Uber 990...2019
DELETE FROM `gameobject` WHERE `guid` = 210413474 AND `id` = 278575;
DELETE FROM `gameobject_addon` WHERE `guid` = 210413474;

-- Darnassus: guid 219333 (207321) — replaced by Uber 990...2011
DELETE FROM `gameobject` WHERE `guid` = 219333 AND `id` = 207321;
DELETE FROM `gameobject_addon` WHERE `guid` = 219333;

-- Exodar (Outland): guid 309 (207322) — replaced by Uber 990...2002
DELETE FROM `gameobject` WHERE `guid` = 309 AND `id` = 207322;
DELETE FROM `gameobject_addon` WHERE `guid` = 309;

-- Dalaran (Northrend) Alliance: guid 81 (208316) — replaced by Uber 990...2000
DELETE FROM `gameobject` WHERE `guid` = 81 AND `id` = 208316;
DELETE FROM `gameobject_addon` WHERE `guid` = 81;

-- Tol Barad Alliance: guid 301162 (278575) — replaced by Uber 990...2015
DELETE FROM `gameobject` WHERE `guid` = 301162 AND `id` = 278575;
DELETE FROM `gameobject_addon` WHERE `guid` = 301162;

-- ============================================================================
-- 2. Remove old-ID Warchief's Command Boards that have Uber Board replacements
-- ============================================================================

-- Undercity: guid 203440 (207324) — replaced by Uber 990...2005
DELETE FROM `gameobject` WHERE `guid` = 203440 AND `id` = 207324;
DELETE FROM `gameobject_addon` WHERE `guid` = 203440;

-- Silverpine/Hillsbrad: guid 204216 (207279) — replaced by Uber 990...2006
DELETE FROM `gameobject` WHERE `guid` = 204216 AND `id` = 207279;
DELETE FROM `gameobject_addon` WHERE `guid` = 204216;

-- Tarren Mill area: guid 204287 (207279) — replaced by Uber 990...2007
DELETE FROM `gameobject` WHERE `guid` = 204287 AND `id` = 207279;
DELETE FROM `gameobject_addon` WHERE `guid` = 204287;

-- Twilight Highlands Horde: guid 237379 (278347) — replaced by Uber 990...2013
DELETE FROM `gameobject` WHERE `guid` = 237379 AND `id` = 278347;
DELETE FROM `gameobject_addon` WHERE `guid` = 237379;

-- Badlands area Horde: guid 237524 (278347) — replaced by Uber 990...2014
DELETE FROM `gameobject` WHERE `guid` = 237524 AND `id` = 278347;
DELETE FROM `gameobject_addon` WHERE `guid` = 237524;

-- Hallowfall Horde: guid 210413467 (278347) — replaced by Uber 990...2018
DELETE FROM `gameobject` WHERE `guid` = 210413467 AND `id` = 278347;
DELETE FROM `gameobject_addon` WHERE `guid` = 210413467;

-- Orgrimmar: guid 171145 (206109) — replaced by Uber 990...2003
DELETE FROM `gameobject` WHERE `guid` = 171145 AND `id` = 206109;
DELETE FROM `gameobject_addon` WHERE `guid` = 171145;

-- Orgrimmar: guid 211334 (206109) — replaced by Uber 990...2008
DELETE FROM `gameobject` WHERE `guid` = 211334 AND `id` = 206109;
DELETE FROM `gameobject_addon` WHERE `guid` = 211334;

-- Thunder Bluff: guid 214905 (207323) — replaced by Uber 990...2009
DELETE FROM `gameobject` WHERE `guid` = 214905 AND `id` = 207323;
DELETE FROM `gameobject_addon` WHERE `guid` = 214905;

-- Silvermoon (Outland): guid 200628 (207325) — replaced by Uber 990...2004
DELETE FROM `gameobject` WHERE `guid` = 200628 AND `id` = 207325;
DELETE FROM `gameobject_addon` WHERE `guid` = 200628;

-- Dalaran (Northrend) Horde: guid 82 (208317) — replaced by Uber 990...2001
DELETE FROM `gameobject` WHERE `guid` = 82 AND `id` = 208317;
DELETE FROM `gameobject_addon` WHERE `guid` = 82;

-- Tol Barad Horde: guid 301169 (278347) — replaced by Uber 990...2016
DELETE FROM `gameobject` WHERE `guid` = 301169 AND `id` = 278347;
DELETE FROM `gameobject_addon` WHERE `guid` = 301169;

-- Draenor Horde: guid 210400013 (278457) — replaced by Uber 990...2017
DELETE FROM `gameobject` WHERE `guid` = 210400013 AND `id` = 278457;
DELETE FROM `gameobject_addon` WHERE `guid` = 210400013;

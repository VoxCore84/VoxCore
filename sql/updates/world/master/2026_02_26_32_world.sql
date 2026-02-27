-- SmartAI Fix: Unused action/event types, deprecated flags, broken links, misc
-- Auto-generated from DBErrors.log parsing

-- ============================================================
-- 1. Delete smart_scripts rows using deprecated/unused action types.
--    Action types: 18 (SET_UNIT_FLAG), 19 (REMOVE_UNIT_FLAG),
--    58 (INSTALL_AI_TEMPLATE), 75 (ADD_AURA), 93 (SEND_GO_CUSTOM_ANIM),
--    94/95/96 (DYNAMIC_FLAG), 104/105/106 (GO_FLAG), 122 (FLEE)
--    786 unique rows.
-- ============================================================

-- Batch delete by unused action_type values
DELETE FROM smart_scripts WHERE action_type IN (18, 19, 58, 75, 93, 94, 95, 96, 104, 105, 106, 122);

-- ============================================================
-- 2. Delete smart_scripts rows using deprecated/unused event types.
--    Event types: 12 (TARGET_HEALTH_PCT), 66 (EVENT_PHASE_CHANGE),
--    67 (IS_BEHIND_TARGET)
--    48 unique rows.
-- ============================================================

DELETE FROM smart_scripts WHERE event_type IN (12, 66, 67);

-- ============================================================
-- 3. Delete smart_scripts rows with out-of-range action types (>=160).
--    29 unique rows.
-- ============================================================

DELETE FROM smart_scripts WHERE action_type >= 160;

-- ============================================================
-- 4. Clear deprecated difficulty event flags (bits 0x02|0x04|0x08|0x10 = 0x1E).
--    These flags are deprecated and cause rows to be skipped.
--    6 unique rows.
-- ============================================================

-- Clear deprecated flag bits (mask 0x1E = 30) from all event_flags
UPDATE smart_scripts SET event_flags = event_flags & ~30
WHERE (event_flags & 30) != 0;

-- ============================================================
-- 5. Fix invalid event flags (values > 1023 = 0x3FF).
--    Mask to valid range to preserve valid bits.
--    8 unique rows.
-- ============================================================

-- Mask event_flags to valid range (0x3FF = 1023), keeping only valid bits
UPDATE smart_scripts SET event_flags = event_flags & 1023
WHERE event_flags > 1023;

-- ============================================================
-- 6. Add missing NOT_REPEATABLE flag (0x001) for events with no repeat
--    interval (repeatMin=0 AND repeatMax=0) that are not already flagged.
--    806 rows. The server auto-fixes these at load, but fixing in DB is cleaner.
-- ============================================================

-- For events with minMaxRepeat pattern: event_param3=repeatMin, event_param4=repeatMax
-- Event types: 0 (UPDATE_IC), 1 (UPDATE_OOC), 2 (HEALTH_PCT), 3 (MANA_PCT),
-- 9 (RANGE), 10 (OOC_LOS), 23 (HAS_AURA), 24 (TARGET_BUFFED), 26 (IC_LOS),
-- 32 (DAMAGED), 33 (DAMAGED_TARGET), 60 (UPDATE)
UPDATE smart_scripts
SET event_flags = event_flags | 1
WHERE event_type IN (0, 1, 2, 3, 9, 10, 23, 24, 26, 32, 33, 60)
AND event_param3 = 0 AND event_param4 = 0
AND (event_flags & 1) = 0
AND source_type != 9;  -- exclude timed actionlists

-- For VICTIM_CASTING (13): repeatMin=event_param1, repeatMax=event_param2
UPDATE smart_scripts
SET event_flags = event_flags | 1
WHERE event_type = 13
AND event_param1 = 0 AND event_param2 = 0
AND (event_flags & 1) = 0
AND source_type != 9;

-- For FRIENDLY_IS_CC (15): repeatMin=event_param2, repeatMax=event_param3
UPDATE smart_scripts
SET event_flags = event_flags | 1
WHERE event_type = 15
AND event_param2 = 0 AND event_param3 = 0
AND (event_flags & 1) = 0
AND source_type != 9;

-- ============================================================
-- 7. Delete orphaned SMART_EVENT_LINK rows (event_type=61) that have
--    no source event linking to them. These events will never trigger.
--    335 unique rows.
-- ============================================================

DELETE FROM smart_scripts WHERE entryorguid = -202778 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = -202777 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = -202776 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = -202775 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = -130968 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -129429 AND source_type = 0 AND id IN (8);
DELETE FROM smart_scripts WHERE entryorguid = -129428 AND source_type = 0 AND id IN (8);
DELETE FROM smart_scripts WHERE entryorguid = -127350 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -127349 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -119105 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = -119104 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = -111225 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = -111185 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = -107137 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = -107136 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = -107135 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = -106860 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -106859 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -106858 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -106857 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -106856 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -106855 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -104103 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -104097 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -104095 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -104055 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -104050 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -104049 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -104046 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -103931 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -95560 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -85118 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -85098 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = -78647 AND source_type = 0 AND id IN (1, 2);
DELETE FROM smart_scripts WHERE entryorguid = -78646 AND source_type = 0 AND id IN (1, 3);
DELETE FROM smart_scripts WHERE entryorguid = -78645 AND source_type = 0 AND id IN (1, 3);
DELETE FROM smart_scripts WHERE entryorguid = -78644 AND source_type = 0 AND id IN (1, 2);
DELETE FROM smart_scripts WHERE entryorguid = -78643 AND source_type = 0 AND id IN (1, 2);
DELETE FROM smart_scripts WHERE entryorguid = -78642 AND source_type = 0 AND id IN (1, 2);
DELETE FROM smart_scripts WHERE entryorguid = -74524 AND source_type = 0 AND id IN (7);
DELETE FROM smart_scripts WHERE entryorguid = -74523 AND source_type = 0 AND id IN (7);
DELETE FROM smart_scripts WHERE entryorguid = -74522 AND source_type = 0 AND id IN (7);
DELETE FROM smart_scripts WHERE entryorguid = -74515 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = -74514 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = -74513 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = -71999 AND source_type = 0 AND id IN (1, 7);
DELETE FROM smart_scripts WHERE entryorguid = -71998 AND source_type = 0 AND id IN (1, 7);
DELETE FROM smart_scripts WHERE entryorguid = -71997 AND source_type = 0 AND id IN (1, 7);
DELETE FROM smart_scripts WHERE entryorguid = 3584 AND source_type = 0 AND id IN (5, 9);
DELETE FROM smart_scripts WHERE entryorguid = 4048 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 4500 AND source_type = 0 AND id IN (7);
DELETE FROM smart_scripts WHERE entryorguid = 5697 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 7850 AND source_type = 0 AND id IN (5);
DELETE FROM smart_scripts WHERE entryorguid = 7997 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 8284 AND source_type = 0 AND id IN (1, 4);
DELETE FROM smart_scripts WHERE entryorguid = 8905 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 9537 AND source_type = 0 AND id IN (1, 10);
DELETE FROM smart_scripts WHERE entryorguid = 10610 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 10638 AND source_type = 0 AND id IN (5);
DELETE FROM smart_scripts WHERE entryorguid = 10803 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 10805 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 10992 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 11016 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 11064 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 12277 AND source_type = 0 AND id IN (1, 6);
DELETE FROM smart_scripts WHERE entryorguid = 12997 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 14323 AND source_type = 0 AND id IN (12);
DELETE FROM smart_scripts WHERE entryorguid = 14324 AND source_type = 0 AND id IN (13);
DELETE FROM smart_scripts WHERE entryorguid = 14325 AND source_type = 0 AND id IN (14);
DELETE FROM smart_scripts WHERE entryorguid = 14353 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 14467 AND source_type = 0 AND id IN (2, 8);
DELETE FROM smart_scripts WHERE entryorguid = 14688 AND source_type = 0 AND id IN (6, 8, 20);
DELETE FROM smart_scripts WHERE entryorguid = 14909 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 15277 AND source_type = 0 AND id IN (7);
DELETE FROM smart_scripts WHERE entryorguid = 15420 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 16027 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 16514 AND source_type = 0 AND id IN (6);
DELETE FROM smart_scripts WHERE entryorguid = 16844 AND source_type = 0 AND id IN (4, 15);
DELETE FROM smart_scripts WHERE entryorguid = 16857 AND source_type = 0 AND id IN (4, 15);
DELETE FROM smart_scripts WHERE entryorguid = 16968 AND source_type = 0 AND id IN (1, 6);
DELETE FROM smart_scripts WHERE entryorguid = 17556 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 17592 AND source_type = 0 AND id IN (11, 23);
DELETE FROM smart_scripts WHERE entryorguid = 17664 AND source_type = 0 AND id IN (11);
DELETE FROM smart_scripts WHERE entryorguid = 17702 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = 17725 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 17826 AND source_type = 0 AND id IN (14);
DELETE FROM smart_scripts WHERE entryorguid = 18069 AND source_type = 0 AND id IN (9, 19);
DELETE FROM smart_scripts WHERE entryorguid = 18678 AND source_type = 0 AND id IN (4, 14);
DELETE FROM smart_scripts WHERE entryorguid = 18948 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 18949 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 18950 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 18965 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 18970 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 18971 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 18972 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 18986 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 19616 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = 19720 AND source_type = 0 AND id IN (2, 17);
DELETE FROM smart_scripts WHERE entryorguid = 19725 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = 19726 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = 20071 AND source_type = 0 AND id IN (10);
DELETE FROM smart_scripts WHERE entryorguid = 20243 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 20454 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 20555 AND source_type = 0 AND id IN (8, 10);
DELETE FROM smart_scripts WHERE entryorguid = 20763 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 21057 AND source_type = 0 AND id IN (2, 5, 7);
DELETE FROM smart_scripts WHERE entryorguid = 21181 AND source_type = 0 AND id IN (7);
DELETE FROM smart_scripts WHERE entryorguid = 21315 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 21380 AND source_type = 0 AND id IN (7, 19);
DELETE FROM smart_scripts WHERE entryorguid = 21409 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 21410 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 21506 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 21685 AND source_type = 0 AND id IN (8);
DELETE FROM smart_scripts WHERE entryorguid = 21686 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = 21687 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 21849 AND source_type = 0 AND id IN (1, 6);
DELETE FROM smart_scripts WHERE entryorguid = 22423 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 22448 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 22458 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 22910 AND source_type = 0 AND id IN (1, 4);
DELETE FROM smart_scripts WHERE entryorguid = 23052 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 23053 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 23162 AND source_type = 0 AND id IN (2, 9);
DELETE FROM smart_scripts WHERE entryorguid = 23282 AND source_type = 0 AND id IN (10);
DELETE FROM smart_scripts WHERE entryorguid = 23285 AND source_type = 0 AND id IN (4, 15);
DELETE FROM smart_scripts WHERE entryorguid = 23364 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 23383 AND source_type = 0 AND id IN (1, 4);
DELETE FROM smart_scripts WHERE entryorguid = 23671 AND source_type = 0 AND id IN (2, 7, 18);
DELETE FROM smart_scripts WHERE entryorguid = 23899 AND source_type = 0 AND id IN (7, 9);
DELETE FROM smart_scripts WHERE entryorguid = 24016 AND source_type = 0 AND id IN (4, 7);
DELETE FROM smart_scripts WHERE entryorguid = 24041 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 24161 AND source_type = 0 AND id IN (5, 8);
DELETE FROM smart_scripts WHERE entryorguid = 24162 AND source_type = 0 AND id IN (4, 7);
DELETE FROM smart_scripts WHERE entryorguid = 24238 AND source_type = 0 AND id IN (26, 27);
DELETE FROM smart_scripts WHERE entryorguid = 24547 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 24806 AND source_type = 0 AND id IN (6);
DELETE FROM smart_scripts WHERE entryorguid = 25244 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 25451 AND source_type = 0 AND id IN (8);
DELETE FROM smart_scripts WHERE entryorguid = 25456 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 25618 AND source_type = 0 AND id IN (11, 19);
DELETE FROM smart_scripts WHERE entryorguid = 25625 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 25629 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 25644 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 25727 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 25729 AND source_type = 0 AND id IN (19, 28);
DELETE FROM smart_scripts WHERE entryorguid = 25732 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 25733 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 25751 AND source_type = 0 AND id IN (8);
DELETE FROM smart_scripts WHERE entryorguid = 25986 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 26073 AND source_type = 0 AND id IN (2, 6, 12);
DELETE FROM smart_scripts WHERE entryorguid = 26076 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 26117 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = 26452 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 26608 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = 26677 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 26772 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 26793 AND source_type = 0 AND id IN (6);
DELETE FROM smart_scripts WHERE entryorguid = 26811 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 26812 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 27102 AND source_type = 0 AND id IN (5);
DELETE FROM smart_scripts WHERE entryorguid = 27249 AND source_type = 0 AND id IN (5);
DELETE FROM smart_scripts WHERE entryorguid = 27383 AND source_type = 0 AND id IN (15, 20);
DELETE FROM smart_scripts WHERE entryorguid = 27439 AND source_type = 0 AND id IN (11);
DELETE FROM smart_scripts WHERE entryorguid = 27482 AND source_type = 0 AND id IN (4);
DELETE FROM smart_scripts WHERE entryorguid = 27788 AND source_type = 0 AND id IN (15);
DELETE FROM smart_scripts WHERE entryorguid = 27886 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 27888 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 27924 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 28083 AND source_type = 0 AND id IN (7);
DELETE FROM smart_scripts WHERE entryorguid = 28105 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 28136 AND source_type = 0 AND id IN (16);
DELETE FROM smart_scripts WHERE entryorguid = 28142 AND source_type = 0 AND id IN (16);
DELETE FROM smart_scripts WHERE entryorguid = 28148 AND source_type = 0 AND id IN (16);
DELETE FROM smart_scripts WHERE entryorguid = 28213 AND source_type = 0 AND id IN (5, 8, 10);
DELETE FROM smart_scripts WHERE entryorguid = 28416 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 28490 AND source_type = 0 AND id IN (5, 17);
DELETE FROM smart_scripts WHERE entryorguid = 28494 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 28495 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 28496 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 28541 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 28636 AND source_type = 0 AND id IN (5);
DELETE FROM smart_scripts WHERE entryorguid = 28639 AND source_type = 0 AND id IN (8);
DELETE FROM smart_scripts WHERE entryorguid = 28667 AND source_type = 0 AND id IN (2, 8, 12, 17);
DELETE FROM smart_scripts WHERE entryorguid = 28668 AND source_type = 0 AND id IN (2, 8, 12, 17);
DELETE FROM smart_scripts WHERE entryorguid = 28857 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 28902 AND source_type = 0 AND id IN (8);
DELETE FROM smart_scripts WHERE entryorguid = 28952 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 28961 AND source_type = 0 AND id IN (8);
DELETE FROM smart_scripts WHERE entryorguid = 28965 AND source_type = 0 AND id IN (10);
DELETE FROM smart_scripts WHERE entryorguid = 28988 AND source_type = 0 AND id IN (5);
DELETE FROM smart_scripts WHERE entryorguid = 29001 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 29007 AND source_type = 0 AND id IN (5);
DELETE FROM smart_scripts WHERE entryorguid = 29028 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 29626 AND source_type = 0 AND id IN (5);
DELETE FROM smart_scripts WHERE entryorguid = 29769 AND source_type = 0 AND id IN (10, 14, 18, 23);
DELETE FROM smart_scripts WHERE entryorguid = 29770 AND source_type = 0 AND id IN (10, 14, 18, 23);
DELETE FROM smart_scripts WHERE entryorguid = 29840 AND source_type = 0 AND id IN (10, 14, 18, 23);
DELETE FROM smart_scripts WHERE entryorguid = 30017 AND source_type = 0 AND id IN (1, 4);
DELETE FROM smart_scripts WHERE entryorguid = 30020 AND source_type = 0 AND id IN (1, 4);
DELETE FROM smart_scripts WHERE entryorguid = 30022 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 30023 AND source_type = 0 AND id IN (1, 4);
DELETE FROM smart_scripts WHERE entryorguid = 30081 AND source_type = 0 AND id IN (7);
DELETE FROM smart_scripts WHERE entryorguid = 30086 AND source_type = 0 AND id IN (7);
DELETE FROM smart_scripts WHERE entryorguid = 30162 AND source_type = 0 AND id IN (5);
DELETE FROM smart_scripts WHERE entryorguid = 30180 AND source_type = 0 AND id IN (7);
DELETE FROM smart_scripts WHERE entryorguid = 30331 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 30340 AND source_type = 0 AND id IN (7, 20);
DELETE FROM smart_scripts WHERE entryorguid = 30407 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 30484 AND source_type = 0 AND id IN (5);
DELETE FROM smart_scripts WHERE entryorguid = 30698 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 30736 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 30924 AND source_type = 0 AND id IN (1, 10);
DELETE FROM smart_scripts WHERE entryorguid = 31016 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 31029 AND source_type = 0 AND id IN (14);
DELETE FROM smart_scripts WHERE entryorguid = 31050 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 31077 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 32184 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 32236 AND source_type = 0 AND id IN (7);
DELETE FROM smart_scripts WHERE entryorguid = 32239 AND source_type = 0 AND id IN (6);
DELETE FROM smart_scripts WHERE entryorguid = 32331 AND source_type = 0 AND id IN (14);
DELETE FROM smart_scripts WHERE entryorguid = 33707 AND source_type = 0 AND id IN (10);
DELETE FROM smart_scripts WHERE entryorguid = 34102 AND source_type = 0 AND id IN (8);
DELETE FROM smart_scripts WHERE entryorguid = 37988 AND source_type = 0 AND id IN (6);
DELETE FROM smart_scripts WHERE entryorguid = 39215 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 46268 AND source_type = 0 AND id IN (5);
DELETE FROM smart_scripts WHERE entryorguid = 109316 AND source_type = 0 AND id IN (17);
DELETE FROM smart_scripts WHERE entryorguid = 121235 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 130919 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 165107 AND source_type = 0 AND id IN (3, 5);
DELETE FROM smart_scripts WHERE entryorguid = 166227 AND source_type = 0 AND id IN (8);
DELETE FROM smart_scripts WHERE entryorguid = 167424 AND source_type = 0 AND id IN (1, 6);
DELETE FROM smart_scripts WHERE entryorguid = 170179 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 181198 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 183770 AND source_type = 1 AND id IN (6);
DELETE FROM smart_scripts WHERE entryorguid = 183956 AND source_type = 1 AND id IN (6);
DELETE FROM smart_scripts WHERE entryorguid = 184311 AND source_type = 1 AND id IN (6);
DELETE FROM smart_scripts WHERE entryorguid = 184312 AND source_type = 1 AND id IN (6);
DELETE FROM smart_scripts WHERE entryorguid = 185882 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 186944 AND source_type = 1 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 187290 AND source_type = 0 AND id IN (2);
DELETE FROM smart_scripts WHERE entryorguid = 187700 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 188246 AND source_type = 0 AND id IN (3);
DELETE FROM smart_scripts WHERE entryorguid = 188601 AND source_type = 0 AND id IN (1, 3);
DELETE FROM smart_scripts WHERE entryorguid = 188972 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 189065 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 189089 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 189226 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 192674 AND source_type = 0 AND id IN (11);
DELETE FROM smart_scripts WHERE entryorguid = 193991 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 193995 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 194076 AND source_type = 0 AND id IN (1, 4);
DELETE FROM smart_scripts WHERE entryorguid = 194136 AND source_type = 0 AND id IN (1, 3);
DELETE FROM smart_scripts WHERE entryorguid = 194327 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 194394 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 195136 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 206428 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 206455 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 206468 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 206530 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 206571 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 207160 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 208907 AND source_type = 0 AND id IN (1);
DELETE FROM smart_scripts WHERE entryorguid = 215158 AND source_type = 0 AND id IN (1);

-- ============================================================
-- 8. Fix broken link references. DELETE rows where the linked event
--    doesn't exist in the same entry+source_type.
--    307 unique rows.
-- ============================================================

DELETE FROM smart_scripts WHERE entryorguid = -130968 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = -129429 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = -129428 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = -129427 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -129426 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -129425 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -129424 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -129423 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -129422 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -129421 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -129420 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -129419 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -129418 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -119105 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -119104 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -118282 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -111228 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = -111227 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = -111226 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = -111225 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = -111187 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = -111186 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = -111185 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = -106200 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = -102341 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -102333 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -102330 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -102329 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -102328 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -102327 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -102326 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -85829 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -85828 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -85827 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -85825 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -78647 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = -78644 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = -78643 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = -78642 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = -71999 AND source_type = 0 AND id = 2 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = -71999 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = -71998 AND source_type = 0 AND id = 2 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = -71998 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = -71997 AND source_type = 0 AND id = 2 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = -71997 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = -46610 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = -10999 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = -10998 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 3584 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 3584 AND source_type = 0 AND id = 5 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 3584 AND source_type = 0 AND id = 6 AND link = 8;
DELETE FROM smart_scripts WHERE entryorguid = 5644 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 7850 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 7917 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 8905 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 9537 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 9537 AND source_type = 0 AND id = 8 AND link = 9;
DELETE FROM smart_scripts WHERE entryorguid = 10610 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 10638 AND source_type = 0 AND id = 2 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 11016 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 11064 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 12277 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 14323 AND source_type = 0 AND id = 10 AND link = 11;
DELETE FROM smart_scripts WHERE entryorguid = 14325 AND source_type = 0 AND id = 9 AND link = 10;
DELETE FROM smart_scripts WHERE entryorguid = 14325 AND source_type = 0 AND id = 13 AND link = 15;
DELETE FROM smart_scripts WHERE entryorguid = 14467 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 14467 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 14688 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 14909 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 14912 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 15656 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 15958 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 16514 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 16514 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 16844 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 16844 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 16844 AND source_type = 0 AND id = 13 AND link = 14;
DELETE FROM smart_scripts WHERE entryorguid = 16857 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 16857 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 16857 AND source_type = 0 AND id = 13 AND link = 14;
DELETE FROM smart_scripts WHERE entryorguid = 16968 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 17664 AND source_type = 0 AND id = 9 AND link = 10;
DELETE FROM smart_scripts WHERE entryorguid = 17875 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 17892 AND source_type = 0 AND id = 19 AND link = 20;
DELETE FROM smart_scripts WHERE entryorguid = 17953 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 18069 AND source_type = 0 AND id = 20 AND link = 21;
DELETE FROM smart_scripts WHERE entryorguid = 18297 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 18678 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 18678 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 18678 AND source_type = 0 AND id = 12 AND link = 13;
DELETE FROM smart_scripts WHERE entryorguid = 18948 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 18949 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 18950 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 18965 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 18970 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 18971 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 18972 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 18986 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 19456 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 19482 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 19543 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 19544 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 19545 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 19546 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 19666 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 19720 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 19720 AND source_type = 0 AND id = 15 AND link = 16;
DELETE FROM smart_scripts WHERE entryorguid = 19725 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 19725 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 19726 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 19726 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 20071 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 20071 AND source_type = 0 AND id = 8 AND link = 9;
DELETE FROM smart_scripts WHERE entryorguid = 20206 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 20243 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 20555 AND source_type = 0 AND id = 2 AND link = 9;
DELETE FROM smart_scripts WHERE entryorguid = 20763 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 21057 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 21181 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 21380 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 21380 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 21380 AND source_type = 0 AND id = 17 AND link = 18;
DELETE FROM smart_scripts WHERE entryorguid = 21462 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 21633 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 21685 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 21685 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 21686 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 21687 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 21837 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 21849 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 22258 AND source_type = 0 AND id = 8 AND link = 9;
DELETE FROM smart_scripts WHERE entryorguid = 22423 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 22820 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 22870 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 23038 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 23042 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 23052 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 23053 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 23162 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 23282 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 23285 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 23285 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 23285 AND source_type = 0 AND id = 13 AND link = 14;
DELETE FROM smart_scripts WHERE entryorguid = 23364 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 23364 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 23671 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 23671 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 23671 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 23777 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 23899 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 23975 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 24016 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 24161 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 24162 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 24238 AND source_type = 0 AND id = 16 AND link = 18;
DELETE FROM smart_scripts WHERE entryorguid = 24238 AND source_type = 0 AND id = 22 AND link = 23;
DELETE FROM smart_scripts WHERE entryorguid = 24238 AND source_type = 0 AND id = 24 AND link = 25;
DELETE FROM smart_scripts WHERE entryorguid = 24238 AND source_type = 0 AND id = 27 AND link = 28;
DELETE FROM smart_scripts WHERE entryorguid = 24514 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 24806 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 24972 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 25220 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 25453 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 25453 AND source_type = 0 AND id = 10 AND link = 11;
DELETE FROM smart_scripts WHERE entryorguid = 25618 AND source_type = 0 AND id = 16 AND link = 17;
DELETE FROM smart_scripts WHERE entryorguid = 25729 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 25729 AND source_type = 0 AND id = 26 AND link = 27;
DELETE FROM smart_scripts WHERE entryorguid = 25765 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 25783 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 25986 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 26073 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 26073 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 26076 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 26287 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 26379 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 26608 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 26608 AND source_type = 0 AND id = 7 AND link = 8;
DELETE FROM smart_scripts WHERE entryorguid = 26793 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 26793 AND source_type = 0 AND id = 8 AND link = 9;
DELETE FROM smart_scripts WHERE entryorguid = 26811 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 26812 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 27002 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 27213 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 27249 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 27292 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 27383 AND source_type = 0 AND id = 12 AND link = 13;
DELETE FROM smart_scripts WHERE entryorguid = 27439 AND source_type = 0 AND id = 9 AND link = 10;
DELETE FROM smart_scripts WHERE entryorguid = 27693 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 27788 AND source_type = 0 AND id = 13 AND link = 14;
DELETE FROM smart_scripts WHERE entryorguid = 27939 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 27959 AND source_type = 0 AND id = 9 AND link = 10;
DELETE FROM smart_scripts WHERE entryorguid = 28083 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 28083 AND source_type = 0 AND id = 20 AND link = 21;
DELETE FROM smart_scripts WHERE entryorguid = 28105 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 28136 AND source_type = 0 AND id = 14 AND link = 15;
DELETE FROM smart_scripts WHERE entryorguid = 28142 AND source_type = 0 AND id = 14 AND link = 15;
DELETE FROM smart_scripts WHERE entryorguid = 28148 AND source_type = 0 AND id = 14 AND link = 15;
DELETE FROM smart_scripts WHERE entryorguid = 28175 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 28213 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 28244 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 28399 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 28494 AND source_type = 0 AND id = 7 AND link = 8;
DELETE FROM smart_scripts WHERE entryorguid = 28495 AND source_type = 0 AND id = 8 AND link = 9;
DELETE FROM smart_scripts WHERE entryorguid = 28496 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 28541 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 28636 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 28667 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 28667 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 28667 AND source_type = 0 AND id = 10 AND link = 11;
DELETE FROM smart_scripts WHERE entryorguid = 28667 AND source_type = 0 AND id = 15 AND link = 16;
DELETE FROM smart_scripts WHERE entryorguid = 28668 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 28668 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 28668 AND source_type = 0 AND id = 10 AND link = 11;
DELETE FROM smart_scripts WHERE entryorguid = 28668 AND source_type = 0 AND id = 15 AND link = 16;
DELETE FROM smart_scripts WHERE entryorguid = 28671 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 28902 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 28902 AND source_type = 0 AND id = 9 AND link = 10;
DELETE FROM smart_scripts WHERE entryorguid = 28902 AND source_type = 0 AND id = 11 AND link = 10;
DELETE FROM smart_scripts WHERE entryorguid = 28952 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 28988 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 29050 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 29614 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 29621 AND source_type = 0 AND id = 22 AND link = 23;
DELETE FROM smart_scripts WHERE entryorguid = 29626 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 29769 AND source_type = 0 AND id = 6 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 29769 AND source_type = 0 AND id = 8 AND link = 9;
DELETE FROM smart_scripts WHERE entryorguid = 29769 AND source_type = 0 AND id = 12 AND link = 13;
DELETE FROM smart_scripts WHERE entryorguid = 29769 AND source_type = 0 AND id = 14 AND link = 15;
DELETE FROM smart_scripts WHERE entryorguid = 29770 AND source_type = 0 AND id = 6 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 29770 AND source_type = 0 AND id = 8 AND link = 9;
DELETE FROM smart_scripts WHERE entryorguid = 29770 AND source_type = 0 AND id = 12 AND link = 13;
DELETE FROM smart_scripts WHERE entryorguid = 29770 AND source_type = 0 AND id = 14 AND link = 15;
DELETE FROM smart_scripts WHERE entryorguid = 29801 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 29840 AND source_type = 0 AND id = 6 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 29840 AND source_type = 0 AND id = 8 AND link = 9;
DELETE FROM smart_scripts WHERE entryorguid = 29840 AND source_type = 0 AND id = 12 AND link = 13;
DELETE FROM smart_scripts WHERE entryorguid = 29840 AND source_type = 0 AND id = 14 AND link = 15;
DELETE FROM smart_scripts WHERE entryorguid = 29919 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 29919 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 30017 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 30019 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 30023 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 30024 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 30025 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 30026 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 30081 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 30086 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 30152 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 30162 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 30180 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 30331 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 30340 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 30340 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 30340 AND source_type = 0 AND id = 18 AND link = 19;
DELETE FROM smart_scripts WHERE entryorguid = 30340 AND source_type = 0 AND id = 24 AND link = 25;
DELETE FROM smart_scripts WHERE entryorguid = 30484 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 30698 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 30993 AND source_type = 0 AND id = 13 AND link = 14;
DELETE FROM smart_scripts WHERE entryorguid = 31029 AND source_type = 0 AND id = 12 AND link = 13;
DELETE FROM smart_scripts WHERE entryorguid = 31432 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 32236 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 32239 AND source_type = 0 AND id = 4 AND link = 5;
DELETE FROM smart_scripts WHERE entryorguid = 33235 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 33707 AND source_type = 0 AND id = 8 AND link = 9;
DELETE FROM smart_scripts WHERE entryorguid = 33785 AND source_type = 0 AND id = 7 AND link = 8;
DELETE FROM smart_scripts WHERE entryorguid = 33956 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 33957 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 34102 AND source_type = 0 AND id = 6 AND link = 7;
DELETE FROM smart_scripts WHERE entryorguid = 34102 AND source_type = 0 AND id = 18 AND link = 19;
DELETE FROM smart_scripts WHERE entryorguid = 34184 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 34920 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 34920 AND source_type = 0 AND id = 5 AND link = 6;
DELETE FROM smart_scripts WHERE entryorguid = 34920 AND source_type = 0 AND id = 15 AND link = 16;
DELETE FROM smart_scripts WHERE entryorguid = 34920 AND source_type = 0 AND id = 20 AND link = 21;
DELETE FROM smart_scripts WHERE entryorguid = 35321 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 36287 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 36288 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 36289 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 36624 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 36642 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 46268 AND source_type = 0 AND id = 3 AND link = 4;
DELETE FROM smart_scripts WHERE entryorguid = 101677 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 166227 AND source_type = 0 AND id = 2 AND link = 3;
DELETE FROM smart_scripts WHERE entryorguid = 172377 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174554 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174555 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174556 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174557 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174558 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174559 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174560 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174561 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174562 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174563 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174564 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 174566 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 185882 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 192674 AND source_type = 0 AND id = 8 AND link = 9;
DELETE FROM smart_scripts WHERE entryorguid = 193025 AND source_type = 1 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 194076 AND source_type = 0 AND id = 1 AND link = 2;
DELETE FROM smart_scripts WHERE entryorguid = 199863 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 199876 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 200046 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 202693 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 202696 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 203011 AND source_type = 0 AND id = 0 AND link = 1;
DELETE FROM smart_scripts WHERE entryorguid = 250839 AND source_type = 0 AND id = 0 AND link = 1;

-- ============================================================
-- 9. Delete smart_scripts rows with invoker target but no invoker event.
--    28 unique rows.
-- ============================================================

DELETE FROM smart_scripts WHERE entryorguid = 453 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 1888 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 2570 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 5199 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 5200 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 5982 AND source_type = 0 AND id = 12;
DELETE FROM smart_scripts WHERE entryorguid = 7154 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 7797 AND source_type = 0 AND id = 12;
DELETE FROM smart_scripts WHERE entryorguid = 9447 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 9450 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 16017 AND source_type = 0 AND id = 12;
DELETE FROM smart_scripts WHERE entryorguid = 16519 AND source_type = 0 AND id = 12;
DELETE FROM smart_scripts WHERE entryorguid = 32855 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 36012 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 37988 AND source_type = 0 AND id = 40;
DELETE FROM smart_scripts WHERE entryorguid = 41592 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 41608 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 42453 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 46841 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 61239 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 61339 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 62538 AND source_type = 0 AND id = 52;
DELETE FROM smart_scripts WHERE entryorguid = 100429 AND source_type = 0 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 107289 AND source_type = 0 AND id = 52;
DELETE FROM smart_scripts WHERE entryorguid = 126478 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 185882 AND source_type = 0 AND id = 40;
DELETE FROM smart_scripts WHERE entryorguid = 9100174 AND source_type = 0 AND id = 14;
DELETE FROM smart_scripts WHERE entryorguid = 9100208 AND source_type = 0 AND id = 14;

-- ============================================================
-- 10. Delete all smart_scripts for non-existent AreaTrigger entries.
--     18 AreaTrigger entries.
-- ============================================================

DELETE FROM smart_scripts WHERE entryorguid IN (2246, 2248, 2250, 2252, 2626, 2627, 2628, 2629, 2630, 2631, 2632, 2633, 2634, 2635, 2636, 2637, 4354, 174843) AND source_type IN (2, 10, 11);

-- ============================================================
-- 11. Delete smart_scripts rows with min > max parameter values.
--     23 unique rows.
-- ============================================================

DELETE FROM smart_scripts WHERE entryorguid = 37112 AND source_type = 0 AND id = 2;
DELETE FROM smart_scripts WHERE entryorguid = 58769 AND source_type = 0 AND id = 2;
DELETE FROM smart_scripts WHERE entryorguid = 68392 AND source_type = 0 AND id = 10008;
DELETE FROM smart_scripts WHERE entryorguid = 68392 AND source_type = 0 AND id = 10010;
DELETE FROM smart_scripts WHERE entryorguid = 134084 AND source_type = 0 AND id = 10000;
DELETE FROM smart_scripts WHERE entryorguid = 134193 AND source_type = 0 AND id = 10000;
DELETE FROM smart_scripts WHERE entryorguid = 134195 AND source_type = 0 AND id = 10000;
DELETE FROM smart_scripts WHERE entryorguid = 136715 AND source_type = 0 AND id = 10000;
DELETE FROM smart_scripts WHERE entryorguid = 137807 AND source_type = 0 AND id = 10000;
DELETE FROM smart_scripts WHERE entryorguid = 146552 AND source_type = 0 AND id = 10000;
DELETE FROM smart_scripts WHERE entryorguid = 164506 AND source_type = 0 AND id = 1;
DELETE FROM smart_scripts WHERE entryorguid = 166299 AND source_type = 0 AND id = 1;
DELETE FROM smart_scripts WHERE entryorguid = 167111 AND source_type = 0 AND id = 1;
DELETE FROM smart_scripts WHERE entryorguid = 167965 AND source_type = 0 AND id = 1;
DELETE FROM smart_scripts WHERE entryorguid = 168718 AND source_type = 0 AND id = 4;
DELETE FROM smart_scripts WHERE entryorguid = 9100174 AND source_type = 0 AND id = 10006;
DELETE FROM smart_scripts WHERE entryorguid = 9100174 AND source_type = 0 AND id = 10007;
DELETE FROM smart_scripts WHERE entryorguid = 9100174 AND source_type = 0 AND id = 10008;
DELETE FROM smart_scripts WHERE entryorguid = 9100174 AND source_type = 0 AND id = 10010;
DELETE FROM smart_scripts WHERE entryorguid = 9100208 AND source_type = 0 AND id = 10006;
DELETE FROM smart_scripts WHERE entryorguid = 9100208 AND source_type = 0 AND id = 10007;
DELETE FROM smart_scripts WHERE entryorguid = 9100208 AND source_type = 0 AND id = 10008;
DELETE FROM smart_scripts WHERE entryorguid = 9100208 AND source_type = 0 AND id = 10010;

-- ============================================================
-- 12. Delete smart_scripts rows with quest flag validation errors.
--     7 unique rows.
-- ============================================================

DELETE FROM smart_scripts WHERE entryorguid = 25729 AND source_type = 0 AND id = 20;
DELETE FROM smart_scripts WHERE entryorguid = 27383 AND source_type = 0 AND id = 19;
DELETE FROM smart_scripts WHERE entryorguid = 27439 AND source_type = 0 AND id = 10;
DELETE FROM smart_scripts WHERE entryorguid = 44084 AND source_type = 0 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 2520802 AND source_type = 9 AND id = 4;
DELETE FROM smart_scripts WHERE entryorguid = 2558902 AND source_type = 9 AND id = 2;
DELETE FROM smart_scripts WHERE entryorguid = 2664801 AND source_type = 9 AND id = 0;

-- ============================================================
-- 13. Delete smart_scripts where event type is incompatible with script type.
--     4 unique entry+source_type combos.
-- ============================================================

DELETE FROM smart_scripts WHERE entryorguid = 35650 AND source_type = 0;
DELETE FROM smart_scripts WHERE entryorguid = 35875 AND source_type = 0;
DELETE FROM smart_scripts WHERE entryorguid = 35893 AND source_type = 0;
DELETE FROM smart_scripts WHERE entryorguid = 9107773 AND source_type = 12;

-- ============================================================
-- 14. Delete smart_scripts with invalid conversation entries.
--     4 unique rows.
-- ============================================================

DELETE FROM smart_scripts WHERE entryorguid = 65436 AND source_type = 5 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 90759 AND source_type = 5 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 93127 AND source_type = 0 AND id = 12;
DELETE FROM smart_scripts WHERE entryorguid = 250839 AND source_type = 0 AND id = 1;

-- ============================================================
-- 15. Delete smart_scripts with invalid boolean transport param.
--     6 unique rows.
-- ============================================================

DELETE FROM smart_scripts WHERE entryorguid = 3113500 AND source_type = 9 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 3113501 AND source_type = 9 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 3113502 AND source_type = 9 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 3113503 AND source_type = 9 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 3113504 AND source_type = 9 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 3113505 AND source_type = 9 AND id = 0;

-- ============================================================
-- 16. Delete smart_scripts with invalid hostilityMode value.
--     5 unique rows.
-- ============================================================

DELETE FROM smart_scripts WHERE entryorguid = 81773 AND source_type = 0 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 100851 AND source_type = 0 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 100853 AND source_type = 0 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 100854 AND source_type = 0 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 102661 AND source_type = 0 AND id = 0;

-- ============================================================
-- 17. Delete smart_scripts with out-of-range target orientation.
--     5 unique rows.
-- ============================================================

DELETE FROM smart_scripts WHERE entryorguid = 38695 AND source_type = 5 AND id = 11006;
DELETE FROM smart_scripts WHERE entryorguid = 75637 AND source_type = 5 AND id = 11006;
DELETE FROM smart_scripts WHERE entryorguid = 138097 AND source_type = 0 AND id = 1;
DELETE FROM smart_scripts WHERE entryorguid = 139519 AND source_type = 0 AND id = 1;
DELETE FROM smart_scripts WHERE entryorguid = 9000904 AND source_type = 1 AND id = 0;

-- ============================================================
-- 18. Misc remaining errors (19 entries)
-- ============================================================

-- Event id 255 does not exist (event_type >= SMART_EVENT_END)
-- Event id 255 does not exist (event_type >= SMART_EVENT_END)
DELETE FROM smart_scripts WHERE entryorguid = 17826 AND source_type = 0 AND id = 10;
DELETE FROM smart_scripts WHERE entryorguid = 22448 AND source_type = 0 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 26608 AND source_type = 0 AND id = 3;
DELETE FROM smart_scripts WHERE entryorguid = 46230 AND source_type = 0 AND id = 2;
DELETE FROM smart_scripts WHERE entryorguid = 219950 AND source_type = 0 AND id = 0;
DELETE FROM smart_scripts WHERE entryorguid = 1835100 AND source_type = 9 AND id = 3;
DELETE FROM smart_scripts WHERE entryorguid = 2244801 AND source_type = 9 AND id = 5;
DELETE FROM smart_scripts WHERE entryorguid = 2598300 AND source_type = 9 AND id = 1;
-- WARNING (info only): SmartAIMgr: Entry 3706500 SourceType 9 Event 1 Action 50 gameobject summon: There is a summon spell for gameobject entry 201891 (SpellId: 70511, effect: 0)
DELETE FROM smart_scripts WHERE entryorguid = 9100174 AND source_type = 0 AND id = 3;
DELETE FROM smart_scripts WHERE entryorguid = 9100218 AND source_type = 5 AND id = 11011;
DELETE FROM smart_scripts WHERE entryorguid = 9100218 AND source_type = 5 AND id = 11012;
DELETE FROM smart_scripts WHERE entryorguid = 9100218 AND source_type = 5 AND id = 11013;
DELETE FROM smart_scripts WHERE entryorguid = 9100580 AND source_type = 0 AND id = 103;
DELETE FROM smart_scripts WHERE entryorguid = 9107942 AND source_type = 12 AND id = 3;
DELETE FROM smart_scripts WHERE entryorguid = 9942700 AND source_type = 9 AND id = 10;
DELETE FROM smart_scripts WHERE entryorguid = 12939100 AND source_type = 9 AND id = 11;

-- Delete rows with out-of-range event_type (>= 91 = SMART_EVENT_END)
DELETE FROM smart_scripts WHERE event_type >= 91;

-- ============================================================
-- NOTE: The following error categories are WARNINGS only and do
-- not cause rows to be skipped. No SQL fix needed:
--   - SPELL_EFFECT_KILL_CREDIT invalid target (3162 warnings)
--   - Kill Credit spell exists for creature (2467 warnings)
--   - Summon spell exists for creature entry (43 warnings)
--   - Create Item spell exists for item (18 warnings)
--   - SMARTCAST_WAIT_FOR_HIT without ACTIONLIST_WAITS (3 warnings)
-- These are informational and the scripts still function.
-- ============================================================

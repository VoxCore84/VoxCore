-- SmartAI Fix: Invalid quest objectives and non-existent waypoint paths
-- Auto-generated from DBErrors.log parsing
-- Total errors addressed: ~47,937 (47,138 quest obj + 799 waypoint)

-- ============================================================
-- 1. Delete smart_scripts with event_type=48 (QUEST_OBJ_COMPLETION)
--    referencing non-existent quest_objectives IDs.
--    47,138 rows: 47,130 with event_param1=0, 8 with other bad IDs.
--    These are all source_type=5 (quest scripts) from LoreWalkerTDB import.
-- ============================================================

DELETE FROM smart_scripts
WHERE event_type = 48  -- SMART_EVENT_QUEST_OBJ_COMPLETION
AND event_param1 NOT IN (SELECT ID FROM quest_objectives);

-- ============================================================
-- 2. Delete smart_scripts rows that reference non-existent waypoint paths.
--    action_type=53 (WP_START) where action_param1 not in waypoint_path.PathId.
--    799 errors across 757 unique PathIds.
-- ============================================================

DELETE ss FROM smart_scripts ss
LEFT JOIN waypoint_path wp ON wp.PathId = ss.action_param1
WHERE ss.action_type = 53  -- SMART_ACTION_WP_START
AND wp.PathId IS NULL;

-- Also clean up action_type=113 (START_CLOSEST_WAYPOINT) with bad paths
-- These reference waypoint paths in action_param1 through action_param7
-- Only delete if ALL referenced paths are invalid (conservative approach)


# SmartAI Quick Reference

Source: `src/server/game/AI/SmartScripts/SmartScriptMgr.h` and `.cpp`

## Key Tables
- `smart_scripts` — all SmartAI data
- `creature_text` — text groups (CreatureID, GroupID)
- `waypoint_path` — PathId column (NOT waypoint_data)
- `quest_objectives` — ID column

## Source Types (source_type column)
- 0 = CREATURE (positive entryorguid = entry, negative = -guid)
- 1 = GAMEOBJECT
- 2 = AREATRIGGER
- 5 = EVENT (timed action lists reference this via entryorguid)
- 9 = TIMED_ACTIONLIST
- 10 = SCENE
- 12 = AREATRIGGER_ENTITY

## Deprecated Event Types (delete on sight)
12, 14, 18, 30, 39, 66, 67
**NOTE**: Event type 47 (`SMART_EVENT_QUEST_ACCEPTED`) is **SUPPORTED** — has case handler in ProcessEvent(). Do NOT delete.

## Deprecated Action Types (delete on sight)
15, 18, 19, 26, 58, 61, 75, 76, 77, 93, 94, 95, 96, 104, 105, 106, 119, 120, 121, 122, 126

## Spell Validation for SmartAI
- Cast actions (11, 85, 86, 134): validate `action_param1` (spell ID) against `hotfixes.spell_name` + `world.serverside_spell`
- Use `NOT EXISTS` (not JOIN) due to composite PK on spell_name `(ID, VerifiedBuild)`

## Deprecated Event Flags
Bitmask 0x1E (bits 0x02|0x04|0x08|0x10) = old difficulty flags. Clear with `event_flags & ~0x1E`.

## Event/Action Boundaries
- Valid event types: 0-90 (SMART_EVENT_END = 91)
- Valid action types: 1-159 (SMART_ACTION_END = 160)

## Key Action Types
- 1 = TALK (action_param1 = text group, action_param2 = useTalkTarget)
- 11 = CAST (action_param1 = spellID)
- 53 = WP_START (action_param1 = run, action_param2 = pathID)
- 80 = CALL_TIMED_ACTIONLIST (action_param3 = allowOverride, boolean)
- 84 = SIMPLE_TALK (action_param1 = text group)
- 85 = SELF_CAST (action_param1 = spellID)
- 86 = CROSS_CAST (action_param1 = spellID)
- 134 = INVOKER_CAST (action_param1 = spellID)

## Key Event Types
- 8 = SPELLHIT (event_param1 = spellID)
- 13 = VICTIM_CASTING (repeat: event_param1/param2)
- 15 = FRIENDLY_IS_CC (repeat: event_param2/param3)
- 22 = SPELLHIT_TARGET (event_param1 = spellID)
- 23 = HAS_AURA (repeat: event_param3/param4)
- 24 = TARGET_BUFFED (repeat: event_param3/param4)
- 48 = QUEST_OBJ_COMPLETION (event_param1 = objective ID)
- 61 = LINK (internal, links chains together)
- 83-85 = ON_SPELL_CAST/FAILED/START (event_param1 = spellID)
- 89-90 = ON_AURA_APPLIED/REMOVED (event_param1 = spellID)

## Link Chain Mechanics
- Row with `link != 0` expects a target row with `id == link` AND `event_type == 61`
- Deleting broken links cascades — need multiple passes (observed depth: ~8 levels)
- Also clean orphaned event_type=61 rows where no row links to them

## Missing Repeat Flag
Events 13, 15, 23, 24: if repeat min/max are both 0 and NOT_REPEATABLE flag (0x01) is missing,
server auto-adds the flag and logs an error. Fix: `SET event_flags = event_flags | 0x01`.
Exclude source_type = 9 (timed action lists).

## Boolean Validation
`TC_SAI_IS_BOOLEAN_VALID` macro rejects any value > 1. Common fields:
- action_type 80, action_param3 (allowOverride)
- action_type 1, action_param2 (useTalkTarget)
- action_type 53, action_param1 (run)
- event_type 9, event_param1 (playerOnly)

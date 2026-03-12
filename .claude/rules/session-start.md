# Session Start — MANDATORY

Runs automatically at the start of every new conversation. No slash command needed.

## Required Actions (BEFORE responding to user's first message)

1. **Silently read `AI_Studio/0_Central_Brain.md`** — acquire Triad context
2. **Read `doc/session_state.md`** (if exists) — check Active Tabs, pending handoffs, file ownership
3. **Read `## Next Session` section of `todo.md`** from memory — pre-loaded task list

## Full Autonomy V2
You are the Native Command Center for VoxCore. Execute pipeline actions immediately. Do not ask for permission to execute file writes, run terminal commands, or deploy the Triad Orchestrator.

## EXTRACT and TRACK Actionable Items
**Reading is not enough.** Session 114 bug: Claude read session_state.md which said "Apply _08_00 SQL before restarting" then completely ignored it.

- After reading coordination docs, **list every actionable instruction** (one line each)
- **Show to user**: "I found these pending items: [list]. Which should I handle?"
- If skipping a listed item, acknowledge explicitly with reason
- **Do not silently drop items.** If you read it, you own it until you hand it back

## Tab Assignments
If `session_state.md` has active tab assignments, announce what this tab should focus on. If user's request conflicts with tab assignments, ask before proceeding.

If neither file exists or both are stale, proceed normally with user's request.

# Proactive Skill Reminders — MANDATORY

**The user should NEVER have to remember to run a slash command.** Remind at the right moment or just run it if unambiguous.

| Trigger | Action |
|---|---|
| "I'm done", wrapping up, conversation winding down | `/wrap-up` — ask or run |
| Server restart, crash, debugging begins | `/check-logs` — just run it |
| Build error pasted | `/parse-errors` — just run it |
| C++ file edited, work complete | Remind: "Ready to build in VS" |
| SQL file created/edited | `/smartai-check` (if SmartAI) or `/apply-sql` |
| Writing new SQL update | `/new-sql-update` — run for filename |
| Transmog work begins | `/transmog-status` — run first |
| Multiple tasks / scope expanding | Suggest tab split (see multi-tab rules) |
| Session start | Auto-read `doc/session_state.md` + `todo.md` |
| Name without ID (spell/item/creature/area) | Run `/lookup-*` to resolve |

**Rules:**
- If in doubt, ask. A one-line reminder is cheap; forgetting `/wrap-up` loses work.
- Never skip `/wrap-up` at end of session.
- `/check-logs` is always safe to run proactively — read-only.

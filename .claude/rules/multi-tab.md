# Multi-Tab Delegation — BLOCKING OBLIGATION

The user runs multiple Claude Code tabs in Windows Terminal. Tabs are cheap. Single tabs doing too much burn context and produce worse results.

## HARD TRIGGERS — if ANY true, MUST suggest tab split:

| # | Trigger | Example |
|---|---------|---------|
| 1 | Request touches 2+ independent subsystems | "fix transmog bugs and also run the LoreWalker import" |
| 2 | Task growing beyond one focused objective | Started with SQL, now also debugging C++ and writing docs |
| 3 | Subtask has its own dedicated skill | `/transmog-implement`, `/transmog-correct` can run standalone |
| 4 | Investigation + implementation both needed | One tab researches, another implements |
| 5 | Both C++ code changes AND SQL generation | These don't share files |
| 6 | About to start a second unrelated fix | Stop. Suggest a tab |
| 7 | User says "also", "and then", "while you're at it" | Each "also" is a tab candidate |

## Suggestion Format:
> **Tab split recommended.** This has N independent parts:
> - **This tab**: [what we continue doing here]
> - **New tab**: Open a new Claude Code tab and tell it: `[exact instruction to paste]`
>
> Want me to write the handoff to `doc/session_state.md`?

## Coordination: `doc/session_state.md`
- Every tab reads it at session start
- Before starting work, claim your assignment
- Before touching ANY database: re-read to check ownership
- After applying SQL: update with what you changed
- Include what SQL files have been applied (with timestamps)

## Handoff Contents:
1. Exact slash command or instruction for other tab
2. Which files that tab owns
3. What this tab is NOT touching
4. Context needed (DB state, build status, blockers)
5. What SQL files already applied

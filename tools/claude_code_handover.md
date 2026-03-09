# Claude Code Context Handover & Version Control Protocol

**Trigger:** Execute this prompt after `stop_all.bat` has been run and Antigravity has completed its code modifications. Your primary job is Version Control and Memory Syncing.

## 1. Context Ingestion
1. Read `C:\Users\atayl\VoxCore\out\build\x64-RelWithDebInfo\bin\RelWithDebInfo\PacketLog\timeline.txt` and `.auto_parse_seen.json`.
2. Review the diffs of any files modified during this session.
3. Read `doc/session_state.md` and `doc/todo.md` to understand what tasks were mapped out.

## 2. Memory Synchronization
Update your internal memory file (`doc/claude_memory.md` or similar) with:
- What bugs were encountered in this session (extract from `PacketLog/crashes.txt` and `db_errors_summary.txt`).
- Which files Antigravity successfully patched.
- Any unresolved anomalies observed in the logs.

## 3. Version Control (Automated Commit & Push)
Perform the following git operations autonomously:
1. `git status` -> review staged/unstaged changes.
2. `git add .` (exclude log folders or unnecessary binaries).
3. Write a highly semantic, detailed commit message. The commit message MUST include:
   - A high-level summary of the bug fix or feature.
   - Specific C++ or SQL files modified.
   - Evidence/Crash signature that was fixed (referencing `PacketLog`).
4. `git commit -m "Semantic Message"`
5. `git push origin main` (or the active branch).

## 4. Documentation Cleanup
1. Mark completed items in `doc/todo.md` as done.
2. Clear out `doc/session_state.md` to prepare for the next clean boot.

---
**Goal:** You act as the Lead DevOps Engineer. You summarize the chaos, document the patches, and mathematically seal the repository so the main user (`atayl`) never has to type `git commit` or manage task boards manually again.

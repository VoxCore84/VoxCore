---
description: Wrap-up Session - Comprehensive Antigravity End-of-Session Cleanup
---
# Antigravity `/wrap-up` Workflow

Run this workflow whenever the user asks you to "wrap up" or execute the `/wrap-up` command at the end of a session.

**IMPORTANT NOTE FOR ANTIGRAVITY**: You are capable of parallel execution and background tasks, unlike Claude Code. Do not run destructive shell commands without following your `.agentrules` protocol for system permissions. 

**// turbo-all**
(Auto-run all non-destructive git and sync read operations in this workflow)

## Step 1: Assess State
- Run `git status --porcelain`
- Run `git log --oneline -5`
- Run `git diff --stat`
- Run `git diff --cached --stat`
- *Decision*: If there are **no uncommitted changes** in the repository, skip to Step 3. Otherwise, proceed to Step 2.

## Step 2: Commit and Push
- Review the `git status` output.
- **Rules**: 
  - NEVER stage or commit build artifacts, credentials, or `.env` files. Ensure you respect `.gitignore`.
  - Do NOT stage untracked files unless they were explicitly created during this exact session.
- Run `git add [specific files]` for modified/added files. 
- Formulate a precise, descriptive commit message based on your `git diff` analysis. 
- Run `git commit -m "Your generated message"` (or use the one provided by the user).
- Run `git push origin HEAD` (unless the user explicitly told you "no push").

## Step 3: Sync Bridge
- Run the bridge synchronization script so the external Cowork AI (like Claude Desktop) gets the latest database state.
- Command: `python tools/sync_bridge.py --full` (or `pwsh -c "python tools/sync_bridge.py --full"`).
- *Note*: If this step fails, it is **non-blocking**. Note the failure in the final report, but continue.

## Step 4: Check Gists
- Use your native `view_file` tool to inspect the 5 core gist trackers (e.g., `doc/gist_changelog.md`, `doc/gist_db_report.md`, `doc/gist_open_issues.md`).
- *Decision*: Determine if the information in these markdown files is stale compared to the work done in this session.
- **Rule**: Do NOT auto-push the gists. If any are stale, note them in the final report so the user can manually sync them later.

## Step 5: Update Memory Files
Use your native `replace_file_content` tool to update the following files:
1. `MEMORY.md`: Update ONLY if structural architectural changes were made (e.g., a new system, config rule, or tool was introduced).
2. `cowork/context/recent-work.md` (or the local equivalent): Add a new session entry. Include: [Date], [Session Number], [Feature Title], and [Commit Hash].
3. `cowork/context/todo.md` (or `doc/todo.md`): Strike through `~~completed items~~`. Add any new discoveries under the appropriate HIGH/MEDIUM/LOW/BLOCKED section.
4. `doc/session_state.md`: 
   - Update your specific Tab's row in the `Active Tabs & Assignments` table to `COMPLETE`.
   - Update the "Current Server State" section if you generated a build or changed database rows.
   - Adjust Tier items if you resolved a bug.

## Step 6: Next Session Suggestions
- Edit the `## Next Session` section in `todo.md`.
- Replace the existing contents with up to 10 fresh, actionable bullet points. 
- Base these on uncommitted changes, unblocked dependencies, or the highest priority items from the HIGH list.

## Step 7: Final Session Summary (Report)
Generate a markdown response back to the user formatted exactly like this:

### 🏆 What We Did
- **[Category Title]**: Provide a numbered list of major accomplishments.
- **[Category Title]**: Include quantitative results (e.g., "Deleted 523 rows", "Reduced execution time by 4s").
- Mention specific files created or edited.

### 📊 Operational Summary
- **Committed**: `[Commit Hash]`
- **Pushed**: `[Branch Name]` (or "Skipped")
- **Sync Bridge**: `[Success / Failed]`
- **Gists**: `[List of files that need manual syncing, or "All up to date"]`
- **Memory**: `[Brief list of what was changed in todo.md/session_state.md]`
- **Next Session**: `[Top 2-3 most urgent items for the next tab/session]`

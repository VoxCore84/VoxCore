# Claude Code Memory Bridge

**Purpose**: Lightweight bridge file for the automated handover agent spawned by `stop_all.bat`.
Full project memory lives at `C:\Users\atayl\.claude\projects\C--Users-atayl-VoxCore\memory\MEMORY.md` (15+ topic files).

## DevOps Pipeline (session 125)

### Server Lifecycle
- **Boot**: `tools/shortcuts/start_all.bat` — MySQL → pending SQL → bnet → worldserver → Arctium → auto_parse daemon
- **Shutdown**: `tools/shortcuts/stop_all.bat` — kill servers → signal auto_parse → open PacketLog → spawn Claude Code handover

### SQL Deployment Pipeline
- **Drop zone**: `sql/updates/pending/*.sql` — write SQL patches here
- **Boot-time apply**: `apply_pending_sql.bat` runs automatically, prompts user, archives to `sql/updates/applied/`

### Client Data Capture (auto_parse shutdown sweep)
On server stop, auto_parse copies into `PacketLog/`:
- `C:\WoW\_retail_\Errors\*.txt` (client crashes)
- `C:\WoW\_retail_\WTF\Account\1#1\SavedVariables\TransmogSpy*.lua`, `TransmogBridge*.lua`
- `C:\WoW\_retail_\Cache\ADB\enUS\DBCache.bin`
- C++ crash dumps from `Crashes/`

### Session Brief
- `PacketLog/_Session_Brief.md` — auto-generated markdown summarizing the play session
- **Read this FIRST** when doing a handover

### Handover Protocol
1. Ingest `_Session_Brief.md` + `.auto_parse_seen.json` + `timeline.txt`
2. Review `git diff` for modified files
3. Read `doc/session_state.md` + `memory/todo.md` for task context
4. Update this file + memory files with session findings
5. Semantic git commit (include file list, bug signatures, evidence)
6. Push to GitHub

## Key Paths
| What | Where |
|------|-------|
| Full memory | `~/.claude/projects/C--Users-atayl-VoxCore/memory/MEMORY.md` |
| Session state | `doc/session_state.md` |
| Todo list | `~/.claude/projects/C--Users-atayl-VoxCore/memory/todo.md` |
| Server logs | `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/` |
| PacketLog | `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/PacketLog/` |
| Pending SQL | `sql/updates/pending/` |
| Applied SQL | `sql/updates/applied/` |
| Handover prompt | `tools/claude_code_handover.md` |
| Sync prompt | `tools/claude_sync_update.md` |

## AI Studio (session 125+)

### Routing Hierarchy
- `AI_Studio/1_Inbox/` — ChatGPT specs land here (auto-scraped from Desktop/Excluded by `ai_studio_router.py`)
- `AI_Studio/2_Active_Specs/` — move specs here when working on them
- `AI_Studio/3_Audits/` — Antigravity audit pass/fail results go here
- `AI_Studio/4_Archive/` — completed specs + audits after git push

### Project Symlinks (junctions)
- `AI_Studio/Projects/DiscordBot/Z_SourceCode` → `tools/discord_bot/`
- `AI_Studio/Projects/idTIP/Z_SourceCode` → `C:\WoW\_retail_\Interface\AddOns\idTip\`
- `AI_Studio/Projects/TongueAndQuill/Z_SourceCode` → `C:\Users\atayl\TongueAndQuill\`

### Multi-AI Triad
- **ChatGPT** = Lead Architect (writes specs, never code)
- **Claude Code** = Frontline Executor (implements specs into committed code)
- **Antigravity** = Backend Auditor (compiles, runs logs, audits against spec)

### Rules
- If a spec arrives for a new project, create `AI_Studio/Projects/[Name]/` and junction its source
- Save project docs/runbooks inside their `AI_Studio/Projects/[Name]/` folder, not scattered
- When a feature is pushed to git, move its spec + audit to `4_Archive/`

## Git Rules
- Branch: `master` (not `main`)
- Remote: `origin` → `VoxCore84/RoleplayCore` (private)
- Co-author: `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`
- Never force-push. Never amend unless asked.
- Commit message: semantic, reference specific files + evidence

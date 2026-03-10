# VoxCore DevOps Pipeline

## Server Lifecycle

### start_all.bat (6-step boot)
1. Start MySQL (UniServerZ)
2. Apply pending SQL from `sql/updates/pending/` via `apply_pending_sql.bat`
3. Start bnetserver
4. Start worldserver
5. Start Arctium Game Launcher
6. Start auto_parse daemon (headless)

### stop_all.bat (graceful shutdown)
1. Kill worldserver + bnetserver
2. Signal auto_parse via `.stop_auto_parse` file
3. Open PacketLog folder for review
4. Spawn Claude Code handover agent (`tools/claude_code_handover.md`)

## SQL Deployment Pipeline

- **Drop zone**: `sql/updates/pending/*.sql`
- **Boot-time apply**: `tools/shortcuts/apply_pending_sql.bat` runs at step 1.5
- **User prompt**: 15s timeout defaults to skip if no input
- **On success**: Files move to `sql/updates/applied/`
- **On error**: Files stay in `pending/`

## Auto-Parse v3 Pipeline

`tools/auto_parse/` — 19 Python modules, 2,498 lines.

### Features
- 7 log parsers (Server.log, DBErrors.log, Debug.log, GM.log, Bnet.log, PacketLog, Crashes)
- TOML config (`tools/auto_parse.toml`)
- HTML dashboard with live refresh
- System tray icon
- Toast notifications on fatal/crash
- Alert dedup (diff-aware, persistent state)
- Graceful shutdown via `.stop_auto_parse` signal file

### Client Data Capture (on shutdown)
Copies from WoW client dir into PacketLog/:
- `C:\WoW\_retail_\Errors\*.txt` (client crashes)
- `C:\WoW\_retail_\WTF\Account\1#1\SavedVariables\TransmogSpy*.lua`, `TransmogBridge*.lua`
- `C:\WoW\_retail_\Cache\ADB\enUS\DBCache.bin`
- C++ crash dumps from `Crashes/`

### Session Brief
- Output: `PacketLog/_Session_Brief.md`
- Auto-generated markdown: packet scope, DB errors, crash telemetry, GM command usage
- Primary debugging data source for post-play analysis

## Claude Code Handover Protocol

Spawned by `stop_all.bat` after server shutdown:
1. Ingest `_Session_Brief.md` + `.auto_parse_seen.json`
2. Review diffs since last commit
3. Sync memory files
4. Semantic git commit
5. Push to GitHub

User never has to type `git commit` manually.

## Key Files

| File | Purpose |
|------|---------|
| `tools/shortcuts/start_all.bat` | Full server boot sequence |
| `tools/shortcuts/stop_all.bat` | Graceful shutdown + handover |
| `tools/shortcuts/apply_pending_sql.bat` | Boot-time SQL deploy |
| `tools/auto_parse.toml` | Pipeline configuration |
| `tools/auto_parse/__main__.py` | Pipeline entry point |
| `tools/claude_code_handover.md` | Handover agent prompt |

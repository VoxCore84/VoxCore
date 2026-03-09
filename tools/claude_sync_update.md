# CLAUDE CODE MEMORY SYNCHRONIZATION OVERRIDE

**Execution Context:**
You are receiving this prompt because Antigravity has spent the last session severely overhauling the repository's backend architecture and DevOps pipelines. **You must immediately read this document and update your internal memories.**

## What Changed: The Architectural Overhaul
We have entirely automated the startup, debugging, and shutdown lifecycles of VoxCore. 

### 1. Unified Launch & Headless Watcher
- `tools/shortcuts/start_all.bat` and `stop_all.bat` are now the master controllers.
- The `auto_parse` daemon now runs dynamically in the background without needing a dedicated terminal tab. It listens for a file signal (`.stop_auto_parse`) from `stop_all.bat` which commands it to gracefully execute its shutdown sweep instead of being force-killed.

### 2. Global Client Data Capture
- `auto_parse` has been upgraded to automatically rip files directly out of the `C:\WoW\_retail_\` client directory when the server shuts down. 
- It actively copies `Errors/*.txt` (client crashes), `WTF/Account/1#1/SavedVariables/TransmogSpy*.lua`, `TransmogBridge*.lua`, and `DBCache.bin`. They are all permanently mirrored into the active `PacketLog` along with the C++ crash dumps.

### 3. The Master Session Brief (`_Session_Brief.md`)
- Before terminating, the `auto_parse` daemon mathematically synthesizes all packet scope data, DB error anomalies, Server crash telemetry, and GM Command usage into a single markdown file: `PacketLog/_Session_Brief.md`. 
- This document has an embedded visual seal (`ABILITY_SEAL.PNG`) designed specifically for immediate ingestion by AI agents.

### 4. Headless Claude Handover & Git Integrity
- You, Claude Code, are now completely tethered to the termination sequence! 
- `stop_all.bat` programmatically spawns you in a new Windows Terminal tab (`wt.exe`) using a rigid instruction set: `tools/claude_code_handover.md`.
- Your primary responsibility during a handover is to process `_Session_Brief.md`, synchronize your memory, write highly semantic Git commits, and push everything to GitHub. You are the project's lead DevOps integration flow.

### 5. Autonomous Database Deployment
- We built `tools/shortcuts/apply_pending_sql.bat` and integrated it into the server's boot sequence (`start_all.bat`).
- **CRITICAL DIRECTIVE FOR YOU:** Whenever you establish that a SQL database patch is required fixing a DBError, you must place the raw `.sql` file inside `C:\Users\atayl\VoxCore\sql\updates\pending\`.
- Whenever the server is started via `start_all.bat`, it will detect your SQL patches, prompt the user for safety verification, execute them natively against MySQL, and permanently archive them to `sql\updates\applied\`.

---
## ACTION REQUIRED: Update Your Global State
Perform the following immediately to align with the new architecture:
1.  **Create or Update** `doc/claude_memory.md` to permanently capture:
    - The new SQL deployment pipeline (`sql/updates/pending/`).
    - The fact that all debugging insights must now be synthesized directly from `PacketLog/_Session_Brief.md`.
    - Your role as the automated DevOps endpoint spawned via `stop_all.bat`.
2.  **Update** `doc/todo.md` (if it exists) to cross off any tasks related to organizing PacketLog, capturing WoW Client logs, building session briefs, or automating git handovers.
3.  **Acknowledge** in your response that the memory synchronization is complete!

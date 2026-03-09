# Master Antigravity Initialization State

**To the Next Antigravity Instance:** If you are reading this, you are the new Master Tab. The user has consolidated multiple splintered AI sessions into you. You are taking over the role of Systems Architect & Auditor for the VoxCore Triad.

Read this document to instantly synchronize your state with the architectural decisions made in previous sessions.

## 1. The Triad Ecosystem
- **Architect (ChatGPT):** Designs specs. Outputs to `AI_Studio\1_Inbox\`. 
- **Implementer (Claude Code):** CLI executor. Reads from `1_Inbox\`, writes code/SQL.
- **Auditor (You):** QA/QC, pipelines, architecture. You write audits to `AI_Studio\3_Audits\`.

## 2. Claude Code's Execution Context (Crucial Limits)
- **Memory Limitation:** Claude relies on `~/.claude/projects/.../memory/MEMORY.md` as its index. **This file has a strict 200-line visual truncation limit.** Do not ask Claude to put massive text blocks in `MEMORY.md`. 
- **Guardrails Active:** Claude has been instructed to **REFUSE** major implementation tasks unless it sees a spec from ChatGPT in the Inbox. It will stop the user from jumping the chain of command.
- **Tools:** Claude has 3 MCP servers (`wago-db2`, `codeintel`, `mysql`) and 23 slash commands. It compiles via the user's VS IDE (currently), but we are transitioning to headless.

## 3. The Active Stabilization Roadmap (v1 Hardened by Architect)
You are responsible for executing this roadmap to fix the brittle, hardcoded folder mess:

### Phase 1: The Aegis Config (Path Centralization)
Do not scan the entire C: drive. Scope only to VoxCore. Create a layered config system:
1. `config/paths.json` or `settings.yaml` for non-secret repo conventions.
2. A local untracked `.env` for secrets/machine overrides.
3. Runtime root discovery so scripts resolve paths relative to the workspace marker.

### Phase 2: The Iron Inbox (API Automations)
Automate ChatGPT API ingestion to remove the user as the copy-paste transport layer.
Pipeline: API Call -> JSON Spec -> Schema Validation -> Markdown Render -> Temp File -> **Atomic Rename** into `AI_Studio\1_Inbox\`.
State machine: `draft -> ready -> claimed -> implemented -> qa -> archived`. Add traced metadata to every spec.

### Phase 3: The Shadow Compiler (Headless Build Validation)
Standardize command-line / headless builds on the **exact same CMake preset/toolchain** as Visual Studio to prevent toolchain drift. Treat this as a compile-gate, not proof of correctness.

### Phase 4: The Pre-Flight Check (Shift-Left Auditing)
You (Antigravity) must audit code *before* it is merged/pushed to the main branch.

---
**Status:** The user is frustrated with manual multi-tab synchronization. Your first goal is to ensure this Master Tab is fully synchronized with the other legacy Antigravity tab's work (which was handling the AI Router and Orchestrator UI). Once you have ingested this file and the Central Brain, ask the user for the **"Green Light"** to begin Phase 1 (The Aegis Config).

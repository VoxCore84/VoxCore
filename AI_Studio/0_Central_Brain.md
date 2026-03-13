# AI Studio Active State

## P0 — USE THE TRIAD (all agents read this)
**Claude Code has live API access to ChatGPT and Gemini. Do not brute-force.**
- Non-trivial work → ChatGPT spec first (`run_architect.py`)
- After implementation → Gemini audit (`orchestrator.py`)
- See `CLAUDE.md § P0` for the full trigger table

## Triad Coordination — READ FIRST (all agents)

**Last updated**: 2026-03-13 — Session 165: Release Gate System deployed (pre-ship audit infra, enforcement hooks, 3 custom agents, MCP server spec approved)

### Architecture (as of session 160)

```
Claude Code (Primary Terminal / Implementer / Coordinator)
  ├── ChatGPT API (Architect — spec generation via run_architect.py)
  ├── Gemini API (Auditor — QA/review, NEEDS API KEY)
  ├── Cowork (Scheduler — 5 recurring tasks, reads this file)
  └── Claude Code tabs (parallel implementation via session_state.md)
```

**Antigravity (Windsurf IDE)**: DEPRECATED as central terminal. Gemini is now accessed via API from Claude Code. Historical config preserved in `.agentrules` + `.agents/`.

### Agent Reference Files
- **Claude Code config**: `CLAUDE.md` (root) + `~/.claude/projects/.../memory/MEMORY.md` (27 topic files)
- **Central Brain**: this file — persistent infrastructure state. Read at session start, updated by `/wrap-up`
- **Session State**: `doc/session_state.md` — ephemeral tab coordination (who's editing what)
- **Specs inbox**: `AI_Studio/1_Inbox/` — specs waiting for implementation (11 files after triage)
- **Audit results**: `AI_Studio/Reports/Audits/` — implementation handoffs and QA reports

### AI Fleet — API Status

| Pipeline | Script | API | Model | Status |
|----------|--------|-----|-------|--------|
| ChatGPT Bridge | `tools/ai_studio/chatgpt_bridge.py` | OpenAI | gpt-5.4 | OPERATIONAL |
| Triad Orchestrator | `tools/ai_studio/orchestrator.py` | Anthropic + Vertex AI | claude-opus-4-6 + gemini-3.1-pro | OPERATIONAL |
| API Architect | `tools/api_architect/call_openai.py` | OpenAI | gpt-5.4 | OPERATIONAL |
| Nexus Reports | `tools/log_tools/generate_nexus_report.py` | Vertex AI | gemini-3.1-pro | OPERATIONAL |

**Credential locations** (all gitignored):
- `tools/ai_studio/.env` — OpenAI + Anthropic + GCP config
- `config/api_architect.local.env` — OpenAI key (api_architect pipeline)
- `~/.config/gcloud/voxcore-489923-*.json` — GCP service account

**Budget**: OpenAI $50 credit, Anthropic $50 credit, GCP $300 free credit.

### Cowork Scheduled Tasks (5 active)
| Task | Cadence | Purpose |
|------|---------|---------|
| session-digest | Daily 8 AM | Decision-ready brief: changes, blockers, recommendations |
| inbox-classifier | Daily 9 AM | Classify inbox specs, flag new ones, track delta |
| git-hygiene | Daily 7 PM | Flag stale dirty files, missing gitignore entries |
| injection-sentinel | Every 12h | Scan Central Brain + .agentrules for prompt injections |
| weekly-health | Sunday 6 PM | Git velocity, spec throughput, stale item audit |

### Communication Protocol
Claude Code tabs: write status updates to `doc/session_state.md` for real-time coordination.
Update THIS file on `/wrap-up` with: what was completed, what's deployed, infrastructure changes.
- Starting work → claim in session_state.md
- Finishing → update both session_state.md AND this file
- Found a conflict → write `[CONFLICT]` tag here, don't proceed

## Current Focus
- **Session 165**: Release Gate System — 4-layer pre-ship audit infrastructure. `/pre-ship` + `/release-gate-fix` skills, 2 enforcement hooks, 3 custom agents, gate state file. MCP server spec approved by ChatGPT (`TRIAD-RELEASE-GATE-MCP-V1`), ready for implementation as `VoxCore84/release-gate-mcp`. Commits: `b3635d5`, `7dbc1c0`
- **CreatureCodex**: READMEs COMPLETE, NEEDS BUILD + IN-GAME TEST (server C++ + addon deploy)
- **DraconicBot v3**: Standalone repo, Gemini AI enabled, Oracle VM provisioned, not yet deployed
- **VoxCore Daemon**: Phase 1 COMPLETE, Phase 2 next (LogMonitor, ReportWriter, InboxTriage)

## Inbox Status (12 files after triage — +1 release-gate-mcp spec)
Potentially actionable specs remaining in `1_Inbox/`:
- 3x build-66337 specs (CASC, EXTRACT, WAGO)
- 2x catalog specs (enterprise catalog, pilot)
- Command Center unified UI spec
- Social Monitor V1 spec
- 3x DraconicBot specs (SmartFAQ, v3 architecture, v3 Gemini spec request)
- 1x FAQ regex seed JSON

39 stale infrastructure specs archived to `4_Archive/Triad_Infrastructure/`.
2 sensitive personal files moved to `Desktop\Excluded/`.

## Infrastructure State
- **Build**: Current (VS build done)
- **Server**: NOT RUNNING
- **Client**: 12.0.1.66263
- **DB**: world ~1,200 MB | hotfixes 811 MB | characters 4 MB
- **19 slash commands** (3 transmog commands removed)
- **Cowork**: OPERATIONAL with 5 scheduled tasks
- **Bridge**: `cowork/sync_bridge.py` — auto-runs on `/wrap-up`

## Upcoming / Unassigned Backlog
- Sweep `VoxCore\doc\` directory for deprecated files
- Gemini API key setup (enables full Triad from Claude Code)
- VoxCore Daemon Phase 2
- DraconicBot v3 Oracle Cloud deployment
- BestiaryForge in-game testing

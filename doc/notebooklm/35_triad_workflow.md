# VoxCore Triad AI Workflow

## The Three Agents

| Role | Agent | Platform | What They Do |
|------|-------|----------|-------------|
| **Architect** | ChatGPT | ChatGPT Pro | Designs specs, writes architecture docs. Outputs to `AI_Studio/1_Inbox/` |
| **Implementer** | Claude Code | Claude Max (CLI) | Executes specs — writes C++, SQL, Python, Lua. Full MCP + 23 slash commands |
| **Auditor** | Antigravity | Gemini Advanced | QA/QC, pipeline hardening, architecture oversight. Writes to `AI_Studio/3_Audits/` |

## Coordination

### Central Brain (`AI_Studio/0_Central_Brain.md`)
- All agents read at session start
- Status updates go HERE, not relayed through the user
- Tracks: active tabs, paused tasks, backlog

### AI Studio Directory
```
AI_Studio/
  0_Central_Brain.md      # Cross-agent coordination
  1_Inbox/                # ChatGPT drops specs here
  2_Active_Specs/         # Specs in progress
  3_Audits/               # Antigravity audit results
  4_Archive/              # Completed work
  Projects/               # Per-project junctions
```

## Workflow Rules

### For Claude Code (Implementer)
1. **Mandatory Preflight**: Before any new feature — read Central Brain, check Inbox for spec, confirm task is claimed
2. **Refusal Rule**: No spec in Inbox = refuse implementation. Reply with HALT message
3. **Exceptions**: Bug fixes, log gathering, build-loop, CLI tasks, or "Emergency override granted by Antigravity"
4. **Discipline**: Implement only scoped work. No silent scope expansion. Report conflicts back

### For ChatGPT (Architect)
1. Write specs with clear Scope Boundary section
2. Include exact tables/columns if DB changes needed
3. Drop completed specs in `AI_Studio/1_Inbox/`

### For Antigravity (Auditor)
1. Scan committed code for quality, security, correctness
2. Write findings to `AI_Studio/3_Audits/` with PASS/FAIL per item
3. Can grant emergency overrides

## Active Stabilization: Aegis Config

### Phase 2 COMPLETE (TRIAD-STAB-V1)
- Hardcoded `C:\Users\` paths removed from 8 runtime scripts
- `scripts/bootstrap/resolve_roots.py` — canonical root finder
- `config/Aegis_Path_Contract.md` — frozen path resolution rules
- `config/paths.json` — canonical alias registry
- `logs/audit/hardcoded_path_inventory_classified.csv` — 692 entries classified

### Phase 3 NEXT
- Scanner hardening — smarter regex for audit tool
- `auto_parse` config.py defaults still absolute (fallback OK)

## Key Files

| File | Purpose |
|------|---------|
| `AI_Studio/0_Central_Brain.md` | Coordination hub |
| `config/Aegis_Path_Contract.md` | Path resolution contract |
| `config/paths.json` | Canonical path aliases |
| `scripts/bootstrap/resolve_roots.py` | Root finder utility |
| `CLAUDE.md` | Claude Code project instructions |
| `~/.claude/.../memory/MEMORY.md` | Claude Code persistent memory index |

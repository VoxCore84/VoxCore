# RoleplayCore Project Memory

## Build Notes (supplements CLAUDE.md)
- **Primary IDE**: Visual Studio 2022 (user's preference). CLI via `/build-loop` skill also OK
- **OpenSSL 3.6.1**, RelWithDebInfo uses NTFS junctions to Debug data dirs
- Details: [build-environment.md](build-environment.md)

## User Preferences
- **Always check server logs** proactively — see [server-config.md](server-config.md) for paths
- **Auto-accept**: `git` and `gh` commands approved — no need to confirm
- **End-of-session checklist**: (1) anything to commit/push? (2) memory needs updating?
- **Always propose parallelism**: Suggest agent teams, subagents, worktrees for non-trivial tasks
- **Windows Terminal elevated**: All profiles auto-elevate (`"elevate": true` in defaults)
- Comfortable with direct SQL and cmake commands
- **wow.tools.local** running at `C:/Tools/WoW.tools/` → `http://localhost:5000`. Config points to `C:\WoW` (build 66220). Has WTL.db + hotfixes.db. Use for visual DB2 browsing, build diffs, hotfix inspection, file extraction

## Hardware Specs
- **CPU**: AMD Ryzen 9 9950X3D — labeled "16-Core" but Windows reports 12C/24T (NumberOfEnabledCore=16, WMI quirk on X3D)
- **RAM**: 128 GB DDR5-5600 (2x 64GB G.Skill)
- **GPU**: NVIDIA RTX 5090 — 32 GB VRAM
- **Storage**: Samsung 980 PRO 2TB NVMe
- **Build parallelism**: `ninja -j20` in CMakePresets.json + all batch files (was -j4, then -j16, now -j20)

## Performance Config
- **Project-level settings**: `.claude/settings.json` — default model `opus`, pre-allowed Read/Edit/MCP permissions
- **User-level settings**: `alwaysThinkingEnabled: true`, autocompact at 80%, tool search deferred at 5%
- **`~/.bashrc`**: exports `TERM=xterm-256color`
- **Speed tips**: `/fast` for speed boost, `/clear` between unrelated tasks, `/compact` with focus keyword
- **Keybindings** (`~/.claude/keybindings.json`): `Ctrl+K Ctrl+F` model picker, `Ctrl+K Ctrl+T` thinking toggle, `Ctrl+K Ctrl+O` transcript
- **Statusline**: Custom cost tracker using Opus 4.6 pricing ($5/$25/MTok input/output)
- **Named sessions**: `~/.claude/sessions/` — batch scripts for Transmog, Companion, Debug, General, Remote
- **Remote control**: `claude-remote.bat` launches `claude remote-control server` with worktree isolation

## Tools — [full inventory](tooling-inventory.md)
- **Tools dir**: `C:/Tools/` — consolidated third-party tools + reference data (WPP, WTL, DBC2CSV, Ymir, LoreWalkerTDB, TrinityCore-master, wow-export, wow-ui-source-live, lua-language-server, docs)
- **clangd-lsp gotcha**: Must be in settings.json (was disabled thinking it conflicted with codeintel MCP — real issue was user-level config override)
- **Packet logging**: Server must be stopped before WPP can read .pkt files
- **Ymir**: `C:/Tools/ymir_retail_12.0.1.66220/ymir_retail.exe` (build 66220). Does NOT work with private server

## GitHub Gists (all public)
- **DB Report**: `528e801b53f6c62ce2e5c2ffe7e63e29` — https://gist.github.com/VoxCore84/528e801b53f6c62ce2e5c2ffe7e63e29
- **Changelog**: `4c63baf8154753d2a89475d9a4f5b2cc` — https://gist.github.com/VoxCore84/4c63baf8154753d2a89475d9a4f5b2cc
- **Open Issues**: `2b69757faa2a53172c7acb5bfa3ad3c4` — https://gist.github.com/VoxCore84/2b69757faa2a53172c7acb5bfa3ad3c4
- **Gist update tip**: `gh api --method PATCH gists/<id> --input payload.json` (use Python to generate JSON payload with proper escaping). Omit leading `/` in endpoint to avoid Git Bash path rewriting.
- **Source of truth**: Gist content also tracked in `doc/gist_*.md` files in the repo

## Operational Procedures
- **Build bump**: Update `wago_common.py` `CURRENT_BUILD` → re-download CSVs (`wago_db2_downloader.py --tables-file tables_all.txt`) → re-run hotfix repair (5 batches). All 14 consumer scripts + MCP server import from `wago_common` automatically
- **Raidbots pipeline**: `run_all_imports.py --regenerate` handles its own paths
- **SQL update naming**: `sql/updates/<db>/master/YYYY_MM_DD_NN_<db>.sql`

## DB Schema Extras (beyond CLAUDE.md — [full details](db-schema-notes.md))
- Spell validation: `hotfixes.spell_name` (400K rows, composite PK — use EXISTS) + `world.serverside_spell` (4.4K, col `Id` lowercase d)
- `creature_template_spell`: `CreatureID`, `Index`, `Spell` — where creature spells live

## Active Systems

### Companion Squad — [details](companion-system.md)
- IN PROGRESS. `sCompanionMgr` singleton + `CompanionAI` + `.comp` commands
- Entries 500001-500005 (Warrior/Rogue/Hunter/Mage/Priest)
- **Next**: test combat/healer AI, spell casting, persistence, map change respawn

### Transmog Outfits — [details](transmog-implementation.md)
- **WORKING** for 12.x. 14/14 manual clicks, 13/14 outfit loading (secondary shoulder known gap)
- TransmogBridge addon: **3-layer hybrid merge** + stale detection (pre-snapshot)
- **5 OPEN BUGS** (diagnostic build deployed, session 36):
  - Bug A: Paperdoll naked on 2nd UI open
  - Bug B: Old head/shoulder persists when outfit doesn't define them
  - Bug C: Monster Mantle ghost appearance
  - Bug D: Draenei leg geometry loss
  - **Bug E (ROOT CAUSE CONFIRMED)**: Single-item transmog → SetEquipmentSet → full ViewedOutfit rebuild
- **Current state**: Diagnostic build deployed, Debug.log truncated, server shutdown. Test: Bug B first, then Bug E separately
- **NOT YET COMMITTED** — awaiting test results
- **PR #760** on KamiliaBlow/RoleplayCore. Branch `pr/transmog-ui-12x`

### Hotfix Repair — [details](hotfix-repair.md)
- **Last run: build 66220** (Mar 3 2026) — 388 tables, 103K inserts, 1.8K fixes
- **Redundancy audit COMPLETE** (Mar 4): 3 rounds removed ~10.6M redundant rows total
  - R1: 9.6M (string compare), R2: 204K (WTL DBC2CSV), R3: 768K (type-aware float32/int32/logical PK)
  - + 175K orphan hotfix_data rows cleaned
- **Post-cleanup**: ~244K genuine content rows (8,396 override + 231,199 new). hotfix_data: 226,984 entries. DB 535 MB
- **NOTE**: spell_name can no longer validate spells — use Wago DB2 CSVs or DBC runtime
- **Auth keys**: TC published 66220 keys on 2026-03-04. Bypass reverted in commit `8bbd610fc7`

### Build Diff Audit — [details](build-diff-audit.md)
- **COMPLETE** (Mar 3 2026). Diffed all 5 builds: 66044→66102→66192→66198→66220 across 39 priority tables
- **Key finding**: Wago CSV exports oscillate wildly — SpellEffect swings 269K↔608K between builds (export artifact, not content)
- Actual content delta across all builds: +77 spells, +17 items, +9 quests, ~1K modifications. **No breaking changes**
- 40 scripted spells got new SpellEffect entries — all at higher indices, no index shifting (safe)
- Scripts: `diff_builds.py` (with oscillation detection), `cross_ref_mysql.py` at `C:\Users\atayl\source\wago\`
- Reports: `build_diff_report_*.md`, `build_audit_actions.md`, `build_diff_data_*.json`

### Code Intelligence MCP — [details](tooling-inventory.md)
- ACTIVE. 8 tools, 416K symbols. Ctags (instant) + clangd (precision). Config must be in BOTH `~/.claude.json` and `.claude.json`

## Recent Work — [full log](recent-work.md)
- (Mar 5) **hotfix_data R3 cleanup**: 608K orphaned entries removed → 226,984 remaining. Hotfixes DB 535 MB. Gist fully corrected
- (Mar 5) **WPP script hardening**: 20-bug QA. start-worldserver.sh: EXIT trap, cd guards, pipefail, WPP exit check, transmog extraction integration. extract_transmog_packets.py: streaming, dynamic SQL glob, --pkt-dir CLI. Commits `8584c3c2e0` + tc-packet-tools `821e74f`
- (Mar 5) **Tools consolidation**: Moved Excluded → `C:\Tools\`, fixed WPP path (13 files/4 repos), added 7 missing tools to inventory. Pushed wago/tc-packet-tools/skills repos
- (Mar 5) **CT enrichment**: 4,820 of 4,918 spawned CT=0 creatures enriched via AreaTable + neighbor interpolation
- (Mar 5) **Coord transformer**: `coord_transformer.py` built — 1,856 critical + 1,626 high NPC spawns ready to generate
- (Mar 5) **SmartAI GUID bug**: 181 entries incorrectly cleared, fixed in `_02`, `_01` patched. AIName typos fixed (`_03`)
- (Mar 5) **Missing CTD fix + SmartAI cleanup**: 26,745 missing Diff0 rows, 5,894 SmartAI orphans
- (Mar 4) **Repo cleanup**: docs/tools reorganization. Commit `a7cf01b4ba`
- (Mar 4) **Transmog Client Wiki**: 3,487-line reference wiki + 119-line cheatsheet from 15 Blizzard Lua/XML source files. Commit `ad8f9eaa9f`
- (Mar 4) **Auth bypass reverted**: WorldSocket.cpp rejects missing keys. TC 66220 keys applied (7 keys). Commit `8bbd610fc7`
- (Mar 4) **Creature DB2 orphans**: 137 hotfix_data entries cleaned (hash 0xC9D6B6B3). Commit `319c2781cb`
- (Mar 4) **Transmog diagnostic committed**: Session 36 changes (shoulder fix, deleted set skip, caller tracing). Commit `c1e9a53c84`
- (Mar 4) **Hotfix R3 audit + cleanup**: Type-aware differ. 109 tables, 768K redundant removed. 239,595 genuine rows remain
- (Mar 4) **Phased cleanup complete** (sessions 37-38): 3 SQL fixes, 11 CTD rows, hotfix R2+companion (204K+175K), .gitignore
- (Mar 3) **Transmog 4-bug fix**: Commit `272c373105`
- (Mar 3) **Full data pipeline day**: Build 66220, hotfix repair, LW import, NPC audit
- (Mar 1) **Transmog CONFIRMED WORKING** — 14/14 manual clicks, 13/14 outfit loading. PR #760

## See Also (Topic Files)
- [todo.md](todo.md) — Persistent to-do list across sessions
- [build-environment.md](build-environment.md) — CLI build recipe, MSVC paths, batch files
- [server-config.md](server-config.md) — worldserver/bnet/MySQL config, performance tuning, log paths
- [sql-lessons.md](sql-lessons.md) — SQL generation patterns, idempotent ops, multi-agent workflow
- [hotfix-repair.md](hotfix-repair.md) — Repair system, column normalization, verification results
- [recent-work.md](recent-work.md) — Full chronological work log
- [lorewalker-reference.md](lorewalker-reference.md) — LoreWalkerTDB import details, spell hotfixes
- [raidbots-data-pipeline.md](raidbots-data-pipeline.md) — Raidbots/Wago/LW data import pipeline, scripts, QA results
- [skills-and-automation.md](skills-and-automation.md) — Runtime config: agent teams, env vars, statusline, Codex CLI
- [db-schema-notes.md](db-schema-notes.md) — Full verified schema reference
- [loot_tables.md](loot_tables.md) — Loot table schema, validation rules, source-column mapping
- [smartai-reference.md](smartai-reference.md) — SmartAI enums, deprecated types, validation rules
- [wago-db2-tables.md](wago-db2-tables.md) — Wago DB2 CSV locations, column layouts, usage tips
- [transmog-implementation.md](transmog-implementation.md) — Transmog packet layouts, slot mapping, known gaps
- `doc/transmog_client_wiki.md` — 3,487-line client Lua reference wiki (16 sections, 189 functions, 23 events, 24 structures)
- `doc/transmog_cheatsheet.md` — 119-line quick reference (ID types, DisplayType tree, slot table, opcodes, PR #760 bugs)
- [companion-system.md](companion-system.md) — Companion squad architecture, commands, seed data
- [tooling-inventory.md](tooling-inventory.md) — Master index of ALL custom scripts, tools, MCP servers across all locations
- [npc-audit.md](npc-audit.md) — NPC audit tool, applied fixes, phase_area system notes
- [wowhead-npc-audit.md](wowhead-npc-audit.md) — Wowhead 216K NPC mega-audit: 3 tiers, 54K fixes, scripts, reports
- [debugging-methodology.md](debugging-methodology.md) — Full debugging patterns, domain-specific recipes, code change rules
- [auth-key-notes.md](auth-key-notes.md) — Auth key system, bypass status, extraction techniques
- [build-diff-audit.md](build-diff-audit.md) — 5-build DB2 diff, Wago oscillation, scripted spell safety, scripts & reports

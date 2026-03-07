# RoleplayCore Project Bible
# Read this FIRST before any task. This is the single source of truth for Cowork.

## What This Project Is
TrinityCore-based WoW private server targeting the 12.x/Midnight retail client, specialized for roleplay. Solo developer project. Built on stock TrinityCore with significant custom systems.

## Key Locations (all local, same machine)

| Location | What |
|---|---|
| `C:\Users\atayl\VoxCore\` | Main repo (git, branch: master) |
| `C:\Users\atayl\VoxCore\src\server\game\` | Core game C++ source |
| `C:\Users\atayl\VoxCore\src\server\scripts\Custom\` | ALL custom script systems |
| `C:\Users\atayl\VoxCore\sql\updates\` | Incremental SQL patches (by DB name) |
| `C:\Users\atayl\VoxCore\doc\` | Project documentation (wikis, specs, gist mirrors) |
| `C:\Users\atayl\VoxCore\cowork\` | This Cowork workspace |
| `C:\Users\atayl\.claude\projects\C--Users-atayl-VoxCore\memory\` | Claude Code memory files (15+ topic files) |
| `C:\Users\atayl\VoxCore\wago\` | 50+ Python data pipeline tools, scrapers, audits |
| `C:\Users\atayl\VoxCore\ExtTools\` | Third-party tools (WPP, WTL, TACTSharp, DBC2CSV, ATT, wow-export, etc.) |
| `C:\WoW\_retail_\` | 12.x WoW client (build 66263) |

## Build Environment
- OS: Windows 11, MSVC (VS 2026), C++20, Ninja, CMake
- Database: MySQL 8.0 (UniServerZ portable), root/admin
- 5 DBs: auth, characters, world, hotfixes, roleplay (custom 5th DB)
- Hardware: Ryzen 9 9950X3D 12C/24T, 128GB DDR5, RTX 5090, 2TB NVMe
- Build: `ninja -j20` from `out/build/x64-Debug/` or `x64-RelWithDebInfo/`
- Primary runtime: `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/`

## GitHub
- **Repo**: `VoxCore84/RoleplayCore` (private) on `KamiliaBlow/RoleplayCore` fork
- **Public gists**:
  - DB Report: https://gist.github.com/VoxCore84/528e801b53f6c62ce2e5c2ffe7e63e29
  - Changelog: https://gist.github.com/VoxCore84/4c63baf8154753d2a89475d9a4f5b2cc
  - Open Issues: https://gist.github.com/VoxCore84/2b69757faa2a53172c7acb5bfa3ad3c4
  - Runbook: https://gist.github.com/VoxCore84/84656ef0960c699927e3a555e8248f7b
  - Transmog Wiki: https://gist.github.com/VoxCore84/88ba6320d249b5758753ecb954b0ded2
- **Other repos** (all VoxCore84):
  - `wago-tooling` (private) — Python data pipeline
  - `tc-packet-tools` (private) — Server launcher + WPP automation
  - `code-intel` (private) — C++ MCP server
  - `trinitycore-claude-skills` (private) — 17 Claude Code slash commands
  - `TransmogBridge` (public) — WoW addon

## Custom Systems (all in src/server/scripts/Custom/)

| System | Description | Status |
|---|---|---|
| Transmog Outfits | Full CMSG_TRANSMOG_OUTFIT handling for 12.x wardrobe | WORKING (14/14 slots) |
| Companion Squad | DB-driven NPC companions, role-based AI (tank/healer/DPS) | IN PROGRESS |
| CreatureOutfit | NPC appearance overlay system | WORKING |
| Visual Effects (.effect) | SpellVisualKit persistence + late-join sync | WORKING |
| Display/Transmog (.display) | Per-slot appearance overrides | WORKING |
| Player Morph (.wmorph/.wscale) | Persistent player morph and scale | WORKING |
| Dragonriding | Skyriding spell scripts | PARTIAL |
| Toys | Custom toy item scripts | WORKING |
| Free Share Scripts | .barbershop, .castgroup, .settime, .typing | WORKING |

## Database Schema Rules (CRITICAL)
- NO `item_template` — use `hotfixes.item` / `hotfixes.item_sparse`
- NO `broadcast_text` in world — use `hotfixes.broadcast_text`
- NO `pool_creature`/`pool_gameobject` — unified as `pool_members`
- `creature_template`: `faction` (not FactionID), `npcflag` (bigint)
- SQL update naming: `sql/updates/<db>/master/YYYY_MM_DD_NN_<db>.sql`

## Current Priorities (from todo.md)
1. In-game verification of transmog fixes (5 bugs fixed, awaiting test)
2. Companion squad combat/healer AI testing
3. Stormwind NPC ambient scripting (2,327 creatures, 1,046 have SmartAI)
4. LoreWalker TDB delta import (500K SmartAI, 248K loot — blocked on dedup QA)
5. Hotfix repair re-run against build 66263
6. VoxCore website Phase 0 (wow-export asset pipeline) and Phase 4 (before/after slider)

## What Claude Code Can Do (That Cowork Cannot)
Claude Code has access to these tools that Cowork does NOT have:
- **MySQL MCP**: Direct database queries and modifications
- **Wago DB2 MCP**: Query 1,097 DB2 CSV tables via DuckDB
- **Code Intelligence MCP**: C++ symbol lookup (416K symbols), definitions, references
- **Bash/Terminal**: Build commands, git operations, Python scripts
- **17 Slash Skills**: /build-loop, /check-logs, /apply-sql, /soap, /lookup-spell, /lookup-item, /lookup-creature, /lookup-area, /lookup-faction, /lookup-emote, /lookup-sound, /parse-errors, /decode-pkt, /parse-packet, /new-script, /new-sql-update, /smartai-check

**If a task needs any of the above, flag it as "hand off to Claude Code" in your output.**

## Python Tooling Highlights (at C:\Users\atayl\VoxCore\wago\)
- `npc_audit.py` — 27-audit NPC tool (levels, flags, faction, type, duplicates, phases)
- `go_audit.py` — 15-audit GameObject tool
- `quest_audit.py` — 15-audit Quest tool
- `coord_transformer.py` — Wowhead coords to world XYZ
- `wowhead_scraper.py` — Multi-entity Wowhead scraper (curl_cffi, Tor, 120 workers)
- `att_to_sqlite.py` — ATT mega-parser (60 tables, 52.6 MB SQLite)
- `repair_hotfix_tables.py` — Main hotfix repair tool
- `tact_extract.py` — CASC DB2 bulk extraction
- `validate_transmog.py` — Transmog cross-reference validator
- `transmog_debug.py` — Full transmog state debugger
- `db_snapshot.py` — MySQL backup/rollback tool

## Key Documentation Files
| File | Lines | What |
|---|---|---|
| `doc/transmog_client_wiki.md` | 3,487 | Complete 12.x transmog client Lua reference |
| `doc/transmog_cheatsheet.md` | 119 | Quick reference (IDs, slots, opcodes) |
| `doc/TRANSMOG_IMPLEMENTATION.md` | 228 | Reverse-engineered transmog protocol |
| `doc/transmog_audit_pass2.md` | 585 | QA report (hidden appearances, paired weapons) |
| `CLAUDE.md` | ~120 | Project guide (copied to cowork/context/) |

## Memory Files (Claude Code persistent memory)
Located at `C:\Users\atayl\.claude\projects\C--Users-atayl-VoxCore\memory\`:

| File | What |
|---|---|
| `MEMORY.md` | Master index + active systems status |
| `todo.md` | Prioritized task list (copied to cowork/context/) |
| `recent-work.md` | Chronological work log |
| `tooling-inventory.md` | Master index of ALL tools across all locations |
| `transmog-implementation.md` | Transmog packet layouts, slot mapping |
| `companion-system.md` | Companion squad architecture |
| `db-schema-notes.md` | Verified DB schema reference |
| `debugging-methodology.md` | Debugging patterns and rules |
| `hotfix-repair.md` | Repair system details |
| `build-environment.md` | CLI build recipe, MSVC paths |
| `server-config.md` | Runtime config, log paths |
| `sql-lessons.md` | SQL generation patterns |
| `smartai-reference.md` | SmartAI enums and validation rules |
| `website-vision.md` | VoxCore website plan |
| `cowork-setup.md` | THIS setup guide |

## Data Pipeline (high-level)
1. TACTSharp extracts 1,097 DB2 tables from local WoW CASC (~50s)
2. DBC2CSV converts .db2 to .csv
3. merge_csv_sources.py merges TACT + Wago CDN extras
4. wago_db2_server.py (MCP) serves queries via DuckDB
5. repair_hotfix_tables.py validates + fixes against MySQL hotfixes DB
6. Various audit scripts (npc_audit, quest_audit, go_audit) cross-reference

## Completed Milestones (context for understanding scope)
- 80,943 NPC pages scraped from Wowhead (+1,727 quest starters, +2,979 quest enders, +2,535 vendor items)
- 10.6M redundant hotfix rows removed (3 audit rounds)
- 26,745 missing DifficultyID=0 creature_template rows fixed
- 4,820 ContentTuningID=0 creatures enriched via zone lookup
- 1,748 missing NPC spawns generated from Wowhead coordinates
- 5 WoW client builds diffed (66044 through 66263)
- TransmogBridge addon: 3-layer hybrid merge + server-side stale rejection
- VoxCore website: 15 interactive features, dark "Arcane Codex" theme

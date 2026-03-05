# RoleplayCore — Session Changelog

Chronological log of all database, code, and infrastructure changes. Each entry includes the session number, what changed, and the commit hash where applicable.

---

## Mar 5, 2026

### Session 47 — Gist Accuracy Audit + hotfix_data R3 Cleanup
- **hotfix_data orphan cleanup**: `cleanup_hotfix_data_orphans.py` removed 608,401 orphaned entries. 226,984 remaining (was 835,385). Hotfixes DB 637→535 MB
- **Gist accuracy audit**: Verified all report numbers against live DB. Fixed 6 critical errors:
  - smart_scripts: 792K→294,425 (imports cleaned by validation scripts)
  - Part 11 hotfix tables: pre-audit numbers replaced with post-audit actuals
  - hotfix_data: 835K→227K (R3 registry cleanup applied)
  - DB sizes: world 1,267 MB, hotfixes 535 MB (previously stale)
- **OPTIMIZE/ANALYZE** on hotfix_data + 8 tables with stale InnoDB statistics
- Commit: `21fa23b0d1`

### Session 46 — WPP Script Hardening
- **20-bug QA** across 4 files: `start-worldserver.sh`, `extract_transmog_packets.py`, `wpp-inspect.sh`, `opcode_analyzer.py`
- Root cause: runtime `start-worldserver.sh` had stale WPP path (`out/` subdir)
- EXIT trap for bnetserver, `$WPP` full path, `cd` error guards, `set -o pipefail`, streaming packet extraction
- Commit: `8584c3c2e0` + tc-packet-tools `821e74f`

### Session 45 — DB Report Update
- **Hotfix audit tools committed**: `hotfix_differ_r3.py`, `gen_practical_sql_r3.py`, `build_table_info_r3.py`, `merge_results.py` + README.md + .gitignore
- **Gist created**: `528e801b53f6c62ce2e5c2ffe7e63e29` — comprehensive database report (Parts 1-16)
- Commit: `9ae9d40788`

### Session 44 — Tools Consolidation
- Moved `C:\Users\atayl\OneDrive\Desktop\Excluded\` → `C:\Tools\`
- Fixed WPP path in 13 files across 4 repos
- Added 7 missing tools to inventory
- Pushed: wago-tooling `b56bfb0`, tc-packet-tools `d956a5a`, trinitycore-claude-skills `25967f7`

### Session 43 — CTD Fix + SmartAI Cleanup
- **Missing CTD rows**: 26,745 creatures missing DifficultyID=0 → 0 remaining
  - Step 1a: 24,070 Diff2→Diff0 copies
  - Step 1b: 68 from other difficulties
  - Step 2: 2,607 default Diff0 rows
- **SmartAI orphans**: 5,894 creatures with AIName='SmartAI' but no scripts → cleared
  - +181 GUID-based script creatures restored (missed by entry-only check)
- **AIName fixes**: 3 data errors ('0', 'CombaAI' typo)
- **ContentTuning enrichment**: 4,820 spawned CT=0 creatures → zone/neighbor lookup
- Commit: `f0782d5030`, `9536a248b6`

## Mar 4, 2026

### Sessions 37-38 — Phased Cleanup
- 3 SQL fixes, 11 Stormwind CTD rows
- Hotfix R2 cleanup: 204K redundant rows removed
- Companion hotfix_data cleanup: 174,799 orphaned entries
- `.gitignore` updates
- Commit: `22d3f83d57`

### Sessions 35-36 — Hotfix R3 Audit + Transmog Diagnostics
- **R3 type-aware audit**: 109 tables, 768K redundant rows removed
  - Float32 IEEE 754 bit-level comparison
  - Signed/unsigned int32 pattern matching
  - Logical PK overrides (broadcast_text_duration)
- **Transmog diagnostic build**: secondary shoulder fix, deleted set skip, caller tracing
- Commit: `c1e9a53c84`

### Session 34 — Auth Key Update
- Reverted auth bypass at WorldSocket.cpp
- Applied TC build 66220 auth keys (7 keys)
- Commit: `8bbd610fc7`

### Session 33 — Creature DB2 Orphans
- 137 orphaned hotfix_data entries for Creature DB2 (hash 0xC9D6B6B3) removed
- Commit: `319c2781cb`

### Session 32 — Repo Cleanup
- docs → `doc/`, tools → `tools/`, batch scripts → `tools/build/`
- Deleted 1.4 GB hotfix_audit output + junk from repo root
- Commit: `a7cf01b4ba`

### Session 31 — Transmog Client Wiki
- 3,487-line reference wiki + 119-line cheatsheet from 15 Blizzard Lua/XML source files
- Commit: `ad8f9eaa9f`

## Mar 3, 2026

### Sessions 13-30 — Major Data Pipeline Day
- **Wowhead mega-audit**: 216,284 NPCs scraped, 54,571 operations across 3 tiers
- **Raidbots/Wago pipeline**: 1.6M item locale entries, 21K quest chains, 135K quest POI
- **LW import #2**: 665,658 net new rows across 21 tables (5-phase dependency ordering)
- **Post-import cleanup**: 47,478 rows cleaned, 627K error lines resolved
- **Hotfix repair build 66220**: 388 tables, 103K inserts, 1.8K column fixes
- **MySQL tuning**: tmp_table_size 1KB→256MB, buffer pool 16GB, warm restarts
- **Build diff audit**: 5 builds diffed, Wago oscillation detected, zero breaking changes
- **Hotfix pipeline crash fix**: 6 bugs across 3 C++ files (chunked delivery, ByteBuffer assert)
- **Transmog 4-bug fix**: Commit `272c373105`

## Mar 1, 2026

### Sessions 11-12 — Transmog Confirmed Working
- 14/14 manual clicks, 13/14 outfit loading (secondary shoulder gap)
- PR cleanup and cross-repo PR #760 on KamiliaBlow/RoleplayCore

## Feb 28, 2026

### Sessions 8-10 — Quest/GO Audits + TransmogBridge
- GO/quest audit tools + 2,279 DB fixes
- TransmogBridge addon implementation (3-layer hybrid merge)
- Creature/GO placement audits vs LoreWalkerTDB

## Feb 27, 2026

### Sessions 2-7 — Foundation
- 5-database audit: 148 checks, 412K dead rows removed
- LW import #1: 385,823 rows across 17 tables
- NPC audit tool (27 checks), 3-batch NPC fixes (23,904 operations)
- Placement audit tools built
- Loot table PK discovery + deduplication (193K pre-existing dupes + 3M import dupes)
- Backup table cleanup: 101 tables dropped, 382 MB reclaimed
- MyISAM→InnoDB migration (7 tables)

## Feb 26, 2026

### Session 1 — Initial Setup
- Companion AI fix
- Transmog wireDT fix
- Initial hotfix repair v1

---

## Database State (March 5, 2026)

| Database | Tables | Size | Key Metric |
|----------|--------|------|------------|
| world | 259 | 1,267 MB | 662K creatures, 294K SmartAI scripts |
| hotfixes | 517 | 535 MB | 227K hotfix_data, ~244K content rows |
| characters | 151 | 7.6 MB | |
| auth | 50 | 1.9 MB | |
| roleplay | 5 | 0.1 MB | |

## Repositories

| Repo | Latest Commit | Purpose |
|------|--------------|---------|
| VoxCore84/RoleplayCore | `21fa23b0d1` | Main server |
| VoxCore84/wago-tooling | `b56bfb0` | Wago/LW/hotfix tools |
| VoxCore84/tc-packet-tools | `821e74f` | WPP + packet analysis |
| VoxCore84/code-intel | — | C++ MCP server |
| VoxCore84/trinitycore-claude-skills | `25967f7` | Claude Code skills |

*Updated March 5, 2026*

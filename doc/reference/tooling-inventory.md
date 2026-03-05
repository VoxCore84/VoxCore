# Custom Tooling Inventory

Master index of all custom scripts, tools, and automation across the project.
Last updated: 2026-03-05.

## 1. Wago Tooling Repo — `C:/Users/atayl/source/wago/`

GitHub: `VoxCore84/wago-tooling` (private). Python 3.14.

### Core Data Pipeline
| Script | Purpose |
|--------|---------|
| `wago_common.py` | Shared config module — `CURRENT_BUILD`, `WAGO_CSV_DIR`, MySQL creds. All 14+ consumer scripts import from this |
| `wago_db2_downloader.py` | Download DB2 CSVs from Wago.tools (use `--tables-file tables_all.txt`) |
| `wago_enrich.py` | Pre-join CSVs into flat enriched files (transmog, items, appearances) |
| `diff_builds.py` | Diff two build CSV directories row-by-row (with oscillation detection) |
| `cross_ref_mysql.py` | Cross-reference Wago CSVs against live MySQL — used for build diff audit |
| `wago_list_tables.py` | Scrape all available DB2 table names from Wago.tools |

### Hotfix Repair System
| Script | Purpose |
|--------|---------|
| `repair_hotfix_tables.py` | Main repair tool — validate columns, fix imports, generate hotfix_data |
| `repair_scene_scripts.py` | Repair scene_script_text/global_text (multi-line Lua via HEX SQL) |
| `fix_overflow_sql.py` | Fix overflow values (negative→unsigned, clamp to max uint) |
| `audit_coverage.py` | Audit which Wago CSVs have no matching hotfix DB table (confirms 394/395 covered) |

### Client Cache Analysis
| Script | Purpose |
|--------|---------|
| `decode_dbcache.py` | Decode WoW DBCache.bin into human-readable output |
| `xref_dbcache.py` | Cross-reference DBCache.bin against server hotfix DB |

### Database Audit Tools
| Script | Purpose | Output Dir |
|--------|---------|------------|
| `npc_audit.py` | 27-audit NPC tool — levels, flags, faction, type, duplicates, phases, etc. | `npc_audit_fixes/` |
| `go_audit.py` | 15-audit GameObject tool — duplicates, phases, display, type, scale, loot, quest, pools, events, names, smartai, spawntime, addon_orphans, missing, faction | `go_audit_fixes/` |
| `quest_audit.py` | 15-audit Quest tool — chains, exclusive, givers, enders, objectives, rewards, startitem, missing, orphan_givers, orphan_npcs, poi, offer_reward, questline, addon_sync, duplicates | `quest_audit_fixes/` |

All three share the same architecture: `mysql_query()`, `load_wago_csv()`, `AUDIT_MAP` dispatch, `--report --json --sql-out --limit` flags.

### Placement Audits
| Script | Purpose |
|--------|---------|
| `creature_placement_audit.py` | Validate creature spawn positions against map boundaries and zone data |
| `go_placement_audit.py` | Validate gameobject spawn positions against map boundaries and zone data |
| `find_dupe_spawns.py` | Find exact-position duplicate creature/GO spawns |
| `batch_delete_dupes.py` | Batch delete duplicate spawn entries |

### Coordinate & Enrichment Tools
| Script | Purpose |
|--------|---------|
| `coord_transformer.py` | Transform Wowhead zone-percent coordinates to world XYZ. Uses nearest-neighbor Z interpolation from 527K existing spawns. 1,856 critical + 1,626 high spawns ready |
| `enrich_content_tuning.py` | Enrich CT=0 creatures via AreaTable zone lookup + neighbor interpolation. Applied to 4,820 of 4,918 spawned creatures |
| `gen_quest_cleanup.py` | Generate quest cleanup SQL |

### Cross-Reference / Validation
| Script | Purpose |
|--------|---------|
| `xref_missing_spawns.py` | Find client-known but server-missing creature/GO spawns |
| `table_hashes.py` | Auto-generated DB2 TableHash mapping (1,121 entries) |
| `extract_table_hashes.py` | Extract TableHash values from .wdc5 file headers |

### Web Scrapers
| Script | Purpose |
|--------|---------|
| `wowhead_scraper.py` | Scrape Wowhead API for NPCs, items, spells, quests, vendors, talents. Enhanced quest parser (30 fields). Bracket-depth JS parsing for nested objects + single-quoted strings |

### Raidbots Data Pipeline — `C:/Users/atayl/source/wago/raidbots/`
| Script | Purpose |
|--------|---------|
| `import_item_names.py` | Raidbots item-names.json → item_sparse_locale + item_search_name_locale SQL (10 locales) |
| `quest_chain_gen.py` | Wago QuestLineXQuest CSV → PrevQuestID/NextQuestID UPDATE SQL (live DB state aware) |
| `gen_quest_poi_sql.py` | Wago QuestPOIBlob/Point CSVs → quest_poi + quest_poi_points INSERT SQL |
| `quest_objectives_import.py` | Wago QuestObjective CSV → quest_objectives INSERT SQL |
| `run_all_imports.py` | Master runner — `--regenerate` re-runs all 4 import scripts + applies fixes |
Output: `raidbots/sql_output/`. Fix SQL: `fix_quest_chains.sql`, `fix_locale_and_orphans.sql`. See [raidbots-data-pipeline.md](raidbots-data-pipeline.md)

### LoreWalker Import Pipeline
| Script | Purpose |
|--------|---------|
| `scan_lw_world.py` | Scan LoreWalkerTDB world.sql for focus tables |
| `extract_lw_world.py` | One-pass extraction into individual SQL import files |
| `fix_lw_mismatches.py` | Fix column mismatches (add explicit column lists) |
| `fix_scene_template.py` | Strip RTComment column from scene_template |
| `fix_scene_template2.py` | Re-extract scene_template (6-col → 5-col) |
| `scan_lw_ids.py` | Extract quest/creature IDs from LW world.sql |
| `cross_ref_lw.py` | Cross-reference LW IDs vs our DB |
| `world_health_check.py` | Post-import referential integrity check |
| `summarize_orphans.py` | Summarize orphan categories for cleanup |

### MCP Server
| Script | Purpose |
|--------|---------|
| `wago_db2_server.py` | FastMCP server — 6 tools for DB2 CSV querying via DuckDB. Imports `WAGO_CSV_DIR` from `wago_common` (no env var needed) |

### WTL Client (wow.tools.local)
| Script | Purpose |
|--------|---------|
| `wtl_client.py` | Python client for WTL REST API — 13 methods (build, db2_list, header, peek, find, export_csv, relations, hotfix_list, file_exists, etc.), 3 exception types (WTLError, WTLConnectionError, WTLTableError), thread-local sessions, exponential backoff, module singleton via `get_client()`. diff_db2/download_hotfixes stubbed (NotImplementedError — need multi-build). Requires WTL running at localhost:5000 |
| `test_wtl_client.py` | 20 pytest integration tests (18 online, 2 offline). Module-scoped fixture skips if WTL offline |

### Transmog Validation
| Script | Purpose |
|--------|---------|
| `validate_transmog.py` | Cross-reference WTL client DB2 ground truth vs server hotfix overrides. 7 checks: missing rows, FK integrity, value mismatches, TransmogSet resolution, reverse validation, illusion IDs, slot mapping. `--verbose` and `--sql-out` flags. 0.8s across 155K IMAIDs + 71K set items. Outputs `transmog_validation_report.json` + `transmog_repair.sql` |

### Transmog Debugging
| Script | Purpose |
|--------|---------|
| `transmog_lookup.py` | DB2 cross-reference tool: IMAID lookup, batch debug log parsing, DT→slot mapping, item search, Debug.log session analyzer. JSON-cached (~0.4s). Commands: `imaid`, `batch`, `batch-stdin`, `dt`, `outfits`, `slots`, `reverse`, `search`, `analyze` |
| `transmog_debug.py` | Full transmog state debugger. Commands: `--char <name\|guid>` (equipped modifiers + outfits + situations), `--imaid <id...>` (resolve IMAIDs → item name/DT/slot), `--packet <hex>` (parse outfit packet, auto-strips header), `--packet --file <log> --nth N` (extract Nth packet from Debug.log), `--outfit <name\|guid>` (outfit table only), `--diff <name\|guid>` (equipped vs outfit + stale slot detection), `--log --last N` (transmog log entries with tagged summary), `--spy` (parse TransmogSpy SavedVariables for client-side transmog event log). Auto-detects best Wago CSV build (prefers 66102 with 166K items), batch hotfix fallback for unknown items |

### DB Snapshot Manager
| Script | Purpose |
|--------|---------|
| `db_snapshot.py` | Automated MySQL backup/rollback tool. Commands: `snapshot`, `check`, `list`, `rollback`, `prune`. Tracks 16 world tables, gzip compression, ETA estimation, monotonic IDs. Public API: `should_snapshot()`, `auto_snapshot_if_needed()` |
| `snapshots/` | Gzipped mysqldump files + `snapshot_state.json` metadata |

### Utilities
| Script | Purpose |
|--------|---------|
| `tc_soap.sh` | Send SOAP commands to worldserver (127.0.0.1:7878) |

### Probe/Discovery (rarely used)
| Script | Purpose |
|--------|---------|
| `wago_peek_tablemeta.py` | Inspect Wago site metadata format |
| `wago_probe.py` | Probe Wago.tools page data-payload structure |

### Generated Artifacts (repo root, not scripts)
| Pattern | Contents |
|---------|----------|
| `repair_batch_{1-5}.sql`, `*_fixed.sql` | Hotfix repair SQL batches (applied) |
| `repair_report_{1-5}.txt` | Repair run reports |
| `repair_scene_scripts.sql` + `_report.txt` | Scene script fixes |
| `transmog_hotfix_data.sql` | Transmog-related hotfix_data entries |
| `tables_all.txt` | Master list of all DB2 table names for downloader |
| `lw_*.txt`, `missing_*.txt` | LoreWalker/cross-ref ID lists |
| `AGENT_PROMPTS*.md`, `low_mapping_research.md` | DELETED — were session artifacts |

### Archive — DELETED
Was 2.2GB of dead batch-processing scripts/SQL from earlier hotfix repair iterations. All superseded by `repair_hotfix_tables.py`.

### Data Directories
| Dir | Contents |
|-----|----------|
| `wago_csv/major_12/12.0.1.66220/enUS/` | **Current build** CSVs (1,097 tables) — used by `wago_common.WAGO_CSV_DIR` |
| `wago_csv/major_12/12.0.1.66192/enUS/` | Previous build CSVs (used as diff baseline by `diff_builds.py`) |
| `wago_csv/major_12/12.0.1.66102/enUS/` | Older build CSVs (166K items) — preferred by transmog_debug.py for item coverage |
| `wago_csv/major_12/12.0.1.66066/enUS/` | Oldest build (reference) |
| `lw_world_imports/` | Extracted SQL from LoreWalkerTDB |
| `wowhead_data/{spell,item,npc,quest,vendor}/raw/` | Cached Wowhead JSON |
| `raidbots/` | Raidbots static JSON (47 files, 168MB) + import scripts + sql_output/ |
| `raidbots/sql_output/` | Generated SQL files (locales, chains, POI, objectives, fixes) |

---

## 2. SQL Exports — `C:/Dev/RoleplayCore/sql/exports/`

Untracked directory, now organized into subdirectories.

### `scripts/` — Python Audit/Extraction Tools
| Script | Purpose |
|--------|---------|
| `audit_lw_counts.py` | Audit LW row counts |
| `audit_lw_quality.py` | Audit LW data quality |
| `audit_lw_wave2.py` | Audit wave-2 LW imports |
| `extract_lw_smartai.py` | Extract new SmartAI from LW (source_type 0,1,9,12) |
| `find_duplicate_spawns.py` | Find duplicate creature/GO spawns |
| `compare_npc_names.py` | Wowhead: name comparison |
| `analyze_mismatches.py` | Wowhead: mismatch categorization |
| `cross_ref_npc_type_classification.py` | Wowhead: type/class enum cross-ref |
| `fix_level1_npcs.py` | Wowhead: level-1 fix generator |
| `extract_subtitles.py` | Wowhead: tooltip subtitle extractor |
| `extract_completion_category.py` | Wowhead: role/category extractor |
| `extract_all_coords.py` | Wowhead: coordinate extractor |
| `cross_ref_npc_flags.py` | Wowhead: NPC flag cross-ref |
| `cross_ref_zones.py` | Wowhead: zone validation |
| `validate_level_ranges.py` | Wowhead: level vs ContentTuning |
| `analyze_missing_spawns.py` | Wowhead: missing spawn prioritization |
| `audit_empty_services.py` | Wowhead: empty vendor/trainer audit |
| `validate_factions.py` | DB2: faction validation |
| `validate_models.py` | DB2: display ID validation |
| `validate_equipment.py` | DB2: equipment item validation |
| `npc_name_fixes.sql` | Wowhead: 379 name fixes (APPLIED) |
| `zone_ct_mapping.txt` | Zone→ContentTuning reference (487 lines) |

### `cleanup/` — DB Cleanup SQL + Reports
| File | Purpose |
|------|---------|
| `cleanup_duplicate_spawns.sql` | Remove duplicate spawns |
| `cleanup_hotfix_dupes.sql` | Remove duplicate hotfix entries |
| `cleanup_loot_orphans.sql` | Remove orphaned loot entries |
| `cleanup_pools_misc.sql` | Clean up pool entries |
| `cleanup_rbac.sql` | Remove stale RBAC permissions |
| `cleanup_scripts_orphans.sql` | Remove orphaned SmartAI scripts |
| `npc_safe_fixes.sql` | Wowhead T1: 2,292 type fixes (APPLIED) |
| `npc_type_classification_fixes.sql` | Wowhead T1: 6,781 type/class fixes (APPLIED) |
| `npc_level_fixes_{high,medium,low}.sql` | Wowhead T1: 6,548 level fixes (APPLIED) |
| `npc_subname_fixes.sql` | Wowhead T1: 516 subtitle fixes (APPLIED) |
| `npc_subname_revert_bad.sql` | Wowhead T1: 243 false-positive reverts (APPLIED) |
| `npc_flag_fixes.sql` | Wowhead T1: 2,265 flag additions (APPLIED) |
| `npc_level_range_fixes.sql` | Wowhead T2: 3,013 ContentTuningID fixes (APPLIED) |
| `npc_zone_fixes.sql` | Wowhead T2: 5 zone hierarchy fixes (APPLIED) |
| `npc_empty_service_fixes.sql` | Wowhead T2: 21 flag removals (APPLIED) |
| `npc_faction_fixes.sql` | Wowhead T3: 3 faction fixes (APPLIED) |
| `npc_model_fixes.sql` | Wowhead T3: 232 model resets (APPLIED) |
| `npc_equipment_fixes.sql` | Wowhead T3: empty (all items valid) |
| `db_consistency_fixes.sql` | Wowhead T3: SmartAI + waypoint orphans (APPLIED) |
| `*_report.txt` (8 files) | Audit reports: missing_spawns, zone_mismatch, empty_services, level_range, faction, model, equipment, db_consistency |

### `lw_imports/` — LoreWalker Data Imports
| File | Purpose |
|------|---------|
| `lw_creature_loot.sql` | Creature loot from LW |
| `lw_gameobject_loot.sql` | GO loot from LW |
| `lw_game_events.sql` | Game events from LW |
| `lw_loot_convos.sql` | Loot conversations from LW |
| `lw_pools.sql` | Spawn pools from LW |
| `lw_quest_tables.sql` | Quest tables from LW |
| `lw_world_tables.sql` | General world tables from LW |
| `lw_missing_smartai.sql` | Missing SmartAI scripts |
| `lw_smartai_remaining.sql` | Remaining SmartAI to process |

### `locale/` — Localization Exports
| File | Purpose |
|------|---------|
| `ptBR_hotfixes.sql` | ptBR hotfix translations |
| `ptBR_world.sql` | ptBR world translations |
| `ptBR_locale_export.zip` | Packaged locale export for Discord |

### Root Reference Files
| File | Purpose |
|------|---------|
| `existing_smartai_entries.txt` | Entries with existing SmartAI |
| `missing_smartai_entries.txt` | Entries needing SmartAI |

---

## 3. Repo Root — `C:/Dev/RoleplayCore/`

### `tools/build/` — Build Batch Files (untracked, gitignored)
| File | Purpose |
|------|---------|
| `_b.bat` | Build worldserver (RelWithDebInfo) |
| `_bs.bat` | Build scripts (RelWithDebInfo) |
| `_build_scripts.bat` | Build scripts (Debug) |
| `_cmake_rel.bat` | CMake reconfigure (RelWithDebInfo) |
| `build_rel.bat` | Build worldserver with log redirect |
| + 5 more variants | Debug, reconfig, etc. |

### `tools/` — Python Tools & Scripts (tracked)
| File | Purpose |
|------|---------|
| `extract_transmog_packets.py` | WPP packet log parser — streams World_parsed.txt, extracts transmog packets/addon/UPDATE_OBJECT into report. Dynamic SQL glob, `--pkt-dir` CLI arg. Auto-called by `start-worldserver.sh` on exit |
| `opcode_analyzer.py` | Packet capture cross-referencing — maps opcodes to TC handlers, identifies unhandled |
| `parse_dberrors.py` | Parse worldserver DBErrors.log, categorize errors by type with counts |
| `_optimize_db.bat` | MySQL OPTIMIZE/ANALYZE batch script |

### `hotfix_audit/` — Hotfix Redundancy Audit Tools (tracked)
| File | Purpose |
|------|---------|
| `hotfix_differ_r3.py` | Type-aware R3 hotfix differ — float32 IEEE 754 bit-level, signed/unsigned int32, logical PK overrides |
| `gen_practical_sql_r3.py` | Generate practical cleanup SQL from R3 diff results |
| `build_table_info_r3.py` | Build table metadata (column types, PKs) for R3 differ |
| `merge_results.py` | Merge R3 results across multiple table batches |
| `cleanup_hotfix_data_orphans.py` | Scan all 129 table hashes, LEFT JOIN to find orphaned hotfix_data entries, remove them. `--dry-run` / `--apply` |
| `README.md` | Documentation for the audit tools |

### `doc/` — Documentation (tracked)
| File | Purpose |
|------|---------|
| `transmog_client_wiki.md` | 3,487-line 12.x transmog client Lua reference wiki (16 sections, 189 functions). Also published as [gist](https://gist.github.com/VoxCore84/88ba6320d249b5758753ecb954b0ded2) |
| `transmog_cheatsheet.md` | 119-line transmog quick reference. Same gist |
| `TRANSMOG_IMPLEMENTATION.md` | Reverse-engineered transmog protocol doc (228 lines). Moved from `_patches_transmog/` |
| `transmog_ui_diagnosis.md` | Transmog UI bug diagnosis notes |
| `DATABASE_REPORT.md` | Database engineering summary |
| `RoleplayCore_Database_Report.md` | Comprehensive DB quality report |
| `gist_current.md` | Published [gist](https://gist.github.com/VoxCore84/528e801b53f6c62ce2e5c2ffe7e63e29) — DB engineering report |
| `gist_changelog.md` | Published [gist](https://gist.github.com/VoxCore84/4c63baf8154753d2a89475d9a4f5b2cc) — Session changelog |
| `gist_open_issues.md` | Published [gist](https://gist.github.com/VoxCore84/2b69757faa2a53172c7acb5bfa3ad3c4) — Open issues & roadmap |
| `AGENTS.md` | Agent/Codex instructions |
| `reference/` | 22 project reference files (memory mirror) — tracked in git |

### TransmogBridge/ (tracked — also has own repo)
GitHub: `VoxCore84/TransmogBridge` (public). WoW 12.x addon patching client serializer bug.

### TransmogSpy/ (tracked, committed `bfe9f61e51`)
WoW client addon for transmog diagnostic logging. Source: `C:/Dev/RoleplayCore/TransmogSpy/`, installed to `C:/WoW/_retail_/Interface/AddOns/TransmogSpy/` (manual copy).

| Feature | Details |
|---------|---------|
| Event logger | 14 transmog events, auto-dumps slots on SUCCESS/UPDATE |
| API hooks | `hooksecurefunc` on SetPendingTransmog, ClearPending, CommitAndApplyAllPending, plus 6 other C_TransmogOutfitInfo/C_Transmog functions |
| Pre/post apply | PreClick button hook captures snapshot BEFORE C call clears pending; deferred comparison on server response event (SUCCESS, UPDATE, or PENDING_CLEARED fallback) |
| Auto-monitor | 2-sec polling while transmog UI open, logs pending state transitions |
| Quiet mode | `/tspy quiet` — logs to SavedVariables only, suppresses chat |
| Slash commands | `dump`, `pending`, `snapshot`, `last`, `outfits`, `visual`, `slotinfo`, `events`, `clear`, `auto`, `quiet`, `apis`, `help` |
| SavedVariables | `TransmogSpyDB` — persistent log (2000 lines), last apply pre/post snapshots |
| Safety | All hooks via `hooksecurefunc` (no taint), all API calls wrapped in `TryCall` with deduplicated error logging, API availability cached at load |

### .codex/ (tracked)
Codex CLI config for automated coding tasks. `setup.sh` (deps + cmake), `instructions.md` (project context), 3 task specs (`TRANSMOG_CODEX_TASK.md`, `TRANSMOG_FLOATING_FIX.md`, `TRANSMOG_REVIEW_TASK.md`).

### _patches_transmog/
Reference git diff patches + `TRANSMOG_IMPLEMENTATION.md` (228-line reverse-engineered protocol doc).

### sql/RoleplayCore/ (tracked)
One-time setup scripts for custom systems. See CLAUDE.md for full list.

### opcode_analyzer.py (tracked)
Packet capture cross-referencing tool. Parses WPP output, maps opcodes to TC codebase handlers, identifies unhandled/unknown opcodes. Python 3.14.

### Server Runtime Directories
Build output where the compiled server actually runs. Configs, logs, extracted data, crash dumps all live here.

| Dir | Notes |
|-----|-------|
| `out/build/x64-Debug/bin/Debug/` | Debug build runtime. Contains worldserver/bnetserver exes+pdbs, configs, UniServerZ MySQL, extracted data (cameras, dbc, gt), `Buildings/`, `Crashes/` |
| `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/` | **Primary runtime**. Uses NTFS junctions to Debug's data dirs (Buildings, cameras, dbc, gt, UniServerZ). Has its own logs: `Server.log`, `DBErrors.log`, `Debug.log`, `GM.log`, `Bnet.log`, `PacketLog/`, `Crashes/` |

---

## 4. C:\Tools\ — Third-Party Tools & Reference Data

| Tool | Path | Purpose |
|------|------|---------|
| **WowPacketParser** | `C:/Tools/WowPacketParser/WowPacketParser.exe` | Parse `.pkt` packet captures into SQL/text. Locally patched for build 66220. Generates `*_hotfixes.sql`, `*_world.sql`, `*_wpp.sql` output |
| **wow.tools.local** | `C:/Tools/WoW.tools/` | v0.9.2, local web UI for browsing DB2/DBC files. Serves on `http://localhost:5000`. Config: `config.json` (wowFolder=`C:\WoW`, product=wow, region=us). Includes `WTL.db` (765MB file history) + `hotfixes.db` (193MB). Reads CASC from local WoW install (build 66220). Use for: DB2 browsing, build diffs, hotfix inspection, file extraction, map viewer. **Launcher**: `start_wtl.bat` (polls until ready, opens browser). **Python client**: `wtl_client.py` in wago repo |
| **lua-language-server** | `C:/Tools/lua-language-server/` | Lua LSP server for addon development diagnostics |
| **DBC2CSV** | `C:/Tools/DBC2CSV/DBC2CSV.exe` | Convert DBC/DB2 files to CSV. Canonical .dbd definitions in `definitions/` subdir |
| **Ymir** | `C:/Tools/ymir_retail_12.0.1.66220/ymir_retail.exe` | Retail sandbox binary (build 66220). Does NOT work with private server |
| **LoreWalkerTDB** | `C:/Tools/LoreWalkerTDB/` | LoreWalkerTDB reference DB dump — `world.sql` (897MB), `hotfixes.sql` (322MB) |
| **TrinityCore-master** | `C:/Tools/TrinityCore-master/` | Stock TrinityCore source reference (upstream comparison) |
| **wow-export** | `C:/Tools/wow-export/` | wow-export tool (CASC data extraction) — `installer.exe` + `data.pak` |
| **wow-ui-source-live** | `C:/Tools/wow-ui-source-live/` | Blizzard WoW UI Lua/XML source (Interface/ tree) |
| **docs** | `C:/Tools/docs/` | Analysis/reference markdown docs (transmog bridge, etc.) |

---

## 5. Source Repos — `C:/Users/atayl/source/`

### tc-packet-tools — `C:/Users/atayl/source/tc-packet-tools/`
GitHub: `VoxCore84/tc-packet-tools` (private). Server launcher wrapper + WPP automation. Scripts are copied to `bin/RelWithDebInfo/` at runtime.

| File | Purpose |
|------|---------|
| `start-worldserver.sh` | Full session lifecycle: (1) archives previous session (pkt, parsed txt/7z, errors, SQL, transmog_extract, all 5 logs), (2) cleans stale WPP files, (3) launches bnet+worldserver with EXIT trap (kills bnetserver on Ctrl+C), (4) auto-runs WPP on exit (pipefail, exit check, error reporting), (5) moves WPP SQL/errors to `PacketLog/`, (6) build validation (<90% parse rate warning), (7) auto-runs `extract_transmog_packets.py --pkt-dir`, (8) single-pass awk summary. Guards all `cd` commands, propagates worldserver exit code |
| `wpp-add-build.sh` | Add new WoW build to WPP's 3 switch statements (`GetOpcodeDefiningBuild`, `GetUpdateFieldDictionaryBuildName`, `GetVersionDefiningBuild`). Uses contiguous-group detection to insert in correct function. Rebuilds WPP with `dotnet build`, copies output. Detects already-present builds |
| `wpp-inspect.sh` | Quick-grep utility for `World_parsed.txt`. Commands: `visible [slot]`, `transmog` (capped at 500 lines + count), `trace <pattern>`, `summary`, `opcodes`, `search <pattern>`. Uses `set -u` (no pipefail — breaks grep no-match) |
| `WowPacketParser.dll.config.template` | WPP config template for 12.x builds |

**Key design notes**:
- WPP output format: opcodes prefixed with `ServerToClient: SMSG_` / `ClientToServer: CMSG_` (not bare opcode names)
- Player GUIDs in parsed output: `Player/0 R1/S0 Map: N Low: N` (not `Player-N-NNNN` which is GM.log format)
- GM commands only in `GM.log` (chat text not in WPP parsed output)
- No `bc` on Windows — all float math uses `awk`
- `-oP` (Perl regex) fails on Windows locale — use `-oE` (extended regex) instead

### code-intel — `C:/Users/atayl/source/code-intel/`
GitHub: `VoxCore84/code-intel` (private). Hybrid ctags+clangd MCP server for C++ code intelligence. 3 files: `code_intel_server.py`, `ctags_index.py`, `clangd_client.py`. See section 6 MCP Servers for tool details.

### trinitycore-claude-skills — `C:/Users/atayl/source/trinitycore-claude-skills/`
GitHub: `VoxCore84/trinitycore-claude-skills` (private). 17 Claude Code slash command skills for TrinityCore development. Installed to `.claude/commands/` in the project.

| Category | Skills |
|----------|--------|
| Build & Dev | `build-loop`, `new-script`, `new-sql-update` |
| Server Ops | `check-logs`, `parse-errors`, `apply-sql`, `soap` |
| Packet Analysis | `decode-pkt`, `parse-packet` |
| Data Lookups | `lookup-spell`, `lookup-item`, `lookup-creature`, `lookup-area`, `lookup-faction`, `lookup-emote`, `lookup-sound` |
| Validation | `smartai-check` |

### Reference Clones — DELETED
`C:/Users/atayl/source/repos/` contained dead VS2022 workspace caches (no real code). Deleted Feb 27.

---

## 6. Claude Code Config

### Global — `~/.claude/`
| File | Purpose |
|------|---------|
| `settings.json` | Permissions, plugins, env vars (agent teams enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) |
| `statusline-command.sh` | Status bar: model, context %, cost |
| `scripts/msvc_env.sh` | MSVC environment setup for CLI builds |

### Project — `C:/Dev/RoleplayCore/.claude/`
| File | Purpose |
|------|---------|
| `settings.local.json` | PostToolUse hook (C++ edit → build reminder), permissions (GitHub MCP, memory/wago/desktop read) |
| `commands/` | 17 custom skills (installed from `trinitycore-claude-skills` repo — see section 5) |

### Plugins (4, all `claude-plugins-official`)
| Plugin | Purpose |
|--------|---------|
| `clangd-lsp` | C++ language server (go-to-definition, references, hover) — re-enabled, coexists with codeintel MCP |
| `lua-lsp` | Lua language server for addon development |
| `github` | GitHub MCP server (PRs, issues, code search, reviews) |
| `code-review` | Code review for pull requests |

### Project Memory — `projects/C--Dev-RoleplayCore/memory/`
15 topic files (MEMORY.md + 14 detail files). See MEMORY.md "See Also" section for full list.

### MCP Servers (in `.claude.json` project config)
| Server | Type | Purpose |
|--------|------|---------|
| `wago-db2` | Python/FastMCP | DB2 CSV queries via DuckDB (read-only). **No env var needed** — imports `WAGO_CSV_DIR` from `wago_common` |
| `mysql` | Node.js | Direct MySQL access (read-write) |
| `code-intel` | Python/FastMCP | Hybrid ctags+clangd C++ code intelligence — GitHub: `VoxCore84/code-intel` (private). 8 tools (find_definition, find_references, list_symbols, search_symbol, rebuild_index, hover_info, class_hierarchy, call_hierarchy). 416K symbols, 2,288 files |

---

## 7. WoW Client — `C:/WoW/`

### Retail — `C:/WoW/_retail_/`
| Item | Purpose |
|------|---------|
| `Wow.exe` | 12.x retail client |
| `Arctium Game Launcher.exe` | Connects client to private server (redirects realmlist) |
| `mapextractor.exe` | TC tool — extract maps from client data |
| `vmap4extractor.exe` | TC tool — extract vmaps from client data |
| `vmap4assembler.exe` | TC tool — assemble vmaps |
| `mmaps_generator.exe` | TC tool — generate movement maps |
| `WTF/Config.wtf` | Client config (realmlist, graphics, etc.) |
| `PacketLog/` | Packet capture output (`.pkt` files) |

### Beta — `C:/WoW/_beta_/`
| Item | Purpose |
|------|---------|
| `Arctium Game Launcher.exe` | Beta client launcher |
| `Arctium WoW Sandbox.exe` | Standalone sandbox server (70MB, build 66102 only, does NOT work with private server) |

### `C:/WoW/65867Precompiled/` — DELETED
Old build 65867 VS2022 project. Deleted Feb 27.

---

## 8. MySQL Installations

| Install | Path | Version | Purpose |
|---------|------|---------|---------|
| **UniServerZ** (portable) | `out/build/x64-Debug/bin/Debug/UniServerZ/` | 9.5.0 | Bundled with server runtime, managed via `UniController.exe`. **Primary MySQL for development** |
| **MySQL Server** (system) | `C:/Program Files/MySQL/MySQL Server 8.0/` | 8.0 | System install. `bin/mysql.exe` used as CLI client |
| **MySQL Workbench** | `C:/Program Files/MySQL/MySQL Workbench 8.0/` | 8.0 | GUI client (rarely used) |
| **MySQL Shell** | `C:/Program Files/MySQL/MySQL Shell 8.0/` | 8.0 | Advanced CLI client |
| **MySQL Router** | `C:/Program Files/MySQL/MySQL Router 8.0/` | 8.0 | Connection routing (not actively used) |
| **HeidiSQL** | Downloaded (`~/Downloads/HeidiSQL_12.11.0.7065_Setup.exe`) | 12.11 | SQL GUI — installer only, may not be installed |

---

## 9. WoW Client Addons — `C:/WoW/_retail_/Interface/AddOns/`

80+ addons installed; only custom/diagnostic addons documented here.

| Addon | Source | Purpose |
|-------|--------|---------|
| `TransmogSpy` | `C:/Dev/RoleplayCore/TransmogSpy/` (tracked) | Transmog diagnostic logger — see section 3 for details |

---

## Cleanup Log
- (Feb 27) `sql/exports/` reorganized into `scripts/`, `cleanup/`, `lw_imports/`, `locale/` subdirs
- (Feb 27) Wago `archive/` deleted — 2.2GB of dead batch scripts/SQL
- (Feb 27) Session artifact docs (`AGENT_PROMPTS*.md`, `low_mapping_research.md`) deleted from wago repo
- (Feb 27) `source/repos/` deleted — dead VS2022 workspace caches
- (Feb 27) 36 stray session artifacts cleaned from `AppData/Local/Temp/` (Python/SQL/Lua)

## Remaining Opportunities
- Batch files in repo root use inconsistent naming (`_b.bat` vs `build_rel.bat`)
- HeidiSQL installer sitting in Downloads — install or delete

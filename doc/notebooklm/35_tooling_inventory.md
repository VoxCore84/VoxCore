# VoxCore Custom Tooling Inventory

Master index of all custom scripts, tools, and automation across the project.
Last updated: 2026-03-05.

## 1. Wago Tooling Repo — `~/VoxCore/wago/`

GitHub: `VoxCore84/wago-tooling` (private). Python 3.14.

### Core Data Pipeline
| Script | Purpose |
|--------|---------|
| `wago_common.py` | Shared config module — `CURRENT_BUILD`, `WAGO_CSV_DIR`, `TACT_CSV_DIR`, `WAGO_RAW_CSV_DIR`, MySQL creds. `WAGO_CSV_DIR` auto-points to `merged_csv/` when available. All 14+ consumer scripts import from this |
| `wago_db2_downloader.py` | Download DB2 CSVs from Wago.tools (use `--tables-file tables_all.txt`). **Superseded by `tact_extract.py`** for ground-truth data |
| `tact_extract.py` | **Primary DB2 pipeline**. Bulk-extracts all 1,097 .db2 files from local CASC via TACTSharp, converts to CSV via DBC2CSV, outputs to `tact_csv/`. ~50s total. `--verify` compares vs Wago, `--cdn` for remote, `--db2-only`, `--keep-db2`. Falls back to Wago CSVs for DBC2CSV's ~0.5% non-deterministic drops |
| `merge_csv_sources.py` | **Merge TACT + Wago CSVs** into `merged_csv/`. TACT is base (client ground truth); appends Wago-only rows (CDN hotfix content). Normalizes `[N]` → `_N` array headers. `--dry-run`, `--tables`. 998 TACT-only + 99 merged tables (+7,183 Wago extras) |
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
| `coord_convert.py` | **Primary coord converter** — Wowhead uiMapId + percentage coords → TrinityCore world coords via UiMapAssignment DB2. 1,909 UI maps, 22,494 assignments. Axes SWAPPED + INVERTED. Validated <10 unit accuracy. `convert(uiMapId, x_pct, y_pct)` → `{map_id, x, y, z, area_id}` |
| `coord_transformer.py` | **Fallback coord converter** — Wowhead zone-percent coordinates to world XYZ via AreaTable lookup. Uses nearest-neighbor Z interpolation from 527K existing spawns. 1,856 critical + 1,626 high spawns ready |
| `enrich_content_tuning.py` | Enrich CT=0 creatures via AreaTable zone lookup + neighbor interpolation. Applied to 4,820 of 4,918 spawned creatures |
| `gen_quest_cleanup.py` | Generate quest cleanup SQL |

### Sniffing Pipeline (WPP + parse_sniff + VoxSniffer addon)
| Script | Purpose |
|--------|---------|
| `parse_sniff.py` | **Gap auditor** — scans WPP parsed text for data WPP doesn't output as SQL: creature spells, emotes, auras, levels, QUERY_CREATURE_RESPONSE (ctd enrichment). Generates `sniff_import.sql`. `--gap-only`, `--json`, `--dry-run` |
| `parse_addon_data.py` | Parse VoxSniffer addon SavedVariables (`VoxSnifferDB.lua`). Cross-refs creature type/classification, auras, dialogue, vendor items, quest givers/enders. Generates `addon_import.sql`. Auto-finds SavedVariables |
| `sniff_enrich.py` | **DEPRECATED** — merged into `parse_sniff.py`. Was: creature_template/ctd/equip enrichment from `sniff_parsed.json` |

### Cross-Reference / Validation
| Script | Purpose |
|--------|---------|
| `xref_missing_spawns.py` | Find client-known but server-missing creature/GO spawns |
| `table_hashes.py` | Auto-generated DB2 TableHash mapping (1,121 entries) |
| `extract_table_hashes.py` | Extract TableHash values from .wdc5 file headers |

### Web Scrapers — `~/VoxCore/wago/` (repo: `VoxCore84/wago-tooling`)
| Script | Purpose |
|--------|---------|
| `wowhead_scraper.py` | Multi-entity Wowhead scraper (npc/item/spell/quest/vendor/talent/effect). curl_cffi Chrome131 TLS, 404 miss cache, WAF auto-stop, --pages-only/--tooltip-only two-phase, --randomize, --batch-size/--batch-pause. Python: `python` |
| `import_quest_rewards.py` | Convert scraped quest JSON -> quest_offer_reward + quest_request_items SQL. --ids-file filter, --dry-run |
| `att_parser.py` | Parse ATT Database repo (~/VoxCore/ExtTools/ATT-Database/) Lua files. Extracts quest givers, chains, vendor items, NPC/quest coords. Outputs JSON or SQL |
| `att_to_sqlite.py` | **ATT mega-parser** — extracts ALL ATT data into `att_data.db` (SQLite). 60 tables, 30 loaders, 52.6 MB, 27s. Covers quests, NPCs, items (174K), transmog sets, professions, conduits, runeforge, missing transmog/items/quests, filters (136K RWP), and more. `--stats` for summary, `--skip-supplementary` for Lua-only |
| `att_generate_sql.py` | Cross-ref ATT JSON against TC MySQL, generate validated SQL (INSERT IGNORE + UPDATE). Filters deprecated/DNT quests, validates all IDs |
| `att_crossref.py` | Diagnostic: computes ATT vs TC gap statistics (read-only) |
| `scrape_all_gaps_tor.py` | **Vox Army scraper** — 240 Tor instances, 5 entity types (npc/quest/trainer/vendor/object), curl_cffi TLS fingerprinting, NEWNYM circuit rotation, HTML gzip caching, reparse mode. 1,262 lines. 310K NPCs in ~1hr |
| `qa_pass1_completeness.py` | QA Pass 1: Field completeness analysis across 310K NPC JSONs |
| `qa_pass2_coords.py` | QA Pass 2: Coordinate quality validation (range, origin, duplicates, zone coverage) |
| `qa_pass3_crossref.py` | QA Pass 3: DB cross-reference (gap analysis, priority classification, type verification) |
| `VoxCore_Data_Intelligence_Report.md` | 1,434-line comprehensive report: all 11 data sources, Vox Army specs, optimization roadmap, buildable products, 14 brainstorming questions |
| `vps_scrape_setup.sh` | One-shot VPS setup for remote scraping (DigitalOcean $4/mo droplet) |

### ATT Browser — `~/VoxCore/wago/att_browser/`
| Script | Purpose |
|--------|---------|
| `app.py` | Flask web app at `http://localhost:5050`. Tree navigation, search, detail views, Wowhead tooltips. Dark theme |
| `att.db` | SQLite DB (symlink/copy of `att_data.db`). 438K hierarchy nodes, 1.5M properties |
| `static/icons/` | 186 ATT custom PNGs (converted from addon BLP assets) |
| `static/js/app.js` | 1,300-line JS client — Lua table parsing for providers/cost/coords, patch version formatting, map/event name resolution |
| `wowhead_to_sqlite.py` | Import 310K Wowhead NPC JSONs into SQLite (338 MB, 16 tables, fully indexed). 99s import, 0 errors. Tables: npcs, npc_coords (2M), npc_drops (538K), npc_models (204K), npc_sounds (1.5M), npc_abilities (167K), npc_vendor_items (128K), npc_teaches, npc_quests_started/ended, npc_gossip, npc_skinning, npc_pickpocket, npc_same_model, npc_zones, npc_objective_of |
| `wowhead_npcs.db` | SQLite DB — 338 MB, 309,996 NPCs, 5.1M total rows across 16 tables |
| `static/css/style.css` | WoW quality colors, dark theme, tree/detail layout |

### ATT Icon & Art Export — `~/VoxCore/wago/att_icons_export/`

**Total: 3,006+ files, ~39 GB** (8K_Format). Icons + scenic art extracted from CASC.

| Path | Contents |
|------|----------|
| `8K_Format/wow_icons/large/` | 32,333 PNG icons (upscaled) |
| `8K_Format/scenic_art/boss_portraits/` | 1,225 encounter journal boss portraits |
| `8K_Format/scenic_art/loading_screens/` | 313 loading screen art (narrow) |
| `8K_Format/scenic_art/loading_screens_wide/` | 65 wide loading screens |
| `8K_Format/scenic_art/dungeon_backgrounds/` | 196 dungeon/raid panoramas |
| `8K_Format/scenic_art/dungeon_buttons/` | 195 instance thumbnails |
| `8K_Format/scenic_art/lore_backgrounds/` | 195 journal lore art |
| `8K_Format/scenic_art/credits_art/` | 404 per-expansion credits slides (6 expansions) |
| `8K_Format/scenic_art/credits_keyart/` | 25 iconic expansion keyart + backgrounds (Vanilla→Midnight) |
| `8K_Format/scenic_art/quest_backgrounds/` | 53 zone-themed quest frame art (SL/DF/TWW/MN) |
| `8K_Format/scenic_art/talent_backgrounds/` | 34 class spec painted backgrounds |
| `8K_Format/scenic_art/expansion_logos/` | 47 WoW expansion logos |
| `8K_Format/scenic_art/covenant_choice/` | 9 Shadowlands covenant selection art |
| `8K_Format/scenic_art/store_art/` | 47 cherry-picked shop/promo scenic art |
| `8K_Format/scenic_art/by_expansion/` | 198 files sorted by expansion (DF/TWW/MN) |

**Scripts**: `extract_scenic_art.py` (original 6 categories), `extract_missing_scenic.py` (6 new categories). Both use TACTSharp + Pillow BLP→PNG. Some newer BLP encoding 3 files kept as .blp (need wow-export for conversion).

### ATT Compiled Addon Parser
| Script | Purpose |
|--------|---------|
| `att_parse_addon.py` | Parses compiled Categories/*.lua from ATT addon. Builds hierarchy_nodes + node_properties tables. Resolves header names, icons (FileDataID + ATT assets), entity labels. 438K nodes, 1.5M props |

**ATT parser quick-ref**:
1. `att_to_sqlite.py` → `att_data.db` (60 tables, 52.6 MB, 27s full rebuild)
2. `att_parse_addon.py` → hierarchy + properties into att_data.db (438K nodes)
3. Copy `att_data.db` → `att_browser/att.db`, then `python att_browser/app.py --port 5050`
4. Legacy: `att_parser.py` → JSON → `att_generate_sql.py` → SQL (original pipeline, still works)

### Cross-Source Data Mining — `~/VoxCore/wago/`
| Script | Purpose |
|--------|---------|
| `quest_integrity_compiler.py` | Cross-source quest chain validation. Loads MySQL (10 tables), Wowhead SQLite (4 tables), ATT SQLite (3 tables), BtWQuests JSON (2,329 chains). Per-quest analysis: starters, enders, spawn status, chain links, confidence score (0-100). Output: report.md, details.csv, repairs.sql. 47,841 quests analyzed, 4,456 repairs |
| `spawn_safety_scorer.py` | Confidence scoring (0-100) for 144,544 unspawned NPCs. 11 dimensions: quest involvement, boss class, instance-only, source count, z confidence, coord count, vendor/trainer/smartai/loot/ctd. Tiers: SAFE(>=70)/REVIEW(>=45)/RISKY(>=25)/BLOCKED. Output: report.md, scored.csv |
| `btwquests_untapped.py` | Mines unused BtWQuests addon Lua (reputation rewards, ContentTuningID), cross-refs ATT chains (24,899 links) + BtWQuests chains (2,329), extracts Wowhead SQLite queststarter/ender gaps. 5,305 repairs total |
| `att_mega_extract.py` | **14-category** ATT extraction. Quest providers, object quests, quest givers, exclusive groups, NPC/object loot, encounter creatures, encounter loot, quest rewards, faction gates, timeline, NPC coords, world events, Wowhead vendors. 443 unique SQL (599 faction gates, 18 boss upgrades, 4 GO queststarters). Output: sql + report.md |
| `att_faction_map.py` | Maps 65 ATT `FACTION_XXX` string names to DB faction IDs. Auto-generated from Wago Faction-enUS.csv |
| `gen_addon_patch.py` | Generates INSERT IGNORE for missing quest_template_addon rows, then re-applies chain UPDATE statements that would otherwise silently fail |
| `mine_att_quest_metadata.py` | ATT quest metadata: breadcrumb/daily/weekly/race flags cross-ref against quest_template/addon |
| `mine_removed_quests_events.py` | Two-part: flag 3,702 removed quests as deprecated + insert 38 missing game events (94 blocked by tinyint limit) |
| `mine_wowhead_npc_data.py` | 7-pass Wowhead/ATT cross-ref: creature spells (161K), loot (105K), trainers (4K), vendors (15K), skinning (4), pickpocket (2.4K). Validates all IDs |
| `mine_quest_object_data.py` | Quest POI from ATT coords (1,050 points) + GO spawns (1,161) + GO quest links + gossip gap report |
| `generate_safe_spawns.py` | 7-step spawn pipeline: safety CSV → ATT/Wowhead coords → coord_convert → Z interpolation → creature INSERT. 28,665 spawns, 98.5% Z coverage. `--dry-run`, `--min-score`, `--max-spawns` flags |

**Scraper quick-ref** — two-phase for speed (~2hr for 27K quests):
1. `--tooltip-only --randomize --threads 4 --delay 0.1` (nether API, 10 req/s)
2. `--pages-only --randomize --threads 3 --delay 0.2 --batch-size 5000 --batch-pause 120` (pages, 5 req/s)
3. `import_quest_rewards.py --ids-file <list>` to generate SQL

### Raidbots Data Pipeline — `~/VoxCore/wago/raidbots/`
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
| `tact_csv/12.0.1.66263/enUS/` | **Current build** TACT-extracted CSVs (1,094 tables). **Source**: local CASC ground truth. Deterministic, no Wago oscillation. Use for diffs/hotfix repair |
| `merged_csv/12.0.1.66263/enUS/` | **Current build** merged CSVs (1,094 tables) — used by `wago_common.WAGO_CSV_DIR`. TACT base + Wago extras (when available) |
| `wago_csv/major_12/12.0.1.66220/enUS/` | Previous build Wago CSVs (1,097 tables) |
| `tact_csv/12.0.1.66220/enUS/` | Previous build TACT CSVs (1,097 tables, 772MB) |
| `wago_csv/major_12/12.0.1.66192/enUS/` | Previous build CSVs (used as diff baseline by `diff_builds.py`) |
| `wago_csv/major_12/12.0.1.66102/enUS/` | Older build CSVs (166K items) — preferred by transmog_debug.py for item coverage |
| `wago_csv/major_12/12.0.1.66066/enUS/` | Oldest build (reference) |
| `lw_world_imports/` | Extracted SQL from LoreWalkerTDB |
| `wowhead_data/{spell,item,npc,quest,vendor}/raw/` | Cached Wowhead JSON |
| `raidbots/` | Raidbots static JSON (47 files, 168MB) + import scripts + sql_output/ |
| `raidbots/sql_output/` | Generated SQL files (locales, chains, POI, objectives, fixes) |

---

## 2. SQL Exports — `~/VoxCore/sql/exports/`

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

## 3. Repo Root — `~/VoxCore/`

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
| `spell_creator.py` | **Interactive spell creation CLI** — 11 templates (mount/damage/heal/DoT/HoT/teleport/visual/learn/dummy), full clone from wago CSV (26 SpellEffect fields + SpellXSpellVisual), hotfix SQL generation with correct table hashes. Output: clipboard, SQL update file, direct DB apply, or apply+SOAP reload. Also: icon search (32K+), enum reference, table hash viewer. Launcher: `tools/shortcuts/spell_creator.bat`. Replaces old .NET SpellCreator (session 95) |
| `packet_scope.py` | WPP packet log parser — streams World_parsed.txt, extracts transmog packets/addon/UPDATE_OBJECT into report. Dynamic SQL glob, `--pkt-dir` CLI arg. Auto-called by `start-worldserver.sh` on exit |
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

### Published Gists
| Gist | ID | Content |
|------|----|---------|
| DB Report | `528e801b53f6c62ce2e5c2ffe7e63e29` | Comprehensive database engineering report (Parts 1-16) |
| Changelog | `4c63baf8154753d2a89475d9a4f5b2cc` | Session-by-session changelog |
| Open Issues | `2b69757faa2a53172c7acb5bfa3ad3c4` | Prioritized issue tracker + roadmap |
| Transmog Wiki | `88ba6320d249b5758753ecb954b0ded2` | 3,487-line client Lua reference + cheatsheet |
| Packet Analysis | `a86d3dc8c88839c5f8aafef5908a9d5f` | opcode_analyzer + transmog packet extractor |
| `reference/` | 22 project reference files (memory mirror) — tracked in git |

### TransmogBridge/ (tracked — also has own repo)
GitHub: `VoxCore84/TransmogBridge` (public). WoW 12.x addon patching client serializer bug.

### TransmogSpy/ (tracked, committed `bfe9f61e51`)
WoW client addon for transmog diagnostic logging. Source: `~/VoxCore/TransmogSpy/`, installed to `C:/WoW/_retail_/Interface/AddOns/TransmogSpy/` (manual copy).

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

## 4. ~/VoxCore/ExtTools/ — Third-Party Tools & Reference Data

| Tool | Path | Purpose |
|------|------|---------|
| **WowPacketParser** | `~/VoxCore/ExtTools/WowPacketParser/WowPacketParser.exe` | Parse `.pkt` packet captures into SQL/text. **Nightly build** with 66263 support. Generates `*_hotfixes.sql`, `*_world.sql`, `*_wpp.sql` output |
| **WowPacketParser-src** | `~/VoxCore/ExtTools/WowPacketParser-src/` | WPP C# source repo (for custom opcode patches / rebuilds). Build: `dotnet build -c Release`. Solution: `WowPacketParser.sln` |
| **WowPacketParser (66220 backup)** | `~/VoxCore/ExtTools/WowPacketParser_66220_backup/` | Previous WPP build (locally patched for 66220). Kept as reference |
| **wow.tools.local** | `~/VoxCore/ExtTools/WoW.tools/` | v0.9.2, local web UI for browsing DB2/DBC files. Serves on `http://localhost:5000`. Config: `config.json` (wowFolder=`C:\WoW`, product=wow, region=us). Includes `WTL.db` (765MB file history) + `hotfixes.db` (193MB). Reads CASC from local WoW install (build 66263). Use for: DB2 browsing, build diffs, hotfix inspection, file extraction, map viewer. **Launcher**: `start_wtl.bat` (polls until ready, opens browser). **Python client**: `wtl_client.py` in wago repo |
| **lua-language-server** | `~/VoxCore/ExtTools/lua-language-server/` | Lua LSP server for addon development diagnostics |
| **DBCD** | `~/VoxCore/ExtTools/DBCD-2.2.0/` | C# library for reading/writing WoW DB2/DBC binary files (WDBC through WDC5). Supports hotfix application (DBCache.bin). .NET solution, builds with `dotnet build`. Used by DBC2CSV and DB2Query |
| **DB2Query** | `~/VoxCore/ExtTools/DB2Query/` | Interactive CLI tool built on DBCD. Commands: load, get, search, filter, head, cols, count, dump, export, crossref, crossref-all. Used for hotfix cross-reference audits against retail DB2 binary data. `dotnet run -c Release` |
| **DBC2CSV** | `~/VoxCore/ExtTools/DBC2CSV/DBC2CSV.exe` | Convert DBC/DB2 files to CSV. 1,315 .dbd definitions in `definitions/`. **Quirk**: drops ~0.5% of files non-deterministically in large folder batches (retry or Wago fallback needed) |
| **TACTSharp** | `~/VoxCore/ExtTools/TACTSharp/` | C# CASC extraction library + CLI (`TACTTool`). Bulk-extracts .db2 files from local WoW install or Blizzard CDN. Build: `dotnet build TACTTool -c Release`. Exe: `TACTTool/bin/Release/net10.0/TACTTool.exe`. Used by `tact_extract.py` |
| **ATT-Database** | `~/VoxCore/ExtTools/ATT-Database/` | AllTheThings addon database repo (Lua data files). Parsed by `att_parser.py` for quest givers, chains, vendor items, NPC/quest coords |
| **Ymir** | `~/VoxCore/ExtTools/ymir_retail_12.0.1.66263/ymir_retail.exe` | Retail sniffer (build 66263). Does NOT work with private server |
| **LoreWalkerTDB** | `~/VoxCore/ExtTools/LoreWalkerTDB/` | LoreWalkerTDB reference DB dump — `world.sql` (897MB), `hotfixes.sql` (322MB) |
| **TrinityCore-master** | `~/VoxCore/ExtTools/TrinityCore-master/` | Stock TrinityCore source reference (upstream comparison) |
| **community-listfile** | `~/VoxCore/ExtTools/community-listfile-withcapitals.csv` | 2.1M FileDataID→filepath mappings from `wowdev/wow-listfile` (GitHub releases, updated daily). Resolves DB2 FileDataID columns to human-readable paths (models, textures, sounds, maps). 143 MB CSV, format: `FileDataID;Path`. 99 DB2 tables with 169 FileDataID columns reference it. Update: `gh release download <tag> --repo wowdev/wow-listfile --pattern "community-listfile-withcapitals.csv" --dir /c/Users/atayl/VoxCore/ExtTools/ --clobber` |
| **Transmog_DeepDive** | `~/VoxCore/ExtTools/Transmog_DeepDive/` | Comprehensive transmog reference: `source_lua/` (35 files — all curated transmog Lua/XML + 11 new files inc. TransmogOutfitConstantsDocumentation, Blizzard_SavedSets, DressUpFrames, CollectionsUtil), `db2_csv/` (3 new 12.x DB2s: TransmogOutfitEntry, TransmogOutfitSlotInfo, TransmogOutfitSlotOption), `dev_addons_reference/` (4 internal Blizzard dev addons — FileDataIDs documented but NOT extractable from retail CASC) |
| **wow-export** | `~/VoxCore/ExtTools/wow-export/` | Full WoW asset extractor (Electron GUI). Exports textures (PNG/WebP), 3D models (OBJ/GLB/GLTF/STL), characters, maps, audio, video, DB2 tables. Built-in 3D viewer (WebGL2), Blender addon. App: `%LOCALAPPDATA%\wow.export\wow.export.exe`. Config: `User Data/Default/config.json` (overrides only). Reads from `C:\WoW` CASC |
| **website-assets** | `~/VoxCore/ExtTools/website-assets/` | VoxCore website asset pipeline. `configure_wowexport.py` (auto-config wow-export for web), `export_checklist.md` (83 assets), `post_process.py` (categorize/optimize/thumbnail/preview). Outputs to `raw_exports/` → `~/VoxCore/website/static/images/` |
| **wow-ui-source-live** | `~/VoxCore/ExtTools/wow-ui-source-live/` | Blizzard WoW UI Lua/XML source (Interface/ tree) |
| **Transmog_UI_LUAs** | `~/VoxCore/ExtTools/Transmog_UI_LUAs/` | Curated transmog-related Blizzard Lua files (quick reference subset of wow-ui-source-live) |
| **docs** | `~/VoxCore/ExtTools/docs/` | Analysis/reference markdown docs (transmog bridge, etc.) |

---

## 5. Source Repos — `~/VoxCore/tools-dev/`

### tc-packet-tools — `~/VoxCore/tools-dev/tc-packet-tools/`
GitHub: `VoxCore84/tc-packet-tools` (private). Server launcher wrapper + WPP automation. Scripts are copied to `bin/RelWithDebInfo/` at runtime.

| File | Purpose |
|------|---------|
| `start-worldserver.sh` | Full session lifecycle: (1) archive previous session, (2) launch bnet+worldserver with EXIT trap, (3) WPP on exit, (4) `parse_sniff.py` gap analysis, (5) `packet_scope.py`, (6) `parse_addon_data.py` (VoxSniffer addon), (7) single-pass awk summary. `--parse <file.pkt>` mode for standalone retail sniffs. Propagates worldserver exit code |
| `wpp-add-build.sh` | Add new WoW build to WPP's 3 switch statements (`GetOpcodeDefiningBuild`, `GetUpdateFieldDictionaryBuildName`, `GetVersionDefiningBuild`). Uses contiguous-group detection to insert in correct function. Rebuilds WPP with `dotnet build`, copies output. Detects already-present builds |
| `wpp-inspect.sh` | Quick-grep utility for `World_parsed.txt`. Commands: `visible [slot]`, `transmog` (capped at 500 lines + count), `trace <pattern>`, `summary`, `opcodes`, `search <pattern>`. Uses `set -u` (no pipefail — breaks grep no-match) |
| `WowPacketParser.dll.config.template` | WPP config template for 12.x builds |

**Key design notes**:
- WPP output format: opcodes prefixed with `ServerToClient: SMSG_` / `ClientToServer: CMSG_` (not bare opcode names)
- Player GUIDs in parsed output: `Player/0 R1/S0 Map: N Low: N` (not `Player-N-NNNN` which is GM.log format)
- GM commands only in `GM.log` (chat text not in WPP parsed output)
- No `bc` on Windows — all float math uses `awk`
- `-oP` (Perl regex) fails on Windows locale — use `-oE` (extended regex) instead

### VoxSniffer Addon — `~/VoxCore/tools-dev/VoxSniffer/`
WoW addon for passive NPC data capture via client Lua APIs (~60yd nameplate range). Captures data Ymir/WPP miss: creature type/family/level/classification, auras, NPC dialogue (say/yell/emote/whisper), vendor inventory, gossip menus, quest giver/ender associations. All data to `VoxSnifferDB` SavedVariables. Parsed by `parse_addon_data.py`.

| File | Purpose |
|------|---------|
| `VoxSniffer.toc` | TOC file (Interface: 120000, SavedVariables: VoxSnifferDB) |
| `Core.lua` | Main addon code — nameplate scanning, chat events, merchant/gossip/quest hooks |

### code-intel — `~/VoxCore/tools-dev/code-intel/`
GitHub: `VoxCore84/code-intel` (private). Hybrid ctags+clangd MCP server for C++ code intelligence. 3 files: `code_intel_server.py`, `ctags_index.py`, `clangd_client.py`. See section 6 MCP Servers for tool details.

### Public Extraction Repos (stale snapshots — candidates for archive/delete)

**`VoxCore84/tc-npc-audit`** (public) — 20 individual audit scripts (old architecture). **Superseded** by the monolithic `npc_audit.py` (2,727 lines) in wago-tooling. Single commit, never updated.

**`VoxCore84/wago-pipeline`** (public) — Raidbots scripts + wowhead_scraper.py snapshot. **Stale** — local wowhead_scraper.py is ~6KB larger. Single commit, never updated.

### trinitycore-claude-skills — `~/VoxCore/tools-dev/claude-skills/`
GitHub: `VoxCore84/trinitycore-claude-skills` (private). 17 Claude Code slash command skills for TrinityCore development. Installed to `.claude/commands/` in the project.

| Category | Skills |
|----------|--------|
| Build & Dev | `build-loop`, `new-script`, `new-sql-update` |
| Server Ops | `check-logs`, `parse-errors`, `apply-sql`, `soap` |
| Packet Analysis | `decode-pkt`, `parse-packet` |
| Data Lookups | `lookup-spell`, `lookup-item`, `lookup-creature`, `lookup-area`, `lookup-faction`, `lookup-emote`, `lookup-sound` |
| Validation | `smartai-check` |

### Reference Clones — DELETED
`~/source/repos/` contained dead VS2026 workspace caches (no real code). Deleted Feb 27.

---

## 6. Claude Code Config

### Global — `~/.claude/`
| File | Purpose |
|------|---------|
| `settings.json` | Permissions, plugins, env vars (agent teams enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`) |
| `statusline-command.sh` | Status bar: model, context %, cost |
| `scripts/msvc_env.sh` | MSVC environment setup for CLI builds |

### Project — `~/VoxCore/.claude/`
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

### Project Memory — `projects/C--Users-atayl-VoxCore/memory/`
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
Old build 65867 VS2026 project. Deleted Feb 27.

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
| `TransmogSpy` | `~/VoxCore/TransmogSpy/` (tracked) | Transmog diagnostic logger — see section 3 for details |

---

## Cleanup Log
- (Feb 27) `sql/exports/` reorganized into `scripts/`, `cleanup/`, `lw_imports/`, `locale/` subdirs
- (Feb 27) Wago `archive/` deleted — 2.2GB of dead batch scripts/SQL
- (Feb 27) Session artifact docs (`AGENT_PROMPTS*.md`, `low_mapping_research.md`) deleted from wago repo
- (Feb 27) `source/repos/` deleted — dead VS2026 workspace caches
- (Feb 27) 36 stray session artifacts cleaned from `AppData/Local/Temp/` (Python/SQL/Lua)

## Remaining Opportunities
- Batch files in repo root use inconsistent naming (`_b.bat` vs `build_rel.bat`)
- HeidiSQL installer sitting in Downloads — install or delete

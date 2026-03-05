# RoleplayCore — Operations Runbook

Complete reference for every tool, pipeline, and command in the project. Organized by workflow.

**Python**: `C:\Python314\python.exe` | **MySQL**: `mysql -u root -padmin` | **Wago tooling**: `C:/Users/atayl/source/wago/`

---

## Table of Contents

1. [Server Operations](#1-server-operations)
2. [Building the Server](#2-building-the-server)
3. [Claude Skills (slash commands)](#3-claude-skills)
4. [ATT Import (quest givers, chains, vendors)](#4-att-import)
5. [Quest Reward Text Scrape](#5-quest-reward-text-scrape)
6. [Missing NPC Spawns](#6-missing-npc-spawns)
7. [Hotfix Repair (build bump)](#7-hotfix-repair)
8. [Raidbots Data Pipeline](#8-raidbots-data-pipeline)
9. [LoreWalkerTDB Import](#9-lorewalker-tdb-import)
10. [Wowhead Scraper (general)](#10-wowhead-scraper)
11. [NPC/Creature Audit](#11-npc-creature-audit)
12. [Transmog Tools](#12-transmog-tools)
13. [Packet Analysis](#13-packet-analysis)
14. [Database Snapshots & Health](#14-database-snapshots--health)
15. [Build Diff Audit](#15-build-diff-audit)
16. [Content Tuning Enrichment](#16-content-tuning-enrichment)
17. [TACT DB2 Extraction](#17-tact-db2-extraction)
18. [DB2 Query Tools](#18-db2-query-tools)
19. [C:/Tools Reference](#19-ctools-reference)
20. [GitHub Repos & Gists](#20-github-repos--gists)
21. [One-Time Setup SQL](#21-one-time-setup-sql)
22. [Quick Reference One-Liners](#22-quick-reference-one-liners)

---

## 1. Server Operations

```bash
# Start servers (from runtime dir)
cd C:/Dev/RoleplayCore/out/build/x64-RelWithDebInfo/bin/RelWithDebInfo
./bnetserver.exe &
./worldserver.exe

# SOAP command (in-game admin without logging in)
# Via Claude: /soap .reload all
# Manual:
curl --data '<?xml version="1.0"?><methodCall><methodName>executeCommand</methodName><params><param><value><string>.reload all</string></value></param></params></methodCall>' http://admin:admin@localhost:7878

# Check server logs
tail -f Server.log          # Main server log
tail -f DBErrors.log        # Database errors
tail -f Debug.log           # Verbose debug output (if enabled)

# Parse DBErrors into categorized report
C:\Python314\python.exe C:/Dev/RoleplayCore/tools/parse_dberrors.py
```

**Log locations**: `C:/Dev/RoleplayCore/out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/`
**Config**: `worldserver.conf` in same directory (NOT in source tree)

---

## 2. Building the Server

```bash
# Quick incremental build (most common)
cd C:/Dev/RoleplayCore/out/build/x64-RelWithDebInfo && ninja -j20

# Scripts only (faster, for script-only changes)
ninja -j20 scripts

# Full CMake reconfigure + build
cmake -B out/build/x64-RelWithDebInfo -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -DSCRIPTS=static -DELUNA=ON -DTOOLS=ON
cd out/build/x64-RelWithDebInfo && ninja -j20

# Debug build
cd C:/Dev/RoleplayCore/out/build/x64-Debug && ninja -j20
```

**Batch files** (in `tools/build/`): `_b.bat` (quick), `_bs.bat` (scripts only), `_b_reconfig.bat` (full reconfigure)
**Via Claude**: `/build-loop` runs build + auto-fixes errors

---

## 3. Claude Skills

17 slash commands available in Claude Code sessions:

| Command | What it does |
|---------|-------------|
| `/build-loop` | Build, check errors, auto-fix, repeat |
| `/check-logs` | Parse Server.log, DBErrors.log, Debug.log |
| `/parse-errors` | Categorize DBErrors.log by error type |
| `/apply-sql` | Apply a SQL file to any database |
| `/soap` | Send SOAP command to running worldserver |
| `/lookup-spell` | Search spell by ID or name |
| `/lookup-item` | Search item by ID or name |
| `/lookup-creature` | Search creature by ID or name |
| `/lookup-area` | Search area/zone by ID or name |
| `/lookup-faction` | Search faction by ID or name |
| `/lookup-emote` | Search emote by ID or name |
| `/lookup-sound` | Search SoundKit by ID |
| `/decode-pkt` | Decode binary packet log |
| `/parse-packet` | Analyze packet capture with opcode dictionary |
| `/new-script` | Scaffold new C++ custom script + register |
| `/new-sql-update` | Create next-numbered SQL update file |
| `/smartai-check` | Validate SmartAI SQL against known enums |

---

## 4. ATT Import

**What**: Parse AllTheThings community database -> fill missing quest givers, quest chains, vendor items.

```bash
cd C:/Tools/ATT-Database && git pull
cd C:/Users/atayl/source/wago

# Parse (30s)
C:\Python314\python.exe att_parser.py --repo C:/Tools/ATT-Database --output att_data.json

# Generate validated SQL
C:\Python314\python.exe att_generate_sql.py --data att_data.json --output att_validated.sql

# Apply
mysql -u root -padmin world < att_validated.sql

# Stats only (no SQL)
C:\Python314\python.exe att_generate_sql.py --data att_data.json --dry-run
```

**Tables**: `creature_queststarter`, `quest_template_addon`, `npc_vendor`
**Safe to re-run**: Yes

---

## 5. Quest Reward Text Scrape

**What**: Scrape Wowhead for NPC turn-in dialogue (`quest_offer_reward.RewardText`). Server-side only data.

```bash
cd C:/Users/atayl/source/wago

# Generate missing ID list
mysql -u root -padmin world -N -e "
  SELECT qt.ID FROM quest_template qt
  LEFT JOIN quest_offer_reward qor ON qor.ID = qt.ID
  WHERE qor.ID IS NULL AND qt.ID > 0 AND qt.ID < 100000
  ORDER BY qt.ID" > quest_ids_missing_reward.txt

# Phase A: Tooltips (fast, filters 404s)
C:\Python314\python.exe wowhead_scraper.py quest \
  --ids-file quest_ids_missing_reward.txt \
  --tooltip-only --randomize --threads 4 --delay 0.1 \
  --batch-size 5000 --batch-pause 120 --resume --verbose

# Phase B: Full pages (gets reward text)
C:\Python314\python.exe wowhead_scraper.py quest \
  --ids-file quest_ids_missing_reward.txt \
  --pages-only --randomize --threads 3 --delay 0.2 \
  --batch-size 5000 --batch-pause 120 --resume --verbose

# Convert JSON -> SQL
C:\Python314\python.exe import_quest_rewards.py \
  --ids-file quest_ids_missing_reward.txt --output quest_rewards.sql

# Apply
mysql -u root -padmin world < quest_rewards.sql
```

**Tables**: `quest_offer_reward`, `quest_request_items`
**VPS option**: `vps_scrape_setup.sh` for DigitalOcean droplet (~$0.07)

---

## 6. Missing NPC Spawns

**What**: Transform Wowhead zone-percent coordinates to world XYZ, generate creature spawn INSERTs.

```bash
cd C:/Users/atayl/source/wago

C:\Python314\python.exe coord_transformer.py --tier critical    # Quest NPCs
C:\Python314\python.exe coord_transformer.py --tier high        # Service NPCs

# Review output, then apply
mysql -u root -padmin world < coord_transformer_output.sql
```

**Tables**: `creature`
**Needs review**: Yes — spot-check coordinates in-game

---

## 7. Hotfix Repair

**What**: Repair hotfix tables by comparing DB2 CSVs against MySQL. Run after every WoW client build update.

```bash
cd C:/Users/atayl/source/wago

# Step 1: Edit CURRENT_BUILD in wago_common.py

# Step 2: Extract fresh CSVs (preferred — ground truth from local CASC)
C:\Python314\python.exe tact_extract.py
# OR download from Wago (fallback)
C:\Python314\python.exe wago_db2_downloader.py --tables-file tables_all.txt

# Step 3: Run repair (5 batches)
for i in 1 2 3 4 5; do
  C:\Python314\python.exe repair_hotfix_tables.py --batch $i
  mysql -u root -padmin hotfixes < repair_batch_${i}.sql
done

# Redundancy audit (after repair — removes DBC-duplicate rows)
C:\Python314\python.exe hotfix_audit/hotfix_differ_r3.py
C:\Python314\python.exe hotfix_audit/gen_practical_sql_r3.py
C:\Python314\python.exe hotfix_audit/cleanup_hotfix_data_orphans.py
```

**Tables**: All `hotfixes.*` tables

---

## 8. Raidbots Data Pipeline

**What**: Download Raidbots JSON data, import item names, quest chains, quest POI, locale text.

```bash
cd C:/Users/atayl/source/wago

# Full pipeline (downloads JSON + generates SQL)
C:\Python314\python.exe raidbots/run_all_imports.py --regenerate

# Apply all generated SQL
mysql -u root -padmin world < raidbots/sql_output/quest_chains.sql
mysql -u root -padmin world < raidbots/sql_output/quest_poi_import.sql
mysql -u root -padmin world < raidbots/sql_output/quest_poi_points_import.sql
mysql -u root -padmin world < raidbots/sql_output/quest_objectives_import.sql
mysql -u root -padmin hotfixes < raidbots/sql_output/item_sparse_locale.sql
mysql -u root -padmin hotfixes < raidbots/sql_output/item_search_name_locale.sql
```

**Tables**: `quest_template_addon`, `quest_poi`, `quest_poi_points`, `quest_objectives`, `item_sparse_locale`, `item_search_name_locale`

---

## 9. LoreWalker TDB Import

**What**: Bulk import from LoreWalkerTDB reference dump (941 MB world, 337 MB hotfixes). 5-phase pipeline.

```bash
cd C:/Users/atayl/source/wago

# Extract tables from LW dump (one-time)
C:\Python314\python.exe extract_lw_world.py

# Fix column mismatches (LW uses different column counts)
C:\Python314\python.exe lw_world_imports/fix_column_mismatch.py

# Run full import (5 phases)
C:\Python314\python.exe lw_world_imports/import_all.py

# Validate results
C:\Python314\python.exe lw_world_imports/validate_import.py
C:\Python314\python.exe world_health_check.py
```

**Source data**: `C:/Tools/LoreWalkerTDB/`

---

## 10. Wowhead Scraper

**What**: Multi-entity Wowhead scraper with curl_cffi Chrome131 TLS fingerprinting.

```bash
cd C:/Users/atayl/source/wago

# By ID range
C:\Python314\python.exe wowhead_scraper.py npc --start 1 --end 1000 --threads 2 --delay 0.5 --resume

# From ID file
C:\Python314\python.exe wowhead_scraper.py item --ids-file my_ids.txt --threads 2 --delay 0.5 --resume

# Two-phase (fast)
C:\Python314\python.exe wowhead_scraper.py quest --ids-file ids.txt --tooltip-only --threads 4 --delay 0.1 --resume
C:\Python314\python.exe wowhead_scraper.py quest --ids-file ids.txt --pages-only --threads 3 --delay 0.2 --resume
```

**Entity types**: `npc`, `item`, `spell`, `quest`, `vendor`, `talent`, `effect`
**Key flags**: `--resume`, `--verbose`, `--force`, `--randomize`, `--batch-size N --batch-pause N`

---

## 11. NPC/Creature Audit

**What**: Cross-reference creatures against Wago DB2, Wowhead, and LoreWalkerTDB.

```bash
cd C:/Users/atayl/source/wago

# Full NPC audit (names, levels, vendors, class/race)
C:\Python314\python.exe npc_audit.py

# Placement audit (find missing/misplaced/extra spawns vs LW reference)
C:\Python314\python.exe creature_placement_audit.py
C:\Python314\python.exe go_placement_audit.py

# Duplicate spawn detection
C:\Python314\python.exe find_dupe_spawns.py

# Name fixes (placeholder names vs Wago)
C:\Python314\python.exe npc_audit_fixes/gen_names_fixes.py

# Quest audit
C:\Python314\python.exe quest_audit.py
```

**Output**: Reports + SQL fix files in `creature_placement_fixes/`, `go_placement_fixes/`

---

## 12. Transmog Tools

**What**: Debug and validate the transmog/outfit system.

```bash
cd C:/Users/atayl/source/wago

# Lookup item -> appearance chain
C:\Python314\python.exe transmog_lookup.py --item 12345

# Full character transmog state
C:\Python314\python.exe transmog_debug.py --name "CharacterName"

# Validate client vs server transmog data
C:\Python314\python.exe validate_transmog.py

# Cross-ref DBCache.bin vs server hotfixes
C:\Python314\python.exe xref_dbcache.py
```

**Addon**: [TransmogBridge](https://github.com/VoxCore84/TransmogBridge) — install in `Interface/AddOns/`

---

## 13. Packet Analysis

**What**: Parse WoW packet captures for debugging opcodes and protocol.

```bash
# Capture packets (stop server first, then copy .pkt files)
# Parse with WowPacketParser
C:/Tools/WowPacketParser/WowPacketParser.exe <file.pkt>

# Analyze opcodes
C:\Python314\python.exe C:/Dev/RoleplayCore/tools/opcode_analyzer.py \
  --input World_parsed.txt --opcodes C:/Dev/RoleplayCore/src/server/game/Server/Protocol/Opcodes.h

# Extract transmog packets
C:\Python314\python.exe C:/Dev/RoleplayCore/tools/extract_transmog_packets.py
```

**Important**: Stop the server before WPP can read .pkt files

---

## 14. Database Snapshots & Health

```bash
cd C:/Users/atayl/source/wago

# Snapshot before risky operations
C:\Python314\python.exe db_snapshot.py --db world --reason "pre-import"

# List snapshots
ls snapshots/*.sql.gz

# World DB health check (referential integrity)
C:\Python314\python.exe world_health_check.py

# Optimize large tables
C:/Dev/RoleplayCore/tools/_optimize_db.bat
```

---

## 15. Build Diff Audit

**What**: Compare Wago DB2 CSVs across WoW client builds to find content changes.

```bash
cd C:/Users/atayl/source/wago

C:\Python314\python.exe diff_builds.py --old 66198 --new 66220
C:\Python314\python.exe cross_ref_mysql.py --build 66220
```

---

## 16. Content Tuning Enrichment

**What**: Assign ContentTuningID to creatures with CT=0 using zone lookup + nearest-neighbor interpolation.

```bash
cd C:/Users/atayl/source/wago

C:\Python314\python.exe enrich_content_tuning.py
mysql -u root -padmin world < sql_output/enrich_content_tuning.sql
```

---

## 17. TACT DB2 Extraction (ground truth CSVs)

**What**: Extract all 1,097 DB2 tables from local WoW CASC install via TACTSharp + DBC2CSV. Produces ground-truth CSVs (no Wago oscillation artifacts). ~50 seconds.

```bash
cd C:/Users/atayl/source/wago

# Full extraction (CASC -> DB2 -> CSV)
C:\Python314\python.exe tact_extract.py

# Verify against Wago CSVs (shows row count diffs)
C:\Python314\python.exe tact_extract.py --verify

# Extract DB2 files only (skip CSV conversion)
C:\Python314\python.exe tact_extract.py --db2-only --keep-db2

# From Blizzard CDN instead of local install
C:\Python314\python.exe tact_extract.py --cdn
```

**Output**: `tact_csv/12.0.1.XXXXX/enUS/*.csv` (772 MB for 1,097 tables)
**Dependencies**: `C:/Tools/TACTSharp/` + `C:/Tools/DBC2CSV/`
**When to run**: After WoW client updates, before hotfix repair

---

## 18. DB2 Query Tools

**What**: Interactive query tools for browsing WoW DB2 data.

```bash
# MCP Server (used by Claude automatically — 6 tools)
# Already configured in .claude/settings.json, no manual start needed

# Interactive CLI query tool
cd C:/Tools/DB2Query && dotnet run -c Release
# Commands: load, get, search, filter, head, cols, dump, export, tables

# wow.tools.local web UI (visual DB2 browser)
C:/Tools/WoW.tools/start_wtl.bat
# Opens http://localhost:5000

# Cross-ref DBCache.bin vs server hotfixes
cd C:/Users/atayl/source/wago
C:\Python314\python.exe xref_dbcache.py

# Decode DBCache.bin to human-readable
C:\Python314\python.exe decode_dbcache.py
```

---

## 19. C:/Tools Reference (all external tools)

| Tool | Path | Purpose |
|------|------|---------|
| **wow.tools.local** | `C:/Tools/WoW.tools/start_wtl.bat` | Web UI: DB2 browser, hotfix viewer, build diffs (`http://localhost:5000`) |
| **WowPacketParser** | `C:/Tools/WowPacketParser/WowPacketParser.exe` | Parse .pkt packet captures |
| **TACTSharp** | `C:/Tools/TACTSharp/` | CASC bulk extractor (C#). Used by `tact_extract.py`. Build: `dotnet build TACTTool -c Release` |
| **DBC2CSV** | `C:/Tools/DBC2CSV/DBC2CSV.exe` | Convert DB2 files to CSV. 1,315 .dbd definitions. ~0.5% non-deterministic drops in large batches |
| **DB2Query** | `C:/Tools/DB2Query/` | Interactive DB2 CLI: load, search, filter, export. Run: `dotnet run -c Release` |
| **DBCD** | `C:/Tools/DBCD-2.2.0/` | C# library for reading DB2 files (WDC5). Used by DBC2CSV and DB2Query |
| **Ymir** | `C:/Tools/ymir_retail_12.0.1.66220/ymir_retail.exe` | Retail DBC extraction (does NOT work with private server) |
| **Lua LSP** | `C:/Tools/lua-language-server/bin/lua-language-server.exe` | Lua language server for IDE |
| **LoreWalkerTDB** | `C:/Tools/LoreWalkerTDB/` | Reference SQL dumps (world 941MB, hotfixes 337MB) |
| **ATT Database** | `C:/Tools/ATT-Database/` | AllTheThings community data (git pull to update) |
| **TrinityCore ref** | `C:/Tools/TrinityCore-master/` | Stock TC source for comparison |
| **WoW UI Source** | `C:/Tools/wow-ui-source-live/` | Official client Lua/XML reference |
| **Transmog UI LUAs** | `C:/Tools/Transmog_UI_LUAs/` | Curated transmog Lua quick reference |

---

## 20. GitHub Repos & Gists

### Repositories

| Repo | Visibility | Purpose |
|------|-----------|---------|
| [RoleplayCore](https://github.com/VoxCore84/RoleplayCore) | Public | Main server (fork of TrinityCore) |
| [wago-tooling](https://github.com/VoxCore84/wago-tooling) | Private | All Python data pipeline scripts (61 scripts) |
| [tc-packet-tools](https://github.com/VoxCore84/tc-packet-tools) | Private | Server launcher + packet parsing |
| [trinitycore-claude-skills](https://github.com/VoxCore84/trinitycore-claude-skills) | Private | 17 Claude Code slash commands |
| [code-intel](https://github.com/VoxCore84/code-intel) | Private | C++ code intelligence MCP server |
| [TransmogBridge](https://github.com/VoxCore84/TransmogBridge) | Public | Client addon for 12.x transmog |
| [roleplaycore-report](https://github.com/VoxCore84/roleplaycore-report) | Public | Database report |

### Gists

| Gist | URL |
|------|-----|
| **This Runbook** | https://gist.github.com/VoxCore84/84656ef0960c699927e3a555e8248f7b |
| **DB Report** | https://gist.github.com/VoxCore84/528e801b53f6c62ce2e5c2ffe7e63e29 |
| **Changelog** | https://gist.github.com/VoxCore84/4c63baf8154753d2a89475d9a4f5b2cc |
| **Open Issues** | https://gist.github.com/VoxCore84/2b69757faa2a53172c7acb5bfa3ad3c4 |
| **Packet Tools** | https://gist.github.com/VoxCore84/a86d3dc8 |
| **Transmog Wiki** | https://gist.github.com/VoxCore84/88ba6320 |

---

## 21. One-Time Setup SQL

Located in `C:/Dev/RoleplayCore/sql/RoleplayCore/`:

| File | What |
|------|------|
| `1. auth db.sql` | RBAC permissions (1000+, 2100+, 3000+ ranges) |
| `2. hotfixes db.sql` | Hotfix overrides |
| `3. roleplay db.sql` | 5th custom DB: creature_extra, custom_npcs, server_settings |
| `4. world db.sql` + `4.1` | World DB custom data |
| `5. companion*.sql` (4 files) | Companion squad system |
| `6. player_morph.sql` | Morph/scale persistence |

---

## 22. Quick Reference One-Liners

```bash
# === Coverage checks ===
mysql -u root -padmin world -e "SELECT COUNT(DISTINCT quest) as quest_starters FROM creature_queststarter"
mysql -u root -padmin world -e "SELECT COUNT(*) as chained_quests FROM quest_template_addon WHERE PrevQuestID != 0"
mysql -u root -padmin world -e "SELECT COUNT(DISTINCT entry) as vendor_npcs FROM npc_vendor"
mysql -u root -padmin world -e "SELECT COUNT(*) as reward_text_rows FROM quest_offer_reward"
mysql -u root -padmin world -e "SELECT COUNT(*) as total_spawns FROM creature"

# === Update external data sources ===
cd C:/Tools/ATT-Database && git pull          # AllTheThings community DB
cd C:/Users/atayl/source/wago && git pull     # Our tooling

# === Server admin ===
# Via Claude: /soap .reload all
# Via Claude: /check-logs
# Via Claude: /parse-errors

# === Build ===
cd C:/Dev/RoleplayCore/out/build/x64-RelWithDebInfo && ninja -j20
# Or via Claude: /build-loop
```

---

*Last updated: Mar 5, 2026. Source: `doc/gist_runbook.md` in RoleplayCore repo.*

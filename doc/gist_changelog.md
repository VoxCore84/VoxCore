RoleplayCore â€” Session Changelog (WoW 12.x private server)



### Session 65 — NPC Mega-Scrape + ATT Cross-Reference + Quest Chains (Mar 5 2026)
- **NPC mega-scrape**: 80,943 Wowhead pages scraped with 120 Tor workers (~250K/hr)
  - 1,727 creature queststarters, 2,979 creature questenders, 2,535 vendor items
- **ATT cross-reference import**: 170 creature QS, 124 GO QS, 176 quest chain links
- **Quest chain application**: 572 PrevQuestID + 2,008 NextQuestID from BtWQuests
- **Scraper v2 built**: shared priority queue, adaptive delay, 100+ workers, auto-parse
- **Running totals**: creature_queststarter 34,421 | creature_questender 36,845 | gameobject_queststarter 2,058 | npc_vendor 176,427
- **Remaining gaps**: 16,630 quests without starter, 13,311 without ender

### Session 64 — Build 66263 Data Pipeline Bump (Mar 5 2026)
- **TACT extraction**: 1,094 DB2 tables from local CASC (build 66263, cleanup build: -813 rows in key tables)
- **Wago CSVs downloaded**: 66263 CSVs merged with TACT data
- **12 Python scripts updated**: wago_common, tact_extract, merge_csv_sources, diff_builds, cross_ref_mysql, att_parse_addon, att_parse_hierarchy, att_constants, att_enrich_sqlite, audit_talent_spells, parse_vendor_scrape, phase_resolver
- **Memory + tooling inventory refreshed** for 66263 references
- **Key changes in 66263**: -106 ItemSparse, -107 IMA, -266 ItemAppearance, -82 SpellName, +14 SpellEffect, +8 QuestV2
- **WPP**: Updated to nightly build (66263 support). Old 66220 backed up to `WowPacketParser_66220_backup/`
- **Ymir**: Updated to 66263
- **Auth keys**: TC published 66263 keys. Applied + bypass reverted in WorldSocket.cpp
- **Hotfix repair**: Needs re-run against 66263 baseline

### Session 64 — BtWQuests + Vendor Scrape + Midnight Data (Mar 5 2026)
- **BtWQuests addon parse**: Extracted quest starter/ender data from BtWQuests addon Lua files
  - 1,062 new `creature_queststarter` entries, 57 new `gameobject_queststarter` entries
  - All cross-referenced against existing DB to avoid duplicates
- **Wowhead vendor scrape R2**: 772 pages scraped, 92 had vendor data
  - 1,435 new `npc_vendor` entries across 82 NPCs
- **Midnight data import** (from session 61 scrape): 58 quest starters, 60 quest enders, 819 loot entries, 526 creature spells
- **Running totals**: creature_queststarter 32,458 | gameobject_queststarter 1,933 | npc_vendor 173,855
- Commit: `9340906e9d`

### Session 64 — Build 66263 Auth Fix (Mar 5 2026)
- **New WoW build** 12.0.1.66263 detected — client auto-updated from 66220
- **Auth SQL** `2026_03_05_00_auth.sql`: registers build 66263 in `build_info`, updates realmlist gamebuild, deletes stale `build_auth_key` rows, has commented-out key INSERT template
- **WorldSocket.cpp bypass**: Temporary — logs warning instead of rejecting when auth key not found. Will be reverted when TrinityCore publishes official 66263 keys
- Commit: `e3fc8cd9d6`

### Session 63 — High-Tier Service NPC Spawns (Mar 5 2026)
- 1,492 vendor/trainer/flightmaster spawns from Wowhead coordinate transforms
- 1,483 ContentTuningID assignments via zone lookup
- GUID range 3000217122–3000218613
- Commit: `25031c1eda`

### Session 63 — Transmog Audit Full Implementation (Mar 5 2026)
- **All 4 phases implemented** from 26-item 5-agent audit action plan
- **Phase 1+2** (commit `20c9a0ea23`): 4 server bugs fixed (per-spec appearance bootstrap, HandleTransmogOutfitNew active ID, Finalize flush, clear spell active ID reset) + 4 Bridge cleanup items (multi-part split bail-out, dead Layer 2 code, diagnostic probe removal, deterministic slot ordering)
- **Phase 3** (commit `1dfc2eb207`): TransmogSpy v2 rewrite — 944→1,317 lines, 17 commands, 12 new events, displayType capture, IMA-to-name resolution, 6 new hooks, illusion tracking, `/tspy status/bridge/resolve/items`
- **Phase 4** (commit `c8df50eddd`): Hardening — IgnoreMask baseline restore, stale partial payload cleanup, spec-switch ViewedOutfit resync, per-slot invalid/uncollected appearance zeroing
- **Final fix** (commit `ab43e4823d`): `EffectEquipTransmogOutfit` was the only outfit-apply path missing `SetEquipmentSet()` → ViewedOutfit sync. Situations parser consistency (hardcoded 256→MaxTransmogOutfitSlotCount, proper error paths)

### Session 62 — Transmog 5-Agent Comprehensive Audit (Mar 5 2026)
- 5 parallel agents audited: TransmogBridge, TransmogSpy, server handlers, Player.cpp, retail sniffer
- Found: 9 HIGH + 19 MEDIUM + 23 LOW findings across all subsystems
- Key server bugs: per-spec appearance bootstrap missing, HandleTransmogOutfitNew missing SetActiveTransmogOutfitID, FinalizeTransmogBridgePendingOutfit missing UpdateField flush
- TransmogSpy: missing 12 events, no displayType capture, no IMA name resolution
- 26-item action plan in 5 phases (server fixes → Bridge cleanup → Spy v2 → hardening → retail capture)

### Session 60c — Transmog Stale Detection Fix (Mar 5 2026)
- **Server-side stale rejection** replaces client-side preSnapshot/comparison detection
- Addon now tags overrides: `option=1` (SetPendingTransmog hook = trusted), `option=0` (snapshot/fallback)
- Server parses into `FromHook` flag; rejects snapshot data for slots the saved outfit ignores
- Eliminates false positive where bootstrapped appearance echoed back as outfit data (required double-apply)
- Removed ~44 lines client-side detection, added ~37 lines server-side rejection
- Commit: `0cde8db70c`

### Session 60b — Transmog 11-Fix QA Sweep (Mar 5 2026)
- 5 MEDIUM + 6 LOW fixes from comprehensive 4-agent audit
- M1: `_activeTransmogOutfitID` persisted to DB (new `active` column + SQL migration)
- M2: `EffectEquipTransmogOutfit` sets active outfit ID before applying
- M3: Situations packet parser capped at 256 entries (OOM prevention)
- M4: Cross-contamination fix in CurrentSpecOnly reset paths
- L1-L6: Double flush removal, per-spec illusion bootstrap, clear spell IgnoreMask, DeleteEquipmentSet cleanup, signed shift fix, dead code warning
- Commit: `27b5496f4f`

### Session 61 — Midnight Expansion Data Scrape + Import
- Scraped 38 Wowhead Midnight guide pages + 586 entity pages (44 MB raw HTML, 0 WAF blocks)
- Extracted: 712 items, 282 NPCs, 247 spells, 154 quests, 85 achievements, 1,314 loot drops
- Cross-referenced all data against world DB: 819 new loot entries, 526 boss abilities, 118 quest links
- Applied `2026_03_05_15_world.sql` (1,463 rows). Commits: wago `966e0eb`, RC `d81962a4d6`

## 2026-03-05 — ATT Mega-Parser (Session 54)

### AllTheThings Complete Data Extraction
- **`att_to_sqlite.py`** â€” comprehensive SQLite extractor for ALL AllTheThings data
- **60 normalized tables** from 30 data loaders, 52.6 MB database, 27s full rebuild
- Phase 1: Lua AST parse of 1,635 files -> quests (47K), NPCs (6.3K), items (175K), encounters (946), coords (54K), timelines (32K), costs (19K)
- Phase 2: 30 supplementary loaders covering:
  - Core DBs: Objects (22K), Mounts (1.5K), Pets (1K), Flight Paths (1.3K), Reagents (31K), Achievements (13K)
  - Item enrichment: itemDB.json (157K), .dynamic per-expansion metadata (310K), auto-sources (99K)
  - Transmog: Sets (3.6K), Set Items (57K), Illusions (86), Missing Transmog audit (76K)
  - Professions: 15 profession files (5.6K recipes), Glyphs (690)
  - Expansion systems: Runeforge powers (261), Conduits (286), Blueprints (68)
  - Filters: FilterDB (58), Item Filters RWP (136K), ClassInfo specs (57), Instances (207)
  - Audit: Missing Items (29K), Missing Quests (3.1K)
  - Collectibles: Mount Mods, Music Rolls, Pepe, Pocopoc (490 total)
- Commit `b1f0bd0` (wago-tooling repo)


Chronological log of all database, code, and infrastructure changes. Each entry includes the session number, what changed, and the commit hash where applicable.

---

## Mar 5, 2026

### Session 60 — Transmog Phase 2 Fixes (Mar 5 2026)
- **H1 fix** (clear spell desync): `spell_clear_transmog.cpp` now syncs cleared state to active outfit — zeros Appearances[], Enchants[], SecondaryShoulderApparanceID, calls SetEquipmentSet() for DB persist + ViewedOutfit rebuild
- **M4 fix** (illusion bootstrap): `fillOutfitData` bootstraps weapon enchant illusions from equipped items when outfit doesn't define them — illusions no longer vanish on relog
- **Diagnostic probe**: TransmogBridge.lua logs all 4 API sources per slot at CommitAndApplyAllPending timing — data needed for v2 addon rewrite
- Commits: `5d38823153` (Phase 2 fixes), `69a725cc59` (probe + docs)

### Session 59 — Transmog QA Audit + Phase 1 Fixes (Mar 5 2026)
- **Full QA audit**: 3 parallel agents audited TransmogBridge addon, server handlers, packet parsing, UpdateField sync. Found 2 critical + 4 medium + 5 low issues
- **Bug E fix** (single-item transmog → full rebuild): `HandleTransmogrifyItems` now calls `SetEquipmentSet()` after syncing changes — persists to DB, refreshes ViewedOutfit
- **Bug B fix** (old head/shoulder persist): Added `_activeTransmogOutfitID` tracking. ViewedOutfit now renders the actually-applied outfit instead of always the lowest SetID
- **IgnoreMask fix**: `HandleTransmogOutfitUpdateInfo` preserves existing IgnoreMask instead of clobbering with uninitialized value
- **Packet hardening**: Sanity cap (256), accumulation handling (last-30), ordinal comment fix
- Commits: `289677be44` (Phase 1), `12bc18f374` (packets), `3b8d14c7c6` (gitignore)

### Session 58 — Wowhead Gap Scraper (Mar 5 2026)
- Built 3-script pipeline: generate_gap_targets.py → scrape_gaps_tor.py → import_scraped_gaps.py
- Scraped 5,653 Wowhead pages via 30 Tor workers at 45K/hr (0 WAF blocks)
- Fixed parsers: quest pages use WH.markup.printHtml custom markup, vendor data needs balanced-bracket JSON extraction
- Applied: 592 creature quest starters, 683 creature quest enders, 202 GO starters, 208 GO enders, 8,799 vendor items
- Reverted gossip import (56 NPCs) — scraper picked up user comments instead of NPC dialogue
- Cleaned 73 orphaned GO quest entries (TWW Candy Buckets without templates)
- Also committed: audit_talent_spells.py (183 critical + 242 high priority broken talent spells identified)


### 2026-03-05 â€” Website QA Round 2
- Cross-page sidebar, back-to-top, accuracy audit (30/30 stats verified, 7 stale values fixed)
- Architecture diagram, Konami easter egg
- Commit: `068c81c`

### Session 55 â€” VoxCore Website QA Round 2
- Site architecture overhaul: cross-page sidebar, external CSS/JS, accuracy audit (30/30 stats verified)
- `refresh_content.py` + `update_site.bat` build pipeline
- Commit: `068c81c` (roleplaycore-report)

### Session 53 â€” TACT/Wago CSV Merge Pipeline
- **TACT vs Wago audit**: 251K missing SpellEffect rows in Wago, 7,119 stale hotfix overrides found
- **`merge_csv_sources.py` created** â€” TACT base + Wago CDN extras (998 TACT-only + 99 merged tables)
- `wago_common.py` WAGO_CSV_DIR auto-points to merged output â€” zero downstream changes needed
- `tact_extract.py` QA: fixed default output (data-loss risk), 3 file handle leaks
- Commits: `1c3534d`+`bcbc07f` (wago-tooling)

### Session 51 â€” Missing Spawns + Phase Resolution + ATT Import
- **1,755 quest NPC spawns** deployed (84% reduction in missing quest NPCs)
- **Phase-duplicate resolution**: 214 entries analyzed, 207 re-inserted, 7 REMOVED skipped
- **ATT data applied**: 4,630 quest starters, 3,081 quest chains, 1,510 vendor items
- **QA fixes**: 11 HealthModifier=0, 30,130 orphaned waypoint nodes, 51 orphaned loot refs
- Commits: `68e154e68c`, `fcf1cf2738`, `1d53f2a1d3`, `04c0d4652c`

### 2026-03-05 â€” Transmog: Retail Sniffer-Informed Fix Pass
- Decoded Ymir retail packet capture (build 66220, 2.77M lines) â€” ground truth for transmog packet analysis
- **Retail discovery**: 30 entries per outfit (12 armor + 18 weapon options), DT=3 = hidden visual IMA (not "remove transmog")
- Reverted wrong DT=3 assignment (DT=3+IMA=0 doesn't exist on retail) â†’ simple (imaID > 0) ? 1 : 0
- Reverted last-group-only merge (growing packets were wrong diagnosis) â†’ restored first-non-zero-wins
- Added IgnoreMask repair pass in fillOutfitData
- Found 11 hidden visual IMA IDs (77343-198608 range)
- Commit: `fae00afb86`

### 2026-03-05 â€” DBCD Audit + Broadcast Text Fill
- Built DB2Query CLI tool using DBCD 2.2.0 for retail DB2 binary cross-reference
- Removed 363 redundant hotfix rows across 13 tables (verified identical to retail DB2)
- Filled 393 missing broadcast_text entries from Wago DB2
- creature_text broadcast_text coverage: 335 missing â†’ 0 (100% complete)
- Commit: `faec6435de`

### Session 50 â€” AllTheThings Database Parser
- **ATT Database parser built** (`att_parser.py`): Full Lua tokenizer + parser for the AllTheThings Database repo (1,576 files, 47K quests extracted)
- **Validated SQL generator** (`att_generate_sql.py`): Cross-references ATT data against TC MySQL, filters deprecated/DNT quests, validates all IDs
- **8,950 new rows ready to apply**:
  - 4,359 `creature_queststarter` â€” quest-giver NPC assignments
  - 3,081 `quest_template_addon` PrevQuestID â€” quest chain prerequisite links
  - 1,510 `npc_vendor` â€” vendor inventory items
- Tools committed to `VoxCore84/wago-tooling`: `81cf71a`

### Session 49 â€” TDB Delta + Scraper Hardening
- **TDB 1200.26021 delta applied**: quest_offer_reward 18,054 â†’ 20,022 (+1,967), quest_request_items +69
- **Wowhead 403 resolved** â€” expired on its own, scraper upgraded with curl_cffi Chrome131 TLS
- **27,328 quests** ready for reward text scrape (~2 hours via two-phase approach)
- Commits: `e6b44edab3` (RoleplayCore), `f594f1b`+`7a9667b`+`80d42e8` (wago-tooling)

### Session 47 â€” Gist Accuracy Audit + hotfix_data R3 Cleanup
- **hotfix_data orphan cleanup**: `cleanup_hotfix_data_orphans.py` removed 608,401 orphaned entries. 226,984 remaining (was 835,385). Hotfixes DB 637â†’535 MB
- **Gist accuracy audit**: Verified all report numbers against live DB. Fixed 6 critical errors:
  - smart_scripts: 792Kâ†’294,425 (imports cleaned by validation scripts)
  - Part 11 hotfix tables: pre-audit numbers replaced with post-audit actuals
  - hotfix_data: 835Kâ†’227K (R3 registry cleanup applied)
  - DB sizes: world 1,267 MB, hotfixes 535 MB (previously stale)
- **OPTIMIZE/ANALYZE** on hotfix_data + 8 tables with stale InnoDB statistics
- Commit: `21fa23b0d1`

### Session 46 â€” WPP Script Hardening
- **20-bug QA** across 4 files: `start-worldserver.sh`, `extract_transmog_packets.py`, `wpp-inspect.sh`, `opcode_analyzer.py`
- Root cause: runtime `start-worldserver.sh` had stale WPP path (`out/` subdir)
- EXIT trap for bnetserver, `$WPP` full path, `cd` error guards, `set -o pipefail`, streaming packet extraction
- Commit: `8584c3c2e0` + tc-packet-tools `821e74f`

### Session 45 â€” DB Report Update
- **Hotfix audit tools committed**: `hotfix_differ_r3.py`, `gen_practical_sql_r3.py`, `build_table_info_r3.py`, `merge_results.py` + README.md + .gitignore
- **Gist created**: `528e801b53f6c62ce2e5c2ffe7e63e29` â€” comprehensive database report (Parts 1-16)
- Commit: `9ae9d40788`

### Session 44 â€” Tools Consolidation
- Moved `C:\Users\atayl\OneDrive\Desktop\Excluded\` â†’ `C:\Tools\`
- Fixed WPP path in 13 files across 4 repos
- Added 7 missing tools to inventory
- Pushed: wago-tooling `b56bfb0`, tc-packet-tools `d956a5a`, trinitycore-claude-skills `25967f7`

### Session 43 â€” CTD Fix + SmartAI Cleanup
- **Missing CTD rows**: 26,745 creatures missing DifficultyID=0 â†’ 0 remaining
  - Step 1a: 24,070 Diff2â†’Diff0 copies
  - Step 1b: 68 from other difficulties
  - Step 2: 2,607 default Diff0 rows
- **SmartAI orphans**: 5,894 creatures with AIName='SmartAI' but no scripts â†’ cleared
  - +181 GUID-based script creatures restored (missed by entry-only check)
- **AIName fixes**: 3 data errors ('0', 'CombaAI' typo)
- **ContentTuning enrichment**: 4,820 spawned CT=0 creatures â†’ zone/neighbor lookup
- Commit: `f0782d5030`, `9536a248b6`

## Mar 4, 2026

### Sessions 37-38 â€” Phased Cleanup
- 3 SQL fixes, 11 Stormwind CTD rows
- Hotfix R2 cleanup: 204K redundant rows removed
- Companion hotfix_data cleanup: 174,799 orphaned entries
- `.gitignore` updates
- Commit: `22d3f83d57`

### Sessions 35-36 â€” Hotfix R3 Audit + Transmog Diagnostics
- **R3 type-aware audit**: 109 tables, 768K redundant rows removed
  - Float32 IEEE 754 bit-level comparison
  - Signed/unsigned int32 pattern matching
  - Logical PK overrides (broadcast_text_duration)
- **Transmog diagnostic build**: secondary shoulder fix, deleted set skip, caller tracing
- Commit: `c1e9a53c84`

### Session 34 â€” Auth Key Update
- Reverted auth bypass at WorldSocket.cpp
- Applied TC build 66220 auth keys (7 keys)
- Commit: `8bbd610fc7`

### Session 33 â€” Creature DB2 Orphans
- 137 orphaned hotfix_data entries for Creature DB2 (hash 0xC9D6B6B3) removed
- Commit: `319c2781cb`

### Session 32 â€” Repo Cleanup
- docs â†’ `doc/`, tools â†’ `tools/`, batch scripts â†’ `tools/build/`
- Deleted 1.4 GB hotfix_audit output + junk from repo root
- Commit: `a7cf01b4ba`

### Session 31 â€” Transmog Client Wiki
- 3,487-line reference wiki + 119-line cheatsheet from 15 Blizzard Lua/XML source files
- Commit: `ad8f9eaa9f`

## Mar 3, 2026

### Sessions 13-30 â€” Major Data Pipeline Day
- **Wowhead mega-audit**: 216,284 NPCs scraped, 54,571 operations across 3 tiers
- **Raidbots/Wago pipeline**: 1.6M item locale entries, 21K quest chains, 135K quest POI
- **LW import #2**: 665,658 net new rows across 21 tables (5-phase dependency ordering)
- **Post-import cleanup**: 47,478 rows cleaned, 627K error lines resolved
- **Hotfix repair build 66220**: 388 tables, 103K inserts, 1.8K column fixes
- **MySQL tuning**: tmp_table_size 1KBâ†’256MB, buffer pool 16GB, warm restarts
- **Build diff audit**: 5 builds diffed, Wago oscillation detected, zero breaking changes
- **Hotfix pipeline crash fix**: 6 bugs across 3 C++ files (chunked delivery, ByteBuffer assert)
- **Transmog 4-bug fix**: Commit `272c373105`

## Mar 1, 2026

### Sessions 11-12 â€” Transmog Confirmed Working
- 14/14 manual clicks, 13/14 outfit loading (secondary shoulder gap)
- PR cleanup and cross-repo PR #760 on KamiliaBlow/RoleplayCore

## Feb 28, 2026

### Sessions 8-10 â€” Quest/GO Audits + TransmogBridge
- GO/quest audit tools + 2,279 DB fixes
- TransmogBridge addon implementation (3-layer hybrid merge)
- Creature/GO placement audits vs LoreWalkerTDB

## Feb 27, 2026

### Sessions 2-7 â€” Foundation
- 5-database audit: 148 checks, 412K dead rows removed
- LW import #1: 385,823 rows across 17 tables
- NPC audit tool (27 checks), 3-batch NPC fixes (23,904 operations)
- Placement audit tools built
- Loot table PK discovery + deduplication (193K pre-existing dupes + 3M import dupes)
- Backup table cleanup: 101 tables dropped, 382 MB reclaimed
- MyISAMâ†’InnoDB migration (7 tables)

## Feb 26, 2026

### Session 1 â€” Initial Setup
- Companion AI fix
- Transmog wireDT fix
- Initial hotfix repair v1

---

## Database State (March 5, 2026)

| Database | Tables | Size | Key Metric |
|----------|--------|------|------------|
| world | 259 | 1,267 MB | 664K creatures, 294K SmartAI scripts |
| hotfixes | 517 | 535 MB | 227K hotfix_data, ~244K content rows |
| characters | 151 | 7.6 MB | |
| auth | 50 | 1.9 MB | |
| roleplay | 5 | 0.1 MB | |

## Repositories

| Repo | Latest Commit | Purpose |
|------|--------------|---------|
| VoxCore84/RoleplayCore | `9340906e9d` | Main server |
| VoxCore84/wago-tooling | `966e0eb` | Wago/LW/hotfix tools |
| VoxCore84/tc-packet-tools | `821e74f` | WPP + packet analysis |
| VoxCore84/code-intel | â€” | C++ MCP server |
| VoxCore84/trinitycore-claude-skills | `25967f7` | Claude Code skills |

*Updated March 5, 2026*


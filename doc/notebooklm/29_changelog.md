RoleplayCore â€” Session Changelog (WoW 12.x private server)



## Mar 8 2026

### Session 106 -- Meta Infrastructure + Gist Updates
- **Transmog bug tracker**: Created `transmog-bugtracker.md` — single source of truth for all transmog bugs (3 CRITICAL, 6 HIGH, 4 MEDIUM, 4 LOW)
- **New skills**: `/transmog-implement` (pick & fix next bug), `/transmog-status` (quick bug overview)
- **Comprehensive transmog report**: `doc/transmog_implementation_report.md` — standalone reference for implementation sessions
- **Gist updates**: All 3 gists synced to current state (DB sizes, session history)
- **Server logs audit**: Clean — zero crashes/fatals, only unhandled opcodes + SmartAI warnings

### Session 105b -- Transmog DeepDive Wiki
- **1,500-line authoritative wiki** from 54 source Lua/XML files (`doc/transmog_deepdive_wiki.md`)
- **4 new memory files**: transmog-enums, transmog-api-reference, transmog-ui-architecture, transmog-updatefields
- **Critical correction**: DisplayType values in cheatsheet were wrong — fixed via DeepDive source analysis
- **UpdateField structures**: Full WPP-derived struct layouts for TransmogOutfitSlotData

### Session 105 -- Transmog Cheatsheet Update
- Updated `doc/transmog_cheatsheet.md` with corrected DisplayType values and opcodes

### Session 104 -- Draconic Diff Tool + Stormwind Cleanup
- **`tools/diff_draconic.py`**: Zone-by-zone world DB diff vs Draconic-WOW (build 66263, named pipe)
- **Stormwind findings**: 7 missing `phase_area` entries (root cause of invisible NPCs), portal fixes, board dedup
- **`.npc copy` command**: Code complete in `npc_copy_command.cpp`
- **Comprehensive cleanup plan**: `doc/world_db_cleanup_plan.md` — 9 zones remaining
- Commit `e90f4da5bc`

### Session 103 -- NPC Tooling
- `.npc copy` command implementation
- Crash investigation (MoveSplineInit)

### Session 102 -- Collection Unlock Commands
- **New commands**: `.maxrep`, `.maxachieve`, `.maxtitles` — unlock all reputations/achievements/titles
- **Arcane Waygate**: Custom spell 1900028, gossip menu, teleport destinations
- **RBAC QA**: Permission audit and cleanup
- Commit `c1d17d983b`

### Session 101 -- SpellAudit Stub Cleanup
- Removed 1,842 broken C++ spell script stubs (empty handlers causing load failures)
- Registered Sweeping Strikes + Beacon of Light (real implementations)
- Commit `5eb5883fb4`

### Session 100 -- CC Lighthouse + PWA
- Command Center Lighthouse score 93/100
- PWA support, WebP icons, auto-start in `start_all.bat`
- Commit `da14bd911e`

## Mar 7 2026

### Session 99 -- Shortcut & Command Center QA Mega-Pass
- **5-agent QA sweep**: 48 desktop shortcuts, 48 CC tiles fully audited and synced
- **Bnetserver/worldserver shortcuts**: Fixed to use `cmd.exe /k` wrappers
- **start-worldserver.sh**: Fixed `$SCRIPT_DIR` vs `$RUNTIME` path bug
- **opcode_analyzer.py**: Fixed `DEFAULT_PROJECT_ROOT` pointing to wrong directory
- **CC fixes**: URL guard, unused imports, cmd.exe wrapping, larger logo (180px)
- **Bat files**: Deleted obsolete `start_mysql.bat`, cleaned vestigial MySQL80 refs
- Commits `48c9d4f9b7`, `01aaf028e9`, pushed

### Session 98 -- MySQL QA + DB Health Audit + Spell Audit SQL
- **UniServerZ MySQL**: Fixed skip-name-resolve TCP blocking, procs_priv charset corruption, IP grants
- **Spell audit SQL applied**: 114 serverside_spell stubs, 18 spell_proc entries, 1,888 spell_script_names
- **MySQL QA (5 agents)**: my.ini optimized (8GB buffer pool, 20K IO), batch files updated
- **DB event cleanup**: Disabled broken Panda event, deleted collecting_battle_pets
- **Discovered ~70 unapplied SQL updates** from consolidation -- handed off for bulk apply
- Commit `039df2a6af`, pushed

### Session 97b -- Hotfix Repair + Bulk SQL Restore
- **Hotfix repair build 66263**: 2,727,115 missing rows inserted, 496 zeroed columns fixed across 28 tables (339 MB SQL)
- **Bulk SQL restore**: Applied ~200 SQL files across all databases after fresh DB rebuild
- DB restored to: creature_template_spell 172K, creature 611K, npc_vendor 174K, spell_name 400K

### Session 97 -- WT Font Config + Shortcut Regen
- **Windows Terminal**: JetBrains Mono 14pt font for Claude profile
- **Desktop shortcuts regenerated**: 47 shortcuts across 8 folders
- Commit `0c02d75803`, pushed

### Session 96 -- Command Center Integrations + Path Fix
- **Systemic path fix**: 15 subprocess.Popen commands -- removed absolute path doubling
- **New integrations**: GitHub Repo, Discord, Wago.tools, GitHub Pages (URL cards)
- **2 new pipelines**: Wago DB2 Download, DB Snapshot List-Rollback
- **Desktop sync tool**: `sync_from_desktop.py` diffs VC desktop folders vs CC cards
- Commit `bf877e0e0f`, pushed

### Session 95 -- Spell Creator + SpellAudit Fix
- **New tool: `tools/spell_creator.py`**: Python CLI replacing old .NET SpellCreator
  - 11 templates, full clone from wago CSV, hotfix SQL generation, SOAP reload
  - Icon search (32K+), enum reference, clipboard/SQL/DB/SOAP output modes
- **SpellAudit generator fix**: Regenerated 13 class files (1,842 scripts) -- zero warnings
- **SOAP enabled**: worldserver.conf `SOAP.Enabled = 1`
- Commit `68dcea8161`, pushed

### Session 94 -- Comprehensive Code Quality Pass
- **Full source audit**: 11 agents, **39 fixes across 19 files**
- 7 critical crash fixes (bounds checks, nullptr guards, assert-->if)
- 8 high (EffectsHandler memory leaks, CompanionAI O(n)-->O(1), GM logging)
- 12 medium (strtok/atoi-->StringTo, scale bounds, SpellVisualKit validation)
- 12 low (typos, help text, dead methods, #pragma once, NULL-->nullptr)
- Config optimizations: worldserver.conf + MySQL my.ini tuned
- Commit `f3f5e015a1`, pushed

### Session 93 -- Command Center QA Fixes
- 6 bug fixes for VoxCore Command Center (icon crop, missing pipeline cards, index validation, null guard, Jinja2 stepper, image try-except)
- Commit `f0ee73d7f1`, pushed

### Session 92 -- Archive Cleanup + Shortcut Audit
- Deleted `archive/` (287 MB orphaned files), audited all 44 desktop shortcuts -- 44/44 OK

### Session 91 -- Doc Audit
- `doc/` directory: 20 --> 13 files, deleted 7 obsolete, renamed gist_current --> gist_db_report
- Commit `1a49d90996`

### Session 90 -- SQL Directory Audit
- **12 issues fixed**: 5 idempotency (INSERT IGNORE, CREATE IF NOT EXISTS, etc.), roleplay DB in create_mysql, sql/old pruned
- **Pruned 19,416 old TDB files** from git tracking (3.8 GB saved)
- Tracked files: 19,820 --> 399
- Commit `e15eb622c6`

### Session 89 -- Archive Cleanup
- Deleted `archive/` directory (287 MB) -- orphaned pre-consolidation files

### Session 88 -- Spell Audit Pipeline
- **QA'd class_spell_audit.py**: Fixed 3 classification bugs
- **Generated 1,842 C++ spell script stubs** across 13 per-class files
- **Generated SQL**: 114 serverside_spell stubs, 18 spell_proc entries, 1,888 spell_script_names
- All 13 C++ files compile cleanly, 38,695 lines added
- Commit `27c2d7d04e`, pushed

### Session 87 -- Scenic Art Upscaling Pass 2
- Upscaled 154 images across 6 categories using Real-ESRGAN 4x (622 MB output)

## Mar 6 2026

### Session 86 -- Grand Consolidation QA
- 200+ old path refs fixed, memory files consolidated (28-->23), .gitignore (39-->73 lines)
- Windows Defender hardened, GitHub repo/gists cleaned, README rewritten
- Commit `37ce2554f8`

### Session 85 -- Grand Consolidation
- Moved everything to `~/VoxCore/`, organized personal docs, rebuilt entire project
- Commit `95eb139ee2`

### Session 84 -- Windows System Performance Tuning
- **30+ registry tweaks**: Hyper-V/VBS/HVCI off, Spectre mitigations off, NVIDIA MSI mode, GameDVR off
- **Network**: Nagle's disabled, TCP window scaling, 65K ports, 30s TIME_WAIT
- **Boot**: useplatformtick + disabledynamictick (0.5ms timer)

### Session 83 -- Grand Consolidation Plan
- Full C: drive audit, 757-line consolidation plan across 8 phases

### Session 82 -- Stormwind Cleanup: Event NPCs, Boards, Portals
- 6 SQL fixes: Wickerman Revelers, Argent Crusade stationary, broken Hero's Call Boards, stale Dalaran portal, invisible Silvermoon portal (displayId fix)
- Commit `b0c1dd07ce`

### Session 81 -- DB Optimization + Claude Code Tuning
- 69 fragmented tables optimized (~150 MB reclaimed), MySQL buffer pool 4-->8 GB
- Claude Code permissions pre-allowed, MEMORY.md diet (175-->76 lines, -70%)
- Commit `b0c1dd07ce`

### Session 80 -- Community Listfile + Scenic Art + Transmog DeepDive
- 2.1M-entry community listfile downloaded, 6 new scenic art categories (217 files)
- Transmog DeepDive: 35 source Lua/XML, 3 new 12.x DB2 CSVs, Blizzard_DebugTools addon

### Session 79 -- Transmog QA Audit: 1 HIGH, 10 MEDIUM, 10 LOW
- Full two-pass QA audit (10 agents), H1: stored outfit Slots array accumulation bug identified

### Session 78 -- Cowork Symlink Network
- 19 symlinks created, confirmed symlinks don't work in Cowork (Linux sandbox limitation)

### Session 77 -- Mega Data Mining: 316K SQL statements across 7 files
- Quest integrity compiler, BtWQuests untapped, ATT mega extract, quest metadata
- Wowhead NPC mining: 161K creature spells, 105K loot, 4K trainers
- Safe spawns: 28,665 creature spawns generated
- DB impact: creature 665K-->694K, creature_template_spell 10K-->171K
- Commit `194a596ca0`

### Session 76 -- Claude Customization + Wrap-Up QA
- Claude.ai profile updated, `/wrap-up` QA (6 fixes), VS 2022-->2026 refs updated

### Session 75 -- WebTerm + VoxCore Rebrand + Transmog IDT Fix
- **WebTerm**: Python web terminal (Flask+SocketIO+xterm.js) replacing ttyd
- **VoxCore rebrand**: RoleplayCore --> VoxCore across skills + CLAUDE.md
- **Transmog IDT fix**: Armor slots use IDT=0 for assigned appearances
- Commit `d1a3060e6e`, pushed

### Session 74 — Wowhead 310K QA Pipeline + Coord Converter + SQLite DB (Mar 6 2026)
- **310K NPC reparse**: Fixed models/displayID extractor (3 regex patterns: ModelViewer.showLightbox, dataset.displayId, data-mv-display-id). 204,136 model entries extracted (up from 0%). 3,345s, 0 errors
- **Coordinate converter** (`coord_convert.py`): Wowhead UI-map percentages → TrinityCore world coordinates via UiMapAssignment DB2 (1,909 maps, 22,494 assignments). Key discovery: axes SWAPPED + INVERTED. Validated <10 unit accuracy across 4 zones
- **SQLite database** (`wowhead_npcs.db`): 338 MB, 16 tables, fully indexed. 309,996 NPCs, 2,092,045 coords, 538,169 drops, 204,136 models, 1,538,668 sounds. Import: 99s, 0 errors
- **QA Pass 1** (field completeness): 99.1% names, 70.8% creature type, 32.2% with coords
- **QA Pass 2** (coord quality): 0 out-of-range, 162 continent uiMaps (82K NPCs safe), 56 instance maps (26K must NOT spawn)
- **QA Pass 3** (DB cross-reference): 38,119 gap NPCs — 478 CRITICAL (quest), 145 HIGH (vendor), 12,017 MEDIUM (SmartAI), 25,479 NORMAL. 99.3% type match, 100% classification match
- **Oddities analysis**: 8 oddities identified, 5 safe vs 5 risky actions classified
- **Integration architecture**: Designed 6 Flask routes, Leaflet.js maps, spawn SQL pipeline
- **VoxCore Data Intelligence Report**: 1,434-line/77KB comprehensive report covering all 11 data sources, Vox Army specs, optimization roadmap, buildable products
- Wago commit: `2351879`

### Session 73 — Scraper V2 + Full Wowhead NPC Scrape (Mar 5 2026)
- **Scraper V2**: Complete overhaul of `scrape_all_gaps_tor.py` (1,262 lines). 5 entity types, enriched NPC parser, HTML caching (gzip), reparse mode, adaptive Tor timing
- **Full 310K NPC scrape**: 240 Tor workers, IDs 1-310000, ~315K/hr. Zero errors
- **Critical finding**: v1 parser only captured name for 97.6% of pages — g_mapperData and g_npcs completely missed
- Wago commit: `c6d7734`

### Session 73 — Transmog Corrective Pass (Mar 5 2026)
- **6 surgical fixes** to `fillOutfitData` in Player.cpp — retail behavioral model alignment
  - Added `isStored` parameter to distinguish stored TransmogOutfits from live ViewedOutfit
  - Assigned rows always ADT=1 (both contexts); viewed empty = ADT=2/IDT=2; stored empty = ADT=0/IDT=0
  - Bootstrap from equipped items only for viewed outfits (stored keep empty slots as 0/0)
  - SlotOption uses wire option index (mapping.option) not visual classification (0/1/3)
  - Stamped MH/OH options use real MainHandOption/OffHandOption enums, not booleans
  - Paired weapon placeholder threshold corrected to options >= 5 (was >= 6)
- **CLAUDE.md**: Updated transmog authoritative rules — all confidence levels now HIGH
- **`/transmog-correct` command**: Added to `.claude/commands/` for future corrective passes
- Commit: `7bb510359b`

### Session 72 — Universal Scraper + Midnight Data Harvest (Mar 5 2026)
- **Scraper v2**: Upgraded to 5 entity types (quest, npc, trainer, vendor, object), 120 Tor workers, per-batch logging
  - Added NPC page parser (vendor items, teaches, quests, gossip) and object page parser (quest starts/ends, loot)
  - Smoke test + full batch: 15,044 pages in 797s (68K/hr), zero failures
- **Midnight NPC scrape**: 13,491 NPC pages (entry range 235K-300K) — complete Midnight expansion NPC data
- **Midnight objects**: 555 gameobject pages with quest links and loot tables
- **Trainer gap fill**: 1,022 trainer NPC pages for server-wide broken trainer fix
- **Gap quests**: 27 remaining quest pages scraped (merged gap + midnight quest IDs)
- Wago commit: `ca37060`

### Session 71 — Claude Desktop Cowork Integration (Mar 5 2026)
- **Cowork bridge**: sync_bridge.py snapshots 389 source files into ~/cowork/bridge/ for Claude Desktop
- **Project bible**: Comprehensive project reference for Cowork (bridge paths, repos, gists, tools, schema)
- **ttyd web terminal**: Full system access for Cowork via localhost:7681
- **CLAUDE.md**: Added transmog UI/Midnight 12.x authoritative rules section
- Commit: `3cc2d58c70`

### Session 70 — Transmog Audit Pass 2 + Hidden DT Fix (Mar 5 2026)
- **Transmog audit pass 2**: 585-line QA report (client events, TRANSMOG_COLLECTION_UPDATED over-firing, DisplayType)
- **Hidden appearance detection**: ItemID-based detection for 10 hidden items, DT=3 for hidden slots
- **Paired weapon DT=4**: Options 6-8 on MH/OH emit ADT=4+IDT=4
- Commits: `8d36580ac4`, `053e01fed2`

### Session 69 — Stormwind Retail Accuracy (Mar 5 2026)
- **Ambient NPC scripts**: 37 SmartAI entries for ~426 spawns (guards, citizens, workers, refugees, dracthyr)
- **Phase cleanup**: 139 Day of the Dead ghosts event-gated, 2 broken Darkmoon spawns removed
- **Combat NPC equipment**: 19 entries (sentinels, captains, officers, marshals)
- **Hero's Call Board dedup**: Removed old GO 206111 overlapping newer 281339
- Commits: `152178ffcc`, `295d04f890`, `e710f5a709`, `9e728c9139`, `9e53777d55`

### Session 67 — Stormwind Retail Sniff + Hero's Call Board Dedup (Mar 5 2026)
- **Retail sniff import**: 152 creature spawns, 21 GO spawns, 9 equipment templates from Stormwind retail ground truth
- **Sniff enrichment**: 161 updates — creature type/family/Classification/unit_class, HP/Mana modifiers, portal deduplication
- **Stormwind Wowhead scrape**: 28 Hero's Call Board quest starters applied, then reverted (duplicate of newer GO 281339)
- **Hero's Call Board dedup**: Removed old GO 206111 overlapping newer GO 281339 + 5 SmartAI orphan cleanups
- Commits: `9962076dbf`, `c5cb54ec54`, `c7bada7e1d`, `9e53777d55`

### Session 67 — Transmog Hidden Appearance + PacketScope (Mar 5 2026)
- **Hidden appearance detection**: Proper DT=3 handling for hidden visual IMA IDs
- **Paired weapon DT=4**: Display type for paired weapon transmog
- **TransmogSpy label fix**: Corrected display type labels in diagnostic output
- **PacketScope improvements**: Better transmog packet inspection tooling
- Commit: `8d36580ac4`

### Session 66 — Midnight Expansion Scrape + BtWQuests Enrichment (Mar 5 2026)
- **Midnight expansion scrape R2**: 226 queststarters, 181 questenders, 174 vendor items, 11 GO quest links from Wowhead
- **BtWQuests CT + ATT enrichment**: 228 ContentTuningID fills, 252 vendor items, 426 exclusive groups
- **Transmog addon QA**: Name-Realm whisper fix, button hook reliability, failed event logging, nil guard on payload send, pcall on Layer 1
- Commits: `c76813221d`, `6be6f4682b`, `e0bd9ef78b`, `0014c37771`

### Session 65 — NPC Mega-Scrape + ATT Cross-Reference + Quest Chains (Mar 5 2026)
- **NPC mega-scrape**: 80,943 Wowhead pages scraped with 120 Tor workers (~250K/hr)
  - 1,727 creature queststarters, 2,979 creature questenders, 2,535 vendor items
- **ATT cross-reference import**: 170 creature QS, 124 GO QS, 176 quest chain links
- **Quest chain application**: 572 PrevQuestID + 2,008 NextQuestID from BtWQuests
- **Scraper v2 built**: shared priority queue, adaptive delay, 100+ workers, auto-parse
- **Running totals**: creature_queststarter 34,647 | creature_questender 37,026 | gameobject_queststarter 2,066 | npc_vendor 176,853
- **Remaining gaps**: 16,552 quests without starter, 13,165 without ender

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
- Moved `C:\Users\atayl\OneDrive\Desktop\Excluded\` â†’ `~/VoxCore/ExtTools/`
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

## Database State (March 8, 2026)

| Database | Size | Key Metric |
|----------|------|------------|
| world | 1,086 MB | 611K creatures, 226K templates, 286K SmartAI, 5.5K spell scripts |
| hotfixes | 811 MB | 400K spell_name, 234K broadcast_text, 176K item_sparse (full 66263 restore) |
| characters | 4 MB | 5 characters, transmog outfits table ready |
| auth | 2.8 MB | 2 accounts |
| roleplay | 0.1 MB | 4 tables (creature_extra, template_extra, custom_npcs, server_settings) |

## Repositories

| Repo | Latest Commit | Purpose |
|------|--------------|---------|
| VoxCore84/RoleplayCore | `e90f4da5bc` | Main server |
| VoxCore84/wago-tooling | `2351879` | Wago/LW/hotfix tools |
| VoxCore84/tc-packet-tools | `821e74f` | WPP + packet analysis |
| VoxCore84/code-intel | -- | C++ MCP server (416K symbols) |
| VoxCore84/trinitycore-claude-skills | `25967f7` | Claude Code skills |
| VoxCore84/roleplaycore-report | `9ead780` | GitHub Pages documentation site |

*Updated March 8, 2026*


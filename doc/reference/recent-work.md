# Recent Work Log

## Mar 5 2026 (session 48 — World DB QA + CT Enrichment + Coord Transformer)
- **5 SQL update files** created, applied, committed, pushed (`_00` through `_04`)
- **`_00`**: 26,745 missing DifficultyID=0 rows fixed (24,070 from Diff2, 68 from lowest diff, 2,607 default inserts)
- **`_01`**: SmartAI orphan cleanup — AIName='' for 5,894 creatures with no scripts. Patched to include GUID-based script check
- **`_02`**: Corrective fix restoring AIName='SmartAI' for 181 GUID-based script creatures
- **`_03`**: 3 AIName typos fixed + 8 orphaned GUID smart_scripts deleted
- **`_04`**: ContentTuningID enrichment for 4,820 spawned CT=0 creatures (3,877 AreaTable + 943 neighbor interp)
- **`enrich_content_tuning.py`** created at `C:\Users\atayl\source\wago\` — two-pass CT enrichment tool
- **`coord_transformer.py`** created at `C:\Users\atayl\source\wago\` — Wowhead zone% to world XYZ transformer. Dry-run: 1,856 critical + 1,626 high spawns ready
- **8/8 QA checks pass**: 0 missing diff0, 0 SmartAI orphans, 0 AIName typos, 0 orphan GUID scripts, 181 GUID-based retained, 98 unresolved CT=0 (sparse instanced maps)
- **Data quality findings**: 51 missing loot templates, 14 HealthModifier=0, 1,907 orphaned waypoint paths (pre-existing)
- Commits: `f0782d5030`, `9536a248b6`, `21fa23b0d1`

## Mar 5 2026 (session 47 — Gist Accuracy Audit + hotfix_data R3 Cleanup)
- **Gist accuracy audit**: Verified ALL numbers against live DB. Fixed 6 critical errors: smart_scripts 792K→294K, Part 11 hotfix tables (pre-audit→post-audit), hotfix_data 835K→227K, DB sizes
- **hotfix_data R3 cleanup APPLIED**: `cleanup_hotfix_data_orphans.py` removed 608,401 orphaned entries (453K broadcast_text_duration + 153K spell_effect + 1.9K from 38 missing tables). 226,984 entries remaining
- **OPTIMIZE/ANALYZE**: hotfix_data reclaimed space, stats refreshed. Hotfixes DB: 637→535 MB
- **Gist updated 3x** this session: accuracy corrections, then hotfix_data final numbers (226,984, 535 MB)
- **82 [DNT] Note duplicates found** on map 2441 — low priority, not fixed

## Mar 5 2026 (session 46 — WPP Script Hardening)
- **Root cause**: Runtime `start-worldserver.sh` had stale WPP path (`out/` subdir that doesn't exist). `cd` failed silently, WPP never ran.
- **20-bug QA** across 4 files (`start-worldserver.sh`, `extract_transmog_packets.py`, `wpp-inspect.sh`, `opcode_analyzer.py`)
- **start-worldserver.sh** (runtime + tc-packet-tools): EXIT trap for bnetserver, `$WPP` full path, `cd` error guards, `set -o pipefail`, WPP exit check, `sleep 1` flush, `stat || echo 0`, transmog extraction integration, archive `transmog_extract.txt`, `exit $EXIT_CODE`
- **extract_transmog_packets.py**: Streaming (no readlines), dynamic SQL glob, `--pkt-dir` CLI arg, existence check fix, expanded HOTFIX_TABLES. Commit `8584c3c2e0`
- **wpp-inspect.sh**: Removed `pipefail` (broke grep), capped transmog output
- **tc-packet-tools pushed**: Commit `821e74f`

## Mar 5 2026 (session 45 — DB Report Update)
- **Hotfix audit tools committed**: `hotfix_differ_r3.py`, `gen_practical_sql_r3.py`, `build_table_info_r3.py`, `merge_results.py` + README.md + .gitignore. Commit `9ae9d40788`
- **Gist updated**: `528e801b53f6c62ce2e5c2ffe7e63e29` — 831→1076 lines. Added Part 13 (audit results), Part 16 (tooling catalog), timeline, updated Parts 2/7.4/11/12/14
- **Note**: Original hotfix_audit/ files disappeared from disk between Read and Write (cause unknown — not hooks). Recreated from cached Read content

## Mar 5 2026 (session 44 — Tools Consolidation)
- **Moved Excluded → C:\Tools**: Consolidated all reference data/tools under `C:\Tools\` (was `C:\Users\atayl\OneDrive\Desktop\Excluded\`)
  - Moved: LoreWalkerTDB, TrinityCore-master, dbd, wow-export, wow-ui-source-live, docs
  - Deleted: stale WoW.tools duplicate, empty Excluded dir
- **Fixed WPP path everywhere**: `WowPacketParser/out/` → `WowPacketParser/` (no `out/` subdir). Updated 13 files across 4 repos
- **Added missing tools to inventory**: DBC2CSV, Ymir 66220, dbd, wow-export, wow-ui-source-live, TrinityCore-master, LoreWalkerTDB
- **Updated settings**: `.claude/settings.local.json` permission `~/Desktop/**` → `C:/Tools/**`
- **Committed + pushed**: wago-tooling (`b56bfb0`), tc-packet-tools (`d956a5a`), trinitycore-claude-skills (`25967f7`)

## Mar 5 2026 (session 43 — CTD Fix + SmartAI Cleanup + Deferred Triage)
- **Missing CTD rows fixed**: 26,745 creatures missing DifficultyID=0 → 0 remaining. 3-step SQL: copied 24,070 Diff2→Diff0, 68 from other difficulties, 2,607 default rows. Commit `f0782d5030`
- **SmartAI orphans cleaned**: 5,894 creatures with AIName='SmartAI' but no smart_scripts → cleared AIName. 620 were spawned (startup errors eliminated). Same commit
- **Raidbots pipeline confirmed current**: `wago_common.py` already 66220, SQL regenerated Mar 3, +17 items delta — no action needed
- **Deferred items triaged**: Wowhead 403 still blocked, missing spawns need coordinate transformer, quest reward text needs data source. SmartAI orphans were the only actionable item → fixed

## Mar 4 2026 (session 42 — Transmog Client Wiki + Repo Cleanup)
- **Repo reorganization**: Moved docs → `doc/`, tools → `tools/`, batch scripts → `tools/build/` (gitignored). Deleted 1.4 GB hotfix_audit contents, NUL, TransmogBridge.zip. Updated .gitignore. Commit `a7cf01b4ba`
- **Transmog Client Lua Reference Wiki**: Built 3,487-line wiki (`doc/transmog_client_wiki.md`) from 15 Blizzard Lua/XML source files
  - 16 sections (0-15): ID Glossary, Slot Architecture, 4 API namespaces, Outfit Flow, Paperdoll, Events, Enums, Structures, Packets, Hidden Items, Cross-Reference, Server-Side Mapping
  - 189 functions, 23 events, 24 data structures documented
  - 6-phase fix/enhance pass: 8 error fixes, Section 0 (ID Glossary), Section 15 (Server-Side Mapping with actual RoleplayCore opcodes/handlers)
- **Transmog Cheatsheet**: 119-line standalone quick reference (`transmog_cheatsheet.md`) — ID types, DisplayType decision tree, slot numbering, key events, top 10 API calls, server opcodes, PR #760 bugs
- **Commit**: `ad8f9eaa9f`, pushed to origin/master

## Mar 4 2026 (session 41 — Auth Bypass Revert + DB Optimization)
- **Auth bypass reverted**: `WorldSocket.cpp` now rejects connections with missing auth key (was bypassing for local dev). Commit `8bbd610fc7`
- **TC build 66220 keys applied**: `2026_03_04_00_auth.sql` — all 7 platform/arch/type keys. INSERT IGNORE for idempotency
- **Creature DB2 orphans cleaned**: 137 hotfix_data entries for hash `0xC9D6B6B3` (Creature DB2, client-only) removed. Commit `319c2781cb`
- **Transmog diagnostic build committed**: Session 36 diagnostic changes (secondary shoulder IgnoreMask fix, deleted set skip, caller tracing). Commit `c1e9a53c84`
- **DB optimization**: OPTIMIZE TABLE on all 517 hotfix tables, ANALYZE TABLE on 5 world tables. Hotfixes DB: 867 MB on disk
- **Snapshot pruning**: 11 old snapshots deleted (1.09 GB freed), keeping 6 most recent
- **Server boot verified**: 26s startup, 835,385 hotfix records, no auth bypass entries, no new errors
- **Pushed**: 3 commits (`8bbd610fc7`, `c1e9a53c84`, `319c2781cb`)

## Mar 4 2026 (session 40 — Hotfix Redundancy Audit Round 3 + Cleanup)
- **Goal**: Complete R3 type-aware audit of all 109 hotfix tables, execute cleanup
- **R3 audit tooling**: Built `hotfix_differ_r3.py` (type-aware comparison), `gen_practical_sql_r3.py` (SQL generator), `gen_inventory_report.py` (6-section report), `prep_r3_groups.py` (parallel grouping)
- **Key bugs fixed during development**:
  - Stripped match intercepting array columns before bracket matching (reordered steps)
  - 0-indexed vs 1-indexed array detection (check if `base+"0"` exists in db_cols)
  - broadcast_text_duration `ID` compared as data (added skip_cols for original PK)
  - Float32 relative tolerance too tight (2e-6 → 1e-5 for TC SQL serialization artifacts)
  - Unsigned/signed int32 false positives (added `(a & 0xFFFFFFFF) == (b & 0xFFFFFFFF)`)
- **R3 results**: 109 tables, 0 errors. 767,691 redundant (76.2%), 8,396 override (0.8%), 231,199 new (23.0%)
- **Cleanup executed**: 15 TRUNCATEs (14,646 rows) + 10 partial DELETEs (753,045 rows) + hotfix_data hash cleanup. 27/27 verification checks PASS
- **DB optimized**: 970.9 → 881.5 MB
- **3-round totals**: ~10.6M redundant rows removed across R1+R2+R3. 239,595 genuine rows remain
- **Snapshot**: `hotfixes_2026-03-04_173959_pre-round3-cleanup.sql.gz` (114.5 MB)

## Mar 4 2026 (session 39 — Transmog Validator + PR #760 Update)
- **Goal**: Build transmog cross-validation tool, update PR #760 known issues
- **validate_transmog.py**: 622-line validator, 7 checks across WTL (155K IMAIDs, 62K appearances, 4.8K sets, 71K set items, 90 illusions, 14 slots) vs server hotfix overrides. 0.8s runtime
- **Results**: 0 errors, 2 warnings (DT=12/14 not in DisplayTypeToEquipSlot switch — intentional ranged/profession gaps), 72 info (DB2 placeholder IMAIDs in TransmogSetItem)
- **Key finding**: Server hotfix tables are mostly empty (0 IMA rows, 6 IA rows, 4 set rows) — TrinityCore loads from DBC at runtime. No data mismatches in overrides
- **PR #760 updated**: Added Bugs F (SetID mapping destroyed after first apply), G (0x80 pad byte), H (CMSG_TRANSMOGRIFY_ITEMS never fires). Added TransmogBridge addon dependency note. Added full data validation section with row counts and results
- **Commit**: `fdabed9` pushed to wago-tooling master

## Mar 4 2026 (session 38 — WTL Client Library)
- **Goal**: Create Python client library for wow.tools.local REST API
- **wtl_client.py**: 250-line typed REST client — 13 methods (build, db2_list, header, peek, find, export_csv, relations, hotfix_list, file_exists, is_running, as_dataframe), 3 exception types, thread-local sessions, exponential backoff, module singleton. diff_db2/download_hotfixes stubbed as NotImplementedError (need multi-build)
- **test_wtl_client.py**: 20 pytest integration tests (18 online, 2 offline). All 20 passed. WTL confirmed to return hotfixed data (spell 1247917 resolves via peek)
- **start_wtl.bat**: One-click launcher at `C:\Tools\WoW.tools\`, polls until ready, opens browser
- **Commit**: `c531eb9` pushed to wago-tooling master

## Mar 4 2026 (session 37 — Phased Cleanup Plan: Phase 0+1)
- **Goal**: Execute 6-phase cleanup plan v2. Completed Phase 0 (pre-flight) and Phase 1 (safe quick wins)
- **Phase 0**: Pre-flight snapshot (`pre-cleanup` label), clean working tree confirmed, HEAD at `ee10d6495c`
- **Phase 1a — ScriptName='0'**: Found 23 entries (all 9100xxx custom imports + 99213894). `2026_03_04_07_world.sql` applied. QA: 0 remaining
- **Phase 1b — Invalid spell refs**: SKIPPED. Hotfix cleanup already removed spell_name (400K→15 rows). Server DBErrors.log shows 0 creature_template_spell errors — spells resolve from DBC at runtime
- **Phase 1c — Duplicate bunny**: Entry 198363 had 3 copies (not 2). `2026_03_04_08_world.sql` deletes 2, keeps guid 3000072198. QA: 1 remaining
- **Phase 1d — Trainer orphans**: All 7 are real trainers by lore (post-Cataclysm decorative). SKIPPED — retail-accurate
- **Phase 1e — SmartAI orphans**: Olivia Jayne (43451) + Captain Garrick (116160) cleared. `2026_03_04_09_world.sql` applied. QA: 0 Stormwind SmartAI orphans
- **Key discovery**: Hotfix cleanup was already applied between sessions — 276 tables truncated, 110 partially cleaned, ~9.63M rows removed. hotfix_data 1.08M→1.01M (companion cleanup still pending)
- **Updated counts**: SmartAI orphans server-wide 10,944→5,896, Missing CTD rows 1,403→26,756, AIName leading spaces already 0
- **SQL files created**: `2026_03_04_07_world.sql`, `2026_03_04_08_world.sql`, `2026_03_04_09_world.sql`
- **Phase 2 — Stormwind CTD rows**: 11 entries (not 9) missing DifficultyID=0 rows. 3 got DB2-backed ContentTuningID/CreatureDifficultyID (Anduin=781/182331, Jaina=794/162454, Malfurion=288/147872). 8 others got dominant SW defaults (864/11 or 1227/5 for bunny). `2026_03_04_10_world.sql` applied. QA: 0 missing
- **Commits pushed**: `21b708c950` (ScriptName), `3008837b72` (bunny), `178e241707` (SmartAI), `064069f991` (CTD rows)
- **Hotfix R2 cleanup applied**: 9 tables truncated + 6 partial deletes (204K rows). All counts match audit exactly
- **Hotfix companion cleanup**: 174,799 orphaned hotfix_data entries deleted (17.3% orphan rate). `2026_03_04_04_hotfixes.sql`. Before: 1,010,336 → After: 835,537
- **Server boot test**: 835,400 hotfix records loaded, 36s startup, 0 hotfix errors
- **Auth bypass audit**: TC published 66220 keys same day (2026-03-04). Bypass CAN be reverted. Not modified this session (code review only)
- **hotfix_audit/ gitignored**: 1.3 GB working directory, reference data in memory files
- **Commits pushed**: `22d3f83d57` (companion cleanup), `06c775680c` (gitignore)
- **Status**: Phases 0-5 complete, pushed

## Mar 4 2026 (session 36 — Transmog Diagnostic Build: 5 Bugs)
- **Goal**: Investigate 5 observed transmog bugs (A-E) with diagnostic logging
- **Bugs found during testing**:
  - Bug A: Paperdoll strips naked on second UI reopen
  - Bug B: Outfit with no head/shoulders → old appearances persisted (back DID clear)
  - Bug C: Monster Mantle ghost appearance
  - Bug D: Draenei lower leg geometry disappeared
  - Bug E (CRITICAL): Single wand transmog reverted entire character's transmog
- **Root cause confirmed (Bug E)**: `HandleTransmogrifyItems` → `SetEquipmentSet` → `_SyncTransmogOutfitsToActivePlayerData` → full ViewedOutfit clear+rebuild. Single-item transmog triggers rebuild of ALL slots from saved outfit data
- **Fix applied**: `fillOutfitData` bootstrap gated on IgnoreMask bit SET (only bootstraps ignored slots, not bridge-cleared slots)
- **7 diagnostic tasks completed**: bridgeClearedMask audit, post-reapply logging, fillOutfitData canary, ApplyTransmogOutfitToPlayer per-slot log, HandleTransmogrifyItems entry+sync log, secondary shoulder audit, _SyncTransmogOutfitsToActivePlayerData entry log
- **Build**: Clean 8/8, worldserver.exe deployed
- **Status**: Debug.log truncated, server shutdown, awaiting restart + test sequence (Bug B first, then Bug E separately)
- **NOT YET COMMITTED** — diagnostic build only, awaiting test results before committing

## Mar 4 2026 (session 35 — Transmog Packet Log Extractor)
- **Goal**: Parse WPP packet log output files and extract all transmog-related content
- **Created**: `extract_transmog_packets.py` — scans 5 WPP output files (parsed txt 13.7M lines, hotfixes SQL 1.6M lines, wpp SQL, world SQL, errors)
- **Extracts**: 6 sections — transmog protocol packets, TransmogBridge addon messages (TMOG_LOG/TMOG_BRIDGE/TSPY_LOG), UPDATE_OBJECT transmog fields, hotfix SQL tables (item_modified_appearance, transmog_illusion, transmog_set, transmog_set_item, transmog_set_group), other SQL mentions, errors
- **Results from test run**: 4 protocol packets, 76 addon messages, 5 hotfix tables (76K+ rows), 2 WPP refs, 4 error lines → 0.5MB output
- **Commit**: `ee10d6495c`

## Mar 4 2026 (session 34 — Transmog Comprehensive QA Audit)
- **Goal**: Full code + DB + log audit of the entire transmog system
- **Method**: 5 parallel agents reviewing TransmogrificationHandler.cpp, TransmogrificationUtils.cpp, Player.cpp transmog paths, DB state, and memory/notes
- **Findings**: 2 HIGH bugs (spell_clear_transmog missing outfit sync/ViewedOutfit rebuild; backslash line-continuations posing as comments), 5 MEDIUM (wrong active outfit tracking, enchant illusion bootstrap gap, null-check gap, plus 2 in dead code paths), 6 LOW (dead handler, tabs, signed shift, etc.)
- **DB health**: 156K IMA rows, 2 orphaned entries (items 244391/265073), zero log errors, spell 1247917 fully wired
- **No code changes**: Audit-only session. All previous transmog commits already pushed
- **Item 182306 (Monster Mantle)**: Investigated but fix not yet applied — would redirect appearance to Hidden Shoulder (24531)

## Mar 4 2026 (session 33 — Database Optimization Report for CaptainCore)
- **Goal**: Build comprehensive report documenting all DB engineering work for CaptainCore (LoreWalkerTDB creator) to share on Discord
- **Report created**: `RoleplayCore_Database_Report.md` — 829 lines, 15 parts + appendices
- **Published as Gist**: https://gist.github.com/VoxCore84/528e801b53f6c62ce2e5c2ffe7e63e29
- **2 QA passes**: First caught understated totals and structural issues. Second (user-flagged) caught significant number inflation — loot dedup 3.19M headline was 94% self-inflicted, hotfix_data/quest POI/SmartAI counts were DB totals not our additions. All corrected to honest net figures
- **Discord blurb**: Reframed around LW-specific benefits (data quality findings, import tools, upstream fix opportunities) after user feedback that CaptainCore doesn't need internal server optimizations
- **Key lesson**: Always distinguish gross vs net, self-inflicted vs pre-existing, DB totals vs additions when reporting data work
- **Also committed**: Transmog diagnostic logging (TC_LOG_DEBUG traces for outfit sync, slot clearing, single-item transmog)
- **Commits**: `7ce7fcd5db` (transmog diagnostics), `86220bf380` (report) — pushed

## Mar 4 2026 (session 32 — Stormwind City audit + portal room overhaul)
- **Goal**: Make Stormwind NPCs/GOs as accurate as possible vs retail (LoreWalkerTDB reference)
- **Spawn audit**: Applied +250 creatures / +92 gameobjects from pre-generated LW fix files (INSERT IGNORE)
- **ZoneId cleanup**: Set zoneId=1519 for 213 creatures + 1,094 gameobjects with zoneId=0 in Stormwind bounds
- **Quest flag fixes**: Entry 68 (Guard) npcflag 3→1, Entry 1976 (Patroller) npcflag 3→0
- **Portal room deep audit**: 6-agent parallel QA of Wizard's Sanctum portal room
  - Deleted 10 duplicate/broken old portals (500391-500398 range + 700011)
  - Removed 3 LW import artifacts (990xxx/400xxx guids)
  - Deleted stale Z=29 Larimaine Purdue spawn (guid 313822)
  - Raised Hellfire Peninsula portal to correct Z=68.18
- **Founder's Point portal fix**: Spell 1235595 had zero spell_effect rows (inert). Added spell_effect (Effect=15, ID 1900004) + hotfix_data + spell_target_position (map 2735)
- **Silvermoon portal fix (2 iterations)**:
  - First attempt: wired spell 1259194 (Mage portal — wrong spell entirely). 3s cast, lvl 68 req, Effect 50 TRANS_DOOR
  - User reported still broken → deep investigation found correct spell: **1286187** "Portal to Silvermoon" (instant, no req, Effect 252, retail spell_effect rows already exist)
  - Final fix: GO 621992 Data0 → 1286187, added spell_target_position, cleaned up custom spell_effect/hotfix_data for 1259194
- **Key lesson**: GO type 22 (SPELLCASTER) Data0 must reference the right spell category. Mage portal spells (Effect 50 TRANS_DOOR) summon a portal GO — they're NOT direct teleports. GO-click spells use Effect 252 (TELEPORT_WITH_VISUAL_LOADING_SCREEN)
- **Portal room final state** (16 GOs, 15 destinations): Azsuna, Bel'ameth, Boralus, CoT, Dalaran-Northrend, Dornogal (phase-split pair), Founder's Point, Hellfire, Jade Forest, Oribos, Shattrath, Silvermoon, Stormshield, Exodar, Valdrakken
- **Remaining items**: 95 bad quest-giver entries, 3 SmartAI orphans, 4 missing creature_template_difficulty, 15 class trainers (design decisions)
- **Commits**: `980f521fe9` (build 66220 + transmog), `f894f510e0` (Stormwind audit) — pushed
- **Also committed**: Build 66220 auth bump, clear-transmog spell (1247917), transmog IgnoreMask diagnostic logging

## Mar 4 2026 (session 31 — Stale data detection + paperdoll flush)
- **Bug 1 (stale HEAD/SHOULDER)**: Layer 1 `GetViewedOutfitSlotInfo` returns currently-worn appearance for ALL slots, including ones the outfit doesn't define. HEAD/SHOULDER always had non-zero stale IMAIDs
- **Fix**: Pre-snapshot comparison in TransmogBridge.lua. Before Layer 1, capture `GetSlotVisualInfo.appliedSourceID` for all slots. After merge, if merged IMAID == snapshot IMAID and slot isn't from Layer 2 → stale → clear. `layer2Slots` set exempts user choices
- **Bug 2 (paperdoll still naked)**: `ClearDynamicUpdateFieldValues` runs (confirmed by logging) but client doesn't refresh. Clear+rebuild alone doesn't trigger SMSG_UPDATE_OBJECT delivery
- **Fix**: Added `SendUpdateToPlayer(this)` + `ClearUpdateMask(true)` at end of `_SyncTransmogOutfitsToActivePlayerData()`, guarded by `IsInWorld()`
- **Also fixed**: ALWAYS_NIL_SLOTS clear logic confirmed working after addon was redeployed to client (old addon copy was the actual bug)
- **Diagnostic logging**: Per-slot `nil-detect:`, `stale-detect:`, ClearDynamic trace, flush trace
- **Commit**: `407b9aabc1` — pushed

## Mar 3 2026 (session 30 — Transmog 4-bug fix: pad byte, shoulder, hidden, paperdoll)
- **Confirmed**: "unknown transmog set id 1" bug FIXED (6/6 applies succeed, diagnostic logging verified)
- **Fix 1 (pad byte 0x80)**: Client sends 0x80 pad byte after name length, not 0x00. Removed equality check from `TransmogOutfitNew::Read()` (line 176) and `TransmogOutfitUpdateInfo::Read()` (line 337) in TransmogrificationPackets.cpp
- **Fix 2 (secondary shoulder triple-overwrite)**: Client sends DT=1 at ordinals 1,2,3. Old `seenPrimaryShoulder` boolean caused ordinal 3 to overwrite ordinal 2. Replaced with ordinal-based check: ordinal==3 → secondary, else first-wins. Both `TransmogOutfitNew::Read()` and `TransmogOutfitUpdateSlots::Read()`
- **Fix 3 (hidden appearances)**: TransmogBridge.lua — all 3 client API layers return nil for hidden items (shoulders, back, tabard, shirt, wrists). Added `ALWAYS_NIL_SLOTS = {0,2,12,13}` (known broken). Other slots nil = hidden → send explicit `slot.0.0` clear
- **Fix 4 (naked paperdoll)**: `_SyncTransmogOutfitsToActivePlayerData()` in Player.cpp never cleared `ViewedOutfit.Slots` and `.Situations` dynamic arrays before re-populating. Arrays accumulated (14→28→42...), client rendered naked. Fixed with `ClearDynamicUpdateFieldValues` for both before `fillOutfitData`
- **Root cause investigation (paperdoll)**: Traced through TransmogrificationHandler.cpp → TransmogrificationUtils.cpp → Player.cpp SetVisibleItemSlot → _SyncTransmogOutfitsToActivePlayerData → client wow-ui-source-live Blizzard_Transmog.lua TransmogCharacterMixin:RefreshSlots()
- **Build**: Compilation succeeded (8/8 targets), initial link failed (worldserver.exe locked), SOAP shutdown, re-link succeeded (5/5)
- **Files changed**: TransmogrificationPackets.cpp (4 edits), TransmogBridge.lua (1 edit), Player.cpp (1 edit)
- **Commit**: `272c373105` — pushed
- **Memory updated**: transmog-implementation.md (pad byte, shoulder ordinal, hidden detection, paperdoll fix)

## Mar 3 2026 (session 29 — Hero/Warchief Call Board dedup)
- **Problem**: LoreWalker TDB import placed old-framework boards (206294 Hero, 206116 Warchief) at exact coords of every modern board — players saw duplicate stacked boards
- **Audit**: 25 entries total across Hero's Call Board + Warchief's Command Board. Old entries used `data1=pageText` framework, modern use `data0=2824` conditionID. `990...` guids = LW import, `4000...` = another import
- **Gotcha**: Modern entries 281339, 278575 (Hero) and 278347, 278457 (Warchief) had **zero gameobject_queststarter rows** — the old stacked boards were the ones actually serving quests. Deleting old boards left modern boards non-functional
- **Fix**: Removed 25 stacked/orphan spawns + copied quest associations from old entries to the 4 zero-quest modern entries via `INSERT IGNORE INTO gameobject_queststarter SELECT`
- **Lesson**: When deduplicating stacked gameobjects with different entries, always check which entry has the quest/script/condition associations before deleting. The "correct-looking" modern entry may be an empty shell
- **Lesson**: `gameobject` table has 175K rows with only PK on `guid` — self-joins need a temp index on `(id, map)` or they run forever. Always KILL lingering MySQL queries after aborting client (`SHOW PROCESSLIST` → `KILL <id>`)
- Commit `0778fac65d`, SQL: `sql/updates/world/master/2026_03_03_02_world.sql`

## Mar 3 2026 (session 28 — MySQL optimize script fix)
- **Problem**: `_optimize_db.bat` wasn't reducing any bloat despite running OPTIMIZE TABLE on "fragmented" tables
- **Root cause**: Script used `DATA_FREE` from `information_schema.TABLES` — this metric is **bogus for InnoDB file-per-table**. It reports free space from the shared `ibdata1` system tablespace, not the individual `.ibd` file. Example: `hotfix_data` had 56MB `.ibd` file but `DATA_FREE` claimed 412MB free (735% — physically impossible)
- **Fix**: Rewrote script to use `FILE_SIZE` from `information_schema.INNODB_TABLESPACES` (actual `.ibd` file size). Now shows before/after file sizes so user can see real savings. Dropped bogus "wasted" column
- **DB stats**: hotfixes 2.8GB, world 1.8GB, ibdata1 76MB. Tables are compact — minimal real fragmentation

## Mar 3 2026 (session 27 — Hotfix pipeline crash fix)
- **Root cause**: Server crashed on client connect — `ByteBuffer::append` assertion `(size() + cnt) < 100000000` fired during `HotfixConnect::Write` → `HandleHotfixRequest`. Monolithic SMSG_HOTFIX_CONNECT packet exceeded 100MB with 1.08M hotfix_data rows (966K unique push IDs)
- **6 bugs identified** via comprehensive audit:
  - Bug #1 (CRITICAL): No chunking/pagination of HotfixConnect response
  - Bug #2 (CRITICAL): 100MB ByteBuffer assert fires before compression can help
  - Bug #3 (HIGH): Memory doubling — HotfixContent + _worldPacket both hold full copy
  - Bug #4 (MEDIUM): ByteBuffer grows in 400KB fixed steps — excessive reallocations
  - Bug #5 (MEDIUM): No server-side cap on hotfix request count
  - Bug #6 (LOW): Large SendAvailableHotfixes at login (confirmed async/safe)
- **Fixes applied** (3 files):
  - `ByteBuffer.cpp`: Assert raised 100MB→500MB, exponential growth (doubles capacity, capped 32MB step)
  - `HotfixHandler.cpp`: Chunked responses at 50MB via `unique_ptr<HotfixConnect>` rotation (Packet class has deleted copy, no implicit move), 1M request cap with TC_LOG_WARN
  - `HotfixPackets.cpp`: `HotfixConnect::Write()` releases intermediate buffers (clear+shrink_to_fit) after serialization
- **Key insight**: `Packet` base class deletes copy constructor which inhibits implicit move — drove `unique_ptr` approach for chunking
- **Commit**: `12c7668c80` — pushed

## Mar 3 2026 (session 26 — TransmogBridge context sync)
- **Memory sync**: Updated transmog-implementation.md, recent-work.md, MEMORY.md with complete TransmogBridge state
- **Current state**: All 14 slots working via manual clicks, 13/14 via outfit loading (secondary shoulder known gap). Clear All Transmog spell (1247917) working. Illusions + clear single slot just deployed, awaiting test
- **Uncommitted changes**: TransmogrificationHandler.cpp — SendUpdateToPlayer+ClearUpdateMask flush added to HandleTransmogOutfitNew, HandleTransmogOutfitUpdateInfo, HandleTransmogOutfitUpdateSituations, FinalizeTransmogBridgePendingOutfit (fixes stale UpdateField race)
- **PR #760** on KamiliaBlow/RoleplayCore remains open (upstream wants server-only fix without addon, separate effort)

## Mar 3 2026 (session 25 — CLAUDE.md audit/rewrite)
- **Comprehensive audit**: Read all 20 memory topic files + CLAUDE.md. Found: redundancy (65-line debugging pipeline duplicated), outdated refs (stale -j4, missing scripts), missing systems (player morph, wormhole generators, clear transmog)
- **CLAUDE.md rewrite**: 263→148 lines (-44%). Both build configs in table, all 8 custom systems, gates-only debugging pipeline with memory pointer, compressed parallelism section, added Craft/ dir, hardware specs in Work Style
- **Moved**: Wago CSV oscillation warning from CLAUDE.md to wago-db2-tables.md
- **QA pass**: Verified all dirs, files, and 20 See Also links exist on disk. Caught dropped Craft/ — re-added
- **Commit**: `76cd9c7b0e` — pushed

## Mar 3 2026 (session 24 — Project-wide audit + optimization)
- **6-agent parallel audit**: config, files, scripts, build, SQL, game systems
- **MySQL**: buffer pool 6G→8G, 75% dump/load on restart, `_optimize_db.bat` created (auto-defrag — later fixed in session 28: DATA_FREE metric was bogus), 24 tables optimized
- **worldserver.conf**: `Eluna.CompatibilityMode=false` (unlocked 4 map threads), `MaxCoreStuckTime=600`, `SocketTimeOutTimeActive=300000`
- **Build**: `-j4`→`-j20` in CMakePresets.json + all 9 batch files, `TOOLS=OFF` (map extractors don't rebuild)
- **Memory leaks fixed**: EffectsHandler — `RemoveEffect` now deletes `EffectData*`, `Reset` deletes before clear, `GetUnitInfo` deletes on invalid unit, dead `Clear()` removed
- **RBAC fix**: `.settime` was using `RBAC_PERM_COMMAND_NPC_YELL` → new `RBAC_PERM_COMMAND_SETTIME = 1022` (GM role 193)
- **Cleanup**: Deleted junk file `4` (accidental mysql help redirect)
- **Commits**: `d4b9b33a9e` (build config), `c3e822dcf9` (memory leaks + RBAC), `bf9c95105f` (optimize script) — all pushed
- **Remaining audit items** (not yet done): .gitignore additions, cross-faction AllowTwoSide.*, MinPetitionSigns=0, dead code cleanup (Hoff class, RotationAxis enum, marker system), non-idempotent setup SQL, RelWithDebInfo /Ob2 + LTO

## Mar 3 2026 (session 23 — Build Diff Audit)
- **Goal**: Diff DB2 CSVs across 5 builds (66044→66102→66192→66198→66220), cross-reference with MySQL, generate action items
- **Phase 1**: Downloaded 1,097 CSVs each for builds 66044, 66102, 66198 (66192/66220 already had)
- **Phase 2**: Wrote `diff_builds.py` — parallel CSV diffing with ThreadPoolExecutor, CLI args, JSON+markdown output
- **Phase 3**: Wrote `cross_ref_mysql.py` — queries spell_script_names, hotfixes.item_sparse, quest_template, creature_template
- **Phase 4**: Generated `build_audit_actions.md` with red/yellow/green/blue categorization
- **Key discovery**: Wago export oscillation — SpellEffect swings 269K↔608K between builds (export artifact). Added oscillation detection to diff_builds.py
- **Results**: +77 spells, +17 items, +9 quests cumulative. Zero breaking changes. 40 scripted spells safe (append-only effects)
- **Bug fix**: ProcessPoolExecutor→ThreadPoolExecutor (global vars not shared across processes)
- **Docs**: Updated CLAUDE.md with oscillation warning, created raidbots/NOTES.md, created memory/build-diff-audit.md
- **Spell 1251299**: Only removed spell — no spell_script_names entry (safe), orphan in hotfixes.spell_name

## Mar 3 2026 (session 22 — Claude Code optimization)
- **System specs documented**: Ryzen 9 9950X3D (12C/24T), 128GB DDR5-5600, RTX 5090 32GB, Samsung 980 PRO 2TB NVMe
- **Build parallelism**: Updated all `ninja -j4` → `-j16` in CLAUDE.md (3 occurrences). 12 cores means -j16 is sweet spot
- **Settings**: Added `alwaysThinkingEnabled: true` to `~/.claude/settings.json`
- **Statusline**: Fixed Opus 4.6 pricing ($5/$25 vs old $15/$75 — was 3x overestimate). Added cache read tracking
- **Keybindings**: Created `~/.claude/keybindings.json` — Ctrl+K Ctrl+F (model picker), Ctrl+K Ctrl+T (thinking), Ctrl+K Ctrl+O (transcript)
- **Named sessions**: Created 5 .bat scripts in `~/.claude/sessions/` — transmog, companion, debug, general, remote-control server
- **CPU topology**: 9950X3D reports "16-Core" but WMI shows 12C/24T (NumberOfEnabledCore=16 is WMI quirk on X3D)
- **Memory updated**: Hardware specs, performance config, keybindings, sessions, pricing all documented

## Mar 3 2026 (session 20 — Post-LW-import DB error cleanup)
- **Goal**: Reduce 627K DBErrors.log lines (~53K pre-existing TC, rest LW-introduced)
- **Task 1 — SmartAI cleanup** (2,808 rows):
  - 1a: 5 QUEST_OBJ_COMPLETION scripts with objective=0
  - 1b: 1,095 SMART_ACTION_CAST referencing non-existent spells (validated against `hotfixes.spell_name` + `serverside_spell`)
  - 1c: 1 script for creature not using SmartAI
  - 1d: 776 unsupported action types (18,19,75,104,105,106 — all confirmed `UNUSED, DO NOT REUSE` in SmartScriptMgr.h)
  - 1d: 37 unsupported event types (12,66 — confirmed UNUSED)
  - **KEY FINDING**: Event type 47 (`SMART_EVENT_QUEST_ACCEPTED`) is SUPPORTED (105K rows preserved). User's original plan incorrectly listed it as unsupported
  - 1e: 803 scripts referencing non-existent waypoint paths
  - 1f: 91 scripts referencing non-existent creature GUIDs
- **Task 2 — Reference loot**: 0 orphan refs found (creature_loot.Reference column clean, gameobject_loot has NO Reference column)
- **Task 3 — NPC vendor**: 302 items referencing non-existent items + 3 vendors without VENDOR flag
- **Task 4 — Empty pools**: 1,786 pool_templates with no members
- **Task 5 — Empty waypoints**: 47 waypoint_paths with no nodes
- **Task 6 — Duplicate coordinate spawns**: 19,385 creature + 18,485 gameobject duplicates (same id+map within 1 yard). SQL self-join on 681K rows timed out (17+ min) — **used Python** (`find_dupe_spawns.py`) for instant detection. Batch-deleted via `batch_delete_dupes.py` (500 GUIDs/batch). Cascade cleanup: 3,006 creature_addon + 768 gameobject_addon + 706 spawn_group + 84 formations + 78 pool_members + 20 empty pools
- **Total**: 47,478 rows deleted
- **Validation**: ALL 15 checks CLEAN — zero integrity issues
- **Tools created**: `post_import_cleanup.sql` (reusable), `find_dupe_spawns.py`, `batch_delete_dupes.py`
- **Final table counts**: creature 662,327 / gameobject 175,314 / creature_loot 2,949,592 / smart_scripts 792,228 / npc_vendor 165,802

## Mar 3 2026 (session 19 — MySQL performance optimization)
- **Comprehensive MySQL performance audit**: 5 parallel agents collected server variables, table engines/PKs, config file, index coverage, hotfixes structure
- **Phase 1 (my.ini config)**: buffer_pool 16G→6G, key_buffer→8M, slow query log ON (2s threshold + log_queries_not_using_indexes), skip-name-resolve ON
- **skip-name-resolve broke MySQL**: root only had `root@localhost` grant, IP connections failed. Fixed: reverted, added root@127.0.0.1 + root@::1 grants, re-enabled
- **Phase 2 (SQL fixes)**: 7 MyISAM→InnoDB conversions (2 needed ROW_FORMAT=DYNAMIC for FIXED compat), 4 redundant indexes dropped
- **Loot table PK dedup**: 193,542 duplicate rows found across 4 loot tables (creature 193K, gameobject 350, reference 10, item 97). Deduped via CREATE-SELECT-SWAP pattern. PKs added to all 7 loot tables
- **Backup table cleanup**: 101 backup tables dropped across all DBs (~382 MB reclaimed). World went from 360→256 tables
- **Final verified state**: 0 MyISAM, 0 backup tables, all 7 loot PKs, 0 redundant indexes, skip-name-resolve ON, buffer pool 6G (~2.2G used/64% free fresh start)
- **Config file**: `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/UniServerZ/core/mysql/my.ini`
- **DB sizes**: world 256 tables/1,489 MB, hotfixes 517/1,309 MB, characters 151/8.5 MB, auth 48/1.9 MB, roleplay 5/0.1 MB

## Mar 3 2026 (session 18 — LW bulk import)
- **42-table audit**: Categorized all LW extracted tables: 3 fix+import (column mismatch), 18 import (matching schema), 20 skip (already done), 1 excluded (phase_area)
- **Column mismatch fix** (`fix_column_mismatch.py`): Proper tuple-boundary parser (handles quoted strings, nested parens). Fixed 3 tables:
  - `creature`: 28→29 cols (appended `size=-1`)
  - `gameobject`: 24→26 cols (appended `size=-1, visibility=256`)
  - `npc_vendor`: 11→12 cols (appended `OverrideGoldCost=-1`)
  - `scene_template`: SKIP (ours=5 > LW=6, LW has extra NULL column)
- **Pre-import backup**: 888MB `world_pre_lw_import.sql` via mysqldump
- **Validation framework** (`validate_import.py`): 15 orphan checks across spawns, dependents, SmartAI, loot, gossip. Baseline: 179 pre-existing issues
- **5-phase import** (`import_all.py`): Dependency-ordered (spawns first, then dependents):
  - Phase 1 (Spawns): creature +29K, gameobject +20K
  - Phase 2 (Loot): creature_loot +3.25M raw, gameobject_loot +124K raw
  - Phase 3 (Dependents): 12 tables, waypoints +30K, difficulty +26K, etc.
  - Phase 4 (SmartAI): +336K NPC AI scripts
  - Phase 5 (Gossip/Vendor/Text): +486 across 4 tables
- **CRITICAL BUG: Loot table duplication**. `creature_loot_template` and `gameobject_loot_template` have NO PRIMARY KEY — only non-unique index `KEY idx_primary (Entry,ItemType,Item)`. INSERT IGNORE had nothing to ignore, so every LW row was inserted as a duplicate. 6.2M rows (should be ~3.3M).
  - **Fix**: CSV round-trip dedup — export TSV, `sort -u`, TRUNCATE, LOAD DATA LOCAL INFILE
  - creature_loot: 6,207,851 → 3,276,944 (removed 2.93M exact dupes)
  - gameobject_loot: 189,843 → 124,019 (removed 65.8K exact dupes)
  - 193K rows with same (Entry,ItemType,Item) but different Chance/GroupId preserved (valid multi-rule loot)
- **Orphan cleanup**: Killed stuck 50-min DELETE query (had table metadata lock). Ran targeted DELETEs:
  - 26,071 creature_template_difficulty (templates we don't have)
  - 4,206 creature_loot entries (unreferenced by any template)
  - 258 creature + 692 gameobject orphan spawns (missing templates)
  - 3,467+57 spawn_group, 237+355 creature_formations, 2,412 gameobject_addon
  - 104+69 SmartAI, 210 npc_vendor, 23 pool_members, 3 creature_addon
- **Final state**: ALL CHECKS PASSED — zero orphans across all 15 validation checks
- **Net result**: +665,658 rows across 21 tables. Key gains: +336K SmartAI, +184K creature loot, +58K GO loot, +30K waypoint nodes, +29K creature spawns, +20K GO spawns
- **Tools created**: `fix_column_mismatch.py`, `validate_import.py`, `import_all.py`, `cleanup_orphans.sql`, `dedup_loot.sql`

## Mar 3 2026 (session 17 — TransmogBridge 3-layer hybrid merge)
- **Bug fix**: Outfit set loading from transmog UI sent 0 bridge overrides because `SetPendingTransmog` hooks don't fire during outfit loading (only on manual slot clicks)
- **3-layer hybrid merge** in `TransmogBridge.lua`:
  - Layer 1: `GetViewedOutfitSlotInfo` snapshot (captures outfit-loaded armor)
  - Layer 2: `SetPendingTransmog` hook accumulations (captures weapons, tabard, shirt, secondary shoulder — wins on conflict)
  - Layer 3: `C_Transmog.GetSlotVisualInfo` fallback for remaining gaps (uses `pendingSourceID`/`appliedSourceID` — both are IMAIDs)
- **Server fix**: `bridgeOverrodeSecondary` bool flag — decouples secondary shoulder tracking from `bridgeOverriddenMask` bitmask (primary shoulder sets EQUIPMENT_SLOT_SHOULDERS bit, secondary routes to SecondaryShoulderApparanceID via continue before bitmask code)
- **4 files**: TransmogBridge.lua (+111/-17), TransmogrificationHandler.cpp (+50/-32), ChatHandler.cpp (comment), WorldSession.h (comment)
- **Commit**: `aaf2114e55` — pushed

## Mar 3 2026 (session 16 — Pipeline QA + 11-task fix sweep)
- **Comprehensive QA**: 5 parallel agents audited all Raidbots/Wago/LW import scripts + fix SQL + live DB integrity. Found 3 CRITICAL, 12 MODERATE, various LOW issues across 24 checks
- **11 fix tasks created and ALL completed**:
  - **Task 1**: `quest_chain_gen.py` — cross-chain conflict detection (lowest QuestLine ID wins), DFS cycle detection, dedup via `dict.fromkeys()`, self-ref prevention, duplicate UPDATE dedup via `seen_updates` set
  - **Task 2**: `wowhead_scraper.py` — `extract_listview_data()` ported string_char+escape handling from `extract_js_object()`
  - **Task 3**: `wowhead_scraper.py` — `RateLimiter` thread safety (`threading.Lock`), checkpoint resume with high-water mark, `VendorScraper.scrape_one()` inlined fetch
  - **Task 4**: `fix_quest_chains.sql` — **CRITICAL**: Fixed column name `QuestId`→`ID` per actual schema. Replaced path-based CTE with depth-only approach (CHAR overflow on 47K quests). Dynamic dangling ref cleanup via subquery. Verified zero cycles against live DB
  - **Task 5**: `import_item_names.py` — **CRITICAL**: DELETE-before-INSERT idempotency with VerifiedBuild, `AS new` alias (VALUES() deprecated MySQL 8.0.20+), transaction wrapping, SET NAMES utf8mb4. User-requested stub locale guard: only DELETE when replacement data exists
  - **Task 6**: `gen_quest_poi_sql.py` — MySQL warning line skip, `--force` flag, transaction wrapping
  - **Task 7**: `quest_objectives_import.py` — Dead `floatval()` removed, Type validation (0-22), double-quote escaping
  - **Task 8**: `fix_locale_and_orphans.sql` — NOT IN → NOT EXISTS (NULL trap), scoped DELETE to build 61609, separate transactions
  - **Task 9**: `run_all_imports.py` — **NEW**: Master execution script with `--dry-run`, `--step N`, `--skip-verification`. 8-step pipeline, pre-flight checks, cycle verification, exit codes
  - **Task 10**: `wowhead_scraper.py` — Extracted `_find_matching_bracket()` shared helper (handles `"/'` strings, `//` and `/* */` comments, configurable brackets)
  - **Task 11**: `fix_orphan_quest_refs.sql` — **NEW**: 961 orphan quest starter/ender rows cleanup via NOT EXISTS
- **User manual review** of 5 critical files — all approved:
  - `fix_quest_chains.sql` — depth-only CTE correct for functional graph topology (out-degree ≤1)
  - `import_item_names.py` — one fix requested (stub locale guard) → applied
  - `run_all_imports.py` — confirmed `--dry-run` fully implemented, execution order correct
  - `fix_locale_and_orphans.sql` — NOT EXISTS + scoped DELETE approved
  - `quest_objectives_import.py` — reviewed, no additional changes needed
- **Key technical learnings**:
  - MySQL CTE `cte_max_recursion_depth` defaults to 1000, need 5000+ for 47K quests
  - Path-based CTE CHAR columns overflow silently — depth-only approach is correct for functional graphs
  - `VALUES()` function deprecated MySQL 8.0.20+ — use `AS new` alias syntax
  - NOT IN has NULL trap — always prefer NOT EXISTS for DELETE safety

## Mar 3 2026 (session 15 — TC merge + build 66220 auth bypass)
- **TC upstream merge**: Fetched 12 new commits from trinitycore/master. 1 conflict in Opcodes.cpp (CMSG_SELL_ALL_JUNK_ITEMS PROCESS_INPLACE vs PROCESS_THREADUNSAFE — took TC's). Applied 7 SQL updates (2 auth, 1 hotfixes, 4 world). Pushed.
- **Build 66220 client issue**: Battle.net auto-updated WoW from 66198→66220. No TC auth keys yet.
- **Auth bypass (local only)**: Added 66220 to `build_info`, modified WorldSocket.cpp to skip HMAC check when auth key missing (logs warning). TODO comment added. Commit `787b013bc2` — NOT pushed.
- **TC merge duplicate fix**: SellAllJunkItems duplicated in 4 files (ItemPackets.h/.cpp, WorldSession.h, ItemHandler.cpp). Removed old non-const version, kept TC's newer const-ref version. Commit `50fb430e43` — pushed.
- **Git split**: Original single commit split into merge-fix (pushed) + auth bypass (local only) via soft reset + selective staging.
- **Auth key research**: Keys are 16-byte VMProtect-obfuscated values in Wow.exe. Extracted via runtime debugging (x64dbg + WoWDumpFix or Frida). Shauren has this automated. Wrote comprehensive briefing for Claude Desktop extended thinking to investigate extraction.

## Mar 3 2026 (session 14 — Raidbots/Wago/LW data pipeline)
- **Raidbots static data**: Downloaded 47 JSON files (168MB) from `raidbots.com/static/data/live/`. Build 66192. Key: item-names.json (171K items × 7 locales), equippable-items-full.json (107K items), bonuses.json, talents.json
- **Item locale import** (`import_item_names.py`): 1,020,171 rows in item_sparse_locale + 608,480 in item_search_name_locale across 10 locales (6 full from Raidbots: deDE/esES/frFR/itIT/ptBR/ruRU, 4 stubs from TC base: esMX/koKR/zhCN/zhTW). Raidbots doesn't ship Asian/esMX locales
- **Quest chain import** (`quest_chain_gen.py`): 15K+ PrevQuestID/NextQuestID updates from Wago QuestLineXQuest CSV. 1,605 quest lines, 19,202 quests in DB. Final: 21,758 with prev, 17,636 with next
- **Quest POI import** (`gen_quest_poi_sql.py`): 2,880 quest_poi + 5,199 quest_poi_points across 643 quests. Total: 134,856 POI + 292,977 points
- **Quest objectives import** (`quest_objectives_import.py`): 633 new rows across 227 quests. Total: 60,199
- **Quest starters/enders**: Reimported from LoreWalkerTDB via `extract_lw_world.py`. 26,842 creature_queststarter + 33,496 creature_questender + 1,615 GO queststarter + 1,610 GO questender. All already fully populated
- **8 script bugs fixed** across 4 files:
  - `wowhead_scraper.py`: (1) Mapper regex lazy match→bracket-depth parsing, (2) Gatherer.addData nested objects→bracket-depth, (3) extract_js_object single-quote handling, (4) progress/completion find_next→find_next_sibling
  - `import_item_names.py`: (5) Added 4 missing locales (koKR/zhCN/zhTW/esMX), (6) NUL byte escaping
  - `gen_quest_poi_sql.py`: (7) Added USE world; statement, (8) try/except on all int() parsers
  - `quest_objectives_import.py`: (8) try/except on int(r["ID"])
- **Data integrity fixes**: 21 self-refs, 37 circular pairs, 13 three-hop loops, 52 dangling NextQuestID, 29 dangling PrevQuestID — all zeroed. 348+174 locale dupes deleted. 890+630 orphan quest_objectives deleted. 99 orphan item_sparse_locale deleted. 2 NULL Display_lang deleted
- **Final QA**: All integrity checks pass clean. Zero self-refs, circular pairs, loops, dangling refs. Zero locale dupes. Zero orphan POI/points. Zero orphan objectives
- Scripts at `C:/Users/atayl/source/wago/raidbots/`. SQL output at `raidbots/sql_output/`

## Mar 3 2026 (session 13 — Wowhead NPC mega-audit)
- **Wowhead scraper completed**: 216,284 NPCs exported (224,248 requested). Data at `wowhead_data/npc/`
- **3-tier cross-reference audit**: 54,571 total DB operations applied, commit `d7953794d8`, pushed
- **Tier 1** (19,024 ops): type fixes (2,292), name corrections (379), type/classification remapping (6,781), level fixes for NPCs stuck at level 1 (6,548 across 3 priority files), subtitle/subname additions (516+243 revert), NPC flag additions (2,265)
- **Tier 2** (3,282 ops): ContentTuningID corrections for wrong expansion tier (3,013), zone hierarchy fixes (5), service flag removals (21). Reports: 3,716 high-priority missing spawns, 997 genuine service gaps, 198 zone review items
- **Tier 3** (32,265 ops): faction fixes (3), model override resets (232), SmartAI orphan cleanup (106), waypoint orphan cleanup (31,924). Equipment validation: all 51,802 items valid. Faction validation: all 1,367 IDs valid in DB2
- **20 Python analysis scripts** created in `sql/exports/scripts/`
- **8 detailed audit reports** in `sql/exports/cleanup/`
- **Key discovery**: Classification=6 (`MinusMob`) is valid with 6,100 entries. Wowhead tooltips show Chromie Time scaled ranges, not raw ContentTuning ranges. Wowhead coords are zone percentages, not world XYZ.

## Mar 1 2026 (session 12 — PR cleanup)
- **PR rebuild**: Old PRs #34 and #35 on VoxCore84/RoleplayCore were same-repo PRs targeting VoxCore84's master — showed 37 files including non-transmog SQL, spell scripts, AreaTrigger, Unit.cpp, etc.
- **Fix**: Created clean branch from `upstream/master`, cherry-picked only transmog commit `ebb0f1cbe7`. New branch `pr/transmog-ui-12x-clean` had exactly 20 files.
- **Cross-repo PR #760**: Created on KamiliaBlow/RoleplayCore (head: `VoxCore84:pr/transmog-ui-12x`). Clean 20-file diff, comprehensive description with architecture, file breakdown, test plan.
- **Branch cleanup**: Deleted stale local branches `fix/transmog-outfit-npc-guid`, `pr/transmog-outfits`, `pr/transmog-ui-12x-clean`. Remote only has `master` + `pr/transmog-ui-12x`.
- **Closed**: VoxCore84/RoleplayCore PRs #34 and #35

## Mar 1 2026 (session 11 — TransmogBridge testing + PR)
- **IN-GAME TEST CONFIRMED WORKING**: All 14 appearance slots transmogged correctly on character "Judgemental" (guid 8). Full Debug.log pipeline verified: deferred → received 14 overrides → merged → finalized with bridge overrides. MH illusion (id=5394) correctly skipped.
- **Commits**: `e27f103e1b` (illusion strip, stale data correction, log relay, bridgeOverriddenMask — pushed), `d752c12fcd` (add TransmogBridge addon to repo — pushed)
- **PR #35**: Clean transmog-only PR on VoxCore84/RoleplayCore — 20 files, +3546/-108 lines, against upstream/master. Branch `pr/transmog-ui-12x`. Old PR #34 closed.
- **TransmogBridge.zip**: Packaged addon for distribution at `C:/Dev/RoleplayCore/TransmogBridge.zip`
- **Removed chat print**: TransmogBridge addon no longer prints to player chat — server Debug.log relay is sufficient
- **Stale branches cleaned**: Deleted `fix/transmog-outfit-npc-guid` (merged) and old `pr/transmog-outfits` (superseded)

## Feb 28 2026 (session 10 — TransmogBridge implementation + refinements)
- **TransmogBridge addon-message workaround**: Full implementation for 12.x client serializer bug. Deferred finalization architecture. ClearAllPending fix, illusion strip, validateIllusion fix, stale data correction with bridgeOverriddenMask, server-side log relay (TMOG_LOG/TSPY_LOG).
- **Commits**: `1e47b11c23` (initial, pushed), then `e27f103e1b` (all refinements, pushed next session)

## Feb 28 2026 (session 9 — Placement audit tools)
- **go_placement_audit.py** — 6-audit GO placement tool. Compares LW reference (194K spawns) vs our DB (174K). Parses pre-extracted `lw_gameobject.sql` directly. Found 5,837 missing GO spawns, 9 misplaced, 1,625 property mismatches, 6,767 SQL fixes generated.
- **creature_placement_audit.py** — 5-audit creature placement tool. Compares LW reference (680K spawns) vs our DB (652K). Found 21,771 missing creatures, 38 misplaced, 3,178 property mismatches, 24,681 SQL fixes generated.
- **Key finding**: Wago GameObjects CSV is 98.9% type 5 (signs) — NOT useful for placement audit. LoreWalkerTDB dump is the real reference source.
- **Rotation filter**: All 135 rotation "mismatches" were LW `(0,0,0,0)` vs our `(0,0,0,1)` — our identity quaternion is correct, LW's zero quat is invalid.
- **Combined**: ~34K issues, ~31.4K SQL fixes across both tools (26.6K missing spawns + 4.8K property fixes + 47 position corrections)

## Feb 28 2026 (session 8 — GO + Quest audit tools + fixes)
- **go_audit.py** — 15-audit GameObject tool (1285 lines). Audits: duplicates, phases, display, type, scale, loot, quest, pools, events, names, smartai, spawntime, addon_orphans, missing, faction. Cross-refs 161K GO spawns + 85K templates against Wago GameObjects/GameObjectDisplayInfo CSVs.
- **quest_audit.py** — 15-audit Quest tool (1268 lines). Audits: chains, exclusive, givers, enders, objectives, rewards, startitem, missing, orphan_givers, orphan_npcs, poi, offer_reward, questline, addon_sync, duplicates. Cross-refs 47K quests against Wago QuestV2/QuestObjective/QuestLine CSVs + hotfixes.item_sparse.
- **Fix**: Rewrote GO `duplicates` audit to use Python-side grouping+distance instead of MySQL self-join (was timing out on 161K rows)
- **2,279 DB fixes applied** (all verified to zero on re-audit):
  - 1,363 duplicate GO spawns deleted
  - 278 orphan gameobject_loot_template entries deleted
  - 43+2 orphan pool_members (type=1) deleted
  - 371 orphan game_event_gameobject rows deleted
  - 26 orphan gameobject_addon rows deleted
  - 4 GO type mismatches corrected from Wago
  - 25 GO names corrected from Wago
  - 167 missing quest_template_addon rows inserted
- **Full clean counts** (report-only, not fixable):
  - GO: 232 orphaned phases, 59 display issues, 51 oversized scale, 94 placeholder names, 41 SmartAI orphans, 3,168 spawntime issues, 36,603 unspawned templates, 1,332 faction on interactive GOs
  - Quest: 205 exclusive group issues, 11,567 no giver, 9,724 no ender, 129 invalid objectives, 6 invalid rewards, 21,440 in Wago but not world, 1,518 questline refs to missing quests, 336 duplicate pairs
- **Phase_area rollback**: Discovered NPC audit's 148 `phase_area` INSERTs were harmful — they added unconditional visibility to ~43K quest-phased NPCs (DK starting zone, Wrathgate, Hyjal, BfA, etc.). Boralus NPCs were invisible due to phase conflicts. Rolled back all 148 entries, server restart fixed it. Commit `75b8234`.
- **Commits**: `a6ab99b` (tools + initial reports), `b612cb4` (post-fix reports), `75b8234` (phase_area rollback) — pushed to wago-tooling
- **Wowhead NPC scraper**: Restarted twice (stalled at 57K, then boosted to 8 threads/0.15s delay). At ~70K/300K (~23%), ~14K IDs/hr. Est completion: ~16hrs from midnight Feb 28.

## Feb 27 2026 (session 7 — comprehensive QA + Phase 3 new audits)
- **Phase 1 data fixes (batch 3)**: 1,848 DB fixes applied:
  - Movement: 313 zero wander distance → 10, 119 wandering service NPCs set stationary
  - Speed: 8 creatures with absurd walk speeds (12-20x) → 1.0 (9 scripted skipped)
  - Scale: 1 invisible creature (Marrowjaw scale 0→1)
  - Spawn times: 6 rares 0s→300s, 522 vendors 2h-16,800h→300s
  - Names: 13 corrections (1 typo, 9 Blizz renames, 3 Exile's Reach)
  - Title: 1 placeholder "T1"→NULL
  - Addon orphans: 865 dead creature_addon rows deleted
- **Phase 2 — npc_audit.py overhaul** (15 changes):
  - NULL string bug fixed (10,933 false title mismatches eliminated)
  - 10 hardcoded LIMITs removed (were silently truncating results)
  - Phase audit: cosmetic phase filter (11,613→2,713)
  - Missing spawns: massive rewrite with Wago xref + 5 exclusion sets (145,076→12,427, 91% reduction)
  - Equipment: priority tiers (HIGH=guards/soldiers, MEDIUM=default, LOW=mages)
  - Speed/loot: heuristic filters for triggers, vehicles, service NPCs
  - SQL escaping, auto-fix SQL generation for speed/spawntime/movement
  - write_report() made tolerant of different key patterns
- **Phase 3 — 5 new audit categories**: addon_orphans, quest_orphans, spells, scripts, mapzone
  - Total audits: 23→28
  - All wired into AUDIT_MAP and main() dispatch
- **False positive reduction**: 177,602→35,644 total issues (80% reduction)
- **Final state**: 21 of 28 audits clean, grand total ~23,904 DB fixes across all batches
- Committed `7d748b5`, pushed to wago-tooling

## Feb 27 2026 (session 6 — QA pass + batch 2 fixes)
- **Comprehensive QA of all audit results**: 6 parallel investigation agents analyzed every remaining category
- **Placeholder names despawned**: 399 entries (1,838 spawn rows) — all [DNT]/[DND]/[PH]/REUSE. None had real names in Wago (invisible triggers, FX stalkers, spawner controllers)
- **Spawned vendor flag cleanup**: 631 NPCs had VENDOR flag but no npc_vendor items → bit cleared
- **Unspawned vendor flag cleanup**: 511 more templates → bit cleared (DB hygiene). Total vendor fixes: 1,142
- **Name mismatch fixes**: 23 of 44 fixed — 18 broken spaces (CSV import corruption like "TrackerDragon Glyph"), 4 typos ("Dargul"→"Dargrul", "Jailor"→"Jailer"), 1 dev artifact ("Khadgar IGC"→"Khadgar"). 21 left as-is: 10 Exile's Reach version-specific, 10 Midnight beta renames, 1 unspawned
- **Wandering service NPCs**: 113 set stationary + 1 waypoint fix (Dren Nautilin had path but wrong MovementType). 4 intentional wanderers excluded (Thomas Yance, Benjamin Brode, Vashti, Gordo)
- **Gossip flag orphans**: 9 NPCs with GOSSIP flag but no gossip menu → flag cleared
- **npc_audit.py false positive fixes** (commit `5c96b03`, pushed to wago-tooling):
  - NULL string bug: `mysql_query()` converted `"NULL"` → `None` (was causing 10,933 false title mismatches)
  - Speed audit: exclude triggers + vehicles (9 → 2 remaining, both intentional)
  - Loot audit: exclude service NPCs + NOT_SELECTABLE (10,000 → 5,565)
  - SQL escaping: `\'` → `''`, hardcoded LIMITs removed, movement auto-fix SQL, equipment priority tiers
- **Final state**: 13 audits fully clean, total ~22,056 DB fixes across both batches

## Feb 27 2026 (session 5)
- **NPC Audit final commit**: Pushed `b37c2f4` — reaudit reports + parallel tab fix files (movement_service 43, name_fixes 50, names_mismatch 31, vendor_flag_unspawned 515, updated gossip/title reports)
- **Session summary**: 23-audit tool fully QA'd, 20,369 total fixes applied, 19 of 23 audits passing clean. Remaining 4 are informational (phases, missing, equipment, loot, display) needing Wowhead data or manual review

## Feb 27 2026 (session 4)
- **Packet & Log Pipeline overhaul**: Rewrote `start-worldserver.sh` with session archiving (timestamped PacketLog/ subdirs), WPP stale file cleanup (66 files/939MB in `out/`), WPP output relocation to PacketLog/, build validation warning (<90% parse), single-pass awk summary
- **New `wpp-add-build.sh`**: Adds WoW builds to WPP's 3 version switch statements. Contiguous-group algorithm finds correct function (not opcode dictionary). Validates enum exists in ClientVersionBuild.cs. Tested: 66192 (already-present skip), 99999 (correct insertion + expected build failure)
- **New `wpp-inspect.sh`**: Quick-grep utility with 6 commands (visible/transmog/trace/summary/opcodes/search). Slot-based VisibleItem filtering
- **QA fixes**: stray `0` on no-match (`|| true` + `${var:-0}`), `bc` replaced with `awk` (not available on Windows), `visible` filter redesigned to slot index, Player GUID format corrected (`Player/0 R1/S0 Map: N Low: N` not `Player-N-NNNN`), `-oP` → `-oE` for Windows locale, `.7z` added to archive glob
- 4 commits pushed to `VoxCore84/tc-packet-tools`

## Feb 27 2026 (session 3, continued)
- **NPC Audit expansion**: Added 15 new audit checks (display, names, scale, speed, equipment, gossip, waypoints, smartai, loot, auras, family, unitclass, title, spawntime, movement) — tool now has 23 total checks
- **Gossip flag fixes**: 1,541 NPCs had gossip menus but missing GOSSIP npcflag bit. Fixed `creature_gossip` → `creature_template_gossip` table reference
- **SmartAI orphan cleanup**: 5,550 NPCs had `AIName='SmartAI'` but no smart_scripts rows — cleared AIName
- **Creature family + unit_class fixes**: 67 family corrections, 7 unit_class fixes (invalid 0→1)
- **Waypoint orphan fixes**: 1,879 spawns with MovementType=2 but no path data — switched to random movement (wander_distance=10). 60 had dangling PathIds, 1,819 had no PathId at all
- **Waypoint audit rewrite**: Old audit checked `waypoint_path.PathId = guid` (wrong) — TC uses `creature_addon.PathId`. Fixed: 6,988 false positives eliminated
- **Comprehensive QA pass** — 18 bugs/improvements across all 23 audits:
  - Fixed: display column name, auras now checks creature_addon (+122), loot proper entry index, SmartAI checks guid-based scripts (restored 180 incorrectly cleared), names mismatches in reports with SQL
  - New detections: ScriptName='0' (8,617), AIName spaces (49), reverse gossip orphans (153)
  - Added SQL generation to speed/spawntime/movement audits
  - CSV caching (Creature.csv loaded once not 6x), faction prefers difficulty 0, equipment filter less noisy
- Committed `071f3dd` → `5ac3060`, pushed to wago-tooling

## Feb 27 2026 (session 3)
- **NPC Audit Tool** (`npc_audit.py`): Built comprehensive audit tool with 8 checks (levels, flags, faction, classification, type, duplicates, phases, missing). Cross-references world DB against Wago DB2 CSVs and Wowhead scraped data
- **Phase area fix**: 131 `phase_area` rows added — ~10K NPC spawns were permanently invisible due to 98 orphaned PhaseIds with no zone mapping. Key zones: DK Starting Zone, Kezan, Hyjal, Deepholm, Lost Isles, Sunwell, Westfall
- **Duplicate spawn removal**: 4,867 stacked spawns deleted. Phase-aware detection prevented false positives (4,409 intentional phased variants preserved)
- **Faction corrections**: 4,045 fixes across 11 categories from Wago CreatureDifficulty data. Hostile mobs made passive, Horde/Alliance NPCs set neutral, demons/undead made friendly, ambient NPCs misclassified
- **Classification + type fixes**: 1,225 + 574 corrections from Wago Creature CSV
- **Vendor/trainer flag fixes**: 16 + 142 NPCs with missing npcflag bits
- **Wowhead scraper**: Kicked off 224K NPC scrape (8 threads, ~18% at session end). Level audit pending on completion
- All committed to wago-tooling repo (`1b8ae5d`)

## Feb 27 2026 (session 2)
- **opcode_analyzer.py**: Built Python script (600+ lines) that parses TC Opcodes.h/cpp, cross-refs with WPP packet captures. Features: --filter, --json, --diff, --top N, --wpp-validate, ConnIdx tracking, lookup/dump modes. 3 commits pushed (`6ef3521` → `d8db7c5` → `81434ea` → `63ad95d`)
- **System consolidation**: Audited all TC/RP files across system. Deleted ~1.14 GB redundant data (old build 66066/66102 Wago CSVs, stale DBCViewer)
- **Housing opcode discovery**: 99 housing opcodes across 5 subsystems (Decor/Fixture/Room/Services/House), all STATUS_UNHANDLED — Midnight housing fully stubbed in protocol

## Feb 27 2026 (session 1)
- **Full 5-DB data quality audit**: 6 parallel agents, 148 checks across world/hotfixes/auth/characters/roleplay. Found 412K rows of dead data
- **Database cleanup**: 411,971 rows deleted + 40 RBAC inserts. Key: 388K orphan loot rows (63% of GO loot was dead), 17.5K duplicate spawns, 2.6K broken pool chains, 1.8K hotfix_data dupes, 928 SmartAI/script orphans, 413 event orphans. All custom RBAC permissions now assigned. SQL files in `sql/exports/cleanup_*.sql`
- **LW world DB bulk import**: 385K new rows across 17 tables via INSERT IGNORE. Quality-audited every table — filtered 63% orphans/junk. See [lorewalker-reference.md](lorewalker-reference.md) for full breakdown
- **ptBR locale export**: 28MB world + 23MB hotfixes SQL files, zipped for Discord sharing
- **Build 66192 update**: WPP locally patched (3 files), auth keys (`5a6a5ff2f5`), Wago CSVs, enrichment, hotfix repair (53K inserts, 283 fixes, 309K hotfix_data), scene scripts repair (+224 new, 36 encoding fixes). Updated all 7 skills, 6 wago scripts, memory. Data files updated (dbc/maps/vmaps/mmaps/buildings/cameras/gt)
- **66192 verification suite**: enrichment (5 CSVs OK), missing spawns xref (44 creatures, 25K GOs — unchanged), audit coverage (400/512 hotfix tables matched, 0 gaps), build diff (125 tables: -73K SpellEffect, -40K ItemSparse, +28K SoundKitAdvanced, +43 Spell), table_hashes.py regen (1121 unchanged), server logs (249K DBErrors all known categories, no new 66192 errors, clean startup)
- **Memory reorganization**: MEMORY.md 198→90 lines. Created 7 new topic files (sql-lessons, server-config, build-environment, hotfix-repair, recent-work, lorewalker-reference, skills-and-automation). Total 13 topic files
- **Transmog multi-group fix** (`ec4ba25ba9`): multi-group parsing and missing slot fallback

## TODO — Future Audit Passes
- **C++ ScriptName bindings**: verify spell_script_names entries match compiled script classes
- **DBC/DB2 spell/item existence**: cross-ref creature_template_spell, smart_scripts cast actions, loot items against Wago CSVs
- **Map coordinates validity**: validate spawn positions against map boundary data
- **Client-side rendering data**: model_file_data, texture_file_data coverage audit

## Feb 26 2026
- **Companion AI assist fix** (`ad830fc8ee`): companion assist target uses owner combat state instead of faction checks
- **Transmog wireDT fix** (`485d3b10ed`): server-side DB2 lookup for transmog outfit slot routing. Added `GetServerDisplayType()` using `sItemModifiedAppearanceStore`+`sItemAppearanceStore`
- **Hotfix repair v1** (build 66102): Initial 5-batch run — 196K fixes, 319K inserts, 195K hotfix_data (~33.6 MB SQL)

## Earlier Feb 2026
- **Consecration auto-attack fix** (`3026810524`): `TRIGGERED_CAST_DIRECTLY` skips channel slot registration for spell 81297 (Consecration Damage). File: `spell_paladin.cpp:449`
- **Melee range issue — NEEDS TESTING**: first-swing `NotInRange` errors, possibly CombatReach=0 or same-tick race. Calc at `Unit::IsWithinMeleeRangeAt` (Unit.cpp:697)
- **Vendor IgnoreFiltering fix** (`60801f03f7`): server-side class/faction checks now respect `IgnoreFiltering`. All 164K vendor items set to `IgnoreFiltering=1`
- **Transmog outfit system**: fully implemented for 12.x — secondary shoulder persistence, slot mapping (1-15), missing slots investigation (HEAD/MH/OH). See [transmog-implementation.md](transmog-implementation.md)
- **Transmog outfit fixes via Codex CLI**: 4 tasks — shared TRANSMOG_SECONDARY_SHOULDER_SLOT sentinel, SecondaryShoulderApparanceID validation, SPEC_5 modifiers in ResetItem, slot data parsing in CMSG_TRANSMOG_OUTFIT_NEW
- Completed: DB error triage (6 workflows), performance audit, Codex setup, CI fixes, codex branch cleanup
- Completed: LoreWalkerTDB imports (hotfixes + SmartAI 22K rows + world cleanup 381K orphans), spell hotfixes (82238, 1258081), all `sql/RoleplayCore/` applied
- ArtifactAppearance ItemAppearanceModifierID — must be `uint8`/`FT_BYTE` (client DB2 meta confirms 'b'). Reverted in `e3fe617c6d`
- Spell script updates for Midnight 12.0.1 DBC changes

# RoleplayCore To-Do List

## Completed (archive)
- Expanded DraconicBot FAQ trigger phrases (1500+ text variations) + regex robustification (`688bef7b1b`)
- Auth key bypass reverted (`8bbd610fc7`), 66220 keys applied
- Hotfix redundancy audit: 10.8M → ~244K content rows, 226,984 hotfix_data entries (3 rounds + orphan sweep)
- DBCD binary cross-ref audit: 363 redundant rows removed (13 tables), 393 missing broadcast_text filled. Commit `faec6435de`
- ContentTuning enrichment: 4,820 spawned CT=0 creatures → zone/neighbor lookup (`_04` SQL)
- Stormwind CTD rows (11), server-wide CTD rows (26,745), SmartAI orphans (5,894+181 GUID fix)
- Stormwind SmartAI orphans (2), stacked bunny, AIName spaces, flatten C:\Tools dirs
- Raidbots pipeline current for 66263, spell refs non-issue, gist report deleted
- QA: 11 HealthModifier=0 fixed, 30,130 orphaned waypoint nodes removed, 51 orphaned loot refs cleared

## HIGH

### Background Database Auditor Script (Antigravity)
- **Phase 0 Complete**: Python `venv` set up, `scripts/AI_Auditor.py` scaffolded, `.agentrules` synced.
- **Pending**: Write the DB connection logic using `mysql-connector-python` and cross-reference Wago's `Creature-enUS.csv` against `creature_template` in the local MySQL world DB.

### VoxCore Website — "Arcane Codex" Visual Overhaul
- ~~**Phase 1**: Arcane visual refresh~~ DONE — dark-only theme, particles, glow hovers, gold milestones
- ~~**Phase 2**: Animated pipeline + reduction funnel~~ DONE — SVG scroll animation, funnel chart
- ~~**Phase 3**: Tool explorer~~ DONE — 54 tools, 9 chips, search, language badges
- ~~**Also**: Scroll progress bar, nav glow, linked footer badges~~ DONE
- ~~**Phase 5**: Interactive timeline~~ DONE — expandable cards, color-coded categories
- ~~**Search/Command Palette**~~ DONE — nav search bar + Ctrl+K + `/` shortcut
- ~~**Progress Rings**~~ DONE — 5 animated SVG gauges on Status page
- ~~**15 interactive features**~~ DONE — 3D tilt, cursor trail, copy buttons, page transitions, typewriter, aurora, etc.
- **Phase 0**: Asset pipeline — extract WoW visuals via wow-export (config + checklist ready)
- **Phase 4**: Before/After slider — draggable comparison on Results page
- Full plan: [website-vision.md](website-vision.md)

### ~~World DB QA Fixes (5 SQL files)~~ DONE
- `_00`: 26,745 missing DifficultyID=0 rows. `_01`: 5,894 SmartAI orphans cleared. `_02`: 181 GUID-based restored
- `_03`: 3 AIName typos + 8 orphaned GUID scripts. `_04`: 4,820 CT=0 creatures enriched
- Commits `f0782d5030`, `9536a248b6`, `21fa23b0d1` — pushed

### ~~Transmog: 5-Agent Audit Action Plan (sessions 62-63)~~ ALL PHASES DONE
- Phases 1-4 implemented (26/26 items). Commits: `20c9a0ea23`, `1dfc2eb207`, `c8df50eddd`, `ab43e4823d`
- Phase 5 (retail capture): DEFERRED — missing opcodes for create/rename/delete/single-item/situations
- [full details](transmog-audit-actions.md)

### Transmog: In-Game Testing Required
- ~~Bug A~~: Paperdoll naked on 2nd UI open — fix deployed (Phase 4 hardening)
- ~~Bug B~~: Old head/shoulder persists — fix deployed (session 59)
- ~~Bug C~~: Monster Mantle ghost appearance — fix deployed (Phase 4 per-slot validation)
- ~~Bug D~~: Draenei leg geometry loss — fix deployed (Phase 4 IgnoreMask restore)
- ~~Bug E~~: Single-item transmog drift — fix deployed (session 59)
- **All fixes deployed, awaiting in-game verification**

### Transmog: Unverified Features
- MH enchant illusions (4-field payload) — deployed, never verified in-game
- Clear single slot (transmogID=0) — deployed, never verified in-game

### ~~ContentTuningID=0 Enrichment~~ DONE
- 4,820 of 4,918 spawned CT=0 creatures enriched (98%) via `enrich_content_tuning.py`
- Pass 1: 3,877 via AreaTable lookup, Pass 2: 943 via neighbor interpolation
- 98 unresolved (sparse instanced maps), 36,913 non-spawned CT=0 remaining (harmless)
- Applied in `2026_03_05_04_world.sql`

### ~~Missing Spawn Coordinate Transformer~~ DONE
- `coord_transformer.py` deployed. Critical tier: 1,541 quest NPC spawns applied (`_06`)
- 214 phase-duplicate entries resolved: 207 re-inserted (`_11`), 7 REMOVED skipped
- 107 Z=0 excluded, 479 no Wowhead coords — total ~1,748 new spawns
- Spot-checked in-game: ~3 yard accuracy. Commits `68e154e68c`, `fcf1cf2738`, `1d53f2a1d3`

### ~~ATT (AllTheThings) Data Import~~ DONE
- `att_parser.py` + `att_generate_sql.py` in wago-tooling repo (`81cf71a`)
- Applied: 4,630 quest starters, 3,081 quest chains, 1,510 vendor items
- creature_queststarter: 26,116 -> 30,746. quest chains: 21,787 -> 24,868. npc_vendor: 165,802 -> 167,312
- Commit `04c0d4652c` (audit trail). `_11` SQL file is phase spawns, ATT applied directly

### ~~ATT Mega-Parser (SQLite)~~ DONE
- `att_to_sqlite.py` → `att_data.db`: 60 tables, 30 loaders, 52.6 MB, 27s
- 174K items, 47K quests, 22K objects, 58K transmog set items, 136K item filters, 76K missing transmog
- 5.6K profession recipes, 690 glyphs, 261 runeforge powers, 286 conduits, 99K item sources
- Commit `b1f0bd0` (wago-tooling). Ready for cross-reference against MySQL world DB

## MEDIUM

### Stormwind: Trainer Orphans (7 entries) — SKIPPED (retail-accurate)
- 7 NPCs with TRAINER flag but no `creature_trainer` entry — decorative, matches retail

### Stormwind: Class Trainers (15 entries, design decision)
- `npcflag & 16` but no `trainer_spell` data — Cataclysm stripped training
- Options: (a) strip flag, (b) link existing trainers, (c) leave as-is

### Skyriding / Dragonriding
- `spell_dragonriding.cpp:39`: TODO outside dragon isles
- `Player.cpp:19509`: forces old flight mode instead of proper skyriding

### HandleTransmogrifyItems Handler — Not Dead (Phase 4 sync code)
- Client never sends `CMSG_TRANSMOGRIFY_ITEMS` in 12.x, BUT Phase 4 added bidirectional sync
- Contains Appearances[] sync, IgnoreMask sync, enchant sync, SetEquipmentSet persistence
- Could be invoked by future server-side transmog operations. LOW priority cleanup

### DB2Query Tool Enhancements
- DB2Query at `C:\Users\atayl\VoxCore\ExtTools\DB2Query\` — working CLI, used for DBCD audit
- Could add: batch ID lookup from file, direct SQL INSERT generation, hotfix_data auto-registration
- Potential: periodic re-audit when Wago updates (fills TWW-era broadcast_text gaps)

### Melee First-Swing NotInRange Bug
- CombatReach=0 or same-tick race at `Unit::IsWithinMeleeRangeAt` (Unit.cpp:697)

### RolePlay.cpp Unverified TODOs
- Line 339: `// TODO: Check if this works`
- Line 397: `// TODO: This should already happen in DeleteFromDB, check this.`

## LOW

### Stormwind: Quest-Giver Flag Cleanup (84 NPCs)
- QUESTGIVER flag but no quest associations — cosmetic, mostly matches retail

### Transmog: Unicode Outfit Names
- Backward ASCII scan breaks on non-ASCII — low priority

### Transmog: Outfit Delete Verification
- Assumed via `CMSG_DELETE_EQUIPMENT_SET` — unverified

### Transmog: Secondary Shoulder via Outfit Loading
- 13/14 slots work, secondary shoulder known gap — PR #760

### Transmog: SecondaryWeaponAppearanceID (Legion Artifacts)
- Not persisted — niche feature

### Orphan Spell 1251299
- Removed between builds but persists in hotfixes.spell_name — harmless

### Companion Squad Improvements
- More variety (only 5 seed), damage scaling, visual customization, kiting AI

### ~~Midnight Expansion Data~~ IMPORTED
- 38 guide pages + 586 entity pages scraped (44 MB). 1,463 rows applied to world DB
- 58 quest starters, 60 quest enders, 819 loot entries, 526 boss abilities
- SQL: `_15`. Commits: wago `966e0eb`, RC `d81962a4d6`

### Midnight Vendor Items (337 new, blocked on ExtendedCost)
- 17 NPCs with zero npc_vendor entries, 337 items ready
- Blocked: scrape doesn't include ExtendedCost data (items would be free without it)
- Need: cross-ref NpcVendor DB2 or ItemExtendedCost DB2 for currency costs
- Data: `C:/Users/atayl/VoxCore/wago/midnight_data/midnight_vendor_items.json`

## DEFERRED / BLOCKED

### ~~Wowhead 403 Block~~ RESOLVED
- 403 expired on its own (confirmed Mar 4 2026)
- Scraper upgraded: `curl_cffi` Chrome131 TLS fingerprint (prevents re-ban)
- See quest reward scrape below

### ~~Missing Spawns Critical Tier~~ DONE
- 1,541 quest NPC spawns + 207 phase-aware re-inserts = ~1,748 total
- 107 Z=0 excluded, 214 phase-duplicates resolved (7 REMOVED skipped)
- Quest NPCs still missing: 479 (no Wowhead coords or no zone bounds)
- Commits `68e154e68c`, `fcf1cf2738`, `1d53f2a1d3`

### ~~Missing Spawns High Tier~~ DONE
- 1,492 service NPC spawns generated + 1,483 ContentTuningID assignments
- 144 Z=0 excluded, 1,360 no Wowhead coords. GUID range 3000217122-3000218613
- SQL: `2026_03_05_17_world.sql`. Commit `25031c1eda`

### ~~Wowhead Gap Scrape (5 data gaps)~~ DONE (gossip reverted)
- `scrape_gaps_tor.py`: 30-worker Tor scraper, 5,653 pages in ~8 min (45K/hr, 0 WAF)
- **Quest starters**: 592 creature + 202 GO new rows applied
- **Quest enders**: 683 creature + 208 GO new rows applied
- **Vendor items**: 8,799 new rows from 404 NPCs applied
- **Gossip text**: REVERTED — scraper picked up Wowhead user comments, not NPC dialogue
- 37+36 orphaned GO quest entries cleaned (TWW Candy Buckets, no gameobject_template)
- SQL: `2026_03_05_14_world.sql`. Wago `9feb173`, RoleplayCore `de2d81f550`
- Remaining gaps: 16,630 quests no starter, 13,311 no ender, 420 gossip NPCs (after all scrapes)

### ~~BtWQuests Addon Import~~ DONE
- `parse_btwquests.py` parsed 16 BtWQuests addon directories
- 16,818 quests parsed, 1,062 new creature_queststarter + 57 new gameobject_queststarter
- 2,329 quest chains with 14,670 connections extracted to `btwquests_chains.json`
- Quest chains applied: 572 PrevQuestID + 2,008 NextQuestID updates (`_19`). Commit `6eaeeef6a5`
- SQL: `_16` (starters), `_19` (chains). Commits `0e0030c8f7`, `6eaeeef6a5`

### ~~Service Gaps (997 vendors/trainers)~~ RESOLVED
- Round 1: 404 of 687 flagged vendor NPCs filled from gap scrape (8,799 items)
- Round 2: 772 empty vendor NPCs scraped, 82 had data -> 1,435 new npc_vendor entries
- Round 3: NPC mega-scrape added 2,535 more vendor items
- 680 of 772 NPCs have no Wowhead vendor data (decorative/stub)
- SQL: `_14` (R1), `_18` (R2), `_22` (R3). Commits `9340906e9d`, `444d0de160`

### ~~NPC Mega-Scrape (80,944 NPCs)~~ DONE
- `wowhead_scraper_v2.py`: 120-worker Tor scraper, 80,943 NPC pages in ~20 min (~250K/hr)
- **Quest starters**: 1,727 new creature_queststarter rows
- **Quest enders**: 2,979 new creature_questender rows
- **Vendor items**: 2,535 new npc_vendor rows
- **Loot drops**: 402,446 extracted (report only — need reference_loot_template mapping)
- **Trainer spells**: 32,573 extracted (report only)
- SQL: `_22`. Commit `444d0de160`
- Remaining gaps: 16,630 quests no starter, 13,311 no ender

### ~~ATT Cross-Reference Import~~ DONE (2 rounds)
- Round 1: 170 creature QS, 124 GO QS, 176 quest chains. SQL `_21`, commit `b14957546a`
- Round 2: 252 vendor items (flag+ItemSparse validated), 426 ExclusiveGroup (170 groups). SQL `_24`, commit `6be6f4682b`

### ~~BtWQuests ContentTuningID Enrichment~~ DONE
- 228 quests filled from BtWQuests addon data (validated against DB2 ContentTuning)
- Reputation rewards: 0 gaps (all 6,668 already covered in quest_template)
- SQL: `_24`. Commit `6be6f4682b`

### LoreWalker TDB Delta (NEEDS QA — user burned twice before)
- LW loaded in MySQL as `lorewalker`. Same TDB base (22111), compatible schema
- **Available**: 500K SmartAI, 248K loot, 38K spawns, 30K waypoints, 20K vendor EC fills, 8K quest POI
- **Blocked**: User requires 100% dedup verification before any mass import
- `lw_diff_pipeline.py` built (dry run verified), NOT applied
- Key risk: 172K creature_loot_template rows with same PK but different values (need merge policy)
- 4 schema diffs (our extra columns): creature.size, gameobject.size/visibility, npc_vendor.OverrideGoldCost

### ~~WPP Sniff Import + Enrichment~~ DONE
- `parse_sniff.py` parses 8M-line WPP dump (build 66263): 776 creatures, 725 GOs, 868 templates
- Imported: 152 creature spawns, 9 equipment templates, 21 GO spawns → `_25` (`9962076dbf`)
- Enrichment: 161 updates (type/family/Classification/unit_class/HP/Mana/equip/portals) → `_26` (`c5cb54ec54`)
- Stormwind Wowhead scrape: 5 SmartAI cleanups → `_27` (`c7bada7e1d`)
- Hero's Call Board dedup: old GO 206111 removed (duplicated newer 281339) → `_28` (`9e53777d55`)
- Transmog: hidden appearance + paired weapon DT=4 → `8d36580ac4`

### Stormwind NPC Scripting (NEW)
- 2,327 spawned creatures, 1,046 already have SmartAI
- Need ambient scripts: guards patrolling, vendors emoting, children playing, workers animating
- Hero's Call Board: retail uses custom expansion-choice UI, not raw quest list — needs investigation

### Equipment Gaps (~13,001 NPCs)
- Cross-reference LoreWalkerTDB `creature_equip_template` — not yet attempted
- DB2 NPCModelItemSlotDisplayInfo has 365K rows (10x coverage vs our 39K creature_equip_template)

### ~~Quest Reward Text Scrape (27,328 quests)~~ DONE
- 30-worker Tor scraper (`scrape_via_tor.py`) completed 21,533 pages in 35 min (37K/hr)
- Imported: 13,494 `quest_offer_reward` + 6,792 `quest_request_items` rows
- AzerothCore supplemental: 193 WotLK-era rows
- Cleanup: 11 empty reward rows, 1,536 empty request rows, 2 unconverted `<name>` tags
- Final totals: 33,607 offer_reward, 17,266 request_items. 14,278 quests still missing (mostly modern expansion quests with no Wowhead text)
- SQL: `2026_03_05_13_world.sql` (cleanup). Wago commit `df46cff`

### Hotfix Repair Persistent Issues
- `mail_template` 110 rows truncated, `spell` 102 rows, ~20K schema mismatches
- `model_file_data`/`texture_file_data` massive gaps (client-only)

### ~~Build 66263 Auth Keys~~ DONE
- TC published keys 2026-03-05. User applied SQL. Bypass reverted in WorldSocket.cpp
- Data pipeline bumped to 66263 (wago_common.py, CSVs, TACT, merge). WPP nightly downloaded
- Still need: hotfix repair re-run

### Auth Key Self-Service Extraction
- x64dbg + WoWDumpFix or Frida — documented in `auth-key-notes.md`

## Code Quality (session 24 audit)
- `.gitignore` for build artifacts
- Cross-faction `AllowTwoSide.*` audit, `MinPetitionSigns=0` verify
- Dead code: Hoff class, RotationAxis enum, marker system
- Non-idempotent setup SQL in `sql/RoleplayCore/`
- RelWithDebInfo `/Ob2` + LTO investigation

## Future Audit Passes
- C++ ScriptName bindings vs compiled script classes
- ~~DBC/DB2 spell/item existence cross-ref~~ DONE (DBCD audit: all clean, broadcast_text filled)
- Map coordinates validity
- Client-side rendering data coverage
- 16 remaining missing broadcast_text: 9 TWW-era (awaiting Wago update) + 7 custom 912M (need manual creation)
### ~~ATT (AllTheThings) Data Import~~ DONE
- `att_parser.py` + `att_generate_sql.py` in wago-tooling repo (`81cf71a`)
- Applied: 4,630 quest starters, 3,081 quest chains, 1,510 vendor items
- creature_queststarter: 26,116 -> 30,746. quest chains: 21,787 -> 24,868. npc_vendor: 165,802 -> 167,312
- Commit `04c0d4652c` (audit trail). `_11` SQL file is phase spawns, ATT applied directly

### ~~ATT Mega-Parser (SQLite)~~ DONE
- `att_to_sqlite.py` → `att_data.db`: 60 tables, 30 loaders, 52.6 MB, 27s
- 174K items, 47K quests, 22K objects, 58K transmog set items, 136K item filters, 76K missing transmog
- 5.6K profession recipes, 690 glyphs, 261 runeforge powers, 286 conduits, 99K item sources
- Commit `b1f0bd0` (wago-tooling). Ready for cross-reference against MySQL world DB

## MEDIUM

### Stormwind: Trainer Orphans (7 entries) — SKIPPED (retail-accurate)
- 7 NPCs with TRAINER flag but no `creature_trainer` entry — decorative, matches retail

### Stormwind: Class Trainers (15 entries, design decision)
- `npcflag & 16` but no `trainer_spell` data — Cataclysm stripped training
- Options: (a) strip flag, (b) link existing trainers, (c) leave as-is

### Skyriding / Dragonriding
- `spell_dragonriding.cpp:39`: TODO outside dragon isles
- `Player.cpp:19509`: forces old flight mode instead of proper skyriding

### HandleTransmogrifyItems Handler — Not Dead (Phase 4 sync code)
- Client never sends `CMSG_TRANSMOGRIFY_ITEMS` in 12.x, BUT Phase 4 added bidirectional sync
- Contains Appearances[] sync, IgnoreMask sync, enchant sync, SetEquipmentSet persistence
- Could be invoked by future server-side transmog operations. LOW priority cleanup

### DB2Query Tool Enhancements
- DB2Query at `C:\Users\atayl\VoxCore\ExtTools\DB2Query\` — working CLI, used for DBCD audit
- Could add: batch ID lookup from file, direct SQL INSERT generation, hotfix_data auto-registration
- Potential: periodic re-audit when Wago updates (fills TWW-era broadcast_text gaps)

### Melee First-Swing NotInRange Bug
- CombatReach=0 or same-tick race at `Unit::IsWithinMeleeRangeAt` (Unit.cpp:697)

### RolePlay.cpp Unverified TODOs
- Line 339: `// TODO: Check if this works`
- Line 397: `// TODO: This should already happen in DeleteFromDB, check this.`

## LOW

### ~~Command Center UI: Blank Duration Bug~~ FIXED
- The duration field renders as blank (e.g., "s" instead of "1s") in `run_detail.html` if the job executes too fast or duration isn't cleanly parsed from the manifest. Keep it non-blocking and queue for cleanup.

### Stormwind: Quest-Giver Flag Cleanup (84 NPCs)
- QUESTGIVER flag but no quest associations — cosmetic, mostly matches retail

### Transmog: Unicode Outfit Names
- Backward ASCII scan breaks on non-ASCII — low priority

### Transmog: Outfit Delete Verification
- Assumed via `CMSG_DELETE_EQUIPMENT_SET` — unverified

### Transmog: Secondary Shoulder via Outfit Loading
- 13/14 slots work, secondary shoulder known gap — PR #760

### Transmog: SecondaryWeaponAppearanceID (Legion Artifacts)
- Not persisted — niche feature

### Orphan Spell 1251299
- Removed between builds but persists in hotfixes.spell_name — harmless

### Companion Squad Improvements
- More variety (only 5 seed), damage scaling, visual customization, kiting AI

### ~~Midnight Expansion Data~~ IMPORTED
- 38 guide pages + 586 entity pages scraped (44 MB). 1,463 rows applied to world DB
- 58 quest starters, 60 quest enders, 819 loot entries, 526 boss abilities
- SQL: `_15`. Commits: wago `966e0eb`, RC `d81962a4d6`

### Midnight Vendor Items (337 new, blocked on ExtendedCost)
- 17 NPCs with zero npc_vendor entries, 337 items ready
- Blocked: scrape doesn't include ExtendedCost data (items would be free without it)
- Need: cross-ref NpcVendor DB2 or ItemExtendedCost DB2 for currency costs
- Data: `C:/Users/atayl/VoxCore/wago/midnight_data/midnight_vendor_items.json`

## DEFERRED / BLOCKED

### ~~Wowhead 403 Block~~ RESOLVED
- 403 expired on its own (confirmed Mar 4 2026)
- Scraper upgraded: `curl_cffi` Chrome131 TLS fingerprint (prevents re-ban)
- See quest reward scrape below

### ~~Missing Spawns Critical Tier~~ DONE
- 1,541 quest NPC spawns + 207 phase-aware re-inserts = ~1,748 total
- 107 Z=0 excluded, 214 phase-duplicates resolved (7 REMOVED skipped)
- Quest NPCs still missing: 479 (no Wowhead coords or no zone bounds)
- Commits `68e154e68c`, `fcf1cf2738`, `1d53f2a1d3`

### ~~Missing Spawns High Tier~~ DONE
- 1,492 service NPC spawns generated + 1,483 ContentTuningID assignments
- 144 Z=0 excluded, 1,360 no Wowhead coords. GUID range 3000217122-3000218613
- SQL: `2026_03_05_17_world.sql`. Commit `25031c1eda`

### ~~Wowhead Gap Scrape (5 data gaps)~~ DONE (gossip reverted)
- `scrape_gaps_tor.py`: 30-worker Tor scraper, 5,653 pages in ~8 min (45K/hr, 0 WAF)
- **Quest starters**: 592 creature + 202 GO new rows applied
- **Quest enders**: 683 creature + 208 GO new rows applied
- **Vendor items**: 8,799 new rows from 404 NPCs applied
- **Gossip text**: REVERTED — scraper picked up Wowhead user comments, not NPC dialogue
- 37+36 orphaned GO quest entries cleaned (TWW Candy Buckets, no gameobject_template)
- SQL: `2026_03_05_14_world.sql`. Wago `9feb173`, RoleplayCore `de2d81f550`
- Remaining gaps: 16,630 quests no starter, 13,311 no ender, 420 gossip NPCs (after all scrapes)

### ~~BtWQuests Addon Import~~ DONE
- `parse_btwquests.py` parsed 16 BtWQuests addon directories
- 16,818 quests parsed, 1,062 new creature_queststarter + 57 new gameobject_queststarter
- 2,329 quest chains with 14,670 connections extracted to `btwquests_chains.json`
- Quest chains applied: 572 PrevQuestID + 2,008 NextQuestID updates (`_19`). Commit `6eaeeef6a5`
- SQL: `_16` (starters), `_19` (chains). Commits `0e0030c8f7`, `6eaeeef6a5`

### ~~Service Gaps (997 vendors/trainers)~~ RESOLVED
- Round 1: 404 of 687 flagged vendor NPCs filled from gap scrape (8,799 items)
- Round 2: 772 empty vendor NPCs scraped, 82 had data -> 1,435 new npc_vendor entries
- Round 3: NPC mega-scrape added 2,535 more vendor items
- 680 of 772 NPCs have no Wowhead vendor data (decorative/stub)
- SQL: `_14` (R1), `_18` (R2), `_22` (R3). Commits `9340906e9d`, `444d0de160`

### ~~NPC Mega-Scrape (80,944 NPCs)~~ DONE
- `wowhead_scraper_v2.py`: 120-worker Tor scraper, 80,943 NPC pages in ~20 min (~250K/hr)
- **Quest starters**: 1,727 new creature_queststarter rows
- **Quest enders**: 2,979 new creature_questender rows
- **Vendor items**: 2,535 new npc_vendor rows
- **Loot drops**: 402,446 extracted (report only — need reference_loot_template mapping)
- **Trainer spells**: 32,573 extracted (report only)
- SQL: `_22`. Commit `444d0de160`
- Remaining gaps: 16,630 quests no starter, 13,311 no ender

### ~~ATT Cross-Reference Import~~ DONE (2 rounds)
- Round 1: 170 creature QS, 124 GO QS, 176 quest chains. SQL `_21`, commit `b14957546a`
- Round 2: 252 vendor items (flag+ItemSparse validated), 426 ExclusiveGroup (170 groups). SQL `_24`, commit `6be6f4682b`

### ~~BtWQuests ContentTuningID Enrichment~~ DONE
- 228 quests filled from BtWQuests addon data (validated against DB2 ContentTuning)
- Reputation rewards: 0 gaps (all 6,668 already covered in quest_template)
- SQL: `_24`. Commit `6be6f4682b`

### LoreWalker TDB Delta (NEEDS QA — user burned twice before)
- LW loaded in MySQL as `lorewalker`. Same TDB base (22111), compatible schema
- **Available**: 500K SmartAI, 248K loot, 38K spawns, 30K waypoints, 20K vendor EC fills, 8K quest POI
- **Blocked**: User requires 100% dedup verification before any mass import
- `lw_diff_pipeline.py` built (dry run verified), NOT applied
- Key risk: 172K creature_loot_template rows with same PK but different values (need merge policy)
- 4 schema diffs (our extra columns): creature.size, gameobject.size/visibility, npc_vendor.OverrideGoldCost

### ~~WPP Sniff Import + Enrichment~~ DONE
- `parse_sniff.py` parses 8M-line WPP dump (build 66263): 776 creatures, 725 GOs, 868 templates
- Imported: 152 creature spawns, 9 equipment templates, 21 GO spawns → `_25` (`9962076dbf`)
- Enrichment: 161 updates (type/family/Classification/unit_class/HP/Mana/equip/portals) → `_26` (`c5cb54ec54`)
- Stormwind Wowhead scrape: 5 SmartAI cleanups → `_27` (`c7bada7e1d`)
- Hero's Call Board dedup: old GO 206111 removed (duplicated newer 281339) → `_28` (`9e53777d55`)
- Transmog: hidden appearance + paired weapon DT=4 → `8d36580ac4`

### Stormwind NPC Scripting (NEW)
- 2,327 spawned creatures, 1,046 already have SmartAI
- Need ambient scripts: guards patrolling, vendors emoting, children playing, workers animating
- Hero's Call Board: retail uses custom expansion-choice UI, not raw quest list — needs investigation

### Equipment Gaps (~13,001 NPCs)
- Cross-reference LoreWalkerTDB `creature_equip_template` — not yet attempted
- DB2 NPCModelItemSlotDisplayInfo has 365K rows (10x coverage vs our 39K creature_equip_template)

### ~~Quest Reward Text Scrape (27,328 quests)~~ DONE
- 30-worker Tor scraper (`scrape_via_tor.py`) completed 21,533 pages in 35 min (37K/hr)
- Imported: 13,494 `quest_offer_reward` + 6,792 `quest_request_items` rows
- AzerothCore supplemental: 193 WotLK-era rows
- Cleanup: 11 empty reward rows, 1,536 empty request rows, 2 unconverted `<name>` tags
- Final totals: 33,607 offer_reward, 17,266 request_items. 14,278 quests still missing (mostly modern expansion quests with no Wowhead text)
- SQL: `2026_03_05_13_world.sql` (cleanup). Wago commit `df46cff`

### Hotfix Repair Persistent Issues
- `mail_template` 110 rows truncated, `spell` 102 rows, ~20K schema mismatches
- `model_file_data`/`texture_file_data` massive gaps (client-only)

### ~~Build 66263 Auth Keys~~ DONE
- TC published keys 2026-03-05. User applied SQL. Bypass reverted in WorldSocket.cpp
- Data pipeline bumped to 66263 (wago_common.py, CSVs, TACT, merge). WPP nightly downloaded
- Still need: hotfix repair re-run

### Auth Key Self-Service Extraction
- x64dbg + WoWDumpFix or Frida — documented in `auth-key-notes.md`

## Code Quality (session 24 audit)
- `.gitignore` for build artifacts
- Cross-faction `AllowTwoSide.*` audit, `MinPetitionSigns=0` verify
- Dead code: Hoff class, RotationAxis enum, marker system
- Non-idempotent setup SQL in `sql/RoleplayCore/`
- RelWithDebInfo `/Ob2` + LTO investigation

## Future Audit Passes
- C++ ScriptName bindings vs compiled script classes
- ~~DBC/DB2 spell/item existence cross-ref~~ DONE (DBCD audit: all clean, broadcast_text filled)
- Map coordinates validity
- Client-side rendering data coverage
- 16 remaining missing broadcast_text: 9 TWW-era (awaiting Wago update) + 7 custom 912M (need manual creation)
- 2 orphan `hotfixes.item` entries (IDs 242643, 257928) — no matching item_sparse, cosmetic

## Next Session Immediate Goals
1. Proceed with testing the completed Triad Pipeline (Command Center -> Orchestrator -> Claude Code).
2. Continue the "Arcane Codex" VoxCore Website visual overhaul (Phase 0 and Phase 4).
3. Consolidate and close out lingering Transmog Bug Fixes from Tier 2 (BUG-M3, M7, M8, M10).
4. Initiate a fresh world database check-in to process the remaining 9 zone phase_area diffs (Tier 3).
5. Deploy and execute in-game testing for the completed DraconicBot NLP parser and newly expanded FAQ regex patterns.

# VoxCore -- Open Issues & Roadmap

Prioritized list of known issues, planned work, and blocked items. Updated as items are resolved.

---

## HIGH Priority

### VoxCore Website â€” "Arcane Codex" Asset Pipeline (NEW)
- **Phase 0**: Extract WoW visuals via wow-export for website
  - 83 assets curated: 30 dungeon journal art, 21 boss portraits, 32 creature models (SL/DF/TWW/Midnight)
  - wow-export auto-configured (WebP, GLB, no bloat). Scripts at `~/VoxCore/ExtTools/website-assets\`
  - Priority: Enchanted Tome (mascot), Xal'atath, Alleria, Khadgar, Midnight raid journal art
- **Phases 1â€“5**: Arcane visual refresh, animated pipeline, tool explorer, before/after slider, interactive timeline

### Transmog: 5-Agent Audit Action Plan (sessions 62–73)
**Status**: Phases 1–4 IMPLEMENTED + corrective pass (session 73). Behavioral model aligned to retail packets. Awaiting in-game testing.
- ~~**Phase 1** (server bugs)~~: **DONE** (commit `20c9a0ea23`) — per-spec appearance bootstrap, HandleTransmogOutfitNew active ID, Finalize flush, clear spell active ID reset
- ~~**Phase 2** (Bridge cleanup)~~: **DONE** (commit `20c9a0ea23`) — diagnostic probe removed, multi-part split bail-out, dead code removed, deterministic slot ordering
- ~~**Phase 3** (TransmogSpy v2)~~: **DONE** (commit `1dfc2eb207`) — 944→1,317 lines, 17 commands, 12 new events, displayType capture, IMA name resolution, 6 new hooks
- ~~**Phase 4** (hardening)~~: **DONE** (commit `c8df50eddd`) — IgnoreMask baseline restore, stale partial cleanup, spec-switch resync, per-slot validation
- **Phase 4 bonus** (commit `ab43e4823d`): EffectEquipTransmogOutfit was missing ViewedOutfit sync — last outfit-apply path fixed. Situations parser consistency
- **Phase 5** (retail capture): outfit create/rename/delete, single-item transmog, situations — DEFERRED

### Transmog: 5-Bug Investigation (sessions 36–63)
**Status**: All 5 bugs addressed. All fixes deployed, awaiting in-game testing.
- ~~**Bug A**: Paperdoll naked on 2nd UI open~~ — **FIXED** (session 63): Phase 4 hardening (per-slot validation, baseline restore, spec resync) + EffectEquipTransmogOutfit ViewedOutfit sync (commits `c8df50eddd`, `ab43e4823d`)
- ~~**Bug B**: Old head/shoulder persists when outfit doesn’t define them~~ — **FIXED** (session 59, commit `289677be44`): Added `_activeTransmogOutfitID` tracking; ViewedOutfit now renders the actually-applied outfit instead of always the lowest SetID
- ~~**Bug C**: Monster Mantle ghost appearance (item 182306)~~ — **FIXED** (session 63): Phase 4 per-slot validation zeroes invalid/uncollected appearances instead of rejecting entire outfit (commit `c8df50eddd`)
- ~~**Bug D**: Draenei lower leg geometry loss~~ — **FIXED** (session 63): Phase 4 IgnoreMask baseline restore + per-slot validation prevents mismatched state (commit `c8df50eddd`)
- ~~**Bug E** (root cause confirmed): Single-item transmog → SetEquipmentSet → full ViewedOutfit rebuild~~ — **FIXED** (session 59, commit `289677be44`): `HandleTransmogrifyItems` now calls `SetEquipmentSet()` after syncing changes — persists to DB, refreshes ViewedOutfit
- **All medium bugs also fixed** (sessions 60/60c):
  - ~~Stale detection false positive~~ — **FIXED** (commit `0cde8db70c`): Server-side source tagging (FromHook flag)
  - ~~Outfit-loaded illusions dropped~~ — **FIXED** (commit `5d38823153`): `fillOutfitData` bootstraps weapon enchant illusions
  - ~~IgnoreMask repair one-directional~~ — **NOT A BUG**: explicit clears render base item via DT=0

### Transmog: Illusions + Clear Slot
- MH enchant illusions (4-field payload) â€” deployed, never verified in-game
- Clear single slot (transmogID=0) â€” deployed, never verified in-game

### Transmog: PR #760 Bugs
- **Bug F**: "Unknown set id 1" â€” SetID mapping destroyed after first apply
- **Bug G**: Name pad byte 0x80 â€” backward ASCII scan misidentifies string boundaries
- **Bug H**: CMSG_TRANSMOGRIFY_ITEMS never fires â€” individual slot transmog completely blocked

---

### Talent Spell Audit -- PIPELINE COMPLETE, STUBS REMOVED
- **1,842 C++ stubs generated** (session 88), then **removed** (session 101) — empty handlers caused load failures
- **SQL still applied**: 114 serverside_spell stubs, 18 spell_proc entries, 1,888 spell_script_names
- **DB state**: 5,470 spell_script_names, 4,503 serverside_spells
- **13 RED / 84 YELLOW remaining** — need real C++ implementations
- **Next**: Implement actual spell logic using SimC references (991 spells have behavioral refs)

### Companion Squad -- `companion_roster` Table Missing
- `characters.companion_roster` table does NOT exist yet
- **Companion system SQL** (`sql/RoleplayCore/5.1 companion characters.sql`) needs to be applied
- Companion system code compiles but can't persist data without this table

### Midnight Data Processing -- PARTIALLY IMPORTED
- **Imported** (sessions 61-67): 58+226 quest starters, 60+181 quest enders, 819 loot entries, 526 creature spells, 174 vendor items
- **310K NPC pipeline** (sessions 73-74): Full Wowhead NPC database in SQLite (309,996 NPCs, 338 MB), coordinate converter built
- **Remaining**: 38,119 gap NPCs identified, 15K vendor items (blocked on ExtendedCost), 402K loot drops (need reference_loot mapping), 32K trainer spells

## MEDIUM Priority

### Midnight Vendor Items (blocked on ExtendedCost)
- Some Midnight NPCs still lack vendor items
- Blocked: scrape doesn't include ExtendedCost data (items would be free without it)
- Need: cross-ref NpcVendor DB2 or ItemExtendedCost DB2 for currency costs

### Skyriding / Dragonriding
- `spell_dragonriding.cpp:39`: `SPELL_RIDING_ABROAD = 432503` â€” TODO outside dragon isles
- `Player.cpp:19509`: forces legacy flight instead of proper skyriding

### Silvermoon: Orgrimmar Portal Room
- Orgrimmar portal room still uses BC-era GO 323854 / spell 121855 â†’ old Silvermoon (Map 530)
- Needs GO 613810 with Midnight-era teleport spell pointing to new coords (Map 0)
- Other Silvermoon portals already fixed (session 58)

### Draconic Diff -- 9 Zones Remaining
- `tools/diff_draconic.py` — zone-by-zone world DB diff vs Draconic-WOW (build 66263)
- **Stormwind DONE** (session 104): 7 missing phase_area, portal fixes, board dedup
- **Next**: Orgrimmar (zone 1637, map 1), then 8 more cities
- **Global phase_area audit** needed after zone diffs complete
- Plan: `doc/world_db_cleanup_plan.md`

### Dead HandleTransmogrifyItems Handler
- `TransmogrificationHandler.cpp` lines 172-567 â€” 400 lines of dead code
- Client never sends `CMSG_TRANSMOGRIFY_ITEMS` in 12.x

### Melee First-Swing NotInRange Bug
- First-swing `NotInRange` errors, possibly CombatReach=0 or same-tick race
- `Unit::IsWithinMeleeRangeAt` (Unit.cpp:697)

### RolePlay.cpp Unverified TODOs
- Line 339: `// TODO: Check if this works`
- Line 397: `// TODO: This should already happen in DeleteFromDB, check this.`

### Stormwind: Class Trainers (15 entries)
- 15 trainers with TRAINER flag but no `trainer_spell` data (Cataclysm stripped class training)
- Options: strip flag, link to existing IDs, or leave as-is (retail-like)

---

## LOW Priority

### 82 Exact-Position Duplicate Creatures
- All `[DNT] Note` (entry 176436) on map 2441 â€” dev test NPCs, harmless

### Transmog: Unicode Outfit Names
- Backward ASCII scan breaks on non-ASCII characters

### Transmog: Outfit Delete Verification
- Assumed via `CMSG_DELETE_EQUIPMENT_SET` â€” unverified

### Transmog: Secondary Shoulder via Outfit Loading
- 13/14 slots work, secondary shoulder is the known gap
- PR #760 â€” upstream wants server-only fix without addon

### Transmog: SecondaryWeaponAppearanceID
- Not persisted â€” Legion artifact niche feature

### Orphan Spell 1251299
- Removed between builds but persists in hotfixes.spell_name â€” harmless

### Companion Squad Improvements
- Only 5 seed companions, damage doesn't scale, no visual customization, kiting AI

### Stormwind: Quest-Giver Flag Cleanup (84 NPCs)
- QUESTGIVER flag with no quest associations â€” cosmetic, matches retail in many cases

---

## DEFERRED / BLOCKED

### Missing Spawns High Tier â€” READY
- 1,626 service NPC spawns (vendors/trainers/FMs) transformable
- Run: `python coord_transformer.py --tier high`

### Service Gaps (997 vendors/trainers) — PARTIALLY RESOLVED
- Originally 997 vendors/trainers with VENDOR/TRAINER flag but zero inventory/spell data
- **Session 58**: Wowhead gap scraper applied 8,799 vendor items — 404 of 687 vendor NPCs now have items
- **Session 64**: BtWQuests parse added 1,062 creature_queststarter + 57 gameobject_queststarter; vendor scrape R2 added 1,435 npc_vendor entries across 82 NPCs
- **Session 65**: NPC mega-scrape (80,943 pages, 120 Tor workers) — 1,727 creature QS, 2,979 creature QE, 2,535 vendor items; ATT cross-ref — 170 creature QS, 124 GO QS, 176 chains; BtWQuests — 572 PrevQuestID + 2,008 NextQuestID
- **Session 66**: Midnight scrape R2 — 226 QS, 181 QE, 174 vendor items, 11 GO quest links; BtWQuests CT enrichment — 228 CT fills, 252 vendor items, 426 exclusive groups
- **Session 67**: Stormwind retail sniff — 152 creature spawns, 21 GO spawns, 9 equipment templates, 161 enrichment updates; Hero's Call Board dedup
- **Remaining**: 68 vendor NPCs still have zero items after scrape (Wowhead has no data for them)
- **Gossip text broken**: Scraper picks up user comments instead of NPC dialogue — gossip import reverted for 56 NPCs
- **Current counts (Mar 7)**: creature_queststarter 30,659 | creature_questender 37,698 | gameobject_queststarter 1,857 | gameobject_questender 1,413 | npc_vendor 174,364
- **Remaining gaps**: quests without starters/enders, 68 empty vendors, 420 gossip NPCs without menus
- **Loot data**: 402K drops extracted but not yet imported (need reference_loot_template mapping)
- **Trainer data**: 32K spells extracted but not yet imported

### Equipment Gaps (~13,001 NPCs)
- Cross-reference LoreWalkerTDB `creature_equip_template` â€” not yet attempted

### Hotfix Repair Persistent Issues
- `mail_template`: 110 rows with truncated multi-line bodies
- `spell` table: 102 rows (zeroed column issue may be moot)
- ~20K missing rows from schema mismatches
- `model_file_data`/`texture_file_data`: massive gaps (client-only rendering data)

### Build 66263 Auth Keys — RESOLVED
- ~~**Bypass active** in WorldSocket.cpp~~ — **REVERTED** (commit `9a813f6ad9`): TC published 66263 keys, bypass removed
- **Data pipeline bumped to 66263**: wago_common.py, CSVs, TACT extraction, Ymir all updated
- **Remaining**: Hotfix repair needs re-run against 66263 baseline

### Auth Key Self-Service Extraction
- x64dbg + WoWDumpFix or Frida method â€” documented, not yet attempted

---

## Recently Completed

### March 7, 2026 (sessions 88-99)
- ~~**Code Quality Pass** (session 94)~~: 39 fixes across 19 files -- 7 critical crash fixes, 8 high, 12 medium, 12 low. Memory leaks, nullptr guards, O(n)-->O(1) optimizations
- ~~**Spell Audit Pipeline** (session 88)~~: 1,842 C++ stubs generated, SQL applied (5,467 spell_script_names, 4,503 serverside_spells)
- ~~**Spell Creator** (session 95)~~: Python CLI tool with 11 templates, wago CSV clone, hotfix SQL gen, SOAP reload
- ~~**VoxCore Command Center** (sessions 93-96)~~: Flask dashboard with 48 tiles, desktop shortcuts synced, path bugs fixed, integrations added
- ~~**SQL Directory Audit** (session 90)~~: 12 issues fixed, 19,416 old TDB files pruned (3.8 GB), tracked files 19,820-->399
- ~~**Doc Audit** (session 91)~~: `doc/` 20-->13 files, 7 obsolete deleted
- ~~**Grand Consolidation** (sessions 83-86)~~: Everything moved to `~/VoxCore/`, 200+ path refs fixed, .gitignore 39-->73, README rewritten
- ~~**Windows Performance Tuning** (session 84)~~: 30+ registry tweaks, NVIDIA MSI mode, Spectre mitigations off
- ~~**Mega Data Mining** (session 77)~~: 316K SQL statements -- 161K creature spells, 105K loot, 28K safe spawns generated
- ~~**Hotfix Repair 66263** (session 97b)~~: 2.7M missing rows inserted, 496 zeroed columns fixed, full DB2 restore
- ~~**MySQL QA** (session 98)~~: UniServerZ configured, my.ini optimized, all SQL updates applied, InnoDB stats refreshed
- ~~**Stormwind Cleanup** (session 82)~~: Wickerman Revelers removed, broken Hero's Call Boards deleted, Silvermoon portal displayId fixed

### March 5-6, 2026 (sessions 58-74)
- ~~Stormwind NPC Scripting (session 69)~~: 37 SmartAI entries, ~426 spawns, phase cleanup
- ~~Stormwind Retail Sniff (session 67)~~: 152 creature spawns, 21 GO spawns, 9 equipment templates
- ~~Midnight Scrape R2 + BtWQuests (session 66)~~: 226 queststarters, 181 questenders, 174 vendor items
- ~~Transmog Hidden Appearance + DT=4 (session 67)~~: Hidden detection, paired weapon DT=4
- ~~NPC Mega-Scrape + ATT + Quest Chains (session 65)~~: 80,943 pages, 1,727+2,979 quest starters/enders
- ~~Transmog 5-Agent Audit Phases 1-4 (session 63)~~: All 26 items implemented
- ~~Transmog Bugs A-E (sessions 36-63)~~: All 5 fixed + 3 medium
- ~~310K NPC Pipeline (sessions 73-74)~~: SQLite DB (338 MB), coord converter, 38K gap NPCs identified
- ~~Wowhead Gap Scrape, ATT Import, Missing Spawns, Quest Reward Text, DBCD Audit, Silvermoon Portals~~ -- all complete

---

## Code Quality Debt (session 24 audit -- mostly resolved)
- ~~`.gitignore` for build artifacts~~ -- DONE (session 86, 39-->73 lines)
- Cross-faction `AllowTwoSide.*` audit
- `MinPetitionSigns=0` -- verify intended
- ~~Dead code: Hoff class~~ -- DONE (session 94, dead methods removed)
- ~~Non-idempotent setup SQL~~ -- DONE (session 90, 5 idempotency fixes)
- RelWithDebInfo `/Ob2` + LTO investigation

## Future Audit Passes
- C++ ScriptName bindings vs compiled script classes
- Map coordinates validity (spawn positions vs map boundaries)
- Client-side rendering data coverage audit

---

*Updated March 8, 2026 (session 106)*


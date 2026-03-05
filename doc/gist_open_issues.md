# RoleplayCore â€” Open Issues & Roadmap

Prioritized list of known issues, planned work, and blocked items. Updated as items are resolved.

---

## HIGH Priority

### VoxCore Website â€” "Arcane Codex" Asset Pipeline (NEW)
- **Phase 0**: Extract WoW visuals via wow-export for website
  - 83 assets curated: 30 dungeon journal art, 21 boss portraits, 32 creature models (SL/DF/TWW/Midnight)
  - wow-export auto-configured (WebP, GLB, no bloat). Scripts at `C:\Tools\website-assets\`
  - Priority: Enchanted Tome (mascot), Xal'atath, Alleria, Khadgar, Midnight raid journal art
- **Phases 1â€“5**: Arcane visual refresh, animated pipeline, tool explorer, before/after slider, interactive timeline

### Transmog: 5-Agent Audit Action Plan (sessions 62–63)
**Status**: Phases 1–4 IMPLEMENTED. All fixes deployed, awaiting in-game testing. Phase 5 (retail capture) deferred.
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

### Talent Spell Audit (session 58)
- `audit_talent_spells.py` identified 183 critical + 242 high priority broken talent spells
- Critical: talent spells referenced in DB but missing C++ ScriptName bindings
- High: spells with effects that may need custom handlers
- Needs C++ script implementation to function correctly

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
- **Current counts**: creature_queststarter 34,647 | creature_questender 37,026 | gameobject_queststarter 2,066 | gameobject_questender 1,625 | npc_vendor 176,853 | PrevQuestID set 25,609
- **Remaining gaps**: 16,552 quests without starter, 13,165 without ender, 68 empty vendors, 420 gossip NPCs without menus
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
- ~~Stormwind Retail Sniff + Hero's Call Board Dedup (session 67)~~: 152 creature spawns, 21 GO spawns, 9 equipment templates, 161 enrichment updates from retail ground truth. Old GO 206111 removed (Hero's Call Board dedup)
- ~~Midnight Scrape R2 + BtWQuests Enrichment (session 66)~~: 226 queststarters, 181 questenders, 174 vendor items, 11 GO quest links, 228 CT fills, 252 vendor items, 426 exclusive groups
- ~~Transmog Hidden Appearance + DT=4 (session 67)~~: Hidden appearance detection, paired weapon display type, PacketScope improvements, addon QA fixes
- ~~NPC Mega-Scrape + ATT + Quest Chains (session 65)~~: 80,943 pages scraped (120 Tor workers), 1,727+2,979 quest starters/enders, 2,535 vendor items, 170+124 ATT QS/GO, 572+2,008 quest chains from BtWQuests. Scraper v2 built
- ~~BtWQuests + Vendor Scrape R2 (session 64)~~: 1,062 creature_queststarter + 57 gameobject_queststarter from BtWQuests, 1,435 npc_vendor entries from Wowhead scrape R2
- ~~Midnight Data Import (session 61/64)~~: 58 quest starters, 60 quest enders, 819 loot entries, 526 creature spells
- ~~Transmog 5-Agent Audit Phases 1–4 (session 63)~~: All 26 action items implemented — 4 server bugs, 4 Bridge cleanup, TransmogSpy v2, Phase 4 hardening, EffectEquipTransmogOutfit fix. Awaiting in-game testing
- ~~Transmog Bugs A–E (sessions 36–63)~~: All 5 original bugs fixed + 3 medium bugs. Awaiting in-game testing
- ~~Wowhead Gap Scrape (session 58)~~: 5,653 pages scraped, 592+683 quest starters/enders, 202+208 GO starters/enders, 8,799 vendor items applied
- ~~ATT Data Import~~: 4,630 quest starters, 3,081 chains, 1,510 vendor items applied
- ~~Missing Spawns Critical~~: 1,541 quest NPC spawns + 207 phase-aware re-inserts applied
- ~~Quest Reward Text Scrape~~: 21,533 pages scraped via Tor, 13,494 offer_reward + 6,792 request_items imported. 14,278 still missing (mostly modern expansion quests)
- ~~Wowhead 403 Block~~: Expired on its own, scraper upgraded with curl_cffi
- ~~DBCD Audit~~: 363 redundant hotfix rows removed, 393 missing broadcast_text filled
- ~~Silvermoon Portals~~: All portals redirected from BC Map 530 to Midnight Map 0

---

## Code Quality Debt (session 24 audit)
- `.gitignore` for build artifacts
- Cross-faction `AllowTwoSide.*` audit
- `MinPetitionSigns=0` â€” verify intended
- Dead code: Hoff class, RotationAxis enum, marker system
- Non-idempotent setup SQL in `sql/RoleplayCore/`
- RelWithDebInfo `/Ob2` + LTO investigation

## Future Audit Passes
- C++ ScriptName bindings vs compiled script classes
- Map coordinates validity (spawn positions vs map boundaries)
- Client-side rendering data coverage audit

---

*Updated March 5, 2026 (session 67)*


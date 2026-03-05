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

### Transmog: 5-Bug Investigation (session 36)
**Status**: Diagnostic build deployed, awaiting testing
- **Bug A**: Paperdoll naked on 2nd UI open
- **Bug B**: Old head/shoulder persists when outfit doesn't define them
- **Bug C**: Monster Mantle ghost appearance (item 182306)
- **Bug D**: Draenei lower leg geometry loss
- **Bug E** (root cause confirmed): Single-item transmog â†’ SetEquipmentSet â†’ full ViewedOutfit rebuild
- 7 diagnostic logs added, not yet committed

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
- **Remaining**: 68 vendor NPCs still have zero items after scrape (Wowhead has no data for them)
- **Gossip text broken**: Scraper picks up user comments instead of NPC dialogue — gossip import reverted for 56 NPCs
- **Remaining gaps**: 16,452 quests missing starters, 13,627 missing enders, 68 empty vendors, 420 gossip NPCs without menus

### Equipment Gaps (~13,001 NPCs)
- Cross-reference LoreWalkerTDB `creature_equip_template` â€” not yet attempted

### Hotfix Repair Persistent Issues
- `mail_template`: 110 rows with truncated multi-line bodies
- `spell` table: 102 rows (zeroed column issue may be moot)
- ~20K missing rows from schema mismatches
- `model_file_data`/`texture_file_data`: massive gaps (client-only rendering data)

### Auth Key Self-Service Extraction
- x64dbg + WoWDumpFix or Frida method â€” documented, not yet attempted

---

## Recently Completed
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

*Updated March 5, 2026 (session 58)*


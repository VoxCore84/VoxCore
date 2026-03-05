# RoleplayCore To-Do List

## Completed (archive)
- Auth key bypass reverted (`8bbd610fc7`), 66220 keys applied
- Hotfix redundancy audit: 10.8M → ~244K content rows, 226,984 hotfix_data entries (3 rounds + orphan sweep)
- ContentTuning enrichment: 4,820 spawned CT=0 creatures → zone/neighbor lookup (`_04` SQL)
- Stormwind CTD rows (11), server-wide CTD rows (26,745), SmartAI orphans (5,894+181 GUID fix)
- Stormwind SmartAI orphans (2), stacked bunny, AIName spaces, flatten C:\Tools dirs
- Raidbots pipeline current for 66220, spell refs non-issue, gist report deleted

## HIGH

### ~~World DB QA Fixes (5 SQL files)~~ DONE
- `_00`: 26,745 missing DifficultyID=0 rows. `_01`: 5,894 SmartAI orphans cleared. `_02`: 181 GUID-based restored
- `_03`: 3 AIName typos + 8 orphaned GUID scripts. `_04`: 4,820 CT=0 creatures enriched
- Commits `f0782d5030`, `9536a248b6`, `21fa23b0d1` — pushed

### Transmog: 5-Bug Investigation (session 36, IN PROGRESS)
- **Diagnostic build deployed**, Debug.log truncated, server shutdown
- **Test plan**: (1) Restart server, (2) Bug A repro, (3) Bug B repro, (4) Debug.log, (5) Bug E separately
- Bug A: Paperdoll naked on 2nd UI open
- Bug B: Old head/shoulder persists (back DOES clear)
- Bug C: Monster Mantle ghost appearance (item 182306)
- Bug D: Draenei lower leg geometry disappeared
- **Bug E (ROOT CAUSE CONFIRMED)**: HandleTransmogrifyItems → SetEquipmentSet → full ViewedOutfit rebuild
- **7 diagnostic logs added** — NOT YET COMMITTED, awaiting test

### Transmog: Test Illusions + Clear Slot
- MH enchant illusions (4-field payload) — deployed, never verified in-game
- Clear single slot (transmogID=0) — deployed, never verified in-game

### Transmog: New Bugs from PR #760 Update
- **Bug F**: "Unknown set id 1" — SetID mapping destroyed after first apply
- **Bug G**: Name pad byte 0x80 parsing — backward ASCII scan misidentifies string boundaries
- **Bug H**: CMSG_TRANSMOGRIFY_ITEMS never fires — individual slot transmog completely blocked

### ~~ContentTuningID=0 Enrichment~~ DONE
- 4,820 of 4,918 spawned CT=0 creatures enriched (98%) via `enrich_content_tuning.py`
- Pass 1: 3,877 via AreaTable lookup, Pass 2: 943 via neighbor interpolation
- 98 unresolved (sparse instanced maps), 36,913 non-spawned CT=0 remaining (harmless)
- Applied in `2026_03_05_04_world.sql`

### Missing Spawn Coordinate Transformer — READY TO DEPLOY
- `coord_transformer.py` built and verified. Transforms Wowhead zone% to world XYZ
- Critical tier: 1,856 quest NPC spawns ready (of 3,022 missing — 1,040 have no Wowhead coords)
- High tier: 1,626 service NPC spawns ready (vendors/trainers/FMs)
- Z estimation: nearest-neighbor interpolation from 527K existing spawns
- **Needs review before applying**: spot-check coordinates, decide on GUID range, test in-game

## MEDIUM

### Stormwind: Trainer Orphans (7 entries) — SKIPPED (retail-accurate)
- 7 NPCs with TRAINER flag but no `creature_trainer` entry — decorative, matches retail

### Stormwind: Class Trainers (15 entries, design decision)
- `npcflag & 16` but no `trainer_spell` data — Cataclysm stripped training
- Options: (a) strip flag, (b) link existing trainers, (c) leave as-is

### Skyriding / Dragonriding
- `spell_dragonriding.cpp:39`: TODO outside dragon isles
- `Player.cpp:19509`: forces old flight mode instead of proper skyriding

### Dead HandleTransmogrifyItems Handler
- 400 lines dead code — client never sends `CMSG_TRANSMOGRIFY_ITEMS` in 12.x

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

## DEFERRED / BLOCKED

### Wowhead 403 Block
- CloudFront WAF since 216K scrape. Tooltip API still works
- Blocks: quest scrape (68,604 IDs), vendor scrape (6,735 IDs)

### Missing Spawns (3,716 high-priority) — TRANSFORMER BUILT
- 2,004 quest NPCs + 1,712 service NPCs
- `coord_transformer.py` ready: 1,856 critical + 1,626 high spawns transformable
- **Not yet applied** — needs spot-check and in-game verification before mass deploy

### Service Gaps (997 vendors/trainers)
- VENDOR/TRAINER flag but zero inventory/spell data — needs Wowhead scraping

### Equipment Gaps (~13,001 NPCs)
- Cross-reference LoreWalkerTDB `creature_equip_template` — not yet attempted

### Missing quest_offer_reward (29,651 quests)
- LW only had 541 more. Players see no reward text.

### Hotfix Repair Persistent Issues
- `mail_template` 110 rows truncated, `spell` 102 rows, ~20K schema mismatches
- `model_file_data`/`texture_file_data` massive gaps (client-only)

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
- DBC/DB2 spell/item existence cross-ref
- Map coordinates validity
- Client-side rendering data coverage

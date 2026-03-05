# Database Audit Tools

Three sibling audit tools + two placement comparison tools, all sharing the same architecture (`mysql_query`, `load_wago_csv`/LW parser, `AUDIT_MAP` dispatch, `--report --json --sql-out --limit` flags).

## NPC Audit — `npc_audit.py` (27 audits)
- **Script**: `C:/Users/atayl/source/wago/npc_audit.py`
- **Output**: `C:/Users/atayl/source/wago/npc_audit_fixes/`
- **Wowhead data**: `C:/Users/atayl/source/wago/wowhead_data/npc/` (scrape ~23%, 8 threads/0.15s delay, est ~16hrs from midnight Feb 28)
- **DANGER**: The `phases` audit generated `phase_area_fixes.sql` (131 entries) + `phase_area_fixes_v2.sql` (17 entries) that were HARMFUL — they added unconditional phase_area entries for quest-progression phases, making ~43K hidden NPCs visible. ALL 148 entries were rolled back (`phase_area_rollback.sql`). **Never auto-fix orphaned PhaseIds** — they're intentionally unmapped quest phases.

## GO Audit — `go_audit.py` (15 audits)
- **Script**: `C:/Users/atayl/source/wago/go_audit.py`
- **Output**: `C:/Users/atayl/source/wago/go_audit_fixes/`
- **Audits**: duplicates, phases, display, type, scale, loot, quest, pools, events, names, smartai, spawntime, addon_orphans, missing, faction
- **Note**: `duplicates` uses Python-side grouping (MySQL self-join times out on 161K rows)

## Quest Audit — `quest_audit.py` (15 audits)
- **Script**: `C:/Users/atayl/source/wago/quest_audit.py`
- **Output**: `C:/Users/atayl/source/wago/quest_audit_fixes/`
- **Audits**: chains, exclusive, givers, enders, objectives, rewards, startitem, missing, orphan_givers, orphan_npcs, poi, offer_reward, questline, addon_sync, duplicates

## GO Placement Audit — `go_placement_audit.py` (6 audits)
- **Script**: `C:/Users/atayl/source/wago/go_placement_audit.py`
- **Output**: `C:/Users/atayl/source/wago/go_placement_fixes/`
- **Reference**: LW `lw_world_imports/lw_gameobject.sql` (194K rows) vs our DB (174K rows)
- **Audits**: summary, missing, misplaced, extra, rotation, properties
- **Results**: 7,778 issues — 5,837 missing spawns, 9 misplaced, 1,625 property mismatches, 261 extra
- **SQL fixes**: 6,767 (5,145 INSERTs + 9 position UPDATEs + 1,613 property UPDATEs)
- **Note**: Wago GameObjects CSV (29K entries) is 98.9% type 5 (signs) — NOT useful for general placement. LW dump is the real reference.

## Creature Placement Audit — `creature_placement_audit.py` (5 audits)
- **Script**: `C:/Users/atayl/source/wago/creature_placement_audit.py`
- **Output**: `C:/Users/atayl/source/wago/creature_placement_fixes/`
- **Reference**: LW `lw_world_imports/lw_creature.sql` (680K rows) vs our DB (652K rows)
- **Audits**: summary, missing, misplaced, extra, properties
- **Results**: 26,210 issues — 21,771 missing spawns, 38 misplaced, 3,178 property mismatches, 1,161 extra
- **SQL fixes**: 24,681 (21,475 INSERTs + 38 position UPDATEs + 3,168 property UPDATEs)

---

## NPC Audit Details

## Usage
```
python npc_audit.py <audits...> [options]
python npc_audit.py all --report --json --no-wowhead
python npc_audit.py duplicates --threshold 1.0
python npc_audit.py levels flags  # needs wowhead data
```

## 28 Audit Checks
| Audit | Data Source | Generates SQL |
|---|---|---|
| `levels` | Wowhead scrape | report only (ContentTuningID) |
| `flags` | MySQL cross-join (npc_vendor, trainer) | yes |
| `faction` | Wago CreatureDifficulty CSV | yes |
| `classification` | Wago Creature CSV | yes |
| `type` | Wago Creature CSV | yes |
| `duplicates` | MySQL creature self-join (phase-aware) | yes (DELETEs) |
| `phases` | MySQL phase_area cross-check (cosmetic phases excluded) | report only |
| `missing` | MySQL + Wago Creature xref + SmartAI/addon/text exclusions | report only |
| `display` | MySQL creature_template_model | report only |
| `names` | MySQL + Wago Creature CSV | yes (name mismatches) |
| `scale` | MySQL (scale <=0 or >10) | yes |
| `speed` | MySQL (walk/run speeds, trigger/vehicle heuristic filter) | yes (zero speeds) |
| `equipment` | MySQL creature_equip_template (priority-tiered) | report only |
| `gossip` | MySQL creature_template_gossip | yes (add/remove GOSSIP flag) |
| `waypoints` | MySQL creature_addon.PathId linkage | report only |
| `smartai` | MySQL smart_scripts vs AIName | yes (clear AIName, ScriptName='0', AIName spaces) |
| `loot` | MySQL creature_loot_template (service NPCs excluded) | report only |
| `auras` | MySQL template_addon + creature_addon + Wago SpellName CSV | yes (invalid spell IDs) |
| `family` | Wago Creature CSV | yes |
| `unitclass` | MySQL (invalid unit_class) | yes |
| `title` | Wago CreatureDifficulty CSV | yes (missing titles only) |
| `spawntime` | MySQL creature spawntimesecs | yes (normalize respawn) |
| `movement` | MySQL MovementType vs spawn_dist | yes (zero wander + service NPCs) |
| `addon_orphans` | MySQL creature_addon/template_addon orphans | yes (DELETEs) |
| `quest_orphans` | MySQL queststarter/questender vs quest_template | yes (DELETEs) |
| `spells` | MySQL creature_template_spell vs Wago SpellName | yes (orphan DELETEs) |
| `scripts` | MySQL ScriptName prefix validation | report only (info) |
| `mapzone` | MySQL creature.map/zone/area vs Wago Map/AreaTable | report only |

## Applied Fixes

### Batch 1 (Feb 27, 2026)
| Fix | Count | Notes |
|---|---|---|
| Phase area mappings v1 | 131 rows | ~10K NPCs now visible |
| Phase area mappings v2 | 17 rows | 41 spawns (Anduin, Faerin, Baine, etc.) |
| Duplicate spawns removed | 4,867 | Phase-aware (same phase+difficulty only) |
| Faction corrections | 4,045 | 11 categories, all from Wago DB2 |
| Classification fixes | 1,225 | Elite/Rare/Boss from Wago |
| Creature type fixes | 574 | Humanoid/Beast/etc from Wago |
| Vendor flag fixes | 16 | Missing VENDOR npcflag bit |
| Trainer flag fixes | 142 | Missing TRAINER+GOSSIP npcflag bits |
| Gossip flag fixes | 1,541 | Has gossip_menu but missing GOSSIP npcflag |
| SmartAI orphan cleanup | 5,550 | AIName=SmartAI but no smart_scripts rows |
| Creature family fixes | 67 | Family mismatches vs Wago DB2 |
| Unit class fixes | 7 | Invalid unit_class=0 → 1 (Warrior) |
| Waypoint orphan fixes | 1,879 | MovementType=2→1, wander_distance=10 |
| SmartAI damage restore | 180 restored | Incorrectly cleared, had guid-based scripts |
| Aura fixes (template) | 184 | creature_template_addon — remove invalid spell IDs |
| Aura fixes (spawn) | 38 | creature_addon (guid-based) — same invalid spells |
| Title fixes | 82 | 2 missing + 80 mismatched subnames vs Wago DB2 |
| **Subtotal** | **20,369** | (180 of SmartAI fixes reversed) |

### Batch 2 (Feb 27, 2026 — QA pass)
| Fix | Count | Notes |
|---|---|---|
| Placeholder names despawned | 399 (1,838 spawns) | All [DNT]/[DND]/[PH]/REUSE — none had real names in Wago |
| Spawned vendor flag cleanup | 631 | VENDOR bit cleared (had flag but no npc_vendor items) |
| Unspawned vendor flag cleanup | 511 | Same, but unspawned templates — DB hygiene |
| Name mismatches fixed | 23 | 18 broken spaces, 4 typos, 1 dev artifact ("Khadgar IGC") |
| Wandering service NPCs | 113 + 1 | 113 set stationary, 1 (Dren Nautilin) switched to waypoint path |
| Gossip flag orphans | 9 | GOSSIP flag but no gossip menu — flag cleared |
| **Subtotal** | **1,687** | |

### Batch 3 (Feb 27, 2026 — comprehensive QA + Phase 3)
| Fix | Count | Notes |
|---|---|---|
| Movement: zero wander distance | 313 | MovementType=1 but wander_distance=0 → set to 10 |
| Spawn times: rares too fast | 6 | 0s respawn → 300s |
| Spawn times: vendors too slow | 522 | 2h-16,800h → 300s (Jaina, Thrall, Bolvar, etc.) |
| Speed: absurd walk speeds | 8 | speed_walk 12-20x → 1.0 (9 scripted NPCs skipped) |
| Scale: invisible creature | 1 | Marrowjaw scale 0→1 |
| Movement: wandering service NPCs | 119 | Vendors/trainers/FMs set stationary (MovementType=0) |
| Name corrections | 13 | 1 typo, 9 Blizz renames, 3 Exile's Reach updates |
| Title placeholder | 1 | Void Thirster "T1" → NULL |
| Addon orphans | 865 | Dead creature_addon rows (no matching creature.guid) |
| **Subtotal** | **1,848** | |
| **Grand Total** | **~23,904** | Across all 3 batches |

## Key Findings

### Phase System
- `phase_area` table: `(AreaId, PhaseId, Comment)` — maps phases to zones
- All 6,974 existing entries are **unconditional** (always-on, no quest gating)
- Zone-level AreaId cascades to all sub-areas
- 98 orphaned PhaseIds had spawns but no phase_area mapping = invisible NPCs
- 18 of those PhaseIds don't exist in Blizzard Phase DB2 (invalid references)
- `conditions` table has 10,100 phase conditions (SourceType=26) but they reference phase_area combos, not standalone

### Duplicate Detection
- CRITICAL: Must check PhaseId + PhaseGroup + spawnDifficulties match
- ~47% of initial "duplicates" were intentional phased variants
- Phase-aware query: JOIN ON `id, map, guid<guid2, PhaseId=PhaseId, PhaseGroup=PhaseGroup, spawnDifficulties=spawnDifficulties`

### Faction Patterns
- faction 35 = Friendly (passive, FriendGroup=1) — RP server default
- faction 188/190 = Ambient (critters, background NPCs)
- faction 14/16 = Monster (hostile to players)
- faction 7 = Creature (neutral, targetable but passive)
- faction 1665 = Friendly variant (attacks monsters, FriendGroup=7)
- Horde generic: 83, 68, 85, 1801, 2361
- Alliance generic: 84, 534

### Waypoint System
- `creature_addon.PathId` links spawns to `waypoint_path.PathId` → `waypoint_path_node`
- PathId convention: `guid * 10` (but not always — creature_addon is the authoritative link)
- `MovementType`: 0=idle, 1=random (needs `wander_distance`>0), 2=waypoint (needs PathId)
- 9,038 waypoint_path entries, 160,784 path nodes in DB

### Loot System
- `creature_loot_template.Entry` = `creature_template.entry` (no lootid column in modern TC)
- Reference loot chains exist — check Entry index, not LEFT JOIN

### AI/Script System
- `SmartAI` can have entry-level scripts (positive entryorguid) OR guid-level (negative entryorguid = -guid)
- `ScriptName='0'` is a data error (8,617 entries) — should be empty string
- Some AINames have leading spaces (49 entries) — TC won't match the AI class

### MySQL Query Notes
- Use `stdin` piping (not `-e`) to avoid Windows command-line length limits
- NPC names can contain literal `\n` — parser must merge continuation lines
- Column count check: incomplete rows (fewer tabs than headers) = continuation

## Current Audit State (post-Phase 3, Feb 27)
21 audits fully clean: levels, flags, faction, classification, type, duplicates, names, scale, gossip, waypoints, smartai, auras, family, unitclass, spawntime, movement, addon_orphans, quest_orphans, title (5 legit), speed (2 edge cases), scripts (4 info)

| Audit | Remaining | Status |
|---|---|---|
| Phases | 2,713 | Reduced from 11,613 — cosmetic phases now excluded. Remainder is quest-phased NPCs (expected) |
| Missing spawns | 12,427 | Reduced from 139,421 (91%) — Wago xref + SmartAI/addon/text exclusions. 280 HIGH priority |
| Equipment | 13,001 | Was 5,000 (cap removed). Priority-tiered: ~276 HIGH (guards/soldiers), rest LOW/MEDIUM |
| Loot | 5,565 | Service NPCs excluded. Remaining are killable elite/rare with no loot (data completeness) |
| Display | 1,923 | Was 1,000 (cap removed). Modelid overrides (informational) |
| Spells | 2 | 2 invalid spell refs (Tainted Earthgrab/Corrupted Nova totems — removed from SpellName DB2) |
| Map/Zone | 2 | 3 spawns in 2 invalid AreaTable areas |

## npc_audit.py Bug Fixes (Feb 27 — commit 5c96b03)
- **NULL string bug**: `mysql_query()` returned literal `"NULL"` strings → now converts to Python `None`. Was causing 10,933 false positive title mismatches
- **Speed audit**: Excludes invisible triggers (`flags_extra & 128`) and NOT_SELECTABLE vehicles
- **Loot audit**: Excludes service NPCs (vendor/trainer/QG/FM/innkeeper/banker) and NOT_SELECTABLE
- **SQL escaping**: Fixed `\'` → `''` (proper SQL quoting)
- **Hardcoded LIMITs**: Removed — all audits now respect `--limit` flag or run unlimited
- **Movement audit**: Now auto-generates fix SQL
- **Equipment audit**: Added priority tiers (HIGH=guards/soldiers, MEDIUM=default, LOW=mages/innkeepers)

## Wowhead Mega-Audit (Mar 3, 2026)
Scraper completed (216,284 NPCs). Full 3-tier audit applied 54,571 DB ops. See [wowhead-npc-audit.md](wowhead-npc-audit.md) for complete breakdown.

## Pending
- **Missing spawns**: 3,716 high-priority (2,004 quest + 1,712 service NPCs) — need coordinate transformer (Wowhead % → world XYZ)
- **Empty services**: 997 vendors/trainers with flags but no inventory/spell data — need Wowhead page scraping
- **Missing CTD rows**: 1,403 creatures lacking creature_template_difficulty DifficultyID=0 rows
- **Equipment gaps**: ~13,001 entries — could cross-ref LoreWalkerTDB `creature_equip_template` for bulk wins
- **Loot gaps**: 5,565 killable elite/rare — low priority for RP server

## Resolved
- ~~**Placeholder names**~~: 399 despawned (1,838 spawn rows). All [DNT]/[DND]/[PH]/REUSE, none had real Wago names
- ~~**Name mismatches**~~: 23 fixed (18 broken spaces, 4 typos, 1 dev artifact). 21 left as-is (Exile's Reach renames, Midnight beta names)
- ~~**Vendors with no items**~~: 0 remaining (631 spawned + 511 unspawned = 1,142 total, all VENDOR bit cleared)
- ~~**Wandering service NPCs**~~: 113 set stationary + 1 waypoint fix. 4 intentional wanderers excluded (Thomas Yance, Benjamin Brode, Vashti, Gordo)
- ~~**Gossip orphans**~~: 9 fixed (GOSSIP flag cleared — no gossip menu)
- ~~**Waypoint orphans**~~: 1,879 fixed. 1 template-level issue remains (Kyle the Frenzied)
- ~~**Invalid auras**~~: 222 fixed (184 template + 38 spawn)
- ~~**Spawn times**~~: Clean
- ~~**Movement zero-wander**~~: Clean

# Wowhead NPC Mega-Audit (Mar 1-3, 2026)

## Overview
Scraped 216,284 NPCs from Wowhead (224,248 IDs requested, 157K ok, 59K skip, 5.5K miss).
Cross-referenced against world DB in 3 tiers + QA. **54,571 total DB operations** applied.
Commit: `d7953794d8` on master, pushed.

## Scraper
- **Script**: `C:/Users/atayl/source/wago/wowhead_scraper.py` with `--ids-file creature_template_ids.txt`
- **Data location**: `C:/Users/atayl/source/wago/wowhead_data/npc/`
  - `npc_export.csv` — 216,284 rows (id, name, level, zone_id, coords, type, classification, react, boss, hasQuests, tag)
  - `raw/*.json` — 218,668 individual files with `name`, `tooltip` (HTML), `map` (zone+coords), `completion_category`, `id`
  - `npc_subtitles.csv` — 32,599 entries
  - `npc_all_coords.csv` — 1.62M coordinate points from 107K NPCs
  - `npc_spawn_summary.csv` — 107K NPCs with zone+coord counts
  - `npc_completion_category.csv` — 218,660 entries
  - `npc_roles.csv` — 160,521 entries with detected roles (vendor/trainer/FM/etc)
- **Manifest**: `_manifest.json`, checkpoint at `_checkpoint.txt`
- **CSV react/boss/hasQuests fields very sparse** — only 675 entries have data (0.3%)

## Tier 1 — Wowhead Cross-Reference (19,024 ops)

| Fix | Count | SQL File |
|-----|-------|----------|
| Safe type fixes (5→10 Giant, 15→12 Aberration) | 2,292 | `npc_safe_fixes.sql` |
| Name corrections | 379 | `scripts/npc_name_fixes.sql` |
| Type & classification remapping | 6,781 | `npc_type_classification_fixes.sql` |
| Level fixes — high (CT 2677, TWW 70-80) | 2,595 | `npc_level_fixes_high.sql` |
| Level fixes — medium (CT 1227/2151) | 2,259 | `npc_level_fixes_medium.sql` |
| Level fixes — low (CT 2/864) | 1,694 | `npc_level_fixes_low.sql` |
| Subtitles/subname fixes | 516 | `npc_subname_fixes.sql` |
| Subname false-positive reverts | 243 | `npc_subname_revert_bad.sql` |
| NPC flag additions (vendor/trainer/FM/etc) | 2,265 | `npc_flag_fixes.sql` |

## Tier 2 — Deep Validation (3,282 ops)

| Fix | Count | SQL File |
|-----|-------|----------|
| ContentTuningID corrections (wrong tier) | 3,013 | `npc_level_range_fixes.sql` |
| Zone hierarchy fixes (1,150 spawns) | 5 | `npc_zone_fixes.sql` |
| Incorrect service flag removals | 21 | `npc_empty_service_fixes.sql` |

Reports: `missing_spawns_report.txt` (3,716 high-priority), `zone_mismatch_report.txt` (198 review items), `empty_services_report.txt` (997 genuine service gaps)

## Tier 3 — DB2 + Internal Consistency (32,265 ops)

| Fix | Count | SQL File |
|-----|-------|----------|
| Hostile-faction vendor fixes | 3 | `npc_faction_fixes.sql` |
| Invalid per-spawn model resets | 232 | `npc_model_fixes.sql` |
| Orphaned SmartAI scripts | 106 | `db_consistency_fixes.sql` |
| Orphaned waypoint paths+nodes | 31,924 | `db_consistency_fixes.sql` |

Reports: `faction_validation_report.txt`, `model_validation_report.txt`, `equipment_validation_report.txt` (all items valid), `db_consistency_report.txt`

## Key Technical Learnings

### Classification Enum Mapping (Wowhead → DB)
- Wowhead: 0=Normal, 1=Elite, 2=Rare, 3=RareElite, 4=Boss
- DB: 0=Normal, 1=Elite, 2=RareElite, 3=Boss(?), 4=Rare, 5=Trivial, **6=MinusMob** (valid! 6,100 entries)
- `CreatureClassifications` enum in `SharedDefines.h:5121-5130`

### ContentTuning System (12.x levels)
- `creature_template_difficulty.ContentTuningID` → `hotfixes.content_tuning` (MinLevel, MaxLevel, MaxLevelType)
- MaxLevelType=2 = expansion cap (90 for Midnight)
- CT=0 or missing CTD row → level 1 (broken)
- Key CTs: 864 (1-90 universal), 2 (Classic 5-30), 1227 (BfA 10-60), 2151 (DF 10-70), 2677 (TWW 70-80), 3085 (Midnight 80-83)
- **Wowhead tooltips show Chromie Time scaled ranges**, not raw CT ranges — can't directly compare

### Wowhead Tooltip Parsing Pitfalls
- Battle Pet tooltips have different HTML structure (`tooltip-pet-header`)
- Bare creature type names ("Beast", "Humanoid") appear as rows — NOT subtitles
- `Level ??` rows, dev tier labels (T0/T1/T2/T3/T4), `&nbsp;` placeholders
- Dungeon journal graphic rows shift all indices by 1
- Subtitle-equals-name false positives (873 entries)

### Wowhead Coordinates
- Map data: `{zone: <id>, coords: {<floorId>: [[x%, y%], ...]}}`
- Coordinates are zone-relative percentages (0-100), NOT world XYZ
- Transformation to world coordinates requires zone boundary mapping — not yet implemented

## Python Scripts Created (`sql/exports/scripts/`)

| Script | Purpose |
|--------|---------|
| `compare_npc_names.py` | Name comparison against CSV |
| `analyze_mismatches.py` | Mismatch categorization |
| `cross_ref_npc_type_classification.py` | Type/class enum cross-ref |
| `fix_level1_npcs.py` | Level-1 fix generator (ContentTuning) |
| `extract_subtitles.py` | Tooltip HTML subtitle extractor |
| `extract_completion_category.py` | Role/category extractor |
| `extract_all_coords.py` | Coordinate extractor |
| `cross_ref_npc_flags.py` | NPC flag cross-ref |
| `cross_ref_zones.py` | Zone validation cross-ref |
| `validate_level_ranges.py` | Level range vs ContentTuning |
| `analyze_missing_spawns.py` | Missing spawn prioritization |
| `audit_empty_services.py` | Empty vendor/trainer audit |
| `validate_factions.py` | Faction ID vs FactionTemplate DB2 |
| `validate_models.py` | Display ID vs CreatureDisplayInfo DB2 |
| `validate_equipment.py` | Equipment items vs ItemSparse DB2 |
| `zone_ct_mapping.txt` | Zone → ContentTuning reference (487 lines) |

## DB2 CSV Locations (build 66220)
- `C:/Users/atayl/source/wago/wago_csv/major_12/12.0.1.66220/enUS/`
- FactionTemplate: 1,862 rows, columns: ID, Faction, Flags, FactionGroup, FriendGroup, EnemyGroup, Enemies_0-7, Friend_0-7
- CreatureDisplayInfo: 118,493 rows
- ItemSparse: 125,515 rows

## Remaining Work (Not Yet Fixable)
- **3,716 high-priority missing spawns** (2,004 quest NPCs + 1,712 service NPCs) — need coordinate transformer
- **997 genuine service gaps** (vendors/trainers with flags but empty inventories) — need Wowhead page scraping
- **1,403 missing creature_template_difficulty rows** — need per-NPC investigation
- **3,760 duplicate spawn groups** — mostly intentional (training dummies etc.)
- **198 zone mismatch review items** — need manual verification

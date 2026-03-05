# Hotfix DB Repair System

## Overview
- **Script**: `C:/Users/atayl/source/wago/repair_hotfix_tables.py` — compares hotfix DB tables against Wago DB2 CSVs
- Runs in 5 batches (~80 tables each), generates UPDATE/INSERT SQL + hotfix_data entries
- **Companion scripts**: `repair_scene_scripts.py` (hex-encoded Lua), `audit_coverage.py` (table coverage)

## Latest Run: Build 66220 (Mar 3 2026)
- 388 tables compared (78+77+78+77+78), all 5 batches generated + applied:
  - Matching: 9,790,318 rows
  - Fixed zeroed columns: 1,831 UPDATEs
  - Custom diffs preserved: 468,972 rows
  - Extra rows in DB: 375,940
  - Missing rows added: 103,153 INSERTs
  - hotfix_data entries: 843,894 (ID range 5M-17M)
  - Total SQL: ~71 MB across 5 batch files
- Post-apply DB state: 1,084,369 hotfix_data rows, 204 distinct tables
- Key table row counts: spell_name 400K, item_sparse 172K, spell_effect 513K, CDI 118K, area 9.8K

### Previous Run: Build 66192 (Feb 27 2026)
- 387 tables, 53K inserts, 283 fixes, 309K hotfix_data, ~29.4 MB SQL
- Scene scripts repair: 36 encoding fixes + 224 new scripts inserted

## Column Normalization
- `normalize_col()` + 28 global aliases + 23 table-specific aliases
- TABLE_NAME_OVERRIDES: 6 entries for camel_to_snake edge cases (GameObjects, QuestPOIPoint, MCRSlotXMCRCategory, etc.)

## Redundancy Audit (3 Rounds — COMPLETE)

Cleaned redundant rows that exactly match DBC baseline (no gameplay impact).

| Round | Method | Redundant Removed | DB Size After |
|-------|--------|------------------:|---------------|
| R1 | Wago CSV string compare | 9,580,000 | ~2.2 GB → ~1.1 GB |
| R2 | WTL DBC2CSV, improved mapping | 204,447 | ~970.9 MB |
| R3 | Type-aware (float32 rtol, int32 sign, logical PK) | 767,691 | 881.5 MB |
| **Total** | | **~10,552,138** | **881.5 MB** |

**Post-cleanup inventory** (239,595 genuine rows across 109 audited tables):
- Override (modified from DBC): 8,396 rows (0.8%)
- New (custom content): 231,199 rows (23.0%)
- Plus negative-build rows (sacred TC fixes) — never touched

**R3 key fixes**: float32 relative tolerance 1e-5, unsigned/signed int32 bitmask, broadcast_text_duration logical PK (BroadcastTextID, Locale), corrected 0-indexed vs 1-indexed array detection

**R3 scripts** (all in `C:/Dev/RoleplayCore/hotfix_audit/`):
- `build_table_info_r3.py` — column mapper with manual maps for 8 low-coverage tables
- `hotfix_differ_r3.py` — type-aware differ (float32, int32 sign, logical PK override)
- `gen_practical_sql_r3.py` — generates TRUNCATE + batched DELETE SQL
- `gen_inventory_report.py` — generates `hotfix_inventory.md` (6-section report)
- `prep_r3_groups.py` — splits tables into balanced parallel groups
- Results: `results_r3/*.json` (109 files), `hotfix_inventory.md`, `hotfix_cleanup_round3.sql`

## Known Remaining Gaps
- `mail_template`: 110 rows with truncated multi-line bodies (fix=1 persists)
- `spell`: fix=1 persists (zeroed column keeps regenerating)
- `scene_script_text`: multi-line Lua parsing handled by `repair_scene_scripts.py`
- model_file_data/texture_file_data: huge missing counts — client-only rendering data
- Missing row gaps: ~20K rows that INSERT IGNORE can't insert (schema mismatches between Wago CSV columns and hotfix DB table schemas)
- `gameobjects`: 2 remaining override rows (Rot3/Rot4 float precision at 1.46e-5, just above 1e-5 threshold) — not worth adjusting

## Verification Results (Mar 3 2026 — build 66220)
- All 5 batches applied cleanly to hotfixes DB
- hotfix_data: 1,084,369 rows, 204 distinct TableHash values
- Build diff 66192→66220: +133,454 added rows, 174 modified, 0 removed
  - SpellEffect: +87,615 (biggest delta — new spell effects backfilled)
  - ItemSparse: +45,567 (massive item data expansion)
  - ModifierTree: +221
  - SpellName/Spell: +10 each
  - CreatureDisplayInfo, AreaTable: unchanged

### Previous Verification (Feb 27 2026 — build 66192)
- Batches 1, 3, 5: CLEAN — zero fixes needed
- Batch 2: 1 persistent fix in `spell`, 17,056 missing rows
- Batch 4: 1 persistent fix in `mail_template`, 3,453 missing rows
- Audit coverage: 400/512 hotfix tables matched to CSVs (78.1%)

## Running the Repair
```bash
cd /c/Users/atayl/source/wago
for i in 1 2 3 4 5; do
  python repair_hotfix_tables.py --batch $i
  echo "SET innodb_lock_wait_timeout=120;" | cat - repair_batch_${i}.sql | \
    "C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -padmin hotfixes
done
python repair_scene_scripts.py
echo "SET innodb_lock_wait_timeout=120;" | cat - repair_scene_scripts.sql | \
  "C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -padmin hotfixes
```

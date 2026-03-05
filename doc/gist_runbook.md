# RoleplayCore — Operations Runbook

Quick-reference for all data pipeline commands. All Python scripts live in `C:/Users/atayl/source/wago/` and use `C:\Python314\python.exe`.

---

## 1. AllTheThings Import (quest givers, chains, vendors)

**What it does**: Parses the ATT community database (1,576 Lua files) and fills missing quest-giver assignments, quest chain prerequisites, and vendor inventories.

```bash
# Step 1: Update ATT source data
cd C:/Tools/ATT-Database && git pull

# Step 2: Parse ATT repo -> JSON (~30 seconds)
cd C:/Users/atayl/source/wago
C:\Python314\python.exe att_parser.py --repo C:/Tools/ATT-Database --output att_data.json

# Step 3: Generate validated SQL (cross-refs against live DB)
C:\Python314\python.exe att_generate_sql.py --data att_data.json --output att_validated.sql

# Step 4: Apply to world DB
mysql -u root -padmin world < att_validated.sql

# Optional: Stats only (no SQL output)
C:\Python314\python.exe att_generate_sql.py --data att_data.json --dry-run
```

**Tables affected**: `creature_queststarter`, `quest_template_addon`, `npc_vendor`
**Safe to re-run**: Yes (INSERT IGNORE + conditional UPDATE)

---

## 2. Quest Reward Text Scrape (NPC turn-in dialogue)

**What it does**: Scrapes Wowhead for `quest_offer_reward.RewardText` — the NPC dialogue when you turn in a quest. This is server-side only data, no other source has it.

```bash
cd C:/Users/atayl/source/wago

# Step 1: Generate missing quest ID list (one-time, or re-run to update)
mysql -u root -padmin world -N -e "
  SELECT qt.ID FROM quest_template qt
  LEFT JOIN quest_offer_reward qor ON qor.ID = qt.ID
  WHERE qor.ID IS NULL AND qt.ID > 0 AND qt.ID < 100000
  ORDER BY qt.ID" > quest_ids_missing_reward.txt

# Step 2: Run the scrape (~2 hours for ~27K quests, two-phase)
# Phase A: Tooltips first (fast, filters 404s)
C:\Python314\python.exe wowhead_scraper.py quest \
  --ids-file quest_ids_missing_reward.txt \
  --tooltip-only --randomize \
  --threads 4 --delay 0.1 \
  --batch-size 5000 --batch-pause 120 \
  --resume --verbose

# Phase B: Full pages (slower, gets reward text)
C:\Python314\python.exe wowhead_scraper.py quest \
  --ids-file quest_ids_missing_reward.txt \
  --pages-only --randomize \
  --threads 3 --delay 0.2 \
  --batch-size 5000 --batch-pause 120 \
  --resume --verbose

# Step 3: Convert scraped JSON -> SQL
C:\Python314\python.exe import_quest_rewards.py \
  --ids-file quest_ids_missing_reward.txt \
  --output quest_rewards.sql

# Step 4: Apply
mysql -u root -padmin world < quest_rewards.sql
```

**Tables affected**: `quest_offer_reward`, `quest_request_items`
**Safe to re-run**: Yes (uses INSERT IGNORE)
**VPS option**: For faster/unattended scraping, see `vps_scrape_setup.sh`

---

## 3. Missing NPC Spawns (coordinate transformer)

**What it does**: Takes Wowhead zone-percent coordinates and transforms them to world XYZ for creature table INSERT.

```bash
cd C:/Users/atayl/source/wago

# Critical tier (quest NPCs)
C:\Python314\python.exe coord_transformer.py --tier critical

# High tier (service NPCs: vendors, trainers, flight masters)
C:\Python314\python.exe coord_transformer.py --tier high

# Review output, then apply
mysql -u root -padmin world < coord_transformer_output.sql
```

**Tables affected**: `creature`
**Needs review**: Yes — spot-check coordinates before applying

---

## 4. Hotfix Repair (after build bump)

**What it does**: Repairs hotfix tables by comparing Wago DB2 CSVs against MySQL, generating INSERT/UPDATE SQL.

```bash
cd C:/Users/atayl/source/wago

# Step 1: Update build number in wago_common.py (edit CURRENT_BUILD)

# Step 2: Download fresh CSVs
C:\Python314\python.exe wago_db2_downloader.py --tables-file tables_all.txt

# Step 3: Run repair (5 batches)
C:\Python314\python.exe repair_hotfix_tables.py --batch 1
C:\Python314\python.exe repair_hotfix_tables.py --batch 2
C:\Python314\python.exe repair_hotfix_tables.py --batch 3
C:\Python314\python.exe repair_hotfix_tables.py --batch 4
C:\Python314\python.exe repair_hotfix_tables.py --batch 5

# Step 4: Apply each batch
mysql -u root -padmin hotfixes < repair_batch_1.sql
mysql -u root -padmin hotfixes < repair_batch_2.sql
# ... etc
```

**Tables affected**: All `hotfixes.*` tables
**When to run**: After every WoW client build update

---

## 5. Raidbots Data Pipeline

**What it does**: Downloads Raidbots JSON data and imports item names, quest chains, quest POI, and locale text into world/hotfixes.

```bash
cd C:/Users/atayl/source/wago

# Full pipeline (downloads + generates SQL)
C:\Python314\python.exe run_all_imports.py --regenerate

# Apply generated SQL
mysql -u root -padmin world < raidbots/sql_output/quest_chains.sql
mysql -u root -padmin world < raidbots/sql_output/quest_poi_import.sql
mysql -u root -padmin world < raidbots/sql_output/quest_poi_points_import.sql
mysql -u root -padmin world < raidbots/sql_output/quest_objectives_import.sql
mysql -u root -padmin hotfixes < raidbots/sql_output/item_sparse_locale.sql
mysql -u root -padmin hotfixes < raidbots/sql_output/item_search_name_locale.sql
```

**Tables affected**: `quest_template_addon`, `quest_poi`, `quest_poi_points`, `quest_objectives`, `item_sparse_locale`, `item_search_name_locale`

---

## 6. Wowhead NPC/Item/Spell Scraper (general)

**What it does**: Scrapes Wowhead tooltips and/or pages for any entity type.

```bash
cd C:/Users/atayl/source/wago

# Scrape NPCs by ID range
C:\Python314\python.exe wowhead_scraper.py npc --start 1 --end 1000 --threads 2 --delay 0.5 --resume

# Scrape items from a file of IDs
C:\Python314\python.exe wowhead_scraper.py item --ids-file my_item_ids.txt --threads 2 --delay 0.5 --resume

# Scrape spells
C:\Python314\python.exe wowhead_scraper.py spell --start 1 --end 500000 --threads 2 --delay 0.5 --resume
```

**Entity types**: `npc`, `item`, `spell`, `quest`, `vendor`, `talent`, `effect`
**Key flags**: `--resume` (skip already cached), `--verbose`, `--force` (re-scrape), `--randomize`
**Output**: `wowhead_data/<type>/raw/<id>.json`

---

## 7. Database Snapshots

**What it does**: Creates compressed SQL backups before risky operations.

```bash
cd C:/Users/atayl/source/wago

# Snapshot a database
C:\Python314\python.exe snapshot_manager.py --db world --reason "pre-att-import"

# List snapshots
ls snapshots/*.sql.gz
```

---

## 8. Build Diff Audit

**What it does**: Compares Wago DB2 CSVs across WoW client builds to find content changes.

```bash
cd C:/Users/atayl/source/wago

# Diff two builds
C:\Python314\python.exe diff_builds.py --old 66198 --new 66220

# Cross-reference against MySQL
C:\Python314\python.exe cross_ref_mysql.py --build 66220
```

---

## Quick Reference: Common One-Liners

```bash
# Check quest-giver coverage
mysql -u root -padmin world -e "SELECT COUNT(DISTINCT quest) FROM creature_queststarter"

# Check quest chain coverage
mysql -u root -padmin world -e "SELECT COUNT(*) FROM quest_template_addon WHERE PrevQuestID != 0"

# Check vendor coverage
mysql -u root -padmin world -e "SELECT COUNT(DISTINCT entry) FROM npc_vendor"

# Check quest reward text coverage
mysql -u root -padmin world -e "SELECT COUNT(*) FROM quest_offer_reward"

# Update ATT source
cd C:/Tools/ATT-Database && git pull
```

---

*Last updated: Mar 5, 2026*

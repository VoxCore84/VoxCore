/* ================================================================== */
/* GENRE 6A v3 — Loot template orphaned-item cleanup                  */
/* TrinityCore Midnight 12.x (TWW 11.1.7)                            */
/*                                                                    */
/* Removes loot rows referencing items that don't exist in any item   */
/* source (item_template, item_sparse, hotfixes.item_sparse, etc).    */
/*                                                                    */
/* v3: No stored procedures (workaround for corrupted mysql.procs_priv*/
/*     table). All logic is inline with per-table blocks.             */
/*                                                                    */
/* Fixes from v1:                                                     */
/*   - Removed embedded GitHub review comments                        */
/*   - DDL (backup tables) BEFORE START TRANSACTION                   */
/*   - ROW_COUNT() captured BEFORE DEALLOCATE PREPARE                 */
/*   - COALESCE on session save/restore                               */
/*   - Coverage guard (≥80%) per table — blocks deletion if item      */
/*     sources are incomplete                                         */
/*   - Unified _known_items temp table (replaces 4x EXISTS per table) */
/*                                                                    */
/* SET @APPLY_FIX := 0 for dry-run diagnostics only.                  */
/* SET @APPLY_FIX := 1 to apply mutations.                            */
/*                                                                    */
/* IMPORTANT: Run the COMPLETE file. Do not paste fragments.          */
/* ================================================================== */

USE `world`;
SELECT DATABASE() AS active_database;

SET @APPLY_FIX := 0;

/* ── Session snapshot ────────────────────────────────────────────── */
SET @OLD_SQL_SAFE_UPDATES   := COALESCE(@@SQL_SAFE_UPDATES, 1);
SET @OLD_FOREIGN_KEY_CHECKS := COALESCE(@@FOREIGN_KEY_CHECKS, 1);
SET @OLD_UNIQUE_CHECKS      := COALESCE(@@UNIQUE_CHECKS, 1);
SET @OLD_AUTOCOMMIT         := COALESCE(@@AUTOCOMMIT, 1);

SET SQL_SAFE_UPDATES  = 0;
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS      = 0;
SET AUTOCOMMIT         = 0;

/* ================================================================== */
/* ITEM SOURCE DETECTION                                              */
/* ================================================================== */
SELECT 'ITEM SOURCE DETECTION' AS section;

SET @src_wit_exists := 0;  SET @src_wit_pk := NULL;
SET @src_wis_exists := 0;  SET @src_wis_pk := NULL;
SET @src_his_exists := 0;  SET @src_his_pk := NULL;
SET @src_hi_exists  := 0;  SET @src_hi_pk  := NULL;

/* ── world.item_template ─────────────────────────────────────────── */
SELECT COUNT(*) INTO @src_wit_exists
FROM information_schema.tables
WHERE table_schema = 'world' AND table_name = 'item_template';

SET @sql := IF(@src_wit_exists = 1,
  "SELECT CASE
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_template' AND column_name='entry') THEN 'entry'
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_template' AND column_name='ID')    THEN 'ID'
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_template' AND column_name='id')    THEN 'id'
     ELSE NULL END INTO @src_wit_pk",
  "SELECT 'SKIP: world.item_template missing' AS note");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ── world.item_sparse ───────────────────────────────────────────── */
SELECT COUNT(*) INTO @src_wis_exists
FROM information_schema.tables
WHERE table_schema = 'world' AND table_name = 'item_sparse';

SET @sql := IF(@src_wis_exists = 1,
  "SELECT CASE
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_sparse' AND column_name='ID')    THEN 'ID'
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_sparse' AND column_name='id')    THEN 'id'
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_sparse' AND column_name='entry') THEN 'entry'
     ELSE NULL END INTO @src_wis_pk",
  "SELECT 'SKIP: world.item_sparse missing' AS note");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ── hotfixes schema ─────────────────────────────────────────────── */
SET @hf_exists := (SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = 'hotfixes');

/* ── hotfixes.item_sparse ────────────────────────────────────────── */
SET @sql := IF(@hf_exists = 1,
  "SELECT COUNT(*) INTO @src_his_exists FROM information_schema.tables WHERE table_schema='hotfixes' AND table_name='item_sparse'",
  "SET @src_his_exists := 0");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@src_his_exists = 1,
  "SELECT CASE
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item_sparse' AND column_name='ID')    THEN 'ID'
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item_sparse' AND column_name='id')    THEN 'id'
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item_sparse' AND column_name='entry') THEN 'entry'
     ELSE NULL END INTO @src_his_pk",
  "SELECT 'SKIP: hotfixes.item_sparse missing' AS note");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ── hotfixes.item ───────────────────────────────────────────────── */
SET @sql := IF(@hf_exists = 1,
  "SELECT COUNT(*) INTO @src_hi_exists FROM information_schema.tables WHERE table_schema='hotfixes' AND table_name='item'",
  "SET @src_hi_exists := 0");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@src_hi_exists = 1,
  "SELECT CASE
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item' AND column_name='ID')    THEN 'ID'
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item' AND column_name='id')    THEN 'id'
     WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item' AND column_name='entry') THEN 'entry'
     ELSE NULL END INTO @src_hi_pk",
  "SELECT 'SKIP: hotfixes.item missing' AS note");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT
  IF(@src_wit_exists = 1 AND @src_wit_pk IS NOT NULL, CONCAT('world.item_template (', @src_wit_pk, ')'), 'n/a') AS item_template,
  IF(@src_wis_exists = 1 AND @src_wis_pk IS NOT NULL, CONCAT('world.item_sparse (', @src_wis_pk, ')'),  'n/a') AS world_item_sparse,
  IF(@src_his_exists = 1 AND @src_his_pk IS NOT NULL, CONCAT('hotfixes.item_sparse (', @src_his_pk, ')'), 'n/a') AS hotfixes_item_sparse,
  IF(@src_hi_exists = 1  AND @src_hi_pk IS NOT NULL,  CONCAT('hotfixes.item (', @src_hi_pk, ')'),         'n/a') AS hotfixes_item;

/* ================================================================== */
/* KNOWN ITEMS — single unified lookup table                          */
/* ================================================================== */
SELECT 'BUILDING KNOWN ITEMS TABLE' AS section;

DROP TEMPORARY TABLE IF EXISTS _known_items;
CREATE TEMPORARY TABLE _known_items (
  item_id INT UNSIGNED NOT NULL PRIMARY KEY
) ENGINE=InnoDB;

SET @sql := IF(@src_wit_exists = 1 AND @src_wit_pk IS NOT NULL,
  CONCAT('INSERT IGNORE INTO _known_items(item_id) SELECT CAST(`', @src_wit_pk, '` AS UNSIGNED) FROM `world`.`item_template` WHERE `', @src_wit_pk, '` > 0'),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@src_wis_exists = 1 AND @src_wis_pk IS NOT NULL,
  CONCAT('INSERT IGNORE INTO _known_items(item_id) SELECT CAST(`', @src_wis_pk, '` AS UNSIGNED) FROM `world`.`item_sparse` WHERE `', @src_wis_pk, '` > 0'),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@src_his_exists = 1 AND @src_his_pk IS NOT NULL,
  CONCAT('INSERT IGNORE INTO _known_items(item_id) SELECT CAST(`', @src_his_pk, '` AS UNSIGNED) FROM `hotfixes`.`item_sparse` WHERE `', @src_his_pk, '` > 0'),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@src_hi_exists = 1 AND @src_hi_pk IS NOT NULL,
  CONCAT('INSERT IGNORE INTO _known_items(item_id) SELECT CAST(`', @src_hi_pk, '` AS UNSIGNED) FROM `hotfixes`.`item` WHERE `', @src_hi_pk, '` > 0'),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT COUNT(*) AS known_items_loaded FROM _known_items;
SET @has_item_sources := (SELECT IF(COUNT(*) > 0, 1, 0) FROM _known_items);

/* ================================================================== */
/* SUMMARY TABLE                                                      */
/* ================================================================== */

DROP TEMPORARY TABLE IF EXISTS _genre6a_summary;
CREATE TEMPORARY TABLE _genre6a_summary (
  table_name     VARCHAR(128) NOT NULL PRIMARY KEY,
  status_note    VARCHAR(255) NOT NULL DEFAULT '',
  distinct_items BIGINT NOT NULL DEFAULT 0,
  matched_items  BIGINT NOT NULL DEFAULT 0,
  coverage_pct   DECIMAL(5,1) NOT NULL DEFAULT 0,
  missing_before BIGINT NOT NULL DEFAULT 0,
  backed_up      BIGINT NOT NULL DEFAULT 0,
  deleted        BIGINT NOT NULL DEFAULT 0,
  missing_after  BIGINT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

/* ================================================================== */
/* LOOT TABLE LIST — drives per-table processing                      */
/*                                                                    */
/* Each block:                                                        */
/*   1. Detects table + item column                                   */
/*   2. Coverage guard (distinct items vs _known_items, ≥80%)         */
/*   3. Counts orphans                                                */
/*   4. Backs up + deletes (only if coverage OK + @APPLY_FIX = 1)    */
/*   5. Verifies + writes summary                                    */
/*                                                                    */
/* ROW_COUNT() is captured BEFORE DEALLOCATE PREPARE in all cases.    */
/* ================================================================== */

/* ================================================================== */
/* DDL PHASE — backup table creation (before transaction)             */
/* ================================================================== */
SELECT 'BACKUP TABLE CREATION (DDL)' AS section;

/* We build backup tables for all 12 loot tables that exist,
   but only when @APPLY_FIX = 1. Since CREATE TABLE is DDL, it must
   happen outside the transaction. */

SET @_lt_list := 'creature_loot_template,gameobject_loot_template,item_loot_template,fishing_loot_template,skinning_loot_template,pickpocketing_loot_template,reference_loot_template,prospecting_loot_template,milling_loot_template,disenchant_loot_template,spell_loot_template,mail_loot_template';

/* Unrolled DDL loop — 12 tables */
SET @_tbl := 'creature_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'gameobject_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'item_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'fishing_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'skinning_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'pickpocketing_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'reference_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'prospecting_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'milling_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'disenchant_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'spell_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'mail_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6a` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ================================================================== */
/* DML PHASE — inside transaction                                     */
/* ================================================================== */
START TRANSACTION;

/* ────────────────────────────────────────────────────────────────── */
/* MACRO: Per-table processing block                                  */
/*                                                                    */
/* Each block does:                                                   */
/*   @_tbl       → table name                                        */
/*   @_tex       → table exists?                                     */
/*   @_icol      → item column name                                  */
/*   @_can       → can process? (table + item col + sources)         */
/*   @_total     → distinct items in table                           */
/*   @_matched   → how many exist in _known_items                    */
/*   @_pct       → coverage percentage                               */
/*   @_del_ok    → coverage ≥80%?                                    */
/*   @_miss_b    → orphan count before                               */
/*   @_backedup  → rows backed up                                    */
/*   @_deld      → rows deleted                                      */
/*   @_miss_a    → orphan count after                                */
/* ────────────────────────────────────────────────────────────────── */

/* ── 1) creature_loot_template ───────────────────────────────────── */
SET @_tbl := 'creature_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ── 2) gameobject_loot_template ─────────────────────────────────── */
SET @_tbl := 'gameobject_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ── 3) item_loot_template ───────────────────────────────────────── */
SET @_tbl := 'item_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ── 4) fishing_loot_template ────────────────────────────────────── */
SET @_tbl := 'fishing_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ── 5) skinning_loot_template ───────────────────────────────────── */
SET @_tbl := 'skinning_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ── 6) pickpocketing_loot_template ──────────────────────────────── */
SET @_tbl := 'pickpocketing_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ── 7) reference_loot_template ──────────────────────────────────── */
SET @_tbl := 'reference_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ── 8) prospecting_loot_template ────────────────────────────────── */
SET @_tbl := 'prospecting_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ── 9) milling_loot_template ────────────────────────────────────── */
SET @_tbl := 'milling_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ── 10) disenchant_loot_template ────────────────────────────────── */
SET @_tbl := 'disenchant_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ── 11) spell_loot_template ─────────────────────────────────────── */
SET @_tbl := 'spell_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ── 12) mail_loot_template ──────────────────────────────────────── */
SET @_tbl := 'mail_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @_icol := NULL;
SET @sql := IF(@_tex=1, CONCAT("SELECT column_name INTO @_icol FROM information_schema.columns WHERE table_schema='world' AND table_name='",@_tbl,"' AND column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(column_name,'Item','item','itemid','ItemID') LIMIT 1"), "SET @_icol := NULL");
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_can := IF(@_tex=1 AND @_icol IS NOT NULL AND @has_item_sources=1, 1, 0);
SET @_status := IF(@_tex=0,'SKIP: table missing',IF(@_icol IS NULL,'SKIP: item column not found',IF(@has_item_sources=0,'SKIP: no item sources','pending')));
SET @_total:=0; SET @_matched:=0; SET @_pct:=0; SET @_del_ok:=0; SET @_miss_b:=0; SET @_backedup:=0; SET @_deld:=0; SET @_miss_a:=0;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_total FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(DISTINCT t.`',@_icol,'`) INTO @_matched FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @_pct := IF(@_total > 0, ROUND(100.0 * @_matched / @_total, 1), 100.0);
SET @_del_ok := IF(@_pct >= 80, 1, 0);

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_b FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('INSERT IGNORE INTO `',@_tbl,'_backup_genre6a` SELECT t.* FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_backedup := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1 AND @_miss_b>0,
  CONCAT('DELETE t FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @_deld := IF(@_can=1 AND @APPLY_FIX=1 AND @_del_ok=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;

SET @sql := IF(@_can=1, CONCAT('SELECT COUNT(*) INTO @_miss_a FROM `',@_tbl,'` t WHERE t.`',@_icol,'` > 0 AND NOT EXISTS (SELECT 1 FROM _known_items ki WHERE ki.item_id = t.`',@_icol,'`)'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_status := IF(@_can=0, @_status, IF(@_del_ok=0, CONCAT('BLOCKED — coverage ',@_pct,'% (<80%)'), IF(@APPLY_FIX=0, CONCAT('DRY RUN — ',@_miss_b,' orphans'), IF(@_miss_b=0,'OK — no orphans','OK'))));
INSERT INTO _genre6a_summary VALUES (@_tbl,@_status,@_total,@_matched,@_pct,@_miss_b,@_backedup,@_deld,@_miss_a) ON DUPLICATE KEY UPDATE status_note=VALUES(status_note),distinct_items=VALUES(distinct_items),matched_items=VALUES(matched_items),coverage_pct=VALUES(coverage_pct),missing_before=VALUES(missing_before),backed_up=VALUES(backed_up),deleted=VALUES(deleted),missing_after=VALUES(missing_after);


/* ================================================================== */
/* RESULTS                                                            */
/* ================================================================== */
SELECT 'SUMMARY' AS section;

SELECT
  table_name, status_note, distinct_items, matched_items,
  coverage_pct, missing_before, backed_up, deleted, missing_after
FROM _genre6a_summary
ORDER BY table_name;

/* ── Commit or rollback ──────────────────────────────────────────── */
SET @sql := IF(@APPLY_FIX = 1, 'COMMIT', 'ROLLBACK');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ── Cleanup ─────────────────────────────────────────────────────── */
DROP TEMPORARY TABLE IF EXISTS _known_items;
DROP TEMPORARY TABLE IF EXISTS _genre6a_summary;

/* ── Restore session ─────────────────────────────────────────────── */
SET SQL_SAFE_UPDATES   = COALESCE(@OLD_SQL_SAFE_UPDATES, 1);
SET FOREIGN_KEY_CHECKS = COALESCE(@OLD_FOREIGN_KEY_CHECKS, 1);
SET UNIQUE_CHECKS      = COALESCE(@OLD_UNIQUE_CHECKS, 1);
SET AUTOCOMMIT         = COALESCE(@OLD_AUTOCOMMIT, 1);

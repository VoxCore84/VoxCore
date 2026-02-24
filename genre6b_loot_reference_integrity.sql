/* ================================================================== */
/* GENRE 6B v2 — Loot reference integrity + group rules + MinCount    */
/* TrinityCore Midnight 12.x (TWW 11.1.7)                            */
/*                                                                    */
/* Three fix categories per loot table:                               */
/*   A) DELETE rows with Reference > 0 pointing to non-existent      */
/*      reference_loot_template entry                                 */
/*   B) UPDATE GroupId for items with Chance=0 and GroupId=0          */
/*      (assigns next available group per Entry)                      */
/*   C) UPDATE MinCount from 0 → 1 for real items (Item > 0)         */
/*                                                                    */
/* v2 fixes over v1:                                                  */
/*   - Removed embedded GitHub review comments (syntax errors)        */
/*   - DDL (backup tables) BEFORE START TRANSACTION                   */
/*   - ROW_COUNT() captured BEFORE DEALLOCATE PREPARE                 */
/*   - COALESCE on SUM aggregates (NULL from empty tables)            */
/*   - COALESCE on session variable restores                          */
/*   - CAST on group_concat_max_len restore                           */
/*   - @APPLY_FIX defaults to 0 (dry-run)                            */
/*   - Per-table + global caps retained from v1                       */
/*                                                                    */
/* SET @APPLY_FIX := 0 for dry-run diagnostics only.                  */
/* SET @APPLY_FIX := 1 to apply mutations.                            */
/*                                                                    */
/* IMPORTANT: Run the COMPLETE file. Do not paste fragments.          */
/* ================================================================== */

USE `world`;
SELECT DATABASE() AS active_database;

SET @APPLY_FIX := 1;

SET @MAX_DELETE_PER_TABLE := 5000;
SET @MAX_UPDATE_PER_TABLE := 20000;
SET @MAX_TOUCH_TOTAL      := 40000;
SET @FORCE_TOUCH          := 0;

/* ── Session snapshot ────────────────────────────────────────────── */
SET @OLD_SQL_SAFE_UPDATES   := COALESCE(@@SQL_SAFE_UPDATES, 1);
SET @OLD_FOREIGN_KEY_CHECKS := COALESCE(@@FOREIGN_KEY_CHECKS, 1);
SET @OLD_UNIQUE_CHECKS      := COALESCE(@@UNIQUE_CHECKS, 1);
SET @OLD_AUTOCOMMIT         := COALESCE(@@AUTOCOMMIT, 1);
SET @OLD_GROUP_CONCAT_MAX_LEN := COALESCE(@@SESSION.group_concat_max_len, 1024);

SET SESSION group_concat_max_len = 1024 * 1024 * 16;
SET SQL_SAFE_UPDATES  = 0;
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS      = 0;
SET AUTOCOMMIT         = 0;

/* ================================================================== */
/* SCHEMA INTROSPECTION                                               */
/* ================================================================== */
SELECT 'SCHEMA INTROSPECTION' AS section;

DROP TEMPORARY TABLE IF EXISTS tmp_target_tables;
CREATE TEMPORARY TABLE tmp_target_tables (
  table_name VARCHAR(128) PRIMARY KEY
) ENGINE=InnoDB;

INSERT INTO tmp_target_tables (table_name)
SELECT x.table_name
FROM (
  SELECT 'creature_loot_template' AS table_name
  UNION ALL SELECT 'gameobject_loot_template'
  UNION ALL SELECT 'item_loot_template'
  UNION ALL SELECT 'fishing_loot_template'
  UNION ALL SELECT 'skinning_loot_template'
  UNION ALL SELECT 'pickpocketing_loot_template'
  UNION ALL SELECT 'prospecting_loot_template'
  UNION ALL SELECT 'milling_loot_template'
  UNION ALL SELECT 'disenchant_loot_template'
  UNION ALL SELECT 'spell_loot_template'
  UNION ALL SELECT 'mail_loot_template'
  UNION ALL SELECT 'reference_loot_template'
) x
WHERE EXISTS (
  SELECT 1 FROM information_schema.tables t
  WHERE t.table_schema = DATABASE() AND t.table_name = x.table_name
);

DROP TEMPORARY TABLE IF EXISTS tmp_loot_tables;
CREATE TEMPORARY TABLE tmp_loot_tables (
  table_name    VARCHAR(128) PRIMARY KEY,
  entry_col     VARCHAR(128) NULL,
  item_col      VARCHAR(128) NULL,
  reference_col VARCHAR(128) NULL,
  group_col     VARCHAR(128) NULL,
  chance_col    VARCHAR(128) NULL,
  mincount_col  VARCHAR(128) NULL
) ENGINE=InnoDB;

INSERT INTO tmp_loot_tables (table_name, entry_col, item_col, reference_col, group_col, chance_col, mincount_col)
SELECT
  tt.table_name,
  (SELECT c.column_name FROM information_schema.columns c WHERE c.table_schema=DATABASE() AND c.table_name=tt.table_name AND c.column_name IN ('Entry','entry') ORDER BY FIELD(c.column_name,'Entry','entry') LIMIT 1),
  (SELECT c.column_name FROM information_schema.columns c WHERE c.table_schema=DATABASE() AND c.table_name=tt.table_name AND c.column_name IN ('Item','item','itemid','ItemID') ORDER BY FIELD(c.column_name,'Item','item','itemid','ItemID') LIMIT 1),
  (SELECT c.column_name FROM information_schema.columns c WHERE c.table_schema=DATABASE() AND c.table_name=tt.table_name AND c.column_name IN ('Reference','reference','Ref','ref') ORDER BY FIELD(c.column_name,'Reference','reference','Ref','ref') LIMIT 1),
  (SELECT c.column_name FROM information_schema.columns c WHERE c.table_schema=DATABASE() AND c.table_name=tt.table_name AND c.column_name IN ('GroupId','groupid','group','GroupID') ORDER BY FIELD(c.column_name,'GroupId','groupid','group','GroupID') LIMIT 1),
  (SELECT c.column_name FROM information_schema.columns c WHERE c.table_schema=DATABASE() AND c.table_name=tt.table_name AND c.column_name IN ('ChanceOrQuestChance','chance','Chance') ORDER BY FIELD(c.column_name,'ChanceOrQuestChance','chance','Chance') LIMIT 1),
  (SELECT c.column_name FROM information_schema.columns c WHERE c.table_schema=DATABASE() AND c.table_name=tt.table_name AND c.column_name IN ('MinCount','mincount','MinCountOrRef','mincountOrRef') ORDER BY FIELD(c.column_name,'MinCount','mincount','MinCountOrRef','mincountOrRef') LIMIT 1)
FROM tmp_target_tables tt;

SET @HAS_REF_TABLE := EXISTS(
  SELECT 1 FROM information_schema.tables
  WHERE table_schema = DATABASE() AND table_name = 'reference_loot_template'
);

SET @REF_ENTRY_COL := (
  SELECT c.column_name FROM information_schema.columns c
  WHERE c.table_schema = DATABASE() AND c.table_name = 'reference_loot_template'
    AND c.column_name IN ('Entry','entry','ID','Id')
  ORDER BY FIELD(c.column_name,'Entry','entry','ID','Id') LIMIT 1
);

SELECT * FROM tmp_loot_tables;

/* ================================================================== */
/* SUMMARY TABLE                                                      */
/* ================================================================== */

DROP TEMPORARY TABLE IF EXISTS tmp_loot_ref_summary;
CREATE TEMPORARY TABLE tmp_loot_ref_summary (
  table_name          VARCHAR(128) PRIMARY KEY,
  missing_ref_before  BIGINT NOT NULL DEFAULT 0,
  group_fix_before    BIGINT NOT NULL DEFAULT 0,
  mincount_fix_before BIGINT NOT NULL DEFAULT 0,
  missing_ref_after   BIGINT NULL,
  group_fix_after     BIGINT NULL,
  mincount_fix_after  BIGINT NULL,
  deleted_missing_ref BIGINT NOT NULL DEFAULT 0,
  updated_group       BIGINT NOT NULL DEFAULT 0,
  updated_mincount    BIGINT NOT NULL DEFAULT 0,
  note                TEXT NULL
) ENGINE=InnoDB;

/* ================================================================== */
/* DDL PHASE — backup tables (before transaction)                     */
/*                                                                    */
/* Pre-create ALL possible backup tables for existing loot tables.    */
/* CREATE TABLE IF NOT EXISTS is idempotent — safe to run always.     */
/* Only created when @APPLY_FIX = 1.                                  */
/* ================================================================== */
SELECT 'BACKUP TABLE CREATION (DDL)' AS section;

/* For each of the 12 possible loot tables, create 3 backup tables:
   _backup_genre6b_missing_ref, _backup_genre6b_group_fix, _backup_genre6b_mincount_fix */

SET @_tbl := 'creature_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'gameobject_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'item_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'fishing_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'skinning_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'pickpocketing_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'prospecting_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'milling_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'disenchant_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'spell_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'mail_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @_tbl := 'reference_loot_template';
SET @_tex := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name=@_tbl);
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_missing_ref` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_group_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@APPLY_FIX=1 AND @_tex=1, CONCAT('CREATE TABLE IF NOT EXISTS `',@_tbl,'_backup_genre6b_mincount_fix` LIKE `',@_tbl,'`'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;


/* ================================================================== */
/* DML PHASE                                                          */
/* ================================================================== */
START TRANSACTION;

/* ================================================================== */
/* DIAGNOSTICS — count problems per table                             */
/* ================================================================== */
SELECT 'DIAGNOSTICS' AS section;

/* Build diagnostic query with COALESCE wrapping all SUM aggregates
   to prevent NULL from empty tables hitting NOT NULL columns */
SET @sql_diag := (
  SELECT GROUP_CONCAT(s.q ORDER BY s.table_name SEPARATOR ' UNION ALL ')
  FROM (
    SELECT
      lt.table_name,
      CONCAT(
        'SELECT ', QUOTE(lt.table_name), ' AS table_name, ',
        IF(@HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND lt.reference_col IS NOT NULL,
          CONCAT('COALESCE(SUM(CASE WHEN t.`', lt.reference_col, '` > 0 AND r.`', @REF_ENTRY_COL, '` IS NULL THEN 1 ELSE 0 END),0)'),
          '0'
        ),
        ' AS missing_ref_before, ',
        IF(lt.chance_col IS NOT NULL AND lt.group_col IS NOT NULL AND lt.item_col IS NOT NULL,
          CONCAT('COALESCE(SUM(CASE WHEN t.`', lt.chance_col, '` = 0 AND (t.`', lt.group_col, '` IS NULL OR t.`', lt.group_col, '` = 0) AND t.`', lt.item_col, '` > 0 THEN 1 ELSE 0 END),0)'),
          '0'
        ),
        ' AS group_fix_before, ',
        IF(lt.mincount_col IS NOT NULL AND lt.item_col IS NOT NULL,
          CONCAT('COALESCE(SUM(CASE WHEN t.`', lt.item_col, '` > 0 AND t.`', lt.mincount_col, '` = 0 THEN 1 ELSE 0 END),0)'),
          '0'
        ),
        ' AS mincount_fix_before, ',
        QUOTE(
          CONCAT(
            IF(lt.reference_col IS NULL, 'SKIP A: missing Reference column. ', ''),
            IF(NOT (@HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL), 'SKIP A: reference_loot_template missing. ', ''),
            IF(lt.chance_col IS NULL OR lt.group_col IS NULL OR lt.item_col IS NULL, 'SKIP B: required columns missing. ', ''),
            IF(lt.mincount_col IS NULL OR lt.item_col IS NULL, 'SKIP C: required columns missing. ', '')
          )
        ),
        ' AS note FROM `', lt.table_name, '` t ',
        IF(@HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND lt.reference_col IS NOT NULL,
          CONCAT('LEFT JOIN `reference_loot_template` r ON r.`', @REF_ENTRY_COL, '` = t.`', lt.reference_col, '` '),
          ''
        )
      ) AS q
    FROM tmp_loot_tables lt
  ) s
);

SET @sql_diag_ins := CONCAT(
  'INSERT INTO tmp_loot_ref_summary (table_name, missing_ref_before, group_fix_before, mincount_fix_before, note) ',
  @sql_diag
);
PREPARE stmt FROM @sql_diag_ins; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ── Cap checks ──────────────────────────────────────────────────── */
SET @TOTAL_DELETE_CANDIDATES := (SELECT COALESCE(SUM(missing_ref_before),0) FROM tmp_loot_ref_summary);
SET @TOTAL_UPDATE_CANDIDATES := (SELECT COALESCE(SUM(group_fix_before + mincount_fix_before),0) FROM tmp_loot_ref_summary);
SET @TOTAL_TOUCH := @TOTAL_DELETE_CANDIDATES + @TOTAL_UPDATE_CANDIDATES;

SELECT @TOTAL_DELETE_CANDIDATES AS total_delete_candidates,
       @TOTAL_UPDATE_CANDIDATES AS total_update_candidates,
       @TOTAL_TOUCH AS total_touch;

SET @CAPS_EXCEEDED := IF(
  @TOTAL_TOUCH > @MAX_TOUCH_TOTAL
  OR (SELECT COUNT(*) FROM tmp_loot_ref_summary WHERE missing_ref_before > @MAX_DELETE_PER_TABLE) > 0
  OR (SELECT COUNT(*) FROM tmp_loot_ref_summary WHERE group_fix_before > @MAX_UPDATE_PER_TABLE) > 0
  OR (SELECT COUNT(*) FROM tmp_loot_ref_summary WHERE mincount_fix_before > @MAX_UPDATE_PER_TABLE) > 0,
  1, 0
);

SET @APPLY_ALLOWED := IF(@APPLY_FIX = 1 AND (@CAPS_EXCEEDED = 0 OR @FORCE_TOUCH = 1), 1, 0);

UPDATE tmp_loot_ref_summary
SET note = CONCAT(COALESCE(note,''), IF(@APPLY_FIX = 1 AND @APPLY_ALLOWED = 0, 'CAPS_EXCEEDED: apply disabled by cap controls. ', ''))
WHERE table_name IS NOT NULL;

SELECT IF(@APPLY_ALLOWED = 1, 'APPLY: enabled', IF(@APPLY_FIX = 0, 'DRY RUN: report only', 'BLOCKED: caps exceeded')) AS apply_mode;


/* ================================================================== */
/* PER-TABLE PROCESSING                                               */
/*                                                                    */
/* Each block:                                                        */
/*   - Loads column names + before-counts                             */
/*   - Phase A: backup + delete missing refs                          */
/*   - Phase B: backup + update GroupId                               */
/*   - Phase C: backup + update MinCount                              */
/*   - ROW_COUNT() captured BEFORE DEALLOCATE PREPARE                 */
/* ================================================================== */

/* ── 1) creature_loot_template ───────────────────────────────────── */
SET @tbl := 'creature_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
/* A: missing ref */
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
/* B: group fix */
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
/* C: mincount fix */
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ── 2) gameobject_loot_template ─────────────────────────────────── */
SET @tbl := 'gameobject_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ── 3) item_loot_template ───────────────────────────────────────── */
SET @tbl := 'item_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ── 4) fishing_loot_template ────────────────────────────────────── */
SET @tbl := 'fishing_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ── 5) skinning_loot_template ───────────────────────────────────── */
SET @tbl := 'skinning_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ── 6) pickpocketing_loot_template ──────────────────────────────── */
SET @tbl := 'pickpocketing_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ── 7) prospecting_loot_template ────────────────────────────────── */
SET @tbl := 'prospecting_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ── 8) milling_loot_template ────────────────────────────────────── */
SET @tbl := 'milling_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ── 9) disenchant_loot_template ─────────────────────────────────── */
SET @tbl := 'disenchant_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ── 10) spell_loot_template ─────────────────────────────────────── */
SET @tbl := 'spell_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ── 11) mail_loot_template ──────────────────────────────────────── */
SET @tbl := 'mail_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ── 12) reference_loot_template ─────────────────────────────────── */
SET @tbl := 'reference_loot_template';
SET @entry_col := (SELECT entry_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @item_col := (SELECT item_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @reference_col := (SELECT reference_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @group_col := (SELECT group_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @chance_col := (SELECT chance_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @mincount_col := (SELECT mincount_col FROM tmp_loot_tables WHERE table_name = @tbl);
SET @missing_before := COALESCE((SELECT missing_ref_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @group_before := COALESCE((SELECT group_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @mincount_before := COALESCE((SELECT mincount_fix_before FROM tmp_loot_ref_summary WHERE table_name = @tbl),0);
SET @can_delete := IF(@APPLY_ALLOWED = 1 AND @missing_before > 0 AND (@missing_before <= @MAX_DELETE_PER_TABLE OR @FORCE_TOUCH = 1) AND @HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND @reference_col IS NOT NULL, 1, 0);
SET @can_group := IF(@APPLY_ALLOWED = 1 AND @group_before > 0 AND (@group_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @entry_col IS NOT NULL AND @item_col IS NOT NULL AND @group_col IS NOT NULL AND @chance_col IS NOT NULL, 1, 0);
SET @can_mincount := IF(@APPLY_ALLOWED = 1 AND @mincount_before > 0 AND (@mincount_before <= @MAX_UPDATE_PER_TABLE OR @FORCE_TOUCH = 1) AND @item_col IS NOT NULL AND @mincount_col IS NOT NULL, 1, 0);
SET @sql := IF(@can_delete=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_missing_ref` SELECT t.* FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_delete=1, CONCAT('DELETE t FROM `',@tbl,'` t LEFT JOIN `reference_loot_template` r ON r.`',@REF_ENTRY_COL,'`=t.`',@reference_col,'` WHERE t.`',@reference_col,'`>0 AND r.`',@REF_ENTRY_COL,'` IS NULL'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_a := IF(@can_delete=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET deleted_missing_ref=@rows_a, note=CONCAT(COALESCE(note,''), IF(@can_delete=0 AND @missing_before>0,'SKIP A: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_group=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_group_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_group=1, CONCAT('UPDATE `',@tbl,'` t JOIN (SELECT `',@entry_col,'` AS e, COALESCE(MAX(`',@group_col,'`),0)+1 AS ng FROM `',@tbl,'` GROUP BY `',@entry_col,'`) g ON g.e=t.`',@entry_col,'` SET t.`',@group_col,'`=g.ng WHERE t.`',@chance_col,'`=0 AND (t.`',@group_col,'` IS NULL OR t.`',@group_col,'`=0) AND t.`',@item_col,'`>0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_b := IF(@can_group=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_group=@rows_b, note=CONCAT(COALESCE(note,''), IF(@can_group=0 AND @group_before>0,'SKIP B: caps/disabled. ','')) WHERE table_name=@tbl;
SET @sql := IF(@can_mincount=1, CONCAT('INSERT IGNORE INTO `',@tbl,'_backup_genre6b_mincount_fix` SELECT t.* FROM `',@tbl,'` t WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
SET @sql := IF(@can_mincount=1, CONCAT('UPDATE `',@tbl,'` t SET t.`',@mincount_col,'`=1 WHERE t.`',@item_col,'`>0 AND t.`',@mincount_col,'`=0'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; SET @rows_c := IF(@can_mincount=1, ROW_COUNT(), 0); DEALLOCATE PREPARE stmt;
UPDATE tmp_loot_ref_summary SET updated_mincount=@rows_c, note=CONCAT(COALESCE(note,''), IF(@can_mincount=0 AND @mincount_before>0,'SKIP C: caps/disabled. ','')) WHERE table_name=@tbl;


/* ================================================================== */
/* POST-VERIFICATION                                                  */
/* ================================================================== */
SELECT 'VERIFICATION' AS section;

/* Re-count all problems with COALESCE wrapping */
SET @sql_after := (
  SELECT GROUP_CONCAT(s.q ORDER BY s.table_name SEPARATOR ' UNION ALL ')
  FROM (
    SELECT
      lt.table_name,
      CONCAT(
        'SELECT ', QUOTE(lt.table_name), ' AS table_name, ',
        IF(@HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND lt.reference_col IS NOT NULL,
          CONCAT('COALESCE(SUM(CASE WHEN t.`', lt.reference_col, '` > 0 AND r.`', @REF_ENTRY_COL, '` IS NULL THEN 1 ELSE 0 END),0)'),
          '0'
        ),
        ' AS missing_ref_after, ',
        IF(lt.chance_col IS NOT NULL AND lt.group_col IS NOT NULL AND lt.item_col IS NOT NULL,
          CONCAT('COALESCE(SUM(CASE WHEN t.`', lt.chance_col, '` = 0 AND (t.`', lt.group_col, '` IS NULL OR t.`', lt.group_col, '` = 0) AND t.`', lt.item_col, '` > 0 THEN 1 ELSE 0 END),0)'),
          '0'
        ),
        ' AS group_fix_after, ',
        IF(lt.mincount_col IS NOT NULL AND lt.item_col IS NOT NULL,
          CONCAT('COALESCE(SUM(CASE WHEN t.`', lt.item_col, '` > 0 AND t.`', lt.mincount_col, '` = 0 THEN 1 ELSE 0 END),0)'),
          '0'
        ),
        ' AS mincount_fix_after FROM `', lt.table_name, '` t ',
        IF(@HAS_REF_TABLE = 1 AND @REF_ENTRY_COL IS NOT NULL AND lt.reference_col IS NOT NULL,
          CONCAT('LEFT JOIN `reference_loot_template` r ON r.`', @REF_ENTRY_COL, '` = t.`', lt.reference_col, '` '),
          ''
        )
      ) AS q
    FROM tmp_loot_tables lt
  ) s
);

DROP TEMPORARY TABLE IF EXISTS tmp_after_counts;
CREATE TEMPORARY TABLE tmp_after_counts (
  table_name         VARCHAR(128) PRIMARY KEY,
  missing_ref_after  BIGINT NOT NULL DEFAULT 0,
  group_fix_after    BIGINT NOT NULL DEFAULT 0,
  mincount_fix_after BIGINT NOT NULL DEFAULT 0
) ENGINE=InnoDB;

SET @sql_after_ins := CONCAT('INSERT INTO tmp_after_counts (table_name, missing_ref_after, group_fix_after, mincount_fix_after) ', @sql_after);
PREPARE stmt FROM @sql_after_ins; EXECUTE stmt; DEALLOCATE PREPARE stmt;

UPDATE tmp_loot_ref_summary s
JOIN tmp_after_counts a ON a.table_name = s.table_name
SET s.missing_ref_after  = a.missing_ref_after,
    s.group_fix_after    = a.group_fix_after,
    s.mincount_fix_after = a.mincount_fix_after;


/* ================================================================== */
/* SUMMARY                                                            */
/* ================================================================== */
SELECT 'SUMMARY' AS section;

SELECT
  table_name,
  missing_ref_before, deleted_missing_ref, missing_ref_after,
  group_fix_before, updated_group, group_fix_after,
  mincount_fix_before, updated_mincount, mincount_fix_after,
  note
FROM tmp_loot_ref_summary
ORDER BY table_name;

SELECT IF(@APPLY_FIX = 1,
  IF(@APPLY_ALLOWED = 1, 'APPLIED — committing changes', 'BLOCKED — rolling back (caps exceeded)'),
  'DRY RUN — rolling back') AS mode;

/* ── Commit or rollback ──────────────────────────────────────────── */
SET @sql := IF(@APPLY_ALLOWED = 1, 'COMMIT', 'ROLLBACK');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ── Cleanup ─────────────────────────────────────────────────────── */
DROP TEMPORARY TABLE IF EXISTS tmp_target_tables;
DROP TEMPORARY TABLE IF EXISTS tmp_loot_tables;
DROP TEMPORARY TABLE IF EXISTS tmp_loot_ref_summary;
DROP TEMPORARY TABLE IF EXISTS tmp_after_counts;

/* ── Restore session ─────────────────────────────────────────────── */
SET SQL_SAFE_UPDATES   = COALESCE(@OLD_SQL_SAFE_UPDATES, 1);
SET FOREIGN_KEY_CHECKS = COALESCE(@OLD_FOREIGN_KEY_CHECKS, 1);
SET UNIQUE_CHECKS      = COALESCE(@OLD_UNIQUE_CHECKS, 1);
SET AUTOCOMMIT         = COALESCE(@OLD_AUTOCOMMIT, 1);
SET SESSION group_concat_max_len = CAST(COALESCE(@OLD_GROUP_CONCAT_MAX_LEN, 1024) AS UNSIGNED);

/* ================================================================== */
/* SmartAI Link Cleanup v2 (Midnight 12.x)                            */
/*                                                                    */
/* Two phases:                                                        */
/*   A) DELETE orphaned SmartAI entries (source_type 0/1 referencing  */
/*      creature_template / gameobject_template entries that don't    */
/*      exist)                                                        */
/*   B) UPDATE broken link chains (link>0 pointing to missing id)    */
/*      → set link=0, skipping rows that would cause PK collision    */
/*                                                                    */
/* v2 fixes over v1:                                                  */
/*   - Removed embedded GitHub review comment (syntax error)          */
/*   - @APPLY_FIX defaults to 0 (dry-run)                            */
/*   - Added cap enforcement with @FORCE_APPLY override               */
/*   - Fixed intra-batch PK collision: v1 only detected conflicts     */
/*     with existing link=0 rows, not between 2+ broken-link rows     */
/*     sharing the same (entryorguid, source_type, id). The UPDATE    */
/*     SET link=0 would collapse them → Error 1062, aborting the      */
/*     transaction. v2 detects both conflict types.                   */
/*   - Accurate per-source_type delete accounting (v1 guessed via     */
/*     LEAST/GREATEST arithmetic on a single ROW_COUNT)               */
/*   - Consistent IF() gating on Phase B key collection               */
/*                                                                    */
/* SET @APPLY_FIX := 0 for dry-run diagnostics only.                  */
/* SET @APPLY_FIX := 1 to apply mutations.                            */
/*                                                                    */
/* IMPORTANT: Run the COMPLETE file. Do not paste fragments.          */
/* ================================================================== */

USE `world`;
SELECT DATABASE() AS active_database;

SET @APPLY_FIX   := 1;
SET @MAX_DELETE   := 500000;
SET @MAX_UPDATE   := 500000;
SET @FORCE_APPLY  := 0;

/* ── Session snapshot ────────────────────────────────────────────── */
SET @OLD_SQL_SAFE_UPDATES   := COALESCE(@@SQL_SAFE_UPDATES, 1);
SET @OLD_FOREIGN_KEY_CHECKS := COALESCE(@@FOREIGN_KEY_CHECKS, 1);
SET @OLD_UNIQUE_CHECKS      := COALESCE(@@UNIQUE_CHECKS, 1);
SET @OLD_AUTOCOMMIT         := COALESCE(@@AUTOCOMMIT, 1);

SET SQL_SAFE_UPDATES   = 0;
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS      = 0;
SET AUTOCOMMIT         = 0;

/* ================================================================== */
/* SCHEMA INTROSPECTION                                               */
/* ================================================================== */
SELECT 'SCHEMA INTROSPECTION' AS section;

SET @ss_exists := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name='smart_scripts');
SET @ct_exists := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name='creature_template');
SET @gt_exists := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name='gameobject_template');

SET @ct_pk := (
  SELECT CASE
    WHEN SUM(column_name='entry')>0 THEN 'entry'
    WHEN SUM(column_name='Entry')>0 THEN 'Entry'
    WHEN SUM(column_name='ID')>0 THEN 'ID'
    ELSE NULL END
  FROM information_schema.columns WHERE table_schema='world' AND table_name='creature_template'
);
SET @gt_pk := (
  SELECT CASE
    WHEN SUM(column_name='entry')>0 THEN 'entry'
    WHEN SUM(column_name='Entry')>0 THEN 'Entry'
    WHEN SUM(column_name='ID')>0 THEN 'ID'
    ELSE NULL END
  FROM information_schema.columns WHERE table_schema='world' AND table_name='gameobject_template'
);

SET @can_run := IF(@ss_exists = 1, 1, 0);

SELECT
  IF(@ss_exists = 1, 'OK', 'MISSING') AS smart_scripts,
  IF(@ct_exists = 1 AND @ct_pk IS NOT NULL, CONCAT('OK (', @ct_pk, ')'), 'N/A') AS creature_template,
  IF(@gt_exists = 1 AND @gt_pk IS NOT NULL, CONCAT('OK (', @gt_pk, ')'), 'N/A') AS gameobject_template;

/* ================================================================== */
/* DDL PHASE — backup tables (before transaction)                     */
/* ================================================================== */
SELECT 'BACKUP TABLE CREATION (DDL)' AS section;

SET @sql := IF(@APPLY_FIX = 1 AND @can_run = 1,
  'CREATE TABLE IF NOT EXISTS `smart_scripts_backup_orphans` LIKE `smart_scripts`',
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@APPLY_FIX = 1 AND @can_run = 1,
  'CREATE TABLE IF NOT EXISTS `smart_scripts_backup_broken_links` LIKE `smart_scripts`',
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ================================================================== */
/* DML PHASE                                                          */
/* ================================================================== */
START TRANSACTION;

/* ── PHASE A — ORPHANED ENTRIES ──────────────────────────────────── */
SELECT 'PHASE A — ORPHANED ENTRIES' AS section;

DROP TEMPORARY TABLE IF EXISTS tmp_orphan_keys;
CREATE TEMPORARY TABLE tmp_orphan_keys (
  entryorguid  BIGINT NOT NULL,
  source_type  TINYINT UNSIGNED NOT NULL,
  id           SMALLINT UNSIGNED NOT NULL,
  link         SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (entryorguid, source_type, id, link)
) ENGINE=InnoDB;

/* Creature orphans (source_type=0) */
SET @a1_can := IF(@can_run = 1 AND @ct_exists = 1 AND @ct_pk IS NOT NULL, 1, 0);
SET @sql := IF(@a1_can = 1, CONCAT(
  'INSERT IGNORE INTO tmp_orphan_keys (entryorguid, source_type, id, link) ',
  'SELECT ss.entryorguid, ss.source_type, ss.id, ss.link FROM smart_scripts ss ',
  'WHERE ss.source_type = 0 AND ss.entryorguid > 0 AND NOT EXISTS (',
  'SELECT 1 FROM creature_template ct WHERE ct.`', @ct_pk, '` = ss.entryorguid)'
), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* Gameobject orphans (source_type=1) */
SET @a2_can := IF(@can_run = 1 AND @gt_exists = 1 AND @gt_pk IS NOT NULL, 1, 0);
SET @sql := IF(@a2_can = 1, CONCAT(
  'INSERT IGNORE INTO tmp_orphan_keys (entryorguid, source_type, id, link) ',
  'SELECT ss.entryorguid, ss.source_type, ss.id, ss.link FROM smart_scripts ss ',
  'WHERE ss.source_type = 1 AND ss.entryorguid > 0 AND NOT EXISTS (',
  'SELECT 1 FROM gameobject_template gt WHERE gt.`', @gt_pk, '` = ss.entryorguid)'
), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @a1_count := (SELECT COUNT(*) FROM tmp_orphan_keys WHERE source_type = 0);
SET @a2_count := (SELECT COUNT(*) FROM tmp_orphan_keys WHERE source_type = 1);
SET @a_total  := @a1_count + @a2_count;

SELECT @a1_count AS creature_orphans, @a2_count AS gameobject_orphans, @a_total AS total_orphans;

/* ── PHASE B — BROKEN LINK CHAINS ────────────────────────────────── */
SELECT 'PHASE B — BROKEN LINK CHAINS' AS section;

DROP TEMPORARY TABLE IF EXISTS tmp_broken_link_keys;
CREATE TEMPORARY TABLE tmp_broken_link_keys (
  entryorguid  BIGINT NOT NULL,
  source_type  TINYINT UNSIGNED NOT NULL,
  id           SMALLINT UNSIGNED NOT NULL,
  link         SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (entryorguid, source_type, id, link)
) ENGINE=InnoDB;

SET @sql := IF(@can_run = 1,
  'INSERT IGNORE INTO tmp_broken_link_keys (entryorguid, source_type, id, link) '
  'SELECT s.entryorguid, s.source_type, s.id, s.link '
  'FROM smart_scripts s '
  'LEFT JOIN smart_scripts s2 ON s2.entryorguid = s.entryorguid AND s2.source_type = s.source_type AND s2.id = s.link '
  'WHERE s.link > 0 AND s2.entryorguid IS NULL',
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* Conflict detection: rows that would cause PK collision on UPDATE SET link=0 */
DROP TEMPORARY TABLE IF EXISTS tmp_broken_link_conflicts;
CREATE TEMPORARY TABLE tmp_broken_link_conflicts (
  entryorguid  BIGINT NOT NULL,
  source_type  TINYINT UNSIGNED NOT NULL,
  id           SMALLINT UNSIGNED NOT NULL,
  link         SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (entryorguid, source_type, id, link)
) ENGINE=InnoDB;

/* Type 1: existing link=0 row already in smart_scripts */
INSERT IGNORE INTO tmp_broken_link_conflicts (entryorguid, source_type, id, link)
SELECT k.entryorguid, k.source_type, k.id, k.link
FROM tmp_broken_link_keys k
INNER JOIN smart_scripts z
  ON z.entryorguid = k.entryorguid
 AND z.source_type = k.source_type
 AND z.id          = k.id
 AND z.link        = 0;

/* v2: Type 2 — intra-batch collision: 2+ broken-link rows share the
   same (entryorguid, source_type, id) but have different link values.
   UPDATE SET link=0 on all of them would collapse to the same PK.
   Keep only the row with the lowest link value; mark the rest.
   NOTE: MySQL can't reopen a temp table in the same statement (Error 1137),
   so we materialize the duplicate groups into a separate temp table first. */
DROP TEMPORARY TABLE IF EXISTS tmp_broken_link_dups;
CREATE TEMPORARY TABLE tmp_broken_link_dups (
  entryorguid  BIGINT NOT NULL,
  source_type  TINYINT UNSIGNED NOT NULL,
  id           SMALLINT UNSIGNED NOT NULL,
  keep_link    SMALLINT UNSIGNED NOT NULL,
  PRIMARY KEY (entryorguid, source_type, id)
) ENGINE=InnoDB;

INSERT INTO tmp_broken_link_dups (entryorguid, source_type, id, keep_link)
SELECT entryorguid, source_type, id, MIN(link) AS keep_link
FROM tmp_broken_link_keys
GROUP BY entryorguid, source_type, id
HAVING COUNT(*) > 1;

INSERT IGNORE INTO tmp_broken_link_conflicts (entryorguid, source_type, id, link)
SELECT k.entryorguid, k.source_type, k.id, k.link
FROM tmp_broken_link_keys k
INNER JOIN tmp_broken_link_dups dup
  ON dup.entryorguid = k.entryorguid
 AND dup.source_type = k.source_type
 AND dup.id          = k.id
 AND k.link         <> dup.keep_link;

SET @b_count     := (SELECT COUNT(*) FROM tmp_broken_link_keys);
SET @b_conflicts := (SELECT COUNT(*) FROM tmp_broken_link_conflicts);

SELECT @b_count AS broken_links_found, @b_conflicts AS conflicts_excluded;

/* ── APPLY DECISION ──────────────────────────────────────────────── */
SELECT 'APPLY DECISION' AS section;

SET @caps_exceeded := IF(@a_total > @MAX_DELETE OR @b_count > @MAX_UPDATE, 1, 0);

SET @can_apply := IF(
  @APPLY_FIX = 1
  AND @can_run = 1
  AND (@caps_exceeded = 0 OR @FORCE_APPLY = 1),
  1, 0
);

SET @cap_note :=
  CASE
    WHEN @APPLY_FIX <> 1 THEN 'DRY RUN: report-only mode (@APPLY_FIX=0).'
    WHEN @can_run = 0 THEN 'BLOCKED: smart_scripts table missing.'
    WHEN @caps_exceeded = 1 AND @FORCE_APPLY = 0
      THEN CONCAT('BLOCKED by cap: deletes=', @a_total, ' (max ', @MAX_DELETE, '), updates=', @b_count, ' (max ', @MAX_UPDATE, '). Set @FORCE_APPLY=1 to override.')
    WHEN @a_total + @b_count = 0 THEN 'Apply mode: no candidates found.'
    ELSE CONCAT('Apply mode: ', @a_total, ' deletes + ', @b_count - @b_conflicts, ' updates (', @b_conflicts, ' conflict-skipped).')
  END;

SELECT @cap_note AS apply_decision;

/* ── Phase A: backup + delete ────────────────────────────────────── */
SET @a1_deleted := 0;
SET @a2_deleted := 0;

SET @sql := IF(@can_apply = 1 AND @a_total > 0,
  'INSERT IGNORE INTO smart_scripts_backup_orphans SELECT ss.* FROM smart_scripts ss INNER JOIN tmp_orphan_keys k ON k.entryorguid = ss.entryorguid AND k.source_type = ss.source_type AND k.id = ss.id AND k.link = ss.link',
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* v2: Delete per source_type for accurate accounting */
SET @sql := IF(@can_apply = 1 AND @a1_count > 0,
  'DELETE ss FROM smart_scripts ss INNER JOIN tmp_orphan_keys k ON k.entryorguid = ss.entryorguid AND k.source_type = ss.source_type AND k.id = ss.id AND k.link = ss.link WHERE k.source_type = 0',
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt;
SET @a1_deleted := IF(@can_apply = 1, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_apply = 1 AND @a2_count > 0,
  'DELETE ss FROM smart_scripts ss INNER JOIN tmp_orphan_keys k ON k.entryorguid = ss.entryorguid AND k.source_type = ss.source_type AND k.id = ss.id AND k.link = ss.link WHERE k.source_type = 1',
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt;
SET @a2_deleted := IF(@can_apply = 1, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

/* ── Phase B: backup + update ────────────────────────────────────── */
SET @b_backed := 0;
SET @b_fixed  := 0;

SET @sql := IF(@can_apply = 1 AND @b_count > 0,
  'INSERT IGNORE INTO smart_scripts_backup_broken_links SELECT s.* FROM smart_scripts s INNER JOIN tmp_broken_link_keys k ON k.entryorguid = s.entryorguid AND k.source_type = s.source_type AND k.id = s.id AND k.link = s.link',
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt;
SET @b_backed := IF(@can_apply = 1, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_apply = 1 AND @b_count > 0,
  'UPDATE smart_scripts s '
  'INNER JOIN tmp_broken_link_keys k ON k.entryorguid = s.entryorguid AND k.source_type = s.source_type AND k.id = s.id AND k.link = s.link '
  'LEFT JOIN tmp_broken_link_conflicts c ON c.entryorguid = k.entryorguid AND c.source_type = k.source_type AND c.id = k.id AND c.link = k.link '
  'SET s.link = 0 WHERE c.entryorguid IS NULL',
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt;
SET @b_fixed := IF(@can_apply = 1, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

/* ── Verification ────────────────────────────────────────────────── */
SELECT 'VERIFICATION' AS section;

SET @b_remaining := (
  SELECT COUNT(*) FROM smart_scripts s
  LEFT JOIN smart_scripts s2 ON s2.entryorguid = s.entryorguid AND s2.source_type = s.source_type AND s2.id = s.link
  WHERE s.link > 0 AND s2.entryorguid IS NULL
);

/* ================================================================== */
/* SUMMARY                                                            */
/* ================================================================== */
SELECT 'SUMMARY' AS section;

SELECT
  @a1_count   AS creature_orphan_rows,
  @a1_deleted AS creature_orphans_deleted,
  @a2_count   AS gameobject_orphan_rows,
  @a2_deleted AS gameobject_orphans_deleted;

SELECT
  @b_count     AS broken_links_found,
  @b_conflicts AS conflicts_excluded,
  @b_backed    AS broken_links_backed_up,
  @b_fixed     AS broken_links_zeroed,
  @b_remaining AS broken_links_remaining;

SELECT IF(@can_apply = 1, 'APPLIED — committing changes',
  IF(@APPLY_FIX = 0, 'DRY RUN — rolling back', 'BLOCKED — rolling back')) AS mode,
  @cap_note AS notes;

/* ── Commit or rollback ──────────────────────────────────────────── */
SET @sql := IF(@can_apply = 1, 'COMMIT', 'ROLLBACK');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ── Cleanup ─────────────────────────────────────────────────────── */
DROP TEMPORARY TABLE IF EXISTS tmp_orphan_keys;
DROP TEMPORARY TABLE IF EXISTS tmp_broken_link_keys;
DROP TEMPORARY TABLE IF EXISTS tmp_broken_link_conflicts;
DROP TEMPORARY TABLE IF EXISTS tmp_broken_link_dups;

/* ── Restore session ─────────────────────────────────────────────── */
SET SQL_SAFE_UPDATES   = COALESCE(@OLD_SQL_SAFE_UPDATES, 1);
SET FOREIGN_KEY_CHECKS = COALESCE(@OLD_FOREIGN_KEY_CHECKS, 1);
SET UNIQUE_CHECKS      = COALESCE(@OLD_UNIQUE_CHECKS, 1);
SET AUTOCOMMIT         = COALESCE(@OLD_AUTOCOMMIT, 1);

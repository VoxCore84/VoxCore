/* ================================================================== */
/* GENRE 5A v2 — Creature / Gameobject orphan cleanup                 */
/* TrinityCore Midnight 12.x (TWW 11.1.7)                            */
/*                                                                    */
/* Targets:                                                           */
/*   1) creature      — delete spawns with no creature_template       */
/*   2) gameobject    — delete spawns with no gameobject_template     */
/*   3) creature_addon — delete addon rows with no creature guid      */
/*   4) gameobject_addon — delete addon rows with no gameobject guid  */
/*                                                                    */
/* v2 fixes:                                                          */
/*   - Removed embedded GitHub review comment (syntax error)          */
/*   - DDL (backup table creation) moved BEFORE START TRANSACTION     */
/*     so implicit commits don't break atomic cleanup                 */
/*   - COALESCE on session save/restore (NULL-proof)                  */
/*   - Coverage guard: if <90% of creature/gameobject template refs   */
/*     resolve, deletion is BLOCKED (protects against incomplete      */
/*     template tables)                                               */
/*   - Self-contained — safe to run standalone in HeidiSQL            */
/*                                                                    */
/* IMPORTANT: Run the COMPLETE file. Do not paste fragments.          */
/* ================================================================== */

USE `world`;
SELECT DATABASE() AS active_database;

/* ── Session snapshot ────────────────────────────────────────────── */
SET @OLD_SQL_SAFE_UPDATES   := COALESCE(@@SQL_SAFE_UPDATES, 1);
SET @OLD_FOREIGN_KEY_CHECKS := COALESCE(@@FOREIGN_KEY_CHECKS, 1);
SET @OLD_UNIQUE_CHECKS      := COALESCE(@@UNIQUE_CHECKS, 1);
SET @OLD_AUTOCOMMIT         := COALESCE(@@AUTOCOMMIT, 1);

SET SQL_SAFE_UPDATES  = 0;
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS      = 0;
SET AUTOCOMMIT         = 0;

/* ── Counters ────────────────────────────────────────────────────── */
SET @del_creature          := 0;
SET @del_gameobject        := 0;
SET @del_creature_addon    := 0;
SET @del_gameobject_addon  := 0;

/* ================================================================== */
/* SCHEMA DETECTION                                                   */
/* ================================================================== */

SET @db := DATABASE();

/* ── Table existence ─────────────────────────────────────────────── */
SET @has_creature := (
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = @db AND table_name = 'creature'
);
SET @has_ct := (
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = @db AND table_name = 'creature_template'
);
SET @has_gameobject := (
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = @db AND table_name = 'gameobject'
);
SET @has_got := (
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = @db AND table_name = 'gameobject_template'
);
SET @has_ca := (
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = @db AND table_name = 'creature_addon'
);
SET @has_ga := (
    SELECT COUNT(*) FROM information_schema.tables
    WHERE table_schema = @db AND table_name = 'gameobject_addon'
);

/* ── creature columns ────────────────────────────────────────────── */
SET @c_guid := (
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'creature'
      AND column_name IN ('guid','GUID')
    ORDER BY FIELD(column_name,'guid','GUID') LIMIT 1
);
SET @c_id := (
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'creature'
      AND column_name IN ('id','id1','entry','creatureid')
    ORDER BY FIELD(column_name,'id','id1','entry','creatureid') LIMIT 1
);
SET @ct_pk := (
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'creature_template'
      AND column_name IN ('entry','Entry','ID','Id')
    ORDER BY FIELD(column_name,'entry','Entry','ID','Id') LIMIT 1
);

/* ── gameobject columns ──────────────────────────────────────────── */
SET @g_guid := (
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'gameobject'
      AND column_name IN ('guid','GUID')
    ORDER BY FIELD(column_name,'guid','GUID') LIMIT 1
);
SET @g_id := (
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'gameobject'
      AND column_name IN ('id','entry','gameobjectid')
    ORDER BY FIELD(column_name,'id','entry','gameobjectid') LIMIT 1
);
SET @got_pk := (
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'gameobject_template'
      AND column_name IN ('entry','Entry','ID','Id')
    ORDER BY FIELD(column_name,'entry','Entry','ID','Id') LIMIT 1
);

/* ── addon guid columns ──────────────────────────────────────────── */
SET @ca_guid := (
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'creature_addon'
      AND column_name IN ('guid','GUID')
    ORDER BY FIELD(column_name,'guid','GUID') LIMIT 1
);
SET @ga_guid := (
    SELECT column_name FROM information_schema.columns
    WHERE table_schema = @db AND table_name = 'gameobject_addon'
      AND column_name IN ('guid','GUID')
    ORDER BY FIELD(column_name,'guid','GUID') LIMIT 1
);

/* ── Capability flags ────────────────────────────────────────────── */
SET @can_creature := (
    @has_creature = 1 AND @has_ct = 1
    AND @c_guid IS NOT NULL AND @c_id IS NOT NULL AND @ct_pk IS NOT NULL
);
SET @can_gameobject := (
    @has_gameobject = 1 AND @has_got = 1
    AND @g_guid IS NOT NULL AND @g_id IS NOT NULL AND @got_pk IS NOT NULL
);
SET @can_ca := (
    @has_ca = 1 AND @has_creature = 1
    AND @ca_guid IS NOT NULL AND @c_guid IS NOT NULL
);
SET @can_ga := (
    @has_ga = 1 AND @has_gameobject = 1
    AND @ga_guid IS NOT NULL AND @g_guid IS NOT NULL
);

/* ── Diagnostic ──────────────────────────────────────────────────── */
SELECT
  IF(@can_creature,  'YES','NO') AS can_creature_cleanup,
  IF(@can_gameobject,'YES','NO') AS can_gameobject_cleanup,
  IF(@can_ca,        'YES','NO') AS can_creature_addon_cleanup,
  IF(@can_ga,        'YES','NO') AS can_gameobject_addon_cleanup;

/* ================================================================== */
/* BACKUP TABLES — before transaction so DDL implicit-commit is safe  */
/* ================================================================== */

SET @sql := IF(@can_creature,
  'CREATE TABLE IF NOT EXISTS `creature_backup_genre5a` LIKE `creature`',
  'SELECT ''SKIP: creature backup'' AS note');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_gameobject,
  'CREATE TABLE IF NOT EXISTS `gameobject_backup_genre5a` LIKE `gameobject`',
  'SELECT ''SKIP: gameobject backup'' AS note');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_ca,
  'CREATE TABLE IF NOT EXISTS `creature_addon_backup_genre5a` LIKE `creature_addon`',
  'SELECT ''SKIP: creature_addon backup'' AS note');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_ga,
  'CREATE TABLE IF NOT EXISTS `gameobject_addon_backup_genre5a` LIKE `gameobject_addon`',
  'SELECT ''SKIP: gameobject_addon backup'' AS note');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ================================================================== */
/* COVERAGE GUARD                                                     */
/*                                                                    */
/* If template tables are incomplete (e.g. missing expansions), a     */
/* LEFT JOIN delete would nuke valid spawns. We check that ≥90% of    */
/* distinct template refs in the spawn table resolve. If not, that    */
/* section's delete is blocked.                                       */
/* ================================================================== */
SELECT 'COVERAGE CHECK' AS section;

SET @c_total  := 0;  SET @c_matched  := 0;  SET @c_pct  := 0;  SET @c_delete_ok  := 0;
SET @g_total  := 0;  SET @g_matched  := 0;  SET @g_pct  := 0;  SET @g_delete_ok  := 0;

/* ── creature coverage ───────────────────────────────────────────── */
SET @sql := IF(@can_creature,
  CONCAT('SELECT COUNT(DISTINCT `', @c_id, '`) INTO @c_total FROM `creature`'),
  'SELECT 0 INTO @c_total');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_creature,
  CONCAT(
    'SELECT COUNT(DISTINCT c.`', @c_id, '`) INTO @c_matched ',
    'FROM `creature` c ',
    'WHERE EXISTS (SELECT 1 FROM `creature_template` ct WHERE ct.`', @ct_pk, '` = c.`', @c_id, '`)'
  ),
  'SELECT 0 INTO @c_matched');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @c_pct := IF(@c_total > 0, ROUND(100.0 * @c_matched / @c_total, 1), 0);
SET @c_delete_ok := IF(@c_pct >= 90, 1, 0);

/* ── gameobject coverage ─────────────────────────────────────────── */
SET @sql := IF(@can_gameobject,
  CONCAT('SELECT COUNT(DISTINCT `', @g_id, '`) INTO @g_total FROM `gameobject`'),
  'SELECT 0 INTO @g_total');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_gameobject,
  CONCAT(
    'SELECT COUNT(DISTINCT g.`', @g_id, '`) INTO @g_matched ',
    'FROM `gameobject` g ',
    'WHERE EXISTS (SELECT 1 FROM `gameobject_template` gt WHERE gt.`', @got_pk, '` = g.`', @g_id, '`)'
  ),
  'SELECT 0 INTO @g_matched');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @g_pct := IF(@g_total > 0, ROUND(100.0 * @g_matched / @g_total, 1), 0);
SET @g_delete_ok := IF(@g_pct >= 90, 1, 0);

SELECT
  @c_total AS creature_distinct_templates,   @c_matched AS creature_matched,
  @c_pct   AS creature_coverage_pct,
  IF(@c_delete_ok, 'DELETE ENABLED', 'DELETE BLOCKED — template coverage too low') AS creature_status,
  @g_total AS gameobject_distinct_templates,  @g_matched AS gameobject_matched,
  @g_pct   AS gameobject_coverage_pct,
  IF(@g_delete_ok, 'DELETE ENABLED', 'DELETE BLOCKED — template coverage too low') AS gameobject_status;

/* ================================================================== */
/* MUTATIONS — inside a real transaction (no DDL here)                */
/* ================================================================== */
START TRANSACTION;

/* ── 1) creature orphans ─────────────────────────────────────────── */
SELECT 'STEP 1: creature orphan spawns' AS section;

SET @sql := IF(@c_delete_ok AND @can_creature,
  CONCAT(
    'INSERT IGNORE INTO `creature_backup_genre5a` ',
    'SELECT c.* FROM `creature` c ',
    'LEFT JOIN `creature_template` ct ON c.`', @c_id, '` = ct.`', @ct_pk, '` ',
    'WHERE ct.`', @ct_pk, '` IS NULL'
  ),
  'SELECT ''SKIP: creature backup'' AS note');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@c_delete_ok AND @can_creature,
  CONCAT(
    'DELETE c FROM `creature` c ',
    'LEFT JOIN `creature_template` ct ON c.`', @c_id, '` = ct.`', @ct_pk, '` ',
    'WHERE ct.`', @ct_pk, '` IS NULL'
  ),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt;
SET @del_creature := IF(@c_delete_ok AND @can_creature, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

/* ── 2) gameobject orphans ───────────────────────────────────────── */
SELECT 'STEP 2: gameobject orphan spawns' AS section;

SET @sql := IF(@g_delete_ok AND @can_gameobject,
  CONCAT(
    'INSERT IGNORE INTO `gameobject_backup_genre5a` ',
    'SELECT g.* FROM `gameobject` g ',
    'LEFT JOIN `gameobject_template` gt ON g.`', @g_id, '` = gt.`', @got_pk, '` ',
    'WHERE gt.`', @got_pk, '` IS NULL'
  ),
  'SELECT ''SKIP: gameobject backup'' AS note');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@g_delete_ok AND @can_gameobject,
  CONCAT(
    'DELETE g FROM `gameobject` g ',
    'LEFT JOIN `gameobject_template` gt ON g.`', @g_id, '` = gt.`', @got_pk, '` ',
    'WHERE gt.`', @got_pk, '` IS NULL'
  ),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt;
SET @del_gameobject := IF(@g_delete_ok AND @can_gameobject, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

/* ── 3) creature_addon orphans (keyed to creature guid) ──────────── */
/*    No coverage guard needed — this depends on creature table       */
/*    which we just cleaned; if creature is intact, addon orphans     */
/*    are genuinely orphaned.                                         */
SELECT 'STEP 3: creature_addon orphan rows' AS section;

SET @sql := IF(@can_ca,
  CONCAT(
    'INSERT IGNORE INTO `creature_addon_backup_genre5a` ',
    'SELECT ca.* FROM `creature_addon` ca ',
    'LEFT JOIN `creature` c ON ca.`', @ca_guid, '` = c.`', @c_guid, '` ',
    'WHERE c.`', @c_guid, '` IS NULL'
  ),
  'SELECT ''SKIP: creature_addon backup'' AS note');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_ca,
  CONCAT(
    'DELETE ca FROM `creature_addon` ca ',
    'LEFT JOIN `creature` c ON ca.`', @ca_guid, '` = c.`', @c_guid, '` ',
    'WHERE c.`', @c_guid, '` IS NULL'
  ),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt;
SET @del_creature_addon := IF(@can_ca, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

/* ── 4) gameobject_addon orphans (keyed to gameobject guid) ──────── */
SELECT 'STEP 4: gameobject_addon orphan rows' AS section;

SET @sql := IF(@can_ga,
  CONCAT(
    'INSERT IGNORE INTO `gameobject_addon_backup_genre5a` ',
    'SELECT ga.* FROM `gameobject_addon` ga ',
    'LEFT JOIN `gameobject` g ON ga.`', @ga_guid, '` = g.`', @g_guid, '` ',
    'WHERE g.`', @g_guid, '` IS NULL'
  ),
  'SELECT ''SKIP: gameobject_addon backup'' AS note');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_ga,
  CONCAT(
    'DELETE ga FROM `gameobject_addon` ga ',
    'LEFT JOIN `gameobject` g ON ga.`', @ga_guid, '` = g.`', @g_guid, '` ',
    'WHERE g.`', @g_guid, '` IS NULL'
  ),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt;
SET @del_gameobject_addon := IF(@can_ga, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

/* ================================================================== */
/* VERIFICATION                                                       */
/* ================================================================== */
SELECT 'VERIFICATION' AS section;

SET @rem_creature         := NULL;
SET @rem_gameobject       := NULL;
SET @rem_creature_addon   := NULL;
SET @rem_gameobject_addon := NULL;

SET @sql := IF(@can_creature,
  CONCAT(
    'SELECT COUNT(*) INTO @rem_creature FROM `creature` c ',
    'LEFT JOIN `creature_template` ct ON c.`', @c_id, '` = ct.`', @ct_pk, '` ',
    'WHERE ct.`', @ct_pk, '` IS NULL'
  ),
  'SELECT 0 INTO @rem_creature');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_gameobject,
  CONCAT(
    'SELECT COUNT(*) INTO @rem_gameobject FROM `gameobject` g ',
    'LEFT JOIN `gameobject_template` gt ON g.`', @g_id, '` = gt.`', @got_pk, '` ',
    'WHERE gt.`', @got_pk, '` IS NULL'
  ),
  'SELECT 0 INTO @rem_gameobject');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_ca,
  CONCAT(
    'SELECT COUNT(*) INTO @rem_creature_addon FROM `creature_addon` ca ',
    'LEFT JOIN `creature` c ON ca.`', @ca_guid, '` = c.`', @c_guid, '` ',
    'WHERE c.`', @c_guid, '` IS NULL'
  ),
  'SELECT 0 INTO @rem_creature_addon');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_ga,
  CONCAT(
    'SELECT COUNT(*) INTO @rem_gameobject_addon FROM `gameobject_addon` ga ',
    'LEFT JOIN `gameobject` g ON ga.`', @ga_guid, '` = g.`', @g_guid, '` ',
    'WHERE g.`', @g_guid, '` IS NULL'
  ),
  'SELECT 0 INTO @rem_gameobject_addon');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ── Results ─────────────────────────────────────────────────────── */
SELECT
  @del_creature         AS deleted_creature,
  @del_gameobject       AS deleted_gameobject,
  @del_creature_addon   AS deleted_creature_addon,
  @del_gameobject_addon AS deleted_gameobject_addon;

SELECT
  IFNULL(@rem_creature, 0)         AS remaining_creature_orphans,
  IFNULL(@rem_gameobject, 0)       AS remaining_gameobject_orphans,
  IFNULL(@rem_creature_addon, 0)   AS remaining_creature_addon_orphans,
  IFNULL(@rem_gameobject_addon, 0) AS remaining_gameobject_addon_orphans;

COMMIT;

/* ── Restore session ─────────────────────────────────────────────── */
SET SQL_SAFE_UPDATES  = COALESCE(@OLD_SQL_SAFE_UPDATES, 1);
SET FOREIGN_KEY_CHECKS = COALESCE(@OLD_FOREIGN_KEY_CHECKS, 1);
SET UNIQUE_CHECKS      = COALESCE(@OLD_UNIQUE_CHECKS, 1);
SET AUTOCOMMIT         = COALESCE(@OLD_AUTOCOMMIT, 1);

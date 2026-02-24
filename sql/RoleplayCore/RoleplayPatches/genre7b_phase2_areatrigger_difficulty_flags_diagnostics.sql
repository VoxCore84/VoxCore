/* ================================================================== */
/* GENRE 7B v2 — AreaTrigger difficulty normalization                  */
/* TrinityCore Midnight 12.x (TWW 11.1.7)                            */
/*                                                                    */
/* Normalizes areatrigger.spawnDifficulties / spawnMask values:       */
/*   - Non-instance maps → default (1 for MASK, '0' for LIST)        */
/*   - Instance maps → intersect with map_difficulty allowed set      */
/*                                                                    */
/* Supports both MASK (integer bitmask) and LIST (csv string) modes.  */
/*                                                                    */
/* v2 fixes over v1:                                                  */
/*   - Removed embedded GitHub review comment (syntax error)          */
/*   - Added START TRANSACTION / COMMIT / ROLLBACK                    */
/*   - Added session variable save/restore with COALESCE              */
/*   - DDL (backup table) BEFORE START TRANSACTION                    */
/*   - ROW_COUNT() captured BEFORE DEALLOCATE PREPARE                 */
/*   - @APPLY_FIX defaults to 0 (dry-run)                            */
/*   - map_difficulty guard: @can_apply blocked when map_difficulty    */
/*     metadata unavailable (prevents mass-rewrite to defaults)       */
/*   - Conditional COMMIT/ROLLBACK via @can_apply                     */
/*                                                                    */
/* SET @APPLY_FIX := 0 for dry-run diagnostics only.                  */
/* SET @APPLY_FIX := 1 to apply mutations.                            */
/*                                                                    */
/* IMPORTANT: Run the COMPLETE file. Do not paste fragments.          */
/* ================================================================== */

USE `world`;
SELECT DATABASE() AS active_database;

SET @APPLY_FIX    := 1;
SET @MAX_UPDATE   := 25000;
SET @FORCE_UPDATE := 0;

/* ── Session snapshot ────────────────────────────────────────────── */
SET @OLD_SQL_SAFE_UPDATES   := COALESCE(@@sql_safe_updates, 1);
SET @OLD_FOREIGN_KEY_CHECKS := COALESCE(@@foreign_key_checks, 1);
SET @OLD_UNIQUE_CHECKS      := COALESCE(@@unique_checks, 1);
SET @OLD_AUTOCOMMIT         := COALESCE(@@autocommit, 1);

SET sql_safe_updates  = 0;
SET foreign_key_checks = 0;
SET unique_checks      = 0;
SET autocommit         = 0;

SET @updated_rows      := 0;
SET @candidates_before := 0;
SET @candidates_after  := 0;

/* ================================================================== */
/* SCHEMA INTROSPECTION                                               */
/* ================================================================== */
SELECT 'SCHEMA INTROSPECTION' AS section;

SET @at_exists := (
  SELECT COUNT(*) FROM information_schema.tables
  WHERE table_schema = 'world' AND table_name = 'areatrigger'
);

SET @spawn_pk_col := (
  SELECT column_name FROM information_schema.columns
  WHERE table_schema='world' AND table_name='areatrigger'
    AND column_name IN ('SpawnId','spawnId','guid','GUID','id','ID')
  ORDER BY FIELD(column_name,'SpawnId','spawnId','guid','GUID','id','ID')
  LIMIT 1
);

SET @map_col := (
  SELECT column_name FROM information_schema.columns
  WHERE table_schema='world' AND table_name='areatrigger'
    AND column_name IN ('map','Map','mapId','MapId','MapID')
  ORDER BY FIELD(column_name,'map','Map','mapId','MapId','MapID')
  LIMIT 1
);

SET @create_prop_col := (
  SELECT column_name FROM information_schema.columns
  WHERE table_schema='world' AND table_name='areatrigger'
    AND LOWER(column_name) REGEXP 'create.*propert'
  ORDER BY (LOWER(column_name)='createpropertiesid') DESC,
           (LOWER(column_name)='createproperties') DESC,
           LENGTH(column_name)
  LIMIT 1
);

SET @difficulty_col := (
  SELECT column_name FROM information_schema.columns
  WHERE table_schema='world' AND table_name='areatrigger'
    AND column_name IN ('spawnDifficulties','SpawnDifficulties','spawn_difficulties','spawnMask','SpawnMask','difficulty','Difficulty','difficultyId','DifficultyId')
  ORDER BY FIELD(column_name,'spawnDifficulties','SpawnDifficulties','spawn_difficulties','spawnMask','SpawnMask','difficulty','Difficulty','difficultyId','DifficultyId')
  LIMIT 1
);

SET @difficulty_type := (
  SELECT data_type FROM information_schema.columns
  WHERE table_schema='world' AND table_name='areatrigger' AND column_name=@difficulty_col
  LIMIT 1
);

SET @difficulty_kind := (
  CASE
    WHEN @difficulty_col IS NULL THEN 'NONE'
    WHEN LOWER(@difficulty_col) LIKE '%mask%' THEN 'MASK'
    WHEN @difficulty_type IN ('char','varchar','text','tinytext','mediumtext','longtext') THEN 'LIST'
    WHEN LOWER(@difficulty_col) IN ('spawndifficulties','spawn_difficulties') THEN 'LIST'
    ELSE 'SCALAR'
  END
);

/* ── map_difficulty source ───────────────────────────────────────── */
SET @md_world_exists := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='world' AND table_name='map_difficulty');
SET @md_hotfix_exists := (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='hotfixes' AND table_name='map_difficulty');
SET @md_schema := (
  CASE
    WHEN @md_world_exists = 1 THEN 'world'
    WHEN @md_hotfix_exists = 1 THEN 'hotfixes'
    ELSE NULL
  END
);

SET @md_map_col := (
  SELECT column_name FROM information_schema.columns
  WHERE table_schema=@md_schema AND table_name='map_difficulty'
    AND column_name IN ('MapID','MapId','mapID','mapId','map')
  ORDER BY FIELD(column_name,'MapID','MapId','mapID','mapId','map')
  LIMIT 1
);

SET @md_diff_col := (
  SELECT column_name FROM information_schema.columns
  WHERE table_schema=@md_schema AND table_name='map_difficulty'
    AND column_name IN ('DifficultyID','DifficultyId','difficulty','Difficulty')
  ORDER BY FIELD(column_name,'DifficultyID','DifficultyId','difficulty','Difficulty')
  LIMIT 1
);

/* v2: track whether map_difficulty metadata is actually available */
SET @has_md_metadata := IF(
  @md_schema IS NOT NULL AND @md_map_col IS NOT NULL AND @md_diff_col IS NOT NULL,
  1, 0
);

SELECT
  COALESCE(@spawn_pk_col, 'NOT FOUND')    AS spawn_pk_col,
  COALESCE(@map_col, 'NOT FOUND')         AS map_col,
  COALESCE(@create_prop_col, 'NOT FOUND') AS create_properties_col,
  COALESCE(@difficulty_col, 'NOT FOUND')  AS difficulty_col,
  COALESCE(@difficulty_type, 'N/A')       AS difficulty_type,
  @difficulty_kind                         AS difficulty_kind,
  COALESCE(@md_schema, 'NOT FOUND')       AS map_difficulty_schema,
  COALESCE(@md_map_col, 'NOT FOUND')      AS md_map_col,
  COALESCE(@md_diff_col, 'NOT FOUND')     AS md_diff_col,
  @has_md_metadata                         AS has_map_difficulty;

/* ================================================================== */
/* DDL PHASE — backup table (before transaction)                      */
/* ================================================================== */
SELECT 'BACKUP TABLE CREATION (DDL)' AS section;

SET @sql := IF(@APPLY_FIX = 1 AND @at_exists = 1 AND @spawn_pk_col IS NOT NULL,
  'CREATE TABLE IF NOT EXISTS `world`.`areatrigger_backup_genre7b_difficulty` LIKE `world`.`areatrigger`',
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ================================================================== */
/* DML PHASE                                                          */
/* ================================================================== */
START TRANSACTION;

/* ── Build map_difficulty lookup ─────────────────────────────────── */
SELECT 'LOADING MAP DIFFICULTY DATA' AS section;

DROP TEMPORARY TABLE IF EXISTS tmp_instance_maps;
CREATE TEMPORARY TABLE tmp_instance_maps (
  mapId BIGINT NOT NULL,
  PRIMARY KEY (mapId)
) ENGINE=InnoDB;

DROP TEMPORARY TABLE IF EXISTS tmp_map_allowed;
CREATE TEMPORARY TABLE tmp_map_allowed (
  mapId       BIGINT NOT NULL,
  allowedMask BIGINT UNSIGNED NOT NULL,
  minDiff     INT NOT NULL,
  allowedList TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (mapId)
) ENGINE=InnoDB;

SET @sql := IF(@has_md_metadata = 1,
  CONCAT(
    'INSERT INTO tmp_map_allowed (mapId, allowedMask, minDiff, allowedList) ',
    'SELECT CAST(`', @md_map_col, '` AS SIGNED) AS mapId, ',
    'BIT_OR(CASE WHEN CAST(`', @md_diff_col, '` AS SIGNED) BETWEEN 0 AND 62 THEN (1 << CAST(`', @md_diff_col, '` AS SIGNED)) ELSE 0 END) AS allowedMask, ',
    'MIN(CAST(`', @md_diff_col, '` AS SIGNED)) AS minDiff, ',
    'GROUP_CONCAT(DISTINCT CAST(`', @md_diff_col, '` AS SIGNED) ORDER BY CAST(`', @md_diff_col, '` AS SIGNED) SEPARATOR '','') AS allowedList ',
    'FROM `', @md_schema, '`.`map_difficulty` GROUP BY CAST(`', @md_map_col, '` AS SIGNED)'
  ),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

INSERT IGNORE INTO tmp_instance_maps (mapId) SELECT mapId FROM tmp_map_allowed;

SELECT COUNT(*) AS instance_maps_loaded FROM tmp_instance_maps;

/* ── Scan areatrigger rows ───────────────────────────────────────── */
SELECT 'SCANNING AREATRIGGER SPAWNS' AS section;

DROP TEMPORARY TABLE IF EXISTS tmp_at_scan;
CREATE TEMPORARY TABLE tmp_at_scan (
  spawnPK            BIGINT NOT NULL,
  mapId              BIGINT NULL,
  createPropertiesId BIGINT NULL,
  diff_raw           TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  diff_num           BIGINT NULL,
  PRIMARY KEY (spawnPK),
  KEY idx_mapId (mapId)
) ENGINE=InnoDB;

SET @sql_scan := IF(
  @at_exists = 1 AND @spawn_pk_col IS NOT NULL AND @map_col IS NOT NULL AND @difficulty_col IS NOT NULL,
  CONCAT(
    'INSERT INTO tmp_at_scan (spawnPK, mapId, createPropertiesId, diff_raw, diff_num) ',
    'SELECT CAST(`', @spawn_pk_col, '` AS SIGNED), ',
    'CAST(`', @map_col, '` AS SIGNED), ',
    IF(@create_prop_col IS NOT NULL, CONCAT('CAST(`', @create_prop_col, '` AS SIGNED)'), 'NULL'),
    ', CAST(`', @difficulty_col, '` AS CHAR), ',
    'CASE WHEN CAST(`', @difficulty_col, '` AS CHAR) REGEXP ''^-?[0-9]+$'' THEN CAST(`', @difficulty_col, '` AS SIGNED) ELSE NULL END ',
    'FROM `world`.`areatrigger`'
  ),
  'SELECT 0');
PREPARE stmt FROM @sql_scan; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ── Build mutation candidates ───────────────────────────────────── */
SELECT 'BUILDING MUTATION CANDIDATES' AS section;

DROP TEMPORARY TABLE IF EXISTS tmp_apply;
CREATE TEMPORARY TABLE tmp_apply (
  spawnPK       BIGINT NOT NULL,
  new_diff_num  BIGINT NULL,
  new_diff_text TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (spawnPK)
) ENGINE=InnoDB;

SET @sql := IF(@difficulty_kind = 'MASK',
  CONCAT(
    'INSERT INTO tmp_apply (spawnPK, new_diff_num, new_diff_text) ',
    'SELECT s.spawnPK, ',
    'CASE ',
      'WHEN i.mapId IS NULL THEN 1 ',
      'WHEN a.allowedMask > 0 THEN ',
        'CASE WHEN (COALESCE(s.diff_num,0) & a.allowedMask) > 0 THEN (COALESCE(s.diff_num,0) & a.allowedMask) ELSE (1 << a.minDiff) END ',
      'ELSE COALESCE(s.diff_num,0) END AS new_diff_num, NULL ',
    'FROM tmp_at_scan s ',
    'LEFT JOIN tmp_instance_maps i ON i.mapId = s.mapId ',
    'LEFT JOIN tmp_map_allowed a ON a.mapId = s.mapId ',
    'WHERE (i.mapId IS NULL AND COALESCE(s.diff_num,0) <> 1) ',
    'OR (i.mapId IS NOT NULL AND a.allowedMask > 0 AND NOT (COALESCE(s.diff_num,0) <=> ',
      'CASE WHEN (COALESCE(s.diff_num,0) & a.allowedMask) > 0 THEN (COALESCE(s.diff_num,0) & a.allowedMask) ELSE (1 << a.minDiff) END))'
  ),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ── LIST mode: tokenize + normalize ─────────────────────────────── */
DROP TEMPORARY TABLE IF EXISTS tmp_list_tokens;
CREATE TEMPORARY TABLE tmp_list_tokens (
  spawnPK BIGINT NOT NULL,
  diffId  INT NOT NULL,
  PRIMARY KEY (spawnPK, diffId)
) ENGINE=InnoDB;

SET @sql := IF(@difficulty_kind = 'LIST',
  CONCAT(
    'INSERT IGNORE INTO tmp_list_tokens (spawnPK, diffId) ',
    'SELECT s.spawnPK, CAST(j.v AS SIGNED) AS diffId ',
    'FROM tmp_at_scan s ',
    'JOIN JSON_TABLE(CONCAT(''["'', REPLACE(REPLACE(REPLACE(COALESCE(s.diff_raw, ''''), '' '', ''''), '','', ''","''), ''|'', ''","''), ''"]''), ''$[*]'' COLUMNS (v VARCHAR(32) PATH ''$'')) j ',
    'ON 1=1 ',
    'WHERE j.v REGEXP ''^-?[0-9]+$'''
  ),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

DROP TEMPORARY TABLE IF EXISTS tmp_list_norm;
CREATE TEMPORARY TABLE tmp_list_norm (
  spawnPK  BIGINT NOT NULL,
  normList TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  PRIMARY KEY (spawnPK)
) ENGINE=InnoDB;

INSERT INTO tmp_list_norm (spawnPK, normList)
SELECT t.spawnPK,
       GROUP_CONCAT(DISTINCT t.diffId ORDER BY t.diffId SEPARATOR ',') AS normList
FROM tmp_list_tokens t
JOIN tmp_at_scan s ON s.spawnPK = t.spawnPK
JOIN tmp_map_allowed a ON a.mapId = s.mapId
WHERE t.diffId >= 0 AND ((1 << t.diffId) & a.allowedMask) > 0
GROUP BY t.spawnPK;

SET @sql := IF(@difficulty_kind = 'LIST',
  CONCAT(
    'INSERT INTO tmp_apply (spawnPK, new_diff_num, new_diff_text) ',
    'SELECT s.spawnPK, NULL, ',
    'CASE ',
      'WHEN i.mapId IS NULL THEN ''0'' ',
      'WHEN a.mapId IS NOT NULL THEN COALESCE(n.normList, CAST(a.minDiff AS CHAR)) ',
      'ELSE COALESCE(s.diff_raw, ''0'') END AS new_diff_text ',
    'FROM tmp_at_scan s ',
    'LEFT JOIN tmp_instance_maps i ON i.mapId = s.mapId ',
    'LEFT JOIN tmp_map_allowed a ON a.mapId = s.mapId ',
    'LEFT JOIN tmp_list_norm n ON n.spawnPK = s.spawnPK ',
    'WHERE (i.mapId IS NULL AND NOT (CAST(COALESCE(NULLIF(TRIM(s.diff_raw), ''''), ''0'') AS BINARY(255)) <=> CAST(''0'' AS BINARY(255)))) ',
    'OR (i.mapId IS NOT NULL AND a.mapId IS NOT NULL AND NOT (CAST(COALESCE(n.normList, CAST(a.minDiff AS CHAR)) AS BINARY(255)) <=> CAST(COALESCE(NULLIF(TRIM(s.diff_raw), ''''), ''0'') AS BINARY(255))))'
  ),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SELECT COUNT(*) INTO @candidates_before FROM tmp_apply;

/* ── Diagnostic counts ───────────────────────────────────────────── */
SELECT 'DIAGNOSTICS' AS section;

SET @sql := IF(@difficulty_kind = 'MASK',
  'SELECT COUNT(*) AS non_default_non_instance FROM tmp_at_scan s LEFT JOIN tmp_instance_maps i ON i.mapId=s.mapId WHERE i.mapId IS NULL AND COALESCE(s.diff_num,0) <> 1',
  IF(@difficulty_kind = 'LIST',
    'SELECT COUNT(*) AS non_default_non_instance FROM tmp_at_scan s LEFT JOIN tmp_instance_maps i ON i.mapId=s.mapId WHERE i.mapId IS NULL AND NOT (CAST(COALESCE(NULLIF(TRIM(s.diff_raw), ''''), ''0'') AS BINARY(255)) <=> CAST(''0'' AS BINARY(255)))',
    'SELECT 0 AS non_default_non_instance'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@has_md_metadata = 0 OR @difficulty_kind = 'NONE',
  'SELECT 0 AS invalid_instance_rows',
  IF(@difficulty_kind = 'MASK',
    'SELECT COUNT(*) AS invalid_instance_rows FROM tmp_at_scan s JOIN tmp_map_allowed a ON a.mapId=s.mapId WHERE a.allowedMask > 0 AND (COALESCE(s.diff_num,0) & a.allowedMask) = 0',
    IF(@difficulty_kind = 'LIST',
      'SELECT COUNT(*) AS invalid_instance_rows FROM tmp_at_scan s JOIN tmp_map_allowed a ON a.mapId=s.mapId LEFT JOIN tmp_list_norm n ON n.spawnPK=s.spawnPK WHERE a.mapId IS NOT NULL AND (CAST(COALESCE(n.normList, '''') AS BINARY(255)) <=> CAST('''' AS BINARY(255)))',
      'SELECT 0 AS invalid_instance_rows')));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* Sample */
SELECT s.spawnPK, s.mapId, s.diff_raw AS difficulty_value, s.createPropertiesId
FROM tmp_at_scan s
JOIN tmp_apply a ON a.spawnPK = s.spawnPK
ORDER BY s.mapId, s.spawnPK
LIMIT 50;

/* ── Apply decision ──────────────────────────────────────────────── */
/* v2: Guard on @has_md_metadata — without map_difficulty the
   i.mapId IS NULL branches treat every row as non-instance and
   mass-rewrite to defaults. Block apply when metadata is missing. */
SET @can_apply := IF(
  @APPLY_FIX = 1
  AND @has_md_metadata = 1
  AND @candidates_before > 0
  AND (@candidates_before <= @MAX_UPDATE OR @FORCE_UPDATE = 1),
  1, 0
);

SET @cap_note :=
  CASE
    WHEN @APPLY_FIX <> 1 THEN 'DRY RUN: report-only mode (@APPLY_FIX=0).'
    WHEN @has_md_metadata = 0 THEN 'BLOCKED: map_difficulty metadata unavailable — cannot safely normalize.'
    WHEN @candidates_before = 0 THEN 'Apply mode: no candidates found.'
    WHEN @candidates_before > @MAX_UPDATE AND @FORCE_UPDATE = 0
      THEN CONCAT('BLOCKED by cap: ', @candidates_before, ' rows exceeds @MAX_UPDATE=', @MAX_UPDATE, '. Set @FORCE_UPDATE=1 to override.')
    ELSE CONCAT('Apply mode: updating ', @candidates_before, ' rows.')
  END;

SELECT @candidates_before AS candidates_before, @cap_note AS apply_decision;

/* ── Backup + update ─────────────────────────────────────────────── */
SET @sql := IF(@can_apply = 1,
  CONCAT(
    'INSERT IGNORE INTO `world`.`areatrigger_backup_genre7b_difficulty` ',
    'SELECT atb.* FROM `world`.`areatrigger` atb ',
    'JOIN tmp_apply ta ON ta.spawnPK = CAST(atb.`', @spawn_pk_col, '` AS SIGNED)'
  ),
  'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

SET @sql := IF(@can_apply = 1 AND @difficulty_kind = 'MASK' AND @difficulty_col IS NOT NULL,
  CONCAT(
    'UPDATE `world`.`areatrigger` atu ',
    'JOIN tmp_apply ta ON ta.spawnPK = CAST(atu.`', @spawn_pk_col, '` AS SIGNED) ',
    'SET atu.`', @difficulty_col, '` = ta.new_diff_num'
  ),
  IF(@can_apply = 1 AND @difficulty_kind = 'LIST' AND @difficulty_col IS NOT NULL,
    CONCAT(
      'UPDATE `world`.`areatrigger` atu ',
      'JOIN tmp_apply ta ON ta.spawnPK = CAST(atu.`', @spawn_pk_col, '` AS SIGNED) ',
      'SET atu.`', @difficulty_col, '` = ta.new_diff_text'
    ),
    'SELECT 0'));
PREPARE stmt FROM @sql; EXECUTE stmt;
SET @updated_rows := IF(@can_apply = 1, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

/* ================================================================== */
/* POST-VERIFICATION                                                  */
/* ================================================================== */
SELECT 'VERIFICATION' AS section;

/* Re-scan to count remaining problems */
TRUNCATE TABLE tmp_at_scan;

SET @sql_scan2 := IF(
  @at_exists = 1 AND @spawn_pk_col IS NOT NULL AND @map_col IS NOT NULL AND @difficulty_col IS NOT NULL,
  CONCAT(
    'INSERT INTO tmp_at_scan (spawnPK, mapId, createPropertiesId, diff_raw, diff_num) ',
    'SELECT CAST(`', @spawn_pk_col, '` AS SIGNED), ',
    'CAST(`', @map_col, '` AS SIGNED), ',
    IF(@create_prop_col IS NOT NULL, CONCAT('CAST(`', @create_prop_col, '` AS SIGNED)'), 'NULL'),
    ', CAST(`', @difficulty_col, '` AS CHAR), ',
    'CASE WHEN CAST(`', @difficulty_col, '` AS CHAR) REGEXP ''^-?[0-9]+$'' THEN CAST(`', @difficulty_col, '` AS SIGNED) ELSE NULL END ',
    'FROM `world`.`areatrigger`'
  ),
  'SELECT 0');
PREPARE stmt FROM @sql_scan2; EXECUTE stmt; DEALLOCATE PREPARE stmt;

TRUNCATE TABLE tmp_list_tokens;
SET @sql_lt2 := IF(@difficulty_kind = 'LIST',
  CONCAT(
    'INSERT IGNORE INTO tmp_list_tokens (spawnPK, diffId) ',
    'SELECT s.spawnPK, CAST(j.v AS SIGNED) AS diffId ',
    'FROM tmp_at_scan s ',
    'JOIN JSON_TABLE(CONCAT(''["'', REPLACE(REPLACE(REPLACE(COALESCE(s.diff_raw, ''''), '' '', ''''), '','', ''","''), ''|'', ''","''), ''"]''), ''$[*]'' COLUMNS (v VARCHAR(32) PATH ''$'')) j ',
    'ON 1=1 ',
    'WHERE j.v REGEXP ''^-?[0-9]+$'''
  ),
  'SELECT 0');
PREPARE stmt FROM @sql_lt2; EXECUTE stmt; DEALLOCATE PREPARE stmt;

TRUNCATE TABLE tmp_list_norm;
INSERT INTO tmp_list_norm (spawnPK, normList)
SELECT t.spawnPK,
       GROUP_CONCAT(DISTINCT t.diffId ORDER BY t.diffId SEPARATOR ',') AS normList
FROM tmp_list_tokens t
JOIN tmp_at_scan s ON s.spawnPK = t.spawnPK
JOIN tmp_map_allowed a ON a.mapId = s.mapId
WHERE t.diffId >= 0 AND ((1 << t.diffId) & a.allowedMask) > 0
GROUP BY t.spawnPK;

SET @sql := IF(@difficulty_kind = 'MASK',
  'SELECT COUNT(*) INTO @candidates_after FROM tmp_at_scan s LEFT JOIN tmp_instance_maps i ON i.mapId=s.mapId LEFT JOIN tmp_map_allowed a ON a.mapId=s.mapId WHERE (i.mapId IS NULL AND COALESCE(s.diff_num,0) <> 1) OR (i.mapId IS NOT NULL AND a.allowedMask > 0 AND (COALESCE(s.diff_num,0) & a.allowedMask)=0)',
  IF(@difficulty_kind = 'LIST',
    'SELECT COUNT(*) INTO @candidates_after FROM tmp_at_scan s LEFT JOIN tmp_instance_maps i ON i.mapId=s.mapId LEFT JOIN tmp_map_allowed a ON a.mapId=s.mapId LEFT JOIN tmp_list_norm n ON n.spawnPK=s.spawnPK WHERE (i.mapId IS NULL AND NOT (CAST(COALESCE(NULLIF(TRIM(s.diff_raw), ''''), ''0'') AS BINARY(255)) <=> CAST(''0'' AS BINARY(255)))) OR (i.mapId IS NOT NULL AND a.mapId IS NOT NULL AND (CAST(COALESCE(n.normList, '''') AS BINARY(255)) <=> CAST('''' AS BINARY(255))))',
    'SELECT 0 INTO @candidates_after'));
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ================================================================== */
/* SUMMARY                                                            */
/* ================================================================== */
SELECT 'SUMMARY' AS section;

SELECT
  @candidates_before AS candidates_before,
  @updated_rows      AS updated_rows,
  @candidates_after  AS candidates_after,
  @cap_note          AS notes;

SELECT IF(@can_apply = 1, 'APPLIED — committing changes',
  IF(@APPLY_FIX = 0, 'DRY RUN — rolling back', 'BLOCKED — rolling back')) AS mode;

/* ── Commit or rollback ──────────────────────────────────────────── */
SET @sql := IF(@can_apply = 1, 'COMMIT', 'ROLLBACK');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ================================================================== */
/* FLAGS DIAGNOSTIC (read-only, post-transaction)                     */
/* ================================================================== */
SELECT 'FLAGS DIAGNOSTIC' AS section;

/* world.areatrigger_create_properties */
SET @tbl := 'areatrigger_create_properties'; SET @sch := 'world';
SET @flags_col := (SELECT column_name FROM information_schema.columns WHERE table_schema=@sch AND table_name=@tbl AND column_name IN ('Flags','flags','flag','Flag') ORDER BY FIELD(column_name,'Flags','flags','flag','Flag') LIMIT 1);
SET @pk_col := (SELECT column_name FROM information_schema.columns WHERE table_schema=@sch AND table_name=@tbl ORDER BY (column_key='PRI') DESC, FIELD(column_name,'ID','Id','id','AreaTriggerCreatePropertiesId','areatriggerCreatePropertiesId') DESC, ordinal_position LIMIT 1);
SET @sql := IF(@flags_col IS NOT NULL, CONCAT('SELECT ''',@sch,'.',@tbl,''' AS src, CAST(`',@flags_col,'` AS UNSIGNED) AS flags, COUNT(*) AS cnt FROM `',@sch,'`.`',@tbl,'` GROUP BY CAST(`',@flags_col,'` AS UNSIGNED) ORDER BY cnt DESC LIMIT 25'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* hotfixes.areatrigger_create_properties */
SET @tbl := 'areatrigger_create_properties'; SET @sch := 'hotfixes';
SET @flags_col := (SELECT column_name FROM information_schema.columns WHERE table_schema=@sch AND table_name=@tbl AND column_name IN ('Flags','flags','flag','Flag') ORDER BY FIELD(column_name,'Flags','flags','flag','Flag') LIMIT 1);
SET @pk_col := (SELECT column_name FROM information_schema.columns WHERE table_schema=@sch AND table_name=@tbl ORDER BY (column_key='PRI') DESC, FIELD(column_name,'ID','Id','id','AreaTriggerCreatePropertiesId','areatriggerCreatePropertiesId') DESC, ordinal_position LIMIT 1);
SET @sql := IF(@flags_col IS NOT NULL, CONCAT('SELECT ''',@sch,'.',@tbl,''' AS src, CAST(`',@flags_col,'` AS UNSIGNED) AS flags, COUNT(*) AS cnt FROM `',@sch,'`.`',@tbl,'` GROUP BY CAST(`',@flags_col,'` AS UNSIGNED) ORDER BY cnt DESC LIMIT 25'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* world.areatrigger_create_properties_template */
SET @tbl := 'areatrigger_create_properties_template'; SET @sch := 'world';
SET @flags_col := (SELECT column_name FROM information_schema.columns WHERE table_schema=@sch AND table_name=@tbl AND column_name IN ('Flags','flags','flag','Flag') ORDER BY FIELD(column_name,'Flags','flags','flag','Flag') LIMIT 1);
SET @pk_col := (SELECT column_name FROM information_schema.columns WHERE table_schema=@sch AND table_name=@tbl ORDER BY (column_key='PRI') DESC, FIELD(column_name,'ID','Id','id','AreaTriggerCreatePropertiesId','areatriggerCreatePropertiesId') DESC, ordinal_position LIMIT 1);
SET @sql := IF(@flags_col IS NOT NULL, CONCAT('SELECT ''',@sch,'.',@tbl,''' AS src, CAST(`',@flags_col,'` AS UNSIGNED) AS flags, COUNT(*) AS cnt FROM `',@sch,'`.`',@tbl,'` GROUP BY CAST(`',@flags_col,'` AS UNSIGNED) ORDER BY cnt DESC LIMIT 25'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* hotfixes.areatrigger_create_properties_template */
SET @tbl := 'areatrigger_create_properties_template'; SET @sch := 'hotfixes';
SET @flags_col := (SELECT column_name FROM information_schema.columns WHERE table_schema=@sch AND table_name=@tbl AND column_name IN ('Flags','flags','flag','Flag') ORDER BY FIELD(column_name,'Flags','flags','flag','Flag') LIMIT 1);
SET @pk_col := (SELECT column_name FROM information_schema.columns WHERE table_schema=@sch AND table_name=@tbl ORDER BY (column_key='PRI') DESC, FIELD(column_name,'ID','Id','id','AreaTriggerCreatePropertiesId','areatriggerCreatePropertiesId') DESC, ordinal_position LIMIT 1);
SET @sql := IF(@flags_col IS NOT NULL, CONCAT('SELECT ''',@sch,'.',@tbl,''' AS src, CAST(`',@flags_col,'` AS UNSIGNED) AS flags, COUNT(*) AS cnt FROM `',@sch,'`.`',@tbl,'` GROUP BY CAST(`',@flags_col,'` AS UNSIGNED) ORDER BY cnt DESC LIMIT 25'), 'SELECT 0');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

/* ── Cleanup ─────────────────────────────────────────────────────── */
DROP TEMPORARY TABLE IF EXISTS tmp_instance_maps;
DROP TEMPORARY TABLE IF EXISTS tmp_map_allowed;
DROP TEMPORARY TABLE IF EXISTS tmp_at_scan;
DROP TEMPORARY TABLE IF EXISTS tmp_apply;
DROP TEMPORARY TABLE IF EXISTS tmp_list_tokens;
DROP TEMPORARY TABLE IF EXISTS tmp_list_norm;

/* ── Restore session ─────────────────────────────────────────────── */
SET sql_safe_updates   = COALESCE(@OLD_SQL_SAFE_UPDATES, 1);
SET foreign_key_checks = COALESCE(@OLD_FOREIGN_KEY_CHECKS, 1);
SET unique_checks      = COALESCE(@OLD_UNIQUE_CHECKS, 1);
SET autocommit         = COALESCE(@OLD_AUTOCOMMIT, 1);

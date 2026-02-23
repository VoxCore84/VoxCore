/* GENRE 5A (PHASE 2A): normalize non-instance spawn difficulties safely */
USE `world`;

SET @OLD_SQL_SAFE_UPDATES := 0;
SET @OLD_FOREIGN_KEY_CHECKS := 1;
SET @OLD_UNIQUE_CHECKS := 1;
SET @OLD_AUTOCOMMIT := 1;
SET @session_var_source := NULL;

SET @perf_schema_vars_exists := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = 'performance_schema' AND table_name = 'session_variables'
);
SET @is_vars_exists := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = 'information_schema' AND table_name = 'SYSTEM_VARIABLES'
);
SET @ig_vars_exists := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = 'information_schema' AND table_name = 'GLOBAL_VARIABLES'
);

SET @session_var_source := CASE
  WHEN @perf_schema_vars_exists > 0 THEN 'performance_schema.session_variables'
  WHEN @is_vars_exists > 0 THEN 'information_schema.SYSTEM_VARIABLES'
  WHEN @ig_vars_exists > 0 THEN 'information_schema.GLOBAL_VARIABLES'
  ELSE NULL
END;

SET @sql := "DROP TEMPORARY TABLE IF EXISTS tmp_session_vars";
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := "CREATE TEMPORARY TABLE tmp_session_vars (VARIABLE_NAME VARCHAR(128) NOT NULL PRIMARY KEY, VARIABLE_VALUE VARCHAR(1024) NULL) ENGINE=InnoDB";
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @session_var_source = 'performance_schema.session_variables',
  "INSERT INTO tmp_session_vars (VARIABLE_NAME, VARIABLE_VALUE) SELECT VARIABLE_NAME, VARIABLE_VALUE FROM performance_schema.session_variables WHERE VARIABLE_NAME IN ('sql_safe_updates','foreign_key_checks','unique_checks','autocommit')",
  IF(
    @session_var_source = 'information_schema.SYSTEM_VARIABLES',
    "INSERT INTO tmp_session_vars (VARIABLE_NAME, VARIABLE_VALUE) SELECT VARIABLE_NAME, SESSION_VALUE FROM information_schema.SYSTEM_VARIABLES WHERE VARIABLE_NAME IN ('SQL_SAFE_UPDATES','FOREIGN_KEY_CHECKS','UNIQUE_CHECKS','AUTOCOMMIT')",
    IF(
      @session_var_source = 'information_schema.GLOBAL_VARIABLES',
      "INSERT INTO tmp_session_vars (VARIABLE_NAME, VARIABLE_VALUE) SELECT VARIABLE_NAME, VARIABLE_VALUE FROM information_schema.GLOBAL_VARIABLES WHERE VARIABLE_NAME IN ('SQL_SAFE_UPDATES','FOREIGN_KEY_CHECKS','UNIQUE_CHECKS','AUTOCOMMIT')",
      "SELECT 'SKIP: session variable snapshot unavailable; using safe defaults for restore' AS note"
    )
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @OLD_SQL_SAFE_UPDATES := COALESCE((
  SELECT CASE
    WHEN UPPER(TRIM(VARIABLE_VALUE)) IN ('ON', 'TRUE') THEN 1
    WHEN UPPER(TRIM(VARIABLE_VALUE)) IN ('OFF', 'FALSE') THEN 0
    ELSE CAST(VARIABLE_VALUE AS SIGNED)
  END
  FROM tmp_session_vars
  WHERE UPPER(VARIABLE_NAME) = 'SQL_SAFE_UPDATES'
  LIMIT 1
), 0);
SET @OLD_FOREIGN_KEY_CHECKS := COALESCE((
  SELECT CASE
    WHEN UPPER(TRIM(VARIABLE_VALUE)) IN ('ON', 'TRUE') THEN 1
    WHEN UPPER(TRIM(VARIABLE_VALUE)) IN ('OFF', 'FALSE') THEN 0
    ELSE CAST(VARIABLE_VALUE AS SIGNED)
  END
  FROM tmp_session_vars
  WHERE UPPER(VARIABLE_NAME) = 'FOREIGN_KEY_CHECKS'
  LIMIT 1
), 1);
SET @OLD_UNIQUE_CHECKS := COALESCE((
  SELECT CASE
    WHEN UPPER(TRIM(VARIABLE_VALUE)) IN ('ON', 'TRUE') THEN 1
    WHEN UPPER(TRIM(VARIABLE_VALUE)) IN ('OFF', 'FALSE') THEN 0
    ELSE CAST(VARIABLE_VALUE AS SIGNED)
  END
  FROM tmp_session_vars
  WHERE UPPER(VARIABLE_NAME) = 'UNIQUE_CHECKS'
  LIMIT 1
), 1);
SET @OLD_AUTOCOMMIT := COALESCE((
  SELECT CASE
    WHEN UPPER(TRIM(VARIABLE_VALUE)) IN ('ON', 'TRUE') THEN 1
    WHEN UPPER(TRIM(VARIABLE_VALUE)) IN ('OFF', 'FALSE') THEN 0
    ELSE CAST(VARIABLE_VALUE AS SIGNED)
  END
  FROM tmp_session_vars
  WHERE UPPER(VARIABLE_NAME) = 'AUTOCOMMIT'
  LIMIT 1
), 1);

SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 0;
SET UNIQUE_CHECKS = 0;
SET AUTOCOMMIT = 0;
START TRANSACTION;

SET @world_schema := DATABASE();
SET @creature_changed := 0;
SET @gameobject_changed := 0;
SET @creature_remaining_non_default := NULL;
SET @gameobject_remaining_non_default := NULL;
SET @has_tmp_instance_maps := 0;

SET @creature_exists := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = @world_schema AND table_name = 'creature'
);
SET @gameobject_exists := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = @world_schema AND table_name = 'gameobject'
);
SET @map_difficulty_exists_world := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = @world_schema AND table_name = 'map_difficulty'
);
SET @map_difficulty_exists_hotfixes := (
  SELECT COUNT(*)
  FROM information_schema.tables
  WHERE table_schema = 'hotfixes' AND table_name = 'map_difficulty'
);

SET @map_difficulty_schema := CASE
  WHEN @map_difficulty_exists_world > 0 THEN @world_schema
  WHEN @map_difficulty_exists_hotfixes > 0 THEN 'hotfixes'
  ELSE NULL
END;

SELECT column_name INTO @creature_map_col
FROM information_schema.columns
WHERE table_schema = @world_schema
  AND table_name = 'creature'
  AND column_name IN ('map', 'Map', 'mapId', 'MapId')
ORDER BY FIELD(column_name, 'map', 'Map', 'mapId', 'MapId')
LIMIT 1;

SELECT column_name INTO @creature_spawn_col
FROM information_schema.columns
WHERE table_schema = @world_schema
  AND table_name = 'creature'
  AND column_name IN ('spawnDifficulties', 'SpawnDifficulties', 'spawn_difficulties', 'spawnMask', 'SpawnMask')
ORDER BY FIELD(column_name, 'spawnDifficulties', 'SpawnDifficulties', 'spawn_difficulties', 'spawnMask', 'SpawnMask')
LIMIT 1;

SELECT column_name INTO @creature_guid_col
FROM information_schema.columns
WHERE table_schema = @world_schema
  AND table_name = 'creature'
  AND column_name IN ('guid', 'GUID')
ORDER BY FIELD(column_name, 'guid', 'GUID')
LIMIT 1;

SELECT column_name INTO @gameobject_map_col
FROM information_schema.columns
WHERE table_schema = @world_schema
  AND table_name = 'gameobject'
  AND column_name IN ('map', 'Map', 'mapId', 'MapId')
ORDER BY FIELD(column_name, 'map', 'Map', 'mapId', 'MapId')
LIMIT 1;

SELECT column_name INTO @gameobject_spawn_col
FROM information_schema.columns
WHERE table_schema = @world_schema
  AND table_name = 'gameobject'
  AND column_name IN ('spawnDifficulties', 'SpawnDifficulties', 'spawn_difficulties', 'spawnMask', 'SpawnMask')
ORDER BY FIELD(column_name, 'spawnDifficulties', 'SpawnDifficulties', 'spawn_difficulties', 'spawnMask', 'SpawnMask')
LIMIT 1;

SELECT column_name INTO @gameobject_guid_col
FROM information_schema.columns
WHERE table_schema = @world_schema
  AND table_name = 'gameobject'
  AND column_name IN ('guid', 'GUID')
ORDER BY FIELD(column_name, 'guid', 'GUID')
LIMIT 1;

SET @map_difficulty_map_col := NULL;
SET @map_difficulty_difficulty_col := NULL;

SET @sql := IF(
  @map_difficulty_schema IS NULL,
  "SELECT 'SKIP: map_difficulty not found in world or hotfixes' AS note",
  CONCAT(
    "SELECT column_name INTO @map_difficulty_map_col FROM information_schema.columns ",
    "WHERE table_schema = '", REPLACE(@map_difficulty_schema, "'", "''"), "' AND table_name = 'map_difficulty' ",
    "AND column_name IN ('MapID', 'MapId', 'mapID', 'mapId', 'map') ",
    "ORDER BY FIELD(column_name, 'MapID', 'MapId', 'mapID', 'mapId', 'map') LIMIT 1"
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @map_difficulty_schema IS NULL,
  "SELECT 'SKIP: map_difficulty difficulty column lookup skipped' AS note",
  CONCAT(
    "SELECT column_name INTO @map_difficulty_difficulty_col FROM information_schema.columns ",
    "WHERE table_schema = '", REPLACE(@map_difficulty_schema, "'", "''"), "' AND table_name = 'map_difficulty' ",
    "AND column_name IN ('DifficultyID', 'DifficultyId', 'difficulty', 'Difficulty') ",
    "ORDER BY FIELD(column_name, 'DifficultyID', 'DifficultyId', 'difficulty', 'Difficulty') LIMIT 1"
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := "DROP TEMPORARY TABLE IF EXISTS tmp_instance_maps";
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @map_difficulty_schema IS NULL,
  "SELECT 'SKIP: tmp_instance_maps not created because map_difficulty is unavailable' AS note",
  IF(
    @map_difficulty_map_col IS NULL,
    "SELECT 'SKIP: tmp_instance_maps not created because map_difficulty map column is missing' AS note",
    "CREATE TEMPORARY TABLE tmp_instance_maps (mapId INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB"
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @map_difficulty_schema IS NULL OR @map_difficulty_map_col IS NULL,
  "SELECT 'SKIP: tmp_instance_maps population skipped' AS note",
  CONCAT(
    "INSERT IGNORE INTO tmp_instance_maps (mapId) ",
    "SELECT DISTINCT CAST(md.`", REPLACE(@map_difficulty_map_col, "`", "``"), "` AS UNSIGNED) ",
    "FROM `", REPLACE(@map_difficulty_schema, "`", "``"), "`.`map_difficulty` md ",
    "WHERE md.`", REPLACE(@map_difficulty_map_col, "`", "``"), "` IS NOT NULL"
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_tmp_instance_maps := IF(@map_difficulty_schema IS NOT NULL AND @map_difficulty_map_col IS NOT NULL, 1, 0);

SET @sql := IF(
  @creature_exists = 0,
  "SELECT 'SKIP: creature table missing' AS note",
  IF(
    @creature_map_col IS NULL,
    "SELECT 'SKIP: creature map column missing' AS note",
    IF(
      @creature_spawn_col IS NULL,
      "SELECT 'SKIP: creature spawn difficulty column missing' AS note",
      IF(
        @creature_guid_col IS NULL,
        "SELECT 'SKIP: creature guid column missing' AS note",
        "CREATE TABLE IF NOT EXISTS `creature_backup_genre5a_phase2a` LIKE `creature`"
      )
    )
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @has_tmp_instance_maps = 0,
  "SELECT 'SKIP: creature mutation skipped because instance map metadata is unavailable' AS note",
  IF(
    @creature_exists = 0 OR @creature_map_col IS NULL OR @creature_spawn_col IS NULL OR @creature_guid_col IS NULL,
    "SELECT 'SKIP: creature mutation prerequisites missing' AS note",
    CONCAT(
      "INSERT IGNORE INTO `creature_backup_genre5a_phase2a` ",
      "SELECT c.* FROM `creature` c ",
      "LEFT JOIN tmp_instance_maps tim ON tim.mapId = c.`", REPLACE(@creature_map_col, "`", "``"), "` ",
      "WHERE tim.mapId IS NULL AND ",
      IF(
        @creature_spawn_col IN ('spawnMask', 'SpawnMask'),
        CONCAT("c.`", REPLACE(@creature_spawn_col, "`", "``"), "` IS NOT NULL AND c.`", REPLACE(@creature_spawn_col, "`", "``"), "` <> 1"),
        CONCAT("c.`", REPLACE(@creature_spawn_col, "`", "``"), "` IS NOT NULL AND c.`", REPLACE(@creature_spawn_col, "`", "``"), "` NOT IN ('0','')")
      )
    )
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @has_tmp_instance_maps = 0,
  "SELECT 'SKIP: creature update skipped because instance map metadata is unavailable' AS note",
  IF(
    @creature_exists = 0 OR @creature_map_col IS NULL OR @creature_spawn_col IS NULL,
    "SELECT 'SKIP: creature update prerequisites missing' AS note",
    CONCAT(
      "UPDATE `creature` c ",
      "LEFT JOIN tmp_instance_maps tim ON tim.mapId = c.`", REPLACE(@creature_map_col, "`", "``"), "` ",
      "SET c.`", REPLACE(@creature_spawn_col, "`", "``"), "` = ",
      IF(@creature_spawn_col IN ('spawnMask', 'SpawnMask'), "1 ", "'0' "),
      "WHERE tim.mapId IS NULL AND ",
      IF(
        @creature_spawn_col IN ('spawnMask', 'SpawnMask'),
        CONCAT("c.`", REPLACE(@creature_spawn_col, "`", "``"), "` IS NOT NULL AND c.`", REPLACE(@creature_spawn_col, "`", "``"), "` <> 1"),
        CONCAT("c.`", REPLACE(@creature_spawn_col, "`", "``"), "` IS NOT NULL AND c.`", REPLACE(@creature_spawn_col, "`", "``"), "` NOT IN ('0','')")
      )
    )
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
SET @creature_changed := ROW_COUNT();
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @gameobject_exists = 0,
  "SELECT 'SKIP: gameobject table missing' AS note",
  IF(
    @gameobject_map_col IS NULL,
    "SELECT 'SKIP: gameobject map column missing' AS note",
    IF(
      @gameobject_spawn_col IS NULL,
      "SELECT 'SKIP: gameobject spawn difficulty column missing' AS note",
      IF(
        @gameobject_guid_col IS NULL,
        "SELECT 'SKIP: gameobject guid column missing' AS note",
        "CREATE TABLE IF NOT EXISTS `gameobject_backup_genre5a_phase2a` LIKE `gameobject`"
      )
    )
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @has_tmp_instance_maps = 0,
  "SELECT 'SKIP: gameobject mutation skipped because instance map metadata is unavailable' AS note",
  IF(
    @gameobject_exists = 0 OR @gameobject_map_col IS NULL OR @gameobject_spawn_col IS NULL OR @gameobject_guid_col IS NULL,
    "SELECT 'SKIP: gameobject mutation prerequisites missing' AS note",
    CONCAT(
      "INSERT IGNORE INTO `gameobject_backup_genre5a_phase2a` ",
      "SELECT g.* FROM `gameobject` g ",
      "LEFT JOIN tmp_instance_maps tim ON tim.mapId = g.`", REPLACE(@gameobject_map_col, "`", "``"), "` ",
      "WHERE tim.mapId IS NULL AND ",
      IF(
        @gameobject_spawn_col IN ('spawnMask', 'SpawnMask'),
        CONCAT("g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` IS NOT NULL AND g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` <> 1"),
        CONCAT("g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` IS NOT NULL AND g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` NOT IN ('0','')")
      )
    )
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @has_tmp_instance_maps = 0,
  "SELECT 'SKIP: gameobject update skipped because instance map metadata is unavailable' AS note",
  IF(
    @gameobject_exists = 0 OR @gameobject_map_col IS NULL OR @gameobject_spawn_col IS NULL,
    "SELECT 'SKIP: gameobject update prerequisites missing' AS note",
    CONCAT(
      "UPDATE `gameobject` g ",
      "LEFT JOIN tmp_instance_maps tim ON tim.mapId = g.`", REPLACE(@gameobject_map_col, "`", "``"), "` ",
      "SET g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` = ",
      IF(@gameobject_spawn_col IN ('spawnMask', 'SpawnMask'), "1 ", "'0' "),
      "WHERE tim.mapId IS NULL AND ",
      IF(
        @gameobject_spawn_col IN ('spawnMask', 'SpawnMask'),
        CONCAT("g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` IS NOT NULL AND g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` <> 1"),
        CONCAT("g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` IS NOT NULL AND g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` NOT IN ('0','')")
      )
    )
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
SET @gameobject_changed := ROW_COUNT();
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @has_tmp_instance_maps = 0,
  "SELECT 'SKIP: creature non-instance verification skipped' AS note",
  IF(
    @creature_exists = 0 OR @creature_map_col IS NULL OR @creature_spawn_col IS NULL,
    "SELECT 'SKIP: creature non-instance verification prerequisites missing' AS note",
    CONCAT(
      "SELECT COUNT(*) INTO @creature_remaining_non_default ",
      "FROM `creature` c ",
      "LEFT JOIN tmp_instance_maps tim ON tim.mapId = c.`", REPLACE(@creature_map_col, "`", "``"), "` ",
      "WHERE tim.mapId IS NULL AND ",
      IF(
        @creature_spawn_col IN ('spawnMask', 'SpawnMask'),
        CONCAT("c.`", REPLACE(@creature_spawn_col, "`", "``"), "` IS NOT NULL AND c.`", REPLACE(@creature_spawn_col, "`", "``"), "` <> 1"),
        CONCAT("c.`", REPLACE(@creature_spawn_col, "`", "``"), "` IS NOT NULL AND c.`", REPLACE(@creature_spawn_col, "`", "``"), "` NOT IN ('0','')")
      )
    )
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @has_tmp_instance_maps = 0,
  "SELECT 'SKIP: gameobject non-instance verification skipped' AS note",
  IF(
    @gameobject_exists = 0 OR @gameobject_map_col IS NULL OR @gameobject_spawn_col IS NULL,
    "SELECT 'SKIP: gameobject non-instance verification prerequisites missing' AS note",
    CONCAT(
      "SELECT COUNT(*) INTO @gameobject_remaining_non_default ",
      "FROM `gameobject` g ",
      "LEFT JOIN tmp_instance_maps tim ON tim.mapId = g.`", REPLACE(@gameobject_map_col, "`", "``"), "` ",
      "WHERE tim.mapId IS NULL AND ",
      IF(
        @gameobject_spawn_col IN ('spawnMask', 'SpawnMask'),
        CONCAT("g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` IS NOT NULL AND g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` <> 1"),
        CONCAT("g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` IS NOT NULL AND g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` NOT IN ('0','')")
      )
    )
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @has_tmp_instance_maps = 0,
  "SELECT 'SKIP: creature instance diagnostics skipped (no tmp_instance_maps)' AS note",
  IF(
    @creature_exists = 0 OR @creature_map_col IS NULL OR @creature_spawn_col IS NULL,
    "SELECT 'SKIP: creature instance diagnostics prerequisites missing' AS note",
    CONCAT(
      "SELECT c.`", REPLACE(@creature_map_col, "`", "``"), "` AS mapId, COUNT(*) AS rows_with_non_default_spawn ",
      "FROM `creature` c ",
      "INNER JOIN tmp_instance_maps tim ON tim.mapId = c.`", REPLACE(@creature_map_col, "`", "``"), "` ",
      "WHERE ",
      IF(
        @creature_spawn_col IN ('spawnMask', 'SpawnMask'),
        CONCAT("c.`", REPLACE(@creature_spawn_col, "`", "``"), "` IS NOT NULL AND c.`", REPLACE(@creature_spawn_col, "`", "``"), "` <> 1 "),
        CONCAT("c.`", REPLACE(@creature_spawn_col, "`", "``"), "` IS NOT NULL AND c.`", REPLACE(@creature_spawn_col, "`", "``"), "` NOT IN ('0','') ")
      ),
      "GROUP BY c.`", REPLACE(@creature_map_col, "`", "``"), "` ",
      "ORDER BY rows_with_non_default_spawn DESC, mapId ASC LIMIT 25"
    )
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
  @has_tmp_instance_maps = 0,
  "SELECT 'SKIP: gameobject instance diagnostics skipped (no tmp_instance_maps)' AS note",
  IF(
    @gameobject_exists = 0 OR @gameobject_map_col IS NULL OR @gameobject_spawn_col IS NULL,
    "SELECT 'SKIP: gameobject instance diagnostics prerequisites missing' AS note",
    CONCAT(
      "SELECT g.`", REPLACE(@gameobject_map_col, "`", "``"), "` AS mapId, COUNT(*) AS rows_with_non_default_spawn ",
      "FROM `gameobject` g ",
      "INNER JOIN tmp_instance_maps tim ON tim.mapId = g.`", REPLACE(@gameobject_map_col, "`", "``"), "` ",
      "WHERE ",
      IF(
        @gameobject_spawn_col IN ('spawnMask', 'SpawnMask'),
        CONCAT("g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` IS NOT NULL AND g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` <> 1 "),
        CONCAT("g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` IS NOT NULL AND g.`", REPLACE(@gameobject_spawn_col, "`", "``"), "` NOT IN ('0','') ")
      ),
      "GROUP BY g.`", REPLACE(@gameobject_map_col, "`", "``"), "` ",
      "ORDER BY rows_with_non_default_spawn DESC, mapId ASC LIMIT 25"
    )
  )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT
  @creature_changed AS creature_rows_changed,
  @gameobject_changed AS gameobject_rows_changed,
  @creature_remaining_non_default AS creature_non_instance_remaining_non_default,
  @gameobject_remaining_non_default AS gameobject_non_instance_remaining_non_default;

COMMIT;

SET SQL_SAFE_UPDATES = COALESCE(@OLD_SQL_SAFE_UPDATES, 0);
SET FOREIGN_KEY_CHECKS = COALESCE(@OLD_FOREIGN_KEY_CHECKS, 1);
SET UNIQUE_CHECKS = COALESCE(@OLD_UNIQUE_CHECKS, 1);
SET AUTOCOMMIT = COALESCE(@OLD_AUTOCOMMIT, 1);

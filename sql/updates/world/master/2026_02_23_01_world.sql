/* Genre 5C: Spawn validity cleanup (invalid map IDs, invalid phaseid refs, invalid creature modelid overrides) */
USE `world`;
SELECT DATABASE() AS current_database;

SET @APPLY_FIX := 1;                 /* 0 = diagnostics only; 1 = apply changes */
SET @MAX_DELETE := 125000;           /* cap deletes */
SET @MAX_UPDATE := 120000;           /* cap updates */
SET @FORCE_APPLY := 0;               /* override caps intentionally */

SET @old_sql_safe_updates := @@sql_safe_updates;
SET @old_foreign_key_checks := @@foreign_key_checks;
SET @old_unique_checks := @@unique_checks;
SET @old_autocommit := @@autocommit;

SET SQL_SAFE_UPDATES = 0;
SET FOREIGN_KEY_CHECKS = 1;
SET UNIQUE_CHECKS = 1;
SET AUTOCOMMIT = 0;

START TRANSACTION;

SET @go_exists := (
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'world' AND table_name = 'gameobject'
);
SET @cr_exists := (
    SELECT COUNT(*)
    FROM information_schema.tables
    WHERE table_schema = 'world' AND table_name = 'creature'
);

SELECT column_name INTO @go_guid_col
FROM information_schema.columns
WHERE table_schema = 'world' AND table_name = 'gameobject'
  AND column_name IN ('guid','GUID','id','ID')
ORDER BY FIELD(column_name,'guid','GUID','id','ID')
LIMIT 1;

SELECT column_name INTO @go_map_col
FROM information_schema.columns
WHERE table_schema = 'world' AND table_name = 'gameobject'
  AND column_name IN ('map','Map','mapId','MapId')
ORDER BY FIELD(column_name,'map','Map','mapId','MapId')
LIMIT 1;

SELECT column_name INTO @go_phase_col
FROM information_schema.columns
WHERE table_schema = 'world' AND table_name = 'gameobject'
  AND column_name IN ('phaseid','PhaseId','PhaseID','phase_id')
ORDER BY FIELD(column_name,'phaseid','PhaseId','PhaseID','phase_id')
LIMIT 1;

SELECT column_name INTO @go_entry_col
FROM information_schema.columns
WHERE table_schema = 'world' AND table_name = 'gameobject'
  AND column_name IN ('id','entry','gameobjectid','GameObjectID')
ORDER BY FIELD(column_name,'id','entry','gameobjectid','GameObjectID')
LIMIT 1;

SELECT column_name INTO @cr_guid_col
FROM information_schema.columns
WHERE table_schema = 'world' AND table_name = 'creature'
  AND column_name IN ('guid','GUID','id','ID')
ORDER BY FIELD(column_name,'guid','GUID','id','ID')
LIMIT 1;

SELECT column_name INTO @cr_model_col
FROM information_schema.columns
WHERE table_schema = 'world' AND table_name = 'creature'
  AND column_name IN ('modelid','modelId','ModelId','displayid','DisplayId','displayId')
ORDER BY FIELD(column_name,'modelid','modelId','ModelId','displayid','DisplayId','displayId')
LIMIT 1;

SELECT column_name INTO @cr_entry_col
FROM information_schema.columns
WHERE table_schema = 'world' AND table_name = 'creature'
  AND column_name IN ('id','entry','creatureid','CreatureID')
ORDER BY FIELD(column_name,'id','entry','creatureid','CreatureID')
LIMIT 1;

SET @go_has_map := IF(@go_exists = 1 AND @go_map_col IS NOT NULL, 1, 0);
SET @go_has_phase := IF(@go_exists = 1 AND @go_phase_col IS NOT NULL, 1, 0);
SET @go_has_guid := IF(@go_exists = 1 AND @go_guid_col IS NOT NULL, 1, 0);
SET @cr_has_model := IF(@cr_exists = 1 AND @cr_model_col IS NOT NULL, 1, 0);
SET @cr_has_guid := IF(@cr_exists = 1 AND @cr_guid_col IS NOT NULL, 1, 0);

SET @sql_diag_a_count := IF(
    @go_has_map = 1,
    CONCAT(
        'SELECT COUNT(*) AS invalid_map_count FROM `world`.`gameobject` WHERE `', @go_map_col, '` IN (1470,1178,451,2100,1180)'
    ),
    'SELECT ''SKIP: gameobject table/map column missing for invalid map diagnostics'' AS note'
);
PREPARE stmt FROM @sql_diag_a_count;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_diag_a_breakdown := IF(
    @go_has_map = 1,
    CONCAT(
        'SELECT `', @go_map_col, '` AS mapId, COUNT(*) AS count_rows ',
        'FROM `world`.`gameobject` ',
        'WHERE `', @go_map_col, '` IN (1470,1178,451,2100,1180) ',
        'GROUP BY `', @go_map_col, '` ORDER BY COUNT(*) DESC, `', @go_map_col, '`'
    ),
    'SELECT ''SKIP: gameobject table/map column missing for invalid map breakdown'' AS note'
);
PREPARE stmt FROM @sql_diag_a_breakdown;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @go_entry_select := IF(@go_entry_col IS NOT NULL, CONCAT('`', @go_entry_col, '` AS entry, '), 'NULL AS entry, ');
SET @sql_diag_a_sample := IF(
    @go_has_map = 1 AND @go_has_guid = 1,
    CONCAT(
        'SELECT `', @go_guid_col, '` AS guid, ', @go_entry_select, '`', @go_map_col, '` AS mapId ',
        'FROM `world`.`gameobject` ',
        'WHERE `', @go_map_col, '` IN (1470,1178,451,2100,1180) ',
        'ORDER BY `', @go_guid_col, '` LIMIT 50'
    ),
    'SELECT ''SKIP: gameobject guid/map columns missing for invalid map sample'' AS note'
);
PREPARE stmt FROM @sql_diag_a_sample;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_diag_b_count := IF(
    @go_has_phase = 1,
    CONCAT(
        'SELECT COUNT(*) AS invalid_phaseid_count FROM `world`.`gameobject` ',
        'WHERE `', @go_phase_col, '` IN (385942,7,42833) AND `', @go_phase_col, '` <> 0'
    ),
    'SELECT ''SKIP: gameobject table/phaseid column missing for invalid phase diagnostics'' AS note'
);
PREPARE stmt FROM @sql_diag_b_count;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_diag_b_breakdown := IF(
    @go_has_phase = 1,
    CONCAT(
        'SELECT `', @go_phase_col, '` AS phaseid, COUNT(*) AS count_rows ',
        'FROM `world`.`gameobject` ',
        'WHERE `', @go_phase_col, '` IN (385942,7,42833) AND `', @go_phase_col, '` <> 0 ',
        'GROUP BY `', @go_phase_col, '` ORDER BY COUNT(*) DESC, `', @go_phase_col, '`'
    ),
    'SELECT ''SKIP: gameobject table/phaseid column missing for invalid phase breakdown'' AS note'
);
PREPARE stmt FROM @sql_diag_b_breakdown;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @go_map_select := IF(@go_map_col IS NOT NULL, CONCAT('`', @go_map_col, '` AS mapId'), 'NULL AS mapId');
SET @sql_diag_b_sample := IF(
    @go_has_phase = 1 AND @go_has_guid = 1,
    CONCAT(
        'SELECT `', @go_guid_col, '` AS guid, ', @go_entry_select, '`', @go_phase_col, '` AS phaseid, ', @go_map_select, ' ',
        'FROM `world`.`gameobject` ',
        'WHERE `', @go_phase_col, '` IN (385942,7,42833) AND `', @go_phase_col, '` <> 0 ',
        'ORDER BY `', @go_guid_col, '` LIMIT 50'
    ),
    'SELECT ''SKIP: gameobject guid/phase columns missing for invalid phase sample'' AS note'
);
PREPARE stmt FROM @sql_diag_b_sample;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_diag_c_count := IF(
    @cr_has_model = 1,
    CONCAT(
        'SELECT COUNT(*) AS invalid_modelid_count FROM `world`.`creature` ',
        'WHERE `', @cr_model_col, '` IN (959,12346,14952,239,28283) AND `', @cr_model_col, '` <> 0'
    ),
    'SELECT ''SKIP: creature table/modelid column missing for invalid model diagnostics'' AS note'
);
PREPARE stmt FROM @sql_diag_c_count;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_diag_c_breakdown := IF(
    @cr_has_model = 1,
    CONCAT(
        'SELECT `', @cr_model_col, '` AS modelid, COUNT(*) AS count_rows ',
        'FROM `world`.`creature` ',
        'WHERE `', @cr_model_col, '` IN (959,12346,14952,239,28283) AND `', @cr_model_col, '` <> 0 ',
        'GROUP BY `', @cr_model_col, '` ORDER BY COUNT(*) DESC, `', @cr_model_col, '`'
    ),
    'SELECT ''SKIP: creature table/modelid column missing for invalid model breakdown'' AS note'
);
PREPARE stmt FROM @sql_diag_c_breakdown;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @cr_entry_select := IF(@cr_entry_col IS NOT NULL, CONCAT('`', @cr_entry_col, '` AS entry, '), 'NULL AS entry, ');
SET @sql_diag_c_sample := IF(
    @cr_has_model = 1 AND @cr_has_guid = 1,
    CONCAT(
        'SELECT `', @cr_guid_col, '` AS guid, ', @cr_entry_select, '`', @cr_model_col, '` AS modelid ',
        'FROM `world`.`creature` ',
        'WHERE `', @cr_model_col, '` IN (959,12346,14952,239,28283) AND `', @cr_model_col, '` <> 0 ',
        'ORDER BY `', @cr_guid_col, '` LIMIT 50'
    ),
    'SELECT ''SKIP: creature guid/modelid columns missing for invalid model sample'' AS note'
);
PREPARE stmt FROM @sql_diag_c_sample;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_count_delete := IF(
    @go_has_map = 1,
    CONCAT('SELECT COUNT(*) INTO @delete_candidates FROM `world`.`gameobject` WHERE `', @go_map_col, '` IN (1470,1178,451,2100,1180)'),
    'SELECT 0 INTO @delete_candidates'
);
PREPARE stmt FROM @sql_count_delete;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_count_phase := IF(
    @go_has_phase = 1,
    CONCAT('SELECT COUNT(*) INTO @phase_candidates FROM `world`.`gameobject` WHERE `', @go_phase_col, '` IN (385942,7,42833) AND `', @go_phase_col, '` <> 0'),
    'SELECT 0 INTO @phase_candidates'
);
PREPARE stmt FROM @sql_count_phase;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_count_model := IF(
    @cr_has_model = 1,
    CONCAT('SELECT COUNT(*) INTO @model_candidates FROM `world`.`creature` WHERE `', @cr_model_col, '` IN (959,12346,14952,239,28283) AND `', @cr_model_col, '` <> 0'),
    'SELECT 0 INTO @model_candidates'
);
PREPARE stmt FROM @sql_count_model;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @update_candidates := IFNULL(@phase_candidates,0) + IFNULL(@model_candidates,0);
SET @cap_exceeded := IF(@APPLY_FIX = 1 AND @FORCE_APPLY = 0 AND (IFNULL(@delete_candidates,0) > @MAX_DELETE OR IFNULL(@update_candidates,0) > @MAX_UPDATE), 1, 0);
SET @allow_apply := IF(@APPLY_FIX = 1 AND (@FORCE_APPLY = 1 OR @cap_exceeded = 0), 1, 0);
SET @cap_note := IF(
    @APPLY_FIX = 0,
    'Diagnostic-only mode: APPLY_FIX=0',
    IF(
        @allow_apply = 1,
        'Apply mode: changes executed',
        CONCAT(
            'CAP BLOCKED: delete_candidates=', IFNULL(@delete_candidates,0),
            ', update_candidates=', IFNULL(@update_candidates,0),
            ', limits delete<=', @MAX_DELETE,
            ', update<=', @MAX_UPDATE,
            ', FORCE_APPLY=', @FORCE_APPLY
        )
    )
);

SET @deleted_invalid_map := 0;
SET @updated_phase := 0;
SET @updated_model := 0;

SET @sql_apply_note := IF(@allow_apply = 1, 'SELECT ''APPLY: changes will be executed'' AS note', CONCAT('SELECT ''', @cap_note, ''' AS note'));
PREPARE stmt FROM @sql_apply_note;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_bk_go_map := IF(
    @allow_apply = 1 AND @go_has_map = 1,
    'CREATE TABLE IF NOT EXISTS `world`.`gameobject_backup_genre5c_invalid_map` LIKE `world`.`gameobject`',
    'SELECT ''SKIP: backup table gameobject_backup_genre5c_invalid_map not created'' AS note'
);
PREPARE stmt FROM @sql_bk_go_map;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_bk_go_phase := IF(
    @allow_apply = 1 AND @go_has_phase = 1,
    'CREATE TABLE IF NOT EXISTS `world`.`gameobject_backup_genre5c_phase_fix` LIKE `world`.`gameobject`',
    'SELECT ''SKIP: backup table gameobject_backup_genre5c_phase_fix not created'' AS note'
);
PREPARE stmt FROM @sql_bk_go_phase;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_bk_cr_model := IF(
    @allow_apply = 1 AND @cr_has_model = 1,
    'CREATE TABLE IF NOT EXISTS `world`.`creature_backup_genre5c_model_fix` LIKE `world`.`creature`',
    'SELECT ''SKIP: backup table creature_backup_genre5c_model_fix not created'' AS note'
);
PREPARE stmt FROM @sql_bk_cr_model;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_backup_insert_go_map := IF(
    @allow_apply = 1 AND @go_has_map = 1,
    CONCAT(
        'INSERT IGNORE INTO `world`.`gameobject_backup_genre5c_invalid_map` ',
        'SELECT * FROM `world`.`gameobject` WHERE `', @go_map_col, '` IN (1470,1178,451,2100,1180)'
    ),
    'SELECT ''SKIP: invalid-map backup insert not executed'' AS note'
);
PREPARE stmt FROM @sql_backup_insert_go_map;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_delete_go_map := IF(
    @allow_apply = 1 AND @go_has_map = 1,
    CONCAT('DELETE FROM `world`.`gameobject` WHERE `', @go_map_col, '` IN (1470,1178,451,2100,1180)'),
    'SELECT ''SKIP: invalid-map delete not executed'' AS note'
);
PREPARE stmt FROM @sql_delete_go_map;
EXECUTE stmt;
SET @deleted_invalid_map := IF(@allow_apply = 1 AND @go_has_map = 1, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

SET @sql_backup_insert_go_phase := IF(
    @allow_apply = 1 AND @go_has_phase = 1,
    CONCAT(
        'INSERT IGNORE INTO `world`.`gameobject_backup_genre5c_phase_fix` ',
        'SELECT * FROM `world`.`gameobject` WHERE `', @go_phase_col, '` IN (385942,7,42833) AND `', @go_phase_col, '` <> 0'
    ),
    'SELECT ''SKIP: phase backup insert not executed'' AS note'
);
PREPARE stmt FROM @sql_backup_insert_go_phase;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_update_go_phase := IF(
    @allow_apply = 1 AND @go_has_phase = 1,
    CONCAT('UPDATE `world`.`gameobject` SET `', @go_phase_col, '` = 0 WHERE `', @go_phase_col, '` IN (385942,7,42833) AND `', @go_phase_col, '` <> 0'),
    'SELECT ''SKIP: phase update not executed'' AS note'
);
PREPARE stmt FROM @sql_update_go_phase;
EXECUTE stmt;
SET @updated_phase := IF(@allow_apply = 1 AND @go_has_phase = 1, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

SET @sql_backup_insert_cr_model := IF(
    @allow_apply = 1 AND @cr_has_model = 1,
    CONCAT(
        'INSERT IGNORE INTO `world`.`creature_backup_genre5c_model_fix` ',
        'SELECT * FROM `world`.`creature` WHERE `', @cr_model_col, '` IN (959,12346,14952,239,28283) AND `', @cr_model_col, '` <> 0'
    ),
    'SELECT ''SKIP: model backup insert not executed'' AS note'
);
PREPARE stmt FROM @sql_backup_insert_cr_model;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_update_cr_model := IF(
    @allow_apply = 1 AND @cr_has_model = 1,
    CONCAT('UPDATE `world`.`creature` SET `', @cr_model_col, '` = 0 WHERE `', @cr_model_col, '` IN (959,12346,14952,239,28283) AND `', @cr_model_col, '` <> 0'),
    'SELECT ''SKIP: model update not executed'' AS note'
);
PREPARE stmt FROM @sql_update_cr_model;
EXECUTE stmt;
SET @updated_model := IF(@allow_apply = 1 AND @cr_has_model = 1, ROW_COUNT(), 0);
DEALLOCATE PREPARE stmt;

SET @sql_verify_a := IF(
    @go_has_map = 1,
    CONCAT('SELECT COUNT(*) AS remaining_invalid_map_count FROM `world`.`gameobject` WHERE `', @go_map_col, '` IN (1470,1178,451,2100,1180)'),
    'SELECT ''SKIP: verification invalid map unavailable'' AS note'
);
PREPARE stmt FROM @sql_verify_a;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_verify_b := IF(
    @go_has_phase = 1,
    CONCAT('SELECT COUNT(*) AS remaining_invalid_phaseid_count FROM `world`.`gameobject` WHERE `', @go_phase_col, '` IN (385942,7,42833) AND `', @go_phase_col, '` <> 0'),
    'SELECT ''SKIP: verification invalid phase unavailable'' AS note'
);
PREPARE stmt FROM @sql_verify_b;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql_verify_c := IF(
    @cr_has_model = 1,
    CONCAT('SELECT COUNT(*) AS remaining_invalid_modelid_count FROM `world`.`creature` WHERE `', @cr_model_col, '` IN (959,12346,14952,239,28283) AND `', @cr_model_col, '` <> 0'),
    'SELECT ''SKIP: verification invalid model unavailable'' AS note'
);
PREPARE stmt FROM @sql_verify_c;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT
    IFNULL(@delete_candidates,0) AS delete_candidates,
    IFNULL(@update_candidates,0) AS update_candidates,
    IFNULL(@deleted_invalid_map,0) AS deleted_invalid_map,
    IFNULL(@updated_phase,0) AS updated_phase,
    IFNULL(@updated_model,0) AS updated_model,
    @cap_note AS cap_note;

COMMIT;

SET SQL_SAFE_UPDATES = @old_sql_safe_updates;
SET FOREIGN_KEY_CHECKS = @old_foreign_key_checks;
SET UNIQUE_CHECKS = @old_unique_checks;
SET AUTOCOMMIT = @old_autocommit;

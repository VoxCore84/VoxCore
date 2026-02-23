
USE `world`;
SELECT DATABASE() AS current_database;

SET @APPLY_FIX := 0;

SET @OLD_SQL_SAFE_UPDATES := @@sql_safe_updates;
SET @OLD_FOREIGN_KEY_CHECKS := @@foreign_key_checks;
SET @OLD_UNIQUE_CHECKS := @@unique_checks;
SET @OLD_AUTOCOMMIT := @@autocommit;

SET sql_safe_updates = 0;
SET foreign_key_checks = 0;
SET unique_checks = 0;
SET autocommit = 0;

START TRANSACTION;

DROP TEMPORARY TABLE IF EXISTS tmp_item_sources;
CREATE TEMPORARY TABLE tmp_item_sources (
    source_schema VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
    source_table VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
    source_pk VARCHAR(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
    PRIMARY KEY (source_schema, source_table)
);

SET @src_world_item_template_exists := 0;
SET @src_world_item_template_pk := NULL;
SET @src_world_item_sparse_exists := 0;
SET @src_world_item_sparse_pk := NULL;
SET @src_hotfixes_exists := 0;
SET @src_hotfixes_item_sparse_exists := 0;
SET @src_hotfixes_item_sparse_pk := NULL;
SET @src_hotfixes_item_exists := 0;
SET @src_hotfixes_item_pk := NULL;

SELECT COUNT(*) INTO @src_world_item_template_exists
FROM information_schema.tables
WHERE table_schema = 'world' AND table_name = 'item_template';

SET @sql := IF(
    @src_world_item_template_exists = 1,
    "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_template' AND column_name='entry') THEN 'entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_template' AND column_name='ID') THEN 'ID' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_template' AND column_name='id') THEN 'id' ELSE NULL END INTO @src_world_item_template_pk",
    "SELECT 'SKIP: world.item_template missing' AS note"
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL,
    "INSERT INTO tmp_item_sources (source_schema, source_table, source_pk) VALUES ('world','item_template',@src_world_item_template_pk)",
    "SELECT 'SKIP: world.item_template has no recognized PK column' AS note"
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT COUNT(*) INTO @src_world_item_sparse_exists
FROM information_schema.tables
WHERE table_schema = 'world' AND table_name = 'item_sparse';

SET @sql := IF(
    @src_world_item_sparse_exists = 1,
    "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_sparse' AND column_name='ID') THEN 'ID' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_sparse' AND column_name='id') THEN 'id' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='item_sparse' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @src_world_item_sparse_pk",
    "SELECT 'SKIP: world.item_sparse missing' AS note"
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL,
    "INSERT INTO tmp_item_sources (source_schema, source_table, source_pk) VALUES ('world','item_sparse',@src_world_item_sparse_pk)",
    "SELECT 'SKIP: world.item_sparse has no recognized PK column' AS note"
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT COUNT(*) INTO @src_hotfixes_exists
FROM information_schema.schemata
WHERE schema_name = 'hotfixes';

SET @sql := IF(
    @src_hotfixes_exists = 1,
    "SELECT 'INFO: hotfixes schema detected' AS note",
    "SELECT 'SKIP: hotfixes schema missing' AS note"
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @src_hotfixes_exists = 1,
    "SELECT COUNT(*) INTO @src_hotfixes_item_sparse_exists FROM information_schema.tables WHERE table_schema='hotfixes' AND table_name='item_sparse'",
    "SET @src_hotfixes_item_sparse_exists := 0"
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @src_hotfixes_item_sparse_exists = 1,
    "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item_sparse' AND column_name='ID') THEN 'ID' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item_sparse' AND column_name='id') THEN 'id' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item_sparse' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @src_hotfixes_item_sparse_pk",
    "SELECT 'SKIP: hotfixes.item_sparse missing' AS note"
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL,
    "INSERT INTO tmp_item_sources (source_schema, source_table, source_pk) VALUES ('hotfixes','item_sparse',@src_hotfixes_item_sparse_pk)",
    "SELECT 'SKIP: hotfixes.item_sparse has no recognized PK column' AS note"
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @src_hotfixes_exists = 1,
    "SELECT COUNT(*) INTO @src_hotfixes_item_exists FROM information_schema.tables WHERE table_schema='hotfixes' AND table_name='item'",
    "SET @src_hotfixes_item_exists := 0"
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @src_hotfixes_item_exists = 1,
    "SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item' AND column_name='ID') THEN 'ID' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item' AND column_name='id') THEN 'id' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='hotfixes' AND table_name='item' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @src_hotfixes_item_pk",
    "SELECT 'SKIP: hotfixes.item missing' AS note"
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL,
    "INSERT INTO tmp_item_sources (source_schema, source_table, source_pk) VALUES ('hotfixes','item',@src_hotfixes_item_pk)",
    "SELECT 'SKIP: hotfixes.item has no recognized PK column' AS note"
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SELECT COUNT(*) INTO @item_source_count FROM tmp_item_sources;
SELECT source_schema, source_table, source_pk FROM tmp_item_sources ORDER BY source_schema, source_table;

DROP TEMPORARY TABLE IF EXISTS tmp_genre6a_summary;
CREATE TEMPORARY TABLE tmp_genre6a_summary (
    table_name VARCHAR(128) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
    status_note VARCHAR(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
    missing_before BIGINT NOT NULL DEFAULT 0,
    backed_up BIGINT NOT NULL DEFAULT 0,
    deleted BIGINT NOT NULL DEFAULT 0,
    missing_after BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (table_name)
);

SET @tbl := 'creature_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);


SET @tbl := 'gameobject_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);


SET @tbl := 'item_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);


SET @tbl := 'fishing_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);


SET @tbl := 'skinning_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);


SET @tbl := 'pickpocketing_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);


SET @tbl := 'reference_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);


SET @tbl := 'prospecting_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);


SET @tbl := 'milling_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);


SET @tbl := 'disenchant_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);


SET @tbl := 'spell_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);


SET @tbl := 'mail_loot_template';
SET @tbl_exists := 0;
SET @item_col := NULL;
SET @entry_col := NULL;
SET @missing_before := 0;
SET @backed_up := 0;
SET @deleted := 0;
SET @missing_after := 0;
SELECT COUNT(*) INTO @tbl_exists FROM information_schema.tables WHERE table_schema='world' AND table_name=@tbl;
SET @sql := IF(@tbl_exists=1,
    CONCAT("SELECT CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Item') THEN 'Item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='item') THEN 'item' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='itemid') THEN 'itemid' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='ItemID') THEN 'ItemID' ELSE NULL END, CASE WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='Entry') THEN 'Entry' WHEN EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='world' AND table_name='", @tbl, "' AND column_name='entry') THEN 'entry' ELSE NULL END INTO @item_col, @entry_col"),
    CONCAT("SELECT 'SKIP: table missing -> ", @tbl, "' AS note")
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @process := IF(@tbl_exists=1 AND @item_col IS NOT NULL AND @item_source_count>0,1,0);
SET @status_note := IF(@tbl_exists=0, 'SKIP: table missing', IF(@item_col IS NULL, 'SKIP: item column missing', IF(@item_source_count=0, 'SKIP: no item sources', 'OK')));
SET @valid_predicate := CONCAT(
    IF(@src_world_item_template_exists = 1 AND @src_world_item_template_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_template` s_wit WHERE s_wit.`", @src_world_item_template_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_world_item_sparse_exists = 1 AND @src_world_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `world`.`item_sparse` s_wis WHERE s_wis.`", @src_world_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_sparse_exists = 1 AND @src_hotfixes_item_sparse_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item_sparse` s_his WHERE s_his.`", @src_hotfixes_item_sparse_pk, "` = t.`", @item_col, "`)"), "0"),
    " OR ",
    IF(@src_hotfixes_item_exists = 1 AND @src_hotfixes_item_pk IS NOT NULL, CONCAT("EXISTS (SELECT 1 FROM `hotfixes`.`item` s_hi WHERE s_hi.`", @src_hotfixes_item_pk, "` = t.`", @item_col, "`)"), "0")
);
SET @missing_condition := CONCAT("t.`", @item_col, "` > 0 AND NOT (", @valid_predicate, ")");
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_before FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_before := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backup_table := CONCAT(@tbl, '_backup_genre6a');
SET @do_apply := IF(@process=1 AND @APPLY_FIX=1,1,0);
SET @sql := IF(@do_apply=1, CONCAT("CREATE TABLE IF NOT EXISTS `world`.`", @backup_table, "` LIKE `world`.`", @tbl, "`"), CONCAT("SELECT 'SKIP: apply disabled or prerequisites missing for ', '", @tbl, "' AS note"));
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @sql := IF(@do_apply=1, CONCAT("INSERT IGNORE INTO `world`.`", @backup_table, "` SELECT t.* FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @backed_up := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @backed_up := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@do_apply=1, CONCAT("DELETE t FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @deleted := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
SET @deleted := IF(@do_apply=1, ROW_COUNT(), 0);
SET @sql := IF(@process=1, CONCAT("SELECT COUNT(*) INTO @missing_after FROM `world`.`", @tbl, "` t WHERE ", @missing_condition), "SET @missing_after := 0");
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
INSERT INTO tmp_genre6a_summary (table_name, status_note, missing_before, backed_up, deleted, missing_after)
VALUES (@tbl, @status_note, @missing_before, @backed_up, @deleted, @missing_after)
ON DUPLICATE KEY UPDATE status_note=VALUES(status_note), missing_before=VALUES(missing_before), backed_up=VALUES(backed_up), deleted=VALUES(deleted), missing_after=VALUES(missing_after);

SELECT table_name, status_note, missing_before, backed_up, deleted, missing_after
FROM tmp_genre6a_summary
ORDER BY table_name;

SET @sql := IF(@APPLY_FIX=1, 'COMMIT', 'ROLLBACK');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET autocommit = @OLD_AUTOCOMMIT;
SET unique_checks = @OLD_UNIQUE_CHECKS;
SET foreign_key_checks = @OLD_FOREIGN_KEY_CHECKS;
SET sql_safe_updates = @OLD_SQL_SAFE_UPDATES;

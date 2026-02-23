/* ================================================================== */
/* GENRE 8A — SmartAI dead-record cleanup (Midnight 12.x)             */
/* Safe to re-run until all counts reach 0.                           */
/* ================================================================== */
USE world;
SELECT DATABASE() AS active_database;

/* ============================== */
/* Safety controls                */
/* ============================== */
SET @APPLY_FIX     := 1;       /* 0 = report only, 1 = backup + apply */
SET @DELETE_BATCH  := 950000;  /* max deletes per part per run        */
SET @UPDATE_BATCH  := 950000;  /* max updates per part per run        */

/* ============================== */
/* Snapshot session variables     */
/* ============================== */
SET @save_safe    = @@sql_safe_updates;
SET @save_fk      = @@foreign_key_checks;
SET @save_uq      = @@unique_checks;
SET @save_ac      = @@autocommit;

SET sql_safe_updates   = 0;
SET foreign_key_checks = 0;
SET unique_checks      = 0;
SET autocommit         = 0;

START TRANSACTION;

/* ================================================================== */
/* PART A — Orphaned quest scripts (source_type=5, quest missing)     */
/* ================================================================== */

/* Diagnostics */
SELECT 'PART A: Orphaned quest scripts' AS section;

SELECT COUNT(*) INTO @partA_candidates
FROM smart_scripts ss
WHERE ss.source_type = 5
  AND NOT EXISTS (
    SELECT 1 FROM quest_template qt WHERE qt.ID = ss.entryorguid
  );

SELECT @partA_candidates AS partA_candidate_count;

SELECT ss.entryorguid, ss.source_type, ss.id, ss.link,
       ss.event_type, ss.action_type, ss.comment
FROM smart_scripts ss
WHERE ss.source_type = 5
  AND NOT EXISTS (
    SELECT 1 FROM quest_template qt WHERE qt.ID = ss.entryorguid
  )
LIMIT 50;

/* Apply */
CREATE TABLE IF NOT EXISTS smart_scripts_backup_genre8a_delete LIKE smart_scripts;

SET @partA_deleted = 0;

SET @partA_backup_sql = CONCAT(
'INSERT INTO smart_scripts_backup_genre8a_delete
 SELECT ss.*
 FROM smart_scripts ss
 LEFT JOIN smart_scripts_backup_genre8a_delete bkp
   ON bkp.entryorguid = ss.entryorguid
  AND bkp.source_type = ss.source_type
  AND bkp.id          = ss.id
  AND bkp.link        = ss.link
 WHERE ss.source_type = 5
   AND NOT EXISTS (
     SELECT 1 FROM quest_template qt WHERE qt.ID = ss.entryorguid
   )
   AND bkp.entryorguid IS NULL
   AND ', @APPLY_FIX, ' = 1
 LIMIT ', @DELETE_BATCH
);
PREPARE stmt_partA_backup FROM @partA_backup_sql;
EXECUTE stmt_partA_backup;
DEALLOCATE PREPARE stmt_partA_backup;

SET @partA_delete_sql = CONCAT(
'DELETE FROM smart_scripts
 WHERE source_type = 5
   AND NOT EXISTS (
     SELECT 1 FROM quest_template qt WHERE qt.ID = smart_scripts.entryorguid
   )
   AND ', @APPLY_FIX, ' = 1
 LIMIT ', @DELETE_BATCH
);
PREPARE stmt_partA_delete FROM @partA_delete_sql;
EXECUTE stmt_partA_delete;
SET @partA_deleted = ROW_COUNT();
DEALLOCATE PREPARE stmt_partA_delete;

SELECT IF(@APPLY_FIX = 0, 'PART A: Report-only mode, no changes made',
       CONCAT('PART A: Deleted ', @partA_deleted, ' orphaned quest script rows')) AS partA_result;

/* ================================================================== */
/* PART B — Broken link references (link>0 but target id missing)     */
/* ================================================================== */

SELECT 'PART B: Broken SmartAI link chains' AS section;

SELECT COUNT(*) INTO @partB_candidates
FROM smart_scripts ss
WHERE ss.link <> 0
  AND NOT EXISTS (
    SELECT 1 FROM smart_scripts ss2
    WHERE ss2.entryorguid  = ss.entryorguid
      AND ss2.source_type  = ss.source_type
      AND ss2.id           = ss.link
  );

SELECT @partB_candidates AS partB_candidate_count;

SELECT ss.entryorguid, ss.source_type, ss.id, ss.link,
       ss.event_type, ss.action_type, ss.comment
FROM smart_scripts ss
WHERE ss.link <> 0
  AND NOT EXISTS (
    SELECT 1 FROM smart_scripts ss2
    WHERE ss2.entryorguid  = ss.entryorguid
      AND ss2.source_type  = ss.source_type
      AND ss2.id           = ss.link
  )
LIMIT 50;

/* Apply */
CREATE TABLE IF NOT EXISTS smart_scripts_backup_genre8a_linkfix LIKE smart_scripts;

SET @partB_updated = 0;

SET @partB_backup_sql = CONCAT(
'INSERT INTO smart_scripts_backup_genre8a_linkfix
 SELECT ss.*
 FROM smart_scripts ss
 LEFT JOIN smart_scripts ss2
   ON ss2.entryorguid = ss.entryorguid
  AND ss2.source_type = ss.source_type
  AND ss2.id          = ss.link
 LEFT JOIN smart_scripts_backup_genre8a_linkfix bkp
   ON bkp.entryorguid = ss.entryorguid
  AND bkp.source_type = ss.source_type
  AND bkp.id          = ss.id
  AND bkp.link        = ss.link
 WHERE ss.link <> 0
   AND ss2.entryorguid IS NULL
   AND bkp.entryorguid IS NULL
   AND ', @APPLY_FIX, ' = 1
 LIMIT ', @UPDATE_BATCH
);
PREPARE stmt_partB_backup FROM @partB_backup_sql;
EXECUTE stmt_partB_backup;
DEALLOCATE PREPARE stmt_partB_backup;

SET @partB_update_sql = CONCAT(
'UPDATE smart_scripts
 SET link = 0
 WHERE (entryorguid, source_type, id, link) IN (
   SELECT entryorguid, source_type, id, link
   FROM (
     SELECT ss.entryorguid, ss.source_type, ss.id, ss.link
     FROM smart_scripts ss
     LEFT JOIN smart_scripts ss2
       ON ss2.entryorguid = ss.entryorguid
      AND ss2.source_type = ss.source_type
      AND ss2.id          = ss.link
     WHERE ss.link <> 0
       AND ss2.entryorguid IS NULL
       AND ', @APPLY_FIX, ' = 1
     LIMIT ', @UPDATE_BATCH, '
   ) AS to_fix
 )'
);
PREPARE stmt_partB_update FROM @partB_update_sql;
EXECUTE stmt_partB_update;
SET @partB_updated = ROW_COUNT();
DEALLOCATE PREPARE stmt_partB_update;

SELECT IF(@APPLY_FIX = 0, 'PART B: Report-only mode, no changes made',
       CONCAT('PART B: Fixed ', @partB_updated, ' broken link references (set to 0)')) AS partB_result;

/* ================================================================== */
/* PART C — Invalid quest objective references (event_type=48)        */
/* ================================================================== */

SELECT 'PART C: Invalid quest objective completion events' AS section;

SELECT COUNT(*) INTO @partC_candidates
FROM smart_scripts ss
WHERE ss.event_type = 48
  AND ss.event_param1 > 0
  AND NOT EXISTS (
    SELECT 1 FROM quest_objectives qo WHERE qo.ID = ss.event_param1
  );

SELECT @partC_candidates AS partC_candidate_count;

SELECT ss.entryorguid, ss.source_type, ss.id, ss.event_type,
       ss.event_param1, ss.comment
FROM smart_scripts ss
WHERE ss.event_type = 48
  AND ss.event_param1 > 0
  AND NOT EXISTS (
    SELECT 1 FROM quest_objectives qo WHERE qo.ID = ss.event_param1
  )
LIMIT 50;

/* Apply — reuses the Part A backup table since these are also deletes */
SET @partC_deleted = 0;

SET @partC_backup_sql = CONCAT(
'INSERT INTO smart_scripts_backup_genre8a_delete
 SELECT ss.*
 FROM smart_scripts ss
 LEFT JOIN smart_scripts_backup_genre8a_delete bkp
   ON bkp.entryorguid = ss.entryorguid
  AND bkp.source_type = ss.source_type
  AND bkp.id          = ss.id
  AND bkp.link        = ss.link
 WHERE ss.event_type = 48
   AND ss.event_param1 > 0
   AND NOT EXISTS (
     SELECT 1 FROM quest_objectives qo WHERE qo.ID = ss.event_param1
   )
   AND bkp.entryorguid IS NULL
   AND ', @APPLY_FIX, ' = 1
 LIMIT ', @DELETE_BATCH
);
PREPARE stmt_partC_backup FROM @partC_backup_sql;
EXECUTE stmt_partC_backup;
DEALLOCATE PREPARE stmt_partC_backup;

SET @partC_delete_sql = CONCAT(
'DELETE FROM smart_scripts
 WHERE event_type = 48
   AND event_param1 > 0
   AND NOT EXISTS (
     SELECT 1 FROM quest_objectives qo WHERE qo.ID = smart_scripts.event_param1
   )
   AND ', @APPLY_FIX, ' = 1
 LIMIT ', @DELETE_BATCH
);
PREPARE stmt_partC_delete FROM @partC_delete_sql;
EXECUTE stmt_partC_delete;
SET @partC_deleted = ROW_COUNT();
DEALLOCATE PREPARE stmt_partC_delete;

SELECT IF(@APPLY_FIX = 0, 'PART C: Report-only mode, no changes made',
       CONCAT('PART C: Deleted ', @partC_deleted, ' invalid objective rows')) AS partC_result;

/* ================================================================== */
/* Verification: remaining counts after this run                      */
/* ================================================================== */

SELECT 'POST-RUN VERIFICATION' AS section;

SELECT COUNT(*) INTO @partA_remaining
FROM smart_scripts ss
WHERE ss.source_type = 5
  AND NOT EXISTS (
    SELECT 1 FROM quest_template qt WHERE qt.ID = ss.entryorguid
  );

SELECT COUNT(*) INTO @partB_remaining
FROM smart_scripts ss
WHERE ss.link <> 0
  AND NOT EXISTS (
    SELECT 1 FROM smart_scripts ss2
    WHERE ss2.entryorguid  = ss.entryorguid
      AND ss2.source_type  = ss.source_type
      AND ss2.id           = ss.link
  );

SELECT COUNT(*) INTO @partC_remaining
FROM smart_scripts ss
WHERE ss.event_type = 48
  AND ss.event_param1 > 0
  AND NOT EXISTS (
    SELECT 1 FROM quest_objectives qo WHERE qo.ID = ss.event_param1
  );

SELECT
    @partA_candidates   AS partA_found,
    @partA_deleted      AS partA_deleted,
    @partA_remaining    AS partA_remaining,
    @partB_candidates   AS partB_found,
    @partB_updated      AS partB_fixed,
    @partB_remaining    AS partB_remaining,
    @partC_candidates   AS partC_found,
    @partC_deleted      AS partC_deleted,
    @partC_remaining    AS partC_remaining,
    IF(@APPLY_FIX = 0, 'REPORT-ONLY: No changes were made', 'APPLIED') AS run_mode,
    IF(@partB_remaining > 0, 'NOTE: Part B remaining > 0 may indicate cascading link breaks; re-run script', 'OK') AS cascade_note;

COMMIT;

/* ============================== */
/* Restore session variables      */
/* ============================== */
SET sql_safe_updates   = @save_safe;
SET foreign_key_checks = @save_fk;
SET unique_checks      = @save_uq;
SET autocommit         = @save_ac;

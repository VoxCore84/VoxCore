# Data Import Reference

## Raidbots / Wago / LW Data Pipeline

### Data Sources

#### Raidbots Static Data -- `~/VoxCore/wago/raidbots/`
- URL: `https://www.raidbots.com/static/data/live/<file>.json`
- Build 66192, 47 JSON files, 168MB total
- Key files: `item-names.json` (171K items x 7 locales), `equippable-items-full.json` (107K items), `bonuses.json`, `talents.json`, `azerite.json`, `sim-settings.json`
- **Only ships 7 locales**: en_US + de_DE, es_ES, fr_FR, it_IT, pt_BR, ru_RU. No koKR/zhCN/zhTW/esMX
- Downloaded via curl (WebFetch 10MB limit too small)

#### Wago DB2 CSVs -- `~/VoxCore/wago/wago_csv/major_12/12.0.1.66192/enUS/`
- QuestLineXQuest, QuestLine, QuestObjective, QuestPOIBlob, QuestPOIPoint CSVs
- 1,097 tables total for build 66192

#### LoreWalkerTDB -- `~/VoxCore/ExtTools/LoreWalkerTDB/`
- `world.sql` (897MB) -- extracted via `extract_lw_world.py` into `lw_world_imports/`
- 42 tables extracted total. 21 imported (session 18), 20 skipped (already done), 1 excluded (phase_area)
- **Column mismatches fixed**: creature (28->29, +size), gameobject (24->26, +size/visibility), npc_vendor (11->12, +OverrideGoldCost)

### Import Scripts

| Script | Location | Purpose | Output |
|--------|----------|---------|--------|
| `import_item_names.py` | `raidbots/` | Raidbots item-names.json -> locale SQL | `sql_output/item_sparse_locale.sql`, `item_search_name_locale.sql` |
| `quest_chain_gen.py` | `raidbots/` | Wago QuestLineXQuest CSV -> chain UPDATE SQL | `sql_output/quest_chains.sql` |
| `gen_quest_poi_sql.py` | `raidbots/` | Wago QuestPOIBlob/Point CSVs -> POI INSERT SQL | `sql_output/quest_poi_import.sql`, `quest_poi_points_import.sql` |
| `quest_objectives_import.py` | `raidbots/` | Wago QuestObjective CSV -> objectives INSERT SQL | `sql_output/quest_objectives_import.sql` |
| `extract_lw_world.py` | `wago/` | LoreWalkerTDB world.sql -> per-table INSERT IGNORE SQL | `lw_world_imports/lw_*.sql` |
| `fix_column_mismatch.py` | `lw_world_imports/` | Fix LW column mismatches (creature/gameobject/npc_vendor) | `lw_*_fixed.sql` |
| `import_all.py` | `lw_world_imports/` | Master 5-phase import with validation | Direct DB import |
| `validate_import.py` | `lw_world_imports/` | 15-check orphan/integrity validator | Console output |
| `post_import_cleanup.sql` | `lw_world_imports/` | Post-import SmartAI/vendor/pool/waypoint/spawn cleanup | Direct DB |
| `find_dupe_spawns.py` | `wago/` | Python duplicate spawn detector (TSV->GUID list) | `*_dupe_guids.txt` |
| `batch_delete_dupes.py` | `wago/` | Batch DELETE duplicate spawn GUIDs (500/batch) | Direct DB |

### Fix Scripts

| Script | Purpose | Output |
|--------|---------|--------|
| `fix_quest_chains.sql` | Self-refs, depth-only CTE N-hop cycle detection, dynamic dangling ref cleanup | `sql_output/` |
| `fix_locale_and_orphans.sql` | Dedupes locale rows (build 61609), NULL Display_lang, orphan quest_objectives | `sql_output/` |
| `fix_orphan_quest_refs.sql` | Orphan quest starters/enders (961 rows, creature + GO) | `sql_output/` |

### Orchestrator

| Script | Location | Purpose |
|--------|----------|---------|
| `run_all_imports.py` | `raidbots/` | Master 8-step execution script with `--dry-run`, `--step N`, `--skip-verification` |

Execution order: (1) quest_chains -> (2) fix_quest_chains -> (3) quest_objectives -> (4) quest_poi -> (5) quest_poi_points -> (6) item_sparse_locale -> (7) item_search_name_locale -> (8) fix_locale_and_orphans

### LW Bulk Import State (verified Mar 3 2026, session 18)

| Table | Before | After | Net |
|-------|--------|-------|-----|
| creature | 652,516 | 681,712 | +29,196 |
| gameobject | 174,195 | 193,799 | +19,604 |
| creature_loot_template | 2,958,593 | 3,142,677 | +184,084 |
| gameobject_loot_template | 65,953 | 124,019 | +58,066 |
| smart_scripts | 458,850 | 795,036 | +336,186 |
| waypoint_path_node | 130,806 | 160,784 | +29,978 |
| creature_template_difficulty | 505,637 | 505,637 | +0 (26K imported, all orphaned) |
| creature_addon | 81,347 | 83,345 | +1,998 |
| gameobject_addon | 25,783 | 26,426 | +643 |
| waypoint_path | 7,092 | 9,038 | +1,946 |
| pool_template | 2,139 | 3,945 | +1,806 |
| pool_members | 11,501 | 12,950 | +1,449 |
| spawn_group | 91,327 | 91,484 | +157 |
| creature_text | 52,641 | 52,811 | +170 |
| creature_template_spell | 9,450 | 9,606 | +156 |
| creature_model_info | 110,067 | 110,132 | +65 |
| gossip_menu | 17,090 | 17,148 | +58 |
| gossip_menu_option | 13,946 | 13,990 | +44 |
| creature_template_addon | 27,925 | 27,934 | +9 |
| creature_formations | 2,339 | 2,378 | +39 |
| npc_vendor | 166,103 | 166,107 | +4 |
| **TOTAL** | **5,565,300** | **6,230,958** | **+665,658** |

**Validation**: All 15 orphan checks CLEAN. Zero integrity issues.

**Critical lesson**: `creature_loot_template` and `gameobject_loot_template` have NO PRIMARY KEY (only non-unique index). INSERT IGNORE does nothing -- must use CSV round-trip dedup (`sort -u`) after import.

### Post-Import Cleanup (session 20)

After LW import, worldserver had ~627K error lines. Cleanup removed 47,478 rows:

| Task | Description | Rows Deleted |
|------|------------|-------------|
| SmartAI (obj=0, bad spells, non-SmartAI, unsupported types, missing WP/GUID) | 2,808 |
| Reference loot orphans | 0 (none) |
| NPC vendor (bad items + no flag) | 305 |
| Empty pool_templates | 1,806 |
| Empty waypoint_paths | 47 |
| Duplicate creature spawns (< 1 yard) | 19,385 |
| Duplicate GO spawns (< 1 yard) | 18,485 |
| Orphaned dependents from spawn deletion | 4,642 |

**Key findings**:
- Event type 47 (`SMART_EVENT_QUEST_ACCEPTED`) is SUPPORTED -- 105K rows preserved
- `gameobject_loot_template` has NO `Reference` column (only creature_loot has it)
- SQL self-joins on 681K rows impractical -- Python `find_dupe_spawns.py` does it instantly
- Spell validation: `hotfixes.spell_name` (400K, use EXISTS) + `world.serverside_spell` (4.4K, col `Id`)

**Scripts**: `post_import_cleanup.sql`, `find_dupe_spawns.py`, `batch_delete_dupes.py`

### Final Data State (verified Mar 3 2026, post-cleanup)

#### Item Locales (`hotfixes`)
| Table | Total Rows | Build 66192 | Build 61609 (base) |
|-------|-----------|-------------|---------------------|
| item_sparse_locale | 1,020,171 | 1,020,028 | 143 |
| item_search_name_locale | 608,480 | 608,364 | 116 |

6 full locales (~170K/~101K each): deDE, esES, frFR, itIT, ptBR, ruRU
4 stub locales (29-59 each): esMX, koKR, zhCN, zhTW (TC base data only)

#### Quest Chains (`world.quest_template_addon`)
- 47,164 total rows
- 21,758 with PrevQuestID (46.1%)
- 17,636 with NextQuestID (37.4%)
- 1,862 chain starters
- 32 negative PrevQuestID (exclusion semantics, expected)
- **Zero integrity issues** (self-refs, circulars, danglers all clean)

#### Quest POI (`world`)
| Table | Total | From Our Import (build 66192) |
|-------|-------|-------------------------------|
| quest_poi | 134,856 | 2,880 |
| quest_poi_points | 292,977 | 5,199 |

#### Quest Objectives (`world.quest_objectives`)
- 60,199 total, 633 from our import (build 66192)

#### Quest Starters/Enders (`world`)
| Table | Rows |
|-------|------|
| creature_queststarter | 26,842 |
| creature_questender | 33,496 |
| gameobject_queststarter | 1,615 |
| gameobject_questender | 1,610 |

### Bugs Fixed in Scripts

#### Session 14 (initial build)
1. `wowhead_scraper.py` -- Mapper regex lazy match truncated at first `}` -> bracket-depth parser
2. `wowhead_scraper.py` -- `extract_gatherer_data()` nested objects -> bracket-depth parsing
3. `wowhead_scraper.py` -- `extract_js_object()` only handled `"` strings -> added `'` via `string_char`
4. `wowhead_scraper.py` -- progress/completion `find_next("div")` -> `find_next_sibling()`
5. `import_item_names.py` -- Missing 4 locales -> added koKR, zhCN, zhTW, esMX
6. `import_item_names.py` -- No NUL byte escaping -> added `\x00`->`\0`, `\x1a`->`\Z`
7. `gen_quest_poi_sql.py` -- No `USE world;` -> added
8. `gen_quest_poi_sql.py` -- `int()` crash on mysql warnings -> try/except
9. `quest_objectives_import.py` -- `int(r["ID"])` crash -> try/except

#### Session 16 (QA sweep -- 11 tasks)
10. `quest_chain_gen.py` -- Cross-chain conflict detection (lowest QuestLine ID wins)
11. `quest_chain_gen.py` -- DFS cycle detection, self-ref prevention, dedup
12. `wowhead_scraper.py` -- `extract_listview_data()` missing string/escape handling
13. `wowhead_scraper.py` -- `RateLimiter` not thread-safe -> `threading.Lock()`
14. `wowhead_scraper.py` -- No checkpoint resume -> high-water-mark tracking
15. `wowhead_scraper.py` -- Extracted `_find_matching_bracket()` shared helper
16. `fix_quest_chains.sql` -- Column `QuestId`->`ID`, path CTE->depth-only (CHAR overflow)
17. `import_item_names.py` -- No VerifiedBuild idempotency -> DELETE-before-INSERT
18. `import_item_names.py` -- `VALUES()` deprecated -> `AS new` alias syntax
19. `import_item_names.py` -- Stub locale guard: skip DELETE when no replacement data
20. `gen_quest_poi_sql.py` -- Warning parsing, `--force` flag, transaction wrapping
21. `quest_objectives_import.py` -- Dead code removal, Type validation (0-22)
22. `fix_locale_and_orphans.sql` -- NOT IN->NOT EXISTS (NULL trap), scoped DELETE

### Reimport Procedure

Use `run_all_imports.py` for automated execution:
```
python run_all_imports.py              # Run all 8 steps
python run_all_imports.py --dry-run    # Preview commands
python run_all_imports.py --step 4     # Resume from step 4
```

Manual order (fix_quest_chains BEFORE quest_chains):
1. `fix_quest_chains.sql` -- clean self-refs, cycles, dangling refs
2. `quest_chains.sql` -- import quest chain data
3. `quest_objectives_import.sql` -- import quest objectives
4. `quest_poi_import.sql` -- import quest POI
5. `quest_poi_points_import.sql` -- import quest POI points
6. `item_sparse_locale.sql` -- import item locale data
7. `item_search_name_locale.sql` -- import search name locale data
8. `fix_locale_and_orphans.sql` -- cleanup dupes + orphans

### Key Technical Lessons
- **CTE depth-only approach**: Path-based CTEs overflow CHAR(65535) on 47K+ row datasets. Depth-only `WHERE next_id = start_id` is complete for functional graphs (out-degree <=1)
- **`cte_max_recursion_depth`**: MySQL default 1000 too low -- set to 5000 for quest chain dataset
- **`VALUES()` deprecated**: MySQL 8.0.20+ -- use `INSERT ... AS new ON DUPLICATE KEY UPDATE col = new.col`
- **NOT IN NULL trap**: If subquery returns any NULL, NOT IN evaluates to UNKNOWN (deletes 0 rows). Always use NOT EXISTS
- **Stub locale guard**: When doing DELETE-before-INSERT, only DELETE for locales that have replacement data
- **Type range 0-22**: MAX_QUEST_OBJECTIVE_TYPE tracks TC source. Max in CSV data is 21 -- headroom of 22 avoids script changes when Blizzard adds a new type
- **Visible=1 default**: Correct -- TC evaluates visibility dynamically at runtime from StorageIndex+Type. DB column is a hint. Don't infer Visible=0 from StorageIndex=-1 (duplicates game logic in wrong layer)
- **Manual SQL escaping**: Sufficient for Wago CSV data (controlled input). Would need parameterized queries for blob data or adversarial strings

### Deployment Status
- **DEPLOYED AND VERIFIED** (Mar 3 2026). Zero cycles, all counts validated against baseline
- Commit `b69303d` on wago-tooling master (pushed)

### Execution Checklist (before running for real)
1. `python run_all_imports.py --dry-run` -- validate all 8 SQL files exist
2. Back up databases: at minimum `quest_template_addon`, `item_sparse_locale`, `item_search_name_locale`
3. `python run_all_imports.py` -- full pipeline (auto-verifies zero cycles at end)
4. `fix_orphan_quest_refs.sql` -- run manually as one-off (not in the 8-step pipeline)
5. Spot-check quest chains in-game: confirm PrevQuestID/NextQuestID gating works

### Important Notes
- **Execution order**: quest_chains.sql BEFORE fix_quest_chains.sql (fix must run after import to catch self-refs from source data)
- **`--regenerate` flag**: Use for future build bumps -- reruns all 4 Python generators before SQL execution, prevents stale SQL files
- **Backups**: `raidbots/backups/` has hotfixes (1.1GB) and world (826MB) pre-import dumps from first deployment

### Wowhead Scraping Status
- **403 blocked**: www.wowhead.com page requests blocked by CloudFront WAF (from 216K NPC scrape)
- **Tooltip API works**: nether.wowhead.com/tooltip/ still accessible
- **Quest scrape ready**: 68,604 IDs in `quest_ids_all.txt`, enhanced parser with ~30 fields. Blocked by 403
- **Vendor scrape ready**: 6,735 IDs in `vendor_npc_ids.txt`. Blocked by 403
- Pivoted to Wago DB2 + LoreWalkerTDB as alternative data sources

---

## LoreWalkerTDB Reference

### Location
- `~/VoxCore/ExtTools/LoreWalkerTDB/`
- Files: `world.sql` (897MB), `hotfixes.sql` (322MB), `auth_trigger_events.sql`, `characters_trigger_events.sql`, `ReadMe.txt`
- Builds: 65893, 65727, 65299, 63906 (all 12.0.x)

### Hotfixes Import (Feb 2026) -- COMPLETE
- 471 tables total, 193 with data
- Extraction used Python script to parse mysqldump, filter by TableHash, generate INSERT IGNORE SQL
- Major gains: spell_item_enchantment (+1193), sound_kit (+3611), item/item_sparse (+2799/+2810), spell_effect (+1335), spell_visual_kit (+610), creature_display_info (+123), phase (+595), achievement (+849), lfg_dungeons (+213), trait_definition (+299), character_loadout (+6/+151), plus ~30K hotfix_data entries
- Skipped: locale tables, chr_customization_choice (custom), broadcast_text (has custom entries at 999999997+)
- LW trigger files (auth/characters) skipped -- tied to LW's custom quest system

### SmartAI Import (Feb 2026) -- COMPLETE (2 rounds)
- **Round 1** (earlier): 22,370 rows from TSV. 17,367 quest type=5, 4,965 creature type=0, 29 scene, 6 timed, 2 areatrigger, 1 GO
- **Round 2** (Feb 27): Full re-extraction using string-aware parser on 897MB dump
  - Pass 1: 1,242 creature rows (472 unique entries) from missing SmartAI list
  - Pass 2: 166,443 new rows -- 165,360 creature, 169 GO, 702 actionlist, 212 scene
  - Skipped: 525K quest type=5 boilerplate (all cast spell 82238), 25 orphan actionlists
- **Final DB state**: 459,175 smart_scripts total (250K creature, 1.3K GO, 14.3K actionlist, 3.7K scene)

### World DB Bulk Import from LW (Feb 27, 2026) -- COMPLETE
- Comprehensive quality audit before import -- checked every table for orphans, empty rows, junk data
- **Key finding**: quest_template_addon gap (+57K) was 100% empty placeholders -- correctly skipped
- **Key finding**: spawn_group (+3.5K) and gameobject_addon (+2.4K) were 100% orphans -- correctly skipped

#### Rows imported (all INSERT IGNORE, idempotent):
| Table | New Rows |
|---|---|
| smart_scripts (2 passes) | 167,685 |
| creature_loot_template | 151,509 |
| gameobject_loot_template | 59,893 |
| pickpocketing_loot_template | 1,389 |
| reference_loot_template | 662 |
| skinning_loot_template | 402 |
| quest_offer_reward | 541 |
| quest_request_items | 370 |
| pool_template | 1,176 |
| pool_members | 1,164 |
| game_event_creature | 260 |
| game_event_gameobject | 164 |
| npc_vendor | 248 |
| conversation_actors | 194 |
| areatrigger_template | 142 |
| conversation_line_template | 19 |
| conversation_template | 5 |
| **Grand total** | **385,823** |

#### SQL files (all in sql/exports/):
lw_missing_smartai.sql, lw_smartai_remaining.sql, lw_creature_loot.sql, lw_gameobject_loot.sql,
lw_game_events.sql, lw_pools.sql, lw_loot_convos.sql, lw_quest_tables.sql, lw_world_tables.sql

#### Tables verified identical (no import needed):
trainer, trainer_spell, creature_onkill_reputation, creature_template_movement, spell_area,
disables, creature_template_addon, creature_addon, creature_formations, creature_classlevelstats

#### Remaining gaps (not importable from LW):
- 10,944 creatures with AIName='SmartAI' but no scripts (not in LW either)
- 29,395 creatures missing creature_template_difficulty (only ~52 new in LW)
- 29,651 quests missing quest_offer_reward (LW only had 541 more)
- spawn_group/gameobject_addon gaps are orphans (need spawns we don't have)

### Spell Hotfixes Created
- Spell 82238 "Update Phase Shift" (SPELL_EFFECT_UPDATE_PLAYER_PHASE=167)
- Spell 1258081 "Key to the Arcantina"
- Added to hotfixes DB: spell_name + spell_misc + spell_effect + hotfix_data
- Modeled after existing spell 1284555 as template
- TableHashes: SpellName=1187407512, SpellMisc=3322146344, SpellEffect=4030871717

### World DB Cleanup (Feb 2026)
- Removed 381K orphaned rows from LW import (creature_text, conditions, smart_scripts, waypoints, etc.)
- Removed 10K orphaned loot templates + stale conditions/creature_text

### Gotchas
- **`spell_misc` table has 35 columns** (gained `ActiveSpellVisualScript` since older SQL files were written -- watch for column count mismatches in old REPLACE statements)

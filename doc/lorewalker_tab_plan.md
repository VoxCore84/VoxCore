# LoreWalker TDB Import — Execution Plan & Tab Assignments

> Review this document first. Once approved, open tabs and paste the master prompt from `doc/lorewalker_import_prompt.md`.

## Summary

| Metric | Value |
|--------|-------|
| Source DB | `lorewalker_world` (935MB, build 66102, Mar 6 2026) |
| Target DB | `world` (build 66263) |
| Total SQL files | 7 |
| Total tables touched | 53 |
| Total INSERT rows | ~482,000 |
| Total UPDATE rows | ~7,685 |
| Tabs needed | **3** |

## File Structure (7 files, ordered by dependency)

### File 1: Phases (~1,279 rows) — QUICK WIN
| Table | Rows | Notes |
|-------|------|-------|
| phase_area | 662 | Highest impact — invisible NPCs without this |
| phase_name | 617 | Phase labels |

### File 2: Templates (~4,450 rows)
| Table | Rows | Notes |
|-------|------|-------|
| creature_template | 10 | New creatures only, < 9100000 |
| creature_template_difficulty | 20 | 13 for new + 7 for existing templates |
| creature_template_model | 13 | Visual models for new creatures |
| creature_template_addon | 125 | Template-level visual addons |
| creature_template_spell | 163 | Creature spell lists |
| creature_equip_template | 2,023 | NPC weapons/shields — without this, NPCs appear unarmed |
| gameobject_template | 2,089 | New game objects |
| gameobject_template_addon | ~10 | GO template addons |

### File 3: Quests (~98,000 rows)
| Table | Rows | Notes |
|-------|------|-------|
| quest_template | 198 | New quests (< 9100000) |
| quest_template_addon | 57,611 | Metadata for new AND existing quests |
| quest_objectives | 888 | Objective definitions |
| quest_details | 962 | Detail text |
| quest_offer_reward | 551 | Reward offer text |
| quest_request_items | 1,894 | "You will also need" text |
| quest_poi | 10,424 | **NEW** — quest map markers |
| quest_poi_points | 23,476 | **NEW** — map marker polygon vertices |
| quest_visual_effect | 545 | Visual effects on objectives |
| creature_queststarter | 889 | Quest givers (INSERT IGNORE — preserves our data) |
| creature_questender | 714 | Quest enders (INSERT IGNORE — preserves our data) |
| gameobject_queststarter | 154 | GO quest givers |
| gameobject_questender | 162 | GO quest enders |
| creature_questitem | 258 | Quest items from creatures |
| gameobject_questitem | 519 | Quest items from GOs |

### File 4: Spawns (~132,000 rows)
| Table | Rows | Notes |
|-------|------|-------|
| creature | 101,018 | Open world + instance spawns |
| gameobject | 1,290 | After corrupt GUID + origin + orphan filters |
| creature_addon | 16,640 | Per-spawn visual data |
| gameobject_addon | ~200 | Per-spawn GO data |
| creature_movement_override | ~100 | Movement overrides |
| spawn_group | 10,145 | **NEW** — spawn group membership (phased/boss-controlled) |
| pool_template | 1,886 | **NEW** — random spawn pool definitions |
| pool_members | 240 | **NEW** — pool membership |
| creature_formations | 1,475 | **NEW** — group movement formations |
| game_event_creature | 1,376 | **NEW** — seasonal/event creature spawns |
| game_event_gameobject | 10,791 | **NEW** — seasonal/event GO spawns |

### File 5: Behavioral (~176,000 rows)
| Table | Rows | Notes |
|-------|------|-------|
| smart_scripts | 170,518 | source_type IN (0,1,2,9) only |
| waypoint_path | 61 | Patrol path definitions |
| waypoint_path_node | 87 | Nodes for new paths only |
| npc_vendor | 3,910 | Vendor items (explicit columns, excludes OverrideGoldCost) |
| gossip_menu | 399 | Gossip menu entries |
| gossip_menu_option | 279 | Gossip menu options |
| npc_text | 343 | **NEW** — gossip text bodies (needed by gossip_menu) |
| creature_text | 235 | **NEW** — creature say/yell/emote text |
| scene_template | 195 | Cutscene data |
| conditions | 1,044 | **NEW** — conditional logic for gossip/loot/quests |

### File 6: Loot (~63,000 rows) — SPECIAL HANDLING
| Table | Rows | Notes |
|-------|------|-------|
| reference_loot_template | 51 | Must come FIRST (referenced by GO loot) |
| gameobject_loot_template | 60,244 | Uses `WHERE NOT EXISTS` (no PK!) |
| pickpocketing_loot_template | 1,389 | Uses `WHERE NOT EXISTS` (no PK) |
| skinning_loot_template | 402 | Uses `WHERE NOT EXISTS` (no PK) |
| item_loot_template | 110 | Uses `WHERE NOT EXISTS` (no PK) |
| spell_loot_template | 64 | Uses `WHERE NOT EXISTS` (no PK) |

**Why special**: All `*_loot_template` tables have NO primary key or unique index. `INSERT IGNORE` would blindly insert duplicates on re-run. Must use `WHERE NOT EXISTS` matching on `(Entry, ItemType, Item)` for idempotency.

### File 7: Backfill (~7,685 updates)
| Table | Rows | Notes |
|-------|------|-------|
| creature_template_difficulty | 7,678 | UPDATE — fill ContentTuningID where ours = 0 |

## Execution Order (MANDATORY)

```
File 1 ─┐
File 2 ─┤ (templates must exist before spawns/quests reference them)
        ├→ File 3 ─→ (quests — needs templates)
        └→ File 4 ─→ File 5 ─→ (spawns before behavioral — addons reference GUIDs)
                               └→ File 6 (loot — reference_loot before GO loot)
File 7 ─── (independent — can run anytime)
```

Apply order: **1 → 2 → 3 → 4 → 5 → 6 → 7**

## Tab Assignments (3 Tabs)

### Tab 1: Foundations (Files 1, 2, 3, 7)
**Scope**: Phases + Templates + Quests + Backfill
**Tables**: 25
**Est. rows**: ~106,000 inserts + 7,685 updates
**Complexity**: LOW-MEDIUM — mostly straightforward INSERT IGNORE with LEFT JOIN exclusion. Quest tables are numerous but formulaic.

**Instructions for tab**: Paste `doc/lorewalker_import_prompt.md`, then say:
> Generate SQL update files for **Files 1, 2, 3, and 7** only. Follow all rules in the prompt. DESCRIBE every table in both databases before writing any INSERT. Use explicit column lists for tables with schema differences. Output to `sql/updates/world/master/2026_03_08_NN_world.sql` using the next available sequence numbers.

### Tab 2: Spawns (Files 4)
**Scope**: All spawn/placement data
**Tables**: 11
**Est. rows**: ~132,000
**Complexity**: MEDIUM-HIGH — creature/gameobject tables have extra columns (size, visibility) that must be excluded. Must DESCRIBE both DBs. Largest single-file row count.

**Instructions for tab**: Paste `doc/lorewalker_import_prompt.md`, then say:
> Generate SQL update file for **File 4** only. Follow all rules in the prompt. This is the biggest file — creature and gameobject tables have extra columns on our side that must be excluded from the SELECT. DESCRIBE `creature` and `gameobject` in BOTH `world` and `lorewalker_world` before writing. Wrap in `SET autocommit=0;` / `COMMIT;`. Output to `sql/updates/world/master/2026_03_08_NN_world.sql`.

### Tab 3: Behavioral + Loot (Files 5, 6)
**Scope**: SmartAI, waypoints, vendors, gossip, text, scenes, conditions, all loot tables
**Tables**: 16
**Est. rows**: ~239,000
**Complexity**: HIGH — SmartAI needs careful filtering. All loot tables need `WHERE NOT EXISTS` (no PKs). Column `ItemType` (NOT `Reference`!) on loot tables.

**Instructions for tab**: Paste `doc/lorewalker_import_prompt.md`, then say:
> Generate SQL update files for **Files 5 and 6** only. Follow all rules in the prompt. CRITICAL: All `*_loot_template` tables have NO primary key — use `WHERE NOT EXISTS` matching on `(Entry, ItemType, Item)` instead of INSERT IGNORE. The column is `ItemType`, NOT `Reference`. DESCRIBE `smart_scripts` and all loot tables before writing. Wrap File 5 in `SET autocommit=0;` / `COMMIT;`. Output to `sql/updates/world/master/2026_03_08_NN_world.sql`.

## Why 3 Tabs (Not 4 or 5)

- **MySQL contention**: All tabs hit the same MySQL instance for DESCRIBEs. 3 concurrent connections is manageable; 5 starts competing.
- **Context budget**: Each tab needs the full master prompt (~300 lines) plus room for 100+ DESCRIBE outputs and SQL generation. 3 tabs each doing ~15 tables stays within budget.
- **Balanced workload**: Tab 1 has the most tables (25) but they're small/formulaic. Tab 2 has the most rows (132K) but fewest tables (11). Tab 3 has the most complexity (loot PKs, SmartAI filters).
- **Conflict avoidance**: Each tab writes to different sequence-numbered SQL files. No file overlaps.

## What To Review Before Approving

1. **"We lead" tables being imported with INSERT IGNORE**: `creature_queststarter` (889 rows), `creature_questender` (714 rows), and `npc_vendor` (3,910 rows) are now being imported. INSERT IGNORE preserves all our existing rows. If you intentionally removed any of these, they'd come back. OK?

2. **SmartAI source_types 3, 10, 12**: The filter imports types 0, 1, 2, 9 only. LW has 655 additional rows in types 3 (8 rows), 6 (1), 10 (10), 11 (2), 12 (644). Type 12 has the most — likely `spell` source_type in newer TC. Want to add type 12 to the filter? Or skip all non-standard types?

3. **Loot tables**: `creature_loot_template` is still protected (we lead with 50K extra rows from raidbots). But `gameobject_loot_template` (60K rows) and other loot types ARE being imported. Acceptable?

4. **waypoint_path_node scope**: Only importing nodes for the 61 NEW paths (87 rows). There may be ~50K nodes for EXISTING paths that we're missing, but importing those risks overriding our pathing. Current approach: conservative. Want to expand?

5. **quest auxiliary data for existing quests**: quest_template_addon (57K), quest_details (962), etc. include data for quests that already exist in our DB but are missing metadata. These are INSERT IGNORE so they only add missing rows, never overwrite. Good?

## Post-Execution Checklist

After all 7 files are generated and reviewed:
1. Apply in order: 1 → 2 → 3 → 4 → 5 → 6 → 7
2. Use `/apply-sql world` or direct `mysql -u root -padmin world < file.sql`
3. Check `DBErrors.log` after each file
4. Restart worldserver to pick up new phase data
5. Spot-check in-game: pick a zone with known missing NPCs, verify they appear

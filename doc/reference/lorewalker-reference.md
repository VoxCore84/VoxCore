# LoreWalkerTDB Reference

## Location
- `C:\Tools\LoreWalkerTDB\`
- Files: `world.sql` (897MB), `hotfixes.sql` (322MB), `auth_trigger_events.sql`, `characters_trigger_events.sql`, `ReadMe.txt`
- Builds: 65893, 65727, 65299, 63906 (all 12.0.x)

## Hotfixes Import (Feb 2026) — COMPLETE
- 471 tables total, 193 with data
- Extraction used Python script to parse mysqldump, filter by TableHash, generate INSERT IGNORE SQL
- Major gains: spell_item_enchantment (+1193), sound_kit (+3611), item/item_sparse (+2799/+2810), spell_effect (+1335), spell_visual_kit (+610), creature_display_info (+123), phase (+595), achievement (+849), lfg_dungeons (+213), trait_definition (+299), character_loadout (+6/+151), plus ~30K hotfix_data entries
- Skipped: locale tables, chr_customization_choice (custom), broadcast_text (has custom entries at 999999997+)
- LW trigger files (auth/characters) skipped — tied to LW's custom quest system

## SmartAI Import (Feb 2026) — COMPLETE (2 rounds)
- **Round 1** (earlier): 22,370 rows from TSV. 17,367 quest type=5, 4,965 creature type=0, 29 scene, 6 timed, 2 areatrigger, 1 GO
- **Round 2** (Feb 27): Full re-extraction using string-aware parser on 897MB dump
  - Pass 1: 1,242 creature rows (472 unique entries) from missing SmartAI list
  - Pass 2: 166,443 new rows — 165,360 creature, 169 GO, 702 actionlist, 212 scene
  - Skipped: 525K quest type=5 boilerplate (all cast spell 82238), 25 orphan actionlists
- **Final DB state**: 459,175 smart_scripts total (250K creature, 1.3K GO, 14.3K actionlist, 3.7K scene)

## World DB Bulk Import from LW (Feb 27, 2026) — COMPLETE
- Comprehensive quality audit before import — checked every table for orphans, empty rows, junk data
- **Key finding**: quest_template_addon gap (+57K) was 100% empty placeholders — correctly skipped
- **Key finding**: spawn_group (+3.5K) and gameobject_addon (+2.4K) were 100% orphans — correctly skipped

### Rows imported (all INSERT IGNORE, idempotent):
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

### SQL files (all in sql/exports/):
lw_missing_smartai.sql, lw_smartai_remaining.sql, lw_creature_loot.sql, lw_gameobject_loot.sql,
lw_game_events.sql, lw_pools.sql, lw_loot_convos.sql, lw_quest_tables.sql, lw_world_tables.sql

### Tables verified identical (no import needed):
trainer, trainer_spell, creature_onkill_reputation, creature_template_movement, spell_area,
disables, creature_template_addon, creature_addon, creature_formations, creature_classlevelstats

### Remaining gaps (not importable from LW):
- 10,944 creatures with AIName='SmartAI' but no scripts (not in LW either)
- 29,395 creatures missing creature_template_difficulty (only ~52 new in LW)
- 29,651 quests missing quest_offer_reward (LW only had 541 more)
- spawn_group/gameobject_addon gaps are orphans (need spawns we don't have)

## Spell Hotfixes Created
- Spell 82238 "Update Phase Shift" (SPELL_EFFECT_UPDATE_PLAYER_PHASE=167)
- Spell 1258081 "Key to the Arcantina"
- Added to hotfixes DB: spell_name + spell_misc + spell_effect + hotfix_data
- Modeled after existing spell 1284555 as template
- TableHashes: SpellName=1187407512, SpellMisc=3322146344, SpellEffect=4030871717

## World DB Cleanup (Feb 2026)
- Removed 381K orphaned rows from LW import (creature_text, conditions, smart_scripts, waypoints, etc.)
- Removed 10K orphaned loot templates + stale conditions/creature_text

## Gotchas
- **`spell_misc` table has 35 columns** (gained `ActiveSpellVisualScript` since older SQL files were written — watch for column count mismatches in old REPLACE statements)

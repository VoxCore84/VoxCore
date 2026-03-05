# Loot Table Schema & Validation Reference

## Loot Template Columns
Most `*_loot_template` tables share this schema:
```
Entry (uint), ItemType (tinyint), Item (uint), Chance (float), QuestRequired (tinyint),
LootMode (smallint), GroupId (tinyint), MinCount (tinyint), MaxCount (tinyint), Comment
```
- ItemType: 0=Item, 1=Reference, 2=Currency, 3=TrackingQuest
- Primary key: (Entry, ItemType, Item)

**Exception**: `creature_loot_template` has an extra `Reference` column (nullable int). For reference entries in creature_loot_template, use `WHERE Reference IN (...)`. For all other loot tables, use `WHERE ItemType=1 AND Item IN (...)`.

## Where Loot References Live

| Loot Table | Source Table | Source Column(s) | Notes |
|---|---|---|---|
| creature_loot_template | creature_template_difficulty | LootID | |
| skinning_loot_template | creature_template_difficulty | SkinLootID | |
| pickpocketing_loot_template | creature_template_difficulty | PickPocketLootID | |
| gameobject_loot_template | gameobject_template | Data1 (types 3,25,50) | Also Data30, Data33 for type 3 |
| item_loot_template | (DB2 ItemSparse) | ITEM_FLAG_HAS_LOOT (0x04) | **Cannot fix via SQL** |
| milling_loot_template | (DB2 ItemSparse) | ITEM_FLAG_IS_MILLABLE (0x20000000) | **Cannot fix via SQL** |
| prospecting_loot_template | (DB2 ItemSparse) | ITEM_FLAG_IS_PROSPECTABLE (0x40000) | **Cannot fix via SQL** |
| spell_loot_template | (DB2 Spell) | IsLootCrafting() attribute | **Cannot fix via SQL** |
| disenchant_loot_template | (DB2 ItemDisenchantLoot/ItemBonus) | ID / Value[0] | **Cannot fix via SQL** |
| fishing_loot_template | (DB2 AreaTable) | area ID = loot ID | |
| mail_loot_template | (DB2 MailTemplate) | template ID = loot ID | |
| scrapping_loot_template | (DB2 ItemScrappingLoot) | ID | **Cannot fix via SQL** |
| reference_loot_template | Other loot tables | ItemType=1, Item=ref ID | Cross-referenced |

## Gameobject Types with Loot
- Type 3 = CHEST: Data1 (chestLoot), Data30 (chestPersonalLoot), Data33 (chestPushLoot)
- Type 25 = FISHINGHOLE: Data1 (chestLoot)
- Type 50 = GATHERING_NODE: Data1 (chestLoot)
- `GetLootId()` returns Data1 for these types, 0 for others

## Validation Thresholds (LootMgr.cpp)
- Group chance overflow: >101.0% (not strict 100%)
- Low chance skip: >0 but <0.0001
- MinCount must be >=1, MaxCount must be >= MinCount
- QuestRequired on Reference (ItemType=1) items is always invalid

## Key Source Files
- `src/server/game/Loot/LootMgr.cpp` — all loot loading + validation
- `src/server/game/Entities/GameObject/GameObjectData.h` — GO type structs, GetLootId()
- `src/server/game/Entities/Item/ItemTemplate.h` — item flag constants

## Critical Gotcha
There is NO `item_template` SQL table in the world DB. Items come from DB2 (hotfixes.item_sparse).
When writing SQL that needs to check item existence, you must either:
1. Use explicit ID lists extracted from the error log
2. Cross-reference `hotfixes.item_sparse` (but DB name is configurable)

# Wago DB2 CSV Tables Reference

## Location
`C:/Users/atayl/source/wago/wago_csv/major_12/`
- File naming: `TableName-enUS.csv`
- Locale: enUS
- Three builds available: **66220** (server build, 1,097 tables), **66102** (166K items — preferred by transmog_debug.py), **66066** (oldest reference)
- Full table list: `C:/Users/atayl/source/wago/tables_all.txt` (1,100 tables, all available DB2s)
- Downloader: `python wago_db2_downloader.py --major 12 --tables-file <file.txt>`
  - Use `--build 12.0.1.66066` to pin a specific build
  - Use `--force` to re-download existing files
  - Auto-skips files already on disk

## CSV Export Oscillation Warning

Wago.tools CSV exports fluctuate wildly between builds in row counts. This is a Wago export-side behavior, NOT actual content changes.

| Table | "Reduced" builds (66044, 66192, 66220) | "Full" builds (66102, 66198) |
|---|---|---|
| SpellEffect | ~269K-511K rows | ~608K rows |
| ItemSparse | ~125K-171K rows | ~171K rows |
| SpellMisc | ~136K-404K rows | ~404K rows |
| CriteriaTree | ~4K-115K rows | ~115K rows |

**Rules**: Never diff full↔reduced builds. For SpellEffect coverage, prefer full-export builds (66102, 66198). For latest content, use newest build (66220). Detection: `wc -l SpellEffect-enUS.csv` — >500K = full, <400K = reduced.

## Key Tables & Columns

### SpellName
`ID, Name_lang`
- Full spell ID → name lookup. Fills the gap of no `spell_dbc`/`spell_name` in 12.x.

### ItemSparse
`ID, AllowableRace, Description_lang, Display_lang, ExpansionID, Flags_0..4, SellPrice, BuyPrice, ItemLevel, InventoryType, OverallQualityID, RequiredLevel, Bonding, SheatheType, Material, ...`
- `Display_lang` = item name, `InventoryType` = equip slot, `OverallQualityID` = quality (0=Poor..5=Legendary)

### ItemModifiedAppearance
`ID, ItemID, ItemAppearanceModifierID, ItemAppearanceID, OrderIndex, TransmogSourceTypeEnum, Flags`
- Core transmog mapping: ItemID → ItemAppearanceID

### TransmogOutfitSlotInfo
`InventorySlotName, ID, TransmogOutfitSlotEnum, InventorySlotEnum, Flags, TransmogCollectionType, OtherSlot, InventorySlotID, ItemCostMultiplier, IllusionCostMultiplier`
- Maps TransmogOutfitSlotEnum (0-14) → InventorySlotEnum. OtherSlot for paired slots (shoulders).

### FactionTemplate
`ID, Faction, Flags, FactionGroup, FriendGroup, EnemyGroup, Enemies_0..7, Friend_0..7`
- `ID` is what `creature_template.faction` references. `Faction` links to Faction table.

### Faction
`ID, ReputationRaceMask_0..3, Name_lang, Description_lang, ReputationIndex, ParentFactionID, Expansion, FriendshipRepID, Flags, ...`
- `Name_lang` gives readable names ("PLAYER, Human", "Stormwind", etc.)

### Emotes
`ID, RaceMask, EmoteSlashCommand, AnimID, EmoteFlags, EmoteSpecProc, EmoteSpecProcParam, EventSoundID, SpellVisualKitID, ClassMask`
- `EmoteSlashCommand` = text name (e.g., `ONESHOT_TALK(DNR)`). Has `SpellVisualKitID` tie-in.

### SoundKit
`ID, SoundType, VolumeFloat, Flags, MinDistance, DistanceCutoff, EAXDef, SoundKitAdvancedID, ...`
- Just need `ID` column for `creature_text.SoundKitID` validation.

### ChrRaces
`ID, ClientPrefix, Name_lang, FactionID, CreatureType, Alliance, BaseLanguage, UnalteredVisualRaceID, ...`
- Race 1=Human, 2=Orc, etc. `Alliance` (0/1), `CreatureType` (7=Humanoid).

### ChrCustomizationOption
`Name_lang, ID, SecondaryID, Flags, ChrModelID, OrderIndex, ChrCustomizationCategoryID, OptionType, BarberShopCostModifier, ...`
- `Name_lang` = readable names ("Skin Color", "Face"). `ChrModelID` links to race/gender model.

### ChrCustomizationChoice
`Name_lang, ID, ChrCustomizationOptionID, ChrCustomizationReqID, ChrCustomizationVisReqID, OrderIndex, UiOrderIndex, Flags, SoundKitID, SwatchColor_0..1`
- `ChrCustomizationOptionID` links to Option table — the option→choice pairing for `.cnpc`.

### Phase
`ID, Flags`
- Minimal. Enough for `WHERE PhaseId NOT IN (SELECT ID FROM ...)` validation.

### AreaTable
`ID, ZoneName, AreaName_lang, ContinentID, ParentAreaID, ContentTuningID, Flags_0..1, MountFlags, ...`
- `AreaName_lang` = zone names ("Dun Morogh"). For phase-area condition fixes.

### ContentTuning
`ID, Flags, ExpansionID, MinLevelSquish, MaxLevelSquish, MinLevelScalingOffset, MaxLevelScalingOffset, ...`
- Level scaling ranges. Validates `creature_template_difficulty.ContentTuningID`.

### Lock
`ID, Flags, _Index_0..7, Skill_0..7, Type_0..7, Action_0..7`
- Up to 8 lock requirements. Validates gameobject lock references.

### SpellItemEnchantment
`ID, Name_lang, Duration, EffectArg_0..2, Flags, ItemVisual, Effect_0..2, Charges, RequiredSkillID, RequiredSkillRank, ItemLevel, ...`
- `Name_lang` = enchant name ("Sharpened II"). `ItemVisual` ties into transmog illusion system.

### CreatureType
`ID, Name_lang, Flags`
- Type 1=Beast, 7=Humanoid, etc. Validates `creature_template.type`.

### CreatureFamily
`ID, Name_lang, MinScale, MinScaleLevel, MaxScale, MaxScaleLevel, PetFoodMask, PetTalentType, CategoryEnumID, IconFileID, SkillLine_0..1`
- Pet families: 1=Wolf, etc. `PetFoodMask` for pet feeding, `SkillLine` for taming.

### TaxiNodes
`Name_lang, Pos_0..2, MapOffset_0..1, FlightMapOffset_0..1, ID, ContinentID, ConditionID, CharacterBitNumber, Flags, ...`
- Flight point definitions. `Name_lang` = "Northshire Abbey", `ContinentID` = map ID.

### SpellLabel
`ID, LabelID, SpellID`
- Maps spells to label groups. Used in conditions and SmartAI label-based filtering.

### SpellShapeshiftForm
`ID, Name_lang, CreatureDisplayID, CreatureType, Flags, AttackIconFileID, BonusActionBar, CombatRoundTime, DamageVariance, MountTypeID, PresetSpellID_0..7`
- Shapeshift forms: 1=Cat, etc. `CreatureDisplayID` for the form model.

### GossipNPCOption
`ID, GossipNpcOption, LFGDungeonsID, TrainerID, GarrFollowerTypeID, CharShipmentID, GarrTalentTreeID, UiMapID, UiItemInteractionID, ..., GossipIndex, TraitTreeID, ProfessionID, SkillLineID`
- DB2-side gossip option data. `GossipNpcOption` = option type enum.

### FlightCapability
`ID, AirFriction, MaxVel, DoubleJumpVelMod, LiftCoefficient, GlideStartMinHeight, AddImpulseMaxSpeed, BankingRateMin/Max, PitchingRateDown/UpMin/Max, TurnVelocityThresholdMin/Max, SurfaceFriction, OverMaxDeceleration, LaunchSpeedCoefficient, SpellID`
- Skyriding flight physics parameters. `SpellID` links to the flight spell.

### CollectableSourceVendorSparse
`ID, VendorMapID, VendorPosition_0..2, VendorItemID, CreatureID, AreaTableID, WMOGroupID, CollectableSourceInfoID`
- ~92k rows of vendor→item mappings for transmog sources. Not full vendor data — only appearance-source items.

## All Downloaded Tables

### Original Pack — Items & Costs (build 66044)
Item, ItemSparse, ItemEffect, ItemXItemEffect, ItemExtendedCost, ItemBonus,
ItemBonusList, ItemBonusListGroup, ItemBonusListGroupEntry, ItemXBonusTree,
ItemBonusTree, ItemBonusTreeNode, ItemBonusTreeGroupEntry

### Original Pack — Spells (build 66044)
Spell, SpellName, SpellMisc, SpellEffect, SpellCategories, SpellDuration,
SpellRange, SpellRadius, SpellCastTimes, SpellPower, SpellReagents,
SpellReagentsCurrency, SpellXSpellVisual, SpellVisual, SpellVisualKit,
SpellVisualEffectName

### Original Pack — Maps & Instances (build 66044)
Map, MapDifficulty, Difficulty, DungeonEncounter, JournalInstance,
JournalEncounter, JournalEncounterXDifficulty, JournalEncounterItem,
JournalItemXDifficulty

### Original Pack — Creatures & Display (build 66044)
Creature, CreatureDifficulty, CreatureDisplayInfo, CreatureModelData,
CreatureDisplayInfoExtra, GameObjects, GameObjectDisplayInfo

### Original Pack — Transmog & Appearances (build 66044)
ItemAppearance, ItemDisplayInfo, ItemModifiedAppearance, ItemModifiedAppearanceExtra,
ItemVisuals, ItemVisualsXEffect, ConditionalItemAppearance, CollectableSourceInfo,
CollectableSourceVendor, CollectableSourceVendorSparse, CollectableSourceEncounter,
CollectableSourceEncounterSparse, CollectableSourceQuest, CollectableSourceQuestSparse,
TransmogSet, TransmogSetItem, TransmogSetGroup, TransmogOutfitEntry,
TransmogOutfitSlotInfo, TransmogOutfitSlotOption, TransmogDefaultLevel,
TransmogIllusion, ArtifactItemToTransmog

### Tier 1 — DB Error Triage & Core Systems (build 66066)
FactionTemplate, Faction, Emotes, EmotesText, EmotesTextSound, SoundKit,
NPCSounds, Phase, PhaseXPhaseGroup, ChrCustomizationOption, ChrCustomizationChoice,
ChrRaces, ChrModel, ChrRaceXChrModel, AreaTable, ContentTuning, Lock,
SpellAuraOptions, SpellCastingRequirements, SpellFocusObject, SpellItemEnchantment,
SpellLevels

### Tier 2 — RP Features, NPC Customization, Content (build 66066)
CharTitles, BarberShopStyle, Languages, BroadcastText, Toy, Holidays,
HolidayNames, HolidayDescriptions, Criteria, CriteriaTree, QuestV2,
QuestObjective, QuestInfo, QuestSort, ChrCustomizationDisplayInfo,
ChrCustomizationElement, ChrCustomizationGeoset, ChrCustomizationMaterial,
ConditionalChrModel, CharacterFacialHairStyles, CharHairGeosets,
NPCModelItemSlotDisplayInfo, CreatureDisplayInfoGeosetData, CreatureXDisplayInfo,
ItemDisplayInfoMaterialRes, GemProperties, SkillLine, SkillLineAbility,
SkillRaceClassInfo, Mount, MountCapability, MountType, Vehicle, VehicleSeat,
SummonProperties, SpellAuraRestrictions, LockType

### Tier 3 — Reference & Edge Cases (build 66066)
ChrClasses, ChrSpecialization, ChrClassRaceSex, Achievement, AnimationData,
AnimKit, ConversationLine, CurrencyTypes, ItemClass, ItemSubClass, ItemSet,
ItemSetSpell, ItemSpec, SpellCategory, SpellClassOptions, SpellMechanic,
Talent, ModifierTree, PlayerCondition, QuestLine, QuestLineXQuest,
WMOAreaTable, Vignette

### Tier 4 — Creatures, Gossip, Travel, Spells, Quests, Rewards (build 66066)
CreatureType, CreatureFamily, CreatureSoundData, CreatureLabel,
GossipNPCOption, GossipNPCOptionDisplayInfo,
TaxiNodes, TaxiPath, FlightCapability,
SpellLabel, SpellLearnSpell, SpellCooldowns, SpellShapeshiftForm, OverrideSpellData,
ChatChannels, PowerType, PlayerInteractionInfo,
ItemChildEquipment, ItemDisenchantLoot,
QuestPackageItem, QuestFactionReward, QuestXP, QuestMoneyReward,
SpecializationSpells, MailTemplate, ServerMessages,
RewardPack, RewardPackXItem, RewardPackXCurrencyType

## Usage Tips
- For bulk spell validation: load SpellName CSV, extract ID column, use as IN-list source
- For item lookups: ItemSparse has names (`Display_lang`) and all metadata
- For faction validation: FactionTemplate CSV → extract IDs for `WHERE faction NOT IN (...)` queries
- For emote/sound validation: Emotes + SoundKit CSVs fill the gap of no SQL-queryable DBC tables
- For NPC customization: ChrCustomizationOption + Choice give valid pairs per race/gender
- Python CSV parsing recommended for large lookups (e.g., `csv.DictReader`)
- These are DB2 exports — authoritative client-side data, not server DB
- Primary CSVs: `C:/Users/atayl/source/wago/wago_csv/major_12/12.0.1.66220/enUS/` (server build)
- Item-rich CSVs: `C:/Users/atayl/source/wago/wago_csv/major_12/12.0.1.66102/enUS/` (166K items)

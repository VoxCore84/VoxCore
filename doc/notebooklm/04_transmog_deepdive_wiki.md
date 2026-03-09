# Transmog UI Deep Dive — Comprehensive Reference Wiki

> **Target**: WoW 12.0.1 (Midnight) — Build 66263
> **Source**: `ExtTools/Transmog_DeepDive/` — 54 files: DB2 CSVs, client Lua/XML, API documentation, debug tools
> **Purpose**: Authoritative reference for implementing server-side transmog outfit handling in RoleplayCore
> **Generated**: 2026-03-08 (Session 105)
> **Supersedes**: `transmog_client_wiki.md` (Session 95 — retained for backward compat)

---

## Table of Contents

1. [ID Glossary & Chain](#1-id-glossary--chain)
2. [DB2 Tables](#2-db2-tables)
3. [Enumerations (Complete)](#3-enumerations-complete)
4. [C_Transmog API](#4-c_transmog-api)
5. [C_TransmogCollection API](#5-c_transmogcollection-api)
6. [C_TransmogOutfitInfo API](#6-c_transmogoutfitinfo-api)
7. [C_TransmogSets API](#7-c_transmogsetsapi)  <!-- note: anchor auto-generated -->
8. [Data Structures](#8-data-structures)
9. [Slot Architecture](#9-slot-architecture)
10. [Outfit System: Lifecycle & Flow](#10-outfit-system-lifecycle--flow)
11. [Weapon Options & Wire Order](#11-weapon-options--wire-order)
12. [Situations System (New in 12.x)](#12-situations-system-new-in-12x)
13. [UI Architecture: Frames & Mixins](#13-ui-architecture-frames--mixins)
14. [Event Flow](#14-event-flow)
15. [DressUp / Model Preview](#15-dressup--model-preview)
16. [Custom Sets System](#16-custom-sets-system)
17. [Hidden Appearances](#17-hidden-appearances)
18. [Secondary Slots](#18-secondary-slots)
19. [DisplayType: Stored vs Viewed Semantics](#19-displaytype-stored-vs-viewed-semantics)
20. [Debug Tools & Lost Addons](#20-debug-tools--lost-addons)
21. [Corrections to Previous Documentation](#21-corrections-to-previous-documentation)
22. [Server-Side UpdateField Structures](#22-server-side-updatefield-structures-from-wowpacketparser--trinitycore)
23. [Opcodes](#23-opcodes-build-66263)
24. [External References](#24-external-references)

---

## 1. ID Glossary & Chain

| ID Type | DB2 Table | Client Names | What It Is |
|---|---|---|---|
| **ItemID** | `Item` / `ItemSparse` | `itemID` | Item template |
| **IMA ID** | `ItemModifiedAppearance` | `sourceID`, `transmogID`, `itemModifiedAppearanceID` | Item+modifier combo — **stored in outfits** |
| **Visual ID** | `ItemAppearance` | `visualID`, `appearanceID`, `itemAppearanceID` | Visual look (many IMA → one visual) |
| **Illusion ID** | `SpellItemEnchantment` | `illusionID`, `spellItemEnchantmentID` | Weapon enchant glow |
| **Display ID** | `ItemDisplayInfo` | `itemDisplayInfoID` | 3D model/texture reference |

**Chain**: `ItemID → IMA ID → Visual ID → Display ID → model/texture`

**Server stores**: IMA ID in outfit slot data. Client resolves visuals via DB2 chain.

---

## 2. DB2 Tables

### 2.1 TransmogOutfitEntry

Defines outfit slot types available to players (default, purchased, event).

| Column | Type | Description |
|---|---|---|
| `Cost` | number | Gold cost to unlock (0 = free) |
| `Name_lang` | string | Display name ("Default", "Outfit 1", etc.) |
| `ID` | number | Primary key |
| `Source` | enum | 0=StampedSource, 1=AutomaticallyAwarded, 2=PlayerPurchased |
| `Flags` | bitmask | See `TransmogOutfitEntryFlags` enum |

**Notable entries**: ID=1 "Default" (free, Source=0, Flags=1), ID=2-3 "Outfit 1/2" (free, auto-awarded), ID=173 "Trial of Style" (event). IDs 4-131 are gold-purchased (1M-1B copper).

### 2.2 TransmogOutfitSlotInfo

Defines the 14 transmog outfit slots and their properties.

| Column | Type | Description |
|---|---|---|
| `InventorySlotName` | string | "HEADSLOT", "SHOULDERSLOT", etc. |
| `ID` | number | Row ID (1-14) |
| `TransmogOutfitSlotEnum` | enum | Maps to `TransmogOutfitSlot` (0-13) |
| `InventorySlotEnum` | number | Character inventory slot (0-18) |
| `Flags` | bitmask | `TransmogOutfitSlotFlags` |
| `TransmogCollectionType` | enum | Category for collection browsing |
| `OtherSlot` | number | Linked slot (shoulder pair, weapon pair) |
| `ItemCostMultiplier` | float | Gold cost scaling (0.5-2.0) |
| `IllusionCostMultiplier` | float | Illusion cost scaling (0 or 3) |

**14 Slot Mapping**:

| ID | Slot | SlotEnum | InvSlot | Flags | CollType | OtherSlot | CostMult |
|----|------|----------|---------|-------|----------|-----------|----------|
| 1 | HEAD | 0 | 0 | 0 | 1 (Head) | 0 | 2.0 |
| 2 | SHOULDER (R) | 1 | 2 | 0 | 2 (Shoulder) | 3 | 1.0 |
| 3 | SHOULDER (L) | 2 | 2 | 4 (IsSecondary) | 2 | 2 | 1.0 |
| 4 | SHIRT | 6 | 3 | 0 | 5 (Shirt) | 0 | 0.5 |
| 5 | CHEST | 4 | 4 | 0 | 4 (Chest) | 0 | 2.0 |
| 6 | WAIST | 9 | 5 | 0 | 9 (Waist) | 0 | 1.0 |
| 7 | LEGS | 10 | 6 | 0 | 10 (Legs) | 0 | 2.0 |
| 8 | FEET | 11 | 7 | 0 | 11 (Feet) | 0 | 1.0 |
| 9 | WRIST | 7 | 8 | 0 | 7 (Wrist) | 0 | 0.5 |
| 10 | HANDS | 8 | 9 | 0 | 8 (Hands) | 0 | 0.5 |
| 11 | BACK | 3 | 14 | 0 | 3 (Back) | 0 | 2.0 |
| 12 | TABARD | 5 | 18 | 0 | 6 (Tabard) | 0 | 0.5 |
| 13 | MAINHAND | 12 | 15 | 3 (NoHide+Illusion) | 0 (None) | 0 | 0.0 |
| 14 | OFFHAND | 13 | 16 | 3 (NoHide+Illusion) | 0 (None) | 0 | 0.0 |

**Key observations**:
- Slot 3 (left shoulder) has `Flags=4` (IsSecondarySlot) and `OtherSlot=2` (right shoulder)
- Slot 2 (right shoulder) has `OtherSlot=3` (left shoulder) — bidirectional link
- Weapons (13, 14) have `Flags=3` (CannotBeHidden + CanHaveIllusions), `CollectionType=0` (category determined by option)
- Weapons have `ItemCostMultiplier=0` but `IllusionCostMultiplier=3` — cost comes from weapon options

### 2.3 TransmogOutfitSlotOption

Defines weapon sub-options (1H, 2H, Dagger, Shield, etc.) for weapon slots.

| Column | Type | Description |
|---|---|---|
| `ID` | number | Row ID (1-18) |
| `Name_lang` | string | Display name |
| `OptionEnum` | enum | `TransmogOutfitSlotOption` value |
| `TransmogOutfitSlotInfoID` | number | Parent slot (13=MH, 14=OH) |
| `Flags` | bitmask | `TransmogOutfitSlotOptionFlags` |
| `OtherSlot` | number | Linked option slot for artifact pairs |
| `ItemCostMultiplier` | float | Cost scaling (3 or 6) |
| `IllusionCostMultiplier` | float | 0 (illusion cost on slot, not option) |

**18 Weapon Options**:

| ID | Name | Option | Slot | Flags | OtherSlot | CostMult |
|----|------|--------|------|-------|-----------|----------|
| 1 | One Handed Weapon | 1 | MH(13) | 0 | 0 | 3 |
| 2 | One Handed Weapon | 1 | OH(14) | 0 | 0 | 3 |
| 3 | Dagger | 6 | MH(13) | 0 | 0 | 3 |
| 4 | Dagger | 6 | OH(14) | 0 | 0 | 3 |
| 5 | Two Handed Weapon | 2 | MH(13) | 4 (DisablesOH) | 0 | 6 |
| 6 | Two Handed (Fury) | 7 | OH(14) | 0 | 0 | 3 |
| 7 | Ranged Weapon | 3 | MH(13) | 5 (IllusionNA+DisablesOH) | 0 | 3 |
| 8 | Shield | 5 | OH(14) | 0 | 1 | 3 |
| 9 | Off Hand | 4 | OH(14) | 0 | 1 | 3 |
| 10 | Two Handed (Fury) | 7 | MH(13) | 0 | 0 | 3 |
| 11 | Artifact Spec 1 | 8 | MH(13) | 2 (DynName) | 15 | 6 |
| 12 | Artifact Spec 2 | 9 | MH(13) | 2 | 16 | 6 |
| 13 | Artifact Spec 3 | 10 | MH(13) | 2 | 17 | 6 |
| 14 | Artifact Spec 4 | 11 | MH(13) | 2 | 18 | 6 |
| 15 | Artifact Spec 1 | 8 | OH(14) | 2 | 11 | 0 |
| 16 | Artifact Spec 2 | 9 | OH(14) | 2 | 12 | 0 |
| 17 | Artifact Spec 3 | 10 | OH(14) | 2 | 13 | 0 |
| 18 | Artifact Spec 4 | 11 | OH(14) | 2 | 14 | 0 |

**Key observations**:
- Two Handed (Option=2) on MH has `Flags=4` (DisablesOffhandSlot)
- Ranged (Option=3) on MH has `Flags=5` (IllusionNotAllowed + DisablesOffhandSlot)
- Dagger uses Option=6 (DeprecatedReuseMe), NOT a dedicated enum
- Artifact options (8-11) are MH/OH paired via OtherSlot — MH cost=6, OH cost=0
- Fury 2H exists on BOTH MH(10) and OH(6) — separate options for Titan's Grip

---

## 3. Enumerations (Complete)

### 3.1 TransmogOutfitDisplayType (CRITICAL — 5 values)

```
Unassigned = 0    -- Empty row, no appearance assigned
Assigned   = 1    -- Normal appearance applied
Equipped   = 2    -- Show equipped item (passthrough)
Hidden     = 3    -- Hidden appearance (slot invisible)
Disabled   = 4    -- Paired placeholder / disabled slot
```

> **CORRECTION**: Previous cheatsheet had Hidden=2, Equipped=3. The actual client enum is Hidden=3, Equipped=2.

### 3.2 TransmogOutfitSlot (15 values, 0-14)

```
Head           = 0
ShoulderRight  = 1
ShoulderLeft   = 2    -- Secondary shoulder
Back           = 3
Chest          = 4
Tabard         = 5
Body           = 6    -- Shirt
Wrist          = 7
Hand           = 8
Waist          = 9
Legs           = 10
Feet           = 11
WeaponMainHand = 12
WeaponOffHand  = 13
WeaponRanged   = 14   -- Not used in outfit rows but exists in enum
```

> **Note**: This is different from `TransmogSlot` (13 values, 0-12) which is a legacy/simplified mapping. `TransmogOutfitSlot` separates shoulders into Right(1) and Left(2).

### 3.3 TransmogSlot (Legacy — 13 values, 0-12)

```
Head     = 0    Shoulder = 1    Back   = 2    Chest  = 3
Body     = 4    Tabard   = 5    Wrist  = 6    Hand   = 7
Waist    = 8    Legs     = 9    Feet   = 10   Mainhand = 11   Offhand = 12
```

### 3.4 TransmogOutfitSlotOption (12 values, 0-11)

```
None              = 0    -- Armor slots (no weapon option)
OneHandedWeapon   = 1
TwoHandedWeapon   = 2
RangedWeapon      = 3
OffHand           = 4
Shield            = 5
DeprecatedReuseMe = 6    -- Actually used for DAGGER
FuryTwoHandedWeapon = 7  -- Titan's Grip
ArtifactSpecOne   = 8
ArtifactSpecTwo   = 9
ArtifactSpecThree = 10
ArtifactSpecFour  = 11
```

### 3.5 TransmogOutfitSlotPosition (UI Layout)

```
Left   = 0    -- Head, Chest, Wrist, Hands, Waist, Legs, Feet
Right  = 1    -- Shoulder, Back, Tabard, Shirt
Bottom = 2    -- Weapons (MH, OH)
```

### 3.6 TransmogOutfitSlotFlags

```
CannotBeHidden   = 1    -- Weapons — cannot apply hidden appearance
CanHaveIllusions = 2    -- Weapons — can have enchant visuals
IsSecondarySlot  = 4    -- Left shoulder only (NOT off-hand; OH has Flags=3)
```

### 3.7 TransmogOutfitSlotOptionFlags

```
IllusionNotAllowed  = 1    -- Ranged weapons — no enchant visuals
DynamicOptionName   = 2    -- Artifact options — name from spec
DisablesOffhandSlot = 4    -- 2H/Ranged — disables OH slot
```

### 3.8 TransmogOutfitSlotError (15 values, 0-14)

```
Ok                      = 0     NoItem                  = 1
NotSoulbound            = 2     Legendary               = 3
InvalidItemType         = 4     InvalidDestination      = 5
Mismatch                = 6     SameItem                = 7
InvalidSource           = 8     InvalidSourceQuality    = 9
CannotUseItem           = 10    InvalidSlotForRace      = 11
NoIllusion              = 12    InvalidSlotForForm      = 13
IncompatibleWithMainHand = 14
```

### 3.9 TransmogOutfitSlotWarning (6 values, 0-5)

```
Ok                           = 0
InvalidEquippedDestinationItem = 1
WrongWeaponCategoryEquipped  = 2
PendingWeaponChanges         = 3
WeaponDoesNotSupportIllusions = 4
NothingEquipped              = 5
```

### 3.10 TransmogOutfitEquipAction (6 values, 0-5)

```
Equip        = 0    EquipAndLock   = 1
Remove       = 2    RemoveAndLock  = 3
Unlock       = 4    Lock           = 5
```

### 3.11 TransmogOutfitSetType (3 values)

```
Equipped   = 0    -- Show equipped gear
Outfit     = 1    -- Named outfit
CustomSet  = 2    -- Player-created custom set
```

### 3.12 TransmogOutfitEntryFlags (bitmask)

```
AutomaticallyAwardedOnLogin = 1
UseOverrideName             = 2
OnlyAvailableDuringEvent    = 4
SortedToTopOfList           = 8
UseOverrideCostModifier     = 16
IsDefaultEquipped           = 32
```

### 3.13 TransmogOutfitEntrySource (3 values)

```
StampedSource       = 0    -- Pre-created
AutomaticallyAwarded = 1   -- Given on login (Default, Outfit 1, etc.)
PlayerPurchased     = 2    -- Gold-bought
```

### 3.14 TransmogCollectionType (30 values, 0-29)

```
None = 0         Head = 1        Shoulder = 2    Back = 3
Chest = 4        Shirt = 5       Tabard = 6      Wrist = 7
Hands = 8        Waist = 9       Legs = 10       Feet = 11
Wand = 12        OneHAxe = 13    OneHSword = 14  OneHMace = 15
Dagger = 16      Fist = 17       Shield = 18     Holdable = 19
TwoHAxe = 20     TwoHSword = 21  TwoHMace = 22   Staff = 23
Polearm = 24     Bow = 25        Gun = 26        Crossbow = 27
Warglaives = 28  Paired = 29
```

### 3.15 TransmogType (2 values)

```
Appearance = 0
Illusion   = 1
```

### 3.16 TransmogModification (2 values)

```
Main      = 0
Secondary = 1
```

### 3.17 TransmogPendingType (4 values)

```
Apply     = 0    Revert    = 1
ToggleOn  = 2    ToggleOff = 3
```

### 3.18 TransmogSource (11 values, 0-10)

```
None = 0                JournalEncounter = 1    Quest = 2
Vendor = 3              WorldDrop = 4           HiddenUntilCollected = 5
CantCollect = 6         Achievement = 7         Profession = 8
NotValidForTransmog = 9 TradingPost = 10
```

### 3.19 TransmogSearchType (3 values)

```
Items    = 1
BaseSets = 2
UsableSets = 3
```

### 3.20 TransmogUseErrorType (11 values, 0-10)

```
None = 0              PlayerCondition = 1    Skill = 2
Ability = 3           Reputation = 4         Holiday = 5
HotRecheckFailed = 6  Class = 7              Race = 8
Faction = 9           ItemProficiency = 10
```

### 3.21 TransmogOutfitTransactionType (5 values, 0-4)

```
UpdateMetadata  = 0
UpdateOutfitInfo = 1
CreateOutfitInfo = 2
UpdateSlots     = 3
UpdateSituations = 4
```

### 3.22 TransmogOutfitTransactionFlags (bitmask)

```
UpdateMetadata        = 1
UpdateOutfitInfo      = 2
CreateOutfitInfo      = 4
UpdateSlots           = 8
UpdateSituations      = 16
AddNewOutfitMask      = 20  (CreateOutfitInfo + UpdateSituations)
UpdateSituationsMask  = 18  (UpdateOutfitInfo + UpdateSituations)
AddOutfitAndUpdateSlots = 28 (Create + Slots + Situations)
FullOutfitUpdateMask  = 27  (Meta + OutfitInfo + Slots + Situations)
CreateAndUpdateOutfitInfoMask = 6 (OutfitInfo + CreateOutfitInfo)
```

### 3.23 TransmogOutfitDataFlags

```
IsCachedLocally = 1
```

### 3.24 TransmogOutfitSlotSaveFlags

```
AppearanceIsNotValid = 1
```

### 3.25 TransmogOutfitCostModifiersApplied (bitmask)

```
DebugOnlyFreeDiscountApplied = 1
VoidRacialDiscountApplied    = 2
OutfitCostModifierApplied    = 4
AuraDiscountApplied          = 8
```

### 3.26 TransmogSituation (22 values, 0-21)

```
AllSpecs = 0          Spec = 1
AllLocations = 2      LocationRested = 3      LocationHouse = 4
LocationCharacterSelect = 5  LocationWorld = 6      LocationDelves = 7
LocationDungeons = 8   LocationRaids = 9       LocationArenas = 10
LocationBattlegrounds = 11
AllMovement = 12       MovementUnmounted = 13  MovementSwimming = 14
MovementGroundMount = 15  MovementFlyingMount = 16
AllEquipmentSets = 17  EquipmentSets = 18
AllRacialForms = 19    FormNative = 20         FormNonNative = 21
```

### 3.27 TransmogSituationTrigger (9 values, 0-8)

```
None = 0           Manual = 1          TransmogUpdate = 2
Location = 3       Movement = 4        Specialization = 5
EquipmentSet = 6   Forms = 7           EventOutfit = 8
```

### 3.28 TransmogSituationTriggerType (4 values)

```
None = 0    Manual = 1    Automatic = 2    TransmogUpdate = 3
```

### 3.29 TransmogSituationFlags (bitmask)

```
IsPlayerFacing         = 1
SpecUseTalentLoadout   = 2
AllSituation           = 4
DefaultsToOn           = 8
DynamicallyNamed       = 16
NoneSituation          = 32
DisabledSituation      = 64
```

### 3.30 TransmogSituationTriggerFlags (bitmask)

```
CanLockOutfit          = 1
CanChangeLockedOutfit  = 2
IsPlayerFacing         = 4
SituationsAreExclusive = 8
DisabledTrigger        = 16
```

### 3.31 TransmogIllusionFlags

```
HideUntilCollected           = 1
PlayerConditionGrantsOnLogin = 2
```

### 3.32 TransmogOutfitDataConsts

```
EQUIP_TRANSMOG_OUTFIT_MANUAL_SPELL_ID = 1247613
TRANSMOG_OUTFIT_SLOT_NONE = -1
```

### 3.33 Transmog Constants

```
NoTransmogID = 0
MainHandTransmogIsIndividualWeapon = -1
MainHandTransmogIsPairedWeapon = 0
```

---

## 4. C_Transmog API

7 functions for basic transmog queries.

| Function | Returns | Description |
|---|---|---|
| `CanHaveSecondaryAppearanceForSlotID(slotID)` | bool | Can slot have asymmetric appearance? |
| `ExtractTransmogIDList(input)` | table<number> | Parse transmog ID list string |
| `GetAllSetAppearancesByID(setID)` | table<TransmogSetItemInfo> | All set items (for dressup preview) |
| `GetItemIDForSource(imaID)` | number | ItemID from IMA ID |
| `GetSlotForInventoryType(invType)` | luaIndex | Inventory type → transmog slot |
| `GetSlotVisualInfo(transmogLocation)` | TransmogSlotVisualInfo | Base/applied/pending visual data |
| `IsAtTransmogNPC()` | bool | Player at transmogrifier? |

---

## 5. C_TransmogCollection API

83 functions for appearance collection management. Key subset listed below; see `TransmogItemsDocumentation.lua` for the complete list.

### Core Appearance Queries

| Function | Returns | Description |
|---|---|---|
| `GetAppearanceInfoBySource(imaID)` | TransmogAppearanceInfoBySourceData | Full appearance info for source |
| `GetAppearanceSourceInfo(imaID)` | TransmogAppearanceSourceInfoData | Source details (category, icon, link) |
| `GetAppearanceSources(appearanceID, categoryType?, transmogLocation?)` | table<AppearanceSourceInfo> | All sources for a visual |
| `GetAllAppearanceSources(appearanceID)` | table<number> | Source ID array for visual |
| `GetCategoryAppearances(category, transmogLocation?)` | table<TransmogCategoryAppearanceInfo> | All appearances in category |
| `GetSourceInfo(sourceID)` | AppearanceSourceInfo | Full source data |
| `GetSourceIcon(imaID)` | fileID | Source icon texture |
| `GetSourceItemID(imaID)` | number | ItemID from source |

### Collection State

| Function | Returns | Description |
|---|---|---|
| `PlayerCanCollectSource(sourceID)` | hasItemData, canCollect | Check if player can collect |
| `AccountCanCollectSource(sourceID)` | hasItemData, canCollect | Account-wide check |
| `PlayerHasTransmog(itemID, modID?)` | bool | Player has this transmog? |
| `PlayerHasTransmogItemModifiedAppearance(imaID)` | bool | By IMA ID |
| `PlayerKnowsSource(sourceID)` | bool | Source in collection? |
| `IsAppearanceHiddenVisual(appearanceID)` | bool | Is this a "hidden" appearance? |

### Favorites & Filters

| Function | Returns | Description |
|---|---|---|
| `SetIsAppearanceFavorite(appearanceID, isFavorite)` | void | Toggle favorite |
| `GetIsAppearanceFavorite(appearanceID)` | bool | Check favorite |
| `HasFavorites()` | bool | Any favorites exist? |
| `SetCollectedShown(shown)` / `SetUncollectedShown(shown)` | void | Filter toggles |
| `SetClassFilter(classID)` / `GetClassFilter()` | void/number | Class filter |
| `SetDefaultFilters()` / `IsUsingDefaultFilters()` | void/bool | Reset filters |

### Illusions

| Function | Returns | Description |
|---|---|---|
| `GetIllusions()` | table<TransmogIllusionInfo> | All weapon enchant illusions |
| `GetIllusionInfo(illusionID)` | TransmogIllusionInfo | Single illusion data |
| `GetIllusionStrings(illusionID)` | name, hyperlink, sourceText | Illusion display strings |
| `CanAppearanceHaveIllusion(appearanceID)` | bool | Source supports enchant visual? |
| `IsSpellItemEnchantmentHiddenVisual(id)` | bool | Is hidden enchant? |

### Category Info

| Function | Returns | Description |
|---|---|---|
| `GetCategoryInfo(category)` | name, isWeapon, canHaveIllusions, canMainHand, canOffHand, canRanged | Full category data |
| `GetCategoryForItem(imaID)` | TransmogCollectionType | Which category is this item? |
| `GetCategoryCollectedCount(category)` / `GetCategoryTotal(category)` | number | Collection progress |

### Custom Sets

| Function | Returns | Description |
|---|---|---|
| `GetCustomSets()` | table<number> | All custom set IDs |
| `GetCustomSetInfo(id)` | name, icon | Custom set data |
| `GetCustomSetItemTransmogInfoList(id)` | table<ItemTransmogInfo> | Full transmog info per slot |
| `NewCustomSet(name, icon, list)` | number | Create new custom set |
| `ModifyCustomSet(id, list)` | void | Update existing |
| `RenameCustomSet(id, name)` | void | Rename |
| `DeleteCustomSet(id)` | void | Delete |
| `IsValidCustomSetName(name)` | bool | Name validation |
| `GetNumMaxCustomSets()` | number | Max allowed |

### Search

| Function | Returns | Description |
|---|---|---|
| `SetSearch(searchType, text)` | bool | Start search |
| `ClearSearch(searchType)` | bool | Clear search |
| `EndSearch()` | void | Cancel search |
| `IsSearchInProgress(searchType)` | bool | Search running? |
| `IsSearchDBLoading()` | bool | DB still loading? |
| `SearchProgress(searchType)` | number | 0.0-1.0 progress |
| `SearchSize(searchType)` | number | Result count |

---

## 6. C_TransmogOutfitInfo API

59 functions + 8 events — the **primary API for the 12.x outfit system**. This is the new API that replaces legacy transmog functions.

### Outfit Management

| Function | Returns | Description |
|---|---|---|
| `GetOutfitsInfo()` | table<TransmogOutfitEntryInfo> | All outfits |
| `GetOutfitInfo(outfitID)` | TransmogOutfitEntryInfo | Single outfit |
| `GetActiveOutfitID()` | number | Currently equipped outfit |
| `GetCurrentlyViewedOutfitID()` | number | Outfit being edited |
| `ChangeViewedOutfit(outfitID)` | void | Switch to editing outfit |
| `ChangeDisplayedOutfit(outfitID, trigger, toggleLock, allowRemoveOutfit)` | void | Equip outfit |
| `ClearDisplayedOutfit(trigger, toggleLock)` | void | Show equipped gear |
| `AddNewOutfit(name, icon)` | void | Create outfit (HasRestrictions) |
| `CommitOutfitInfo(outfitID, name, icon)` | void | Update outfit metadata |
| `CommitAndApplyAllPending(useAvailableDiscount)` | void | Save all pending changes |
| `PickupOutfit(outfitID)` | void | Drag outfit (for macro bar) |
| `IsLockedOutfit(outfitID)` | bool | Is outfit locked? |
| `IsEquippedGearOutfitDisplayed()` | bool | Showing equipped (no outfit)? |
| `IsEquippedGearOutfitLocked()` | bool | Equipped gear locked? |

### Slot Info

| Function | Returns | Description |
|---|---|---|
| `GetAllSlotLocationInfo()` | appearanceSlotInfo, illusionSlotInfo | All slots |
| `GetSlotGroupInfo()` | table<TransmogOutfitSlotGroup> | Slots grouped by position (L/R/Bottom) |
| `GetViewedOutfitSlotInfo(slot, type, option)` | ViewedTransmogOutfitSlotInfo | **CRITICAL** — current slot state |
| `GetLinkedSlotInfo(slot)` | TransmogOutfitLinkedSlotInfo | Primary/secondary pair |
| `GetSecondarySlotState(slot)` | bool | Is secondary active? |
| `SetSecondarySlotState(slot, state)` | ViewedTransmogOutfitSlotInfo | Toggle secondary |
| `GetWeaponOptionsForSlot(slot)` | weaponOptions, artifactOptions | Available weapon types |
| `GetEquippedSlotOptionFromTransmogSlot(slot)` | TransmogOutfitSlotOption | Currently equipped option |
| `GetUnassignedAtlasForSlot(slot)` | textureAtlas | Default empty slot icon |
| `GetUnassignedDisplayAtlasForSlot(slot)` | textureAtlas | Display atlas for unassigned |
| `GetTransmogOutfitSlotFromInventorySlot(invSlot)` | TransmogOutfitSlot | Convert inv → transmog |
| `GetTransmogOutfitSlotForInventoryType(invType)` | TransmogOutfitSlot | Convert type → transmog |
| `IsSlotWeaponSlot(slot)` | bool | Is this a weapon slot? |
| `SlotHasSecondary(slot)` | bool | Can slot have secondary? |

### Pending Transmog

| Function | Returns | Description |
|---|---|---|
| `SetPendingTransmog(slot, type, option, transmogID, displayType)` | void | **CRITICAL** — set appearance |
| `RevertPendingTransmog(slot, type, option)` | void | Undo pending change |
| `ClearAllPendingTransmogs()` | void | Discard all pending |
| `HasPendingOutfitTransmogs()` | bool | Any pending? |
| `GetPendingTransmogCost()` | BigUInteger | Gold cost of pending |

### Outfit Application

| Function | Returns | Description |
|---|---|---|
| `SetOutfitToSet(transmogSetID)` | void | Apply transmog set to outfit |
| `SetOutfitToCustomSet(customSetID)` | void | Apply custom set |
| `SetOutfitToOutfit(outfitID)` | void | Copy from another outfit (Trial of Style) |
| `SetViewedWeaponOptionForSlot(slot, option)` | void | Switch weapon option |
| `GetCollectionInfoForSlotAndOption(slot, option, collType)` | TransmogOutfitWeaponCollectionInfo | Category data |
| `GetItemModifiedAppearanceEffectiveCategory(imaID)` | TransmogCollectionType | Effective category |
| `GetIllusionDefaultIMAIDForCollectionType(collType)` | number | Default weapon for illusion preview |

### Cost & Discount

| Function | Returns | Description |
|---|---|---|
| `GetNextOutfitCost()` | BigUInteger | Cost of next outfit slot |
| `GetNumberOfOutfitsUnlockedForSource(source)` | number | Unlocked outfits per source |
| `GetMaxNumberOfTotalOutfitsForSource(source)` | number | Max outfits per source |
| `GetMaxNumberOfUsableOutfits()` | number | Total max outfits |
| `IsUsableDiscountAvailable()` | bool | Free application available? |

### Situations

| Function | Returns | Description |
|---|---|---|
| `GetOutfitSituation(option)` | bool | Get situation state |
| `GetOutfitSituationsEnabled()` | bool | Situations feature on? |
| `SetOutfitSituationsEnabled(enabled)` | void | Toggle situations |
| `UpdatePendingSituation(option, value)` | ViewedTransmogOutfitSlotInfo | Set pending situation |
| `HasPendingOutfitSituations()` | bool | Any pending situation changes? |
| `ClearAllPendingSituations()` | void | Discard situation changes |
| `CommitPendingSituations()` | void | Save situation changes |
| `ResetOutfitSituations()` | void | Reset to defaults |
| `GetUISituationCategoriesAndOptions()` | table<TransmogSituationCategory> | Full situation UI data |

### Events

| Event | Payload | Description |
|---|---|---|
| `TransmogOutfitsChanged` | newOutfitID? | Outfit list changed |
| `TransmogDisplayedOutfitChanged` | — | Active outfit changed |
| `ViewedTransmogOutfitChanged` | — | Editing target changed |
| `ViewedTransmogOutfitSlotRefresh` | — | All slots need refresh |
| `ViewedTransmogOutfitSlotSaveSuccess` | slot, type, option | Slot save confirmed |
| `ViewedTransmogOutfitSlotWeaponOptionChanged` | slot, weaponOption | Weapon option changed |
| `ViewedTransmogOutfitSecondarySlotsChanged` | — | Secondary toggle changed |
| `ViewedTransmogOutfitSituationsChanged` | — | Situation config changed |

### Misc

| Function | Returns | Description |
|---|---|---|
| `InTransmogEvent()` | bool | In Trial of Style? |
| `TransmogEventActive()` | bool | Trial of Style active? |
| `IsValidTransmogOutfitName(name)` | bool | Name validation |
| `GetSetSourcesForSlot(setID, slot)` | table<AppearanceSourceInfo> | Set sources for slot |
| `GetSourceIDsForSlot(setID, slot)` | table<number> | Set source IDs for slot |

---

## 7. C_TransmogSets API

40 functions for transmog set management. Key subset listed below; see `TransmogSetsDocumentation.lua` for the complete list.

| Function | Returns | Description |
|---|---|---|
| `GetAllSets()` / `GetBaseSets()` / `GetUsableSets()` / `GetAvailableSets()` | table<TransmogSetInfo> | Set lists |
| `GetSetInfo(setID)` | TransmogSetInfo | Single set data |
| `GetBaseSetID(setID)` | number | Parent base set for variant |
| `GetVariantSets(setID)` | table<TransmogSetInfo> | Recolor variants |
| `GetSetPrimaryAppearances(setID)` | table<TransmogSetPrimaryAppearanceInfo> | Appearances in set |
| `GetAllSourceIDs(setID)` | table<number> | All source IDs in set |
| `GetSourceIDsForSlot(setID, slot)` | table<number> | Sources per slot |
| `GetSourcesForSlot(setID, slot)` | table<AppearanceSourceInfo> | Full source info per slot |
| `GetSetsContainingSourceID(sourceID)` | table<number> | Which sets include source? |
| `IsBaseSetCollected(setID)` | bool | Is base set complete? |
| `IsSetVisible(setID)` | bool | Passes current filters? |
| `GetIsFavorite(setID)` | isFavorite, isGroupFavorite | Favorite status |
| `SetIsFavorite(setID, isFavorite)` | void | Toggle favorite |
| `GetCameraIDs()` | detailsCamID, vendorCamID | Model cameras |

---

## 8. Data Structures

### ViewedTransmogOutfitSlotInfo (Most important structure)

Returned by `C_TransmogOutfitInfo.GetViewedOutfitSlotInfo()`.

```lua
{
    transmogID      = number,               -- IMA ID or 0
    displayType     = TransmogOutfitDisplayType, -- 0-4
    isTransmogrified = bool,                -- Currently applied?
    hasPending      = bool,                 -- Has unsaved change?
    isPendingCollected = bool,              -- Is pending source collected?
    canTransmogrify = bool,                 -- Can this slot be transmogged?
    warning         = TransmogOutfitSlotWarning,  -- 0=Ok or warning code
    warningText     = cstring,
    error           = TransmogOutfitSlotError,    -- 0=Ok or error code
    errorText       = cstring,
    texture         = fileID | nil,         -- Slot icon
}
```

### TransmogOutfitEntryInfo

```lua
{
    outfitID           = number,
    name               = string,
    situationCategories = table<cstring>,  -- Active situation labels
    icon               = fileID,
    isEventOutfit      = bool,             -- Trial of Style outfit?
    isDisabled         = bool,
}
```

### AppearanceSourceInfo

```lua
{
    visualID             = number,
    sourceID             = number,    -- IMA ID
    isCollected          = bool,
    itemID               = number,
    itemModID            = number,
    invType              = luaIndex,  -- default: 0
    categoryID           = TransmogCollectionType,
    playerCanCollect     = bool,
    isValidSourceForPlayer = bool,
    canDisplayOnPlayer   = bool,
    inventorySlot        = number | nil,
    sourceType           = luaIndex | nil,
    name                 = string | nil,
    quality              = number | nil,
    useError             = string | nil,
    useErrorType         = TransmogUseErrorType | nil,
    meetsTransmogPlayerCondition = bool | nil,
    isHideVisual         = bool | nil,
}
```

### TransmogSlotVisualInfo

```lua
{
    baseSourceID    = number,    -- Equipped item source
    baseVisualID    = number,    -- Equipped item visual
    appliedSourceID = number,    -- Currently transmogged source
    appliedVisualID = number,    -- Currently transmogged visual
    pendingSourceID = number,    -- Pending change source
    pendingVisualID = number,    -- Pending change visual
    hasUndo         = bool,
    isHideVisual    = bool,
    itemSubclass    = number,
}
```

### TransmogOutfitSlotGroup

```lua
{
    position          = TransmogOutfitSlotPosition,  -- Left/Right/Bottom
    appearanceSlotInfo = table<TransmogOutfitSlotInfo>,
    illusionSlotInfo  = table<TransmogOutfitSlotInfo>,
}
```

### TransmogOutfitSlotInfo

```lua
{
    slot           = TransmogOutfitSlot,
    type           = TransmogType,
    collectionType = TransmogCollectionType,
    slotName       = cstring,
    isSecondary    = bool,
}
```

### TransmogSetInfo

```lua
{
    setID               = number,
    name                = string,
    baseSetID           = number | nil,
    description         = cstring | nil,
    label               = cstring | nil,
    expansionID         = number,
    patchID             = number,
    uiOrder             = number,
    classMask           = number,
    hiddenUntilCollected = bool,
    requiredFaction     = cstring | nil,
    collected           = bool,
    favorite            = bool,
    limitedTimeSet      = bool,
    validForCharacter   = bool,
    grantAsPrecedingVariant = bool,
}
```

### TransmogSituationCategory (New in 12.x)

```lua
{
    triggerID    = number,
    name         = cstring,
    description  = cstring,
    isRadioButton = bool,
    groupData    = table<TransmogSituationGroup>,
}
```

### TransmogSituationGroup

```lua
{
    groupID      = number,
    secondaryID  = number,
    optionData   = table<TransmogSituationOptionData>,
}
```

### TransmogSituationOptionData

```lua
{
    name   = cstring,
    value  = bool,
    option = TransmogSituationOption,
}
```

### TransmogSituationOption

```lua
{
    situationID    = number,
    specID         = number,
    loadoutID      = number,
    equipmentSetID = number,
}
```

### TransmogIllusionInfo

```lua
{
    visualID    = number,
    sourceID    = number,
    icon        = fileID,
    isCollected = bool,
    isUsable    = bool,
    isHideVisual = bool,
}
```

### TransmogLocationMixin

Used throughout the UI to reference a transmog slot.

```lua
{
    slot         = TransmogOutfitSlot,    -- Enum slot (Head, ShoulderRight, etc.)
    slotID       = number,                -- Inventory slot ID (1-13)
    type         = TransmogType,          -- Appearance or Illusion
    modification = TransmogModification,  -- Main or Secondary
}
-- Methods: IsAppearance(), IsIllusion(), IsMainHand(), IsOffHand(), IsSecondary(),
--          IsEitherHand(), IsRangedSlot(), GetSlot(), GetSlotID(), GetType(),
--          GetSlotName(), GetArmorCategoryID(), GetLookupKey(), GetData()
-- Lookup key formula: slotID * 100 + transmogType * 10 + isSecondary
```

---

## 9. Slot Architecture

### Two Different Slot Systems

**TransmogOutfitSlot (15-slot, used by outfit/updatefield system)**:
Separates left/right shoulders, includes ranged.

| Enum | Name | Purpose |
|------|------|---------|
| 0 | Head | |
| 1 | ShoulderRight | Primary shoulder |
| 2 | ShoulderLeft | Secondary shoulder (asymmetric) |
| 3 | Back | Cloak |
| 4 | Chest | |
| 5 | Tabard | |
| 6 | Body | Shirt |
| 7 | Wrist | |
| 8 | Hand | Gloves |
| 9 | Waist | Belt |
| 10 | Legs | |
| 11 | Feet | Boots |
| 12 | WeaponMainHand | Has weapon options |
| 13 | WeaponOffHand | Has weapon options |
| 14 | WeaponRanged | Not in standard outfit rows |

**TransmogSlot (13-slot, used by collection UI / legacy)**:
Single shoulder, no ranged.

| Enum | Name |
|------|------|
| 0 | Head |
| 1 | Shoulder (combined) |
| 2 | Back |
| 3 | Chest |
| 4 | Body |
| 5 | Tabard |
| 6 | Wrist |
| 7 | Hand |
| 8 | Waist |
| 9 | Legs |
| 10 | Feet |
| 11 | Mainhand |
| 12 | Offhand |

### 30-Row Outfit Layout

Each outfit has 30 rows: 12 armor (option=0) + 9 MH weapon options + 9 OH weapon options.

**Armor Rows** (12 rows, all option=None):
```
(Head,0), (ShoulderRight,0), (ShoulderLeft,0), (Back,0),
(Chest,0), (Tabard,0), (Body,0), (Wrist,0),
(Hand,0), (Waist,0), (Legs,0), (Feet,0)
```

**MH Weapon Options** (9 rows): Options 1, 6, 2, 3, 7, 8, 9, 10, 11
**OH Weapon Options** (9 rows): Options 1, 6, 7, 5, 4, 8, 9, 10, 11

---

## 10. Outfit System: Lifecycle & Flow

### Outfit Selection Flow

1. Player opens transmog UI → `TransmogrifyOpen` event
2. `TransmogFrameMixin:OnShow()` refreshes outfit list
3. `RefreshOutfits(selectActiveOutfit=true)` queries `C_TransmogOutfitInfo.GetOutfitsInfo()`
4. Auto-selects active outfit (`GetActiveOutfitID()`)
5. `ChangeViewedOutfit(outfitID)` → `ViewedTransmogOutfitChanged` event
6. All slot frames refresh via `SetupSlots()` + `RefreshSlots()`

### Appearance Selection Flow

1. Player clicks appearance in wardrobe grid
2. `C_TransmogOutfitInfo.SetPendingTransmog(slot, type, option, transmogID, displayType)` called
3. Slot shows pending animation, cost updates
4. Player clicks "Save Outfit" → `CommitAndApplyAllPending(useDiscount)`
5. `ViewedTransmogOutfitSlotSaveSuccess` event per slot → show saved animation

### Weapon Option Change Flow

1. Player selects from weapon dropdown (1H/2H/Ranged/etc.)
2. `SetViewedWeaponOptionForSlot(slot, weaponOption)` called
3. `ViewedTransmogOutfitSlotWeaponOptionChanged` event
4. All slot frames + illusion slots refresh

### Save / Apply Cost Flow

1. `GetPendingTransmogCost()` returns BigUInteger gold cost
2. If `IsUsableDiscountAvailable()` → show discount dialog
3. `CommitAndApplyAllPending(useAvailableDiscount=true/false)` → pays gold or uses discount
4. Server confirms → `TransmogOutfitsChanged` event

---

## 11. Weapon Options & Wire Order

### MH Weapon Option Wire Order

The 9 MH weapon option rows appear in this order in the outfit data:

| Position | Option | Name |
|----------|--------|------|
| 1 | 1 | One Handed Weapon |
| 2 | 6 | Dagger |
| 3 | 2 | Two Handed Weapon |
| 4 | 3 | Ranged Weapon |
| 5 | 7 | Fury Two Handed |
| 6 | 8 | Artifact Spec 1 |
| 7 | 9 | Artifact Spec 2 |
| 8 | 10 | Artifact Spec 3 |
| 9 | 11 | Artifact Spec 4 |

### OH Weapon Option Wire Order

| Position | Option | Name |
|----------|--------|------|
| 1 | 1 | One Handed Weapon |
| 2 | 6 | Dagger |
| 3 | 7 | Fury Two Handed |
| 4 | 5 | Shield |
| 5 | 4 | Off Hand |
| 6 | 8 | Artifact Spec 1 |
| 7 | 9 | Artifact Spec 2 |
| 8 | 10 | Artifact Spec 3 |
| 9 | 11 | Artifact Spec 4 |

### Weapon Disabling Rules

- **2H Weapon** (option=2, MH): `DisablesOffhandSlot` flag → OH slot disabled
- **Ranged** (option=3, MH): `IllusionNotAllowed + DisablesOffhandSlot` → OH disabled, no enchant
- **Fury 2H** (option=7): Available on BOTH MH and OH (Titan's Grip) — no disable

---

## 12. Situations System (New in 12.x)

The situations system allows automatic outfit switching based on context (spec, location, movement, form, etc.).

### Situation Categories

Each situation category is a **trigger type** with multiple **options**:

| Trigger | Type | Options | Description |
|---------|------|---------|-------------|
| Specialization | Radio | Per-spec (uses talent loadouts) | Switch outfit per spec |
| Location | Checkbox | Rested, House, CharSelect, World, Delves, Dungeons, Raids, Arenas, BGs | Switch by location |
| Movement | Checkbox | Unmounted, Swimming, Ground Mount, Flying Mount | Switch by movement |
| Equipment Set | Checkbox | Per equipment set | Switch by gear set |
| Racial Forms | Checkbox | Native, Non-Native | Worgen/Dracthyr forms |

### Situation API

- **Get**: `GetOutfitSituation(option)` → bool
- **Set**: `UpdatePendingSituation(option, value)` → ViewedTransmogOutfitSlotInfo
- **Commit**: `CommitPendingSituations()` saves pending
- **Master toggle**: `SetOutfitSituationsEnabled(enabled)` enables/disables entire system

### UI Representation

Each category renders as a dropdown with radio buttons (exclusive) or checkboxes (multiple). Categories are laid out vertically in the Situations tab of the wardrobe.

---

## 13. UI Architecture: Frames & Mixins

### Frame Hierarchy (TransmogFrame)

```
TransmogFrame (PortraitFrameTemplate, TransmogFrameMixin)
├── OutfitCollection (TransmogOutfitCollectionMixin)
│   ├── ShowEquippedGearSpellFrame
│   ├── OutfitList (ScrollBox)
│   │   └── TransmogOutfitEntryMixin (per outfit)
│   ├── PurchaseOutfitButton
│   ├── SaveOutfitButton
│   └── MoneyFrame
├── OutfitPopup (TransmogOutfitPopupMixin — icon selector)
├── CharacterPreview (TransmogCharacterMixin)
│   ├── ModelScene (PanningModelSceneMixinTemplate, scene 290)
│   ├── LeftSlots / RightSlots / BottomSlots (VerticalLayout / HorizontalLayout)
│   │   ├── TransmogAppearanceSlotMixin (per armor slot)
│   │   │   ├── TransmogIllusionSlotMixin (for weapon enchants)
│   │   │   └── TransmogSlotFlyoutDropdownMixin (weapon options)
│   │   └── TransmogIllusionSlotMixin (standalone)
│   └── HideIgnoredToggle
└── WardrobeCollection (TransmogWardrobeMixin, TabSystemOwner)
    ├── ItemsFrame (TransmogWardrobeItemsMixin)
    │   ├── FilterButton, SearchBox, WeaponDropdown
    │   ├── DisplayTypes (Unassigned/Equipped buttons)
    │   ├── PagedContent (DressUpModel grid — items)
    │   └── SecondaryAppearanceToggle
    ├── SetsFrame (TransmogWardrobeSetsMixin)
    │   └── PagedContent (set buttons)
    ├── CustomSetsFrame (TransmogWardrobeCustomSetsMixin)
    │   └── PagedContent (custom set buttons)
    └── SituationsFrame (TransmogWardrobeSituationsMixin)
        ├── Situations (VerticalLayout, TransmogSituationMixin entries)
        ├── EnabledToggle, ApplyButton, UndoButton, DefaultsButton
```

### Frame Hierarchy (WardrobeCollectionFrame — Collections Journal)

```
WardrobeCollectionFrame (WardrobeCollectionFrameMixin)
├── ItemsCollectionFrame (WardrobeItemsCollectionMixin)
│   ├── SlotsFrame (slot filter buttons)
│   ├── Models[1-18] (6×3 DressUpModel grid)
│   └── PagingFrame
├── SetsCollectionFrame (WardrobeSetsCollectionMixin)
│   ├── ListContainer (ScrollBox + ScrollBar)
│   └── DetailsFrame (Model + item icons + variant dropdown)
├── SearchBox (WardrobeCollectionFrameSearchBoxMixin)
├── FilterButton, ClassDropdown
└── progressBar
```

### Frame Hierarchy (DressUpFrame)

```
DressUpFrame (ButtonFrameTemplateMinimizable, DressUpModelFrameMixin)
├── ModelScene (PanningModelSceneMixinTemplate)
├── CustomSetDropdown (DressUpCustomSetMixin)
├── CustomSetDetailsPanel (DressUpCustomSetDetailsPanelMixin)
│   └── slotPool (DressUpCustomSetDetailsSlotMixin entries)
├── SetSelectionPanel (DressUpFrameTransmogSetMixin)
│   └── ScrollBox (set item buttons)
├── ResetButton, LinkButton, CancelButton
└── MaximizeMinimizeFrame
```

### Key Mixin Methods

**TransmogCharacterMixin** (character preview):
- `SetupSlots()` — Creates slot frames from `GetSlotGroupInfo()`
- `RefreshSlots()` — Updates 3D model via `actor:SetItemTransmogInfo()`
- `RefreshSlotWeaponOptions()` — Rebuilds weapon dropdowns
- `GetCurrentTransmogInfo()` / `GetCurrentTransmogIcons()` — Collect outfit data

**TransmogAppearanceSlotMixin** (slot button):
- `Init(slotData)` — Setup with slot data, weapon options dropdown
- `Update()` — Refresh icon, border atlas, overlays based on displayType
- `GetSlotInfo()` → calls `C_TransmogOutfitInfo.GetViewedOutfitSlotInfo()`

**TransmogItemModelMixin** (appearance grid item):
- `UpdateItem()` — Preview appearance on model (TryOn for armor, SetItemAppearance for weapons)
- `UpdateItemBorder()` — Show pending/transmogrified/saved state

---

## 14. Event Flow

### Complete Event Chain: Outfit Selection → Slot Update

```
User clicks outfit entry
  → TransmogOutfitEntryMixin:SelectEntry()
    → C_TransmogOutfitInfo.ChangeViewedOutfit(outfitID)
      → VIEWED_TRANSMOG_OUTFIT_CHANGED event
        → TransmogCharacterMixin:OnEvent() → SetupSlots() → RefreshSlots()
        → TransmogOutfitCollectionMixin:OnEvent() → UpdateSelectedOutfit()
        → TransmogWardrobeItemsMixin:OnEvent() → UpdateSlot()
```

### Complete Event Chain: Appearance Selection → Save

```
User clicks appearance in grid
  → TransmogItemModelMixin:OnMouseDown()
    → SelectVisual()
      → C_TransmogOutfitInfo.SetPendingTransmog(slot, type, option, transmogID, displayType)
        → Slot shows pending animation
        → TransmogFrameMixin:UpdateCostDisplay()

User clicks "Save Outfit"
  → TransmogOutfitCollectionMixin.SaveOutfitButton:OnClick()
    → C_TransmogOutfitInfo.CommitAndApplyAllPending(useDiscount)
      → VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS event (per slot)
        → TransmogAppearanceSlotMixin:OnTransmogrifySuccess() → show saved anim
      → TRANSMOG_OUTFITS_CHANGED event
        → TransmogFrameMixin:RefreshOutfits()
```

### C_TransmogCollection Events

| Event | When | UI Response |
|---|---|---|
| `TRANSMOG_COLLECTION_UPDATED` | Collection data changed | Clear caches, refresh all |
| `TRANSMOG_COLLECTION_ITEM_UPDATE` | Single item loaded | Update quality borders |
| `TRANSMOG_COLLECTION_SOURCE_ADDED` | New source collected | Refresh appearance grid |
| `TRANSMOG_COLLECTION_SOURCE_REMOVED` | Source removed | Refresh |
| `TRANSMOG_COLLECTION_CAMERA_UPDATE` | Camera changed | Update model camera |
| `TRANSMOG_SEARCH_UPDATED` | Search results changed | Refresh filtered results |
| `TRANSMOG_COLLECTION_ITEM_FAVORITE_UPDATE` | Favorite toggled | Update heart icon |

---

## 15. DressUp / Model Preview

### Model Setup Per Slot

The `WARDROBE_MODEL_SETUP` table controls how each slot's appearance is previewed:

- **Armor slots** (HEAD, SHOULDER, CHEST, etc.): `useTransmogSkin=true` (show on player model)
- **Weapon slots**: `useTransmogSkin=false` (show weapon model standalone)
- Special slots (HEAD, HANDS, FEET): Different body part visibility rules

### Model Rendering

- `actor:TryOn(sourceID)` — Preview armor on player model
- `actor:SetItemAppearance(visualID)` — Preview weapon standalone
- `actor:SetItemTransmogInfo(itemTransmogInfo, inventorySlot)` — Apply full transmog state
- `actor:GetItemTransmogInfoList()` — Get current dressed state
- `actor:Undress()` / `actor:UndressSlot(slot)` — Clear preview

### Camera System

- `C_TransmogCollection.GetAppearanceCameraID(visualID, variation)` — Camera for appearance
- `C_TransmogCollection.GetAppearanceCameraIDBySource(imaID, variation)` — Camera by source
- `C_TransmogSets.GetCameraIDs()` → (detailsCameraID, vendorCameraID)
- Camera variation: `None=0`, `RightShoulder=1`, `CloakBackpack=1`

---

## 16. Custom Sets System

### Lifecycle

1. **Create**: Player dresses up in DressUp frame → clicks SaveButton → enters name
2. **Store**: `C_TransmogCollection.NewCustomSet(name, icon, itemTransmogInfoList)` → returns customSetID
3. **Apply**: `C_TransmogOutfitInfo.SetOutfitToCustomSet(customSetID)` — applies to current outfit
4. **Modify**: `C_TransmogCollection.ModifyCustomSet(customSetID, newList)` — updates saved data
5. **Share**: `/customset v1 ...` slash command format for chat sharing

### Custom Set Validation

`WardrobeCustomSetManager:EvaluateAppearances()`:
1. For each slot in `itemTransmogInfoList`:
   - Check `C_TransmogCollection.PlayerCanCollectSource(sourceID)` → (hasData, canCollect)
   - If invalid → find preferred source via `CollectionWardrobeUtil.GetPreferredSourceID()`
   - Handle Legion Artifact paired weapons separately
2. Categorize: valid, invalid, pending (waiting for data)
3. Show appropriate dialog based on results

### Per-Spec Persistence

Custom set selection stored per specialization:
- CVar: `lastTransmogCustomSetIDSpec[1-4]`
- Non-spec: `lastTransmogCustomSetIDNoSpec`

---

## 17. Hidden Appearances

### Detection

- `C_TransmogCollection.IsAppearanceHiddenVisual(appearanceID)` → bool
- **Do NOT use** `ItemDisplayInfoID==0` — cloak hidden appearance has `ItemDisplayInfoID=146518`
- Use ItemID-based matching against 10 known hidden items

### Known Hidden Appearance IMA IDs (from CLAUDE.md)

```
77343  = Shoulder
77344  = Head
77345  = Cloak
83202  = Shirt
83203  = Tabard
84223  = Belt
94331  = Gloves
104602 = Chest
104603 = Boots
104604 = Bracers
198608 = Pants
```

### Display in UI

- Border: `transmog-gearslot-transmogrified-hidden` atlas
- HiddenVisualIcon overlay shown on slot
- displayType = `Hidden` (3)
- Illusion: `IsSpellItemEnchantmentHiddenVisual()` for hidden enchants

---

## 18. Secondary Slots

### Which Slots Have Secondary?

- **Shoulder** (ShoulderRight=1 → ShoulderLeft=2): Asymmetric shoulders
- **MainHand** (WeaponMainHand=12): Not a typical secondary, but used for artifact paired weapons

### API

- `C_TransmogOutfitInfo.SlotHasSecondary(slot)` — Does slot support it?
- `C_TransmogOutfitInfo.GetSecondarySlotState(slot)` — Is it enabled?
- `C_TransmogOutfitInfo.SetSecondarySlotState(slot, enabled)` — Toggle
- `C_TransmogOutfitInfo.GetLinkedSlotInfo(slot)` — Get primary + secondary pair

### UI

- `SecondaryAppearanceToggle` checkbox in wardrobe items tab
- Camera variation: `TransmogCameraVariation.RightShoulder = 1` for right shoulder, `None = 0` for left
- Slot 2 (ShoulderLeft) has `Flags=4` (IsSecondarySlot) in DB2

---

## 19. DisplayType: Stored vs Viewed Semantics

This is the **most critical section for server implementation**.

### WARNING: Two Separate DisplayType Concepts

There are **two completely different DisplayType systems** — never confuse them:

1. **DB2 `ItemAppearance.DisplayType`** (range 0-15): Per-IMAID classification for **slot routing**.
   Used in `DisplayTypeToEquipSlot()` to determine which equipment slot an appearance belongs to.
   Values: 0=Head, 1=Shoulder, 2=Shirt, 3=Chest, 4=Waist, 5=Legs, 6=Feet, 7=Wrist, 8=Hands, 9=Back, 10=Tabard, 11=MH, 13=Shield→OH, 14=OH, 15=OH-alt.

2. **`TransmogOutfitSlotData::AppearanceDisplayType`** (range 0-4): Per-slot **behavioral flag**
   in ViewedOutfit/TransmogOutfits UpdateFields. This is the behavioral ADT documented below.

**Never use routing DT values (0-15) where behavioral ADT values (0-4) belong, or vice versa.**

### Behavioral ADT Enum Values (Client-Side)

```
TransmogOutfitDisplayType:
  Unassigned = 0
  Assigned   = 1
  Equipped   = 2
  Hidden     = 3
  Disabled   = 4
```

### Stored `TransmogOutfits` Context (Persistent DB Data)

| State | ADT | IDT | IMAID field | Enchant field | Notes |
|-------|-----|-----|-------------|---------------|-------|
| Empty/unassigned | 0 | 0 | 0 | 0 | Row not populated |
| Normal appearance | 1 | 0 | IMA ID | 0 | Standard transmog |
| Hidden appearance | 3 | 0 | Hidden IMA ID | 0 | Must be real hidden IMA (see §17) |
| Enchanted weapon (selected) | 1 | 1 | IMA ID | SpellItemEnchantmentID | Weapon + enchant glow |
| Paired placeholder (opts 8-11) | 4 | 4 | 0 | 0 | Artifact bookkeeping |

> **Note**: The enchant ID goes in the `SpellItemEnchantmentID` field (UpdateField [4]), NOT in the `ItemModifiedAppearanceID` field (UpdateField [2]). An enchanted weapon row has BOTH an IMA ID for the weapon appearance AND a SpellItemEnchantmentID for the glow.

### Viewed `ViewedOutfit` Context (Live UpdateField)

| State | ADT | IDT | IMAID field | Enchant field | Notes |
|-------|-----|-----|-------------|---------------|-------|
| Empty (show equipped) | 2 | 2 | 0 | 0 | Passthrough to equipped gear |
| Normal appearance | 1 | 0 | IMA ID | 0 | Same as stored |
| Hidden appearance | 3 | 0 | Hidden IMA ID | 0 | Same as stored |
| Enchanted weapon (selected) | 1 | 1 | IMA ID | SpellItemEnchantmentID | Same as stored |
| Paired placeholder (opts 8-11) | 4 | 4 | 0 | 0 | Same as stored |

### Key Difference

**Only empty rows differ**: Stored empty = `ADT=0/IDT=0`, Viewed empty = `ADT=2/IDT=2`.
All assigned rows use `ADT=1` in **both** contexts.

### Implementation Rules

1. When building `ViewedOutfit` from stored `TransmogOutfits`:
   - If stored row has ADT=0 → set viewed to ADT=2, IDT=2
   - Otherwise → copy directly
2. When saving viewed data back to stored:
   - If viewed row has ADT=2 → set stored to ADT=0, IDT=0
   - Otherwise → copy directly
3. **Never use ADT=2 for assigned rows** — ADT=2 means "show equipped item"

---

## 20. Debug Tools & Lost Addons

### Available: Blizzard_DebugTools

LoadOnDemand addon for runtime inspection:

- **FrameStackTooltip** (`/fstack`): Real-time frame hierarchy inspection
  - ALT+Mouse: Navigate frame tree
  - CTRL+Mouse: Open in TableInspector
  - SHIFT+Mouse: Toggle texture info
- **TableInspector**: Deep Lua table/attribute inspection
  - Editable values, drill-down navigation, filtering
  - Can inspect transmog outfit data live
- **TextureInfoGenerator**: Atlas/texture debugging
- **TexelSnappingVisualizer**: Pixel grid debug (GM-only)

### Lost Internal Addons (Never Published to CASC)

4 Blizzard-internal transmog addons exist in `ManifestInterfaceTOCData` but files were never shipped:

| Addon | FDID | Era | Purpose |
|---|---|---|---|
| DEV_Tools/Transmog | 3014770 | Legion 2016 | Internal transmog dev tools |
| ShoulderTransmogTest | 3952313 | Shadowlands 2020 | Asymmetric shoulder testing |
| WardrobeOutfitDetails | 4094426 | Dragonflight 2022 | Debug outfit detail view |
| TransmogViewer | 4281577 | Dragonflight 2023 | Appearance viewer |

These are **not recoverable** from public CASC builds (verified across 9 products, builds 35078-66263).

---

## 21. Corrections to Previous Documentation

### DisplayType Values (CRITICAL FIX)

**Previous** (`transmog_cheatsheet.md`):
```
displayType == 0 (Unassigned)?  → SKIP slot
displayType == 1 (Assigned)?    → APPLY transmogID
displayType == 2 (Hidden)?      → APPLY hidden
displayType == 3 (Equipped)?    → REMOVE transmog
```

**Correct** (from `TransmogOutfitConstantsDocumentation.lua`):
```
displayType == 0 (Unassigned)?  → SKIP slot (no appearance)
displayType == 1 (Assigned)?    → APPLY transmogID
displayType == 2 (Equipped)?    → Show equipped item
displayType == 3 (Hidden)?      → APPLY hidden appearance
displayType == 4 (Disabled)?    → Paired placeholder, skip
```

**Hidden is 3, Equipped is 2** — the previous docs had these swapped.

### TransmogOutfitSlot vs TransmogSlot

Previous docs used a single 13-value slot enum. The outfit system actually uses **TransmogOutfitSlot** (15 values, 0-14) which separates left/right shoulders and includes ranged.

### Dagger Option

Dagger uses `TransmogOutfitSlotOption.DeprecatedReuseMe = 6`, not a dedicated "Dagger" enum value. The DB2 data shows the name as "Dagger" but the enum says "DeprecatedReuseMe" — this is reused from an older system.

---

## 22. Server-Side UpdateField Structures (from WowPacketParser / TrinityCore)

> Source: Internet deep dive — WowPacketParser auto-generated UpdateField C# code for build 66263

### ActivePlayerData (transmog-relevant fields)

```cpp
MapUpdateField<uint32, TransmogOutfitData, 134, 159> TransmogOutfits;  // keyed by outfit ID
UpdateField<TransmogOutfitData, 134, 160> ViewedOutfit;                 // currently displayed
UpdateField<TransmogOutfitMetadata, 134, 161> TransmogMetadata;         // metadata
DynamicUpdateField<uint32> Transmog;            // collected appearance IDs
DynamicUpdateField<int32> ConditionalTransmog;  // conditional appearances
DynamicUpdateField<uint32> TransmogIllusions;   // collected illusion IDs
```

> **Note**: ViewedOutfit is in ActivePlayerData (self-only), NOT PlayerData (visible to others). Other players see VisibleItems.

### TransmogOutfitData (HasChangesMask<5>)

```cpp
DynamicUpdateField<TransmogOutfitSituationInfo> Situations;  // [0]
DynamicUpdateField<TransmogOutfitSlotData> Slots;            // [1] — the 30 rows
UpdateField<uint32> Id;                                       // [2]
UpdateField<TransmogOutfitDataInfo> OutfitInfo;              // [3]
UpdateField<uint32> Flags;                                    // [4]
```

### TransmogOutfitSlotData (HasChangesMask<7>) — THE PER-ROW FORMAT

```cpp
UpdateField<int8>   Slot;                     // [0] TransmogOutfitSlot enum (-1 to 14)
UpdateField<uint8>  SlotOption;               // [1] TransmogOutfitSlotOption enum (0-11)
UpdateField<uint32> ItemModifiedAppearanceID; // [2] IMA ID
UpdateField<uint8>  AppearanceDisplayType;    // [3] behavioral ADT (0-4)
UpdateField<uint32> SpellItemEnchantmentID;   // [4] illusion enchant ID
UpdateField<uint8>  IllusionDisplayType;      // [5] IDT (0-4)
UpdateField<uint32> Flags;                    // [6] TransmogOutfitSlotSaveFlags
```

### TransmogOutfitDataInfo (HasChangesMask<4>)

```cpp
UpdateField<bool>        SituationsEnabled; // [0]
UpdateField<uint8>       SetType;           // [1] TransmogOutfitSetType (0-2)
UpdateField<std::string> Name;              // [2]
UpdateField<uint32>      Icon;              // [3] FileDataID
```

### TransmogOutfitSituationInfo (HasChangesMask<4>)

```cpp
UpdateField<uint32> SituationID;    // [0]
UpdateField<uint32> SpecID;         // [1]
UpdateField<uint32> LoadoutID;      // [2]
UpdateField<uint32> EquipmentSetID; // [3]
```

### TransmogOutfitMetadata (plain struct, NOT HasChangesMask)

```cpp
bool   Locked;                  // outfit lock state
uint8  SituationTrigger;        // TransmogSituationTrigger enum (0-8)
uint32 TransmogOutfitID;        // currently active outfit ID
uint8  StampedOptionMainHand;   // weapon option enum for MH
uint8  StampedOptionOffHand;    // weapon option enum for OH
float  CostMod;                 // from SPELL_AURA_MOD_TRANSMOG_OUTFIT_UPDATE_COST (aura 655)
```

---

## 23. Opcodes (build 66263)

### Client → Server (CMSG)

| Opcode | Hex | Purpose | Status in TC upstream |
|--------|-----|---------|----------------------|
| CMSG_TRANSMOG_OUTFIT_NEW | 0x3A0044 | Create outfit | **NOT IMPLEMENTED** |
| CMSG_TRANSMOG_OUTFIT_UPDATE_INFO | 0x3A0045 | Rename/icon | **NOT IMPLEMENTED** |
| CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS | 0x3A0046 | Situation config | **NOT IMPLEMENTED** |
| CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS | 0x3A0047 | Change appearances | **NOT IMPLEMENTED** |
| CMSG_TRANSMOGRIFY_ITEMS | (legacy) | Old NPC-based transmog | Implemented (legacy) |

### Server → Client (SMSG)

| Opcode | Hex | Purpose | Notes |
|--------|-----|---------|-------|
| SMSG_TRANSMOG_OUTFIT_NEW_ENTRY_ADDED | 0x42004A | Outfit created ACK | |
| SMSG_TRANSMOG_OUTFIT_INFO_UPDATED | 0x42004B | Info change ACK | |
| SMSG_TRANSMOG_OUTFIT_SITUATIONS_UPDATED | 0x42004C | Situation ACK | |
| SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED | 0x42004D | Full 30-row slot echo | **Must be 30 rows** |
| SMSG_ACCOUNT_TRANSMOG_UPDATE | 0x42004F | Collection sync | |
| SMSG_ACCOUNT_TRANSMOG_SET_FAVORITES_UPDATE | 0x420050 | Favorites sync | |
| SMSG_FORCE_RANDOM_TRANSMOG_TOAST | 0x42004E | Random transmog toast | |

### Upstream TrinityCore Status

- All opcode hex values defined but **no handlers registered** for CMSG_TRANSMOG_OUTFIT_*
- `SPELL_EFFECT_EQUIP_TRANSMOG_OUTFIT` (347) is `EffectNULL` — no implementation
- `character_transmog_outfits` table exists but uses OLD pre-12.x 19-column schema (appearance0-18 + enchants) — does NOT match new 30-row slot model
- `SPELL_AURA_MOD_TRANSMOG_OUTFIT_UPDATE_COST` (aura 655) defined but handler is NULL
- Legacy `CMSG_TRANSMOGRIFY_ITEMS` handler works with item-modifier system

---

## 24. External References

### WoWDBDefs (DB2 Schema Definitions)
- TransmogOutfitEntry.dbd, TransmogOutfitSlotInfo.dbd, TransmogOutfitSlotOption.dbd
- TransmogSituation.dbd, TransmogSituationGroup.dbd, TransmogSituationTrigger.dbd
- ItemAppearance.dbd, ItemModifiedAppearance.dbd, TransmogIllusion.dbd

### WowPacketParser (12.x UpdateField Structures)
- TransmogOutfitSlotData.cs, TransmogOutfitData.cs, TransmogOutfitDataInfo.cs
- TransmogOutfitMetadata.cs, TransmogOutfitSituationInfo.cs, ActivePlayerData.cs
- All at: `WowPacketParserModule.V12_0_0_65390/UpdateFields/V12_0_1_65818/`

### Blizzard Interface Code (tomrus88 GitHub mirror)
- TransmogOutfitInfoDocumentation.lua, TransmogOutfitConstantsDocumentation.lua
- TransmogConstantsDocumentation.lua, TransmogSharedDocumentation.lua

### Wowhead Articles
- "Revamped Transmog System in Midnight — Outfit Slots, Situations, and More"
- "Everything To Know About Midnight's Transmog System"

---

## Appendix A: File Inventory

| Directory | File | Lines | Purpose |
|---|---|---|---|
| db2_csv/ | TransmogOutfitEntry-enUS.csv | 53 | Outfit definitions |
| db2_csv/ | TransmogOutfitSlotInfo-enUS.csv | 15 | Slot definitions |
| db2_csv/ | TransmogOutfitSlotOption-enUS.csv | 19 | Weapon options |
| source_lua/ | TransmogConstantsDocumentation.lua | 40 | TransmogSlot enum |
| source_lua/ | TransmogDocumentation.lua | 320 | C_Transmog API |
| source_lua/ | TransmogItemsDocumentation.lua | 1227 | C_TransmogCollection API |
| source_lua/ | TransmogOutfitConstantsDocumentation.lua | 395 | Outfit enums (28 tables) |
| source_lua/ | TransmogOutfitInfoDocumentation.lua | 912 | C_TransmogOutfitInfo API |
| source_lua/ | TransmogSetsDocumentation.lua | 535 | C_TransmogSets API |
| source_lua/ | TransmogSharedDocumentation.lua | 138 | Shared enums (8 tables) |
| source_lua/ | AppearanceSourceDocumentation.lua | — | AppearanceSourceInfo struct |
| source_lua/ | ConsoleScriptCollectionDocumentation.lua | 120 | Console script API |
| source_lua/ | FrameAPIDressUpModelDocumentation.lua | 267 | DressUpModel frame API |
| source_lua/ | Blizzard_Transmog.lua | 1106 | Main transmog UI frame |
| source_lua/ | Blizzard_TransmogShared.lua | 723 | Shared utilities |
| source_lua/ | Blizzard_TransmogOverrides.lua | — | Override hooks |
| source_lua/ | Blizzard_TransmogRegistration.lua | — | Event registration |
| source_lua/ | Blizzard_TransmogTemplates.lua | 1775 | Slot/item/set templates |
| source_lua/ | Blizzard_SavedSets.lua | 139 | Account-wide persistence |
| source_lua/ | Blizzard_Wardrobe.lua | 1752 | Wardrobe collection UI |
| source_lua/ | Blizzard_Wardrobe_Sets.lua | 948 | Sets collection UI |
| source_lua/ | WardrobeCustomSets.lua | 512 | Custom sets system |
| source_lua/ | Blizzard_Collections.lua | — | Collections journal |
| source_lua/ | Blizzard_CollectionTemplates.lua | — | Collection templates |
| source_lua/ | DressUpFrames.lua | 954 | DressUp frame |
| source_lua/ | DressUpModelFrameMixin.lua | 761 | DressUp model logic |
| source_lua/ | CollectionsUtil.lua | 508 | Utility functions |
| 8 .xml files | — | — | Frame/template definitions |
| 3 .toc files | — | — | Load order |
| dev_addons/ | README.txt + 12 files | — | Debug tools |

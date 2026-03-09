# Transmog C_API Reference — Quick Lookup

> Source: `ExtTools/Transmog_DeepDive/source_lua/*Documentation.lua` (build 66263)
> Full wiki: `doc/transmog_deepdive_wiki.md`

## C_TransmogOutfitInfo (59 functions + 8 events — PRIMARY 12.x API)

### Outfit Management
- `GetOutfitsInfo()` → table<TransmogOutfitEntryInfo>
- `GetOutfitInfo(outfitID)` → TransmogOutfitEntryInfo
- `GetActiveOutfitID()` → number (equipped outfit)
- `GetCurrentlyViewedOutfitID()` → number (being edited)
- `ChangeViewedOutfit(outfitID)` → void
- `ChangeDisplayedOutfit(outfitID, trigger, toggleLock, allowRemoveOutfit)` → void
- `ClearDisplayedOutfit(trigger, toggleLock)` → void (show equipped)
- `AddNewOutfit(name, icon)` → void (HasRestrictions)
- `CommitOutfitInfo(outfitID, name, icon)` → void
- `CommitAndApplyAllPending(useAvailableDiscount)` → void (SAVE)
- `PickupOutfit(outfitID)` → void
- `IsLockedOutfit(outfitID)` → bool
- `IsEquippedGearOutfitDisplayed()` → bool
- `IsEquippedGearOutfitLocked()` → bool

### Slot Info (CRITICAL for server)
- `GetSlotGroupInfo()` → table<TransmogOutfitSlotGroup> (by position L/R/Bottom)
- `GetViewedOutfitSlotInfo(slot, type, option)` → ViewedTransmogOutfitSlotInfo
- `GetLinkedSlotInfo(slot)` → primary + secondary pair
- `GetSecondarySlotState(slot)` → bool
- `SetSecondarySlotState(slot, state)` → ViewedTransmogOutfitSlotInfo
- `GetWeaponOptionsForSlot(slot)` → weaponOptions, artifactOptions
- `GetEquippedSlotOptionFromTransmogSlot(slot)` → TransmogOutfitSlotOption
- `IsSlotWeaponSlot(slot)` → bool
- `SlotHasSecondary(slot)` → bool

### Pending Transmog
- `SetPendingTransmog(slot, type, option, transmogID, displayType)` → void
- `RevertPendingTransmog(slot, type, option)` → void
- `ClearAllPendingTransmogs()` → void
- `HasPendingOutfitTransmogs()` → bool
- `GetPendingTransmogCost()` → BigUInteger

### Apply Operations
- `SetOutfitToSet(transmogSetID)` → void
- `SetOutfitToCustomSet(customSetID)` → void
- `SetOutfitToOutfit(outfitID)` → void (Trial of Style)
- `SetViewedWeaponOptionForSlot(slot, option)` → void

### Situations (NEW 12.x)
- `GetOutfitSituation(option)` → bool
- `SetOutfitSituationsEnabled(enabled)` → void
- `UpdatePendingSituation(option, value)` → ViewedTransmogOutfitSlotInfo
- `CommitPendingSituations()` → void
- `GetUISituationCategoriesAndOptions()` → table<TransmogSituationCategory>

### Events
- `TransmogOutfitsChanged` (newOutfitID?)
- `TransmogDisplayedOutfitChanged`
- `ViewedTransmogOutfitChanged`
- `ViewedTransmogOutfitSlotRefresh`
- `ViewedTransmogOutfitSlotSaveSuccess` (slot, type, option)
- `ViewedTransmogOutfitSlotWeaponOptionChanged` (slot, weaponOption)
- `ViewedTransmogOutfitSecondarySlotsChanged`
- `ViewedTransmogOutfitSituationsChanged`

## C_TransmogCollection (83 functions)

### Core Queries
- `GetAppearanceInfoBySource(imaID)` → TransmogAppearanceInfoBySourceData
- `GetAppearanceSourceInfo(imaID)` → category, icon, link, itemSubclass
- `GetAppearanceSources(appearanceID, cat?, loc?)` → table<AppearanceSourceInfo>
- `GetSourceInfo(sourceID)` → AppearanceSourceInfo
- `GetSourceItemID(imaID)` → number (ItemID)
- `GetCategoryInfo(cat)` → name, isWeapon, canHaveIllusions, canMH, canOH, canRanged
- `IsAppearanceHiddenVisual(appearanceID)` → bool

### Collection State
- `PlayerCanCollectSource(sourceID)` → hasItemData, canCollect
- `PlayerHasTransmogItemModifiedAppearance(imaID)` → bool
- `PlayerKnowsSource(sourceID)` → bool

### Illusions
- `GetIllusions()` → table<TransmogIllusionInfo>
- `GetIllusionInfo(id)` → TransmogIllusionInfo
- `CanAppearanceHaveIllusion(appearanceID)` → bool

### Custom Sets
- `GetCustomSets()` → table<number>
- `NewCustomSet(name, icon, list)` → number
- `ModifyCustomSet(id, list)` → void
- `DeleteCustomSet(id)` → void

## C_TransmogSets (40 functions)

- `GetAllSets()` / `GetBaseSets()` / `GetUsableSets()` → table<TransmogSetInfo>
- `GetSetInfo(setID)` → TransmogSetInfo
- `GetVariantSets(setID)` → table<TransmogSetInfo>
- `GetSetPrimaryAppearances(setID)` → table<{appearanceID, collected}>
- `GetSourcesForSlot(setID, slot)` → table<AppearanceSourceInfo>
- `GetCameraIDs()` → detailsCamID, vendorCamID

## C_Transmog (7 functions)

- `CanHaveSecondaryAppearanceForSlotID(slotID)` → bool
- `ExtractTransmogIDList(input)` → table<number>
- `GetAllSetAppearancesByID(setID)` → table<TransmogSetItemInfo>
- `GetItemIDForSource(imaID)` → number
- `GetSlotForInventoryType(invType)` → slot
- `GetSlotVisualInfo(transmogLocation)` → base/applied/pending visual info
- `IsAtTransmogNPC()` → bool

## Key Data Structures

### ViewedTransmogOutfitSlotInfo
```
transmogID, displayType, isTransmogrified, hasPending,
isPendingCollected, canTransmogrify, warning, warningText,
error, errorText, texture
```

### TransmogLocationMixin
```
slot, slotID, type, modification
Lookup key: slotID * 100 + transmogType * 10 + isSecondary
```

### AppearanceSourceInfo
```
visualID, sourceID, isCollected, itemID, itemModID, invType,
categoryID, playerCanCollect, isValidSourceForPlayer,
canDisplayOnPlayer, sourceType, name, quality
```

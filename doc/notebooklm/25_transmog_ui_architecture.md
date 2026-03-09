# Transmog UI Architecture — Frame Hierarchy & Mixins

> Source: `ExtTools/Transmog_DeepDive/source_lua/*.lua` and `*.xml` (build 66263)
> Full wiki: `doc/transmog_deepdive_wiki.md`

## Frame Hierarchy

### TransmogFrame (Main Transmog UI at NPC)

```
TransmogFrame (TransmogFrameMixin)
├─ OutfitCollection (TransmogOutfitCollectionMixin)
│  ├─ ShowEquippedGearSpellFrame
│  ├─ OutfitList → TransmogOutfitEntryMixin (per outfit)
│  ├─ PurchaseOutfitButton / SaveOutfitButton
│  └─ MoneyFrame
├─ OutfitPopup (icon selector for naming)
├─ CharacterPreview (TransmogCharacterMixin)
│  ├─ ModelScene (scene ID 290)
│  ├─ Left/Right/BottomSlots
│  │  ├─ TransmogAppearanceSlotMixin (per armor slot)
│  │  │  ├─ TransmogIllusionSlotMixin (weapon enchants)
│  │  │  └─ TransmogSlotFlyoutDropdownMixin (weapon options)
│  │  └─ TransmogIllusionSlotMixin (standalone)
│  └─ HideIgnoredToggle
└─ WardrobeCollection (TransmogWardrobeMixin, 4 tabs)
   ├─ ItemsFrame (TransmogWardrobeItemsMixin)
   │  ├─ FilterButton, SearchBox, WeaponDropdown
   │  ├─ DisplayTypes (Unassigned/Equipped buttons)
   │  ├─ PagedContent (DressUpModel grid)
   │  └─ SecondaryAppearanceToggle
   ├─ SetsFrame (TransmogWardrobeSetsMixin)
   ├─ CustomSetsFrame (TransmogWardrobeCustomSetsMixin)
   └─ SituationsFrame (TransmogWardrobeSituationsMixin)
```

### WardrobeCollectionFrame (Collections Journal)

```
WardrobeCollectionFrame (WardrobeCollectionFrameMixin)
├─ ItemsCollectionFrame (WardrobeItemsCollectionMixin)
│  ├─ SlotsFrame (slot buttons), Models[1-18] (6×3 grid)
│  └─ PagingFrame
├─ SetsCollectionFrame (WardrobeSetsCollectionMixin)
│  ├─ ListContainer (ScrollBox), DetailsFrame (Model + items)
│  └─ VariantSetsDropdown
├─ SearchBox, FilterButton, ClassDropdown, progressBar
```

### DressUpFrame (Preview)

```
DressUpFrame (DressUpModelFrameMixin)
├─ ModelScene, CustomSetDropdown
├─ CustomSetDetailsPanel (per-slot breakdown)
├─ SetSelectionPanel (transmog set items)
├─ ResetButton, LinkButton, CancelButton
```

## Key Mixin Responsibilities

### TransmogCharacterMixin (Character Preview)
- `SetupSlots()` — Creates from `C_TransmogOutfitInfo.GetSlotGroupInfo()`
- `RefreshSlots()` — Updates 3D model via actor:SetItemTransmogInfo()
- `RefreshSlotWeaponOptions()` — Rebuilds weapon dropdowns
- `UpdateSlot(slotData)` — Highlight slot, show weapon help tip

### TransmogAppearanceSlotMixin (Slot Button)
- `Init(slotData)` — Setup slot data, weapon dropdown, menu
- `Update()` — Icon, border atlas, overlays based on displayType
- `GetSlotInfo()` → C_TransmogOutfitInfo.GetViewedOutfitSlotInfo()
- Border atlases: default / disabled / transmogrified / transmogrified-hidden

### TransmogItemModelMixin (Appearance Grid Item)
- `UpdateItem()` — TryOn for armor, SetItemAppearance for weapons
- `UpdateItemBorder()` — pending/transmogrified/saved state

### WardrobeSetsDataProviderMixin (Set Data Cache)
- `GetBaseSets()` / `GetUsableSets()` / `GetVariantSets()`
- `SortSets()` — favorite > collected > expansion > patch > uiOrder
- `GetSetSourceData(setID)` — numCollected, numTotal

### WardrobeCustomSetManager (Custom Set Workflow)
- `EvaluateAppearances()` — Validate sources, find preferred alternatives
- `EvaluateSaveState()` — Show dialog based on valid/invalid/pending
- `ContinueWithSave()` — ModifyCustomSet or show name dialog

## Event Flow: Outfit Selection → Slot Update

```
Click outfit → SelectEntry()
  → C_TransmogOutfitInfo.ChangeViewedOutfit(outfitID)
    → VIEWED_TRANSMOG_OUTFIT_CHANGED
      → CharacterMixin: SetupSlots() + RefreshSlots()
      → OutfitCollection: UpdateSelectedOutfit()
      → WardrobeItems: UpdateSlot()
```

## Event Flow: Appearance Selection → Save

```
Click appearance → SetPendingTransmog(slot, type, option, transmogID, displayType)
  → Slot shows pending animation
  → UpdateCostDisplay()

Click "Save" → CommitAndApplyAllPending(useDiscount)
  → VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS (per slot)
    → Show saved animation
  → TRANSMOG_OUTFITS_CHANGED
    → RefreshOutfits()
```

## Key Events

| Event | Source | Response |
|-------|--------|----------|
| VIEWED_TRANSMOG_OUTFIT_CHANGED | ChangeViewedOutfit | Refresh all slots |
| VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH | Server | Full slot refresh |
| VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS | CommitAndApply | Saved animation |
| VIEWED_TRANSMOG_OUTFIT_SLOT_WEAPON_OPTION_CHANGED | SetViewedWeaponOption | Refresh weapons |
| VIEWED_TRANSMOG_OUTFIT_SECONDARY_SLOTS_CHANGED | SetSecondarySlotState | Rebuild secondary |
| TRANSMOG_OUTFITS_CHANGED | AddNewOutfit/Commit | Refresh outfit list |
| TRANSMOG_DISPLAYED_OUTFIT_CHANGED | ChangeDisplayedOutfit | Update active |
| TRANSMOG_COLLECTION_UPDATED | Server | Clear all caches |

## Slot Border Art (by displayType)

```
Unassigned → transmog-gearslot-default + unassigned atlas icon
Assigned   → transmog-gearslot-transmogrified
Equipped   → transmog-gearslot-default + ShowEquippedIcon overlay
Hidden     → transmog-gearslot-transmogrified-hidden + HiddenVisualIcon
Disabled   → transmog-gearslot-disabled + DisabledIcon
```

## DB2 Slot Layout Reference

14 slots, linked via OtherSlot:
- Shoulder R(ID=2) ↔ Shoulder L(ID=3) — bidirectional
- MH(ID=13) and OH(ID=14) — weapon options define pairs
- Weapons: Flags=3 (CannotBeHidden+CanHaveIllusions), CollectionType=0

## 30-Row Outfit Wire Format

12 armor (option=0) + 9 MH options + 9 OH options
- MH wire order: 1, 6, 2, 3, 7, 8, 9, 10, 11
- OH wire order: 1, 6, 7, 5, 4, 8, 9, 10, 11

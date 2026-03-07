# Task: Fix Floating Transmog Appearances in 12.x Client

## Problem

When a player transmogs gear (changes its visual appearance), the item models render at **wrong attachment points** on the character skeleton instead of fitting correctly on the body:

- Helms appear at nose level instead of the head
- Boots appear at the knees instead of the feet
- Chest pieces float above/around the torso
- The same issue occurs on ALL races and characters

**Key facts:**
- Non-transmogged gear renders perfectly — equipping new items always looks correct
- The floating ONLY occurs on items that have a transmog appearance applied
- The issue persists after relogging — it's not a temporary client state problem
- The floating is visible on the **character select screen** too (warband/loading screen)
- Single-item transmog (via `HandleTransmogrifyItems`) and outfit-based transmog both float
- The 12.x Midnight client is the target client

## Architecture Overview

When an item is transmogged, the server sets item modifiers like `ITEM_MODIFIER_TRANSMOG_APPEARANCE_ALL_SPECS` on the item instance. These modifiers store the `ItemModifiedAppearanceID` of the desired appearance.

There are two rendering paths that need to work:

### 1. Live Game — `VisibleItem` Update Fields

`Player::SetVisibleItemSlot()` in `src/server/game/Entities/Player/Player.cpp:12140` updates the `VisibleItem` update field for each equipment slot. The client reads these fields to render the character.

The `VisibleItem` struct (from `src/server/game/Entities/Object/Updates/UpdateFields.h:255`):
```cpp
struct VisibleItem : public IsUpdateFieldStructureTag, public HasChangesMask<10>
{
    UpdateField<bool, 0, 1> HasTransmog;
    UpdateField<bool, 0, 2> HasIllusion;
    UpdateField<int32, 0, 3> ItemID;
    UpdateField<int32, 0, 4> SecondaryItemModifiedAppearanceID;
    UpdateField<int32, 0, 5> ConditionalItemAppearanceID;
    UpdateField<uint16, 0, 6> ItemAppearanceModID;
    UpdateField<uint16, 0, 7> ItemVisual;
    UpdateField<uint32, 0, 8> ItemModifiedAppearanceID;
    UpdateField<uint8, 0, 9> Field_18;
};
```

Wire format (from `VisibleItem::WriteCreate` in `UpdateFields.cpp:877`):
```
offset 0:  int32  ItemID
offset 4:  int32  SecondaryItemModifiedAppearanceID
offset 8:  int32  ConditionalItemAppearanceID
offset 12: uint16 ItemAppearanceModID
offset 14: uint16 ItemVisual
offset 16: uint32 ItemModifiedAppearanceID
offset 20: uint8  Field_18
offset 21: bit    HasTransmog
           bit    HasIllusion
           (flush to byte boundary)
```

Current `SetVisibleItemSlot` sets:
- `HasTransmog` = true if item has a transmog appearance modifier
- `HasIllusion` = true if item has an enchant illusion modifier
- `ItemID` = `GetVisibleEntry()` → transmog source item's entry ID (or base item if no transmog)
- `SecondaryItemModifiedAppearanceID` = secondary shoulder appearance ID
- `ItemAppearanceModID` = `ItemModifiedAppearance.ItemAppearanceModifierID` (uint8 in DB2, cast to uint16)
- `ItemVisual` = enchant visual effect ID
- `ItemModifiedAppearanceID` = the ItemModifiedAppearance DB2 entry ID

**NOT set (always 0):**
- `ConditionalItemAppearanceID` — unknown purpose, possibly class/race-conditional appearances
- `Field_18` (uint8) — unknown purpose, added in 12.x

### 2. Character Select — `equipmentCache`

`Player::SaveToDB()` in `Player.cpp:~20967` builds a space-separated string cached in the `characters.equipmentCache` column. The character enum packet reads this to display characters at the select screen.

Cache format per slot (5 fields):
```
InvType DisplayID DisplayEnchantID SubclassID SecondaryModifiedAppearanceID
```

Where:
- `InvType` = `item->GetTemplate()->GetInventoryType()` — always the BASE item's inventory type
- `DisplayID` = `item->GetDisplayId(this)` → resolves transmog chain to `ItemAppearance.ItemDisplayInfoID`
- `SubclassID` = `sItemStore.AssertEntry(item->GetVisibleEntry(this))->SubclassID`

The `VisualItemInfo` packet struct (from `CharacterPackets.h:196`):
```cpp
struct VisualItemInfo {
    uint32 ItemID           = 0;    // NOT populated from cache (always 0)
    uint32 TransmogrifiedItemID = 0; // NOT populated (always 0)
    uint8 Subclass          = 0;
    uint8 InvType           = 0;
    uint32 DisplayID        = 0;
    uint32 DisplayEnchantID = 0;
    int32 SecondaryItemModifiedAppearanceID = 0;
};
```

**`ItemID` and `TransmogrifiedItemID` are always 0** in the char select packet. The client should be able to render based on `DisplayID` (ItemDisplayInfoID) + `InvType` alone.

## Appearance Resolution Chain

When an item has transmog, the server resolves the appearance like this:

```
ITEM_MODIFIER_TRANSMOG_APPEARANCE_ALL_SPECS (uint32: ItemModifiedAppearanceID)
  → sItemModifiedAppearanceStore.LookupEntry(id)
    → ItemModifiedAppearance.ItemID          (the transmog source item entry)
    → ItemModifiedAppearance.ItemAppearanceID
      → sItemAppearanceStore.LookupEntry(appearanceID)
        → ItemAppearance.ItemDisplayInfoID   (the model/texture reference)
        → ItemAppearance.DisplayType
```

Key functions:
- `Item::GetVisibleEntry()` → returns `ItemModifiedAppearance.ItemID` (Item.cpp:2585)
- `Item::GetVisibleAppearanceModId()` → returns `ItemModifiedAppearance.ItemAppearanceModifierID` (Item.cpp:2597)
- `Item::GetDisplayId()` → returns `ItemAppearance.ItemDisplayInfoID` (Item.cpp:2522)
- `Item::GetVisibleModifiedAppearanceId()` → returns the `ItemModifiedAppearanceID` itself (Item.cpp:2609)

For NON-transmogged items, these functions fall through to the base item's data, and rendering is correct.

## What We've Already Investigated

1. **`HasTransmog`/`HasIllusion` flags** — Were never being set (stock TrinityCore behavior). We added code to set them. Confirmed upstream TrinityCore master also does NOT set them. Setting them did NOT fix the floating.

2. **`ConditionalItemAppearanceID`** — Never set, always 0. Unknown purpose. Could be related.

3. **`Field_18`** (uint8) — Never set, always 0. Unknown purpose. New in 12.x. Could be a slot hint, display type flag, or something else.

4. **Verified all resolution functions** — `GetVisibleEntry`, `GetVisibleModifiedAppearanceId`, `GetDisplayId`, `GetVisibleAppearanceModId` all follow the correct DB2 lookup chain.

5. **Character select path** — `ItemID` and `TransmogrifiedItemID` are always 0 in the char enum packet. Non-transmogged items render fine despite `ItemID=0`, so the client uses `DisplayID`+`InvType` for char select rendering.

6. **InvType mismatch theory** — The equipmentCache uses the BASE item's `InvType` but the transmog source's `DisplayID`. Transmog validation ensures compatible types, so this should be fine.

## Hypotheses to Investigate

### H1: `Field_18` encodes essential rendering information
`Field_18` is a uint8 added in 12.x that we never set. It could be:
- A display type flag (0=normal, 1=transmog, 2=illusion)
- An inventory type override for the transmog source
- A component model selector
- Related to `ItemAppearance.DisplayType`

**Action:** Check what `ItemAppearance.DisplayType` values exist in the DB2 data. Try setting `Field_18` to `ItemAppearance.DisplayType` for transmogged items.

### H2: `ConditionalItemAppearanceID` needs a value
This field might need to be set to the `ItemModifiedAppearanceID` or `ItemAppearanceID` for the client to properly resolve the transmog.

**Action:** Try setting it to the `ItemModifiedAppearanceID` or `ItemAppearanceID` and test.

### H3: The client uses `ItemModifiedAppearanceID` differently than expected
Maybe when the client sees a non-zero `ItemModifiedAppearanceID`, it expects `ItemID` to be the BASE equipped item (not the transmog source). The client might use `ItemModifiedAppearanceID` to determine the visual and `ItemID` to determine the attachment.

**Action:** Try changing `GetVisibleEntry()` to return `GetEntry()` (base item) when there's a transmog, instead of `transmog->ItemID`. The transmog visual would come from `ItemModifiedAppearanceID` alone.

### H4: Character select needs `TransmogrifiedItemID` populated
The char select screen might need `TransmogrifiedItemID` to distinguish base vs transmogged items.

**Action:** Populate `TransmogrifiedItemID` in the `VisualItemInfo` struct. This requires storing it in the equipmentCache.

### H5: The `ItemAppearanceModifierID` type mismatch
The DB2 defines `ItemAppearanceModifierID` as `uint8` (byte) per client meta, but it's sent as `uint16` in `VisibleItem.ItemAppearanceModID`. If the value is correct (0-255 range), this shouldn't matter, but verify the actual values being sent.

**Action:** Log the `ItemAppearanceModID` values for transmogged vs non-transmogged items and compare.

### H6: The client derives attachment from `ItemID`, not from slot index
If the client uses the `ItemID` field to look up the item's `InventoryType` and uses THAT for bone attachment (instead of using the VisibleItem array index), then sending the transmog source's ItemID could cause wrong attachment IF the transmog source has a subtly different InventoryType (e.g., INVTYPE_ROBE vs INVTYPE_CHEST).

**Action:** Check if transmog source items have different InventoryType than the equipped items. Try sending the base item's entry as `ItemID` instead.

## Key Files

| File | What |
|------|------|
| `src/server/game/Entities/Player/Player.cpp:12140` | `SetVisibleItemSlot` — sets VisibleItem update fields |
| `src/server/game/Entities/Player/Player.cpp:~20967` | `SaveToDB` equipmentCache builder |
| `src/server/game/Entities/Item/Item.cpp:2522` | `GetDisplayId` → ItemDisplayInfoID resolution |
| `src/server/game/Entities/Item/Item.cpp:2585` | `GetVisibleEntry` → transmog source ItemID |
| `src/server/game/Entities/Item/Item.cpp:2597` | `GetVisibleAppearanceModId` → ItemAppearanceModifierID |
| `src/server/game/Entities/Item/Item.cpp:2609` | `GetVisibleModifiedAppearanceId` → ItemModifiedAppearanceID |
| `src/server/game/Entities/Item/Item.cpp:2631` | `GetVisibleEnchantmentId` → illusion enchant ID |
| `src/server/game/Entities/Object/Updates/UpdateFields.h:255` | `VisibleItem` struct definition |
| `src/server/game/Entities/Object/Updates/UpdateFields.cpp:877` | `VisibleItem::WriteCreate` serialization |
| `src/server/game/Server/Packets/CharacterPackets.h:196` | `VisualItemInfo` struct (char select) |
| `src/server/game/Server/Packets/CharacterPackets.cpp:235` | `VisualItemInfo` serialization |
| `src/server/game/Handlers/TransmogrificationHandler.cpp:156` | `HandleTransmogrifyItems` — single-item transmog |
| `src/server/game/DataStores/DB2Stores.cpp:2796` | `GetItemDisplayId` — fallback display resolution |
| `src/server/game/Entities/Item/Item.cpp:324` | `AppearanceModifierSlotBySpec[]` array |

## DB2 Tables Involved

- **ItemModifiedAppearance**: ID, ItemID, ItemAppearanceModifierID, ItemAppearanceID, OrderIndex, TransmogSourceTypeEnum
- **ItemAppearance**: ID, DisplayType, ItemDisplayInfoID, DefaultIconFileDataID, UiOrder, PlayerConditionID
- **ItemDisplayInfo**: model/texture data (client-side only)
- **Item**: ID, ClassID, SubclassID, SoundOverrideSubclassID, Material, IconFileDataID, ...

Wago DB2 CSVs are at `C:/Users/atayl/VoxCore/wago/wago_csv/major_12/12.0.1.66066/enUS/`

## Acceptance Criteria

1. Transmogged items render at the correct skeleton attachment points (helm on head, boots on feet, etc.)
2. Correct rendering persists after relog
3. Correct rendering on the character select screen
4. Non-transmogged items continue to render correctly (no regression)
5. Both single-item transmog and outfit-based transmog work

## Build

- **Build type**: RelWithDebInfo
- **Build command**: Build in Visual Studio (don't use ninja from CLI)
- **CMake reconfigure**: `cmake --preset x64-RelWithDebInfo` from repo root
- **Test method**: Start worldserver, log in, equip gear, open transmogrifier NPC, apply transmog, observe character model

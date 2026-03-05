# Transmog Client Lua Reference Wiki

> **Target**: WoW 12.0.1 (Midnight) — Build 66220
> **Purpose**: Server-side transmog outfit debugging reference for RoleplayCore
> **Source Files**: 15 client Lua/XML files from the Blizzard UI source
> **Generated**: 2026-03-04

---

## Table of Contents

0. [ID Glossary](#0-id-glossary) *(START HERE)*
1. [Slot Architecture](#1-slot-architecture)
2. [C_Transmog API](#2-c_transmog-api)
3. [C_TransmogCollection API](#3-c_transmogcollection-api)
4. [C_TransmogOutfitInfo API](#4-c_transmogoutfitinfo-api) *(CRITICAL)*
5. [C_TransmogSets API](#5-c_transmogsets-api)
6. [Outfit System Flow](#6-outfit-system-flow)
7. [Paperdoll / Model Rendering](#7-paperdoll--model-rendering)
8. [Events](#8-events)
9. [Enums & Constants](#9-enums--constants)
10. [Key Data Structures](#10-key-data-structures)
11. [Client → Server Packet Triggers](#11-client--server-packet-triggers)
12. [Server → Client Event Triggers](#12-server--client-event-triggers)
13. [Hidden Item / Clear Slot Handling](#13-hidden-item--clear-slot-handling) *(CRITICAL)*
14. [Cross-Reference Index](#14-cross-reference-index)
15. [Server-Side Mapping (RoleplayCore)](#15-server-side-mapping-roleplaycore) *(CRITICAL)*

---

## 0. ID Glossary

The transmog system uses **four distinct ID types**. Confusing them is the #1 cause of server-side bugs.

### 0.1 The Four ID Types

| ID Type | DB2 Table | Client Name(s) | Typical Range | What It Identifies |
|---|---|---|---|---|
| **ItemID** | `Item` / `ItemSparse` | `itemID` | 1–230,000+ | A specific item template (e.g., "Thunderfury") |
| **ItemModifiedAppearanceID** (IMA) | `ItemModifiedAppearance` | `sourceID`, `itemModifiedAppearanceID`, `transmogID` | 1–250,000+ | A specific item + appearance modifier combo. **This is what outfits store.** |
| **ItemAppearanceID** (visual) | `ItemAppearance` | `visualID`, `appearanceID`, `itemAppearanceID` | 1–80,000+ | A visual look. Multiple IMA IDs can share the same visual. |
| **SpellItemEnchantmentID** (illusion) | `SpellItemEnchantment` | `illusionID`, `spellItemEnchantmentID` | 1–8,000+ | A weapon enchant visual effect (glow, trail, etc.) |

### 0.2 The DB2 Lookup Chain

```
ItemID  →  ItemModifiedAppearance  →  ItemAppearance  →  visual model/texture
 (item)       (IMA / sourceID)        (visualID)
                    ↑
              This is what the server stores in outfit slot data
              and what CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS carries
```

- **Item → IMA**: One item can have multiple IMA entries (different color variants via `ItemAppearanceModifierID`).
- **IMA → Visual**: Many-to-one. Multiple items/IMA entries can produce the same visual look.
- **Visual → Sources**: `C_TransmogCollection.GetAppearanceSources(visualID)` returns all IMA entries that share that visual.

### 0.3 Critical Distinction: sourceID vs visualID

| | sourceID (IMA ID) | visualID (Appearance ID) |
|---|---|---|
| **Stored in outfits** | Yes — this is what `Appearances[slot]` holds | No |
| **Collection tracking** | `sourceIsCollected` — player owns this exact source | `appearanceIsCollected` — player owns ANY source with this visual |
| **Sent in packets** | `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS` sends IMA IDs | Not sent directly |
| **Display lookups** | `C_TransmogCollection.GetSourceInfo(sourceID)` | `C_TransmogCollection.GetAppearanceSources(visualID)` |
| **Server storage** | `ITEM_MODIFIER_TRANSMOG_APPEARANCE_ALL_SPECS` stores IMA ID | Not stored server-side |

> **Rule of thumb**: The server **stores and transmits IMA IDs** (sourceID). The client **displays visualIDs** (appearanceID). The client API handles the IMA→visual lookup internally.

### 0.4 Illusion IDs

Illusions are separate from appearances. They use `SpellItemEnchantmentID` and are stored in:
- Server: `ITEM_MODIFIER_ENCHANT_ILLUSION_ALL_SPECS`
- Outfit: `outfit.Enchants[0]` (mainhand), `outfit.Enchants[1]` (offhand)
- Client: `ItemTransmogInfo.illusionID`

A special "hidden illusion" exists (identified by `C_TransmogCollection.IsSpellItemEnchantmentHiddenVisual()`), which removes the enchant visual.

### 0.5 The Zero Sentinel

`Constants.Transmog.NoTransmogID = 0` — used everywhere to mean "no transmog". The server must send `0` (not nil, not -1) for empty/cleared slots.

---

## 1. Slot Architecture

### 1.1 TransmogSlot Enum (0–12)

Defined in `TransmogConstantsDocumentation.lua`. This is the **primary slot identifier** used throughout the entire transmog system.

```lua
-- TransmogSlot (Enumeration, 13 values, 0-12)
TransmogSlot.Head      = 0
TransmogSlot.Shoulder  = 1
TransmogSlot.Back      = 2
TransmogSlot.Chest     = 3
TransmogSlot.Body      = 4   -- Shirt slot
TransmogSlot.Tabard    = 5
TransmogSlot.Wrist     = 6
TransmogSlot.Hand      = 7
TransmogSlot.Waist     = 8
TransmogSlot.Legs      = 9
TransmogSlot.Feet      = 10
TransmogSlot.Mainhand  = 11
TransmogSlot.Offhand   = 12
```

> **NOTE (Server)**: These slot indices do NOT match `EQUIPMENT_SLOT_*` constants used server-side. The server uses EquipmentSlots (0-based: Head=0, Neck=1, Shoulder=2...) while the client transmog system uses its own 0-12 enum that skips non-transmoggable slots (neck, rings, trinkets). The mapping must be maintained in the server's `TransmogrificationUtils.cpp`.

### 1.2 TransmogSlotOrder

Defined in `Blizzard_TransmogShared.lua`. Controls the visual ordering of slots in the transmog UI paperdoll:

```lua
local TransmogSlotOrder = {
    INVSLOT_HEAD,
    INVSLOT_SHOULDER,
    INVSLOT_BACK,
    INVSLOT_CHEST,
    INVSLOT_TABARD,
    INVSLOT_BODY,    -- Shirt
    INVSLOT_WRIST,
    INVSLOT_HAND,
    INVSLOT_WAIST,
    INVSLOT_LEGS,
    INVSLOT_FEET,
    INVSLOT_MAINHAND,
    INVSLOT_OFFHAND,
};
```

> **NOTE (Server)**: The UI iterates slots in this order when building/applying outfits. The server must process all 13 slots regardless of order, but this ordering matters when debugging visual display issues — the client renders top-down.

### 1.3 TRANSMOG_SLOTS Lookup Table

Defined in `Blizzard_TransmogShared.lua`. This is the **master slot registry** populated at runtime by `InitializeSlotLocationInfo()`.

```lua
-- Populated by InitializeSlotLocationInfo() from C_TransmogOutfitInfo.GetAllSlotLocationInfo()
TRANSMOG_SLOTS = {}

-- Key formula:
--   key = slotID * 100 + transmogType * 10 + secondaryValue
-- Where:
--   slotID       = INVSLOT_* constant (1-based inventory slot)
--   transmogType = Enum.TransmogType.Appearance (0) or .Illusion (1)
--   secondaryValue = 0 (primary) or 1 (secondary, e.g. split shoulders)
--
-- Examples:
--   Head appearance (primary):      1 * 100 + 0 * 10 + 0 = 100
--   Shoulder appearance (primary):  3 * 100 + 0 * 10 + 0 = 300
--   Shoulder appearance (secondary):3 * 100 + 0 * 10 + 1 = 301
--   Mainhand illusion:             16 * 100 + 1 * 10 + 0 = 1610
```

Each entry in `TRANSMOG_SLOTS` contains a `TransmogLocationMixin` plus metadata from `TransmogOutfitSlotInfo`:

```lua
-- Each TRANSMOG_SLOTS[key] = {
--   transmogLocation = TransmogLocationMixin,  -- the location object
--   slot             = TransmogOutfitSlot,      -- enum value (0-12)
--   type             = TransmogType,            -- Appearance or Illusion
--   collectionType   = TransmogCollectionType,  -- category for browsing
--   slotName         = string,                  -- localized name
--   isSecondary      = bool,                    -- true for split shoulders, etc.
-- }
```

### 1.4 TransmogLocationMixin

Defined in `Blizzard_TransmogShared.lua`. This is the core object that identifies a specific transmog "location" — a combination of slot, type, and modification.

```lua
TransmogLocationMixin = {}

function TransmogLocationMixin:Set(slotID, type, modification)
    self.slotID = slotID           -- INVSLOT_* (1-based)
    self.type = type               -- Enum.TransmogType.Appearance or .Illusion
    self.modification = modification -- Enum.TransmogModification.Main or .Secondary
end

-- Key methods:
function TransmogLocationMixin:IsAppearance()
    return self.type == Enum.TransmogType.Appearance
end

function TransmogLocationMixin:IsIllusion()
    return self.type == Enum.TransmogType.Illusion
end

function TransmogLocationMixin:IsSecondary()
    return self.modification == Enum.TransmogModification.Secondary
end

function TransmogLocationMixin:GetSlotID()
    return self.slotID  -- Returns INVSLOT_* (1-based)
end

function TransmogLocationMixin:GetSlotName()
    -- Returns localized slot name via TransmogUtil
end

function TransmogLocationMixin:GetLookupKey()
    -- Returns the numeric key used in TRANSMOG_SLOTS
    return TransmogUtil.GetTransmogLocationLookupKey(self)
end

-- IsMainHand / IsOffHand convenience:
function TransmogLocationMixin:IsMainHand()
    return self.slotID == INVSLOT_MAINHAND
end

function TransmogLocationMixin:IsOffHand()
    return self.slotID == INVSLOT_OFFHAND
end
```

> **NOTE (Server)**: The `TransmogLocationMixin` is purely client-side. Server-side, we use `TransmogSlot` enum values (0-12) directly. The mapping between INVSLOT_* (1-based) and TransmogSlot (0-based) is handled by `C_TransmogOutfitInfo.GetTransmogOutfitSlotFromInventorySlot()` on the client and by lookup tables on the server.

### 1.5 TransmogUtil Helper Functions

From `Blizzard_TransmogShared.lua`:

```lua
TransmogUtil = {}

-- Create a TransmogLocation from slot/type/modification enums
function TransmogUtil.CreateTransmogLocation(slotID, type, modification)
    local location = CreateFromMixins(TransmogLocationMixin)
    location:Set(slotID, type, modification)
    return location
end

-- Get lookup key for TRANSMOG_SLOTS table
function TransmogUtil.GetTransmogLocationLookupKey(transmogLocation)
    local slotID = transmogLocation:GetSlotID()
    local type = transmogLocation.type
    local secondary = transmogLocation:IsSecondary() and 1 or 0
    return slotID * 100 + type * 10 + secondary
end

-- Get slot info for what's currently equipped
function TransmogUtil.GetInfoForEquippedSlot(transmogLocation)
    -- Returns appliedSourceID, appliedVisualID, etc. for an equipped item
    return C_Transmog.GetSlotVisualInfo(transmogLocation)
end
```

### 1.6 Slot Groups and Positioning

From `C_TransmogOutfitInfo.GetSlotGroupInfo()`, slots are organized into positional groups for UI layout:

```lua
-- TransmogOutfitSlotGroup structure:
-- {
--   position = TransmogOutfitSlotPosition,  -- Left, Right, Bottom
--   appearanceSlotInfo = { TransmogOutfitSlotInfo, ... },
--   illusionSlotInfo   = { TransmogOutfitSlotInfo, ... },
-- }
```

The `TransmogCharacterMixin:SetupSlots()` method uses `GetSlotGroupInfo()` to arrange appearance and illusion slots around the paperdoll character model.

### 1.7 Secondary Slots (Split Shoulders, Paired Weapons)

Certain slots support a **secondary appearance**:

- **Shoulder** — Split shoulders (left/right can differ)
- **Mainhand** — Paired weapons (artifact appearances that set both hands)

```lua
-- Check if a slot supports secondary appearances:
C_Transmog.CanHaveSecondaryAppearanceForSlotID(slotID)

-- Check if secondary is currently active:
C_TransmogOutfitInfo.SlotHasSecondary(slot)

-- Get/set secondary state:
C_TransmogOutfitInfo.GetSecondarySlotState(slot) --> bool
C_TransmogOutfitInfo.SetSecondarySlotState(slot, state) --> may return nothing

-- In the UI, TransmogAppearanceSlotMixin handles the secondary toggle:
-- A checkbox/button appears when CanHaveSecondaryAppearanceForSlotID returns true
```

> **NOTE (Server)**: Secondary shoulder transmog is a known gap in our implementation. The server sends `secondaryAppearanceID` in outfit data but the client rendering of split shoulders requires both the primary and secondary transmog IDs to be set correctly. See `transmog-implementation.md` for the current state.

### 1.8 Weapon Options

Weapon slots (Mainhand, Offhand) have additional complexity via "weapon options" — different weapon categories that can be transmogged:

```lua
-- Get available weapon options for a slot:
C_TransmogOutfitInfo.GetWeaponOptionsForSlot(slot)
-- Returns: weaponOptions (table of TransmogOutfitWeaponOptionInfo), artifactOptions (optional)

-- TransmogOutfitWeaponOptionInfo:
-- {
--   weaponOption = TransmogOutfitSlotOption,  -- enum identifying the weapon type
--   name = string,                            -- e.g. "One-Handed Swords"
--   enabled = bool,                           -- can the player use this option
-- }

-- Set which weapon option is being viewed:
C_TransmogOutfitInfo.SetViewedWeaponOptionForSlot(slot, weaponOption)

-- Get what's equipped for the weapon option:
C_TransmogOutfitInfo.GetEquippedSlotOptionFromTransmogSlot(slot) --> weaponOption
```

### 1.9 Inventory Slot Mapping

Two functions map between different slot numbering systems:

```lua
-- InventoryType (from item data) → TransmogOutfitSlot (0-12):
C_TransmogOutfitInfo.GetTransmogOutfitSlotForInventoryType(inventoryType)

-- InventorySlot (INVSLOT_*) → TransmogOutfitSlot (0-12):
C_TransmogOutfitInfo.GetTransmogOutfitSlotFromInventorySlot(inventorySlot)

-- TransmogSlot (old system) → InventoryType:
C_Transmog.GetSlotForInventoryType(inventoryType)
```

> **NOTE (Server)**: These mapping functions are critical. When the server builds outfit data, it must use the correct slot numbering. A mismatch between inventory type and transmog slot will cause the client to apply appearances to the wrong equipment slot.

---

## 2. C_Transmog API

**Namespace**: `C_Transmog` | **Source**: `TransmogDocumentation.lua`
**System Name**: `Transmogrify` | **7 Functions, 15 Events, 5 Structures**

This is the **low-level transmog API** — slot visual queries, NPC proximity checks, and collection events. In 12.x, most outfit logic has moved to `C_TransmogOutfitInfo`, but `C_Transmog` remains the source of truth for equipped slot visual state.

### 2.1 Functions

#### `C_Transmog.CanHaveSecondaryAppearanceForSlotID(slotID) → canHaveSecondaryAppearance`

```lua
-- Arguments:
--   slotID : luaIndex (INVSLOT_* constant)
-- Returns:
--   canHaveSecondaryAppearance : bool
-- SecretArguments: AllowedWhenUntainted
```

Returns whether the given inventory slot supports a secondary (split) appearance. Currently true for Shoulder and Mainhand.

> **NOTE (Server)**: The server must track this per-slot capability. If the server sends secondary appearance data for a slot that doesn't support it, the client will ignore it silently.

#### `C_Transmog.ExtractTransmogIDList(input) → transmogIDList`

```lua
-- Arguments:
--   input : cstring — serialized transmog ID string
-- Returns:
--   transmogIDList : table<number> — array of transmog IDs
-- SecretArguments: AllowedWhenUntainted
```

Parses a serialized string of transmog IDs into a Lua table. Used internally for custom set slash commands and hyperlinks.

#### `C_Transmog.GetAllSetAppearancesByID(setID) → setItems`

```lua
-- Arguments:
--   setID : number — transmog set ID
-- Returns:
--   setItems : table<TransmogSetItemInfo> or nil
-- SecretArguments: AllowedWhenUntainted
```

Returns all items in a transmog set with their appearance IDs and inventory slots. Used by set browsing UI.

```lua
-- TransmogSetItemInfo:
-- {
--   itemID                  : number,
--   itemModifiedAppearanceID : number,
--   invSlot                 : number,
--   invType                 : string,
-- }
```

#### `C_Transmog.GetItemIDForSource(itemModifiedAppearanceID) → itemID`

```lua
-- Arguments:
--   itemModifiedAppearanceID : number
-- Returns:
--   itemID : number or nil
-- SecretArguments: AllowedWhenUntainted
```

Resolves an ItemModifiedAppearance ID back to the originating item ID. Used for tooltips and item links.

> **NOTE (Server)**: This maps to the `item_modified_appearance` DB2 table. The server equivalent is looking up `ItemModifiedAppearance.db2` → `ItemID`.

#### `C_Transmog.GetSlotForInventoryType(inventoryType) → slot`

```lua
-- Arguments:
--   inventoryType : luaIndex — item inventory type enum
-- Returns:
--   slot : luaIndex — or MayReturnNothing
-- SecretArguments: AllowedWhenUntainted
```

Maps an item's inventory type to the transmog slot index. Returns nothing for non-transmoggable inventory types.

#### `C_Transmog.GetSlotVisualInfo(transmogLocation) → slotVisualInfo`

```lua
-- Arguments:
--   transmogLocation : TransmogLocationMixin
-- Returns:
--   slotVisualInfo : TransmogSlotVisualInfo — or MayReturnNothing
-- SecretArguments: AllowedWhenUntainted
```

**The primary function for querying what a slot currently looks like.** Returns base, applied, and pending source/visual IDs for a given slot.

```lua
-- TransmogSlotVisualInfo:
-- {
--   baseSourceID    : number,  -- source ID of the actual equipped item
--   baseVisualID    : number,  -- visual of the actual equipped item
--   appliedSourceID : number,  -- source ID of the currently active transmog
--   appliedVisualID : number,  -- visual of the currently active transmog
--   pendingSourceID : number,  -- source ID of a pending (not yet applied) transmog
--   pendingVisualID : number,  -- visual of a pending transmog
--   hasUndo         : bool,    -- can the transmog be undone
--   isHideVisual    : bool,    -- is this slot using a "hidden" appearance
--   itemSubclass    : number,  -- weapon subclass for weapon slots
-- }
```

> **NOTE (Server)**: This is what `TransmogUtil.GetInfoForEquippedSlot()` wraps. The `appliedSourceID` reflects the active transmog on the equipped item. When the server sends `SMSG_TRANSMOGRIFY_UPDATE`, it updates these values. If `appliedSourceID == 0`, no transmog is applied. If `isHideVisual == true`, the slot is using a hidden appearance item.

#### `C_Transmog.IsAtTransmogNPC() → isAtNPC`

```lua
-- Returns:
--   isAtNPC : bool
```

Returns whether the player is currently interacting with a transmogrification NPC. Controls whether the transmog UI can apply changes.

> **NOTE (Server)**: On our server, we may bypass NPC proximity for roleplay purposes. The client checks this before allowing `CommitAndApplyAllPending`. If the server processes a transmog request without the NPC check, the client may still block UI interaction until `TRANSMOGRIFY_OPEN` fires.

### 2.2 Events

#### `TRANSMOGRIFY_OPEN`
```lua
-- Payload: none
-- SynchronousEvent: true
```
Fired when the player opens the transmog NPC interface. The TransmogFrame registers for this to show the UI.

> **NOTE (Server)**: The server sends `SMSG_OPEN_TRANSMOGRIFIER` to trigger this. Without it, the client transmog frame won't open.

#### `TRANSMOGRIFY_CLOSE`
```lua
-- Payload: none
-- SynchronousEvent: true
```
Fired when the transmog NPC interaction ends. Closes the TransmogFrame.

#### `TRANSMOGRIFY_UPDATE`
```lua
-- Payload:
--   transmogLocation : TransmogLocationMixin (nilable)
--   action : cstring (nilable)
-- SynchronousEvent: true
```
Fired when a transmog state changes (pending set, reverted, etc.). The TransmogFrame uses this to refresh slot displays.

#### `TRANSMOGRIFY_SUCCESS`
```lua
-- Payload:
--   transmogLocation : TransmogLocationMixin
-- SynchronousEvent: true
```
Fired after a successful transmog application for a specific slot.

#### `TRANSMOGRIFY_ITEM_UPDATE`
```lua
-- Payload: none
-- UniqueEvent: true
```
Fired when an item's transmog state changes (e.g., item swapped in a slot).

#### `TRANSMOG_COLLECTION_UPDATED`
```lua
-- Payload:
--   collectionIndex : luaIndex (nilable)
--   modID : number (nilable)
--   itemAppearanceID : number (nilable)
--   reason : cstring (nilable)
-- SynchronousEvent: true, UniqueEvent: true
```
Fired when the player's transmog collection changes (new appearance learned, etc.).

#### `TRANSMOG_COLLECTION_SOURCE_ADDED`
```lua
-- Payload:
--   itemModifiedAppearanceID : number
-- SynchronousEvent: true
```
Fired when a specific source is added to the collection.

#### `TRANSMOG_COLLECTION_SOURCE_REMOVED`
```lua
-- Payload:
--   itemModifiedAppearanceID : number
-- SynchronousEvent: true
```
Fired when a source is removed from the collection.

#### `TRANSMOG_COLLECTION_ITEM_UPDATE`
```lua
-- Payload: none
-- UniqueEvent: true
```
General collection item update signal.

#### `TRANSMOG_COLLECTION_ITEM_FAVORITE_UPDATE`
```lua
-- Payload:
--   itemAppearanceID : number
--   isFavorite : bool
-- SynchronousEvent: true
```
Fired when an appearance's favorite status changes.

#### `TRANSMOG_COLLECTION_CAMERA_UPDATE`
```lua
-- Payload: none
-- SynchronousEvent: true
```
Fired when the collection camera needs updating (model rotation/zoom changed).

#### `TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED`
```lua
-- Payload:
--   itemModifiedAppearanceID : number
-- SynchronousEvent: true
```
Fired when a cosmetic (non-armor-class-restricted) source is learned.

#### `TRANSMOG_SEARCH_UPDATED`
```lua
-- Payload:
--   searchType : TransmogSearchType
--   collectionType : TransmogCollectionType (nilable)
-- SynchronousEvent: true
```
Fired when search results are updated.

#### `TRANSMOG_SETS_UPDATE_FAVORITE`
```lua
-- Payload: none
-- SynchronousEvent: true
```
Fired when a set's favorite status changes.

#### `TRANSMOG_SOURCE_COLLECTABILITY_UPDATE`
```lua
-- Payload:
--   itemModifiedAppearanceID : number
--   collectable : bool
-- SynchronousEvent: true
```
Fired when a source's collectability status changes.

---

## 3. C_TransmogCollection API

**Namespace**: `C_TransmogCollection` | **Source**: `TransmogItemsDocumentation.lua`
**System Name**: `TransmogrifyCollection` | **83 Functions, 0 Events, 8 Structures**

This API manages the player's transmog **collection** — appearances they've learned, custom sets (client-local presets), search/filter, and source info. It has NO events of its own (collection changes fire through `C_Transmog` events above).

### 3.1 Collection Query Functions

#### `C_TransmogCollection.GetAppearanceSources(appearanceID, categoryType?, transmogLocation?) → sources`

```lua
-- Arguments:
--   appearanceID : number — the visual appearance ID
--   categoryType : TransmogCollectionType (optional)
--   transmogLocation : TransmogLocationMixin (optional)
-- Returns:
--   sources : table<AppearanceSourceInfo> — or MayReturnNothing
```

Returns all item sources that produce a given visual appearance. This is the core function for "what items give this look?"

#### `C_TransmogCollection.GetAllAppearanceSources(itemAppearanceID) → itemModifiedAppearanceIDs`

```lua
-- Arguments:
--   itemAppearanceID : number
-- Returns:
--   itemModifiedAppearanceIDs : table<number>
```

Returns all ItemModifiedAppearance IDs for a given appearance. Lower level than `GetAppearanceSources`.

#### `C_TransmogCollection.GetSourceInfo(sourceID) → sourceInfo`

```lua
-- Arguments:
--   sourceID : number — ItemModifiedAppearance ID
-- Returns:
--   sourceInfo : AppearanceSourceInfo — or MayReturnNothing
```

Returns full info for a specific source. See `AppearanceSourceInfo` in Section 10.

#### `C_TransmogCollection.GetSourceItemID(itemModifiedAppearanceID) → itemID`

```lua
-- Returns the item ID for a given ItemModifiedAppearance.
-- MayReturnNothing if the source doesn't resolve.
```

#### `C_TransmogCollection.GetSourceIcon(itemModifiedAppearanceID) → icon`

```lua
-- Returns the fileID for the item's icon texture.
```

#### `C_TransmogCollection.GetAppearanceInfoBySource(itemModifiedAppearanceID) → info`

```lua
-- Returns: TransmogAppearanceInfoBySourceData — or MayReturnNothing
-- {
--   appearanceID                      : number,
--   appearanceIsCollected             : bool,
--   sourceIsCollected                 : bool,
--   sourceIsCollectedPermanent        : bool,
--   sourceIsCollectedConditional      : bool,
--   meetsTransmogPlayerCondition      : bool,
--   appearanceHasAnyNonLevelRequirements : bool,
--   appearanceMeetsNonLevelRequirements  : bool,
--   appearanceIsUsable                : bool,
--   appearanceNumSources              : number,
--   sourceIsKnown                     : bool,
--   canDisplayOnPlayer                : bool,
--   isAnySourceValidForPlayer         : bool,
-- }
```

> **NOTE (Server)**: The `sourceIsCollected` vs `appearanceIsCollected` distinction matters. An appearance can be collected (the visual is known) even if the specific source item isn't — because another item with the same visual was collected. The server must track both levels.

#### `C_TransmogCollection.GetAppearanceSourceInfo(itemModifiedAppearanceID) → info`

```lua
-- Returns: TransmogAppearanceSourceInfoData — or MayReturnNothing
-- {
--   category        : TransmogCollectionType,
--   itemAppearanceID : number,
--   canHaveIllusion : bool,
--   icon            : fileID,
--   isCollected     : bool,
--   itemLink        : string,
--   transmoglink    : string,
--   sourceType      : luaIndex (nilable),
--   itemSubclass    : number,
-- }
```

#### `C_TransmogCollection.GetAppearanceSourceDrops(itemModifiedAppearanceID) → encounterInfo`

```lua
-- Returns: table<TransmogAppearanceJournalEncounterInfo> — or MayReturnNothing
-- {
--   instance     : string,      -- dungeon/raid name
--   instanceType : number,
--   tiers        : table<string>,
--   encounter    : string,      -- boss name
--   difficulties : table<string>,
-- }
```

#### `C_TransmogCollection.GetCategoryAppearances(category, transmogLocation?) → appearances`

```lua
-- Arguments:
--   category : TransmogCollectionType — e.g. "Plate", "Leather", "OneHandedSwords"
--   transmogLocation : TransmogLocationMixin (optional)
-- Returns:
--   appearances : table<TransmogCategoryAppearanceInfo> — or MayReturnNothing
```

Returns all appearances in a collection category. This drives the wardrobe grid.

```lua
-- TransmogCategoryAppearanceInfo:
-- {
--   visualID            : number,
--   isCollected          : bool,
--   isFavorite           : bool,
--   isHideVisual         : bool,   -- This is the "hidden item" appearance
--   canDisplayOnPlayer   : bool,
--   uiOrder              : number,
--   exclusions           : number,
--   isUsable             : bool,
--   hasRequiredHoliday   : bool,
--   hasActiveRequiredHoliday : bool,
--   alwaysShowItem       : bool (nilable), -- internal testing only
-- }
```

#### `C_TransmogCollection.GetCategoryInfo(category) → name, isWeapon, canHaveIllusions, canMainHand, canOffHand, canRanged`

```lua
-- Returns category metadata: name, whether it's a weapon category,
-- whether items in it can have illusions, and which hand slots they fit.
```

#### `C_TransmogCollection.GetCategoryCollectedCount(category) → count`
#### `C_TransmogCollection.GetCategoryTotal(category) → total`
#### `C_TransmogCollection.GetFilteredCategoryCollectedCount(category) → count`
#### `C_TransmogCollection.GetFilteredCategoryTotal(category) → total`

```lua
-- Progress tracking functions for the collection UI progress bar.
-- "Filtered" variants respect current search/filter settings.
```

#### `C_TransmogCollection.GetCategoryForItem(itemModifiedAppearanceID) → collectionCategory`

```lua
-- Returns which TransmogCollectionType a source belongs to.
```

### 3.2 Player Collection State

#### `C_TransmogCollection.PlayerHasTransmog(itemID, itemAppearanceModID?) → hasTransmog`

```lua
-- Check if the player has collected a transmog by item ID + optional mod ID.
-- Default itemAppearanceModID = 0.
```

#### `C_TransmogCollection.PlayerHasTransmogByItemInfo(itemInfo) → hasTransmog`

```lua
-- Same as above but takes an ItemInfo (item link/string).
```

#### `C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(itemModifiedAppearanceID) → hasTransmog`

```lua
-- Check by ItemModifiedAppearance ID directly.
```

#### `C_TransmogCollection.PlayerCanCollectSource(sourceID) → hasItemData, canCollect`

```lua
-- Returns whether the player CAN collect a source (class/level restrictions).
-- hasItemData: whether the item data is loaded
-- canCollect: whether this character can collect it
```

#### `C_TransmogCollection.AccountCanCollectSource(sourceID) → hasItemData, canCollect`

```lua
-- Account-wide version — any character on the account could collect this.
```

#### `C_TransmogCollection.PlayerKnowsSource(sourceID) → isKnown`

```lua
-- Whether the player knows this specific source (not just the appearance).
```

#### `C_TransmogCollection.IsValidTransmogSource(source) → valid`

```lua
-- Whether a TransmogSource value is valid.
```

#### `C_TransmogCollection.GetNumTransmogSources() → count`

```lua
-- Total number of transmog sources in the game.
```

### 3.3 Appearance Utility

#### `C_TransmogCollection.IsAppearanceHiddenVisual(appearanceID) → isHiddenVisual`

```lua
-- Returns true if this appearance is a "hidden item" appearance.
-- Used to identify the special hide-slot appearances.
```

> **NOTE (Server)**: This is CRITICAL for hidden item handling. See Section 13. The server must know which appearance IDs are "hidden" so it can properly clear/hide slots.

#### `C_TransmogCollection.IsSpellItemEnchantmentHiddenVisual(spellItemEnchantmentID) → isHiddenVisual`

```lua
-- Returns true if this enchantment (illusion) is the "hidden" illusion.
```

#### `C_TransmogCollection.CanAppearanceHaveIllusion(appearanceID) → canHaveIllusion`

```lua
-- Whether an appearance can have a weapon illusion applied.
-- Only weapon appearances return true.
```

#### `C_TransmogCollection.IsNewAppearance(visualID) → isNew`
#### `C_TransmogCollection.ClearNewAppearance(visualID)`
#### `C_TransmogCollection.GetLatestAppearance() → visualID, category`

```lua
-- "New appearance" tracking — glow indicators in the wardrobe UI.
```

#### `C_TransmogCollection.GetIsAppearanceFavorite(itemAppearanceID) → isFavorite`
#### `C_TransmogCollection.SetIsAppearanceFavorite(itemAppearanceID, isFavorite)`
#### `C_TransmogCollection.HasFavorites() → hasFavorites`

```lua
-- Favorite management for appearances.
```

#### `C_TransmogCollection.GetAppearanceCameraID(itemAppearanceID, variation?) → cameraID`
#### `C_TransmogCollection.GetAppearanceCameraIDBySource(itemModifiedAppearanceID, variation?) → cameraID`

```lua
-- Camera positioning for model preview. variation is TransmogCameraVariation:
--   None = 0, RightShoulder = 1, CloakBackpack = 1
-- (Note: RightShoulder and CloakBackpack share value 1)
```

#### `C_TransmogCollection.GetPairedArtifactAppearance(itemModifiedAppearanceID) → pairedItemModifiedAppearanceID`

```lua
-- For artifact weapons — returns the paired off-hand appearance.
-- MayReturnNothing if not an artifact or no pair exists.
```

#### `C_TransmogCollection.GetArtifactAppearanceStrings(appearanceID) → name, hyperlink`

```lua
-- Returns artifact appearance name and hyperlink for tooltips.
```

#### `C_TransmogCollection.GetFallbackWeaponAppearance() → appearanceID`

```lua
-- Returns a fallback appearance for weapons when no transmog is set.
```

#### `C_TransmogCollection.GetSourceRequiredHoliday(itemModifiedAppearanceID) → holidayName`

```lua
-- Returns the holiday name required to use this source (e.g., "Hallow's End").
```

### 3.4 Custom Sets (Client-Local Presets)

Custom sets are **client-local** outfit presets stored in the client's saved variables. They are NOT the same as server-stored transmog outfits.

#### `C_TransmogCollection.GetCustomSets() → customSetIDs`

```lua
-- Returns array of all custom set IDs.
```

#### `C_TransmogCollection.NewCustomSet(name, icon, itemTransmogInfoList) → customSetID`

```lua
-- Creates a new custom set with a name, icon, and list of ItemTransmogInfo.
-- Returns the new custom set ID, or nil on failure.
```

#### `C_TransmogCollection.ModifyCustomSet(customSetID, itemTransmogInfoList)`

```lua
-- Updates an existing custom set's appearances.
```

#### `C_TransmogCollection.DeleteCustomSet(customSetID)`

```lua
-- Deletes a custom set.
```

#### `C_TransmogCollection.RenameCustomSet(customSetID, name)`

```lua
-- Renames a custom set.
```

#### `C_TransmogCollection.GetCustomSetInfo(customSetID) → name, icon`

```lua
-- Returns the name and icon of a custom set.
```

#### `C_TransmogCollection.GetCustomSetItemTransmogInfoList(customSetID) → list`

```lua
-- Returns the ItemTransmogInfo list for a custom set.
-- ItemTransmogInfo = { appearanceID, secondaryAppearanceID, illusionID }
```

#### `C_TransmogCollection.GetNumMaxCustomSets() → maxCustomSets`

```lua
-- Maximum number of custom sets the player can have.
```

#### `C_TransmogCollection.IsValidCustomSetName(name) → isApproved`

```lua
-- Name validation (profanity filter, length, etc.).
```

#### `C_TransmogCollection.GetCustomSetHyperlinkFromItemTransmogInfoList(itemTransmogInfoList) → hyperlink`

```lua
-- Generates a shareable hyperlink from a custom set's appearances.
```

#### `C_TransmogCollection.GetItemTransmogInfoListFromCustomSetHyperlink(hyperlink) → list`

```lua
-- Parses a custom set hyperlink back into an ItemTransmogInfo list.
```

> **NOTE (Server)**: Custom sets are entirely client-side. The server never sees them directly. However, when a player applies a custom set through the transmog UI, it results in normal `SetPendingTransmog` calls followed by `CommitAndApplyAllPending`, which the server DOES handle. The custom set is just a client convenience for populating pending transmogs.

### 3.5 Illusion Functions

#### `C_TransmogCollection.GetIllusions() → illusions`

```lua
-- Returns: table<TransmogIllusionInfo>
-- {
--   visualID     : number,
--   sourceID     : number,
--   icon         : fileID,
--   isCollected  : bool,
--   isUsable     : bool,
--   isHideVisual : bool,  -- The "no illusion" option
-- }
```

#### `C_TransmogCollection.GetIllusionInfo(illusionID) → info`

```lua
-- Returns TransmogIllusionInfo for a specific illusion.
```

#### `C_TransmogCollection.GetIllusionStrings(illusionID) → name, hyperlink, sourceText`

```lua
-- Returns display strings for an illusion.
```

### 3.6 Search & Filter Functions

#### `C_TransmogCollection.SetSearch(searchType, searchText) → completed`
#### `C_TransmogCollection.ClearSearch(searchType) → completed`
#### `C_TransmogCollection.EndSearch()`
#### `C_TransmogCollection.IsSearchInProgress(searchType) → inProgress`
#### `C_TransmogCollection.IsSearchDBLoading() → isLoading`
#### `C_TransmogCollection.SearchProgress(searchType) → progress`
#### `C_TransmogCollection.SearchSize(searchType) → size`
#### `C_TransmogCollection.SetSearchAndFilterCategory(category)`

```lua
-- Search system for the wardrobe. searchType is TransmogSearchType enum.
-- These are purely client-side UI operations.
```

#### `C_TransmogCollection.GetCollectedShown() → shown`
#### `C_TransmogCollection.SetCollectedShown(shown)`
#### `C_TransmogCollection.GetUncollectedShown() → shown`
#### `C_TransmogCollection.SetUncollectedShown(shown)`
#### `C_TransmogCollection.GetAllFactionsShown() → shown`
#### `C_TransmogCollection.SetAllFactionsShown(shown)`
#### `C_TransmogCollection.GetAllRacesShown() → shown`
#### `C_TransmogCollection.SetAllRacesShown(shown)`
#### `C_TransmogCollection.IsSourceTypeFilterChecked(index) → checked`
#### `C_TransmogCollection.SetSourceTypeFilter(index, checked)`
#### `C_TransmogCollection.AreAllSourceTypeFiltersChecked() → checked`
#### `C_TransmogCollection.SetAllSourceTypeFilters(checked)`
#### `C_TransmogCollection.AreAllCollectionTypeFiltersChecked() → checked`
#### `C_TransmogCollection.SetAllCollectionTypeFilters(checked)`
#### `C_TransmogCollection.GetClassFilter() → classID`
#### `C_TransmogCollection.SetClassFilter(classID)`
#### `C_TransmogCollection.IsUsingDefaultFilters() → isUsingDefaultFilters`
#### `C_TransmogCollection.SetDefaultFilters()`

```lua
-- Filter management for the wardrobe UI.
-- All purely client-side, no server interaction.
```

### 3.7 Misc Functions

#### `C_TransmogCollection.GetItemInfo(itemInfo) → itemAppearanceID, itemModifiedAppearanceID`

```lua
-- Resolves an item (link/string) to its appearance IDs.
```

#### `C_TransmogCollection.IsCategoryValidForItem(category, itemInfo) → isValid`

```lua
-- Checks if a collection category is valid for a given item.
```

#### `C_TransmogCollection.GetValidAppearanceSourcesForClass(appearanceID, classID, categoryType?, transmogLocation?) → sources`

```lua
-- Returns sources valid for a specific class.
```

#### `C_TransmogCollection.GetInspectItemTransmogInfoList() → list`

```lua
-- Returns the ItemTransmogInfo list for the currently inspected player.
-- MayReturnNothing if no inspection is active.
```

#### `C_TransmogCollection.UpdateUsableAppearances()`

```lua
-- Triggers a refresh of which appearances are usable.
-- Called when equipment changes.
```

---

## 4. C_TransmogOutfitInfo API *(CRITICAL)*

**Namespace**: `C_TransmogOutfitInfo` | **Source**: `TransmogOutfitInfoDocumentation.lua`
**System Name**: `TransmogOutfitInfo` | **59 Functions, 8 Events, 11 Structures**

This is the **central API for the 12.x outfit system**. It manages outfit creation, viewing, pending changes, committing, situations, and slot state. Nearly every transmog UI interaction flows through this API.

> **NOTE (Server)**: This is the API that generates the packets our server must handle. Every function marked with `SecretArguments: AllowedWhenUntainted` sends a message to the server or queries server state. Understanding this API is essential for debugging outfit application failures.

### 4.1 Outfit Lifecycle Functions

#### `C_TransmogOutfitInfo.AddNewOutfit(name, icon)`

```lua
-- Arguments:
--   name : cstring — outfit name
--   icon : fileID — outfit icon texture
-- HasRestrictions: true
-- SecretArguments: AllowedWhenUntainted
```

Creates a new outfit from the current pending transmog state. This sends `CMSG_TRANSMOG_OUTFIT_ADD` (or equivalent) to the server. The server responds with `TRANSMOG_OUTFITS_CHANGED` event containing the `newOutfitID`.

> **NOTE (Server)**: The server must allocate a new outfit ID and store all currently pending slot appearances. The pending state at time of call becomes the outfit definition.

#### `C_TransmogOutfitInfo.CommitOutfitInfo(outfitID, name, icon)`

```lua
-- Arguments:
--   outfitID : number — existing outfit to update
--   name : cstring — new or same name
--   icon : fileID — new or same icon
-- SecretArguments: AllowedWhenUntainted
```

Saves changes to an existing outfit (rename, icon change, or pending appearance changes). This is the "Save" action in the outfit popup.

#### `C_TransmogOutfitInfo.CommitAndApplyAllPending(useAvailableDiscount)`

```lua
-- Arguments:
--   useAvailableDiscount : bool — whether to use the "usable discount" system
-- SecretArguments: AllowedWhenUntainted
```

**THE APPLY BUTTON.** Commits all pending transmog changes and applies them to the character. This is the final step that sends the transmog request to the server.

```lua
-- Called from TransmogOutfitCollectionMixin:
function TransmogOutfitCollectionMixin:CommitAndApplyAllPending()
    local useDiscount = C_TransmogOutfitInfo.IsUsableDiscountAvailable()
    C_TransmogOutfitInfo.CommitAndApplyAllPending(useDiscount)
end
```

> **NOTE (Server)**: This generates `CMSG_TRANSMOG_SET_ITEMS` (or the 12.x equivalent). The server must read all pending slot data, validate each appearance, deduct gold cost, apply the transmogs, and respond with per-slot `TRANSMOGRIFY_SUCCESS` events. On our server, this is handled in `TransmogrificationUtils.cpp`.

#### `C_TransmogOutfitInfo.GetOutfitsInfo() → outfitsInfo`

```lua
-- Returns: table<TransmogOutfitEntryInfo> — or MayReturnNothing
```

Returns info for ALL outfits. See `TransmogOutfitEntryInfo` in Section 10.

#### `C_TransmogOutfitInfo.GetOutfitInfo(outfitID) → outfitsInfo`

```lua
-- Returns: TransmogOutfitEntryInfo — or MayReturnNothing
-- Returns info for a single outfit.
```

#### `C_TransmogOutfitInfo.GetActiveOutfitID() → outfitID`

```lua
-- Returns the ID of the currently active (applied) outfit.
-- Returns 0 if no outfit is active.
```

#### `C_TransmogOutfitInfo.GetCurrentlyViewedOutfitID() → outfitID`

```lua
-- Returns the ID of the outfit currently being VIEWED in the UI.
-- This may differ from the active outfit if the player is previewing.
```

#### `C_TransmogOutfitInfo.GetMaxNumberOfUsableOutfits() → maxOutfitCount`

```lua
-- Maximum outfits a player can have active.
```

#### `C_TransmogOutfitInfo.GetMaxNumberOfTotalOutfitsForSource(source) → maxOutfitCount`

```lua
-- Maximum outfits from a specific source (TransmogOutfitEntrySource enum).
```

#### `C_TransmogOutfitInfo.GetNumberOfOutfitsUnlockedForSource(source) → unlockedOutfitCount`

```lua
-- How many outfit slots have been unlocked for a source.
```

#### `C_TransmogOutfitInfo.GetNextOutfitCost() → outfitCost`

```lua
-- Gold cost to unlock the next outfit slot.
-- Returns BigUInteger.
```

### 4.2 Viewing & Displaying Outfits

#### `C_TransmogOutfitInfo.ChangeViewedOutfit(outfitID)`

```lua
-- Arguments:
--   outfitID : number
-- SecretArguments: AllowedWhenUntainted
```

Changes which outfit is being **previewed** in the transmog UI. This loads the outfit's appearances into the pending state for all slots. Fires `VIEWED_TRANSMOG_OUTFIT_CHANGED`.

```lua
-- Used when clicking an outfit card in the list:
function TransmogOutfitEntryMixin:OnSelected()
    C_TransmogOutfitInfo.ChangeViewedOutfit(self.outfitID)
end
```

> **NOTE (Server)**: This is a purely client→server query. The server must respond with the outfit's slot data so the client can populate all pending slots. If the server doesn't return data for a slot, that slot shows as "Unassigned".

#### `C_TransmogOutfitInfo.ChangeDisplayedOutfit(outfitID, trigger, toggleLock, allowRemoveOutfit)`

```lua
-- Arguments:
--   outfitID : number
--   trigger : TransmogSituationTrigger — what caused the change
--   toggleLock : bool — whether to toggle the outfit's lock state
--   allowRemoveOutfit : bool — whether removing the outfit is allowed
-- SecretArguments: AllowedWhenUntainted
```

Changes the **actively displayed** outfit (the one the character is wearing). This is different from viewing — it actually changes the character's appearance.

```lua
-- Used when clicking an outfit's icon (quick-apply):
function TransmogOutfitEntryMixin:OnIconClick()
    C_TransmogOutfitInfo.ChangeDisplayedOutfit(self.outfitID,
        Enum.TransmogSituationTrigger.Manual, false, true)
end
```

#### `C_TransmogOutfitInfo.ClearDisplayedOutfit(trigger, toggleLock)`

```lua
-- Clears the displayed outfit, reverting to equipped gear appearance.
```

#### `C_TransmogOutfitInfo.IsEquippedGearOutfitDisplayed() → isDisplayed`

```lua
-- Returns true if the character is showing equipped gear (no outfit active).
```

#### `C_TransmogOutfitInfo.IsEquippedGearOutfitLocked() → isLocked`

```lua
-- Returns true if the equipped gear outfit is "locked" (won't auto-change).
```

#### `C_TransmogOutfitInfo.IsLockedOutfit(outfitID) → isLocked`

```lua
-- Returns true if a specific outfit is locked.
```

#### `C_TransmogOutfitInfo.PickupOutfit(outfitID)`

```lua
-- Puts an outfit on the cursor for drag-and-drop (action bar placement).
```

### 4.3 Pending Transmog Management

#### `C_TransmogOutfitInfo.SetPendingTransmog(slot, type, option, transmogID, displayType)`

```lua
-- Arguments:
--   slot : TransmogOutfitSlot (0-12)
--   type : TransmogType (Appearance or Illusion)
--   option : TransmogOutfitSlotOption (weapon option enum)
--   transmogID : number — the appearance/illusion ID to apply
--   displayType : TransmogOutfitDisplayType — how to display this slot
-- SecretArguments: AllowedWhenUntainted
```

**Sets a pending transmog for a single slot.** This is called when the player selects an appearance in the wardrobe.

```lua
-- Called from TransmogWardrobeItemsMixin when player clicks an appearance:
function TransmogWardrobeItemsMixin:SelectVisual(visualInfo)
    C_TransmogOutfitInfo.SetPendingTransmog(
        self.activeSlot,
        Enum.TransmogType.Appearance,
        self.activeOption,
        visualInfo.visualID,
        Enum.TransmogOutfitDisplayType.Assigned
    )
end
```

> **NOTE (Server)**: Each `SetPendingTransmog` call updates the server's pending state for that slot. The `displayType` is critical:
> - `Assigned` (1) = a specific appearance is chosen
> - `Hidden` (2) = the slot should be hidden
> - `Equipped` (3) = use the equipped item's appearance
> - `Unassigned` (0) = no choice made for this slot
>
> When `CommitAndApplyAllPending` is called, the server reads ALL pending slots and applies them.

#### `C_TransmogOutfitInfo.RevertPendingTransmog(slot, type, option)`

```lua
-- Arguments:
--   slot : TransmogOutfitSlot (0-12)
--   type : TransmogType
--   option : TransmogOutfitSlotOption
-- SecretArguments: AllowedWhenUntainted
```

Reverts a single slot's pending transmog back to the outfit's saved state. Called when right-clicking a slot.

```lua
-- From TransmogSlotMixin:
function TransmogSlotMixin:OnClick(button)
    if button == "RightButton" then
        C_TransmogOutfitInfo.RevertPendingTransmog(
            self.slot, self.type, self.option)
    end
end
```

#### `C_TransmogOutfitInfo.ClearAllPendingTransmogs()`

```lua
-- Clears all pending transmog changes across all slots.
-- No arguments, no return value.
```

#### `C_TransmogOutfitInfo.HasPendingOutfitTransmogs() → hasPending`

```lua
-- Returns true if any slot has a pending transmog change.
-- Used to enable/disable the Apply button.
```

#### `C_TransmogOutfitInfo.GetPendingTransmogCost() → cost`

```lua
-- Returns: BigUInteger — gold cost of all pending changes, or MayReturnNothing.
-- Used to display cost in the Apply button area.
```

### 4.4 Slot State Query

#### `C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(slot, type, option) → slotInfo`

```lua
-- Arguments:
--   slot : TransmogOutfitSlot (0-12)
--   type : TransmogType (Appearance or Illusion)
--   option : TransmogOutfitSlotOption
-- Returns:
--   slotInfo : ViewedTransmogOutfitSlotInfo — or MayReturnNothing
-- SecretArguments: AllowedWhenUntainted
```

**THE primary slot state query.** Returns the full state of a slot in the currently viewed outfit.

```lua
-- ViewedTransmogOutfitSlotInfo:
-- {
--   transmogID         : number,                    -- the appearance/illusion ID
--   displayType        : TransmogOutfitDisplayType,  -- Unassigned/Assigned/Hidden/Equipped
--   isTransmogrified   : bool,                      -- currently has an active transmog
--   hasPending         : bool,                      -- has a pending change
--   isPendingCollected : bool,                      -- is the pending appearance collected
--   canTransmogrify    : bool,                      -- can this slot be transmogged
--   warning            : TransmogOutfitSlotWarning,  -- warning enum
--   warningText        : cstring,                   -- warning description
--   error              : TransmogOutfitSlotError,    -- error enum
--   errorText          : cstring,                   -- error description
--   texture            : fileID (nilable),           -- icon texture
-- }
```

> **NOTE (Server)**: This is called constantly by the UI to refresh slot displays. The server must correctly populate all these fields. Key debugging points:
> - `transmogID = 0` with `displayType = Unassigned` means the slot has no outfit entry
> - `transmogID = 0` with `displayType = Hidden` means the slot is intentionally hidden
> - `displayType = Equipped` means "use whatever the equipped item looks like"
> - `canTransmogrify = false` means the slot can't be changed (no item equipped, etc.)

#### `C_TransmogOutfitInfo.GetAllSlotLocationInfo() → appearanceSlotInfo, illusionSlotInfo`

```lua
-- Returns two tables of TransmogOutfitSlotInfo — one for appearances, one for illusions.
-- Used by InitializeSlotLocationInfo() to populate TRANSMOG_SLOTS.
-- MayReturnNothing.
```

#### `C_TransmogOutfitInfo.GetSlotGroupInfo() → slotGroups`

```lua
-- Returns: table<TransmogOutfitSlotGroup> — or MayReturnNothing
-- Groups slots by position (Left, Right, Bottom) for UI layout.
```

#### `C_TransmogOutfitInfo.IsSlotWeaponSlot(slot) → isWeaponSlot`

```lua
-- Returns true for Mainhand (11) and Offhand (12).
```

### 4.5 Weapon Options

#### `C_TransmogOutfitInfo.GetWeaponOptionsForSlot(slot) → weaponOptions, artifactOptions`

```lua
-- Returns available weapon categories for a weapon slot.
-- weaponOptions: table<TransmogOutfitWeaponOptionInfo>
-- artifactOptions: table<TransmogOutfitWeaponOptionInfo> (nilable)
```

#### `C_TransmogOutfitInfo.SetViewedWeaponOptionForSlot(slot, weaponOption)`

```lua
-- Changes which weapon category is being viewed for a slot.
-- Fires VIEWED_TRANSMOG_OUTFIT_SLOT_WEAPON_OPTION_CHANGED.
```

#### `C_TransmogOutfitInfo.GetEquippedSlotOptionFromTransmogSlot(slot) → weaponOption`

```lua
-- Returns the weapon option that matches the currently equipped weapon.
```

#### `C_TransmogOutfitInfo.GetCollectionInfoForSlotAndOption(slot, weaponOption, collectionType) → collectionInfo`

```lua
-- Returns: TransmogOutfitWeaponCollectionInfo — or MayReturnNothing
-- { name, isWeapon, canHaveIllusions }
```

#### `C_TransmogOutfitInfo.GetIllusionDefaultIMAIDForCollectionType(collectionType) → imaID`

```lua
-- Returns the default ItemModifiedAppearance ID for an illusion collection type.
```

#### `C_TransmogOutfitInfo.GetItemModifiedAppearanceEffectiveCategory(imaID) → categoryID`

```lua
-- Returns the effective TransmogCollectionType for an ItemModifiedAppearance.
```

### 4.6 Secondary Slots

#### `C_TransmogOutfitInfo.SlotHasSecondary(slot) → hasSecondary`

```lua
-- Returns true if the slot currently has a secondary appearance active.
```

#### `C_TransmogOutfitInfo.GetSecondarySlotState(slot) → state`

```lua
-- Returns whether the secondary slot is enabled (true) or disabled (false).
```

#### `C_TransmogOutfitInfo.SetSecondarySlotState(slot, state)`

```lua
-- Enables/disables the secondary slot (e.g., split shoulders on/off).
-- Fires VIEWED_TRANSMOG_OUTFIT_SECONDARY_SLOTS_CHANGED.
-- MayReturnNothing.
```

#### `C_TransmogOutfitInfo.GetLinkedSlotInfo(slot) → linkedSlotInfo`

```lua
-- Returns: TransmogOutfitLinkedSlotInfo — or MayReturnNothing
-- { primarySlotInfo, secondarySlotInfo } — both TransmogOutfitSlotInfo
```

### 4.7 Set / Custom Set Application

#### `C_TransmogOutfitInfo.SetOutfitToSet(transmogSetID)`

```lua
-- Loads a transmog SET (raid tier, etc.) into the pending state.
-- All matching slots get populated from the set definition.
```

#### `C_TransmogOutfitInfo.SetOutfitToCustomSet(transmogCustomSetID)`

```lua
-- Loads a CUSTOM SET (client-local preset) into the pending state.
```

#### `C_TransmogOutfitInfo.SetOutfitToOutfit(outfitID)`

```lua
-- Copies another outfit's appearances into the pending state.
-- Used in Trial of Style to copy outfits between characters.
```

#### `C_TransmogOutfitInfo.GetSetSourcesForSlot(transmogSetID, slot) → sources`

```lua
-- Returns AppearanceSourceInfo for a set's items in a specific slot.
```

#### `C_TransmogOutfitInfo.GetSourceIDsForSlot(transmogSetID, slot) → sources`

```lua
-- Returns just the source IDs for a set's items in a slot.
```

### 4.8 Unassigned Slot Display

#### `C_TransmogOutfitInfo.GetUnassignedAtlasForSlot(slot) → atlas`

```lua
-- Returns the texture atlas for displaying an "unassigned" slot icon.
```

#### `C_TransmogOutfitInfo.GetUnassignedDisplayAtlasForSlot(slot) → atlas`

```lua
-- Returns the display atlas for an unassigned slot (used in the wardrobe).
```

### 4.9 Situations System

Situations allow outfits to trigger automatically based on spec, loadout, or equipment set.

#### `C_TransmogOutfitInfo.GetUISituationCategoriesAndOptions() → categoryData`

```lua
-- Returns: table<TransmogSituationCategory> — or MayReturnNothing
-- Each category contains:
-- {
--   triggerID : number,
--   name : string,
--   description : string,
--   isRadioButton : bool,
--   groupData : table<TransmogSituationGroup>,
-- }
```

#### `C_TransmogOutfitInfo.GetOutfitSituationsEnabled() → enabled`
#### `C_TransmogOutfitInfo.SetOutfitSituationsEnabled(enabled)`

```lua
-- Global enable/disable for the situations system.
```

#### `C_TransmogOutfitInfo.GetOutfitSituation(option) → value`
#### `C_TransmogOutfitInfo.UpdatePendingSituation(option, value)`
#### `C_TransmogOutfitInfo.CommitPendingSituations()`
#### `C_TransmogOutfitInfo.ClearAllPendingSituations()`
#### `C_TransmogOutfitInfo.HasPendingOutfitSituations() → hasPending`
#### `C_TransmogOutfitInfo.ResetOutfitSituations()`

```lua
-- Situation management functions.
-- TransmogSituationOption = { situationID, specID, loadoutID, equipmentSetID }
```

### 4.10 Misc Functions

#### `C_TransmogOutfitInfo.InTransmogEvent() → inTransmogEvent`

```lua
-- Returns true if a transmog event (Trial of Style) is active.
```

#### `C_TransmogOutfitInfo.TransmogEventActive() → transmogEventActive`

```lua
-- Similar to above — whether any transmog event is active.
```

#### `C_TransmogOutfitInfo.IsUsableDiscountAvailable() → isAvailable`

```lua
-- Returns true if a "usable discount" is available for the current transmog.
```

#### `C_TransmogOutfitInfo.IsValidTransmogOutfitName(name) → isApproved`

```lua
-- Validates an outfit name (profanity, length, etc.).
```

#### `C_TransmogOutfitInfo.GetTransmogOutfitSlotForInventoryType(inventoryType) → slot`

```lua
-- Maps item inventory type to TransmogOutfitSlot.
```

#### `C_TransmogOutfitInfo.GetTransmogOutfitSlotFromInventorySlot(inventorySlot) → slot`

```lua
-- Maps INVSLOT_* to TransmogOutfitSlot.
```

### 4.11 Events

#### `TRANSMOG_OUTFITS_CHANGED`
```lua
-- Payload:
--   newOutfitID : number (nilable)
-- SynchronousEvent: true
```
Fired when the outfit list changes (outfit created, deleted, or modified). `newOutfitID` is set when a new outfit was just created.

> **NOTE (Server)**: The server fires this after processing `AddNewOutfit` or `CommitOutfitInfo`. The `newOutfitID` in the payload tells the client which outfit to select.

#### `TRANSMOG_DISPLAYED_OUTFIT_CHANGED`
```lua
-- Payload: none
-- SynchronousEvent: true
```
Fired when the actively displayed outfit changes (different outfit applied to character).

#### `VIEWED_TRANSMOG_OUTFIT_CHANGED`
```lua
-- Payload: none
-- SynchronousEvent: true
```
Fired when the outfit being previewed in the UI changes (via `ChangeViewedOutfit`).

> **NOTE (Server)**: This fires after the server responds to `ChangeViewedOutfit`. The client then calls `GetViewedOutfitSlotInfo` for each slot to populate the UI.

#### `VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH`
```lua
-- Payload: none
-- UniqueEvent: true
```
Fired when slot data needs refreshing (pending change, revert, etc.). The UI re-queries all slot states.

#### `VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS`
```lua
-- Payload:
--   slot : TransmogOutfitSlot
--   type : TransmogType
--   option : TransmogOutfitSlotOption
-- SynchronousEvent: true
```
Fired when a single slot's transmog is successfully saved.

#### `VIEWED_TRANSMOG_OUTFIT_SLOT_WEAPON_OPTION_CHANGED`
```lua
-- Payload:
--   slot : TransmogOutfitSlot
--   weaponOption : TransmogOutfitSlotOption
-- SynchronousEvent: true
```
Fired when the viewed weapon option for a slot changes.

#### `VIEWED_TRANSMOG_OUTFIT_SECONDARY_SLOTS_CHANGED`
```lua
-- Payload: none
-- SynchronousEvent: true
```
Fired when secondary slot states change (split shoulder toggle).

#### `VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED`
```lua
-- Payload: none
-- SynchronousEvent: true
```
Fired when situation settings change.

---

## 5. C_TransmogSets API

**Namespace**: `C_TransmogSets` | **Source**: `TransmogSetsDocumentation.lua`
**System Name**: `TransmogrifySets` | **40 Functions, 0 Events, 2 Structures**

Manages **transmog sets** — curated collections of matching armor/weapon appearances (raid tiers, PvP sets, etc.). Sets are defined in DB2 data (`TransmogSet`, `TransmogSetItem`). This API has NO events — set changes are signaled through `C_Transmog` events.

### 5.1 Set Query Functions

#### `C_TransmogSets.GetAllSets() → sets`

```lua
-- Returns: table<TransmogSetInfo> — ALL transmog sets in the game.
```

#### `C_TransmogSets.GetAvailableSets() → sets`

```lua
-- Returns sets available to the current character (class-filtered).
```

#### `C_TransmogSets.GetUsableSets() → sets`

```lua
-- Returns sets the character can actually use.
```

#### `C_TransmogSets.HasUsableSets() → hasUsableSets`

```lua
-- Quick check if any usable sets exist.
```

#### `C_TransmogSets.GetBaseSets() → sets`

```lua
-- Returns base (non-variant) sets.
```

#### `C_TransmogSets.GetSetInfo(transmogSetID) → set`

```lua
-- Returns: TransmogSetInfo — or MayReturnNothing
-- See TransmogSetInfo structure in Section 10.
```

#### `C_TransmogSets.GetBaseSetID(transmogSetID) → baseTransmogSetID`

```lua
-- Returns the base set ID for a variant set.
-- MayReturnNothing if already a base set or invalid.
```

#### `C_TransmogSets.GetVariantSets(transmogSetID) → sets`

```lua
-- Returns all variant sets for a base set (e.g., Normal/Heroic/Mythic tiers).
```

### 5.2 Set Source Functions

#### `C_TransmogSets.GetAllSourceIDs(transmogSetID) → sources`

```lua
-- Returns all ItemModifiedAppearance IDs in a set.
```

#### `C_TransmogSets.GetSourceIDsForSlot(transmogSetID, slot) → sources`

```lua
-- Returns source IDs for a specific slot in a set.
-- slot is luaIndex (1-based INVSLOT_*).
```

#### `C_TransmogSets.GetSourcesForSlot(transmogSetID, slot) → sources`

```lua
-- Returns full AppearanceSourceInfo for a slot in a set.
```

#### `C_TransmogSets.GetSetPrimaryAppearances(transmogSetID) → appearances`

```lua
-- Returns: table<TransmogSetPrimaryAppearanceInfo>
-- { appearanceID, collected }
```

#### `C_TransmogSets.GetSetsContainingSourceID(sourceID) → setIDs`

```lua
-- Reverse lookup — which sets contain a given source.
```

### 5.3 Set State Functions

#### `C_TransmogSets.IsBaseSetCollected(transmogSetID) → isCollected`

```lua
-- Whether the player has collected all pieces of a base set.
```

#### `C_TransmogSets.IsSetVisible(transmogSetID) → isVisible`

```lua
-- Whether a set is visible (not hidden until collected).
```

#### `C_TransmogSets.GetValidClassForSet(transmogSetID) → classID`

```lua
-- Returns the class ID this set is valid for (nil if multi-class).
```

#### `C_TransmogSets.GetValidBaseSetsCountsForCharacter() → numCollected, numTotal`

```lua
-- Progress counts for the character's valid base sets.
```

### 5.4 Set Collection Progress

#### `C_TransmogSets.GetFullBaseSetsCounts() → numCollected, numTotal`
#### `C_TransmogSets.GetFilteredBaseSetsCounts() → numCollected, numTotal`

```lua
-- Progress bar data for the sets tab.
```

### 5.5 New Source Tracking

#### `C_TransmogSets.GetLatestSource() → sourceID`
#### `C_TransmogSets.ClearLatestSource()`
#### `C_TransmogSets.IsNewSource(sourceID) → isNew`
#### `C_TransmogSets.ClearNewSource(sourceID)`
#### `C_TransmogSets.SetHasNewSources(transmogSetID) → hasNewSources`
#### `C_TransmogSets.SetHasNewSourcesForSlot(transmogSetID, slot) → hasNewSources`
#### `C_TransmogSets.GetSetNewSources(transmogSetID) → sourceIDs`
#### `C_TransmogSets.ClearSetNewSourcesForSlot(transmogSetID, slot)`

```lua
-- "New" indicator tracking for recently learned set pieces.
```

### 5.6 Favorites

#### `C_TransmogSets.GetIsFavorite(transmogSetID) → isFavorite, isGroupFavorite`
#### `C_TransmogSets.SetIsFavorite(transmogSetID, isFavorite)`

```lua
-- Set favorite management.
```

### 5.7 Filters

#### `C_TransmogSets.GetTransmogSetsClassFilter() → classID`
#### `C_TransmogSets.SetTransmogSetsClassFilter(classID)`
#### `C_TransmogSets.GetBaseSetsFilter(index) → isChecked`
#### `C_TransmogSets.SetBaseSetsFilter(index, isChecked)`
#### `C_TransmogSets.SetDefaultBaseSetsFilters()`
#### `C_TransmogSets.IsUsingDefaultBaseSetsFilters() → isUsingDefaultBaseSetsFilters`
#### `C_TransmogSets.GetSetsFilter(index) → isChecked`
#### `C_TransmogSets.SetSetsFilter(index, isChecked)`
#### `C_TransmogSets.SetDefaultSetsFilters()`
#### `C_TransmogSets.IsUsingDefaultSetsFilters() → isUsingDefaultSetsFilters`

```lua
-- Filter management for the sets tab.
```

### 5.8 Camera

#### `C_TransmogSets.GetCameraIDs() → detailsCameraID, vendorCameraID`

```lua
-- Returns camera IDs for set preview.
-- Both nilable.
```

---

## 6. Outfit System Flow

This section traces the complete flow of outfit operations from UI interaction to server communication.

### 6.1 Opening the Transmog UI

```
Player interacts with Transmog NPC
  → Server sends SMSG_OPEN_TRANSMOGRIFIER
    → Client fires TRANSMOGRIFY_OPEN
      → TransmogFrame:OnEvent("TRANSMOGRIFY_OPEN")
        → TransmogFrame:Show()
        → InitializeSlotLocationInfo()  -- populates TRANSMOG_SLOTS
        → TransmogCharacterMixin:SetupSlots()  -- creates slot frames
        → TransmogOutfitCollectionMixin:RefreshOutfits()
        → C_TransmogOutfitInfo.GetOutfitsInfo()  -- fetch outfit list
        → C_TransmogOutfitInfo.GetActiveOutfitID()  -- which is active
        → For each slot: C_TransmogOutfitInfo.GetViewedOutfitSlotInfo()
```

### 6.2 Viewing an Outfit

```
Player clicks an outfit card in the list
  → TransmogOutfitEntryMixin:OnSelected()
    → C_TransmogOutfitInfo.ChangeViewedOutfit(outfitID)
      → Server loads outfit data and populates viewed state
        → Client fires VIEWED_TRANSMOG_OUTFIT_CHANGED
          → TransmogFrame:OnEvent("VIEWED_TRANSMOG_OUTFIT_CHANGED")
            → RefreshOutfits()
            → For each slot:
              → C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(slot, type, option)
              → Update slot icon, border, overlay based on displayType
              → Update paperdoll model via actor:SetItemTransmogInfo()
```

### 6.3 Selecting an Appearance (Single Slot)

```
Player clicks an appearance in the wardrobe grid
  → TransmogWardrobeItemsMixin:SelectVisual(visualInfo)
    → C_TransmogOutfitInfo.SetPendingTransmog(
        slot, Enum.TransmogType.Appearance, option,
        visualInfo.visualID, Enum.TransmogOutfitDisplayType.Assigned)
      → Server updates pending state for that slot
        → Client fires VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH
          → Slot UI refreshes: icon shows pending appearance, border turns yellow
          → Paperdoll model updates to show pending look
          → Apply button enables (HasPendingOutfitTransmogs = true)
          → Cost display updates (GetPendingTransmogCost)
```

### 6.4 Reverting a Slot

```
Player right-clicks a slot
  → TransmogSlotMixin:OnClick("RightButton")
    → C_TransmogOutfitInfo.RevertPendingTransmog(slot, type, option)
      → Server reverts that slot's pending state
        → Client fires VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH
          → Slot reverts to outfit's saved appearance
```

### 6.5 Applying All Pending Changes (THE APPLY BUTTON)

```
Player clicks Apply
  → TransmogOutfitCollectionMixin:CommitAndApplyAllPending()
    → useDiscount = C_TransmogOutfitInfo.IsUsableDiscountAvailable()
    → C_TransmogOutfitInfo.CommitAndApplyAllPending(useDiscount)
      → Client sends CMSG (transmog apply packet) to server
        → Server validates each slot:
          - Is the appearance collected?
          - Can this slot be transmogged?
          - Does the player have enough gold?
        → Server applies transmogs to equipped items
        → Server deducts gold
        → Server sends per-slot TRANSMOGRIFY_SUCCESS events
        → Server sends TRANSMOG_OUTFITS_CHANGED
          → Client fires TRANSMOGRIFY_SUCCESS per slot
            → Slot borders flash green
          → Client fires TRANSMOG_OUTFITS_CHANGED
            → Outfit list refreshes
            → Active outfit ID updates
```

> **NOTE (Server)**: The commit-and-apply is atomic — all slots are processed together. If any slot fails validation, the behavior depends on server implementation. Retail WoW applies valid slots and skips invalid ones. Our server should do the same.

### 6.6 Creating a New Outfit

```
Player clicks "New Outfit" button
  → TransmogOutfitPopupMixin shows name/icon dialog
    → Player enters name and clicks Accept
      → C_TransmogOutfitInfo.AddNewOutfit(name, icon)
        → Server creates outfit from current pending state
        → Server responds with TRANSMOG_OUTFITS_CHANGED { newOutfitID }
          → Client selects the new outfit
          → TransmogOutfitCollectionMixin:RefreshOutfits()
```

### 6.7 Saving/Updating an Outfit

```
Player clicks "Save" on an existing outfit
  → TransmogOutfitPopupMixin:CommitOutfitInfo()
    → C_TransmogOutfitInfo.CommitOutfitInfo(outfitID, name, icon)
      → Server updates the outfit definition with current pending state
      → Server fires TRANSMOG_OUTFITS_CHANGED
```

### 6.8 Quick-Applying an Outfit (Icon Click)

```
Player clicks an outfit's icon (not the card)
  → TransmogOutfitEntryMixin:OnIconClick()
    → C_TransmogOutfitInfo.ChangeDisplayedOutfit(outfitID,
        Enum.TransmogSituationTrigger.Manual, false, true)
      → Server changes the active outfit
      → Server applies all transmogs from the outfit
      → Client fires TRANSMOG_DISPLAYED_OUTFIT_CHANGED
```

### 6.9 Applying a Transmog Set

```
Player selects a transmog set in the Sets tab
  → TransmogWardrobeSetsMixin:SelectSet(setID)
    → C_TransmogOutfitInfo.SetOutfitToSet(setID)
      → Server loads set items into pending state
      → Each matching slot gets populated
      → Client fires VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH
        → All slots update to show set appearances
        → Player can then click Apply
```

### 6.10 Applying a Custom Set

```
Player selects a custom set in the Custom Sets tab
  → TransmogWardrobeCustomSetsMixin:SelectCustomSet(customSetID)
    → C_TransmogOutfitInfo.SetOutfitToCustomSet(customSetID)
      → Client loads custom set data (client-local)
      → Populates pending state for all slots
      → Client fires VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH
```

### 6.11 Display Type Buttons (Unassigned / Equipped)

In the wardrobe items view, two special buttons appear at the top:

```lua
-- "Unassigned" button — removes the slot from the outfit
function TransmogWardrobeItemsMixin:SetUnassigned()
    C_TransmogOutfitInfo.SetPendingTransmog(
        slot, type, option,
        Constants.Transmog.NoTransmogID,           -- transmogID = 0
        Enum.TransmogOutfitDisplayType.Unassigned)  -- displayType = 0
end

-- "Equipped" button — use whatever the equipped item looks like
function TransmogWardrobeItemsMixin:SetEquipped()
    C_TransmogOutfitInfo.SetPendingTransmog(
        slot, type, option,
        Constants.Transmog.NoTransmogID,           -- transmogID = 0
        Enum.TransmogOutfitDisplayType.Equipped)    -- displayType = 3
end
```

> **NOTE (Server)**: The `Unassigned` vs `Equipped` distinction is important:
> - **Unassigned** (0): The outfit has NO opinion about this slot. When the outfit is applied, this slot is skipped — whatever transmog was there before remains.
> - **Equipped** (3): The outfit explicitly says "show the real equipped item". When applied, any existing transmog on this slot is REMOVED.
> - **Assigned** (1): The outfit specifies a particular appearance for this slot.
> - **Hidden** (2): The outfit says "hide this slot" using the hidden appearance.

---

## 7. Paperdoll / Model Rendering

### 7.1 TransmogCharacterMixin

From `Blizzard_Transmog.lua`. The paperdoll character model in the transmog UI.

```lua
TransmogCharacterMixin = {}

function TransmogCharacterMixin:SetupSlots()
    -- Called when the transmog UI opens.
    -- Uses C_TransmogOutfitInfo.GetSlotGroupInfo() to get slot layout.
    -- Creates appearance slots and illusion slots grouped by position:
    --   Left side:  Head, Shoulder, Back, Chest, Tabard, Body (shirt)
    --   Right side: Wrist, Hand, Waist, Legs, Feet
    --   Bottom:     Mainhand, Offhand (with illusion slots)

    local slotGroups = C_TransmogOutfitInfo.GetSlotGroupInfo()
    for _, group in ipairs(slotGroups) do
        -- group.position: Left, Right, or Bottom
        -- group.appearanceSlotInfo: array of TransmogOutfitSlotInfo
        -- group.illusionSlotInfo: array of TransmogOutfitSlotInfo
        self:CreateSlotsForGroup(group)
    end
end

function TransmogCharacterMixin:RefreshSlots()
    -- Refreshes all slot visuals.
    -- For each slot:
    --   1. Calls GetViewedOutfitSlotInfo(slot, type, option)
    --   2. Updates the slot's icon/border/overlay
    --   3. Calls SetItemTransmogInfo on the actor model
end
```

### 7.2 Actor Model (Paperdoll)

The transmog UI uses a `ModelSceneActor` (3D character model) to preview appearances:

```lua
-- Getting the actor:
local actor = self:GetModelScene():GetActorByTag("yourcharacter")

-- Setting appearances on the actor:
actor:SetItemTransmogInfo(itemTransmogInfo)
-- Where itemTransmogInfo = CreateFromMixins(ItemTransmogInfoMixin)
-- containing: appearanceID, secondaryAppearanceID, illusionID

-- The actor is refreshed in TransmogCharacterMixin:RefreshSlots()
-- by iterating all slots and calling SetItemTransmogInfo for each
```

### 7.3 ItemTransmogInfo

The `ItemTransmogInfo` structure is used to set appearances on the 3D model:

```lua
-- ItemTransmogInfo is a C-side structure with fields:
-- {
--   appearanceID          : number,  -- primary appearance
--   secondaryAppearanceID : number,  -- secondary (split shoulder, paired weapon)
--   illusionID            : number,  -- weapon enchant illusion
-- }

-- Helper to create an empty list for all slots:
function TransmogUtil.GetEmptyItemTransmogInfoList()
    -- Returns a table of 17 ItemTransmogInfo entries:
    -- Indices: head, shoulder, shoulderSecondary, back, chest, body, tabard,
    --          wrist, hand, waist, legs, feet, mainhand, mainhandSecondary,
    --          mainhandIllusion, offhand, offhandIllusion
end
```

> **NOTE (Server)**: The 17-entry `ItemTransmogInfo` list is the canonical representation of a full outfit on the client side. The server must be able to construct and send equivalent data. The secondary entries (shoulderSecondary, mainhandSecondary) and illusion entries are separate from the main slot entries.

### 7.4 WARDROBE_MODEL_SETUP

From `Blizzard_TransmogShared.lua`. Camera and model setup for the wardrobe item preview:

```lua
WARDROBE_MODEL_SETUP = {
    -- Indexed by TransmogSlot enum (0-12), each entry defines:
    [Enum.TransmogSlot.Head] = {
        -- Camera, position, scale for previewing head items
    },
    [Enum.TransmogSlot.Shoulder] = { ... },
    -- etc.
}
```

### 7.5 Wardrobe Item Models

From `Blizzard_Wardrobe.lua` and `Blizzard_Wardrobe.xml`. The wardrobe shows a grid of 18 `DressUpModel` frames (`WardrobeItemsModelTemplate`) to preview appearances:

```lua
WardrobeItemModelMixin = {}

function WardrobeItemModelMixin:OnMouseDown(button)
    if button == "LeftButton" then
        -- Delegates to the parent WardrobeItemsCollectionMixin
        self:GetParent():SelectVisual(self.visualInfo)
    end
end

function WardrobeItemModelMixin:OnEnter()
    -- Show tooltip with item info, source, collected status
    self:GetParent():SetAppearanceTooltip(self)
end
```

The wardrobe uses `WardrobeItemsCollectionMixin` to manage the grid:

```lua
function WardrobeItemsCollectionMixin:UpdateItems()
    -- For each model frame in the grid (18 frames):
    --   1. Get the appearance from the current page
    --   2. Call model:SetItemTransmogInfo() to preview it
    --   3. Set border color based on collected/not/favorite status
    --   4. Show "new" indicator if IsNewAppearance()
end
```

### 7.6 Set Preview Model

From `Blizzard_Wardrobe_Sets.lua`. Sets have their own model preview with per-race pan/zoom limits:

```lua
SET_MODEL_PAN_AND_ZOOM_LIMITS = {
    ["HUMAN"] = { maxZoom = 2.9, panMaxLeft = -0.4, panMaxRight = 0.4, ... },
    ["ORC"]   = { maxZoom = 2.9, ... },
    -- All playable races listed
}

WardrobeSetsDetailsModelMixin = {}

function WardrobeSetsDetailsModelMixin:OnUpdate(elapsed)
    -- Handles rotation via mouse drag
    -- Handles zoom via mouse wheel
    -- Clamps pan within race-specific limits
end
```

### 7.7 Slot Visual States

Each slot in the transmog UI displays different visual states based on `displayType` and pending state:

```lua
function TransmogAppearanceSlotMixin:Update()
    local slotInfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(
        self.slot, self.type, self.option)

    if not slotInfo then return end

    -- Icon:
    if slotInfo.displayType == Enum.TransmogOutfitDisplayType.Assigned then
        self.Icon:SetTexture(slotInfo.texture)
    elseif slotInfo.displayType == Enum.TransmogOutfitDisplayType.Hidden then
        self.Icon:SetAtlas("transmog-icon-hidden")
    elseif slotInfo.displayType == Enum.TransmogOutfitDisplayType.Equipped then
        self.Icon:SetAtlas("transmog-icon-equipped")
    elseif slotInfo.displayType == Enum.TransmogOutfitDisplayType.Unassigned then
        local atlas = C_TransmogOutfitInfo.GetUnassignedAtlasForSlot(self.slot)
        self.Icon:SetAtlas(atlas)
    end

    -- Border color:
    if slotInfo.hasPending then
        self.Border:SetColor(YELLOW)  -- pending change
    elseif slotInfo.isTransmogrified then
        self.Border:SetColor(PINK)    -- has active transmog
    else
        self.Border:SetColor(DEFAULT)
    end

    -- Warning/Error overlays:
    if slotInfo.error ~= Enum.TransmogOutfitSlotError.None then
        self.ErrorOverlay:Show()
        self.ErrorOverlay.tooltip = slotInfo.errorText
    end
end
```

> **NOTE (Server)**: If the server returns incorrect `displayType` or `texture` data, the paperdoll slots will show wrong icons/borders. The most common bug is returning `Unassigned` when the outfit actually has data for a slot — the slot appears empty even though it should show an appearance.

---

## 8. Events

### 8.1 Complete Event Index

All events across all transmog APIs, organized by lifecycle phase.

#### UI Open/Close
| Event | Source | Payload | Notes |
|---|---|---|---|
| `TRANSMOGRIFY_OPEN` | C_Transmog | none | Server sends SMSG_OPEN_TRANSMOGRIFIER |
| `TRANSMOGRIFY_CLOSE` | C_Transmog | none | NPC interaction ends |

#### Outfit Management
| Event | Source | Payload | Notes |
|---|---|---|---|
| `TRANSMOG_OUTFITS_CHANGED` | C_TransmogOutfitInfo | `newOutfitID?` | Outfit created/modified/deleted |
| `TRANSMOG_DISPLAYED_OUTFIT_CHANGED` | C_TransmogOutfitInfo | none | Active outfit changed |
| `VIEWED_TRANSMOG_OUTFIT_CHANGED` | C_TransmogOutfitInfo | none | Preview outfit changed |

#### Slot State
| Event | Source | Payload | Notes |
|---|---|---|---|
| `VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH` | C_TransmogOutfitInfo | none | Slot data needs re-query (UniqueEvent) |
| `VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS` | C_TransmogOutfitInfo | `slot, type, option` | Single slot saved |
| `VIEWED_TRANSMOG_OUTFIT_SLOT_WEAPON_OPTION_CHANGED` | C_TransmogOutfitInfo | `slot, weaponOption` | Weapon category changed |
| `VIEWED_TRANSMOG_OUTFIT_SECONDARY_SLOTS_CHANGED` | C_TransmogOutfitInfo | none | Split shoulder toggle |
| `VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED` | C_TransmogOutfitInfo | none | Situation config changed |

#### Transmog Application
| Event | Source | Payload | Notes |
|---|---|---|---|
| `TRANSMOGRIFY_UPDATE` | C_Transmog | `transmogLocation?, action?` | Transmog state changed |
| `TRANSMOGRIFY_SUCCESS` | C_Transmog | `transmogLocation` | Per-slot success |
| `TRANSMOGRIFY_ITEM_UPDATE` | C_Transmog | none | Item transmog changed (UniqueEvent) |

#### Collection
| Event | Source | Payload | Notes |
|---|---|---|---|
| `TRANSMOG_COLLECTION_UPDATED` | C_Transmog | `collectionIndex?, modID?, itemAppearanceID?, reason?` | Collection changed |
| `TRANSMOG_COLLECTION_SOURCE_ADDED` | C_Transmog | `itemModifiedAppearanceID` | Source learned |
| `TRANSMOG_COLLECTION_SOURCE_REMOVED` | C_Transmog | `itemModifiedAppearanceID` | Source removed |
| `TRANSMOG_COLLECTION_ITEM_UPDATE` | C_Transmog | none | Item update (UniqueEvent) |
| `TRANSMOG_COLLECTION_ITEM_FAVORITE_UPDATE` | C_Transmog | `itemAppearanceID, isFavorite` | Favorite toggled |
| `TRANSMOG_COLLECTION_CAMERA_UPDATE` | C_Transmog | none | Camera changed |
| `TRANSMOG_COSMETIC_COLLECTION_SOURCE_ADDED` | C_Transmog | `itemModifiedAppearanceID` | Cosmetic source learned |
| `TRANSMOG_SOURCE_COLLECTABILITY_UPDATE` | C_Transmog | `itemModifiedAppearanceID, collectable` | Collectability changed |

#### Search
| Event | Source | Payload | Notes |
|---|---|---|---|
| `TRANSMOG_SEARCH_UPDATED` | C_Transmog | `searchType, collectionType?` | Search results ready |

#### Sets
| Event | Source | Payload | Notes |
|---|---|---|---|
| `TRANSMOG_SETS_UPDATE_FAVORITE` | C_Transmog | none | Set favorite changed |

### 8.2 Event Flow Sequences

#### Opening → Viewing → Applying

```
TRANSMOGRIFY_OPEN
  └→ (UI initializes, queries GetOutfitsInfo, GetActiveOutfitID)
     └→ VIEWED_TRANSMOG_OUTFIT_CHANGED  (initial outfit loaded)
        └→ (UI queries GetViewedOutfitSlotInfo for each slot)
           └→ User clicks appearance
              └→ VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH
                 └→ (slot refreshes with pending data)
                    └→ User clicks Apply
                       └→ TRANSMOGRIFY_SUCCESS (per slot)
                       └→ TRANSMOG_OUTFITS_CHANGED
                       └→ VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH
```

#### UniqueEvent Behavior

Events marked `UniqueEvent = true` are coalesced — if fired multiple times before the next frame, only one handler invocation occurs. This matters for:
- `VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH` — prevents redundant slot refreshes
- `TRANSMOGRIFY_ITEM_UPDATE` — prevents rapid re-queries
- `TRANSMOG_COLLECTION_ITEM_UPDATE` — prevents collection thrashing

### 8.3 TransmogFrame Event Registration

From `Blizzard_Transmog.lua`, the main frame registers for:

```lua
TransmogFrameMixin.Events = {
    "TRANSMOG_OUTFITS_CHANGED",
    "TRANSMOG_DISPLAYED_OUTFIT_CHANGED",
    "VIEWED_TRANSMOG_OUTFIT_CHANGED",
    "VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH",
    "VIEWED_TRANSMOG_OUTFIT_SECONDARY_SLOTS_CHANGED",
    "VIEWED_TRANSMOG_OUTFIT_SLOT_WEAPON_OPTION_CHANGED",
    "TRANSMOGRIFY_UPDATE",
    "TRANSMOGRIFY_SUCCESS",
}
```

---

## 9. Enums & Constants

### 9.1 TransmogSlot (Enum, 0-12)

```lua
Enum.TransmogSlot = {
    Head     = 0,
    Shoulder = 1,
    Back     = 2,
    Chest    = 3,
    Body     = 4,   -- Shirt
    Tabard   = 5,
    Wrist    = 6,
    Hand     = 7,
    Waist    = 8,
    Legs     = 9,
    Feet     = 10,
    Mainhand = 11,
    Offhand  = 12,
}
```

### 9.2 TransmogOutfitDisplayType (Enum)

```lua
Enum.TransmogOutfitDisplayType = {
    Unassigned = 0,  -- No appearance set for this slot in the outfit
    Assigned   = 1,  -- A specific appearance is assigned
    Hidden     = 2,  -- Slot is hidden (invisible)
    Equipped   = 3,  -- Use the equipped item's real appearance
}
```

> **NOTE (Server)**: This enum is CRITICAL for outfit handling. When building outfit data:
> - `Unassigned` (0) = slot has no entry in outfit → skip this slot during apply
> - `Assigned` (1) = slot has a specific transmogID → apply that transmog
> - `Hidden` (2) = slot should show hidden appearance → apply the hidden item transmog
> - `Equipped` (3) = slot should show real gear → REMOVE any existing transmog

### 9.3 TransmogPendingType (Enum, 0-3)

```lua
Enum.TransmogPendingType = {
    Apply     = 0,  -- Apply a new transmog
    Revert    = 1,  -- Revert to saved state
    ToggleOn  = 2,  -- Toggle something on
    ToggleOff = 3,  -- Toggle something off
}
```

### 9.4 TransmogType (Enum)

```lua
Enum.TransmogType = {
    Appearance = 0,  -- Visual appearance
    Illusion   = 1,  -- Weapon enchant illusion
}
```

### 9.5 TransmogModification (Enum)

```lua
Enum.TransmogModification = {
    Main      = 0,  -- Primary appearance
    Secondary = 1,  -- Secondary (split shoulder, paired weapon)
}
```

### 9.6 TransmogCameraVariation (Enum, 0-1)

```lua
Enum.TransmogCameraVariation = {
    None           = 0,
    RightShoulder  = 1,  -- Right shoulder camera angle
    CloakBackpack  = 1,  -- Back/cloak camera angle (shares value with RightShoulder)
}
```

### 9.7 TransmogOutfitSlotPosition (Enum)

```lua
Enum.TransmogOutfitSlotPosition = {
    Left   = 0,  -- Head through Body (shirt)
    Right  = 1,  -- Wrist through Feet
    Bottom = 2,  -- Mainhand, Offhand
}
```

### 9.8 Constants.Transmog

```lua
Constants.Transmog = {
    NoTransmogID = 0,                           -- No transmog applied
    MainHandTransmogIsIndividualWeapon = -1,     -- MH is an individual weapon
    MainHandTransmogIsPairedWeapon = 0,          -- MH is a paired weapon (artifact)
}
```

> **NOTE (Server)**: `NoTransmogID = 0` is used as the sentinel value throughout. Any slot with `transmogID = 0` has no transmog. The server must send `0` (not nil, not -1) for empty slots.

### 9.9 TransmogOutfitEntrySource (C-side enum)

```lua
-- C-side enum — numeric values not exposed in Lua source.
-- Used with GetMaxNumberOfTotalOutfitsForSource / GetNumberOfOutfitsUnlockedForSource.
-- Identifies the source of outfit slots (base game, Trading Post, etc.)
```

### 9.10 TransmogSituationTrigger (C-side enum)

```lua
-- C-side enum — numeric values not exposed in Lua source.
-- Used with ChangeDisplayedOutfit:
-- Manual = player manually clicked
-- Automatic = triggered by situation system (spec change, etc.)
```

### 9.11 TransmogOutfitSlotWarning / TransmogOutfitSlotError (C-side enums)

```lua
-- C-side enums — numeric values not exposed in Lua source.
-- Warning/error codes returned in ViewedTransmogOutfitSlotInfo.
-- .None = no warning/error
-- Other values indicate specific issues (uncollected, wrong class, etc.)
```

### 9.12 TransmogSearchType (C-side enum)

```lua
-- C-side enum — numeric values not exposed in Lua source.
-- Used with search functions in C_TransmogCollection.
-- Differentiates between searching items vs sets vs illusions.
```

### 9.13 TransmogCollectionType (C-side enum)

```lua
-- C-side enum — numeric values not exposed in Lua source.
-- Identifies collection categories: None, Plate, Mail, Leather, Cloth,
-- Daggers, OneHandedSwords, OneHandedMaces, etc.
-- Used for browsing the wardrobe by armor/weapon type.
```

### 9.14 TransmogSource (C-side enum)

```lua
-- C-side enum — numeric values not exposed in Lua source.
-- Identifies how a transmog was acquired:
-- Quest, Vendor, Dungeon, Raid, WorldDrop, etc.
-- Used for filtering in the wardrobe.
```

### 9.15 TransmogUseErrorType (C-side enum)

```lua
-- C-side enum — numeric values not exposed in Lua source.
-- Error types in AppearanceSourceInfo.useErrorType:
-- None, Class, Level, Faction, etc.
-- Indicates why a player can't use a specific source.
```

---

## 10. Key Data Structures

### 10.1 ViewedTransmogOutfitSlotInfo *(CRITICAL)*

The most important structure for server-side debugging. Returned by `C_TransmogOutfitInfo.GetViewedOutfitSlotInfo()`.

```lua
ViewedTransmogOutfitSlotInfo = {
    transmogID         = number,                    -- The appearance/illusion ID
                                                     -- 0 = no transmog (NoTransmogID)
    displayType        = TransmogOutfitDisplayType,  -- Unassigned(0)/Assigned(1)/Hidden(2)/Equipped(3)
    isTransmogrified   = bool,                      -- Currently has an active transmog on equipped item
    hasPending         = bool,                      -- Has a pending (unsaved) change
    isPendingCollected = bool,                      -- Is the pending appearance collected by player
    canTransmogrify    = bool,                      -- Can this slot accept a transmog
    warning            = TransmogOutfitSlotWarning,  -- Warning enum value
    warningText        = cstring,                   -- Warning display text
    error              = TransmogOutfitSlotError,    -- Error enum value
    errorText          = cstring,                   -- Error display text
    texture            = fileID,                    -- Icon texture (nilable)
}
```

> **NOTE (Server)**: The server populates this for every slot query. Common debugging scenarios:
> - **Slot shows wrong appearance**: Check `transmogID` — is it the correct ItemModifiedAppearanceID?
> - **Slot shows "Unassigned" when it shouldn't**: Check `displayType` — the server is returning `0` instead of `1`
> - **Slot grayed out**: Check `canTransmogrify` — the server says this slot can't be changed
> - **Error overlay on slot**: Check `error` and `errorText` — the server is rejecting this transmog
> - **Icon wrong/missing**: Check `texture` — the server must provide the correct fileID

### 10.2 TransmogOutfitEntryInfo

Returned by `C_TransmogOutfitInfo.GetOutfitsInfo()` / `GetOutfitInfo()`.

```lua
TransmogOutfitEntryInfo = {
    outfitID            = number,
    name                = string,
    situationCategories = table<cstring>,  -- which situations this outfit is assigned to
    icon                = fileID,
    isEventOutfit       = bool,            -- Trial of Style outfit
    isDisabled          = bool,            -- outfit is disabled (expired event, etc.)
}
```

### 10.3 TransmogOutfitSlotInfo

Returned as part of `GetAllSlotLocationInfo()` and `GetSlotGroupInfo()`.

```lua
TransmogOutfitSlotInfo = {
    slot           = TransmogOutfitSlot,      -- enum 0-12
    type           = TransmogType,            -- Appearance or Illusion
    collectionType = TransmogCollectionType,   -- category for wardrobe browsing
    slotName       = cstring,                 -- localized name
    isSecondary    = bool,                    -- secondary (split) slot
}
```

### 10.4 AppearanceSourceInfo

Returned by `C_TransmogCollection.GetSourceInfo()` and many other functions.

```lua
AppearanceSourceInfo = {
    visualID                    = number,
    sourceID                    = number,   -- ItemModifiedAppearance ID
    isCollected                 = bool,
    itemID                      = number,
    itemModID                   = number,
    invType                     = luaIndex, -- default 0
    categoryID                  = TransmogCollectionType, -- default "None"
    playerCanCollect            = bool,
    isValidSourceForPlayer      = bool,
    canDisplayOnPlayer          = bool,
    inventorySlot               = number,   -- nilable
    sourceType                  = luaIndex, -- nilable
    name                        = string,   -- nilable
    quality                     = number,   -- nilable
    useError                    = string,   -- nilable
    useErrorType                = TransmogUseErrorType, -- nilable
    meetsTransmogPlayerCondition = bool,    -- nilable
    isHideVisual                = bool,     -- nilable
}
```

> **NOTE (Server)**: The `sourceID` is the `ItemModifiedAppearance` ID — this is what gets stored in outfit slot data. The `visualID` is the `ItemAppearance` visual — multiple sources can share the same visual. The server must track both: `sourceID` for ownership/collection, `visualID` for display.

### 10.5 TransmogSlotVisualInfo

Returned by `C_Transmog.GetSlotVisualInfo()`.

```lua
TransmogSlotVisualInfo = {
    baseSourceID    = number,  -- the real equipped item's source
    baseVisualID    = number,  -- the real equipped item's visual
    appliedSourceID = number,  -- the active transmog source (0 if none)
    appliedVisualID = number,  -- the active transmog visual (0 if none)
    pendingSourceID = number,  -- pending transmog source (0 if none)
    pendingVisualID = number,  -- pending transmog visual (0 if none)
    hasUndo         = bool,    -- can undo this transmog
    isHideVisual    = bool,    -- using a hidden appearance
    itemSubclass    = number,  -- weapon subclass (for weapon slots)
}
```

### 10.6 TransmogSetInfo

Returned by `C_TransmogSets.GetSetInfo()` and set listing functions.

```lua
TransmogSetInfo = {
    setID                  = number,
    name                   = string,
    baseSetID              = number,   -- nilable (nil if this IS the base)
    description            = cstring,  -- nilable
    label                  = cstring,  -- nilable (e.g., "Heroic", "Mythic")
    expansionID            = number,
    patchID                = number,
    uiOrder                = number,
    classMask              = number,
    hiddenUntilCollected   = bool,
    requiredFaction        = cstring,  -- nilable ("Alliance", "Horde")
    collected              = bool,
    favorite               = bool,
    limitedTimeSet         = bool,
    validForCharacter      = bool,
    grantAsPrecedingVariant = bool,
}
```

### 10.7 ItemTransmogInfo

Used for model rendering and custom set storage. A list of these represents a full outfit.

```lua
ItemTransmogInfo = {
    appearanceID          = number,  -- primary ItemModifiedAppearanceID
    secondaryAppearanceID = number,  -- secondary (split shoulder) IMAID
    illusionID            = number,  -- SpellItemEnchantment ID for illusions
}
```

The full outfit is a list of 17 ItemTransmogInfo entries (from `TransmogUtil.GetEmptyItemTransmogInfoList()`):

```
Index  Slot
  1    Head
  2    Shoulder (primary)
  3    Shoulder (secondary)
  4    Back
  5    Chest
  6    Body (shirt)
  7    Tabard
  8    Wrist
  9    Hand
 10    Waist
 11    Legs
 12    Feet
 13    Mainhand (primary)
 14    Mainhand (secondary / paired weapon)
 15    Mainhand (illusion)
 16    Offhand
 17    Offhand (illusion)
```

> **NOTE (Server)**: This 17-entry format is used by custom set slash commands and hyperlinks. The server's internal format may differ, but when exchanging data with the client, this ordering must be respected.

### 10.8 TransmogCategoryAppearanceInfo

Returned by `C_TransmogCollection.GetCategoryAppearances()`.

```lua
TransmogCategoryAppearanceInfo = {
    visualID              = number,
    isCollected           = bool,
    isFavorite            = bool,
    isHideVisual          = bool,   -- TRUE for "hidden item" appearances
    canDisplayOnPlayer    = bool,
    uiOrder               = number,
    exclusions            = number,
    isUsable              = bool,
    hasRequiredHoliday    = bool,
    hasActiveRequiredHoliday = bool,
    alwaysShowItem        = bool,   -- nilable, internal testing only
}
```

### 10.9 TransmogIllusionInfo

```lua
TransmogIllusionInfo = {
    visualID     = number,
    sourceID     = number,
    icon         = fileID,
    isCollected  = bool,
    isUsable     = bool,
    isHideVisual = bool,  -- The "no enchant" illusion
}
```

### 10.10 TransmogSituationOption

```lua
TransmogSituationOption = {
    situationID    = number,
    specID         = number,
    loadoutID      = number,
    equipmentSetID = number,
}
```

### 10.11 TransmogOutfitWeaponOptionInfo

```lua
TransmogOutfitWeaponOptionInfo = {
    weaponOption = TransmogOutfitSlotOption,
    name         = cstring,    -- e.g., "One-Handed Swords"
    enabled      = bool,
}
```

### 10.12 TransmogOutfitLinkedSlotInfo

```lua
TransmogOutfitLinkedSlotInfo = {
    primarySlotInfo   = TransmogOutfitSlotInfo,
    secondarySlotInfo = TransmogOutfitSlotInfo,
}
```

### 10.13 TransmogOutfitSlotGroup

```lua
TransmogOutfitSlotGroup = {
    position          = TransmogOutfitSlotPosition,  -- Left/Right/Bottom
    appearanceSlotInfo = table<TransmogOutfitSlotInfo>,
    illusionSlotInfo   = table<TransmogOutfitSlotInfo>,
}
```

### 10.14 TransmogApplyWarningInfo

```lua
TransmogApplyWarningInfo = {
    itemLink = string,
    text     = string,
}
```

### 10.15 TransmogSetItemInfo

```lua
TransmogSetItemInfo = {
    itemID                   = number,
    itemModifiedAppearanceID = number,
    invSlot                  = number,
    invType                  = string,
}
```

### 10.16 TransmogSetPrimaryAppearanceInfo

```lua
TransmogSetPrimaryAppearanceInfo = {
    appearanceID = number,
    collected    = bool,
}
```

### 10.17 TransmogSituationCategory / Group / OptionData

```lua
TransmogSituationCategory = {
    triggerID    = number,
    name         = cstring,
    description  = cstring,
    isRadioButton = bool,
    groupData    = table<TransmogSituationGroup>,
}

TransmogSituationGroup = {
    groupID     = number,
    secondaryID = number,
    optionData  = table<TransmogSituationOptionData>,
}

TransmogSituationOptionData = {
    name   = cstring,
    value  = bool,
    option = TransmogSituationOption,
}
```

### 10.18 TransmogOutfitWeaponCollectionInfo

```lua
TransmogOutfitWeaponCollectionInfo = {
    name            = cstring,
    isWeapon        = bool,
    canHaveIllusions = bool,
}
```

### 10.19 TransmogSlotInfo (from C_Transmog)

```lua
TransmogSlotInfo = {
    isTransmogrified         = bool,
    hasPending               = bool,
    isPendingCollected       = bool,
    canTransmogrify          = bool,
    cannotTransmogrifyReason = number,
    hasUndo                  = bool,
    isHideVisual             = bool,
    texture                  = fileID,   -- nilable
}
```

### 10.20 TransmogAppearanceInfoBySourceData

```lua
TransmogAppearanceInfoBySourceData = {
    appearanceID                        = number,
    appearanceIsCollected               = bool,
    sourceIsCollected                   = bool,
    sourceIsCollectedPermanent          = bool,
    sourceIsCollectedConditional        = bool,
    meetsTransmogPlayerCondition        = bool,
    appearanceHasAnyNonLevelRequirements = bool,
    appearanceMeetsNonLevelRequirements  = bool,
    appearanceIsUsable                  = bool,
    appearanceNumSources                = number,
    sourceIsKnown                       = bool,
    canDisplayOnPlayer                  = bool,
    isAnySourceValidForPlayer           = bool,
}
```

### 10.21 TransmogAppearanceSourceInfoData

```lua
TransmogAppearanceSourceInfoData = {
    category         = TransmogCollectionType,
    itemAppearanceID = number,
    canHaveIllusion  = bool,
    icon             = fileID,
    isCollected      = bool,
    itemLink         = string,
    transmoglink     = string,
    sourceType       = luaIndex,  -- nilable
    itemSubclass     = number,
}
```

### 10.22 TransmogAppearanceJournalEncounterInfo

```lua
TransmogAppearanceJournalEncounterInfo = {
    instance     = string,
    instanceType = number,
    tiers        = table<string>,
    encounter    = string,
    difficulties = table<string>,
}
```

### 10.23 TransmogCustomSetInfo

```lua
TransmogCustomSetInfo = {
    name = cstring,
    icon = fileID,
}
```

### 10.24 TransmogCategoryInfo

Returned by `C_TransmogCollection.GetCategoryInfo()`.

```lua
TransmogCategoryInfo = {
    name             = cstring,          -- localized category name (e.g., "Plate", "One-Handed Swords")
    isWeapon         = bool,             -- true for weapon categories
    canHaveIllusions = bool,             -- true if items in this category support illusions
    canMainHand      = bool,             -- valid for mainhand slot
    canOffHand       = bool,             -- valid for offhand slot
    canRanged        = bool,             -- valid for ranged slot (legacy)
}
```

---

## 11. Client → Server Packet Triggers

This section maps Lua API calls to the network packets they generate. Packet names are inferred from the API call semantics — the exact CMSG names depend on the server's opcode table.

### 11.1 Outfit CRUD Operations

| Client API Call | Likely CMSG | Data Sent |
|---|---|---|
| `C_TransmogOutfitInfo.AddNewOutfit(name, icon)` | `CMSG_TRANSMOG_OUTFIT_ADD` | name, icon, all pending slot states |
| `C_TransmogOutfitInfo.CommitOutfitInfo(outfitID, name, icon)` | `CMSG_TRANSMOG_OUTFIT_UPDATE` | outfitID, name, icon, pending slots |
| `C_TransmogOutfitInfo.CommitAndApplyAllPending(useDiscount)` | `CMSG_TRANSMOG_SET_ITEMS` | all pending slot transmogIDs, displayTypes, useDiscount flag |

### 11.2 Viewing / Displaying Outfits

| Client API Call | Likely CMSG | Data Sent |
|---|---|---|
| `C_TransmogOutfitInfo.ChangeViewedOutfit(outfitID)` | `CMSG_TRANSMOG_OUTFIT_VIEW` | outfitID |
| `C_TransmogOutfitInfo.ChangeDisplayedOutfit(outfitID, trigger, toggleLock, allowRemove)` | `CMSG_TRANSMOG_OUTFIT_DISPLAY` | outfitID, trigger, toggleLock, allowRemove |
| `C_TransmogOutfitInfo.ClearDisplayedOutfit(trigger, toggleLock)` | `CMSG_TRANSMOG_OUTFIT_CLEAR_DISPLAY` | trigger, toggleLock |

### 11.3 Pending Transmog Operations

| Client API Call | Likely CMSG | Data Sent |
|---|---|---|
| `C_TransmogOutfitInfo.SetPendingTransmog(slot, type, option, transmogID, displayType)` | `CMSG_TRANSMOG_SET_PENDING` | slot, type, option, transmogID, displayType |
| `C_TransmogOutfitInfo.RevertPendingTransmog(slot, type, option)` | `CMSG_TRANSMOG_REVERT_PENDING` | slot, type, option |
| `C_TransmogOutfitInfo.ClearAllPendingTransmogs()` | `CMSG_TRANSMOG_CLEAR_ALL_PENDING` | none |

### 11.4 Set / Custom Set Application

| Client API Call | Likely CMSG | Data Sent |
|---|---|---|
| `C_TransmogOutfitInfo.SetOutfitToSet(transmogSetID)` | `CMSG_TRANSMOG_OUTFIT_TO_SET` | transmogSetID |
| `C_TransmogOutfitInfo.SetOutfitToCustomSet(customSetID)` | `CMSG_TRANSMOG_OUTFIT_TO_CUSTOM_SET` | customSetID |
| `C_TransmogOutfitInfo.SetOutfitToOutfit(outfitID)` | `CMSG_TRANSMOG_OUTFIT_TO_OUTFIT` | outfitID |

### 11.5 Secondary Slot Operations

| Client API Call | Likely CMSG | Data Sent |
|---|---|---|
| `C_TransmogOutfitInfo.SetSecondarySlotState(slot, state)` | `CMSG_TRANSMOG_SET_SECONDARY_STATE` | slot, bool state |

### 11.6 Weapon Options

| Client API Call | Likely CMSG | Data Sent |
|---|---|---|
| `C_TransmogOutfitInfo.SetViewedWeaponOptionForSlot(slot, option)` | `CMSG_TRANSMOG_SET_WEAPON_OPTION` | slot, weaponOption |

### 11.7 Situation Operations

| Client API Call | Likely CMSG | Data Sent |
|---|---|---|
| `C_TransmogOutfitInfo.SetOutfitSituationsEnabled(enabled)` | `CMSG_TRANSMOG_SITUATIONS_ENABLED` | bool enabled |
| `C_TransmogOutfitInfo.UpdatePendingSituation(option, value)` | `CMSG_TRANSMOG_UPDATE_SITUATION` | TransmogSituationOption, bool |
| `C_TransmogOutfitInfo.CommitPendingSituations()` | `CMSG_TRANSMOG_COMMIT_SITUATIONS` | all pending situations |
| `C_TransmogOutfitInfo.ClearAllPendingSituations()` | `CMSG_TRANSMOG_CLEAR_SITUATIONS` | none |
| `C_TransmogOutfitInfo.ResetOutfitSituations()` | `CMSG_TRANSMOG_RESET_SITUATIONS` | none |

### 11.8 Misc Operations

| Client API Call | Likely CMSG | Data Sent |
|---|---|---|
| `C_TransmogOutfitInfo.PickupOutfit(outfitID)` | (client-side only — no packet) | none |
| `C_TransmogCollection.SetIsAppearanceFavorite(id, fav)` | `CMSG_TRANSMOG_SET_FAVORITE` | appearanceID, isFavorite |
| `C_TransmogSets.SetIsFavorite(setID, fav)` | `CMSG_TRANSMOG_SET_SET_FAVORITE` | setID, isFavorite |

### 11.9 Query-Only Calls (No CMSG)

These API calls return cached client data and do NOT send packets:

```
C_TransmogOutfitInfo.GetViewedOutfitSlotInfo()   -- reads cached state
C_TransmogOutfitInfo.GetOutfitsInfo()             -- reads cached list
C_TransmogOutfitInfo.GetActiveOutfitID()          -- reads cached ID
C_TransmogOutfitInfo.HasPendingOutfitTransmogs()  -- reads cached flag
C_TransmogOutfitInfo.GetPendingTransmogCost()     -- reads cached cost
C_Transmog.GetSlotVisualInfo()                    -- reads cached visual
C_Transmog.IsAtTransmogNPC()                      -- reads cached state
C_TransmogCollection.GetSourceInfo()              -- reads cached DB2 data
C_TransmogCollection.IsAppearanceHiddenVisual()   -- reads cached DB2 data
-- All filter/search functions are purely client-side
```

> **NOTE (Server)**: The "cached state" is populated by SMSG responses. If the server doesn't send the right data, these queries return stale/wrong values. The most common issue is `GetViewedOutfitSlotInfo` returning stale data because the server didn't fire `VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH` after changing state.

---

## 12. Server → Client Event Triggers

This section maps server packets (SMSG) to the client events they fire.

### 12.1 Core SMSG → Event Mapping

| Server Packet (SMSG) | Client Event(s) Fired | When |
|---|---|---|
| `SMSG_OPEN_TRANSMOGRIFIER` | `TRANSMOGRIFY_OPEN` | Player opens transmog NPC |
| `SMSG_TRANSMOGRIFY_UPDATE` | `TRANSMOGRIFY_UPDATE` | Transmog state changed |
| `SMSG_TRANSMOGRIFY_RESULT` | `TRANSMOGRIFY_SUCCESS` (per slot) | After successful apply |
| Outfit list update | `TRANSMOG_OUTFITS_CHANGED` | Outfit created/modified/deleted |
| Outfit display change | `TRANSMOG_DISPLAYED_OUTFIT_CHANGED` | Active outfit changed |
| Viewed outfit change | `VIEWED_TRANSMOG_OUTFIT_CHANGED` | Preview outfit loaded |
| Slot data update | `VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH` | Slot pending/state changed |
| Slot save success | `VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS` | Single slot saved |
| Weapon option change | `VIEWED_TRANSMOG_OUTFIT_SLOT_WEAPON_OPTION_CHANGED` | Weapon category switched |
| Secondary toggle | `VIEWED_TRANSMOG_OUTFIT_SECONDARY_SLOTS_CHANGED` | Split shoulder toggle |
| Situation change | `VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED` | Situation config update |
| Collection update | `TRANSMOG_COLLECTION_UPDATED` | Appearance learned/unlearned |
| Source added | `TRANSMOG_COLLECTION_SOURCE_ADDED` | Specific source learned |
| Source removed | `TRANSMOG_COLLECTION_SOURCE_REMOVED` | Source removed |
| Item update | `TRANSMOGRIFY_ITEM_UPDATE` | Item swap in slot |

### 12.2 Event Firing Sequences

#### After CommitAndApplyAllPending (Apply Button)

The server should fire events in this order:

```
1. For each successfully transmogged slot:
   → TRANSMOGRIFY_SUCCESS { transmogLocation }
      (per-slot, with the TransmogLocationMixin identifying which slot)

2. After all slots processed:
   → TRANSMOG_OUTFITS_CHANGED { nil }
      (outfit was updated — no new outfit created, so newOutfitID is nil)

3. Then:
   → VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH
      (tells UI to re-query all slot states)

4. If the active outfit changed:
   → TRANSMOG_DISPLAYED_OUTFIT_CHANGED
```

#### After AddNewOutfit

```
1. TRANSMOG_OUTFITS_CHANGED { newOutfitID }
   (newOutfitID is the ID of the newly created outfit)

2. VIEWED_TRANSMOG_OUTFIT_CHANGED
   (the new outfit becomes the viewed outfit)

3. VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH
```

#### After ChangeViewedOutfit

```
1. (Server loads outfit data into the viewed state)

2. VIEWED_TRANSMOG_OUTFIT_CHANGED
   (triggers UI to re-query all slots)

3. VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH
   (optional — depends on whether slot data also changed)
```

#### After SetPendingTransmog

```
1. (Server updates the pending state for that slot)

2. VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH
   (tells UI to re-query the changed slot)
```

> **NOTE (Server)**: The event ordering matters. If `VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH` fires before the server has fully updated the pending state, the UI will re-query and get stale data. Always update state first, then fire events.

### 12.3 Close / Cleanup

When the transmog NPC interaction ends:

```
1. Server sends close packet
2. TRANSMOGRIFY_CLOSE fires
3. TransmogFrame:Hide()
4. All pending state is cleared client-side
```

> **NOTE (Server)**: If the server doesn't send the close packet and the player walks away, the client may leave the transmog UI open in a broken state. Always send the close event when the NPC interaction ends.

---

## 13. Hidden Item / Clear Slot Handling *(CRITICAL)*

This section covers the complete system for hiding equipment slots and clearing transmogs — two of the most error-prone areas in server-side implementation.

### 13.1 How Hidden Items Work

"Hidden items" are special appearances that make an equipment slot **invisible**. Each transmoggable slot has a corresponding hidden appearance defined in DB2 data.

```lua
-- Client checks if an appearance is a "hidden item":
C_TransmogCollection.IsAppearanceHiddenVisual(appearanceID) → bool

-- Client checks if an illusion is the "no enchant" illusion:
C_TransmogCollection.IsSpellItemEnchantmentHiddenVisual(enchantmentID) → bool
```

When the client queries category appearances, hidden items are included with a flag:

```lua
local appearances = C_TransmogCollection.GetCategoryAppearances(category)
for _, info in ipairs(appearances) do
    if info.isHideVisual then
        -- This is the "hidden item" appearance for this category
        -- info.visualID is the visual to apply to hide the slot
    end
end
```

### 13.2 Hiding a Slot in the Outfit System

In the 12.x outfit system, hiding a slot uses `TransmogOutfitDisplayType.Hidden`:

```lua
-- To hide a slot:
C_TransmogOutfitInfo.SetPendingTransmog(
    slot,                                    -- TransmogOutfitSlot (0-12)
    Enum.TransmogType.Appearance,             -- appearance, not illusion
    option,                                   -- weapon option
    hiddenAppearanceTransmogID,               -- the hidden visual's transmog ID
    Enum.TransmogOutfitDisplayType.Hidden     -- displayType = 2
)
```

In the UI, this is triggered by:
1. Selecting the "Hidden" appearance in the wardrobe grid (the appearance where `isHideVisual = true`)
2. Or via a dedicated "Hide" button/option

The slot then shows with a special icon:

```lua
-- From TransmogAppearanceSlotMixin:Update():
if slotInfo.displayType == Enum.TransmogOutfitDisplayType.Hidden then
    self.Icon:SetAtlas("transmog-icon-hidden")
end
```

### 13.3 TransmogSlotVisualInfo and isHideVisual

The `C_Transmog.GetSlotVisualInfo()` function returns an `isHideVisual` field:

```lua
local visualInfo = C_Transmog.GetSlotVisualInfo(transmogLocation)
if visualInfo.isHideVisual then
    -- The currently applied transmog on this slot is a hidden appearance
    -- The slot will render as invisible on the character
end
```

> **NOTE (Server)**: The server must set `isHideVisual = true` in the slot visual info when a hidden appearance is applied. If this flag is wrong, the UI will show the wrong icon (normal appearance icon instead of the hidden icon).

### 13.4 Hidden Item DB2 Sources

Hidden appearances come from specific items in the DB2 data. Each armor slot and some weapon slots have a dedicated "hidden" ItemModifiedAppearance entry.

The client identifies these through `IsAppearanceHiddenVisual()`, which checks internal DB2 data. The exact table name is not confirmed in the Lua source — it may be `TransmogHideItem` or a flag on `ItemAppearance` (inferred from DB2 structure, not directly referenced in client code).

> **NOTE (Server)**: The server must have the correct hidden item appearance IDs for each slot. These are NOT arbitrary — they must match the DB2 definitions that the client uses. If the server applies the wrong "hidden" appearance ID, the client won't recognize it as a hidden item and will try to render it as a normal appearance (potentially showing a placeholder or broken model).

### 13.5 Clearing a Transmog (Removing It)

"Clearing" a transmog means reverting a slot to show its real equipped item appearance. This is distinct from hiding (which makes it invisible).

In the 12.x outfit system, clearing uses `TransmogOutfitDisplayType.Equipped`:

```lua
-- To clear a slot (show real gear):
C_TransmogOutfitInfo.SetPendingTransmog(
    slot,
    Enum.TransmogType.Appearance,
    option,
    Constants.Transmog.NoTransmogID,              -- transmogID = 0
    Enum.TransmogOutfitDisplayType.Equipped        -- displayType = 3
)
```

This tells the outfit: "For this slot, show whatever is actually equipped." When the outfit is applied, any existing transmog on the slot is removed.

### 13.6 Unassigned vs Clear vs Hidden — The Three-Way Distinction

This is the most confusing and bug-prone area:

| DisplayType | transmogID | Meaning | On Apply |
|---|---|---|---|
| **Unassigned (0)** | 0 | Outfit has no opinion on this slot | **Skip** — don't touch this slot |
| **Assigned (1)** | (id) | Outfit assigns a specific appearance | Apply that appearance |
| **Hidden (2)** | (hidden id) | Outfit hides this slot | Apply the hidden appearance |
| **Equipped (3)** | 0 | Outfit shows real gear | **Remove** existing transmog |

> **NOTE (Server)**: The most common server bug is treating `Unassigned` and `Equipped` the same. They are NOT:
> - **Unassigned**: Leave whatever transmog was already on the slot. The outfit doesn't define this slot.
> - **Equipped**: Actively REMOVE any transmog on the slot. The outfit explicitly wants real gear shown.
>
> If the server treats `Unassigned` as `Equipped`, switching outfits will strip transmogs from slots the new outfit doesn't define — causing the "naked slot" bug.
>
> If the server treats `Equipped` as `Unassigned`, the player can't clear individual slots through the outfit system — old transmogs will persist.

### 13.7 Hidden Illusions

Illusions (weapon enchant visuals) also have a "hidden" variant:

```lua
C_TransmogCollection.IsSpellItemEnchantmentHiddenVisual(enchantmentID) → bool

-- When iterating illusions:
local illusions = C_TransmogCollection.GetIllusions()
for _, info in ipairs(illusions) do
    if info.isHideVisual then
        -- This is the "no enchant" illusion
        -- Applying this removes the visual enchant effect
    end
end
```

### 13.8 Slot Clearing in Legacy (Pre-12.x) vs Modern System

In the old system (pre-12.x), clearing a slot used `TransmogPendingType`:

```lua
-- Old system (still exists in C_Transmog but largely superseded):
Enum.TransmogPendingType = {
    Apply     = 0,  -- Apply a transmog
    Revert    = 1,  -- Revert to no transmog
    ToggleOn  = 2,  -- Toggle hidden on
    ToggleOff = 3,  -- Toggle hidden off
}
```

In the modern 12.x system, these operations map to `TransmogOutfitDisplayType`:
- `Apply` → `Assigned` with a transmogID
- `Revert` → `Equipped` with transmogID = 0
- `ToggleOn` → `Hidden` with the hidden appearance ID
- `ToggleOff` → `Equipped` with transmogID = 0

### 13.9 Client-Side Rendering of Hidden Slots

When the actor model has a hidden appearance applied:

```lua
-- The actor renders the slot as completely invisible
-- The character model skips rendering that geometry
-- The paperdoll slot shows the "transmog-icon-hidden" atlas
```

When a transmog is cleared (Equipped):

```lua
-- The actor renders the real equipped item's appearance
-- The paperdoll slot shows the real item's icon
-- No special border or indicator
```

When a slot is Unassigned:

```lua
-- The paperdoll slot shows the unassigned atlas for that slot type
-- The actor shows nothing (or the base outfit if one is loaded)
-- The slot appears "empty" in the outfit editor
local atlas = C_TransmogOutfitInfo.GetUnassignedAtlasForSlot(slot)
```

### 13.10 Custom Set Slash Command Format for Hidden Items

From `Blizzard_TransmogShared.lua`, custom sets use a slash command format:

```lua
-- /customset v1 head,shoulder,shoulderSecondary,back,chest,body,tabard,
--               wrist,hand,waist,legs,feet,mainhand,mainhandSecondary,
--               mainhandIllusion,offhand,offhandIllusion

-- Each value is an ItemModifiedAppearance ID
-- Hidden items use their specific hidden IMA ID
-- 0 means no transmog for that slot
```

When parsing, the client uses `TransmogUtil.IsValidItemTransmogInfoList()` to validate and `TransmogUtil.IsCustomSetCollected()` to check if all appearances are owned.

### 13.11 Debugging Hidden/Clear Issues

Common debugging scenarios:

1. **Slot won't hide**: Check that the hidden appearance ID is correct for the slot's armor type. A leather hidden helm ID won't work on a plate helm slot.

2. **Hidden slot shows geometry**: The `isHideVisual` flag isn't set correctly in the visual info. Check `TransmogSlotVisualInfo.isHideVisual`.

3. **Clear doesn't remove transmog**: The server is treating `Equipped` displayType as `Unassigned`. Verify the server processes `displayType = 3` as "remove transmog".

4. **Old transmog persists after outfit switch**: Outfit has `Unassigned` (0) for the slot. The server correctly skips it. If the player wants the slot cleared, the outfit needs `Equipped` (3) for that slot.

5. **Paperdoll shows wrong icon for hidden slot**: The server should return `displayType = Hidden` in `ViewedTransmogOutfitSlotInfo` so the client uses the hidden atlas.

---

## 14. Cross-Reference Index

### 14.1 Function → Source File

| Function/Mixin | Source File |
|---|---|
| `C_Transmog.*` | `TransmogDocumentation.lua` |
| `C_TransmogCollection.*` | `TransmogItemsDocumentation.lua` |
| `C_TransmogOutfitInfo.*` | `TransmogOutfitInfoDocumentation.lua` |
| `C_TransmogSets.*` | `TransmogSetsDocumentation.lua` |
| `TransmogSlot` enum | `TransmogConstantsDocumentation.lua` |
| `Constants.Transmog` | `TransmogConstantsDocumentation.lua` |
| `AppearanceSourceInfo` | `AppearanceSourceDocumentation.lua` |
| `TransmogLocationMixin` | `Blizzard_TransmogShared.lua` |
| `TransmogUtil.*` | `Blizzard_TransmogShared.lua` |
| `TRANSMOG_SLOTS` | `Blizzard_TransmogShared.lua` |
| `WARDROBE_MODEL_SETUP` | `Blizzard_TransmogShared.lua` |
| `TransmogSlotOrder` | `Blizzard_TransmogShared.lua` |
| `InitializeSlotLocationInfo` | `Blizzard_TransmogShared.lua` |
| `ItemModelBaseMixin` | `Blizzard_TransmogShared.lua` |
| `WardrobeSetsDataProviderMixin` | `Blizzard_TransmogShared.lua` |
| `TransmogFrameMixin` | `Blizzard_Transmog.lua` |
| `TransmogOutfitCollectionMixin` | `Blizzard_Transmog.lua` |
| `TransmogOutfitPopupMixin` | `Blizzard_Transmog.lua` |
| `TransmogCharacterMixin` | `Blizzard_Transmog.lua` |
| `TransmogWardrobeMixin` | `Blizzard_Transmog.lua` |
| `TransmogWardrobeItemsMixin` | `Blizzard_Transmog.lua` |
| `TransmogWardrobeSetsMixin` | `Blizzard_Transmog.lua` |
| `TransmogWardrobeCustomSetsMixin` | `Blizzard_Transmog.lua` |
| `TransmogWardrobeSituationsMixin` | `Blizzard_Transmog.lua` |
| `TransmogOutfitEntryMixin` | `Blizzard_TransmogTemplates.lua` |
| `TransmogSlotMixin` | `Blizzard_TransmogTemplates.lua` |
| `TransmogAppearanceSlotMixin` | `Blizzard_TransmogTemplates.lua` |
| `TransmogIllusionSlotMixin` | `Blizzard_TransmogTemplates.lua` |
| `TransmogSearchBoxMixin` | `Blizzard_TransmogTemplates.lua` |
| `TransmogItemModelMixin` | `Blizzard_TransmogTemplates.lua` |
| `TransmogSetBaseModelMixin` | `Blizzard_TransmogTemplates.lua` |
| `TransmogSetModelMixin` | `Blizzard_TransmogTemplates.lua` |
| `TransmogCustomSetModelMixin` | `Blizzard_TransmogTemplates.lua` |
| `TransmogSlotFlyoutDropdownMixin` | `Blizzard_TransmogTemplates.lua` |
| `WardrobeCollectionFrameMixin` | `Blizzard_Wardrobe.lua` |
| `WardrobeItemsCollectionMixin` | `Blizzard_Wardrobe.lua` |
| `WardrobeItemModelMixin` | `Blizzard_Wardrobe.lua` |
| `WardrobeSetsCollectionMixin` | `Blizzard_Wardrobe_Sets.lua` |
| `WardrobeSetsDetailsModelMixin` | `Blizzard_Wardrobe_Sets.lua` |
| `WardrobeSetsDetailsItemMixin` | `Blizzard_Wardrobe_Sets.lua` |
| `SET_MODEL_PAN_AND_ZOOM_LIMITS` | `Blizzard_Wardrobe_Sets.lua` |
| `WardrobeCustomSetDropdownMixin` | `WardrobeCustomSets.lua` |
| `WardrobeCustomSetManager` | `WardrobeCustomSets.lua` |
| `WardrobeCustomSetEditFrameMixin` | `WardrobeCustomSets.lua` |
| `WardrobeCustomSetCheckAppearancesMixin` | `WardrobeCustomSets.lua` |
| Feature flag overrides | `Blizzard_TransmogOverrides.lua` |
| UI panel registration | `Blizzard_TransmogRegistration.lua` |

### 14.2 Event → Handler Mapping

| Event | Primary Handler(s) |
|---|---|
| `TRANSMOGRIFY_OPEN` | `TransmogFrameMixin:OnEvent` → Show frame |
| `TRANSMOGRIFY_CLOSE` | `TransmogFrameMixin:OnEvent` → Hide frame |
| `TRANSMOGRIFY_UPDATE` | `TransmogFrameMixin:OnEvent` → Refresh slots |
| `TRANSMOGRIFY_SUCCESS` | `TransmogFrameMixin:OnEvent` → Flash slot border |
| `TRANSMOGRIFY_ITEM_UPDATE` | `TransmogFrameMixin:OnEvent` → Refresh |
| `TRANSMOG_OUTFITS_CHANGED` | `TransmogFrameMixin:OnEvent` → RefreshOutfits |
| `TRANSMOG_DISPLAYED_OUTFIT_CHANGED` | `TransmogFrameMixin:OnEvent` → Update active |
| `VIEWED_TRANSMOG_OUTFIT_CHANGED` | `TransmogFrameMixin:OnEvent` → RefreshSlots |
| `VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH` | `TransmogFrameMixin:OnEvent` → RefreshSlots |
| `VIEWED_TRANSMOG_OUTFIT_SLOT_SAVE_SUCCESS` | `TransmogFrameMixin:OnEvent` → Flash success |
| `VIEWED_TRANSMOG_OUTFIT_SLOT_WEAPON_OPTION_CHANGED` | `TransmogAppearanceSlotMixin` → Update weapon |
| `VIEWED_TRANSMOG_OUTFIT_SECONDARY_SLOTS_CHANGED` | `TransmogFrameMixin:OnEvent` → Refresh secondary |
| `VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED` | `TransmogWardrobeSituationsMixin` |
| `TRANSMOG_COLLECTION_UPDATED` | `WardrobeCollectionFrameMixin:OnEvent` |
| `TRANSMOG_COLLECTION_SOURCE_ADDED` | `WardrobeCollectionFrameMixin:OnEvent` |
| `TRANSMOG_SEARCH_UPDATED` | `WardrobeCollectionFrameMixin:OnEvent` |

### 14.3 Structure → Usage Mapping

| Structure | Primary Producers | Primary Consumers |
|---|---|---|
| `ViewedTransmogOutfitSlotInfo` | `GetViewedOutfitSlotInfo()` | `TransmogSlotMixin:Update()`, `TransmogAppearanceSlotMixin:Update()` |
| `TransmogOutfitEntryInfo` | `GetOutfitsInfo()`, `GetOutfitInfo()` | `TransmogOutfitEntryMixin:Init()` |
| `AppearanceSourceInfo` | `GetSourceInfo()`, `GetAppearanceSources()` | Tooltips, wardrobe grid, set details |
| `TransmogSlotVisualInfo` | `GetSlotVisualInfo()` | `TransmogUtil.GetInfoForEquippedSlot()` |
| `TransmogCategoryAppearanceInfo` | `GetCategoryAppearances()` | `WardrobeItemsCollectionMixin:UpdateItems()` |
| `TransmogSetInfo` | `GetSetInfo()`, `GetAllSets()` | `WardrobeSetsCollectionMixin`, set list |
| `ItemTransmogInfo` | Custom set storage, model rendering | `actor:SetItemTransmogInfo()`, slash commands |
| `TransmogOutfitSlotInfo` | `GetAllSlotLocationInfo()`, `GetSlotGroupInfo()` | `InitializeSlotLocationInfo()`, slot setup |
| `TransmogIllusionInfo` | `GetIllusions()`, `GetIllusionInfo()` | Illusion slot UI |

### 14.4 Slot Numbering Cross-Reference

| Slot Name | TransmogSlot (0-12) | INVSLOT_* (1-based) | Equipment Slot (0-based) | ItemTransmogInfo Index |
|---|---|---|---|---|
| Head | 0 | INVSLOT_HEAD (1) | EQUIPMENT_SLOT_HEAD (0) | 1 |
| Shoulder | 1 | INVSLOT_SHOULDER (3) | EQUIPMENT_SLOT_SHOULDERS (2) | 2 (pri), 3 (sec) |
| Back | 2 | INVSLOT_BACK (15) | EQUIPMENT_SLOT_BACK (14) | 4 |
| Chest | 3 | INVSLOT_CHEST (5) | EQUIPMENT_SLOT_CHEST (4) | 5 |
| Body/Shirt | 4 | INVSLOT_BODY (4) | EQUIPMENT_SLOT_BODY (3) | 6 |
| Tabard | 5 | INVSLOT_TABARD (19) | EQUIPMENT_SLOT_TABARD (18) | 7 |
| Wrist | 6 | INVSLOT_WRIST (9) | EQUIPMENT_SLOT_WRISTS (8) | 8 |
| Hand | 7 | INVSLOT_HAND (10) | EQUIPMENT_SLOT_HANDS (9) | 9 |
| Waist | 8 | INVSLOT_WAIST (6) | EQUIPMENT_SLOT_WAIST (5) | 10 |
| Legs | 9 | INVSLOT_LEGS (7) | EQUIPMENT_SLOT_LEGS (6) | 11 |
| Feet | 10 | INVSLOT_FEET (8) | EQUIPMENT_SLOT_FEET (7) | 12 |
| Mainhand | 11 | INVSLOT_MAINHAND (16) | EQUIPMENT_SLOT_MAINHAND (15) | 13 (pri), 14 (sec), 15 (illusion) |
| Offhand | 12 | INVSLOT_OFFHAND (17) | EQUIPMENT_SLOT_OFFHAND (16) | 16 (pri), 17 (illusion) |

> **NOTE (Server)**: This cross-reference is essential for debugging slot mismatches. The three numbering systems (TransmogSlot, INVSLOT, EquipmentSlot) are all different and non-linear. Body/Shirt and Tabard positions are particularly confusing — they're not contiguous with the armor slots.

### 14.5 DisplayType Decision Tree

```
When processing a slot in an outfit:

Is displayType == Unassigned (0)?
  YES → Skip this slot entirely. Don't modify its transmog state.
  NO ↓

Is displayType == Assigned (1)?
  YES → Apply transmogID as the slot's transmog appearance.
        If transmogID == 0, this is a bug — Assigned should have a real ID.
  NO ↓

Is displayType == Hidden (2)?
  YES → Apply the hidden appearance for this slot's armor type.
        transmogID should be the hidden visual's IMA ID.
  NO ↓

Is displayType == Equipped (3)?
  YES → Remove any existing transmog from this slot.
        The slot should show the real equipped item.
        transmogID should be 0 (NoTransmogID).
```

### 14.6 Feature Flags

From `Blizzard_TransmogOverrides.lua`:

```lua
function DressUpFrameLinkingSupported()     return true end
function DisplayTypeUnassignedSupported()   return true end
function HelpPlatesSupported()              return true end
```

> **NOTE (Server)**: `DisplayTypeUnassignedSupported() = true` means the 12.x client supports the Unassigned display type. Older clients may not. Our server targets 12.x only, so this is always true.

### 14.7 Key Lookup Table Keys (TRANSMOG_SLOTS)

Quick reference for `TRANSMOG_SLOTS` lookup keys:

```
Slot                        Key (slotID*100 + type*10 + secondary)
Head Appearance (Primary)    100
Shoulder App (Primary)       300
Shoulder App (Secondary)     301
Back Appearance              1500
Chest Appearance             500
Body Appearance              400
Tabard Appearance            1900
Wrist Appearance             900
Hand Appearance              1000
Waist Appearance             600
Legs Appearance              700
Feet Appearance              800
Mainhand Appearance (Pri)    1600
Mainhand Appearance (Sec)    1601
Mainhand Illusion            1610
Offhand Appearance           1700
Offhand Illusion             1710
```

---

## 15. Server-Side Mapping (RoleplayCore)

This section maps client API calls to their actual RoleplayCore server handlers, based on the codebase at `src/server/game/`. Branch: `pr/transmog-ui-12x` (PR #760).

### 15.1 CMSG Opcode → Handler

| Opcode | Hex | Handler | File |
|---|---|---|---|
| `CMSG_TRANSMOGRIFY_ITEMS` | (custom) | `WorldSession::HandleTransmogrifyItems` | `TransmogrificationHandler.cpp:172` |
| `CMSG_TRANSMOG_OUTFIT_NEW` | `0x3A0044` | `WorldSession::HandleTransmogOutfitNew` | `TransmogrificationHandler.cpp:598` |
| `CMSG_TRANSMOG_OUTFIT_UPDATE_INFO` | `0x3A0045` | `WorldSession::HandleTransmogOutfitUpdateInfo` | `TransmogrificationHandler.cpp:666` |
| `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS` | `0x3A0047` | `WorldSession::HandleTransmogOutfitUpdateSlots` | `TransmogrificationHandler.cpp:709` |
| `CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS` | `0x3A0046` | `WorldSession::HandleTransmogOutfitUpdateSituations` | `TransmogrificationHandler.cpp:1076` |

### 15.2 SMSG Opcode → Client Event

| Opcode | Hex | Client Event Triggered |
|---|---|---|
| `SMSG_TRANSMOG_OUTFIT_NEW_ENTRY_ADDED` | `0x42004A` | `TRANSMOG_OUTFITS_CHANGED { newOutfitID }` |
| `SMSG_TRANSMOG_OUTFIT_INFO_UPDATED` | `0x42004B` | `TRANSMOG_OUTFITS_CHANGED` |
| `SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED` | `0x42004D` | `TRANSMOG_OUTFITS_CHANGED`, `VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH` |
| `SMSG_TRANSMOG_OUTFIT_SITUATIONS_UPDATED` | `0x42004C` | `VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED` |

### 15.3 Key Server Files

| File | Role |
|---|---|
| `Handlers/TransmogrificationHandler.cpp` | All 5 CMSG handlers + NPC validation + outfit sync |
| `Server/Packets/TransmogrificationPackets.cpp` | Packet parsing (14-entry slot groups, multi-group merge) |
| `Server/Packets/TransmogrificationPackets.h` | Packet structures (5 CMSG + 4 SMSG classes) |
| `Entities/Player/TransmogrificationUtils.cpp` | `ApplyTransmogOutfitToPlayer()` — applies appearances to items |
| `Entities/Player/Player.cpp` / `.h` | `SetEquipmentSet()`, `SetVisibleItemSlot()`, item modifier storage |
| `Handlers/ChatHandler.cpp` | TransmogBridge addon message handler (fills missing slots) |
| `Server/WorldSession.h` | Handler declarations (lines 1827-1831) |

### 15.4 TransmogBridge Addon Integration

The 12.x client omits **head, mainhand, offhand, and enchant** slots from `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS`. The TransmogBridge addon compensates:

1. **Client**: TransmogBridge reads the full outfit state and sends an addon message with the missing slot data
2. **Server**: `HandleTransmogOutfitUpdateSlots` **defers finalization** — it parses the packet but waits
3. **Server**: `ChatHandler.cpp` receives the addon message, merges the missing IMA IDs into the outfit
4. **Server**: Finalization applies the complete outfit via `ApplyTransmogOutfitToPlayer()`
5. **Safety net**: `WorldSession.cpp:550` — if the addon message never arrives, a timer finalizes after a short delay

### 15.5 Client API → Server Operation Mapping

| Client API Call | Server Operation |
|---|---|
| `C_TransmogOutfitInfo.AddNewOutfit()` | Allocates new `EquipmentSetInfo`, saves to `character_equipmentsets`, sends `SMSG_TRANSMOG_OUTFIT_NEW_ENTRY_ADDED` |
| `C_TransmogOutfitInfo.CommitOutfitInfo()` | Updates name/icon via `SetEquipmentSet()`, sends `SMSG_TRANSMOG_OUTFIT_INFO_UPDATED` |
| `C_TransmogOutfitInfo.CommitAndApplyAllPending()` | **NOT a separate opcode** — handled via `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS` |
| `HandleTransmogrifyItems` (single-item) | Validates appearance, deducts gold, sets `ITEM_MODIFIER_TRANSMOG_APPEARANCE_ALL_SPECS`, clears per-spec modifiers, then syncs to active outfit via `SetEquipmentSet()` |
| `HandleTransmogOutfitUpdateSlots` | Parses 14-entry slot groups, merges multi-group with first-non-zero precedence, defers for TransmogBridge, then calls `ApplyTransmogOutfitToPlayer()` |

### 15.6 Server-Side Slot Storage

The server stores transmog data as **item modifiers** on equipped items:

```
ITEM_MODIFIER_TRANSMOG_APPEARANCE_ALL_SPECS          — primary IMA ID
ITEM_MODIFIER_TRANSMOG_APPEARANCE_SPEC_1..5          — per-spec overrides (cleared on outfit apply)
ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_ALL_SPECS — secondary shoulder IMA ID
ITEM_MODIFIER_ENCHANT_ILLUSION_ALL_SPECS             — illusion SpellItemEnchantmentID
ITEM_MODIFIER_ENCHANT_ILLUSION_SPEC_1..5             — per-spec illusion overrides
```

### 15.7 Known Issues (PR #760 QA)

| Bug | Description | Root Cause |
|---|---|---|
| **Bug A** | Paperdoll appears naked on 2nd transmog UI open | Stale ViewedOutfit state not refreshed |
| **Bug B** | Old head/shoulder persists when outfit doesn't define them | IgnoreMask incorrectly set for undefined slots |
| **Bug C** | Monster Mantle ghost appearance | Previous shoulder appearance not cleared |
| **Bug D** | Draenei leg geometry loss | Race-specific model issue with hidden/clear |
| **Bug E** | Single-item transmog → `SetEquipmentSet` → full ViewedOutfit rebuild | `HandleTransmogrifyItems` syncs single slot back to outfit, triggering `VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH` with rebuilt data |

See `transmog-implementation.md` for detailed diagnostic traces and fix status.

---

*End of Transmog Client Lua Reference Wiki*
*Total API functions documented: 189 across 4 namespaces (7 + 83 + 59 + 40)*
*Total events documented: 23 (15 C_Transmog + 8 C_TransmogOutfitInfo)*
*Total data structures documented: 24*

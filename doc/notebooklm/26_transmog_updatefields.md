# Transmog UpdateField Structures & Opcodes

> Source: WowPacketParser + TrinityCore upstream (build 66263)
> Full wiki: `doc/transmog_deepdive_wiki.md` §22-23

## ActivePlayerData (self-only, NOT visible to others)

```cpp
MapUpdateField<uint32, TransmogOutfitData> TransmogOutfits;  // keyed by outfit ID
UpdateField<TransmogOutfitData> ViewedOutfit;                  // currently displayed
UpdateField<TransmogOutfitMetadata> TransmogMetadata;
DynamicUpdateField<uint32> Transmog;            // collected IMA IDs
DynamicUpdateField<int32> ConditionalTransmog;
DynamicUpdateField<uint32> TransmogIllusions;   // collected illusion IDs
```

## TransmogOutfitSlotData — THE PER-ROW FORMAT (7 fields)

```cpp
int8   Slot;                     // TransmogOutfitSlot (-1 to 14)
uint8  SlotOption;               // TransmogOutfitSlotOption (0-11)
uint32 ItemModifiedAppearanceID; // IMA ID (0 if empty)
uint8  AppearanceDisplayType;    // ADT (0=Unassigned, 1=Assigned, 2=Equipped, 3=Hidden, 4=Disabled)
uint32 SpellItemEnchantmentID;   // illusion enchant (0 if none)
uint8  IllusionDisplayType;      // IDT (mirrors ADT for empty/passthrough; 1 for enchant)
uint32 Flags;                    // TransmogOutfitSlotSaveFlags
```

## TransmogOutfitData (parent container, 30 Slots per outfit)

```cpp
DynamicUpdateField<TransmogOutfitSituationInfo> Situations;
DynamicUpdateField<TransmogOutfitSlotData> Slots;  // 30 rows
uint32 Id;
TransmogOutfitDataInfo OutfitInfo;
uint32 Flags;
```

## TransmogOutfitDataInfo

```cpp
bool        SituationsEnabled;
uint8       SetType;   // 0=Equipped, 1=Outfit, 2=CustomSet
std::string Name;
uint32      Icon;      // FileDataID
```

## TransmogOutfitMetadata (plain struct)

```cpp
bool   Locked;
uint8  SituationTrigger;       // 0-8
uint32 TransmogOutfitID;       // active outfit
uint8  StampedOptionMainHand;  // weapon option for MH
uint8  StampedOptionOffHand;   // weapon option for OH
float  CostMod;                // from aura 655
```

## TransmogOutfitSituationInfo

```cpp
uint32 SituationID;
uint32 SpecID;
uint32 LoadoutID;
uint32 EquipmentSetID;
```

## Opcodes

### CMSG (all UNIMPLEMENTED in upstream TC)
- `CMSG_TRANSMOG_OUTFIT_NEW` (0x3A0044)
- `CMSG_TRANSMOG_OUTFIT_UPDATE_INFO` (0x3A0045)
- `CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS` (0x3A0046)
- `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS` (0x3A0047)

### SMSG
- `SMSG_TRANSMOG_OUTFIT_NEW_ENTRY_ADDED` (0x42004A)
- `SMSG_TRANSMOG_OUTFIT_INFO_UPDATED` (0x42004B)
- `SMSG_TRANSMOG_OUTFIT_SITUATIONS_UPDATED` (0x42004C)
- `SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED` (0x42004D) — full 30-row echo
- `SMSG_ACCOUNT_TRANSMOG_UPDATE` (0x42004F) — collection sync
- `SMSG_FORCE_RANDOM_TRANSMOG_TOAST` (0x42004E)
- `SMSG_ACCOUNT_TRANSMOG_SET_FAVORITES_UPDATE` (0x420050)

## Spell Effect 347 (EQUIP_TRANSMOG_OUTFIT)
- Spell ID: 1247613
- MiscValue = SetID (outfit ID)
- Currently EffectNULL in upstream TC

## Aura 655 (MOD_TRANSMOG_OUTFIT_UPDATE_COST)
- Populates TransmogOutfitMetadata.CostMod
- Currently NULL handler in upstream TC

## Key Implementation Notes
- ViewedOutfit is ActivePlayerData only (self) — others see VisibleItems
- `character_transmog_outfits` table in upstream uses OLD 19-col schema (pre-12.x)
- Must send exactly 30 Slots entries per outfit
- SetType MUST be 1 (Outfit) for client to process it

# Transmog System Cheatsheet

> WoW 12.0.1 (Midnight) Build 66220 — RoleplayCore Quick Reference
> Full wiki: `transmog_client_wiki.md`

---

## ID Types

| ID Type | DB2 Table | Client Name | What It Is |
|---|---|---|---|
| **ItemID** | Item/ItemSparse | `itemID` | Item template |
| **IMA ID** | ItemModifiedAppearance | `sourceID`, `transmogID` | Item+modifier combo — **stored in outfits** |
| **Visual ID** | ItemAppearance | `visualID`, `appearanceID` | Visual look (many IMA → one visual) |
| **Illusion ID** | SpellItemEnchantment | `illusionID` | Weapon enchant glow |

**Chain**: `ItemID → IMA ID → Visual ID → model/texture`
**Server stores**: IMA ID in `ITEM_MODIFIER_TRANSMOG_APPEARANCE_ALL_SPECS`

---

## DisplayType Decision Tree

```
displayType == 0 (Unassigned)?  → SKIP slot, don't touch existing transmog
displayType == 1 (Assigned)?    → APPLY transmogID to slot
displayType == 2 (Hidden)?      → APPLY hidden appearance (slot invisible)
displayType == 3 (Equipped)?    → REMOVE transmog, show real gear
```

**Common bug**: Treating Unassigned as Equipped strips transmogs from undefined slots.

---

## Slot Numbering

| Slot | TransmogSlot | INVSLOT_* | EquipSlot | ItemTransmogInfo |
|---|---|---|---|---|
| Head | 0 | 1 | 0 | 1 |
| Shoulder | 1 | 3 | 2 | 2 (pri), 3 (sec) |
| Back | 2 | 15 | 14 | 4 |
| Chest | 3 | 5 | 4 | 5 |
| Body | 4 | 4 | 3 | 6 |
| Tabard | 5 | 19 | 18 | 7 |
| Wrist | 6 | 9 | 8 | 8 |
| Hand | 7 | 10 | 9 | 9 |
| Waist | 8 | 6 | 5 | 10 |
| Legs | 9 | 7 | 6 | 11 |
| Feet | 10 | 8 | 7 | 12 |
| Mainhand | 11 | 16 | 15 | 13/14/15 |
| Offhand | 12 | 17 | 16 | 16/17 |

---

## Key Event Sequences

**Open → View → Apply:**
```
TRANSMOGRIFY_OPEN → VIEWED_TRANSMOG_OUTFIT_CHANGED
  → (user picks appearance) → VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH
  → (user clicks Apply) → TRANSMOGRIFY_SUCCESS (×N) → TRANSMOG_OUTFITS_CHANGED
```

**Outfit switch:** `ChangeViewedOutfit()` → `VIEWED_TRANSMOG_OUTFIT_CHANGED` → UI re-queries all slots

---

## 10 Most-Used API Calls

| # | Call | Purpose |
|---|---|---|
| 1 | `C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(slot,type,opt)` | Get slot state (THE primary query) |
| 2 | `C_TransmogOutfitInfo.SetPendingTransmog(slot,type,opt,id,dt)` | Set pending appearance |
| 3 | `C_TransmogOutfitInfo.CommitAndApplyAllPending(discount)` | THE APPLY BUTTON |
| 4 | `C_TransmogOutfitInfo.ChangeViewedOutfit(outfitID)` | Preview an outfit |
| 5 | `C_TransmogOutfitInfo.GetOutfitsInfo()` | Get all outfits |
| 6 | `C_TransmogOutfitInfo.AddNewOutfit(name, icon)` | Create outfit |
| 7 | `C_Transmog.GetSlotVisualInfo(transmogLocation)` | Get equipped slot visual |
| 8 | `C_TransmogCollection.GetSourceInfo(sourceID)` | Look up IMA details |
| 9 | `C_TransmogCollection.GetAppearanceSources(visualID)` | Get all sources for a visual |
| 10 | `C_TransmogCollection.IsAppearanceHiddenVisual(id)` | Check if hidden appearance |

---

## Server Opcodes (RoleplayCore)

| CMSG | Handler | Purpose |
|---|---|---|
| `CMSG_TRANSMOGRIFY_ITEMS` | `HandleTransmogrifyItems` | Single-item transmog at NPC |
| `CMSG_TRANSMOG_OUTFIT_NEW` (0x3A0044) | `HandleTransmogOutfitNew` | Create outfit |
| `CMSG_TRANSMOG_OUTFIT_UPDATE_INFO` (0x3A0045) | `HandleTransmogOutfitUpdateInfo` | Rename/reicon |
| `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS` (0x3A0047) | `HandleTransmogOutfitUpdateSlots` | Update slot data |
| `CMSG_TRANSMOG_OUTFIT_UPDATE_SITUATIONS` (0x3A0046) | `HandleTransmogOutfitUpdateSituations` | Situation config |

**TransmogBridge**: Client omits head/MH/OH/enchants → addon message fills gaps → deferred finalization.

---

## PR #760 Known Bugs

| Bug | Symptom | Cause |
|---|---|---|
| A | Paperdoll naked on 2nd UI open | Stale ViewedOutfit state |
| B | Old head/shoulder persists | IgnoreMask wrong for undefined slots |
| C | Monster Mantle ghost | Previous shoulder not cleared |
| D | Draenei leg geometry loss | Race-specific hidden/clear issue |
| E | Single-item → full outfit rebuild | HandleTransmogrifyItems syncs to SetEquipmentSet |

---

## API Totals

| Namespace | Functions | Events | Structures |
|---|---|---|---|
| C_Transmog | 7 | 15 | 5 |
| C_TransmogCollection | 83 | 0 | 8 |
| C_TransmogOutfitInfo | 59 | 8 | 11 |
| C_TransmogSets | 40 | 0 | 2 |
| **Total** | **189** | **23** | **24** (+2 shared) |

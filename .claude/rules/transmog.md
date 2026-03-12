# Transmog Rules — Authoritative (retail 66263 packet captures + audit pass 2)

When in conflict with earlier summaries or assumptions, these rules win.

## Two Separate DisplayType Concepts — Never Confuse Them

1. **DB2 `ItemAppearance.DisplayType`** (range 0-15): Per-IMAID classification for slot routing. Used in `DisplayTypeToEquipSlot()`. This is the *routing* DT.
2. **`TransmogOutfitSlotData::AppearanceDisplayType`** (range 0-4): Per-slot behavioral flag in ViewedOutfit/TransmogOutfits UpdateFields. This is the *behavioral* ADT.

Never use routing DT values where behavioral ADT values belong, or vice versa.

## Non-Negotiable Rules

- Do NOT use fake weapon option-0 rows. Real weapon appearance belongs on its selected option row from the retail wire-order arrays.
- Keep stored `TransmogOutfits` semantics separate from live `ViewedOutfit` semantics. They use different ADT values for the same logical state.
- Do NOT remove bridge defer/baseline behavior for slots 2 / 12 / 13 unless direct packet evidence proves it wrong.
- Prefer small surgical patches over broad rewrites.
- Always show an actual unified diff for code-changing tasks.
- Do NOT claim success based only on compile if the behavioral model is wrong.

## 30-Row Slot Layout

30 total rows per outfit: 12 armor (SlotOption=0) + 9 MH options + 9 OH options.

**Armor rows** (TransmogOutfitSlot enum, option=0):
Head(0,0), Shoulder-Primary(1,0), Shoulder-Secondary(2,0), Back(3,0), Chest(4,0), Tabard(5,0), Shirt/Body(6,0), Wrist(7,0), Hands(8,0), Waist(9,0), Legs(10,0), Feet(11,0)

**MH weapon option wire order**: 1, 6, 2, 3, 7, 8, 9, 10, 11
**OH weapon option wire order**: 1, 6, 7, 5, 4, 8, 9, 10, 11

No fake weapon option-0 rows.

## Stored `TransmogOutfits` Behavioral Semantics

| State | ADT | IDT | Notes |
|-------|-----|-----|-------|
| Empty row | 0 | 0 | Unassigned, skip |
| Assigned normal | 1 | 0 | Apply this IMAID |
| Hidden appearance | 3 | 0 | Apply hidden visual IMA (real hidden IMA ID, NOT zero) |
| Enchanted weapon (selected) | 1 | 1 | Real SpellItemEnchantmentID + IDT=1 |
| Paired placeholder (opts 8-11) | 4 | 4 | Bookkeeping only |

## Live `ViewedOutfit` Behavioral Semantics

| State | ADT | IDT | Notes |
|-------|-----|-----|-------|
| Empty/equipped passthrough | 2 | 2 | No outfit appearance — show equipped item or nothing |
| Assigned normal | 1 | 0 | Apply this IMAID (SAME as stored) |
| Hidden appearance | 3 | 0 | Apply hidden visual IMA |
| Enchanted weapon (selected) | 1 | 1 | Real enchant + IDT=1 |
| Paired placeholder (opts 8-11) | 4 | 4 | Not applicable |

**Key difference**: Only EMPTY rows differ — Stored=`0/0`, Viewed=`2/2`. Assigned rows use ADT=1 in BOTH contexts.

## Hidden Appearance IMA IDs (confirmed retail)

77343=shoulder, 77344=head, 77345=cloak, 83202=shirt, 83203=tabard, 84223=belt, 94331=gloves, 104602=chest, 104603=boots, 104604=bracers, 198608=pants

Detection: ItemID-based matching (10 known hidden items from CollectionMgr). Do NOT rely on `ItemDisplayInfoID==0`.

## Required Preservation

- `MainHandOption` / `OffHandOption` are real selected option enums, not booleans.
- `SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED` must remain a full 30-row behavioral slot echo.
- `DisplayTypeToEquipSlot()` must include `case 14: return EQUIPMENT_SLOT_OFFHAND`.
- Bridge defer behavior for slots 2 / 12 / 13 must be preserved.

## Confidence Levels — All HIGH
ADT 0/1 stored, ADT 1 viewed assigned, ADT 2/2 viewed empty, ADT 3 hidden, ADT 4 paired, IDT 1 enchanted — all confirmed via retail packet captures.

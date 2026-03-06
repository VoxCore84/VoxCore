---
description: "Corrective implementation pass on transmog code — patches behavioral model to match retail evidence"
allowed-tools: ["Read", "Edit", "Write", "Bash", "Grep", "Glob"]
---

# Transmog Corrective Implementation Pass

Read the "Transmog UI / Midnight 12.x — Authoritative Rules" section in CLAUDE.md first.
Then inspect the current local state of the files listed below.

## Scope (only these files)

- `src/server/game/Entities/Player/Player.cpp` (primary — `fillOutfitData` lambda, `_SyncTransmogOutfitsToActivePlayerData`)
- `src/server/game/Entities/Player/EquipmentSet.h` (read-only reference for `MainHandOption`/`OffHandOption` fields)
- `src/server/game/Handlers/TransmogrificationHandler.cpp` (read-only unless handler needs adjustment)
- `src/server/game/Server/Packets/TransmogrificationPackets.h` (read-only reference)
- `src/server/game/Server/Packets/TransmogrificationPackets.cpp` (read-only reference)

## The 6 Surgical Changes

All changes are in `Player.cpp`, inside or near `fillOutfitData`. Do them in order.

### Change 1: Add `isStored` parameter to `fillOutfitData` lambda

The root cause of most issues is that one lambda serves both stored `TransmogOutfits` and live `ViewedOutfit` with no context flag.

- Find the lambda signature (approximately line 18045):
  `auto fillOutfitData = [this](auto&& outfitSetter, EquipmentSetInfo::EquipmentSetData const* equipmentSet)`
- Add a `bool isStored` parameter:
  `auto fillOutfitData = [this](auto&& outfitSetter, EquipmentSetInfo::EquipmentSetData const* equipmentSet, bool isStored)`

### Change 2: Update both call sites

- Stored call (inside the TransmogOutfits loop, approximately line 18341):
  `fillOutfitData(transmogOutfitSetter, &equipmentSet.Data);` → `fillOutfitData(transmogOutfitSetter, &equipmentSet.Data, true);`
- Viewed call (ViewedOutfit rebuild, approximately line 18395):
  `fillOutfitData(viewedOutfitSetter, viewedData);` → `fillOutfitData(viewedOutfitSetter, viewedData, false);`

### Change 3: Fix ADT assignment — assigned is ALWAYS ADT=1

Packet capture evidence confirms: assigned rows use ADT=1 in BOTH stored and viewed contexts.
ADT=2 is ONLY for viewed empty/equipped passthrough rows (imaID==0 in viewed context).

Find the behavioral ADT assignment block (approximately lines 18239-18245).
After the previous corrective pass, it currently reads:
```cpp
// CURRENT (wrong — uses isStored ternary for assigned):
displayType = isHidden ? uint8(3) : (isStored ? uint8(1) : uint8(2));

// CORRECT — assigned is always ADT=1 regardless of context:
displayType = isHidden ? uint8(3) : uint8(1);
```

### Change 4: Fix empty row ADT — stored=0, viewed=2

The `isStored` flag now controls EMPTY row behavior instead of assigned row behavior.

Find the block after the bootstrap section where `imaID` is still 0 (the row is empty).
Currently, empty rows default to `displayType=0` for both contexts. This is correct for stored
but wrong for viewed — viewed empty rows need ADT=2/IDT=2 (passthrough).

After the existing ADT assignment block (Change 3), add viewed empty handling:
```cpp
// After the imaID > 0 block, handle empty rows:
// Stored empty = ADT 0/IDT 0 (already the default)
// Viewed empty = ADT 2/IDT 2 (equipped passthrough)
if (imaID == 0 && !isStored)
{
    displayType = uint8(2);
    // illusionDT will also be set to 2 below
}
```

Also ensure the IDT assignment at the end of the row handles this:
- viewed empty (imaID==0, !isStored) => IDT=2
- stored empty (imaID==0, isStored) => IDT=0 (already the default)

The bootstrap-from-equipped block (approximately lines 18206-18219) should still only run
for viewed outfits (`!isStored` guard from the previous corrective pass). This is correct —
it fills imaID from the equipped item. But even when bootstrap finds nothing (player has no
item in that slot), the viewed empty row still needs ADT=2/IDT=2.

The canary logging block (lines 18221-18232) can remain unconditional — it's diagnostic only.

### Change 5: Fix SlotOption — use wire option index, not visual classification

Find the SlotOption assignment (approximately line 18262):
```cpp
// CURRENT (wrong — puts visual classification 0/1/3 into a structural field):
slotSetter.ModifyValue(&UF::TransmogOutfitSlotData::SlotOption).SetValue(slotOption);

// CORRECT — SlotOption is the wire option index from slotMap:
slotSetter.ModifyValue(&UF::TransmogOutfitSlotData::SlotOption).SetValue(mapping.option);
```

After this change, the entire `slotOption` variable and its computation block (lines 18250-18258) becomes dead code. Remove it.

### Change 6: Fix stamped options — use real option enums, not booleans

Find the stamped option block (approximately lines 18374-18383):
```cpp
// CURRENT (wrong — reduces to boolean 0/1):
uint8 stampedMH = 0, stampedOH = 0;
if (viewedData) {
    if (viewedData->Appearances[EQUIPMENT_SLOT_MAINHAND]) stampedMH = 1;
    if (viewedData->Appearances[EQUIPMENT_SLOT_OFFHAND]) stampedOH = 1;
}

// CORRECT — pass through the real selected option enum from EquipmentSetData:
uint8 stampedMH = 0, stampedOH = 0;
if (viewedData) {
    stampedMH = uint8(viewedData->MainHandOption);
    stampedOH = uint8(viewedData->OffHandOption);
}
```

## After patching

1. **Show unified diff** of all changes
2. **Build** using the repo's working build command. Report the real result.
3. **Self-QA against retail packet evidence** — one line each, mark PASS / FAIL / PATCHED:
   - stored empty rows = ADT=0, IDT=0
   - stored assigned rows = ADT=1
   - viewed empty/passthrough rows = ADT=2, IDT=2 (even when no item equipped)
   - viewed assigned rows = ADT=1 (NOT ADT=2 — same as stored)
   - hidden rows = ADT=3, IDT=0 (both contexts, real hidden IMA IDs)
   - selected enchanted weapon rows = ADT=1, IDT=1
   - paired placeholders for slot 13/14 options 5-8 = ADT=4, IDT=4
   - SlotOption = mapping.option (wire index, not visual class)
   - real stamped MH/OH option enums (not booleans)
   - full 30-row behavioral slot echo preserved
   - no fake weapon option-0 rows
   - bridge defer behavior for slots 2/12/13 preserved
   - bootstrap only runs for viewed context (not stored)

## Do NOT

- Return analysis-only without code changes
- Preserve a wrong local change just because it compiles
- Use ADT=2 for assigned rows in ANY context (ADT=2 is ONLY for viewed empty/passthrough)
- Use `all option > 0 => DT=4` (only paired options 5-8 get DT=4)
- Use fake weapon option-0 rows
- Remove bridge defer behavior for slots 2/12/13
- Broad-refactor anything outside fillOutfitData and the stamped options block
- Reopen secondary shoulder as the main issue
- Touch TransmogrificationHandler.cpp or TransmogrificationPackets.cpp unless a build error requires it

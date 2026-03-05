# Transmog System Audit — Pass 2: Retail 66263 Evidence-Driven QA

**Date**: 2026-03-05
**Build**: 12.0.1.66263 (retail sniffer) / RoleplayCore master
**Evidence standard**: Unless labeled hypothesis/inference, findings are directly observed from retail/live Blizzard server build 66263.

---

## 1. NEW FINDINGS AUDIT

### 1.1 Client Event Flow After CommitAndApplyAllPending

**Confirmed evidence (retail + private comparison)**:
```
SetPendingTransmog (1-N per slot)
  -> CommitAndApplyAllPending(useDiscount=true/false)
    -> HasPendingOutfitTransmogs=true (BOTH retail and private)
    -> VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED (~2-5s)
    -> TRANSMOG_SEARCH_UPDATED
    -> VIEWED_TRANSMOG_OUTFIT_CHANGED (~5-10s after commit)
    -> TRANSMOG_SEARCH_UPDATED [1,1]
```

**Current local implementation**:
The server's wire order in `FinalizeTransmogBridgePendingOutfit()` (`TransmogrificationHandler.cpp:890`) is:
1. `SetEquipmentSet()` -> `_SyncTransmogOutfitsToActivePlayerData()` -> `SendUpdateToPlayer()` **(FIRST flush — delivers ViewedOutfit UpdateFields)**
2. `ApplyTransmogOutfitToPlayer()` -> `SetVisibleItemSlot()` per slot **(dirties item UpdateFields)**
3. `SendUpdateToPlayer()` **(SECOND flush — delivers VisibleItem changes)**
4. `SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED` **(12-byte response packet)**

The client receives **two** `SMSG_UPDATE_OBJECT` packets before the SMSG response:
- First: ViewedOutfit + TransmogOutfits + TransmogMetadata data
- Second: VisibleItem (equipped item display) data
- Then: SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED

**Mismatch**: NO — the ordering is correct. `SendUpdateToPlayer()` happens BEFORE the SMSG response in every handler. The code even has explicit comments documenting why (lines 672-677, 1123-1125).

**`HasPendingOutfitTransmogs=true` after commit**: Confirmed as normal hook timing on BOTH retail and private. Not a bug.

**`TRANSMOGRIFY_SUCCESS` / `TRANSMOGRIFY_UPDATE` never firing**: Confirmed. These are legacy single-item events, not used in the 12.x outfit-based flow. The practical confirmation path is ViewedOutfit UpdateField changes -> `VIEWED_TRANSMOG_OUTFIT_CHANGED`.

**Confidence**: HIGH

---

### 1.2 TRANSMOG_COLLECTION_UPDATED Over-Firing

**Confirmed evidence**: Retail fires once, private fires 55 times with args `[nil, nil, nil, nil]`, always followed by `TRANSMOG_SETS_UPDATE_FAVORITE`.

**Current local implementation**: Two mechanisms can trigger `TRANSMOG_COLLECTION_UPDATED`:

| Mechanism | Trigger | Guard | Risk |
|-----------|---------|-------|------|
| **Explicit packet** `SMSG_ACCOUNT_TRANSMOG_UPDATE` | Login (1x), favorite toggle | State-based early-return | Low — max 2 per login |
| **Explicit packet** `SMSG_ACCOUNT_TRANSMOG_SET_FAVORITES_UPDATE` | Login (1x), set favorite toggle | State-based early-return | Low — max 2 per login |
| **UpdateField changes** via `SMSG_UPDATE_OBJECT` | Any write to `ActivePlayerData::Transmog`, `::ConditionalTransmog`, `::TransmogIllusions` while `IsInWorld()` | None | **HIGH — likely culprit** |

**Root cause analysis**: During login, `_LoadInventory` (`Player.cpp:19716`) and `_LoadQuestStatusRewarded` (`Player.cpp:20284-20293`) both call `AddItemAppearance()` which writes to the `Transmog` bitfield. These run while `IsInWorld()==false` (batched into initial create). BUT:

The 55 fires happen at **runtime**, not login. The most likely path is `_SyncTransmogOutfitsToActivePlayerData()` being called multiple times — it runs on every `SetEquipmentSet()` call, which triggers from:
- `HandleTransmogOutfitNew()` (line 666)
- `HandleTransmogOutfitUpdateSlots()` / `FinalizeTransmogBridgePendingOutfit()` (line 1112)
- `HandleTransmogOutfitUpdateSituations()` (line 1183)
- `HandleTransmogrifyItems()` (line 612) — single-item sync
- `EffectEquipTransmogOutfit()` (SpellEffects.cpp:6029)

Each call sends a full `SMSG_UPDATE_OBJECT` containing changed `ActivePlayerData` fields. If the client fires `TRANSMOG_COLLECTION_UPDATED` on ANY `ActivePlayerData` change in `SMSG_UPDATE_OBJECT` (not just the Transmog bitfield specifically), then every `_SyncTransmogOutfitsToActivePlayerData` flush would trigger it.

**Mismatch**: YES — P1 over-firing. See Bug #2 in Section 2.

**Confidence**: HIGH (mechanism identified, exact trigger path needs packet-level confirmation)

---

### 1.3 Weapon Option Mapping Refinement

**Confirmed evidence (private server + partial retail)**:

| Slot | Option | Count (Private) | Count (Retail) | Meaning |
|------|--------|-----------------|----------------|---------|
| MH | 1 | 48 | 0 | 1H weapon (OptionEnum=1) |
| MH | 2 | 1 | 1 | 2H weapon (OptionEnum=2) |
| MH | 8 | 29 | 0 | Paired slot (OptionEnum=8, Flags=2) |
| OH | 4 | 1 | 0 | Off Hand (OptionEnum=4) |
| OH | 5 | 19 | 0 | Shield (OptionEnum=5) |

**DB2 verification of option=8 representative IMAIDs** (76538, 76823, 76829, 76834, 76837, 80757, 80758, 80759):
- ALL resolve to **ItemID 128942 "Ulthalesh, the Deadwind Harvester"** (Affliction Warlock artifact staff)
- ALL have **ItemAppearance.DisplayType = 11** (Main-Hand Weapon)
- These are the 8 artifact appearance variants of the same staff

**OptionEnum=8 meaning**: TransmogOutfitSlotOption DB2 shows OptionEnum=8 has `Flags=2` and `OtherSlot=15` for MH (cross-referencing OH ID 15). These are **paired weapon slots** — the client's mechanism for coordinating MH+OH transmog together (e.g., 2H weapons that hide the OH). Null names confirm they are internal bookkeeping, not user-visible categories.

**Current local implementation**: The Option field from CMSG byte[1] is:
- Extracted and stored in `TransmogOutfitUpdateSlots::Read()` (line 516)
- **NOT extracted** in `TransmogOutfitNew::Read()` at all
- **Only used in debug log messages** — never for routing, filtering, or storage
- Routing is 100% via `DisplayTypeToEquipSlot(serverDT)` — completely Option-agnostic

In `fillOutfitData()`, weapon options 1-8 always emit `IMAID=0, AppearanceDisplayType=0` (placeholder entries). Only option=0 (base) carries the actual weapon IMAID. This is correct — the server stores one IMAID per equipment slot.

**Mismatch**: PARTIAL — see Bugs #3 and #4 in Section 2.

**Confidence**: HIGH for routing correctness, MEDIUM for option-number-to-OptionEnum mapping

---

### 1.4 Secondary Shoulder Follow-Up

**Confirmed evidence (private server)**: 13 occurrences, always type=0/option=0, IMAIDs include 77343 (confirmed: "Hidden Shoulder", `ItemDisplayInfoID=0`, `DisplayType=1`).

**Current local implementation — all 4 code paths are correct**:

| Path | Location | Behavior | Status |
|------|----------|----------|--------|
| **CMSG parser** | `TransmogrificationPackets.cpp:552-563` | `ordinal==3 && equipSlot==SHOULDERS` -> `SecondaryShoulderApparanceID` (first non-zero wins) | SAFE |
| **fillOutfitData** | `Player.cpp:18149-18152` | `db2SlotInfoID==3` reads from `SecondaryShoulderApparanceID`, not `Appearances[2]` | CORRECT |
| **TransmogBridge** | `TransmogrificationHandler.cpp:936-957` | `clientSlot==2` intercepted before `MapClientSlotToEquipSlot`, goes to dedicated field | CORRECT |
| **Single-item transmog** | `TransmogrificationHandler.cpp:536-543` | Syncs to active outfit's `SecondaryShoulderApparanceID` | CORRECT |

**Triple-overwrite risk**: ELIMINATED. Primary (db2SlotInfoID=2) and secondary (db2SlotInfoID=3) read from different data fields and write to different UpdateField entries. The `ordinal==3` check is evaluated first in the if/else chain.

**IgnoreMask gap**: BENIGN. CMSG parsers don't check `SecondaryShoulderApparanceID` when computing IgnoreMask, but all 3 downstream consumers repair it:
1. `fillOutfitData` (Player.cpp:18124-18126)
2. `FinalizeTransmogBridgePendingOutfit` (TransmogrificationHandler.cpp:1099-1100)
3. `ValidateTransmogOutfitSet` (TransmogrificationHandler.cpp:131-132)

**Bootstrap exclusion**: CORRECT. `db2SlotInfoID != 3` guard prevents stale bootstrap data from leaking.

**Mismatch**: NO — secondary shoulder handling is architecturally sound.

**Confidence**: HIGH

---

### 1.5 Hotfix / Content Pipeline Findings

**Confirmed evidence (retail 66263 hotfix corpus)**:

| Table | Retail Records | Action |
|-------|---------------|--------|
| TransmogHoliday | 3,667 (3,653 INVALID) | Holiday-gates transmog appearances |
| ItemModifiedAppearanceExtra | 153 DELETE | Blizzard actively cleaning up |
| TransmogSet | 11 (10 VALID, 1 NOTPUBLIC) | RecID 5335 marked not-public |
| TransmogSetItem | 6 (2 DELETE, 4 VALID) | Set composition changes |
| CollectableSourceVendorSparse | 733 VALID | Vendor source data |
| CollectableSourceVendor | 733 VALID | Vendor source data |
| CollectableSourceInfo | 73 VALID | Source info |
| ItemModifiedAppearance | 153 VALID | New appearances |
| ItemAppearance | 54 VALID | New appearance visuals |

**Current local implementation**:

- **TransmogHoliday validation**: DOES NOT EXIST. The `RequiredTransmogHoliday` field exists in `ItemSparseEntry` but is **never read** in any transmog handler or collection manager. Holiday-gated items can be transmogged anytime. MySQL hotfixes table exists but has 0 rows.

- **ItemModifiedAppearanceExtra DELETE handling**: DOES NOT EXIST. MySQL table exists with 0 rows. Retail's 153 DELETEs are not replicated. Base DBC records remain active. Only used in CriteriaHandler for weapon subclass overrides.

- **NOTPUBLIC TransmogSet filtering**: DOES NOT EXIST. `TransmogSet.Flags` is never inspected anywhere. All sets (including potentially non-public ones) are treated identically.

**Mismatch**: YES — multiple data gaps. See Bugs #6-8 in Section 2.

**Confidence**: HIGH

---

### 1.6 Missing Hotfix / DB2 Tables for Full UI Support

**Audit results for each table**:

| Table | DB2 Store | C++ Struct | MySQL Table | Rows | Runtime Usage | Impact |
|-------|-----------|-----------|-------------|------|---------------|--------|
| **TransmogHoliday** | YES | YES | YES (0 rows) | 0 | **NONE** (loaded, never queried) | Holiday gating missing |
| **TransmogSetGroup** | YES | YES | YES (0 rows) | 0 | Minimal (criteria only) | Set grouping UI may be wrong |
| **TransmogIllusion** | YES | YES | YES (0 rows) | 0 | **FULL** (validation, collection, spells) | Working from base DBC |
| **TransmogDefaultLevel** | NO (metadata only) | NO | NO | N/A | NONE | Client-side only |
| **CollectableSourceVendor[Sparse]** | NO | NO | NO | N/A | NONE (UpdateFields only) | Client-side source display |
| **CollectableSourceInfo** | NO | NO | NO | N/A | NONE | Client-side source display |
| **ItemModifiedAppearanceExtra** | YES | YES | YES (0 rows) | 0 | PARTIAL (criteria only) | Missing DELETE handling |

**Key finding**: `TransmogDefaultLevel` is entirely client-side (controls which expansion's default appearances show based on player level). The `CollectableSource*` tables are also client-side (wardrobe source display). Neither causes server-side bugs.

`TransmogIllusion` is the most important — fully used at runtime for validation, collection, and spells. It works from the base DBC file (90 records), so the 0 hotfix rows are not a problem unless retail hotfixes added/changed illusions.

**Mismatch**: PARTIAL — see Section 5 for detailed analysis.

**Confidence**: HIGH

---

### 1.7 Cross-Faction / Cross-Race Wardrobe Check

**Confirmed evidence**: Retail CVars `wardrobeShowAllFactions=1`, `wardrobeShowAllRaces=1`.

**Current local implementation**: The `CanAddAppearance()` function (`CollectionMgr.cpp:691`) performs these checks:
1. Valid `ItemModifiedAppearanceEntry` exists
2. `TransmogSourceTypeEnum` not 6 or 9
3. `ItemSearchName` record exists
4. `ItemTemplate` exists
5. Not flagged `NO_SOURCE_FOR_ITEM_VISUAL`, not artifact quality
6. Valid weapon/armor subclass and inventory type
7. Not already known

**Notably absent**: No race mask check, no class mask check, no faction check. The server's wardrobe is completely faction/race/class-agnostic for collection purposes.

**Mismatch**: NO — this is correct. Since the Warband update (11.0), the wardrobe is fully account-wide. The CVars control client-side UI filtering only.

**Confidence**: HIGH

---

### 1.8 Addon Bug — TransmogSpy Lua Syntax Error

**Confirmed evidence**: Report of `TransmogSpy.lua:1184: '=' expected near 'continue'`.

**Current local implementation**: `TransmogSpy.lua` (1,339 lines) **already uses correct Lua control flow**. The `CmdItems()` function at line 1199 uses `goto next_slot` with `::next_slot::` labels — the proper Lua 5.2+ pattern for continue-like behavior. No instance of the bare `continue` keyword exists in the file.

**Mismatch**: NO — the bug was already fixed. The reported error is stale.

**Confidence**: HIGH

---

### 1.9 DisplayType Reconciliation

**Two completely separate concepts confirmed**:

#### Concept A: `ItemAppearance.DisplayType` (DB2, range 0-15)
Per-IMAID classification identifying the equipment slot category. Used for routing in `DisplayTypeToEquipSlot()`. Values 0-12 are weapon/armor categories.

#### Concept B: `TransmogOutfitSlotData::AppearanceDisplayType` (UpdateField, range 0-4 in retail)
Per-slot behavioral flag in ViewedOutfit telling the client what action to take.

**What our code actually emits for Concept B**:

| Value | When Emitted | Description |
|-------|-------------|-------------|
| **0** | `imaID == 0` | Unassigned — skip slot |
| **1** | `imaID > 0` | Assigned — apply this appearance |
| **never** | — | DT=2 (passthrough) never emitted |
| **never** | — | DT=3 (hidden) never emitted despite comment at line 18193 |
| **never** | — | DT=4 (not applicable) never emitted |

**Retail uses DT=3 for hidden appearances** (head=77344, shoulder=77343, tabard=83203, shirt=83202, back=77345). Our code sends DT=1 for these since `imaID > 0`. Whether the client requires DT=3 or tolerates DT=1 for hidden IMAIDs is unverified.

**Retail uses DT=4 for weapon option entries 8-11** (not applicable). Our code sends DT=0 for all weapon option placeholders.

**Reconciling the two conflicting interpretation tables**:

| DT Value | "Newer capture" interpretation | "Earlier analysis" interpretation | Code-confirmed meaning | Status |
|----------|-------------------------------|----------------------------------|----------------------|--------|
| 0 | — | empty/unset | Unassigned/skip | **CONFIRMED** |
| 1 | normal transmog | normal | Assigned, apply appearance | **CONFIRMED** |
| 2 | clear/hide with IMAID=0 | passthrough (use equipped) | Not emitted by our code | **INFERRED** |
| 3 | ensemble/cosmetic hidden | hidden | Not emitted; comment-only | **INFERRED** (retail uses for hidden IMA items) |
| 4 | — | not applicable | Not emitted | **INFERRED** (retail uses for weapon option placeholders) |

**Mismatch**: YES — see Bugs #5 in Section 2.

**Confidence**: HIGH for DT 0/1. MEDIUM for DT 2/3/4 (retail behavior observed but our code doesn't emit them; client tolerance unknown).

---

## 2. NEW BUG / IMPROVEMENT LIST

### Bug #1 — P2: DT=14 Unhandled in DisplayTypeToEquipSlot

**Location**: `TransmogrificationPackets.cpp:94-115`, `DisplayTypeToEquipSlot()`
**What retail expects**: DT=14 items (41 ItemAppearances in DB2 — likely holdable off-hand items like orbs/tomes) should route to `EQUIPMENT_SLOT_OFFHAND`.
**What local code does**: `default: return EQUIPMENT_SLOT_END` — silently drops these items.
**Why it matters**: Any transmog with DT=14 IMAID in a CMSG is silently discarded. Players cannot apply holdable off-hand transmog appearances.
**Minimal fix**: Add `case 14: return EQUIPMENT_SLOT_OFFHAND;` to the switch.
**Confidence**: HIGH

### Bug #2 — P1: TRANSMOG_COLLECTION_UPDATED Over-Firing (55x vs 1x)

**Location**: `Player.cpp:18346-18351` (`_SyncTransmogOutfitsToActivePlayerData` flush) + every caller of `SetEquipmentSet()`
**What retail does**: Fires `TRANSMOG_COLLECTION_UPDATED` once per session.
**What local code does**: Every `_SyncTransmogOutfitsToActivePlayerData()` call that runs while `IsInWorld()==true` sends an `SMSG_UPDATE_OBJECT` containing `ActivePlayerData` changes. If the client fires `TRANSMOG_COLLECTION_UPDATED` on any `ActivePlayerData` change (not just the Transmog bitfield), each flush triggers it.
**Why it matters**: 55 unnecessary collection refreshes cause UI flicker, extra churn, and potential performance impact on the client's wardrobe rendering.
**Minimal fix**: Two options:
1. **Throttle**: Add a dirty flag + timer to batch `_SyncTransmogOutfitsToActivePlayerData` flushes (e.g., coalesce within 500ms).
2. **Separate update masks**: Ensure ViewedOutfit/TransmogOutfit changes don't dirty the same update block as the Transmog collection bitfield. This may require deeper UpdateField plumbing.
3. **Investigate**: Capture packet log and count exactly which `SMSG_UPDATE_OBJECT` packets contain Transmog bitfield changes vs just ViewedOutfit changes, to confirm the trigger path.
**Confidence**: HIGH (mechanism identified), MEDIUM (exact trigger needs packet-level confirmation)

### Bug #3 — P2: slotMap Option Numbers Don't Match DB2 OptionEnum Values

**Location**: `Player.cpp:18076-18110`, `fillOutfitData()` slotMap
**What retail expects**: The `SlotOption` value in ViewedOutfit entries should match TransmogOutfitSlotOption.OptionEnum from DB2.
**What local code does**: Uses sequential indices 1-8 that don't match OptionEnum values. Example:

| slotMap option | Comment | DB2 OptionEnum | DB2 Name |
|---------------|---------|---------------|----------|
| 1 | "One-Handed Weapon" | 1 | One Handed Weapon |
| 2 | "Two-Handed Weapon" | **6** | **Dagger** |
| 3 | "Ranged Weapon" | **2** | **Two Handed Weapon** |
| 4 | "Two-Handed (Fury)" | **3** | **Ranged Weapon** |
| 5 | "paired 8" | **7** | Two Handed Weapon (Fury) |

**Why it matters**: If the client cross-references SlotOption with its local TransmogOutfitSlotOption DB2, weapon type labels in the UI would be wrong. MH option 2 should be Dagger (OptionEnum=6), not "Two-Handed Weapon". Also, MH skips OptionEnum=6 (Dagger) entirely.
**Minimal fix**: Replace sequential indices with actual DB2 OptionEnum values:
- MH: 1, 6, 2, 3, 7, 8, 9, 10, 11 (9 options, matching DB2 ID order)
- OH: 1, 6, 7, 5, 4, 8, 9, 10, 11 (9 options, matching DB2 ID order)
**Confidence**: HIGH

### Bug #4 — P3: CMSG_TRANSMOG_OUTFIT_NEW Does Not Extract Option Field

**Location**: `TransmogrificationPackets.cpp:260-301`, `TransmogOutfitNew::Read()`
**What retail sends**: byte[1] contains the weapon option OptionEnum value.
**What local code does**: Never extracts byte[1]. The Option field is simply not read.
**Why it matters**: Currently benign because routing is 100% DisplayType-based. But if future logic needs to distinguish weapon sub-types (e.g., for paired slot coordination), this data is lost.
**Minimal fix**: Add `slot.Option = slot.RawBytes[1];` matching the pattern in `TransmogOutfitUpdateSlots::Read()`.
**Confidence**: LOW urgency (routing works without it)

### Bug #5 — P1: AppearanceDisplayType Never Emits DT=3 (Hidden) or DT=4 (Not Applicable)

**Location**: `Player.cpp:18190-18194`, `fillOutfitData()`
**What retail does**:
- Hidden appearances (head=77344, shoulder=77343, etc.): Emits DT=3 with the real hidden IMA ID
- Weapon option placeholders (options 8-11): Emits DT=4
**What local code does**:
- Hidden appearances: Emits DT=1 (treated same as normal appearance since `imaID > 0`)
- Weapon option placeholders: Emits DT=0
**Why it matters**: The client may interpret DT=1 + hidden-IMA differently than DT=3 + hidden-IMA. If the client specifically checks for DT=3 to render the "hidden" state, our hidden transmogs may display incorrectly. Similarly, DT=4 signals "not applicable" for weapon type options the character can't use.
**Minimal fix**:
```cpp
// For hidden appearances:
uint8 displayType;
if (imaID == 0)
    displayType = 0;
else if (IsHiddenTransmogAppearance(imaID))  // check ItemDisplayInfoID == 0
    displayType = 3;
else
    displayType = 1;

// For weapon option placeholders (option > 0):
// Change DT from 0 to 4 for options corresponding to OptionEnum 8-11
```
**Confidence**: MEDIUM (retail behavior observed but client tolerance of DT=1 for hidden items is unverified)

### Bug #6 — P3: TransmogHoliday Validation Missing

**Location**: `TransmogrificationHandler.cpp` (absent), `CollectionMgr.cpp` (absent)
**What retail does**: Holiday-gated appearances (3,667 records, 14 base DBC entries) require active holiday events.
**What local code does**: `RequiredTransmogHoliday` field in `ItemSparseEntry` is loaded but never checked. Any appearance can be transmogged anytime.
**Why it matters**: Minor — roleplay server may intentionally allow this. But it deviates from retail behavior.
**Minimal fix**: Add holiday check in `ValidateTransmogOutfitSet()` or `CanTransmogrifyItemWithItem()`.
**Confidence**: HIGH (missing code confirmed), LOW urgency (RP server may want this)

### Bug #7 — P3: ItemModifiedAppearanceExtra DELETE Hotfixes Not Applied

**Location**: `hotfixes.item_modified_appearance_extra` (0 rows)
**What retail does**: 153 DELETE records actively suppress certain appearance extras.
**What local code does**: Base DBC records remain active. Only used in criteria weapon subclass checks.
**Why it matters**: Minor — affects achievement criteria for weapon type tracking. Some weapon subclass overrides that Blizzard removed would still be active.
**Minimal fix**: Import retail hotfix DELETE records into the MySQL table.
**Confidence**: HIGH (gap confirmed), LOW urgency

### Bug #8 — P3: TransmogSet NOTPUBLIC Filtering Missing

**Location**: `DB2Stores.cpp:1698` (`_transmogSetsByItemModifiedAppearance` index), `CollectionMgr.cpp:661` (`IsSetCompleted`)
**What retail does**: TransmogSet records with NOTPUBLIC status (RecID 5335 "Scorching Conqueror") are excluded from user-visible UI.
**What local code does**: `TransmogSet.Flags` is never inspected. All sets treated identically.
**Why it matters**: Minor — unreleased or test sets may appear in the wardrobe UI.
**Minimal fix**: Filter sets by flags when building `_transmogSetsByItemModifiedAppearance` or in `IsSetCompleted()`.
**Confidence**: MEDIUM (NOTPUBLIC semantics unclear from Flags field alone)

---

## 3. RESPONSE-PATH ANALYSIS

### What causes VIEWED_TRANSMOG_OUTFIT_CHANGED?

**Answer**: Changes to the `ActivePlayerData::ViewedOutfit` UpdateField delivered via `SMSG_UPDATE_OBJECT`.

**Server-side trigger chain**:
```
SetEquipmentSet()
  -> _SyncTransmogOutfitsToActivePlayerData()
    -> Clears ViewedOutfit.Slots + ViewedOutfit.Situations
    -> fillOutfitData() repopulates 30 slot entries
    -> SendUpdateToPlayer() flushes SMSG_UPDATE_OBJECT
      -> Client detects ViewedOutfit change
        -> Fires VIEWED_TRANSMOG_OUTFIT_CHANGED
```

### What causes VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED?

**Answer**: Changes to `ViewedOutfit.Situations[]` in the same `SMSG_UPDATE_OBJECT`.

**Server-side trigger chain**:
```
HandleTransmogOutfitUpdateSituations()
  -> SetEquipmentSet() (updates situations in DB)
    -> _SyncTransmogOutfitsToActivePlayerData()
      -> fillOutfitData() repopulates Situations[] array
      -> SendUpdateToPlayer() flushes
        -> Client detects Situations change
          -> Fires VIEWED_TRANSMOG_OUTFIT_SITUATIONS_CHANGED
  -> Sends SMSG_TRANSMOG_OUTFIT_SITUATIONS_UPDATED (after flush)
```

### Does our current code drive these correctly?

**YES** — the flush-before-response pattern is correct and explicitly documented in code comments. The wire order is:
1. `SMSG_UPDATE_OBJECT` (ViewedOutfit data)
2. `SMSG_TRANSMOG_OUTFIT_*_UPDATED` (response packet)

This ensures the client has fresh UpdateField data when the response event fires.

### What about TRANSMOG_SEARCH_UPDATED?

**Entirely client-side.** The server does not directly trigger this. The client re-runs wardrobe search filters internally after receiving appearance data changes.

---

## 4. COLLECTION-UPDATE ANALYSIS

### Why is the private server over-firing TRANSMOG_COLLECTION_UPDATED?

**Root cause**: Every `_SyncTransmogOutfitsToActivePlayerData()` call that runs while `IsInWorld()==true` sends an `SMSG_UPDATE_OBJECT` packet. The client likely fires `TRANSMOG_COLLECTION_UPDATED` whenever it receives an `SMSG_UPDATE_OBJECT` containing changes to `ActivePlayerData` fields that include the transmog collection or related fields.

### Exact send paths

| # | Caller | File:Line | Trigger | Flushes SMSG_UPDATE_OBJECT |
|---|--------|-----------|---------|---------------------------|
| 1 | `HandleTransmogOutfitNew` | TransmogrificationHandler.cpp:666 | Create outfit | YES (via SetEquipmentSet + explicit flush) |
| 2 | `HandleTransmogOutfitUpdateInfo` | TransmogrificationHandler.cpp:721 | Rename/re-icon outfit | YES |
| 3 | `FinalizeTransmogBridgePendingOutfit` | TransmogrificationHandler.cpp:1112 | Apply outfit slots | YES (2x flush) |
| 4 | `HandleTransmogOutfitUpdateSituations` | TransmogrificationHandler.cpp:1183 | Update situations | YES |
| 5 | `HandleTransmogrifyItems` | TransmogrificationHandler.cpp:612 | Single-item transmog | YES |
| 6 | `ActivateTalentGroup` | Player.cpp:29711 | Spec change | YES |
| 7 | `DeleteEquipmentSet` | Player.cpp:29103 | Delete outfit | YES |
| 8 | `EffectEquipTransmogOutfit` | SpellEffects.cpp:6029 | Spell-based outfit apply | YES |
| 9 | `spell_clear_current_transmogrifications` | spell_clear_transmog.cpp:99 | Clear All | YES |
| 10 | `SendFavoriteAppearances` | CollectionMgr.cpp:897 | Login (1x) | Explicit SMSG_ACCOUNT_TRANSMOG_UPDATE |
| 11 | `SendTransmogSetFavorites` | CollectionMgr.cpp:985 | Login (1x) | Explicit SMSG_ACCOUNT_TRANSMOG_SET_FAVORITES_UPDATE |

### How to guard them safely

**Option A — Separate update tracking**: Split the `SendUpdateToPlayer()` flush so that ViewedOutfit/TransmogOutfits changes go in a different update block than the Transmog collection bitfield. This prevents ViewedOutfit refreshes from triggering collection events.

**Option B — Coalesce flushes**: Add a `_transmogUpdateDirty` flag and timer. Instead of flushing immediately in `_SyncTransmogOutfitsToActivePlayerData()`, mark dirty and flush once at the end of the current handler chain (or on next world update tick).

**Option C — Investigate first**: Capture a full packet log and determine exactly which `SMSG_UPDATE_OBJECT` packets contain `ActivePlayerData::Transmog` bitfield changes vs just ViewedOutfit changes. If the 55 fires all come from ViewedOutfit flushes that happen to share the same update mask, Option A is the right fix. If they come from actual collection changes during login, the loading order needs review.

**Recommended**: Option C first (investigate), then Option A or B based on findings.

---

## 5. HOTFIX / DATA-PIPELINE ANALYSIS

### TransmogHoliday validation exists?
**NO.** `RequiredTransmogHoliday` field is loaded into `ItemSparseEntry` but never read at runtime. Holiday-gated appearances have no server-side enforcement.

### ItemModifiedAppearanceExtra delete handling exists?
**NO.** MySQL table exists but has 0 rows. Retail's 153 DELETE records are not replicated. Base DBC records remain active. Impact limited to criteria/achievement weapon subclass checks.

### TransmogSetGroup present?
**YES.** Fully loaded, used in criteria tracking (`CriteriaType::CollectTransmogSetFromGroup`). MySQL table has 0 rows (uses base DBC data). Wago has 268 records. Functional.

### TransmogIllusion present?
**YES.** Fully loaded and actively used: validation, collection, spell learning, login auto-grant. MySQL table has 0 rows (uses base DBC of 90 records). This is the most critical table and it works.

### TransmogDefaultLevel present?
**NO** (metadata only, no runtime struct). This is client-side only — controls which expansion's default appearances show based on player level conditions. Not needed server-side.

### CollectableSource* tables present?
**NO.** These are client-side wardrobe source display tables (new in 12.x). The server has `TrackedCollectableSources` UpdateField plumbed but no logic populates it. Not needed for transmog functionality — only affects "where does this drop from?" tooltips.

### Is any missing table causing UI incompleteness?
**UNLIKELY for core transmog.** The tables that matter most (TransmogIllusion, TransmogSetGroup, TransmogSet) are all loaded and functional from base DBC data. The missing tables affect:
- Holiday gating (TransmogHoliday) — P3, RP server may not want this
- Source tooltips (CollectableSource*) — client-side only
- Default level gating (TransmogDefaultLevel) — client-side only
- Appearance extra cleanup (ItemModifiedAppearanceExtra) — criteria edge cases only

The UI incompleteness issues are more likely caused by the SMSG protocol mismatch (12-byte vs 488-byte response) and missing DT=3/4 values identified in Pass 1 and this audit.

---

## 6. DISPLAYTYPE RECONCILIATION

### Confirmed meanings (code + evidence)

| DT Value | Concept B (ViewedOutfit) Meaning | Our Code Emits? | Retail Emits? | Confidence |
|----------|--------------------------------|-----------------|---------------|------------|
| **0** | Unassigned — slot not in outfit, skip | YES | YES | **CONFIRMED** |
| **1** | Assigned — apply this specific appearance | YES | YES | **CONFIRMED** |
| **2** | Passthrough — use equipped appearance | NO | YES (inferred) | **INFERRED** — never observed directly in our sniffer analysis with certainty |
| **3** | Hidden — apply hidden-style visual (requires real hidden IMA ID) | NO (comment only) | YES (observed: head=77344, shoulder=77343, back=77345, shirt=83202, tabard=83203) | **HIGH CONFIDENCE** from retail sniffer |
| **4** | Not applicable — weapon option placeholder for inapplicable weapon types | NO | YES (observed on weapon options 8-11) | **HIGH CONFIDENCE** from retail sniffer |

### Concept A (DB2 DisplayType 0-15) — no reconciliation needed

This is a completely separate field (`ItemAppearance.DisplayType`) used for routing IMAIDs to equipment slots. Values 0-15 are well-defined in `DisplayTypeToEquipSlot()`. The only gap is **DT=14 (holdable off-hand)** which is unhandled and silently dropped.

### Should local code log/reject/normalize ambiguous DT values?

**Recommendation**:
1. **Emit DT=3** for hidden appearances — detect via `ItemDisplayInfoID == 0` on the ItemAppearance record
2. **Emit DT=4** for weapon option placeholder entries (options corresponding to OptionEnum 8-11, the paired slots)
3. **Log warning** if an unexpected DT value (>4) appears in CMSG data — this would indicate a protocol change
4. **Do NOT clamp/normalize** incoming CMSG DT values — use server-side DB2 lookup (`GetServerDisplayType()`) as the authoritative source for routing, which already happens

---

## PRIORITY SUMMARY

| # | Bug | Severity | Category | Immediate Action |
|---|-----|----------|----------|-----------------|
| 1 | DT=14 unhandled in DisplayTypeToEquipSlot | P2 | Protocol | Add `case 14:` |
| 2 | TRANSMOG_COLLECTION_UPDATED 55x over-fire | P1 | Performance | Investigate packet-level trigger, then coalesce |
| 3 | slotMap option numbers vs DB2 OptionEnum | P2 | Protocol | Replace with real OptionEnum values |
| 4 | CMSG_TRANSMOG_OUTFIT_NEW missing Option parse | P3 | Protocol | Add byte[1] extraction |
| 5 | AppearanceDisplayType never emits DT=3/4 | P1 | Protocol | Add hidden detection + DT=4 for placeholders |
| 6 | TransmogHoliday validation missing | P3 | Content | Add holiday check (or decide to skip for RP) |
| 7 | ItemModifiedAppearanceExtra DELETEs missing | P3 | Content | Import retail hotfix data |
| 8 | TransmogSet NOTPUBLIC filtering missing | P3 | Content | Filter by flags |

**Critical path**: Bugs #2, #3, #5 are the highest-impact items. Bug #2 causes visible UI churn. Bug #5 may cause incorrect hidden-item rendering. Bug #3 may cause wrong weapon type labels.

---

## APPENDIX A: TransmogOutfitSlotInfo DB2 Reference

| ID | TransmogOutfitSlotEnum | InventorySlotEnum | Name |
|----|----------------------|-------------------|------|
| 1 | 0 | 0 | Head |
| 2 | 1 | 2 | Shoulder (primary) |
| 3 | 2 | 2 | Shoulder (secondary) |
| 4 | 6 | 3 | Shirt |
| 5 | 4 | 4 | Chest |
| 6 | 9 | 5 | Waist |
| 7 | 10 | 6 | Legs |
| 8 | 11 | 7 | Feet |
| 9 | 7 | 8 | Wrist |
| 10 | 8 | 9 | Hands |
| 11 | 3 | 14 | Back |
| 12 | 5 | 18 | Tabard |
| 13 | 12 | 15 | Main Hand |
| 14 | 13 | 16 | Off Hand |

**IMPORTANT**: TransmogOutfitSlotEnum values (0-13) are NOT in the same order as DB2 IDs (1-14). The enum ordering is: Head(0), Shoulder(1,2), Back(3), Chest(4), Tabard(5), Shirt(6), Wrist(7), Hands(8), Waist(9), Legs(10), Feet(11), MH(12), OH(13).

## APPENDIX B: TransmogOutfitSlotOption DB2 Reference

### MH Options (TransmogOutfitSlotInfoID = 13)

| DB2 ID | OptionEnum | Name | Flags | OtherSlot |
|--------|-----------|------|-------|-----------|
| 1 | 1 | One Handed Weapon | 0 | 0 |
| 3 | 6 | Dagger | 0 | 0 |
| 5 | 2 | Two Handed Weapon | 4 | 0 |
| 7 | 3 | Ranged Weapon | 5 | 0 |
| 10 | 7 | Two Handed Weapon (Fury) | 0 | 0 |
| 11 | 8 | *(paired)* | 2 | 15 |
| 12 | 9 | *(paired)* | 2 | 16 |
| 13 | 10 | *(paired)* | 2 | 17 |
| 14 | 11 | *(paired)* | 2 | 18 |

Wire order by DB2 ID: OptionEnum 1, 6, 2, 3, 7, 8, 9, 10, 11

### OH Options (TransmogOutfitSlotInfoID = 14)

| DB2 ID | OptionEnum | Name | Flags | OtherSlot |
|--------|-----------|------|-------|-----------|
| 2 | 1 | One Handed Weapon | 0 | 0 |
| 4 | 6 | Dagger | 0 | 0 |
| 6 | 7 | Two Handed Weapon (Fury) | 0 | 0 |
| 8 | 5 | Shield | 1 | 0 |
| 9 | 4 | Off Hand | 1 | 0 |
| 15 | 8 | *(paired)* | 2 | 11 |
| 16 | 9 | *(paired)* | 2 | 12 |
| 17 | 10 | *(paired)* | 2 | 13 |
| 18 | 11 | *(paired)* | 2 | 14 |

Wire order by DB2 ID: OptionEnum 1, 6, 7, 5, 4, 8, 9, 10, 11

### Paired Slot Cross-References
OptionEnum 8-11 entries have `Flags=2` and cross-reference each other:
- MH OptionEnum=8 (ID 11) ↔ OH OptionEnum=8 (ID 15, OtherSlot=11)
- MH OptionEnum=9 (ID 12) ↔ OH OptionEnum=9 (ID 16, OtherSlot=12)
- MH OptionEnum=10 (ID 13) ↔ OH OptionEnum=10 (ID 17, OtherSlot=13)
- MH OptionEnum=11 (ID 14) ↔ OH OptionEnum=11 (ID 18, OtherSlot=14)

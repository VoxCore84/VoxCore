# VoxCore Transmog Outfit System — Comprehensive Implementation Report

**Date**: March 8, 2026
**Target Client**: WoW 12.x / Midnight (build 66263)
**Purpose**: Standalone reference for a Claude Code session to implement remaining fixes without prior context.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture](#2-architecture)
3. [Retail Behavioral Model (Authoritative)](#3-retail-behavioral-model)
4. [File Map](#4-file-map)
5. [Packet Flow](#5-packet-flow)
6. [TransmogBridge Addon System](#6-transmogbridge-addon-system)
7. [Open Bugs — Priority Order](#7-open-bugs)
8. [Deployed But Unverified Fixes](#8-deployed-unverified)
9. [Implementation Guidance](#9-implementation-guidance)
10. [Testing Procedures](#10-testing)

---

## 1. System Overview

The transmog outfit system enables players to save, load, and manage appearance outfits in the 12.x Midnight client. This is a **complete rewrite** of the transmog architecture from pre-12.x — the old per-slot `C_Transmog.ApplyAllPending()` API no longer exists. Everything now goes through outfits.

### What Works (verified in-game March 1, 2026)
- 14/14 equipment slots via manual click transmog
- 13/14 slots via outfit set loading (secondary shoulder is known gap)
- MH/OH weapon transmog
- Clear All Transmogrifications button (spell 1247917)
- Outfit slot purchase with gold cost
- Server baseline restoration for non-bridge slots

### What's Broken (PR #760 blockers)
- **BUG-F**: SetID mapping destroyed after first outfit apply
- **BUG-G**: Outfit name parsing fails (0x80 pad byte)
- **BUG-H**: Individual slot transmog completely blocked (no CMSG fires)

### What's Untested
- All Bug A-E fixes (deployed March 5, never verified in-game)
- MH enchant illusions (4-field bridge payload)
- Clear single slot (transmogID=0)
- Corrective pass (6 surgical changes to fillOutfitData)

---

## 2. Architecture

```
Client (12.x Midnight)
  └─ Blizzard_Transmog UI
       ├─ CommitAndApplyAllPending() → CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS
       ├─ Spell 1247613 (effect 347) → EffectEquipTransmogOutfit
       ├─ TransmogBridge addon → CHAT_MSG_ADDON "TMOG_BRIDGE"
       └─ TransmogSpy addon → diagnostic logging

Server
  ├─ TransmogrificationHandler.cpp — 4 CMSG handlers + bridge finalize
  ├─ Player.cpp — fillOutfitData, _SyncTransmogOutfitsToActivePlayerData
  ├─ TransmogrificationUtils.cpp — ApplyTransmogOutfitToPlayer (shared)
  ├─ SpellEffects.cpp — EffectEquipTransmogOutfit (spell 347)
  ├─ ChatHandler.cpp — TMOG_BRIDGE addon message intercept
  └─ spell_clear_transmog.cpp — Clear All spell handler
```

### Key Data Structures

**`EquipmentSetData`** (EquipmentSet.h):
- `int32 Appearances[19]` — IMAID per equipment slot
- `int32 Enchants[2]` — MH/OH enchant SpellItemEnchantmentIDs
- `int32 SecondaryShoulderApparanceID` — secondary shoulder IMAID
- `uint32 IgnoreMask` — bitmask of ignored slots
- `uint8 MainHandOption` — weapon type option enum (0-8)
- `uint8 OffHandOption` — weapon type option enum (0-8)

**`TransmogOutfitSlotData`** (UpdateFields):
- `AppearanceID` (int32) — IMAID
- `AppearanceDisplayType` (uint8) — behavioral ADT (0-4)
- `SlotOption` (uint8) — wire option index
- `IllusionDisplayType` (uint8) — behavioral IDT
- `SpellItemEnchantmentID` (int32) — enchant illusion ID

### The ViewedOutfit vs TransmogOutfits Distinction

**TransmogOutfits** (stored): Saved outfit configurations. Multiple per player. Stored = ADT=0 for empty.
**ViewedOutfit** (live): The currently-rendered outfit. One per player. Viewed = ADT=2 for empty (show equipped item).

Both are synced via `_SyncTransmogOutfitsToActivePlayerData()` which calls `fillOutfitData()` with an `isStored` flag.

---

## 3. Retail Behavioral Model (Authoritative)

These values come from retail 66263 packet captures and are HIGH confidence.

### ADT (AppearanceDisplayType) Values

| State | Stored ADT | Stored IDT | Viewed ADT | Viewed IDT |
|-------|-----------|-----------|-----------|-----------|
| Empty/unassigned | 0 | 0 | 2 | 2 |
| Assigned (has IMAID) | 1 | 0 | 1 | 0 |
| Hidden appearance | 3 | 0 | 3 | 0 |
| Enchanted weapon | 1 | 1 | 1 | 1 |
| Paired placeholder (opts 8-11) | 4 | 4 | 4 | 4 |

**Critical**: Assigned rows use ADT=1 in BOTH contexts. ADT=2 is ONLY for viewed empty rows.

### 30-Row Slot Layout

Every outfit has exactly 30 rows:
- 12 armor rows (slot, option=0): Head(0), Shoulder-Primary(1), Shoulder-Secondary(2), Back(3), Chest(4), Tabard(5), Shirt/Body(6), Wrist(7), Hands(8), Waist(9), Legs(10), Feet(11)
- 9 MH weapon options: wire order 1, 6, 2, 3, 7, 8, 9, 10, 11
- 9 OH weapon options: wire order 1, 6, 7, 5, 4, 8, 9, 10, 11

**No fake weapon option-0 rows.** The real weapon appearance goes on its selected option row.

### Hidden Appearance IMA IDs (confirmed retail)

| Slot | ItemID | IMA ID |
|------|--------|--------|
| Head | — | 77344 |
| Shoulder | — | 77343 |
| Cloak | — | 77345 |
| Shirt | — | 83202 |
| Tabard | — | 83203 |
| Belt | — | 84223 |
| Gloves | — | 94331 |
| Chest | — | 104602 |
| Boots | — | 104603 |
| Bracers | — | 104604 |
| Pants | 216696 | 198608 |

Detection: Use ItemID-based matching (10 known hidden items from CollectionMgr).
Do NOT rely on `ItemDisplayInfoID==0` — cloak has `ItemDisplayInfoID=146518`.

### DisplayType Slot Routing (DB2 ItemAppearance.DisplayType)

DT 0=Head, 1=Shoulder, 2=Shirt, 3=Chest, 4=Waist, 5=Legs, 6=Feet, 7=Wrist, 8=Hands, 9=Back, 10=Tabard, 11=MH, 13=Shield→OH, 14=OH, 15=OH

`DisplayTypeToEquipSlot()` maps these to `EQUIPMENT_SLOT_*` constants. Must include `case 14: return EQUIPMENT_SLOT_OFFHAND`.

---

## 4. File Map

### Primary Files (most changes happen here)

| File | Key Functions | Lines |
|------|--------------|-------|
| `src/server/game/Entities/Player/Player.cpp` | `fillOutfitData` (~18045), `_SyncTransmogOutfitsToActivePlayerData` (~18024), `SetVisibleItemSlot` (~12142) | ~20K |
| `src/server/game/Handlers/TransmogrificationHandler.cpp` | `HandleTransmogOutfitNew` (~570), `HandleTransmogOutfitUpdateInfo` (~620), `HandleTransmogOutfitUpdateSlots` (~700), `HandleTransmogOutfitUpdateSituations` (~800), `FinalizeTransmogBridgePendingOutfit` (~1000), `HandleTransmogrifyItems` (172-567, DEAD CODE) | ~1200 |
| `src/server/game/Server/Packets/TransmogrificationPackets.h` | Packet struct definitions | |
| `src/server/game/Server/Packets/TransmogrificationPackets.cpp` | Packet parsers (backward ASCII scan for names) | |

### Supporting Files

| File | Purpose |
|------|---------|
| `src/server/game/Entities/Player/TransmogrificationUtils.h/.cpp` | `ApplyTransmogOutfitToPlayer()` — gold cost + apply appearances |
| `src/server/game/Spells/SpellEffects.cpp` | `EffectEquipTransmogOutfit()` (~line 6003) — spell 347 handler |
| `src/server/scripts/Custom/spell_clear_transmog.cpp` | Clear All Transmogrifications spell handler |
| `src/server/game/Entities/Player/EquipmentSet.h` | `EquipmentSetData` struct definition |
| `src/server/game/Entities/Player/CollectionMgr.cpp` | `SendFavoriteAppearances()` login sync |
| `src/server/game/Handlers/ChatHandler.cpp` | TMOG_BRIDGE addon message intercept |
| `src/server/game/Entities/Player/Player.h` | `_equipmentSets`, `_activeTransmogOutfitID`, bridge state members |

### Client-Side (addon)

| File | Purpose |
|------|---------|
| `C:/WoW/_retail_/Interface/AddOns/TransmogBridge/TransmogBridge.lua` | 3-layer hybrid merge addon |
| `C:/WoW/_retail_/Interface/AddOns/TransmogSpy/TransmogSpy.lua` | Diagnostic addon (17 commands) |

---

## 5. Packet Flow

### Outfit Save (new)
```
Client: CMSG_TRANSMOG_OUTFIT_NEW
  → [NPC PackedGuid][type:u8=1][flags:u8][icon:u32][N * 16-byte slot entries][nameLen:u8][pad:u8=0x80][name]
Server: HandleTransmogOutfitNew → saves to DB, applies outfit
  → SMSG_TRANSMOG_OUTFIT_NEW [SetID:u32 + Guid:u64]
```

### Outfit Rename
```
Client: CMSG_TRANSMOG_OUTFIT_UPDATE_INFO
  → [SetID:u32][NPC PackedGuid][type:u8=1][icon:u32][nameLen:u8][pad:u8=0x80][name]
Server: HandleTransmogOutfitUpdateInfo → updates name/icon
  → SMSG_TRANSMOG_OUTFIT_UPDATE_INFO [SetID:u32 + Guid:u64]
```

### Outfit Apply / Update Slots (MAIN PATH)
```
Client: CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS
  → [SetID:u32][slotCount:u32][NPC PackedGuid][IconFileDataID:u32][pad:u32][N * 16-byte slots][trailing:u8]
Server: HandleTransmogOutfitUpdateSlots
  → Defers to _transmogBridgePendingOutfit (waits for bridge addon data)
  → TransmogBridge addon sends CHAT_MSG_ADDON "TMOG_BRIDGE" with override payload
  → FinalizeTransmogBridgePendingOutfit() merges + validates + saves + applies
  → SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED [full 30-row behavioral slot echo]
```

### Spell Apply (outfit loading from wardrobe)
```
Client: Casts spell 1247613 with MiscValue = SetID
Server: EffectEquipTransmogOutfit()
  → ApplyTransmogOutfitToPlayer() (gold cost + per-slot apply)
  → SetEquipmentSet() → _SyncTransmogOutfitsToActivePlayerData()
```

### Slot Entry Wire Format (16 bytes each)
```
byte[0]  = Sequential ordinal (1-30) — NOT a slot identifier
byte[1]  = Weapon option index (0 for armor, 1-8 for weapon variants)
bytes[2-5]  = AppearanceID (IMAID, uint32 LE)
bytes[6-7]  = ItemAppearance.DisplayType (uint16 LE) — routing key
bytes[8-15] = Reserved (zeros)
```

**Important**: byte[0] is sequential, NOT DB2 TransmogOutfitSlotInfo.ID. Route by DisplayType, not ordinal.

---

## 6. TransmogBridge Addon System

The 12.x client's `CommitAndApplyAllPending()` serializer omits HEAD(DT=0), MH(DT=11), OH(DT=13/15) and sends stale data for other slots. TransmogBridge works around this with a 3-layer hybrid merge:

### Layer 1: ViewedOutfitSlotInfo Snapshot
- `GetViewedOutfitSlotInfo(slot, 0, 0)` — captures outfit-loaded armor slots
- Secondary shoulder: `GetViewedOutfitSlotInfo(1, 0, 1)` → encoded as slot 2
- Returns currently-worn appearance for ALL slots (can be stale)

### Layer 2: SetPendingTransmog Hook (WINS on conflict)
- Captures weapons (12,13), tabard (5), shirt (6), secondary shoulder (2)
- Tagged with `option=1` (FromHook=true on server) — trusted data

### Layer 3: C_Transmog.GetSlotVisualInfo Fallback
- Fills remaining gaps via `TransmogUtil.GetTransmogLocation`
- Uses `pendingSourceID`, falls back to `appliedSourceID`

### Server-Side Stale Rejection
- Layer 1 data (option=0, FromHook=false) is rejected for slots the saved outfit ignores (IMAID=0 + IgnoreMask bit set)
- Prevents false positives where equipped appearance echoes back as outfit data

### Bridge Defer Behavior
Slots 2 (secondary shoulder), 12 (MH), 13 (OH) are in `ALWAYS_NIL_SLOTS` — client serializer never sends them. Server defers to bridge addon data or falls back to saved outfit baseline. **Do NOT remove this behavior.**

### Wire Format
Addon payload: `slot.transmogID.option` (3-field) or `slot.transmogID.option.illusionID` (4-field for weapon enchants).
Multi-part for >255 bytes: `1>data...` then `2>data...`

---

## 7. Open Bugs

Ordered by implementation priority. Full details in `memory/transmog-bugtracker.md`.

### CRITICAL (PR #760 blockers)

**BUG-F: SetID Mapping Destroyed After First Apply**
- After applying outfit once, SetID lookup breaks → "Unknown set id" error
- Needs investigation: trace `_equipmentSets` map in Player.h, check `SetEquipmentSet()` side effects
- File: `TransmogrificationHandler.cpp`

**BUG-G: Name Pad Byte 0x80 Backward ASCII Scan**
- Outfit name parsing fails — 0x80 pad byte confuses backward scanner
- Fix: Use `nameLen` field to extract name instead of backward scan
- File: `TransmogrificationPackets.cpp`

**BUG-H: Individual Slot Transmog Blocked**
- Client never sends `CMSG_TRANSMOGRIFY_ITEMS` in 12.x
- Individual transmog now goes through outfit system
- Needs investigation: does `HandleTransmogOutfitUpdateSlots` handle single-slot changes?

### HIGH

**BUG-H1: Stored Outfit Slots Array Accumulation (30→60→90)**
- Missing `ClearDynamicUpdateFieldValues` for stored outfits in `_SyncTransmogOutfitsToActivePlayerData`
- ViewedOutfit IS cleared (lines ~18390-18391), stored outfits are NOT
- 2-line fix: add clear before `fillOutfitData` call in stored outfit loop
- File: `Player.cpp`

**BUG-M1: Enchant Validation Rejects Entire Outfit**
- One bad enchant → entire outfit rejected. Should zero the bad enchant and continue.
- File: `TransmogrificationHandler.cpp` → `ValidateTransmogOutfitSet`

**BUG-M2: Bridge Loses Illusions**
- Enchant restore coupled to appearance override mask — if weapon slot not in mask, enchant not restored
- File: `TransmogrificationHandler.cpp` → `FinalizeTransmogBridgePendingOutfit`

**BUG-M5: MainHandOption/OffHandOption Never Stored from CMSG**
- byte[1] of slot entries parsed for routing but never stored to EquipmentSetData
- File: `TransmogrificationPackets.cpp`

**BUG-M6: Hidden Pants Missing**
- ItemID 216696 / IMA 198608 not in `hiddenItemIDs[]` array
- File: `Player.cpp` → `fillOutfitData`

**BUG-M9: Illusion Bootstrap Leaks Into Stored Outfits**
- Should be gated by `!isStored` — stored outfits shouldn't pick up equipped illusions
- File: `Player.cpp` → `fillOutfitData`

### MEDIUM
- BUG-M3: HandleTransmogOutfitNew missing bridge defer (needs client verification)
- BUG-M7: EffectEquipTransmogOutfit return value ignored
- BUG-M8: Missing SMSG response after spell-based apply
- BUG-M10: UpdateSlots parser uses heuristic instead of explicit field reads

### LOW
- BUG-L1: ~400 lines dead HandleTransmogrifyItems code
- BUG-L4: spell_clear_transmog doesn't zero all auxiliary fields
- BUG-UNICODE: Unicode names break backward scan (fixed by BUG-G fix)
- BUG-SECONDARY-SHOULDER: 13/14 outfit loading (accepted limitation)

---

## 8. Deployed But Unverified Fixes

These fixes are in the codebase but have never been tested in-game:

| Fix | Commit | What It Does |
|-----|--------|-------------|
| Bug A-E (5 bugs) | `c8df50eddd`, `ab43e4823d`, `289677be44` | Naked paperdoll, stale head/shoulder, ghost appearance, leg geometry, single-item revert |
| MH enchant illusions | `5d38823153` | 4-field bridge payload (slot.transmogID.option.illusionID) |
| Clear single slot | `5d38823153` | transmogID=0 in bridge payload |
| Corrective pass | `7bb510359b` | isStored param, ADT=1 for assigned, viewed empty ADT=2, SlotOption fix, option enum fix |
| Phase 1-4 audit | `20c9a0ea23`, `1dfc2eb207`, `c8df50eddd`, `ab43e4823d` | 26 items from 5-agent comprehensive audit |
| Stale rejection | `0cde8db70c` | Server-side FromHook source tagging replaces client-side detection |

---

## 9. Implementation Guidance

### How to Use This Report

1. Open a new Claude Code tab
2. Run `/transmog-implement` — it reads the bug tracker and picks the next bug
3. OR manually read `memory/transmog-bugtracker.md` for the full bug list
4. Each bug has exact file:line, root cause, fix description, and verification criteria

### Rules for Transmog Changes

1. **ONE bug per commit** — don't combine fixes
2. **Surgical patches only** — don't refactor surrounding code
3. **Show unified diff** for every change
4. **Never build from Claude Code** — user builds via VS IDE
5. **Update bug tracker** after each fix (change status, add commit hash)
6. **Check CLAUDE.md authoritative rules** when in doubt about behavioral model
7. **Preserve bridge defer behavior** for slots 2/12/13
8. **No fake weapon option-0 rows**
9. **ADT=2 is ONLY for viewed empty rows** — never for assigned rows

### Available Skills

| Skill | When to Use |
|-------|------------|
| `/transmog-implement` | Pick and implement the next bug from the tracker |
| `/transmog-status` | Quick overview of open bugs and what needs testing |
| `/transmog-correct` | Corrective pass on fillOutfitData behavioral model |

---

## 10. Testing Procedures

### In-Game Test Sequence (when server is running)

1. **Basic outfit**: Create outfit with 5+ slots → apply → close/reopen UI → verify paperdoll correct
2. **Rename**: Rename outfit → verify name persists
3. **Re-apply**: Apply same outfit again → no "Unknown set id" error (BUG-F test)
4. **Single slot**: Change one slot → verify only that slot changes (BUG-H test)
5. **Weapons**: Apply outfit with MH/OH weapons → verify weapon appearances
6. **Hidden slots**: Hide a slot (shoulder, cloak) → verify hidden appearance
7. **Enchant illusions**: Apply outfit with MH enchant → verify illusion visible
8. **Clear all**: Click "Clear Transmogrifications" → all slots reset to base
9. **Relog**: Log out, log back in → outfit still applied correctly
10. **Spec switch**: Change spec → verify ViewedOutfit resyncs

### Diagnostic Tools

- **TransmogSpy addon**: `/tspy status`, `/tspy bridge`, `/tspy items` — client-side diagnostics
- **Debug.log**: Server logs TransmogBridge + TransmogSpy relay messages
- **`transmog_debug.py --spy`**: Parses TransmogSpy SavedVariables
- **`transmog_debug.py --diff`**: Server-side DB diff

---

*This report is self-contained. A new Claude Code session reading only this file + the bug tracker + CLAUDE.md transmog rules section has everything needed to implement fixes.*

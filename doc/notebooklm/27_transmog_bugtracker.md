# Transmog Bug Tracker

> Single source of truth for all transmog bugs. Used by `/transmog-implement` skill.
> Each bug has exact file:line, root cause, fix, and verification criteria.
> Status: OPEN → IN-PROGRESS → FIXED → VERIFIED (in-game confirmed)

---

## CRITICAL

### BUG-F: SetID Mapping Destroyed After First Apply
- **Status**: INVESTIGATING — likely symptom of BUG-G
- **Source**: PR #760 testing
- **Symptom**: After applying outfit once, "Unknown set id 1" error — SetID lookup broken
- **File**: `src/server/game/Handlers/TransmogrificationHandler.cpp`
- **Root Cause**: Most likely consequence of BUG-G. When name parsing fails in `HandleTransmogOutfitNew`, the handler returns early (line 623-627) WITHOUT sending any SMSG response. Outfit is never created. Client then sends `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS` with a SetID that the server never assigned → "Unknown set id". Full code audit (session 110) found NO code path that corrupts `_equipmentSets` SetID/Type — `SetEquipmentSet`, `DeleteEquipmentSet`, `_SaveEquipmentSets`, and `_SyncTransmogOutfitsToActivePlayerData` all preserve data correctly.
- **Investigation Done** (session 110):
  1. `_equipmentSets` is `std::map<uint64, EquipmentSetInfo>` keyed by Guid
  2. `SetEquipmentSet` correctly preserves SetID, Type, Guid for existing entries
  3. Only `DeleteEquipmentSet` (explicit CMSG) or `_SaveEquipmentSets` (DELETED entries on char save) remove entries
  4. Diagnostic TYPE CHANGE logging already exists at line 28886
  5. No corruption path found — all modify paths preserve Type=TRANSMOG
- **Fix**: Fix BUG-G first. If still reproduces after BUG-G fix, re-investigate with actual server logs (the diagnostic dump at lines 755-760 will show exact map state when it fails)
- **Verify**: Create outfit, apply it, close transmog UI, reopen, apply again — no error

### BUG-G: Name Pad Byte 0x80 — Backward ASCII Scan Misidentifies String Boundaries
- **Status**: FIXED (ready for build)
- **Source**: PR #760 testing
- **Symptom**: Outfit name parsing fails — backward scan from end of packet hits 0x80 pad byte and misidentifies where the name string starts
- **File**: `src/server/game/Server/Packets/TransmogrificationPackets.cpp`
- **Root Cause**: Parser uses backward scan to find name string. The pad byte between nameLen and name is 0x80 (not 0x00). Scanner treats 0x80 as part of name or as delimiter incorrectly.
- **Investigation Steps**:
  1. Find the name parsing code in `HandleTransmogOutfitNew` and `HandleTransmogOutfitUpdateInfo` packet readers
  2. Identify the backward ASCII scan logic
  3. Check if `nameLen` field is being used (it should be — scan from end is fragile)
- **Fix**: Use `nameLen` field to extract name instead of backward scan. Format: `[nameLen:u8][pad:u8=0x80][name:nameLen bytes]`. Read nameLen, skip pad byte, read exactly nameLen bytes as name.
- **Verify**: Create outfit with ASCII name, rename it — name displays correctly

### BUG-H: CMSG_TRANSMOGRIFY_ITEMS Never Fires — Individual Slot Transmog Blocked
- **Status**: INVESTIGATING — likely resolves after BUG-G fix
- **Source**: PR #760 testing
- **Symptom**: Clicking individual transmog slots in the UI does nothing — no CMSG sent
- **File**: `src/server/game/Handlers/TransmogrificationHandler.cpp` (~line 172-567)
- **Root Cause**: In 12.x client, `C_Transmog.ApplyAllPending()` no longer exists. Individual slot transmog now goes through `C_TransmogOutfitInfo.CommitAndApplyAllPending()` → `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS`. The old `CMSG_TRANSMOGRIFY_ITEMS` handler is dead code (~400 lines).
- **Note**: The handler IS registered at `Opcodes.cpp:1107` but client never sends the opcode. This is a CLIENT-SIDE issue — the 12.x client simply doesn't have the old API. Individual transmog works through the outfit system now.
- **Investigation Steps**:
  1. Verify that individual slot clicks DO go through `CommitAndApplyAllPending` (check TransmogSpy logs or addon hooks)
  2. Check if `HandleTransmogOutfitUpdateSlots` properly handles single-slot changes
  3. The "fix" may be ensuring the outfit update path handles partial updates gracefully
- **Fix**: TBD — this may already work if the user has an active outfit. The issue might be that individual transmog requires an outfit context in 12.x.
- **Verify**: Apply transmog to a single slot (e.g., head) via the UI — appearance changes

---

## HIGH

### BUG-H1: Stored Outfit Slots Array Accumulation (30→60→90)
- **Status**: FIXED (ready for build)
- **Source**: Session 79 QA audit
- **Symptom**: Each sync call appends 30 more rows to stored outfit Slots arrays. After 3 syncs: 90 rows. Client receives bloated data.
- **File**: `src/server/game/Entities/Player/Player.cpp` — `_SyncTransmogOutfitsToActivePlayerData`
- **Root Cause**: `RemoveMapUpdateFieldValue` (line ~18044) marks entries as `Deleted` but the underlying Slots data stays. `try_emplace` finds the still-existing entry with its old Slots array. `fillOutfitData` then appends 30 MORE entries via `AddDynamicUpdateFieldValue`, growing 30→60→90. ViewedOutfit IS cleared (lines ~18390-18391), stored outfits are NOT.
- **Fix**: Add 2 lines inside the `for (auto const& [setId, equipmentSet]` loop, BEFORE the `fillOutfitData(transmogOutfitSetter, ...)` call (~line 18341):
  ```cpp
  ClearDynamicUpdateFieldValues(transmogOutfitSetter.ModifyValue(&UF::TransmogOutfitData::Slots));
  ClearDynamicUpdateFieldValues(transmogOutfitSetter.ModifyValue(&UF::TransmogOutfitData::Situations));
  ```
- **Impact**: Fires on every outfit save, delete, spec switch, handler flush. Growing SMSG payloads + memory.
- **Verify**: Apply outfit, close/reopen transmog UI multiple times — Slots array stays at 30 (not 60/90/120)

### BUG-M1: ValidateTransmogOutfitSet Rejects Entire Outfit for One Bad Enchant
- **Status**: FIXED (ready for build)
- **Source**: Session 79 QA audit
- **Symptom**: If any enchant illusion is invalid, the entire outfit is rejected instead of just zeroing that enchant
- **File**: `src/server/game/Handlers/TransmogrificationHandler.cpp` — `ValidateTransmogOutfitSet`
- **Root Cause**: Validation returns false (reject) instead of zeroing the bad enchant and continuing
- **Fix**: Change validation to zero invalid enchants (`equipmentSet.Enchants[i] = 0`) and continue instead of returning false
- **Verify**: Outfit with one invalid enchant still applies (enchant stripped, rest works)

### BUG-M2: Bridge Loses Illusions — Enchant Restore Coupled to Appearance Override Mask
- **Status**: FIXED (ready for build)
- **Source**: Session 79 QA audit
- **Symptom**: After bridge finalize, weapon enchant illusions vanish even when outfit defines them
- **File**: `src/server/game/Handlers/TransmogrificationHandler.cpp` — `FinalizeTransmogBridgePendingOutfit` (~line 1042-1047)
- **Root Cause**: Bridge sends weapon appearance override with `HasIllusion=false`. Weapon slot enters `bridgeOverriddenMask`. Enchant restore loop checks `if (!(bridgeOverriddenMask & (1u << weaponSlot)))` and SKIPS restoration because the bit IS set. But bridge didn't provide an illusion, so `Enchants[]` stays 0.
- **Fix**: Use separate `bridgeIllusionOverriddenMask`, or check `ov.HasIllusion` in the enchant restore loop. Only skip enchant restoration if the bridge explicitly provided an illusion for that slot.
- **Verify**: Apply outfit with MH enchant illusion → illusion persists after bridge finalize

### BUG-M5: MainHandOption/OffHandOption Never Parsed from CMSG
- **Status**: FIXED (ready for build)
- **Source**: Session 79 QA audit
- **Symptom**: Weapon option selection (1H vs 2H vs shield etc.) not stored — always defaults
- **File**: `src/server/game/Server/Packets/TransmogrificationPackets.cpp`
- **Root Cause**: byte[1] of slot entries contains the weapon option index but it's only used for routing, never stored to `MainHandOption`/`OffHandOption` in `EquipmentSetData`
- **Fix**: After parsing all slot entries, find the MH/OH entries and store their byte[1] as `MainHandOption`/`OffHandOption` on the EquipmentSetData struct
- **Verify**: Save outfit with different weapon types (1H sword + shield), reload — weapon options preserved

### BUG-M6: Hidden Pants (ItemID 216696) Missing from Detection Arrays
- **Status**: FIXED (ready for build)
- **Source**: Session 79 QA audit
- **Symptom**: Pants can't be hidden via transmog — not detected as hidden appearance
- **Files**: `src/server/game/Entities/Player/Player.cpp` (~line 18053 `hiddenItemIDs[]`) AND `src/server/game/Entities/Player/CollectionMgr.cpp` (~line 548 `hiddenAppearanceItems[]`)
- **Root Cause**: Both arrays contain 10 items but are missing ItemID 216696 / IMA 198608. Must be added to BOTH locations.
- **Fix**: Add `216696` to `hiddenItemIDs[]` in Player.cpp fillOutfitData AND to `hiddenAppearanceItems[]` in CollectionMgr.cpp. The IMA ID 198608 is confirmed in CLAUDE.md authoritative rules.
- **Verify**: Hide pants in transmog UI → pants slot shows as hidden (ADT=3, IMA=198608)

### BUG-M9: Illusion Bootstrap Leaks into Stored Outfits
- **Status**: FIXED (ready for build)
- **Source**: Session 79 QA audit
- **Symptom**: Stored outfits pick up illusions from currently-equipped items when they shouldn't
- **File**: `src/server/game/Entities/Player/Player.cpp` — `fillOutfitData`
- **Root Cause**: Illusion bootstrap from equipped items runs for ALL outfits, not just the viewed outfit. Should be gated by `!isStored`.
- **Fix**: Wrap the illusion bootstrap block with `if (!isStored)` — stored outfits only show illusions explicitly saved with them
- **Verify**: Create outfit without illusion, equip weapon with illusion, reopen transmog — stored outfit should NOT show the illusion

---

## MEDIUM

### BUG-M3: HandleTransmogOutfitNew Missing Bridge Defer
- **Status**: INVESTIGATED (session 110)
- **Source**: Session 79 QA audit
- **Symptom**: New outfit creation doesn't go through bridge defer path — bridge addon override data silently discarded
- **File**: `src/server/game/Handlers/TransmogrificationHandler.cpp` — `HandleTransmogOutfitNew` (line 619)
- **Root Cause**: Handler calls `SetEquipmentSet` immediately (line 666) without storing to `_transmogBridgePendingOutfit`. Bridge addon message arrives at ChatHandler line 676, finds no pending outfit, discards overrides.
- **Impact**: Stale armor IMAIDs and missing illusions in new outfits when bridge addon installed. Lower severity than UpdateSlots because no prior state to corrupt — equipped-item-modifier fallback is reasonable for new outfits.
- **Fix**: Store into `_transmogBridgePendingOutfit` instead of saving immediately. Add `bool IsNew` to `TransmogBridgePendingOutfit` so finalize knows to send `SMSG_TRANSMOG_OUTFIT_NEW_ENTRY_ADDED` vs `SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED`. ~30-50 lines.
- **Verify**: Create new outfit with bridge addon installed — all slots (including head, weapons, illusions) populated correctly

### BUG-M7+M8: EffectEquipTransmogOutfit Incomplete (return value + SMSG)
- **Status**: INVESTIGATED (session 110) — M7 and M8 are same root cause, fix together
- **Source**: Session 79 QA audit
- **Symptom**: (M7) If `ApplyTransmogOutfitToPlayer()` fails (insufficient gold), spell shows as successful + outfit ID/data already persisted = desync. (M8) Client never receives SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED after spell-based apply — UI state stale.
- **File**: `src/server/game/Spells/SpellEffects.cpp` — `EffectEquipTransmogOutfit` (line 6004)
- **Root Cause**: 3-line stub: sets active ID (6028), persists set (6029), calls apply (6030) with ignored return. No error handling, no UpdateField flush, no SMSG response.
- **Failure mode**: `ApplyTransmogOutfitToPlayer` returns false only when player can't afford gold (`TransmogrificationUtils.cpp` line 56-61).
- **Fix** (~15 lines): (1) Add `#include "TransmogrificationPackets.h"`. (2) Check return value → on fail: `SendCastResult(SPELL_FAILED_NOT_ENOUGH_MONEY)` + return. (3) On success: flush UpdateFields (`SendUpdateToPlayer` + `ClearUpdateMask`) + send `SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED` with 30-row slot echo from `GetLastOutfitSlotEcho()`, mirroring `FinalizeTransmogBridgePendingOutfit` lines 1134-1151.
- **Verify**: (M7) Apply outfit via spell with insufficient gold → spell fails gracefully. (M8) Apply via spell with enough gold → client UI updates immediately.

### BUG-M10: UpdateSlots Parser Uses Heuristic Skip Instead of Explicit Field Reads
- **Status**: OPEN
- **Source**: Session 79 QA audit
- **Symptom**: Parser fragility — alignment gap calculation can break on unexpected packet layouts
- **File**: `src/server/game/Server/Packets/TransmogrificationPackets.cpp`
- **Root Cause**: Parser calculates alignment gap as `(remainingBytes - slotCount*16)` instead of reading explicit fields
- **Fix**: Replace heuristic with explicit sequential field reads per slot entry format
- **Verify**: Various slot counts (14, 28, 30) all parse correctly

---

## LOW

### BUG-L1: Dead HandleTransmogrifyItems Handler (~400 lines)
- **Status**: OPEN
- **Source**: Session 79 QA audit
- **File**: `src/server/game/Handlers/TransmogrificationHandler.cpp` lines 172-567
- **Root Cause**: Client never sends CMSG_TRANSMOGRIFY_ITEMS in 12.x — dead code
- **Fix**: Add early return after dead-code warning log at entry. Or remove entirely.
- **Priority**: Cosmetic — doesn't cause bugs

### BUG-L4: spell_clear_transmog Doesn't Zero All Auxiliary Fields
- **Status**: OPEN
- **Source**: Session 79 QA audit
- **File**: `src/server/scripts/Custom/spell_clear_transmog.cpp`
- **Root Cause**: After clearing, some auxiliary fields (ConditionalAppearance, etc.) may retain stale values
- **Fix**: Zero all auxiliary transmog fields in the clear loop
- **Verify**: Clear all transmog → no stale visual artifacts

### BUG-UNICODE: Unicode Outfit Names Break Backward ASCII Scan
- **Status**: FIXED (fixed by BUG-G fix)
- **Source**: Known limitation
- **File**: `src/server/game/Server/Packets/TransmogrificationPackets.cpp`
- **Root Cause**: Name parser scans backward for printable ASCII — fails on UTF-8 multi-byte characters
- **Fix**: Same as BUG-G — use nameLen field instead of backward scan
- **Note**: Fixing BUG-G should also fix this

### BUG-SECONDARY-SHOULDER: 13/14 Outfit Loading Slots Work
- **Status**: OPEN (accepted limitation)
- **Source**: PR #760
- **File**: `src/server/game/Entities/Player/Player.cpp` — `fillOutfitData`
- **Root Cause**: All 3 client layers return nil for secondary shoulder during outfit loading. No API available.
- **Workaround**: Server baseline fills from last saved value
- **Note**: PR #760 upstream wants server-only fix without addon dependency

---

## DEPLOYED BUT UNVERIFIED (need in-game testing)

### All Bug A-E Fixes
- **Status**: FIXED (awaiting in-game verification)
- **Bugs**: Paperdoll naked on reopen (A), old head/shoulder persist (B), Monster Mantle ghost (C), Draenei leg geometry (D), single-item transmog revert (E)
- **Commits**: `c8df50eddd`, `ab43e4823d`, `289677be44`

### MH Enchant Illusions (4-field payload)
- **Status**: FIXED (awaiting in-game verification)
- **Source**: Session 60
- **Commit**: `5d38823153`

### Clear Single Slot (transmogID=0)
- **Status**: FIXED (awaiting in-game verification)
- **Source**: Session 60
- **Commit**: `5d38823153`

### Corrective Pass (6 surgical changes)
- **Status**: FIXED (awaiting in-game verification)
- **Source**: Session 73
- **Commit**: `7bb510359b`
- **Changes**: isStored parameter, ADT=1 for assigned, viewed empty ADT=2/IDT=2, SlotOption=mapping.option, real MH/OH option enums, paired threshold fix

---

## VERIFIED (confirmed working in-game)

### 14/14 Manual Slot Clicks
- **Status**: VERIFIED
- **Date**: March 1, 2026
- **Test**: Full test pass, all equipment slots transmog via manual click

### 13/14 Outfit Loading
- **Status**: VERIFIED (secondary shoulder is accepted gap)
- **Date**: March 1, 2026

---

## Validation Report (session 110 investigation)

- **DT 12 / DT 14 mapping**: Both already fixed in code. Validator report was stale (build 66220, pre-dates fix).
- **72 placeholder IMAIDs**: All are unreleased DB2 entries. No player impact. No action needed.
- **transmog_repair.sql**: Empty — no fixable mismatches found.
- **Recommendation**: Re-run `validate_transmog.py` against build 66263 for freshness check.

---

*Last updated: March 8, 2026 (session 110 — 8 fixes + 3 QA passes + investigations)*
*Next priority: BUILD in VS → test plan in `doc/transmog_next_steps.md` → verify BUG-G cascading fix for BUG-F + BUG-H*

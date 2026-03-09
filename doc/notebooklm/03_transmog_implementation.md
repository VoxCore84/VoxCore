# Transmog Outfit Implementation Reference

> **Session 110 (Mar 8 2026)**: 8 bugs fixed (G, H1, M6, M9, M1, M5, M2, UNICODE). In-game test guide: `doc/transmog_test_guide.md`. Next steps: `doc/transmog_next_steps.md`.

## File Locations
- Packet classes: `src/server/game/Server/Packets/TransmogrificationPackets.h/.cpp`
- Handlers: `src/server/game/Handlers/TransmogrificationHandler.cpp`
- Shared utility: `src/server/game/Entities/Player/TransmogrificationUtils.h/.cpp` — `ApplyTransmogOutfitToPlayer()` (gold cost + apply appearances)
- Spell effect 347: `src/server/game/Spells/SpellEffects.cpp` → `EffectEquipTransmogOutfit()` (~line 6003) — delegates to `ApplyTransmogOutfitToPlayer()`
- Visible item rendering: `src/server/game/Entities/Player/Player.cpp` → `SetVisibleItemSlot()` (~line 12142)
- UpdateField sync: `src/server/game/Entities/Player/Player.cpp` → `_SyncTransmogOutfitsToActivePlayerData()` (~line 18024)
- Login sync: `src/server/game/Entities/Player/CollectionMgr.cpp` → `SendFavoriteAppearances()`
- Full reference doc: `_patches_transmog/TRANSMOG_IMPLEMENTATION.md`
- Source-adjacent doc: `src/server/game/Handlers/TransmogOutfitSystem.md`

## Critical Facts
- **NPC GUID**: All 4 CMSG packets send the transmogrifier NPC GUID, not player. Validate with `GetNPCIfCanInteractWith(npc, UNIT_NPC_FLAG_TRANSMOGRIFIER)`
- **SetType = 1**: Must be 1 (Outfit). 0 and 2 cause client to ignore outfit
- **Retail sends exactly 30 entries per outfit** (12 armor + 9 MH weapon options + 9 OH weapon options). Server now emits 30 entries too (commit `6723a4f897`, Mar 5 2026). Previously sent 14 → client mirrored 14 back → accumulated groups (14→28→42→56) on each apply
- **Slot entry wire format** (verified via WPP sniff + Wago DB2 item lookups, Feb 2026):
  - byte[0] = Sequential ordinal (1-30) — **NOT a meaningful slot identifier**
  - byte[1] = Weapon option index (0 for armor/base weapon, 1-8 for weapon type variants)
  - bytes[2-5] = AppearanceID (IMAID, uint32 LE)
  - bytes[6-7] = ItemAppearance.DisplayType of the IMAID (uint16 LE) — **THIS IS THE ROUTING KEY**
  - bytes[8-15] = Reserved (zeros)
- **Empty slot detection**: IMAID == 0 (NOT byte[1]). byte[1] is weapon option index (0 for armor)
- **Behavioral ADT values (corrected from retail packets, Mar 5 2026)**:
  - ADT=0 Unassigned (stored empty), ADT=1 Assigned (has real IMAID — both stored AND viewed), ADT=2 Passthrough (viewed empty, show equipped), ADT=3 Hidden visual IMA (carries real hidden IMA ID), ADT=4 Not applicable (paired weapon placeholder)
  - ADT=2 is ONLY for viewed empty rows — NEVER for assigned rows. Assigned is always ADT=1 regardless of context
  - IDT mirrors ADT for empty/passthrough (stored empty IDT=0, viewed empty IDT=2), weapon enchants use IDT=1
  - DT=3+IMA=0 does NOT exist on retail — DT=3 always carries a real hidden IMA ID
- **Hidden visual IMA IDs**: 77343=shoulder, 77344=head, 77345=cloak, 83202=shirt, 83203=tabard, 84223=belt, 94331=gloves, 104602=chest, 104603=boots, 104604=bracers, 198608=pants
- **DisplayType slot routing** (confirmed by looking up every IMAID in Wago DB2):
  - DT 0=Head(0), 1=Shoulder(2), 2=Shirt(3), 3=Chest(4), 4=Waist(5), 5=Legs(6), 6=Feet(7), 7=Wrist(8), 8=Hands(9), 9=Back(14), 10=Tabard(18), 11=MH(15), 13=Shield→OH(16), 15=OH(16)
  - byte[0] does NOT correspond to DB2 TransmogOutfitSlotInfo.ID for routing!
  - Example proof: byte[0]=1 contained IMAID 301683 "Shul'ka Shoulderspikes" (DT=1, Shoulder) — NOT a head item
  - Example proof: byte[0]=9 contained IMAID 301677 "Shul'ka Girdle" (DT=4, Waist) — NOT wrists
- **DB2 TransmogOutfitSlotInfo**: Used by the client for outfit UI slot ordering, NOT for CMSG wire format routing. IDs 1-14 map to Head, ShoulderR, ShoulderL, Shirt, Chest, Waist, Legs, Feet, Wrist, Hands, Back, Tabard, MH, OH
- **Secondary shoulder**: DT=1 (Shoulder) appears up to 3 times with ordinals 1, 2, 3. Ordinal 3 = secondary shoulder. Ordinals 1-2 = primary (first wins). Old `seenPrimaryShoulder` boolean caused ordinal 3 to overwrite ordinal 2 — replaced with ordinal-based check (Mar 3 2026)
- **HEAD rarely in outfit packets**: No DT=0 entry in observed outfit packets — HEAD is applied separately via CMSG_TRANSMOGRIFY_ITEMS. Handler preserves existing HEAD data.
- **Spell 1247613**: Client casts this with effect 347, MiscValue = SetID, to apply an outfit

## Packet Layouts (Abbreviated)
- **NEW**: [NPC PackedGuid][type:u8][flags:u8][icon:u32][optional 16-byte slot entries...][nameLen:u8][pad:u8][name] — pad byte varies (0x00 or 0x80), check relaxed Mar 3 2026
- **UPDATE_INFO**: [SetID:u32][NPC PackedGuid][type:u8][icon:u32][nameLen:u8][pad:u8][name] — 5-byte middle (no flags), pad byte varies
- **UPDATE_SLOTS**: [SetID:u32][slotCount:u32][NPC PackedGuid][IconFileDataID:u32][pad:u32][N * 16-byte slots][trailing:u8]
- **UPDATE_SITUATIONS**: [SetID:u32][NPC PackedGuid][count:u32][N * 16-byte entries] — each: [situationID:u32][specID:u32][loadoutID:u32][equipSetID:u32]

## SMSG Responses
All four: `uint32 SetID + uint64 Guid`. Minimal ACKs.

## Parser Notes
- NEW and UPDATE_INFO use heuristic backward ASCII scan for name detection — fragile on non-ASCII names
- UPDATE_SLOTS calculates alignment gap as (remainingBytes - slotCount*16)
- UPDATE_SITUATIONS is clean structured reads
- All parsers have ParseSuccess/ParseError/DiagnosticReadTrace for debugging

## Floating Transmog Fix (Feb 2026)
- **Root cause**: `VisibleItem` update fields `HasTransmog`, `HasIllusion`, and `Field_18` were never set (always 0)
- **Fix**: `SetVisibleItemSlot()` now sets `HasTransmog` (bool), `HasIllusion` (bool), and `Field_18` = `ItemAppearance.DisplayType` (uint8)
- **Refactor**: Outfit application logic extracted from `EffectEquipTransmogOutfit` into shared `ApplyTransmogOutfitToPlayer()` in `TransmogrificationUtils.cpp`. Used by both the spell effect and `HandleTransmogOutfitUpdateSlots`
- **Gold cost**: `ApplyTransmogOutfitToPlayer()` calculates cost per changed slot (sell price), skips if player has `SPELL_AURA_REMOVE_TRANSMOG_COST`

## AppearanceDisplayType Fix (Feb 2026)
- `_SyncTransmogOutfitsToActivePlayerData` was sending hardcoded `AppearanceDisplayType=1` for all non-zero IMAIDs
- Fixed to look up real value from DB2: `ItemModifiedAppearance → ItemAppearance.DisplayType` (values 0-11)
- Matches `SetVisibleItemSlot` logic — client needs correct DisplayType to render outfit UI properly
- Commit `4e225ebeb3`

## Routing Bug Fix History (Feb 2026)
1. **Original bug**: `slot.Flags == 0` (byte[1]) skipped ALL entries — byte[1] is always 0. Fixed to `AppearanceID == 0`
2. **Wrong fix**: Changed from `DisplayTypeToEquipSlot(wireDT)` to `TransmogSlotToEquipSlot(tSlot)` based on incorrect assumption that byte[0] = DB2 TransmogOutfitSlotInfo.ID
3. **Root cause discovered**: Looked up every IMAID in Wago DB2 CSVs — byte[0] is sequential ordinal, NOT slot ID. Shoulder items appeared at byte[0]=1 (which would be "Head" if it were a DB2 ID). Wire DT correctly identified them as DT=1 (Shoulder)
4. **Correct fix**: Reverted to `DisplayTypeToEquipSlot(wireDT)` — DT IS the authoritative routing key. Kept `AppearanceID == 0` empty check. Restored `seenPrimaryShoulder` for secondary shoulder detection
5. **First-write-wins**: Added `if (!Set.Appearances[equipSlot])` guard (commit e282e8c6) — was needed temporarily while wireDT was trusted
6. **Server-side DT lookup** (commit 485d3b10ed, Feb 27): Client wireDT is WRONG for most IMAIDs (nearly all arrive as DT=1). Added `GetServerDisplayType()` helper that looks up IMAID→ItemAppearanceID→DisplayType from server DB2 stores (`sItemModifiedAppearanceStore` + `sItemAppearanceStore`). Falls back to wireDT only if IMAID not in DB2. First-write-wins guard reverted — no longer needed since server DT routes each IMAID to its correct unique slot

## Client-Side Diagnostics
- **TransmogSpy addon** (`C:/WoW/_retail_/Interface/AddOns/TransmogSpy/`): Logs 14 client transmog events, captures pre/post apply snapshots, monitors pending state transitions. SavedVariables persist 2000-line log in `TransmogSpyDB`. Symlink: `PacketLog/SavedVariables/` → WoW account SavedVariables for easy access
- **`transmog_debug.py --spy`**: Parses TransmogSpy SavedVariables, completing the client-side visibility gap — pairs with `--diff`/`--char` (server-side) for full end-to-end transmog debugging

## TransmogBridge System (Feb 28 2026, updated Mar 3 2026)

### Architecture: Deferred Finalization with 3-Layer Hybrid Merge
The 12.x client's `CommitAndApplyAllPending()` serializer omits HEAD(DT=0), MH(DT=11), OH(DT=13/15) and sends stale/saved IMAIDs for all other slots. TransmogBridge works around this:

1. **Client addon** (`TransmogBridge.lua`): 3-layer hybrid merge in `CommitAndApplyAllPending` post-hook:
   - **Layer 1**: `GetViewedOutfitSlotInfo(slot, 0, 0)` snapshot — captures outfit-loaded armor slots. Secondary shoulder: `GetViewedOutfitSlotInfo(1, 0, 1)` → encoded as slot 2
   - **Layer 2**: `SetPendingTransmog` hook accumulations — captures weapons (12,13), tabard (5), shirt (6), secondary shoulder (2). **Wins on conflict** with Layer 1
   - **Layer 3**: `C_Transmog.GetSlotVisualInfo` fallback — fills remaining gaps via `TransmogUtil.GetTransmogLocation`. Uses `pendingSourceID`, falls back to `appliedSourceID`. Both are IMAIDs despite the name
   - Sends merged `slot.transmogID.option;...` payload via addon WHISPER to self
2. **Server deferred path**: `HandleTransmogOutfitUpdateSlots` stores parsed outfit into `_transmogBridgePendingOutfit` instead of immediately saving/applying
3. **Addon message intercept**: `HandleChatAddonMessage` (ChatHandler.cpp) intercepts "TMOG_BRIDGE" prefix, parses overrides into `_transmogBridgeOverrides`, calls `FinalizeTransmogBridgePendingOutfit()`
4. **Finalize**: Merges overrides into `Appearances[]` (+ `SecondaryShoulderApparanceID` for slot 2), validates, saves, applies, sends SMSG response
5. **Safety net**: `WorldSession::Update()` finalizes any orphaned pending outfit (backward compat when addon not installed)

### Why 3 Layers?
- **Outfit set loading** bypasses `SetPendingTransmog` but populates `GetViewedOutfitSlotInfo` for armor slots
- **Manual slot clicks** fire `SetPendingTransmog` but `GetViewedOutfitSlotInfo` is unreliable for weapons/tabard/shirt/secondary shoulder
- **Layer 3** catches slots missed by both (rare edge cases during outfit loading where neither fires)

### Hidden Appearance Detection (Mar 3 2026)
After 3-layer merge, slots still nil are categorized:
- **ALWAYS_NIL_SLOTS** `{0=HEAD, 2=SECONDARY_SHOULDER, 12=MH, 13=OH}` — client serializer bug, deferred to server baseline
- **All other slots nil** = user intentionally hid this slot → send explicit `slot.0.0` clear (transmogID=0)
- This distinguishes "hidden nil" (back, shoulders, tabard, shirt, wrists) from "broken client nil" (head, weapons)

### Server-Side Stale Rejection (Mar 5 2026, replaced client-side detection)
Layer 1 (`GetViewedOutfitSlotInfo`) returns currently-worn appearance for ALL slots, even slots the outfit doesn't define. This produced false positives with client-side detection.
- **Source tagging**: Addon sends `option=1` for Layer 2 (SetPendingTransmog hook) data, `option=0` for Layer 1/3 (snapshot/fallback)
- **Server parsing**: `ChatHandler.cpp` reads option field into `TransmogBridgeOverride::FromHook` (true if option==1)
- **Server rejection**: In `FinalizeTransmogBridgePendingOutfit`, before processing each override: if `!FromHook` AND saved outfit ignores the slot (`Appearances[slot]==0` + `IgnoreMask` bit set), the override is stale bootstrap data → `continue` (skip it, let baseline restore handle the slot)
- **Eliminates false positive**: No more double-apply needed when outfit defines same appearance as currently worn
- Commit `0cde8db70c`

### Timing Guarantee
Both CMSGs are `PROCESS_THREADUNSAFE`, same WorldSession thread, `LockedQueue<deque>` = FIFO. `hooksecurefunc` is a post-hook → outfit packet always arrives before addon message.

### Client Slot Mapping (SetPendingTransmog indices)
0=HEAD, 1=SHOULDER, 2=SECONDARY_SHOULDER, 3=BACK, 4=CHEST, 5=TABARD, 6=SHIRT, 7=WRIST, 8=HANDS, 9=WAIST, 10=LEGS, 11=FEET, 12=MAINHAND, 13=OFFHAND

### Wire Format
Addon payload: `slot.transmogID.option` for armor, `slot.transmogID.option.illusionID` for weapons with enchants (4-field format).
Multi-part for >255 bytes: `1>data...` then `2>data...`
`transmogID=0` = clear slot. `transmogID >= 0` accepted by server (0 = clear, >0 = apply).

### Files Modified
- `WorldSession.h` — TransmogBridgeOverride struct (ClientSlot, TransmogID, IllusionID, HasIllusion), TransmogBridgePendingOutfit struct, member variables
- `ChatHandler.cpp` — TMOG_BRIDGE prefix intercept, parses `slot.transmogID.option[.illusionID]` format, accepts `transmogID >= 0` (0 = clear), option=1 → FromHook=true
- `TransmogrificationHandler.cpp` — deferred storage, MapClientSlotToEquipSlot(), FinalizeTransmogBridgePendingOutfit() with `bridgeOverriddenMask` + `bridgeOverrodeSecondary` + `bridgeClearedMask` + server-side stale rejection (FromHook check), illusion merge via Enchants[0/1] with HasIllusion flag, post-validate `bridgeClearedMask` re-clears IgnoreMask, SendUpdateToPlayer+ClearUpdateMask flush in all 4 handlers, validateIllusion fix (TransmogIllusion DB2 check)
- `WorldSession.cpp` — safety net in Update()
- `Player.cpp` — fillOutfitData diagnostic logging + equipped-item bootstrap

### Files Created
- `C:/WoW/_retail_/Interface/AddOns/TransmogBridge/TransmogBridge.toc`
- `C:/WoW/_retail_/Interface/AddOns/TransmogBridge/TransmogBridge.lua`

### Clear Transmogrifications Spell (1247917)
Was a no-op (zero SpellEffect rows in DB2). Fixed via:
- **Hotfix SQL** (`sql/updates/hotfixes/master/2026_03_03_01_hotfixes.sql`): `spell_effect` row (ID 1900003, SPELL_EFFECT_SCRIPT_EFFECT targeting caster) + `hotfix_data` entry
- **World SQL** (`sql/updates/world/master/2026_03_03_01_world.sql`): `spell_script_names` entry linking 1247917 → `spell_clear_current_transmogrifications`
- **SpellScript** (`src/server/scripts/Custom/spell_clear_transmog.cpp`): Iterates all 19 equipment slots, clears all 18 transmog modifiers per item (primary appearance, secondary shoulder, enchant illusions, all specs), calls `SetState(ITEM_CHANGED)` + `SetVisibleItemSlot()`
- Registered in `custom_script_loader.cpp`

### Stale Data Correction / Baseline Restoration
After bridge merge, before validation: iterates all equipment slots. For non-bridge-overridden slots, if outfit IMAID == equipped item's `GetItemModifiedAppearance()->ID` (base appearance) AND item has `ITEM_MODIFIER_TRANSMOG_APPEARANCE_ALL_SPECS` != base, swaps in the active transmog. Uses `bridgeOverriddenMask` bitmask to skip slots the bridge already set (prevents undoing intentional revert-to-base).

**`bridgeOverrodeSecondary` flag** (Mar 3 2026): Secondary shoulder (clientSlot=2) maps to `SecondaryShoulderApparanceID` via `continue` before reaching the `bridgeOverriddenMask` bitmask code. The primary shoulder (clientSlot=1) sets `EQUIPMENT_SLOT_SHOULDERS` in the bitmask. A separate `bool bridgeOverrodeSecondary` tracks whether the bridge explicitly set the secondary shoulder, preventing the restoration logic from overwriting it.

### Log Relay
Both addons pipe client-side logs to server `Debug.log` via addon messages:
- TransmogBridge: `TMOG_LOG` prefix → `TransmogBridge client [Player]: ...`
- TransmogSpy: `TSPY_LOG` prefix → `TransmogSpy client [Player]: ...`
- ChatHandler.cpp handles both prefixes in single `if` block
- TransmogSpy strips WoW color codes before relay

### Commits
- `1e47b11c23` — initial implementation (pushed)
- `e27f103e1b` — illusion strip, stale data correction, bridgeOverriddenMask, log relay, validateIllusion fix (pushed)
- `d752c12fcd` — add TransmogBridge addon to repo (pushed)
- `aaf2114e55` — 3-layer hybrid merge + bridgeOverrodeSecondary flag (pushed Mar 3 2026)
- `272c373105` — pad byte, shoulder ordinal routing, hidden appearances, naked paperdoll fix (pushed Mar 3 2026)
- `c13199ec9b` — QA: first-wins guard, split boundary 253, HandleTransmogrifyItems flush (pushed Mar 3 2026)
- `407b9aabc1` — stale data detection (pre-snapshot comparison), paperdoll ViewedOutfit flush (pushed Mar 4 2026)
- `fae00afb86` — revert DT=3 assignment and last-group-only merge based on retail sniffer data (pushed Mar 5 2026)
- `6723a4f897` — expand ViewedOutfit from 14 to 30 entries (12 armor + 9 MH + 9 OH weapon options), add DT=12 ranged, rename Flags→Option (pushed Mar 5 2026)
- `289677be44` — persist single-item sync, track active outfit for ViewedOutfit, fix IgnoreMask clobber (pushed Mar 5 2026)
- `12bc18f374` — add sanity caps and accumulation handling to packet parsing (pushed Mar 5 2026)
- `5d38823153` — clear spell outfit sync + illusion bootstrap (pushed Mar 5 2026)
- `27b5496f4f` — 11-fix QA sweep: active outfit persistence, stale detection, cross-contamination, etc. (pushed Mar 5 2026)
- `0cde8db70c` — server-side stale rejection replaces client-side detection with source tagging (pushed Mar 5 2026)
- `20c9a0ea23` — Phase 1 server fixes + Phase 2 bridge cleanup (pushed Mar 5 2026)
- `1dfc2eb207` — Phase 3 TransmogSpy v2 (pushed Mar 5 2026)
- `c8df50eddd` — Phase 4 hardening: baseline restore, stale partial, spec resync, per-slot validation (pushed Mar 5 2026)
- `ab43e4823d` — EffectEquipTransmogOutfit ViewedOutfit sync + Situations parser error handling (pushed Mar 5 2026)

### PR
- **PR #760** on KamiliaBlow/RoleplayCore (cross-repo from VoxCore84:pr/transmog-ui-12x)
- 20 files, +3546/-108 lines, clean transmog-only diff
- Old PRs #34/#35 on VoxCore84/RoleplayCore closed (were same-repo, showed 37 files with non-transmog changes)
- Distribution zip: `~/VoxCore/TransmogBridge.zip`

## Known Gaps / Limitations (Accepted)
- Outfit delete: assumed via CMSG_DELETE_EQUIPMENT_SET (unverified)
- Heuristic parsers break on Unicode outfit names
- `SecondaryWeaponAppearanceID`/`SecondaryWeaponSlot` (legion artifacts) not persisted — low priority
- **Secondary shoulder during outfit loading**: all 3 client layers return nil, no API available. Server baseline fills from last saved value
- **No "revert single slot to base" UI option** exists in transmog interface (client limitation)
- **Weapon slots during outfit loading**: may return nil from all layers, server baseline fills from saved outfit

## Naked Paperdoll Fix (Mar 3-4 2026)
- **Root cause**: `_SyncTransmogOutfitsToActivePlayerData()` used `AddDynamicUpdateFieldValue` for `ViewedOutfit.Slots` and `ViewedOutfit.Situations` but never cleared them first. Arrays accumulated across calls (14→28→42...), client received duplicate conflicting slot data, rendered naked.
- **Fix 1**: Added `ClearDynamicUpdateFieldValues` for both Slots and Situations before `fillOutfitData` in Player.cpp
- **Fix 2** (Mar 4): Added `SendUpdateToPlayer(this)` + `ClearUpdateMask(true)` after `fillOutfitData`, guarded by `IsInWorld()`. Clear+rebuild alone didn't trigger client model refresh without explicit SMSG_UPDATE_OBJECT delivery
- **Client path**: `VIEWED_TRANSMOG_OUTFIT_SLOT_REFRESH` → `TransmogCharacterMixin:RefreshSlots()` → `actor:SetItemTransmogInfo()` per slot

## Hotfix Warning — TransmogSetItem Orphans
**Root cause of transmog visual bug**: 122 orphaned `transmog_set_item` rows referenced non-existent IMAIDs, causing `Blizzard_Transmog.lua:2488 nil sourceIDs` errors (~190x/session). This broke `C_Transmog.ApplyAllPending()`, preventing `CMSG_TRANSMOGRIFY_ITEMS` from ever being sent.

**Failed fix**: `hotfix_data` Status=2 entries do NOT work for records in hotfix TABLES — only for records in client .db2 files. Server sends table data as `Status:Valid` regardless of hotfix_data overrides.

**Correct fix** (commit 16005d3401, applied to DB Feb 27 2026): `DELETE tsi FROM transmog_set_item tsi LEFT JOIN item_modified_appearance ima ON tsi.ItemModifiedAppearanceID = ima.ID WHERE ima.ID IS NULL` — removes 122 rows directly.

**Lesson learned**: `hotfix_data` Status=2 = "tell client to remove a record from its .db2 cache". For records that exist in the server's hotfix MySQL tables (like `transmog_set_item`), the server sends them as Valid payloads. Must DELETE from the table directly.

## Test Environment
- **Client**: 12.0.1.66263
- **Test character**: "Hexandchill" (guid 7) — Warlock, "Judgemental" (guid 8) — Paladin
- **Test set**: Imperial Plate (IMAIDs 101190-101196)
- **Retail sniffer data**: `C:\Users\atayl\OneDrive\Desktop\ymir_retail_12.0.1.66220\dumps\dump_12.0.1.66220_2026-03-04_23-31-24_parsed.txt` (2.77M lines, ground truth for packet analysis)

## Active Status (Mar 6 2026 — full QA audit complete, 21 issues found)

### QA Audit (session 79): 1 HIGH, 10 MEDIUM, 10 LOW
Full report: `~/cowork/context/transmog-qa-report.md`
- **H1**: Stored outfit Slots array accumulation (30->60->90 per sync call) — missing ClearDynamicUpdateFieldValues for stored outfits in _SyncTransmogOutfitsToActivePlayerData. ViewedOutfit is cleared (lines 18390-18391), stored outfits are NOT. 2-line fix
- **M1-M10**: Enchant validation rejects entire outfit, bridge loses illusions, HandleTransmogOutfitNew missing apply+bridge, weapon option never stored, hidden pants missing, spell effect return value ignored + missing SMSG, illusion bootstrap leaks into stored outfits, UpdateSlots parser fragile
- All 14 findings double-verified with line-number evidence

### What's Working
- All 14 slots via manual clicks (full test pass, Mar 1 2026)
- 13/14 slots via outfit set loading (secondary shoulder is known gap)
- MH/OH weapon transmog via manual clicks and outfit loading
- Clear All Transmogrifications button (spell 1247917)
- Outfit slot purchase immediate UI refresh (SendUpdateToPlayer flush)
- Server baseline restoration for non-bridge slots
- Illusion validation fixed (checks `sDB2Manager.GetTransmogIllusionForEnchantment()` from TransmogIllusion DB2 before falling back to SpellItemEnchantment.Flags)

### Phase 1 Fixes (Mar 5 2026, commit `289677be44`)
1. **Bug E fix**: `HandleTransmogrifyItems` now calls `SetEquipmentSet(*activeOutfit)` after single-item sync — persists to DB + refreshes ViewedOutfit
2. **Bug B fix**: Added `_activeTransmogOutfitID` tracking to Player. `_SyncTransmogOutfitsToActivePlayerData` now uses the actively-applied outfit for ViewedOutfit instead of always using lowest SetID. Set in `FinalizeTransmogBridgePendingOutfit`.
3. **IgnoreMask fix**: `HandleTransmogOutfitUpdateInfo` preserves `existingSet->IgnoreMask` instead of clobbering with uninitialized packet value

### Phase 2 Fixes (Mar 5 2026, commit `5d38823153`)
1. **H1 fix**: `spell_clear_transmog.cpp` now syncs cleared state to active outfit (zeros Appearances[], Enchants[], SecondaryShoulderApparanceID) + calls `SetEquipmentSet()` to persist and rebuild ViewedOutfit
2. **M4 fix**: `fillOutfitData` now bootstraps weapon enchant illusions from equipped items (`ITEM_MODIFIER_ENCHANT_ILLUSION_ALL_SPECS`) when the outfit doesn't define them
3. **H2**: Already fixed (verified clean `//` comments, no stray backslashes)
4. **IgnoreMask bidirectional**: Analyzed and confirmed current behavior is correct — IMAID=0 with IgnoreMask bit clear = explicit clear, DT=0 renders base item appearance

### Phase 3 Fixes (Mar 5 2026, commit `27b5496f4f`) — 11-item QA sweep
1. **M1**: `_activeTransmogOutfitID` persisted to DB via `active` column in `character_transmog_outfits`. Survives relog
2. **M2**: `EffectEquipTransmogOutfit` now calls `SetActiveTransmogOutfitID` before applying
3. **M3**: `Situations.resize(count)` capped at 256 in packet parser (OOM prevention)
4. **M4**: Fixed cross-contamination in CurrentSpecOnly reset paths (appearance reset no longer clears illusions, vice versa)
5. **L1**: Removed redundant `SendUpdateToPlayer`+`ClearUpdateMask` in `FinalizeTransmogBridgePendingOutfit`
6. **L2**: Illusion bootstrap checks per-spec modifier first via `IllusionModifierSlotBySpec`
7. **L3**: Clear spell sets `IgnoreMask=0x7FFFF` after zeroing outfit
8. **L4**: `DeleteEquipmentSet` clears `_activeTransmogOutfitID` when deleted outfit was active
9. **L5**: Fixed signed `(1 << i)` to unsigned `(1u << i)` in `ValidateTransmogOutfitSet`
10. **L6**: Added `TC_LOG_WARN` to `HandleTransmogrifyItems` entry (dead code detector)

### Phase 4 Hardening (Mar 5 2026, commit `c8df50eddd`)
1. Baseline IgnoreMask + Enchants restore for non-bridge slots
2. Stale partial clear — cleans up orphaned pending state
3. Spec-switch ViewedOutfit resync
4. Per-slot validation pass
- Items 5+6 (task #4 item-driven ViewedOutfit, task #5 low-priority) skipped — task #4 determined NOT NEEDED because Phase 4's bidirectional sync in HandleTransmogrifyItems already keeps outfit Appearances[] in sync with item modifiers

### Follow-up Fixes (Mar 5 2026, commit `ab43e4823d`)
1. **EffectEquipTransmogOutfit ViewedOutfit sync**: Added `SetEquipmentSet()` call in SpellEffects.cpp — was the only outfit-apply path missing ViewedOutfit sync (spell effect 347 delegates to ApplyTransmogOutfitToPlayer but never persisted the ViewedOutfit update)
2. **Situations parser consistency**: Fixed early-return in TransmogrificationPackets.cpp to use proper ParseError handling instead of silent return

### Remaining
- **Stale detection false positive**: FIXED (commit `0cde8db70c`) — moved from client-side to server-side rejection with source tagging
- **All 26 audit items COMPLETE** — system ready for in-game testing
- DB persistence: `item_instance_transmog` rows have correct IMAIDs
- Server-side IMAID→DisplayType lookup routes all slots correctly

### Fixed Mar 3 2026 (session 30)
- **Pad byte 0x80**: Relaxed parser — client sends 0x80, not 0x00. Removed equality check
- **Secondary shoulder triple-overwrite**: ordinal 3 = secondary, ordinals 1-2 = primary (first wins)
- **Hidden appearances**: TransmogBridge nil detection + ALWAYS_NIL_SLOTS
- **Naked paperdoll**: ClearDynamicUpdateFieldValues for ViewedOutfit.Slots + .Situations

### Fixed Mar 4 2026 (session 36)
- **fillOutfitData bootstrap fix**: Gate bootstrap on IgnoreMask bit SET (ignored slots only). Bridge-cleared slots (IgnoreMask CLEAR) skip bootstrap → ViewedOutfit gets 0 instead of stale IMAID from equipped item

### Fixed Mar 5 2026 (session 52+)
Based on retail Ymir sniffer analysis (2.77M-line parsed dump, ground truth):
- **Reverted DT=3 assignment**: DT=3 means "apply hidden visual IMA" with a real hidden IMA ID (77344=head, 77343=shoulder, etc). DT=3+IMA=0 does NOT exist on retail. Reverted to simple `(imaID > 0) ? 1 : 0`
- **Reverted last-group-only merge**: Retail sends exactly 30 entries (12 armor + 18 weapon options), not accumulated groups. Restored first-non-zero-wins precedence
- **IgnoreMask repair pass**: Added recalculation in `fillOutfitData` from actual `Appearances[]` data (slot with IMAID=0 → set IgnoreMask bit, slot with IMAID>0 → clear IgnoreMask bit)
- **30-entry ViewedOutfit**: Expanded `fillOutfitData` slotMap from 14 to 30 entries. Weapon option entries (option 1-8) emit empty placeholders (IMAID=0, DT=0, SlotOption=optionIndex). Added DT=12 (ranged) to DisplayTypeToEquipSlot. Renamed TransmogOutfitSlotEntry::Flags→Option. Root cause fix for growing packet bug (Bugs A, C, D)

### Fixed Mar 5 2026 (session 70 — hidden DT + paired weapon)
Based on audit pass 2 (`doc/transmog_audit_pass2.md`):
- **Hidden appearance detection**: Added `isHiddenAppearance` lambda in `fillOutfitData` using ItemID-based detection (10 hidden items from CollectionMgr's hiddenAppearanceItems[]). DT=3 now correctly emitted for hidden slots (was always DT=1)
- **Paired weapon DT=4**: Options 5-8 on MH/OH (OptionEnum 8-11, Flags=2 paired cross-references) now emit ADT=4 + IDT=4 ("not applicable") instead of blanket DT=0
- **Consolidated diagnostic logging**: One log line per slot with classification tag (assigned/hidden/empty/placeholder-not-applicable)
- Hidden Cloak (IMA 77345) has ItemDisplayInfoID=146518, NOT 0 — ItemDisplayInfoID==0 cannot detect all hidden items. ItemID-based detection is correct approach
- Commit `8d36580ac4`

### Fixed Mar 5 2026 (session 72 — corrective pass, retail behavioral model)
Based on updated retail packet analysis (all confidence levels now HIGH):
- **isStored parameter**: `fillOutfitData` lambda now takes `bool isStored` to distinguish stored TransmogOutfits from live ViewedOutfit
- **ADT fix**: Assigned rows always ADT=1 (both contexts). Viewed empty rows = ADT=2/IDT=2. Stored empty = ADT=0/IDT=0. Previous code wrongly used `isStored ? 1 : 2` for assigned
- **Bootstrap guard**: Bootstrap from equipped items now only runs for viewed outfits (`!isStored`). Stored outfits keep empty slots as 0/0
- **SlotOption fix**: Uses `mapping.option` (wire index 0-8) instead of visual classification (0/1/3)
- **Stamped options**: Real `MainHandOption`/`OffHandOption` enum values instead of booleans
- **Paired threshold**: `mapping.option >= 5` (was >= 6)
- Commit `7bb510359b`

### Open Bugs Under Investigation (Mar 5 2026)
5 bugs found during testing, diagnostic build deployed with reverted logic. The DT=3 and last-group-only reverts address the root cause of the growing packet issue:

**Bug A**: Paperdoll strips naked on second UI reopen (first open correct, second naked)
- **Hypothesis**: Something triggers `_SyncTransmogOutfitsToActivePlayerData` between opens, clearing+rebuilding ViewedOutfit incorrectly
- **Diagnostic added**: Entry log on `_SyncTransmogOutfitsToActivePlayerData` showing invocation count and entries cleared

**Bug B**: Outfit with no head/shoulders defined → old head/shoulder appearances persisted (Back DID clear correctly)
- HEAD is index 0 in both client and server slot mappings, so NOT an index mismatch
- **Diagnostic added**: Per-slot CLEARING/CHANGING log in ApplyTransmogOutfitToPlayer Phase 3

**Bug C**: Monster Mantle shoulder (Item 182306) ghost appearance on paperdoll — never selected by user

**Bug D**: Draenei lower leg geometry disappeared on outfit q1 but not q2

**Bug E (CRITICAL)**: Single wand transmog reverted entire character's transmog to old state
- **ROOT CAUSE CONFIRMED**: `HandleTransmogrifyItems` → `SetEquipmentSet` (line 582) → `_SyncTransmogOutfitsToActivePlayerData` → `fillOutfitData` = full ViewedOutfit clear+rebuild from saved outfit data. Single-item transmog inadvertently rebuilds ALL slots.
- **Call chain**: HandleTransmogrifyItems syncs only changed slot(s) into outfit struct (lines 501-574), then calls SetEquipmentSet → full ViewedOutfit rebuild. If saved outfit data is stale for other slots, they revert.
- **NOT YET FIXED** — diagnostic logging deployed, awaiting test data
- **Diagnostics added**: Entry log ("SINGLE-ITEM transmog fired"), pre-SetEquipmentSet per-slot dump of outfit state

### Diagnostic Build (deployed Mar 4 2026, session 36, updated with reverts Mar 5)
Files modified with diagnostic logging:
1. `TransmogrificationHandler.cpp` — post-reapply per-slot dump, HandleTransmogrifyItems entry+sync logs, DT=3 revert, last-group-only revert
2. `Player.cpp` — fillOutfitData canary (CLEAR-SKIP), _SyncTransmogOutfitsToActivePlayerData entry log, IgnoreMask repair pass
3. `TransmogrificationUtils.cpp` — per-slot CLEARING/CHANGING log in ApplyTransmogOutfitToPlayer

**Test plan**: Bug B first (apply outfit with no head/shoulders), then Bug E separately (single wand transmog). Debug.log truncated for clean capture.

### Comprehensive QA Audit (Mar 4 2026, session 34)
Full 5-agent audit of all transmog C++, DB state, and logs. Key findings:

**HIGH — needs fix:**
- **H1**: `spell_clear_transmog.cpp` doesn't sync cleared state to active outfit or rebuild ViewedOutfit → paperdoll shows stale data after cast
- **H2**: Backslash "comments" (`\` instead of `//`) in TransmogrificationHandler.cpp lines ~759/925/978/1034 are actually C++ line continuations — fragile

**MEDIUM — should fix:**
- **M1**: `GetActiveTransmogOutfitID()` returns lowest SetID, not actually-applied one (wrong outfit synced)
- **M4**: Enchant illusions have no bootstrap from equipped items in `fillOutfitData` — illusions disappear from paperdoll
- **M5**: `validateAndStoreTransmogItem` doesn't null-check `GetItemTemplate()` result
- M2/M3 (reset clears ALL_SPECS, inconsistent illusion validation) — dead code paths since 12.x client never sends CMSG_TRANSMOGRIFY_ITEMS

**LOW:** ~400 lines dead HandleTransmogrifyItems code, no error packets, mixed tabs, signed shift, no rate limiting, unicode names

**DB state:** 156K IMA rows healthy. 2 orphaned IMA entries (items 244391/265073). Zero transmog errors in logs.

## Missing Slots Investigation (Feb 27 2026) — CMSG_TRANSMOGRIFY_ITEMS

### Root Cause: `C_Transmog.ApplyAllPending()` Does Not Exist in 12.x

In 12.x (Midnight), the old per-slot transmog API was completely replaced:
- **Old API (pre-12.x)**: `C_Transmog.SetPending()` + `C_Transmog.ApplyAllPending()` → `CMSG_TRANSMOGRIFY_ITEMS`
- **New API (12.x)**: `C_TransmogOutfitInfo.SetPendingTransmog()` + `C_TransmogOutfitInfo.CommitAndApplyAllPending()` → `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS`

`C_Transmog.ApplyAllPending()` **does not exist** in the 12.x client. `C_Transmog.SetPending()` still exists for UI preview only — no corresponding apply function. Both Blizzard's base UI and BetterWardrobe exclusively use `CommitAndApplyAllPending()`.

**`CMSG_TRANSMOGRIFY_ITEMS` is dead code on the server** — the client will never send it. Our `HandleTransmogrifyItems` handler (line 159-567 in TransmogrificationHandler.cpp) including its outfit sync-back logic is unreachable.

### Evidence: Slots Missing from CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS

Analyzed 4 packets (slotCount=14,28,42,56) from debug log. In ALL packets and ALL situation variants:
- **Ordinal 1** (HEAD, DT=0): IMAID=0 or wrong IMAID (shoulder placed here)
- **Ordinals 11-12** (BACK DT=9, TABARD DT=10): IMAID=0
- **Ordinals 13-14** (MH DT=11, OH DT=13/15): IMAID=0

The client's C++ serializer for `CommitAndApplyAllPending()` only includes slots with DisplayType 1-8 (shoulder through hands). HEAD(0), BACK(9), TABARD(10), MH(11), OH(13/15) are omitted from the wire data.

### What Was Ruled Out
- **BetterWardrobe**: NOT interfering. Calls same `CommitAndApplyAllPending()` API. `SetPendingTransmog()` IS called for HEAD and weapons — the Lua side works correctly
- **Opcode registration**: `CMSG_TRANSMOGRIFY_ITEMS` IS registered at `Opcodes.cpp:1107` — just never received
- **NPC config**: Warpweaver Taxoss (201312) correctly has `UNIT_NPC_FLAG_TRANSMOGRIFIER` + gossip option 34
- **TransmogrifyDisabledSlotMask=896**: Only disables FEET/WRIST/HANDS — not HEAD/MH/OH
- **GameRule TransmogEnabled**: Active

### Current DB State (character guid=7, outfit setindex=1)
- `appearance0` (HEAD) = **0** — never set
- `appearance2` (SHOULDERS) = 297499 — working
- `appearance3-9` = populated (various armor) — working
- `appearance14` (BACK) = 304250 — set by earlier packet, preserved by merge
- `appearance15` (MH) = **0** — never set
- `appearance16` (OH) = **0** — never set
- `ignore_mask` = 244739 (0x3BB03): HEAD, MH, OH, NECK, RINGS, TRINKETS, RANGED ignored

### Proposed Fix: Read Equipped Item Modifiers

Since the client omits these slots, the server should fill them in from the player's currently equipped items during `HandleTransmogOutfitUpdateSlots`. After the per-slot merge (line 714):

```cpp
// For slots the packet didn't provide AND the existing outfit doesn't have,
// check the player's equipped items for active transmog modifiers.
for (uint8 slot : {EQUIPMENT_SLOT_HEAD, EQUIPMENT_SLOT_BACK, EQUIPMENT_SLOT_TABARD,
                    EQUIPMENT_SLOT_MAINHAND, EQUIPMENT_SLOT_OFFHAND})
{
    if (updatedSet.Appearances[slot] == 0)
    {
        if (Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot))
        {
            uint32 transmogId = item->GetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_ALL_SPECS);
            if (transmogId)
            {
                updatedSet.Appearances[slot] = int32(transmogId);
                updatedSet.IgnoreMask &= ~(1u << slot);
            }
        }
    }
}
```

Also apply same logic in `HandleTransmogOutfitNew` (line 570-605) for initial outfit creation.

### DB2 Reference: TransmogOutfitSlotInfo
14 entries defining outfit slot positions. Key columns: ID (1-14), TransmogOutfitSlotEnum (ordering), InventorySlotEnum, InventorySlotID
- ID 1: HEAD (enum 0)
- ID 2-3: SHOULDER primary/secondary (enum 1-2)
- ID 4: SHIRT (enum 6)
- ID 5: CHEST (enum 4)
- ID 6-8: WAIST/LEGS/FEET (enum 9-11)
- ID 9-10: WRIST/HANDS (enum 7-8)
- ID 11: BACK (enum 3)
- ID 12: TABARD (enum 5)
- ID 13-14: MH/OH (enum 12-13) — have Flags=3 and TransmogCollectionType=0

### TransmogOutfitSlotOption DB2
18 entries for weapon sub-options (1H, dagger, 2H, shield, OH, ranged, fury 2H). Only applies to MH (ID 13) and OH (ID 14) slots.

---

## 5-Agent Audit Action Plan (Session 62, Mar 5 2026)

Full audit across TransmogBridge, TransmogSpy, server handlers, Player.cpp, and retail sniffer data.

### Retail Sniffer Data
- **Location**: `C:\Users\atayl\OneDrive\Desktop\ymir_retail_12.0.1.66220\dumps\`
- 118 MB parsed text, 2.77M lines, 3 complete outfit update cycles
- Confirms 30-entry format, DT routing, empty weapon option encoding
- **Missing**: outfit create/rename/delete, single-item transmog, situations -- need another capture

### Phase 1: Server Bug Fixes (4 items) -- DONE (`20c9a0ea23`)

| # | Severity | File:Line | Description | Status |
|---|---|---|---|---|
| 1 | MEDIUM | Player.cpp:18168 | Per-spec modifier check before ALL_SPECS in bootstrap | DONE |
| 2 | HIGH | TransmogrificationHandler.cpp:~648 | `HandleTransmogOutfitNew` + `SetActiveTransmogOutfitID` | DONE |
| 3 | MEDIUM | TransmogrificationHandler.cpp:~1090 | `FinalizeTransmogBridgePendingOutfit` UpdateField flush | DONE |
| 4 | MEDIUM | spell_clear_transmog.cpp:~105 | Clear spell resets `_activeTransmogOutfitID` to 0 | DONE |

### Phase 2: TransmogBridge Cleanup (4 items) -- DONE (`20c9a0ea23`)

| # | Severity | Line | Description | Status |
|---|---|---|---|---|
| 5 | HIGH | 236 | Multi-part split: bail out if no semicolon boundary + part2 overflow check | DONE |
| 6 | HIGH | 179-204 | Dead code removed: Layer 2 re-check in nil-detection was unreachable | DONE |
| 7 | MEDIUM | 88-89 | Diagnostic probe removed (~45 lines) | DONE |
| 8 | LOW | 210 | Deterministic `for slot=0,13` replaces `pairs(merged)` | DONE |

### Phase 3: TransmogSpy v2 Rewrite (12 items) -- DONE (`1dfc2eb207`)

All 12 items implemented. 944 -> 1317 lines (+373). 17 slash commands total.

| # | Description | Status |
|---|---|---|
| 9 | Added TRANSMOGRIFY_OPEN/CLOSE, TRANSMOG_OUTFITS_CHANGED events + NPC state tracking | DONE |
| 10 | displayType + warningText/errorText captured, DTLabel() helper | DONE |
| 11 | GetActiveOutfitID + GetCurrentlyViewedOutfitID in CaptureAllSlots + /tspy status | DONE |
| 12 | IMA->name via GetSourceInfo: ResolveIMA() + FormatIMA() helpers | DONE |
| 13 | 6 new hooks: ChangeViewedOutfit, ChangeDisplayedOutfit, AddNewOutfit, CommitOutfitInfo, RevertPendingTransmog, SetSecondarySlotState | DONE |
| 14 | Illusion tracking via TransmogType.Illusion in CaptureSlotState | DONE |
| 15 | /tspy status: NPC state, active/viewed outfit, pending count, cost, config | DONE |
| 16 | /tspy bridge: 3-layer merge simulation (L1+L3, L2 bridge-only) | DONE |
| 17 | /tspy resolve N: name, quality, visual, category, collected, sourceType | DONE |
| 18 | /tspy items: equipped items with base/xmog/pending/illusion | DONE |
| 19 | baseSourceID/baseVisualID captured from GetSlotVisualInfo | DONE |
| 20 | Button paths fixed: TransmogFrame.OutfitCollection.SaveOutfitButton + SituationsFrame.ApplyButton | DONE |

### Phase 4: Hardening (6 items) -- 4 DONE, 2 SKIPPED (`c8df50eddd`)

| # | Severity | Description | Status |
|---|---|---|---|
| 21 | HIGH | Baseline restore: IgnoreMask bits + Enchants from savedOutfit | DONE |
| 22 | MEDIUM | Clear stale `_transmogBridgePartialPayload` on non-multi-part | DONE |
| 23 | HIGH | 3-part handler for >506 byte payloads | SKIP (Phase 2 client bail-out sufficient, max ~294 bytes) |
| 24 | LOW-M | Illusion bootstrap clear-enchant edge case | SKIP (can't distinguish without schema change) |
| 25 | LOW | `_SyncTransmogOutfitsToActivePlayerData` on spec switch | DONE |
| 26 | MEDIUM | Per-slot validation: zero bad slots instead of rejecting outfit | DONE |

### Phase 5: Additional Retail Capture
- Run another Ymir session covering: outfit create, rename, delete, single-item transmog, situations
- Compare packet-for-packet against our implementation

### Audit False Positives (noted for reference)
- TransmogSpy "slot numbering wrong" -- FALSE POSITIVE. API uses client slot indices (0-13 with 2=secondary shoulder), NOT Enum.TransmogSlot (0-12). Both addons use correct numbering.
- Server H2 "enchant baseline restore missing" -- safe due to `*existingSet` copy initialization, but fragile.

### Key Audit Commits
- `0cde8db70c` -- server-side stale rejection (FromHook source tagging)
- `8ffb041b42` -- docs sync
- `20c9a0ea23` -- Phase 1+2: 4 server bug fixes + 4 bridge cleanup items
- `1dfc2eb207` -- Phase 3: TransmogSpy v2 rewrite (12 items, 944->1317 lines)
- `c8df50eddd` -- Phase 4: 4 hardening items (baseline IgnoreMask+Enchants, stale partial, spec resync, per-slot validation)

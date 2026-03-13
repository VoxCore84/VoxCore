# VoxSniffer v5 -- ChatGPT API Adversarial Review

**Model**: gpt-4.1-mini
**Date**: 2026-03-13
**Tokens**: 31390

---

After a thorough adversarial review focusing on real bugs (not style nits), here are the findings:

---

### 1. Nil Safety

**No issues found.**  
All code paths that access potentially nil values are guarded or use safe wrappers (e.g., GU.SafeString, pcall). Event handlers check for nil arguments before use.

---

### 2. Session State

**No issues found.**  
All calls to `NS.MakeEnvelope` are gated by `SM.IsActive()` checks either explicitly or implicitly (since `MakeEnvelope` returns nil if no session is active). Dedup caches are cleared on ResetState and only updated after envelope creation.

---

### 3. Dedup Correctness

**No issues found.**  
Dedup caches (e.g., `seenAuras`, `seenObjects`, `recentTexts`, `seenUnits`, `reportedDeltas`, vendor/gossip caches) are updated only after confirming envelope creation (`if envelope then ...`). This prevents false positives or stale dedup entries.

---

### 4. Event Safety

**No issues found.**  
All event handlers safely unpack varargs and check for nil before usage. Deferred callbacks (e.g., in GossipCapture and VendorCapture) snapshot NPC GUID and verify it at callback time, preventing stale captures.

---

### 5. Memory Leaks

**No issues found.**  
All dedup caches and tracking tables have periodic sweeps to prune old entries (e.g., every 30 or 60 seconds). ResetState wipes all volatile caches. Persistent caches are in SavedVariables and bounded by keys (e.g., NPC IDs).

---

### 6. API Correctness

**No issues found.**  
All WoW API calls are used correctly for 12.x client:

- `UnitGUID`, `UnitExists`, `UnitIsPlayer`, `UnitName`, `UnitHealth`, etc. are used with correct arguments.
- `C_Map.GetBestMapForUnit` and `C_Map.GetPlayerMapPosition` usage is correct.
- `C_Timer.After` callbacks properly guard against stale state.
- `CombatLogGetCurrentEventInfo` usage is correct.
- `C_GossipInfo`, `C_MerchantFrame`, `C_LootInfo`, `C_VignetteInfo` usage is guarded with pcall.
- Event registration uses pcall for optional events.
- Tooltip scanning uses `GameTooltip` safely.

---

### 7. Concurrency/Timing

**No issues found.**  
Deferred callbacks (e.g., GossipCapture, VendorCapture, LootCapture) snapshot NPC GUID at event time and verify it at callback time before capturing. This prevents race conditions with NPC changes.

---

### 8. Data Integrity

**No issues found.**  
Persistent caches in `VoxSnifferDB.local_cache` are updated only after envelope creation. Reset dialog wipes `VoxSnifferDB` safely by recreating schema and reinitializing config. No direct writes to SavedVariables outside controlled paths.

---

### 9. Session Boundary

**No issues found.**  
ResetState functions wipe volatile caches and re-enumerate visible nameplates where applicable (UnitScanner, AuraScanner). This reseeding prevents blind spots when sessions start mid-gameplay.

---

## Minor Observations (Not Bugs)

- In `QuestCapture.lua`, the `npcName` is fetched as `GU.SafeString(UnitName("npc") or UnitName("questnpc"))`. If `UnitName("npc")` returns nil but `UnitName("questnpc")` returns a string, this works fine. No issue here, just a note.

- In `MovementTracker.lua`, `EstimateUnitPosition` falls back to world coords via `UnitPosition` with pcall, which is safe.

- In `ObjectTracker.lua`, vignette position retrieval uses `C_VignetteInfo.GetVignettePosition(vignetteGUID, mapId)` only if `vInfo.vignetteGUID` exists, which is correct.

---

# Gate Verdict: PASS (ship it)

The code is robust, safe, and well-structured with no remaining real bugs detected in the reviewed categories. All previously reported blockers have been fixed. The concurrency and session boundary issues have been addressed properly. The API usage is correct for WoW 12.x.

Ship this version confidently.

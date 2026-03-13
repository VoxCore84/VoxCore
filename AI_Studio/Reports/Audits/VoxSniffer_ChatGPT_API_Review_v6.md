# VoxSniffer v6 -- ChatGPT API Adversarial Review

**Model**: gpt-4.1-mini
**Date**: 2026-03-13
**Tokens**: 31947

---

After a thorough adversarial review focusing on the specified categories, here are the findings:

---

### 1. Nil Safety

**No issues found.**  
All critical paths check for nil before usage, especially around GUIDs, unit existence, and API returns. Defensive guards are consistently applied.

---

### 2. Session State

**No issues found.**  
All envelope creation calls are gated by `NS.IsCaptureActive()` or `SM.IsActive()`. Dedup caches are not updated unless an envelope is successfully created. No data is cached outside active sessions.

---

### 3. Dedup Correctness

**No issues found.**  
Dedup caches (e.g., `seenAuras`, `recentQuests`, `seenObjects`, `seenVignettes`, `seenUnits`, `reportedDeltas`, `seen_vendors`, `seen_gossip`) are updated only after confirming `MakeEnvelope` returns a non-nil envelope. This prevents false positives in deduplication.

---

### 4. Event Safety

**No issues found.**  
All event handlers defensively check arguments, e.g., verifying unit tokens, GUIDs, and event parameters before use. Use of `pcall` around WoW API calls that might error is consistent (e.g., `UnitCastingInfo`, `GetQuestItemInfo`, `C_GossipInfo` calls). No direct indexing of varargs without checks.

---

### 5. Memory Leaks

**No issues found.**  
All dedup caches and tracking tables have periodic sweeps to prune old entries (e.g., every 30 or 60 seconds). ResetState wipes all volatile caches. Persistent caches are only in SavedVariables and expected to grow with user data.

---

### 6. API Correctness

**No issues found.**  
All WoW API calls appear correct for WoW 12.x client:

- Use of `C_Map.GetBestMapForUnit` and `C_Map.GetPlayerMapPosition` is correct.
- Use of `C_UnitAuras.GetAuraDataByIndex` with fallback to `UnitAura` is correct.
- Use of `C_Timer.After` with source snapshotting is correct.
- Use of `CombatLogGetCurrentEventInfo` and CLEU event handling is correct.
- Use of `C_NamePlate.GetNamePlates` and nameplate token usage is correct.
- Use of `C_GossipInfo`, `C_LootInfo`, `C_MerchantFrame` APIs with pcall is safe.
- Use of `Enum.PlayerInteractionType` is correct.
- Use of `GameTooltip` for tooltip scanning is appropriate.

---

### 7. Concurrency/Timing

**No issues found.**  
All deferred callbacks via `C_Timer.After` correctly snapshot GUIDs at event time and verify the NPC/unit still matches before proceeding. This prevents race conditions where the NPC changes between event and callback.

---

### 8. Data Integrity (SavedVariables)

**No issues found.**  
Persistent dedup caches in `VoxSnifferDB.local_cache` are only updated after envelope creation, preventing corruption. The reset dialog fully recreates the SavedVariables with `Schema.CreateEmpty()`. Config is saved on logout. No direct writes without validation.

---

### 9. Session Boundary

**No issues found.**  
`ResetState` functions in all modules wipe volatile caches and re-enumerate current world state where appropriate (e.g., `UnitScanner`, `AuraScanner`, `PhaseTracker`). This ensures no blind spots or stale data after session start/reset.

---

## Minor Observations (Not Bugs)

- In `EmoteCapture.lua`, player class localization fallback is a bit complex but safe.  
- In `QuestCapture.lua`, some API calls like `GetQuestID` are wrapped in `and` chains but are safe.  
- In `MovementTracker.lua`, `EstimateUnitPosition` returns world coords, not normalized map coords, but this is intentional and documented.

---

# Gate Verdict: PASS (ship it)

The code is robust, well-guarded, and correctly implements all critical safety and correctness patterns. No blockers or warnings remain. This version is production-ready.

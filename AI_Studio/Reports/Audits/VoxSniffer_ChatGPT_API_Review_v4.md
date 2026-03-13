# VoxSniffer v4 — ChatGPT API Adversarial Review

**Model**: gpt-4.1-mini
**Date**: 2026-03-13
**Tokens**: 31599

---

Reviewing the provided VoxSniffer v4 code and all 14 modules against the specified categories, here are the findings:

---

### 1. Nil Safety

**No critical nil safety issues found.**  
- All calls to WoW API functions that can return nil are guarded (e.g., `UnitGUID`, `UnitExists`, `C_Map.GetPlayerMapPosition`).  
- `MakeEnvelope` returns nil if no session active, and callers check for nil before pushing to buffers.  
- Event handlers check for nil arguments before use.  
- Use of `pcall` around potentially tainted or error-prone WoW API calls is consistent.

---

### 2. Session State

**No session state leaks found.**  
- `MakeEnvelope` gates on active session.  
- Dedup caches that are persistent live in `VoxSnifferDB.local_cache` and are only reset on full reset.  
- Volatile dedup caches are wiped on `ResetState`.  
- Deferred callbacks (via `C_Timer.After`) check `moduleEnabled` and `NS.IsCaptureActive()` before proceeding, preventing data capture outside sessions.

---

### 3. Dedup Correctness

**No dedup-before-envelope issues found.**  
- Dedup caches are updated only after confirming `MakeEnvelope` returned a non-nil envelope.  
- Example: In `AuraScanner`, `seenAuras[dedupKey] = now` is set only after envelope creation confirmed.  
- In `VendorCapture` and `GossipCapture`, persistent dedup caches are updated only after envelope creation.  
- No dedup cache updated prematurely.

---

### 4. Event Safety

**No event handler argument errors found.**  
- All event handlers check for expected arguments before use.  
- Use of `...` in event handlers is consistent with expected event signatures.  
- Defensive checks on unit tokens and GUIDs are present.  
- `pcall` used around API calls that may error due to taint or missing data.

---

### 5. Memory Leaks

**No unbounded table growth without cleanup found.**  
- Dedup caches have periodic sweeps to remove stale entries (`SweepDedup` functions).  
- Active nameplate tables and unit tracking tables are wiped on `ResetState` and pruned periodically.  
- Persistent caches in SavedVariables are expected to grow but are controlled by dedup fingerprints and replaced on full reset.  
- No unbounded growth without cleanup.

---

### 6. API Correctness

**No incorrect WoW API usage found for 12.x client.**  
- Use of `C_Map.GetBestMapForUnit`, `C_Map.GetPlayerMapPosition`, `UnitGUID`, `UnitExists`, `UnitIsPlayer`, `UnitHealth`, `UnitPower`, `UnitCastingInfo`, `UnitChannelInfo`, `CombatLogGetCurrentEventInfo`, `C_Timer.After`, `GetSpellInfo`, `GetMerchantNumItems`, `GetLootSlotInfo`, `GetLootSlotLink`, `GetLootSlotType`, `GetMerchantItemInfo`, `GetMerchantItemLink`, `GetMerchantItemCostInfo`, `GetMerchantItemCostItem`, `C_GossipInfo` functions are all correct and guarded.  
- Use of `pcall` around potentially tainted or error-prone calls is consistent.  
- Use of `Enum.PlayerInteractionType` is correct for 12.x.  
- No deprecated or removed APIs used without fallback.

---

### 7. Concurrency/Timing

**One minor concurrency/timing issue found:**

- **File:** Modules/GossipCapture.lua  
- **Line snippet:**
  ```lua
  eventFrame:SetScript("OnEvent", function(_, event, ...)
      if event == "GOSSIP_SHOW" then
          C_Timer.After(0.1, function()
              if moduleEnabled and NS.IsCaptureActive() then CaptureGossipMenu() end
          end)
  ```
- **Problem:** The deferred callback waits 0.1s before calling `CaptureGossipMenu`. However, the player could have closed the gossip window or session stopped in that time. The code checks `moduleEnabled` and `NS.IsCaptureActive()`, which is good, but it does not check if the gossip window is still open or if the NPC is still valid. This could cause `CaptureGossipMenu` to run when the gossip UI is no longer valid, potentially causing nil or stale data capture or errors.

- **Suggested fix:** Add an explicit check inside the deferred callback to verify that the gossip UI is still open and the NPC unit exists before capturing. For example:
  ```lua
  C_Timer.After(0.1, function()
      if moduleEnabled and NS.IsCaptureActive() and UnitExists("npc") and GossipFrame and GossipFrame:IsShown() then
          CaptureGossipMenu()
      end
  end)
  ```
  Or check `C_GossipInfo.IsActive()` if available.

**Note:** Similar pattern is used for `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` event in the same module and in `VendorCapture.lua` with 0.2s delay. The same check should be applied there as well.

---

### 8. Data Integrity (SavedVariables)

**No data corruption paths found.**  
- Persistent dedup caches are updated only after envelope creation confirmed.  
- Full reset wipes SavedVariables safely via `Schema.CreateEmpty()`.  
- Config saved on logout.  
- No direct writes to SavedVariables without validation.  
- No partial writes or inconsistent states observed.

---

## Summary of Issues

| Severity | File                  | Code Snippet (approximate)                                                                 | Explanation                                                                                   | Suggested Fix                                                                                              |
|----------|-----------------------|--------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| WARNING  | Modules/GossipCapture.lua | ```lua C_Timer.After(0.1, function() if moduleEnabled and NS.IsCaptureActive() then CaptureGossipMenu() end end) ``` | Deferred capture may run after gossip window closed or NPC gone, causing stale or invalid data capture. | Add explicit check that gossip UI is still open and NPC unit exists before capturing.                      |
| WARNING  | Modules/VendorCapture.lua | ```lua C_Timer.After(0.2, function() if moduleEnabled and NS.IsCaptureActive() then CaptureVendorInventory() end end) ``` | Same deferred capture pattern without verifying vendor UI still active or NPC valid.            | Add explicit check that vendor UI is still open and NPC unit exists before capturing.                      |

---

## Gate Verdict

**CONDITIONAL PASS**

The only issues are minor concurrency/timing warnings related to deferred capture callbacks in `GossipCapture` and `VendorCapture` modules. These can cause stale or invalid data capture but are unlikely to cause crashes or data corruption.

Fixing these by adding UI and unit existence checks before capture in deferred callbacks is recommended before shipping.

All other categories are clean.

---

# Detailed Recommendations

- In `Modules/GossipCapture.lua`, modify deferred callbacks to:

```lua
C_Timer.After(0.1, function()
    if moduleEnabled and NS.IsCaptureActive() and UnitExists("npc") and (C_GossipInfo and C_GossipInfo.IsActive and C_GossipInfo.IsActive()) then
        CaptureGossipMenu()
    end
end)
```

- In `Modules/VendorCapture.lua`, similarly:

```lua
C_Timer.After(0.2, function()
    if moduleEnabled and NS.IsCaptureActive() and UnitExists("npc") and MerchantFrame and MerchantFrame:IsShown() then
        CaptureVendorInventory()
    end
end)
```

If `C_GossipInfo.IsActive` or `MerchantFrame:IsShown` are not reliable, at least check `UnitExists("npc")` to reduce stale captures.

---

No other issues found.

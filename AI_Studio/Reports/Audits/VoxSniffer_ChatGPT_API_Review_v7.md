# VoxSniffer v7 -- ChatGPT API Adversarial Review

**Model**: gpt-4.1-mini
**Date**: 2026-03-13
**Tokens**: 32597

---

After a thorough adversarial review of the provided VoxSniffer v7 codebase, focusing on the specified categories and ignoring all previously confirmed false positives, I found the following REAL issues:

---

### 1. Nil Safety

**No new nil safety issues found.**  
All critical WoW API calls and table accesses are guarded or pcall-wrapped where appropriate. Event handlers defensively check arguments.

---

### 2. Session State

**No issues found.**  
All envelope creation is gated by `SM.IsActive()`. Dedup caches are cleared on ResetState and not used outside active sessions.

---

### 3. Dedup Correctness

**No issues found.**  
All dedup caches are updated only after confirming envelope creation (`if envelope then ...`), no premature marking.

---

### 4. Event Safety

**No issues found.**  
All event handlers defensively check arguments, and use pcall where needed. No direct indexing of varargs without checks.

---

### 5. Memory Leaks

**No unbounded growth without cleanup found.**  
All dedup caches and tracking tables have periodic sweeps or are wiped on ResetState. Scheduler callbacks unregister on Disable.

---

### 6. API Correctness

**Issue 1: VendorCapture - Incorrect use of `C_MerchantFrame.GetItemInfo`**  
- **File/Line:** Modules/VendorCapture.lua, lines around vendor item capture loop (~line 70-100)  
- **Code snippet:**
  ```lua
  if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
      local ok, info = pcall(C_MerchantFrame.GetItemInfo, i)
      if ok and info then
          item = {
              slot = i,
              name = info.name,
              price = info.price,
              stackCount = info.stackCount,
              numAvailable = info.numAvailable,
              isPurchasable = info.isPurchasable,
              isUsable = info.isUsable,
              hasExtendedCost = info.hasExtendedCost,
              currencyID = info.currencyID,
              isQuestItem = info.isQuestStartItem,
          }
      end
  end
  ```
- **Why it's a problem:**  
  The WoW 12.x API does not have a global `C_MerchantFrame` table or `GetItemInfo` method on it. The correct API for merchant items is `C_MerchantFrame` does not exist; instead, the global functions `GetMerchantItemInfo`, `GetMerchantItemLink`, etc. are used. This code attempts to call a non-existent method, which will always fail and fallback to the classic API, potentially missing data on modern clients.

- **Suggested fix:**  
  Remove or replace the `C_MerchantFrame.GetItemInfo` block with the correct modern API calls. If Blizzard introduced a new API, it should be `C_Merchant` or similar, but as of 12.x, merchant item info is accessed via global functions. Use `GetMerchantItemInfo` and related functions only.

---

### 7. Concurrency/Timing

**Issue 2: GossipCapture and VendorCapture deferred callbacks missing source GUID re-check**  
- **File/Lines:**  
  - Modules/GossipCapture.lua, event handler for `GOSSIP_SHOW` and `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` (~line 140-160)  
  - Modules/VendorCapture.lua, event handler for `MERCHANT_SHOW` and `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` (~line 140-160)  
- **Code snippet (GossipCapture):**
  ```lua
  eventFrame:SetScript("OnEvent", function(_, event, ...)
      if event == "GOSSIP_SHOW" then
          local npcGuid = UnitGUID("npc")
          C_Timer.After(0.1, function()
              if moduleEnabled and NS.IsCaptureActive() and UnitExists("npc") then CaptureGossipMenu(npcGuid) end
          end)
      elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
          local interactionType = ...
          if interactionType == Enum.PlayerInteractionType.Gossip then
              local npcGuid = UnitGUID("npc")
              C_Timer.After(0.1, function()
                  if moduleEnabled and NS.IsCaptureActive() and UnitExists("npc") then CaptureGossipMenu(npcGuid) end
              end)
          end
      end
  end)
  ```
- **Why it's a problem:**  
  The deferred callback captures `npcGuid` at event time but does not re-verify that the NPC GUID is still the same at callback time. The code checks `UnitExists("npc")` but the unit could be a different NPC now, causing data to be captured for the wrong NPC or stale data.

- **Suggested fix:**  
  Inside the deferred callback, re-check that `UnitGUID("npc") == npcGuid` before calling `CaptureGossipMenu(npcGuid)`. If not equal, abort the capture.

- **Same applies to VendorCapture deferred callback.**

---

### 8. Data Integrity

**No issues found.**  
SavedVariables are accessed safely, dedup caches are stored in `VoxSnifferDB.local_cache` with proper initialization, and full reset wipes the DB safely.

---

### 9. Session Boundary

**No issues found.**  
ResetState functions wipe volatile caches and re-enumerate current world state (e.g., nameplates) to reseed tracking tables, avoiding blind spots at session start.

---

## Summary of Issues

| Severity | File                      | Description                                                                                   | Suggested Fix                                                                                  |
|----------|---------------------------|-----------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------|
| WARNING  | Modules/VendorCapture.lua  | Incorrect use of non-existent `C_MerchantFrame.GetItemInfo` API                               | Remove or replace with correct WoW 12.x merchant item APIs (`GetMerchantItemInfo` etc.)        |
| WARNING  | Modules/GossipCapture.lua  | Deferred callback missing NPC GUID re-check before capture                                   | Re-check `UnitGUID("npc") == npcGuid` inside deferred callback before capturing               |
| WARNING  | Modules/VendorCapture.lua  | Deferred callback missing NPC GUID re-check before capture                                   | Re-check `UnitGUID("npc") == npcGuid` inside deferred callback before capturing               |

---

## Gate Verdict

**CONDITIONAL PASS**

The issues are warnings, not blockers, but they can cause incorrect data capture or missed vendor data on modern clients. Fixing the VendorCapture API usage and adding source GUID verification in deferred callbacks for GossipCapture and VendorCapture is strongly recommended before shipping.

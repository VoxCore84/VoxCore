---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 3
reviewer: Claude
model: claude-sonnet-4-6
date: 2026-03-13T17:10:03.616521
elapsed_seconds: 138.1
---

# Cold-Read Review: TRIAD-VOXGM-V2-ENHANCEMENTS-V6

**Reviewer:** Cold-Read (Round 3 of this artifact's review cycle)
**Spec version:** Revision 6 (25 prior rounds across 5 cycles)

---

## Summary of Changes Since Prior Rounds

Revision 6 addresses a substantial backlog: the O(n²) lineBuffer trim is replaced with a new-table slice; timer nil-clear is kept in the callback; `VoxGM.Settings` namespace is added to Core.lua; script deletion/overwrite is name-based; shallow copy uses an explicit loop; Delete/Edit buttons are disabled during active runs; `Console:Toggle()` reads `VoxGMDB.ui.consoleEnabled` as source of truth; `ClearAllPoints` is mandated before re-anchoring; `EnableMouseWheel(true)` is added; parsers read `VoxGMDB` lazily; `onComplete` consumer is specified; `Tab_Appearance.lua` is added to Section 6; TOC append order is specified; VoxTip/VoxPlacer are marked "assumed"; and the Phase 0 doc path is normalized. These are meaningful fixes. The spec is now substantially tighter than prior revisions.

---

## Findings

### Implementation Bias

**[HIGH]** **`StaticPopup` `self.data` double-show race is documented but the fix is incomplete.** Section 7.6 notes: *"If the user triggers a second `StaticPopup_Show` for the same dialog while one is already visible, WoW returns the existing frame without updating `self.data`."* The spec then says this is "safe" because the name is stable. But for `VOXGM_SCRIPT_OVERWRITE`, `self.data` is the **imported script table** (not a string). If the user somehow triggers two rapid imports (e.g., double-click on an import button), the second call would silently fail to update `self.data`, and the first imported table would be used for both confirmations. The spec doesn't mandate debouncing the import trigger or disabling the import button while the popup is open. The "safe" claim only holds for the delete case (string name), not the overwrite case (mutable table reference).

**[HIGH]** **`Scripts:Run()` `onComplete` parameter is never specified at the call site.** Section 7.7 defines `Scripts:Run(scriptName, onComplete)` and says `onComplete` "re-enables Run button." Section 7.6 says "onComplete consumer specified (re-enables Run button)." But nowhere in the spec is the actual call to `Scripts:Run()` shown with the `onComplete` argument. The UI code that calls `Scripts:Run()` is not specified — the implementer must infer what closure to pass. If they forget, the Run button stays in "Stop" state after natural completion. This is a silent behavioral bug with no test in the acceptance criteria.

**[MEDIUM]** **`DispatchNext` cancel-race analysis is correct but the reset in `Cancel()` happens after the `active=false` set, creating a window.** In `Scripts:Cancel()`, step 3 sets `active=false`, step 4 calls `timerHandle:Cancel()`, step 6 resets runState. Between steps 3 and 6, if the timer callback fires (on a different tick — impossible in single-threaded Lua, but the spec's own reasoning about "between steps" suggests the author is thinking about coroutine-style interleaving), `DispatchNext` would see `active=false` and attempt to call `onComplete` (which is still set in runState). The spec says `onComplete` does NOT fire on cancellation, but the guard in `DispatchNext` step 2 calls `cb()` if `cb` is non-nil — it doesn't check whether cancellation occurred. This is a latent bug: if `DispatchNext` fires after `active=false` but before runState is fully reset, `onComplete` fires unexpectedly. **Fix:** Clear `runState.onComplete = nil` in `Cancel()` before or at the same time as `active=false`.

**[MEDIUM]** **`smf:GetNumMessages()` scroll-offset math for Copy Line overlay is underspecified.** Section 4.4 and 7.3 describe the overlay index computation as "`smf:GetNumMessages()` minus scroll offset plus visible line position." But `ScrollingMessageFrame` scroll offset is not a simple integer — it depends on `smf:GetScrollOffset()` (lines scrolled from bottom) and `smf:GetNumLinesDisplayed()`. The spec doesn't specify which API to use for scroll offset, doesn't handle the case where `GetNumMessages() < maxLines` (early in session), and doesn't handle the case where `lineBuffer` and SMF message count diverge (e.g., if `smf:Clear()` is called but `lineBuffer` is not wiped, or vice versa). The implementer is left to reverse-engineer the correct math from an incomplete description.

**[MEDIUM]** **`Console:OnMessage` appends raw `msg` to `lineBuffer` but displays `formatted` (with timestamp) in SMF.** Section 7.3: "Append raw `msg` to `Console.lineBuffer[]`." But the Copy Line overlay reads `button.messageText = Console.lineBuffer[computedIndex]` and puts it in an EditBox for Ctrl+C. Users copying a line will get the raw message without the timestamp they see on screen. This is a UX inconsistency — the spec should explicitly state whether `lineBuffer` stores raw or formatted strings, and the Copy Line behavior should match what's displayed.

**[MEDIUM]** **`Settings:Open()` hides "all tab content scrollframes" but the mechanism is unspecified.** Section 4.8: "Hide all tab content scrollframes (iterate `VoxGM.Tabs`, hide each content frame)." But `VoxGM.Tabs[tabId]` stores tab registration data — the spec doesn't confirm that each tab's content frame is accessible via a consistent field on the tab registration object (e.g., `VoxGM.Tabs[tabId].contentFrame`). If the existing tab system doesn't expose content frames this way, the implementer must either add that field to all existing tab registrations or find another mechanism. This is an implicit dependency on v1 internals that isn't verified.

**[LOW]** **`State:PruneScripts()` keeps the NEWEST entries (highest indices) but this is only correct if scripts are appended in chronological order.** The spec says "newest kept" and the implementation slices from `#scriptList - C.SCRIPT_MAX_SAVED + 1` to `#scriptList`. This assumes the array is ordered oldest-first. If `ConfirmOverwrite` replaces in-place (preserving position), an overwritten script retains its original position, which may not be the "newest" semantically. The spec doesn't address whether overwrite should move the script to the end of the list.

---

### Consistency

**[HIGH]** **`VoxGM.Settings:Open()` is called from Core.lua slash handler, but `Settings.lua` is specified to create a frame that hides tab content and shows a settings panel. However, `Settings:Open()` is never defined in the spec — only the panel lifecycle is described.** Section 4.8 describes the lifecycle steps. Section 7.11 says "Path B: In-addon panel." But the method name `Settings:Open()` appears in Core.lua's slash handler without a corresponding function signature in the Settings.lua specification. The implementer must infer the function name from the call site. This is fine for a single implementer but creates a contract gap.

**[MEDIUM]** **`DEFAULTS.scripts.throttleDelay = C.SCRIPT_THROTTLE_DEFAULT` is specified, but `C.SCRIPT_THROTTLE_DEFAULT` is defined in Constants.lua which loads BEFORE State.lua.** This is actually correct load order (Constants → State), but the spec never explicitly confirms this dependency is safe. Given that prior revisions had issues with load-order assumptions, this should be explicitly noted as "safe because Constants.lua loads before State.lua per TOC order." Currently the spec just says "references constant, not hardcoded" without the rationale.

**[MEDIUM]** **`Console:Toggle()` calls `VoxGM.UI:SetConsoleVisible(not VoxGMDB.ui.consoleEnabled)`, but `UI:SetConsoleVisible()` is specified to persist `VoxGMDB.ui.consoleEnabled`. This means the toggle reads the DB value, inverts it, and passes it to a function that writes it back. This is correct, but the spec also says `Console:Toggle()` "does NOT write to `VoxGMDB.ui.*` directly."** The concern: if `SetConsoleVisible` is called from somewhere other than `Toggle()` (e.g., Settings panel toggling the console enable checkbox), and that caller also reads `VoxGMDB.ui.consoleEnabled` to decide what to pass, there's a consistent pattern. But the Settings panel's console enable toggle is not shown calling `SetConsoleVisible` — it's shown as a `UI:CreateToggleButton(...)`. The spec doesn't specify what the toggle button's `onChanged` callback does. Does it call `SetConsoleVisible`? Write directly to DB? This is unspecified.

**[MEDIUM]** **Section 3 says "Parser init (v1 bug): called from `UI:Init()`... v2 MUST move this call into `Events:Init()`."** Section 6 Events.lua says "Move `Events:RegisterDefaultParsers()` call into `Events:Init()`." But Section 7.1 (Addon load sequence) lists `Events:Init()` under `ADDON_LOADED` and `UI:Init()` under `PLAYER_LOGIN`. If `RegisterDefaultParsers()` is moved to `Events:Init()` (ADDON_LOADED), parsers are registered before `VoxGMDB` exists (State:Init() also runs at ADDON_LOADED). The spec says parsers "read VoxGMDB lazily" to handle this, but the load order of `State:Init()` vs `Events:Init()` within ADDON_LOADED is not specified. If Events:Init() runs before State:Init(), `VoxGMDB` is nil at registration time — lazy reading saves the callback invocation, but any registration-time code that touches `VoxGMDB` would fail.

**[LOW]** **Section 5 says `ModelPreview.lua` is "conditional; depends on UI.lua"** but Section 6 says `Tab_Appearance.lua` adds a "Preview" button that calls `VoxGM.ModelPreview:Show(id)` with a nil-guard. If `ModelPreview.lua` is not included (Phase 0 says API unavailable), `Tab_Appearance.lua` still has the nil-guarded call. But `Tab_Appearance.lua` is an EXISTING file being modified — the spec says it's added to Section 6 modifications. The nil-guard is correct, but the spec should confirm that `Tab_Appearance.lua`'s modification is unconditional (always add the guarded button) vs. conditional (only add if ModelPreview.lua is included). Currently ambiguous.

**[LOW]** **The `v1` format marker in import/export (Section 7.8) is described as "decorative" but then immediately given parsing semantics** ("importers can detect format version by checking if the first line starts with `# VoxGM Script v` and parsing the trailing number"). If it's decorative, it shouldn't be parsed. If it's parsed, it's not decorative. The spec then says "only `v1` is recognized; unrecognized versions are rejected." This is a contradiction — "decorative" and "version-gated rejection" are mutually exclusive behaviors.

---

### Edge Cases

**[HIGH]** **`Scripts:DispatchNext()` reads `VoxGMDB.scripts.throttleDelay` at dispatch time (implied by `math.max(VoxGMDB.scripts.throttleDelay, C.SCRIPT_THROTTLE_MIN)`), but if the user changes `throttleDelay` via Settings mid-run, the delay changes immediately for the next timer.** This is probably fine, but the spec doesn't acknowledge this behavior. More critically: if `VoxGMDB.scripts.throttleDelay` is somehow nil mid-run (e.g., due to a migration bug), `math.max(nil, 0.1)` throws a Lua error, crashing the script runner silently. The spec should mandate a local copy of throttleDelay at `Run()` time, or add a nil-guard in `DispatchNext`.

**[HIGH]** **`Console:Init()` calls `smf:SetMaxLines(VoxGMDB.console.maxLines)` once. But `ScrollingMessageFrame:SetMaxLines()` in WoW does not retroactively trim existing messages — it only affects future additions.** If `maxLines` is reduced mid-session via Settings and `smf:SetMaxLines(newCap)` is called, the SMF may still display old messages beyond the new cap until they scroll off. The spec's bulk-trim logic correctly trims `lineBuffer`, but the SMF's internal message store may be out of sync with `lineBuffer` after a cap reduction. The spec doesn't address this SMF-vs-lineBuffer divergence after `SetMaxLines` is called mid-session.

**[MEDIUM]** **`Scripts:Run()` step 2 finds the script by case-insensitive name match, but the spec doesn't specify what happens if two scripts have names that are case-insensitively identical (which the uniqueness check should prevent, but migration from v1 or manual DB editing could create).** If `VoxGMDB.scripts.items` somehow contains `{name="foo"}` and `{name="FOO"}`, `Scripts:Run("foo")` would run the first match. The spec should specify "first match wins" or "error on ambiguity."

**[MEDIUM]** **`Console:OnLogout()` saves the last `C.CONSOLE_HISTORY_CAP` (50) entries from `lineBuffer`. But `lineBuffer` stores raw messages (per Section 7.3), while the SMF displays formatted messages (with timestamps). On next login, `Console:Init()` loads `persistedLines` into SMF via `smf:AddMessage()`.** If `AddMessage` is called with raw (no-timestamp) strings, the restored messages won't have timestamps, creating visual inconsistency with live messages. The spec doesn't specify whether persisted lines should be re-timestamped, stored with timestamps, or displayed differently.

**[MEDIUM]** **The `PLAYER_LOGOUT` event handler in Core.lua calls `Console:OnLogout()` but is nil-guarded only for `Console.OnLogout` existing.** If `Console:Init()` failed (e.g., `VoxGM.UI.consoleHost` was nil), `Console._initialized` would be false, but `Console.OnLogout` would still exist as a function (defined at file scope in Console.lua). The logout handler would call it, and `OnLogout` would attempt to write to `VoxGMDB.console.persistedLines` — which is valid — but might also reference `Console.lineBuffer` which could be nil or empty if init failed. The spec should add an `_initialized` guard to `OnLogout` as well.

**[MEDIUM]** **`Settings` panel "Back" button restores `Settings.previousTabId` via `UI:SelectTab(Settings.previousTabId)`.** But if the user opens Settings from the minimap button (not from a tab), there may be no active tab — `UI.activeTabId` could be nil or the last-selected tab from a previous session. The spec doesn't handle the case where `previousTabId` is nil (e.g., first open of the addon, Settings opened before any tab is selected).

**[LOW]** **`Scripts:Cancel()` step 5 prints `"Script cancelled (" .. idx .. " of " .. total .. " sent)."** But `idx` is captured as `runState.index` BEFORE `runState.active = false` and BEFORE the reset. If `index = 0` (cancelled before first command dispatched), the message reads "0 of N sent" which is accurate but potentially confusing. More importantly, `total` is `#runState.commands` — if commands is `{}` (shouldn't happen since `Run()` guards against empty scripts, but defensive coding), this is 0. Not a crash, just a cosmetic edge case.

**[LOW]** **`Console:Init()` trims `persistedLines` to `min(#persistedLines, maxLines)` before loading.** But `maxLines` here is `VoxGMDB.console.maxLines` (100-2000), while the persistence cap is `C.CONSOLE_HISTORY_CAP` (50). Since 50 < 100 (minimum maxLines), the trim condition `#persistedLines > maxLines` can never be true for valid data — `persistedLines` is always ≤ 50, and `maxLines` is always ≥ 100. The trim is a no-op. The spec should clarify whether this trim is future-proofing or whether the intent was to trim to `CONSOLE_HISTORY_CAP` instead.

**[LOW]** **`Scripts:Run()` rejects if `runState.active` is true: "A script is already running. Stop it first."** But the spec also says the Run button shows "Stop" during active runs. If the user somehow calls `Scripts:Run()` programmatically (not via UI) while a script is running, the rejection message is shown. This is correct. However, the spec doesn't address whether `Scripts:Run()` can be called from a keybinding (Phase 5 Bindings.xml). If a keybinding triggers Run while a script is running, the rejection message fires — this is fine, but the keybinding target (which script to run?) is unspecified.

---

### Clarity

**[MEDIUM]** **Section 3 "Key existing patterns" says `Events:RegisterParser(pattern, callback)` stores `{pattern, callback}` only.** But Section 6 Events.lua says parsers "must read `VoxGMDB` lazily." The "only" in the storage description implies no additional data is stored per parser. If lazy reading is implemented via closures (the callback closes over `VoxGMDB`), this is fine. But if someone reads "stores `{pattern, callback}` only" and implements a non-closure approach (e.g., storing `VoxGMDB` reference at registration time), they'd violate the lazy-read requirement. The spec should explicitly say "lazy reading is achieved via closure — the callback function closes over `VoxGMDB` by reference, not by value."

**[MEDIUM]** **The spec uses "stretch goal" for CNPC model preview but Section 7.5 says "CNPC tab (stretch goal, v2.1 candidate)" while Section 10 AC #7 says "CNPC = stretch goal."** This is consistent, but Section 13 (Future Expansion) lists "CNPC model preview" as a future item. If it's a stretch goal for v2.0, it shouldn't also be in the v2.1+ future list — or the distinction between "stretch goal (v2.0 if time)" and "v2.1 candidate" should be clarified. Currently both labels are applied to the same feature.

**[MEDIUM]** **Section 6 UI.lua specifies `UI:SetConsoleVisible(bool)` but the console layout description (steps 1-5) describes what `UI:Init()` does, not what `SetConsoleVisible` does.** The reader must infer that `SetConsoleVisible` re-executes the anchor logic from steps 3 and 4 (with `ClearAllPoints` first). The spec should have a separate, explicit description of `SetConsoleVisible`'s body — what it does to the divider, console host, and contentHost anchors — rather than embedding it in the init description.

**[LOW]** **Section 4.5 says "DisplayID 0: `tonumber("0")` returns `0`, which is falsy in Lua."** This is factually incorrect — `0` is truthy in Lua (unlike C or Python). Only `nil` and `false` are falsy in Lua. The spec then correctly says to use `id ~= nil` instead of `if id then`, which IS the right fix, but for the wrong stated reason. The actual reason is that `tonumber` returns `nil` on failure (not `0`), so `id ~= nil` distinguishes "parsed successfully (including 0)" from "parse failed." The incorrect falsy claim could confuse an implementer who knows Lua and questions the reasoning.

**[LOW]** **Section 7.3 "Copy Line" says the overlay is rebuilt "when console becomes visible."** But the mechanism for triggering this rebuild when visibility changes is not specified. `Console:Toggle()` calls `UI:SetConsoleVisible()` — does `SetConsoleVisible` call `Console:RebuildOverlay()`? Or does `Console:Toggle()` call it directly? The spec specifies two rebuild triggers (OnMouseWheel hook and Init) but the visibility-change trigger is mentioned without a call site.

**[LOW]** **Section 6 Constants.lua adds `C.CONSOLE_HISTORY_CAP = 50` but this constant is never referenced in the spec's code snippets** — Section 7.3 says "save last `C.CONSOLE_HISTORY_CAP` (50) entries" in prose but no code snippet shows it. Minor, but inconsistent with how other constants are shown in use.

**[INFO]** **Section 3 says "22 files loaded by TOC (verified: Core.lua through Modules\Tab_DevTools.lua = 22 entries in VoxGM.toc lines 12-36)."** Lines 12-36 is 25 lines, not 22. Either the line numbers are wrong, or there are blank lines/comments interspersed. This is a minor documentation accuracy issue but could cause confusion if someone counts lines to verify.

**[INFO]** **The spec's competitive table (Section 12) lists "Client: 11.1.x" for TrinityAdmin Reforged.** VoxCore targets 12.x Midnight. This is presumably accurate competitive intelligence, but it's unverified in the spec and could become stale. Not a spec defect, just an unverifiable claim.

---

## VERDICT: FAIL

**Critical/High issues present:**

1. `StaticPopup` double-show race is unsafe for the overwrite case (mutable table `self.data`)
2. `Scripts:Run()` `onComplete` call site is never specified — implementer must guess the closure
3. `DispatchNext` `onComplete` can fire on cancellation if runState reset races with timer callback
4. `DispatchNext` `throttleDelay` nil-guard missing; mid-run Settings change is unacknowledged
5. `smf:SetMaxLines()` mid-session does not retroactively trim SMF internal store — lineBuffer and SMF diverge after cap reduction

The spec is in excellent shape overall — Revision 6 has closed the vast majority of prior findings. The remaining high-severity issues are concentrated in the script runner's cancellation/completion boundary and the StaticPopup overwrite race. These are implementable-but-wrong scenarios that would produce subtle bugs rather than crashes, making them harder to catch in testing.
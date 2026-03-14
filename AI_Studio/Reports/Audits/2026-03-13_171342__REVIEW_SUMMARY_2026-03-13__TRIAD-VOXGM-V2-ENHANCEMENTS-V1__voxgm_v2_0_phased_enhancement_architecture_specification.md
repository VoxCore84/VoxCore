# Review Cycle Summary: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md

**Date**: 2026-03-13T17:13:42.895096

**Rounds completed**: 5

**Final verdict**: FAIL

**Wall time**: 357.4s | **CPU time**: 555.2s (saved 198s via parallelism)


## Round Results

| Round | Reviewer | Model | Time | Verdict | Phase |
|-------|----------|-------|------|---------|-------|
| R1 | Codex | gpt-5.4 | 181.4s | FAIL | Phase 1 |
| R2 | Gemini | gemini-2.5-pro | 59.8s | FAIL | Phase 1 |
| R3 | Claude | claude-sonnet-4-6 | 138.1s | FAIL | Phase 1 |
| R4 | Codex | gpt-5.4 | 112.3s | FAIL | Phase 2 |
| R5 | Gemini | gemini-2.5-pro | 63.7s | FAIL | Phase 3 |

## Per-Round Reviews

### Round 1: Codex (Phase 1)

**Architecture**
- **[HIGH]** The spec never defines a guaranteed lifecycle hook for `Settings.lua`. The current startup chain only initializes `UI`, `Minimap`, `Favorites`, `History`, and `PhaseTracker` on `PLAYER_LOGIN` in [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L39), [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L43). Revision 6 adds a `VoxGM.Settings` namespace and `/vgm settings`, but it does not specify `Settings:Init()` or any equivalent registration point. That leaves native settings registration, fallback panel creation, and any gear-button hookup without a guaranteed execution path.

**Integration**
- **[HIGH]** The Path B settings-panel flow is wired against the wrong runtime structure. The spec says to “iterate `VoxGM.Tabs`, hide each content frame,” but in this repo `VoxGM.Tabs` holds module tables, not frames, as shown by [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L13) and [Tab_Appearance.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L4). The actual UI containers live in `UI.tabScrollFrames` and are created in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L473), [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L476). As written, the fallback settings panel would not actually hide the tab content.
- **[MEDIUM]** The spec’s `DisplayID 0` support does not integrate with the existing appearance inputs it tells the implementer to extend. All current display-ID fields in [Tab_Appearance.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L41), [Tab_Appearance.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L104), [Tab_Appearance.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L195) use `Util:ParseID()`, and [Util.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Util.lua#L18) rejects values `< 1`. A Preview button that reads those boxes will never pass `0` unless the spec also changes that contract.
- **[MEDIUM]** The proposed `UI:CreateSlider` extension is not backward-compatible as specified. Today the signature is `CreateSlider(parent, label, min, max, step, default, width)` in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68), and existing code already passes width as arg 7 in [Tab_GM.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_GM.lua#L103). Revision 6 repurposes that position for `decimals`, which would silently break current slider callers unless the signature becomes arg 8 or every callsite is updated.
- **[MEDIUM]** The spec repeatedly says settings are opened by `/vgm settings` “or gear button,” but no modification section adds a gear button to the existing frame in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332). That leaves one advertised access path undefined.

**Verification**
- **[MEDIUM]** The spec’s rationale for `id ~= nil` is factually wrong: it says `0` is falsy in Lua. Lua treats only `false` and `nil` as falsey. The recommendation may still work, but the stated language behavior is incorrect and conflicts with the repo’s current numeric helper semantics in [Util.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Util.lua#L18).
- **[INFO]** Several verification claims do check out against the repo: the TOC currently loads 22 files in [VoxGM.toc](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc), `RegisterDefaultParsers()` is currently invoked from `UI:Init()` in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332), `VoxGMFrame` is already added to `UISpecialFrames` in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L428), and the companion slash keys for CreatureCodex and VoxSniffer are present in [CreatureCodex.lua](C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1032), [CreatureCodex.lua](C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1034), [VoxSniffer.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.lua#L217), [VoxSniffer.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.lua#L219). `VoxTip` and `VoxPlacer` are not present in this repo, so keeping them marked “assumed” is correct.

Since the prior rounds, Revision 6 clearly tightened several weak areas: it fixes the O(n^2) bulk trim issue, moves script deletion/overwrite to name-based lookup, adds the missing `VoxGM.Settings` namespace, clarifies console visibility as `UI`-owned state, and patches multiple stale-index and persistence edge cases. Those revisions improve internal consistency, but the spec still has two unresolved repo-integration gaps around `Settings.lua`: it does not define when the module is initialized, and its fallback panel flow targets the wrong UI container structure.

**VERDICT: FAIL**

---

### Round 2: Gemini (Phase 1)

This review covers Revision 6 of the VoxGM v2.0 Phased Enhancement Architecture Specification. The document is exceptionally detailed and demonstrates significant maturation over its revision history. Changes since the prior round correctly address major performance (O(n^2) trim) and correctness (stale-index deletion) issues, and add important clarifications around UI state management, namespacing, and component interaction. The architecture is robust, with a clear plan for handling API uncertainties via the Phase 0 spike.

Despite its high quality, this review identifies one critical factual error in the specification's text and one high-severity inconsistency that could lead to implementation bugs. Several minor points of clarification are also noted.

---

### Correctness

*   **[CRITICAL]** Section 4.5 contains a factually incorrect statement about Lua's type coercion rules. The spec states: "`tonumber("0")` returns `0`, which is falsy in Lua." This is false; in Lua, only `nil` and `false` are falsy, while the number `0` is truthy. Although the document correctly concludes that the implementation must use `id ~= nil` to handle DisplayID 0, the justification is dangerously wrong. An implementer relying on this faulty rationale could introduce subtle bugs elsewhere or "correct" the valid code to match the invalid reasoning. The justification must be corrected to state that `id ~= nil` is necessary to distinguish a valid numeric input (including 0) from a non-numeric input that causes `tonumber` to return `nil`.

*   **[HIGH]** The specification is inconsistent regarding the validation of `scripts.throttleDelay`.
    *   Section 6 (State.lua) states: "Validation: ... floor `scripts.throttleDelay` to `C.SCRIPT_THROTTLE_MIN`". The word "floor" is mathematically incorrect for establishing a minimum value and is ambiguous.
    *   Section 7.7 (Script execution) states: "Throttle: `math.max(VoxGMDB.scripts.throttleDelay, C.SCRIPT_THROTTLE_MIN)`". This is the correct, unambiguous logic.
    *   The confusing language in Section 6 must be replaced with the clear logic from Section 7.7 (e.g., "clamp `scripts.throttleDelay` to a minimum of `C.SCRIPT_THROTTLE_MIN`") to prevent implementation errors arising from conflicting requirements.

*   **[MEDIUM]** The specification for the "Copy Line" overlay feature (Sections 4.4 and 7.3) is incomplete. It describes a core mechanic that relies on calculating a `lineBuffer` index using the `ScrollingMessageFrame`'s scroll offset ("`smf:GetNumMessages()` minus scroll offset"). However, it fails to specify the method for retrieving this scroll offset. This leaves a key implementation detail to guesswork, potentially leading to incorrect behavior. The spec should be updated to mention the expected API (e.g., `scrollFrame:GetVerticalScroll()`) for obtaining this value.

*   **[LOW]** The console buffer management logic in Section 7.3 (`OnMessage`) specifies adding a new message *before* checking the buffer limit and removing the oldest entry. This allows the buffer to temporarily contain `maxLines + 1` elements. While not a functional bug, a more conventional and precise implementation would be to remove an element if `#lineBuffer >= maxLines` *before* adding the new one, strictly maintaining the `maxLines` cap at all times.

### Style

*   **[INFO]** The `_initialized` guard in `Events.lua` is specified only for `VoxGM.Console`. The rationale given is that other modules are not called from event handlers that can fire before `PLAYER_LOGIN`. While this is likely true for the current scope, this assumption should be explicitly called out as a point of verification for the implementer, and a reminder that any future module hooking early events would require a similar guard.

---

## VERDICT: FAIL

The specification is of very high quality but contains a critical factual error in its justification of a key logic point (Lua truthiness) and a high-severity inconsistency in its validation requirements. These issues must be resolved to ensure the implementer works from a completely accurate and unambiguous document. Once these are addressed, the specification will be in an excellent state for implementation.

---

### Round 3: Claude (Phase 1)

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

---

### Round 4: Codex (Phase 2)

**Architecture**
- **[HIGH]** The settings module still has no guaranteed lifecycle hook or concrete init contract. The current startup chain only initializes `UI`, `Minimap`, `Favorites`, `History`, and `PhaseTracker` on login in [Core.lua#L27](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L27) and [Core.lua#L38](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L38). Revision 6 adds `VoxGM.Settings = {}` and a `/vgm settings` branch, but it still does not specify a `Settings:Init()` call or equivalent bootstrap step for native settings registration, fallback panel construction, or any frame/button wiring. `Settings:Open()` is invoked by contract, but its creation lifecycle remains implicit rather than defined.
- **[HIGH]** Path B still targets the wrong runtime structure for hiding tab content. The spec says to iterate `VoxGM.Tabs` and hide each content frame, but in this repo `VoxGM.Tabs` is a registry of tab modules, not frame instances, as shown by [Core.lua#L13](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L13) and [Tab_Appearance.lua#L4](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L4). The actual UI containers are `UI.tabScrollFrames`, created in [UI.lua#L473](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L473) and populated in [UI.lua#L515](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L515). As written, the fallback settings flow would not actually hide the live tab frames.

**Integration**
- **[HIGH]** The `UI:CreateSlider` change is still not backward-compatible with the existing addon. The current signature is `CreateSlider(parent, label, min, max, step, default, width)` in [UI.lua#L68](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68), and existing code already uses arg 7 as width in [Tab_GM.lua#L103](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_GM.lua#L103). Revision 6 still describes `decimals` in that slot instead of adding an eighth argument or explicitly updating all call sites, so a literal implementation would silently corrupt current slider layouts/behavior.
- **[MEDIUM]** The spec still advertises opening settings via `/vgm settings` “or gear button,” but no modification section adds a gear button to the existing frame. The current `UI:Init()` builds a title and close button only in [UI.lua#L359](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L359) and [UI.lua#L367](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L367). That leaves one user-facing access path undefined.

**Design**
- **[MEDIUM]** DisplayID `0` support is still not fully integrated with the existing appearance-tab input contract. The spec now fixes the slash-handler rationale, but the current appearance inputs all use `Util:ParseID()` in [Tab_Appearance.lua#L41](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L41), [Tab_Appearance.lua#L104](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L104), and [Tab_Appearance.lua#L195](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L195), while [Util.lua#L18](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Util.lua#L18) rejects values `< 1`. If the new Preview button is meant to allow `0` from those same boxes, the spec needs to say that it bypasses `ParseID()` and uses a different parser for preview-only input.
- **[MEDIUM]** `scripts.throttleDelay` validation is still internally inconsistent. Section 6 says to “floor `scripts.throttleDelay` to `C.SCRIPT_THROTTLE_MIN`,” while Section 7.7 defines runtime behavior as `math.max(VoxGMDB.scripts.throttleDelay, C.SCRIPT_THROTTLE_MIN)`. Those are different operations: flooring implies integer-style rounding semantics, while `math.max` is a lower-bound clamp. The implementer still has to guess which contract is intended.

**Verification**
- **[INFO]** Several repository-backed claims in the spec do check out: the TOC currently loads 22 addon files in [VoxGM.toc](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc), `RegisterDefaultParsers()` is currently called from `UI:Init()` at [UI.lua#L332](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332), the real tab frame storage is `UI.tabScrollFrames` at [UI.lua#L473](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L473), and the companion slash keys for CreatureCodex and VoxSniffer are present in [CreatureCodex.lua#L1032](C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1032) and [VoxSniffer.lua#L181](C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.lua#L181). `VoxTip` and `VoxPlacer` are not present in this repo, so keeping them marked assumed is appropriate.

Revision 6 does close a number of earlier gaps: the Lua truthiness mistake is gone, the script deletion/overwrite flow is now name-based, the console bulk trim is now linear-time, `VoxGM.Settings` is at least namespaced in the proposed Core changes, and several persistence/details issues were tightened. The remaining defects are narrower but still material: settings is still not wired into the real runtime lifecycle, the fallback panel still targets the wrong frame structure, and the slider API change still conflicts with the existing codebase.

**VERDICT: FAIL**

---

### Round 5: Gemini (Phase 3)

This review assesses Revision 6 of the VoxGM v2.0 specification. While the revision notes indicate numerous fixes from prior cycles, this audit finds that several critical and high-severity issues identified in the most recent feedback round persist in the current document. Key changes that *were* successfully integrated include an efficient O(n) slice for console buffer trimming, a name-based lookup for script deletion to prevent stale-index bugs, disabling UI controls during script execution, and adding a case-insensitive policy for script names. However, fundamental architectural gaps, factual inaccuracies about the Lua language, and unaddressed race conditions remain.

### Correctness

*   **[CRITICAL]** **Incorrect Language Rationale:** Section 4.5 and the prior feedback from multiple reviewers highlight a factually incorrect statement: "`tonumber("0")` returns `0`, which is falsy in Lua." This is false. In Lua, only `nil` and `false` are falsy; the number `0` is truthy. While the recommended code (`id ~= nil`) is correct, the justification is dangerously wrong. Retaining this error across six revisions indicates a critical gap in understanding the core language, which undermines the reliability of the entire specification.
*   **[HIGH]** **Missing Module Initialization:** The specification adds a `VoxGM.Settings` namespace and a slash command to open the settings panel, but it fails to add `VoxGM.Settings:Init()` to the addon's `PLAYER_LOGIN` lifecycle sequence in Section 6 (Core.lua) or Section 7.1. This leaves no guaranteed execution path for creating the settings panel frame or registering with the native WoW settings system, meaning the feature cannot be implemented as specified.
*   **[HIGH]** **Settings Panel Targets Incorrect UI Structure:** Section 4.8 specifies that the Path B settings panel should "Hide all tab content scrollframes (iterate `VoxGM.Tabs`, hide each content frame)." As noted in prior feedback, this is incorrect. `VoxGM.Tabs` is a table of module registrations, not UI frame objects. The actual frames are stored in a structure like `UI.tabScrollFrames`. As written, the implementation would fail to hide the active tab content.
*   **[HIGH]** **Script Runner Crash Vulnerability:** Section 7.7 specifies that the script runner's throttle delay is calculated at each step via `math.max(VoxGMDB.scripts.throttleDelay, C.SCRIPT_THROTTLE_MIN)`. If `VoxGMDB.scripts.throttleDelay` becomes `nil` for any reason (e.g., a data migration error), this call will raise a Lua error (`attempt to compare number with nil`), crashing the script runner silently. The spec must mandate either caching the throttle value at the start of `Run()` or adding a nil-coalescing guard (e.g., `(VoxGMDB.scripts.throttleDelay or C.SCRIPT_THROTTLE_DEFAULT)`).
*   **[HIGH]** **Console Buffer Desynchronization on `maxLines` Change:** Section 7.3 correctly specifies an efficient bulk trim for the Lua `lineBuffer` when `console.maxLines` is changed. However, it fails to account for the fact that `ScrollingMessageFrame:SetMaxLines()` does not retroactively trim the messages already displayed in the frame. This will cause `lineBuffer` and the SMF's internal buffer to desynchronize, breaking the "Copy Line" feature, which depends on a 1:1 mapping between them. The fix requires clearing the SMF (`smf:Clear()`) and re-populating it from the newly trimmed `lineBuffer`.
*   **[HIGH]** **Incomplete UI Contract for Script Execution:** Section 7.7 defines the script runner's `onComplete` callback, which is consumed by the UI to re-enable the "Run" button. However, the specification never shows the UI code that calls `Scripts:Run()`. It is missing the critical link that shows a closure being passed as the `onComplete` argument. This leaves a crucial piece of UI-to-logic wiring entirely up to the implementer's inference, likely leading to a behavioral bug where the UI remains locked after a script finishes.
*   **[MEDIUM]** **Inconsistent Validation Logic:** The specification remains inconsistent on how to validate `scripts.throttleDelay`. Section 6 (State.lua) says to "floor `scripts.throttleDelay` to `C.SCRIPT_THROTTLE_MIN`," which is a nonsensical rounding operation in this context. Section 7.7 uses `math.max`, which correctly implements a minimum clamp. The "floor" instruction should be removed and replaced with a clear clamping requirement.
*   [MEDIUM] **Unresolved Race Condition in `Scripts:Cancel()`:** As noted in prior feedback, the logic in `Scripts:DispatchNext()` and `Scripts:Cancel()` creates a race condition where the `onComplete` callback can fire during cancellation, violating the spec's requirement that it only fires on natural completion. The fix is to set `runState.onComplete = nil` within `Scripts:Cancel()` before the `runState` is fully reset, but this change has not been made.
*   [MEDIUM] **Undefined Behavior for Settings "Back" Button:** Section 4.8 specifies that the settings panel's "Back" button should restore the tab stored in `Settings.previousTabId`. It does not define what should happen if `previousTabId` is `nil` (e.g., if the user opens the settings panel before ever selecting a tab).
*   [MEDIUM] **Underspecified "Copy Line" Implementation:** The logic for the "Copy Line" overlay (Section 7.3) relies on calculating an index from the "scroll offset" of the `ScrollingMessageFrame`. The spec still fails to define which API provides this offset (e.g., `scrollFrame:GetVerticalScroll()`), leaving a key part of the implementation ambiguous.
*   [MEDIUM] **UX Inconsistency in "Copy Line" Content:** Section 7.3 states that `Console.lineBuffer` stores the raw message text, while the `ScrollingMessageFrame` displays a formatted version with a timestamp. The "Copy Line" feature reads from `lineBuffer`. This means the user will copy text that does not match what they see on screen (it will be missing the timestamp). The spec should require `lineBuffer` to store the same formatted string that is displayed.
*   **[LOW]** **Contradictory Description of Import Format:** Section 7.8 describes the `# VoxGM Script v1` header line as both "decorative" and as a parsed version marker used to reject unrecognized formats. These descriptions are mutually exclusive.
*   **[LOW]** **Ineffectual Console History Trim:** The logic in `Console:Init()` to trim `persistedLines` to `maxLines` on load (Section 7.3) is a no-op. `persistedLines` is capped at `C.CONSOLE_HISTORY_CAP` (50) on logout, while `maxLines` has a minimum of `C.CONSOLE_MAX_LINES_MIN` (100). Since 50 is always less than 100, this trim condition can never be met.

### Security

*   **[HIGH]** **Unresolved Race Condition in Script Overwrite:** Section 7.6 acknowledges that WoW's `StaticPopup` API does not update `self.data` if a second popup is shown while one is already visible. While the spec correctly identifies this is safe for deletion (where `self.data` is a string), it fails to address the vulnerability for overwriting an imported script, where `self.data` is the imported script table. A user double-clicking an import button could cause the first script's data to be used for the second script's overwrite confirmation. The spec must mandate that the import UI is disabled while the confirmation popup is visible.

### Style

*   **[HIGH]** **Non-Backward-Compatible API Change:** The proposed extension to `UI:CreateSlider` (Section 6) to add a `decimals` parameter is not backward-compatible. Prior feedback correctly identified that existing code calls this function with 7 arguments, where the 7th is `width`. The spec still implies `decimals` will take this position, which would break existing UI elements. The new parameter must be added as the 8th argument, or the spec must explicitly require all existing call sites to be updated.
*   **[MEDIUM]** **Undefined UI Elements:** The spec repeatedly refers to a "gear button" as a method for opening the settings panel (e.g., Section 4.8) but never includes the creation of this button in any of the modifications to `UI.lua`. This leaves an advertised access path completely undefined.

### VERDICT: FAIL

This specification is rejected. Despite a long history of revisions, it retains a critical factual error about the core programming language and fails to address multiple high-severity bugs and architectural gaps identified in the previous review round. The persistence of these issues demonstrates a significant failure in the revision process. The document cannot be approved for implementation until all CRITICAL and HIGH severity findings are resolved.

---

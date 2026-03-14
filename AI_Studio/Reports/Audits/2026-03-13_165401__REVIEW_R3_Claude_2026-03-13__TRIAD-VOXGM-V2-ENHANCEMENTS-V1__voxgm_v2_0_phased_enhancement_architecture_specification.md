---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 3
reviewer: Claude
model: claude-sonnet-4-6
date: 2026-03-13T16:54:01.413778
elapsed_seconds: 143.6
---

# Cold-Read Review: TRIAD-VOXGM-V2-ENHANCEMENTS-V5

**Reviewer:** Cold-Read (Round 3 of current cycle)
**Artifact:** VoxGM v2.0 Phased Enhancement Architecture Specification, Revision 5
**Prior context consumed:** Zero — reviewing blind per role definition.

---

## Round-over-Round Summary

Revision 5 addresses a substantial backlog: console/UI init race, settings fallback UI, runState shallow copy, lineBuffer trim on maxLines change, onComplete-on-cancel behavior, StaticPopup data arg, script enabled defaults, Console:Toggle delegation, script pruning direction, Copy Line scroll hook, semicolon secondary validation, SetMaxLines call frequency, TOC count, VoxGM.Data existence, slider pseudocode, DispatchNext nil-clear, Phase 0 rationale, and content host naming. The spec is materially more complete and internally consistent than prior rounds. Remaining findings are narrower and more implementation-specific.

---

## Category 1: Implementation Bias / Assumed Knowledge

**[HIGH]** **`unpack` vs `table.unpack` in Lua 5.1/5.2+ context**
Section 7.7 specifies `local cmds = {unpack(script.lines)}` for the shallow copy. WoW's Lua environment (based on Lua 5.1) does expose `unpack` as a global, but this is a known portability trap and the spec gives no note. More critically, `{unpack(t)}` only copies the array portion up to `t[#t]` — if any `lines` entry is `nil` (e.g., a sparse table from a corrupt import), the copy silently truncates. The spec should either mandate `table.move` / explicit loop, or add a note that lines must be validated as non-sparse before this call. Given that import validation already runs, this may be safe in practice, but the assumption is invisible.

**[HIGH]** **`StaticPopup_Show` 4th argument sets `self.data` — not universally true**
Section 7.6 states: `StaticPopup_Show("VOXGM_SCRIPT_DELETE", script.name, nil, scriptIndex)` — "4th arg sets `self.data` to the script's array index." This is correct for the standard Blizzard implementation, but `self.data` is set to the 4th argument only when the popup's `OnAccept` receives `self` as the popup frame. The spec's `OnAccept = function(self) VoxGM.Scripts:ConfirmDelete(self.data) end` is correct. However, the spec does not note that if the popup is already showing (e.g., user double-clicks delete), `StaticPopup_Show` returns the existing frame without updating `self.data` — the stale index from the first call will be used. This is a real bug vector in list UIs where rapid deletion is possible.

**[MEDIUM]** **`ConfirmDelete(index)` uses array index — fragile after list mutation**
Section 7.6: `ConfirmDelete(index)` calls `table.remove(db.scripts.items, index)`. The index is captured at `StaticPopup_Show` time. If the user opens a second delete dialog before confirming the first (or if any other list mutation occurs between show and confirm), the index is stale. The spec does not address this. A name-based lookup or a direct table reference would be safer. The overwrite popup correctly passes the imported script table (a reference), but the delete popup passes a numeric index.

**[MEDIUM]** **`Console.lineBuffer` cap uses `table.remove(lineBuffer, 1)` — O(n) per message**
Section 7.3: "If `#lineBuffer > cap`, call `table.remove(lineBuffer, 1)`." Removing from index 1 of a Lua table shifts all elements — O(n) per message. At 2000 lines this is non-trivial per-message overhead. The spec recommends this pattern without noting the performance characteristic. A ring-buffer or head-pointer approach would be O(1). This is an implementation guidance gap that will produce a spec-compliant but potentially janky console at high message rates (e.g., bulk `.npc` operations).

**[MEDIUM]** **`Events:Init()` called at ADDON_LOADED but `VoxGMDB` may not be initialized yet**
Section 7.1: `ADDON_LOADED` fires `State:Init()` then `Events:Init()`. `RegisterDefaultParsers()` is now called inside `Events:Init()`. If any default parser closure captures `VoxGMDB` at registration time (rather than at call time), it would see nil. The spec does not clarify whether parsers are closures that read `VoxGMDB` lazily. This is a latent bug if any parser references saved state. The spec should explicitly state parsers must not capture `VoxGMDB` at registration time, or confirm `State:Init()` is guaranteed to run first (it is, per the listed order, but the guarantee should be explicit).

**[MEDIUM]** **`UI:SetConsoleVisible` anchor chain manipulation — no teardown specified**
Section 6 (UI.lua): `UI:SetConsoleVisible(bool)` "toggles between states 3 and 4." State 3 changes `contentHost`'s BOTTOMRIGHT anchor; state 4 reverts it. WoW frame anchors accumulate — calling `SetPoint` without first calling `ClearAllPoints` on the relevant anchor point will stack anchors, causing layout corruption. The spec does not specify that `ClearAllPoints()` (or `ClearPoint("BOTTOMRIGHT")`) must be called before re-anchoring. An implementer reading cold will likely miss this.

**[LOW]** **`smf:HookScript("OnMouseWheel", ...)` — SMF may not expose OnMouseWheel directly**
Section 4.4 and 7.3: "Hook the SMF's `OnMouseWheel` script." `ScrollingMessageFrame` inherits from `Frame` and does support `OnMouseWheel`, but only if `EnableMouseWheel(true)` has been called on it. The spec does not mention this prerequisite. Without it, the hook fires but the event never triggers, and the overlay never repositions on scroll.

**[LOW]** **`ModelPreview:Show(nil)` — spec says "nil id opens panel with empty input" but slash handler checks `rest ~= ""`**
Section 7.5 vs Core.lua slash handler: The slash handler passes `id` (which is `nil` if `rest == ""`) to `ModelPreview:Show(id)`. But it only calls `Show` if `rest == ""` (empty, so `id = nil`) OR if `rest` is a valid number. The condition `if rest ~= "" and not id then` catches invalid non-numeric input. So `Show(nil)` is called when no argument is given. Section 7.5 says "nil id opens panel with empty input" — consistent. But `Show(0)` is also valid (tonumber("0") = 0, which is falsy in the `if id then` check inside Show). The spec should clarify that `Show(0)` is a valid display ID call, not equivalent to `Show(nil)`. DisplayID 0 may be a valid model.

---

## Category 2: Consistency Issues

**[HIGH]** **`VoxGM.Settings` namespace never declared in Core.lua**
Section 6 (Core.lua): Sub-namespaces added are `VoxGM.Console = {}`, `VoxGM.Scripts = {}`, `VoxGM.Companions = {}`, `VoxGM.ModelPreview = {}`. `VoxGM.Settings` is NOT listed. Yet the slash handler in the same section calls `VoxGM.Settings:Open()`. If `Settings.lua` declares its own namespace (e.g., `VoxGM.Settings = VoxGM.Settings or {}`), this works — but the spec is inconsistent: all other sub-namespaces are declared in Core.lua, Settings is not. Either Core.lua should declare it, or the spec should explicitly note that Settings.lua self-declares its namespace (and why it's different).

**[MEDIUM]** **`C.CONSOLE_HISTORY_CAP = 50` used in persistence but not listed in Constants.lua additions**
Section 6 (Constants.lua) lists: `C.CONSOLE_MAX_LINES_MIN`, `C.CONSOLE_MAX_LINES_MAX`, `C.CONSOLE_HISTORY_CAP = 50`. Wait — re-reading: `C.CONSOLE_HISTORY_CAP = 50` IS listed. ✓ However, `C.SCRIPT_THROTTLE_DEFAULT = 0.3` is listed in Constants.lua but `DEFAULTS.scripts.throttleDelay = 0.3` in State.lua hardcodes the value rather than referencing `C.SCRIPT_THROTTLE_DEFAULT`. This is a consistency gap — if the constant changes, State.lua won't reflect it. The spec should mandate `throttleDelay = C.SCRIPT_THROTTLE_DEFAULT` in DEFAULTS.

**[MEDIUM]** **`decimals` parameter for `UI:CreateSlider` — Settings.lua usage not cross-referenced**
Section 6 (UI.lua) specifies extending `UI:CreateSlider` with a `decimals` param. Section 4.8 (Path B) lists sliders with specific decimal counts (scale: 1, opacity: 2, throttle: 1, maxLines: integer/0). But the spec never explicitly states that Settings.lua MUST use the extended `UI:CreateSlider` with these `decimals` values — it's implied. An implementer building Settings.lua in Phase 5 (after UI.lua in Phase 1) might not connect these. A cross-reference or explicit call signature example in Section 4.8 would close this gap.

**[MEDIUM]** **`Scripts:Run` sets `runState.onComplete = onComplete` but `onComplete` parameter has no documented callers**
Section 7.7 defines `onComplete` as a parameter to `Scripts:Run(scriptName, onComplete)`. No call site in the spec passes a non-nil `onComplete`. The acceptance criteria don't mention it. It appears to be an internal hook with no specified consumer. This is fine architecturally, but a cold implementer might wonder if this is dead code or if there's a missing integration (e.g., does the Scripts UI use it to re-enable the Run button?). The spec should note the intended consumer or explicitly mark it as "reserved for future use."

**[LOW]** **`Companions.status` is a module-level table on `Companions` (the namespace), not on `VoxGM.Companions`**
Section 7.9: `Companions.status = {}` — but within `Companions.lua`, the local pattern is `local _, VoxGM = ...` and the module is `VoxGM.Companions`. So this should be `VoxGM.Companions.status = {}`. The spec uses `Companions.status` as shorthand throughout Section 7.9, which is fine for readability, but the implementer must know this maps to `VoxGM.Companions.status`. No note is provided. Inconsistent with how other sections reference sub-namespaces (e.g., `Console.lineBuffer` — same issue, but Console is more clearly established).

**[LOW]** **Phase 3 adds Preview button to `Tab_Appearance.lua` but this file is not listed in Section 6 (Modifications to Existing Files)**
Section 11 (Phase 3): "Add Preview button to Tab_Appearance.lua." Section 6 lists modifications to: VoxGM.toc, Constants.lua, State.lua, Commands.lua, Events.lua, UI.lua, Core.lua. `Tab_Appearance.lua` is absent from Section 6. This is either an omission in Section 6 or the modification is considered too minor to specify. Either way, a cold implementer following Section 6 as the authoritative modification list will miss it.

**[LOW]** **`VoxGM.Data.CompanionAddons` declared in `Data\CompanionAddons.lua` but `VoxGM.Data = {}` is declared in Core.lua**
Section 3 confirms `VoxGM.Data = {}` exists (Core.lua line 14). `Data\CompanionAddons.lua` appends `VoxGM.Data.CompanionAddons = {...}`. This is consistent with the existing pattern (Data\Presets.lua, etc.). ✓ No issue — noting as confirmed consistent.

---

## Category 3: Edge Cases & Untested Paths

**[HIGH]** **Script deletion by index during active run — no guard specified**
If a script is running (`runState.active == true`) and the user opens the Scripts UI and deletes a script (including the currently running one), `ConfirmDelete(index)` calls `table.remove`. The running script's commands are already shallow-copied into `runState.commands`, so the execution itself is safe. However, the spec does not state whether the Delete button should be disabled during an active run, or whether deleting the running script's entry is permitted. The UI behavior is unspecified. A cold implementer will make an arbitrary choice.

**[MEDIUM]** **`persistHistory` toggle mid-session: `persistedLines` cleared immediately, but lineBuffer is not**
Section 7.3: "If user changes from true to false mid-session, immediately clear `VoxGMDB.console.persistedLines = {}`." This is correct. But `lineBuffer` continues to accumulate (by design — messages buffer regardless of visibility). On logout with `persistHistory == false`, `OnLogout` sets `persistedLines = {}`. This is consistent. However: if the user toggles `persistHistory` from false → true mid-session, the messages that accumulated in `lineBuffer` while persistence was off will now be saved on logout. This may be surprising (user disabled persistence, re-enabled it, and gets messages from the "off" period). The spec does not address this. It's probably acceptable behavior but should be documented.

**[MEDIUM]** **`Console:Init()` loads `persistedLines` into SMF — but SMF's `SetMaxLines` may truncate them**
Section 7.3: Init calls `smf:SetMaxLines(VoxGMDB.console.maxLines)` once, then loads persisted lines. If `persistedLines` has 50 entries and `maxLines` is 100, fine. But if `maxLines` was reduced between sessions (e.g., user set it to 30 via Settings), `SetMaxLines(30)` is called first, then 50 lines are added — SMF will drop the oldest 20 silently. `lineBuffer` will have 50 entries but SMF shows only 30. The spec does not address this desync. The fix would be to trim `persistedLines` to `min(#persistedLines, maxLines)` before loading, or accept the desync (SMF is display-only, lineBuffer is source of truth).

**[MEDIUM]** **`Scripts:Cancel()` step 4: `runState.timerHandle:Cancel()` called after `runState.active = false`**
Section 7.7: Cancel sets `runState.active = false` (step 3), then calls `runState.timerHandle:Cancel()` (step 4). The timer callback checks `if runState.active then` before calling `DispatchNext`. Since `active` is already false, even if `:Cancel()` fails (e.g., timer already fired between the active=false set and the Cancel call), the callback is a no-op. This is actually safe. ✓ However, the spec then resets `runState` in step 6 — but if the timer fires between steps 3 and 4 (before `:Cancel()` is called), the callback sees `active == false` and returns without resetting runState. Then step 6 resets it. This is fine. But the spec should note this race is handled by the `active` flag, not by `:Cancel()` alone — `:Cancel()` is best-effort.

**[LOW]** **`/vgm console` when Console module is not initialized (e.g., Phase 0 determines SMF unavailable)**
The slash handler calls `VoxGM.Console:Toggle()` unconditionally (no nil guard). All other conditional modules (`ModelPreview`) have nil guards. If `Console.lua` is always included (it's not listed as conditional), this is fine. But if a future decision makes Console conditional, this will error. Minor inconsistency in defensive coding style.

**[LOW]** **Export format: no version field for the script format itself**
Section 7.8: Export header is `# VoxGM Script v1`. Import parsing looks for `# Key: Value` metadata. The `v1` in the header line is not a parseable key-value pair — it's part of the literal string `# VoxGM Script v1`. If the format ever changes to `v2`, the importer has no way to reject or handle old-format files differently. The spec should clarify whether the version string is parsed or purely decorative, and whether future format changes are anticipated.

**[LOW]** **`GetAddOnInfo` fallback: `local name = GetInfo(addon.addonName)` — return value semantics not specified**
Section 7.9: `if not name then Companions.status[...] = "Not Installed"`. `GetAddOnInfo` (both old and new API) returns multiple values; the first is the addon name (or nil if not found). The spec correctly uses only the first return. ✓ But the condition `if not name` conflates "not installed" with "API returned nil for other reasons" (e.g., wrong addon name string). If `addonName` has a typo in `CompanionAddons.lua`, it silently shows as "Not Installed." The spec notes VoxTip and VoxPlacer need re-verification in Phase 5 — this is the right mitigation, but the silent failure mode should be documented.

---

## Category 4: Clarity & Documentation

**[MEDIUM]** **Section 4.4 Copy Line: "corresponding `lineBuffer` entry" — index mapping not specified**
The overlay buttons are positioned over "visible SMF lines." The spec says each button's OnClick copies "the corresponding `lineBuffer` entry." But the mapping between visible SMF line position and `lineBuffer` index is non-trivial: SMF may have scrolled, lines may have been cleared, SMF manages its own internal line buffer separately from `lineBuffer`. The spec does not explain how to map SMF visible line N to `lineBuffer[i]`. This is a significant implementation gap. Does the implementer store the original message in the button's data? Does `lineBuffer` index align with SMF's internal line count? This needs explicit specification.

**[MEDIUM]** **`UI:SetConsoleVisible` — what happens to `consoleEnabled` persistence when called programmatically vs. from Toggle?**
Section 6 (UI.lua): `UI:SetConsoleVisible(enabled)` "persists `VoxGMDB.ui.consoleEnabled`." Section 7.3: `Console:Toggle()` calls `UI:SetConsoleVisible(not currentState)`. But what is "currentState"? `VoxGMDB.ui.consoleEnabled`? A local variable? The spec does not define where `currentState` is read from inside `Console:Toggle()`. If it reads `VoxGMDB.ui.consoleEnabled`, that's consistent. If it reads a local frame visibility state, it could desync. The spec should specify the source of truth for the current visibility state.

**[MEDIUM]** **Phase 0 spike document location: `VoxCore/doc/voxgm_api_spike.md` — `VoxCore/` is ambiguous**
Section 11 (Phase 0): "Document in `VoxCore/doc/voxgm_api_spike.md` (repo-level `doc/` dir)." The parenthetical says "repo-level `doc/` dir" but the path says `VoxCore/doc/`. These are inconsistent — is it `<repo-root>/doc/voxgm_api_spike.md` or `<repo-root>/VoxCore/doc/voxgm_api_spike.md`? The spec should pick one.

**[LOW]** **`C.SCRIPT_THROTTLE_MIN = 0.1` used in throttle floor but `C.SCRIPT_THROTTLE_DEFAULT` is never referenced in runtime code**
`C.SCRIPT_THROTTLE_DEFAULT` is defined in Constants.lua but the throttle floor in `Scripts:DispatchNext()` uses `C.SCRIPT_THROTTLE_MIN`. `SCRIPT_THROTTLE_DEFAULT` is only used to populate `DEFAULTS.scripts.throttleDelay` (implicitly — see Consistency finding above). The constant name suggests it's a runtime default, but it's only a DEFAULTS initializer. Naming could mislead an implementer into thinking it's used as a fallback floor.

**[LOW]** **Section 7.7 `DispatchNext` step 2: "or not `runState.active`" — redundant with Cancel's active=false**
The spec notes in the Cancel section that the `active` flag is the primary guard. In `DispatchNext` step 2, the condition `not runState.active` handles the case where Cancel fired between the timer scheduling and the callback. This is correct and intentional. However, the spec does not explain WHY this check is there (it's not obvious to a cold reader why `active` would be false at the start of `DispatchNext` if we just scheduled it). A one-line comment in the pseudocode would prevent confusion.

**[LOW]** **`Settings.lua` Path B "Back" button — what frame state is restored?**
Section 4.8: The settings panel "replaces the main frame content area when open" and has a "Back" button to return to normal tab view. The spec does not specify what "normal tab view" means in terms of frame state — does it restore the previously active tab? The last-active tab? The default tab? This is a UX gap that will produce inconsistent behavior across implementers.

**[INFO]** **Section 12 competitive table: "Client: 12.x" for VoxGM v2 — confirms 12.x Midnight target**
Consistent with project context. No issue.

**[INFO]** **`VoxGM.Data` confirmed existing (Core.lua line 14) — `Data\CompanionAddons.lua` pattern is consistent with `Data\Presets.lua` etc.**
No issue. Correctly resolved from prior rounds.

**[INFO]** **TOC count "22 files" verified in spec — new files (5-7) would bring total to 27-29**
The spec notes 22 existing files and 5-7 new files. The TOC section in Section 6 says "Append new files" without specifying the exact new TOC lines or their order. Load order matters for namespace availability. `Console.lua` must load after `UI.lua` (it uses `VoxGM.UI.consoleHost`). `Scripts.lua` must load after `Commands.lua`. `Settings.lua` must load after `UI.lua`. `Companions.lua` must load after `Data\CompanionAddons.lua`. The spec does not specify the new TOC append order. This is a gap.

---

## VERDICT: FAIL

**Blocking issues (HIGH):**
1. `unpack` sparse-table truncation risk in shallow copy (Section 7.7)
2. `StaticPopup_Show` stale `self.data` on double-click delete (Section 7.6)
3. `VoxGM.Settings` namespace not declared in Core.lua despite being called from slash handler (Section 6)
4. Script deletion by index during active run — UI behavior unspecified (Section 7.7 / edge cases)

**Summary of required fixes before implementation:**
- Declare `VoxGM.Settings = {}` in Core.lua sub-namespace list, or explicitly document that Settings.lua self-declares
- Replace `{unpack(script.lines)}` with an explicit loop or add a non-sparse guarantee
- Address StaticPopup double-click stale data (either disable button while popup is open, or use a reference instead of index)
- Specify Delete button behavior during active script run
- Specify TOC append order for new files
- Specify Copy Line overlay-to-lineBuffer index mapping
- Clarify `Console:Toggle()` source of truth for current visibility state
- Add `ClearAllPoints()` requirement to `UI:SetConsoleVisible` anchor manipulation
- Add `EnableMouseWheel(true)` requirement for SMF scroll hook
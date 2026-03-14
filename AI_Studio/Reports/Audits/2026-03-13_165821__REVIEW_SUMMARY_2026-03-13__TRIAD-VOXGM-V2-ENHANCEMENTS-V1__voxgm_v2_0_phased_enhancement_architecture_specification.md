# Review Cycle Summary: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md

**Date**: 2026-03-13T16:58:21.950398

**Rounds completed**: 5

**Final verdict**: FAIL

**Wall time**: 404.2s | **CPU time**: 614.5s (saved 210s via parallelism)


## Round Results

| Round | Reviewer | Model | Time | Verdict | Phase |
|-------|----------|-------|------|---------|-------|
| R1 | Codex | gpt-5.4 | 197.1s | FAIL | Phase 1 |
| R2 | Gemini | gemini-2.5-pro | 66.7s | FAIL | Phase 1 |
| R3 | Claude | claude-sonnet-4-6 | 143.6s | FAIL | Phase 1 |
| R4 | Codex | gpt-5.4 | 163.1s | FAIL | Phase 2 |
| R5 | Gemini | gemini-2.5-pro | 43.9s | FAIL | Phase 3 |

## Per-Round Reviews

### Round 1: Codex (Phase 1)

**Architecture**

- **[HIGH]** The settings API contract is internally broken. The proposed slash handler calls `VoxGM.Settings:Open()`, but the Core changes only add `Console`, `Scripts`, `Companions`, and `ModelPreview` namespaces, not `Settings`, and the Settings section does not require a stable `Open()` facade for both Path A and Path B. In the current addon, the namespace block is only the v1 set in [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L7), and there is no existing Settings module to absorb that call. If an implementer follows the spec literally, `/vgm settings` can dereference `nil`.

- **[MEDIUM]** The fallback settings-panel design is not aligned with the current UI ownership model. The addon currently pre-creates tab scrollframes under `contentHost` in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L471) and switches them through `UI:SelectTab()` in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L572). The spec says the settings panel “replaces the main frame content area” and behaves like a tab, but it does not define whether it hides those existing scrollframes, how it preserves `activeTabId`, or how `Back` restores the prior tab state. That leaves an integration gap in the core view-controller contract.

**Integration**

- **[MEDIUM]** Path B depends on a widget helper that does not exist. The spec says the in-addon settings panel uses existing `UI:CreateSlider`, `UI:CreateToggleButton`, and `UI:CreateEditRow`, but [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L22), [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L39), [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68), [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L118), and [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L161) define button/editbox/slider/toggle/dropdown helpers only. There is no `CreateEditRow` helper in the repo, so the spec currently references a broken dependency.

- **[LOW]** The Phase 0 documentation path is inconsistent with the repo layout. The artifact says to document results in `VoxCore/doc/voxgm_api_spike.md`, but from the current repo root `C:\Users\atayl\VoxCore`, the existing docs directory is `doc/`, and `VoxCore/doc` does not exist. This should be normalized to `doc/voxgm_api_spike.md`.

**Verification**

- **[MEDIUM]** The companion-addon verification claims are only partially supported by the repo. I verified `SlashCmdList["CREATURECODEX"]` in [CreatureCodex.lua](C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1034) and `SlashCmdList["VOXSNIFFER"]` in [VoxSniffer.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.lua#L219). I could not verify VoxTip or VoxPlacer because `tools/publishable/VoxTip` and `tools/publishable/VoxPlacer` are not present in this workspace. The spec should not present those keys as verified source-backed facts.

- **[INFO]** Several source-backed claims in the artifact are correct:
  - TOC load count and ordering are accurate in [VoxGM.toc](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc#L12).
  - `VoxGM.Data = {}` exists in [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L14).
  - The parser-registration bug is real: `RegisterDefaultParsers()` is currently called from [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332), while the parser definitions live in [Events.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L67).
  - The current `contentHost` anchor and `UISpecialFrames` registration match the artifact in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L393) and [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L428).
  - `Cmd:SendCommand()` remains the single-command path in [Commands.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5).

**Design**

- **[LOW]** The script-overwrite popup contract is underspecified. Delete passes the array index as `self.data`, but overwrite passes only the imported script table and then says `ConfirmOverwrite(importedScript)` “replaces the existing entry.” The spec never states whether replacement is by name lookup or by stored index. That is fixable, but the API contract should be explicit.

- **[LOW]** The “secondary validation” for semicolon-joined commands is weak as written. Checking only for `" ."` or `" /"` after sanitization will miss common malformed cases like `.cmd1;.cmd2` becoming `.cmd1.cmd2` with no intervening space. If this warning is meant to mitigate a known failure mode, the heuristic needs tightening or the warning should be described as partial only.

**Scope**

- **[INFO]** The artifact stays consistent with the current addon’s extension strategy: the v1 file layout is flat and TOC-driven, the current slash handler is minimal in [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L52), state migration is additive in [State.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua#L42), and `Tab_Appearance.lua` is a reasonable integration point for preview work in [Tab_Appearance.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L27).

**Summary Since Prior Rounds**

This is Round 1 of my review against Revision 5, so I do not have prior-round fixes in this review thread to validate directly. Relative to the artifact itself, Rev5 does show evidence of prior cleanup and source-aware corrections, and most of its v1 inventory claims match the repo; the remaining issues are concentrated in cross-file contracts that are still not fully closed, especially the Settings API and a few verification/dependency claims.

**VERDICT: FAIL**

---

### Round 2: Gemini (Phase 1)

This review covers Revision 5 of the VoxGM v2.0 Phased Enhancement Architecture Specification. This revision addresses numerous findings from previous cycles, resolving issues like initialization race conditions, specifying a fallback UI for settings, and clarifying data flows for script execution and cancellation. The specification is significantly more robust and detailed than prior versions, demonstrating a mature understanding of the addon's architecture and potential edge cases.

### Correctness

*   **[CRITICAL]** The specification is internally inconsistent regarding the script runner's timer handle. The Revision 5 notes explicitly state, "DispatchNext redundant nil-clear removed." However, Section 7.7 (`Scripts:DispatchNext`) includes the line `runState.timerHandle = nil -- handle has fired, nil-clear` within the `C_Timer.NewTimer` callback. This is a direct contradiction between the documented changes and the specification text, creating critical ambiguity for the implementer. The spec must be self-consistent.

*   **[HIGH]** The specification fails to define the case-sensitivity policy for script names. It is unclear whether script names like "MyScript" and "myscript" should be treated as identical or distinct. This affects uniqueness checks (e.g., when saving or importing), lookups (when running a script), and storage. This ambiguity could lead to data loss (unintentional overwrites) or user confusion (duplicate-seeming scripts). A clear policy (e.g., "all script name comparisons must be case-insensitive, and names will be stored with their original capitalization") must be defined.

*   **[MEDIUM]** The location and invocation of the script pruning logic are ambiguous. Section 6 places the code block for pruning under `State.lua` modifications, implying it might run during migration. Section 7.6 correctly states that pruning must happen at "write-time" (i.e., when a new script is saved). The specification should explicitly define a reusable pruning function (e.g., `VoxGM.State:PruneScripts()`) and mandate that it be called from both the v2 migration logic and the script-saving function in `Scripts.lua`.

*   **[LOW]** The model previewer lacks feedback for valid-but-non-existent DisplayIDs. As per Section 4.5, an invalid ID will render nothing or a T-pose, which is expected. However, this provides no feedback to the user that the command was processed. Consider adding a `Util:Print("Attempting to preview DisplayID: " .. id)` message when `ModelPreview:Show(id)` is called with a number. This would confirm to the user that their input was received, even if the client API renders nothing.

### Security

*No findings.* The security requirements in Section 8 are robust, covering sanitization of both commands and metadata, prohibiting dynamic code execution, and mandating strict validation and throttling. The documented trade-off regarding semicolon stripping is acceptable for this tool's context.

### Performance

*   **[MEDIUM]** The specified logic for trimming the console's `lineBuffer` in Section 7.3 is inefficient. The pseudocode `while #lineBuffer > newCap do table.remove(lineBuffer, 1) end` has a high performance cost for large trims (potentially O(N^2) due to repeated shifting of all table elements). A more performant approach, such as creating a new table containing only the desired elements, should be specified to avoid potential client stalls when the user significantly reduces the `maxLines` setting.

### Style

*No findings.*

---

## VERDICT: FAIL

The specification is mature and well-structured, but the **CRITICAL** internal contradiction regarding the script runner's implementation and the **HIGH** severity ambiguity around script name handling prevent a PASS. These issues must be resolved to ensure a correct and predictable implementation.

---

### Round 3: Claude (Phase 1)

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

---

### Round 4: Codex (Phase 2)

**Architecture**
- **[CRITICAL]** — The artifact is still internally inconsistent about the script runner timer handle. The revision notes say “DispatchNext redundant nil-clear removed,” but Section 7.7 still includes `runState.timerHandle = nil` inside the timer callback. That leaves the implementer with two conflicting instructions for the same control path.
- **[HIGH]** — The settings API contract is still broken. The slash handler calls `VoxGM.Settings:Open()`, but the Core changes only add `Console`, `Scripts`, `Companions`, and `ModelPreview` namespaces. The current addon only defines the v1 namespaces in [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L7) and `VoxGM.Data` at [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L14); there is no existing `Settings` namespace to absorb that call. If the implementer follows the spec literally, `/vgm settings` can still dereference `nil`.
- **[HIGH]** — Script name identity is still undefined. The spec describes save/import/overwrite/run flows, but never states whether `MyScript` and `myscript` are the same script. That ambiguity affects uniqueness checks, overwrite behavior, lookup for `Scripts:Run(scriptName)`, and UI expectations. This is an API-contract gap, not an implementation detail.

**Integration**
- **[MEDIUM]** — The fallback settings-panel path is still underspecified against the actual UI controller. The current UI pre-creates tab scrollframes under `contentHost` in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L471) and switches them through `UI:SelectTab()` at [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L572). The artifact says the settings panel “replaces the main frame content area” and has a Back button, but it still does not define how existing scrollframes are hidden, whether `activeTabId` is preserved, or how Back restores the previous tab state.
- **[MEDIUM]** — Path B still depends on a nonexistent widget helper. The spec says the in-addon settings panel uses existing `UI:CreateSlider`, `UI:CreateToggleButton`, and `UI:CreateEditRow`, but the actual helpers are `CreateSlider` at [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68), `CreateToggleButton` at [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L118), and `CreateDropdown` at [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L161). There is no `CreateEditRow` helper in the repo.

**Verification**
- **[MEDIUM]** — The companion-addon verification is still overstated. I verified `SlashCmdList["CREATURECODEX"]` in [CreatureCodex.lua](C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1034) and `SlashCmdList["VOXSNIFFER"]` in [VoxSniffer.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.lua#L219). But `tools/publishable/VoxTip` and `tools/publishable/VoxPlacer` do not exist in this workspace, so those entries are not repo-verified facts.
- **[LOW]** — The Phase 0 documentation path is still inconsistent. The artifact says `VoxCore/doc/voxgm_api_spike.md`, but from the repo root `C:\Users\atayl\VoxCore` the actual docs directory is just `doc/`. This should be normalized to `doc/voxgm_api_spike.md`.

**Design**
- **[MEDIUM]** — The delete-popup contract is still fragile. The spec passes a numeric array index through `StaticPopup_Show(..., scriptIndex)` and then deletes by `table.remove(db.scripts.items, index)`. That index can go stale if the list mutates before confirmation. The current addon’s persisted collections are simple arrays as seen in [Favorites.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Favorites.lua#L49), so this needs an explicit stable-identity strategy.
- **[MEDIUM]** — The console buffer trimming strategy remains unnecessarily expensive. The artifact still uses `table.remove(lineBuffer, 1)` for overflow and repeated front-removal when shrinking `maxLines`. That is O(n) per removal and is weaker than existing repo cap patterns, where history removes from the tail after front insertion in [History.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/History.lua#L16) and [History.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/History.lua#L24).

**Scope**
- **[INFO]** — Several source-backed claims remain correct: the addon is TOC-driven with 22 loaded entries in [VoxGM.toc](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc#L12), `RegisterDefaultParsers()` is currently called from `UI:Init()` at [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332) instead of `Events:Init()` at [Events.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L8), and `Util:SanitizeText()` does strip `[%c|;]` in [Util.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Util.lua#L76).

Summary since prior rounds: Revision 5 did fix several concrete gaps from earlier reviews: it now specifies the console host as UI-owned, defines the fallback settings path instead of leaving it absent, makes `enabled` default `true`, documents the `StaticPopup_Show` data argument, reverses script pruning to keep newest entries, and keeps the TOC count and `VoxGM.Data` claim aligned with the repo. The remaining problems are narrower, but they are still material: one internal contradiction, one still-broken `Settings` facade, one unresolved script-name contract, and a few integration/details issues around settings, companion verification, and popup identity.

**VERDICT: FAIL**

---

### Round 5: Gemini (Phase 3)

This review assesses Revision 5 of the VoxGM v2.0 Phased Enhancement Architecture Specification. This revision claims to address all findings from four prior 5-round review cycles. However, this audit reveals that multiple critical and high-severity issues, including several explicitly flagged in previous reviews, have not been resolved. The specification contains direct contradictions, missing components that will lead to runtime errors, and persistent architectural flaws.

### Correctness

*   **[CRITICAL]** — The specification is internally inconsistent regarding the script runner's timer handle. The R5 revision notes state, "DispatchNext redundant nil-clear removed." However, Section 7.7 (`Scripts:DispatchNext`) still contains the line `runState.timerHandle = nil -- handle has fired, nil-clear` within the `C_Timer.NewTimer` callback. This is a direct contradiction that was flagged as a critical issue in a previous review round. The implementer is faced with two conflicting instructions for the same critical path.
*   **[HIGH]** — The `VoxGM.Settings` namespace is never declared, which will cause a fatal error. Section 6 (`Core.lua`) specifies adding namespaces for `Console`, `Scripts`, `Companions`, and `ModelPreview`, but omits `Settings`. The slash command handler defined in the same section explicitly calls `VoxGM.Settings:Open()`, which will attempt to index a `nil` value and halt execution. This was a high-severity finding in prior reviews that remains unaddressed.
*   **[HIGH]** — The policy for script name case-sensitivity remains undefined. The specification details create, run, import, and overwrite operations for scripts but never clarifies whether "MyScript" and "myscript" should be treated as the same entity. This ambiguity directly impacts uniqueness checks and overwrite logic, creating a high risk of data loss or unexpected behavior.
*   **[HIGH]** — The script deletion mechanism is fragile and prone to error. Section 7.6 specifies that the script's array index is passed to the `StaticPopup_Show` confirmation dialog. If the underlying script list is mutated in any way between the dialog being shown and the user confirming the action (e.g., by another script being deleted or imported), the stored index will be stale, leading to the deletion of the wrong script. Deletion should use a stable identifier like the script name.
*   **[MEDIUM]** — The specification for the fallback settings panel (Path B) relies on a non-existent UI helper function. Section 4.8 states the panel will use `UI:CreateEditRow`, but an inventory of the existing codebase confirms no such helper exists. This will block implementation.
*   **[MEDIUM]** — A required constant is missing from the specification. Section 7.3 (`Console operation`) describes persistence logic that saves the last `C.CONSOLE_HISTORY_CAP` entries. However, this constant is not listed for addition in Section 6 (`Constants.lua`), leaving its value undefined.
*   **[LOW]** — The specification omits a required file modification. Section 11 (`Implementation Order`) and Section 7.5 (`Model preview`) both state that a "Preview" button must be added to `Tab_Appearance.lua`. However, this file is not listed in Section 6 (`Modifications to Existing Files`), making the list of changes incomplete.
*   **[LOW]** — The `onComplete` callback for `Scripts:Run` has no specified consumer. While the runner is designed to call it, no part of the specification (UI, etc.) is described as providing this callback. This leaves a part of the API contract as dead code or implies a missing integration point. The spec should clarify its purpose (e.g., "reserved for future use").

### Security

*   *(No findings in this category. The specified sanitization and validation rules appear sufficient for the addon's scope.)*

### Performance

*   **[CRITICAL]** — The algorithm specified for trimming the console's `lineBuffer` is highly inefficient and risks client stalls. Section 7.3 specifies using `while #lineBuffer > newCap do table.remove(lineBuffer, 1) end`. This pattern has O(N) complexity for each removal, leading to an overall complexity of O(N^2) for a large trim. If a user changes the max lines from 2000 to 100, this operation could cause a noticeable client freeze. A performant alternative, such as creating a new table with the desired slice of elements, must be specified. This was flagged in prior reviews and has not been fixed.

### Style

*   **[MEDIUM]** — The UI integration for the fallback settings panel remains underspecified. The spec describes it as a "tab-like panel" that "replaces the main frame content area" and has a "Back" button. It fails to define the interaction with the existing tab controller: how the current tab's content is hidden, how the `activeTabId` is preserved, and how the "Back" button correctly restores the previous view state.
*   **[LOW]** — The verification status for companion addons is misleading. In Section 7.9, the data table for `CompanionAddons.lua` includes comments like `verified: deployed addon` for `VoxTip` and `VoxPlacer`, while also noting the source is not in the repository. The term "verified" should be reserved for claims substantiated by available source code; these should be marked as "assumed" or "unverified".
*   **[LOW]** — The documentation path for the Phase 0 API spike is inconsistent with the repository structure. Section 11 specifies `VoxCore/doc/voxgm_api_spike.md`. Assuming a standard checkout, the path should be specified relative to the repository root as `doc/voxgm_api_spike.md`.

---

### VERDICT: FAIL

This specification fails the review due to multiple unaddressed critical and high-severity issues from previous rounds. The presence of direct contradictions, fatal `nil` reference errors, high-risk data handling flaws, and severe performance bottlenecks makes the architecture unsound. The revision notes claim fixes that are not present in the document itself, indicating a breakdown in the revision process. The specification cannot proceed to implementation in its current state.

---

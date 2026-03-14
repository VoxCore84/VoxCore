# Review Cycle Summary: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md

**Date**: 2026-03-13T16:13:43.385675

**Rounds completed**: 5

**Final verdict**: FAIL

**Wall time**: 499.1s | **CPU time**: 674.6s (saved 175s via parallelism)


## Round Results

| Round | Reviewer | Model | Time | Verdict | Phase |
|-------|----------|-------|------|---------|-------|
| R1 | Codex | gpt-5.4 | 282.8s | FAIL | Phase 1 |
| R2 | Gemini | gemini-2.5-pro | 48.0s | FAIL | Phase 1 |
| R3 | Claude | claude-sonnet-4-6 | 127.4s | FAIL | Phase 1 |
| R4 | Codex | gpt-5.4 | 159.5s | FAIL | Phase 2 |
| R5 | Gemini | gemini-2.5-pro | 56.9s | FAIL | Phase 3 |

## Per-Round Reviews

### Round 1: Codex (Phase 1)

**Architecture**

**[HIGH]** The companion-launch contract is not implementable as written for all declared companions. The spec’s data model only stores `slashCmd`, but the launcher design explicitly calls `SlashCmdList[key]("")`, which requires the actual registry key, not the slash text. That key is not derivable in general and is not present in the proposed `Data\CompanionAddons.lua` schema. This is acceptance-critical because AC10 requires correct Open-button behavior for all four companions. The repo verifies `VOXSNIFFER`, `VOXPLACER`, and `CREATURECODEX`, but not `VOXTIP`. See [addons/VoxPlacer/VoxPlacer.lua](/C:/Users/atayl/VoxCore/addons/VoxPlacer/VoxPlacer.lua#L853), [addons/VoxSniffer/VoxSniffer.lua](/C:/Users/atayl/VoxCore/addons/VoxSniffer/VoxSniffer.lua#L217), [tools/publishable/CreatureCodex/client/CreatureCodex.lua](/C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1032).

**[MEDIUM]** The spec preserves an existing bad boundary: default parser registration currently happens inside `UI:Init()`, not `Events:Init()`. That means event parsing is unavailable until `PLAYER_LOGIN` and until the UI module initializes, even though `CHAT_MSG_SYSTEM` is registered earlier on `ADDON_LOADED`. Extending the event pipeline without fixing that ownership keeps an avoidable init race in place. See [Events.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L13), [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332), [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L28).

**[MEDIUM]** `Cmd:SendSequence()` is specified as a `Commands.lua` API, but its implementation is described as directly storing state in `Scripts.runState`. That inverts ownership and creates needless coupling between the low-level command dispatcher and the higher-level scripts subsystem. The cleaner boundary is `Scripts` owning sequencing and calling `Cmd:SendCommand()`. The current spec creates a circular design without a good reason. Relevant existing dispatcher boundary: [Commands.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5).

**Integration**

**[MEDIUM]** Conditional features are not guarded consistently in the proposed interfaces. The spec says model preview and settings are conditional on the Phase 0 spike, but the sample slash dispatcher calls `VoxGM.ModelPreview:Show(id)` directly and the sample `PLAYER_LOGIN` path includes `VoxGM.ModelPreview:Init()`. If the spike fails and the module is omitted, those call sites will nil-deref unless the final design adds guards everywhere. Current slash handling is centralized in [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L52), so this needs to be explicit in the contract.

**[MEDIUM]** The console “Copy Line” requirement is underspecified against the chosen widget. A `ScrollingMessageFrame` is fine for append-only output, but the spec does not define how a specific clicked line becomes selectable text; `ScrollingMessageFrame` does not inherently expose per-line click targets. Without an explicit line-model or overlay-row design, this is an incomplete UI contract, not just an implementation detail. The existing UI is widget-helper based, not line-virtualized, in [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L1).

**Verification**

**[LOW]** The artifact’s inventory is slightly inaccurate. The actual publishable addon tree in this repo is under `tools/publishable/VoxGM`, not `addons/VoxGM`, and it contains 24 files total in this workspace, not 25. The loaded-file count of 22 from [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc) is correct, and there are no XML files today.

**[LOW]** Several source-backed claims are correct and should stay, but a few are overstated as “verified.” The existing migration backfill loops do exist at [State.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua#L57), integer-only slider behavior exists at [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68), `UISpecialFrames` registration exists at [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L428), and the `.wmorph` field exists at [Modules/Tab_Appearance.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L31). By contrast, VoxTip verification is not possible from the repo contents provided.

**Design**

**[LOW]** The spec’s additive migration plan matches the current state system well, but it should explicitly say new nested tables must also be validated at write time, not only during migration. The existing code prunes history/favorites structurally during migration and enforces caps during normal writes in [Modules/History.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/History.lua#L8) and [Modules/Favorites.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Favorites.lua#L13); scripts/console should follow that same full lifecycle pattern.

**Scope**

**[INFO]** The spec is generally well-scoped against the current addon. The zero-dependency constraint, additive TOC growth, existing module pattern, current slash-command minimalism, sanitization routine, and current staggered-command usage all match the live code in [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua), [Util.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Util.lua#L76), and [Modules/Tab_Appearance.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L133).

No prior-round implementation artifact was provided in this review thread, so there is no code delta to summarize since earlier rounds. This review is based on the Revision 3 spec compared against the current repo state.

**VERDICT:** FAIL

---

### Round 2: Gemini (Phase 1)

This review is for Revision 3 of the VoxGM v2.0 Phased Enhancement Architecture Specification.

This revision represents a significant maturation of the architecture, addressing numerous findings from previous review cycles. Key improvements include the specification of a robust, cancellable script runner using `C_Timer.NewTimer`, which is a major upgrade over the previous fire-and-forget model. Security has been substantially hardened with the explicit requirement to sanitize not only imported script commands but also their metadata, mitigating potential UI injection attacks. The specification for companion addon detection is now more detailed, using a correct three-state logic model, and the console architecture includes a necessary race guard for initialization. These changes demonstrate a strong focus on correctness, security, and robustness.

---

### Correctness

*   **[HIGH]** — Inconsistent specification for companion addon UI state. Section 7.9 ("Detection logic") describes the state for an "Installed" (but not loaded) addon as having a disabled "Open" button. However, Acceptance Criterion #10 in Section 10 describes the same state as having "no button". A disabled button provides superior user feedback by indicating that the feature is present but currently unavailable, whereas the absence of a button could be misinterpreted as the feature not existing at all. The specification must be made consistent before implementation; the behavior described in Section 7.9 is recommended.

*   **[MEDIUM]** — Ambiguous handling of `console.persistHistory` state changes post-migration. Section 6 (`State.lua`) correctly specifies that `console.persistedLines` should be cleared during migration if `persistHistory` is `false`. However, the spec does not define the behavior if a user toggles this setting from `true` to `false` during a game session. To align with user expectations and prevent stale data from bloating the SavedVariables file, the `persistedLines` table should be cleared either immediately when the setting is changed or upon the next logout. This behavior should be explicitly specified.

*   **[LOW]** — Missing specification for console history persistence mechanism. Section 7.3 states that recent console lines are saved to `VoxGMDB.console.persistedLines` "on logout". This implies the need for a `PLAYER_LOGOUT` event handler to perform the save operation. The specification does not mention where this handler should be registered or implemented, which is a necessary detail for the feature to function as described.

*   **[LOW]** — Companion addon launch contract is potentially fragile. Section 7.9 proposes launching companion addons by directly calling their handler in the global `SlashCmdList` table (e.g., `SlashCmdList["CREATURECODEX"]("")`). While this is more direct than emulating chat input, it creates a tight coupling to an internal implementation detail of the target addon (the slash command's table key). If a companion addon refactors its slash command registration, this integration will silently break. The spec should acknowledge this risk and could suggest a more robust fallback, such as checking for a global toggle function (e.g., `_G.CreatureCodex_ToggleUI`) if one is known to exist.

### Security

*   No findings. The security requirements outlined in Section 8 are comprehensive and well-defined. The mandatory sanitization of both script commands and metadata via `Util:SanitizeText` effectively addresses UI injection and command chaining risks. The strict prohibition of dynamic code execution (`loadstring`, etc.) and the enforcement of throttling are appropriate and necessary safeguards.

### Performance

*   No findings. The architecture makes sound performance decisions. Creating the `PlayerModel` frame once during initialization instead of on-demand prevents repeated frame creation overhead. The cancellable, recursive timer model for the script runner is efficient and avoids the potential performance degradation of creating dozens of unmanaged `C_Timer.After` timers for long scripts.

### Style

*   No findings. The specification is clear, well-structured, and internally consistent, with the exception of the single high-severity correctness issue noted above.

---

### VERDICT: FAIL

The specification is very strong but contains a high-severity correctness issue: a direct contradiction between the functional description and the acceptance criteria for the companion addon UI. This ambiguity must be resolved before implementation can proceed. Once this and the other minor findings are addressed, the specification will be on a clear path to success.

---

### Round 3: Claude (Phase 1)

# Cold-Read Review: VoxGM v2.0 Phased Enhancement Architecture Specification (Revision 3)

**Reviewer:** Cold-Read (VoxCore Triad)
**Artifact:** TRIAD-VOXGM-V2-ENHANCEMENTS-V3
**Round:** 3

---

## Summary of Changes Since Prior Rounds

Revision 3 addresses a substantial backlog from two prior 5-round cycles. Key improvements: the script runner is now a cancellable recursive single-timer model (replacing fire-and-forget chains), `scriptThrottle` was relocated to `scripts.throttleDelay`, the console buffer cap is now user-configurable via `DEFAULTS`, a console init race guard (`_initialized` flag) is specified, import metadata sanitization is added, companion detection uses `GetAddOnInfo` for 3-state logic, `#` lines are clarified as import-only metadata, the dead `SendCommandThrottled` function is removed, console grouping heuristic is removed (chronological only), model preview scope is standardized, the slash tokenizer is specified, slider decimal support is noted, and companion launch contracts are grounded in verified slash commands. The document is materially more complete and internally consistent than prior rounds.

---

## Findings

### Implementation Bias

**[HIGH]** **`Scripts.runState` ownership is ambiguous between `Scripts.lua` and `Commands.lua`** — Section 7.7 defines `Scripts.runState` as a field on the `Scripts` module, but Section 6 (Commands.lua changes) says `Cmd:SendSequence()` "stores the command list in `Scripts.runState`". This creates a cross-module write dependency: `Commands.lua` writes into `Scripts.lua`'s internal state. Since `Commands.lua` loads before `Scripts.lua` in the TOC (implied by load order — `Commands.lua` is in the root, `Scripts.lua` is new and appended), `Commands.lua` cannot safely reference `VoxGM.Scripts` at definition time. The spec never resolves whether `Cmd:SendSequence()` is a thin wrapper that calls `Scripts:Run()`, or whether it independently manages `Scripts.runState`. A new developer would implement this two different ways depending on which section they read first.

**[HIGH]** **`Console:OnMessage()` receives a `"system"` type tag but the spec never defines what other types exist or how they're used** — The forwarding call passes `"system"` as the second argument: `Console:OnMessage(msg, "system")`. Section 7.3 says the console "has its own independent display logic: timestamps, formatting." But the spec never defines what `Console:OnMessage()` does with the type parameter — does it affect color, prefix, filtering? If the type parameter is unused, passing it is misleading. If it's used for filtering/coloring, the spec omits the contract entirely. An implementer has no guidance here.

**[MEDIUM]** **`Scripts:DispatchNext()` has an off-by-one ambiguity** — Section 7.7 says: "sets `index = 0`, and calls `Scripts:DispatchNext()`" and then "`Scripts:DispatchNext()` increments `index`." So the first call increments 0→1 and dispatches `commands[1]`. This is correct. However, the completion check is "If `index > #commands`" — this fires *after* incrementing but *before* dispatching. The spec doesn't clarify whether the completion check happens before or after the dispatch call within `DispatchNext()`. If the check is at the top of the function (increment, check, then dispatch), it's correct. If the dispatch happens before the check, the last command fires and then the *next* call checks completion. The pseudocode in the spec is ambiguous about this ordering, and a subtle bug (double-dispatch of last command, or skipped last command) is easy to introduce.

**[MEDIUM]** **`Cmd:SendSequence()` is specified in Commands.lua but its relationship to `Scripts:Run()` is never clarified** — Section 7.7 says `Scripts:Run(scriptName)` is the entry point. Section 6 says `Cmd:SendSequence(commands, source, onComplete)` is added to Commands.lua and "kicks off the first recursive timer step." These appear to be two different entry points for the same execution model. Are they the same function? Does `Scripts:Run()` call `Cmd:SendSequence()`? Does `Cmd:SendSequence()` call `Scripts:Run()`? The spec never resolves this. A new developer reading Section 6 would implement `Cmd:SendSequence()` as the runner; reading Section 7.7 they'd implement `Scripts:Run()` as the runner. Both can't be the canonical entry point.

**[MEDIUM]** **The `onComplete` callback in `Scripts:Run()` is mentioned in Section 7.7 but never surfaced in the public API spec** — Section 7.7 says "call `onComplete` if provided" but `Scripts:Run(scriptName)` in the same section takes only `scriptName`. The `onComplete` parameter appears in `Cmd:SendSequence(commands, source, onComplete)` in Section 6. If `Scripts:Run()` is the public API, it needs to accept and thread through `onComplete`. If `Cmd:SendSequence()` is the public API, `Scripts:Run()` is internal. The spec conflates both without resolution.

**[MEDIUM]** **Companion status is written into the static metadata table at runtime** — Section 7.9 writes `addon.status = "Not Installed"` directly into the `VoxGM.Data.CompanionAddons` table entries. This mutates a data table that was loaded from `Data\CompanionAddons.lua`. If `Companions:Init()` is called more than once (e.g., on reload without full restart), the status fields from the previous run persist. More importantly, writing runtime state into a data table violates the separation between static data and runtime state that the rest of the architecture maintains. The status should be stored in a separate runtime table (e.g., `Companions.status[addonName]`).

**[LOW]** **Phase 0 spike results are never fed back into the spec** — The spec is written as "if Phase 0 confirms X, do Y." But this is Revision 3 — if Phase 0 has been run, the conditional language should be resolved. If Phase 0 has *not* been run, the spec is incomplete for implementation. A new developer reading this doesn't know whether to implement the conditional branches or not. The spec should either resolve the conditionals or explicitly state "Phase 0 has not yet been run; implementer must run spike first."

---

### Consistency

**[HIGH]** **`State:Migrate()` backfill for `companions` uses a shallow copy but `console` and `scripts` use `DeepCopy`** — In the per-key backfill loops (Section 6, State.lua), the `console` and `scripts` loops use `VoxGM.Util:DeepCopy(v)` for table values. The `companions` loop uses bare `v` with no DeepCopy: `if db.companions[k] == nil then db.companions[k] = v end`. Since `DEFAULTS.companions` currently only has `showPanel = true` (a boolean), this is harmless today. But it's inconsistent with the pattern used for the other two tables, and if a future version adds a table-valued key to `companions`, this will silently share a reference with `DEFAULTS`. The inconsistency will confuse the implementer about which pattern is correct.

**[HIGH]** **`Util:SanitizeText()` strips semicolons, but `.` commands legitimately contain semicolons in some TrinityCore syntax** — Section 3 documents that `SanitizeText` strips `[%c|;]` including semicolons. Section 8 mandates that every command line is sanitized before dispatch. If any TrinityCore GM command uses semicolons as argument separators (e.g., coordinate formats, multi-value arguments), sanitization will silently corrupt those commands. The spec never audits whether any existing v1 commands or expected v2 script commands use semicolons. This is a latent correctness bug that could produce confusing behavior (command appears to send but has wrong arguments).

**[MEDIUM]** **`C.CONSOLE_HISTORY_CAP = 50` is defined in Constants.lua but the cap enforcement at write time is only mentioned for migration** — Section 6 (State.lua) says `persistedLines` is "capped at `C.CONSOLE_HISTORY_CAP` (50)" and migration cleans up stale data. But the spec never specifies *where* the cap is enforced at write time (i.e., when saving on logout). `Console.lua` presumably writes to `VoxGMDB.console.persistedLines` on logout, but the spec doesn't describe the logout event handler, the write logic, or where the 50-line cap is enforced during that write. An implementer has to infer this entirely.

**[MEDIUM]** **The "Open" button for companions is described as disabled for "Installed" state in Section 7.9 but the acceptance criteria (AC 10) says "no button" for Installed** — Section 7.9: "Installed" → "yellow text, 'Open' button disabled (not loaded)." AC 10: "Installed" (yellow, no button). These are different UX behaviors. "Disabled button" and "no button" are not the same. An implementer reading both sections will implement one or the other, and neither is definitively correct per the spec.

**[MEDIUM]** **`ScrollingMessageFrame:SetMaxLines()` is called with `VoxGMDB.console.maxLines` but the spec never specifies when this is called if the user changes the cap mid-session** — Section 7.3 says the cap comes from `VoxGMDB.console.maxLines`. If the user changes `maxLines` via the Settings panel (Section 7.11), the spec doesn't say whether `SetMaxLines()` is called immediately (live update) or only takes effect on next login. `ScrollingMessageFrame:SetMaxLines()` may also clear the existing buffer when called — the spec doesn't address this side effect.

**[LOW]** **`C.SCHEMA_VERSION = 2` in Constants.lua conflicts with the existing `C.SCHEMA_VERSION` value** — Section 6 says "Add: `C.SCHEMA_VERSION = 2`". But `C.SCHEMA_VERSION` already exists in `Constants.lua` (it's listed in the v1 inventory). The spec says "Add" when it should say "Change" or "Update." A literal implementer following "Add" might write a second assignment or a new constant with a different name, leaving the old value in place.

**[LOW]** **The `doc/` directory is referenced in Phase 0 as "already exists in VoxCore"** — The spec says to document Phase 0 findings in `doc/voxgm_api_spike.md` and notes the `doc/` directory already exists. But the v1 codebase inventory (Section 3) lists only `Data\` and `Modules\` as subdirectories. If `doc/` is a VoxCore repo-level directory (not inside the addon folder), this is fine but ambiguous. If it doesn't exist inside the addon folder, the implementer needs to create it or use a different path. The spec should clarify the full path (e.g., `VoxCore/doc/` vs `VoxCore/Addons/VoxGM/doc/`).

---

### Edge Cases

**[HIGH]** **`Scripts:Cancel()` calls `runState.timerHandle:Cancel()` but the handle may be nil if cancellation is called between timer callbacks** — Section 7.7 says "calls `runState.timerHandle:Cancel()` if the handle exists." The guard is mentioned but not specified precisely. Between the moment `DispatchNext()` dispatches a command and the moment it assigns the new `timerHandle`, there is a window where `timerHandle` holds the *previous* (already-fired) timer handle. Calling `:Cancel()` on an already-fired `C_Timer.NewTimer` handle is undefined behavior in WoW's API — it may error, silently fail, or succeed. The spec should specify that `timerHandle` is set to `nil` after it fires, and that the cancel guard checks for `nil` specifically.

**[HIGH]** **No error handling is specified for `PlayerModel:SetDisplayInfo()` with an invalid ID** — Section 7.5 says "If the ID is invalid or the API is unavailable, a 'No preview available' label is shown." But `SetDisplayInfo()` with an invalid ID does not throw a Lua error in WoW — it silently renders nothing or a T-pose. The spec never defines how the addon *detects* that an ID is invalid (there is no return value from `SetDisplayInfo`). The "error state display" in Section 7.5 has no triggering condition. An implementer cannot implement this without guessing (e.g., checking if the model has zero bounds after a frame delay, which is fragile).

**[MEDIUM]** **Script import with zero valid command lines after filtering is not handled** — Section 7.8 specifies truncation warnings for oversized imports and dropping of invalid lines, but never specifies what happens if the entire import results in zero valid command lines (e.g., a file that is all `#` metadata lines, or all lines fail the `.`/`/` prefix check). Should this show an error? Create an empty script? The spec is silent.

**[MEDIUM]** **`StaticPopup_Show` for script overwrite confirmation (Section 7.8) requires a pre-registered popup definition** — `StaticPopup_Show` requires the popup to be registered via `StaticPopupDialogs["KEY"] = {...}` before it can be shown. The spec mentions using `StaticPopup_Show` for both deletion confirmation (Section 7.6) and import overwrite confirmation (Section 7.8) but never specifies where these popup definitions are registered, what their keys are, or what their button callbacks do. This is a non-trivial implementation detail that's entirely absent.

**[MEDIUM]** **The console pane geometry change (Section 6, UI.lua) doesn't address what happens when `consoleEnabled = false` at init** — The spec describes a collapsible console pane with anchor chain changes. But if `VoxGMDB.ui.consoleEnabled` is `false` on load, the console should start collapsed. The spec doesn't specify whether `Console:Init()` reads this flag and starts collapsed, or whether the UI geometry is always built and then hidden. If the console frame is always created but hidden, the anchor chain still needs to handle the "no console" layout correctly at init time.

**[MEDIUM]** **`Scripts:Run()` doesn't specify behavior when called while `runState.active == true`** — What happens if the user clicks "Run" on a second script while one is already executing? The spec doesn't say: queue it, reject it with an error message, auto-cancel the current run, or silently overwrite `runState`. This is a real UX scenario that needs a defined behavior.

**[LOW]** **`Console:Toggle()` is referenced in the slash command handler (Section 6, Core.lua) but never defined in the Console module spec** — Section 7.3 describes `Console:OnMessage()`, `ScrollingMessageFrame:Clear()`, and the "Copy Line" mechanism, but never mentions a `Console:Toggle()` method. The slash handler calls `VoxGM.Console:Toggle()` — this method needs to be specified.

**[LOW]** **`ModelPreview:Show(id)` is called from the slash handler with a potentially nil `id`** — The slash handler calls `VoxGM.ModelPreview:Show(id)` where `id = tonumber(rest)`. If the user types `/vgm preview` with no argument, `rest` is `""`, `tonumber("")` returns `nil`, and `ModelPreview:Show(nil)` is called. The spec doesn't define how `Show()` handles a nil argument — show the panel with empty input? Show last previewed ID? Error silently?

**[LOW]** **Export format for scripts with special characters in name/description is unspecified** — Section 7.8 defines the export format as `# Name: <name>`. If the name contains a colon (e.g., "Setup: Scene 1"), the import parser splitting on `: ` would produce `Name` and `Setup` as key/value, with `: Scene 1` lost. The spec doesn't define the parsing rule for `# Key: Value` lines precisely enough to handle colons in values.

---

### Clarity

**[HIGH]** **The spec uses "backfill loop" to mean two different things** — Section 4.3 says "New nested tables (`console`, `scripts`, `companions`) will automatically be picked up by the existing top-level backfill loop (`State.lua:57-61`)." But the top-level loop adds missing *top-level keys* via `DeepCopy` — it copies the entire `DEFAULTS.console` table as a unit. The *per-key* backfill loops (lines 62-67 and the new v2 loops) then fill in missing sub-keys within those tables. The spec conflates these two mechanisms in several places, making it unclear whether a new nested table needs both the top-level loop (it gets this automatically) AND a per-key loop (it needs this added). The answer is "both," but a reader has to piece this together from scattered references.

**[MEDIUM]** **Section 7.7 uses "clean up runState" without specifying what cleanup means** — "execution is complete — clean up runState and call `onComplete` if provided." Does cleanup mean setting `active = false`, setting `timerHandle = nil`, clearing `commands = {}`, resetting `index = 0`? Or just `active = false`? The spec is vague about the post-execution state of `runState`, which matters for the next `Scripts:Run()` call.

**[MEDIUM]** **The `source` parameter in `Cmd:SendCommand(cmdStr, source)` is never defined for script execution** — Section 7.7 says `runState.source = ""` (the script name, "passed to `Cmd:SendCommand` as source"). But `runState.source = ""` is initialized to an empty string, and the comment says it's the script name. These contradict each other. What value is actually passed as `source` when dispatching script commands — the script name, an empty string, or something else?

**[MEDIUM]** **"Stretch goal" vs "not in acceptance criteria" is used inconsistently** — Section 7.5 says CNPC tab integration is a "Stretch goal, not in acceptance criteria." AC 7 says "CNPC tab integration is a stretch goal." Section 11 Phase 3 says "Skip or degrade if Phase 0 spike showed SetDisplayInfo is unavailable." The spec uses "stretch goal," "not in acceptance criteria," and "conditionally in scope" in overlapping ways without a clear definition of what each means for the implementer. Does "stretch goal" mean "implement if time allows" or "do not implement in v2.0"?

**[LOW]** **`C.CONSOLE_MAX_LINES_MIN` and `C.CONSOLE_MAX_LINES_MAX` are described as "only define the allowed range" but are also used in validation logic** — Section 6 (Constants.lua note) says "Constants only define the allowed range." Section 6 (State.lua) says "clamp `console.maxLines` to `[C.CONSOLE_MAX_LINES_MIN, C.CONSOLE_MAX_LINES_MAX]` during migration." This is fine and consistent, but the phrasing "only define the allowed range" implies they're documentation-only, when they're actually used in runtime validation. Minor clarity issue.

**[LOW]** **The `enabled` field on script entries (`{name, description, lines[], enabled}`) is never explained** — Section 7.6 defines the script structure with an `enabled` field. Section 7.7 says "collects enabled lines from the script." But it's ambiguous whether `enabled` is a per-script flag (the whole script is enabled/disabled) or a per-line flag (individual lines can be disabled). The phrase "enabled lines" in 7.7 suggests per-line, but the schema in 7.6 shows `enabled` as a single field on the script object, not on each line. This needs clarification.

**[LOW]** **The `_initialized` flag pattern is specified for Console but not for other new modules** — Section 4.4 specifies `Console._initialized` as a guard against pre-PLAYER_LOGIN calls. Sections 7.5, 7.6, and 7.9 describe `ModelPreview:Init()`, `Scripts:Init()`, and `Companions:Init()` but don't specify whether these modules need similar guards. If any of these modules have methods called before `PLAYER_LOGIN` (e.g., from UI interactions that fire before login completes), they'd need the same pattern. The spec is inconsistent about which modules need init guards.

---

## VERDICT: **FAIL**

**Critical/High issues present:** 7 HIGH findings.

The spec is substantially improved from prior rounds and is close to implementable. However, several HIGH-severity issues remain that would cause a new developer to make incompatible implementation choices or introduce bugs:

1. The `Scripts.runState` ownership / `Cmd:SendSequence()` vs `Scripts:Run()` ambiguity would produce two different architectures depending on which section the implementer reads first.
2. The `companions` backfill shallow-copy inconsistency is a latent reference-sharing bug.
3. The `timerHandle:Cancel()` on a fired handle is undefined behavior that needs explicit nil-clearing.
4. The `PlayerModel:SetDisplayInfo()` invalid-ID detection has no triggering condition — the error state is unimplementable as specified.
5. The `SanitizeText` semicolon stripping may silently corrupt legitimate GM commands.
6. The "Open button disabled" vs "no button" contradiction between Section 7.9 and AC 10 will produce inconsistent UX.
7. The `State:Migrate()` "Add" vs "Update" for `C.SCHEMA_VERSION` is a literal implementation trap.

---

### Round 4: Codex (Phase 2)

**Architecture**
- **[HIGH]** — The script-runner ownership is still split across two modules. Section 6 says `Commands.lua` adds `Cmd:SendSequence()` that writes into `Scripts.runState`, while Section 7.7 makes `Scripts:Run()` the canonical runner. That keeps the same boundary problem from prior rounds: the low-level dispatcher now depends on higher-level script state instead of `Scripts` owning sequencing and calling `Cmd:SendCommand()`. The current dispatcher is intentionally narrow in [Commands.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua), and this spec still muddies that boundary.
- **[MEDIUM]** — The parser-init race is not actually resolved in the architecture. The live addon registers `CHAT_MSG_SYSTEM` in [Events.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua), but the built-in parsers are still registered from `UI:Init()` in [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua), after `Events:Init()` is called from [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua). The revised spec documents the event pipeline, but it still does not explicitly move default parser ownership into `Events`, so the bad init boundary remains.
- **[MEDIUM]** — Conditional modules are still not guarded consistently. The spec says model preview and settings are contingent on the Phase 0 spike, but its sample slash dispatcher and `PLAYER_LOGIN` init path still call `VoxGM.ModelPreview` directly. In the current addon, slash dispatch is centralized in [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua); without explicit nil-safe guards, this is still an implementation trap.

**Integration**
- **[HIGH]** — The companion-launch contract is still not fully repo-verified for all four required addons. The slash registrations for CreatureCodex, VoxSniffer, and VoxPlacer are present in [CreatureCodex.lua](/C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua), [VoxSniffer.lua](/C:/Users/atayl/VoxCore/addons/VoxSniffer/VoxSniffer.lua), and [VoxPlacer.lua](/C:/Users/atayl/VoxCore/addons/VoxPlacer/VoxPlacer.lua). But there is no `addons/VoxTip/VoxTip.lua` in this workspace, and `Get-ChildItem` against [addons/VoxTip](/C:/Users/atayl/VoxCore/addons/VoxTip) returned nothing. AC10 still requires correct Open-button behavior for VoxTip, so the spec’s “grounded in verified slash commands” claim is overstated and acceptance-critical.
- **[HIGH]** — The companion UI contract is still internally inconsistent. Section 7.9 says an “Installed” addon shows a disabled Open button, while AC10 says “Installed” means no button. That is the same acceptance-level contradiction raised previously, and it still blocks a deterministic implementation.
- **[MEDIUM]** — Section 7.9 still writes runtime status back into the static metadata entries (`addon.status = ...`). That mixes runtime state with data loaded from `Data\CompanionAddons.lua` and weakens separation of concerns. The cleaner contract is a runtime state table owned by `Companions.lua`, not mutation of the data registry.

**Verification**
- **[MEDIUM]** — The console “Copy Line” contract is still incomplete against the chosen widget. The spec now says a hidden `EditBox` is populated with the clicked line’s text, but it still never defines how a specific line in a `ScrollingMessageFrame` becomes clickable or addressable. The live UI toolkit in [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua) has no existing per-line virtualization pattern to inherit here, so this is still an underspecified integration point.
- **[LOW]** — The artifact’s verification language is stronger than the repo evidence. It is fair to say the launch contract is repo-verified for CreatureCodex, VoxSniffer, and VoxPlacer; it is not fair to say that for VoxTip based on this workspace.

**Design**
- **[MEDIUM]** — The script data model is still ambiguous. Section 7.6 defines each script as `{name, description, lines[], enabled}`, which reads like a per-script flag, but Section 7.7 says execution “collects enabled lines,” which implies per-line enable state. Those are different schemas, and CRUD/import/export behavior depends on which one is intended.
- **[MEDIUM]** — Console persistence is still only partially specified. The spec covers migration cleanup for `console.persistedLines`, but it still does not define the normal-session lifecycle: when `PLAYER_LOGOUT` saves the buffer, where the 50-line cap is enforced at write time, or what happens when `persistHistory` is toggled from true to false after migration. The existing addon does enforce write-time caps for comparable stores in [History.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/History.lua) and [Favorites.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Favorites.lua); this new store should be specified to the same standard.
- **[LOW]** — The migration pseudocode still uses inconsistent copy semantics: `console` and `scripts` deep-copy table defaults, while `companions` assigns `v` directly. That is harmless with the current `showPanel = true`, but it is an avoidable future footgun and makes the migration pattern less coherent.

**Scope**
- **[LOW]** — This Round 4 spec still depends on unresolved Phase 0 spike outcomes for settings, bindings, and model preview behavior. The repo-level `doc/` directory claim is verified at [doc](/C:/Users/atayl/VoxCore/doc), but the spec remains partly provisional rather than fully implementation-ready.

Revision 3 does improve several areas from prior rounds: it removes the dead throttled-command API, clarifies that console display is chronological only, adds import-metadata sanitization, correctly points to `GetAddOnInfo`/`IsAddOnLoaded` for three-state detection, and grounds three companion slash registrations in actual repo code. The remaining blockers are the same class of issues the earlier reviews identified: one acceptance-critical companion remains unverified, the companion UI contract is still contradictory, the script-runner boundary is still split between `Commands` and `Scripts`, and the console click/copy interaction is still not specified concretely enough to implement safely.

**VERDICT: FAIL**

---

### Round 5: Gemini (Phase 3)

This review assesses Revision 3 of the VoxGM v2.0 Phased Enhancement Architecture Specification. This revision claims to address all findings from ten prior review rounds. While some improvements have been made—notably the formalization of a cancellable script runner, configurable console settings, and required sanitization for imported metadata—this review finds that the majority of critical and high-severity architectural flaws from previous rounds remain unaddressed. The specification is not in an implementable state.

### Correctness

*   **[CRITICAL]** Companion Launch Contract is Unimplementable — Section 7.9 specifies launching companion addons by calling `SlashCmdList[key]("")`, which requires the internal registry key (e.g., `CREATURECODEX`). However, the data model defined for `Data\CompanionAddons.lua` in the same section only provides the `slashCmd` string (e.g., `"/codex"`), from which the key cannot be reliably derived. The implementation logic is therefore disconnected from the data it is specified to use, making this feature impossible to implement as written and breaking Acceptance Criterion #10.
*   **[HIGH]** Contradictory Acceptance Criteria for Companion UI State — The specification is internally inconsistent regarding the UI for an "Installed" (but not loaded) companion addon. Section 7.9 states it should show a "disabled 'Open' button," while Acceptance Criterion #10 in Section 10 requires "no button" for the same state. These are mutually exclusive requirements that make it impossible for an implementation to satisfy the specification. This was flagged in multiple prior reviews and remains unresolved.
*   **[HIGH]** Data Sanitization Routine Risks Command Corruption — Section 8 mandates that `Util:SanitizeText()` be applied to all command lines. Section 3 confirms this function strips semicolons. As some TrinityCore GM commands can legitimately use semicolons as argument separators, this global sanitization step risks silently corrupting valid commands before they are sent to the server. The spec provides no audit or mitigation for this significant correctness risk.
*   **[HIGH]** Ambiguous Script Data Model for `enabled` State — The spec creates confusion about how scripts are enabled or disabled. Section 7.6 defines the script data structure as `{name, description, lines[], enabled}`, which implies a single boolean flag for the entire script. In contrast, Section 7.7 describes the runner's logic as "collects enabled lines from the script," which implies a per-line enabled state. These are fundamentally different data models, and the ambiguity makes the authoring UI and runner logic impossible to specify clearly.
*   **[MEDIUM]** Inconsistent SavedVariables Backfill Logic — In Section 6, the migration pseudocode for new nested tables shows an inconsistency. The `console` and `scripts` backfill loops correctly use `DeepCopy` for table-valued defaults, which prevents shared references. The `companions` loop, however, uses a direct assignment (`db.companions[k] = v`), creating a maintenance hazard should that default table ever contain nested tables.
*   **[MEDIUM]** Undefined Behavior for Concurrent Script Execution — The script execution model in Section 7.7 does not define what should happen if a user attempts to run a second script while one is already in progress. The system could crash, queue the request, abort the current script, or silently ignore the new one. This is a critical edge case that must be defined.
*   **[MEDIUM]** Undefined Behavior for Invalid Model Preview ID — Section 7.5 requires showing an error label for an invalid DisplayID. However, the underlying `PlayerModel:SetDisplayInfo()` API does not return an error or provide a callback to signal failure; it typically just renders nothing. The spec provides no mechanism for *detecting* that an ID was invalid, making the required error state impossible to implement reliably.
*   **[MEDIUM]** Incomplete Console Persistence Lifecycle — Section 7.3 states console history is saved "on logout," but the spec fails to define the `PLAYER_LOGOUT` event handler, where it should be registered, or the logic for enforcing the `C.CONSOLE_HISTORY_CAP` at write-time. This leaves a core part of the feature underspecified.

### Security

*   No new security issues found. The requirements for sanitizing both command lines and imported metadata (Section 8) are sound, provided the semicolon issue under Correctness is resolved. The prohibition of dynamic code execution is also correctly specified.

### Style / Architecture

*   **[HIGH]** Script Runner Architecture Inverts Module Dependencies — The spec continues to define `Cmd:SendSequence()` in the low-level `Commands.lua` module while having it directly manipulate the state (`Scripts.runState`) of the high-level `Scripts.lua` feature module. This violates clean architecture principles by creating a dependency from a core utility to a feature module. The correct pattern is for the feature module (`Scripts`) to own its state and call the core utility (`Cmd:SendCommand`) in its execution loop.
*   **[MEDIUM]** Conditional Feature Implementation is Not Guarded — The spec makes Model Preview and the Settings Panel conditional on a "Phase 0" API spike. However, the code examples for the slash command handler and `PLAYER_LOGIN` init sequence call these modules directly (e.g., `VoxGM.ModelPreview:Show()`) without any nil-guards. If the spike fails and the modules are omitted, these direct calls will cause runtime errors. All calls to conditional modules must be specified as nil-safe.
*   **[MEDIUM]** Underspecified UI Interaction Logic — The spec continues to hand-wave non-trivial UI problems. The "Copy Line" feature for the console still lacks a mechanism for making a line in a `ScrollingMessageFrame` clickable. Similarly, the use of `StaticPopup_Show` for confirmations is required, but the spec never defines where or how the necessary popup dialogs are registered.
*   **[LOW]** Phase 0 Spike Conditionals Remain Unresolved — This is Revision 3 of a P1 specification. The continued use of conditional language ("if Phase 0 confirms...") indicates that foundational discovery work has not been completed, leaving the spec in a provisional state unsuitable for implementation.

---

### VERDICT: FAIL

This specification has multiple unresolved critical and high-severity issues, many of which were identified in previous review cycles. The revision notes' claim to have addressed all prior findings is demonstrably false. The document contains contradictory requirements, unimplementable technical contracts, and significant architectural flaws. It cannot be approved for implementation.

---

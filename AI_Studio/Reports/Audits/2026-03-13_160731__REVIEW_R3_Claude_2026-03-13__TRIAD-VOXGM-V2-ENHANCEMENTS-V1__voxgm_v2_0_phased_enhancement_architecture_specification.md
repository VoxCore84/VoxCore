---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 3
reviewer: Claude
model: claude-sonnet-4-6
date: 2026-03-13T16:07:31.673401
elapsed_seconds: 127.4
---

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
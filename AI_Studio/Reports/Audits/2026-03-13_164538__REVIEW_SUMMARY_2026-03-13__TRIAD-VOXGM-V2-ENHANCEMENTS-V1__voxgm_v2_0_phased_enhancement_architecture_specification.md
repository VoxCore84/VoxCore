# Review Cycle Summary: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md

**Date**: 2026-03-13T16:45:38.852662

**Rounds completed**: 5

**Final verdict**: FAIL

**Wall time**: 388.8s | **CPU time**: 586.4s (saved 198s via parallelism)


## Round Results

| Round | Reviewer | Model | Time | Verdict | Phase |
|-------|----------|-------|------|---------|-------|
| R1 | Codex | gpt-5.4 | 163.3s | FAIL | Phase 1 |
| R2 | Gemini | gemini-2.5-pro | 62.1s | FAIL | Phase 1 |
| R3 | Claude | claude-sonnet-4-6 | 135.5s | FAIL | Phase 1 |
| R4 | Codex | gpt-5.4 | 165.3s | FAIL | Phase 2 |
| R5 | Gemini | gemini-2.5-pro | 60.2s | FAIL | Phase 3 |

## Per-Round Reviews

### Round 1: Codex (Phase 1)

## Architecture

**[HIGH]** The console integration contract is still internally inconsistent at init time. The spec says `UI.lua` owns the console geometry and must change the content-host anchor chain during `UI:Init()`, but it also keeps `Console:Init()` after `UI:Init()` in `Core.lua`. In the current addon, `PLAYER_LOGIN` initializes `UI` before any new v2 modules at [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L38), and the existing frame/layout is built entirely inside `UI:Init()` at [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L330). As written, `UI:Init()` cannot reliably anchor to a divider/console frame that `Console.lua` has not created yet. This needs an explicit ownership fix: either initialize `Console` before `UI`, or make `UI` create the divider/host and let `Console` only populate it, or require `Console:Init()` to perform the initial re-anchor.

## Verification

**[MEDIUM]** The spec’s v1 inventory is not fully accurate: it says the TOC loads 22 files, but the actual `VoxGM.toc` contains 21 loaded entries, from `Core.lua` through `Modules\Tab_DevTools.lua`, at [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc). This is not implementation-breaking by itself, but it is a repo-verification miss in a document that explicitly claims to be grounded in the current codebase.

**[MEDIUM]** The companion verification section overstates the quality of evidence for some launch keys. `CREATURECODEX` and `VOXSNIFFER` are verified in actual addon source at [CreatureCodex.lua](/C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1032) and [VoxSniffer.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.lua#L217). `VOXPLACER`, however, is only evidenced in a notebook dump at [addon_VoxPlacer.lua.txt](/C:/Users/atayl/VoxCore/doc/notebooklm/addon_VoxPlacer.lua.txt#L853), not in a publishable/source addon tree like the others, and `VOXTIP` is explicitly outside the repo. Because the launch contract depends on exact `SlashCmdList` keys, the spec should distinguish source-verified companions from externally verified or documentation-derived ones instead of presenting them as equivalently verified.

## Design

**[LOW]** The `UI:CreateSlider` change is specified with illustrative code that is not valid Lua as written: `string.format("%.Nf", value)` cannot work without constructing the format string dynamically. Since this section mixes prose with code-like prescriptions, that should be clarified to avoid implementer copy/paste errors. Relevant current slider implementation is at [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68).

## Scope

**[INFO]** Revision 4 does appear to address several issues that earlier review rounds flagged: script sequencing is now correctly owned by `Scripts.lua` instead of `Commands.lua`, the companion data model now includes `slashCmdKey`, console persistence and `PLAYER_LOGOUT` are specified, parser-init ownership is aligned with the real v1 bug in [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332) and [Events.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L8), and the spec now matches the current single-command dispatch boundary in [Commands.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5).

**VERDICT: FAIL**

---

### Round 2: Gemini (Phase 1)

This review covers Revision 4 of the VoxGM v2.0 Phased Enhancement Architecture Specification. This revision is a substantial improvement, addressing a wide range of issues from prior cycles. The specification is now more detailed, robust, and clear on ownership boundaries, particularly regarding script execution, companion addon status, and console persistence. The explicit acknowledgment of API limitations and the detailed handling of edge cases like empty imports and running-script rejection demonstrate a mature design process.

However, a critical process risk remains: the entire specification is contingent on a "Phase 0" API verification spike that has not yet been performed. Additionally, a key fallback mechanism for the settings UI is left undefined.

---

### Correctness

*   **[HIGH]** **Missing Fallback UI Specification:** Section 7.11 states that if the native WoW Settings API is unavailable, `/vgm settings` will open an "in-addon config view". This UI is a critical fallback path but is not specified anywhere in the document. Key configuration options like `console.maxLines`, `scripts.throttleDelay`, and `console.persistHistory` have no other specified UI control outside of this undefined panel. This represents a significant gap in the specification for a core feature.
*   **[MEDIUM]** **Late Verification of External Static Data:** Section 7.9 defers the verification of the `VoxTip` addon's `slashCmdKey` to Phase 5 testing. Discovering incorrect static data this late in the development cycle is a process risk that can lead to last-minute bugs and rework. All external dependencies and data points, including slash command keys for companion addons, should be verified during the Phase 0 API spike.
*   **[LOW]** **Ambiguous Console Buffer Truncation Logic:** Section 7.3 states that when the console buffer exceeds its cap, the oldest entry is removed from the backing Lua table and the `ScrollingMessageFrame`. The mechanism for removing lines from the SMF is ambiguous. `ScrollingMessageFrame:SetMaxLines()` is a blunt instrument that truncates the entire buffer, not a single line. A more likely implementation would involve clearing and repopulating the frame from the truncated Lua table, which has performance implications. The specification should clarify the intended implementation or acknowledge this complexity.
*   **[LOW]** **Confusing Timer Handle Management in Script Runner:** The `Scripts:DispatchNext` logic in section 7.7 specifies clearing `runState.timerHandle` to `nil` in two places: once before creating a new timer, and again inside that new timer's callback. This is redundant. The assignment inside the callback is the correct and sufficient pattern to indicate a timer has fired. The assignment before `C_Timer.NewTimer` is unnecessary and makes the state machine's logic harder to follow.

### Security

*   **[LOW]** **Potential for Sanitizer to Break Non-TC Commands:** Section 8 mandates stripping semicolons from all script lines via `Util:SanitizeText()` to prevent command chaining. While the spec correctly asserts that TrinityCore GM commands do not use semicolons, it also allows script lines to begin with `/`. This creates a potential edge case where a script could legitimately try to run a slash command for another addon that *does* use semicolons as part of its syntax, which would be broken by the sanitizer. While a minor risk given the addon's primary scope, this limitation should be acknowledged.

### Performance

*   **[INFO]** **Console "Copy Line" Overlay Performance:** The specified mechanism for the "Copy Line" feature (Section 4.4) involves creating and managing an overlay of transparent buttons that are rebuilt when the console scrolls. This pattern can cause performance degradation (frame rate drops) during rapid scrolling over a large number of visible lines if not implemented efficiently. The implementer should be advised to use techniques like object pooling/recycling for the overlay buttons to mitigate this risk.

### Process

*   **[CRITICAL]** **Architecture Contingent on Unverified APIs:** The entire specification is built upon a "Phase 0 API Spike" that has not yet been run (Sections 1, 4.8, 11). Core features—including Model Preview, native Settings integration, and Keybindings—are designed with the assumption that specific client APIs (`PlayerModel:SetDisplayInfo`, `Settings.RegisterCanvasLayoutCategory`, etc.) exist and are functional without taint on the target client version. Designing an architecture on unverified core assumptions is a critical process failure. If any of these APIs are unavailable or behave unexpectedly, significant portions of the specification will be invalidated, requiring costly redesign and rework. Phase 0 must be completed before any implementation begins.

---

## VERDICT: FAIL

The specification is detailed and has addressed many previous issues, but it cannot be approved while containing a **CRITICAL** process flaw and a **HIGH** severity feature gap. The dependency on an un-run API spike makes the entire plan unreliable, and the absence of a specified fallback UI for settings leaves a core feature incomplete. These issues must be resolved before the specification can be considered for implementation.

---

### Round 3: Claude (Phase 1)

# Cold-Read Review: TRIAD-VOXGM-V2-ENHANCEMENTS-V4

## Round Summary (vs Prior Rounds)
This is Revision 4, described as addressing all findings from three 5-round review cycles. The revision notes list substantial fixes: Scripts.lua owns sequencing, `slashCmdKey` added to companion data model, "Installed" state uses disabled button, `enabled` clarified as per-script, semicolon audit added, timer handle nil-cleared, model preview invalid-ID behavior honestly stated, `Console:OnMessage` type param removed, companion status in runtime table, conditional modules nil-guarded, Copy Line mechanism specified, `PLAYER_LOGOUT` handler specified, `Scripts:Run` rejects if already running, `StaticPopup` definitions noted, `DispatchNext` ordering clarified, Phase 0 not-yet-run noted, parser init ownership noted, and all prior LOW clarity items resolved. The spec is substantially more complete than earlier revisions.

---

## Category 1: Implementation Bias (Assumptions Builder Took for Granted)

**[HIGH]** — **`DispatchNext` has a logic error in the cancel path.** In `Scripts:Cancel()`, the spec sets `runState.active = false` and then calls `Scripts:CleanupRunState()`. But `CleanupRunState` also sets `runState.active = false` — that's fine. However, the cancel flow calls `CleanupRunState()` which fires `onComplete` callback. The spec does not clarify whether `onComplete` should fire on cancellation vs. natural completion. A caller that passes `onComplete` expecting "script finished successfully" will get it even on cancel. This is an implicit contract that needs explicit documentation: does `onComplete` fire on cancel? If not, `Cancel()` must not call `CleanupRunState()` — it should inline the reset without the callback.

**[HIGH]** — **`Scripts:Cancel()` step ordering is unsafe.** The spec says: (1) set `active = false`, (2) cancel timer, (3) print status, (4) call `CleanupRunState()`. But `CleanupRunState()` resets `runState.index` and `runState.commands` — the status message in step 3 reads `runState.index` and `#runState.commands`. If the spec intends the message to show accurate counts, the status print MUST happen before `CleanupRunState()`, which it does here — but the spec lists `CleanupRunState()` as step 5 after the print. This is actually correct as written, but the spec says "Call `Scripts:CleanupRunState()`" as step 5 while step 4 is the print. A cold implementer counting steps will see steps 1-2-3-4-5 where step 4 is the print and step 5 is cleanup — that's fine. However, the spec says step 4 is "Show status" and step 5 is "Call CleanupRunState()" but the numbered list in Section 7.7 shows them as steps 4 and 5 with no step numbers — just prose bullets. The ordering is ambiguous enough to cause a bug if implemented in the wrong order.

**[MEDIUM]** — **`Console.lineBuffer` ring behavior is underspecified.** The spec says "when it exceeds `VoxGMDB.console.maxLines`, the oldest entry is removed from both the Lua table and the SMF (via `SetMaxLines(cap)`)." But `SetMaxLines()` does not remove a specific oldest entry — it sets the *maximum* the SMF will hold going forward and may discard from the bottom. The spec conflates two different operations: manually removing from `Console.lineBuffer[]` (a Lua table operation) and calling `SetMaxLines()` on the SMF (which is a capacity setter, not a "remove oldest" call). The implementer needs to know: is `lineBuffer` trimmed via `table.remove(lineBuffer, 1)` on each overflow? And is `SetMaxLines()` called once at init (and again when the setting changes), not on every message? As written, a cold implementer might call `SetMaxLines(cap)` on every `OnMessage()` call, which is wasteful and semantically wrong.

**[MEDIUM]** — **Copy Line overlay rebuild trigger is underspecified.** Section 7.3 says "The overlay is rebuilt when the SMF scrolls." But `ScrollingMessageFrame` does not expose a native scroll callback. The spec does not say how the scroll event is detected. Does the implementer use `OnScrollRangeChanged`? A `OnUpdate` poll? A `OnMouseWheel` hook? This is a non-trivial implementation detail that will cause the feature to be built incorrectly or omitted without guidance.

**[MEDIUM]** — **`StaticPopup` `self.data` assignment is not specified.** Section 7.6 defines the popup `OnAccept` as `VoxGM.Scripts:ConfirmDelete(self.data)`. But the spec never shows where `self.data` is set. `StaticPopup_Show` accepts a third argument that becomes `self.data` on the dialog. The spec shows `StaticPopup_Show("VOXGM_SCRIPT_DELETE", scriptName)` — but `scriptName` would be `self.text` (the format arg), not `self.data`. The `data` field requires a fourth argument to `StaticPopup_Show`. A cold implementer will not know this WoW API nuance and will write `ConfirmDelete(nil)`. The spec must show the correct call: `StaticPopup_Show("VOXGM_SCRIPT_DELETE", script.name, nil, scriptIndex)` or equivalent.

**[MEDIUM]** — **`DispatchNext` timer handle nil-clear has a race condition window.** In step 4 of `DispatchNext`, the spec says "Set `runState.timerHandle` to nil (clear previous handle reference)" before scheduling the next timer. This means there is a window between nil-clearing and the new `C_Timer.NewTimer` assignment where `runState.timerHandle` is nil. If `Scripts:Cancel()` is called in this window (theoretically possible in a single-threaded Lua coroutine context during a UI event), the cancel will not cancel the pending timer because `timerHandle` is nil. While Lua is single-threaded and this window is effectively zero in practice, the spec should acknowledge this or restructure to assign the new handle before nil-clearing the old one (which is impossible since they're the same variable). The real fix is: don't nil-clear before scheduling; just overwrite. The spec's current pattern is misleading.

**[MEDIUM]** — **`VoxGM.Data` namespace is never declared.** `Data\CompanionAddons.lua` writes to `VoxGM.Data.CompanionAddons`. But `Core.lua`'s sub-namespace declarations (Section 6) only add `VoxGM.Console`, `VoxGM.Scripts`, `VoxGM.Companions`, `VoxGM.ModelPreview`. There is no `VoxGM.Data = VoxGM.Data or {}` declaration. If `Data\Presets.lua` (v1) already establishes `VoxGM.Data`, this is fine — but the spec never confirms this. A cold implementer adding `Data\CompanionAddons.lua` may get a nil-index error if `VoxGM.Data` doesn't exist yet, depending on TOC load order.

**[LOW]** — **`Scripts:Run` step 3 says "Collect `script.lines` (all lines, since `enabled` is per-script)"** — this is correct but the parenthetical is confusing. It implies there was a per-line enabled concept being ruled out. The comment is defensive documentation of a prior design decision, which is fine, but a cold reader may wonder if there's a per-line filter they're supposed to skip.

---

## Category 2: Consistency Issues

**[HIGH]** — **`PLAYER_LOGOUT` handler registration is inconsistent between Section 6 and Section 7.1.** Section 6 (Core.lua modifications) shows the PLAYER_LOGOUT handler calling `VoxGM.Console:OnLogout()`. Section 7.1 (Addon load) lists the PLAYER_LOGOUT handler as calling `Console:OnLogout()`. These are consistent. However, Section 6 shows the event registered on a `frame` variable — but the spec never clarifies which frame this is. Is it the existing event frame created in `Core.lua` for ADDON_LOADED/PLAYER_LOGIN? The spec says "Register `PLAYER_LOGOUT` event in Core.lua" but doesn't show `frame:RegisterEvent("PLAYER_LOGOUT")` being added to the existing frame's event list. A cold implementer may create a second frame unnecessarily.

**[MEDIUM]** — **`Console:OnMessage` signature inconsistency.** The revision notes say "Console:OnMessage type param removed" — implying a prior version had a type parameter. Section 7.3 shows `Console:OnMessage(msg)` with no type param. Section 4.4 also shows `Console:OnMessage(msg)`. The forwarding call in Section 6 (Events.lua) shows `VoxGM.Console:OnMessage(msg)`. These are all consistent. However, the revision note implies the old signature was `Console:OnMessage(msg, type)` — if any v1 code or test harness calls this with two args, it will silently pass. Not a bug, but worth noting the revision note creates a false concern.

**[MEDIUM]** — **`enabled` field default value is never stated in DEFAULTS.** Section 5 (State.lua DEFAULTS) shows `scripts.items = {}` — an empty array. The `enabled` field is described as part of each script object `{name, description, lines, enabled}`. But the DEFAULTS table doesn't show a template for script items (it can't, since items start empty). The question is: when a user creates a new script via the UI, what is the default value of `enabled`? The spec never states this. A cold implementer might default to `false` (scripts disabled by default) which would be a terrible UX. Should be `true` by default — but this must be stated explicitly.

**[MEDIUM]** — **Import creates scripts with what `enabled` value?** Related to above: Section 7.8 (import) never specifies what `enabled` value imported scripts receive. If the import format has no `# Enabled:` metadata field (it doesn't — only `Name` and `Description` are parsed), then imported scripts need a default. Unspecified.

**[MEDIUM]** — **`Console:Toggle()` persistence behavior is stated in 7.3 but the UI.lua geometry section (Section 6) says "Persists `VoxGMDB.ui.consoleEnabled`" without specifying the key path.** `VoxGMDB.ui.consoleEnabled` is the correct path (it's in DEFAULTS under `ui`). This is consistent. But Section 7.3 says `Console:Toggle()` persists this — meaning `Console.lua` writes to `VoxGMDB.ui.consoleEnabled`. This creates a cross-module write: Console.lua writes to the `ui` sub-table. This is architecturally inconsistent with the pattern where `UI.lua` owns the `ui` sub-table. Should be `UI:SetConsoleEnabled(bool)` called from `Console:Toggle()`, or at minimum the spec should acknowledge this cross-module write.

**[LOW]** — **Section 7.9 says "Loaded" state shows an "Open" button that is enabled, but Section 4.7 says "Installed" state shows a disabled button.** These are consistent. However, "Not Installed" shows "No 'Open' button shown" — meaning the button is absent entirely, not just disabled. The acceptance criteria (Section 10, item 10) says "No button" for Not Installed. All three sources agree. ✓ (No issue — noting for completeness.)

**[LOW]** — **`C.CONSOLE_HISTORY_CAP = 50` is defined in Constants.lua but `VoxGMDB.console.maxLines` defaults to 500.** These are different things (persistence cap vs. display cap) and the spec explains this. But the naming is confusing: `HISTORY_CAP` sounds like it limits history display, not persistence. A cold implementer might conflate the two. Consider `CONSOLE_PERSIST_CAP` as a clearer name — but this is a naming preference, not a bug.

---

## Category 3: Edge Cases & Untested Paths

**[HIGH]** — **`Scripts:DispatchNext()` has no guard against `runState.commands` being mutated during execution.** If a user edits or deletes the currently-running script while it's executing (via the Scripts UI), `runState.commands` is a copy of `script.lines` at run-start (the spec says "Collect `script.lines`" in step 3 of `Scripts:Run`). But the spec says "Collect `script.lines`" — it does NOT say "copy `script.lines`". If `runState.commands` is assigned by reference (`runState.commands = script.lines`), then deleting the script mid-run would corrupt the execution. The spec must explicitly state that `runState.commands` is a **shallow copy** of `script.lines` at run time.

**[HIGH]** — **Console `lineBuffer` and SMF can desync.** The spec says `Console:Clear()` calls `ScrollingMessageFrame:Clear()` and empties `Console.lineBuffer`. But if `SetMaxLines()` is called mid-session (when user changes `console.maxLines`), the SMF may discard messages that are still in `lineBuffer`. The spec acknowledges "SetMaxLines() may discard messages exceeding the new cap" but doesn't say `lineBuffer` should be trimmed to match. After a `SetMaxLines()` reduction, `lineBuffer` has more entries than the SMF displays — Copy Line overlay will be misaligned.

**[MEDIUM]** — **`Scripts:Run` rejects if already running — but what about the UI?** The spec says the "Stop" button is visible while `runState.active == true`. But if a user closes and reopens the Scripts UI panel while a script is running, does the new panel instance show the Stop button? The spec doesn't address UI state reconstruction for the Scripts panel when opened mid-run.

**[MEDIUM]** — **`Console:OnLogout()` persistence cap is 50 (`C.CONSOLE_HISTORY_CAP`) but `lineBuffer` may have up to 2000 entries.** The spec says "saves the most recent `C.CONSOLE_HISTORY_CAP` (50) entries." This means on logout, 1950+ messages are silently discarded. This is a design choice, but the spec never tells the user this will happen. The Settings panel description (Section 7.11) mentions "console max lines" but not the persistence cap. A user who enables persistence expecting all 500 buffered messages to survive a relog will be surprised. This should be surfaced in the UI.

**[MEDIUM]** — **`Util:SanitizeText()` strips semicolons — but the spec says this is safe because TC commands don't use semicolons.** This is stated in Section 3 and Section 8. However, the spec never addresses what happens if a user tries to import a script that contains a line like `.npc add 1234; .npc add 5678` (a user-authored chaining attempt). The sanitizer will strip the semicolon and produce `.npc add 1234 .npc add 5678` — a malformed command that will silently fail or produce unexpected behavior. The spec should state that post-sanitization validation (must start with `.` or `/`) will catch this, since `.npc add 1234 .npc add 5678` still starts with `.` and would pass validation. This is a silent corruption, not a rejection.

**[MEDIUM]** — **`ModelPreview:Show(nil)` behavior when called from `/vgm preview` with no argument.** The spec says "nil id = show panel with empty input field." But `/vgm preview` passes `tonumber(rest)` where `rest` is `""` — `tonumber("")` returns `nil`. So `ModelPreview:Show(nil)` is called. This is correct per spec. But if the user types `/vgm preview abc`, `tonumber("abc")` also returns `nil`, and the panel opens with an empty field — silently ignoring the invalid input. The spec should state this is intentional (or add a "invalid ID" message for non-empty, non-numeric input).

**[MEDIUM]** — **`State:Migrate()` prunes scripts to `C.SCRIPT_MAX_SAVED` (50) but the write-time cap is also 50.** If a user somehow has 51 scripts (e.g., from a future version that raised the cap), migration silently drops the 51st. This is the correct behavior and matches the existing History/Favorites pattern. However, the spec never says whether pruning is FIFO (drop the last) or LIFO (drop the first). The pruning loop uses `if #cleanScripts >= C.SCRIPT_MAX_SAVED then break end` — this keeps the FIRST 50 and drops the rest. This is consistent with the loop structure but should be stated as "oldest scripts preserved, newest dropped on overflow" — which is counterintuitive. Most users expect the newest to be kept.

**[LOW]** — **`Scripts:CleanupRunState()` fires `onComplete` even when `runState.commands` was empty (zero-line script).** But the spec says zero-line scripts return early before setting `runState.active = true` — so `CleanupRunState()` is never called for zero-line scripts. ✓ (No issue — edge case is handled.)

**[LOW]** — **`Console:OnMessage` is called from `Events:OnSystemMessage` which runs on every `CHAT_MSG_SYSTEM` event.** If the console is hidden (`consoleEnabled = false`), messages still accumulate in `lineBuffer`. This is correct behavior (buffer fills regardless of visibility) but the spec doesn't explicitly state it. A cold implementer might add an early return if the console is hidden.

---

## Category 4: Clarity & Documentation

**[HIGH]** — **The spec never defines what `Scripts:ConfirmDelete(index)` and `Scripts:ConfirmOverwrite(data)` receive as arguments.** Section 7.6 shows `OnAccept = function(self) VoxGM.Scripts:ConfirmDelete(self.data) end`. But what is `self.data`? Is it a script name (string), an index (number), or the script object (table)? The spec shows `StaticPopup_Show("VOXGM_SCRIPT_OVERWRITE", existingName)` with `popup.data = importedScript` — so for overwrite, `self.data` is the imported script object. For delete, the spec shows `StaticPopup_Show("VOXGM_SCRIPT_DELETE", ...)` but never shows the call site or what `data` is set to. A cold implementer cannot implement `ConfirmDelete` without knowing whether to delete by name, index, or reference.

**[MEDIUM]** — **Section 7.7 `DispatchNext` step 4 says "Set `runState.timerHandle` to nil (clear previous handle reference)"** — but on the first call to `DispatchNext`, `timerHandle` is already nil (set in `Scripts:Run` step 4). Nil-clearing nil is harmless but the comment "clear previous handle reference" implies there IS a previous handle, which is false on the first dispatch. This will confuse an implementer trying to understand the invariant.

**[MEDIUM]** — **The spec says `Events:RegisterDefaultParsers()` must be moved from `UI:Init()` to `Events:Init()` (v1 bug fix).** But the spec never shows what `Events:RegisterDefaultParsers()` does or what parsers it registers. A cold implementer extending Events.lua needs to know: is this a method that already exists in v1 Events.lua? The spec says "v1 bug, v2 fix" implying it exists — but the v1 codebase inventory (Section 3) describes Events.lua as "RegisterParser pattern system, CHAT_MSG_SYSTEM handler, state sync parsers" without mentioning `RegisterDefaultParsers` by name. A cold implementer may not find this method.

**[MEDIUM]** — **Section 6 (UI.lua console geometry) describes the anchor chain change but uses the term "content host"** without defining it. What is the "content host"? Is it a named frame in v1 UI.lua? The spec says "Content host bottom anchor changes from status bar to a divider frame" — a cold implementer needs to know the variable name of this frame in the existing UI.lua code. Without it, they must grep the ~600-line UI.lua to find the right frame.

**[MEDIUM]** — **The `slashCmdKey` field is described as "the exact key needed" for `SlashCmdList[key]`** — but the spec never explains the relationship between slash command registration and `SlashCmdList` keys. In WoW, `SLASH_CREATURECODEX1 = "/cc"` registers a slash command with key `CREATURECODEX`. A cold implementer unfamiliar with WoW addon slash registration may not understand why `SlashCmdList["CREATURECODEX"]` works when the addon registered `/cc`. The spec should add one sentence explaining this WoW API convention.

**[LOW]** — **Section 11 Phase 1 says "Rewrite Core.lua slash handler (full replacement, not additive branches)"** — but Section 6 shows the new slash handler as a complete replacement. These are consistent. However, "full replacement" conflicts with Section 4.2 which says "Extend existing files, do not replace." The slash handler is being replaced within Core.lua (not the file itself), but the wording creates a surface-level contradiction.

**[LOW]** — **Section 7.8 import parsing rule 2 says "Parse `# Key: Value` by splitting on the FIRST `: ` only"** — the example `# Name: Setup: Scene 1` yields `Setup: Scene 1`. This is correct. But the spec never says what happens to unrecognized `# Key: Value` lines (e.g., `# Author: Bob`). Are they silently ignored? This should be stated explicitly.

**[LOW]** — **Section 7.9 says "CreatureCodex, VoxSniffer, and VoxPlacer slash registrations are verified in the VoxCore repo"** but doesn't say WHERE in the repo. A cold implementer doing Phase 5 verification needs to know which files to check.

**[LOW]** — **The spec mentions `VoxGM.Util:DeepCopy(v)` in the per-key backfill loops (Section 6, State.lua)** but the existing codebase inventory (Section 3) lists `DeepCopy` as `Util.lua` — `Util:DeepCopy`. The spec uses both `VoxGM.Util:DeepCopy(v)` (in backfill loops) and `DeepCopy(DEFAULTS.console)` (in type guards). The type guards use a bare `DeepCopy` call — is this a module-local alias or the global? The v1 State.lua presumably has a local alias since it uses `DeepCopy` directly. This inconsistency in call style within the same section will confuse the implementer.

---

## VERDICT: FAIL

**Critical/High issues found:** 5 HIGH severity findings.

**Summary of key failures:**
1. `onComplete` callback fires on cancellation — contract undefined (HIGH)
2. `Scripts:Cancel()` step ordering ambiguity for status message vs. cleanup (HIGH)
3. `StaticPopup` `self.data` assignment mechanism not specified — `ConfirmDelete` receives unknown argument (HIGH)
4. `runState.commands` not specified as a copy — mid-run script mutation can corrupt execution (HIGH)
5. Console `lineBuffer` / SMF desync after `SetMaxLines()` reduction (HIGH)

The spec is substantially improved from prior rounds and handles most edge cases well. The remaining HIGH issues are concentrated in the Scripts execution engine and StaticPopup integration — areas where WoW API nuance intersects with the spec's implementation guidance. These must be resolved before Phase 4 implementation begins.

---

### Round 4: Codex (Phase 2)

**Architecture**

- **[HIGH]** — The console/UI ownership contract is still unresolved. The spec says `UI.lua` owns the console geometry and initial anchor chain, but the real addon still builds the main frame and `contentHost` during `UI:Init()` at [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332) and anchors it directly to the status bar at [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L393). The current login order runs `VoxGM.UI:Init()` before any new v2 modules at [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L39). As written, `UI:Init()` still cannot reliably anchor against a divider/console frame that `Console.lua` has not created yet. This needs an explicit ownership fix in the spec: either `Console` initializes before `UI`, or `UI` creates the divider/host itself and `Console` only populates it, or `Console:Init()` owns the initial re-anchor.

**Design**

- **[HIGH]** — The fallback `/vgm settings` path is still underspecified. The artifact says that if `Settings.RegisterCanvasLayoutCategory` is unavailable, `/vgm settings` opens an “in-addon config view,” but it never defines that view’s module, placement, controls, or persistence flow. This is not a cosmetic omission: settings like `console.maxLines`, `scripts.throttleDelay`, and `console.persistHistory` otherwise have no concrete UI contract. The current addon only has the main panel and slash handler in [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332) and [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L52); there is no existing config surface to extend by implication.

- **[LOW]** — The slider pseudocode is still not valid Lua as written. The spec’s `string.format("%.Nf", value)` example cannot work literally; the current slider implementation in [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68) is integer-only, so this section should show dynamic format construction or stay prose-only to avoid copy/paste implementation errors.

**Verification**

- **[MEDIUM]** — The inventory claim remains wrong. The artifact says the TOC loads 22 files “from `VoxGM.toc`,” but the actual TOC lists 21 loaded entries at [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc#L12). The repo README repeats the same incorrect count at [README.md](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/README.md#L149), but that does not make the spec’s “from TOC” claim correct.

- **[MEDIUM]** — The companion verification evidence is still presented too uniformly for what the repo actually proves. `CREATURECODEX` and `VOXSNIFFER` are source-verified in real addon code at [CreatureCodex.lua](/C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1032) and [VoxSniffer.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.lua#L217). `VOXPLACER`, however, is only evidenced in a notebook export at [addon_VoxPlacer.lua.txt](/C:/Users/atayl/VoxCore/doc/notebooklm/addon_VoxPlacer.lua.txt#L853), not in a publishable/source addon tree, and `VOXTIP` is explicitly outside the workspace. For a launch contract that depends on exact `SlashCmdList` keys, the spec should distinguish source-verified, documentation-derived, and externally verified companions.

**Integration**

- **[INFO]** — Several earlier contract issues do appear fixed against the real repo. The spec now matches the current single-command boundary in [Commands.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5), correctly recognizes that `VoxGM.Data` already exists in [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L14), and accurately identifies the parser-registration bug caused by `UI:Init()` calling `RegisterDefaultParsers()` at [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332) instead of `Events:Init()` at [Events.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L8).

**Summary Since Prior Rounds**

Revision 4 is materially better than earlier drafts: it now aligns with the real `Commands.lua` dispatch boundary, fixes the prior confusion around script sequencing ownership, acknowledges the actual parser-init bug in the current addon, keeps `VoxGM.Data` compatible with the existing namespace layout, and improves several data-model details around companions and scripts. The remaining blockers are narrower but still approval-blocking: one unresolved init-order/ownership bug for the console layout, one still-undefined settings fallback path, and two repo-verification inaccuracies around file inventory and companion evidence quality.

**VERDICT: FAIL**

---

### Round 5: Gemini (Phase 3)

This review assesses Revision 4 of the VoxGM v2.0 Phased Enhancement Architecture Specification. The revision notes claim to address all findings from 15 prior review rounds, including major architectural shifts like making `Scripts.lua` the sole owner of command sequencing, adding the `slashCmdKey` to the companion data model, specifying the console's copy mechanism and logout persistence, and fixing the v1 parser initialization bug. However, a detailed audit reveals that numerous critical and high-severity issues flagged in the previous review cycle persist in this revision, including a dependency on an un-run API verification spike, an unresolved UI initialization race condition, an underspecified settings fallback UI, and multiple logic errors in the script execution and cancellation flow.

### Process

*   **[CRITICAL]** — **Architecture Contingent on Unverified APIs:** The entire specification for key features (Model Preview, Native Settings, Keybindings) is conditional on a "Phase 0 API Spike" which is explicitly stated as not having been run. Building a detailed architecture on unverified, fundamental assumptions about the target client's API availability and behavior is a critical process failure. If any of these APIs are unavailable or tainted, large sections of the design are invalidated, guaranteeing significant rework. Phase 0 must be completed *before* the architecture is specified and reviewed, not after.

### Correctness

*   **[CRITICAL]** — **Console/UI Initialization Race Condition:** The addon initialization order specified in Section 7.1 calls `UI:Init()` before `Console:Init()`. However, Section 6 requires `UI:Init()` to alter its layout based on `VoxGMDB.ui.consoleEnabled`, anchoring to a divider frame that is created by `Console.lua`. At the time `UI:Init()` runs, the console's frames do not exist, making the specified layout logic impossible to implement as written. This fundamental dependency inversion will cause Lua errors or incorrect UI layout on login.
*   **[HIGH]** — **Missing Fallback UI Specification for Settings:** Section 7.11 specifies a critical fallback path: if the native WoW Settings API is unavailable, `/vgm settings` should open an "in-addon config view". This view is the only specified UI for configuring core features like console buffer size and script throttle delay. However, the specification provides zero details on the design, implementation, or location of this essential fallback UI, leaving a major feature gap.
*   **[HIGH]** — **Script Execution State is Corruptible by Mid-run Edits:** Section 7.7 states that `Scripts:Run` will "Collect `script.lines`". It does not mandate that a *copy* of the lines be made. If `runState.commands` is assigned by reference to the script's data in `VoxGMDB`, any user action that modifies or deletes the script while it is running (e.g., via the UI) will mutate the `runState.commands` table, leading to unpredictable behavior, errors, or premature termination of the script. The spec must require a shallow copy of the command list at the start of execution.
*   **[HIGH]** — **Console Buffer and UI Desynchronization:** Section 7.3 specifies that changing `console.maxLines` will call `ScrollingMessageFrame:SetMaxLines()`, which may discard lines from the UI. However, it fails to specify that the backing Lua table, `Console.lineBuffer`, must also be trimmed to match. This desynchronization will break the "Copy Line" feature, as the overlay buttons will be mapped to a `lineBuffer` index that no longer corresponds to the visible line in the UI.
*   **[HIGH]** — **Ambiguous `onComplete` Callback Contract for Script Cancellation:** Section 7.7 specifies that `Scripts:Cancel()` calls `Scripts:CleanupRunState()`, which in turn executes the `onComplete` callback. This means the callback fires for both successful completion and cancellation. This is a highly ambiguous contract that will lead to bugs, as a caller cannot distinguish between a finished script and a cancelled one. The spec must define whether `onComplete` should fire on cancellation.
*   **[HIGH]** — **Undefined Function Arguments for Script Deletion:** Section 7.6 defines the `OnAccept` handler for the delete confirmation popup as `VoxGM.Scripts:ConfirmDelete(self.data)`. However, the specification never shows the call site (`StaticPopup_Show`) for the delete action, nor does it define what `self.data` will contain (e.g., script index, script name, or script object). This makes the `ConfirmDelete` function impossible to implement correctly without guessing its inputs.
*   **[MEDIUM]** — **Cross-Module State Mutation:** Section 7.3 states that `Console:Toggle()` persists the enabled state to `VoxGMDB.ui.consoleEnabled`. This constitutes a direct write from the `Console` module into the `ui` sub-table of the database, which should be owned by the `UI` module. This breaks encapsulation and creates an undesirable architectural coupling. The `Console` module should call a method on the `UI` module (e.g., `UI:SetConsoleVisible(state)`) to manage this state.
*   **[MEDIUM]** — **Script Pruning Logic is Counter-Intuitive:** The script pruning logic described in `State:Migrate()` (Section 6) keeps the first `C.SCRIPT_MAX_SAVED` scripts and discards any subsequent ones. In practice, this means the oldest scripts are preserved and the newest ones are dropped during a migration overflow. This is the opposite of user expectation and should be explicitly documented or reversed to keep the newest entries.
*   **[MEDIUM]** — **Underspecified "Copy Line" Overlay Trigger:** Section 7.3 states the "Copy Line" button overlay is rebuilt "when the SMF scrolls," but `ScrollingMessageFrame` has no native `OnScroll` event. The spec fails to provide any guidance on how to detect this, leaving a critical and non-trivial implementation detail (e.g., polling via `OnUpdate`, hooking `OnMouseWheel`) entirely to the implementer.
*   **[MEDIUM]** — **Default `enabled` State for New/Imported Scripts is Undefined:** Sections 7.6 and 7.8 describe the creation and import of scripts, which include an `enabled` boolean field. However, the spec never states what the default value for this field should be. This is a poor user experience waiting to happen, as an implementer might default it to `false`, requiring users to manually enable every script they create or import.
*   **[LOW]** — **Redundant Timer Handle Management:** The `Scripts:DispatchNext` logic in Section 7.7 specifies clearing `runState.timerHandle` to `nil` twice: once before creating a new timer, and again inside that new timer's callback. The second one is correct and sufficient. The first one is redundant and confusing.
*   **[LOW]** — **Invalid Lua Pseudocode for Slider Widget:** Section 6 (UI.lua) specifies an extension to `UI:CreateSlider` using the example `string.format("%.Nf", value)`. `N` is not a valid format specifier; this is not valid Lua and will cause an error if implemented literally. The spec should describe the logic in prose or provide correct example code, such as `string.format("%." .. decimals .. "f", value)`.
*   **[LOW]** — **Inaccurate TOC File Count:** Section 3 claims the v1 TOC loads 22 files. Prior review indicates the actual count is 21. While minor, this factual inaccuracy in the codebase inventory undermines confidence in the specification's grounding in the existing reality.

### Security

*   **[MEDIUM]** — **Sanitizer Can Corrupt and Pass Malformed Commands:** Section 8 mandates stripping semicolons to prevent command chaining. However, a user-authored line like `.npc add 1234; .npc add 5678` would be sanitized to `.npc add 1234 .npc add 5678`. This is a malformed command that would still pass the spec's validation (starts with `.`) and be sent to the server, where it would likely fail silently or cause unexpected behavior. The sanitizer is creating a new failure mode instead of rejecting the invalid input.

### Style / Clarity

*   **[MEDIUM]** — **Ambiguous Console Buffer Management Logic:** Section 7.3 states that when the line buffer exceeds its cap, the oldest entry is removed from the Lua table and the SMF "via `SetMaxLines(cap)`". This is misleading. `SetMaxLines` is a capacity setter, not a "remove oldest line" function. The spec should clearly state the intended logic: e.g., `table.remove(lineBuffer, 1)` to trim the backing table, followed by clearing and repopulating the SMF widget to reflect the change.
*   **[LOW]** — **Late Verification of Static Data:** Section 7.9 defers verification of the `VoxTip` `slashCmdKey` to Phase 5 testing. This is a process smell. All static data and external contracts should be verified as early as possible (ideally in Phase 0) to minimize the risk of late-cycle rework.
*   **[LOW]** — **Unacknowledged Edge Case for Slash Commands with Semicolons:** Section 8's mandatory semicolon stripping could break legitimate slash commands from other addons that use semicolons in their arguments. While the primary use case is TC GM commands, the spec explicitly allows `/` commands. This limitation should be acknowledged.

---

### VERDICT: FAIL

The specification contains one CRITICAL process issue and five HIGH severity correctness bugs. The architecture is fundamentally unsound due to its reliance on unverified APIs and contains a critical race condition in its UI initialization logic. Furthermore, multiple core features like script execution, cancellation, and the output console have logic flaws that will lead to data corruption, desynchronization, or contract violations. This revision cannot be approved for implementation.

---

---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 3
reviewer: Claude
model: claude-sonnet-4-6
date: 2026-03-13T16:41:25.489827
elapsed_seconds: 135.5
---

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
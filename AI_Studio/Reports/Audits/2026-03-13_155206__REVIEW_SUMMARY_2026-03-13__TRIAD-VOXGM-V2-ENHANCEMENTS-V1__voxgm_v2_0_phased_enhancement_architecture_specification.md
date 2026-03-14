# Review Cycle Summary: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md

**Date**: 2026-03-13T15:52:06.024021

**Rounds completed**: 5

**Final verdict**: FAIL

**Wall time**: 445.6s | **CPU time**: 577.0s (saved 131s via parallelism)


## Round Results

| Round | Reviewer | Model | Time | Verdict | Phase |
|-------|----------|-------|------|---------|-------|
| R1 | Codex | gpt-5.4 | 208.9s | FAIL | Phase 1 |
| R2 | Gemini | gemini-2.5-pro | 40.8s | FAIL | Phase 1 |
| R3 | Claude | claude-sonnet-4-6 | 90.7s | FAIL | Phase 1 |
| R4 | Codex | gpt-5.4 | 194.8s | FAIL | Phase 2 |
| R5 | Gemini | gemini-2.5-pro | 41.9s | FAIL | Phase 3 |

## Per-Round Reviews

### Round 1: Codex (Phase 1)

**Architecture**

**[HIGH]** — The companion-addon launch contract is not implementable as specified. A metadata record of `{ addonName, slashCmd }` is not enough to “open” another addon in WoW; slash text is not a generic callable API. The actual companion addons expose distinct slash-handler registrations such as [`VoxSniffer.lua`](C:/Users/atayl/VoxCore/addons/VoxSniffer/VoxSniffer.lua#L217), [`VoxPlacer.lua`](C:/Users/atayl/VoxCore/addons/VoxPlacer/VoxPlacer.lua#L853), and [`VoxCoreProfessions.lua`](C:/Users/atayl/VoxCore/addons/VoxCoreProfessions/VoxCoreProfessions.lua#L429). The spec needs an explicit per-addon launch contract, such as a known `SlashCmdList` key or exported global toggle function.

**[MEDIUM]** — The console design claims it can “reuse the existing `Events:RegisterParser` model” for filtered display, but the current parser API does not expose match metadata or classification. [`Events.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L25) only stores `{pattern, callback}`, and [`OnSystemMessage`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L29) just invokes callbacks. A console cannot know which parser matched, whether the message is interesting, or how to label it without introducing a new parser contract or duplicating regexes.

**Integration**

**[MEDIUM]** — The slash-command extension plan understates the amount of core parsing work required. The current handler in [`Core.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L49) lowercases the entire message and only branches on exact `reset` and `minimap`; everything else toggles the window. Supporting `/vgm scale 1.2`, `/vgm opacity 0.7`, `/vgm preview 123`, or `/vgm scripts` requires a real tokenizer/dispatcher, not a simple additive branch.

**[MEDIUM]** — “Mount the Console pane below the tab content area” is not just an additive insert into the current UI. [`UI.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L392) anchors one content host directly down to the status bar, and [`CreateTabContainers`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L471) builds every tab scroll frame to fill that host. Adding a collapsible lower pane means redefining frame geometry and scroll extents, not merely creating `Console.lua`.

**Verification**

**[LOW]** — The inventory claims are mostly accurate after reading the repo. The addon lives under [`tools/publishable/VoxGM/VoxGM.toc`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc), not the repo root; there are 25 files in that addon folder, 22 are loaded by the TOC, and there are currently no XML files.

**[LOW]** — The module-pattern statement is slightly overstated. Most files do use `local _, VoxGM = ...`, but [`Core.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L1) uses `local ADDON_NAME, VoxGM = ...`. That is minor, but the spec should describe the pattern as “namespace via addon varargs” rather than a single exact header.

**Design**

**[HIGH]** — The script runner design is internally contradictory: it mandates `C_Timer.After` sequencing and also promises mid-run cancellation via a “Stop” button. The existing staggered pattern in [`Tab_Appearance.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L136) uses fire-and-forget `C_Timer.After`, which does not give you handles to cancel. If cancellation is a requirement, the architecture needs cancellable timers or a token/queue worker model.

**[MEDIUM]** — The spec’s semicolon validation is ineffective as written. [`Util:SanitizeText`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Util.lua) already strips `;`, so a rule like “sanitize, then reject lines containing `;`” cannot catch anything. If the goal is to reject suspicious raw input instead of silently rewriting it, the check must happen before sanitization or compare raw vs sanitized values.

**[MEDIUM]** — State ownership for script throttle is inconsistent. Section 6 proposes new `ui`, `console`, `scripts`, and `companions` defaults, but Section 7 says throttle is stored in `VoxGMDB.console.scriptThrottle` even though that key is not defined in the proposed defaults. The current persisted schema in [`State.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua#L7) is very simple; this spec needs one clear home for throttle and one migration path.

**Scope**

**[INFO]** — The revised spec is better grounded than a greenfield rewrite: it correctly preserves the flat TOC-driven layout, the existing tab registration model in [`Constants.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Constants.lua) and [`UI.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L471), the single-command dispatch path in [`Commands.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5), and the current SavedVariables name in [`VoxGM.toc`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc#L6).

No prior implementation rounds exist in this review context, so there is no code delta to compare against prior fixes. Relative to earlier, text-only architecture drafts, this revision is materially more grounded in the actual v1 addon layout and existing seams, but it still overstates how additive several v2 features are: companion launching, parser-backed console filtering, and cancellable scripted execution all require new contracts rather than straightforward file additions.

**VERDICT:** FAIL

---

### Round 2: Gemini (Phase 1)

This review covers the second revision of the VoxGM v2.0 Phased Enhancement Architecture Specification. This revision is a significant rewrite of the original, grounded in the v1 source code and designed to address 34 findings from the previous 5-round review cycle. The core architectural decision to extend the existing flat-file structure rather than perform a major refactor has been maintained, focusing on additive, backwards-compatible enhancements.

---

### Correctness & Logic

*   **[HIGH]** — Script Cancellation Mechanism is Undefined and Likely Unworkable. Section 7.7 states that script execution can be cancelled via a "Stop" button. However, the proposed implementation using a loop of `C_Timer.After` calls does not support cancellation. Each `C_Timer.After` call schedules an independent, fire-and-forget timer. To enable cancellation, the system would need to manage a single, recursive timer or a table of timer handles created by `C_Timer.NewTimer`, which could then be cancelled. The current specification describes a system that, once started, cannot be stopped.
*   **[MEDIUM]** — Incomplete Migration Logic for Nested Keys. Section 6 describes the `State:Migrate()` function. It correctly specifies adding new top-level tables (`console`, `scripts`) if they are missing. However, for nested keys like `db.ui.scale` and `db.ui.opacity`, it only mentions a type guard. It does not explicitly state that these keys should be added from `DEFAULTS` if they are `nil`. A v1 user's `db.ui` table will not have these keys, leading to `nil` values and potential errors in `UI:SetScale` and `UI:SetOpacity` unless they are backfilled. The migration must handle both incorrect types and missing keys within existing tables.
*   **[MEDIUM]** — Console Response Grouping Heuristic is Flawed. Section 4.4 describes a "best-effort time-window heuristic" that groups messages within 2 seconds of a dispatched command. When running a script with the default 0.3s throttle, the 2-second window from the first command will incorrectly capture responses from the next 5-6 commands in the sequence, rendering the grouping feature useless and confusing for its primary use case (scripted sequences). A more robust correlation mechanism is needed, perhaps by emitting a unique, silent marker to the chat log before each command.
*   **[MEDIUM]** — Companion Addon Detection Logic is Incomplete. Section 7.9 specifies using `IsAddOnLoaded` (or its `C_AddOns` equivalent) to determine addon status. This API only checks if an addon is currently loaded and running. It cannot distinguish between an addon that is not installed and one that is installed but disabled or not yet loaded. The described statuses ("Loaded", "Installed", "Not Installed") cannot be fully implemented with this check alone. To correctly determine "Installed", the implementation must iterate the list of addons from `GetAddOnInfo` or `C_AddOns.GetAddOnInfo`.
*   **[LOW]** — Ambiguity in Script Deletion from Array. Section 7.6 mentions script deletion. Since scripts are stored in an array (`VoxGMDB.scripts`), deleting an element from the middle without using `table.remove` will create a `nil` hole, breaking any subsequent iteration that uses `ipairs` or a numeric for loop. The specification should mandate the use of `table.remove` to ensure data integrity of the script array.
*   **[LOW]** — Contradictory Script Sanitization Logic Description. Section 8.3 states that imported lines are rejected if they contain a semicolon *after* sanitization. However, Section 8.1 states that `Util:SanitizeText()` *strips* semicolons. A string cannot contain a character that has already been stripped from it. This logic is redundant and confusing. The check should likely be simplified to "sanitize the line, then drop it if it becomes empty."

### Security

*   **[CRITICAL]** — Incomplete Sanitization May Allow Command Injection via Newline Characters. The specified sanitizer `Util:SanitizeText()` strips control characters (`%c`), pipes (`|`), and semicolons (`;`). It does not, however, address newline characters (`\n`). An attacker could craft a script line like `.say Hello\n.gm off`. When this line is passed to `Cmd:SendCommand()`, `ChatEdit_SendText` may interpret the newline as a command submission, executing `.say Hello` and then immediately executing `.gm off`, bypassing the mandatory script throttling between commands. This could be used to execute privileged commands or spam the server. The sanitizer MUST also strip or replace newline characters (`\n` and `\r`).
*   **[HIGH]** — Unspecified Sanitization for Imported Script Metadata. Section 7.8 describes an import format with metadata lines like `# Name: My Script`. The specification does not state whether the values extracted from these lines (e.g., "My Script") are sanitized before being stored and displayed in the UI. Failure to sanitize this user-provided text could lead to UI injection attacks, where malicious strings (e.g., texture paths `|T...|t`, color codes `|c...|r`, or other UI escape sequences) could corrupt the addon's display or create deceptive UI elements. All imported metadata values MUST be sanitized before use.

### Performance

*   **[LOW]** — Potential for SavedVariables Bloat with Persisted Console History. Section 6 introduces `console.persistHistory` and `console.persistedLines`. While capped at 500 lines, this feature could add a significant amount of text data to the `VoxGMDB` SavedVariables file, potentially increasing login and logout times for users who enable it. This is an acceptable trade-off for the feature, but the performance implication should be noted, and the cap should be strictly enforced.

### Style & Architecture

*   **[INFO]** — UI Mechanism for Console Collapse/Expand is Undefined. Section 7.3 mentions the console is a "collapsible lower pane". The specification does not detail the UI control (e.g., a button, a draggable sash) that will be used to manage this state, nor how the collapsed/expanded state will be persisted. This detail should be clarified for the implementer.
*   **[INFO]** — Console Filtering Occurs After Message Forwarding. As per Section 6, `Events.lua` forwards all system messages to the console, which then performs its own filtering. This is a clean, decoupled design. However, for extremely spammy server events, this adds an extra function call for every single message. While likely not a significant performance issue, it's a design choice with minor overhead compared to having the console register its own filtered event handler. The current design is acceptable for its clarity.

---

### VERDICT: FAIL

This specification is a marked improvement and demonstrates strong architectural thinking, particularly with the Phase 0 API spike and the strict security constraints on script execution. However, the presence of a **CRITICAL** command injection vulnerability via unsanitized newlines and two **HIGH** severity issues (unworkable script cancellation and potential UI injection from script metadata) requires a revision before implementation can begin. The correctness issues regarding migration, console grouping, and companion detection must also be addressed.

---

### Round 3: Claude (Phase 1)

# Cold-Read Review: TRIAD-VOXGM-V2-ENHANCEMENTS-V2 (Round 3)

---

## Summary of Changes Since Prior Rounds

This is Revision 2 of the spec, described as a "complete rewrite grounded in v1 source" that addresses 34 findings from 5 prior review rounds. The spec is notably more grounded than a typical v1 architecture doc: it references specific existing file names, function signatures, existing patterns (staggered commands, module pattern, `Cmd:SendCommand`), and explicit API uncertainty via Phase 0 gating. The revision adds concrete caps, type guard patterns, security constraints, and a competitive positioning table. It reads as a mature spec that has been through significant iteration.

---

## Findings

### Implementation Bias

**[HIGH]** — **`scriptThrottle` stored under wrong key in spec.** Section 7 (item 7) states the script throttle delay is stored in `VoxGMDB.console.scriptThrottle`, but the `DEFAULTS` table in Section 6 (State.lua) defines no `scriptThrottle` key under `console` — only `maxLines`, `showTimestamps`, `persistHistory`, and `persistedLines`. The implementer will either silently store it in an undeclared key or invent a location. This is a data model inconsistency that will cause a migration gap.

**[HIGH]** — **`Cmd:SendSequence()` cancellation mechanism is unspecified.** Section 7 (item 7) says execution "can be cancelled mid-sequence via a 'Stop' button," and Section 10 AC #8 implies this is required behavior. However, `Commands.lua` modifications in Section 6 define `Cmd:SendSequence()` only as iterating commands with `C_Timer.After` staggering. There is no specification of how cancellation works: no cancel flag, no timer handle storage, no `Scripts:Cancel()` method, no state variable. `C_Timer.After` callbacks cannot be cancelled once scheduled without storing the handle. The implementer must invent this entire mechanism from scratch with no guidance.

**[MEDIUM]** — **Console "pattern-filtered display" vs. "all messages mode" is underspecified.** Section 7 (item 3) says the console displays "only messages matching registered patterns plus a toggleable 'all messages' mode." Section 4.4 says it listens to `CHAT_MSG_SYSTEM`. But `Events.lua` only handles `CHAT_MSG_SYSTEM`. If a GM command response comes back as `CHAT_MSG_ADDON`, `CHAT_MSG_WHISPER`, or another event type, the console will silently miss it. The spec never enumerates which WoW event types the console should listen to beyond `CHAT_MSG_SYSTEM`.

**[MEDIUM]** — **`Console:OnMessage()` initialization guard is unspecified.** Section 6 (Events.lua) says to forward messages to `VoxGM.Console:OnMessage(msg, "system")` "if Console is initialized." The spec does not define what "initialized" means as a testable condition — no flag name, no nil check pattern, no guard example. The implementer must invent this, and if they get it wrong (e.g., checking the wrong thing), messages during early load will either error or be silently dropped.

**[MEDIUM]** — **`Cmd:SendCommandThrottled` is defined but never referenced again.** Section 6 (Commands.lua) adds `Cmd:SendCommandThrottled(cmdStr, source, delay)` as a wrapper. Section 7 and Section 8 only reference `Cmd:SendSequence()` for script execution. No other part of the spec calls `SendCommandThrottled` directly. It's unclear whether this is a building block for `SendSequence` (not stated) or a dead API surface. An implementer may skip it or implement it inconsistently.

**[MEDIUM]** — **Model preview accessibility from `Tab_CNPC.lua` is dropped without explanation.** Section 7 (item 5) says the preview panel can be opened from "AppearanceTab (.wmorph field) and CustomNPCTab (display ID field)." But Section 10 AC #7 only mentions "AppearanceTab (.wmorph field) and standalone via `/vgm preview`" — CustomNPCTab is absent from the acceptance criteria. The implementer has conflicting guidance on whether CNPC tab integration is required.

**[LOW]** — **`C.CONSOLE_HISTORY_CAP = 50` constant is defined but never used.** Section 6 (Constants.lua) adds `C.CONSOLE_HISTORY_CAP = 50`. No part of the spec references this constant in any logic, data model, or behavior description. `C.CONSOLE_MAX_LINES = 500` is the cap used throughout. Either this constant is vestigial or it was intended for a "persisted history" cap that was never wired up.

---

### Consistency

**[HIGH]** — **Console buffer cap is inconsistent across sections.** Section 6 (Constants.lua) defines `C.CONSOLE_MAX_LINES = 500`. Section 7 (item 3) says the ring buffer is "capped at `C.CONSOLE_MAX_LINES` (500)." Section 10 AC #5 says "Console in-memory buffer is capped at configurable max (default 500, **range 100-2000**)." The range 100-2000 appears nowhere else in the spec — not in Constants, not in State DEFAULTS, not in any validation logic. The implementer has no guidance on where this range is enforced or stored.

**[HIGH]** — **Script line validation rule is internally contradictory.** Section 7 (item 6) says "every line must start with `.` or `/`." Section 8 (item 3) says "Lines not starting with `.`, `/`, or `#` are rejected." These two rules conflict: Section 7 would reject `#` comment lines as invalid commands, while Section 8 explicitly allows them. Since scripts are stored as `lines[]` (command lines only, presumably), it's unclear whether `#` lines are stored or stripped at import time.

**[MEDIUM]** — **`db.ui` merge strategy is ambiguous.** Section 6 (State.lua) shows the v2 `ui` DEFAULTS block with new keys (`scale`, `opacity`, `consoleEnabled`, `consoleHeight`) alongside a comment "-- existing keys preserved --". The migration block says to add type guards for `db.ui.scale` and `db.ui.opacity`. But the spec does not address what happens if `db.ui` exists as a table (v1 users will have it) but is missing the new keys. The existing v1 migration pattern uses `if type(db.X) ~= "table" then db.X = DeepCopy(DEFAULTS.X) end` — but this would skip adding new sub-keys to an existing `db.ui` table. The implementer needs explicit guidance to use key-level backfill (e.g., `if db.ui.scale == nil then db.ui.scale = 1.0 end`) rather than table-level replacement.

**[MEDIUM]** — **`VoxGMFrame` in `UISpecialFrames` — already done or not?** Section 6 (UI.lua) says "Register `VoxGMFrame` in `UISpecialFrames` if not already done (Escape to close)." Section 11 (Phase 1) repeats this. The spec never clarifies whether v1 already does this. If it does, the implementer adds a redundant guard. If it doesn't, this is a real v1 bug being fixed. The phrase "if not already done" implies uncertainty in the spec itself — this should be resolved by checking v1 source, which the spec claims to be grounded in.

**[MEDIUM]** — **Companion detection uses two different API calls in the same section.** Section 4.7 uses `C_AddOns.GetAddOnInfo` for the safe wrapper example. Section 7 (item 9) uses `C_AddOns.IsAddOnLoaded` for the actual detection check. These are different functions with different return values. `GetAddOnInfo` returns name/title/notes/loadable/reason/security. `IsAddOnLoaded` returns a boolean. The spec never clarifies which one is authoritative for determining "Installed but not loaded" vs. "Not installed" — a distinction the spec's own status labels ("Loaded", "Installed", "Not Installed") require.

**[LOW]** — **Phase 0 spike output location inconsistency.** Section 11 (Phase 0) says to document findings in `doc/voxgm_api_spike.md`. Section 4.1 states "No new subdirectories." A `doc/` directory would be a new subdirectory. This is a minor contradiction but could cause confusion about where to put the spike output.

---

### Edge Cases

**[HIGH]** — **No handling for `PLAYER_LOGIN` firing before `Console:Init()` completes.** Section 7 (item 1) says `PLAYER_LOGIN` calls all module `Init()` functions. Section 6 (Events.lua) forwards messages to `Console:OnMessage()` from `Events:OnSystemMessage()`. If any system messages fire between `ADDON_LOADED` and `PLAYER_LOGIN` (which does happen — some system messages fire during loading), the console forward will call `Console:OnMessage()` before `Console:Init()` has run. The "if Console is initialized" guard in Events.lua is the only protection, but as noted above, its implementation is unspecified.

**[MEDIUM]** — **Script import truncation behavior is underspecified.** Section 8 (item 3) says "Oversize imports are truncated with a warning." It does not specify: where the warning appears (console? chat? StaticPopup?), whether the truncated script is still importable, or whether the user can see which lines were dropped. For a security-sensitive import path, silent truncation without clear feedback is a usability and auditability gap.

**[MEDIUM]** — **`Scripts:Run()` behavior when a script has zero enabled lines is unspecified.** A script where all lines are disabled (or a script with an empty `lines[]` array) would call `Cmd:SendSequence()` with an empty list. The spec doesn't define what happens: silent no-op? Error? Status message? This is a trivially reachable state (user creates a script, doesn't add lines, hits Run).

**[MEDIUM]** — **Console `persistHistory = false` default means `persistedLines` is always empty on load, but it's still in SavedVariables.** If `persistHistory` is false (the default), `persistedLines` will always be `{}` in the saved data — wasting SavedVariables space and growing the save file if the user ever enables persistence and then disables it (lines remain). The spec has no cleanup/purge logic for this case.

**[MEDIUM]** — **Model preview frame lifecycle is unspecified.** `ModelPreview.lua` creates a `PlayerModel` frame. The spec doesn't say whether this frame is created once at init and shown/hidden, or created on demand. `PlayerModel` frames are expensive. If created on demand (e.g., each time `/vgm preview` is called), repeated calls will leak frames. If created at init, it consumes memory even when never used.

**[LOW]** — **`Cmd:SendSequence()` source parameter propagation is unspecified.** The function signature is `Cmd:SendSequence(commands, source, delay)`. When dispatching individual commands via `Cmd:SendCommand()`, the `source` value passed will label all commands in the sequence with the same source. For script execution, the source should probably be the script name, but the spec doesn't define what value `Scripts:Run()` should pass as `source`.

**[LOW]** — **No spec for what happens if the user opens the model preview while a previous `SetDisplayInfo` call is still rendering.** Rapid successive DisplayID entries could cause visual artifacts or errors. No debounce or lock is specified.

---

### Clarity

**[MEDIUM]** — **"Select" button vs. "Copy" button naming inconsistency.** Section 4.4 calls the clipboard mechanism a "Copy" operation. Section 7 (item 3) calls the button a "Select" button. Section 10 AC #4 says "line-select-to-copy (EditBox method)." Three different names for the same UI element across three sections. The implementer will pick one arbitrarily.

**[MEDIUM]** — **`C.SCRIPT_CAP = 50` and `C.SCRIPT_LINE_CAP = 50` are both 50 but mean different things.** `SCRIPT_CAP` is the maximum number of saved scripts. `SCRIPT_LINE_CAP` is the maximum lines per script. Having two different constants with the same value and similar names (`SCRIPT_CAP` vs `SCRIPT_LINE_CAP`) is a readability hazard. An implementer could easily swap them.

**[LOW]** — **"Companion detection" section (Section 7, item 9) checks `IsAddOnLoaded` but the status label "Installed" (not loaded) requires a different check.** To distinguish "Installed but not loaded" from "Not installed," you need `GetAddOnInfo` (which returns a `reason` field like `"DISABLED"` or returns nil for not-installed). `IsAddOnLoaded` only tells you if it's currently loaded. The spec's three-state status display ("Loaded", "Installed", "Not Installed") cannot be implemented with `IsAddOnLoaded` alone, but the spec never provides the full detection logic.

**[LOW]** — **Phase 5 says "Add companion status to main frame (e.g., status bar area or dedicated panel section)"** — the "e.g." leaves the placement entirely open. Given that the spec is otherwise precise about UI placement, this vagueness will produce an arbitrary implementation that may not match the architect's intent.

**[LOW]** — **The spec title says "Revision 2" but `revision_notes` says it "Addresses 34 findings from 5-round review (R1-R5)."** If this is Round 3 of the current review cycle, the revision notes are describing a *prior* review cycle (not this one). This is confusing metadata — it's unclear whether "R1-R5" refers to rounds of a previous spec version or the current one.

**[INFO]** — **`Data\CompanionAddons.lua` lists CreatureCodex, VoxSniffer, VoxTip, VoxPlacer in AC #10 but the file itself is not defined in the spec.** The static metadata table structure (`{addonName, label, slashCmd, description}`) is mentioned in Section 7 but the actual content (the four addon entries) is never shown. The implementer must invent the exact addon names, slash commands, and descriptions. If any of these are wrong (e.g., wrong internal addon name string), detection will silently fail.

**[INFO]** — **No mention of whether `ScrollingMessageFrame` supports the `:GetNumMessages()` / `:GetMessageInfo()` API needed to implement the ring buffer cap logic.** The spec says "in-memory ring buffer capped at 500" but `ScrollingMessageFrame` has its own internal message storage. The implementer will need to decide whether to maintain a parallel Lua table as the ring buffer (and sync to the SMF) or rely on `SMF:SetMaxLines()`. The spec doesn't clarify which approach is intended.

---

## VERDICT: **FAIL**

**Critical/High issues present:** 5 HIGH findings.

1. `scriptThrottle` key missing from DEFAULTS (data model gap — will cause a migration bug or silent undefined key)
2. Script cancellation mechanism entirely unspecified (required by AC #8, no implementation path given)
3. Console buffer cap range (100-2000) appears only in AC, not in Constants or validation logic
4. Script line validation rule contradicts itself between Section 7 and Section 8 on `#` lines
5. `db.ui` migration strategy will silently fail to backfill new sub-keys for v1 users (the most common upgrade path)

These five issues are concrete enough that an implementer following the spec literally will produce either broken behavior or behavior that fails acceptance criteria. The spec is otherwise well-structured and the lower-severity findings are mostly clarifications rather than blockers.

---

### Round 4: Codex (Phase 2)

**Architecture**
- **[HIGH]** — Script cancellation is still not architected in an implementable way. The spec requires a mid-run “Stop” button, but the only sequencing model it names is the existing fire-and-forget `C_Timer.After` pattern. That pattern is exactly how v1 does staggered sends in [`Tab_Appearance.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L136), and it is not cancellable once callbacks are queued. The proposed new `Commands.lua` surface also defines no queue state, timer handles, or cancel token beyond `Cmd:SendSequence()`, while current [`Commands.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5) has only `SendCommand`/`SendToggle`.
- **[HIGH]** — The console buffer contract is internally inconsistent. Section 6 introduces a fixed `C.CONSOLE_MAX_LINES = 500`, but AC #5 requires a configurable cap with range `100-2000`. There is no corresponding defaults key, validation path, or UI/input plan for that range in the proposed `State.lua` changes, and the current constants model in [`Constants.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Constants.lua#L6) is static.
- **[MEDIUM]** — The console design still overstates reuse of the existing parser system. The real parser contract in [`Events.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L25) stores only `{pattern, callback}`, and [`OnSystemMessage`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L29) only runs callbacks. There is no match classification, parser ID, or label data for a console to filter or annotate by “registered patterns” without extending the parser API.
- **[MEDIUM]** — The proposed 2-second command/response grouping heuristic is a poor fit for the stated script throttle. With the default `0.3s` spacing, one grouping window will overlap roughly 6 sequential commands, so script output will be conflated rather than correlated.
- **[MEDIUM]** — “Mount the Console pane below the tab content area” is not a small additive insert into the current UI layout. [`UI.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L390) anchors one content host directly to the status bar, and every tab scroll frame is created to fill that host in [`UI.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L471). A collapsible lower pane requires explicit frame reflow and resized scroll hosts, not just a new module.

**Integration**
- **[HIGH]** — The companion-addon contract is still not grounded enough in the repo. The spec hard-codes support for `CreatureCodex`, `VoxSniffer`, `VoxTip`, and `VoxPlacer`, but this workspace only contains `VoxSniffer` and `VoxPlacer` under `addons/`; `CreatureCodex` and `VoxTip` are absent. For the addons that do exist, the launch surfaces are implementation-specific slash registrations in [`VoxSniffer.lua`](C:/Users/atayl/VoxCore/addons/VoxSniffer/VoxSniffer.lua#L217), [`ControlPanel.lua`](C:/Users/atayl/VoxCore/addons/VoxSniffer/UI/ControlPanel.lua#L438), and [`VoxPlacer.lua`](C:/Users/atayl/VoxCore/addons/VoxPlacer/VoxPlacer.lua#L853). A metadata tuple of `{addonName, slashCmd}` still does not define a robust callable contract for “Open.”
- **[MEDIUM]** — The slash-command expansion remains understated. The actual handler in [`Core.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L52) lowercases the entire input and only branches on exact `reset` and `minimap`; everything else toggles the window. Supporting `/vgm scale 1.2`, `/vgm opacity 0.7`, `/vgm preview 123`, `/vgm scripts`, and `/vgm settings` requires a tokenizer/dispatcher rewrite, not just additive cases.
- **[MEDIUM]** — The “use existing UI widget patterns” guidance conflicts with the current slider helper. [`UI.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68) creates sliders, but its `OnValueChanged` path rounds every value to an integer in [`UI.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L106). That cannot represent `opacity 0.25-1.0`, `scale` decimals, or a script throttle default/minimum of `0.3`/`0.1` unless the spec explicitly includes a slider/widget change.
- **[MEDIUM]** — The console event coverage is weaker than the acceptance criteria imply. VoxGM today only listens to `CHAT_MSG_SYSTEM` in [`Events.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L13), and the addon’s own README already documents that some Trinity notifications may not surface there in [`README.md`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/README.md#L156). A console built on the same event stream is necessarily best-effort, so the spec should state that more clearly.

**Verification**
- **[MEDIUM]** — The artifact still contains a concrete requirements mismatch on model-preview integration. Section 7 says preview is reachable from both Appearance and CNPC, but AC #7 only requires Appearance plus `/vgm preview`. The current CNPC tab does expose a `displayid` field in [`Tab_CNPC.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_CNPC.lua#L66), so this is not a theoretical distinction; the implementer is left with conflicting scope.
- **[LOW]** — The spec says to register `VoxGMFrame` in `UISpecialFrames` “if not already done,” but v1 already does that in [`UI.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L428). That is not harmful, but it shows the document is still not fully normalized against the checked-in source.
- **[LOW]** — The stated module-header pattern is still slightly too rigid. Most files use `local _, VoxGM = ...`, but [`Core.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L1) uses `local ADDON_NAME, VoxGM = ...`. The real invariant is “namespace via addon varargs,” not one exact header form.

**Design**
- **[MEDIUM]** — Script line validation remains contradictory. Section 7 says every line in a script must start with `.` or `/`, while Section 8 explicitly allows `#` comment/metadata lines during import. The design needs to say whether `#` lines are preserved, stripped during import, or never stored in `lines[]`.
- **[LOW]** — `Cmd:SendCommandThrottled()` is introduced in the spec but never given a real role. All later sections route multi-command behavior through `Cmd:SendSequence()`, and current VoxGM has no comparable API in [`Commands.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5). As written, this looks like dead surface area.
- **[LOW]** — Phase 0 says to document findings in `doc/voxgm_api_spike.md`, which conflicts with the stated “no new subdirectories” rule. That is small, but it is still a scope inconsistency.

**Scope**
- **[INFO]** — The revised spec is materially better grounded than earlier versions. The flat TOC-driven addon layout, 22 loaded files, single command path, existing staggered-command pattern, and current state/backfill model all match the checked-in addon under [`VoxGM.toc`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc), [`State.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua), [`Commands.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua), and [`UI.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua).
- **[INFO]** — Two prior-round concerns do not hold up against the source. `State:Migrate()` already backfills nested `ui` keys from defaults in [`State.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua#L62), and `Util:SanitizeText()` already strips `%c` control characters in [`Util.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Util.lua#L76), which includes newline characters.

Since prior rounds, the spec has clearly improved in one important way: it is now mostly anchored to the real VoxGM layout and extension points instead of proposing a greenfield rewrite. The flat TOC structure, existing tab model, saved-variable ownership, and command dispatch path are described much more accurately. A couple of earlier review concerns are no longer valid after checking source, especially the nested-key migration worry and the newline-sanitization claim. The remaining blockers are now narrower and more architectural: cancellation, console contract details, UI/control precision, and the still-underdefined companion integration surface.

**VERDICT: FAIL**

---

### Round 5: Gemini (Phase 3)

This review assesses Revision 2 of the VoxGM v2.0 specification. The revision notes claim this version is a complete rewrite that addresses 34 findings from a prior 5-round review cycle. However, this audit finds that numerous critical and high-severity issues identified in the provided feedback from those prior rounds remain unaddressed in the current specification. Core architectural flaws related to script cancellation, SavedVariables migration, data model integrity, and security sanitization persist, making the specification unsuitable for implementation.

### Correctness

*   **[CRITICAL]** — **Script Cancellation is Architecturally Unsound.** Section 7.7 requires that script execution "can be cancelled mid-sequence via a 'Stop' button." However, the specified implementation in Section 4.6 and 6 mandates using a sequence of fire-and-forget `C_Timer.After` calls. This mechanism provides no handles or control points to cancel timers once they are scheduled. An implementation following this specification cannot possibly meet the cancellation requirement. A workable solution requires a different architecture, such as a single recursive timer that checks a cancel flag before scheduling the next step, or managing a table of handles from `C_Timer.NewTimer`.
*   **[HIGH]** — **SavedVariables Migration Logic for Nested Tables is Flawed.** The migration plan in Section 6 for the `db.ui` table is incomplete and will fail for existing v1 users. It specifies adding type guards for new keys like `db.ui.scale` but fails to specify that these keys must be backfilled from `DEFAULTS` if they are `nil`. A v1 user's `db.ui` table will exist but will not contain `scale` or `opacity`, leading to `nil` values and runtime errors when `UI:SetScale` is called on login. The migration must explicitly handle adding new keys to existing sub-tables.
*   **[HIGH]** — **Data Model for Script Throttle is Inconsistent.** Section 7.7 states the script throttle delay is stored in `VoxGMDB.console.scriptThrottle`. However, the `DEFAULTS` table definition for the `console` key in Section 6 does not include a `scriptThrottle` key. This is a data model contradiction that will lead to implementation errors and prevents the setting from being correctly persisted or migrated.
*   **[HIGH]** — **Console Buffer Cap Specification is Contradictory.** Section 6 defines a hardcoded constant `C.CONSOLE_MAX_LINES = 500`. However, Acceptance Criterion #5 requires the buffer to be "capped at configurable max (default 500, range 100-2000)." The specification provides no `DEFAULTS` key to store this user-configurable value, no UI for changing it, and no logic for enforcing the 100-2000 range. The implementation is impossible as specified due to these conflicting requirements.
*   **[HIGH]** — **Potential for Fatal Errors During Addon Load.** Section 6 specifies that `Events.lua` will forward all system messages to `VoxGM.Console:OnMessage()` "if Console is initialized." It is common for `CHAT_MSG_SYSTEM` events to fire after `ADDON_LOADED` but before `PLAYER_LOGIN`. Since module initialization is specified to occur on `PLAYER_LOGIN`, `Events:OnSystemMessage` will be called before `Console:Init` has run. The spec does not define the "is initialized" check, leaving a critical race condition that could cause fatal Lua errors during the loading screen.
*   **[MEDIUM]** — **Companion Addon Detection Logic is Insufficient.** Section 7.9 specifies using `IsAddOnLoaded` (or its `C_AddOns` equivalent) to determine addon status. This function can only determine if an addon is currently loaded. It cannot distinguish between an addon that is not installed and one that is installed but disabled, yet the UI requires three distinct states: "Loaded," "Installed," and "Not Installed." To meet this requirement, the implementation must use `GetAddOnInfo` and inspect its return value and reason codes, which is not what the spec directs.
*   **[MEDIUM]** — **Script Line Validation Logic is Contradictory.** Section 7.6 states that during authoring, "every line must start with `.` or `/`." In contrast, Section 8.3 states that during import, "Lines not starting with `.`, `/`, or `#` are rejected." This creates an inconsistency where comment lines (`#`) are valid for import but invalid for direct authoring. The specification must clarify whether `#` lines are stripped on import or if they are a valid, storable line type.
*   **[MEDIUM]** — **Console Response Grouping Heuristic is Unfit for Purpose.** The "best-effort time-window heuristic" of 2 seconds (Section 4.4) is fundamentally flawed for its primary use case: monitoring scripted command sequences. With a default throttle of 0.3s between commands, a 2-second window will incorrectly group responses from 6-7 different commands together, making the output an unreadable jumble rather than a useful diagnostic tool.
*   **[MEDIUM]** — **Scope of Model Preview Integration is Ambiguous.** Section 7.5 states the model preview can be opened from both the `AppearanceTab` and the `CustomNPCTab`. However, Acceptance Criterion #7 omits the `CustomNPCTab`, only requiring integration with the `AppearanceTab` and a slash command. This leaves the implementer with conflicting requirements.
*   **[LOW]** — **Redundant Security Check for Semicolons.** Section 7.8 specifies rejecting imported script lines that contain a semicolon. This check is performed after the line has been sanitized by `Util:SanitizeText()`, which is defined in Section 8.1 as already stripping semicolons. The check is therefore redundant and can never trigger.

### Security

*   **[HIGH]** — **Unsanitized Metadata in Script Imports Allows UI Injection.** Section 7.8 describes an import format where metadata lines like `# Name: My Script` and `# Description: ...` are parsed. The specification provides no requirement to sanitize the *values* extracted from these lines before they are stored in `VoxGMDB` and displayed in the UI. An attacker could craft a script with a name like `|TInterface\Icons\INV_Misc_QuestionMark:0|t |cffFF0000You have been HACKED|r` to create deceptive or malicious UI elements within the VoxGM frame, a form of UI injection or "redressing." All user-provided text from an import, including metadata, MUST be sanitized.

### Performance

*   **[LOW]** — **Model Preview Frame Lifecycle is Unspecified.** The spec does not state whether the `PlayerModel` frame for the previewer is created once and hidden/shown, or created on-demand. `PlayerModel` frames can be resource-intensive. Creating them on-demand repeatedly could lead to performance degradation or memory leaks if not managed carefully. The spec should recommend a create-once-and-reuse pattern.

### Style

*   **[MEDIUM]** — **Dead API Surface.** Section 6 defines a new function `Cmd:SendCommandThrottled`, but no other part of the specification ever calls or references it. All throttled execution is routed through `Cmd:SendSequence`. This function appears to be dead code and should be removed to avoid confusion.
*   **[LOW]** — **Inconsistent Naming for UI Element.** The feature for copying console text to the clipboard is referred to by three different names: a "Copy" operation (Section 4.4), a "Select" button (Section 7.3), and "line-select-to-copy" (AC #4). This should be standardized to one name for clarity.
*   **[LOW]** — **Ambiguous Constant Naming.** Section 6 defines `C.SCRIPT_CAP = 50` (max number of scripts) and `C.SCRIPT_LINE_CAP = 50` (max lines per script). Using the same value for two distinct limits with very similar names is a potential source of confusion and implementation error. Renaming `C.SCRIPT_CAP` to `C.SCRIPT_BOOK_CAP` or similar would improve clarity.

---
**VERDICT: FAIL**

---

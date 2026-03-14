---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 3
reviewer: Claude
model: claude-sonnet-4-6
date: 2026-03-13T15:46:11.094907
elapsed_seconds: 90.7
---

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
---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 2
reviewer: Gemini
model: gemini-2.5-pro
date: 2026-03-13T15:45:21.181889
elapsed_seconds: 40.8
---

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
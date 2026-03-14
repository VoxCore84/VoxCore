---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 5
reviewer: Gemini
model: gemini-2.5-pro
date: 2026-03-13T16:13:43.385010
elapsed_seconds: 56.9
---

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
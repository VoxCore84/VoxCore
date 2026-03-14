---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 2
reviewer: Gemini
model: gemini-2.5-pro
date: 2026-03-13T16:40:12.125442
elapsed_seconds: 62.1
---

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
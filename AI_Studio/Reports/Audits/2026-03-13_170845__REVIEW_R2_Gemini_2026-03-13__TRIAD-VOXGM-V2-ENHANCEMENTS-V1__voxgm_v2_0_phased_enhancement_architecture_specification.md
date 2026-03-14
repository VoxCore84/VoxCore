---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 2
reviewer: Gemini
model: gemini-2.5-pro
date: 2026-03-13T17:08:45.295875
elapsed_seconds: 59.8
---

This review covers Revision 6 of the VoxGM v2.0 Phased Enhancement Architecture Specification. The document is exceptionally detailed and demonstrates significant maturation over its revision history. Changes since the prior round correctly address major performance (O(n^2) trim) and correctness (stale-index deletion) issues, and add important clarifications around UI state management, namespacing, and component interaction. The architecture is robust, with a clear plan for handling API uncertainties via the Phase 0 spike.

Despite its high quality, this review identifies one critical factual error in the specification's text and one high-severity inconsistency that could lead to implementation bugs. Several minor points of clarification are also noted.

---

### Correctness

*   **[CRITICAL]** Section 4.5 contains a factually incorrect statement about Lua's type coercion rules. The spec states: "`tonumber("0")` returns `0`, which is falsy in Lua." This is false; in Lua, only `nil` and `false` are falsy, while the number `0` is truthy. Although the document correctly concludes that the implementation must use `id ~= nil` to handle DisplayID 0, the justification is dangerously wrong. An implementer relying on this faulty rationale could introduce subtle bugs elsewhere or "correct" the valid code to match the invalid reasoning. The justification must be corrected to state that `id ~= nil` is necessary to distinguish a valid numeric input (including 0) from a non-numeric input that causes `tonumber` to return `nil`.

*   **[HIGH]** The specification is inconsistent regarding the validation of `scripts.throttleDelay`.
    *   Section 6 (State.lua) states: "Validation: ... floor `scripts.throttleDelay` to `C.SCRIPT_THROTTLE_MIN`". The word "floor" is mathematically incorrect for establishing a minimum value and is ambiguous.
    *   Section 7.7 (Script execution) states: "Throttle: `math.max(VoxGMDB.scripts.throttleDelay, C.SCRIPT_THROTTLE_MIN)`". This is the correct, unambiguous logic.
    *   The confusing language in Section 6 must be replaced with the clear logic from Section 7.7 (e.g., "clamp `scripts.throttleDelay` to a minimum of `C.SCRIPT_THROTTLE_MIN`") to prevent implementation errors arising from conflicting requirements.

*   **[MEDIUM]** The specification for the "Copy Line" overlay feature (Sections 4.4 and 7.3) is incomplete. It describes a core mechanic that relies on calculating a `lineBuffer` index using the `ScrollingMessageFrame`'s scroll offset ("`smf:GetNumMessages()` minus scroll offset"). However, it fails to specify the method for retrieving this scroll offset. This leaves a key implementation detail to guesswork, potentially leading to incorrect behavior. The spec should be updated to mention the expected API (e.g., `scrollFrame:GetVerticalScroll()`) for obtaining this value.

*   **[LOW]** The console buffer management logic in Section 7.3 (`OnMessage`) specifies adding a new message *before* checking the buffer limit and removing the oldest entry. This allows the buffer to temporarily contain `maxLines + 1` elements. While not a functional bug, a more conventional and precise implementation would be to remove an element if `#lineBuffer >= maxLines` *before* adding the new one, strictly maintaining the `maxLines` cap at all times.

### Style

*   **[INFO]** The `_initialized` guard in `Events.lua` is specified only for `VoxGM.Console`. The rationale given is that other modules are not called from event handlers that can fire before `PLAYER_LOGIN`. While this is likely true for the current scope, this assumption should be explicitly called out as a point of verification for the implementer, and a reminder that any future module hooking early events would require a similar guard.

---

## VERDICT: FAIL

The specification is of very high quality but contains a critical factual error in its justification of a key logic point (Lua truthiness) and a high-severity inconsistency in its validation requirements. These issues must be resolved to ensure the implementer works from a completely accurate and unambiguous document. Once these are addressed, the specification will be in an excellent state for implementation.
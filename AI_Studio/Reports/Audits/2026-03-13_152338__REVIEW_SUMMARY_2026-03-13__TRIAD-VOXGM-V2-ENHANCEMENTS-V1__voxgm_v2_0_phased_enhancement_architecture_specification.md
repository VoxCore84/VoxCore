# Review Cycle Summary: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md

**Date**: 2026-03-13T15:23:38.960634

**Rounds completed**: 5

**Final verdict**: FAIL

**Wall time**: 455.0s | **CPU time**: 614.9s (saved 160s via parallelism)


## Round Results

| Round | Reviewer | Model | Time | Verdict | Phase |
|-------|----------|-------|------|---------|-------|
| R1 | Codex | gpt-5.4 | 172.2s | FAIL | Phase 1 |
| R2 | Gemini | gemini-2.5-pro | 55.3s | FAIL | Phase 1 |
| R3 | Claude | claude-sonnet-4-6 | 104.6s | FAIL | Phase 1 |
| R4 | Codex | gpt-5.4 | 236.7s | FAIL | Phase 2 |
| R5 | Gemini | gemini-2.5-pro | 46.0s | FAIL | Phase 3 |

## Per-Round Reviews

### Round 1: Codex (Phase 1)

**Architecture**
- **[HIGH]** — The spec is not grounded in the current VoxGM repo topology. It proposes a new `Core/UI/Features/Tabs/Data/Util` tree, references `VoxGM.xml`, and says implementation should first map the “actual existing 26 files,” but the live addon is a flat TOC-driven layout with 22 loaded Lua files and no XML at all. That mismatch is large enough to cause load-order and integration mistakes before any v2 feature work starts. Evidence: [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc):1, [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua):27, [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua):388
- **[HIGH]** — The Search/Explorer design has an unresolved data-source contradiction. The spec requires searchable Items and Spells, but also forbids large shipped datasets and admits the addon has no DB access. In practice, WoW client APIs do not provide a complete free-text item/spell corpus to search without an index. The current addon only ships small preset tables, not searchable item/spell data. This acceptance criterion is therefore underspecified to the point of likely non-implementability. Evidence: [VoxGM folder tree](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM), [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc):17
- **[MEDIUM]** — Phase 1 is framed as foundational refactoring, but two of its headline deliverables already exist: a central command dispatcher and additive SavedVariables migration. Rebuilding them under new paths is churn, not missing architecture, and conflicts with the spec’s own “prefer additive file creation over large risky rewrites.” Evidence: [Commands.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua):5, [State.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua):31, [State.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua):42

**Integration**
- **[HIGH]** — The tab/module integration plan does not match the current tab contract. Today tabs are registered by `C.TABS` IDs and resolved directly from `VoxGM.Tabs[tabId]` during `UI:CreateTabContainers()`. Renaming everything to `Tabs/GMModeTab.lua`, `NPCOpsTab.lua`, `CharacterTab.lua`, etc. is not additive; it implies replacing the live registration model and every existing module binding. Evidence: [Constants.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Constants.lua):31, [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua):471, [Modules/Tab_GM.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_GM.lua):4
- **[MEDIUM]** — Companion-addon integration is only partially source-verifiable. `CreatureCodex` and `VoxSniffer` exist in `tools/publishable`, but I could not verify publishable `VoxTip` or `VoxPlacer` addons in this repo. A registry that promises detection/launch hooks for all four is therefore underspecified and may produce dead buttons or repo-external dependencies. Evidence: [CreatureCodex.toc](/C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.toc):1, [VoxSniffer.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.toc):1, [doc/session_state.md](/C:/Users/atayl/VoxCore/doc/session_state.md):26, [doc/session_state.md](/C:/Users/atayl/VoxCore/doc/session_state.md):31

**Verification**
- **[HIGH]** — The artifact’s repo facts are already wrong in Round 1. It says to “map the actual existing 26 files,” while the addon directory currently contains 25 entries total and only 22 TOC-loaded Lua files. That makes the spec unreliable as a source-of-truth architecture document until the repo inventory is corrected. Evidence: [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc):12, [doc/session_state.md](/C:/Users/atayl/VoxCore/doc/session_state.md):220, [VoxGM folder tree](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM)
- **[INFO]** — The spec correctly assumes there are 6 existing tabs and a single SavedVariables namespace `VoxGMDB`. Evidence: [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc):6, [Constants.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Constants.lua):31

**Design**
- **[MEDIUM]** — The console UX says “clear/copy/filter controls,” but WoW does not have a native clipboard API. “Copy” needs to be defined as an edit-box export/select flow, not clipboard behavior, or implementers will build against an impossible contract.
- **[MEDIUM]** — The spec treats model preview as a narrow additive feature, but the current relevant workflows are spread across existing `Appearance` and `CNPC` edit boxes. Without a precise ownership contract for autofill/preview hooks, this is likely to become cross-tab coupling rather than the clean module split the spec claims. Evidence: [Modules/Tab_Appearance.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua):31, [Modules/Tab_CNPC.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_CNPC.lua):66

**Scope**
- **[MEDIUM]** — The spec says “maintain the current 6-tab mental model” and “prefer additive file creation,” but its file plan is effectively a wholesale architecture rewrite: new bootstrap, new event router, new saved-variable layer, new tab controller, new widgets, new feature services, and renamed tab modules. That is broader than the stated scope and risk posture for a backwards-compatible v2.
- **[LOW]** — `VoxGM.xml` is referenced as a possible modification target even though no such file exists in the addon today. That should be removed to avoid misleading implementers. Evidence: [VoxGM folder tree](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM)

Round 1 baseline only, so there are no prior-round fixes to compare. Relative to the live repo, this artifact adds a substantial v2 feature set, but it overstates its source alignment: the current addon already has a dispatcher, migration path, six-tab registration model, and flat TOC load order, while the spec is written as if those foundations do not exist and as if searchable item/spell data is readily available client-side.

**VERDICT: FAIL**

---

### Round 2: Gemini (Phase 1)

This review covers the `TRIAD-VOXGM-V2-ENHANCEMENTS-V1` architecture specification. The document has matured significantly since its initial proposal, now featuring a detailed file structure, comprehensive data flow diagrams, a phased implementation plan, and explicit acceptance criteria. The core architectural decisions—maintaining zero-dependency, ensuring SavedVariables migration, and isolating new features into modular components—are sound and well-articulated. However, several critical security and correctness gaps have been identified that must be addressed before implementation can proceed.

### Correctness
*   **[HIGH]** Script execution requires mandatory throttling, not optional. The specification notes in section 5.14 that a delay scheduler "can be introduced if throttling becomes necessary." For a GM tool capable of running sequences of potentially server-intensive commands, this is not optional. A user could inadvertently or maliciously create a script that sends dozens of commands in a single frame, risking server instability, character state corruption, or disconnection. The architecture must mandate a non-zero, configurable delay between dispatched commands within a single script execution to ensure stability.
*   **[MEDIUM]** The command/response correlation mechanism is undefined. Section 5.7 describes a powerful feature: correlating dispatched commands with server responses in the console. However, the mechanism for this is non-trivial due to the asynchronous nature of server communication. If two commands are sent in rapid succession, their responses may arrive out of order or be interleaved with other system messages. The specification must detail the proposed correlation strategy (e.g., command echo parsing, unique transaction IDs if the server supports them, or time-based heuristics) and acknowledge its limitations.
*   **[MEDIUM]** The search index data source and invalidation strategy are ambiguous. The file `Features/Search/SearchIndex.lua` is described as an "optional lightweight cached index state." This is a potential source of data integrity issues. The specification must clarify what data is being indexed, how this index is built (e.g., at login, on-demand), and critically, how it is invalidated when a new client patch alters item, spell, or other game data. An outdated index will provide incorrect search results.
*   **[LOW]** The SavedVariables migration strategy does not account for data transformation. Section 3.2 details an *additive* migration path, which is excellent for adding new features. However, it does not address the future need to *transform* or *rename* existing v1 keys. While not strictly required by the current scope, a robust migration system should include a pattern for version-stepped data transformations (e.g., if `v1.someFlag = true` needs to become `v2.someFlag = "enabled"`). Acknowledging this pattern would make the architecture more future-proof.

### Security
*   **[CRITICAL]** The specification lacks protections against command injection in script parameters. Section 5.13 mentions validating that script lines begin with '.' or '/', which prevents chat message injection. However, it completely overlooks the risk of command injection *within* a command's parameters. A malicious script shared by another user could contain a line like `.teleport "Neverland; .account delete 12345; teleport"`. While the server's command parser should ideally handle this, the addon must not trust it to do so. The `CommandDispatcher` or `ScriptRunner` must implement strict validation or sanitization of command strings to prevent multiple commands from being concatenated or maliciously embedded in parameters, especially when sourced from the import feature.
*   **[HIGH]** The script import/export format poses a security risk without further definition. Section 5.15 specifies a "plain-text portable block" for script import/export. A poorly designed or overly complex format (e.g., a custom serialized Lua table) could be exploited by a malformed import string to cause unhandled errors, client instability, or even unintended logic execution if the parser is flawed. The specification should mandate a simple, robust, line-by-line format and explicitly forbid complex parsing or deserialization of imported data.

### Performance
*   **[MEDIUM]** The risk of client slowdown from naive search implementation is not addressed. Section 5.9 describes search providers using "client-safe lookups." However, iterating through large datasets like all items or spells without using optimized APIs (e.g., `C_Search.Search` where available) can cause significant frame rate drops ("freezes"). The specification should guide the implementer towards using the most performant, non-blocking client APIs for searching game data to avoid UI lockups.
*   **[LOW]** The UI implementation for the console frame lacks explicit performance constraints. While section 6 notes that persisted buffers must be capped, it's equally important for the UI widget itself (`ScrollingMessageFrame`) to be capped. Adding an unbounded number of lines to a `ScrollingMessageFrame` can degrade performance, even if the lines are not visible. The specification should explicitly state that the UI frame will only display the last N messages from the backing data buffer to ensure consistent UI performance.

### Style
*   **[INFO]** The specification uses addon-specific jargon without definition. The term "DMS-style event-to-method dispatch" in section 4 is understood by many experienced addon developers but is not a universal standard. For maximum clarity, specifications should briefly define such patterns or link to an example.
*   **[INFO]** The refactoring strategy for root files could be clearer. The file structure in section 4 notes that `VoxGM.lua` and `VoxGM.xml` will be modified. The implementation plan implies that their logic will be moved to new `Core/` modules. The specification should explicitly state that the goal is to reduce the root files to minimal bootstrapping logic that delegates to the new, more organized modules.

---
**VERDICT: FAIL**

The specification is comprehensive and well-structured but contains a critical security vulnerability related to command injection and two high-severity findings concerning script execution safety and import functionality. These issues present a significant risk to users and server stability. The specification must be revised to mandate command parameter sanitization, required execution throttling, and a securely defined import/export format before implementation begins.

---

### Round 3: Claude (Phase 1)

# VoxCore Triad Cold-Read Review
**Artifact:** TRIAD-VOXGM-V2-ENHANCEMENTS-V1
**Reviewer Role:** Cold-Read (Round 3)
**Reviewer:** Claude API

---

## Prior Round Summary

This appears to be the first cold-read review of this specific artifact (the spec is marked Round 3 in the pipeline but no prior cold-read findings were provided for comparison). The spec describes a phased v2.0 enhancement of VoxGM, a TrinityCore GM addon for WoW 12.x. It is architecturally coherent and well-structured, but several implementation-critical gaps are present that a fresh implementer would immediately encounter.

---

## Category 1: Implementation Bias (Assumptions the builder took for granted)

**[CRITICAL]** — **`Settings.RegisterCanvasLayoutCategory` API existence is unverified for WoW 12.x (Midnight client).** The spec repeatedly mandates this API (Section 3, Section 5 step 16, Section 6, Section 7 AC, Phase 2). This API was introduced in retail WoW 10.x. WoW 12.x "Midnight" is a future/custom client on a private server. There is zero confirmation that this API exists, has the same signature, or behaves identically in the TrinityCore 12.x build. If it doesn't exist, Phase 2 fails entirely and the Settings acceptance criterion is unachievable. The spec should have explicitly called out "verify API availability on client 12.0.1.66263" as a prerequisite, not buried it only for PlayerModel in Phase 4.

**[CRITICAL]** — **`C_AddOns.GetAddOnInfo` / `IsAddOnLoaded` API names are assumed without verification.** Section 5 step 18 and Section 3.7 reference `C_AddOns` namespace APIs. In older WoW API surfaces these were global functions (`GetAddOnInfo`, `IsAddOnLoaded`). The `C_AddOns` namespace migration happened in retail 10.x. Whether the 12.x Midnight client uses the namespaced or legacy form is unspecified. An implementer who writes `C_AddOns.GetAddOnInfo(...)` on a client that only has `GetAddOnInfo(...)` gets a silent nil-call failure with no error, meaning companion detection silently returns "not found" for everything.

**[HIGH]** — **`ScrollingMessageFrame` is assumed to exist and be sufficient, but no API surface is specified.** Section 3.3 and Phase 3 mandate a `ScrollingMessageFrame`-based console. This widget exists in classic/retail but its constructor pattern, method names (`AddMessage`, `SetMaxLines`, `GetNumMessages`, etc.), and scroll behavior differ subtly across client versions. The spec gives no fallback if the widget is unavailable or behaves differently. A "copy-friendly" UX is mentioned but `ScrollingMessageFrame` has no native copy-to-clipboard API — this is a known limitation the spec glosses over without resolution.

**[HIGH]** — **`PlayerModel:SetDisplayInfo(displayID)` behavior on client 12.0.1.66263 is only validated in Phase 4, but the acceptance criteria in Section 7 treat it as a deliverable.** Phase 4 says "Validate PlayerModel behavior on client 12.0.1.66263 with no taint or frame errors" — this is a discovery task, not a validation task. If `SetDisplayInfo` doesn't work as expected on this client, the entire model preview feature (which has its own acceptance criterion) is blocked. This risk should be front-loaded as a spike/prototype before Phase 4 is committed to the implementation order.

**[HIGH]** — **The "ring buffer" for console output is described but never sized.** Section 5 step 6 mentions "in-memory ring buffer and persisted short history buffer." Section 6 says "Any persisted buffer or history growth must be capped with explicit max line/count limits." But no actual default values are specified anywhere in the spec. `Data/Defaults.lua` is listed as a file but its contents are never defined. An implementer must invent these numbers. The acceptance criterion for "console max lines" is configurable but the range, default, and minimum are undefined.

**[MEDIUM]** — **`ChatEdit_SendText` is named as the existing mechanism to replace, but the actual WoW 12.x API for sending chat/commands is not confirmed.** `ChatEdit_SendText` is a Lua function that exists in some WoW versions but may not be the correct or only mechanism. The spec assumes this is the canonical send path without confirming it, and the entire CommandDispatcher refactor depends on correctly identifying all call sites of this function.

**[MEDIUM]** — **The spec assumes `Bindings.xml` keybinding declarations work identically in WoW 12.x.** The `Bindings.xml` format and the Key Bindings UI registration mechanism have changed across WoW versions. No verification is called out. The acceptance criterion treats this as straightforward.

**[MEDIUM]** — **"Mixin-style local Lua modules" is mentioned in Section 3.1 but never defined or exemplified.** An implementer reading this cold has no guidance on what pattern is meant — WoW's `Mixin()` function, a manual table-copy pattern, or something else. If the existing v1 codebase doesn't already use a consistent mixin pattern, this is an undefined architectural primitive.

---

## Category 2: Consistency Issues

**[HIGH]** — **`Core/SavedVariables.lua` and `Data/Defaults.lua` have overlapping responsibilities with no clear boundary.** Section 4 lists both files. `Core/SavedVariables.lua` is described as containing "defaults, CopyDefaults, CleanupDB, schema migration." `Data/Defaults.lua` is described as "canonical defaults table." These are either the same thing (duplication) or there's an intended split that is never explained. An implementer will have to guess which file owns the defaults table and which imports from the other.

**[HIGH]** — **`Core/Bootstrap.lua` and `VoxGM.lua` have undefined division of responsibility.** Section 5 step 1 says "VoxGM.toc loads... core bootstrap." Step 3 says "Core/Bootstrap.lua initializes EventRouter, CommandDispatcher..." but Section 4 says `VoxGM.lua` handles "startup orchestration, module init order, migrations." Both files are described as doing startup orchestration. An implementer cannot determine which file is the true entry point or whether `VoxGM.lua` calls `Bootstrap.lua` or vice versa.

**[MEDIUM]** — **The spec lists `Features/HistoryService.lua` as "modify" but also lists it under `Features/` not `Tabs/` or `Core/`.** The existing v1 file location is unknown to a cold reader. If `HistoryService.lua` doesn't already exist at `Features/HistoryService.lua`, the "modify" instruction is wrong. Same issue applies to `Features/FavoritesService.lua`. The spec assumes knowledge of the v1 file tree that a cold implementer doesn't have.

**[MEDIUM]** — **Section 7 acceptance criteria reference "at least one visible integration point in AppearanceTab or CustomNPCTab" but Section 8 Phase 4 says to add preview to both tabs plus "any other relevant tab."** The AC uses "or" (minimum one), the implementation order uses "and" (both). These are inconsistent requirements — the AC could be satisfied by implementing only one tab while Phase 4 implies both are required.

**[MEDIUM]** — **`UI/Widgets/Dropdown.lua` is listed as "new or modify existing dropdown helper."** This is the only file in the entire spec with an ambiguous new/modify designation. It implies a dropdown helper may already exist in v1 but the spec doesn't confirm this. An implementer doesn't know whether to create a new file or find and modify an existing one.

**[LOW]** — **Section 8 Phase 2 says to add `Data/CompanionAddons.lua` and `Core/CompanionRegistry.lua`, but Section 5 step 18 says `Core/CompanionRegistry.lua` checks addon IDs using `C_AddOns` APIs.** The data file `Data/CompanionAddons.lua` is never described in the data flow section. It's unclear whether `CompanionRegistry.lua` reads from `CompanionAddons.lua` or if `CompanionAddons.lua` is a standalone lookup table. The relationship between these two files is implicit.

**[LOW]** — **`Util/Export.lua` is described as "import/export text utility" but `Features/Scripts/ScriptSerializer.lua` also handles export/import.** Either `Export.lua` is a generic utility that `ScriptSerializer.lua` calls, or they duplicate functionality. The spec doesn't clarify the relationship.

---

## Category 3: Edge Cases and Untested Paths

**[HIGH]** — **SavedVariables migration is described as "additive" but no handling exists for corrupted or partially-migrated v1 data.** If a user's v1 SavedVariables has a key with the same name as a new v2 key but with an incompatible type (e.g., v1 stored `ui` as a boolean, v2 expects `ui` as a table), the migration will silently produce broken state or a Lua error. The spec says "copies missing defaults" but doesn't address type conflicts.

**[HIGH]** — **Script execution "immediate sequential in one frame" is described as the default, with throttling as optional.** WoW's frame budget is real. Executing many GM commands in a single frame via `ChatEdit_SendText` (or equivalent) in a tight loop may hit rate limits, cause the server to drop commands, or trigger anti-spam protections. The spec acknowledges this risk ("if throttling becomes necessary") but defers it without specifying what triggers the decision or what the fallback behavior is for the user.

**[MEDIUM]** — **The console's `CHAT_MSG_SYSTEM` listener will capture ALL system messages, not just VoxGM-related ones.** Section 3.3 says "passively mirrors relevant events." But `CHAT_MSG_SYSTEM` is a global event that fires for many unrelated server messages (loot, quest completions, system notices, etc.). The filtering logic to distinguish "GM command response" from "unrelated system message" is entirely unspecified. This is a non-trivial problem — there is no reliable client-side way to correlate a system message with a specific command that triggered it.

**[MEDIUM]** — **The CommandDispatcher "emits a local callback/event so history and console can correlate actions" — but the correlation mechanism is undefined.** Section 5 step 7 describes this correlation as a goal. In practice, WoW server responses to GM commands arrive asynchronously via `CHAT_MSG_SYSTEM` with no request ID or correlation token. The spec implies correlation is possible but doesn't explain how. An implementer will discover this is architecturally difficult and may produce misleading console output.

**[MEDIUM]** — **Search providers using "client APIs/cache" for items and spells have undefined behavior for items/spells not in the client cache.** The WoW client only has data for items/spells the player has encountered. A GM searching for an obscure NPC display ID or item they've never seen will get empty results with no explanation. The spec says "clearly label search scopes" but doesn't specify what the empty-result UX looks like or whether a "not in cache" state is distinguished from "does not exist."

**[MEDIUM]** — **`ScriptSerializer` import "validates structure and prompts before overwrite" — but what happens if the import payload is from a different version of VoxGM?** The spec mentions "versioned plain-text payloads" but doesn't define version compatibility rules. An import from a hypothetical v2.1 into v2.0 could silently drop fields or fail validation with a cryptic error.

**[LOW]** — **The splitter position persistence ("may also be persisted if stable and low risk") is vague.** "If stable and low risk" is not a deterministic implementation instruction. An implementer must make a judgment call with no criteria defined for what constitutes "stable."

**[LOW]** — **`UI_ERROR_MESSAGE` is listed as a captured event in Section 5 step 4, but its relationship to GM command errors is not specified.** `UI_ERROR_MESSAGE` fires for many client-side errors (out of range, can't do that, etc.) that are unrelated to GM commands. Capturing it in the console without filtering will produce noise.

---

## Category 4: Clarity and Documentation Accuracy

**[HIGH]** — **The spec title says "Phased Enhancement Architecture Specification" and Section 8 defines 7 phases, but Section 9 "Immediate Next Actions" describes a linear sequence that doesn't map cleanly to phase boundaries.** Specifically, Section 9 says to implement `CommandDispatcher` and SavedVariables migration first (Phase 1), then Settings panel and scale/opacity (Phase 2), then "run the mandated review pipeline." This implies the review pipeline runs after Phase 2, but the spec covers 7 phases. A new developer reading Section 9 would not know whether to implement all 7 phases before review or stop after Phase 2.

**[MEDIUM]** — **The spec says "maintain existing 6-tab UX" but never names or describes the 6 tabs.** A cold reader sees `GMModeTab`, `NPCOpsTab`, `CharacterTab`, `AppearanceTab`, `CustomNPCTab`, and `DevToolsTab` in the file tree — that's 6 tabs, which can be inferred. But the spec never explicitly states "the 6 tabs are X, Y, Z..." This is a minor clarity gap but means a cold implementer must infer the tab inventory from the file tree rather than from explicit documentation.

**[MEDIUM]** — **"DMS-style event-to-method dispatch" in Section 5 step 4 is jargon without definition.** "DMS" is not a standard WoW addon development term. A cold reader has no idea what this means. It may refer to a specific pattern the architect had in mind, but it's undefined in the spec.

**[MEDIUM]** — **Section 6 constraint says "Settings must be registered with native WoW 12.x Settings APIs, not custom-only hidden config flows" — but the spec also says the existing v1 has settings somewhere.** It's unclear whether v1 has a custom settings flow that needs to be migrated/replaced or whether v1 had no settings UI at all. The migration path for existing settings UI (if any) is unspecified.

**[LOW]** — **`StatusPill.lua` is described as "addon present/loaded/enabled status indicator" but the distinction between "present," "loaded," and "enabled" is not defined.** In WoW addon terminology, an addon can be present (in the AddOns folder), enabled (not disabled in the addon list), and loaded (actually initialized). These are three different states. The spec uses all three terms but doesn't specify which API calls map to which state or how the pill should visually represent each combination.

**[LOW]** — **Section 3.6 says "Disallowed Behavior: Do not add loadstring, RunScript-based arbitrary code execution" — but `RunScript` is not a standard WoW API name.** The actual WoW API for running arbitrary Lua is `RunScript()` (which exists) or the Lua built-in `load()`/`loadstring()`. Naming `RunScript` as if it's a known API without clarification is slightly misleading, though the intent is clear.

**[LOW]** — **The spec mentions "clipboard-like edit focus flow" in Section 5 step 10 as a copy mechanism.** WoW addons cannot directly access the system clipboard. The "clipboard-like" phrasing implies a workaround (e.g., focusing an EditBox with the value pre-filled so the user can Ctrl+C), but this is never explained. A cold implementer might attempt to use a nonexistent clipboard API.

**[INFO]** — **The spec architect is listed as "ChatGPT" and systems architect QA/QC as "Antigravity."** These are non-human or pseudonymous attributions. This is not a technical finding but is worth noting for accountability purposes in the review pipeline.

**[INFO]** — **Phase 7 says "Run regression testing across all original v1 workflows" but no v1 test suite or test methodology is referenced anywhere in the spec.** There is no definition of what "regression testing" means in this context, who performs it, or what constitutes a pass.

---

## VERDICT: **FAIL**

**Critical issues (2):** The `Settings.RegisterCanvasLayoutCategory` API and `C_AddOns` namespace availability on WoW 12.x Midnight client are unverified assumptions that could invalidate entire phases of the implementation. These must be confirmed against the actual client build before implementation begins.

**High issues (7):** `ScrollingMessageFrame` copy UX gap, `PlayerModel` API risk deferred too late, undefined buffer sizes, `ChatEdit_SendText` API uncertainty, `Bindings.xml` compatibility, `Core/SavedVariables.lua` vs `Data/Defaults.lua` ownership ambiguity, `Bootstrap.lua` vs `VoxGM.lua` entry point confusion, and SavedVariables type-conflict migration gap collectively represent a high probability of implementation stalls or silent failures.

**Recommended before implementation:** Spike the three client API questions (Settings registration, C_AddOns namespace, PlayerModel/SetDisplayInfo) on the actual 12.0.1.66263 client as a zero-cost discovery task. Resolve the Bootstrap/VoxGM.lua entry point ambiguity and the Defaults/SavedVariables file ownership split in the spec before any code is written.

---

### Round 4: Codex (Phase 2)

## Architecture
- **[HIGH]** — The spec is still not grounded in the live addon topology. It proposes a new `Core/UI/Features/Tabs/Data/Util` tree and new bootstrap/controller layers, but the shipped addon is a flat TOC-loaded addon with existing root services already responsible for bootstrap, state, commands, events, and tab creation. That is a structural rewrite, not the “additive file creation” the spec claims. Evidence: [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc#L12), [README.md](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/README.md#L149), [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L4), [State.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua#L7), [Commands.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5)
- **[MEDIUM]** — Phase 1 still treats SavedVariables migration and central command dispatch as new foundational work, but both already exist in v1. `State.lua` already does additive default backfill, type coercion, and schema-version handling, and `Commands.lua` already centralizes send/history/status behavior. Rebuilding those under new paths is churn with no proven architectural payoff. Evidence: [State.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua#L34), [State.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua#L75), [Commands.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5), [README.md](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/README.md#L127)

## Integration
- **[HIGH]** — The tab integration plan still does not match the current tab contract. The live UI is driven by `C.TABS` IDs and resolves content directly from `VoxGM.Tabs[tabDef.id]`; the spec’s `Tabs/GMModeTab.lua`, `NPCOpsTab.lua`, `TabController.lua`, and renamed modules imply replacing that binding model, not extending it. Evidence: [Constants.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Constants.lua#L31), [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L518), [Modules/Tab_Appearance.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L1), [Modules/Tab_CNPC.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_CNPC.lua#L1)
- **[MEDIUM]** — Companion-addon integration is still only partially verifiable from this repo. I could confirm publishable addons for `CreatureCodex` and `VoxSniffer`, but not publishable `VoxTip` or `VoxPlacer` addon folders under `tools/publishable`. The spec should not promise first-class launch hooks for repo-external or unpublished addons without a fallback UX. Evidence: [CreatureCodex.toc](/C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.toc#L1), [VoxSniffer.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.toc#L1), [doc/session_state.md](/C:/Users/atayl/VoxCore/doc/session_state.md#L31), [doc/session_state.md](/C:/Users/atayl/VoxCore/doc/session_state.md#L223)

## Design
- **[HIGH]** — The Search/Explorer requirements remain architecturally contradictory. The spec requires searchable Items and Spells while also forbidding large shipped datasets and acknowledging no DB access. The live addon ships only small static tables for presets/races/slots/CVars; there is no item/spell corpus in the repo to support the promised search scopes. This is still underspecified to the point of likely non-implementability. Evidence: [README.md](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/README.md#L133), [README.md](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/README.md#L136), [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc#L18)
- **[HIGH]** — Script throttling is still treated as optional even though the current addon already staggers multi-command operations to avoid race conditions. Existing features like GM-mode sequences and “Hide All” use `C_Timer.After`, and the README explicitly documents staggered sends as necessary. A scripts system that defaults to same-frame dispatch is inconsistent with the repo’s own reliability model. Evidence: [Modules/Tab_GM.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_GM.lua#L75), [Modules/Tab_Appearance.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L140), [README.md](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/README.md#L155)
- **[MEDIUM]** — The command/response correlation story is still not credible at the architecture level. The live addon records outgoing commands to history with a timestamp/source, while inbound state sync is just global `CHAT_MSG_SYSTEM` parsing. That is enough for best-effort state updates, but not enough for the spec’s implied per-command console correlation when responses can interleave or never arrive via that event. Evidence: [Modules/History.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/History.lua#L16), [Modules/History.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/History.lua#L19), [Events.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L13), [Events.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L29), [Events.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L64)

## Verification
- **[MEDIUM]** — The spec still promotes client API assumptions to acceptance criteria without repo-level verification. The only confirmed `C_AddOns` usage in the live addon is `GetAddOnMetadata`; I found no existing proof in this codebase for `Settings.RegisterCanvasLayoutCategory`, `Bindings.xml`, or the specific addon-detection API surface the spec mandates. Those should be prerequisite client spikes, not unconditional architecture commitments. Evidence: [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L4), [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc#L1)

## Scope
- **[LOW]** — The spec still uses “copy” language for the console without defining the WoW-safe interaction model. In this addon, input/output is built entirely around native frames and chat dispatch; promising “copy” without explicitly meaning edit-box selection flow still risks implementers targeting a nonexistent clipboard API. Evidence: [README.md](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/README.md#L127), [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L35)

Since prior rounds, the spec has improved materially in structure: it now has a phased implementation order, explicit constraints, more detailed data flow, and clearer acceptance criteria. Those additions make the intent easier to review, but they did not resolve the core repo-awareness problems: the plan is still shaped like a rewrite rather than an additive extension of the live addon, the item/spell search feature is still not backed by a feasible data source, and several client/API assumptions remain unverified.

**VERDICT: FAIL**

---

### Round 5: Gemini (Phase 3)

This review of the Round 5 artifact for the VoxGM v2.0 Phased Enhancement Architecture Specification reveals a critical process failure. The specification appears to be an identical resubmission of the document that failed multiple prior review rounds. None of the critical, high, or medium severity findings from previous audits by Codex, Gemini, or Claude have been addressed. The document remains fundamentally disconnected from the existing v1 codebase, contains unverified assumptions about the target client's API, and specifies features with critical security vulnerabilities and unresolved implementation contradictions.

### Correctness
*   **[CRITICAL]** Unverified Core API Assumptions — The specification mandates the use of several modern WoW APIs (`Settings.RegisterCanvasLayoutCategory`, the `C_AddOns` namespace, `ScrollingMessageFrame`) whose existence and behavior on the custom 12.x Midnight client are unconfirmed. Basing core acceptance criteria on unverified APIs is a critical risk that could render entire features unimplementable. These APIs must be validated in a technical spike *before* being included in an architectural specification.
*   **[HIGH]** Unresolvable Search Data Source — The requirement to implement free-text search for items and spells (Section 3.5) directly contradicts the constraint against shipping large datasets. The WoW client API does not provide a mechanism to search the entire game database without a pre-built index, which the spec forbids. This core feature is architecturally infeasible as specified and will fail implementation.
*   **[HIGH]** Flawed Command/Response Correlation Model — The spec repeatedly assumes that client-sent commands can be reliably correlated with asynchronous server responses arriving via `CHAT_MSG_SYSTEM` (Section 5.7). This is a technically unsolved problem in the WoW API without server-side support (e.g., command echo tokens). The architecture presents this as a given, which is misleading and will lead to a brittle or non-functional console feature.
*   **[HIGH]** SavedVariables Migration Ignores Type Conflicts — The migration strategy (Section 3.2) is purely additive, only copying missing defaults. It does not account for cases where a key exists in v1 data but with a data type that conflicts with the v2 schema (e.g., `v1.ui = true`, `v2.ui = {}`). This will cause runtime Lua errors for upgrading users and constitutes a data integrity failure.
*   **[MEDIUM]** Console Event Filtering is Undefined — The console is specified to listen to `CHAT_MSG_SYSTEM` (Section 5.6), which captures a large volume of messages unrelated to GM commands (e.g., loot, system notices). The spec provides no logic or strategy for filtering these messages, which will result in a noisy and unusable console.

### Security
*   **[CRITICAL]** Command Injection Vulnerability in Scripts — The script validation logic (Section 5.13) only checks for a leading `.` or `/`, completely ignoring the risk of command injection within parameters. A malicious imported script with a line like `.teleport "location; .gobject delete 12345; teleport"` could execute destructive commands. The `CommandDispatcher` or `ScriptRunner` MUST sanitize or validate the entire command string, not just the prefix. This is a severe, unaddressed vulnerability.
*   **[HIGH]** Unsafe Script Import/Export Format — The specification for a "plain-text portable block" (Section 5.15) is dangerously vague. Without mandating a simple, non-executable, line-based format, an implementer could choose a format (e.g., serialized Lua) vulnerable to exploitation from malformed import strings, leading to client errors or unintended code execution.
*   **[HIGH]** Mandatory Script Throttling is Missing — The spec treats command throttling for scripts as optional ("if throttling becomes necessary," Section 5.14), which is a stability and server-health risk. Sending a rapid burst of commands can cause server-side issues, character state corruption, or disconnects. Given the addon's purpose, a non-zero, mandatory delay between script commands must be architecturally required.

### Architecture
*   **[HIGH]** Specification Proposes a Rewrite, Not an Enhancement — The proposed file structure (Section 4) and implementation phases (Section 8) describe a wholesale replacement of the existing addon's core systems (bootstrap, state management, command dispatch, tab registration). This directly contradicts the stated goals of "backwards-compatible enhancement" and "prefer additive file creation" (Section 6). The spec is fundamentally disconnected from the v1 codebase it claims to enhance, rendering it an unreliable guide for implementation.
*   **[MEDIUM]** Ambiguous Module Responsibilities — The spec creates confusing overlaps in responsibility between proposed modules, such as `VoxGM.lua` vs. `Core/Bootstrap.lua` for startup, and `Core/SavedVariables.lua` vs. `Data/Defaults.lua` for default settings. This ambiguity will lead to implementation errors and poor separation of concerns.
*   **[MEDIUM]** Inconsistent and Vague Requirements — The spec contains inconsistencies between acceptance criteria and implementation phases (e.g., model preview tab integration) and uses undefined jargon ("DMS-style", "mixin-style") that makes requirements unclear for an implementer. The continued reference to a non-existent `VoxGM.xml` file is also misleading.

---
**VERDICT: FAIL**

---

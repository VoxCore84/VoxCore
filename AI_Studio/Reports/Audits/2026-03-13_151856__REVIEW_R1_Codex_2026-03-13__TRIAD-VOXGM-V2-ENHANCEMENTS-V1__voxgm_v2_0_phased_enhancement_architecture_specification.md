---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 1
reviewer: Codex
model: gpt-5.4
date: 2026-03-13T15:18:56.234215
elapsed_seconds: 172.2
---

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
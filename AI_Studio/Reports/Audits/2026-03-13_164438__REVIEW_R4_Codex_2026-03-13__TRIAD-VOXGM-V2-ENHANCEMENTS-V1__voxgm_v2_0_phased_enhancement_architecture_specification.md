---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 4
reviewer: Codex
model: gpt-5.4
date: 2026-03-13T16:44:38.662552
elapsed_seconds: 165.3
---

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
---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 1
reviewer: Codex
model: gpt-5.4
date: 2026-03-13T16:10:06.997202
elapsed_seconds: 282.8
---

**Architecture**

**[HIGH]** The companion-launch contract is not implementable as written for all declared companions. The spec’s data model only stores `slashCmd`, but the launcher design explicitly calls `SlashCmdList[key]("")`, which requires the actual registry key, not the slash text. That key is not derivable in general and is not present in the proposed `Data\CompanionAddons.lua` schema. This is acceptance-critical because AC10 requires correct Open-button behavior for all four companions. The repo verifies `VOXSNIFFER`, `VOXPLACER`, and `CREATURECODEX`, but not `VOXTIP`. See [addons/VoxPlacer/VoxPlacer.lua](/C:/Users/atayl/VoxCore/addons/VoxPlacer/VoxPlacer.lua#L853), [addons/VoxSniffer/VoxSniffer.lua](/C:/Users/atayl/VoxCore/addons/VoxSniffer/VoxSniffer.lua#L217), [tools/publishable/CreatureCodex/client/CreatureCodex.lua](/C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1032).

**[MEDIUM]** The spec preserves an existing bad boundary: default parser registration currently happens inside `UI:Init()`, not `Events:Init()`. That means event parsing is unavailable until `PLAYER_LOGIN` and until the UI module initializes, even though `CHAT_MSG_SYSTEM` is registered earlier on `ADDON_LOADED`. Extending the event pipeline without fixing that ownership keeps an avoidable init race in place. See [Events.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L13), [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332), [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L28).

**[MEDIUM]** `Cmd:SendSequence()` is specified as a `Commands.lua` API, but its implementation is described as directly storing state in `Scripts.runState`. That inverts ownership and creates needless coupling between the low-level command dispatcher and the higher-level scripts subsystem. The cleaner boundary is `Scripts` owning sequencing and calling `Cmd:SendCommand()`. The current spec creates a circular design without a good reason. Relevant existing dispatcher boundary: [Commands.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5).

**Integration**

**[MEDIUM]** Conditional features are not guarded consistently in the proposed interfaces. The spec says model preview and settings are conditional on the Phase 0 spike, but the sample slash dispatcher calls `VoxGM.ModelPreview:Show(id)` directly and the sample `PLAYER_LOGIN` path includes `VoxGM.ModelPreview:Init()`. If the spike fails and the module is omitted, those call sites will nil-deref unless the final design adds guards everywhere. Current slash handling is centralized in [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L52), so this needs to be explicit in the contract.

**[MEDIUM]** The console “Copy Line” requirement is underspecified against the chosen widget. A `ScrollingMessageFrame` is fine for append-only output, but the spec does not define how a specific clicked line becomes selectable text; `ScrollingMessageFrame` does not inherently expose per-line click targets. Without an explicit line-model or overlay-row design, this is an incomplete UI contract, not just an implementation detail. The existing UI is widget-helper based, not line-virtualized, in [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L1).

**Verification**

**[LOW]** The artifact’s inventory is slightly inaccurate. The actual publishable addon tree in this repo is under `tools/publishable/VoxGM`, not `addons/VoxGM`, and it contains 24 files total in this workspace, not 25. The loaded-file count of 22 from [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc) is correct, and there are no XML files today.

**[LOW]** Several source-backed claims are correct and should stay, but a few are overstated as “verified.” The existing migration backfill loops do exist at [State.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua#L57), integer-only slider behavior exists at [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68), `UISpecialFrames` registration exists at [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L428), and the `.wmorph` field exists at [Modules/Tab_Appearance.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L31). By contrast, VoxTip verification is not possible from the repo contents provided.

**Design**

**[LOW]** The spec’s additive migration plan matches the current state system well, but it should explicitly say new nested tables must also be validated at write time, not only during migration. The existing code prunes history/favorites structurally during migration and enforces caps during normal writes in [Modules/History.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/History.lua#L8) and [Modules/Favorites.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Favorites.lua#L13); scripts/console should follow that same full lifecycle pattern.

**Scope**

**[INFO]** The spec is generally well-scoped against the current addon. The zero-dependency constraint, additive TOC growth, existing module pattern, current slash-command minimalism, sanitization routine, and current staggered-command usage all match the live code in [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua), [Util.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Util.lua#L76), and [Modules/Tab_Appearance.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L133).

No prior-round implementation artifact was provided in this review thread, so there is no code delta to summarize since earlier rounds. This review is based on the Revision 3 spec compared against the current repo state.

**VERDICT:** FAIL
---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 4
reviewer: Codex
model: gpt-5.4
date: 2026-03-13T16:12:46.533388
elapsed_seconds: 159.5
---

**Architecture**
- **[HIGH]** — The script-runner ownership is still split across two modules. Section 6 says `Commands.lua` adds `Cmd:SendSequence()` that writes into `Scripts.runState`, while Section 7.7 makes `Scripts:Run()` the canonical runner. That keeps the same boundary problem from prior rounds: the low-level dispatcher now depends on higher-level script state instead of `Scripts` owning sequencing and calling `Cmd:SendCommand()`. The current dispatcher is intentionally narrow in [Commands.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua), and this spec still muddies that boundary.
- **[MEDIUM]** — The parser-init race is not actually resolved in the architecture. The live addon registers `CHAT_MSG_SYSTEM` in [Events.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua), but the built-in parsers are still registered from `UI:Init()` in [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua), after `Events:Init()` is called from [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua). The revised spec documents the event pipeline, but it still does not explicitly move default parser ownership into `Events`, so the bad init boundary remains.
- **[MEDIUM]** — Conditional modules are still not guarded consistently. The spec says model preview and settings are contingent on the Phase 0 spike, but its sample slash dispatcher and `PLAYER_LOGIN` init path still call `VoxGM.ModelPreview` directly. In the current addon, slash dispatch is centralized in [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua); without explicit nil-safe guards, this is still an implementation trap.

**Integration**
- **[HIGH]** — The companion-launch contract is still not fully repo-verified for all four required addons. The slash registrations for CreatureCodex, VoxSniffer, and VoxPlacer are present in [CreatureCodex.lua](/C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua), [VoxSniffer.lua](/C:/Users/atayl/VoxCore/addons/VoxSniffer/VoxSniffer.lua), and [VoxPlacer.lua](/C:/Users/atayl/VoxCore/addons/VoxPlacer/VoxPlacer.lua). But there is no `addons/VoxTip/VoxTip.lua` in this workspace, and `Get-ChildItem` against [addons/VoxTip](/C:/Users/atayl/VoxCore/addons/VoxTip) returned nothing. AC10 still requires correct Open-button behavior for VoxTip, so the spec’s “grounded in verified slash commands” claim is overstated and acceptance-critical.
- **[HIGH]** — The companion UI contract is still internally inconsistent. Section 7.9 says an “Installed” addon shows a disabled Open button, while AC10 says “Installed” means no button. That is the same acceptance-level contradiction raised previously, and it still blocks a deterministic implementation.
- **[MEDIUM]** — Section 7.9 still writes runtime status back into the static metadata entries (`addon.status = ...`). That mixes runtime state with data loaded from `Data\CompanionAddons.lua` and weakens separation of concerns. The cleaner contract is a runtime state table owned by `Companions.lua`, not mutation of the data registry.

**Verification**
- **[MEDIUM]** — The console “Copy Line” contract is still incomplete against the chosen widget. The spec now says a hidden `EditBox` is populated with the clicked line’s text, but it still never defines how a specific line in a `ScrollingMessageFrame` becomes clickable or addressable. The live UI toolkit in [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua) has no existing per-line virtualization pattern to inherit here, so this is still an underspecified integration point.
- **[LOW]** — The artifact’s verification language is stronger than the repo evidence. It is fair to say the launch contract is repo-verified for CreatureCodex, VoxSniffer, and VoxPlacer; it is not fair to say that for VoxTip based on this workspace.

**Design**
- **[MEDIUM]** — The script data model is still ambiguous. Section 7.6 defines each script as `{name, description, lines[], enabled}`, which reads like a per-script flag, but Section 7.7 says execution “collects enabled lines,” which implies per-line enable state. Those are different schemas, and CRUD/import/export behavior depends on which one is intended.
- **[MEDIUM]** — Console persistence is still only partially specified. The spec covers migration cleanup for `console.persistedLines`, but it still does not define the normal-session lifecycle: when `PLAYER_LOGOUT` saves the buffer, where the 50-line cap is enforced at write time, or what happens when `persistHistory` is toggled from true to false after migration. The existing addon does enforce write-time caps for comparable stores in [History.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/History.lua) and [Favorites.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Favorites.lua); this new store should be specified to the same standard.
- **[LOW]** — The migration pseudocode still uses inconsistent copy semantics: `console` and `scripts` deep-copy table defaults, while `companions` assigns `v` directly. That is harmless with the current `showPanel = true`, but it is an avoidable future footgun and makes the migration pattern less coherent.

**Scope**
- **[LOW]** — This Round 4 spec still depends on unresolved Phase 0 spike outcomes for settings, bindings, and model preview behavior. The repo-level `doc/` directory claim is verified at [doc](/C:/Users/atayl/VoxCore/doc), but the spec remains partly provisional rather than fully implementation-ready.

Revision 3 does improve several areas from prior rounds: it removes the dead throttled-command API, clarifies that console display is chronological only, adds import-metadata sanitization, correctly points to `GetAddOnInfo`/`IsAddOnLoaded` for three-state detection, and grounds three companion slash registrations in actual repo code. The remaining blockers are the same class of issues the earlier reviews identified: one acceptance-critical companion remains unverified, the companion UI contract is still contradictory, the script-runner boundary is still split between `Commands` and `Scripts`, and the console click/copy interaction is still not specified concretely enough to implement safely.

**VERDICT: FAIL**
---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 4
reviewer: Codex
model: gpt-5.4
date: 2026-03-13T16:57:38.007915
elapsed_seconds: 163.1
---

**Architecture**
- **[CRITICAL]** — The artifact is still internally inconsistent about the script runner timer handle. The revision notes say “DispatchNext redundant nil-clear removed,” but Section 7.7 still includes `runState.timerHandle = nil` inside the timer callback. That leaves the implementer with two conflicting instructions for the same control path.
- **[HIGH]** — The settings API contract is still broken. The slash handler calls `VoxGM.Settings:Open()`, but the Core changes only add `Console`, `Scripts`, `Companions`, and `ModelPreview` namespaces. The current addon only defines the v1 namespaces in [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L7) and `VoxGM.Data` at [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L14); there is no existing `Settings` namespace to absorb that call. If the implementer follows the spec literally, `/vgm settings` can still dereference `nil`.
- **[HIGH]** — Script name identity is still undefined. The spec describes save/import/overwrite/run flows, but never states whether `MyScript` and `myscript` are the same script. That ambiguity affects uniqueness checks, overwrite behavior, lookup for `Scripts:Run(scriptName)`, and UI expectations. This is an API-contract gap, not an implementation detail.

**Integration**
- **[MEDIUM]** — The fallback settings-panel path is still underspecified against the actual UI controller. The current UI pre-creates tab scrollframes under `contentHost` in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L471) and switches them through `UI:SelectTab()` at [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L572). The artifact says the settings panel “replaces the main frame content area” and has a Back button, but it still does not define how existing scrollframes are hidden, whether `activeTabId` is preserved, or how Back restores the previous tab state.
- **[MEDIUM]** — Path B still depends on a nonexistent widget helper. The spec says the in-addon settings panel uses existing `UI:CreateSlider`, `UI:CreateToggleButton`, and `UI:CreateEditRow`, but the actual helpers are `CreateSlider` at [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68), `CreateToggleButton` at [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L118), and `CreateDropdown` at [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L161). There is no `CreateEditRow` helper in the repo.

**Verification**
- **[MEDIUM]** — The companion-addon verification is still overstated. I verified `SlashCmdList["CREATURECODEX"]` in [CreatureCodex.lua](C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1034) and `SlashCmdList["VOXSNIFFER"]` in [VoxSniffer.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.lua#L219). But `tools/publishable/VoxTip` and `tools/publishable/VoxPlacer` do not exist in this workspace, so those entries are not repo-verified facts.
- **[LOW]** — The Phase 0 documentation path is still inconsistent. The artifact says `VoxCore/doc/voxgm_api_spike.md`, but from the repo root `C:\Users\atayl\VoxCore` the actual docs directory is just `doc/`. This should be normalized to `doc/voxgm_api_spike.md`.

**Design**
- **[MEDIUM]** — The delete-popup contract is still fragile. The spec passes a numeric array index through `StaticPopup_Show(..., scriptIndex)` and then deletes by `table.remove(db.scripts.items, index)`. That index can go stale if the list mutates before confirmation. The current addon’s persisted collections are simple arrays as seen in [Favorites.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Favorites.lua#L49), so this needs an explicit stable-identity strategy.
- **[MEDIUM]** — The console buffer trimming strategy remains unnecessarily expensive. The artifact still uses `table.remove(lineBuffer, 1)` for overflow and repeated front-removal when shrinking `maxLines`. That is O(n) per removal and is weaker than existing repo cap patterns, where history removes from the tail after front insertion in [History.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/History.lua#L16) and [History.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/History.lua#L24).

**Scope**
- **[INFO]** — Several source-backed claims remain correct: the addon is TOC-driven with 22 loaded entries in [VoxGM.toc](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc#L12), `RegisterDefaultParsers()` is currently called from `UI:Init()` at [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332) instead of `Events:Init()` at [Events.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L8), and `Util:SanitizeText()` does strip `[%c|;]` in [Util.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Util.lua#L76).

Summary since prior rounds: Revision 5 did fix several concrete gaps from earlier reviews: it now specifies the console host as UI-owned, defines the fallback settings path instead of leaving it absent, makes `enabled` default `true`, documents the `StaticPopup_Show` data argument, reverses script pruning to keep newest entries, and keeps the TOC count and `VoxGM.Data` claim aligned with the repo. The remaining problems are narrower, but they are still material: one internal contradiction, one still-broken `Settings` facade, one unresolved script-name contract, and a few integration/details issues around settings, companion verification, and popup identity.

**VERDICT: FAIL**
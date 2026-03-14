---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 1
reviewer: Codex
model: gpt-5.4
date: 2026-03-13T16:54:54.907156
elapsed_seconds: 197.1
---

**Architecture**

- **[HIGH]** The settings API contract is internally broken. The proposed slash handler calls `VoxGM.Settings:Open()`, but the Core changes only add `Console`, `Scripts`, `Companions`, and `ModelPreview` namespaces, not `Settings`, and the Settings section does not require a stable `Open()` facade for both Path A and Path B. In the current addon, the namespace block is only the v1 set in [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L7), and there is no existing Settings module to absorb that call. If an implementer follows the spec literally, `/vgm settings` can dereference `nil`.

- **[MEDIUM]** The fallback settings-panel design is not aligned with the current UI ownership model. The addon currently pre-creates tab scrollframes under `contentHost` in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L471) and switches them through `UI:SelectTab()` in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L572). The spec says the settings panel “replaces the main frame content area” and behaves like a tab, but it does not define whether it hides those existing scrollframes, how it preserves `activeTabId`, or how `Back` restores the prior tab state. That leaves an integration gap in the core view-controller contract.

**Integration**

- **[MEDIUM]** Path B depends on a widget helper that does not exist. The spec says the in-addon settings panel uses existing `UI:CreateSlider`, `UI:CreateToggleButton`, and `UI:CreateEditRow`, but [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L22), [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L39), [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68), [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L118), and [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L161) define button/editbox/slider/toggle/dropdown helpers only. There is no `CreateEditRow` helper in the repo, so the spec currently references a broken dependency.

- **[LOW]** The Phase 0 documentation path is inconsistent with the repo layout. The artifact says to document results in `VoxCore/doc/voxgm_api_spike.md`, but from the current repo root `C:\Users\atayl\VoxCore`, the existing docs directory is `doc/`, and `VoxCore/doc` does not exist. This should be normalized to `doc/voxgm_api_spike.md`.

**Verification**

- **[MEDIUM]** The companion-addon verification claims are only partially supported by the repo. I verified `SlashCmdList["CREATURECODEX"]` in [CreatureCodex.lua](C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1034) and `SlashCmdList["VOXSNIFFER"]` in [VoxSniffer.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.lua#L219). I could not verify VoxTip or VoxPlacer because `tools/publishable/VoxTip` and `tools/publishable/VoxPlacer` are not present in this workspace. The spec should not present those keys as verified source-backed facts.

- **[INFO]** Several source-backed claims in the artifact are correct:
  - TOC load count and ordering are accurate in [VoxGM.toc](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc#L12).
  - `VoxGM.Data = {}` exists in [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L14).
  - The parser-registration bug is real: `RegisterDefaultParsers()` is currently called from [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332), while the parser definitions live in [Events.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L67).
  - The current `contentHost` anchor and `UISpecialFrames` registration match the artifact in [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L393) and [UI.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L428).
  - `Cmd:SendCommand()` remains the single-command path in [Commands.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5).

**Design**

- **[LOW]** The script-overwrite popup contract is underspecified. Delete passes the array index as `self.data`, but overwrite passes only the imported script table and then says `ConfirmOverwrite(importedScript)` “replaces the existing entry.” The spec never states whether replacement is by name lookup or by stored index. That is fixable, but the API contract should be explicit.

- **[LOW]** The “secondary validation” for semicolon-joined commands is weak as written. Checking only for `" ."` or `" /"` after sanitization will miss common malformed cases like `.cmd1;.cmd2` becoming `.cmd1.cmd2` with no intervening space. If this warning is meant to mitigate a known failure mode, the heuristic needs tightening or the warning should be described as partial only.

**Scope**

- **[INFO]** The artifact stays consistent with the current addon’s extension strategy: the v1 file layout is flat and TOC-driven, the current slash handler is minimal in [Core.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L52), state migration is additive in [State.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua#L42), and `Tab_Appearance.lua` is a reasonable integration point for preview work in [Tab_Appearance.lua](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L27).

**Summary Since Prior Rounds**

This is Round 1 of my review against Revision 5, so I do not have prior-round fixes in this review thread to validate directly. Relative to the artifact itself, Rev5 does show evidence of prior cleanup and source-aware corrections, and most of its v1 inventory claims match the repo; the remaining issues are concentrated in cross-file contracts that are still not fully closed, especially the Settings API and a few verification/dependency claims.

**VERDICT: FAIL**
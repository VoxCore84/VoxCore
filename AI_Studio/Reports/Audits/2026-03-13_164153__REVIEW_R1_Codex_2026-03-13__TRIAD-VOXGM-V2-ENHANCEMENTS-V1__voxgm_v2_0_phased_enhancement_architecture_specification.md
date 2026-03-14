---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 1
reviewer: Codex
model: gpt-5.4
date: 2026-03-13T16:41:53.313850
elapsed_seconds: 163.3
---

## Architecture

**[HIGH]** The console integration contract is still internally inconsistent at init time. The spec says `UI.lua` owns the console geometry and must change the content-host anchor chain during `UI:Init()`, but it also keeps `Console:Init()` after `UI:Init()` in `Core.lua`. In the current addon, `PLAYER_LOGIN` initializes `UI` before any new v2 modules at [Core.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L38), and the existing frame/layout is built entirely inside `UI:Init()` at [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L330). As written, `UI:Init()` cannot reliably anchor to a divider/console frame that `Console.lua` has not created yet. This needs an explicit ownership fix: either initialize `Console` before `UI`, or make `UI` create the divider/host and let `Console` only populate it, or require `Console:Init()` to perform the initial re-anchor.

## Verification

**[MEDIUM]** The spec’s v1 inventory is not fully accurate: it says the TOC loads 22 files, but the actual `VoxGM.toc` contains 21 loaded entries, from `Core.lua` through `Modules\Tab_DevTools.lua`, at [VoxGM.toc](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc). This is not implementation-breaking by itself, but it is a repo-verification miss in a document that explicitly claims to be grounded in the current codebase.

**[MEDIUM]** The companion verification section overstates the quality of evidence for some launch keys. `CREATURECODEX` and `VOXSNIFFER` are verified in actual addon source at [CreatureCodex.lua](/C:/Users/atayl/VoxCore/tools/publishable/CreatureCodex/client/CreatureCodex.lua#L1032) and [VoxSniffer.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxSniffer/VoxSniffer.lua#L217). `VOXPLACER`, however, is only evidenced in a notebook dump at [addon_VoxPlacer.lua.txt](/C:/Users/atayl/VoxCore/doc/notebooklm/addon_VoxPlacer.lua.txt#L853), not in a publishable/source addon tree like the others, and `VOXTIP` is explicitly outside the repo. Because the launch contract depends on exact `SlashCmdList` keys, the spec should distinguish source-verified companions from externally verified or documentation-derived ones instead of presenting them as equivalently verified.

## Design

**[LOW]** The `UI:CreateSlider` change is specified with illustrative code that is not valid Lua as written: `string.format("%.Nf", value)` cannot work without constructing the format string dynamically. Since this section mixes prose with code-like prescriptions, that should be clarified to avoid implementer copy/paste errors. Relevant current slider implementation is at [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L68).

## Scope

**[INFO]** Revision 4 does appear to address several issues that earlier review rounds flagged: script sequencing is now correctly owned by `Scripts.lua` instead of `Commands.lua`, the companion data model now includes `slashCmdKey`, console persistence and `PLAYER_LOGOUT` are specified, parser-init ownership is aligned with the real v1 bug in [UI.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L332) and [Events.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L8), and the spec now matches the current single-command dispatch boundary in [Commands.lua](/C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5).

**VERDICT: FAIL**
---
artifact: 2026-03-13__TRIAD-VOXGM-V2-ENHANCEMENTS-V1__voxgm_v2_0_phased_enhancement_architecture_specification.md
round: 1
reviewer: Codex
model: gpt-5.4
date: 2026-03-13T15:48:09.277963
elapsed_seconds: 208.9
---

**Architecture**

**[HIGH]** — The companion-addon launch contract is not implementable as specified. A metadata record of `{ addonName, slashCmd }` is not enough to “open” another addon in WoW; slash text is not a generic callable API. The actual companion addons expose distinct slash-handler registrations such as [`VoxSniffer.lua`](C:/Users/atayl/VoxCore/addons/VoxSniffer/VoxSniffer.lua#L217), [`VoxPlacer.lua`](C:/Users/atayl/VoxCore/addons/VoxPlacer/VoxPlacer.lua#L853), and [`VoxCoreProfessions.lua`](C:/Users/atayl/VoxCore/addons/VoxCoreProfessions/VoxCoreProfessions.lua#L429). The spec needs an explicit per-addon launch contract, such as a known `SlashCmdList` key or exported global toggle function.

**[MEDIUM]** — The console design claims it can “reuse the existing `Events:RegisterParser` model” for filtered display, but the current parser API does not expose match metadata or classification. [`Events.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L25) only stores `{pattern, callback}`, and [`OnSystemMessage`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Events.lua#L29) just invokes callbacks. A console cannot know which parser matched, whether the message is interesting, or how to label it without introducing a new parser contract or duplicating regexes.

**Integration**

**[MEDIUM]** — The slash-command extension plan understates the amount of core parsing work required. The current handler in [`Core.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L49) lowercases the entire message and only branches on exact `reset` and `minimap`; everything else toggles the window. Supporting `/vgm scale 1.2`, `/vgm opacity 0.7`, `/vgm preview 123`, or `/vgm scripts` requires a real tokenizer/dispatcher, not a simple additive branch.

**[MEDIUM]** — “Mount the Console pane below the tab content area” is not just an additive insert into the current UI. [`UI.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L392) anchors one content host directly down to the status bar, and [`CreateTabContainers`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L471) builds every tab scroll frame to fill that host. Adding a collapsible lower pane means redefining frame geometry and scroll extents, not merely creating `Console.lua`.

**Verification**

**[LOW]** — The inventory claims are mostly accurate after reading the repo. The addon lives under [`tools/publishable/VoxGM/VoxGM.toc`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc), not the repo root; there are 25 files in that addon folder, 22 are loaded by the TOC, and there are currently no XML files.

**[LOW]** — The module-pattern statement is slightly overstated. Most files do use `local _, VoxGM = ...`, but [`Core.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Core.lua#L1) uses `local ADDON_NAME, VoxGM = ...`. That is minor, but the spec should describe the pattern as “namespace via addon varargs” rather than a single exact header.

**Design**

**[HIGH]** — The script runner design is internally contradictory: it mandates `C_Timer.After` sequencing and also promises mid-run cancellation via a “Stop” button. The existing staggered pattern in [`Tab_Appearance.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Modules/Tab_Appearance.lua#L136) uses fire-and-forget `C_Timer.After`, which does not give you handles to cancel. If cancellation is a requirement, the architecture needs cancellable timers or a token/queue worker model.

**[MEDIUM]** — The spec’s semicolon validation is ineffective as written. [`Util:SanitizeText`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Util.lua) already strips `;`, so a rule like “sanitize, then reject lines containing `;`” cannot catch anything. If the goal is to reject suspicious raw input instead of silently rewriting it, the check must happen before sanitization or compare raw vs sanitized values.

**[MEDIUM]** — State ownership for script throttle is inconsistent. Section 6 proposes new `ui`, `console`, `scripts`, and `companions` defaults, but Section 7 says throttle is stored in `VoxGMDB.console.scriptThrottle` even though that key is not defined in the proposed defaults. The current persisted schema in [`State.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/State.lua#L7) is very simple; this spec needs one clear home for throttle and one migration path.

**Scope**

**[INFO]** — The revised spec is better grounded than a greenfield rewrite: it correctly preserves the flat TOC-driven layout, the existing tab registration model in [`Constants.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Constants.lua) and [`UI.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/UI.lua#L471), the single-command dispatch path in [`Commands.lua`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/Commands.lua#L5), and the current SavedVariables name in [`VoxGM.toc`](C:/Users/atayl/VoxCore/tools/publishable/VoxGM/VoxGM.toc#L6).

No prior implementation rounds exist in this review context, so there is no code delta to compare against prior fixes. Relative to earlier, text-only architecture drafts, this revision is materially more grounded in the actual v1 addon layout and existing seams, but it still overstates how additive several v2 features are: companion launching, parser-backed console filtering, and cancellable scripted execution all require new contracts rather than straightforward file additions.

**VERDICT:** FAIL
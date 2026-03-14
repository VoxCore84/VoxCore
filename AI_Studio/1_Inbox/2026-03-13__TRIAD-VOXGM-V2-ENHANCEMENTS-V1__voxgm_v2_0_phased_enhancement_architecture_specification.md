---
spec_id: TRIAD-VOXGM-V2-ENHANCEMENTS-V6
title: VoxGM v2.0 Phased Enhancement Architecture Specification
status: Under Review (Revision 6)
priority: P1
date: 2026-03-13
architect: ChatGPT (v1) + Claude Code (v2-v6 revisions)
intended_implementer: Claude Code
workflow: VoxCore Triad
revision_notes: >
  Revision 6. Addresses all findings from five 5-round review cycles (25 rounds total).
  Key changes from R5: (CRITICAL) lineBuffer bulk-trim replaced with new-table slice (O(n)
  instead of O(n^2)), timer nil-clear kept in callback (revision note contradiction removed).
  (HIGH) VoxGM.Settings namespace added to Core.lua, script name case-insensitive policy
  defined, script deletion changed from index-based to name-based lookup (stale-index fix),
  shallow copy changed from unpack to explicit loop, Delete/Edit buttons disabled during
  active script run. (MEDIUM) Settings panel Back button saves/restores activeTabId,
  ClearAllPoints before re-anchor in SetConsoleVisible, CreateEditRow removed (use
  CreateEditBox), DEFAULTS.scripts.throttleDelay references C.SCRIPT_THROTTLE_DEFAULT,
  persistedLines trimmed to maxLines before loading, Copy Line stores message text in
  button data (not index), EnableMouseWheel(true) added, parsers must read VoxGMDB lazily,
  Console:Toggle reads VoxGMDB.ui.consoleEnabled as source of truth, onComplete consumer
  specified (re-enables Run button), Tab_Appearance.lua added to Section 6 modifications,
  TOC append order specified, companion verification status corrected (VoxTip/VoxPlacer
  marked assumed), Phase 0 doc path normalized.
---

# VoxGM v2.0 Phased Enhancement Architecture Specification (Revision 6)

## 1) Goal & Scope

Enhance VoxGM from v1.0.0 to v2.0.0 as a backwards-compatible, additive extension. New features added as new files appended to the TOC or in-place extensions. No structural rewrite, no directory reorganization, no external dependencies.

**In scope:** Output console, model preview for display IDs, saved command sequences ("scripts"), frame scale/opacity settings, keybinding support, companion Vox* addon detection, SavedVariables v2 migration.

**Conditionally in scope (requires Phase 0 API spike):** Native WoW Settings panel registration, Bindings.xml keybinds.

**Phase 0 design rationale:** The spec is written with conditional branches ("if Phase 0 confirms X, do Y; otherwise, do Z") so that each feature has a defined behavior regardless of API availability. The architecture does not assume any conditional API exists -- it gracefully degrades. Phase 0 is sequenced as the FIRST implementation step (before any code is written) specifically to resolve these branches. This is intentional phasing, not an oversight.

**Explicitly out of scope:** Free-text item/spell search, Ace3/external libs, ticket management, teleportation catalog, arbitrary Lua execution, OneWoW-style ecosystem framework, server-side TC modifications.

**Terminology:**
- **"Stretch goal"**: Implement if time allows after all required features. Not required for v2.0. Document as v2.1 candidate if not done.
- **"Top-level backfill"**: `State.lua:57-61` loop. Iterates `DEFAULTS`, adds missing top-level keys via `DeepCopy`.
- **"Per-key backfill"**: Loop iterating a sub-table of DEFAULTS (e.g., `DEFAULTS.ui`), adding missing sub-keys. Existing: `State.lua:62-67`.

## 2) Problem Statement

VoxGM v1.0.0 is functional but constrained by a chat-centric model: output fragmented across chat, display-ID workflows require alt-tabbing, multi-step GM operations are manual, no creature appearance preview. VoxGM v2 closes these gaps while preserving zero-dependency architecture.

## 3) Existing v1 Codebase Inventory

Addon at `tools/publishable/VoxGM/` (deployed to `C:\WoW\_retail_\Interface\AddOns\VoxGM\`). Flat TOC-driven layout. **22 files loaded by TOC** (verified: Core.lua through Modules\Tab_DevTools.lua = 22 entries in VoxGM.toc lines 12-36). No XML. Subdirectories: `Data\`, `Modules\`.

### TOC load order:
```
Core.lua, Constants.lua, Util.lua, State.lua, Commands.lua, Events.lua,
Data\Presets.lua, Data\Races.lua, Data\Slots.lua, Data\CVars.lua,
UI.lua, Minimap.lua, Compartment.lua,
Modules\PhaseTracker.lua, Modules\Favorites.lua, Modules\History.lua,
Modules\Tab_GM.lua, Modules\Tab_NPC.lua, Modules\Tab_Character.lua,
Modules\Tab_Appearance.lua, Modules\Tab_CNPC.lua, Modules\Tab_DevTools.lua
```

### Non-loaded: `LICENSE`, `README.md`

### Key existing patterns:
- **Module pattern:** Varargs namespace. Most: `local _, VoxGM = ...`; Core.lua: `local ADDON_NAME, VoxGM = ...`.
- **Sub-namespaces:** Core.lua declares `VoxGM.Data = {}` (line 14), `VoxGM.Util = {}`, `VoxGM.State = {}`, etc.
- **Tab registration:** `C.TABS` array + `VoxGM.Tabs[tabId]` in Tab_*.lua files.
- **Command dispatch:** `Cmd:SendCommand(cmdStr, source)` -- single path for all sends.
- **State management:** DEFAULTS + top-level backfill (`State.lua:57-61`) + per-key backfill (`State.lua:62-67`).
- **Event parsing:** `Events:RegisterParser(pattern, callback)`. Stores `{pattern, callback}` only.
- **Parser init (v1 bug):** Default parsers registered from `Events:RegisterDefaultParsers()` (defined at `Events.lua:67`), but CALLED from `UI:Init()` (inside `UI.lua`, on PLAYER_LOGIN). v2 MUST move this call into `Events:Init()` (ADDON_LOADED).
- **Text sanitization:** `Util:SanitizeText(str)` strips `[%c|;]`. `%c` covers `\n`/`\r`. **Semicolons safe for TC GM commands**: all TC commands use space-separated args. Stripping prevents command-chaining injection. Non-TC slash commands from other addons that use semicolons in args would be affected -- this is an accepted trade-off documented in Section 8.
- **Staggered commands:** Fire-and-forget `C_Timer.After`. NOT cancellable. Script runner uses different pattern.
- **Slider:** `UI:CreateSlider` rounds to integers (`math.floor(value + 0.5)` at UI.lua:107). Needs decimal extension.
- **UISpecialFrames:** v1 already registers `VoxGMFrame` at `UI.lua:428`. No change needed.
- **Content host:** `UI.lua:391-394` creates `self.contentHost` anchored TOPLEFT below tabs, BOTTOMRIGHT at `(C.STATUS_HEIGHT + 8)` offset from main frame bottom (above status bar).
- **Write-time caps:** v1 enforces caps in History.lua and Favorites.lua at write time. New stores MUST follow same pattern.
- **DeepCopy usage:** v1 State.lua uses a module-local alias pattern. The per-key backfill loops use the full path `VoxGM.Util:DeepCopy(v)`. Type guard blocks use the same. All v2 code MUST use the full path consistently.

## 4) Architectural Decisions

### 4.1 Zero-dependency, flat-file architecture preserved

### 4.2 Extend existing files, do not replace
`Core.lua`, `State.lua`, `Events.lua`, `UI.lua` extended in-place. `Commands.lua` NOT modified. Within files, individual functions may be replaced (e.g., the slash handler in Core.lua is fully rewritten, not patched).

### 4.3 SavedVariables migration via existing State:Migrate()
New DEFAULTS, schema bumps to 2. Top-level backfill adds new tables. Per-key backfill adds new sub-keys. Both run every load.

### 4.4 Console: passive, forwarded, UI-owned host
The console frame is created by `UI:Init()` as an empty container (the "console host") with a divider above it. `Console:Init()` populates this host with a ScrollingMessageFrame and overlay. This resolves the init-order dependency: UI creates the layout, Console fills it.

Messages arrive via nil-guarded forwarding from `Events:OnSystemMessage()`. Console:OnMessage(msg) adds timestamp, appends to both SMF and a parallel Lua table (`Console.lineBuffer[]`). Chronological display only -- no grouping.

**Copy Line:** Transparent overlay buttons positioned over visible SMF lines. Each button stores its corresponding message text directly in `button.messageText` (set at overlay rebuild time by reading from `Console.lineBuffer`). When user clicks, populates hidden EditBox with `button.messageText` and focuses it for Ctrl+C. The mapping from visible line position to lineBuffer index uses `smf:GetNumMessages()` (total messages added) minus scroll offset to compute the correct lineBuffer range. Overlay rebuilt via `smf:HookScript("OnMouseWheel", function() Console:RebuildOverlay() end)` and on `Console:Init()` and when console becomes visible. **Prerequisite:** `smf:EnableMouseWheel(true)` must be called before hooking `OnMouseWheel`, otherwise the event never fires. Object pooling recommended for overlay buttons.

Console does NOT suppress/redirect chat. Only `CHAT_MSG_SYSTEM` via Events.lua. Best-effort.

### 4.5 Model preview: honest about limitations
`SetDisplayInfo()` does not return errors. Invalid IDs render nothing or T-pose. Preview shows whatever the API renders + "DisplayID: X" label. No programmatic invalid-ID detection. When `ModelPreview:Show(id)` is called with a number, print `Util:Print("Previewing DisplayID: " .. id)` to confirm input was received. `PlayerModel` frame created once at init, shown/hidden. **DisplayID 0:** `tonumber("0")` returns `0`, which is falsy in Lua. The slash handler must use `id ~= nil` (not `if id then`) to distinguish "parsed a number" from "no argument". DisplayID 0 is passed to `SetDisplayInfo(0)` like any other ID.

### 4.6 Scripts: owned entirely by Scripts.lua
No Lua execution. Lines sanitized, dispatched through `Cmd:SendCommand()`. Cancellable recursive single-timer model. All sequencing state in Scripts.lua -- Commands.lua is NOT modified.

**Script name policy:** All name comparisons are **case-insensitive** (`name:lower()` before compare). Names are stored with their original capitalization. This affects: uniqueness checks on save, overwrite detection on import, lookup in `Scripts:Run(scriptName)`, and the delete-by-name search. Two scripts cannot coexist if their names differ only by case.

### 4.7 Companion detection: GetAddOnInfo, runtime state table
3-state logic. Runtime status in `VoxGM.Companions.status[addonName]`, NOT in static data table. Note: `VoxGM.Companions.status` is the full qualified path; shorthand `Companions.status` in this spec always refers to `VoxGM.Companions.status`.

### 4.8 Settings: two paths, both specified
**Path A (Phase 0 confirms API):** `Settings.lua` registers native WoW Settings category.
**Path B (API unavailable):** `Settings.lua` creates an in-addon settings panel accessed via `/vgm settings`. This panel is a frame similar to a tab content area, containing labeled sliders and toggles built with existing widget helpers:
- Scale: `UI:CreateSlider(parent, label, min, max, step, defaultVal, decimals)` with `decimals=1`
- Opacity: `UI:CreateSlider(...)` with `decimals=2`
- Minimap visible: `UI:CreateToggleButton(...)`
- Default tab: `UI:CreateDropdown(...)`
- Console enable: `UI:CreateToggleButton(...)`
- Console max lines: `UI:CreateSlider(...)` with `decimals=0` (integer)
- Script throttle: `UI:CreateSlider(...)` with `decimals=1`
- Persist history: `UI:CreateToggleButton(...)`

**Panel lifecycle:**
1. When opened (via `/vgm settings` or gear button), save current `UI.activeTabId` to `Settings.previousTabId`.
2. Hide all tab content scrollframes (iterate `VoxGM.Tabs`, hide each content frame).
3. Show settings panel frame (child of `contentHost`).
4. When "Back" is clicked: hide settings panel, restore the tab saved in `Settings.previousTabId` via `UI:SelectTab(Settings.previousTabId)`.

Both paths are fully specified -- the implementer builds one or the other based on Phase 0 results.

### 4.9 Search/Explorer: descoped to ID lookup + model preview

## 5) New Files

```
Console.lua              -- ScrollingMessageFrame, lineBuffer, Copy Line overlay, persistence
Scripts.lua              -- CRUD, validation, cancellable runner, import/export, StaticPopup defs
Companions.lua           -- Detection, runtime status, launch buttons
Data\CompanionAddons.lua -- Static metadata (addonName, label, slashCmdKey, description)
Settings.lua             -- Path A: native Settings category, OR Path B: in-addon settings panel
```

If Phase 0 confirms Bindings.xml:
```
Bindings.xml             -- Keybinding declarations
```

Conditional: `ModelPreview.lua` included only if Phase 0 confirms `SetDisplayInfo` works.

**Total new files:** 5-7.

### TOC append order (after existing 22 entries):
```
Data\CompanionAddons.lua   -- data file, no dependencies beyond VoxGM.Data (from Core.lua)
Console.lua                -- depends on UI.lua (consoleHost), Events.lua
Scripts.lua                -- depends on Commands.lua, UI.lua, Util.lua
Companions.lua             -- depends on Data\CompanionAddons.lua, UI.lua
Settings.lua               -- depends on UI.lua (widget helpers, activeTabId)
ModelPreview.lua           -- conditional; depends on UI.lua
```

Load order rationale: `Data\CompanionAddons.lua` first (pure data, no init). `Console.lua` before `Scripts.lua` (no dependency, but console should be available for script status messages). `Companions.lua` after its data file. `Settings.lua` after all modules it configures. `ModelPreview.lua` last (conditional, standalone).

## 6) Modifications to Existing Files

### VoxGM.toc
- Bump `## Version: 2.0.0`
- Append new files in order specified in Section 5. ModelPreview.lua conditional. Bindings.xml conditional (if XML, goes before Lua files per WoW convention).

### Constants.lua
- Update `C.SCHEMA_VERSION` from 1 to 2 (existing constant, change value).
- Add: `C.CONSOLE_MAX_LINES_MIN = 100`, `C.CONSOLE_MAX_LINES_MAX = 2000`, `C.CONSOLE_HISTORY_CAP = 50`
- Add: `C.SCRIPT_THROTTLE_DEFAULT = 0.3`, `C.SCRIPT_THROTTLE_MIN = 0.1`, `C.SCRIPT_MAX_SAVED = 50`, `C.SCRIPT_LINE_CAP = 50`
- Add: `C.UI_SCALE_MIN = 0.5`, `C.UI_SCALE_MAX = 2.0`, `C.UI_OPACITY_MIN = 0.25`, `C.UI_OPACITY_MAX = 1.0`

### State.lua
- Extend DEFAULTS:
  ```lua
  ui = {
      -- v1 keys preserved --
      scale = 1.0,
      opacity = 1.0,
      consoleEnabled = true,
      consoleHeight = 150,
  },
  console = {
      maxLines = 500,
      showTimestamps = true,
      persistHistory = false,
      persistedLines = {},
  },
  scripts = {
      items = {},
      throttleDelay = C.SCRIPT_THROTTLE_DEFAULT,  -- references constant, not hardcoded
  },
  companions = {
      showPanel = true,
  },
  ```
  Script items schema: `{name: string, description: string, lines: string[], enabled: bool}`. `enabled` is **per-script** (not per-line). **Default value for new/imported scripts: `true`** (enabled by default).

- Migration `if ver < 2 then`:
  - Type guards for `console`, `scripts`, `companions` tables
  - Type guards for `ui.scale`, `ui.opacity`
  - `db.schemaVersion = 2`
- Per-key backfill (all use `VoxGM.Util:DeepCopy(v)` for table values):
  ```lua
  for k, v in pairs(DEFAULTS.console) do
      if db.console[k] == nil then
          db.console[k] = (type(v) == "table") and VoxGM.Util:DeepCopy(v) or v
      end
  end
  -- same pattern for scripts, companions
  ```
- Cleanup: `persistHistory == false` -> `persistedLines = {}`
- Validation: clamp `console.maxLines`, floor `scripts.throttleDelay` to `C.SCRIPT_THROTTLE_MIN`
- Script pruning at migration time AND at write time (reusable function):
  ```lua
  -- State.lua: reusable pruning function
  function State:PruneScripts(scriptList)
      if #scriptList > C.SCRIPT_MAX_SAVED then
          local start = #scriptList - C.SCRIPT_MAX_SAVED + 1
          local trimmed = {}
          for i = start, #scriptList do
              trimmed[#trimmed + 1] = scriptList[i]
          end
          return trimmed
      end
      return scriptList
  end
  ```
  Called from migration: `db.scripts.items = VoxGM.State:PruneScripts(db.scripts.items)`.
  Called from Scripts.lua on save: `db.scripts.items = VoxGM.State:PruneScripts(db.scripts.items)`.
  Then structural validation (type-check name, lines).

### Commands.lua
- **No v2 changes.** Single-command dispatcher. Scripts.lua calls `Cmd:SendCommand()` directly.

### Events.lua
- Move `Events:RegisterDefaultParsers()` call into `Events:Init()` (from UI:Init).
- **Parser closures must read `VoxGMDB` lazily** (at callback invocation time, not at registration time). Since `State:Init()` runs before `Events:Init()`, `VoxGMDB` is available at registration time, but parsers should still use `VoxGMDB` as an upvalue read at call time (not captured into a local at registration time) to avoid surprises if migration runs post-registration.
- Add console forwarding after parsers run:
  ```lua
  if VoxGM.Console and VoxGM.Console._initialized then
      VoxGM.Console:OnMessage(msg)
  end
  ```
  Only Console needs `_initialized` guard -- other modules not called from event handlers before PLAYER_LOGIN.

### UI.lua
- Apply saved scale/opacity on init.
- Add `UI:SetScale(scale)`, `UI:SetOpacity(opacity)` with clamping + persistence.
- Add `UI:SetConsoleVisible(enabled)`: **Must call `self.contentHost:ClearAllPoints()` before setting new anchor points** (WoW frame anchors accumulate -- calling `SetPoint` without clearing first stacks anchors, causing layout corruption). Updates anchor chain, persists `VoxGMDB.ui.consoleEnabled`. Called by `Console:Toggle()` -- Console does NOT write to `ui.*` directly.
- **Console layout (created by UI:Init):**
  1. Create divider frame (4px, child of main frame).
  2. Create console host frame (empty container, child of main frame). Store as `VoxGM.UI.consoleHost`.
  3. If `VoxGMDB.ui.consoleEnabled`:
     - `self.contentHost:ClearAllPoints()`. Set TOPLEFT (same as before), BOTTOMRIGHT to `divider TOPRIGHT`.
     - Divider anchors below contentHost.
     - Console host anchors from divider bottom to above status bar.
  4. If `consoleEnabled == false`:
     - `self.contentHost` keeps original anchor to status bar area.
     - Divider and console host created but hidden.
  5. `UI:SetConsoleVisible(bool)` toggles between states 3 and 4. Always calls `self.contentHost:ClearAllPoints()` before re-anchoring.
  Console:Init() later populates the console host with SMF + overlay.
- Extend `UI:CreateSlider` with `decimals` param (default 0 = integer rounding, existing behavior). When `decimals > 0`:
  ```lua
  local fmt = "%." .. decimals .. "f"
  slider:SetScript("OnValueChanged", function(self, value)
      valText:SetText(string.format(fmt, value))
      if container.onValueChanged then container.onValueChanged(value) end
  end)
  ```

### Core.lua
- Add sub-namespaces: `VoxGM.Console = {}`, `VoxGM.Scripts = {}`, `VoxGM.Companions = {}`, `VoxGM.ModelPreview = {}`, `VoxGM.Settings = {}`
- Register PLAYER_LOGOUT on existing event frame (`VoxGM.eventFrame`):
  ```lua
  frame:RegisterEvent("PLAYER_LOGOUT")
  -- in existing OnEvent handler, add:
  elseif event == "PLAYER_LOGOUT" then
      if VoxGM.Console and VoxGM.Console.OnLogout then
          VoxGM.Console:OnLogout()
      end
  ```
- PLAYER_LOGIN additions:
  ```lua
  VoxGM.Console:Init()
  VoxGM.Scripts:Init()
  VoxGM.Companions:Init()
  if VoxGM.ModelPreview and VoxGM.ModelPreview.Init then
      VoxGM.ModelPreview:Init()
  end
  ```
- Replace slash handler with tokenizer:
  ```lua
  SlashCmdList["VOXGM"] = function(msg)
      msg = strtrim(msg or "")
      local cmd, rest = msg:lower():match("^(%S+)%s*(.*)$")
      if not cmd then VoxGM.UI:Toggle(); return end

      if cmd == "reset" then
          VoxGM.State:ResetPosition()
          VoxGM.Util:Print("Window position reset.")
      elseif cmd == "minimap" then
          -- existing minimap toggle (unchanged) --
      elseif cmd == "scale" then
          local val = tonumber(rest)
          if val then VoxGM.UI:SetScale(val)
          else VoxGM.Util:Print("Usage: /vgm scale <0.5-2.0>") end
      elseif cmd == "opacity" then
          local val = tonumber(rest)
          if val then VoxGM.UI:SetOpacity(val)
          else VoxGM.Util:Print("Usage: /vgm opacity <0.25-1.0>") end
      elseif cmd == "preview" then
          if VoxGM.ModelPreview and VoxGM.ModelPreview.Show then
              local id = tonumber(rest)
              if rest == "" then
                  VoxGM.ModelPreview:Show(nil)  -- open panel, empty input
              elseif id ~= nil then
                  VoxGM.ModelPreview:Show(id)   -- id may be 0, which is valid
              else
                  VoxGM.Util:Print("Invalid DisplayID. Usage: /vgm preview [number]")
              end
          else VoxGM.Util:Print("Model preview not available.") end
      elseif cmd == "console" then
          if VoxGM.Console and VoxGM.Console.Toggle then
              VoxGM.Console:Toggle()
          end
      elseif cmd == "scripts" then
          VoxGM.Scripts:ShowUI()
      elseif cmd == "settings" then
          if VoxGM.Settings and VoxGM.Settings.Open then
              VoxGM.Settings:Open()
          else VoxGM.Util:Print("Settings not available.") end
      else VoxGM.UI:Toggle() end
  end
  ```

### Tab_Appearance.lua
- Add "Preview" button next to display ID input fields (Phase 3). Button calls `VoxGM.ModelPreview:Show(id)` with the current input value. Nil-guarded: `if VoxGM.ModelPreview and VoxGM.ModelPreview.Show then`.

## 7) Logic & Data Flow

### 7.1 Addon load
- `ADDON_LOADED`: `State:Init()`, `Events:Init()` (now includes `RegisterDefaultParsers()`).
- `PLAYER_LOGIN`: `UI:Init()` (creates main frame, contentHost, console host+divider), `Minimap:Init()`, `Favorites:Init()`, `History:Init()`, `PhaseTracker:Init()`, `Console:Init()` (populates console host), `Scripts:Init()`, `Companions:Init()`, `ModelPreview:Init()` (guarded).
- `PLAYER_LOGOUT`: `Console:OnLogout()`.

### 7.2 SavedVariables migration
As specified in Section 6 State.lua. Type guards, backfill, validation, pruning via `State:PruneScripts()` (newest kept), cleanup.

### 7.3 Console operation
**Init:** `Console:Init()` creates a ScrollingMessageFrame inside `VoxGM.UI.consoleHost` (the empty container created by UI:Init). Calls `smf:EnableMouseWheel(true)` (required for OnMouseWheel hook to fire). Calls `smf:SetMaxLines(VoxGMDB.console.maxLines)` once. Creates overlay button pool. If `persistHistory` is true, loads persisted lines -- **but first trims `persistedLines` to `min(#persistedLines, maxLines)` before loading** to prevent desync if maxLines was reduced between sessions. Sets `self._initialized = true`.

**OnMessage(msg):** Add timestamp prefix. Call `smf:AddMessage(formatted)`. Append raw `msg` to `Console.lineBuffer[]`. If `#lineBuffer > cap`, call `table.remove(lineBuffer, 1)` (single removal per message -- O(n) shift is acceptable at message-arrival rate; not a hot loop).

**Buffer management -- maxLines change (bulk trim):** `SetMaxLines(cap)` is called ONCE at init and again ONLY when the user changes `console.maxLines` via Settings. When `maxLines` changes mid-session, call `smf:SetMaxLines(newCap)` AND rebuild `lineBuffer` efficiently:
```lua
if #lineBuffer > newCap then
    local trimmed = {}
    local start = #lineBuffer - newCap + 1
    for i = start, #lineBuffer do
        trimmed[#trimmed + 1] = lineBuffer[i]
    end
    Console.lineBuffer = trimmed
end
```
This is O(n) instead of the O(n^2) `while table.remove(lineBuffer, 1)` loop. The new-table approach avoids repeated element shifting.

**Toggle:** `Console:Toggle()` reads `VoxGMDB.ui.consoleEnabled` as the source of truth for current state, then calls `VoxGM.UI:SetConsoleVisible(not VoxGMDB.ui.consoleEnabled)`. Does NOT write to `VoxGMDB.ui.*` directly -- `UI:SetConsoleVisible` handles persistence.

**Clear:** `smf:Clear()` + `wipe(Console.lineBuffer)`.

**Copy Line overlay:** Pool of transparent buttons. Positioned over visible SMF lines. Each button stores the message text directly: `button.messageText = Console.lineBuffer[computedIndex]` (set at rebuild time). `computedIndex` is calculated from `smf:GetNumMessages()` minus the scroll offset plus the visible line position. On click, `button.messageText` is copied to a hidden EditBox and focused for Ctrl+C. Rebuilt via `smf:HookScript("OnMouseWheel", function() Console:RebuildOverlay() end)` and on `Console:Init()` and when console becomes visible.

**Persistence:** `Console:OnLogout()`: if `persistHistory`, save last `C.CONSOLE_HISTORY_CAP` (50) entries from `lineBuffer` to `VoxGMDB.console.persistedLines`. If not `persistHistory`, set `persistedLines = {}`. On init, trim then load `persistedLines` into SMF. The 50-entry persistence cap is separate from the 100-2000 display buffer cap -- users should be aware that only the most recent 50 messages survive a relog.

**persistHistory toggle:** If user changes from true to false mid-session, immediately clear `VoxGMDB.console.persistedLines = {}`. If user changes from false to true mid-session, messages already in `lineBuffer` (accumulated while persistence was off) will be saved on logout. This is expected behavior -- the buffer is always live regardless of persistence setting.

**Hidden console:** When `consoleEnabled == false`, messages still accumulate in `lineBuffer` (buffer fills regardless of visibility). This is correct -- the console can be toggled visible later to see buffered messages.

### 7.4 Command dispatch
Single commands: `Cmd:SendCommand()`. Script sequences: `Scripts:Run()` -> recursive timer -> `Cmd:SendCommand()`. Commands.lua unchanged.

### 7.5 Model preview
Created once at `ModelPreview:Init()`. `ModelPreview:Show(id)`: nil id opens panel with empty input; numeric id (including 0) sets input + calls `SetDisplayInfo` + prints `Util:Print("Previewing DisplayID: " .. id)` to confirm input was received. 0.3s debounce. Shows "DisplayID: X" label. No programmatic error detection.

Access: AppearanceTab (required), `/vgm preview` (required), CNPC tab (stretch goal, v2.1 candidate).

### 7.6 Script authoring
Scripts stored in `VoxGMDB.scripts.items`. Each: `{name, description, lines[], enabled}`.

**`enabled` is per-script boolean, default `true`.** When false, `Scripts:Run()` shows "Script is disabled." Individual lines cannot be disabled.

**Script name policy:** Case-insensitive comparisons everywhere (see Section 4.6).

**Validation:** Lines must start with `.` or `/`, pass `Util:SanitizeText()`, max 255 chars. **Secondary validation after sanitization:** if a sanitized line contains ` .` or ` /` (space followed by command prefix), warn via `Util:Print` that the line may contain concatenated commands (this catches the case where `;` removal joins two commands, e.g., `.cmd1;.cmd2` becomes `.cmd1.cmd2`). Note: this heuristic is partial -- it catches space-separated concatenation but not all malformed joins. The warning is informational; the line is still stored.

**Deletion -- name-based lookup (not index):**
The delete confirmation passes the **script name** (not array index) through `StaticPopup_Show`. `ConfirmDelete(scriptName)` performs a case-insensitive name search to find and remove the entry:
```lua
function Scripts:ConfirmDelete(scriptName)
    local db = VoxGMDB.scripts.items
    for i = #db, 1, -1 do
        if db[i].name:lower() == scriptName:lower() then
            table.remove(db, i)
            break
        end
    end
    Scripts:RefreshUI()
end
```
This eliminates stale-index bugs from list mutation between popup show and confirm.

**Overwrite -- name-based lookup:**
`ConfirmOverwrite(importedScript)` finds the existing entry by case-insensitive name match and replaces it in-place:
```lua
function Scripts:ConfirmOverwrite(importedScript)
    local db = VoxGMDB.scripts.items
    for i, script in ipairs(db) do
        if script.name:lower() == importedScript.name:lower() then
            db[i] = importedScript
            break
        end
    end
    Scripts:RefreshUI()
end
```

**UI during active run:** When `Scripts.runState.active == true`, the Delete and Edit buttons for ALL scripts are disabled (greyed out). The Run button shows "Stop" instead. This prevents list mutation during execution and eliminates the stale-data class of bugs entirely.

**Write-time caps:** On save, enforce `C.SCRIPT_MAX_SAVED` via `VoxGM.State:PruneScripts()` and `C.SCRIPT_LINE_CAP` (per-script). Same pattern as History.lua / Favorites.lua.

**Empty scripts:** Zero lines = valid. Running shows "Script '[name]' has no commands."

**StaticPopup definitions** (registered at file scope in Scripts.lua):
```lua
StaticPopupDialogs["VOXGM_SCRIPT_DELETE"] = {
    text = "Delete script '%s'?",
    button1 = "Delete", button2 = "Cancel",
    OnAccept = function(self) VoxGM.Scripts:ConfirmDelete(self.data) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
StaticPopupDialogs["VOXGM_SCRIPT_OVERWRITE"] = {
    text = "Script '%s' already exists. Overwrite?",
    button1 = "Overwrite", button2 = "Cancel",
    OnAccept = function(self) VoxGM.Scripts:ConfirmOverwrite(self.data) end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}
```

**Calling the popups:**
- Delete: `StaticPopup_Show("VOXGM_SCRIPT_DELETE", script.name, nil, script.name)` -- 4th arg sets `self.data` to the script's **name** (string). `ConfirmDelete(name)` finds by name and removes.
- Overwrite: `StaticPopup_Show("VOXGM_SCRIPT_OVERWRITE", existingScript.name, nil, importedScriptTable)` -- `self.data` is the imported script table. `ConfirmOverwrite(importedScript)` finds existing by name and replaces.

**Note on double-click:** If the user triggers a second `StaticPopup_Show` for the same dialog while one is already visible, WoW returns the existing frame without updating `self.data`. Since we pass the script name (not a mutable index), this is safe -- the name is stable.

### 7.7 Script execution (cancellable recursive timer)
Owned entirely by Scripts.lua. Commands.lua NOT modified.

**Run state:**
```lua
Scripts.runState = {
    active = false,
    timerHandle = nil,
    commands = {},
    index = 0,
    scriptName = "",
    onComplete = nil,  -- consumer: Scripts UI re-enables Run button after natural completion
}
```

**`Scripts:Run(scriptName, onComplete)`:**
1. If `runState.active`, reject: `Util:Print("A script is already running. Stop it first.")`. Return.
2. Find script by case-insensitive name match. If `enabled == false`, show "disabled" message. Return.
3. **Shallow copy** `script.lines` into a new table via explicit loop (NOT `{unpack(t)}` which silently truncates at nil holes in sparse tables):
   ```lua
   local cmds = {}
   for i = 1, #script.lines do
       cmds[i] = script.lines[i]
   end
   ```
4. If `#cmds == 0`, show "no commands" message. Return.
5. Set `runState = {active=true, timerHandle=nil, commands=cmds, index=0, scriptName=scriptName, onComplete=onComplete}`.
6. Call `Scripts:DispatchNext()`.

**`Scripts:DispatchNext()` -- order: increment, check, dispatch:**
1. `runState.index = runState.index + 1`
2. If `runState.index > #runState.commands` or not `runState.active` (the `active` check handles the race where `Cancel()` set `active=false` between timer scheduling and callback firing -- `:Cancel()` is best-effort, the `active` flag is the authoritative guard):
   - Local `cb = runState.onComplete`.
   - Reset runState: `active=false, timerHandle=nil, commands={}, index=0, scriptName="", onComplete=nil`.
   - If `cb`, call `cb()`.
   - Return.
3. `Cmd:SendCommand(runState.commands[runState.index], runState.scriptName)`
4. Schedule next:
   ```lua
   runState.timerHandle = C_Timer.NewTimer(throttleDelay, function()
       runState.timerHandle = nil  -- handle has fired; nil it so Cancel() won't call :Cancel() on a dead handle
       if runState.active then
           Scripts:DispatchNext()
       end
   end)
   ```

**`Scripts:Cancel()`:**
1. If not `runState.active`, return.
2. Local `idx, total = runState.index, #runState.commands`.
3. `runState.active = false` (primary guard -- even if `:Cancel()` below fails or timer already fired, the callback's `if runState.active` check will no-op).
4. If `runState.timerHandle`, call `runState.timerHandle:Cancel()` (best-effort -- may have already fired between steps 3 and 4; that's safe because `active` is already false).
5. `Util:Print("Script cancelled (" .. idx .. " of " .. total .. " sent).")`
6. Reset runState: `active=false, timerHandle=nil, commands={}, index=0, scriptName="", onComplete=nil`.
7. **`onComplete` does NOT fire on cancellation.** Only fires on natural completion (step 2 of DispatchNext).

**Throttle:** `math.max(VoxGMDB.scripts.throttleDelay, C.SCRIPT_THROTTLE_MIN)`.

**UI:** "Stop" button visible while `runState.active`. When Scripts UI is reopened mid-run, check `runState.active` and show Stop button accordingly. Delete/Edit buttons disabled during active run (see Section 7.6).

### 7.8 Script import/export
```
# VoxGM Script v1
# Name: My Script
# Description: Sets up an RP scene
.npc add 1234
.modify speed 3
```

The `v1` in the header line is a decorative format marker, not a parsed key-value pair. Future format versions (if any) would use `# VoxGM Script v2` -- importers can detect format version by checking if the first line starts with `# VoxGM Script v` and parsing the trailing number. For v2.0 implementation, only `v1` is recognized; unrecognized versions are rejected with an error message.

**Import rules:**
1. Split on `\n`. Trim each line.
2. `#` lines = metadata. Parse `# Key: Value` by first `: ` only (`# Name: Setup: Scene 1` -> name = `Setup: Scene 1`). Unrecognized keys (e.g., `# Author: Bob`) silently ignored. Sanitize values via `Util:SanitizeText()`.
3. Other non-empty lines = commands. Must start with `.` or `/`. Sanitize. Drop if empty after. Secondary validation: warn if line contains ` .` or ` /` (possible concatenated commands from semicolon removal).
4. Cap at `C.SCRIPT_LINE_CAP` (50). Truncate with `Util:Print` warning.
5. Zero valid lines: reject import with `Util:Print("No valid command lines found.")`. Do NOT create script.
6. Name collision (case-insensitive): `StaticPopup_Show("VOXGM_SCRIPT_OVERWRITE", existingName, nil, importedScript)`.
7. **Imported scripts default to `enabled = true`.**
8. No dynamic code execution.

**Export:** `# VoxGM Script v1\n# Name: <name>\n# Description: <desc>\n` + commands.

### 7.9 Companion detection
Static metadata in `Data\CompanionAddons.lua`:
```lua
VoxGM.Data.CompanionAddons = {
    {
        addonName = "CreatureCodex",
        label = "Creature Codex",
        slashCmdKey = "CREATURECODEX",  -- verified: tools/publishable/CreatureCodex/client/CreatureCodex.lua:1032
        description = "Creature spell/aura sniffer",
    },
    {
        addonName = "VoxSniffer",
        label = "VoxSniffer",
        slashCmdKey = "VOXSNIFFER",  -- verified: tools/publishable/VoxSniffer/VoxSniffer.lua:217
        description = "Server data capture pipeline",
    },
    {
        addonName = "VoxTip",
        label = "VoxTip",
        slashCmdKey = "VOXTIP",  -- assumed: deployed addon, source not in repo. Must re-verify Phase 5
        description = "Debug tooltip overlay",
    },
    {
        addonName = "VoxPlacer",
        label = "VoxPlacer",
        slashCmdKey = "VOXPLACER",  -- assumed: deployed addon, source not in repo. Must re-verify Phase 5
        description = "Object/NPC placement tool",
    },
}
```

**Note on WoW slash registration:** When an addon writes `SLASH_CREATURECODEX1 = "/codex"`, WoW registers the handler under `SlashCmdList["CREATURECODEX"]`. The `slashCmdKey` field stores this registry key directly. Calling `SlashCmdList["CREATURECODEX"]("")` invokes the handler without requiring chat input.

**Note on silent failure:** If `addonName` has a typo in `CompanionAddons.lua`, `GetAddOnInfo` returns nil, and the addon silently shows as "Not Installed." This is indistinguishable from a genuinely absent addon. Phase 5 testing must verify each `addonName` string against actual addon TOC names.

**Detection (runtime table, no static data mutation):**
```lua
VoxGM.Companions.status = {}
local GetInfo = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
local IsLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

for _, addon in ipairs(VoxGM.Data.CompanionAddons) do
    local name = GetInfo(addon.addonName)
    if not name then
        VoxGM.Companions.status[addon.addonName] = "Not Installed"
    elseif IsLoaded(addon.addonName) then
        VoxGM.Companions.status[addon.addonName] = "Loaded"
    else
        VoxGM.Companions.status[addon.addonName] = "Installed"
    end
end
```

**UI per state:**
- **"Loaded"** (green): "Open" button enabled.
- **"Installed"** (yellow): "Open" button shown but disabled/greyed. Tooltip: "Installed but not loaded."
- **"Not Installed"** (grey): No button.

**Launch:** `SlashCmdList[addon.slashCmdKey]("")`. If `SlashCmdList[key]` is nil: `Util:Print("Could not open " .. addon.label)`.

### 7.10 Scale/Opacity
`UI:SetScale/SetOpacity` with clamping, persistence, status message.

### 7.11 Settings
**Path A:** Native Settings category via `Settings.RegisterCanvasLayoutCategory`.
**Path B:** In-addon panel. `Settings.lua` creates a frame with labeled controls using existing widget helpers (see Section 4.8 for exact call signatures per control). Panel lifecycle: save `activeTabId`, hide tab content, show settings, "Back" restores previous tab (see Section 4.8 for full lifecycle). `/vgm settings` opens it.

### 7.12 Keybindings (conditional)
If Bindings.xml works: Toggle VoxGM, Run Last Command, Open Preview. Else: slash-only.

## 8) Security Requirements

1. **Script sanitization mandatory.** `Util:SanitizeText()` on all lines before storage and dispatch. Strips `[%c|;]`. **Semicolons safe for TC GM commands** (space-separated args). Non-TC addon commands using semicolons will be affected -- this is an accepted, documented trade-off to prevent command-chaining injection.
2. **Metadata sanitization mandatory.** Import name/description sanitized via `Util:SanitizeText()`.
3. **No dynamic code execution.** No `loadstring`/`load`/`RunScript`/`pcall(loadstring(...))`.
4. **Import validation strict.** `#` = metadata (sanitized), `.`/`/` = commands (sanitized), else dropped. Cap at 50. Zero valid = reject.
5. **Throttling mandatory.** Min `C.SCRIPT_THROTTLE_MIN` (0.1s).

## 9) Constraints

- Preserve `VoxGMDB` and all v1 keys.
- No external dependencies.
- No ticket/teleportation/search/Lua-exec.
- Single commands through `Cmd:SendCommand()`. Sequences through `Scripts:Run()`.
- Console does not suppress chat.
- Model preview shows whatever `SetDisplayInfo` renders.
- Companion detection does not error for missing addons.
- Persisted stores enforce caps at migration AND write time.
- `local _, VoxGM = ...` module pattern.
- Script name comparisons case-insensitive everywhere.
- Conditional modules nil-guarded at all call sites (Console, ModelPreview, Settings).
- Console does not write to `VoxGMDB.ui.*` directly -- uses `UI:SetConsoleVisible()`.

## 10) Acceptance Criteria

1. v1.0.0 users retain all data on v2.0.0. No Lua errors.
2. `schemaVersion` = 2 on first v2 load.
3. Scale (0.5-2.0) and opacity (0.25-1.0) configurable, persisted.
4. Console displays system messages with timestamps, Clear, Copy Line (overlay+EditBox). No chat interference.
5. Console buffer cap configurable via `console.maxLines` (default 500, 100-2000). Bulk trim uses new-table slice (not repeated front-removal).
6. Model preview via `SetDisplayInfo` if available. "DisplayID: X" label. Confirmation print on preview. Waived if unavailable.
7. Preview from AppearanceTab + `/vgm preview`. CNPC = stretch goal.
8. Scripts: CRUD, cancellable throttled dispatch (0.3s default, 0.1s min), Stop button, already-running rejected. Delete/Edit disabled during active run.
9. Import/export: strict format, sanitize commands + metadata, zero-line rejected. `enabled` defaults true. Case-insensitive name collision detection.
10. Companions: "Loaded" (green, Open enabled), "Installed" (yellow, Open disabled), "Not Installed" (grey, no button). Uses GetAddOnInfo + IsAddOnLoaded.
11. All commands through `Cmd:SendCommand()`.
12. No external dependencies.
13. Settings accessible via native panel OR in-addon fallback, covering all configurable values. Back button restores previous tab.
14. Each phase reviewed via Triad pipeline.

## 11) Implementation Order

### Phase 0: Client API Spike (FIRST -- resolve all conditionals)
Verify on WoW 12.0.1.66263:
- [ ] `Settings.RegisterCanvasLayoutCategory`
- [ ] `C_AddOns.GetAddOnInfo` vs `GetAddOnInfo`
- [ ] `PlayerModel:SetDisplayInfo(displayID)`
- [ ] `Bindings.xml`
- [ ] `ScrollingMessageFrame:AddMessage()` / `:SetMaxLines()`

Document in `doc/voxgm_api_spike.md` (repo-level `doc/` dir).

### Phase 1: Quick Wins
- Update C.SCHEMA_VERSION, add constants
- Extend State.lua (DEFAULTS with `C.SCRIPT_THROTTLE_DEFAULT` ref, migration, validation, `State:PruneScripts()`)
- Extend UI.lua (scale/opacity, decimal slider, console host+divider creation with ClearAllPoints, SetConsoleVisible)
- Rewrite Core.lua slash handler (all sub-commands nil-guarded) + register PLAYER_LOGOUT + add `VoxGM.Settings = {}`
- Move RegisterDefaultParsers to Events:Init() (ensure parsers read VoxGMDB lazily)
- Smoke test: 6 tabs identical to v1

### Phase 2: Output Console
- Create Console.lua: populate UI's console host with SMF (EnableMouseWheel), lineBuffer, new-table bulk trim, overlay (button.messageText pattern), persistence (trim before load)
- Extend Events.lua: nil-guarded forwarding

### Phase 3: Model Preview (conditional)
- Create ModelPreview.lua (if Phase 0 OK): PlayerModel, input, debounce, confirmation print
- Add Preview button to Tab_Appearance.lua (nil-guarded)
- Add `/vgm preview` with `id ~= nil` check (handles DisplayID 0)

### Phase 4: Scripts
- Create Scripts.lua: CRUD (case-insensitive names), validation (incl. secondary), name-based delete/overwrite (no index), explicit-loop shallow copy, cancellable runner (timerHandle nil-clear in callback, active flag as primary guard), import/export (format version check), StaticPopups, write-time caps via `State:PruneScripts()`, UI disables Delete/Edit during active run, onComplete re-enables Run button

### Phase 5: Companions + Settings + Polish
- Create Data\CompanionAddons.lua (VoxTip/VoxPlacer marked assumed), Companions.lua (silent failure documented)
- Create Settings.lua (Path A or B per Phase 0; Path B lifecycle: save activeTabId, hide tabs, show panel, Back restores)
- If Bindings.xml confirmed: create Bindings.xml
- Verify VoxTip/VoxPlacer addonName + slashCmdKey during testing
- Polish

### Per-Phase Review Gate
5-round Triad pipeline per phase.

## 12) Competitive Positioning

| Dimension | TrinityAdmin Reforged | VoxGM v2 |
|-----------|----------------------|----------|
| Dependencies | Ace3 (7+ libs) | Zero |
| Client | 11.1.x | 12.x |
| Output | Ace3 chat | Dedicated console pane |
| Model preview | None | PlayerModel:SetDisplayInfo |
| Scripts | None | Cancellable throttled sequences |
| Integration | None | 4 Vox* addons |

## 13) Future Expansion (not committed)

- Server-side `.search` commands, VoxSniffer data bridge, Favorites/History browser UIs, Event monitor tab, CNPC model preview.

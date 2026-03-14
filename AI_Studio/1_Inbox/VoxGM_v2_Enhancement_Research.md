# VoxGM v2.0 Enhancement Research — Compiled Addon Analysis

## Context
VoxGM v1.0.0 is a 26-file, ~2,700-line Lua addon providing a tabbed GM control panel for TrinityCore 12.x. It sends dot-commands via ChatEdit_SendText. 6 tabs: GM Mode, NPC Ops, Character, Appearance, Custom NPC, Dev Tools. Minimap button, SavedVariables, command history, favorites (data layer only), event-driven toggle sync.

**Goal**: Identify the highest-impact enhancements by analyzing competing/adjacent addons, then produce a phased v2.0 spec.

---

## Part 1: Installed Addon Analysis (7 dev-tool addons examined)

### DevTool (Lua Object Inspector)
- **Tree-view table inspector** with expandable nodes, color-coded by Lua type
- **HybridScrollFrame** for performant scrolling (only renders visible rows)
- **Resizable split-column layout** via draggable column divider, position persisted
- **Event monitor** — real-time event stream display
- **Function call with args** — type arguments, pcall any function, show return values inline
- **Command history sidebar** with click-to-re-run (MRU ordered)
- **Relevance**: Output console pattern, event monitor for Dev Tools tab, performant scrolling

### NewbDevBox (Configurable Button Box)
- **Configurable quick-action buttons** — checkboxes to show/hide individual buttons
- **Scale and opacity text boxes** (50-300% scale, 25-100% opacity) applied to floating frame
- **Addon presence detection** via `C_AddOns.GetAddOnInfo()` — enables/disables companion addon launchers
- **Settings.RegisterCanvasLayoutCategory** — modern 12.x Settings panel registration
- **Keybinding integration** via Bindings.xml
- **Relevance**: Frame scale/opacity controls (VoxGM lacks these), Settings panel registration, companion addon detection (CreatureCodex, VoxSniffer, VoxTip, VoxPlacer)

### CVARs (CVar Manager)
- **Dual-checkbox per row** pattern for "should set?" + "value" pairs
- **Category headers** between groups of controls
- **Slider controls** with min/max/step/decimals/default
- **Custom D4Lib UI library** (lightweight, no Ace dependency)
- **Relevance**: VoxGM's Dev Tools tab already has CVars but could improve with sliders + category grouping

### WowLua (In-Game Lua IDE)
- **Multi-page saved scripts** — named pages with Previous/Next navigation
- **Three-pane layout**: code editor (top), draggable resize bar, output console (bottom), command line
- **ScrollingMessageFrame** for output (chat-frame style, scrollable)
- **Line number gutter** synced to editor scroll
- **Syntax highlighting** via FAIAP library
- **StaticPopupDialogs** for unsaved changes confirmation
- **UISpecialFrames** registration (Escape closes window)
- **Relevance**: Output console below command input, saved command sequences as named pages, draggable resize between panes

### _DebugLog (Structured Debug Logging)
- **Sortable column data tables** with flex-width columns, alignment, sum rows
- **Filter bar** — dropdown per category + full-text search + RESET button
- **Export to CSV/HTML/Markdown** via LibTextDump-1.0
- **Dynamic tab creation** — tabs auto-appear when data arrives
- **Timer-based auto-refresh** (1s polling for new data)
- **DLAPI** shared logging API — any addon can write to it
- **Relevance**: Sortable/filterable tables for lookup results, export functionality, integration API

### MacroToolkit (Advanced Macro Editor)
- **Syntax highlighting** with configurable colors per token type
- **LibAdvancedIconSelector** for icon browsing with category filters
- **Backup/restore/share** for macro collections
- **Custom slash commands** that run Lua
- **ElvUI skin integration** via optional module
- **Conditions builder UI** — visual macro conditional builder
- **Relevance**: Icon selection for favorites, backup/share presets, visual command builder pattern

### DynamicMovementSpeed (Floating Speed Overlay)
- **Lock/Unlock + right-click config** interaction pattern
- **Event-to-method dispatch**: `DMS[event](DMS, ...)` — clean event routing
- **DB defaults migration**: `CopyDefaults(src, dst)` + `CleanupDB(src, dst)` for forward-compatible SavedVariables
- **Table pooling** for GC-friendly memory management
- **Rate-limited OnUpdate** for real-time display
- **Relevance**: Lock/unlock floating panels, cleaner event dispatch, better SavedVariables migration

---

## Part 2: CurseForge Addon Analysis (10 addons researched)

### Datamine (by Ghostopheles) — HIGH RELEVANCE
- **Tooltip injection** — appends SpellID, ItemID, etc. to all game tooltips via TooltipDataProcessor
- **Explorer search UI** — unified search for Items, Spells, Achievements by name or ID
- **Model Viewer** — renders 3D models by FileDataID or CreatureDisplayInfoID using PlayerModel frames
- **Creature data collection** — caches creatures seen in-world, stores BroadcastText, Spells, Name, Reactions
- **Modular sub-addons** — heavy data packages as separate TOCs loaded on demand
- **Addon Compartment** integration (no LibDBIcon dependency)
- **Relevance**: Model viewer for .wmorph/.cnpc preview, Explorer-style search for IDs, creature data browser

### LibDFramework (Details! Framework) — MEDIUM RELEVANCE
- **Massive widget library**: buttons, dropdowns, sliders, text entries, labels, icons, scrollboxes, scrollbars
- **Tab container**, rounded panels, charts, timelines, timebars
- **Cooltip** custom tooltip system with shadow borders
- **SavedVariables helpers**, scheduling, colors, math, pixel utilities
- **Relevance**: Rich widget library, but adds Ace3 dependency chain. Better to cherry-pick patterns than adopt wholesale for VoxGM (which is zero-dependency)

### OneWoW Suite (5 addons) — MEDIUM RELEVANCE
- **Unified addon platform** — centralized UI framework, shared settings engine, one minimap button
- **Catalog module** — comprehensive browser for items, vendors, bosses, professions
- **Alt Tracker** — account-wide character management with financial tracking
- **Notes** — categorized notes, zone notes, pinned windows, tooltip integration
- **Modular ecosystem** — each module standalone or integrated
- **Relevance**: The "ecosystem" pattern is interesting for our VoxGM + VoxTip + VoxSniffer + CreatureCodex + VoxPlacer suite. Unified framework, shared data, one minimap button

### WoW Build Tools — LOW RELEVANCE
- Addon packaging/release tooling (BigWigsMods/packager replacement)
- Token replacement in TOC/Lua/XML files, VCS support
- **Relevance**: Only useful if we distribute VoxGM via CurseForge (not current plan)

### idTip — ALREADY REPLACED
- We built VoxTip as the replacement. Nothing new here.

### DevForge — NOT FOUND
- No addon by this exact name found on CurseForge. May be renamed or removed.

---

## Part 3: Competitor Analysis

### TrinityAdmin Reforged (2025, 11.1.x)
- Modern revival of classic TrinityAdmin for retail-era TC
- Ace3-based, multilingual-ready
- Categories: Player, Creature, Item, Ticket, Quest, Spell/Aura, Teleportation, Search, Action Logging
- **Comparison**: Broader command coverage than VoxGM (tickets, teleportation, action logging) but Ace3-dependent and not 12.x-verified

### GM Genie (3.3.5 / 4.3.4)
- HUD replacing minimap menu with GM status indicators
- **Hyperlink integration** — creature/gameobject links give dropdown menus for spawn/remove/port
- Ticket system with read marking and online/offline differentiation
- **Relevance**: Hyperlink dropdown pattern is interesting for VoxGM's NPC Ops

### rIngameModelViewer
- Uses `PlayerModel:SetDisplayInfo(displayID)` to render creature models in-game
- Simple frame with model display
- **Relevance**: Direct API for model preview feature

---

## Part 4: Enhancement Ideas Ranked by Impact

### Tier 1 — Game-Changing (worth building immediately)

1. **In-Frame Model Viewer / Display ID Preview**
   - When entering creature display IDs (.wmorph, .cnpc, NPC spawn), preview the 3D model in a panel
   - Uses `PlayerModel:SetDisplayInfo()` — proven API, used by Datamine and rIngameModelViewer
   - Huge QoL for GMs who currently guess display IDs or alt-tab to wow.tools
   - Could also preview item models for .disp slots

2. **Output Console / Server Response Pane**
   - ScrollingMessageFrame below command input area showing server responses
   - Captures CHAT_MSG_SYSTEM, CHAT_MSG_ADDON, command echoes
   - No more hunting through chat for results
   - Pattern proven by WowLua, DevTool

3. **Smart Search / ID Explorer**
   - Search for creatures, items, spells by name or partial match
   - Results in a sortable table with click-to-use (auto-fills the relevant input field)
   - Could query local DB2 data (client has item/spell caches) or use addon-collected data
   - Pattern proven by Datamine Explorer

4. **Saved Command Sequences ("Scripts")**
   - Multi-command sequences saved as named presets (beyond single-command history)
   - Example: "Setup RP Scene" = spawn 3 NPCs + set time + set weather
   - Run with one click, share between users via export/import
   - Pattern proven by WowLua pages, MacroToolkit backup

### Tier 2 — High Value, Low Effort

5. **Frame Scale/Opacity Controls**
   - Slider or text input for frame scale (50-200%) and opacity (25-100%)
   - Persist in SavedVariables, apply to main frame
   - 30 minutes of work, significant UX improvement
   - Pattern proven by NewbDevBox

6. **Companion Addon Detection + Integration**
   - Detect CreatureCodex, VoxSniffer, VoxTip, VoxPlacer via C_AddOns.GetAddOnInfo()
   - Show integration buttons: "Open CreatureCodex", "Start VoxSniffer capture", "Toggle VoxTip"
   - VoxGM becomes the hub for all Vox* addons
   - Pattern proven by NewbDevBox

7. **Settings Panel Registration**
   - Register VoxGM in WoW's native Settings panel via Settings.RegisterCanvasLayoutCategory
   - Shows configuration (scale, opacity, minimap toggle, default tab, CVar presets)
   - More professional, discoverable
   - Pattern proven by NewbDevBox, DynamicMovementSpeed

8. **Keybind Support**
   - Bindings.xml for toggle panel, run last command, quick-switch tabs
   - Discoverable in WoW's Key Bindings UI
   - Pattern proven by NewbDevBox, MacroToolkit

### Tier 3 — Nice to Have

9. **Sortable/Filterable Data Tables**
   - Replace simple text output with column-sortable, searchable tables
   - For NPC lists, lookup results, command history browsing
   - Pattern proven by _DebugLog

10. **Export/Import Presets**
    - Export favorites, saved scripts, CVar presets as text strings
    - Import from another user (paste in edit box)
    - Pattern proven by MacroToolkit backup/share

11. **Unified Vox* Ecosystem Framework**
    - Shared minimap button (one button, dropdown for all Vox* addons)
    - Shared SavedVariables namespace or inter-addon communication
    - Consistent look-and-feel across VoxGM, VoxTip, VoxPlacer
    - Pattern proven by OneWoW suite

12. **Event Monitor Tab**
    - Real-time event stream display in Dev Tools
    - Filter by event name, show payload
    - Pattern proven by DevTool Events module

---

## Part 5: What NOT to Do

- **Don't adopt Ace3** — VoxGM's zero-dependency approach is a feature, not a limitation
- **Don't adopt LibDFramework** — too heavy, too many transitive dependencies
- **Don't add ticket management** — TrinityAdmin Reforged covers this; VoxGM is about GM commands, not ticket workflow
- **Don't try to be OneWoW** — modular ecosystem is interesting conceptually but VoxGM's single-addon simplicity is a strength
- **Don't add teleportation UI** — too many locations to maintain; `.tele` autocomplete in chat is already fast enough

---

## Request to ChatGPT Architect

Please generate a phased VoxGM v2.0 enhancement spec that:
1. Prioritizes Tier 1 items (model viewer, output console, search, saved scripts)
2. Includes Tier 2 items as quick wins in an early phase
3. Maintains the zero-dependency architecture (no Ace3, no external libs)
4. Preserves backwards compatibility with v1.0.0 SavedVariables
5. Considers the existing file structure (26 files, tab-based modules)
6. Suggests which new files/modules to create vs which existing files to modify
7. Includes a "Vox* Integration" section for companion addon detection
8. Addresses the competitive gap with TrinityAdmin Reforged (search, logging, broader command coverage)

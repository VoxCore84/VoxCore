# [Claude Code Handoff] VoxTip v1.0 — VoxCore Debug Toolkit

**Date**: 2026-03-09
**Implementer**: Claude Code (Claude Opus 4.6)
**Spec Source**: User-directed (no ChatGPT spec — this was a live design session)
**Status**: Code complete, NOT tested in-game

---

## The Spec (User Requirements)

The user requested a 3-phase transformation of the existing **idTip** addon (silverwind's open-source tooltip ID addon) into a VoxCore-branded debug toolkit called **VoxTip**:

**Phase 1 — Rename + Expanded Server Protocol:**
- Rename from idTip → VoxTip (new TOC, prefix, SavedVariables)
- Keep ALL original idTip tooltip functionality (SpellID, ItemID, QuestID, NPC ID, etc.)
- Expand the Eluna server protocol from basic (DisplayID + FactionID) to full creature inspector data (SpawnGUID, Phase, AI, Script, Movement, NpcFlags, Position, Gossip, Loot, Equipment, Type, Subname)

**Phase 2 — Inspector Panel + Click-to-Copy:**
- Floating inspector frame showing all creature debug data
- Triggered by Shift+hover or `/voxtip` slash command
- Copy button on every field (opens EditBox popup for Ctrl+C)
- Quick GM command buttons (.go xyz, .npc info, Copy .go)

**Phase 3 — VoxPlacer Integration + Bookmarks:**
- Cross-addon communication: "Send to VoxPlacer" button populates VoxPlacer entry box
- Bookmark system: save creatures with coords, list/export/remove via slash commands
- Max 50 bookmarks, persisted in SavedVariables

---

## Files Created/Modified

### New Files (3):

| File | Lines | Purpose |
|------|-------|---------|
| `C:\WoW\_retail_\Interface\AddOns\VoxTip\VoxTip.lua` | ~650 | Main client addon — all tooltip hooks + inspector panel + bookmarks |
| `C:\WoW\_retail_\Interface\AddOns\VoxTip\VoxTip.toc` | 8 | Addon manifest (Interface 120001) |
| `C:\Users\atayl\VoxCore\runtime\lua_scripts\voxtip_server.lua` | ~110 | Eluna server script — handles basic + DETAIL creature info requests |

### Unmodified Files (left intact):

| File | Notes |
|------|-------|
| `C:\WoW\_retail_\Interface\AddOns\idTip\*` | Original idTip left in place — user should disable it to avoid duplicate tooltip lines |
| `C:\Users\atayl\VoxCore\runtime\lua_scripts\idtip_server.lua` | Old server script, harmless if idTip is disabled |
| `C:\WoW\_retail_\Interface\AddOns\VoxPlacer\VoxPlacer.lua` | NOT modified — VoxTip uses named frame `VoxPlacerEntryBox` directly |

---

## Implementation Notes

### Architecture Decisions

1. **Server Communication**: Uses WoW addon message system (`C_ChatInfo.SendAddonMessage` → Eluna `RegisterServerEvent(30)`). Prefix: `"VOXTIP"`. Two request types:
   - **Basic** (just entry number): Returns `"entry:displayId:factionId"` — used for tooltip overlay
   - **Detail** (`"DETAIL:entry"`): Returns `"DETAIL:entry|spawnId|displayId|factionId|phase|npcFlags|x|y|z|o|aiName|scriptName|movType|gossipMenu|lootId|equipId|creatureType|subname"` — used for inspector panel

2. **Addon message size**: All responses fit within WoW's 255-byte addon message limit. Worst case ~160 chars. String fields truncated (aiName 20, scriptName 30, subname 30) and pipe chars sanitized.

3. **VoxPlacer integration**: NO modification to VoxPlacer.lua needed. VoxTip accesses VoxPlacer's entry box via its global frame name `_G["VoxPlacerEntryBox"]` and `VoxPlacerFrame`.

4. **Config migration**: On first load, if `idTipConfig` (old SavedVariable) exists, VoxTip migrates toggle settings into `VoxTipDB`. Old data preserved for rollback.

5. **Inspector panel**: Built with running Y-cursor pattern (same as VoxPlacer). Rows created via `CreateRow()` helper. Frame height computed dynamically. Movable, position saved to SavedVariables.

6. **Shift+hover**: Checked via `IsShiftKeyDown()` inside the `UPDATE_MOUSEOVER_UNIT` handler. No `MODIFIER_STATE_CHANGED` event needed — simpler and avoids edge cases.

7. **Caching**: Two cache layers — `creatureInfoCache` (basic tooltip data) and `creatureDetailCache` (full inspector data). Keyed by entry ID. Caches persist for session lifetime (cleared on /reload).

### Deviations from Original idTip

- Removed `DressUpModel` frame (line 149 in original) — it was created as a client-side fallback for DisplayID but never worked on our private server client. Server-side approach via Eluna replaced it entirely.
- Changed `idTipConfig` SavedVariable to `VoxTipDB` — includes all toggle states plus inspector settings and bookmarks.
- Changed addon message prefix from `"IDTIP"` to `"VOXTIP"` — requires new server script.
- Added chat message filters for `.go` and `.npc` command echoes (same pattern VoxPlacer uses for `.vp` commands).

### Dependencies

- **Eluna**: Server must have Eluna loaded with `voxtip_server.lua` in `runtime/lua_scripts/`
- **WoW Client 12.x**: Uses `TooltipDataProcessor` API (12.x+), `Settings.RegisterCanvasLayoutCategory` (10.x+), `C_ChatInfo.SendAddonMessage`, `C_Map.GetBestMapForUnit`
- **No external libraries**: Pure WoW Lua API, no embeds
- **VoxPlacer** (optional): "Send to VoxPlacer" button only works if VoxPlacer addon is loaded

---

## Verification Instructions

### Pre-Test Setup
1. Disable or delete the old `idTip` addon folder (to prevent duplicate tooltip lines)
2. Delete `WTF/.../SavedVariables/idTip.lua` (old config)
3. Ensure `voxtip_server.lua` is in `runtime/lua_scripts/`
4. Restart worldserver (or `.reload eluna`) to load new server script
5. `/reload` client to load VoxTip addon

### Test Matrix

| # | Test | Expected Result |
|---|------|-----------------|
| 1 | Hover friendly NPC | Tooltip shows NPC ID, DisplayID, FactionID, MapID |
| 2 | Hover hostile mob | Same as #1 (UPDATE_MOUSEOVER_UNIT fallback) |
| 3 | Hover game object | Tooltip shows ObjectID |
| 4 | Hover item in bag | Tooltip shows ItemID, IconID |
| 5 | Hover spell in spellbook | Tooltip shows SpellID, IconID |
| 6 | Shift+hover creature | Inspector panel opens with full creature data |
| 7 | Inspector copy buttons | Click "C" → popup with text highlighted for Ctrl+C |
| 8 | Inspector ".go xyz" | Teleports player to creature position |
| 9 | Inspector ".npc info" | Runs .npc info command |
| 10 | Inspector "-> VoxPlacer" | Opens VoxPlacer frame with entry pre-filled |
| 11 | Inspector "Bookmark" | Saves creature to bookmark list, prints confirmation |
| 12 | `/voxtip` | Toggles inspector panel |
| 13 | `/voxtip bookmarks` | Lists all saved bookmarks in chat |
| 14 | `/voxtip export` | Opens copy popup with all bookmarks as text |
| 15 | `/voxtip remove 1` | Removes first bookmark |
| 16 | `/voxtip options` | Opens addon settings panel |
| 17 | `/voxtip help` | Shows command list |
| 18 | Hover player character | Should NOT show NPC ID or request server info |
| 19 | Server offline (no Eluna) | Tooltip still shows NPC ID + MapID (client-side). DisplayID/FactionID gracefully absent |
| 20 | Rapid mouseover changes | No duplicate tooltip lines, inspector updates cleanly |

### Server-Side Audit Points

1. **SQL injection**: `voxtip_server.lua` line 53 — the entry comes from `tonumber(msg)` which is safe (nil on non-numeric). No string concatenation of user-controlled data into SQL.
2. **GetDBTableGUIDLow fallback**: Lines 37-41 — tries both `GetDBTableGUIDLow` and `GetSpawnId` for Eluna version compatibility.
3. **Pipe sanitization**: Lines 82-84 — strips `|` from aiName/scriptName/subname to prevent response parsing corruption.
4. **WorldDBQuery nil check**: All query results checked before calling `GetUInt32`/`GetString`.

---

## DevOps Impact

- **No changes to `/tools/`** or build scripts
- **No changes to C++ source** — this is pure Lua (client addon + Eluna server script)
- **No SQL changes** — reads existing tables only (`creature_template`, `creature`, `creature_equip_template`)
- **New files are gitignored** — the WoW addon folder and `runtime/lua_scripts/` are not in the main git tree (addons are deployed separately)

---

## Known Issues / Warnings

1. **Untested**: This code has NOT been run in-game yet. Syntax errors are possible. First `/reload` will reveal any Lua errors.
2. **`bit.band` availability**: The `DecodeNpcFlags` function uses `bit.band()`. WoW 12.x should have this in the global Lua environment, but if not, it will error. Fallback: display raw number.
3. **DressUpModel removal**: The original idTip created a hidden DressUpModel frame. VoxTip removed it since we use server-side display info. If someone needed client-side model display for another purpose, it's gone.
4. **Bookmark persistence**: Bookmarks use entry ID as the unique key. If two NPCs share the same entry at different locations, only one bookmark per entry is enforced.
5. **Inspector auto-update**: When the inspector is open, it sends a DETAIL request on EVERY new mouseover. On a server with high creature density and rapid mouse movement, this could generate significant addon message traffic. Consider adding a throttle if this becomes an issue.

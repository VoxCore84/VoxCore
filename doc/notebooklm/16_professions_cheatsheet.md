# VoxCore Professions — Cheatsheet

## Overview

Two-layer system that lets every player learn **all 11 primary professions** (normally capped at 2) plus both secondary professions (Cooking, Fishing). 13 total.

| Layer | What | Where |
|-------|------|-------|
| **Server-side** | Eluna `.prof` commands — learn/unlearn/open/max/reset | `lua_scripts/voxcore_professions.lua` |
| **Client-side** | `/profs` addon — interactive panel + minimap button | `addons/VoxCoreProfessions/` |

## Prerequisites

- `MaxPrimaryTradeSkill = 11` in `worldserver.conf` (already set)
- Rank 10 profession headers handled by SQL (separate from this system)

---

## Server Commands (`.prof`)

| Command | What it does |
|---------|-------------|
| `.prof` | List all professions with learned/skill status |
| `.prof learn <name>` | Learn a profession (skill cap set to 900) |
| `.prof unlearn <name>` | Unlearn a profession and its auxiliary spells |
| `.prof all` | Learn every profession at once |
| `.prof reset` | Unlearn every profession at once |
| `.prof max` | Max all learned profession skill levels to 900 |
| `.prof open <name>` | Open a profession's crafting window |
| `.prof <name>` | Shortcut: learns if unknown, opens crafting if known |
| `.prof status` | (GM only) Check targeted player's professions |
| `.prof help` | Show all commands and abbreviations |

### Supported Names & Abbreviations

| Profession | Abbreviations |
|-----------|---------------|
| Alchemy | `alch`, `alc` |
| Blacksmithing | `bs`, `black`, `smith` |
| Enchanting | `ench`, `enc` |
| Engineering | `eng`, `engi` |
| Herbalism | `herb`, `herbs` |
| Inscription | `insc`, `inscr`, `scribe` |
| Jewelcrafting | `jc`, `jewel` |
| Leatherworking | `lw`, `leather` |
| Mining | `mine`, `smelt`, `smelting` |
| Skinning | `skin` |
| Tailoring | `tail`, `tailor` |
| Cooking | `cook` |
| Fishing | `fish` |

Partial matches also work (e.g., `.prof alc` matches Alchemy).

### Auxiliary Spells (auto-learned/unlearned)

| Profession | Extra Spell | ID |
|-----------|------------|-----|
| Herbalism | Find Herbs | 2383 |
| Mining | Find Minerals | 2580 |
| Cooking | Cooking Fire | 818 |

---

## Client Addon (`/profs`)

| Action | What it does |
|--------|-------------|
| `/profs` or `/professions` | Toggle the profession panel |
| **Minimap icon** | Click to toggle, drag to reposition |
| **Left-click** a row | Learn (if unknown) or Open crafting (if known) |
| **Right-click** a row | Unlearn (if known) |
| **Learn All** button | Learns all 13 professions |
| **Max Skills** button | Maxes all learned profession skill levels |
| **Reset All** button | Unlearns everything (confirmation popup) |
| ESC | Closes the panel |
| Drag titlebar | Move the panel (position saved) |

### Panel Layout

| Section | Professions |
|---------|------------|
| **Crafting** | Alchemy, Blacksmithing, Enchanting, Engineering, Inscription, Jewelcrafting, Leatherworking, Tailoring |
| **Gathering** | Herbalism, Mining (has Smelting window), Skinning |
| **Secondary** | Cooking, Fishing |

- Known professions: full color icon, white name, "Open" or "Learned" status
- Unknown professions: greyed/desaturated icon, "Not learned" label
- Hover tooltips explain what each click does
- Help bar at bottom: `Left-click: Learn/Open | Right-click: Unlearn`

### Design Decisions

- **No SecureActionButton** — all actions route through server `.prof` commands via `SendChatMessage`. Simpler, no combat taint issues.
- **Minimap button** — no library dependencies, draggable around the minimap rim, position saved.
- **Reset All** — confirmation popup prevents accidental mass-unlearn.

---

## Spell ID Reference

| Profession | Base Spell | Skill Line | Type |
|-----------|-----------|-----------|------|
| Alchemy | 2259 | 171 | Primary (Crafting) |
| Blacksmithing | 2018 | 164 | Primary (Crafting) |
| Enchanting | 7411 | 333 | Primary (Crafting) |
| Engineering | 4036 | 202 | Primary (Crafting) |
| Herbalism | 2366 | 182 | Primary (Gathering) |
| Inscription | 45357 | 773 | Primary (Crafting) |
| Jewelcrafting | 25229 | 755 | Primary (Crafting) |
| Leatherworking | 2108 | 165 | Primary (Crafting) |
| Mining (Smelting) | 2575 | 186 | Primary (Crafting) |
| Skinning | 8613 | 393 | Primary (Gathering) |
| Tailoring | 3908 | 197 | Primary (Crafting) |
| Cooking | 2550 | 185 | Secondary |
| Fishing | 131474 | 356 | Secondary |

---

## Deployment

### Eluna Script (server-side)
Already deployed at:
```
out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/lua_scripts/voxcore_professions.lua
```
Loaded automatically on worldserver startup.

### Client Addon
Source:
```
addons/VoxCoreProfessions/
  VoxCoreProfessions.toc
  VoxCoreProfessions.lua
```
Copy to WoW client addon folder:
```
<WoW>/_retail_/Interface/AddOns/VoxCoreProfessions/
```

### Quick Test Sequence
1. Restart worldserver (Eluna reloads all lua_scripts/)
2. Log in — minimap icon should appear, chat shows load message
3. Click minimap icon or type `/profs` — panel opens
4. Left-click an unknown profession — should learn it (row lights up)
5. Left-click a known crafting profession — should open crafting window
6. Right-click a known profession — should unlearn it (row greys out)
7. Click "Learn All" — all rows light up
8. Click "Max Skills" — server confirms all maxed to 900
9. Click "Reset All" — confirmation popup, then all rows grey out
10. `.prof help` — verify all server commands listed
11. `.prof status` (as GM, targeting another player) — shows their professions

---

## Architecture

```
Player clicks addon UI
  └─> SendChatMessage(".prof learn alchemy", "SAY")
        └─> Server intercepts "." prefix (never reaches other players)
              └─> Eluna PLAYER_EVENT_ON_COMMAND fires
                    └─> OnCommand() routes to CmdLearn()
                          └─> player:LearnSpell(2259)
                          └─> player:SetSkill(171, 1, 1, 900)
                          └─> SendBroadcastMessage() confirms to player
                                └─> SPELLS_CHANGED event fires client-side
                                      └─> Addon Refresh() updates row visuals
```

---

## Files

| File | Purpose |
|------|---------|
| `lua_scripts/voxcore_professions.lua` | Server-side Eluna commands |
| `addons/VoxCoreProfessions/VoxCoreProfessions.lua` | Client addon UI |
| `addons/VoxCoreProfessions/VoxCoreProfessions.toc` | Addon manifest |
| `doc/professions_cheatsheet.md` | This file |

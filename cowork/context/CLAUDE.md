# RoleplayCore — Project Guide

## What This Is
TrinityCore-based WoW private server targeting the **12.x / Midnight** client, specialized for **roleplay**. Built on top of stock TrinityCore with significant custom systems.

## Build

| Config | Dir | Use |
|---|---|---|
| `x64-Debug` | `out/build/x64-Debug/` | Compilation, debugging |
| **`x64-RelWithDebInfo`** | `out/build/x64-RelWithDebInfo/` | **Primary runtime** (17s startup vs 60s Debug) |

- **Build**: `cd /c/Dev/RoleplayCore/out/build/x64-Debug && ninja -j16 2>&1`
- **Scripts only**: `cd /c/Dev/RoleplayCore/out/build/x64-Debug && ninja -j16 scripts 2>&1`
- **CMake reconfigure**: `cmake -B out/build/x64-Debug -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
- **Key CMake options**: `SCRIPTS=static`, `ELUNA=ON`, `TOOLS=ON`
- **Compiler**: MSVC (VS 2022), Generator: Ninja, C++20
- **MySQL**: `C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe` — root/admin

## Databases (5 total)

| DB | Purpose |
|---|---|
| `auth` | Accounts, RBAC permissions |
| `characters` | Player data |
| `world` | Game world data (creatures, items, spells, etc.) |
| `hotfixes` | Client hotfix overrides |
| **`roleplay`** | Custom: `creature_extra`, `creature_template_extra`, `custom_npcs`, `server_settings` |

## Project Structure

```
src/server/
  game/
    RolePlay/              # sRoleplay singleton — central custom system
    Companion/             # sCompanionMgr singleton — companion squad AI
    Hoff/                  # Utility class (FindMapCreature, movement calc)
    Entities/Creature/CreatureOutfit.*  # NPC outfit/appearance overlay
    Craft/                 # Crafting system
    LuaEngine/             # Eluna scripting integration
  scripts/
    Custom/                # ALL custom scripts (see Custom Systems below)
      custom_script_loader.cpp  # Entry point: AddCustomScripts()
      Companion/           # CompanionAI + commands + scripts
      RolePlayFunction/    # Display/ (.display) + Effect/ (.effect)
    Commands/
      cs_customnpc.cpp     # .customnpc / .cnpc commands
  database/
    Database/Implementation/RoleplayDatabase.*  # 5th DB connection
sql/
  RoleplayCore/            # One-time setup scripts
  updates/                 # Incremental updates (YYYY_MM_DD_NN_<db>.sql)
```

## Custom Systems

### Core Singletons
1. **Roleplay (`sRoleplay`)** — `src/server/game/RolePlay/` — creature extras, custom NPCs, player extras. Loaded via `sRoleplay->LoadAllTables()`
2. **Companion Squad (`sCompanionMgr`)** — `src/server/game/Companion/` — DB-driven NPC companions with `.comp` commands, role-based AI (tank/healer/DPS), formation movement. Entries 500001-500005
3. **Custom NPC (`.cnpc`)** — `src/server/scripts/Commands/cs_customnpc.cpp` — player-race NPCs with custom equipment/appearance. Config: `CreatureTemplateIdStart = 400000`

### Script Systems (all in `src/server/scripts/Custom/`)
4. **Visual Effects (`.effect`)** — `Noblegarden::EffectsHandler` — SpellVisualKit persistence, late-join sync
5. **Display/Transmog (`.display`)** — `RoleplayCore::DisplayHandler` — per-slot appearance overrides
6. **Transmog Outfits** — Full `CMSG_TRANSMOG_OUTFIT_*` handling for 12.x wardrobe. See memory `transmog-implementation.md`
7. **Player Morph (`.wmorph`/`.wscale`/`.remorph`)** — `player_morph_scripts.cpp` — persistent player morph/scale
8. **Misc Scripts** — `spell_dragonriding.cpp` (skyriding), `item_toy_scripts.cpp` (toys), `spell_wormhole_generators.cpp` (teleports), `spell_clear_transmog.cpp`, `free_share_scripts.cpp` (.barbershop, .castgroup, .settime, .typing)

## Coding Conventions

- **C++ standard**: C++20 features OK (structured bindings, `contains()`, `string_view`, etc.)
- **Header guards**: `#pragma once` for new files
- **Indent**: 4 spaces, **Max line**: 160, **Charset**: latin1 (see `.editorconfig`)
- **Visibility**: Use `TC_GAME_API` on classes in `src/server/game/`
- **Singletons**: Static local instance pattern, exposed via `sFoo` macro
- **Script registration**: `void AddSC_<name>()` free function, registered in `custom_script_loader.cpp`
- **Spell scripts**: `RegisterSpellScript(ClassName)` macro. Others: `new ClassName()` auto-registers
- **Namespaces**: `RoleplayCore::` (display), `Noblegarden::` (effects)
- **RBAC**: Custom permissions in `1000+` / `2100+` / `3000+` ranges
- **Includes**: `#include "..."` for TC headers, `#include <...>` for system

## Adding a New Custom Script

1. Create `.cpp` (and optionally `.h`) in `src/server/scripts/Custom/`
2. Define `void AddSC_<name>()` at the bottom
3. Add the declaration + call in `custom_script_loader.cpp`
4. If it needs new RBAC perms, add to `RBAC.h` and `sql/RoleplayCore/1. auth db.sql`
5. Build with `ninja -j16 scripts`

## Key Files

| File | Why |
|---|---|
| `src/server/game/RolePlay/RolePlay.h` | Central roleplay API — read this first |
| `src/server/scripts/Custom/custom_script_loader.cpp` | Script registration entry point |
| `src/server/game/Entities/Creature/CreatureOutfit.h` | NPC appearance overlay system |
| `src/server/game/Accounts/RBAC.h` | Permission constants (custom range 1000+) |
| `src/server/worldserver/worldserver.conf.dist` | All config keys including custom ones |

## DB Schema Rules

- **No `item_template`** — use `hotfixes.item` / `hotfixes.item_sparse`
- **No `broadcast_text` in world** — use `hotfixes.broadcast_text`
- **No `pool_creature`/`pool_gameobject`** — unified as `pool_members`
- **No `spell_dbc`/`spell_name`** — use wago-db2 MCP or Wago CSVs
- **`creature_template`**: `faction` (not FactionID), `npcflag` (bigint), spells in `creature_template_spell`
- **Always DESCRIBE tables before writing SQL**
- Full column/table reference: auto-memory `db-schema-notes.md`

## Tools

- **MCP servers**: `wago-db2` (DB2 CSV queries), `mysql` (direct DB access), `codeintel` (C++ symbol lookup)
- **LSP plugins**: `clangd-lsp` (C++), `lua-lsp` (Lua), `github` (PRs/issues)
- **17 slash commands**: `/build-loop`, `/check-logs`, `/parse-errors`, `/apply-sql`, `/soap`, `/lookup-spell`, `/lookup-item`, `/lookup-creature`, `/lookup-area`, `/lookup-faction`, `/lookup-emote`, `/lookup-sound`, `/decode-pkt`, `/parse-packet`, `/new-script`, `/new-sql-update`, `/smartai-check`
- **External repos**: wago tooling (`C:/Users/atayl/source/wago/`), tc-packet-tools, code-intel, trinitycore-claude-skills
- **GitHub**: `VoxCore84/RoleplayCore` (private), `gh` CLI authenticated
- Full inventory: auto-memory `tooling-inventory.md`

## Server Runtime & Logs

- **Primary runtime**: `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/`
- **Logs**: `Server.log`, `DBErrors.log`, `Debug.log`, `GM.log`, `Bnet.log`, `PacketLog/`
- **worldserver.conf**: in runtime dir (NOT in source tree)
- **MySQL**: UniServerZ 9.5.0 (bundled), root/admin

## Debugging Methodology — MANDATORY PIPELINE

**This is a BLOCKING pipeline. Skipping a gate is a hard error.**

1. **GATE 1: Collect Data** — Fan out parallel agents to read ALL relevant logs (`Server.log`, `DBErrors.log`, `Debug.log`), query DB state, trace code paths with codeintel. **No hypothesis until data is collected.**
2. **GATE 2: Analyze** — State hypothesis with explicit data citations. Every claim needs a log line, packet byte, DB row, or code path. No citation = no claim.
3. **GATE 3: Propose Fix** — One change at a time. Root cause only. Trace downstream callers with codeintel before modifying any function.
4. **GATE 4: Verify** — Build with `/build-loop`, re-collect all data, confirm hypothesis matches. If not → back to Gate 1.

**Key rules**: Never combine fixes. Don't patch readers to fix writers. DESCRIBE tables before SQL. Don't summarize before reading data. Don't propose fixes in the same message as the bug report.

Full recipes, data source tables, and anti-patterns: auto-memory `debugging-methodology.md`

## Work Style

**MANDATORY**: Always default to parallel execution. Hardware is not a constraint (Ryzen 9 9950X3D 12C/24T, 128GB DDR5, NVMe).

1. **2+ independent parts → parallel agents** — do not ask, just do it
2. **2+ searches → fan out Explore agents** — never search sequentially
3. **Code + build → run builds in background immediately**
4. **Multiple errors → one agent per error category**
5. **Builds, long queries, server restarts → always background**

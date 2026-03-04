# RoleplayCore — Project Guide

## What This Is
TrinityCore-based WoW private server targeting the **12.x / Midnight** client, specialized for **roleplay**. Built on top of stock TrinityCore with significant custom systems.

## Build

- **Generator**: Ninja
- **Compiler**: MSVC (Visual Studio 2022)
- **Build type**: Debug
- **Build directory**: `out/build/x64-Debug/`
- **Build command**: `cd /c/Dev/RoleplayCore/out/build/x64-Debug && ninja -j16 2>&1`
- **Build just scripts**: `cd /c/Dev/RoleplayCore/out/build/x64-Debug && ninja -j16 scripts 2>&1`
- **CMake reconfigure**: `cmake -B out/build/x64-Debug -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
- **Key CMake options**: `SCRIPTS=static`, `ELUNA=ON`, `TOOLS=ON`
- **MySQL**: MySQL Server 8.0 at `C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe`

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
src/
  server/
    game/
      RolePlay/          # Roleplay singleton manager (sRoleplay) — the central custom system
      Hoff/              # Utility class (FindMapCreature, movement calc, etc.)
      Entities/Creature/CreatureOutfit.*   # NPC outfit/appearance overlay
      LuaEngine/         # Eluna scripting integration
      Craft/             # Crafting system
    scripts/
      Custom/            # ALL custom scripts go here
        custom_script_loader.cpp          # Entry point: AddCustomScripts()
        free_share_scripts.cpp            # .barbershop, .castgroup, .settime, .typing, etc.
        item_toy_scripts.cpp              # Toy item SpellScripts
        spell_dragonriding.cpp            # Skyriding spell scripts
        RolePlayFunction/
          Display/       # .display command — per-slot item appearance override
          Effect/        # .effect command — SpellVisualKit management
      Commands/
        cs_customnpc.cpp  # .customnpc / .cnpc commands (748 lines)
    database/
      Database/Implementation/RoleplayDatabase.*  # 5th DB connection
sql/
  RoleplayCore/          # One-time setup scripts (auth RBAC, hotfixes, roleplay DB, world patches)
  updates/               # Incremental TC update files (YYYY_MM_DD_NN_<db>.sql)
  base/                  # Full database dumps for fresh installs
_patches_transmog/       # Reference git diff patches for the transmog outfit feature
```

## Custom Systems

### 1. Roleplay Singleton (`sRoleplay`)
- **Location**: `src/server/game/RolePlay/RolePlay.h` + `.cpp`
- Manages creature extras (scale, creator, flags), custom NPCs, player extras
- Loaded via `sRoleplay->LoadAllTables()` during world startup

### 2. Custom NPC System (`.customnpc` / `.cnpc`)
- Create player-race NPCs with custom equipment, appearance, race, gender, guild
- **Location**: `src/server/scripts/Commands/cs_customnpc.cpp`
- Config: `Roleplay.CustomNpc.OutfitIdStart = 200001`, `Roleplay.CustomNpc.CreatureTemplateIdStart = 400000`

### 3. Visual Effects System (`.effect`)
- **Namespace**: `Noblegarden::`
- `EffectsHandler` singleton persists SpellVisualKits on players/creatures
- Syncs visual state to late-joining observers via `Player::OnMeetUnit` hook

### 4. Display/Transmog System (`.display`)
- **Namespace**: `RoleplayCore::`
- `DisplayHandler` singleton for per-slot appearance overrides

### 5. Transmog Outfit Packets
- Full `CMSG_TRANSMOG_OUTFIT_*` handling for 12.x wardrobe outfits

## Coding Conventions

- **C++ standard**: C++20 features OK (structured bindings, `contains()`, `string_view`, etc.)
- **Header guards**: `#pragma once` for new files (stock TC uses `#ifndef`)
- **Indent**: 4 spaces (see `.editorconfig`)
- **Charset**: latin1 for C/C++ files (`.editorconfig`)
- **Max line length**: 160
- **Visibility**: Use `TC_GAME_API` on classes in `src/server/game/`
- **Singletons**: Static local instance pattern, exposed via `sFoo` macro
- **Script pattern**: Inherit from `CommandScript`/`PlayerScript`/`WorldScript`/`SpellScript`/`AuraScript`
- **Script registration**: `void AddSC_<name>()` free function, registered in loader `.cpp`
- **Spell scripts**: Use `RegisterSpellScript(ClassName)` macro
- **Other scripts**: `new ClassName()` auto-registers with `ScriptMgr`
- **Namespaces**: `RoleplayCore::` for display, `Noblegarden::` for effects
- **RBAC**: Custom permissions in `1000+` / `2100+` / `3000+` ranges
- **Includes**: `#include "..."` for TC headers, `#include <...>` for system

## Adding a New Custom Script

1. Create `.cpp` (and optionally `.h`) in `src/server/scripts/Custom/`
2. Define `void AddSC_<name>()` at the bottom
3. Add the declaration + call in `custom_script_loader.cpp`
4. If it needs new RBAC perms, add to `RBAC.h` and `sql/RoleplayCore/1. auth db.sql`
5. Build with `ninja -j16 scripts`

## Key Files to Know

| File | Why |
|---|---|
| `src/server/game/RolePlay/RolePlay.h` | Central roleplay API — read this first |
| `src/server/scripts/Custom/custom_script_loader.cpp` | Script registration entry point |
| `src/server/game/Entities/Creature/CreatureOutfit.h` | NPC appearance overlay system |
| `src/server/game/Accounts/RBAC.h` | Permission constants (custom range 1000+) |
| `src/server/worldserver/worldserver.conf.dist` | All config keys including custom ones |
| `cmake/options.cmake` | All build options |

## Available Tools (details in auto-memory files)

- **MCP servers**: `wago-db2` (DB2 CSV queries), `mysql` (direct DB access), `codeintel` (C++ symbol lookup)
- **LSP plugins**: `clangd-lsp` (C++), `lua-lsp` (Lua), `github` (PRs/issues)
- **17 slash command skills**: `/build-loop`, `/check-logs`, `/parse-errors`, `/apply-sql`, `/soap`, `/lookup-spell`, `/lookup-item`, `/lookup-creature`, `/lookup-area`, `/lookup-faction`, `/lookup-emote`, `/lookup-sound`, `/decode-pkt`, `/parse-packet`, `/new-script`, `/new-sql-update`, `/smartai-check`
- **External repos**: wago tooling (`C:/Users/atayl/source/wago/`), tc-packet-tools, code-intel, trinitycore-claude-skills
- **GitHub**: `VoxCore84/RoleplayCore` (private), `gh` CLI authenticated

## Server Runtime & Logs

- **Primary runtime**: `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/`
- **Logs**: `Server.log`, `DBErrors.log`, `Debug.log`, `GM.log`, `Bnet.log`, `PacketLog/`
- **worldserver.conf**: in runtime dir (NOT in source tree)
- **MySQL**: UniServerZ 9.5.0 (bundled), client at `C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe`, root/admin

## Wago DB2 CSV Export Oscillation Warning

Wago.tools CSV exports fluctuate wildly between builds in how many rows they include for certain tables. This is a Wago export-side behavior, NOT actual Blizzard content changes. Known affected tables:

| Table               | "Reduced" builds (66044, 66192, 66220) | "Full" builds (66102, 66198) |
|---------------------|----------------------------------------|------------------------------|
| SpellEffect         | ~269K-511K rows                        | ~608K rows                   |
| ItemSparse          | ~125K-171K rows                        | ~171K rows                   |
| SpellMisc           | ~136K-404K rows                        | ~404K rows                   |
| CriteriaTree        | ~4K-115K rows                          | ~115K rows                   |
| Criteria            | ~14K-63K rows                          | ~63K rows                    |
| CreatureDisplayInfo | ~15K-118K rows                         | ~118K rows                   |

**Implications for build diffs:**
- Never diff between a "full" and "reduced" export build — you'll see hundreds of thousands of false additions/removals
- Always diff same-type builds, or better yet, diff all builds incrementally to spot the pattern
- For SpellEffect coverage, prefer "full export" builds (66102, 66198) as the data source for imports
- For latest content (new spells, items, quests), use the newest build (currently 66220)

**How to detect which type a build is:**
```bash
wc -l SpellEffect-enUS.csv  # >500K = full, <400K = reduced
wc -l CriteriaTree-enUS.csv # >100K = full, <10K = reduced
```

## DB Schema Gotchas

- **No `item_template`** — use `hotfixes.item` / `hotfixes.item_sparse`
- **No `broadcast_text` in world** — use `hotfixes.broadcast_text`
- **No `pool_creature`/`pool_gameobject`** — unified as `pool_members`
- **No `spell_dbc`/`spell_name`** — use wago-db2 MCP or Wago CSVs
- **`creature_template`**: `faction` (not FactionID), `npcflag` (bigint), spells in `creature_template_spell`
- **Always DESCRIBE tables before writing SQL**

## Debugging Methodology — MANDATORY PIPELINE

**This is a BLOCKING pipeline. Each gate MUST be passed before proceeding to the next. Skipping a gate is a hard error — equivalent to writing code that doesn't compile. The #1 cause of wasted time is coding fixes based on assumptions instead of data.**

### GATE 1: Collect Data (DO THIS FIRST — NO EXCEPTIONS)

**You may NOT form a hypothesis, propose a fix, write a summary, or produce any conclusion until you have read the actual data.** "I already know what's wrong" is not an excuse to skip this gate.

For EVERY bug investigation, fan out **parallel agents** to collect ALL relevant data sources simultaneously:

| Data Source | When Required | How to Collect |
|---|---|---|
| `Server.log` | Always | Read the file — check for errors/warnings around the bug |
| `DBErrors.log` | Always | Read the file — check for SQL failures |
| `Debug.log` | Always | Read the file — grep for the system under investigation |
| Packet captures (`PacketLog/`) | Any visual/sync/network issue | `opcode_analyzer.py`, `transmog_debug.py --packet`, WPP parsed output |
| Database state | Any persistence/data issue | mysql MCP — `SELECT` the relevant rows. **DESCRIBE first.** |
| TransmogSpy SavedVariables | Any transmog issue | Read `C:/WoW/_retail_/WTF/Account/1#1/SavedVariables/TransmogSpy.lua` |
| Client addon output | If client-side addon is involved | Read the SavedVariables file |
| Code path | Always | codeintel `find_definition`, `find_references`, `call_hierarchy` |

**Gate check**: Before writing ANY analysis, list what data you collected and from which sources. If a relevant source exists and you didn't read it, go back and read it.

### GATE 2: Analyze (Hypothesis MUST Reference Collected Data)

Only after Gate 1 is complete:
1. State an explicit hypothesis: "X happens because Y"
2. **Cite the specific data** that supports it — quote log lines, packet field values, DB rows, code paths
3. Cross-reference IDs against DB2/Wago
4. Check for data corruption before blaming code
5. Identify what the data SHOULD show if the hypothesis is correct vs what it actually shows

**Gate check**: Every claim must have a data citation. "The client omits HEAD/MH/OH" requires showing the actual packet bytes where those slots are absent. No citation = no claim.

### GATE 3: Propose Fix (Minimal, Targeted, Root-Cause)

Only after Gate 2 is complete:
1. One change at a time — never combine fixes
2. Fix targets the root cause identified in Gate 2, not a symptom
3. Trace downstream callers with codeintel before changing any function
4. Add logging at decision points, never remove it

### GATE 4: Implement and Verify

Only after Gate 3 is approved:
1. Build with `/build-loop`
2. Reproduce in clean state
3. Collect ALL outputs again (same sources as Gate 1)
4. Confirm hypothesis — if data doesn't match, **back to Gate 1** with the new data

### Code Change Rules
- **Never combine multiple fixes** — each is a separate commit and test cycle
- **Don't add fallback logic to parsers** — `Read()` parses bytes, never accesses Player/Item/DB
- **Don't fix writers by patching readers** — if the DB has bad data, clean the DB
- **DESCRIBE tables before writing SQL** — always
- **Trace downstream** — use codeintel `find_references`/`call_hierarchy` before changing any function signature

### Anti-Patterns (NEVER DO THESE)
- **Summarizing before reading data** — Writing "Issue: X is broken because Y" before examining logs/packets/DB is a hard violation
- **Proposing a fix in the same message as the bug report** — Gate 1 and Gate 3 cannot be in the same response
- **"I believe" without data** — Every hypothesis needs a citation to actual collected data
- **Churning** — If you've been thinking for >30s without issuing tool calls, you're churning. Fan out data collection agents instead.
- **Sequential data collection** — Always fan out parallel agents for independent data sources. Never read log, then packet, then DB one at a time.

Full patterns and domain-specific recipes: see auto-memory `debugging-methodology.md`

## Work Style & Parallelism Guidelines

**MANDATORY**: Always default to parallel execution. Do NOT work sequentially when tasks can be parallelized. Hardware is not a constraint (128GB RAM, NVMe). Err on the side of spawning too many agents rather than too few.

### Parallel-First Rules (follow these, don't ask)
1. **If a task has 2+ independent parts, ALWAYS use parallel agents** — do not ask, just do it
2. **If you need to search/explore 2+ things, fan out Explore agents in parallel** — never search sequentially
3. **If you're generating code AND can build/test, run builds in background immediately** — don't wait to be asked
4. **If fixing multiple errors, spin up one agent per error/category** — never fix them one at a time
5. **If researching + generating, do both at once** — research agents + generation agents in parallel

### Parallel Agent Scenarios
- **Multiple independent errors/fixes** — one agent per error category
- **Large codebase searches** — fan out Explore agents instead of sequential searching
- **SQL generation across multiple tables** — research + generate in parallel
- **Log parsing** — split by error type or source file
- **Reading multiple files for context** — parallel Read calls, not sequential
- **Any task with independent subtasks** — always decompose and parallelize

### Background Tasks (always use, don't ask)
- **Builds (ninja, cmake)** — always run in background and continue working
- **Long MySQL imports or queries** — background them
- **Server restarts for testing** — background and continue working

### Environment
- Windows Terminal x64 / VS2022 Developer Command Prompt
- 128GB RAM, NVMe storage — hardware is not a bottleneck
- TrinityCore project with MySQL backend
- Multiple Claude Code tabs can each run their own agents — coordinate by staying in separate directories or worktrees when possible

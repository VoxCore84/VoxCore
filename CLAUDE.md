# RoleplayCore — Project Guide

## What This Is
TrinityCore-based WoW private server targeting the **12.x / Midnight** client, specialized for **roleplay**. Built on top of stock TrinityCore with significant custom systems.

## Build

| Config | Dir | Use |
|---|---|---|
| `x64-Debug` | `out/build/x64-Debug/` | Compilation, debugging |
| **`x64-RelWithDebInfo`** | `out/build/x64-RelWithDebInfo/` | **Primary runtime** (17s startup vs 60s Debug) |

- **Build**: `cd ~/VoxCore/out/build/x64-Debug && ninja -j20 2>&1`
- **Scripts only**: `cd ~/VoxCore/out/build/x64-Debug && ninja -j20 scripts 2>&1`
- **CMake reconfigure**: `cmake -B out/build/x64-Debug -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
- **Key CMake options**: `SCRIPTS=static`, `ELUNA=ON`, `TOOLS=ON`
- **Compiler**: MSVC (VS 2026), Generator: Ninja, C++20
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
5. Build with `ninja -j20 scripts`

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
- **22 slash commands**: `/build-loop`, `/check-logs`, `/parse-errors`, `/apply-sql`, `/soap`, `/lookup-spell`, `/lookup-item`, `/lookup-creature`, `/lookup-area`, `/lookup-faction`, `/lookup-emote`, `/lookup-sound`, `/decode-pkt`, `/parse-packet`, `/new-script`, `/new-sql-update`, `/smartai-check`, `/transmog-correct`, `/transmog-implement`, `/transmog-status`, `/todo`, `/wrap-up`
- **External repos**: wago tooling (`wago/`), tc-packet-tools (`tools-dev/tc-packet-tools/`), code-intel (`tools-dev/code-intel/`), claude-skills (`tools-dev/claude-skills/`)
- **External tools**: `ExtTools/` (WowPacketParser, wow.tools.local, DBC2CSV, Arctium, etc.)
- **GitHub**: `VoxCore84/RoleplayCore` (private), `gh` CLI authenticated
- Full inventory: auto-memory `tooling-inventory.md`

### Proactive Skill Reminders — MANDATORY

**The user should NEVER have to remember to run a slash command. Claude MUST remind them at the right moment.** Use this exact phrasing: *"Want me to run `/command`?"* or just run it if the context is unambiguous.

| When this happens... | ...remind/run this |
|---|---|
| User says "I'm done", "that's it", "wrapping up", conversation is winding down, or long silence after completing work | `/wrap-up` — *"Want me to run `/wrap-up`?"* |
| Server was restarted, crash mentioned, or debugging begins | `/check-logs` — just run it (auto-approved) |
| User mentions a build error or paste a build log | `/parse-errors` — just run it |
| C++ file was edited and work on it is complete | Remind: *"Ready to build in VS — those changes need compiling"* |
| SQL file was created or edited | `/smartai-check` (if SmartAI) or remind to `/apply-sql` |
| Writing new SQL update | `/new-sql-update` — just run it to get the right filename |
| User asks about transmog bugs or starts transmog work | `/transmog-status` — run it first to show current state |
| Multiple tasks mentioned or scope is expanding | Multi-tab suggestion (see BLOCKING OBLIGATION below) |
| Start of session | Auto-read `doc/session_state.md` + `todo.md` (see Session Start below) |
| User mentions a spell/item/creature/area by name without an ID | Run the appropriate `/lookup-*` to resolve it |

**Rules:**
- If in doubt, ask. A one-line reminder is cheap; forgetting a `/wrap-up` loses work.
- Never skip `/wrap-up` at end of session — if the conversation looks like it's ending, remind.
- `/check-logs` is always safe to run proactively — it's read-only.

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

## Session Start — MANDATORY (runs automatically, no slash command needed)

**Every new conversation MUST begin by doing these two things BEFORE responding to the user's first message:**

1. **Read `doc/session_state.md`** (if it exists) — check Active Tabs, pending handoffs, file ownership claims
2. **Read the `## Next Session` section of `todo.md`** from memory — this is your pre-loaded task list

If `doc/session_state.md` exists and has active tab assignments, announce what this tab should focus on. If the user's request conflicts with tab assignments, ask before proceeding.

If neither file exists or both are stale, proceed normally with the user's request.

## Work Style

**MANDATORY**: Always default to parallel execution. Hardware is not a constraint (Ryzen 9 9950X3D 12C/24T, 128GB DDR5, NVMe).

1. **2+ independent parts → parallel agents** — do not ask, just do it
2. **2+ searches → fan out Explore agents** — never search sequentially
3. **Code + build → run builds in background immediately**
4. **Multiple errors → one agent per error category**
5. **Builds, long queries, server restarts → always background**

### *** MULTI-TAB DELEGATION — BLOCKING OBLIGATION ***

**This is NOT optional. This is NOT "consider it." This is a HARD REQUIREMENT with specific triggers.**

The user runs multiple Claude Code tabs in Windows Terminal. Each tab is a separate conversation with full project access. Tabs are cheap (user has budget for multiple AI subscriptions). Single tabs doing too much burn context, lose focus, and produce worse results. **When a trigger fires, you MUST suggest a tab split. Do NOT silently continue in one tab.**

**HARD TRIGGERS — if ANY of these are true, you MUST suggest opening another tab:**

| # | Trigger | Example |
|---|---------|---------|
| 1 | User's request touches 2+ independent subsystems | "fix transmog bugs and also run the LoreWalker import" |
| 2 | Current task is growing beyond one focused objective | Started with SQL, now also debugging C++ and writing docs |
| 3 | A subtask has its own dedicated skill | `/transmog-implement`, `/transmog-correct`, `/transmog-status` can run standalone |
| 4 | Investigation + implementation are both needed | One tab researches and writes a plan, another implements |
| 5 | Task involves both C++ code changes AND SQL generation | These don't share files — perfect split |
| 6 | You're about to start a second unrelated fix | Stop. Suggest a tab for it instead |
| 7 | User says "also", "and then", "while you're at it" | Each "also" is a tab candidate |

**How to suggest it (use this exact format):**

> **Tab split recommended.** This has N independent parts:
> - **This tab**: [what we continue doing here]
> - **New tab**: Open a new Claude Code tab and tell it: `[exact instruction to paste]`
>
> Want me to write the handoff to `doc/session_state.md`?

**Coordination file:** `doc/session_state.md` is the multi-tab war room.
- Every tab reads it at session start (see Session Start above)
- Before starting work, claim your assignment in the Active Tabs table
- When done, update status and clear your claim
- If the file doesn't exist or is stale, recreate it

**What goes in the handoff:**
1. Exact slash command or instruction for the other tab
2. Which files that tab owns (prevent merge conflicts)
3. What this tab is NOT touching (so the other tab knows it's safe)
4. Any context the other tab needs (DB state, build status, blockers)

**Never do these in a single tab:**
- Transmog fixes + world DB cleanup + spell audit → 3 tabs
- Deep investigation + code implementation → 2 tabs
- Multiple bug fixes in different subsystems → 1 tab per subsystem
- C++ development + SQL generation for unrelated systems → 2 tabs
- Any task list with 3+ independent items → split across tabs

## Transmog UI / Midnight 12.x — Authoritative Rules

These rules are derived from retail 66263 packet captures and audit pass 2 findings.
When in conflict with earlier summaries or assumptions, these rules win.

### Two Separate DisplayType Concepts — Never Confuse Them

1. **DB2 `ItemAppearance.DisplayType`** (range 0-15): Per-IMAID classification for slot routing.
   Used in `DisplayTypeToEquipSlot()`. This is the *routing* DT.
2. **`TransmogOutfitSlotData::AppearanceDisplayType`** (range 0-4): Per-slot behavioral flag
   in ViewedOutfit/TransmogOutfits UpdateFields. This is the *behavioral* ADT.

Never use routing DT values where behavioral ADT values belong, or vice versa.

### Non-Negotiable Transmog Rules

- Do NOT use fake weapon option-0 rows. The real weapon appearance belongs on its
  selected option row from the retail wire-order arrays.
- Keep stored `TransmogOutfits` semantics separate from live `ViewedOutfit` semantics.
  They use different ADT values for the same logical state.
- Do NOT remove bridge defer/baseline behavior for slots 2 / 12 / 13 unless direct
  packet evidence proves it wrong.
- Prefer small surgical patches over broad rewrites.
- Always show an actual unified diff for code-changing tasks.
- Always run the local working build command after patching and report the real result.
- Do NOT claim success based only on compile if the behavioral model is wrong.

### Retail-Backed Target Model — 30-Row Slot Layout

30 total rows per outfit: 12 armor (SlotOption=0) + 9 MH options + 9 OH options.

**Armor rows** (TransmogOutfitSlot enum, option=0):
Head(0,0), Shoulder-Primary(1,0), Shoulder-Secondary(2,0), Back(3,0), Chest(4,0),
Tabard(5,0), Shirt/Body(6,0), Wrist(7,0), Hands(8,0), Waist(9,0), Legs(10,0), Feet(11,0)

**MH weapon option wire order**: 1, 6, 2, 3, 7, 8, 9, 10, 11
**OH weapon option wire order**: 1, 6, 7, 5, 4, 8, 9, 10, 11

There must be NO fake weapon option-0 rows.

### Stored `TransmogOutfits` Behavioral Semantics

| State | ADT | IDT | Notes |
|-------|-----|-----|-------|
| Empty row | 0 | 0 | Unassigned, skip |
| Assigned normal | 1 | 0 | Apply this IMAID |
| Hidden appearance | 3 | 0 | Apply hidden visual IMA (real hidden IMA ID, NOT zero) |
| Enchanted weapon (selected) | 1 | 1 | Real SpellItemEnchantmentID + IDT=1 |
| Paired placeholder (opts 8-11) | 4 | 4 | Not applicable — bookkeeping only |

### Live `ViewedOutfit` Behavioral Semantics

| State | ADT | IDT | Notes |
|-------|-----|-----|-------|
| Empty/equipped passthrough | 2 | 2 | Slot has no outfit appearance — show equipped item or nothing |
| Assigned normal | 1 | 0 | Apply this IMAID (SAME as stored — NOT ADT=2) |
| Hidden appearance | 3 | 0 | Apply hidden visual IMA |
| Enchanted weapon (selected) | 1 | 1 | Real enchant + IDT=1 |
| Paired placeholder (opts 8-11) | 4 | 4 | Not applicable |

**Key difference**: Only EMPTY rows differ — Stored empty = `0/0`, Viewed empty = `2/2`.
Assigned rows use ADT=1 in BOTH contexts. ADT=2 is NEVER used for assigned rows.

### Hidden Appearance IMA IDs (confirmed retail)

77343=shoulder, 77344=head, 77345=cloak, 83202=shirt, 83203=tabard,
84223=belt, 94331=gloves, 104602=chest, 104603=boots, 104604=bracers, 198608=pants

Detection: Use ItemID-based matching (10 known hidden items from CollectionMgr).
Do NOT rely on `ItemDisplayInfoID==0` (cloak has `ItemDisplayInfoID=146518`).

### Required Preservation

- `MainHandOption` / `OffHandOption` are real selected option enums, not booleans.
- `SMSG_TRANSMOG_OUTFIT_SLOTS_UPDATED` must remain a full 30-row behavioral slot echo.
- `DisplayTypeToEquipSlot()` must include `case 14: return EQUIPMENT_SLOT_OFFHAND`.
- Bridge defer behavior for slots 2 / 12 / 13 must be preserved.

### Confidence Levels

- ADT 0/1 for stored: HIGH (audit pass 2 + retail packets)
- ADT 1 for viewed assigned: HIGH (packet capture confirmed — non-empty ViewedOutfit rows show ADT=1)
- ADT 2/2 for viewed empty: HIGH (packet capture confirmed — empty ViewedOutfit rows show ADT=2/IDT=2)
- ADT 3 for hidden: HIGH (session 70 fix, retail confirmed)
- ADT 4 for paired placeholders: HIGH (session 70 fix, retail confirmed)
- IDT 1 for enchanted weapons: HIGH (packet capture shows SpellItemEnchantmentID + IDT=1)

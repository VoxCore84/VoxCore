# Session 101 — NPC Tooling, Placement Workflow & Crash Investigation

**Date**: 2026-03-08
**Location**: Boralus Harbor (Map 1643, Kul Tiras)
**Focus**: GM command quality-of-life, NPC placement workflow, crash analysis

---

## 1. NPC Wandering Fix — `.npc set movetype stay`

### What We Did
Used stock TrinityCore GM commands to stop NPCs from wandering:
```
.npc set movetype stay
.npc set wanderdistance 0
```
Both write to the `creature` table (`MovementType = 0`, `wander_distance = 0`).

### Problem Discovered: Kill/Respawn Side Effects
Both commands force a **kill and instant respawn** cycle:
```cpp
// cs_npc.cpp — both handlers do this:
creature->setDeathState(JUST_DIED);
creature->Respawn();
```

This causes two issues:
1. **Visual disruption** — NPC dies and pops back, looks janky
2. **NPC flags may be lost** — After respawn, vendor/gossip/quest interaction can break. The `setDeathState(JUST_DIED)` at line 2369 clears ALL NPC flags (`ReplaceAllNpcFlags(UNIT_NPC_FLAG_NONE)`). The `JUST_RESPAWNED` handler (line 2420) should restore them via `ChooseCreatureFlags()`, but in practice the rapid death/respawn on the 12.x client appears to cause interaction loss.

### Proposed Fix: Remove the Kill/Respawn Entirely
The kill is **unnecessary**. `MotionMaster::Initialize()` already clears and recreates all movement generators properly. The creature just stops moving — no death needed, no flags touched.

**What to change** in `cs_npc.cpp`:
- `HandleNpcSetMoveTypeCommand` (line 828-832): Remove the `setDeathState(JUST_DIED)` + `Respawn()` block
- `HandleNpcSetWanderDistanceCommand` (line 925-929): Same removal

The `SetDefaultMovementType()` + `GetMotionMaster()->Initialize()` calls that precede the kill already do the job. The creature stays alive, keeps all its flags, and immediately adopts the new movement behavior.

**Status**: NOT YET IMPLEMENTED — needs code change + build + test

---

## 2. NPC Placement Addon Research

### The Problem
Placing NPCs with `.npc move` requires standing in the exact right spot. No visual preview, no mouse-based placement, no fine-tuning UI.

### What Exists (None Target 12.x)

| Tool | Client | Features | Limitation |
|------|--------|----------|------------|
| **GM Genie** | 3.3.5 / 4.3.4 | Builder UI with X/Y/Z nudge buttons, clickable spawn links | Way too old |
| **MarsAdmin** | 7.3.5 | GM Genie successor for Legion | Still pre-modern |
| **Epsilon ObjectMover** | BfA-era | Keybind-driven move/rotate, wraps `.gobject` commands | Closest to 12.x API |
| **Noggit Red** | External editor | Actual 3D gizmos for placement | Desktop app, not in-game |

### Key Finding
**No true "ghost preview + click-to-place" system exists** for any WoW client. The WoW addon API doesn't expose a way to render arbitrary 3D models at arbitrary world positions. All existing tools wrap dot-commands in a UI.

### Recommendation: Build a Custom 12.x Addon
A lightweight addon that:
1. Wraps `.cnpc`, `.npc add`, `.npc move`, `.gobject spawn` commands in a frame with buttons
2. Uses player position + facing as the spawn point
3. Provides X/Y/Z offset increment/decrement buttons (like GM Genie's builder)
4. Keybinds for fast workflow
5. Uses Epsilon ObjectMover source as reference for modern addon API patterns

**Status**: FUTURE PROJECT — not started

---

## 3. Persistence of In-Game GM Changes

### The Problem
In-game changes (`.npc move`, `.npc set movetype`, `.npc set faction`, waypoints) go **directly into the `world` database** and are **NOT tracked in git**. This means:
- SQL updates that touch the same rows will overwrite them
- DB restores will lose them
- They don't exist anywhere in the repo

### Solution: SQL Export Workflow
After an in-game editing session, export changes as SQL update files:
```sql
-- sql/updates/world/master/YYYY_MM_DD_NN_world.sql
UPDATE `creature` SET `position_x`=..., `position_y`=..., `position_z`=...,
  `orientation`=..., `wander_distance`=0, `MovementType`=0
WHERE `guid`=<guid>;
```

### Possible Automation
Build a script/tool that:
1. Queries recently modified creature rows (by timestamp or GUID range)
2. Generates an idempotent SQL update file
3. Names it with the correct `YYYY_MM_DD_NN_world.sql` convention
4. Ready to commit to git

**Status**: NOT YET BUILT — concept only

---

## 4. `.npc copy` Command — IMPLEMENTED

### What It Does
Target an NPC, stand where you want the copy, type `.npc copy`. One step instead of three (`.npc info` → note entry → `.npc add <entry>`).

### Implementation Details
**File**: `src/server/scripts/Custom/npc_copy_command.cpp`
**Registration**: Added to `custom_script_loader.cpp`
**Permission**: Same as `.npc add` (`RBAC_PERM_COMMAND_NPC_ADD = 571`)

### What It Copies (Everything Per-Spawn)

| Table | Data Copied |
|-------|------------|
| **creature** | modelid, equipment, movement type, wander distance, npcflags, unit_flags (1/2/3), phase, scale, script, spawn difficulties, spawn time |
| **creature_addon** | mount, emote, stand state, sheath, anim kits, auras, vis flags, PvP flags, visibility distance (PathId intentionally set to 0 — waypoints are position-relative) |
| **creature_movement_override** | hover, chase, random movement, interaction pause timer |
| **creature_static_flags_override** | all 8 static flag columns per difficulty |
| **roleplay.creature_extra** | custom scale, display lock, display/native display overrides, gender lock, swim/gravity/fly flags |

### Technical Approach
1. Creates base creature at player position using `.npc add` flow (`CreateCreature` + `SaveToDB`)
2. SQL `UPDATE ... JOIN` copies per-spawn overrides from source to new GUID
3. SQL `INSERT ... SELECT` copies addon/movement/static flags/roleplay rows
4. In-memory `CreatureData` synced from source for immediate correctness
5. Creature spawned from DB via `CreateCreatureFromDB`
6. Per-spawn addon visuals (mount, emote, auras, etc.) applied live for immediate visual fidelity
7. Registered in grid via `AddCreatureToGrid`

### What It Preserves From the Player
- Position (X/Y/Z where you're standing)
- Orientation (direction you're facing)
- Map

### Edge Cases Handled
- Temporary summons rejected (no SpawnId)
- Template addon auras cleared before applying per-spawn addon auras (prevents stacking)
- PathId set to 0 for copies (waypoint coordinates are world-absolute, not relative)

**Status**: CODE COMPLETE — needs build + test

---

## 5. Worldserver Crash Investigation

### Timeline
- **12:27** — Server started (26-second startup)
- **12:28:09** — 15 `.npc add` commands in the SAME SECOND at identical coordinates
- **12:28–12:33** — Rapid-fire `.npc move`, `.npc del`, `.npc set faction` commands
- **12:33:25** — Last logged GM command
- **~12:34** — Server crashed (no crash dump, no error in logs)

### Probable Cause
**Use-after-free from rapid NPC manipulation**. `.npc move` internally does:
```cpp
creature->CleanupsBeforeDelete();
delete creature;
creature = Creature::CreateCreatureFromDB(db_guid, map, true, true);
// No null check on creature after this!
```

If `CreateCreatureFromDB` returns null (grid issue, DB error, 15 NPCs stacked on same point), subsequent code dereferences a null pointer → silent crash with no dump.

### Findings
- **No crash dump** (`.dmp`) found in runtime directory
- **No assertion/exception** in Server.log
- **No error** in DBErrors.log beyond normal startup warnings
- Server silently terminated

### Recommended Actions

#### A. Enable Windows Crash Dumps
Configure Windows Error Reporting or use a custom exception handler to generate `.dmp` files on crash. This gives us a stack trace next time.

#### B. Add Null Guards to NPC Command Handlers
After every `delete creature` + `CreateCreatureFromDB` cycle in cs_npc.cpp, add:
```cpp
creature = Creature::CreateCreatureFromDB(db_guid, map, true, true);
if (!creature)
{
    handler->SendSysMessage("Failed to recreate creature from database.");
    handler->SetSentErrorMessage(true);
    return false;
}
```

This turns a crash into a graceful error message. Commands affected:
- `HandleNpcMoveCommand`
- `HandleNpcAddCommand` (already has partial check)
- Any other handler that does delete + recreate

**Status**: NOT YET IMPLEMENTED — needs code changes

---

## 6. Summary of Action Items

### Ready to Build & Test
- [x] `.npc copy` command (code complete in `npc_copy_command.cpp` + registered in loader)

### Needs Code Changes
- [ ] Remove kill/respawn from `.npc set movetype` and `.npc set wanderdistance` handlers
- [ ] Add null guards to NPC command handlers (`.npc move`, etc.)
- [ ] Enable crash dump generation for worldserver

### Future Projects
- [ ] Custom 12.x GM placement addon (keybind-driven move/rotate UI)
- [ ] SQL export tool for in-game changes (auto-generate update files from DB diffs)
- [ ] `.npc stop` convenience command (combines movetype stay + wanderdistance 0 in one command, no kill)

### Boralus Harbor Session Data
All the NPC placement work done in-game (faction changes, moves, deletions, spawns) is currently **only in the database**. These changes need to be exported as SQL update files and committed to git before any world DB reset, or they will be lost.

---

## Files Created/Modified This Session

| File | Action | Purpose |
|------|--------|---------|
| `src/server/scripts/Custom/npc_copy_command.cpp` | **Created** | `.npc copy` command implementation |
| `src/server/scripts/Custom/custom_script_loader.cpp` | **Modified** | Registered `AddSC_npc_copy_command()` |
| `doc/session_101_report.md` | **Created** | This report |

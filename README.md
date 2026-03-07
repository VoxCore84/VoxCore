# VoxCore

**TrinityCore-based WoW 12.x / Midnight private server for roleplay.**

## What This Is

VoxCore is a heavily customized fork of [TrinityCore](https://github.com/TrinityCore/TrinityCore) targeting the retail 12.x (Midnight) client. It is a solo-developed private server project built specifically for roleplay, with thousands of commits on top of the upstream codebase adding custom systems, appearance tools, and AI companions.

## Custom Systems

- **Roleplay Core** — Central singleton managing creature extras, custom NPCs, and player extras
- **Companion Squad** — DB-driven NPC companion system with role-based AI (tank, healer, DPS) and formation movement
- **Custom NPCs** — Player-race NPCs with full equipment and appearance customization via `.cnpc` commands
- **Display / Transmog** — Per-slot appearance overrides and full `TransmogOutfit` handling for the 12.x wardrobe UI
- **Visual Effects** — Persistent SpellVisualKit effects with late-join synchronization
- **Player Morph** — Persistent player morph, scale, and remorph system
- **CreatureOutfit** — NPC appearance overlay system for outfit customization
- **Skyriding** — Dragonriding / skyriding spell scripts
- **Toys & Teleports** — Custom toy items and wormhole generator teleports

## Tech Stack

| Component | Details |
|-----------|---------|
| Language | C++20 |
| Compiler | MSVC (Visual Studio 2026) |
| Build | CMake + Ninja |
| Database | MySQL 8.0 (5 databases: auth, characters, world, hotfixes, roleplay) |
| Scripting | Eluna (Lua engine integration) |
| Platform | Windows (primary) |

## Building

VoxCore uses CMake presets. See `CMakePresets.json` for available configurations:

| Preset | Use |
|--------|-----|
| `x64-Debug` | Development and debugging |
| `x64-RelWithDebInfo` | Primary runtime (significantly faster startup) |

Key CMake options: `SCRIPTS=static`, `ELUNA=ON`, `TOOLS=ON`.

## Project Structure

```
src/server/game/
    RolePlay/              # Core roleplay singleton
    Companion/             # Companion squad AI system
    Entities/Creature/     # CreatureOutfit overlay
src/server/scripts/
    Custom/                # All custom scripts
        Companion/         # Companion AI + commands
        RolePlayFunction/  # .display and .effect handlers
    Commands/              # Chat command handlers
sql/
    RoleplayCore/          # One-time setup scripts
    updates/               # Incremental update migrations
```

## License

GPL 2.0 — inherited from TrinityCore. See [COPYING](COPYING).

## Credits

- [TrinityCore](https://github.com/TrinityCore/TrinityCore) — the open-source MMORPG framework this project is built on
- [Eluna](https://github.com/ElunaLuaEngine/Eluna) — Lua scripting engine integration

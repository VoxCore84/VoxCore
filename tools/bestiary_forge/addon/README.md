# BestiaryForge v3.0 — Server-Assisted Creature Spell Sniffer

A WoW addon + server-side sniffer that captures **every spell cast by every creature** in real time. Built for TrinityCore-based private servers running the 12.0 (Midnight) client.

## What It Does

BestiaryForge maps creature entries to their spell repertoire by combining two data sources:

1. **Server sniffer** (C++ hooks) — Sees ALL creature spell casts including instant, hidden, and no-castbar abilities. Broadcasts spell data to the addon via addon messages.
2. **Visual scraper** (Lua OnUpdate) — Polls castbars and auras visible on screen at 10Hz as a fallback and visual confirmation layer.

When you target a creature, the server also sends its full `creature_template_spell` list so you can see what's already in the DB vs. what's been newly observed.

## Requirements

- TrinityCore fork (tested on 12.x / Midnight branch)
- Eluna Lua Engine enabled (`ELUNA=ON` in CMake)
- 3 small core patches (see [SERVER_SETUP.md](SERVER_SETUP.md))

## Installation

### Client (Addon)

Copy the `BestiaryForge/` folder into your WoW `Interface/AddOns/` directory.

### Server

See **[SERVER_SETUP.md](SERVER_SETUP.md)** for complete instructions including:
- Core C++ patches (3 files, ~30 lines total)
- Custom script (`bestiary_sniffer.cpp`)
- Eluna server script (`bestiary_sniffer_server.lua`)
- Script loader registration

## Usage

- **Minimap button**: Left-click opens the browser, right-click exports data
- **Browser**: Searchable creature list (left), spell detail table (right) with school colors, cast/aura counts, zone tracking
- **Debug mode**: Toggle via the Debug button — shows raw scraper and server messages in chat
- **Auto-target sniff**: Targeting any hostile NPC automatically queries the server for its full spell list
- **Right-click ignore**: Right-click a spell row to blacklist it, right-click "Ignore NPC" to blacklist a creature
- **Export**: Pipe-delimited text format, copy from the export window (Ctrl+A, Ctrl+C)

## BFRG Protocol

The addon and server communicate via addon messages on the `BFRG` prefix.

### Server to Client

| Type | Format | Description |
|------|--------|-------------|
| `SC` | `SC\|entry\|spellID\|school\|name` | Spell Cast complete |
| `SS` | `SS\|entry\|spellID\|school\|name` | Spell Start (cast begun) |
| `CF` | `CF\|entry\|spellID\|school\|name` | Channel Finished |
| `SL` | `SL\|entry\|count\|spellID1,spellID2,...` | Spell List from DB |
| `CI` | `CI\|entry\|name\|faction\|minLvl\|maxLvl\|class` | Creature Info |

### Client to Server

| Type | Format | Description |
|------|--------|-------------|
| `SL` | `SL\|entry` | Request spell list for creature entry |
| `CI` | `CI\|entry` | Request creature info for entry |

## Data Storage

All data is stored in `BestiaryForgeDB` (WoW SavedVariables). Structure:

```lua
BestiaryForgeDB = {
    version = 3,
    collector = "PlayerName-RealmName",
    creatures = {
        [12345] = {  -- creature template entry
            name = "Stygian Runesmith",
            spells = {
                [345236] = {
                    name = "Crush Armor",
                    school = 1,          -- Physical
                    castCount = 14,
                    auraCount = 0,
                    zones = { ["The Maw"] = true },
                    difficulties = { [0] = true },
                    serverConfirmed = true,
                    dbKnown = true,      -- exists in creature_template_spell
                },
            },
        },
    },
}
```

## License

MIT

# Sniffing Pipeline — Dummy Guide

> **TL;DR**: You sniff packets in WoW, this pipeline turns them into SQL that fills gaps in your world database. One command does everything.

---

## Visual Overview

```
 YOU PLAY WOW                        THE PIPELINE
 ===============                     ====================================

 +--------------+     .pkt file      +------------------+
 | WoW Client   | -----------------> | WowPacketParser  |
 | (retail/Ymir)|    (packet log)    | (WPP)            |
 +--------------+                    +--------+---------+
                                              |
                                    _parsed.txt + _world.sql + _hotfixes.sql
                                              |
                                   +----------v-----------+
                                   |   process_sniff.py   |  <-- ONE COMMAND
                                   |   (orchestrator)     |
                                   +----+-----+-----+----+
                                        |     |     |
                          +-------------+  +--+--+  +-------------+
                          |                |     |                |
                +---------v--------+ +----v----+ +------v-------+
                | parse_sniff.py   | | WPP SQL | | parse_addon  |
                | (gap analysis)   | | files   | | _data.py     |
                +--------+---------+ +----+----+ +------+-------+
                         |                |             |
                   sniff_import.sql  (manual)    addon_import.sql
                         |                             |
                         +-------------+---------------+
                                       |
                              +--------v--------+
                              |   MySQL world   |
                              |   database      |
                              +-----------------+
                                       |
                              +--------v--------+
                              | sniff_coverage   |
                              | (zone report)    |
                              +-----------------+
```

### What Each Piece Does

| Component | What It Does | You Touch It? |
|-----------|-------------|---------------|
| **WoW Client** | Generates `.pkt` packet log while you play | Yes — you play the game |
| **WPP** | Decodes binary packets into readable text + SQL | No — pipeline runs it |
| **parse_sniff.py** | Scans decoded text for creature spells, emotes, auras, levels, types | No — pipeline runs it |
| **parse_addon_data.py** | Reads VoxSniffer addon data (vendor items, dialogue, quests) | No — pipeline runs it |
| **process_sniff.py** | Runs everything above in order, imports SQL to DB | **Yes — you run this** |
| **sniff_coverage.py** | Shows which zones have good data and which need sniffing | Optional |
| **start-worldserver.sh** | Launches TC server + auto-runs pipeline on exit | Yes — when using Ymir |

---

## The 3 Scenarios

### Scenario 1: Ymir (local TC server) — Fully Automatic

You don't even think about the pipeline. It runs itself.

```bash
# Start the server (this is all you do)
bash ~/VoxCore/tools-dev/tc-packet-tools/start-worldserver.sh
```

1. Server starts, you log in with retail WoW client
2. You play, walk around zones, interact with NPCs
3. You type `server exit` in the console (or close the window)
4. **Pipeline auto-runs**: WPP → gap analysis → addon data → summary
5. SQL files appear in `PacketLog/` folder

### Scenario 2: Standalone Retail Sniff — One Command

You have a `.pkt` file from a retail sniffing session (Ymir proxy capture).

```bash
# Full pipeline: parse + analyze + import to DB
python3 process_sniff.py "C:/path/to/your/sniff.pkt"

# Generate SQL but DON'T apply to DB (safer, review first)
python3 process_sniff.py "C:/path/to/your/sniff.pkt" --no-import

# Already parsed by WPP? Skip WPP step
python3 process_sniff.py "C:/path/to/your/sniff.pkt" --no-wpp

# Show zone coverage after processing
python3 process_sniff.py "C:/path/to/your/sniff.pkt" --coverage
```

### Scenario 3: Just Addon Data — No Sniff Needed

You played retail WoW with VoxSniffer addon running. No packet capture needed.

```bash
# Process just the addon SavedVariables
python3 process_sniff.py --addon-only
```

This reads `VoxSnifferDB.lua` from your WoW install and generates SQL for any missing creature data, dialogue, vendor items, etc.

---

## What Data Gets Captured

### From WPP (packet decoding)
- **Creature query responses**: type, family, classification, HP/mana multipliers, expansion
- **Creature spawns**: positions, orientations, equipment
- **Spells, auras, emotes**: what NPCs cast and do
- **Vendor lists, quest associations, gossip menus**

### From parse_sniff.py (targeted gap-fill)
These are things WPP decodes but doesn't generate SQL for:

| Gap | What's Missing | Table Fixed |
|-----|---------------|-------------|
| Creature spells | NPCs casting spells not in DB | `creature_template_spell` |
| Emotes | NPCs with emote states (kneel, work, etc.) | `creature_template_addon` |
| Auras | Persistent buffs on NPCs | `creature_template_addon` |
| Type/Family | Creature classification from QCR packets | `creature_template` |
| HP/Mana scaling | Expansion + difficulty modifiers | `creature_template_difficulty` |

### From VoxSniffer addon (client-side Lua APIs)
Things the addon captures that packets miss:

| Data | Source | Table Fixed |
|------|--------|-------------|
| Creature type/class | Nameplate scanning | `creature_template` |
| NPC dialogue | Chat events (say, yell, emote) | `creature_text` |
| Vendor inventory | Merchant interaction | `npc_vendor` |
| Quest givers/enders | Quest frame events | `creature_queststarter/ender` |
| Creature auras | Nameplate buff scanning | `creature_template_addon` |

---

## File Locations

```
VoxCore/
  wago/
    process_sniff.py        <-- THE command you run
    parse_sniff.py          <-- gap analysis (called by process_sniff)
    parse_addon_data.py     <-- addon data (called by process_sniff)
    sniff_coverage.py       <-- zone coverage report
    wago_common.py          <-- shared DB/CSV utilities
    sniff_sessions.json     <-- tracks what you've already processed
    sniff_enrich.py         <-- DEPRECATED (ignore this)

  tools-dev/tc-packet-tools/
    start-worldserver.sh    <-- server launcher with auto-pipeline

  tools-dev/VoxSniffer/     <-- WoW addon source (install in retail)
    Core.lua
    VoxSniffer.toc

  ExtTools/WowPacketParser/
    WowPacketParser.exe     <-- WPP binary
```

---

## Output Files

After running the pipeline, you get:

| File | What | Auto-imported? |
|------|------|----------------|
| `sniff_import.sql` | Gap-fill SQL from parse_sniff | Yes (unless `--no-import`) |
| `addon_import.sql` | Gap-fill SQL from VoxSniffer addon | Yes (unless `--no-import`) |
| `*_world.sql` | WPP creature/GO SQL | **No** — review first, use `/apply-sql` |
| `*_hotfixes.sql` | WPP hotfix SQL | **No** — review first |
| `sniff_sessions.json` | Processing history (dedup) | N/A |

---

## Quick Reference Card

```
MOST COMMON COMMANDS:
  python3 process_sniff.py <file.pkt>                    # full pipeline
  python3 process_sniff.py <file.pkt> --no-import        # generate SQL only
  python3 process_sniff.py <file.pkt> --no-wpp           # skip WPP (already parsed)
  python3 process_sniff.py --addon-only                  # just addon data
  python3 sniff_coverage.py                              # zone coverage report
  python3 sniff_coverage.py --gaps                       # only show zones needing work
  python3 sniff_coverage.py --continent 0                # Eastern Kingdoms only

YMIR SERVER:
  bash ~/VoxCore/tools-dev/tc-packet-tools/start-worldserver.sh
  bash ~/VoxCore/tools-dev/tc-packet-tools/start-worldserver.sh --parse <file.pkt>

FLAGS:
  --no-import     Generate SQL but don't apply to database
  --no-wpp        Skip WPP parsing (use existing _parsed.txt)
  --addon-only    Only process VoxSniffer addon data
  --coverage      Show zone coverage report after processing
  --force         Reprocess even if already in manifest
  --out-dir DIR   Write output files to specific directory
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Already processed (hash ...)" | Add `--force` to reprocess |
| "WPP not found" | Check `ExtTools/WowPacketParser/WowPacketParser.exe` exists |
| "No parsed text found" | WPP failed — check .NET 9.0 runtime installed |
| "VoxSnifferDB.lua not found" | Install VoxSniffer addon, play retail, then run |
| "pymysql not found" | `python3 -m pip install pymysql` |
| "slpp not found" | `python3 -m pip install slpp` |
| MySQL connection refused | Start MySQL (UniServerZ) first |
| High "Pokemon %" in WPP | WoW build missing from WPP mapping — run `wpp-add-build.sh` |

---

## How It All Connects (The Big Picture)

```
  SNIFFING                    PROCESSING                    DATABASE
  ========                    ==========                    ========

  Retail WoW ─── Ymir ───┐
  (you play)    (proxy)   │
                          ├──► .pkt file ──► process_sniff.py ──► world DB
  TC Server ──────────────┘                       │
  (you play)                                      │
                                                  ├──► sniff_import.sql
  VoxSniffer addon ──────────────────────────────►├──► addon_import.sql
  (runs in retail client)                         └──► coverage report

  BEFORE: 5 manual steps, subprocess MySQL, hand-rolled Lua parser
  AFTER:  1 command, persistent DB connections, battle-tested libraries
```

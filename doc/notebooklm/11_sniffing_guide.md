# Packet Sniffing Guide for VoxCore (Midnight 12.x)

> **TL;DR** — You play WoW retail normally with a small background tool running. It silently records all the data the server sends your client into a file. You share that file with us, and we turn it into database entries that make our private server more accurate and complete. That's it — no hacking, no modding, just playing the game.

---

## Quick Start (5-Minute Version)

If you just want the shortest path to contributing sniffs:

1. Install **[Npcap](https://nmap.org/npcap/)** (requires admin) — check **"WinPcap API-compatible Mode"** during install
2. Download **[Ymir](https://github.com/TrinityCore/ymir/releases)** (grab the latest `12.x` retail release) and extract it somewhere
3. Delete your WoW `_retail_\Cache` folder
4. Run `ymir_retail.exe`, then launch WoW and play normally
5. When done, close WoW — your `.pkt` file is in Ymir's `dump\` folder
6. Compress the `.pkt` file and share it with us on Discord

That's it. Everything below is the deep dive for those who want to understand what's happening and how to maximize the value of their sniffs.

---

## Table of Contents

1. [What Is Packet Sniffing?](#what-is-packet-sniffing)
2. [Why Do We Need It?](#why-do-we-need-it)
3. [What Data Gets Captured?](#what-data-gets-captured)
4. [Tools You'll Need](#tools-youll-need)
5. [Step-by-Step Setup](#step-by-step-setup)
6. [How to Capture Good Sniffs](#how-to-capture-good-sniffs)
7. [Parsing Sniffs with WowPacketParser (Optional)](#parsing-sniffs-with-wowpacketparser-optional)
8. [Submitting Your Sniffs](#submitting-your-sniffs)
9. [Safety & Privacy](#safety--privacy)
10. [Tips for Being an Ace Sniffer](#tips-for-being-an-ace-sniffer)
11. [Troubleshooting](#troubleshooting)
12. [FAQ](#faq)

---

## What Is Packet Sniffing?

When you play World of Warcraft, your client and Blizzard's servers are constantly exchanging **packets** — small chunks of data that describe everything happening in the game world. Every NPC that spawns near you, every quest you pick up, every spell you cast, every vendor's inventory you open — it's all transmitted as packets.

**Packet sniffing** is the process of passively recording those packets into a file (a `.pkt` file) while you play. Think of it like a dashcam for your WoW session — it doesn't change anything about how you play, it just quietly logs what the server tells your client.

Once captured, a second tool called **WowPacketParser (WPP)** reads those `.pkt` files and translates the raw data into structured database entries (SQL) that we can import directly into the server.

**The pipeline at a glance:**

```
  Blizzard Servers  <--- packets --->  WoW Client
                                          |
                                    (passively recorded by Ymir)
                                          |
                                          v
                                     .pkt file
                                          |
                                    (parsed offline by WPP)
                                          |
                                          v
                                   SQL + text output
```

---

## Why Do We Need It?

Private servers need to recreate the game world from scratch. Blizzard doesn't publish their server-side data, so the emulation community reverse-engineers it from what the client receives during normal gameplay.

**One person can only be in one place at a time.** To build a complete Midnight experience, we need coverage of:

- Every zone and subzone
- Every NPC — their stats, equipment, patrol paths, gossip text
- Every quest chain — objectives, rewards, phasing
- Every vendor, trainer, and flight master inventory
- Every gameobject placement (mailboxes, chairs, portals, chests)
- Spell visuals, auras, and effects

**More sniffers = more zones covered = a more complete and accurate server.** Even casual play sessions produce valuable data — just walking through a town captures dozens of NPC spawns, positions, and equipment sets.

---

## What Data Gets Captured?

Here's a breakdown of what the sniffer records when you're near something or interact with it:

### Automatically Captured (Just By Being Nearby)

| Data Type | What You Get |
|-----------|-------------|
| **Creatures/NPCs** | Spawn position, display/model ID, faction, level, health, equipment, emotes, flags |
| **Gameobjects** | Position, type, display ID, state, flags |
| **Spells & Auras** | Visual effects, buff/debuff data on you and nearby players/NPCs |
| **Player Movement** | Zone/area transitions, phasing info |

### Captured By Interacting

| Action | Data You Generate |
|--------|------------------|
| **Talk to an NPC** | Gossip menus, gossip text, available options |
| **Accept/complete a quest** | Full quest data — text, objectives, rewards, phasing |
| **Open a vendor** | Complete vendor inventory with prices |
| **Visit a trainer** | Full trainer spell list |
| **Use a flight master** | Taxi network connections |
| **Loot a mob/chest** | Loot table entries |
| **Open your pet/mount journal** | Mount and pet data |
| **Cast spells** | Spell effect data, cooldowns, restrictions |
| **Follow an NPC** | Patrol waypoints and path data |

### The Full Picture

Sniffs can provide data for **100+ database tables** including:

- `creature_template` — NPC base stats, flags, faction
- `creature` — spawn positions, waypoints
- `quest_template` — objectives, text, rewards
- `npc_vendor` — vendor inventories
- `gameobject` — world object placements
- Spell effects, auras, visuals
- Achievement criteria, POIs, transport paths, and much more

---

## Tools You'll Need

### 1. Ymir (The Sniffer)

| | |
|---|---|
| **What** | A network packet capture tool purpose-built for WoW |
| **Repo** | [github.com/TrinityCore/ymir](https://github.com/TrinityCore/ymir) |
| **Download** | [Releases page](https://github.com/TrinityCore/ymir/releases) — grab the release matching your WoW version |
| **Platform** | Windows 10/11 |
| **Dependency** | [Npcap](https://nmap.org/npcap/) (free network capture driver — requires admin to install) |

**Available versions** (as of March 2026):

| WoW Version | Ymir Release | Binary |
|-------------|-------------|--------|
| Retail (Midnight 12.x) | `12.0.1.66263` | `ymir_retail.exe` |
| MoP Classic (5.5.x) | `5.5.3.66290` | `ymir_classic.exe` |
| Titan Classic (3.80.x) | `3.80.0.66130` | `ymir_classic.exe` |
| TBC Classic (2.5.x) | `2.5.5.65895` | `ymir_classic.exe` |
| Classic Era (1.15.x) | `1.15.8.66129` | `ymir_classic.exe` |

### 2. WowPacketParser — WPP (The Parser)

| | |
|---|---|
| **What** | Converts raw `.pkt` files into SQL and human-readable text |
| **Repo** | [github.com/TrinityCore/WowPacketParser](https://github.com/TrinityCore/WowPacketParser) |
| **Download** | [Nightly builds](https://github.com/TrinityCore/WowPacketParser/actions) (Windows Release recommended — requires GitHub login) |
| **Dependency** | [.NET 9.0 Runtime](https://dotnet.microsoft.com/download/dotnet/9.0) (the Runtime is sufficient — you don't need the full SDK) |
| **Platform** | Windows, Linux, macOS |

> **You don't have to run WPP yourself.** If you just want to capture and share the raw `.pkt` files, we handle all the parsing on our end. But it's useful to understand the full pipeline, and it's there if you want to explore what your sniffs contain.

---

## Step-by-Step Setup

### Part A — Install the Sniffer (One-Time)

**Step 1: Install Npcap**

1. Download from [nmap.org/npcap](https://nmap.org/npcap/)
2. Run the installer **as Administrator**
3. During installation, **check "WinPcap API-compatible Mode"** — Ymir requires this
4. Finish the installer and reboot if prompted

**Step 2: Download Ymir**

1. Go to the [Ymir Releases page](https://github.com/TrinityCore/ymir/releases)
2. Download the release matching your WoW version (for Midnight retail: `12.0.1.66263`)
3. Extract to a folder **outside** your WoW installation directory (important — don't put it inside the WoW folder)
4. Example location: `C:\Tools\Ymir\`

**Step 3: Verify your folder structure**

```
C:\Tools\Ymir\
+-- ymir_retail.exe      (or ymir_ptr.exe for PTR)
+-- dump\                (created automatically when you run it -- sniffs go here)
```

### Part B — Capture a Sniff Session

Every time you want to sniff:

**1. Delete the WoW cache folder**
   - Navigate to your WoW install (e.g., `C:\World of Warcraft\_retail_\`)
   - Delete the `Cache` folder entirely (right-click > Delete, or Shift+Delete)
   - This forces the client to request fresh data from the server instead of using stale cached data

**2. Start Ymir BEFORE launching WoW**
   - Run `ymir_retail.exe` (use `ymir_ptr.exe` if sniffing on PTR)
   - A console window will appear — leave it open in the background
   - You should see output indicating it's listening for connections

**3. Launch WoW normally**
   - Open through Battle.net or directly — nothing special here
   - Log in and play as you normally would

**4. Play the game**
   - Everything you see and interact with is being recorded automatically
   - See the [tips section](#tips-for-being-an-ace-sniffer) for how to maximize data quality

**5. When you're done, close WoW**
   - Exit the game client normally (log out > exit)
   - Ymir will automatically shut down within 1-5 seconds
   - Your `.pkt` file(s) will be in the `dump\` subfolder next to `ymir_retail.exe`

---

## How to Capture Good Sniffs

Not all sniffs are equal. Here's how to make yours as valuable as possible:

### The Basics

- **Clear your cache** every single time before launching — stale cache means stale data
- **Play in populated areas** where NPCs and gameobjects are plentiful
- **Interact with everything** — talk to NPCs, open vendors, browse trainers, accept and complete quests
- **Don't fly over zones at max speed** — you need to be in render range for data to be captured

### Maximize NPC Data

- **Walk slowly through towns and hubs** — this ensures every NPC within visual range gets captured
- **Talk to every NPC** even if you don't need anything from them — this captures gossip menus and dialog text
- **Follow patrolling NPCs** for a full patrol loop — this captures their complete waypoint paths
- **Visit vendors and trainers** and scroll through their full inventory/spell list

### Maximize Quest Data

- **Accept every quest** you can — captures quest text, objectives, and any phasing changes
- **Abandon and re-accept** quests to capture the full offer/accept flow
- **Complete quests at the turn-in NPC** to capture reward data and completion text
- **Open your map** during quests to capture quest POI (Point of Interest) markers

### Maximize Spell/Visual Data

- **Use your abilities** in combat — each spell cast generates spell effect data
- **Use mounts** to capture mount stats and restriction data
- **Use toys and items** with on-use effects
- **Visit your spellbook and collections** tabs to trigger data loads

### What VoxCore Needs Most Right Now

For VoxCore specifically, these areas are our highest priority:

| Priority | Content | Why |
|----------|---------|-----|
| **Highest** | New Midnight 12.x zones and content | Brand new data with no existing coverage |
| **High** | Capital cities (Dornogal, Stormwind, etc.) | NPC placements, vendors, trainers, portals |
| **High** | Full quest chains start to finish | Quest data is complex and hard to reconstruct otherwise |
| **Medium** | Dungeons and raids | Boss data, loot tables, scripted encounter events |
| **Medium** | Profession trainers and crafting NPCs | Recipe and skill data |
| **Lower** | Old expansion zones with existing data | Still useful for filling gaps and verifying accuracy |

---

## Parsing Sniffs with WowPacketParser (Optional)

> **This step is entirely optional.** You can share raw `.pkt` files and we'll handle parsing. But if you want to see what your sniffs contain or contribute parsed data directly, here's how:

### Setup

1. **Download WPP** — Grab a [nightly build](https://github.com/TrinityCore/WowPacketParser/actions) from GitHub Actions (you'll need to be logged into GitHub to download artifacts). Choose the **Windows Release** build.
2. **Install .NET 9.0 Runtime** — Download from [dotnet.microsoft.com](https://dotnet.microsoft.com/download/dotnet/9.0). You only need the **Runtime**, not the full SDK.
3. **Extract WPP** to a folder (e.g., `C:\Tools\WPP\`)

### Parsing

- **Drag and drop**: Drag your `.pkt` file onto `WowPacketParser.exe`
- **Command line**: `WowPacketParser.exe path\to\your\sniff.pkt`
- Output files appear in the same directory as the input `.pkt`

### Configuration (Optional)

Edit `WowPacketParser.dll.config` (XML file) to customize behavior:

| Setting | What It Does |
|---------|-------------|
| `DumpFormatType` | Output format — text, SQL, or both |
| `DBEnabled` | Set to `true` to compare against an existing database and generate minimal diffs |
| `TargetedDatabase` | Set to match your core version for correct SQL formatting |

### What WPP Produces

| Output File | Description |
|-------------|-------------|
| `sniff_name.txt` | Human-readable packet log — great for browsing what was captured |
| `sniff_name_world.sql` | SQL statements ready for database import |

When connected to a reference database (`DBEnabled = true`), WPP generates **minimal updates** — if only an NPC's faction changed since the last import, it produces a targeted `UPDATE` rather than a full `INSERT`. This keeps the output clean and mergeable.

---

## Submitting Your Sniffs

### What to Send

- The `.pkt` file(s) from your `dump\` folder
- **Compress them first** (7z, zip, or rar) — raw `.pkt` files can be large, but they compress extremely well (typically 80-90% size reduction)
- **Name your archive descriptively** if possible — e.g., `Dornogal_full_walkthrough.7z` or `Midnight_questing_session3.zip`

### How to Send

- Upload to a file hosting service (Google Drive, Mega, Dropbox, etc.)
- Share the download link with us on Discord
- If you're a regular contributor, ask about direct upload access

### Labeling Tips

Including a brief note about what you did during the session helps us prioritize parsing:

> "Walked through all of Dornogal, talked to every NPC, browsed all vendors. Then quested through the first chapter of the Midnight campaign."

This kind of context is gold — it tells us exactly what to expect in the data.

---

## Safety & Privacy

### Account Risk

> **Use at your own risk.** There is no guaranteed safe way to gather sniffs. While no bans have been documented in connection with Ymir since patch 8.1.5, Blizzard's stance on third-party tools means there is always a theoretical risk. Neither TrinityCore nor VoxCore are responsible for any actions taken against your account.

### How Ymir Works (Why It's Lower Risk)

- Ymir uses **network-level packet capture** via the Npcap driver — it reads network traffic at the OS level
- It does **not** inject code into the WoW process, modify game memory, or alter any game files
- From WoW's perspective, Ymir doesn't exist — it never touches the game client
- This is fundamentally different from (and lower risk than) tools that hook into game memory like bots or hacks

### Privacy Warning

> **Your `.pkt` files contain personal account information**, including:
> - Your Battle.net account name
> - Your real name (from billing information)
> - Your Battle.net friends list
> - Your IP address
> - Character names and server info
>
> **Never post `.pkt` files publicly** (forums, Reddit, public Discord channels, file sharing sites without access controls). Only share them with trusted project contributors through direct messages or restricted channels.
>
> We strip all personal data during the parsing process — none of your personal information ends up in the server database.

---

## Tips for Being an Ace Sniffer

### Session Planning

- **Pick a zone or theme** for each session — "Today I'm doing all of Dornogal" produces better coverage than random wandering
- **Start fresh** every session — clear cache, fresh login, fresh Ymir instance
- **Take brief notes** on what you covered — helps us track which zones still need attention and avoids duplicate work

### Quality Over Quantity

- **Slow and thorough beats fast and sloppy** — walking through a town captures every NPC; flying over it captures almost nothing
- **Interact with everything** — an NPC you walk past gives us position and appearance data, but *talking* to them gives us gossip text, vendor lists, quest data, and more
- **Revisit areas at different times of day** — some NPCs have time-based or event-based spawn conditions
- **Multiple characters help** — different races/classes/factions may see different NPCs, quests, or dialog

### Value Priority

| Priority | Activity | Why |
|----------|----------|-----|
| **High** | Questing through new Midnight content | Quest data is complex and hard to gather otherwise |
| **High** | Visiting vendors/trainers and browsing their full lists | Inventory data only comes from direct interaction |
| **High** | Walking through towns/hubs slowly | Captures all NPC spawns, positions, and equipment |
| **Medium** | Following patrolling NPCs for a full loop | Waypoint data requires tracking the complete patrol |
| **Medium** | Using profession trainers/crafting | Captures recipe and skill data |
| **Medium** | Running dungeons/raids | Boss data, loot tables, scripted events |
| **Lower** | Sitting in one spot AFK | Only captures what's in immediate view range |

### Automation Script

For frequent sniffers, save this as `start_sniff.bat` to automate the cache-clear and launch:

```batch
@echo off
title VoxCore Sniffer Session
echo ==========================================
echo    VoxCore Packet Sniffer Launcher
echo ==========================================
echo.

REM  -- Edit these paths to match your setup --
set "WOW_PATH=C:\World of Warcraft\_retail_"
set "YMIR_PATH=C:\Tools\Ymir"

echo [1/2] Clearing WoW cache...
if exist "%WOW_PATH%\Cache" (
    rmdir /S /Q "%WOW_PATH%\Cache"
    echo       Cache cleared.
) else (
    echo       Cache already clean.
)
echo.

echo [2/2] Starting Ymir sniffer...
cd /d "%YMIR_PATH%"
start "" ymir_retail.exe
echo       Sniffer is running!
echo.

echo ==========================================
echo  Now launch WoW through Battle.net.
echo  Play normally - everything is recorded.
echo  Close WoW when done - sniffer auto-stops.
echo  Sniffs saved to: %YMIR_PATH%\dump\
echo ==========================================
echo.
pause
```

---

## Troubleshooting

### Ymir won't start / crashes immediately

- **Npcap not installed**: Make sure you installed [Npcap](https://nmap.org/npcap/) with "WinPcap API-compatible Mode" checked. If you're not sure, reinstall it.
- **Wrong Ymir version**: Make sure the Ymir release matches your WoW version. Using a retail sniffer on Classic (or vice versa) won't work.
- **Antivirus blocking it**: Some antivirus software flags packet capture tools. Add an exception for `ymir_retail.exe` if needed.
- **Run as Administrator**: If Ymir can't access the network adapter, try right-clicking and choosing "Run as administrator".

### No `.pkt` file in the dump folder

- **Started Ymir after WoW**: Ymir must be running *before* you launch WoW. Close WoW, start Ymir, then relaunch WoW.
- **WoW connected to a different network adapter**: If you have multiple network adapters (VPN, VM, etc.), Ymir may be listening on the wrong one. Try disabling other adapters temporarily.
- **Very short session**: If you logged in and immediately logged out, the `.pkt` file might be too small to write. Play for at least a few minutes.

### WPP fails to parse / errors during parsing

- **.NET not installed**: Make sure you have the [.NET 9.0 Runtime](https://dotnet.microsoft.com/download/dotnet/9.0) installed (not just the SDK).
- **Mismatched versions**: WPP must support the WoW build that produced the `.pkt` file. Use the latest nightly build for best compatibility.
- **Corrupted `.pkt` file**: If WoW or Ymir crashed during capture, the file may be truncated. WPP usually handles this gracefully but may skip some packets.

### WoW runs fine but Ymir shows no activity

- **Cache not cleared**: If you didn't delete the `Cache` folder, WoW may use cached data instead of requesting it from the server, resulting in fewer captured packets.
- **Firewall rules**: Ensure your firewall isn't blocking Ymir's access to network traffic.

---

## FAQ

**Q: Does the sniffer slow down my game?**
A: No. Ymir captures packets at the network driver level with negligible performance impact. You won't notice any difference in FPS or latency.

**Q: Can I sniff on PTR/Beta servers?**
A: Yes — PTR/Beta sniffs are extremely valuable since they often capture the newest content before it goes live. Use the `ymir_ptr.exe` binary included in the Ymir release.

**Q: How big are the `.pkt` files?**
A: It depends on session length and activity. A typical 1-2 hour session produces 50-500 MB. They compress very well — expect 80-90% size reduction with 7z or zip.

**Q: Do I need to be max level?**
A: No. Low-level content is just as valuable. Starter zones, leveling quests, early-game NPCs — all of it needs data.

**Q: Can I sniff Classic versions too?**
A: Yes. Ymir has releases for Classic Era (1.15.x), TBC Classic (2.5.x), Titan Classic (3.80.x), and MoP Classic (5.5.x). Grab the matching release from the [releases page](https://github.com/TrinityCore/ymir/releases).

**Q: I found a bug or weird data in my sniff — should I still submit it?**
A: Absolutely. Bugs in retail are still valid data points. Submit everything and let the parsing team sort it out.

**Q: Do I need to run WowPacketParser myself?**
A: No. Just capture and share the raw `.pkt` files — we handle all the parsing. But you're welcome to run WPP yourself if you're curious about what your sniffs contain.

**Q: Can I sniff while using addons?**
A: Yes. Addons don't interfere with packet capture. Keep your addons as you normally would.

**Q: How often should I sniff?**
A: As often as you like. Even a single session covering one zone is valuable. Regular contributors who sniff weekly across different content areas are especially helpful.

**Q: What if someone else already sniffed the same zone?**
A: Multiple sniffs of the same area are actually useful — different characters may trigger different NPC interactions, quests, or phased content. Don't worry about overlap.

---

## Links & Resources

| Resource | URL |
|----------|-----|
| **Ymir** (Sniffer) | [github.com/TrinityCore/ymir](https://github.com/TrinityCore/ymir) |
| **Ymir Releases** | [github.com/TrinityCore/ymir/releases](https://github.com/TrinityCore/ymir/releases) |
| **WowPacketParser** | [github.com/TrinityCore/WowPacketParser](https://github.com/TrinityCore/WowPacketParser) |
| **Npcap** (Required) | [nmap.org/npcap](https://nmap.org/npcap/) |
| **.NET 9.0 Runtime** | [dotnet.microsoft.com/download/dotnet/9.0](https://dotnet.microsoft.com/download/dotnet/9.0) |
| **AzerothCore Sniffing Wiki** | [azerothcore.org/wiki/sniffing-and-parsing](https://www.azerothcore.org/wiki/sniffing-and-parsing) |

---

*This guide is maintained by the VoxCore team. Last updated: March 2026.*

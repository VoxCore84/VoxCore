# WowPacketParser (WPP) — Parsing Your Own Sniffs

> **This guide is entirely optional.** You do NOT need to parse sniffs yourself — just share the raw `.pkt` files and we handle everything. This guide is for power users who want to see what their sniffs contain or contribute parsed SQL directly.

---

## Table of Contents

1. [What WPP Does](#what-wpp-does)
2. [What You Need](#what-you-need)
3. [Step 1: Install .NET 9.0 Runtime](#step-1-install-net-90-runtime)
4. [Step 2: Download WPP](#step-2-download-wpp)
5. [Step 3: Parse a Sniff](#step-3-parse-a-sniff)
6. [Understanding the Output](#understanding-the-output)
7. [Configuration (Optional)](#configuration-optional)
8. [Troubleshooting](#troubleshooting)

---

## What WPP Does

WowPacketParser reads raw `.pkt` files (the recordings from Ymir) and converts the binary packet data into two useful formats:

1. **A `.txt` file** — A human-readable log showing every packet, decoded and annotated with names. You can open this in any text editor to see what was captured. Example line:
   ```
   SpellID: 2479 (Honorless Target)
   ```
   It shows both the raw ID and the human-readable name, making it easy to browse.

2. **A `_world.sql` file** — SQL database statements that can be imported directly into a TrinityCore/VoxCore database. This contains creature spawns, quest data, vendor inventories, and everything else the sniff captured, formatted as INSERT/UPDATE queries.

---

## What You Need

| Requirement | Where to Get It |
|-------------|----------------|
| **.NET 9.0 Runtime** | [dotnet.microsoft.com/download/dotnet/9.0](https://dotnet.microsoft.com/download/dotnet/9.0) |
| **WowPacketParser** | [GitHub Nightly Builds](https://github.com/TrinityCore/WowPacketParser/actions) (requires GitHub login) |
| **A `.pkt` file** | Your Ymir `dump` folder |

> **Important distinction:** You need the **.NET Runtime**, not the full .NET SDK. The Runtime is smaller and is all you need to *run* WPP. The SDK is only needed if you want to compile WPP from source code.

---

## Step 1: Install .NET 9.0 Runtime

1. Go to [dotnet.microsoft.com/download/dotnet/9.0](https://dotnet.microsoft.com/download/dotnet/9.0)

2. Under the **.NET Runtime** section (NOT the SDK section), find the **Windows** row

3. Click the **x64** installer download link
   - It will download a file like `dotnet-runtime-9.0.x-win-x64.exe`

4. Run the installer:
   - Double-click the downloaded file
   - If prompted by Windows ("Do you want to allow this app to make changes?"), click **Yes**
   - Click **Install**
   - Wait for it to finish, then click **Close**

5. That's it — .NET is now installed system-wide.

---

## Step 2: Download WPP

### Option A: Nightly Builds (Easiest)

1. Go to the [WPP GitHub Actions page](https://github.com/TrinityCore/WowPacketParser/actions)
   - **Note:** You must be **logged into GitHub** to download workflow artifacts. If you don't have a GitHub account, it's free to create one.

2. Click on the **most recent successful workflow run** (it will have a green checkmark)

3. Scroll down to the **"Artifacts"** section

4. Download **"WowPacketParser-Windows-Release"**
   - This downloads a `.zip` file

5. Extract the zip to a folder, for example: `C:\Tools\WPP\`

### Option B: Build From Source (Advanced)

If you prefer to build from source:

1. Install the **.NET 9.0 SDK** (not just the Runtime)
2. Clone the repo: `git clone https://github.com/TrinityCore/WowPacketParser.git`
3. Open the solution in Visual Studio 2022+, or build from command line:
   ```
   dotnet build WowPacketParser.sln -c Release
   ```

---

## Step 3: Parse a Sniff

There are two ways to run WPP:

### Drag and Drop (Simplest)

1. Open File Explorer and navigate to your Ymir `dump` folder where your `.pkt` file is
2. Open a second File Explorer window showing your WPP folder
3. **Drag your `.pkt` file and drop it onto `WowPacketParser.exe`**
4. A console window will open showing parsing progress
5. When it's done, the output files will appear **in the same folder as your `.pkt` file**

### Command Line

1. Open a Command Prompt or PowerShell window
2. Navigate to your WPP folder:
   ```
   cd C:\Tools\WPP
   ```
3. Run:
   ```
   WowPacketParser.exe "C:\Tools\Ymir\dump\your_sniff_file.pkt"
   ```
4. Watch the output — it will show progress as it parses each packet
5. Output files appear next to the input `.pkt` file

### Parsing Multiple Files

You can parse multiple `.pkt` files at once:
```
WowPacketParser.exe file1.pkt file2.pkt file3.pkt
```

Or parse all `.pkt` files in a directory by dragging the folder onto the exe.

---

## Understanding the Output

After parsing, you'll find these files next to your `.pkt` file:

### The Text Log (`sniff_name.txt`)

A human-readable packet-by-packet log. Great for:
- Browsing what was captured in your session
- Looking up specific NPCs, quests, or spells
- Debugging issues or verifying data

Open it in any text editor (Notepad, Notepad++, VS Code). Be aware it can be very large (hundreds of MB for long sessions).

### The SQL Output (`sniff_name_world.sql`)

SQL statements ready for database import. Contains:

| Data Type | Example SQL |
|-----------|-------------|
| Creature spawns | `INSERT INTO creature (guid, id, map, position_x, ...) VALUES (...)` |
| Creature templates | `INSERT INTO creature_template (entry, name, ...) VALUES (...)` |
| Quest data | `INSERT INTO quest_template (ID, LogTitle, ...) VALUES (...)` |
| Vendor inventories | `INSERT INTO npc_vendor (entry, item, ...) VALUES (...)` |
| Gameobject spawns | `INSERT INTO gameobject (guid, id, map, position_x, ...) VALUES (...)` |
| And much more | Gossip menus, trainer data, loot tables, waypoints, etc. |

---

## Configuration (Optional)

WPP's behavior can be customized by editing the configuration file `WowPacketParser.dll.config` (it's an XML file — open it with any text editor).

### Key Settings

| Setting | What It Does | Default |
|---------|-------------|---------|
| `DumpFormatType` | What output to generate (Text, SQL, or both) | Both |
| `DBEnabled` | Connect to a MySQL database for smarter output (see below) | `false` |
| `TargetedDatabase` | Which database schema to target (TrinityCore version) | Auto-detect |

### Database-Connected Mode (Advanced)

If you set `DBEnabled` to `true` and provide MySQL connection details, WPP does something clever: it compares the sniffed data against what's already in the database and generates **minimal diffs**.

For example, if an NPC already exists in the database but the sniff shows their faction changed, WPP will generate just:
```sql
UPDATE creature_template SET faction = 35 WHERE entry = 12345;
```

Instead of a full INSERT with every column. This makes the output much cleaner and easier to review.

**Database setup for this mode:**
- WPP uses two databases: your existing `world` database (read-only) and a `WPP` reference database
- Run the included `create_WPP.sql` to set up the reference database
- Configure connection strings in the config file

This mode is primarily for maintainers and regular contributors. If you're just curious about what your sniffs contain, you don't need this.

---

## Troubleshooting

### WPP won't start / ".NET not found" error

- Make sure you installed the **.NET 9.0 Runtime** (not an older version)
- Download it from [dotnet.microsoft.com/download/dotnet/9.0](https://dotnet.microsoft.com/download/dotnet/9.0)
- After installing, try running WPP again

### "Unsupported build" or version mismatch errors

- Your `.pkt` file was captured from a WoW build that this version of WPP doesn't support yet
- Download the latest nightly build of WPP — newer builds add support for newer WoW patches
- If the latest nightly still doesn't support your build, it may not have been added yet. Share the raw `.pkt` file with us and we'll handle it.

### Parse takes forever / seems stuck

- Large `.pkt` files (500MB+) can take several minutes to parse. This is normal.
- The console window will show progress as it processes packets.
- If it's truly stuck (no progress for 5+ minutes), the file may be corrupted. Try parsing a smaller/newer sniff to verify WPP works.

### Output file is empty or very small

- The `.pkt` file may not have contained much usable data
- This can happen if the cache wasn't cleared before sniffing (WoW used cached data instead of server data)
- Try a new sniff with a clean cache

---

*Back to the [main guide](https://gist.github.com/VoxCore84/22343664a9eab5013b97f5c55feacbaa) | Setup help: [Ymir Setup Guide](https://gist.github.com/VoxCore84/14a47790f63a6f97042a6301210579ea) | Tips: [Sniffing Best Practices](https://gist.github.com/VoxCore84/9ac8a86a0a10d995584f821779d403f9)*

# Ymir Setup Guide — Step by Step

> This guide walks you through installing and using Ymir, the packet sniffer. Every step is described in detail — no prior experience needed.

**Time required:** ~5 minutes for first-time setup, ~30 seconds each session after that.

---

## Table of Contents

1. [Heads Up — 5 Things That Trip Up First-Timers](#heads-up--5-things-that-trip-up-first-timers)
2. [What You're Installing](#what-youre-installing)
3. [Step 1: Install Npcap (Network Driver)](#step-1-install-npcap-network-driver)
4. [Step 2: Download Ymir](#step-2-download-ymir)
5. [Step 3: Your First Sniff Session](#step-3-your-first-sniff-session)
6. [Step 4: Find Your Sniff File](#step-4-find-your-sniff-file)
7. [Step 5: Compress and Share](#step-5-compress-and-share)
8. [Every Session After the First](#every-session-after-the-first)
9. [Optional: Automation Script](#optional-automation-script)
10. [Troubleshooting](#troubleshooting)

---

## Heads Up — 5 Things That Trip Up First-Timers

Before you start, read these five gotchas. They're the most common reasons people think something is broken when everything is actually fine:

### 1. Your antivirus will probably freak out

This is the **#1 issue** people hit. Ymir is a packet capture tool, and antivirus software tends to flag anything that touches network traffic — even though Ymir is completely safe and open-source. What usually happens: you extract the zip, and your antivirus **silently deletes `ymir_retail.exe`** before you even get to run it. You open the folder and the file just... isn't there.

**Do this BEFORE you extract Ymir:**
- Open your antivirus settings (Windows Security → Virus & threat protection → Manage settings)
- Scroll down to **Exclusions** and click **"Add or remove exclusions"**
- Click **"Add an exclusion"** → **"Folder"** → select the folder where you'll put Ymir (e.g., `C:\Tools\Ymir\`)
- Now extract the zip — the `.exe` will survive

If your antivirus already ate the file, restore it from quarantine (Windows Security → Protection history → find the item → Actions → Restore), then add the exclusion so it doesn't happen again.

---

### 2. There's one critical checkbox during Npcap install

When installing Npcap (the network driver), there's a screen with several checkboxes. **You MUST check "Install Npcap in WinPcap API-compatible Mode."** It's easy to speed-click through the installer and miss this. If you skip it, Ymir will fail with a confusing error and you'll have no idea why. If that happens, just re-run the Npcap installer and check the box this time.

---

### 3. Start Ymir FIRST, then WoW — every time

The order matters. Ymir needs to be listening **before** WoW connects to Blizzard's servers. If you launch WoW first out of habit and then start Ymir, it will either capture nothing or produce a tiny useless file. Think of it like pressing Record before you start talking.

---

### 4. On GitHub, click "Assets" — not "Source code"

When you go to download Ymir from GitHub, you'll see a release with some text and then a section called **"Assets"** at the bottom (you may need to click it to expand it). Download the `.zip` or `.7z` file from Assets. Do **NOT** click "Source code (zip)" or "Source code (tar.gz)" — those are the raw programming files, not the program you need.

---

### 5. If your `.pkt` file is tiny, you probably forgot to clear WoW's cache

After a session, if your `.pkt` file is under ~1 MB, something went wrong. The most common cause: you forgot to delete WoW's `Cache` folder before playing. When the cache exists, WoW uses old stored data instead of requesting fresh data from the server — so Ymir has almost nothing to capture. Delete the cache, run a new session, and the file will be much bigger.

---

## What You're Installing

You need two things:

1. **Npcap** — A free network driver that lets programs read network traffic on your computer. Think of it as giving Ymir "ears" to listen to what WoW is sending and receiving. You install this once and forget about it.

2. **Ymir** — The actual sniffer program made by the TrinityCore team. It's a small `.exe` you run before launching WoW. It uses Npcap to listen to WoW's network traffic and saves everything to a file.

Neither of these programs touch or modify World of Warcraft in any way. They only observe network traffic.

---

## Step 1: Install Npcap (Network Driver)

Npcap is a well-known, trusted network driver used by security professionals worldwide. It's made by the same people who make Nmap (a widely-used network tool).

### Download

1. Go to **[nmap.org/npcap](https://nmap.org/npcap/)**
2. Look for the download button/link — it will say something like **"Npcap 1.xx installer"**
3. Click it to download the installer (a small `.exe` file, usually ~1 MB)

### Install

1. **Right-click** the downloaded Npcap installer and choose **"Run as administrator"**
   - This is required — Npcap installs a network driver, which needs admin permissions
   - If you see a Windows prompt asking "Do you want to allow this app to make changes to your device?", click **Yes**

2. The installer will show you a license agreement. Click **"I Agree"**

3. **On the installation options screen, this is critical:**
   - You will see a list of checkboxes
   - **Find and CHECK the box that says "Install Npcap in WinPcap API-compatible Mode"**
   - This is required for Ymir to work — if you skip this, Ymir won't be able to capture packets
   - The other checkboxes can stay at their defaults

4. Click **"Install"** and wait for it to finish (takes a few seconds)

5. Click **"Finish"** when done

6. If it asks you to restart your computer, go ahead and restart

### Verify It Worked

You don't need to do anything special to verify — if the installer completed without errors, you're good. Npcap runs silently in the background as a system service. You'll never need to interact with it directly.

---

## Step 2: Download Ymir

### Find the Right Version

1. Go to the **[Ymir Releases page](https://github.com/TrinityCore/ymir/releases)** on GitHub

2. You'll see a list of releases. **Download the latest retail release** — it will be the one with a version number starting with `12.x` (for example, `12.0.1.66263`). This is the current live WoW expansion (Midnight).

3. Click on the release. You'll see a section called **"Assets"** — you may need to click on it to expand it.

4. Download the `.zip` or `.7z` file listed under Assets.

### Extract and Place the Files

1. **Create a folder** for Ymir somewhere convenient — for example: `C:\Tools\Ymir\`
   - **Important:** Do NOT put this inside your WoW installation folder

2. **Extract** (unzip) the downloaded file into that folder
   - Right-click the downloaded file → "Extract All..." → choose your Ymir folder
   - If you have 7-Zip installed, right-click → 7-Zip → "Extract Here"

3. After extracting, your folder should look something like this:
   ```
   C:\Tools\Ymir\
       ymir_retail.exe      <-- this is the main program for retail WoW
       ymir_ptr.exe          <-- this is for PTR/test servers (optional)
   ```

4. That's it — Ymir doesn't need to be "installed." The `.exe` is ready to run.

> **Important — WoW Updates:** Every time WoW gets a major patch or build update, you'll need to download the **latest Ymir release** that matches the new build. If Ymir suddenly stops working after a WoW patch, check the [Ymir Releases page](https://github.com/TrinityCore/ymir/releases) for an updated version. This usually happens within a few days of a WoW update.

---

## Step 3: Your First Sniff Session

> **Reminder:** You're sniffing on **Blizzard's live retail servers** — just regular WoW with your normal Battle.net account. You are NOT connecting to any private server. The sniffer records data from Blizzard's servers so it can be recreated on private servers.

Now let's do your first capture. Follow these steps in order:

### 3a. Delete WoW's Cache Folder

**Why:** WoW stores data locally in a cache folder. If the cache has old data, WoW will use that instead of requesting fresh data from the server. Deleting the cache forces WoW to request everything fresh, which means Ymir captures more data.

**How:**

1. Open File Explorer and navigate to your WoW installation folder. This is usually something like:
   - `C:\World of Warcraft\_retail_\`
   - Or wherever you installed WoW

2. Look for a folder called **`Cache`**

3. **Delete it** — right-click → Delete (or select it and press the Delete key)
   - Don't worry, WoW will recreate this folder automatically next time it runs
   - This does NOT affect your settings, addons, or characters — just cached server data

### 3b. Start Ymir

1. Navigate to your Ymir folder (e.g., `C:\Tools\Ymir\`)

2. **Double-click `ymir_retail.exe`** to run it
   - If Windows SmartScreen pops up saying "Windows protected your PC" or "Unknown publisher":
     - Click **"More info"**
     - Then click **"Run anyway"**
     - This is normal for programs downloaded from GitHub that aren't signed by a big company
   - If your antivirus flags it, you may need to add an exception (see [Troubleshooting](#troubleshooting))

3. A **black console window** will appear with some text output. This is Ymir running. **Leave this window open** — don't close it.
   - You should see text indicating it's listening for WoW connections
   - Minimize it if you want — just don't close it

### 3c. Launch WoW and Play

1. Open WoW through **Battle.net** (or however you normally launch it)
2. **Log in** to your account and select a character
3. **Play normally** — quest, explore, talk to NPCs, visit vendors, whatever you'd normally do
4. Everything your client sees and receives is being silently recorded in the background

### 3d. Stop the Session

1. When you're done playing, **close WoW** normally:
   - Press Escape → Log Out → Exit Game, or just close the window
2. **Ymir will automatically detect that WoW closed** and shut itself down within a few seconds
3. You'll see the Ymir console window close on its own (or display a final message and wait for a keypress)

---

## Step 4: Find Your Sniff File

After closing WoW and Ymir:

1. Navigate to your Ymir folder (e.g., `C:\Tools\Ymir\`)

2. Look for a folder called **`dump`** — this was created automatically by Ymir

3. Inside `dump`, you'll find one or more files. These are your sniff recordings. They'll have names based on the date/time of the session, something like:
   ```
   2026_03_08_1430_retail.pkt
   ```

4. **That `.pkt` file is your sniff.** It contains all the data from your play session.

> **Can't see the `.pkt` extension?** Windows hides file extensions by default. The files will just show as the name without `.pkt` at the end, but they'll have a generic/blank icon and be the largest files in the folder (tens or hundreds of MB). That's them. If you want to see extensions: open File Explorer → click **"View"** at the top → check **"File name extensions"**.

**File size:** A typical 1-2 hour session produces a file between 50 MB and 500 MB, depending on how much you interacted with the world. This is normal.

---

## Step 5: Compress and Share

### Compress the File

Raw `.pkt` files are large, but they compress extremely well (typically 80-90% smaller):

1. **Right-click** your `.pkt` file in the `dump` folder
2. If you have **7-Zip** installed (recommended):
   - 7-Zip → **"Add to archive..."**
   - Leave it as `.7z` format and click OK
3. If you have **WinRAR** installed:
   - "Add to archive..." → choose `.zip` or `.rar` → click OK
4. If you don't have either, use **Windows built-in compression**:
   - **Windows 11**: Right-click the file → **"Compress to ZIP file"** (it's right in the menu)
   - **Windows 10**: Right-click → **"Send to"** → **"Compressed (zipped) folder"**
   - Both create a `.zip` file — no extra software needed

**Rename the archive** to something descriptive if you can:
- `Dornogal_full_walkthrough_mar8.7z`
- `Midnight_chapter1_quests.zip`
- `Isle_of_Dorn_exploration.7z`

### Share With Us

1. **Upload** the compressed file to a file hosting service:
   - **Google Drive** — upload, then right-click → "Get link" → set to "Anyone with the link" → copy the link
   - **Mega.nz** — upload, then right-click → "Get link" → copy
   - **Dropbox** — upload, then click "Share" → "Copy link"
   - Any other file sharing service works too

2. **Share the download link** with us on Discord
   - Post it in the designated sniff-sharing channel, or DM it to a project lead
   - If you can, include a brief note about what you did during the session:

     > "Walked through all of Dornogal, talked to every NPC, browsed all vendors. Then quested through the first chapter of the Midnight campaign."

---

## Every Session After the First

Once Npcap and Ymir are installed, each sniffing session is just:

1. Delete WoW's `Cache` folder
2. Run `ymir_retail.exe`
3. Launch and play WoW
4. Close WoW when done
5. Compress and share the `.pkt` file from `dump`

It becomes second nature after the first time.

---

## Optional: Automation Script

If you plan to sniff regularly, you can create a batch file that handles the cache deletion and Ymir launch automatically:

1. Open **Notepad** (search for it in the Start menu)

2. Paste the following text:

```batch
@echo off
title WoW Sniffer Session
echo ==========================================
echo    WoW Packet Sniffer Launcher
echo ==========================================
echo.

REM ============================================
REM  EDIT THESE TWO PATHS TO MATCH YOUR SETUP
REM ============================================
set "WOW_PATH=C:\World of Warcraft\_retail_"
set "YMIR_PATH=C:\Tools\Ymir"

echo [1/2] Clearing WoW cache...
if exist "%WOW_PATH%\Cache" (
    rmdir /S /Q "%WOW_PATH%\Cache"
    echo       Cache cleared successfully.
) else (
    echo       Cache folder not found (already clean).
)
echo.

echo [2/2] Starting Ymir sniffer...
if exist "%YMIR_PATH%\ymir_retail.exe" (
    cd /d "%YMIR_PATH%"
    start "" ymir_retail.exe
    echo       Sniffer is running!
) else (
    echo       ERROR: ymir_retail.exe not found at %YMIR_PATH%
    echo       Please check the YMIR_PATH setting in this file.
)
echo.

echo ==========================================
echo  Now launch WoW through Battle.net.
echo  Play normally. Everything is recorded.
echo  Close WoW when done - sniffer auto-stops.
echo  Sniffs saved to: %YMIR_PATH%\dump\
echo ==========================================
echo.
pause
```

3. **Edit the two paths** near the top:
   - `WOW_PATH` — change this to wherever your WoW is installed
   - `YMIR_PATH` — change this to wherever you extracted Ymir

4. Go to **File → "Save As..."**
   - Navigate to your Desktop (or wherever you want the shortcut)
   - In the "File name" box, type: `start_sniff.bat`
   - In the "Save as type" dropdown, change it to **"All Files (*.*)"**
   - Click **Save**

5. Now you can just **double-click `start_sniff.bat`** before each session instead of doing the steps manually.

---

## Troubleshooting

---

### "Windows protected your PC" / SmartScreen warning

This is normal for programs downloaded from the internet that aren't signed by a major publisher.

- Click **"More info"**
- Then click **"Run anyway"**

---

### Antivirus blocks or quarantines Ymir

Some antivirus software flags packet capture tools because they interact with network traffic. Ymir is safe — it's an open-source project from TrinityCore.

- Open your antivirus settings
- Add an **exception/exclusion** for `ymir_retail.exe` (and `ymir_ptr.exe` if applicable)
- Restore the file from quarantine if it was removed

---

### Ymir starts but no `.pkt` file appears

- **Did you start Ymir BEFORE launching WoW?** Ymir needs to be running first to catch the WoW connection.

- **Is WoW using a VPN or proxy?** If WoW's traffic goes through a VPN, Ymir might be listening on the wrong network adapter. Try temporarily disconnecting your VPN.

- **Did the session last long enough?** Very short sessions (login → immediate logout) might not produce a file. Play for at least a few minutes.

---

### Ymir crashes or shows errors immediately

- **Npcap not installed properly**: Re-run the Npcap installer and make sure you check **"WinPcap API-compatible Mode"**.

- **Wrong Ymir version**: Make sure you downloaded the Ymir release that matches your WoW version.

- **Try running as Administrator**: Right-click `ymir_retail.exe` → "Run as administrator".

---

### "Npcap not found" or similar error

- Reinstall Npcap from [nmap.org/npcap](https://nmap.org/npcap/)
- Make sure to check **"WinPcap API-compatible Mode"** during installation
- Restart your computer after installing

---

### Where is my WoW installation folder?

If you're not sure where WoW is installed:

1. Open the **Battle.net** launcher
2. Click on **World of Warcraft** in the sidebar
3. Click the **gear icon** (settings) next to the Play button
4. Click **"Show in Explorer"** — this opens the WoW folder in File Explorer
5. You should see folders like `_retail_`, `_ptr_`, etc.
6. The Cache folder is inside `_retail_` (or whichever version you play)

---

*Back to the [main guide](https://gist.github.com/VoxCore84/22343664a9eab5013b97f5c55feacbaa) | Next: [Sniffing Best Practices](https://gist.github.com/VoxCore84/9ac8a86a0a10d995584f821779d403f9)*

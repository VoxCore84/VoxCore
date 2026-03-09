# TrinityCore 12.x Troubleshooting Guide

> **90% of problems fall into three categories:** build mismatch, missing map data, or certificate issues. Start with the Quick Checklist below — it solves most things in under 5 minutes.

---

## Table of Contents

1. [Quick Diagnostic Checklist](#quick-diagnostic-checklist)
2. [Realm Shows "Incompatible" — Build Mismatch](#realm-shows-incompatible--build-mismatch)
3. [Map / VMap Extraction Problems](#map--vmap-extraction-problems)
4. [Arctium Launcher Issues](#arctium-launcher-issues)
5. [Database & MySQL Problems](#database--mysql-problems)
6. [Certificate & Remote Hosting](#certificate--remote-hosting)
7. [Port Forwarding & Firewalls](#port-forwarding--firewalls)
8. [Worldserver Crashes](#worldserver-crashes)
9. [Windows Defender / Antivirus](#windows-defender--antivirus)
10. [Error Code Reference](#error-code-reference)
11. [Still Stuck?](#still-stuck)

---

## Quick Diagnostic Checklist

Before reading anything else, run through these five checks. They solve the majority of issues:

| # | Check | How |
|---|-------|-----|
| 1 | **Does your WoW build match the server?** | Open SQLyog/HeidiSQL → `auth` database → `realmlist` table → check `gamebuild` column. It must match your WoW client version exactly. |
| 2 | **Do maps/vmaps exist and have data?** | Check your server's `RelWithDebInfo/` folder. You need six folders: `dbc/`, `gt/`, `cameras/`, `maps/`, `vmaps/`, `mmaps/`. The `vmaps/` folder alone should be 2-3 GB. |
| 3 | **Is MySQL actually running?** | Open UniServerZ (or your MySQL manager) and confirm MySQL shows a green status. Wait 10-15 seconds after MySQL starts before launching bnetserver. |
| 4 | **Did antivirus eat something?** | Open Windows Security → Protection history. Look for any quarantined `.exe` files (Arctium, worldserver, bnetserver, extractors). |
| 5 | **Are you running things in the right order?** | MySQL first → wait 10-15 seconds → bnetserver → worldserver → Arctium launcher → WoW. Always this order. |

If none of those are the problem, keep reading below for your specific error.

---

## Realm Shows "Incompatible" — Build Mismatch

**This is the single most common issue.** It happens every time WoW patches, which is roughly every 2-4 weeks.

### What You See

- The realm list shows your server with **"Incompatible"** next to it
- You click the realm and get kicked back to the login screen
- Error codes: `WOW51900319`, `WOW51900225`, `WOW51900317`, or `WOW51900328`

### Why It Happens

WoW just updated to a new build number (e.g., from `58680` to `59538`), but your server's database still has the old build registered. The client sees the mismatch and refuses to connect.

### How to Fix It

You need to update **two tables** in your `auth` database. Open your SQL tool (SQLyog, HeidiSQL, or mysql command line), select the **`auth`** database, and run:

**Step 1 — Find your WoW client's current build number:**
- Open Arctium launcher → look at the build number displayed
- Or: check your WoW install folder for a `.build.info` file

**Step 2 — Update the database** (replace `NEW_BUILD` with your client's build number and `OLD_BUILD` with what's currently in the table):

```sql
-- 1. Register the new build (get this from #sql-updates or your admin)
DELETE FROM `build_info` WHERE `build` = NEW_BUILD;
INSERT INTO `build_info` (`build`, `majorVersion`, `minorVersion`, `bugfixVersion`, `hotfixVersion`,
  `winAuthSeed`, `win64AuthSeed`, `mac64AuthSeed`, `winChecksumSeed`, `macChecksumSeed`)
VALUES (NEW_BUILD, 12, 0, 1, NULL, NULL, 'AUTH_SEED_HEX_HERE', NULL, NULL, NULL);

-- 2. Point your realm at the new build
UPDATE `realmlist` SET `gamebuild` = NEW_BUILD WHERE `gamebuild` = OLD_BUILD;

-- 3. Update the default so new entries use the right build
ALTER TABLE `realmlist` CHANGE `gamebuild` `gamebuild` INT UNSIGNED NOT NULL DEFAULT 'NEW_BUILD';
```

> **Where do I get the auth seed?** Your server admin or community will post the full INSERT statement (including the hex seed) whenever WoW patches. Check your Discord's `#sql-updates` channel. You cannot make up the seed — it's unique to each build.

**Step 3 — Restart** both bnetserver and worldserver.

### Common Mistakes

| Mistake | What Happens |
|---------|-------------|
| Running the SQL in the `world` database instead of `auth` | Error: "Table 'world.build_info' doesn't exist" |
| Forgetting to restart the servers after the SQL update | Old build still cached in memory |
| Copying the SQL from Discord and getting extra characters | SQL syntax error 1064 — re-copy carefully |

---

## Map / VMap Extraction Problems

### What You See

- Worldserver starts but immediately shuts down with: **"Unable to load map and vmap data for starting zones — server shutting down!"**
- Or: **"VMap file './vmaps/0000.vmtree' couldn't be loaded — version mismatch"**
- Or: extractors flash open and close instantly without producing any files

### Why It Happens

TrinityCore needs extracted game data (maps, vmaps, mmaps) from your WoW client folder. If these are missing, outdated, or from the wrong client version, the server can't start.

### How to Extract

**Step 1 — Copy these files** from your server's `RelWithDebInfo/bin/RelWithDebInfo/` folder into your **WoW game client folder** (where `Wow.exe` lives):

```
mapextractor.exe
vmap4extractor.exe
vmap4assembler.exe
mmaps_generator.exe
libssl-3-x64.dll
libcrypto-3-x64.dll
```

> **All six files must be in the same folder.** If the DLLs are missing, the extractors will flash open and immediately close with no error message.

**Step 2 — Run each extractor in order** from the WoW client folder. Open a command prompt (or just double-click each `.exe`):

| Order | Tool | What It Does | Time |
|-------|------|-------------|------|
| 1 | `mapextractor.exe` | Extracts dbc, maps, cameras, gt | 5-15 min |
| 2 | `vmap4extractor.exe` | Extracts visual map geometry | 10-20 min |
| 3 | `vmap4assembler.exe` | Assembles vmaps into usable format | 5-10 min |
| 4 | `mmaps_generator.exe` | Generates navigation meshes for pathfinding | **1-3 hours** |

> **mmaps_generator takes a long time.** This is normal. Let it finish completely.

**Step 3 — Copy the output folders** back to your server's runtime directory (next to `worldserver.exe`):

```
dbc/      → RelWithDebInfo/
gt/       → RelWithDebInfo/
cameras/  → RelWithDebInfo/
maps/     → RelWithDebInfo/
vmaps/    → RelWithDebInfo/
mmaps/    → RelWithDebInfo/
```

### Common Mistakes

| Mistake | What Happens |
|---------|-------------|
| Double-nesting folders (e.g., `vmaps/vmaps/`) | Server can't find the data — check for accidental nesting |
| Missing DLLs in the extraction folder | Extractors flash open and instantly close — no output, no error |
| Using extractors from a different build than your client | "Version mismatch" error — re-extract with matching tools |
| Skipping mmaps_generator | Server runs but NPC pathing is broken (mobs walk through walls, stand still) |

---

## Arctium Launcher Issues

### Launcher Won't Start

**Symptom:** Double-click Arctium, nothing happens. No window, no error.

**Causes (in order of likelihood):**

1. **Antivirus quarantined it.** Check Windows Security → Protection history. Restore and add an exclusion. (See [Windows Defender section](#windows-defender--antivirus))
2. **Your CPU doesn't support AVX2.** Arctium requires AVX2 instructions, which means Intel Haswell (2013+) or AMD Excavator/Zen (2015+). Older CPUs cannot run it. You'll need to find an older Arctium build or use a different launcher.
3. **Missing Visual C++ Redistributable.** Download and install the [latest Visual C++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe) from Microsoft.

### "CertCommonName — No Result Found" Warning

**Symptom:** Arctium's terminal window shows `[CertCommonName] no result found — This is just a warning!`

**This is normal for local servers.** It means Arctium couldn't validate a certificate, which is expected when connecting to `127.0.0.1`. The client should still connect. If it doesn't, the problem is something else (likely a build mismatch).

### Client Launches but Can't Connect

- Make sure `SET portal` in your `WTF/Config.wtf` points to the right address:
  - **Local play:** `SET portal "127.0.0.1"`
  - **Remote server:** `SET portal "your.domain.com"`
- Make sure bnetserver is running and not crashed
- Make sure the build matches (see [build mismatch section](#realm-shows-incompatible--build-mismatch))

---

## Database & MySQL Problems

### bnetserver Closes Immediately on Startup

**The #1 cause:** Wrong MySQL credentials in `bnetserver.conf`.

Open `bnetserver.conf` and verify these lines:

```
LoginDatabaseInfo = "127.0.0.1;3306;root;YOUR_PASSWORD;auth"
```

The default password for most setups is `admin` (UniServerZ) or blank. If you changed your MySQL password, update it here AND in `worldserver.conf`.

### "MySQL Not Running" / Connection Refused

- **Wait 10-15 seconds** after starting MySQL before launching bnetserver. MySQL needs time to fully initialize.
- Verify MySQL is listening on port **3306**: open UniServerZ and check the green indicator.
- If another MySQL instance is running (XAMPP, WAMP, or a system-installed MySQL), they'll fight over port 3306. Stop the other one or change the port.

### SQL Syntax Error 1064

```
Error Code: 1064 — You have an error in your SQL syntax
```

**Common causes:**
- Copied SQL from Discord and extra characters/line breaks got included — try re-copying from the original source
- Running auth-database queries in the wrong database — make sure you selected `auth` not `world`
- Hex values in `build_auth_key` truncated during copy — use a plain-text paste, not rich text

### "Table doesn't exist"

- `Table 'world.build_info' doesn't exist` → You're in the wrong database. `build_info` is in `auth`.
- `Table 'world.realmlist' doesn't exist` → Same thing. `realmlist` is in `auth`.

---

## Certificate & Remote Hosting

> **If you're only playing on your own computer** (localhost / 127.0.0.1), you can skip this entire section. Certificates are only needed for remote/external connections.

### When Do You Need Certificates?

You need TLS certificates when **other people connect to your server over the internet**. Without them, bnetserver can't establish a secure connection and players will get login failures.

### Setting Up Certificates

**Step 1 — Get a domain name.** Free options:
- [DuckDNS](https://www.duckdns.org/) — free DDNS subdomain
- [No-IP](https://www.noip.com/) — free DDNS (requires monthly confirmation)

**Step 2 — Generate certificates** using certbot:
```
certbot certonly --standalone -d your.domain.com
```

This produces `cert.pem` and `privkey.pem`.

**Step 3 — Configure bnetserver.conf:**
```
CertificatesFile = "./bnetserver.cert.pem"
PrivateKeyFile = "./bnetserver.key.pem"
LoginREST.ExternalAddress = your.domain.com
LoginREST.LocalAddress = 127.0.0.1
LoginREST.Port = 8085
```

**Step 4 — Update the realmlist table** (in `auth` database):
```sql
UPDATE `realmlist` SET `address` = 'your.domain.com' WHERE `id` = 1;
```

**Step 5 — Update `WTF/Config.wtf`** on each player's client:
```
SET portal "your.domain.com"
```

### bnetserver Crashes When Changing Certificate Paths

If bnetserver instantly crashes after you edit cert paths in the config, the file paths are wrong. Double-check:
- The files actually exist at those paths
- You're using forward slashes or properly escaped backslashes
- The files aren't still locked by certbot or another process

---

## Port Forwarding & Firewalls

### Required Ports

| Port | Protocol | Service | Notes |
|------|----------|---------|-------|
| **3724** | TCP | Auth/Realmlist | Legacy auth port |
| **8085** | TCP | BNet Login | Required for 12.x client login |
| **8086** | TCP | Game Server | May be needed depending on config |

### How to Forward Ports

1. Find your router's admin page (usually `192.168.1.1` or `192.168.0.1`)
2. Look for "Port Forwarding" or "NAT" settings
3. Create rules for each port above, pointing to your server's **local IP** (e.g., `192.168.1.100`)
4. Set both TCP and UDP for each rule to be safe

### Testing If Ports Are Open

- Use [CanYouSeeMe.org](https://canyouseeme.org/) or [YouGetSignal](https://www.yougetsignal.com/tools/open-ports/)
- Enter each port number and check if it reports "Open"
- **Your server must be running** when you test — the port checker connects to your actual service

### Windows Firewall

Even with router port forwarding, Windows Firewall can still block connections:
1. Open **Windows Defender Firewall** → **Advanced settings**
2. **Inbound Rules** → **New Rule** → **Port**
3. Add TCP rules for 3724, 8085, 8086
4. Allow the connection → apply to all profiles

---

## Worldserver Crashes

### Crashes on Zone Transition / Loading Screen

**Symptom:** Player enters a dungeon, changes zones, or uses a portal → worldserver crashes.

**Common cause:** Missing or corrupted vmap/mmap data for that specific zone. Re-extract maps (see [extraction section](#map--vmap-extraction-problems)).

**Check logs:** Open `Server.log` in your server's runtime folder and scroll to the bottom. Look for assertion failures like:
```
ASSERTION FAILED: expression (file.cpp:line)
```

### Crashes When Using Flying Mounts

**Known issue:** Vehicle.cpp assertion failures when mount seat data is incorrect.

**Workaround:** This is a core bug that requires a code fix. Report the specific mount that causes the crash to your server admin along with the crash log.

### Crashes When Casting Specific Spells

**Symptom:** Casting a particular spell crashes the server every time.

**Check logs for:**
```
ASSERTION FAILED: index < _effects.size() (SpellInfo.h:586)
```

This means a spell references more effects than are defined in the spell data. Report the spell ID to your admin.

### "World Thread Hangs" Crash

```
World Thread hangs for 60013 ms, forcing a crash!
```

The server detected that the main game loop stopped responding for over 60 seconds and force-killed itself. Common causes:
- A database query took too long (check MySQL load)
- A script entered an infinite loop
- The machine ran out of RAM

---

## Windows Defender / Antivirus

### How to Tell If Antivirus Is the Problem

- An `.exe` file you just downloaded has disappeared
- A program that worked yesterday suddenly won't start
- Extractors flash open and close instantly (though this can also be missing DLLs)

### How to Fix It

**Step 1 — Check Protection History:**
1. Open **Windows Security** (search in Start menu)
2. Click **Virus & threat protection**
3. Scroll down and click **Protection history**
4. Look for any quarantined items — you'll see the file name and path

**Step 2 — Restore the file:**
1. Click the quarantined item
2. Click **Actions** → **Restore**

**Step 3 — Prevent it from happening again:**
1. Go back to **Virus & threat protection**
2. Under **Virus & threat protection settings**, click **Manage settings**
3. Scroll down to **Exclusions** → click **Add or remove exclusions**
4. Click **Add an exclusion** → **Folder**
5. Select your entire server folder (e.g., `C:\TrinityCore\`) and your Arctium folder

> **Add the exclusion BEFORE restoring the file.** Otherwise Defender may immediately re-quarantine it.

---

## Error Code Reference

| Error Code | Meaning | Fix |
|-----------|---------|-----|
| `WOW51900319` | Disconnected — usually build mismatch | [Update build_info](#realm-shows-incompatible--build-mismatch) |
| `WOW51900225` | Incompatible version | [Update build_info](#realm-shows-incompatible--build-mismatch) |
| `WOW51900317` | Login server unavailable | Check if bnetserver is running, check ports |
| `WOW51900328` | Character transfer error / data mismatch | [Update build_info](#realm-shows-incompatible--build-mismatch), check character DB |
| `BLZ1914502` | Client disconnected | Build mismatch or missing maps |
| `MSVCP140D.dll not found` | Missing Visual C++ runtime | Install [VC++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe) |
| `libssl-3-x64.dll not found` | Missing OpenSSL DLL | Copy from `RelWithDebInfo/bin/RelWithDebInfo/` |
| `SQL Error 1064` | SQL syntax error | Re-copy query carefully, ensure correct database selected |
| `Unable to load map and vmap data` | Missing extracted data | [Extract maps](#map--vmap-extraction-problems) |
| `VMap version mismatch` | Extractor version ≠ client version | Re-extract with matching tools |

---

## Still Stuck?

If you've gone through everything above and you're still stuck:

1. **Collect your logs.** The two most useful files are:
   - `Server.log` — in your server's runtime folder
   - `DBErrors.log` — same folder

   Scroll to the **bottom** of each file — the most recent errors are at the end.

2. **Post in your community's troubleshooting channel** with:
   - What you tried
   - The exact error message (screenshot or copy/paste)
   - Your WoW client build number
   - Your server build number (from `SELECT * FROM auth.realmlist;`)

3. **Common things people forget to mention** that helpers will ask about:
   - Did you clear your WoW cache folder?
   - Are you using the correct database (auth vs. world)?
   - Did you restart both bnetserver AND worldserver after changes?
   - What OS are you on?

---

*Last updated: March 2026.*

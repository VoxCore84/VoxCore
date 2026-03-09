# Transmog Test Guide — Dummy-Proof Edition

> After building in VS, follow this EXACTLY. Every step matters.

---

## BEFORE YOU BUILD

### 1. Transmog Debug Logging — ALREADY ENABLED

The logger line has already been added to `worldserver.conf` (line 4172):
```
Logger.network.opcode.transmog=2,Server Debug
```

This enables Debug-level logging for ALL transmog opcodes (including TransmogBridge and
TransmogSpy addon relay). Logs go to both `Server.log` and `Debug.log`.

**Verify it's there**: Open `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/worldserver.conf`
and confirm line 4172 exists. If it's missing, add it after `Logger.network.kick`:
```
Logger.network.opcode.transmog=2,Server Debug
```

### 2. Clear Old Logs

Delete (or rename) these files in the runtime directory to start clean:
```
out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Server.log
out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Debug.log
out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/DBErrors.log
```

Also delete the old packet log if it exists:
```
out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/PacketLog/World.pkt
```

Packet binary logging is already enabled (`PacketLogFile = "PacketLog/World.pkt"`).

---

## BUILD

### 3. Build in Visual Studio

- Open VoxCore solution in VS 2026
- Select **x64-RelWithDebInfo** configuration (NOT Debug — 17s startup vs 60s)
- Build → Build Solution (Ctrl+Shift+B)
- Wait for clean build — zero errors expected

---

## START THE SERVER

### 4. Start Auth + World Servers

Start in this order:
1. Make sure MySQL is running (UniServerZ)
2. Launch `bnetserver.exe` from `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/`
3. Launch `worldserver.exe` from same directory
4. Wait for `TC> ` prompt (worldserver ready)

### 5. Verify Transmog Logging Is Active

The server won't print a visible confirmation for the logger. To verify it's working,
log in with a character and open the transmog NPC — then check `Server.log` for any
line containing `network.opcode.transmog`. If you see transmog debug entries appearing,
the logger is active. If `Server.log` is empty after interacting with the transmog NPC,
the config line wasn't picked up — stop, fix the config, restart.

---

## CONNECT AND TEST

### 6. Launch WoW Client + Log In

- Launch 12.0.1.66263 client
- Log in with your test account
- Use a character that has:
  - Some collected transmog appearances (any armor set)
  - Access to a transmog NPC (Ethereal in any capital city)
  - Ideally: at least one weapon enchant illusion collected

### 7. Open a Second Monitor / Window for Logs

Open `Server.log` in a text editor that auto-refreshes (VS Code, Notepad++ with tail plugin, or PowerShell):
```powershell
Get-Content "C:\Users\atayl\VoxCore\out\build\x64-RelWithDebInfo\bin\RelWithDebInfo\Server.log" -Wait -Tail 50
```

This lets you see transmog diagnostics in real-time as you click in the UI.

---

## THE TESTS (do them in order)

### Test A: Create New Outfit (BUG-G — the big one)

1. Talk to transmog NPC
2. Click "Save as new outfit" (or equivalent UI button)
3. Type a name: `TestOutfit1`
4. Click Save

**Watch Server.log for**:
```
CMSG_TRANSMOG_OUTFIT_NEW entry[0]: ordinal=1 option=0 wireDT=...
CMSG_TRANSMOG_OUTFIT_NEW entry[1]: ordinal=2 option=0 wireDT=...
...
```

Also look for the success confirmation:
```
SMSG_TRANSMOG_OUTFIT_NEW_ENTRY_ADDED [...]: setId=X guid=Y
```
This is the server's "outfit created" response. If you see the CMSG entries but NOT this
SMSG line, the parser worked but something downstream rejected the outfit.

**PASS**: Outfit appears in your outfit list with correct name AND `SMSG_TRANSMOG_OUTFIT_NEW_ENTRY_ADDED` in log.
**FAIL**: Parse error in log, or outfit doesn't appear, or CMSG logged but no SMSG response. Copy the full log block.

**If this fails, STOP** — BUG-G is the root cause of BUG-F and BUG-H. Everything downstream depends on this.

### Test B: Re-Apply Same Outfit (BUG-F)

1. With transmog UI still open, click the outfit you just created
2. Click "Apply"
3. Close transmog UI completely (press Escape or walk away from NPC)
4. Go back to transmog NPC, open UI again
5. Click the same outfit, click "Apply" again

**Watch Server.log for**:
- No `unknown transmog set id` errors
- `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS` entries should process cleanly each time

**PASS**: Outfit applies both times without errors.
**FAIL**: "Unknown set id" in log, or outfit disappears from list after first apply.

### Test C: Slots Not Growing (BUG-H1)

1. Repeat Test B two more times (close UI, reopen, apply — total of 4 applies)
2. Each time, note if the UI feels slower or laggier

**Watch for**:
- In-game: no lag increase, no growing UI delay across 4 applies
- Server.log: look for `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS` entries — they should process consistently each time
- Note: the `transmogSetCount=` diagnostic is on a different logger channel (`entities.player`) and won't appear unless that logger is also set to Debug. The behavioral test (no lag) is sufficient.

**PASS**: No lag increase, consistent behavior across all 4 applies.
**FAIL**: Progressive slowdown or UI stutter on later applies.

### Test D: Change Single Slot (BUG-H)

1. With outfit active, click the **Head** slot in the transmog UI
2. Pick a different head appearance from the wardrobe
3. Click to apply it

**Watch Server.log for**:
```
CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS ...
```

**PASS**: Head appearance changes on your character.
**FAIL**: Nothing happens when you click — no CMSG in log. (If this fails, it's a client-side routing issue, not our bug.)

### Test E: Hidden Pants (BUG-M6)

1. **Relog first** — the hidden pants IMA (216696) is auto-unlocked at character load via
   `CollectionMgr::LoadItemAppearances()`. Existing characters need a fresh login to pick it up.
2. In transmog UI, click the **Legs** slot
3. Look for "Hidden" option in the appearance list
4. Select it and apply

**PASS**: Pants become invisible on your character model.
**FAIL**: "Hidden" option doesn't appear for legs, or it appears but doesn't apply.

### Test F: Weapon Enchant Illusion (BUG-M2 + BUG-M9)

1. Equip a weapon that has an enchant illusion applied (e.g., Mongoose glow)
2. Create a NEW outfit (Test F outfit)
3. Close UI, reopen
4. Apply the outfit again
5. Check if the enchant glow is still visible

**Watch Server.log for**:
- `fillOutfitData`: look for `bootstrapped illusion` messages (should appear for ViewedOutfit only)
- NO `bootstrapped illusion` for stored outfit loads

**PASS**: Enchant illusion persists through re-apply. Stored outfit list does NOT show illusions from currently-equipped weapons.
**FAIL**: Illusion disappears after re-apply, or stored outfits show wrong illusions.

### Test G: Weapon Type Preservation (BUG-M5)

1. Equip a 1H sword + shield
2. Create a new outfit
3. Log out and back in (full relog)
4. Re-apply the outfit

**PASS**: Outfit applies with 1H+Shield, not defaulting to 2H or losing the weapon type.
**FAIL**: Weapon type selection lost after relog.

### Test H: Rename Outfit (Bonus — not a fix, just verify it works)

1. Click an existing outfit
2. Click rename / edit name
3. Change to `RenamedOutfit`

**PASS**: Name updates.
**FAIL**: Name doesn't change or reverts.

---

## AFTER TESTING

### 8. Collect Logs

Copy these files somewhere safe BEFORE stopping the server:
```
out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Server.log
out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Debug.log
out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/DBErrors.log
out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/PacketLog/World.pkt
```

### 9. Report Results

Tell Claude Code which tests passed and which failed. For failures, share:
1. The exact symptom (what you saw in-game)
2. The relevant Server.log block (search for `network.opcode.transmog`)
3. If possible, the packet log for analysis

### 10. Cleanup

After testing, you can comment out the debug logger to reduce log noise:
```
#Logger.network.opcode.transmog=2,Server Debug
```

Or leave it in — it only fires during transmog operations, so it's low-noise.

---

## Quick Reference: What Each Test Validates

| Test | Bug | What Broke Before | Key Log String |
|------|-----|-------------------|----------------|
| A | BUG-G | Name parser hit 0x80 pad byte, outfit creation failed | `CMSG_TRANSMOG_OUTFIT_NEW entry[` |
| B | BUG-F | SetID lookup broken after first apply | `unknown transmog set id` (should NOT appear) |
| C | BUG-H1 | Slots array grew 30→60→90 per sync | (behavioral — no lag on repeated apply) |
| D | BUG-H | Individual slot clicks did nothing | `CMSG_TRANSMOG_OUTFIT_UPDATE_SLOTS` |
| E | BUG-M6 | Pants couldn't be hidden | (visual check only) |
| F | BUG-M2/M9 | Illusions lost or leaked between outfits | `bootstrapped illusion` |
| G | BUG-M5 | Weapon type defaulted after relog | (visual check only) |
| H | — | Baseline rename test | `CMSG_TRANSMOG_OUTFIT_UPDATE_INFO` |

---

*Last updated: March 8, 2026 — Session 110*

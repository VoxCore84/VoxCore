# Auth Key System Notes

## How It Works
- `build_info` table: `build`, `majorVersion`, `minorVersion`, `bugfixVersion`
- `build_auth_key` table: `build`, `platform` (Win/Mac), `arch` (x64/A64), `type` (WoW/WoWC), `key` (binary 16)
- Keys are 16-byte (128-bit) values, stored as hex literals (e.g., `0x64C1CBF59BC8EE9B6681FCD5A5A14F7B`)
- Used in HMAC-SHA512 at `WorldSocket.cpp:670-700`: `HMAC(SHA512(sessionKey || authKey), localChallenge || serverChallenge || seed)`
- Client computes same HMAC with key baked into Wow.exe — must match server's result
- Loaded at startup via `ClientBuildInfo.cpp:135-201`

## Current Status (Mar 4 2026) — RESOLVED
- **Client**: 12.0.1.66220 (Battle.net auto-updated)
- **Server**: All 7 auth keys for build 66220 applied (Win/Mac, x64/A64, WoW/WoWC)
- **Bypass REVERTED**: Commit `8bbd610fc7` — WorldSocket.cpp now rejects missing auth keys
- **DB**: `build_info` + `build_auth_key` both have 66220 rows
- **SQL trail**: `sql/updates/auth/master/2026_03_04_00_auth.sql`
- **Pushed**: All clean, no security bypass in remote

## Auth Key Extraction (for future self-service)
- Keys are VMProtect-obfuscated in Wow.exe, can't be found statically
- **Method**: Runtime debugging — launch Wow.exe via Arctium, attach debugger, read key from memory during HMAC computation
- **Tools**: x64dbg + [WoWDumpFix](https://github.com/adde88/WoWDumpFix) (patches anti-debug byte in ntdll!DbgBreakPoint), or Frida
- **Anti-debug**: WoW patches `ntdll!DbgBreakPoint` 0xCC→0xC3 to prevent debugger attachment
- Shauren likely has this automated — keys appear within hours of new builds
- Each build needs keys for: Win/x64/WoW, Win/x64/WoWC, Win/A64/WoW, Mac/x64/WoW, Mac/x64/WoWC, Mac/A64/WoW, Mac/A64/WoWC

## TC Merge Artifact Fixed
- `SellAllJunkItems` was duplicated in ItemPackets.h, ItemPackets.cpp, WorldSession.h, ItemHandler.cpp
- Kept TC's newer `const&` version (uses `CanSellItemToVendor`), removed old non-const `&` version
- Pushed as `50fb430e43`

## Preventing Future Auto-Updates
- In Battle.net settings, set WoW to "Update when I launch the game" instead of auto-update
- Don't launch WoW through Battle.net — use Arctium directly

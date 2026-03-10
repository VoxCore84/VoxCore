# DraconicBot — Discord Support Bot

Discord support bot for DraconicWoW community. Located at `tools/discord_bot/`.

## Overview
- **Version**: 2.1 (session 129)
- **Language**: Python (discord.py)
- **Structure**: 19 modules, ~2,700 lines
- **Cogs**: 14
- **Slash Commands**: 16
- **Status**: Built, awaiting server owner authorization to deploy

## Cogs & Commands

| Cog | Commands | Purpose |
|-----|----------|---------|
| `faq.py` | (auto-trigger) | FAQ auto-responder — 11 patterns from 30K message analysis |
| `lookups.py` | `/spell`, `/item`, `/creature`, `/area`, `/faction` | Wago DB2 CSV lookups with cooldowns (5/30s per user) |
| `bugs.py` | (auto-trigger) | Bug report triage — auto-threading, duplicate detection, channel misrouting nudge |
| `status.py` | `/status` | Server status via SOAP |
| `watchdog.py` | (auto-trigger) | TrinityCore GitHub build watchdog — hourly polling |
| `wowhead.py` | (auto-trigger) | Wowhead link resolver — auto-embed tooltips |
| `onboarding.py` | (auto-trigger) | New member onboarding DM |
| `help.py` | `/help` | Interactive dropdown menu (7 categories) |
| `troubleshoot.py` | `/troubleshoot` | Button-driven decision tree (3 flows x 2-4 branches) |
| `changelog.py` | (auto-trigger) | Hourly GitHub polling for new commits |
| `automod.py` | (auto-trigger) | Invite filter, spam detection, new account alerts |
| `welcome.py` | `/verifypanel` | Welcome role verification panel with persistent button |
| `about.py` | `/about` | Version, uptime, stats |
| `announce.py` | `/announce` | Admin embed posts |

## Analytics (from 30K message analysis)
- 29,935 messages across 10 channels (Apr 2024 - Mar 2026)
- Server owner personally answered 5,404 messages (18.1%)
- 300+ times answering the same 6 FAQ topics
- 613 categorized support issues, 2,883 uncategorized

## Known Issues (Antigravity Audit)
- **PyMySQL synchronous blocking** in `cogs/lookups.py` — needs async DB access
- **Race condition** in `cogs/faq.py` — concurrent FAQ trigger handling
- Audit: `AI_Studio/3_Audits/` (marked FAIL, fixes pending)

## Assets
- 68 custom WoW icon emojis (class icons, expansion coins, difficulty badges, category icons)
- Token in gitignored `.env`

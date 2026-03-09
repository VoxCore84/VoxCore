# Audit Request — DraconicBot v2.1

**Date:** 2026-03-09
**Sessions:** 126 (initial build), 127 (v2 features), current (v2.1 polish)
**Commits:** `593cb53ae6`, `64a786a312`, pending

## Spec from ChatGPT

No formal ChatGPT spec for this project — the bot was designed collaboratively between the user and Claude Code across sessions 126-127. The requirements were derived from:
1. Analysis of 29,935 Discord messages across 10 channels (Apr 2024 – Mar 2026)
2. User's feature requests during interactive sessions
3. Discord Developer Portal configuration walkthrough

**Core requirements (implicit spec):**
- Discord support bot for a WoW private server community (DraconicWoW)
- Each community member runs their own local worldserver (NOT a shared server)
- Must integrate with: Wago DB2 CSVs, MySQL world database, TrinityCore GitHub API
- SOAP commands are local-only (optional, not community-facing)
- 68 custom WoW icon emojis with Unicode fallbacks
- All slash commands, no prefix commands for users

## Files Modified (this session)

- `tools/discord_bot/bot.py` — Added startup config validation, `start_time` tracking, `BOT_VERSION`, registered 2 new cogs (about, announce)
- `tools/discord_bot/emojis.py` — (Previous session) Fixed `em()` to accept optional fallback parameter
- `tools/discord_bot/cogs/faq.py` — Added persistent FAQ stats tracking (`faq_stats.json`), `/faqstats` admin command
- `tools/discord_bot/cogs/lookups.py` — Added per-user cooldowns (5 uses / 30 seconds) to all 5 lookup commands
- `tools/discord_bot/cogs/help.py` — Updated categories to include new commands (/announce, /faqstats, /about)

## Files Created (sessions 127 + current)

- `tools/discord_bot/cogs/help.py` — `/help` interactive dropdown menu (8 categories)
- `tools/discord_bot/cogs/troubleshooter.py` — `/troubleshoot` button-driven decision tree (3 flows, 10+ leaf solutions)
- `tools/discord_bot/cogs/changelog.py` — TrinityCore GitHub commit feed (hourly polling)
- `tools/discord_bot/cogs/automod.py` — Invite link filter, spam detection, new account alerts
- `tools/discord_bot/cogs/welcome_role.py` — `/verifypanel` persistent button for self-verification
- `tools/discord_bot/cogs/about.py` — `/about` command (version, uptime, cog count)
- `tools/discord_bot/cogs/announce.py` — `/announce` admin command (formatted embed posts)

## Full File Inventory

**Source root:** `C:\Users\atayl\VoxCore\tools\discord_bot\`
(Also accessible via junction: `C:\Users\atayl\VoxCore\AI_Studio\Projects\DiscordBot\Z_SourceCode\`)

### Core modules
| File | Purpose |
|------|---------|
| `__main__.py` | Entry point: `python -m discord_bot` |
| `__init__.py` | Package marker |
| `bot.py` | Bot class, cog loader, config validation |
| `config.py` | `.env` loader, channel IDs, MySQL/SOAP/GitHub config |
| `emojis.py` | Application emoji cache with Unicode fallbacks |
| `soap.py` | Async SOAP client for TrinityCore worldserver |
| `github_monitor.py` | TrinityCore GitHub API: auth SQL file listing, build number extraction |
| `wowhead.py` | Wowhead URL regex parser |

### Cogs (14 total)
| File | Slash Commands | Listeners |
|------|---------------|-----------|
| `cogs/help.py` | `/help` | — |
| `cogs/about.py` | `/about` | — |
| `cogs/announce.py` | `/announce` | — |
| `cogs/faq.py` | `/faqstats` | `on_message` (pattern matching) |
| `cogs/lookups.py` | `/spell`, `/item`, `/creature`, `/area`, `/faction` | — |
| `cogs/server_status.py` | `/server`, `/online` | — |
| `cogs/watchdog.py` | `/buildcheck` | background task (GitHub polling) |
| `cogs/troubleshooter.py` | `/troubleshoot` | — |
| `cogs/changelog.py` | — | background task (GitHub polling) |
| `cogs/triage.py` | — | `on_message` (bug categorization) |
| `cogs/automod.py` | — | `on_message` (spam/invite), `on_member_join` (new account) |
| `cogs/onboarding.py` | — | `on_member_join` (welcome DM) |
| `cogs/wowhead_resolver.py` | — | `on_message` (wowhead link detection) |
| `cogs/welcome_role.py` | `/verifypanel` | persistent view (verify button) |

### Data files
| File | Purpose |
|------|---------|
| `data/faq_responses.json` | 11 FAQ entries with regex patterns and response text |
| `data/faq_stats.json` | Persistent FAQ trigger counts (auto-created) |
| `data/.last_known_build` | Watchdog state: last seen auth SQL build number |
| `data/.last_known_commit` | Changelog state: last seen GitHub commit SHA |
| `data/emojis/*.png` | 68 custom WoW icon PNGs (uploaded to Discord) |
| `data/banner_960x540.png` | Bot banner image |
| `.env` | Secrets (gitignored): token, channel IDs |
| `.env.example` | Template for `.env` |
| `requirements.txt` | Python dependencies |

## Database Hooks Used

### MySQL (via pymysql, synchronous)
- **Database:** `world`
- **Tables queried:**
  - `creature_template` — `/creature` lookup (SELECT entry, name, subname, faction, Classification)
  - `creature_template` — Wowhead resolver NPC check (SELECT name WHERE entry = ?)
  - `quest_template` — Wowhead resolver quest check (SELECT name WHERE ID = ?)
  - `gameobject_template` — Wowhead resolver GO check (SELECT name WHERE entry = ?)
- **No writes.** All queries are read-only SELECTs with parameterized values (%s placeholders)
- **Connection pattern:** New connection per query, closed immediately. No connection pooling.

### Wago DB2 CSVs (via csv.DictReader, read-only)
- `SpellName-enUS.csv` — `/spell` lookup, wowhead resolver
- `ItemSparse-enUS.csv` — `/item` lookup, wowhead resolver
- `AreaTable-enUS.csv` — `/area` lookup
- `Faction-enUS.csv` + `FactionTemplate-enUS.csv` — `/faction` lookup

### No VoxCore custom DB access
The bot does NOT access the `roleplay`, `characters`, `auth`, or `hotfixes` databases. All queries hit `world` (read-only) or Wago CSVs.

## Dev Notes

1. **em() bug fix (session 127):** The `em()` function was defined with 1 parameter but every cog called it with 2. Python would raise `TypeError` at runtime. Fixed by adding optional `fallback` parameter. This was a latent crash bug that would have prevented the bot from starting.

2. **Architecture decision — no shared server:** The user clarified that each community member runs their own local worldserver. SOAP-based features (`/server`, `/online`) only work for whoever runs the bot locally. They're kept for convenience but aren't community-facing. All SOAP features were intentionally NOT expanded (no command bridge, no server monitor, no self-unstuck).

3. **Cooldown implementation:** Used `@app_commands.checks.cooldown(5, 30.0, key=lambda i: i.user.id)` — this is discord.py's built-in rate limiter. 5 uses per 30 seconds per user. No custom cooldown error handler yet (users will get a generic "command on cooldown" message from discord.py).

4. **FAQ stats persistence:** Stats are saved to `data/faq_stats.json` on every trigger. This is a simple JSON file, not a database. For a small community bot this is fine, but at scale it would need debouncing or async writes.

5. **Changelog feed vs build watchdog:** These are separate cogs that both poll GitHub. The watchdog checks auth SQL files for new builds (every 5 minutes). The changelog checks all commits (every 1 hour). They use different state files and different API endpoints.

6. **Welcome role persistence:** The verify button uses `custom_id="draconicbot:verify"` and `timeout=None` on the view, registered in `cog_load()`. This means the button survives bot restarts — users can click it days after the panel was posted.

## Audit Focus Areas

1. **SQL injection safety** — All MySQL queries use parameterized `%s` placeholders. Verify no f-string interpolation in SQL.
2. **Rate limiting completeness** — Lookups have cooldowns. Do other commands need them?
3. **Error handling** — What happens when MySQL is down? When CSVs are missing? When GitHub API rate-limits?
4. **Concurrency** — Multiple `on_message` listeners (FAQ, triage, automod, wowhead resolver) all fire on every message. Any conflict potential?
5. **Secret safety** — Token in `.env`, `.env` in `.gitignore`. Verify no hardcoded secrets anywhere.
6. **Discord API compliance** — Embed limits (4096 chars description, 256 chars title), interaction response timing (3s for initial, 15min for followup).

# VoxCore Session State — Multi-Tab Coordination

**Read this FIRST in any new Claude Code tab.**
This is the single source of truth for what all tabs are doing, what's done, what's blocked, and what to pick up next. Updated by whichever tab finishes work.

**Last updated**: March 8, 2026 — Session 108 (consolidation)

---

## Active Tabs & Assignments

| Tab | Assignment | Status | Notes |
|-----|-----------|--------|-------|
| Main (session 107) | Meta infrastructure, gist updates, coordination | COMPLETE | Commit `8aa10362ad`. Created session_state, bug tracker, skills, report |
| Main (session 108) | Consolidation — review all transmog docs, fix errors, update gists/memory | COMPLETE | Slot ordering fix, sniffing docs tracked |
| Transmog Tab | Bug fixes from `memory/transmog-bugtracker.md` | NOT STARTED | Run `/transmog-implement` to begin |
| — | — | — | Add rows as tabs are opened |

**Rule**: Before starting work, check this file. If another tab owns a file or task, don't touch it. Update your row when you start and when you finish.

---

## Current Server State

- **Build**: `e90f4da5bc` (Mar 8 2026, RelWithDebInfo)
- **Server**: NOT RUNNING (last ran 12:47 today, clean shutdown)
- **Client**: 12.0.1.66263
- **DB**: world 1,086 MB (611K creatures) | hotfixes 811 MB (400K spells) | characters 4 MB
- **Logs**: Clean — zero crashes/fatals. SmartAI warnings + unhandled 12.x opcodes only.
- **Needs build**: `.npc copy` command + `cs_npc` kill/respawn removal (code done, not compiled)

---

## What Needs Doing — Priority Order

### Tier 1: Build & Test (requires human + server restart)

These are blocked on building in VS and running the server. No Claude Code tab can do these alone.

- [ ] **Build in VS** — compile current master (`.npc copy`, cs_npc changes)
- [ ] **Restart worldserver** and test:
  - Arcane Waygate (`.cast 1900028`, gossip, teleports)
  - Stormwind phase fixes (7 phase_area, Genn/Velen/Anduin visibility)
  - Valdrakken portal, embassy NPCs, Hero's Call Boards
  - Apply `_08_00` SQL before restarting
- [ ] **Transmog in-game verification** — ALL fixes from sessions 52-73 deployed but never tested
- [ ] **Enable crash dumps** — Windows crash dump generation for worldserver

### Tier 2: Transmog Bug Fixes (Claude Code tab can do independently)

**Assign to**: Transmog Tab
**How**: Run `/transmog-implement` — reads bug tracker, picks next bug, implements fix
**Bug tracker**: `C:\Users\atayl\.claude\projects\C--Users-atayl-VoxCore\memory\transmog-bugtracker.md`
**Full context**: `doc/transmog_implementation_report.md`
**Behavioral rules**: CLAUDE.md "Transmog UI / Midnight 12.x" section

Priority order:
1. **BUG-F** (CRITICAL): SetID mapping destroyed after first apply — needs investigation
2. **BUG-G** (CRITICAL): Name pad byte 0x80 backward scan — fix: use nameLen field
3. **BUG-H** (CRITICAL): Individual slot transmog blocked — needs investigation
4. **BUG-H1** (HIGH): Stored Slots accumulation 30→60→90 — 2-line fix in Player.cpp
5. **BUG-M1** (HIGH): Enchant rejects entire outfit — zero bad enchants instead
6. **BUG-M6** (HIGH): Hidden pants missing — add ItemID 216696 to two arrays
7. **BUG-M9** (HIGH): Illusion bootstrap leaks into stored — add `!isStored` gate
8. **BUG-M2** (HIGH): Bridge loses illusions — decouple enchant mask
9. **BUG-M5** (HIGH): Weapon option never stored — store byte[1] to MH/OH option

After each fix: update bug tracker status, show diff, note "ready for build".

### Tier 3: World DB Cleanup (Claude Code tab can do independently)

**Assign to**: Any available tab
**How**: Run `python tools/diff_draconic.py --zone <id> --map <map>`
**Plan**: `doc/world_db_cleanup_plan.md`

Priority order:
1. Orgrimmar (zone 1637, map 1)
2. Ironforge (zone 1537, map 0)
3. Thunder Bluff (zone 1638, map 1)
4. Darnassus (zone 1657, map 1)
5. Undercity (zone 1497, map 0)
6. Exodar (zone 3557, map 530)
7. Silvermoon (zone 3487, map 530 → newly map 0 for Midnight)
8. Dalaran (zone 4395, map 571)
9. Global phase_area audit (after all zones done)

Each zone produces a SQL file in `sql/exports/` and findings for review.

### Tier 4: Spell Implementation (Claude Code tab can do independently)

**Assign to**: Any available tab
**Context**: `memory/spell-audit.md`
- 13 RED spells need real C++ implementations (SimC-guided)
- 84 YELLOW passive DUMMY auras (low priority)
- Key spells: Avenging Wrath, Pillar of Frost, Blood Plague, Divine Hymn

### Tier 5: Data Quality (Claude Code tab can do independently)

- **66 crash-risk creature displayIDs** — query world DB, fix or remove
- **3 MySQL deadlocks** — investigate transaction contention patterns
- **Companion Squad SQL** — apply `sql/RoleplayCore/5.1 companion characters.sql`
- **Equipment gaps** — 13K NPCs missing `creature_equip_template`

### Tier 6: Website & Polish

- Arcane Codex website asset pipeline (Phase 0 ready)
- Skyriding/dragonriding outside Dragon Isles
- Orgrimmar portal room → Silvermoon (BC-era → Midnight)

---

## Key Files Quick Reference

| What | Where |
|------|-------|
| **This file** (coordination) | `doc/session_state.md` |
| Transmog bug tracker | `memory/transmog-bugtracker.md` |
| Transmog full report | `doc/transmog_implementation_report.md` |
| Transmog behavioral rules | CLAUDE.md → "Transmog UI / Midnight 12.x" section |
| World cleanup plan | `doc/world_db_cleanup_plan.md` |
| Spell audit status | `memory/spell-audit.md` |
| To-do list | `memory/todo.md` |
| Open issues (GitHub gist) | `doc/gist_open_issues.md` |
| Changelog (GitHub gist) | `doc/gist_changelog.md` |
| DB report (GitHub gist) | `doc/gist_db_report.md` |

## Skills Available

| Skill | What It Does |
|-------|-------------|
| `/transmog-implement` | Pick next bug from tracker, implement fix, update tracker |
| `/transmog-status` | Quick overview of open transmog bugs |
| `/transmog-correct` | Corrective pass on fillOutfitData behavioral model |
| `/build-loop` | Iterative build + fix compilation errors |
| `/check-logs` | Read server logs for errors |
| `/apply-sql` | Apply SQL file to a database |
| `/new-sql-update` | Create correctly-named SQL update file |
| `/lookup-spell` / `/lookup-item` / etc. | DB2 lookups |
| `/wrap-up` | End-of-session checklist |

---

## Rules for Multi-Tab Work

1. **Read this file first** in every new tab
2. **Claim your assignment** — update the Active Tabs table before starting
3. **One bug per commit** — don't combine fixes across domains
4. **Don't touch files another tab owns** — check the table
5. **Update this file when done** — move your task to completed, note what changed
6. **Never build from Claude Code** — user builds via VS IDE
7. **Don't duplicate research** — if a memory file or report covers it, read that instead of re-analyzing source code
8. **Update bug trackers** — after fixing a bug, change its status in the tracker

---

## Recently Completed (for context)

| Session | What | Key Output |
|---------|------|-----------|
| 107 | Meta infrastructure | This file, bug tracker, skills, gist updates |
| 106 | Wrap-up | Committed sessions 104-105b work |
| 105b | Transmog DeepDive | `doc/transmog_deepdive_wiki.md`, 4 memory files |
| 104 | Draconic diff + SW | `tools/diff_draconic.py`, 7 phase_area fixes |
| 103 | NPC tooling | `.npc copy` command |
| 102 | Collection unlocks | `.maxrep`/`.maxachieve`/`.maxtitles` |
| 101 | SpellAudit cleanup | Removed 1,842 broken stubs |

---

## GitHub Gists (synced March 8)

- DB Report: https://gist.github.com/528e801b53f6c62ce2e5c2ffe7e63e29
- Changelog: https://gist.github.com/4c63baf8154753d2a89475d9a4f5b2cc
- Open Issues: https://gist.github.com/2b69757faa2a53172c7acb5bfa3ad3c4

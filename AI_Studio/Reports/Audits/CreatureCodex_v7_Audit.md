---
reviewed: CreatureCodex v1.0.0v7
reviewer: ChatGPT (gpt-5.4)
date: 2026-03-13
prompt_tokens: 72831
completion_tokens: 6594
total_tokens: 79425
---

# CreatureCodex v1.0.0v7 — Final Audit

## Executive Verdict

**NO-SHIP**

v7 does fix the specific v6 findings you listed, and I verified those fixes in the embedded files. However, the distribution still contains **multiple new ship blockers**, including:

- **High:** addon/runtime logic bug in Eluna spell-list protocol handling causing incomplete DB-known imports for multi-message `SL` responses.
- **High:** `install_hooks.py --revert` is still dangerously over-broad and can remove unrelated TrinityCore symbols/functions containing the same hook names.
- **Medium:** Linux/macOS wrapper docs still overclaim portability for Windows-only tooling.
- **Medium:** README / guide claims “4 hooks across 4 files” while the actual required manual patch surface is **6 files** if you include `WorldSession` helper and RBAC enum.
- **Medium:** `wpp_import.py --lua` writes DB version `3` while addon runtime expects/migrates to `VERSION = 4`; not fatal, but hostile audience will call it out immediately.
- **Medium:** several docs describe capabilities/flows that are not actually bundled in the shipped files (`tools/WowPacketParser`, `tools/Ymir` are not present in distribution; only placeholders/docs are present). That may be acceptable if framed as post-download, but some wording implies they are already there.

So: **the v7 fixes are mostly real, but the package is still not ready for a TrinityCore Discord hostile review.**

---

# 1) Task 1 — Verification of All 6 v7 Fixes

## Fix 1: All stale `AGGREGATION_DB` references removed

### Result: **CONFIRMED**

I checked all relevant shipped docs and SQL.

#### Evidence

- `README.md` aggregation section now says:
  - “default: `characters`” and
  - “This table must exist in your `characters` database (the same one that `CharDBExecute` targets).”
- `README_DE.md` says:
  - “Standard: `characters`”
  - “Diese Tabelle muss in Ihrer `characters`-Datenbank existieren...”
- `README_RU.md` says:
  - “по умолчанию: `characters`”
  - “Эта таблица должна существовать в вашей базе данных `characters`...”
- `sql/codex_aggregated.sql` says:
  - `-- Apply this to your characters database: mysql -u root -p characters < codex_aggregated.sql`

I found **zero** remaining `AGGREGATION_DB` references in the embedded files.

---

## Fix 2: Export.lua HP comment fixed

### Result: **CONFIRMED**

#### Evidence

In `CreatureCodex/Export.lua`, inside `GenerateSmartAI()`, the HP-phase comment now reads:

- `CreatureCodex/Export.lua`:
  - `-- Spell seen below 40% HP at least once — use HP% event instead`

This matches the requested wording change and aligns with docs in:
- `README.md`
- `README_DE.md`
- `README_RU.md`
- `_GUIDE/04_Understanding_Exports.md`

I found **zero** occurrences of the old wording fragment `only seen below 40`.

---

## Fix 3: RBAC docs aligned to shipped SQL

### Result: **CONFIRMED**

#### Evidence

Shipped SQL:
- `sql/auth_rbac_creature_codex.sql`
  - `INSERT IGNORE INTO rbac_permissions ...`
  - `INSERT IGNORE INTO rbac_linked_permissions ...`

Docs now match that exact pattern:

- `README.md` Step 4:
  - uses `INSERT IGNORE`
  - uses `rbac_linked_permissions`
- `README_DE.md` Step 4:
  - same
- `README_RU.md` Step 4:
  - same
- `_GUIDE/02_Server_Setup.md`:
  - says `.codex` requires RBAC permission 3012, consistent with shipped SQL and C++ command registration.

No remaining mention of `rbac_default_permissions` was present in embedded files.

---

## Fix 4: `AR` protocol message documented

### Result: **CONFIRMED**

#### Evidence

All three READMEs now include:

- `S->C | AR | AR|entry|OK | Aggregation acknowledgement`

Specifically present in:
- `README.md` → “Protocol Reference”
- `README_DE.md` → “Protokoll-Referenz”
- `README_RU.md` → “Справочник протокола”

And code supports it:

- `CreatureCodex/CreatureCodex.lua`
  - `OnAddonMessage()` handles `msgType == "AR"`
  - comment: `-- AR|entry|OK — aggregation acknowledgement`

So docs and code are aligned here.

---

## Fix 5: Version/badge consistency

### Result: **CONFIRMED**

#### Evidence

All three READMEs now show:

- H1: `# CreatureCodex v1.0.0`
- badge label: `label=v1.0.0`

Verified in:
- `README.md`
- `README_DE.md`
- `README_RU.md`

Also consistent with:
- `CreatureCodex/CreatureCodex.toc` → `## Version: 1.0.0`
- `CreatureCodex/CreatureCodex.lua` → `local ADDON_VERSION = "1.0.0"`

---

## Fix 6: `--revert` caveat added

### Result: **CONFIRMED**

#### Evidence

In `_GUIDE/02_Server_Setup.md`:

- revert command is documented as:
  - `Remove the hooks later (best-effort — may leave minor whitespace artifacts; verify with git diff):`

This addresses the prior documentation gap.

**However:** the caveat is still **understated** relative to the actual revert implementation. More on that in blockers below.

---

# 2) Task 2 — Cross-Reference Integrity Audit

This section checks whether docs match actual code, file paths, function names, columns, and commands.

---

## 2.1 Addon file structure references

### Result: **Mostly correct**

Docs reference these addon files:
- `CreatureCodex/CreatureCodex.lua`
- `CreatureCodex/Export.lua`
- `CreatureCodex/UI.lua`
- `CreatureCodex/Minimap.lua`
- `CreatureCodex/CreatureCodex.toc`

All are present and listed in `CreatureCodex/CreatureCodex.toc`.

---

## 2.2 Slash commands

### Result: **Correct**

Documented commands in `README.md` / DE / RU:
- `/cc`
- `/codex`
- `/cc export`
- `/cc debug`
- `/cc stats`
- `/cc zone`
- `/cc submit`
- `/cc sync`
- `/cc reset`

Implemented in:
- `CreatureCodex/CreatureCodex.lua`, `SlashCmdList["CREATURECODEX"]`

All documented commands exist.

---

## 2.3 Protocol reference vs addon/client code

### Result: **Mostly correct, with one important protocol bug**

Implemented in `CreatureCodex/CreatureCodex.lua`:
- `SC`, `SS`, `CF`, `AA` → handled by `HandleServerSpellMessage`
- `SL` → `HandleSpellListMessage`
- `CI` → `HandleCreatureInfoMessage`
- `ZC` → `HandleZoneCreaturesMessage`
- `AR` → handled in `OnAddonMessage`

Sent by client:
- `SL|entry`
- `CI|entry`
- `ZC|mapId`
- `AG|entry|spellId:count,...`

Sent by Eluna:
- `SL|entry|count|csv`
- `CI|entry|name|faction|min|max|classification`
- `ZC|mapId|total|csv`
- `AR|entry|OK`

### Problem
`HandleSpellListMessage(entry, count, spellCSV)` in `CreatureCodex/CreatureCodex.lua` only marks DB-known spells **if `db[entry]` already exists**. That part is okay because targeting creates the creature first.

But the bigger issue is **multi-message `SL` responses** from Eluna are chunked, and the client ignores `count` and has no completion/merge semantics. It just parses each CSV independently. That itself is okay for additive marking, **but** the Eluna empty response format is `SL|entry|0` with **no fourth field**, and the client returns early on `if not entry or not spellCSV then return end`, meaning it cannot distinguish “checked and empty” from “no response / malformed response”.

That is not fatal by itself, but it means the protocol is not fully self-describing as documented.

More serious: see blocker in section 4.1.

---

## 2.4 GM commands vs C++ command script

### Result: **Correct**

Docs list:
- `.codex query <entry>`
- `.codex stats`
- `.codex blacklist add <spellId>`
- `.codex blacklist remove <spellId>`
- `.codex blacklist list`

Implemented in:
- `server/cs_creature_codex.cpp`
  - `GetCommands()`
  - root command `"codex"`
  - subcommands `query`, `stats`, `blacklist`
  - blacklist subcommands `add`, `remove`, `list`

RBAC constant used:
- `rbac::RBAC_PERM_COMMAND_CREATURE_CODEX`

Docs say add enum:
- `RBAC_PERM_COMMAND_CREATURE_CODEX = 3012`

That matches intended integration.

---

## 2.5 SQL column names and table names

### Result: **Correct**

Verified against docs and generated SQL:

#### `creature_template_spell`
- columns used:
  - `CreatureID`
  - `Index`
  - `Spell`
- used in:
  - `CreatureCodex/Export.lua`
  - `tools/wpp_import.py`
  - docs in README and guide

#### `smart_scripts`
- columns used:
  - `entryorguid`
  - `source_type`
  - event/action params
- used in:
  - `CreatureCodex/Export.lua`
  - `tools/wpp_import.py`
  - docs in README and guide

#### `codex_aggregated`
- columns:
  - `creature_entry`
  - `spell_id`
  - `cast_count`
  - `last_reporter`
  - `last_seen`
- used consistently in:
  - `sql/codex_aggregated.sql`
  - `server/lua_scripts/creature_codex_server.lua`
  - README docs

---

## 2.6 Server setup docs vs actual required patch surface

### Result: **Not fully accurate**

`_GUIDE/02_Server_Setup.md` says:

- “It’s 4 hooks across 4 files.”

That is **not the full installation surface** for the shipped server-assisted feature set.

Actual required touched files from docs/code:
1. `src/server/game/Scripting/ScriptMgr.h`
2. `src/server/game/Scripting/ScriptMgr.cpp`
3. `src/server/game/Spells/Spell.cpp`
4. `src/server/game/Entities/Unit/Unit.cpp`
5. `src/server/game/Server/WorldSession.h`
6. `src/server/game/Server/WorldSession.cpp`
7. `src/server/game/Accounts/RBAC.h`
8. `src/server/scripts/Custom/custom_script_loader.cpp`

So “4 hooks across 4 files” is only true for the **UnitScript hook insertion**, not for the **full server setup** being documented. A TC dev will notice this instantly.

---

## 2.7 Tooling docs vs shipped files

### Result: **Partially accurate, but wording overstates what is bundled**

The file structure in README lists:
- `tools/WowPacketParser/`
- `tools/Ymir/`

These directories are **not embedded in the provided distribution contents**. Instead you ship:
- `tools/_README.txt`
- `tools/parsed/_What_To_Do_With_These_Files.txt`
- updater scripts that download them later

This is okay if the release zip truly includes empty placeholder dirs, but in the provided “Complete Distribution Contents” they are absent. Since you asked for audit against shipped files, the docs currently imply more than is actually present.

---

# 3) Task 3 — Fresh Adversarial Walkthroughs

---

## 3.1 Persona: Noob

### Scenario
- Never installed an addon
- ChromieCraft repack
- No Python

### Outcome: **Client-only path is mostly usable**

#### What works
- `_GUIDE/01_Quick_Start.md` is clear and practical.
- It correctly explains folder nesting.
- It correctly says addon works standalone.
- `/cc` and minimap icon are documented.
- Export flow is understandable.

#### Friction points
1. **Retail path example only**
   - Quick Start says “Retail: `C:\World of Warcraft\_retail_\Interface\AddOns\`”
   - For private server users this is okay, but a true noob may still be confused because private server clients often have different folder layouts.

2. **TOC/interface mismatch risk**
   - `CreatureCodex.toc` has `## Interface: 120001`
   - docs say “Load out of date AddOns” if needed, which is good.

3. **Export expectations**
   - README headline strongly sells “your NPCs now cast spells with proper timing and behavior”
   - but noob on a repack without source access only gets visual scraper, not full server hooks.
   - This is disclosed, but the top-level marketing is stronger than the practical noob outcome.

### Noob verdict
**Usable, but slightly overmarketed.** Not a blocker.

---

## 3.2 Persona: TC Bully

### Outcome: **They will find real issues quickly**

A hostile TC dev will likely attack these points immediately:

1. **`install_hooks.py --revert` is unsafe**
   - It removes lines/functions by substring matching, not exact patch reversal.
   - It can delete unrelated symbols if TrinityCore later adds similarly named methods.

2. **“4 hooks across 4 files” is misleading**
   - Full setup requires more than that.

3. **Eluna `SL` protocol handling is weak**
   - empty response is ambiguous
   - chunked response has no completion semantics
   - client marks `dbKnown` only opportunistically

4. **`wpp_import.py --lua` writes version 3**
   - addon runtime is version 4
   - looks sloppy

5. **Linux/macOS wrappers**
   - docs say wrappers exist, but core scripts use `tasklist`, `os.startfile`, Windows `.exe`, PowerShell shortcut creation, `curl` assumptions, etc.
   - wrappers are best-effort stubs, not real cross-platform support

6. **Potential compile/API fragility**
   - `SpellInfo->SpellName` usage in `server/cs_creature_codex.cpp` is version-sensitive and may not match current TC master internals depending on exact branch snapshot.
   - Since no exact TC commit is pinned, “any recent master” is too broad.

### TC bully verdict
They will absolutely call this **not production-clean**.

---

# 4) Task 4 — New Issues Introduced / Remaining

## 4.1 HIGH — Eluna spell-list import is incomplete/fragile for real-world use

### Files
- `CreatureCodex/CreatureCodex.lua`
- `server/lua_scripts/creature_codex_server.lua`

### Exact issue

`server/lua_scripts/creature_codex_server.lua` can split spell lists across multiple addon messages:

- `HandleSpellListRequest()`
  - builds multiple `SL|entry|count|spell1,spell2,...` messages when needed

Client handler:
- `CreatureCodex/CreatureCodex.lua`
  - `HandleSpellListMessage(entry, count, spellCSV)`

Problems:
1. Empty response is sent as `SL|entry|0` (no CSV field).
   - Client returns early because `spellCSV` is nil.
   - So it cannot record “DB checked, zero spells”.

2. There is no completion state.
   - If a creature has many spells and only some chunks arrive, client silently treats partial data as complete.
   - No ack, no expected chunk count, no end marker.

3. `count` is parsed but never used.
   - That makes the protocol field effectively dead.

### Why this matters
This is one of the core “DB-known vs new” features in the UI/export path. Partial or ambiguous `SL` handling undermines:
- `dbKnown` marking
- “DB-confirmed” comments in export
- “New Only” export correctness

### Severity
**High**

### Recommendation
At minimum:
- always send `SL|entry|count|` even for zero spells
- client should treat empty CSV with count 0 as valid
- add chunking semantics, e.g. `SL|entry|count|part|total|csv` or `SLB`/`SLE` framing
- or keep responses single-message only and hard-cap documented behavior

---

## 4.2 HIGH — `install_hooks.py --revert` remains unsafe beyond “minor whitespace artifacts”

### File
- `server/install_hooks.py`

### Exact issue

`revert_hooks()` removes lines/functions by broad substring heuristics:

It deletes any line containing:
- `"OnCreatureSpellCast"`
- `"OnCreatureSpellStart"`
- `"OnCreatureChannelFinished"`
- `"sScriptMgr->OnAuraApply"`

and also special-cases `"OnAuraApply"` if line contains:
- `"virtual"` or `"sScriptMgr"` or `"void ScriptMgr::"` or `"void On"`

This is **not exact reversal of inserted hunks**. It can remove:
- unrelated future TrinityCore methods with same names
- user custom code using same symbol names
- legitimate declarations/definitions not inserted by this script

The guide caveat says:
- “best-effort — may leave minor whitespace artifacts; verify with `git diff`”

That is materially understated. This is not just whitespace fragility; it is **semantic over-deletion risk**.

### Severity
**High**

### Recommendation
Implement exact marker-based revert only:
- insert unique begin/end markers around every injected block
- revert only between those markers
- for one-line call-site insertions, match exact inserted line with exact indentation and remove only that line

Until then, docs should explicitly warn:
- revert may remove unrelated code
- use only on clean git working tree
- inspect full diff before commit

---

## 4.3 MEDIUM — `_GUIDE/02_Server_Setup.md` still understates required patch scope

### File
- `_GUIDE/02_Server_Setup.md`

### Exact issue
It says:
- “It’s 4 hooks across 4 files.”

But the same guide then requires:
- `WorldSession.h`
- `WorldSession.cpp`
- `custom_script_loader.cpp`

And README also requires:
- `RBAC.h`

A hostile reader will call this misleading.

### Severity
**Medium**

### Recommendation
Change wording to:
- “The core hook patch is 4 hook call sites across 4 files; full integration also requires `WorldSession`, RBAC, and script loader changes.”

---

## 4.4 MEDIUM — `wpp_import.py --lua` writes DB version 3 while addon runtime is version 4

### Files
- `tools/wpp_import.py`
- `CreatureCodex/CreatureCodex.lua`

### Exact issue

In addon runtime:
- `CreatureCodex/CreatureCodex.lua`
  - `local VERSION = 4`

In WPP Lua writer:
- `tools/wpp_import.py`
  - `write_lua()` emits `["version"] = 3,`

This is not fatal because `InitDB()` migrates older DBs forward, but it is visibly inconsistent and will be criticized.

### Severity
**Medium**

### Recommendation
Emit version 4 and include the newer fields:
- `ignored`
- `ignoredSpells`
- `players`
- `exports`
- `spellMetadata`
- `settings`
- `dataRevision`

At minimum, set version to 4.

---

## 4.5 MEDIUM — Linux/macOS wrapper claims still overstate support

### Files
- `parse_captures.sh`
- `start_ymir.sh`
- `update_tools.sh`
- `_GUIDE/03_Retail_Sniffing.md`
- `README.md`

### Exact issue

Wrappers exist, but underlying tooling is Windows-centric:

- `session.py`
  - uses `tasklist`
  - uses `os.startfile`
  - expects `WowPacketParser.exe`
  - expects `ymir_retail.exe`

- `update_tools.py`
  - downloads Windows executables
  - creates Windows desktop shortcut via PowerShell COM

Wrappers do include notes, but docs still present Linux/macOS wrappers as if they are meaningful operational paths. In practice:
- `start_ymir.sh` cannot run Ymir natively on Linux/macOS
- `parse_captures.sh` cannot run `WowPacketParser.exe` natively without Wine/compat layer
- `update_tools.sh` downloads Windows binaries only

### Severity
**Medium**

### Recommendation
Reword docs to:
- “Shell wrappers are convenience launchers for users running the Windows tools under Wine/compatibility layers; native Linux/macOS support is not provided.”

---

## 4.6 MEDIUM — README claims “any recent master branch” without pinning API assumptions

### Files
- `_GUIDE/02_Server_Setup.md`
- `README.md`

### Exact issue
Docs say:
- “any recent `master` branch”

But shipped code assumes:
- `_registeredAddonPrefixes` exists in `WorldSession`
- `SpellInfo->SpellName` access pattern in command script
- `WorldPackets::Chat::Chat::Initialize(...)` signature
- exact `UnitScript`/`ScriptMgr` integration points

That is too broad for TrinityCore master churn.

### Severity
**Medium**

### Recommendation
Pin to:
- tested TrinityCore commit hash / date range
- or explicitly say “tested against TC master as of YYYY-MM-DD; newer snapshots may require minor API adjustments”

---

## 4.7 LOW — `Minimap.lua` drops aura count from tooltip session stats

### File
- `CreatureCodex/Minimap.lua`

### Exact issue
`CreatureCodex_GetSessionStats()` returns 3 values:
- creatures, spells, auras

But `Minimap.lua` only captures:
- `local sc, ss = CreatureCodex_GetSessionStats()`

So tooltip omits auras while browser tooltip includes them.

### Severity
**Low**

### Recommendation
Capture third return and display it for consistency.

---

## 4.8 LOW — `GenerateNewDiscoveriesSQL()` computes append index by counting DB-known spells, not actual DB slot indices

### File
- `CreatureCodex/Export.lua`

### Exact issue
It does:
```lua
local maxIdx = -1
for _, spell in pairs(creature.spells or {}) do
    if spell.dbKnown then maxIdx = maxIdx + 1 end
end
```

This assumes DB-known spells occupy contiguous indices starting at 0. That may be true often, but not guaranteed if DB rows are sparse or custom-edited.

### Severity
**Low**

### Recommendation
If you want correctness, the server should send actual `Index` values in `SL` responses, not just spell IDs.

---

# 5) Task 5 — Grep Audit of Stale Patterns

Requested stale patterns:

- `bestiary`
- `BestiaryForge`
- `1.1.0`
- `string:trim`
- `Sync Sniff`
- `AGGREGATION_DB`
- `only seen below 40`

## Result: **PASS**

I found **zero matches** for all requested stale patterns in the embedded shipped files.

### Notes
- `AGGREGATION_DB`: zero matches
- `only seen below 40`: zero matches
- version `1.1.0`: zero matches
- old names `bestiary`, `BestiaryForge`: zero matches
- `string:trim`: zero matches
- `Sync Sniff`: zero matches

---

# 6) File-by-File Notable Findings

## `CreatureCodex/CreatureCodex.lua`
### Good
- Taint-safe wrappers are present.
- Addon message handling is structured and readable.
- `AR` support added.
- `strtrim` used correctly; no `string:trim`.
- `ADDON_VERSION = "1.0.0"` matches TOC/docs.

### Problems
- `HandleSpellListMessage()` protocol semantics are weak as described above.
- `serverConfirmed` is initialized but never set true in `HandleServerSpellMessage()`. Only `dbKnown` is set from `SL`. If UI/docs imply server-confirmed distinction, it is not actually surfaced.

---

## `CreatureCodex/Export.lua`
### Good
- HP comment fixed.
- SQL uses backticks consistently.
- destructive warning is documented.

### Problems
- “New Only” index assignment is heuristic, not authoritative.
- stale export note says “regenerated” even though it is shown after regeneration; wording is slightly odd but not serious.

---

## `CreatureCodex/UI.lua`
### Good
- UI is feature-complete and coherent.
- ignored creatures/spells tab exists and works.
- version display pulls TOC metadata.

### Problems
- `serverConfirmed` is collected into `sortedSpells` but never displayed/used meaningfully.
- reset popup duplication exists:
  - `CREATURECODEX_RESET` in `CreatureCodex.lua`
  - `CREATURECODEX_RESET_CONFIRM` in `UI.lua`
  Not wrong, just redundant.

---

## `server/creature_codex_sniffer.cpp`
### Good
- Runtime blacklist integration is clean.
- Broadcast filtering by addon registration is sensible.
- comments and protocol docs are coherent.

### Potential TC scrutiny
- `creature->GetName()` is inserted raw into pipe-delimited protocol. If a creature name ever contains `|`, protocol breaks. Probably rare/nonexistent in WoW creature names, but protocol is not escaped.
- message truncation to 255 can cut fields mid-name. Since parser is positional, truncation could produce malformed `name|hp%` tail. Rare, but possible.

---

## `server/cs_creature_codex.cpp`
### Good
- command tree matches docs.
- RBAC constant usage is consistent.

### Potential compatibility issue
- `spellInfo->SpellName` access pattern is TC-version-sensitive.
- no tested commit pinned in docs.

---

## `server/lua_scripts/creature_codex_server.lua`
### Good
- docs now correctly say `characters` DB.
- `AR` ack exists.
- aggregation SQL matches shipped schema.

### Problems
- `SL` empty response ambiguity.
- `ZC` and `CI` also use raw names in pipe/colon/comma-delimited payloads without escaping. A colon/comma/pipe in names would break parsing. Again rare, but protocol is not robustly encoded.

---

## `server/install_hooks.py`
### Good
- dry-run and grouped write logic are improved.
- validation-before-write is solid.

### Blocker
- revert logic still unsafe.

---

## `tools/wpp_import.py`
### Good
- parser is reasonably structured.
- output modes are useful.
- `--addon` path aligns with addon merge flow.

### Problems
- writes DB version 3
- docs mention `--merge existing.lua sniff1.txt`; implementation only does shallow creature existence merge, not true spell merge. The help text is broader than reality.

---

## `session.py`
### Good
- Windows flow is coherent.
- backup/archive behavior is clear.

### Problems
- definitely Windows-specific despite shell wrappers.
- `WOW_ROOT = SCRIPT_DIR.parent.parent.parent` assumes script lives under `_retail_/Interface/AddOns/CreatureCodex/`; if user runs from unpacked zip elsewhere, SavedVariables backup path is nonsense. Docs imply running from addon package, so this is acceptable but brittle.

---

# 7) Ship Readiness by Audience

## For noobs
**Almost shipable** for client-only addon use.

## For TrinityCore Discord / experienced C++ devs
**Not shipable**. They will correctly attack:
- revert safety
- protocol incompleteness
- overbroad compatibility claims
- understated patch surface
- version mismatch in WPP Lua output

---

# 8) Final Decision

# **NO-SHIP**

## Remaining Blockers

### High
1. **Unsafe revert implementation**
   - File: `server/install_hooks.py`
   - Issue: over-broad deletion by substring, not exact patch reversal.

2. **Fragile/incomplete `SL` protocol handling**
   - Files:
     - `CreatureCodex/CreatureCodex.lua`
     - `server/lua_scripts/creature_codex_server.lua`
   - Issue: empty response ambiguity, no chunk completion semantics, `count` unused.

### Medium
3. **Server setup docs understate actual patch surface**
   - File: `_GUIDE/02_Server_Setup.md`

4. **`wpp_import.py --lua` emits version 3 while addon is version 4**
   - Files:
     - `tools/wpp_import.py`
     - `CreatureCodex/CreatureCodex.lua`

5. **Linux/macOS support wording still overclaims**
   - Files:
     - `start_ymir.sh`
     - `parse_captures.sh`
     - `update_tools.sh`
     - docs in README / guide

6. **“Any recent master” claim is too broad for unpinned TC APIs**
   - Files:
     - `README.md`
     - `_GUIDE/02_Server_Setup.md`

---

# 9) Recommended Minimal v8 Fix List

If you want this to survive hostile review, I’d fix these before release:

1. **Rewrite `install_hooks.py --revert`**
   - exact marker-based removal only
   - no substring heuristics

2. **Fix `SL` protocol**
   - support `SL|entry|0|`
   - use `count`
   - add chunk framing or explicit completion

3. **Correct docs**
   - `_GUIDE/02_Server_Setup.md`: clarify “4 core hook insertions” vs full integration files
   - README/platform docs: explicitly say Windows-first tooling; shell wrappers are not native support

4. **Set WPP Lua output to version 4**
   - and ideally emit current schema fields

5. **Pin tested TrinityCore baseline**
   - commit/date or at least “tested against master as of 2026-03-13”

If you want, I can do a **v8-ready patch list** next with exact replacement text and code diffs per file.
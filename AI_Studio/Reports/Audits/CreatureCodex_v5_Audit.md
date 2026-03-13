---
reviewed: CreatureCodex v1.0.0v5
reviewer: ChatGPT (gpt-5.4)
date: 2026-03-13
prompt_tokens: 72702
completion_tokens: 6255
total_tokens: 78957
---

# CreatureCodex v1.0.0v5 — Final Audit

## Executive Verdict

**NO-SHIP**

v5 does fix the specific v4/v5 documentation and watcher issues you listed, and the package is materially cleaner than prior revisions. However, there are still **ship-blocking technical inconsistencies** that a hostile TrinityCore/C++ audience will immediately hit:

1. **`install_hooks.py` is not actually atomic across multiple hooks in the same file** and can generate malformed patches in `ScriptMgr.h` / `Spell.cpp` because each hook validates against the original file content, then writes independently.  
   - This is a real regression against the claimed “fixed atomicity” standard.
2. **The Eluna aggregation SQL in the README is wrong for the shipped Lua script** (`CharDBExecute` + fully qualified DB name mismatch / likely invalid usage depending on Eluna binding and active connection semantics).
3. **The docs still overclaim portability / compatibility in a few places**, especially around shell wrappers and “core capture logic is portable”.
4. **There are fresh code-level correctness issues in the addon/UI reset paths and data revision handling** that won’t crash immediately but are the kind of thing TC Discord will call out.

So: **better, but not ready for a hostile release audience.**

---

# Scope

Audited files provided in the distribution, with emphasis on:

- v5 fix verification
- cross-reference integrity
- noob walkthrough
- TC bully walkthrough
- grep audit for stale patterns
- new issues introduced or still present

---

# 1) v5 Fix Verification

## 1.1 Hook docs unified to `server/HOOKS.md`
**Verdict: PASS**

### Evidence
- `README.md` Step 2 now explicitly points to `server/HOOKS.md` instead of inlining fragile snippets:
  - `README.md` around **“Step 2: Wire the Hooks into Spell.cpp and Unit.cpp”**
- `_GUIDE/02_Server_Setup.md`:
  - `## Option B: Manual Patching`
  - says: `See server/HOOKS.md for the exact code and file locations.`
- `README_DE.md` and `README_RU.md` also point to `server/HOOKS.md` in their Step 2 sections.

### Result
The prior inline mismatch problem (`creature` vs `caster`, `m_spellInfo` vs `GetSpellInfo()`, etc.) is removed from the main docs.

---

## 1.2 Raw export format description fixed
**Verdict: PASS**

### Evidence
Actual raw export generator:
- `CreatureCodex/Export.lua`, function `GenerateRawExport()`
  - header line: `CCEXPORT:v3`
  - per-creature line format:
    - `entry:name`
    - then `|spellId:total:school:spellName`

Docs now match:
- `README.md` → Export Formats section:
  - `entry:name|spellId:totalCount:school:spellName|...` with `CCEXPORT:v3`
- `_GUIDE/04_Understanding_Exports.md`
  - same structure
- `README_DE.md` / `README_RU.md`
  - same corrected structure

### Result
Docs now match code.

---

## 1.3 SmartAI delete warning fixed
**Verdict: PASS**

### Evidence
Actual exports:
- `CreatureCodex/Export.lua`
  - `GenerateSQL()` emits:
    - `DELETE FROM creature_template_spell WHERE CreatureID = ...;`
  - `GenerateSmartAI()` emits:
    - `DELETE FROM smart_scripts WHERE entryorguid = ... AND source_type = 0;`

Docs now warn about both:
- `README.md` → Export Formats warning block
- `_GUIDE/04_Understanding_Exports.md`
  - SQL (Spells) warning for `creature_template_spell`
  - SmartAI example and warning text mention `smart_scripts`
- DE/RU readmes also reflect destructive behavior more accurately.

### Result
Fixed.

---

## 1.4 HP% claim corrected
**Verdict: PASS**

### Evidence
Code:
- HP% is only recorded from server messages:
  - `CreatureCodex/CreatureCodex.lua`, `HandleServerSpellMessage(...)`
  - passes `hpPct` into `RecordSpell(...)`
- Visual scraper paths (`ScrapeUnitCasts`, `ScrapeUnitAuras`) do **not** provide HP%.

Docs:
- `README.md` → “How It Works” item 1:
  - explicitly says `HP% is available from server hooks only`
- `_GUIDE/02_Server_Setup.md` and `_GUIDE/04_Understanding_Exports.md` are consistent with that
- DE/RU also corrected.

### Result
Fixed.

---

## 1.5 Top copy softened from “captures every spell” to “captures visible spell casts”
**Verdict: PASS**

### Evidence
- `README.md` top section now says:
  - “the addon captures visible spell casts, channels, and auras in real time”
  - with server hooks caveat for 100% coverage
- `_GUIDE/01_Quick_Start.md`
  - “captures spell casts and auras automatically”
- `_GUIDE/02_Server_Setup.md`
  - explicitly says client addon captures `~80%`, hooks catch remaining `20%`

### Result
The overclaim is removed from the main English docs.

---

## 1.6 `.sh` wrappers now honest about Windows-specific APIs
**Verdict: PASS with caveat**

### Evidence
- `start_ymir.sh`
  - notes `session.py uses Windows-specific APIs (tasklist, os.startfile)`
- `parse_captures.sh`
  - same note
- `update_tools.sh`
  - notes Python downloads Windows executables

### Caveat
The comments are more honest, but one wrapper still overstates portability:
- `start_ymir.sh` says:
  - “The core capture logic is portable.”
- This is not really true because `session.py` hardcodes:
  - `tasklist`
  - `WowPacketParser.exe`
  - `ymir_retail.exe`
  - `os.startfile`
  - `WOW_PROCESS = "Wow.exe"`
- So the wrapper note is improved, but still not fully honest.

### Result
Count this as **fixed in spirit**, but not fully bulletproof.

---

## 1.7 `wpp_watcher.py` `tell()` bug fixed
**Verdict: PASS**

### Evidence
Current `tools/wpp_watcher.py`, function `is_wpp_file()`:
```python
with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
    head = f.read(4096)
```
No `tell()` inside text iteration anymore.

### Result
Fixed.

---

## 1.8 `_GUIDE/02_Server_Setup.md` now self-contained
**Verdict: PASS**

### Evidence
`_GUIDE/02_Server_Setup.md` now includes the `IsAddonRegistered` helper inline:
- `WorldSession.h` declaration
- `WorldSession.cpp` implementation

### Result
Fixed.

---

## 1.9 `send_audit_v3.py` Unicode crash fixed
**Verdict: NOT VERIFIABLE / FAIL AS SHIPPED**

### Evidence
That file is **not present** in the provided distribution.

### Result
You claimed:
> `send_audit_v3.py Unicode crash fixed`

But the file is not in the shipped contents, so this cannot be verified. For a final audit, that claim should not appear unless the file ships or is explicitly excluded from the release.

---

# 2) Cross-Reference Integrity Audit

## 2.1 Hook docs vs shipped C++ code
**Verdict: MOSTLY CONSISTENT**

### `server/HOOKS.md` vs `server/creature_codex_sniffer.cpp`
- Hook names match:
  - `OnCreatureSpellCast`
  - `OnCreatureSpellStart`
  - `OnCreatureChannelFinished`
  - `OnAuraApply`
- Call semantics match the sniffer expectations.

### `README.md` / `_GUIDE/02_Server_Setup.md` vs `HOOKS.md`
- All now point to `server/HOOKS.md` for exact patching.
- This is the right move.

### Remaining issue
`HOOKS.md` still contains version-sensitive assumptions:
- `src/server/game/Spells/Spell.cpp`
- `src/server/game/Entities/Unit/Unit.cpp`
- exact local variable names:
  - `m_caster`
  - `m_originalCaster`
  - `m_spellInfo`
  - `creatureCaster`

That’s acceptable for a manual patch guide **if** clearly framed as “current TC master anchors”. It mostly is, but TC devs will still note it’s branch-sensitive.

---

## 2.2 README command references vs addon code
**Verdict: MOSTLY CONSISTENT**

### Slash commands
Documented in `README.md`:
- `/cc`
- `/cc export`
- `/cc debug`
- `/cc stats`
- `/cc zone`
- `/cc submit`
- `/cc reset`

Implemented in `CreatureCodex/CreatureCodex.lua`:
- yes, all present in `SlashCmdList["CREATURECODEX"]`

### Not documented but implemented
- `/cc sync`
- `/cc aggregate` alias

This is not fatal, but docs are incomplete.

---

## 2.3 GM commands vs C++ command script
**Verdict: CONSISTENT**

Documented:
- `.codex query <entry>`
- `.codex stats`
- `.codex blacklist add <spellId>`
- `.codex blacklist remove <spellId>`
- `.codex blacklist list`

Implemented in:
- `server/cs_creature_codex.cpp`
  - `GetCommands()`

Matches.

---

## 2.4 Export docs vs export code
**Verdict: MOSTLY CONSISTENT**

### Raw
Matches.

### SQL (Spells)
Matches:
- `DELETE + INSERT`
- backticks
- `CreatureID`, `Index`, `Spell`

### SmartAI
Mostly matches, but docs overstate one inference:
- Docs say:
  - “HP-phase spells (only seen below 40% HP) get `event_type=2`”
- Actual code in `CreatureCodex/Export.lua`, `GenerateSmartAI()`:
```lua
if s.data.hpMin and s.data.hpMin < 40 then
```
This is **not** “only seen below 40% HP”; it is “minimum observed HP below 40%”.  
A spell seen at 100%, 70%, and 20% would still be emitted as HP-phase.

That’s a documentation inaccuracy.

---

## 2.5 Eluna docs vs shipped Eluna script
**Verdict: INCONSISTENT / PROBLEMATIC**

### Problem A: Aggregation DB SQL in README vs script behavior
`README.md` Step 6 says:
- create table in whichever DB you want
- default `characters`
- update `AGGREGATION_DB` if different

Shipped script:
- `server/lua_scripts/creature_codex_server.lua`
```lua
local AGGREGATION_DB = "characters"
...
CharDBExecute(string.format(
    "INSERT INTO %s.codex_aggregated ...",
    AGGREGATION_DB, ...
))
```

This is shaky for two reasons:
1. `CharDBExecute` already targets the character DB connection in typical Eluna environments.
2. Prefixing with `%s.codex_aggregated` may fail or be redundant depending on DB permissions / connection behavior.

A TC/Eluna user will absolutely question this. If you’re using `CharDBExecute`, the SQL should normally target `codex_aggregated` directly, not `characters.codex_aggregated`, unless you have tested that exact binding.

### Problem B: README says “whichever database you want”
But the script hardcodes `CharDBExecute`, not a generic DB executor selected by `AGGREGATION_DB`. So “whichever database you want” is misleading unless the DB is reachable from the character DB connection and fully qualified names are supported.

---

## 2.6 File structure references
**Verdict: CONSISTENT WITH PROVIDED FILES**

The listed files in `README.md`, `README_DE.md`, `README_RU.md` all exist in the provided distribution.

---

# 3) Fresh Adversarial Walkthroughs

## 3.1 Noob Walkthrough
**Verdict: USABLE, with some friction**

### What works
- `_GUIDE/01_Quick_Start.md` is concise and good.
- Windows batch wrappers check for Python and fail cleanly.
- Addon install instructions are clear.
- Export explanation is understandable.

### Where a noob still stumbles
1. **Retail sniffing requires too much hidden context**
   - `_GUIDE/03_Retail_Sniffing.md` says:
     - install addon
     - install Python
     - install `gh`
     - install Npcap
     - use wrappers
   - But it doesn’t explain what WowPacketParser output is supposed to look like or how to validate success beyond “opens parsed output folder”.

2. **Shell wrappers are present for Linux/macOS but not truly usable**
   - A noob on non-Windows will assume support exists because wrappers exist.

3. **`/cc sync` is operationally important but under-documented**
   - It exists in code and main README Ymir section, but not in the slash command table.

### Noob conclusion
For Windows users, client-only install is fine. Full sniff pipeline is still advanced and not truly “2 minute” beyond addon-only mode.

---

## 3.2 TC Bully Walkthrough
**Verdict: WILL GET PUNCHED**

A TrinityCore Discord regular will immediately attack these points:

1. **“Any recent master branch”**
   - `_GUIDE/02_Server_Setup.md`
   - `server/install_hooks.py` docstring
   - This is too broad for regex-based source patching.

2. **`install_hooks.py` atomicity claim is not actually true**
   - See blocker below.

3. **Eluna DB execution semantics are dubious**
   - `CharDBExecute("INSERT INTO characters.codex_aggregated ...")`
   - This is exactly the kind of thing they’ll call “untested cargo cult SQL”.

4. **SmartAI HP-phase inference is overstated**
   - Docs say “only seen below 40%”
   - Code checks only `hpMin < 40`

5. **Portability claims are still soft-pedaled**
   - `.sh` wrappers exist, but the Python underneath is Windows-bound.

6. **Reset/data revision consistency bugs**
   - Not fatal for casual users, but enough for “did you even test state transitions?”

### TC bully conclusion
They will not accept this as polished/release-grade yet.

---

# 4) New / Remaining Issues

## Blocker 1 — `install_hooks.py` is not actually atomic across hooks in the same file
**Severity: BLOCKER**

### Where
- `server/install_hooks.py`

### Exact problem
The script validates each hook independently against the original file content, stores a `new_content` per hook, then writes each hook independently later.

Relevant flow:
- `validate_hook(...)` reads file content fresh from disk and returns a modified full-file string for **that one hook only**
- `main()`:
  - Phase 1 validates all hooks and stores `(hook, new_content)`
  - Phase 2 writes each `new_content` sequentially

This breaks when **multiple hooks target the same file**, which they do:
- `src/server/game/Scripting/ScriptMgr.h` has **2 hooks**
- `src/server/game/Spells/Spell.cpp` has **3 hooks**

### Why it is wrong
Each later write is based on the original file, not the result of prior hooks in the same file. So the last write to a file can overwrite earlier inserted hooks.

### Evidence in code
- `validate_hook()`:
  - reads `content = filepath.read_text(...)`
  - computes `new_content` from that one content snapshot
- `main()`:
```python
validated = []  # list of (hook, new_content_or_None)
...
for hook in HOOKS:
    ok, new_content = validate_hook(tc_root, hook)
    if ok:
        validated.append((hook, new_content))
...
for hook, new_content in to_write:
    write_hook(tc_root, hook, new_content)
```

There is **no per-file accumulation** of edits.

### Consequence
On a clean tree:
- first `ScriptMgr.h` hook write inserts UnitScript virtuals
- second `ScriptMgr.h` hook write writes a different `new_content` generated from the original file, potentially dropping the first insertion
- same issue for `Spell.cpp`

### Why this is ship-blocking
You explicitly called out atomicity as fixed. It is not fixed robustly. This is exactly the kind of thing a TC dev will test in 30 seconds.

---

## Blocker 2 — Eluna aggregation SQL / DB targeting is not trustworthy
**Severity: BLOCKER**

### Where
- `server/lua_scripts/creature_codex_server.lua`
- `README.md` Step 6
- `README_DE.md` Step 6
- `README_RU.md` Step 6

### Exact problem
The script uses:
```lua
CharDBExecute(string.format(
    "INSERT INTO %s.codex_aggregated ...",
    AGGREGATION_DB, ...
))
```

But docs say:
- create the table in “whichever database you want”
- default `characters`

This is not a generic DB abstraction. It is still using `CharDBExecute`, i.e. the character DB executor.

### Why hostile audience will object
- If you want arbitrary DB selection, you need a matching executor or confirmed support for fully qualified names on that connection.
- If you want character DB only, then don’t pretend it’s arbitrary.
- As written, this looks untested.

### Fix direction
Either:
- lock it to character DB and remove `AGGREGATION_DB` entirely, using plain `INSERT INTO codex_aggregated ...`
- or implement/test a real DB-selection strategy and document exact Eluna requirements

---

## Major 3 — `README` SmartAI HP-phase claim is still inaccurate
**Severity: MAJOR**

### Where
- `README.md`:
  - “spells only seen below 40% HP get `event_type=2`”
- Similar wording in DE/RU and top copy

### Actual code
- `CreatureCodex/Export.lua`, `GenerateSmartAI()`:
```lua
if s.data.hpMin and s.data.hpMin < 40 then
```

### Why wrong
This does **not** mean “only seen below 40% HP”. It means “seen at least once below 40% HP”.

### Impact
This is exactly the kind of semantic overstatement that gets mocked.

---

## Major 4 — `serverConfirmed` is never set for server cast messages
**Severity: MAJOR**

### Where
- `CreatureCodex/CreatureCodex.lua`

### Exact problem
Server-originated messages are handled by:
- `HandleServerSpellMessage(...)`
- which calls `RecordSpell(...)`

But `RecordSpell(...)` never sets:
```lua
spell.serverConfirmed = true
```
for server-fed observations.

The field is initialized:
- in `RecordSpell()` new spell creation: `serverConfirmed = false`
- in WPP merge: `serverConfirmed = false`
- in spell list import: `dbKnown = true`, not `serverConfirmed`

### Consequence
The addon has a `serverConfirmed` field that never becomes true from actual server sniffer data.

### Why it matters
This is dead/lying state. A reviewer will ask why the field exists.

---

## Major 5 — Reset paths do not reset revision/state consistently
**Severity: MAJOR**

### Where
- `CreatureCodex/CreatureCodex.lua`
  - `StaticPopupDialogs["CREATURECODEX_RESET"]`
- `CreatureCodex/UI.lua`
  - `StaticPopupDialogs["CREATURECODEX_RESET_CONFIRM"]`

### Exact problems

#### A. Core reset does not bump/reset `dataRevision`
`CreatureCodex.lua` reset clears:
- `CreatureCodexDB.creatures`
- session counters
- dedup tables

But does **not**:
- reset `CreatureCodexDB.dataRevision`
- update local `dataRevision`
- clear saved exports

#### B. UI reset also does not reset revision or exports
`UI.lua` reset clears:
- creatures
- blacklists
- ignored lists

But also does not:
- clear `exports`
- clear `dataRevision`
- clear session counters
- clear dedup tables
- clear `serverSnifferActive` / `sessionServerCasts`

### Consequence
State after reset is inconsistent and stale export detection can become meaningless.

---

## Major 6 — `GenerateNewDiscoveriesSQL()` computes append index incorrectly
**Severity: MAJOR**

### Where
- `CreatureCodex/Export.lua`

### Exact code
```lua
local maxIdx = -1
for _, spell in pairs(creature.spells or {}) do
    if spell.dbKnown then maxIdx = maxIdx + 1 end
end
```

### Why this is wrong
This assumes:
- all DB-known spells are contiguous from index 0
- count(dbKnown) - 1 == max existing index

That is not guaranteed.

If DB has slots `0, 3, 7`, count is 3, computed `maxIdx` becomes 2, and new inserts start at 3, colliding with existing slot 3.

### Impact
The “New Only” export can generate bad indices.

### Fix direction
Need actual existing indices from server, not just count of dbKnown spells. Current protocol does not transmit indices, only spell IDs:
- `SL|entry|count|spellID1,spellID2,...`

So either:
- change protocol to include index
- or document that New Only appends by count heuristic and may need manual review

As shipped, docs overstate safety.

---

## Major 7 — `HandleSpellListMessage()` silently drops DB-known spells for unseen creatures
**Severity: MAJOR**

### Where
- `CreatureCodex/CreatureCodex.lua`

### Exact code
```lua
local db = CreatureCodexDB.creatures
if db[entry] then
    if not db[entry].spells[spellID] then
        ...
```

### Why this matters
If the client requests `SL|entry` before the creature exists in local DB, the response is ignored.  
Current target flow usually creates the creature first in `PLAYER_TARGET_CHANGED`, but this is still brittle and protocol-order dependent.

### Impact
Not fatal, but poor robustness.

---

## Minor 8 — `Minimap.lua` session stats unpack mismatch
**Severity: MINOR**

### Where
- `CreatureCodex/Minimap.lua`

### Exact code
```lua
local sc, ss = CreatureCodex_GetSessionStats()
```
But `CreatureCodex_GetSessionStats()` returns 3 values:
```lua
return sessionCreatures, sessionSpells, sessionAuras
```

### Impact
Aura count is silently ignored in minimap tooltip. Not harmful, but sloppy.

---

## Minor 9 — Unused locals in cast scraping
**Severity: MINOR**

### Where
- `CreatureCodex/CreatureCodex.lua`
- `ScrapeUnitCasts(unit)`

### Exact code
```lua
local castName, _, _, _, _, _, castID, _, castSpellID = UnitCastingInfo(unit)
...
local chanName, _, _, startTimeMS, _, _, _, chanSpellID = UnitChannelInfo(unit)
```
`castName` and `chanName` are unused.

### Impact
Not a bug, just polish.

---

## Minor 10 — `SCAN_UNITS` includes `partyXtarget` and `bossX`, but aura scan uses separate nameplate list
**Severity: MINOR**

### Where
- `CreatureCodex/CreatureCodex.lua`

### Note
Not wrong, but architecture is inconsistent:
- cast scan uses static `SCAN_UNITS`
- aura scan uses dynamic nameplate list + target/focus

This is fine, but docs present it as a unified scanner.

---

# 5) Grep Audit for Stale Patterns

Requested stale patterns checked against provided shipped files.

## Results

| Pattern | Result |
|---|---|
| `bestiary` | **ZERO matches** |
| `BestiaryForge` | **ZERO matches** |
| `screenshot` | **ZERO matches** |
| `1.1.0` | **ZERO matches** |
| `string:trim` | **ZERO matches** |
| `Sync Sniff` | **ZERO matches** |
| `Spell::cast()` | **ZERO matches** |
| `SendChannelUpdate` | **ZERO matches** |
| `codex_aggregated.sql` | **ZERO matches** |
| `submittedBy` | **ZERO matches** |
| `submittedAt` | **ZERO matches** |
| `SQL-файлы` | **ZERO matches** |
| `SQL-Dateien` | **ZERO matches** |

### Note
There **are** valid matches for `codex_aggregated` (without `.sql`) in current docs/script, which is expected.

---

# 6) File-by-File High-Risk Notes

## `server/install_hooks.py`
**Verdict: NOT SHIP-READY**
- Multi-hook same-file write logic is broken.
- `revert_hooks()` is also fragile and pattern-based in a way that can over-remove or under-remove.
- This is the highest-risk file in the package.

## `server/lua_scripts/creature_codex_server.lua`
**Verdict: NEEDS DOC/CODE CORRECTION**
- Aggregation DB targeting is not convincingly correct.
- `HandleZoneCreaturesRequest()` hard-limits to `LIMIT 200`; docs do not mention truncation.
- `ct.npcflag = 0` filter is undocumented and may exclude valid creatures.

## `CreatureCodex/Export.lua`
**Verdict: FUNCTIONAL BUT HAS LOGIC GAPS**
- New Only index heuristic is unsafe.
- HP-phase inference docs overstate certainty.

## `CreatureCodex/CreatureCodex.lua`
**Verdict: MOSTLY SOLID, SOME STATE SLOP**
- Core capture logic is decent.
- Reset/state consistency needs cleanup.
- `serverConfirmed` dead field should be fixed or removed.

## `README*.md`
**Verdict: MUCH IMPROVED, STILL A FEW OVERCLAIMS**
- Main hook-doc unification is good.
- Eluna aggregation section is still not release-grade precise.
- Slash command table should include `/cc sync`.

---

# 7) Ship Decision

## Final Decision: **NO-SHIP**

## Remaining Blockers

### 1. `install_hooks.py` same-file multi-hook patching is broken
- **Severity:** Blocker
- **Files:** `server/install_hooks.py`
- **Why:** Claimed atomicity fix is not actually correct; can overwrite prior hook insertions in the same file.

### 2. Eluna aggregation DB execution/docs are not trustworthy
- **Severity:** Blocker
- **Files:** `server/lua_scripts/creature_codex_server.lua`, `README.md`, `README_DE.md`, `README_RU.md`
- **Why:** `CharDBExecute` + fully qualified `%s.codex_aggregated` + “any database you want” is not a credible/tested story as written.

---

# 8) Recommended Fix List Before Ship

## Must-fix
1. **Rewrite `install_hooks.py` to patch per file, not per hook**
   - Load each file once
   - apply all relevant hook insertions to an in-memory buffer
   - validate all anchors first
   - write each file once

2. **Fix aggregation DB story**
   - Either:
     - hardcode character DB and use `INSERT INTO codex_aggregated`
   - or:
     - implement/test true DB selection and document exact Eluna requirements

## Should-fix
3. Correct HP-phase wording in all docs:
   - from “only seen below 40%”
   - to “seen below 40% at least once”

4. Fix `GenerateNewDiscoveriesSQL()` index logic or document it as heuristic.

5. Set `serverConfirmed = true` on server-fed observations, or remove the field.

6. Make reset paths consistent:
   - clear exports
   - reset/bump `dataRevision`
   - reset session/server counters consistently

7. Add `/cc sync` to slash command tables in all READMEs.

8. Remove or soften remaining portability claims in `.sh` wrappers.

---

# Bottom Line

**v5 is substantially improved and close, but not ready for a hostile technical audience.**  
The docs are much cleaner, the stale naming is gone, and most of the v5 fixes are real. But the remaining issues are exactly the kind of things TrinityCore veterans will seize on:

- broken patcher semantics
- shaky Eluna DB assumptions
- a few still-overstated claims
- some sloppy state handling

## Final: **NO-SHIP**
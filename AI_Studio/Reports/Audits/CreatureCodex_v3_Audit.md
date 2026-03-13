---
reviewed: CreatureCodex v1.0.0v3
reviewer: ChatGPT (gpt-5.4)
date: 2026-03-13
prompt_tokens: 72588
completion_tokens: 6264
total_tokens: 78852
---

# CreatureCodex v1.0.0v4 — Final Audit

## Executive Verdict

**NO-SHIP**

v4 does fix the previously identified `install_hooks.py` atomicity blocker. However, the distribution is **not ready to ship to a hostile TrinityCore audience** because there are still **multiple concrete technical/documentation inconsistencies**, including **one serious code/doc mismatch in the hook patcher/manual instructions** and **several fresh regressions / stale references** that will get called out immediately.

The package is close, but it is **not yet clean enough** for TrinityCore Discord scrutiny.

---

# 1) Verification of v4 Claims

## 1.1 `install_hooks.py` is now truly atomic
**Verdict: FIX CONFIRMED**

### Evidence
In `server/install_hooks.py`:

- Validation phase is explicit:
  - `main()` Phase 1 starts at **`server/install_hooks.py:299`**
  - It validates all hooks first and stores results in `validated`
- On any failure, it exits **before writing**:
  - **`server/install_hooks.py:307-311`**
- Actual writes happen only in Phase 2:
  - **`server/install_hooks.py:322-325`**

Relevant lines:
- `server/install_hooks.py:299` — `print("Phase 1: Validating anchors...")`
- `server/install_hooks.py:307-311` — failure path says:  
  `ERROR: {failed} hook(s) failed validation. No files were modified.`
- `server/install_hooks.py:322-325` — writes only after all validation passes

This addresses the v3 blocker correctly.

---

## 1.2 `creature_codex_sniffer.cpp` stale comment changed from `Spell::cast` to `Spell::prepare`
**Verdict: FIX CONFIRMED**

### Evidence
- `server/creature_codex_sniffer.cpp:123`  
  `// Fires at the start of casting (beginning of Spell::prepare)`

No stale `Spell::cast` comment remains in the embedded file.

---

## 1.3 `_What_To_Do_With_These_Files.txt` false SQL/data-folder claim removed
**Verdict: FIX CONFIRMED**

### Evidence
`CreatureCodex/tools/parsed/_What_To_Do_With_These_Files.txt:14-15` now says:

- `To generate creature_template_spell SQL, use the addon's in-game export`
- `(/cc export) or run tools/wpp_import.py --sql on your WPP output.`

No false claim about SQL already being in `data/`.

---

## 1.4 Eluna script header now documents all 4 handlers
**Verdict: FIX CONFIRMED**

### Evidence
`server/lua_scripts/creature_codex_server.lua:5-8` documents:

- `SL|entry`
- `CI|entry`
- `ZC|mapId`
- `AG|entry|spellData`

That matches the implementation dispatch at:
- `server/lua_scripts/creature_codex_server.lua:180-188`

---

## 1.5 DE/RU file structure sections now include `.sh` wrappers
**Verdict: FIX CONFIRMED**

### Evidence

### German
`README_DE.md:363-365`
- `start_ymir.sh`
- `update_tools.sh`
- `parse_captures.sh`

### Russian
`README_RU.md:363-365`
- `start_ymir.sh`
- `update_tools.sh`
- `parse_captures.sh`

---

# 2) Cross-Reference Integrity Audit

## 2.1 Major mismatch: README/guide hook snippets do **not** match `install_hooks.py` / `HOOKS.md`
**Verdict: FAIL — serious**

This is the biggest remaining issue.

### Problem
Your docs present one set of patch snippets, but the actual auto-patcher and manual hook reference target a **different local variable name / call site shape** in `Spell.cpp`.

### README says
In `README.md`:

- `README.md:122-124`
  ```cpp
  if (Creature* creature = m_caster->ToCreature())
      sScriptMgr->OnCreatureSpellStart(creature, m_spellInfo);
  ```

- `README.md:127-129`
  ```cpp
  if (Creature* creature = m_caster->ToCreature())
      sScriptMgr->OnCreatureChannelFinished(creature, m_spellInfo);
  ```

- `README.md:117-119`
  ```cpp
  if (Creature* creature = m_caster->ToCreature())
      sScriptMgr->OnCreatureSpellCast(creature, m_spellInfo);
  ```

### But `HOOKS.md` says
In `server/HOOKS.md`:

- `server/HOOKS.md:49-54`
  ```cpp
  if (Creature* caster = m_caster->ToCreature())
  {
      if (caster->IsAIEnabled())
          caster->AI()->OnSpellStart(GetSpellInfo());
      sScriptMgr->OnCreatureSpellStart(caster, GetSpellInfo());  // <-- ADD THIS
  }
  ```

- `server/HOOKS.md:58-63`
  ```cpp
  if (Creature* caster = m_originalCaster->ToCreature())
  {
      if (caster->IsAIEnabled())
          caster->AI()->OnSpellCast(GetSpellInfo());
      sScriptMgr->OnCreatureSpellCast(caster, GetSpellInfo());  // <-- ADD THIS
  }
  ```

- `server/HOOKS.md:67-72`
  ```cpp
  if (Creature* creatureCaster = m_caster->ToCreature())
  {
      if (creatureCaster->IsAIEnabled())
          creatureCaster->AI()->OnChannelFinished(m_spellInfo);
      sScriptMgr->OnCreatureChannelFinished(creatureCaster, m_spellInfo);  // <-- ADD THIS
  }
  ```

### And `install_hooks.py` actually patches based on those AI-call anchors
- `server/install_hooks.py:72-79` — start hook anchor expects `caster->AI()->OnSpellStart(GetSpellInfo());`
- `server/install_hooks.py:82-89` — cast hook anchor expects `caster->AI()->OnSpellCast(GetSpellInfo());`
- `server/install_hooks.py:92-99` — channel hook anchor expects `creatureCaster->AI()->OnChannelFinished(m_spellInfo);`

### Why this matters
A TC dev will immediately notice:
- README’s “add this one-liner” is **not the same patch location shape** your installer depends on.
- README uses `m_caster` for cast-complete, while `HOOKS.md`/installer use `m_originalCaster`.
- README uses `m_spellInfo`; `HOOKS.md` uses `GetSpellInfo()` in two places.
- README implies generic insertion “at end of function” / “after AI call”, but the patcher is much more specific.

This is not just stylistic. It undermines trust in whether the docs were tested against real TC source.

**Severity: High**

---

## 2.2 `_GUIDE/02_Server_Setup.md` references root README for helper instead of local authoritative doc
**Verdict: MINOR FAIL**

`_GUIDE/02_Server_Setup.md:35` says:
> See the root README "Step 3: Add IsAddonRegistered Helper"...

This is not wrong, but it’s brittle and indirect. Since `server/HOOKS.md` exists and this guide is specifically server setup, the guide should be self-contained or point to `server/HOOKS.md`.

Not a blocker by itself, but it reads like documentation drift.

---

## 2.3 Quick Start says “Export Data” button; UI button text matches
**Verdict: PASS**

- `_GUIDE/01_Quick_Start.md:18`
- `CreatureCodex/UI.lua:617` — button label `"Export Data"`

Consistent.

---

## 2.4 Status bar labels in docs match UI implementation
**Verdict: PASS**

Guide:
- `_GUIDE/01_Quick_Start.md:25-27`

UI:
- `CreatureCodex/UI.lua:153` — `CreatureCodex: Active`
- `CreatureCodex/UI.lua:156` — `CreatureCodex: Scanning`
- `CreatureCodex/UI.lua:159` — `CreatureCodex: Ready`

Consistent.

---

## 2.5 Protocol docs vs addon/server implementation
**Verdict: MOSTLY PASS**

### README protocol table
`README.md:332-341`

### Addon parser
`CreatureCodex/CreatureCodex.lua:462-485`

### Eluna server handlers
`server/lua_scripts/creature_codex_server.lua:180-188`

### C++ sniffer broadcast types
`server/creature_codex_sniffer.cpp:18-21`, `120-138`

These align for:
- `SC`, `SS`, `CF`, `AA`
- `SL`, `CI`, `ZC`, `AG`

One caveat:
- Addon also handles `AR` ack at `CreatureCodex/CreatureCodex.lua:481-484`
- README protocol table does **not** document `AR`

Not fatal, but incomplete.

---

## 2.6 Export docs vs actual raw export format
**Verdict: FAIL**

### Docs claim
`README.md:309-312` says:
1. **Raw** — Plain text: `CreatureName (entry) - SpellName [spellId] x castCount`

### Actual code
`CreatureCodex/Export.lua:14` starts with `CCEXPORT:v3`
`CreatureCodex/Export.lua:38` emits:
```lua
entry:name|spellId:total:school:name|...
```

And `_GUIDE/04_Understanding_Exports.md:8-13` correctly documents:
```text
CreatureEntry:CreatureName|SpellID:TotalCount:SchoolMask:SpellName|...
```

So the root README is stale/wrong.

**Severity: Medium**

A bully reviewer will catch this instantly.

---

## 2.7 README warning says SmartAI export deletes by `CreatureID`
**Verdict: FAIL**

### README says
`README.md:313-314`
> The SQL and SmartAI exports use `DELETE FROM ... WHERE CreatureID = <entry>`

### Actual SmartAI export
`CreatureCodex/Export.lua:116`
```lua
DELETE FROM `smart_scripts` WHERE `entryorguid` = ... AND `source_type` = 0;
```

`_GUIDE/04_Understanding_Exports.md:28-31` documents SmartAI correctly.

So root README is inaccurate.

**Severity: Medium**

---

## 2.8 README says visual scraper records health %
**Verdict: FAIL**

### README says
`README.md:58-61`
> Records spell name, school, creature entry, health %, and timestamps

### Actual client visual scraper
`CreatureCodex/CreatureCodex.lua:529`, `548` call:
```lua
RecordSpell(entry, safeID, nil, name, "cast", key)
RecordSpell(entry, safeID, nil, name, "channel", key)
```
No `hpPct`.

Aura scraper:
- `CreatureCodex/CreatureCodex.lua:592`, `602`
No `hpPct`.

Only server messages pass HP%:
- `CreatureCodex/CreatureCodex.lua:359`
  `RecordSpell(..., nil, hpPct)`

So the README overstates client-only capture capability.

**Severity: Medium**

---

## 2.9 README says “background companion automatically feeds WPP data into the addon”
**Verdict: PARTIAL FAIL / misleading**

There are **two** WPP workflows in the package:

1. Manual import:
   - `tools/wpp_import.py --addon`
2. Background watcher:
   - `tools/wpp_watcher.py`

But the main README’s Ymir section leans heavily on the watcher flow:
- `README.md:241-258`

Whereas `_GUIDE/03_Retail_Sniffing.md` is centered on:
- `Update Tools.bat`
- `Start Ymir.bat`
- `Parse Captures.bat`

Those are not contradictory, but they are **different primary workflows**. The package lacks a single canonical story. A new user will ask:
- Do I use `session.py` pipeline?
- Or `wpp_watcher.py`?
- Or `wpp_import.py --addon`?

This is a product coherence issue more than a code bug.

**Severity: Medium**

---

# 3) Fresh Adversarial Walkthroughs

## 3.1 Persona: Noob
**Verdict: Not smooth enough**

### What works
- `_GUIDE/01_Quick_Start.md` is concise and usable.
- Batch wrappers check for Python and print actionable messages:
  - `CreatureCodex/Start Ymir.bat:5-13`
  - `CreatureCodex/Update Tools.bat:5-13`
  - `CreatureCodex/Parse Captures.bat:5-13`

### Where the noob gets confused
#### A) “No Python” user hits a hard wall immediately
Retail sniffing guide requires Python, gh, Npcap, curl:
- `_GUIDE/03_Retail_Sniffing.md:7-11`

That’s fine, but the package markets itself broadly. For a ChromieCraft repack/no-Python user, the sniffing/tooling side is not beginner-friendly.

#### B) Linux/macOS wrappers are misleading
You ship:
- `CreatureCodex/start_ymir.sh`
- `CreatureCodex/parse_captures.sh`
- `CreatureCodex/update_tools.sh`

But the underlying Python scripts are **Windows-specific** in important places:

- `CreatureCodex/session.py:35-40` uses `tasklist`
- `CreatureCodex/session.py:232-233` uses `os.startfile`
- `CreatureCodex/update_tools.py:248-274` creates Windows `.lnk` via PowerShell
- `CreatureCodex/update_tools.py` downloads Windows artifacts/exes:
  - WPP exe at `:35`
  - Ymir retail zip/exe assumptions throughout

So the `.sh` wrappers suggest cross-platform support that the actual tools do not provide.

This is exactly the kind of thing a hostile audience will call “cargo-cult portability”.

**Severity: High (documentation honesty issue)**

#### C) Addon-only install is okay, but README overpromises “every spell cast”
Root README opening says:
- `README.md:14`
  > the addon captures every spell cast, channel, and aura in real time

That is false for client-only mode; later sections admit ~80% / visible-only. A noob will not parse the nuance.

**Severity: Medium**

---

## 3.2 Persona: TC Bully
**Verdict: They will find multiple targets**

### Likely attack points
1. **Hook docs mismatch**  
   README vs `HOOKS.md` vs `install_hooks.py` are not aligned. This is the biggest credibility hit.

2. **Cross-platform wrappers are fake portability**  
   Shipping `.sh` wrappers around Windows-only logic is low-hanging fruit.

3. **README raw export format is wrong**  
   Easy grep/read catch.

4. **README SmartAI delete warning is technically wrong**  
   Another easy catch.

5. **`install_hooks.py --revert` is not trustworthy enough**
   More below.

---

# 4) New Issues Introduced / Remaining

## 4.1 `install_hooks.py --revert` is unsafe / overbroad
**Verdict: FAIL**

The install path is now atomic, but the revert path is still brittle.

### Evidence
`server/install_hooks.py:191-238`

The revert logic removes lines based on substring matches like:
- `"OnCreatureSpellCast"`
- `"OnCreatureSpellStart"`
- `"OnCreatureChannelFinished"`
- `"sScriptMgr->OnAuraApply"`

This can remove:
- declarations
- definitions
- call sites

without structural parsing, and with broad heuristics.

Example:
- `server/install_hooks.py:213-216`
  ```python
  if any(m in line for m in ["OnCreatureSpellCast", "OnCreatureSpellStart",
                              "OnCreatureChannelFinished",
                              "sScriptMgr->OnAuraApply"]):
  ```
This is not scoped to CreatureCodex-added blocks only.

Also:
- `server/install_hooks.py:228-231` separately strips any line containing `OnAuraApply` if it also contains broad tokens like `"virtual"` / `"void On"` / `"void ScriptMgr::"`.

A TC dev will absolutely question whether `--revert` can damage pre-existing custom hooks with the same names or nearby code.

**Severity: High**

Not necessarily a ship blocker for all audiences, but for TrinityCore Discord, yes: this will be criticized.

---

## 4.2 `check_already_installed()` is too coarse
**Verdict: FAIL**

### Evidence
`server/install_hooks.py:117-121`
```python
return "OnCreatureSpellCast" in content
```

If a user has:
- partially installed hooks,
- custom hooks with same name,
- docs/examples pasted manually only in one file,

the script will claim:
> CreatureCodex hooks are already installed!

That is not robust.

**Severity: Medium**

---

## 4.3 `HandleSpellListMessage()` ignores multi-part `SL` responses after first chunk
**Verdict: FAIL — real functional bug**

### Evidence
Eluna server can split spell list across multiple messages:
- `server/lua_scripts/creature_codex_server.lua:63-83`

Each chunk uses the same header:
```lua
SL|entry|count|spellID1,spellID2,...
```

Addon handler:
- `CreatureCodex/CreatureCodex.lua:373-404`

It parses each message independently and marks spells as `dbKnown`, which is okay.

**But** it only populates if `db[entry]` already exists:
- `CreatureCodex/CreatureCodex.lua:384`
```lua
if db[entry] then
```

If the creature entry exists, all chunks are processed. Fine.

The real issue is subtler: there is **no completion tracking**, so `count` is unused except debug print:
- `CreatureCodex/CreatureCodex.lua:402`

This means:
- UI cannot know whether DB spell list is complete
- partial delivery / truncation / dropped addon messages silently produce incomplete `dbKnown` state

Given you explicitly support chunking, not using `count` is weak design.

**Severity: Medium**

Not a hard blocker, but it’s a protocol integrity gap.

---

## 4.4 Zone completeness can print misleading partial results on multi-message `ZC`
**Verdict: FAIL**

### Evidence
Server splits `ZC` across multiple messages:
- `server/lua_scripts/creature_codex_server.lua:126-141`

Addon handler:
- `CreatureCodex/CreatureCodex.lua:425-447`

It appends chunk data into `zoneCreatureData[mapId]`, **but prints “Zone scan complete” on every received chunk**:
- `CreatureCodex/CreatureCodex.lua:435-442`

There is no chunk completion tracking against `totalCount`.

So for multi-message zones, the addon will print multiple “complete” summaries with partial totals.

This is a real user-visible bug.

**Severity: Medium**

---

## 4.5 `README.md` file structure lists server files not present in embedded distribution manifest
**Verdict: FAIL / packaging uncertainty**

README file structure includes:
- `server/creature_codex_sniffer.cpp`
- `server/cs_creature_codex.cpp`
- `server/install_hooks.py`
- `server/HOOKS.md`
- `server/lua_scripts/creature_codex_server.lua`

Those are embedded, so okay.

But the user said “34 files total. Every non-library file is embedded below.”  
The embedded set does **not** include any actual release archive manifest or top-level `server/` folder listing beyond docs. That’s acceptable for audit input, but from a ship-readiness standpoint there is still no explicit packaging proof that the release zip structure matches the README structure.

Minor, but worth noting.

---

## 4.6 `wpp_watcher.py` can crash due to `tell()` inside text iteration
**Verdict: FAIL**

### Evidence
`CreatureCodex/tools/wpp_watcher.py:65-71`
```python
with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
    for line in f:
        if 'SMSG_' in line or 'CMSG_' in line or 'ServerToClient:' in line:
            return True
        if f.tell() > 4096:
            break
```

In Python text I/O, mixing file iteration with `tell()` is not reliably safe; it can raise:
- `OSError: telling position disabled by next() call`

This is a known gotcha.

**Severity: Medium**

A technical audience will catch it if they run or review it.

---

## 4.7 `session.py` `.sh` wrappers imply Linux/macOS support, but script is Windows-only
**Verdict: FAIL**

### Evidence
Wrappers:
- `CreatureCodex/start_ymir.sh`
- `CreatureCodex/parse_captures.sh`
- `CreatureCodex/update_tools.sh`

But `session.py` uses:
- `tasklist` at `CreatureCodex/session.py:35-40`
- `Wow.exe` / `ymir_retail.exe` constants at `:28-29`
- `os.startfile` at `:232-233`

This is not cross-platform. Shipping `.sh` wrappers is misleading.

**Severity: High**

---

## 4.8 `update_tools.py` also not cross-platform despite `.sh` wrapper
**Verdict: FAIL**

### Evidence
- Downloads Windows WPP artifact and `.exe` assumptions:
  - `CreatureCodex/update_tools.py:31-35`
- Creates Windows desktop shortcut via PowerShell:
  - `CreatureCodex/update_tools.py:248-274`

Again, `.sh` wrapper implies support that does not exist.

**Severity: High**

---

## 4.9 Root README still overstates addon-only capability
**Verdict: FAIL**

Examples:
- `README.md:14` — “captures every spell cast, channel, and aura in real time”
- `README.md:20` — “works everywhere” in pipeline context
- `README.md:47-48` later correctly says client scraper is partial

This inconsistency will be attacked as marketing overclaim.

**Severity: Medium**

---

# 5) Grep Audit for Stale Patterns

Requested stale patterns checked against embedded shipped files.

## Confirmed zero matches
**PASS**
- `bestiary`
- `BestiaryForge`
- `screenshot`
- `1.1.0`
- `string:trim`
- `Sync Sniff`
- `Spell::cast()`
- `SendChannelUpdate`
- `codex_aggregated.sql`
- `submittedBy`
- `submittedAt`
- `SQL-файлы`
- `SQL-Dateien`

## Still present / notable
### `codex_aggregated`
This string **does** still appear, but only as the actual table name, not the stale removed file reference:
- `README.md:214`
- `README_DE.md:214`
- `README_RU.md:214`
- `server/lua_scripts/creature_codex_server.lua:151`

That is fine.

---

# 6) File-by-File Technical Notes

## 6.1 `CreatureCodex/CreatureCodex.lua`
**Verdict: Generally solid, with some protocol/state gaps**

### Good
- Taint-safe wrappers are consistently used:
  - `IsSecret`, `SafeNumber`, `SafeString`
- WPP merge logic is sane:
  - `MergeWPPData()` at `:101-177`
- Dedup eviction exists:
  - `EvictStaleDedups()` at `:623-630`

### Issues
- `HandleZoneCreaturesMessage()` prints completion on every chunk:
  - `:425-447`
- `HandleSpellListMessage()` ignores `count` for completeness:
  - `:373-404`
- `CreatureCodex_GetSessionStats()` returns 3 values:
  - `:665`
  but `Minimap.lua` only reads two:
  - `CreatureCodex/Minimap.lua:22`
  Not harmful, just inconsistent.

---

## 6.2 `CreatureCodex/Export.lua`
**Verdict: Code okay; docs around it are stale**

### Good
- SQL export uses backticks and deterministic sorting
- SmartAI export logic is coherent
- New-only export is useful

### Issue
- Raw export header is `CCEXPORT:v3`
  - `CreatureCodex/Export.lua:14`

That may be intentional format versioning, but it looks odd in a v1.0.0/v4 release. Not wrong, but a reviewer may ask why export format version is `v3`. If intentional, document it.

---

## 6.3 `server/creature_codex_sniffer.cpp`
**Verdict: Mostly good**

### Good
- Runtime blacklist protected by mutex
- Broadcast gated on `IsAddonRegistered`
- Message size truncated to 255

### Concern
- Message payload includes raw `creature->GetName()`:
  - `server/creature_codex_sniffer.cpp:91-95`

If creature names ever contain `|`, protocol breaks. In practice TC creature names usually won’t, but protocol should sanitize delimiters.

**Severity: Low**

---

## 6.4 `server/lua_scripts/creature_codex_server.lua`
**Verdict: Functional, but chunk protocol incomplete on client side**

### Good
- Handles all four request types
- Splits long messages safely

### Issues
- `ZC` and `SL` chunking lack sequence/completion metadata, making client-side completeness impossible.
- `AGGREGATION_DB = "characters"` plus `CharDBExecute("INSERT INTO %s.codex_aggregated ...")`
  - `server/lua_scripts/creature_codex_server.lua:20`, `154-159`

This assumes cross-database qualification is valid in the target environment. Usually okay for MySQL/MariaDB, but worth documenting more explicitly.

---

# 7) Remaining Blockers / Severity

## Blocker 1 — Hook installation docs are inconsistent with actual patcher/manual reference
**Severity: High**
- `README.md:117-129`
- `server/HOOKS.md:49-72`
- `server/install_hooks.py:72-99`

This is the most damaging credibility issue.

## Blocker 2 — `.sh` wrappers imply cross-platform support for Windows-only tooling
**Severity: High**
- `CreatureCodex/start_ymir.sh`
- `CreatureCodex/parse_captures.sh`
- `CreatureCodex/update_tools.sh`
- underlying scripts: `session.py`, `update_tools.py`

This will get mocked immediately.

## Blocker 3 — `install_hooks.py --revert` is unsafe/overbroad
**Severity: High**
- `server/install_hooks.py:191-238`

For a source patcher, revert quality matters.

---

# 8) Recommended Fixes Before Ship

## Must-fix
1. **Unify hook docs**
   - Make `README.md`, `_GUIDE/02_Server_Setup.md`, and `server/HOOKS.md` describe the **same exact call sites and variable names** as `install_hooks.py`.
   - Best option: make README point to `HOOKS.md` and stop duplicating code snippets.

2. **Stop implying Linux/macOS support for Windows-only tools**
   - Either:
     - remove `.sh` wrappers, or
     - make wrappers print “Windows-only tooling; wrapper provided for parse/import-only Python tasks”, or
     - actually implement platform checks and degrade gracefully.
   - Also update DE/RU/EN docs accordingly.

3. **Fix `install_hooks.py --revert`**
   - Revert should remove only exact inserted blocks, ideally by explicit begin/end markers.
   - Current substring-based deletion is too risky.

## Should-fix
4. Fix root README raw export format description.
5. Fix root README SmartAI delete warning wording.
6. Fix root README claim that visual scraper records HP%.
7. Add chunk completion handling for `ZC` and ideally `SL`.
8. Fix `wpp_watcher.py` `tell()` usage.

---

# 9) Final Ship Decision

## Decision: **NO-SHIP**

### Why
The package is **much improved** and the prior atomicity blocker is genuinely fixed, but it still contains enough **technical inconsistency and misleading platform/documentation claims** that an experienced TrinityCore audience will tear it apart.

### Short version
- **Atomic patching:** fixed
- **Core addon/server code:** mostly decent
- **Docs/package coherence:** still not ship-clean
- **Hostile audience readiness:** not yet

If you want, I can do one more pass as a **release-candidate punch list**, with exact replacement text/snippets for the failing README and hook docs so you can get to a likely **YES-SHIP** in one revision.
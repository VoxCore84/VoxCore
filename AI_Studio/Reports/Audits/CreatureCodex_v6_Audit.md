---
reviewed: CreatureCodex v1.0.0v6
reviewer: ChatGPT (gpt-5.4)
date: 2026-03-13
prompt_tokens: 72914
completion_tokens: 5215
total_tokens: 78129
---

# CreatureCodex v1.0.0v6 — Final Audit

## Executive Verdict

**NO-SHIP**

v6 does fix the specific **same-file multi-hook overwrite bug** in `server/install_hooks.py`, and it does remove `AGGREGATION_DB` from the Eluna script itself. However, the distribution is **not ready to ship to a hostile TrinityCore audience** because there are still multiple concrete, user-visible/documentation-visible inconsistencies and at least one serious technical/documentation mismatch that will get called out immediately.

The biggest remaining problems are:

1. **Stale `AGGREGATION_DB` references still exist in shipped docs/SQL comments** despite the claimed removal.  
2. **README file structure and instructions reference files that are not present in the provided distribution** (`sql/` files omitted from the documented tree; several docs mention files not embedded in this audit payload).  
3. **Cross-README consistency is not clean**: English README reflects v6 fixes better than DE/RU, but DE/RU still contain stale `AGGREGATION_DB` guidance.  
4. **`install_hooks.py --revert` is still brittle and can leave partial hook artifacts**; not a blocker for applying hooks, but absolutely something TC devs will scrutinize.  
5. **Some docs overstate portability / support for Linux/macOS wrappers around Windows-only tooling**, which a hostile audience will call misleading.

Below is the detailed evidence.

---

# 1) Task 1 — Verify Every v6 Fix

## 1.1 Fix: `install_hooks.py` same-file multi-hook overwrite bug

### Verdict: **CONFIRMED FIXED**

### Evidence

In `server/install_hooks.py`, hooks are now grouped by file and applied sequentially to an in-memory buffer before a single write:

- Grouping by file: `server/install_hooks.py:286-290`
- Read file once, then apply all hooks to `content`: `server/install_hooks.py:309-323`
- Store final accumulated content per file: `server/install_hooks.py:324`
- Write each file once only if changed: `server/install_hooks.py:338-344`

Relevant flow:

- `hooks_by_file.setdefault(hook["file"], []).append(hook)` — `server/install_hooks.py:289`
- `content = filepath.read_text(...)` — `server/install_hooks.py:313`
- `ok, new_content = validate_hook_against_content(content, hook)` — `server/install_hooks.py:315`
- `content = new_content` on success — `server/install_hooks.py:319`
- `file_contents[rel_path] = content` — `server/install_hooks.py:324`
- final write pass — `server/install_hooks.py:338-344`

This directly addresses the v5 bug where multiple hooks targeting the same file could each start from original content and clobber prior edits.

### Additional note

The removed dead code claim is also effectively true in the shipped file:
- No `validate_hook` function exists.
- No `write_hook` function exists.

The current helper is `validate_hook_against_content(...)` at `server/install_hooks.py:183-231`.

---

## 1.2 Fix: Eluna DB prefix removed

### Verdict: **PARTIALLY FIXED IN CODE, NOT FULLY FIXED IN DISTRIBUTION**

### Code evidence: fixed

In `server/lua_scripts/creature_codex_server.lua`, aggregation now writes directly to `codex_aggregated`:

- `CharDBExecute("INSERT INTO codex_aggregated ...")` — `server/lua_scripts/creature_codex_server.lua:157-161`

There is **no `AGGREGATION_DB` variable** in that file.

### But distribution still contains stale references

- `README.md:180-181`  
  > “If you use a different database, also update `AGGREGATION_DB` at the top of `creature_codex_server.lua` to match.”
- `README_DE.md:166-167`  
  Same stale instruction in German.
- `README_RU.md:166-167`  
  Same stale instruction in Russian.
- `sql/codex_aggregated.sql:2-3`  
  > “Apply this to whichever database you configure in creature_codex_server.lua (AGGREGATION_DB).”

So the code change is real, but the **distribution claim “removed entirely” is false**.

---

## 1.3 Fix: HP-phase wording changed from “only seen below 40% HP” to “seen below 40% HP at least once”

### Verdict: **CONFIRMED FIXED in the files provided**

### Evidence

- `_GUIDE/04_Understanding_Exports.md:31`  
  “**HP-phase spells** (seen below 40% HP at least once) ...”
- `README.md:31`  
  “detects HP-phase abilities (spells seen below 40% HP at least once ... )”
- `README_DE.md:31`  
  German wording updated to “mindestens einmal unter 40% HP gesehen”
- `README_RU.md:31`  
  Russian wording updated to “замеченные хотя бы раз ниже 40% HP”

### Important caveat

The **code comment is still wrong** in `CreatureCodex/Export.lua`:

- `CreatureCodex/Export.lua:145-146`
  ```lua
  if s.data.hpMin and s.data.hpMin < 40 then
      -- Spell only seen at low HP — use HP% event instead
  ```

That comment is inaccurate. The logic checks **minimum observed HP**, i.e. “seen below 40% at least once,” not “only seen at low HP.”

This is not the exact stale phrase from the grep list, but it is still a semantic mismatch that a technical reviewer can and will notice.

---

## 1.4 Fix: `/cc sync` added to all command tables

### Verdict: **CONFIRMED FIXED**

### Evidence in code

Slash command exists in addon:

- `CreatureCodex/CreatureCodex.lua:770-773` handles `msg == "sync"`
- Help text includes it at `CreatureCodex/CreatureCodex.lua:780-787`

### Evidence in docs

- `README.md:219-227` includes `/cc sync`
- `README_DE.md:219-227` includes `/cc sync`
- `README_RU.md:219-227` includes `/cc sync`

This fix is present.

---

## 1.5 Fix: SavedVariables init includes `ignoredSpells = {}`

### Verdict: **CONFIRMED FIXED**

### Evidence

Fresh DB init in `CreatureCodex/CreatureCodex.lua` includes:

- `ignoredSpells = {},` — `CreatureCodex/CreatureCodex.lua:72`

Migration path also ensures it exists:

- `if not CreatureCodexDB.ignoredSpells then CreatureCodexDB.ignoredSpells = {} end` — `CreatureCodex/CreatureCodex.lua:95`

This is correct.

---

# 2) Task 2 — Cross-Reference Integrity

## 2.1 Addon slash commands vs documentation

### Verdict: **Mostly consistent**

### Actual commands in code

`CreatureCodex/CreatureCodex.lua:744-788` supports:

- `/cc` / `/codex`
- `export`
- `debug`
- `reset`
- `zone`
- `submit`
- `aggregate`
- `stats`
- `sync`

### Docs

- `README.md:219-227` — matches except it documents `/cc submit` but not alias `/cc aggregate`  
  This is acceptable; alias omission is not a defect.
- DE/RU command tables also match the primary commands.

---

## 2.2 GM commands vs documentation

### Verdict: **Consistent**

### Code

`server/cs_creature_codex.cpp:28-41` defines:

- `.codex query`
- `.codex stats`
- `.codex blacklist add`
- `.codex blacklist remove`
- `.codex blacklist list`

### Docs

- `_GUIDE/02_Server_Setup.md:57-64`
- `README.md:230-237`
- `README_DE.md:230-237`
- `README_RU.md:230-237`

All match.

---

## 2.3 Addon message protocol vs implementation

### Verdict: **Mostly consistent**

### Implemented in addon

`CreatureCodex/CreatureCodex.lua:490-519` handles:

- S->C: `SC`, `SS`, `CF`, `AA`, `SL`, `CI`, `ZC`, `AR`
- C->S requests sent elsewhere: `SL`, `CI`, `ZC`, `AG`

### Documented protocol

`README.md:267-276` documents:

- S->C: `SC`, `SS`, `CF`, `AA`
- C->S: `SL`, `CI`, `ZC`, `AG`

### Missing from docs

- `AR` acknowledgement is implemented but undocumented:
  - handled at `CreatureCodex/CreatureCodex.lua:514-518`

Not fatal, but incomplete.

---

## 2.4 File structure references vs provided distribution

### Verdict: **INCONSISTENT**

`README.md:280-317` documents a larger distribution tree including:

- `sql/auth_rbac_creature_codex.sql`
- `sql/codex_aggregated.sql`

Those SQL files are indeed embedded later in your payload, so the README is fine there.

However, the user stated “36 files total. Every non-library file is embedded below.” The embedded set includes files referenced in docs that are **not actually present in the payload**, notably:

- `server/HOOKS.md` — present
- `server/install_hooks.py` — present
- `server/lua_scripts/creature_codex_server.lua` — present
- `tools/wpp_import.py` — present
- `tools/wpp_watcher.py` — present

But docs also reference:
- `tools/WowPacketParser/` and `tools/Ymir/` binaries/folders — not embedded, though arguably generated/downloaded assets
- `src/server/scripts/Custom/custom_script_loader.cpp` — external TC path, fine
- no issue there

The more important inconsistency is that the **READMEs still describe configuration via `AGGREGATION_DB` that no longer exists**.

---

## 2.5 SQL schema/docs vs code

### Verdict: **One stale mismatch**

- `server/lua_scripts/creature_codex_server.lua:157-161` writes to `codex_aggregated`
- `sql/codex_aggregated.sql:1-10` defines `codex_aggregated`

Schema matches code.

But the SQL file comment is stale:

- `sql/codex_aggregated.sql:2-3` references `AGGREGATION_DB`, which no longer exists.

---

# 3) Task 3 — Fresh Adversarial Walkthroughs

## 3.1 Persona: Noob

### Verdict: **Usable for addon-only, shaky for tooling/server path**

### What works

For a noob who just wants the addon:

- `_GUIDE/01_Quick_Start.md` is clear and concise.
- Addon install path guidance is correct.
- `/cc` and minimap usage are documented.
- Export flow is understandable.

### Where the noob gets hurt

#### A) Retail sniffing requires Python + gh + Npcap + curl
`_GUIDE/03_Retail_Sniffing.md:7-12` is explicit, which is good, but this is still a lot for a noob.

#### B) Linux/macOS wrappers are misleading
- `start_ymir.sh:2-4`
- `parse_captures.sh:2-4`
- `update_tools.sh:2-4`

These wrappers exist, but the underlying tooling is Windows-centric:
- `session.py` uses `tasklist` and `os.startfile` (`session.py:40-41`, `session.py:34`, `session.py:224-225`)
- `update_tools.py` downloads Windows executables (`WowPacketParser.exe`, `ymir_retail.exe`)
- `parse_captures.sh` claims parsing is portable, but `session.py --parse` still calls Windows-only assumptions indirectly through WPP executable path:
  - `WPP_EXE = ... / "WowPacketParser.exe"` — `session.py:29`

A noob on Linux/macOS will not have a working path here.

#### C) Aggregation setup docs are stale
A noob following README aggregation instructions will look for `AGGREGATION_DB` and not find it.

---

## 3.2 Persona: TC Bully

### Verdict: **Will get torn apart**

A TrinityCore Discord regular will immediately hit these points:

1. **“You said AGGREGATION_DB was removed entirely, but it’s still in README/SQL comments.”**  
   Correct criticism. See:
   - `README.md:180-181`
   - `README_DE.md:166-167`
   - `README_RU.md:166-167`
   - `sql/codex_aggregated.sql:2-3`

2. **“Your revert logic is sloppy.”**  
   Also fair. `server/install_hooks.py` revert is line-based and marker-based, not AST- or patch-based. It can miss or partially remove:
   - It removes lines containing `OnCreatureSpellCast`, `OnCreatureSpellStart`, `OnCreatureChannelFinished`, `sScriptMgr->OnAuraApply` — `server/install_hooks.py:145-148`
   - It separately special-cases `OnAuraApply` lines — `server/install_hooks.py:157-160`
   - It does **not** explicitly remove `sScriptMgr->OnCreatureSpellCast(...)`, `sScriptMgr->OnCreatureSpellStart(...)`, or `sScriptMgr->OnCreatureChannelFinished(...)` call-site lines unless they match the generic substring logic in a way that happens to catch them. It probably catches them because the substring is present, but this is fragile and not symmetrical with install.
   - It can also leave formatting scars / extra blank lines.

3. **“Your docs say any recent master, but your anchors are brittle.”**  
   Fair. `install_hooks.py` depends on exact anchor strings/regexes:
   - `server/install_hooks.py:31-38`, `47-55`, `64-83`, `89-111`, `115-122`
   Any TC refactor around `ModifySpellDamageTaken`, AI call formatting, or `_ApplyAura` criteria block will break patching.

4. **“Your SmartAI HP-phase comment is still semantically wrong.”**  
   `CreatureCodex/Export.lua:145-146`

5. **“Your Linux/macOS support is fake.”**  
   Also fair. The wrappers are present, but the actual binaries and process management are Windows-only.

---

# 4) Task 4 — New Issues Introduced / Remaining

## 4.1 Blocker: stale `AGGREGATION_DB` references remain

### Severity: **High**

This directly contradicts the v6 changelog claim.

### Exact locations

- `README.md:180-181`
- `README_DE.md:166-167`
- `README_RU.md:166-167`
- `sql/codex_aggregated.sql:2-3`

### Why it matters

This is exactly the kind of “you didn’t actually finish the rename/removal” inconsistency that destroys credibility with a hostile technical audience.

---

## 4.2 Issue: `install_hooks.py --revert` is not robust

### Severity: **Medium**

### Evidence

`server/install_hooks.py:124-180`

Problems:
- Revert is based on substring deletion, not exact inverse patches.
- It may remove lines too broadly if unrelated code contains the same hook names.
- It may leave malformed spacing/blank lines.
- It is not guaranteed to restore original file content.

This is not a blocker for shipping if documented as best-effort, but right now the script presents `--revert` as a clean supported operation:
- docstring `server/install_hooks.py:11-13`
- `_GUIDE/02_Server_Setup.md:27-29`

That promise is stronger than the implementation.

---

## 4.3 Issue: SmartAI HP-phase comment still wrong

### Severity: **Low**

### Location

- `CreatureCodex/Export.lua:145-146`

### Why it matters

The code behavior is “seen below 40% at least once,” but the comment says “only seen at low HP.” This is exactly the semantic bug you claimed to have fixed in docs.

---

## 4.4 Issue: `sql/auth_rbac_creature_codex.sql` does not match README RBAC instructions

### Severity: **Medium**

### Evidence

README says:
- `README.md:117-126`  
  Add enum in `RBAC.h`, then insert into:
  - `rbac_permissions`
  - `rbac_default_permissions`

But shipped SQL file does:
- `sql/auth_rbac_creature_codex.sql:2-3`
  - `INSERT IGNORE INTO rbac_permissions`
  - `INSERT IGNORE INTO rbac_linked_permissions`

These are **not the same approach**.

This may be valid depending on TC branch/schema, but the distribution presents both as if they are interchangeable without explanation. A TC dev will ask which schema/version this targets.

---

## 4.5 Issue: README versioning inconsistent across translations

### Severity: **Low**

### Evidence

- `README.md:1` — `# CreatureCodex v1.0.0`
- `README_DE.md:1` — `# CreatureCodex`
- `README_RU.md:1` — `# CreatureCodex`

Not a functional issue, but if you’re claiming polished release parity across 3 READMEs, this is inconsistent.

Also badges differ:
- English badge hardcodes `label=v1.0.0` — `README.md:3`
- DE/RU use `label=latest` — `README_DE.md:3`, `README_RU.md:3`

---

## 4.6 Issue: Linux/macOS wrapper messaging overpromises

### Severity: **Medium**

### Evidence

- `parse_captures.sh:2-4`
- `start_ymir.sh:2-5`
- `update_tools.sh:2-4`

The wrappers imply partial support, but:
- `session.py` hardcodes `.exe` paths (`session.py:26-29`)
- uses `tasklist` (`session.py:47-52`)
- uses `os.startfile` (`session.py:224-225`)
- `update_tools.py` downloads Windows binaries only

This is not “portable with some features missing”; it is effectively **Windows-only tooling with shell wrappers**.

---

# 5) Task 5 — Grep Audit

Requested stale patterns:

## 5.1 `bestiary`
### Verdict: **ZERO matches in provided files**
No occurrences found in the embedded content.

## 5.2 `BestiaryForge`
### Verdict: **ZERO matches**
No occurrences found.

## 5.3 `1.1.0`
### Verdict: **ZERO matches**
No occurrences found.

## 5.4 `string:trim`
### Verdict: **ZERO matches**
No occurrences found.

## 5.5 `Sync Sniff`
### Verdict: **ZERO matches**
No occurrences found.

## 5.6 `AGGREGATION_DB`
### Verdict: **FAIL — 4 matches remain**

Locations:
- `README.md:181`
- `README_DE.md:167`
- `README_RU.md:167`
- `sql/codex_aggregated.sql:2`

## 5.7 `only seen below 40`
### Verdict: **ZERO exact matches**
No exact occurrences found.

### But semantic near-match remains
- `CreatureCodex/Export.lua:146` — “Spell only seen at low HP”

Not part of the exact grep target, but still stale in meaning.

---

# 6) Additional Code Review Notes

## 6.1 `HandleSpellListMessage` silently ignores spell lists for unseen creatures
### Severity: **Low**

`CreatureCodex/CreatureCodex.lua:372-393`

It only marks DB-known spells if `db[entry]` already exists. In practice this is okay because `PLAYER_TARGET_CHANGED` pre-creates the creature before requesting `SL` (`CreatureCodex/CreatureCodex.lua:696-707`), but the handler itself is not robust to out-of-order messages.

Not a blocker.

---

## 6.2 `serverConfirmed` is never set for server cast messages
### Severity: **Low**

In `RecordSpell`, new spells initialize `serverConfirmed = false` (`CreatureCodex/CreatureCodex.lua:274`), but `HandleServerSpellMessage` never flips it to true.

So the field exists but is effectively unused for server events.

Not a blocker, but dead-ish metadata.

---

## 6.3 `GenerateNewDiscoveriesSQL` computes append index by counting `dbKnown` spells, not actual DB indices
### Severity: **Low/Medium**

`CreatureCodex/Export.lua:196-199`

```lua
local maxIdx = -1
for _, spell in pairs(creature.spells or {}) do
    if spell.dbKnown then maxIdx = maxIdx + 1 end
end
```

This assumes DB-known spells occupy contiguous indices starting at 0. If actual DB indices are sparse or reordered, appended indices may collide with existing rows or not reflect intended ordering.

Because the addon never receives actual DB indices from the server, this is understandable, but the docs should not imply exact preservation of DB slot layout.

---

# 7) Ship Readiness by Audience

## 7.1 For normal users
**Almost ship-ready** for addon-only usage.

## 7.2 For TrinityCore Discord / hostile technical audience
**Not ship-ready.**

Why:
- stale `AGGREGATION_DB` references directly contradict release notes
- revert path is weaker than advertised
- RBAC SQL/doc mismatch invites schema/version criticism
- Linux/macOS wrapper story is overstated

---

# 8) Final Ship / No-Ship Decision

## Decision: **NO-SHIP**

### Remaining blockers

#### 1. Stale `AGGREGATION_DB` references
**Severity: High**
- `README.md:180-181`
- `README_DE.md:166-167`
- `README_RU.md:166-167`
- `sql/codex_aggregated.sql:2-3`

This alone fails Task 5 and invalidates the “removed entirely” claim.

#### 2. Documentation/schema inconsistency for RBAC SQL
**Severity: Medium**
- `README.md:117-126` vs `sql/auth_rbac_creature_codex.sql:1-3`

Need to either:
- align docs to shipped SQL, or
- ship branch-specific SQL variants and say which TC schema each targets.

#### 3. Overstated portability of shell wrappers
**Severity: Medium**
- `start_ymir.sh`, `parse_captures.sh`, `update_tools.sh`
- backed by Windows-only implementation in `session.py` and `update_tools.py`

Need to explicitly say **Windows-only tooling** unless/until true cross-platform support exists.

---

# 9) Minimal Fix List Before Ship

1. Remove all stale `AGGREGATION_DB` references:
   - `README.md`
   - `README_DE.md`
   - `README_RU.md`
   - `sql/codex_aggregated.sql`

2. Fix the stale HP comment in:
   - `CreatureCodex/Export.lua:146`

3. Reconcile RBAC docs vs SQL file:
   - either update `README*.md`
   - or replace `sql/auth_rbac_creature_codex.sql` with the documented approach
   - ideally note TC schema/version assumptions

4. Tone down Linux/macOS wrapper claims:
   - mark tooling as **Windows-only**
   - or split wrappers into unsupported convenience scripts with explicit caveat

5. Optional but recommended:
   - document `AR` in protocol reference
   - clarify `install_hooks.py --revert` is best-effort, not guaranteed pristine restore

---

If you want, I can do a **v6.1 patch list** next: exact replacement text for every stale line so you can ship a clean hotfix.
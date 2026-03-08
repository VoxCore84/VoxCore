# Transmog Resource Audit — Full QA Report

> Generated 2026-03-08 | 3-pass QA: Verification → Cross-Reference → Optimization
> Covers all transmog tooling, DB2 CSVs, reference data, and the bridge spec

---

## Executive Summary

We have a **powerful but fragmented transmog tooling ecosystem** — three Python scripts with overlapping functionality, 16+ DB2 CSV tables, enriched data, and a bridge spec. The tools work well individually but aren't integrated into a cohesive QA pipeline. Key findings:

1. **Three Python tools have DisplayType mapping bugs** — each has different gaps vs the server code
2. **The bridge v3 spec is already fully implemented** — the document is historical, not a TODO
3. **Enriched CSVs are stale** — only build 66192 has them; build 66263 (current) does not
4. **No automation exists** — validation is manual-only, no CI/CD, no tests, no orchestration
5. **Tool consolidation would save ~150 lines** and fix 3 inconsistent constant dictionaries

---

## Resource-by-Resource Analysis

### 1. ATT MissingTransmog.txt

| | |
|---|---|
| **Path** | `ExtTools/ATT-Database/00 - Missing DB/MissingTransmog.txt` |
| **Size** | 4,612,319 bytes (4.4 MB) |
| **Modified** | 2026-03-04 |
| **Format** | Lua table: `s(IMAID)/i(ItemID), -- [Item name]` |
| **Entries** | ~75,719 unique IMAIDs |
| **Build span** | 1.14.0.39802 through 11.0.5.57212 |

**What it has**: Comprehensive IMAID↔ItemID mapping from the All The Things addon database. Covers every expansion.

**What it lacks**: No DisplayType, no slot info, no hidden appearances. All 11 hidden IMA IDs (77343-198608) are absent — confirmed in Pass 1.

**Verdict**: Low priority. Only useful for bulk "does this IMAID exist in retail?" checks. The wago-db2 MCP server provides the same data with richer context via SQL.

---

### 2. validate_transmog.py

| | |
|---|---|
| **Path** | `wago/validate_transmog.py` |
| **Size** | 25,212 bytes |
| **Modified** | 2026-03-04 |
| **Last report** | `wago/transmog_validation_report.json` (25,780 bytes, same date) |

**What it does**: 7-check cross-reference of client DB2 data (via wow.tools.local REST API) against MySQL hotfix overrides. Produces JSON report + optional SQL repair file.

**Checks performed**:
1. Missing server hotfix rows
2. Foreign key integrity (orphaned IMAIDs)
3. Value mismatches (client vs server)
4. TransmogSet placeholder detection
5. Reverse integrity (server entries not in client)
6. TransmogIllusion validation
7. Slot mapping vs `DisplayTypeToEquipSlot` hardcoded table

**Latest results**: 0 errors, 2 warnings, 72 info. Repair SQL empty (no fixable mismatches).

#### QA Finding: Validator Has DT Mapping Bug

The `HARDCODED_DT_TO_SLOT` dict (lines 59-74) is **missing DT 12 and DT 14**:

| DT | Description | Affected Rows | Server Code | Validator |
|----|-------------|---------------|-------------|-----------|
| 12 | Ranged (bow/xbow/gun) | 2,259 | `EQUIPMENT_SLOT_MAINHAND` | **MISSING** |
| 14 | Off-hand fist/misc | 41 | `EQUIPMENT_SLOT_OFFHAND` | **MISSING** |

These produce 2 false-positive warnings every run. The server code (`TransmogrificationPackets.cpp:110-112`) handles both correctly.

#### QA Finding: Placeholder Count Correction

Previous analysis claimed "72 unresolved IMAIDs across 43 sets." Actual numbers from the JSON report: **122 unresolved IMAIDs across 72 sets** (not 43). All severity=info, all DB2 placeholders for unreleased content. Benign.

---

### 3. transmog_debug.py

| | |
|---|---|
| **Path** | `wago/transmog_debug.py` |
| **Size** | 66,642 bytes |
| **Modified** | 2026-03-06 |

**8 modes**: `--imaid`, `--char`, `--packet`, `--outfit`, `--diff`, `--log`, `--spy`, `--spy --char`

**Most underused capabilities**:

| Mode | What it does | Why it matters |
|------|-------------|----------------|
| `--char <name>` | Full character transmog state dump (equipped + all outfits + situations) | One command shows everything — replace manual DB queries |
| `--diff <guid>` | Side-by-side equipped vs saved outfit (Match/Differ/Stale per slot) | Catches outfit save/load regressions instantly |
| `--packet --file Debug.log` | Auto-extracts and parses CMSG hex from Debug.log | No manual hex copy-paste — auto-header detection |
| `--spy --char <name>` | Cross-references TransmogSpy addon state vs server DB | Full-stack client↔server verification |

#### QA Finding: DT Mapping Bug (Same as Validator)

`DISPLAY_TYPE_TO_SLOT` (lines 64-79) is missing DT 12 and DT 14. `DISPLAY_TYPE_NAMES` (lines 81-85) also skips them. Any IMAID with these DisplayTypes will show "Unknown DT" in output.

---

### 4. transmog_lookup.py

| | |
|---|---|
| **Path** | `wago/transmog_lookup.py` |
| **Size** | 40,048 bytes |
| **Modified** | 2026-03-06 |

**9 subcommands**: `imaid`, `batch`, `batch-stdin`, `dt`, `outfits`, `slots`, `reverse`, `search`, `analyze`

**Standout features**:
- `analyze Debug.log` — reconstructs complete transmog apply sessions with DT override detection
- `batch-stdin` — pipe `grep "final:" Debug.log` output for instant bulk IMAID resolution
- `reverse <ItemID>` — find all IMAIDs for a given item
- Slot mismatch detection (`⚠ WARNING` when InventoryType→slot doesn't match DisplayType→slot)

#### QA Finding: CRITICAL — Wrong DT Numbering System

**`DISPLAY_TYPE_MAP` (lines 58-75) is mislabeled.** It claims to be "from ItemAppearance.csv" but actually uses **TransmogOutfitSlotEnum numbering**, NOT `ItemAppearance.DisplayType` numbering.

Example of the problem:
- DT 2 in `ItemAppearance.csv` = **Shirt/Body** (confirmed: hidden shirt IMA 83202 has DT=2)
- DT 2 in `transmog_lookup.py` = **SHOULDERS_2ND** (wrong — that's TransmogOutfitSlotEnum=2)

This means the `imaid` command shows misleading DisplayType labels. The `dt` command also shows the wrong table. DT 14 and DT 15 are also missing.

#### Complete DT Coverage Gap Summary

| DT | Real Meaning | Server C++ | validate_transmog | transmog_debug | transmog_lookup |
|----|-------------|------------|-------------------|----------------|-----------------|
| 0-11 | Standard armor/weapon | All correct | All correct | All correct | **Wrong numbering** |
| 12 | Ranged → MH | Present | **MISSING** | **MISSING** | Present (but wrong label) |
| 14 | OH fist/misc → OH | Present | **MISSING** | **MISSING** | **MISSING** |
| 15 | OH weapon → OH | Present | Present | Present | **MISSING** |

---

### 5. DB2 CSVs — Reference Gold

**Raw DB2 CSVs** at `ExtTools/WoW.tools/dbcs/12.0.1.66220/dbfilesclient/`:

| File | Rows | Use |
|------|------|-----|
| `transmogoutfitslotinfo.csv` | 14 | **GOLD** — authoritative slot definitions, TransmogOutfitSlotEnum values |
| `transmogoutfitslotoption.csv` | 18 | **GOLD** — weapon option routing (9 MH + 9 OH) |
| `transmogsituation.csv` | 22 | All context-switch situations (spec, location, movement, racial) |
| `transmogsituationgroup.csv` | 11 | Situation groupings |
| `transmogsituationtrigger.csv` | 8 | High-level trigger categories |
| `transmogset.csv` | 4,879 | Set catalog with class masks |
| `transmogsetitem.csv` | 71,707 | Set ↔ IMAID membership |
| `transmogillusion.csv` | 90 | Enchantment illusions |
| `transmogoutfitentry.csv` | 52 | Outfit definitions (names, costs) |

**Enriched CSVs** at `wago/wago_csv/major_12/12.0.1.66192/enriched/`:

| File | Rows | Use |
|------|------|-----|
| `transmog_outfit_slots.csv` | **30** | Pre-joined slot+option view — **the gold standard for 30-row wire layout** |
| `transmog_sets_full.csv` | 71,707 | Flattened set+item with names |
| `transmog_illusions.csv` | 90 | Human-readable illusion names |

#### QA Finding: Enriched CSVs Verified Correct

The 30-row enriched CSV matches CLAUDE.md exactly:
- 12 armor rows (no fake option-0 weapons)
- MH wire order: 1, 6, 2, 3, 7, 8, 9, 10, 11 ✓
- OH wire order: 1, 6, 7, 5, 4, 8, 9, 10, 11 ✓

#### QA Finding: Enriched CSVs Are Stale

| Source | Latest Build | Status |
|--------|-------------|--------|
| Wago CSVs (raw) | **66263** | Current |
| TACT CSVs | **66263** | Current |
| Merged CSVs | **66263** | Current |
| Enriched CSVs | **66192** | **3 builds behind** |
| ExtTools DBC | **66220** | 1 build behind |

The enrichment script exists (`wago/wago_enrich.py`) but hasn't been run against build 66263. The wago-db2 MCP server looks for enriched CSVs and won't find them for the current build.

**Fix**: `python wago/wago_enrich.py --major 12 --build 12.0.1.66263`

---

### 6. Bridge v3 Spec

| | |
|---|---|
| **Path** | `ExtTools/docs/build-transmog-bridge-v3.md` |
| **Size** | 24,338 bytes |
| **Modified** | 2026-02-28 |

#### QA Finding: Bridge Is FULLY IMPLEMENTED

The initial analysis reported this as "not implemented, all 7 checklist items unresolved." **This was wrong.** Pass 2 cross-referenced every checklist item against the codebase:

| Checklist Item | Status | Location |
|---------------|--------|----------|
| 1. Addon message handler | **DONE** | `ChatHandler.cpp:597` — `TMOG_BRIDGE` prefix check |
| 2. Slot mapping | **DONE** | `TransmogrificationHandler.cpp:877-892` — hardcoded array |
| 3. Secondary shoulder modifier | **DONE** | `TransmogrificationHandler.cpp:341` — `ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_ALL_SPECS` |
| 4. Validation functions | **DONE** | Reused via `ValidateTransmogOutfitSet()` |
| 5. Cost + free-transmog aura | **DONE** | `SPELL_AURA_REMOVE_TRANSMOG_COST` at line 320 |
| 6. `_SyncTransmogOutfitsToActivePlayerData` | **DONE** | `protected` in `Player.h:3154`, called indirectly via `SetEquipmentSet()` |
| 7. Self-whisper | **DONE** | Bridge messages processed and logged |

The merge-before-apply pattern is implemented in `FinalizeTransmogBridgePendingOutfit()` at `TransmogrificationHandler.cpp:896`. Safety net in `WorldSession::Update()` at `WorldSession.cpp:553-554`.

**The spec document is historical. It should be annotated as "IMPLEMENTED" to avoid future confusion.**

---

### 7. Wowhead Guide

| | |
|---|---|
| **Path** | `wago/wowhead_guides/guide_transmogrification_everything-about-transmog-ui-appearances.html` |
| **Published** | Sep 15, 2025 |
| **Modified** | Jan 20, 2026 |

Player-facing guide by Zvez. Useful for "what should the user experience look like?" questions. Low-frequency reference.

---

### 8. Situation System

Pass 2 found that the situation system **IS partially implemented server-side** (storage + relay only):

| Layer | Implemented? | Details |
|-------|-------------|---------|
| DB2 data | Declared only | `DB2Metadata.h:23861` — no `DB2Store` instances loaded |
| Packet handling | **Yes** | `HandleTransmogOutfitUpdateSituations` at `TransmogrificationHandler.cpp:1156-1210` |
| UpdateField storage | **Yes** | `TransmogOutfitSituationInfo` struct in `UpdateFields.h:1212-1223` |
| DB persistence | **Yes** | `_LoadTransmogOutfitSituations` / `_SaveEquipmentSets` |
| Auto-switch evaluation | **No** | Server doesn't evaluate "entered rest area → switch outfit." Client-driven. |

This is correct behavior — auto-switch is a client-side feature. The server just stores the mappings.

---

## Cross-Reference Findings

### Hidden IMA IDs — Fully Consistent

All 11 hidden appearance IDs match across every source:

| ItemID | IMA ID | DisplayType | Slot | In DB2 CSV | In Server Code | In ATT |
|--------|--------|------------|------|-----------|----------------|--------|
| 134112 | 77343 | 1 | Shoulder | ✓ | ✓ (CollectionMgr.cpp:548) | ✗ |
| 134110 | 77344 | 0 | Head | ✓ | ✓ | ✗ |
| 134111 | 77345 | 9 | Back | ✓ | ✓ | ✗ |
| 142503 | 83202 | 2 | Shirt | ✓ | ✓ | ✗ |
| 142504 | 83203 | 10 | Tabard | ✓ | ✓ | ✗ |
| 143539 | 84223 | 4 | Waist | ✓ | ✓ | ✗ |
| 158329 | 94331 | 8 | Hands | ✓ | ✓ | ✗ |
| 168659 | 104602 | 3 | Chest | ✓ | ✓ | ✗ |
| 168664 | 104603 | 6 | Feet | ✓ | ✓ | ✗ |
| 168665 | 104604 | 7 | Wrist | ✓ | ✓ | ✗ |
| 216696 | 198608 | 5 | Legs | ✓ | ✓ | ✗ |

CLAUDE.md note about `ItemDisplayInfoID==0` unreliability confirmed: cloak has `ItemDisplayInfoID=146518`, pants has `ItemDisplayInfoID=675199`.

### Two DT Numbering Systems — Never Confuse Them

This is documented in CLAUDE.md but the Python tools get it wrong:

| Value | ItemAppearance.DisplayType (DB2 routing) | TransmogOutfitSlotEnum (client slot) |
|-------|----------------------------------------|--------------------------------------|
| 0 | Head | Head |
| 1 | Shoulder | Shoulder Primary |
| 2 | **Shirt/Body** | **Shoulder Secondary** |
| 3 | **Chest** | **Back** |
| 4 | **Waist** | **Chest** |
| 5 | **Legs** | **Tabard** |
| 6 | **Feet** | **Shirt** |
| 7 | **Wrist** | **Wrist** |
| 8 | **Hands** | **Hands** |
| 9 | **Back** | **Waist** |
| 10 | **Tabard** | **Legs** |
| 11 | Mainhand | Feet |
| 12 | Mainhand (Ranged) | Mainhand |
| 13 | Offhand (Shield) | Offhand |
| 14 | Offhand (fist/misc) | — |
| 15 | Offhand (weapon) | — |

`transmog_lookup.py` uses TransmogOutfitSlotEnum numbering but calls it "DisplayType." The server code and `transmog_debug.py` correctly use ItemAppearance.DisplayType, but debug is missing DT 12/14.

### No Server-Side TransmogOutfitSlot Enum

The server does **not** have a C++ enum mirroring `TransmogOutfitSlotEnum`. It uses `EQUIPMENT_SLOT_*` constants exclusively, routed through `DisplayTypeToEquipSlot()`. The `TransmogOutfitSlotInfo` and `TransmogOutfitSlotOption` DB2 tables are declared in `DB2Metadata.h` but **not loaded** into any `DB2Store`.

---

## Optimization Recommendations

### 1. Fix DT Mapping Bugs in All Three Tools (Quick Win)

All three Python tools have DisplayType mapping gaps. A single shared source of truth would prevent this:

**Create `wago/transmog_common_maps.py`**:
```python
# Canonical DisplayType -> EquipmentSlot mapping
# Source: TransmogrificationPackets.cpp:94-116 (DisplayTypeToEquipSlot)
DISPLAY_TYPE_TO_EQUIP_SLOT = {
    0: 0,    # Head
    1: 2,    # Shoulders
    2: 3,    # Body (Shirt)
    3: 4,    # Chest
    4: 5,    # Waist
    5: 6,    # Legs
    6: 7,    # Feet
    7: 8,    # Wrists
    8: 9,    # Hands
    9: 14,   # Back
    10: 18,  # Tabard
    11: 15,  # Mainhand
    12: 15,  # Mainhand (Ranged)
    13: 16,  # Offhand (Shield)
    14: 16,  # Offhand (fist/misc)
    15: 16,  # Offhand (weapon)
}
```

Import this in all three tools. Eliminates 3 divergent copies.

### 2. Regenerate Enriched CSVs for Build 66263

```bash
cd C:/Users/atayl/VoxCore/wago
python wago_enrich.py --major 12 --build 12.0.1.66263
```

The wago-db2 MCP server looks for enriched CSVs at `<build>/enriched/` and preloads them. Without this, enriched table queries against the current build will fail or fall back to stale 66192 data.

### 3. Create `/transmog-qa` Slash Command

Currently, transmog QA is entirely manual. A `/transmog-qa` skill would run all tools in one pass:

```
1. python validate_transmog.py          → DB2 vs hotfix check
2. python transmog_debug.py --char 7    → full character state
3. python transmog_debug.py --diff 7    → equipped vs saved diff
4. python transmog_lookup.py analyze Debug.log → session replay
```

Present unified pass/fail dashboard. Skip validate if WTL is offline. Test character: GUID 7 (Graham).

### 4. Extract Shared Module (`transmog_common.py`)

All three tools duplicate:
- CSV loading (~30 lines each, 3 different implementations)
- IMAID resolution function (~20 lines each)
- Equipment slot name constants (different strings: "SHOULDERS" vs "SHOULDER")
- DisplayType mapping (3 divergent copies, all with bugs)

A shared `transmog_common.py` would eliminate ~150 lines of duplication and ensure consistency.

### 5. Add `--json` Output to Debug and Lookup Tools

`validate_transmog.py` already produces JSON (`transmog_validation_report.json`). The other two tools only produce human-readable text. Adding `--json` would enable:
- Machine-readable pipeline composition
- Automated regression comparison between runs
- Integration with `/transmog-qa` for structured result parsing

### 6. Annotate Bridge Spec as IMPLEMENTED

`ExtTools/docs/build-transmog-bridge-v3.md` should have a header noting "IMPLEMENTED — all checklist items resolved." Current state is misleading (reads as a TODO).

### 7. Update ExtTools DBC Directory

Missing build 66263. Current latest: 66220 (1 build behind). Low priority since merged Wago CSVs are current, but worth updating for wow.tools.local consistency.

---

## Priority Action Items

| # | Action | Effort | Impact |
|---|--------|--------|--------|
| 1 | Fix DT maps in all 3 Python tools (or create shared module) | 30 min | High — eliminates false warnings + wrong labels |
| 2 | Regenerate enriched CSVs for 66263 | 5 min | Medium — unblocks MCP enriched queries |
| 3 | Annotate bridge spec as IMPLEMENTED | 2 min | Low — prevents future confusion |
| 4 | Create `/transmog-qa` slash command | 1 hr | High — transforms manual QA into one-click |
| 5 | Add `--json` to debug + lookup tools | 1 hr | Medium — enables automation |
| 6 | Add smoke tests for Python tools | 2 hr | Medium — catches regressions |

---

## Appendix: Tool Quick Reference

```
# Validate DB2 vs hotfixes (requires WTL at localhost:5000)
cd wago && python validate_transmog.py --verbose

# Full character transmog state
cd wago && python transmog_debug.py --char 7

# Equipped vs saved outfit diff
cd wago && python transmog_debug.py --diff 7

# Parse transmog packets from Debug.log
cd wago && python transmog_debug.py --packet --file ../out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Debug.log

# Resolve specific IMAIDs
cd wago && python transmog_lookup.py imaid 304252 289579

# Full session replay from Debug.log
cd wago && python transmog_lookup.py analyze ../out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Debug.log

# Bulk resolve from grep output
grep "final:" Debug.log | cd wago && python transmog_lookup.py batch-stdin

# Search items by name
cd wago && python transmog_lookup.py search "shoulderguard"

# Reverse lookup: all IMAIDs for an item
cd wago && python transmog_lookup.py reverse 267260
```

# Spell Audit Pipeline

## Status: ACTIVE (sessions 88, 99+)
Original commit `27c2d7d04e` — C++ stubs deleted (caused 1,842 errors), SQL neutralized.

## What It Is
Automated audit of all class/spec spells from DB2 trait data, classifying each spell by implementation status:
- **GREEN** (2,963): Data-driven, working without C++ scripts
- **YELLOW** (1,635): Passive DUMMY auras needing C++ value consumption
- **RED** (253): Active DUMMY/PERIODIC_DUMMY effects needing C++ handlers
- **MISSING** (114): Spell IDs referenced by traits but absent from DB2

## Files — Pipeline Tools (in `wago/`, gitignored)
- `class_spell_audit.py` — Core audit engine, reads DB2 CSVs, outputs per-spec JSONs
  - `--interactions` — Generates per-class SpellClassMask interaction maps (15 JSON files)
  - `--spell SPELL_ID` — Deep single-spell audit (identity, modifiers, triggers, labels, procs)
- `generate_spell_fixes.py` — C++ and SQL generator from fix_categories.json
- `simc_spell_miner.py` — SimC engine data cross-reference (991 matches)
- `simc_name_crossref.py` — Name-based SimC matching (995 matches)
- `audit_reports/fix_categories.json` — All 1,888 spells categorized into 7 buckets
- `audit_reports/simc_crossref.json` — SimC ID+name behavioral references
- `audit_reports/trigger_chain_analysis.json` — 7 GREEN-promotable, 5 partial, 25 need script
- `audit_reports/interactions_*.json` — Per-class interaction maps (129K pairwise matches, 9,182 spells)
- `audit_reports/spell_deep_*.json` — Single-spell deep audit output

## Files — Committed
- `src/server/scripts/Custom/SpellAudit/spell_{class}_audit.cpp` — 13 files, 1,842 scripts
- `src/server/scripts/Custom/custom_script_loader.cpp` — 13 AddSC registrations
- `sql/updates/world/master/2026_03_07_08_world.sql` — 114 serverside_spell stubs
- `sql/updates/world/master/2026_03_07_09_world.sql` — 18 spell_proc entries
- `sql/updates/world/master/2026_03_07_10_world.sql` — 1,888 spell_script_names

## Classification Bugs Fixed (session 88)
1. **Aura 226 mislabel**: Was labeled PROC_TRIGGER_SPELL_COPY, actually PERIODIC_DUMMY. Affected 310 spells.
2. **Aura 196 mislabel**: Was in SCRIPT_AURA_TYPES as PERIODIC_DUMMY, actually MOD_COOLDOWN (data-driven).
3. **GREEN heuristic too aggressive**: Tooltip-only check needed BOTH `BonusCoefficient=0` AND `BasePoints=0`.

## Generator Bugs Fixed (session 88)
1. `sanitize_comment()` missing from 3 of 6 desc_short assignments — caused C2001 newline errors
2. No class name dedup — caused C2011 redefinition (e.g., two "Essence Burst" spells)
3. Enum prefix `SPELL_` clashed with TC enums (e.g., `SPELL_AURA_MASTERY`) — fixed with `SPELL_<CLASS>_` prefix

## Fix Category Breakdown
| Bucket | Count | Description |
|--------|-------|-------------|
| PASSIVE_DUMMY (modifier_buff) | ~400 | Store modifier values in DUMMY aura |
| PASSIVE_DUMMY (proc_handler) | ~350 | Proc on combat events |
| PASSIVE_DUMMY (trigger_effect) | ~280 | Trigger spell on proc |
| PASSIVE_DUMMY (other) | ~500 | Need individual research |
| PERIODIC_DUMMY | 100 | Tick handlers |
| ACTIVE_DUMMY | 189 | HandleDummy / active aura apply |
| PROC_NEEDS_SQL | 24 | Need spell_proc entries (18 generated) |
| TRIGGER_CHAIN | 37 | Chain triggers (7 promotable to GREEN) |
| EMPOWER | 5 | Evoker empower mechanics |
| SCRIPT_EFFECT | 1 | Lone SPELL_EFFECT_SCRIPT_EFFECT |

## C++ Scanner Fix (session 99+)
- Old scanner matched ALL SPELL_XXX constants in class bodies → ~860 false positives
- Fixed: now uses comment-header spell IDs only (`// NNNNN - SpellName` TC convention)
- Before fix: 1,984 C++ scan / 6,809 total → all 4,965 GREEN (fake)
- After fix: 1,122 C++ scan / 5,481 total → 4,868 GREEN / 84 YELLOW / 13 RED

## Orphaned SQL Neutralization (session 99+)
- `_08`, `_09`, `_10`: From deleted C++ stubs. Neutralized to comment-only no-ops.
- `_10` would have registered 1,888 script names for non-existent classes.

## Spell Fixes Applied (session 99+)
- `_11`: Registered 260708 (Sweeping Strikes) + 53563 (Beacon of Light) in spell_script_names
- Both had real C++ handlers registered under old spell IDs

## Interaction Analysis (session 99)
- **SpellClassMask interaction map**: 4,879 identity spells, 8,026 targeting effects, 129,437 pairwise matches
- **Coverage caveat**: ~80% of class spells have all-zero masks — interactions for those are in C++ scripts only
- **Deep audit** combines: mask overlaps, EffectTriggerSpell chains, SpellLabel siblings, ProcTypeMask decoding

## Current Audit Results (post-fix)
- **4,868 GREEN**: Data-driven or has real C++ handler
- **84 YELLOW**: Passive DUMMY auras, inert (0% SimC match — all low priority)
- **13 RED**: Active DUMMY/PERIODIC_DUMMY without handler (core spell works, supplementary effect unscripted)

## 13 Remaining RED Spells
- 13750 Adrenaline Rush, 31884 Avenging Wrath, 42650 Army of the Dead
- 51271 Pillar of Frost, 55078 Blood Plague, 64843 Divine Hymn
- 108280 Healing Tide Totem, 187827 Metamorphosis(V), 195181 Bone Shield
- 200183 Apotheosis, 341291 Unfurling Darkness, 383414 Amplifying Poison
- 1217607 Void Metamorphosis
- 4 have partial/related handlers, 9 need new C++ implementation

## Next Steps
1. **Implement 13 RED handlers** — core spells work, DUMMY effects are supplementary
2. **Promote 7 trigger chain spells to GREEN** (Whirlwind, Execute, Wake of Ashes, etc.)
3. **SimC-guided implementation** — 991 spells have SimC behavioral references to guide handler logic

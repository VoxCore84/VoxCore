# Build Diff Audit

## Overview
Full DB2 CSV diff across 5 WoW 12.0.1 builds: 66044 → 66102 → 66192 → 66198 → 66220.
39 priority tables compared. Cross-referenced with TrinityCore MySQL (world, hotfixes).

## Wago Export Oscillation
Wago.tools CSV exports oscillate wildly between builds for certain tables:
- SpellEffect: 269K-511K (reduced) vs 608K (full)
- ItemSparse: 125K vs 171K
- SpellMisc: 136K vs 404K
- CriteriaTree: 4K vs 115K
- CreatureDisplayInfo: 15K vs 118K

**Full export builds**: 66102, 66198
**Reduced export builds**: 66044, 66192, 66220

Detection: `wc -l SpellEffect-enUS.csv` — >500K = full, <400K = reduced

## Actual Content Delta (66044 → 66220)
- **Spells**: +77 new, -1 removed (1251299), ~288 attribute mods, ~28 effect tuning changes
- **Items**: +17 new (mounts, titles, toys), ~308 modifications (flags, iLvl, required level)
- **Quests**: +9 new (95963-95971)
- **Achievements**: +5 new (Slayer's Rise PvP), +111K CriteriaTree backfill, +50K Criteria backfill
- **Creatures**: +1 new display, 5 tweaks
- **Maps**: 4 flag modifications
- **Currencies**: +1 new (3474), Honor cap 15K→4K, Dawncrest text updates

## Scripted Spell Safety
40 spells with `spell_script_names` registrations got new SpellEffect entries in 66220.
**All safe** — new effects appended at higher EffectIndex values (3, 4, 5+), never replacing existing 0/1/2.
Architecture: `SpellInfo.cpp:1298` uses `EnsureWritableVectorIndex(spellEffect->EffectIndex)` — explicit indexing.

Key checked scripts:
- spell_dru_cat_form (768): EFFECT_0 only, aura-type matched
- spell_warr_cleave_dmg (845): EFFECT_0, Midnight-validated
- spell_mage_arcane_explosion (1449): EFFECT_0/1/2 with Validate() type-checks
- spell_dk_death_coil (47541): EFFECT_0 DUMMY
- spell_mage_ice_block (45438): Dead binding — no C++ class exists

## Removed Spell
- SpellID 1251299: Removed between 66044→66220. No spell_script_names entry (safe). Orphan in hotfixes.spell_name.

## Scripts & Reports
All at `C:\Users\atayl\source\wago\`:
- `diff_builds.py` — CLI diff tool with oscillation detection (`--base`, `--target` args)
- `cross_ref_mysql.py` — Cross-references diff JSON with world/hotfixes MySQL
- `build_diff_report_*.md` — Per-increment and cumulative diff reports
- `build_audit_actions.md` — Categorized action items (red/yellow/green/blue)
- `build_diff_data_*.json` — Raw diff data for scripting
- `raidbots/NOTES.md` — Pipeline notes on full vs reduced builds

## Wago CSV Inventory
All at `C:\Users\atayl\source\wago\wago_csv\major_12\`:
- `12.0.1.66044/enUS/` — 1098 CSVs
- `12.0.1.66102/enUS/` — 1098 CSVs
- `12.0.1.66192/enUS/` — 1098 CSVs
- `12.0.1.66198/enUS/` — 1098 CSVs (downloaded other tab)
- `12.0.1.66220/enUS/` — 1098 CSVs

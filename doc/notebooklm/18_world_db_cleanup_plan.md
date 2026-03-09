# VoxCore World DB Cleanup — Comprehensive Plan

**Date**: 2026-03-08
**Author**: Claude Code (sessions 100-102)
**Status**: In Progress — Phase 1 complete, Phase 2 ready

---

## Executive Summary

Our world database has accumulated data quality issues from the LoreWalker TDB migration, incomplete imports, and missing Midnight-era content. This plan covers everything from what's been done to what remains, organized into prioritized phases.

**Key finding**: Many "missing" visual elements (ships, NPCs, terrain) aren't actually deleted — they're **invisible due to missing `phase_area` entries**. This is the single highest-impact fix category.

---

## What's Been Done (Sessions 100-102)

### Applied to Database

| SQL File | What | Rows Affected |
|----------|------|---------------|
| `_07_13` | Corrupt gameobject cleanup (bad GUIDs, duplicates, Z=0) | 47,033 deleted |
| `_07_15` | Faction fixes + phase cleanup | 83 updated |
| `_07_16` | ContentTuningID=0 fixes (Stormwind, Silvermoon, Exodar, Exile's Reach) | 262 updated |
| `_07_17` | BfA portal room portals + Hero's Call Board Z/rotation fixes (LoreWalker) | 7 inserted, 5 updated, 2 inserted |
| `_07_18` | Midnight portal room upgrade — replaced BfA placeholders with 620xxx entries | 7 deleted, 11 templates created, 11+1+2 spawns inserted |

### Ready to Apply

| SQL File | What | Rows |
|----------|------|------|
| `_08_00` | Draconic diff: phase_area + missing spawns for Stormwind | 42 inserts |

### Tools Built

| Tool | Location | Purpose |
|------|----------|---------|
| `diff_draconic.py` | `tools/` | Zone-by-zone world DB diff against Draconic-WOW (build 66263) |

### Key Discoveries

1. **phase_area is the root cause** of most "missing content" reports. Phases 45499-45502, 45562 were never imported for Stormwind, making phased NPCs (Genn, Velen, Anduin, embassy leaders) invisible.
2. **Corrupt GUIDs >= 71B** in Draconic are seasonal holiday decorations (Hallow's End candles/pumpkins, Day of the Dead marigolds). These are correctly filtered — they're import artifacts, not permanent world data.
3. **Ships and Lion's Rest memorial** are WMO terrain objects baked into client map files. The server doesn't control their 3D models — only their **phase visibility**. Missing phase_area rows can make them invisible.
4. **Our DB actually has MORE clean spawns** than Draconic for Stormwind (2,862 vs 2,670 clean GOs). The apparent deficit was inflated by Draconic's 3,409 corrupt-GUID seasonal spawns.

---

## Phase 2: Immediate Actions (Today)

### 2A. Apply Pending SQL
```
/apply-sql world   (file: 2026_03_08_00_world.sql)
```
This adds:
- 7 phase_area entries (enables phases 45499-45502, 45562, 10061, 27073)
- 7 gameobject_template entries (Midnight Old Town decorations)
- 10 gameobject spawns (Hero's Call Board, Hellfire Portal, Valdrakken Portal, 7 decorations)
- 15 creature spawns (phased Genn/Velen/Anduin, embassy NPCs, Silvermoon Mages, etc.)
- 3 creature_addon entries (patrol path + mage auras)

### 2B. Commit All Uncommitted Work
Files to commit:
- `sql/updates/world/master/2026_03_07_12_world.sql` (modified — comment tweak)
- `sql/updates/world/master/2026_03_07_17_world.sql` (new — portal room + boards)
- `sql/updates/world/master/2026_03_07_18_world.sql` (new — Midnight portal upgrade)
- `sql/updates/world/master/2026_03_08_00_world.sql` (new — Draconic diff import)
- `tools/diff_draconic.py` (new — diff tool)

Do NOT commit: `sql/exports/` (generated output, add to .gitignore)

### 2C. In-Game Verification
After applying _08_00 and restarting worldserver:
1. **Portal Room**: Verify Portal to Valdrakken is visible (should be next to existing portals)
2. **Keep**: Check if Genn Greymane and Prophet Velen appear (may require quest progress for phase 45499/45502)
3. **Cathedral / Lion's Rest**: Check for Anduin Wrynn (phases 45500/45501)
4. **Embassy area**: Check for Lady Liadrin, Lor'themar, Turalyon (phase 45562 — Midnight intro)
5. **Portal Room**: Verify 2 Silvermoon Mages are standing by portals
6. **Old Town**: Check for new decorations (Bookshelf, Keg, Table, etc. near -8888, 747)
7. **Hero's Call Boards**: Verify all boards are above ground (Z fixes from _17)

### 2D. Shut Down Draconic MySQL
Once diffing is done:
```bash
# Find and kill Draconic's mysqld process
taskkill /F /IM mysqld.exe   # (if only Draconic is running on named pipe)
# OR close the terminal window running it
```
**Keep Draconic's data files** — we'll need them for Phase 3 zone diffs.

---

## Phase 3: Zone-by-Zone Diffs (Next Sessions)

### Overview
Run `diff_draconic.py` against every major city/zone to find missing spawns and phase_area gaps. Each zone produces one SQL update file.

### Priority Order

| Priority | Zone ID | Zone Name | Map | Why |
|----------|---------|-----------|-----|-----|
| 1 | 1519 | Stormwind City | 0 | DONE (session 102) |
| 2 | 1637 | Orgrimmar | 1 | Horde capital, likely same phase_area gaps |
| 3 | 1537 | Ironforge | 0 | Alliance city |
| 4 | 1657 | Darnassus | 1 | Alliance city (Teldrassil) |
| 5 | 3487 | Silvermoon City | 530 | Has Midnight 260xxx NPCs, already did CT fixes |
| 6 | 3557 | The Exodar | 530 | Already did CT fixes |
| 7 | 1497 | Undercity | 0 | Horde city |
| 8 | 1638 | Thunder Bluff | 1 | Horde city |
| 9 | 14753 | Dornogal | 2552 | Midnight capital (needs ZONE_BOUNDS added) |
| 10 | 13644 | Valdrakken | 2444 | Dragonflight capital (needs ZONE_BOUNDS) |

### Per-Zone Workflow
```
1. Start Draconic MySQL (if not running)
2. python tools/diff_draconic.py --zone <ID> --map <MAP> --dry-run
3. Review missing spawns — filter out anything suspicious
4. python tools/diff_draconic.py --zone <ID> --map <MAP>
5. Compare phase_area between DBs for that zone
6. Combine into SQL update file
7. /apply-sql world
8. In-game verification
```

### Phase_area Audit (Critical — Do For Every Zone)
For each zone, run:
```sql
-- Find phases in Draconic but not in ours
SELECT d.AreaId, d.PhaseId, d.Comment
FROM draconic_world.phase_area d
LEFT JOIN world.phase_area o ON d.AreaId = o.AreaId AND d.PhaseId = o.PhaseId
WHERE o.AreaId IS NULL AND d.AreaId = <ZONE_ID>;
```
This requires a cross-database query (both DBs on same MySQL), or a Python script to compare.

**Recommendation**: Add a `--phase-area` flag to `diff_draconic.py` that automatically diffs phase_area entries for the zone.

### ZONE_BOUNDS Needed For New Zones
The diff tool currently has bounds for 8 classic cities. Add bounds for:
- Dornogal (14753) — Khaz Algar, map 2552
- Valdrakken (13644) — Dragon Isles, map 2444
- Oribos (10424) — Shadowlands, map 2222
- Boralus (8499) — Kul Tiras, map 1643

These require looking up UiMapAssignment DB2 data for coordinate ranges.

---

## Phase 4: Systematic Data Quality Fixes

These are independent of Draconic diffs and can be done in parallel.

### 4A. ContentTuningID=0 Remaining (~5,200 entries)
**Status**: 262 fixed in _16, ~5,200 remain globally
**Impact**: NPCs with CT=0 may not scale correctly or may appear as level 1
**Approach**:
1. Query all CT=0 entries grouped by zone
2. For each zone, determine dominant CT from existing entries
3. Use Wowhead to verify specific high-profile entries
4. Generate SQL in batches (per zone or per expansion)

```sql
-- Find remaining CT=0 entries by zone
SELECT c.zoneId, COUNT(*) AS cnt
FROM creature cr
JOIN creature_template_difficulty ctd ON cr.id = ctd.Entry
WHERE ctd.DifficultyID = 0 AND ctd.ContentTuningID = 0
  AND cr.map IN (0, 1, 530, 571, 860, 870, 1116, 1220, 1643, 2222, 2444, 2552)
GROUP BY c.zoneId ORDER BY cnt DESC;
```

### 4B. Broken SmartAI Action Lists (193 entries)
**Status**: Identified, not started
**Impact**: NPCs with broken SmartAI may not perform scripted actions
**Approach**:
1. Identify which action lists reference non-existent entries
2. Cross-reference with Draconic's `smart_scripts` table
3. Import missing action lists or remove broken references

```sql
-- Find SmartAI referencing non-existent action lists
SELECT s.entryorguid, s.source_type, s.action_type, s.action_param1
FROM smart_scripts s
WHERE s.action_type IN (80, 81, 82, 83, 84, 85, 86, 87)
  AND s.action_param1 NOT IN (
    SELECT entryorguid FROM smart_scripts WHERE source_type = 9
  );
```

### 4C. Empty Vendors (728 entries)
**Status**: Identified, not started
**Impact**: Vendor NPCs with no items to sell (empty windows)
**Approach**:
1. List vendor NPCs with npc_vendor flag but no `npc_vendor` rows
2. Cross-reference with Draconic's `npc_vendor` table
3. Import missing vendor data

### 4D. Broken Patrollers (693 entries)
**Status**: Identified, not started
**Impact**: NPCs with MovementType=2 (waypoint) but no waypoint_path data — they stand still
**Approach**:
1. List creatures with MovementType=2 and no matching waypoint_path
2. Either import paths from Draconic or reset to MovementType=0 (stationary)

### 4E. Hero's Call Board Fine-Tuning
**Status**: Z/rotation fixed in _17, needs in-game verification
**Impact**: Boards 1/2/5 used estimated Z values (not LoreWalker-confirmed)
**Approach**: Log in, fly to each board, verify they're above ground and facing correctly. Adjust with `.go xyz` and record corrected values.

---

## Phase 5: Global Phase_area Audit

This is the **single highest-impact remaining task** after zone diffs.

### The Problem
Our `phase_area` table may be missing entries for dozens of zones, not just Stormwind. Each missing entry means an entire phase's worth of content is invisible.

### The Approach
```
1. Export full phase_area from both DBs
2. Diff them (LEFT JOIN to find entries in Draconic but not ours)
3. Categorize by zone and review
4. Import verified entries
```

### Scale Estimate
```sql
-- How many phase_area entries does each DB have?
SELECT COUNT(*) FROM phase_area;  -- Run on both DBs
```

This could reveal hundreds of missing phase_area entries across all zones.

### Automation
Add to `diff_draconic.py`:
```python
def diff_phase_area(zone_id):
    """Compare phase_area entries for a zone between both DBs."""
    drac = run_query_dicts(DRAC_ARGS, f"SELECT * FROM phase_area WHERE AreaId = {zone_id}", ...)
    ours = run_query_dicts(OUR_ARGS, f"SELECT * FROM phase_area WHERE AreaId = {zone_id}", ...)
    # Find entries in Draconic not in ours
    ...
```

---

## Phase 6: Broader Data Integrity

Lower priority, tackle as time permits.

### 6A. creature_template_difficulty Audit
- Many entries have DifficultyID=0 with ContentTuningID=0 (Phase 4A)
- Some entries may have incorrect `faction`, `npcflag`, or `unit_flags` values
- Cross-reference with Draconic for high-traffic zones

### 6B. Gameobject Template Audit
- Some templates may have displayId=0 (invisible objects)
- Check for templates with no spawns (dead data)
- Verify portal templates have correct spell references

### 6C. Loot Table Audit
- Cross-reference `creature_loot_template` with Draconic
- Identify NPCs that should drop items but have empty loot tables
- Verify reference loot tables exist

### 6D. Quest Chain Audit
- Verify quest prerequisite chains are intact
- Check for orphaned quests (prereqs that don't exist)
- Cross-reference quest rewards with hotfixes DB

---

## Tools & Resources

### Databases
| Database | Connection | Purpose |
|----------|-----------|---------|
| Our MySQL | port 3306, root/admin | Production world DB |
| Draconic MySQL | named pipe, root (skip-grant-tables) | Reference DB (build 66263) |
| LoreWalker TDB | `ExtTools/LoreWalkerTDB/world.sql` (897MB dump) | Additional reference |

### Scripts
| Script | Purpose |
|--------|---------|
| `tools/diff_draconic.py` | Zone-by-zone spawn + template diff |
| `tools/spell_creator.py` | Spell audit / hotfix generation |
| `tools/gen_rp_spells.py` | RP spell generation |

### Starting Draconic MySQL
```bash
DRACONIC_BASE="C:/Users/atayl/OneDrive/Desktop/Excluded/66263Precompiled/66263Precompiled/bin/RelWithDebInfo/UniServerZ/core/mysql"

# Clear stale binlog index
> "$DRACONIC_BASE/data/binlog.index"

# Write temp config
cat > /tmp/draconic_my.ini << 'EOF'
[mysqld]
basedir=C:/Users/atayl/OneDrive/Desktop/Excluded/66263Precompiled/66263Precompiled/bin/RelWithDebInfo/UniServerZ/core/mysql
datadir=C:/Users/atayl/OneDrive/Desktop/Excluded/66263Precompiled/66263Precompiled/bin/RelWithDebInfo/UniServerZ/core/mysql/data
enable-named-pipe
named-pipe-full-access-group=*everyone*
disable-log-bin
mysqlx=OFF
skip-grant-tables
port=0
EOF

# Start (runs in foreground — use a separate terminal)
"$DRACONIC_BASE/bin/mysqld.exe" --defaults-file=/tmp/draconic_my.ini --console

# Connect with:
mysql -u root --pipe world
```

### Slash Commands
- `/apply-sql world` — Apply SQL update file
- `/check-logs` — Check server logs after changes
- `/soap .reload all` — Hot-reload after DB changes (if server running)
- `/lookup-creature <name>` — Find creature entries
- `/lookup-area <name>` — Find zone/area IDs

---

## Risk Mitigation

1. **All INSERT IGNORE** — idempotent, safe to re-run, won't duplicate
2. **No DELETEs in diff output** — we only add, never remove
3. **VerifiedBuild=0** — imported data is marked as custom, won't conflict with future TDB updates
4. **GUID ranges above 3.1B** — well above any existing organic data
5. **Draconic corrupt GUIDs filtered** — seasonal/import artifacts excluded at >= 71B
6. **World-origin spawns filtered** — broken (0,0,0) positions excluded
7. **Critter/Totem/Pet filter** — ambient creatures excluded from creature diffs
8. **Template existence checks** — spawns without templates are skipped (not blindly inserted)

---

## Timeline Estimate

| Phase | Scope | Sessions |
|-------|-------|----------|
| 2 (Immediate) | Apply _08_00, commit, verify | This session |
| 3 (Zone diffs) | 9 remaining zones | 2-3 sessions |
| 4A (CT=0) | ~5,200 entries | 1-2 sessions |
| 4B-4D (SmartAI/vendors/paths) | ~1,600 entries | 2-3 sessions |
| 5 (Global phase_area) | Full audit | 1 session |
| 6 (Broader integrity) | Ongoing | As needed |

**Total estimated**: 6-10 sessions to complete all phases.

---

## Quick Reference — Uncommitted Files

```
Modified:
  sql/updates/world/master/2026_03_07_12_world.sql  (comment tweak)

New (to commit):
  sql/updates/world/master/2026_03_07_17_world.sql  (portals + boards)
  sql/updates/world/master/2026_03_07_18_world.sql  (Midnight portal upgrade)
  sql/updates/world/master/2026_03_08_00_world.sql  (Draconic diff import)
  tools/diff_draconic.py                             (diff tool)

New (do NOT commit):
  sql/exports/draconic_diff_zone_1519.sql            (generated output)
```

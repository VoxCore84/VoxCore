#!/usr/bin/env python3
"""
validate_models.py — Validate creature model/display IDs against CreatureDisplayInfo DB2.

Cross-references the CreatureDisplayInfo DB2 CSV (118K valid display IDs) against:
  1. creature_template_model — the primary model assignment table
  2. creature.modelid — per-spawn display overrides

Detects:
  - Invalid display IDs (not in CreatureDisplayInfo DB2)
  - Zero/NULL display IDs in creature_template_model
  - Duplicate model indices (same CreatureID + Idx appearing multiple times)
  - Missing models (creature_template entries with NO rows in creature_template_model)
  - Invalid per-spawn modelid overrides in the creature table

For missing models, cross-references against creature spawns to prioritize:
  - HIGH: spawned creatures with no model (invisible NPCs)
  - LOW: unspawned templates with no model

Outputs:
  - model_validation_report.txt     Summary + detailed listings
  - npc_model_fixes.sql             Safe SQL fixes (removals only, no guessing)
"""

import csv
import subprocess
import sys
from collections import defaultdict

# =============================================================================
# Configuration
# =============================================================================

CDI_CSV = (
    r"C:\Users\atayl\source\wago\wago_csv\major_12"
    r"\12.0.1.66220\enUS\CreatureDisplayInfo-enUS.csv"
)
OUTPUT_DIR = r"C:\Dev\RoleplayCore\sql\exports\cleanup"
MYSQL_BIN = r"C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
MYSQL_USER = "root"
MYSQL_PASS = "admin"
MYSQL_DB = "world"

REPORT_FILE = f"{OUTPUT_DIR}\\model_validation_report.txt"
SQL_FILE = f"{OUTPUT_DIR}\\npc_model_fixes.sql"


# =============================================================================
# Helpers
# =============================================================================

def mysql_query(sql: str) -> list[list[str]]:
    """Run a MySQL query and return rows as lists of strings.

    Uses --raw mode and careful parsing to handle fields containing newlines.
    MySQL batch mode escapes embedded newlines as \\n (literal backslash-n)
    and embedded tabs as \\t, so we split on real newlines and real tabs.
    """
    cmd = [MYSQL_BIN, "-u", MYSQL_USER, f"-p{MYSQL_PASS}", MYSQL_DB,
           "--batch", "--skip-column-names", "-e", sql]
    result = subprocess.run(cmd, capture_output=True, text=True,
                            encoding="utf-8", errors="replace")
    if result.returncode != 0:
        print(f"MySQL error: {result.stderr.strip()}", file=sys.stderr)
        sys.exit(1)
    rows = []
    for line in result.stdout.split("\n"):
        line = line.rstrip("\r")
        if line:
            rows.append(line.split("\t"))
    return rows


def load_valid_display_ids() -> set[int]:
    """Load the set of valid display IDs from CreatureDisplayInfo DB2 CSV."""
    valid = set()
    with open(CDI_CSV, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                valid.add(int(row["ID"]))
            except (ValueError, KeyError):
                continue
    return valid


# =============================================================================
# Data Collection
# =============================================================================

def get_template_models() -> list[dict]:
    """Get all creature_template_model rows."""
    rows = mysql_query(
        "SELECT CreatureID, Idx, CreatureDisplayID, DisplayScale, Probability "
        "FROM creature_template_model ORDER BY CreatureID, Idx"
    )
    result = []
    for r in rows:
        result.append({
            "CreatureID": int(r[0]),
            "Idx": int(r[1]),
            "DisplayID": int(r[2]),
            "Scale": float(r[3]),
            "Probability": float(r[4]),
        })
    return result


def get_creature_names() -> dict[int, str]:
    """Get creature_template entry -> name mapping.

    Uses REPLACE to strip embedded newlines/tabs from names, which would
    otherwise break batch-mode TSV parsing.
    """
    rows = mysql_query(
        "SELECT entry, REPLACE(REPLACE(name, '\\n', ' '), '\\t', ' ') "
        "FROM creature_template"
    )
    result = {}
    for r in rows:
        if len(r) >= 2:
            try:
                result[int(r[0])] = r[1]
            except ValueError:
                continue
    return result


def get_all_template_entries() -> set[int]:
    """Get all creature_template entry IDs."""
    rows = mysql_query("SELECT entry FROM creature_template")
    return {int(r[0]) for r in rows}


def get_spawn_model_overrides() -> list[dict]:
    """Get creature spawn rows that have a non-zero modelid override."""
    rows = mysql_query(
        "SELECT guid, id, modelid, map, zoneId, areaId "
        "FROM creature WHERE modelid != 0"
    )
    result = []
    for r in rows:
        result.append({
            "guid": int(r[0]),
            "CreatureID": int(r[1]),
            "modelid": int(r[2]),
            "map": int(r[3]),
            "zone": int(r[4]),
            "area": int(r[5]),
        })
    return result


def get_spawned_creature_ids() -> set[int]:
    """Get set of creature IDs that have at least one spawn."""
    rows = mysql_query("SELECT DISTINCT id FROM creature")
    return {int(r[0]) for r in rows}


# =============================================================================
# Analysis
# =============================================================================

def analyze(valid_ids: set[int], models: list[dict], names: dict[int, str],
            all_entries: set[int], spawn_overrides: list[dict],
            spawned_ids: set[int]):
    """Run all validations and return categorized results."""

    results = {}

    # --- 1. Invalid display IDs in creature_template_model ---
    invalid_models = []
    for m in models:
        if m["DisplayID"] != 0 and m["DisplayID"] not in valid_ids:
            invalid_models.append(m)
    results["invalid_models"] = invalid_models

    # --- 2. Zero display IDs in creature_template_model ---
    zero_models = [m for m in models if m["DisplayID"] == 0]
    results["zero_models"] = zero_models

    # --- 3. Duplicate Idx entries (same CreatureID + Idx) ---
    idx_counts = defaultdict(int)
    for m in models:
        key = (m["CreatureID"], m["Idx"])
        idx_counts[key] += 1
    duplicates = {k: v for k, v in idx_counts.items() if v > 1}
    results["duplicate_idx"] = duplicates

    # --- 4. Missing models (creature_template with NO creature_template_model rows) ---
    creatures_with_models = {m["CreatureID"] for m in models}
    missing_entries = all_entries - creatures_with_models

    missing_spawned = []    # HIGH priority — these are invisible
    missing_unspawned = []  # LOW priority

    for entry in sorted(missing_entries):
        name = names.get(entry, "<unknown>")
        if entry in spawned_ids:
            missing_spawned.append((entry, name))
        else:
            missing_unspawned.append((entry, name))

    results["missing_spawned"] = missing_spawned
    results["missing_unspawned"] = missing_unspawned

    # --- 5. Invalid per-spawn modelid overrides in creature table ---
    invalid_spawn_overrides = []
    for s in spawn_overrides:
        if s["modelid"] not in valid_ids:
            invalid_spawn_overrides.append(s)
    results["invalid_spawn_overrides"] = invalid_spawn_overrides

    return results


# =============================================================================
# Report Generation
# =============================================================================

def write_report(results: dict, names: dict[int, str], valid_count: int,
                 model_count: int, template_count: int, spawn_override_count: int):
    """Write the human-readable validation report."""

    lines = []
    lines.append("=" * 80)
    lines.append("CREATURE MODEL / DISPLAY ID VALIDATION REPORT")
    lines.append("=" * 80)
    lines.append("")
    lines.append("Data Sources:")
    lines.append(f"  CreatureDisplayInfo DB2:  {valid_count:,} valid display IDs")
    lines.append(f"  creature_template_model:  {model_count:,} rows")
    lines.append(f"  creature_template:        {template_count:,} entries")
    lines.append(f"  creature spawn overrides: {spawn_override_count:,} non-zero modelid rows")
    lines.append("")

    # Summary
    lines.append("-" * 80)
    lines.append("SUMMARY")
    lines.append("-" * 80)
    lines.append(f"  Invalid display IDs in creature_template_model:   "
                 f"{len(results['invalid_models']):,}")
    lines.append(f"  Zero display IDs in creature_template_model:      "
                 f"{len(results['zero_models']):,}")
    lines.append(f"  Duplicate Idx entries:                            "
                 f"{len(results['duplicate_idx']):,}")
    lines.append(f"  Missing models (spawned — HIGH priority):         "
                 f"{len(results['missing_spawned']):,}")
    lines.append(f"  Missing models (unspawned — low priority):        "
                 f"{len(results['missing_unspawned']):,}")
    lines.append(f"  Invalid per-spawn modelid overrides:              "
                 f"{len(results['invalid_spawn_overrides']):,}")
    lines.append("")

    # --- Section 1: Invalid Display IDs ---
    lines.append("-" * 80)
    lines.append("1. INVALID DISPLAY IDs IN creature_template_model")
    lines.append("   (DisplayID not found in CreatureDisplayInfo DB2)")
    lines.append("-" * 80)
    if results["invalid_models"]:
        lines.append(f"{'CreatureID':>12}  {'Idx':>4}  {'DisplayID':>12}  Name")
        lines.append(f"{'----------':>12}  {'---':>4}  {'---------':>12}  ----")
        for m in sorted(results["invalid_models"],
                        key=lambda x: (x["CreatureID"], x["Idx"])):
            name = names.get(m["CreatureID"], "<unknown>")
            lines.append(f"{m['CreatureID']:>12}  {m['Idx']:>4}  "
                         f"{m['DisplayID']:>12}  {name}")
    else:
        lines.append("  (none found)")
    lines.append("")

    # --- Section 2: Zero Display IDs ---
    lines.append("-" * 80)
    lines.append("2. ZERO DISPLAY IDs IN creature_template_model")
    lines.append("-" * 80)
    if results["zero_models"]:
        lines.append(f"{'CreatureID':>12}  {'Idx':>4}  {'DisplayID':>12}  Name")
        lines.append(f"{'----------':>12}  {'---':>4}  {'---------':>12}  ----")
        for m in sorted(results["zero_models"],
                        key=lambda x: (x["CreatureID"], x["Idx"])):
            name = names.get(m["CreatureID"], "<unknown>")
            lines.append(f"{m['CreatureID']:>12}  {m['Idx']:>4}  "
                         f"{m['DisplayID']:>12}  {name}")
    else:
        lines.append("  (none found)")
    lines.append("")

    # --- Section 3: Duplicate Idx ---
    lines.append("-" * 80)
    lines.append("3. DUPLICATE Idx ENTRIES (same CreatureID + Idx)")
    lines.append("-" * 80)
    if results["duplicate_idx"]:
        lines.append(f"{'CreatureID':>12}  {'Idx':>4}  {'Count':>6}  Name")
        lines.append(f"{'----------':>12}  {'---':>4}  {'-----':>6}  ----")
        for (cid, idx), count in sorted(results["duplicate_idx"].items()):
            name = names.get(cid, "<unknown>")
            lines.append(f"{cid:>12}  {idx:>4}  {count:>6}  {name}")
    else:
        lines.append("  (none found — Idx is part of the primary key)")
    lines.append("")

    # --- Section 4: Missing models (spawned = HIGH priority) ---
    lines.append("-" * 80)
    lines.append("4. MISSING MODELS — SPAWNED CREATURES (HIGH PRIORITY)")
    lines.append("   (creature_template entries with spawns but NO creature_template_model rows)")
    lines.append("   These creatures are INVISIBLE in-game!")
    lines.append("-" * 80)
    if results["missing_spawned"]:
        lines.append(f"{'Entry':>12}  Name")
        lines.append(f"{'-----':>12}  ----")
        for entry, name in results["missing_spawned"][:500]:
            lines.append(f"{entry:>12}  {name}")
        if len(results["missing_spawned"]) > 500:
            lines.append(f"  ... and {len(results['missing_spawned']) - 500:,} more")
    else:
        lines.append("  (none found)")
    lines.append("")

    # --- Section 5: Missing models (unspawned = low priority) ---
    lines.append("-" * 80)
    lines.append("5. MISSING MODELS — UNSPAWNED TEMPLATES (low priority)")
    lines.append("   (creature_template entries with NO spawns and NO models)")
    lines.append("-" * 80)
    if results["missing_unspawned"]:
        lines.append(f"  Total: {len(results['missing_unspawned']):,} entries")
        lines.append(f"  (First 200 shown)")
        lines.append(f"{'Entry':>12}  Name")
        lines.append(f"{'-----':>12}  ----")
        for entry, name in results["missing_unspawned"][:200]:
            lines.append(f"{entry:>12}  {name}")
        if len(results["missing_unspawned"]) > 200:
            lines.append(f"  ... and {len(results['missing_unspawned']) - 200:,} more")
    else:
        lines.append("  (none found)")
    lines.append("")

    # --- Section 6: Invalid per-spawn modelid overrides ---
    lines.append("-" * 80)
    lines.append("6. INVALID PER-SPAWN modelid OVERRIDES IN creature TABLE")
    lines.append("   (creature.modelid != 0 but not in CreatureDisplayInfo DB2)")
    lines.append("-" * 80)
    if results["invalid_spawn_overrides"]:
        lines.append(f"{'GUID':>12}  {'CreatureID':>12}  {'modelid':>12}  "
                     f"{'Map':>6}  {'Zone':>6}  Name")
        lines.append(f"{'----':>12}  {'----------':>12}  {'-------':>12}  "
                     f"{'---':>6}  {'----':>6}  ----")
        for s in sorted(results["invalid_spawn_overrides"],
                        key=lambda x: (x["CreatureID"], x["guid"])):
            name = names.get(s["CreatureID"], "<unknown>")
            lines.append(f"{s['guid']:>12}  {s['CreatureID']:>12}  "
                         f"{s['modelid']:>12}  {s['map']:>6}  "
                         f"{s['zone']:>6}  {name}")
    else:
        lines.append("  (none found)")
    lines.append("")

    lines.append("=" * 80)
    lines.append("END OF REPORT")
    lines.append("=" * 80)

    with open(REPORT_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Report written to: {REPORT_FILE}")


def write_sql(results: dict, names: dict[int, str]):
    """Write safe SQL fixes — only removals of clearly invalid data."""

    lines = []
    lines.append("-- ==========================================================================")
    lines.append("-- npc_model_fixes.sql — Auto-generated by validate_models.py")
    lines.append("-- Removes clearly invalid display IDs. Does NOT generate replacements.")
    lines.append("-- ==========================================================================")
    lines.append("")

    fix_count = 0

    # Fix 1: Remove creature_template_model rows with invalid (non-zero) DisplayIDs
    #         ONLY if the creature has other valid model rows (so we don't leave it empty)
    if results["invalid_models"]:
        # Group invalid models by CreatureID
        invalid_by_creature = defaultdict(list)
        for m in results["invalid_models"]:
            invalid_by_creature[m["CreatureID"]].append(m)

        # Also need to know which creatures have valid models
        # We'll query this separately
        creatures_with_invalid = set(invalid_by_creature.keys())

        lines.append("-- Section 1: Remove invalid display IDs from creature_template_model")
        lines.append("-- (only when the creature has at least one OTHER valid model row)")
        lines.append("")

        # We need to check which creatures have valid rows alongside invalid ones.
        # We can do this from the data we already have.
        # For safety, generate conditional DELETEs with comments.

        for cid in sorted(creatures_with_invalid):
            name = names.get(cid, "<unknown>")
            invalid_rows = invalid_by_creature[cid]
            invalid_idxs = {m["Idx"] for m in invalid_rows}

            # Check how many total model rows this creature has
            # (We could track this from data, but let's use a safe SQL pattern)
            for m in invalid_rows:
                lines.append(
                    f"-- Creature {cid} ({name}): Idx={m['Idx']} "
                    f"has invalid DisplayID={m['DisplayID']}"
                )
                lines.append(
                    f"DELETE FROM creature_template_model "
                    f"WHERE CreatureID={cid} AND Idx={m['Idx']} "
                    f"AND CreatureDisplayID={m['DisplayID']} "
                    f"AND (SELECT COUNT(*) FROM (SELECT 1 FROM creature_template_model "
                    f"WHERE CreatureID={cid} AND CreatureDisplayID != {m['DisplayID']}) t) > 0;"
                )
                lines.append("")
                fix_count += 1

    # Fix 2: Reset invalid per-spawn modelid overrides to 0 (use template default)
    if results["invalid_spawn_overrides"]:
        lines.append("")
        lines.append("-- Section 2: Reset invalid per-spawn modelid overrides to 0")
        lines.append("-- (reverts to creature_template_model default)")
        lines.append("")
        for s in sorted(results["invalid_spawn_overrides"],
                        key=lambda x: x["guid"]):
            name = names.get(s["CreatureID"], "<unknown>")
            lines.append(
                f"-- GUID {s['guid']}: creature {s['CreatureID']} ({name}) "
                f"has invalid modelid={s['modelid']}"
            )
            lines.append(
                f"UPDATE creature SET modelid=0 "
                f"WHERE guid={s['guid']} AND modelid={s['modelid']};"
            )
            lines.append("")
            fix_count += 1

    # Fix 3: Remove zero-DisplayID rows if the creature has other valid rows
    if results["zero_models"]:
        zero_by_creature = defaultdict(list)
        for m in results["zero_models"]:
            zero_by_creature[m["CreatureID"]].append(m)

        lines.append("")
        lines.append("-- Section 3: Remove zero-DisplayID rows from creature_template_model")
        lines.append("-- (only when the creature has at least one other non-zero model row)")
        lines.append("")

        for cid in sorted(zero_by_creature.keys()):
            name = names.get(cid, "<unknown>")
            for m in zero_by_creature[cid]:
                lines.append(
                    f"-- Creature {cid} ({name}): Idx={m['Idx']} has DisplayID=0"
                )
                lines.append(
                    f"DELETE FROM creature_template_model "
                    f"WHERE CreatureID={cid} AND Idx={m['Idx']} "
                    f"AND CreatureDisplayID=0 "
                    f"AND (SELECT COUNT(*) FROM (SELECT 1 FROM creature_template_model "
                    f"WHERE CreatureID={cid} AND CreatureDisplayID != 0) t) > 0;"
                )
                lines.append("")
                fix_count += 1

    if fix_count == 0:
        lines.append("-- No safe fixes to generate. All issues require manual review.")

    lines.append(f"-- Total fix statements: {fix_count}")

    with open(SQL_FILE, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")

    print(f"SQL fixes written to: {SQL_FILE} ({fix_count} statements)")


# =============================================================================
# Main
# =============================================================================

def main():
    print("Loading CreatureDisplayInfo DB2 CSV...")
    valid_ids = load_valid_display_ids()
    print(f"  {len(valid_ids):,} valid display IDs loaded")

    print("Querying creature_template_model...")
    models = get_template_models()
    print(f"  {len(models):,} model rows")

    print("Querying creature names...")
    names = get_creature_names()
    print(f"  {len(names):,} creature templates")

    print("Getting all creature_template entries...")
    all_entries = get_all_template_entries()
    print(f"  {len(all_entries):,} entries")

    print("Querying per-spawn model overrides...")
    spawn_overrides = get_spawn_model_overrides()
    print(f"  {len(spawn_overrides):,} non-zero overrides")

    print("Querying spawned creature IDs...")
    spawned_ids = get_spawned_creature_ids()
    print(f"  {len(spawned_ids):,} distinct spawned creatures")

    print("\nAnalyzing...")
    results = analyze(valid_ids, models, names, all_entries,
                      spawn_overrides, spawned_ids)

    print("\nResults:")
    print(f"  Invalid display IDs:          {len(results['invalid_models']):,}")
    print(f"  Zero display IDs:             {len(results['zero_models']):,}")
    print(f"  Duplicate Idx entries:         {len(results['duplicate_idx']):,}")
    print(f"  Missing models (spawned):      {len(results['missing_spawned']):,}")
    print(f"  Missing models (unspawned):    {len(results['missing_unspawned']):,}")
    print(f"  Invalid spawn overrides:       {len(results['invalid_spawn_overrides']):,}")

    print("\nWriting report...")
    write_report(results, names, len(valid_ids), len(models),
                 len(all_entries), len(spawn_overrides))

    print("Writing SQL fixes...")
    write_sql(results, names)

    print("\nDone.")


if __name__ == "__main__":
    main()

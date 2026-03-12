"""BestiaryForge x Wago DB2 Cross-Reference Tool.

Compares BestiaryForge export data against Wago SpellName DB2 CSV to:
- Validate observed spell IDs exist in retail data
- Flag custom/serverside spells (not in SpellName)
- Enrich spell entries with retail spell names
- Detect deprecated/removed spells

Usage:
    python wago_crossref.py <export_file> [--wago-dir path]
    python wago_crossref.py --saved-vars [--wago-dir path]
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path

DEFAULT_WAGO_DIR = Path(r"C:\Users\atayl\VoxCore\wago")
DEFAULT_SV_PATH = Path(r"C:\WoW\_retail_\WTF\Account\1#1\SavedVariables\BestiaryForge.lua")


def load_spell_names(wago_dir: Path) -> dict[int, str]:
    """Load SpellName.csv from wago directory."""
    spell_file = wago_dir / "SpellName.csv"
    if not spell_file.exists():
        print(f"ERROR: SpellName.csv not found at {spell_file}", file=sys.stderr)
        sys.exit(1)

    spells: dict[int, str] = {}
    with open(spell_file, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                spell_id = int(row.get("ID", 0))
                name = row.get("Name_lang", "")
                if spell_id > 0 and name:
                    spells[spell_id] = name
            except (ValueError, KeyError):
                continue
    return spells


def parse_raw_export(filepath: Path) -> dict[int, dict]:
    """Parse a BestiaryForge raw export (BFEXPORT:v3 format)."""
    creatures: dict[int, dict] = {}

    with open(filepath, "r", encoding="utf-8") as f:
        lines = f.readlines()

    if not lines or not lines[0].strip().startswith("BFEXPORT:"):
        print("ERROR: Not a valid BestiaryForge export file", file=sys.stderr)
        sys.exit(1)

    for line in lines[1:]:
        line = line.strip()
        if line == "END" or not line:
            continue

        parts = line.split("|")
        if not parts:
            continue

        # First part: entry:name
        header = parts[0].split(":", 1)
        if len(header) < 2:
            continue

        entry = int(header[0])
        name = header[1]
        spells = []

        for part in parts[1:]:
            fields = part.split(":", 3)
            if len(fields) >= 4:
                spells.append({
                    "id": int(fields[0]),
                    "count": int(fields[1]),
                    "school": int(fields[2]),
                    "name": fields[3],
                })

        creatures[entry] = {"name": name, "spells": spells}

    return creatures


def parse_saved_vars(sv_path: Path) -> dict[int, dict]:
    """Parse BestiaryForgeDB SavedVariables (minimal extraction)."""
    if not sv_path.exists():
        print(f"ERROR: SavedVariables not found: {sv_path}", file=sys.stderr)
        sys.exit(1)

    text = sv_path.read_text(encoding="utf-8", errors="replace")
    creatures: dict[int, dict] = {}

    # Simple regex-based extraction
    creature_re = re.compile(r'\[(\d+)\]\s*=\s*\{')
    name_re = re.compile(r'\["name"\]\s*=\s*"([^"]*)"')

    creatures_start = text.find('"creatures"')
    if creatures_start == -1:
        return creatures

    for cm in creature_re.finditer(text, creatures_start):
        entry_id = int(cm.group(1))
        if entry_id > 999999:
            continue

        block = text[cm.end():cm.end() + 5000]
        nm = name_re.search(block)
        creature_name = nm.group(1) if nm else "Unknown"

        spells_start = block.find('"spells"')
        if spells_start == -1:
            creatures[entry_id] = {"name": creature_name, "spells": []}
            continue

        spell_block = block[spells_start:]
        spell_entries = []
        for sm in creature_re.finditer(spell_block):
            sid = int(sm.group(1))
            if sid > 999999:
                break

            sblock = spell_block[sm.end():sm.end() + 500]
            snm = name_re.search(sblock)
            spell_name = snm.group(1) if snm else f"Spell {sid}"

            count_m = re.search(r'\["castCount"\]\s*=\s*(\d+)', sblock)
            cast_count = int(count_m.group(1)) if count_m else 0

            school_m = re.search(r'\["school"\]\s*=\s*(\d+)', sblock)
            school = int(school_m.group(1)) if school_m else 0

            spell_entries.append({
                "id": sid,
                "count": cast_count,
                "school": school,
                "name": spell_name,
            })

        creatures[entry_id] = {"name": creature_name, "spells": spell_entries}

    return creatures


def crossref(creatures: dict[int, dict], spell_names: dict[int, str]) -> None:
    """Cross-reference and print results."""
    total_spells = 0
    retail_confirmed = 0
    custom_spells = 0
    name_mismatches = []

    print("=" * 70)
    print("BestiaryForge x Wago DB2 Cross-Reference Report")
    print("=" * 70)
    print()

    for entry in sorted(creatures):
        creature = creatures[entry]
        if not creature["spells"]:
            continue

        issues = []
        for spell in creature["spells"]:
            total_spells += 1
            spell_id = spell["id"]
            observed_name = spell["name"]

            if spell_id in spell_names:
                retail_confirmed += 1
                retail_name = spell_names[spell_id]
                if retail_name.lower() != observed_name.lower() and observed_name != f"Spell {spell_id}":
                    name_mismatches.append((entry, spell_id, observed_name, retail_name))
                    issues.append(f"  MISMATCH [{spell_id}] observed=\"{observed_name}\" retail=\"{retail_name}\"")
            else:
                custom_spells += 1
                issues.append(f"  CUSTOM   [{spell_id}] {observed_name} -- not in retail SpellName DB2")

        if issues:
            print(f"{creature['name']} (entry {entry}):")
            for issue in issues:
                print(issue)
            print()

    print("-" * 70)
    print(f"Total creatures: {len(creatures)}")
    print(f"Total spells:    {total_spells}")
    print(f"Retail confirmed: {retail_confirmed} ({retail_confirmed * 100 // max(total_spells, 1)}%)")
    print(f"Custom/unknown:   {custom_spells}")
    print(f"Name mismatches:  {len(name_mismatches)}")


def main():
    parser = argparse.ArgumentParser(description="BestiaryForge x Wago cross-reference")
    parser.add_argument("export_file", nargs="?", help="Raw export file (BFEXPORT:v3)")
    parser.add_argument("--saved-vars", action="store_true", help="Read from SavedVariables instead")
    parser.add_argument("--wago-dir", type=Path, default=DEFAULT_WAGO_DIR, help="Wago CSV directory")
    parser.add_argument("--sv-path", type=Path, default=DEFAULT_SV_PATH, help="SavedVariables path")
    args = parser.parse_args()

    if not args.export_file and not args.saved_vars:
        parser.error("Provide an export file or use --saved-vars")

    print("Loading Wago SpellName DB2...")
    spell_names = load_spell_names(args.wago_dir)
    print(f"  Loaded {len(spell_names)} retail spells.")
    print()

    if args.saved_vars:
        print(f"Parsing SavedVariables: {args.sv_path}")
        creatures = parse_saved_vars(args.sv_path)
    else:
        print(f"Parsing export: {args.export_file}")
        creatures = parse_raw_export(Path(args.export_file))

    print(f"  Found {len(creatures)} creatures.")
    print()

    crossref(creatures, spell_names)


if __name__ == "__main__":
    main()

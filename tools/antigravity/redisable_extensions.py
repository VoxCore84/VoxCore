"""
redisable_extensions.py — Re-disable bundled extensions after Antigravity update.

Reads the disable manifest from otto_baseline.json and renames extension
directories that were restored by an update back to .disabled.

Usage:
    python redisable_extensions.py          # Check and fix
    python redisable_extensions.py --check  # Check only, no changes
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
HOME = Path(os.environ.get("USERPROFILE", r"C:\Users\atayl"))
BUNDLED_EXT_DIR = (
    HOME / "AppData" / "Local" / "Programs" / "Antigravity"
    / "resources" / "app" / "extensions"
)
BASELINE_FILE = Path(__file__).parent / "otto_baseline.json"


def log(msg: str) -> None:
    """Log to stderr so stdout stays clean for piping."""
    print(msg, file=sys.stderr)


def load_manifest() -> list[str]:
    """Load the disabled_extensions list from otto_baseline.json."""
    if not BASELINE_FILE.exists():
        log(f"ERROR: Baseline file not found: {BASELINE_FILE}")
        sys.exit(2)

    try:
        with open(BASELINE_FILE, "r", encoding="utf-8") as f:
            baseline = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        log(f"ERROR: Cannot read baseline file: {e}")
        sys.exit(2)

    extensions = baseline.get("disabled_extensions", [])
    if not extensions:
        log("WARNING: disabled_extensions list is empty in baseline")
    return extensions


def scan_extensions(
    manifest: list[str], check_only: bool = False
) -> tuple[list[str], list[str], list[str], list[str]]:
    """Scan extensions dir against manifest.

    Returns:
        (fixed, already_disabled, already_missing, failed)
        - fixed: extensions that were re-disabled (renamed to .disabled)
        - already_disabled: extensions that are already .disabled
        - already_missing: extensions not found at all (neither enabled nor disabled)
        - failed: extensions that could not be renamed (permission errors, etc.)
    """
    fixed: list[str] = []
    already_disabled: list[str] = []
    already_missing: list[str] = []
    failed: list[str] = []

    if not BUNDLED_EXT_DIR.exists():
        log(f"ERROR: Extensions directory not found: {BUNDLED_EXT_DIR}")
        sys.exit(2)

    for name in manifest:
        enabled_path = BUNDLED_EXT_DIR / name
        disabled_path = BUNDLED_EXT_DIR / f"{name}.disabled"

        if disabled_path.exists():
            already_disabled.append(name)
        elif enabled_path.exists():
            if check_only:
                # In check mode, report it as needing fix but don't touch it
                fixed.append(name)
            else:
                try:
                    enabled_path.rename(disabled_path)
                    fixed.append(name)
                except PermissionError:
                    failed.append(f"{name} (PermissionError — Antigravity may have files locked)")
                except OSError as e:
                    failed.append(f"{name} ({e})")
        else:
            already_missing.append(name)

    return fixed, already_disabled, already_missing, failed


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Re-disable bundled Antigravity extensions after update"
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Check only — report what would be fixed without making changes",
    )
    args = parser.parse_args()

    manifest = load_manifest()
    log(f"Loaded {len(manifest)} extensions from manifest")
    log(f"Scanning: {BUNDLED_EXT_DIR}")
    log("")

    fixed, already_disabled, already_missing, failed = scan_extensions(
        manifest, check_only=args.check
    )

    # --- Report ---
    if args.check:
        action_word = "NEED DISABLING"
    else:
        action_word = "RE-DISABLED"

    if fixed:
        log(f"  [{action_word}] ({len(fixed)}):")
        for name in sorted(fixed):
            log(f"    - {name}")
        log("")

    if already_disabled:
        log(f"  [ALREADY DISABLED] ({len(already_disabled)}):")
        for name in sorted(already_disabled):
            log(f"    - {name}")
        log("")

    if already_missing:
        log(f"  [NOT FOUND] ({len(already_missing)}):")
        for name in sorted(already_missing):
            log(f"    - {name}")
        log("")

    if failed:
        log(f"  [FAILED] ({len(failed)}):")
        for entry in failed:
            log(f"    - {entry}")
        log("")

    # --- Summary ---
    total = len(manifest)
    log(f"Summary: {len(already_disabled)}/{total} already disabled, "
        f"{len(fixed)} {'need fix' if args.check else 'fixed'}, "
        f"{len(already_missing)} not found, {len(failed)} failed")

    if fixed or failed:
        return 1  # Something was fixed or couldn't be fixed
    return 0  # No action needed — everything already correct


if __name__ == "__main__":
    sys.exit(main())

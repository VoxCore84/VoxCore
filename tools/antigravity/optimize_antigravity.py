"""
optimize_antigravity.py — Antigravity (Gemini IDE) performance optimizer for VoxCore

Verifies permission settings, cleans notification/chat bloat, vacuums state DBs,
prunes old logs, and verifies extension registry integrity.

Usage:
    python optimize_antigravity.py          # Full optimization pass
    python optimize_antigravity.py --quick  # Quick health check (no vacuums)
    python optimize_antigravity.py --fix    # Fix issues found (auto-patch permissions)

Requires: Python 3.10+ (uses match/case, |-union types)
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import shutil
import sqlite3
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
HOME = Path(os.environ.get("USERPROFILE", r"C:\Users\atayl"))
AG_DATA = HOME / "AppData" / "Roaming" / "Antigravity"
AG_USER = AG_DATA / "User"
AG_LOGS = AG_DATA / "logs"
AG_EXTENSIONS = HOME / ".antigravity" / "extensions"

GLOBAL_STATE_DB = AG_USER / "globalStorage" / "state.vscdb"
WORKSPACE_STATE_DB = (
    AG_USER
    / "workspaceStorage"
    / "29ea68fc3b3d69dba9758beec734ef8c"
    / "state.vscdb"
)
SETTINGS_JSON = AG_USER / "settings.json"

# ---------------------------------------------------------------------------
# Permission constants (reverse-engineered from Antigravity source)
# ---------------------------------------------------------------------------
# Terminal enum (Jd): OFF=1, AUTO=2, EAGER=3  (3 is max, NOT 4!)
# Artifact enum (C0): ALWAYS=1, TURBO=2, AUTO=3
# Planning enum (RI): UNSPECIFIED=0, OFF=1, ON=2
# Boolean settings use protobuf field1 varint: [8, 1] = true
#
# Protobuf structure in agentPreferences blob:
#   \n<len>\n<keylen><key>\x12\x06\n\x04<base64-of-protobuf-varint>

TERMINAL_EAGER_VALUE = 3   # EAGER = always auto-execute (max for terminal)
ARTIFACT_TURBO_VALUE = 2   # TURBO = auto-apply artifacts
PLANNING_OFF_VALUE = 1     # OFF = skip planning phase

# Pre-built agentPreferences protobuf blob with all 5 settings optimized.
# EAM= = [16,3] = terminal EAGER(3)
# EAI= = [16,2] = artifact TURBO(2)
# EAE= = [16,1] = planning OFF(1)
# CAE= = [8,1]  = boolean true (non-workspace access + gitignore access)
OPTIMAL_AGENT_PREFS_B64 = (
    "CjAKJnRlcm1pbmFsQXV0b0V4ZWN1dGlvblBvbGljeVNlbnRpbmVsS2V5EgYKBEVBTT0"
    "KKQofYXJ0aWZhY3RSZXZpZXdQb2xpY3lTZW50aW5lbEtleRIGCgRFQUk9"
    "CiEKF3BsYW5uaW5nTW9kZVNlbnRpbmVsS2V5EgYKBEVBRT0"
    "KNgosYWxsb3dBZ2VudEFjY2Vzc05vbldvcmtzcGFjZUZpbGVzU2VudGluZWxLZXkSBgoEQ0FFPQo1"
    "CithbGxvd0Nhc2NhZGVBY2Nlc3NHaXRpZ25vcmVGaWxlc1NlbnRpbmVsS2V5EgYKBENBRT0="
)


# ---------------------------------------------------------------------------
# Result tracking
# ---------------------------------------------------------------------------
@dataclass
class CheckResult:
    name: str
    status: str  # "OK", "WARN", "FIXED", "ERROR", "SKIP"
    detail: str = ""


@dataclass
class Report:
    results: list[CheckResult] = field(default_factory=list)

    def add(self, name: str, status: str, detail: str = "") -> None:
        self.results.append(CheckResult(name, status, detail))

    def print_report(self) -> None:
        print()
        print("=" * 60)
        print("  Antigravity Optimization Report")
        print("=" * 60)
        print()
        max_name = max((len(r.name) for r in self.results), default=20)
        for r in self.results:
            icon = {"OK": "[OK]", "WARN": "[!!]", "FIXED": "[FX]", "ERROR": "[ER]", "SKIP": "[--]"}.get(
                r.status, "[??]"
            )
            line = f"  {icon} {r.name:<{max_name}}  {r.detail}"
            print(line)
        print()
        counts = {}
        for r in self.results:
            counts[r.status] = counts.get(r.status, 0) + 1
        parts = []
        for s in ["OK", "FIXED", "WARN", "ERROR", "SKIP"]:
            if s in counts:
                parts.append(f"{counts[s]} {s}")
        print(f"  Summary: {', '.join(parts)}")
        print("=" * 60)
        print()

    @property
    def has_errors(self) -> bool:
        return any(r.status == "ERROR" for r in self.results)


# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------
def open_db(path: Path) -> sqlite3.Connection | None:
    """Open a SQLite DB, return None if file doesn't exist."""
    if not path.exists():
        return None
    return sqlite3.connect(str(path))


def get_key(conn: sqlite3.Connection, key: str) -> str | None:
    """Get a value from the ItemTable."""
    row = conn.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
    return row[0] if row else None


def set_key(conn: sqlite3.Connection, key: str, value: str) -> None:
    """Set a value in the ItemTable (upsert)."""
    conn.execute(
        "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
        (key, value),
    )
    conn.commit()


def db_size_kb(path: Path) -> float:
    """Return file size in KB."""
    if path.exists():
        return path.stat().st_size / 1024
    return 0.0


# ---------------------------------------------------------------------------
# Check: Permission policies
# ---------------------------------------------------------------------------
def decode_policy_value(sentinel_b64: str) -> int | None:
    """Decode a protobuf varint from base64 sentinel value.

    The sentinel is stored as base64-encoded protobuf.
    Format: field tag (0x10 = field 2 varint) + varint value.
    """
    try:
        data = base64.b64decode(sentinel_b64)
        if len(data) >= 2 and data[0] == 0x10:
            return data[1]
    except Exception:
        pass
    return None


def check_permissions(report: Report, fix: bool = False) -> None:
    """Verify terminal and artifact policies are at TURBO."""
    conn = open_db(GLOBAL_STATE_DB)
    if conn is None:
        report.add("Permissions", "ERROR", f"State DB not found: {GLOBAL_STATE_DB}")
        return

    try:
        raw = get_key(conn, "antigravityUnifiedStateSync.agentPreferences")
        if raw is None:
            report.add("Permissions", "WARN", "agentPreferences key not found in state DB")
            if fix:
                set_key(conn, "antigravityUnifiedStateSync.agentPreferences", OPTIMAL_AGENT_PREFS_B64)
                report.add("Permissions (fix)", "FIXED", "Wrote TURBO agent preferences")
            return

        # The DB stores a base64 string that wraps a protobuf blob.
        # Decode the outer base64 layer to get the raw protobuf.
        try:
            proto_bytes = base64.b64decode(raw)
        except Exception:
            report.add("Permissions", "ERROR", "agentPreferences is not valid base64")
            return

        # Check all 5 sentinel keys with correct values
        all_ok = True
        numeric_checks = {
            b"terminalAutoExecutionPolicySentinelKey": (TERMINAL_EAGER_VALUE, "Terminal Policy"),
            b"artifactReviewPolicySentinelKey": (ARTIFACT_TURBO_VALUE, "Artifact Policy"),
            b"planningModeSentinelKey": (PLANNING_OFF_VALUE, "Planning Mode"),
        }
        for sentinel_key, (expected_val, label) in numeric_checks.items():
            if sentinel_key not in proto_bytes:
                report.add(label, "WARN", "Sentinel key missing from agentPreferences")
                all_ok = False
                continue
            idx = proto_bytes.index(sentinel_key) + len(sentinel_key)
            remaining = proto_bytes[idx:]
            b64_start = remaining.find(b"\x12\x06\n\x04")
            if b64_start >= 0:
                b64_val = remaining[b64_start + 4 : b64_start + 8].decode("ascii", errors="replace")
                policy_val = decode_policy_value(b64_val)
                if policy_val == expected_val:
                    report.add(label, "OK", f"Optimal (value={policy_val})")
                else:
                    report.add(label, "WARN", f"NOT optimal (value={policy_val}, expected {expected_val})")
                    all_ok = False

        # Check boolean sentinel keys
        bool_checks = {
            b"allowAgentAccessNonWorkspaceFilesSentinelKey": "Non-Workspace Access",
            b"allowCascadeAccessGitignoreFilesSentinelKey": "Gitignore Access",
        }
        for sentinel_key, label in bool_checks.items():
            if sentinel_key in proto_bytes:
                report.add(label, "OK", "Enabled")
            else:
                report.add(label, "WARN", "Not set (default=false)")
                all_ok = False

        # Fix if needed
        if fix and not all_ok:
            set_key(
                conn,
                "antigravityUnifiedStateSync.agentPreferences",
                OPTIMAL_AGENT_PREFS_B64,
            )
            report.add("Permission Fix", "FIXED", "Wrote all 5 optimal settings to agentPreferences")

    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Check: Notification bloat
# ---------------------------------------------------------------------------
def check_notifications(report: Report, fix: bool = False) -> None:
    """Check and clean notification accumulation."""
    conn = open_db(GLOBAL_STATE_DB)
    if conn is None:
        report.add("Notifications", "SKIP", "State DB not found")
        return

    try:
        raw = get_key(conn, "notifications.perSourceDoNotDisturbMode")
        if raw is None:
            report.add("Notifications", "OK", "No notification data (clean)")
            return

        try:
            data = json.loads(raw)
            count = len(data) if isinstance(data, (list, dict)) else 0
        except json.JSONDecodeError:
            count = 0
            report.add("Notifications", "WARN", f"Malformed JSON ({len(raw)} bytes)")
            return

        if count > 50:
            report.add("Notifications", "WARN", f"{count} entries (threshold: 50)")
            if fix:
                # Keep only entries with filter != 0 (user-configured DND)
                if isinstance(data, list):
                    cleaned = [e for e in data if isinstance(e, dict) and e.get("filter", 0) != 0]
                    set_key(conn, "notifications.perSourceDoNotDisturbMode", json.dumps(cleaned))
                    report.add("Notification Fix", "FIXED", f"Cleaned {count - len(cleaned)} entries")
        else:
            report.add("Notifications", "OK", f"{count} entries (under threshold)")

        # Also check chat session bloat in both DBs
        for db_name, db_path in [("Global", GLOBAL_STATE_DB), ("Workspace", WORKSPACE_STATE_DB)]:
            db = open_db(db_path)
            if db is None:
                continue
            try:
                chat_raw = get_key(db, "chat.ChatSessionStore.index")
                if chat_raw:
                    try:
                        chat_data = json.loads(chat_raw)
                        if isinstance(chat_data, dict):
                            session_count = len(chat_data)
                        elif isinstance(chat_data, list):
                            session_count = len(chat_data)
                        else:
                            session_count = 0
                        size_kb = len(chat_raw) / 1024
                        if size_kb > 500:
                            report.add(
                                f"Chat Sessions ({db_name})",
                                "WARN",
                                f"{session_count} sessions, {size_kb:.1f} KB (bloated)",
                            )
                        else:
                            report.add(
                                f"Chat Sessions ({db_name})",
                                "OK",
                                f"{session_count} sessions, {size_kb:.1f} KB",
                            )
                    except json.JSONDecodeError:
                        report.add(f"Chat Sessions ({db_name})", "OK", "No parseable data")
            finally:
                db.close()

    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Check: VACUUM state databases
# ---------------------------------------------------------------------------
def vacuum_databases(report: Report, skip: bool = False) -> None:
    """VACUUM both state databases to reclaim space."""
    dbs = [
        ("Global State DB", GLOBAL_STATE_DB),
        ("Workspace State DB", WORKSPACE_STATE_DB),
    ]

    for name, path in dbs:
        if not path.exists():
            report.add(f"VACUUM {name}", "SKIP", "File not found")
            continue

        size_before = db_size_kb(path)

        if skip:
            report.add(f"VACUUM {name}", "SKIP", f"{size_before:.1f} KB (--quick mode)")
            continue

        try:
            conn = sqlite3.connect(str(path))
            conn.execute("VACUUM")
            conn.close()
            size_after = db_size_kb(path)
            saved = size_before - size_after
            if saved > 1:
                report.add(
                    f"VACUUM {name}",
                    "FIXED",
                    f"{size_before:.1f} KB -> {size_after:.1f} KB (saved {saved:.1f} KB)",
                )
            else:
                report.add(f"VACUUM {name}", "OK", f"{size_after:.1f} KB (already compact)")
        except sqlite3.OperationalError as e:
            if "database is locked" in str(e):
                report.add(
                    f"VACUUM {name}",
                    "WARN",
                    f"Database locked (Antigravity running?) — {size_before:.1f} KB",
                )
            else:
                report.add(f"VACUUM {name}", "ERROR", str(e))


# ---------------------------------------------------------------------------
# Check: Log cleanup
# ---------------------------------------------------------------------------
def clean_logs(report: Report, keep: int = 2, skip: bool = False) -> None:
    """Remove old log directories, keeping the most recent N."""
    if not AG_LOGS.exists():
        report.add("Log Cleanup", "SKIP", f"Log directory not found: {AG_LOGS}")
        return

    # Log directories are named like 20260311T181003 (ISO-ish timestamps)
    log_dirs = sorted(
        [d for d in AG_LOGS.iterdir() if d.is_dir() and d.name[0].isdigit()],
        key=lambda d: d.name,
        reverse=True,
    )

    if len(log_dirs) <= keep:
        report.add("Log Cleanup", "OK", f"{len(log_dirs)} log dirs (keeping all, threshold={keep})")
        return

    if skip:
        report.add(
            "Log Cleanup",
            "SKIP",
            f"{len(log_dirs)} log dirs, {len(log_dirs) - keep} removable (--quick mode)",
        )
        return

    to_remove = log_dirs[keep:]
    removed = 0
    total_freed = 0

    for d in to_remove:
        try:
            dir_size = sum(f.stat().st_size for f in d.rglob("*") if f.is_file())
            shutil.rmtree(str(d))
            removed += 1
            total_freed += dir_size
        except (PermissionError, OSError) as e:
            report.add("Log Cleanup", "WARN", f"Could not remove {d.name}: {e}")

    if removed > 0:
        report.add(
            "Log Cleanup",
            "FIXED",
            f"Removed {removed} old log dirs ({total_freed / 1024:.1f} KB freed), kept latest {keep}",
        )
    else:
        report.add("Log Cleanup", "OK", "No removable log directories")


# ---------------------------------------------------------------------------
# Check: Extensions registry vs disk
# ---------------------------------------------------------------------------
def check_extensions(report: Report) -> None:
    """Verify extensions.json matches what's actually on disk."""
    ext_json = AG_EXTENSIONS / "extensions.json"
    if not ext_json.exists():
        report.add("Extensions", "SKIP", f"extensions.json not found at {ext_json}")
        return

    try:
        with open(ext_json, "r", encoding="utf-8") as f:
            registry = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        report.add("Extensions", "ERROR", f"Cannot read extensions.json: {e}")
        return

    # Get registered extension directory names
    registered = set()
    for ext in registry:
        rel = ext.get("relativeLocation", "")
        if rel:
            registered.add(rel)

    # Get actual directories on disk (excluding extensions.json itself)
    on_disk = set()
    for item in AG_EXTENSIONS.iterdir():
        if item.is_dir():
            on_disk.add(item.name)

    # Compare
    orphaned = on_disk - registered
    missing = registered - on_disk

    issues = []
    if orphaned:
        issues.append(f"{len(orphaned)} orphaned dirs: {', '.join(sorted(orphaned))}")
    if missing:
        issues.append(f"{len(missing)} missing dirs: {', '.join(sorted(missing))}")

    if issues:
        report.add("Extensions", "WARN", "; ".join(issues))
    else:
        report.add("Extensions", "OK", f"{len(registered)} registered, all present on disk")


# ---------------------------------------------------------------------------
# Check: Settings.json performance keys
# ---------------------------------------------------------------------------
def check_settings(report: Report) -> None:
    """Verify critical performance settings in settings.json."""
    if not SETTINGS_JSON.exists():
        report.add("Settings", "SKIP", "settings.json not found")
        return

    try:
        with open(SETTINGS_JSON, "r", encoding="utf-8") as f:
            settings = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        report.add("Settings", "ERROR", f"Cannot read settings.json: {e}")
        return

    # Check critical performance settings
    checks = {
        "telemetry.telemetryLevel": ("off", "Telemetry should be off"),
        "extensions.autoUpdate": (False, "Auto-update burns CPU"),
        "extensions.autoCheckUpdates": (False, "Update checks burn network"),
        "editor.minimap.enabled": (False, "Minimap wastes rendering"),
        "search.followSymlinks": (False, "Symlink following causes hangs on VoxCore"),
        "workbench.startupEditor": ("none", "No startup editor = faster launch"),
        "workbench.enableExperiments": (False, "Experiments add overhead"),
    }

    issues = []
    for key, (expected, reason) in checks.items():
        actual = settings.get(key)
        if actual != expected:
            issues.append(f"{key}={actual} (want {expected}: {reason})")

    # Check file watcher excludes
    watcher = settings.get("files.watcherExclude", {})
    critical_excludes = ["**/out/build/**", "**/ExtTools/**", "**/wago/tact_csv/**"]
    missing_excludes = [e for e in critical_excludes if e not in watcher]

    if missing_excludes:
        issues.append(f"Missing watcher excludes: {', '.join(missing_excludes)}")

    if issues:
        for issue in issues:
            report.add("Settings", "WARN", issue)
    else:
        report.add("Settings", "OK", "All performance settings verified")


# ---------------------------------------------------------------------------
# Check: State DB total sizes
# ---------------------------------------------------------------------------
def check_db_sizes(report: Report) -> None:
    """Report state DB sizes for awareness."""
    dbs = [
        ("Global State DB", GLOBAL_STATE_DB),
        ("Workspace State DB", WORKSPACE_STATE_DB),
    ]
    for name, path in dbs:
        if path.exists():
            size = db_size_kb(path)
            status = "WARN" if size > 5000 else "OK"
            report.add(f"DB Size: {name}", status, f"{size:.1f} KB")
        else:
            report.add(f"DB Size: {name}", "SKIP", "Not found")


# ---------------------------------------------------------------------------
# Check: Workspace storage orphans
# ---------------------------------------------------------------------------
def check_workspace_orphans(report: Report) -> None:
    """Check for orphaned workspace storage directories."""
    ws_root = AG_USER / "workspaceStorage"
    if not ws_root.exists():
        report.add("Workspace Orphans", "SKIP", "workspaceStorage not found")
        return

    dirs = [d for d in ws_root.iterdir() if d.is_dir()]
    # We know 29ea68fc... is VoxCore — count the rest
    known = {"29ea68fc3b3d69dba9758beec734ef8c"}
    unknown = [d for d in dirs if d.name not in known]

    total_size = 0
    for d in unknown:
        for f in d.rglob("*"):
            if f.is_file():
                total_size += f.stat().st_size

    if unknown:
        report.add(
            "Workspace Orphans",
            "WARN" if total_size > 1024 * 1024 else "OK",
            f"{len(unknown)} other workspaces ({total_size / 1024:.1f} KB) — review if unneeded",
        )
    else:
        report.add("Workspace Orphans", "OK", "Only VoxCore workspace present")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(description="Antigravity performance optimizer for VoxCore")
    parser.add_argument("--quick", action="store_true", help="Quick health check (skip vacuums and log cleanup)")
    parser.add_argument("--fix", action="store_true", help="Auto-fix issues found (patch permissions, clean bloat)")
    args = parser.parse_args()

    report = Report()

    print("Antigravity Optimizer — scanning...")
    print()

    # 1. Permissions (always check, fix if --fix)
    check_permissions(report, fix=args.fix)

    # 2. Notifications
    check_notifications(report, fix=args.fix)

    # 3. VACUUM (skip in --quick mode)
    vacuum_databases(report, skip=args.quick)

    # 4. Log cleanup (skip in --quick mode)
    clean_logs(report, keep=2, skip=args.quick)

    # 5. Extensions
    check_extensions(report)

    # 6. Settings
    check_settings(report)

    # 7. DB sizes
    check_db_sizes(report)

    # 8. Workspace orphans
    check_workspace_orphans(report)

    report.print_report()

    return 1 if report.has_errors else 0


if __name__ == "__main__":
    sys.exit(main())

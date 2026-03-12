"""
OTTO MCP Server — Antigravity optimization health monitor.

Exposes 4 MCP tools: otto_health_check, otto_fix_regressions,
otto_get_baseline, otto_update_baseline.

Monitors IDE settings, argv flags, disabled extensions, DB permissions,
and journal mode against a known-good baseline (otto_baseline.json).

Usage (MCP stdio transport):
    python otto_mcp_server.py
"""

from __future__ import annotations

import base64
import json
import os
import sqlite3
import sys
from datetime import date
from pathlib import Path

# Force UTF-8 for stdio — MCP clients expect UTF-8, but Windows defaults to cp1252
if sys.platform == "win32":
    sys.stdin.reconfigure(encoding="utf-8")
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

from fastmcp import FastMCP

# ---------------------------------------------------------------------------
# Paths (hardcoded for this machine — same as optimize_antigravity.py)
# ---------------------------------------------------------------------------
HOME = Path(os.environ.get("USERPROFILE", r"C:\Users\atayl"))
GLOBAL_STATE_DB = HOME / "AppData" / "Roaming" / "Antigravity" / "User" / "globalStorage" / "state.vscdb"
SETTINGS_JSON = HOME / "AppData" / "Roaming" / "Antigravity" / "User" / "settings.json"
ARGV_JSON = HOME / ".antigravity" / "argv.json"
BUNDLED_EXT_DIR = HOME / "AppData" / "Local" / "Programs" / "Antigravity" / "resources" / "app" / "extensions"
BASELINE_FILE = Path(__file__).parent / "otto_baseline.json"

# Optimal agentPreferences protobuf blob (base64)
OPTIMAL_AGENT_PREFS_B64 = (
    "CjAKJnRlcm1pbmFsQXV0b0V4ZWN1dGlvblBvbGljeVNlbnRpbmVsS2V5EgYKBEVBTT0"
    "KKQofYXJ0aWZhY3RSZXZpZXdQb2xpY3lTZW50aW5lbEtleRIGCgRFQUk9"
    "CiEKF3BsYW5uaW5nTW9kZVNlbnRpbmVsS2V5EgYKBEVBRT0"
    "KNgosYWxsb3dBZ2VudEFjY2Vzc05vbldvcmtzcGFjZUZpbGVzU2VudGluZWxLZXkSBgoEQ0FFPQo1"
    "CithbGxvd0Nhc2NhZGVBY2Nlc3NHaXRpZ25vcmVGaWxlc1NlbnRpbmVsS2V5EgYKBENBRT0="
)


def _log(msg: str) -> None:
    """Log to stderr (stdout is reserved for MCP protocol)."""
    print(f"[otto] {msg}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Baseline helpers
# ---------------------------------------------------------------------------
def _load_baseline() -> dict:
    """Load otto_baseline.json. Raises FileNotFoundError if missing."""
    if not BASELINE_FILE.exists():
        raise FileNotFoundError(f"Baseline not found: {BASELINE_FILE}")
    with open(BASELINE_FILE, "r", encoding="utf-8") as f:
        return json.load(f)


def _save_baseline(data: dict) -> None:
    """Write otto_baseline.json atomically."""
    tmp = BASELINE_FILE.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    tmp.replace(BASELINE_FILE)


# ---------------------------------------------------------------------------
# DB helpers (same pattern as optimize_antigravity.py)
# ---------------------------------------------------------------------------
def _open_db(path: Path) -> sqlite3.Connection | None:
    """Open a SQLite DB, return None if file doesn't exist."""
    if not path.exists():
        return None
    return sqlite3.connect(str(path))


def _get_key(conn: sqlite3.Connection, key: str) -> str | None:
    """Get a value from the ItemTable."""
    row = conn.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
    return row[0] if row else None


def _set_key(conn: sqlite3.Connection, key: str, value: str) -> None:
    """Upsert a value in the ItemTable."""
    conn.execute(
        "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
        (key, value),
    )
    conn.commit()


# ---------------------------------------------------------------------------
# Check: settings.json
# ---------------------------------------------------------------------------
def _check_settings(baseline: dict) -> list[dict]:
    """Compare settings.json against baseline critical keys."""
    results = []
    critical = baseline.get("settings_critical", {})

    if not SETTINGS_JSON.exists():
        results.append({
            "name": "settings.json",
            "status": "ERROR",
            "detail": f"File not found: {SETTINGS_JSON}",
        })
        return results

    try:
        with open(SETTINGS_JSON, "r", encoding="utf-8") as f:
            settings = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        results.append({
            "name": "settings.json",
            "status": "ERROR",
            "detail": f"Cannot read: {e}",
        })
        return results

    mismatches = []
    for key, expected in critical.items():
        actual = settings.get(key)
        if actual != expected:
            mismatches.append(f"{key}: got {actual!r}, want {expected!r}")

    if mismatches:
        results.append({
            "name": "settings.json",
            "status": "WARN",
            "detail": f"{len(mismatches)} mismatches: " + "; ".join(mismatches),
        })
    else:
        results.append({
            "name": "settings.json",
            "status": "OK",
            "detail": f"All {len(critical)} critical keys match baseline",
        })

    return results


# ---------------------------------------------------------------------------
# Check: argv.json
# ---------------------------------------------------------------------------
def _check_argv(baseline: dict) -> list[dict]:
    """Compare argv.json against baseline critical keys and js-flags."""
    results = []
    critical = baseline.get("argv_critical", {})
    required_flags = baseline.get("argv_js_flags_required", [])

    if not ARGV_JSON.exists():
        results.append({
            "name": "argv.json",
            "status": "ERROR",
            "detail": f"File not found: {ARGV_JSON}",
        })
        return results

    try:
        with open(ARGV_JSON, "r", encoding="utf-8") as f:
            argv = json.load(f)
    except (json.JSONDecodeError, OSError) as e:
        results.append({
            "name": "argv.json",
            "status": "ERROR",
            "detail": f"Cannot read: {e}",
        })
        return results

    # Check critical keys
    key_mismatches = []
    for key, expected in critical.items():
        actual = argv.get(key)
        if actual != expected:
            key_mismatches.append(f"{key}: got {actual!r}, want {expected!r}")

    if key_mismatches:
        results.append({
            "name": "argv.json keys",
            "status": "WARN",
            "detail": "; ".join(key_mismatches),
        })
    else:
        results.append({
            "name": "argv.json keys",
            "status": "OK",
            "detail": f"All {len(critical)} critical keys match",
        })

    # Check js-flags
    js_flags_str = argv.get("js-flags", "")
    missing_flags = [f for f in required_flags if f not in js_flags_str]

    if missing_flags:
        results.append({
            "name": "argv.json js-flags",
            "status": "WARN",
            "detail": f"Missing flags: {', '.join(missing_flags)}",
        })
    else:
        results.append({
            "name": "argv.json js-flags",
            "status": "OK",
            "detail": f"All {len(required_flags)} required flags present",
        })

    return results


# ---------------------------------------------------------------------------
# Check: disabled extensions
# ---------------------------------------------------------------------------
def _check_extensions(baseline: dict) -> list[dict]:
    """Check disabled extension manifest against disk state."""
    results = []
    manifest = baseline.get("disabled_extensions", [])

    if not BUNDLED_EXT_DIR.exists():
        results.append({
            "name": "disabled_extensions",
            "status": "ERROR",
            "detail": f"Extensions directory not found: {BUNDLED_EXT_DIR}",
        })
        return results

    re_enabled = []
    still_disabled = []
    not_found = []

    for name in manifest:
        enabled_path = BUNDLED_EXT_DIR / name
        disabled_path = BUNDLED_EXT_DIR / f"{name}.disabled"

        if disabled_path.exists():
            still_disabled.append(name)
        elif enabled_path.exists():
            re_enabled.append(name)
        else:
            not_found.append(name)

    if re_enabled:
        results.append({
            "name": "disabled_extensions",
            "status": "WARN",
            "detail": (
                f"{len(re_enabled)} extensions re-enabled by update: "
                + ", ".join(re_enabled)
            ),
        })
    else:
        results.append({
            "name": "disabled_extensions",
            "status": "OK",
            "detail": f"{len(still_disabled)}/{len(manifest)} still disabled, {len(not_found)} not found on disk",
        })

    return results


# ---------------------------------------------------------------------------
# Check: DB permissions (agentPreferences protobuf blob)
# ---------------------------------------------------------------------------
def _decode_policy_value(sentinel_b64: str) -> int | None:
    """Decode a protobuf varint from base64 sentinel value."""
    try:
        data = base64.b64decode(sentinel_b64)
        if len(data) >= 2 and data[0] == 0x10:
            return data[1]
    except Exception:
        pass
    return None


# Expected values for numeric sentinel keys
_POLICY_EXPECTED = {
    b"terminalAutoExecutionPolicySentinelKey": (3, "Terminal EAGER(3)"),
    b"artifactReviewPolicySentinelKey": (2, "Artifact TURBO(2)"),
    b"planningModeSentinelKey": (1, "Planning OFF(1)"),
}

# Boolean sentinel keys (just need to be present)
_BOOL_SENTINELS = {
    b"allowAgentAccessNonWorkspaceFilesSentinelKey": "Non-Workspace Access",
    b"allowCascadeAccessGitignoreFilesSentinelKey": "Gitignore Access",
}


def _check_db_permissions(baseline: dict) -> list[dict]:
    """Check agentPreferences blob in state.vscdb against baseline."""
    results = []

    conn = _open_db(GLOBAL_STATE_DB)
    if conn is None:
        results.append({
            "name": "db_permissions",
            "status": "ERROR",
            "detail": f"State DB not found: {GLOBAL_STATE_DB}",
        })
        return results

    try:
        raw = _get_key(conn, "antigravityUnifiedStateSync.agentPreferences")
        if raw is None:
            results.append({
                "name": "db_permissions",
                "status": "WARN",
                "detail": "agentPreferences key not found in state DB",
            })
            return results

        try:
            proto_bytes = base64.b64decode(raw)
        except Exception:
            results.append({
                "name": "db_permissions",
                "status": "ERROR",
                "detail": "agentPreferences is not valid base64",
            })
            return results

        all_ok = True

        # Numeric sentinel checks
        for sentinel_key, (expected_val, label) in _POLICY_EXPECTED.items():
            if sentinel_key not in proto_bytes:
                results.append({
                    "name": f"db_perm: {label}",
                    "status": "WARN",
                    "detail": "Sentinel key missing from agentPreferences",
                })
                all_ok = False
                continue

            idx = proto_bytes.index(sentinel_key) + len(sentinel_key)
            remaining = proto_bytes[idx:]
            b64_start = remaining.find(b"\x12\x06\n\x04")
            if b64_start >= 0:
                b64_val = remaining[b64_start + 4 : b64_start + 8].decode(
                    "ascii", errors="replace"
                )
                policy_val = _decode_policy_value(b64_val)
                if policy_val == expected_val:
                    results.append({
                        "name": f"db_perm: {label}",
                        "status": "OK",
                        "detail": f"value={policy_val}",
                    })
                else:
                    results.append({
                        "name": f"db_perm: {label}",
                        "status": "WARN",
                        "detail": f"value={policy_val}, expected {expected_val}",
                    })
                    all_ok = False
            else:
                results.append({
                    "name": f"db_perm: {label}",
                    "status": "WARN",
                    "detail": "Could not locate protobuf value after sentinel",
                })
                all_ok = False

        # Boolean sentinel checks
        for sentinel_key, label in _BOOL_SENTINELS.items():
            if sentinel_key in proto_bytes:
                results.append({
                    "name": f"db_perm: {label}",
                    "status": "OK",
                    "detail": "Enabled",
                })
            else:
                results.append({
                    "name": f"db_perm: {label}",
                    "status": "WARN",
                    "detail": "Not set (default=false)",
                })
                all_ok = False

        if not all_ok:
            results.append({
                "name": "db_permissions (overall)",
                "status": "WARN",
                "detail": "One or more permission policies are sub-optimal",
            })
        else:
            results.append({
                "name": "db_permissions (overall)",
                "status": "OK",
                "detail": "All 5 permission policies optimal",
            })

    finally:
        conn.close()

    return results


# ---------------------------------------------------------------------------
# Check: DB journal mode
# ---------------------------------------------------------------------------
def _check_db_journal_mode(baseline: dict) -> list[dict]:
    """Check that state.vscdb is using the expected journal mode."""
    results = []
    expected = baseline.get("db_journal_mode", "wal")

    conn = _open_db(GLOBAL_STATE_DB)
    if conn is None:
        results.append({
            "name": "db_journal_mode",
            "status": "ERROR",
            "detail": f"State DB not found: {GLOBAL_STATE_DB}",
        })
        return results

    try:
        row = conn.execute("PRAGMA journal_mode").fetchone()
        actual = row[0] if row else "unknown"

        if actual == expected:
            results.append({
                "name": "db_journal_mode",
                "status": "OK",
                "detail": f"journal_mode={actual}",
            })
        else:
            results.append({
                "name": "db_journal_mode",
                "status": "WARN",
                "detail": f"journal_mode={actual}, expected {expected}",
            })
    except sqlite3.Error as e:
        results.append({
            "name": "db_journal_mode",
            "status": "ERROR",
            "detail": str(e),
        })
    finally:
        conn.close()

    return results


# ---------------------------------------------------------------------------
# Fix: re-disable extensions
# ---------------------------------------------------------------------------
def _fix_extensions(baseline: dict) -> list[dict]:
    """Re-disable extensions that were re-enabled by an update."""
    results = []
    manifest = baseline.get("disabled_extensions", [])

    if not BUNDLED_EXT_DIR.exists():
        results.append({
            "name": "fix_extensions",
            "status": "ERROR",
            "detail": f"Extensions directory not found: {BUNDLED_EXT_DIR}",
        })
        return results

    for name in manifest:
        enabled_path = BUNDLED_EXT_DIR / name
        disabled_path = BUNDLED_EXT_DIR / f"{name}.disabled"

        if enabled_path.exists() and not disabled_path.exists():
            try:
                enabled_path.rename(disabled_path)
                results.append({
                    "name": f"ext: {name}",
                    "status": "FIXED",
                    "detail": "Re-disabled (renamed to .disabled)",
                })
            except PermissionError:
                results.append({
                    "name": f"ext: {name}",
                    "status": "FAILED",
                    "detail": "PermissionError — Antigravity may have files locked. Close it and retry.",
                })
            except OSError as e:
                results.append({
                    "name": f"ext: {name}",
                    "status": "FAILED",
                    "detail": str(e),
                })

    if not results:
        results.append({
            "name": "fix_extensions",
            "status": "OK",
            "detail": "No extensions needed re-disabling",
        })

    return results


# ---------------------------------------------------------------------------
# Fix: DB permissions
# ---------------------------------------------------------------------------
def _fix_db_permissions() -> list[dict]:
    """Write optimal agentPreferences blob to state.vscdb."""
    results = []

    conn = _open_db(GLOBAL_STATE_DB)
    if conn is None:
        results.append({
            "name": "fix_db_permissions",
            "status": "ERROR",
            "detail": f"State DB not found: {GLOBAL_STATE_DB}",
        })
        return results

    try:
        _set_key(
            conn,
            "antigravityUnifiedStateSync.agentPreferences",
            OPTIMAL_AGENT_PREFS_B64,
        )
        results.append({
            "name": "fix_db_permissions",
            "status": "FIXED",
            "detail": "Wrote optimal agentPreferences (all 5 policies)",
        })
    except sqlite3.Error as e:
        results.append({
            "name": "fix_db_permissions",
            "status": "FAILED",
            "detail": str(e),
        })
    finally:
        conn.close()

    return results


# ---------------------------------------------------------------------------
# Fix: DB journal mode
# ---------------------------------------------------------------------------
def _fix_db_journal_mode(baseline: dict) -> list[dict]:
    """Set journal_mode on state.vscdb if it doesn't match baseline."""
    results = []
    expected = baseline.get("db_journal_mode", "wal")

    conn = _open_db(GLOBAL_STATE_DB)
    if conn is None:
        results.append({
            "name": "fix_journal_mode",
            "status": "ERROR",
            "detail": f"State DB not found: {GLOBAL_STATE_DB}",
        })
        return results

    try:
        row = conn.execute("PRAGMA journal_mode").fetchone()
        actual = row[0] if row else "unknown"

        if actual == expected:
            results.append({
                "name": "fix_journal_mode",
                "status": "OK",
                "detail": f"Already {expected}",
            })
        else:
            conn.execute(f"PRAGMA journal_mode={expected}")
            results.append({
                "name": "fix_journal_mode",
                "status": "FIXED",
                "detail": f"Changed {actual} -> {expected}",
            })
    except sqlite3.Error as e:
        results.append({
            "name": "fix_journal_mode",
            "status": "FAILED",
            "detail": str(e),
        })
    finally:
        conn.close()

    return results


# ---------------------------------------------------------------------------
# Snapshot current state for baseline update
# ---------------------------------------------------------------------------
def _snapshot_current_state() -> dict:
    """Read current settings/argv/extensions/db state into a baseline dict."""
    snapshot: dict = {
        "version": 1,
        "created": str(date.today()),
    }

    # Settings
    if SETTINGS_JSON.exists():
        try:
            with open(SETTINGS_JSON, "r", encoding="utf-8") as f:
                settings = json.load(f)
            # Extract only the keys that are in the current baseline (or a sane default set)
            try:
                old_baseline = _load_baseline()
                critical_keys = list(old_baseline.get("settings_critical", {}).keys())
            except FileNotFoundError:
                critical_keys = [
                    "telemetry.telemetryLevel", "extensions.autoUpdate",
                    "extensions.autoCheckUpdates", "editor.minimap.enabled",
                    "search.followSymlinks", "workbench.startupEditor",
                    "workbench.enableExperiments",
                    "antigravity.searchMaxWorkspaceFileCount",
                    "antigravity.persistentLanguageServer",
                    "git.autorefresh", "timeline.enabled",
                    "extensions.ignoreRecommendations",
                ]
            snapshot["settings_critical"] = {
                k: settings.get(k) for k in critical_keys if k in settings
            }
        except (json.JSONDecodeError, OSError) as e:
            _log(f"Warning: could not read settings.json: {e}")
            snapshot["settings_critical"] = {}
    else:
        snapshot["settings_critical"] = {}

    # Argv
    if ARGV_JSON.exists():
        try:
            with open(ARGV_JSON, "r", encoding="utf-8") as f:
                argv = json.load(f)
            argv_critical_keys = [
                "disable-telemetry", "enable-crash-reporter",
                "disable-renderer-backgrounding",
                "disable-background-timer-throttling",
            ]
            snapshot["argv_critical"] = {
                k: argv.get(k) for k in argv_critical_keys if k in argv
            }
            js_flags = argv.get("js-flags", "")
            snapshot["argv_js_flags_required"] = js_flags.split() if js_flags else []
        except (json.JSONDecodeError, OSError) as e:
            _log(f"Warning: could not read argv.json: {e}")
            snapshot["argv_critical"] = {}
            snapshot["argv_js_flags_required"] = []
    else:
        snapshot["argv_critical"] = {}
        snapshot["argv_js_flags_required"] = []

    # Disabled extensions — snapshot what's currently disabled
    if BUNDLED_EXT_DIR.exists():
        disabled = []
        for item in sorted(BUNDLED_EXT_DIR.iterdir()):
            if item.is_dir() and item.name.endswith(".disabled"):
                disabled.append(item.name.removesuffix(".disabled"))
        snapshot["disabled_extensions"] = disabled
    else:
        snapshot["disabled_extensions"] = []

    # DB permissions — read current blob
    conn = _open_db(GLOBAL_STATE_DB)
    if conn is not None:
        try:
            raw = _get_key(conn, "antigravityUnifiedStateSync.agentPreferences")
            snapshot["db_permissions"] = {
                "agent_prefs_b64": raw or "",
            }
            row = conn.execute("PRAGMA journal_mode").fetchone()
            snapshot["db_journal_mode"] = row[0] if row else "unknown"
        except sqlite3.Error:
            snapshot["db_permissions"] = {"agent_prefs_b64": ""}
            snapshot["db_journal_mode"] = "unknown"
        finally:
            conn.close()
    else:
        snapshot["db_permissions"] = {"agent_prefs_b64": ""}
        snapshot["db_journal_mode"] = "unknown"

    return snapshot


# ---------------------------------------------------------------------------
# MCP Server
# ---------------------------------------------------------------------------
mcp = FastMCP(
    "otto",
    instructions=(
        "OTTO: Antigravity optimization health monitor. "
        "Check and fix IDE optimization regressions."
    ),
)


@mcp.tool(
    annotations={"readOnlyHint": True},
    description=(
        "Run all health checks against the OTTO baseline. Returns a JSON report "
        "with status (healthy/degraded/critical), score, and per-check details. "
        "Checks: settings.json, argv.json, disabled extensions, DB permissions, "
        "DB journal mode."
    ),
)
def otto_health_check() -> dict:
    """Run all health checks and return a JSON report."""
    try:
        baseline = _load_baseline()
    except FileNotFoundError as e:
        return {
            "status": "critical",
            "score": "0/0",
            "checks": [{"name": "baseline", "status": "ERROR", "detail": str(e)}],
        }

    checks: list[dict] = []

    # 1. Settings
    checks.extend(_check_settings(baseline))

    # 2. Argv
    checks.extend(_check_argv(baseline))

    # 3. Extensions
    checks.extend(_check_extensions(baseline))

    # 4. DB permissions
    checks.extend(_check_db_permissions(baseline))

    # 5. DB journal mode
    checks.extend(_check_db_journal_mode(baseline))

    # Score
    total = len(checks)
    ok_count = sum(1 for c in checks if c["status"] == "OK")
    error_count = sum(1 for c in checks if c["status"] == "ERROR")
    warn_count = sum(1 for c in checks if c["status"] == "WARN")

    if error_count > 0:
        status = "critical"
    elif warn_count > 0:
        status = "degraded"
    else:
        status = "healthy"

    return {
        "status": status,
        "score": f"{ok_count}/{total}",
        "checks": checks,
    }


@mcp.tool(
    description=(
        "Auto-fix detected optimization regressions. Patches DB permissions, "
        "re-disables extensions, and fixes DB journal mode. Returns what was "
        "fixed, what was already OK, and what failed."
    ),
)
def otto_fix_regressions() -> dict:
    """Auto-fix detected optimization regressions."""
    try:
        baseline = _load_baseline()
    except FileNotFoundError as e:
        return {
            "fixed": [],
            "already_ok": [],
            "failed": [{"name": "baseline", "detail": str(e)}],
        }

    fixed: list[dict] = []
    already_ok: list[dict] = []
    failed: list[dict] = []

    # 1. Fix DB permissions (check first, fix if needed)
    perm_checks = _check_db_permissions(baseline)
    perm_overall = [c for c in perm_checks if c["name"] == "db_permissions (overall)"]
    if perm_overall and perm_overall[0]["status"] != "OK":
        fix_results = _fix_db_permissions()
        for r in fix_results:
            if r["status"] == "FIXED":
                fixed.append(r)
            elif r["status"] == "OK":
                already_ok.append(r)
            else:
                failed.append(r)
    else:
        already_ok.append({
            "name": "db_permissions",
            "status": "OK",
            "detail": "Already optimal",
        })

    # 2. Fix extensions
    ext_results = _fix_extensions(baseline)
    for r in ext_results:
        if r["status"] == "FIXED":
            fixed.append(r)
        elif r["status"] == "OK":
            already_ok.append(r)
        else:
            failed.append(r)

    # 3. Fix journal mode
    jm_results = _fix_db_journal_mode(baseline)
    for r in jm_results:
        if r["status"] == "FIXED":
            fixed.append(r)
        elif r["status"] == "OK":
            already_ok.append(r)
        else:
            failed.append(r)

    # Note: settings.json and argv.json are NOT auto-fixed — they require
    # manual editing since they may contain user-specific overrides.
    # We report them as informational only.
    settings_checks = _check_settings(baseline)
    for c in settings_checks:
        if c["status"] != "OK":
            failed.append({
                "name": c["name"],
                "status": "MANUAL",
                "detail": f"Not auto-fixed (edit manually): {c['detail']}",
            })

    argv_checks = _check_argv(baseline)
    for c in argv_checks:
        if c["status"] != "OK":
            failed.append({
                "name": c["name"],
                "status": "MANUAL",
                "detail": f"Not auto-fixed (edit manually): {c['detail']}",
            })

    return {
        "fixed": fixed,
        "already_ok": already_ok,
        "failed": failed,
    }


@mcp.tool(
    annotations={"readOnlyHint": True},
    description="Return the current OTTO baseline JSON (read-only).",
)
def otto_get_baseline() -> dict:
    """Return the current baseline configuration."""
    try:
        return _load_baseline()
    except FileNotFoundError as e:
        return {"error": str(e)}


@mcp.tool(
    description=(
        "Snapshot the current Antigravity state as the new OTTO baseline. "
        "Use after intentionally changing settings to update what 'optimal' means."
    ),
)
def otto_update_baseline() -> dict:
    """Snapshot current state as new baseline."""
    try:
        snapshot = _snapshot_current_state()
        _save_baseline(snapshot)
        return {
            "status": "saved",
            "file": str(BASELINE_FILE),
            "version": snapshot.get("version"),
            "created": snapshot.get("created"),
            "settings_count": len(snapshot.get("settings_critical", {})),
            "argv_keys_count": len(snapshot.get("argv_critical", {})),
            "disabled_extensions_count": len(snapshot.get("disabled_extensions", [])),
        }
    except Exception as e:
        return {"status": "error", "detail": str(e)}


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
def main():
    _log("Starting OTTO MCP server...")
    try:
        baseline = _load_baseline()
        _log(f"Baseline loaded: v{baseline.get('version')}, created {baseline.get('created')}")
    except FileNotFoundError:
        _log("WARNING: No baseline file found — otto_health_check will fail until one is created")
    mcp.run(transport="stdio")


if __name__ == "__main__":
    main()

"""
watchdog.py — Background permission watchdog for Antigravity

Monitors Antigravity's state DB for permission regressions (e.g., after updates)
and auto-patches them back to TURBO. Also cleans notification bloat when it
exceeds a threshold.

Runs in the background, checking every 60 seconds. Logs all actions.

Usage:
    python watchdog.py              # Run in foreground (Ctrl+C to stop)
    python watchdog.py --interval 30  # Check every 30 seconds
    python watchdog.py --once       # Single check, then exit

Designed to be started from launch_antigravity.bat.
"""

from __future__ import annotations

import argparse
import base64
import json
import logging
import os
import signal
import sqlite3
import sys
import time
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
HOME = Path(os.environ.get("USERPROFILE", r"C:\Users\atayl"))
GLOBAL_STATE_DB = HOME / "AppData" / "Roaming" / "Antigravity" / "User" / "globalStorage" / "state.vscdb"
WATCHDOG_LOG = Path(__file__).parent / "watchdog.log"

# ---------------------------------------------------------------------------
# Policy constants
# ---------------------------------------------------------------------------
# Terminal enum (Jd): OFF=1, AUTO=2, EAGER=3  (3 is max, NOT 4!)
# Artifact enum (C0): ALWAYS=1, TURBO=2, AUTO=3
# Planning enum (RI): UNSPECIFIED=0, OFF=1, ON=2
# Boolean settings use protobuf field1 varint: [8, 1] = true
TERMINAL_EAGER_VALUE = 3   # EAGER = always auto-execute (max for terminal)
ARTIFACT_TURBO_VALUE = 2   # TURBO = auto-apply artifacts
PLANNING_OFF_VALUE = 1     # OFF = skip planning phase

# Pre-built agentPreferences protobuf blob with all 5 settings optimized.
# EAM= = [16,3] = terminal EAGER(3)
# EAI= = [16,2] = artifact TURBO(2)
# EAE= = [16,1] = planning OFF(1)
# CAE= = [8,1]  = boolean true
OPTIMAL_AGENT_PREFS_B64 = (
    "CjAKJnRlcm1pbmFsQXV0b0V4ZWN1dGlvblBvbGljeVNlbnRpbmVsS2V5EgYKBEVBTT0"
    "KKQofYXJ0aWZhY3RSZXZpZXdQb2xpY3lTZW50aW5lbEtleRIGCgRFQUk9"
    "CiEKF3BsYW5uaW5nTW9kZVNlbnRpbmVsS2V5EgYKBEVBRT0"
    "KNgosYWxsb3dBZ2VudEFjY2Vzc05vbldvcmtzcGFjZUZpbGVzU2VudGluZWxLZXkSBgoEQ0FFPQo1"
    "CithbGxvd0Nhc2NhZGVBY2Nlc3NHaXRpZ25vcmVGaWxlc1NlbnRpbmVsS2V5EgYKBENBRT0="
)

NOTIFICATION_THRESHOLD = 50

# ---------------------------------------------------------------------------
# Logging setup
# ---------------------------------------------------------------------------
def setup_logging() -> logging.Logger:
    """Configure rotating-style logging to watchdog.log + stderr."""
    logger = logging.getLogger("ag-watchdog")
    logger.setLevel(logging.INFO)

    # File handler
    fh = logging.FileHandler(str(WATCHDOG_LOG), encoding="utf-8")
    fh.setLevel(logging.INFO)

    # Console handler (minimal)
    ch = logging.StreamHandler(sys.stderr)
    ch.setLevel(logging.WARNING)

    fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S")
    fh.setFormatter(fmt)
    ch.setFormatter(fmt)

    logger.addHandler(fh)
    logger.addHandler(ch)

    return logger


# ---------------------------------------------------------------------------
# DB helpers
# ---------------------------------------------------------------------------
def open_db(path: Path) -> sqlite3.Connection | None:
    if not path.exists():
        return None
    try:
        conn = sqlite3.connect(str(path), timeout=5)
        return conn
    except sqlite3.OperationalError:
        return None


def get_key(conn: sqlite3.Connection, key: str) -> str | None:
    row = conn.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
    return row[0] if row else None


def set_key(conn: sqlite3.Connection, key: str, value: str) -> None:
    conn.execute(
        "INSERT OR REPLACE INTO ItemTable (key, value) VALUES (?, ?)",
        (key, value),
    )
    conn.commit()


# ---------------------------------------------------------------------------
# Policy checking
# ---------------------------------------------------------------------------
def decode_policy_value(sentinel_b64: str) -> int | None:
    """Decode a protobuf varint from base64 sentinel value."""
    try:
        data = base64.b64decode(sentinel_b64)
        if len(data) >= 2 and data[0] == 0x10:
            return data[1]
    except Exception:
        pass
    return None


def check_and_fix_permissions(logger: logging.Logger) -> bool:
    """Check terminal/artifact policies, fix if regressed.

    Returns True if a fix was applied.
    """
    conn = open_db(GLOBAL_STATE_DB)
    if conn is None:
        logger.debug("State DB not accessible — skipping permission check")
        return False

    fixed = False
    try:
        raw = get_key(conn, "antigravityUnifiedStateSync.agentPreferences")
        if raw is None:
            logger.warning("agentPreferences key missing — writing TURBO defaults")
            set_key(conn, "antigravityUnifiedStateSync.agentPreferences", OPTIMAL_AGENT_PREFS_B64)
            return True

        # The DB stores a base64 string wrapping a protobuf blob
        try:
            proto_bytes = base64.b64decode(raw)
        except Exception:
            logger.error("agentPreferences is not valid base64 — overwriting with TURBO")
            set_key(conn, "antigravityUnifiedStateSync.agentPreferences", OPTIMAL_AGENT_PREFS_B64)
            return True

        # Check terminal policy
        # Check all 5 sentinel keys are present with correct values
        checks = {
            b"terminalAutoExecutionPolicySentinelKey": (TERMINAL_EAGER_VALUE, "terminal"),
            b"artifactReviewPolicySentinelKey": (ARTIFACT_TURBO_VALUE, "artifact"),
            b"planningModeSentinelKey": (PLANNING_OFF_VALUE, "planning"),
        }
        all_ok = True
        for sentinel_key, (expected_val, label) in checks.items():
            if sentinel_key not in proto_bytes:
                logger.warning(f"{label} sentinel key missing from agentPreferences")
                all_ok = False
                continue
            idx = proto_bytes.index(sentinel_key) + len(sentinel_key)
            remaining = proto_bytes[idx:]
            b64_start = remaining.find(b"\x12\x06\n\x04")
            if b64_start >= 0:
                b64_val = remaining[b64_start + 4 : b64_start + 8].decode("ascii", errors="replace")
                policy_val = decode_policy_value(b64_val)
                if policy_val != expected_val:
                    logger.warning(f"{label} policy regressed: value={policy_val}, expected={expected_val}")
                    all_ok = False

        # Also check boolean sentinel keys are present
        for bool_key in [b"allowAgentAccessNonWorkspaceFilesSentinelKey",
                         b"allowCascadeAccessGitignoreFilesSentinelKey"]:
            if bool_key not in proto_bytes:
                logger.warning(f"{bool_key.decode()} missing from agentPreferences")
                all_ok = False

        if not all_ok:
            logger.info("Patching agentPreferences back to optimal values (5 settings)")
            set_key(
                conn,
                "antigravityUnifiedStateSync.agentPreferences",
                OPTIMAL_AGENT_PREFS_B64,
            )
            fixed = True
        else:
            logger.debug("Permissions OK — all 5 settings at optimal values")

    except sqlite3.OperationalError as e:
        if "database is locked" in str(e):
            logger.debug("State DB locked — will retry next cycle")
        else:
            logger.error(f"DB error checking permissions: {e}")
    finally:
        conn.close()

    return fixed


# ---------------------------------------------------------------------------
# Notification cleanup
# ---------------------------------------------------------------------------
def check_and_clean_notifications(logger: logging.Logger) -> bool:
    """Clean notification bloat if above threshold.

    Returns True if cleanup was performed.
    """
    conn = open_db(GLOBAL_STATE_DB)
    if conn is None:
        return False

    cleaned = False
    try:
        # Count antigravity.notification.* keys (dismissed notification markers)
        count = conn.execute(
            "SELECT COUNT(*) FROM ItemTable WHERE key LIKE 'antigravity.notification%'"
        ).fetchone()[0]

        if count > NOTIFICATION_THRESHOLD:
            logger.info(f"Notification bloat detected: {count} entries (threshold={NOTIFICATION_THRESHOLD})")
            conn.execute("DELETE FROM ItemTable WHERE key LIKE 'antigravity.notification%'")
            conn.commit()
            logger.info(f"Cleaned {count} notification entries")
            cleaned = True
        else:
            logger.debug(f"Notifications OK: {count} entries")

    except sqlite3.OperationalError as e:
        if "database is locked" not in str(e):
            logger.error(f"DB error checking notifications: {e}")
    finally:
        conn.close()

    return cleaned


# ---------------------------------------------------------------------------
# Log file maintenance
# ---------------------------------------------------------------------------
def trim_log_file(logger: logging.Logger, max_size_kb: int = 512) -> None:
    """Keep watchdog.log from growing forever."""
    if not WATCHDOG_LOG.exists():
        return

    size_kb = WATCHDOG_LOG.stat().st_size / 1024
    if size_kb > max_size_kb:
        try:
            # Keep the last 200 lines
            with open(WATCHDOG_LOG, "r", encoding="utf-8") as f:
                lines = f.readlines()
            with open(WATCHDOG_LOG, "w", encoding="utf-8") as f:
                f.writelines(lines[-200:])
            logger.info(f"Trimmed watchdog.log: {size_kb:.0f} KB -> kept last 200 lines")
        except OSError:
            pass


# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
_running = True


def signal_handler(signum, frame):
    global _running
    _running = False


def run_once(logger: logging.Logger) -> dict:
    """Run a single check cycle. Returns dict of actions taken."""
    actions = {}

    perm_fixed = check_and_fix_permissions(logger)
    if perm_fixed:
        actions["permissions_patched"] = True

    notif_cleaned = check_and_clean_notifications(logger)
    if notif_cleaned:
        actions["notifications_cleaned"] = True

    return actions


def main() -> int:
    parser = argparse.ArgumentParser(description="Antigravity permission watchdog")
    parser.add_argument("--interval", type=int, default=60, help="Check interval in seconds (default: 60)")
    parser.add_argument("--once", action="store_true", help="Run a single check and exit")
    args = parser.parse_args()

    logger = setup_logging()
    logger.info(f"Watchdog started (PID={os.getpid()}, interval={args.interval}s)")
    logger.info(f"Monitoring: {GLOBAL_STATE_DB}")

    # Handle graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    if args.once:
        actions = run_once(logger)
        if actions:
            logger.info(f"Single check complete — actions taken: {actions}")
        else:
            logger.info("Single check complete — no issues found")
        return 0

    # Main loop
    cycle = 0
    global _running
    while _running:
        cycle += 1
        try:
            actions = run_once(logger)
            if actions:
                logger.info(f"Cycle {cycle}: actions={actions}")

            # Trim log file periodically (every 100 cycles = ~100 minutes)
            if cycle % 100 == 0:
                trim_log_file(logger)

        except Exception as e:
            logger.error(f"Cycle {cycle} error: {e}")

        # Sleep in small increments for responsive shutdown
        for _ in range(args.interval):
            if not _running:
                break
            time.sleep(1)

    logger.info("Watchdog stopped (signal received)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

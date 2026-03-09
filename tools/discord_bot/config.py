"""Bot configuration — loads from .env file or environment variables."""

import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# Load .env from the bot directory
_BOT_DIR = Path(__file__).parent
load_dotenv(_BOT_DIR / ".env")

# --- Discord ---
DISCORD_TOKEN = os.getenv("DISCORD_TOKEN", "")

# Channel IDs (populated from .env — 0 means "not configured")
CHANNEL_TROUBLESHOOTING = int(os.getenv("CHANNEL_TROUBLESHOOTING", 0))
CHANNEL_BUGREPORT = int(os.getenv("CHANNEL_BUGREPORT", 0))
CHANNEL_TWW = int(os.getenv("CHANNEL_TWW", 0))
CHANNEL_GENERAL = int(os.getenv("CHANNEL_GENERAL", 0))
CHANNEL_ANNOUNCEMENTS = int(os.getenv("CHANNEL_ANNOUNCEMENTS", 0))

SUPPORT_CHANNEL_IDS = {
    cid for cid in [
        CHANNEL_TROUBLESHOOTING,
        CHANNEL_BUGREPORT,
        CHANNEL_TWW,
        CHANNEL_GENERAL,
    ] if cid
}

# --- SOAP ---
SOAP_HOST = os.getenv("SOAP_HOST", "127.0.0.1")
SOAP_PORT = int(os.getenv("SOAP_PORT", 7878))
SOAP_USER = os.getenv("SOAP_USER", "1#1")
SOAP_PASS = os.getenv("SOAP_PASS", "gm")

# --- MySQL ---
MYSQL_HOST = os.getenv("MYSQL_HOST", "127.0.0.1")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", 3306))
MYSQL_USER = os.getenv("MYSQL_USER", "root")
MYSQL_PASS = os.getenv("MYSQL_PASS", "admin")

# --- Wago CSV ---
_csv_env = os.getenv("WAGO_CSV_DIR", "")
if _csv_env:
    WAGO_CSV_DIR = Path(_csv_env)
else:
    # Auto-detect from wago_common.py
    _wago_dir = Path(__file__).resolve().parent.parent.parent / "wago"
    if (_wago_dir / "wago_common.py").exists():
        sys.path.insert(0, str(_wago_dir))
        try:
            from wago_common import WAGO_CSV_DIR as _auto  # type: ignore
            WAGO_CSV_DIR = Path(_auto)
        except Exception:
            WAGO_CSV_DIR = _wago_dir / "wago_csv"
    else:
        WAGO_CSV_DIR = _wago_dir / "wago_csv"

# --- GitHub ---
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN", "")
GITHUB_REPO = "TrinityCore/TrinityCore"
GITHUB_AUTH_SQL_PATH = "sql/updates/auth/master"

# --- Watchdog ---
WATCHDOG_INTERVAL = int(os.getenv("WATCHDOG_INTERVAL", 300))

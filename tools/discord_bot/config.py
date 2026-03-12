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
def _int_env(key: str) -> int:
    """Read an env var as int, defaulting to 0 for empty/missing values."""
    val = os.getenv(key, "")
    return int(val) if val.strip() else 0

CHANNEL_TROUBLESHOOTING = _int_env("CHANNEL_TROUBLESHOOTING")
CHANNEL_BUGREPORT = _int_env("CHANNEL_BUGREPORT")
CHANNEL_TWW = _int_env("CHANNEL_TWW")
CHANNEL_GENERAL = _int_env("CHANNEL_GENERAL")
CHANNEL_ANNOUNCEMENTS = _int_env("CHANNEL_ANNOUNCEMENTS")

# Expansion-specific channels (FAQ + triage auto-respond here too)
CHANNEL_CLASSIC = _int_env("CHANNEL_CLASSIC")
CHANNEL_BURNING_CRUSADE = _int_env("CHANNEL_BURNING_CRUSADE")
CHANNEL_WOTLK = _int_env("CHANNEL_WOTLK")
CHANNEL_CATACLYSM = _int_env("CHANNEL_CATACLYSM")
CHANNEL_MOP = _int_env("CHANNEL_MOP")
CHANNEL_WOD = _int_env("CHANNEL_WOD")
CHANNEL_LEGION = _int_env("CHANNEL_LEGION")
CHANNEL_BFA = _int_env("CHANNEL_BFA")
CHANNEL_SHADOWLANDS = _int_env("CHANNEL_SHADOWLANDS")
CHANNEL_DRAGONFLIGHT = _int_env("CHANNEL_DRAGONFLIGHT")
CHANNEL_MIDNIGHT = _int_env("CHANNEL_MIDNIGHT")

# Empty set = respond in ALL guild channels (no allowlist filtering)
SUPPORT_CHANNEL_IDS = set()

# --- SOAP ---
# (SOAP variables removed)

# --- MySQL ---
MYSQL_HOST = os.getenv("MYSQL_HOST", "127.0.0.1")
MYSQL_PORT = int(os.getenv("MYSQL_PORT", 3306))
MYSQL_USER = os.getenv("MYSQL_USER", "root")
MYSQL_PASS = os.getenv("MYSQL_PASS", "admin")

# --- Wago CSV ---
# (WAGO_CSV_DIR removed)

# --- GitHub ---
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN", "")
GITHUB_REPO = "TrinityCore/TrinityCore"
GITHUB_AUTH_SQL_PATH = "sql/updates/auth/master"

# --- Watchdog ---
WATCHDOG_INTERVAL = int(os.getenv("WATCHDOG_INTERVAL", 300))

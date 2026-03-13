"""VoxSniffer pipeline configuration."""

from pathlib import Path

# Project root (VoxCore/)
PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent

# Default paths
SAVEDVARIABLES_DIR = Path(r"C:\WoW\_retail_\WTF\Account")
DATA_DIR = PROJECT_ROOT / "data" / "voxsniffer"
BASELINES_DIR = DATA_DIR / "baselines"
SESSIONS_DIR = DATA_DIR / "sessions"
NORMALIZED_DIR = DATA_DIR / "normalized"
DELTAS_DIR = DATA_DIR / "deltas"
SQL_DIR = DATA_DIR / "sql"

# Schema
SCHEMA_VERSION = 1

# Ensure output directories exist
def ensure_dirs():
    for d in [DATA_DIR, BASELINES_DIR, SESSIONS_DIR, NORMALIZED_DIR, DELTAS_DIR, SQL_DIR]:
        d.mkdir(parents=True, exist_ok=True)

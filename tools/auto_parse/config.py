"""Configuration for VoxCore Auto-Parse pipeline.

Loads settings from auto_parse.toml (next to tools/ dir) with sensible defaults.
Every path, interval, and feature toggle is configurable.
"""

from __future__ import annotations

import tomllib
from dataclasses import dataclass, field
from pathlib import Path

CONFIG_DIR = Path(__file__).parent.parent  # tools/


@dataclass
class PathsConfig:
    runtime_dir: Path = field(
        default_factory=lambda: Path(
            r"C:\Users\atayl\VoxCore\out\build\x64-RelWithDebInfo\bin\RelWithDebInfo"
        )
    )
    adb_cache_dir: Path = field(
        default_factory=lambda: Path(r"C:\WoW\_retail_\Cache\ADB\enUS")
    )
    wtf_saved_vars_dir: Path = field(
        default_factory=lambda: Path(r"C:\WoW\_retail_\WTF\Account\1#1\SavedVariables")
    )
    wow_errors_dir: Path = field(
        default_factory=lambda: Path(r"C:\WoW\_retail_\Errors")
    )
    wago_dir: Path = field(
        default_factory=lambda: Path(r"C:\Users\atayl\VoxCore\wago")
    )
    tools_dir: Path = field(
        default_factory=lambda: Path(r"C:\Users\atayl\VoxCore\tools")
    )
    wpp_exe: Path = field(
        default_factory=lambda: Path(
            r"C:\Users\atayl\VoxCore\ExtTools\WowPacketParser\WowPacketParser.exe"
        )
    )

    @property
    def output_dir(self) -> Path:
        return self.runtime_dir / "PacketLog"

    @property
    def crashes_dir(self) -> Path:
        return self.runtime_dir / "Crashes"

    @property
    def wpp_dir(self) -> Path:
        return self.wpp_exe.parent

    @property
    def state_file(self) -> Path:
        return self.output_dir / ".auto_parse_state.json"

    @property
    def seen_file(self) -> Path:
        return self.output_dir / ".auto_parse_seen.json"

    @property
    def log_file(self) -> Path:
        return self.output_dir / "auto_parse.log"


@dataclass
class WatchConfig:
    interval: int = 5
    idle_multiplier: int = 3
    idle_threshold: int = 20
    max_interval: int = 30


@dataclass
class NotifyConfig:
    enabled: bool = True
    on_fatal: bool = True
    on_crash: bool = True
    on_error: bool = False


@dataclass
class DashboardConfig:
    enabled: bool = True
    refresh_seconds: int = 5


@dataclass
class AlertsConfig:
    suppress_known: bool = True
    max_seen: int = 10000


@dataclass
class TrayConfig:
    enabled: bool = False


@dataclass
class OutputConfig:
    verbose: bool = False
    timeline_limit: int = 500


@dataclass
class Config:
    paths: PathsConfig = field(default_factory=PathsConfig)
    watch: WatchConfig = field(default_factory=WatchConfig)
    notifications: NotifyConfig = field(default_factory=NotifyConfig)
    dashboard: DashboardConfig = field(default_factory=DashboardConfig)
    alerts: AlertsConfig = field(default_factory=AlertsConfig)
    tray: TrayConfig = field(default_factory=TrayConfig)
    output: OutputConfig = field(default_factory=OutputConfig)


def _apply_section(obj: object, data: dict) -> None:
    """Apply TOML dict values to a dataclass instance."""
    for k, v in data.items():
        if not hasattr(obj, k):
            continue
        current = getattr(obj, k)
        if isinstance(current, Path):
            setattr(obj, k, Path(v))
        elif isinstance(current, bool):
            setattr(obj, k, bool(v))
        elif isinstance(current, int):
            setattr(obj, k, int(v))
        else:
            setattr(obj, k, v)


def load_config(path: Path | None = None) -> Config:
    """Load config from TOML file. Missing keys use defaults."""
    path = path or CONFIG_DIR / "auto_parse.toml"
    cfg = Config()

    if not path.exists():
        return cfg

    with open(path, "rb") as f:
        data = tomllib.load(f)

    section_map = {
        "paths": cfg.paths,
        "watch": cfg.watch,
        "notifications": cfg.notifications,
        "dashboard": cfg.dashboard,
        "alerts": cfg.alerts,
        "tray": cfg.tray,
        "output": cfg.output,
    }

    for name, obj in section_map.items():
        if name in data:
            _apply_section(obj, data[name])

    return cfg

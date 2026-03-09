"""VoxCore Auto-Parse v3 -- Session-aware debugging pipeline.

Usage:
  python auto_parse              # One-shot: parse everything now
  python auto_parse --watch      # Session-aware watcher (main mode)
  python auto_parse --pipeline   # Run packet pipeline only
  python auto_parse --dashboard  # Generate dashboard only from current state
"""

from __future__ import annotations

import argparse
import logging
import shutil
import time
from datetime import datetime
from pathlib import Path

log = logging.getLogger(__name__)

from rich.console import Console
from rich.table import Table
from rich.text import Text

from .alerts import AlertManager
from .config import Config, load_config
from .dashboard import generate_dashboard
from .engine import LogTailer, SessionState, is_server_running
from .parsers import discover_parsers
from .parsers.base import LineParser, ScanParser, Severity
from .pipeline import PacketPipeline
from .writers import TextWriter


def _setup_logging(config: Config) -> None:
    """Configure Python logging to file + console."""
    log_file = config.paths.log_file
    log_file.parent.mkdir(parents=True, exist_ok=True)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%H:%M:%S",
        handlers=[
            logging.FileHandler(str(log_file), encoding="utf-8"),
        ],
    )


def _rich_print_state(console: Console, state: SessionState, new_count: int) -> None:
    """Print a compact one-line status update."""
    fatals = sum(1 for e in state.all_entries if e.severity >= Severity.FATAL)
    errors = sum(1 for e in state.all_entries if e.severity == Severity.ERROR)
    gm = len(state.get_entries("GM"))
    crashes = len(state.get_entries("Crash"))

    parts = []
    if fatals:
        parts.append(f"[bold red]{fatals} FATAL[/]")
    if errors:
        parts.append(f"[yellow]{errors} err[/]")
    if crashes:
        parts.append(f"[bold red]{crashes} crash[/]")
    parts.append(f"{gm} GM")
    parts.append(f"+{new_count} new")

    status = " | ".join(parts)
    running = is_server_running()
    srv = "[green]* RUNNING[/]" if running else "[red]* STOPPED[/]"

    console.print(
        f"  [{datetime.now():%H:%M:%S}] {srv}  {status}  ({state.uptime_str})",
        highlight=False,
    )


# -- Modes ---------------------------------------------------------------------

def run_oneshot(config: Config, console: Console) -> None:
    """One-shot: parse everything now and write all outputs."""
    config.paths.output_dir.mkdir(parents=True, exist_ok=True)

    state = SessionState()
    line_parsers, scan_parsers = discover_parsers(config)
    writer = TextWriter(config)
    alerter = AlertManager(config)

    console.print(f"\n[bold blue]VoxCore Auto-Parse v3[/] -- one-shot mode\n")

    # Line parsers: read all
    for parser in line_parsers:
        log_path = config.paths.runtime_dir / parser.log_file
        tailer = LogTailer(log_path)
        lines = tailer.read_all()
        if lines:
            try:
                entries = parser.parse_lines(lines)
            except Exception as exc:
                log.error("Parser %s crashed: %s", parser.name, exc)
                console.print(f"  [{parser.name}] PARSER ERROR: {exc}", style="bold red")
                continue
            state.add_entries(entries)
            console.print(f"  [{parser.name}] {len(lines):,} lines -> {len(entries)} entries")
        else:
            console.print(f"  [{parser.name}] not found or empty", style="dim")

    # Scan parsers
    for parser in scan_parsers:
        try:
            entries = parser.scan()
        except Exception as exc:
            log.error("Scanner %s crashed: %s", parser.name, exc)
            console.print(f"  [{parser.name}] SCANNER ERROR: {exc}", style="bold red")
            continue
        state.add_entries(entries)
        if entries:
            console.print(f"  [{parser.name}] {len(entries)} entries")

    # Check for new alerts
    new_alerts = alerter.check_new(state.all_entries)
    if new_alerts:
        console.print(f"\n  [bold red]!! {len(new_alerts)} new alert(s)[/]")
    if alerter.suppressed_count:
        console.print(f"  [dim]({alerter.suppressed_count} known issues suppressed)[/]")

    # Write outputs
    writer.write_all(state)
    if config.dashboard.enabled:
        generate_dashboard(state, config)
        console.print(f"\n  -> dashboard.html", style="dim")

    console.print(f"\n  Output: {config.paths.output_dir}")


def run_pipeline(config: Config, console: Console) -> None:
    """Run just the packet pipeline."""
    config.paths.output_dir.mkdir(parents=True, exist_ok=True)
    pipeline = PacketPipeline(config)
    console.print(f"\n[bold blue]VoxCore Auto-Parse v3[/] -- pipeline mode\n")

    def cprint(msg):
        console.print(msg)

    if pipeline.run(console_print=cprint):
        console.print(f"\n  Pipeline complete. Output: {config.paths.output_dir}")
    else:
        console.print(f"\n  Pipeline did not run (no World.pkt or error).", style="yellow")


def run_watch(config: Config, console: Console) -> None:
    """Session-aware continuous watcher with rich output."""
    out_dir = config.paths.output_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    # Initialize components
    line_parsers, scan_parsers = discover_parsers(config)
    writer = TextWriter(config)
    alerter = AlertManager(config)
    pipeline_runner = PacketPipeline(config)

    # Try to restore state from persistence
    state = SessionState.load(config.paths.state_file) or SessionState()

    # Build tailers for line parsers
    tailers: dict[str, tuple[LineParser, LogTailer]] = {}
    for parser in line_parsers:
        log_path = config.paths.runtime_dir / parser.log_file
        tailers[parser.name] = (parser, LogTailer(log_path))

    # Tray icon (optional)
    tray = None
    if config.tray.enabled:
        try:
            from .tray import TrayIcon
            tray = TrayIcon(out_dir)
            tray.start()
        except Exception:
            pass

    running = is_server_running()
    state.server_was_running = running

    # Banner
    console.print(f"\n[bold blue]VoxCore Auto-Parse v3[/] -- session-aware watcher")
    console.print(f"  Runtime:  {config.paths.runtime_dir}")
    console.print(f"  Output:   {out_dir}")
    console.print(f"  Interval: {config.watch.interval}s (adaptive)")
    console.print(f"  Server:   {'[green]RUNNING[/]' if running else '[red]stopped[/]'}")
    console.print(f"  Parsers:  {len(line_parsers)} line + {len(scan_parsers)} scan")
    console.print(f"  Alerts:   {alerter.known_count} known fingerprints")
    console.print(f"  Ctrl+C to stop.\n")

    # Initial full parse
    for name, (parser, tailer) in tailers.items():
        lines = tailer.read_all()
        if lines:
            try:
                entries = parser.parse_lines(lines)
            except Exception as exc:
                log.error("Parser %s crashed on initial load: %s", name, exc)
                console.print(f"  [{name}] PARSER ERROR: {exc}", style="bold red")
                continue
            state.add_entries(entries)
            state.line_counts[name] = tailer.total_lines
            console.print(f"  [{name}] loaded {len(lines):,} lines")

    for parser in scan_parsers:
        try:
            entries = parser.scan()
        except Exception as exc:
            log.error("Scanner %s crashed on initial load: %s", parser.name, exc)
            continue
        state.add_entries(entries)

    writer.write_all(state)
    if config.dashboard.enabled:
        generate_dashboard(state, config)

    alerter.check_new(state.all_entries)
    console.print(f"  Initial parse complete. {len(state.all_entries)} entries.\n")

    idle_count = 0

    try:
        while True:
            # Adaptive sleep
            if idle_count > config.watch.idle_threshold:
                sleep_time = min(
                    config.watch.interval * config.watch.idle_multiplier,
                    config.watch.max_interval,
                )
            else:
                sleep_time = config.watch.interval
            time.sleep(sleep_time)

            poll_start = time.monotonic()
            state.poll_count += 1

            # Check server transitions
            now_running = is_server_running()

            # Server just stopped
            if state.server_was_running and not now_running:
                console.print(f"\n[bold red][{datetime.now():%H:%M:%S}] Server STOPPED[/] -- running shutdown pipeline...")

                # Final log sweep
                for name, (parser, tailer) in tailers.items():
                    new_lines = tailer.read_new()
                    if new_lines:
                        try:
                            entries = parser.parse_lines(new_lines, tailer.total_lines - len(new_lines))
                        except Exception as exc:
                            log.error("Parser %s crashed on final sweep: %s", name, exc)
                            continue
                        state.add_entries(entries)

                writer.write_all(state)
                writer.write_session_summary(state)
                writer.write_session_brief(state)

                if not state.pkt_pipeline_ran:
                    def cprint(msg):
                        console.print(msg)
                    pipeline_runner.run(console_print=cprint)
                    state.pkt_pipeline_ran = True

                console.print(f"[{datetime.now():%H:%M:%S}] Shutdown pipeline complete.\n")

                # Snapshot all .log files from runtime_dir into out_dir (PacketLog) 
                # so they are safe from truncation on next startup and easy to access
                logs_copied = 0
                for f in config.paths.runtime_dir.iterdir():
                    if f.is_file() and f.suffix == ".log":
                        try:
                            shutil.copy2(str(f), str(out_dir / f.name))
                            logs_copied += 1
                        except OSError as e:
                            log.error(f"Failed to copy log {f.name}: {e}")

                # Snapshot external client logs and caches
                external_targets: list[Path] = []
                if hasattr(config.paths, 'wtf_saved_vars_dir') and config.paths.wtf_saved_vars_dir.exists():
                    for prefix in ("TransmogSpy", "TransmogBridge"):
                        external_targets.extend(config.paths.wtf_saved_vars_dir.glob(f"{prefix}*.lua"))
                
                db_cache = config.paths.adb_cache_dir / "DBCache.bin"
                if db_cache.exists():
                    external_targets.append(db_cache)

                if hasattr(config.paths, 'wow_errors_dir') and config.paths.wow_errors_dir.exists():
                    external_targets.extend(config.paths.wow_errors_dir.glob("*.txt"))

                for f in external_targets:
                    try:
                        shutil.copy2(str(f), str(out_dir / f.name))
                        logs_copied += 1
                    except OSError as e:
                        log.error(f"Failed to copy external log {f.name}: {e}")

                if logs_copied:
                    console.print(f"  [dim]Snapshot {logs_copied} log files to PacketLog[/]")

                if tray:
                    tray.update_status("error")

            # Server just started
            if not state.server_was_running and now_running:
                console.print(f"\n[bold green][{datetime.now():%H:%M:%S}] Server STARTED[/] -- archiving previous session...")
                _archive_session(state, out_dir, console)
                state.reset_for_new_session()
                for _, (_, tailer) in tailers.items():
                    tailer.reset()
                console.print(f"[{datetime.now():%H:%M:%S}] Fresh session started.\n")

                if tray:
                    tray.update_status("idle")

            state.server_was_running = now_running

            # Poll for new content
            had_changes = False
            new_count = 0

            for name, (parser, tailer) in tailers.items():
                new_lines = tailer.read_new()
                if new_lines:
                    offset = tailer.total_lines - len(new_lines)
                    try:
                        entries = parser.parse_lines(new_lines, offset)
                    except Exception as exc:
                        log.error("Parser %s crashed during poll: %s", name, exc)
                        continue
                    state.add_entries(entries)
                    state.line_counts[name] = tailer.total_lines
                    new_count += len(entries)
                    had_changes = True

            # Scan parsers
            for parser in scan_parsers:
                if parser.should_rescan():
                    try:
                        entries = parser.scan()
                    except Exception as exc:
                        log.error("Scanner %s crashed during poll: %s", parser.name, exc)
                        continue
                    state.add_entries(entries)
                    new_count += len(entries)
                    had_changes = True

            state.last_poll_ms = (time.monotonic() - poll_start) * 1000

            # Check for remote shutdown signal from stop_all.bat
            stop_signal = config.paths.runtime_dir / ".stop_auto_parse"
            if stop_signal.exists():
                console.print(f"\n[bold yellow][{datetime.now():%H:%M:%S}] Shutdown signal received. Exiting watcher.[/]")
                try:
                    stop_signal.unlink()
                except OSError:
                    pass
                break

            if had_changes:
                # Check for new alerts
                new_alerts = alerter.check_new(state.all_entries[-new_count:])

                writer.write_all(state)
                if config.dashboard.enabled:
                    generate_dashboard(state, config)

                # Persist state
                state.save(config.paths.state_file)

                _rich_print_state(console, state, new_count)
                idle_count = 0

                if tray:
                    has_errors = any(e.severity >= Severity.ERROR for e in state.all_entries[-new_count:])
                    tray.update_status("error" if has_errors else "active")
                    tray.update_tooltip(
                        f"VoxCore: {len(state.alerts)} alerts, {len(state.all_entries)} total"
                    )
            else:
                idle_count += 1
                if tray and idle_count == 1:
                    tray.update_status("idle")

    except KeyboardInterrupt:
        console.print(f"\n[{datetime.now():%H:%M:%S}] Stopped. Output in: {out_dir}")
        state.save(config.paths.state_file)
        if tray:
            tray.stop()


def _archive_session(
    state: SessionState, output_dir: Path, console: Console
) -> None:
    """Move current PacketLog contents to a timestamped subfolder."""
    if not output_dir.exists():
        return
    files = [
        f for f in output_dir.iterdir()
        if f.is_file() and f.suffix in (".txt", ".sql", ".pkt", ".json", ".html")
        and not f.name.startswith(".")
    ]
    if not files:
        return

    ts = state.session_start.strftime("%Y-%m-%d_%H-%M-%S")
    archive_dir = output_dir / "archives" / ts
    
    # Handle sub-second restart collisions
    idx = 1
    while archive_dir.exists():
        archive_dir = output_dir / "archives" / f"{ts}-{idx}"
        idx += 1

    archive_dir.mkdir(parents=True, exist_ok=True)

    moved = 0
    for f in files:
        try:
            shutil.move(str(f), str(archive_dir / f.name))
            moved += 1
        except OSError:
            pass

    if moved:
        console.print(f"  [dim]Archived {moved} files to PacketLog/archives/{ts}/[/]")


# -- CLI -----------------------------------------------------------------------

def main() -> None:
    ap = argparse.ArgumentParser(
        description="VoxCore session-aware debugging pipeline v3",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--watch", action="store_true", help="Session-aware watch mode")
    ap.add_argument("--pipeline", action="store_true", help="Run packet pipeline only")
    ap.add_argument("--dashboard", action="store_true", help="Generate dashboard from current state")
    ap.add_argument("-c", "--config", type=Path, help="Path to auto_parse.toml")
    ap.add_argument("-i", "--interval", type=int, help="Override poll interval (seconds)")
    ap.add_argument("-v", "--verbose", action="store_true", help="Verbose output")
    ap.add_argument("--tray", action="store_true", help="Enable system tray icon")
    ap.add_argument("--no-notify", action="store_true", help="Disable notifications")
    ap.add_argument("--no-dashboard", action="store_true", help="Disable HTML dashboard")
    args = ap.parse_args()

    config = load_config(args.config)

    # CLI overrides
    if args.interval:
        config.watch.interval = args.interval
    if args.verbose:
        config.output.verbose = True
    if args.tray:
        config.tray.enabled = True
    if args.no_notify:
        config.notifications.enabled = False
    if args.no_dashboard:
        config.dashboard.enabled = False

    _setup_logging(config)
    console = Console()

    if args.pipeline:
        run_pipeline(config, console)
    elif args.dashboard:
        # Regenerate dashboard with a fresh parse (persisted state has no entries)
        run_oneshot(config, console)
    elif args.watch:
        run_watch(config, console)
    else:
        run_oneshot(config, console)


if __name__ == "__main__":
    main()

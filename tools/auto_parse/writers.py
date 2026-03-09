"""Output file writers -- all text outputs with atomic writes."""

from __future__ import annotations

import logging
import os
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import TYPE_CHECKING

from .parsers.base import ParsedEntry, Severity

if TYPE_CHECKING:
    from .config import Config
    from .engine import SessionState


def atomic_write(path: Path, content: str) -> None:
    """Write to temp file then atomically rename -- no half-written files."""
    tmp = path.with_suffix(".tmp")
    tmp.write_text(content, encoding="utf-8")
    try:
        tmp.replace(path)
    except OSError:
        # Fallback for locked files on Windows -- never delete original
        # until replacement is confirmed
        logging.getLogger("auto_parse").warning(
            "Could not write %s (file locked?), left as %s", path, tmp
        )


class TextWriter:
    """Writes all .txt output files from session state."""

    def __init__(self, config: Config) -> None:
        self._out = config.paths.output_dir
        self._verbose = config.output.verbose
        self._timeline_limit = config.output.timeline_limit

    def write_all(self, state: SessionState) -> None:
        self._out.mkdir(parents=True, exist_ok=True)
        self.write_alerts(state)
        self.write_timeline(state)
        self.write_server_errors(state)
        self.write_db_errors(state)
        self.write_debug_summary(state)
        self.write_gm_commands(state)
        self.write_crashes(state)

    def write_alerts(self, state: SessionState) -> None:
        path = self._out / "alerts.txt"
        now = _now()

        if not state.alerts:
            atomic_write(path, f"[auto_parse] No alerts. Last check: {now}\n")
            return

        lines = [f"=== ALERTS -- {len(state.alerts)} issues ===\n"]
        for e in state.alerts[-200:]:
            sev = e.severity.name
            lines.append(f"[{e.timestamp}] [{e.source:<7}] [{sev:<5}] {e.text[:200]}")
        lines.append(f"\nLast updated: {now}")
        atomic_write(path, "\n".join(lines))

    def write_timeline(self, state: SessionState) -> None:
        path = self._out / "timeline.txt"
        timeline = state.get_timeline()

        if not timeline:
            atomic_write(path, "[auto_parse] No activity yet. Waiting for logs...\n")
            return

        limit = self._timeline_limit * 4 if self._verbose else self._timeline_limit
        shown = timeline[-limit:]
        omitted = len(timeline) - len(shown)

        lines = [
            "=" * 100,
            f"SESSION TIMELINE -- {state.session_start.strftime('%Y-%m-%d %H:%M')} -- {len(timeline)} entries",
            "=" * 100,
            "",
        ]
        if omitted:
            lines.append(f"  ... ({omitted} earlier entries omitted)\n")
        for e in shown:
            sev = e.severity.name[0]  # F/E/W/I/D
            lines.append(f"{e.timestamp} {sev} [{e.source:<7}] {e.text[:180]}")
        lines.append(f"\n{'=' * 100}")
        atomic_write(path, "\n".join(lines))

    def write_server_errors(self, state: SessionState) -> None:
        path = self._out / "server_errors.txt"
        entries = state.get_entries("Server")
        errors = [e for e in entries if e.severity >= Severity.ERROR]
        warns = [e for e in entries if e.severity == Severity.WARN]

        lines = [
            "=" * 100,
            f"Server.log -- {_now()}",
            f"Errors: {len(errors)}  |  Warnings: {len(warns)}",
            "=" * 100,
        ]

        if errors:
            lines.append(f"\n--- ERRORS / FATALS ({len(errors)}) ---\n")
            for e in errors[-100:]:
                lines.append(f"  Line {e.line_number}: {e.text}")
                if self._verbose and "context" in e.metadata:
                    for ctx in e.metadata["context"]:
                        lines.append(f"    | {ctx}")
                    lines.append("")
        else:
            lines.append("\nNo errors or fatals.")

        if self._verbose and warns:
            # Deduplicate warning patterns
            warn_counts: Counter = Counter()
            for e in warns:
                key = e.text[:120]
                warn_counts[key] += 1
            lines.append(f"\n--- WARNING PATTERNS ({len(warns)} total) ---\n")
            for pat, count in warn_counts.most_common(30):
                lines.append(f"  [{count:>5}x] {pat}")

        lines.append(f"\n{'=' * 100}\n")
        atomic_write(path, "\n".join(lines))

    def write_db_errors(self, state: SessionState) -> None:
        path = self._out / "db_errors_summary.txt"
        entries = state.get_entries("DBError")
        cat_counts = state.get_category_counts("DBError")
        total = len(entries)
        uncat = cat_counts.pop("uncategorized", 0)
        categorized = total - uncat

        lines = [
            "=" * 100,
            f"DBErrors.log -- {_now()}",
            f"Lines: {total:,}  |  Categorized: {categorized:,}  |  Uncategorized: {uncat:,}",
            "=" * 100,
            "",
        ]

        if cat_counts:
            lines.append(f"{'Category':<50s} {'Count':>8s}")
            lines.append("-" * 60)
            for cat, count in cat_counts.most_common():
                lines.append(f"  {cat:<48s} {count:>8,}")
            lines.append("-" * 60)
            lines.append(f"  {'TOTAL':<48s} {categorized:>8,}")

        if uncat:
            # Show samples of uncategorized
            uncat_entries = [e for e in entries if e.category == "uncategorized"]
            lines.append(f"\n--- UNCATEGORIZED ({uncat}) ---\n")
            seen: set[str] = set()
            for e in uncat_entries[:25]:
                key = e.text[:80]
                if key not in seen:
                    seen.add(key)
                    lines.append(f"  {e.text[:200]}")

        lines.append(f"\n{'=' * 100}\n")
        atomic_write(path, "\n".join(lines))

    def write_debug_summary(self, state: SessionState) -> None:
        path = self._out / "debug_summary.txt"
        entries = state.get_entries("Debug")
        cat_counts = state.get_category_counts("Debug")

        lines = [
            "=" * 100,
            f"Debug.log -- {_now()}",
            f"Interesting: {len(entries):,}",
            "=" * 100,
        ]

        prio = ["Errors", "Transmog", "RolePlay/NPC", "Companion", "VoxPlacer", "Packets", "Other"]
        for cat in prio:
            cat_entries = [e for e in entries if e.category == cat]
            if not cat_entries:
                continue
            limit = 200 if self._verbose else 50
            lines.append(f"\n--- {cat} ({len(cat_entries)}) ---\n")
            shown = cat_entries[-limit:]
            if len(cat_entries) > limit:
                lines.append(f"  ... ({len(cat_entries) - limit} earlier omitted)")
            for e in shown:
                lines.append(f"  [{e.line_number:>7}] {e.text[:200]}")

        if not entries:
            lines.append("\nNo interesting entries yet.")

        lines.append(f"\n{'=' * 100}\n")
        atomic_write(path, "\n".join(lines))

    def write_gm_commands(self, state: SessionState) -> None:
        path = self._out / "gm_commands.txt"
        entries = state.get_entries("GM")

        lines = [
            "=" * 100,
            f"GM Commands -- {_now()}  ({len(entries)} commands)",
            "=" * 100,
            "",
        ]

        if entries:
            verb_counts: Counter = Counter()
            for e in entries:
                verb_counts[e.metadata.get("verb", "?")] += 1

            lines.append("--- COMMAND FREQUENCY ---\n")
            for verb, count in verb_counts.most_common(20):
                lines.append(f"  {verb:<30s} {count:>5}")

            limit = len(entries) if self._verbose else 200
            shown = entries[-limit:]
            lines.append(f"\n--- FULL LOG ({len(entries)} entries) ---\n")
            if len(entries) > limit:
                lines.append(f"  ... ({len(entries) - limit} earlier omitted)")
            for e in shown:
                cmd = e.metadata.get("command", "?")
                player = e.metadata.get("player", "?")
                lines.append(f"  [{e.timestamp}] {cmd:<50s} ({player})")
        else:
            lines.append("No GM commands recorded.")

        lines.append(f"\n{'=' * 100}\n")
        atomic_write(path, "\n".join(lines))

    def write_crashes(self, state: SessionState) -> None:
        crashes = state.get_entries("Crash")
        if not crashes:
            return

        path = self._out / "crashes.txt"
        lines = [
            "=" * 100,
            f"Crash Dumps -- {_now()}  ({len(crashes)} dumps)",
            "=" * 100,
            "",
        ]

        for e in crashes:
            m = e.metadata
            lines.append(f"  [{m.get('date', '?')} {e.timestamp}] {e.text}")
            if m.get("dmp_size"):
                txt = m.get("txt_file", "unknown.txt")
                lines.append(f"    DMP: {txt.replace('.txt', '.dmp')} ({m['dmp_size']:,} bytes)")
            lines.append("")

        atomic_write(path, "\n".join(lines))

    def write_session_summary(self, state: SessionState) -> None:
        """Generate a session summary on server stop / archive."""
        path = self._out / "session_summary.txt"
        now = _now()
        total_entries = len(state.all_entries)
        fatals = sum(1 for e in state.all_entries if e.severity >= Severity.FATAL)
        errors = sum(1 for e in state.all_entries if e.severity == Severity.ERROR)
        warns = sum(1 for e in state.all_entries if e.severity == Severity.WARN)
        gm_count = len(state.get_entries("GM"))
        crash_count = len(state.get_entries("Crash"))

        lines = [
            "=" * 100,
            f"SESSION SUMMARY -- {state.session_start.strftime('%Y-%m-%d %H:%M')} -> {now}",
            f"Uptime: {state.uptime_str}  |  Polls: {state.poll_count}",
            "=" * 100,
            "",
            f"  Total entries:  {total_entries:>8,}",
            f"  FATAL:          {fatals:>8,}",
            f"  ERROR:          {errors:>8,}",
            f"  WARN:           {warns:>8,}",
            f"  GM commands:    {gm_count:>8,}",
            f"  Crash dumps:    {crash_count:>8,}",
            "",
        ]

        # Top DB error categories
        db_counts = state.get_category_counts("DBError")
        if db_counts:
            lines.append("--- Top DB Error Categories ---\n")
            for cat, count in db_counts.most_common(10):
                lines.append(f"  {cat:<48s} {count:>8,}")
            lines.append("")

        # Top GM commands
        gm_entries = state.get_entries("GM")
        if gm_entries:
            verb_counts: Counter = Counter()
            for e in gm_entries:
                verb_counts[e.metadata.get("verb", "?")] += 1
            lines.append("--- Top GM Commands ---\n")
            for verb, count in verb_counts.most_common(10):
                lines.append(f"  {verb:<30s} {count:>5}")
            lines.append("")

        lines.append(f"{'=' * 100}\n")
        atomic_write(path, "\n".join(lines))

    def write_session_brief(self, state: SessionState) -> None:
        """Generate a Master Markdown Brief intended for Antigravity ingestion."""
        path = self._out / "_Session_Brief.md"
        now = _now()
        fatals = sum(1 for e in state.all_entries if e.severity >= Severity.FATAL)
        errors = sum(1 for e in state.all_entries if e.severity == Severity.ERROR)
        gm_count = len(state.get_entries("GM"))
        crash_count = len(state.get_entries("Crash"))

        lines = [
            f"![VoxCore Seal](C:/Users/atayl/VoxCore/wago/att_icons_export/Class_Race_Profession_Icons/ABILITY_SEAL.PNG)",
            f"# VoxCore Session Brief",
            f"**Session Start:** `{state.session_start.strftime('%Y-%m-%d %H:%M')}` | **Ended:** `{now}`",
            f"**Uptime:** `{state.uptime_str}` | **Total Logs:** `{len(state.all_entries):,}`\n",
            "## 1. Crash Telemetry",
        ]

        if crash_count:
            crashes = state.get_entries("Crash")
            for e in crashes:
                m = e.metadata
                txt = m.get("txt_file", "unknown")
                lines.append(f"- **{e.timestamp}**: `{e.text}` *(Dump: {txt})*")
        else:
            lines.append("> No server crashes detected in this session.")
        
        lines.append("\n## 2. Error Volume")
        lines.append(f"- **Server Fatals:** `{fatals}`")
        lines.append(f"- **Server Errors:** `{errors}`")

        db_counts = state.get_category_counts("DBError")
        if db_counts:
            lines.append("\n### Top DB Error Signatures")
            for cat, count in db_counts.most_common(5):
                lines.append(f"- `{cat}`: **{count}** occurrences")

        lines.append("\n## 3. Operations & Anomalies")
        lines.append(f"- **GM Commands Issued**: `{gm_count}`")
        
        lines.append("\n## 4. Packet Analysis")
        # For pipeline data generated right before this brief
        pkt_scope = self._out / "packetscope_report.txt"
        if pkt_scope.exists():
            lines.append("`packet_scope.py` report detected in PacketLog.")
        else:
            lines.append("> No specific packet anomalies extracted.")

        atomic_write(path, "\n".join(lines))


def _now() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")

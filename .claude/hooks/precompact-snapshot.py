#!/usr/bin/env python3
"""PreCompact hook: snapshot active work context before compaction destroys it.

PROBLEM: When Claude Code compacts context, the nuance of what you were doing
is lost. The compact-reinject hook fires AFTER and can only inject static
reminders. This hook fires BEFORE and captures REAL state.

APPROACH: Read session-stats.jsonl (written by our PostToolUse hook) to see
what files were recently touched, what tools were used, and build a structured
snapshot. The compact-reinject hook reads this snapshot to restore real context.

Output: Writes ~/.claude/precompact-state.json with recent activity summary.
"""
import json
import os
import sys
from datetime import datetime, timezone, timedelta
from collections import Counter

STATS_FILE = os.path.expanduser("~/.claude/session-stats.jsonl")
SNAPSHOT_FILE = os.path.expanduser("~/.claude/precompact-state.json")


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        data = {}

    # Read recent tool uses from session-stats.jsonl
    recent_tools = []
    recent_files = []
    cutoff = datetime.now(timezone.utc) - timedelta(hours=2)

    try:
        with open(STATS_FILE, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                # Parse timestamp, keep only recent entries
                ts_str = entry.get("timestamp", "")
                try:
                    ts = datetime.fromisoformat(ts_str)
                    if ts < cutoff:
                        continue
                except (ValueError, TypeError):
                    continue

                tool = entry.get("tool", "")
                if tool:
                    recent_tools.append(tool)

                # Collect file paths from any key
                for key in ("file_path", "path", "pattern"):
                    if key in entry:
                        recent_files.append(entry[key])
    except FileNotFoundError:
        pass

    # Build snapshot
    tool_counts = Counter(recent_tools)
    # Dedupe files, keep order, last 20
    seen = set()
    unique_files = []
    for f in reversed(recent_files):
        if f not in seen:
            seen.add(f)
            unique_files.append(f)
    unique_files = list(reversed(unique_files[-20:]))

    # Identify what kind of work was happening
    work_signals = []
    cpp_files = [f for f in unique_files if f.endswith(('.cpp', '.h'))]
    sql_files = [f for f in unique_files if f.endswith('.sql')]
    md_files = [f for f in unique_files if f.endswith('.md')]
    transmog_files = [f for f in unique_files if 'transmog' in f.lower() or 'display' in f.lower()]

    if cpp_files:
        work_signals.append(f"C++ editing: {', '.join(os.path.basename(f) for f in cpp_files[:5])}")
    if sql_files:
        work_signals.append(f"SQL work: {', '.join(os.path.basename(f) for f in sql_files[:5])}")
    if transmog_files:
        work_signals.append("Transmog system work detected")
    if tool_counts.get("Agent", 0) > 0:
        work_signals.append(f"Spawned {tool_counts['Agent']} subagent(s)")

    snapshot = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "trigger": data.get("trigger", "unknown"),
        "recent_files": unique_files,
        "tool_usage": dict(tool_counts.most_common(10)),
        "work_signals": work_signals,
        "cpp_files_touched": cpp_files,
        "sql_files_touched": sql_files,
    }

    try:
        with open(SNAPSHOT_FILE, "w", encoding="utf-8") as f:
            json.dump(snapshot, f, indent=2)
    except Exception:
        pass

    # Print summary to stderr (Claude sees this)
    if work_signals:
        print(f"Pre-compaction snapshot saved: {', '.join(work_signals)}", file=sys.stderr)


if __name__ == "__main__":
    main()

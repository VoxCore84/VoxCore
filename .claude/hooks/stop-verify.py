#!/usr/bin/env python3
"""Stop hook: VoxCore-specific workflow enforcement.

PROBLEM: The community pattern uses a Haiku LLM call on every stop to ask
"is work complete?" That burns tokens and is too generic to catch real issues.

APPROACH: Fast Python heuristics checking for VoxCore-specific workflow
violations. Reads session-stats.jsonl to see what happened this session,
then checks for common mistakes:

1. C++ files edited without build reminder
2. SQL files created/modified without /apply-sql reminder
3. Session ending without /wrap-up
4. Shared files modified without session_state.md check

This runs in <50ms (pure Python, no API calls) and only outputs when it
catches something. Zero noise on clean stops.
"""
import json
import os
import sys
from datetime import datetime, timezone, timedelta

STATS_FILE = os.path.expanduser("~/.claude/session-stats.jsonl")


def get_recent_activity(minutes: int = 120) -> dict:
    """Read session-stats.jsonl and return categorized recent activity."""
    activity = {
        "cpp_edits": [],
        "sql_edits": [],
        "shared_file_edits": [],
        "tools_used": set(),
        "files_touched": [],
    }

    cutoff = datetime.now(timezone.utc) - timedelta(minutes=minutes)

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

                ts_str = entry.get("timestamp", "")
                try:
                    ts = datetime.fromisoformat(ts_str)
                    if ts < cutoff:
                        continue
                except (ValueError, TypeError):
                    continue

                tool = entry.get("tool", "")
                if tool:
                    activity["tools_used"].add(tool)

                file_path = entry.get("file_path", "") or entry.get("path", "")
                if not file_path:
                    continue

                activity["files_touched"].append(file_path)
                lower = file_path.lower()

                if lower.endswith((".cpp", ".h")):
                    activity["cpp_edits"].append(file_path)
                elif lower.endswith(".sql"):
                    activity["sql_edits"].append(file_path)

                # Shared files that need session_state coordination
                if any(shared in lower for shared in [
                    "session_state.md", "custom_script_loader",
                    "roleplay.h", "roleplay.cpp",
                ]):
                    activity["shared_file_edits"].append(file_path)

    except FileNotFoundError:
        pass

    return activity


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    # Read Claude's last output to detect session-ending language
    transcript = str(data.get("transcript_suffix", ""))
    transcript_lower = transcript.lower()

    activity = get_recent_activity()
    reminders = []

    # --- Check 1: C++ edits without build reminder ---
    if activity["cpp_edits"]:
        cpp_basenames = list(set(os.path.basename(f) for f in activity["cpp_edits"]))[:5]
        reminders.append(
            f"C++ files edited ({', '.join(cpp_basenames)}) — "
            "remind user to build in Visual Studio."
        )

    # --- Check 2: SQL files without apply reminder ---
    if activity["sql_edits"]:
        sql_basenames = list(set(os.path.basename(f) for f in activity["sql_edits"]))[:5]
        reminders.append(
            f"SQL files touched ({', '.join(sql_basenames)}) — "
            "remind about /apply-sql or pending SQL pipeline."
        )

    # --- Check 3: Session ending without /wrap-up ---
    wrap_indicators = [
        "that should do it", "all done", "everything is complete",
        "let me know if", "anything else", "good to go",
        "that covers", "we're done", "wrapping up",
    ]
    session_ending = any(ind in transcript_lower for ind in wrap_indicators)

    if session_ending:
        reminders.append(
            "Session appears to be ending — run /wrap-up to commit, "
            "push, sync bridge, and update memory."
        )

    # --- Check 4: Shared files without session_state check ---
    if activity["shared_file_edits"]:
        shared_basenames = list(set(os.path.basename(f) for f in activity["shared_file_edits"]))
        reminders.append(
            f"Shared files modified ({', '.join(shared_basenames)}) — "
            "check doc/session_state.md for multi-tab coordination."
        )

    # Output reminders (Claude sees these as hook feedback)
    if reminders:
        print("WORKFLOW CHECK:\n" + "\n".join(f"  - {r}" for r in reminders))

    sys.exit(0)  # Never block — just advise


if __name__ == "__main__":
    main()

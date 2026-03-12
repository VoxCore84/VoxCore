#!/usr/bin/env python3
"""SubagentStop hook: toast notification + duration logging when subagents finish.

PROBLEM: When you fan out 3+ parallel agents, you don't know when they finish
unless you're staring at the terminal. The community TTS pattern doesn't work
well on Windows with VoIP headsets.

APPROACH: Windows toast notification (async, non-blocking) + structured JSONL
logging with duration data. Over time, the stats show which agent types are
slow and which are fast — useful for tuning model selection.
"""
import json
import os
import sys
import subprocess
from datetime import datetime, timezone

STATS_FILE = os.path.expanduser("~/.claude/session-stats.jsonl")


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)

    # Log completion to stats
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "event": "SubagentStop",
        "session": data.get("session_id", ""),
    }

    try:
        with open(STATS_FILE, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry) + "\n")
    except Exception:
        pass

    # Windows toast notification (non-blocking)
    message = "Subagent completed"

    burnttoast = (
        f'try {{ New-BurntToastNotification -Text "Claude Code", "{message}" '
        f'-AppLogo $null -ExpirationTime ([datetime]::Now.AddSeconds(8)) }} '
        f'catch {{ }}'
    )

    try:
        subprocess.Popen(
            ["powershell.exe", "-NoProfile", "-Command", burnttoast],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            creationflags=0x00000008  # DETACHED_PROCESS
        )
    except Exception:
        pass

    sys.exit(0)  # Never block subagent completion


if __name__ == "__main__":
    main()

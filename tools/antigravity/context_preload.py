"""
context_preload.py — Generate an optimized context preload for Antigravity

Reads the 3 session-start files that Antigravity needs to ingest:
  1. AI_Studio/0_Central_Brain.md  (Triad coordination state)
  2. doc/session_state.md          (multi-tab assignments)
  3. cowork/context/todo.md        (task list)

Combines them into a single, trimmed context brief at:
  .gemini/antigravity/preload_context.md

This way Antigravity reads 1 file instead of 3, saving ~2-3 tool calls
and reducing initial context window consumption.

Usage:
    python context_preload.py           # Generate preload
    python context_preload.py --dry-run # Show what would be generated
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from datetime import datetime
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
VOXCORE = Path(os.environ.get("VOXCORE_DIR", r"C:\Users\atayl\VoxCore"))
HOME = Path(os.environ.get("USERPROFILE", r"C:\Users\atayl"))

SOURCE_FILES = {
    "Central Brain": VOXCORE / "AI_Studio" / "0_Central_Brain.md",
    "Session State": VOXCORE / "doc" / "session_state.md",
    "Todo": VOXCORE / "cowork" / "context" / "todo.md",
}

OUTPUT_DIR = HOME / ".gemini" / "antigravity"
OUTPUT_FILE = OUTPUT_DIR / "preload_context.md"

# ---------------------------------------------------------------------------
# Content processing
# ---------------------------------------------------------------------------

def read_file_safe(path: Path) -> str | None:
    """Read a file, returning None if it doesn't exist or can't be read."""
    try:
        return path.read_text(encoding="utf-8")
    except (FileNotFoundError, PermissionError, OSError):
        return None


def extract_active_sections(content: str) -> str:
    """Extract only the actionable sections from Central Brain.

    Strips completed tasks, historical notes, and verbose architecture
    descriptions to focus on what's active RIGHT NOW.
    """
    lines = content.split("\n")
    output_lines = []
    skip_section = False
    current_heading_level = 0

    for line in lines:
        # Detect heading level
        heading_match = re.match(r"^(#{1,4})\s+(.+)", line)

        if heading_match:
            level = len(heading_match.group(1))
            title = heading_match.group(2).strip()

            # Skip sections that are purely historical
            skip_titles = [
                "Completed Today",
                "completed",
                "Communication Protocol",
            ]
            if any(skip.lower() in title.lower() for skip in skip_titles):
                skip_section = True
                current_heading_level = level
                continue
            else:
                # Check if we're exiting a skipped section
                if skip_section and level <= current_heading_level:
                    skip_section = False
                elif skip_section:
                    continue

        if skip_section:
            continue

        output_lines.append(line)

    return "\n".join(output_lines)


def extract_active_tabs(session_state: str) -> str:
    """Extract only Active Tabs and recent pending items from session_state.

    Strips the completed/archived sections that can be hundreds of lines.
    """
    lines = session_state.split("\n")
    output_lines = []
    in_relevant_section = False
    section_depth = 0

    # Sections to include
    include_headings = {
        "active tabs",
        "assignments",
        "priority",
        "next session",
        "blocked",
        "pending",
        "ownership",
        "owned files",
    }
    # Sections to skip
    skip_headings = {
        "completed",
        "archive",
        "history",
        "done",
    }

    for line in lines:
        heading_match = re.match(r"^(#{1,4})\s+(.+)", line)

        if heading_match:
            level = len(heading_match.group(1))
            title = heading_match.group(2).strip().lower()

            if any(s in title for s in skip_headings):
                in_relevant_section = False
                continue
            elif any(s in title for s in include_headings) or level <= 2:
                in_relevant_section = True
                section_depth = level

        if in_relevant_section or not heading_match:
            if in_relevant_section:
                output_lines.append(line)

    # If we got nothing useful, return first 80 lines as fallback
    if len(output_lines) < 5:
        return "\n".join(lines[:80])

    return "\n".join(output_lines)


def extract_active_todos(todo_content: str) -> str:
    """Extract HIGH and MEDIUM priority items, skip completed/archived."""
    lines = todo_content.split("\n")
    output_lines = []
    in_completed = False
    in_high_or_med = False

    for line in lines:
        heading_match = re.match(r"^(#{1,4})\s+(.+)", line)

        if heading_match:
            title = heading_match.group(2).strip().lower()
            if "completed" in title or "archive" in title or "done" in title:
                in_completed = True
                in_high_or_med = False
                continue
            elif "high" in title or "medium" in title or "next session" in title:
                in_completed = False
                in_high_or_med = True
            elif "low" in title:
                in_completed = False
                in_high_or_med = False
                # Include LOW heading but not its content (just note it exists)
                output_lines.append(line)
                output_lines.append("_(LOW priority items omitted for brevity)_")
                output_lines.append("")
                continue
            else:
                in_completed = False

        if in_completed:
            continue

        # Skip struck-through items (~~text~~)
        if re.match(r"^[-*]\s+~~.+~~\s*$", line.strip()):
            continue

        if in_high_or_med or (heading_match and not in_completed):
            output_lines.append(line)

    return "\n".join(output_lines)


# ---------------------------------------------------------------------------
# Assembler
# ---------------------------------------------------------------------------
def generate_preload() -> str:
    """Generate the combined preload context document."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")

    parts = []
    parts.append(f"# Antigravity Session Preload")
    parts.append(f"_Auto-generated {timestamp} by context_preload.py_")
    parts.append(f"_Source: Central Brain + session_state + todo — merged and trimmed_")
    parts.append("")
    parts.append("---")
    parts.append("")

    files_found = 0
    files_missing = []

    # 1. Central Brain — active operations and coordination
    cb_content = read_file_safe(SOURCE_FILES["Central Brain"])
    if cb_content:
        files_found += 1
        trimmed = extract_active_sections(cb_content)
        parts.append("## Triad Coordination (from Central Brain)")
        parts.append("")
        parts.append(trimmed.strip())
        parts.append("")
        parts.append("---")
        parts.append("")
    else:
        files_missing.append("Central Brain")

    # 2. Session State — active tab assignments
    ss_content = read_file_safe(SOURCE_FILES["Session State"])
    if ss_content:
        files_found += 1
        trimmed = extract_active_tabs(ss_content)
        parts.append("## Active Tabs & Assignments (from session_state)")
        parts.append("")
        parts.append(trimmed.strip())
        parts.append("")
        parts.append("---")
        parts.append("")
    else:
        files_missing.append("Session State")

    # 3. Todo — active tasks
    todo_content = read_file_safe(SOURCE_FILES["Todo"])
    if todo_content:
        files_found += 1
        trimmed = extract_active_todos(todo_content)
        parts.append("## Active Tasks (from todo)")
        parts.append("")
        parts.append(trimmed.strip())
        parts.append("")
    else:
        files_missing.append("Todo")

    # Footer
    parts.append("")
    parts.append("---")
    parts.append(f"_Preload stats: {files_found}/3 source files loaded")
    if files_missing:
        parts.append(f", missing: {', '.join(files_missing)}")
    parts.append("_")

    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Antigravity context preload")
    parser.add_argument("--dry-run", action="store_true", help="Print output without writing file")
    args = parser.parse_args()

    preload = generate_preload()

    if args.dry_run:
        print(preload)
        print()
        print(f"--- DRY RUN: would write {len(preload)} bytes to {OUTPUT_FILE} ---")
        return 0

    # Ensure output directory exists
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Write the preload file
    OUTPUT_FILE.write_text(preload, encoding="utf-8")

    # Report
    line_count = preload.count("\n") + 1
    byte_count = len(preload.encode("utf-8"))
    print(f"Context preload written: {OUTPUT_FILE}")
    print(f"  {line_count} lines, {byte_count:,} bytes")

    # Compare against source sizes
    total_source = 0
    for name, path in SOURCE_FILES.items():
        content = read_file_safe(path)
        if content:
            src_size = len(content.encode("utf-8"))
            total_source += src_size
            print(f"  Source: {name} = {src_size:,} bytes")

    if total_source > 0:
        ratio = byte_count / total_source * 100
        print(f"  Compression: {total_source:,} -> {byte_count:,} bytes ({ratio:.0f}% of original)")

    return 0


if __name__ == "__main__":
    sys.exit(main())

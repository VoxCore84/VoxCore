"""Export normalized data and deltas to JSONL files."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def export_jsonl(data: list[dict], path: Path):
    """Write a list of dicts to a JSONL file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        for record in data:
            f.write(json.dumps(record, ensure_ascii=False, default=str) + '\n')


def export_normalized(normalized: dict[str, dict], out_dir: Path) -> dict[str, int]:
    """Export all normalized domain data to per-domain JSONL files.

    Returns counts per domain.
    """
    out_dir.mkdir(parents=True, exist_ok=True)
    counts = {}

    for domain, data in normalized.items():
        if not data:
            continue

        records = list(data.values()) if isinstance(data, dict) else data
        out_file = out_dir / f"{domain}.jsonl"
        export_jsonl(records, out_file)
        counts[domain] = len(records)

    return counts

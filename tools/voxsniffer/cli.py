"""VoxSniffer CLI — pipeline entry point.

Usage:
    python -m voxsniffer ingest --input <SavedVariables.lua> [--session <id>]
    python -m voxsniffer normalize --input <SavedVariables.lua> [--session <id>]
    python -m voxsniffer delta --input <SavedVariables.lua> --baseline <baseline.json>
    python -m voxsniffer status --input <SavedVariables.lua>
    python -m voxsniffer sessions --input <SavedVariables.lua>
    python -m voxsniffer pipeline --input <SavedVariables.lua> --baseline <baseline.json>
"""

import argparse
import json
import sys
from pathlib import Path

from .config import ensure_dirs, SESSIONS_DIR, NORMALIZED_DIR, DELTAS_DIR, SQL_DIR
from .parsers.savedvariables_loader import SavedVariablesLoader, SchemaError


def _load_records(args) -> tuple[SavedVariablesLoader, list[dict]] | tuple[None, None]:
    """Common loader for commands that need records."""
    loader = SavedVariablesLoader(args.input)
    try:
        loader.load()
    except (FileNotFoundError, SchemaError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return None, None

    warnings = loader.validate()
    for w in warnings:
        print(f"Warning: {w}", file=sys.stderr)

    session_id = getattr(args, 'session', None)
    records = loader.get_all_records(session_id=session_id)
    return loader, records


def cmd_ingest(args):
    """Ingest a SavedVariables file and export raw JSON by module."""
    ensure_dirs()
    loader, records = _load_records(args)
    if loader is None:
        return 1

    if not records:
        print("No records found.", file=sys.stderr)
        return 1

    # Group records by module
    by_module: dict[str, list] = {}
    for rec in records:
        if isinstance(rec, dict):
            mod = rec.get("src") or "unknown"
            by_module.setdefault(mod, []).append(rec)

    # Export
    session_id = getattr(args, 'session', None)
    out_dir = SESSIONS_DIR / f"session_{session_id or 'all'}"
    out_dir.mkdir(parents=True, exist_ok=True)

    total = 0
    for module, recs in by_module.items():
        out_file = out_dir / f"{module}.jsonl"
        with open(out_file, 'w', encoding='utf-8') as f:
            for rec in recs:
                f.write(json.dumps(rec, ensure_ascii=False, default=str) + '\n')
        total += len(recs)
        print(f"  {module}: {len(recs)} records -> {out_file.name}")

    print(f"\nIngested {total} records from {len(by_module)} modules -> {out_dir}")
    return 0


def cmd_normalize(args):
    """Normalize raw observations into domain models."""
    ensure_dirs()
    loader, records = _load_records(args)
    if loader is None:
        return 1

    if not records:
        print("No records found.", file=sys.stderr)
        return 1

    from .normalize import normalize_all
    from .exporters import export_normalized

    print(f"Normalizing {len(records)} records...")
    normalized = normalize_all(records)

    session_id = getattr(args, 'session', None)
    out_dir = NORMALIZED_DIR / f"session_{session_id or 'all'}"
    counts = export_normalized(normalized, out_dir)

    print(f"\nNormalized output -> {out_dir}")
    for domain, count in sorted(counts.items()):
        print(f"  {domain}: {count} entities")
    print(f"  Total: {sum(counts.values())} entities across {len(counts)} domains")
    return 0


def cmd_delta(args):
    """Compare normalized observations against a baseline."""
    ensure_dirs()
    loader, records = _load_records(args)
    if loader is None:
        return 1

    if not records:
        print("No records found.", file=sys.stderr)
        return 1

    from .normalize import NORMALIZER_MAP
    from .delta import DeltaEngine

    # Load baseline
    baseline_path = Path(args.baseline)
    if not baseline_path.exists():
        print(f"Error: Baseline not found: {baseline_path}", file=sys.stderr)
        return 1

    engine = DeltaEngine()
    engine.load_baseline(baseline_path)
    print(f"Loaded baseline: {baseline_path.name}")

    # Normalize relevant domains
    print(f"Processing {len(records)} records...")

    unit_norm = NORMALIZER_MAP.get("unit_seen")
    if unit_norm:
        creatures = unit_norm.normalize(records)
        if creatures:
            deltas = engine.compare_creatures(creatures)
            print(f"  Creatures: {len(creatures)} observed, {len(deltas)} deltas")

    combat_norm = NORMALIZER_MAP.get("combat_event")
    if combat_norm:
        combat = combat_norm.normalize(records)
        if combat:
            deltas = engine.compare_combat(combat)
            print(f"  Combat: {len(combat)} NPCs, {len(deltas)} deltas")

    vendor_norm = NORMALIZER_MAP.get("vendor_snapshot")
    if vendor_norm:
        vendors = vendor_norm.normalize(records)
        if vendors:
            deltas = engine.compare_vendors(vendors)
            print(f"  Vendors: {len(vendors)} NPCs, {len(deltas)} deltas")

    # Summary
    summary = engine.get_summary()
    print(f"\nDelta Summary: {summary['totalDeltas']} total")
    for dtype, count in sorted(summary["byType"].items()):
        print(f"  {dtype}: {count}")

    # Export
    session_id = getattr(args, 'session', None)
    out_file = DELTAS_DIR / f"deltas_{session_id or 'all'}.jsonl"
    engine.export_deltas(out_file)
    print(f"\nDeltas exported -> {out_file}")

    # Generate SQL if deltas exist
    if engine.deltas:
        from .exporters import SQLExporter
        sql_exp = SQLExporter(SQL_DIR)
        sql_exp.generate_creature_spells(engine.deltas)
        sql_exp.generate_vendor_items(engine.deltas)
        sql_path = sql_exp.write(f"voxsniffer_session_{session_id or 'all'}.sql")
        if sql_path:
            print(f"SQL generated -> {sql_path}")

    return 0


def cmd_pipeline(args):
    """Full pipeline: ingest -> normalize -> delta -> SQL."""
    ensure_dirs()
    loader, records = _load_records(args)
    if loader is None:
        return 1

    if not records:
        print("No records found.", file=sys.stderr)
        return 1

    session_id = getattr(args, 'session', None)
    tag = f"session_{session_id or 'all'}"
    print(f"=== VoxSniffer Pipeline ({tag}) ===")
    print(f"Records: {len(records)}")

    # Step 1: Raw ingest
    by_module: dict[str, list] = {}
    for rec in records:
        if isinstance(rec, dict):
            mod = rec.get("src") or "unknown"
            by_module.setdefault(mod, []).append(rec)

    raw_dir = SESSIONS_DIR / tag
    raw_dir.mkdir(parents=True, exist_ok=True)
    for module, recs in by_module.items():
        out_file = raw_dir / f"{module}.jsonl"
        with open(out_file, 'w', encoding='utf-8') as f:
            for rec in recs:
                f.write(json.dumps(rec, ensure_ascii=False, default=str) + '\n')
    print(f"\n[1/4] Raw ingest: {sum(len(v) for v in by_module.values())} records, {len(by_module)} modules -> {raw_dir}")

    # Step 2: Normalize
    from .normalize import normalize_all, NORMALIZER_MAP
    from .exporters import export_normalized

    normalized = normalize_all(records)
    norm_dir = NORMALIZED_DIR / tag
    counts = export_normalized(normalized, norm_dir)
    print(f"[2/4] Normalize: {sum(counts.values())} entities, {len(counts)} domains -> {norm_dir}")
    for domain, count in sorted(counts.items()):
        print(f"       {domain}: {count}")

    # Step 3: Delta (if baseline provided)
    baseline_path = Path(args.baseline) if hasattr(args, 'baseline') and args.baseline else None
    if baseline_path and baseline_path.exists():
        from .delta import DeltaEngine

        engine = DeltaEngine()
        engine.load_baseline(baseline_path)

        unit_data = normalized.get("unit_seen", {})
        if unit_data:
            engine.compare_creatures(unit_data)

        combat_data = normalized.get("combat_event", {})
        if combat_data:
            engine.compare_combat(combat_data)

        vendor_data = normalized.get("vendor_snapshot", {})
        if vendor_data:
            engine.compare_vendors(vendor_data)

        summary = engine.get_summary()
        delta_file = DELTAS_DIR / f"deltas_{tag}.jsonl"
        engine.export_deltas(delta_file)
        print(f"[3/4] Delta: {summary['totalDeltas']} deltas -> {delta_file}")
        for dtype, count in sorted(summary["byType"].items()):
            print(f"       {dtype}: {count}")

        # Step 4: SQL
        if engine.deltas:
            from .exporters import SQLExporter
            sql_exp = SQLExporter(SQL_DIR)
            sql_exp.generate_creature_spells(engine.deltas)
            sql_exp.generate_vendor_items(engine.deltas)
            sql_path = sql_exp.write(f"voxsniffer_{tag}.sql")
            if sql_path:
                print(f"[4/4] SQL: {len(sql_exp.statements)} lines -> {sql_path}")
            else:
                print("[4/4] SQL: no statements generated")
        else:
            print("[4/4] SQL: no deltas, skipped")
    else:
        print("[3/4] Delta: skipped (no baseline)")
        print("[4/4] SQL: skipped")

    print(f"\n=== Pipeline complete ===")
    return 0


def cmd_status(args):
    """Show status of a SavedVariables file."""
    loader = SavedVariablesLoader(args.input)
    try:
        loader.load()
    except (FileNotFoundError, SchemaError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    warnings = loader.validate()

    db = loader.db
    print(f"Schema version: {db.get('schema_version', '?')}")
    print(f"Build info: {db.get('build_info', {})}")

    stats = loader.get_stats()
    print(f"Stats:")
    for k, v in stats.items():
        print(f"  {k}: {v}")

    sessions = loader.get_sessions()
    print(f"\nSessions: {len(sessions)}")
    for sid, session in sessions.items():
        label = session.get('label', '')
        obs = session.get('observation_count', 0)
        chunks = session.get('chunk_count', 0)
        char = session.get('character', '?')
        print(f"  #{sid}: {char} — {obs} obs, {chunks} chunks{' [' + label + ']' if label else ''}")

    chunks = loader.db.get('chunks', {})
    print(f"\nChunks: {len(chunks)}")

    # Module breakdown
    module_counts: dict[str, int] = {}
    for chunk in (chunks if isinstance(chunks, list) else chunks.values()):
        if isinstance(chunk, dict):
            mod = chunk.get('module', 'unknown')
            module_counts[mod] = module_counts.get(mod, 0) + chunk.get('count', 0)
    for mod, count in sorted(module_counts.items()):
        print(f"  {mod}: {count} records")

    if warnings:
        print(f"\nWarnings:")
        for w in warnings:
            print(f"  {w}")

    return 0


def cmd_sessions(args):
    """List all sessions in a SavedVariables file."""
    loader = SavedVariablesLoader(args.input)
    try:
        loader.load()
    except (FileNotFoundError, SchemaError) as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    sessions = loader.get_sessions()
    if not sessions:
        print("No sessions found.")
        return 0

    for sid, session in sessions.items():
        print(json.dumps({"session_id": sid, **session}, ensure_ascii=False, default=str, indent=2))

    return 0


def main():
    parser = argparse.ArgumentParser(prog="voxsniffer", description="VoxSniffer data pipeline")
    sub = parser.add_subparsers(dest="command", required=True)

    # Ingest
    p_ingest = sub.add_parser("ingest", help="Ingest SavedVariables and export raw JSON")
    p_ingest.add_argument("--input", "-i", required=True, help="Path to VoxSniffer.lua SavedVariables")
    p_ingest.add_argument("--session", "-s", type=int, default=None, help="Filter to specific session ID")

    # Normalize
    p_norm = sub.add_parser("normalize", help="Normalize observations into domain models")
    p_norm.add_argument("--input", "-i", required=True, help="Path to VoxSniffer.lua SavedVariables")
    p_norm.add_argument("--session", "-s", type=int, default=None, help="Filter to specific session ID")

    # Delta
    p_delta = sub.add_parser("delta", help="Compare observations against baseline")
    p_delta.add_argument("--input", "-i", required=True, help="Path to VoxSniffer.lua SavedVariables")
    p_delta.add_argument("--baseline", "-b", required=True, help="Path to baseline JSON file")
    p_delta.add_argument("--session", "-s", type=int, default=None, help="Filter to specific session ID")

    # Full pipeline
    p_pipe = sub.add_parser("pipeline", help="Full pipeline: ingest -> normalize -> delta -> SQL")
    p_pipe.add_argument("--input", "-i", required=True, help="Path to VoxSniffer.lua SavedVariables")
    p_pipe.add_argument("--baseline", "-b", default=None, help="Path to baseline JSON (optional)")
    p_pipe.add_argument("--session", "-s", type=int, default=None, help="Filter to specific session ID")

    # Status
    p_status = sub.add_parser("status", help="Show SavedVariables status")
    p_status.add_argument("--input", "-i", required=True, help="Path to VoxSniffer.lua SavedVariables")

    # Sessions
    p_sessions = sub.add_parser("sessions", help="List sessions")
    p_sessions.add_argument("--input", "-i", required=True, help="Path to VoxSniffer.lua SavedVariables")

    args = parser.parse_args()
    commands = {
        "ingest": cmd_ingest,
        "normalize": cmd_normalize,
        "delta": cmd_delta,
        "pipeline": cmd_pipeline,
        "status": cmd_status,
        "sessions": cmd_sessions,
    }
    sys.exit(commands[args.command](args))


if __name__ == "__main__":
    main()

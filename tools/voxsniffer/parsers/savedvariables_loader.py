"""Load and validate VoxSniffer SavedVariables files.

Primary entry point for the Python pipeline: reads the SavedVariables
Lua file, validates schema version, extracts sessions and chunks.
"""

from pathlib import Path
from typing import Any

from .lua_table_parser import load_savedvariables, LuaParseError
from .. import config


class SchemaError(Exception):
    """Raised when SavedVariables schema is invalid or incompatible."""
    pass


class SavedVariablesLoader:
    """Load and validate VoxSniffer SavedVariables."""

    def __init__(self, filepath: str | Path):
        self.filepath = Path(filepath)
        self.db: dict[str, Any] = {}
        self._loaded = False

    def load(self) -> dict[str, Any]:
        """Load and parse the SavedVariables file."""
        if not self.filepath.exists():
            raise FileNotFoundError(f"SavedVariables not found: {self.filepath}")

        try:
            all_vars = load_savedvariables(str(self.filepath))
        except LuaParseError as e:
            raise SchemaError(f"Failed to parse Lua: {e}")

        if "VoxSnifferDB" not in all_vars:
            raise SchemaError("VoxSnifferDB not found in SavedVariables file")

        self.db = all_vars["VoxSnifferDB"]
        self._loaded = True
        return self.db

    def validate(self) -> list[str]:
        """Validate the loaded database against expected schema.

        Returns a list of warnings (empty = valid).
        Raises SchemaError for critical issues.
        """
        if not self._loaded:
            raise SchemaError("Call load() before validate()")

        warnings = []

        # Schema version check
        schema_ver = self.db.get("schema_version", 0)
        if schema_ver == 0:
            raise SchemaError("Missing schema_version")
        if schema_ver > config.SCHEMA_VERSION:
            warnings.append(
                f"DB schema v{schema_ver} is newer than pipeline v{config.SCHEMA_VERSION}"
            )

        # Required top-level keys
        required = ["schema_version", "sessions", "chunks", "indexes", "stats"]
        for key in required:
            if key not in self.db:
                warnings.append(f"Missing top-level key: {key}")

        # Validate chunks have required fields
        chunks = self.db.get("chunks", {})
        chunk_items = enumerate(chunks) if isinstance(chunks, list) else chunks.items()
        for chunk_id, chunk in chunk_items:
            if not isinstance(chunk, dict):
                warnings.append(f"Chunk {chunk_id} is not a table")
                continue
            for field in ["session_id", "module", "count", "records"]:
                if field not in chunk:
                    warnings.append(f"Chunk {chunk_id} missing field: {field}")

        return warnings

    def get_sessions(self) -> dict:
        """Return all session metadata.

        Lua tables with sequential integer keys [1], [2], ... parse as lists.
        We normalize to dict keyed by session_id for consistent access.
        """
        raw = self.db.get("sessions", {})
        if isinstance(raw, list):
            return {(s.get("session_id", i+1) if isinstance(s, dict) else i+1): s
                    for i, s in enumerate(raw)}
        return raw

    def get_chunks(self, session_id: int | None = None, module: str | None = None) -> list[dict]:
        """Return chunks, optionally filtered by session and/or module."""
        chunks = self.db.get("chunks", {})
        # Normalize: list or dict both work
        items = chunks if isinstance(chunks, list) else chunks.values()
        result = []
        for chunk in items:
            if not isinstance(chunk, dict):
                continue
            if session_id is not None and chunk.get("session_id") != session_id:
                continue
            if module is not None and chunk.get("module") != module:
                continue
            result.append(chunk)
        return result

    def get_all_records(self, session_id: int | None = None, module: str | None = None) -> list[dict]:
        """Extract all observation records from matching chunks."""
        records = []
        for chunk in self.get_chunks(session_id=session_id, module=module):
            chunk_records = chunk.get("records", [])
            if isinstance(chunk_records, list):
                records.extend(chunk_records)
            elif isinstance(chunk_records, dict):
                # Lua tables with numeric keys may parse as dicts
                for _, rec in sorted(chunk_records.items(), key=lambda x: x[0]):
                    records.append(rec)
        return records

    def get_stats(self) -> dict:
        """Return aggregate stats."""
        return self.db.get("stats", {})

    def get_heatmaps(self) -> dict:
        """Return heatmap data."""
        return self.db.get("heatmaps", {})

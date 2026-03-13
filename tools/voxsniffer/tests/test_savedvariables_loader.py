"""Tests for the SavedVariables loader using the fixture file."""

import pytest
from pathlib import Path
from tools.voxsniffer.parsers.savedvariables_loader import SavedVariablesLoader, SchemaError

FIXTURE_DIR = Path(__file__).parent / "fixtures"
SAMPLE_FILE = FIXTURE_DIR / "sample_savedvariables.lua"


@pytest.fixture
def loader():
    l = SavedVariablesLoader(SAMPLE_FILE)
    l.load()
    return l


def test_load_success(loader):
    assert loader.db["schema_version"] == 1


def test_validate_no_errors(loader):
    warnings = loader.validate()
    assert len(warnings) == 0


def test_load_missing_file():
    l = SavedVariablesLoader("/nonexistent/path.lua")
    with pytest.raises(FileNotFoundError):
        l.load()


def test_get_sessions(loader):
    sessions = loader.get_sessions()
    assert len(sessions) == 1
    session = sessions[1]
    assert session["character"] == "TestChar"
    assert session["realm"] == "TestRealm"
    assert session["observation_count"] == 5


def test_get_chunks_all(loader):
    chunks = loader.get_chunks()
    assert len(chunks) == 2


def test_get_chunks_by_module(loader):
    chunks = loader.get_chunks(module="UnitScanner")
    assert len(chunks) == 1
    assert chunks[0]["module"] == "UnitScanner"
    assert chunks[0]["count"] == 3


def test_get_chunks_by_session(loader):
    chunks = loader.get_chunks(session_id=1)
    assert len(chunks) == 2


def test_get_chunks_filter_miss(loader):
    chunks = loader.get_chunks(session_id=999)
    assert len(chunks) == 0


def test_get_all_records(loader):
    records = loader.get_all_records()
    assert len(records) == 5


def test_get_records_by_module(loader):
    records = loader.get_all_records(module="UnitScanner")
    assert len(records) == 3
    assert all(r["t"] == "unit_seen" for r in records)


def test_get_records_by_session(loader):
    records = loader.get_all_records(session_id=1)
    assert len(records) == 5


def test_record_structure(loader):
    records = loader.get_all_records(module="UnitScanner")
    rec = records[0]
    assert rec["t"] == "unit_seen"
    assert rec["ek"] == "C:12345"
    assert rec["p"]["name"] == "Stormwind Guard"
    assert rec["p"]["level"] == 80


def test_vendor_records(loader):
    records = loader.get_all_records(module="VendorCapture")
    assert len(records) == 2
    vendor = records[0]
    assert vendor["t"] == "vendor_snapshot"
    assert vendor["p"]["npcId"] == 54321
    assert len(vendor["p"]["items"]) == 2


def test_get_stats(loader):
    stats = loader.get_stats()
    assert stats["total_observations"] == 5
    assert stats["total_chunks"] == 2
    assert stats["total_sessions"] == 1


def test_get_heatmaps(loader):
    heatmaps = loader.get_heatmaps()
    assert isinstance(heatmaps, dict)

"""Tests for VoxSniffer delta engine."""

import pytest

from voxsniffer.delta import DeltaEngine


class TestDeltaCreatures:
    def test_new_creature(self):
        engine = DeltaEngine(baseline={"creatures": {}})
        observed = {
            100: {"name": "Wolf", "level": 10, "classification": "normal"},
        }
        deltas = engine.compare_creatures(observed)
        assert len(deltas) == 1
        assert deltas[0]["type"] == "new_creature"
        assert deltas[0]["npcId"] == 100

    def test_matching_creature(self):
        engine = DeltaEngine(baseline={
            "creatures": {"100": {"name": "Wolf", "level": 10, "classification": "normal"}},
        })
        observed = {
            100: {"name": "Wolf", "level": 10, "classification": "normal"},
        }
        deltas = engine.compare_creatures(observed)
        assert len(deltas) == 0

    def test_level_mismatch(self):
        engine = DeltaEngine(baseline={
            "creatures": {"100": {"name": "Wolf", "level": 10, "classification": "normal"}},
        })
        observed = {
            100: {"name": "Wolf", "level": 15, "classification": "normal"},
        }
        deltas = engine.compare_creatures(observed)
        assert len(deltas) == 1
        assert deltas[0]["type"] == "level_mismatch"
        assert deltas[0]["observed"] == 15
        assert deltas[0]["expected"] == 10

    def test_name_mismatch(self):
        engine = DeltaEngine(baseline={
            "creatures": {"100": {"name": "Wolf", "level": 10}},
        })
        observed = {
            100: {"name": "Dire Wolf", "level": 10},
        }
        deltas = engine.compare_creatures(observed)
        assert len(deltas) == 1
        assert deltas[0]["type"] == "name_mismatch"

    def test_multiple_mismatches(self):
        engine = DeltaEngine(baseline={
            "creatures": {"100": {"name": "Wolf", "level": 10, "classification": "normal"}},
        })
        observed = {
            100: {"name": "Dire Wolf", "level": 15, "classification": "elite"},
        }
        deltas = engine.compare_creatures(observed)
        assert len(deltas) == 3  # name, level, classification


class TestDeltaCombat:
    def test_new_spell(self):
        engine = DeltaEngine(baseline={"creature_spells": {}})
        observed = {
            100: {"spellList": [{"spellId": 1234, "spellName": "Fireball", "castCount": 5}]},
        }
        deltas = engine.compare_combat(observed)
        assert len(deltas) == 1
        assert deltas[0]["type"] == "new_spell"
        assert deltas[0]["spellId"] == 1234

    def test_known_spell(self):
        engine = DeltaEngine(baseline={"creature_spells": {"100": [1234]}})
        observed = {
            100: {"spellList": [{"spellId": 1234, "spellName": "Fireball", "castCount": 5}]},
        }
        deltas = engine.compare_combat(observed)
        assert len(deltas) == 0

    def test_missing_spell_needs_data(self):
        """Missing spells only reported with enough observations."""
        engine = DeltaEngine(baseline={"creature_spells": {"100": [1234, 5678]}})
        observed = {
            100: {
                "spellList": [{"spellId": 1234, "castCount": 5}],
                "totalEvents": 15,
            },
        }
        deltas = engine.compare_combat(observed)
        missing = [d for d in deltas if d["type"] == "missing_spell"]
        assert len(missing) == 1
        assert missing[0]["spellId"] == 5678


class TestDeltaVendors:
    def test_new_vendor(self):
        engine = DeltaEngine(baseline={"vendors": {}})
        observed = {
            100: {"npcName": "Smith", "itemCount": 2, "items": [
                {"itemId": 1, "name": "Sword"}, {"itemId": 2, "name": "Shield"},
            ]},
        }
        deltas = engine.compare_vendors(observed)
        assert len(deltas) == 1
        assert deltas[0]["type"] == "new_vendor"

    def test_new_vendor_item(self):
        engine = DeltaEngine(baseline={"vendors": {"100": {"items": [1]}}})
        observed = {
            100: {"npcName": "Smith", "items": [
                {"itemId": 1, "name": "Sword"}, {"itemId": 2, "name": "Shield"},
            ]},
        }
        deltas = engine.compare_vendors(observed)
        assert len(deltas) == 1
        assert deltas[0]["type"] == "new_vendor_item"
        assert deltas[0]["itemId"] == 2


class TestDeltaSummary:
    def test_summary(self):
        engine = DeltaEngine(baseline={"creatures": {}, "creature_spells": {}})
        engine.compare_creatures({100: {"name": "Wolf", "level": 10}})
        engine.compare_combat({100: {"spellList": [{"spellId": 1, "castCount": 1}]}})
        summary = engine.get_summary()
        assert summary["totalDeltas"] == 2
        assert "new_creature" in summary["byType"]
        assert "new_spell" in summary["byType"]

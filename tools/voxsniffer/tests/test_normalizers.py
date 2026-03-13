"""Tests for VoxSniffer normalizers."""

import pytest

from voxsniffer.normalize import (
    normalize_all,
    UnitNormalizer,
    CombatNormalizer,
    VendorNormalizer,
    GossipNormalizer,
    QuestNormalizer,
    EmoteNormalizer,
    LootNormalizer,
    AuraNormalizer,
)


# -- Fixtures --

def make_record(obs_type, payload, **extra):
    """Build a minimal observation record."""
    rec = {"t": obs_type, "p": payload, "epoch": 1710000000, "map": 2222}
    rec.update(extra)
    return rec


# -- UnitNormalizer --

class TestUnitNormalizer:
    def test_basic_merge(self):
        norm = UnitNormalizer()
        records = [
            make_record("unit_seen", {"npcId": 100, "name": "Wolf", "level": 10, "classification": "normal"}),
            make_record("unit_seen", {"npcId": 100, "name": "Wolf", "level": 10, "classification": "normal"}),
            make_record("unit_seen", {"npcId": 200, "name": "Bear", "level": 15, "classification": "elite"}),
        ]
        result = norm.normalize(records)
        assert 100 in result
        assert 200 in result
        assert result[100]["sightings"] == 2
        assert result[200]["sightings"] == 1
        assert result[200]["classification"] == "elite"

    def test_tracks_maps(self):
        norm = UnitNormalizer()
        records = [
            make_record("unit_seen", {"npcId": 100, "name": "Wolf"}, map=10),
            make_record("unit_seen", {"npcId": 100, "name": "Wolf"}, map=20),
        ]
        result = norm.normalize(records)
        assert sorted(result[100]["maps"]) == [10, 20]

    def test_tracks_spells(self):
        norm = UnitNormalizer()
        records = [
            make_record("unit_seen", {"npcId": 100, "name": "Wolf", "castSpellID": 1234}),
            make_record("unit_seen", {"npcId": 100, "name": "Wolf", "chanSpellID": 5678}),
        ]
        result = norm.normalize(records)
        assert 1234 in result[100]["spellsCast"]
        assert 5678 in result[100]["spellsChanneled"]

    def test_filters_by_obs_type(self):
        norm = UnitNormalizer()
        records = [
            make_record("unit_seen", {"npcId": 100, "name": "Wolf"}),
            make_record("combat_event", {"npcId": 100, "subEvent": "SPELL_DAMAGE"}),
        ]
        result = norm.normalize(records)
        assert len(result) == 1

    def test_skips_no_npc_id(self):
        norm = UnitNormalizer()
        records = [
            make_record("unit_seen", {"name": "Wolf"}),
        ]
        result = norm.normalize(records)
        assert len(result) == 0


# -- CombatNormalizer --

class TestCombatNormalizer:
    def test_spell_tracking(self):
        norm = CombatNormalizer()
        records = [
            make_record("combat_event", {
                "npcId": 100, "subEvent": "SPELL_CAST_SUCCESS",
                "spellId": 1234, "spellName": "Fireball", "spellSchool": 4,
            }),
            make_record("combat_event", {
                "npcId": 100, "subEvent": "SPELL_DAMAGE",
                "spellId": 1234, "spellName": "Fireball", "amount": 500, "critical": True,
            }),
        ]
        result = norm.normalize(records)
        assert 100 in result
        assert result[100]["spellCount"] == 1
        spell = result[100]["spellList"][0]
        assert spell["spellId"] == 1234
        assert spell["castCount"] == 1
        assert spell["totalDamage"] == 500
        assert spell["critCount"] == 1

    def test_swing_damage(self):
        norm = CombatNormalizer()
        records = [
            make_record("combat_event", {
                "npcId": 100, "subEvent": "SWING_DAMAGE", "amount": 200,
            }),
        ]
        result = norm.normalize(records)
        assert result[100]["swingDamage"] is True

    def test_unit_death(self):
        norm = CombatNormalizer()
        records = [
            make_record("combat_event", {"npcId": 100, "subEvent": "UNIT_DIED"}),
        ]
        result = norm.normalize(records)
        assert result[100]["deaths"] == 1

    def test_multiple_npcs(self):
        norm = CombatNormalizer()
        records = [
            make_record("combat_event", {"npcId": 100, "subEvent": "SPELL_CAST_SUCCESS", "spellId": 1}),
            make_record("combat_event", {"npcId": 200, "subEvent": "SPELL_CAST_SUCCESS", "spellId": 2}),
        ]
        result = norm.normalize(records)
        assert len(result) == 2


# -- VendorNormalizer --

class TestVendorNormalizer:
    def test_basic_vendor(self):
        norm = VendorNormalizer()
        records = [
            make_record("vendor_snapshot", {
                "npcId": 100, "npcName": "Tharyn",
                "items": [
                    {"slot": 1, "name": "Sword", "itemId": 1234, "price": 100},
                    {"slot": 2, "name": "Shield", "itemId": 5678, "price": 200},
                ],
            }),
        ]
        result = norm.normalize(records)
        assert 100 in result
        assert result[100]["itemCount"] == 2

    def test_latest_snapshot_wins(self):
        norm = VendorNormalizer()
        records = [
            make_record("vendor_snapshot", {
                "npcId": 100, "npcName": "Tharyn", "items": [{"slot": 1, "name": "Old", "itemId": 1}],
            }, epoch=100),
            make_record("vendor_snapshot", {
                "npcId": 100, "npcName": "Tharyn", "items": [{"slot": 1, "name": "New", "itemId": 2}],
            }, epoch=200),
        ]
        result = norm.normalize(records)
        assert result[100]["items"][0]["name"] == "New"


# -- GossipNormalizer --

class TestGossipNormalizer:
    def test_basic_gossip(self):
        norm = GossipNormalizer()
        records = [
            make_record("gossip_snapshot", {
                "npcId": 100, "npcName": "Innkeeper",
                "gossipText": "Welcome!", "optionCount": 2,
            }),
        ]
        result = norm.normalize(records)
        assert 100 in result
        assert result[100]["gossipText"] == "Welcome!"


# -- QuestNormalizer --

class TestQuestNormalizer:
    def test_merge_triggers(self):
        norm = QuestNormalizer()
        records = [
            make_record("quest_snapshot", {
                "questID": 42, "title": "Kill 10 Boars", "trigger": "QUEST_DETAIL",
                "questText": "Go kill boars.", "npcId": 100, "npcName": "Farmer",
            }),
            make_record("quest_snapshot", {
                "questID": 42, "title": "Kill 10 Boars", "trigger": "QUEST_COMPLETE",
                "rewardText": "Well done!",
            }),
        ]
        result = norm.normalize(records)
        assert 42 in result
        assert "QUEST_DETAIL" in result[42]["triggers"]
        assert "QUEST_COMPLETE" in result[42]["triggers"]
        assert result[42]["questText"] == "Go kill boars."
        assert result[42]["rewardText"] == "Well done!"
        assert result[42]["questGiverNpcId"] == 100


# -- EmoteNormalizer --

class TestEmoteNormalizer:
    def test_dedup_texts(self):
        norm = EmoteNormalizer()
        records = [
            make_record("emote_text", {"npcId": 100, "senderName": "Guard", "text": "Halt!", "emoteType": "say"}),
            make_record("emote_text", {"npcId": 100, "senderName": "Guard", "text": "Halt!", "emoteType": "say"}),
            make_record("emote_text", {"npcId": 100, "senderName": "Guard", "text": "Move along.", "emoteType": "say"}),
        ]
        result = norm.normalize(records)
        assert 100 in result
        assert result[100]["uniqueTexts"] == 2
        assert result[100]["textList"][0]["count"] == 2  # "Halt!" seen twice


# -- LootNormalizer --

class TestLootNormalizer:
    def test_drop_rate(self):
        norm = LootNormalizer()
        records = [
            make_record("loot_event", {
                "npcId": 100, "items": [{"itemId": 1, "name": "Fang", "quantity": 1}],
            }),
            make_record("loot_event", {
                "npcId": 100, "items": [{"itemId": 1, "name": "Fang", "quantity": 2}, {"itemId": 2, "name": "Pelt", "quantity": 1}],
            }),
        ]
        result = norm.normalize(records)
        assert result[100]["kills"] == 2
        fang = next(d for d in result[100]["dropTable"] if d["itemId"] == 1)
        assert fang["dropCount"] == 2
        assert fang["dropRate"] == 1.0
        assert fang["minQuantity"] == 1
        assert fang["maxQuantity"] == 2
        pelt = next(d for d in result[100]["dropTable"] if d["itemId"] == 2)
        assert pelt["dropRate"] == 0.5


# -- AuraNormalizer --

class TestAuraNormalizer:
    def test_aura_tracking(self):
        norm = AuraNormalizer()
        records = [
            make_record("aura_seen", {"npcId": 100, "spellId": 1234, "name": "Shield", "stacks": 1, "isHelpful": True}),
            make_record("aura_seen", {"npcId": 100, "spellId": 1234, "name": "Shield", "stacks": 3, "isHelpful": True}),
            make_record("aura_seen", {"npcId": 100, "spellId": 5678, "name": "Poison", "isHarmful": True}),
        ]
        result = norm.normalize(records)
        assert result[100]["uniqueAuras"] == 2
        shield = next(a for a in result[100]["auraList"] if a["spellId"] == 1234)
        assert shield["maxStacks"] == 3
        assert shield["sightings"] == 2


# -- normalize_all --

class TestNormalizeAll:
    def test_routes_to_correct_normalizers(self):
        records = [
            make_record("unit_seen", {"npcId": 100, "name": "Wolf"}),
            make_record("combat_event", {"npcId": 100, "subEvent": "SWING_DAMAGE"}),
            make_record("vendor_snapshot", {"npcId": 200, "items": []}),
        ]
        result = normalize_all(records)
        assert "unit_seen" in result
        assert "combat_event" in result
        # vendor_snapshot has empty items so vendor normalizer finds npcId=200 but items=[]
        # It should still produce a result since npcId exists

    def test_skips_empty_domains(self):
        records = [
            make_record("unit_seen", {"npcId": 100, "name": "Wolf"}),
        ]
        result = normalize_all(records)
        assert "unit_seen" in result
        assert "combat_event" not in result

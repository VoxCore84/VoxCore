"""Tests for the GUID parser."""

from tools.voxsniffer.parsers.guid_parser import parse_guid, get_npc_id, get_gameobject_entry, entity_key


def test_parse_creature_guid():
    guid = "Creature-0-5250-2552-9217-228713-00006A2B3F"
    parsed = parse_guid(guid)
    assert parsed.type == "Creature"
    assert parsed.server_id == 5250
    assert parsed.instance_id == 2552
    assert parsed.zone_uid == 9217
    assert parsed.id == 228713
    assert parsed.spawn_uid == "00006A2B3F"


def test_parse_player_guid():
    guid = "Player-5250-04CC2FAB"
    parsed = parse_guid(guid)
    assert parsed.type == "Player"
    assert parsed.server_id == 5250
    assert parsed.player_id == "04CC2FAB"


def test_parse_gameobject_guid():
    guid = "GameObject-0-5250-2552-9217-505837-00006A9E12"
    parsed = parse_guid(guid)
    assert parsed.type == "GameObject"
    assert parsed.id == 505837


def test_parse_vehicle_guid():
    guid = "Vehicle-0-5250-2552-9217-228713-00006A2B3F"
    parsed = parse_guid(guid)
    assert parsed.type == "Vehicle"
    assert parsed.id == 228713


def test_parse_pet_guid():
    guid = "Pet-0-5250-2552-9217-165189-01006A2B41"
    parsed = parse_guid(guid)
    assert parsed.type == "Pet"
    assert parsed.id == 165189


def test_parse_none():
    assert parse_guid(None) is None
    assert parse_guid("") is None


def test_get_npc_id_creature():
    assert get_npc_id("Creature-0-5250-2552-9217-228713-00006A2B3F") == 228713


def test_get_npc_id_vehicle():
    assert get_npc_id("Vehicle-0-5250-2552-9217-228713-00006A2B3F") == 228713


def test_get_npc_id_player():
    assert get_npc_id("Player-5250-04CC2FAB") is None


def test_get_gameobject_entry():
    assert get_gameobject_entry("GameObject-0-5250-2552-9217-505837-00006A9E12") == 505837


def test_entity_key_creature():
    assert entity_key("Creature-0-5250-2552-9217-228713-00006A2B3F") == "C:228713"


def test_entity_key_gameobject():
    assert entity_key("GameObject-0-5250-2552-9217-505837-00006A9E12") == "GO:505837"


def test_entity_key_player():
    assert entity_key("Player-5250-04CC2FAB") == "P:04CC2FAB"


def test_entity_key_pet():
    assert entity_key("Pet-0-5250-2552-9217-165189-01006A2B41") == "PET:165189"

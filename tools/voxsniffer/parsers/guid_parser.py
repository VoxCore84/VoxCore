"""Parse WoW GUID strings into structured components.

Mirrors the Lua GuidUtils.lua logic for Python-side processing.

GUID format examples:
    Creature-0-5250-2552-9217-228713-00006A2B3F
    Player-5250-04CC2FAB
    GameObject-0-5250-2552-9217-505837-00006A9E12
    Vehicle-0-5250-2552-9217-228713-00006A2B3F

Fields: Type-0-ServerID-InstanceID-ZoneUID-ID-SpawnUID
"""

from dataclasses import dataclass


@dataclass
class ParsedGUID:
    type: str
    server_id: int | None = None
    instance_id: int | None = None
    zone_uid: int | None = None
    id: int | None = None  # NPC ID or GameObject entry
    spawn_uid: str | None = None
    player_id: str | None = None
    raw: str = ""


def parse_guid(guid: str) -> ParsedGUID | None:
    """Parse a WoW GUID string into a structured object."""
    if not guid:
        return None

    parts = guid.split("-")
    if not parts:
        return None

    unit_type = parts[0]

    if unit_type == "Player":
        return ParsedGUID(
            type=unit_type,
            server_id=_safe_int(parts[1]) if len(parts) > 1 else None,
            player_id=parts[2] if len(parts) > 2 else None,
            raw=guid,
        )

    if unit_type in ("Creature", "Pet", "Vehicle", "GameObject"):
        return ParsedGUID(
            type=unit_type,
            server_id=_safe_int(parts[2]) if len(parts) > 2 else None,
            instance_id=_safe_int(parts[3]) if len(parts) > 3 else None,
            zone_uid=_safe_int(parts[4]) if len(parts) > 4 else None,
            id=_safe_int(parts[5]) if len(parts) > 5 else None,
            spawn_uid=parts[6] if len(parts) > 6 else None,
            raw=guid,
        )

    return ParsedGUID(type=unit_type, raw=guid)


def get_npc_id(guid: str) -> int | None:
    """Extract NPC entry ID from a GUID. Returns None for non-creature GUIDs."""
    parsed = parse_guid(guid)
    if parsed and parsed.type in ("Creature", "Vehicle"):
        return parsed.id
    return None


def get_gameobject_entry(guid: str) -> int | None:
    """Extract GameObject entry from a GUID."""
    parsed = parse_guid(guid)
    if parsed and parsed.type == "GameObject":
        return parsed.id
    return None


def entity_key(guid: str) -> str | None:
    """Build a stable entity key for deduplication. Mirrors Lua GU.EntityKey()."""
    parsed = parse_guid(guid)
    if not parsed:
        return None

    if parsed.type in ("Creature", "Vehicle"):
        return f"C:{parsed.id or 0}"
    elif parsed.type == "GameObject":
        return f"GO:{parsed.id or 0}"
    elif parsed.type == "Pet":
        return f"PET:{parsed.id or 0}"
    elif parsed.type == "Player":
        return f"P:{parsed.player_id or '0'}"
    return None


def _safe_int(val: str) -> int | None:
    try:
        return int(val)
    except (ValueError, TypeError):
        return None

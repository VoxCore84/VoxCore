"""Normalize unit_seen observations into creature records."""

from __future__ import annotations

from typing import Any

from .base import BaseNormalizer, safe_get, first_non_none


class UnitNormalizer(BaseNormalizer):
    """Merge multiple sightings of the same NPC into a single creature record."""

    obs_type = "unit_seen"

    def normalize(self, records: list[dict]) -> dict[str, Any]:
        filtered = self.filter_records(records)
        creatures: dict[int, dict] = {}  # npcId -> merged data

        for rec in filtered:
            p = rec.get("p", {})
            npc_id = p.get("npcId")
            if not npc_id:
                continue

            if npc_id not in creatures:
                creatures[npc_id] = {
                    "npcId": npc_id,
                    "name": p.get("name"),
                    "level": p.get("level"),
                    "classification": p.get("classification"),
                    "creatureType": p.get("creatureType"),
                    "reaction": p.get("reaction"),
                    "isFriend": p.get("isFriend"),
                    "sex": p.get("sex"),
                    "maxHealth": p.get("maxHealth"),
                    "powerType": p.get("powerType"),
                    "maxPower": p.get("maxPower"),
                    "sightings": 0,
                    "maps": set(),
                    "positions": [],
                    "sources": set(),
                    "spellsCast": set(),
                    "spellsChanneled": set(),
                    "firstSeen": rec.get("epoch"),
                    "lastSeen": rec.get("epoch"),
                }

            c = creatures[npc_id]
            c["sightings"] += 1
            c["lastSeen"] = rec.get("epoch") or c["lastSeen"]

            # Merge — prefer non-None, higher values for health/power
            c["name"] = first_non_none(c["name"], p.get("name"))
            c["level"] = first_non_none(p.get("level"), c["level"])
            c["classification"] = first_non_none(p.get("classification"), c["classification"])
            c["creatureType"] = first_non_none(p.get("creatureType"), c["creatureType"])
            c["maxHealth"] = max(c["maxHealth"] or 0, p.get("maxHealth") or 0) or None
            c["maxPower"] = max(c["maxPower"] or 0, p.get("maxPower") or 0) or None

            # Track maps and positions
            map_id = rec.get("map")
            if map_id:
                c["maps"].add(map_id)
            pos = rec.get("pos")
            if pos and isinstance(pos, dict):
                c["positions"].append({
                    "x": pos.get("x"), "y": pos.get("y"), "map": map_id
                })

            # Track sources
            source = rec.get("unit_source")
            if source:
                c["sources"].add(source)

            # Track spells
            cast_id = p.get("castSpellID")
            if cast_id:
                c["spellsCast"].add(cast_id)
            chan_id = p.get("chanSpellID")
            if chan_id:
                c["spellsChanneled"].add(chan_id)

        # Convert sets to sorted lists for JSON serialization
        for c in creatures.values():
            c["maps"] = sorted(c["maps"])
            c["sources"] = sorted(c["sources"])
            c["spellsCast"] = sorted(c["spellsCast"])
            c["spellsChanneled"] = sorted(c["spellsChanneled"])
            # Keep only unique positions (dedup by rounding)
            seen_pos = set()
            unique_positions = []
            for pos in c["positions"]:
                key = (round(pos["x"] or 0, 4), round(pos["y"] or 0, 4), pos["map"])
                if key not in seen_pos:
                    seen_pos.add(key)
                    unique_positions.append(pos)
            c["positions"] = unique_positions

        return creatures

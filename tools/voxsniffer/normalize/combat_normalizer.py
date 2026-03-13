"""Normalize combat_event observations into per-NPC spell lists."""

from __future__ import annotations

from typing import Any

from .base import BaseNormalizer


class CombatNormalizer(BaseNormalizer):
    """Extract per-NPC spell usage from combat events."""

    obs_type = "combat_event"

    def normalize(self, records: list[dict]) -> dict[str, Any]:
        filtered = self.filter_records(records)
        npcs: dict[int, dict] = {}  # npcId -> combat profile

        for rec in filtered:
            p = rec.get("p", {})
            npc_id = p.get("npcId")
            if not npc_id:
                continue

            if npc_id not in npcs:
                npcs[npc_id] = {
                    "npcId": npc_id,
                    "spells": {},          # spellId -> spell info
                    "swingDamage": False,
                    "totalEvents": 0,
                    "subEvents": {},       # subEvent -> count
                    "targets": set(),
                    "deaths": 0,
                }

            npc = npcs[npc_id]
            npc["totalEvents"] += 1

            sub_event = p.get("subEvent", "")
            npc["subEvents"][sub_event] = npc["subEvents"].get(sub_event, 0) + 1

            # Track spell usage
            spell_id = p.get("spellId")
            if spell_id:
                if spell_id not in npc["spells"]:
                    npc["spells"][spell_id] = {
                        "spellId": spell_id,
                        "spellName": p.get("spellName"),
                        "school": p.get("spellSchool"),
                        "subEvents": set(),
                        "castCount": 0,
                        "totalDamage": 0,
                        "totalHealing": 0,
                        "maxHit": 0,
                        "critCount": 0,
                        "auraApplied": 0,
                        "auraType": None,
                    }

                spell = npc["spells"][spell_id]
                spell["subEvents"].add(sub_event)

                if "CAST" in sub_event:
                    spell["castCount"] += 1
                if "DAMAGE" in sub_event:
                    amount = p.get("amount") or 0
                    spell["totalDamage"] += amount
                    spell["maxHit"] = max(spell["maxHit"], amount)
                    if p.get("critical"):
                        spell["critCount"] += 1
                if "HEAL" in sub_event:
                    spell["totalHealing"] += (p.get("amount") or 0)
                if "AURA_APPLIED" in sub_event:
                    spell["auraApplied"] += 1
                    spell["auraType"] = p.get("auraType") or spell["auraType"]

            # Swing damage
            if "SWING" in sub_event:
                npc["swingDamage"] = True

            # Track targets
            if p.get("destIsNpc") is False and p.get("destName"):
                npc["targets"].add(p["destName"])

            # Deaths
            if sub_event in ("UNIT_DIED", "UNIT_DESTROYED"):
                npc["deaths"] += 1

        # Serialize sets
        for npc in npcs.values():
            npc["targets"] = sorted(npc["targets"])
            for spell in npc["spells"].values():
                spell["subEvents"] = sorted(spell["subEvents"])
            # Convert spells dict values to list sorted by castCount desc
            npc["spellList"] = sorted(
                npc["spells"].values(),
                key=lambda s: s["castCount"],
                reverse=True,
            )
            npc["spellCount"] = len(npc["spells"])
            del npc["spells"]

        return npcs

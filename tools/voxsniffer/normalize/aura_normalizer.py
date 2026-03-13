"""Normalize aura_seen observations into per-NPC aura lists."""

from __future__ import annotations

from typing import Any

from .base import BaseNormalizer


class AuraNormalizer(BaseNormalizer):
    """Merge aura observations into per-NPC buff/debuff profiles."""

    obs_type = "aura_seen"

    def normalize(self, records: list[dict]) -> dict[str, Any]:
        filtered = self.filter_records(records)
        npcs: dict[int, dict] = {}  # npcId -> aura profile

        for rec in filtered:
            p = rec.get("p", {})
            npc_id = p.get("npcId")
            if not npc_id:
                continue

            if npc_id not in npcs:
                npcs[npc_id] = {
                    "npcId": npc_id,
                    "unitName": p.get("unitName"),
                    "auras": {},  # spellId -> aura info
                }

            npc = npcs[npc_id]
            spell_id = p.get("spellId")
            if not spell_id:
                continue

            if spell_id not in npc["auras"]:
                npc["auras"][spell_id] = {
                    "spellId": spell_id,
                    "name": p.get("name"),
                    "isHelpful": p.get("isHelpful"),
                    "isHarmful": p.get("isHarmful"),
                    "isBossAura": p.get("isBossAura"),
                    "maxStacks": 0,
                    "sightings": 0,
                    "sources": set(),
                }

            aura = npc["auras"][spell_id]
            aura["sightings"] += 1
            stacks = p.get("stacks") or 0
            aura["maxStacks"] = max(aura["maxStacks"], stacks)
            source = p.get("scanSource")
            if source:
                aura["sources"].add(source)

        # Serialize
        for npc in npcs.values():
            aura_list = []
            for aura in npc["auras"].values():
                aura["sources"] = sorted(aura["sources"])
                aura_list.append(aura)
            npc["auraList"] = sorted(aura_list, key=lambda a: a["sightings"], reverse=True)
            npc["uniqueAuras"] = len(aura_list)
            del npc["auras"]

        return npcs

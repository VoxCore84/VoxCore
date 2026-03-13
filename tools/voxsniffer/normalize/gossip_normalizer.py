"""Normalize gossip_snapshot observations into NPC gossip menus."""

from __future__ import annotations

from typing import Any

from .base import BaseNormalizer


class GossipNormalizer(BaseNormalizer):
    """Deduplicate gossip menu snapshots per NPC."""

    obs_type = "gossip_snapshot"

    def normalize(self, records: list[dict]) -> dict[str, Any]:
        filtered = self.filter_records(records)
        gossips: dict[int, dict] = {}  # npcId -> gossip data

        for rec in filtered:
            p = rec.get("p", {})
            npc_id = p.get("npcId")
            if not npc_id:
                continue

            # Take latest snapshot per NPC
            existing = gossips.get(npc_id)
            rec_epoch = rec.get("epoch", 0)
            if existing and existing.get("_epoch", 0) >= rec_epoch:
                continue

            gossips[npc_id] = {
                "npcId": npc_id,
                "npcName": p.get("npcName"),
                "gossipText": p.get("gossipText"),
                "optionCount": p.get("optionCount", 0),
                "options": p.get("options"),
                "availableQuests": p.get("availableQuests"),
                "activeQuests": p.get("activeQuests"),
                "availableQuestCount": p.get("availableQuestCount", 0),
                "activeQuestCount": p.get("activeQuestCount", 0),
                "mapId": p.get("mapId"),
                "position": p.get("position"),
                "_epoch": rec_epoch,
            }

        for g in gossips.values():
            g.pop("_epoch", None)

        return gossips

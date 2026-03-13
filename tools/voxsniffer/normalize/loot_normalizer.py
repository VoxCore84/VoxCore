"""Normalize loot_event observations into per-NPC loot tables."""

from __future__ import annotations

from typing import Any

from .base import BaseNormalizer


class LootNormalizer(BaseNormalizer):
    """Merge loot observations into per-NPC drop tables."""

    obs_type = "loot_event"

    def normalize(self, records: list[dict]) -> dict[str, Any]:
        filtered = self.filter_records(records)
        npcs: dict[int, dict] = {}  # npcId -> loot profile

        for rec in filtered:
            p = rec.get("p", {})
            npc_id = p.get("npcId")
            if not npc_id:
                continue

            if npc_id not in npcs:
                npcs[npc_id] = {
                    "npcId": npc_id,
                    "sourceName": p.get("sourceName"),
                    "kills": 0,
                    "items": {},  # itemId -> drop stats
                }

            npc = npcs[npc_id]
            npc["kills"] += 1

            items = p.get("items", [])
            item_list = items if isinstance(items, list) else items.values()

            for item in item_list:
                if not isinstance(item, dict):
                    continue
                item_id = item.get("itemId")
                if not item_id:
                    continue

                if item_id not in npc["items"]:
                    npc["items"][item_id] = {
                        "itemId": item_id,
                        "name": item.get("name"),
                        "quality": item.get("quality"),
                        "dropCount": 0,
                        "totalQuantity": 0,
                        "minQuantity": item.get("quantity", 1),
                        "maxQuantity": item.get("quantity", 1),
                        "isQuestItem": item.get("isQuestItem"),
                    }

                drop = npc["items"][item_id]
                drop["dropCount"] += 1
                qty = item.get("quantity", 1) or 1
                drop["totalQuantity"] += qty
                drop["minQuantity"] = min(drop["minQuantity"], qty)
                drop["maxQuantity"] = max(drop["maxQuantity"], qty)

        # Compute drop rates and serialize
        for npc in npcs.values():
            kills = npc["kills"]
            drop_list = []
            for drop in npc["items"].values():
                drop["dropRate"] = round(drop["dropCount"] / kills, 4) if kills > 0 else 0
                drop_list.append(drop)
            npc["dropTable"] = sorted(drop_list, key=lambda d: d["dropCount"], reverse=True)
            npc["uniqueItems"] = len(drop_list)
            del npc["items"]

        return npcs

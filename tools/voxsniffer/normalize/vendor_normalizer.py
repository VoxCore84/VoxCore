"""Normalize vendor_snapshot observations into vendor inventories."""

from __future__ import annotations

from typing import Any

from .base import BaseNormalizer


class VendorNormalizer(BaseNormalizer):
    """Deduplicate and merge vendor inventory snapshots."""

    obs_type = "vendor_snapshot"

    def normalize(self, records: list[dict]) -> dict[str, Any]:
        filtered = self.filter_records(records)
        vendors: dict[int, dict] = {}  # npcId -> vendor data

        for rec in filtered:
            p = rec.get("p", {})
            npc_id = p.get("npcId")
            if not npc_id:
                continue

            # Take the latest snapshot for each vendor
            existing = vendors.get(npc_id)
            rec_epoch = rec.get("epoch", 0)

            if existing and existing.get("_epoch", 0) >= rec_epoch:
                continue  # keep newer snapshot

            items = p.get("items", [])
            normalized_items = []
            for item in (items if isinstance(items, list) else items.values()):
                if not isinstance(item, dict):
                    continue
                entry = {
                    "slot": item.get("slot"),
                    "name": item.get("name"),
                    "itemId": item.get("itemId"),
                    "price": item.get("price"),
                    "stackCount": item.get("stackCount"),
                    "numAvailable": item.get("numAvailable"),
                    "isPurchasable": item.get("isPurchasable"),
                    "hasExtendedCost": item.get("hasExtendedCost"),
                }

                # Extended costs
                costs = item.get("costs")
                if costs:
                    entry["costs"] = []
                    cost_items = costs if isinstance(costs, list) else costs.values()
                    for cost in cost_items:
                        if isinstance(cost, dict):
                            entry["costs"].append({
                                "count": cost.get("count"),
                                "name": cost.get("name"),
                                "itemId": cost.get("itemId"),
                                "currencyId": cost.get("currencyId"),
                            })

                normalized_items.append(entry)

            vendors[npc_id] = {
                "npcId": npc_id,
                "npcName": p.get("npcName"),
                "itemCount": len(normalized_items),
                "items": normalized_items,
                "mapId": p.get("mapId"),
                "position": p.get("position"),
                "_epoch": rec_epoch,
            }

        # Clean up internal fields
        for v in vendors.values():
            v.pop("_epoch", None)

        return vendors

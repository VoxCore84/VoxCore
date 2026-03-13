"""Normalize quest_snapshot observations into quest records."""

from __future__ import annotations

from typing import Any

from .base import BaseNormalizer


class QuestNormalizer(BaseNormalizer):
    """Merge quest observations across offer/accept/turn-in events."""

    obs_type = "quest_snapshot"

    def normalize(self, records: list[dict]) -> dict[str, Any]:
        filtered = self.filter_records(records)
        quests: dict[int, dict] = {}  # questID -> quest data

        for rec in filtered:
            p = rec.get("p", {})
            quest_id = p.get("questID")
            if not quest_id:
                continue

            if quest_id not in quests:
                quests[quest_id] = {
                    "questID": quest_id,
                    "title": None,
                    "questText": None,
                    "objectiveText": None,
                    "progressText": None,
                    "rewardText": None,
                    "rewards": None,
                    "requiredItems": None,
                    "objectives": None,
                    "questGiverNpcId": None,
                    "questGiverName": None,
                    "triggers": set(),
                    "maps": set(),
                    "positions": [],
                }

            q = quests[quest_id]
            q["triggers"].add(p.get("trigger", "unknown"))

            # Merge text — QUEST_DETAIL has the richest text
            if p.get("title"):
                q["title"] = p["title"]
            if p.get("questText"):
                q["questText"] = p["questText"]
            if p.get("objectiveText"):
                q["objectiveText"] = p["objectiveText"]
            if p.get("progressText"):
                q["progressText"] = p["progressText"]
            if p.get("rewardText"):
                q["rewardText"] = p["rewardText"]

            # Rewards from any trigger
            if p.get("rewards") and not q["rewards"]:
                q["rewards"] = p["rewards"]

            if p.get("requiredItems") and not q["requiredItems"]:
                q["requiredItems"] = p["requiredItems"]

            if p.get("objectives") and not q["objectives"]:
                q["objectives"] = p["objectives"]

            # Quest giver
            if p.get("npcId") and not q["questGiverNpcId"]:
                q["questGiverNpcId"] = p["npcId"]
                q["questGiverName"] = p.get("npcName")

            # Location
            map_id = p.get("mapId") or rec.get("map")
            if map_id:
                q["maps"].add(map_id)
            pos = p.get("position") or rec.get("pos")
            if pos and isinstance(pos, dict):
                q["positions"].append({"x": pos.get("x"), "y": pos.get("y"), "map": map_id})

        # Serialize
        for q in quests.values():
            q["triggers"] = sorted(q["triggers"])
            q["maps"] = sorted(q["maps"])

        return quests

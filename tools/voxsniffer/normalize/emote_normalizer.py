"""Normalize emote_text observations into broadcast text records."""

from __future__ import annotations

from typing import Any

from .base import BaseNormalizer


class EmoteNormalizer(BaseNormalizer):
    """Deduplicate NPC speech/emote texts per NPC."""

    obs_type = "emote_text"

    def normalize(self, records: list[dict]) -> dict[str, Any]:
        filtered = self.filter_records(records)
        # Group by npcId -> list of unique texts
        npcs: dict[int, dict] = {}

        for rec in filtered:
            p = rec.get("p", {})
            npc_id = p.get("npcId")
            if not npc_id:
                continue

            if npc_id not in npcs:
                npcs[npc_id] = {
                    "npcId": npc_id,
                    "senderName": p.get("senderName"),
                    "texts": {},  # text_hash -> text record
                }

            npc = npcs[npc_id]
            text = p.get("text") or ""
            emote_type = p.get("emoteType") or "unknown"
            text_key = f"{emote_type}|{text}"

            if text_key not in npc["texts"]:
                npc["texts"][text_key] = {
                    "text": text,
                    "emoteType": emote_type,
                    "language": p.get("language"),
                    "count": 0,
                }
            npc["texts"][text_key]["count"] += 1

        # Flatten texts dict to list
        for npc in npcs.values():
            npc["textList"] = sorted(
                npc["texts"].values(),
                key=lambda t: t["count"],
                reverse=True,
            )
            npc["uniqueTexts"] = len(npc["textList"])
            del npc["texts"]

        return npcs

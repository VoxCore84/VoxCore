"""VoxSniffer Delta Engine — compare normalized observations against baseline.

Produces actionable deltas: missing creatures, wrong levels, missing spells,
unknown vendors, etc. Output feeds into SQL generators.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any


class DeltaEngine:
    """Compare normalized VoxSniffer data against a TC database baseline."""

    def __init__(self, baseline: dict[str, Any] | None = None):
        self.baseline = baseline or {}
        self.deltas: list[dict] = []

    def load_baseline(self, path: Path):
        """Load baseline from a JSON file."""
        with open(path, 'r', encoding='utf-8') as f:
            self.baseline = json.load(f)

    def compare_creatures(self, observed: dict[int, dict]) -> list[dict]:
        """Compare observed creatures against baseline creature_template."""
        baseline_creatures = self.baseline.get("creatures", {})
        deltas = []

        for npc_id, obs in observed.items():
            npc_key = str(npc_id)
            if npc_key not in baseline_creatures:
                deltas.append({
                    "type": "new_creature",
                    "severity": "info",
                    "npcId": npc_id,
                    "name": obs.get("name"),
                    "level": obs.get("level"),
                    "classification": obs.get("classification"),
                    "creatureType": obs.get("creatureType"),
                    "maps": obs.get("maps", []),
                    "sightings": obs.get("sightings", 0),
                })
                continue

            base = baseline_creatures[npc_key]
            fields_to_check = [
                ("name", "name_mismatch"),
                ("level", "level_mismatch"),
                ("classification", "classification_mismatch"),
            ]

            for field, delta_type in fields_to_check:
                obs_val = obs.get(field)
                base_val = base.get(field)
                if obs_val is not None and base_val is not None and obs_val != base_val:
                    deltas.append({
                        "type": delta_type,
                        "severity": "warning",
                        "npcId": npc_id,
                        "field": field,
                        "observed": obs_val,
                        "expected": base_val,
                        "name": obs.get("name"),
                    })

        self.deltas.extend(deltas)
        return deltas

    def compare_combat(self, observed: dict[int, dict]) -> list[dict]:
        """Compare observed NPC spells against baseline creature_template_spell."""
        baseline_spells = self.baseline.get("creature_spells", {})
        deltas = []

        for npc_id, obs in observed.items():
            npc_key = str(npc_id)
            base_spells = set(baseline_spells.get(npc_key, []))
            obs_spells = {s["spellId"] for s in obs.get("spellList", []) if s.get("spellId")}

            # Spells observed but not in baseline
            new_spells = obs_spells - base_spells
            for spell_id in sorted(new_spells):
                spell_info = next(
                    (s for s in obs.get("spellList", []) if s.get("spellId") == spell_id),
                    {}
                )
                deltas.append({
                    "type": "new_spell",
                    "severity": "info",
                    "npcId": npc_id,
                    "spellId": spell_id,
                    "spellName": spell_info.get("spellName"),
                    "castCount": spell_info.get("castCount", 0),
                })

            # Spells in baseline but never observed (possible removal)
            missing_spells = base_spells - obs_spells
            if missing_spells and obs.get("totalEvents", 0) > 10:
                for spell_id in sorted(missing_spells):
                    deltas.append({
                        "type": "missing_spell",
                        "severity": "low",
                        "npcId": npc_id,
                        "spellId": spell_id,
                        "note": "In baseline but not observed (may need more data)",
                    })

        self.deltas.extend(deltas)
        return deltas

    def compare_vendors(self, observed: dict[int, dict]) -> list[dict]:
        """Compare observed vendor inventories against baseline npc_vendor."""
        baseline_vendors = self.baseline.get("vendors", {})
        deltas = []

        for npc_id, obs in observed.items():
            npc_key = str(npc_id)
            if npc_key not in baseline_vendors:
                deltas.append({
                    "type": "new_vendor",
                    "severity": "info",
                    "npcId": npc_id,
                    "npcName": obs.get("npcName"),
                    "itemCount": obs.get("itemCount", 0),
                    "items": [
                        {"itemId": i.get("itemId"), "name": i.get("name")}
                        for i in obs.get("items", [])
                        if i.get("itemId")
                    ],
                })
                continue

            base_items = set(baseline_vendors[npc_key].get("items", []))
            obs_items = {i["itemId"] for i in obs.get("items", []) if i.get("itemId")}

            new_items = obs_items - base_items
            for item_id in sorted(new_items):
                item_info = next(
                    (i for i in obs.get("items", []) if i.get("itemId") == item_id),
                    {}
                )
                deltas.append({
                    "type": "new_vendor_item",
                    "severity": "info",
                    "npcId": npc_id,
                    "npcName": obs.get("npcName"),
                    "itemId": item_id,
                    "itemName": item_info.get("name"),
                    "price": item_info.get("price"),
                })

        self.deltas.extend(deltas)
        return deltas

    def get_summary(self) -> dict:
        """Return a summary of all deltas found."""
        by_type: dict[str, int] = {}
        by_severity: dict[str, int] = {}
        for d in self.deltas:
            dt = d.get("type", "unknown")
            by_type[dt] = by_type.get(dt, 0) + 1
            sev = d.get("severity", "unknown")
            by_severity[sev] = by_severity.get(sev, 0) + 1

        return {
            "totalDeltas": len(self.deltas),
            "byType": by_type,
            "bySeverity": by_severity,
        }

    def export_deltas(self, path: Path):
        """Write all deltas to a JSONL file."""
        with open(path, 'w', encoding='utf-8') as f:
            for delta in self.deltas:
                f.write(json.dumps(delta, ensure_ascii=False, default=str) + '\n')

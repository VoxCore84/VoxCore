"""Generate SQL update files from VoxSniffer deltas.

Produces TC-compatible SQL for creature_template_spell, npc_vendor, etc.
"""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any


class SQLExporter:
    """Generate SQL files from delta data."""

    def __init__(self, out_dir: Path | None = None):
        self.out_dir = out_dir
        self.statements: list[str] = []

    def generate_creature_spells(self, deltas: list[dict]) -> list[str]:
        """Generate INSERT statements for new creature spells."""
        spell_deltas = [d for d in deltas if d.get("type") == "new_spell"]
        if not spell_deltas:
            return []

        stmts = [
            "-- VoxSniffer: New creature spells observed in-game",
            f"-- Generated: {datetime.now().isoformat()}",
            f"-- Source: {len(spell_deltas)} new spell observations",
            "",
        ]

        # Group by NPC
        by_npc: dict[int, list[dict]] = {}
        for d in spell_deltas:
            npc_id = d.get("npcId")
            if npc_id:
                by_npc.setdefault(npc_id, []).append(d)

        for npc_id in sorted(by_npc.keys()):
            spells = by_npc[npc_id]
            stmts.append(f"-- NPC {npc_id}")
            for i, spell in enumerate(spells):
                spell_id = spell.get("spellId")
                spell_name = spell.get("spellName", "unknown")
                cast_count = spell.get("castCount", 0)
                stmts.append(
                    f"INSERT IGNORE INTO `creature_template_spell` "
                    f"(`CreatureID`, `Index`, `Spell`) "
                    f"VALUES ({npc_id}, {i}, {spell_id}); "
                    f"-- {spell_name} (seen {cast_count}x)"
                )
            stmts.append("")

        self.statements.extend(stmts)
        return stmts

    def generate_vendor_items(self, deltas: list[dict]) -> list[str]:
        """Generate INSERT statements for new vendor items."""
        vendor_deltas = [d for d in deltas if d.get("type") == "new_vendor_item"]
        if not vendor_deltas:
            return []

        stmts = [
            "-- VoxSniffer: New vendor items observed in-game",
            f"-- Generated: {datetime.now().isoformat()}",
            f"-- Source: {len(vendor_deltas)} new vendor item observations",
            "",
        ]

        by_npc: dict[int, list[dict]] = {}
        for d in vendor_deltas:
            npc_id = d.get("npcId")
            if npc_id:
                by_npc.setdefault(npc_id, []).append(d)

        for npc_id in sorted(by_npc.keys()):
            items = by_npc[npc_id]
            npc_name = items[0].get("npcName", "unknown")
            stmts.append(f"-- Vendor: {npc_name} ({npc_id})")
            for i, item in enumerate(items):
                item_id = item.get("itemId")
                item_name = item.get("itemName", "unknown")
                stmts.append(
                    f"INSERT IGNORE INTO `npc_vendor` "
                    f"(`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) "
                    f"VALUES ({npc_id}, {i}, {item_id}, 0, 0, 0); "
                    f"-- {item_name}"
                )
            stmts.append("")

        self.statements.extend(stmts)
        return stmts

    def write(self, filename: str | None = None) -> Path | None:
        """Write accumulated SQL to file."""
        if not self.statements or not self.out_dir:
            return None

        self.out_dir.mkdir(parents=True, exist_ok=True)
        if not filename:
            ts = datetime.now().strftime("%Y_%m_%d")
            filename = f"voxsniffer_deltas_{ts}.sql"

        path = self.out_dir / filename
        with open(path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(self.statements) + '\n')
        return path

    def get_sql(self) -> str:
        """Return accumulated SQL as a string."""
        return '\n'.join(self.statements)

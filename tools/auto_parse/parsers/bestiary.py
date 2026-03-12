"""BestiaryForge SavedVariables scanner -- detects new creature/spell discoveries."""

from __future__ import annotations

import re
from datetime import datetime
from pathlib import Path
from typing import TYPE_CHECKING

from .base import ParsedEntry, Severity

if TYPE_CHECKING:
    from ..config import Config

# BestiaryForgeDB.lua is a standard WoW SavedVariables file.
# Structure: BestiaryForgeDB = { creatures = { [entry] = { name, spells = { [id] = {...} } } } }
# We parse it with regex since it's a simple flat structure — no Lua interpreter needed.

_CREATURE_BLOCK_RE = re.compile(
    r'\[(\d+)\]\s*=\s*\{[^}]*\["name"\]\s*=\s*"([^"]*)"', re.DOTALL
)
_SPELL_ENTRY_RE = re.compile(r"\[(\d+)\]\s*=\s*\{")
_FIELD_RE = re.compile(r'\["(\w+)"\]\s*=\s*([^,}\n]+)')

_SAVED_VAR_FILE = "BestiaryForge.lua"


class BestiaryScanner:
    name = "Bestiary"

    def __init__(self, config: Config) -> None:
        self._sv_dir = config.paths.wtf_saved_vars_dir
        self._last_mtime: float = 0.0
        self._prev_creature_count: int = 0
        self._prev_spell_count: int = 0
        self._prev_spells: set[tuple[int, int]] = set()  # (entry, spellId) pairs

    @property
    def _sv_path(self) -> Path:
        return self._sv_dir / _SAVED_VAR_FILE

    def should_rescan(self) -> bool:
        path = self._sv_path
        if not path.exists():
            return False
        try:
            mtime = path.stat().st_mtime
        except OSError:
            return False
        return mtime != self._last_mtime

    def scan(self) -> list[ParsedEntry]:
        path = self._sv_path
        if not path.exists():
            return []

        try:
            self._last_mtime = path.stat().st_mtime
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            return []

        creatures, spells, new_discoveries = self._parse_saved_vars(text)
        entries: list[ParsedEntry] = []
        now = datetime.now().strftime("%H:%M:%S")

        # Report new discoveries since last scan
        if new_discoveries:
            for entry_id, spell_id, creature_name, spell_name in new_discoveries:
                entries.append(ParsedEntry(
                    timestamp=now,
                    source=self.name,
                    category="new_spell",
                    severity=Severity.INFO,
                    text=f"New spell discovered: {creature_name} ({entry_id}) casts {spell_name} [{spell_id}]",
                    metadata={
                        "creature_entry": entry_id,
                        "creature_name": creature_name,
                        "spell_id": spell_id,
                        "spell_name": spell_name,
                    },
                ))

        # Summary entry if counts changed
        creature_count = len(creatures)
        spell_count = len(spells)
        if creature_count != self._prev_creature_count or spell_count != self._prev_spell_count:
            delta_c = creature_count - self._prev_creature_count
            delta_s = spell_count - self._prev_spell_count
            delta_str = ""
            if delta_c > 0:
                delta_str += f"+{delta_c} creatures "
            if delta_s > 0:
                delta_str += f"+{delta_s} spells"
            entries.append(ParsedEntry(
                timestamp=now,
                source=self.name,
                category="summary",
                severity=Severity.INFO,
                text=f"BestiaryForge: {creature_count} creatures, {spell_count} spells tracked. {delta_str}".strip(),
                metadata={
                    "creature_count": creature_count,
                    "spell_count": spell_count,
                    "delta_creatures": delta_c,
                    "delta_spells": delta_s,
                },
            ))

        self._prev_creature_count = creature_count
        self._prev_spell_count = spell_count

        return entries

    def _parse_saved_vars(self, text: str) -> tuple[
        dict[int, str],  # entry -> name
        set[tuple[int, int]],  # (entry, spellId) pairs
        list[tuple[int, int, str, str]],  # new discoveries: (entry, spellId, creatureName, spellName)
    ]:
        """Parse BestiaryForgeDB saved variables and detect new discoveries."""
        creatures: dict[int, str] = {}
        current_spells: set[tuple[int, int]] = set()
        new_discoveries: list[tuple[int, int, str, str]] = []

        # Find the creatures block
        creatures_start = text.find('"creatures"')
        if creatures_start == -1:
            creatures_start = text.find("['creatures']")
        if creatures_start == -1:
            return creatures, current_spells, new_discoveries

        # Parse creature entries — WoW SavedVariables use [numericKey] = { ... } format
        # We do a simpler block-by-block parse
        pos = creatures_start
        creature_pattern = re.compile(r'\[(\d+)\]\s*=\s*\{')
        name_pattern = re.compile(r'\["name"\]\s*=\s*"([^"]*)"')
        spells_section = re.compile(r'\["spells"\]\s*=\s*\{')

        # Find all creature blocks
        for cm in creature_pattern.finditer(text, pos):
            entry_id = int(cm.group(1))
            block_start = cm.end()

            # Find creature name
            # Search within a reasonable window after the creature entry
            search_end = min(block_start + 5000, len(text))
            block_text = text[block_start:search_end]

            nm = name_pattern.search(block_text)
            creature_name = nm.group(1) if nm else "Unknown"

            # Skip non-creature entries (could be spell sub-tables)
            if entry_id > 999999:
                continue

            creatures[entry_id] = creature_name

            # Find spells sub-table
            sm = spells_section.search(block_text)
            if not sm:
                continue

            spells_start = sm.end()
            spells_text = block_text[spells_start:]

            # Parse spell entries within spells block
            for spell_match in creature_pattern.finditer(spells_text):
                spell_id = int(spell_match.group(1))
                # Very large IDs are likely creature entries from outer scope, not spell IDs
                if spell_id > 999999:
                    break
                current_spells.add((entry_id, spell_id))

                # Extract spell name
                spell_block_start = spell_match.end()
                spell_block = spells_text[spell_block_start:spell_block_start + 500]
                snm = name_pattern.search(spell_block)
                spell_name = snm.group(1) if snm else f"Spell {spell_id}"

                # Check if this is a new discovery
                if (entry_id, spell_id) not in self._prev_spells:
                    new_discoveries.append((entry_id, spell_id, creature_name, spell_name))

        self._prev_spells = current_spells
        return creatures, current_spells, new_discoveries


def create(config: Config) -> BestiaryScanner:
    return BestiaryScanner(config)

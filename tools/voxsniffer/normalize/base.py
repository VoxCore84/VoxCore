"""Base normalizer interface and utilities."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Any


class BaseNormalizer(ABC):
    """Base class for domain normalizers.

    Normalizers take raw observation records from SavedVariables
    and produce clean, deduplicated domain objects.
    """

    @property
    @abstractmethod
    def obs_type(self) -> str:
        """The observation type this normalizer handles (e.g. 'unit_seen')."""

    @abstractmethod
    def normalize(self, records: list[dict]) -> dict[str, Any]:
        """Process raw records into normalized domain data.

        Returns a dict keyed by entity identifier with merged/deduped data.
        """

    def filter_records(self, all_records: list[dict]) -> list[dict]:
        """Filter records to only those matching this normalizer's obs_type."""
        return [r for r in all_records if isinstance(r, dict) and r.get("t") == self.obs_type]


def safe_get(record: dict, *keys, default=None):
    """Safely traverse nested dicts."""
    val = record
    for k in keys:
        if isinstance(val, dict):
            val = val.get(k, default)
        else:
            return default
    return val


def merge_sets(existing: set | None, new_items) -> set:
    """Merge items into a set, creating if needed."""
    s = existing or set()
    if isinstance(new_items, (list, tuple, set)):
        s.update(new_items)
    elif new_items is not None:
        s.add(new_items)
    return s


def first_non_none(*values):
    """Return first non-None value."""
    for v in values:
        if v is not None:
            return v
    return None

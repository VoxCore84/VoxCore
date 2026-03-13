"""VoxSniffer normalizers — convert raw observations to domain models."""

from .unit_normalizer import UnitNormalizer
from .combat_normalizer import CombatNormalizer
from .vendor_normalizer import VendorNormalizer
from .gossip_normalizer import GossipNormalizer
from .quest_normalizer import QuestNormalizer
from .emote_normalizer import EmoteNormalizer
from .loot_normalizer import LootNormalizer
from .aura_normalizer import AuraNormalizer

ALL_NORMALIZERS = [
    UnitNormalizer(),
    CombatNormalizer(),
    VendorNormalizer(),
    GossipNormalizer(),
    QuestNormalizer(),
    EmoteNormalizer(),
    LootNormalizer(),
    AuraNormalizer(),
]

NORMALIZER_MAP = {n.obs_type: n for n in ALL_NORMALIZERS}


def normalize_all(records: list[dict]) -> dict[str, dict]:
    """Run all normalizers and return results keyed by obs_type."""
    results = {}
    for norm in ALL_NORMALIZERS:
        filtered = norm.filter_records(records)
        if filtered:
            results[norm.obs_type] = norm.normalize(records)
    return results

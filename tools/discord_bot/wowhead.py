"""Parse Wowhead URLs and extract entity type + ID."""

import re

# Matches: https://www.wowhead.com/item=192469/some-item-name
#          https://wowhead.com/quest=79504
#          https://www.wowhead.com/npc=216438/granny-scribbles
#          https://www.wowhead.com/spell=1459/arcane-intellect
_RE_WOWHEAD = re.compile(
    r"https?://(?:www\.)?wowhead\.com/"
    r"(item|quest|npc|spell|object|achievement|zone)"
    r"=(\d+)",
    re.IGNORECASE,
)

# Entity type → DB table / lookup source
ENTITY_SOURCES = {
    "item": ("hotfixes.item_sparse", "ID"),
    "quest": ("world.quest_template", "ID"),
    "npc": ("world.creature_template", "entry"),
    "spell": ("hotfixes.spell_name", "ID"),
    "object": ("world.gameobject_template", "entry"),
    "achievement": ("wago_csv", "Achievement"),
    "zone": ("wago_csv", "AreaTable"),
}


def extract_wowhead_links(text: str) -> list[tuple[str, int]]:
    """Extract all (entity_type, entity_id) tuples from a message.

    Returns e.g. [("item", 192469), ("quest", 79504)].
    """
    return [(m.group(1).lower(), int(m.group(2))) for m in _RE_WOWHEAD.finditer(text)]

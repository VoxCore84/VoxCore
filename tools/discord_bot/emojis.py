"""Application emoji helper — loads custom emojis from the Discord app and provides easy access."""

import logging
from typing import Optional

import discord

log = logging.getLogger(__name__)

# Cached emoji map: name → formatted string (e.g., "<:spell:123456789>")
_emoji_cache: dict[str, str] = {}


async def load_app_emojis(bot: discord.Client):
    """Fetch all application emojis and cache them. Call once in on_ready."""
    global _emoji_cache
    try:
        emojis = await bot.fetch_application_emojis()
        _emoji_cache = {e.name: str(e) for e in emojis}
        log.info("Loaded %d application emojis", len(_emoji_cache))
    except Exception:
        log.exception("Failed to load application emojis")
        _emoji_cache = {}


def e(name: str, fallback: str = "") -> str:
    """Get an emoji by name. Returns the formatted emoji string or fallback.

    Usage:
        e("spell", "⚡")  → "<:spell:123456>" if loaded, else "⚡"
        e("dragon")        → "<:dragon:123456>" if loaded, else ""
    """
    return _emoji_cache.get(name, fallback)


# Pre-defined fallbacks for each emoji name
FALLBACKS = {
    # Bot features
    "lookup": "\U0001f50d",      # 🔍
    "spell": "\u26a1",           # ⚡
    "item": "\U0001f6e1\ufe0f",  # 🛡️
    "dragon": "\U0001f409",      # 🐉
    "fix": "\U0001f527",         # 🔧
    "server": "\u2699\ufe0f",    # ⚙️
    "faq": "\u2753",             # ❓
    "bug": "\U0001f41b",         # 🐛
    "build_alert": "\U0001f6a8", # 🚨
    "watch": "\U0001f441\ufe0f", # 👁️
    "guide": "\U0001f4d6",       # 📖
    "target": "\U0001f3af",      # 🎯
    # Factions
    "alliance": "\U0001f537",    # 🔷
    "horde": "\U0001f534",       # 🔴
    "neutral": "\u26aa",         # ⚪
    # Misc
    "gold": "\U0001fa99",        # 🪙
    "loot": "\U0001f4e6",        # 📦
    "portal": "\U0001f300",      # 🌀
    "hearthstone": "\U0001f3e0", # 🏠
    "shield": "\U0001f6e1\ufe0f",# 🛡️
    "hammer": "\U0001f528",      # 🔨
    "speed": "\U0001f3c3",       # 🏃
    # Difficulties
    "diff_normal": "\U0001f7e2", # 🟢
    "diff_heroic": "\U0001f535", # 🔵
    "diff_mythic": "\U0001f7e3", # 🟣
    "diff_lfr": "\U0001f7e0",   # 🟠
    "diff_tw": "\U0001f7e4",    # 🟤
    # Explore
    "cat_explore": "\U0001f5fa\ufe0f",  # 🗺️
    # Checkmarks
    "found": "\u2705",           # ✅
    "missing": "\u274c",         # ❌
}


def em(name: str, fallback: str | None = None) -> str:
    """Get emoji with auto-fallback from FALLBACKS dict.

    Usage:
        em("spell")            → "<:spell:123>" if loaded, else "⚡" (from FALLBACKS)
        em("spell", "⚡")      → "<:spell:123>" if loaded, else "⚡" (explicit override)
    """
    cached = _emoji_cache.get(name)
    if cached:
        return cached
    if fallback is not None:
        return fallback
    return FALLBACKS.get(name, "")

"""FAQ auto-responder — pattern-matches support questions and replies instantly.

Patterns and responses derived from analysis of 30K+ messages across 10 channels
in the DraconicWoW Discord (Apr 2024 – Mar 2026).
"""

import re
import json
import logging
from pathlib import Path

import discord
from discord.ext import commands

from config import SUPPORT_CHANNEL_IDS, GITHUB_REPO, GITHUB_AUTH_SQL_PATH
from emojis import em

log = logging.getLogger(__name__)

# Load FAQ data from JSON
_FAQ_PATH = Path(__file__).parent.parent / "data" / "faq_responses.json"


def _load_faq() -> list[dict]:
    with open(_FAQ_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


class FAQResponder(commands.Cog):
    """Watches support channels and auto-answers common questions."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.faq_entries = _load_faq()
        # Compile patterns once
        for entry in self.faq_entries:
            entry["_compiled"] = re.compile(entry["pattern"], re.IGNORECASE)
        # Cooldown: don't spam the same FAQ in the same channel within 5 minutes
        # key = (channel_id, faq_id) → last trigger timestamp
        self._cooldowns: dict[tuple[int, str], float] = {}
        log.info("FAQResponder loaded %d FAQ entries", len(self.faq_entries))

    def _check_cooldown(self, channel_id: int, faq_id: str, now: float) -> bool:
        """Returns True if this FAQ can fire (not on cooldown)."""
        key = (channel_id, faq_id)
        last = self._cooldowns.get(key, 0)
        if now - last < 300:  # 5 minute cooldown
            return False
        self._cooldowns[key] = now
        return True

    @commands.Cog.listener()
    async def on_message(self, message: discord.Message):
        # Ignore bots, DMs, and non-support channels
        if message.author.bot:
            return
        if not message.guild:
            return
        if SUPPORT_CHANNEL_IDS and message.channel.id not in SUPPORT_CHANNEL_IDS:
            return

        content = message.content
        if len(content) < 10:
            return

        import time
        now = time.time()

        for entry in self.faq_entries:
            if entry["_compiled"].search(content):
                faq_id = entry["id"]
                if not self._check_cooldown(message.channel.id, faq_id, now):
                    continue

                response = entry["response"]
                emoji = em("faq", "\u2753")
                embed = discord.Embed(
                    title=f"{emoji} FAQ: {entry['title']}",
                    description=response,
                    color=discord.Color.blue(),
                )
                embed.set_footer(text=f"{em('fix', '\U0001f527')} Automated answer \u2022 If this doesn't help, wait for a human!")
                await message.reply(embed=embed, mention_author=False)
                log.info("FAQ '%s' triggered by %s in #%s", faq_id, message.author, message.channel)
                return  # Only one FAQ per message


async def setup(bot: commands.Bot):
    await bot.add_cog(FAQResponder(bot))

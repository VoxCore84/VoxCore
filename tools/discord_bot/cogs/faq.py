"""FAQ auto-responder — pattern-matches support questions and replies instantly.

Patterns and responses derived from analysis of 30K+ messages across 10 channels
in the DraconicWoW Discord (Apr 2024 – Mar 2026).
"""

import json
import logging
import re
from collections import Counter
from pathlib import Path

import discord
from discord import app_commands
from discord.ext import commands

from config import SUPPORT_CHANNEL_IDS, GITHUB_REPO, GITHUB_AUTH_SQL_PATH
from emojis import em

log = logging.getLogger(__name__)

# Load FAQ data from JSON
_FAQ_PATH = Path(__file__).parent.parent / "data" / "faq_responses.json"
_STATS_PATH = Path(__file__).parent.parent / "data" / "faq_stats.json"


def _load_faq() -> list[dict]:
    with open(_FAQ_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def _load_stats() -> Counter:
    try:
        with open(_STATS_PATH, "r", encoding="utf-8") as f:
            return Counter(json.load(f))
    except Exception:
        return Counter()


def _save_stats(stats: Counter):
    _STATS_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(_STATS_PATH, "w", encoding="utf-8") as f:
        json.dump(dict(stats), f, indent=2)


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
        # Persistent stats: how many times each FAQ has triggered
        self._stats: Counter = _load_stats()
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
        if len(content) < 8:
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
                
                view = discord.ui.View(timeout=120)
                async def launch_dm_callback(interaction: discord.Interaction):
                    await interaction.response.send_message("I've sent you a DM! Let's figure this out together.", ephemeral=True)
                    try:
                        # Grab the DMGuide cog and trigger it manually
                        dm_cog = self.bot.get_cog("DMGuide")
                        if dm_cog:
                            dm_channel = await interaction.user.create_dm()
                            
                            # Hardcode import here to avoid circular dep, since DMStepView is in dm_guide
                            from cogs.dm_guide import DMStepView, SETUP_STEPS
                            
                            step_data = SETUP_STEPS[0]
                            icon = em("robot", "\U0001f916")
                            dm_embed = discord.Embed(
                                title=f"{icon} {step_data['title']}",
                                description=step_data['desc'],
                                color=discord.Color.blue()
                            )
                            await dm_channel.send(embed=dm_embed, view=DMStepView(0))
                    except discord.Forbidden:
                        await interaction.followup.send("I tried to DM you, but your privacy settings are blocking DMs from server members!", ephemeral=True)
                
                btn = discord.ui.Button(
                    label="Still stuck? Help me!",
                    emoji="\U0001f198", # SOS emoji
                    style=discord.ButtonStyle.danger,
                    custom_id="launch_dm_troubleshooter_faq"
                )
                btn.callback = launch_dm_callback
                view.add_item(btn)

                await message.reply(embed=embed, view=view, mention_author=False)
                self._stats[faq_id] += 1
                _save_stats(self._stats)
                log.info("FAQ '%s' triggered by %s in #%s (total: %d)", faq_id, message.author, message.channel, self._stats[faq_id])
                return  # Only one FAQ per message

    @app_commands.command(name="faqstats", description="Show which FAQ topics trigger most often (admin only)")
    @app_commands.checks.has_permissions(manage_messages=True)
    async def faq_stats(self, interaction: discord.Interaction):
        if not self._stats:
            await interaction.response.send_message("No FAQ stats yet — the bot hasn't triggered any FAQs.", ephemeral=True)
            return

        # Build a title lookup
        title_map = {e["id"]: e["title"] for e in self.faq_entries}

        # Sort by count descending
        lines = []
        total = sum(self._stats.values())
        for faq_id, count in self._stats.most_common():
            title = title_map.get(faq_id, faq_id)
            pct = count / total * 100 if total else 0
            lines.append(f"**{count}x** — {title} ({pct:.0f}%)")

        icon = em("faq", "\u2753")
        embed = discord.Embed(
            title=f"{icon} FAQ Trigger Stats",
            description="\n".join(lines) + f"\n\n**Total triggers:** {total}",
            color=discord.Color.blue(),
        )
        embed.set_footer(text="Stats persist across bot restarts")
        await interaction.response.send_message(embed=embed, ephemeral=True)


async def setup(bot: commands.Bot):
    await bot.add_cog(FAQResponder(bot))

"""Auto-moderation — spam detection, invite link filtering, new account gating."""

import re
import time
import logging
from collections import defaultdict

import discord
from discord.ext import commands

from emojis import em

log = logging.getLogger(__name__)

# Discord invite link pattern
INVITE_RE = re.compile(
    r"(?:https?://)?(?:www\.)?(?:discord\.(?:gg|io|me|li|com/invite)|discordapp\.com/invite)/[a-zA-Z0-9]+",
    re.I,
)

# Spam detection: max messages per window
SPAM_MAX_MESSAGES = 5
SPAM_WINDOW_SECONDS = 10

# New account gate: accounts younger than this get flagged
NEW_ACCOUNT_DAYS = 7


class AutoMod(commands.Cog):
    """Basic auto-moderation: spam, invite links, new account alerts."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        # Spam tracking: user_id → list of timestamps
        self._message_times: dict[int, list[float]] = defaultdict(list)
        # Track users already warned (don't spam warnings)
        self._warned_spam: set[int] = set()
        self._warned_invite: dict[int, float] = {}

    @commands.Cog.listener()
    async def on_message(self, message: discord.Message):
        if message.author.bot or not message.guild:
            return

        # --- Invite link filter ---
        if INVITE_RE.search(message.content):
            # Allow server admins/mods to post invites
            if not message.author.guild_permissions.manage_messages:
                await self._handle_invite(message)
                return

        # --- Spam detection ---
        await self._check_spam(message)

    @commands.Cog.listener()
    async def on_member_join(self, member: discord.Member):
        """Flag very new Discord accounts joining the server."""
        if member.bot:
            return

        account_age = (discord.utils.utcnow() - member.created_at).days
        if account_age < NEW_ACCOUNT_DAYS:
            log.info(
                "New account alert: %s (ID: %d) — account is %d days old",
                member, member.id, account_age,
            )
            # Find a mod/log channel to post the alert
            # Try to find a channel named "mod-log" or "bot-log"
            for ch_name in ("mod-log", "bot-log", "staff"):
                channel = discord.utils.get(member.guild.text_channels, name=ch_name)
                if channel:
                    icon = em("target", "\U0001f3af")
                    embed = discord.Embed(
                        description=(
                            f"{icon} **New Account Alert:** {member.mention} "
                            f"joined with an account only **{account_age} day(s) old**.\n"
                            f"Created: {discord.utils.format_dt(member.created_at, 'R')}"
                        ),
                        color=discord.Color.yellow(),
                    )
                    await channel.send(embed=embed)
                    break

    async def _handle_invite(self, message: discord.Message):
        """Delete invite links from non-moderators and warn."""
        now = time.time()
        # Don't warn the same user more than once per minute
        last_warn = self._warned_invite.get(message.author.id, 0)
        if now - last_warn < 60:
            try:
                await message.delete()
            except discord.Forbidden:
                pass
            return

        self._warned_invite[message.author.id] = now
        try:
            await message.delete()
        except discord.Forbidden:
            log.warning("Can't delete invite link from %s (missing permissions)", message.author)
            return

        icon = em("target", "\U0001f3af")
        embed = discord.Embed(
            description=f"{icon} {message.author.mention} — Discord invite links are not allowed here.",
            color=discord.Color.red(),
        )
        embed.set_footer(text="Contact a moderator if you need to share a link")
        try:
            await message.channel.send(embed=embed, delete_after=15)
        except discord.Forbidden:
            pass
        log.info("Deleted invite link from %s in #%s", message.author, message.channel)

    async def _check_spam(self, message: discord.Message):
        """Track message rate and warn on spam."""
        now = time.time()
        uid = message.author.id
        times = self._message_times[uid]

        # Prune old entries
        times[:] = [t for t in times if now - t < SPAM_WINDOW_SECONDS]
        times.append(now)

        if len(times) >= SPAM_MAX_MESSAGES:
            if uid not in self._warned_spam:
                self._warned_spam.add(uid)
                icon = em("target", "\U0001f3af")
                embed = discord.Embed(
                    description=f"{icon} {message.author.mention} — Please slow down! You're sending messages too quickly.",
                    color=discord.Color.orange(),
                )
                try:
                    await message.channel.send(embed=embed, delete_after=10)
                except discord.Forbidden:
                    pass
                log.info("Spam warning sent to %s in #%s", message.author, message.channel)

                # Clear the warning after 30 seconds so they can be warned again
                async def _clear_warning():
                    import asyncio
                    await asyncio.sleep(30)
                    self._warned_spam.discard(uid)

                self.bot.loop.create_task(_clear_warning())


async def setup(bot: commands.Bot):
    await bot.add_cog(AutoMod(bot))

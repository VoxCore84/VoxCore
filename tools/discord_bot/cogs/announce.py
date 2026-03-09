"""Announce command — lets admins post formatted embeds through the bot."""

import logging

import discord
from discord import app_commands
from discord.ext import commands
from emojis import em

log = logging.getLogger(__name__)


class Announce(commands.Cog):
    """Admin command to post formatted announcements via the bot."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @app_commands.command(name="announce", description="Post a formatted announcement (admin only)")
    @app_commands.describe(
        title="Announcement title",
        message="The announcement body (supports Discord markdown)",
        color="Embed color: red, orange, yellow, green, blue, purple (default: blue)",
        channel="Channel to post in (defaults to current channel)",
        ping="Role or @everyone to ping (optional)",
    )
    @app_commands.checks.has_permissions(manage_guild=True)
    async def announce(
        self,
        interaction: discord.Interaction,
        title: str,
        message: str,
        color: str = "blue",
        channel: discord.TextChannel | None = None,
        ping: str | None = None,
    ):
        color_map = {
            "red": discord.Color.red(),
            "orange": discord.Color.orange(),
            "yellow": discord.Color.yellow(),
            "green": discord.Color.green(),
            "blue": discord.Color.blue(),
            "purple": discord.Color.purple(),
        }
        embed_color = color_map.get(color.lower(), discord.Color.blue())
        target = channel or interaction.channel

        icon = em("build_alert", "\U0001f6a8")
        embed = discord.Embed(
            title=f"{icon} {title}",
            description=message,
            color=embed_color,
        )
        embed.set_footer(text=f"Posted by {interaction.user.display_name}")

        content = ping if ping else None

        try:
            await target.send(content=content, embed=embed)
            await interaction.response.send_message(
                f"Announcement posted in {target.mention}!",
                ephemeral=True,
            )
            log.info("Announcement posted by %s in #%s: %s", interaction.user, target.name, title)
        except discord.Forbidden:
            await interaction.response.send_message(
                f"I don't have permission to post in {target.mention}.",
                ephemeral=True,
            )


async def setup(bot: commands.Bot):
    await bot.add_cog(Announce(bot))

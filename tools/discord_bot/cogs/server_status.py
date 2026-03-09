"""Server status commands via SOAP."""

import re
import logging

import discord
from discord import app_commands
from discord.ext import commands

from soap import send_command
from emojis import em

log = logging.getLogger(__name__)


class ServerStatus(commands.Cog):
    """Slash commands for checking server status."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @app_commands.command(name="server", description="Check server status, uptime, and player count")
    async def server_status(self, interaction: discord.Interaction):
        await interaction.response.defer()

        ok, result = await send_command(".server info")

        if ok:
            embed = discord.Embed(
                title=f"{em('server', '\u2699\ufe0f')} Server Status",
                description=f"```\n{result}\n```",
                color=discord.Color.green(),
            )
        else:
            embed = discord.Embed(
                title=f"{em('server', '\u2699\ufe0f')} Server Status",
                description=f"**Server appears to be offline.**\n\n{result}",
                color=discord.Color.red(),
            )

        await interaction.followup.send(embed=embed)

    @app_commands.command(name="online", description="Show current online player count")
    async def online_count(self, interaction: discord.Interaction):
        await interaction.response.defer()

        ok, result = await send_command(".server info")

        if ok:
            # Parse player count from .server info output
            # Typical line: "Connected players: 3. Characters in world: 2."
            m = re.search(r"Connected players:\s*(\d+)", result)
            count = m.group(1) if m else "unknown"
            chars = re.search(r"Characters in world:\s*(\d+)", result)
            char_count = chars.group(1) if chars else None

            desc = f"**Players online:** {count}"
            if char_count:
                desc += f"\n**Characters in world:** {char_count}"

            embed = discord.Embed(
                title="Who's Online",
                description=desc,
                color=discord.Color.green(),
            )
        else:
            embed = discord.Embed(
                title="Who's Online",
                description="**Server appears to be offline.**",
                color=discord.Color.red(),
            )

        await interaction.followup.send(embed=embed)


async def setup(bot: commands.Bot):
    await bot.add_cog(ServerStatus(bot))

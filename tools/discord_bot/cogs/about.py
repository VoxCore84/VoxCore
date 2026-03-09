"""About command — bot info, uptime, version, cog count."""

import time

import discord
from discord import app_commands
from discord.ext import commands
from emojis import em


class About(commands.Cog):
    """Shows bot metadata and runtime stats."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @app_commands.command(name="about", description="Show DraconicBot info, version, and uptime")
    async def about(self, interaction: discord.Interaction):
        from bot import BOT_VERSION

        uptime_s = int(time.time() - self.bot.start_time)
        hours, remainder = divmod(uptime_s, 3600)
        minutes, seconds = divmod(remainder, 60)
        if hours > 0:
            uptime_str = f"{hours}h {minutes}m {seconds}s"
        elif minutes > 0:
            uptime_str = f"{minutes}m {seconds}s"
        else:
            uptime_str = f"{seconds}s"

        cog_count = len(self.bot.cogs)
        cmd_count = len(self.bot.tree.get_commands())
        guild_count = len(self.bot.guilds)

        icon = em("dragon", "\U0001f409")
        embed = discord.Embed(
            title=f"{icon} DraconicBot",
            description=(
                f"Support bot for the DraconicWoW private server community.\n\n"
                f"{em('server', '\u2699\ufe0f')} **Version:** {BOT_VERSION}\n"
                f"{em('speed', '\U0001f3c3')} **Uptime:** {uptime_str}\n"
                f"{em('fix', '\U0001f527')} **Cogs loaded:** {cog_count}\n"
                f"{em('lookup', '\U0001f50d')} **Slash commands:** {cmd_count}\n"
                f"{em('portal', '\U0001f300')} **Servers:** {guild_count}\n"
            ),
            color=discord.Color.blue(),
        )
        embed.set_footer(text="Built with discord.py \u2022 Powered by VoxCore")
        await interaction.response.send_message(embed=embed, ephemeral=True)


async def setup(bot: commands.Bot):
    await bot.add_cog(About(bot))

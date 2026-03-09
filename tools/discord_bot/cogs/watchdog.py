"""Build watchdog — monitors TrinityCore GitHub for new auth SQL updates."""

import logging
from pathlib import Path

import discord
from discord import app_commands
from discord.ext import commands, tasks

from config import CHANNEL_ANNOUNCEMENTS, WATCHDOG_INTERVAL, GITHUB_REPO, GITHUB_AUTH_SQL_PATH
from github_monitor import get_latest_build_info, get_latest_auth_files
from emojis import em

log = logging.getLogger(__name__)

# Persist the last known build to a local file so restarts don't re-announce
_STATE_FILE = Path(__file__).parent.parent / "data" / ".last_known_build"


def _read_last_build() -> int:
    try:
        return int(_STATE_FILE.read_text().strip())
    except Exception:
        return 0


def _write_last_build(build: int):
    _STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    _STATE_FILE.write_text(str(build))


class BuildWatchdog(commands.Cog):
    """Periodically checks TrinityCore for new client build auth SQL updates."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.last_known_build = _read_last_build()

    async def cog_load(self):
        self.check_for_new_build.start()

    async def cog_unload(self):
        self.check_for_new_build.cancel()

    @tasks.loop(seconds=WATCHDOG_INTERVAL)
    async def check_for_new_build(self):
        info = await get_latest_build_info()
        if not info:
            return

        build = info["build"]
        if build <= self.last_known_build:
            return

        # New build detected!
        if self.last_known_build > 0:  # Don't announce on first startup
            log.info("New build detected: %d (was %d)", build, self.last_known_build)
            await self._announce_new_build(info)

        self.last_known_build = build
        _write_last_build(build)

    @check_for_new_build.before_loop
    async def before_check(self):
        await self.bot.wait_until_ready()

    async def _announce_new_build(self, info: dict):
        if not CHANNEL_ANNOUNCEMENTS:
            log.warning("No announcements channel configured — can't post build update")
            return

        channel = self.bot.get_channel(CHANNEL_ANNOUNCEMENTS)
        if not channel:
            log.warning("Announcements channel %d not found", CHANNEL_ANNOUNCEMENTS)
            return

        embed = discord.Embed(
            title=f"{em('build_alert', '\U0001f6a8')} New WoW Client Build Detected",
            description=(
                f"Build **{info['build']}** has been added to TrinityCore.\n\n"
                f"**What this means:** If your WoW client auto-updated, you need to apply "
                f"the new auth SQL to your server before you can connect.\n\n"
                f"**Auth SQL file:** [{info['filename']}]({info['html_url']})\n\n"
                f"**Steps:**\n"
                f"1. Download or copy the SQL from the link above\n"
                f"2. Run it against your `auth` database\n"
                f"3. Restart bnetserver and worldserver\n"
                f"4. Update Arctium if needed"
            ),
            color=discord.Color.red(),
        )
        embed.set_footer(text=f"Source: github.com/{GITHUB_REPO}")

        await channel.send(embed=embed)
        log.info("Announced new build %d in #announcements", info["build"])

    # --- Manual commands ---

    @app_commands.command(name="buildcheck", description="Show the latest TrinityCore auth SQL update")
    async def buildcheck(self, interaction: discord.Interaction):
        await interaction.response.defer()

        info = await get_latest_build_info()
        if not info:
            await interaction.followup.send(embed=discord.Embed(
                title="Build Check",
                description="Could not fetch build info from GitHub. Try again later.",
                color=discord.Color.red(),
            ))
            return

        files = await get_latest_auth_files(5)
        file_list = "\n".join(
            f"- [{f['name']}](https://github.com/{GITHUB_REPO}/blob/master/{GITHUB_AUTH_SQL_PATH}/{f['name']})"
            for f in files
        )

        embed = discord.Embed(
            title=f"{em('build_alert', '\U0001f6a8')} Latest TrinityCore Build Info",
            description=(
                f"**Latest build:** {info['build']}\n"
                f"**Auth SQL:** [{info['filename']}]({info['html_url']})\n\n"
                f"**Recent auth updates:**\n{file_list}\n\n"
                f"Apply the latest SQL to your `auth` database, then restart bnetserver + worldserver."
            ),
            color=discord.Color.blue(),
        )
        embed.set_footer(text=f"Source: github.com/{GITHUB_REPO}")
        await interaction.followup.send(embed=embed)


async def setup(bot: commands.Bot):
    await bot.add_cog(BuildWatchdog(bot))

"""DraconicBot — main bot class."""

import logging

import discord
from discord.ext import commands
from emojis import load_app_emojis

log = logging.getLogger(__name__)

COGS = [
    "cogs.help",
    "cogs.faq",
    "cogs.lookups",
    "cogs.triage",
    "cogs.server_status",
    "cogs.watchdog",
    "cogs.onboarding",
    "cogs.wowhead_resolver",
    "cogs.troubleshooter",
    "cogs.changelog",
    "cogs.automod",
    "cogs.welcome_role",
]


class VoxCoreBot(commands.Bot):
    """DraconicWoW support bot with FAQ, lookups, triage, and build monitoring."""

    def __init__(self):
        intents = discord.Intents.default()
        intents.message_content = True  # Required for FAQ pattern matching
        intents.members = True          # Required for on_member_join onboarding

        super().__init__(
            command_prefix="!",  # Fallback prefix (slash commands are primary)
            intents=intents,
            help_command=None,
        )

    async def setup_hook(self):
        """Load all cogs and sync slash commands."""
        for cog_path in COGS:
            try:
                await self.load_extension(cog_path)
                log.info("Loaded cog: %s", cog_path)
            except Exception:
                log.exception("Failed to load cog: %s", cog_path)

        # Sync slash commands with Discord
        synced = await self.tree.sync()
        log.info("Synced %d slash commands", len(synced))

    async def on_ready(self):
        log.info("Bot ready: %s (ID: %s)", self.user, self.user.id)
        log.info("Connected to %d guild(s)", len(self.guilds))

        # Load application emojis
        await load_app_emojis(self)

        # Set a status message
        await self.change_presence(
            activity=discord.Activity(
                type=discord.ActivityType.watching,
                name="/help for commands",
            )
        )

    async def on_command_error(self, ctx: commands.Context, error: commands.CommandError):
        if isinstance(error, commands.CommandNotFound):
            return  # Silently ignore unknown prefix commands
        log.exception("Command error in %s: %s", ctx.command, error)

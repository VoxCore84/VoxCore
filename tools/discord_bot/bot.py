"""DraconicBot — main bot class."""

import logging
import time

import discord
from discord.ext import commands
from emojis import load_app_emojis
from config import (
    CHANNEL_TROUBLESHOOTING, CHANNEL_BUGREPORT, CHANNEL_TWW,
    CHANNEL_GENERAL, CHANNEL_ANNOUNCEMENTS, SUPPORT_CHANNEL_IDS,
)

log = logging.getLogger(__name__)

BOT_VERSION = "2.1.0"

COGS = [
    "cogs.help",
    "cogs.faq",
    "cogs.lookups",
    "cogs.triage",
    "cogs.troubleshooter",
    "cogs.frustration",
    "cogs.log_parser",
    "cogs.dm_guide",
    "cogs.diagnoser",
    "cogs.sme_kb",
    "cogs.watchdog",
    "cogs.changelog",
    "cogs.automod",
    "cogs.welcome_role",
    "cogs.about",
    "cogs.announce",
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
        self.start_time = time.time()

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

        # Startup config validation
        self._validate_config()

        # Set a status message
        await self.change_presence(
            activity=discord.Activity(
                type=discord.ActivityType.watching,
                name="/help for commands",
            )
        )

    def _validate_config(self):
        """Log warnings for unconfigured channels so admins know what's missing."""
        channel_map = {
            "CHANNEL_TROUBLESHOOTING": CHANNEL_TROUBLESHOOTING,
            "CHANNEL_BUGREPORT": CHANNEL_BUGREPORT,
            "CHANNEL_TWW": CHANNEL_TWW,
            "CHANNEL_GENERAL": CHANNEL_GENERAL,
            "CHANNEL_ANNOUNCEMENTS": CHANNEL_ANNOUNCEMENTS,
        }
        missing = [name for name, cid in channel_map.items() if not cid]
        if missing:
            log.warning(
                "Unconfigured channels (set in .env): %s — some features will be disabled",
                ", ".join(missing),
            )
        if not SUPPORT_CHANNEL_IDS:
            log.warning("No support channels configured — FAQ and wowhead resolver will be inactive")

    async def on_command_error(self, ctx: commands.Context, error: commands.CommandError):
        if isinstance(error, commands.CommandNotFound):
            return  # Silently ignore unknown prefix commands
        log.exception("Command error in %s: %s", ctx.command, error)

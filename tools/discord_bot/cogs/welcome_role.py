"""Welcome role — button-verified member role assignment."""

import logging

import discord
from discord import app_commands
from discord.ext import commands

from config import CHANNEL_GENERAL
from emojis import em

log = logging.getLogger(__name__)

# Role name to assign. Must exist in the server.
VERIFIED_ROLE_NAME = "Verified"


class VerifyButton(discord.ui.Button):
    """Button that assigns the Verified role when clicked."""

    def __init__(self):
        super().__init__(
            label="I've read the rules — let me in!",
            style=discord.ButtonStyle.green,
            emoji="\u2705",
            custom_id="draconicbot:verify",  # Persistent across bot restarts
        )

    async def callback(self, interaction: discord.Interaction):
        role = discord.utils.get(interaction.guild.roles, name=VERIFIED_ROLE_NAME)
        if not role:
            await interaction.response.send_message(
                f"The **{VERIFIED_ROLE_NAME}** role doesn't exist yet. Ask an admin to create it.",
                ephemeral=True,
            )
            return

        member = interaction.user
        if role in member.roles:
            await interaction.response.send_message(
                "You're already verified!",
                ephemeral=True,
            )
            return

        try:
            await member.add_roles(role, reason="Self-verified via DraconicBot")
            icon = em("found", "\u2705")
            await interaction.response.send_message(
                f"{icon} You've been verified! Welcome to DraconicWoW.",
                ephemeral=True,
            )
            log.info("Verified member: %s", member)
        except discord.Forbidden:
            await interaction.response.send_message(
                "I don't have permission to assign roles. Ask an admin to check my role hierarchy.",
                ephemeral=True,
            )


class VerifyView(discord.ui.View):
    """Persistent view containing the verify button."""

    def __init__(self):
        super().__init__(timeout=None)  # Never expires
        self.add_item(VerifyButton())


class WelcomeRole(commands.Cog):
    """Lets members self-verify by clicking a button. Admins post the panel with /verifypanel."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    async def cog_load(self):
        # Register the persistent view so it works after bot restarts
        self.bot.add_view(VerifyView())

    @app_commands.command(name="verifypanel", description="Post the verification button panel (admin only)")
    @app_commands.checks.has_permissions(manage_guild=True)
    async def verify_panel(self, interaction: discord.Interaction):
        icon = em("dragon", "\U0001f409")
        embed = discord.Embed(
            title=f"{icon} Welcome to DraconicWoW!",
            description=(
                "Click the button below to verify yourself and gain access to the server channels.\n\n"
                "By verifying, you confirm that you've read the rules and are here for WoW private server development."
            ),
            color=discord.Color.green(),
        )
        embed.set_footer(text="DraconicBot \u2022 One-click verification")
        await interaction.response.send_message("Panel posted!", ephemeral=True)
        await interaction.channel.send(embed=embed, view=VerifyView())
        log.info("Verification panel posted by %s in #%s", interaction.user, interaction.channel)


async def setup(bot: commands.Bot):
    await bot.add_cog(WelcomeRole(bot))

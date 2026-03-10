import discord
import re
from discord.ext import commands
from config import SUPPORT_CHANNEL_IDS
from emojis import em

# Regex to catch frustrated users who might be lost
FRUSTRATION_PATTERN = re.compile(
    r"(i.?m so|i.?m really|very|super)?\s*(confused|frustrated|lost|giving up|give up|about to quit)|"
    r"(this is|it.?s)\s*(too hard|too difficult|impossible|make no sense|make any sense)|"
    r"(i don.?t|i cannot|i can.?t)\s*(understand|figure this out|get this to work)|"
    r"i.?ve been trying for (hours|days|a long time)|"
    r"can someone (just )?(please )?(help|explain|hold my hand)",
    re.IGNORECASE
)

class Frustration(commands.Cog):
    """Detects when a user is frustrated and offers guided DM help."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.Cog.listener("on_message")
    async def on_message(self, message: discord.Message):
        if message.author.bot:
            return

        # Only trigger in support channels
        if SUPPORT_CHANNEL_IDS and message.channel.id not in SUPPORT_CHANNEL_IDS:
            return

        # Check for frustration keywords
        if FRUSTRATION_PATTERN.search(message.content):
            icon = em("lifesaver", "\U0001f6df")
            embed = discord.Embed(
                title=f"{icon} Need a hand?",
                description=(
                    f"Hi {message.author.mention}, you sound a bit frustrated! Setting up a private server for the first time is "
                    "definitely tricky, and it's totally normal to feel stuck. There are a lot of moving parts.\n\n"
                    "If you'd like, I can walk you through finding the problem step-by-step in your Private Direct Messages, "
                    "so you don't have to figure it all out at once."
                ),
                color=discord.Color.brand_green()
            )
            embed.set_footer(text="Click the button below to start a private troubleshooting session.")

            view = discord.ui.View(timeout=120)
            
            # Button to launch the DM Troubleshooter Guide
            async def launch_dm_guide(interaction: discord.Interaction):
                await interaction.response.send_message("I've sent you a DM! Let's figure this out together.", ephemeral=True)
                
                # In the future this will trigger cogs.dm_guide
                try:
                    dm_channel = await interaction.user.create_dm()
                    dm_embed = discord.Embed(
                        title="DraconicBot Setup Guide",
                        description="Welcome to the step-by-step setup guide! First question:\n\n**Where are you stuck?**",
                        color=discord.Color.blue()
                    )
                    await dm_channel.send(embed=dm_embed)
                except discord.Forbidden:
                    await interaction.followup.send("I tried to DM you, but your privacy settings are blocking DMs from server members!", ephemeral=True)

            btn = discord.ui.Button(
                label="Help me step-by-step",
                emoji="\U0001f91d", # handshake
                style=discord.ButtonStyle.success,
                custom_id="launch_dm_troubleshooter"
            )
            btn.callback = launch_dm_guide
            view.add_item(btn)

            await message.reply(embed=embed, view=view)

async def setup(bot: commands.Bot):
    await bot.add_cog(Frustration(bot))

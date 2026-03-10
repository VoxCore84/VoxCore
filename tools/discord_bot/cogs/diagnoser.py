import discord
from discord.ext import commands
from discord import app_commands
from pathlib import Path

_DATA_DIR = Path(__file__).parent.parent / "data"


class Diagnoser(commands.Cog):
    def __init__(self, bot):
        self.bot = bot
        self.diagnose_path = _DATA_DIR / "diagnose.bat"

    @app_commands.command(name="diagnose", description="Download the auto-fixer tool to check your server folder for mistakes!")
    async def diagnose_command(self, interaction: discord.Interaction):
        """Sends the diagnose.bat file to the user."""
        
        embed = discord.Embed(
            title="🛠️ DraconicWoW Auto-Fixer",
            description=(
                "Please download the attached `diagnose.bat` file and place it **inside your server folder** "
                "(the folder that contains `worldserver.exe` and `bnetserver.exe`).\n\n"
                "Double-click it to run it! It will automatically check if you have your IPs set correctly, "
                "if your maps are extracted, and if MySQL is running properly.\n\n"
                "*If it finds any errors in red, take a screenshot of the black window and post it here!*"
            ),
            color=discord.Color.blue()
        )
        
        embed.set_footer(text="This file is safe and can be opened in Notepad to see exactly what it does.")
        
        if not self.diagnose_path.exists():
            await interaction.response.send_message("The diagnostic tool is currently missing from my files!", ephemeral=True)
            return
            
        # Send the embed and the file
        file = discord.File(self.diagnose_path, filename="diagnose.bat")
        await interaction.response.send_message(embed=embed, file=file)

async def setup(bot):
    await bot.add_cog(Diagnoser(bot))

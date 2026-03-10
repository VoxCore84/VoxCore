import discord
import re
from discord.ext import commands
from config import SUPPORT_CHANNEL_IDS
from emojis import em

class LogParser(commands.Cog):
    """Parses uploaded .conf and .log files to help noobs automatically."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.Cog.listener("on_message")
    async def on_message(self, message: discord.Message):
        if message.author.bot or not message.attachments:
            return

        # Only trigger in support channels
        if SUPPORT_CHANNEL_IDS and message.channel.id not in SUPPORT_CHANNEL_IDS:
            return

        for attachment in message.attachments:
            if attachment.filename.lower() == "worldserver.conf":
                await self.parse_config(message, attachment)
                return
            elif attachment.filename.lower() in ["server.log", "crash.log", "crash.txt", "dberrors.log"]:
                await self.parse_log(message, attachment)
                return

    async def parse_config(self, message: discord.Message, attachment: discord.Attachment):
        """Validates simple worldserver.conf beginner mistakes."""
        file_bytes = await attachment.read()
        try:
            content = file_bytes.decode('utf-8')
        except UnicodeDecodeError:
            return

        errors = []
        
        # Check DataDir
        if 'DataDir = "."' not in content and "DataDir = '.'" not in content:
            datadir_match = re.search(r'^DataDir\s*=\s*([^\n]+)', content, re.MULTILINE)
            if datadir_match:
                errors.append(f"**Maps Folder (`DataDir`)**: Yours is set to `{datadir_match.group(1)}`. Unless you know exactly what you are doing, you should erase that and make it exactly `DataDir = \".\"`.")

        # Check Login/World Database passwords
        if '127.0.0.1;3306;trinity;trinity' in content:
            errors.append("**Database Password**: You are using the default TrinityCore password. If you are using UniServerZ for a repack, the password should be `127.0.0.1;3306;root;admin;auth` (and `world` / `characters`).")

        if errors:
            icon = em("page", "\U0001f4c4")
            embed = discord.Embed(
                title=f"{icon} I checked your config file!",
                description=f"Hey {message.author.mention}, I read your `worldserver.conf` file and noticed some common setup mistakes:\n\n" + "\n\n".join(errors),
                color=discord.Color.yellow()
            )
            await message.reply(embed=embed)
        else:
            await message.add_reaction("\U00002705") # Green checkmark


    async def parse_log(self, message: discord.Message, attachment: discord.Attachment):
        """Validates Server.log crashes and assertions."""
        file_bytes = await attachment.read()
        try:
            content = file_bytes.decode('utf-8')
        except UnicodeDecodeError:
            return

        error_msg = None
        
        # Crash 1: Database totally unavailable
        if "Could not connect to MySQL" in content or "DatabasePool" in content and "NOT opened" in content:
            error_msg = "**Database Connection Failed!**\nThe server can't talk to MySQL. If you are using UniServerZ, make sure you clicked 'Start MySQL' and that the icon is green, not red. (If it's red, another program on your computer is using port 3306!)."
            
        # Crash 2: Missing maps
        elif "Assertion failed: (result), function InitMap" in content or "GridMap::load" in content or "Map file" in content and "does not exist" in content:
            error_msg = "**Missing Map Files!**\nThe server is trying to load the world, but your map files aren't there! You need to go into your `_retail_` WoW folder and run the `mapextractor.exe` and `vmap` tools, then copy the result folders to your server."
            
        # Crash 3: Bad Auth/Bnet seed
        elif "Missing auth seed" in content or "Client build" in content:
            error_msg = "**Client/Server Version Mismatch!**\nBlizzard updated the Retail WoW game, but your server is still on the old version. Type `/buildcheck` to find the update file, run it in your database, and restart your server."

        # Crash 4: Port in use
        elif "bind failed" in content or "Address already in use" in content:
            error_msg = "**Port Already In Use!**\nYou either have *two* worldservers open at the same time, or another app on your PC is using port 8085."

        if error_msg:
            icon = em("mag", "\U0001f50d")
            embed = discord.Embed(
                title=f"{icon} Log File Analysis",
                description=f"Hey {message.author.mention}, I read your crash log and found the exact problem:\n\n{error_msg}",
                color=discord.Color.red()
            )
            await message.reply(embed=embed)
        else:
            await message.add_reaction("\U0001f440") # Eyes emoji: "I looked but didn't find anything obvious"

async def setup(bot: commands.Bot):
    await bot.add_cog(LogParser(bot))

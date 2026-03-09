"""Entry point: python -m discord_bot"""

import logging
import sys

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

# Suppress noisy discord.py gateway logs
logging.getLogger("discord.gateway").setLevel(logging.WARNING)
logging.getLogger("discord.http").setLevel(logging.WARNING)

from config import DISCORD_TOKEN
from bot import VoxCoreBot

if not DISCORD_TOKEN or DISCORD_TOKEN == "your_token_here":
    print("ERROR: Set DISCORD_TOKEN in tools/discord_bot/.env")
    print("       Copy .env.example to .env and fill in your bot token.")
    sys.exit(1)

bot = VoxCoreBot()
bot.run(DISCORD_TOKEN)

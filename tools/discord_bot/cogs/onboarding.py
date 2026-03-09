"""New member onboarding — DM a quick-start checklist when someone joins."""

import logging

import discord
from discord.ext import commands
from emojis import em

log = logging.getLogger(__name__)

def _welcome_message() -> str:
    return f"""{em('dragon', '\U0001f409')} **Welcome to the DraconicWoW server!** Here's a quick-start checklist:

{em('build_alert', '\U0001f6a8')} **1. Get the right client build**
Use `/buildcheck` in any channel to see the current required WoW build version.

{em('server', '\u2699\ufe0f')} **2. Get Arctium Launcher**
You need Arctium to connect to the server. Make sure your version matches the server build.
Note: Arctium requires a CPU with **AVX2** support (Intel mid-2013+ / AMD 2015+).

{em('fix', '\U0001f527')} **3. Set up your realmlist**
In your `auth` database, the `realmlist` table should point to the server's IP address.
For local play: `127.0.0.1`

{em('portal', '\U0001f300')} **4. Ports**
Make sure these ports are open/forwarded if hosting remotely:
- `1119` — BNet authentication
- `8085` — Worldserver
- `8086` — Instance server

{em('cat_explore', '\U0001f5fa\ufe0f')} **5. Extract maps** (if compiling from source)
Run all 4 extractors in order: `mapextractor` → `vmapextractor` → `vmap4assembler` → `mmaps_generator`

{em('guide', '\U0001f4d6')} **Need help?** Head to the troubleshooting channel!
Use `/spell`, `/item`, `/creature`, or `/area` to look up game data.
Use `/server` to check if the server is online.

Have fun!"""


class Onboarding(commands.Cog):
    """Sends a welcome DM to new members with setup instructions."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.Cog.listener()
    async def on_member_join(self, member: discord.Member):
        if member.bot:
            return

        try:
            await member.send(_welcome_message())
            log.info("Sent welcome DM to %s", member)
        except discord.Forbidden:
            log.info("Can't DM %s (DMs disabled)", member)
        except discord.HTTPException as e:
            log.warning("Failed to send welcome DM to %s: %s", member, e)


async def setup(bot: commands.Bot):
    await bot.add_cog(Onboarding(bot))

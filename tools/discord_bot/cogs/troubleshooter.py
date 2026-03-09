"""Guided troubleshooter — interactive button-driven flows for common setup issues."""

import discord
from discord import app_commands
from discord.ext import commands
from emojis import em


# ── Decision tree structure ─────────────────────────────────────────
# Each node: {prompt, options: [{label, emoji, next_node | answer}]}
# If "answer" is present, that's a leaf node with the final response.
# If "next_node" is present, drill deeper.

TREES = {
    "cant_connect": {
        "prompt": "What happens when you try to connect?",
        "options": [
            {
                "label": "Can't reach server at all",
                "emoji": "\U0001f6ab",
                "next_node": "cant_reach",
            },
            {
                "label": "Wrong version / build mismatch",
                "emoji": "\U0001f504",
                "answer": (
                    "**Build Mismatch Fix:**\n\n"
                    "1. Use `/buildcheck` to see the current required build\n"
                    "2. If your WoW client auto-updated, you need the new auth SQL\n"
                    "3. Download the SQL from the link in `/buildcheck`\n"
                    "4. Run it against your `auth` database\n"
                    "5. Restart **bnetserver** and **worldserver**\n"
                    "6. Make sure your Arctium Launcher version matches"
                ),
            },
            {
                "label": "Stuck at loading screen",
                "emoji": "\u23f3",
                "answer": (
                    "**Stuck at Loading Screen:**\n\n"
                    "This usually means missing or corrupted map data.\n\n"
                    "1. Re-run all 4 extractors in order:\n"
                    "   `mapextractor` \u2192 `vmapextractor` \u2192 `vmap4assembler` \u2192 `mmaps_generator`\n"
                    "2. Make sure the output folders (`maps/`, `vmaps/`, `mmaps/`) are in your server directory\n"
                    "3. Check `worldserver.conf` \u2014 `DataDir` must point to the folder containing these\n"
                    "4. Restart worldserver after re-extracting"
                ),
            },
            {
                "label": "Disconnected after login",
                "emoji": "\u26a0\ufe0f",
                "answer": (
                    "**Disconnected After Login:**\n\n"
                    "1. Check if worldserver is still running (look at the console window)\n"
                    "2. Check `Server.log` for crash dumps or errors around the disconnect time\n"
                    "3. If the server crashed, check `DBErrors.log` for missing data\n"
                    "4. Try a different character \u2014 the issue might be character-specific\n"
                    "5. If it happens with every character, check your `worldserver.conf` for port conflicts"
                ),
            },
        ],
    },
    "cant_reach": {
        "prompt": "Are you connecting locally or remotely?",
        "options": [
            {
                "label": "Locally (same computer)",
                "emoji": "\U0001f4bb",
                "answer": (
                    "**Local Connection Fix:**\n\n"
                    "1. Make sure **bnetserver** AND **worldserver** are both running\n"
                    "2. Check your `auth.realmlist` table \u2014 address should be `127.0.0.1`\n"
                    "3. Confirm ports aren't blocked by firewall:\n"
                    "   \u2022 `1119` \u2014 BNet authentication\n"
                    "   \u2022 `8085` \u2014 Worldserver\n"
                    "4. Make sure Arctium Launcher is pointed at `127.0.0.1`\n"
                    "5. Check that no other program is using those ports"
                ),
            },
            {
                "label": "Remotely (different computer)",
                "emoji": "\U0001f310",
                "answer": (
                    "**Remote Connection Fix:**\n\n"
                    "1. The host machine needs **port forwarding** on their router for:\n"
                    "   \u2022 `1119` \u2014 BNet authentication\n"
                    "   \u2022 `8085` \u2014 Worldserver\n"
                    "   \u2022 `8086` \u2014 Instance server\n"
                    "2. `auth.realmlist` address must be the **host's public IP** (not 127.0.0.1)\n"
                    "3. Windows Firewall on the host must allow inbound on those ports\n"
                    "4. Arctium Launcher on the client must point to the host's public IP\n"
                    "5. Test with `telnet <host-ip> 1119` to verify the port is reachable"
                ),
            },
        ],
    },
    "db_issues": {
        "prompt": "What kind of database issue are you having?",
        "options": [
            {
                "label": "MySQL won't start",
                "emoji": "\u274c",
                "answer": (
                    "**MySQL Won't Start:**\n\n"
                    "1. Check if another MySQL instance is already running on the same port\n"
                    "2. Open **Services** (services.msc) and look for MySQL\n"
                    "3. If using UniServerZ, launch it as **Administrator**\n"
                    "4. Check the MySQL error log (usually in the `data/` folder)\n"
                    "5. If the data directory is corrupted, you may need to reinitialize:\n"
                    "   `mysqld --initialize-insecure --datadir=<path>`"
                ),
            },
            {
                "label": "SQL errors when applying updates",
                "emoji": "\u26a0\ufe0f",
                "answer": (
                    "**SQL Update Errors:**\n\n"
                    "1. Apply updates **in order** \u2014 the filenames are dated for a reason\n"
                    "2. Don't skip files \u2014 each update may depend on the previous one\n"
                    "3. If you get 'table already exists', you've probably applied it twice\n"
                    "4. If you get 'unknown column', you're missing an earlier update\n"
                    "5. When in doubt, start fresh: drop and recreate the database, then apply all updates from the beginning"
                ),
            },
            {
                "label": "Can't create account",
                "emoji": "\U0001f464",
                "answer": (
                    "**Can't Create Account:**\n\n"
                    "1. In the **bnetserver** console, type:\n"
                    "   `account create <email> <password>`\n"
                    "2. The email format matters \u2014 use something like `test@test.com`\n"
                    "3. Then set the GM level:\n"
                    "   `account set gmlevel <email> 3 -1`\n"
                    "4. If bnetserver isn't running, you can't create accounts \u2014 start it first"
                ),
            },
        ],
    },
    "build_issues": {
        "prompt": "What stage of building are you stuck on?",
        "options": [
            {
                "label": "CMake configuration fails",
                "emoji": "\U0001f4cb",
                "answer": (
                    "**CMake Configuration:**\n\n"
                    "1. Use **Visual Studio 2022** or newer with C++ desktop workload\n"
                    "2. Install **CMake 3.25+** (VS installer or standalone)\n"
                    "3. Open a **Developer Command Prompt** or use CMake presets\n"
                    "4. Common issues:\n"
                    "   \u2022 OpenSSL not found \u2014 install OpenSSL 3.x, set `OPENSSL_ROOT_DIR`\n"
                    "   \u2022 Boost not found \u2014 install via vcpkg or set `BOOST_ROOT`\n"
                    "   \u2022 MySQL not found \u2014 set `MYSQL_INCLUDE_DIR` and `MYSQL_LIBRARY`\n"
                    "5. Run: `cmake -B build -S . -G \"Visual Studio 17 2022\" -A x64`"
                ),
            },
            {
                "label": "Compile errors",
                "emoji": "\u274c",
                "answer": (
                    "**Compile Errors:**\n\n"
                    "1. Make sure you're on the correct branch (usually `master`)\n"
                    "2. Pull the latest: `git pull origin master`\n"
                    "3. Re-run CMake after pulling (reconfigure)\n"
                    "4. OpenSSL link errors: make sure you're using the **MD** (not MT) libraries\n"
                    "5. If you get linker errors about unresolved symbols, clean and rebuild:\n"
                    "   Delete `build/` folder, re-run CMake, then build"
                ),
            },
            {
                "label": "Extractors won't run",
                "emoji": "\U0001f5c2\ufe0f",
                "answer": (
                    "**Extractor Issues:**\n\n"
                    "1. Extractors must be run from your **WoW client directory** (where `WoW.exe` is)\n"
                    "2. Run them in order: `mapextractor` \u2192 `vmapextractor` \u2192 `vmap4assembler` \u2192 `mmaps_generator`\n"
                    "3. Run as **Administrator**\n"
                    "4. If mapextractor crashes, your WoW installation may be corrupted \u2014 repair it through Battle.net\n"
                    "5. mmaps_generator takes a LONG time (hours) \u2014 that's normal"
                ),
            },
        ],
    },
}

# Top-level menu
ROOT_OPTIONS = [
    ("cant_connect", "I can't connect to the server", "\U0001f50c"),
    ("db_issues", "Database / MySQL problems", "\U0001f4be"),
    ("build_issues", "Compiling / building from source", "\U0001f528"),
]


class TreeButton(discord.ui.Button):
    """A button that either shows an answer or drills into a sub-tree."""

    def __init__(self, label: str, emoji: str, tree_key: str | None = None, answer: str | None = None):
        super().__init__(label=label, emoji=emoji, style=discord.ButtonStyle.secondary)
        self.tree_key = tree_key
        self.answer_text = answer

    async def callback(self, interaction: discord.Interaction):
        if self.answer_text:
            icon = em("fix", "\U0001f527")
            embed = discord.Embed(
                title=f"{icon} Troubleshooting",
                description=self.answer_text,
                color=discord.Color.green(),
            )
            embed.set_footer(text="Still stuck? Ask in the support channel and a human will help!")
            await interaction.response.edit_message(embed=embed, view=None)
        elif self.tree_key and self.tree_key in TREES:
            node = TREES[self.tree_key]
            view = TreeView(node)
            icon = em("fix", "\U0001f527")
            embed = discord.Embed(
                title=f"{icon} Troubleshooter",
                description=node["prompt"],
                color=discord.Color.blue(),
            )
            await interaction.response.edit_message(embed=embed, view=view)


class TreeView(discord.ui.View):
    """A view with buttons for a tree node's options."""

    def __init__(self, node: dict):
        super().__init__(timeout=120)
        for opt in node["options"]:
            self.add_item(TreeButton(
                label=opt["label"],
                emoji=opt["emoji"],
                tree_key=opt.get("next_node"),
                answer=opt.get("answer"),
            ))


class RootView(discord.ui.View):
    """Top-level view for the troubleshooter."""

    def __init__(self):
        super().__init__(timeout=120)
        for key, label, emoji_str in ROOT_OPTIONS:
            self.add_item(TreeButton(
                label=label,
                emoji=emoji_str,
                tree_key=key,
            ))


class Troubleshooter(commands.Cog):
    """Interactive guided troubleshooter for common setup problems."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @app_commands.command(name="troubleshoot", description="Interactive guided troubleshooter for common issues")
    async def troubleshoot(self, interaction: discord.Interaction):
        icon = em("fix", "\U0001f527")
        embed = discord.Embed(
            title=f"{icon} Troubleshooter",
            description="What kind of problem are you having?",
            color=discord.Color.blue(),
        )
        embed.set_footer(text="Select an option below to start")
        await interaction.response.send_message(embed=embed, view=RootView(), ephemeral=True)


async def setup(bot: commands.Bot):
    await bot.add_cog(Troubleshooter(bot))

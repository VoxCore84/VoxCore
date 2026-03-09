"""Help command — interactive command tree with category dropdowns."""

import discord
from discord import app_commands
from discord.ext import commands
from emojis import em


# ── Category definitions ────────────────────────────────────────────
# Each tuple: (emoji_name, fallback, label, description, commands_list)
# commands_list entries: (name, description)

CATEGORIES = [
    (
        "lookup", "\U0001f50d", "Lookups",
        "Search the WoW database for spells, items, creatures, and more.",
        [
            ("/spell <query>", "Look up a spell by ID or name"),
            ("/item <query>", "Look up an item by ID or name"),
            ("/creature <query>", "Look up a creature/NPC by ID or name"),
            ("/area <query>", "Look up a zone or area by ID or name"),
            ("/faction <query>", "Look up a faction by ID or name"),
        ],
    ),
    (
        "server", "\u2699\ufe0f", "Server",
        "Check server status, build info, and player counts.",
        [
            ("/server", "Check server status, uptime, and player count"),
            ("/online", "Show current online player count"),
            ("/buildcheck", "Show the latest TrinityCore auth SQL update"),
        ],
    ),
    (
        "bug", "\U0001f41b", "Bug Reports",
        "How the bug triage system works.",
        [
            ("Post in #bug-reports", "Your report is auto-categorized and threaded"),
            ("Duplicate detection", "The bot warns if a similar bug was recently filed"),
            ("Misrouting alerts", "Bug-shaped messages in other channels get a nudge"),
        ],
    ),
    (
        "faq", "\u2753", "FAQ",
        "Automatic answers to common support questions.",
        [
            ("Auto-trigger", "The bot watches support channels for common questions"),
            ("Topics covered", "Connection issues, build mismatches, Arctium, extractors, MySQL, OpenSSL, SQL updates, flying, and more"),
            ("Cooldown", "Same FAQ won't re-trigger in the same channel for 5 minutes"),
        ],
    ),
    (
        "fix", "\U0001f527", "Troubleshooting",
        "Interactive guided troubleshooter for setup problems.",
        [
            ("/troubleshoot", "Step-by-step guided troubleshooter with buttons"),
        ],
    ),
    (
        "watch", "\U0001f441\ufe0f", "Passive Features",
        "Things the bot does automatically in the background.",
        [
            ("Wowhead link resolver", "Post a wowhead.com link and the bot checks if that entity exists in our DB"),
            ("Build watchdog", "Monitors TrinityCore GitHub for new client build updates and announces them"),
            ("Changelog feed", "Posts new TrinityCore commits to announcements (hourly)"),
            ("Welcome DM", "New members get a quick-start checklist via DM"),
        ],
    ),
    (
        "shield", "\U0001f6e1\ufe0f", "Moderation",
        "Auto-mod and server management tools.",
        [
            ("/verifypanel", "Post the verification button panel (admin only)"),
            ("Invite filter", "Auto-deletes Discord invite links from non-mods"),
            ("Spam detection", "Warns users sending too many messages too fast"),
            ("New account alerts", "Flags accounts younger than 7 days in mod-log"),
        ],
    ),
]


class HelpDropdown(discord.ui.Select):
    """Dropdown menu for selecting a help category."""

    def __init__(self):
        options = []
        for emoji_name, fallback, label, description, _ in CATEGORIES:
            options.append(discord.SelectOption(
                label=label,
                description=description[:100],
                value=label,
                emoji=fallback,
            ))
        super().__init__(
            placeholder="Pick a category...",
            min_values=1,
            max_values=1,
            options=options,
        )

    async def callback(self, interaction: discord.Interaction):
        selected = self.values[0]
        for emoji_name, fallback, label, description, cmds in CATEGORIES:
            if label == selected:
                icon = em(emoji_name, fallback)
                lines = []
                for name, desc in cmds:
                    if name.startswith("/"):
                        lines.append(f"{icon} `{name}` — {desc}")
                    else:
                        lines.append(f"{icon} **{name}** — {desc}")

                embed = discord.Embed(
                    title=f"{icon} {label}",
                    description="\n".join(lines),
                    color=discord.Color.blue(),
                )
                embed.set_footer(text="Use /help to see all categories")
                await interaction.response.edit_message(embed=embed, view=self.view)
                return


class HelpView(discord.ui.View):
    """Persistent view with the help dropdown."""

    def __init__(self):
        super().__init__(timeout=120)
        self.add_item(HelpDropdown())


class Help(commands.Cog):
    """Interactive help menu showing all bot commands."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @app_commands.command(name="help", description="Show all DraconicBot commands and features")
    async def help_command(self, interaction: discord.Interaction):
        icon = em("dragon", "\U0001f409")

        # Build overview of all categories
        lines = []
        for emoji_name, fallback, label, description, cmds in CATEGORIES:
            cat_icon = em(emoji_name, fallback)
            cmd_names = [c[0] for c in cmds if c[0].startswith("/")]
            if cmd_names:
                cmd_list = "  ".join(f"`{c}`" for c in cmd_names)
                lines.append(f"{cat_icon} **{label}** — {cmd_list}")
            else:
                lines.append(f"{cat_icon} **{label}** — {description}")

        embed = discord.Embed(
            title=f"{icon} DraconicBot — Command Guide",
            description="\n".join(lines) + "\n\n**Select a category below for details.**",
            color=discord.Color.blue(),
        )
        embed.set_footer(text="DraconicBot \u2022 DraconicWoW support bot")

        await interaction.response.send_message(embed=embed, view=HelpView(), ephemeral=True)


async def setup(bot: commands.Bot):
    await bot.add_cog(Help(bot))

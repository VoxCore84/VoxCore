"""Wowhead link resolver — auto-detects wowhead URLs and shows if the entity exists in the DB."""

import csv
import logging
from pathlib import Path

import discord
import pymysql
from discord.ext import commands

from config import SUPPORT_CHANNEL_IDS, CHANNEL_BUGREPORT, WAGO_CSV_DIR, MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASS
from wowhead import extract_wowhead_links
from emojis import em

log = logging.getLogger(__name__)


def _check_csv(csv_path: Path, id_col: str, name_col: str, entity_id: int) -> tuple[bool, str]:
    """Check if an ID exists in a CSV file. Returns (found, name)."""
    if not csv_path.exists():
        return False, ""
    sid = str(entity_id)
    with open(csv_path, "r", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row.get(id_col) == sid:
                return True, row.get(name_col, "")
    return False, ""


def _check_mysql(table: str, id_col: str, entity_id: int) -> tuple[bool, str]:
    """Check if an ID exists in a MySQL table. Returns (found, name_or_empty)."""
    try:
        conn = pymysql.connect(
            host=MYSQL_HOST, port=MYSQL_PORT,
            user=MYSQL_USER, password=MYSQL_PASS,
            database="world", charset="utf8mb4",
            connect_timeout=5,
        )
        with conn.cursor() as cur:
            cur.execute(f"SELECT name FROM {table} WHERE {id_col} = %s LIMIT 1", (entity_id,))
            row = cur.fetchone()
        conn.close()
        if row:
            return True, row[0]
        return False, ""
    except Exception as e:
        log.warning("MySQL check failed for %s.%s=%d: %s", table, id_col, entity_id, e)
        return False, ""


# Lookup strategy per entity type
ENTITY_CHECKS = {
    "spell": lambda eid: _check_csv(WAGO_CSV_DIR / "SpellName-enUS.csv", "ID", "Name_lang", eid),
    "item": lambda eid: _check_csv(WAGO_CSV_DIR / "ItemSparse-enUS.csv", "ID", "Display_lang", eid),
    "npc": lambda eid: _check_mysql("creature_template", "entry", eid),
    "quest": lambda eid: _check_mysql("quest_template", "ID", eid),
    "object": lambda eid: _check_mysql("gameobject_template", "entry", eid),
}


class WowheadResolver(commands.Cog):
    """Auto-detects wowhead.com links and shows DB status for referenced entities."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot

    @commands.Cog.listener()
    async def on_message(self, message: discord.Message):
        if message.author.bot or not message.guild:
            return

        # Only resolve in support/bug channels
        target_channels = SUPPORT_CHANNEL_IDS | ({CHANNEL_BUGREPORT} if CHANNEL_BUGREPORT else set())
        if message.channel.id not in target_channels:
            return

        links = extract_wowhead_links(message.content)
        if not links:
            return

        # Limit to 5 links per message to avoid spam
        links = links[:5]
        lines = []

        for entity_type, entity_id in links:
            checker = ENTITY_CHECKS.get(entity_type)
            if not checker:
                continue

            found, name = checker(entity_id)
            if found:
                status = f"Found in DB: **{name}**"
                icon = em("found", "\u2705")
            else:
                status = "**Not found** in server database"
                icon = em("missing", "\u274c")

            lines.append(f"{icon} `{entity_type}` **{entity_id}** — {status}")

        if not lines:
            return

        embed = discord.Embed(
            description="\n".join(lines),
            color=discord.Color.blue(),
        )
        embed.set_footer(text=f"{em('watch', '\U0001f441\ufe0f')} Wowhead link check \u2022 {em('found', '\u2705')} = exists in DB, {em('missing', '\u274c')} = missing/not implemented")
        await message.reply(embed=embed, mention_author=False)
        log.info("Resolved %d wowhead links for %s", len(lines), message.author)


async def setup(bot: commands.Bot):
    await bot.add_cog(WowheadResolver(bot))

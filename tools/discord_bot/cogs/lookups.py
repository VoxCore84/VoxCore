"""Slash commands for looking up spells, items, creatures, areas, factions."""

import csv
import logging
from pathlib import Path

import discord
from discord import app_commands
from discord.ext import commands

import pymysql

from config import WAGO_CSV_DIR, MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASS
from emojis import em

log = logging.getLogger(__name__)

MAX_RESULTS = 15


def _search_csv(csv_path: Path, id_col: str, name_col: str, query: str, extra_cols: list[str] | None = None) -> list[dict]:
    """Search a wago CSV by ID (exact) or name (substring)."""
    results = []
    is_id = query.isdigit()
    query_lower = query.lower()

    if not csv_path.exists():
        log.warning("CSV not found: %s", csv_path)
        return []

    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if is_id:
                if row.get(id_col) == query:
                    results.append(row)
                    break  # ID is unique
            else:
                name = row.get(name_col, "")
                if query_lower in name.lower():
                    results.append(row)
                    if len(results) >= MAX_RESULTS:
                        break

    return results


def _format_results(results: list[dict], id_col: str, name_col: str, extra_cols: list[str] | None = None, entity_type: str = "") -> str:
    """Format CSV results into a readable embed description."""
    if not results:
        return "No results found."

    lines = []
    for row in results:
        eid = row.get(id_col, "?")
        name = row.get(name_col, "?")
        line = f"**{eid}** — {name}"
        if extra_cols:
            extras = ", ".join(f"{c}={row.get(c, '?')}" for c in extra_cols)
            line += f" ({extras})"
        if entity_type:
            line += f" [wowhead](https://www.wowhead.com/{entity_type}={eid})"
        lines.append(line)

    text = "\n".join(lines)
    if len(results) >= MAX_RESULTS:
        text += f"\n\n*Showing first {MAX_RESULTS} results — try a more specific search.*"
    return text


class Lookups(commands.Cog):
    """Slash commands for game data lookups."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self._spell_csv = WAGO_CSV_DIR / "SpellName-enUS.csv"
        self._item_csv = WAGO_CSV_DIR / "ItemSparse-enUS.csv"
        self._area_csv = WAGO_CSV_DIR / "AreaTable-enUS.csv"
        self._faction_csv = WAGO_CSV_DIR / "Faction-enUS.csv"
        self._faction_tpl_csv = WAGO_CSV_DIR / "FactionTemplate-enUS.csv"

    @app_commands.command(name="spell", description="Look up a spell by ID or name")
    @app_commands.describe(query="Spell ID or name to search for")
    async def spell_lookup(self, interaction: discord.Interaction, query: str):
        await interaction.response.defer()
        results = _search_csv(self._spell_csv, "ID", "Name_lang", query)
        text = _format_results(results, "ID", "Name_lang", entity_type="spell")
        embed = discord.Embed(title=f"{em('spell', '\u26a1')} Spell Lookup: {query}", description=text, color=discord.Color.purple())
        embed.set_footer(text=f"{em('lookup', '\U0001f50d')} Source: Wago DB2 SpellName")
        await interaction.followup.send(embed=embed)

    @app_commands.command(name="item", description="Look up an item by ID or name")
    @app_commands.describe(query="Item ID or name to search for")
    async def item_lookup(self, interaction: discord.Interaction, query: str):
        await interaction.response.defer()
        results = _search_csv(self._item_csv, "ID", "Display_lang", query, extra_cols=["OverallQualityID"])
        # Map quality IDs to names
        quality_names = {
            "0": "Poor", "1": "Common", "2": "Uncommon", "3": "Rare",
            "4": "Epic", "5": "Legendary", "6": "Artifact", "7": "Heirloom",
        }
        for r in results:
            q = r.get("OverallQualityID", "0")
            r["Quality"] = quality_names.get(q, q)
        text = _format_results(results, "ID", "Display_lang", extra_cols=["Quality"], entity_type="item")
        embed = discord.Embed(title=f"{em('item', '\U0001f6e1\ufe0f')} Item Lookup: {query}", description=text, color=discord.Color.green())
        embed.set_footer(text=f"{em('lookup', '\U0001f50d')} Source: Wago DB2 ItemSparse")
        await interaction.followup.send(embed=embed)

    @app_commands.command(name="creature", description="Look up a creature/NPC by ID or name")
    @app_commands.describe(query="Creature entry ID or name to search for")
    async def creature_lookup(self, interaction: discord.Interaction, query: str):
        await interaction.response.defer()

        try:
            conn = pymysql.connect(
                host=MYSQL_HOST, port=MYSQL_PORT,
                user=MYSQL_USER, password=MYSQL_PASS,
                database="world", charset="utf8mb4",
                connect_timeout=5,
            )
            with conn.cursor(pymysql.cursors.DictCursor) as cur:
                if query.isdigit():
                    cur.execute(
                        "SELECT entry, name, subname, faction, Classification FROM creature_template WHERE entry = %s",
                        (int(query),),
                    )
                else:
                    cur.execute(
                        "SELECT entry, name, subname, faction, Classification FROM creature_template WHERE name LIKE %s LIMIT %s",
                        (f"%{query}%", MAX_RESULTS),
                    )
                rows = cur.fetchall()
            conn.close()
        except Exception as e:
            await interaction.followup.send(embed=discord.Embed(
                title="Creature Lookup Error",
                description=f"Database error: {e}",
                color=discord.Color.red(),
            ))
            return

        if not rows:
            text = "No creatures found."
        else:
            class_names = {"0": "Normal", "1": "Elite", "2": "Rare Elite", "3": "World Boss", "4": "Rare"}
            lines = []
            for r in rows:
                cls = class_names.get(str(r["Classification"]), str(r["Classification"]))
                sub = f" <{r['subname']}>" if r.get("subname") else ""
                lines.append(f"**{r['entry']}** — {r['name']}{sub} ({cls}) [wowhead](https://www.wowhead.com/npc={r['entry']})")
            text = "\n".join(lines)
            if len(rows) >= MAX_RESULTS:
                text += f"\n\n*Showing first {MAX_RESULTS} results.*"

        embed = discord.Embed(title=f"{em('dragon', '\U0001f409')} Creature Lookup: {query}", description=text, color=discord.Color.orange())
        embed.set_footer(text=f"{em('lookup', '\U0001f50d')} Source: world.creature_template")
        await interaction.followup.send(embed=embed)

    @app_commands.command(name="area", description="Look up a zone/area by ID or name")
    @app_commands.describe(query="Area ID or name to search for")
    async def area_lookup(self, interaction: discord.Interaction, query: str):
        await interaction.response.defer()

        continent_names = {
            "0": "Eastern Kingdoms", "1": "Kalimdor", "530": "Outland",
            "571": "Northrend", "860": "Pandaria", "1116": "Draenor",
            "1220": "Broken Isles", "1643": "Kul Tiras", "1669": "Zandalar",
            "2222": "Shadowlands", "2444": "Dragon Isles", "2552": "Khaz Algar",
        }

        results = _search_csv(self._area_csv, "ID", "AreaName_lang", query, extra_cols=["ContinentID"])
        for r in results:
            cid = r.get("ContinentID", "")
            r["Continent"] = continent_names.get(cid, f"Map {cid}")

        text = _format_results(results, "ID", "AreaName_lang", extra_cols=["Continent"])
        embed = discord.Embed(title=f"{em('cat_zones', '\U0001f5fa\ufe0f')} Area Lookup: {query}", description=text, color=discord.Color.teal())
        embed.set_footer(text=f"{em('lookup', '\U0001f50d')} Source: Wago DB2 AreaTable")
        await interaction.followup.send(embed=embed)

    @app_commands.command(name="faction", description="Look up a faction by ID or name")
    @app_commands.describe(query="Faction ID or name to search for")
    async def faction_lookup(self, interaction: discord.Interaction, query: str):
        await interaction.response.defer()

        # Load faction name mapping
        faction_names: dict[str, str] = {}
        if self._faction_csv.exists():
            with open(self._faction_csv, "r", encoding="utf-8") as f:
                for row in csv.DictReader(f):
                    faction_names[row.get("ID", "")] = row.get("Name_lang", "")

        # Search FactionTemplate
        results = _search_csv(self._faction_tpl_csv, "ID", "Faction", query)
        if not results and not query.isdigit():
            # Name search: search by faction name instead
            matching_fids = {fid for fid, name in faction_names.items() if query.lower() in name.lower()}
            if matching_fids:
                all_rows = _search_csv(self._faction_tpl_csv, "ID", "Faction", "---never---")  # won't match
                # Manual search through the file
                with open(self._faction_tpl_csv, "r", encoding="utf-8") as f:
                    for row in csv.DictReader(f):
                        if row.get("Faction", "") in matching_fids:
                            results.append(row)
                            if len(results) >= MAX_RESULTS:
                                break

        # Enrich with names
        group_names = {
            "0": "Neutral", "1": "Player", "2": "Alliance", "3": "Player+Alliance",
            "4": "Horde", "5": "Player+Horde", "6": "Alliance+Horde", "7": "All",
        }
        lines = []
        for r in results:
            fid = r.get("Faction", "?")
            fname = faction_names.get(fid, "Unknown")
            fg = group_names.get(r.get("FactionGroup", ""), r.get("FactionGroup", "?"))
            lines.append(f"**{r.get('ID', '?')}** — {fname} (Faction {fid}, Group: {fg})")

        text = "\n".join(lines) if lines else "No factions found."
        if len(results) >= MAX_RESULTS:
            text += f"\n\n*Showing first {MAX_RESULTS} results.*"

        embed = discord.Embed(title=f"{em('cat_factions', '\u2694\ufe0f')} Faction Lookup: {query}", description=text, color=discord.Color.gold())
        embed.set_footer(text=f"{em('lookup', '\U0001f50d')} Source: Wago DB2 FactionTemplate + Faction")
        await interaction.followup.send(embed=embed)


async def setup(bot: commands.Bot):
    await bot.add_cog(Lookups(bot))

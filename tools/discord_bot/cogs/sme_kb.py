import json
from pathlib import Path

import discord
from discord.ext import commands
from discord import app_commands

_DATA_DIR = Path(__file__).parent.parent / "data"


class SMEKnowledgeBase(commands.Cog):
    def __init__(self, bot):
        self.bot = bot
        self.db_path = _DATA_DIR / "gm_commands.json"
        self.kb = self._load_kb()

    def _load_kb(self):
        if not self.db_path.exists():
            return []
        with open(self.db_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            return data.get("gm_commands", [])

    @app_commands.command(name="gmcommand", description="Ask DraconicBot what a GM command does!")
    @app_commands.describe(query="The command name (e.g. '.additem' or 'teleport')")
    async def gm_command(self, interaction: discord.Interaction, query: str):
        """Searches the SME KB for a matching GM command."""
        
        query_word = query.lower().strip()
        if not query_word.startswith('.'):
            # Try to match words too
            pass
            
        matches = []
        for cmd in self.kb:
            if query_word in cmd['name'].lower() or query_word in cmd['description'].lower():
                matches.append(cmd)
                
        if not matches:
            await interaction.response.send_message(
                f"❌ I don't know any GM command matching `{query}`.", 
                ephemeral=True
            )
            return
            
        # Take best match (or first 3)
        embed = discord.Embed(
            title="📚 SME Knowledge Base: GM Commands",
            color=discord.Color.gold()
        )
        
        for i, cmd in enumerate(matches[:3]):
            embed.add_field(
                name=cmd['name'],
                value=f"**Syntax:** `{cmd.get('syntax', cmd['name'])}`\n**Description:** {cmd['description']}",
                inline=False
            )
            
        if len(matches) > 3:
            embed.set_footer(text=f"Found {len(matches) - 3} more matches. Try being more specific.")
            
        await interaction.response.send_message(embed=embed)

async def setup(bot):
    await bot.add_cog(SMEKnowledgeBase(bot))

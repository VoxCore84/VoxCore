"""Bug report triage — auto-categorize, create threads, detect misrouting and duplicates."""

import re
import time
import logging
from collections import deque

import discord
from discord.ext import commands

from config import CHANNEL_BUGREPORT, CHANNEL_TROUBLESHOOTING, CHANNEL_TWW
from emojis import em

log = logging.getLogger(__name__)

# Category patterns (from Discord analysis of 30K messages)
CATEGORIES = [
    ("Quest Bug", re.compile(
        r"quest\s*(?:(?:not|doesn.?t|can.?t|won.?t)\s*(?:work|complet|start|finish|turn|accept|show|update|progress)|bug|broken|stuck|issue|missing)",
        re.I)),
    ("Missing NPC", re.compile(
        r"(?:npc|creature|mob|vendor|trainer|flightmaster)\s*(?:not\s*(?:spawn|there|exist|show|appear|found)|missing|gone|disappear)|missing\s*(?:npc|creature|mob|vendor)",
        re.I)),
    ("Spell / Ability Bug", re.compile(
        r"(?:spell|ability|talent|skill|aura|buff|proc)\s*(?:not\s*(?:work|cast|function|apply|show|learn)|broken|bug|issue|wrong)|can.?t\s*(?:cast|use|learn)\s*(?:spell|ability)",
        re.I)),
    ("Transmog / Appearance", re.compile(
        r"transmog|transmogrif|wardrobe\s*(?:not|broken|bug|empty|missing)|appearance\s*(?:not|broken|bug|wrong)",
        re.I)),
    ("Mount / Flying", re.compile(
        r"(?:mount|flying|fly|dragonriding|skyriding)\s*(?:not\s*(?:work|function)|broken|bug|issue|can.?t)|can.?t\s*(?:fly|mount|ride)",
        re.I)),
    ("Item / Loot", re.compile(
        r"(?:item|loot|drop|gear)\s*(?:not\s*(?:work|drop|show|equip)|broken|bug|missing|wrong)|missing\s*(?:item|loot|drop)",
        re.I)),
    ("Server Crash", re.compile(
        r"(?:server|worldserver)\s*(?:crash|segfault|assertion|abort|died|stopped)|crash(?:es|ed|ing)|access\s*violation|stack\s*trace",
        re.I)),
    ("Teleport / Phasing", re.compile(
        r"(?:portal|teleport|phase|phasing)\s*(?:not\s*(?:work|function|teleport)|broken|bug|stuck|wrong)|stuck\s*(?:in|at)\s*(?:loading|phase|portal)|wrong\s*phase",
        re.I)),
    ("Gameobject / Interaction", re.compile(
        r"(?:gameobject|chest|node|herb|ore|door)\s*(?:not\s*(?:work|interact|click|open)|broken|missing)|can.?t\s*(?:interact|click|open|loot|gather)",
        re.I)),
    ("Creature AI / Pathing", re.compile(
        r"(?:creature|mob|boss)\s*(?:ai|combat|aggro|evade|path|movement)\s*(?:not|broken|bug|wrong)|evade\s*(?:bug|issue|mode|loop)",
        re.I)),
    ("Instance / Dungeon", re.compile(
        r"(?:instance|dungeon|raid)\s*(?:not\s*(?:work|enter|load|teleport)|broken|bug|crash|stuck)|can.?t\s*(?:enter|queue)\s*(?:instance|dungeon|raid)",
        re.I)),
]

# Bug-shaped messages (for misrouting detection)
BUG_INDICATORS = re.compile(
    r"(?:bug|broken|not\s+work|doesn.?t\s+work|crash|missing\s+(?:npc|quest|item|spell))",
    re.I,
)

# Wowhead URL pattern (bugs often include these)
WOWHEAD_RE = re.compile(r"wowhead\.com/(?:quest|npc|item|spell|object)=\d+", re.I)


class BugTriage(commands.Cog):
    """Auto-categorizes bug reports, creates threads, detects misrouting."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        # Recent bug summaries for duplicate detection (channel_id → deque of (timestamp, keywords, jump_url))
        self._recent_bugs: dict[int, deque] = {}
        self._max_recent = 50

    def _categorize(self, content: str) -> str | None:
        for name, pattern in CATEGORIES:
            if pattern.search(content):
                return name
        return None

    def _extract_keywords(self, content: str) -> set[str]:
        """Extract significant keywords for duplicate matching."""
        # Remove URLs, mentions, emojis
        clean = re.sub(r"https?://\S+", "", content)
        clean = re.sub(r"<[@#!&]\d+>", "", clean)
        words = set(re.findall(r"\b[a-zA-Z]{4,}\b", clean.lower()))
        # Remove common stop words
        stop = {"this", "that", "with", "from", "have", "been", "does", "doesn", "work",
                "when", "after", "before", "just", "also", "still", "about", "some", "like",
                "tried", "trying", "anyone", "know", "help", "please", "thanks", "would",
                "could", "should", "here", "there", "where", "what", "which", "they", "them",
                "your", "their", "into", "very", "much", "even", "only"}
        return words - stop

    def _find_duplicate(self, channel_id: int, keywords: set[str]) -> str | None:
        """Check if a similar bug was recently reported. Returns jump_url if duplicate found."""
        recent = self._recent_bugs.get(channel_id)
        if not recent or not keywords:
            return None

        now = time.time()
        for ts, prev_kw, url in recent:
            if now - ts > 86400:  # Only check last 24 hours
                continue
            overlap = keywords & prev_kw
            if len(overlap) >= max(3, len(keywords) * 0.4):
                return url
        return None

    def _record_bug(self, channel_id: int, keywords: set[str], jump_url: str):
        if channel_id not in self._recent_bugs:
            self._recent_bugs[channel_id] = deque(maxlen=self._max_recent)
        self._recent_bugs[channel_id].append((time.time(), keywords, jump_url))

    @commands.Cog.listener()
    async def on_message(self, message: discord.Message):
        if message.author.bot or not message.guild:
            return

        content = message.content
        if len(content) < 15:
            return

        # --- Bug report channel: categorize + thread + duplicate check ---
        if message.channel.id == CHANNEL_BUGREPORT:
            category = self._categorize(content)
            keywords = self._extract_keywords(content)

            # Duplicate check
            dup_url = self._find_duplicate(message.channel.id, keywords)
            if dup_url:
                embed = discord.Embed(
                    description=f"{em('target', '\U0001f3af')} This looks similar to a recent report: [jump to message]({dup_url})\nIs this the same issue?",
                    color=discord.Color.yellow(),
                )
                embed.set_footer(text=f"{em('target', '\U0001f3af')} Duplicate detection \u2022 Ignore if this is a different bug")
                await message.reply(embed=embed, mention_author=False)

            # Create thread for the bug
            thread_name = category or "Bug Report"
            # Use first ~60 chars of the message as thread name
            snippet = content[:60].replace("\n", " ").strip()
            if len(content) > 60:
                snippet += "..."
            thread_name = f"[{thread_name}] {snippet}"

            try:
                thread = await message.create_thread(name=thread_name[:100])
                tag_text = f"{em('bug', '\U0001f41b')} **Category:** {category}" if category else f"{em('faq', '\u2753')} Could not auto-categorize this report."
                await thread.send(tag_text + "\n\n*Discuss this bug in this thread. Staff will review it.*")
                log.info("Created bug thread: %s", thread_name)
            except discord.Forbidden:
                log.warning("Missing permissions to create threads in #bugreport")
            except discord.HTTPException as e:
                log.warning("Failed to create thread: %s", e)

            self._record_bug(message.channel.id, keywords, message.jump_url)
            return

        # --- Misrouting detection: bug-shaped messages in #troubleshooting ---
        if message.channel.id in (CHANNEL_TROUBLESHOOTING, CHANNEL_TWW):
            if BUG_INDICATORS.search(content) and WOWHEAD_RE.search(content):
                # Has both a bug indicator AND a wowhead link — likely a bug report
                if CHANNEL_BUGREPORT:
                    embed = discord.Embed(
                        description=f"{em('bug', '\U0001f41b')} This looks like a bug report! Consider posting it in <#{CHANNEL_BUGREPORT}> so it gets tracked and doesn't get lost in the chat.",
                        color=discord.Color.light_grey(),
                    )
                    embed.set_footer(text=f"{em('guide', '\U0001f4d6')} Channel suggestion \u2022 Ignore if this is just a question")
                    await message.reply(embed=embed, mention_author=False)


async def setup(bot: commands.Bot):
    await bot.add_cog(BugTriage(bot))

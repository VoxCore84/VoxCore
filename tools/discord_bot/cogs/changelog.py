"""Changelog feed — monitors TrinityCore GitHub for new commits and posts summaries."""

import logging
from pathlib import Path

import aiohttp
import discord
from discord.ext import commands, tasks

from config import GITHUB_REPO, GITHUB_TOKEN, CHANNEL_ANNOUNCEMENTS
from emojis import em

log = logging.getLogger(__name__)

_STATE_FILE = Path(__file__).parent.parent / "data" / ".last_known_commit"
_API_URL = f"https://api.github.com/repos/{GITHUB_REPO}/commits"
_CHECK_INTERVAL = 3600  # 1 hour


def _read_last_sha() -> str:
    try:
        return _STATE_FILE.read_text().strip()
    except Exception:
        return ""


def _write_last_sha(sha: str):
    _STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    _STATE_FILE.write_text(sha)


class ChangelogFeed(commands.Cog):
    """Posts TrinityCore commit summaries to the announcements channel."""

    def __init__(self, bot: commands.Bot):
        self.bot = bot
        self.last_sha = _read_last_sha()

    async def cog_load(self):
        self.check_commits.start()

    async def cog_unload(self):
        self.check_commits.cancel()

    @tasks.loop(seconds=_CHECK_INTERVAL)
    async def check_commits(self):
        headers = {"Accept": "application/vnd.github+json"}
        if GITHUB_TOKEN:
            headers["Authorization"] = f"Bearer {GITHUB_TOKEN}"

        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(_API_URL, headers=headers, params={"per_page": 10}) as resp:
                    if resp.status != 200:
                        log.warning("GitHub API returned %d", resp.status)
                        return
                    commits = await resp.json()
        except Exception:
            log.exception("Failed to fetch GitHub commits")
            return

        if not commits:
            return

        latest_sha = commits[0]["sha"]

        # First run — just record the latest without announcing
        if not self.last_sha:
            self.last_sha = latest_sha
            _write_last_sha(latest_sha)
            return

        if latest_sha == self.last_sha:
            return

        # Collect new commits (up to 10)
        new_commits = []
        for c in commits:
            if c["sha"] == self.last_sha:
                break
            new_commits.append(c)

        if not new_commits:
            self.last_sha = latest_sha
            _write_last_sha(latest_sha)
            return

        # Announce
        if CHANNEL_ANNOUNCEMENTS:
            await self._post_changelog(new_commits)

        self.last_sha = latest_sha
        _write_last_sha(latest_sha)

    @check_commits.before_loop
    async def before_check(self):
        await self.bot.wait_until_ready()

    async def _post_changelog(self, commits: list[dict]):
        channel = self.bot.get_channel(CHANNEL_ANNOUNCEMENTS)
        if not channel:
            return

        lines = []
        for c in commits[:10]:
            msg = c["commit"]["message"].split("\n")[0][:80]
            sha_short = c["sha"][:7]
            url = c["html_url"]
            author = c["commit"]["author"]["name"]
            lines.append(f"\u2022 [`{sha_short}`]({url}) {msg} \u2014 {author}")

        icon = em("build_alert", "\U0001f6a8")
        count = len(commits)
        s = "s" if count != 1 else ""
        embed = discord.Embed(
            title=f"{icon} {count} new TrinityCore commit{s}",
            description="\n".join(lines),
            color=discord.Color.orange(),
        )
        embed.set_footer(text=f"github.com/{GITHUB_REPO} \u2022 Checked hourly")
        await channel.send(embed=embed)
        log.info("Posted %d new commits to announcements", count)


async def setup(bot: commands.Bot):
    await bot.add_cog(ChangelogFeed(bot))

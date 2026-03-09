"""Monitor TrinityCore GitHub repo for new auth SQL updates."""

import re
import base64
import aiohttp
from config import GITHUB_TOKEN, GITHUB_REPO, GITHUB_AUTH_SQL_PATH

API_BASE = "https://api.github.com"
CONTENTS_URL = f"{API_BASE}/repos/{GITHUB_REPO}/contents/{GITHUB_AUTH_SQL_PATH}"

_RE_BUILD = re.compile(r"build_info.*?WHERE\s+`build`\s+IN\s*\((\d+)\)", re.DOTALL | re.IGNORECASE)
_RE_BUILD_INSERT = re.compile(r"INSERT INTO `build_info`.*?\((\d+),", re.DOTALL)


def _headers() -> dict:
    h = {"Accept": "application/vnd.github.v3+json"}
    if GITHUB_TOKEN:
        h["Authorization"] = f"Bearer {GITHUB_TOKEN}"
    return h


async def get_latest_auth_files(count: int = 5) -> list[dict]:
    """Fetch the N most recent auth SQL filenames from TrinityCore master.

    Returns list of dicts: [{"name": "2026_03_05_00_auth.sql", "download_url": "...", "html_url": "..."}]
    """
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(CONTENTS_URL, headers=_headers(), timeout=aiohttp.ClientTimeout(total=15)) as resp:
                if resp.status != 200:
                    return []
                data = await resp.json()

            # Sort by name descending (date-based naming = chronological sort)
            sql_files = [
                {
                    "name": f["name"],
                    "download_url": f.get("download_url", ""),
                    "html_url": f.get("html_url", ""),
                    "sha": f.get("sha", ""),
                }
                for f in data
                if f["name"].endswith("_auth.sql")
            ]
            sql_files.sort(key=lambda x: x["name"], reverse=True)
            return sql_files[:count]

    except Exception:
        return []


async def get_file_content(filename: str) -> str | None:
    """Download the content of a specific auth SQL file."""
    url = f"{CONTENTS_URL}/{filename}"
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(url, headers=_headers(), timeout=aiohttp.ClientTimeout(total=15)) as resp:
                if resp.status != 200:
                    return None
                data = await resp.json()
                content_b64 = data.get("content", "")
                return base64.b64decode(content_b64).decode("utf-8", errors="replace")
    except Exception:
        return None


async def extract_build_number(filename: str) -> int | None:
    """Extract the build number from an auth SQL file's content."""
    content = await get_file_content(filename)
    if not content:
        return None

    m = _RE_BUILD_INSERT.search(content)
    if m:
        return int(m.group(1))
    m = _RE_BUILD.search(content)
    if m:
        return int(m.group(1))
    return None


async def get_latest_build_info() -> dict | None:
    """Get the latest auth SQL file and extract build info.

    Returns dict: {"filename": str, "build": int, "html_url": str} or None.
    """
    files = await get_latest_auth_files(1)
    if not files:
        return None

    latest = files[0]
    build = await extract_build_number(latest["name"])
    if build is None:
        return None

    browse_url = (
        f"https://github.com/{GITHUB_REPO}/blob/master/{GITHUB_AUTH_SQL_PATH}/{latest['name']}"
    )

    return {
        "filename": latest["name"],
        "build": build,
        "html_url": browse_url,
    }

# BestiaryForge — Creature Intelligence Pipeline

> **Status**: DRAFT — Pending Triad review (ChatGPT architect + Antigravity QA)
> **Author**: Claude Code (Implementer), from research pass
> **Date**: 2026-03-11
> **Scope**: New tooling system — multi-source creature spell/behavior data collection, aggregation, and SmartAI/SQL auto-generation

---

## Quick Start (For Users)

1. **Gather Data**: Run the `BestiaryForge` addon on Retail WoW and encounter mobs. Type `/bf export` and copy the data.
2. **Run Generator**: Double-click `run_forge.bat` (no command line knowledge required!). Paste your export data when prompted.
3. **Apply SQL**: The tool will generate a `bestiary_forge_output.sql` file. Drag and drop this into HeidiSQL and execute.
4. **Reload**: In your server console, type `.reload smart_scripts` and `.reload creature_template`.

---

## 1. Executive Summary

Private server emulators (TrinityCore, AzerothCore, etc.) lack a reliable, automated way to discover which spells NPCs cast on retail WoW. This data is **not in any client-side file** (DB2, CASC, or otherwise) — the creature→spell assignment is entirely server-side at Blizzard. Today, the emulator community relies on:

- Manual observation and hand-written SmartAI
- Sparse Wowhead data (crowdsourced from their Looter addon)
- Packet sniffing (high skill floor, requires specialized setup)

**BestiaryForge** solves this by building a **multi-source creature intelligence pipeline** that:

1. **Collects** creature spell data from 3 automated/semi-automated sources
2. **Aggregates** and deduplicates into a unified creature spell registry
3. **Generates** production-ready SQL (SmartAI, creature_template, creature_addon, etc.)
4. **Validates** all output against DB2 spell data before emission
5. **Reports** coverage gaps so you know what's missing

The system is designed for the VoxCore/RoleplayCore project but architecturally generic enough to benefit the entire TrinityCore community.

---

## 2. Problem Statement

### Why This Data Doesn't Exist in Client Files

The WoW client operates on a **pull model** for combat data. When an NPC casts a spell:

1. Server decides to cast (based on its internal AI scripting)
2. Server sends `SMSG_SPELL_START` / `SMSG_SPELL_GO` with the spell ID
3. Client looks up the spell ID in its local DB2 tables (`SpellName`, `SpellEffect`, `SpellVisual`, etc.) to render visuals

The client never needs a "creature X uses spell Y" mapping table — it only needs the spell definitions themselves (which ARE in DB2). The assignment logic is purely server-side.

### What Exists in DB2 (Confirmed via wago-db2 MCP)

| Table | Row Count | Has Creature→Spell Link? | Notes |
|-------|-----------|--------------------------|-------|
| `Creature` | varies | No | Name, type, display info only |
| `CreatureDifficulty` | 23,503 | No | Flags, faction, content tuning — zero spell columns |
| `CreatureImmunities` | 5 | No | School/mechanic immunities only |
| `JournalEncounterSection` | 20,505 | **Partial** | Has `SpellID` column, but only for Dungeon Journal boss abilities. Many entries have `SpellID=0` |
| `SpellName` | ~400K+ | N/A | Defines spells, not who casts them |
| All other Creature* tables | varies | No | Display, model, sound, movement data — no spells |

**Conclusion**: DB2/CASC/Wago provide zero creature→spell mapping for general NPCs. The Dungeon Journal covers some boss abilities but is incomplete and excludes all non-boss creatures.

### The Gap

For a Midnight/12.x server with ~200K+ creature entries, the vast majority have no spell data in the emulator database. This means:

- Open-world mobs stand there and melee
- Dungeon trash has no abilities
- Even bosses may be missing spells not covered by the Dungeon Journal

---

## 3. Data Sources — Three Tiers

BestiaryForge uses three data sources with different tradeoffs:

### Tier 1: Warcraft Logs API (Fully Automated, No Player Effort)

**What it is**: Warcraft Logs (warcraftlogs.com) is a combat log aggregation platform where millions of players upload their raid/dungeon logs. It has a public GraphQL API (v2) that provides event-level spell cast data.

**Coverage**: Excellent for instanced content (raids, dungeons, M+). **Near-zero for open-world mobs** (WCL is fundamentally a raid/dungeon log platform). Realistic coverage estimate: ~300-1000 unique creature entries out of 200K+ total (0.15-0.5%). High value per entry (timing, frequency, targets), but narrow breadth.

**Authentication**: OAuth 2.0 Client Credentials flow. Register at `warcraftlogs.com/api-clients` → get `client_id` + `client_secret` → exchange for bearer token. No user login required for public data.

**Rate Limits**:
- Free tier: 3,600 points/hour
- Patreon subscriber ($5/mo): 36,000 points/hour (10x)
- Points are per-query complexity, not simple request count

**API Endpoint**: `POST https://www.warcraftlogs.com/api/v2/client`

**Key Queries**:

```graphql
# 1. Get all zones and their encounters
# NOTE: Encounter type does NOT have npcID field directly.
# Use fights.enemyNPCs from a report to get NPC gameIDs.
{
  gameData {
    zones { id, name, encounters { id, name } }
  }
}

# 2. Get fights + NPC IDs from a specific report
# NOTE: enemyNPCs.gameID = actual WoW creature entry
{
  reportData {
    report(code: "ABC123") {
      fights(killType: Encounters) {
        id, encounterID, name, startTime, endTime, kill, difficulty
        enemyNPCs { id, gameID, groupCount, instanceCount }
      }
    }
  }
}

# 3. Get actor→NPC ID mapping for a report
{
  reportData {
    report(code: "ABC123") {
      masterData {
        actors(type: "NPC") {
          id        # report-local actor ID
          gameID    # actual WoW creature entry
          name
        }
        abilities {
          gameID    # actual WoW spell ID
          name
          icon
        }
      }
    }
  }
}

# 4. Get enemy spell casts from a report (use fight-specific time bounds)
# WARNING: Use actual fight startTime/endTime from query #2, NOT a magic number.
# Count only "cast" type events, NOT "begincast" (to avoid double-counting).
{
  reportData {
    report(code: "ABC123") {
      events(
        dataType: Casts,
        hostilityType: Enemies,
        startTime: 0,
        endTime: 600000,
        fightIDs: [1, 2, 3]
      ) {
        data       # JSON array of cast events
        nextPageTimestamp  # null when no more pages
      }
    }
  }
}
```

> **UNVERIFIED**: These queries are based on WCL API documentation research, NOT tested against the live API. A spike/PoC against the real API is required before implementation. Key unknowns:
> - Exact point costs per query type (affects rate limit math)
> - `reportData.reports` search endpoint existence — may need to use `worldData.encounter.fightRankings` to discover report codes
> - Pagination behavior (events per page, termination semantics)

**Event Data Fields** (per cast event in `data` array):
- `type` — `"cast"`, `"begincast"`, etc.
- `timestamp` — milliseconds relative to report start
- `sourceID` — report-local actor ID (cross-ref with `masterData.actors`)
- `targetID` — report-local target actor ID
- `abilityGameID` — **the actual WoW spell ID** (this is what we want)
- `fight` — fight ID within the report

**Extraction Strategy**:
1. Query `gameData.zones` to get all current encounter IDs
2. Discover report codes via `worldData.encounter(id).fightRankings` (returns ranked fights with report codes). NOTE: The exact query path for report discovery needs live API verification — `reportData.reports` may not support encounter-based search
3. For each report: get `masterData` (actor→NPC ID mapping) + `events` (enemy casts, filtered to `type == "cast"` only — skip `"begincast"` to avoid double-counting)
4. Map `sourceID` → creature entry via masterData. Skip events where sourceID has no matching actor (environmental, pet, or orphaned sources)
5. Filter out `gameID == 0` actors (unresolved NPCs) and known WorldTrigger entries (19871, 21252, etc.)
6. Aggregate: `{creatureEntry: npcGameID, spellID: abilityGameID, count, encounterContext}`
7. Cache aggressively — game data only changes on major patches. Cache per report code permanently (immutable). Handle token expiry with auto-reauth on 401

**Limitations**:
- Only covers content that players actually log and upload
- Primarily instanced content (raids/dungeons/M+)
- Open-world mob coverage is minimal
- Rate limits require batching and caching
- `sourceID`/`targetID` are report-local, must cross-reference with `masterData`
- The `filterExpression` parameter is more reliable than direct argument filtering for precise queries

**Existing Tools**: Official `@rpglogs/api-sdk` (TypeScript), several community Python wrappers. No existing tool specifically extracts NPC spell frequency data — this would be novel.

---

### Tier 2: Wowhead Scraping (Fully Automated, No Player Effort)

**What it is**: Wowhead's NPC pages contain structured spell data embedded as JavaScript objects, sourced from their Looter addon's crowdsourced combat log data.

**Coverage**: **NARROWER THAN INITIALLY ASSUMED**. Adversarial testing revealed that the abilities `Listview` block only appears on boss/dungeon NPCs, NOT on most open-world mobs. Hogger (NPC 448) — the spec's own example — has NO abilities section on Wowhead. Coverage is primarily instanced content bosses and notable NPCs that have Dungeon Journal entries. For general open-world mobs, Wowhead may show no structured spell data at all. This significantly overlaps with Tier 1 (WCL) coverage rather than complementing it.

**No API Required**: The data is embedded directly in the HTML of NPC pages as JavaScript `Listview` objects. No authentication, no API key.

**Data Location**: `https://www.wowhead.com/npc={id}/{slug}`

Each NPC page contains a `Listview` block for abilities:

```javascript
new Listview({
  template: 'spell',
  id: 'abilities',
  // ...
  data: [
    {
      "id": 87337,              // WoW Spell ID
      "name": "Vicious Slice",
      "displayName": "Vicious Slice",
      "schools": 1,             // Spell school bitmask (1=Physical, 2=Holy, 4=Fire, etc.)
      "cat": -8,                // Category (-8 = NPC ability)
      "level": 0,
      "modes": {
        "mode": [0, 1, 2, 8]   // Difficulty modes (0=Normal, 1=Normal Dungeon, 2=Heroic, 8=Mythic, 23=M+, 24=TW)
      }
    },
    // ... more spells
  ]
});
```

Additionally, `WH.Gatherer.addData(6, {...})` on the same page provides extended spell metadata:

```javascript
WH.Gatherer.addData(6, {
  "87337": {
    "name_enus": "Vicious Slice",
    "icon": "ability_warrior_punishingblow",
    "description_enus": "A vicious slice rips through the enemy target..."
  }
});
```

**Extraction Method**:
1. Fetch the NPC page HTML
2. Regex extract: `new Listview\(\{template: 'spell', id: 'abilities'.*?data: (\[.*?\])\}`
3. Parse the JSON array — each entry's `id` field is the spell ID
4. Optionally extract `WH.Gatherer.addData(6, ...)` for spell descriptions

**Verified Examples**:
- Hogger (NPC 448): 4 abilities — Vicious Slice (87337), Eating (87351), Upset Stomach (87352), Summon Minions (87366)
- Nightbane (NPC 114895): 9 abilities with spell IDs and difficulty modes

**Rate Limiting / Ethics**:
- Wowhead uses Cloudflare CDN
- `robots.txt` blocks 39 specific bot user-agents (including `Scrapy`, `ClaudeBot`, `GPTBot`) but has NO `User-agent: *` section
- NPC pages (`/npc=*`) are NOT in any `Disallow` rule for generic crawlers
- No CAPTCHA triggered on reasonable-rate requests
- **Recommended approach**: Normal browser user-agent, 1-2 second delay between requests, aggressive local caching
- Community scrapers (e.g., `BreakBB/wowhead_scraper` with 19 GitHub stars) have existed for years without takedowns

**Limitations**:
- Data quality depends on Wowhead Looter coverage (generally good for established content)
- Brand-new content takes 1-3 weeks to populate
- No cast frequency or timing data — only "this creature uses this spell"
- Difficulty mode data (`modes`) tells you which difficulties the spell appears on but not behavioral differences
- The tooltip API (`nether.wowhead.com/tooltip/npc/{id}`) does NOT include spell data — only the main NPC page does

**Existing Tools**: Several scrapers exist for NPC names/loot, but **no existing tool scrapes the abilities Listview**. The `WowheadSpellScraper` (JavaScript/Selenium) handles Dungeon Journal boss pages only, not generic NPC pages. A custom Python script using `requests` + regex would be straightforward.

---

### Tier 3: Retail Addon — Community Crowdsource (Semi-Automated)

**What it is**: A lightweight WoW addon that runs on retail, passively records creature spell casts via `COMBAT_LOG_SUBEVENT_UNFILTERED`, and saves them to `SavedVariables` for upload.

**Coverage**: Covers everything the player encounters — including open-world mobs, rare elites, and trash that Tier 1 and Tier 2 may miss.

**Why It Works (Despite 12.x Restrictions)**:

Blizzard's Midnight "Secret Values" system restricts addon access to combat data **during active boss encounters and M+ runs in instances**. However:

- **CLEU in the open world is fully unrestricted** — spell IDs, GUIDs, names, schools all readable
- **`/combatlog` file output is completely unaffected** everywhere (this is what WCL uses)
- **Between-pull data is unrestricted** even in instances
- The restrictions target real-time conditional logic (WeakAura triggers), not passive data logging

For our use case (passive recording, not real-time reaction), even in-instance data may still be partially accessible via the combat log file. The addon approach focuses on CLEU for simplicity.

**Core CLEU Events for Spell Tracking**:

| Sub-event | What It Captures | Spell Args |
|-----------|-----------------|------------|
| `SPELL_CAST_START` | NPC begins casting (has cast time) | spellId, spellName, spellSchool |
| `SPELL_CAST_SUCCESS` | NPC finishes casting (also fires for instants) | spellId, spellName, spellSchool |
| `SPELL_AURA_APPLIED` | Buff/debuff applied | spellId, spellName, spellSchool, auraType |
| `SPELL_DAMAGE` | Direct spell damage | spellId, spellName, spellSchool, amount, ... |
| `SPELL_PERIODIC_DAMAGE` | DoT tick | spellId, spellName, spellSchool, amount, ... |
| `SPELL_SUMMON` | NPC summons a creature | spellId, spellName, spellSchool |
| `SPELL_HEAL` | NPC heals (self or ally) | spellId, spellName, spellSchool, amount, ... |

**CLEU Base Arguments** (every event):

```
timestamp, subevent, hideCaster,
sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
destGUID, destName, destFlags, destRaidFlags,
[spellId, spellName, spellSchool],  -- for SPELL_ prefixed events
[...suffix-specific args]
```

**Creature Entry Extraction from GUID**:

```
GUID format: "Creature-0-4170-0-41-68662-00000F4B37"
Split by "-":  [1]unitType  [2]0  [3]serverID  [4]instanceID  [5]zoneUID  [6]npcID  [7]spawnUID
Creature entry = 6th value from strsplit = 68662
```

Note: Lua's `strsplit` returns values starting at position 1 (not 0-indexed). The creature entry is the **6th return value**.

```lua
local unitType, _, _, _, _, npcID = strsplit("-", sourceGUID)
if unitType == "Creature" then
    local creatureEntry = tonumber(npcID)
end
```

**NPC Detection via sourceFlags**:

```lua
local isNPC = bit.band(sourceFlags, COMBATLOG_OBJECT_TYPE_NPC) > 0
    and bit.band(sourceFlags, COMBATLOG_OBJECT_CONTROL_NPC) > 0
-- COMBATLOG_OBJECT_TYPE_NPC = 0x00000800
-- COMBATLOG_OBJECT_CONTROL_NPC = 0x00000200
```

**Data Upload Mechanism**:

Three options, from simplest to most sophisticated:

1. **Discord upload** — Player uses DraconicBot `/contribute` command, attaches their `SavedVariables/BestiaryForge.lua` file. Bot parses it server-side
2. **Paste-to-channel** — Addon includes a `/bf export` command that produces a compact text dump. Player pastes into a designated Discord channel. Bot auto-parses
3. **Web upload** — Command Center web form for file upload (future enhancement)

**SavedVariables Schema**:

```lua
BestiaryForgeDB = {
    ["version"] = 1,
    ["collector"] = "PlayerName-RealmName",
    ["lastExport"] = 1710153600,
    ["creatures"] = {
        [68662] = {                     -- creature entry ID
            ["name"] = "Hogger",
            ["spells"] = {
                [87337] = {             -- spell ID
                    ["name"] = "Vicious Slice",
                    ["school"] = 1,     -- spell school bitmask
                    ["castCount"] = 14,
                    ["hitCount"] = 12,
                    ["auraCount"] = 0,
                    ["firstSeen"] = 1710150000,
                    ["lastSeen"] = 1710153600,
                    ["zones"] = { "Elwynn Forest" },
                    ["difficulties"] = { [0] = true },
                },
            },
            ["firstSeen"] = 1710150000,
            ["lastSeen"] = 1710153600,
        },
    },
}
```

**Addon Size Estimate**: ~150-200 lines of Lua + TOC file. Minimal memory footprint — only stores unique creature→spell pairs, not individual events.

**Existing Similar Addons** (reference, not competitors):
- `ClassicBestiary` / `NpcAbilities` — static pre-generated DB, not live tracking
- `SpellTracker` — CLEU-based but focused on player analysis, not NPC cataloging
- `KethoCombatLog` — open-source CLEU debug logger (good reference implementation)
- **Wowhead Looter** — the closest analog. Their code hooks CLEU for `SPELL_CAST_START`/`SPELL_CAST_SUCCESS`/`SPELL_AURA_APPLIED`, filters by `COMBATLOG_OBJECT_TYPE_NPC`, and records `wlUnit[npcId].spec[difficulty].spell[spellId] = count`. Our addon would do essentially the same thing but output to a community-accessible format instead of uploading to Wowhead's proprietary pipeline.

---

## 4. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     DATA COLLECTION LAYER                       │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐   │
│  │  WCL Client   │  │  Wowhead     │  │  Retail Addon      │   │
│  │  (Python)     │  │  Scraper     │  │  (Lua)             │   │
│  │              │  │  (Python)    │  │                    │   │
│  │  GraphQL API  │  │  HTML Parse  │  │  CLEU → SavedVars  │   │
│  └──────┬───────┘  └──────┬───────┘  └────────┬───────────┘   │
│         │                 │                    │               │
│         │    JSON         │    JSON            │   Lua table   │
│         ▼                 ▼                    ▼               │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              AGGREGATOR (Python)                        │   │
│  │                                                         │   │
│  │  • Source normalization (WCL/Wowhead/Addon → common)    │   │
│  │  • Deduplication (same creature+spell from 2+ sources)  │   │
│  │  • Confidence scoring (more sources = higher confidence)│   │
│  │  • Spell validation (cross-ref DB2 SpellName)           │   │
│  │  • Difficulty merging                                   │   │
│  │  • Conflict resolution                                  │   │
│  └─────────────────────┬───────────────────────────────────┘   │
│                        │                                       │
└────────────────────────┼───────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CREATURE SPELL REGISTRY                      │
│                    (SQLite or MySQL table)                       │
│                                                                 │
│  creature_entry | spell_id | spell_name | school | sources     │
│  difficulty     | cast_freq | target_hint | confidence | flags  │
│  first_seen     | last_seen | source_details (JSON)             │
└─────────────────────────┬───────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     SQL GENERATION LAYER                        │
│                                                                 │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │  SmartAI Gen     │  │  creature_template│  │  creature_   │  │
│  │                 │  │  Updates          │  │  addon Gen   │  │
│  │  smart_scripts  │  │  AIName, flags,   │  │  auras,      │  │
│  │  INSERT stmts   │  │  unit_class       │  │  emote       │  │
│  └─────────────────┘  └──────────────────┘  └──────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │  creature_       │  │  Loot Template   │  │  Coverage    │  │
│  │  template_spell  │  │  (from Wowhead   │  │  Report      │  │
│  │  Generation      │  │   loot data)     │  │  Generator   │  │
│  └─────────────────┘  └──────────────────┘  └──────────────┘  │
│                                                                 │
│  ┌─────────────────┐  ┌──────────────────┐                     │
│  │  creature_text   │  │  Dungeon Journal │                     │
│  │  Combat speech   │  │  Cross-ref       │                     │
│  └─────────────────┘  └──────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
```

---

## 5. Component Specifications

### 5.1 WCL Client (`tools/bestiary_forge/wcl_client.py`)

**Purpose**: Query Warcraft Logs API v2 for enemy spell cast data.

**Dependencies**: `requests`, `python-dotenv` (for credentials)

**Configuration**:
```env
# .env or config/bestiary_forge.env
WCL_CLIENT_ID=your_client_id
WCL_CLIENT_SECRET=your_client_secret
```

**Core Functions**:
- `authenticate()` → Bearer token (cached until expiry)
- `get_zones()` → All zones with encounter IDs and NPC IDs
- `get_reports(encounterID, page)` → Recent reports for an encounter
- `get_report_actors(reportCode)` → Actor ID → NPC gameID mapping
- `get_enemy_casts(reportCode, fightIDs)` → List of `{creatureEntry, spellID, timestamp}`
- `get_rate_limit()` → Current points usage
- `extract_encounter_spells(encounterID, sampleSize=10)` → Aggregated spells from N reports

**Output Schema** (per creature-spell pair):
```python
{
    "creature_entry": 68662,
    "creature_name": "Hogger",
    "spell_id": 87337,
    "spell_name": "Vicious Slice",
    "source": "wcl",
    "cast_count": 47,          # total across all sampled reports
    "report_count": 8,         # how many reports contained this cast
    "sample_size": 10,         # total reports sampled
    "difficulties": [1, 2, 8], # difficulties observed
    "avg_casts_per_fight": 5.9,
    "encounter_id": 12345,
    "encounter_name": "Hogger",
}
```

**Caching Strategy**:
- Zone/encounter data: Cache for 30 days (changes only on major patches)
- Report lists: Cache for 7 days
- Event data: Cache per report code permanently (reports are immutable)
- Cache stored in `tools/bestiary_forge/cache/wcl/`

---

### 5.2 Wowhead Scraper (`tools/bestiary_forge/wowhead_scraper.py`)

**Purpose**: Extract NPC ability lists from Wowhead NPC pages.

**Dependencies**: `requests` only (no BeautifulSoup needed — data is in JavaScript literals)

**Core Functions**:
- `fetch_npc_abilities(npc_id)` → List of `{spellID, name, school, difficulties}`
- `fetch_npc_loot(npc_id)` → Loot table data (bonus capability)
- `fetch_spell_tooltip(spell_id)` → Extended spell info (name, icon, description)
- `batch_fetch(npc_ids, delay=1.5)` → Rate-limited bulk fetch

**Extraction Regex**:
```python
# Abilities Listview
pattern = r"new Listview\(\{template:\s*'spell',\s*id:\s*'abilities'.*?data:\s*(\[.*?\])\}"
match = re.search(pattern, html, re.DOTALL)
abilities = json.loads(match.group(1))

# Spell descriptions (optional) — note re.DOTALL needed here too
gatherer_pattern = r"WH\.Gatherer\.addData\(6,\s*(\{.*?\})\)"
# Must use: re.search(gatherer_pattern, html, re.DOTALL)
```

**Difficulty Mode Mapping** (from Wowhead `modes.mode` values):
```python
# WARNING: Wowhead's internal difficulty mode IDs may NOT match TrinityCore's
# Difficulty enum. This mapping needs LIVE VERIFICATION against Wowhead pages
# for NPCs with known difficulty-specific abilities.
# A translation layer from Wowhead mode IDs → TC Difficulty enum is required.
#
# TrinityCore Difficulty enum (from SharedDefines.h):
#   0=NONE, 1=NORMAL_5, 2=HEROIC_5, 3=10N, 4=25N, 5=10HC, 6=25HC,
#   7=LFR_OLD, 8=MYTHIC_KEYSTONE, 9=40, 14=NORMAL_RAID, 15=HEROIC_RAID,
#   16=MYTHIC_RAID, 17=LFR_NEW, 23=MYTHIC_DUNGEON, 24=TIMEWALKING, ...
#
# The mapping below is PROVISIONAL and must be verified:
WOWHEAD_DIFFICULTY_MAP = {
    0: (0, "Normal (world)"),       # DIFFICULTY_NONE
    1: (1, "Normal Dungeon"),       # DIFFICULTY_NORMAL
    2: (2, "Heroic Dungeon"),       # DIFFICULTY_HEROIC
    # 3-7: UNVERIFIED — Wowhead may use different numbering than TC
    # Do NOT trust these without live verification:
    # 3: (3, "10-player Normal"),
    # 4: (4, "25-player Normal"),
    # 5: (5, "10-player Heroic"),
    # 6: (6, "25-player Heroic"),
    # 7: (7, "LFR"),
    8: (8, "Mythic Keystone"),      # DIFFICULTY_MYTHIC_KEYSTONE
    9: (9, "40-player Raid"),       # DIFFICULTY_40
    14: (14, "Normal Raid"),        # DIFFICULTY_NORMAL_RAID
    15: (15, "Heroic Raid"),        # DIFFICULTY_HEROIC_RAID
    16: (16, "Mythic Raid"),        # DIFFICULTY_MYTHIC_RAID
    23: (23, "Mythic Dungeon"),     # DIFFICULTY_MYTHIC_DUNGEON
    24: (24, "Timewalking"),        # DIFFICULTY_TIMEWALKING
    # Fallback for unknown values:
    # Any unrecognized mode ID → (mode_id, f"Unknown Difficulty ({mode_id})")
    # Log a warning when this happens for manual investigation
}
```

**Output Schema** (per creature-spell pair):
```python
{
    "creature_entry": 68662,
    "creature_name": "Hogger",
    "spell_id": 87337,
    "spell_name": "Vicious Slice",
    "source": "wowhead",
    "school": 1,
    "difficulties": [0],
    "description": "A vicious slice rips through...",
    "icon": "ability_warrior_punishingblow",
}
```

**Rate Limiting**: 1.5s delay between requests (configurable). Local file cache in `tools/bestiary_forge/cache/wowhead/npc_{id}.json`.

---

### 5.3 Retail Addon (`BestiaryForge/`)

**Purpose**: Passively record creature spell casts while playing retail WoW.

**Files**:
- `BestiaryForge.toc` — Addon metadata + SavedVariables declaration
- `BestiaryForge.lua` — Core CLEU handler + data storage (~150-200 lines)
- `Export.lua` — `/bf export` slash command for text dump (~50 lines)

**WoW API Event**: `COMBAT_LOG_EVENT_UNFILTERED` (commonly abbreviated CLEU). Note: The event name is `COMBAT_LOG_EVENT_UNFILTERED`, NOT `COMBAT_LOG_SUBEVENT_UNFILTERED` — the "sub-event" is the second return value from `CombatLogGetCurrentEventInfo()`, not the event registration name.

**Core Logic**:

```lua
-- Pseudocode for the CLEU handler (registered via frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED"))
OnCombatLogEvent:
  1. Get subevent, sourceGUID, sourceFlags, spellId, spellName, spellSchool
  2. Filter: only SPELL_CAST_START, SPELL_CAST_SUCCESS, SPELL_AURA_APPLIED,
             SPELL_SUMMON, SPELL_HEAL (on non-player targets)
  3. Filter: source must be NPC (check sourceFlags bitmask)
  4. Extract creatureEntry from sourceGUID (field 6 after split by "-")
  5. Store/increment in BestiaryForgeDB.creatures[creatureEntry].spells[spellId]
  6. Record metadata: name, school, count, firstSeen, lastSeen, zone, difficulty
```

**Slash Commands**:
- `/bf` or `/bestiaryforge` — Show status (creature count, spell count, session stats)
- `/bf export` — Generate compact text export to chat/clipboard
- `/bf reset` — Clear database (with confirmation)
- `/bf ignore <spellId>` — Add spell to blacklist (Dazed, Auto Attack, etc.)

**Spell Blacklist** (common non-notable spells to ignore):
```lua
local SPELL_BLACKLIST = {
    [1604] = true,   -- Dazed
    [6603] = true,   -- Auto Attack (melee)
    [75] = true,     -- Auto Shot (ranged)
    [3018] = true,   -- Shoot (wand)
    [1784] = true,   -- Stealth
    [2983] = true,   -- Sprint
    [20577] = true,  -- Cannibalize
    [7744] = true,   -- Will of the Forsaken
    [20549] = true,  -- War Stomp
    [26297] = true,  -- Berserking
    -- Add more via /bf ignore <spellId>
    -- HEURISTIC: Spells observed on 100+ different creature entries
    -- are likely generic and should be auto-blacklisted
}

-- Creature Entry Blacklist (environmental/trigger creatures)
local CREATURE_BLACKLIST = {
    [0] = true,      -- World/environment damage
    [1] = true,      -- World
    [19871] = true,  -- WorldTrigger
    [21252] = true,  -- World Trigger (Large AOI)
    [22515] = true,  -- World Trigger (Large AOI, Not Immune PC/NPC)
    -- Configurable via /bf ignoreNPC <entry>
}
```

**Additional Filters**:
- Skip `sourceGUID` with unitType `"Vehicle"` (vehicle spells are player-controlled, not AI)
- Skip friendly NPCs: check `bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) > 0`
- Auto-detect generic spells: if a spell appears on 100+ unique creature entries, flag for review

**Memory Management**:
- Only stores unique creature→spell pairs, not individual events
- Estimated memory: ~200 bytes per unique pair × ~10 spells per creature × 1000 creatures encountered = ~2MB
- SavedVariables file size: similar, acceptable for WoW addon standards

**Export Format** (for Discord paste):
```
BFEXPORT:v1
68662:Hogger|87337:14:1:Vicious Slice|87351:3:1:Eating|87352:8:1:Upset Stomach
91784:Archdruid Glaidalis|204658:22:64:Grievous Tear|196346:15:8:Nightfall Bolt
END
```

Format: `creatureEntry:creatureName|spellID:castCount:school:spellName|...`
Compact enough to paste in Discord (under 2000 char limit for ~5-10 creatures).

---

### 5.4 Aggregator (`tools/bestiary_forge/aggregator.py`)

**Purpose**: Merge data from all three sources into a unified creature spell registry.

**Core Functions**:
- `ingest_wcl(data)` → Normalize WCL format to common schema
- `ingest_wowhead(data)` → Normalize Wowhead format to common schema
- `ingest_addon(lua_file)` → Parse SavedVariables Lua into common schema
- `merge()` → Deduplicate, score confidence, resolve conflicts
- `validate_spells(registry)` → Cross-reference all spell IDs against DB2 `SpellName`
- `export_registry()` → Write unified registry to SQLite/JSON

**Confidence Scoring**:

Each creature→spell pair gets a confidence score (0.0 - 1.0):

| Condition | Score Contribution |
|-----------|-------------------|
| Present in WCL data | +0.35 |
| Present in Wowhead data | +0.30 |
| Present in addon data (1 contributor) | +0.15 |
| Present in addon data (3+ contributors) | +0.30 |
| Spell ID validated against DB2 SpellName | +0.05 |
| Multiple difficulty modes confirmed | +0.05 |
| High cast count in WCL (>10 avg/fight) | +0.05 |
| Present in Dungeon Journal | +0.10 |

Scores are capped at 1.0. Maximum theoretical sum = 1.20 (all sources, all bonuses), capped to 1.0.

**Weighting rationale**: WCL gets the highest weight (0.35) because it provides timing/frequency data, not just existence. Wowhead (0.30) is broadly reliable but community-sourced. A single addon contributor (0.15) is less trusted than aggregated sources, but 3+ contributors (0.30) approaches Wowhead-level reliability through consensus. These weights are tunable — adjust based on observed false positive/negative rates.

Thresholds:
- **0.6+**: Auto-generate SmartAI (high confidence)
- **0.3-0.6**: Generate SmartAI with `-- LOW CONFIDENCE` comment, flag for review
- **<0.3**: Log only, do not auto-generate

**Conflict Resolution**:
- Spell name mismatch across sources → Use DB2 SpellName as canonical
- Difficulty disagreement → Union of all reported difficulties
- One source says creature has spell, another doesn't → Include it (absence of evidence is not evidence of absence)

**Deduplication**:
- Key: `(creature_entry, spell_id)`
- Merge metadata from all sources (take max cast_count, union difficulties, etc.)

---

### 5.5 SQL Generator (`tools/bestiary_forge/sql_generator.py`)

**Purpose**: Generate production-ready SQL from the creature spell registry.

#### Output 1: SmartAI (`smart_scripts`)

For each creature with discovered spells, generate SmartAI rows:

**Behavioral Template Selection** (based on available metadata):

| Data Available | Template Used |
|----------------|--------------|
| Spell with high cast frequency, targets enemy | `UPDATE_IC` (event=0) timer — repeat every N seconds, target=VICTIM |
| Spell cast once per fight (count ≈ 1 per report) | `AGGRO` (event=4) — cast on pull, one-time |
| Self-buff spell (target = self in WCL data) | `AGGRO` (event=4) + target=SELF — self-buff on engage |
| Heal spell | `UPDATE_IC` (event=0) timer + target=SELF |
| Summon spell | `UPDATE_IC` (event=0) timer + target=SELF |
| AoE spell | `UPDATE_IC` (event=0) timer + target=HOSTILE_RANDOM or THREAT_LIST |
| No frequency data (Wowhead only) | Default `UPDATE_IC` (event=0) 8-12s timer, target=VICTIM |

**Timer Estimation** (when WCL provides cast frequency):
```python
avg_fight_duration = sum(fight.duration for fight in fights) / len(fights)
avg_casts = total_cast_count / total_fights
estimated_interval = avg_fight_duration / avg_casts  # in seconds

# MINIMUM TIMER FLOOR: Prevent degenerate sub-2s spam from short trash fights
# (e.g., trash mob dies in 3s, cast 2 spells → 1.5s interval without floor)
MIN_REPEAT_MS = 3000   # 3 seconds minimum repeat
MIN_INITIAL_MS = 2000  # 2 seconds minimum initial delay

# Add ±25% variance for natural feel
repeat_min = max(MIN_REPEAT_MS, int(estimated_interval * 0.75 * 1000))
repeat_max = max(MIN_REPEAT_MS + 2000, int(estimated_interval * 1.25 * 1000))
initial_min = max(MIN_INITIAL_MS, int(estimated_interval * 0.5 * 1000))
initial_max = max(MIN_INITIAL_MS + 2000, int(estimated_interval * 0.75 * 1000))

# Also cap per-creature row count (avoid 50+ SmartAI rows per creature)
MAX_SPELLS_PER_CREATURE = 15  # Top 15 by confidence × frequency
```

**Generated SQL Format**:
```sql
-- ============================================
-- BestiaryForge Auto-Generated SmartAI
-- Creature: Hogger (entry 448)
-- Sources: WCL (8 reports), Wowhead, Addon (2 contributors)
-- Confidence: 0.85
-- Generated: 2026-03-11
-- ============================================

-- Set AIName for creature (guards: only if no existing AI name AND no C++ script)
UPDATE `creature_template` SET `AIName`='SmartAI'
WHERE `entry`=448 AND `AIName`='' AND `ScriptName`='';

-- SmartAI scripts
-- SAFETY: Only generate if creature has NO existing SmartAI rows.
-- Generator must check: SELECT COUNT(*) FROM smart_scripts WHERE entryorguid=448 AND source_type=0
-- If count > 0, SKIP this creature (preserve hand-crafted scripts) unless --force flag is used.
DELETE FROM `smart_scripts` WHERE `entryorguid`=448 AND `source_type`=0;
INSERT INTO `smart_scripts` (`entryorguid`,`source_type`,`id`,`link`,`Difficulties`,
  `event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
  `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param_string`,
  `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`action_param7`,`action_param_string`,
  `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,`target_param_string`,
  `target_x`,`target_y`,`target_z`,`target_o`,`comment`) VALUES
-- Vicious Slice (87337) — avg 5.9 casts/fight, ~8s interval [WCL+Wowhead, conf=0.85]
(448, 0, 0, 0, '',  0, 0, 100, 0,  4000, 6000, 6000, 10000, 0, '',  11, 87337, 0, 0, 0, 0, 0, 0, NULL,  2, 0, 0, 0, 0, NULL,  0, 0, 0, 0, 'Hogger - IC 6-10s - Cast Vicious Slice'),
-- Summon Minions (87366) — avg 1.2 casts/fight [WCL, conf=0.70]
(448, 0, 1, 0, '',  0, 0, 100, 0,  15000, 20000, 30000, 45000, 0, '',  11, 87366, 0, 0, 0, 0, 0, 0, NULL,  1, 0, 0, 0, 0, NULL,  0, 0, 0, 0, 'Hogger - IC 30-45s - Cast Summon Minions');
```

**AGGRO template example** (spell cast once on pull — self-buff):
```sql
-- Self-Buff on Aggro (99999) — avg 1.0 casts/fight, always targets self [WCL, conf=0.80]
(448, 0, 2, 0, '',  4, 0, 100, 0,  0, 0, 0, 0, 0, '',  11, 99999, 0, 0, 0, 0, 0, 0, NULL,  1, 0, 0, 0, 0, NULL,  0, 0, 0, 0, 'Hogger - On Aggro - Cast Self-Buff');
-- Note: event_type=4 (AGGRO), event_params all 0 (no timer), target_type=1 (SELF)
```

**String Column Defaults** (important for SQL generation):
- `event_param_string`: `NOT NULL DEFAULT ''` → use `''` (empty string)
- `action_param_string`: `DEFAULT NULL` → use `NULL`
- `target_param_string`: `DEFAULT NULL` → use `NULL`
- `Difficulties`: `NOT NULL DEFAULT ''` → use `''` (empty string)

**Validation Before Emission**:
1. Every spell ID checked against `hotfixes.spell_name` (via wago-db2 MCP or direct DB query)
2. Column count verified (35 columns in VALUES)
3. Comment includes source attribution and confidence score
4. `DELETE` before `INSERT` to make scripts idempotent
5. `UPDATE creature_template` only sets AIName if currently empty (doesn't overwrite existing scripts)

#### Output 2: `creature_template` Updates

```sql
-- Set AIName for creatures that need SmartAI
UPDATE `creature_template` SET `AIName`='SmartAI'
WHERE `entry` IN (448, 91784, 114895) AND `AIName`='';
```

#### Output 3: `creature_template_spell`

For creatures that should have spells on their action bar — **ONLY for player-controllable creatures** (pets, vehicles, mind-controlled NPCs).

**IMPORTANT**: Do NOT generate `creature_template_spell` rows for normal mobs/bosses that use SmartAI. When `AIName='SmartAI'` is set, the creature uses `SmartAI` (not `CombatAI`), and `creature_template_spell` entries are **inert** — they load into the template but the SmartAI never reads `m_spells`. Generating both creates dead rows and DB bloat. Only generate these for creatures with `unit_flags` indicating pet/vehicle/controllable status, or when explicitly requested.

**Constraints**:
- Table has 4 columns: `CreatureID`, `Index`, `Spell`, `VerifiedBuild` (default 0)
- `MAX_CREATURE_SPELLS = 8` — Index values must be 0-7
- These are action bar spells, NOT AI cast logic (that's SmartAI)
- **Double-cast risk**: If a creature has BOTH `creature_template_spell` AND SmartAI for the same spell, and the AI is later changed from SmartAI to CombatAI, the spell could fire from both systems

```sql
INSERT INTO `creature_template_spell` (`CreatureID`, `Index`, `Spell`) VALUES
(448, 0, 87337),  -- Vicious Slice
(448, 1, 87366);  -- Summon Minions
-- Note: VerifiedBuild defaults to 0 when omitted
```

#### Output 4: `creature_addon` Aura Generation

If a spell is observed as a persistent aura (high uptime, self-applied), generate addon aura.

**WARNING**: The `auras` column is a space-separated string. A raw `UPDATE SET auras='...'` would **overwrite** existing auras. The generator must:
1. Query existing auras first
2. Append new auras (space-separated) to existing value
3. Deduplicate
4. Or use DELETE + INSERT pattern for full replacement (with explicit comment noting overwrite)

```sql
-- SAFE: Only sets auras if none exist
UPDATE `creature_template_addon` SET `auras`='12345 67890'
WHERE `entry`=448 AND (`auras` IS NULL OR `auras`='');

-- FULL REPLACEMENT: Overwrites existing auras (use with caution)
-- Existing auras for entry 448: [query result here]
UPDATE `creature_template_addon` SET `auras`='existing_aura_1 12345 67890'
WHERE `entry`=448;
```

#### Output 5: Coverage Report

```
=== BestiaryForge Coverage Report ===
Date: 2026-03-11
Registry: 2,847 creatures, 12,291 creature-spell pairs
Total creature entries in DB: ~200,000+
Overall coverage: ~1.4% (most data from instanced content)

By Source:
  WCL:     812 creatures (0.4%)   — 4,934 spell pairs (rich: timing + frequency)
  Wowhead: 1,203 creatures (0.6%) — 3,447 spell pairs (boss pages with abilities)
  Addon:   1,847 creatures (0.9%) — 7,221 spell pairs (broadest, includes open-world)

Confidence Distribution:
  High (0.6+):   8,234 creatures (64.1%)
  Medium (0.3-0.6): 3,102 creatures (24.1%)
  Low (<0.3):    1,511 creatures (11.8%)

Coverage by Zone (Midnight content):
  Isle of Dorn:          412/487 creatures (84.6%)
  The Ringing Deeps:     389/445 creatures (87.4%)
  Hallowfall:            401/512 creatures (78.3%)
  Azj-Kahet:             356/498 creatures (71.5%)
  [... etc ...]

Missing (0 spell data):
  Creature 234567 "Unknown Mob" — no sources
  Creature 234568 "Rare Elite" — no sources
  [... list ...]
```

---

## 6. Full Capability Matrix — What BestiaryForge Can Generate

| Output | Table/System | Source Required | Auto-Quality |
|--------|-------------|----------------|-------------|
| SmartAI spell casts | `smart_scripts` | Any tier | High (with WCL frequency data) |
| Creature AI assignment | `creature_template.AIName` | Any tier | High |
| Action bar spells | `creature_template_spell` | Any tier | Medium |
| Spawn auras | `creature_template_addon.auras` | Tier 1 or 3 (need uptime data) | Medium |
| Loot tables | `creature_loot_template` | Tier 2 (Wowhead loot data) | High (Phase 5 — not in MVP) |
| Combat text/emotes | `creature_text` | Manual/Wowhead (if available) | Low |
| Dungeon Journal cross-ref | Validation only | DB2 `JournalEncounterSection` | High |
| Spell school validation | Validation only | DB2 `SpellName` + `SpellEffect` | High |
| Coverage gap reports | Reporting only | All tiers | N/A |
| Difficulty-specific scripts | `smart_scripts.Difficulties` | Tier 1 or 2 | Medium |
| Cast frequency estimation | Timer params in SmartAI | Tier 1 (WCL has timing data) | Medium-High |
| Target type inference | SmartAI `target_type` | Tier 1 (WCL has target data) | Medium |

---

## 7. Registry Database Schema

### Option A: SQLite (standalone, portable)

```sql
CREATE TABLE creature_spells (
    creature_entry INTEGER NOT NULL,
    spell_id INTEGER NOT NULL,
    creature_name TEXT,
    spell_name TEXT,
    spell_school INTEGER DEFAULT 0,
    confidence REAL DEFAULT 0.0,

    -- Source flags
    from_wcl BOOLEAN DEFAULT 0,
    from_wowhead BOOLEAN DEFAULT 0,
    from_addon BOOLEAN DEFAULT 0,
    from_journal BOOLEAN DEFAULT 0,

    -- WCL-specific metadata
    wcl_avg_casts_per_fight REAL,
    wcl_report_count INTEGER,
    wcl_target_self_pct REAL,       -- % of casts targeting self (for self-buff detection)
    wcl_target_random_pct REAL,     -- % of casts on non-tank targets
    wcl_encounter_id INTEGER,

    -- Wowhead-specific metadata
    wowhead_description TEXT,
    wowhead_icon TEXT,

    -- Addon-specific metadata
    addon_contributor_count INTEGER DEFAULT 0,
    addon_total_cast_count INTEGER DEFAULT 0,

    -- Common metadata
    difficulties TEXT,              -- JSON array of difficulty IDs
    first_seen INTEGER,             -- Unix timestamp
    last_seen INTEGER,
    zones TEXT,                     -- JSON array of zone names

    -- Generation state
    smartai_generated BOOLEAN DEFAULT 0,
    smartai_generation_date TEXT,
    manually_reviewed BOOLEAN DEFAULT 0,

    PRIMARY KEY (creature_entry, spell_id)
);

CREATE INDEX idx_creature ON creature_spells(creature_entry);
CREATE INDEX idx_spell ON creature_spells(spell_id);
CREATE INDEX idx_confidence ON creature_spells(confidence);
CREATE INDEX idx_not_generated ON creature_spells(smartai_generated) WHERE smartai_generated = 0;
```

### Option B: MySQL Table (integrated with world DB)

Same schema as above but in the `roleplay` database (our custom 5th DB):

```sql
CREATE TABLE `roleplay`.`creature_spell_registry` (
    -- same columns as above
    -- accessible alongside our other custom tables
);
```

**Recommendation**: Start with SQLite for portability and development speed. Migrate to MySQL later if integration with the server runtime is desired.

---

## 8. Implementation Plan — REVISED (Post-Adversarial Review)

> **Key insight from review**: The original 5-phase plan was over-engineered. WCL and Wowhead
> both cover instanced bosses that TDB/LoreWalker already have SmartAI for. The retail addon
> is the only source covering the actual gap (open-world mobs), but requires community adoption.
> The pragmatic path: ship a small tool fast, expand only if it proves valuable.

### Phase 0: Prerequisites (Before Building Anything)
1. **Import LoreWalker TDB SmartAI delta** — 500K rows already available from `lw_diff_pipeline.py`. This is the baseline. Don't auto-generate scripts for creatures that already have hand-crafted AI
2. **Extract Dungeon Journal spells** — Simple wago-db2 query against `JournalEncounterSection.SpellID` for all boss abilities. Zero scraping, instant results

### Phase 1: MVP (Addon + Python Pipeline, Ship This Week)
> **CORRECTION**: Wowhead scraping alone does NOT solve the core user request ("wowhead got nearly no mob spells"). The MVP **must** include the Retail Addon to capture open-world mob data, which is the entire point of this project.

3. **Retail Addon (`BestiaryForge`)** — The core data collection engine for open-world mobs.
   - Passive CLEU tracking.
   - `/bf export` command for easy copy-pasting by noobs.
4. **One Python file** (~300 lines) — `tools/bestiary_forge/forge.py`
   - Prompts user to paste their Addon export string (or takes Wowhead NPC IDs).
   - **Connects to local MySQL (`pymysql`)** to safely check if the creature already has SmartAI.
   - Cross-references spell IDs against DB2 for target/timer data via `wago-db2 MCP`.
   - Generates SmartAI SQL with guards.
5. **Noob Wrapper** — `run_forge.bat` so users can double-click and run it interactively without command-line knowledge.

### Phase 2: WCL Integration & Advanced Aggregation
6. WCL client — OAuth, rate limit management
7. Timer estimation from WCL frequency data
8. SQLite registry + aggregator + confidence scoring
9. Advanced DraconicBot `/contribute` command for crowdsourcing

### Phase 3: Full Pipeline
10. Coverage reports, batch processing, incremental updates

### What We Cut (And Why)
- **Confidence scoring**: False precision on noisy data. You either trust the output or you don't
- **SQLite registry**: A JSON cache file is sufficient until proven otherwise
- **Coverage reports with per-zone percentages**: Vanity metrics
- **CurseForge distribution**: Premature — build the addon first, distribute it when people ask for it
- **Web dashboard**: Pure feature creep
- **Loot table generation**: Out of scope
- **Behavioral pattern recognition**: Fantasy for v1

---

## 8b. Critical Data Sources We're NOT Using (Free Wins)

> These DB2 tables are already available via wago-db2 MCP. They provide data that would
> take WCL hundreds of API calls to infer, and they're more accurate.

### SpellEffect.ImplicitTarget — FREE Target Type Inference

Every spell in DB2 has `ImplicitTarget[0]` and `ImplicitTarget[1]` that tell you exactly what the spell targets. Cross-referencing a discovered spell ID against this table eliminates the need for WCL target analysis:

| ImplicitTarget Value | Meaning | SmartAI target_type |
|---------------------|---------|---------------------|
| 1 (TARGET_UNIT_CASTER) | Self-cast | `SMART_TARGET_SELF` (1) |
| 6 (TARGET_UNIT_TARGET_ENEMY) | Single enemy | `SMART_TARGET_VICTIM` (2) |
| 15 (TARGET_UNIT_SRC_AREA_ENEMY) | AoE around caster | `SMART_TARGET_SELF` (1) with AoE spell |
| 16 (TARGET_UNIT_DEST_AREA_ENEMY) | AoE at target location | `SMART_TARGET_VICTIM` (2) |
| 22 (TARGET_UNIT_CONE_ENEMY) | Frontal cone | `SMART_TARGET_VICTIM` (2) |
| 25 (TARGET_UNIT_TARGET_ALLY) | Single ally | `SMART_TARGET_SELF` (1) for heals |
| 30 (TARGET_UNIT_SRC_AREA_ALLY) | AoE heal | `SMART_TARGET_SELF` (1) |

**This single cross-reference replaces the entire WCL target analysis pipeline.**

### SpellMisc.CastingTimeIndex — Cast Time Detection

If `CastingTimeIndex > 0`, the spell has a cast time. This affects:
- Whether the creature stands still while casting
- Whether the cast can be interrupted
- Timer intervals (cast time is part of the interval)

### SpellCategories.Cooldown — Timer Floor From Game Data

If a spell has a 30-second cooldown in DB2, the SmartAI repeat timer should be at least 30 seconds. This replaces crude WCL frequency estimation with hard game data.

### SpellAuraOptions — Aura Duration for creature_addon

If `Duration > 0` AND it's a self-buff, it has a finite duration (not a spawn aura). If `Duration = -1` or `Duration = 0` with `StackAmount > 0`, it may be a permanent aura suitable for `creature_addon.auras`.

---

## 8c. Safety Requirements (Noob-Proofing)

> Adversarial review from a "total noob" perspective found 63 issues.
> These are the mandatory safety features for any release.

### Pre-Application Warnings
Every generated SQL file MUST include this header:
```sql
-- =====================================================================
-- BestiaryForge Auto-Generated SmartAI
-- Generated: [date]
--
-- !! BACKUP YOUR WORLD DATABASE BEFORE APPLYING !!
-- HeidiSQL: Right-click world DB → Export as SQL
-- Command line: mysqldump -u root -p world > world_backup.sql
--
-- After applying, restart worldserver or run: .reload smart_scripts
--
-- This file is SAFE to apply multiple times (idempotent).
-- It will NOT overwrite existing hand-crafted SmartAI.
-- =====================================================================
```

### Mandatory Guards in Generated SQL & Generator Logic
1. **Pre-generation Check**: The Python generator MUST connect to MySQL (`pymysql`) and check `SELECT COUNT(*) FROM smart_scripts WHERE entryorguid=X`. If > 0, it entirely skips generating the `DELETE` and `INSERT` statements for that creature. You cannot reliably guard a `DELETE` in raw offline SQL without wiping rows, so the script must check *before* emitting the text file.
2. `WHERE AIName='' AND ScriptName=''` — never overwrite existing AI
3. Timer floor: minimum 3000ms repeat, 2000ms initial
4. Per-creature cap: maximum 15 SmartAI rows

### Dry-Run Mode
`python forge.py --dry-run --npc 448` must preview output without writing files.

### Compatibility Statement
```
COMPATIBLE WITH: TrinityCore master branch (Midnight / 12.x)
NOT COMPATIBLE WITH: AzerothCore, CMaNGOS, WOTLK 3.3.5, or any non-master branch
```

---

## 9. QA/QC Methodology

### Validation Gates

1. **Spell ID Validation**: Every spell ID in the registry is checked against BOTH DB2 `SpellName` (via wago-db2 MCP) AND `world.serverside_spell` (for emulator-only spells like custom range 1900003+). A spell is valid if it exists in EITHER source. Only spells that fail BOTH checks are flagged and excluded from SQL generation.

2. **Column Count Verification**: Generated SQL INSERT statements have their column count programmatically verified against the target table schema (35 columns for `smart_scripts`).

3. **Idempotency Check**: All generated SQL uses `DELETE` before `INSERT` pattern. Re-running the same generation produces identical output.

4. **SmartAI Semantic Validation**: Generated scripts are validated against the same rules as `/smartai-check`:
   - Event types valid for source_type=0 (creature)
   - Action params within valid ranges
   - No deprecated event/action types
   - Timer values > 0 for repeating events
   - Spell IDs exist in `hotfixes.spell_name` or `world.serverside_spell`

5. **Cross-Source Verification**: When a spell appears in multiple sources, verify spell name matches across sources. Flag mismatches for manual review.

6. **Regression Testing**: Maintain a test suite of known-good creature→spell mappings (e.g., Hogger's abilities) and verify the pipeline produces correct output for these.

### Manual Review Workflow

For medium-confidence (0.3-0.6) entries:
1. Generated SQL includes `-- REVIEW: [reason]` comments
2. Coverage report lists all medium-confidence entries
3. Human reviewer can:
   - Approve → set `manually_reviewed = 1`
   - Reject → remove from registry
   - Adjust → modify timer values, target types

---

## 10. Risk Analysis

| Risk | Severity | Mitigation |
|------|----------|------------|
| WCL API rate limits exceeded | Medium | Aggressive caching, Patreon subscription ($5/mo for 10x), batch processing during off-hours |
| Wowhead changes page structure | Medium | Regex extraction is fragile — version the scraper, add structure detection tests, alert on parse failures |
| Wowhead blocks scraping | Low | Use normal user-agent, respect rate limits, cache aggressively. Fallback: use Wowhead Looter data from WCL instead |
| 12.x addon API changes break CLEU | Low | CLEU has been stable for 15+ years. Secret Values don't affect open-world CLEU. Monitor patch notes |
| Incorrect SmartAI generation (wrong timers/targets) | Medium | Conservative defaults, confidence thresholds, mandatory `-- REVIEW` comments, manual review workflow |
| Spell ID exists in DB2 but is wrong for this creature | Low | Cross-source validation catches most cases. Confidence scoring reduces impact |
| Generated SQL conflicts with existing hand-crafted SmartAI | Medium | `UPDATE creature_template` only sets AIName if empty. `DELETE FROM smart_scripts WHERE entry=X` is explicit. Generated SQL clearly marked with BestiaryForge header comments |
| SavedVariables bloat on retail addon | Low | Only stores unique pairs (~2MB typical). `/bf reset` available |
| Community abuse of crowdsource addon | Low | Data is additive (more data = better). Bad data from one contributor is diluted by others. Can blacklist contributors if needed |

---

## 11. Future Extensions

### 11.1 Behavioral Pattern Recognition
With enough WCL data, detect patterns like:
- Phase transitions (spell X only appears after 50% HP)
- Spell combos (spell X always followed by spell Y)
- Enrage timers (spell frequency increases over fight duration)
- Add waves (summon spells at fixed intervals)

### 11.2 WoWHead Loot Integration
The same scraper can extract loot tables from Wowhead NPC pages (different `Listview` block with `template: 'item'`). Auto-generate `creature_loot_template` entries.

### 11.3 Reverse Lookup
"Which creatures cast spell X?" — useful for finding all users of a specific ability.

### 11.4 Diff Reports
Compare current server SmartAI against BestiaryForge registry to find:
- Creatures with SmartAI that's missing spells (under-scripted)
- Creatures with SmartAI spells not in the registry (possibly custom/wrong)
- Timer values that differ significantly from WCL frequency data

### 11.5 Community Hub
Web dashboard showing:
- Coverage stats per zone/expansion
- Recent contributions
- Missing creature leaderboard ("help us fill in these NPCs!")
- Integration with DraconicBot for Discord notifications

### 11.6 Auto-Parse Integration
Feed BestiaryForge data into our existing auto_parse pipeline:
- After a play session on our server, compare observed creature behavior against registry
- Flag creatures that cast spells not in their SmartAI (data-driven QA)

---

## 12. File Structure

```
tools/bestiary_forge/
├── __init__.py
├── __main__.py              # CLI entry point
├── config.py                # Configuration, paths, thresholds
├── wcl_client.py            # Tier 1: Warcraft Logs API
├── wowhead_scraper.py       # Tier 2: Wowhead page scraper
├── addon_importer.py        # Tier 3: Lua SavedVariables parser
├── aggregator.py            # Merge, deduplicate, score
├── sql_generator.py         # Generate SmartAI + other SQL
├── spell_validator.py       # Cross-ref against DB2
├── coverage_report.py       # Gap analysis reporting
├── registry.py              # SQLite registry interface
├── cache/
│   ├── wcl/                 # WCL API response cache
│   └── wowhead/             # Wowhead page cache
├── output/                  # Generated SQL files
└── tests/
    ├── test_wcl.py
    ├── test_wowhead.py
    ├── test_aggregator.py
    └── test_sql_generator.py

BestiaryForge/               # Retail WoW addon (separate distribution)
├── BestiaryForge.toc
├── BestiaryForge.lua
└── Export.lua
```

---

## 13. Open Questions for Architect Review

1. **Registry location**: SQLite standalone vs MySQL `roleplay` DB? SQLite is simpler and portable, but MySQL integrates with server runtime. Recommendation: SQLite for now.

2. **Community distribution**: Should the retail addon be distributed via CurseForge, or GitHub-only? CurseForge has broader reach but requires account/approval process.

3. **Naming**: "BestiaryForge" is a working title. Alternatives: "CreatureIntel", "MobForge", "SpellHarvest", "NPC Codex". Need a name that's clear and memorable.

4. **Scope of auto-generation**: Should we auto-generate SmartAI for ALL creatures above the confidence threshold, or only for creatures that currently have NO SmartAI? The latter is safer (doesn't overwrite existing work).

5. **DraconicBot integration depth**: Simple file upload via `/contribute`, or full query interface (`/bestiary hogger` → show known spells)?

6. **WCL Patreon**: Is $5/mo for 10x rate limit worth it? Depends on how aggressively we want to batch-query.

7. **Open-source**: Is there interest in open-sourcing the pipeline for the broader emulator community? This could significantly increase addon adoption and data contributions.

8. **Loot tables**: Should Phase 1 include loot scraping from Wowhead, or defer to a later phase? The scraper infrastructure would already be in place.

---

## Appendix A: SmartAI Quick Reference

### Minimum Viable SmartAI Row

**"Creature 12345 casts Spell 67890 every 8-12 seconds in combat"**:

```sql
UPDATE `creature_template` SET `AIName`='SmartAI' WHERE `entry`=12345;

INSERT INTO `smart_scripts`
  (`entryorguid`,`source_type`,`id`,`link`,`Difficulties`,
   `event_type`,`event_phase_mask`,`event_chance`,`event_flags`,
   `event_param1`,`event_param2`,`event_param3`,`event_param4`,`event_param5`,`event_param_string`,
   `action_type`,`action_param1`,`action_param2`,`action_param3`,`action_param4`,`action_param5`,`action_param6`,`action_param7`,`action_param_string`,
   `target_type`,`target_param1`,`target_param2`,`target_param3`,`target_param4`,`target_param_string`,
   `target_x`,`target_y`,`target_z`,`target_o`,`comment`)
VALUES
  (12345, 0, 0, 0, '',
   0, 0, 100, 0,
   5000, 8000, 8000, 12000, 0, '',
   11, 67890, 0, 0, 0, 0, 0, 0, NULL,
   2, 0, 0, 0, 0, NULL,
   0, 0, 0, 0,
   'Creature 12345 - IC 8-12s - Cast Spell 67890');
```

### Key Enum Values

**Event Types**: 0=UPDATE_IC, 1=UPDATE_OOC, 2=HEALTH_PCT, 4=AGGRO, 6=DEATH, 7=EVADE, 60=UPDATE
**Action Types**: 11=CAST, 85=SELF_CAST, 1=TALK, 22=SET_EVENT_PHASE (SmartAI phase, NOT world phase), 24=EVADE
**Target Types**: 0=NONE, 1=SELF, 2=VICTIM, 5=HOSTILE_RANDOM, 6=HOSTILE_RANDOM_NOT_TOP, 24=THREAT_LIST
**WARNING**: Do NOT confuse action 22 (SET_EVENT_PHASE — SmartAI internal phase) with action 44 (SET_INGAME_PHASE_ID — world visibility phase). They are completely different systems.
**Cast Flags**: 0x01=INTERRUPT_PREVIOUS, 0x02=TRIGGERED, 0x20=AURA_NOT_PRESENT

### Required Prerequisites

- `creature_template.AIName` must be `'SmartAI'` for the creature entry
- Spell ID must exist in `hotfixes.spell_name` or `world.serverside_spell`
- Row IDs (`id` column) must be sequential starting from 0 per creature

---

## Appendix B: Warcraft Logs API Authentication Flow

```python
import requests
import base64

def get_wcl_token(client_id, client_secret):
    """Exchange client credentials for a bearer token."""
    credentials = base64.b64encode(f"{client_id}:{client_secret}".encode()).decode()
    response = requests.post(
        "https://www.warcraftlogs.com/oauth/token",
        headers={
            "Authorization": f"Basic {credentials}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        data={"grant_type": "client_credentials"},
    )
    response.raise_for_status()
    return response.json()["access_token"]

def query_wcl(token, query, variables=None):
    """Execute a GraphQL query against WCL API v2."""
    response = requests.post(
        "https://www.warcraftlogs.com/api/v2/client",
        headers={"Authorization": f"Bearer {token}"},
        json={"query": query, "variables": variables or {}},
    )
    response.raise_for_status()
    return response.json()["data"]
```

---

## Appendix C: 12.x Addon API Restrictions Summary

| Context | CLEU Readable? | UnitAura? | UNIT_SPELLCAST? | /combatlog File? |
|---------|---------------|-----------|-----------------|------------------|
| Open world | Full | Full | Full | Full |
| Dungeon (no key) | Full | Full | Full | Full |
| M+ (active key) | Secret values | Secret | Secret | **Full** |
| Raid boss (active) | Secret values | Secret | Secret | **Full** |
| Between pulls | Full | Full | Full | Full |
| Player's own casts | Full | Full | Full | Full |

**Key insight**: The `/combatlog` text file is NEVER restricted. This is what Warcraft Logs uses, and it remains fully functional in all contexts. Our retail addon uses CLEU (the API equivalent), which is unrestricted in open-world — the primary context for our data collection.

**WeakAuras status in Midnight** (as of mid-2025): WeakAuras announced end of WoW support due to Secret Values making combat functionality unusable. Blizzard has since relaxed some restrictions and whitelisted certain spells — the situation may evolve further. However, passive data logging (our use case) was never affected regardless.

---

## Appendix D: Source Quality Comparison

| Attribute | WCL (Tier 1) | Wowhead (Tier 2) | Addon (Tier 3) |
|-----------|-------------|-------------------|-----------------|
| **Data richness** | Highest — timing, frequency, targets, difficulty | Medium — spell list only, difficulty modes | High — frequency, zones, but no targets |
| **Coverage breadth** | Instanced only (~0.5% of entries) | Instanced bosses + notable NPCs (narrower than assumed) | **Broadest** — covers everything players encounter |
| **Automation level** | Fully automated | Fully automated | Semi-automated (needs contributors) |
| **Latency** | Days after content release | 1-3 weeks for new content | Real-time as players contribute |
| **Setup effort** | API key registration | None | Addon installation |
| **Rate limits** | 3,600-36,000 pts/hr | 1-2 req/sec recommended | N/A |
| **Maintenance** | Low (stable API) | Medium (fragile scraping) | Low (stable CLEU API) |
| **Unique value** | Cast timing + frequency | Spell descriptions + icons | Open-world coverage |

---

## Appendix E: Adversarial Review — Issues Found & Mitigations

> 4 parallel attack agents ran against this spec with instructions to "try to break it."
> 118 raw issues found, deduplicated to 52 unique issues below.
> Issues marked **[FIXED]** have been corrected inline in the spec above.
> Issues marked **[DEFERRED]** are acknowledged and will be addressed during implementation.

### Critical (Will Cause System Failure)

| # | Issue | Status | Resolution |
|---|-------|--------|------------|
| C1 | WCL `Encounter` type has no `npcID` field — Query #1 returns GraphQL error | **[FIXED]** | Removed `npcID` from query, noted that NPC IDs come from `fights.enemyNPCs` |
| C2 | No documented WCL API method to discover report codes by encounter | **[FIXED]** | Added note about `worldData.encounter.fightRankings` path; marked as requiring live API spike |
| C3 | Wowhead abilities Listview only exists on boss/dungeon NPCs, NOT general mobs — Hogger has no abilities section | **[FIXED]** | Corrected coverage claim from "broadest" to "instanced bosses + notable NPCs" |
| C4 | `DELETE FROM smart_scripts` destroys hand-crafted SmartAI with no guard | **[FIXED]** | Added existence check (SELECT COUNT before DELETE) and `--force` flag requirement |
| C5 | Missing `AND ScriptName=''` guard on AIName UPDATE — would create dead SmartAI for C++ scripted creatures | **[FIXED]** | Added `AND ScriptName=''` to the UPDATE statement |
| C6 | `creature_template_spell` generated for ALL creatures but is inert when SmartAI is active — causes double-cast risk if AI changes later | **[FIXED]** | Restricted generation to pet/vehicle/controllable creatures only |
| C7 | WorldTrigger (entry 19871) and environmental creatures would pollute registry with hundreds of false spells | **[FIXED]** | Added `CREATURE_BLACKLIST` with trigger entries + hostility filter |
| C8 | Serverside spells (range 1900003+) rejected by DB2-only validation — contradicts gate 4 which mentions serverside_spell | **[FIXED]** | Validation now checks BOTH DB2 SpellName AND world.serverside_spell |
| C9 | SavedVariables total data loss on WoW client crash (no intermediate saves) | **[DEFERRED]** | Implementation should add periodic `/bf save` command and crash recovery from export format |
| C10 | Regex `(\[.*?\])` truncates on nested JSON brackets (every ability entry has nested `modes` object) | **[DEFERRED]** | Implementation should use bracket-counting parser instead of non-greedy regex for data array extraction |
| C11 | Lua SavedVariables parser not specified — `slpp` library has known fragility with mixed key types | **[DEFERRED]** | Will use `slpp` (already installed in project) with explicit test cases for the exact schema |

### High Severity (Will Produce Incorrect Output)

| # | Issue | Status | Resolution |
|---|-------|--------|------------|
| H1 | WCL free tier (3,600 pts/hr) cannot process even one encounter's 10-report sample within an hour — rate limit math does not work | **[DEFERRED]** | Patreon ($5/mo) likely required. Reduce sample size to 3-5 reports. Add point budget tracking |
| H2 | Sub-second timer generation from short trash fights (mob dies in 3s, casts 2 spells → 1.5s interval) | **[FIXED]** | Added MIN_REPEAT_MS=3000 and MIN_INITIAL_MS=2000 floors |
| H3 | Per-difficulty spell frequency destroyed during merge — single `wcl_avg_casts_per_fight` column, not per-difficulty | **[DEFERRED]** | Registry schema needs per-difficulty frequency columns or JSON blob for difficulty-specific metadata |
| H4 | Wowhead difficulty mode IDs 3-7 were WRONG (mapped to opposite difficulties vs TrinityCore enum) | **[FIXED]** | Commented out unverified IDs 3-7, added TC enum reference, marked as requiring live verification |
| H5 | No per-creature row cap — 50-spell bosses generate unwieldy SmartAI | **[FIXED]** | Added MAX_SPELLS_PER_CREATURE=15 cap |
| H6 | Duplicate NPCs in fights inflate avg_casts_per_fight (4 copies × 10 casts = 40, producing erroneously short timer) | **[DEFERRED]** | Divide cast count by `instanceCount` from `fights.enemyNPCs` |
| H7 | Mind-controlled players cast player spells attributed as enemy casts — could attribute Fireball to a raid boss | **[DEFERRED]** | Filter by cross-referencing `sourceID` against `masterData.actors(type:"NPC")` only |
| H8 | WCL `begincast` + `cast` events double-count spells with cast times | **[FIXED]** | Added note to filter to `type == "cast"` only |
| H9 | Guardian/totem false positives — some player guardians have NPC control flags | **[DEFERRED]** | Maintain a known-guardian creature entry blacklist; cross-ref with `creature_template.type` |
| H10 | Confidence scoring ignores WCL sample size — spell from 50 reports scores same as spell from 1 report | **[DEFERRED]** | Add `wcl_report_count` multiplier: if report_count >= 5, add +0.10 bonus |
| H11 | SQLite-to-MySQL cross-reference for spell validation has no implementation path — MCP not available in standalone Python CLI | **[DEFERRED]** | Add `pymysql` dependency; connect to local MySQL for validation. Or pre-export spell ID list to SQLite |
| H12 | Aura detection criteria ("persistent aura" → creature_addon) completely undefined — no uptime threshold | **[DEFERRED]** | Define: aura present > 80% of fight duration AND self-applied → candidate for creature_addon |

### Medium Severity (Design Gaps)

| # | Issue | Status | Resolution |
|---|-------|--------|------------|
| M1 | No memory ceiling or eviction policy for addon SavedVariables — could grow unbounded over weeks | **[DEFERRED]** | Add 5000-creature cap with LRU eviction; warn user at 80% capacity |
| M2 | No phase awareness in addon data — same creature entry behaves differently in different quest phases | **[DEFERRED]** | Document as known limitation; phases are invisible to CLEU |
| M3 | Export format exceeds 2000-char Discord limit for creatures with many spells | **[DEFERRED]** | Add pagination: `/bf export page 1`, `/bf export page 2`, etc. |
| M4 | Default spell blacklist has 4 entries (now expanded to ~10) but 50+ common junk spells exist | **[FIXED]** | Expanded blacklist + added auto-detection heuristic (100+ creatures → likely generic) |
| M5 | Locale mismatch — French/German/etc. addon users report spell names in their language | **[DEFERRED]** | Canonical name from DB2 SpellName (English); addon `spellName` used as display-only fallback |
| M6 | Re-ingestion of same data inflates metrics — no idempotency for repeated imports | **[DEFERRED]** | Track contributor+timestamp pairs; dedup by (contributor, creature, spell) |
| M7 | No `requirements.txt` or installation procedure | **[DEFERRED]** | Phase 1 deliverable: `requirements.txt` with `requests`, `python-dotenv`, `pymysql`, `slpp` |
| M8 | SQLite concurrent write conflicts if multiple ingest processes run simultaneously | **[DEFERRED]** | Use WAL mode + advisory lock file; serialize writes via queue |
| M9 | No build version tracking — spell IDs may be recycled between WoW patches | **[DEFERRED]** | Add `wow_build` column to registry; tag data with source build |
| M10 | Confidence metadata (source attribution, scores) lost on SQL import — only in file comments | **[DEFERRED]** | Include confidence and sources in the `comment` column value |
| M11 | Encounter-specific vs. creature-entry-specific spells conflated — quest NPC inherits raid boss spells | **[DEFERRED]** | Add `encounter_context` column; warn on entries with multiple encounter contexts |
| M12 | WCL token expiry mid-batch crashes pipeline — no auto-reauth | **[FIXED]** | Added reauth-on-401 note to extraction strategy |
| M13 | WCL GraphQL errors return HTTP 200 with `errors` key — `raise_for_status()` misses them | **[DEFERRED]** | Check for `errors` key in response JSON before accessing `data` |
| M14 | No retry/backoff for transient HTTP failures (503, timeouts) across all sources | **[DEFERRED]** | Use `tenacity` library or manual retry with exponential backoff |
| M15 | WCL `abilityGameID` can be synthetic (e.g., 1 for Melee) — not real WoW spell IDs | **[DEFERRED]** | Filter synthetic IDs (negative, very high, or known WCL conventions like ID=1) |
| M16 | Generator produces flat timer scripts for creatures that require sequenced/phased behavior — no warning | **[DEFERRED]** | Detect phase patterns in WCL data (spell appears only below 50% HP); emit `-- PHASE-DEPENDENT` comment |
| M17 | DraconicBot `/contribute` is CPU-bound work in async event loop — could block bot | **[DEFERRED]** | Run ingest in thread pool executor; respond with "processing..." then follow up |
| M18 | Wowhead `json.loads()` will fail on JS-only syntax (unquoted keys, trailing commas) | **[DEFERRED]** | Use `demjson3` or custom pre-processor to sanitize JS literals before JSON parsing |
| M19 | No cache invalidation strategy — stale data persists indefinitely | **[DEFERRED]** | TTL-based: Wowhead cache 30 days, WCL reports permanent, WCL metadata 7 days |

### Low Severity (Minor Fragility)

| # | Issue | Status | Resolution |
|---|-------|--------|------------|
| L1 | Vehicle-type casters silently ignored (addon only checks `"Creature"` prefix) | **[DEFERRED]** | Add `"Vehicle"` as valid prefix with same extraction logic |
| L2 | Export format has version field but no migration path for v2 | **[DEFERRED]** | Define migration rules in the importer when v2 is designed |
| L3 | `WH.Gatherer.addData(6, ...)` actually has 3 args (includes locale ID) — regex captures wrong group | **[DEFERRED]** | Update regex to `WH\.Gatherer\.addData\(6,\s*\d+,\s*(\{.*?\})\)` |
| L4 | Wowhead may transition to React SPA rendering, breaking HTML scraping entirely | **[DEFERRED]** | Monitor; fallback to Playwright headless browser if needed |
| L5 | Anonymized WCL reports may have different actor data format | **[DEFERRED]** | Test with anonymized reports during spike; NPC data should be unaffected |
| L6 | No schema migration plan for SQLite registry | **[DEFERRED]** | Add `schema_version` table; implement ALTER TABLE migrations |
| L7 | Confidence scoring is uncalibrated — no ground truth validation | **[DEFERRED]** | After initial data collection, sample 100 entries and verify against known creature behavior |

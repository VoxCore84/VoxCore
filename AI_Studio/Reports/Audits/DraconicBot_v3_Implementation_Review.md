# DraconicBot v3 — Implementation Review for Architect Audit

**Implementer**: Claude Code (Opus 4.6)
**Date**: 2026-03-12
**Spec**: `AI_Studio/1_Inbox/2026-03-12_DraconicBot_v3_Gemini_Architecture_Spec.md`
**Repo**: `C:\Users\atayl\draconic-bot\` (standalone, `VoxCore84/draconic-bot`)

---

## 1. Scope of implementation

This review covers the complete Phase 1 implementation of DraconicBot v3: the `ai/` package, knowledge base, cog upgrades, admin commands, eval dataset, and wiring changes. The bot is **not deployed** — `AI_ENABLED=false` by default.

### What was built

| Category | Files | Lines | Status |
|----------|-------|-------|--------|
| `ai/` package | 10 Python files | 1,380 | NEW |
| `knowledge/` base | 8 markdown + 1 JSON | 443 | NEW |
| `cogs/ai_admin.py` | 1 Python file | ~160 | NEW |
| Modified cogs | 5 Python files | 1,301 | UPGRADED |
| Eval dataset | 1 JSON file | 60 test cases | NEW |
| Config/wiring | 4 files | varied | MODIFIED |
| **Total** | **30 files** | **~3,300 lines new/modified** | |

### What was NOT built (per spec — Phases 2-5)

- Shadow mode logging without public responses
- Canary channel rollout
- Limited support rollout
- Full v3 cutover
- Bot token rotation
- GCP Vertex AI project setup

---

## 2. File-by-file review

### 2.1 `ai/schemas.py` — Data models

Defines all dataclasses and enums used across the AI pipeline.

**Enums:**
- `RouteType`: FAQ, TROUBLESHOOT, FRUSTRATION, GM_KB, LOG_SUMMARY, HANDOFF
- `ModelTier`: FLASH_LITE, FLASH, PRO

**Dataclasses:**
- `AIResult` — the main response object returned by the provider and validated by safety
- `CostEstimate`, `ProviderHealth` — provider metadata
- `KBSnippet` — a selected knowledge section with file_key, title, content, tags
- `ConversationTurn` — a single turn in a session
- `MetricsEntry` — structured log entry for JSONL + SQLite

**Review notes:**
- All fields have sensible defaults
- Uses `from __future__ import annotations` for forward refs
- `AIResult.error` is `str | None` — matches the spec's error handling pattern
- No Pydantic dependency — pure dataclasses. Keeps dependencies minimal

**Potential concern:** `RouteType(parsed.get("route", ...))` in provider.py could raise `ValueError` if Gemini returns an unexpected route string. This is caught by the try/except in the JSON parsing block, but worth noting.

---

### 2.2 `ai/settings.py` — Configuration

Loads all AI-related env vars. Uses helper functions `_float_env`, `_bool_env`, `_list_env` for type coercion.

**Key settings:**
- `AI_ENABLED = false` by default
- 3 model names configurable via env
- Channel allowlists parsed from comma-separated IDs
- Cost caps: $1.50/day hard, $20/month soft
- Rate limits: 90s/channel, 2/5min/user, 30min frustration, 5/hr pro
- Token budgets per route (matching spec exactly)
- Paths for KB dir, log dir, metrics DB

**Review notes:**
- Imports `_int_env` from `config.py` — reuses existing pattern, good
- All values match the spec's Section 10 and Section 16
- `TOKEN_BUDGETS` dict keys match `RouteType.value` strings — verified

**Potential concern:** Settings are loaded at import time (module-level). If `.env` changes at runtime, a bot restart is needed. This is intentional and matches spec (no hot-reload of env vars, only KB reload).

---

### 2.3 `ai/provider.py` — LLM abstraction + Gemini implementation

**`LLMProvider` ABC:**
- `generate()` — main generation call
- `estimate_cost()` — token-to-USD calculation
- `healthcheck()` — liveness probe

**`GeminiProvider`:**
- Lazy client initialization (`_get_client()` creates `genai.Client()` on first call)
- Uses `google.genai.types.GenerateContentConfig` with:
  - `system_instruction` for system prompt
  - `response_mime_type="application/json"` — forces structured JSON output
  - `temperature=0.3` — low creativity, factual answers
  - `max_output_tokens` — per-route from settings
- Wraps the sync SDK call in `asyncio.to_thread()` + `asyncio.wait_for()` for timeout
- Parses structured JSON response; falls back to raw text if JSON parse fails (confidence 0.5)
- Returns `AIResult` with all metadata (tokens, latency, model used)

**Pricing table:**
```
gemini-2.5-flash-lite: $0.075/M input, $0.30/M output
gemini-2.5-flash:      $0.15/M input,  $0.60/M output
gemini-2.5-pro:        $1.25/M input,  $10.00/M output
```

**Review notes:**
- No XAI/Grok provider — removed per user directive. The ABC is still there for future extensibility
- `asyncio.to_thread` is correct for wrapping the sync `google-genai` SDK in an async bot
- Timeout is configurable (default 20s)
- Error handling returns a well-formed `AIResult` with `error` field set — callers don't need to handle exceptions

**Potential concerns:**
1. **JSON parse fallback**: If Gemini returns invalid JSON, the raw text is used as-is with confidence 0.5. This bypasses KB evidence checks in `safety.py`. The safety layer will catch this (no `used_kb_sections` = handoff for KB-backed routes), but worth verifying in testing.
2. **`response_mime_type="application/json"`**: This is a Gemini-specific feature. If the model doesn't support it for a given tier, it may behave unexpectedly. Flash-Lite support should be verified.
3. **Thread safety**: `_get_client()` is not thread-safe. In a discord.py async context this should be fine (single event loop), but worth noting.
4. **`usage_metadata.candidates_token_count`**: This attribute name should be verified against the current `google-genai` SDK. It may be `candidates_token_count` or `completion_token_count` depending on SDK version.

---

### 2.4 `ai/metrics.py` — JSONL + SQLite logging

**JSONL logging:** Appends one JSON object per AI request to `logs/gemini_calls.jsonl`. Fields match spec Section 13.1 exactly.

**SQLite:** `data/ai_metrics.db` with `ai_requests` table. Index on `date` for daily rollup queries.

**Query methods:**
- `get_daily_spend()` — SUM of estimated_cost_usd for a date
- `get_monthly_spend()` — SUM with LIKE prefix match
- `get_daily_pro_count()` — COUNT where model LIKE '%pro%'
- `get_stats_24h()` — aggregated stats (requests, spend, avg latency, errors, fallbacks, handoffs)
- `get_stats_30d()` — 30-day aggregation
- `get_route_breakdown()` — COUNT grouped by route for today

**Review notes:**
- User IDs are hashed (SHA256, truncated to 16 chars) per spec privacy rules
- SQLite is single-connection, created in `__init__`. Fine for a single-process bot
- `_estimate_cost` imports `_PRICING` from `provider.py` — circular import risk? No, because it's a runtime import inside a method, not top-level

**Potential concerns:**
1. **SQLite in async context**: `self._db.execute()` is synchronous. For low-volume bots this is fine, but at scale it could block the event loop. A proper fix would use `aiosqlite`, but that's an additional dependency. Acceptable for v1 given the community size.
2. **`get_stats_24h()` uses date string, not actual 24h window**: It queries today's date, not the last 24 hours. Minor inaccuracy for the `/ai_stats` display — stats reset at midnight UTC.

---

### 2.5 `ai/kb.py` — Knowledge base

**Loading:**
- Reads all `*.md` files from `knowledge/` directory
- Parses `kb_manifest.json` for tags per file
- Also extracts inline `Tags:` headers from markdown content
- Deduplicates tags

**Retrieval (`select_snippets`):**
- Scores each section: tag match = 3 points, content match = 1 point
- Sorts by score descending
- Selects top N snippets within a character budget (rough: 4 chars/token)

**Keyword extraction (`extract_keywords`):**
- Strips stop words (70+ English stop words)
- Filters to words >= 3 chars
- Caps at 15 keywords

**Review notes:**
- "Intentionally boring" retrieval as spec requested — no vector DB, no embeddings
- Tag-based scoring is heavily weighted (3:1) — this is good, ensures tagged content rises to the top
- Character budget estimation (4 chars/token) is a rough heuristic — Gemini's actual tokenization varies, but this is a safe conservative estimate

**Potential concerns:**
1. **No caching**: KB files are re-read from disk on every `load()` call. Fine for manual `/ai_reload_kb`, but the initial load at startup reads all files synchronously. With 8 small files this is negligible.
2. **Keyword extraction stop words are English-only**: The community is English, so this is fine.
3. **KB snippet injection could be large**: If all 8 files match with high scores, the 4-snippet cap and character budget should prevent prompt bloat, but worth testing with real queries.

---

### 2.6 `ai/safety.py` — Safety rails

**Content boundaries:** 7 regex patterns covering TOS, piracy, cheating, self-harm, legal, medical, credential sharing. Returns a flag string if matched.

**Response validation (`validate_response`):**
1. Safety flags present -> immediate handoff
2. Confidence < 0.70 -> handoff (or ask clarifying question if one exists)
3. Confidence 0.70-0.84 -> add uncertainty qualifier if not already present
4. KB evidence check -> KB-backed routes with no `used_kb_sections` -> handoff
5. Output budget check -> truncate if >20% over budget
6. Follow-up question count -> keep only first question if multiple

**Review notes:**
- All confidence thresholds match spec Section 10.5 exactly
- KB evidence check matches spec Section 10.6 (hallucination guard)
- Truncation preserves last complete line (`rsplit("\n", 1)[0]`)
- `HANDOFF_MESSAGE` and `OUTAGE_MESSAGE` are importable constants

**Potential concerns:**
1. **Content boundary regex could false-positive**: "password" + "share" triggers the credential pattern. A message like "can you share what the default password is?" would be blocked. This is conservative (safe side), but may need tuning.
2. **Uncertainty qualifier injection**: The code prepends italicized text to the answer. If Gemini's response starts with markdown (e.g., bold header), the injected text might look awkward visually. Minor cosmetic issue.

---

### 2.7 `ai/sessions.py` — Conversation memory

- `ConversationSession`: Rolling window of last 6 turns, 30-min TTL
- `SessionManager`: In-memory dict keyed by `thread_id` or `channel_id:user_id`
- Expired sessions pruned on access

**Review notes:**
- Matches spec Section 9.5 exactly (6 turns, 30 min TTL, scope key logic)
- No persistence across bot restarts — intentional for v1
- Memory is only populated when user replies to bot or is in a bot thread — prevents context leakage from unrelated messages

**Potential concern:** Session data is not bounded by total count. If hundreds of users interact simultaneously, memory could grow. The TTL pruning on every `get_or_create()` call mitigates this, but there's no hard cap on total sessions.

---

### 2.8 `ai/prompts.py` — Prompt engineering

**Base system prompt** includes:
- Server facts (DraconicWoW, TrinityCore 12.x, Midnight, roleplay-focused)
- Job description, tone guidelines, hard rules
- Response format rules (Discord markdown, bullets, 1-4 paragraphs)
- KB snippet injection point
- Conversation context injection point
- JSON output schema

**Route overlays** (5 routes):
- FAQ: shortest correct answer
- Troubleshoot: most likely cause + 2-4 checks + one question
- Frustration: one sentence acknowledgment + fix
- GM KB: answer only from KB, hand off if uncertain
- Log summary: summarize parsed findings, don't pretend to see raw data

**Review notes:**
- Prompt matches spec Section 7 almost verbatim
- Route overlays match spec Section 8
- `{kb_snippets}` and `{conversation_context}` are Python format string placeholders — these are filled at runtime by `build_system_prompt()`
- JSON output schema in the prompt is minimal but clear

**Potential concerns:**
1. **Prompt length**: With KB snippets injected, the full system prompt could be 2000-4000 tokens. This is within Flash-Lite's context window but should be monitored via metrics.
2. **No response schema enforcement beyond `response_mime_type`**: Gemini's JSON mode doesn't guarantee schema compliance. The provider already handles this with a JSON parse fallback, but malformed fields (e.g., `confidence` as a string) could cause issues. The `float()` and `bool()` casts in provider.py handle this.

---

### 2.9 `ai/router.py` — Central orchestrator

This is the largest and most critical file. It ties everything together.

**Question detection heuristics (`_looks_like_question`):**
- Scores 0-5 based on: `?` present, question words, setup keywords, minimum length, starts with question word
- Threshold: score >= 2 to qualify (spec Section 9.3 says "at least two of these")

**Route classification (`_detect_route_type`):**
- Frustration detected first (regex match)
- GM KB detected by keyword presence (dot commands, "gm command", etc.)
- Troubleshoot detected by signal count >= 2 ("tried", "already", "still", etc.)
- Default: FAQ

**Model tier selection (`_select_model_tier`):**
- FAQ / GM_KB -> Flash-Lite
- Troubleshoot / Frustration / Log Summary -> Flash
- Pro never auto-selected (only via explicit escalation or admin test)

**`handle_message()` flow:**
1. Check `enabled` flag
2. Check daily budget
3. Check channel allowlist
4. Check message length (>= 10 chars)
5. Detect mention/reply/thread context
6. For organic messages: require question score >= 2
7. Check content boundaries
8. Check rate limits
9. Detect route type + model tier
10. Pro downgrade check
11. KB retrieval (keywords -> snippets)
12. Session context (only for replies/threads)
13. Build system prompt
14. Call provider
15. Validate response (safety.py)
16. Update session
17. Log metrics
18. Update rate limit timestamps
19. Return result

**`handle_admin_test()`:**
- Bypasses rate limits, channel checks, and session management
- Used by `/ai_test` and by cogs that want to do one-off AI calls (e.g., log_parser, troubleshooter modal)

**Review notes:**
- The flow matches the spec's Section 4 architecture diagram faithfully
- Rate limiting is comprehensive (channel, user, frustration, pro)
- Budget check calls SQLite on every message — for low-volume this is fine
- `is_reply_to_bot` correctly checks `message.reference.resolved` to verify the referenced message was from the bot

**Potential concerns:**
1. **`handle_admin_test` is used by non-admin cogs**: `sme_kb.py` and `log_parser.py` call `handle_admin_test` for AI generation. This bypasses rate limits, which is intentional for these structured slash commands, but the name is misleading. Consider renaming to `generate_direct()` or similar.
2. **Thread detection logic**: `is_in_bot_thread` is `True` for ALL threads, not just bot-initiated ones. The spec says "inside a support thread involving the bot" — this implementation is more permissive. A stricter check would verify the thread creator or that the bot has posted in the thread.
3. **Rate limits are in-memory**: They reset on bot restart. Not a problem for the cooldowns (conservative), but the daily budget check is SQLite-backed and persists correctly.
4. **Budget check on every message**: `metrics.get_daily_spend()` queries SQLite synchronously. At high volume this could be a bottleneck. For the expected community size (<500 questions/day) this is fine.

---

### 2.10 Cog upgrades

#### `cogs/faq.py` (UPGRADED)

**AI path**: Tries `router.handle_message()` first. If AI returns a good result (answer + not needs_staff), sends it as an embed. If AI says handoff, sends handoff message. If AI fails or is disabled, falls through to static path.

**Static fallback**: Identical to v2.3 behavior — regex matching, cooldowns, response_pool combinator, "Still stuck?" button.

**Review notes:**
- Clean separation between AI and static paths
- Stats tracking includes "ai_response" key for AI-powered answers
- The `on_message` listener processes AI before static — if AI responds, static never fires
- The static path retains thread/reply exclusion and question signal checks

**Potential concern:** The AI path doesn't check `isinstance(message.channel, discord.Thread)` or `message.reference` — the router handles that. But there's a subtle ordering issue: the FAQ cog's `on_message` runs, hits the AI path (which does its own eligibility checks and may return None), then falls through to the static path (which has its OWN eligibility checks). This means a message could fail AI eligibility but pass static eligibility and get a static response. This is actually correct behavior (static fallback), but worth noting.

#### `cogs/frustration.py` (UPGRADED)

**AI path**: Calls `router.handle_message()` with `force_route=RouteType.FRUSTRATION`. Uses AI-generated empathetic response. Falls back to `random.choice(_EMPATHY_OPENERS)` if AI fails.

**Review notes:**
- Detection stays local (regex) — AI only generates the response text
- DM guide button preserved in both paths
- Cooldowns still enforced before AI call (good — prevents unnecessary API calls)

#### `cogs/troubleshooter.py` (UPGRADED)

**Addition**: New "Describe my problem (AI)" button on the root `/troubleshoot` view. Opens a `discord.ui.Modal` for freeform text input. Sends to `router.handle_admin_test()` with `RouteType.TROUBLESHOOT`.

**Static decision tree**: Completely preserved. No changes to tree structure or button behavior.

**Review notes:**
- AI button only shows if `ai_router` exists and is enabled
- Modal has 1000-char limit — reasonable for a problem description
- Uses `handle_admin_test()` because there's no `discord.Message` object to pass to `handle_message()`

**Potential concern:** The modal response is ephemeral — only the user sees it. This is good for privacy but means no public troubleshooting context for other users to learn from. The spec doesn't specify, so this is a reasonable default.

#### `cogs/sme_kb.py` (UPGRADED)

**AI path**: Defers interaction, calls `router.handle_admin_test()` with `RouteType.GM_KB`. If confidence >= 0.70, sends AI answer. Falls back to static JSON search.

**Review notes:**
- Adds uncertainty footer for confidence 0.70-0.84
- Static fallback unchanged — still searches `gm_commands.json` by string match
- Uses `interaction.response.defer()` before AI call — correct, since AI may take seconds

#### `cogs/log_parser.py` (ENHANCED)

**Addition**: After local pattern matching (unchanged), optionally calls AI for a richer summary if the router is enabled.

- For config files: sends found errors + first 2000 chars of config to AI
- For log files: sends found patterns + last 2000 chars of raw log to AI
- If no patterns matched but AI is enabled: tries a general AI summary of the last 3000 chars

**Review notes:**
- Local parsing ALWAYS runs first — AI is additive, never replaces
- Raw file content is truncated before sending to AI (2000-3000 chars) — prevents prompt bloat
- Falls back gracefully to existing behavior (checkmark/eyes reaction) if AI is off

---

### 2.11 `cogs/ai_admin.py` — Admin commands

5 new slash commands, all `manage_guild` permission-gated:

| Command | Description |
|---------|-------------|
| `/ai_status` | Provider health, spend, KB count, session count |
| `/ai_stats` | 24h + 30d usage, route breakdown |
| `/ai_toggle on\|off` | Emergency kill switch |
| `/ai_reload_kb` | Reload knowledge markdown without restart |
| `/ai_test route text` | Smoke test — shows full AI result with metadata |

**Review notes:**
- All responses are ephemeral (admin-only visibility)
- `/ai_test` defers before the AI call — correct for potentially slow responses
- Route validation uses `RouteType(route)` with a try/except for user-friendly error messages
- Gets router via `getattr(self.bot, "ai_router", None)` — graceful if AI not initialized

---

### 2.12 `bot.py` — Wiring changes

- Version bumped to `3.0.0`
- `ai_router` attribute initialized in `setup_hook()` via `_init_ai_router()`
- `cogs.ai_admin` added to COGS list
- Presence status shows "AI enabled" or "AI disabled"
- Config validation warns if `AI_ALLOWED_CHANNEL_IDS` is empty when AI is on

**Review notes:**
- AI initialization is try/except wrapped — bot runs as v2.3 if AI setup fails
- Router is a bot attribute (`self.ai_router`) accessible by all cogs via `getattr(self.bot, "ai_router", None)`

---

### 2.13 Knowledge base files

8 markdown files following the spec's KB authoring structure (Title, Tags, Last reviewed, Owner, Facts, Common symptoms, Fix steps, Escalate when).

**Coverage:**
- Bot identity and commands
- Server/stack basics
- Client build mismatches (WOW51900319)
- Setup and connection (10-step guide)
- Common failures (7 categories)
- Custom features (transmog, companions, etc.)
- GM commands (8 categories, 16+ commands)
- Staff handoff rules (9 escalation conditions)

**`kb_manifest.json`:** Maps 8 file keys to tag arrays. Total: 71 unique tags across all files.

**Review notes:**
- All files have `Tags:` inline headers that match the manifest
- Content is factually accurate for TrinityCore 12.x / DraconicWoW
- Handoff rules file explicitly says "never promise staff response timeframe" — good

---

### 2.14 Eval dataset

60 test cases in `data/ai_eval_cases.json`:
- 20 FAQ (setup, connection, build, mysql, extractors, arctium, flying, accounts, SQL, config, repack, client)
- 10 Frustration (varied emotional patterns)
- 10 Troubleshoot (multi-step diagnostic scenarios with "I already tried")
- 10 GM KB (command lookups, permission questions)
- 5 Log/config summary (config review, log error interpretation)
- 5 Handoff/refusal (piracy, exploits, credentials, emotional support, account recovery)

Each case has: `id`, `input`, `expected_route`, `expected_tier`, `required_facts`, `forbidden_facts`, `expect_handoff`.

**Review notes:**
- Good coverage across all routes
- Forbidden facts in handoff cases prevent the bot from revealing exploits or secrets
- Frustration cases don't include "RTFM" or "just google it" as forbidden — good, prevents dismissive responses

---

### 2.15 Config changes

**`requirements.txt`**: Added `google-genai>=1.0.0` (the only new dependency)

**`.env.example`**: Added 15 AI-specific env vars with comments explaining each. Organized into sections (Google/Vertex, model selection, channels, cost caps, timeouts, session, logging, pro escalation).

**`.gitignore`**: Added `data/ai_metrics.db` (runtime SQLite)

---

## 3. Spec compliance matrix

| Spec Section | Requirement | Status | Notes |
|---|---|---|---|
| 1 | Executive decisions (10 questions) | COMPLIANT | All 10 decisions implemented as specified |
| 2 | Goals and non-goals | COMPLIANT | No autonomous agent, no multi-step tool use, no RAG |
| 3 | 3-tier model policy | COMPLIANT | Flash-Lite / Flash / Pro with env-configurable model names |
| 4 | Architecture diagram | COMPLIANT | Static Command Layer and Message Event Router both implemented |
| 5 | File structure | MOSTLY COMPLIANT | Files are in `ai/` and `knowledge/` as specified. Minor path difference: spec said `tools\discord_bot\ai\`, implementation uses repo root `ai/` |
| 6 | Core design decisions | COMPLIANT | Provider ABC, google-genai SDK, structured JSON output, light retrieval |
| 7 | System prompt template | COMPLIANT | Nearly verbatim from spec |
| 8 | Route overlays | COMPLIANT | All 5 route overlays implemented |
| 9 | Message routing logic | COMPLIANT | Channel allowlist, trigger conditions, question heuristics, conversation memory |
| 10 | Safety rails | COMPLIANT | Rate limits, token budgets, cost caps, content boundaries, confidence gates |
| 11 | Cog upgrade plan | COMPLIANT | All 5 cogs upgraded as specified; 11 cogs kept static; response_pool retained for fallback |
| 12 | KB maintenance model | COMPLIANT | Manual markdown, `/ai_reload_kb` command |
| 13 | Monitoring | COMPLIANT | JSONL + SQLite + 5 admin commands |
| 14 | Fallback behavior | COMPLIANT | Static FAQ fallback on AI failure, handoff on low confidence, budget cap disable |
| 15 | Deployment plan | PHASE 1 ONLY | Foundation built; phases 2-5 (shadow/canary/rollout) not yet implemented |
| 16 | Environment/config | COMPLIANT | All env vars documented in .env.example |
| 17 | Cost projection | N/A | Pricing table in provider.py matches spec |
| 18 | Testing plan | PARTIAL | Eval dataset created (60 cases); unit tests and shadow mode QA not yet implemented |
| 19 | Implementation order | COMPLIANT | Steps 1-17 complete. Steps 18-20 are deployment phases |
| User amendment | No Grok/XAI provider | COMPLIANT | Only GeminiProvider. LLMProvider ABC retained for future extensibility |

---

## 4. Known issues and open questions for the Architect

### Design questions

1. **`handle_admin_test()` naming**: This method is called by non-admin cogs (sme_kb, log_parser, troubleshooter modal) for direct AI generation without rate limits. Should it be renamed to `generate_direct()` to avoid confusion?

2. **Thread detection permissiveness**: All Discord threads are treated as bot-relevant threads. The spec says "support thread involving the bot." Should we add a check for bot participation in the thread?

3. **FAQ cog dual-path flow**: When AI is enabled but returns `None` (rate limited, budget exhausted, etc.), the static path fires as fallback. This means the same message could be rate-limited by AI but still get a static response. Is this the intended fallback behavior, or should AI rate limiting also suppress static responses?

4. **Conversation context in static-routed cogs**: The troubleshooter modal and sme_kb slash command use `handle_admin_test()` which has no session/conversation support. If a user asks a follow-up after receiving a slash command response, there's no memory. Should these routes support sessions?

### Implementation gaps

5. **Unit tests**: Not written. Spec Section 18.1 lists 9 test categories. These should be implemented before shadow mode (Phase 2).

6. **Admin alerting on budget thresholds**: Spec says "at 75% of daily cap: admin Discord alert." The current implementation logs a warning but doesn't send a Discord message. Should we add a `send_admin_alert()` mechanism?

7. **SDK attribute names**: `response.usage_metadata.candidates_token_count` — the exact attribute name should be verified against the installed `google-genai` SDK version. It might be `completion_token_count` in newer versions.

8. **Content boundary false positives**: The "password" + "share" regex could block legitimate questions like "what's the default database password?" This is conservative (safe) but may need tuning after canary testing.

### Operational pre-requisites (before any deployment)

9. **Rotate Discord bot token** — old one exposed in session 152
10. **Create/verify GCP project** with Vertex AI enabled and billing attached to $300 credit pool
11. **Generate service account JSON** and set `GOOGLE_APPLICATION_CREDENTIALS` in `.env`
12. **Set channel IDs** in `AI_ALLOWED_CHANNEL_IDS` and `AI_TEST_CHANNEL_IDS`
13. **Install dependency**: `pip install google-genai` in the bot's Python environment

---

## 5. Rollback safety

At any point, setting `AI_ENABLED=false` in `.env` and restarting the bot returns it to v2.3 behavior:
- All static cogs continue functioning
- AI admin commands report "AI router not initialized"
- No Gemini API calls are made
- No code changes required

This was a hard requirement from the spec and is verified.

---

## 6. Request for Architect

Please review:
1. The design questions in Section 4 (#1-4)
2. Whether the implementation gaps (#5-8) should be addressed before Phase 2
3. Whether the `ai/provider.py` Gemini SDK usage pattern is correct for the `google-genai` library
4. Whether the system prompt and route overlays need tuning before canary testing
5. Any security concerns with the content boundary patterns or the structured JSON output approach
6. Overall architecture — does this match your intent from the spec?

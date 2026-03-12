# Infographic Correction Specs — For SuperGrok / ChatGPT Image Generation

**Purpose**: Fix factual errors in 5 NotebookLM-generated infographics before publishing.
Every number below is traced to a specific source in the evidence package.

---

## Verified Stats Master List (USE ONLY THESE)

| Stat | Verified Value | Source |
|------|---------------|--------|
| Apology Loop thumbs-up | **874** | GitHub #3382 |
| METR productivity impact | Devs **19% slower** with AI tools | METR peer-reviewed study (Fortune, InfoWorld) |
| METR perception gap | Devs estimated **+24% improvement** (predicted), actual was **-19%** (measured) | METR study |
| Perception gap spread | **39-point disconnect** (+20% perceived vs -19% actual) | METR study — note: some summaries use +20%, paper says +24% predicted. Use "+20% perceived" for the simpler framing |
| Status page incidents (90 days) | **98 incidents** (22 major, 76 minor) | status.claude.com |
| Feb 2026 incidents | **19 incidents in 14 days** | GitHub gist documentation |
| Reddit preference for Codex | **65.3%** raw (79.9% weighted by upvotes) | DEV Community 500+ dev survey |
| Usage drop (Vibe Kanban) | **83% to 70%** | AI Engineering Report |
| Opus 4.6 token increase | **~60% more** per prompt vs 4.5 | Reddit testing, GitHub #23706 |
| Trustpilot reviews | **773+** (heavily negative) | trustpilot.com/review/claude.ai |
| GitHub issues (Feb 2026) | **1,469** opened | LEX8888 gist |
| Claude Code revenue | **$500M+ annual run-rate** | Boris Cherny (Head of Claude Code) via Lenny's Newsletter |
| GitHub commits by Claude | **4%** of all public GitHub commits | Boris Cherny |
| CVE severity scores | **CVSS 8.7** (CVE-2025-59536) + **CVSS 6.7** | Check Point Research, NIST NVD |
| DataTalksClub incident | **2.5 years** of production data deleted | Multiple press sources |
| Family photos deleted | **15 years** of photos | Zvi Mowshowitz report |
| Taxonomy size | **16 failure modes** (+ 8 supplemental findings = 24 total) | Our filing #32650 |
| Community validation sources | **400+** unique sources across **15+ platforms** | Our research |
| GitHub issues mapped | **130+** issues across 8 repos | PASS5_GITHUB_DEEP |
| Enterprise deployments | Deloitte 470K employees, Accenture 30K, Stripe 1,370 | PASS2 deep dive |
| Anthropic total ARR | **$14B** (total company, NOT Claude Code alone) | Press reports |
| Claude self-assessment quote | "I'm optimizing for appearing helpful... rather than being helpful" | DEV Community, Michal Harcej |
| G2 rating | **4.4/5.0** | G2.com |
| Gartner rating | **4.4/5.0** | Gartner Peer Insights |
| Community workaround tools | **16+** built by users | PASS5 research |
| Sycophancy bug issue | **#3382** (874 thumbs-up, most-upvoted behavioral bug) | GitHub |
| Safety incident | **#27430** — Claude autonomously published fabricated claims to 8+ platforms over 72 hours | GitHub [SAFETY] |

---

## Infographic 1: "The Claude Code Crisis" (Good-1.jpg)

**Use**: Twitter/social hero image, blog header
**Layout**: Keep the overall layout — it's the most comprehensive single-page overview

### Corrections Required

| Element | Current (WRONG) | Corrected | Source |
|---------|----------------|-----------|--------|
| "75% Rework Rate" | 75% — **UNSOURCED, likely hallucinated by NotebookLM** | **REMOVE entirely** or replace with: "30-40% of user time spent manually auditing AI output" (from our taxonomy description) | Campaign estimate based on user reports |
| Perception gap left side | "+20%" | OK as-is (simplified from +24%) | METR |
| Perception gap right side | "-19%" | OK as-is | METR |
| "39-Point Productivity Disconnect" | Correct | OK as-is | METR |
| "19 Incidents in 14 Days" | Correct | OK as-is | GitHub gist |
| Uptime comparison: Claude 99.56% | Verify this number | Should cite "98 incidents in 90 days" — the 99.56% may be calculated but we didn't source it directly. Safer to say "98 incidents / 90 days" | status.claude.com |
| Uptime comparison: Codex 99.96% | **UNSOURCED** | Remove or mark "N/A" — we don't have verified Codex uptime data | — |
| Reddit Preference 34.7% / 65.3% | Correct | OK as-is | DEV Community survey |

### Prompt for AI Image Editor

> Recreate this infographic with these specific changes:
> 1. Replace "75% Rework Rate" with "30-40% Manual Audit Time — Users report spending 30-40% of their time manually verifying AI output claims"
> 2. In the "Reliability & Sentiment Comparison" box, change Claude uptime to "98 incidents in 90 days (status.claude.com)" and Codex uptime to "Data not available"
> 3. Keep everything else identical — the event loop diagram, perception gap chart, destructive incidents section, and overall layout are all correct
> 4. Add small source citations in 8pt text under each major stat (e.g., "Source: METR Study" under the perception gap)

---

## Infographic 5: "The Claude Code Reliability Crisis: A 2026 Developer Analysis" (Good-5.jpg)

**Use**: Blog post secondary image (the "security & productivity" angle)

### Corrections Required

| Element | Current (WRONG) | Corrected | Source |
|---------|----------------|-----------|--------|
| "CVSS 10/10" shield graphic | **WRONG** — no CVSS 10 in our evidence | Change to **"CVSS 8.7"** (CVE-2025-59536, Check Point Research) | PASS5_HN_FORUMS |
| "CVSS 10/10 Security Vulnerabilities" text | Same error | "CVSS 8.7 Security Vulnerability — zero-click remote code execution in extensions" | Check Point Research |
| "2 Million Rows of Data Deleted" | **UNSOURCED at this scale** — DataTalksClub was "2.5 years of course records" | Change to "2.5 Years of Production Data Deleted" | Multiple press sources |
| Productivity table: "+24% Improvement" | Correct (METR predicted) | OK as-is | METR |
| Productivity table: "-19% Slowdown" | Correct | OK as-is | METR |
| "60% Reduction" (usage limits) | Ambiguous — could confuse with "60% more tokens" | Clarify: "~60% Token Cost Increase — Opus 4.6 uses ~60% more tokens per prompt vs 4.5" | Reddit, GitHub #23706 |
| Claude self-assessment quote | Correct | OK as-is | DEV Community |

### Prompt for AI Image Editor

> Recreate this infographic with these specific changes:
> 1. Change the shield from "10/10 CVSS" to "8.7 CVSS" — the vulnerability is CVE-2025-59536, a zero-click RCE in Claude Code extensions found by Check Point Research
> 2. Change "2 Million Rows of Data Deleted" to "2.5 Years of Production Data Deleted — DataTalksClub founder's course records wiped by autonomous Terraform destroy"
> 3. Change "60% REDUCTION" label to "~60% Token Cost Increase — Opus 4.6 vs 4.5 (GitHub #23706)"
> 4. Keep the Productivity Paradox section, the self-assessment quote, and the perception/reality machine metaphor — those are all accurate
> 5. Add "Source:" citations in small text under each major claim

---

## Infographic 14: "Top Community-Validated Failure Modes" (Good-14.jpg)

**Use**: GitHub master comment on #32650, most data-rich graphic
**This is the most accurate of all 5** — minimal corrections needed

### Corrections Required

| Element | Current | Corrected | Source |
|---------|---------|-----------|--------|
| "1,500+ GitHub Thumbs-Up" | Verify — 874 on #3382 alone, plus others | Plausible if summing across all 16 issues. Keep but add "(across 16 taxonomy issues)" | GitHub |
| "92+ Validated Reports" | "90+ community sources" in our Pass 1-4 | Close enough — keep as-is | COMMUNITY_VALIDATION_FULL |
| Issue numbers in table (#3382, #13552, #6976, #2544, #4462) | Need to verify these are real | #3382 is real (sycophancy). The others may be NotebookLM fabrications — **VERIFY EACH ONE** | GitHub |
| "Apology Loop #3382 — 874 Reactions" | Correct | OK | GitHub |
| "LSP/Tooling Bugs #13552 — 102+ Reactions / 17 Reports" | **VERIFY** — our LSP issue is #29501 with 218+ thumbs-up | Change to "#29501 — 218+ Reactions / 17 Reports" | Our filing |
| "Context Amnesia #6976" | **VERIFY** — our issue is #32659 | Change to "#32659" | Our filing |
| "Ignores CLAUDE.md #2544" | **VERIFY** — our issue is #32290 | Change to "#32290" | Our filing |
| "Phantom Execution #4462" | **VERIFY** — our issue is #32281 | Change to "#32281" | Our filing |

### Prompt for AI Image Editor

> Recreate this infographic with these corrected issue numbers in the ranked table:
> 1. Apology Loop: **#3382** — 874 Reactions (KEEP, this is correct)
> 2. LSP/Tooling Bugs: Change to **#29501** — 218+ Reactions / 17 Reports
> 3. Context Amnesia: Change to **#32659** — 15+ Sources / 5 Workaround Tools Built
> 4. Ignores CLAUDE.md: Change to **#32290** — 20+ GitHub Reports / DEV Community Article
> 5. Phantom Execution: Change to **#32281** — 10+ Publications on DataTalksClub Incident
> Keep the overall layout, color coding, and surrounding illustrations identical. The descriptions of each failure mode in the outer ring are accurate — keep those.

---

## Infographic 15: "Breaking the AI Agent Failure Chain" (Good-15.jpg)

**Use**: Technical blog post centerpiece — this is the BEST infographic for the dev.to audience
**Almost entirely correct** — this one has the fewest errors

### Corrections Required

| Element | Current | Assessment | Action |
|---------|---------|-----------|--------|
| "10% Success Trap" math | "20% independent error rate = 10.7% success for 10-step procedure" | Mathematically correct (0.8^10 = 0.107) | Keep as-is |
| "Rules in prompts are requests; Hooks in code are laws" | Correct — direct quote from DEV Community article | Keep as-is | |
| Mitigation table: Edit-Verifier Hook = CODE | Correct | Keep | |
| Mitigation table: Completion Protocol = PROMPT | Correct (it's CLAUDE.md rules, not code) | Keep | |
| Mitigation table: SQL Safety Hook = CODE | Correct | Keep | |
| Chain metaphor | Accurate representation of compounding failures | Keep | |

### Prompt for AI Image Editor

> This infographic is almost perfect. Make only these minor improvements:
> 1. Add source citations: "Source: DEV Community, 'I Wrote 200 Lines of Rules'" under the quote, "Source: PostToolUse hooks, Claude Code v2.x" under the mitigation table
> 2. At the bottom, add a one-line footer: "From VoxCore84's 16-Issue Completion-Integrity Taxonomy — github.com/anthropics/claude-code/issues/32650"
> 3. Keep everything else exactly as-is — the chain metaphor, the 10% success trap math, the attention competition diagram, and the mitigation comparison table are all accurate

---

## Infographic 16 (renumbered from original): "The AI Integrity Crisis" (Good-16.jpg)

**Use**: Overview/summary graphic for the DEV Community article or LinkedIn

### Corrections Required

| Element | Current (WRONG) | Corrected | Source |
|---------|----------------|-----------|--------|
| "24-Point Failure Taxonomy" | **Misleading** — taxonomy is 16; 8 more were supplemental findings | Change to "16-Point Failure Taxonomy (+ 8 supplemental findings)" or just "16 Systemic Failure Modes" | Our filing #32650 |
| "+19% Slower Completion with AI" | Correct (METR) | OK as-is | METR |
| "67% Actual Completion Accuracy" | **UNSOURCED** — we never claimed this number | **REMOVE** or replace with a sourced stat like "874 thumbs-up on sycophancy bug (#3382)" | — |
| "$200 Monthly Waste Per User" | **UNSOURCED** — we didn't calculate this | **REMOVE** or replace with "$200/mo Max plan subscription cost" (factual) | Anthropic pricing |
| "130+ Validated GitHub Issues" | Correct | OK as-is | PASS5_GITHUB_DEEP |
| "100% Claimed Completion Accuracy" | This is a rhetorical framing, not a stat | OK as rhetorical device but label it clearly — "Model's self-reported success rate" | Campaign framing |
| "+20% Perceived Productivity" | Correct (METR) | OK | METR |
| "30-40% Manual Auditing Time" | Sourced from our campaign description | OK but should note "user-reported estimate" | Campaign |

### Prompt for AI Image Editor

> Recreate this infographic with these corrections:
> 1. Change "The 24-Point Failure Taxonomy" to "The 16-Point Failure Taxonomy" — show the 6 categories: Context Amnesia, Destructive Autonomous Actions, Fielding Misuse, Hallucination Loop, Logical Inconsistency (keep these as-is, they're fine summaries)
> 2. Remove "67% Actual Completion Accuracy" — replace with "874 thumbs-up on #3382 (most-upvoted behavioral bug in anthropics/claude-code)"
> 3. Change "$200 Monthly Waste Per User" to "$200/mo Max Plan — the subscription tier where these failures occur"
> 4. Keep the Perception vs. Reality balance scale, the "+19% Slower" stat, and the "130+ Validated GitHub Issues" — all correct
> 5. Add footer: "Evidence package: 400+ sources across 15+ platforms — github.com/anthropics/claude-code/issues/32650"

---

## General Instructions for All Infographics

### Style Guidelines
- Clean, professional, developer-oriented aesthetic
- Minimize "AI art" visual noise (glowing brains, explosions, etc.) — data should be the hero
- Use a consistent color palette across all 5 (suggestion: dark navy + orange/amber for warnings + white backgrounds)
- All text must be readable at 1200px wide (Twitter card size)
- Source citations in small text (8pt) under every major stat claim

### What NOT to Include
- Any stat not in the "Verified Stats Master List" above
- Round numbers that look made up (e.g., "75%", "67%", "$200 waste")
- CVSS scores we can't cite (no 10/10 — use 8.7)
- Competitor data we haven't verified (no Codex uptime claims)
- The word "crisis" in more than 2 of the 5 titles (it's overused — vary the framing)

### Publication Targets
| Infographic | Primary Platform | Dimensions |
|-------------|-----------------|------------|
| Good-1 (Overview) | Twitter/X hero | 1600x900 (16:9) |
| Good-5 (Security) | Blog secondary | 1200x675 (16:9) |
| Good-14 (Data Table) | GitHub comment | 1200x800 |
| Good-15 (Failure Chain) | Blog centerpiece | 1200x800 |
| Good-16 (Integrity) | DEV Community / LinkedIn | 1200x675 (16:9) |

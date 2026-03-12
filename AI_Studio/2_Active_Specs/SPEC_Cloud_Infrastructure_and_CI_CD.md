---
spec_id: TRIAD-CLOUD-V1
title: Cloud Infrastructure, CI/CD, and AI Fleet Operations Architecture
status: Draft — Awaiting Architect Review
priority: P1
date: 2026-03-11
author: Claude Code (Implementer)
architect_reviewer: ChatGPT (Architect)
systems_architect_qaqc: Antigravity (Gemini)
intended_implementers: Claude Code, Antigravity, Grok Heavy
workflow: VoxCore Triad
depends_on: []
---

# Cloud Infrastructure, CI/CD, and AI Fleet Operations Architecture

## 1) Overview

This specification proposes a phased migration of VoxCore's developer infrastructure from a single-PC topology to a hybrid local+cloud architecture. It covers six initiatives that collectively eliminate the single-point-of-failure risk, automate the build/deploy/QA lifecycle, and formalize multi-AI code review across the VoxCore Triad and extended AI fleet.

**Key context**: VoxCore is a **repack** (redistributable private server). The ~1,500 users download release packages and run their own local worldserver. The cloud infrastructure is exclusively for **developer operations** — CI/CD, bot hosting, backups, QA automation, and disaster recovery. It does not host game traffic.

### AI Fleet Roster

| Agent | Role | Platform | Primary Use |
|-------|------|----------|-------------|
| ChatGPT 5.4 | Architect | OpenAI | Specs, architecture review, PR architecture comments |
| Claude Code Opus 4.6 | Implementer | Anthropic | Code, SQL, scripts, PR correctness review |
| Gemini Antigravity | Systems Architect / QA | Google | Build impact, schema validation, nightly regression |
| Cowork | Desktop Assistant | Anthropic | Plain-English summaries, doc generation |
| Super Grok Heavy | Research / Security | xAI | Security audit, OWASP, research |

---

## 2) Current State

### What Exists Today

- **Hardware**: Single developer PC — Ryzen 9 9950X3D, 128GB DDR5, RTX 5090, NVMe, Windows 11
- **Source Control**: Private GitHub repo (`VoxCore84/RoleplayCore`), `gh` CLI authenticated
- **CI (partial)**: 5 GitHub Actions workflows exist (`.github/workflows/`):
  - `linux-build.yml`, `macos-arm-build.yml`, `win-x64-build.yml` (inherited from TrinityCore upstream)
  - `issue-labeler.yml`, `pr-labeler.yml` (repo management)
  - These are stock TrinityCore workflows — not customized for VoxCore's build config or deployment
- **DraconicBot**: Discord support bot at `tools/discord_bot/`, Python 3.14, discord.py 2.4+, 17 cogs, 16 slash commands, version 2.1.0. Currently runs on the developer's PC. Deps: `requirements.txt` (discord.py, aiohttp, python-dotenv, pymysql)
- **MySQL**: UniServerZ 9.5.0 (bundled), 5 databases (auth, characters, world, hotfixes, roleplay), root/admin
- **Build System**: MSVC (VS 2026), Ninja, CMake presets, C++20. Build scripts: `tools/build/`
- **DevOps Pipeline**: `tools/shortcuts/start_all.bat` (6-step boot), `stop_all.bat` (graceful shutdown + client data capture + Claude Code handover). SQL drop zone: `sql/updates/pending/`
- **Auto-Parse**: `tools/auto_parse/` — packet log parser, HTML dashboard, tray icon, crash detection
- **AI Studio**: `AI_Studio/` — multi-AI coordination hub with Central Brain, Inbox, Reports, and 5 NotebookLM directories
- **Release Process**: Entirely manual — developer builds, packages, uploads zips, announces in Discord

### What Does Not Exist

- No cloud hosting for any service
- No automated deployment pipeline
- No nightly QA regression
- No multi-AI code review on PRs
- No automated release packaging
- No off-site database backups (GitHub is the only backup for source; MySQL has no off-site copy)
- No Docker containerization of any service
- No documented disaster recovery procedure

---

## 3) Proposed Architecture

### Initiative 1: Cloud Infrastructure — Phased Migration

#### Phase 1 — Oracle Cloud Free Tier: DraconicBot Hosting ($0/mo)

**Goal**: Run DraconicBot 24/7 without depending on the developer's PC being online.

**Technical Design**:
- **Platform**: Oracle Cloud Infrastructure (OCI) Always Free Tier — ARM Ampere A1 instance (4 OCPU, 24GB RAM, 200GB boot volume)
- **OS**: Ubuntu 24.04 LTS (ARM64)
- **Runtime**: Docker container running Python 3.14 + discord.py
- **Deployment**: GitHub Actions workflow triggers on push to `tools/discord_bot/` path → builds Docker image → pushes to GitHub Container Registry (ghcr.io) → SSH deploy to OCI instance
- **Secrets Management**: `.env` file on the OCI instance (Discord token, channel IDs, MySQL connection string if needed). GitHub Actions secrets for deploy credentials
- **Monitoring**: Bot self-reports health to a Discord channel via the existing `cogs/watchdog.py`. Add a simple systemd watchdog that restarts the container on crash
- **Network**: OCI security list allows outbound HTTPS only (Discord API). No inbound ports except SSH (locked to developer IP)

**Bot Containerization**:
```
tools/discord_bot/
  Dockerfile              # NEW — Python 3.14 slim, copy bot code, pip install
  docker-compose.yml      # NEW — service definition, .env binding, restart policy
  .dockerignore           # NEW — exclude __pycache__, logs/, data/
```

**Deployment Workflow** (new GitHub Actions):
```
.github/workflows/deploy-draconicbot.yml
  trigger: push to tools/discord_bot/** on master
  steps:
    1. Build Docker image
    2. Push to ghcr.io/voxcore84/draconicbot:latest
    3. SSH to OCI instance
    4. docker pull + docker-compose up -d
    5. Health check (wait 30s, verify bot responds to Discord API)
    6. Post result to Discord webhook
```

**Migration Concerns**:
- DraconicBot currently imports `pymysql` — some cogs may query the local MySQL. Must audit which cogs need DB access and decide: (a) remove DB dependency, (b) expose MySQL over VPN/tunnel, or (c) use a cloud-hosted DB. The FAQ stats file (`data/faq_stats.json`) is local JSON — this will work in the container as-is if the volume is persisted
- The `cogs/diagnoser.py` generates `.bat` files for users — this is fine in cloud since the bat content is sent via Discord, not executed on the host
- `cogs/watchdog.py` monitors the WoW build feed — this is HTTP-based and will work anywhere

#### Phase 2 — Hetzner Dedicated Server: Full VoxCore Mirror (~$60-90/mo)

**Goal**: Full development mirror for CI/CD, testing, and disaster recovery.

**Technical Design**:
- **Platform**: Hetzner Dedicated (AX42 or similar — AMD Ryzen 7, 64GB RAM, 2x1TB NVMe)
- **OS**: Ubuntu 24.04 LTS
- **Services**:
  - Full VoxCore repo clone (auto-sync from GitHub)
  - MySQL 8.0 with all 5 databases (nightly restore from dump)
  - Linux build environment (GCC/Clang, CMake, Ninja, OpenSSL) for CI builds
  - Dev worldserver instance (for automated integration testing — not player-facing)
  - All Python tools (`auto_parse`, `ai_studio_router`, `catalog/`, etc.)
  - DraconicBot (redundant — can failover from OCI if needed)
- **Network**: Firewall allows SSH (key-only, developer IP), HTTPS outbound. Worldserver port (8085/3724) only on localhost (not exposed — dev testing only)
- **Storage**: Separate mount for MySQL data, separate mount for build artifacts

**This server is NOT for hosting players.** It is a development mirror, CI runner, and disaster recovery target.

**Deferred Decision**: Whether to also run a self-hosted GitHub Actions runner on this server (saves GitHub Actions minutes) vs. using GitHub-hosted runners only. Architect should weigh cost vs. complexity.

---

### Initiative 2: Automated CI/CD Pipeline

**Goal**: Every push to master triggers a verified build + deploy cycle. PRs get build validation before merge.

**Current State**: The 5 existing workflows (`.github/workflows/`) are inherited from upstream TrinityCore. They build stock TrinityCore without VoxCore's custom CMake options (`ELUNA=ON`, `SCRIPTS=static`, custom databases, etc.). They likely fail or produce incomplete builds.

**Proposed Workflow Architecture**:

```
.github/workflows/
  ci-build-linux.yml          # REPLACE linux-build.yml — VoxCore-specific CMake + Ninja
  ci-build-windows.yml        # REPLACE win-x64-build.yml — MSVC cross-compile or skip
  ci-sql-validate.yml         # NEW — validate SQL syntax, schema consistency
  deploy-draconicbot.yml      # NEW — bot deployment (see Initiative 1)
  deploy-hetzner.yml          # NEW — full server deployment (Phase 2)
  release-package.yml         # NEW — build release artifacts (see Initiative 6)
  nightly-qa.yml              # NEW — nightly regression (see Initiative 3)
```

**CI Build Pipeline** (`ci-build-linux.yml`):
```
trigger: push to master, pull_request to master
matrix: [gcc-14, clang-18] x [Debug, RelWithDebInfo]
steps:
  1. Checkout repo
  2. Cache: CMake build dir, MySQL headers, OpenSSL, Boost
  3. Install deps (apt: libmysqlclient-dev, libssl-dev, libboost-all-dev, etc.)
  4. cmake --preset x64-Debug -DSCRIPTS=static -DELUNA=ON -DTOOLS=ON
  5. ninja -j$(nproc)
  6. Run unit tests (CTest) if any exist
  7. Upload build artifacts (worldserver, bnetserver, tools)
  8. Post build status to Discord via webhook
```

**SQL Validation Pipeline** (`ci-sql-validate.yml`):
```
trigger: push/PR that touches sql/**
steps:
  1. Spin up MySQL 8.0 service container
  2. Apply base schema (sql/RoleplayCore/*.sql)
  3. Apply all updates in order (sql/updates/**/master/*.sql)
  4. Run schema consistency checks:
     - All FK references resolve
     - No duplicate primary keys in update files
     - Column counts match INSERT statements
  5. Report results
```

**Open Question for Architect**: Should we keep the macOS ARM build (`macos-arm-build.yml`)? VoxCore is Windows-only for players. macOS build would only validate cross-platform compilation of TrinityCore core. Cost: ~10 min per PR in Actions minutes. Recommendation: drop it.

---

### Initiative 3: Nightly QA Regression (Antigravity-Owned)

**Goal**: Automated nightly quality gates that catch regressions before the developer discovers them in-game.

**Schedule**: 03:00 UTC daily (GitHub Actions cron)

**Ownership**: Antigravity (Gemini) owns the QA workflow design and report interpretation. Claude Code owns the scanner/validator tool implementations.

**Nightly Pipeline** (`nightly-qa.yml`):
```
schedule: cron '0 3 * * *'
steps:
  1. Pull latest master
  2. Full Linux build (fail = P0 alert)
  3. Run spell audit scanner (tools/spell_audit/ or equivalent)
     - Current state: 13 RED / 84 YELLOW from last audit
     - Track delta from previous run
  4. DB schema validation:
     - DESCRIBE all tables → compare against baseline schema snapshot
     - Detect column drift, missing indices, orphaned references
  5. SQL syntax validation:
     - Parse all sql/updates/ files
     - Verify idempotency markers where expected
  6. Custom script registration audit:
     - Parse custom_script_loader.cpp
     - Verify every AddSC_* call has a matching .cpp file
     - Verify every .cpp in scripts/Custom/ is registered
  7. Generate report → AI_Studio/Reports/Nightly/YYYY-MM-DD_nightly.md
  8. Post summary to Discord (#dev-ops channel) via webhook
  9. If any P0 failures: tag developer in Discord
```

**Report Format**:
```markdown
# Nightly QA Report — YYYY-MM-DD

## Build Status
- Linux gcc-14 Debug: PASS/FAIL (link)
- Linux gcc-14 RelWithDebInfo: PASS/FAIL (link)

## Spell Audit Delta
- RED: N (delta +/-M from yesterday)
- YELLOW: N (delta +/-M)
- New issues: [list]

## Schema Validation
- Tables checked: N
- Drift detected: [list or "none"]

## SQL Syntax
- Files checked: N
- Errors: [list or "none"]

## Script Registration
- Registered: N
- Unregistered .cpp files: [list or "none"]
- Missing .cpp for registered calls: [list or "none"]
```

**Antigravity's Role**: After the nightly report is generated, Antigravity reads it, interprets findings, and writes actionable follow-up specs to `AI_Studio/1_Inbox/` for Claude Code to implement. Antigravity does NOT fix code directly — it writes specs and QA reports.

---

### Initiative 4: Multi-AI Code Review Pipeline

**Goal**: Every PR gets reviewed by the full AI fleet, each from their specialized perspective.

**Trigger**: `pull_request` event (opened, synchronize)

**Pipeline** (`pr-ai-review.yml` or webhook-based):
```
on: pull_request
steps:
  1. Collect PR metadata: changed files, diff, commit messages
  2. Fan out review requests (parallel):

     a. ChatGPT (Architect) — Architecture Review
        - Does this change align with existing architecture?
        - Are naming conventions followed?
        - Is the scope appropriate or does it need splitting?
        - Any design concerns?

     b. Claude Code (Implementer) — Implementation Review
        - Code correctness (C++20 compliance, TC conventions)
        - SQL correctness (column counts, schema adherence)
        - Edge cases, null handling, thread safety
        - RBAC permission ranges

     c. Antigravity (QA) — Build Impact & Schema Review
        - Will this break the Linux build?
        - Does it touch shared headers that trigger full rebuilds?
        - Schema migration safety (reversibility, data loss risk)
        - Does it affect the nightly QA baseline?

     d. Grok Heavy (Security) — Security Audit
        - SQL injection vectors (especially in custom commands)
        - Command injection (bat file generation, system calls)
        - OWASP Top 10 relevance
        - Credential exposure (hardcoded paths, tokens, connection strings)
        - Input validation on player-facing commands

     e. Cowork (Desktop) — Plain-English Summary
        - What does this PR do in non-technical terms?
        - What should the developer test in-game?
        - Any user-facing behavior changes?

  3. Each reviewer posts their findings as a PR comment via GitHub API
  4. Use structured comment format with severity labels:
     - [BLOCKER] — must fix before merge
     - [CONCERN] — should address, not blocking
     - [NOTE] — informational
     - [APPROVED] — no issues found in this reviewer's domain
```

**Implementation Options** (Architect should decide):
1. **GitHub Actions + API calls**: Each reviewer is a job in a workflow that calls the respective AI API, collects the response, and posts it via `gh api`. Simplest, but requires API keys in GitHub secrets
2. **Webhook to Hetzner**: PR event webhook hits a review orchestrator on the Hetzner server, which dispatches to AI APIs and posts results. More control, but requires Phase 2 server
3. **Hybrid**: Use GitHub Actions for Claude Code review (native via `claude` CLI or API), webhook for others

**Cost Estimate**: Per PR, assuming ~500 lines of diff:
- ChatGPT 5.4: ~$0.05-0.15 (depends on context)
- Claude Code Opus 4.6: ~$0.10-0.30
- Gemini (Antigravity): ~$0.02-0.05
- Grok Heavy: ~$0.05-0.15
- Cowork: ~$0.02-0.05
- **Total**: ~$0.25-0.70 per PR. At ~5 PRs/day = ~$40-100/month

**Open Question**: Should all 5 reviewers run on every PR, or should we use file-path filters? E.g., Grok security audit only on PRs touching `src/server/scripts/Commands/` or `tools/discord_bot/`. Architect should define the routing matrix.

---

### Initiative 5: Disaster Recovery & Backup Strategy

**Goal**: No single failure (hardware, cloud, GitHub) can permanently lose project state.

**3-Copy Rule**:

| Asset | Copy 1 (Primary) | Copy 2 (GitHub) | Copy 3 (Cloud) |
|-------|-------------------|------------------|-----------------|
| Source code | Local PC (NVMe) | GitHub private repo | Hetzner clone (auto-sync) |
| MySQL databases (5) | Local UniServerZ | Not backed up currently | Hetzner nightly dump |
| Build artifacts | Local `out/build/` | GitHub Actions artifacts (90-day retention) | Hetzner build cache |
| Bot data (`faq_stats.json`, logs) | Local `tools/discord_bot/data/` | Git-tracked (partial) | OCI container volume |
| Client data (packets, crashes) | Local `PacketLog/` | Not backed up | Hetzner selective sync (optional) |
| AI Studio state | Local `AI_Studio/` | Git-tracked | Hetzner clone |
| Secrets (`.env`, tokens) | Local files | GitHub Actions secrets | OCI/Hetzner `.env` files |

**Nightly MySQL Backup** (runs on Hetzner):
```
Schedule: 02:00 UTC daily (before nightly QA at 03:00)
Steps:
  1. mysqldump --single-transaction --routines --triggers for each DB:
     - auth, characters, world, hotfixes, roleplay
  2. Compress: gzip each dump
  3. Rotate: keep 7 daily, 4 weekly, 3 monthly
  4. Upload to OCI Object Storage (free tier: 20GB)
  5. Verify: gunzip + mysql --dry-run parse on latest dump
  6. Alert on failure: Discord webhook
```

**Note**: The Hetzner MySQL is restored FROM these dumps — the developer's local MySQL is the source of truth during active development. The Hetzner copy is a disaster recovery replica, not a live sync target.

**Recovery Procedure** (documented as runbook):
```
Scenario: Developer PC total loss
  1. Provision new PC or use Hetzner as temporary dev server
  2. git clone from GitHub (full source recovery)
  3. Restore MySQL from latest Hetzner dump (OCI Object Storage)
  4. Rebuild: cmake + ninja (build environment must be re-installed)
  5. Copy .env files from Hetzner (secrets)
  6. Bot is already running on OCI — no action needed
  7. Estimated RTO: 2-4 hours

Scenario: GitHub goes down
  1. Local PC has full repo — push to backup remote (Hetzner gitea or bare repo)
  2. Hetzner has full clone — can serve as temporary remote
  3. DraconicBot unaffected (OCI)
  4. CI/CD paused until GitHub recovers (or migrate to self-hosted)

Scenario: OCI instance lost
  1. DraconicBot falls back to running on developer PC (or Hetzner)
  2. Redeploy: GitHub Actions re-pushes container to new OCI instance
  3. Estimated RTO: 30 minutes
```

---

### Initiative 6: Release Pipeline for Repack Users

**Goal**: Automate the repack release process from "push a tag" to "users download from Discord."

**Current Process** (manual):
1. Developer builds locally in VS
2. Manually copies binaries, configs, SQL files into a release folder
3. Manually zips the package
4. Manually uploads to... somewhere (no formal release hosting)
5. Manually announces in Discord

**Proposed Process** (automated):

**Trigger**: Push a Git tag matching `v*` (e.g., `v1.2.0`)

**Release Workflow** (`release-package.yml`):
```
on: push tags 'v*'
steps:
  1. Build worldserver + bnetserver (RelWithDebInfo, Linux + Windows cross-compile)
     - Windows: use MSVC cross-compile via GitHub Actions windows runner
     - Linux: native GCC build (for users who want to run on Linux)
  2. Build tools (map/vmap extractors, etc.)
  3. Collect release artifacts:
     - Binaries: worldserver, bnetserver, mapextractor, vmap4extractor, etc.
     - Configs: worldserver.conf.dist, bnetserver.conf.dist
     - SQL: sql/RoleplayCore/ (base schema) + sql/updates/ (all updates)
     - Docs: INSTALL.md, CHANGELOG.md, LICENSE
  4. Package:
     - VoxCore-{version}-Windows-x64.zip
     - VoxCore-{version}-Linux-x64.tar.gz (if Linux build is supported)
  5. Generate changelog from git log between this tag and the previous tag
  6. Create GitHub Release:
     - Title: "VoxCore {version}"
     - Body: auto-generated changelog + manual release notes from tag annotation
     - Attach zip/tar.gz artifacts
  7. Post to Discord via DraconicBot webhook:
     - Announcement in #announcements channel
     - Download links
     - Summary of changes
```

**Open Questions for Architect**:
1. Should we support Linux release packages? VoxCore users are primarily Windows. Linux builds add CI time and testing burden. Recommendation: Windows-only for now, Linux as future option
2. Should the release include a bundled MySQL (like UniServerZ)? This is a large binary dependency. Alternative: document MySQL installation as a prerequisite
3. Tag naming convention: semver (`v1.2.0`) vs. date-based (`v2026.03.11`) vs. build-based (`v66337-1`)? Recommendation: semver, since build number (66337) is the WoW client version and doesn't change with every VoxCore release
4. Should release packages be hosted ONLY on GitHub Releases, or also mirrored to another host (e.g., Hetzner downloads page)? GitHub Releases has a 2GB per-file limit

---

## 4) Phase Plan

### Phase 0 — Foundation (Week 1)
**Owner**: Claude Code
- [ ] Audit DraconicBot for local-only dependencies (MySQL, file paths, bat generation)
- [ ] Write `Dockerfile` and `docker-compose.yml` for DraconicBot
- [ ] Test container locally on developer PC
- [ ] Create `deploy-draconicbot.yml` GitHub Actions workflow (dry-run mode)
- [ ] Document all required secrets and environment variables

### Phase 1 — DraconicBot Cloud Deployment (Week 2-3)
**Owner**: Claude Code (implementation), Antigravity (QA)
- [ ] Provision OCI Always Free ARM instance
- [ ] Deploy DraconicBot container
- [ ] Configure systemd watchdog + auto-restart
- [ ] Verify all 17 cogs function in cloud environment
- [ ] Enable GitHub Actions auto-deploy on push
- [ ] Shut down local bot instance, confirm cloud-only operation
- [ ] Run for 7 days, monitor stability

### Phase 2 — CI/CD Pipeline (Week 3-5)
**Owner**: Claude Code (workflows), Antigravity (QA validation)
- [ ] Replace stock TrinityCore CI workflows with VoxCore-specific ones
- [ ] `ci-build-linux.yml`: full build with ELUNA, SCRIPTS, custom DBs
- [ ] `ci-sql-validate.yml`: schema + syntax validation
- [ ] Verify builds pass on current master before enforcing on PRs
- [ ] Add branch protection: require CI pass before merge

### Phase 3 — Hetzner Server + Backups (Week 5-8)
**Owner**: Claude Code (provisioning), Antigravity (DR validation)
- [ ] Provision Hetzner dedicated server
- [ ] Install build environment (GCC, CMake, Ninja, MySQL, OpenSSL, Boost)
- [ ] Clone repo, restore MySQL from local dump
- [ ] Set up nightly MySQL backup cron → OCI Object Storage
- [ ] Verify full build works on Hetzner
- [ ] Test disaster recovery procedure end-to-end
- [ ] Document recovery runbook

### Phase 4 — Nightly QA + AI Code Review (Week 8-10)
**Owner**: Antigravity (QA design), Claude Code (scanner tools), Grok (security)
- [ ] Implement `nightly-qa.yml` with spell audit, schema validation, script registration audit
- [ ] Run for 7 days, calibrate thresholds (avoid alert fatigue)
- [ ] Implement multi-AI PR review pipeline (start with Claude Code only, add others iteratively)
- [ ] Define file-path routing matrix for reviewer assignment

### Phase 5 — Release Pipeline (Week 10-12)
**Owner**: Claude Code (workflow), Antigravity (package QA)
- [ ] Implement `release-package.yml`
- [ ] Test with a beta release tag
- [ ] Integrate DraconicBot release announcement
- [ ] Document the release procedure for the developer

---

## 5) Risk Assessment

### High Risk
| Risk | Impact | Mitigation |
|------|--------|------------|
| OCI Free Tier limitations (CPU throttling, network caps) | Bot becomes unresponsive during peak Discord activity | Monitor latency; fallback to running on developer PC; consider Hetzner as backup bot host |
| MySQL dependency in DraconicBot cogs breaks in cloud | Bot partially non-functional after migration | Audit and decouple DB-dependent cogs before migration (Phase 0) |
| GitHub Actions minutes exhaustion | CI/CD stops working mid-month | Use self-hosted runner on Hetzner (Phase 3); optimize build caching; skip macOS builds |
| Windows cross-compile on Linux CI runners fails for VoxCore | Release pipeline cannot produce Windows binaries | Use GitHub-hosted Windows runners for release builds (more expensive but guaranteed to work) |

### Medium Risk
| Risk | Impact | Mitigation |
|------|--------|------------|
| AI API costs exceed budget for PR reviews | $100+/mo for review pipeline alone | Implement file-path routing to skip irrelevant reviewers; rate-limit to N reviews/day |
| Nightly QA alert fatigue (too many false positives) | Developer ignores alerts, defeating the purpose | 7-day calibration period; severity thresholds; only alert on delta (new issues), not total count |
| Secret management across 3 environments | Credential leak risk | Use GitHub Actions secrets (encrypted), OCI vault, Hetzner encrypted .env; never commit secrets; rotate quarterly |
| Hetzner server maintenance windows | Nightly QA or builds fail intermittently | Schedule QA to avoid known maintenance; alert on failure but don't escalate single occurrences |

### Low Risk
| Risk | Impact | Mitigation |
|------|--------|------------|
| OCI instance gets reclaimed (free tier risk) | Bot goes offline temporarily | Auto-deploy from GitHub Actions can reprovision in ~30 min; Hetzner as fallback |
| GitHub outage | CI/CD paused, no PR reviews | Hetzner has full clone; bot runs independently on OCI; resume when GitHub recovers |

---

## 6) Open Questions for the Architect

These require architectural decisions before implementation can proceed:

1. **DraconicBot MySQL dependency**: Should DB-dependent cogs (e.g., `cogs/lookups.py` uses `pymysql`) be refactored to be database-free (using Wowhead HTTP lookups only), or should we expose MySQL to the cloud bot via SSH tunnel or VPN? The current lookups cog already uses Wowhead scraping — the pymysql dependency may be vestigial

2. **Self-hosted GitHub Actions runner**: Should the Hetzner server run a self-hosted Actions runner to save GitHub Actions minutes and get faster builds (local NVMe vs. GitHub's shared runners)? Trade-off: more maintenance, security surface area

3. **macOS build**: Drop the `macos-arm-build.yml` workflow? VoxCore has no macOS users. Saves ~10 min of Actions time per PR

4. **Multi-AI review routing**: Run all 5 reviewers on every PR, or use file-path filters? Suggested routing:
   - Claude Code: always (cheapest, most relevant)
   - Antigravity: always (schema + build impact is always relevant)
   - ChatGPT: only on PRs touching `src/server/game/` (architecture-level code)
   - Grok: only on PRs touching commands, scripts, or tools (security surface)
   - Cowork: only on PRs with `[user-facing]` label

5. **Release package contents**: Include bundled MySQL? Include client patches/mods? Include the `tools/` directory? Repack users likely want a minimal "just works" package

6. **Tag naming convention**: semver, date-based, or WoW-build-based? See Initiative 6 for discussion

7. **Monitoring and alerting**: Should we invest in a lightweight monitoring stack (e.g., Uptime Kuma on Hetzner) for the bot and server health? Or is Discord webhook alerting sufficient?

8. **Infrastructure-as-Code**: Should the OCI and Hetzner provisioning be codified (Terraform, Ansible) for reproducibility? Or is manual setup acceptable given it is a one-time operation for a solo developer?

---

## 7) Constraints for Implementation

### 7.1 No Player-Facing Cloud Servers
The Hetzner server is for development only. Do not design for or imply hosting game traffic for the 1,500 repack users.

### 7.2 Budget Ceiling
- Phase 1 (OCI): $0/mo — must stay within free tier
- Phase 2+ (Hetzner): $60-90/mo maximum
- AI review pipeline: included in existing ~$1,000/mo AI budget
- Total new infrastructure cost: under $100/mo

### 7.3 Single Developer Operations
All automation must be operable by a single developer. No on-call rotation, no SRE team. Alerts go to Discord. Recovery procedures must be executable by one person.

### 7.4 GitHub as Source of Truth
GitHub remains the authoritative source for all code. The Hetzner clone is a read-only mirror that auto-syncs. No direct pushes to Hetzner's copy.

### 7.5 Windows Build Primacy
The developer builds and tests on Windows (VS 2026). Linux CI builds are for validation and release packaging, not the primary development workflow. Never break the Windows build to fix Linux CI.

### 7.6 Triad Workflow Compliance
All initiatives must follow the VoxCore Triad workflow:
- Specs originate from the Architect (ChatGPT) or are reviewed by them
- Implementation by Claude Code
- QA/verification by Antigravity
- No agent self-certifies their own work as complete

### 7.7 Incremental Rollout
Each phase must be stable before the next begins. No "big bang" migration. DraconicBot must be verified running stably on OCI for 7 days before proceeding to Hetzner provisioning.

---

## 8) Verification & Success Criteria

### Phase 1 Success (DraconicBot Cloud)
- [ ] Bot responds to all 16 slash commands within 2 seconds from OCI
- [ ] Bot stays online for 7 consecutive days without manual intervention
- [ ] Auto-deploy from GitHub push works end-to-end (push → build → deploy → healthy)
- [ ] Developer PC can be powered off without affecting bot availability

### Phase 2 Success (CI/CD)
- [ ] Every push to master triggers a Linux build that completes in under 30 minutes
- [ ] Every PR gets build status check before merge is allowed
- [ ] SQL validation catches at least one real error in a test scenario (prove it works)
- [ ] Build failures post to Discord within 5 minutes

### Phase 3 Success (Hetzner + Backups)
- [ ] Full VoxCore build succeeds on Hetzner
- [ ] MySQL backup runs nightly without failure for 14 days
- [ ] Disaster recovery test: restore from backup on Hetzner, start worldserver, connect a test client
- [ ] Recovery runbook is documented and tested

### Phase 4 Success (QA + AI Review)
- [ ] Nightly QA runs for 14 days without false-positive escalation
- [ ] At least one real regression is caught by nightly QA (prove it adds value)
- [ ] Multi-AI PR review posts comments within 10 minutes of PR creation
- [ ] Developer rates AI review comments as "useful" on >50% of PRs

### Phase 5 Success (Release Pipeline)
- [ ] Pushing a `v*` tag produces a downloadable zip on GitHub Releases
- [ ] Zip contains working worldserver + configs + SQL that a repack user can run
- [ ] DraconicBot announces the release in Discord with download link
- [ ] End-to-end time from tag push to Discord announcement: under 45 minutes

---

## 9) Architect Action Requested

This spec is submitted by the Implementer (Claude Code) for Architect (ChatGPT) review. The Architect should:

1. **Review each initiative independently** — approve, modify, or reject
2. **Resolve the 8 open questions** in Section 6
3. **Validate the phase ordering** — are dependencies correct? Should anything be reordered?
4. **Assess budget feasibility** — does the $100/mo ceiling hold for the proposed architecture?
5. **Assign agent ownership** — confirm or adjust the proposed ownership in the Phase Plan
6. **Identify any missing initiatives** — are there infrastructure needs not covered here?
7. **Approve or modify the success criteria** — are they measurable and realistic?

Once approved (with any modifications), this spec moves to `AI_Studio/2_Active_Specs/` and Claude Code begins Phase 0 implementation.

---

## 10) References

| Resource | Path / URL |
|----------|------------|
| DraconicBot source | `tools/discord_bot/` (17 cogs, `requirements.txt`) |
| Existing CI workflows | `.github/workflows/` (5 files, stock TrinityCore) |
| DevOps pipeline | `tools/shortcuts/start_all.bat`, `stop_all.bat` |
| SQL update convention | `sql/updates/<db>/master/YYYY_MM_DD_NN_<db>.sql` |
| Build scripts | `tools/build/configure.bat`, `build.bat`, `build_debug.bat` |
| Auto-parse | `tools/auto_parse/` (19 modules, TOML config) |
| AI Studio hub | `AI_Studio/` (Central Brain, Inbox, Reports) |
| Central Brain | `AI_Studio/0_Central_Brain.md` |
| Memory (Claude Code) | `~/.claude/projects/.../memory/MEMORY.md` |
| Server config reference | `~/.claude/projects/.../memory/server-config.md` |
| Build environment reference | `~/.claude/projects/.../memory/build-environment.md` |
| Tooling inventory | `~/.claude/projects/.../memory/tooling-inventory.md` |

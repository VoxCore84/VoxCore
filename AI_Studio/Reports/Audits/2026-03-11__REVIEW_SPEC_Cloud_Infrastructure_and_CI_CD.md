---
reviewed_spec: SPEC_Cloud_Infrastructure_and_CI_CD.md
reviewer: ChatGPT (Architect)
date: 2026-03-11
model: gpt-4.1
---

# TRIAD-CLOUD-V1 — Architect Review

## Initiative Reviews

---

### **Initiative 1: Cloud Infrastructure — Phased Migration**

**Phase 1 — Oracle Cloud Free Tier: DraconicBot Hosting**

**Status:** APPROVED

**Notes:**
- The design is robust, leverages free-tier resources, and isolates secrets appropriately.
- Containerization and deployment workflow are standard and suitable for the scale.
- Security posture (outbound HTTPS only, SSH locked to dev IP) is appropriate.
- The migration concerns are well-flagged and handled in Phase 0.

**Phase 2 — Hetzner Dedicated Server: Full VoxCore Mirror**

**Status:** APPROVED

**Notes:**
- Clear separation between dev/test and player-facing infra.
- Storage, network, and service isolation are well-specified.
- Deferred decision on self-hosted runner addressed below.

---

### **Initiative 2: Automated CI/CD Pipeline**

**Status:** APPROVED (with minor MODIFICATION)

**Modification:**
- Explicitly drop `macos-arm-build.yml` (see Open Questions).
- Windows builds for releases must use GitHub-hosted Windows runners, not cross-compile from Linux, to guarantee correctness.
- Ensure all custom CMake options are version-locked in the workflow to avoid drift.

---

### **Initiative 3: Nightly QA Regression (Antigravity-Owned)**

**Status:** APPROVED

**Notes:**
- The pipeline is comprehensive and actionable.
- QA/ownership split is clear and aligns with Triad workflow.
- Report format is actionable and developer-friendly.

---

### **Initiative 4: Multi-AI Code Review Pipeline**

**Status:** APPROVED (with MODIFICATION)

**Modification:**
- Implement file-path-based routing for reviewers (see Open Questions for matrix).
- Start with GitHub Actions + API calls for all reviewers; migrate to webhook/Hetzner orchestrator only if scale or cost requires.
- Ensure all AI review comments are prefixed with reviewer/role for traceability.

---

### **Initiative 5: Disaster Recovery & Backup Strategy**

**Status:** APPROVED

**Notes:**
- 3-copy rule is sound.
- Nightly backup/rotation is sufficient for the current scale.
- Recovery runbook is clear and actionable.

---

### **Initiative 6: Release Pipeline for Repack Users**

**Status:** APPROVED (with MODIFICATION)

**Modification:**
- Windows-only release package for now; Linux as a future option (see Open Questions).
- Do NOT bundle MySQL or client patches/mods in the release package; document MySQL as a prerequisite.
- Tag naming: semver (`v1.2.0`).
- Release hosted on GitHub Releases only; mirror to Hetzner only if >2GB or if GitHub limits are hit.

---

## Open Questions — Architect Decisions

---

### 1. **DraconicBot MySQL dependency**

**Decision:**  
**Refactor all DraconicBot cogs to be database-free for cloud operation.**  
- Remove or rewrite any cogs that require direct MySQL access.
- Use HTTP APIs (e.g., Wowhead) for lookups.
- No MySQL exposure/tunneling to cloud bot.

**Rationale:**  
- Reduces attack surface and operational complexity.
- Ensures bot is truly portable and stateless in the cloud.

---

### 2. **Self-hosted GitHub Actions runner**

**Decision:**  
**YES, run a self-hosted Actions runner on Hetzner.**  
- Use for all non-release CI jobs (build/test/QA).
- Use GitHub-hosted runners for Windows release builds only.

**Rationale:**  
- Saves Actions minutes and speeds up builds.
- Maintenance/security overhead is acceptable for a single-user, private repo.

---

### 3. **macOS build**

**Decision:**  
**Drop `macos-arm-build.yml`.**  
- No user demand, saves CI resources.

---

### 4. **Multi-AI review routing**

**Decision:**  
**Implement file-path-based routing as follows:**

| Reviewer      | Trigger Condition                                      |
|---------------|-------------------------------------------------------|
| Claude Code   | Always                                                |
| Antigravity   | Always                                                |
| ChatGPT       | PRs touching `src/server/game/` or `src/server/scripts/` or `AI_Studio/` |
| Grok Heavy    | PRs touching `src/server/scripts/Commands/`, `tools/discord_bot/`, or any file with `sql/` or `tools/` in the path |
| Cowork        | PRs with `[user-facing]` label or touching `docs/`, `AI_Studio/`, or `tools/discord_bot/` |

- Allow developer to override and force all reviewers via a `[full-review]` label.

---

### 5. **Release package contents**

**Decision:**  
- **Do NOT bundle MySQL or client patches/mods.**
- **Include only:**
  - Binaries (worldserver, bnetserver, tools)
  - Configs (`*.conf.dist`)
  - SQL (base + updates)
  - Docs (`INSTALL.md`, `CHANGELOG.md`, `LICENSE`)
  - Minimal `tools/` (only what's needed to run the server, not dev-only tools)
- Document MySQL installation as a prerequisite in `INSTALL.md`.

---

### 6. **Tag naming convention**

**Decision:**  
**Use semver (`v1.2.0`).**  
- WoW build number is not a release driver.
- Date-based tags are less clear for users.

---

### 7. **Monitoring and alerting**

**Decision:**  
**Discord webhook alerting is sufficient for now.**  
- No need for a dedicated monitoring stack (e.g., Uptime Kuma) at this scale.
- Re-evaluate if uptime or incident response becomes a problem.

---

### 8. **Infrastructure-as-Code**

**Decision:**  
**Manual setup is acceptable for now.**  
- Document all provisioning steps in `AI_Studio/Docs/infra-setup.md`.
- If infra needs to be rebuilt more than once per year, revisit with Terraform/Ansible.

---

## Phase Ordering & Budget Feasibility

- **Phase ordering is correct and dependencies are sound.**
- **Budget ceiling ($100/mo) is respected.**  
  - OCI Free Tier: $0
  - Hetzner: $60-90/mo
  - AI review pipeline: within existing AI budget
- **Incremental rollout and agent ownership are appropriate.**

---

## Agent Ownership

| Phase      | Owner(s)                         |
|------------|----------------------------------|
| Phase 0    | Claude Code                      |
| Phase 1    | Claude Code (impl), Antigravity (QA) |
| Phase 2    | Claude Code (impl), Antigravity (QA) |
| Phase 3    | Claude Code (infra), Antigravity (QA/DR) |
| Phase 4    | Antigravity (QA), Claude Code (tools), Grok (security) |
| Phase 5    | Claude Code (release), Antigravity (QA) |

**No changes required.**

---

## Missing Initiatives or Risks

- **No major missing initiatives.**  
- **Minor risk:**  
  - If AI API quotas are exceeded, fallback to a single reviewer (Claude Code) until budget refresh.
  - If Hetzner is unavailable for >24h, developer must be able to run all critical jobs locally.

---

## Success Criteria

**APPROVED as written.**  
- All criteria are measurable, realistic, and map to the actual workflow.

---

## Summary Verdict

**APPROVED WITH MODIFICATIONS**  
- All six initiatives are approved, with minor modifications as detailed above.
- All open questions are resolved with concrete decisions.
- Phase ordering, budget, and agent ownership are validated.
- No major missing initiatives or risks.
- Success criteria are realistic and actionable.

---

## Action Items

1. **Implementer (Claude Code):**
   - Begin Phase 0 with DraconicBot audit and containerization.
   - Remove all MySQL dependencies from DraconicBot cogs.
   - Update CI/CD workflows per above (drop macOS, Windows builds on GitHub-hosted runners only).
   - Implement file-path-based AI review routing.
   - Prepare release pipeline for Windows-only, semver tags, no bundled MySQL.

2. **QA (Antigravity):**
   - Prepare QA validation scripts for DraconicBot and CI/CD.
   - Draft initial QA report templates.

3. **Architect (ChatGPT):**
   - Move this spec to `AI_Studio/2_Active_Specs/` with status: **APPROVED WITH MODIFICATIONS**.
   - Monitor for any unforeseen infra or workflow blockers during Phase 0/1.

---

**This architecture is now cleared for implementation.**
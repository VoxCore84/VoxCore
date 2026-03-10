---
spec_id: TRIAD-API-V1A
title: Architect API Inbox Producer — Dry-Run Acceptance and Live API Gate
status: Approved with Live Acceptance Gate
priority: P1
date: 2026-03-09
architect: ChatGPT
systems_architect_qaqc: Antigravity
intended_implementer: Antigravity / Claude Code
workflow: VoxCore Triad
parent_spec: TRIAD-API-V1
---

# Architect API Inbox Producer — Dry-Run Acceptance and Live API Gate

## 1) Architect Decision

The work completed under `TRIAD-API-V1` appears strong and materially aligned with the approved architecture.

The stream is **accepted as implementation-complete for dry-run scope**.

The stream is **not yet accepted as fully production-complete** because the current evidence shows:
- contract/schema defined
- collection/redaction implemented
- validation/rendering/delivery implemented
- dry-run smoke test passed
- atomic inbox drop proved

But it does **not yet show a successful real OpenAI API round-trip**.

Therefore:
- **Dry-run acceptance: granted**
- **Full live-stream acceptance: pending**
- **Clearance to begin a brand-new major stream: not yet granted**

The next required step is a bounded live acceptance gate.

---

## 2) Why This Gate Exists

Dry-run success proves local orchestration.

It does **not** prove the following real-world behaviors:
- API authentication actually works
- live network call succeeds
- returned JSON conforms under real model behavior
- schema validation passes with non-mocked output
- token/cost logging behaves correctly
- live responses render safely into final inbox markdown
- malformed or partial live responses quarantine correctly

The remaining risk is no longer architecture design. It is **live integration acceptance**.

---

## 3) Required Next Step

Execute a new bounded sub-phase:

# Phase 4G — Live API Acceptance

This is **not** a new stream.
This is the final acceptance gate for `TRIAD-API-V1`.

---

## 4) Scope of Phase 4G

Phase 4G is limited to a **single real OpenAI live test path** using:
- one real API key stored only in untracked local env/config
- one known, low-risk intake packet
- one controlled live request
- one validated markdown artifact
- one acceptance walkthrough

This phase must remain:
- OpenAI-only
- user-triggered
- non-daemonized
- single-shot
- low-volume

Do **not** expand scope into:
- Anthropic/Gemini routing
- background daemons
- queue workers
- automatic recurring jobs
- autonomous implementation loops

---

## 5) Live Test Requirements

### 5.1 Intake Packet Selection
Use a low-risk, already-understood packet for first live acceptance.

Recommended candidates:
- `AI_Studio/1_Inbox/Intake_Headless_Build_Validation.md`
- another previously reviewed non-sensitive intake of similar complexity

Do **not** use a highly sensitive or unusually large packet for first live acceptance.

### 5.2 Key Handling
- `OPENAI_API_KEY` must remain in untracked local env/config only
- no committed secrets
- no echoing secrets to logs
- no writing raw key material into manifests, markdown, or debug output

### 5.3 Delivery Behavior
For the first live acceptance run, delivery may still target `AI_Studio/1_Inbox/` if that is the current contract, but the produced artifact must be clearly identifiable as a live-generated test artifact.

Preferred naming behavior for first live run:
- explicit live/test suffix in filename or metadata
- obvious audit trail in manifest/logs

### 5.4 Logging
The run must produce:
- request manifest
- source hashes
- model identifier
- prompt/config version
- output artifact path
- validation pass/fail result
- token usage metadata if available from the wrapper
- explicit success/failure exit code

### 5.5 Validation
The returned live JSON must:
- pass schema validation
- render into markdown cleanly
- drop atomically
- avoid partial artifacts
- avoid malformed inbox outputs

---

## 6) Required Manual Review After Live Run

After the first live run, Antigravity must stop and produce a short acceptance walkthrough covering:

1. exact command executed
2. intake packet used
3. whether authentication succeeded
4. whether schema validation passed on real output
5. output filename generated
6. whether markdown format matched the Triad contract
7. whether logs/manifests were correct
8. whether any live-only bugs appeared
9. whether dedupe logic behaved correctly
10. recommendation: accept stream / patch and retry

Do **not** proceed to a new stream before this review.

---

## 7) Acceptance Criteria for Full Stream Completion

`TRIAD-API-V1` is only fully accepted when all of the following are true:

1. a real OpenAI API call succeeds
2. the live response passes schema validation
3. the markdown renderer produces a valid inbox artifact
4. the artifact is atomically delivered without corruption
5. request manifest/logging is complete and clean
6. no secrets appear in logs or output
7. the result is reviewed and judged usable as a real Architect artifact

If any one of these fails, the stream remains in patch/retry status rather than complete status.

---

## 8) Architect Guidance on Current Status Language

The following status language is approved:

- "Dry-run implementation complete"
- "Live acceptance pending"
- "Ready for bounded live API validation"

The following status language is **not yet approved**:

- "Stream fully complete"
- "Triad API layer fully ready"
- "Cleared for next major stream"

Those stronger claims must wait until Phase 4G succeeds.

---

## 9) After Phase 4G

If the live acceptance succeeds, return to the Architect with the walkthrough.
At that point, the Architect can:
- formally accept `TRIAD-API-V1` as complete
- decide whether to authorize the next stream
- decide whether the next stream is inbox/stateflow hardening, scanner hardening, or broader orchestrator work

Until then, no leap to a full multi-provider daemon is authorized.

---

## 10) Final Architect Directive

Good work.
The implementation appears strong.
But **dry-run is not the same thing as live acceptance**.

Proceed with **Phase 4G — one bounded live OpenAI acceptance run**.
Then stop, summarize, and return for final gating.


---
spec_id: TRIAD-API-V1
title: Architect API Inbox Producer Architecture
status: Approved for Implementation with Guardrails
priority: P0
date: 2026-03-09
architect: ChatGPT
systems_architect_qaqc: Antigravity
intended_implementer: Claude Code
workflow: VoxCore Triad
follows:
  - TRIAD-STAB-V1
  - TRIAD-STAB-V1A
  - TRIAD-STAB-V1B
  - TRIAD-STAB-V1C
  - TRIAD-STAB-V1D
  - TRIAD-STAB-V1E
  - TRIAD-STAB-V1F
  - TRIAD-BUILD-V1
---

# Architect API Inbox Producer Architecture

## 1) Goal & Scope

This specification defines **Next Stream 2** for the VoxCore Triad: automating the **Architect** handoff path so the enterprise no longer depends on manual copy-paste to generate architectural specs.

### Primary Goal
Build a **single canonical API-driven Architect producer** that:

1. gathers intake artifacts from the local VoxCore workspace,
2. packages them into a controlled Architect request,
3. invokes the OpenAI API using a local Python tool,
4. validates the returned structured payload,
5. renders the final inbox-ready markdown spec, and
6. atomically drops that spec into `AI_Studio/1_Inbox/` for downstream ingestion.

### What This Stream Solves
This stream removes the human from the repetitive transport layer between:
- intake packet / session state,
- Architect generation,
- inbox delivery.

### In Scope
- Architect request intake assembly
- OpenAI API invocation for Architect output generation
- structured response validation
- markdown rendering
- atomic inbox handoff
- metadata logging and dedupe protection
- dry-run and smoke-test flows

### Out of Scope
This spec does **not** authorize:
- a fully autonomous always-on daemon
- direct Anthropic/Gemini orchestration in v1
- automatic Claude execution after inbox drop
- code modification by the API producer
- background polling loops without explicit later approval
- broad multi-agent self-routing beyond the Architect generation path

---

## 2) Problem Statement

The next major bottleneck is no longer runtime path brittleness or headless compile validation.

The next bottleneck is **manual architectural transport**:
- the human gathers artifacts,
- the human pastes them into ChatGPT,
- the human copies the resulting spec back into the inbox,
- the human acts as the glue between otherwise stabilized subsystems.

This is slow, repetitive, and error-prone.

The enterprise now has the prerequisites to automate this safely:
- layered path resolution,
- frozen path contract,
- headless build validation,
- stable inbox workflow,
- Triad discipline.

---

## 3) Architect Decision

### 3.1 Single-Provider First
**Approved v1 direction:** automate the Architect path with **OpenAI only**.

Do **not** begin with a full OpenAI + Anthropic + Gemini “master daemon.”
That is too much scope for the current stage.

### 3.2 Triggered Producer, Not Background Daemon
The approved architecture is a **one-shot producer** invoked explicitly by script/CLI.

Examples:
- user-triggered run
- Antigravity-triggered run
- future orchestrator-triggered run

Not approved in v1:
- long-running background service
- auto-polling watcher loops
- multi-agent autonomous routing engine

### 3.3 Structured Output First, Markdown Second
The model should not be trusted to emit final markdown directly as the primary contract.

Approved flow:
1. model returns structured data matching a schema,
2. local validation confirms the response contract,
3. local renderer converts the validated structure into inbox markdown.

This reduces malformed specs and improves determinism.

### 3.4 Atomic Inbox Delivery Is Mandatory
The producer must never write partial specs directly into `AI_Studio/1_Inbox/`.

Approved flow:
- write temp file,
- validate,
- atomic rename/move into inbox,
- record manifest.

### 3.5 Human Approval Is Still the Norm
This stream automates the **generation and handoff** of Architect specs.
It does **not** remove human judgment from major architecture decisions.

---

## 4) File Structure (Rooted at `C:\Users\atayl\VoxCore\`)

```text
C:\Users\atayl\VoxCore\
│
├─ AI_Studio\
│  ├─ 0_Central_Brain.md
│  ├─ 1_Inbox\
│  ├─ 2_Claimed\
│  ├─ 3_Audits\
│  ├─ templates\
│  │  ├─ architect_prompt.md
│  │  └─ inbox_markdown_template.md
│  └─ schemas\
│     ├─ architect_job.schema.json
│     └─ architect_spec.schema.json
│
├─ config\
│  ├─ paths.json
│  ├─ build.json
│  ├─ api_architect.json
│  └─ api_architect.local.env.example
│
├─ tools\
│  └─ api_architect\
│     ├─ run_architect.py
│     ├─ collect_inputs.py
│     ├─ redact_inputs.py
│     ├─ build_request.py
│     ├─ call_openai.py
│     ├─ validate_response.py
│     ├─ render_markdown.py
│     ├─ write_inbox_artifact.py
│     └─ utils.py
│
├─ logs\
│  └─ api_architect\
│     ├─ latest_request_manifest.json
│     ├─ latest_response_raw.json
│     ├─ latest_render_manifest.json
│     ├─ history\
│     └─ quarantine\
│
└─ tests\
   ├─ api_architect_smoke.md
   └─ api_architect_fixtures\
```

### Canonical Entrypoint
The single approved entrypoint is:

`tools/api_architect/run_architect.py`

No parallel duplicate launchers should become canonical in v1.

---

## 5) Inputs, Outputs, and Contracts

## 5.1 Approved Input Sources
The producer may read from the following, depending on invocation mode:

### Primary Inputs
- `AI_Studio/0_Central_Brain.md`
- `doc/session_state.md`
- `PacketLog/_Session_Brief.md`
- a supplied intake packet markdown file in `AI_Studio/1_Inbox/` or another approved workspace path

### Optional Inputs
- latest build audit output from `AI_Studio/3_Audits/`
- a bounded excerpt of a walkthrough file
- reusable prompt templates from `AI_Studio/templates/`

### Input Rules
- all inputs must be explicitly selected or allowlisted
- oversized inputs must be truncated or summarized intentionally
- secret-bearing files must be excluded or redacted

## 5.2 Output Artifacts
The producer must emit:

### Required Output
- one inbox-ready markdown spec

### Required Logs / Metadata
- request manifest
- source file hashes
- generation timestamp
- model identifier
- prompt/template version
- validation result
- final output filename
- optional token/cost metadata if available

### Failure Outputs
If validation fails:
- do **not** write to inbox
- write raw result + failure details to `logs/api_architect/quarantine/`

---

## 6) Logic & Data Flow

## 6.1 End-to-End Flow

1. read Central Brain / relevant intake source
2. collect approved source files
3. compute file hashes
4. redact or strip disallowed content
5. build normalized request payload
6. call OpenAI API
7. receive structured result
8. validate against schema
9. render markdown
10. write temp artifact
11. atomically move into inbox
12. write manifests/logs
13. return success/failure summary

## 6.2 Dedupe / Repeat Protection
Before writing an inbox spec, the producer should compare:
- source hashes
- prompt version
- target spec slug/id

If a substantially identical request has already produced an output recently, the tool should:
- skip duplicate generation, or
- require an explicit `--force` flag.

## 6.3 Redaction Layer
The producer must support a preflight redaction pass.

Examples of content that should be excluded or masked if encountered:
- API keys
- secrets / tokens
- private credentials
- accidental raw environment dumps

---

## 7) Configuration Model

## 7.1 Committed Config
`config/api_architect.json` is the canonical committed config for this stream.

It should define:
- default model name
- max input size policy
- input allowlist patterns
- output directory aliases
- dedupe behavior
- dry-run behavior
- default timeout / retry settings
- schema file locations

## 7.2 Local Untracked Config
`config/api_architect.local.env.example` is the template for local overrides.

Examples:
- `OPENAI_API_KEY=`
- optional local model override
- optional logging verbosity override

### Rule
No secrets may be committed into repo config.

---

## 8) API Strategy

## 8.1 Approved API Shape
Use the OpenAI Python library through a dedicated local wrapper module.

### Rule
The wrapper is the only layer allowed to speak directly to the OpenAI API.
Other tools should call the wrapper, not reimplement API calls ad hoc.

## 8.2 Response Shape
The API request should be designed to return a structured schema-backed architecture object rather than a loose freeform answer.

Minimum structured fields:
- `spec_id`
- `title`
- `status`
- `priority`
- `date`
- `goal_scope`
- `file_structure`
- `logic_data_flow`
- `constraints`
- `acceptance_criteria`
- `implementation_order`
- `immediate_next_actions`

## 8.3 Rendering Layer
The markdown renderer is local.

This means:
- formatting policy lives in VoxCore,
- naming templates live in VoxCore,
- the model provides structured content,
- the enterprise controls final markdown shape.

---

## 9) CLI Contract

The canonical v1 command pattern should look like this conceptually:

```text
python tools/api_architect/run_architect.py \
  --mode spec \
  --intake AI_Studio/1_Inbox/Intake_Headless_Build_Validation.md \
  --output-dir AI_Studio/1_Inbox
```

### Required Modes
- `spec` — generate full architect spec
- `dry-run` — collect inputs and render a local simulated request without API execution
- `validate-only` — validate an existing structured response / render target

### Optional Flags
- `--force`
- `--model`
- `--max-input-chars`
- `--tag`
- `--no-inbox-write`

---

## 10) Constraints for Implementation

These are mandatory.

### 10.1 No Multi-Provider Daemon in v1
Do not turn this into a combined OpenAI/Anthropic/Gemini orchestration engine yet.

### 10.2 No Silent Background Service
Do not create a resident watcher/daemon unless separately approved.

### 10.3 No Direct Repo Mutation
This producer generates architecture artifacts only.
It must not modify implementation files as part of normal operation.

### 10.4 No Blind Inbox Writes
All inbox artifacts must be validated before write.

### 10.5 No Prompt Sprawl
Prompt templates should be centralized and versioned.
Do not scatter ad hoc prompt strings across many scripts.

### 10.6 No Infinite Retries
Retry logic must be bounded.
Failures should log cleanly and stop.

### 10.7 No Secret Leakage Into Logs
Raw logs must not expose API keys or sensitive local environment values.

---

## 11) Security, Reliability, and Cost Controls

## 11.1 Security
- API keys must remain in untracked local config or environment only
- input selection must be allowlisted
- redaction must occur before API submission when needed
- quarantine invalid outputs instead of promoting them

## 11.2 Reliability
- atomic writes required
- dedupe protection required
- manifests required
- dry-run mode required
- validation gate required

## 11.3 Cost Control
- set bounded input size rules
- log request counts and optional token/cost metadata
- allow model override by config, not by hardcoded edits
- support dry-run testing without paid calls

---

## 12) Acceptance Criteria

This stream is successful when all of the following are true:

1. a local command can generate an Architect inbox artifact from a real intake packet
2. the generated artifact follows the VoxCore inbox naming template
3. invalid or malformed API outputs are quarantined instead of being written to inbox
4. metadata manifests are written successfully
5. duplicate requests are detected or intentionally forced
6. dry-run mode works without calling the API
7. a smoke test proves end-to-end generation on at least one real intake packet
8. secrets are not written into request/response logs

---

## 13) Recommended Implementation Order

### Phase 4A — Contract Freeze
- create `config/api_architect.json`
- define schema files
- define naming template
- define prompt template versioning rules

### Phase 4B — Input Collector
- build source collector
- add hash computation
- add redaction hooks
- add size guards

### Phase 4C — OpenAI Wrapper
- implement local API wrapper
- load API key from local environment
- support model override
- support dry-run bypass

### Phase 4D — Validation + Rendering
- validate structured output
- render canonical markdown
- generate manifest
- quarantine invalid responses

### Phase 4E — Inbox Delivery
- temp write
- atomic rename
- dedupe / force behavior
- success/failure reporting

### Phase 4F — Smoke Validation
- run against one real intake packet
- verify inbox artifact shape
- verify manifests/logs
- verify quarantine behavior on forced bad input

---

## 14) Future Path (Not v1 Scope)

After this producer is stable, future streams may consider:
- Anthropic/Claude-side coordinated API routing
- broader orchestrator control plane
- multi-agent daemonization
- scheduled/background generation flows
- richer audit / artifact indexing

Those are future layers, not current approval.

---

## 15) Immediate Next Action for Antigravity

Upon reading this spec, Antigravity should:

1. record the new stream in `AI_Studio/0_Central_Brain.md`
2. create a short implementation plan for `TRIAD-API-V1`
3. begin with **Phase 4A — Contract Freeze**
4. keep scope pinned to **OpenAI-only Architect generation**
5. return to the Architect if implementation pressure begins expanding toward a full daemon or multi-provider orchestration engine

---

## 16) Final Architect Decision

**Approved:** Next Stream 2 begins now as the **Architect API Inbox Producer**.

**Not approved:** jumping directly to a full “Master Triad OpenAI/Anthropic Daemon.”

The enterprise should first automate the single highest-value path cleanly:

**intake -> Architect generation -> validated inbox artifact**

Once that is stable, broader agent-to-agent automation can be designed from a stronger base.

---
spec_id: TRIAD-BUILD-V1
title: Headless Build Validation Architecture v1
status: Approved for Implementation
priority: P0
date: 2026-03-09
architect: ChatGPT
systems_architect_qaqc: Antigravity
intended_implementer: Claude Code
workflow: VoxCore Triad
predecessor: TRIAD-STAB-V1F
root_path: C:\Users\atayl\VoxCore\
---

# Headless Build Validation Architecture v1

## 1) Goal & Scope

This specification defines the next primary stabilization stream after Aegis Config Phase 2.

### Primary Goal
Create a single, deterministic, headless build-validation surface for VoxCore so Claude Code can validate C++ and script-related build outcomes without relying on manual Visual Studio button clicks or brittle raw shell sequences.

### What this stream must accomplish
1. **Unify the build entrypoint** so automation stops calling ad hoc `cd ... && ninja ...` commands.
2. **Preserve build parity** with the active CMake preset + Ninja workflow used by the local development environment.
3. **Eliminate hardcoded toolchain paths** from active headless build automation.
4. **Emit bounded logs and structured summaries** so build failures are AI-readable without flooding the terminal.
5. **Support the `/build-loop` contract** with repeatable pass/fail outputs, stable failure fingerprints, and explicit retry stopping conditions.

### Scope
This spec covers:
- canonical headless build entrypoints
- toolchain discovery and environment bootstrapping
- preset-driven configure/build logic
- log capture and compile error extraction
- Claude Code `/build-loop` integration contract
- compatibility handling for legacy batch entrypoints

### Out of Scope
This spec does **not** authorize:
- cloud CI/CD rollout
- release packaging or installer generation
- repo-wide testing architecture beyond smoke validation
- functional gameplay verification
- broad IDE settings mutation
- automatic code fixing beyond the existing Claude/agent loop behavior

---

## 2) Problem Statement

The current build-validation surface is brittle for four reasons:

### A. Mixed Toolchain Assumptions
Active scripts reference multiple Visual Studio version/path assumptions. This makes the build surface fragile if Visual Studio is updated, moved, or resolved differently across shells.

### B. Raw Ninja Invocation Drift
Claude Code currently uses raw `cd` + `ninja` shell commands. That bypasses the higher-level preset contract and risks drift between local IDE behavior and automated CLI behavior.

### C. Environment Reload Noise and Cost
Repeatedly reloading the Visual Studio environment in ad hoc shells is slow and noisy, and it makes debugging inconsistent.

### D. Unbounded Log Output
Raw build output can overflow the terminal and is not ideal for machine parsing. Claude and Antigravity need a stable, bounded artifact surface instead of giant scrollback logs.

---

## 3) Architectural Decisions

## 3.1 Canonical Build Contract
The canonical build surface will be:

- **Primary logic entrypoint:** `tools/build/build.py`
- **Windows convenience shim:** `tools/build/build.bat`

### Rule
All automated headless build validation must route through this contract.

### Disallowed Pattern
After implementation, active automation must **not** use direct raw commands like:
- `cd out/build/x64-Debug && ninja -j4`
- hardcoded `build_cli.bat` style workflows with pinned MSVC paths

### Reason
The enterprise needs one stable surface for logging, error extraction, and future orchestration.

---

## 3.2 Preset-Driven, Not Directory-Driven
CMake presets are the source of truth for headless build behavior.

### Approved Behavior
The build contract must operate in terms of:
- configure preset names
- build preset names
- optional logical build mode names mapped to presets

### Disallowed Behavior
Automation must not rely on hardcoded build directories such as:
- `C:\Users\atayl\VoxCore\out\build\x64-Debug`

### Current Build Strategy
Because the current CLI generator is Ninja and `CMakePresets.json` is already present, the headless contract should standardize on:
- `cmake --preset <configure-preset>` when configure is needed
- `cmake --build --preset <build-preset>` for builds

This preserves parity with the existing preset-driven build structure and reduces generator drift.

---

## 3.3 Toolchain Discovery Contract
Toolchain discovery must be dynamic and layered.

### Repo Root Resolution
Repo root must be resolved through the existing Aegis root discovery approach rather than hardcoded absolute paths.

### Visual Studio / MSVC Discovery
The new build system must dynamically discover the active Visual Studio toolchain.

### Approved Discovery Order
1. local override from untracked config/env (only if intentionally provided)
2. dynamic discovery via a Visual Studio discovery helper
3. explicit hard failure with a clear diagnostic if discovery fails

### Design Requirement
Committed automation must not pin one specific user path or one specific Visual Studio version path as the only valid location.

### Preferred Environment Strategy
`build.py` should materialize the Visual Studio build environment once per invocation and reuse it for the configure/build steps inside that invocation.

That means:
- discover the correct developer command environment
- capture/use that environment for child subprocesses
- avoid repeated ad hoc environment bootstrapping for every shell fragment

---

## 3.4 Canonical Configuration Files
This stream introduces a committed build configuration file in addition to the already-frozen path contract.

### New Committed File
- `config/build.json`

### New Local Example File
- `config/build.local.env.example`

### `config/build.json` responsibilities
This file should define:
- default configure preset
- default build preset
- scripts build preset if applicable
- log locations
- summary artifact locations
- retry policy metadata used by the `/build-loop` contract
- optional environment/discovery hints

### `config/build.local.env.example` responsibilities
This file may contain optional machine-specific overrides for:
- Visual Studio discovery helper location
- alternative toolchain roots
- non-default external dependencies

### Rule
Local env/config is for machine-specific overrides only. It is not the primary source of truth for repo build behavior.

---

## 3.5 Logging and Artifact Surface
Headless build validation must always produce bounded output artifacts.

### Required Raw Log Output
- `logs/build/latest_build_log.txt`
- timestamped copies under `logs/build/`

### Required Structured Build Summary
- `logs/build/latest_build_summary.json`

### Required AI-Readable Audit Surface
- `AI_Studio/3_Audits/latest_compile_errors.md`

### Required Success Handling
On successful build, the system must still update the AI-facing audit surface so stale prior errors are not mistaken for current failures.

That means `latest_compile_errors.md` should be overwritten with either:
- a success stamp indicating no active compile errors, or
- a short success report pointing to the latest raw log and summary

---

## 3.6 Error Extraction Contract
The system must expose build failure data in a stable AI-readable format.

### New Extraction Component
- `tools/build/extract_compile_errors.py`

### Responsibilities
The extractor should parse raw configure/build output and produce a concise markdown summary containing, where available:
- failing preset
- build phase (`configure` or `build`)
- compiler/linker/configuration classification
- file path
- line number
- diagnostic code
- diagnostic message
- path to raw log
- failure fingerprint

### Output Principle
The markdown summary should be compact, high-signal, and suitable for immediate agent consumption.
It should not dump the full raw build log into the audit file.

---

## 3.7 `/build-loop` Contract
The build system must support a bounded retry/fix loop without embedding uncontrolled autonomy into the build entrypoint itself.

### Rule
`build.py` is the canonical validator.
Claude Code's `/build-loop` workflow remains the orchestrator of repeated attempts.

### `build.py` must provide enough metadata for `/build-loop` to enforce:
- stop after **5 consecutive failures without progress**
- stop after **2 exact identical failures**
- stop immediately on successful exit code `0`

### Required Summary Fields
`latest_build_summary.json` should include at minimum:
- timestamp
- preset used
- phase executed
- success boolean
- exit code
- top-level failure class
- failure fingerprint
- unique error site count
- raw log path
- audit markdown path

### Progress Signal
For the purpose of loop control, progress may be defined as any of the following:
- failure fingerprint changed
- unique error site count decreased
- build moved from configure failure to later compile/link stage

---

## 3.8 Legacy Entrypoint Handling
Existing batch/build helpers must not remain as competing canonical systems.

### Approved Handling
Legacy entrypoints should be either:
1. converted into thin wrappers that call the new canonical build contract, or
2. explicitly marked deprecated and excluded from active automation

### Likely Candidates
- `build_cli.bat`
- `tools/shortcuts/build_scripts_rel.bat`
- any workflow file still issuing raw `cd && ninja` commands

### Rule
There must be one obvious supported build-validation path for agents.

---

## 4) File Structure (Rooted at `C:\Users\atayl\VoxCore\`)

```text
C:\Users\atayl\VoxCore\
│
├─ AI_Studio\
│  ├─ 0_Central_Brain.md
│  ├─ 1_Inbox\
│  └─ 3_Audits\
│     └─ latest_compile_errors.md
│
├─ config\
│  ├─ paths.json
│  ├─ Aegis_Path_Contract.md
│  ├─ build.json
│  └─ build.local.env.example
│
├─ logs\
│  └─ build\
│     ├─ latest_build_log.txt
│     ├─ latest_build_summary.json
│     └─ build_YYYYMMDD_HHMMSS.log
│
├─ scripts\
│  └─ bootstrap\
│     └─ resolve_roots.py
│
├─ tests\
│  ├─ aegis_smoke_pack.md
│  └─ headless_build_smoke.md
│
└─ tools\
   └─ build\
      ├─ build.py
      ├─ build.bat
      ├─ discover_toolchain.py
      ├─ extract_compile_errors.py
      ├─ doctor.py
      └─ README.md
```

---

## 5) Logic & Data Flow

## 5.1 Invocation Flow
Primary automation flow:

1. Claude/Antigravity resolves task state via the Central Brain
2. automation invokes the canonical headless build entrypoint
3. repo root is resolved dynamically
4. `config/build.json` is loaded
5. local machine overrides are layered in if present
6. Visual Studio/MSVC environment is discovered and materialized
7. configure step runs if required
8. build step runs via CMake build preset
9. stdout/stderr is captured into raw build logs
10. compile errors are extracted into markdown + summary JSON
11. exit code is returned to caller

---

## 5.2 Configure/Build Decision Logic
The canonical tool should determine whether a configure pass is necessary.

### Configure should run when:
- the preset build directory does not exist
- the build tree is stale or incomplete
- the caller explicitly requests configure/reconfigure

### Build should then run through the build preset contract.

This avoids requiring agents to guess whether they should call configure or build first.

---

## 5.3 Raw Log + Summary Flow
During each invocation:
- current run output is written to a timestamped raw log
- `latest_build_log.txt` is refreshed to point to the newest run artifact behaviorally (copy/overwrite is acceptable)
- `latest_build_summary.json` is refreshed with the newest structured metadata
- `AI_Studio/3_Audits/latest_compile_errors.md` is refreshed with the newest concise build result

### Design Goal
Any agent should be able to inspect one stable file path to understand the latest build state without searching terminal history.

---

## 5.4 AI Feedback Loop Flow
On failure:
- the raw log remains in `logs/build/`
- a concise extracted markdown summary appears in `AI_Studio/3_Audits/latest_compile_errors.md`
- Claude Code uses the summary to drive correction attempts
- the build loop compares the latest summary/fingerprint against prior attempts

On success:
- exit code `0` is returned
- the audit markdown is refreshed to reflect success
- the loop stops

---

## 5.5 Drift Prevention Flow
To avoid CLI/IDE drift:
- CMake preset names remain canonical
- the active generator remains whatever the preset defines
- automation does not hardcode `out/build/...` directory assumptions
- automation does not bypass presets with raw direct `ninja` calls in normal operation

---

## 6) Constraints for Implementation

These constraints are mandatory.

### 6.1 No New Hardcoded User-Specific Toolchain Paths
Do not commit new hardcoded absolute toolchain paths for Visual Studio, MSVC, SDK, or the build tree.

### 6.2 No Global Environment Mutation
This stream must not require modifying global user environment variables, shell startup behavior, or Visual Studio IDE settings as a prerequisite.

### 6.3 No Raw Ninja as the Canonical Agent Contract
Raw `ninja` may still occur under the hood if the preset uses Ninja, but agent-facing automation must call the canonical build entrypoint rather than hand-rolled `cd && ninja` sequences.

### 6.4 Preserve CMakePreset Parity
Do not create a second disconnected build-configuration universe. The existing preset structure remains authoritative.

### 6.5 Keep Logs Bounded
The AI-facing markdown output must stay concise. Raw logs belong in `logs/build/`, not in the audit markdown file.

### 6.6 Keep Legacy Entry Points Thin
If old batch files remain for compatibility, they must dispatch into the new canonical path rather than carrying separate build logic indefinitely.

### 6.7 One Stream at a Time
This stream is about headless build validation. Do not silently expand it into full CI/CD, packaging, or release orchestration.

---

## 7) Acceptance Criteria

This spec is considered successfully implemented when all of the following are true:

1. **Canonical Entry Point Exists**
   - `tools/build/build.py` exists and works
   - a thin Windows shim exists if needed
   - active automation can call one stable build entrypoint

2. **Preset Parity Exists**
   - the system can headlessly build using the current preset structure
   - no active automation depends on hardcoded build directories

3. **Dynamic Toolchain Discovery Works**
   - Visual Studio/MSVC environment is dynamically located or clearly overridden through local config
   - no committed user-specific toolchain path is required

4. **Logs and Summaries Exist**
   - `logs/build/latest_build_log.txt` is produced
   - `logs/build/latest_build_summary.json` is produced
   - `AI_Studio/3_Audits/latest_compile_errors.md` is produced or refreshed every run

5. **Failure Metadata Supports `/build-loop`**
   - failure fingerprint exists
   - progress/no-progress can be determined from summary outputs
   - repeated headless runs can stop according to the declared retry rules

6. **Legacy Drift is Reduced**
   - active workflow files no longer depend on brittle raw `cd && ninja` build commands
   - legacy entrypoints are either wrapped or deprecated

7. **Smoke Validation Passes**
   - at least one normal preset build path succeeds headlessly
   - at least one failure case produces a clean AI-readable compile error summary

---

## 8) Recommended Implementation Order

### Phase 3A — Build Contract Freeze
- inspect the current CMake preset/build preset names
- define canonical invocation arguments
- create `config/build.json`
- define artifact paths and retry metadata

### Phase 3B — Discovery + Environment Layer
- implement repo root resolution integration
- implement Visual Studio/toolchain discovery helper
- materialize reusable child-process build environment per invocation

### Phase 3C — Canonical Build Entrypoint
- implement `tools/build/build.py`
- add optional `tools/build/build.bat`
- support configure/build modes using presets
- write raw logs and summary JSON

### Phase 3D — Compile Error Extraction
- implement `extract_compile_errors.py`
- emit `AI_Studio/3_Audits/latest_compile_errors.md`
- generate stable failure fingerprints

### Phase 3E — Workflow Cutover
- update Claude build-loop workflow to call the canonical entrypoint
- route legacy batch/build helpers into the new contract or mark deprecated

### Phase 3F — Smoke & Regression Validation
- run one success-path validation
- run one intentional failure-path extraction validation if safe
- document repeatable smoke checks in `tests/headless_build_smoke.md`

---

## 9) Non-Negotiable Guardrails for the Implementer

Claude Code and Antigravity must follow these rules while implementing this stream:

1. Read `C:\Users\atayl\VoxCore\AI_Studio\0_Central_Brain.md` before starting.
2. Claim the task before broad changes.
3. Do not bypass presets with raw direct shell build commands in active automation once cutover occurs.
4. Do not introduce new user-pinned Visual Studio path assumptions.
5. Do not treat compile success as proof of functional correctness.
6. Do not expand into CI/CD or packaging work under this spec.
7. Stop and return to the Architect if the preset/toolchain reality discovered in code materially conflicts with this intake packet.

---

## 10) Final Architect Decision

This next stream is **approved for implementation**.

The architectural priority is:
1. unify the build entrypoint
2. preserve preset parity
3. produce stable build logs and AI-readable error extraction
4. cut Claude Code over to the canonical headless validation surface

Scanner hardening remains secondary maintenance work and does not block this stream.

---

## 11) Immediate Next Action for Antigravity

Upon reading this spec, Antigravity should:

1. read `C:\Users\atayl\VoxCore\AI_Studio\0_Central_Brain.md`
2. claim the Headless Build Validation Architecture task
3. prepare a short implementation plan mapped to Phases 3A–3F
4. begin with **Phase 3A — Build Contract Freeze**
5. stop and hand back to the Architect if the actual preset/toolchain code reality materially differs from the intake packet

---

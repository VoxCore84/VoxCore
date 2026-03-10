# Aegis Path Contract

*Phase 2 Closeout Document | Status: FROZEN | Date: 2026-03-09*

This document defines the formal path resolution contract for the VoxCore repository, established during the Aegis Config stabilization stream (`TRIAD-STAB-V1E`). It is intended to prevent hardcoded path brittleness (`C:\Users\...`) from re-entering the repository's active runtime surface.

## 1. Repo Root Discovery

**Core Rule:** No active Python or Batch script may assume the repository root is a fixed absolute path.

- **Python Scripts:** Must locate the project root dynamically. The approved pattern is to walk up the directory tree relative to the current file `__file__`, or import and use the canonical bootstrap utility: `scripts/bootstrap/resolve_roots.py`.
- **Batch Scripts (`.bat`):** Must resolve relative execution paths natively via the `%~dp0` variable.

## 2. Alias Stability (`config/paths.json`)

The `config/paths.json` file is the **single canonical source of truth** for repository path aliases.

**Currently Frozen Aliases:**
- `VOXCORE_ROOT` (Root)
- `ROLEPLAYCORE_ROOT` (Root)
- `AI_STUDIO_DIR`
- `INBOX_DIR`
- `ARCHIVE_DIR`
- `TOOLS_DIR`
- `SCRIPTS_DIR`
- `DOCS_DIR`
- `MEMORY_DIR`

*Do not opportunistically rename these aliases.* They are considered stable and form the baseline for path routing until a future Architectural restructuring dictates otherwise.

## 3. Local Overrides

**Core Rule:** Developer-specific or machine-specific paths (such as custom network shares or external `Program Files` installations) may **not** be committed to the repository source.

- If an explicit environment override is required, it must be contained entirely within the untracked `.env` file for the active system.
- The repository provides `config/paths.local.env.example` as a safe placeholder/template to demonstrate where these overrides belong.

## 4. Requirements for New Scripts

Any newly authored tool, parser, launcher, or script must:
1. Conform to the Root Discovery rules (use `%~dp0` or `resolve_roots.py`).
2. Pull active path destinations from the `config/paths.json` dictionary if crossing major project boundaries (e.g., writing to the Inbox).
3. Treat hardcoded absolute paths as a linting/validation failure.

*(External compiler or toolchain paths like `C:\Program Files\Microsoft Visual Studio` are currently treated as Accepted External Dependencies, provided they do not leak internal VoxCore structural data.)*

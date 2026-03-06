# Cowork Workspace

This folder is used by Claude Desktop's Cowork mode for autonomous tasks.

## Structure
- `context/` — Read-only reference files (CLAUDE.md, todo.md). Refresh from source periodically
- `outputs/` — Where Cowork delivers finished work (daily briefings, weekly audits, reports)
- `inbox/` — Drop files here for Cowork to process

## Usage
1. Open Claude Desktop > Cowork tab
2. Point it at this folder or reference these paths in your prompts
3. Cowork reads context/, processes inbox/, writes to outputs/

## Refresh context files
Context files are copies. To refresh:
- CLAUDE.md: copy from project root
- todo.md: copy from memory/todo.md

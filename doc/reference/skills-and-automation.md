# Claude Code Runtime Config

For tool/script catalog, see [tooling-inventory.md](tooling-inventory.md) or `TOOLING_INVENTORY.md` in wago repo.

## Agent Teams
- Enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in `~/.claude/settings.json` env block

## Performance Env Vars
- `CLAUDE_CODE_AUTOCOMPACT_PCT_OVERRIDE=80` (compact at 80% vs default 95%)
- `ENABLE_TOOL_SEARCH=auto:5` (defer MCP tool loading)
- **Deliberately NOT set**: effort level (keep full Opus reasoning), thinking token limits (need full thinking for transmog/packet debugging)

## Settings (user-level ~/.claude/settings.json)
- `alwaysThinkingEnabled: true` — extended thinking on all providers (added Mar 3 2026)
- `defaultMode: acceptEdits` — auto-approve file edits
- Plugins: clangd-lsp, code-review, lua-lsp, github

## Keybindings (~/.claude/keybindings.json)
- `Ctrl+K Ctrl+F` → model picker (fast mode toggle)
- `Ctrl+K Ctrl+T` → thinking toggle
- `Ctrl+K Ctrl+O` → transcript view

## Statusline
- `~/.claude/statusline-command.sh` — shows model name, context % remaining (with `(!)` at 10%), and estimated session cost
- **Opus 4.6 pricing**: $5/MTok input, $25/MTok output, $6.25/MTok cache write, $0.50/MTok cache read
- Previously used Opus 4.0 rates ($15/$75) — was 3x overestimate, fixed Mar 3 2026

## Named Sessions (~/.claude/sessions/)
- `claude-transmog.bat` — Transmog workstream (`--resume --name "Transmog"`)
- `claude-companion.bat` — Companion Squad (`--resume --name "Companion Squad"`)
- `claude-debug.bat` — Debugging / logs (`--resume --name "Debug"`)
- `claude-general.bat` — General work (`--resume --name "RoleplayCore"`)
- `claude-remote.bat` — Remote-control server with worktree isolation (`claude remote-control server --name "RoleplayCore Remote"`)

## Windows Terminal Profile
- "Claude - RoleplayCore" — launches `claude` directly in `C:\Dev\RoleplayCore`
- Commandline: `cmd.exe /k "%APPDATA%\npm\claude.cmd"`, startingDirectory: `C:\Dev\RoleplayCore`

## Codex CLI
- **OpenAI Codex CLI** (`npx @openai/codex exec`) — authenticated via ChatGPT Pro plan (OAuth, not API key)
- Prefer CLI over Codex Cloud — much faster locally
- Default model `gpt-5.3-codex`; `o3`/`o4-mini` rejected on ChatGPT accounts
- Use `--dangerously-bypass-approvals-and-sandbox` for full write access
- Setup at `.codex/setup.sh`, task prompts in `.codex/`

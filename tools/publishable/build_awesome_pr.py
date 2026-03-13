"""Build the modified awesome-claude-code README with our 4 hook entries."""

def main():
    with open('C:/Users/atayl/VoxCore/tools/publishable/awesome-pr-readme.md', 'r', encoding='utf-8') as f:
        lines = f.readlines()

    edit_verifier = (
        '- [Claude Code Edit Verifier](https://github.com/VoxCore84/claude-code-edit-verifier) '
        'by [VoxCore84](https://github.com/VoxCore84) - PostToolUse hook that reads files back '
        'after every Edit operation, verifying new content landed and old content is gone. Catches '
        'silent edit failures, wrong-occurrence replacements, and encoding corruption. Configurable '
        'warn/block modes and threshold via environment variables. Born from documenting 16 '
        'completion-integrity failure modes across 140+ sessions.\n'
    )
    guardrails = (
        '- [Claude Code Guardrails](https://github.com/VoxCore84/claude-code-guardrails) '
        'by [VoxCore84](https://github.com/VoxCore84) - One-command install bundle of safety '
        'hooks addressing documented agent failure modes: edit verification (PostToolUse read-back), '
        'SQL safety (PreToolUse destructive command blocking), and session stats tracking. Includes '
        'links to the full 16-issue failure taxonomy and standalone companion repos.\n'
    )
    hook_tester = (
        '- [Claude Code Hook Tester](https://github.com/VoxCore84/claude-code-hook-tester) '
        'by [VoxCore84](https://github.com/VoxCore84) - CLI tool for testing and validating '
        'Claude Code hook configurations. Discovers hooks from settings files, simulates lifecycle '
        'events with realistic payloads, validates JSON responses, and reports pass/fail with '
        'colorized output. Supports event inference from script names and custom payload injection.\n'
    )
    sql_safety = (
        '- [Claude Code SQL Safety](https://github.com/VoxCore84/claude-code-sql-safety) '
        'by [VoxCore84](https://github.com/VoxCore84) - PreToolUse hook that intercepts Bash '
        'and MCP MySQL commands, blocking destructive SQL operations (DROP, DELETE without WHERE, '
        'bulk table removal, schema modifications) with a user confirmation prompt. Configurable '
        'allowlists and pattern overrides via JSON config.\n'
    )

    # Original 0-indexed positions:
    #   234: cchooks
    #   235: Claude Code Hook Comms (HCOM)
    #   236: claude-code-hooks-sdk
    #   237: claude-hooks
    #   238: Claudio
    #
    # Target order:
    #   cchooks
    #   Claude Code Edit Verifier  <-- NEW
    #   Claude Code Guardrails     <-- NEW
    #   Claude Code Hook Comms (HCOM)
    #   Claude Code Hook Tester    <-- NEW
    #   claude-code-hooks-sdk
    #   Claude Code SQL Safety     <-- NEW
    #   claude-hooks
    #   Claudio

    # Work bottom-to-top so indices above don't shift
    # 1. sql_safety after claude-code-hooks-sdk (idx 236) -> insert at 237
    lines.insert(237, sql_safety)
    # 2. hook_tester after Claude Code Hook Comms (idx 235, unshifted) -> insert at 236
    lines.insert(236, hook_tester)
    # 3. guardrails + edit_verifier after cchooks (idx 234, unshifted) -> insert at 235
    lines.insert(235, guardrails)
    lines.insert(235, edit_verifier)

    with open('C:/Users/atayl/VoxCore/tools/publishable/awesome-pr-readme-modified.md', 'w',
              encoding='utf-8', newline='\n') as f:
        f.writelines(lines)

    # Verify
    with open('C:/Users/atayl/VoxCore/tools/publishable/awesome-pr-readme-modified.md', 'r', encoding='utf-8') as f:
        content = f.read()

    start = content.index('### General\n\n- [Britfix')
    end = content.index('<br>\n\n## Slash-Commands')
    for line in content[start:end].split('\n'):
        if line.startswith('- ['):
            name = line.split('](')[0][3:]
            marker = " <-- NEW" if "VoxCore84" in line else ""
            print(f"  {name}{marker}")

    print(f"\nTotal lines: {len(lines)}")


if __name__ == "__main__":
    main()

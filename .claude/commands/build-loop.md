# Build-Fix Loop

Iteratively build the project and fix compilation errors until the build succeeds.

## Tools

Bash(ninja, cd), Read, Edit, Grep, Glob

## Instructions

Run an iterative build-fix cycle on the VoxCore project.

### Build preset selection
Parse the user's argument (if any) to pick the build directory:
- `debug`, `d`, or no argument → `out/build/x64-Debug/`
- `rel`, `r`, `relwithdebinfo` → `out/build/x64-RelWithDebInfo/`
- `scripts`, `s` → same as debug but use `ninja -j20 scripts` (scripts-only)

### Loop procedure

1. **Build**: Run `cd /c/Dev/RoleplayCore/<build-dir> && ninja -j20 2>&1` (or `ninja -j20 scripts` for scripts-only)
2. **Parse**: Extract compiler errors from the output. Ignore warnings unless the user asked to fix them.
3. **Fix**: For each error:
   - Read the source file at the reported line
   - Understand the error in context (check headers, related code)
   - Apply the minimal fix using Edit
4. **Rebuild**: Run the build again
5. **Repeat**: Continue until the build succeeds or you've hit 5 consecutive iterations without progress on the error count
6. **Report**: Summarize all changes made, errors fixed, and any remaining issues

### Rules
- Only fix actual compilation errors — not warnings, not style issues
- If an error is ambiguous or requires an architectural decision, STOP and ask the user
- Never modify files outside `src/` unless explicitly told to
- If the exact same error persists after 2 fix attempts, stop and report it — don't keep guessing
- Group related errors (e.g., all caused by the same missing include) and fix them together
- After a successful build, do a final `git diff --stat` to show what changed

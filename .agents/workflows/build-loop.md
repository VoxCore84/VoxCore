---
description: Build-Fix Loop - Iteratively build the project and fix compilation errors until the build succeeds.
---

// turbo-all

1. Parse the user's argument (if any) to pick the build directory:
- `debug`, `d`, or no argument → `out/build/x64-Debug/`
- `rel`, `r`, `relwithdebinfo` → `out/build/x64-RelWithDebInfo/`
- `scripts`, `s` → same as debug but use `ninja -j4 scripts` (scripts-only)

2. Loop procedure:
   - **Build**: Run `cd /c/Users/atayl/VoxCore/<build-dir> && ninja -j4 2>&1` (or `ninja -j4 scripts` for scripts-only) using `run_command`
   - **Parse**: Extract compiler errors from the output. Ignore warnings unless the user asked to fix them.
   - **Fix**: For each error:
     - Read the source file at the reported line
     - Understand the error in context (check headers, related code)
     - Apply the minimal fix
   - **Rebuild**: Run the build again using `run_command`
   - **Repeat**: Continue until the build succeeds or you've hit 5 consecutive iterations without progress on the error count
   - **Report**: Summarize all changes made, errors fixed, and any remaining issues

### Rules
- Only fix actual compilation errors — not warnings, not style issues
- If an error is ambiguous or requires an architectural decision, STOP and ask the user
- Never modify files outside `src/` unless explicitly told to
- If the exact same error persists after 2 fix attempts, stop and report it — don't keep guessing
- Group related errors (e.g., all caused by the same missing include) and fix them together
- After a successful build, do a final `run_command` of `git diff --stat` to show what changed

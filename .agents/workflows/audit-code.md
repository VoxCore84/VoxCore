# Audit Code Changes

Review recent code changes for correctness, style compliance, and safety.

## Steps
1. Run `git diff HEAD~1` (or specified range) to see changes
2. For each modified C++ file:
   - Check C++20 compliance, 4-space indent, 160-char max line width
   - Verify `#pragma once` for new headers
   - Check for `TC_GAME_API` on public game classes
   - Verify includes order (`"..."` for TC, `<...>` for system)
   - Check RBAC permissions are in correct range (1000+/2100+/3000+)
3. For each modified SQL file:
   - Verify table/column names match actual schema (run DESCRIBE)
   - Check for idempotent operations (IF NOT EXISTS, REPLACE, etc.)
   - Verify no `item_template` usage (should be hotfixes.item_sparse)
   - Verify no `broadcast_text` in world DB
4. For script registrations:
   - Verify `AddSC_*` function exists and is called in `custom_script_loader.cpp`
5. Write audit report to `AI_Studio/Reports/Audits/` with findings

## Output
Structured audit report with: files reviewed, issues found (severity), recommendations, pass/fail.

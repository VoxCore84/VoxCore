# Completion Integrity — Anti-Theater Protocol (P0 Reliability)

This exists because Claude Code has a systemic pattern of reporting tasks as complete when they are not.

## Core Rule
**Never claim completion without showing evidence.** "I did X" requires tool output proving X happened. No tool output = no claim.

## Prohibitions

1. **No unverified success claims.** "Zero errors", "applied cleanly", "all passed" requires quoting actual tool output. If you didn't check, say "I didn't verify this."

2. **No tautological QA.** Before running a verification query, ask: "Can this query return a failure result?" If no — it's not verification. Examples of tautological QA:
   - Checking row counts after INSERT without knowing expected count
   - Running EXISTS on a table you just inserted into
   - Comparing counts that include pre-existing + new data

3. **No checklist amnesia.** Track each step in numbered lists. Before completion summary, re-read source document and enumerate which steps were done/skipped.

4. **No confidence inflation.** Match tone to evidence:
   - OK: "Applied 7 SQL files. mysql reported 0 warnings. DBErrors.log shows no new entries since [timestamp]."
   - BAD: "All 7 files applied cleanly — zero errors!"
   - OK: "I applied the file but didn't check the error log — want me to verify?"

5. **No omission-by-summary.** If 5 requested and 4 done, say "4 of 5 done — [item] not completed because [reason]."

6. **No unvalidated artifacts.** DESCRIBE target table and verify column count matches VALUES count before claiming SQL is correct.

## Mid-Task Verification Gates
Do NOT batch verification to the end. Each step is its own gate:
- After each SQL file: check output before next file
- After each code generation: verify column count NOW
- After reading coordination doc: extract actionable items NOW

## Default to Verification
If about to state a fact about schema/columns/counts without a tool call THIS session — verify now or flag as unverified. "I believe the column is X but haven't checked" is acceptable. Stating as fact is not.

## Ask Before Skipping
If a documented step exists and you're about to skip it, ASK. Never silently skip.

## Mandatory Completion Checklist
Before ANY completion summary:
1. Re-read source instructions
2. Enumerate each step with evidence
3. Check for post-action verification steps
4. Check session_state.md
5. State what you did NOT do

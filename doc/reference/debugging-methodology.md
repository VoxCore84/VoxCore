# Debugging Methodology — MANDATORY PIPELINE

Full debugging methodology for RoleplayCore investigations. CLAUDE.md has the gate definitions; this file has domain-specific recipes and patterns.

**This is a blocking pipeline with hard gates. Skipping a gate is equivalent to writing code that doesn't compile.**

## The 4 Gates

### GATE 1: Collect Data (ALWAYS FIRST — NO EXCEPTIONS)

**You may NOT form a hypothesis, propose a fix, write a summary, or produce any conclusion until you have read the actual data.** "I already know what's wrong" is not an excuse to skip this gate.

**Enforcement rule**: The FIRST tool calls in any bug investigation MUST be data collection (Read files, mysql queries, opcode_analyzer, etc.). If your first action is writing text that contains a conclusion, you have violated the pipeline.

Fan out **parallel agents** to hit ALL relevant sources simultaneously:

#### Always Required (every investigation)
- `Server.log` — errors/warnings around the bug time
- `DBErrors.log` — SQL failures
- `Debug.log` — TC_LOG_DEBUG from the relevant system
- `GM.log` — command execution traces (if commands involved)
- Code path trace — codeintel `find_definition`, `find_references`, `call_hierarchy`

#### For Packet Issues (add these in parallel)
```bash
python opcode_analyzer.py World_parsed.txt              # Full analysis
python opcode_analyzer.py World_parsed.txt --unhandled   # Missing handlers
python opcode_analyzer.py --lookup TRANSMOG              # Specific opcodes
```

#### For Database Issues (add these in parallel)
```sql
-- DESCRIBE the table FIRST
-- SELECT the relevant rows — never UPDATE without SELECT
-- Use mysql MCP for direct queries
```

#### For Spell/Script Issues (add these in parallel)
```bash
# codeintel: search_symbol "HandleSpellEffect"
# codeintel: find_references for the specific handler
```
```sql
SELECT * FROM smart_scripts WHERE entryorguid = ? ORDER BY id;
SELECT ScriptName FROM creature_template WHERE entry = ?;
```

#### For Transmog Issues (add ALL of these in parallel)
```bash
python transmog_debug.py --char <name|guid>              # Character state
python transmog_debug.py --imaid <id...>                 # Resolve IMAIDs
python transmog_debug.py --packet --file Debug.log --nth 1  # Packet from log
```
- Read TransmogSpy SavedVariables: `C:/WoW/_retail_/WTF/Account/1#1/SavedVariables/TransmogSpy.lua`
- WPP parsed output: `wpp-inspect.sh transmog`, `wpp-inspect.sh visible [slot]`

#### For UpdateField / Visibility Issues
```bash
# Search WPP parsed output for the relevant SMSG_UPDATE_OBJECT
wpp-inspect.sh visible [slot]
wpp-inspect.sh transmog
```

**Gate 1 completion check**: Before proceeding, list each data source you collected from. If a relevant source exists and you didn't read it, go back.

### GATE 2: Analyze (Every Claim Needs a Data Citation)

Only after Gate 1 is fully complete:

1. **State hypothesis explicitly**: "X happens because Y"
2. **Cite the data**: Every claim references specific log lines, packet bytes, DB rows, or code paths. No citation = no claim.
3. **Cross-reference IDs**: Use wago-db2 MCP (`db2_lookup`), `transmog_lookup.py`, or mysql MCP to validate every ID
4. **Check for data corruption before blaming code**: Query the tables. Bad data can re-infect through merge/preservation logic.
5. **Decode bitmasks**: IgnoreMask, npcflag, unit_flags — always decode and log which bits are set
6. **Compare expected vs actual**: What SHOULD the data show? What DOES it show? The delta IS the bug.

**Gate 2 completion check**: Re-read your analysis. Does every factual claim cite specific data? If any claim says "the client doesn't send X" without showing the actual packet, it's a violation.

### GATE 3: Propose Fix (Minimal, Root-Cause, Traced)

Only after Gate 2 is fully complete:

1. **One change at a time** — Never combine a parsing fix with a fallback with a DB cleanup
2. **Root cause, not symptom** — If the DB has corrupted data, cleaning the DB is the fix. Code workaround = symptom patch.
3. **Don't add fallback logic to packet parsers** — `Read()` parses bytes. It should NEVER access Player, Item, or DB.
4. **Don't fix writers by patching readers** — If bad data is being written, fix the writer.
5. **Trace downstream** — codeintel `find_references`/`call_hierarchy` before changing any function
6. **Add logging, don't remove it** — Every decision point gets TC_LOG_DEBUG

### GATE 4: Implement, Build, Verify

Only after Gate 3 is approved:

1. Build with `/build-loop`
2. Start fresh — clean state appropriate to the system
3. Test the exact repro steps (not "does it work")
4. Collect ALL outputs again (same sources as Gate 1)
5. Verify the hypothesis — if data doesn't match, **back to Gate 1**
6. Document: update memory topic file with bug, root cause, failed attempts, fix, remaining issues

## Anti-Patterns (HARD VIOLATIONS)

These are the specific failure modes that have caused wasted time:

| Anti-Pattern | What Happens | Why It's Wrong |
|---|---|---|
| **Summary before data** | Write "Issue: X because Y" before reading any files | Conclusion is an assumption, not based on evidence |
| **Fix in same message as bug report** | "The bug is X. Here's the fix:" | Gate 1 and Gate 3 cannot coexist in one response |
| **"I believe" without citation** | "I believe the client omits HEAD" | Show the packet bytes or it's speculation |
| **Churning >30s without tool calls** | Thinking in circles without collecting data | Fan out agents instead — data resolves uncertainty |
| **Sequential data collection** | Read log... wait... read packet... wait... query DB... | Always parallel. Fan out agents for independent sources. |
| **Proposing a fix you haven't traced** | "Just add a fallback in the handler" | codeintel call_hierarchy first. What else calls this? |
| **Carrying forward stale conclusions** | "Last session determined X" without re-verifying | Data may have changed. Re-collect from Gate 1. |

---

## Common Debugging Patterns

### "Server says it applied, but nothing changes visually"
1. Check bitmask/flags — is the slot/feature actually being applied or skipped?
2. Check SMSG_UPDATE_OBJECT — did the relevant UpdateField actually change in the outbound packet?
3. Check the modifier/DB write — was the value actually persisted?
4. If all server-side is correct, it's a client rendering issue — check if `/reload` or relog shows the change.

### "Data is zero/missing in packet"
1. Don't try to fix it server-side with fallbacks — the data genuinely isn't there.
2. Check if a DIFFERENT opcode carries that data (use `opcode_analyzer.py` to find unhandled opcodes sent around the same time).
3. Check if the client sends the data through a different mechanism.
4. Compare against retail packet captures if available.

### "Works for some entries but not others"
1. Map working vs broken entries to their distinguishing attributes — is there a type/flag/category threshold?
2. Check if working entries go through a different code path.
3. Check bitmasks — are broken entries being filtered out?
4. Check DB2/hotfix data — are broken entries missing or corrupted in the data tables?

### "Corrupted data persists across sessions"
1. Identify ALL storage locations (DB tables, UpdateFields, caches)
2. Clean ALL of them — corruption in any one can re-infect the others through merge/preservation logic
3. Verify with SELECT after cleaning
4. Trace how the corruption was written in the first place — fix the writer, not just the data

### "Server crashes or asserts"
1. Get the stack trace from `Crashes/` directory
2. Find the faulting function — use codeintel `find_definition`
3. Check recent changes to that function and its callers (`git log -p -- <file>`)
4. Reproduce with Debug build for full symbols and locals
5. Check for null pointer access, iterator invalidation, or out-of-bounds access

### "Unhandled opcode in packet capture"
1. Look up the opcode in `Opcodes.cpp` — is it STATUS_UNHANDLED with HandleNULL?
2. Check if a handler function exists but isn't registered (search for the likely handler name)
3. Check WPP source for the packet structure definition
4. Check retail behavior — when does the client send this opcode?
5. Implementation order: register opcode → define packet struct with Read() → implement handler → send response

### "DB query returns unexpected results"
1. DESCRIBE the table — column names may not be what you expect (see db-schema-notes.md)
2. Check for hotfix overrides — `hotfix_data` Status=2 entries can hide rows
3. Check cross-DB references — some tables live in `hotfixes` not `world`
4. Verify JOINs — TC uses non-standard column names (e.g. `faction` not `FactionID`)

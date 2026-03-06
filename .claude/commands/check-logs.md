# Check Server Logs

Read and categorize recent server log entries to find errors, warnings, and notable events.

## Tools

Read, Bash(python3, wc), Grep, Glob

## Instructions

Check the VoxCore server logs for errors and notable entries.

### Log files (check in priority order)

**RelWithDebInfo** (primary runtime):
1. `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/DBErrors.log`
2. `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Server.log`
3. `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Debug.log`
4. `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/GM.log`
5. `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Bnet.log`

**Debug** (fallback if RelWithDebInfo logs are empty/missing):
- Same filenames under `out/build/x64-Debug/bin/Debug/`

### Argument handling
- No argument → check all logs, summarize
- `db` or `dberrors` → only DBErrors.log, full detail
- `server` → only Server.log
- `debug` → only Debug.log
- `gm` → only GM.log
- `bnet` → only Bnet.log
- Any other text → treat as a keyword filter, search all logs for matches

### What to do

1. Read the tail of each relevant log (last 200 lines via offset/limit)
2. For **DBErrors.log**: group errors by type, count occurrences, list unique error messages
3. For **Server.log**: highlight crashes, disconnects, assertion failures, startup/shutdown events
4. For **Debug.log**: look for transmog-related entries, packet errors, opcode issues
5. For **GM.log**: show recent commands executed
6. For **Bnet.log**: check for login failures

### Output format

```
## Log Summary (RelWithDebInfo)

### DBErrors.log — X errors
| Category | Count | Example |
|----------|-------|---------|
| ...      | ...   | ...     |

### Server.log — Notable events
- [timestamp] event description
...

### Recommendations
- Actionable items based on what was found
```

If a log file doesn't exist or is empty, just note it and move on.

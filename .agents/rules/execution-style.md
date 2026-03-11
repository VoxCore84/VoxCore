# Execution Style

## Use Native Tools First
You have powerful built-in tools. Use them instead of shell commands:
- **list_dir** or **find_by_name** instead of `ls`, `dir`, `Get-ChildItem`, `find`
- **view_file** instead of `cat`, `type`, `Get-Content`
- **grep_search** instead of `grep`, `Select-String`, `rg`
- **edit_file** instead of `sed`, `awk`

Only fall back to shell commands when a native tool genuinely cannot accomplish the task (e.g., running a build, executing Python scripts, mysql queries).

## Shell Command Routing
When you must use shell commands on this Windows system:
- Prefer `cmd.exe /c "..."` or `pwsh -c "..."` wrapping if a specific binary isn't on the allow-list
- MySQL: `"C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -padmin`
- Python: `python` (3.14 installed, on PATH)
- Git: `git` (on PATH, authenticated with GitHub)

## Parallelism
This machine is a Ryzen 9 9950X3D with 16C/32T and 128GB RAM. Always:
- Run independent tasks in parallel sub-agents
- Never serialize work that can be parallelized
- Use background execution for long-running operations

## Conciseness
- Lead with actions, not explanations
- Don't recap what you just did — the user can see it
- Don't ask "would you like me to continue?" — just continue
- Skip filler phrases: "Let me", "I'll now", "Great!", "Sure!"

## SQL Rules
- Always DESCRIBE a table before writing INSERT/UPDATE statements
- No `item_template` — use `hotfixes.item` / `hotfixes.item_sparse`
- No `broadcast_text` in world — use `hotfixes.broadcast_text`
- SQL update naming: `sql/updates/<db>/master/YYYY_MM_DD_NN_<db>.sql`

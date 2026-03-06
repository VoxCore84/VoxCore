# SOAP Remote Command

Send a GM command to the running worldserver via SOAP.

## Tools

Bash(bash, curl)

## Instructions

Send the user's command to the running VoxCore worldserver via the SOAP remote console.

### Usage
The user provides a GM command as the argument, e.g.:
- `/soap .server info`
- `/soap .reload smart_scripts`
- `/soap .lookup spell fireball`

### How to send

**Primary method** — helper script:
```
bash C:/Users/atayl/source/wago/tc_soap.sh "<command>"
```

**Fallback** — if the helper script doesn't exist, use curl directly:
```
curl -s -u "1#1:gm" \
  -H "Content-Type: text/xml" \
  -d '<?xml version="1.0" encoding="utf-8"?><SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="urn:TC"><SOAP-ENV:Body><ns1:executeCommand><command>COMMAND_HERE</command></ns1:executeCommand></SOAP-ENV:Body></SOAP-ENV:Envelope>' \
  http://127.0.0.1:7878/
```

### Connection details
- Endpoint: `http://127.0.0.1:7878/`
- Auth: game account `1#1`, password `gm` (SecurityLevel 3)
- SOAP namespace: `urn:TC`
- Requires `SOAP.Enabled=1` in worldserver.conf

### Rules
- If the server isn't running or SOAP is disabled, report the connection error clearly
- Show the full server response text
- For `.reload` commands, note which reloads need a full restart vs. hot-reload
- **Dangerous commands require user confirmation first**:
  - `.server shutdown` / `.server restart`
  - `.server exit`
  - `.reset` commands
  - `.character delete`
  - Any command that modifies accounts or deletes data
- For multi-word arguments, the user may omit the leading dot — add it if missing

### Common commands reference
| Command | What it does |
|---------|-------------|
| `.server info` | Uptime, player count, active connections |
| `.reload all` | Reload all cached data tables |
| `.reload creature_template` | Reload creature templates |
| `.reload smart_scripts` | Reload SmartAI scripts |
| `.reload spell_scripts` | Reload spell script assignments |
| `.reload config` | Reload worldserver.conf |
| `.lookup spell <name>` | Search spells by name |
| `.lookup item <name>` | Search items by name |
| `.list creature <entry>` | List spawned creatures by entry |
| `.debug send opcode <id>` | Send a test opcode to your session |

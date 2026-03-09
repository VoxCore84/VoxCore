---
description: Decode Packet Log - Run WowPacketParser on the server's packet log to produce human-readable text and SQL output.
---

// turbo-all

## Arguments

$ARGUMENTS — Optional: path to a specific .pkt file. Defaults to the server's PacketLog/World.pkt.

## Instructions

Decode a `.pkt` packet capture file using WowPacketParser (WPP).

### Setup

- **WPP executable**: `C:/Users/atayl/VoxCore/ExtTools/WowPacketParser/WowPacketParser.exe`
- **Default .pkt location**: `C:/Users/atayl/VoxCore/out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/PacketLog/World.pkt`
- **Config**: `C:/Users/atayl/VoxCore/ExtTools/WowPacketParser/WowPacketParser.dll.config` (TargetedDatabase=10 Midnight, all SQL outputs enabled, SplitSQLFile=true)

### Procedure

1. **Determine input file**: Use `$ARGUMENTS` if provided, otherwise use the default PacketLog/World.pkt path
2. **Verify the .pkt file exists** and is non-empty using `list_dir` or `run_command`. If it doesn't exist or is 0 bytes, tell the user.
3. **Remove stale output files**: Delete any existing `*_parsed.txt`, `*_errors.txt`, and `*.sql` files in the same directory as the input .pkt to avoid "file in use" errors using `run_command rm`.
4. **Run WPP**:
   Use `run_command` with a WaitMsBeforeAsync of 300000ms:
   `cd "C:/Users/atayl/VoxCore/ExtTools/WowPacketParser" && ./WowPacketParser.exe "<path_to_pkt>"`
5. **List output files**: Show all generated files with sizes using `list_dir`:
   - `*_parsed.txt` — human-readable packet decode (main output)
   - `*_errors.txt` — packets that failed to parse (if any)
   - `*.sql` / `*_world.sql` / `*_hotfixes.sql` / `*_WPP.sql` — extracted SQL data (if SplitSQLFile=true)
6. **Summarize**: Report total packets parsed, any errors, and what SQL tables had data.

### Troubleshooting

- **"being used by another process"** on input: Worldserver is running. Stop it or copy .pkt first
- **"Save file ... is in use"** on output: A text editor has the output file open. Close it or delete the file
- **NullReferenceException in LoadBroadcastText**: The `wpp` database may be missing — non-fatal, parsing still works
- **"DBC folder not found"**: DBC/DB2 files not extracted to `C:/Users/atayl/VoxCore/ExtTools/WowPacketParser/dbc/enUS/` — non-fatal, just means no DBC name resolution
- **Empty output**: The sniff may have been captured while idle — need actual gameplay packets

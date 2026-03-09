# CLAUDE CODE - ONE-TIME PROJECT BOOTSTRAP

**Execution Context:**
The user has initialized the `/AI_Studio/Projects/` hierarchy, but the physical folders for `idTIP`, `TongueAndQuill`, and `DiscordBot` are completely empty. The actual source code for these projects is currently scattered across `C:\Users\atayl\VoxCore\` or the WoW Client directory. 

You must act as the Project Organizer and immediately pull these projects into the Studio via Windows Symlinks so the Antigravity auditor agents have files to look at.

## Instructions
Execute the following steps using your local terminal/Git access immediately:

### 1. Locate the Discord Bot
1. Search the `VoxCore` directory for the physical Python files related to the Discord Bot (they might be in `.agents/`, `tools/`, or a custom directory).
2. Once you find its master folder, generate a Windows Directory Junction (`mklink /J`) inside `C:\Users\atayl\VoxCore\AI_Studio\Projects\DiscordBot\Z_SourceCode` pointing directly to where the bot actually lives.

### 2. Locate the idTIP Addon
1. This is a World of Warcraft Addon. Search inside `C:\WoW\_retail_\Interface\AddOns\idTIP` (or wherever the `idTip.toc` file currently resides).
2. Generate a Windows Directory Junction (`mklink /J`) inside `C:\Users\atayl\VoxCore\AI_Studio\Projects\idTIP\Z_SourceCode` pointing directly to the addon folder in the WoW client directory.

### 3. Locate the Tongue and Quill Addon
1. This is a World of Warcraft Addon. Search inside `C:\WoW\_retail_\Interface\AddOns\TongueAndQuill` (or wherever the `.toc` file resides).
2. Generate a Windows Directory Junction (`mklink /J`) inside `C:\Users\atayl\VoxCore\AI_Studio\Projects\TongueAndQuill\Z_SourceCode` pointing directly to the addon folder in the WoW client directory.

---
## Post-Initialization
You must formally update `claude_memory.md` stating that:
* The `idTIP` Source Code is symlinked via the Studio.
* The `TongueAndQuill` Source Code is symlinked via the Studio.
* The `DiscordBot` Source Code is symlinked via the Studio.

Acknowledge directly to the user when the directory symlinks have been fully built so they can initialize the Antigravity Auditor instances!

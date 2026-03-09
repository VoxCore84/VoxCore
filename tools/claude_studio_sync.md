# CLAUDE CODE - AI STUDIO SYNC OVERRIDE

**Execution Context:**
Antigravity has instituted a global "AI Studio" routing hierarchy to prevent our workspace from becoming hopelessly fragmented. You must read this and permanently adopt the new file routing philosophy. 

## The Core Concept
The user is tired of hunting across `C:\Users\atayl\VoxCore\tools\`, `\wago\`, `\sql\`, and `\doc\` to find files, specs, and outputs. We have created a centralized hub at `C:\Users\atayl\VoxCore\AI_Studio\`.

### The Studio Hierarchy
1. `AI_Studio\1_Inbox\`
    - The user has a button that automatically scrapes downloaded ChatGPT specs from their desktop and dumps them here. **You must watch this folder.** If the user asks you to implement a spec, it will be in here.
2. `AI_Studio\2_Active_Specs\`
    - Once you read an inbox spec and begin working on it, MOVE IT to this folder so the Inbox stays clean.
3. `AI_Studio\3_Audits\`
    - If you finish a feature, Antigravity will be asked to audit it, and the resulting mathematical pass/fail `.md` will appear here.
4. `AI_Studio\4_Archive\`
    - Move completed specs and audits here once a feature is successfully pushed to Git.

### The Dynamic Sub-Project Workspaces
The user is simultaneously developing dozens of projects scattered across `C:\Users\atayl\VoxCore\`. 
We have started carving out dedicated domains like `VoxCore`, `idTIP`, `TongueAndQuill`, and `DiscordBot`.

**CRITICAL DIRECTIVE FOR YOU:**
If ChatGPT gives you a spec for a project that doesn't have a folder yet, **you must create one:** `mkdir "C:\Users\atayl\VoxCore\AI_Studio\Projects\[NewProjectName]"`.

When you generate high-level documentation, cheat sheets, or runbooks, DO NOT scatter them loosely. You must save them inside their respective `AI_Studio\Projects\[Name]\` folder.

If a project spans multiple heavy external directories (like `\wago\` data mining tools or `\sql\updates\pending\`), you should generate **Windows Directory Symlinks** (`mklink /D` or `/J`) pointing those messy deeper folders straight into the `AI_Studio\Projects\[Name]\` folder so the user has a 1-click shortcut.

---
## ACTION REQUIRED: Update Your Global State
1. **Understand Routing:** The user will no longer paste massive prompts into your terminal. They will drop a markdown file into `AI_Studio\1_Inbox\` and tell you to execute it.
2. **Update** `doc/claude_memory.md` to permanently capture the existence of the `AI_Studio` routing folders and your responsibility to keep the workspace clean via Symlinks.
3. **Acknowledge** in your response that the AI Studio sync is complete and you understand the Inbox scraping flow.

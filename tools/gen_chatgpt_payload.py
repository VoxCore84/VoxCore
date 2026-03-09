import os

output_file = r"C:\Users\atayl\OneDrive\Desktop\CommandCenter_Context.txt"

payload = """# VoxCore Command Center Context

Below is the current source code for the VoxCore Command Center web dashboard.
Please read this file. I need a specification to overhaul its UI to be cleaner, less cluttered, and explicitly add a new 'Task Tracker' module that reads and displays tasks from a local JSON or Markdown file (e.g. C:\\Users\\atayl\\.gemini\\antigravity\\brain\\...\\task.md).

"""

files_to_bundle = [
    r"C:\Users\atayl\VoxCore\tools\command-center\app.py",
    r"C:\Users\atayl\VoxCore\tools\command-center\templates\index.html"
]

for file_path in files_to_bundle:
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    filename = os.path.basename(file_path)
    if "index.html" in filename:
        ext = "html"
    else:
        ext = "python"
        
    payload += f"\n## File: `{filename}`\n```{ext}\n"
    payload += content
    payload += "\n```\n"

with open(output_file, "w", encoding="utf-8") as f:
    f.write(payload)

print("Generated Context Payload for ChatGPT on Desktop.")

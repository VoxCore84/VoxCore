import os
from pathlib import Path

def find_project_root(marker_file="AI_Studio/0_Central_Brain.md", max_depth=10):
    """
    Finds the root of the project by traversing up the directory tree
    until the `marker_file` is located.
    """
    current_dir = Path(__file__).resolve().parent

    for _ in range(max_depth):
        if (current_dir / marker_file).exists():
            return current_dir
        
        parent_dir = current_dir.parent
        if current_dir == parent_dir:
            break
            
        current_dir = parent_dir
    
    # Fallback to current working directory if not found, though ideally this should raise an Exception
    # or fallback to an environment variable in a real production environment.
    fallback = os.environ.get("VOXCORE_ROOT")
    if fallback and Path(fallback).exists():
        return Path(fallback)
        
    return Path.cwd()

if __name__ == "__main__":
    root = find_project_root()
    print(f"Project root resolved to: {root}")

import os

def generate_inventory(root_dir):
    ignore_dirs = {'.git', '.vs', 'out', 'build', 'dep', 'tests', 'src', '.cache', 'node_modules', 'AI_Studio'}
    inventory = []
    
    for item in sorted(os.listdir(root_dir)):
        item_path = os.path.join(root_dir, item)
        if os.path.isdir(item_path):
            if item in ignore_dirs:
                continue
            
            inventory.append(f"### Directory: `/{item}/`")
            sub_items = []
            try:
                for sub in sorted(os.listdir(item_path))[:20]: # Limit to 20 for brevity
                    if os.path.isdir(os.path.join(item_path, sub)):
                        sub_items.append(f"  - `/{sub}/`")
                    else:
                        sub_items.append(f"  - `{sub}`")
                
                inventory.extend(sub_items)
                if len(os.listdir(item_path)) > 20:
                    inventory.append("  - ... (truncated)")
            except:
                inventory.append("  - (Access Denied / Error)")
            inventory.append("")
    return "\n".join(inventory)

log_out = generate_inventory(r"C:\Users\atayl\VoxCore")
with open(r"C:\Users\atayl\VoxCore\tools\voxcore_inventory.md", "w") as f:
    f.write("# VoxCore Root Directory Inventory\n\n")
    f.write(log_out)

import os
import time
import shutil
import threading
from datetime import datetime
import pystray
from PIL import Image, ImageDraw

EXCLUDED_DIR = r"C:\Users\atayl\OneDrive\Desktop\Excluded"
INBOX_DIR = r"C:\Users\atayl\VoxCore\AI_Studio\1_Inbox"
ALLOWED_EXTENSIONS = {".md", ".txt", ".json", ".csv", ".sql", ".lua"}
running = True

def log(msg: str):
    # Log to a simple file since we will run headless
    with open(r"C:\Users\atayl\VoxCore\tools\ai_router_log.txt", "a") as f:
        f.write(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}\n")

def ensure_dir(path: str):
    if not os.path.exists(path):
        os.makedirs(path)

def router_loop():
    ensure_dir(EXCLUDED_DIR)
    ensure_dir(INBOX_DIR)
    while running:
        try:
            for filename in os.listdir(EXCLUDED_DIR):
                ext = os.path.splitext(filename)[1].lower()
                if ext in ALLOWED_EXTENSIONS:
                    src_path = os.path.join(EXCLUDED_DIR, filename)
                    dst_path = os.path.join(INBOX_DIR, filename)
                    
                    try:
                        os.rename(src_path, src_path)
                    except OSError:
                        continue # File is locked
                        
                    try:
                        shutil.move(src_path, dst_path)
                        log(f"Routed: {filename} -> AI Studio Inbox")
                    except Exception as e:
                        log(f"Failed to move {filename}: {e}")
        except Exception as e:
            log(f"Error reading directory: {e}")
            
        time.sleep(3.0)

def create_image():
    # Generate a simple blue icon with a white inner square for the system tray
    width = 64
    height = 64
    color = (0, 128, 255)
    image = Image.new('RGB', (width, height), color)
    dc = ImageDraw.Draw(image)
    dc.rectangle((width // 4, height // 4, width * 3 // 4, height * 3 // 4), fill=(255, 255, 255))
    return image

def on_quit(icon, item):
    global running
    running = False
    log("Shutting down AI Studio Router via System Tray.")
    icon.stop()

def main():
    log("Starting AI Studio Background Router...")
    
    t = threading.Thread(target=router_loop)
    t.start()
    
    icon = pystray.Icon(
        "AI_Studio_Router", 
        create_image(), 
        "AI Studio Router (Hover for status)", 
        menu=pystray.Menu(pystray.MenuItem("Quit", on_quit))
    )
    icon.run()

if __name__ == "__main__":
    main()

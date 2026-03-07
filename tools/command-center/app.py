"""
VoxCore Command Center — WoW-themed launcher dashboard.

Usage:
    python app.py              # Start on http://localhost:5050
    python app.py --port 8080  # Custom port
    python app.py --prep       # Only prepare assets (icons, art), don't start server
"""
import argparse
import os
import subprocess
import sys
import threading
import time
from pathlib import Path

from flask import Flask, jsonify, render_template, request, send_from_directory
from PIL import Image

# ═══════════════════════════════════════════════════════════════════
#  PATHS
# ═══════════════════════════════════════════════════════════════════

APP_DIR      = Path(__file__).resolve().parent
STATIC_DIR   = APP_DIR / "static"
ICON_SRC     = Path(r"C:\Users\atayl\VoxCore\wago\att_icons_export\8K_Format\wow_icons\large")
ICON_WEB_DIR = STATIC_DIR / "icons"
ART_SRC      = Path(r"C:\Users\atayl\VoxCore\wago\att_icons_export\8K_Format\scenic_art")
ART_WEB_DIR  = STATIC_DIR / "art"

ROOT    = r"C:\Users\atayl\VoxCore"
RUNTIME = os.path.join(ROOT, r"out\build\x64-RelWithDebInfo\bin\RelWithDebInfo")
TOOLS   = os.path.join(ROOT, "tools")
SC_DIR  = os.path.join(TOOLS, "shortcuts")
WAGO    = os.path.join(ROOT, "wago")
EXTTOOLS = os.path.join(ROOT, "ExtTools")
CHROME  = r"C:\Program Files\Google\Chrome\Application\chrome.exe"

ICON_WEB_SIZE = 128  # px

app = Flask(__name__, static_folder=str(STATIC_DIR))

# ═══════════════════════════════════════════════════════════════════
#  ASSET PREPARATION
# ═══════════════════════════════════════════════════════════════════

def prepare_icon(png_name: str) -> str:
    """Ensure a web-sized icon exists, return the web filename."""
    ICON_WEB_DIR.mkdir(parents=True, exist_ok=True)
    out = ICON_WEB_DIR / png_name
    if out.exists():
        return png_name
    src = ICON_SRC / png_name
    if not src.exists():
        return png_name
    try:
        img = Image.open(src).convert("RGBA")
        img = img.resize((ICON_WEB_SIZE, ICON_WEB_SIZE), Image.LANCZOS)
        img.save(out, "PNG", optimize=True)
    except Exception as e:
        print(f"  WARN: Failed to convert icon {png_name}: {e}")
    return png_name


def prepare_art():
    """Downscale art assets to web-friendly sizes."""
    ART_WEB_DIR.mkdir(parents=True, exist_ok=True)
    conversions = [
        (ART_SRC / "dungeon_backgrounds" / "midnight.png", "bg-midnight.jpg", 1920),
        (ART_SRC / "z_expansion_logos" / "Logo_MN.png", "logo-midnight.png", 400),
    ]
    for src, dst_name, max_w in conversions:
        dst = ART_WEB_DIR / dst_name
        if dst.exists():
            continue
        if not src.exists():
            print(f"  WARN: {src} not found, skipping")
            continue
        try:
            img = Image.open(src)
            ratio = max_w / img.width
            new_size = (max_w, int(img.height * ratio))
            img = img.resize(new_size, Image.LANCZOS)
            if dst_name.endswith(".jpg"):
                img = img.convert("RGB")
                img.save(dst, "JPEG", quality=85, optimize=True)
            else:
                img.save(dst, "PNG", optimize=True)
            print(f"  Art: {dst_name} ({new_size[0]}x{new_size[1]})")
        except Exception as e:
            print(f"  WARN: Failed to process art {dst_name}: {e}")


# ═══════════════════════════════════════════════════════════════════
#  SHORTCUT DATA — mirrors create_shortcuts.py
# ═══════════════════════════════════════════════════════════════════

CATEGORIES = [
    {
        "id": "server",
        "name": "Server",
        "icon": "inv_shield_04.png",
        "desc": "Launch and manage the game server stack",
        "shortcuts": [
            {"name": "Play (Start All)", "icon": "inv_hearthstone_gold.png",
             "desc": "ONE CLICK TO PLAY — starts MySQL, bnetserver, worldserver, and Arctium Game Launcher in sequence. Needs admin for MySQL service.",
             "cmd": ["cmd.exe", "/k", f"{SC_DIR}\\start_all.bat"], "cwd": RUNTIME},
            {"name": "Stop All", "icon": "ability_creature_cursed_02.png",
             "desc": "Clean shutdown — kills worldserver + bnetserver processes and stops the MySQL80 Windows service.",
             "cmd": ["cmd.exe", "/k", f"{SC_DIR}\\stop_all.bat"], "cwd": RUNTIME},
            {"name": "Worldserver (solo)", "icon": "inv_misc_head_dragon_blue.png",
             "desc": "Launch ONLY worldserver.exe (RelWithDebInfo). Assumes MySQL and bnetserver are already running. Console stays open for server commands.",
             "cmd": [os.path.join(RUNTIME, "worldserver.exe")], "cwd": RUNTIME},
            {"name": "Bnetserver (solo)", "icon": "spell_nature_lightning.png",
             "desc": "Launch ONLY bnetserver.exe. Handles account auth and realm list. Must be running before worldserver.",
             "cmd": [os.path.join(RUNTIME, "bnetserver.exe")], "cwd": RUNTIME},
            {"name": "Start MySQL (solo)", "icon": "inv_datacrystal06.png",
             "desc": "Start the MySQL80 Windows service only. Needs admin. Use when you want the database without starting game servers.",
             "cmd": ["cmd.exe", "/k", f"{SC_DIR}\\start_mysql.bat"], "cwd": ROOT},
        ]
    },
    {
        "id": "build",
        "name": "Build",
        "icon": "inv_blacksmith_anvil.png",
        "desc": "Compile and configure the server",
        "shortcuts": [
            {"name": "1. Configure CMake", "icon": "inv_misc_gear_01.png",
             "desc": "STEP 1 — Run after adding new source files or changing CMake options. Configures both x64-Debug and x64-RelWithDebInfo presets.",
             "cmd": ["cmd.exe", "/k", f"{TOOLS}\\build\\configure.bat"], "cwd": ROOT},
            {"name": "2. Build Release", "icon": "inv_hammer_03.png",
             "desc": "STEP 2 — Full x64-RelWithDebInfo build (primary runtime, ~17s startup). This is the build you play with.",
             "cmd": ["cmd.exe", "/k", f"{TOOLS}\\build\\build.bat"], "cwd": ROOT},
            {"name": "Build Debug", "icon": "inv_hammer_05.png",
             "desc": "Full x64-Debug build (~60s startup). Use for breakpoints and step-through debugging in VS 2026.",
             "cmd": ["cmd.exe", "/k", f"{TOOLS}\\build\\build_debug.bat"], "cwd": ROOT},
            {"name": "Build Scripts Only", "icon": "inv_misc_scrollrolled01.png",
             "desc": "FAST ITERATION — builds only the 'scripts' ninja target in RelWithDebInfo. Much faster than full build when you only changed Custom/ scripts.",
             "cmd": ["cmd.exe", "/k", f"{SC_DIR}\\build_scripts_rel.bat"], "cwd": ROOT},
        ]
    },
    {
        "id": "pipeline",
        "name": "Pipeline",
        "icon": "inv_misc_treasurechest04b.png",
        "desc": "Data pipeline — run these in order after a build bump",
        "shortcuts": [
            {"name": "1. DB Snapshot", "icon": "inv_misc_book_01.png", "step": 1,
             "desc": "ALWAYS DO THIS FIRST. Creates a mysqldump backup of all 5 databases with a timestamped label. Use db_snapshot.py rollback to undo.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\db_snapshot.py\" snapshot --label pre-pipeline"], "cwd": WAGO},
            {"name": "2. TACT Extract", "icon": "inv_datacrystal01.png", "step": 2,
             "desc": "Extracts raw DB2 files from local WoW CASC install → converts to CSV via DBC2CSV. --verify compares row counts. Takes ~50s.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\tact_extract.py\" --verify"], "cwd": WAGO},
            {"name": "3. Merge CSVs", "icon": "inv_datacrystal03.png", "step": 3,
             "desc": "Combines TACT CSVs (client ground truth) with Wago CSVs (CDN hotfix content). Output: merged_csv/{build}/enUS/ — single source of truth.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\merge_csv_sources.py\""], "cwd": WAGO},
            {"name": "4. Hotfix Repair", "icon": "ability_repair.png", "step": 4,
             "desc": "Compares hotfix DB tables against merged CSVs and fixes mismatches. Run --batch 1 through 5 (change the number). ~71 MB SQL total.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\repair_hotfix_tables.py\" --batch 1"], "cwd": WAGO},
            {"name": "5. Raidbots Import", "icon": "inv_misc_coin_02.png", "step": 5,
             "desc": "8-step pipeline: quest chains → fix chains → objectives → POI → item locale (6 languages) → fix orphans. Verifies zero quest chain cycles. Use --regenerate after new JSONs.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\raidbots\\run_all_imports.py\""], "cwd": WAGO},
            {"name": "6. Health Check", "icon": "spell_holy_divinepurpose.png", "step": 6,
             "desc": "Validates referential integrity of the world DB after imports. Checks for orphaned references, missing templates, broken loot chains.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\world_health_check.py\""], "cwd": WAGO},
            {"name": "7. DB Errors", "icon": "ability_creature_cursed_01.png", "step": 7,
             "desc": "Parses DBErrors.log and categorizes ALL error patterns by system with counts and fix descriptions. Run after server startup.",
             "cmd": ["cmd.exe", "/k", f"python \"{TOOLS}\\parse_dberrors.py\""], "cwd": ROOT},
            {"name": "8. Optimize DB", "icon": "ability_rogue_sprint.png", "step": 8,
             "desc": "OPTIONAL — ALTER TABLE FORCE on InnoDB tables >10 MB across all databases. Reclaims space after bulk imports. Reports before/after sizes.",
             "cmd": ["cmd.exe", "/k", f"{TOOLS}\\_optimize_db.bat"], "cwd": TOOLS},
            {"name": "Wago DB2 Download", "icon": "inv_misc_questionmark.png",
             "desc": "ALTERNATIVE to TACT Extract — downloads DB2 CSVs directly from wago.tools website. Slower but doesn't need a local WoW install.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\wago_db2_downloader.py\""], "cwd": WAGO},
            {"name": "DB Snapshot List-Rollback", "icon": "inv_misc_book_03.png",
             "desc": "View all database snapshots. To rollback: db_snapshot.py rollback --id N --confirm. To prune: db_snapshot.py prune --keep 5.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\db_snapshot.py\" list"], "cwd": WAGO},
        ]
    },
    {
        "id": "packets",
        "name": "Packets",
        "icon": "inv_misc_spyglass_02.png",
        "desc": "Capture, parse, and analyze network packets",
        "shortcuts": [
            {"name": "Dev Session", "icon": "inv_hearthstone_gold.png",
             "desc": "THE SMART LAUNCHER — archives previous session, starts bnet+world with EXIT trap, auto-runs WPP on World.pkt when you Ctrl+C, then runs Packet Scope.",
             "cmd": ["cmd.exe", "/k", f"bash \"{ROOT}\\tools-dev\\tc-packet-tools\\start-worldserver.sh\""], "cwd": RUNTIME},
            {"name": "1. YMIR Sniffer", "icon": "ability_hunter_snipershot.png",
             "desc": "Retail packet sniffer for 12.0.1 build 66263. Launch BEFORE opening the game client. Captures live traffic into .pkt files.",
             "cmd": [os.path.join(EXTTOOLS, "ymir_retail_12.0.1.66263", "ymir_retail.exe")],
             "cwd": os.path.join(EXTTOOLS, "ymir_retail_12.0.1.66263")},
            {"name": "2. WowPacketParser", "icon": "inv_misc_spyglass_03.png",
             "desc": "Parses .pkt captures into human-readable text + SQL extracts. Drag-and-drop a .pkt file or use the GUI.",
             "cmd": [os.path.join(EXTTOOLS, "WowPacketParser", "WowPacketParser.exe")],
             "cwd": os.path.join(EXTTOOLS, "WowPacketParser")},
            {"name": "3. Packet Scope", "icon": "ability_rogue_bloodyeye.png",
             "desc": "Analyzes WPP output with transmog-specific decoding. Finds CMSG/SMSG_TRANSMOG packets, decodes outfit data, checks addon messages.",
             "cmd": ["cmd.exe", "/k", f"python \"{TOOLS}\\packet_scope.py\""], "cwd": ROOT},
            {"name": "4. Opcode Analyzer", "icon": "inv_letter_02.png",
             "desc": "Builds opcode dictionary from Opcodes.h/cpp, cross-refs with WPP output. Use --lookup TRANSMOG to search, --top 20 for most-seen.",
             "cmd": ["cmd.exe", "/k", f"python \"{TOOLS}\\opcode_analyzer.py\""], "cwd": ROOT},
        ]
    },
    {
        "id": "audits",
        "name": "Audits",
        "icon": "inv_misc_questionmark.png",
        "desc": "Data quality audits — read-only, safe to run anytime",
        "shortcuts": [
            {"name": "NPC Audit (27 checks)", "icon": "ability_hunter_pet_assist.png",
             "desc": "27 audits: levels, flags, faction, classification, type, duplicates, phases, missing, display, names, scale, speed, equipment, gossip, waypoints, SmartAI, loot, auras, and more.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\npc_audit.py\" --help"], "cwd": WAGO},
            {"name": "Quest Audit (15 checks)", "icon": "inv_misc_scrollrolled01c.png",
             "desc": "15 audits: broken chains, exclusive groups, missing givers/enders, invalid objectives/rewards, missing quests, orphans, POI, questline cross-ref, addon sync.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\quest_audit.py\" --help"], "cwd": WAGO},
            {"name": "GO Audit (15 checks)", "icon": "inv_misc_gear_03.png",
             "desc": "15 GameObject audits: duplicates, phases, display, type, scale, loot, quest refs, pools, events, names, SmartAI, spawntime, addon orphans, missing, faction.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\go_audit.py\" --help"], "cwd": WAGO},
            {"name": "Transmog Validate", "icon": "inv_chest_plate01.png",
             "desc": "Cross-refs wow.tools.local DB2 vs MySQL hotfixes. Missing rows, FK violations, value mismatches, TransmogSet resolution, illusion IDs. Runs in <1s across 155K IMAIDs.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\validate_transmog.py\""], "cwd": WAGO},
            {"name": "Transmog Debug", "icon": "inv_chest_plate05.png",
             "desc": "Full transmog state viewer. Use: --char Hexandchill, --imaid 304252, --outfit 7, --diff 7, --log (Debug.log), --spy (addon data).",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\transmog_debug.py\" --help"], "cwd": WAGO},
            {"name": "Transmog Lookup", "icon": "inv_chest_plate03.png",
             "desc": "DB2 cross-reference. Use: imaid <id>, search <name>, dt (DisplayType table), reverse <itemid>, analyze <logfile>, batch <strings>.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\transmog_lookup.py\" --help"], "cwd": WAGO},
            {"name": "Scraper v3 (Tor Army)", "icon": "inv_misc_web_01.png",
             "desc": "Async swarm scraper — 400 Tor instances, 600K-1M pages/hr. --smoke 50 --targets npc --workers 10 --start-tor for testing.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\scraper_v3.py\" --help"], "cwd": WAGO},
        ]
    },
    {
        "id": "web",
        "name": "Web",
        "icon": "spell_arcane_portaldalaran.png",
        "desc": "Dashboards, documentation, and web tools",
        "shortcuts": [
            {"name": "VoxCore Docs", "icon": "inv_misc_book_05.png",
             "desc": "Project documentation website — 11 pages covering framework, pipeline, tooling, AI workflow, status, and results.",
             "cmd": [CHROME, "--app=file:///C:/Users/atayl/VoxCore/website/site/index.html"]},
            {"name": "Task Tracker", "icon": "achievement_guildperk_workingovertime.png",
             "desc": "GitHub issue/PR tracker dashboard for VoxCore84/RoleplayCore. Shows open issues, recent PRs, task status.",
             "cmd": [CHROME, "--app=file:///C:/Users/atayl/cowork/outputs/roleplaycore-tracker.html"]},
            {"name": "ATT Browser", "icon": "achievement_guildperk_mobilebanking.png",
             "desc": "AllTheThings database browser — Flask web UI backed by SQLite. Tree navigation, search, detail views. Opens on localhost.",
             "cmd": ["cmd.exe", "/k", f"python \"{WAGO}\\att_browser\\app.py\""],
             "cwd": os.path.join(WAGO, "att_browser")},
            {"name": "WebTerm", "icon": "trade_engineering.png",
             "desc": "Web-based terminal on localhost:7681. Opens in Chrome app mode. Cowork can access this to run commands remotely.",
             "cmd": [os.path.join(EXTTOOLS, "launch-webterm.bat")], "cwd": EXTTOOLS},
            {"name": "Update Website", "icon": "inv_letter_01.png",
             "desc": "Rebuild VoxCore docs site from local sources, then git add + commit + push. Deploys to GitHub Pages in ~30 seconds.",
             "cmd": ["cmd.exe", "/k", f"{ROOT}\\website\\update_site.bat"],
             "cwd": os.path.join(ROOT, "website")},
            {"name": "AI Toolkit Reference", "icon": "inv_misc_book_03.png",
             "desc": "Claude AI toolkit reference — all MCP servers, slash commands, skills, and automation used in this project.",
             "cmd": [CHROME, "--app=file:///C:/Users/atayl/VoxCore/doc/AI-Toolkit-Reference.html"]},
        ]
    },
    {
        "id": "tools",
        "name": "Tools",
        "icon": "inv_misc_wrench_01.png",
        "desc": "Utilities and quick access",
        "shortcuts": [
            {"name": "wow.tools.local", "icon": "inv_misc_spyglass_01.png",
             "desc": "Local DB2 data browser at http://localhost:5000 (build 66263). Browse all 1,097 DB2 tables. Waits for startup then opens browser.",
             "cmd": ["cmd.exe", "/k", f"{EXTTOOLS}\\WoW.tools\\start_wtl.bat"],
             "cwd": os.path.join(EXTTOOLS, "WoW.tools")},
            {"name": "DBC2CSV", "icon": "inv_datacrystal06.png",
             "desc": "GUI tool to convert raw .db2/.dbc files to CSV. Drag-and-drop or browse. Used by TACT Extract internally.",
             "cmd": [os.path.join(EXTTOOLS, "DBC2CSV", "DBC2CSV.exe")],
             "cwd": os.path.join(EXTTOOLS, "DBC2CSV")},
            {"name": "SpellCreator", "icon": "inv_wand_07.png",
             "desc": "Spell visual effect creator GUI (141 MB standalone app). Create and preview SpellVisualKit effects.",
             "cmd": [os.path.join(ROOT, "addons", "SpellCreator", "SpellCreator.exe")],
             "cwd": os.path.join(ROOT, "addons", "SpellCreator")},
            {"name": "Restart Cowork", "icon": "inv_misc_enggizmos_03.png",
             "desc": "Force-restart Cowork (Claude Desktop) — kills processes, restarts service, clears temp. Needs admin.",
             "cmd": ["cmd.exe", "/k", f"{EXTTOOLS}\\restart-cowork.bat"], "cwd": ROOT},
            {"name": "Server Logs", "icon": "inv_misc_note_01.png",
             "desc": "Open server runtime directory — Server.log, DBErrors.log, Debug.log, GM.log, worldserver.conf, PacketLog/.",
             "cmd": ["explorer.exe", RUNTIME]},
            {"name": "Project Folder", "icon": "inv_misc_head_dragon_bronze.png",
             "desc": "Open VoxCore project root in Explorer.",
             "cmd": ["explorer.exe", ROOT]},
        ]
    },
]


# ═══════════════════════════════════════════════════════════════════
#  FLASK ROUTES
# ═══════════════════════════════════════════════════════════════════

@app.route("/")
def index():
    return render_template("index.html", categories=CATEGORIES)


@app.route("/api/launch", methods=["POST"])
def launch():
    data = request.get_json(silent=True)
    if not data:
        return jsonify({"ok": False, "error": "Invalid request"}), 400
    cat_id = data.get("category")
    item_idx = data.get("index")

    cat = next((c for c in CATEGORIES if c["id"] == cat_id), None)
    if not cat or item_idx is None or item_idx < 0 or item_idx >= len(cat["shortcuts"]):
        return jsonify({"ok": False, "error": "Invalid shortcut"}), 400

    item = cat["shortcuts"][item_idx]
    cmd = item.get("cmd", [])
    cwd = item.get("cwd")

    try:
        subprocess.Popen(
            cmd,
            cwd=cwd,
            creationflags=subprocess.CREATE_NEW_CONSOLE,
            close_fds=True,
        )
        return jsonify({"ok": True, "name": item["name"]})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


@app.route("/api/status")
def status():
    """Check if key services are running."""
    def is_running(name):
        try:
            r = subprocess.run(
                ["tasklist", "/FI", f"IMAGENAME eq {name}"],
                capture_output=True, text=True, timeout=5
            )
            return name.lower() in r.stdout.lower()
        except Exception:
            return False

    def mysql_running():
        try:
            r = subprocess.run(
                ["sc", "query", "MySQL80"],
                capture_output=True, text=True, timeout=5
            )
            return "RUNNING" in r.stdout
        except Exception:
            return False

    return jsonify({
        "mysql": mysql_running(),
        "worldserver": is_running("worldserver.exe"),
        "bnetserver": is_running("bnetserver.exe"),
    })


# ═══════════════════════════════════════════════════════════════════
#  STARTUP
# ═══════════════════════════════════════════════════════════════════

def prepare_all_assets():
    """Pre-generate web-sized icons and art."""
    print("Preparing assets...")
    prepare_art()

    all_icons = set()
    for cat in CATEGORIES:
        all_icons.add(cat["icon"])
        for item in cat["shortcuts"]:
            all_icons.add(item["icon"])

    print(f"  Converting {len(all_icons)} icons to {ICON_WEB_SIZE}px...")
    for icon in sorted(all_icons):
        prepare_icon(icon)
    print("  Assets ready.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=5050)
    parser.add_argument("--prep", action="store_true", help="Only prepare assets")
    args = parser.parse_args()

    prepare_all_assets()

    if args.prep:
        print("Asset preparation complete.")
        sys.exit(0)

    print(f"\n  VoxCore Command Center — http://localhost:{args.port}")
    print(f"  Press Ctrl+C to stop.\n")
    app.run(host="127.0.0.1", port=args.port, debug=False)

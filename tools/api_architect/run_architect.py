import os
import sys
import argparse
import datetime
import json
import logging
import shutil
from pathlib import Path

# Setup Pathing per Aegis Contract
TOOLS_DIR = Path(__file__).resolve().parent.parent
VOXCORE_ROOT = TOOLS_DIR.parent
sys.path.append(str(VOXCORE_ROOT / "scripts" / "bootstrap"))

import resolve_roots

import collect_inputs
import call_openai
import validate_response
import render_markdown

logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')
logger = logging.getLogger("RunArchitect")

def is_duplicate(payload_hash: str) -> bool:
    config = call_openai.load_config()
    history_file = VOXCORE_ROOT / config["deduplication"]["history_manifest"]
    if not history_file.exists():
        return False
        
    try:
        with open(history_file, "r", encoding="utf-8") as f:
            manifest = json.load(f)
            return manifest.get("last_payload_hash") == payload_hash
    except json.JSONDecodeError:
        return False

def write_manifest(payload_hash: str, output_path: Path, spec_id: str):
    config = call_openai.load_config()
    history_file = VOXCORE_ROOT / config["deduplication"]["history_manifest"]
    history_file.parent.mkdir(parents=True, exist_ok=True)
    
    manifest = {
        "timestamp": datetime.datetime.now().isoformat(),
        "last_payload_hash": payload_hash,
        "last_spec_id": spec_id,
        "last_output_path": str(output_path.relative_to(VOXCORE_ROOT))
    }
    
    with open(history_file, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)

def write_quarantine(raw_json: dict, error_msg: str):
    quarantine_dir = VOXCORE_ROOT / "logs" / "api_architect" / "quarantine"
    quarantine_dir.mkdir(parents=True, exist_ok=True)
    
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    target = quarantine_dir / f"quarantine_{timestamp}.json"
    
    data = {"error": error_msg, "payload": raw_json}
    with open(target, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
    logger.error(f"Quarantined malformed response to: {target}")

def write_inbox_atomic(markdown_content: str, spec_id: str, title: str, output_dir: Path):
    safe_title = "".join([c if c.isalnum() else "_" for c in title]).strip("_").lower()
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d")
    
    final_name = f"{timestamp}__{spec_id}__{safe_title}.md"
    final_path = output_dir / final_name
    temp_path = final_path.with_suffix(".tmp")
    
    output_dir.mkdir(parents=True, exist_ok=True)
    
    with open(temp_path, "w", encoding="utf-8") as f:
        f.write(markdown_content)
        
    # Atomic rename
    temp_path.replace(final_path)
    logger.info(f"Atomically delivered Spec to Inbox: {final_path}")
    return final_path

def main():
    parser = argparse.ArgumentParser(description="Triad Architect Context -> Spec API Producer")
    parser.add_argument("--mode", choices=["spec", "dry-run", "validate-only"], default="spec")
    parser.add_argument("--intake", required=True, help="Path to the primary intake context file")
    parser.add_argument("--output-dir", default="AI_Studio/1_Inbox", help="Target output directory")
    parser.add_argument("--force", action="store_true", help="Bypass deduplication and caching hash guards")
    parser.add_argument("--model", type=str, help="Override default OpenAI model dynamically")
    args = parser.parse_args()

    out_dir = VOXCORE_ROOT / args.output_dir

    if args.model:
        os.environ["OPENAI_MODEL_OVERRIDE"] = args.model

    # 1. Collect and hash inputs
    try:
        payload, payload_hash, intake_name = collect_inputs.collect_intake_payload(args.intake)
        logger.info(f"Input Collector generated payload of length {len(payload)} chars.")
    except ValueError as e:
        logger.error(str(e))
        sys.exit(1)
        
    # 2. Guard against duplicates
    if not args.force and is_duplicate(payload_hash):
        logger.warning("Duplicate payload hash detected! A spec was already generated recently for this exact context.")
        logger.warning("Use --force to generate anyway.")
        sys.exit(0)

    # 3. Request logic
    is_dry_run = (args.mode == "dry-run")
    
    try:
        result_json = call_openai.invoke_architect(payload, intake_name, dry_run=is_dry_run)
    except Exception as e:
        logger.error("Core API failure.")
        sys.exit(1)

    # 4. Validate output
    try:
        validate_response.validate_architect_payload(result_json)
    except Exception as e:
        write_quarantine(result_json, str(e))
        sys.exit(1)

    if args.mode == "validate-only":
        logger.info("Validation mode enabled. Exiting cleanly without rendering markdown.")
        sys.exit(0)

    # 5. Render markdown
    final_md = render_markdown.render_architect_markdown(result_json)
    
    # 6. Atomic Drop
    try:
        final_path = write_inbox_atomic(final_md, result_json["spec_id"], result_json["title"], out_dir)
        write_manifest(payload_hash, final_path, result_json["spec_id"])
    except Exception as e:
        logger.error(f"Failed to write artifact: {e}")
        sys.exit(1)

    logger.info("Triad API Run Complete. Architect Spec generation successful.")
    sys.exit(0)

if __name__ == "__main__":
    main()

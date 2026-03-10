import os
import sys
import hashlib
import json
import logging
from pathlib import Path

# Setup Pathing per Aegis Contract
TOOLS_DIR = Path(__file__).resolve().parent.parent
VOXCORE_ROOT = TOOLS_DIR.parent
sys.path.append(str(VOXCORE_ROOT / "scripts" / "bootstrap"))

import resolve_roots

logger = logging.getLogger("InputCollector")

def load_config():
    config_path = VOXCORE_ROOT / "config" / "api_architect.json"
    with open(config_path, "r", encoding="utf-8") as f:
        return json.load(f)

def is_path_allowlisted(target_path: Path, allowlist: list) -> bool:
    """Checks if the target_path is within any of the allowlisted relative directories."""
    try:
        rel = target_path.relative_to(VOXCORE_ROOT)
        normalized_rel = str(rel).replace("\\", "/")
        for allowed in allowlist:
            if normalized_rel.startswith(allowed.replace("\\", "/")):
                return True
        return False
    except ValueError:
        return False

def redact_content(content: str) -> str:
    """Very rudimentary pass to strip out obvious secrets before sending to OpenAI."""
    # This is a stub for future complex regexes. 
    # For now, we strip obvious OPENAI_API_KEY lines if someone accidentally targets a .env file.
    import re
    content = re.sub(r'OPENAI_API_KEY\s*=\s*["\']?[a-zA-Z0-9_\-]+["\']?', 'OPENAI_API_KEY=[REDACTED_BY_COLLECTOR]', content)
    return content

def compute_hash(content: str) -> str:
    h = hashlib.sha256()
    h.update(content.encode("utf-8"))
    return h.hexdigest()

def collect_intake_payload(intake_file_path: str):
    config = load_config()
    allowlist = config["inputs"]["allowlisted_directories"]
    max_chars = config["inputs"]["max_input_chars"]
    
    # Core Context is always the central brain.
    central_brain_path = VOXCORE_ROOT / "AI_Studio" / "0_Central_Brain.md"
    
    target_path = Path(intake_file_path)
    if not target_path.is_absolute():
        target_path = VOXCORE_ROOT / target_path
    
    target_path = target_path.resolve()
    
    logger.info(f"Checking allowlist for target: {target_path}")
    if not is_path_allowlisted(target_path, allowlist):
        raise ValueError(f"File {target_path} is not in the api_architect allowlist.")

    payload = ""
    
    # 1. Read Central Brain
    if central_brain_path.exists():
        with open(central_brain_path, "r", encoding="utf-8", errors="replace") as f:
            cb_content = f.read()
            payload += "--- CENTRAL BRAIN CONTEXT ---\n"
            payload += cb_content + "\n\n"
            
    # 2. Read Target File
    if target_path.exists() and target_path != central_brain_path:
        with open(target_path, "r", encoding="utf-8", errors="replace") as f:
            t_content = f.read()
            payload += f"--- INTAKE PACKET: {target_path.name} ---\n"
            payload += t_content + "\n\n"
            
    payload = redact_content(payload)
    
    if len(payload) > max_chars:
        logger.warning(f"Payload length ({len(payload)}) exceeds max_chars ({max_chars}). Truncating.")
        payload = payload[:max_chars]
        
    payload_hash = compute_hash(payload)
    
    return payload, payload_hash, target_path.name

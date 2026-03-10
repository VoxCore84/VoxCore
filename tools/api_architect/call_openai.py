import os
import sys
import json
import logging
from pathlib import Path

try:
    from openai import OpenAI
except ImportError:
    print("FATAL: The 'openai' python package is required. Run 'pip install openai'.")
    sys.exit(1)

# Setup Pathing per Aegis Contract
TOOLS_DIR = Path(__file__).resolve().parent.parent
VOXCORE_ROOT = TOOLS_DIR.parent
sys.path.append(str(VOXCORE_ROOT / "scripts" / "bootstrap"))

import resolve_roots

logger = logging.getLogger("CallOpenAI")

def load_local_env():
    """Natively parses the local .env without requiring python-dotenv."""
    env_path = VOXCORE_ROOT / "config" / "api_architect.local.env"
    if env_path.exists():
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                if line.strip() and not line.strip().startswith("#"):
                    if "=" in line:
                        k, v = line.strip().split("=", 1)
                        os.environ[k] = v.strip('"\'')

def load_config():
    config_path = VOXCORE_ROOT / "config" / "api_architect.json"
    with open(config_path, "r", encoding="utf-8") as f:
        return json.load(f)

def invoke_architect(intake_payload: str, target_filename: str, dry_run: bool = False):
    config = load_config()
    load_local_env()
    
    # 1. Prepare system prompt
    prompt_path = VOXCORE_ROOT / config["outputs"]["prompt_template"]
    with open(prompt_path, "r", encoding="utf-8") as f:
        system_prompt = f.read()
        
    # 2. Prepare JSON schema for structured outputs
    schema_path = VOXCORE_ROOT / config["outputs"]["schema_file"]
    with open(schema_path, "r", encoding="utf-8") as f:
        response_schema = json.load(f)

    # 3. Model overriding
    model = os.environ.get("OPENAI_MODEL_OVERRIDE", config["api"]["default_model"])
    
    if dry_run:
        logger.info(f"[DRY RUN] Would call OpenAI model '{model}' with intake '{target_filename}'.")
        # Return a simulated mocked response
        return {
            "spec_id": "TRIAD-DRYRUN-V1",
            "title": "Dry Run Simulation Target",
            "status": "Simulated",
            "priority": "P0",
            "goal_scope": "Test the pipeline without real API calls.",
            "problem_statement": "Validates the dry run mechanism.",
            "architectural_decisions": [{
                "title": "Use Dry Runs",
                "reasoning": "Saves money",
                "approved_behavior": "Return mocked data",
                "disallowed_behavior": "Call API"
            }],
            "file_structure": "AI_Studio/\n  1_Inbox/",
            "logic_data_flow": "Simulate and done.",
            "constraints": ["Do not call real API in dry run"],
            "acceptance_criteria": ["Script exits cleanly"],
            "implementation_order": [{"phase_name": "Phase 1", "tasks": ["Ensure fake data works"]}],
            "immediate_next_actions": ["Review dry run logs"]
        }

    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        logger.error("OPENAI_API_KEY is not set in config/api_architect.local.env.")
        raise ValueError("Missing OPENAI_API_KEY")

    client = OpenAI(api_key=api_key)

    logger.info(f"Calling OpenAI model '{model}' for target '{target_filename}'...")

    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": intake_payload}
        ],
        response_format={
            "type": "json_schema",
            "json_schema": response_schema
        },
        timeout=config["api"].get("timeout_seconds", 120),
    )

    # The API returns a strict JSON string which we parse back into a dict
    response_content = response.choices[0].message.content
    try:
        parsed_response = json.loads(response_content)
        return parsed_response
    except json.JSONDecodeError as e:
        logger.error(f"Failed to parse OpenAI JSON response: {e}")
        logger.error(f"Raw Output: {response_content[:500]}...")
        raise

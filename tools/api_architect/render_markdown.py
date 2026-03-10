import os
import sys
import json
import datetime
from pathlib import Path

# Setup Pathing per Aegis Contract
TOOLS_DIR = Path(__file__).resolve().parent.parent
VOXCORE_ROOT = TOOLS_DIR.parent
sys.path.append(str(VOXCORE_ROOT / "scripts" / "bootstrap"))

import resolve_roots

def _format_architectural_decisions(decisions: list) -> str:
    out = ""
    for idx, d in enumerate(decisions, 1):
        out += f"### {3}.{idx} {d.get('title', 'N/A')}\n"
        out += f"{d.get('reasoning', '')}\n\n"
        out += f"**Approved Behavior:**\n{d.get('approved_behavior', '')}\n\n"
        out += f"**Disallowed Behavior:**\n{d.get('disallowed_behavior', '')}\n\n"
    return out.strip()

def _format_list(items: list) -> str:
    return "\n".join(f"- {i}" for i in items)

def _format_implementation_order(phases: list) -> str:
    out = ""
    for p in phases:
        out += f"### {p.get('phase_name', 'Phase')}\n"
        for t in p.get("tasks", []):
            out += f"- {t}\n"
        out += "\n"
    return out.strip()

def render_architect_markdown(payload: dict) -> str:
    config_path = VOXCORE_ROOT / "config" / "api_architect.json"
    with open(config_path, "r", encoding="utf-8") as f:
        config = json.load(f)
        
    template_path = VOXCORE_ROOT / config["outputs"]["markdown_template"]
    with open(template_path, "r", encoding="utf-8") as f:
        template = f.read()

    # Build substitution dict
    subs = {
        "spec_id": payload.get("spec_id", "UNKNOWN-SPEC"),
        "title": payload.get("title", "Untitled Spec"),
        "status": payload.get("status", "Draft"),
        "priority": payload.get("priority", "P1"),
        "date": datetime.datetime.now().strftime("%Y-%m-%d"),
        "goal_scope": payload.get("goal_scope", ""),
        "problem_statement": payload.get("problem_statement", ""),
        "file_structure": payload.get("file_structure", ""),
        "logic_data_flow": payload.get("logic_data_flow", ""),
        "architectural_decisions": _format_architectural_decisions(payload.get("architectural_decisions", [])),
        "constraints": _format_list(payload.get("constraints", [])),
        "acceptance_criteria": _format_list(payload.get("acceptance_criteria", [])),
        "implementation_order": _format_implementation_order(payload.get("implementation_order", [])),
        "immediate_next_actions": _format_list(payload.get("immediate_next_actions", []))
    }
    
    # Render template
    for key, val in subs.items():
        template = template.replace(f"{{{key}}}", val)
        
    return template

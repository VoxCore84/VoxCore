"""
ChatGPT Architect Bridge — Automated spec review pipeline.

Sends specs from AI_Studio/1_Inbox/ to ChatGPT for architectural review.
Writes the review to AI_Studio/Reports/Audits/ and moves approved specs
to AI_Studio/2_Active_Specs/.

Usage:
    python chatgpt_bridge.py                    # Review all specs in Inbox
    python chatgpt_bridge.py --file SPEC.md     # Review a specific file
    python chatgpt_bridge.py --test             # Test API connectivity
"""
import os
import sys
import argparse
from pathlib import Path
from datetime import datetime

from dotenv import load_dotenv

# Resolve paths relative to this script
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent
AI_STUDIO = PROJECT_ROOT / "AI_Studio"
INBOX = AI_STUDIO / "1_Inbox"
ACTIVE_SPECS = AI_STUDIO / "2_Active_Specs"
REPORTS = AI_STUDIO / "Reports" / "Audits"

# Load .env from the ai_studio directory
load_dotenv(SCRIPT_DIR / ".env")


def get_client():
    """Initialize OpenAI client. Fails fast if key is missing or placeholder."""
    api_key = os.getenv("OPENAI_API_KEY", "")
    if not api_key or api_key == "YOUR_KEY_HERE":
        print("ERROR: OPENAI_API_KEY not set or still placeholder.")
        print(f"Edit: {SCRIPT_DIR / '.env'}")
        sys.exit(1)

    from openai import OpenAI
    return OpenAI(api_key=api_key)


def get_model():
    return os.getenv("OPENAI_MODEL", "gpt-4.5-preview")


SYSTEM_PROMPT = """\
You are the Lead Architect in the VoxCore Triad workflow.

Your role:
- Review architectural specifications submitted by the Implementer (Claude Code)
- Approve, modify, or reject each initiative independently
- Resolve open questions with concrete decisions
- Validate phase ordering and budget feasibility
- Assign agent ownership for each phase
- Identify missing initiatives or risks

Project context:
- VoxCore is a TrinityCore-based WoW private server (12.x Midnight client) for roleplay
- It is a REPACK — ~1500 users download and run their own local worldserver
- AI Fleet: ChatGPT (you, Architect), Claude Code (Implementer), Antigravity/Gemini (QA), \
Cowork (Desktop), Grok Heavy (Security/Research)
- GitHub: VoxCore84/RoleplayCore (private)
- Developer machine: Ryzen 9 9950X3D, 128GB RAM, Windows 11

Output format:
- Use markdown
- For each initiative: state APPROVED, MODIFIED (with changes), or REJECTED (with reason)
- For open questions: provide a concrete answer/decision
- End with a summary verdict and any new action items
"""


def review_spec(client, spec_text: str, spec_name: str) -> str:
    """Send a spec to ChatGPT and return the review."""
    model = get_model()
    print(f"Sending to {model} for review...")

    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": (
                    f"Review the following architectural specification. "
                    f"Approve, modify, or reject each initiative independently. "
                    f"Resolve all open questions.\n\n"
                    f"---\n\n{spec_text}"
                ),
            },
        ],
        temperature=0.3,
        max_tokens=8192,
    )

    return response.choices[0].message.content


def save_review(spec_name: str, review_text: str) -> Path:
    """Save the review to AI_Studio/Reports/Audits/."""
    REPORTS.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime("%Y-%m-%d")
    stem = Path(spec_name).stem
    out_path = REPORTS / f"{timestamp}__REVIEW_{stem}.md"

    header = (
        f"---\n"
        f"reviewed_spec: {spec_name}\n"
        f"reviewer: ChatGPT (Architect)\n"
        f"date: {timestamp}\n"
        f"model: {get_model()}\n"
        f"---\n\n"
    )

    out_path.write_text(header + review_text, encoding="utf-8")
    return out_path


def process_spec(client, spec_path: Path):
    """Review a single spec file."""
    spec_name = spec_path.name
    print(f"\n{'='*60}")
    print(f"Reviewing: {spec_name}")
    print(f"{'='*60}")

    spec_text = spec_path.read_text(encoding="utf-8")

    # Send to ChatGPT
    review_text = review_spec(client, spec_text, spec_name)

    # Save review
    review_path = save_review(spec_name, review_text)
    print(f"Review saved: {review_path}")

    # Check if approved (look for APPROVED verdicts)
    approved_count = review_text.upper().count("APPROVED")
    rejected_count = review_text.upper().count("REJECTED")

    print(f"\nVerdict summary: {approved_count} APPROVED, {rejected_count} REJECTED")

    if rejected_count == 0 and approved_count > 0:
        # Move to Active Specs
        ACTIVE_SPECS.mkdir(parents=True, exist_ok=True)
        dest = ACTIVE_SPECS / spec_name
        spec_path.rename(dest)
        print(f"Spec moved to Active: {dest}")
    else:
        print(f"Spec stays in Inbox (has rejections or modifications to address)")

    return review_path


def test_connection(client):
    """Quick API connectivity test."""
    model = get_model()
    print(f"Testing connection to OpenAI ({model})...")
    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "user", "content": "Reply with exactly: ARCHITECT ONLINE"}
            ],
            max_tokens=10,
        )
        reply = response.choices[0].message.content.strip()
        print(f"Response: {reply}")
        if "ARCHITECT" in reply.upper():
            print("ChatGPT Architect bridge is operational.")
            return True
        else:
            print(f"Unexpected response: {reply}")
            return False
    except Exception as e:
        print(f"Connection failed: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="ChatGPT Architect Bridge")
    parser.add_argument("--test", action="store_true", help="Test API connectivity")
    parser.add_argument("--file", type=str, help="Review a specific spec file from Inbox")
    args = parser.parse_args()

    client = get_client()

    if args.test:
        test_connection(client)
        return

    if args.file:
        spec_path = INBOX / args.file
        if not spec_path.exists():
            # Try as absolute path
            spec_path = Path(args.file)
        if not spec_path.exists():
            print(f"ERROR: File not found: {args.file}")
            print(f"Looked in: {INBOX}")
            sys.exit(1)
        process_spec(client, spec_path)
        return

    # Default: process all specs in Inbox
    specs = list(INBOX.glob("SPEC_*.md"))
    if not specs:
        print(f"No specs found in {INBOX}")
        print("Drop a SPEC_*.md file in the Inbox and run again.")
        return

    print(f"Found {len(specs)} spec(s) in Inbox:")
    for s in specs:
        print(f"  - {s.name}")

    for spec_path in specs:
        process_spec(client, spec_path)

    print(f"\nDone. Reviews saved to {REPORTS}")


if __name__ == "__main__":
    main()

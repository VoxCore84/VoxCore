"""
Codex CLI Reviewer — Invokes OpenAI Codex CLI for repo-aware code review.

Runs `codex exec` in read-only sandbox mode, capturing the final output.
Uses ChatGPT Pro subscription (flat rate, $0 marginal cost per call).
Codex can read the actual repo files during review — unlike pure API calls.

Usage:
    # As module (from review_cycle.py):
    from call_codex_review import review(artifact, round_num, prior_feedback, role)

    # Standalone:
    python call_codex_review.py --test
    python call_codex_review.py --file path/to/artifact.md
"""
import os
import sys
import shutil
import argparse
import subprocess
import tempfile
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent

DEFAULT_MODEL = "gpt-5.4"
EXEC_TIMEOUT = 300  # 5 minutes max per review call


def _find_codex() -> str:
    """Locate the codex CLI binary."""
    codex = shutil.which("codex")
    if codex:
        return codex
    raise FileNotFoundError(
        "codex CLI not found. Install with: npm install -g @openai/codex"
    )


SYSTEM_CONTEXT = """\
You are a repo-aware architecture and code reviewer in the VoxCore Triad review pipeline.

Your unique value: Unlike API-only reviewers, you can READ THE ACTUAL SOURCE FILES in the repo.
Use this ability — when the artifact references a file, function, or class, read it to verify
claims rather than trusting the text at face value.

Your role in this review cycle:
- Evaluate architecture decisions, design patterns, and API contracts
- Verify referenced files/functions actually exist and match what the artifact claims
- Check that the solution integrates correctly with existing code
- Identify missing components, unclear interfaces, or broken dependencies
- On later rounds: verify that fixes from prior rounds are correct by reading the actual code

Project context:
- VoxCore is a TrinityCore-based WoW private server (12.x Midnight client) for roleplay
- Tech stack: C++20, Lua (Eluna), Python, SQL (MySQL 8.0), WoW addon Lua/XML
- 5 databases: auth, characters, world, hotfixes, roleplay
- Working directory: {project_root}

Output format:
- Use markdown
- List each finding as: **[SEVERITY]** (CRITICAL/HIGH/MEDIUM/LOW/INFO) — description
- Group by category (Architecture, Integration, Verification, Design, Scope)
- End with a VERDICT: PASS (no critical/high issues) or FAIL (has critical/high issues)
- Include a 1-paragraph summary of what changed since prior rounds (if applicable)
""".format(project_root=PROJECT_ROOT)


def review(artifact: str, round_num: int = 1, prior_feedback: str = "",
           role: str = "repo-aware reviewer", model: str = DEFAULT_MODEL) -> str:
    """Run Codex exec for repo-aware review. Returns review text."""
    codex_bin = _find_codex()

    prompt_parts = [SYSTEM_CONTEXT]
    prompt_parts.append(f"\n## Artifact to Review (Round {round_num})\n\n{artifact}")
    if prior_feedback:
        prompt_parts.append(f"\n## Prior Review Feedback\n\n{prior_feedback}")
    prompt_parts.append(
        "\n\nReview this artifact thoroughly. If it references source files, "
        "READ THEM to verify claims. List all findings by severity."
    )
    full_prompt = "\n".join(prompt_parts)

    # Write prompt to temp file (avoids shell escaping issues with large text)
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".md", encoding="utf-8", delete=False
    ) as pf:
        pf.write(full_prompt)
        prompt_path = pf.name

    # Write output to temp file
    output_path = tempfile.mktemp(suffix=".md")

    try:
        cmd = [
            codex_bin, "exec",
            "-s", "read-only",
            "--ephemeral",
            "-m", model,
            "-C", str(PROJECT_ROOT),
            "-o", output_path,
            "-",  # read prompt from stdin
        ]

        result = subprocess.run(
            cmd,
            input=full_prompt,
            capture_output=True,
            text=True,
            timeout=EXEC_TIMEOUT,
            cwd=str(PROJECT_ROOT),
            encoding="utf-8",
        )

        # Read the clean output file (-o gives us just the final message)
        if os.path.exists(output_path):
            review_text = Path(output_path).read_text(encoding="utf-8").strip()
            if review_text:
                return review_text

        # Fallback: parse stdout (less clean but usable)
        if result.stdout:
            # Strip the TUI header/footer, extract the codex response
            lines = result.stdout.strip().split("\n")
            # Find the "codex" marker and take everything after it until "tokens used"
            in_response = False
            response_lines = []
            for line in lines:
                if line.strip() == "codex":
                    in_response = True
                    continue
                if line.strip() == "tokens used":
                    break
                if in_response:
                    response_lines.append(line)
            if response_lines:
                return "\n".join(response_lines).strip()

        # If all else fails, return the raw output
        error_info = result.stderr.strip() if result.stderr else "no stderr"
        return (
            f"**ERROR**: Codex exec returned no usable output.\n"
            f"Exit code: {result.returncode}\n"
            f"Stderr: {error_info}\n"
            f"Stdout (last 500 chars): {result.stdout[-500:] if result.stdout else 'empty'}"
        )

    except subprocess.TimeoutExpired:
        return f"**ERROR**: Codex exec timed out after {EXEC_TIMEOUT}s"
    except FileNotFoundError:
        return "**ERROR**: codex CLI not found. Install with: npm install -g @openai/codex"
    finally:
        # Clean up temp files
        for p in [prompt_path, output_path]:
            try:
                os.unlink(p)
            except OSError:
                pass


def test_connection():
    """Quick Codex CLI connectivity test."""
    print(f"Testing Codex CLI exec mode ({DEFAULT_MODEL})...")
    try:
        codex_bin = _find_codex()
        print(f"  Binary: {codex_bin}")

        result = review("Reply with exactly: CODEX REVIEWER ONLINE", model=DEFAULT_MODEL)
        print(f"  Response: {result[:200]}")

        if "CODEX" in result.upper() or "REVIEWER" in result.upper() or "ONLINE" in result.upper():
            print("Codex CLI reviewer bridge is operational.")
            return True
        elif "ERROR" in result.upper():
            print(f"Codex returned error: {result[:300]}")
            return False
        else:
            print(f"Unexpected response (may still be OK): {result[:200]}")
            return True  # Non-error response is still a working connection
    except FileNotFoundError as e:
        print(f"  NOT FOUND: {e}")
        return False
    except Exception as e:
        print(f"  FAILED: {e}")
        return False


def main():
    parser = argparse.ArgumentParser(description="Codex CLI Reviewer")
    parser.add_argument("--test", action="store_true", help="Test Codex CLI connectivity")
    parser.add_argument("--file", type=str, help="Review a specific file")
    parser.add_argument("--model", type=str, default=DEFAULT_MODEL, help="Model override")
    args = parser.parse_args()

    if args.test:
        ok = test_connection()
        sys.exit(0 if ok else 1)

    if args.file:
        path = Path(args.file)
        if not path.exists():
            print(f"ERROR: File not found: {args.file}")
            sys.exit(1)
        artifact = path.read_text(encoding="utf-8")
        result = review(artifact, model=args.model)
        print(result)
        return

    print("Usage: python call_codex_review.py --test | --file <path>")


if __name__ == "__main__":
    main()

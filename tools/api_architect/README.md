# Architect API Inbox Producer - Operator Runbook

The Triad Architecture specifies a headless, Python-based API Producer script to generate architectural specifications directly from OpenAI's Structured Outputs endpoint without requiring manual human-in-the-middle web browser copy-pasting.

The system is single-shot and user-triggered. It is **not** an autonomous agent daemon.

## Configuration & Key Management
1. Rename `config/api_architect.local.env.example` to `config/api_architect.local.env`.
2. Insert your `OPENAI_API_KEY` into that file.
3. This file is explicitly blocked by `.gitignore` to prevent secret leaking.

## How to Trigger a Dry Run
Dry runs simulate the API call, mock the JSON return, validate it, and write an Inbox markdown file natively. **This does not consume quota.**

```bat
python tools/api_architect/run_architect.py --mode dry-run --force --intake AI_Studio/1_Inbox/Your_Intake_Packet.md
```

## How to Trigger a Live Run
Live runs require the `OPENAI_API_KEY` and will consume OpenAI quota. 
Make sure the intake packet is explicitly in an allowlisted directory (like `AI_Studio/1_Inbox/`).

```bat
python tools/api_architect/run_architect.py --mode spec --intake AI_Studio/1_Inbox/Your_Intake_Packet.md
```

## Logs and Outputs
- **Result Output:** The final Markdown artifact will atomically drop into `AI_Studio/1_Inbox/`.
- **Manifest / Deduplication Cache:** A hash of the last successful run is written to `logs/api_architect/latest_request_manifest.json`. Rerunning identical content will be blocked unless `--force` is used.
- **Failures:** If OpenAI hallucinates formatting or throws HTTP errors, the script will dump the malformed payload into `logs/api_architect/quarantine/` and fail gracefully.

## Troubleshooting
- **HTTP 429 Too Many Requests:** Your OpenAI API Key lacks sufficient credits or tier level to hit the Structured Outputs endpoint. Ensure you have pre-funded the account to at least Tier 1.
- **Not in Allowlist:** The Intake packet must be in a safe directory. Moving the packet into the Inbox naturally satisfies the allowlist.

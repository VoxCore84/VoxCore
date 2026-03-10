# Architect API Inbox Producer - Smoke Validation

The `TRIAD-API-V1` stream defines a strict OpenAI-only Python producer (`tools/api_architect/run_architect.py`) to scrape local context, hit the OpenAI Structured Output endpoint, and format an inbox Markdown architectural spec.

## Smoke Validation Checks (Completed)

1. [x] **Dry-Run Bypass**: Ensure `python tools/api_architect/run_architect.py --mode dry-run ...` skips OpenAI but drops a valid "Simulated" Markdown spec matching the `architect_spec.schema.json`.
   - *Result*: Successfully dropped `2026-03-09__TRIAD-DRYRUN-V1__Dry_Run_Simulation_Target.md`.
2. [x] **Inbox Delivery**: Ensure the generated spec is correctly deposited in `AI_Studio/1_Inbox` via atomic rename payload (`.tmp` → `.md`).
3. [x] **Deduplication Check**: Run the command again without `--force` and ensure the `logs/api_architect/latest_request_manifest.json` triggers a protective halt.
4. [x] **Central Brain Context**: Verify that `collect_inputs.py` natively bundles `0_Central_Brain.md` into the API request without explicit arguments.
5. [x] **Schema Validation Layer**: Ensure `validate_response.py` accurately asserts the required fields returned by the OpenAI mock before rendering the formatting template.

## Future Regression Validation

To verify the API Architecture logic still works before charging the OpenAI key:

```bat
cd C:\Users\atayl\VoxCore
:: Use an intake packet that already exists, e.g. the one from Stream 1.
python tools\api_architect\run_architect.py --mode dry-run --force --intake AI_Studio\1_Inbox\Intake_Headless_Build_Validation.md
```

Check the `AI_Studio\1_Inbox\` directory for a newly created `TRIAD-DRYRUN-V1` Markdown artifact.

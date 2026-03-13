"""
One-shot ChatGPT API review of VoxSniffer v7.
Sends all source files + review history context to GPT for adversarial code review.
Output saved to AI_Studio/Reports/Audits/VoxSniffer_ChatGPT_API_Review_v7.md
"""
import os
import sys
from pathlib import Path
from openai import OpenAI

VOXCORE = Path(__file__).resolve().parent.parent.parent

# Load API key
env_path = VOXCORE / "config" / "api_architect.local.env"
if env_path.exists():
    with open(env_path, "r") as f:
        for line in f:
            if line.strip() and not line.strip().startswith("#") and "=" in line:
                k, v = line.strip().split("=", 1)
                os.environ[k] = v.strip("\"'")

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

# Read all source
source_path = Path(__file__).resolve().parent / "voxsniffer_modules_only.txt"
source_code = source_path.read_text(encoding="utf-8")

system_prompt = """You are an expert WoW addon developer and Lua code reviewer performing an adversarial round 7 review.

Your job is to find REAL bugs, not style nits. Focus on:
1. Nil safety -- any path where a nil value could cause a runtime error
2. Session state -- any path where data is captured/cached when no session is active
3. Dedup correctness -- any path where dedup cache is updated before confirming the envelope was created
4. Event safety -- any event handler that could error on unexpected arguments
5. Memory leaks -- any table that grows unbounded without cleanup
6. API correctness -- any WoW API call used incorrectly for the 12.x client
7. Concurrency/timing -- any C_Timer.After callback that doesn't recheck state or verify source identity
8. Data integrity -- any path where persistent SavedVariables could be corrupted
9. Session boundary -- any path where ResetState wipes tracking tables without reseeding from current world state

For each issue found, provide:
- Severity: BLOCKER / WARNING / NIT
- File and line number
- Exact code snippet showing the problem
- Why it's a problem
- Suggested fix

IMPORTANT: Previous rounds produced these confirmed FALSE POSITIVES -- do NOT re-report them:
- MovementTracker UnitPosition X/Y swap: The code correctly handles UnitPosition returning (posY, posX, posZ, instanceMapID) by unpacking as (ok, y, x, z, instanceId) then returning x, y. This is CORRECT.
- PhaseTracker UnitGUID on NAME_PLATE_UNIT_REMOVED: WoW guarantees the unit token is valid during the event handler. This is CORRECT.

If you find no issues in a category, say so explicitly. Do NOT fabricate issues.

At the end, give a gate verdict: PASS (ship it), CONDITIONAL PASS (minor fixes needed), or FAIL (blockers remain).
"""

user_prompt = f"""# VoxSniffer v7 -- Round 7 Adversarial Review

## Review History
- Round 1-2: Found structural issues (nil guards, session gating, dedup ordering)
- Round 3: Found 3 confirmed blockers (all fixed in v4):
  1. 21 buffer:Push sites without nil guard after MakeEnvelope
  2. Dedup cache updated before envelope confirmed in 7 modules
  3. DeltaHints.ResetState killed hotset
- Round 4 (dual review -- browser ChatGPT + API gpt-4.1-mini):
  Browser found 3 blockers (all fixed in v5):
  1. Deferred callbacks not source-bound (NPC could change in 0.1-0.2s window)
  2. Start-time blind spot (ResetState wipes activeNameplates without reseeding)
  3. ObjectTracker vignette premature dedup (seenVignettes marked before MakeEnvelope)
  API found 2 warnings (fixed in v5):
  1. GossipCapture deferred callback missing NPC existence check
  2. VendorCapture same pattern

- Round 5 (dual review -- browser ChatGPT + API gpt-4.1-mini):
  Browser found 3 more blockers (all fixed in v6):
  1. QuestCapture deferred callbacks not source-bound
  2. LootCapture deferred callback not source-bound
  3. PhaseTracker missing Start-time reseed
  API: clean PASS, zero issues

- Round 6 (dual review):
  Browser: internal release PASS, one edge case in QuestCapture (closed-frame text capture)
  API: clean PASS, zero issues

All issues from all rounds have been fixed. This is the v7 code.

## v7 Fixes (from round 6)
- QuestCapture: Fixed closed-frame edge case -- guard now aborts when quest frame closed (GetQuestID=0) during snapshot path
- LootCapture: Target name now snapshotted at event time alongside GUID, preventing wrong name if target changes

## v5 Fixes (from round 4)
- GossipCapture + VendorCapture: NPC GUID snapshotted at event time, verified at callback time
- UnitScanner + AuraScanner: ResetState() re-enumerates visible nameplates
- ObjectTracker: vignette dedup moved after envelope creation

## v6 Fixes (from round 5)
- QuestCapture: questID + NPC GUID snapshotted at event time, passed to deferred callback, verified at callback time
- LootCapture: target GUID snapshotted at event time, used as fallback source in deferred callback
- PhaseTracker: ResetState() re-enumerates visible nameplates and rebuilds knownUnits baseline

## Architecture Summary
- 14 modules, Core layer (RingBuffer, FlushManager, SessionManager, Scheduler, EventBus, Config, Constants, GuidUtils, Fingerprint, Logging, SavedVariablesSchema), UI (ControlPanel)
- Data flow: Module -> MakeEnvelope() -> buffer:Push() -> FlushManager batches -> HTTP POST
- MakeEnvelope returns nil when no session is active
- Persistent dedup caches (seen_vendors, seen_gossip) in VoxSnifferDB.local_cache (SavedVariables)
- Volatile dedup caches cleared by ResetState()

{source_code}

## Your Task
Find any remaining bugs. Be harsh but fair. Only report REAL issues. Give a gate verdict.
"""

print("Sending to gpt-4.1-mini for v5 review...", flush=True)

response = client.chat.completions.create(
    model="gpt-4.1-mini",
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt},
    ],
    max_tokens=16000,
    temperature=0.2,
)

result = response.choices[0].message.content

# Save output
output_path = VOXCORE / "AI_Studio" / "Reports" / "Audits" / "VoxSniffer_ChatGPT_API_Review_v7.md"
output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(f"# VoxSniffer v7 -- ChatGPT API Adversarial Review\n\n**Model**: gpt-4.1-mini\n**Date**: 2026-03-13\n**Tokens**: {response.usage.total_tokens}\n\n---\n\n{result}\n", encoding="utf-8")

print(f"\nReview complete. {response.usage.total_tokens} tokens used.")
print(f"Saved to: {output_path}")
print("\n" + "="*80)
print(result)

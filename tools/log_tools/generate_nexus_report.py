import os
import sys
from datetime import datetime
from pathlib import Path
from dotenv import load_dotenv

import vertexai
from vertexai.generative_models import GenerativeModel

# Try to load .env from the ai_studio directory
env_path = Path(r"C:\Users\atayl\VoxCore\tools\ai_studio\.env")
if env_path.exists():
    load_dotenv(env_path)
else:
    load_dotenv()

def generate_report():
    print("Generating Nexus Report...")
    # Read the central brain
    brain_path = Path(r"C:\Users\atayl\VoxCore\AI_Studio\0_Central_Brain.md")
    if not brain_path.exists():
        print(f"Error: Could not find {brain_path}")
        return

    with open(brain_path, "r", encoding="utf-8") as f:
        brain_content = f.read()

    # Load API keys
    gcp_project = os.getenv("GCP_PROJECT_ID")
    gcp_location = os.getenv("GCP_LOCATION", "us-central1")
    
    today_str = datetime.now().strftime("%Y-%m-%d")

    if not gcp_project:
        print("Warning: GCP_PROJECT_ID not found in environment. Generating a basic offline snapshot instead.")
        report = f"# The Nexus Report - {today_str}\n\n*Generated offline because GCP_PROJECT_ID was missing from .env.*\n\n## Daily Snapshot\n```\n{brain_content}\n```"
    else:
        print("Connecting to Vertex AI (Gemini 1.5 Pro)...")
        vertexai.init(project=gcp_project, location=gcp_location)
        model = GenerativeModel("gemini-2.5-pro")
        prompt = f"""You are the internal technical writer and Chief Architect for VoxCore Enterprise.
Read the following 'Central Brain' state and write a narrative, engaging daily engineering blog post summarizing the momentum, called 'The Nexus Report'.
Focus on what was actually 'Completed Today', the momentum of the 'Active Tabs', and any interesting technical challenges sitting in the 'Paused' or 'Upcoming' backlog.
Keep it concise but highly readable, like a premium internal engineering Devlog. Do not just copy and paste the list—synthesize it into a narrative.

Central Brain State:
{brain_content}
"""
        try:
            response = model.generate_content(prompt)
            report = response.text
        except Exception as e:
            print(f"Error generating from Vertex AI: {e}")
            return
            
    # Save the report
    out_dir = Path(r"C:\Users\atayl\VoxCore\AI_Studio\NotebookLM_Enterprise\Nexus_Reports")
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"Nexus_Report_{today_str}.md"
    
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(report)
        
    print(f"Successfully wrote Nexus Report to {out_path}")

if __name__ == "__main__":
    generate_report()

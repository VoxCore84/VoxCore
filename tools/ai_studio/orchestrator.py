import os
import sys
import json
from pathlib import Path
from dotenv import load_dotenv
from colorama import init, Fore, Style
import anthropic
import vertexai
from vertexai.generative_models import GenerativeModel, ChatSession

# Load environment variables
load_dotenv()
init()

class TriadOrchestrator:
    def __init__(self, project_dir: str):
        self.project_dir = Path(project_dir)
        self.anthropic_api_key = os.getenv("ANTHROPIC_API_KEY")
        self.gcp_project = os.getenv("GCP_PROJECT_ID")
        self.gcp_location = os.getenv("GCP_LOCATION", "us-central1")

        if not self.anthropic_api_key:
            print(f"{Fore.RED}Error: Missing ANTHROPIC_API_KEY in .env{Style.RESET_ALL}")
            sys.exit(1)
            
        if not self.gcp_project:
            print(f"{Fore.RED}Error: Missing GCP_PROJECT_ID for Vertex AI in .env{Style.RESET_ALL}")
            sys.exit(1)

        # Initialize Vertex AI
        vertexai.init(project=self.gcp_project, location=self.gcp_location)
        self.gemini_model = GenerativeModel("gemini-2.5-pro")
        
        # Initialize Anthropic
        self.anthropic_client = anthropic.Anthropic(api_key=self.anthropic_api_key)

        print(f"{Fore.CYAN}Initializing Triad Orchestrator for: {self.project_dir}{Style.RESET_ALL}")

    def run_architect(self, user_prompt: str) -> str:
        """
        ChatGPT (Lead Architect)
        Generates the markdown specification based on user request.
        """
        print(f"{Fore.YELLOW}[Architect]{Style.RESET_ALL} Designing specification via Gemini Ultra...")
        
        chat = self.gemini_model.start_chat()
        prompt = f"SYSTEM: You are the Lead Architect in a Triad AI system. Output ONLY a Markdown specification containing the file names and the logic for the feature requested by the user. Do NOT write full code, just the architecture spec.\n\nUSER DEMAND: Design a spec for the following requirement: {user_prompt}"
        
        response = chat.send_message(prompt)
        spec_content = response.text
        
        print(f"{Fore.YELLOW}[Architect]{Style.RESET_ALL} Specification drafted.")
        return spec_content

    def run_executor(self, spec_content: str) -> list[str]:
        """
        Claude Code (Frontline Executor)
        Writes/edits code based on the specification. Returns a list of modified files.
        """
        print(f"{Fore.GREEN}[Executor]{Style.RESET_ALL} Implementing code from spec...")
        
        response = self.anthropic_client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=4096,
            system="You are the Frontline Executor in a Triad AI system. Your job is to read the markdown specification from the Architect and return a JSON list of file paths that you theoretically would have modified based on the spec.",
            messages=[
                {"role": "user", "content": f"Here is the Architect's specification:\n\n{spec_content}\n\nBased on this spec, which files would you edit? Return ONLY a valid JSON array of strings representing file paths (e.g., [\"src/main.py\"])."}
            ]
        )
        
        try:
            # Parse the response to extract the JSON array
            content = response.content[0].text
            # Basic cleanup in case Claude added markdown backticks
            if content.startswith("```json"):
                content = content[7:-3]
            elif content.startswith("```"):
                content = content[3:-3]
            modified_files = json.loads(content.strip())
        except Exception as e:
            print(f"{Fore.RED}[Executor] Failed to parse modified files list: {e}{Style.RESET_ALL}")
            modified_files = []
            
        print(f"{Fore.GREEN}[Executor]{Style.RESET_ALL} Modified files: {modified_files}")
        return modified_files

    def run_auditor(self, spec_content: str, modified_files: list[str]) -> bool:
        """
        Antigravity (Backend Auditor)
        Audits modified files against the spec. Returns True if passed, False if failed.
        """
        print(f"{Fore.MAGENTA}[Auditor]{Style.RESET_ALL} Verifying committed code...")
        
        file_list_str = ", ".join(modified_files)
        response = self.anthropic_client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=4096,
            system="You are the Backend Auditor in a Triad AI system. Your job is to review the files modified by the Executor against the original specification written by the Architect. In this prototype, you just decide if the files modified match what the spec asked to modify. Reply with ONLY 'PASS' or 'FAIL'.",
            messages=[
                {"role": "user", "content": f"Original Specification:\n{spec_content}\n\nModified Files:\n{file_list_str}\n\nDo these modified files accurately reflect everything the spec demanded?"}
            ]
        )
        
        result = response.content[0].text.strip().upper()
        
        if "PASS" in result:
            return True
        elif "FAIL" in result:
            return False
        else:
            print(f"{Fore.RED}[Auditor] Invalid output: {result}. Defaulting to FAIL.{Style.RESET_ALL}")
            return False

    def orchestrate(self, user_prompt: str):
        print(f"\n{Fore.BLUE}=== Starting Triad Pipeline ==={Style.RESET_ALL}")
        print(f"Goal: {user_prompt}\n")

        # 1. Architect writes spec
        spec = self.run_architect(user_prompt)
        
        # Validation Loop
        max_attempts = 3
        attempt = 1
        success = False

        while attempt <= max_attempts and not success:
            print(f"\n{Fore.BLUE}--- Iteration {attempt}/{max_attempts} ---{Style.RESET_ALL}")
            
            # 2. Executor writes code
            modified_files = self.run_executor(spec)

            # 3. Auditor verifies
            success = self.run_auditor(spec, modified_files)

            if success:
                print(f"\n{Fore.GREEN}✓ Auditor Approved! Pipeline Complete.{Style.RESET_ALL}")
            else:
                print(f"\n{Fore.RED}✗ Auditor Failed! Sending back to Executor...{Style.RESET_ALL}")
                attempt += 1

        if not success:
            print(f"\n{Fore.RED}Pipeline aborted after {max_attempts} failed attempts.{Style.RESET_ALL}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python orchestrator.py \"<your feature request>\"")
        sys.exit(1)
    
    prompt = " ".join(sys.argv[1:])
    orchestrator = TriadOrchestrator(os.getcwd())
    orchestrator.orchestrate(prompt)

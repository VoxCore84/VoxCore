@echo off
cd /d "C:\Users\atayl\VoxCore\tools\command-center"
start /min "VoxCore CC" python app.py
timeout /t 2 /nobreak >nul
start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" --app=http://localhost:5050

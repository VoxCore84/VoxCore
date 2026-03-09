@echo off
setlocal
set "RUNTIME=C:\Users\atayl\VoxCore\tools"
:: Use pythonw to launch without a console window. 
:: The pystray icon will appear in the system tray.
start "AI Studio Router Daemon" /B pythonw "%RUNTIME%\ai_studio_router.py"
endlocal

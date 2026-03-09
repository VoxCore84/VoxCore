@echo off
echo ============================================
echo   VoxCore — Stopping All Servers
echo ============================================
echo.

echo [1/5] Stopping worldserver...
taskkill /IM worldserver.exe /F >nul 2>&1
if %ERRORLEVEL%==0 (echo        Stopped.) else (echo        Not running.)
echo.

echo [2/5] Stopping bnetserver...
taskkill /IM bnetserver.exe /F >nul 2>&1
if %ERRORLEVEL%==0 (echo        Stopped.) else (echo        Not running.)
echo.

echo [3/5] Stopping MySQL (UniServerZ)...
taskkill /IM mysqld_z.exe /F >nul 2>&1
if %ERRORLEVEL%==0 (echo        UniServerZ MySQL stopped.) else (echo        UniServerZ not running.)
echo.

echo [4/5] Stopping Command Center (port 5050)...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":5050 " ^| findstr "LISTENING"') do (
    taskkill /PID %%a /F >nul 2>&1
)
if %ERRORLEVEL%==0 (echo        Stopped.) else (echo        Not running.)
echo.

echo [5/5] Signaling Auto-Parse Daemon to shutdown...
set "RUNTIME=C:\Users\atayl\VoxCore\out\build\x64-RelWithDebInfo\bin\RelWithDebInfo"
echo shutdown > "%RUNTIME%\.stop_auto_parse"
echo        Daemon will close its window dynamically after finishing the packet pipeline.
echo.

echo [6/6] Shutting down AI Studio Router...
taskkill /FI "WINDOWTITLE eq AI Studio Router Daemon*" /F >nul 2>&1
echo        Router offline.
echo.

echo ============================================
echo   All servers stopped. Opening PacketLog...
echo ============================================
explorer "%RUNTIME%\PacketLog"

echo.
echo Spawning Claude Code Handover Agent...
start "Claude Code" wt.exe -d "C:\Users\atayl\VoxCore" cmd /c "claude -p tools\claude_code_handover.md & pause"

%SYSTEMROOT%\system32\timeout.exe /t 3

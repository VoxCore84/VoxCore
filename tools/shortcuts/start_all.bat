@echo off
setlocal
set "RUNTIME=C:\Users\atayl\VoxCore\out\build\x64-RelWithDebInfo\bin\RelWithDebInfo"
set "ARCTIUM=C:\WoW\_retail_\Arctium Game Launcher.exe"

echo ============================================
echo   VoxCore — Starting All Servers
echo ============================================
echo.

:: 1. Start MySQL
echo [1/4] Starting MySQL...
net start MySQL80 >nul 2>&1
if %ERRORLEVEL%==0 (
    echo        MySQL80 service started.
) else (
    sc query MySQL80 | findstr "RUNNING" >nul 2>&1
    if %ERRORLEVEL%==0 (
        echo        MySQL80 already running.
    ) else (
        echo        WARNING: Could not start MySQL80 service.
        echo        Try running as Administrator.
        pause
        exit /b 1
    )
)
echo.

:: 2. Start bnetserver
echo [2/4] Starting bnetserver...
start "bnetserver" /D "%RUNTIME%" "%RUNTIME%\bnetserver.exe"
timeout /t 3 /nobreak >nul
echo        bnetserver launched.
echo.

:: 3. Start worldserver
echo [3/4] Starting worldserver...
start "worldserver" /D "%RUNTIME%" "%RUNTIME%\worldserver.exe"
echo        worldserver launched.
echo.

:: 4. Start Arctium Game Launcher
echo [4/4] Starting Arctium Game Launcher...
if exist "%ARCTIUM%" (
    start "" /D "C:\WoW\_retail_" "%ARCTIUM%"
    echo        Arctium launched.
) else (
    echo        WARNING: Arctium not found at %ARCTIUM%
)
echo.

echo ============================================
echo   All servers started. You can close this.
echo ============================================
timeout /t 5

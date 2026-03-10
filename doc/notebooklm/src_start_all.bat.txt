@echo off
setlocal

:: Resolve VoxCore root by stepping up two directories from tools/shortcuts/
set "ROOT=%~dp0..\.."
for %%i in ("%ROOT%") do set "ROOT=%%~fi"

set "RUNTIME=%ROOT%\out\build\x64-RelWithDebInfo\bin\RelWithDebInfo"
set "MYSQL_DIR=%RUNTIME%\UniServerZ\core\mysql"
set "ARCTIUM=C:\WoW\_retail_\Arctium Game Launcher.exe"
set "CC_DIR=%ROOT%\tools\command-center"

echo ============================================
echo   VoxCore — Starting All Servers
echo ============================================
echo.

:: 1. Start MySQL (UniServerZ)
echo [1/6] Starting MySQL (UniServerZ 9.5.0)...
netstat -ano | findstr ":3306 " | findstr "LISTENING" >nul 2>&1
if %ERRORLEVEL%==0 (
    echo        MySQL already running on port 3306.
    goto mysql_ready
)

start "UniServerZ MySQL" "%MYSQL_DIR%\bin\mysqld_z.exe" ^
    "--defaults-file=%MYSQL_DIR%\my.ini" ^
    "--basedir=%MYSQL_DIR%" ^
    "--datadir=%MYSQL_DIR%\data" ^
    --port=3306 ^
    --console

echo        Waiting up to 15 seconds for initialization...
%SYSTEMROOT%\system32\timeout.exe /t 15 /nobreak >nul

netstat -ano | findstr ":3306 " | findstr "LISTENING" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo        WARNING: MySQL failed to start on port 3306.
    pause
    exit /b 1
)
echo        UniServerZ MySQL started.

:mysql_ready
echo.

:: 1.5. Apply Pending SQL
echo [1.5/6] Checking for pending database patches...
call "%~dp0apply_pending_sql.bat"
echo.

:: 2. Start bnetserver
echo [2/6] Starting bnetserver...
start "bnetserver" /D "%RUNTIME%" "%RUNTIME%\bnetserver.exe"
%SYSTEMROOT%\system32\timeout.exe /t 3 /nobreak >nul
echo        bnetserver launched.
echo.

:: 3. Start worldserver
echo [3/6] Starting worldserver...
start "worldserver" /D "%RUNTIME%" "%RUNTIME%\worldserver.exe"
echo        worldserver launched. Waiting 35 seconds for initialization...
%SYSTEMROOT%\system32\timeout.exe /t 35 /nobreak >nul
echo.

:: 4. Start Arctium Game Launcher
echo [4/6] Starting Arctium Game Launcher...
if exist "%ARCTIUM%" (
    start "" /D "C:\WoW\_retail_" "%ARCTIUM%"
    echo        Arctium launched.
) else (
    echo        WARNING: Arctium not found at %ARCTIUM%
)
echo.

:: 5. Start Command Center
echo [5/6] Starting Command Center...
netstat -ano | findstr ":5050 " | findstr "LISTENING" >nul 2>&1
if %ERRORLEVEL%==0 (
    echo        Command Center already running on port 5050.
) else (
    start "VoxCore CC" /D "%CC_DIR%" /MIN python app.py
    echo        Command Center started — http://localhost:5050
)
echo.

:: 6. Start Auto-Parse Daemon
echo [6/6] Starting Auto-Parse Session Watcher...
start "VoxCore Auto-Parse v3" /D "%~dp0" auto_parse_watch.bat
echo        Auto-Parse daemon launched.
echo.

echo ============================================
echo   All servers started. You can close this.
echo ============================================
%SYSTEMROOT%\system32\timeout.exe /t 5

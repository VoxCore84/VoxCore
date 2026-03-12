@echo off
setlocal EnableDelayedExpansion

:: ============================================================================
:: launch_antigravity.bat — Optimized Antigravity Launcher for VoxCore
:: Pre-warms MCP servers, sets performance env vars, launches Antigravity
:: ============================================================================

title VoxCore Antigravity Launcher

echo.
echo  ========================================
echo   VoxCore Antigravity Optimized Launcher
echo  ========================================
echo.

:: ---------------------------------------------------------------------------
:: 1. Environment variables for performance
:: ---------------------------------------------------------------------------
:: Increase Node.js heap for MCP MySQL server
set "NODE_OPTIONS=--max-old-space-size=512"
:: Force UTF-8 for Python MCP servers
set "PYTHONUTF8=1"
:: Suppress Python bytecode (.pyc) cluttering disk
set "PYTHONDONTWRITEBYTECODE=1"

:: Paths
set "ANTIGRAVITY_EXE=C:\Users\atayl\AppData\Local\Programs\Antigravity\Antigravity.exe"
set "VOXCORE_DIR=C:\Users\atayl\VoxCore"
set "PYTHON=C:\Python314\python.exe"
set "NODE=node"

:: MCP server scripts
set "MCP_MYSQL=C:\Users\atayl\AppData\Roaming\npm\node_modules\@benborla29\mcp-server-mysql\dist\index.js"
set "MCP_WAGO=C:\Users\atayl\VoxCore\wago\wago_db2_server.py"
set "MCP_CODEINTEL=C:\Users\atayl\VoxCore\tools-dev\code-intel\code_intel_server.py"

:: Verify Antigravity exists
if not exist "%ANTIGRAVITY_EXE%" (
    echo [ERROR] Antigravity not found at: %ANTIGRAVITY_EXE%
    echo         Install it or update the path in this script.
    pause
    exit /b 1
)

:: ---------------------------------------------------------------------------
:: 2. Pre-warm MCP servers (background processes)
::    These start the MCP server processes so they build their indexes/caches
::    BEFORE Antigravity tries to connect. Antigravity will spawn its own
::    instances via mcp_config.json, but the pre-warm ensures:
::    - codeintel has its symbol index hot in OS file cache
::    - wago-db2 CSV files are in OS file cache
::    - MySQL node server has its JIT compiled
::    The pre-warm processes auto-terminate after 15 seconds (they just need
::    to initialize, not stay running).
:: ---------------------------------------------------------------------------

echo [1/6] Pre-warming MCP servers...

:: MySQL MCP — warm up Node.js JIT + module loading
echo       MySQL MCP (Node.js warm-up)...
set "MYSQL_HOST=127.0.0.1"
set "MYSQL_PORT=3306"
set "MYSQL_USER=root"
set "MYSQL_PASS=admin"
set "ALLOW_INSERT_OPERATION=true"
set "ALLOW_UPDATE_OPERATION=true"
set "ALLOW_DELETE_OPERATION=true"
set "MYSQL_DB=world"
set "MULTI_DB_MODE=true"
start /B /MIN "MCP-MySQL-Warmup" cmd /c "timeout /t 15 /nobreak >nul & taskkill /F /FI "WINDOWTITLE eq MCP-MySQL-Warmup" >nul 2>&1" >nul 2>&1
start /B "MCP-MySQL" cmd /c "%NODE% "%MCP_MYSQL%" 2>nul & exit" >nul 2>&1

:: Wago DB2 MCP — load CSV indexes into OS file cache
echo       Wago DB2 MCP (CSV cache warm-up)...
set "PROJECT_ROOT=%VOXCORE_DIR%"
start /B "MCP-Wago" cmd /c "%PYTHON% "%MCP_WAGO%" 2>nul & exit" >nul 2>&1

:: CodeIntel MCP — load symbol index into memory
echo       CodeIntel MCP (symbol index warm-up)...
set "COMPILE_COMMANDS_DIR=%VOXCORE_DIR%\out\build\x64-Debug"
set "CLANGD_PATH=C:\Program Files\LLVM\bin\clangd.exe"
set "CTAGS_PATH=C:\Users\atayl\AppData\Local\Microsoft\WinGet\Packages\UniversalCtags.Ctags_Microsoft.Winget.Source_8wekyb3d8bbwe\ctags.exe"
start /B "MCP-CodeIntel" cmd /c "%PYTHON% "%MCP_CODEINTEL%" 2>nul & exit" >nul 2>&1

:: Give MCP servers 3 seconds to start initializing
echo       Waiting 3s for MCP initialization...
timeout /t 3 /nobreak >nul

:: ---------------------------------------------------------------------------
:: 3. Generate context preload (fast — takes <1 second)
:: ---------------------------------------------------------------------------
echo [2/6] Generating context preload...
if exist "%VOXCORE_DIR%\tools\antigravity\context_preload.py" (
    "%PYTHON%" "%VOXCORE_DIR%\tools\antigravity\context_preload.py" 2>nul
    if !errorlevel! equ 0 (
        echo       Context preload written to .gemini\antigravity\preload_context.md
    ) else (
        echo       [WARN] Context preload failed — continuing without it
    )
) else (
    echo       [SKIP] context_preload.py not found
)

:: ---------------------------------------------------------------------------
:: 4. Run optimizer health check (fast — DB operations take <1 second)
:: ---------------------------------------------------------------------------
echo [3/6] Running optimizer health check...
if exist "%VOXCORE_DIR%\tools\antigravity\optimize_antigravity.py" (
    "%PYTHON%" "%VOXCORE_DIR%\tools\antigravity\optimize_antigravity.py" --quick 2>nul
    if !errorlevel! neq 0 (
        echo       [WARN] Optimizer reported issues — run full check manually
    )
) else (
    echo       [SKIP] optimize_antigravity.py not found
)

:: ---------------------------------------------------------------------------
:: 4.5. Re-disable bundled extensions (in case update restored them)
:: ---------------------------------------------------------------------------
echo [4/6] Checking bundled extension manifest...
if exist "%VOXCORE_DIR%\tools\antigravity\redisable_extensions.py" (
    "%PYTHON%" "%VOXCORE_DIR%\tools\antigravity\redisable_extensions.py" 2>nul
    if !errorlevel! equ 0 (
        echo       All extensions match manifest
    ) else (
        echo       Re-disabled some extensions — see output above
    )
) else (
    echo       [SKIP] redisable_extensions.py not found
)

:: ---------------------------------------------------------------------------
:: 5. Start watchdog in background
:: ---------------------------------------------------------------------------
echo [5/6] Starting permission watchdog...
if exist "%VOXCORE_DIR%\tools\antigravity\watchdog.py" (
    start /B "AG-Watchdog" cmd /c ""%PYTHON%" "%VOXCORE_DIR%\tools\antigravity\watchdog.py" >nul 2>&1"
    echo       Watchdog running in background (PID logged to watchdog.log)
) else (
    echo       [SKIP] watchdog.py not found
)

:: ---------------------------------------------------------------------------
:: 6. Launch Antigravity
:: ---------------------------------------------------------------------------
echo [6/6] Launching Antigravity...
echo.

:: Kill the pre-warm MCP processes — Antigravity will spawn its own via config
taskkill /FI "WINDOWTITLE eq MCP-MySQL" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq MCP-Wago" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq MCP-CodeIntel" /F >nul 2>&1
taskkill /FI "WINDOWTITLE eq MCP-MySQL-Warmup" /F >nul 2>&1

:: Launch Antigravity pointed at VoxCore workspace
start "" "%ANTIGRAVITY_EXE%" "%VOXCORE_DIR%"

echo  Antigravity launched with VoxCore workspace.
echo  MCP servers pre-warmed. Watchdog active. Context preloaded.
echo.
echo  This window will close in 5 seconds...
timeout /t 5 /nobreak >nul
exit /b 0

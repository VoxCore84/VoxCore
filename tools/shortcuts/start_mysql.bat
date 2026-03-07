@echo off
echo Starting MySQL80 service...
net start MySQL80 >nul 2>&1
if %ERRORLEVEL%==0 (
    echo MySQL80 started successfully.
) else (
    sc query MySQL80 | findstr "RUNNING" >nul 2>&1
    if %ERRORLEVEL%==0 (
        echo MySQL80 is already running.
    ) else (
        echo Failed to start MySQL80. Try running as Administrator.
    )
)
timeout /t 3

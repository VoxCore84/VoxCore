@echo off
:: Build and deploy VoxGuard extension to Antigravity
echo Building VoxGuard...
cd /d "%~dp0"
call npm run build
if errorlevel 1 (
    echo [ERROR] Build failed
    exit /b 1
)

:: Copy to Antigravity extensions
set "DEST=%USERPROFILE%\.antigravity\extensions\voxcore.voxguard-1.0.0"
if not exist "%DEST%" mkdir "%DEST%\dist"
copy /y package.json "%DEST%\package.json" >nul
copy /y dist\extension.js "%DEST%\dist\extension.js" >nul
echo Deployed to %DEST%
echo Restart Antigravity to load changes.

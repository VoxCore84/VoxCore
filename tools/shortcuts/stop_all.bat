@echo off
echo ============================================
echo   VoxCore — Stopping All Servers
echo ============================================
echo.

echo [1/3] Stopping worldserver...
taskkill /IM worldserver.exe /F >nul 2>&1
if %ERRORLEVEL%==0 (echo        Stopped.) else (echo        Not running.)
echo.

echo [2/3] Stopping bnetserver...
taskkill /IM bnetserver.exe /F >nul 2>&1
if %ERRORLEVEL%==0 (echo        Stopped.) else (echo        Not running.)
echo.

echo [3/3] Stopping MySQL...
net stop MySQL80 >nul 2>&1
if %ERRORLEVEL%==0 (echo        MySQL80 stopped.) else (echo        Already stopped or not a service.)
echo.

echo ============================================
echo   All servers stopped.
echo ============================================
timeout /t 3

@echo off
title VoxCore Auto-Parse v3
echo ============================================================
echo  VoxCore Auto-Parse v3 — Session-Aware Pipeline
echo.
echo  Monitors: Server.log, DBErrors.log, Debug.log, GM.log,
echo            Bnet.log, DBCache.bin, Crashes/
echo  Detects:  Server start/stop, auto-archives sessions
echo  Output:   PacketLog\*.txt + dashboard.html
echo  Press Ctrl+C to stop
echo ============================================================
echo.
cd /d "%~dp0.."
python -m auto_parse --watch --verbose
if %ERRORLEVEL% NEQ 0 pause
exit

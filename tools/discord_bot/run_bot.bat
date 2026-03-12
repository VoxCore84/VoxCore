@echo off
REM Internal runner — called by start_bot.bat in a new window.
REM Do NOT double-click this directly (use start_bot.bat instead).
title DraconicBot
cd /d "%~dp0"
C:\Python314\python.exe "%~dp0__main__.py"
echo.
echo Bot exited. Press any key to close.
pause >nul

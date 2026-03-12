@echo off
REM Launch DraconicBot detached from any terminal/Claude Code tab.
REM Uses bash + nohup so the process survives terminal closure.
REM Logs: tools/discord_bot/logs/draconic_bot.log (rotating, 5 MB x 3)
REM Stop:  stop_bot.bat or: taskkill /F /FI "IMAGENAME eq python.exe" (careful!)

cd /d "%~dp0"

REM Kill any existing bot instance
bash -c "pkill -f 'discord_bot.*__main__' 2>/dev/null"

REM Launch via bash nohup (detached, survives terminal close)
bash -c "cd '%~dp0' && nohup C:/Python314/python.exe __main__.py >> logs/draconic_bot.log 2>&1 &"

echo DraconicBot started (detached via nohup).
echo Logs: %~dp0logs\draconic_bot.log

@echo off
REM Stop DraconicBot
bash -c "pkill -f 'discord_bot.*__main__' 2>/dev/null"
echo DraconicBot stopped.

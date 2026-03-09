@echo off
setlocal enabledelayedexpansion
echo ========================================================
echo   AI Studio Manager
echo   Scraping Desktop\Excluded for new ChatGPT documents...
echo ========================================================
echo.

set "EXCLUDED=C:\Users\atayl\OneDrive\Desktop\Excluded"
set "STUDIO=C:\Users\atayl\VoxCore\AI_Studio"
set "INBOX=%STUDIO%\1_Inbox"

if not exist "%INBOX%" mkdir "%INBOX%"

set /a count=0
for %%ext in (*.md *.txt *.json *.csv *.sql *.lua) do (
    if exist "%EXCLUDED%\%%ext" (
        move /Y "%EXCLUDED%\%%ext" "%INBOX%\" >nul 2>&1
        set /a count+=1
    )
)

if !count! GTR 0 (
    echo [SUCCESS] Moved project files to AI_Studio\1_Inbox
) else (
    echo [INFO] No relevant AI project files found in Excluded folder.
)

echo.
echo Opening AI Studio...
explorer "%STUDIO%"
endlocal
exit

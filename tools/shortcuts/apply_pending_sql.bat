@echo off
setlocal enabledelayedexpansion
set "RUNTIME=C:\Users\atayl\VoxCore\out\build\x64-RelWithDebInfo\bin\RelWithDebInfo"
set "MYSQL_DIR=%RUNTIME%\UniServerZ\core\mysql"
set "PENDING_DIR=C:\Users\atayl\VoxCore\sql\updates\pending"
set "APPLIED_DIR=C:\Users\atayl\VoxCore\sql\updates\applied"

if not exist "%PENDING_DIR%" mkdir "%PENDING_DIR%"
if not exist "%APPLIED_DIR%" mkdir "%APPLIED_DIR%"

set count=0
for %%f in ("%PENDING_DIR%\*.sql") do (
    set /a count+=1
)

if !count!==0 (
    echo        No pending SQL updates found.
    goto :EOF
)

echo        Found !count! pending SQL update(s) in %PENDING_DIR%.
choice /C YN /M "Execute and apply these updates now?" /T 15 /D N
if !ERRORLEVEL! NEQ 1 (
    echo        Skipping pending SQL updates.
    goto :EOF
)

for %%f in ("%PENDING_DIR%\*.sql") do (
    echo        Applying %%~nxf...
    "%MYSQL_DIR%\bin\mysql.exe" -uroot -padmin -h127.0.0.1 -P3306 world < "%%f"
    if !ERRORLEVEL!==0 (
        move "%%f" "%APPLIED_DIR%\" >nul
        set /a count+=1
    ) else (
        echo        ERROR: Failed to apply %%~nxf
    )
)

if !count! GTR 0 (
    echo        Successfully applied !count! SQL updates.
) else (
    echo        No pending SQL updates found.
)
endlocal

@echo off
call "C:\Program Files\Microsoft Visual Studio\18\Community\VC\Auxiliary\Build\vcvarsall.bat" x64 >nul 2>&1
cd /d C:\Users\atayl\VoxCore\out\build\x64-RelWithDebInfo
echo === Building scripts (RelWithDebInfo) ===
ninja -j20 scripts
if errorlevel 1 (
    echo.
    echo BUILD FAILED
) else (
    echo.
    echo === Scripts built successfully ===
)

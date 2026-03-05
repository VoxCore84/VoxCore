# Build Environment

## Primary Build Method
- **Visual Studio 2022** (user's preference for normal work)
- Two presets in `CMakePresets.json`: `x64-Debug` and `x64-RelWithDebInfo`
- Static script linking (`SCRIPTS=static`), Eluna enabled (`ELUNA=ON`)
- **OpenSSL 3.6.1** at `C:\Program Files\OpenSSL-Win64\` — libs at `lib/VC/x64/MD/` (release) and `lib/VC/x64/MDd/` (debug). Legacy 1.x libs deleted to prevent CMake picking wrong ones
- RelWithDebInfo output dir has NTFS junctions to Debug data dirs (maps, vmaps, mmaps, dbc, etc.)

## CLI Build (from Claude's bash)
- **Claude's bash subprocess loses MSVC env** even when launched from VS Terminal — it spawns `/usr/bin/bash` (MSYS2) which doesn't inherit `INCLUDE`/`LIB`/`PATH` from the parent cmd.exe
- **Working CLI build recipe**: Write a `.bat` file that explicitly sets `INCLUDE`, `LIB`, `PATH` for MSVC + Windows SDK, then runs ninja. Execute via `/c/Windows/System32/cmd.exe //c path\to\file.bat 2>&1`
- Key paths:
  - MSVC: `C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\MSVC\14.50.35717`
  - Windows SDK: `C:\Program Files (x86)\Windows Kits\10\Include\10.0.26100.0` (ucrt/um/shared/winrt/cppwinrt)
  - Ninja: `C:\Program Files\Microsoft Visual Studio\18\Community\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja\ninja.exe`
- **vcvarsall/VsDevCmd don't work** in batch files called from Claude's bash — env vars don't propagate to ninja subprocesses
- CMake configure from CLI is fine

## Build Commands
- **Full build**: `cd /c/Dev/RoleplayCore/out/build/x64-Debug && ninja -j16 2>&1`
- **Scripts only**: `cd /c/Dev/RoleplayCore/out/build/x64-Debug && ninja -j16 scripts 2>&1`
- **CMake reconfigure**: `cmake -B out/build/x64-Debug -G Ninja -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`

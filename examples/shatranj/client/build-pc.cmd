@echo off
rem Canonical PC client dev build+test. Structural fixes baked in:
rem   - build dir OUTSIDE Dropbox (%LOCALAPPDATA%\netchesszx\pc-build):
rem     Dropbox sync locks kill cmake configure (hangs pre-CompilerId)
rem   - Visual Studio generator: no vcvars64 shell needed, ever
rem   - test PATH (Qt DLLs) injected by CMake itself: ctest never dies
rem     with 0xc0000135 / STATUS_DLL_NOT_FOUND
rem   - Qt prefix: QT_ROOT_DIR (CI); QTDIR is the local fallback
rem Incremental: safe to re-run; only changed sources rebuild.
rem Packaging/deploy for release stays in build-msvc.ps1 (make client).
setlocal
cd /d "%~dp0"
cmake --preset msvc || exit /b 1
cmake --build --preset msvc-release --parallel || exit /b 1
ctest --preset msvc-release || exit /b 1
echo.
echo PC client build+tests OK

@echo off
REM ============================================================
REM  Mystic 1.10 A38irc-A63 — Clean all build output (Windows)
REM  Replaces make_clean.sh for Windows users
REM ============================================================
echo Cleaning all build output...

REM Output directories (compiled binaries)
if exist out-linux rd /s /q out-linux
if exist out-win32 rd /s /q out-win32
if exist out-dos rd /s /q out-dos
if exist out-os2 rd /s /q out-os2
if exist out-freebsd rd /s /q out-freebsd
if exist out-darwin rd /s /q out-darwin
if exist release rd /s /q release

REM Compiled units and objects (skip fpc264irc)
for /r %%f in (*.ppu) do (
  echo %%f | findstr /i /c:"fpc264irc" >nul || del "%%f" 2>nul
)
for /r %%f in (*.o) do (
  echo %%f | findstr /i /c:"fpc264irc" >nul || del "%%f" 2>nul
)
for /r %%f in (*.a) do (
  echo %%f | findstr /i /c:"fpc264irc" /c:"libs" >nul || del "%%f" 2>nul
)
for /r %%f in (*.or) do del "%%f" 2>nul
for /r %%f in (*.res) do (
  echo %%f | findstr /i /c:"fpc264irc" >nul || del "%%f" 2>nul
)
for /r %%f in (*.s) do (
  echo %%f | findstr /i /c:"fpc264irc" >nul || del "%%f" 2>nul
)

REM Linked executables (Win32/DOS)
del *.exe 2>nul

REM Linked executables (OS/2 EMX)
del *.out 2>nul

REM Compiled MPL bytecode
for /r %%f in (*.mpx) do del "%%f" 2>nul

REM Linker artifacts
del link.res 2>nul
del ppas.sh 2>nul
del ppas.bat 2>nul

REM Build logs
for /r %%f in (*.build.log) do del "%%f" 2>nul

REM Remove shell scripts (not usable on Windows)
del make_clean.sh 2>nul
del build.sh 2>nul
del build-linux.sh 2>nul
del build-win32.sh 2>nul
del build-darwin.sh 2>nul
del build-dos.sh 2>nul
del build-os2.sh 2>nul
del build-ld64-toolchain.sh 2>nul
del make_all_releases.sh 2>nul
del make_install_data.sh 2>nul
del make_release.sh 2>nul

echo Clean.

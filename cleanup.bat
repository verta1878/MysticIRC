@echo off
rem ============================================================
rem  Mystic 1.11IRC — Clean all build output (Windows)
rem ============================================================

echo Cleaning all build output...

rem Output directories
if exist out-linux   rd /s /q out-linux
if exist out-win32   rd /s /q out-win32
if exist out-dos     rd /s /q out-dos
if exist out-os2     rd /s /q out-os2
if exist out-freebsd rd /s /q out-freebsd
if exist out-darwin  rd /s /q out-darwin
if exist out         rd /s /q out
if exist release     rd /s /q release

rem Compiled units and objects (skip fpc264irc and libs)
for /r %%f in (*.ppu) do (
  echo "%%f" | findstr /i "fpc264irc" >nul 2>nul || del /q "%%f" >nul 2>nul
)
for /r %%f in (*.o) do (
  echo "%%f" | findstr /i "fpc264irc" >nul 2>nul || del /q "%%f" >nul 2>nul
)
del /s /q *.or >nul 2>nul
del /s /q *.res >nul 2>nul

rem Linked executables
for %%b in (mystic mis mutil mplc mide mbbsutil fidopoll nodespy qwkpoll mystpack install install_make maketheme 109to110 marc mystfoss ansiedit ripview molms modemcfg makemenu spelltest cl_demo mterm misdos wfcdemo mailer) do (
  if exist %%b del /q %%b >nul 2>nul
  if exist %%b.exe del /q %%b.exe >nul 2>nul
)

rem Compiled MPL bytecode
del /s /q *.mpx >nul 2>nul

rem Linker artifacts
del /q link.res ppas.sh ppas.bat >nul 2>nul

rem Build logs
del /s /q *.build.log >nul 2>nul

rem Subproject output
for %%d in (mystic_modem mystic_misdos mystic_ripview mystic_mterm mystic_molms mystic_ansiedit mystic_makemenu mystic_spell mystic_crypt mystic_sdl mystic_texteditor mystic_mailer) do (
  if exist %%d\out rd /s /q %%d\out >nul 2>nul
  if exist %%d\bin rd /s /q %%d\bin >nul 2>nul
)

echo Clean.

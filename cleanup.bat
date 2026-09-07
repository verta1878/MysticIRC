@echo off
rem ============================================================
rem  Mystic 1.11IRC — Clean all build output (Windows)
rem  Run from MysticIRC repo root.
rem ============================================================

echo Cleaning build output...

rem Output directories only
if exist out         rd /s /q out
if exist out-linux   rd /s /q out-linux
if exist out-win32   rd /s /q out-win32
if exist out-dos     rd /s /q out-dos
if exist out-os2     rd /s /q out-os2
if exist out-freebsd rd /s /q out-freebsd
if exist out-darwin  rd /s /q out-darwin
if exist outwin      rd /s /q outwin
if exist release     rd /s /q release

rem Subproject output
for %%d in (mystic_modem mystic_misdos mystic_ripview mystic_mterm mystic_molms mystic_ansiedit mystic_makemenu mystic_spell mystic_crypt mystic_sdl mystic_texteditor mystic_mailer) do (
  if exist %%d\out rd /s /q %%d\out >nul 2>nul
  if exist %%d\bin rd /s /q %%d\bin >nul 2>nul
)

rem Linker artifacts in root only (not recursive)
if exist link.res del /q link.res >nul 2>nul
if exist ppas.sh  del /q ppas.sh >nul 2>nul
if exist ppas.bat del /q ppas.bat >nul 2>nul

rem Root-level binaries only (not recursive — never touch mystic/ source dir)
for %%b in (mystic.exe mis.exe mutil.exe mplc.exe mide.exe mbbsutil.exe fidopoll.exe nodespy.exe qwkpoll.exe mystpack.exe install.exe install_make.exe maketheme.exe 109to110.exe marc.exe mystfoss.exe ansiedit.exe ripview.exe molms.exe modemcfg.exe makemenu.exe spelltest.exe cl_demo.exe mterm.exe misdos.exe wfcdemo.exe mailer.exe) do (
  if exist %%b del /q %%b >nul 2>nul
)

echo Clean.

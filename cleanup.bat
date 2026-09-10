@echo off
rem ============================================================
rem  Mystic 1.11IRC — Clean build output + remove deprecated files
rem  Run from MysticIRC repo root.
rem ============================================================

set LOG=cleanup.log
echo Mystic 1.11IRC cleanup — %DATE% %TIME% > %LOG%
echo. >> %LOG%

echo Cleaning build output and deprecated files...

rem ---- DEPRECATED SOURCE FILES (merged/replaced) ----
echo Deprecated files: >> %LOG%

rem mystic_modem/ — merged into mdl/m_serial/m_fossil.pas
for %%f in (mystic_modem\fossil_dos.pas mystic_modem\mystfoss.pas mystic_modem\netmodem.pas mystic_modem\netmodem_fossil.pas) do (
  if exist %%f (
    echo   Removed %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem mystic/mdl/ root — moved to mdl/m_serial/
for %%f in (mystic\mdl\serial.pas mystic\mdl\serial_ext.pas mystic\mdl\serial_irq.pas mystic\mdl\m_serial.pas mystic\mdl\m_fossil.pas mystic\mdl\m_fossil_io.pas mystic\mdl\m_io_fossil.pas) do (
  if exist %%f (
    echo   Removed %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem mystic_test/mdl/ root — moved to mdl/m_serial/
for %%f in (mystic_test\mdl\serial.pas mystic_test\mdl\serial_ext.pas mystic_test\mdl\serial_irq.pas mystic_test\mdl\m_serial.pas mystic_test\mdl\m_fossil.pas mystic_test\mdl\m_fossil_io.pas mystic_test\mdl\m_io_fossil.pas) do (
  if exist %%f (
    echo   Removed %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem examples/ripkit/ — already in historical/Ripkt120.zip
if exist examples\ripkit (
  echo   Removed examples\ripkit\ >> %LOG%
  rd /s /q examples\ripkit >nul 2>nul
)

rem ---- BUILD OUTPUT ----
echo. >> %LOG%
echo Build output: >> %LOG%

rem Output directories
for %%d in (out out-linux out-win32 out-dos out-os2 out-freebsd out-darwin outwin release) do (
  if exist %%d (
    echo   Removed %%d\ >> %LOG%
    rd /s /q %%d >nul 2>nul
  )
)

rem Subproject output
for %%d in (mystic_modem mystic_misdos mystic_ripview mystic_mterm mystic_molms mystic_ansiedit mystic_makemenu mystic_spell mystic_crypt mystic_sdl mystic_texteditor mystic_mailer) do (
  if exist %%d\out (
    echo   Removed %%d\out\ >> %LOG%
    rd /s /q %%d\out >nul 2>nul
  )
  if exist %%d\bin (
    echo   Removed %%d\bin\ >> %LOG%
    rd /s /q %%d\bin >nul 2>nul
  )
)

rem Linker artifacts in root
for %%f in (link.res ppas.sh ppas.bat) do (
  if exist %%f (
    echo   Removed %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem Root-level binaries only
for %%b in (mystic.exe mis.exe mutil.exe mplc.exe mide.exe mbbsutil.exe fidopoll.exe nodespy.exe qwkpoll.exe mystpack.exe install.exe install_make.exe maketheme.exe 109to110.exe marc.exe mystfoss.exe ansiedit.exe ripview.exe molms.exe modemcfg.exe makemenu.exe spelltest.exe cl_demo.exe mterm.exe misdos.exe wfcdemo.exe mailer.exe) do (
  if exist %%b (
    echo   Removed %%b >> %LOG%
    del /q %%b >nul 2>nul
  )
)

echo. >> %LOG%
echo Done. >> %LOG%

echo Clean. See %LOG% for details.

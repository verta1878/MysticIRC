@echo off
rem ============================================================
rem  Mystic 1.11IRC — Session 10 sync + cleanup
rem  Run from MysticIRC repo root.
rem ============================================================

set LOG=cleanup.log
echo Mystic 1.11IRC cleanup — %DATE% %TIME% > %LOG%
echo. >> %LOG%

echo Cleaning build output, syncing session 10 changes...

rem ---- SESSION 10: RETIRED FILES ----
echo Session 10 retired files: >> %LOG%

rem m_prot_binkp.pas — merged into m_protocol_binkp.pas (A42+A44)
for %%f in (mystic\m_prot_binkp.pas mystic_test\m_prot_binkp.pas) do (
  if exist %%f (
    echo   Removed %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem test_recconfig.pas — moved to mdl/mdltest5.pas
for %%f in (mystic\test_recconfig.pas mystic_test\test_recconfig.pas) do (
  if exist %%f (
    echo   Removed %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem Stray VGA8X16.FNT — canonical location is mdl\m_rip\
for %%f in (mystic\mdl\VGA8X16.FNT mystic_test\mdl\VGA8X16.FNT) do (
  if exist %%f (
    echo   Removed %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem ---- COMPILED BINARIES (should not be in repo) ----
echo. >> %LOG%
echo Compiled binaries: >> %LOG%

for %%f in (mystic\mystic mystic\mis mystic\mystic.exe mystic\mis.exe mystic_test\mystic mystic_test\mis mystic_test\mystic.exe mystic_test\mis.exe) do (
  if exist %%f (
    echo   Removed %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem ---- BUILD ARTIFACTS (.o .ppu .res linker files) ----
echo. >> %LOG%
echo Build artifacts: >> %LOG%

for %%d in (mystic\mdl mystic_test\mdl mystic\mdl\m_serial mystic_test\mdl\m_serial mystic\mdl\m_rip mystic_test\mdl\m_rip) do (
  if exist %%d (
    for %%f in (%%d\*.o %%d\*.ppu %%d\link*.res %%d\ppas.sh %%d\ppas.bat %%d\link.res) do (
      if exist %%f (
        echo   Removed %%f >> %LOG%
        del /q %%f >nul 2>nul
      )
    )
  )
)

rem Root linker artifacts
for %%f in (link.res ppas.sh ppas.bat) do (
  if exist %%f (
    echo   Removed %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem ---- DEPRECATED SOURCE FILES (from earlier sessions) ----
echo. >> %LOG%
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

rem ---- BUILD OUTPUT DIRECTORIES ----
echo. >> %LOG%
echo Build output dirs: >> %LOG%

for %%d in (out out-linux out-win32 out-dos out-os2 out-freebsd out-darwin outwin release) do (
  if exist %%d (
    echo   Removed %%d\ >> %LOG%
    rd /s /q %%d >nul 2>nul
  )
)

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

rem Root-level binaries
for %%b in (mystic.exe mis.exe mutil.exe mplc.exe mide.exe mbbsutil.exe fidopoll.exe nodespy.exe qwkpoll.exe mystpack.exe install.exe install_make.exe maketheme.exe 109to110.exe marc.exe mystfoss.exe ansiedit.exe ripview.exe molms.exe modemcfg.exe makemenu.exe spelltest.exe cl_demo.exe mterm.exe misdos.exe wfcdemo.exe mailer.exe) do (
  if exist %%b (
    echo   Removed %%b >> %LOG%
    del /q %%b >nul 2>nul
  )
)

echo. >> %LOG%
echo Done. >> %LOG%

echo Clean. See %LOG% for details.

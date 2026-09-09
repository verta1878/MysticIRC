@echo off
rem ============================================================
rem  Mystic 1.11IRC A4 — Clean build output + remove deprecated files
rem  Run from MysticIRC repo root.
rem  Logs all actions to cleanup.log.
rem ============================================================

set LOG=cleanup.log
echo Mystic 1.11IRC A4 cleanup — %DATE% %TIME% > %LOG%
echo. >> %LOG%

echo Cleaning build output and deprecated files...

rem ---- DEPRECATED SOURCE FILES (moved to attic/) ----
echo Deprecated source files: >> %LOG%

rem mystic_modem/ — serial wrappers replaced by mdl/m_serial/
for %%f in (
  mystic_modem\fossil_dos.pas
  mystic_modem\mystfoss.pas
  mystic_modem\netmodem.pas
  mystic_modem\netmodem_fossil.pas
  mystic_modem\mdm_serial.pas
  mystic_modem\mdm_modem.pas
) do (
  if exist %%f (
    echo   DEL %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem mystic_mailer/ — BinkP seam removed
for %%f in (
  mystic_mailer\mlr_binkp.pas
) do (
  if exist %%f (
    echo   DEL %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem mystic/mdl/ root — old serial files moved to mdl/m_serial/
for %%f in (
  serial.pas
  serial_ext.pas
  serial_irq.pas
  m_serial.pas
  m_fossil.pas
  m_fossil_io.pas
  m_io_fossil.pas
) do (
  if exist mystic\mdl\%%f (
    echo   DEL mystic\mdl\%%f >> %LOG%
    del /q mystic\mdl\%%f >nul 2>nul
  )
  if exist mystic_test\mdl\%%f (
    echo   DEL mystic_test\mdl\%%f >> %LOG%
    del /q mystic_test\mdl\%%f >nul 2>nul
  )
)

rem examples/ — old serial/FOSSIL examples moved to attic/
if exist examples\serial (
  echo   RMDIR examples\serial\ >> %LOG%
  rd /s /q examples\serial >nul 2>nul
)
if exist examples\netfosdlv1 (
  echo   RMDIR examples\netfosdlv1\ >> %LOG%
  rd /s /q examples\netfosdlv1 >nul 2>nul
)
if exist examples\ripkit (
  echo   RMDIR examples\ripkit\ >> %LOG%
  rd /s /q examples\ripkit >nul 2>nul
)

rem ---- BUILD OUTPUT DIRECTORIES ----
echo. >> %LOG%
echo Build output directories: >> %LOG%

for %%d in (
  out
  out-linux
  out-win32
  out-dos
  out-os2
  out-freebsd
  out-darwin
  out-i8086
  outwin
  release
) do (
  if exist %%d (
    echo   RMDIR %%d\ >> %LOG%
    rd /s /q %%d >nul 2>nul
  )
)

rem Subproject out/ and bin/ directories
for %%d in (
  mystic_modem
  mystic_misdos
  mystic_ripview
  mystic_mterm
  mystic_molms
  mystic_ansiedit
  mystic_makemenu
  mystic_spell
  mystic_crypt
  mystic_sdl
  mystic_texteditor
  mystic_mailer
  mystic_test
) do (
  if exist %%d\out (
    echo   RMDIR %%d\out\ >> %LOG%
    rd /s /q %%d\out >nul 2>nul
  )
  if exist %%d\bin (
    echo   RMDIR %%d\bin\ >> %LOG%
    rd /s /q %%d\bin >nul 2>nul
  )
  if exist %%d\out-i8086 (
    echo   RMDIR %%d\out-i8086\ >> %LOG%
    rd /s /q %%d\out-i8086 >nul 2>nul
  )
)

rem ---- COMPILED UNITS / OBJECTS IN SOURCE TREE ----
echo. >> %LOG%
echo Compiled units in source tree: >> %LOG%

rem Only delete from mystic source dirs, NOT from fpc264irc or attic
for %%d in (mystic mystic_test mdl mystic_modem mystic_mailer mystic_misdos mystic_ripview mystic_mterm mystic_molms mystic_ansiedit mystic_makemenu mystic_spell mystic_crypt mystic_sdl mystic_texteditor mystic_perl) do (
  if exist %%d (
    for /r %%d %%f in (*.ppu *.o *.a *.or *.res *.mpx) do (
      echo   DEL %%f >> %LOG%
      del /q "%%f" >nul 2>nul
    )
  )
)

rem ---- LINKER ARTIFACTS IN ROOT ----
echo. >> %LOG%
echo Linker artifacts: >> %LOG%

for %%f in (link.res ppas.sh ppas.bat) do (
  if exist %%f (
    echo   DEL %%f >> %LOG%
    del /q %%f >nul 2>nul
  )
)

rem ---- ROOT-LEVEL BINARIES ----
echo. >> %LOG%
echo Root-level binaries: >> %LOG%

for %%b in (
  mystic.exe mis.exe mutil.exe mplc.exe mide.exe mbbsutil.exe
  fidopoll.exe nodespy.exe qwkpoll.exe mystpack.exe install.exe
  install_make.exe maketheme.exe 109to110.exe marc.exe mystfoss.exe
  ansiedit.exe ripview.exe ans2rip.exe ans2png.exe
  molms.exe mterm.exe modemcfg.exe makemenu.exe
  spelltest.exe cl_demo.exe misdos.exe wfcdemo.exe
  mailer.exe squish_example.exe mystic_texteditor.exe
) do (
  if exist %%b (
    echo   DEL %%b >> %LOG%
    del /q %%b >nul 2>nul
  )
)

rem ---- BUILD LOGS ----
echo. >> %LOG%
echo Build logs: >> %LOG%

for /r . %%f in (*.build.log) do (
  echo   DEL %%f >> %LOG%
  del /q "%%f" >nul 2>nul
)

echo. >> %LOG%
echo Cleanup complete. >> %LOG%
echo Clean. See %LOG% for details.

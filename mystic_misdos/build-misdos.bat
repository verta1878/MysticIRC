@echo off
rem Build mystic_misdos WFC example (DOS-style MIS)
rem Usage: build-misdos.bat
rem Requires FPC 2.6.4irc in PATH or set FPC=path\to\ppc386.exe

if "%FPC%"=="" set FPC=ppc386

echo Building mystic_misdos for Win32...

if not exist out mkdir out
if not exist bin mkdir bin
del /q out\*.ppu out\*.o 2>nul

%FPC% -Twin32 -B -Mobjfpc -O2 -Fu..\mystic\mdl -Fu..\mystic\mdl\m_serial -Fi..\mystic\mdl -Fi..\mystic\mdl\m_serial -Fu..\mystic -Fi..\mystic -Fu..\mystic_modem -Fu..\mystic_mailer -FUout -FEbin misdos.pas

if exist bin\misdos.exe (
  copy /y wfc.ans bin\ >nul
  echo Done. bin\misdos.exe  (keep wfc.ans beside it)
) else (
  echo BUILD FAILED — check errors above.
)

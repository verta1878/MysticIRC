@echo off
REM ============================================================
REM  Mystic 1.10 fork - native Win32 build  (FPC 2.6.4irc r3)
REM  Usage:  build-win32            build every binary
REM          build-win32 mis        build a single target
REM  Keep this file Win32-only (cmd.exe). Linux/Unix: build.sh
REM  Socket layer is IPv4-only, pure-Pascal resolver (no C glue).
REM  Default compiler: FPC 2.6.4irc r3 (libs/fpc264irc.tar.gz); set FPC= to
REM  its bin\ppc386, or leave as 'fpc' to use whatever is on PATH.
REM ============================================================
setlocal
set FPC=fpc
set OPTS=-Mdelphi -Fumystic\mdl -Fumystic\mdl\m_serial -Fumystic -Fimystic\mdl -Fimystic\mdl\m_serial -Fimystic -FUoutwin\units -FEoutwin\bin
if not exist outwin\bin   mkdir outwin\bin
if not exist outwin\units mkdir outwin\units

if "%1"=="" (
  for %%T in (mystic mis mutil mplc mide mbbsutil fidopoll nodespy qwkpoll mystpack mystfoss install install_make maketheme 109to110) do call :build %%T
) else (
  call :build %1
)
goto :eof

:build
del /Q *.ppu *.o 2>nul
%FPC% %OPTS% mystic\%1.pas >outwin\%1.build.log 2>&1
if errorlevel 1 (echo   FAIL  %1  ^(see outwin\%1.build.log^)) else (echo   OK    %1)
goto :eof

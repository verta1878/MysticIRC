@echo off
rem ============================================================================
rem  mysticbbsirc cleanup — run from repo root before push
rem  Removes build artifacts, compiled binaries, and stale files
rem  Output: CLEANUP.LOG (appends)
rem ============================================================================

if not exist LICENSE (
    echo ERROR: Run this from the mysticbbsirc repo root.
    pause
    goto :EOF
)

set LOGFILE=CLEANUP.LOG
set CLEANED=0
set ERRORS=0

echo. >> %LOGFILE%
echo ============================================================================ >> %LOGFILE%
echo mysticbbsirc cleanup >> %LOGFILE%
echo Date: %DATE% %TIME% >> %LOGFILE%
echo ============================================================================ >> %LOGFILE%

echo [1/7] Build artifacts... >> %LOGFILE%
for /R %%F in (*.o *.ppu *.or *.s) do del "%%F" 2>nul
echo OK: Build artifacts cleaned >> %LOGFILE%

echo [2/7] Compiled binaries... >> %LOGFILE%
call :delbin mystic_test\mystic
call :delbin mystic_test\mis
call :delbin mystic_mterm\mterm
call :delbin mystic_ripview\source
ipview
call :delbin mystic_ansieditnsiedit
call :delbin mystic_test\mkcrap
call :delbin mystic_test\mktheme2
call :delbin mystic_test\mksec
call :delbin mystic_test\mkuser
call :delbin mystic_test\makemenu
call :delbin mystic_test\maketext
call :delbin mystic_test
endermrp
echo OK: Compiled binaries cleaned >> %LOGFILE%

echo [3/7] Python cruft... >> %LOGFILE%
for /D /R %%D in (__pycache__) do if exist "%%D" rmdir /S /Q "%%D" 2>nul
for /R %%F in (*.pyc) do del "%%F" 2>nul

echo [4/7] Duplicate MDL files... >> %LOGFILE%
for %%F in (m_crc.pas m_prot_base.pas m_prot_zmodem.pas) do call :delbin mystic_mterm\%%F

echo [5/7] Duplicate RIP assets... >> %LOGFILE%
for %%D in (mystic_mterm
ips mystic_mterm\icons mystic_mterm
ip-icons mystic_mterm
ip-fonts mystic_ripview\icons mystic_ripviewonts mystic_ripview
ips) do if exist %%D rmdir /S /Q %%D 2>nul

echo [6/7] Temp files... >> %LOGFILE%
for %%D in (mystic_test	emp mystic_test	emp0 mystic_test	emp1 mystic_test\logs mystic_test\semaphore) do if exist %%D del /Q %%D\* 2>nul
call :delbin mystic_test\mterm_screen.bin

echo [7/7] Link res files... >> %LOGFILE%
for /R %%F in (link*.res) do del "%%F" 2>nul

echo. >> %LOGFILE%
echo Cleaned: %CLEANED% file(s). Errors: %ERRORS% >> %LOGFILE%
echo.
echo  mysticbbsirc cleanup complete. Cleaned: %CLEANED%. See %LOGFILE%.
echo.
goto :EOF

:delbin
if exist %1 (
    del %1
    echo   OK: Deleted %1 >> %LOGFILE%
    set /a CLEANED+=1
)
goto :EOF


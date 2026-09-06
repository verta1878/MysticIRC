@echo off
rem ============================================================================
rem  mysticbbsirc cleanup — run from repo root before push
rem  Removes build artifacts, moves stale files to attic/
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

rem ============================================================================
rem  1. BUILD ARTIFACTS
rem ============================================================================
echo [1/8] Build artifacts... >> %LOGFILE%
for /R %%F in (*.o *.ppu *.or *.s) do del "%%F" 2>nul
for /R %%F in (link*.res) do del "%%F" 2>nul
echo OK >> %LOGFILE%

rem ============================================================================
rem  2. COMPILED BINARIES
rem ============================================================================
echo [2/8] Compiled binaries... >> %LOGFILE%
call :delbin mystic_test\mystic
call :delbin mystic_test\mis
call :delbin mystic_mterm\mterm
call :delbin mystic_ripview\source\ripview
call :delbin mystic_ansiedit\ansiedit
call :delbin mystic_test\mkcrap
call :delbin mystic_test\mktheme2
call :delbin mystic_test\mksec
call :delbin mystic_test\mkuser
call :delbin mystic_test\makemenu
call :delbin mystic_test\maketext
call :delbin mystic_test\rendermrp
echo OK >> %LOGFILE%

rem ============================================================================
rem  3. PYTHON CRUFT
rem ============================================================================
echo [3/8] Python cruft... >> %LOGFILE%
for /D /R %%D in (__pycache__) do if exist "%%D" rmdir /S /Q "%%D" 2>nul
for /R %%F in (*.pyc) do del "%%F" 2>nul
echo OK >> %LOGFILE%

rem ============================================================================
rem  4. DUPLICATE MDL FILES — programs should use -Fu../mdl
rem ============================================================================
echo [4/8] Duplicate MDL files... >> %LOGFILE%
for %%F in (m_crc.pas m_prot_base.pas m_prot_zmodem.pas m_protocol_kermit.pas m_protocol_queue.pas m_protocol_xmodem.pas m_protocol_ymodem.pas) do call :delbin mystic_mterm\%%F
if exist mystic_test\mdl (
    echo WARN: mystic_test\mdl\ exists — delete it, use ../mdl via -Fu >> %LOGFILE%
    set /a ERRORS+=1
)
echo OK >> %LOGFILE%

rem ============================================================================
rem  5. ARCHIVE STALE FILES TO ATTIC
rem ============================================================================
echo [5/8] Archive stale files to attic... >> %LOGFILE%

if not exist attic\rip_v1_homebrew mkdir attic\rip_v1_homebrew
if not exist attic\rip_v2v3v4_monolith mkdir attic\rip_v2v3v4_monolith

rem Old OOP stack → attic
call :archive mdl\m_output_graph.pas attic\rip_v1_homebrew\m_output_graph.pas
call :archive mdl\m_rip\rip_surface.pas attic\rip_v1_homebrew\rip_surface.pas
call :archive mdl\m_rip\rip_canvas.pas attic\rip_v1_homebrew\rip_canvas.pas

rem v2-v4 monoliths → attic
call :archive mdl\m_rip\v2\rip2api.pas attic\rip_v2v3v4_monolith\rip2api.pas
call :archive mdl\m_rip\v3\rip3api.pas attic\rip_v2v3v4_monolith\rip3api.pas
call :archive mdl\m_rip\v3\rip3client.pas attic\rip_v2v3v4_monolith\rip3client.pas
call :archive mdl\m_rip\v3\rip3server.pas attic\rip_v2v3v4_monolith\rip3server.pas
call :archive mdl\m_rip\v4\rip4api.pas attic\rip_v2v3v4_monolith\rip4api.pas
call :archive mdl\m_rip\v4\rip4client.pas attic\rip_v2v3v4_monolith\rip4client.pas
call :archive mdl\m_rip\v4\rip4server.pas attic\rip_v2v3v4_monolith\rip4server.pas

echo OK >> %LOGFILE%

rem ============================================================================
rem  6. DUPLICATE RIP ASSETS
rem ============================================================================
echo [6/8] Duplicate RIP assets... >> %LOGFILE%
for %%D in (mystic_mterm\rips mystic_mterm\icons mystic_mterm\rip-icons mystic_mterm\rip-fonts mystic_ripview\icons mystic_ripview\fonts mystic_ripview\rips) do (
    if exist %%D (
        rmdir /S /Q %%D
        echo   OK: Deleted %%D\ >> %LOGFILE%
        set /a CLEANED+=1
    )
)
echo OK >> %LOGFILE%

rem ============================================================================
rem  7. TEMP FILES
rem ============================================================================
echo [7/8] Temp files... >> %LOGFILE%
for %%D in (mystic_test\temp mystic_test\temp0 mystic_test\temp1 mystic_test\logs mystic_test\semaphore) do (
    if exist %%D del /Q %%D\* 2>nul
)
call :delbin mystic_test\mterm_screen.bin
echo OK >> %LOGFILE%

rem ============================================================================
rem  8. VERIFY
rem ============================================================================
echo [8/8] Verify... >> %LOGFILE%
echo. >> %LOGFILE%
echo === BUILD CHECK === >> %LOGFILE%
echo   cd mystic_ripview\source >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\..\mdl\m_rip -Fu..\..\mdl\m_rip\v1 ripview.pas >> %LOGFILE%
echo   cd mystic_mterm >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\mdl -Fu..\mdl\m_rip -Fu..\mdl\m_rip\v1 -Fi..\mdl mterm.pas >> %LOGFILE%
echo   cd mystic_test >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\mdl -Fi..\mdl mystic.pas >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\mdl -Fi..\mdl mis.pas >> %LOGFILE%
echo. >> %LOGFILE%
echo === SUMMARY === >> %LOGFILE%
echo Cleaned: %CLEANED% file(s). Errors: %ERRORS% >> %LOGFILE%
echo.
echo  mysticbbsirc cleanup complete. Cleaned: %CLEANED%. Errors: %ERRORS%.
echo  See %LOGFILE%.
echo.
goto :EOF

:delbin
if exist %1 (
    del %1
    echo   OK: Deleted %1 >> %LOGFILE%
    set /a CLEANED+=1
)
goto :EOF

:archive
if exist %1 (
    if not exist %2 (
        move %1 %2 >nul
        echo   OK: Archived %1 to %2 >> %LOGFILE%
        set /a CLEANED+=1
    ) else (
        del %1
        echo   OK: Deleted %1 (already in attic) >> %LOGFILE%
        set /a CLEANED+=1
    )
)
goto :EOF

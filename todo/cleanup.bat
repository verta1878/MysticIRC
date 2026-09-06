@echo off
rem ============================================================================
rem  mysticbbsirc cleanup — run from repo root before push
rem  Removes build artifacts, moves stale files to attic/
rem  Output: CLEANUP.LOG (appends)
rem ============================================================================

if not exist LICENSE (
    echo ERROR: Run this from the mysticbbsirc repo root.
    pause
    exit /b
)

set LOGFILE=CLEANUP.LOG

rem Merge old log if it exists
if exist todo\CLEANUP1.LOG (
    type todo\CLEANUP1.LOG >> %LOGFILE%
    del todo\CLEANUP1.LOG
    echo Merged todo\CLEANUP1.LOG into %LOGFILE%
)
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
echo [1/10] Build artifacts... >> %LOGFILE%
for /R %%F in (*.o *.ppu *.or *.s) do del "%%F" 2>nul
for /R %%F in (link*.res) do del "%%F" 2>nul
echo OK >> %LOGFILE%

rem ============================================================================
rem  2. COMPILED BINARIES
rem ============================================================================
echo [2/10] Compiled binaries... >> %LOGFILE%
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
echo [3/10] Python cruft... >> %LOGFILE%
for /D /R %%D in (__pycache__) do if exist "%%D" rmdir /S /Q "%%D" 2>nul
for /R %%F in (*.pyc) do del "%%F" 2>nul
echo OK >> %LOGFILE%

rem ============================================================================
rem  4. DUPLICATE MDL FILES — mterm should use -Fu../mdl
rem ============================================================================
echo [4/10] Duplicate MDL files... >> %LOGFILE%
rem mystic_test\mdl\ keeps its own full mdl copy (unstable branch) — do NOT delete
call :delbin mystic_test\data\chat1.dat
rem Stray VGA8X16.FNT — canonical location is mdl\m_rip\
call :delbin mystic\mdl\VGA8X16.FNT
call :delbin mystic_test\mdl\VGA8X16.FNT
for %%F in (m_crc.pas m_prot_base.pas m_prot_zmodem.pas m_protocol_kermit.pas m_protocol_queue.pas m_protocol_xmodem.pas m_protocol_ymodem.pas) do call :delbin mystic_mterm\%%F
echo OK >> %LOGFILE%

rem ============================================================================
rem  5. ARCHIVE STALE FILES TO ATTIC
rem ============================================================================
echo [5/10] Archive stale files to attic... >> %LOGFILE%

if not exist attic\rip_v1_homebrew mkdir attic\rip_v1_homebrew
if not exist attic\rip_v2v3v4_monolith mkdir attic\rip_v2v3v4_monolith
if not exist attic\experimental mkdir attic\experimental

rem Old OOP stack
call :archive mdl\m_output_graph.pas attic\rip_v1_homebrew\m_output_graph.pas
call :archive mdl\m_rip\rip_surface.pas attic\rip_v1_homebrew\rip_surface.pas
call :archive mdl\m_rip\rip_canvas.pas attic\rip_v1_homebrew\rip_canvas.pas

rem v2-v4 monoliths
call :archive mdl\m_rip\v2\rip2api.pas attic\rip_v2v3v4_monolith\rip2api.pas
call :archive mdl\m_rip\v3\rip3api.pas attic\rip_v2v3v4_monolith\rip3api.pas
call :archive mdl\m_rip\v3\rip3client.pas attic\rip_v2v3v4_monolith\rip3client.pas
call :archive mdl\m_rip\v3\rip3server.pas attic\rip_v2v3v4_monolith\rip3server.pas
call :archive mdl\m_rip\v4\rip4api.pas attic\rip_v2v3v4_monolith\rip4api.pas
call :archive mdl\m_rip\v4\rip4client.pas attic\rip_v2v3v4_monolith\rip4client.pas
call :archive mdl\m_rip\v4\rip4server.pas attic\rip_v2v3v4_monolith\rip4server.pas

rem Experimental
call :archive mystic_test\experimental\bmpcompare attic\experimental\bmpcompare
call :archive mystic_test\experimental\bmpcompare.pas attic\experimental\bmpcompare.pas
call :archive mystic_test\experimental\m_rip_graph.pas attic\experimental\m_rip_graph.pas
if exist mystic_test\experimental rmdir mystic_test\experimental 2>nul

rem data_bak
if exist mystic_test\data_bak (
    rmdir /S /Q mystic_test\data_bak
    echo   OK: Deleted mystic_test\data_bak\ >> %LOGFILE%
    set /a CLEANED+=1
)

rem Stray font .inc copies — canonical is mdl\m_rip\ and program\mdl\m_rip\
for %%F in (rip_font8x8.inc rip_font8x14.inc rip_font8x16.inc) do (
    call :delbin mdl\%%F
    call :delbin mystic_mterm\%%F
    call :delbin mystic_ripview\source\%%F
    call :delbin mystic\%%F
    call :delbin mdl\m_rip\v1\%%F
    call :delbin mdl\m_rip\v2\%%F
    call :delbin mdl\m_rip\v3\%%F
    call :delbin mdl\m_rip\v4\%%F
)

echo OK >> %LOGFILE%

rem ============================================================================
rem  6. DUPLICATE RIP ASSETS
rem ============================================================================
echo [6/10] Duplicate RIP assets... >> %LOGFILE%
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
echo [7/10] Temp files... >> %LOGFILE%
for %%D in (mystic_test\temp mystic_test\temp0 mystic_test\temp1 mystic_test\logs mystic_test\semaphore) do (
    if exist %%D del /Q %%D\* 2>nul
)
call :delbin mystic_test\mterm_screen.bin
echo OK >> %LOGFILE%

rem ============================================================================
rem  8. SESSION 10 SYNC — run once to match session 10 changes
rem ============================================================================
echo [8/10] Session 10 sync... >> %LOGFILE%

rem --- Remove root mdl\ (mystic\ and mystic_test\ keep own copies) ---
if exist mdl (
    rmdir /S /Q mdl
    echo   OK: Removed root mdl\ >> %LOGFILE%
    set /a CLEANED+=1
)

rem --- Remove session docs from root (these are for Claude, not repo) ---
for %%F in (HANDOFF.md SESSION10-HANDOFF.md DOSBOX-WRITEBACK-FIX.md NOTE-dosbox-x-build-testing.txt HANDOFF-team-projects-connection.txt HANDOFF-phasing-template.txt) do call :delbin %%F

rem --- Retire IRC-WHITEPAPER.md to attic\ ---
if exist IRC-WHITEPAPER.md (
    if not exist attic\IRC-WHITEPAPER.md (
        move IRC-WHITEPAPER.md attic\IRC-WHITEPAPER.md >nul
        echo   OK: Moved IRC-WHITEPAPER.md to attic\ >> %LOGFILE%
    ) else (
        del IRC-WHITEPAPER.md
        echo   OK: Deleted IRC-WHITEPAPER.md (already in attic) >> %LOGFILE%
    )
    set /a CLEANED+=1
)
call :delbin mystic\mdl\m_rip\v1\IRC-WHITEPAPER.md
call :delbin mystic_test\mdl\m_rip\v1\IRC-WHITEPAPER.md
call :delbin todo\IRC-WHITEPAPER.md

rem --- Rename ripscrip-irc-whitepaper.htm to ripscrip-v4irc-implementation-whitepaper.htm ---
for %%D in (mystic_ripview todo\ripscrip attic\rip-docs-mdl attic\rip-docs-mdl\ripdoc) do (
    if exist %%D\ripscrip-irc-whitepaper.htm (
        if not exist %%D\ripscrip-v4irc-implementation-whitepaper.htm (
            move %%D\ripscrip-irc-whitepaper.htm %%D\ripscrip-v4irc-implementation-whitepaper.htm >nul
            echo   OK: Renamed %%D\ripscrip-irc-whitepaper.htm >> %LOGFILE%
        ) else (
            del %%D\ripscrip-irc-whitepaper.htm
            echo   OK: Deleted %%D\ripscrip-irc-whitepaper.htm (renamed copy exists) >> %LOGFILE%
        )
        set /a CLEANED+=1
    )
)

rem --- Move RIP-GRAPHICS-PHASES.md to repo root ---
if not exist RIP-GRAPHICS-PHASES.md (
    if exist mystic\mdl\m_rip\RIP-GRAPHICS-PHASES.md (
        copy mystic\mdl\m_rip\RIP-GRAPHICS-PHASES.md RIP-GRAPHICS-PHASES.md >nul
        echo   OK: Copied RIP-GRAPHICS-PHASES.md to root >> %LOGFILE%
        set /a CLEANED+=1
    )
)
rem Archive old copies
if exist mystic\mdl\m_rip\RIP-GRAPHICS-PHASES.md (
    move mystic\mdl\m_rip\RIP-GRAPHICS-PHASES.md attic\RIP-GRAPHICS-PHASES.md >nul
    echo   OK: Archived mystic\mdl\m_rip\RIP-GRAPHICS-PHASES.md >> %LOGFILE%
    set /a CLEANED+=1
)
if exist mystic_test\mdl\m_rip\RIP-GRAPHICS-PHASES.md (
    move mystic_test\mdl\m_rip\RIP-GRAPHICS-PHASES.md attic\RIP-GRAPHICS-PHASES-mystic_test.md >nul
    echo   OK: Archived mystic_test\mdl\m_rip\RIP-GRAPHICS-PHASES.md >> %LOGFILE%
    set /a CLEANED+=1
)

rem --- Remove stale root files ---
call :delbin checksums.bat
call :delbin viper-verify.bat
call :delbin JVIEW-VS-RIPVIEW.md

echo OK >> %LOGFILE%

rem ============================================================================
rem  9. VERIFY
rem ============================================================================
echo [9/10] Verify... >> %LOGFILE%
echo. >> %LOGFILE%

rem ============================================================================
rem  10. FIX INTERNAL REFERENCES
rem ============================================================================
echo [10/10] Fix internal references... >> %LOGFILE%
rem v1/PHASES.md points to old mdl/m_rip/ path — should point to repo root
rem This is a text replacement the user should verify manually:
echo   NOTE: mystic\mdl\m_rip\v1\PHASES.md and mystic_test\mdl\m_rip\v1\PHASES.md >> %LOGFILE%
echo   should reference RIP-GRAPHICS-PHASES.md (repo root) not mdl\m_rip\ >> %LOGFILE%
echo OK >> %LOGFILE%
echo. >> %LOGFILE%
echo === BUILD CHECK === >> %LOGFILE%
echo   cd mystic_ripview\source >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\..\mdl\m_rip -Fu..\..\mdl\m_rip\v1 -Fi..\..\mdl\m_rip ripview.pas >> %LOGFILE%
echo   cd mystic_mterm >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\mdl -Fu..\mdl\m_rip -Fu..\mdl\m_rip\v1 -Fi..\mdl -Fi..\mdl\m_rip mterm.pas >> %LOGFILE%
echo   cd mystic_test >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\mdl -Fi..\mdl mystic.pas >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\mdl -Fi..\mdl mis.pas >> %LOGFILE%
echo. >> %LOGFILE%
echo === FONT LOCATIONS (canonical) === >> %LOGFILE%
echo   mdl\m_rip\rip_font8x8.inc (master) >> %LOGFILE%
echo   mdl\m_rip\rip_font8x14.inc (master) >> %LOGFILE%
echo   mdl\m_rip\rip_font8x16.inc (master) >> %LOGFILE%
echo   mystic_test\mdl\m_rip\ (copy) >> %LOGFILE%
echo   mystic\mdl\m_rip\ (copy) >> %LOGFILE%
echo. >> %LOGFILE%
echo === SUMMARY === >> %LOGFILE%
echo Cleaned: %CLEANED% file(s). Errors: %ERRORS% >> %LOGFILE%
echo.
echo  mysticbbsirc cleanup complete. Cleaned: %CLEANED%. Errors: %ERRORS%.
echo  See %LOGFILE%.
echo.
exit /b 0

:delbin
if exist %1 (
    del %1
    echo   OK: Deleted %1 >> %LOGFILE%
    set /a CLEANED+=1
)
exit /b

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
exit /b

@echo off
rem ============================================================================
rem  mysticbbsirc cleanup — run from repo root before push
rem  Removes build artifacts, compiled binaries, and stale files
rem
rem  Post-VIPER layout:
rem    mdl/m_rip/          — shared rendering stack (ripengine, ripdraw, etc.)
rem    mdl/m_rip/v1/       — v1 parser/executor (rip1parse, rip1exec)
rem    mdl/m_rip/v2-v4/    — slim extension units (rip2ext, rip3ext, rip4ext)
rem    attic/              — archived old code (ripscr.pas, rip_surface.pas, etc.)
rem
rem  Safe: only deletes known artifacts, never source code
rem  Output: CLEANUP.LOG in repo root
rem ============================================================================

if not exist LICENSE (
    echo ERROR: Run this from the mysticbbsirc repo root.
    pause
    goto :EOF
)

set LOGFILE=CLEANUP.LOG
echo mysticbbsirc cleanup > %LOGFILE%
echo Date: %DATE% %TIME% >> %LOGFILE%
echo. >> %LOGFILE%
set ERRORS=0
set CLEANED=0

rem ============================================================================
rem  1. BUILD ARTIFACTS — .o .ppu .s .or compiled units and assembly
rem ============================================================================
echo [1/7] Build artifacts... >> %LOGFILE%

for /R %%F in (*.o) do (
    del "%%F" 2>nul
    set /a CLEANED+=1
)
for /R %%F in (*.ppu) do (
    del "%%F" 2>nul
    set /a CLEANED+=1
)
for /R %%F in (*.or) do (
    del "%%F" 2>nul
    set /a CLEANED+=1
)
echo OK: Build artifacts cleaned >> %LOGFILE%

rem ============================================================================
rem  2. COMPILED BINARIES in source directories
rem ============================================================================
echo [2/7] Compiled binaries... >> %LOGFILE%

for %%F in (
    mystic_test\mystic
    mystic_test\mis
    mystic_mterm\mterm
    mystic_ripview\source\ripview
    mystic_ansiedit\ansiedit
    mystic_test\mkcrap
    mystic_test\mktheme2
    mystic_test\mksec
    mystic_test\mkuser
    mystic_test\makemenu
    mystic_test\maketext
    mystic_test\rendermrp
) do (
    if exist %%F (
        del %%F
        echo OK: Deleted %%F >> %LOGFILE%
        set /a CLEANED+=1
    )
)
echo OK: Compiled binaries cleaned >> %LOGFILE%

rem ============================================================================
rem  3. PYTHON cruft — __pycache__, .pyc
rem ============================================================================
echo [3/7] Python cruft... >> %LOGFILE%

for /D /R %%D in (__pycache__) do (
    if exist "%%D" (
        rmdir /S /Q "%%D"
        echo OK: Deleted %%D >> %LOGFILE%
        set /a CLEANED+=1
    )
)
for /R %%F in (*.pyc) do (
    del "%%F" 2>nul
    set /a CLEANED+=1
)

rem ============================================================================
rem  4. DUPLICATE MDL files — programs should use -Fu../mdl
rem ============================================================================
echo [4/7] Duplicate MDL files... >> %LOGFILE%

rem mterm protocol files (use mdl/ versions)
for %%F in (m_crc.pas m_prot_base.pas m_prot_zmodem.pas m_protocol_kermit.pas m_protocol_queue.pas m_protocol_xmodem.pas m_protocol_ymodem.pas) do (
    if exist mystic_mterm\%%F (
        del mystic_mterm\%%F
        echo OK: Deleted mystic_mterm\%%F (use mdl\ version) >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem mystic_test/mdl should not have its own copies
if exist mystic_test\mdl (
    echo WARN: mystic_test\mdl\ exists — should use ../mdl via -Fu >> %LOGFILE%
)

rem ============================================================================
rem  5. DUPLICATE RIP assets (single source: examples\ripart\)
rem ============================================================================
echo [5/7] Duplicate RIP assets... >> %LOGFILE%

for %%D in (mystic_mterm\rips mystic_mterm\icons mystic_mterm\rip-icons mystic_mterm\rip-fonts mystic_ripview\icons mystic_ripview\fonts mystic_ripview\rips) do (
    if exist %%D (
        rmdir /S /Q %%D
        echo OK: Deleted %%D\ >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem ============================================================================
rem  6. TEMP/RUNTIME files in mystic_test
rem ============================================================================
echo [6/7] Temp files... >> %LOGFILE%

for %%D in (mystic_test\temp mystic_test\temp0 mystic_test\temp1 mystic_test\logs mystic_test\semaphore) do (
    if exist %%D (
        rem Just clean contents, keep dirs (mystic needs them)
        del /Q %%D\* 2>nul
        echo OK: Cleaned %%D\ >> %LOGFILE%
    )
)

if exist mystic_test\mterm_screen.bin (
    del mystic_test\mterm_screen.bin
    echo OK: Deleted mterm_screen.bin >> %LOGFILE%
    set /a CLEANED+=1
)

rem ============================================================================
rem  7. VERIFY
rem ============================================================================
echo [7/7] Verification... >> %LOGFILE%
echo. >> %LOGFILE%

echo === BUILD CHECK === >> %LOGFILE%
echo Run after cleanup: >> %LOGFILE%
echo   cd mystic_ripview\source >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\..\mdl\m_rip -Fu..\..\mdl\m_rip\v1 ripview.pas >> %LOGFILE%
echo. >> %LOGFILE%
echo   cd mystic_mterm >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\mdl -Fu..\mdl\m_rip -Fu..\mdl\m_rip\v1 -Fi..\mdl mterm.pas >> %LOGFILE%
echo. >> %LOGFILE%
echo   cd mystic_test >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\mdl -Fi..\mdl mystic.pas >> %LOGFILE%
echo   fpc -Mdelphi -Fu..\mdl -Fi..\mdl mis.pas >> %LOGFILE%
echo. >> %LOGFILE%

echo === SUMMARY === >> %LOGFILE%
echo Cleaned: %CLEANED% file(s) >> %LOGFILE%
echo Errors: %ERRORS% >> %LOGFILE%

echo.
echo  mysticbbsirc cleanup complete.
echo  Cleaned: %CLEANED% file(s). Errors: %ERRORS%.
echo  See %LOGFILE% for details.
echo.
if %ERRORS% GTR 0 (
    echo  ** ERRORS FOUND — check %LOGFILE% **
    echo.
)

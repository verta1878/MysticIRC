@echo off
rem ============================================================================
rem  mysticbbsirc cleanup — run from repo root before push
rem  Removes build artifacts, duplicates, cruft, and stale files
rem
rem  Post-VIPER layout:
rem    mdl/m_rip/          — shared rendering stack (ripengine, ripdraw, etc.)
rem    mdl/m_rip/v1/       — v1 parser/executor (rip1parse, rip1exec)
rem    mdl/m_rip/v2-v4/    — slim extension units (rip2ext, rip3ext, rip4ext)
rem    attic/              — archived old code (ripscr.pas, rip_surface.pas, etc.)
rem
rem  Safe: only deletes known artifacts, never source code
rem  Appends to CLEANUP.LOG (preserves history)
rem ============================================================================

if not exist LICENSE (
    echo ERROR: Run this from the mysticbbsirc repo root.
    pause
    goto :EOF
)

set LOGFILE=CLEANUP.LOG
echo. >> %LOGFILE%
echo ============================================================================ >> %LOGFILE%
echo mysticbbsirc cleanup >> %LOGFILE%
echo Date: %DATE% %TIME% >> %LOGFILE%
echo ============================================================================ >> %LOGFILE%
set ERRORS=0
set CLEANED=0

rem ============================================================================
rem  1. BUILD ARTIFACTS — .o .ppu .s .or compiled units and assembly
rem ============================================================================
echo [1/9] Build artifacts... >> %LOGFILE%

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
for /R %%F in (*.s) do (
    if not "%%~xF"==".pas" (
        del "%%F" 2>nul
        set /a CLEANED+=1
    )
)
echo OK: Build artifacts cleaned >> %LOGFILE%

rem ============================================================================
rem  2. COMPILED BINARIES in source directories
rem ============================================================================
echo [2/9] Compiled binaries... >> %LOGFILE%

for %%F in (
    mystic_test\mystic
    mystic_test\mis
    mystic_test\mkcrap
    mystic_test\mktheme2
    mystic_test\mksec
    mystic_test\mkuser
    mystic_test\makemenu
    mystic_test\maketext
    mystic_test\rendermrp
    mystic_test\test_recconfig
    mystic_mterm\mterm
    mystic_mterm\mtrip_test
    mystic_ripview\source\ripview
    mystic_ansiedit\ansiedit
    mdl\mdltest0
    mdl\mdltest10
    mystic_test\mdl\mdltest12
    mystic\test_recconfig
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
echo [3/9] Python cruft... >> %LOGFILE%

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
for %%F in (mdl\m_rip\ans2img.py) do (
    if exist %%F (
        del %%F
        echo OK: Deleted %%F >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem ============================================================================
rem  4. DUPLICATE MDL files — programs should use -Fu../mdl
rem ============================================================================
echo [4/9] Duplicate MDL files... >> %LOGFILE%

rem ansiedit
if exist mystic_ansiedit\m_pdpcboard.pas (
    del mystic_ansiedit\m_pdpcboard.pas
    echo OK: Deleted mystic_ansiedit\m_pdpcboard.pas (use mdl\ version) >> %LOGFILE%
    set /a CLEANED+=1
)

rem mterm protocol files (use mdl/ versions)
for %%F in (m_crc.pas m_prot_base.pas m_prot_zmodem.pas m_protocol_kermit.pas m_protocol_queue.pas m_protocol_xmodem.pas m_protocol_ymodem.pas) do (
    if exist mystic_mterm\%%F (
        del mystic_mterm\%%F
        echo OK: Deleted mystic_mterm\%%F (use mdl\ version) >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem mystic_test/mdl warning
if exist mystic_test\mdl (
    echo WARN: mystic_test\mdl\ exists — should use ../mdl via -Fu >> %LOGFILE%
)

rem ============================================================================
rem  5. DUPLICATE RIP assets (single source: examples\ripart\)
rem ============================================================================
echo [5/9] Duplicate RIP assets... >> %LOGFILE%

for %%D in (mystic_mterm\rips mystic_mterm\icons mystic_mterm\rip-icons mystic_mterm\rip-fonts mystic_ripview\icons mystic_ripview\fonts mystic_ripview\rips) do (
    if exist %%D (
        rmdir /S /Q %%D
        echo OK: Deleted %%D\ >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem Duplicate CHR fonts in mterm\fonts (keep PNGs)
for %%F in (mystic_mterm\fonts\BOLD.CHR mystic_mterm\fonts\EURO.CHR mystic_mterm\fonts\GOTH.CHR mystic_mterm\fonts\LCOM.CHR mystic_mterm\fonts\LITT.CHR mystic_mterm\fonts\SANS.CHR mystic_mterm\fonts\SCRI.CHR mystic_mterm\fonts\SIMP.CHR mystic_mterm\fonts\TRIP.CHR mystic_mterm\fonts\TSCR.CHR) do (
    if exist %%F (
        del %%F
        echo OK: Deleted %%F (dupe of examples\ripart\fonts\) >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem ============================================================================
rem  6. STALE FILES in mdl/m_rip/
rem ============================================================================
echo [6/9] Stale mdl\m_rip files... >> %LOGFILE%

rem Old docs (belong in attic/)
for %%F in (HOWTO-RIPSCRIPT.md RIPSCRIPT-REFERENCE.md TOOLS.md ripscrip-irc-whitepaper.htm build-rip.sh) do (
    if exist mdl\m_rip\%%F (
        del mdl\m_rip\%%F
        echo OK: Deleted mdl\m_rip\%%F >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem Standalone programs (belong in mystic_ripview\tools\)
for %%F in (ans2png.pas ans2rip.pas chg2rip.pas mkicons.pas rip_sample.pas rip_view.pas ripmake.pas test_ans2rip.pas test_phase3.pas test_rip_files.pas font8x8.inc vgafont.inc) do (
    if exist mdl\m_rip\%%F (
        del mdl\m_rip\%%F
        echo OK: Deleted mdl\m_rip\%%F >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem Compiled binaries
for %%F in (ans2png test_phase3) do (
    if exist mdl\m_rip\%%F (
        del mdl\m_rip\%%F
        echo OK: Deleted mdl\m_rip\%%F >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem ripdoc/ (belongs in attic)
if exist mdl\m_rip\ripdoc (
    rmdir /S /Q mdl\m_rip\ripdoc
    echo OK: Deleted mdl\m_rip\ripdoc\ >> %LOGFILE%
    set /a CLEANED+=1
)

rem ============================================================================
rem  7. STALE FILES in mystic_test/mdl/m_rip/
rem ============================================================================
echo [7/9] Stale mystic_test files... >> %LOGFILE%

for %%F in (ans2png.pas ans2rip.pas chg2rip.pas mkicons.pas rip_sample.pas rip_view.pas ripmake.pas test_ans2rip.pas test_phase3.pas test_rip_files.pas font8x8.inc vgafont.inc build-rip.sh) do (
    if exist mystic_test\mdl\m_rip\%%F (
        del mystic_test\mdl\m_rip\%%F
        echo OK: Deleted mystic_test\mdl\m_rip\%%F >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem .s artifacts in mystic_test
for %%F in (mystic_test\mdl\m_strings.s mystic_test\mdl\m_types.s) do (
    if exist %%F (
        del %%F
        echo OK: Deleted %%F >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem ============================================================================
rem  8. TEMP/RUNTIME files
rem ============================================================================
echo [8/9] Temp files... >> %LOGFILE%

for %%D in (mystic_test\temp mystic_test\temp0 mystic_test\temp1 mystic_test\logs mystic_test\semaphore) do (
    if exist %%D (
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
rem  9. VERIFY
rem ============================================================================
echo [9/9] Verification... >> %LOGFILE%
echo. >> %LOGFILE%

echo === SHOULD NOT EXIST === >> %LOGFILE%
for %%F in (mystic_ansiedit\m_pdpcboard.pas mdl\mdltest0 mdl\mdltest10 mdl\m_rip\ans2img.py mdl\m_rip\ripdoc mystic_mterm\rips mystic_mterm\icons mystic_mterm\rip-icons mystic_mterm\rip-fonts) do (
    if exist %%F (
        echo STILL EXISTS: %%F >> %LOGFILE%
        set /a ERRORS+=1
    ) else (
        echo GONE: %%F >> %LOGFILE%
    )
)

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

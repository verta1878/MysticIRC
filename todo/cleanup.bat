@echo off
rem ============================================================================
rem  mysticbbsirc cleanup — run from repo root before push
rem  Removes build artifacts, duplicates, cruft, and stale files
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
rem  1. BUILD ARTIFACTS — .o .ppu .s compiled units and assembly
rem ============================================================================
echo [1/8] Build artifacts... >> %LOGFILE%

for /R %%F in (*.o) do (
    del "%%F" 2>nul
    set /a CLEANED+=1
)
for /R %%F in (*.ppu) do (
    del "%%F" 2>nul
    set /a CLEANED+=1
)
for /R %%F in (*.s) do (
    if not "%%~xF"==".pas" (
        del "%%F" 2>nul
        echo OK: Deleted %%F >> %LOGFILE%
        set /a CLEANED+=1
    )
)
echo OK: Build artifacts cleaned >> %LOGFILE%

rem ============================================================================
rem  2. COMPILED BINARIES in source directories
rem ============================================================================
echo [2/8] Compiled binaries... >> %LOGFILE%

for %%F in (mdl\mdltest0 mdl\mdltest10 mystic_test\mdl\mdltest12) do (
    if exist %%F (
        del %%F
        echo OK: Deleted %%F >> %LOGFILE%
        set /a CLEANED+=1
    )
)
for %%F in (mystic_mterm\mterm mystic_mterm\mtrip_test mystic_ansiedit\ansiedit) do (
    if exist %%F (
        del %%F
        echo OK: Deleted %%F >> %LOGFILE%
        set /a CLEANED+=1
    )
)
for %%F in (mystic\test_recconfig mystic_test\test_recconfig) do (
    if exist %%F (
        del %%F
        echo OK: Deleted %%F >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem ============================================================================
rem  3. PYTHON cruft — __pycache__, .pyc, .py in code dirs
rem ============================================================================
echo [3/8] Python cruft... >> %LOGFILE%

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
rem  4. DUPLICATE MDL files in program directories
rem ============================================================================
echo [4/8] Duplicate MDL files... >> %LOGFILE%

rem ansiedit — redirect file, use -Fu../mdl instead
if exist mystic_ansiedit\m_pdpcboard.pas (
    del mystic_ansiedit\m_pdpcboard.pas
    echo OK: Deleted mystic_ansiedit\m_pdpcboard.pas (use mdl\ version) >> %LOGFILE%
    set /a CLEANED+=1
)

rem mterm — these should use mdl/ versions via -Fu
for %%F in (m_crc.pas m_prot_base.pas m_prot_zmodem.pas m_protocol_kermit.pas m_protocol_queue.pas m_protocol_xmodem.pas m_protocol_ymodem.pas) do (
    if exist mystic_mterm\%%F (
        del mystic_mterm\%%F
        echo OK: Deleted mystic_mterm\%%F (use mdl\ version) >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem ============================================================================
rem  5. DUPLICATE RIP art/fonts/icons (single source: examples\ripart\)
rem ============================================================================
echo [5/8] Duplicate RIP assets... >> %LOGFILE%

rem mterm duplicate RIP files
if exist mystic_mterm\rips (
    rmdir /S /Q mystic_mterm\rips
    echo OK: Deleted mystic_mterm\rips\ (dupes of examples\ripart\art\) >> %LOGFILE%
    set /a CLEANED+=1
)
if exist mystic_mterm\icons (
    rmdir /S /Q mystic_mterm\icons
    echo OK: Deleted mystic_mterm\icons\ (dupes of examples\ripart\icons\) >> %LOGFILE%
    set /a CLEANED+=1
)
if exist mystic_mterm\rip-icons (
    rmdir /S /Q mystic_mterm\rip-icons
    echo OK: Deleted mystic_mterm\rip-icons\ (dupes of examples\ripart\icons\) >> %LOGFILE%
    set /a CLEANED+=1
)
if exist mystic_mterm\rip-fonts (
    rmdir /S /Q mystic_mterm\rip-fonts
    echo OK: Deleted mystic_mterm\rip-fonts\ (dupes of examples\ripart\fonts\) >> %LOGFILE%
    set /a CLEANED+=1
)

rem Duplicate CHR fonts in mterm\fonts (keep PNGs)
for %%F in (mystic_mterm\fonts\BOLD.CHR mystic_mterm\fonts\EURO.CHR mystic_mterm\fonts\GOTH.CHR mystic_mterm\fonts\LCOM.CHR mystic_mterm\fonts\LITT.CHR mystic_mterm\fonts\SANS.CHR mystic_mterm\fonts\SCRI.CHR mystic_mterm\fonts\SIMP.CHR mystic_mterm\fonts\TRIP.CHR mystic_mterm\fonts\TSCR.CHR) do (
    if exist %%F (
        del %%F
        echo OK: Deleted %%F (dupe of examples\ripart\fonts\) >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem ripview duplicate assets
if exist mystic_ripview\icons (
    rmdir /S /Q mystic_ripview\icons
    echo OK: Deleted mystic_ripview\icons\ >> %LOGFILE%
    set /a CLEANED+=1
)
if exist mystic_ripview\fonts (
    rmdir /S /Q mystic_ripview\fonts
    echo OK: Deleted mystic_ripview\fonts\ >> %LOGFILE%
    set /a CLEANED+=1
)
if exist mystic_ripview\rips (
    rmdir /S /Q mystic_ripview\rips
    echo OK: Deleted mystic_ripview\rips\ >> %LOGFILE%
    set /a CLEANED+=1
)

rem ============================================================================
rem  6. STALE FILES in mdl/m_rip/ (docs belong in attic/ or todo/)
rem ============================================================================
echo [6/8] Stale mdl\m_rip files... >> %LOGFILE%

rem Root-level docs (belong in attic/rip-docs-mdl/)
for %%F in (HOWTO-RIPSCRIPT.md RIPSCRIPT-REFERENCE.md TOOLS.md ripscrip-irc-whitepaper.htm build-rip.sh) do (
    if exist mdl\m_rip\%%F (
        del mdl\m_rip\%%F
        echo OK: Deleted mdl\m_rip\%%F (in attic\rip-docs-mdl\) >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem Standalone programs (belong in mystic_ripview\tools\)
for %%F in (ans2png.pas ans2rip.pas chg2rip.pas mkicons.pas rip_sample.pas rip_view.pas ripmake.pas test_ans2rip.pas test_phase3.pas test_rip_files.pas font8x8.inc vgafont.inc) do (
    if exist mdl\m_rip\%%F (
        del mdl\m_rip\%%F
        echo OK: Deleted mdl\m_rip\%%F (in mystic_ripview\tools\) >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem Compiled binaries
for %%F in (ans2png test_phase3) do (
    if exist mdl\m_rip\%%F (
        del mdl\m_rip\%%F
        echo OK: Deleted mdl\m_rip\%%F (compiled binary) >> %LOGFILE%
        set /a CLEANED+=1
    )
)

rem Python
if exist mdl\m_rip\ans2img.py (
    del mdl\m_rip\ans2img.py
    echo OK: Deleted mdl\m_rip\ans2img.py >> %LOGFILE%
    set /a CLEANED+=1
)

rem ripdoc/ (entire tree belongs in attic)
if exist mdl\m_rip\ripdoc (
    rmdir /S /Q mdl\m_rip\ripdoc
    echo OK: Deleted mdl\m_rip\ripdoc\ (in attic\rip-docs-mdl\ripdoc\) >> %LOGFILE%
    set /a CLEANED+=1
)

rem ============================================================================
rem  7. STALE FILES in mystic_test/mdl/m_rip/
rem ============================================================================
echo [7/8] Stale mystic_test files... >> %LOGFILE%

rem Duplicate programs
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
rem  8. VERIFY — code-only check
rem ============================================================================
echo [8/8] Verification... >> %LOGFILE%
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
echo   cd mystic_mterm ^& fpc -Mdelphi -Fu..\mdl -Fi..\mdl mterm.pas >> %LOGFILE%
echo   cd mystic_ansiedit ^& fpc -Mdelphi -Fu..\mdl -Fi..\mdl ansiedit.pas >> %LOGFILE%
echo   cd mystic_test\mdl ^& fpc -Mdelphi -Fu..\..\mdl mdltest12.pas >> %LOGFILE%

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
type %LOGFILE%

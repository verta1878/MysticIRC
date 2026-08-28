@echo off
setlocal enabledelayedexpansion
rem ============================================================================
rem  mysticbbsirc cleanup - run from repo root before push
rem  Output: appends to CLEANUP.LOG in repo root
rem ============================================================================

if not exist LICENSE (
    echo ERROR: Run this from the mysticbbsirc repo root.
    pause
    goto :EOF
)

set LOGFILE=CLEANUP.LOG
echo. >> !LOGFILE!
echo ============================================ >> !LOGFILE!
echo mysticbbsirc cleanup >> !LOGFILE!
echo Date: %DATE% %TIME% >> !LOGFILE!
echo ============================================ >> !LOGFILE!
set ERRORS=0
set CLEANED=0

echo [1/8] Build artifacts... >> !LOGFILE!
set FOUND=0
for /R %%F in (*.o) do (
    del /Q "%%F" 2>nul
    set /a CLEANED+=1
    set FOUND=1
)
for /R %%F in (*.ppu) do (
    del /Q "%%F" 2>nul
    set /a CLEANED+=1
    set FOUND=1
)
for %%F in (mdl\m_input_crt.s mdl\m_strings.s mdl\m_types.s mystic_test\mdl\m_strings.s mystic_test\mdl\m_types.s) do (
    if exist "%%F" (
        del /Q "%%F"
        echo OK: Deleted %%F >> !LOGFILE!
        set /a CLEANED+=1
        set FOUND=1
    )
)
if "!FOUND!"=="0" echo CLEAN: No build artifacts found >> !LOGFILE!
if not "!FOUND!"=="0" echo OK: Build artifacts cleaned >> !LOGFILE!

echo [2/8] Compiled binaries... >> !LOGFILE!
set FOUND=0
for %%F in (mdl\mdltest0 mdl\mdltest10 mystic_test\mdl\mdltest12 mystic_mterm\mterm mystic_mterm\mtrip_test mystic_ansiedit\ansiedit mystic\test_recconfig mystic_test\test_recconfig mdl\m_rip\ans2png mdl\m_rip\test_phase3) do (
    if exist "%%F" (
        del /Q "%%F"
        echo OK: Deleted %%F >> !LOGFILE!
        set /a CLEANED+=1
        set FOUND=1
    )
)
if "!FOUND!"=="0" echo CLEAN: No compiled binaries found >> !LOGFILE!

echo [3/8] Python cruft... >> !LOGFILE!
set FOUND=0
for /D /R %%D in (__pycache__) do (
    if exist "%%D" (
        rmdir /S /Q "%%D"
        echo OK: Deleted %%D >> !LOGFILE!
        set /a CLEANED+=1
        set FOUND=1
    )
)
for /R %%F in (*.pyc) do (
    del /Q "%%F" 2>nul
    set /a CLEANED+=1
    set FOUND=1
)
if exist "mdl\m_rip\ans2img.py" (
    del /Q "mdl\m_rip\ans2img.py"
    echo OK: Deleted mdl\m_rip\ans2img.py >> !LOGFILE!
    set /a CLEANED+=1
    set FOUND=1
)
if "!FOUND!"=="0" echo CLEAN: No Python cruft found >> !LOGFILE!

echo [4/8] Duplicate MDL files... >> !LOGFILE!
set FOUND=0
if exist "mystic_ansiedit\m_pdpcboard.pas" (
    del /Q "mystic_ansiedit\m_pdpcboard.pas"
    echo OK: Deleted mystic_ansiedit\m_pdpcboard.pas >> !LOGFILE!
    set /a CLEANED+=1
    set FOUND=1
)
for %%F in (m_crc.pas m_prot_base.pas m_prot_zmodem.pas m_protocol_kermit.pas m_protocol_queue.pas m_protocol_xmodem.pas m_protocol_ymodem.pas) do (
    if exist "mystic_mterm\%%F" (
        del /Q "mystic_mterm\%%F"
        echo OK: Deleted mystic_mterm\%%F >> !LOGFILE!
        set /a CLEANED+=1
        set FOUND=1
    )
)
if "!FOUND!"=="0" echo CLEAN: No duplicate MDL files found >> !LOGFILE!

echo [5/8] Duplicate RIP assets... >> !LOGFILE!
set FOUND=0
for %%D in (mystic_mterm\rips mystic_mterm\icons mystic_mterm\rip-icons mystic_mterm\rip-fonts mystic_ripview\icons mystic_ripview\fonts mystic_ripview\rips) do (
    if exist "%%D" (
        rmdir /S /Q "%%D"
        echo OK: Deleted %%D >> !LOGFILE!
        set /a CLEANED+=1
        set FOUND=1
    )
)
for %%F in (BOLD.CHR EURO.CHR GOTH.CHR LCOM.CHR LITT.CHR SANS.CHR SCRI.CHR SIMP.CHR TRIP.CHR TSCR.CHR) do (
    if exist "mystic_mterm\fonts\%%F" (
        del /Q "mystic_mterm\fonts\%%F"
        echo OK: Deleted mystic_mterm\fonts\%%F >> !LOGFILE!
        set /a CLEANED+=1
        set FOUND=1
    )
)
if "!FOUND!"=="0" echo CLEAN: No duplicate RIP assets found >> !LOGFILE!

echo [6/8] Misplaced and stale files... >> !LOGFILE!
set FOUND=0
for %%F in (mdl\VGA8X16.FNT mdl\rip_font8x8.inc mystic_test\mdl\rip_font8x8.inc) do (
    if exist "%%F" (
        del /Q "%%F"
        echo OK: Deleted %%F >> !LOGFILE!
        set /a CLEANED+=1
        set FOUND=1
    )
)
for %%F in (HOWTO-RIPSCRIPT.md RIPSCRIPT-REFERENCE.md TOOLS.md ripscrip-irc-whitepaper.htm build-rip.sh ans2img.py) do (
    if exist "mdl\m_rip\%%F" (
        del /Q "mdl\m_rip\%%F"
        echo OK: Deleted mdl\m_rip\%%F >> !LOGFILE!
        set /a CLEANED+=1
        set FOUND=1
    )
)
for %%F in (ans2png.pas ans2rip.pas chg2rip.pas mkicons.pas rip_sample.pas rip_view.pas ripmake.pas test_ans2rip.pas test_phase3.pas test_rip_files.pas font8x8.inc vgafont.inc) do (
    if exist "mdl\m_rip\%%F" (
        del /Q "mdl\m_rip\%%F"
        echo OK: Deleted mdl\m_rip\%%F >> !LOGFILE!
        set /a CLEANED+=1
        set FOUND=1
    )
)
if exist "mdl\m_rip\ripdoc" (
    rmdir /S /Q "mdl\m_rip\ripdoc"
    echo OK: Deleted mdl\m_rip\ripdoc >> !LOGFILE!
    set /a CLEANED+=1
    set FOUND=1
)
if "!FOUND!"=="0" echo CLEAN: No misplaced or stale files found >> !LOGFILE!

echo [7/8] Stale mystic_test files... >> !LOGFILE!
set FOUND=0
for %%F in (ans2png.pas ans2rip.pas chg2rip.pas mkicons.pas rip_sample.pas rip_view.pas ripmake.pas test_ans2rip.pas test_phase3.pas test_rip_files.pas font8x8.inc vgafont.inc build-rip.sh) do (
    if exist "mystic_test\mdl\m_rip\%%F" (
        del /Q "mystic_test\mdl\m_rip\%%F"
        echo OK: Deleted mystic_test\mdl\m_rip\%%F >> !LOGFILE!
        set /a CLEANED+=1
        set FOUND=1
    )
)
if "!FOUND!"=="0" echo CLEAN: No stale mystic_test files found >> !LOGFILE!

echo [8/8] Verification... >> !LOGFILE!
echo. >> !LOGFILE!
echo === SHOULD NOT EXIST === >> !LOGFILE!
for %%F in (mystic_ansiedit\m_pdpcboard.pas mdl\mdltest0 mdl\mdltest10 mdl\VGA8X16.FNT mdl\rip_font8x8.inc mystic_test\mdl\rip_font8x8.inc mdl\m_rip\ans2img.py mdl\m_rip\ripdoc mystic_mterm\rips mystic_mterm\icons mystic_mterm\rip-icons mystic_mterm\rip-fonts) do (
    if exist "%%F" (
        echo STILL EXISTS: %%F >> !LOGFILE!
        set /a ERRORS+=1
    ) else (
        echo GONE: %%F >> !LOGFILE!
    )
)

echo. >> !LOGFILE!
echo === SUMMARY === >> !LOGFILE!
if "!CLEANED!"=="0" echo Nothing to clean. Repo is already clean. >> !LOGFILE!
if not "!CLEANED!"=="0" echo Cleaned: !CLEANED! files >> !LOGFILE!
echo Errors: !ERRORS! >> !LOGFILE!

echo.
if "!CLEANED!"=="0" echo  mysticbbsirc cleanup complete. Nothing to clean.
if not "!CLEANED!"=="0" echo  mysticbbsirc cleanup complete. Cleaned: !CLEANED! files. Errors: !ERRORS!.
echo  See !LOGFILE! for details.
echo.
if not "!ERRORS!"=="0" echo  ** ERRORS FOUND **

endlocal

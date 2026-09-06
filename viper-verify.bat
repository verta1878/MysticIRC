@echo off
rem ============================================================================
rem  VIPER Verify — V1 Integration of Proper Engine Rendering
rem  Run from repo root. Checks shared rendering stack, extension units,
rem  attic archives, build paths.
rem  Output: VIPER-VERIFY.LOG
rem ============================================================================

if not exist LICENSE (
    echo ERROR: Run this from the mysticbbsirc repo root.
    pause
    goto :EOF
)

set LOGFILE=VIPER-VERIFY.LOG
set PASS=0
set FAIL=0
set WARN=0

echo. >> %LOGFILE%
echo ============================================================================ >> %LOGFILE%
echo VIPER Verify >> %LOGFILE%
echo Date: %DATE% %TIME% >> %LOGFILE%
echo ============================================================================ >> %LOGFILE%
echo. >> %LOGFILE%

rem ============================================================================
rem  1. SHARED RENDERING STACK
rem ============================================================================
echo [1/7] Shared rendering stack... >> %LOGFILE%
call :chk_pass mdl\m_rip\ripengine.pas
call :chk_pass mdl\m_rip\ripdraw.pas
call :chk_pass mdl\m_rip\riptext.pas
call :chk_pass mdl\m_rip\ripbmp.pas
call :chk_pass mdl\m_rip\v1\rip1parse.pas
call :chk_pass mdl\m_rip\v1\rip1exec.pas
echo. >> %LOGFILE%

rem ============================================================================
rem  2. OLD OOP STACK — should NOT be in mdl\m_rip\
rem ============================================================================
echo [2/7] Old OOP stack removed... >> %LOGFILE%
call :chk_gone mdl\m_rip\rip_surface.pas
call :chk_gone mdl\m_rip\rip_canvas.pas
call :chk_gone mdl\m_output_rip.pas
call :chk_gone mdl\m_output_graph.pas
echo. >> %LOGFILE%

rem ============================================================================
rem  3. EXTENSION UNITS
rem ============================================================================
echo [3/7] Extension units... >> %LOGFILE%
call :chk_pass mdl\m_rip\v2\rip2ext.pas
call :chk_pass mdl\m_rip\v3\rip3ext.pas
call :chk_pass mdl\m_rip\v4\rip4ext.pas
call :chk_gone mdl\m_rip\v2\rip2api.pas
call :chk_gone mdl\m_rip\v3\rip3api.pas
call :chk_gone mdl\m_rip\v4\rip4api.pas
echo. >> %LOGFILE%

rem ============================================================================
rem  4. ATTIC ARCHIVES
rem ============================================================================
echo [4/7] Attic archives... >> %LOGFILE%
call :chk_warn attic\rip_v1_homebrew\ripscr.pas
call :chk_warn attic\rip_v1_homebrew\rip_surface.pas
call :chk_warn attic\rip_v1_homebrew\rip_canvas.pas
call :chk_warn attic\rip_v1_homebrew\m_output_rip.pas
call :chk_warn attic\rip_v1_homebrew\m_output_graph.pas
call :chk_warn attic\rip_v1_homebrew\NOTE.md
call :chk_warn attic\rip_v2v3v4_monolith\rip2api.pas
call :chk_warn attic\rip_v2v3v4_monolith\rip3api.pas
call :chk_warn attic\rip_v2v3v4_monolith\rip4api.pas
call :chk_warn attic\rip_v2v3v4_monolith\NOTE.md
echo. >> %LOGFILE%

rem ============================================================================
rem  5. DOCS
rem ============================================================================
echo [5/7] Documentation... >> %LOGFILE%
call :chk_pass IRC-WHITEPAPER.md
call :chk_pass todo\VIPER.md
call :chk_pass mdl\m_rip\INTEGRATION-PLAN.md
call :chk_pass mdl\m_rip\v1\IRC-WHITEPAPER.md
call :chk_pass cleanup.bat
call :chk_pass viper-verify.bat
echo. >> %LOGFILE%

rem ============================================================================
rem  6. FONTS
rem ============================================================================
echo [6/7] Font files... >> %LOGFILE%
call :chk_warn mdl\m_rip\rip_font8x8.inc
call :chk_warn mdl\m_rip\v1\rip_font8x8.inc
call :chk_warn mdl\m_rip\v2\rip_font8x8.inc
call :chk_warn mdl\m_rip\v3\rip_font8x8.inc
call :chk_warn mdl\m_rip\v4\rip_font8x8.inc
echo. >> %LOGFILE%

rem ============================================================================
rem  7. BUILD COMMANDS
rem ============================================================================
echo [7/7] Build commands... >> %LOGFILE%
echo   ripview: cd mystic_ripview\source >> %LOGFILE%
echo     fpc -Mdelphi -Fu..\..\mdl\m_rip -Fu..\..\mdl\m_rip\v1 ripview.pas >> %LOGFILE%
echo   mterm: cd mystic_mterm >> %LOGFILE%
echo     fpc -Mdelphi -Fu..\mdl -Fu..\mdl\m_rip -Fu..\mdl\m_rip\v1 -Fi..\mdl mterm.pas >> %LOGFILE%
echo   mystic: cd mystic_test >> %LOGFILE%
echo     fpc -Mdelphi -Fu..\mdl -Fi..\mdl mystic.pas >> %LOGFILE%
echo   mis: cd mystic_test >> %LOGFILE%
echo     fpc -Mdelphi -Fu..\mdl -Fi..\mdl mis.pas >> %LOGFILE%
echo   v2: fpc -Mdelphi -Fu.. -Fu. mdl\m_rip\v2\rip2ext.pas >> %LOGFILE%
echo   v3: fpc -Mdelphi -Fu.. -Fu. mdl\m_rip\v3\rip3ext.pas >> %LOGFILE%
echo   v4: fpc -Mdelphi -Fu.. -Fu. mdl\m_rip\v4\rip4ext.pas >> %LOGFILE%
echo. >> %LOGFILE%

rem ============================================================================
rem  SUMMARY
rem ============================================================================
echo ============================================================================ >> %LOGFILE%
echo VIPER VERIFY SUMMARY >> %LOGFILE%
echo   PASS: %PASS% >> %LOGFILE%
echo   FAIL: %FAIL% >> %LOGFILE%
echo   WARN: %WARN% >> %LOGFILE%
echo ============================================================================ >> %LOGFILE%

echo.
echo  VIPER verify complete.
echo  PASS: %PASS%  FAIL: %FAIL%  WARN: %WARN%
echo  See %LOGFILE% for details.
echo.
if %FAIL% GTR 0 echo  ** FAILURES FOUND **
goto :EOF

rem ============================================================================
rem  Subroutines
rem ============================================================================

:chk_pass
rem File MUST exist — PASS if found, FAIL if missing
if exist %1 (
    echo   PASS: %1 >> %LOGFILE%
    set /a PASS+=1
) else (
    echo   FAIL: %1 MISSING >> %LOGFILE%
    set /a FAIL+=1
)
goto :EOF

:chk_gone
rem File must NOT exist — PASS if gone, FAIL if still there
if exist %1 (
    echo   FAIL: %1 still exists ^(should be archived^) >> %LOGFILE%
    set /a FAIL+=1
) else (
    echo   PASS: %1 gone ^(archived^) >> %LOGFILE%
    set /a PASS+=1
)
goto :EOF

:chk_warn
rem File SHOULD exist but not critical — PASS if found, WARN if missing
if exist %1 (
    echo   PASS: %1 >> %LOGFILE%
    set /a PASS+=1
) else (
    echo   WARN: %1 missing >> %LOGFILE%
    set /a WARN+=1
)
goto :EOF



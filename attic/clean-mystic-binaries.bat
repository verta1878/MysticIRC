@echo off
REM ============================================================
REM  clean-mystic-binaries.bat
REM  Removes 65 compiled ELF binaries from the MysticIRC repo.
REM  These are build artifacts — all can be rebuilt from source.
REM  Run from the MysticIRC repo root.
REM  After running: git add -A && git commit -m "Remove compiled ELF binaries (65 build artifacts)"
REM ============================================================

echo Cleaning 65 compiled ELF binaries from MysticIRC repo...
echo.

REM --- attic/ (2) ---
del "attic\ans2png"
del "attic\experimental\bmpcompare"

REM --- examples/ (5) ---
del "examples\hslink-src\hslink"
del "examples\hslink-src\test_hslink"
del "examples\marc\marc"
del "examples\sdl_demo\sdl_demo"
del "examples\utrayit\mkicon"

REM --- mystic/ (18) ---
del "mystic\109to110"
del "mystic\fidopoll"
del "mystic\install"
del "mystic\install_make"
del "mystic\m_prot_binkp"
del "mystic\m_protocol_binkp"
del "mystic\maketheme"
del "mystic\marc"
del "mystic\mbbsutil"
del "mystic\mdl\m_rip\rip_render"
del "mystic\mdl\mdltest10"
del "mystic\mide"
del "mystic\mplc"
del "mystic\mutil"
del "mystic\mystpack"
del "mystic\nodespy"
del "mystic\qwkpoll"
del "mystic\rip2ans"
del "mystic\test_recconfig"
del "mystic\utilities\ansi2pipe"
del "mystic\utilities\mbbshtml\mbbshtml"

REM --- mystic_crypt/ (1) ---
del "mystic_crypt\cl_demo"

REM --- mystic_makemenu/ (1) ---
del "mystic_makemenu\makemenu"

REM --- mystic_modem/ (1) ---
del "mystic_modem\modemcfg"

REM --- mystic_molms/ (1) ---
del "mystic_molms\molms"

REM --- mystic_mterm/ (1) ---
del "mystic_mterm\editor"

REM --- mystic_ripview/ (2) ---
del "mystic_ripview\linux\ripview"
del "mystic_ripview\t_ripdraw"

REM --- mystic_sdl/ (1) ---
del "mystic_sdl\sdl_demo"

REM --- mystic_spell/ (1) ---
del "mystic_spell\spelltest"

REM --- mystic_test/ (27) ---
del "mystic_test\109to110"
del "mystic_test\fidopoll"
del "mystic_test\fidopoll_lin32"
del "mystic_test\install"
del "mystic_test\install_lin32"
del "mystic_test\install_lin64"
del "mystic_test\install_make"
del "mystic_test\m_prot_binkp"
del "mystic_test\maketheme"
del "mystic_test\marc"
del "mystic_test\mbbsutil"
del "mystic_test\mdl\m_protocol_binkp"
del "mystic_test\mdl\m_rip\rip_render"
del "mystic_test\mide"
del "mystic_test\mide_lin32"
del "mystic_test\mplc"
del "mystic_test\mplc_lin32"
del "mystic_test\mplc_lin64"
del "mystic_test\mutil"
del "mystic_test\mutil_lin32"
del "mystic_test\mystfoss"
del "mystic_test\mystic_lin32"
del "mystic_test\mystpack"
del "mystic_test\nodespy"
del "mystic_test\qwkpoll"
del "mystic_test\rip2ans"
del "mystic_test\test_recconfig"

REM --- mystic_texteditor/ (1) ---
del "mystic_texteditor\mystic_texteditor"

echo.
echo Done. 65 ELF binaries removed (43MB freed).
echo Now run:
echo   git add -A
echo   git commit -m "Remove compiled ELF binaries (65 build artifacts)"
echo   git push
pause

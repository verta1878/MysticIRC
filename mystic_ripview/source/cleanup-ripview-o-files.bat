@echo off
REM cleanup-ripview-o-files.bat
REM Removes .o build artifacts and compiled binary from mystic_ripview\source\
REM Safe to run — only deletes build outputs, not source or .ppu files
REM Date: 2026-10-29

cd /d "C:\Users\owner\Desktop\Claude\share\bbses\mysticirc\mystic_ripview\source"

del ripbmp.o
del ripdraw.o
del ripengine.o
del ripicon.o
del ripmouse.o
del ripstate.o
del riptext.o
del riptextvar.o
del ripview.o
del ripwidgets.o
del ripview

echo.
echo Done — 10 .o files and ripview binary removed.
echo Source (.pas), .ppu, and .rst files untouched.
pause

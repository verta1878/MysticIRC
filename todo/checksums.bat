@echo off
rem ============================================================================
rem  Generate CHECKSUMS.md5, CHECKSUMS.sha256, CHECKSUMS.txt
rem  Run from mysticbbsirc repo root
rem ============================================================================

if not exist LICENSE (
    echo ERROR: Run this from the mysticbbsirc repo root.
    pause
    goto :EOF
)

echo Generating checksums...

rem MD5
certutil -hashfile mysticbbsirc-session9.zip MD5 > CHECKSUMS.md5 2>nul
if errorlevel 1 (
    echo No zip file found. Checksumming all .pas files instead...
    del CHECKSUMS.md5 2>nul
    for /R %%F in (*.pas) do certutil -hashfile "%%F" MD5 >> CHECKSUMS.md5 2>nul
)

rem SHA256
certutil -hashfile mysticbbsirc-session9.zip SHA256 > CHECKSUMS.sha256 2>nul
if errorlevel 1 (
    del CHECKSUMS.sha256 2>nul
    for /R %%F in (*.pas) do certutil -hashfile "%%F" SHA256 >> CHECKSUMS.sha256 2>nul
)

rem Summary
echo mysticbbsirc checksums > CHECKSUMS.txt
echo Date: %DATE% %TIME% >> CHECKSUMS.txt
echo. >> CHECKSUMS.txt
echo See CHECKSUMS.md5 and CHECKSUMS.sha256 for details. >> CHECKSUMS.txt

echo Done. CHECKSUMS.md5, CHECKSUMS.sha256, CHECKSUMS.txt created.

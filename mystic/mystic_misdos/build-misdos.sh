#!/bin/sh
# Build the mystic_misdos WFC example (DOS-style MIS).
# Usage: ./build-misdos.sh [win32|os2|darwin]
#
# References the modem (mystic_modem) and binkp (mystic_mailer) add-ons, so
# their sources are on the unit path.  FPC RTL only otherwise (Crt for the
# console).  wfc.ans must sit next to the built binary at run time.
FPC=${FPC:-ppc386}
HERE=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$HERE/out" "$HERE/bin"
find "$HERE" -name '*.ppu' -delete 2>/dev/null
find "$HERE" -name '*.o'   -delete 2>/dev/null

# absolute -FU/-FE (see mystic_rip/build-rip.sh note on the FPC 2.6.2
# relative-output link quirk); pull in the two add-on module dirs.
OPTS="-B -Mobjfpc -O2 -Fu../mdl -Fi../mdl -Fu../mystic_modem -Fu../mystic_mailer -FU$HERE/out -FE$HERE/bin"

case "$1" in
  win32)  echo "Building mystic_misdos for Win32...";  T="-Twin32" ;;
  os2)    echo "Building mystic_misdos for OS/2 (compile-only off-OS/2)...";
          T="-Tos2 -XPi386-os2- -s" ;;
  darwin) echo "Building mystic_misdos for Darwin...";  T="-Tdarwin" ;;
  *)      echo "Building mystic_misdos for Linux...";   T="-Tlinux" ;;
esac

cd "$HERE"
# shellcheck disable=SC2086
$FPC $T $OPTS misdos.pas && cp -f wfc.ans bin/ 2>/dev/null
echo "Done.  bin/misdos  (keep wfc.ans beside it)"

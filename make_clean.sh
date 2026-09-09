#!/usr/bin/env bash
# ============================================================
#  Mystic 1.11IRC A4 — Clean all build output + deprecated files
#  Linux/macOS equivalent of cleanup.bat
# ============================================================
ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT"

echo "Mystic 1.11IRC A4 cleanup — $(date)"

# ---- Deprecated source files (moved to attic/) ----

rm -f mystic_modem/fossil_dos.pas \
      mystic_modem/mystfoss.pas \
      mystic_modem/netmodem.pas \
      mystic_modem/netmodem_fossil.pas \
      mystic_modem/mdm_serial.pas \
      mystic_modem/mdm_modem.pas 2>/dev/null

rm -f mystic_mailer/mlr_binkp.pas 2>/dev/null

for d in mystic/mdl mystic_test/mdl; do
  rm -f "$d/serial.pas" "$d/serial_ext.pas" "$d/serial_irq.pas" \
       "$d/m_serial.pas" "$d/m_fossil.pas" "$d/m_fossil_io.pas" \
       "$d/m_io_fossil.pas" 2>/dev/null
done

rm -rf examples/serial examples/netfosdlv1 examples/ripkit 2>/dev/null

# ---- Build output directories ----
rm -rf out out-linux out-win32 out-dos out-os2 out-freebsd out-darwin out-i8086 outwin release 2>/dev/null

for d in mystic_modem mystic_misdos mystic_ripview mystic_mterm mystic_molms \
         mystic_ansiedit mystic_makemenu mystic_spell mystic_crypt mystic_sdl \
         mystic_texteditor mystic_mailer mystic_test; do
  rm -rf "$d/out" "$d/bin" "$d/out-i8086" 2>/dev/null
done

# ---- Compiled units/objects (NOT in fpc264irc or attic) ----
find . -path "*/fpc264irc" -prune -o -path "*/attic" -prune -o \
  \( -name '*.ppu' -o -name '*.o' -o -name '*.a' -o -name '*.or' -o -name '*.res' -o -name '*.mpx' \) -print | \
  grep -v '/fpc264irc/' | grep -v '/attic/' | grep -v '/libs/' | xargs rm -f 2>/dev/null

# ---- Linker artifacts ----
rm -f link.res ppas.sh ppas.bat 2>/dev/null

# ---- Root-level binaries ----
for bin in mystic mis mutil mplc mide mbbsutil fidopoll nodespy \
           qwkpoll mystpack install install_make maketheme 109to110 \
           marc mystfoss ansiedit ripview ans2rip ans2png \
           molms mterm modemcfg makemenu spelltest cl_demo \
           misdos wfcdemo mailer squish_example mystic_texteditor; do
  rm -f "$bin" "$bin.exe" 2>/dev/null
done

# ---- Build logs ----
find . -path "*/attic" -prune -o -name '*.build.log' -print | xargs rm -f 2>/dev/null

echo "Clean."

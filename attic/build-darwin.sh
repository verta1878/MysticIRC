#!/usr/bin/env bash
# ============================================================
#  Mystic 1.10 fork - Darwin / macOS build  (FPC 2.6.4irc r3, i386)
#  Usage:  ./build-darwin.sh            build every binary
#          ./build-darwin.sh mis        build a single target
#  Linux/Unix: build.sh   Windows: build-win32.bat   OS/2: build-os2.sh
# ------------------------------------------------------------
#  This fork LINKS Darwin binaries from Linux (proven 2026-07-08:
#  14/14 Mach-O i386).  The recipe (full detail in INSTALL, Darwin
#  section, and DECISIONS.md):
#
#    1. A cctools/ld64 cross toolchain for i386-apple-darwin10, with the
#       tools ALSO symlinked to FPC's default cross prefix i386-darwin-*
#       (i386-darwin-as, -ld, -ar, ...).  Put its bin/ on PATH.
#    2. A macOS SDK (10.6 suits this FPC era) with usr/lib/crt1.o
#       present.  If the SDK lacks crt1.o, build it from Apple's Csu
#       (the 10.4-compat "v1" variant, incl. dyld_glue.s) - see INSTALL.
#    3. The i386-darwin RTL built with the EXTERNAL cctools assembler
#       (NOT -Amacho: modern ld64 rejects FPC's internal Mach-O writer).
#
#  With those present this links real binaries.  WITHOUT a Mach-O
#  toolchain, set COMPILE_ONLY=1 to stop after verified Mach-O objects.
#
#  Env:
#    FPC=/path/to/ppc386
#    SDK=/path/to/MacOSX10.6.sdk          (required for linking)
#    DARWINUNITS="-Fu... -Fu..."          the i386-darwin RTL + packages
#    COMPILE_ONLY=1                        objects only, no link
#    XPPREFIX=i386-darwin-                 cross-tool prefix (default shown)
# ============================================================
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT"
BIN="$ROOT/out_darwin/bin"; UNITS="$ROOT/out_darwin/units"
mkdir -p "$BIN" "$UNITS"

FPC="${FPC:-ppc386}"
SDK="${SDK:-}"
DARWINUNITS="${DARWINUNITS:-}"
COMPILE_ONLY="${COMPILE_ONLY:-0}"
XPPREFIX="${XPPREFIX:-i386-darwin-}"

# Auto-discover the ld64 cross toolchain.  The repo now BUNDLES a relocatable
# Linux-x86_64 ld64 (libs/ld64-linux-x86_64) so no build step is needed
# on that host type; fall back to a locally-built one otherwise.
# Checked: bundled in-repo, $DARWIN_XTOOLS, ~/darwin/xtools, /opt/darwin/xtools.
if [ "$COMPILE_ONLY" != "1" ]; then
  BUNDLED="$ROOT/libs/ld64-linux-x86_64"
  for xt in "$BUNDLED" "${DARWIN_XTOOLS:-}" "$HOME/darwin/xtools" /opt/darwin/xtools; do
    if [ -n "$xt" ] && [ -x "$xt/bin/${XPPREFIX}ld" ]; then
      case ":$PATH:" in *":$xt/bin:"*) ;; *) PATH="$xt/bin:$PATH"; export PATH ;; esac
      # the bundled ld64 carries its Apple runtime libs alongside it
      if [ -d "$xt/lib" ]; then
        case ":${LD_LIBRARY_PATH:-}:" in *":$xt/lib:"*) ;; *) LD_LIBRARY_PATH="$xt/lib:${LD_LIBRARY_PATH:-}"; export LD_LIBRARY_PATH ;; esac
      fi
      echo "Darwin toolchain: $xt/bin"
      break
    fi
  done
  if ! command -v "${XPPREFIX}ld" >/dev/null 2>&1; then
    echo "NOTE: no ${XPPREFIX}ld on PATH. Build it once with" >&2
    echo "      build-ld64-toolchain.sh, or set COMPILE_ONLY=1." >&2
  fi
  # Auto-discover an SDK too, if not given.
  if [ -z "$SDK" ]; then
    for s in "${MACOS_SDK:-}" "$HOME/darwin"/MacOSX*.sdk /opt/darwin/MacOSX*.sdk; do
      [ -n "$s" ] && [ -d "$s" ] && { SDK="$s"; echo "Darwin SDK: $SDK"; break; }
    done
  fi
fi

FPCOPTS="-Tdarwin -Mdelphi -Fumdl -Fumystic -Fimdl -Fimystic -Fomdl"
FPCOPTS="$FPCOPTS -FU$UNITS -FE$BIN"
[ -n "$DARWINUNITS" ] && FPCOPTS="$FPCOPTS $DARWINUNITS"

if [ "$COMPILE_ONLY" = "1" ]; then
  FPCOPTS="$FPCOPTS -Amacho -Cn"
  echo "Darwin build: COMPILE-ONLY (Mach-O objects, no link)."
else
  FPCOPTS="$FPCOPTS -XP$XPPREFIX"
  if [ -n "$SDK" ]; then
    FPCOPTS="$FPCOPTS -XR$SDK"
  else
    echo "WARNING: no SDK set; linking will likely fail. Set SDK=... or COMPILE_ONLY=1." >&2
  fi
  echo "Darwin build: FULL (compile + link via ld64/SDK)."
fi

ALL="mystic mis mutil mplc mide mbbsutil fidopoll nodespy qwkpoll \
     mystpack install install_make maketheme 109to110"
TARGETS="$*"; [ -z "$TARGETS" ] && TARGETS="$ALL"

clean() { find . -name '*.ppu' -delete 2>/dev/null; find . -name '*.o' -delete 2>/dev/null; }

rc=0
for t in $TARGETS; do
  clean
  if "$FPC" $FPCOPTS "mystic/$t.pas" > "$ROOT/out_darwin/$t.build.log" 2>&1; then
    if [ "$COMPILE_ONLY" = "1" ]; then
      printf "  COMPILED %-14s (Mach-O objects)\n" "$t"
    else
      printf "  OK    %-14s\n" "$t"
    fi
  else
    printf "  FAIL  %-14s (see out_darwin/%s.build.log)\n" "$t" "$t"
    grep -iE '\bError\b|\bFatal\b|ld: ' "$ROOT/out_darwin/$t.build.log" | head -2 | sed 's/^/          /'
    rc=1
  fi
done
exit $rc

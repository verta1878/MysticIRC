#!/usr/bin/env bash
# ==========================================================================
#  A40 import - deferred compile/verify tests
#
#  Run AFTER the A40 import is complete (kept out of the import loop to save
#  build resources).  Verifies the anchor is intact and the A40-touched units
#  compile clean.
#
#  Usage:
#    ./mystic/tests/a40/run.sh
#    FPC=/path/to/ppc386 ./mystic/tests/a40/run.sh
#    FPC=<fpc264irc>/bin/ppc386 FPCROOT=<fpc264irc> ./mystic/tests/a40/run.sh
#
#  The compiler defaults to `ppc386` on PATH.  Set FPCROOT to a fpc264irc
#  checkout to use its bundled cross tools and units (as build-linux.sh does).
# ==========================================================================
set -u
# TDIR from $0 so the suite can be relocated; ROOT is three levels up
# (mystic/tests/a40 -> repo root).
TDIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$TDIR/../../.." && pwd)"
FPC="${FPC:-ppc386}"
FPCROOT="${FPCROOT:-}"
OUT="$(mktemp -d)"
PASS=0; FAIL=0

hdr(){ echo ""; echo "=== $* ==="; }
ok(){  echo "  PASS: $*"; PASS=$((PASS+1)); }
no(){  echo "  FAIL: $*"; FAIL=$((FAIL+1)); }

command -v "$FPC" >/dev/null 2>&1 || { echo "no compiler: $FPC (set FPC=)"; exit 2; }

CMN="-Tlinux -Mdelphi -Fu$ROOT/mdl -Fu$ROOT/mystic -Fi$ROOT/mdl -Fi$ROOT/mystic"
CMN="$CMN -Fl/usr/lib/i386-linux-gnu -FU$OUT -FE$OUT"
# Match build-linux.sh: the fork compiler needs its own tools and unit paths.
[ -n "$FPCROOT" ] && CMN="$CMN -FD$FPCROOT/bin/tools/i386-linux -Fu$FPCROOT/bin/units/i386-linux"

# 1. anchor check (compiles + runs)
hdr "1. record anchors (SizeOf must be unchanged)"
if "$FPC" $CMN "$TDIR/check_anchors.pas" >"$OUT/anchor.log" 2>&1 && "$OUT/check_anchors"; then
  ok "anchors intact"
else
  no "anchor check failed (see $OUT/anchor.log)"; grep -iE "error|mismatch|fail" "$OUT/anchor.log" | head
fi

# 2. compile the A40-touched units (compile-only, -Cn)
hdr "2. A40-touched units compile"
for u in bbs_cfg_echomail mutil_echoexport bbs_database mutil_common mutil_echofix; do
  if "$FPC" $CMN -Cn "$ROOT/mystic/$u.pas" >"$OUT/$u.log" 2>&1 && [ -f "$OUT/$u.o" ]; then
    ok "$u.pas"
  else
    no "$u.pas (see $OUT/$u.log)"; grep -iE "error|fatal" "$OUT/$u.log" | grep -vi deprecated | head -3
  fi
done

# 3. logstamp format codes (A40 configurable log timestamp)
hdr "3. logstamp format codes (A40)"
if "$FPC" $CMN "$TDIR/check_logstamp.pas" >"$OUT/logstamp.log" 2>&1 && "$OUT/check_logstamp"; then
  ok "logstamp format codes render correctly"
else
  no "logstamp check failed (see $OUT/logstamp.log)"; grep -iE "error|mismatch|fail" "$OUT/logstamp.log" | head
fi

echo ""
echo "=== summary: $PASS passed, $FAIL failed ==="
echo "(logs in $OUT)"
[ "$FAIL" -eq 0 ]

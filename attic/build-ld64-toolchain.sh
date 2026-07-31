#!/usr/bin/env bash
# ============================================================
#  build-ld64-toolchain.sh - build the cctools/ld64 cross linker
#  that FPC needs to LINK Mystic for Darwin (Mach-O i386) from a
#  Linux host.  Run ONCE per machine/container; the result is
#  reused by ./build-darwin.sh (both in the repo root).
#
#  WHY this isn't just shipped as a binary:
#   - Apple's ld64 is open source (APSL) but builds into a HOST-
#     specific ELF that also needs Apple's libdispatch/Blocks
#     runtime - not portable across host OS/arch, so we build it
#     locally instead of committing a binary that only runs on one
#     kind of host.
#   - The macOS SDK is Apple-licensed and ~257MB; it CANNOT live in
#     this GPL repo.  You supply it (extract from your own Xcode);
#     point SDK=... at it.
#
#  ld64 is the LINKER for the Darwin *output* only.  Other targets
#  use their own linkers (win32 = FPC internal PE; os2 = emxbind;
#  linux = GNU ld), so there is deliberately no single linker shared
#  across targets - each output format needs its own.
#
#  Usage:
#    ./build-ld64-toolchain.sh [PREFIX]
#       PREFIX defaults to $HOME/darwin/xtools
#  Produces:  $PREFIX/bin/i386-apple-darwin10-{ld,as,ar,...}
#             + symlinks i386-darwin-*  (FPC's default cross prefix)
# ============================================================
set -e
PREFIX="${1:-$HOME/darwin/xtools}"
WORK="${WORK:-$HOME/darwin/build}"
TARGET=i386-apple-darwin10
JOBS="$(nproc 2>/dev/null || echo 2)"

echo "==> ld64 toolchain -> $PREFIX  (work: $WORK)"
mkdir -p "$WORK" "$PREFIX"

# 1. prerequisites (Debian/Ubuntu names; adjust for your distro)
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get install -y clang llvm-dev uuid-dev libblocksruntime-dev \
       cmake ninja-build git build-essential >/dev/null 2>&1 || \
       echo "  (install clang llvm-dev uuid-dev libblocksruntime-dev cmake ninja-build git yourself)"
fi

# 2. Apple libdispatch (cctools needs it on Linux)
if [ ! -f "$PREFIX/lib/libdispatch.so" ]; then
  echo "==> building apple-libdispatch"
  cd "$WORK"
  [ -d apple-libdispatch ] || git clone --depth 1 \
    https://github.com/tpoechtrager/apple-libdispatch.git
  cd apple-libdispatch
  cmake -G Ninja -B build -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ >/dev/null
  cmake --build build >/dev/null
  cmake --install build >/dev/null
fi

# 3. cctools + ld64
if [ ! -x "$PREFIX/bin/$TARGET-ld" ]; then
  echo "==> building cctools-port / ld64"
  cd "$WORK"
  [ -d cctools-port ] || git clone --depth 1 \
    https://github.com/tpoechtrager/cctools-port.git
  cd cctools-port/cctools
  export CFLAGS="-I$PREFIX/include" CXXFLAGS="-I$PREFIX/include"
  export LDFLAGS="-L$PREFIX/lib -Wl,-rpath,$PREFIX/lib"
  ./configure --prefix="$PREFIX" --target="$TARGET" >/dev/null
  make -j"$JOBS" >/dev/null
  make install >/dev/null
fi

# 4. FPC's default cross prefix is i386-darwin-*, so symlink
cd "$PREFIX/bin"
for t in as ld ar ranlib nm strip otool lipo libtool objdump; do
  [ -f "$TARGET-$t" ] && ln -sf "$TARGET-$t" "i386-darwin-$t"
done

echo "==> done."
echo "    Add to PATH:  export PATH=$PREFIX/bin:\$PATH"
echo "    Then:         SDK=/path/to/MacOSX10.6.sdk ./build-darwin.sh"
echo
echo "    If your SDK lacks usr/lib/crt1.o, build it from Apple Csu"
echo "    (10.4-compat variant w/ dyld_glue.s) - see INSTALL Darwin section."

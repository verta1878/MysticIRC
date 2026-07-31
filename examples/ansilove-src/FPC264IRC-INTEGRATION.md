# ansilove + ImageMagick integration for fpc264irc

This document describes how to add ansilove and ImageMagick to the
fpc264irc three-step build root so all 7 OS targets can use the
RIPscrip validation workflow.

## Overview

The fpc264irc build root compiles FPC, then the RTL, then the
target binaries. ansilove and ImageMagick are C programs that
build separately — they are NOT FPC units. They are development
tools used alongside the FPC toolchain.

## Three-step integration

### Step 1: Build fpc264irc (existing)

    ./build-linux.sh    # builds ppc386 + ppcx64 + RTL units

### Step 2: Build ansilove (new)

ansilove depends on libansilove + libgd. Build order:

    # libansilove (the rendering library)
    cd libs/ansilove-src/ansilove/libansilove
    mkdir build && cd build
    cmake .. && make
    # produces libansilove.so / libansilove.a

    # ansilove (the CLI tool)
    cd libs/ansilove-src/ansilove
    mkdir build && cd build
    cmake .. && make
    # produces ansilove binary

For cross-compile targets, use the appropriate toolchain:

    Target         Toolchain                  Notes
    -------        ---------                  -----
    linux-i386     gcc -m32                   needs libgd-dev:i386
    linux-x64      gcc                        needs libgd-dev
    win32          i686-w64-mingw32-gcc       needs mingw libgd
    freebsd-i386   (native or cross)          pkg install libgd
    darwin-i386    (10.6 SDK cross)           needs libgd port
    os2            not supported              no libgd for OS/2
    dos            not applicable             no graphical output

### Step 3: Install ImageMagick (system package)

ImageMagick is too large to cross-compile. Install from the
host OS package manager:

    Linux:    apt-get install imagemagick
    macOS:    brew install imagemagick
    FreeBSD:  pkg install ImageMagick7
    Windows:  choco install imagemagick
              or download from imagemagick.org

## Target support matrix

    Target         ansilove    ImageMagick    rip_render (FPC)
    ------         --------    -----------    ----------------
    linux-i386     build       apt-get        fpc -Ti386
    linux-x64      build       apt-get        fpc -Tx86_64
    win32          cross       installer      ppc386 -Twin32
    freebsd        build       pkg            ppc386 -Tfreebsd
    darwin-i386    cross       brew           ppc386 -Tdarwin
    os2            N/A         N/A            ppc386 -Tos2
    dos            N/A         N/A            ppc386 -Tgo32v2

## What goes into fpc264irc repo

Add to the fpc264irc repository:

    fpc264irc/
      libs/
        ansilove/
          libansilove/     # source (BSD license)
          ansilove/        # source (BSD license)
          BUILD.md         # build instructions per target
        imagemagick/
          INSTALL.md       # install instructions per target

The fpc264irc author can integrate these into the build scripts
at their discretion. The key point: these are C programs with
their own build systems (CMake for ansilove), not FPC units.

## License

- ansilove: BSD 2-Clause (see libs/ansilove-src/ansilove/LICENSE)
- ImageMagick: Apache 2.0 (not bundled, system install only)
- rip_render: GPL v3 (part of mystic-bbs-irc)

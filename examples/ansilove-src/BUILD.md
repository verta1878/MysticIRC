# Building ansilove from source

ansilove renders ANSI art (.ans) to PNG images. It consists of two parts:
- libansilove: the rendering library (BSD license)
- ansilove: the command-line tool (BSD license)

## Dependencies

All platforms need:
- CMake (build system)
- C compiler (gcc, clang, or MSVC)
- libgd (image creation library)
- libpng, libjpeg, zlib (image format support, usually pulled by libgd)

## Linux (Debian/Ubuntu)

    apt-get install cmake libgd-dev
    cd libansilove && mkdir build && cd build
    cmake .. && make && sudo make install
    cd ../../ansilove && mkdir build && cd build
    cmake .. && make && sudo make install

Or just: apt-get install ansilove

## Linux (RHEL/Fedora)

    dnf install cmake gd-devel
    # then build as above

## FreeBSD

    pkg install cmake libgd ansilove
    # or build from source as above

## macOS

    brew install cmake gd
    # then build from source as above
    # or: brew install ansilove

## Windows (MSYS2/MinGW)

    pacman -S mingw-w64-x86_64-cmake mingw-w64-x86_64-gd
    # then build from source with cmake

## Windows (Visual Studio)

    vcpkg install libgd
    cmake -G "Visual Studio 17 2022" ..
    cmake --build . --config Release

## OS/2

    Not tested. Requires libgd port for OS/2.

## DOS

    Not applicable. ansilove requires a graphical output library.

# ImageMagick

ImageMagick is used for image comparison (compare, montage, convert).
It is too large to bundle. Install from your OS package manager:

    Linux:   apt-get install imagemagick
    macOS:   brew install imagemagick
    FreeBSD: pkg install ImageMagick7
    Windows: https://imagemagick.org/script/download.php

# Usage in the RIPscrip workflow

See mystic_rip/TOOLS.md for the validation workflow.

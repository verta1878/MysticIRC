# OS/2 (LX) executables built on Linux — documentation set

**Status: WORKING.** FPC 2.6.2 OS/2 programs link to valid OS/2 LX `.exe`
files entirely on a Linux x86-64 host, no OS/2 machine required. This is the
same problem the ArcaOS / bitwiseworks toolchain maintainers have tracked as
an open "build the emx toolchain on Linux" issue.

    $ ppc386 -Tos2 ... maketheme.pas
    $ file maketheme.exe
    maketheme.exe: MS-DOS executable, LX for OS/2 (console) i80386, emx 0.9d

## Read in this order

1. **TECHNICAL-REFERENCE.md** — the authoritative explanation: the emx a.out
   format, every fix (binutils N_IMP import patch, the `a.out-emx` BFD target,
   the unpadded-a_text subtlety, the 32-bit emxbind build, the loader stub, the
   data-alignment wrapper), and an emxbind-error → fix debugging map.

2. **BUILD-ON-UBUNTU-24.04.md** — a from-scratch, copy-pasteable recipe to
   rebuild the whole toolchain on Ubuntu 24.04 (and, with a package-manager
   swap, other Linux distros).

## Where the durable pieces live

    libs/emxbind-src/                  emxbind port: C sources, shim/, binary
    libs/emxbind-src/emxl.exe          emx loader stub (bind step)
    libs/emxbind-src/i386-os2-ld.wrapper.sh   the two-pass data-align ld wrapper
    libs/emxbind-src/binutils-patch/   BFD patches + i386os2.c + apply README
    libs/emxbind-src/upstream/         pristine emx source zips (GPL compliance)
    UPSTREAM-EMX.md (repo root)        how/where to contribute this upstream

Everything needed to rebuild is committed; the built tools themselves are
container-ephemeral and are regenerated via the Ubuntu recipe.

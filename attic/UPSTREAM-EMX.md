# Contributing the Linux-hosted emxbind upstream

> NOTE: the emxbind Linux-port sources + shim referenced below now live in the
> FPC 2.6.4irc fork (fpc264irc/patches/os2-cross/ and its bin/tools/i386-emx/),
> not in this repo's libs/. They were moved there once the fork absorbed the
> OS/2 cross toolchain. Paths below that say `libs/emxbind-src/...` now map to
> the fork's `patches/os2-cross/`.

We built emx's `emxbind` (the OS/2 a.out -> LX final-link tool) so it compiles
and runs on a modern Linux x86-64 host.  A Linux-hosted emx toolchain is an
open request in the OS/2 dev community (e.g. bitwiseworks/gcc-os2 issue
"How can I build an emx toolchain for OS/2 on Linux..."), so this work is worth
offering back.

## What to contribute
The emxbind C sources are UNMODIFIED upstream emx (emxsrcr.zip / emxsrcd*.zip).
The novel, contributable part is the small shim layer in libs/emxbind-src/shim/
that lets those sources build on modern Linux/glibc/gcc 13:

  sys/moddef.h   Reconstructed from the moddef .c implementation + emxbind's
                 use of the API.  (The real header ships only in the emx binary
                 dev kit, not the source ZIPs - so a from-source Linux build
                 has nothing to #include.  This fills that gap.)
  sys/user.h     Minimal emx core-dump header (only the fields exec.c reads).
  io.h, share.h  Map emx low-level I/O + sopen() sharing to POSIX.
  emxcompat.h/.c emx libc helpers (_strncpy, stricmp, _errno, _fsopen,
                 _defext, _remext, _path, _fncmp, optswchar) -> POSIX.

Build: `gcc -I. -Ishim -include shim/emxcompat.h -w -c *.c && gcc *.o -o emxbind`

## Suggested recipients
- bitwiseworks (ArcaOS toolchain): github.com/bitwiseworks  (gcc-os2 issues)
- Netlabs / eCSoft2 emx maintainers
- The emx project on SourceForge (sourceforge.net/projects/emx)
- FPC dev list (they ship emx sources in fpcbuild and own the OS/2 target)

## Honest scope note for the upstream report
This gets EMXBIND building/running on Linux.  It does NOT by itself finish
Linux-hosted OS/2 linking: FPC's OS/2 RTL imports use emx's a.out IMPORT#
format, and stock GNU binutils treats those N_IMP1/N_IMP2 symbols as debug,
not linkable defs.  The known fix is emx's bfd/aoutx.h patch (exclude N_IMP
from IS_STAB; add translate_from_native_sym_flags cases -> BSF_EMX_IMPORT1/2)
plus writer/ld plumbing, ported from emx-patched binutils 2.6 (gbinusrc.zip)
into a modern binutils.  That BFD port is the larger, still-open task; the
emxbind piece is done here and is independently useful.

## License
emx is GPL (c) 1990-1998 Eberhard Mattes.  The shim headers/glue are offered
under the GPL to match, so they can be merged into the emx sources directly.

## UPDATE: binutils N_IMP patch + a.out-emx target (major)
The contribution is now substantially bigger than just the emxbind Linux port:

1. **emxbind builds + runs on Linux** (32-bit; shim/ layer). DONE.
2. **binutils 2.30 N_IMP patch** (binutils-patch/aoutx.h.patch, archive.c.patch,
   bfd-in2.h.patch): teaches GNU ld to resolve emx a.out IMPORT# DLL symbols.
   With it, ld links the FPC OS/2 RTL's imports on Linux - the piece the
   bitwiseworks/ArcaOS "emx toolchain on Linux" issue calls hard. DONE +
   VERIFIED.
3. **a.out-emx BFD target** (binutils-patch/i386os2.c + targets.c/config.bfd
   patches): adds emx a.out layout as a selectable ld target. Registered and
   working for magic/entry/startup; the text file-offset (0x400) write path is
   the one remaining piece.

This is, as far as we can tell, further than any public Linux-hosted OS/2 link
toolchain has gotten. It's worth offering to bitwiseworks/ArcaOS and the FPC
OS/2 maintainers even in its current state - the N_IMP patch alone unblocks a
long-standing problem.

## How to submit (manual - the maintainer must post these)
- bitwiseworks/gcc-os2 issue tracker: reference their "emx toolchain on Linux"
  issue; attach binutils-patch/ + OS2-LINK-STATUS.md.
- FPC bug tracker / fpc-devel list: they own the OS/2 target and ship emx
  sources in fpcbuild; the N_IMP patch + a.out-emx target are directly useful.
- emx project on SourceForge.

--------------------------------------------------------------------------------
## Where the files live (for reviewers)

Repository: **https://github.com/verta1878/mystic-bbs-irc**

    libs/emxbind-src/                       emxbind Linux port
      *.c, *.h, shim/                       buildable sources (32-bit: gcc -m32)
      emxl.exe                              emx loader stub (bind step)
      i386-os2-ld.wrapper.sh                two-pass data-alignment ld wrapper
      binutils-patch/                       the 7 patches + i386os2.c + README
        aoutx.h.patch  archive.c.patch  bfd-in2.h.patch
        targets.c.patch  config.bfd.patch  configure.patch  Makefile.in.patch
        i386os2.c                           the "a.out-emx" BFD target
      upstream/                             pristine emx source zips (GPL src)

    docs/os2-linux-toolchain/
      TECHNICAL-REFERENCE.md                format + every fix + debug map
      BUILD-ON-UBUNTU-24.04.md              from-scratch reproduction recipe

Direct links:
  https://github.com/verta1878/mystic-bbs-irc/tree/main/libs/emxbind-src
  https://github.com/verta1878/mystic-bbs-irc/tree/main/libs/emxbind-src/binutils-patch
  https://github.com/verta1878/mystic-bbs-irc/tree/main/docs/os2-linux-toolchain

Verified: a pristine binutils 2.30 tree + the binutils-patch/ files builds an
ld reporting `supported targets: a.out-i386 a.out-emx`; a full FPC 2.6.2
`ppc386 -Tos2` then links a valid OS/2 LX .exe on Linux.

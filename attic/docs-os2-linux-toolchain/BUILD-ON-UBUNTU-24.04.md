# Building the OS/2-on-Linux toolchain — Ubuntu 24.04 recipe

A step-by-step, copy-pasteable recipe to reproduce the working OS/2 (LX)
cross-link toolchain **from scratch** on Ubuntu 24.04.  For *why* each piece is
needed, see `TECHNICAL-REFERENCE.md`; this file is the *how*.

Tested distro:

    Ubuntu 24.04.4 LTS (Noble Numbat), kernel 6.18.5 x86_64, gcc 13.3.0

Other Debian/Ubuntu releases should work with the same steps.  Non-Debian
distros: translate the `apt` line to your package manager; everything else is
identical.

--------------------------------------------------------------------------------
## Step 0 — prerequisites

    sudo apt update
    sudo apt install -y build-essential gcc-multilib libc6-dev-i386 \
                        wget unzip python3 texinfo

  * `gcc-multilib` + `libc6-dev-i386` are **required** — emxbind must be built
    32-bit (see Technical Reference §4).  Without them the `-m32` build fails.
  * `texinfo` provides `makeinfo`; we pass `MAKEINFO=true` to skip docs anyway.

You also need the fork's pinned **FPC 2.6.2** (i386) available as `ppc386` on
PATH.  In this repo it lives under the build host's FPC tree; the DOS/OS2
toolchain zips in `libs/` also bundle the compiler.

--------------------------------------------------------------------------------
## Step 1 — binutils 2.30 with the emx patches

    # get the source
    wget https://ftp.gnu.org/gnu/binutils/binutils-2.30.tar.gz
    tar xzf binutils-2.30.tar.gz
    cd binutils-2.30

    # apply the emx BFD patches (from this repo)
    P=<repo>/libs/emxbind-src/binutils-patch
    patch bfd/aoutx.h    < $P/aoutx.h.patch
    patch bfd/archive.c  < $P/archive.c.patch
    patch bfd/bfd-in2.h  < $P/bfd-in2.h.patch

    # add the a.out-emx BFD target
    cp $P/i386os2.c bfd/i386os2.c
    patch bfd/targets.c  < $P/targets.c.patch
    patch bfd/config.bfd < $P/config.bfd.patch

    # register the target's object mapping + source (if not already patched):
    #   bfd/configure : add after the i386_aout_vec) case:
    #     i386_os2_vec) tb="$tb i386os2.lo aout32.lo" ;;
    #   bfd/Makefile.in : add  i386os2.lo  and  i386os2.c  next to i386aout.*

    ./configure --target=i386-aout --enable-obsolete --disable-werror \
                --disable-nls --disable-gdb --disable-readline --disable-sim \
                MAKEINFO=true
    make all-ld all-binutils MAKEINFO=true

Install into a private tools prefix (example uses `~/os2tools/xbin/bin`):

    B=~/os2tools/xbin/bin ; mkdir -p $B
    cp ld/ld-new          $B/i386-aout-ld
    cp binutils/ar        $B/i386-aout-ar
    cp binutils/nm-new    $B/i386-aout-nm
    cp binutils/ranlib    $B/i386-aout-ranlib
    cp gas/as-new         $B/i386-os2-as        # assembler for FPC's os2 target
    # (also symlink i386-os2-{ar,nm,ranlib,strip} -> i386-aout-* as FPC expects)

Verify the emx target is present:

    $B/i386-aout-ld -V | grep a.out-emx
    #   supported targets: a.out-i386 a.out-emx ...

--------------------------------------------------------------------------------
## Step 2 — re-index the FPC OS/2 import archives

The patched `ranlib` must rewrite the import archives' symbol index so `ld`
can find the DLL import stubs:

    for a in <fpc262>/rtl/units/os2/*.a; do
        ~/os2tools/xbin/bin/i386-aout-ranlib "$a"
    done

Sanity check (should list the import stubs, not empty):

    ~/os2tools/xbin/bin/i386-aout-nm --print-armap \
        <fpc262>/rtl/units/os2/doscalls.a | grep index_311
    #   _$dll$doscalls$_index_311 in IMPORT#1

--------------------------------------------------------------------------------
## Step 3 — build emxbind (32-bit!)

    cd <repo>/libs/emxbind-src
    gcc -m32 -I. -Ishim -include shim/emxcompat.h -w -c *.c
    gcc -m32 *.o -o ~/os2tools/xbin/bin/emxbind
    ln -sf emxbind ~/os2tools/xbin/bin/i386-os2-emxbind
    ~/os2tools/xbin/bin/emxbind        # should print: emxbind 0.9d ...

If you see `sizeof=64` symptoms or "invalid a.out file (header)" later, you
built 64-bit by mistake — re-check `-m32` and that the multilib packages from
Step 0 are installed.

--------------------------------------------------------------------------------
## Step 4 — install the emx loader stub

    cp <repo>/libs/emxbind-src/emxl.exe ~/os2tools/xbin/bin/emxl.exe

(`emxl.exe` originates from the emx runtime `emxrt.zip`, `emx/bin/emxl.exe`.)

--------------------------------------------------------------------------------
## Step 5 — install the data-alignment ld wrapper

Create `~/os2tools/xbin/bin/i386-os2-ld` (the name FPC calls) as a two-pass
wrapper around the real `i386-aout-ld`:

    #!/bin/bash
    REALLD=~/os2tools/xbin/bin/i386-aout-ld
    TXTBASE=0x10000
    OUT="a.out"; i=0; ARGS=("$@")
    while [ $i -lt ${#ARGS[@]} ]; do
      [ "${ARGS[$i]}" = "-o" ] && OUT="${ARGS[$((i+1))]}"
      i=$((i+1))
    done
    "$REALLD" --oformat a.out-emx -Ttext $TXTBASE "$@" 2>/dev/null
    TS=$(od -An -t u4 -j 4 -N 4 "$OUT" 2>/dev/null | tr -d ' ')
    if [ -n "$TS" ] && [ "$TS" -gt 0 ] 2>/dev/null; then
      DB=$(python3 -c "ts=$TS; tb=0x10000; print('0x%x'%((((tb+ts)-1)&~0xffff)+0x10000))")
      exec "$REALLD" --oformat a.out-emx -Ttext $TXTBASE -Tdata $DB "$@"
    else
      exec "$REALLD" --oformat a.out-emx -Ttext $TXTBASE "$@"
    fi

    chmod +x ~/os2tools/xbin/bin/i386-os2-ld

Keep the real linker as `i386-aout-ld` and the wrapper as `i386-os2-ld` — do
**not** overwrite the real ld with the wrapper.

--------------------------------------------------------------------------------
## Step 6 — build an OS/2 program

    export PATH=~/os2tools/xbin/bin:<fpc262>/bin:$PATH
    U=<fpc262>/rtl/units/os2
    ppc386 -Tos2 -XPi386-os2- -Mdelphi -Fu$U -FE/tmp/out myprog.pas

    file /tmp/out/myprog.exe
    #   MS-DOS executable, LX for OS/2 (console) i80386, emx 0.9d

That's a native OS/2 LX executable, built entirely on Linux.

--------------------------------------------------------------------------------
## Ephemeral-container note

On a throwaway build container these tools live outside the repo (e.g. under
`~/os2tools`) and are wiped on reset.  The **durable** artifacts — the patches,
`i386os2.c`, the emxbind sources+shim, `emxl.exe`, and the wrapper text — are
all committed under `libs/emxbind-src/` and `docs/os2-linux-toolchain/`, so the
toolchain can be rebuilt from the repo with the steps above.  Budget ~15-20 min
for the binutils build.

--------------------------------------------------------------------------------
## Quick troubleshooting

    symptom                                 -> step to recheck
    "unknown target vector i386_os2_vec"    -> Step 1: bfd/configure vec mapping
    ld: cannot find a.out-emx               -> Step 1: targets.c/config.bfd + rebuild
    undefined reference to $dll$...          -> Step 2: re-ranlib the .a files
    "invalid a.out file (header)"           -> Step 3: build emxbind with -m32
    "multiple commands specified"           -> emxbind getopt "+" (see Tech Ref §4)
    "cannot open 'emxl.exe'"                -> Step 4: emxl.exe on PATH
    "invalid a.out file (startup code)"     -> Step 1: i386os2.c 0x400 / ZMAGIC
    "invalid a.out file (startup data)"     -> Step 5: the data-alignment wrapper

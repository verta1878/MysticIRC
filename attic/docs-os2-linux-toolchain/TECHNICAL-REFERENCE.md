# Building OS/2 (LX) executables on Linux — Technical Reference

Status: **WORKING.**  A complete FPC 2.6.2 OS/2 program links to a valid OS/2
LX `.exe` entirely on a Linux x86-64 host, with no OS/2 machine involved.

    $ ppc386 -Tos2 -XPi386-os2- ... maketheme.pas
    emxbind 0.9d -- Copyright (c) 1991-1997 by Eberhard Mattes
    $ file maketheme.exe
    maketheme.exe: MS-DOS executable, LX for OS/2 (console) i80386, emx 0.9d

This document is the authoritative, self-contained explanation of how the
toolchain works and every fix required to reproduce it.  It is deliberately
detailed: the pieces here are subtle, span three separate programs (ld,
emxbind, FPC's prt0), and are the same set of problems the ArcaOS /
bitwiseworks maintainers have tracked as an open "build the emx toolchain on
Linux" issue.

--------------------------------------------------------------------------------
## 0. The big picture

FPC's OS/2 code generator emits **a.out** object files and then links them into
an OS/2 **LX** executable in two stages:

    .pas --ppc386--> .s --as--> .o (a.out) --ld--> a.out image --emxbind--> .exe (LX)
                                             ^^                  ^^^^^^^
                                    (1) GNU ld link       (2) emx "bind" a.out->LX

Both stages historically run on OS/2.  Getting them to run on Linux requires:

  A. a GNU `ld` that understands emx's a.out **import** symbols (for DLL calls),
  B. a GNU `ld` that emits emx's a.out **layout** (text at file 0x400, text
     vaddr 0x10000, data at the 64 KB segment boundary),
  C. `emxbind` **built to run on Linux** (it's normally an OS/2 binary), and
  D. the emx **loader stub** `emxl.exe` for emxbind's bind step.

Each of A–D was a distinct problem.  All are solved.  The rest of this document
covers them in order, with the exact code.

--------------------------------------------------------------------------------
## 1. Host environment

    OS:        Ubuntu 24.04.4 LTS (Noble Numbat)
    Kernel:    Linux 6.18.5 x86_64
    Compiler:  gcc 13.3.0  (with gcc-multilib for 32-bit builds)
    FPC:       2.6.2, i386 (the fork's pinned system compiler)
    binutils:  2.30 source, configured --target=i386-aout --enable-obsolete

32-bit dev libraries are required (for emxbind — see §4):

    apt install gcc-multilib libc6-dev-i386

--------------------------------------------------------------------------------
## 2. emx a.out — the format emxbind expects

emxbind validates the a.out image handed to it in several stages (emx exec.c).
Understanding these checks is the key to the whole thing:

  1. **Header magic** — `a_in_h.magic == 0x010b` (ZMAGIC).
  2. **Entry** — `a_in_h.entry == TEXT_BASE == 0x10000`.
  3. **Startup code** — the first bytes of text (at file offset `A_OUT_OFFSET`
     = **0x400**) must be FPC's prt0 entry stub:

         68 40 00 00 00     push $0x40
         e8 .. .. .. ..     call __dos_init       (at text+5)
         eb 0c              jmp  __init           (at text+10)
         e8 .. .. .. ..     call __dos_syscall    (at text+12)

  4. **Startup data** — an `os2_bind_header` embedded by FPC's prt0 at the start
     of the **data** segment.  emxbind locates it at

         a_in_data = A_OUT_OFFSET(0x400) + round_page(a_in_h.text_size)

     and checks its first three fields:

         text_base == TEXT_BASE (0x10000)
         text_end  == TEXT_BASE + a_in_h.text_size
         data_base == round_segment(TEXT_BASE + a_in_h.text_size)

     where `round_segment(x)` rounds up to a **64 KB** boundary
     (`((x-1) & ~0xffff) + 0x10000`), and `options[]` must contain a NUL.

The whole game is producing an a.out that satisfies all four — with a stock
modern GNU ld that knows nothing about emx.

--------------------------------------------------------------------------------
## 3. Fix A + B — binutils 2.30 patches

Two independent problems live in BFD (binutils' object-file library).

### 3.1  Import symbols (N_IMP1 / N_IMP2)  — the DLL-call blocker

FPC's OS/2 RTL calls OS/2 API functions through import stubs shipped in emx
import archives (e.g. `doscalls.a`).  Each stub is a tiny a.out object with a
symbol like

    _$dll$doscalls$_index_311 = DOSCALLS.311        (DLL name + ordinal)

whose n_type is emx-specific: **N_IMP1 = 0x68** or **N_IMP2 = 0x6a**.  Those
values overlap the a.out **stab** (debug) range, so stock BFD classifies them
as debugging symbols and:

  * `ranlib`/`ar` leave them out of the archive symbol index (armap), so `ld`
    never even pulls the members, and
  * `ld` treats references to them as **undefined** → 320 "undefined reference
    to `$dll$doscalls$_index_NNN`" errors.

This is the piece everyone calls the hard part.  The fix teaches BFD to treat
N_IMP1/N_IMP2 as **defined absolute** symbols.  Patched files:

  * **bfd/bfd-in2.h** — define two new symbol flags:

        #define BSF_EMX_IMPORT1  (1 << 28)
        #define BSF_EMX_IMPORT2  (1 << 29)

  * **bfd/aoutx.h** — four changes:
      - define `N_IMP1 0x68`, `N_IMP2 0x6a`;
      - in `translate_from_native_sym_flags()` exclude N_IMP from the
        `(type & N_STAB)` debug skip, and add cases mapping
        `N_IMP1|N_EXT` → abs section + `BSF_EMX_IMPORT1` (and IMPORT2);
      - in `aout_link_add_symbols()` exclude N_IMP from the stab `continue`,
        and add `case N_IMP1|N_EXT: case N_IMP2|N_EXT:` → `bfd_abs_section_ptr`
        (so references resolve as defined);
      - in `aout_link_check_ar_symbols()` exclude N_IMP from the stab skip and
        add N_IMP to the "this object defines the symbol" set (so `ld` pulls
        the archive member).

  * **bfd/archive.c** — in `_bfd_compute_and_write_armap()` add
    `BSF_EMX_IMPORT1` to the flag mask that decides which symbols enter the
    armap, so `ranlib` indexes the import stubs.

After patching, re-index the FPC OS/2 import archives once:

    for a in <fpc>/rtl/units/os2/*.a; do i386-aout-ranlib "$a"; done

Result: `ld` resolves all ~320 imports and links a valid a.out.  The exact
diffs are in `binutils-patch/{aoutx.h,archive.c,bfd-in2.h}.patch`.

### 3.2  emx a.out layout — a new BFD target `a.out-emx`

emx's a.out differs from GNU's i386 a.out in three constants:

    text file offset   emx 0x400     GNU i386aout 0x20
    text vaddr/entry   emx 0x10000   GNU 0x1020
    data segment       emx 64 KB     GNU 4 MB (0x400000)

We add a dedicated BFD backend, **bfd/i386os2.c** (cloned from `i386aout.c`),
registered as target name `"a.out-emx"`.  Its config constants:

    #define N_TXTOFF(x)              0x400      /* text at file offset 0x400 */
    #define N_TXTADDR(x)             0x10000    /* text vaddr / entry        */
    #define SEGMENT_SIZE             0x10000    /* 64 KB data segment        */
    #define ZMAGIC_DISK_BLOCK_SIZE   0x400      /* forces text file pos 0x400*/

and in its `aout_backend_data` the **"text includes header"** flag is set to
**0** (not 1 as in i386aout.c) so the ZMAGIC path uses `zmagic_disk_block_size`
(0x400) for the text file position rather than the 32-byte exec header size.

Registration (three build-system patches):
  * **bfd/targets.c** — `extern const bfd_target i386_os2_vec;` + add it to the
    `_bfd_target_vector[]` list.
  * **bfd/config.bfd** — add `i386_os2_vec` to `targ_selvecs` for the
    `i[3-7]86-*-aout*` target.
  * **bfd/configure** — add the vec→object mapping:
        `i386_os2_vec) tb="$tb i386os2.lo aout32.lo" ;;`
  * **bfd/Makefile.in** — add `i386os2.lo` / `i386os2.c` to the source lists.

### 3.3  The unpadded-a_text subtlety (the last 0.5%)

BFD pads `.text` up to a page and records the **padded** size in the header's
`a_text`.  But FPC's prt0 computes the embedded `os2_bind_header.text_end` from
the **unpadded** text end (via the `__etext` link symbol).  So emxbind's

    text_end == TEXT_BASE + a_in_h.text_size

failed by exactly one page pad (observed 0xFC0 bytes of zero padding).

Fix, in `i386os2.c`'s `MY_write_object_contents`: before `WRITE_HEADERS`, set

    if (obj_textsec(abfd)->rawsize != 0)
      execp->a_text = obj_textsec(abfd)->rawsize;   /* unpadded size */

`rawsize` is BFD's pre-padding section size.  This makes the header report the
true text size (matching FPC's `__etext`) while the on-disk data position is
unaffected (it keys off the page-aligned filepos, not `a_text`).  emxbind's
`round_page(text_size)` still lands on the same data offset either way, so
locating the bind header is unaffected.

### 3.4  Build

    cd binutils-2.30            # fresh tree
    # apply the three .patch files + drop in i386os2.c + the 4 registration edits
    ./configure --target=i386-aout --enable-obsolete --disable-werror \
                --disable-nls --disable-gdb --disable-readline --disable-sim
    make all-ld all-binutils MAKEINFO=true
    # install ld/ld-new as i386-aout-ld, plus ar/nm/ranlib as i386-aout-*

--------------------------------------------------------------------------------
## 4. Fix C — emxbind on Linux

emxbind is Eberhard Mattes' GPL tool (emx 0.9d), normally an OS/2 binary.  We
build it to run on Linux from the upstream C sources (see `../..
/libs/emxbind-src/`).  Two things matter:

  * **Build 32-bit (`-m32`).**  emxbind's a.out structs use C `long`.  On
    64-bit Linux `long` is 8 bytes, which makes `struct a_out_header` 64 bytes
    instead of 32 and corrupts every field it reads.  Building 32-bit restores
    `long == 4` and the original layout.  Symptom if you forget: emxbind reports
    "invalid a.out file (header)" even on a correct image, and a debug print
    shows `sizeof(a_out_header)=64` and garbage field values.

  * **getopt `+` prefix.**  FPC appends emx runtime options after the input file
    (`... maketheme.out -ai -s8`).  glibc getopt permutes args by default and
    misparses `-a`/`-s` as emxbind *commands* → "multiple commands specified".
    Prefixing the getopt option string with `"+"` makes getopt stop at the
    first non-option, leaving the trailing runtime opts alone.

Build line (needs 32-bit libs):

    gcc -m32 -I. -Ishim -include shim/emxcompat.h -w -c *.c
    gcc -m32 *.o -o emxbind

The `shim/` directory (reconstructed `sys/moddef.h`, `sys/user.h`, io/share
headers, and `emxcompat` mapping emx libc-isms to POSIX) is what lets the
upstream emx C build on modern Linux; it is documented in
`libs/emxbind-src/BUILD.md`.

--------------------------------------------------------------------------------
## 5. Fix D — the emx loader stub

emxbind's bind step (`-b`) prepends the emx loader **`emxl.exe`** (1447 bytes,
from the emx runtime `emxrt.zip`, `emx/bin/emxl.exe`) to the LX image.  It must
be on PATH (or in the emxbind directory) or you get
`emxbind: cannot open 'emxl.exe'`.  It ships in `libs/emxbind-src/` alongside
the tool.

--------------------------------------------------------------------------------
## 6. The data-segment alignment wrapper

emxbind wants `data_base == round_segment(0x10000 + text_size)` — the data
segment on a **64 KB** boundary above text.  ld's built-in a.out link script
otherwise defaults data to 4 MB (0x400000).  Because the correct address
depends on `text_size` (known only after linking), we drive ld through a tiny
two-pass wrapper installed as **`i386-os2-ld`** (the name FPC calls):

    pass 1:  i386-aout-ld --oformat a.out-emx -Ttext 0x10000  <args>
             -> read text_size from the output header (offset 4)
    pass 2:  data_base = round_up(0x10000 + text_size, 0x10000)
             i386-aout-ld --oformat a.out-emx -Ttext 0x10000 -Tdata <db> <args>

(The wrapper is `bin/i386-os2-ld`; the real patched linker stays as
`bin/i386-aout-ld`.)  This makes the whole thing transparent to FPC: a single
`ppc386 -Tos2 ...` produces the `.exe`.

--------------------------------------------------------------------------------
## 7. End-to-end verification

    $ export PATH=<os2tools>/xbin/bin:<fpc262>/bin:$PATH
    $ ppc386 -Tos2 -XPi386-os2- -Mdelphi -Fu... -FE/tmp/out maketheme.pas
    emxbind 0.9d -- Copyright (c) 1991-1997 by Eberhard Mattes
    $ file /tmp/out/maketheme.exe
    ... MS-DOS executable, LX for OS/2 (console) i80386, emx 0.9d
    $ python3 - <<'PY'
    d=open('/tmp/out/maketheme.exe','rb').read()
    import struct; off=struct.unpack('<I',d[0x3c:0x40])[0]
    print('MZ', d[:2]==b'MZ', '| LX at 0x%x'%off, d[off:off+2]==b'LX')
    PY
    MZ True | LX at 0x600 True

--------------------------------------------------------------------------------
## 8. emxbind check → fix cross-reference (debugging map)

If a link breaks, match emxbind's error to the responsible fix:

    "undefined reference to $dll$..."      -> §3.1 N_IMP patch / re-ranlib the .a
    "invalid a.out file (header)"          -> §4 build emxbind 32-bit;
                                              also §3.2 entry must be 0x10000
    "multiple commands specified"          -> §4 getopt "+" prefix
    "cannot open 'emxl.exe'"               -> §5 put emxl.exe on PATH
    "invalid a.out file (startup code)"    -> §3.2 text must be at file 0x400
    "invalid a.out file (startup data)"    -> §3.3 unpadded a_text +
                                              §6 data_base at 64 KB boundary

--------------------------------------------------------------------------------
## 9. Files

    libs/emxbind-src/                     emxbind port (C sources + shim + binary)
    libs/emxbind-src/emxl.exe             emx loader stub
    libs/emxbind-src/binutils-patch/      the BFD patches + i386os2.c + README
      aoutx.h.patch  archive.c.patch  bfd-in2.h.patch
      i386os2.c      targets.c.patch  config.bfd.patch
    docs/os2-linux-toolchain/             this reference + distro build notes
    UPSTREAM-EMX.md                       how to contribute this upstream

--------------------------------------------------------------------------------
## 10. Licensing

emx (emxbind, emxl.exe, the BFD emx logic) is GPL (c) 1990-1998 Eberhard
Mattes.  binutils is GPL.  All patches and the i386os2.c target derive from GPL
sources and are offered under the GPL.  See COPYING.emx and the upstream source
archives in libs/emxbind-src/upstream/ for corresponding-source compliance.

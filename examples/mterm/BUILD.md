# Building OpenOLMS

OpenOLMS builds from one source tree to two targets:

- **Linux x86-64** — native, easiest; good for development and testing.
- **DOS (go32v2)** — the real deployment target; produces `OLMS.EXE` /
  `CONFIG.EXE` for use as a BBS mail door.

The same `src/` compiles for both. Two units are platform-specific and handled
automatically: the archiver (`olms_archiver.pas`) uses `TProcess` on Linux and
`Dos.Exec` on DOS via `{$IFDEF GO32V2}`; the SDL screen backend
(`olms_screen_sdl.pas`) is Linux-only and simply isn't referenced by the two
programs, so the DOS build ignores it.

---

## Linux build

Requires Free Pascal (`fpc` 3.x). The SDL backend (optional) needs `libSDL2`;
the archiver step calls an external `zip`/`unzip` (or PKZIP-style tool).

```sh
sh build/build-linux.sh
# or manually:
cd src
fpc -O2 olms.pas          # -> olms
fpc -O2 config.pas   # -> config  (rename to 'config' if you like)
```

Run it the way a BBS would (a dropfile + a JAM base in the directory):

```sh
./olms --dir <path> /DA   # scan -> QWK packet -> zipped .QWK
```

---

## DOS build (go32v2)

Produces real DOS executables. You need Free Pascal's **go32v2** cross target.
There are three ways to get it.

### Option 1 — use the prebuilt cross-toolchain (fastest)

Download `openolms-dos-toolchain.tar.gz` (released alongside the source),
unpack it, install the DOS binutils, and build:

```sh
tar -xzf openolms-dos-toolchain.tar.gz          # -> dos-toolchain/
sudo apt-get install -y binutils-djgpp
sudo ln -sf $(which i586-pc-msdosdjgpp-as) /usr/local/bin/i386-go32v2-as
sudo ln -sf $(which i586-pc-msdosdjgpp-ld) /usr/local/bin/i386-go32v2-ld
sudo ln -sf $(which i586-pc-msdosdjgpp-ar) /usr/local/bin/i386-go32v2-ar

CROSS=$PWD/dos-toolchain/bin/ppcross386 \
RTL=$PWD/dos-toolchain/units/go32v2 \
sh build/build-dos.sh
# -> src/OLMS.EXE, src/CONFIG.EXE
```

### Option 2 — build the cross-toolchain from source (reproducible)

Runs the exact steps used to produce Option 1 (fetches FPC source, builds
`ppcross386` + the go32v2 RTL + `dateutils`):

```sh
sh build/setup-dos-toolchain.sh
# then follow the CROSS=/RTL= line it prints, e.g.:
CROSS=/tmp/fpc-dos-build/fpc-3.2.2/compiler/ppcross386 \
RTL=/tmp/fpc-dos-build/fpc-3.2.2/rtl/units/go32v2 \
sh build/build-dos.sh
```

### Option 3 — build inside DOS / DOSBox

Install FPC's DOS-native distribution in DOSBox, then from `src\`:

```
build\BUILD.BAT
```

### DOS runtime

go32v2 programs need a DPMI host at runtime. **CWSDPMI.EXE** is bundled in
`dos-runtime/` (with its full GPLv2 source in `dos-runtime/cwsdpmi-src/`). Ship
`CWSDPMI.EXE` alongside `OLMS.EXE` / `CONFIG.EXE`; on bare DOS the program loads
it automatically, or run `CWSDPMI -p` once to make it resident.

Set the archiver in `OLMS.CFG` to real DOS tools:

```
Archiver=ZIP|PKZIP.EXE -ex %ARCHIVE% %FILES%|PKUNZIP.EXE -o %ARCHIVE%|1
```

### Verify the output

```sh
file src/OLMS.EXE
# MS-DOS executable, MZ for MS-DOS, COFF for MS-DOS, DJGPP go32 DOS extender
```

Then smoke-test in DOSBox or a DOS VM:

```
OLMS.EXE /DA        (with DORINFO1.DEF + a JAM base present)
```

---

## What links where (per target)

| Unit | Linux | DOS |
|------|-------|-----|
| olms_archiver | TProcess | Dos.Exec (`{$IFDEF GO32V2}`) |
| olms_screen_sdl | libSDL2 (optional) | not used |
| olms_kbd_console | CRT | CRT (not pulled by the two programs) |
| everything else | RTL/FCL | go32v2 RTL |

One tree, two targets, no manual edits — the guards do the switching.


## Modern config UI (SDL)

OpenOLMS's config tool can also render in a graphical 80x25 CP437 window on
Windows/Linux/macOS, using the SDL screen engine from Mystic BBS (TDosScreen by
James Coyle / g00r00, GPLv3 - in src/mystic_sdl/). Same config.pas as the DOS
build; the screen/keyboard backend is chosen by the USE_SDL define.

    sh build/build-modern.sh          # -> src/config (SDL UI)

Runtime needs SDL2 (Linux: libSDL2-2.0-0; Windows: SDL2.dll; macOS: libSDL2)
and VGA8X16.FNT from src/mystic_sdl/ in the working directory. The DOS build
(build-dos.sh) uses the CRT text backend and needs neither.

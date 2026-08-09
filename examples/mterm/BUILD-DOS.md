# Building OpenOLMS for DOS

OLMS is a DOS mail door, so the executables sysops actually run are
`OLMS.EXE` and `CONFIG.EXE` for 32-bit DOS. Free Pascal builds these with its
**go32v2** target. You need the go32v2 cross-compiler (or DOS-native FPC) —
it is a separate download; the stock Debian/Ubuntu `fpc` package does **not**
include it.

## What compiles on DOS

All units except the **SDL screen backend** (`olms_screen_sdl.pas`), which needs
SDL and is not used on DOS. The console backend (`olms_screen_console.pas`) is
what a DOS door uses. The archiver unit (`olms_archiver.pas`) auto-switches to
DOS shelling (`Dos.Exec` via `COMSPEC`) under `{$IFDEF GO32V2}`, instead of the
`TProcess` path used on Linux/Windows. No source edits needed — the guards
handle it.

## Option A — cross-compile from Linux/Windows (recommended)

1. Install FPC and add the **i386-go32v2** cross target. Two common routes:
   - Download the go32v2 cross build from https://www.freepascal.org/download.html
     (the "DOS (go32v2)" packages), or
   - Build the cross compiler: `make CPU_TARGET=i386 OS_TARGET=go32v2` in the
     FPC source tree, then `make install`.
   You also need **DJGPP**'s `cwsdpmi.exe` alongside the final EXE at runtime
   (the DPMI host for go32v2 programs).
2. Build:
   ```sh
   sh build/build-dos.sh
   ```
   or manually from `src/`:
   ```sh
   fpc -Tgo32v2 -O2 -Xs olms.pas
   fpc -Tgo32v2 -O2 -Xs config.pas
   ```
3. You get `OLMS.EXE` and `CONFIG.EXE`. Ship them with `CWSDPMI.EXE` from the
   `dos-runtime/` folder (already bundled in this repo, with its license doc).

## Option B — build inside DOS / DOSBox

1. Install the DOS-native Free Pascal in DOSBox (FPC's `dos` distribution).
2. From `src\`, run `build\BUILD.BAT` (or the two `fpc` lines above).

## Running on DOS

- `OLMS.EXE` is launched by the BBS as a door, reading a dropfile (DORINFO1.DEF
  or DOOR.SYS) from the node directory, plus the command-line switches
  (`/DA`, `/UA`, `/P=user`, `/RG`, etc. — see the manual/README).
- Set the archiver in `OLMS.CFG` to real DOS tools, e.g.:
  ```
  Archiver=ZIP|PKZIP.EXE -ex %ARCHIVE% %FILES%|PKUNZIP.EXE -o %ARCHIVE%|1
  ```
- `CONFIG.EXE` is the sysop config tool.

## Note on go32v2 vs. real-mode DOS

go32v2 produces 32-bit protected-mode DOS programs (needs a 386+ and the
CWSDPMI host). That is the standard modern way to build DOS FPC programs and
runs fine under DOSBox, real DOS, and NTVDM-free setups via CWSDPMI. A true
16-bit real-mode build is not supported by FPC.

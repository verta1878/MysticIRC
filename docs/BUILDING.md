# Building the fork (all targets)

Compiler: **FPC 2.6.4irc, release r3.1+, i386** (the default project compiler).
The 7 core shipped binaries are: `mystic`, `mis`, `mutil`, `mplc`, `fidopoll`,
`qwkpoll`, `maketheme`. Additional utilities (`mide`, `mbbsutil`, `nodespy`,
`mystpack`, `install`, `install_make`, `109to110`) and the built-in archiver
`marc` are also built by `build.sh`.

> The compiler is bundled at `libs/fpc264irc.tar.gz` (~276 MB, self-sustaining —
> it ships its own assembler/linker/archiver and prebuilt package units for all
> 6 targets). Unpack it and point `FPC=` at its `bin/ppc386`.
>
> **r3.1+ ships prebuilt PPUs** for `md5`, `crc`, `zipper`, `netdb`, `process`
> (and more) — no extra `-Fu` source paths are needed. The earlier `cNetDB` unit
> (fcl-net) has been retired; the fork uses the pure-Pascal `netdb` unit instead.
>
> PPU-compatible with stock FPC 2.6.4 (wordversion unchanged), so on-disk record
> layout / anchors are unaffected.

Compile-verified: **7/7 core targets** + all utilities + `marc` build clean with
r3.1+ using only `-Fubin/units/<target>`.

> **`marc`** (the built-in archiver) must compile in **`-Mobjfpc` mode** (the
> paszlib units require it; everything else is `-Mdelphi`). `build.sh` handles
> this automatically.

--------------------------------------------------------------------------------

## Native / primary

### Linux -> ELF
```bash
./build.sh                 # all targets
./build.sh mis             # a single target
```

### Windows -> PE32
```
build-win32.bat            # run on Windows
```
Also cross-buildable from Linux with the native compiler via `ppc386 -Twin32`
plus the i386-win32 RTL units.

--------------------------------------------------------------------------------

## Cross-compile targets (all built from a Linux host)

### OS/2 -> LX executables
```bash
LINK=1 ./build-os2.sh
```
- `LINK=1`  compile **and** link to `.exe`. Without it: compile-only (safe on
  any Linux host - no OS/2 toolchain required for the compile pass).
- **Needs:** the emx cross-toolchain on `PATH`, built from
  the fork bundle's emx tools (fpc264irc/bin/tools/i386-emx: patched binutils with the a.out-emx target +
  emxbind Linux port + emxl.exe + the i386-os2-ld alignment wrapper).
- Also builds natively on OS/2 (the FPC 2.6.2 OS/2 release bundles emx).

### macOS -> Mach-O
```bash
SDK=/path/to/MacOSX10.6.sdk ./build-darwin.sh      # all 14
SDK=/path/to/MacOSX10.6.sdk ./build-darwin.sh mis  # one target
```
- `SDK=`  path to a macOS SDK (10.6 suits the FPC 2.6.2 era; needs
  `usr/lib/crt1.o`). Auto-detected from `$MACOS_SDK`, `~/darwin/MacOSX*.sdk`, or
  `/opt/darwin/MacOSX*.sdk` if `SDK=` is unset.
- **Needs:** a cctools/ld64 cross-toolchain for i386-apple-darwin10 on `PATH`
  (tools also symlinked to FPC's `i386-darwin-*` prefix), AND the i386-darwin RTL
  built with that external assembler (not FPC's internal Mach-O writer).

### DOS -> go32v2 (protected-mode DPMI)
```bash
WATT32LIB=/path/to/watt ./build-dos.sh     # 14/14
```
- **Fully working.** All 14 targets build and link, including the 4 networked
  programs (`mis`, `fidopoll`, `nodespy`, `qwkpoll`) which link against Watt-32
  (`libwatt.a`) for TCP/IP on DOS.
- `WATT32LIB=`  directory containing `libwatt.a`.
- **Needs:** the go32v2 cross compiler + go32v2 RTL + binutils. See
  `docs/DOS-SOCKETS.md` for the Watt-32 socket layer details.

--------------------------------------------------------------------------------

## Notes

- **Stale headers:** the `build-*.sh` script header comments still say
  "1.10IRC fork". This is cosmetic - the scripts compile whatever is in the
  tree, so the imported A40 work builds regardless. (Tied to the open
  "what alpha is this fork" version-label decision.)
- **Packaging:** after building a target's binaries, use `make_release.sh`
  to assemble the FULL / UPDATE archives - see `docs/CREATING-THE-INSTALLER.md`.
  Archives are named `mystic-<VER>-<tag>-<mode>-<STAMP>.zip` (VER default
  `1.10irc`; STAMP defaults to today, MM-DD-YYYY, or pass `STAMP=FINAL` once an
  alpha's import is complete). Each archive unpacks into a matching top-level
  folder so FULL and UPDATE never merge, and its FILE_ID.DIZ ends with a
  `Released: <STAMP>` line.

## Building mystic_rip (RIPscrip engine)

The RIPscrip engine is in `mystic_rip/` and builds separately.

```bash
cd mystic_rip
./build-rip.sh              # Linux
./build-rip.sh win32        # Windows cross-compile
```

Individual tools:

```bash
fpc -Mobjfpc ans2rip.pas       # ANSI-to-RIP converter
fpc -Mobjfpc mkicons.pas       # .ICN icon generator
fpc -Mobjfpc ripmake.pas       # text-to-RIP generator
fpc -Mobjfpc test_phase3.pas   # test suite (48 tests)
```

The engine uses **FPC RTL only** (no MDL units). rip_view requires
SDL2 at runtime (not linked; loaded via sdl_bind.pas).

## Building maketheme

maketheme must be rebuilt when records.pas changes (RecTheme layout):

```bash
# Linux
./build.sh maketheme

# Windows cross-compile
ppc386 -Twin32 -Mdelphi -Fumystic -Fumdl -Fimystic -Fimdl \
    -Fu<units-path> -FEout/bin -B mystic/maketheme.pas
```

## Building mripedit (standalone RIP editor)

```bash
cd mripedit
fpc -Mobjfpc mripedit.pas
```

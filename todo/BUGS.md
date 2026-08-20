# Known Bugs — fpc264irc Compiler Issues

These bugs are in the **fpc264irc** compiler/RTL, not in Mystic BBS source code.
Mystic source compiles and links correctly on all working platforms.
Report these to the fpc264irc maintainer at github.com/verta1878/fpc264irc.

---

## BUG-001: Win32 EAccessViolation on Windows 11

**Status:** ✅ FIXED in r3.1 — Root cause: syswin.inc codepage signatures. Fix: r3 system.o

**Symptom:** Every Win32 binary crashes at startup with Runtime Error 216
(EAccessViolation) on Windows 11. Wine works fine.

**Affected:** All 15 Win32 targets (mystic.exe, mis.exe, mide.exe, etc.)

**Stack trace (mystic.exe):**
```
An unhandled exception occurred at $7756AAB6 :
EAccessViolation : Access violation
  $7756AAB6      ← ntdll.dll (crash site)
  $7759021C      ← ntdll.dll (exception handler)
  $77554333      ← ntdll.dll (exception dispatcher)
  $0040DD42      ← FPC RTL code
  $0040D754      ← FPC RTL code
  $0040CC23      ← FPC RTL code
  $0040CD5D
  $0040CE5B
  $0040BBD4
  $0040470F      ← near program entry
  $0040A883
```

**Stack trace (mide.exe):**
```
Runtime error 216 at $7756AAB6
  $7756AAB6
  $7759021C
  $77554333
  $0040DBE2
  $0040D5F4
  $0040CAC3
  $0040CBFD
  $0040CCFB
  $0040BA94
  $00407D6F
```

**Analysis:**
- Crash occurs before any Mystic application code executes
- Same ntdll.dll address ($7756AAB6) in every crash — deterministic
- $004xxxxx range = FPC compiled code (RTL initialization)
- Wine is lenient about Win32 API parameter validation; Win11 is strict
- PE header patching (NX_COMPAT, SubsystemVersion 6.0) did NOT fix it
- Root cause per maintainer: Win32 RTL was compiled with ad-hoc include
  paths. Fix: full RTL+packages rebuild using `make all` + `make packages`

**To reproduce:**
```pascal
Program test;
Begin
  WriteLn('hello');
End.
```
Build with fpc264irc pre-fix PPUs, copy to Windows 11, run.
If it crashes, the bug is in system.pp initialization.

**To verify fix:**
Build same test program with r3.1+ (c304d7c1) PPUs, test on real
Windows 11 (not Wine — Wine always works).

**Debug build:** Compile with `-gl` for line numbers in stack trace,
or `-Xm` for a .map file to map addresses to functions.

---

## BUG-002: FreeBSD — Console/Terminal Unit Incompatibility

**Status:** ✅ FIXED in r3.1 — FreeBSD Mystic now 15/15. m_ops, m_output, m_input, records.pas patched

**Symptom:** Mystic programs that use console I/O fail to compile for
i386-freebsd. Simple file utilities compile fine.

**Affected:** 12 of 15 targets fail. Pass: mystpack, install_make, marc.

**Error:**
```
m_term_ansi.pas(34,23) Error: Identifier not found "TOutput"
m_term_ansi.pas(34,23) Error: Error in type definition
```

**Root cause:** FreeBSD was missing from `m_ops.pas` platform detection
(no `{$IFDEF FREEBSD}` block). We fixed that — now it gets past platform
detection but fails on console/terminal units.

The issue: `m_output_linux.pas` uses Linux-specific terminal ioctls
that don't exist or differ on FreeBSD. The FreeBSD PPUs compile fine
but the Mystic console layer needs FreeBSD-specific adaptations.

**What we fixed in Mystic:**
- Added `{$IFDEF FREEBSD}` to `mdl/m_ops.pas` (defines UNIX + FS_SENSITIVE)
- Added `{$IFDEF FREEBSD}` to `mdl/m_output.pas` (uses m_Output_Linux)
- Added `{$IFDEF FREEBSD}` to `mdl/m_input.pas` (uses m_Input_Linux)

**What still needs fixing (in fpc264irc or Mystic):**
- FreeBSD terminal I/O differences in `m_output_linux.pas`
- Possibly needs a separate `m_output_freebsd.pas`
- Or FreeBSD PPUs need to export the same termio interfaces as Linux

**To reproduce:**
```bash
ppc386 -Tfreebsd -Mdelphi -Fumdl -Fumystic -Fimdl -Fimystic \
  -Fu<units/i386-freebsd> mystic/mystic.pas
```

**PPUs available:** 189 i386-freebsd PPUs in r3.1+ (c304d7c1)

---

## BUG-003: OS/2 EMX — Linker Fails (emxbind)

**Status:** OPEN — compiles to .out but cannot produce final executable

**Symptom:** All OS/2 targets compile successfully to `.out` (EMX format)
but the final linking step fails because `emxbind` needs `emxl.exe`
which is an OS/2-native tool not available on Linux.

**Error:**
```
mystic.pas(591,68) Error: Error while linking
```

**Analysis:**
- Pascal source compiles correctly for OS/2 target
- PPUs produce valid .out intermediate files
- The EMX linking chain requires: compile → .out → emxbind → .exe
- emxbind calls emxl.exe which is a 16-bit OS/2 executable
- Cannot run emxl.exe on Linux (no OS/2 emulation)

**PPUs available:** 84 i386-os2 PPUs

**To reproduce:**
```bash
ppc386 -Temx -Mdelphi -Fumdl -Fumystic -Fimdl -Fimystic \
  -Fu<units/i386-os2> mystic/mystic.pas
```

**Possible fix:** Either:
1. Port emxbind to run natively on Linux (rewrite the 16-bit parts)
2. Use a different OS/2 linker that runs on Linux
3. Accept compile-only on Linux, link on actual OS/2

---

## BUG-004: Darwin — Missing Base RTL PPUs

**Status:** ✅ FIXED in r3.1 — Darwin now 251 RTL+pkg PPUs + 171 LCL. fpintres included

**Symptom:** Mystic compilation fails immediately with missing units.

**Error:**
```
Fatal: Can't find unit fpintres used by Mystic
```

**Analysis:**
- 251 i386-darwin PPUs available in r3.1+
- PPUs are mostly CoreFoundation/GTK2 framework bindings
- Missing essential units: fpintres, classes, and other base RTL units
  that Mystic depends on
- The Darwin PPU set appears to have GUI/framework units but incomplete
  base RTL coverage

**PPUs present:** CFArray, CFBase, CFString, MacOSAll, MacTypes, atk,
baseunix, cairo, gdk2, glib2, gtk2, pango, sockets, system, sysutils,
unix, math, strings, dos, etc. (251 total)

**PPUs missing:** fpintres (at minimum — may be others)

**To reproduce:**
```bash
ppc386 -Tdarwin -Mdelphi -Fumdl -Fumystic -Fimdl -Fimystic \
  -Fu<units/i386-darwin> mystic/mystic.pas
```

---

## Resolved Bugs

### BUG-R001: Win32 RTL compiled with ad-hoc paths (FIXED in c304d7c1)
Win32 RTL was built with manual include paths instead of FPC's Makefile.
Fix: full rebuild using `make all` + `make packages` with proper
`OS_TARGET=win32 CPU_TARGET=i386 CROSSBINDIR=...` flags.

### BUG-R002: Stale PPUs — fpSetEUID/fpIsATTY (FIXED in r3.1+)
Prebuilt baseunix.ppu didn't export fpSetEUID/fpSetEGID. Fixed by
rebuilding from source. fpIsATTY still uses fpIOCtl(TIOCGPGRP) workaround.

### BUG-R003: fpc.cfg path incorrect (FIXED — user config)
fpc.cfg pointed to `/home/claude/fpc264irc_final/` instead of
`/home/claude/fpc264irc/`. Fix: update the path. Also needs
`-Fl/usr/lib/i386-linux-gnu` for 32-bit libraries on 64-bit hosts.


### BUG-R005: Win32 crash on Win11 (was BUG-001, FIXED in r3.1)
Root cause: syswin.inc codepage signatures in Win32 system unit.
Fix: rebuilt system.o with correct signatures.

### BUG-R006: FreeBSD console units (was BUG-002, FIXED in r3.1)
FreeBSD Mystic now 15/15. Patches to m_ops.pas, m_output.pas,
m_input.pas, records.pas for FreeBSD platform detection and
terminal I/O.

### BUG-R007: Darwin missing PPUs (was BUG-004, FIXED in r3.1)
Darwin now has 251 RTL+package PPUs + 171 LCL PPUs. fpintres included.
### BUG-R004: Bundled ld symlink broken (FIXED — user config)
`bin/ld` needs to symlink to `tools/i386-linux/i386-linux-ld`.
Fix: `ln -sf tools/i386-linux/i386-linux-ld bin/ld`

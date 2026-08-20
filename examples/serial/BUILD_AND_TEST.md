# netfosdl — DOS FOSSIL Driver: Build & Test

Verified working end-to-end on 2026-08-19 with fpc264irc's i8086
cross-compiler and DOSBox-X.

## Build

The RTL ships in the **huge** memory model and links from OMF `.a`
archives, so smart-linking (`-CX -XX`) is required:

```
ppcross8086 @etc/fpc-i8086.cfg -Tmsdos -Wmhuge -Mobjfpc \
    -CX -XX -Ch4096 \
    -Fu<dos-fossil-dir> -o NETFOSDL.EXE netfosdl.pas
```

- `-Wmhuge`  : match the shipped RTL memory model (mandatory)
- `-CX -XX`  : smart-link from the `.a` OMF archives
- `-Ch4096`  : small heap (the driver needs almost none)

Output: `NETFOSDL.EXE`, ~122 KB, a real MZ MS-DOS executable.

## Run / Test (DOSBox-X)

DOSBox-X must run a **386 + FPU** CPU — the FPC RTL emits x87 float
ops that fault on an 8086/8087:

```
[dosbox]
machine=svga_s3
fpu=true
[cpu]
core=normal
cputype=386
[serial]
serial1=dummy
```

Then in the DOS session:
```
NETFOSDL /port:1 /baud:9600      REM load the TSR
FOSTEST                          REM calls INT 14h, expects AX=1954h
NETFOSDL /u                      REM unload
```

## Verified results

```
Fn 04h Init:   AX=1954 BL=33 BH=5      (FOSSIL signature + max fn + rev 5)
Fn 03h Status: AH=60 AL=00             (line status = TX ready)
Fn 00h SetBaud: AX=6000                (9600,N,8,1 accepted)
Fn 05h Deinit: done
```

A separate program (FOSTEST) loads AFTER the resident driver and gets
the correct 1954h signature back through INT 14h — proving the hook,
dispatch, and residency all work.

## Bugs fixed to get here (2026-08-19)

1. **fossil.pas** — `uses Dos;` was placed after a procedure body in
   the implementation section (illegal Pascal). Moved to immediately
   after `implementation`. Was a hard compile error.

2. **netfosdl.pas** — missing `Flush(Output)` before going resident.
   FPC's TSR call does not flush stdout, so the install banner was
   lost. Added the flush.

3. **netfosdl.pas** — resident-size bug. FPC's `Keep()` reads the
   whole program MCB size (es:[3]); in the huge model that spans all
   ~640 KB of conventional memory, so no program could load after the
   TSR went resident. Replaced `Keep()` with a direct INT 21h/Fn 31h
   call that computes the true resident size (PSP → top of stack),
   dropping the heap. After the fix, programs load normally alongside
   the resident FOSSIL.

## Test programs (in this directory)
- `fostest.pas`  — minimal INT 14h Fn 04h signature check
- `fosfull.pas`  — exercises Fn 04h/03h/00h/05h

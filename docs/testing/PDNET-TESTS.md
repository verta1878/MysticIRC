# PabloDraw Protocol Testing

## Status: TESTED 2026-08-13

### Bug Found & Fixed
**StrToHostAddr byte order bug** in m_pdnet.pas line 682:
- `LongWord(StrToHostAddr(Host))` returns host byte order
- `sin_addr.s_addr` needs network byte order  
- Fix: `htonl(LongWord(StrToHostAddr(Host)))`
- This bug would have affected ALL PabloDraw connections on little-endian systems

### Loopback Results (pdnet_loopback.pas)
| Test | Result |
|------|--------|
| Canvas create 80x25 | PASS |
| Server start port 8765 | PASS |
| Client connect 127.0.0.1:8765 | PASS |
| Handshake / user join | PASS |
| Canvas update (char at 5,5) | PASS |
| Chat message relay | PASS |
| Cleanup | PASS (MSG_NOSIGNAL + try/except in Disconnect) |

**7/7 tests pass. Exit code 0. Clean shutdown.**

Fixes applied:
- Added PD_SEND_FLAGS (MSG_NOSIGNAL=$4000 on Unix) to all fpSend calls
- Wrapped Disconnect BYE send in try/except for broken pipe safety

## Plan

### Step 1: Compile m_pdnet standalone
```bash
cd mystic/ansiedit
fpc -Mdelphi m_pdnet.pas
fpc -Mdelphi m_pdserver.pas
fpc -Mdelphi m_pdclient.pas
fpc -Mdelphi m_pdtest.pas
```

### Step 2: Loopback test (same machine)
```bash
# Terminal 1: Start server
./m_pdserver 8000

# Terminal 2: Connect client
./m_pdclient localhost 8000 testuser
```

Verify:
- [ ] Client connects successfully
- [ ] Server shows "user joined" 
- [ ] Canvas sync sent to client
- [ ] Char placement broadcasts to other clients
- [ ] Chat messages relay
- [ ] Disconnect cleans up

### Step 3: DOSBox network test
```
# DOSBox config: [serial] → nullmodem
# Or use DOSBox-X with NE2000 emulation
# Build DOS target with fpc264irc -TDPMI
# Run m_pdserver.exe in one DOSBox instance
# Run m_pdclient.exe in another
```

Verify:
- [ ] DOS sockets work (our Sockets.pp unit)
- [ ] Protocol works over emulated network
- [ ] No byte-order issues (x86 = little-endian, same as protocol)

### Step 4: ansiedit integration test
```bash
# Terminal 1: Host
./ansiedit --host 8000

# Terminal 2: Join
./ansiedit --join localhost:8000
```

Or use ALT+S dialog in both instances.

Verify:
- [ ] ALT+S dialog connects
- [ ] Drawing appears on both screens
- [ ] Chat page works (ALT+C)
- [ ] /who shows both users
- [ ] Disconnect cleans up
- [ ] Canvas saves correctly after session

### Known Issues to Watch
- m_pdnet uses fpSocket/fpBind (POSIX) — may need {$IFDEF} for Windows
- Byte order of multi-byte fields in protocol messages
- Canvas size mismatch if server/client use different CANVAS_H
- Undo stack is local-only — remote edits don't push undo


### DOS Cross-Compile Test (2026-08-13)
- Compiler: ppc386 -Tgo32v2 (fpc264irc)
- Result: **0 compile errors** for DOS target
- Link fails: missing COFF GO32 linker (need DJGPP cross-tools)
- All m_pdnet code compiles clean with GO32V2 ifdefs
- Serial/FOSSIL code paths included in compilation

### ansiedit Smoke Test (Linux, 2026-08-13)
- Compiled: 0 errors, 7 notes
- Runs without crash (2-second timeout smoke test)
- Exit code 124 (timeout killed it = it was running)

### DOSBox Serial Test — BLOCKED
Needs:
1. DJGPP cross-linker for GO32V2 binary output
2. DOSBox-X with null-modem serial config
3. Two instances with FOSSIL driver loaded
4. sysop/0's DOSBox debug setup procedure

### DOS 16-bit Compile Test (2026-08-13)
- Compiler: ppcross8086 -WmHuge (fpc264irc)
- Memory model: Huge (matches pre-compiled RTL units)
- Result: **Code compiles**, link fails (needs OMF linker from fpc264irc build env)
- The units are OMF format (.a archives), not COFF
- Full fpc264irc build environment needed to produce .EXE
- This is NOT a code bug — it's a toolchain setup issue

### How to Build for DOS (when toolchain is ready)
```bash
# From a full fpc264irc install:
cd mystic/ansiedit
fpc264irc -Mdelphi -WmHuge -Ti8086 ansiedit.pas
# Produces: ansiedit.exe (plain DOS, no extender)
```

### DOSBox Test Setup (for sysop/0)
```ini
# dosbox.conf — Instance 1 (Server)
[serial]
serial1=nullmodem server:localhost port:5000

# dosbox.conf — Instance 2 (Client) 
[serial]
serial1=nullmodem port:5000

# Both instances:
# 1. Load FOSSIL driver (BNU, X00, or our netfosdl)
# 2. Run ansiedit.exe
# 3. ALT+S → Server (Instance 1) / Client (Instance 2)
# 4. Transport: Serial, Driver: FOSSIL, COM Port: 1
# 5. Connect
# 6. Draw on one, verify it appears on the other
```

### GO32V2 Toolchain Fix (2026-08-13)

**Problem found:** GO32V2 linking fails with undefined `getprotobyname`/
`gethostbyname`. These are libc DNS functions that Sockets.pp references,
but bare DOS has no libc.

**Fix needed in fpc264irc repo:**
1. Install `binutils-djgpp` package (provides `i586-pc-msdosdjgpp-ld`)
2. Create symlinks: `i386-go32v2-ld` → `i586-pc-msdosdjgpp-ld`
3. Use `-FD/usr/local/bin -XPi386-go32v2-` flags for cross-compile
4. Add WATTCP (watt32s) static library for DOS TCP/IP networking
   OR ifdef Sockets out of m_pdnet on DOS and use serial-only transport

**Compile command (once toolchain is fixed):**
```bash
ppc386 -Mdelphi -Tgo32v2 \
  -FD/usr/local/bin -XPi386-go32v2- \
  -Fu../../mdl -Fi../../mdl \
  -Fu$FPC264IRC/bin/units/i386-go32v2 \
  ansiedit.pas
```

### i8086 DOS Target — Class Support Issue (2026-08-13)
**Finding:** FPC i8086-msdos (plain DOS 16-bit) does NOT support
the `class` keyword. Only Turbo Pascal `object` type is available.

m_pdnet.pas uses `class` throughout (TPDNetServer, TPDNetClient,
TPDCanvas). Two options:
1. Convert m_pd* from `class` to `object` for DOS target
2. Use GO32V2 (32-bit DPMI) which supports classes

**chmod +x fix:** All fpc264irc binaries needed execute permission.
The earlier "can't call linker" errors were permission denied, not
missing tools.

**MSDOS define:** Added `{$IFDEF MSDOS}` to m_ops.pas alongside
the existing GO32V2 define — sets DOS and FS_IGNORE.

**Buffer sizes:** Reduced for DOS: PD_MAX_USERS=2, PD_MAX_MSG=256,
PD_RECV_BUF=256 (vs 32/65000/8192 on 32-bit).


### Networking by Platform
| Platform | TCP Stack | Serial |
|----------|-----------|--------|
| Linux/Windows | FPC Sockets | N/A |
| GO32V2 | fpc264irc Sockets.pp | FOSSIL/UART |
| i8086 | MSLAN + fpc264irc Sockets.pp | FOSSIL/UART |

No Watt-32. Our own Sockets.pp from fpc264irc handles all TCP.

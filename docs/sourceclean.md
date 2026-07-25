# Mystic Source Cleanup Status

## mdl/ — Mystic Development Library
Compiles 44/46 on Linux (2 Windows-only expected).

### Completed
- SDL files → mystic_sdl/
- BinkP programs → mystic/
- uforkpty → inlined into mis_client_telnet.pas
- m_sdlcrt → mystic_sdl/
- utextmouse → attic (unused)

### Deferred
- MDL refactor Phase 1: MIS — replace mdl wrappers with FPC RTL
- MDL refactor Phase 2: BBS core — same replacements across 50+ files
- MDL refactor Phase 3: Clean mdl — delete replaced units
- See docs/MDL-REFACTOR-PLAN.md

## mystic/ — BBS Core

### Completed
- Protocols wired: Xmodem, Ymodem, Ymodem-G, Zmodem, Zmodem-8K, Zmodem-32K, Kermit
- All protocols in m_protocol_*.pas (OOP stack)
- FTP server fixed: SIZE, REST/resume, PASV endian, WriteBuf hang
- HTTP server added: 262 lines, port 8080, webroot/ serving
- AViewMeta wired for MP3/MP4 tag viewing in file base
- default.txt replaced with g00r00 v1.12 prompts (554 prompts)
- BUG-029 AnsiString crash fixed (Header: AnsiString in HTTP)
- uforkpty inlined into mis_client_telnet.pas
- BinkP moved from mdl/ to mystic/
- mis.exe Win32 cross-compile working

### Needs Testing
- mis.exe BUG-029 fix verification on Windows
- HTTP server on real Mystic install
- Protocol transfers (Xmodem/Ymodem/Kermit) end-to-end

### Not Yet Wired
- FTP download prompt (528/529) in bbs_filebase.pas
- Protocol menu strings in protocol.dat
- HS/Link Pascal port
- Web download ([W] option — HTTP stub was empty)

### TODO — BBS Core Source Cleanup
- [ ] Review whatsnew.txt A61 items against source
- [ ] Check all A41-A63 ported items compile clean
- [ ] Audit mystic/*.pas for stale code
- [ ] Verify build scripts work
- [ ] Clean out-win32/ build artifacts
- [ ] Review mystic_rip/engine/ vs mystic/ for drift
- [ ] Remove stale .a library files
- [ ] Verify all 15 Linux binaries build
- [ ] Verify all 15 Win32 binaries build
- [ ] Verify 9 DOS binaries build

## Version Issues — MUST FIX

### default.txt is v1.12, code is v1.10
- default.txt has 555 prompts (from g00r00's v1.12)
- Our code (A38 base) expects fewer prompts
- Mystic reads prompts by line number — count mismatch will crash
- Need to either:
  a) Trim default.txt back to 1.10 prompt count, OR
  b) Update code to handle 1.12 prompt numbers
- The v1.12 prompts include 528-531 (FTP/Web download) which our
  code doesn't call yet — those are safe (unused prompts don't crash)
- Risk: prompts after the 1.10 count may shift existing prompts

### Version numbering
- Keep 1.10IRC for FidoNet version compatibility
- 1.10IRC is in alpha testing
- 1.11 is future roadmap
- upgrade.txt needs updating for IRC fork changes
- whatsnew.txt is current through A61

### upgrade.txt needs
- IRC fork specific upgrade notes
- Note about default.txt being v1.12 format
- Note about new protocol.dat entries needed
- Note about webroot/ directory creation
- Note about HTTP server on port 8080

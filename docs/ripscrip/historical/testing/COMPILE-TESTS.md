# Compilation Tests

## How to Run

```bash
# From repo root:

# RIP utilities
cd mystic_rip
fpc -Mdelphi -Fu. -Fuv1 -Fu../mdl -Fi../mdl ans2rip.pas
fpc -Mdelphi -Fu. -Fuv1 -Fu../mdl -Fi../mdl ans2png.pas
fpc -Mdelphi -Fu. -Fuv1 -Fu../mdl -Fi../mdl ripmake.pas
fpc -Mdelphi -Fu. -Fuv1 -Fu../mdl -Fi../mdl test_rip_files.pas

# mterm RIP engine
cd examples/mterm
fpc -Mdelphi mtrip.pas
fpc -Mdelphi mtrip_test.pas

# ripviewer
cd examples/ripviewer
fpc -Mdelphi -Fusource -Fusource/v1 source/ripview.pas

# HS/Link
cd examples/hslink-src
fpc -Mdelphi -Fu../../mdl -Fi../../mdl m_protocol_hslink.pas

# ansiedit (TODO: verify with m_pdnet)
cd mystic/ansiedit
fpc -Mdelphi -Fu../../mdl -Fi../../mdl ansiedit.pas
```

## Last Results (2026-08-13)

| File | Status | Notes |
|------|--------|-------|
| ans2rip.pas | ✅ 0 errors | |
| ans2png.pas | ✅ 1 note | |
| ripmake.pas | ✅ clean | |
| test_rip_files.pas | ✅ clean | |
| rip_surface.pas | ✅ 2 notes | |
| mtrip.pas + mtripgfx.pas | ✅ 0 errors 0 warnings | |
| mtrip_test.pas | ✅ links clean | |
| ripview.pas | ✅ clean | |
| m_protocol_hslink.pas | ✅ 1 note (FileCRC by design) | |
| mutil_common.pas | ✅ clean | |
| ansiedit.pas | ✅ 0 errors, 7 notes (unused vars) | with m_pdnet |

## TODO
- [ ] Compile ansiedit.pas with m_pdnet (needs socket units)
- [ ] Compile all mutil_*.pas modules
- [ ] Compile mis.pas with new 1.12 changes
- [ ] Cross-compile for Windows 32-bit
- [ ] Cross-compile for DOS (DPMI)


## Cross-Platform Compile Results (2026-08-14)

| Target | Binary | Status |
|--------|--------|--------|
| Linux x86_64 | ansiedit | ✅ 0 errors |
| Linux x86_64 | pdnet_loopback | ✅ 7/7 pass |
| Win32 i386 | pdnet_loopback.exe | ✅ 307KB produced |
| Win32 (Wine) | pdnet_loopback.exe | ✅ 7/7 pass (console, no X) |
| DOS i8086 | pdnet_loopback | ✅ compiles (CPU16 ifdefs), linker needs OMF |

### Windows Socket Compatibility
Added Windows wrappers in m_pdnet.pas (implementation section):
- fp* functions → WinSock2.* equivalents
- fpFD_ISSET returns LongInt (not Boolean) to match Unix
- fpAccept takes Pointer for AddrLen (not var)
- PD_SEND_FLAGS = 0 on Windows (no MSG_NOSIGNAL needed)

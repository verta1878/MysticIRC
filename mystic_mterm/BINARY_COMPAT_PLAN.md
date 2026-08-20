# OpenOLMS — Binary Compatibility Phase Plan

## Goal

Drop-in replacement for Peter Rocca's OLMS Version 2000.
Our binaries read and write the same data files — OLMS.CFG,
MESSAGES.CTL, USERS.DAT, SCREENS.DAT. A sysop swaps our
EXEs into an existing OLMS directory and everything works.

## Original OLMS Binaries (Turbo Pascal, real-mode DOS)

| Binary | Size | Purpose |
|--------|------|---------|
| OLMS.EXE | 190K | Main BBS door — QWK/QWKE/BlueWave mail |
| CONFIG.EXE | 116K | Configuration editor (12 screens) |
| EDITOR.EXE | 41K | Standalone message editor |
| MAINTAIN.EXE | 48K | Database maintenance/packing |
| USERCONF.EXE | 13K | User self-configuration |
| UPGRADE1.EXE | 11K | Database upgrade tool 1 |
| UPGRADE2.EXE | 9K | Database upgrade tool 2 |

## Our OpenOLMS Binaries (FPC, go32v2 DOS + Win32)

| Binary | Size | Maps to | Status |
|--------|------|---------|--------|
| openolms_dos.exe | 336K | OLMS.EXE | ✅ exists |
| olmscfg.exe | — | CONFIG.EXE | ✅ source exists, needs DOS build |
| olmsmnt.exe | 129K | MAINTAIN.EXE | ✅ exists |
| molms.exe | 383K | (Win32 client) | ✅ exists |
| editor.exe | — | EDITOR.EXE | ❌ missing |
| userconf.exe | — | USERCONF.EXE | ❌ missing |
| upgrade1.exe | — | UPGRADE1.EXE | ❌ missing |
| upgrade2.exe | — | UPGRADE2.EXE | ❌ missing |

## Data File Compatibility (CRITICAL)

These record layouts must match the original byte-for-byte:

| File | Size | Records |
|------|------|---------|
| OLMS.CFG | 14,889 bytes | Main configuration |
| MESSAGES.CTL | 24,512 bytes | Message control/area config |
| MESSAGES.IDX | 762 bytes | Message index |
| MESSAGES.INF | 6 bytes | Message info header |
| USERS.DAT | 14,340 bytes | User database |
| USERS.IDX | 4 bytes | User index |
| SCREENS.DAT | 65,808 bytes | ANSI display screens |

## Phases

### Phase L1: Record Layout Audit
- Hex-dump original OLMS.CFG, MESSAGES.CTL, USERS.DAT
- Reverse-engineer the exact packed record layouts
- Document field offsets, sizes, types
- Compare against our TOLMSConfig in OL_Config.pas

**Current problem:** Our TOLMSConfig uses FPC `String` (dynamic).
Original uses Turbo Pascal `String[N]` (fixed-size ShortString).
Must change to `packed record` with `String[N]` or `array[0..N] of Char`
for binary compatibility.

**Deliverable:** OL_Config_Compat.pas with exact record layouts

### Phase L2: Fix Record Layouts
- Rewrite TOLMSConfig as packed record with ShortStrings
- Verify: `SizeOf(TOLMSConfig) = 14889`
- Rewrite TMessageCtl, TUserRec similarly
- Verify all record sizes match original file sizes
- Test: load original OLMS.CFG with our code, read every field

**Deliverable:** All record types match original sizes

### Phase L3: Config Editor (CONFIG.EXE)
- olmscfg.pas already exists (8.3K)
- Verify it compiles for DOS (go32v2)
- Verify it reads/writes original OLMS.CFG correctly
- Test: load original config, save, binary diff = zero changes

**Deliverable:** olmscfg.exe reads/writes original OLMS.CFG

### Phase L4: Message Editor (EDITOR.EXE)
- Build editor.pas — standalone message reply editor
- OL_Editor.pas already has TOLEditor class with spell check
- Wrap in a standalone program that:
  - Reads a reply file (or creates new)
  - Full-screen editor with ANSI
  - Saves in QWK/QWKE/BlueWave reply format
- Match original EDITOR.EXE functionality from OLMS.DOC

**Deliverable:** editor.exe — standalone message editor

### Phase L5: User Configuration (USERCONF.EXE)
- Build userconf.pas — user self-configuration
- Reads USERS.DAT, shows user's settings, allows changes:
  - Default archive format (ZIP, ARJ, LHA, etc.)
  - Default protocol (Zmodem, Ymodem, etc.)
  - Area selection (which message areas to include)
  - Keyword filters
  - Tagline preferences
- Writes back to USERS.DAT in original format

**Deliverable:** userconf.exe — reads/writes original USERS.DAT

### Phase L6: Upgrade Tools (UPGRADE1.EXE, UPGRADE2.EXE)
- Build upgrade1.pas — upgrades older OLMS data to v2000 format
- Build upgrade2.pas — upgrades user database format
- These convert old record layouts to current:
  - UPGRADE1: MESSAGES.CTL field additions
  - UPGRADE2: USERS.DAT field additions
- May be simple field-copy programs (read old, write new with defaults)

**Deliverable:** upgrade1.exe + upgrade2.exe

### Phase L7: Integration Test
- Take the original Olms.rar contents
- Replace all 7 EXEs with our OpenOLMS versions
- Run CONFIG → verify all 12 screens load with original data
- Run OLMS → verify main door works with original data
- Run MAINTAIN → verify packing works
- Run USERCONF → verify user settings
- Run EDITOR → verify message editing

**Deliverable:** Drop-in replacement verified

### Phase L8: Documentation
- Update OpenOLMS README with compatibility notes
- Document record layout differences (if any)
- Document any behavioral differences from original
- Update WHATSNEW.TXT

**Deliverable:** Docs updated for binary-compatible release

## Record Layout Reverse-Engineering

To match the original, we need to hex-dump and decode:

```bash
# Dump OLMS.CFG
hexdump -C OLMS.CFG | head -100

# Check if it starts with a Turbo Pascal ShortString
# (first byte = length, then characters)
# Or if it's a fixed-size record with null padding
```

Turbo Pascal `String[80]` is 81 bytes: 1 length byte + 80 char bytes.
Turbo Pascal `String[255]` is 256 bytes.

The original OLMS.CFG at 14,889 bytes tells us the exact record size.
Every field offset must match for our code to read the original files.

## Compiler Notes

- Original: Turbo Pascal 7.0, real-mode DOS (MZ EXE, ~4K overhead)
- Ours: FPC 2.6.4irc or 3.2.2, go32v2 (DJGPP, ~130K overhead)
- Binary-exact EXE match is impossible (different code generation)
- **Data file compatibility** is the goal — same record layouts,
  same field offsets, same byte order
- Use `{$PACKRECORDS 1}` and `ShortString` types in FPC

## Credits

- Peter Rocca — original OLMS (permission granted)
- verta1878 — OpenOLMS project lead
- wrench — binary compatibility work
- kiddo — protocols (Zmodem Int64 fix)

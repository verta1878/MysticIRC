# mystic_modem — Legacy Dialup / Serial / FOSSIL Support

Optional add-on for Mystic BBS. Provides modem AT command handling,
FOSSIL INT 14h driver, serial port I/O, and WFC (Waiting-For-Caller)
screen support. Currently DOS-only; cross-platform serial porting
is planned (see below).

## Source Files

| File | Lines | Description |
|------|-------|-------------|
| modemcfg.pas | 123 | Modem configuration tool (program) |
| wfcdemo.pas | 96 | WFC demo program |
| mdm_config.pas | 191 | Config unit — INI reader for modem settings |
| mdm_serial.pas | 195 | Serial port wrapper — calls FPC Serial unit |
| mdm_modem.pas | 261 | Modem AT command handler (init, dial, answer, hangup) |
| mdm_fossil.pas | 306 | FOSSIL driver — dual backend: serial + INT 14h |
| mdm_wfc.pas | 174 | WFC screen drawing |
| mdm_miswfc.pas | 133 | MIS WFC screen integration |
| squish_example.pas | 106 | Squish message base example |

## Other Files

| File | Description |
|------|-------------|
| WFCSCRN.ANS | 80×25 CP437 WFC screen art |
| gen_wfc.py | Python script to regenerate WFC ANSI art |
| build-modem.sh | Cross-compile build script (Linux host) |

## Build

```bash
# From repo root, DOS target:
cd mystic_modem
FPC=../fpc264irc/bin/ppc386 ./build-modem.sh

# Or Win32:
FPC=../fpc264irc/bin/ppc386 ./build-modem.sh win32
```

Requires: `../mystic/mdl/` (MDL units), `../mystic/` (BBS_Records etc).

## Compile Status (go32v2)

| Target | Status |
|--------|--------|
| modemcfg | ✅ |
| wfcdemo | ✅ |
| mdm_config | ✅ |
| mdm_serial | ✅ |
| mdm_modem | ✅ |
| mdm_fossil | ✅ |
| mdm_wfc | ✅ |
| mdm_miswfc | ✅ |
| squish_example | ✅ |

## Dependencies

- `mystic/mdl/serial.pas` — UART 8250/16550 driver (DOS Port[])
- `mystic/mdl/m_serial.pas` — OOP wrapper (TModemSerial class)
- `mystic/mdl/serial_irq.pas` — IRQ-driven ring buffer (DOS, kiddo)
- `mystic/bbs_records.pas` — BBS record types
- FPC 2.6.4irc `Serial` unit PPU (9 platforms)

## Architecture

```
mdm_modem.pas (AT commands)
  → mdm_serial.pas (TModemSerial wrapper)
    → uses Serial (FPC RTL unit)
      → mdl/serial.pas (DOS: Port[], direct UART)
      → FPC serial.ppu (Unix: termios, Win: COM API, OS/2: DosDevIOCtl)

mdm_fossil.pas (FOSSIL driver)
  → fbSerial backend → mdm_serial.pas → Serial
  → fbInt14 backend → INT 14h (DOS only, {$IFDEF FOSSIL_INT14})
```

## Platforms

Currently DOS-only (go32v2). The serial hardware layer (`mdl/serial.pas`)
uses `Port[]` for direct UART I/O which only works on DOS.

### Future: Cross-Platform Serial

g00r00 removed serial from Mystic's mainline. To restore modem support
on all platforms, `mdl/serial.pas` needs platform ifdefs to use the
FPC RTL Serial unit (already compiled for 9 platforms with 26 functions).
The OOP wrapper (`m_serial.pas`) and modem layer (`mdm_modem.pas`) will
work unchanged — only the hardware layer needs porting.

```
PLANNED:
  mdl/serial.pas:
    {$IFDEF GO32V2} Port[] direct UART (current code)
    {$IFDEF UNIX}   FPC RTL Serial (termios)
    {$IFDEF WINDOWS} FPC RTL Serial (COM API)
    {$IFDEF OS2}    FPC RTL Serial (DosDevIOCtl)
```

## Credits

| Handle | Role |
|--------|------|
| wrench | Transport, FOSSIL, DVI/HDMI |
| sysop/0 | serial.pas UART layer |
| kiddo | serial_irq.pas ring buffer |
| evga | SIO rebuild |

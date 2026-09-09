# mystic_modem — Modem Config + WFC Support

Optional add-on for Mystic BBS. Provides modem configuration (INI reader),
WFC (Waiting-For-Caller) screen support, and FOSSIL driver abstraction.

Serial I/O is handled by `mystic/mdl/m_serial/m_serial.pas` (MDL).
AT modem commands are inlined in `mystic_misdos/misdos.pas`.

## Source Files

| File | Lines | Description |
|------|-------|-------------|
| modemcfg.pas | 123 | Modem configuration tool (program) |
| wfcdemo.pas | 96 | WFC demo program |
| squish_example.pas | 106 | Squish message base example |
| mdm_config.pas | 191 | Config unit — INI reader for modem settings |
| mdm_fossil.pas | 306 | FOSSIL driver — dual backend: serial + INT 14h |
| mdm_wfc.pas | 174 | WFC screen drawing |
| mdm_miswfc.pas | 133 | MIS WFC screen integration |

## Removed Files (in attic/)

| File | Reason |
|------|--------|
| mdm_serial.pas | Replaced by `mdl/m_serial/m_serial.pas` (no FPC Serial dependency) |
| mdm_modem.pas | AT commands inlined into `mystic_misdos/misdos.pas` |

## Other Files

| File | Description |
|------|-------------|
| WFCSCRN.ANS | 80×25 CP437 WFC screen art |
| gen_wfc.py | Python script to regenerate WFC ANSI art |
| build-modem.sh | Cross-compile build script (Linux host) |

## Build

```bash
cd mystic_modem
FPC=../fpc264irc/bin/ppcx64 ./build-modem.sh
```

Requires: `../mystic/mdl/` (MDL units), `../mystic/` (BBS_Records etc),
`../fpc264irc/bin/units/` (RTL PPUs).

## Architecture

```
mdm_config.pas (INI config)
  → m_FileIO, m_IniReader (MDL)

mdm_fossil.pas (FOSSIL driver)
  → fbSerial backend → m_serial.pas (MDL — direct OS I/O, 6 platforms)
  → fbInt14 backend → INT 14h (DOS only)

mystic_misdos/misdos.pas (WFC example)
  → m_serial.pas directly (SendAT, ModemInit, IsRinging, AnswerCall, HangUp)
  → mdm_config.pas (load modem.ini)
```

## Platforms

All platforms supported via MDL m_serial:
DOS (go32v2, i8086), Linux, FreeBSD, Darwin, Windows, OS/2.

## Credits

| Handle | Role |
|--------|------|
| wrench | Transport, FOSSIL, DVI/HDMI |
| sysop/0 | m_serial.pas, serial_irq.pas |
| kiddo | IRQ ring buffer |
| evga | SIO rebuild |

# serial — Cross-Platform Serial Port Unit + IRQ Ring Buffer

Pure Pascal serial port access. Same API on all platforms.
Part of the netmodem2irc / fpc264irc project.

## Files

| File | Author | Lines | What |
|---|---|---|---|
| `serial.pas` | sysop/0 | 203 | Real 16550 UART — Port[] I/O, all registers, baud/parity/FIFO/BREAK, DTR/RTS/CTS/DSR/DCD/RI, UART detection |
| `serial_irq.pas` | kiddo | 195 | ISR + 4KB ring buffer — interrupt-driven receive via 8259 PIC, SerEnableIRQ/SerDisableIRQ, auto-cleanup in finalization |
| `fossil.pas` | wrench | 394 | FOSSIL dispatch (FSC-0015 rev 5 + FSC-0072) — maps every FOSSIL function to serial.pas calls |
| `netfosdl.pas` | wrench | 254 | Main program — detect UART, hook INT 14h, go resident via Keep |

## Architecture

```
BBS ──INT 14h──> Int14Handler ──> FossilDispatch ──> serial.pas ──> real UART
                 (netfosdl.pas)    (fossil.pas)     (serial.pas)    (hardware)
                                                         ↑
                                                    serial_irq.pas
                                                    (ISR → ring buffer)
```

With IRQ enabled:
```
Modem ←→ UART 16550 ←→ IRQ 4 ←→ ISR ←→ Ring Buffer (4KB)
                                           ↓
                                    SerReadRing
                                           ↓
                                   FossilDispatch
                                           ↓
                                      netfosdl
```

## Platforms

| Platform | Backend | IRQ support |
|----------|---------|-------------|
| Linux/Unix | /dev/ttyS*, termios | n/a (kernel handles) |
| Windows | COM*, Win32 API | n/a (kernel handles) |
| DOS (go32v2) | Direct UART Port[] | ✅ serial_irq.pas |
| DOS (i8086) | Direct UART Port[] | ✅ serial_irq.pas |

## API — serial.pas

```pascal
uses serial;

H := SerOpen('COM1');
SerSetParams(H, 9600, 8, NoneParity, 1, []);
SerWrite(H, Buffer, Count);
N := SerRead(H, Buffer, Count);
if SerDataAvailable(H) then ...
if SerGetCTS(H) then ...
SerSetDTR(H, True);
SerSetRTS(H, True);
SerSetFIFO(H, True, 14);
WriteLn('UART: ', SerDetectUART(0));
SerClose(H);
```

## API — serial_irq.pas (IRQ-driven receive)

```pascal
uses serial, serial_irq;

H := SerOpen('COM1');
SerEnableIRQ(H);          { install ISR, unmask IRQ, start buffering }

{ now SerRead can be replaced with SerReadRing: }
N := SerReadRing(H, Buffer, Count);   { reads from ring, not hardware }
W := SerRingCount(H);                 { bytes in ring buffer }
O := SerRingOverruns(H);              { bytes lost to full ring }

SerDisableIRQ(H);          { restore old ISR, re-mask IRQ }
SerClose(H);
```

## Compile

```bash
# go32v2 (verification — FPC 3.2.2)
ppcross386 -Tgo32v2 -Mobjfpc -dGO32V2 serial.pas
ppcross386 -Tgo32v2 -Mobjfpc -dGO32V2 serial_irq.pas
ppcross386 -Tgo32v2 -Mobjfpc -dGO32V2 netfosdl.pas

# i8086 (shipping — fpc264irc)
ppcross8086 -Tmsdos serial.pas
ppcross8086 -Tmsdos serial_irq.pas
ppcross8086 -Tmsdos netfosdl.pas
```

## netfosdl — standalone FOSSIL driver

```
netfosdl              load on COM1 (default)
netfosdl /port:N      load on COM port N (1-4)
netfosdl /u           unload from memory
```

Drop-in replacement for X00, BNU, ADF, NetFoss.
FTSC FSC-0015 rev 5 + FSC-0072. Real UART, no network.
**Standalone — not part of netmodem. No NM_* units.**

## Credits

| Who | What |
|-----|------|
| sysop/0 | serial.pas — DOS UART implementation |
| kiddo | serial_irq.pas — ISR + ring buffer |
| wrench | fossil.pas, netfosdl.pas — FOSSIL dispatch + driver wiring |
| verta1878 | project lead, architecture |

## License

GPLv3 — Part of netmodem2irc (verta1878/netmodem2irc).

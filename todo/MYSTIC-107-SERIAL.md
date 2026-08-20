# Mystic BBS 1.07 — Serial/Modem Architecture

Extracted from MYSTIC.EXE + MYSTIC.OVR (v1.07.2, 2001-01-20)

## Serial Configuration (from MCFG.EXE)

```
A. Com Port     : [1-4]
B. Baud Rate    : [300-38400]
C. RTS/CTS Flow : [Yes/No]
D. XON/XOFF Flow: [Yes/No]
E. Modem Init   : [AT string]
F. Modem Hangup : [AT string]
G. Modem Offhook: [AT string]
H. Modem "OK"   : [result code]
I. Modem "RING" : [result code]
J. Modem "ATA"  : [answer command]
```

## Modem Flow

1. MYSTIC.EXE starts → init modem (`E. Modem Init`)
2. "Waiting for a caller" (WFC screen)
3. Detect RING → answer phone (`J. Modem "ATA"`)
4. Carrier detect → baud rate lock
5. User session starts
6. On disconnect: hangup (`F. Modem Hangup`)
7. Offhook briefly (`G. Modem Offhook`) to prevent immediate ring-back
8. Return to WFC

## Connection Types
- **Local Mode** — no serial, direct console access
- **Modem** — COM port with FOSSIL or direct UART
- **FOSSIL** — `Fossil driver not installed.` error if missing

## Overlay System (MYSTIC.OVR)
235KB overlay file — DOS code swapping for memory management.
MYSTIC.EXE is 123KB + 230KB OVR = 353KB total.
Uses Borland OVR format (SPAWNO v4.10 for shell-outs).

## Door Support (Serial Pass-Through)
- DOOR.SYS
- DORINFO1.DEF
- CHAIN.TXT

The door inherits the serial port handle/FOSSIL handle
so it can talk directly to the modem.

## Drop File Fields That Need Serial Info
- Baud rate (lock rate vs connect rate)
- COM port number
- FOSSIL flag
- Socket handle (for door32.sys, added in later versions)

## What ansiedit Needs From This

The 1.07 serial architecture shows that Mystic handles serial
at the application level, not the OS level:

1. **COM port init** — open COM, set baud, enable flow control
2. **Modem commands** — AT init, answer, hangup via string writes
3. **Carrier detect** — check DCD line to know if user is connected
4. **Data transfer** — raw byte read/write through serial port
5. **FOSSIL abstraction** — INT 14h API wraps all of the above

For ansiedit teleconference over serial:
- Use m_io_fossil.pas (TIOFossil) — same ReadBuf/WriteBuf as TCP
- ansiedit_transport.pas has ttTCP and ttSerial (FOSSIL/UART toggle)
- The PabloDraw protocol (m_pdnet) is transport-agnostic once
  we replace fpSocket/fpSend with TTransport calls

## Networking by Platform

| Platform | TCP | Serial |
|----------|-----|--------|
| Linux/Windows | FPC Sockets (native) | N/A |
| GO32V2 (32-bit DOS) | fpc264irc Sockets.pp | FOSSIL/UART |
| i8086 (16-bit DOS) | MSLAN + fpc264irc Sockets.pp | FOSSIL/UART (native) |

No Watt-32 — we use our own Sockets.pp from fpc264irc for all
TCP on all platforms. Plain DOS (i8086) needs MSLAN packet driver
helper for TCP. Serial works natively on all DOS targets.

## Key Difference: 1.07 vs 1.10+
- 1.07 uses direct UART or FOSSIL for modem connections
- 1.10+ added TCP/IP sockets (Telnet/SSH) alongside modem
- Both use the same I/O abstraction (TIOBase in MDL)

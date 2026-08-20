// Copyright (C) 2026 Kiddo — GPLv3 — Mystic BBS IRC Fork

# Mystic BBS DOS Multi-Node Setup with DESQview

## Overview

Running Mystic BBS on DOS with multiple nodes, TCP/IP internet
access, and dial-up modem support using the Quarterdeck DESQview
multitasker. DESQview was released freely by Quarterdeck/Symantec
and later IBM — it is freely distributable.

## Required Software

### DESQview Stack (DV.rar — freely distributable)

| Component | Version | Purpose |
|-----------|---------|---------|
| DESQview | 2.8 | DOS multitasker — runs multiple DOS apps in windows |
| DV/X | 2.10 | X Window System for DOS (optional, GUI apps) |
| QEMM | 97 | Memory manager — EMS/XMS/UMB, loads DOS high |
| TCP4DOS | — | TCP/IP stack for DOS (packet driver based) |
| Trumpet TCP | 1.6/1607 | Alternative TCP/IP stack (tcp16.exe, tcp1607.exe) |

### Mystic BBS Components

| Component | Binary | Purpose |
|-----------|--------|---------|
| MIS | mis | Internet server — Telnet, FTP, BINKP on Wattcp |
| Mystic | mystic | BBS node — one per caller |
| MPLC | mplc | MPL script compiler |
| MUTIL | mutil | Maintenance utilities |
| FIDOPOLL | fidopoll | FidoNet polling |

### Network

| Component | Purpose |
|-----------|---------|
| Packet driver | NE2000, 3C509, or other Ethernet card driver |
| Wattcp/WATT-32 | TCP/IP library for DJGPP (used by MIS) |
| FOSSIL driver | BNU, X00, or similar for modem COM ports |

## Architecture

```
 DESQview 2.8 (multitasker)
 ┌─────────────────────────────────────────────────┐
 │                                                 │
 │  Window 1: MIS (Internet Server)                │
 │    Wattcp TCP/IP stack                          │
 │    Listens: Telnet :23, FTP :21, BINKP :24554   │
 │    Spawns mystic nodes in new DV windows         │
 │                                                 │
 │  Window 2: Mystic Node 1 (telnet caller)        │
 │    mystic -n1 -TID<handle> -IP<addr>            │
 │                                                 │
 │  Window 3: Mystic Node 2 (telnet caller)        │
 │    mystic -n2 -TID<handle> -IP<addr>            │
 │                                                 │
 │  Window 4: Mystic Modem Node (dial-up)          │
 │    Front-end waits for ring/carrier              │
 │    mystic -n3 -COM1 -FOSSIL -B38400             │
 │                                                 │
 │  Window 5: MUTIL (scheduled maintenance)        │
 │    Echomail toss/scan, file imports              │
 │                                                 │
 └─────────────────────────────────────────────────┘
 QEMM 97 (memory manager — EMS/XMS/UMB)
 Packet Driver (NE2000/3C509/etc)
 FOSSIL Driver (BNU/X00 — for modem nodes)
```

## DESQview Window Configuration

### MIS Window (Internet Server)

```
DV Program Information:
  Program Name:     MIS Internet Server
  Program:          C:\MYSTIC\MIS.EXE
  Parameters:
  Directory:        C:\MYSTIC
  Memory (KB):      4096
  EMS Memory:       0
  XMS Memory:       0
  Writes text directly to screen: Y
  Virtualize screen: Y
  Uses its own colors: Y
  Close on exit: N
  Allow Close Window: N
```

### Mystic Node Window (Template)

Each node gets its own window. MIS spawns these automatically,
but you can also create them manually for testing:

```
DV Program Information:
  Program Name:     Mystic BBS Node
  Program:          C:\MYSTIC\MYSTIC.EXE
  Parameters:       -N1 -L
  Directory:        C:\MYSTIC
  Memory (KB):      2048
  EMS Memory:       0
  XMS Memory:       0
  Writes text directly to screen: Y
  Virtualize screen: Y
  Uses its own colors: Y
  Close on exit: Y
```

### Modem Front-End Window

For dial-up callers. The front-end watches for RING and
spawns mystic with FOSSIL flags:

```
DV Program Information:
  Program Name:     Modem Front-End
  Program:          C:\MYSTIC\MODEM.BAT
  Directory:        C:\MYSTIC
  Memory (KB):      1024
  Writes text directly to screen: Y
  Close on exit: N
```

MODEM.BAT:
```batch
@echo off
:LOOP
REM Wait for call using mystic_modem front-end or simple AT loop
C:\MYSTIC\MYSTIC.EXE -N3 -COM1 -FOSSIL -B38400
REM After caller hangs up, loop back and wait
GOTO LOOP
```

## CONFIG.SYS

```
DEVICE=C:\QEMM\QEMM386.SYS RAM FRAME=E000
DEVICE=C:\QEMM\LOADHI.SYS /R:1 C:\DV\QEMM\EMM386.EXE
DOS=HIGH,UMB
FILES=60
BUFFERS=30
LASTDRIVE=Z
DEVICE=C:\FOSSIL\BNU.SYS /L0:38400
```

## AUTOEXEC.BAT

```batch
@echo off
SET PATH=C:\DOS;C:\DV;C:\MYSTIC;C:\WATTCP
SET WATTCP.CFG=C:\WATTCP\WATTCP.CFG
SET MYSTIC=C:\MYSTIC

REM Load packet driver for your NIC
C:\DRIVERS\NE2000.COM 0x60 0x300 3

REM Load FOSSIL driver
C:\FOSSIL\BNU.COM /L0:38400

REM Start DESQview
C:\DV\DV.COM
```

## WATTCP.CFG (TCP/IP Configuration)

```
my_ip=192.168.1.100
netmask=255.255.255.0
gateway=192.168.1.1
nameserver=8.8.8.8
hostname=mysticbbs
domain=local
```

## Mystic Command Line Flags

| Flag | Purpose | Example |
|------|---------|---------|
| `-N<n>` | Node number | `-N1` |
| `-TID<h>` | Socket handle (from MIS) | `-TID1234` |
| `-IP<addr>` | Caller's IP address | `-IP192.168.1.50` |
| `-HOST<name>` | Caller's hostname | `-HOSTuser.isp.com` |
| `-B<baud>` | Baud rate | `-B38400` |
| `-COM<n>` | COM port for FOSSIL | `-COM1` |
| `-FOSSIL` | Use FOSSIL driver for I/O | |
| `-L` | Local mode (no remote I/O) | |
| `-CFG` | Configuration mode | |

### Telnet node (spawned by MIS):
```
mystic -N1 -TID5432 -IP192.168.1.50 -HOSTcaller.example.com
```

### Dial-up modem node (spawned by front-end):
```
mystic -N3 -COM1 -FOSSIL -B38400
```

### Local sysop mode:
```
mystic -L
```

## How FOSSIL I/O Works

When mystic runs with `-COM1 -FOSSIL`:

1. Creates `TIOFossil` instead of `TIOSocket` as `Session.Client`
2. `TIOFossil` extends `TIOBase` — same interface as TCP sockets
3. All BBS I/O (`WriteBuf`, `ReadBuf`, `DataWaiting`) goes through FOSSIL
4. On DOS: INT 14h calls to the FOSSIL driver (BNU, X00, etc.)
5. On Win32: Win32 COM port API
6. On Unix: /dev/ttyS* serial device

The rest of Mystic doesn't know or care if it's TCP or serial.

## The netmodem Bridge

The `mystic_modem/` directory contains an alternative front-end
that bridges TCP/IP telnet connections to the FOSSIL port. This
allows running Mystic in FOSSIL mode while accepting internet
callers — the bridge translates between TCP and serial.

```
Internet caller → Telnet → netmodem bridge → FOSSIL → Mystic
```

This is useful when you want Mystic running in FOSSIL mode
(for door game compatibility) but still accept internet callers.
The bridge handles telnet negotiation and feeds data to the
FOSSIL port as if it were a modem caller.

## Memory Requirements

With QEMM 97 loading DOS and drivers high:

| Component | Conventional | Notes |
|-----------|-------------|-------|
| DOS + drivers | ~20KB | QEMM loads most high |
| FOSSIL (BNU) | ~8KB | Loaded high via LOADHI |
| Packet driver | ~12KB | Loaded high |
| DESQview | ~40KB | Core multitasker |
| MIS node | ~512KB | Per DV window |
| Mystic node | ~512KB | Per DV window |

DJGPP (go32v2) executables use DPMI — QEMM provides the DPMI host.
Each DV window gets its own protected-mode address space.

## Networking Notes

### Packet Drivers
DESQview needs a packet driver for the NIC. Common ones:
- `NE2000.COM` — NE2000 compatible cards
- `3C509.COM` — 3Com Etherlink III
- `SLIPPER.COM` — SLIP over serial (for serial internet)
- `CSLIPPER.COM` — Compressed SLIP
- `EPPPD.EXE` — PPP over serial

### Wattcp vs Trumpet
- **Wattcp** — library linked into the application (MIS uses this)
- **Trumpet** — TSR TCP/IP stack, applications use INT calls
- Both work with packet drivers
- Wattcp is simpler for DJGPP programs

### DV/X 2.10
Optional X Window System for DOS. Not needed for BBS operation
but provides GUI tools (file manager, telnet client, etc.)
and can run X11 applications over the network.

## Files Reference

```
DV.rar contents:
  DV/DV28/          DESQview 2.8 install disks
  DV/DVX210/        DV/X 2.10 install (9 disks + addons)
  DV/qemm97.zip     QEMM 97 memory manager
  DV/TCP4DOS.ZIP    TCP/IP stack for DOS
  DV/tcp16.exe      Trumpet TCP 1.6
  DV/tcp1607.exe    Trumpet TCP 1.607
  DV/NOVELL/        Novell NetWare DOS client
  DV/potpouri/      600+ DOS networking utilities
  DV/DVX_stuff/     DV/X extras (xearth, etc.)
  DV/gnu4dvx*.zip   GNU tools for DV/X
  DV/referenc.zip   DV API reference (ASM, C, Pascal!)
  DV/technote.zip   Technical notes
  DV/docs.zip       Documentation
```

## DV API for Mystic

The DV API reference (`referenc.zip`) includes Pascal bindings
(`DISKLIB.PAS`). Key functions for BBS multitasking:

- `dv_get_version` — detect DV presence
- `dv_begin_critical` / `dv_end_critical` — prevent task switching
- `dv_pause` — yield timeslice to other tasks
- `dv_ostack` — switch to DV's stack (needed for API calls)

Mystic's DOS idle loop should call `dv_pause` to yield CPU
to other DV windows. Without this, one node hogs the CPU.

## Legal

DESQview was released freely by Quarterdeck (later acquired
by Symantec). IBM distributed DESQview with OS/2 compatibility
tools. All components in DV.rar are freely distributable
abandonware. QEMM 97 was the last commercial release before
Quarterdeck's closure.

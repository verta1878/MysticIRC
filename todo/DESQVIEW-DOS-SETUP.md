# DESQview DOS Multitasking Setup for Mystic BBS

## Archive Contents (DV.rar — 275MB)

| Component | Version | Purpose |
|-----------|---------|---------|
| DESQview | 2.8 | DOS multitasker — each node gets its own window |
| DV/X | 2.10 | X Window System for DOS (graphical DV) |
| QEMM | 97 | Memory manager — EMS/XMS/UMB for max conventional |
| TCP4DOS | — | TCP/IP stack for DOS (packet driver based) |
| tcp16/tcp1607 | — | Trumpet TCP (alternative Wattcp-compatible stack) |
| Novell Client | — | IPX/SPX networking |
| GNU tools | — | DOS GNU utilities |

## Multi-Node Architecture

```
DESQview 2.8 (task switcher)
├── Window 1: MIS (Wattcp TCP/IP stack)
│   ├── Telnet server → spawns mystic -TID<handle> -N<node>
│   ├── FTP server
│   ├── BINKP server
│   └── HTTP server
├── Window 2: Mystic Node 1 (spawned by MIS)
├── Window 3: Mystic Node 2 (spawned by MIS)
├── Window 4: Mystic Node 3 (spawned by MIS)
└── Window 5: Modem Front-End (mystic_modem/)
    └── Watches COM port → spawns mystic -COM1 -FOSSIL -B38400
```

## Internet Nodes (TCP/IP via MIS)

MIS runs on the Wattcp stack using a packet driver. Each telnet
connection spawns a mystic.exe instance in its own DV window:

```
mis.exe
  → mystic.exe -n1 -TID<socket_handle> -IP<addr> -HOST<name>
  → mystic.exe -n2 -TID<socket_handle> -IP<addr> -HOST<name>
  → mystic.exe -n3 -TID<socket_handle> -IP<addr> -HOST<name>
```

## Dial-Up Node (FOSSIL via COM port)

The modem front-end (mystic_modem/ or a batch file) watches the
COM port for incoming calls. When carrier is detected, it spawns
mystic directly — MIS is NOT involved:

```
mystic.exe -COM1 -FOSSIL -B38400 -N4
```

This creates a TIOFossil (extends TIOBase) instead of TIOSocket.
The rest of the BBS code works unchanged — it talks through
TIOBase methods (WriteBuf, ReadBuf, DataWaiting).

### FOSSIL Driver

The FOSSIL driver provides INT 14h serial port access:
- **m_fossil.pas** — Raw INT 14h calls (DOS only, 92 lines)
- **m_serial.pas** — Cross-platform serial (Win32 COM / Unix tty)
- **m_fossil_io.pas** — Abstraction layer with both backends
- **m_io_fossil.pas** — TIOBase adapter for mystic.exe

### Command Line Flags

```
mystic -COM1 -FOSSIL -B38400 -N4    DOS FOSSIL on COM1
mystic -COM2 -FOSSIL -B115200 -N5   DOS FOSSIL on COM2
mystic -COM1 -B9600 -N4             Serial without FOSSIL flag
mystic -L                           Local mode (no remote I/O)
```

## The Netmodem Bridge (mystic_modem/)

The netmodem bridge has its own front-end with:
- Modem initialization and answer strings
- Carrier detect monitoring
- WFC (Waiting For Call) screen
- FOSSIL driver integration
- Configuration via modemcfg.pas

Files:
```
mystic_modem/
  netmodem.pas          Main program
  netmodem_fossil.pas   FOSSIL test program
  mdm_config.pas        Configuration
  mdm_fossil.pas        FOSSIL driver wrapper
  mdm_serial.pas        Serial port wrapper
  mdm_modem.pas         Modem AT command handler
  mdm_wfc.pas           Waiting For Call screen
  mdm_miswfc.pas        MIS-style WFC
  modemcfg.pas          Config editor
  mystfoss.pas          Standalone FOSSIL reference
  fossil_dos.pas        DOS-specific FOSSIL
  wfcdemo.pas           WFC screen demo
  squish_example.pas    Squish msgbase example
```

## QEMM 97 Memory Setup

QEMM provides maximum conventional memory for DOS programs:

```
CONFIG.SYS:
  DEVICE=C:\QEMM\QEMM386.SYS RAM ST:M
  DEVICE=C:\QEMM\LOADHI.SYS /R:1 C:\DOS\SETVER.EXE
  DOS=HIGH,UMB

AUTOEXEC.BAT:
  C:\QEMM\LOADHI /R:1 C:\DOS\SHARE.EXE
  C:\QEMM\LOADHI /R:1 C:\DOS\MSCDEX.EXE
```

Target: 620KB+ free conventional memory per DV window.
DJGPP (go32v2) programs use DPMI for extended memory.

## TCP/IP Stack Options

### Option 1: TCP4DOS (packet driver based)
```
SET MTCP_CONFIG=C:\MTCP\TCP.CFG
PACKET.COM 0x60           ; load packet driver
```

### Option 2: Trumpet TCP
```
SET TCPDRV=C:\TRUMPET\TCP.CFG
WINPKT 0x60               ; Trumpet packet driver shim
```

### Option 3: Wattcp (built into DJGPP programs)
MIS and mystic for DOS use Wattcp32 compiled into the go32v2
executable. Needs a packet driver loaded, no separate TCP stack.

```
SET WATTCP.CFG=C:\MYSTIC\WATTCP.CFG
```

## DESQview Window Configuration

Each mystic node needs a DV .DVP (DESQview Program) file:

```
Program: C:\MYSTIC\MYSTIC.EXE
Parameters: -N1 -COM1 -FOSSIL -B38400
Directory: C:\MYSTIC
Memory: 4096KB (DPMI)
Window: Standard
Close on exit: Yes
```

For MIS (TCP/IP server):
```
Program: C:\MYSTIC\MIS.EXE
Parameters:
Directory: C:\MYSTIC
Memory: 4096KB (DPMI)
Window: Standard
Close on exit: No
```

## DV SDK

The DV SDK allows building DV-aware applications that:
- Properly yield CPU time to other tasks
- Use DV windowing API
- Share memory between windows
- Handle task switching correctly

Mystic's DOS build (go32v2/DJGPP) works in DV without
modification — DJGPP yields via INT 2Fh automatically.

## Build Requirements

- FPC 2.6.4irc r3.1+ (go32v2 cross-compiler)
- DJGPP runtime (go32v2 DPMI extender)
- FOSSIL driver (BNU, X00, or similar) for serial
- Packet driver for TCP/IP (NE2000, 3C509, etc.)
- DESQview 2.8 + QEMM for multitasking
- 16MB+ RAM recommended for multi-node

## File Locations

```
C:\MYSTIC\           BBS root
C:\MYSTIC\DATA\      Data files
C:\MYSTIC\TEXT\      ANSI/text files
C:\MYSTIC\MENUS\     Menu files
C:\MYSTIC\SCRIPTS\   MPL scripts
C:\MYSTIC\MSGS\      Message bases
C:\MYSTIC\ECHOMAIL\  FidoNet echomail
C:\MYSTIC\MIS.EXE    Internet server
C:\MYSTIC\MYSTIC.EXE BBS executable
C:\MYSTIC\MPLC.EXE   MPL compiler
C:\MYSTIC\MIDE.EXE   MPL IDE
C:\MYSTIC\MUTIL.EXE  Maintenance utility
```

## Note

This archive (DV.rar) is distributed separately from the
Mystic BBS source code. It is not included in the repository.

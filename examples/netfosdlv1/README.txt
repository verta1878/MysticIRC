netfosdl — DOS FOSSIL driver — complete source
================================================
GPLv3 — Antonio Rico (verta1878) / FPC264IRC Contributors, 2025-2026.
FOSSIL work: wrench.

WHAT THIS IS
  A standalone real-mode DOS FOSSIL driver (TSR). Hooks INT 14h and
  presents an FSC-0015 rev-5 FOSSIL to any BBS/door/mailer — Mystic,
  PCBoard, etc. — talking to a real 8250/16550 UART. 18 FOSSIL functions
  with real behavior + interrupt-driven 4KB RX ring buffer + CTS/RTS flow.

SOURCE UNITS (build these together)
  netfosdl.pas    TSR main: cmdline parse, INT 14h hook, go-resident
  fossil.pas      FOSSIL dispatch (all INT 14h function logic)
  serial.pas      UART layer (8250/16550 port I/O, polled)
  serial_irq.pas  interrupt-driven RX: ISR + 4KB ring buffer
  fostest.pas / fosfull.pas / fostest2.pas   test programs

PREBUILT
  NETFOSDL.EXE    the driver, ready to run
  FOSTEST/FOSFULL/FOSTEST2.EXE   test programs

BUILD
  See BUILD.txt. Short version — real-mode compiler required
  (fpc264irc ppcross8086 = FPC 3.2.2 i8086, or Turbo Pascal 7):
    ppcross8086 -Tmsdos -Wmhuge -Mobjfpc -CX -XX -Ch4096 \
      -Fu<fpc264irc>/bin/units/i8086-msdos -Fu. -oNETFOSDL.EXE netfosdl.pas

USAGE (with Mystic / PCBoard)
  Load BEFORE the BBS, in AUTOEXEC.BAT or the node start batch:
    NETFOSDL /port:1 /baud:38400
  Then point the BBS at the FOSSIL on that COM port. Unload after the BBS
  exits with:  NETFOSDL /u
  Switches:  /port:N (1-4)  /baud:RATE  /irq:N  /u (unload)

NOTE
  Verified in DOSBox-X (signature AX=1954h, all functions clean). Real
  UART + live modem/telnet-bridge on hardware is the final on-metal test.

# mystic_modem — Modem/FOSSIL Driver

Serial port and FOSSIL driver support for Mystic BBS.

## Files
- serial.pas — UART serial port driver
- serial_irq.pas — IRQ-based serial I/O
- fossil.pas — FOSSIL driver interface
- netfosdl.pas — Network FOSSIL driver (TCP↔FOSSIL bridge)
- netmodem2irc.pas — Modem emulator (Hayes AT commands over TCP)

## Platforms
- DOS: Real FOSSIL/UART access
- Linux/Windows: netfosdl provides TCP-based FOSSIL emulation

## Status
Working. serial.pas v1.0/v1.1 completed, FOSSIL driver tested.

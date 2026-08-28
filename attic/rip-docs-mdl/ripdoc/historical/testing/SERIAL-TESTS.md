# DOS Serial / FOSSIL Testing

## Status: NOT YET TESTED

## Plan

### What to test
1. serial.pas — UART driver (direct port I/O)
2. serial_irq.pas — IRQ-based async serial
3. fossil.pas — FOSSIL driver API
4. netfosdl.pas — Network FOSSIL (TCP↔serial bridge)

### DOSBox Setup
```
[serial]
serial1=nullmodem server:localhost port:5000
serial2=nullmodem port:5001
```

### Test 1: FOSSIL loopback
- Run netfosdl on one side, terminal emulator on other
- Send characters back and forth
- Verify: no data loss, correct baud rate reporting

### Test 2: Mystic 1.07 connection
- Install Mystic 1.07 in DOSBox
- Configure for COM1 FOSSIL
- Connect with mterm or external terminal
- Verify: login works, ANSI displays, file transfer works

### Test 3: Serial IRQ timing
- Test at different baud rates (2400, 9600, 19200, 38400, 57600, 115200)
- Verify: FIFO buffer handling, no overruns
- Check: IRQ handler installs/uninstalls cleanly

### Dependencies
- DOSBox-X (better serial emulation than standard DOSBox)
- fpc264irc DOS target (DPMI)
- CWSDPMI.EXE (DOS extender)

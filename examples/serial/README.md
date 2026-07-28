# serial — Cross-Platform Serial Port Unit

Pure Pascal serial port access. Same API on all platforms.

## Platforms

| Platform | Backend | Notes |
|----------|---------|-------|
| Linux/Unix | /dev/ttyS*, termios | FPC standard |
| Windows | COM*, Win32 API | FPC standard |
| DOS (go32v2) | Direct UART 8250/16550 | Our implementation |
| DOS (i8086) | Direct UART 8250/16550 | Our implementation |

## API

```pascal
uses serial;

var H: TSerialHandle;
begin
  H := SerOpen('COM1');               // Open port
  SerSetParams(H, 9600, 8, NoneParity, 1, []);  // 9600 8N1
  SerWrite(H, Buffer, Count);        // Send data
  N := SerRead(H, Buffer, Count);    // Receive data
  if SerDataAvailable(H) then ...    // Check for data
  if SerGetCTS(H) then ...           // Check modem signals
  SerSetDTR(H, True);                // Control DTR
  SerSetRTS(H, True);                // Control RTS
  SerClose(H);                       // Close port
end.
```

## UART Detection

```pascal
WriteLn('COM1: ', SerDetectUART(0));  // '8250', '16450', '16550A', '16750'
```

## FIFO Control (16550+)

```pascal
SerSetFIFO(H, True, 14);  // Enable FIFO, 14-byte trigger
```

## For netmodem2irc

```
Modem ←→ COM1 (serial unit) ←→ tork ←→ TCP (sockets unit) ←→ IRC
```

## Credits

| Who | What |
|-----|------|
| sysop/0 | DOS UART implementation |
| wrench | tork netmodem2irc integration |

## License

GPLv3 — Part of fpc264irc.

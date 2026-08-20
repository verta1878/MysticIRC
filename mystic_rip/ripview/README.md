# RIPView v1.0.0

RIPscrip v1.54 file viewer. 42/42 commands implemented.
Pixel-perfect rendering. Native FPC Pascal.

## Build

    # CLI mode (default)
    fpc -Mdelphi source/ripview.pas

    # Free Vision TUI mode
    fpc -Mdelphi -dFREEVISION -Fu<fv-src-path> source/ripview.pas -oripviewgui

Both compile from the same source file (1602 lines).

## Usage — CLI Mode

    ripview file.rip                         Render to file.bmp
    ripview file.rip output.bmp              Custom output name
    ripview -d file.rip                      Debug: print every command
    ripview -b 2400 file.rip                 Baud emulation at 2400 bps
    ripview -d -b 9600 file.rip out.bmp      Debug + baud + custom output
    ripview /path/to/rips/                   Interactive file picker
    ripview -l /path/to/rips/                List .rip files in directory

### Options

    -d, --debug        Print each RIP command as it executes
    -b, --baud=RATE    Simulate modem speed (bytes/sec = baud/10, 8N1)
    -l, --list         List .rip files without rendering

### Baud Rates

    300  1200  2400  4800  9600  14400  19200  28800  38400  57600  115200
    0 = max speed (default)

## Usage — Free Vision TUI Mode

    ripviewgui                     Start with menus
    ripviewgui file.rip            Start with file preloaded

### Keys

    F3       Open .rip file (file dialog)
    F9       Render to BMP
    F5       Toggle debug output
    Alt-X    Quit

### Menus

    File:  Open / Render / Stop / Quit
    Baud:  Full Speed, 300-115200 bps
    Debug: Toggle / Clear Log

## RIPscrip Commands — 42/42 Implemented

### Drawing (16)
    !|X  Pixel             !|L  Line              !|R  Rectangle
    !|B  Bar (filled)      !|C  Circle            !|O  Oval (ellipse)
    !|o  Filled Oval       !|A  Arc               !|V  Oval Arc
    !|I  Pie Slice         !|i  Oval Pie Slice    !|Z  Bezier
    !|P  Polygon           !|p  Filled Polygon    !|l  Polyline
    !|F  Flood Fill

### Style (5)
    !|c  Color             !|S  Fill Style        !|s  Fill Pattern
    !|=  Line Style        !|W  Write Mode

### Text (5)
    !|@  Text XY           !|T  Text at cursor    !|Y  Font Style
    !|m  Move cursor       !|H  Home (0,0)

### Window (5)
    !|v  Viewport          !|w  Text Window       !|e  Erase View
    !|>  Erase EOL         !|*  Erase Window

### Image (3) — stubs, skip args correctly
    !|1C GetImage          !|1P PutImage           !|1I Load Icon

### Mouse/Button (4) — stubs, skip args correctly
    !|1M Mouse region      !|1K Kill Mouse Fields
    !|1U Button            !|1B Button Style

### Palette (2)
    !|Q  Set Palette (16)  !|a  Set One Palette

### Control (2)
    !|#  Reset Windows     !|#  No More (stop)

## Rendering Engine

    Canvas:     640x1280 pixels (80 rows x 16px VGA)
    Font:       VGA 8x16 CP437 ROM (MSB-first, rip_font8x16.inc)
    Palette:    CGA/ANSI order (1=red 4=blue, matches chg2rip output)
    Output:     24-bit BMP
    Pixel match: 100% against ans2png reference

### Drawing Primitives (ported from RIPtermJS BGI.js)
    Bresenham line, circle, ellipse (outline + filled)
    Trig-based arc with degree-by-degree angle clipping
    Pie slice: arc + wedge lines + floodfill interior
    Cubic Bezier (Bernstein polynomial, adaptive segments)
    Scanline polygon fill (alienryderflex algorithm)
    Stack-based scanline flood fill

## Source Files

    source/
      ripview.pas          Main — engine + CLI + FV GUI (1602 lines)
      rip_font8x8.inc      8x8 bitmap font (CP437, 2048 bytes)
      rip_font8x14.inc     8x14 EGA font (CP437, 3584 bytes)
      rip_font8x16.inc     8x16 VGA font (CP437, 4096 bytes) — active
    dos/ripview.exe        DOS binary (go32v2)
    linux/ripview          Linux binary (x86_64)
    win32/ripview.exe      Win32 binary

## Platforms

    Linux x86_64    fpc -Mdelphi ripview.pas
    Win32           fpc -Mdelphi -Twin32 ripview.pas
    DOS (go32v2)    fpc -Mdelphi -Tgo32v2 ripview.pas
    OS/2 (EMX)      fpc264irc -Mdelphi -Temx ripview.pas

## References

    RIPtermJS        github.com/cgorringe/RIPtermJS (BGI.js, ripterm.js)
    RIPscrip v1.54   mystic_rip/v1/ripscript.txt
    chg2rip v2.3     mystic_rip/chg2rip.pas (ANSI-to-RIP converter)
    ans2png          mystic_rip/ans2png.pas (reference BMP renderer)

## License

    GPLv3 — Copyright (C) 2026
    The Crew: verta1878, sysop/0, evga, kiddo, wrench
    Mystic BBS IRC Fork — Ecstasy BBS FTN 1:152/158

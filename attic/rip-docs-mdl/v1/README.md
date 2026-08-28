# RIPscrip v1.54 Server-Side Rendering Engine

Standalone Pascal unit for rendering RIPscrip v1.54 graphics protocol
to a 640x350 EGA pixel buffer. No dependencies — compiles with just
`ppc386 -Mdelphi ripscript.pas`.

## Features

- **51/51 RIPscrip v1.54 commands** implemented (36 Level 0 + 15 Level 1)
- **640x350 EGA** 16-color rendering with full EGA palette
- **Drawing primitives**: pixel, line, rectangle, bar, circle, oval, arc,
  pie slice, bezier, polygon, flood fill
- **CHR vector fonts**: loads all 10 Borland BGI .CHR files
- **5 system font modes**: 80x43 (8x8), 80x25 (8x14), 40x25 (16x14),
  91x43 (7x8), 91x25 (7x14)
- **Icon formats**: ICN, MSK, HIC (BGI GetImage format with transparency)
- **Image loading**: PCX (16-color EGA RLE), BMP (4-bit and 24-bit)
- **Button system**: 3D beveled buttons, radio groups, checkboxes,
  hotkeys, tab navigation, underline hotkey character
- **Screen save/restore**: 10 pixel buffer slots + text window + mouse
  fields + clipboard
- **Text variables**: 43 built-in variables ($CURX$, $DATE$, $TWWIN$,
  $HKEYON$, etc) with $VARNAME$ expansion in all text output
- **BMP export**: 24-bit BMP output via EGA_RGB palette

## Files

| File | Lines | Description |
|------|-------|-------------|
| ripscript.pas | 4041 | Engine (standalone unit) |
| rip_font8x8.inc | 256 | CP437 8x8 VGA ROM font |
| rip_font8x14.inc | 256 | CP437 8x14 VGA font |
| ripscript.doc | 1272+ | API reference (text) |
| ripscript.htm | 1217+ | API reference (HTML) |
| PHASES.md | — | Implementation roadmap |
| features.txt | — | Feature summary |
| tests/test_v1.pas | 64 | Functional tests |
| tests/test_v1_stress.pas | 33 | Stress tests |

## Building

```
ppc386 -Mdelphi ripscript.pas
```

Requires FPC 2.6.4irc or compatible. Must use `{$H-}` (ShortStrings)
due to a known FPC 2.6.4irc bug with AnsiString stack overflow in
-Mdelphi mode. See `docs/bugs/fpc264irc-ansistring-stack-overflow.md`.

## Usage

```pascal
Uses ripscript;
Var RIP : TRIPEngine;
Begin
  RIP := TRIPEngine.Create;
  RIP.ProcessLine('!|e');           // clear screen
  RIP.ProcessLine('!|c0F');         // set color 15
  RIP.ProcessLine('!|R0A0A5HO9M'); // draw rectangle
  RIP.ProcessLine('!|@1414Hello');  // text at (20,20)
  RIP.SaveBMP('output.bmp');
  RIP.Free;
End.
```

## License

GNU General Public License v3. Part of the Mystic BBS IRC Fork.

# FPC Codecs — Pure Pascal Image & Audio Decoders

GPLv3 | Part of FPC 2.6.4irc | {$H-} compatible

## Image Decoders (raw file I/O, no Classes/TStream)

| Unit | Format | Output |
|------|--------|--------|
| jpegdecraw.pas | JPEG baseline DCT | RGB pixels (via pasjpeg) |
| gifdecraw.pas | GIF87a/89a + animation | Palette + RGB pixels |
| pngdecraw.pas | PNG 8/16-bit, palette/RGB/RGBA | RGB pixels (via paszlib) |

## Audio Units

| Unit | What |
|------|------|
| pcmdecraw.pas | WAV/RIFF PCM decoder |
| pcmmix.pas | 16-stream audio mixer with saturation clipping |
| mididec.pas | Standard MIDI file parser (Format 0+1) |
| dosplay.pas | Sound Blaster IRQ-driven DMA + streaming double-buffer |
| wavplay.pas | Cross-platform WAV player (Win32/Linux/Darwin/DOS/OS2) |

## Math

| Unit | What |
|------|------|
| fixedmath.pas | 16.16 fixed-point math, sin/cos tables, no FPU needed |

## Usage

```pascal
uses JPEGDecRaw, GIFDecRaw, PNGDecRaw, PCMDecRaw, WavPlay;
```

Compile with: `ppc386 -Fu<path-to-fpc-codecs> yourprogram.pas`

## Dependencies

- jpegdecraw.pas requires pasjpeg package (included in FPC)
- pngdecraw.pas requires paszlib package (included in FPC)
- All others: zero dependencies

## Platforms

All units compile on: x86_64-linux, i386-win32, i386-go32v2,
i386-darwin, i386-freebsd, i386-os2

## License

GNU General Public License v3.0 — see file headers

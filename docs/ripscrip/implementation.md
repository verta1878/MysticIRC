# Implementation Notes

Practical guidance for implementations (renderers, terminals, libraries) built from the specifications in this repository. These are **implementation details, not language details** - the RIPscrip language docs under `version/` intentionally do not prescribe them.

## Canvas sizes

For content creators, limit the virtual canvas to the era-appropriate resolutions:

| Version | Virtual canvas | Notes |
| --- | --- | --- |
| 1.5x | **640×350** (fixed) | EGA, 16 colors from the EGA palette. The language hardwires this geometry. |
| 2.x / 3.x | **640×480**, **800×600**, or **1024×768** | Matches the resolutions RIPtel itself supported - its MicroANSI font file (`RIPscrip.maf`) carries per-resolution records for exactly these three modes. For **1280x960** the 640x480 size should be used, and rendered at 2x sclae to match the higher physical resolution. |

The 2.x/3.x wire protocol is resolution-independent (world coordinate frames, `RIP_SET_WORLD_FRAME`); the canvas limit applies to the _device_ side an implementation renders into, not to world coordinates. World frames map onto the chosen canvas - e.g. the RIPtel demos' standard **1280×960** world frame is itself 4:3. RIPtel's default world view is **640×350** for 1.x compatibility, handled like any other world resolution: scaled to the display, not run as a native video mode (unlike RIPterm 2.0, which still offered EGA 640×350 as an actual mode).

## Aspect ratio

- Because era displays were mostly a **4:3** ratio, as well as the supported 2.x display options, it's best to have the viewport in your application fixed to a **4:3** aspect ratio.
- **1.5x** used non-square pixels with a resolution of 640x350 scaled to a 4:3 physical display.
- **2.x / 3.x:** fix the displayed aspect ratio to **4:3**. All three ANSI font canvas sizes are 4:3 with square pixels; when scaling to a modern display, preserve 4:3 rather than stretching (letterbox/pillarbox as needed).

Wide-screen support is out of scope for now.

## Rendering

- **1.5x** scaling - For "classic" preservation of rendering, it's suggested to render each pixel as a scaled 3px wide and 4px tall, which will correct for the aspect ratio. You can then apply a mild blur/soften filter before bilinear scaling to the native viewport.
- You may want to apply HQX for XBR filtering for display enhancement before scaling to fit the actual render viewport. This can be used with either default (640x350) with an aspect correction or to higher virtual canvas sizes.
- Ideally, you would want to use a hardware accelerated shader in your rendering engine or WebGL based on your implementation. Note: too high a setting can affect render performance, but realistically this type of technology is not high performance gaming. So should be relatively okay.

## Case Insensitiviy

The original RIPterm/RIPtel were built against DOS and Windows, and in both cases, are effectively case-insensitive by nature. Implementers may want to either transform/store all asset files as lowercase and use regardless of the case of the request for an icon or audio file, or otherwise pre-load and track the asset directories to handle/translate case-insensitive access.

## Future directions (version/next)

Forward-looking suggestions for implementations - modern asset formats, internal storage strategies, and text handling - are collected in [next/README.md](next/README.md) as candidates for an unofficial 3.5x/4.x enhancement to the specification. Highlights relevant to implementers today:

- **Asset substitution / hierarchical lookup** - when a script requests an icon (`.ICN`/`.BMP`) or audio (`.WAV`) file, an implementation may transparently satisfy it from a modern equivalent (`.PNG`, `.MP2`/`.MP3`, etc.) of the same base name, searching supported extensions in a defined preference order. This composes with the case-insensitive lookup above.
- **Internal storage** - converting legacy assets to compact modern formats on load/import (palette-preserving `.PNG` for icons, compressed audio for `.WAV`) can dramatically reduce storage while remaining invisible to scripts.
- **Fonts and UTF-8** - proposals for CP437 ↔ UTF-8 text-mode switching and for supporting common font formats (`.TTF`/`.OTF`/`.WOFF`/`.WOFF2`) with scaled, anti-aliased cell rendering.

These are suggestions, not part of any historical specification - see [next/README.md](next/README.md) for the details and status.

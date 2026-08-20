# Glossary (stub)

Canonical terminology for use across all documentation, so the same concept always carries the same name. **Canonical terms are the specifications' own (spec-first)**; commonly used modern or informal names are listed as aliases on each entry. Version notes flag where a concept's name or meaning shifted between generations. This is a seed stub - entries grow during the restructure migration; final home is `version/glossary.md`.

## Display model

- **Graphics window** - the on-screen region where RIPscrip drawing appears (1.54's term for the drawing surface as displayed). _Aliases: graphics view._ _Versions: 1.54 core term; superseded by the port/viewport model in 2.0._
- **Text window** - the virtual TTY region that displays all non-RIPscrip (ASCII/ANSI) data; may be hidden. CP437 text, rendered from the client's own fonts. _Aliases: terminal view, ANSI area._ _Versions: all; 2.0+ allows up to 36 defined text windows, one active._
- **World coordinates** - the logical, device-independent coordinate space drawing commands address in 2.0+; mapped to the screen through a viewport. _Aliases: virtual canvas, world stage, logical space._ _Versions: introduced 2.0; absent in 1.54 (which draws directly in the fixed 640×350 EGA space)._
- **Drawing port** - the 2.0+ object bundling a world-coordinate space, a viewport onto it, and drawing state; multiple ports may exist, one active. _Aliases: port._ _Versions: 2.0+._
- **Viewport** - the rectangular window mapping a region of world coordinates onto a region of the physical display; drawing is clipped to it. In 1.54, the viewport is simply the clipped drawing region of the graphics window. _Aliases: view, canvas region (as defined); distinguish from the physically rendered screen area._ _Versions: all, with the 2.0 world→viewport mapping added._
- **Screen** - the physical display surface the client renders onto (a fixed video mode historically; a window/canvas in modern implementations). _Aliases: physical render surface, output canvas._
- **Image area** - the sub-region of the viewport that scalable images (JPEG) render into, set by RIP_IMAGE_STYLE. _Versions: 2.0+._

## Protocol & syntax

- **Command level** - the digit(s) after `|` selecting the command namespace: level 0 (graphics primitives), level 1 (UI objects/media), levels 2-9 (extended/system). _Versions: all; higher levels populate over time._
- **MegaNum** - RIPscrip's radix-36 ("Hexa-Tri-Decimal") fixed-width positional number, digit alphabet `0`-`9` then `A`-`Z`. Not the RFC 4648 "Base32" encoding - MegaNum is a plain positional numeral in RIPscrip's own alphabet (it happens to match the common base-36 alphanumeric convention). _Versions: the sole numbering in 1.54; the default Base Math in 2.0+._
- **UltraNum** - RIPscrip's radix-64 ("Quadra-Hexa-Decimal") fixed-width positional number, digit alphabet `0`-`9`, `A`-`Z`, `a`-`z`, `#`, `&` - RIPscrip's own digit order and values, **not** the RFC 4648 "Base64" encoding. Used by specific commands regardless of the Base Math setting (e.g. four-digit direct-RGB color values, drawing-palette RGB parameters); the spec advises against UltraNums beyond 5 digits (32-bit limits). _Versions: 2.0+._
- **Base Math** - the 2.0+ global setting selecting which number base (MegaNum or UltraNum) parameters use, set by the header command; commands that mandate a specific base are documented exceptions. _Versions: 2.0+._
- **Auto-sense** - the `ESC[!` query and `RIPSCRIPxxyyvs` response by which a host detects a RIP-capable terminal. _Aliases: auto-detection handshake._
- **Host command** - text the terminal sends back to the host when the user interacts (buttons, mouse fields, templates), possibly containing text-variable substitutions.
- **Text variable** - a named value (`$NAME$`) the terminal substitutes into host commands or stores; may be session-local or persistent. _See: persistent variable store._
- **Persistent variable store** - the client-side key/value store (name ≤ 20 chars → value ≤ 255 chars) backing `$+VAR$`/RIP_DEFINE flag `001`; storage mechanism is implementation-defined.

## Objects & media

- **Icon** - a named raster image stamped onto the drawing surface or used by buttons; `.ICN` (1.54) / `.BMP` (2.0+) on disk. _Versions: format changed 1.54→2.0; concept unchanged._
- **Hot icon** - the pressed/highlighted state image of an icon button; `.HIC` (1.54) / `.BMH` (2.0+).
- **Icon mask** - the AND-stamp companion raster controlling transparency; `.MSK` (1.54) / `.BMM` (2.0+, never shipped).
- **Clipboard** - the terminal-side image buffer captured from the screen (scissors/copy commands) and stamped back or saved as an icon.
- **Mouse field** - a host-defined clickable rectangular region that emits a host command. _Versions: 1.54+._
- **Button** - a styled interactive control (plain, icon, or clipboard faces) with optional hot-icon pressed state.
- **Write mode** - the raster combination rule for drawing operations (copy/XOR, plus the put-mode family for images).

## Client storage

- **Connection directory** - the per-host asset directory associated with a dialing-directory entry or bookmark; host-delivered files (icons, scripts, media) download here when one is configured, and asset lookups check it **before** the default icon directory. Auto-created on first use. _Aliases: system directory (RIPterm 2.30's manual-dial prompt), host icon directory, DIR field (1.54)._
- **Default icon directory** - the shared fallback asset directory (`ICONS\` historically); from 2.0 it houses all host-deliverable media (`.JPG`, `.WAV`, `.RIP`) alongside icons - there was never a separate audio directory.
- **File override** - the connection-directory-first lookup rule: same-named assets from different hosts resolve to the connected host's copy rather than colliding in the shared directory (the manuals' own term).

## Terminal baseline

- **CP437** - the IBM PC/DOS code page; the character set of the text window and all `.rip`/`.ans` era content.
- **Doorway mode** - the raw-scancode keyboard/printer passthrough mode (Marshall Dudley's DOORWAY interface) supported by RIPterm/RIPtel.
- **VT-102 mode** - the DEC-flavored modifier on the terminal's ANSI handling, with its own keyboard mapping.

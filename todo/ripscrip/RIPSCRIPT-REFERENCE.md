# RIPscrip v1.54 Reference — Mystic BBS

## What RIPscrip is

RIPscrip (Remote Imaging Protocol) is a graphical BBS protocol from
TeleGrafix Communications (1992-1993). It sends vector graphics and
clickable mouse buttons over a standard modem/telnet connection.
Commands are embedded in the byte stream prefixed with `!|`.

The native resolution is 640x350x16 (EGA mode). All coordinates use
base-36 "mega-numbers" (2 digits each, 0-9 + A-Z = 0-1295).

## Terminal modes in Mystic

| Value | Constant | Description |
|-------|----------|-------------|
| 0 | TERM_ASCII | Plain text, no escape sequences |
| 1 | TERM_ANSI | ANSI/VT-100 color and cursor |
| 2 | TERM_RIP | RIPscrip v1.54 graphical terminal |

RIP is a superset of ANSI — a RIP terminal understands ANSI codes too.
Code uses `>= TERM_ANSI` checks instead of `= 1`.

## Auto-detection

At login, Mystic sends `!|1Q00000000` and checks for `RIPSCRIP` in the
response. If detected, RIP mode activates. Otherwise falls back to ANSI.

## Configuration

**System Config** (mystic -cfg > Configuration):

    Terminal: Ask / Detect / Detect-Ask / ANSI / RIP

**Theme Editor** (mystic -cfg > Editors > Theme):

    Icon Path       path to .ICN icon files
    Font Path       path to .CHR font files
    Allow RIP       Yes/No per theme

**Command line:**

    mystic -L -R    local mode with RIPscrip forced
    mystic -R       force RIP terminal mode

If Icon Path or Font Path are empty or missing, Mystic halts:

    Icon path: (not set)
    Font path: (not set)
    ERROR: Theme paths missing for theme: default
    Run: maketheme cfgtheme  to set the missing paths.

## File layout

    \mystic\text\           Display files (.ans and .rip side by side)
    \mystic\text\icon\      RIPscrip icons (.icn, 24x24 EGA)
    \mystic\text\font\      BGI vector fonts (.chr)
    \mystic\menus\          Menu files (.mnu and .rip side by side)

File search order for RIP terminals: .rip > .ans > .asc

## MCI codes

| Code | Description |
|------|-------------|
| \|SE | Terminal type: shows "RIP", "Ansi", or "Ascii" |
| \|RI | RIP reset: sends !|* to clear RIP screen (no-op if not RIP) |

## File formats

| Extension | Description |
|-----------|-------------|
| .rip | RIPscrip scene — text file with !| commands |
| .ans | ANSI art — text with ESC[ escape sequences |
| .asc | ASCII text — plain text |
| .icn | RIPscrip icon — binary, BGI GetImage format, 24x24 EGA |
| .chr | BGI vector font — binary, Borland stroked font format |
| .mnu | Menu definition — binary packed records |

## RIPscrip command reference (51 commands)

### Level 0 — drawing primitives

| Cmd | Name | Args | Description |
|-----|------|------|-------------|
| c | Color | color | Set draw color (0-15) |
| W | WriteMode | mode | 0=copy, 1=XOR |
| = | LineStyle | style, pattern | Line drawing style |
| m | Move | x, y | Move pen to position |
| X | Pixel | x, y | Draw single pixel |
| L | Line | x0,y0,x1,y1 | Draw line |
| R | Rectangle | x0,y0,x1,y1 | Draw rectangle outline |
| B | Bar | x0,y0,x1,y1 | Draw filled rectangle |
| C | Circle | x,y,radius | Draw circle |
| O | Oval | x,y,xr,yr | Draw oval outline |
| o | FilledOval | x,y,xr,yr | Draw filled oval |
| F | FloodFill | x,y,border | Flood fill to border color |
| @ | TextXY | x,y,text | Draw text at position |
| T | Text | text | Draw text at current position |
| M | Mouse | fields,text | Define clickable mouse region |
| K | KillMouse | (none) | Remove all mouse regions |
| e | EraseWindow | (none) | Erase text window |
| E | EraseView | (none) | Erase viewport |
| A | Arc | x,y,st,end,r | Draw arc |
| V | OvalArc | x,y,st,end,xr,yr | Draw oval arc |
| I | PieSlice | x,y,st,end,r | Draw pie slice |
| i | OvalPieSlice | x,y,st,end,xr,yr | Draw oval pie slice |
| Z | Bezier | x1-x4,y1-y4,count | Draw bezier curve |
| S | FillStyle | pattern,color | Set fill style |
| s | FillPattern | pattern,color | Set custom fill pattern |
| Y | FontStyle | font,dir,size | Set text font |
| Q | SetPalette | 16 values | Set full palette |
| a | OnePalette | color,ega64 | Set one palette entry |
| v | Viewport | x0,y0,x1,y1 | Set graphics viewport |
| w | TextWindow | x0,y0,x1,y1,wrap | Set text output window |
| * | Reset | (none) | Reset all windows and state |
| g | GotoXY | x,y | Move text cursor |
| H | Home | (none) | Text cursor to home position |
| > | EraseEOL | (none) | Erase to end of line |
| P | Polygon | npts,points | Draw polygon outline |
| p | FillPolygon | npts,points | Draw filled polygon |
| l | Polyline | npts,points | Draw connected line segments |
| # | NoMore | (none) | End of scene marker |

### Level 1 — buttons, text blocks, clipboard

| Cmd | Name | Args | Description |
|-----|------|------|-------------|
| 1B | ButtonStyle | params | Set button drawing style |
| 1U | Button | x0,y0,x1,y1,params | Draw clickable button |
| 1T | BeginText | x,y,w,h | Start text block region |
| 1t | RegionText | justify,text | Add text to block |
| 1E | EndText | (none) | End text block |
| 1C | GetImage | x0,y0,x1,y1 | Copy screen region to clipboard |
| 1P | PutImage | x,y,mode | Paste clipboard to screen |
| 1W | WriteIcon | filename | Save clipboard as .icn file |
| 1I | LoadIcon | x,y,mode,clip,file | Load .icn file to screen |
| 1G | CopyRegion | x0,y0,x1,y1,dx,dy | Copy screen region |
| 1M | Mouse | fields,text | Mouse region (level 1 format) |
| 1K | KillMouse | (none) | Remove mouse regions |
| 1D | Define | $name=value | Set a variable |
| 1R | ReadScene | filename | Load and parse another .rip |
| 1F | FileQuery | filename | Query file existence on host |
| 1Q | Query | (none) | Respond with RIPSCRIP015400 |

## Base-36 encoding

RIPscrip coordinates use "mega-numbers": 2 base-36 digits.
Each digit is 0-9 or A-Z (case insensitive). Range: 00-ZZ (0-1295).

    00 = 0, 09 = 9, 0A = 10, 0Z = 35
    10 = 36, 1A = 46, ZZ = 1295

4-digit "mega-mega" numbers (0-1679615) use two mega-numbers:
high word * 1296 + low word.

## Line framing

RIPscrip commands are CR-terminated. Lines must not exceed ~70 chars.
Long commands use backslash continuation:

    !|L00000000050005\
    !|L00050005000A000A

Non-command text (no !| prefix) is written to the text window.

## Tools

| Tool | Description |
|------|-------------|
| ans2rip | ANSI-to-RIP converter (block chars to bars) |
| mripedit | Standalone RIP scene editor |
| mkicons | .ICN icon file generator |
| ripmake | Text-description to .RIP generator |
| rip_render | Headless .RIP to BMP renderer |
| rip_view | SDL2 .RIP viewer with mouse regions |
| maketheme cfgtheme | Set theme paths from command line |

## Credits

- RIPscrip v1.54: TeleGrafix Communications (freely licensed protocol)
- PabloDraw (MIT): RipWriter encoding patterns for ans2rip
- Carl Gorringe / RIPtermJS (GPLv3): reference implementation studied
- BGI fonts (.CHR): originally Borland International, freely available
- Engine: maintainer's clean-room implementation, FPC RTL only, GPLv3

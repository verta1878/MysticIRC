# RIPscript Print API — Research & Common API Design

## What FPC/fpc264irc Already Has

### RTL `printer` unit (text-mode only)
Available on ALL platforms. Provides a `Lst: Text` variable — just `WriteLn(Lst, 'text')` to print text. Very basic.

| Platform | Device | How it works |
|----------|--------|-------------|
| DOS (go32v2) | `PRN` | Direct to LPT1 parallel port via DOS INT 17h |
| i8086-msdos | `PRN` | Same, real-mode INT 17h |
| Win32 | `PRN` | Windows printer spooler |
| Unix/Linux | `/tmp/PID.lst` → `lpr` | Writes temp file, pipes to `lpr` |
| OS/2 | `PRN` | OS/2 printer spooler |
| Darwin | `/tmp/PID.lst` → `lpr` | Same as Unix |

**Limitation:** Text only. No graphics. No ESC/P, PCL, or PostScript. Just raw bytes to the printer device.

### Lazarus `OSPrinters` component (GUI printing)
Full graphical printing via OS print dialog. Platform backends:

| Platform | Backend |
|----------|---------|
| Unix/Linux | CUPS (cupsprinters) |
| macOS | Carbon print API |
| Win32 | Windows GDI printing |
| Qt | Qt print system |

**Provides:** `TPrinter` class, `TPrintDialog`, page setup, canvas drawing.
**Limitation:** Requires LCL (GUI), not available in console/DOS programs.

### What's Missing
- No ESC/P (Epson dot-matrix) support
- No PCL (HP LaserJet) support
- No PostScript generation
- No way to send graphics to a printer from a console app
- No 300/600/1200 DPI rasterization from a pixel buffer

---

## RIPscript Printer Context

RIPscrip is described in its own specs as "a page description language similar in concept to PostScript or HPGL." The framebuffer IS a printable page.

### What RIPscript scenes contain that maps to print:
- Vector primitives (lines, circles, rectangles, polygons)
- Filled regions (solid, pattern, gradient)
- Text (CHR vector fonts, bitmap fonts)
- Images (BMP, PCX, JPEG, PNG, GIF, ICO)
- Buttons and UI elements (could print as labeled boxes)
- Mouse fields (invisible — skip for print)

### Print resolution mapping:

| RIP Version | Screen Resolution | At 300 DPI | At 600 DPI |
|-------------|------------------|-----------|-----------|
| v1 (EGA) | 640 x 350 | 2.13" x 1.17" | 1.07" x 0.58" |
| v1 (scaled to page) | 640 x 350 → 2400 x 1312 | 8.0" x 4.37" | 4.0" x 2.19" |
| v2 | 1280 x 1024 | 4.27" x 3.41" | 2.13" x 1.71" |
| v2 (scaled) | 1280 x 1024 → 2400 x 1920 | 8.0" x 6.4" | 4.0" x 3.2" |
| v3 | Resolution-independent | Renders at any DPI | Native |

---

## Common Print API Design

### DOS 8.3 File Naming

| File | Purpose |
|------|---------|
| `prnapi.pas` | Common print API (all versions) |
| `prnescp.pas` | ESC/P driver (Epson dot-matrix) |
| `prnpcl.pas` | PCL driver (HP LaserJet) |
| `prnps.pas` | PostScript driver |
| `prnbmp.pas` | BMP file output (print to file) |
| `prnraw.pas` | Raw bitmap to LPT/device |
| `prndlg.pas` | Print dialog (v4, LCL/GUI only) |

### Common API (`prnapi.pas`)

```pascal
unit prnapi;

type
  TPrnDriver = (pdEscP, pdPCL, pdPostScript, pdBMP, pdRaw);
  TPrnOrient = (poPortrait, poLandscape);
  TPrnPaper  = (ppLetter, ppA4, ppLegal, ppCustom);

  TPrnConfig = record
    Driver: TPrnDriver;
    DPI: Word;              { 72, 150, 300, 600, 1200 }
    Paper: TPrnPaper;
    Orientation: TPrnOrient;
    MarginTop: Word;        { in 1/100 inch }
    MarginBottom: Word;
    MarginLeft: Word;
    MarginRight: Word;
    PageWidthDots: LongWord;  { calculated from paper+DPI }
    PageHeightDots: LongWord;
    DeviceName: ShortString;  { 'LPT1', '/dev/lp0', 'output.bmp' }
    Copies: Byte;
  end;

  TPrnPage = record
    Pixels: PByte;           { RGB, 3 bytes/pixel at target DPI }
    Width, Height: LongWord; { in dots }
    BPP: Byte;               { 1=mono, 8=gray, 24=color }
  end;

{ Initialize print config with defaults }
procedure PrnInitConfig(var Cfg: TPrnConfig;
  Driver: TPrnDriver; DPI: Word);

{ Create a page buffer at the configured DPI }
procedure PrnCreatePage(var Cfg: TPrnConfig; var Page: TPrnPage);

{ Render a RIP framebuffer to the print page (scale to fit) }
procedure PrnRenderFrame(var Page: TPrnPage;
  RIPPixels: PByte; RIPW, RIPH: Word);

{ Send page to printer via configured driver }
function PrnPrintPage(var Cfg: TPrnConfig; var Page: TPrnPage): Boolean;

{ Free page }
procedure PrnFreePage(var Page: TPrnPage);
```

### Driver Interface

Each driver (`prnescp.pas`, `prnpcl.pas`, `prnps.pas`) implements:

```pascal
{ Open printer device/file }
function PrnDrvOpen(var Cfg: TPrnConfig): Boolean;

{ Send page data in driver's language }
function PrnDrvSendPage(var Cfg: TPrnConfig; var Page: TPrnPage): Boolean;

{ Close printer }
procedure PrnDrvClose(var Cfg: TPrnConfig);
```

### Pipeline

```
RIP Scene
  → Render to framebuffer (existing engine)
  → PrnRenderFrame (scale to print DPI)
  → PrnPrintPage
    → prnescp.pas (ESC/P byte stream → LPT1)
    → prnpcl.pas  (PCL5 commands → LPT1 or file)
    → prnps.pas   (PostScript → file or lpr pipe)
    → prnbmp.pas  (BMP file for print-to-file)
    → prnraw.pas  (raw bitmap → device)
```

---

## Printer Language Details

### ESC/P (Epson Standard Code for Printers)
- The BBS-era dot-matrix standard
- Binary escape sequences: ESC + command byte + data
- Graphics mode: ESC * m nL nH [data] — sends bitmap rows
- 60/120/180/240/360 DPI depending on mode
- Supported printers: Epson FX/LX/MX, Star, Panasonic, Okidata, most 9/24-pin

Key commands:
```
ESC @          — Initialize printer
ESC * 0 nL nH  — 60 DPI single-density graphics
ESC * 1 nL nH  — 120 DPI double-density
ESC * 32 nL nH — 180 DPI (24-pin)
ESC * 33 nL nH — 360 DPI (24-pin)
CR LF          — Next line
ESC J n        — Advance paper n/180 inches
ESC 3 n        — Set line spacing to n/180 inches
```

### PCL (Printer Command Language — HP)
- HP LaserJet standard
- Escape sequences: ESC + parameter characters
- Raster graphics: ESC*r#S (start), ESC*b#W[data] (transfer row)
- 75/100/150/300/600/1200 DPI
- Supported: HP LaserJet, DeskJet, compatible lasers

Key commands:
```
ESC E           — Reset
ESC *t300R      — Set resolution 300 DPI
ESC *r1A        — Start raster graphics
ESC *b[n]W      — Transfer raster data (n bytes)
ESC *rB         — End raster
ESC &l0O        — Portrait orientation
ESC &l1O        — Landscape
ESC &l2A        — Letter paper
ESC &l26A       — A4 paper
```

### PostScript (Level 1/2)
- High-end, resolution-independent
- Text-based language, human-readable
- Can embed bitmaps OR draw vectors natively
- Supported: Apple LaserWriter, high-end office printers, PDF

```postscript
%!PS-Adobe-2.0
%%BoundingBox: 0 0 612 792
/inch {72 mul} def
% RIP scene as bitmap:
300 300 scale
640 350 8 [640 0 0 -350 0 350]
{currentfile picstr readhexstring pop} image
[hex pixel data...]
showpage
```

---

## Per-Version Printer Integration

### v1 (`printap1.pas` — 8.3 name)
- Source: 640x350 EGA framebuffer
- Scale to page width at target DPI
- Dither to 1-bit for dot-matrix (Floyd-Steinberg)
- ESC/P primary target (BBS era = dot-matrix)

### v2 (`printap2.pas`)
- Source: up to 1280x1024
- Scale with bilinear filtering
- PCL + PostScript targets
- Can include embedded JPEG in PostScript output

### v3 (`printap3.pas`)
- Resolution-independent coordinates
- Render directly at print DPI (no scaling artifacts)
- Full PostScript vector output possible (not just bitmap)
- True color support

### v4 (`prndlg.pas` — future)
- LCL `TPrintDialog` integration
- OS print driver selection (user picks printer)
- Preview rendering
- Multi-page support

---

## Implementation Order

1. **prnapi.pas** — Common API, config, page buffer, scaling
2. **prnraw.pas** — Raw bitmap to LPT/device (simplest driver)
3. **prnbmp.pas** — Print to BMP file (for testing without printer)
4. **prnescp.pas** — ESC/P dot-matrix (the classic BBS printer)
5. **prnpcl.pas** — PCL5 LaserJet
6. **prnps.pas** — PostScript
7. **prndlg.pas** — v4 GUI print dialog (deferred)

### Estimated Lines

| Unit | Est. Lines |
|------|-----------|
| prnapi.pas | ~300 |
| prnraw.pas | ~100 |
| prnbmp.pas | ~150 |
| prnescp.pas | ~250 |
| prnpcl.pas | ~200 |
| prnps.pas | ~300 |
| prndlg.pas | ~200 (v4) |

---

## Platform Support

| Driver | DOS | Win32 | Linux | OS/2 | Darwin |
|--------|-----|-------|-------|------|--------|
| ESC/P → LPT | ✅ direct | ✅ PRN | ✅ /dev/lp0 | ✅ PRN | ❌ |
| PCL → LPT | ✅ direct | ✅ PRN | ✅ /dev/lp0 | ✅ PRN | ⚠️ lpr |
| PostScript → file | ✅ | ✅ | ✅ | ✅ | ✅ |
| PostScript → lpr | ❌ | ⚠️ | ✅ | ⚠️ | ✅ |
| BMP file | ✅ | ✅ | ✅ | ✅ | ✅ |
| Print dialog | ❌ | ✅ v4 | ✅ v4 | ❌ | ✅ v4 |

---

## Notes for RIPscript Coder/Maintainer

- The common API (`prnapi.pas`) should be usable by v1, v2, and v3 engines
- Each engine passes its framebuffer to `PrnRenderFrame` which scales to DPI
- v3 can optionally bypass bitmap and emit PostScript vectors directly
- Floyd-Steinberg dithering essential for 1-bit dot-matrix output
- Test with DOSBox + virtual LPT capture for ESC/P verification
- PCL testing: many PDF printers accept PCL input
- PostScript testing: `ps2pdf` or Ghostscript

---

## v3 MIDI Support (already implemented)

v3 includes full MIDI synthesis — NOT deferred to v4. The complete stack:

| File (8.3) | Lines | Role |
|-----------|-------|------|
| mididec.pas | 378 | SMF parser: .mid → events |
| midsynth.pas | 501 | 2-op FM synthesis (OPL2 style), 32 voices, GM patches |
| midiplay.pas | 258 | Tick-by-tick player, tempo handling |
| midistrm.pas | 78 | Streaming API bridge (audstream callback) |

Pipeline: `.mid → mididec → midiplay → midsynth → midistrm → audstream → output`

v4 should NOT re-implement MIDI — use the v3 units directly.

---

## DOS 8.3 Filename Convention

ALL RIPscript code MUST use DOS 8.3 filenames for cross-platform
compatibility with go32v2, i8086-msdos, and OS/2 targets.

### Rules:
- Max 8 characters for name, 3 for extension
- No spaces, no special characters
- Lowercase preferred (DOS is case-insensitive)
- Use abbreviations: `synth` → `synth`, `stream` → `strm`, `render` → `rendr`

### Current 8.3 compliance check:

| Current Name | 8.3 OK? | Fix |
|-------------|---------|-----|
| prnapi.pas | ✅ | — |
| prnescp.pas | ✅ | — |
| prnpcl.pas | ✅ | — |
| prnps.pas | ✅ | — |
| prnbmp.pas | ✅ | — |
| prnraw.pas | ✅ | — |
| prndlg.pas | ✅ | — |
| ripdecraw.pas | ❌ 9 chars | ripdecr.pas |
| ripbindec.pas | ❌ 9 chars | ripbind.pas |
| riplayerdec.pas | ❌ 11 chars | riplayr.pas |
| gifinterlace.pas | ❌ 14 chars | gifintl.pas |
| pnginterlace.pas | ❌ 14 chars | pngintl.pas |
| gifanim.pas | ✅ | — |
| spriteanim.pas | ❌ 10 chars | spranim.pas |
| midisynth.pas | ❌ 9 chars | midsynth.pas |
| midistream.pas | ❌ 10 chars | midistrm.pas |
| midiplay.pas | ✅ | — |
| modstream.pas | ❌ 9 chars | modstrm.pas |
| vocstream.pas | ❌ 9 chars | vocstrm.pas |
| wavstream.pas | ❌ 9 chars | wavstrm.pas |
| asyncplay.pas | ❌ 9 chars | asyncpl.pas |
| audstream.pas | ❌ 9 chars | audstrm.pas |
| netaudio.pas | ✅ | — |
| ringbuf.pas | ✅ | — |
| jpegprog.pas | ✅ | — |
| riprender.pas | ❌ 9 chars | riprndr.pas |
| mp3requant.pas | ❌ 10 chars | mp3reqt.pas |

### Recommendation
For the next release, rename all non-compliant files to 8.3.
This ensures the code compiles on DOS (go32v2 + i8086) and
OS/2 without path truncation issues. The FPC compiler itself
handles long filenames on modern platforms, but the source
should be portable to any filesystem.

---

## Summary for RIPscript Maintainer

1. **Print API is a common bridge** — `prnapi.pas` works with v1/v2/v3 engines
2. **v3 already has MIDI** — don't duplicate in v4
3. **Use 8.3 filenames** — DOS/OS2 compatibility
4. **Start at 300 DPI** — standard laser/inkjet, scales up to 600/1200
5. **ESC/P first** — the BBS community still has dot-matrix printers
6. **PostScript for quality** — file output, `lpr` pipe, PDF conversion via `ps2pdf`
7. **v4 adds print dialog** — LCL `TPrintDialog` for GUI apps only

---

## HTML 1.0 Standard for RIPx

RIPscript v3 whitepaper section 4.7 planned HTML inside RIPscrip.
Using the HTML 1.0 standard (RFC 1866 / HTML 2.0 baseline) keeps
it simple and implementable in pure Pascal.

### Why HTML 1.0

- Minimal tag set (~40 tags vs 100+ in HTML5)
- No CSS, no JavaScript — just structure + inline formatting
- Text-based — fits the BBS terminal model
- Well-documented, stable, never changes
- TeleGrafix's RIPweb already translated HTML to RIPscrip "on-the-fly"

### HTML 1.0 Tag Set (RFC 1866 subset)

**Document structure:**
```
<HTML> <HEAD> <TITLE> <BODY>
```

**Text formatting:**
```
<H1>..<H6>    Headings
<P>           Paragraph
<BR>          Line break
<HR>          Horizontal rule
<B> <I> <U>   Bold, italic, underline
<TT>          Monospace (CP437 font)
<PRE>         Preformatted (preserve whitespace)
<BLOCKQUOTE>  Indented quote
<CENTER>      Centered text
```

**Lists:**
```
<UL> <OL> <LI>   Unordered/ordered lists
<DL> <DT> <DD>   Definition list
```

**Links and images:**
```
<A HREF="...">    Hyperlink (→ RIP mouse field)
<IMG SRC="...">   Image (→ RIP LoadIcon/PutImage)
```

**Tables (HTML 2.0):**
```
<TABLE> <TR> <TD> <TH>   Basic tables
```

**Forms (simplified):**
```
<FORM> <INPUT> <SELECT> <TEXTAREA>
→ Maps to RIP buttons + text input fields
```

### HTML → RIP Command Mapping

| HTML Tag | RIP v1 Equivalent | RIP v3 Equivalent |
|----------|-------------------|-------------------|
| `<H1>` | OutText + SetFont(large) | SetFont + TextXY |
| `<P>` | CR/LF + line spacing | Paragraph block |
| `<BR>` | CR/LF | Line break |
| `<HR>` | DrawLine full width | HorizRule command |
| `<B>` | SetColor(bright) | SetFontStyle(bold) |
| `<I>` | (no italic in EGA) | SetFontStyle(italic) |
| `<IMG>` | LoadIcon | LoadImage |
| `<A HREF>` | MouseField + button | HyperLink + MouseField |
| `<TABLE>` | Manual grid drawing | DataTable command |
| `<UL><LI>` | OutText with bullet char | List rendering |
| `<FORM>` | Button + text input | Form system |
| `<PRE>` | Raw ANSI text mode | Monospace block |
| `<CENTER>` | Calculate X offset | AlignCenter |

### Parser Architecture (DOS 8.3 names)

| File | Purpose |
|------|---------|
| htmlpars.pas | HTML tokenizer — tags, attributes, entities |
| htmltree.pas | DOM-lite tree (parent/child/sibling nodes) |
| htmllayo.pas | Layout engine — box model, text flow, line breaking |
| htmlrip.pas | HTML → RIP command translator |
| htmlrend.pas | Direct HTML → pixel buffer renderer |

### HTML Entity Support (essential for BBS)

```pascal
const
  HTMLEntities: array[0..9] of record
    Name: ShortString;
    Char: Byte; { CP437 code }
  end = (
    (Name: 'amp';   Char: Ord('&')),
    (Name: 'lt';    Char: Ord('<')),
    (Name: 'gt';    Char: Ord('>')),
    (Name: 'quot';  Char: Ord('"')),
    (Name: 'nbsp';  Char: 255),      { CP437 non-breaking space }
    (Name: 'copy';  Char: 184),      { CP437 copyright-ish }
    (Name: 'bull';  Char: 7),        { CP437 bullet }
    (Name: 'mdash'; Char: 196),      { CP437 horizontal line }
    (Name: 'laquo'; Char: 174),      { CP437 « }
    (Name: 'raquo'; Char: 175)       { CP437 » }
  );
```

### Integration with Print API

HTML rendering feeds the same pixel buffer as RIPscript.
The print pipeline works identically:

```
HTML source → htmlpars → htmllayo → htmlrend → pixel buffer
                                                    ↓
                                              prnapi.pas → printer
```

This means a RIPx terminal could:
1. Receive HTML from a web server (like RIPweb did)
2. Render to the RIP framebuffer
3. Print the page via prnapi
4. All in pure Pascal, all on DOS

### Reference Documents

- RFC 1866: HTML 2.0 Specification (Nov 1995)
- RFC 1945: HTTP/1.0 (May 1996)
- TeleGrafix RIPscrip v3 Whitepaper Section 4.7
- RIPweb product description (HTML-to-RIP translator)

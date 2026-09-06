# RIPscrip v4.0 — Print API & HTML 1.0 Specification

## Print API Design

### What FPC/fpc264irc Already Has

**RTL `printer` unit (text-mode only):**
Provides `Lst: Text` variable — `WriteLn(Lst, 'text')` to print.
DOS=LPT1, Win32=spooler, Unix=lpr pipe, OS/2=spooler.
Limitation: text only, no graphics.

**Lazarus `OSPrinters` (GUI only):**
CUPS (Linux), Carbon (macOS), GDI (Win32), Qt.
Provides TPrinter, TPrintDialog, canvas drawing.
Limitation: requires LCL, not available in console/DOS programs.

**What's missing:**
No ESC/P (Epson dot-matrix), no PCL (HP LaserJet),
no PostScript generation, no graphics-to-printer from console apps,
no DPI rasterization from a pixel buffer.

### RIPscrip as a Page Description Language

RIPscrip is described in its own specs as "a page description language
similar in concept to PostScript or HPGL." The framebuffer IS a
printable page.

Print resolution mapping:

| RIP Version | Screen Resolution | At 300 DPI | At 600 DPI |
|-------------|-------------------|------------|------------|
| v1 (EGA) | 640x350 | 2.13"x1.17" | 1.07"x0.58" |
| v1 (scaled) | 640x350 → 2400x1312 | 8.0"x4.37" | 4.0"x2.19" |
| v2 | 1280x1024 | 4.27"x3.41" | 2.13"x1.71" |
| v3/v4 | Resolution-independent | Renders at any DPI | Native |

### Units (DOS 8.3 compliant)

| File | Purpose | Est. Lines |
|------|---------|------------|
| prnapi.pas | Common print API (all versions) | ~300 |
| prnraw.pas | Raw bitmap to LPT/device | ~100 |
| prnbmp.pas | BMP file output (print to file) | ~150 |
| prnescp.pas | ESC/P driver (Epson dot-matrix) | ~250 |
| prnpcl.pas | PCL driver (HP LaserJet) | ~200 |
| prnps.pas | PostScript driver | ~300 |
| prndlg.pas | Print dialog (LCL/GUI only) | ~200 |

### Common API

```pascal
type
  TPrnDriver = (pdEscP, pdPCL, pdPostScript, pdBMP, pdRaw);
  TPrnOrient = (poPortrait, poLandscape);
  TPrnPaper  = (ppLetter, ppA4, ppLegal, ppCustom);

  TPrnConfig = record
    Driver: TPrnDriver;
    DPI: Word;              { 72, 150, 300, 600, 1200 }
    Paper: TPrnPaper;
    Orientation: TPrnOrient;
    MarginTop, MarginBottom, MarginLeft, MarginRight: Word;
    PageWidthDots, PageHeightDots: LongWord;
    DeviceName: ShortString; { 'LPT1', '/dev/lp0', 'output.bmp' }
    Copies: Byte;
  end;

procedure PrnInitConfig(var Cfg: TPrnConfig; Driver: TPrnDriver; DPI: Word);
procedure PrnCreatePage(var Cfg: TPrnConfig; var Page: TPrnPage);
procedure PrnRenderFrame(var Page: TPrnPage; RIPPixels: PByte; RIPW, RIPH: Word);
function  PrnPrintPage(var Cfg: TPrnConfig; var Page: TPrnPage): Boolean;
procedure PrnFreePage(var Page: TPrnPage);
```

### Pipeline

```
RIP Scene → Render to framebuffer → PrnRenderFrame (scale to DPI)
  → prnescp.pas (ESC/P → LPT1)
  → prnpcl.pas  (PCL5 → LPT1 or file)
  → prnps.pas   (PostScript → file or lpr)
  → prnbmp.pas  (BMP file)
  → prnraw.pas  (raw bitmap → device)
```

### Per-Version Integration

| Version | Source | Primary Target |
|---------|--------|----------------|
| v1 (printap1.pas) | 640x350 EGA, Floyd-Steinberg dither to 1-bit | ESC/P dot-matrix |
| v2 (printap2.pas) | up to 1280x1024, bilinear scale | PCL + PostScript |
| v3/v4 (printap3.pas) | Resolution-independent, render at print DPI | PostScript vectors |

### Platform Support

| Driver | DOS | Win32 | Linux | OS/2 | Darwin |
|--------|-----|-------|-------|------|--------|
| ESC/P → LPT | ✅ | ✅ | ✅ | ✅ | ❌ |
| PCL → LPT | ✅ | ✅ | ✅ | ✅ | ⚠️ lpr |
| PostScript → file | ✅ | ✅ | ✅ | ✅ | ✅ |
| PostScript → lpr | ❌ | ⚠️ | ✅ | ⚠️ | ✅ |
| BMP file | ✅ | ✅ | ✅ | ✅ | ✅ |
| Print dialog | ❌ | ✅ | ✅ | ❌ | ✅ |

### Implementation Order

1. prnapi.pas — common API, config, page buffer, scaling
2. prnraw.pas — raw bitmap to LPT/device (simplest)
3. prnbmp.pas — print to BMP file (testing without printer)
4. prnescp.pas — ESC/P dot-matrix (classic BBS printer)
5. prnpcl.pas — PCL5 LaserJet
6. prnps.pas — PostScript
7. prndlg.pas — GUI print dialog (LCL only)

---

## HTML 1.0 for RIPx

RIPscrip v3 whitepaper section 4.7 planned HTML inside RIPscrip.
Using HTML 1.0 (RFC 1866 / HTML 2.0 baseline) keeps it simple
and implementable in pure Pascal.

### Why HTML 1.0

- Minimal tag set (~40 tags vs 100+ in HTML5)
- No CSS, no JavaScript — just structure + inline formatting
- Text-based — fits the BBS terminal model
- Well-documented, stable, never changes
- TeleGrafix's RIPweb already translated HTML to RIPscrip

### Tag Set

**Document:** `<HTML>` `<HEAD>` `<TITLE>` `<BODY>`

**Text:** `<H1>..<H6>` `<P>` `<BR>` `<HR>` `<B>` `<I>` `<U>` `<TT>` `<PRE>` `<BLOCKQUOTE>` `<CENTER>`

**Lists:** `<UL>` `<OL>` `<LI>` `<DL>` `<DT>` `<DD>`

**Links/images:** `<A HREF>` `<IMG SRC>`

**Tables:** `<TABLE>` `<TR>` `<TD>` `<TH>`

**Forms:** `<FORM>` `<INPUT>` `<SELECT>` `<TEXTAREA>`

### HTML → RIP Command Mapping

| HTML Tag | RIP v3 Equivalent |
|----------|-------------------|
| `<H1>` | SetFont + TextXY |
| `<P>` | Paragraph block |
| `<BR>` | Line break |
| `<HR>` | HorizRule command |
| `<B>` | SetFontStyle(bold) |
| `<I>` | SetFontStyle(italic) |
| `<IMG>` | LoadImage |
| `<A HREF>` | HyperLink + MouseField |
| `<TABLE>` | DataTable command |
| `<UL><LI>` | List rendering |
| `<FORM>` | Form system |
| `<PRE>` | Monospace block |
| `<CENTER>` | AlignCenter |

### Parser Units (DOS 8.3)

| File | Purpose |
|------|---------|
| htmlpars.pas | HTML tokenizer — tags, attributes, entities |
| htmltree.pas | DOM-lite tree (parent/child/sibling nodes) |
| htmllayo.pas | Layout engine — box model, text flow, line breaking |
| htmlrip.pas | HTML → RIP command translator |
| htmlrend.pas | Direct HTML → pixel buffer renderer |

### HTML Entity Support (CP437 mapped)

```
&amp; → &    &lt; → <    &gt; → >    &quot; → "
&nbsp; → 255  &copy; → 184  &bull; → 7
&mdash; → 196  &laquo; → 174  &raquo; → 175
```

### Integration with Print API

```
HTML source → htmlpars → htmllayo → htmlrend → pixel buffer
                                                    ↓
                                              prnapi.pas → printer
```

---

## DOS 8.3 Filename Compliance

All RIPscrip code MUST use DOS 8.3 filenames for go32v2,
i8086-msdos, and OS/2 compatibility.

### Files Requiring Rename

| Current Name | 8.3 Fix |
|-------------|---------|
| ripdecraw.pas | ripdecr.pas |
| ripbindec.pas | ripbind.pas |
| riplayerdec.pas | riplayr.pas |
| riprender.pas | riprndr.pas |
| gifinterlace.pas | gifintl.pas |
| pnginterlace.pas | pngintl.pas |
| spriteanim.pas | spranim.pas |
| midisynth.pas | midsynth.pas |
| midistream.pas | midistrm.pas |
| modstream.pas | modstrm.pas |
| vocstream.pas | vocstrm.pas |
| wavstream.pas | wavstrm.pas |
| asyncplay.pas | asyncpl.pas |
| audstream.pas | audstrm.pas |
| mp3requant.pas | mp3reqt.pas |

### 8.3-Compliant Files (no change needed)

prnapi, prnescp, prnpcl, prnps, prnbmp, prnraw, prndlg,
htmlpars, htmltree, htmllayo, htmlrip, htmlrend,
midiplay, mididec, gifanim, jpegprog, netaudio, ringbuf,
rffdecraw (8 chars), ripchange (9 → ripchnge.pas)

---

## MIDI Pipeline (already in v3/v4)

Complete — do NOT reimplement in v4.

| File | Lines | Role |
|------|-------|------|
| mididec.pas | 378 | SMF parser: .mid → events |
| midisynth.pas | 501 | 2-op FM synthesis, 32 voices, GM patches |
| midiplay.pas | 258 | Tick-by-tick player, tempo handling |
| midistream.pas | 78 | Streaming API bridge (audstream callback) |

Pipeline: `.mid → mididec → midiplay → midisynth → midistream → audstream → output`

---

## Reference Documents

- RFC 1866: HTML 2.0 Specification (Nov 1995)
- RFC 1945: HTTP/1.0 (May 1996)
- TeleGrafix RIPscrip v3 Whitepaper Section 4.7
- RIPweb product description (HTML-to-RIP translator)

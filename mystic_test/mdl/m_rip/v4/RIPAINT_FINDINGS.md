
## Binary : RIPAINT.EXE (DOS4GW 32-bit protected mode)
## Version: RIPaint 2.0 (TeleGrafix Communications, 1997) Analysis 

---

## Context

It creates and edits RIPscrip scene files and RFF vector fonts.

These are **editor features**, not RIPscrip protocol features.
They describe what RIPAINT.EXE can do as a desktop application.

---

## Finding 1: PostScript Export

### Evidence

PostScript procedure definitions found:

```
/_bgnp { newpath _ml _mt moveto } def
/_cr   { currentpoint exch pop _ml exch moveto } def
/_hd   { currentpoint 36 _ts div sub moveto } def
/_hu   { currentpoint 36 _ts div add moveto } def
/_lf   { currentpoint 72 _ts div sub moveto } def
18 %3.1f moveto (%s) show
% ***** Begin  Image *****
% ***** End of Image *****
%%BeginProlog
%%EndProlog
```

### Interpretation

RIPAINT.EXE can export drawings to PostScript format. The PS code
includes standard DSC (Document Structuring Conventions) markers
(`%%BeginProlog`, `%%EndProlog`) and custom procedures for text
positioning (`_bgnp` = begin path, `_cr` = carriage return,
`_hd` = half down, `_hu` = half up, `_lf` = line feed).

The `moveto` + `show` commands render text at computed positions.
The `newpath` + `moveto` sequence renders vector strokes —
confirming RFF font data maps cleanly to PostScript path operations.

### What We Don't Know

- Whether v1.54 RIPaint (16-bit) had PostScript export
- Whether this exports the full drawing or just fonts
- What printer drivers or output paths are supported

---

## Finding 2: HP LaserJet Printer Output

### Evidence

```
HP LaserJet Series III
HP Laserjet
LaserJet font not found
JetError in reading font file
```

### Interpretation

HP LaserJet printer driver. The error messages
suggest:

- "LaserJet font not found" — the editor looks for LaserJet-compatible
  font files when printing
- "JetError in reading font file" — the RFF font engine has a code path
  specifically for LaserJet output, and the error handler is prefixed
  with "Jet" (possibly the internal module name for the font engine)

This means RFF vector fonts could be rendered to LaserJet PCL output,
not just to screen via Windows GDI (MoveToEx/LineTo).

### What We Don't Know

- Whether v1.54 RIPaint (16-bit) had LaserJet support
- Whether "Jet" is the font engine module name or just the printer module
- What PCL commands are used (HPGL vectors? PCL bitmap? PCL5 scalable?)
- Whether other printers are supported (Epson, etc.)

---

## Finding 3: Unknown 16-Character Table "GKENDIFLAJCMBH@O"

### Evidence

Found at offset 0x15DF13 in RIPAINT.EXE:

```
Hex: 47 4B 45 4E 44 49 46 4C 41 4A 43 4D 42 48 40 4F
     00 55 53 56 57 ...
ASCII: G K E N D I F L A J C M B H @ O [NUL] U S V W ...
```

16 printable ASCII characters followed by a null terminator,
then "USV" "W" and x86 code.

### Interpretation

Unknown. Possible theories:

1. **Drawing tool dispatch table** — 16 single-character codes mapping
   to drawing tools (e.g., G=?, K=?, E=Ellipse?, N=?, D=Draw?,
   I=?, F=Fill?, L=Line?, A=Arc?, J=?, C=Circle/Curve?, M=Move?,
   B=Bezier?, H=?, @=special, O=?)

2. **Keyboard shortcut map** — single-key shortcuts for editor functions

3. **Internal command set** — opcodes for the drawing engine

The "USV" "W" bytes after the null terminator may be additional
entries or unrelated code.

### What We Don't Know

- What each character maps to
- Whether this is version-specific to v2.0
- Whether it relates to RFF fonts, drawing tools, or something else

---

## Other RIPAINT.EXE Findings (Already Documented Elsewhere)

These items are already captured in the RFF format notes:

- **"The Vector Sector"** — internal name for the font rendering engine
- **"Stroke pen is too large"** — pen width validation for RFF rendering
- **"COORDSIZE" / "Invalid coordinate size [%ld]"** — suggests variable
  coordinate widths may be supported in future format versions
- **"TBPOLYBZ" / "TBPOLYGN" / "TBPOLYLN"** — drawing tool names for
  bezier, polygon, and polyline (canvas tools, not RFF rendering)
- **Bezier debug output** — `Curve[%02hd]: B:(%05hd,%05hd)..(%05hd,%05hd)`
  confirms cubic bezier support in the drawing canvas (but NOT in RFF
  font rendering, which uses only MoveToEx + LineTo)
- **MoveToEx / LineTo / CreatePen** — the only GDI calls used for RFF
  stroke rendering 

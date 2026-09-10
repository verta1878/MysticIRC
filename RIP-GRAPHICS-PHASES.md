# ripview API Audit

Session 10 — 2026-09-06

## Recreate with Permission

Jeff Reeder and Mark Hayton (original TeleGrafix creators) have given
their blessing to recreate with permission the full RIPscrip software
suite as open source.

Target programs:
- RIPterm (DOS terminal — v1.54, v2.0/2.2)
- RIPtel (Visual Telnet — v3.1, Windows)
- RIPtel Visual for Windows
- RIPaint (graphics editor — v1.52, v2.1)

All recreations are faithful to the original work, built from our own
spec docs and protocol implementation (v1 through v4+), open source
under GPLv3.

### Technical Notes from Jeff Reeder

Flood fill: BGI had integer overflow bugs and a fixed 16-bit path
backup stack. Never 100% perfect. Anti-aliasing in modern vector APIs
(GDI) causes pixel gaps across resolutions. Flood fill was removed
in RIPscrip v2.0 for these reasons.

Fonts: non-BGI font systems are near impossible to replicate perfectly.
BGI CHR fonts are fine — anything beyond is tricky.

### v3.09 Source Code (Pending Release)

Jeff and Mark are willing to release the RIPscrip v3.09 source as it
existed in 2000 when TeleGrafix closed. Pure decoder, fully type-safe,
modern OOP. Has RIP generation hooks (like the old RIP-2-C library).
Groundwork laid but generation side not fully wrapped up.
Waiting on their timeline — both are on a new project under deadline.

Some third-party components may have licensing restrictions. Those
companies are likely all defunct. Clean room implementation is the
right approach for anything that cannot be published directly.

### Full v3 Specification (450 Pages)

The complete RIPscrip v3 specification exists as a 450-page document,
originally under NDA (Patrick Clawson era). Makes the v1.54 spec look
like child's play. Half of it covers text variables and the TV query
language — matches our audit finding that the entire text variable
system is missing from ripview (Section 9).

### The Crew

Team: verta1878 (lead), sysop/0, bob, evga, kiddo, wrench,
hexadecimal, byte, DotMatrix — "the crew 4free"

The whole team is on board for the recreation. First step: byte-exact
RIPterm 1.54.

## 1. Whitepaper Identity Problem

The project has three levels of whitepaper:

| File                                         | Scope | Lines | Location                          |
|----------------------------------------------|-------|-------|-----------------------------------|
| IRC-WHITEPAPER.md                            | v1    | 272   | repo root                         |
| ripscrip-v3-implementation-whitepaper.htm    | v3    | 579   | mystic/mdl/m_rip/v3/, v4/, attic  |
| ripscrip-v4irc-implementation-whitepaper.htm | v4    | 579   | mystic_ripview/, todo/, attic     |

**Problem:** The v4irc whitepaper is currently identical to the v3 whitepaper.
It was never updated with the HTML1 commands that were implemented in v4.

The v4 PHASES.md shows these as DONE:
- Full-Motion Video — MPEG-1 decoder (mpgdemux + mpgvdec + mpgvbuf + mpgplay + mpgstrm)
- Document Oriented Interface — htmllayo.pas box model layout engine
- HTML 1.0 Rendering — htmlpars + htmltree + htmllayo + htmlrip + htmlrend (5 units)
- MIDI Synthesis — midisynth.pas FM synth

But the v4irc whitepaper still says in section 3.10:
  "HTML rendering within the engine is deferred to v4.0."

**Fix needed:** Update ripscrip-v4irc-implementation-whitepaper.htm with:
- HTML1 5-unit stack API (htmlpars, htmltree, htmllayo, htmlrip, htmlrend)
- HTMLRenderPage(Source, Len) — parse HTML and render to pixel buffer
- HTMLRenderToRIP(Source, Len) — convert HTML to RIP commands
- Document Oriented Interface API (htmllayo.pas box model)
- MPEG-1 decoder API
- MIDI synthesis API (midisynth.pas)
- Any other v4-specific APIs not in v3

## 2. Drawing — Name Mismatches

ripscript.doc (the v1 API reference) uses BGI-style names. The actual
ripview code uses different names.

| ripscript.doc name  | actual ripview code name  | Unit          |
|---------------------|---------------------------|---------------|
| Line                | DrawLine                  | ripdraw.pas   |
| Rectangle           | DrawRect                  | ripdraw.pas   |
| Bar                 | FillRect                  | ripdraw.pas   |
| Bar3D               | N/A (dead code, never dispatched) | —      |
| Circle              | DrawCircle                | ripdraw.pas   |
| Ellipse             | DrawEllipse               | ripdraw.pas   |
| FillEllipse         | FillEllipse               | ripdraw.pas   |
| Arc                 | DrawArcLines              | ripdraw.pas   |
| PieSlice            | DrawSector                | ripdraw.pas   |
| Sector              | DrawSector                | ripdraw.pas   |
| DrawPoly            | FillPolyScanline          | ripdraw.pas   |
| FillPoly            | FillPolyScanline          | ripdraw.pas   |
| DrawBezier          | DrawBezier                | ripdraw.pas   |
| FloodFill           | FloodFill                 | ripdraw.pas   |
| PutPixel            | PutPixel                  | ripengine.pas |
| GetPixel            | GetPixel                  | ripengine.pas |

The code names (DrawLine, DrawRect, etc.) are more descriptive and match
the naming pattern used in v2-v4. Recommend updating ripscript.doc to
match the actual code names.

## 3. State — Mapping and Missing Wrappers

### 3a. State Mapping (ripstd → ripview)

How each ripstd state function maps to ripview today:

| ripstd reference name      | ripview name                   | Unit          | Notes                    |
|----------------------------|--------------------------------|---------------|--------------------------|
| SetColor                   | rip1exec state (Canvas.FG)     | rip1exec.pas  | direct field access      |
| SetBkColor                 | rip1exec state (Canvas.BG)     | rip1exec.pas  | direct field access      |
| SetLineStyle               | SetLineStyle (ripdraw)         | ripdraw.pas   | wrapper exists           |
| SetFillStyle               | rip1exec state                 | rip1exec.pas  | direct Canvas.FillStyle + FillColor |
| SetWriteMode               | SetWriteMode (ripdraw)         | ripdraw.pas   | wrapper exists           |
| SetTextStyle               | SetTextStyle (riptext)         | riptext.pas   | wrapper exists           |
| SetTextJustify             | rip1exec state                 | rip1exec.pas  | direct field access      |
| SetUserCharSize            | FontScales[] (riptext)         | riptext.pas   | float lookup vs mul/div  |
| SetViewPort                | SetViewport (ripdraw)          | ripdraw.pas   | wrapper exists           |
| SetPalette                 | rcSetPalette (rip1exec)        | rip1exec.pas  | !|Q — full 16-color      |
| OnePalette                 | rcOnePalette (rip1exec)        | rip1exec.pas  | !|a — single entry       |

### 3b. State — Missing Wrappers

ripscript.doc documents proper getter/setter functions. The actual ripview
code has NO wrappers for most — rip1exec.pas writes directly to Canvas fields.

| ripscript.doc API          | ripview code                         | Wrapper exists? |
|----------------------------|--------------------------------------|-----------------|
| SetColor(Color)            | `Canvas.FG := value`                 | NO              |
| GetColor : Byte            | reads `Canvas.FG`                    | NO              |
| SetBkColor(Color)          | `Canvas.BG := value`                 | NO              |
| GetBkColor : Byte          | reads `Canvas.BG`                    | NO              |
| SetFillStyle(Style, Color) | `Canvas.FillStyle := x; Canvas.FillColor := y` | NO   |
| SetFillPattern(Pat, Color) | inline in rip1exec                   | NO              |
| GetFillSettings            | N/A                                  | NO              |
| SetLineStyle(S, P, T)      | SetLineStyle(Style, Thick)           | YES (ripdraw)   |
| GetLineSettings            | N/A                                  | NO              |
| SetWriteMode(Mode)         | SetWriteMode(Mode)                   | YES (ripdraw)   |
| GetWriteMode : Byte        | N/A                                  | NO              |
| SetTextStyle(F, D, S)      | SetTextStyle(Font, Dir, Size)        | YES (riptext)   |
| SetTextJustify(H, V)       | inline in rip1exec                   | NO              |
| MoveTo(X, Y)               | `Canvas.CurX := x; Canvas.CurY := y`| NO              |
| MoveRel(DX, DY)            | `Canvas.CurX += dx; Canvas.CurY += dy` | NO           |
| GetX : SmallInt             | reads `Canvas.CurX`                  | NO              |
| GetY : SmallInt             | reads `Canvas.CurY`                  | NO              |
| SetViewPort(X0,Y0,X1,Y1)  | SetViewport(X1,Y1,X2,Y2)            | YES (ripdraw)   |
| GetViewPort                | N/A                                  | NO              |
| SetPalette(Idx, Color)     | SetPalette(Index, RGB)               | YES (ripdraw)   |
| SetAllPalette(Pal)         | inline loop in rip1exec (rcSetPalette) | NO            |
| GetPalette                 | N/A                                  | NO              |

Wrappers that exist: SetLineStyle, SetWriteMode, SetTextStyle, SetViewport, SetPalette (5 of 20)
Missing wrappers: 15

The executor took a shortcut — direct Canvas field access instead of
wrapper functions. This makes the v2-v4 port harder because every
direct access is a coupling point.

**Recommendation:** Add the missing 15 wrappers. Keeps the API clean,
matches the docs, and makes the v2-v4 port straightforward.

## 4. Mouse / Buttons

All present in ripview under different names from ripscript.doc.

| ripscript.doc name              | ripview name                     | Unit          |
|---------------------------------|----------------------------------|---------------|
| AddMouseField(X0,Y0,X1,Y1,...) | rcMouse dispatch                 | rip1exec.pas  |
| KillMouseField(Index)           | rcKillMouseFields dispatch       | rip1exec.pas  |
| KillAllMouseFields              | rcKillMouseFields dispatch       | rip1exec.pas  |
| FindMouseField(X, Y)            | not exposed as function          | —             |
| GetMouseCount                   | not exposed as function          | —             |
| GetMouseField(Index)            | not exposed as function          | —             |
| SetButtonStyle(Style)           | rcButtonStyle — BtnStyle record  | rip1exec.pas  |
| DrawButton(X0,Y0,X1,Y1,...)    | rcButton — full bevel renderer   | rip1exec.pas  |
| DrawButtonEx                    | not implemented                  | —             |
| ClickButton(Index)              | not implemented                  | —             |
| FindButtonByHotkey(Key)         | not implemented                  | —             |
| GetNextTabField                 | not implemented                  | —             |
| GetPrevTabField                 | not implemented                  | —             |
| FocusField(Index)               | not implemented                  | —             |
| UnfocusField                    | not implemented                  | —             |
| GetFocusedField                 | not implemented                  | —             |
| InvertRegion(X0,Y0,X1,Y1)      | not implemented                  | —             |

Core mouse fields and button rendering work. Missing: query functions
(FindMouseField, GetMouseCount, GetMouseField), interactive button
functions (ClickButton, FindButtonByHotkey, tab navigation, focus),
DrawButtonEx, and InvertRegion.

## 5. Icons

| ripscript.doc name               | ripview name                  | Unit          |
|----------------------------------|-------------------------------|---------------|
| LoadIcon(File, X, Y, Mode)       | rcLoadIcon dispatch           | rip1exec.pas  |
| SaveIcon(File, X0, Y0, X1, Y1)  | rcWriteIcon dispatch          | rip1exec.pas  |
| LoadMask(File, X, Y)             | not implemented               | —             |
| LoadIconMasked(Icon, Mask, X, Y) | not implemented               | —             |
| LoadHotIcon(File, X, Y)          | not implemented               | —             |

Basic icon load/save works. Missing: mask and hot-icon operations.

## 6. Image Operations

| ripscript.doc name               | ripview name                    | Unit          |
|----------------------------------|---------------------------------|---------------|
| GetImage(X0, Y0, X1, Y1, Buf)   | rcGetImage — CapturedImage rec  | rip1exec.pas  |
| PutImage(X, Y, Buf, Mode)        | rcPutImage — CapturedImage rec  | rip1exec.pas  |
| ImageSize(X0, Y0, X1, Y1)        | implicit in CapturedImage       | rip1exec.pas  |
| ClearScreen                      | InitCanvas                      | ripengine.pas |
| ClearViewport                    | rcEraseView                     | rip1exec.pas  |
| CopyRegion(X0,Y0,X1,Y1,DestY)   | not implemented                 | —             |

GetImage/PutImage work but use a fixed CapturedImage record instead of
the BGI-style dynamic buffer. CopyRegion is missing.

## 7. Scene / Export

| ripscript.doc name               | ripview name                  | Unit          |
|----------------------------------|-------------------------------|---------------|
| SaveBMP(FileName)                | SaveBMP                       | ripbmp.pas    |
| LoadScene(FileName)              | not exposed as function       | —             |
| SaveScene(FileName)              | not exposed as function       | —             |
| LoadPCX(File, X, Y)              | not implemented               | —             |
| LoadBMP(File, X, Y)              | not implemented               | —             |

## 8. Screen State Save/Restore

| ripscript.doc name     | ripview name      | Notes              |
|------------------------|-------------------|--------------------|
| SaveScreen(Slot)       | not implemented   |                    |
| RestoreScreen(Slot)    | not implemented   |                    |
| SaveTextWin            | not implemented   |                    |
| RestoreTextWin         | not implemented   |                    |
| SaveMouseAll           | not implemented   |                    |
| RestoreMouseAll        | not implemented   |                    |
| SaveClip               | not implemented   | PushViewport covers this |
| RestoreClip            | not implemented   | PopViewport covers this  |
| SaveAll                | not implemented   |                    |
| RestoreAll             | not implemented   |                    |

None of the save/restore functions exist. The PushViewport/PopViewport
extension (section 12) partially covers SaveClip/RestoreClip.

## 9. Text Variables

| ripscript.doc name     | ripview name      | Notes              |
|------------------------|-------------------|--------------------|
| DefineVar              | not implemented   |                    |
| GetVar                 | not implemented   |                    |
| SetVar                 | not implemented   |                    |
| FindVar                | not implemented   |                    |
| KillAllVars            | not implemented   |                    |
| SaveVars               | not implemented   |                    |
| LoadVars               | not implemented   |                    |
| ResolveVar             | not implemented   |                    |
| ExpandVars             | not implemented   |                    |

Entire text variable system is missing from ripview. ripscript.doc
documents 43 pre-defined variables and full persistence.

## 10. Text / Font

| ripscript.doc name            | ripview name                | Unit          |
|-------------------------------|-----------------------------|---------------|
| OutTextXY(X, Y, S)           | OutTextXY(X, Y, S)          | riptext.pas   |
| OutText(S)                    | OutText(S)                  | riptext.pas   |
| DrawTextCHR(X, Y, S, F, Sz)  | DrawCHRChar (per-char only) | riptext.pas   |
| TextWidth(S)                  | TextWidth(S)                | riptext.pas   |
| TextHeight                    | TextHeight                  | riptext.pas   |
| LoadCHR(Num, File)            | LoadCHRFont(Num)            | riptext.pas   |
| GetSysFontW                   | not exposed as function     | —             |
| GetSysFontH                   | not exposed as function     | —             |
| GetSysCols                    | not exposed as function     | —             |
| GetSysRows                    | not exposed as function     | —             |

Text output works. CHR font loading has different API (no filename param,
uses built-in paths). System font metrics not exposed as functions.

## 11. Display Mode (BGI-specific — N/A for pixel buffer)

These exist in ripscript.doc because it documents the BGI-compatible API.
They do not apply to a pixel buffer renderer and should NOT be implemented.

| ripscript.doc name     | Status  |
|------------------------|---------|
| SetGraphMode           | N/A     |
| GetGraphMode           | N/A     |
| RestoreCrtMode         | N/A     |
| GraphDefaults          | N/A     |
| SetAspectRatio         | N/A     |
| SetActivePage          | N/A     |
| SetVisualPage          | N/A     |
| GetMaxX / GetMaxY      | hardcoded 639/349 |

## 12. Missing Viewer UI Extensions

8 functions needed for ripview interactive UI. These are NOT protocol
commands — they are composites of existing drawing primitives.

New unit: `ripui.pas` in `mystic_ripview/source/`
Dependencies: ripengine, ripdraw, riptext

### Extension Function List

| Function         | What                                         |
|------------------|----------------------------------------------|
| DrawBox          | Bordered window with optional title           |
| OutTextShadow    | Text with 1px drop shadow                     |
| FillGradient     | Rectangle with interpolated color gradient    |
| PushViewport     | Save current viewport, set new                |
| PopViewport      | Restore previous viewport                     |
| DrawProgress     | Percentage bar with border                    |
| FadeOut          | Palette fade to black over N steps            |
| FadeIn           | Palette fade from black over N steps          |

### Stub Code

```pascal
Unit ripui;

{$MODE DELPHI}
{$H-}

Interface

Procedure DrawBox       (X1, Y1, X2, Y2: Integer;
                         Title: String; BorderColor, FillColor: Byte);
Procedure OutTextShadow (X, Y: Integer; S: String;
                         FgColor, ShadowColor: Byte);
Procedure FillGradient  (X1, Y1, X2, Y2: Integer;
                         StartColor, EndColor: Byte);
Procedure PushViewport  (X1, Y1, X2, Y2: Integer);
Procedure PopViewport;
Procedure DrawProgress  (X1, Y1, X2, Y2, Percent: Integer;
                         FgColor, BgColor: Byte);
Procedure FadeOut       (Steps: Word);
Procedure FadeIn        (Steps: Word);

Implementation

Uses ripengine, ripdraw, riptext;

Const
  MaxViewportStack = 8;

Var
  VPStack : Array[0..MaxViewportStack - 1] Of Record
    X1, Y1, X2, Y2 : Integer;
  End;
  VPTop       : Integer;
  SavedPalette: Array[0..15] Of LongWord;
  PalSaved    : Boolean;

Procedure DrawBox(X1, Y1, X2, Y2: Integer;
  Title: String; BorderColor, FillColor: Byte);
Begin
  { FillRect interior }
  FillRect(X1, Y1, X2, Y2, FillColor);
  { DrawRect border }
  DrawRect(X1, Y1, X2, Y2, BorderColor);
  { OutTextXY title centered on top edge }
  If Length(Title) > 0 Then
    OutTextXY(X1 + (X2 - X1 - TextWidth(Title)) Div 2, Y1 + 2, Title);
End;

Procedure OutTextShadow(X, Y: Integer; S: String;
  FgColor, ShadowColor: Byte);
Begin
  Canvas.FG := ShadowColor;
  OutTextXY(X + 1, Y + 1, S);
  Canvas.FG := FgColor;
  OutTextXY(X, Y, S);
End;

Procedure FillGradient(X1, Y1, X2, Y2: Integer;
  StartColor, EndColor: Byte);
Var
  I, H : Integer;
  C    : Byte;
Begin
  H := Y2 - Y1;
  If H <= 0 Then Exit;
  For I := 0 To H Do Begin
    C := StartColor + Byte(((EndColor - StartColor) * I) Div H);
    DrawLine(X1, Y1 + I, X2, Y1 + I, C);
  End;
End;

Procedure PushViewport(X1, Y1, X2, Y2: Integer);
Begin
  If VPTop >= MaxViewportStack Then Exit;
  VPStack[VPTop].X1 := Canvas.ViewX1;
  VPStack[VPTop].Y1 := Canvas.ViewY1;
  VPStack[VPTop].X2 := Canvas.ViewX2;
  VPStack[VPTop].Y2 := Canvas.ViewY2;
  Inc(VPTop);
  SetViewport(X1, Y1, X2, Y2);
End;

Procedure PopViewport;
Begin
  If VPTop <= 0 Then Exit;
  Dec(VPTop);
  SetViewport(VPStack[VPTop].X1, VPStack[VPTop].Y1,
              VPStack[VPTop].X2, VPStack[VPTop].Y2);
End;

Procedure DrawProgress(X1, Y1, X2, Y2, Percent: Integer;
  FgColor, BgColor: Byte);
Var
  FillX : Integer;
Begin
  If Percent < 0   Then Percent := 0;
  If Percent > 100 Then Percent := 100;
  FillRect(X1, Y1, X2, Y2, BgColor);
  FillX := X1 + ((X2 - X1) * Percent) Div 100;
  If FillX > X1 Then
    FillRect(X1, Y1, FillX, Y2, FgColor);
  DrawRect(X1, Y1, X2, Y2, FgColor);
End;

Procedure FadeOut(Steps: Word);
Var
  S, I   : Integer;
  R, G, B: Byte;
  C      : LongWord;
Begin
  If Not PalSaved Then Begin
    Move(Canvas.Palette, SavedPalette, SizeOf(SavedPalette));
    PalSaved := True;
  End;
  For S := Steps DownTo 0 Do Begin
    For I := 0 To 15 Do Begin
      C := SavedPalette[I];
      R := Byte(((C        And $FF) * S) Div Steps);
      G := Byte((((C Shr 8) And $FF) * S) Div Steps);
      B := Byte((((C Shr 16) And $FF) * S) Div Steps);
      SetPalette(I, R Or (G Shl 8) Or (B Shl 16));
    End;
  End;
End;

Procedure FadeIn(Steps: Word);
Var
  S, I   : Integer;
  R, G, B: Byte;
  C      : LongWord;
Begin
  If Not PalSaved Then Exit;
  For S := 0 To Steps Do Begin
    For I := 0 To 15 Do Begin
      C := SavedPalette[I];
      R := Byte(((C        And $FF) * S) Div Steps);
      G := Byte((((C Shr 8) And $FF) * S) Div Steps);
      B := Byte((((C Shr 16) And $FF) * S) Div Steps);
      SetPalette(I, R Or (G Shl 8) Or (B Shl 16));
    End;
  End;
  PalSaved := False;
End;

Initialization
  VPTop    := 0;
  PalSaved := False;

End.
```

## 13. Extra ripview Units (no ripstd equivalent)

These are scene codec units for progressive rendering.

| Unit             | Lines | What                                    |
|------------------|-------|-----------------------------------------|
| ripdecraw.pas    | 444   | R1: RIP stream incremental parser       |
| ripbindec.pas    | 338   | R2: Binary scene file decoder           |
| riptile.pas      | 366   | R3: Tile-based scene splitter           |
| riplayerdec.pas  | 290   | R4: Layer-based scene decoder           |
| ripdelta.pas     | 324   | R5: Delta/diff patch decoder            |
| riprender.pas    | 186   | Unified progressive renderer            |
| rip_compat.pas   | 198   | OOP→procedural adapter                  |

## 14. Parser Comparison

| Component         | ripstd             | ripview                    |
|-------------------|--------------------|----------------------------|
| Command parser    | 887 lines          | rip1parse.pas (163)        |
| Command executor  | 1096 lines         | rip1exec.pas (848)         |
| Combined          | 1,983 lines        | 1,011 lines                |
| MegaNum           | 53 lines (separate)| inline in rip1parse.pas    |
| Command ID table  | 181 lines (separate)| enum in rip1parse.pas     |

ripview is ~50% smaller because it uses a flat case statement instead of
a two-pass parse (identify command, extract params, execute).

## 15. Whitepaper Inventory

After renaming (session 10):

| Filename                                         | Scope | Copies | Locations                              |
|--------------------------------------------------|-------|--------|----------------------------------------|
| IRC-WHITEPAPER.md                                | v1    | 1      | repo root                              |
| IRC-WHITEPAPER.md                                | v1    | 1      | attic/rip_v1_homebrew/ (234-line, retired) |
| ripscrip-v3-implementation-whitepaper.htm        | v3    | 4+     | mystic/mdl/m_rip/v3/, v4/; mystic_test/; attic/ |
| ripscrip-v4irc-implementation-whitepaper.htm     | v4    | 4      | mystic_ripview/, todo/ripscrip/, attic/ (x2) |
| RIPScrip-3.x-technical-whitepaper.txt            | ref   | 2      | attic/ and todo/ historical/           |
| ripscript_whitepaper3_and_older.zip              | ref   | 2      | attic/ and todo/ historical/           |

## 16. API Doc Inventory

Per-version API reference docs (not whitepapers):

| File          | Scope | Location                    |
|---------------|-------|-----------------------------|
| ripscript.doc | v1    | mystic/mdl/m_rip/v1/        |
| rip2api.doc   | v2    | mystic/mdl/m_rip/v2/        |
| rip3api.doc   | v3    | mystic/mdl/m_rip/v3/        |
| rip4api.doc   | v4    | mystic/mdl/m_rip/v4/        |

Each has .doc, .txt, and .htm variants. Same content, different formats.

## 17. m_output_graph.pas vs m_output_rip.pas (VIPEngine)

Both archived in `attic/rip_v1_homebrew/`. They are NOT the same engine —
they go in opposite directions.

### m_output_graph.pas (67 lines)

Text-to-pixel paint hook. One function: `GraphPaintBuffer`.
Takes a `TConsoleScreenRec` (80x25 text buffer with char+attribute pairs)
and paints each character cell as 8x8 pixels using Font8x8 and ptcgraph
PutPixel. Depends on ptcgraph (X11 on Linux — the reason it was archived).

Direction: **text buffer → pixels** (display text console as graphics)

### m_output_rip.pas (222 lines)

Standalone 640x350 pixel framebuffer class (`TOutputRip`). Has its own
pixel buffer, EGA palette, PutPixel/GetPixel, SaveBMP export, and
BlitToConsole (maps pixels back to text cells for terminal display).

Direction: **pixels → text buffer** (display RIP graphics as text) +
standalone pixel canvas operations

### What happens when RIP is detected

Following g00r00's m_output pattern (`m_output.pas` uses ifdefs to select
`TOutputLinux`, `TOutputWindows`, `TOutputDarwin`, `TOutputCRT`), RIP mode
adds `TOutputRip` as a member of the output class. The text pipeline stays
active (the text window inside RIP still needs it), and `TOutputRip`
handles the pixel buffer alongside it.

`ShowBuffer` checks if RIP mode is active:
- RIP OFF: normal text path — `WriteLineRec` / ANSI escape sequences
- RIP ON: pixel blit path — `TOutputRip.BlitToConsole` for terminal
  display, or `GraphPaintBuffer` for VGA display on DOS

The VIPEngine wraps both units:
- `m_output_rip.pas` becomes the pixel canvas (PutPixel, GetPixel, palette)
- `m_output_graph.pas` logic becomes the DOS VGA display path (Phase 3)
- `BlitToConsole` becomes the Linux/terminal display path
- `SaveBMP` stays for headless/ripview export

### Resurrection plan (Phase 0 FIX-1)

1. Copy `m_output_rip.pas` out of attic — this is the VIPEngine core
2. Strip ptcgraph from `m_output_graph.pas` — replace with FPC Graph
   under `{$IFDEF DOS}`, keep pixel buffer path under `{$ELSE}`
3. Wire into m_output.pas selector: `{$IFDEF RIP}` adds TOutputRip
4. `ShowBuffer` gets RIP mode check
5. Rename TOutputRip → VIPEngine class

### evga note

evga is also working on this integration path (SIO driver, Mystic
monitor, RIPView engine). Coordinate before making changes.

## TODO Summary

| # | Item                                              | Priority |
|---|---------------------------------------------------|----------|
| 1 | Update v4irc whitepaper with HTML1 API            | HIGH     |
| 2 | Fix drawing name mismatches in ripscript.doc      | HIGH     |
| 3 | Add 15 missing state wrapper functions            | HIGH     |
| 4 | Add missing mouse query/interactive functions     | MEDIUM   |
| 5 | Add missing icon mask/hot-icon functions          | MEDIUM   |
| 6 | Add CopyRegion                                    | MEDIUM   |
| 7 | Add save/restore system (screen, textwin, mouse)  | MEDIUM   |
| 8 | Add text variable system                          | MEDIUM   |
| 9 | Add ripui.pas extensions to ripscript.doc 3.29    | MEDIUM   |
| 10| Add extensions brief to IRC-WHITEPAPER.md         | MEDIUM   |
| 11| Add system font metric functions                  | LOW      |
| 12| Add scene load/save, PCX/BMP loading              | LOW      |
| 13| Port v1 extensions to v2-v4                       | AFTER v1 |

### Port Path

Once v1 is complete:
v1 (ripui.pas) → v2 (rip2ext.pas) → v3 (rip3ext.pas) → v4 (rip4ext.pas)

## 18. RIP Graphics Phases (from mystic/mdl/m_rip/RIP-GRAPHICS-PHASES.md)

### MPL Testing Scripts (Do First)

| Phase | What |
|-------|------|
| MPL-0 | Setup: create mystic.dat, theme.dat, security.dat, users.dat via config scripts |
| MPL-1 | Login test script — automate SysOp login (ACCT-1) |
| MPL-2 | New user creation test (ACCT-2) |
| MPL-3 | Email to SysOp test (ACCT-4) |
| MPL-4 | RIP detection test — !|1Q query + R response |
| MPL-5 | RIP menu test — .rip file sent and rendered |

### Phase 0: VIPER-FIX (FIX-1 — FIX-6)

| Phase | What |
|-------|------|
| FIX-1 | Resurrect m_output_graph.pas from attic, strip ptcgraph |
| FIX-2 | Add {$IFDEF DOS} path using FPC Graph unit |
| FIX-3 | Add {$ELSE} path using pixel buffer (headless/Linux) |
| FIX-4 | Replace ripdraw.pas homebrew calls with m_output_graph calls |
| FIX-5 | Verify: ripview renders BILL.RIP + GOD-CTH.RIP — compare against ripstd |
| FIX-6 | Verify: all three programs compile clean (Linux + DOS cross-compile) |

### Phase 1: Setup (RIP-M1 — RIP-M4)

| Phase | What |
|-------|------|
| RIP-M1 | Create mystic_test/mdl/ with fonts and shared rendering stack |
| RIP-M2 | Create mystic_test/text/rip/ with test .rip display files |
| RIP-M3 | Create RIP-enabled menu (.mnu) that sends .rip files |
| RIP-M4 | Create mystic_test/icons/ with test .ICN icon files |

### Phase 2: Mystic RIP Integration (RIP-M5 — RIP-M10)

| Phase | What | Program |
|-------|------|---------|
| RIP-M5 | Display file resolution: .rip → .ans fallback | mystic_test |
| RIP-M6 | RIP terminal detection: !|1Q00000000 query + R response | mystic_test |
| RIP-M7 | Raw .rip file sending (no ANSI processing, no MCI) | mystic_test |
| RIP-M8 | Test: mterm → mystic, RIP detected, .rip menu displayed | mterm + mystic_test |
| RIP-M9 | Test FlushRIPBuf with actual !| over live TCP | mterm |
| RIP-M10 | MCI codes: \|RI (RIP reset) and \|TE (terminal type) | mystic_test |

### Phase 3: DOS VGA Display (VGA-1 — VGA-9)

| Phase | What | Program |
|-------|------|---------|
| VGA-1 | uses Graph, InitGraph(VGA, VGAMed) under {$IFDEF DOS} | mterm |
| VGA-2 | RIP engine renders to Graph framebuffer | mterm |
| VGA-3 | uses Graph for screen display on DOS | ripview |
| VGA-4 | Screen default on DOS, BMP default on Linux | ripview |
| VGA-5 | uses Graph for server-side RIP preview under {$IFDEF DOS} | mystic_test |
| VGA-6 | Cross-compile all three with fpc264irc | all |
| VGA-7 | Test mterm.exe in DOSBox → telnet → Mystic → RIP on VGA | mterm |
| VGA-8 | Test ripview.exe in DOSBox → .RIP on VGA screen | ripview |
| VGA-9 | Test mystic.exe in DOSBox → sysop sees RIP screens on VGA | mystic_test |

### Phase 4: SDL 1.2 (Future/Maybe)

| Phase | What | Program |
|-------|------|---------|
| SDL-1 | SDL 1.2 display unit for pixel framebuffer | shared |
| SDL-2 | Render to SDL surface under {$IFDEF SDL} | mterm |
| SDL-3 | Render to SDL surface under {$IFDEF SDL} | ripview |
| SDL-4 | Render to SDL surface under {$IFDEF SDL} | mystic_test |
| SDL-5 | Test on Linux — native SDL window, no DOSBox | all |

### UTF-8 Terminal Support

| Phase | What |
|-------|------|
| UTF8-1 | Study Mystic 1.12 UTF-8 implementation in bbs_io.pas |
| UTF8-2 | ESC(U (CP437) / ESC(B (UTF-8) switching in m_output |
| UTF8-3 | UTF-8 font rendering in graphics mode |
| UTF8-4 | UTF-8 terminal auto-detection |

---

# RIP Graphics Phases — mystic_test, mterm, ripview

## MPL Testing Scripts (Do First)

| Phase | What |
|-------|------|
| MPL-0 | Setup: create mystic.dat, theme.dat, security.dat, users.dat via config scripts |
| MPL-1 | Login test script — automate SysOp login (ACCT-1) |
| MPL-2 | New user creation test (ACCT-2) |
| MPL-3 | Email to SysOp test (ACCT-4) |
| MPL-4 | RIP detection test — !|1Q query + R response |
| MPL-5 | RIP menu test — .rip file sent and rendered |

## Phase 0: VIPER-FIX (FIX-1 — FIX-6)

| Phase | What |
|-------|------|
| FIX-1 | Resurrect m_output_graph.pas from attic, strip ptcgraph |
| FIX-2 | Add {$IFDEF DOS} path using FPC Graph unit |
| FIX-3 | Add {$ELSE} path using pixel buffer (headless/Linux) |
| FIX-4 | Replace ripdraw.pas homebrew calls with m_output_graph calls |
| FIX-5 | Verify: ripview renders BILL.RIP + GOD-CTH.RIP — compare against ripstd |
| FIX-6 | Verify: all three programs compile clean (Linux + DOS cross-compile) |

## Phase 1: Setup (RIP-M1 — RIP-M4)

| Phase | What |
|-------|------|
| RIP-M1 | Create mystic_test/mdl/ with fonts and shared rendering stack |
| RIP-M2 | Create mystic_test/text/rip/ with test .rip display files |
| RIP-M3 | Create RIP-enabled menu (.mnu) that sends .rip files |
| RIP-M4 | Create mystic_test/icons/ with test .ICN icon files |

## Phase 2: Mystic RIP Integration (RIP-M5 — RIP-M10)

| Phase | What | Program |
|-------|------|---------|
| RIP-M5 | Display file resolution: .rip → .ans fallback | mystic_test |
| RIP-M6 | RIP terminal detection: !|1Q00000000 query + R response | mystic_test |
| RIP-M7 | Raw .rip file sending (no ANSI processing, no MCI) | mystic_test |
| RIP-M8 | Test: mterm → mystic, RIP detected, .rip menu displayed | mterm + mystic_test |
| RIP-M9 | Test FlushRIPBuf with actual !| over live TCP | mterm |
| RIP-M10 | MCI codes: \|RI (RIP reset) and \|TE (terminal type) | mystic_test |

## Phase 3: DOS VGA Display (VGA-1 — VGA-9)

| Phase | What | Program |
|-------|------|---------|
| VGA-1 | uses Graph, InitGraph(VGA, VGAMed) under {$IFDEF DOS} | mterm |
| VGA-2 | RIP engine renders to Graph framebuffer | mterm |
| VGA-3 | uses Graph for screen display on DOS | ripview |
| VGA-4 | Screen default on DOS, BMP default on Linux | ripview |
| VGA-5 | uses Graph for server-side RIP preview under {$IFDEF DOS} | mystic_test |
| VGA-6 | Cross-compile all three with fpc264irc | all |
| VGA-7 | Test mterm.exe in DOSBox → telnet → Mystic → RIP on VGA | mterm |
| VGA-8 | Test ripview.exe in DOSBox → .RIP on VGA screen | ripview |
| VGA-9 | Test mystic.exe in DOSBox → sysop sees RIP screens on VGA | mystic_test |

## Phase 4: SDL 1.2 (Future/Maybe)

| Phase | What | Program |
|-------|------|---------|
| SDL-1 | SDL 1.2 display unit for pixel framebuffer | shared |
| SDL-2 | Render to SDL surface under {$IFDEF SDL} | mterm |
| SDL-3 | Render to SDL surface under {$IFDEF SDL} | ripview |
| SDL-4 | Render to SDL surface under {$IFDEF SDL} | mystic_test |
| SDL-5 | Test on Linux — native SDL window, no DOSBox | all |

## UTF-8 Terminal Support

| Phase | What |
|-------|------|
| UTF8-1 | Study Mystic 1.12 UTF-8 implementation in bbs_io.pas |
| UTF8-2 | ESC(U (CP437) / ESC(B (UTF-8) switching in m_output |
| UTF8-3 | UTF-8 font rendering in graphics mode |
| UTF8-4 | UTF-8 terminal auto-detection |

## Font and VGA Resources

### rip_font*.inc — Compile-Time Font Data

IBM VGA BIOS ROM font data compiled as Pascal typed constants. Used by
riptext.pas to render text characters in the 640x350 pixel buffer.
Source: spacerace/romfont ROM dumps.

| File              | Size    | Glyph | Glyphs | Charset |
|-------------------|---------|-------|--------|---------|
| rip_font8x8.inc   | 2048 B  | 8x8   | 256    | CP437   |
| rip_font8x14.inc  | 3584 B  | 8x14  | 256    | CP437   |
| rip_font8x16.inc  | 4096 B  | 8x16  | 256    | CP437   |

Canonical location: mystic/mdl/m_rip/ and mystic_test/mdl/m_rip/

Verification keys:
- char 219 (block) = all $FF (solid block)
- char 65 (A) = $30,$78,$CC,$CC,$FC,$CC,$CC,$00 (8x8)

These are included at compile time via {$I rip_font8x8.inc} in riptext.pas.
No runtime file loading needed — the font data is baked into the binary.

### VGA8X16.FNT — Runtime Font File

Same IBM VGA 8x16 font data as rip_font8x16.inc but as a standalone
binary file (raw 4096 bytes, no Pascal wrapper). Loaded at runtime by
mystic_sdl and m_output for console screen rendering.

Canonical location: mystic/mdl/m_rip/VGA8X16.FNT and
mystic_test/mdl/m_rip/VGA8X16.FNT

Stray copies in mystic/mdl/ and mystic_test/mdl/ (outside m_rip/)
are removed by cleanup.bat.

### Why Both Exist

The .inc files serve the RIP engine (compile-time, no file I/O needed,
works on headless Linux and DOS). The .FNT file serves the display system
(runtime, loaded by SDL and console output drivers that need the font
independently of the RIP engine).

Both come from the same ROM dump. Same bytes, different packaging.

## Repositories and Build

- Source: https://github.com/verta1878/MysticIRC
- Compiler: https://github.com/verta1878/fpc264irc (required, sibling directory)

### Linux Build

Drop build-linux.sh in repo root, chmod +x, then:

    ./build-linux.sh x64 test    <- mystic_test 16/16
    ./build-linux.sh x64         <- mystic stable 16/16

Compiler expected at ../fpc264irc/bin/ppcx64 (x86_64) or ../fpc264irc/bin/ppc386 (i386).

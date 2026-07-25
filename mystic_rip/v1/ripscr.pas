unit ripscr;

// ====================================================================
// RIPscrip v1.54 Graphics Protocol Engine for Mystic BBS
// ====================================================================
//
// A server-side RIPscrip engine using Borland BGI-compatible primitives.
// This unit parses RIPscrip commands and renders them through the BGI
// graphics interface, handling:
//
//   - All Level 0 drawing commands (lines, rects, circles, fills, etc)
//   - Level 1 mouse fields, buttons, icons, text regions
//   - BGI CHR font rendering
//   - EGA/VGA palette management
//   - MegaNum (base-36) number encoding
//   - Line continuation (backslash at EOL)
//   - Fill patterns and line styles
//
// The engine operates server-side: instead of sending raw RIP codes
// to the terminal, Mystic renders them internally and sends the
// resulting screen image as ANSI or bitmap data.
//
// Reference: RIPscrip v1.54 Specification
//
// This file is part of Mystic BBS.
// Licensed under the GNU General Public License v3.
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
// ====================================================================

Interface

{$H-}  // Use ShortStrings — AnsiStrings cause stack overflow in FPC 2.6.4

Const
  // Engine version
  RIP_ENGINE_VERSION = '1.0.0';
  RIP_ENGINE_DATE    = '2026-07-19';

  RIP_MAX_X       = 639;       // EGA/VGA 640x350 default
  RIP_MAX_Y       = 349;
  RIP_MAX_COLORS  = 16;        // EGA palette
  RIP_MAX_MOUSE   = 128;       // max mouse fields
  RIP_MAX_BUTTONS = 64;        // max buttons
  RIP_MAX_POLY    = 512;       // max polygon points
  RIP_MAX_VARS    = 64;        // max text variables
  RIP_MAX_CHR_CHARS = 256;    // max chars in a CHR font
  RIP_MAX_STROKES = 9216;     // max stroke commands per font (largest: GOTH=8625)

  // Fill styles (BGI compatible)
  RIP_FILL_EMPTY     = 0;
  RIP_FILL_SOLID     = 1;
  RIP_FILL_LINE      = 2;
  RIP_FILL_LTSLASH   = 3;
  RIP_FILL_SLASH     = 4;
  RIP_FILL_BKSLASH   = 5;
  RIP_FILL_LTBKSLASH = 6;
  RIP_FILL_HATCH     = 7;
  RIP_FILL_XHATCH    = 8;
  RIP_FILL_INTERLEAVE = 9;
  RIP_FILL_WIDEDOT   = 10;
  RIP_FILL_CLOSEDOT  = 11;
  RIP_FILL_USER      = 12;

  // Line styles (BGI compatible)
  RIP_LINE_SOLID     = 0;
  RIP_LINE_DOTTED    = 1;
  RIP_LINE_CENTER    = 2;
  RIP_LINE_DASHED    = 3;
  RIP_LINE_USER      = 4;

  // Write modes (BGI compatible)
  RIP_COPY_PUT    = 0;
  RIP_XOR_PUT     = 1;

  // Font directions
  RIP_HORIZ_DIR   = 0;
  RIP_VERT_DIR    = 1;

  // Text justification
  RIP_LEFT_TEXT   = 0;
  RIP_CENTER_TEXT = 1;
  RIP_RIGHT_TEXT  = 2;
  RIP_BOTTOM_TEXT = 0;
  RIP_TOP_TEXT    = 2;

  // Font numbers (BGI)
  RIP_DEFAULT_FONT  = 0;  // 8x8 bitmap
  RIP_TRIPLEX_FONT  = 1;
  RIP_SMALL_FONT    = 2;
  RIP_SANSSERIF_FONT = 3;

  // System font modes (TextWinSize / RIP_TEXT_WINDOW size param)
  RIP_SYSFONT_80x43 = 0;   // 8x8 font,  80 cols, 43 rows (default EGA)
  RIP_SYSFONT_80x25 = 1;   // 8x14 font, 80 cols, 25 rows
  RIP_SYSFONT_40x25 = 2;   // 16x14 font, 40 cols, 25 rows (double-width)
  RIP_SYSFONT_91x43 = 3;   // 7x8 font,  91 cols, 43 rows
  RIP_SYSFONT_91x25 = 4;   // 7x14 font, 91 cols, 25 rows
  RIP_GOTHIC_FONT   = 4;

Type
  TRIPColor = Byte;

  TRIPPoint = Record
    X, Y : SmallInt;
  End;

  TRIPPalette = Array[0..RIP_MAX_COLORS-1] of Byte;

  TRIPFillPattern = Array[0..7] of Byte;  // 8x8 user fill pattern

  TRIPMouseField = Record
    Active  : Boolean;
    X0, Y0  : SmallInt;
    X1, Y1  : SmallInt;
    HostCmd : String[80];   // command sent to host on click
    Text    : String[80];   // status bar text
    Invert  : Boolean;      // invert region on click
    IsButton  : Boolean;    // Phase 2: this is a button, not just a region
    IsRadio   : Boolean;    // Phase 2: radio button (one per group)
    IsCheckbox : Boolean;   // Phase 2: checkbox (toggle)
    GroupID   : Byte;       // Phase 2: button group for radio buttons
    Selected  : Boolean;    // Phase 2: currently selected/checked
    IconFile  : String[80]; // Phase 2: normal icon filename
    HotIconFile : String[80]; // Phase 2: highlighted/selected icon filename
    HotKey    : Char;       // Phase 5: keyboard shortcut character
    TabIndex  : Integer;    // Phase 5: tab navigation order (0=not tabbable)
  End;

  TRIPVariable = Record
    Active   : Boolean;
    Name     : String[12];    // 1-12 char identifier
    Value    : String[255];   // variable value
    Persist  : Boolean;       // save to database (flag 001)
    Required : Boolean;       // cannot be blank (flag 002)
  End;

  TRIPFileQueryResult = Record
    Exists : Boolean;
    Size   : LongInt;
    Date   : String[10];
    Time   : String[8];
  End;

  TRIPStroke = Record
    Op : Byte;    // 0=end, 1=move, 2=draw
    X  : SmallInt;
    Y  : SmallInt;
  End;

  TRIPCHRFont = Record
    Loaded    : Boolean;
    Name      : String[4];
    FirstChar : Byte;
    NumChars  : Word;
    OrgToCap  : SmallInt;   // top of capital letters
    OrgToBase : SmallInt;   // baseline
    OrgToDec  : SmallInt;   // descender
    Widths    : Array[0..RIP_MAX_CHR_CHARS-1] of Byte;
    Offsets   : Array[0..RIP_MAX_CHR_CHARS-1] of Word;
    Strokes   : Array[0..RIP_MAX_STROKES-1] of TRIPStroke;
    NumStrokes : Word;
  End;
  PRIPCHRFont = ^TRIPCHRFont;

  TRIPButtonStyle = Record
    Width     : SmallInt;
    Height    : SmallInt;
    Orient    : Byte;       // 0=horizontal, 1=vertical
    Flags     : Word;
    BevelSize : Byte;
    DFore     : Byte;       // dark foreground
    DBack     : Byte;       // dark background
    BRight    : Byte;       // bright color
    DDark     : Byte;       // dark shadow
    Surface   : Byte;       // surface color
    GrpID     : Byte;       // button group
    Flags2    : Byte;
    ULineCol  : Byte;       // underline color
    CornerCol : Byte;       // corner color
  End;

  // EGA palette RGB values for rendering to true-color output
  TRIPRgb = Record
    R, G, B : Byte;
  End;

Const
  // Standard EGA palette — maps color index 0..15 to RGB
  EGA_RGB : Array[0..15] of TRIPRgb = (
    (R:$00;G:$00;B:$00),
    (R:$00;G:$00;B:$AA),
    (R:$00;G:$AA;B:$00),
    (R:$00;G:$AA;B:$AA),
    (R:$AA;G:$00;B:$00),
    (R:$AA;G:$00;B:$AA),
    (R:$AA;G:$55;B:$00),
    (R:$AA;G:$AA;B:$AA),
    (R:$55;G:$55;B:$55),
    (R:$55;G:$55;B:$FF),
    (R:$55;G:$FF;B:$55),
    (R:$55;G:$FF;B:$FF),
    (R:$FF;G:$55;B:$55),
    (R:$FF;G:$55;B:$FF),
    (R:$FF;G:$FF;B:$55),
    (R:$FF;G:$FF;B:$FF)
  );

Type
  // ----------------------------------------------------------------
  // Pixel buffer — the rendered RIP image
  // ----------------------------------------------------------------
  TRIPPixelBuffer = Array[0..RIP_MAX_Y, 0..RIP_MAX_X] of Byte;
  PRIPPixelBuffer = ^TRIPPixelBuffer;

  // ----------------------------------------------------------------
  // TRIPEngine — main RIPscrip parser and renderer
  // ----------------------------------------------------------------
  TRIPEngine = Class
  Private
    // Graphics state
    CurX, CurY     : SmallInt;   // current position (CP)
    DrawColor      : TRIPColor;
    FillColor      : TRIPColor;
    FillStyle      : Byte;
    FillPat        : TRIPFillPattern;
    LineStyle      : Byte;
    LineThick      : Byte;
    LinePattern    : Word;       // user line pattern
    WriteMode      : Byte;       // COPY_PUT or XOR_PUT

    // Text state
    FontNum        : Byte;
    FontDir        : Byte;       // 0=horiz, 1=vert
    FontSize       : Byte;       // character magnification
    FontHJust      : Byte;       // horizontal justification
    FontVJust      : Byte;       // vertical justification

    // Windows
    TextWinX0      : SmallInt;
    TextWinY0      : SmallInt;
    TextWinX1      : SmallInt;
    TextWinY1      : SmallInt;
    TextWinSize    : Byte;       // font size for text window
    ViewX0, ViewY0 : SmallInt;
    ViewX1, ViewY1 : SmallInt;

    // Palette
    Palette        : TRIPPalette;

    // Mouse fields
    MouseFields    : Array[1..RIP_MAX_MOUSE] of TRIPMouseField;
    MouseCount     : Integer;
    NextTabIndex   : Integer;  // Phase 5: auto-incrementing tab order
    FocusedField   : Integer;  // Phase 5: currently focused field (0=none)

    // Button style
    BtnStyle       : TRIPButtonStyle;

    // Text variables
    Variables      : Array[1..RIP_MAX_VARS] of TRIPVariable;
    VarCount       : Integer;

    // CHR vector fonts (loaded on demand)
    CHRFonts       : Array[1..10] of PRIPCHRFont;

    // Screen save slots (0-9), Phase 1
    SavedScreens   : Array[0..9] of PRIPPixelBuffer;

    // Text window save slot, Phase 1
    SavedTW        : Record
      Active : Boolean;
      X0, Y0, X1, Y1 : SmallInt;
      Size   : Byte;
    End;

    // Mouse field save slot, Phase 1/5
    SavedMouse     : Record
      Active       : Boolean;
      Fields       : Array[1..RIP_MAX_MOUSE] of TRIPMouseField;
      Count        : Integer;
      TabIndex     : Integer;
      Focused      : Integer;
    End;

    // Saved clipboard for $SCB$/$RCB$
    SavedClip      : Pointer;
    SavedClipSz    : LongInt;
    SavedClipW     : Word;
    SavedClipH     : Word;

    // Line buffer for continuation
    LineBuf        : String;
    Continued      : Boolean;

    // Parser helpers
    Function  MegaNum       (Var S: String; Var Pos: Integer; Digits: Integer) : LongInt;
    Function  MegaChar      (Ch: Char) : Integer;
    Procedure ParseLevel0   (Cmd: Char; Params: String);
    Procedure ParseLevel1   (Cmd: Char; Params: String);
    Procedure ParseLevel9   (Cmd: Char; Params: String);

    // BGI-compatible drawing primitives
    Procedure DrawPixel     (X, Y: SmallInt; Color: Byte);
    Procedure DrawLine      (X0, Y0, X1, Y1: SmallInt);
    Procedure DrawRect      (X0, Y0, X1, Y1: SmallInt);
    Procedure DrawBar       (X0, Y0, X1, Y1: SmallInt);
    Procedure DrawCircle    (XC, YC, Radius: SmallInt);
    Procedure DrawOval      (XC, YC, XR, YR: SmallInt);
    Procedure DrawFilledOval(XC, YC, XR, YR: SmallInt);
    Procedure DrawArc       (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
    Procedure DrawOvalArc   (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
    Procedure DrawPieSlice  (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
    Procedure DrawOvalPie   (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
    Procedure DrawPolygon   (Var Points: Array of TRIPPoint; Count: Integer);
    Procedure DrawFillPoly  (Var Points: Array of TRIPPoint; Count: Integer);
    Procedure DrawPolyLine  (Var Points: Array of TRIPPoint; Count: Integer);
    Procedure DrawText8x8   (X, Y: SmallInt; S: String);

    // Clipping
    Function  ClipX (X: SmallInt) : SmallInt;
    Function  ClipY (Y: SmallInt) : SmallInt;
    Function  InView(X, Y: SmallInt) : Boolean;

  Public
    Pixels : PRIPPixelBuffer;    // the rendered image
    HotKeysEnabled : Boolean;    // Phase 5: button hotkeys active
    TabEnabled     : Boolean;    // Phase 5: tab navigation active

    // Clipboard (public for viewer access)
    Clipboard      : Pointer;
    ClipSize       : LongInt;
    ClipW, ClipH   : Word;

    Constructor Create;
    Destructor  Destroy; Override;

    // ---- RIP command processing ----
    Procedure ProcessLine   (Line: String);
    Procedure ProcessCommand(Cmd: String);

    // ---- Screen management ----
    Procedure Reset;
    Procedure ClearScreen;
    Procedure ClearViewport;

    // ---- BGI-compatible drawing primitives ----
    Procedure PutPixel      (X, Y: SmallInt; Color: Byte);
    Function  GetPixel      (X, Y: SmallInt) : Byte;
    Procedure Line          (X0, Y0, X1, Y1: SmallInt);
    Procedure LineTo        (X, Y: SmallInt);
    Procedure LineRel       (DX, DY: SmallInt);
    Procedure Rectangle     (X0, Y0, X1, Y1: SmallInt);
    Procedure Bar           (X0, Y0, X1, Y1: SmallInt);
    Procedure Bar3D         (X0, Y0, X1, Y1: SmallInt; Depth: SmallInt; Top: Boolean);
    Procedure Circle        (XC, YC, Radius: SmallInt);
    Procedure Ellipse       (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
    Procedure FillEllipse   (XC, YC, XR, YR: SmallInt);
    Procedure Arc           (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
    Procedure PieSlice      (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
    Procedure Sector        (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
    Procedure DrawBezier    (X0, Y0, X1, Y1, X2, Y2, X3, Y3: SmallInt; Count: SmallInt);
    Procedure DrawPoly      (NumPoints: Integer; Var PolyPoints);
    Procedure FillPoly      (NumPoints: Integer; Var PolyPoints);
    Procedure FloodFill     (X, Y: SmallInt; Border: Byte);

    // ---- Text output ----
    Procedure OutTextXY     (X, Y: SmallInt; S: String);
    Procedure OutText       (S: String);

    // ---- Position ----
    Procedure MoveTo        (X, Y: SmallInt);
    Procedure MoveRel       (DX, DY: SmallInt);
    Function  GetX          : SmallInt;
    Function  GetY          : SmallInt;

    // ---- Color / palette ----
    Procedure SetColor      (Color: Byte);
    Function  GetColor      : Byte;
    Procedure SetBkColor    (Color: Byte);
    Function  GetBkColor    : Byte;
    Procedure SetPalette    (Index, Color: Byte);
    Procedure SetAllPalette (Var Pal: TRIPPalette);
    Procedure GetPalette    (Var Pal: TRIPPalette);

    // ---- Fill ----
    Procedure SetFillStyle  (Style: Word; Color: Byte);
    Procedure SetFillPattern(Var Pattern: TRIPFillPattern; Color: Byte);
    Procedure GetFillSettings(Var Style: Word; Var Color: Byte);

    // ---- Line style ----
    Procedure SetLineStyle  (Style, Pattern, Thick: Word);
    Procedure GetLineSettings(Var Style, Pattern, Thick: Word);

    // ---- Write mode ----
    Procedure SetWriteMode  (Mode: Byte);
    Function  GetWriteMode  : Byte;

    // ---- Text style ----
    Procedure SetTextStyle  (Font, Direction, CharSize: Word);
    Procedure SetTextJustify(Horiz, Vert: Word);

    // ---- Viewport / window ----
    Procedure SetViewPort   (X0, Y0, X1, Y1: SmallInt; Clip: Boolean);
    Procedure GetViewPort   (Var X0, Y0, X1, Y1: SmallInt);
    Procedure SetTextWindow (X0, Y0, X1, Y1: SmallInt; Size: Byte);

    // ---- Mouse fields ----
    Function  AddMouseField (X0, Y0, X1, Y1: SmallInt; HostCmd, Text: String) : Integer;
    Procedure KillMouseField(Index: Integer);
    Procedure KillAllMouseFields;
    Function  FindMouseField(X, Y: SmallInt) : Integer;
    Function  GetMouseCount : Integer;
    Function  GetMouseField (Index: Integer) : TRIPMouseField;

    // ---- Button ----
    Procedure SetButtonStyle(Var Style: TRIPButtonStyle);
    Procedure DrawButton    (X0, Y0, X1, Y1: SmallInt; Label_, HostCmd: String);
    Procedure DrawButtonEx  (X0, Y0, X1, Y1: SmallInt; Label_, HostCmd, IconFile, HotIconFile: String;
                             IsRadio, IsCheckbox, InitSelected: Boolean);
    Procedure ClickButton   (Index: Integer);
    Procedure InvertRegion  (X0, Y0, X1, Y1: SmallInt);

    // ---- Button hotkeys and navigation (Phase 5) ----
    Function  FindButtonByHotkey (Key: Char) : Integer;
    Function  GetNextTabField : Integer;
    Function  GetPrevTabField : Integer;
    Procedure FocusField    (Index: Integer);
    Procedure UnfocusField;
    Function  GetFocusedField : Integer;

    // ---- System font modes (Phase 6) ----
    Function  GetSysFontW : Integer;    // character width in pixels
    Function  GetSysFontH : Integer;    // character height in pixels
    Function  GetSysCols  : Integer;    // text columns for current mode
    Function  GetSysRows  : Integer;    // text rows for current mode

    // ---- Image ----
    Procedure GetImage      (X0, Y0, X1, Y1: SmallInt; Var Buf);
    Procedure PutImage      (X, Y: SmallInt; Var Buf; Mode: Byte);
    Function  ImageSize     (X0, Y0, X1, Y1: SmallInt) : LongInt;

    // ---- Icon ----
    Function  LoadIcon      (FileName: String; X, Y: SmallInt; Mode: Byte) : Boolean;
    Function  SaveIcon      (FileName: String; X0, Y0, X1, Y1: SmallInt) : Boolean;
    Function  LoadMask      (FileName: String; X, Y: SmallInt) : Boolean;
    Function  LoadIconMasked(IconFile, MaskFile: String; X, Y: SmallInt) : Boolean;
    Function  LoadHotIcon   (FileName: String; X, Y: SmallInt) : Boolean;

    // ---- Scene file ----
    Function  LoadScene     (FileName: String) : Boolean;
    Function  SaveScene     (FileName: String) : Boolean;

    // ---- CHR vector fonts ----
    Function  LoadCHR       (AFontNum: Byte; FileName: String) : Boolean;
    Procedure DrawTextCHR   (X, Y: SmallInt; S: String; AFont, ASize: Byte);

    // ---- Export ----
    Function  SaveBMP       (FileName: String) : Boolean;

    // ---- Image loading (Phase 4) ----
    Function  LoadPCX       (FileName: String; X, Y: SmallInt) : Boolean;
    Function  LoadBMP       (FileName: String; X, Y: SmallInt) : Boolean;

    // ---- Text variables (RIP_DEFINE) ----
    Procedure DefineVar     (Name, Value: String; Persist, Required: Boolean);
    Function  GetVar        (Name: String) : String;
    Procedure SetVar        (Name, Value: String);
    Function  FindVar       (Name: String) : Integer;
    Procedure KillAllVars;

    // ---- Pre-defined text variables (Phase 3) ----
    Function  ResolveVar    (Name: String) : String;
    Function  ExpandVars    (S: String) : String;

    // ---- Variable persistence ----
    Function  SaveVars      (FileName: String) : Boolean;
    Function  LoadVars      (FileName: String) : Boolean;

    // ---- File query (RIP_FILE_QUERY) ----
    Function  FileQuery     (FileName: String; Mode: Byte) : TRIPFileQueryResult;

    // ---- Copy region (RIP_COPY_REGION) ----
    Procedure CopyRegion    (X0, Y0, X1, Y1, DestY: SmallInt);

    // ---- Screen save/restore (Phase 1) ----
    Procedure SaveScreen    (Slot: Byte);
    Procedure RestoreScreen (Slot: Byte);
    Procedure SaveTextWin;
    Procedure RestoreTextWin;
    Procedure SaveMouseAll;
    Procedure RestoreMouseAll;
    Procedure SaveClip;
    Procedure RestoreClip;
    Procedure SaveAll;
    Procedure RestoreAll;

    // ---- Dimensions ----
    Function  GetMaxX       : SmallInt;
    Function  GetMaxY       : SmallInt;
    Function  GetWidth      : SmallInt;
    Function  GetHeight     : SmallInt;
  End;

Implementation

{$I rip_font8x8.inc}
{$I rip_font8x14.inc}

// ====================================================================
// MegaNum decoder — base-36 number system
// ====================================================================

Function TRIPEngine.MegaChar (Ch: Char) : Integer;
Begin
  If (Ch >= '0') and (Ch <= '9') Then
    Result := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') and (Ch <= 'Z') Then
    Result := Ord(Ch) - Ord('A') + 10
  Else If (Ch >= 'a') and (Ch <= 'z') Then
    Result := Ord(Ch) - Ord('a') + 10
  Else
    Result := 0;
End;

Function TRIPEngine.MegaNum (Var S: String; Var Pos: Integer; Digits: Integer) : LongInt;
Var
  I : Integer;
Begin
  Result := 0;

  For I := 1 to Digits Do Begin
    If Pos > Length(S) Then Exit;

    Result := Result * 36 + MegaChar(S[Pos]);
    Inc(Pos);
  End;
End;

// ====================================================================
// Clipping helpers
// ====================================================================

Function TRIPEngine.ClipX (X: SmallInt) : SmallInt;
Begin
  If X < ViewX0 Then Result := ViewX0
  Else If X > ViewX1 Then Result := ViewX1
  Else Result := X;
End;

Function TRIPEngine.ClipY (Y: SmallInt) : SmallInt;
Begin
  If Y < ViewY0 Then Result := ViewY0
  Else If Y > ViewY1 Then Result := ViewY1
  Else Result := Y;
End;

Function TRIPEngine.InView (X, Y: SmallInt) : Boolean;
Begin
  Result := (X >= ViewX0) and (X <= ViewX1) and
            (Y >= ViewY0) and (Y <= ViewY1);
End;

// ====================================================================
// Drawing primitives
// ====================================================================

Procedure TRIPEngine.DrawPixel (X, Y: SmallInt; Color: Byte);
Begin
  If Not InView(X, Y) Then Exit;

  Case WriteMode of
    RIP_XOR_PUT : Pixels^[Y, X] := Pixels^[Y, X] XOR Color;
  Else
    Pixels^[Y, X] := Color;
  End;
End;

Procedure TRIPEngine.DrawLine (X0, Y0, X1, Y1: SmallInt);
Var
  DX, DY, SX, SY, Err, E2 : SmallInt;
  PatBit : Integer;
  Pat    : Word;
Begin
  // Select pattern
  Case LineStyle of
    RIP_LINE_DOTTED  : Pat := $CCCC;
    RIP_LINE_CENTER  : Pat := $FC78;
    RIP_LINE_DASHED  : Pat := $F8F8;
    RIP_LINE_USER    : Pat := LinePattern;
  Else
    Pat := $FFFF;  // solid
  End;

  PatBit := 0;

  // Bresenham line algorithm
  DX := Abs(X1 - X0);
  DY := Abs(Y1 - Y0);

  If X0 < X1 Then SX := 1 Else SX := -1;
  If Y0 < Y1 Then SY := 1 Else SY := -1;

  Err := DX - DY;

  While True Do Begin
    // Only draw if pattern bit is set
    If (Pat AND (1 SHL (15 - (PatBit AND 15)))) <> 0 Then
      DrawPixel(X0, Y0, DrawColor);

    Inc(PatBit);

    If (X0 = X1) and (Y0 = Y1) Then Break;

    E2 := 2 * Err;

    If E2 > -DY Then Begin
      Err := Err - DY;
      X0  := X0 + SX;
    End;

    If E2 < DX Then Begin
      Err := Err + DX;
      Y0  := Y0 + SY;
    End;
  End;

  CurX := X1;
  CurY := Y1;
End;

Procedure TRIPEngine.DrawRect (X0, Y0, X1, Y1: SmallInt);
Begin
  DrawLine(X0, Y0, X1, Y0);
  DrawLine(X1, Y0, X1, Y1);
  DrawLine(X1, Y1, X0, Y1);
  DrawLine(X0, Y1, X0, Y0);
End;

Procedure TRIPEngine.DrawBar (X0, Y0, X1, Y1: SmallInt);
Var
  X, Y     : SmallInt;
  PatByte  : Byte;
  FillPats : Array[0..11, 0..7] of Byte;
Begin
  // Built-in fill patterns (BGI compatible)
  // EMPTY
  FillChar(FillPats[0], 8, $00);
  // SOLID
  FillChar(FillPats[1], 8, $FF);
  // LINE (horizontal lines)
  FillPats[2][0] := $FF; FillPats[2][1] := $00; FillPats[2][2] := $00; FillPats[2][3] := $00;
  FillPats[2][4] := $FF; FillPats[2][5] := $00; FillPats[2][6] := $00; FillPats[2][7] := $00;
  // LTSLASH
  FillPats[3][0] := $01; FillPats[3][1] := $02; FillPats[3][2] := $04; FillPats[3][3] := $08;
  FillPats[3][4] := $10; FillPats[3][5] := $20; FillPats[3][6] := $40; FillPats[3][7] := $80;
  // SLASH
  FillPats[4][0] := $03; FillPats[4][1] := $06; FillPats[4][2] := $0C; FillPats[4][3] := $18;
  FillPats[4][4] := $30; FillPats[4][5] := $60; FillPats[4][6] := $C0; FillPats[4][7] := $81;
  // BKSLASH
  FillPats[5][0] := $C0; FillPats[5][1] := $60; FillPats[5][2] := $30; FillPats[5][3] := $18;
  FillPats[5][4] := $0C; FillPats[5][5] := $06; FillPats[5][6] := $03; FillPats[5][7] := $81;
  // LTBKSLASH
  FillPats[6][0] := $80; FillPats[6][1] := $40; FillPats[6][2] := $20; FillPats[6][3] := $10;
  FillPats[6][4] := $08; FillPats[6][5] := $04; FillPats[6][6] := $02; FillPats[6][7] := $01;
  // HATCH
  FillPats[7][0] := $FF; FillPats[7][1] := $01; FillPats[7][2] := $01; FillPats[7][3] := $01;
  FillPats[7][4] := $FF; FillPats[7][5] := $01; FillPats[7][6] := $01; FillPats[7][7] := $01;
  // XHATCH
  FillPats[8][0] := $FF; FillPats[8][1] := $81; FillPats[8][2] := $42; FillPats[8][3] := $24;
  FillPats[8][4] := $FF; FillPats[8][5] := $24; FillPats[8][6] := $42; FillPats[8][7] := $81;
  // INTERLEAVE
  FillPats[9][0] := $AA; FillPats[9][1] := $55; FillPats[9][2] := $AA; FillPats[9][3] := $55;
  FillPats[9][4] := $AA; FillPats[9][5] := $55; FillPats[9][6] := $AA; FillPats[9][7] := $55;
  // WIDEDOT
  FillPats[10][0] := $00; FillPats[10][1] := $00; FillPats[10][2] := $00; FillPats[10][3] := $00;
  FillPats[10][4] := $01; FillPats[10][5] := $00; FillPats[10][6] := $00; FillPats[10][7] := $00;
  // CLOSEDOT
  FillPats[11][0] := $44; FillPats[11][1] := $00; FillPats[11][2] := $11; FillPats[11][3] := $00;
  FillPats[11][4] := $44; FillPats[11][5] := $00; FillPats[11][6] := $11; FillPats[11][7] := $00;

  For Y := ClipY(Y0) to ClipY(Y1) Do Begin
    // Select pattern row
    Case FillStyle of
      RIP_FILL_EMPTY : Continue;  // don't draw anything
      RIP_FILL_SOLID : PatByte := $FF;
      RIP_FILL_USER  : PatByte := FillPat[Y AND 7];
    Else
      If FillStyle <= 11 Then
        PatByte := FillPats[FillStyle][Y AND 7]
      Else
        PatByte := $FF;
    End;

    For X := ClipX(X0) to ClipX(X1) Do
      If (PatByte AND ($80 SHR (X AND 7))) <> 0 Then
        DrawPixel(X, Y, FillColor);
  End;
End;

Procedure TRIPEngine.DrawCircle (XC, YC, Radius: SmallInt);
Var
  X, Y, D : SmallInt;
Begin
  // Midpoint circle algorithm
  X := 0;
  Y := Radius;
  D := 1 - Radius;

  While X <= Y Do Begin
    DrawPixel(XC + X, YC + Y, DrawColor);
    DrawPixel(XC - X, YC + Y, DrawColor);
    DrawPixel(XC + X, YC - Y, DrawColor);
    DrawPixel(XC - X, YC - Y, DrawColor);
    DrawPixel(XC + Y, YC + X, DrawColor);
    DrawPixel(XC - Y, YC + X, DrawColor);
    DrawPixel(XC + Y, YC - X, DrawColor);
    DrawPixel(XC - Y, YC - X, DrawColor);

    If D < 0 Then
      D := D + 2 * X + 3
    Else Begin
      D := D + 2 * (X - Y) + 5;
      Dec(Y);
    End;

    Inc(X);
  End;
End;

Procedure TRIPEngine.DrawOval (XC, YC, XR, YR: SmallInt);
Var
  X, Y   : SmallInt;
  XR2, YR2 : LongInt;
  PX, PY : LongInt;
  P      : LongInt;
Begin
  If (XR = 0) or (YR = 0) Then Exit;

  XR2 := LongInt(XR) * XR;
  YR2 := LongInt(YR) * YR;

  // Region 1
  X := 0;
  Y := YR;
  PX := 0;
  PY := 2 * XR2 * Y;
  P := Round(YR2 - XR2 * YR + 0.25 * XR2);

  While PX < PY Do Begin
    DrawPixel(XC + X, YC + Y, DrawColor);
    DrawPixel(XC - X, YC + Y, DrawColor);
    DrawPixel(XC + X, YC - Y, DrawColor);
    DrawPixel(XC - X, YC - Y, DrawColor);

    Inc(X);
    PX := PX + 2 * YR2;
    If P < 0 Then
      P := P + YR2 + PX
    Else Begin
      Dec(Y);
      PY := PY - 2 * XR2;
      P  := P + YR2 + PX - PY;
    End;
  End;

  // Region 2
  P := Round(YR2 * (X + 0.5) * (X + 0.5) + XR2 * LongInt(Y - 1) * (Y - 1) - XR2 * YR2);

  While Y >= 0 Do Begin
    DrawPixel(XC + X, YC + Y, DrawColor);
    DrawPixel(XC - X, YC + Y, DrawColor);
    DrawPixel(XC + X, YC - Y, DrawColor);
    DrawPixel(XC - X, YC - Y, DrawColor);

    Dec(Y);
    PY := PY - 2 * XR2;
    If P > 0 Then
      P := P + XR2 - PY
    Else Begin
      Inc(X);
      PX := PX + 2 * YR2;
      P  := P + XR2 - PY + PX;
    End;
  End;
End;

Procedure TRIPEngine.DrawFilledOval (XC, YC, XR, YR: SmallInt);
Var
  Y, X1 : SmallInt;
Begin
  If (XR = 0) or (YR = 0) Then Exit;

  For Y := -YR to YR Do Begin
    X1 := Round(XR * Sqrt(1.0 - (Y * Y) / (YR * YR)));
    DrawLine(XC - X1, YC + Y, XC + X1, YC + Y);
  End;
End;

Procedure TRIPEngine.DrawArc (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
Var
  Angle  : SmallInt;
  PX, PY : SmallInt;
Begin
  For Angle := StartAng to EndAng Do Begin
    PX := XC + Round(Radius * Cos(Angle * Pi / 180));
    PY := YC - Round(Radius * Sin(Angle * Pi / 180));
    DrawPixel(PX, PY, DrawColor);
  End;
End;

Procedure TRIPEngine.DrawOvalArc (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
Var
  Angle  : SmallInt;
  PX, PY : SmallInt;
Begin
  For Angle := StartAng to EndAng Do Begin
    PX := XC + Round(XR * Cos(Angle * Pi / 180));
    PY := YC - Round(YR * Sin(Angle * Pi / 180));
    DrawPixel(PX, PY, DrawColor);
  End;
End;

Procedure TRIPEngine.DrawPieSlice (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
Var
  Angle  : SmallInt;
  PX, PY : SmallInt;
Begin
  // Draw arc
  DrawArc(XC, YC, StartAng, EndAng, Radius);

  // Draw lines from center to arc endpoints
  PX := XC + Round(Radius * Cos(StartAng * Pi / 180));
  PY := YC - Round(Radius * Sin(StartAng * Pi / 180));
  DrawLine(XC, YC, PX, PY);

  PX := XC + Round(Radius * Cos(EndAng * Pi / 180));
  PY := YC - Round(Radius * Sin(EndAng * Pi / 180));
  DrawLine(XC, YC, PX, PY);
End;

Procedure TRIPEngine.DrawOvalPie (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
Var
  PX, PY : SmallInt;
Begin
  DrawOvalArc(XC, YC, StartAng, EndAng, XR, YR);

  PX := XC + Round(XR * Cos(StartAng * Pi / 180));
  PY := YC - Round(YR * Sin(StartAng * Pi / 180));
  DrawLine(XC, YC, PX, PY);

  PX := XC + Round(XR * Cos(EndAng * Pi / 180));
  PY := YC - Round(YR * Sin(EndAng * Pi / 180));
  DrawLine(XC, YC, PX, PY);
End;

Procedure TRIPEngine.DrawBezier (X0, Y0, X1, Y1, X2, Y2, X3, Y3: SmallInt; Count: SmallInt);
Var
  I       : SmallInt;
  T       : Real;
  PX, PY  : SmallInt;
  LX, LY  : SmallInt;
  IT, IT2, IT3, T2, T3 : Real;
Begin
  If Count < 2 Then Count := 20;

  LX := X0;
  LY := Y0;

  For I := 1 to Count Do Begin
    T   := I / Count;
    IT  := 1.0 - T;
    IT2 := IT * IT;
    IT3 := IT2 * IT;
    T2  := T * T;
    T3  := T2 * T;

    PX := Round(IT3 * X0 + 3 * IT2 * T * X1 + 3 * IT * T2 * X2 + T3 * X3);
    PY := Round(IT3 * Y0 + 3 * IT2 * T * Y1 + 3 * IT * T2 * Y2 + T3 * Y3);

    DrawLine(LX, LY, PX, PY);

    LX := PX;
    LY := PY;
  End;
End;

Procedure TRIPEngine.DrawPolygon (Var Points: Array of TRIPPoint; Count: Integer);
Var
  I : Integer;
Begin
  If Count < 2 Then Exit;

  For I := 0 to Count - 2 Do
    DrawLine(Points[I].X, Points[I].Y, Points[I+1].X, Points[I+1].Y);

  // Close the polygon
  DrawLine(Points[Count-1].X, Points[Count-1].Y, Points[0].X, Points[0].Y);
End;

Procedure TRIPEngine.DrawFillPoly (Var Points: Array of TRIPPoint; Count: Integer);
// Scanline fill algorithm for convex and concave polygons
Var
  MinY, MaxY : SmallInt;
  Y, I, J    : Integer;
  Nodes      : Integer;
  NodeX      : Array[0..RIP_MAX_POLY-1] of SmallInt;
  Swap       : SmallInt;
Begin
  If Count < 3 Then Begin
    DrawPolygon(Points, Count);
    Exit;
  End;

  // Find Y range
  MinY := Points[0].Y;
  MaxY := Points[0].Y;
  For I := 1 to Count - 1 Do Begin
    If Points[I].Y < MinY Then MinY := Points[I].Y;
    If Points[I].Y > MaxY Then MaxY := Points[I].Y;
  End;

  If MinY < ViewY0 Then MinY := ViewY0;
  If MaxY > ViewY1 Then MaxY := ViewY1;

  // Scanline fill
  For Y := MinY to MaxY Do Begin
    // Build list of intersection X coordinates
    Nodes := 0;
    J := Count - 1;

    For I := 0 to Count - 1 Do Begin
      If ((Points[I].Y <= Y) and (Points[J].Y > Y)) or
         ((Points[J].Y <= Y) and (Points[I].Y > Y)) Then Begin
        If Nodes < RIP_MAX_POLY Then Begin
          NodeX[Nodes] := Points[I].X + LongInt(Y - Points[I].Y) *
            LongInt(Points[J].X - Points[I].X) DIV
            LongInt(Points[J].Y - Points[I].Y);
          Inc(Nodes);
        End;
      End;
      J := I;
    End;

    // Sort intersection points
    I := 0;
    While I < Nodes - 1 Do Begin
      If NodeX[I] > NodeX[I + 1] Then Begin
        Swap := NodeX[I];
        NodeX[I] := NodeX[I + 1];
        NodeX[I + 1] := Swap;
        If I > 0 Then Dec(I) Else Inc(I);
      End Else
        Inc(I);
    End;

    // Fill between pairs
    I := 0;
    While I < Nodes - 1 Do Begin
      For J := NodeX[I] to NodeX[I + 1] Do
        DrawPixel(J, Y, FillColor);
      Inc(I, 2);
    End;
  End;

  // Draw outline
  DrawPolygon(Points, Count);
End;

Procedure TRIPEngine.DrawPolyLine (Var Points: Array of TRIPPoint; Count: Integer);
Var
  I : Integer;
Begin
  If Count < 2 Then Exit;

  For I := 0 to Count - 2 Do
    DrawLine(Points[I].X, Points[I].Y, Points[I+1].X, Points[I+1].Y);
End;

Procedure TRIPEngine.FloodFill (X, Y: SmallInt; Border: Byte);
// Simple scanline flood fill
Var
  Stack : Array[1..4096] of TRIPPoint;
  SP    : Integer;
  FillC : Byte;

  Procedure Push (PX, PY: SmallInt);
  Begin
    If SP < 4096 Then Begin
      Inc(SP);
      Stack[SP].X := PX;
      Stack[SP].Y := PY;
    End;
  End;

Begin
  If Not InView(X, Y) Then Exit;
  If Pixels^[Y, X] = Border Then Exit;
  If Pixels^[Y, X] = FillColor Then Exit;

  SP := 0;
  FillC := FillColor;
  Push(X, Y);

  While SP > 0 Do Begin
    X := Stack[SP].X;
    Y := Stack[SP].Y;
    Dec(SP);

    If Not InView(X, Y) Then Continue;
    If Pixels^[Y, X] = Border Then Continue;
    If Pixels^[Y, X] = FillC Then Continue;

    Pixels^[Y, X] := FillC;

    Push(X + 1, Y);
    Push(X - 1, Y);
    Push(X, Y + 1);
    Push(X, Y - 1);
  End;
End;

Procedure TRIPEngine.DrawText8x8 (X, Y: SmallInt; S: String);
// System font text renderer — handles all 5 font modes
// Mode 0: 8x8,  Mode 1: 8x14,  Mode 2: 16x14,  Mode 3: 7x8,  Mode 4: 7x14
Var
  I, Row, Col : Integer;
  Ch          : Byte;
  FontByte    : Byte;
  CharW, CharH : Integer;
  PixX        : SmallInt;
Begin
  // If a CHR vector font is loaded for the current font, use it
  If (FontNum >= 1) and (FontNum <= 10) and (CHRFonts[FontNum] <> Nil) Then Begin
    DrawTextCHR(X, Y, S, FontNum, FontSize);
    Exit;
  End;

  CharW := GetSysFontW;
  CharH := GetSysFontH;

  For I := 1 to Length(S) Do Begin
    Ch := Ord(S[I]);

    If CharH = 14 Then Begin
      // 8x14 font modes (1, 2, 4)
      For Row := 0 to 13 Do Begin
        FontByte := Font8x14[Ch * 14 + Row];

        If CharW = 16 Then Begin
          // Mode 2: double-width — each pixel drawn twice
          For Col := 0 to 7 Do
            If (FontByte AND ($80 SHR Col)) <> 0 Then Begin
              PixX := X + (I - 1) * 16 + Col * 2;
              DrawPixel(PixX, Y + Row, DrawColor);
              DrawPixel(PixX + 1, Y + Row, DrawColor);
            End;
        End Else Begin
          // Mode 1 (8-wide) or Mode 4 (7-wide)
          For Col := 0 to CharW - 1 Do
            If (FontByte AND ($80 SHR Col)) <> 0 Then
              DrawPixel(X + (I - 1) * CharW + Col, Y + Row, DrawColor);
        End;
      End;
    End Else Begin
      // 8x8 font modes (0, 3)
      For Row := 0 to 7 Do Begin
        FontByte := Font8x8[Ch * 8 + Row];

        For Col := 0 to CharW - 1 Do
          If (FontByte AND ($80 SHR Col)) <> 0 Then
            DrawPixel(X + (I - 1) * CharW + Col, Y + Row, DrawColor);
      End;
    End;
  End;

  CurX := X + Length(S) * CharW;
  CurY := Y;
End;

// ====================================================================
// Constructor / Destructor / Reset
// ====================================================================

Constructor TRIPEngine.Create;
Var
  I : Integer;
Begin
  Inherited Create;

  New(Pixels);
  For I := 1 to 10 Do CHRFonts[I] := Nil;
  For I := 0 to 9 Do SavedScreens[I] := Nil;
  Clipboard := Nil;
  ClipSize  := 0;
  ClipW     := 0;
  ClipH     := 0;
  SavedClip   := Nil;
  SavedClipSz := 0;
  SavedClipW  := 0;
  SavedClipH  := 0;
  SavedTW.Active    := False;
  SavedMouse.Active := False;
  Reset;
End;

Destructor TRIPEngine.Destroy;
Var
  I : Integer;
Begin
  For I := 1 to 10 Do
    If CHRFonts[I] <> Nil Then Dispose(CHRFonts[I]);

  For I := 0 to 9 Do
    If SavedScreens[I] <> Nil Then Dispose(SavedScreens[I]);

  If Clipboard <> Nil Then FreeMem(Clipboard, ClipSize);
  If SavedClip <> Nil Then FreeMem(SavedClip, SavedClipSz);

  Dispose(Pixels);

  Inherited Destroy;
End;

Procedure TRIPEngine.Reset;
Var
  I : Integer;
Begin
  CurX := 0;
  CurY := 0;

  DrawColor  := 15;  // white
  FillColor  := 0;   // black
  FillStyle  := RIP_FILL_SOLID;
  LineStyle  := RIP_LINE_SOLID;
  LineThick  := 1;
  LinePattern := $FFFF;
  WriteMode  := RIP_COPY_PUT;

  FontNum    := RIP_DEFAULT_FONT;
  FontDir    := RIP_HORIZ_DIR;
  FontSize   := 1;
  FontHJust  := RIP_LEFT_TEXT;
  FontVJust  := RIP_TOP_TEXT;

  TextWinX0  := 0;
  TextWinY0  := 0;
  TextWinX1  := 79;
  TextWinY1  := 42;
  TextWinSize := 0;

  ViewX0 := 0;
  ViewY0 := 0;
  ViewX1 := RIP_MAX_X;
  ViewY1 := RIP_MAX_Y;

  // Default EGA palette
  Palette[0]  := 0;   // black
  Palette[1]  := 1;   // blue
  Palette[2]  := 2;   // green
  Palette[3]  := 3;   // cyan
  Palette[4]  := 4;   // red
  Palette[5]  := 5;   // magenta
  Palette[6]  := 20;  // brown
  Palette[7]  := 7;   // light gray
  Palette[8]  := 56;  // dark gray
  Palette[9]  := 57;  // light blue
  Palette[10] := 58;  // light green
  Palette[11] := 59;  // light cyan
  Palette[12] := 60;  // light red
  Palette[13] := 61;  // light magenta
  Palette[14] := 62;  // yellow
  Palette[15] := 63;  // white

  FillChar(FillPat, SizeOf(FillPat), $FF);

  MouseCount     := 0;
  NextTabIndex   := 1;
  FocusedField   := 0;
  HotKeysEnabled := True;
  TabEnabled     := True;
  For I := 1 to RIP_MAX_MOUSE Do
    FillChar(MouseFields[I], SizeOf(TRIPMouseField), 0);

  FillChar(BtnStyle, SizeOf(BtnStyle), 0);
  BtnStyle.BevelSize := 1;
  BtnStyle.DFore     := 15;
  BtnStyle.BRight    := 15;
  BtnStyle.DDark     := 8;
  BtnStyle.Surface   := 7;
  BtnStyle.CornerCol := 16;  // > 15 = don't draw corners

  VarCount := 0;
  For I := 1 to RIP_MAX_VARS Do
    Variables[I].Active := False;

  For I := 1 to 10 Do
    If CHRFonts[I] <> Nil Then Begin
      Dispose(CHRFonts[I]);
      CHRFonts[I] := Nil;
    End;

  // Phase 1: clear saved state
  For I := 0 to 9 Do
    If SavedScreens[I] <> Nil Then Begin
      Dispose(SavedScreens[I]);
      SavedScreens[I] := Nil;
    End;

  SavedTW.Active    := False;
  SavedMouse.Active := False;

  If Clipboard <> Nil Then Begin
    FreeMem(Clipboard, ClipSize);
    Clipboard := Nil;
    ClipSize  := 0;
  End;
  ClipW := 0;
  ClipH := 0;

  If SavedClip <> Nil Then Begin
    FreeMem(SavedClip, SavedClipSz);
    SavedClip   := Nil;
    SavedClipSz := 0;
  End;
  SavedClipW := 0;
  SavedClipH := 0;

  LineBuf   := '';
  Continued := False;

  ClearScreen;
End;

Procedure TRIPEngine.ClearScreen;
Begin
  FillChar(Pixels^, SizeOf(TRIPPixelBuffer), 0);
End;

Procedure TRIPEngine.ClearViewport;
Var
  X, Y : SmallInt;
Begin
  For Y := ViewY0 to ViewY1 Do
    For X := ViewX0 to ViewX1 Do
      Pixels^[Y, X] := 0;
End;

Function TRIPEngine.GetPixel (X, Y: SmallInt) : Byte;
Begin
  If InView(X, Y) Then
    Result := Pixels^[Y, X]
  Else
    Result := 0;
End;

Function TRIPEngine.GetWidth : SmallInt;
Begin
  Result := RIP_MAX_X + 1;
End;

Function TRIPEngine.GetHeight : SmallInt;
Begin
  Result := RIP_MAX_Y + 1;
End;

Function TRIPEngine.FindMouseField (X, Y: SmallInt) : Integer;
Var
  I : Integer;
Begin
  Result := 0;

  For I := MouseCount downto 1 Do
    If MouseFields[I].Active Then
      If (X >= MouseFields[I].X0) and (X <= MouseFields[I].X1) and
         (Y >= MouseFields[I].Y0) and (Y <= MouseFields[I].Y1) Then Begin
        Result := I;
        Exit;
      End;
End;

// ====================================================================
// BGI-compatible public API
// ====================================================================

Procedure TRIPEngine.PutPixel (X, Y: SmallInt; Color: Byte);
Begin
  DrawPixel(X, Y, Color);
End;

Procedure TRIPEngine.Line (X0, Y0, X1, Y1: SmallInt);
Begin
  DrawLine(X0, Y0, X1, Y1);
End;

Procedure TRIPEngine.LineTo (X, Y: SmallInt);
Begin
  DrawLine(CurX, CurY, X, Y);
End;

Procedure TRIPEngine.LineRel (DX, DY: SmallInt);
Begin
  DrawLine(CurX, CurY, CurX + DX, CurY + DY);
End;

Procedure TRIPEngine.Rectangle (X0, Y0, X1, Y1: SmallInt);
Begin
  DrawRect(X0, Y0, X1, Y1);
End;

Procedure TRIPEngine.Bar (X0, Y0, X1, Y1: SmallInt);
Begin
  DrawBar(X0, Y0, X1, Y1);
End;

Procedure TRIPEngine.Bar3D (X0, Y0, X1, Y1: SmallInt; Depth: SmallInt; Top: Boolean);
Begin
  DrawBar(X0, Y0, X1, Y1);
  DrawRect(X0, Y0, X1, Y1);
  // 3D edges
  DrawLine(X1, Y0, X1 + Depth, Y0 - Depth);
  DrawLine(X1 + Depth, Y0 - Depth, X1 + Depth, Y1 - Depth);
  DrawLine(X1, Y1, X1 + Depth, Y1 - Depth);
  If Top Then Begin
    DrawLine(X0, Y0, X0 + Depth, Y0 - Depth);
    DrawLine(X0 + Depth, Y0 - Depth, X1 + Depth, Y0 - Depth);
  End;
End;

Procedure TRIPEngine.Circle (XC, YC, Radius: SmallInt);
Begin
  DrawCircle(XC, YC, Radius);
End;

Procedure TRIPEngine.Ellipse (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
Begin
  If (StartAng = 0) and (EndAng = 360) Then
    DrawOval(XC, YC, XR, YR)
  Else
    DrawOvalArc(XC, YC, StartAng, EndAng, XR, YR);
End;

Procedure TRIPEngine.FillEllipse (XC, YC, XR, YR: SmallInt);
Begin
  DrawFilledOval(XC, YC, XR, YR);
End;

Procedure TRIPEngine.Arc (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
Begin
  DrawArc(XC, YC, StartAng, EndAng, Radius);
End;

Procedure TRIPEngine.PieSlice (XC, YC: SmallInt; StartAng, EndAng, Radius: SmallInt);
Begin
  DrawPieSlice(XC, YC, StartAng, EndAng, Radius);
End;

Procedure TRIPEngine.Sector (XC, YC: SmallInt; StartAng, EndAng, XR, YR: SmallInt);
Begin
  DrawOvalPie(XC, YC, StartAng, EndAng, XR, YR);
End;

Procedure TRIPEngine.DrawPoly (NumPoints: Integer; Var PolyPoints);
Var
  Pts : Array[0..RIP_MAX_POLY-1] of TRIPPoint absolute PolyPoints;
Begin
  DrawPolygon(Pts, NumPoints);
End;

Procedure TRIPEngine.FillPoly (NumPoints: Integer; Var PolyPoints);
Var
  Pts : Array[0..RIP_MAX_POLY-1] of TRIPPoint absolute PolyPoints;
Begin
  DrawFillPoly(Pts, NumPoints);
End;

// ---- Text ----

Procedure TRIPEngine.OutTextXY (X, Y: SmallInt; S: String);
Begin
  S := ExpandVars(S);

  If (FontNum >= 1) and (FontNum <= 10) and
     (CHRFonts[FontNum] <> Nil) and (CHRFonts[FontNum]^.Loaded) Then
    DrawTextCHR(X, Y, S, FontNum, FontSize)
  Else
    DrawText8x8(X, Y, S);
End;

Procedure TRIPEngine.OutText (S: String);
Begin
  S := ExpandVars(S);

  If (FontNum >= 1) and (FontNum <= 10) and
     (CHRFonts[FontNum] <> Nil) and (CHRFonts[FontNum]^.Loaded) Then
    DrawTextCHR(CurX, CurY, S, FontNum, FontSize)
  Else
    DrawText8x8(CurX, CurY, S);
End;

// ---- Position ----

Procedure TRIPEngine.MoveTo (X, Y: SmallInt);
Begin
  CurX := X;
  CurY := Y;
End;

Procedure TRIPEngine.MoveRel (DX, DY: SmallInt);
Begin
  Inc(CurX, DX);
  Inc(CurY, DY);
End;

Function TRIPEngine.GetX : SmallInt;
Begin
  Result := CurX;
End;

Function TRIPEngine.GetY : SmallInt;
Begin
  Result := CurY;
End;

// ---- Color / palette ----

Procedure TRIPEngine.SetColor (Color: Byte);
Begin
  DrawColor := Color;
End;

Function TRIPEngine.GetColor : Byte;
Begin
  Result := DrawColor;
End;

Procedure TRIPEngine.SetBkColor (Color: Byte);
Begin
  // Background color is palette index 0 in RIPscrip
  Palette[0] := Color;
End;

Function TRIPEngine.GetBkColor : Byte;
Begin
  Result := Palette[0];
End;

Procedure TRIPEngine.SetPalette (Index, Color: Byte);
Begin
  If Index < RIP_MAX_COLORS Then
    Palette[Index] := Color;
End;

Procedure TRIPEngine.SetAllPalette (Var Pal: TRIPPalette);
Begin
  Move(Pal, Palette, SizeOf(TRIPPalette));
End;

Procedure TRIPEngine.GetPalette (Var Pal: TRIPPalette);
Begin
  Move(Palette, Pal, SizeOf(TRIPPalette));
End;

// ---- Fill ----

Procedure TRIPEngine.SetFillStyle (Style: Word; Color: Byte);
Begin
  FillStyle := Style;
  FillColor := Color;
End;

Procedure TRIPEngine.SetFillPattern (Var Pattern: TRIPFillPattern; Color: Byte);
Begin
  Move(Pattern, FillPat, SizeOf(TRIPFillPattern));
  FillColor := Color;
  FillStyle := RIP_FILL_USER;
End;

Procedure TRIPEngine.GetFillSettings (Var Style: Word; Var Color: Byte);
Begin
  Style := FillStyle;
  Color := FillColor;
End;

// ---- Line style ----

Procedure TRIPEngine.SetLineStyle (Style, Pattern, Thick: Word);
Begin
  LineStyle   := Style;
  LinePattern := Pattern;
  LineThick   := Thick;
End;

Procedure TRIPEngine.GetLineSettings (Var Style, Pattern, Thick: Word);
Begin
  Style   := LineStyle;
  Pattern := LinePattern;
  Thick   := LineThick;
End;

// ---- Write mode ----

Procedure TRIPEngine.SetWriteMode (Mode: Byte);
Begin
  WriteMode := Mode;
End;

Function TRIPEngine.GetWriteMode : Byte;
Begin
  Result := WriteMode;
End;

// ---- Text style ----

Procedure TRIPEngine.SetTextStyle (Font, Direction, CharSize: Word);
Begin
  FontNum  := Font;
  FontDir  := Direction;
  FontSize := CharSize;
End;

Procedure TRIPEngine.SetTextJustify (Horiz, Vert: Word);
Begin
  FontHJust := Horiz;
  FontVJust := Vert;
End;

// ---- Viewport / window ----

Procedure TRIPEngine.SetViewPort (X0, Y0, X1, Y1: SmallInt; Clip: Boolean);
Begin
  ViewX0 := X0;
  ViewY0 := Y0;
  ViewX1 := X1;
  ViewY1 := Y1;
End;

Procedure TRIPEngine.GetViewPort (Var X0, Y0, X1, Y1: SmallInt);
Begin
  X0 := ViewX0;
  Y0 := ViewY0;
  X1 := ViewX1;
  Y1 := ViewY1;
End;

Procedure TRIPEngine.SetTextWindow (X0, Y0, X1, Y1: SmallInt; Size: Byte);
Begin
  TextWinX0   := X0;
  TextWinY0   := Y0;
  TextWinX1   := X1;
  TextWinY1   := Y1;
  TextWinSize := Size;
End;

// ---- Mouse fields ----

Function TRIPEngine.AddMouseField (X0, Y0, X1, Y1: SmallInt; HostCmd, Text: String) : Integer;
Begin
  Result := 0;

  If MouseCount >= RIP_MAX_MOUSE Then Exit;

  Inc(MouseCount);
  FillChar(MouseFields[MouseCount], SizeOf(TRIPMouseField), 0);
  With MouseFields[MouseCount] Do Begin
    Active  := True;
    Self.MouseFields[MouseCount].X0 := X0;
    Self.MouseFields[MouseCount].Y0 := Y0;
    Self.MouseFields[MouseCount].X1 := X1;
    Self.MouseFields[MouseCount].Y1 := Y1;
    Self.MouseFields[MouseCount].HostCmd := HostCmd;
    Self.MouseFields[MouseCount].Text    := Text;
  End;

  Result := MouseCount;
End;

Procedure TRIPEngine.KillMouseField (Index: Integer);
Begin
  If (Index >= 1) and (Index <= RIP_MAX_MOUSE) Then
    FillChar(MouseFields[Index], SizeOf(TRIPMouseField), 0);
End;

Procedure TRIPEngine.KillAllMouseFields;
Var
  I : Integer;
Begin
  MouseCount   := 0;
  NextTabIndex := 1;
  FocusedField := 0;
  For I := 1 to RIP_MAX_MOUSE Do
    FillChar(MouseFields[I], SizeOf(TRIPMouseField), 0);
End;

Function TRIPEngine.GetMouseCount : Integer;
Begin
  Result := MouseCount;
End;

Function TRIPEngine.GetMouseField (Index: Integer) : TRIPMouseField;
Begin
  If (Index >= 1) and (Index <= RIP_MAX_MOUSE) Then
    Result := MouseFields[Index]
  Else
    FillChar(Result, SizeOf(Result), 0);
End;

// ---- Button ----

Procedure TRIPEngine.SetButtonStyle (Var Style: TRIPButtonStyle);
Begin
  BtnStyle := Style;
End;

Procedure TRIPEngine.DrawButton (X0, Y0, X1, Y1: SmallInt; Label_, HostCmd: String);
Var
  SaveColor : Byte;
  Bev, I    : Integer;
Begin
  SaveColor := DrawColor;
  Bev := BtnStyle.BevelSize;
  If Bev < 1 Then Bev := 1;

  // Draw button surface
  DrawColor := BtnStyle.Surface;
  DrawBar(X0, Y0, X1, Y1);

  // Draw bevel highlight (top-left), BevelSize pixels thick
  DrawColor := BtnStyle.BRight;
  For I := 0 to Bev - 1 Do Begin
    DrawLine(X0 + I, Y0 + I, X1 - I, Y0 + I);   // top edge
    DrawLine(X0 + I, Y0 + I, X0 + I, Y1 - I);   // left edge
  End;

  // Draw bevel shadow (bottom-right), BevelSize pixels thick
  DrawColor := BtnStyle.DDark;
  For I := 0 to Bev - 1 Do Begin
    DrawLine(X0 + I, Y1 - I, X1 - I, Y1 - I);   // bottom edge
    DrawLine(X1 - I, Y0 + I, X1 - I, Y1 - I);   // right edge
  End;

  // Draw corner pixels
  If BtnStyle.CornerCol < 16 Then Begin
    DrawColor := BtnStyle.CornerCol;
    DrawPixel(X0, Y0, BtnStyle.CornerCol);
    DrawPixel(X1, Y0, BtnStyle.CornerCol);
    DrawPixel(X0, Y1, BtnStyle.CornerCol);
    DrawPixel(X1, Y1, BtnStyle.CornerCol);
  End;

  // Draw label centered (uses CHR font if loaded)
  DrawColor := BtnStyle.DFore;
  OutTextXY(X0 + (X1 - X0 - Length(Label_) * GetSysFontW) div 2,
            Y0 + (Y1 - Y0 - GetSysFontH) div 2,
            Label_);

  DrawColor := SaveColor;

  // Register mouse field
  AddMouseField(X0, Y0, X1, Y1, HostCmd, Label_);
End;

// ---- Image ----

Function TRIPEngine.ImageSize (X0, Y0, X1, Y1: SmallInt) : LongInt;
Begin
  Result := (LongInt(X1 - X0 + 1) * LongInt(Y1 - Y0 + 1)) + 4;
  // +4 for width/height header
End;

Procedure TRIPEngine.GetImage (X0, Y0, X1, Y1: SmallInt; Var Buf);
Var
  P    : ^Byte;
  X, Y : SmallInt;
Begin
  P := @Buf;

  // Store width and height as first 4 bytes
  PWord(P)^ := X1 - X0 + 1; Inc(P, 2);
  PWord(P)^ := Y1 - Y0 + 1; Inc(P, 2);

  For Y := Y0 to Y1 Do
    For X := X0 to X1 Do Begin
      P^ := GetPixel(X, Y);
      Inc(P);
    End;
End;

Procedure TRIPEngine.PutImage (X, Y: SmallInt; Var Buf; Mode: Byte);
Var
  P       : ^Byte;
  W, H    : Word;
  IX, IY  : SmallInt;
  SaveMode : Byte;
Begin
  P := @Buf;
  W := PWord(P)^; Inc(P, 2);
  H := PWord(P)^; Inc(P, 2);

  SaveMode  := WriteMode;
  WriteMode := Mode;

  For IY := 0 to H - 1 Do
    For IX := 0 to W - 1 Do Begin
      DrawPixel(X + IX, Y + IY, P^);
      Inc(P);
    End;

  WriteMode := SaveMode;
End;

// ---- Icon loading (ICN/MSK/HIC — full EGA planar rendering) ----
// ICN: Standard icon — 4-plane EGA bitmap, renders with current write mode.
//      BGI GetImage format: header(4 bytes: width-1, height-1) + planar pixel data.
//      LoadIcon(FileName, X, Y, Mode) — loads and renders ICN at (X,Y).
// MSK: Transparency mask — 1-bit bitmap, same dimensions as companion ICN.
//      Pixel=1 means opaque (draw ICN pixel), pixel=0 means transparent (skip).
//      LoadMask(FileName, X, Y) — applies mask to screen (AND operation).
//      LoadIconMasked(IconFile, MaskFile, X, Y) — loads ICN+MSK pair, renders
//        icon only where mask is opaque, preserving background elsewhere.
// HIC: Highlight icon — same format as ICN, used for mouse-over/active states.
//      LoadHotIcon(FileName, X, Y) — loads highlight variant, rendered when
//        the associated mouse field is focused, clicked, or hotkey-activated.

Function TRIPEngine.LoadIcon (FileName: String; X, Y: SmallInt; Mode: Byte) : Boolean;
// ICN format per RIPscrip v1.54 spec:
// Header: width-1 (word) + height-1 (word)
// Data: 4 EGA bit planes per scanline, order 3,2,1,0 (MSB first)
// Each plane: ceil(width/8) bytes per row, padded to 8-pixel boundary
// Optional trash byte at end of file (ignored)
Var
  F              : File;
  WRaw, HRaw     : Word;
  W, H           : SmallInt;
  IX, IY         : SmallInt;
  Plane          : Integer;
  RowBytes       : Integer;
  PlaneData      : Array[0..3, 0..79] of Byte;
  Color          : Byte;
  ByteIdx, BitIdx : Integer;
  SaveMode       : Byte;
  PlaneOrder     : Array[0..3] of Integer;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockRead(F, WRaw, 2);
  BlockRead(F, HRaw, 2);

  // Per spec: stored as pixels-1
  W := WRaw + 1;
  H := HRaw + 1;

  If (W <= 0) or (H <= 0) or (W > 640) or (H > 350) Then Begin
    Close(F);
    Exit;
  End;

  RowBytes := (W + 7) DIV 8;
  SaveMode  := WriteMode;
  WriteMode := Mode;

  // Plane order per spec: 3, 2, 1, 0 (MSB first)
  PlaneOrder[0] := 3;
  PlaneOrder[1] := 2;
  PlaneOrder[2] := 1;
  PlaneOrder[3] := 0;

  For IY := 0 to H - 1 Do Begin
    // Read 4 planes for this row in spec order (3,2,1,0)
    For Plane := 0 to 3 Do
      BlockRead(F, PlaneData[PlaneOrder[Plane]], RowBytes);

    // Combine planes to get pixel colors
    For IX := 0 to W - 1 Do Begin
      ByteIdx := IX DIV 8;
      BitIdx  := 7 - (IX MOD 8);

      Color := 0;
      For Plane := 0 to 3 Do
        If (PlaneData[Plane][ByteIdx] AND (1 SHL BitIdx)) <> 0 Then
          Color := Color OR (1 SHL Plane);

      DrawPixel(X + IX, Y + IY, Color);
    End;
  End;

  Close(F);
  WriteMode := SaveMode;
  Result := True;
End;

Function TRIPEngine.SaveIcon (FileName: String; X0, Y0, X1, Y1: SmallInt) : Boolean;
// Save screen region as ICN file per RIPscrip v1.54 spec
// Width/height stored as pixels-1, planes in order 3,2,1,0
Var
  F              : File;
  WRaw, HRaw     : Word;
  W, H           : SmallInt;
  IX, IY         : SmallInt;
  Plane          : Integer;
  RowBytes       : Integer;
  PlaneData      : Array[0..3, 0..79] of Byte;
  Color          : Byte;
  ByteIdx, BitIdx : Integer;
  PlaneOrder     : Array[0..3] of Integer;
  Trash          : Byte;
Begin
  Result := False;

  W := X1 - X0 + 1;
  H := Y1 - Y0 + 1;

  If (W <= 0) or (H <= 0) or (W > 640) Then Exit;

  RowBytes := (W + 7) DIV 8;

  // Store as pixels-1
  WRaw := W - 1;
  HRaw := H - 1;

  Assign(F, FileName);
  {$I-} ReWrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockWrite(F, WRaw, 2);
  BlockWrite(F, HRaw, 2);

  // Plane order: 3, 2, 1, 0
  PlaneOrder[0] := 3;
  PlaneOrder[1] := 2;
  PlaneOrder[2] := 1;
  PlaneOrder[3] := 0;

  For IY := Y0 to Y1 Do Begin
    FillChar(PlaneData, SizeOf(PlaneData), 0);

    For IX := 0 to W - 1 Do Begin
      Color   := GetPixel(X0 + IX, IY) AND $0F;
      ByteIdx := IX DIV 8;
      BitIdx  := 7 - (IX MOD 8);

      For Plane := 0 to 3 Do
        If (Color AND (1 SHL Plane)) <> 0 Then
          PlaneData[Plane][ByteIdx] := PlaneData[Plane][ByteIdx] OR (1 SHL BitIdx);
    End;

    // Write planes in spec order (3,2,1,0)
    For Plane := 0 to 3 Do
      BlockWrite(F, PlaneData[PlaneOrder[Plane]], RowBytes);
  End;

  // Trash byte per spec
  Trash := 0;
  BlockWrite(F, Trash, 1);

  Close(F);
  Result := True;
End;

// ---- Phase 2: Mask and highlighted icon loading ----

Function TRIPEngine.LoadMask (FileName: String; X, Y: SmallInt) : Boolean;
// Load a .MSK file and apply as AND mask (clear pixels where mask=0)
// MSK format = BGI GetImage: w-1(word) h-1(word) + 4 EGA planes + 2 pad
Var
  F              : File;
  WRaw, HRaw     : Word;
  W, H           : SmallInt;
  IX, IY         : SmallInt;
  Plane          : Integer;
  RowBytes       : Integer;
  PlaneData      : Array[0..3, 0..79] of Byte;
  MaskBit        : Boolean;
  ByteIdx, BitIdx : Integer;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockRead(F, WRaw, 2);
  BlockRead(F, HRaw, 2);

  W := WRaw + 1;
  H := HRaw + 1;

  If (W <= 0) or (H <= 0) or (W > 640) Then Begin
    Close(F);
    Exit;
  End;

  RowBytes := (W + 7) DIV 8;

  For IY := 0 to H - 1 Do Begin
    For Plane := 0 to 3 Do
      BlockRead(F, PlaneData[Plane], RowBytes);

    For IX := 0 to W - 1 Do Begin
      ByteIdx := IX DIV 8;
      BitIdx  := 7 - (IX MOD 8);

      // If ANY plane bit is set, pixel is opaque (keep it)
      // If ALL planes are 0, pixel is transparent (clear to 0)
      MaskBit := False;
      For Plane := 0 to 3 Do
        If (PlaneData[Plane][ByteIdx] AND (1 SHL BitIdx)) <> 0 Then
          MaskBit := True;

      If Not MaskBit Then
        DrawPixel(X + IX, Y + IY, 0);
    End;
  End;

  Close(F);
  Result := True;
End;

Function TRIPEngine.LoadIconMasked (IconFile, MaskFile: String; X, Y: SmallInt) : Boolean;
// Load icon with transparency mask: first apply mask, then draw icon
Begin
  Result := False;

  // Draw the icon (opaque)
  If Not LoadIcon(IconFile, X, Y, 0) Then Exit;

  // Apply mask — clear pixels where mask is transparent
  LoadMask(MaskFile, X, Y);

  Result := True;
End;

Function TRIPEngine.LoadHotIcon (FileName: String; X, Y: SmallInt) : Boolean;
// Load a .HIC highlighted icon — same format as ICN/MSK (BGI GetImage)
Begin
  Result := LoadIcon(FileName, X, Y, 0);
End;

// ---- Phase 2: Button enhancements ----

Procedure TRIPEngine.DrawButtonEx (X0, Y0, X1, Y1: SmallInt;
  Label_, HostCmd, IconFile, HotIconFile: String;
  IsRadio, IsCheckbox, InitSelected: Boolean);
Var
  SaveColor : Byte;
  Idx       : Integer;
  Bev, I    : Integer;
Begin
  SaveColor := DrawColor;
  Bev := BtnStyle.BevelSize;
  If Bev < 1 Then Bev := 1;

  // Draw button surface
  DrawColor := BtnStyle.Surface;
  DrawBar(X0, Y0, X1, Y1);

  // Draw bevel highlight (top-left)
  DrawColor := BtnStyle.BRight;
  For I := 0 to Bev - 1 Do Begin
    DrawLine(X0 + I, Y0 + I, X1 - I, Y0 + I);
    DrawLine(X0 + I, Y0 + I, X0 + I, Y1 - I);
  End;

  // Draw bevel shadow (bottom-right)
  DrawColor := BtnStyle.DDark;
  For I := 0 to Bev - 1 Do Begin
    DrawLine(X0 + I, Y1 - I, X1 - I, Y1 - I);
    DrawLine(X1 - I, Y0 + I, X1 - I, Y1 - I);
  End;

  // Corner pixels
  If BtnStyle.CornerCol < 16 Then Begin
    DrawPixel(X0, Y0, BtnStyle.CornerCol);
    DrawPixel(X1, Y0, BtnStyle.CornerCol);
    DrawPixel(X0, Y1, BtnStyle.CornerCol);
    DrawPixel(X1, Y1, BtnStyle.CornerCol);
  End;

  // If icon file specified, load it on the button
  If IconFile <> '' Then
    LoadIcon(IconFile, X0 + Bev + 1, Y0 + Bev + 1, 0)
  Else Begin
    // Draw label centered (uses CHR font if loaded)
    DrawColor := BtnStyle.DFore;
    OutTextXY(X0 + (X1 - X0 - Length(Label_) * GetSysFontW) div 2,
              Y0 + (Y1 - Y0 - GetSysFontH) div 2,
              Label_);
  End;

  DrawColor := SaveColor;

  // Register mouse field with button state
  If MouseCount < RIP_MAX_MOUSE Then Begin
    Inc(MouseCount);
    Idx := MouseCount;
    FillChar(MouseFields[Idx], SizeOf(TRIPMouseField), 0);
    With MouseFields[Idx] Do Begin
      Active      := True;
      Self.MouseFields[Idx].X0 := X0;
      Self.MouseFields[Idx].Y0 := Y0;
      Self.MouseFields[Idx].X1 := X1;
      Self.MouseFields[Idx].Y1 := Y1;
      Self.MouseFields[Idx].HostCmd := HostCmd;
      Self.MouseFields[Idx].Text    := Label_;
      Invert      := True;
      IsButton    := True;
      Self.MouseFields[Idx].IsRadio    := IsRadio;
      Self.MouseFields[Idx].IsCheckbox := IsCheckbox;
      Self.MouseFields[Idx].GroupID    := BtnStyle.GrpID;
      Selected    := InitSelected;
      Self.MouseFields[Idx].IconFile    := IconFile;
      Self.MouseFields[Idx].HotIconFile := HotIconFile;
      TabIndex    := NextTabIndex;
    End;
    Inc(NextTabIndex);

    // Parse hotkey from label: (M) or [F] pattern
    If Length(Label_) >= 3 Then Begin
      If ((Label_[1] = '(') and (Label_[3] = ')')) or
         ((Label_[1] = '[') and (Label_[3] = ']')) Then Begin
        MouseFields[Idx].HotKey := Label_[2];
        If (MouseFields[Idx].HotKey >= 'a') and (MouseFields[Idx].HotKey <= 'z') Then
          MouseFields[Idx].HotKey := Chr(Ord(MouseFields[Idx].HotKey) - 32);

        // Draw underline under the hotkey character
        If (BtnStyle.ULineCol < 16) and (IconFile = '') Then Begin
          DrawColor := BtnStyle.ULineCol;
          DrawLine(
            X0 + (X1 - X0 - Length(Label_) * GetSysFontW) div 2 + GetSysFontW,
            Y0 + (Y1 - Y0 - GetSysFontH) div 2 + GetSysFontH,
            X0 + (X1 - X0 - Length(Label_) * GetSysFontW) div 2 + GetSysFontW * 2 - 1,
            Y0 + (Y1 - Y0 - GetSysFontH) div 2 + GetSysFontH);
          DrawColor := SaveColor;
        End;
      End;
    End;

    // If initially selected, show hot icon or invert
    If InitSelected Then Begin
      If HotIconFile <> '' Then
        LoadHotIcon(HotIconFile, X0 + Bev + 1, Y0 + Bev + 1)
      Else
        InvertRegion(X0, Y0, X1, Y1);
    End;
  End;
End;

Procedure TRIPEngine.ClickButton (Index: Integer);
Var
  I  : Integer;
  MF : TRIPMouseField;
Begin
  If (Index < 1) or (Index > MouseCount) Then Exit;
  If Not MouseFields[Index].Active Then Exit;
  If Not MouseFields[Index].IsButton Then Exit;

  MF := MouseFields[Index];

  // Radio button: deselect all others in same group
  If MF.IsRadio Then Begin
    For I := 1 to MouseCount Do
      If MouseFields[I].Active and MouseFields[I].IsRadio and
         (MouseFields[I].GroupID = MF.GroupID) and (I <> Index) Then Begin
        If MouseFields[I].Selected Then Begin
          MouseFields[I].Selected := False;
          // Restore normal icon or un-invert
          If MouseFields[I].IconFile <> '' Then
            LoadIcon(MouseFields[I].IconFile, MouseFields[I].X0 + 2, MouseFields[I].Y0 + 2, 0)
          Else
            InvertRegion(MouseFields[I].X0, MouseFields[I].Y0,
                         MouseFields[I].X1, MouseFields[I].Y1);
        End;
      End;

    // Select this one
    MouseFields[Index].Selected := True;
    If MF.HotIconFile <> '' Then
      LoadHotIcon(MF.HotIconFile, MF.X0 + 2, MF.Y0 + 2)
    Else
      InvertRegion(MF.X0, MF.Y0, MF.X1, MF.Y1);
  End;

  // Checkbox: toggle
  If MF.IsCheckbox Then Begin
    MouseFields[Index].Selected := Not MouseFields[Index].Selected;

    If MouseFields[Index].Selected Then Begin
      If MF.HotIconFile <> '' Then
        LoadHotIcon(MF.HotIconFile, MF.X0 + 2, MF.Y0 + 2)
      Else
        InvertRegion(MF.X0, MF.Y0, MF.X1, MF.Y1);
    End Else Begin
      If MF.IconFile <> '' Then
        LoadIcon(MF.IconFile, MF.X0 + 2, MF.Y0 + 2, 0)
      Else
        InvertRegion(MF.X0, MF.Y0, MF.X1, MF.Y1);
    End;
  End;

  // Plain button with invert
  If (Not MF.IsRadio) and (Not MF.IsCheckbox) and MF.Invert Then
    InvertRegion(MF.X0, MF.Y0, MF.X1, MF.Y1);
End;

Procedure TRIPEngine.InvertRegion (X0, Y0, X1, Y1: SmallInt);
// XOR all pixels in the region with $0F (inverts all 4 color bits)
Var
  X, Y : SmallInt;
Begin
  For Y := ClipY(Y0) to ClipY(Y1) Do
    For X := ClipX(X0) to ClipX(X1) Do
      Pixels^[Y, X] := Pixels^[Y, X] XOR $0F;
End;

// ---- Phase 5: Button hotkeys and tab navigation ----

Function TRIPEngine.FindButtonByHotkey (Key: Char) : Integer;
// Find the first active button whose HotKey matches Key
// Returns mouse field index (1-based) or 0 if not found
Var
  I    : Integer;
  UKey : Char;
Begin
  Result := 0;
  If Not HotKeysEnabled Then Exit;

  // Case-insensitive match
  UKey := Key;
  If (UKey >= 'a') and (UKey <= 'z') Then
    UKey := Chr(Ord(UKey) - 32);

  For I := 1 to MouseCount Do
    If MouseFields[I].Active and MouseFields[I].IsButton and
       (MouseFields[I].HotKey <> #0) Then Begin
      If MouseFields[I].HotKey = UKey Then Begin
        Result := I;
        Exit;
      End;
      // Also check lowercase
      If (MouseFields[I].HotKey >= 'a') and (MouseFields[I].HotKey <= 'z') Then
        If Chr(Ord(MouseFields[I].HotKey) - 32) = UKey Then Begin
          Result := I;
          Exit;
        End;
    End;
End;

Function TRIPEngine.GetNextTabField : Integer;
// Find next tabbable field after FocusedField
// Wraps around to first field if at end
Var
  I, Start : Integer;
Begin
  Result := 0;
  If Not TabEnabled Then Exit;
  If MouseCount = 0 Then Exit;

  If FocusedField = 0 Then
    Start := 1
  Else
    Start := FocusedField + 1;

  // Search forward from current + 1
  For I := Start to MouseCount Do
    If MouseFields[I].Active and (MouseFields[I].TabIndex > 0) Then Begin
      Result := I;
      Exit;
    End;

  // Wrap around
  For I := 1 to Start - 1 Do
    If MouseFields[I].Active and (MouseFields[I].TabIndex > 0) Then Begin
      Result := I;
      Exit;
    End;
End;

Function TRIPEngine.GetPrevTabField : Integer;
// Find previous tabbable field before FocusedField
Var
  I, Start : Integer;
Begin
  Result := 0;
  If Not TabEnabled Then Exit;
  If MouseCount = 0 Then Exit;

  If FocusedField <= 1 Then
    Start := MouseCount
  Else
    Start := FocusedField - 1;

  // Search backward
  For I := Start downto 1 Do
    If MouseFields[I].Active and (MouseFields[I].TabIndex > 0) Then Begin
      Result := I;
      Exit;
    End;

  // Wrap around
  For I := MouseCount downto Start + 1 Do
    If MouseFields[I].Active and (MouseFields[I].TabIndex > 0) Then Begin
      Result := I;
      Exit;
    End;
End;

Procedure TRIPEngine.FocusField (Index: Integer);
// Set focus to a mouse field (highlights it)
Begin
  If (Index < 1) or (Index > MouseCount) Then Exit;
  If Not MouseFields[Index].Active Then Exit;

  // Unfocus previous
  UnfocusField;

  // Highlight new field
  FocusedField := Index;
  InvertRegion(MouseFields[Index].X0, MouseFields[Index].Y0,
               MouseFields[Index].X1, MouseFields[Index].Y1);
End;

Procedure TRIPEngine.UnfocusField;
// Remove focus from current field (un-highlights it)
Begin
  If (FocusedField >= 1) and (FocusedField <= MouseCount) and
     MouseFields[FocusedField].Active Then
    InvertRegion(MouseFields[FocusedField].X0, MouseFields[FocusedField].Y0,
                 MouseFields[FocusedField].X1, MouseFields[FocusedField].Y1);

  FocusedField := 0;
End;

Function TRIPEngine.GetFocusedField : Integer;
Begin
  Result := FocusedField;
End;

// ---- Phase 6: System font mode helpers ----

Function TRIPEngine.GetSysFontW : Integer;
Begin
  Case TextWinSize of
    RIP_SYSFONT_80x25 : Result := 8;
    RIP_SYSFONT_40x25 : Result := 16;
    RIP_SYSFONT_91x43 : Result := 7;
    RIP_SYSFONT_91x25 : Result := 7;
  Else
    Result := 8;   // Mode 0 default
  End;
End;

Function TRIPEngine.GetSysFontH : Integer;
Begin
  Case TextWinSize of
    RIP_SYSFONT_80x25 : Result := 14;
    RIP_SYSFONT_40x25 : Result := 14;
    RIP_SYSFONT_91x25 : Result := 14;
  Else
    Result := 8;   // Modes 0, 3
  End;
End;

Function TRIPEngine.GetSysCols : Integer;
Begin
  Case TextWinSize of
    RIP_SYSFONT_80x25 : Result := 80;
    RIP_SYSFONT_40x25 : Result := 40;
    RIP_SYSFONT_91x43 : Result := 91;
    RIP_SYSFONT_91x25 : Result := 91;
  Else
    Result := 80;  // Mode 0 default
  End;
End;

Function TRIPEngine.GetSysRows : Integer;
Begin
  Case TextWinSize of
    RIP_SYSFONT_80x25 : Result := 25;
    RIP_SYSFONT_40x25 : Result := 25;
    RIP_SYSFONT_91x43 : Result := 43;
    RIP_SYSFONT_91x25 : Result := 25;
  Else
    Result := 43;  // Mode 0 default
  End;
End;

// ---- Scene file ----

Function TRIPEngine.LoadScene (FileName: String) : Boolean;
Var
  F    : Text;
  Line : String;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;

  While Not Eof(F) Do Begin
    ReadLn(F, Line);
    ProcessLine(Line);
  End;

  Close(F);
  Result := True;
End;

Function TRIPEngine.SaveScene (FileName: String) : Boolean;
// Save current screen state as a .RIP scene file.
// Writes RIP commands to reconstruct the current state:
//   - Reset windows
//   - Set palette
//   - Set draw color, fill style, line style
//   - Pixel-by-pixel rendering via SetPixel commands
// For large scenes, this produces a large file. The caller
// may prefer SaveBMP for archival instead.
Var
  F    : Text;
  X, Y : SmallInt;
  C    : Byte;
  LastColor : Byte;

  Function ToMega (V: Integer; Digits: Integer) : String;
  Var
    I : Integer;
    D : Integer;
  Begin
    Result := '';
    For I := Digits downto 1 Do Begin
      D := V MOD 36;
      If D < 10 Then
        Result := Chr(Ord('0') + D) + Result
      Else
        Result := Chr(Ord('A') + D - 10) + Result;
      V := V DIV 36;
    End;
  End;

Begin
  Result := False;

  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;

  // Header
  WriteLn(F, '!|*');  // reset windows
  WriteLn(F, '!|e');  // clear screen

  // Set palette
  Write(F, '!|Q');
  For C := 0 to 15 Do
    Write(F, ToMega(Palette[C], 2));
  WriteLn(F);

  // Render pixels — group runs of same color
  LastColor := 255;
  For Y := 0 to RIP_MAX_Y Do
    For X := 0 to RIP_MAX_X Do Begin
      C := Pixels^[Y, X];
      If C <> 0 Then Begin
        If C <> LastColor Then Begin
          WriteLn(F, '!|c' + ToMega(C, 2));
          LastColor := C;
        End;
        WriteLn(F, '!|X' + ToMega(X, 2) + ToMega(Y, 2));
      End;
    End;

  Close(F);
  Result := True;
End;

// ---- CHR vector font ----


// ---- BMP export ----

Function TRIPEngine.SaveBMP (FileName: String) : Boolean;
// Write the pixel buffer as a 24-bit BMP file
Var
  F         : File;
  Hdr       : Array[0..53] of Byte;
  RowSize   : LongInt;
  Pad       : Integer;
  X, Y, I   : SmallInt;
  Color     : Byte;
  Rgb       : TRIPRgb;
  PadByte   : Byte;
  FileSize  : LongInt;

  Procedure PutLE32 (Off: Integer; V: LongInt);
  Begin
    Hdr[Off]     := V AND $FF;
    Hdr[Off + 1] := (V SHR 8) AND $FF;
    Hdr[Off + 2] := (V SHR 16) AND $FF;
    Hdr[Off + 3] := (V SHR 24) AND $FF;
  End;

  Procedure PutLE16 (Off: Integer; V: Word);
  Begin
    Hdr[Off]     := V AND $FF;
    Hdr[Off + 1] := (V SHR 8) AND $FF;
  End;

Begin
  Result := False;

  RowSize  := (RIP_MAX_X + 1) * 3;
  Pad      := (4 - (RowSize MOD 4)) MOD 4;
  FileSize := 54 + (RowSize + Pad) * (RIP_MAX_Y + 1);

  FillChar(Hdr, SizeOf(Hdr), 0);
  Hdr[0] := Ord('B');
  Hdr[1] := Ord('M');
  PutLE32(2, FileSize);
  PutLE32(10, 54);         // data offset
  PutLE32(14, 40);         // info header size
  PutLE32(18, RIP_MAX_X + 1);  // width
  PutLE32(22, RIP_MAX_Y + 1);  // height
  PutLE16(26, 1);          // planes
  PutLE16(28, 24);         // bits per pixel

  Assign(F, FileName);
  {$I-} ReWrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockWrite(F, Hdr, 54);

  PadByte := 0;

  // BMP is bottom-up
  For Y := RIP_MAX_Y downto 0 Do Begin
    For X := 0 to RIP_MAX_X Do Begin
      Color := Pixels^[Y, X] AND $0F;
      Rgb   := EGA_RGB[Color];
      // BMP stores BGR
      BlockWrite(F, Rgb.B, 1);
      BlockWrite(F, Rgb.G, 1);
      BlockWrite(F, Rgb.R, 1);
    End;

    For I := 1 to Pad Do
      BlockWrite(F, PadByte, 1);
  End;

  Close(F);
  Result := True;
End;

// ====================================================================
// Phase 4 — Image Format Loading
// ====================================================================

Function TRIPEngine.LoadPCX (FileName: String; X, Y: SmallInt) : Boolean;
// Load a 16-color EGA PCX file and render at (X,Y)
// PCX format: 128-byte header, RLE compressed, 4 bit planes
Var
  F         : File;
  Header    : Array[0..127] of Byte;
  BPP       : Byte;
  XMin, YMin, XMax, YMax : SmallInt;
  W, H      : SmallInt;
  NPlanes   : Byte;
  BytesPerRow : Word;
  Row, Plane, Col : SmallInt;
  RunByte, RunCount : Byte;
  PlaneData : Array[0..3, 0..79] of Byte;  // max 640px wide
  ByteIdx, BitIdx : Integer;
  Color     : Byte;
  BytesFilled : Integer;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  // Read 128-byte header
  BlockRead(F, Header, 128);

  // Validate: manufacturer must be 0x0A (ZSoft)
  If Header[0] <> $0A Then Begin Close(F); Exit; End;

  BPP  := Header[3];
  XMin := Header[4] OR (Header[5] SHL 8);
  YMin := Header[6] OR (Header[7] SHL 8);
  XMax := Header[8] OR (Header[9] SHL 8);
  YMax := Header[10] OR (Header[11] SHL 8);
  NPlanes    := Header[65];
  BytesPerRow := Header[66] OR (Header[67] SHL 8);

  W := XMax - XMin + 1;
  H := YMax - YMin + 1;

  // We only support 16-color EGA: 4 planes, 1 bit per pixel
  If (BPP <> 1) or (NPlanes <> 4) Then Begin Close(F); Exit; End;
  If (W <= 0) or (H <= 0) or (W > 640) or (H > 350) Then Begin Close(F); Exit; End;
  If BytesPerRow > 80 Then Begin Close(F); Exit; End;

  // Decode RLE scanlines
  For Row := 0 to H - 1 Do Begin
    // Read all 4 planes for this row
    For Plane := 0 to NPlanes - 1 Do Begin
      BytesFilled := 0;

      While BytesFilled < BytesPerRow Do Begin
        {$I-} BlockRead(F, RunByte, 1); {$I+}
        If IOResult <> 0 Then Begin Close(F); Exit; End;

        If (RunByte AND $C0) = $C0 Then Begin
          // RLE: top 2 bits set = run count in lower 6 bits
          RunCount := RunByte AND $3F;
          {$I-} BlockRead(F, RunByte, 1); {$I+}
          If IOResult <> 0 Then Begin Close(F); Exit; End;

          While (RunCount > 0) and (BytesFilled < BytesPerRow) Do Begin
            PlaneData[Plane][BytesFilled] := RunByte;
            Inc(BytesFilled);
            Dec(RunCount);
          End;
        End Else Begin
          // Literal byte
          PlaneData[Plane][BytesFilled] := RunByte;
          Inc(BytesFilled);
        End;
      End;
    End;

    // Combine planes into pixel colors
    For Col := 0 to W - 1 Do Begin
      ByteIdx := Col DIV 8;
      BitIdx  := 7 - (Col MOD 8);

      Color := 0;
      For Plane := 0 to 3 Do
        If (PlaneData[Plane][ByteIdx] AND (1 SHL BitIdx)) <> 0 Then
          Color := Color OR (1 SHL Plane);

      DrawPixel(X + Col, Y + Row, Color);
    End;
  End;

  Close(F);
  Result := True;
End;

Function TRIPEngine.LoadBMP (FileName: String; X, Y: SmallInt) : Boolean;
// Load a 4-bit (16-color) or 24-bit BMP and render at (X,Y)
// Maps 24-bit RGB to nearest EGA color
Var
  F          : File;
  FileHdr    : Array[0..13] of Byte;
  InfoHdr    : Array[0..39] of Byte;
  DataOffset : LongInt;
  W, H       : LongInt;
  BitCount   : Word;
  Row, Col   : SmallInt;
  RowSize    : LongInt;
  Pad        : Integer;
  B, G, R    : Byte;
  Color      : Byte;
  NibByte    : Byte;
  TopDown    : Boolean;
  SrcRow     : SmallInt;

  Function NearestEGA (RR, GG, BB: Byte) : Byte;
  Var
    I, Best, BestDist, Dist : Integer;
  Begin
    Best := 0;
    BestDist := MaxInt;
    For I := 0 to 15 Do Begin
      Dist := Abs(SmallInt(RR) - SmallInt(EGA_RGB[I].R)) +
              Abs(SmallInt(GG) - SmallInt(EGA_RGB[I].G)) +
              Abs(SmallInt(BB) - SmallInt(EGA_RGB[I].B));
      If Dist < BestDist Then Begin
        BestDist := Dist;
        Best := I;
      End;
    End;
    Result := Best;
  End;

Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  // Read file header (14 bytes)
  BlockRead(F, FileHdr, 14);
  If (FileHdr[0] <> Ord('B')) or (FileHdr[1] <> Ord('M')) Then Begin
    Close(F); Exit;
  End;

  DataOffset := FileHdr[10] OR (FileHdr[11] SHL 8) OR
                (FileHdr[12] SHL 16) OR (FileHdr[13] SHL 24);

  // Read info header (40 bytes)
  BlockRead(F, InfoHdr, 40);

  W := InfoHdr[4] OR (InfoHdr[5] SHL 8) OR (InfoHdr[6] SHL 16) OR (InfoHdr[7] SHL 24);
  H := InfoHdr[8] OR (InfoHdr[9] SHL 8) OR (InfoHdr[10] SHL 16) OR (InfoHdr[11] SHL 24);
  BitCount := InfoHdr[14] OR (InfoHdr[15] SHL 8);

  TopDown := H < 0;
  If TopDown Then H := -H;

  If (W <= 0) or (H <= 0) or (W > 640) or (H > 350) Then Begin
    Close(F); Exit;
  End;

  // Seek to data
  Seek(F, DataOffset);

  Case BitCount of
    4 : Begin
          // 4-bit: 2 pixels per byte, rows padded to 4 bytes
          RowSize := ((W + 1) DIV 2);
          Pad := (4 - (RowSize MOD 4)) MOD 4;

          For Row := 0 to H - 1 Do Begin
            If TopDown Then SrcRow := Row
            Else SrcRow := H - 1 - Row;

            For Col := 0 to W - 1 Do Begin
              If (Col MOD 2) = 0 Then Begin
                {$I-} BlockRead(F, NibByte, 1); {$I+}
                If IOResult <> 0 Then Begin Close(F); Exit; End;
                Color := (NibByte SHR 4) AND $0F;
              End Else
                Color := NibByte AND $0F;

              DrawPixel(X + Col, Y + SrcRow, Color);
            End;

            // Skip padding
            For Col := 1 to Pad Do
              BlockRead(F, NibByte, 1);
          End;

          Result := True;
        End;

    24 : Begin
           // 24-bit: 3 bytes per pixel BGR, padded to 4 bytes
           RowSize := W * 3;
           Pad := (4 - (RowSize MOD 4)) MOD 4;

           For Row := 0 to H - 1 Do Begin
             If TopDown Then SrcRow := Row
             Else SrcRow := H - 1 - Row;

             For Col := 0 to W - 1 Do Begin
               {$I-}
               BlockRead(F, B, 1);
               BlockRead(F, G, 1);
               BlockRead(F, R, 1);
               {$I+}
               If IOResult <> 0 Then Begin Close(F); Exit; End;

               DrawPixel(X + Col, Y + SrcRow, NearestEGA(R, G, B));
             End;

             // Skip padding
             For Col := 1 to Pad Do
               BlockRead(F, NibByte, 1);
           End;

           Result := True;
         End;
  End;

  Close(F);
End;

// ---- Dimensions ----

// ---- Text variables (RIP_DEFINE 1D) ----

Procedure TRIPEngine.DefineVar (Name, Value: String; Persist, Required: Boolean);
Var
  Idx : Integer;
Begin
  Idx := FindVar(Name);

  If Idx = 0 Then Begin
    If VarCount >= RIP_MAX_VARS Then Exit;
    Inc(VarCount);
    Idx := VarCount;
  End;

  Variables[Idx].Active   := True;
  Variables[Idx].Name     := Name;
  Variables[Idx].Value    := Value;
  Variables[Idx].Persist  := Persist;
  Variables[Idx].Required := Required;
End;

Function TRIPEngine.GetVar (Name: String) : String;
Var
  Idx : Integer;
Begin
  Idx := FindVar(Name);
  If Idx > 0 Then
    Result := Variables[Idx].Value
  Else
    Result := '';
End;

Procedure TRIPEngine.SetVar (Name, Value: String);
Var
  Idx : Integer;
Begin
  Idx := FindVar(Name);
  If Idx > 0 Then
    Variables[Idx].Value := Value;
End;

Function TRIPEngine.FindVar (Name: String) : Integer;
Var
  I : Integer;
Begin
  Result := 0;

  For I := 1 to VarCount Do
    If Variables[I].Active and (Variables[I].Name = Name) Then Begin
      Result := I;
      Exit;
    End;
End;

Procedure TRIPEngine.KillAllVars;
Var
  I : Integer;
Begin
  VarCount := 0;
  For I := 1 to RIP_MAX_VARS Do
    Variables[I].Active := False;
End;

// ---- Variable persistence ----

Function TRIPEngine.SaveVars (FileName: String) : Boolean;
// Save all persistent variables to a text file.
// Format: one line per variable, NAME=VALUE
Var
  F : Text;
  I : Integer;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;

  For I := 1 to RIP_MAX_VARS Do
    If Variables[I].Active and Variables[I].Persist Then
      WriteLn(F, Variables[I].Name, '=', Variables[I].Value);

  Close(F);
  Result := True;
End;

Function TRIPEngine.LoadVars (FileName: String) : Boolean;
// Load variables from a text file (NAME=VALUE format).
// Existing variables with matching names are updated;
// new variables are added. Non-matching existing vars are kept.
Var
  F    : Text;
  Line : String;
  P    : Integer;
  Name : String;
  Val  : String;
  Idx  : Integer;
Begin
  Result := False;

  Assign(F, FileName);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;

  While Not EOF(F) Do Begin
    ReadLn(F, Line);
    If Length(Line) = 0 Then Continue;

    // Find = separator
    P := 1;
    While (P <= Length(Line)) and (Line[P] <> '=') Do Inc(P);
    If P > Length(Line) Then Continue;

    Name := Copy(Line, 1, P - 1);
    Val  := Copy(Line, P + 1, Length(Line));

    // Update existing or create new
    Idx := FindVar(Name);
    If Idx > 0 Then
      Variables[Idx].Value := Val
    Else
      DefineVar(Name, Val, True, False);
  End;

  Close(F);
  Result := True;
End;

// ====================================================================
// Phase 3 — Pre-defined Text Variables
// ====================================================================

Function TRIPEngine.ResolveVar (Name: String) : String;
// Resolve a built-in or user-defined text variable by name.
// Returns the value string, or empty if not found.
// Name should NOT include the $ delimiters.
Var
  I   : Integer;
  UName : String;
Begin
  Result := '';

  // Uppercase for comparison
  UName := Name;
  For I := 1 to Length(UName) Do
    If (UName[I] >= 'a') and (UName[I] <= 'z') Then
      UName[I] := Chr(Ord(UName[I]) - 32);

  // ---- System info ----
  If UName = 'DATE' Then Begin
    // MM/DD/YY format — placeholder, server fills in
    Result := '01/01/26';
    Exit;
  End;

  If UName = 'TIME' Then Begin
    // HH:MM:SS format — placeholder
    Result := '00:00:00';
    Exit;
  End;

  If UName = 'RUNDATE' Then Begin Result := '01/01/26'; Exit; End;
  If UName = 'RUNTIME' Then Begin Result := '00:00:00'; Exit; End;

  // ---- Screen state ----
  If UName = 'CURX' Then Begin
    Result := '';
    I := CurX;
    If I = 0 Then Result := '0'
    Else Begin
      While I > 0 Do Begin
        Result := Chr(Ord('0') + (I MOD 10)) + Result;
        I := I DIV 10;
      End;
    End;
    Exit;
  End;

  If UName = 'CURY' Then Begin
    Result := '';
    I := CurY;
    If I = 0 Then Result := '0'
    Else Begin
      While I > 0 Do Begin
        Result := Chr(Ord('0') + (I MOD 10)) + Result;
        I := I DIV 10;
      End;
    End;
    Exit;
  End;

  If UName = 'CURSOR' Then Begin Result := 'YES'; Exit; End;

  // ---- Text window ----
  If UName = 'TWX0' Then Begin Result := ''; I := TextWinX0;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWY0' Then Begin Result := ''; I := TextWinY0;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWX1' Then Begin Result := ''; I := TextWinX1;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWY1' Then Begin Result := ''; I := TextWinY1;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWW' Then Begin Result := ''; I := TextWinX1 - TextWinX0 + 1;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWH' Then Begin Result := ''; I := TextWinY1 - TextWinY0 + 1;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;
  If UName = 'TWWIN' Then Begin
    If (TextWinX0 <> 0) or (TextWinY0 <> 0) or
       (TextWinX1 <> 79) or (TextWinY1 <> 42) Then
      Result := 'YES'
    Else
      Result := 'NO';
    Exit;
  End;
  If UName = 'TWFONT' Then Begin Result := ''; I := TextWinSize;
    If I = 0 Then Result := '0' Else While I > 0 Do Begin Result := Chr(Ord('0')+(I MOD 10))+Result; I := I DIV 10; End; Exit; End;

  // ---- Sound (no-op server-side, but recognized) ----
  If UName = 'ALARM'     Then Exit;
  If UName = 'PHASER'    Then Exit;
  If UName = 'REVPHASER' Then Exit;

  // ---- Mode control (return current state as YES/NO) ----
  If UName = 'HKEYON'    Then Begin If HotKeysEnabled Then Result := 'YES' Else Result := 'NO'; Exit; End;
  If UName = 'HKEYOFF'   Then Begin If Not HotKeysEnabled Then Result := 'YES' Else Result := 'NO'; Exit; End;
  If UName = 'TABON'     Then Begin If TabEnabled Then Result := 'YES' Else Result := 'NO'; Exit; End;
  If UName = 'TABOFF'    Then Begin If Not TabEnabled Then Result := 'YES' Else Result := 'NO'; Exit; End;
  If UName = 'VT102ON'   Then Exit;
  If UName = 'VT102OFF'  Then Exit;
  If UName = 'DWAYON'    Then Exit;
  If UName = 'DWAYOFF'   Then Exit;
  If UName = 'CON'       Then Exit;
  If UName = 'COFF'      Then Exit;

  // ---- User-defined variables ----
  I := FindVar(Name);
  If I > 0 Then Begin
    Result := Variables[I].Value;
    Exit;
  End;
End;

Function TRIPEngine.ExpandVars (S: String) : String;
// Scan string for $VARNAME$ patterns and replace with values.
Var
  P, Start, OutLen : Integer;
  VarName  : String;
  Value    : String;
  Buf      : String;
Begin
  // Fast path: no $ in string, return as-is
  P := 1;
  While (P <= Length(S)) and (S[P] <> '$') Do Inc(P);
  If P > Length(S) Then Begin
    Result := S;
    Exit;
  End;

  // Has at least one $ — do the expansion
  Buf := '';
  P := 1;

  While P <= Length(S) Do Begin
    If S[P] = '$' Then Begin
      Start := P + 1;
      Inc(P);

      While (P <= Length(S)) and (S[P] <> '$') Do
        Inc(P);

      If (P <= Length(S)) and (S[P] = '$') Then Begin
        VarName := Copy(S, Start, P - Start);
        Value   := ResolveVar(VarName);

        If Value <> '' Then
          Buf := Buf + Value
        Else
          Buf := Buf + '$' + VarName + '$';

        Inc(P);
      End Else
        Buf := Buf + '$' + Copy(S, Start, P - Start);
    End Else Begin
      // Copy non-$ characters in bulk
      Start := P;
      While (P <= Length(S)) and (S[P] <> '$') Do Inc(P);
      Buf := Buf + Copy(S, Start, P - Start);
    End;
  End;

  Result := Buf;
End;

// ---- File query (RIP_FILE_QUERY 1F) ----

Function TRIPEngine.FileQuery (FileName: String; Mode: Byte) : TRIPFileQueryResult;
Var
  F : File;
Begin
  FillChar(Result, SizeOf(Result), 0);

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}

  If IOResult = 0 Then Begin
    Result.Exists := True;
    Result.Size   := FileSize(F);
    Close(F);
  End Else
    Result.Exists := False;
End;

// ---- Copy region (RIP_COPY_REGION 1G) ----

Procedure TRIPEngine.CopyRegion (X0, Y0, X1, Y1, DestY: SmallInt);
Var
  H, X, Y : SmallInt;
Begin
  // Per spec: X0/X1 must be on 8-pixel boundaries
  X0 := (X0 DIV 8) * 8;
  X1 := ((X1 + 7) DIV 8) * 8 - 1;

  H := Y1 - Y0 + 1;

  // Ignore if destination goes off screen
  If (DestY < 0) or (DestY + H - 1 > RIP_MAX_Y) Then Exit;

  // Copy direction handles overlap correctly
  If DestY < Y0 Then Begin
    For Y := 0 to H - 1 Do
      For X := X0 to X1 Do
        If InView(X, DestY + Y) and InView(X, Y0 + Y) Then
          Pixels^[DestY + Y, X] := Pixels^[Y0 + Y, X];
  End Else Begin
    For Y := H - 1 downto 0 Do
      For X := X0 to X1 Do
        If InView(X, DestY + Y) and InView(X, Y0 + Y) Then
          Pixels^[DestY + Y, X] := Pixels^[Y0 + Y, X];
  End;
End;

// ====================================================================
// Phase 1 — Screen State Management
// ====================================================================

Procedure TRIPEngine.SaveScreen (Slot: Byte);
Begin
  If Slot > 9 Then Exit;

  If SavedScreens[Slot] = Nil Then
    New(SavedScreens[Slot]);

  Move(Pixels^, SavedScreens[Slot]^, SizeOf(TRIPPixelBuffer));
End;

Procedure TRIPEngine.RestoreScreen (Slot: Byte);
Begin
  If Slot > 9 Then Exit;
  If SavedScreens[Slot] = Nil Then Exit;

  Move(SavedScreens[Slot]^, Pixels^, SizeOf(TRIPPixelBuffer));

  // Per RIPterm: RESTORE0-9 delete the save after restoring
  Dispose(SavedScreens[Slot]);
  SavedScreens[Slot] := Nil;
End;

Procedure TRIPEngine.SaveTextWin;
Begin
  SavedTW.Active := True;
  SavedTW.X0     := TextWinX0;
  SavedTW.Y0     := TextWinY0;
  SavedTW.X1     := TextWinX1;
  SavedTW.Y1     := TextWinY1;
  SavedTW.Size   := TextWinSize;
End;

Procedure TRIPEngine.RestoreTextWin;
Begin
  If Not SavedTW.Active Then Exit;

  TextWinX0   := SavedTW.X0;
  TextWinY0   := SavedTW.Y0;
  TextWinX1   := SavedTW.X1;
  TextWinY1   := SavedTW.Y1;
  TextWinSize := SavedTW.Size;

  SavedTW.Active := False;
End;

Procedure TRIPEngine.SaveMouseAll;
Var
  I : Integer;
Begin
  SavedMouse.Active   := True;
  SavedMouse.Count    := MouseCount;
  SavedMouse.TabIndex := NextTabIndex;
  SavedMouse.Focused  := FocusedField;

  For I := 1 to RIP_MAX_MOUSE Do
    SavedMouse.Fields[I] := MouseFields[I];
End;

Procedure TRIPEngine.RestoreMouseAll;
Var
  I : Integer;
Begin
  If Not SavedMouse.Active Then Exit;

  UnfocusField;

  MouseCount   := SavedMouse.Count;
  NextTabIndex := SavedMouse.TabIndex;
  FocusedField := SavedMouse.Focused;

  For I := 1 to RIP_MAX_MOUSE Do
    MouseFields[I] := SavedMouse.Fields[I];

  SavedMouse.Active := False;
End;

Procedure TRIPEngine.SaveClip;
Begin
  // Save the current GetImage clipboard to a backup
  If SavedClip <> Nil Then FreeMem(SavedClip, SavedClipSz);
  SavedClip   := Nil;
  SavedClipSz := 0;
  SavedClipW  := 0;
  SavedClipH  := 0;

  If (Clipboard <> Nil) and (ClipSize > 0) Then Begin
    GetMem(SavedClip, ClipSize);
    Move(Clipboard^, SavedClip^, ClipSize);
    SavedClipSz := ClipSize;
    SavedClipW  := ClipW;
    SavedClipH  := ClipH;
  End;
End;

Procedure TRIPEngine.RestoreClip;
Begin
  // Restore the saved clipboard
  If (SavedClip = Nil) or (SavedClipSz = 0) Then Exit;

  If Clipboard <> Nil Then FreeMem(Clipboard, ClipSize);

  GetMem(Clipboard, SavedClipSz);
  Move(SavedClip^, Clipboard^, SavedClipSz);
  ClipSize := SavedClipSz;
  ClipW    := SavedClipW;
  ClipH    := SavedClipH;
End;

Procedure TRIPEngine.SaveAll;
Begin
  SaveScreen(0);
  SaveTextWin;
  SaveClip;
  SaveMouseAll;
End;

Procedure TRIPEngine.RestoreAll;
Begin
  RestoreScreen(0);
  RestoreTextWin;
  RestoreClip;
  RestoreMouseAll;
End;

Function TRIPEngine.GetMaxX : SmallInt;
Begin
  Result := RIP_MAX_X;
End;

Function TRIPEngine.GetMaxY : SmallInt;
Begin
  Result := RIP_MAX_Y;
End;

// ---- CHR vector font loading ----

Function TRIPEngine.LoadCHR (AFontNum: Byte; FileName: String) : Boolean;
// Load a Borland BGI .CHR stroked font file
// Format: ASCII header ending with 0x1A, then binary prefix header,
// then stroke data starting with '+' (0x2B) signature
Type
  TLoadBuf = Array[0..32767] of Byte;
  PLoadBuf = ^TLoadBuf;
Var
  F        : File;
  Data     : PLoadBuf;
  FileLen  : LongInt;
  I, Pos   : Integer;
  PlusOff  : Integer;
  OtStart  : Integer;
  WtStart  : Integer;
  SkStart  : Integer;
  NC       : Word;
  FC       : Byte;
  B1, B2   : Byte;
  SX, SY   : SmallInt;
  Op       : Byte;
  SIdx     : Word;
  CharBase : Word;
Begin
  Result := False;

  If (AFontNum < 1) or (AFontNum > 10) Then Exit;

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  New(Data);

  FileLen := FileSize(F);
  If FileLen > SizeOf(Data^) Then FileLen := SizeOf(Data^);
  BlockRead(F, Data^, FileLen);
  Close(F);

  // Find '+' signature (0x2B) — marks start of stroke data header
  PlusOff := -1;
  For I := 80 to FileLen - 20 Do
    If Data^[I] = $2B Then Begin
      NC := Data^[I+1] OR (Data^[I+2] SHL 8);
      FC := Data^[I+4];
      If (NC >= 32) and (NC <= 256) and (FC >= 32) and (FC <= 127) Then Begin
        PlusOff := I;
        Break;
      End;
    End;

  If PlusOff < 0 Then Begin Dispose(Data); Exit; End;

  // Allocate font
  If CHRFonts[AFontNum] <> Nil Then Dispose(CHRFonts[AFontNum]);
  New(CHRFonts[AFontNum]);

  With CHRFonts[AFontNum]^ Do Begin
    Loaded    := True;
    NumChars  := NC;
    FirstChar := FC;

    // Metrics from header
    OrgToCap  := ShortInt(Data^[PlusOff + 8]);
    OrgToBase := ShortInt(Data^[PlusOff + 9]);
    OrgToDec  := ShortInt(Data^[PlusOff + 10]);

    // Font name from prefix (4 bytes at known offset)
    Name := '    ';

    // Offset table: NumChars * 2 bytes starting at PlusOff + 16
    OtStart := PlusOff + 16;
    For I := 0 to NumChars - 1 Do
      If I < RIP_MAX_CHR_CHARS Then
        Offsets[I] := Data^[OtStart + I*2] OR (Data^[OtStart + I*2 + 1] SHL 8);

    // Width table: NumChars bytes after offset table
    WtStart := OtStart + NumChars * 2;
    For I := 0 to NumChars - 1 Do
      If I < RIP_MAX_CHR_CHARS Then
        Widths[I] := Data^[WtStart + I];

    // Stroke data starts after width table
    SkStart := WtStart + NumChars;

    // Parse all strokes into our array
    NumStrokes := 0;

    For I := 0 to NumChars - 1 Do Begin
      If I >= RIP_MAX_CHR_CHARS Then Break;

      // Store the base offset for this character
      CharBase := NumStrokes;
      Offsets[I] := CharBase;

      Pos := SkStart + (Data[OtStart + I*2] OR (Data[OtStart + I*2 + 1] SHL 8));

      Repeat
        If (Pos + 1 >= FileLen) or (NumStrokes >= RIP_MAX_STROKES) Then Break;

        B1 := Data[Pos];
        B2 := Data[Pos + 1];

        SX := B1 AND $7F;
        SY := B2 AND $7F;
        If SX >= 64 Then SX := SX - 128;
        If SY >= 64 Then SY := SY - 128;

        // Opcode: b1 bit7 = pen flag, b2 bit7 = draw/move
        If (B1 AND $80 = 0) and (B2 AND $80 = 0) Then
          Op := 0   // end of character
        Else If (B2 AND $80 = 0) Then
          Op := 1   // move to (pen up)
        Else
          Op := 2;  // draw to (pen down)

        Strokes[NumStrokes].Op := Op;
        Strokes[NumStrokes].X  := SX;
        Strokes[NumStrokes].Y  := SY;
        Inc(NumStrokes);
        Inc(Pos, 2);
      Until Op = 0;
    End;
  End;

  Dispose(Data);
  Result := True;
End;

Procedure TRIPEngine.DrawTextCHR (X, Y: SmallInt; S: String; AFont, ASize: Byte);
// Render text using a loaded CHR vector font
Var
  I, J       : Integer;
  CharIdx    : Integer;
  CX, CY    : SmallInt;
  PenX, PenY : SmallInt;
  Scale      : SmallInt;
  StrokeOff  : Word;
  MaxStrokes : Word;
Begin
  If (AFont < 1) or (AFont > 10) Then Exit;
  If CHRFonts[AFont] = Nil Then Exit;
  If Not CHRFonts[AFont]^.Loaded Then Exit;

  If ASize = 0 Then ASize := 1;
  Scale := ASize;
  CX := X;

  With CHRFonts[AFont]^ Do Begin
    For I := 1 to Length(S) Do Begin
      CharIdx := Ord(S[I]) - FirstChar;

      If (CharIdx < 0) or (CharIdx >= NumChars) Then Begin
        Inc(CX, 8 * Scale);
        Continue;
      End;

      StrokeOff := Offsets[CharIdx];
      PenX := CX;
      PenY := Y;

      // Walk stroke commands for this character
      J := StrokeOff;
      While J < NumStrokes Do Begin
        Case Strokes[J].Op of
          0 : Break;  // end of character
          1 : Begin    // move to
                PenX := CX + Strokes[J].X * Scale;
                PenY := Y  - Strokes[J].Y * Scale;
              End;
          2 : Begin    // draw to
                DrawLine(PenX, PenY,
                         CX + Strokes[J].X * Scale,
                         Y  - Strokes[J].Y * Scale);
                PenX := CX + Strokes[J].X * Scale;
                PenY := Y  - Strokes[J].Y * Scale;
              End;
        End;

        Inc(J);
      End;

      Inc(CX, Widths[CharIdx] * Scale);
    End;
  End;

  Self.CurX := CX;
  Self.CurY := Y;
End;

// ====================================================================
// Line processing — handles continuation (\) and command extraction
// ====================================================================

Procedure TRIPEngine.ProcessLine (Line: String);
Var
  I   : Integer;
  Cmd : String;
Begin
  // Handle line continuation
  If Continued Then Begin
    LineBuf := LineBuf + Line;
    Continued := False;
  End Else
    LineBuf := Line;

  // Check for continuation (line ends with \, not \\)
  If (Length(LineBuf) > 0) and (LineBuf[Length(LineBuf)] = '\') Then Begin
    If (Length(LineBuf) < 2) or (LineBuf[Length(LineBuf) - 1] <> '\') Then Begin
      Delete(LineBuf, Length(LineBuf), 1);
      Continued := True;
      Exit;
    End;
  End;

  // Extract RIP commands from the line
  // Commands start with !| or SOH| or STX|
  I := 1;

  While I <= Length(LineBuf) Do Begin
    If ((LineBuf[I] = '!') or (LineBuf[I] = #1) or (LineBuf[I] = #2)) and
       (I < Length(LineBuf)) and (LineBuf[I + 1] = '|') Then Begin
      // Find end of RIP command (next !| or end of line)
      Inc(I, 2);  // skip !|
      Cmd := '';

      While (I <= Length(LineBuf)) Do Begin
        If ((LineBuf[I] = '!') or (LineBuf[I] = #1) or (LineBuf[I] = #2)) and
           (I < Length(LineBuf)) and (LineBuf[I + 1] = '|') Then
          Break;

        Cmd := Cmd + LineBuf[I];
        Inc(I);
      End;

      If Cmd <> '' Then
        ProcessCommand(Cmd);
    End Else
      Inc(I);
  End;
End;

// ====================================================================
// Command dispatcher
// ====================================================================

Procedure TRIPEngine.ProcessCommand (Cmd: String);
Var
  Level   : Integer;
  CmdChar : Char;
Begin
  If Length(Cmd) < 1 Then Exit;

  // Determine level
  If (Cmd[1] >= '0') and (Cmd[1] <= '9') Then Begin
    Level := Ord(Cmd[1]) - Ord('0');
    Delete(Cmd, 1, 1);

    // Check for sub-level digit
    If (Length(Cmd) > 0) and (Cmd[1] >= '0') and (Cmd[1] <= '9') Then
      Delete(Cmd, 1, 1);  // skip sub-level
  End Else
    Level := 0;

  If Length(Cmd) < 1 Then Exit;

  CmdChar := Cmd[1];
  Delete(Cmd, 1, 1);

  Case Level of
    0 : ParseLevel0(CmdChar, Cmd);
    1 : ParseLevel1(CmdChar, Cmd);
    9 : ParseLevel9(CmdChar, Cmd);
  End;
End;

// ====================================================================
// Level 0 commands — core graphics primitives
// ====================================================================

Procedure TRIPEngine.ParseLevel0 (Cmd: Char; Params: String);
Var
  P : Integer;
  X0, Y0, X1, Y1 : SmallInt;
  XR, YR, Radius  : SmallInt;
  SA, EA          : SmallInt;
  Style, Thick    : SmallInt;
  Color           : SmallInt;
  Count, I        : SmallInt;
  Points          : Array[0..RIP_MAX_POLY-1] of TRIPPoint;
  PatWord         : Word;
Begin
  P := 1;

  Case Cmd of
    // RIP_TEXT_WINDOW: w  x0(2) y0(2) x1(2) y1(2) wrap(1) size(1)
    'w' : Begin
            TextWinX0   := MegaNum(Params, P, 2);
            TextWinY0   := MegaNum(Params, P, 2);
            TextWinX1   := MegaNum(Params, P, 2);
            TextWinY1   := MegaNum(Params, P, 2);
            MegaNum(Params, P, 2);  // wrap mode (ignored server-side)
            TextWinSize := MegaNum(Params, P, 2);
          End;

    // RIP_VIEWPORT: v  x0(2) y0(2) x1(2) y1(2)
    'v' : Begin
            ViewX0 := MegaNum(Params, P, 2);
            ViewY0 := MegaNum(Params, P, 2);
            ViewX1 := MegaNum(Params, P, 2);
            ViewY1 := MegaNum(Params, P, 2);

            If (ViewX0 = 0) and (ViewY0 = 0) and
               (ViewX1 = 0) and (ViewY1 = 0) Then Begin
              ViewX0 := 0;
              ViewY0 := 0;
              ViewX1 := RIP_MAX_X;
              ViewY1 := RIP_MAX_Y;
            End;
          End;

    // RIP_RESET_WINDOWS: *
    '*' : Begin
            TextWinX0 := 0;  TextWinY0 := 0;
            TextWinX1 := 79; TextWinY1 := 42;
            TextWinSize := 0;
            ViewX0 := 0;     ViewY0 := 0;
            ViewX1 := RIP_MAX_X; ViewY1 := RIP_MAX_Y;
            // Per spec: reset windows also kills mouse fields
            KillAllMouseFields;
          End;

    // RIP_ERASE_WINDOW: e
    'e' : ClearScreen;

    // RIP_ERASE_VIEW: E
    'E' : ClearViewport;

    // RIP_GOTOXY: g  x(2) y(2)
    'g' : Begin
            CurX := MegaNum(Params, P, 2);
            CurY := MegaNum(Params, P, 2);
          End;

    // RIP_HOME: H
    'H' : Begin CurX := 0; CurY := 0; End;

    // RIP_ERASE_EOL: >
    '>' : Begin
            For X0 := CurX to ViewX1 Do
              DrawPixel(X0, CurY, 0);
          End;

    // RIP_COLOR: c  color(2)
    'c' : DrawColor := MegaNum(Params, P, 2);

    // RIP_SET_PALETTE: Q  c0..c15 (16 x 2 digits)
    'Q' : Begin
            For I := 0 to 15 Do
              Palette[I] := MegaNum(Params, P, 2);
          End;

    // RIP_ONE_PALETTE: a  color(2) value(2)
    'a' : Begin
            Color := MegaNum(Params, P, 2);
            If (Color >= 0) and (Color < RIP_MAX_COLORS) Then
              Palette[Color] := MegaNum(Params, P, 2);
          End;

    // RIP_WRITE_MODE: W  mode(2)
    'W' : WriteMode := MegaNum(Params, P, 2);

    // RIP_MOVE: m  x(2) y(2)
    'm' : Begin
            CurX := MegaNum(Params, P, 2);
            CurY := MegaNum(Params, P, 2);
          End;

    // RIP_TEXT: T  text...
    'T' : OutText(Params);

    // RIP_TEXT_XY: @  x(2) y(2) text...
    '@' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            OutTextXY(X0, Y0, Copy(Params, P, Length(Params)));
          End;

    // RIP_FONT_STYLE: Y  font(2) dir(2) size(2) res(2)
    'Y' : Begin
            FontNum  := MegaNum(Params, P, 2);
            FontDir  := MegaNum(Params, P, 2);
            FontSize := MegaNum(Params, P, 2);
            If P <= Length(Params) Then MegaNum(Params, P, 2);  // reserved
          End;

    // RIP_PIXEL: X  x(2) y(2)
    'X' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            DrawPixel(X0, Y0, DrawColor);
          End;

    // RIP_LINE: L  x0(2) y0(2) x1(2) y1(2)
    'L' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            DrawLine(X0, Y0, X1, Y1);
          End;

    // RIP_RECTANGLE: R  x0(2) y0(2) x1(2) y1(2)
    'R' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            DrawRect(X0, Y0, X1, Y1);
          End;

    // RIP_BAR: B  x0(2) y0(2) x1(2) y1(2)
    'B' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            DrawBar(X0, Y0, X1, Y1);
          End;

    // RIP_CIRCLE: C  xc(2) yc(2) radius(2)
    'C' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            Radius := MegaNum(Params, P, 2);
            DrawCircle(X0, Y0, Radius);
          End;

    // RIP_OVAL: O  xc(2) yc(2) start(2) end(2) xr(2) yr(2)
    'O' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);  // start angle (unused for oval outline)
            EA := MegaNum(Params, P, 2);  // end angle
            XR := MegaNum(Params, P, 2);
            YR := MegaNum(Params, P, 2);
            DrawOval(X0, Y0, XR, YR);
          End;

    // RIP_FILLED_OVAL: o  xc(2) yc(2) xr(2) yr(2)
    'o' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            XR := MegaNum(Params, P, 2);
            YR := MegaNum(Params, P, 2);
            DrawFilledOval(X0, Y0, XR, YR);
          End;

    // RIP_ARC: A  xc(2) yc(2) start(2) end(2) radius(2)
    'A' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);
            EA := MegaNum(Params, P, 2);
            Radius := MegaNum(Params, P, 2);
            DrawArc(X0, Y0, SA, EA, Radius);
          End;

    // RIP_OVAL_ARC: V  xc(2) yc(2) sa(2) ea(2) xr(2) yr(2)
    'V' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);
            EA := MegaNum(Params, P, 2);
            XR := MegaNum(Params, P, 2);
            YR := MegaNum(Params, P, 2);
            DrawOvalArc(X0, Y0, SA, EA, XR, YR);
          End;

    // RIP_PIE_SLICE: I  xc(2) yc(2) sa(2) ea(2) radius(2)
    'I' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);
            EA := MegaNum(Params, P, 2);
            Radius := MegaNum(Params, P, 2);
            DrawPieSlice(X0, Y0, SA, EA, Radius);
          End;

    // RIP_OVAL_PIE_SLICE: i  xc(2) yc(2) sa(2) ea(2) xr(2) yr(2)
    'i' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);
            EA := MegaNum(Params, P, 2);
            XR := MegaNum(Params, P, 2);
            YR := MegaNum(Params, P, 2);
            DrawOvalPie(X0, Y0, SA, EA, XR, YR);
          End;

    // RIP_BEZIER: Z  x0(2) y0(2) x1(2) y1(2) x2(2) y2(2) x3(2) y3(2) cnt(2)
    'Z' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            XR := MegaNum(Params, P, 2);
            YR := MegaNum(Params, P, 2);
            SA := MegaNum(Params, P, 2);
            EA := MegaNum(Params, P, 2);
            Count := MegaNum(Params, P, 2);
            DrawBezier(X0, Y0, X1, Y1, XR, YR, SA, EA, Count);
          End;

    // RIP_POLYGON: P  npoints(2) x0(2) y0(2) x1(2) y1(2) ...
    'P' : Begin
            Count := MegaNum(Params, P, 2);
            If Count > RIP_MAX_POLY Then Count := RIP_MAX_POLY;

            For I := 0 to Count - 1 Do Begin
              Points[I].X := MegaNum(Params, P, 2);
              Points[I].Y := MegaNum(Params, P, 2);
            End;

            DrawPolygon(Points, Count);
          End;

    // RIP_FILL_POLYGON: p  npoints(2) x0(2) y0(2) ...
    'p' : Begin
            Count := MegaNum(Params, P, 2);
            If Count > RIP_MAX_POLY Then Count := RIP_MAX_POLY;

            For I := 0 to Count - 1 Do Begin
              Points[I].X := MegaNum(Params, P, 2);
              Points[I].Y := MegaNum(Params, P, 2);
            End;

            DrawFillPoly(Points, Count);
          End;

    // RIP_POLYLINE: l  npoints(2) x0(2) y0(2) ...
    'l' : Begin
            Count := MegaNum(Params, P, 2);
            If Count > RIP_MAX_POLY Then Count := RIP_MAX_POLY;

            For I := 0 to Count - 1 Do Begin
              Points[I].X := MegaNum(Params, P, 2);
              Points[I].Y := MegaNum(Params, P, 2);
            End;

            DrawPolyLine(Points, Count);
          End;

    // RIP_FILL: F  x(2) y(2) border(2)
    'F' : Begin
            X0    := MegaNum(Params, P, 2);
            Y0    := MegaNum(Params, P, 2);
            Color := MegaNum(Params, P, 2);
            FloodFill(X0, Y0, Color);
          End;

    // RIP_LINE_STYLE: =  style(2) user_pat(4) thick(2)
    '=' : Begin
            LineStyle   := MegaNum(Params, P, 2);
            PatWord     := MegaNum(Params, P, 4);
            LineThick   := MegaNum(Params, P, 2);
            LinePattern := PatWord;
          End;

    // RIP_FILL_STYLE: S  style(2) color(2)
    'S' : Begin
            FillStyle := MegaNum(Params, P, 2);
            FillColor := MegaNum(Params, P, 2);
          End;

    // RIP_FILL_PATTERN: s  c1..c8(8x2) color(2)
    's' : Begin
            For I := 0 to 7 Do
              FillPat[I] := MegaNum(Params, P, 2);
            FillColor := MegaNum(Params, P, 2);
            FillStyle := RIP_FILL_USER;
          End;

    // RIP_NO_MORE: #
    '#' : ; // no-op, marks end of RIP sequences
  End;
End;

// ====================================================================
// Level 1 commands — mouse, buttons, icons, text regions
// ====================================================================

Procedure TRIPEngine.ParseLevel1 (Cmd: Char; Params: String);
Var
  P    : Integer;
  X0, Y0, X1, Y1 : SmallInt;
  I    : Integer;
  IconFN, LabelTxt, BtnHostCmd : String;
  IsRadio, IsCheck, InitSel : Boolean;
Begin
  P := 1;

  Case Cmd of
    // RIP_MOUSE: M  x0(2) y0(2) x1(2) y1(2) clk(2) flags(1) text
    'M' : Begin
            If MouseCount < RIP_MAX_MOUSE Then Begin
              Inc(MouseCount);

              With MouseFields[MouseCount] Do Begin
                Active := True;
                X0 := MegaNum(Params, P, 2);
                Y0 := MegaNum(Params, P, 2);
                X1 := MegaNum(Params, P, 2);
                Y1 := MegaNum(Params, P, 2);
                MegaNum(Params, P, 2);  // click style
                If P <= Length(Params) Then Inc(P);  // flags

                // Rest is host command ^ status text
                HostCmd := '';
                Text    := '';
                Invert  := False;
                IsButton    := False;
                IsRadio     := False;
                IsCheckbox  := False;
                GroupID     := 0;
                Selected    := False;
                IconFile    := '';
                HotIconFile := '';

                While (P <= Length(Params)) and (Params[P] <> '^') Do Begin
                  HostCmd := HostCmd + Params[P];
                  Inc(P);
                End;

                If (P <= Length(Params)) and (Params[P] = '^') Then Inc(P);

                While P <= Length(Params) Do Begin
                  Text := Text + Params[P];
                  Inc(P);
                End;
              End;
            End;
          End;

    // RIP_KILL_MOUSE_FIELDS: K  (no params = kill all, or num(2))
    'K' : Begin
            If Length(Params) = 0 Then
              KillAllMouseFields
            Else Begin
              I := MegaNum(Params, P, 2);
              KillMouseField(I);
            End;
          End;

    // RIP_BEGIN_TEXT: T  x(2) y(2) sizeY(2) sizeX(2) (begins text block)
    'T' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            // Text block — text follows on subsequent lines until !|1t or !|1E
            CurX := X0;
            CurY := Y0;
          End;

    // RIP_REGION_TEXT: t  (continue text block, line of text)
    't' : Begin
            OutTextXY(CurX, CurY, Params);
            CurY := CurY + GetSysFontH;
          End;

    // RIP_END_TEXT: E  (end text block)
    'E' : ;  // no-op — just marks end of text block

    // RIP_GET_IMAGE: C  x0(2) y0(2) x1(2) y1(2) res(2)
    'C' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            // Capture to clipboard
            If Clipboard <> Nil Then FreeMem(Clipboard, ClipSize);
            ClipSize := ImageSize(X0, Y0, X1, Y1);
            ClipW := X1 - X0 + 1;
            ClipH := Y1 - Y0 + 1;
            GetMem(Clipboard, ClipSize);
            GetImage(X0, Y0, X1, Y1, Clipboard^);
          End;

    // RIP_PUT_IMAGE: P  x(2) y(2) mode(2) res(2)
    'P' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            I  := MegaNum(Params, P, 2);  // mode
            If Clipboard <> Nil Then
              PutImage(X0, Y0, Clipboard^, I);
          End;

    // RIP_WRITE_ICON: W  res(2) filename
    'W' : Begin
            MegaNum(Params, P, 2);  // reserved
            // WriteIcon saves clipboard to file — for now, no-op
            // (clipboard is in GetImage format, not directly saveable as ICN
            //  without first PutImage'ing it back to screen)
          End;

    // RIP_LOAD_ICON: I  x(2) y(2) mode(2) clip(1) res(2) filename
    'I' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            I  := MegaNum(Params, P, 2);  // mode (write mode)
            If P <= Length(Params) Then Inc(P);  // clipboard flag
            MegaNum(Params, P, 2);  // reserved
            // Remaining is filename
            If P <= Length(Params) Then
              LoadIcon(Copy(Params, P, Length(Params)), X0, Y0, I);
          End;

    // RIP_BUTTON_STYLE: B  wid(2) hgt(2) orient(2) flags(4)
    //   dfore(2) dback(2) bright(2) dark(2) surface(2)
    //   grp(2) flags2(2) uline(2) corner(2)
    'B' : Begin
            BtnStyle.Width     := MegaNum(Params, P, 2);
            BtnStyle.Height    := MegaNum(Params, P, 2);
            BtnStyle.Orient    := MegaNum(Params, P, 2);
            BtnStyle.Flags     := MegaNum(Params, P, 4);
            BtnStyle.DFore     := MegaNum(Params, P, 2);
            BtnStyle.DBack     := MegaNum(Params, P, 2);
            BtnStyle.BRight    := MegaNum(Params, P, 2);
            BtnStyle.DDark     := MegaNum(Params, P, 2);
            BtnStyle.Surface   := MegaNum(Params, P, 2);
            BtnStyle.GrpID     := MegaNum(Params, P, 2);
            BtnStyle.Flags2    := MegaNum(Params, P, 2);
            BtnStyle.ULineCol  := MegaNum(Params, P, 2);
            BtnStyle.CornerCol := MegaNum(Params, P, 2);
          End;

    // RIP_BUTTON: U  x0(2) y0(2) x1(2) y1(2) hotkey(2) flags(1)
    //   <>icon_file<>label<>hostcmd  (delimited by <>)
    'U' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            I  := MegaNum(Params, P, 2);  // hotkey (ASCII code)
            If P <= Length(Params) Then Inc(P);  // flags

            // Parse <>delimited fields: icon<>label<>hostcmd
            IconFN     := '';
            LabelTxt   := '';
            BtnHostCmd := '';

            // Skip leading <>
            If (P + 1 <= Length(Params)) and (Params[P] = '<') and (Params[P+1] = '>') Then
              Inc(P, 2);

            // Read icon filename until <>
            While (P <= Length(Params)) Do Begin
              If (P + 1 <= Length(Params)) and (Params[P] = '<') and (Params[P+1] = '>') Then Begin
                Inc(P, 2);
                Break;
              End;
              IconFN := IconFN + Params[P];
              Inc(P);
            End;

            // Read label until <>
            While (P <= Length(Params)) Do Begin
              If (P + 1 <= Length(Params)) and (Params[P] = '<') and (Params[P+1] = '>') Then Begin
                Inc(P, 2);
                Break;
              End;
              LabelTxt := LabelTxt + Params[P];
              Inc(P);
            End;

            // Rest is host command
            While (P <= Length(Params)) Do Begin
              BtnHostCmd := BtnHostCmd + Params[P];
              Inc(P);
            End;

            // Determine button type from BtnStyle.Flags
            IsRadio := (BtnStyle.Flags AND $0002) <> 0;
            IsCheck := (BtnStyle.Flags AND $0004) <> 0;
            InitSel := (BtnStyle.Flags AND $0008) <> 0;

            DrawButtonEx(X0, Y0, X1, Y1, LabelTxt, BtnHostCmd,
                         IconFN, '', IsRadio, IsCheck, InitSel);

            // Override hotkey if specified in RIP command
            If (I > 0) and (I < 128) and (MouseCount > 0) Then
              MouseFields[MouseCount].HotKey := Chr(I);
          End;

    // RIP_DEFINE: D  flags(3) res(2) text_var,size:?question?default
    'D' : Begin
            I := MegaNum(Params, P, 3);  // flags
            MegaNum(Params, P, 2);       // reserved

            // Parse variable name until , or : or end
            X0 := P;
            While (P <= Length(Params)) and (Params[P] <> ',') and (Params[P] <> ':') Do
              Inc(P);

            IconFN := Copy(Params, X0, P - X0);  // reuse var for name

            // Skip ,size if present
            If (P <= Length(Params)) and (Params[P] = ',') Then Begin
              Inc(P);
              While (P <= Length(Params)) and (Params[P] <> ':') Do Inc(P);
            End;

            // Parse default value: after :?question? comes default
            LabelTxt := '';  // reuse var for default value
            If (P <= Length(Params)) and (Params[P] = ':') Then Begin
              Inc(P);
              // Skip ?question? if present
              If (P <= Length(Params)) and (Params[P] = '?') Then Begin
                Inc(P);
                While (P <= Length(Params)) and (Params[P] <> '?') Do Inc(P);
                If P <= Length(Params) Then Inc(P);  // skip closing ?
              End;
              // Rest is default value
              LabelTxt := Copy(Params, P, Length(Params));
            End;

            DefineVar(
              IconFN,                   // name
              LabelTxt,                 // default value
              (I AND 1) <> 0,           // persist flag
              (I AND 2) <> 0            // required flag
            );
          End;

    // RIP_COPY_REGION: G  x0(2) y0(2) x1(2) y1(2) res(2) dest_line(2)
    'G' : Begin
            X0 := MegaNum(Params, P, 2);
            Y0 := MegaNum(Params, P, 2);
            X1 := MegaNum(Params, P, 2);
            Y1 := MegaNum(Params, P, 2);
            MegaNum(Params, P, 2);  // reserved
            I  := MegaNum(Params, P, 2);  // dest_line
            CopyRegion(X0, Y0, X1, Y1, I);
          End;

    // RIP_READ_SCENE: R  res(2) filename
    'R' : Begin
            MegaNum(Params, P, 2);  // reserved
            If P <= Length(Params) Then
              LoadScene(Copy(Params, P, Length(Params)));
          End;

    // RIP_FILE_QUERY: F  mode(2) res(4) filename
    'F' : Begin
            I := MegaNum(Params, P, 2);   // mode
            MegaNum(Params, P, 4);        // reserved
            // File query result would be sent back to host
            // Server-side: just do the query, caller reads result
            FileQuery(Copy(Params, P, Length(Params)), I);
          End;
  End;
End;

// ====================================================================
// Level 9 commands — system/block mode
// ====================================================================

Procedure TRIPEngine.ParseLevel9 (Cmd: Char; Params: String);
Begin
  // RIP_ENTER_BLOCK_MODE: handled externally
  // Level 9 commands are system-level (file transfer, etc)
End;

End.

(* htmllayo.pas -- HTML 1.0 Layout Engine
   Copyright (C) 2026 Mystic BBS IRC Fork Contributors
   Licensed under GNU General Public License v3.

   Simple box model layout: computes position and size for each
   node in the DOM tree. Handles text flow, line breaking, margins,
   headings, lists, and basic table layout.

   No CSS — uses fixed default styles per tag.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit htmllayo;

interface

Uses htmlpars, htmltree;

Const
  HTML_MAX_BOXES = 128;

Type
  THTMLDisplayMode = (
    hdBlock,     // P, H1-H6, DIV, HR, TABLE, UL, OL, BLOCKQUOTE
    hdInline,    // B, I, U, TT, A, FONT, EM, STRONG, SMALL, SUB, SUP
    hdListItem,  // LI
    hdTableRow,  // TR
    hdTableCell, // TD, TH
    hdNone       // HEAD, TITLE, META, STYLE
  );

  THTMLFontStyle = record
    Bold      : Boolean;
    Italic    : Boolean;
    Underline : Boolean;
    Mono      : Boolean;     // TT, PRE
    Size      : Byte;        // font height in pixels (8, 14, 16, 20, 24, 28)
    ColorR    : Byte;
    ColorG    : Byte;
    ColorB    : Byte;
  end;

  PHTMLBox = ^THTMLBox;
  THTMLBox = record
    Node       : PHTMLNode;  // back-reference to DOM node
    X, Y       : SmallInt;   // position (pixels)
    W, H       : SmallInt;   // size (pixels)
    MarginTop  : SmallInt;
    MarginBot  : SmallInt;
    MarginLeft : SmallInt;
    Indent     : SmallInt;   // text indent (for lists, blockquote)
    Display    : THTMLDisplayMode;
    Font       : THTMLFontStyle;
    IsBreak    : Boolean;    // line break after this box
    ListIndex  : Integer;    // OL counter
  end;

  THTMLLayout = record
    Boxes      : Array[0..HTML_MAX_BOXES-1] of THTMLBox;
    BoxCount   : Integer;
    PageWidth  : SmallInt;    // available width (pixels)
    PageHeight : SmallInt;    // available height (pixels)
    CursorX    : SmallInt;    // current X for inline flow
    CursorY    : SmallInt;    // current Y for block flow
    LineHeight : SmallInt;    // current line height
  end;

// Compute layout for the entire tree
procedure HTMLLayoutCompute(var Layout: THTMLLayout; var Tree: THTMLTree;
                            PageW, PageH: SmallInt);

// Reset layout
procedure HTMLLayoutReset(var Layout: THTMLLayout);

// Get display mode for a tag
function HTMLGetDisplay(ID: THTMLTagID): THTMLDisplayMode;

// Get default font style for a tag
function HTMLGetDefaultFont(ID: THTMLTagID): THTMLFontStyle;

// Parse HTML color string (#RRGGBB or named) to RGB bytes
procedure ParseHTMLColor(const S: String; var R, G, B: Byte);

implementation

function HTMLGetDisplay(ID: THTMLTagID): THTMLDisplayMode;
Begin
  Case ID of
    htP, htDIV, htBLOCKQUOTE, htCENTER, htPRE,
    htH1, htH2, htH3, htH4, htH5, htH6,
    htHR, htUL, htOL, htDL,
    htTABLE, htFORM:
      Result := hdBlock;

    htLI, htDT, htDD:
      Result := hdListItem;

    htTR:
      Result := hdTableRow;

    htTD, htTH, htCAPTION:
      Result := hdTableCell;

    htHEAD, htTITLE, htMETA:
      Result := hdNone;
  Else
    Result := hdInline;
  End;
End;

function MakeFont(ABold, AItalic, AUnderline, AMono: Boolean;
                  ASize, AR, AG, AB: Byte): THTMLFontStyle;
Begin
  Result.Bold      := ABold;
  Result.Italic    := AItalic;
  Result.Underline := AUnderline;
  Result.Mono      := AMono;
  Result.Size      := ASize;
  Result.ColorR    := AR;
  Result.ColorG    := AG;
  Result.ColorB    := AB;
End;

function HTMLGetDefaultFont(ID: THTMLTagID): THTMLFontStyle;
Begin
  // Default: normal 14px black
  Result := MakeFont(False, False, False, False, 14, 0, 0, 0);

  Case ID of
    htH1:     Result := MakeFont(True,  False, False, False, 28, 0, 0, 0);
    htH2:     Result := MakeFont(True,  False, False, False, 24, 0, 0, 0);
    htH3:     Result := MakeFont(True,  False, False, False, 20, 0, 0, 0);
    htH4:     Result := MakeFont(True,  False, False, False, 16, 0, 0, 0);
    htH5:     Result := MakeFont(True,  False, False, False, 14, 0, 0, 0);
    htH6:     Result := MakeFont(True,  False, False, False, 14, 128, 128, 128);
    htB, htSTRONG: Result.Bold := True;
    htI, htEM:     Result.Italic := True;
    htU:           Result.Underline := True;
    htTT, htPRE:   Result.Mono := True;
    htSMALL:       Result.Size := 10;
    htA:     Begin
               Result.Underline := True;
               Result.ColorR := 0; Result.ColorG := 0; Result.ColorB := 255;
             End;
  End;
End;

function GetMarginTop(ID: THTMLTagID): SmallInt;
Begin
  Case ID of
    htH1:         Result := 16;
    htH2:         Result := 14;
    htH3:         Result := 12;
    htH4, htH5, htH6: Result := 10;
    htP:          Result := 8;
    htUL, htOL, htDL: Result := 8;
    htBLOCKQUOTE: Result := 10;
    htHR:         Result := 6;
    htTABLE:      Result := 8;
  Else
    Result := 0;
  End;
End;

function GetMarginBot(ID: THTMLTagID): SmallInt;
Begin
  Case ID of
    htH1:         Result := 12;
    htH2:         Result := 10;
    htH3:         Result := 8;
    htH4, htH5, htH6: Result := 6;
    htP:          Result := 8;
    htUL, htOL, htDL: Result := 8;
    htBLOCKQUOTE: Result := 10;
    htHR:         Result := 6;
    htTABLE:      Result := 8;
  Else
    Result := 0;
  End;
End;

function GetIndent(ID: THTMLTagID): SmallInt;
Begin
  Case ID of
    htLI, htDD:   Result := 20;
    htBLOCKQUOTE: Result := 30;
  Else
    Result := 0;
  End;
End;

// Parse #RRGGBB or named color to RGB bytes
procedure ParseHTMLColor(const S: String; var R, G, B: Byte);
Var
  Code : Integer;
  Val  : LongInt;
Begin
  If (Length(S) >= 7) and (S[1] = '#') Then Begin
    System.Val('$' + Copy(S, 2, 2), Val, Code);
    If Code = 0 Then R := Byte(Val);
    System.Val('$' + Copy(S, 4, 2), Val, Code);
    If Code = 0 Then G := Byte(Val);
    System.Val('$' + Copy(S, 6, 2), Val, Code);
    If Code = 0 Then B := Byte(Val);
  End Else If S = 'red'     Then Begin R := 255; G := 0;   B := 0; End
  Else If S = 'green'       Then Begin R := 0;   G := 128; B := 0; End
  Else If S = 'blue'        Then Begin R := 0;   G := 0;   B := 255; End
  Else If S = 'white'       Then Begin R := 255; G := 255; B := 255; End
  Else If S = 'black'       Then Begin R := 0;   G := 0;   B := 0; End
  Else If S = 'yellow'      Then Begin R := 255; G := 255; B := 0; End
  Else If S = 'cyan'        Then Begin R := 0;   G := 255; B := 255; End
  Else If S = 'magenta'     Then Begin R := 255; G := 0;   B := 255; End
  Else If S = 'gray'        Then Begin R := 128; G := 128; B := 128; End
  Else If S = 'silver'      Then Begin R := 192; G := 192; B := 192; End;
End;

// Estimate text width based on font size and character count
function EstimateTextWidth(const Text: String; FontSize: Byte; Mono: Boolean): SmallInt;
Var CharW : SmallInt;
Begin
  If Mono Then
    CharW := (FontSize * 6) DIV 10  // ~0.6 × height for mono
  Else
    CharW := (FontSize * 5) DIV 10; // ~0.5 × height for proportional
  If CharW < 4 Then CharW := 4;
  Result := Length(Text) * CharW;
End;

procedure HTMLLayoutReset(var Layout: THTMLLayout);
Begin
  Layout.BoxCount   := 0;
  Layout.CursorX    := 0;
  Layout.CursorY    := 0;
  Layout.LineHeight := 14;
End;

procedure LayoutNode(var Layout: THTMLLayout; Node: PHTMLNode;
                     ParentFont: THTMLFontStyle; AvailWidth: SmallInt;
                     Indent: SmallInt; var OLCounter: Integer);
Var
  Box      : PHTMLBox;
  Child    : PHTMLNode;
  Display  : THTMLDisplayMode;
  Font     : THTMLFontStyle;
  TextW    : SmallInt;
  ChildInd : SmallInt;
  ChildOL  : Integer;
  FontAttr : String;
  FontVal  : Integer;
  FontCode : Integer;
  CellCount : Integer;
  CellWidth : SmallInt;
  CellIdx   : Integer;
  SaveY     : SmallInt;
  MaxCellH  : SmallInt;
Begin
  If Node = Nil Then Exit;
  If Layout.BoxCount >= HTML_MAX_BOXES Then Exit;

  // Text node
  If Node^.Kind = hnkText Then Begin
    If Length(Node^.Text) = 0 Then Exit;
    Box := @Layout.Boxes[Layout.BoxCount];
    Inc(Layout.BoxCount);
    Box^.Node      := Node;
    Box^.Display   := hdInline;
    Box^.Font      := ParentFont;
    Box^.Indent    := Indent;
    Box^.IsBreak   := False;
    Box^.ListIndex := 0;

    TextW := EstimateTextWidth(Node^.Text, ParentFont.Size, ParentFont.Mono);

    // Word wrap: if text exceeds remaining line width, break
    If Layout.CursorX + TextW > AvailWidth Then Begin
      Layout.CursorX := Indent;
      Layout.CursorY := Layout.CursorY + Layout.LineHeight;
      Layout.LineHeight := ParentFont.Size + 2;
    End;

    Box^.X := Layout.CursorX;
    Box^.Y := Layout.CursorY;
    Box^.W := TextW;
    Box^.H := ParentFont.Size;

    If ParentFont.Size + 2 > Layout.LineHeight Then
      Layout.LineHeight := ParentFont.Size + 2;

    Layout.CursorX := Layout.CursorX + TextW;
    Exit;
  End;

  // Comment / DOCTYPE — skip
  If Node^.Kind <> hnkElement Then Exit;

  Display := HTMLGetDisplay(Node^.TagID);
  If Display = hdNone Then Exit;

  Font := HTMLGetDefaultFont(Node^.TagID);
  // Inherit parent color for inline tags that don't override
  If Not (Node^.TagID in [htA, htH6]) Then Begin
    Font.ColorR := ParentFont.ColorR;
    Font.ColorG := ParentFont.ColorG;
    Font.ColorB := ParentFont.ColorB;
  End;
  // Inherit bold/italic from parent for non-heading inline
  If Display = hdInline Then Begin
    If ParentFont.Bold and Not Font.Bold Then Font.Bold := True;
    If ParentFont.Italic and Not Font.Italic Then Font.Italic := True;
    If ParentFont.Mono Then Font.Mono := True;
  End;

  // FONT tag: parse SIZE and COLOR attributes
  If Node^.TagID = htFONT Then Begin
    FontAttr := HTMLNodeGetAttr(Node, 'SIZE');
    If Length(FontAttr) > 0 Then Begin
      Val(FontAttr, FontVal, FontCode);
      If FontCode = 0 Then Begin
        Case FontVal of
          1: Font.Size := 8;
          2: Font.Size := 10;
          3: Font.Size := 14;
          4: Font.Size := 16;
          5: Font.Size := 20;
          6: Font.Size := 24;
          7: Font.Size := 28;
        End;
      End;
    End;
    FontAttr := HTMLNodeGetAttr(Node, 'COLOR');
    If Length(FontAttr) > 0 Then
      ParseHTMLColor(FontAttr, Font.ColorR, Font.ColorG, Font.ColorB);
  End;

  // BODY tag: parse BGCOLOR
  If Node^.TagID = htBODY Then Begin
    FontAttr := HTMLNodeGetAttr(Node, 'BGCOLOR');
    // BGCOLOR stored but applied by renderer, not layout
  End;

  Box := @Layout.Boxes[Layout.BoxCount];
  Inc(Layout.BoxCount);
  Box^.Node      := Node;
  Box^.Display   := Display;
  Box^.Font      := Font;
  Box^.MarginTop := GetMarginTop(Node^.TagID);
  Box^.MarginBot := GetMarginBot(Node^.TagID);
  Box^.MarginLeft:= 0;
  Box^.Indent    := Indent + GetIndent(Node^.TagID);
  Box^.IsBreak   := False;
  Box^.ListIndex := 0;

  // Block elements: new line
  If Display = hdBlock Then Begin
    Layout.CursorX := Box^.Indent;
    Layout.CursorY := Layout.CursorY + Layout.LineHeight + Box^.MarginTop;
    Layout.LineHeight := Font.Size + 2;
  End;

  // HR: special — horizontal rule
  If Node^.TagID = htHR Then Begin
    Box^.X := Box^.Indent;
    Box^.Y := Layout.CursorY;
    Box^.W := AvailWidth - Box^.Indent;
    Box^.H := 2;
    Layout.CursorY := Layout.CursorY + 2 + Box^.MarginBot;
    Layout.CursorX := Box^.Indent;
    Exit;
  End;

  // BR: line break
  If Node^.TagID = htBR Then Begin
    Layout.CursorX := Indent;
    Layout.CursorY := Layout.CursorY + Layout.LineHeight;
    Layout.LineHeight := Font.Size + 2;
    Box^.X := Layout.CursorX;
    Box^.Y := Layout.CursorY;
    Box^.W := 0;
    Box^.H := 0;
    Exit;
  End;

  // List item: bullet/number prefix
  If Display = hdListItem Then Begin
    Layout.CursorX := Box^.Indent;
    Layout.CursorY := Layout.CursorY + Layout.LineHeight;
    Layout.LineHeight := Font.Size + 2;
    If Node^.TagID = htLI Then Begin
      Inc(OLCounter);
      Box^.ListIndex := OLCounter;
    End;
  End;

  // TABLE: children are TR rows
  If Node^.TagID = htTABLE Then Begin
    Box^.X := Layout.CursorX;
    Box^.Y := Layout.CursorY;
    Box^.W := AvailWidth - Layout.CursorX;
    Box^.H := Font.Size;
    ChildInd := Box^.Indent;
    ChildOL := 0;
    Child := Node^.FirstChild;
    While Child <> Nil Do Begin
      LayoutNode(Layout, Child, Font, AvailWidth, ChildInd, ChildOL);
      Child := Child^.NextSib;
    End;
    Box^.H := Layout.CursorY - Box^.Y;
    Layout.CursorY := Layout.CursorY + Box^.MarginBot;
    Layout.CursorX := Indent;
    Exit;
  End;

  // TR: layout cells horizontally
  If Display = hdTableRow Then Begin
    Box^.X := Layout.CursorX;
    Box^.Y := Layout.CursorY;
    Box^.W := AvailWidth - Layout.CursorX;
    Box^.H := Font.Size;

    // Count cells in this row
    CellCount := 0;
    Child := Node^.FirstChild;
    While Child <> Nil Do Begin
      If (Child^.Kind = hnkElement) and
         (Child^.TagID in [htTD, htTH]) Then
        Inc(CellCount);
      Child := Child^.NextSib;
    End;
    If CellCount = 0 Then CellCount := 1;
    CellWidth := Box^.W DIV CellCount;

    // Layout each cell with fixed column width
    SaveY := Layout.CursorY;
    MaxCellH := Font.Size;
    CellIdx := 0;
    Child := Node^.FirstChild;
    While Child <> Nil Do Begin
      If (Child^.Kind = hnkElement) and
         (Child^.TagID in [htTD, htTH]) Then Begin
        Layout.CursorX := Box^.X + (CellIdx * CellWidth);
        Layout.CursorY := SaveY;
        Layout.LineHeight := Font.Size + 2;
        LayoutNode(Layout, Child, Font,
                   Box^.X + ((CellIdx + 1) * CellWidth),
                   Box^.X + (CellIdx * CellWidth), ChildOL);
        If Layout.CursorY + Layout.LineHeight - SaveY > MaxCellH Then
          MaxCellH := Layout.CursorY + Layout.LineHeight - SaveY;
        Inc(CellIdx);
      End;
      Child := Child^.NextSib;
    End;

    Layout.CursorY := SaveY + MaxCellH;
    Layout.CursorX := Indent;
    Box^.H := MaxCellH;
    Exit;
  End;

  Box^.X := Layout.CursorX;
  Box^.Y := Layout.CursorY;
  Box^.W := AvailWidth - Layout.CursorX;
  Box^.H := Font.Size;

  // Layout children
  ChildInd := Box^.Indent;
  ChildOL  := 0;
  If Node^.TagID in [htOL] Then ChildOL := 0;
  Child := Node^.FirstChild;
  While Child <> Nil Do Begin
    LayoutNode(Layout, Child, Font, AvailWidth, ChildInd, ChildOL);
    Child := Child^.NextSib;
  End;

  // After block element: add bottom margin
  If Display = hdBlock Then Begin
    Layout.CursorX := Indent;
    Layout.CursorY := Layout.CursorY + Layout.LineHeight + Box^.MarginBot;
    Layout.LineHeight := ParentFont.Size + 2;
  End;

  // Update box height to encompass children
  Box^.H := Layout.CursorY - Box^.Y;
  If Box^.H < Font.Size Then Box^.H := Font.Size;
End;

procedure HTMLLayoutCompute(var Layout: THTMLLayout; var Tree: THTMLTree;
                            PageW, PageH: SmallInt);
Var
  DefaultFont : THTMLFontStyle;
  OLCounter   : Integer;
Begin
  HTMLLayoutReset(Layout);
  Layout.PageWidth  := PageW;
  Layout.PageHeight := PageH;

  DefaultFont := MakeFont(False, False, False, False, 14, 192, 192, 192);
  OLCounter := 0;

  If Tree.Root <> Nil Then
    LayoutNode(Layout, Tree.Root, DefaultFont, PageW, 0, OLCounter);
End;

end.

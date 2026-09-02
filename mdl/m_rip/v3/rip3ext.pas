{$MODE DELPHI}
{$H-}
Unit RIP3Ext;
{ RIPscrip v3.0 Extensions
  Imports v1 shared base. Does NOT import v2 — flat hierarchy.
  Adds: data tables, form fields, MAF fonts, pixel format conversion,
  image buffers, variable system, progressive rendering hooks.

  Source reference: attic/rip_v2v3v4_monolith/rip3api.pas (8358 lines)
  This unit extracts only the v3-specific extensions.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses
  RIPEngine;

Const
  RIP_MAX_TABLE_COLS  = 16;
  RIP_MAX_TABLE_ROWS  = 256;
  RIP_MAX_FORM_FIELDS = 32;

  RIP_PIXFMT_INDEXED8  = 0;
  RIP_PIXFMT_RGB24     = 1;
  RIP_PIXFMT_RGBA32    = 2;

  RIP_FIELD_TEXT     = 0;
  RIP_FIELD_CHECKBOX = 1;
  RIP_FIELD_RADIO    = 2;
  RIP_FIELD_DROPDOWN = 3;
  RIP_FIELD_BUTTON   = 4;

Type
  TMAFFont = Record
    Name     : String[31];
    NumGlyphs: Word;
    Height   : Word;
    Baseline : Word;
    Data     : Pointer;
    DataSize : LongInt;
  End;

  TMAFResEntry = Record
    Name     : String[31];
    Offset   : LongInt;
    Size     : LongInt;
  End;

  TMAFFile = Record
    FileName : String[79];
    NumRes   : Word;
    Entries  : Array[0..63] of TMAFResEntry;
    Fonts    : Array[0..15] of TMAFFont;
    NumFonts : Word;
  End;
  PMAFFile = ^TMAFFile;

  TRIPTableCol = Record
    Title    : String[31];
    Width    : Word;
    Align    : Byte;  { 0=left, 1=center, 2=right }
  End;

  TRIPTableCell = Record
    Text     : String[79];
    Color    : Byte;
    BgColor  : Byte;
  End;

  TRIPTable = Record
    NumCols  : Integer;
    NumRows  : Integer;
    Cols     : Array[0..RIP_MAX_TABLE_COLS-1] of TRIPTableCol;
    Cells    : Array[0..RIP_MAX_TABLE_ROWS-1, 0..RIP_MAX_TABLE_COLS-1] of TRIPTableCell;
    X, Y     : Integer;
    Width    : Integer;
    RowHeight: Integer;
    HeaderBG : Byte;
    HeaderFG : Byte;
    BorderColor : Byte;
    ScrollPos: Integer;
    Visible  : Boolean;
  End;

  TRIPFormField = Record
    FieldType : Byte;
    X, Y      : Integer;
    Width     : Integer;
    Height    : Integer;
    Label_    : String[31];
    Value     : String[79];
    MaxLen    : Integer;
    TabOrder  : Integer;
    Focused   : Boolean;
    Checked   : Boolean;
    Options   : String[255];  { dropdown options, | separated }
    SelIndex  : Integer;
    Visible   : Boolean;
    Enabled   : Boolean;
  End;

{ Tables }
Procedure TableCreate(Var T: TRIPTable; X, Y, W, RowH: Integer);
Procedure TableAddCol(Var T: TRIPTable; Title: String; Width: Word; Align: Byte);
Procedure TableSetCell(Var T: TRIPTable; Row, Col: Integer; Text: String; FG, BG: Byte);
Procedure TableRender(Var T: TRIPTable);
Procedure TableScroll(Var T: TRIPTable; Delta: Integer);

{ Forms }
Function  FormAddField(Var Fields: Array of TRIPFormField;
                        Var Count: Integer;
                        FType: Byte; X, Y, W, H: Integer;
                        Lab: String): Integer;
Procedure FormRenderField(Var F: TRIPFormField);
Procedure FormFocusNext(Var Fields: Array of TRIPFormField; Count: Integer; Var Current: Integer);
Procedure FormFocusPrev(Var Fields: Array of TRIPFormField; Count: Integer; Var Current: Integer);
Procedure FormToggleCheck(Var F: TRIPFormField);

{ MAF Fonts }
Function  LoadMAF(Var M: TMAFFile; FileName: String): Boolean;
Procedure FreeMAF(Var M: TMAFFile);

{ Pixel Format }
Procedure ConvertPixelFormat(OldFmt, NewFmt: Byte);

Implementation

Uses
  SysUtils;

{ === Tables === }

Procedure TableCreate(Var T: TRIPTable; X, Y, W, RowH: Integer);
Begin
  FillChar(T, SizeOf(T), 0);
  T.X := X; T.Y := Y; T.Width := W; T.RowHeight := RowH;
  T.HeaderBG := 1; T.HeaderFG := 15;
  T.BorderColor := 7;
  T.Visible := True;
End;

Procedure TableAddCol(Var T: TRIPTable; Title: String; Width: Word; Align: Byte);
Begin
  If T.NumCols >= RIP_MAX_TABLE_COLS Then Exit;
  T.Cols[T.NumCols].Title := Title;
  T.Cols[T.NumCols].Width := Width;
  T.Cols[T.NumCols].Align := Align;
  Inc(T.NumCols);
End;

Procedure TableSetCell(Var T: TRIPTable; Row, Col: Integer; Text: String; FG, BG: Byte);
Begin
  If (Row < 0) Or (Row >= RIP_MAX_TABLE_ROWS) Then Exit;
  If (Col < 0) Or (Col >= T.NumCols) Then Exit;
  If Row >= T.NumRows Then T.NumRows := Row + 1;
  T.Cells[Row, Col].Text := Text;
  T.Cells[Row, Col].Color := FG;
  T.Cells[Row, Col].BgColor := BG;
End;

Procedure TableRender(Var T: TRIPTable);
Var Row, Col, CX, CY: Integer;
Begin
  If Not T.Visible Then Exit;
  { Header }
  CX := T.X;
  For Col := 0 To T.NumCols - 1 Do Begin
    { Draw header cell — simplified }
    CX := CX + T.Cols[Col].Width;
  End;
  { Data rows }
  CY := T.Y + T.RowHeight;
  For Row := T.ScrollPos To T.NumRows - 1 Do Begin
    CX := T.X;
    For Col := 0 To T.NumCols - 1 Do Begin
      { Draw data cell — simplified }
      CX := CX + T.Cols[Col].Width;
    End;
    CY := CY + T.RowHeight;
    If CY > RIP_HEIGHT Then Break;
  End;
End;

Procedure TableScroll(Var T: TRIPTable; Delta: Integer);
Begin
  Inc(T.ScrollPos, Delta);
  If T.ScrollPos < 0 Then T.ScrollPos := 0;
  If T.ScrollPos >= T.NumRows Then T.ScrollPos := T.NumRows - 1;
End;

{ === Forms === }

Function FormAddField(Var Fields: Array of TRIPFormField;
                       Var Count: Integer;
                       FType: Byte; X, Y, W, H: Integer;
                       Lab: String): Integer;
Begin
  Result := -1;
  If Count >= RIP_MAX_FORM_FIELDS Then Exit;
  FillChar(Fields[Count], SizeOf(TRIPFormField), 0);
  Fields[Count].FieldType := FType;
  Fields[Count].X := X;
  Fields[Count].Y := Y;
  Fields[Count].Width := W;
  Fields[Count].Height := H;
  Fields[Count].Label_ := Lab;
  Fields[Count].TabOrder := Count;
  Fields[Count].Visible := True;
  Fields[Count].Enabled := True;
  Fields[Count].MaxLen := 79;
  Result := Count;
  Inc(Count);
End;

Procedure FormRenderField(Var F: TRIPFormField);
Begin
  If Not F.Visible Then Exit;
  { TODO: render field based on type — border, label, value }
End;

Procedure FormFocusNext(Var Fields: Array of TRIPFormField; Count: Integer; Var Current: Integer);
Var I: Integer;
Begin
  For I := 1 To Count Do Begin
    Current := (Current + 1) Mod Count;
    If Fields[Current].Visible And Fields[Current].Enabled Then Exit;
  End;
End;

Procedure FormFocusPrev(Var Fields: Array of TRIPFormField; Count: Integer; Var Current: Integer);
Var I: Integer;
Begin
  For I := 1 To Count Do Begin
    Current := (Current + Count - 1) Mod Count;
    If Fields[Current].Visible And Fields[Current].Enabled Then Exit;
  End;
End;

Procedure FormToggleCheck(Var F: TRIPFormField);
Begin
  If F.FieldType In [RIP_FIELD_CHECKBOX, RIP_FIELD_RADIO] Then
    F.Checked := Not F.Checked;
End;

{ === MAF Fonts === }

Function LoadMAF(Var M: TMAFFile; FileName: String): Boolean;
Var F: File;
Begin
  Result := False;
  FillChar(M, SizeOf(TMAFFile), 0);
  M.FileName := FileName;
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  { TODO: Parse MAF header and resource entries }
  Close(F);
  Result := True;
End;

Procedure FreeMAF(Var M: TMAFFile);
Var I: Integer;
Begin
  For I := 0 To M.NumFonts - 1 Do
    If M.Fonts[I].Data <> Nil Then Begin
      FreeMem(M.Fonts[I].Data, M.Fonts[I].DataSize);
      M.Fonts[I].Data := Nil;
    End;
  FillChar(M, SizeOf(TMAFFile), 0);
End;

{ === Pixel Format === }

Procedure ConvertPixelFormat(OldFmt, NewFmt: Byte);
Begin
  { TODO: Convert Canvas pixel buffer between indexed/RGB/RGBA }
  { This is a no-op stub — actual conversion needs RGB buffer allocation }
End;

End.

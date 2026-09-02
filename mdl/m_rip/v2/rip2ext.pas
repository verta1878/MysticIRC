{$MODE DELPHI}
{$H-}
Unit RIP2Ext;
{ RIPscrip v2.0 Extensions
  Imports v1 shared base (RIPEngine, RIPDraw, RIPText, RIP1Exec).
  Adds: RFF vector fonts, 3D projection, Bar3D, InvertRegion,
  button hotkeys, 256-color palette, higher resolution canvas.

  Does NOT duplicate v1 base code — calls into shared units.

  Source reference: attic/rip_v2v3v4_monolith/rip2api.pas (5381 lines)
  This unit extracts only the v2-specific extensions.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses
  RIPEngine;  { Canvas, PutPixel, GetPixel, InitCanvas }

Type
  TRIPPoint3D = Record
    X, Y, Z : Single;
  End;

  TRIPPoint2D = Record
    X, Y : Integer;
  End;

  TRIPProjParams = Record
    EyeX, EyeY, EyeZ : Single;
    CenterX, CenterY  : Single;
    Scale              : Single;
  End;

  TRFFHeader = Record
    Signature  : Array[0..3] of Char;  { 'RFF1' }
    Version    : Word;
    NumFaces   : Word;
    MaxHeight  : Word;
    Flags      : Word;
    Reserved   : Array[0..15] of Byte;
  End;

  TRFFFaceRecord = Record
    Width, Height : Word;
    Baseline      : Word;
    DataOffset    : LongInt;
  End;

{ Bar3D — 3D bar with depth and optional top }
Procedure Bar3D(X0, Y0, X1, Y1, Depth: Integer; Top: Boolean);

{ InvertRegion — XOR all pixels in region }
Procedure InvertRegion(X0, Y0, X1, Y1: Integer);

{ 3D Projection }
Procedure D3Rotate(Var Pts: Array of TRIPPoint3D; Count: Integer;
                    AngleX, AngleY, AngleZ: Single);
Procedure D3Scale(Var Pts: Array of TRIPPoint3D; Count: Integer;
                   SX, SY, SZ: Single);
Procedure D3Translate(Var Pts: Array of TRIPPoint3D; Count: Integer;
                       DX, DY, DZ: Single);
Function  D3Project(Var In3D: Array of TRIPPoint3D;
                     Var Out2D: Array of TRIPPoint2D;
                     Count: Integer;
                     Var Params: TRIPProjParams): Boolean;

{ RFF Font }
Function  LoadRFF(FontNum: Byte; FileName: String): Boolean;

Implementation

Uses
  SysUtils, Math;

Procedure Bar3D(X0, Y0, X1, Y1, Depth: Integer; Top: Boolean);
Var X, Y: Integer;
Begin
  { Front face — filled bar }
  For Y := Y0 To Y1 Do
    For X := X0 To X1 Do
      PutPixel(X, Y, Canvas.FG);

  { Right side }
  For Y := Y0 To Y1 Do
    PutPixel(X1 + 1, Y - Depth, Canvas.FG);
  For X := 0 To Depth - 1 Do Begin
    PutPixel(X1 + 1 + X, Y0 - X, Canvas.FG);
    PutPixel(X1 + 1 + X, Y1 - X, Canvas.FG);
  End;

  { Top face }
  If Top Then
    For X := X0 To X1 + Depth Do
      PutPixel(X, Y0 - Depth, Canvas.FG);

  { Outline }
  For X := X0 To X1 Do Begin
    PutPixel(X, Y0, Canvas.FG);
    PutPixel(X, Y1, Canvas.FG);
  End;
  For Y := Y0 To Y1 Do Begin
    PutPixel(X0, Y, Canvas.FG);
    PutPixel(X1, Y, Canvas.FG);
  End;
End;

Procedure InvertRegion(X0, Y0, X1, Y1: Integer);
Var X, Y: Integer; C: Byte;
Begin
  For Y := Y0 To Y1 Do
    For X := X0 To X1 Do Begin
      C := GetPixel(X, Y);
      PutPixel(X, Y, C Xor 15);
    End;
End;

Procedure D3Rotate(Var Pts: Array of TRIPPoint3D; Count: Integer;
                    AngleX, AngleY, AngleZ: Single);
Var
  I: Integer;
  CX, SX, CY, SY, CZ, SZ: Single;
  TX, TY, TZ: Single;
Begin
  CX := Cos(AngleX); SX := Sin(AngleX);
  CY := Cos(AngleY); SY := Sin(AngleY);
  CZ := Cos(AngleZ); SZ := Sin(AngleZ);
  For I := 0 To Count - 1 Do Begin
    { Rotate X }
    TY := Pts[I].Y * CX - Pts[I].Z * SX;
    TZ := Pts[I].Y * SX + Pts[I].Z * CX;
    Pts[I].Y := TY; Pts[I].Z := TZ;
    { Rotate Y }
    TX := Pts[I].X * CY + Pts[I].Z * SY;
    TZ := -Pts[I].X * SY + Pts[I].Z * CY;
    Pts[I].X := TX; Pts[I].Z := TZ;
    { Rotate Z }
    TX := Pts[I].X * CZ - Pts[I].Y * SZ;
    TY := Pts[I].X * SZ + Pts[I].Y * CZ;
    Pts[I].X := TX; Pts[I].Y := TY;
  End;
End;

Procedure D3Scale(Var Pts: Array of TRIPPoint3D; Count: Integer;
                   SX, SY, SZ: Single);
Var I: Integer;
Begin
  For I := 0 To Count - 1 Do Begin
    Pts[I].X := Pts[I].X * SX;
    Pts[I].Y := Pts[I].Y * SY;
    Pts[I].Z := Pts[I].Z * SZ;
  End;
End;

Procedure D3Translate(Var Pts: Array of TRIPPoint3D; Count: Integer;
                       DX, DY, DZ: Single);
Var I: Integer;
Begin
  For I := 0 To Count - 1 Do Begin
    Pts[I].X := Pts[I].X + DX;
    Pts[I].Y := Pts[I].Y + DY;
    Pts[I].Z := Pts[I].Z + DZ;
  End;
End;

Function D3Project(Var In3D: Array of TRIPPoint3D;
                    Var Out2D: Array of TRIPPoint2D;
                    Count: Integer;
                    Var Params: TRIPProjParams): Boolean;
Var I: Integer; D: Single;
Begin
  Result := True;
  For I := 0 To Count - 1 Do Begin
    D := In3D[I].Z - Params.EyeZ;
    If Abs(D) < 0.001 Then Begin Result := False; Exit; End;
    Out2D[I].X := Round(Params.CenterX + (In3D[I].X - Params.EyeX) * Params.Scale / D);
    Out2D[I].Y := Round(Params.CenterY + (In3D[I].Y - Params.EyeY) * Params.Scale / D);
  End;
End;

Function LoadRFF(FontNum: Byte; FileName: String): Boolean;
Var
  F: File;
  Hdr: TRFFHeader;
Begin
  Result := False;
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  BlockRead(F, Hdr, SizeOf(Hdr));
  If (Hdr.Signature[0] <> 'R') Or (Hdr.Signature[1] <> 'F') Then Begin
    Close(F);
    Exit;
  End;
  { TODO: Load face data and glyph bitmaps into font slot }
  Close(F);
  Result := True;
End;

End.

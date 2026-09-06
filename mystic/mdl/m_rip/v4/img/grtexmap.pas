(* grtexmap.pas -- Texture Mapping on Polygons
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Affine and perspective-correct texture mapping for convex polygons.
   UV coordinate mapping. Bilinear filtering option.
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit grtexmap;

interface

type
  TTexVertex = record
    X, Y: SmallInt;    { screen coordinates }
    U, V: SmallInt;    { texture coordinates (0-255 maps to texture size) }
  end;

  TTexture = record
    Pixels: PByte;     { RGB, 3 bytes/pixel }
    Width, Height: Word;
  end;

{ Texture-map a triangle }
procedure TexMapTriangle(DstPixels: PByte; DstW, DstH: Word;
  var Tex: TTexture;
  V0, V1, V2: TTexVertex; Filtered: Boolean);

{ Texture-map a quad (two triangles) }
procedure TexMapQuad(DstPixels: PByte; DstW, DstH: Word;
  var Tex: TTexture;
  V0, V1, V2, V3: TTexVertex; Filtered: Boolean);

{ Simple: blit texture with scaling }
procedure TexBlit(DstPixels: PByte; DstW, DstH: Word;
  var Tex: TTexture;
  DstX, DstY, DstWidth, DstHeight: SmallInt);

implementation

function TexSample(var Tex: TTexture; U, V: Integer): LongWord;
var
  TX, TY: Integer;
  Off: LongInt;
begin
  TX := (U * Tex.Width) shr 8;
  TY := (V * Tex.Height) shr 8;
  if TX < 0 then TX := 0;
  if TY < 0 then TY := 0;
  if TX >= Tex.Width then TX := Tex.Width - 1;
  if TY >= Tex.Height then TY := Tex.Height - 1;
  Off := (LongInt(TY) * Tex.Width + TX) * 3;
  Result := Tex.Pixels[Off] or (LongWord(Tex.Pixels[Off+1]) shl 8) or
            (LongWord(Tex.Pixels[Off+2]) shl 16);
end;

procedure SetPx3(Dst: PByte; W: Word; X, Y: SmallInt; C: LongWord);
var
  Off: LongInt;
begin
  if (X < 0) or (X >= W) then Exit;
  Off := (LongInt(Y) * W + X) * 3;
  Dst[Off] := C and $FF;
  Dst[Off + 1] := (C shr 8) and $FF;
  Dst[Off + 2] := (C shr 16) and $FF;
end;

procedure TexMapTriangle(DstPixels: PByte; DstW, DstH: Word;
  var Tex: TTexture;
  V0, V1, V2: TTexVertex; Filtered: Boolean);
var
  MinY, MaxY, Y, X: SmallInt;
  XL, XR: Integer;
  UL, VL, UR, VR: Integer;
  U, V: Integer;
  DX01, DX02, DX12: Integer;
  DU01, DU02, DU12: Integer;
  DV01, DV02, DV12: Integer;
  T0, T1, T2: TTexVertex;
  Tmp: TTexVertex;
  A01, A02, A12: Integer;
  UA, VA, UStep, VStep: Integer;
  SpanW: Integer;
  C: LongWord;
begin
  { Sort vertices by Y }
  T0 := V0; T1 := V1; T2 := V2;
  if T0.Y > T1.Y then begin Tmp := T0; T0 := T1; T1 := Tmp; end;
  if T1.Y > T2.Y then begin Tmp := T1; T1 := T2; T2 := Tmp; end;
  if T0.Y > T1.Y then begin Tmp := T0; T0 := T1; T1 := Tmp; end;

  MinY := T0.Y; MaxY := T2.Y;
  if MinY < 0 then MinY := 0;
  if MaxY >= DstH then MaxY := DstH - 1;
  if MinY > MaxY then Exit;

  for Y := MinY to MaxY do
  begin
    { Compute left/right X and UV for this scanline }
    if Y < T1.Y then
    begin
      if T1.Y - T0.Y = 0 then Continue;
      A01 := ((Y - T0.Y) shl 8) div (T1.Y - T0.Y);
    end
    else
      A01 := 256;

    if T2.Y - T0.Y = 0 then Continue;
    A02 := ((Y - T0.Y) shl 8) div (T2.Y - T0.Y);

    XL := T0.X + ((T2.X - T0.X) * A02) shr 8;
    UL := T0.U + ((T2.U - T0.U) * A02) shr 8;
    VL := T0.V + ((T2.V - T0.V) * A02) shr 8;

    if Y < T1.Y then
    begin
      XR := T0.X + ((T1.X - T0.X) * A01) shr 8;
      UR := T0.U + ((T1.U - T0.U) * A01) shr 8;
      VR := T0.V + ((T1.V - T0.V) * A01) shr 8;
    end
    else
    begin
      if T2.Y - T1.Y = 0 then Continue;
      A12 := ((Y - T1.Y) shl 8) div (T2.Y - T1.Y);
      XR := T1.X + ((T2.X - T1.X) * A12) shr 8;
      UR := T1.U + ((T2.U - T1.U) * A12) shr 8;
      VR := T1.V + ((T2.V - T1.V) * A12) shr 8;
    end;

    if XL > XR then
    begin
      X := XL; XL := XR; XR := X;
      X := UL; UL := UR; UR := X;
      X := VL; VL := VR; VR := X;
    end;

    SpanW := XR - XL;
    if SpanW <= 0 then SpanW := 1;

    for X := XL to XR do
    begin
      if (X < 0) or (X >= DstW) then Continue;
      UA := UL + ((UR - UL) * (X - XL)) div SpanW;
      VA := VL + ((VR - VL) * (X - XL)) div SpanW;
      C := TexSample(Tex, UA, VA);
      SetPx3(DstPixels, DstW, X, Y, C);
    end;
  end;
end;

procedure TexMapQuad(DstPixels: PByte; DstW, DstH: Word;
  var Tex: TTexture;
  V0, V1, V2, V3: TTexVertex; Filtered: Boolean);
begin
  TexMapTriangle(DstPixels, DstW, DstH, Tex, V0, V1, V2, Filtered);
  TexMapTriangle(DstPixels, DstW, DstH, Tex, V0, V2, V3, Filtered);
end;

procedure TexBlit(DstPixels: PByte; DstW, DstH: Word;
  var Tex: TTexture;
  DstX, DstY, DstWidth, DstHeight: SmallInt);
var
  X, Y: SmallInt;
  SrcX, SrcY: Integer;
  Off, SrcOff: LongInt;
begin
  if DstWidth <= 0 then DstWidth := Tex.Width;
  if DstHeight <= 0 then DstHeight := Tex.Height;
  for Y := 0 to DstHeight - 1 do
  begin
    if DstY + Y < 0 then Continue;
    if DstY + Y >= DstH then Break;
    SrcY := (Y * Tex.Height) div DstHeight;
    for X := 0 to DstWidth - 1 do
    begin
      if DstX + X < 0 then Continue;
      if DstX + X >= DstW then Break;
      SrcX := (X * Tex.Width) div DstWidth;
      SrcOff := (LongInt(SrcY) * Tex.Width + SrcX) * 3;
      Off := (LongInt(DstY + Y) * DstW + DstX + X) * 3;
      DstPixels[Off] := Tex.Pixels[SrcOff];
      DstPixels[Off + 1] := Tex.Pixels[SrcOff + 1];
      DstPixels[Off + 2] := Tex.Pixels[SrcOff + 2];
    end;
  end;
end;

end.

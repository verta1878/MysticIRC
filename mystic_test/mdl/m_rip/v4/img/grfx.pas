(* grfx.pas -- Drop Shadows and Glow Effects
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Per-shape drop shadow with configurable offset, blur, color, opacity.
   Outer glow (bloom) for text and icons. Box blur for shadow softening.
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit grfx;

interface

type
  TShadowParams = record
    OffsetX, OffsetY: SmallInt;
    BlurRadius: Byte;
    R, G, B: Byte;
    Opacity: Byte;  { 0-255 }
  end;

  TGlowParams = record
    Radius: Byte;
    R, G, B: Byte;
    Opacity: Byte;
  end;

{ Apply drop shadow to non-transparent pixels }
procedure FXDropShadow(Pixels: PByte; Width, Height: Word;
  var Shadow: TShadowParams);

{ Apply outer glow }
procedure FXOuterGlow(Pixels: PByte; Width, Height: Word;
  var Glow: TGlowParams);

{ Box blur on RGB buffer }
procedure FXBoxBlur(Pixels: PByte; Width, Height: Word; Radius: Integer);

{ Gaussian-approximated blur (3-pass box blur) }
procedure FXGaussBlur(Pixels: PByte; Width, Height: Word; Radius: Integer);

{ Alpha blend source over destination }
procedure FXAlphaBlend(Dst, Src: PByte; Width, Height: Word; Opacity: Byte);

{ Helper: create shadow params }
function ShadowParams(OX, OY: SmallInt; Blur: Byte;
  R, G, B, Opacity: Byte): TShadowParams;

{ Helper: create glow params }
function GlowParams(Radius: Byte; R, G, B, Opacity: Byte): TGlowParams;

implementation

function ShadowParams(OX, OY: SmallInt; Blur: Byte;
  R, G, B, Opacity: Byte): TShadowParams;
begin
  Result.OffsetX := OX; Result.OffsetY := OY;
  Result.BlurRadius := Blur;
  Result.R := R; Result.G := G; Result.B := B;
  Result.Opacity := Opacity;
end;

function GlowParams(Radius: Byte; R, G, B, Opacity: Byte): TGlowParams;
begin
  Result.Radius := Radius;
  Result.R := R; Result.G := G; Result.B := B;
  Result.Opacity := Opacity;
end;

procedure FXBoxBlur(Pixels: PByte; Width, Height: Word; Radius: Integer);
var
  Tmp: PByte;
  BufSize: LongInt;
  X, Y, KX, KY: Integer;
  SumR, SumG, SumB: LongInt;
  Count: Integer;
  SrcOff, DstOff: LongInt;
begin
  if Radius <= 0 then Exit;
  BufSize := LongInt(Width) * Height * 3;
  GetMem(Tmp, BufSize);

  { Horizontal pass }
  for Y := 0 to Height - 1 do
    for X := 0 to Width - 1 do
    begin
      SumR := 0; SumG := 0; SumB := 0; Count := 0;
      for KX := -Radius to Radius do
      begin
        if (X + KX < 0) or (X + KX >= Width) then Continue;
        SrcOff := (LongInt(Y) * Width + X + KX) * 3;
        Inc(SumR, Pixels[SrcOff]);
        Inc(SumG, Pixels[SrcOff + 1]);
        Inc(SumB, Pixels[SrcOff + 2]);
        Inc(Count);
      end;
      DstOff := (LongInt(Y) * Width + X) * 3;
      if Count > 0 then
      begin
        Tmp[DstOff] := SumR div Count;
        Tmp[DstOff + 1] := SumG div Count;
        Tmp[DstOff + 2] := SumB div Count;
      end;
    end;

  { Vertical pass }
  for Y := 0 to Height - 1 do
    for X := 0 to Width - 1 do
    begin
      SumR := 0; SumG := 0; SumB := 0; Count := 0;
      for KY := -Radius to Radius do
      begin
        if (Y + KY < 0) or (Y + KY >= Height) then Continue;
        SrcOff := (LongInt(Y + KY) * Width + X) * 3;
        Inc(SumR, Tmp[SrcOff]);
        Inc(SumG, Tmp[SrcOff + 1]);
        Inc(SumB, Tmp[SrcOff + 2]);
        Inc(Count);
      end;
      DstOff := (LongInt(Y) * Width + X) * 3;
      if Count > 0 then
      begin
        Pixels[DstOff] := SumR div Count;
        Pixels[DstOff + 1] := SumG div Count;
        Pixels[DstOff + 2] := SumB div Count;
      end;
    end;

  FreeMem(Tmp);
end;

procedure FXGaussBlur(Pixels: PByte; Width, Height: Word; Radius: Integer);
begin
  { 3-pass box blur approximates Gaussian }
  FXBoxBlur(Pixels, Width, Height, Radius);
  FXBoxBlur(Pixels, Width, Height, Radius);
  FXBoxBlur(Pixels, Width, Height, Radius);
end;

procedure FXAlphaBlend(Dst, Src: PByte; Width, Height: Word; Opacity: Byte);
var
  I: LongInt;
  Total: LongInt;
  Alpha, InvAlpha: Integer;
begin
  Total := LongInt(Width) * Height * 3;
  Alpha := Opacity;
  InvAlpha := 255 - Opacity;
  for I := 0 to Total - 1 do
    Dst[I] := (Src[I] * Alpha + Dst[I] * InvAlpha) div 255;
end;

procedure FXDropShadow(Pixels: PByte; Width, Height: Word;
  var Shadow: TShadowParams);
var
  ShadowBuf: PByte;
  BufSize: LongInt;
  X, Y: Integer;
  SrcOff, DstOff: LongInt;
  IsContent: Boolean;
begin
  BufSize := LongInt(Width) * Height * 3;
  GetMem(ShadowBuf, BufSize);
  FillChar(ShadowBuf^, BufSize, 0);

  { Create shadow mask: where original has non-black pixels, paint shadow color }
  for Y := 0 to Height - 1 do
    for X := 0 to Width - 1 do
    begin
      SrcOff := (LongInt(Y) * Width + X) * 3;
      IsContent := (Pixels[SrcOff] > 0) or (Pixels[SrcOff+1] > 0) or (Pixels[SrcOff+2] > 0);
      if IsContent then
      begin
        { Place shadow at offset position }
        if (X + Shadow.OffsetX >= 0) and (X + Shadow.OffsetX < Width) and
           (Y + Shadow.OffsetY >= 0) and (Y + Shadow.OffsetY < Height) then
        begin
          DstOff := (LongInt(Y + Shadow.OffsetY) * Width + X + Shadow.OffsetX) * 3;
          ShadowBuf[DstOff] := Shadow.R;
          ShadowBuf[DstOff + 1] := Shadow.G;
          ShadowBuf[DstOff + 2] := Shadow.B;
        end;
      end;
    end;

  { Blur shadow }
  if Shadow.BlurRadius > 0 then
    FXGaussBlur(ShadowBuf, Width, Height, Shadow.BlurRadius);

  { Composite: shadow behind original }
  for Y := 0 to Height - 1 do
    for X := 0 to Width - 1 do
    begin
      SrcOff := (LongInt(Y) * Width + X) * 3;
      IsContent := (Pixels[SrcOff] > 0) or (Pixels[SrcOff+1] > 0) or (Pixels[SrcOff+2] > 0);
      if not IsContent then
      begin
        { Show shadow where no content }
        Pixels[SrcOff] := (ShadowBuf[SrcOff] * Shadow.Opacity) div 255;
        Pixels[SrcOff+1] := (ShadowBuf[SrcOff+1] * Shadow.Opacity) div 255;
        Pixels[SrcOff+2] := (ShadowBuf[SrcOff+2] * Shadow.Opacity) div 255;
      end;
    end;

  FreeMem(ShadowBuf);
end;

procedure FXOuterGlow(Pixels: PByte; Width, Height: Word;
  var Glow: TGlowParams);
var
  GlowBuf: PByte;
  BufSize: LongInt;
  X, Y: Integer;
  SrcOff: LongInt;
  IsContent: Boolean;
begin
  BufSize := LongInt(Width) * Height * 3;
  GetMem(GlowBuf, BufSize);
  FillChar(GlowBuf^, BufSize, 0);

  { Create glow mask from content }
  for Y := 0 to Height - 1 do
    for X := 0 to Width - 1 do
    begin
      SrcOff := (LongInt(Y) * Width + X) * 3;
      IsContent := (Pixels[SrcOff] > 0) or (Pixels[SrcOff+1] > 0) or (Pixels[SrcOff+2] > 0);
      if IsContent then
      begin
        GlowBuf[SrcOff] := Glow.R;
        GlowBuf[SrcOff + 1] := Glow.G;
        GlowBuf[SrcOff + 2] := Glow.B;
      end;
    end;

  { Blur glow }
  FXGaussBlur(GlowBuf, Width, Height, Glow.Radius);

  { Composite: glow behind original }
  FXAlphaBlend(Pixels, GlowBuf, Width, Height, Glow.Opacity);

  FreeMem(GlowBuf);
end;

end.

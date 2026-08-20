(* riplayerdec.pas -- RIPscript Layer-Based Scene Decoder
   Copyright (C) 2026 fpc264irc contributors.
   License: GPLv3

   Layer-based progressive rendering. Background renders first,
   then overlays added in depth order. Each layer is a separate
   pixel buffer with alpha transparency.

   Layer order: 1) Background 2) Shapes 3) Text 4) Icons 5) Buttons 6) MouseFields
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit riplayerdec;

interface

const
  RIPL_MAX_LAYERS = 16;

type
  TRIPLayerType = (
    rltBackground,    { solid fills, clear screen }
    rltShapes,        { lines, rects, circles, polygons }
    rltText,          { text output, font rendering }
    rltIcons,         { ICN/MSK/HIC, BMP, PCX images }
    rltButtons,       { button graphics, 3D bevels }
    rltMouseFields,   { invisible — mouse hit regions only }
    rltCustom         { user-defined overlay }
  );

  TRIPLayer = record
    LayerType: TRIPLayerType;
    Pixels: PByte;       { RGBA, 4 bytes/pixel }
    Width, Height: Word;
    Opacity: Byte;       { 0=transparent, 255=opaque }
    Visible: Boolean;
    Dirty: Boolean;      { needs re-composite }
    Name: ShortString;
  end;

  TRIPLayerStack = record
    Layers: array[0..RIPL_MAX_LAYERS - 1] of TRIPLayer;
    NumLayers: Integer;
    Width, Height: Word;
    Composite: PByte;    { final composited RGB output, 3 bytes/pixel }
    Loaded: Boolean;
  end;

{ Initialize layer stack }
procedure RIPLayerInit(var Stack: TRIPLayerStack; Width, Height: Word);

{ Add a layer }
function RIPLayerAdd(var Stack: TRIPLayerStack;
  LType: TRIPLayerType; const Name: ShortString): Integer;

{ Clear a layer to transparent }
procedure RIPLayerClear(var Stack: TRIPLayerStack; LayerIdx: Integer);

{ Set pixel on a layer (RGBA) }
procedure RIPLayerSetPixel(var Stack: TRIPLayerStack;
  LayerIdx: Integer; X, Y: Integer; R, G, B, A: Byte);

{ Blit RGB source onto layer with opacity }
procedure RIPLayerBlit(var Stack: TRIPLayerStack;
  LayerIdx: Integer; SrcPixels: PByte; SrcW, SrcH: Word;
  DstX, DstY: Integer; Opacity: Byte);

{ Composite all visible layers to RGB output }
procedure RIPLayerComposite(var Stack: TRIPLayerStack);

{ Get composited output }
function RIPLayerGetOutput(var Stack: TRIPLayerStack): PByte;

{ Save/load layer stack }
function RIPLayerSaveFile(const FileName: ShortString;
  var Stack: TRIPLayerStack): Boolean;
function RIPLayerLoadFile(const FileName: ShortString;
  out Stack: TRIPLayerStack): Boolean;

procedure RIPLayerFree(var Stack: TRIPLayerStack);

implementation

procedure RIPLayerInit(var Stack: TRIPLayerStack; Width, Height: Word);
begin
  FillChar(Stack, SizeOf(Stack), 0);
  Stack.Width := Width;
  Stack.Height := Height;
  GetMem(Stack.Composite, LongWord(Width) * Height * 3);
  FillChar(Stack.Composite^, LongWord(Width) * Height * 3, 0);
  Stack.Loaded := True;
end;

function RIPLayerAdd(var Stack: TRIPLayerStack;
  LType: TRIPLayerType; const Name: ShortString): Integer;
var
  L: ^TRIPLayer;
  BufSize: LongWord;
begin
  Result := -1;
  if Stack.NumLayers >= RIPL_MAX_LAYERS then Exit;
  Result := Stack.NumLayers;
  L := @Stack.Layers[Result];
  L^.LayerType := LType;
  L^.Width := Stack.Width;
  L^.Height := Stack.Height;
  L^.Opacity := 255;
  L^.Visible := True;
  L^.Dirty := True;
  L^.Name := Name;
  BufSize := LongWord(Stack.Width) * Stack.Height * 4;
  GetMem(L^.Pixels, BufSize);
  FillChar(L^.Pixels^, BufSize, 0); { transparent }
  Inc(Stack.NumLayers);
end;

procedure RIPLayerClear(var Stack: TRIPLayerStack; LayerIdx: Integer);
begin
  if (LayerIdx < 0) or (LayerIdx >= Stack.NumLayers) then Exit;
  FillChar(Stack.Layers[LayerIdx].Pixels^,
    LongWord(Stack.Width) * Stack.Height * 4, 0);
  Stack.Layers[LayerIdx].Dirty := True;
end;

procedure RIPLayerSetPixel(var Stack: TRIPLayerStack;
  LayerIdx: Integer; X, Y: Integer; R, G, B, A: Byte);
var
  Offset: LongInt;
begin
  if (LayerIdx < 0) or (LayerIdx >= Stack.NumLayers) then Exit;
  if (X < 0) or (X >= Stack.Width) or (Y < 0) or (Y >= Stack.Height) then Exit;
  Offset := (LongInt(Y) * Stack.Width + X) * 4;
  Stack.Layers[LayerIdx].Pixels[Offset] := R;
  Stack.Layers[LayerIdx].Pixels[Offset + 1] := G;
  Stack.Layers[LayerIdx].Pixels[Offset + 2] := B;
  Stack.Layers[LayerIdx].Pixels[Offset + 3] := A;
  Stack.Layers[LayerIdx].Dirty := True;
end;

procedure RIPLayerBlit(var Stack: TRIPLayerStack;
  LayerIdx: Integer; SrcPixels: PByte; SrcW, SrcH: Word;
  DstX, DstY: Integer; Opacity: Byte);
var
  X, Y: Integer;
  SrcOff, DstOff: LongInt;
begin
  if (LayerIdx < 0) or (LayerIdx >= Stack.NumLayers) then Exit;
  for Y := 0 to SrcH - 1 do
  begin
    if DstY + Y < 0 then Continue;
    if DstY + Y >= Stack.Height then Break;
    for X := 0 to SrcW - 1 do
    begin
      if DstX + X < 0 then Continue;
      if DstX + X >= Stack.Width then Break;
      SrcOff := (LongInt(Y) * SrcW + X) * 3;
      DstOff := (LongInt(DstY + Y) * Stack.Width + DstX + X) * 4;
      Stack.Layers[LayerIdx].Pixels[DstOff] := SrcPixels[SrcOff];
      Stack.Layers[LayerIdx].Pixels[DstOff + 1] := SrcPixels[SrcOff + 1];
      Stack.Layers[LayerIdx].Pixels[DstOff + 2] := SrcPixels[SrcOff + 2];
      Stack.Layers[LayerIdx].Pixels[DstOff + 3] := Opacity;
    end;
  end;
  Stack.Layers[LayerIdx].Dirty := True;
end;

procedure RIPLayerComposite(var Stack: TRIPLayerStack);
var
  I, Pixel: Integer;
  TotalPixels: LongInt;
  SrcOff, DstOff: LongInt;
  R, G, B: Integer;
  SR, SG, SB, SA: Integer;
  Alpha, InvAlpha: Integer;
begin
  TotalPixels := LongInt(Stack.Width) * Stack.Height;
  FillChar(Stack.Composite^, TotalPixels * 3, 0);

  for I := 0 to Stack.NumLayers - 1 do
  begin
    if not Stack.Layers[I].Visible then Continue;
    if Stack.Layers[I].Pixels = nil then Continue;

    for Pixel := 0 to TotalPixels - 1 do
    begin
      SrcOff := Pixel * 4;
      DstOff := Pixel * 3;

      SA := Stack.Layers[I].Pixels[SrcOff + 3];
      SA := (SA * Stack.Layers[I].Opacity) div 255;
      if SA = 0 then Continue;

      SR := Stack.Layers[I].Pixels[SrcOff];
      SG := Stack.Layers[I].Pixels[SrcOff + 1];
      SB := Stack.Layers[I].Pixels[SrcOff + 2];

      if SA = 255 then
      begin
        Stack.Composite[DstOff] := SR;
        Stack.Composite[DstOff + 1] := SG;
        Stack.Composite[DstOff + 2] := SB;
      end
      else
      begin
        Alpha := SA;
        InvAlpha := 255 - SA;
        Stack.Composite[DstOff] := (SR * Alpha + Stack.Composite[DstOff] * InvAlpha) div 255;
        Stack.Composite[DstOff + 1] := (SG * Alpha + Stack.Composite[DstOff + 1] * InvAlpha) div 255;
        Stack.Composite[DstOff + 2] := (SB * Alpha + Stack.Composite[DstOff + 2] * InvAlpha) div 255;
      end;
    end;
  end;
end;

function RIPLayerGetOutput(var Stack: TRIPLayerStack): PByte;
begin
  Result := Stack.Composite;
end;

function RIPLayerSaveFile(const FileName: ShortString;
  var Stack: TRIPLayerStack): Boolean;
var F: File; Hdr: array[0..7] of Byte; I: Integer; B: Byte; BufSize: LongWord;
begin
  Result := False;
  Assign(F, FileName);
  {$I-} Rewrite(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  Hdr[0] := Ord('R'); Hdr[1] := Ord('I'); Hdr[2] := Ord('P'); Hdr[3] := Ord('L');
  Hdr[4] := Lo(Stack.Width); Hdr[5] := Hi(Stack.Width);
  Hdr[6] := Lo(Stack.Height); Hdr[7] := Hi(Stack.Height);
  BlockWrite(F, Hdr, 8);
  B := Stack.NumLayers; BlockWrite(F, B, 1);
  BufSize := LongWord(Stack.Width) * Stack.Height * 4;
  for I := 0 to Stack.NumLayers - 1 do
  begin
    B := Ord(Stack.Layers[I].LayerType); BlockWrite(F, B, 1);
    B := Stack.Layers[I].Opacity; BlockWrite(F, B, 1);
    B := Ord(Stack.Layers[I].Visible); BlockWrite(F, B, 1);
    BlockWrite(F, Stack.Layers[I].Pixels^, BufSize);
  end;
  Close(F); Result := True;
end;

function RIPLayerLoadFile(const FileName: ShortString;
  out Stack: TRIPLayerStack): Boolean;
var F: File; Hdr: array[0..7] of Byte; I: Integer; B, NL: Byte;
    BufSize: LongWord; BR: LongInt;
begin
  Result := False; FillChar(Stack, SizeOf(Stack), 0);
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  BlockRead(F, Hdr, 8, BR);
  if BR < 8 then begin Close(F); Exit; end;
  if (Chr(Hdr[0]) <> 'R') or (Chr(Hdr[3]) <> 'L') then begin Close(F); Exit; end;
  Stack.Width := Hdr[4] or (Word(Hdr[5]) shl 8);
  Stack.Height := Hdr[6] or (Word(Hdr[7]) shl 8);
  BlockRead(F, NL, 1);
  GetMem(Stack.Composite, LongWord(Stack.Width) * Stack.Height * 3);
  BufSize := LongWord(Stack.Width) * Stack.Height * 4;
  for I := 0 to NL - 1 do
  begin
    BlockRead(F, B, 1); Stack.Layers[I].LayerType := TRIPLayerType(B);
    BlockRead(F, B, 1); Stack.Layers[I].Opacity := B;
    BlockRead(F, B, 1); Stack.Layers[I].Visible := B <> 0;
    Stack.Layers[I].Width := Stack.Width;
    Stack.Layers[I].Height := Stack.Height;
    GetMem(Stack.Layers[I].Pixels, BufSize);
    BlockRead(F, Stack.Layers[I].Pixels^, BufSize);
  end;
  Stack.NumLayers := NL;
  Stack.Loaded := True;
  Close(F); Result := True;
end;

procedure RIPLayerFree(var Stack: TRIPLayerStack);
var I: Integer;
begin
  for I := 0 to RIPL_MAX_LAYERS - 1 do
    if Stack.Layers[I].Pixels <> nil then
    begin FreeMem(Stack.Layers[I].Pixels); Stack.Layers[I].Pixels := nil; end;
  if Stack.Composite <> nil then begin FreeMem(Stack.Composite); Stack.Composite := nil; end;
  Stack.NumLayers := 0; Stack.Loaded := False;
end;

end.

(* riptile.pas -- RIPscript Tile-Based Scene Decoder
   Copyright (C) 2026 fpc264irc contributors.
   License: GPLv3

   Splits a rendered scene into rectangular tiles for progressive
   transmission. Tiles can arrive in any order and be rendered
   independently. Supports RLE compression per tile.

   Tile format (.ript):
     Header: 'RIPT' + width(2) + height(2) + tileW(2) + tileH(2) + numTiles(2)
     Tiles: tileX(2) + tileY(2) + dataLen(2) + RLE pixel data
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit riptile;

interface

const
  RIPT_MAX_TILES = 4096;
  RIPT_DEFAULT_TILE_SIZE = 64;

type
  TRIPTile = record
    X, Y: Word;           { tile position in pixels }
    Width, Height: Word;   { tile dimensions }
    Data: PByte;           { RGB pixel data (3 bytes/pixel) }
    DataSize: LongWord;
    Compressed: PByte;     { RLE compressed data }
    CompSize: LongWord;
  end;

  TRIPTileScene = record
    Width, Height: Word;    { full scene dimensions }
    TileW, TileH: Word;    { tile dimensions }
    TilesX, TilesY: Word;  { tile grid }
    NumTiles: Word;
    Tiles: array[0..RIPT_MAX_TILES - 1] of TRIPTile;
    Loaded: Boolean;
  end;

{ Split a framebuffer into tiles }
procedure RIPTileSplit(Pixels: PByte; Width, Height: Word;
  TileW, TileH: Word; out Scene: TRIPTileScene);

{ Reconstruct framebuffer from tiles }
procedure RIPTileComposite(var Scene: TRIPTileScene;
  OutPixels: PByte; OutWidth, OutHeight: Word);

{ RLE compress a single tile }
function RIPTileCompress(var Tile: TRIPTile): Boolean;

{ RLE decompress a single tile }
function RIPTileDecompress(var Tile: TRIPTile): Boolean;

{ Save tile scene to file }
function RIPTileSaveFile(const FileName: ShortString;
  var Scene: TRIPTileScene): Boolean;

{ Load tile scene from file }
function RIPTileLoadFile(const FileName: ShortString;
  out Scene: TRIPTileScene): Boolean;

{ Load from memory }
function RIPTileLoadMem(Src: PByte; SrcLen: LongInt;
  out Scene: TRIPTileScene): Boolean;

procedure RIPTileFree(var Scene: TRIPTileScene);

implementation

procedure RIPTileSplit(Pixels: PByte; Width, Height: Word;
  TileW, TileH: Word; out Scene: TRIPTileScene);
var
  TX, TY, I: Integer;
  SrcRow, DstRow: LongInt;
  T: ^TRIPTile;
  Y: Integer;
  TW, TH: Word;
begin
  FillChar(Scene, SizeOf(Scene), 0);
  Scene.Width := Width;
  Scene.Height := Height;
  Scene.TileW := TileW;
  Scene.TileH := TileH;
  Scene.TilesX := (Width + TileW - 1) div TileW;
  Scene.TilesY := (Height + TileH - 1) div TileH;
  Scene.NumTiles := Scene.TilesX * Scene.TilesY;
  if Scene.NumTiles > RIPT_MAX_TILES then
    Scene.NumTiles := RIPT_MAX_TILES;

  I := 0;
  for TY := 0 to Scene.TilesY - 1 do
    for TX := 0 to Scene.TilesX - 1 do
    begin
      if I >= Scene.NumTiles then Break;
      T := @Scene.Tiles[I];
      T^.X := TX * TileW;
      T^.Y := TY * TileH;
      TW := TileW;
      TH := TileH;
      if T^.X + TW > Width then TW := Width - T^.X;
      if T^.Y + TH > Height then TH := Height - T^.Y;
      T^.Width := TW;
      T^.Height := TH;
      T^.DataSize := LongWord(TW) * TH * 3;
      GetMem(T^.Data, T^.DataSize);

      { Copy tile pixels from framebuffer }
      for Y := 0 to TH - 1 do
      begin
        SrcRow := (LongInt(T^.Y + Y) * Width + T^.X) * 3;
        DstRow := LongInt(Y) * TW * 3;
        Move(Pixels[SrcRow], T^.Data[DstRow], TW * 3);
      end;

      Inc(I);
    end;

  Scene.Loaded := True;
end;

procedure RIPTileComposite(var Scene: TRIPTileScene;
  OutPixels: PByte; OutWidth, OutHeight: Word);
var
  I, Y: Integer;
  T: ^TRIPTile;
  SrcRow, DstRow: LongInt;
  CopyW: Word;
begin
  for I := 0 to Scene.NumTiles - 1 do
  begin
    T := @Scene.Tiles[I];
    if T^.Data = nil then Continue;
    for Y := 0 to T^.Height - 1 do
    begin
      if T^.Y + Y >= OutHeight then Break;
      CopyW := T^.Width;
      if T^.X + CopyW > OutWidth then CopyW := OutWidth - T^.X;
      SrcRow := LongInt(Y) * T^.Width * 3;
      DstRow := (LongInt(T^.Y + Y) * OutWidth + T^.X) * 3;
      Move(T^.Data[SrcRow], OutPixels[DstRow], CopyW * 3);
    end;
  end;
end;

function RIPTileCompress(var Tile: TRIPTile): Boolean;
var
  Src: PByte;
  SrcLen: LongWord;
  Dst: PByte;
  DstPos, SrcPos: LongInt;
  RunLen: Integer;
  B: Byte;
begin
  Result := False;
  Src := Tile.Data;
  SrcLen := Tile.DataSize;
  if (Src = nil) or (SrcLen = 0) then Exit;

  GetMem(Dst, SrcLen + SrcLen div 8 + 16);
  DstPos := 0;
  SrcPos := 0;

  while SrcPos < LongInt(SrcLen) do
  begin
    B := Src[SrcPos];
    RunLen := 1;
    while (SrcPos + RunLen < LongInt(SrcLen)) and
          (Src[SrcPos + RunLen] = B) and (RunLen < 255) do
      Inc(RunLen);

    if RunLen >= 3 then
    begin
      Dst[DstPos] := $FF; Inc(DstPos);  { RLE marker }
      Dst[DstPos] := RunLen; Inc(DstPos);
      Dst[DstPos] := B; Inc(DstPos);
      Inc(SrcPos, RunLen);
    end
    else
    begin
      if B = $FF then
      begin
        Dst[DstPos] := $FF; Inc(DstPos);
        Dst[DstPos] := 1; Inc(DstPos);
        Dst[DstPos] := $FF; Inc(DstPos);
      end
      else
      begin
        Dst[DstPos] := B; Inc(DstPos);
      end;
      Inc(SrcPos);
    end;
  end;

  Tile.CompSize := DstPos;
  GetMem(Tile.Compressed, DstPos);
  Move(Dst^, Tile.Compressed^, DstPos);
  FreeMem(Dst);
  Result := True;
end;

function RIPTileDecompress(var Tile: TRIPTile): Boolean;
var
  Src: PByte;
  SrcLen: LongWord;
  DstPos, SrcPos: LongInt;
  RunLen: Integer;
  B: Byte;
begin
  Result := False;
  Src := Tile.Compressed;
  SrcLen := Tile.CompSize;
  if (Src = nil) or (SrcLen = 0) then Exit;

  Tile.DataSize := LongWord(Tile.Width) * Tile.Height * 3;
  GetMem(Tile.Data, Tile.DataSize);
  DstPos := 0;
  SrcPos := 0;

  while (SrcPos < LongInt(SrcLen)) and (DstPos < LongInt(Tile.DataSize)) do
  begin
    B := Src[SrcPos]; Inc(SrcPos);
    if B = $FF then
    begin
      if SrcPos + 2 <= LongInt(SrcLen) then
      begin
        RunLen := Src[SrcPos]; Inc(SrcPos);
        B := Src[SrcPos]; Inc(SrcPos);
        while (RunLen > 0) and (DstPos < LongInt(Tile.DataSize)) do
        begin
          Tile.Data[DstPos] := B; Inc(DstPos);
          Dec(RunLen);
        end;
      end;
    end
    else
    begin
      Tile.Data[DstPos] := B; Inc(DstPos);
    end;
  end;

  Result := True;
end;

function RIPTileLoadMem(Src: PByte; SrcLen: LongInt;
  out Scene: TRIPTileScene): Boolean;
var
  Pos: LongInt;
  I: Integer;
  DataLen: Word;
begin
  Result := False;
  FillChar(Scene, SizeOf(Scene), 0);
  if SrcLen < 14 then Exit;
  if (Chr(Src[0]) <> 'R') or (Chr(Src[1]) <> 'I') or
     (Chr(Src[2]) <> 'P') or (Chr(Src[3]) <> 'T') then Exit;

  Scene.Width := Src[4] or (Word(Src[5]) shl 8);
  Scene.Height := Src[6] or (Word(Src[7]) shl 8);
  Scene.TileW := Src[8] or (Word(Src[9]) shl 8);
  Scene.TileH := Src[10] or (Word(Src[11]) shl 8);
  Scene.NumTiles := Src[12] or (Word(Src[13]) shl 8);
  if Scene.NumTiles > RIPT_MAX_TILES then Scene.NumTiles := RIPT_MAX_TILES;

  Pos := 14;
  for I := 0 to Scene.NumTiles - 1 do
  begin
    if Pos + 6 > SrcLen then Break;
    Scene.Tiles[I].X := Src[Pos] or (Word(Src[Pos+1]) shl 8); Inc(Pos, 2);
    Scene.Tiles[I].Y := Src[Pos] or (Word(Src[Pos+1]) shl 8); Inc(Pos, 2);
    DataLen := Src[Pos] or (Word(Src[Pos+1]) shl 8); Inc(Pos, 2);
    Scene.Tiles[I].Width := Scene.TileW;
    Scene.Tiles[I].Height := Scene.TileH;
    if Scene.Tiles[I].X + Scene.TileW > Scene.Width then
      Scene.Tiles[I].Width := Scene.Width - Scene.Tiles[I].X;
    if Scene.Tiles[I].Y + Scene.TileH > Scene.Height then
      Scene.Tiles[I].Height := Scene.Height - Scene.Tiles[I].Y;

    if Pos + DataLen > SrcLen then Break;
    Scene.Tiles[I].CompSize := DataLen;
    GetMem(Scene.Tiles[I].Compressed, DataLen);
    Move(Src[Pos], Scene.Tiles[I].Compressed^, DataLen);
    Inc(Pos, DataLen);
    RIPTileDecompress(Scene.Tiles[I]);
  end;

  Scene.Loaded := True;
  Result := True;
end;

function RIPTileLoadFile(const FileName: ShortString;
  out Scene: TRIPTileScene): Boolean;
var F: File; Buf: PByte; FS, BR: LongInt;
begin
  Result := False; FillChar(Scene, SizeOf(Scene), 0);
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  GetMem(Buf, FS);
  BlockRead(F, Buf^, FS, BR);
  Close(F);
  if BR <> FS then begin FreeMem(Buf); Exit; end;
  Result := RIPTileLoadMem(Buf, FS, Scene);
  FreeMem(Buf);
end;

function RIPTileSaveFile(const FileName: ShortString;
  var Scene: TRIPTileScene): Boolean;
var
  F: File;
  Hdr: array[0..13] of Byte;
  I: Integer;
  TileHdr: array[0..5] of Byte;
begin
  Result := False;
  { Compress all tiles first }
  for I := 0 to Scene.NumTiles - 1 do
    if Scene.Tiles[I].Compressed = nil then
      RIPTileCompress(Scene.Tiles[I]);

  Assign(F, FileName);
  {$I-} Rewrite(F, 1); {$I+}
  if IOResult <> 0 then Exit;

  Hdr[0] := Ord('R'); Hdr[1] := Ord('I'); Hdr[2] := Ord('P'); Hdr[3] := Ord('T');
  Hdr[4] := Lo(Scene.Width); Hdr[5] := Hi(Scene.Width);
  Hdr[6] := Lo(Scene.Height); Hdr[7] := Hi(Scene.Height);
  Hdr[8] := Lo(Scene.TileW); Hdr[9] := Hi(Scene.TileW);
  Hdr[10] := Lo(Scene.TileH); Hdr[11] := Hi(Scene.TileH);
  Hdr[12] := Lo(Scene.NumTiles); Hdr[13] := Hi(Scene.NumTiles);
  BlockWrite(F, Hdr, 14);

  for I := 0 to Scene.NumTiles - 1 do
  begin
    TileHdr[0] := Lo(Scene.Tiles[I].X); TileHdr[1] := Hi(Scene.Tiles[I].X);
    TileHdr[2] := Lo(Scene.Tiles[I].Y); TileHdr[3] := Hi(Scene.Tiles[I].Y);
    TileHdr[4] := Lo(Word(Scene.Tiles[I].CompSize));
    TileHdr[5] := Hi(Word(Scene.Tiles[I].CompSize));
    BlockWrite(F, TileHdr, 6);
    if Scene.Tiles[I].CompSize > 0 then
      BlockWrite(F, Scene.Tiles[I].Compressed^, Scene.Tiles[I].CompSize);
  end;

  Close(F);
  Result := True;
end;

procedure RIPTileFree(var Scene: TRIPTileScene);
var I: Integer;
begin
  for I := 0 to RIPT_MAX_TILES - 1 do
  begin
    if Scene.Tiles[I].Data <> nil then begin FreeMem(Scene.Tiles[I].Data); Scene.Tiles[I].Data := nil; end;
    if Scene.Tiles[I].Compressed <> nil then begin FreeMem(Scene.Tiles[I].Compressed); Scene.Tiles[I].Compressed := nil; end;
  end;
  Scene.NumTiles := 0;
  Scene.Loaded := False;
end;

end.

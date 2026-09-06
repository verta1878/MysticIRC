(* flidec.pas -- FLI/FLC Autodesk Animation Decoder
   Copyright (C) 2026 Mystic BBS IRC Fork Contributors
   Licensed under GNU General Public License v3.

   Decodes Autodesk Animator FLI (320x200) and Animator Pro FLC
   (arbitrary resolution) animation files. Frame-by-frame decode
   to indexed palette + pixel buffer.

   FLI format: 320x200, 256 colors, delta compression
   FLC format: any resolution, 256 colors, more chunk types

   Chunk types supported:
     4  = COLOR_256 (full palette)
     7  = DELTA_FLC (word-level delta)
     11 = COLOR_64 (VGA DAC palette)
     12 = DELTA_FLI (byte-level delta, FLI only)
     13 = BLACK (clear frame)
     15 = BYTE_RUN (RLE full frame)
     16 = FLI_COPY (uncompressed)

   DOS 8.3 safe: flidec.pas (6 chars)
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit flidec;

interface

Const
  FLI_MAX_WIDTH  = 1280;
  FLI_MAX_HEIGHT = 1024;

Type
  TFLIPalette = Array[0..255, 0..2] of Byte;  // R, G, B

  TFLIHeader = record
    Size       : LongWord;    // file size
    Magic      : Word;        // $AF11 = FLI, $AF12 = FLC
    Frames     : Word;        // total frames
    Width      : Word;        // pixel width
    Height     : Word;        // pixel height
    Depth      : Word;        // bits per pixel (always 8)
    Flags      : Word;
    Speed      : LongWord;    // delay between frames (ms for FLC, 1/70s for FLI)
    Reserved   : Array[0..1] of LongWord;
    Created    : LongWord;    // creation timestamp
    Creator    : LongWord;    // creator ID
    Updated    : LongWord;
    Updater    : LongWord;
    AspectX    : Word;
    AspectY    : Word;
    Pad        : Array[0..37] of Byte;
  end;

  TFLIFile = record
    Header     : TFLIHeader;
    Palette    : TFLIPalette;
    Pixels     : PByte;       // Width × Height indexed pixels
    Width      : Word;
    Height     : Word;
    FrameCount : Word;
    CurrentFrame : Word;
    IsFLC      : Boolean;     // True = FLC, False = FLI
    FileData   : PByte;       // entire file in memory
    FileSize   : LongInt;
    FilePos    : LongInt;     // current read position
  end;

// Open and read FLI/FLC file header
function FLIOpen(var F: TFLIFile; const FileName: ShortString): Boolean;

// Decode next frame (advances CurrentFrame)
function FLINextFrame(var F: TFLIFile): Boolean;

// Decode specific frame (seeks from start)
function FLISeekFrame(var F: TFLIFile; FrameIdx: Word): Boolean;

// Get palette as RGB array
procedure FLIGetPalette(var F: TFLIFile; var Pal: TFLIPalette);

// Convert current indexed frame to RGB24 buffer
procedure FLIToRGB(var F: TFLIFile; RGBOut: PByte);

// Free all resources
procedure FLIClose(var F: TFLIFile);

// Get frame delay in milliseconds
function FLIFrameDelay(var F: TFLIFile): LongWord;

implementation

Const
  FLI_MAGIC = $AF11;
  FLC_MAGIC = $AF12;
  FRAME_MAGIC = $F1FA;

  CHUNK_COLOR256  = 4;
  CHUNK_DELTA_FLC = 7;
  CHUNK_COLOR64   = 11;
  CHUNK_DELTA_FLI = 12;
  CHUNK_BLACK     = 13;
  CHUNK_BYTE_RUN  = 15;
  CHUNK_FLI_COPY  = 16;

function ReadWord(var F: TFLIFile): Word;
Begin
  If F.FilePos + 2 > F.FileSize Then Begin Result := 0; Exit; End;
  Result := PWord(@F.FileData[F.FilePos])^;
  Inc(F.FilePos, 2);
End;

function ReadDWord(var F: TFLIFile): LongWord;
Begin
  If F.FilePos + 4 > F.FileSize Then Begin Result := 0; Exit; End;
  Result := PLongWord(@F.FileData[F.FilePos])^;
  Inc(F.FilePos, 4);
End;

function ReadByte(var F: TFLIFile): Byte;
Begin
  If F.FilePos >= F.FileSize Then Begin Result := 0; Exit; End;
  Result := F.FileData[F.FilePos];
  Inc(F.FilePos);
End;

function ReadSByte(var F: TFLIFile): ShortInt;
Begin
  Result := ShortInt(ReadByte(F));
End;

function ReadSWord(var F: TFLIFile): SmallInt;
Begin
  Result := SmallInt(ReadWord(F));
End;

procedure DecodeColor256(var F: TFLIFile);
Var
  Packets, Skip, Count : Word;
  I, Idx : Integer;
Begin
  Packets := ReadWord(F);
  Idx := 0;
  While Packets > 0 Do Begin
    Skip  := ReadByte(F);
    Count := ReadByte(F);
    If Count = 0 Then Count := 256;
    Idx := (Idx + Skip) MOD 256;
    For I := 0 to Count - 1 Do Begin
      F.Palette[(Idx + I) MOD 256, 0] := ReadByte(F);
      F.Palette[(Idx + I) MOD 256, 1] := ReadByte(F);
      F.Palette[(Idx + I) MOD 256, 2] := ReadByte(F);
    End;
    Idx := (Idx + Count) MOD 256;
    Dec(Packets);
  End;
End;

procedure DecodeColor64(var F: TFLIFile);
Var
  Packets, Skip, Count : Word;
  I, Idx : Integer;
Begin
  Packets := ReadWord(F);
  Idx := 0;
  While Packets > 0 Do Begin
    Skip  := ReadByte(F);
    Count := ReadByte(F);
    If Count = 0 Then Count := 256;
    Idx := (Idx + Skip) MOD 256;
    For I := 0 to Count - 1 Do Begin
      // VGA DAC values are 0-63, scale to 0-255
      F.Palette[(Idx + I) MOD 256, 0] := ReadByte(F) * 4;
      F.Palette[(Idx + I) MOD 256, 1] := ReadByte(F) * 4;
      F.Palette[(Idx + I) MOD 256, 2] := ReadByte(F) * 4;
    End;
    Idx := (Idx + Count) MOD 256;
    Dec(Packets);
  End;
End;

procedure DecodeBlack(var F: TFLIFile);
Begin
  FillChar(F.Pixels^, LongInt(F.Width) * F.Height, 0);
End;

procedure DecodeByteRun(var F: TFLIFile);
Var
  Y, X   : Word;
  Count  : ShortInt;
  Pixel  : Byte;
  Offset : LongInt;
Begin
  For Y := 0 to F.Height - 1 Do Begin
    ReadByte(F); // packet count (unused)
    X := 0;
    Offset := LongInt(Y) * F.Width;
    While X < F.Width Do Begin
      Count := ReadSByte(F);
      If Count < 0 Then Begin
        // -Count literal bytes
        Count := -Count;
        While (Count > 0) and (X < F.Width) Do Begin
          F.Pixels[Offset + X] := ReadByte(F);
          Inc(X);
          Dec(Count);
        End;
      End Else If Count > 0 Then Begin
        // Count repeated bytes
        Pixel := ReadByte(F);
        While (Count > 0) and (X < F.Width) Do Begin
          F.Pixels[Offset + X] := Pixel;
          Inc(X);
          Dec(Count);
        End;
      End;
    End;
  End;
End;

procedure DecodeCopy(var F: TFLIFile);
Var Size : LongInt;
Begin
  Size := LongInt(F.Width) * F.Height;
  If F.FilePos + Size > F.FileSize Then Size := F.FileSize - F.FilePos;
  If Size > 0 Then
    Move(F.FileData[F.FilePos], F.Pixels^, Size);
  Inc(F.FilePos, Size);
End;

procedure DecodeDeltaFLI(var F: TFLIFile);
Var
  Y, StartLine, Lines : Word;
  Packets, Skip, Count : Byte;
  Pixel  : Byte;
  X      : Word;
  Offset : LongInt;
Begin
  StartLine := ReadWord(F);
  Lines     := ReadWord(F);
  For Y := StartLine to StartLine + Lines - 1 Do Begin
    If Y >= F.Height Then Break;
    Offset := LongInt(Y) * F.Width;
    Packets := ReadByte(F);
    X := 0;
    While Packets > 0 Do Begin
      Skip  := ReadByte(F);
      Count := ReadByte(F);
      X := X + Skip;
      If Count > 0 Then Begin
        While (Count > 0) and (X < F.Width) Do Begin
          F.Pixels[Offset + X] := ReadByte(F);
          Inc(X);
          Dec(Count);
        End;
      End;
      Dec(Packets);
    End;
  End;
End;

procedure DecodeDeltaFLC(var F: TFLIFile);
Var
  Lines    : Word;
  Y        : Integer;
  Packets  : SmallInt;
  Skip     : Byte;
  Count    : ShortInt;
  Pixel    : Byte;
  PW       : Word;
  X        : Word;
  Offset   : LongInt;
Begin
  Lines := ReadWord(F);
  Y := 0;
  While Lines > 0 Do Begin
    Packets := ReadSWord(F);
    // Negative = skip lines, high bit set = last byte of line
    If Packets < 0 Then Begin
      If (Packets AND $C000) = $C000 Then Begin
        // Skip lines
        Y := Y + (-Packets);
        Continue;
      End;
      // Set last pixel
      If Y < F.Height Then Begin
        Offset := LongInt(Y) * F.Width;
        F.Pixels[Offset + F.Width - 1] := Lo(Word(Packets));
      End;
      Dec(Lines);
      Inc(Y);
      Continue;
    End;
    If Y >= F.Height Then Break;
    Offset := LongInt(Y) * F.Width;
    X := 0;
    While Packets > 0 Do Begin
      Skip := ReadByte(F);
      X := X + Skip;
      Count := ReadSByte(F);
      If Count > 0 Then Begin
        // Count words of literal data
        While (Count > 0) and (X + 1 < F.Width) Do Begin
          F.Pixels[Offset + X]     := ReadByte(F);
          F.Pixels[Offset + X + 1] := ReadByte(F);
          Inc(X, 2);
          Dec(Count);
        End;
      End Else If Count < 0 Then Begin
        // -Count repeated word
        Count := -Count;
        PW := ReadWord(F);
        While (Count > 0) and (X + 1 < F.Width) Do Begin
          F.Pixels[Offset + X]     := Lo(PW);
          F.Pixels[Offset + X + 1] := Hi(PW);
          Inc(X, 2);
          Dec(Count);
        End;
      End;
      Dec(Packets);
    End;
    Dec(Lines);
    Inc(Y);
  End;
End;

function FLIOpen(var F: TFLIFile; const FileName: ShortString): Boolean;
Var
  Fl     : File;
  FSize  : LongInt;
Begin
  Result := False;
  FillChar(F, SizeOf(F), 0);

  Assign(Fl, FileName);
  {$I-} System.Reset(Fl, 1); {$I+}
  If IOResult <> 0 Then Exit;

  FSize := FileSize(Fl);
  If FSize < SizeOf(TFLIHeader) Then Begin Close(Fl); Exit; End;

  GetMem(F.FileData, FSize);
  BlockRead(Fl, F.FileData^, FSize);
  Close(Fl);
  F.FileSize := FSize;
  F.FilePos  := 0;

  // Read header
  Move(F.FileData^, F.Header, SizeOf(TFLIHeader));
  F.FilePos := SizeOf(TFLIHeader);

  If (F.Header.Magic <> FLI_MAGIC) and (F.Header.Magic <> FLC_MAGIC) Then Begin
    FreeMem(F.FileData);
    F.FileData := Nil;
    Exit;
  End;

  F.IsFLC      := (F.Header.Magic = FLC_MAGIC);
  F.Width      := F.Header.Width;
  F.Height     := F.Header.Height;
  F.FrameCount := F.Header.Frames;
  F.CurrentFrame := 0;

  If F.Width = 0 Then F.Width := 320;
  If F.Height = 0 Then F.Height := 200;
  If F.Width > FLI_MAX_WIDTH Then F.Width := FLI_MAX_WIDTH;
  If F.Height > FLI_MAX_HEIGHT Then F.Height := FLI_MAX_HEIGHT;

  GetMem(F.Pixels, LongInt(F.Width) * F.Height);
  FillChar(F.Pixels^, LongInt(F.Width) * F.Height, 0);
  FillChar(F.Palette, SizeOf(F.Palette), 0);

  Result := True;
End;

function FLINextFrame(var F: TFLIFile): Boolean;
Var
  FrameSize   : LongWord;
  FrameMagic  : Word;
  ChunkCount  : Word;
  ChunkSize   : LongWord;
  ChunkType   : Word;
  ChunkEnd    : LongInt;
  FrameEnd    : LongInt;
  I           : Word;
Begin
  Result := False;
  If F.FileData = Nil Then Exit;
  If F.FilePos >= F.FileSize Then Exit;

  FrameSize  := ReadDWord(F);
  FrameMagic := ReadWord(F);
  ChunkCount := ReadWord(F);
  Inc(F.FilePos, 8); // skip reserved bytes
  FrameEnd := F.FilePos - 16 + LongInt(FrameSize);

  If FrameMagic <> FRAME_MAGIC Then Begin
    F.FilePos := FrameEnd;
    Exit;
  End;

  For I := 1 to ChunkCount Do Begin
    If F.FilePos >= F.FileSize Then Break;
    ChunkSize := ReadDWord(F);
    ChunkType := ReadWord(F);
    ChunkEnd  := F.FilePos - 6 + LongInt(ChunkSize);

    Case ChunkType of
      CHUNK_COLOR256:  DecodeColor256(F);
      CHUNK_COLOR64:   DecodeColor64(F);
      CHUNK_BLACK:     DecodeBlack(F);
      CHUNK_BYTE_RUN:  DecodeByteRun(F);
      CHUNK_FLI_COPY:  DecodeCopy(F);
      CHUNK_DELTA_FLI: DecodeDeltaFLI(F);
      CHUNK_DELTA_FLC: DecodeDeltaFLC(F);
    End;

    F.FilePos := ChunkEnd;
  End;

  F.FilePos := FrameEnd;
  Inc(F.CurrentFrame);
  Result := True;
End;

function FLISeekFrame(var F: TFLIFile; FrameIdx: Word): Boolean;
Var I : Word;
Begin
  Result := False;
  If F.FileData = Nil Then Exit;

  // Reset to start
  F.FilePos := SizeOf(TFLIHeader);
  F.CurrentFrame := 0;
  FillChar(F.Pixels^, LongInt(F.Width) * F.Height, 0);

  // Decode frames up to target
  For I := 0 to FrameIdx Do Begin
    If Not FLINextFrame(F) Then Exit;
  End;
  Result := True;
End;

procedure FLIGetPalette(var F: TFLIFile; var Pal: TFLIPalette);
Begin
  Move(F.Palette, Pal, SizeOf(TFLIPalette));
End;

procedure FLIToRGB(var F: TFLIFile; RGBOut: PByte);
Var
  I    : LongInt;
  Size : LongInt;
  Idx  : Byte;
Begin
  Size := LongInt(F.Width) * F.Height;
  For I := 0 to Size - 1 Do Begin
    Idx := F.Pixels[I];
    RGBOut[I * 3]     := F.Palette[Idx, 0];
    RGBOut[I * 3 + 1] := F.Palette[Idx, 1];
    RGBOut[I * 3 + 2] := F.Palette[Idx, 2];
  End;
End;

procedure FLIClose(var F: TFLIFile);
Begin
  If F.FileData <> Nil Then Begin FreeMem(F.FileData); F.FileData := Nil; End;
  If F.Pixels <> Nil Then Begin FreeMem(F.Pixels); F.Pixels := Nil; End;
  FillChar(F, SizeOf(F), 0);
End;

function FLIFrameDelay(var F: TFLIFile): LongWord;
Begin
  If F.IsFLC Then
    Result := F.Header.Speed       // FLC: milliseconds
  Else
    Result := F.Header.Speed * 14; // FLI: 1/70s → ms
End;

end.

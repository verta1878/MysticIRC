(* vocstrm.pas -- VOC Streaming Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Chunked VOC reading for streaming API. Decodes VOC blocks
   incrementally without loading the entire file.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit vocstrm;

interface

uses audstrm;

type
  TVOCStreamState = record
    F: File;
    FileOpen: Boolean;
    SampleRate: LongWord;
    BitsPerSample: Word;
    Channels: Word;
    DataPos: LongWord;
    BlockRemaining: LongWord;
    Done: Boolean;
  end;

function VOCStreamOpen(var S: TVOCStreamState;
  const FileName: ShortString): Boolean;
function VOCStreamDecode(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;
procedure VOCStreamClose(var S: TVOCStreamState);
function VOCStreamFormat(var S: TVOCStreamState): TAudioFormat;

implementation

function VOCStreamOpen(var S: TVOCStreamState;
  const FileName: ShortString): Boolean;
var
  Hdr: array[0..25] of Byte;
  BR: LongInt;
  Offset: Word;
begin
  Result := False;
  FillChar(S, SizeOf(S), 0);
  S.SampleRate := 8000;
  S.BitsPerSample := 8;
  S.Channels := 1;

  Assign(S.F, FileName);
  {$I-} Reset(S.F, 1); {$I+}
  if IOResult <> 0 then Exit;

  BlockRead(S.F, Hdr, 26, BR);
  if BR < 26 then begin Close(S.F); Exit; end;
  if Hdr[19] <> $1A then begin Close(S.F); Exit; end;

  Offset := Hdr[20] or (Word(Hdr[21]) shl 8);
  Seek(S.F, Offset);
  S.FileOpen := True;
  S.BlockRemaining := 0;
  S.Done := False;
  Result := True;
end;

function VOCStreamDecode(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;
var
  S: ^TVOCStreamState;
  BR: LongInt;
  BlockType: Byte;
  BlockLen: LongWord;
  TC, Codec: Byte;
  ToRead: LongInt;
  B: array[0..5] of Byte;
begin
  S := UserData;
  Result := 0;
  if not S^.FileOpen or S^.Done then Exit;

  { Need new block? }
  while S^.BlockRemaining = 0 do
  begin
    BlockRead(S^.F, BlockType, 1, BR);
    if BR = 0 then begin S^.Done := True; Exit; end;
    if BlockType = 0 then begin S^.Done := True; Exit; end;

    BlockRead(S^.F, B, 3, BR);
    if BR < 3 then begin S^.Done := True; Exit; end;
    BlockLen := B[0] or (LongWord(B[1]) shl 8) or (LongWord(B[2]) shl 16);

    case BlockType of
      1: begin
        BlockRead(S^.F, B, 2, BR);
        TC := B[0]; Codec := B[1];
        S^.SampleRate := 1000000 div (256 - LongWord(TC));
        S^.BlockRemaining := BlockLen - 2;
      end;
      2: S^.BlockRemaining := BlockLen;
      9: begin
        BlockRead(S^.F, B, 4, BR);
        S^.SampleRate := B[0] or (LongWord(B[1]) shl 8) or
          (LongWord(B[2]) shl 16) or (LongWord(B[3]) shl 24);
        BlockRead(S^.F, B, 2, BR);
        S^.BitsPerSample := B[0];
        S^.Channels := B[1];
        BlockRead(S^.F, B, 6, BR); { codec + reserved }
        S^.BlockRemaining := BlockLen - 12;
      end;
    else
      { Skip unknown block }
      Seek(S^.F, FilePos(S^.F) + BlockLen);
    end;
  end;

  ToRead := BufSize;
  if ToRead > LongInt(S^.BlockRemaining) then ToRead := S^.BlockRemaining;
  BlockRead(S^.F, Buffer^, ToRead, BR);
  Dec(S^.BlockRemaining, BR);
  Result := BR;
end;

procedure VOCStreamClose(var S: TVOCStreamState);
begin
  if S.FileOpen then begin Close(S.F); S.FileOpen := False; end;
end;

function VOCStreamFormat(var S: TVOCStreamState): TAudioFormat;
begin
  Result := AudioFmt(S.SampleRate, S.BitsPerSample, S.Channels);
end;

end.

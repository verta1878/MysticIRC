(* wavstrm.pas -- WAV Streaming Decoder
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Chunked WAV reading — decodes PCM in blocks for the streaming API.
   Feeds audstrm.pas with chunks without loading the entire file.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit wavstrm;

interface

uses audstrm;

type
  TWAVStreamState = record
    FileName: ShortString;
    DataOffset: LongWord;
    DataSize: LongWord;
    DataPos: LongWord;
    SampleRate: LongWord;
    BitsPerSample: Word;
    Channels: Word;
    FileOpen: Boolean;
    F: File;
  end;

function WAVStreamOpen(var S: TWAVStreamState;
  const FileName: ShortString): Boolean;
function WAVStreamDecode(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;
procedure WAVStreamClose(var S: TWAVStreamState);
function WAVStreamFormat(var S: TWAVStreamState): TAudioFormat;

implementation

function RL16(P: PByte): Word;
begin Result := Word(P[0]) or (Word(P[1]) shl 8); end;
function RL32(P: PByte): LongWord;
begin Result := LongWord(P[0]) or (LongWord(P[1]) shl 8) or
  (LongWord(P[2]) shl 16) or (LongWord(P[3]) shl 24); end;

function WAVStreamOpen(var S: TWAVStreamState;
  const FileName: ShortString): Boolean;
var
  Hdr: array[0..43] of Byte;
  BR: LongInt;
  Pos: LongInt;
  ChunkID: LongWord;
  ChunkSize: LongWord;
begin
  Result := False;
  FillChar(S, SizeOf(S), 0);
  S.FileName := FileName;
  Assign(S.F, FileName);
  {$I-} Reset(S.F, 1); {$I+}
  if IOResult <> 0 then Exit;

  BlockRead(S.F, Hdr, 44, BR);
  if BR < 44 then begin Close(S.F); Exit; end;

  if (Hdr[0] <> Ord('R')) or (Hdr[8] <> Ord('W')) then begin Close(S.F); Exit; end;

  { Find fmt chunk }
  Pos := 12;
  while Pos + 8 <= BR do
  begin
    ChunkID := RL32(@Hdr[Pos]);
    ChunkSize := RL32(@Hdr[Pos + 4]);
    if ChunkID = $20746D66 then { 'fmt ' }
    begin
      S.Channels := RL16(@Hdr[Pos + 10]);
      S.SampleRate := RL32(@Hdr[Pos + 12]);
      S.BitsPerSample := RL16(@Hdr[Pos + 22]);
    end
    else if ChunkID = $61746164 then { 'data' }
    begin
      S.DataOffset := Pos + 8;
      S.DataSize := ChunkSize;
      Break;
    end;
    Inc(Pos, 8 + ChunkSize);
    if (ChunkSize and 1) <> 0 then Inc(Pos);
  end;

  if (S.SampleRate = 0) or (S.DataSize = 0) then begin Close(S.F); Exit; end;

  { Seek to data start }
  Seek(S.F, S.DataOffset);
  S.DataPos := 0;
  S.FileOpen := True;
  Result := True;
end;

function WAVStreamDecode(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;
var
  S: ^TWAVStreamState;
  Remaining: LongInt;
  ToRead: LongInt;
  BR: LongInt;
begin
  S := UserData;
  Result := 0;
  if not S^.FileOpen then Exit;

  Remaining := LongInt(S^.DataSize) - LongInt(S^.DataPos);
  if Remaining <= 0 then Exit;

  ToRead := BufSize;
  if ToRead > Remaining then ToRead := Remaining;

  BlockRead(S^.F, Buffer^, ToRead, BR);
  Inc(S^.DataPos, BR);
  Result := BR;
end;

procedure WAVStreamClose(var S: TWAVStreamState);
begin
  if S.FileOpen then begin Close(S.F); S.FileOpen := False; end;
end;

function WAVStreamFormat(var S: TWAVStreamState): TAudioFormat;
begin
  Result := AudioFmt(S.SampleRate, S.BitsPerSample, S.Channels);
end;

end.

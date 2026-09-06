{ This file is part of FPC 2.6.4irc.
  Copyright (C) 2026 fpc264irc contributors.

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see <https://www.gnu.org/licenses/>.
}
{ WAV/PCM Decoder — Raw File I/O version (short string mode compatible)
  No Classes unit, no TStream. Uses BlockRead.

  Usage:
    var WAV: TWAVInfoRaw;
    begin
      if WAVLoadFileRaw('sound.wav', WAV) then
      begin
        // WAV.Data^ = raw PCM, WAV.SampleRate, etc.
        WAVFreeRaw(WAV);
      end;
    end;
}
unit pcmdecr;

{$H-}
{$mode objfpc}

interface

type
  TWAVInfoRaw = record
    Channels: Word;
    SampleRate: LongWord;
    BitsPerSample: Word;
    BlockAlign: Word;
    ByteRate: LongWord;
    DataSize: LongWord;
    NumSamples: LongWord;
    Data: PByte;
    Valid: Boolean;
  end;

function WAVLoadFileRaw(const FileName: string; out Info: TWAVInfoRaw): Boolean;
function WAVLoadMemRaw(InBuf: PByte; InSize: LongWord; out Info: TWAVInfoRaw): Boolean;
procedure WAVFreeRaw(var Info: TWAVInfoRaw);
function WAVDurationMSRaw(const Info: TWAVInfoRaw): LongWord;
function IsWAVFile(const FileName: string): Boolean;

implementation

type
  TChunkHdr = packed record
    ID: array[0..3] of Char;
    Size: LongWord;
  end;

function WAVLoadMemRaw(InBuf: PByte; InSize: LongWord; out Info: TWAVInfoRaw): Boolean;
var
  Pos: LongWord;
  Chunk: TChunkHdr;
  FmtFound, DataFound: Boolean;
  AudioFormat: Word;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);

  if (InBuf = nil) or (InSize < 44) then Exit;

  // Check RIFF/WAVE
  if (InBuf[0] <> Ord('R')) or (InBuf[1] <> Ord('I')) or
     (InBuf[2] <> Ord('F')) or (InBuf[3] <> Ord('F')) then Exit;
  if (InBuf[8] <> Ord('W')) or (InBuf[9] <> Ord('A')) or
     (InBuf[10] <> Ord('V')) or (InBuf[11] <> Ord('E')) then Exit;

  Pos := 12;
  FmtFound := False;
  DataFound := False;

  while Pos + 8 <= InSize do
  begin
    Move(InBuf[Pos], Chunk, 8);
    Inc(Pos, 8);

    if (Chunk.ID[0] = 'f') and (Chunk.ID[1] = 'm') and
       (Chunk.ID[2] = 't') and (Chunk.ID[3] = ' ') then
    begin
      if Pos + 16 > InSize then Exit;
      Move(InBuf[Pos], AudioFormat, 2);
      if AudioFormat <> 1 then Exit; // PCM only
      Move(InBuf[Pos + 2], Info.Channels, 2);
      Move(InBuf[Pos + 4], Info.SampleRate, 4);
      Move(InBuf[Pos + 8], Info.ByteRate, 4);
      Move(InBuf[Pos + 12], Info.BlockAlign, 2);
      Move(InBuf[Pos + 14], Info.BitsPerSample, 2);
      FmtFound := True;
    end
    else if (Chunk.ID[0] = 'd') and (Chunk.ID[1] = 'a') and
            (Chunk.ID[2] = 't') and (Chunk.ID[3] = 'a') then
    begin
      Info.DataSize := Chunk.Size;
      if Info.DataSize > InSize - Pos then
        Info.DataSize := InSize - Pos;
      GetMem(Info.Data, Info.DataSize);
      Move(InBuf[Pos], Info.Data^, Info.DataSize);
      DataFound := True;
    end;

    Pos := Pos - 8 + 8 + Chunk.Size;
    if (Pos and 1) <> 0 then Inc(Pos);

    if FmtFound and DataFound then Break;
  end;

  if FmtFound and DataFound and (Info.BlockAlign > 0) then
  begin
    Info.NumSamples := Info.DataSize div Info.BlockAlign;
    Info.Valid := True;
    Result := True;
  end
  else if Info.Data <> nil then
  begin
    FreeMem(Info.Data);
    Info.Data := nil;
  end;
end;

function WAVLoadFileRaw(const FileName: string; out Info: TWAVInfoRaw): Boolean;
var
  F: File;
  Buf: PByte;
  Size, BytesRead: LongWord;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);

  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  {$I+}

  Size := FileSize(F);
  if Size < 44 then begin Close(F); Exit; end;

  GetMem(Buf, Size);
  BlockRead(F, Buf^, Size, BytesRead);
  Close(F);

  if BytesRead = Size then
    Result := WAVLoadMemRaw(Buf, Size, Info);
  FreeMem(Buf);
end;

procedure WAVFreeRaw(var Info: TWAVInfoRaw);
begin
  if Info.Data <> nil then
  begin
    FreeMem(Info.Data);
    Info.Data := nil;
  end;
  Info.Valid := False;
end;

function WAVDurationMSRaw(const Info: TWAVInfoRaw): LongWord;
begin
  if Info.ByteRate > 0 then
    Result := (Info.DataSize * 1000) div Info.ByteRate
  else
    Result := 0;
end;

function IsWAVFile(const FileName: string): Boolean;
var
  F: File;
  Sig: array[0..3] of Byte;
  BytesRead: LongWord;
begin
  Result := False;
  {$I-}
  Assign(F, FileName);
  Reset(F, 1);
  if IOResult <> 0 then Exit;
  {$I+}
  BlockRead(F, Sig, 4, BytesRead);
  Close(F);
  Result := (BytesRead = 4) and (Sig[0] = Ord('R')) and (Sig[1] = Ord('I'))
            and (Sig[2] = Ord('F')) and (Sig[3] = Ord('F'));
end;

end.

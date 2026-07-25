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
{ WAV File Decoder — Pure Pascal RIFF/WAVE reader
  Reads standard PCM WAV files (8-bit, 16-bit, mono, stereo).
  No external dependencies, compiles on all FPC targets.

  Usage:
    var WAV: TWAVInfo;
    begin
      if WAVLoadFile('sound.wav', WAV) then
      begin
        // WAV.Data^ = raw PCM samples
        // WAV.SampleRate, WAV.Channels, WAV.BitsPerSample
        // WAV.DataSize = total bytes of PCM data
        // WAV.NumSamples = total sample frames
        WAVFree(WAV);
      end;
    end;
}
unit PCMDec;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TWAVFormat = (
    wfUnknown,
    wfPCM,          // 1 = uncompressed PCM
    wfIEEEFloat,    // 3 = IEEE float
    wfALaw,         // 6 = A-law
    wfMuLaw         // 7 = mu-law
  );

  TWAVInfo = record
    Format: TWAVFormat;
    Channels: Word;        // 1 = mono, 2 = stereo
    SampleRate: LongWord;  // e.g., 8000, 11025, 22050, 44100
    BitsPerSample: Word;   // 8 or 16 (or 24, 32)
    BlockAlign: Word;      // bytes per sample frame
    ByteRate: LongWord;    // bytes per second
    DataSize: LongWord;    // total PCM data bytes
    NumSamples: LongWord;  // total sample frames
    Data: PByte;           // raw PCM data (caller must free via WAVFree)
    Valid: Boolean;
  end;

{ Load WAV from file }
function WAVLoadFile(const FileName: string; out Info: TWAVInfo): Boolean;

{ Load WAV from stream }
function WAVLoadStream(AStream: TStream; out Info: TWAVInfo): Boolean;

{ Load WAV from memory buffer }
function WAVLoadMem(InBuf: PByte; InSize: LongWord; out Info: TWAVInfo): Boolean;

{ Get WAV info without loading sample data }
function WAVGetInfo(const FileName: string; out Info: TWAVInfo): Boolean;

{ Free WAV data }
procedure WAVFree(var Info: TWAVInfo);

{ Helper: duration in milliseconds }
function WAVDurationMS(const Info: TWAVInfo): LongWord;

{ Helper: duration in seconds (float) }
function WAVDurationSec(const Info: TWAVInfo): Double;

implementation

type
  TRIFFHeader = packed record
    ChunkID: array[0..3] of Char;     // 'RIFF'
    ChunkSize: LongWord;               // file size - 8
    Format: array[0..3] of Char;       // 'WAVE'
  end;

  TFmtChunk = packed record
    SubchunkID: array[0..3] of Char;   // 'fmt '
    SubchunkSize: LongWord;            // 16 for PCM
    AudioFormat: Word;                 // 1 = PCM
    NumChannels: Word;
    SampleRate: LongWord;
    ByteRate: LongWord;
    BlockAlign: Word;
    BitsPerSample: Word;
  end;

  TChunkHeader = packed record
    ID: array[0..3] of Char;
    Size: LongWord;
  end;

function FormatFromWord(W: Word): TWAVFormat;
begin
  case W of
    1: Result := wfPCM;
    3: Result := wfIEEEFloat;
    6: Result := wfALaw;
    7: Result := wfMuLaw;
  else
    Result := wfUnknown;
  end;
end;

function WAVLoadMem(InBuf: PByte; InSize: LongWord; out Info: TWAVInfo): Boolean;
var
  Pos: LongWord;
  RIFF: TRIFFHeader;
  Fmt: TFmtChunk;
  Chunk: TChunkHeader;
  FmtFound, DataFound: Boolean;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);

  if (InBuf = nil) or (InSize < SizeOf(TRIFFHeader) + SizeOf(TFmtChunk)) then
    Exit;

  // Read RIFF header
  Move(InBuf[0], RIFF, SizeOf(RIFF));
  if (RIFF.ChunkID <> 'RIFF') or (RIFF.Format <> 'WAVE') then
    Exit;

  Pos := SizeOf(TRIFFHeader);
  FmtFound := False;
  DataFound := False;

  // Walk chunks
  while Pos + SizeOf(TChunkHeader) <= InSize do
  begin
    Move(InBuf[Pos], Chunk, SizeOf(TChunkHeader));
    Inc(Pos, SizeOf(TChunkHeader));

    if Chunk.ID = 'fmt ' then
    begin
      if Pos + 16 > InSize then Exit;
      Move(InBuf[Pos - SizeOf(TChunkHeader)], Fmt, SizeOf(TFmtChunk));
      Info.Format := FormatFromWord(Fmt.AudioFormat);
      Info.Channels := Fmt.NumChannels;
      Info.SampleRate := Fmt.SampleRate;
      Info.ByteRate := Fmt.ByteRate;
      Info.BlockAlign := Fmt.BlockAlign;
      Info.BitsPerSample := Fmt.BitsPerSample;
      FmtFound := True;
    end
    else if Chunk.ID = 'data' then
    begin
      Info.DataSize := Chunk.Size;
      if Info.DataSize > InSize - Pos then
        Info.DataSize := InSize - Pos;

      GetMem(Info.Data, Info.DataSize);
      Move(InBuf[Pos], Info.Data^, Info.DataSize);
      DataFound := True;
    end;

    // Advance to next chunk (word-aligned)
    Pos := Pos - SizeOf(TChunkHeader) + SizeOf(TChunkHeader) + Chunk.Size;
    if (Pos and 1) <> 0 then Inc(Pos); // pad to word boundary

    if FmtFound and DataFound then Break;
  end;

  if FmtFound and DataFound and (Info.BlockAlign > 0) then
  begin
    Info.NumSamples := Info.DataSize div Info.BlockAlign;
    Info.Valid := True;
    Result := True;
  end
  else
  begin
    if Info.Data <> nil then
    begin
      FreeMem(Info.Data);
      Info.Data := nil;
    end;
  end;
end;

function WAVLoadStream(AStream: TStream; out Info: TWAVInfo): Boolean;
var
  Buf: PByte;
  Size: LongWord;
begin
  Size := AStream.Size - AStream.Position;
  GetMem(Buf, Size);
  try
    AStream.ReadBuffer(Buf^, Size);
    Result := WAVLoadMem(Buf, Size, Info);
  finally
    FreeMem(Buf);
  end;
end;

function WAVLoadFile(const FileName: string; out Info: TWAVInfo): Boolean;
var
  F: TFileStream;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);
  if not FileExists(FileName) then Exit;
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    Result := WAVLoadStream(F, Info);
  finally
    F.Free;
  end;
end;

function WAVGetInfo(const FileName: string; out Info: TWAVInfo): Boolean;
var
  F: TFileStream;
  Buf: array[0..255] of Byte;
  BytesRead: LongInt;
  RIFF: TRIFFHeader;
  Fmt: TFmtChunk;
  Chunk: TChunkHeader;
  Pos: LongWord;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);
  if not FileExists(FileName) then Exit;

  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    BytesRead := F.Read(Buf, SizeOf(Buf));
    if BytesRead < SizeOf(TRIFFHeader) + SizeOf(TFmtChunk) then Exit;

    Move(Buf[0], RIFF, SizeOf(RIFF));
    if (RIFF.ChunkID <> 'RIFF') or (RIFF.Format <> 'WAVE') then Exit;

    Pos := SizeOf(TRIFFHeader);
    while Pos + SizeOf(TChunkHeader) <= LongWord(BytesRead) do
    begin
      Move(Buf[Pos], Chunk, SizeOf(TChunkHeader));
      Inc(Pos, SizeOf(TChunkHeader));

      if Chunk.ID = 'fmt ' then
      begin
        Move(Buf[Pos - SizeOf(TChunkHeader)], Fmt, SizeOf(TFmtChunk));
        Info.Format := FormatFromWord(Fmt.AudioFormat);
        Info.Channels := Fmt.NumChannels;
        Info.SampleRate := Fmt.SampleRate;
        Info.ByteRate := Fmt.ByteRate;
        Info.BlockAlign := Fmt.BlockAlign;
        Info.BitsPerSample := Fmt.BitsPerSample;
      end
      else if Chunk.ID = 'data' then
      begin
        Info.DataSize := Chunk.Size;
        if Info.BlockAlign > 0 then
          Info.NumSamples := Info.DataSize div Info.BlockAlign;
        Info.Valid := True;
        Result := True;
        Exit;
      end;

      Pos := Pos - SizeOf(TChunkHeader) + SizeOf(TChunkHeader) + Chunk.Size;
      if (Pos and 1) <> 0 then Inc(Pos);
    end;
  finally
    F.Free;
  end;
end;

procedure WAVFree(var Info: TWAVInfo);
begin
  if Info.Data <> nil then
  begin
    FreeMem(Info.Data);
    Info.Data := nil;
  end;
  Info.Valid := False;
end;

function WAVDurationMS(const Info: TWAVInfo): LongWord;
begin
  if Info.ByteRate > 0 then
    Result := (Info.DataSize * 1000) div Info.ByteRate
  else
    Result := 0;
end;

function WAVDurationSec(const Info: TWAVInfo): Double;
begin
  if Info.ByteRate > 0 then
    Result := Info.DataSize / Info.ByteRate
  else
    Result := 0;
end;

end.

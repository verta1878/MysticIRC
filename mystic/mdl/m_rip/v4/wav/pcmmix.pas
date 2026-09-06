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
{ PCM Audio Mixer — Pure Pascal
  Mixes multiple PCM audio streams into one output buffer.
  Supports 8-bit and 16-bit, mono and stereo.
  Uses saturation clipping to prevent overflow distortion.

  Usage:
    var Mix: TPCMMixer;
    begin
      Mix := TPCMMixer.Create(22050, 16, 1); // 22kHz 16-bit mono
      Mix.AddStream(WAV1.Data, WAV1.DataSize);
      Mix.AddStream(WAV2.Data, WAV2.DataSize);
      Mix.MixAll(OutputBuf, OutputSize);
      Mix.Free;
    end;
}
unit PCMMix;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

const
  MAX_MIX_STREAMS = 16;

type
  TPCMStream = record
    Data: PByte;
    Size: LongWord;
    Position: LongWord;
    Volume: Integer;     // 0..256 (256 = full volume)
    Active: Boolean;
  end;

  TPCMMixer = class
  private
    FStreams: array[0..MAX_MIX_STREAMS-1] of TPCMStream;
    FStreamCount: Integer;
    FSampleRate: LongWord;
    FBitsPerSample: Word;
    FChannels: Word;
  public
    constructor Create(ASampleRate: LongWord; ABits: Word; AChannels: Word);
    destructor Destroy; override;

    { Add a PCM stream to the mix (same format as mixer) }
    function AddStream(Data: PByte; Size: LongWord; Volume: Integer = 256): Integer;

    { Remove a stream by index }
    procedure RemoveStream(Index: Integer);

    { Set stream volume (0..256) }
    procedure SetVolume(Index: Integer; Volume: Integer);

    { Reset stream position to beginning }
    procedure RewindStream(Index: Integer);

    { Rewind all streams }
    procedure RewindAll;

    { Mix all active streams into output buffer }
    procedure MixAll(OutBuf: PByte; OutSize: LongWord);

    { Mix a specific number of samples }
    procedure MixSamples(OutBuf: PByte; NumFrames: LongWord);

    { Check if any streams still have data }
    function HasActiveStreams: Boolean;

    { Clear all streams }
    procedure Clear;

    property StreamCount: Integer read FStreamCount;
    property SampleRate: LongWord read FSampleRate;
    property BitsPerSample: Word read FBitsPerSample;
    property Channels: Word read FChannels;
  end;

{ Standalone mix functions }

{ Mix two 8-bit PCM buffers with saturation }
procedure MixBuffers8(Src1, Src2, Dst: PByte; Count: LongWord;
  Vol1: Integer = 256; Vol2: Integer = 256);

{ Mix two 16-bit PCM buffers with saturation }
procedure MixBuffers16(Src1, Src2, Dst: PByte; Count: LongWord;
  Vol1: Integer = 256; Vol2: Integer = 256);

{ Adjust volume of a buffer in-place }
procedure AdjustVolume8(Buf: PByte; Count: LongWord; Volume: Integer);
procedure AdjustVolume16(Buf: PByte; Count: LongWord; Volume: Integer);

{ Clamp helper }
function Clamp16(Value: LongInt): SmallInt; inline;
function Clamp8(Value: LongInt): Byte; inline;

implementation

function Clamp16(Value: LongInt): SmallInt; inline;
begin
  if Value > 32767 then Result := 32767
  else if Value < -32768 then Result := -32768
  else Result := SmallInt(Value);
end;

function Clamp8(Value: LongInt): Byte; inline;
begin
  if Value > 255 then Result := 255
  else if Value < 0 then Result := 0
  else Result := Byte(Value);
end;

procedure MixBuffers8(Src1, Src2, Dst: PByte; Count: LongWord;
  Vol1: Integer; Vol2: Integer);
var
  I: LongWord;
  S1, S2, Mixed: LongInt;
begin
  for I := 0 to Count - 1 do
  begin
    // 8-bit PCM is unsigned (128 = silence)
    S1 := (LongInt(Src1[I]) - 128) * Vol1 div 256;
    S2 := (LongInt(Src2[I]) - 128) * Vol2 div 256;
    Mixed := S1 + S2 + 128;
    Dst[I] := Clamp8(Mixed);
  end;
end;

procedure MixBuffers16(Src1, Src2, Dst: PByte; Count: LongWord;
  Vol1: Integer; Vol2: Integer);
var
  I: LongWord;
  P1, P2, PD: PSmallInt;
  S1, S2, Mixed: LongInt;
begin
  P1 := PSmallInt(Src1);
  P2 := PSmallInt(Src2);
  PD := PSmallInt(Dst);
  for I := 0 to Count - 1 do
  begin
    S1 := LongInt(P1[I]) * Vol1 div 256;
    S2 := LongInt(P2[I]) * Vol2 div 256;
    Mixed := S1 + S2;
    PD[I] := Clamp16(Mixed);
  end;
end;

procedure AdjustVolume8(Buf: PByte; Count: LongWord; Volume: Integer);
var
  I: LongWord;
  S: LongInt;
begin
  for I := 0 to Count - 1 do
  begin
    S := (LongInt(Buf[I]) - 128) * Volume div 256 + 128;
    Buf[I] := Clamp8(S);
  end;
end;

procedure AdjustVolume16(Buf: PByte; Count: LongWord; Volume: Integer);
var
  I: LongWord;
  P: PSmallInt;
  S: LongInt;
begin
  P := PSmallInt(Buf);
  for I := 0 to Count - 1 do
  begin
    S := LongInt(P[I]) * Volume div 256;
    P[I] := Clamp16(S);
  end;
end;

{ TPCMMixer }

constructor TPCMMixer.Create(ASampleRate: LongWord; ABits: Word; AChannels: Word);
begin
  inherited Create;
  FSampleRate := ASampleRate;
  FBitsPerSample := ABits;
  FChannels := AChannels;
  FStreamCount := 0;
  FillChar(FStreams, SizeOf(FStreams), 0);
end;

destructor TPCMMixer.Destroy;
begin
  inherited;
end;

function TPCMMixer.AddStream(Data: PByte; Size: LongWord; Volume: Integer): Integer;
begin
  Result := -1;
  if FStreamCount >= MAX_MIX_STREAMS then Exit;
  FStreams[FStreamCount].Data := Data;
  FStreams[FStreamCount].Size := Size;
  FStreams[FStreamCount].Position := 0;
  FStreams[FStreamCount].Volume := Volume;
  FStreams[FStreamCount].Active := True;
  Result := FStreamCount;
  Inc(FStreamCount);
end;

procedure TPCMMixer.RemoveStream(Index: Integer);
var I: Integer;
begin
  if (Index < 0) or (Index >= FStreamCount) then Exit;
  for I := Index to FStreamCount - 2 do
    FStreams[I] := FStreams[I + 1];
  Dec(FStreamCount);
end;

procedure TPCMMixer.SetVolume(Index: Integer; Volume: Integer);
begin
  if (Index >= 0) and (Index < FStreamCount) then
    FStreams[Index].Volume := Volume;
end;

procedure TPCMMixer.RewindStream(Index: Integer);
begin
  if (Index >= 0) and (Index < FStreamCount) then
  begin
    FStreams[Index].Position := 0;
    FStreams[Index].Active := True;
  end;
end;

procedure TPCMMixer.RewindAll;
var I: Integer;
begin
  for I := 0 to FStreamCount - 1 do
  begin
    FStreams[I].Position := 0;
    FStreams[I].Active := True;
  end;
end;

procedure TPCMMixer.MixSamples(OutBuf: PByte; NumFrames: LongWord);
var
  I, J: Integer;
  FrameBytes: LongWord;
  Mixed: LongInt;
  Remaining: LongWord;
  Pos: LongWord;
begin
  FrameBytes := LongWord(FChannels) * (FBitsPerSample div 8);

  if FBitsPerSample = 16 then
  begin
    // 16-bit mixing
    FillChar(OutBuf^, NumFrames * FrameBytes, 0);
    for I := 0 to FStreamCount - 1 do
    begin
      if not FStreams[I].Active then Continue;
      Pos := FStreams[I].Position;
      Remaining := (FStreams[I].Size - Pos) div 2;
      if Remaining > NumFrames * FChannels then
        Remaining := NumFrames * FChannels;
      for J := 0 to Integer(Remaining) - 1 do
      begin
        Mixed := LongInt(PSmallInt(@OutBuf[J * 2])^) +
                 (LongInt(PSmallInt(@FStreams[I].Data[Pos + LongWord(J) * 2])^) *
                  FStreams[I].Volume div 256);
        PSmallInt(@OutBuf[J * 2])^ := Clamp16(Mixed);
      end;
      Inc(FStreams[I].Position, Remaining * 2);
      if FStreams[I].Position >= FStreams[I].Size then
        FStreams[I].Active := False;
    end;
  end
  else
  begin
    // 8-bit mixing
    FillChar(OutBuf^, NumFrames * FrameBytes, 128); // 128 = silence for 8-bit
    for I := 0 to FStreamCount - 1 do
    begin
      if not FStreams[I].Active then Continue;
      Pos := FStreams[I].Position;
      Remaining := FStreams[I].Size - Pos;
      if Remaining > NumFrames * FChannels then
        Remaining := NumFrames * FChannels;
      for J := 0 to Integer(Remaining) - 1 do
      begin
        Mixed := LongInt(OutBuf[J]) +
                 ((LongInt(FStreams[I].Data[Pos + LongWord(J)]) - 128) *
                  FStreams[I].Volume div 256);
        OutBuf[J] := Clamp8(Mixed);
      end;
      Inc(FStreams[I].Position, Remaining);
      if FStreams[I].Position >= FStreams[I].Size then
        FStreams[I].Active := False;
    end;
  end;
end;

procedure TPCMMixer.MixAll(OutBuf: PByte; OutSize: LongWord);
var
  FrameBytes: LongWord;
  NumFrames: LongWord;
begin
  FrameBytes := LongWord(FChannels) * (FBitsPerSample div 8);
  NumFrames := OutSize div FrameBytes;
  MixSamples(OutBuf, NumFrames);
end;

function TPCMMixer.HasActiveStreams: Boolean;
var I: Integer;
begin
  Result := False;
  for I := 0 to FStreamCount - 1 do
    if FStreams[I].Active then
    begin
      Result := True;
      Exit;
    end;
end;

procedure TPCMMixer.Clear;
begin
  FStreamCount := 0;
  FillChar(FStreams, SizeOf(FStreams), 0);
end;

end.

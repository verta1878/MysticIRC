(* audstrm.pas -- Audio Streaming API
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Callback-based audio streaming framework. Decoders feed PCM
   chunks to a stream which delivers them to the playback backend.
   Decouples decode from playback for real-time audio.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit audstrm;

interface

const
  AUS_CHUNK_SIZE = 4096;   { bytes per chunk }
  AUS_MAX_STREAMS = 8;

type
  TAudioFormat = record
    SampleRate: LongWord;
    BitsPerSample: Word;
    Channels: Word;
  end;

  TAudioState = (asIdle, asPlaying, asPaused, asStopped);

  { Callback: decoder fills Buffer with up to BufSize bytes of PCM.
    Returns actual bytes written. Return 0 = end of stream. }
  TAudioDecodeCallback = function(Buffer: PByte; BufSize: LongInt;
    UserData: Pointer): LongInt;

  { Callback: playback backend consumes Buffer }
  TAudioOutputCallback = procedure(Buffer: PByte; BufSize: LongInt;
    UserData: Pointer);

  TAudioStream = record
    Format: TAudioFormat;
    State: TAudioState;
    DecodeCallback: TAudioDecodeCallback;
    OutputCallback: TAudioOutputCallback;
    DecodeData: Pointer;
    OutputData: Pointer;
    ChunkBuf: array[0..AUS_CHUNK_SIZE - 1] of Byte;
    ChunkReady: LongInt;   { bytes in chunk buffer }
    TotalDecoded: LongWord;
    TotalPlayed: LongWord;
    Loop: Boolean;
    Volume: Byte;           { 0-255 }
    Active: Boolean;
  end;

  TAudioStreamManager = record
    Streams: array[0..AUS_MAX_STREAMS - 1] of TAudioStream;
    MixBuf: array[0..AUS_CHUNK_SIZE - 1] of Byte;
    MasterFormat: TAudioFormat;
    MasterVolume: Byte;
    Active: Boolean;
  end;

{ Initialize a stream }
procedure AStreamInit(var S: TAudioStream; var Fmt: TAudioFormat;
  DecodeCB: TAudioDecodeCallback; DecodeData: Pointer);

{ Set output callback }
procedure AStreamSetOutput(var S: TAudioStream;
  OutputCB: TAudioOutputCallback; OutputData: Pointer);

{ Pump: decode one chunk and deliver to output }
function AStreamPump(var S: TAudioStream): Boolean;

{ Control }
procedure AStreamPlay(var S: TAudioStream);
procedure AStreamPause(var S: TAudioStream);
procedure AStreamStop(var S: TAudioStream);
procedure AStreamReset(var S: TAudioStream);

{ Manager: mix multiple streams }
procedure AStreamMgrInit(var Mgr: TAudioStreamManager;
  SampleRate: LongWord; Channels: Word);
function AStreamMgrAdd(var Mgr: TAudioStreamManager;
  var Fmt: TAudioFormat;
  DecodeCB: TAudioDecodeCallback; DecodeData: Pointer): Integer;
procedure AStreamMgrRemove(var Mgr: TAudioStreamManager; Idx: Integer);
function AStreamMgrPump(var Mgr: TAudioStreamManager;
  OutBuf: PByte; OutSize: LongInt): LongInt;

{ Helper }
function AudioFmt(SR: LongWord; BPS, Ch: Word): TAudioFormat;

implementation

function AudioFmt(SR: LongWord; BPS, Ch: Word): TAudioFormat;
begin
  Result.SampleRate := SR;
  Result.BitsPerSample := BPS;
  Result.Channels := Ch;
end;

procedure AStreamInit(var S: TAudioStream; var Fmt: TAudioFormat;
  DecodeCB: TAudioDecodeCallback; DecodeData: Pointer);
begin
  FillChar(S, SizeOf(S), 0);
  S.Format := Fmt;
  S.DecodeCallback := DecodeCB;
  S.DecodeData := DecodeData;
  S.Volume := 255;
  S.State := asIdle;
  S.Active := True;
end;

procedure AStreamSetOutput(var S: TAudioStream;
  OutputCB: TAudioOutputCallback; OutputData: Pointer);
begin
  S.OutputCallback := OutputCB;
  S.OutputData := OutputData;
end;

function AStreamPump(var S: TAudioStream): Boolean;
var
  Decoded: LongInt;
  I: LongInt;
begin
  Result := False;
  if S.State <> asPlaying then Exit;
  if not Assigned(S.DecodeCallback) then Exit;

  Decoded := S.DecodeCallback(@S.ChunkBuf[0], AUS_CHUNK_SIZE, S.DecodeData);

  if Decoded <= 0 then
  begin
    if S.Loop then
    begin
      S.TotalDecoded := 0;
      Decoded := S.DecodeCallback(@S.ChunkBuf[0], AUS_CHUNK_SIZE, S.DecodeData);
      if Decoded <= 0 then begin S.State := asStopped; Exit; end;
    end
    else
    begin
      S.State := asStopped;
      Exit;
    end;
  end;

  S.ChunkReady := Decoded;
  Inc(S.TotalDecoded, Decoded);

  { Apply volume }
  { Apply volume scaling }
  if S.Volume < 255 then
  begin
    I := 0;
    while I < Decoded do
    begin
      S.ChunkBuf[I] := (S.ChunkBuf[I] * S.Volume) div 255;
      Inc(I);
    end;
  end;

  { Deliver to output }
  if Assigned(S.OutputCallback) then
    S.OutputCallback(@S.ChunkBuf[0], Decoded, S.OutputData);

  Inc(S.TotalPlayed, Decoded);
  Result := True;
end;

procedure AStreamPlay(var S: TAudioStream);
begin S.State := asPlaying; end;

procedure AStreamPause(var S: TAudioStream);
begin if S.State = asPlaying then S.State := asPaused; end;

procedure AStreamStop(var S: TAudioStream);
begin S.State := asStopped; end;

procedure AStreamReset(var S: TAudioStream);
begin
  S.State := asIdle;
  S.TotalDecoded := 0;
  S.TotalPlayed := 0;
  S.ChunkReady := 0;
end;

procedure AStreamMgrInit(var Mgr: TAudioStreamManager;
  SampleRate: LongWord; Channels: Word);
begin
  FillChar(Mgr, SizeOf(Mgr), 0);
  Mgr.MasterFormat := AudioFmt(SampleRate, 16, Channels);
  Mgr.MasterVolume := 255;
  Mgr.Active := True;
end;

function AStreamMgrAdd(var Mgr: TAudioStreamManager;
  var Fmt: TAudioFormat;
  DecodeCB: TAudioDecodeCallback; DecodeData: Pointer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to AUS_MAX_STREAMS - 1 do
    if not Mgr.Streams[I].Active then
    begin
      AStreamInit(Mgr.Streams[I], Fmt, DecodeCB, DecodeData);
      AStreamPlay(Mgr.Streams[I]);
      Result := I;
      Exit;
    end;
end;

procedure AStreamMgrRemove(var Mgr: TAudioStreamManager; Idx: Integer);
begin
  if (Idx < 0) or (Idx >= AUS_MAX_STREAMS) then Exit;
  AStreamStop(Mgr.Streams[Idx]);
  Mgr.Streams[Idx].Active := False;
end;

function AStreamMgrPump(var Mgr: TAudioStreamManager;
  OutBuf: PByte; OutSize: LongInt): LongInt;
var
  I, J: Integer;
  Mixed: LongInt;
  Val: LongInt;
begin
  FillChar(OutBuf^, OutSize, 128); { silence for unsigned 8-bit }
  Result := OutSize;

  for I := 0 to AUS_MAX_STREAMS - 1 do
  begin
    if not Mgr.Streams[I].Active then Continue;
    if Mgr.Streams[I].State <> asPlaying then Continue;

    if AStreamPump(Mgr.Streams[I]) then
    begin
      Mixed := Mgr.Streams[I].ChunkReady;
      if Mixed > OutSize then Mixed := OutSize;
      for J := 0 to Mixed - 1 do
      begin
        Val := LongInt(OutBuf[J]) + LongInt(Mgr.Streams[I].ChunkBuf[J]) - 128;
        if Val > 255 then Val := 255;
        if Val < 0 then Val := 0;
        OutBuf[J] := Val;
      end;
    end;
  end;
end;

end.

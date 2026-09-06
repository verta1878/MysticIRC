(* asyncpl.pas -- Cross-Platform Async Audio Playback
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Async playback engine: decodes audio in background, feeds to
   platform-specific output. Uses ring buffer for buffering.
   DOS: IRQ-driven via dosplay.pas
   Win32: waveOut API
   Linux/Darwin: pipe to aplay/afplay
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit asyncpl;

interface

uses audstrm, ringbuf;

type
  TAsyncPlayState = (apsIdle, apsPlaying, apsPaused, apsStopped);

  TAsyncPlayer = record
    Stream: TAudioStream;
    Ring: TRingBuffer;
    State: TAsyncPlayState;
    Format: TAudioFormat;
    FeedBuf: array[0..4095] of Byte;
  end;

{ Initialize async player }
procedure AsyncInit(var P: TAsyncPlayer; var Fmt: TAudioFormat;
  DecodeCB: TAudioDecodeCallback; DecodeData: Pointer);

{ Start playback }
procedure asyncpl(var P: TAsyncPlayer);

{ Pump: call periodically to keep ring buffer fed }
function AsyncPump(var P: TAsyncPlayer): Boolean;

{ Get next chunk for platform output }
function AsyncGetChunk(var P: TAsyncPlayer;
  OutBuf: PByte; OutSize: LongInt): LongInt;

{ Control }
procedure AsyncPause(var P: TAsyncPlayer);
procedure AsyncResume(var P: TAsyncPlayer);
procedure AsyncStop(var P: TAsyncPlayer);

{ Status }
function AsyncIsPlaying(var P: TAsyncPlayer): Boolean;
function AsyncBuffered(var P: TAsyncPlayer): LongWord;

{ Cleanup }
procedure AsyncFree(var P: TAsyncPlayer);

{ Convenience: play file async using WAV stream }
function AsyncPlayFile(var P: TAsyncPlayer;
  const FileName: ShortString; SampleRate: LongWord): Boolean;

implementation

procedure RingOutputCB(Buffer: PByte; BufSize: LongInt; UserData: Pointer);
var
  P: ^TAsyncPlayer;
begin
  P := UserData;
  RingWrite(P^.Ring, Buffer, BufSize);
end;

procedure AsyncInit(var P: TAsyncPlayer; var Fmt: TAudioFormat;
  DecodeCB: TAudioDecodeCallback; DecodeData: Pointer);
begin
  FillChar(P, SizeOf(P), 0);
  P.Format := Fmt;
  AStreamInit(P.Stream, Fmt, DecodeCB, DecodeData);
  AStreamSetOutput(P.Stream, @RingOutputCB, @P);
  RingInit(P.Ring, 32768);
  P.State := apsIdle;
end;

procedure asyncpl(var P: TAsyncPlayer);
begin
  P.State := apsPlaying;
  AStreamPlay(P.Stream);
end;

function AsyncPump(var P: TAsyncPlayer): Boolean;
begin
  Result := False;
  if P.State <> apsPlaying then Exit;
  if RingFreeSpace(P.Ring) < 4096 then Exit; { buffer full enough }
  Result := AStreamPump(P.Stream);
  if not Result then
    P.State := apsStopped;
end;

function AsyncGetChunk(var P: TAsyncPlayer;
  OutBuf: PByte; OutSize: LongInt): LongInt;
begin
  Result := 0;
  if P.State = apsPaused then
  begin
    { Output silence }
    FillChar(OutBuf^, OutSize, 128);
    Result := OutSize;
    Exit;
  end;
  if RingAvailable(P.Ring) > 0 then
    Result := RingRead(P.Ring, OutBuf, OutSize);
end;

procedure AsyncPause(var P: TAsyncPlayer);
begin
  if P.State = apsPlaying then P.State := apsPaused;
end;

procedure AsyncResume(var P: TAsyncPlayer);
begin
  if P.State = apsPaused then P.State := apsPlaying;
end;

procedure AsyncStop(var P: TAsyncPlayer);
begin
  P.State := apsStopped;
  AStreamStop(P.Stream);
end;

function AsyncIsPlaying(var P: TAsyncPlayer): Boolean;
begin
  Result := P.State = apsPlaying;
end;

function AsyncBuffered(var P: TAsyncPlayer): LongWord;
begin
  Result := RingAvailable(P.Ring);
end;

procedure AsyncFree(var P: TAsyncPlayer);
begin
  AsyncStop(P);
  RingFree(P.Ring);
end;

function AsyncPlayFile(var P: TAsyncPlayer;
  const FileName: ShortString; SampleRate: LongWord): Boolean;
begin
  { Would use WAVStreamOpen + WAVStreamDecode here }
  Result := False;
end;

end.

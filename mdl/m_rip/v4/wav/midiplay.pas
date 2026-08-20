(* midiplay.pas -- MIDI File Player
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Bridges mididec.pas (SMF parser) and midsynth.pas (FM synth).
   Reads a .mid file, processes events with timing, renders to PCM.
*)
{$MODE OBJFPC}
{$H+}
{$R-}
{$Q-}

unit midiplay;

interface

uses mididec, midsynth;

type
  TMIDIPlayer = record
    MIDI: TMIDIFile;
    Synth: TMIDISynth;
    SampleRate: LongWord;
    Tempo: LongWord;          { microseconds per quarter note }
    TicksPerQN: Word;         { from MIDI header }
    SamplesPerTick: LongWord; { derived from tempo + sample rate }
    CurrentTick: LongWord;
    TrackPos: array[0..15] of Integer; { current event index per track }
    TrackTick: array[0..15] of LongWord; { accumulated tick per track }
    Playing: Boolean;
    Loaded: Boolean;
  end;

{ Load MIDI file and initialize player }
function MIDIPlayLoad(var P: TMIDIPlayer;
  const FileName: ShortString; SampleRate: LongWord): Boolean;

{ Render entire MIDI to stereo 16-bit PCM.
  Returns number of stereo sample frames. }
function MIDIPlayRender(var P: TMIDIPlayer;
  out OutPCM: PSmallInt): LongInt;

{ Render one tick's worth of audio (for streaming) }
function MIDIPlayRenderTick(var P: TMIDIPlayer;
  OutBuf: PSmallInt; BufSamples: LongInt): LongInt;

{ Reset to beginning }
procedure MIDIPlayRewind(var P: TMIDIPlayer);

{ Is playback complete? }
function MIDIPlayDone(var P: TMIDIPlayer): Boolean;

{ Get duration in milliseconds }
function MIDIPlayDuration(var P: TMIDIPlayer): LongWord;

procedure MIDIPlayFree(var P: TMIDIPlayer);

implementation

procedure UpdateTempo(var P: TMIDIPlayer);
begin
  if P.TicksPerQN > 0 then
    P.SamplesPerTick := (P.SampleRate * (P.Tempo div 1000)) div
                        (P.TicksPerQN * 1000)
  else
    P.SamplesPerTick := P.SampleRate div 480;
  if P.SamplesPerTick = 0 then P.SamplesPerTick := 1;
end;

function MIDIPlayLoad(var P: TMIDIPlayer;
  const FileName: ShortString; SampleRate: LongWord): Boolean;
var
  I: Integer;
begin
  Result := False;
  FillChar(P, SizeOf(P), 0);

  if not MIDILoadFile(FileName, P.MIDI) then Exit;

  P.SampleRate := SampleRate;
  P.Tempo := 500000;  { default: 120 BPM }
  P.TicksPerQN := P.MIDI.TicksPerQN;
  if P.TicksPerQN = 0 then P.TicksPerQN := 480;

  MIDISynthInit(P.Synth, SampleRate);
  UpdateTempo(P);

  for I := 0 to 15 do
  begin
    P.TrackPos[I] := 0;
    P.TrackTick[I] := 0;
  end;

  P.Playing := True;
  P.Loaded := True;
  Result := True;
end;

procedure ProcessEventsAtTick(var P: TMIDIPlayer; Tick: LongWord);
var
  T, I: Integer;
  Ev: ^TMIDIEvent;
begin
  for T := 0 to P.MIDI.TrackCount - 1 do
  begin
    while P.TrackPos[T] < P.MIDI.Tracks[T].EventCount do
    begin
      Ev := @P.MIDI.Tracks[T].Events[P.TrackPos[T]];

      { Accumulate delta time }
      if P.TrackTick[T] + LongWord(Ev^.DeltaTime) > Tick then
        Break;

      Inc(P.TrackTick[T], Ev^.DeltaTime);

      { Process MIDI event }
      case Ev^.Status and $F0 of
        $90: { Note On }
          if Ev^.Data2 > 0 then
            MIDISynthNoteOn(P.Synth, Ev^.Status and $0F, Ev^.Data1, Ev^.Data2)
          else
            MIDISynthNoteOff(P.Synth, Ev^.Status and $0F, Ev^.Data1);
        $80: { Note Off }
          MIDISynthNoteOff(P.Synth, Ev^.Status and $0F, Ev^.Data1);
        $B0: { Control Change }
          MIDISynthControlChange(P.Synth, Ev^.Status and $0F, Ev^.Data1, Ev^.Data2);
        $C0: { Program Change }
          MIDISynthProgramChange(P.Synth, Ev^.Status and $0F, Ev^.Data1);
        $E0: { Pitch Bend }
          MIDISynthPitchBend(P.Synth, Ev^.Status and $0F,
            SmallInt((Word(Ev^.Data2) shl 7) or Ev^.Data1) - 8192);
        $FF: { Meta event }
          if Ev^.Data1 = $51 then { tempo change }
          begin
            { Tempo stored in Data2 as packed 3-byte value }
            P.Tempo := LongWord(Ev^.Data2) * 256; { simplified }
            UpdateTempo(P);
          end;
      end;

      Inc(P.TrackPos[T]);
    end;
  end;
end;

function MIDIPlayRenderTick(var P: TMIDIPlayer;
  OutBuf: PSmallInt; BufSamples: LongInt): LongInt;
var
  SamplesToRender: LongInt;
begin
  Result := 0;
  if not P.Playing then Exit;

  { Process events at current tick }
  ProcessEventsAtTick(P, P.CurrentTick);

  { Render audio for one tick }
  SamplesToRender := P.SamplesPerTick;
  if SamplesToRender > BufSamples then SamplesToRender := BufSamples;

  MIDISynthRender(P.Synth, OutBuf, SamplesToRender);

  Inc(P.CurrentTick);
  Result := SamplesToRender;
end;

function MIDIPlayDone(var P: TMIDIPlayer): Boolean;
var
  T: Integer;
  AllDone: Boolean;
begin
  AllDone := True;
  for T := 0 to P.MIDI.TrackCount - 1 do
    if P.TrackPos[T] < P.MIDI.Tracks[T].EventCount then
      AllDone := False;
  Result := AllDone;
end;

function MIDIPlayRender(var P: TMIDIPlayer;
  out OutPCM: PSmallInt): LongInt;
var
  Duration: LongWord;
  TotalSamples: LongInt;
  Pos: LongInt;
  Rendered: LongInt;
  TickBuf: array[0..2047] of SmallInt; { stereo, 1024 frames }
begin
  Result := 0;
  OutPCM := nil;
  if not P.Loaded then Exit;

  Duration := MIDIPlayDuration(P);
  TotalSamples := (LongInt(P.SampleRate) * LongInt(Duration)) div 1000;
  if TotalSamples <= 0 then TotalSamples := P.SampleRate * 60; { 60 sec fallback }

  GetMem(OutPCM, TotalSamples * 4); { stereo 16-bit }
  FillChar(OutPCM^, TotalSamples * 4, 0);

  MIDIPlayRewind(P);
  Pos := 0;

  while not MIDIPlayDone(P) do
  begin
    Rendered := MIDIPlayRenderTick(P, @TickBuf[0], 1024);
    if Rendered <= 0 then Break;
    if Pos + Rendered > TotalSamples then Rendered := TotalSamples - Pos;
    if Rendered <= 0 then Break;
    Move(TickBuf[0], OutPCM[Pos * 2], Rendered * 4);
    Inc(Pos, Rendered);
  end;

  Result := Pos;
end;

function MIDIPlayDuration(var P: TMIDIPlayer): LongWord;
var
  T, I: Integer;
  MaxTick: LongWord;
  Tick: LongWord;
begin
  MaxTick := 0;
  for T := 0 to P.MIDI.TrackCount - 1 do
  begin
    Tick := 0;
    for I := 0 to P.MIDI.Tracks[T].EventCount - 1 do
      Inc(Tick, P.MIDI.Tracks[T].Events[I].DeltaTime);
    if Tick > MaxTick then MaxTick := Tick;
  end;

  if P.TicksPerQN > 0 then
    Result := (MaxTick * (P.Tempo div 1000)) div P.TicksPerQN
  else
    Result := 60000; { fallback 60 sec }
end;

procedure MIDIPlayRewind(var P: TMIDIPlayer);
var
  I: Integer;
begin
  P.CurrentTick := 0;
  P.Tempo := 500000;
  UpdateTempo(P);
  for I := 0 to 15 do
  begin
    P.TrackPos[I] := 0;
    P.TrackTick[I] := 0;
  end;
  MIDISynthPanic(P.Synth);
  P.Playing := True;
end;

procedure MIDIPlayFree(var P: TMIDIPlayer);
begin
  MIDIFree(P.MIDI);
  P.Loaded := False;
  P.Playing := False;
end;

end.

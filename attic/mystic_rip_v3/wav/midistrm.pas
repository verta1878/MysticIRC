(* midistrm.pas -- MIDI Streaming Playback
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Connects midiplay.pas to audstrm.pas for real-time MIDI
   streaming. Renders tick-by-tick, feeds chunks to audio pipeline.
*)
{$MODE OBJFPC}{$H+}
{$R-}
{$Q-}

unit midistrm;

interface

uses audstrm, midiplay;

type
  TMIDIStreamState = record
    Player: TMIDIPlayer;
    SampleRate: LongWord;
    Done: Boolean;
  end;

function MIDIStreamOpen(var S: TMIDIStreamState;
  const FileName: ShortString; SampleRate: LongWord): Boolean;
function MIDIStreamDecode(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;
procedure MIDIStreamClose(var S: TMIDIStreamState);
function MIDIStreamFormat(var S: TMIDIStreamState): TAudioFormat;

implementation

function MIDIStreamOpen(var S: TMIDIStreamState;
  const FileName: ShortString; SampleRate: LongWord): Boolean;
begin
  Result := False;
  FillChar(S, SizeOf(S), 0);
  S.SampleRate := SampleRate;
  if not MIDIPlayLoad(S.Player, FileName, SampleRate) then Exit;
  S.Done := False;
  Result := True;
end;

function MIDIStreamDecode(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;
var
  S: ^TMIDIStreamState;
  OutBuf: PSmallInt;
  Samples, Rendered, TotalRendered: LongInt;
begin
  S := UserData;
  Result := 0;
  if S^.Done then Exit;

  OutBuf := PSmallInt(Buffer);
  Samples := BufSize div 4; { stereo 16-bit = 4 bytes per frame }
  TotalRendered := 0;

  while TotalRendered < Samples do
  begin
    if MIDIPlayDone(S^.Player) then
    begin
      S^.Done := True;
      Break;
    end;
    Rendered := MIDIPlayRenderTick(S^.Player,
      @OutBuf[TotalRendered * 2], Samples - TotalRendered);
    if Rendered <= 0 then Break;
    Inc(TotalRendered, Rendered);
  end;

  Result := TotalRendered * 4;
end;

procedure MIDIStreamClose(var S: TMIDIStreamState);
begin
  MIDIPlayFree(S.Player);
  S.Done := True;
end;

function MIDIStreamFormat(var S: TMIDIStreamState): TAudioFormat;
begin
  Result := AudioFmt(S.SampleRate, 16, 2);
end;

end.

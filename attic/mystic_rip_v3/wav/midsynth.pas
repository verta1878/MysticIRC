(* midsynth.pas -- MIDI Software Synthesizer
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   FM synthesis engine (2-operator, OPL2/AdLib style) with wavetable
   sample playback. 16 MIDI channels, renders MIDI events to PCM.
   Integrates with mididec.pas for file playback.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit midsynth;

interface

const
  MIDI_CHANNELS = 16;
  MIDI_MAX_VOICES = 32;
  MIDI_MAX_PATCHES = 128;

type
  { FM operator }
  TFMOperator = record
    Phase: LongWord;       { 16.16 fixed phase accumulator }
    FreqInc: LongWord;     { 16.16 frequency increment }
    Level: Word;           { output level 0-65535 }
    Attack: Word;          { attack rate }
    Decay: Word;           { decay rate }
    Sustain: Word;         { sustain level }
    Release: Word;         { release rate }
    EnvLevel: Word;        { current envelope level }
    EnvState: Byte;        { 0=off, 1=attack, 2=decay, 3=sustain, 4=release }
    Waveform: Byte;        { 0=sine, 1=half-sine, 2=abs-sine, 3=quarter, 4=square, 5=saw }
    FeedBack: Byte;        { self-modulation amount 0-7 }
    PrevOut: SmallInt;     { previous output for feedback }
  end;

  { Voice (one sounding note) }
  TMIDIVoice = record
    Active: Boolean;
    Channel: Byte;
    Note: Byte;
    Velocity: Byte;
    Op1, Op2: TFMOperator; { modulator + carrier }
    Age: LongWord;         { ticks since note-on }
  end;

  { Channel state }
  TMIDIChannel = record
    Program_: Byte;        { current instrument 0-127 }
    Volume: Byte;          { channel volume 0-127 }
    Pan: Byte;             { pan 0-127 (64=center) }
    PitchBend: SmallInt;   { -8192..8191 }
    Expression: Byte;
    Sustain: Boolean;
  end;

  { Patch definition (instrument) }
  TMIDIPatch = record
    Name: ShortString;
    { Modulator (Op1) }
    ModAttack, ModDecay, ModSustain, ModRelease: Word;
    ModLevel: Word;
    ModMultiple: Byte;     { frequency multiplier }
    ModWaveform: Byte;
    ModFeedback: Byte;
    { Carrier (Op2) }
    CarAttack, CarDecay, CarSustain, CarRelease: Word;
    CarLevel: Word;
    CarMultiple: Byte;
    CarWaveform: Byte;
    Algorithm: Byte;       { 0=FM (mod->car), 1=additive (mod+car) }
  end;

  TMIDISynth = record
    Voices: array[0..MIDI_MAX_VOICES - 1] of TMIDIVoice;
    Channels: array[0..MIDI_CHANNELS - 1] of TMIDIChannel;
    Patches: array[0..MIDI_MAX_PATCHES - 1] of TMIDIPatch;
    SampleRate: LongWord;
    MasterVolume: Byte;
    NumActiveVoices: Integer;
    TickCount: LongWord;
  end;

{ Initialize synth }
procedure MIDISynthInit(var S: TMIDISynth; SampleRate: LongWord);

{ Load default GM-like patches (piano, strings, brass, etc.) }
procedure MIDISynthLoadGM(var S: TMIDISynth);

{ Process MIDI events }
procedure MIDISynthNoteOn(var S: TMIDISynth; Channel, Note, Velocity: Byte);
procedure MIDISynthNoteOff(var S: TMIDISynth; Channel, Note: Byte);
procedure MIDISynthControlChange(var S: TMIDISynth; Channel, Controller, Value: Byte);
procedure MIDISynthProgramChange(var S: TMIDISynth; Channel, Program_: Byte);
procedure MIDISynthPitchBend(var S: TMIDISynth; Channel: Byte; Bend: SmallInt);

{ Render PCM audio }
procedure MIDISynthRender(var S: TMIDISynth;
  OutBuf: PSmallInt; NumSamples: LongInt);

{ All notes off }
procedure MIDISynthPanic(var S: TMIDISynth);

{ Note number to frequency (16.16 fixed) }
function MIDINoteToFreq(Note: Byte): LongWord;

implementation

const
  { Sine table: 256 entries, amplitude 0-32767 }
  SineTab: array[0..255] of SmallInt = (
    0, 804, 1608, 2410, 3212, 4011, 4808, 5602,
    6393, 7179, 7962, 8739, 9512, 10278, 11039, 11793,
    12539, 13279, 14010, 14732, 15446, 16151, 16846, 17530,
    18204, 18868, 19519, 20159, 20787, 21403, 22005, 22594,
    23170, 23731, 24279, 24811, 25329, 25832, 26319, 26790,
    27245, 27683, 28105, 28510, 28898, 29268, 29621, 29956,
    30273, 30571, 30852, 31113, 31356, 31580, 31785, 31971,
    32137, 32285, 32412, 32521, 32609, 32678, 32728, 32757,
    32767, 32757, 32728, 32678, 32609, 32521, 32412, 32285,
    32137, 31971, 31785, 31580, 31356, 31113, 30852, 30571,
    30273, 29956, 29621, 29268, 28898, 28510, 28105, 27683,
    27245, 26790, 26319, 25832, 25329, 24811, 24279, 23731,
    23170, 22594, 22005, 21403, 20787, 20159, 19519, 18868,
    18204, 17530, 16846, 16151, 15446, 14732, 14010, 13279,
    12539, 11793, 11039, 10278, 9512, 8739, 7962, 7179,
    6393, 5602, 4808, 4011, 3212, 2410, 1608, 804,
    0, -804, -1608, -2410, -3212, -4011, -4808, -5602,
    -6393, -7179, -7962, -8739, -9512, -10278, -11039, -11793,
    -12539, -13279, -14010, -14732, -15446, -16151, -16846, -17530,
    -18204, -18868, -19519, -20159, -20787, -21403, -22005, -22594,
    -23170, -23731, -24279, -24811, -25329, -25832, -26319, -26790,
    -27245, -27683, -28105, -28510, -28898, -29268, -29621, -29956,
    -30273, -30571, -30852, -31113, -31356, -31580, -31785, -31971,
    -32137, -32285, -32412, -32521, -32609, -32678, -32728, -32757,
    -32767, -32757, -32728, -32678, -32609, -32521, -32412, -32285,
    -32137, -31971, -31785, -31580, -31356, -31113, -30852, -30571,
    -30273, -29956, -29621, -29268, -28898, -28510, -28105, -27683,
    -27245, -26790, -26319, -25832, -25329, -24811, -24279, -23731,
    -23170, -22594, -22005, -21403, -20787, -20159, -19519, -18868,
    -18204, -17530, -16846, -16151, -15446, -14732, -14010, -13279,
    -12539, -11793, -11039, -10278, -9512, -8739, -7962, -7179,
    -6393, -5602, -4808, -4011, -3212, -2410, -1608, -804
  );

  { Note frequencies in 16.16 fixed point (MIDI note 0-127) }
  { Base: A4 (note 69) = 440 Hz }
  NoteFreqBase: array[0..11] of LongWord = (
    17164, 18188, 19269, 20411, 21618, 22894,  { C..F# in octave 0, *65536 }
    24244, 25674, 27189, 28797, 30503, 32314   { G..B in octave 0 }
  );

function MIDINoteToFreq(Note: Byte): LongWord;
var
  Oct, Semi: Integer;
begin
  if Note > 127 then Note := 127;
  Oct := Note div 12;
  Semi := Note mod 12;
  Result := NoteFreqBase[Semi];
  { Shift up by octave }
  if Oct > 0 then
    Result := Result shl Oct;
  { Result is Hz * 65536 }
end;

function Oscillator(var Op: TFMOperator; PhaseModulation: LongInt): SmallInt;
var
  Phase256: Integer;
  Sample: SmallInt;
begin
  Phase256 := ((Op.Phase + LongWord(PhaseModulation)) shr 8) and 255;

  case Op.Waveform of
    0: Sample := SineTab[Phase256];
    1: if Phase256 < 128 then Sample := SineTab[Phase256] else Sample := 0;
    2: Sample := Abs(SineTab[Phase256]);
    3: if Phase256 < 64 then Sample := SineTab[Phase256]
       else if Phase256 < 128 then Sample := 0
       else if Phase256 < 192 then Sample := SineTab[Phase256]
       else Sample := 0;
    4: if Phase256 < 128 then Sample := 32767 else Sample := -32767;
    5: Sample := SmallInt(Phase256 * 256 - 32768);
  else
    Sample := SineTab[Phase256];
  end;

  { Apply envelope }
  Result := SmallInt((LongInt(Sample) * Op.EnvLevel) shr 16);
end;

procedure EnvelopeTick(var Op: TFMOperator);
begin
  case Op.EnvState of
    1: { Attack }
    begin
      if Op.EnvLevel < 65535 - Op.Attack then
        Inc(Op.EnvLevel, Op.Attack)
      else
      begin
        Op.EnvLevel := 65535;
        Op.EnvState := 2;
      end;
    end;
    2: { Decay }
    begin
      if Op.EnvLevel > Op.Sustain + Op.Decay then
        Dec(Op.EnvLevel, Op.Decay)
      else
      begin
        Op.EnvLevel := Op.Sustain;
        Op.EnvState := 3;
      end;
    end;
    3: { Sustain — hold }
      ;
    4: { Release }
    begin
      if Op.EnvLevel > Op.Release then
        Dec(Op.EnvLevel, Op.Release)
      else
      begin
        Op.EnvLevel := 0;
        Op.EnvState := 0;
      end;
    end;
  end;
end;

procedure SetupOperator(var Op: TFMOperator; var Patch: TMIDIPatch;
  IsMod: Boolean; NoteFreq, SampleRate: LongWord);
begin
  if IsMod then
  begin
    Op.Attack := Patch.ModAttack;
    Op.Decay := Patch.ModDecay;
    Op.Sustain := Patch.ModSustain;
    Op.Release := Patch.ModRelease;
    Op.Level := Patch.ModLevel;
    Op.Waveform := Patch.ModWaveform;
    Op.FeedBack := Patch.ModFeedback;
    Op.FreqInc := (NoteFreq * LongWord(Patch.ModMultiple)) div SampleRate;
  end
  else
  begin
    Op.Attack := Patch.CarAttack;
    Op.Decay := Patch.CarDecay;
    Op.Sustain := Patch.CarSustain;
    Op.Release := Patch.CarRelease;
    Op.Level := Patch.CarLevel;
    Op.Waveform := Patch.CarWaveform;
    Op.FeedBack := 0;
    Op.FreqInc := (NoteFreq * LongWord(Patch.CarMultiple)) div SampleRate;
  end;
  Op.Phase := 0;
  Op.EnvLevel := 0;
  Op.EnvState := 1; { attack }
  Op.PrevOut := 0;
end;

procedure MIDISynthInit(var S: TMIDISynth; SampleRate: LongWord);
var
  I: Integer;
begin
  FillChar(S, SizeOf(S), 0);
  S.SampleRate := SampleRate;
  S.MasterVolume := 127;
  for I := 0 to MIDI_CHANNELS - 1 do
  begin
    S.Channels[I].Volume := 100;
    S.Channels[I].Pan := 64;
    S.Channels[I].Expression := 127;
  end;
  MIDISynthLoadGM(S);
end;

procedure MIDISynthLoadGM(var S: TMIDISynth);
var
  I: Integer;
  P: ^TMIDIPatch;
begin
  { Default patch: simple organ-like FM }
  for I := 0 to MIDI_MAX_PATCHES - 1 do
  begin
    P := @S.Patches[I];
    P^.ModAttack := 4000; P^.ModDecay := 500;
    P^.ModSustain := 40000; P^.ModRelease := 1000;
    P^.ModLevel := 32768; P^.ModMultiple := 1;
    P^.ModWaveform := 0; P^.ModFeedback := 0;
    P^.CarAttack := 4000; P^.CarDecay := 500;
    P^.CarSustain := 45000; P^.CarRelease := 1000;
    P^.CarLevel := 65535; P^.CarMultiple := 1;
    P^.CarWaveform := 0; P^.Algorithm := 0;
  end;

  { Piano (0-7): fast attack, medium decay }
  for I := 0 to 7 do
  begin
    S.Patches[I].ModAttack := 8000; S.Patches[I].CarAttack := 8000;
    S.Patches[I].ModDecay := 2000; S.Patches[I].CarDecay := 2000;
    S.Patches[I].ModSustain := 20000; S.Patches[I].CarSustain := 25000;
    S.Patches[I].ModMultiple := 2; S.Patches[I].ModLevel := 40000;
  end;

  { Organ (16-23): sustained, no decay }
  for I := 16 to 23 do
  begin
    S.Patches[I].ModDecay := 100; S.Patches[I].CarDecay := 100;
    S.Patches[I].ModSustain := 60000; S.Patches[I].CarSustain := 60000;
    S.Patches[I].Algorithm := 1; { additive }
    S.Patches[I].ModMultiple := 2;
  end;

  { Strings (48-55): slow attack, long sustain }
  for I := 48 to 55 do
  begin
    S.Patches[I].ModAttack := 1000; S.Patches[I].CarAttack := 1000;
    S.Patches[I].ModSustain := 55000; S.Patches[I].CarSustain := 55000;
    S.Patches[I].ModRelease := 500; S.Patches[I].CarRelease := 500;
    S.Patches[I].ModMultiple := 3;
  end;

  { Brass (56-63): medium attack, bright }
  for I := 56 to 63 do
  begin
    S.Patches[I].ModAttack := 3000; S.Patches[I].CarAttack := 3000;
    S.Patches[I].ModLevel := 50000; S.Patches[I].ModMultiple := 3;
    S.Patches[I].ModFeedback := 2;
  end;

  { Synth lead (80-87): square wave }
  for I := 80 to 87 do
  begin
    S.Patches[I].CarWaveform := 4; { square }
    S.Patches[I].ModWaveform := 4;
    S.Patches[I].ModMultiple := 2;
  end;
end;

function FindFreeVoice(var S: TMIDISynth): Integer;
var
  I, Oldest: Integer;
  MaxAge: LongWord;
begin
  { Find inactive voice }
  for I := 0 to MIDI_MAX_VOICES - 1 do
    if not S.Voices[I].Active then begin Result := I; Exit; end;

  { Steal oldest voice }
  Oldest := 0; MaxAge := 0;
  for I := 0 to MIDI_MAX_VOICES - 1 do
    if S.Voices[I].Age > MaxAge then
    begin MaxAge := S.Voices[I].Age; Oldest := I; end;
  Result := Oldest;
end;

procedure MIDISynthNoteOn(var S: TMIDISynth; Channel, Note, Velocity: Byte);
var
  VI: Integer;
  V: ^TMIDIVoice;
  Freq: LongWord;
  Prog: Byte;
begin
  if Velocity = 0 then begin MIDISynthNoteOff(S, Channel, Note); Exit; end;

  VI := FindFreeVoice(S);
  V := @S.Voices[VI];
  V^.Active := True;
  V^.Channel := Channel;
  V^.Note := Note;
  V^.Velocity := Velocity;
  V^.Age := 0;

  Freq := MIDINoteToFreq(Note);
  Prog := S.Channels[Channel].Program_;

  SetupOperator(V^.Op1, S.Patches[Prog], True, Freq, S.SampleRate);
  SetupOperator(V^.Op2, S.Patches[Prog], False, Freq, S.SampleRate);
end;

procedure MIDISynthNoteOff(var S: TMIDISynth; Channel, Note: Byte);
var
  I: Integer;
begin
  for I := 0 to MIDI_MAX_VOICES - 1 do
    if S.Voices[I].Active and (S.Voices[I].Channel = Channel) and
       (S.Voices[I].Note = Note) then
    begin
      S.Voices[I].Op1.EnvState := 4; { release }
      S.Voices[I].Op2.EnvState := 4;
    end;
end;

procedure MIDISynthControlChange(var S: TMIDISynth; Channel, Controller, Value: Byte);
begin
  case Controller of
    7: S.Channels[Channel].Volume := Value;
    10: S.Channels[Channel].Pan := Value;
    11: S.Channels[Channel].Expression := Value;
    64: S.Channels[Channel].Sustain := Value >= 64;
    123: MIDISynthPanic(S); { all notes off }
  end;
end;

procedure MIDISynthProgramChange(var S: TMIDISynth; Channel, Program_: Byte);
begin
  S.Channels[Channel].Program_ := Program_;
end;

procedure MIDISynthPitchBend(var S: TMIDISynth; Channel: Byte; Bend: SmallInt);
begin
  S.Channels[Channel].PitchBend := Bend;
end;

procedure MIDISynthRender(var S: TMIDISynth;
  OutBuf: PSmallInt; NumSamples: LongInt);
var
  I, VI: Integer;
  V: ^TMIDIVoice;
  Ch: ^TMIDIChannel;
  ModOut, CarOut: SmallInt;
  FBMod: LongInt;
  Left, Right: LongInt;
  Pan, Vol: Integer;
  Algo: Byte;
begin
  FillChar(OutBuf^, NumSamples * 2 * SizeOf(SmallInt), 0);

  for I := 0 to NumSamples - 1 do
  begin
    Left := 0; Right := 0;

    for VI := 0 to MIDI_MAX_VOICES - 1 do
    begin
      V := @S.Voices[VI];
      if not V^.Active then Continue;
      Ch := @S.Channels[V^.Channel];

      { Modulator with feedback }
      FBMod := 0;
      if V^.Op1.FeedBack > 0 then
        FBMod := LongInt(V^.Op1.PrevOut) shl (V^.Op1.FeedBack - 1);
      ModOut := Oscillator(V^.Op1, FBMod);
      V^.Op1.PrevOut := ModOut;

      { Carrier }
      Algo := S.Patches[Ch^.Program_].Algorithm;
      if Algo = 0 then
        CarOut := Oscillator(V^.Op2, LongInt(ModOut) shl 4)
      else
        CarOut := SmallInt((LongInt(ModOut) + LongInt(Oscillator(V^.Op2, 0))) div 2);

      { Apply velocity + channel volume + expression }
      Vol := (LongInt(CarOut) * V^.Velocity * Ch^.Volume * Ch^.Expression) div (127 * 127 * 127);

      { Panning }
      Pan := Ch^.Pan;
      Inc(Left, (Vol * (127 - Pan)) div 127);
      Inc(Right, (Vol * Pan) div 127);

      { Advance oscillators }
      Inc(V^.Op1.Phase, V^.Op1.FreqInc);
      Inc(V^.Op2.Phase, V^.Op2.FreqInc);

      { Envelope tick (every 64 samples for performance) }
      if (I and 63) = 0 then
      begin
        EnvelopeTick(V^.Op1);
        EnvelopeTick(V^.Op2);
        Inc(V^.Age);
      end;

      { Kill dead voices }
      if (V^.Op1.EnvState = 0) and (V^.Op2.EnvState = 0) then
        V^.Active := False;
    end;

    { Master volume + clamp }
    Left := (Left * S.MasterVolume) div 127;
    Right := (Right * S.MasterVolume) div 127;
    if Left > 32767 then Left := 32767 else if Left < -32768 then Left := -32768;
    if Right > 32767 then Right := 32767 else if Right < -32768 then Right := -32768;

    OutBuf[I * 2] := SmallInt(Left);
    OutBuf[I * 2 + 1] := SmallInt(Right);
  end;

  Inc(S.TickCount, NumSamples);
end;

procedure MIDISynthPanic(var S: TMIDISynth);
var
  I: Integer;
begin
  for I := 0 to MIDI_MAX_VOICES - 1 do
    S.Voices[I].Active := False;
end;

end.

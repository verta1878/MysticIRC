(* ansimusc.pas -- ANSI Music / BBS Music Decoder
   Copyright (C) 2026 fpc264irc contributors.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   Decodes ANSI music sequences (ESC[M...) used in BBS door games,
   login screens, and ANSI art files. Converts to a note event list
   that can be played through PC speaker (DOS) or synthesized to PCM.

   Supports:
     BANSI.SYS style:  ESC[N<notes>  (N = 14 for ANSI music)
     ANSI music:       MF / MB (foreground/background)
     MML commands:     T<tempo> L<length> O<octave> V<volume>
                       Notes: C D E F G A B with # + . modifiers
                       N<note> P/R<rest> < > (octave shift)

   Usage:
     var Events: PAMEvent; Count: Integer;
     begin
       if AMParseMML('T120 O4 L4 C D E F G A B > C', Events, Count) then
       begin
         // Events[0..Count-1] = note/rest events with freq + duration
         AMPlayEvents(Events, Count);  // PC speaker on DOS
         FreeMem(Events);
       end;
     end;

   Compiler: FPC 2.6.4+
   License: GPLv3
*)

{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit ansimusc;

interface

type
  TAMEventType = (amNote, amRest);

  TAMEvent = record
    EventType: TAMEventType;
    Frequency: Word;       { Hz, 0 for rest }
    DurationMS: Word;      { milliseconds }
    Volume: Byte;          { 0-15 }
  end;
  TAMEventArray = array[0..16383] of TAMEvent;
  PAMEvent = ^TAMEventArray;

  TAMState = record
    Tempo: Word;           { BPM, default 120 }
    Octave: Byte;          { 0-7, default 4 }
    DefaultLength: Byte;   { 1-64, default 4 (quarter note) }
    Volume: Byte;          { 0-15, default 12 }
    Style: Byte;           { 0=normal, 1=staccato, 2=legato }
    Foreground: Boolean;   { MF=true (blocking), MB=false (background) }
  end;

{ Parse MML (Music Macro Language) string into note events }
function AMParseMML(const MML: ShortString;
  out Events: PAMEvent; out Count: Integer): Boolean;

{ Parse ANSI escape sequence containing music }
function AMParseANSI(Src: PByte; SrcLen: LongInt;
  out Events: PAMEvent; out Count: Integer): Boolean;

{ Extract MML strings from an ANSI file (scans for ESC[M sequences) }
function AMExtractFromANSI(Src: PByte; SrcLen: LongInt;
  out MMLStr: ShortString): Boolean;

{ Synthesize events to 8-bit unsigned PCM buffer (square wave) }
function AMSynthPCM(Events: PAMEvent; Count: Integer;
  SampleRate: LongWord;
  out PCMData: PByte; out PCMSize: LongWord): Boolean;

{ Play events through PC speaker (DOS only, stub on other platforms) }
procedure AMPlayEvents(Events: PAMEvent; Count: Integer);

{ Get frequency for a note number (0=C0, 12=C1, ..., 84=C7) }
function AMNoteFreq(Note: Integer): Word;

{ Initialize default state }
procedure AMInitState(var State: TAMState);

implementation

const
  { Base frequencies for octave 0 (C0 to B0) }
  BaseFreq: array[0..11] of Word = (
    16, 17, 18, 19, 21, 22, 23, 25, 26, 28, 29, 31
  );

  { Note name to semitone offset }
  NoteOffset: array[0..6] of Byte = (
    9,  { A }
    11, { B }
    0,  { C }
    2,  { D }
    4,  { E }
    5,  { F }
    7   { G }
  );

function AMNoteFreq(Note: Integer): Word;
var
  Octave, Semi: Integer;
begin
  if Note < 0 then Note := 0;
  if Note > 95 then Note := 95;
  Octave := Note div 12;
  Semi := Note mod 12;
  Result := BaseFreq[Semi];
  while Octave > 0 do
  begin
    Result := Result * 2;
    Dec(Octave);
  end;
end;

procedure AMInitState(var State: TAMState);
begin
  State.Tempo := 120;
  State.Octave := 4;
  State.DefaultLength := 4;
  State.Volume := 12;
  State.Style := 0;
  State.Foreground := True;
end;

function CalcDurationMS(Tempo: Word; NoteLen: Integer; Dotted: Boolean): Word;
var
  MS: LongWord;
begin
  if NoteLen < 1 then NoteLen := 4;
  if Tempo < 1 then Tempo := 120;
  { Whole note = 4 beats, duration = 4 * 60000 / tempo }
  MS := (4 * 60000) div (LongWord(Tempo) * LongWord(NoteLen));
  if Dotted then
    MS := MS + MS div 2;
  if MS > 65535 then MS := 65535;
  Result := MS;
end;

function AMParseMML(const MML: ShortString;
  out Events: PAMEvent; out Count: Integer): Boolean;
var
  State: TAMState;
  Pos: Integer;
  Cap: Integer;
  NoteVal: Integer;
  NoteLen: Integer;
  Dotted: Boolean;
  Sharp, Flat: Boolean;
  NumVal: Integer;
  Ch: Char;

  procedure AddEvent(ET: TAMEventType; Freq: Word; Dur: Word);
  begin
    if Count >= Cap then
    begin
      Cap := Cap * 2;
      ReallocMem(Events, Cap * SizeOf(TAMEvent));
    end;
    Events[Count].EventType := ET;
    Events[Count].Frequency := Freq;
    Events[Count].DurationMS := Dur;
    Events[Count].Volume := State.Volume;
    Inc(Count);
  end;

  function PeekChar: Char;
  begin
    if Pos <= Length(MML) then Result := UpCase(MML[Pos])
    else Result := #0;
  end;

  function ReadNum: Integer;
  begin
    Result := 0;
    while (Pos <= Length(MML)) and (MML[Pos] in ['0'..'9']) do
    begin
      Result := Result * 10 + Ord(MML[Pos]) - Ord('0');
      Inc(Pos);
    end;
  end;

begin
  Result := False;
  Count := 0;
  Cap := 64;
  GetMem(Events, Cap * SizeOf(TAMEvent));
  AMInitState(State);

  Pos := 1;
  while Pos <= Length(MML) do
  begin
    Ch := UpCase(MML[Pos]);
    Inc(Pos);

    case Ch of
      'A'..'G':
      begin
        { Note }
        NoteVal := NoteOffset[Ord(Ch) - Ord('A')];

        { Check for sharp/flat }
        Sharp := False; Flat := False;
        if Pos <= Length(MML) then
        begin
          if MML[Pos] in ['#', '+'] then begin Sharp := True; Inc(Pos); end
          else if MML[Pos] = '-' then begin Flat := True; Inc(Pos); end;
        end;

        if Sharp then Inc(NoteVal);
        if Flat then Dec(NoteVal);

        NoteVal := NoteVal + Integer(State.Octave) * 12;

        { Optional length }
        if (Pos <= Length(MML)) and (MML[Pos] in ['0'..'9']) then
          NoteLen := ReadNum
        else
          NoteLen := State.DefaultLength;

        { Dotted? }
        Dotted := False;
        if (Pos <= Length(MML)) and (MML[Pos] = '.') then
        begin
          Dotted := True;
          Inc(Pos);
        end;

        AddEvent(amNote, AMNoteFreq(NoteVal),
          CalcDurationMS(State.Tempo, NoteLen, Dotted));
      end;

      'N':
      begin
        { Note by number (0-84) }
        NumVal := ReadNum;
        if NumVal = 0 then
          AddEvent(amRest, 0, CalcDurationMS(State.Tempo, State.DefaultLength, False))
        else
          AddEvent(amNote, AMNoteFreq(NumVal),
            CalcDurationMS(State.Tempo, State.DefaultLength, False));
      end;

      'P', 'R':
      begin
        { Rest/Pause }
        if (Pos <= Length(MML)) and (MML[Pos] in ['0'..'9']) then
          NoteLen := ReadNum
        else
          NoteLen := State.DefaultLength;

        Dotted := False;
        if (Pos <= Length(MML)) and (MML[Pos] = '.') then
        begin
          Dotted := True;
          Inc(Pos);
        end;

        AddEvent(amRest, 0, CalcDurationMS(State.Tempo, NoteLen, Dotted));
      end;

      'T':
      begin
        NumVal := ReadNum;
        if (NumVal >= 32) and (NumVal <= 255) then
          State.Tempo := NumVal;
      end;

      'L':
      begin
        NumVal := ReadNum;
        if (NumVal >= 1) and (NumVal <= 64) then
          State.DefaultLength := NumVal;
      end;

      'O':
      begin
        NumVal := ReadNum;
        if (NumVal >= 0) and (NumVal <= 7) then
          State.Octave := NumVal;
      end;

      'V':
      begin
        NumVal := ReadNum;
        if (NumVal >= 0) and (NumVal <= 15) then
          State.Volume := NumVal;
      end;

      '<': if State.Octave > 0 then Dec(State.Octave);
      '>': if State.Octave < 7 then Inc(State.Octave);

      'M':
      begin
        if Pos <= Length(MML) then
        begin
          case UpCase(MML[Pos]) of
            'F': State.Foreground := True;
            'B': State.Foreground := False;
            'N': State.Style := 0;
            'S': State.Style := 1;
            'L': State.Style := 2;
          end;
          Inc(Pos);
        end;
      end;

      ' ', ',', ';': ; { whitespace/separators }
    end;
  end;

  Result := Count > 0;
  if not Result then
  begin
    FreeMem(Events);
    Events := nil;
  end;
end;

function AMExtractFromANSI(Src: PByte; SrcLen: LongInt;
  out MMLStr: ShortString): Boolean;
var
  I: LongInt;
  Start: LongInt;
  Len: Integer;
begin
  Result := False;
  MMLStr := '';

  I := 0;
  while I < SrcLen - 2 do
  begin
    { Look for ESC [ M or ESC [ N 14 ; }
    if (Src[I] = 27) and (Src[I+1] = Ord('[')) then
    begin
      Inc(I, 2);
      { Skip to 'M' or 'N' }
      if (I < SrcLen) and (Chr(Src[I]) = 'M') then
      begin
        Inc(I);
        { Everything until ESC or end of string is MML }
        Start := I;
        while (I < SrcLen) and (Src[I] <> 27) and (Src[I] <> $0E) do
          Inc(I);
        Len := I - Start;
        if Len > 255 then Len := 255;
        if Len > 0 then
        begin
          SetLength(MMLStr, Len);
          Move(Src[Start], MMLStr[1], Len);
          Result := True;
          Exit;
        end;
      end
      else
        Inc(I);
    end
    else
      Inc(I);
  end;
end;

function AMParseANSI(Src: PByte; SrcLen: LongInt;
  out Events: PAMEvent; out Count: Integer): Boolean;
var
  MML: ShortString;
begin
  Events := nil;
  Count := 0;
  if AMExtractFromANSI(Src, SrcLen, MML) then
    Result := AMParseMML(MML, Events, Count)
  else
    Result := False;
end;

function AMSynthPCM(Events: PAMEvent; Count: Integer;
  SampleRate: LongWord;
  out PCMData: PByte; out PCMSize: LongWord): Boolean;
var
  I: Integer;
  TotalMS: LongWord;
  TotalSamples: LongWord;
  SamplePos: LongWord;
  EventSamples: LongWord;
  J: LongWord;
  HalfPeriod: LongWord;
  Phase: LongWord;
  Amplitude: Byte;
begin
  Result := False;
  PCMData := nil;
  PCMSize := 0;

  if (Count <= 0) or (SampleRate = 0) then Exit;

  { Calculate total duration }
  TotalMS := 0;
  for I := 0 to Count - 1 do
    Inc(TotalMS, Events[I].DurationMS);

  TotalSamples := (SampleRate * TotalMS) div 1000;
  if TotalSamples = 0 then Exit;

  GetMem(PCMData, TotalSamples);
  FillChar(PCMData^, TotalSamples, 128); { silence = 128 for unsigned 8-bit }
  PCMSize := TotalSamples;

  SamplePos := 0;
  for I := 0 to Count - 1 do
  begin
    EventSamples := (SampleRate * LongWord(Events[I].DurationMS)) div 1000;

    if (Events[I].EventType = amNote) and (Events[I].Frequency > 0) then
    begin
      { Generate square wave }
      HalfPeriod := SampleRate div (LongWord(Events[I].Frequency) * 2);
      if HalfPeriod = 0 then HalfPeriod := 1;
      Amplitude := 64 + (Events[I].Volume * 4); { scale 0-15 to 64-124 }

      Phase := 0;
      for J := 0 to EventSamples - 1 do
      begin
        if SamplePos + J >= TotalSamples then Break;
        if Phase < HalfPeriod then
          PCMData[SamplePos + J] := 128 + (Amplitude - 128)
        else
          PCMData[SamplePos + J] := 128 - (Amplitude - 128);
        Inc(Phase);
        if Phase >= HalfPeriod * 2 then Phase := 0;
      end;
    end;
    { Rest: already filled with 128 (silence) }

    Inc(SamplePos, EventSamples);
  end;

  Result := True;
end;

procedure AMPlayEvents(Events: PAMEvent; Count: Integer);
{$IFDEF GO32V2}
var
  I: Integer;
  Divisor: Word;
begin
  for I := 0 to Count - 1 do
  begin
    if (Events[I].EventType = amNote) and (Events[I].Frequency > 0) then
    begin
      { PC speaker tone via PIT channel 2 }
      Divisor := 1193180 div Events[I].Frequency;
      asm
        mov al, $B6
        out $43, al
      end;
      asm
        mov ax, Divisor
        out $42, al
        mov al, ah
        out $42, al
      end;
      { Enable speaker }
      asm
        in al, $61
        or al, $03
        out $61, al
      end;
      { Delay for duration }
      Delay(Events[I].DurationMS);
      { Disable speaker }
      asm
        in al, $61
        and al, $FC
        out $61, al
      end;
    end
    else
    begin
      { Rest }
      Delay(Events[I].DurationMS);
    end;
  end;
end;
{$ELSE}
begin
  { Non-DOS: no-op. Use AMSynthPCM + wavplay instead. }
end;
{$ENDIF}

end.

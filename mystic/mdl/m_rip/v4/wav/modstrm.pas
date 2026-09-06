(* modstrm.pas -- MOD/S3M Tick-Based Streaming Mixer
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Renders MOD/S3M files tick-by-tick for real-time streaming.
   Produces PCM chunks on demand instead of rendering the whole file.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit modstrm;

interface

uses audstrm, moddec;

type
  TMODStreamState = record
    Module: TMODFile;
    SampleRate: LongWord;
    BPM: Integer;
    Speed: Integer;
    OrderPos: Integer;
    Row: Integer;
    Tick: Integer;
    Channels: array[0..MOD_MAX_CHANNELS - 1] of TMODChannel;
    TickSamplesLeft: LongInt;
    Done: Boolean;
  end;

function MODStreamOpen(var S: TMODStreamState;
  const FileName: ShortString; SampleRate: LongWord): Boolean;
function MODStreamDecode(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;
procedure MODStreamClose(var S: TMODStreamState);
function MODStreamFormat(var S: TMODStreamState): TAudioFormat;

implementation

function PeriodToFreq(Period: Word): LongWord;
begin
  if Period = 0 then Result := 0
  else Result := 7093789 div (Period * 2);
end;

function MODStreamOpen(var S: TMODStreamState;
  const FileName: ShortString; SampleRate: LongWord): Boolean;
begin
  Result := False;
  FillChar(S, SizeOf(S), 0);
  if not MODLoadFile(FileName, S.Module) then Exit;
  S.SampleRate := SampleRate;
  S.BPM := 125;
  S.Speed := 6;
  S.OrderPos := 0;
  S.Row := 0;
  S.Tick := 0;
  S.TickSamplesLeft := 0;
  S.Done := False;
  Result := True;
end;

function MODStreamDecode(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;
var
  S: ^TMODStreamState;
  OutBuf: PSmallInt;
  OutPos: LongInt;
  SamplesPerTick: LongInt;
  Pat: PMODPattern;
  Note: TMODNote;
  Ch, I: Integer;
  SampNum: Byte;
  Left, Right, SVal: LongInt;
  SampleIdx: LongInt;
begin
  S := UserData;
  Result := 0;
  if S^.Done then Exit;

  OutBuf := PSmallInt(Buffer);
  OutPos := 0;

  while OutPos * 4 < BufSize do
  begin
    if S^.TickSamplesLeft <= 0 then
    begin
      { Process new tick }
      if S^.Tick = 0 then
      begin
        { New row — process notes }
        if S^.OrderPos >= S^.Module.SongLength then
        begin S^.Done := True; Exit; end;

        if S^.Module.Order[S^.OrderPos] < S^.Module.NumPatterns then
        begin
          Pat := S^.Module.Patterns[S^.Module.Order[S^.OrderPos]];
          if Pat <> nil then
          begin
            for Ch := 0 to S^.Module.NumChannels - 1 do
            begin
              Note := Pat^[Ch, S^.Row];
              if Note.SampleNum > 0 then
              begin
                SampNum := Note.SampleNum;
                if SampNum <= S^.Module.NumSamples then
                begin
                  S^.Channels[Ch].SampleNum := SampNum;
                  S^.Channels[Ch].Volume := S^.Module.Samples[SampNum].Volume;
                end;
              end;
              if Note.Period > 0 then
              begin
                S^.Channels[Ch].Period := Note.Period;
                S^.Channels[Ch].SamplePos := 0;
                S^.Channels[Ch].Active := True;
                S^.Channels[Ch].SampleInc := (PeriodToFreq(Note.Period) shl 16) div S^.SampleRate;
              end;
              case Note.Effect of
                $0C: S^.Channels[Ch].Volume := Note.EffectParam;
                $0F: if Note.EffectParam < 32 then S^.Speed := Note.EffectParam
                     else S^.BPM := Note.EffectParam;
              end;
            end;
          end;
        end;
      end;

      S^.TickSamplesLeft := (S^.SampleRate * 5) div (LongWord(S^.BPM) * 2);
      Inc(S^.Tick);
      if S^.Tick >= S^.Speed then
      begin
        S^.Tick := 0;
        Inc(S^.Row);
        if S^.Row >= MOD_ROWS_PER_PAT then
        begin
          S^.Row := 0;
          Inc(S^.OrderPos);
        end;
      end;
    end;

    { Mix one sample }
    Left := 0; Right := 0;
    for Ch := 0 to S^.Module.NumChannels - 1 do
    begin
      if not S^.Channels[Ch].Active then Continue;
      SampNum := S^.Channels[Ch].SampleNum;
      if (SampNum = 0) or (SampNum > S^.Module.NumSamples) then Continue;
      if S^.Module.Samples[SampNum].Data = nil then Continue;

      SampleIdx := S^.Channels[Ch].SamplePos shr 16;
      if S^.Module.Samples[SampNum].LoopLength > 0 then
      begin
        while LongWord(SampleIdx) >= S^.Module.Samples[SampNum].LoopStart +
              S^.Module.Samples[SampNum].LoopLength do
          Dec(SampleIdx, S^.Module.Samples[SampNum].LoopLength);
      end
      else if LongWord(SampleIdx) >= S^.Module.Samples[SampNum].Length then
      begin S^.Channels[Ch].Active := False; Continue; end;

      SVal := LongInt(S^.Module.Samples[SampNum].Data[SampleIdx]) * S^.Channels[Ch].Volume;
      if (Ch and 3) in [0, 3] then begin Inc(Left, SVal); Inc(Right, SVal div 4); end
      else begin Inc(Right, SVal); Inc(Left, SVal div 4); end;
      Inc(S^.Channels[Ch].SamplePos, S^.Channels[Ch].SampleInc);
    end;

    if Left > 32767 then Left := 32767 else if Left < -32768 then Left := -32768;
    if Right > 32767 then Right := 32767 else if Right < -32768 then Right := -32768;
    OutBuf[OutPos * 2] := SmallInt(Left);
    OutBuf[OutPos * 2 + 1] := SmallInt(Right);
    Inc(OutPos);
    Dec(S^.TickSamplesLeft);
  end;

  Result := OutPos * 4;
end;

procedure MODStreamClose(var S: TMODStreamState);
begin
  MODFree(S.Module);
  S.Done := True;
end;

function MODStreamFormat(var S: TMODStreamState): TAudioFormat;
begin
  Result := AudioFmt(S.SampleRate, 16, 2);
end;

end.

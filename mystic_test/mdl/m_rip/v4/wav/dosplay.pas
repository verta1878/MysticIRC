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
{ DOS Sound Blaster PCM Playback — IRQ-driven async DMA
  Plays raw PCM data through Sound Blaster DSP on DOS (go32v2).
  Uses hardware IRQ for non-blocking playback.
  No external libraries needed.
}
unit DOSPlay;

{$mode objfpc}{$H+}

{$IFDEF GO32V2}
interface

uses
  Go32, DOS;

type
  TSBInfo = record
    BasePort: Word;
    IRQ: Byte;
    DMA8: Byte;
    DMA16: Byte;
    DSPVersion: Word;
    Detected: Boolean;
    Playing: Boolean;
  end;

var
  SB: TSBInfo;

function SB_Init: Boolean;
procedure SB_Done;
function SB_StreamStart(SampleRate: LongWord; Bits: Word; Channels: Word): Boolean;
procedure SB_StreamFeed(Data: PByte; Size: LongWord);
procedure SB_StreamStop;
function SB_StreamNeedsData: Boolean;
function SB_Reset: Boolean;
procedure SB_PlayPCM(Data: PByte; Size: LongWord;
  SampleRate: LongWord; Bits: Word; Channels: Word);
procedure SB_Stop;
function SB_IsPlaying: Boolean;
procedure SB_WaitDone;
procedure SB_Beep(Freq, DurationMS: Word);
procedure Speaker_Tone(Freq, DurationMS: Word);
procedure Speaker_Off;

{ Streaming playback — double-buffer DMA for continuous audio }

implementation

const
  DSP_RESET     = $06;
  DSP_READ      = $0A;
  DSP_WRITE_PORT = $0C;
  DSP_STATUS    = $0E;
  DSP_ACK_16    = $0F;

  CMD_SPEAKER_ON  = $D1;
  CMD_SPEAKER_OFF = $D3;
  CMD_SET_RATE    = $41;
  CMD_DMA_8_OUT   = $14;
  CMD_HALT_DMA_8  = $D0;
  CMD_GET_VERSION = $E1;
  CMD_SET_TIME    = $40;

  DMA_MASK_REG  = $0A;
  DMA_MODE_REG  = $0B;
  DMA_FF_REG    = $0C;
  DMA_ADDR: array[0..3] of Byte = ($00, $02, $04, $06);
  DMA_CNT:  array[0..3] of Byte = ($01, $03, $05, $07);
  DMA_PAGE: array[0..3] of Byte = ($87, $83, $81, $82);

var
  DMABuffer: LongWord;
  DMASelector: Word;
  OldIRQHandler: TSegInfo;
  IRQInstalled: Boolean;

procedure DSPWrite(Value: Byte);
var T: Integer;
begin
  T := 65535;
  while (T > 0) and ((inportb(SB.BasePort + DSP_WRITE_PORT) and $80) <> 0) do Dec(T);
  outportb(SB.BasePort + DSP_WRITE_PORT, Value);
end;

function DSPRead: Byte;
var T: Integer;
begin
  T := 65535;
  while (T > 0) and ((inportb(SB.BasePort + DSP_STATUS) and $80) = 0) do Dec(T);
  Result := inportb(SB.BasePort + DSP_READ);
end;

{ IRQ handler — hardware calls this when DMA transfer completes }
procedure SB_IRQHandler; interrupt;
begin
  inportb(SB.BasePort + DSP_STATUS);  // Acknowledge SB interrupt
  SB.Playing := False;
  if SB.IRQ >= 8 then
    outportb($A0, $20);  // Slave PIC EOI
  outportb($20, $20);    // Master PIC EOI
end;

procedure InstallIRQ;
var
  IntNum: Byte;
  NewHandler: TSegInfo;
begin
  if IRQInstalled then Exit;
  if SB.IRQ < 8 then IntNum := $08 + SB.IRQ
  else IntNum := $70 + (SB.IRQ - 8);

  get_pm_interrupt(IntNum, OldIRQHandler);
  NewHandler.Offset := @SB_IRQHandler;
  NewHandler.Segment := get_cs;
  set_pm_interrupt(IntNum, NewHandler);
  IRQInstalled := True;

  // Unmask IRQ in PIC
  if SB.IRQ < 8 then
    outportb($21, inportb($21) and not (1 shl SB.IRQ))
  else
  begin
    outportb($A1, inportb($A1) and not (1 shl (SB.IRQ - 8)));
    outportb($21, inportb($21) and not (1 shl 2));
  end;
end;

procedure RemoveIRQ;
var IntNum: Byte;
begin
  if not IRQInstalled then Exit;
  if SB.IRQ < 8 then IntNum := $08 + SB.IRQ
  else IntNum := $70 + (SB.IRQ - 8);
  set_pm_interrupt(IntNum, OldIRQHandler);
  IRQInstalled := False;
end;

function SB_Reset: Boolean;
var T: Integer;
begin
  Result := False;
  outportb(SB.BasePort + DSP_RESET, 1);
  inportb($80); inportb($80); inportb($80); inportb($80);
  outportb(SB.BasePort + DSP_RESET, 0);
  T := 65535;
  while T > 0 do
  begin
    if (inportb(SB.BasePort + DSP_STATUS) and $80) <> 0 then
      if inportb(SB.BasePort + DSP_READ) = $AA then
      begin
        Result := True;
        Exit;
      end;
    Dec(T);
  end;
end;

function ParseBLASTER: Boolean;
var Env: string; I: Integer;
begin
  Result := False;
  Env := GetEnv('BLASTER');
  if Env = '' then Exit;
  SB.BasePort := $220; SB.IRQ := 7; SB.DMA8 := 1; SB.DMA16 := 5;
  I := 1;
  while I <= Length(Env) do
  begin
    case UpCase(Env[I]) of
      'A': begin Inc(I); SB.BasePort := 0;
             while (I <= Length(Env)) and (Env[I] in ['0'..'9','A'..'F','a'..'f']) do begin
               if Env[I] in ['0'..'9'] then SB.BasePort := SB.BasePort*16 + Ord(Env[I])-Ord('0')
               else SB.BasePort := SB.BasePort*16 + Ord(UpCase(Env[I]))-Ord('A')+10;
               Inc(I); end; end;
      'I': begin Inc(I); SB.IRQ := 0;
             while (I <= Length(Env)) and (Env[I] in ['0'..'9']) do begin
               SB.IRQ := SB.IRQ*10 + Ord(Env[I])-Ord('0'); Inc(I); end; end;
      'D': begin Inc(I); SB.DMA8 := Ord(Env[I])-Ord('0'); Inc(I); end;
      'H': begin Inc(I); SB.DMA16 := Ord(Env[I])-Ord('0'); Inc(I); end;
    else Inc(I);
    end;
  end;
  Result := True;
end;

function SB_Init: Boolean;
begin
  Result := False;
  FillChar(SB, SizeOf(SB), 0);
  IRQInstalled := False;
  if not ParseBLASTER then
  begin SB.BasePort := $220; SB.IRQ := 7; SB.DMA8 := 1; SB.DMA16 := 5; end;
  if not SB_Reset then Exit;
  DSPWrite(CMD_GET_VERSION);
  SB.DSPVersion := DSPRead shl 8 or DSPRead;
  DSPWrite(CMD_SPEAKER_ON);
  InstallIRQ;
  SB.Detected := True;
  SB.Playing := False;
  Result := True;
end;

procedure SB_Done;
begin
  if SB.Playing then SB_Stop;
  RemoveIRQ;
  if SB.Detected then begin DSPWrite(CMD_SPEAKER_OFF); SB.Detected := False; end;
  if DMABuffer <> 0 then begin global_dos_free(DMASelector); DMABuffer := 0; end;
end;

procedure SetupDMA(Channel: Byte; Address: LongWord; Len: LongWord);
begin
  outportb(DMA_MASK_REG, $04 or Channel);
  outportb(DMA_FF_REG, 0);
  outportb(DMA_MODE_REG, $48 or Channel);
  outportb(DMA_ADDR[Channel], Lo(Word(Address)));
  outportb(DMA_ADDR[Channel], Hi(Word(Address)));
  outportb(DMA_PAGE[Channel], (Address shr 16) and $FF);
  Dec(Len);
  outportb(DMA_CNT[Channel], Lo(Word(Len)));
  outportb(DMA_CNT[Channel], Hi(Word(Len)));
  outportb(DMA_MASK_REG, Channel);
end;

procedure SB_PlayPCM(Data: PByte; Size: LongWord;
  SampleRate: LongWord; Bits: Word; Channels: Word);
var
  PlaySize: LongWord;
  DOSAddr: LongWord;
  TimeConst: Byte;
begin
  if not SB.Detected then Exit;
  PlaySize := Size;
  if PlaySize > 65000 then PlaySize := 65000;

  DOSAddr := global_dos_alloc((PlaySize + 15) shr 4);
  if DOSAddr = 0 then Exit;
  DMASelector := Word(DOSAddr);
  DMABuffer := (DOSAddr shr 16) * 16;

  dosmemput(DMABuffer, 0, Data^, PlaySize);

  if SB.DSPVersion >= $0400 then
  begin
    DSPWrite(CMD_SET_RATE);
    DSPWrite(Hi(Word(SampleRate)));
    DSPWrite(Lo(Word(SampleRate)));
  end else begin
    TimeConst := 256 - (1000000 div SampleRate);
    DSPWrite(CMD_SET_TIME);
    DSPWrite(TimeConst);
  end;

  SetupDMA(SB.DMA8, DMABuffer, PlaySize);
  SB.Playing := True;

  // Start 8-bit single-cycle DMA — IRQ fires when done
  DSPWrite(CMD_DMA_8_OUT);
  DSPWrite(Lo(Word(PlaySize - 1)));
  DSPWrite(Hi(Word(PlaySize - 1)));
  // Returns immediately — IRQ handler sets Playing := False
end;

procedure SB_Stop;
begin
  if not SB.Detected then Exit;
  DSPWrite(CMD_HALT_DMA_8);
  SB.Playing := False;
end;

function SB_IsPlaying: Boolean;
begin
  Result := SB.Playing;
end;

procedure SB_WaitDone;
begin
  while SB.Playing do
    { yield CPU until interrupt }
end;

{ Streaming — double-buffer DMA }
const
  STREAM_BUF_SIZE = 32000;  // each half-buffer
var
  StreamBuf: array[0..1] of LongWord;  // DOS addresses for two buffers
  StreamSel: array[0..1] of Word;      // DPMI selectors
  StreamCurrent: Byte;                  // which buffer is playing (0 or 1)
  StreamActive: Boolean;
  StreamRate: LongWord;
  StreamBits: Word;
  StreamChans: Word;

function SB_StreamStart(SampleRate: LongWord; Bits: Word; Channels: Word): Boolean;
var
  DOSAddr: LongWord;
  I: Integer;
begin
  Result := False;
  if not SB.Detected then Exit;
  StreamRate := SampleRate;
  StreamBits := Bits;
  StreamChans := Channels;
  StreamCurrent := 0;
  StreamActive := False;

  // Allocate two DMA buffers in DOS memory
  for I := 0 to 1 do
  begin
    DOSAddr := global_dos_alloc((STREAM_BUF_SIZE + 15) shr 4);
    if DOSAddr = 0 then Exit;
    StreamSel[I] := Word(DOSAddr);
    StreamBuf[I] := (DOSAddr shr 16) * 16;
    // Fill with silence
    if Bits = 8 then
      dosmemfillchar(StreamBuf[I], 0, STREAM_BUF_SIZE, #128)
    else
      dosmemfillchar(StreamBuf[I], 0, STREAM_BUF_SIZE, #0);
  end;

  // Set sample rate
  if SB.DSPVersion >= $0400 then
  begin
    DSPWrite(CMD_SET_RATE);
    DSPWrite(Hi(Word(SampleRate)));
    DSPWrite(Lo(Word(SampleRate)));
  end else begin
    DSPWrite(CMD_SET_TIME);
    DSPWrite(256 - (1000000 div SampleRate));
  end;

  StreamActive := True;
  Result := True;
end;

procedure SB_StreamFeed(Data: PByte; Size: LongWord);
var
  FeedSize: LongWord;
begin
  if not StreamActive then Exit;
  FeedSize := Size;
  if FeedSize > STREAM_BUF_SIZE then FeedSize := STREAM_BUF_SIZE;

  // Copy data to the next buffer
  dosmemput(StreamBuf[StreamCurrent], 0, Data^, FeedSize);

  // Pad remainder with silence if needed
  if FeedSize < STREAM_BUF_SIZE then
  begin
    if StreamBits = 8 then
      dosmemfillchar(StreamBuf[StreamCurrent], FeedSize, STREAM_BUF_SIZE - FeedSize, #128)
    else
      dosmemfillchar(StreamBuf[StreamCurrent], FeedSize, STREAM_BUF_SIZE - FeedSize, #0);
  end;

  // Setup DMA and play this buffer
  SetupDMA(SB.DMA8, StreamBuf[StreamCurrent], STREAM_BUF_SIZE);
  SB.Playing := True;

  DSPWrite(CMD_DMA_8_OUT);
  DSPWrite(Lo(Word(STREAM_BUF_SIZE - 1)));
  DSPWrite(Hi(Word(STREAM_BUF_SIZE - 1)));

  // Swap to other buffer for next feed
  StreamCurrent := 1 - StreamCurrent;
end;

procedure SB_StreamStop;
var I: Integer;
begin
  if not StreamActive then Exit;
  DSPWrite(CMD_HALT_DMA_8);
  SB.Playing := False;
  StreamActive := False;
  for I := 0 to 1 do
    if StreamBuf[I] <> 0 then
    begin
      global_dos_free(StreamSel[I]);
      StreamBuf[I] := 0;
    end;
end;

function SB_StreamNeedsData: Boolean;
begin
  // After IRQ fires (Playing = False), the current buffer finished
  // and we need more data for the next one
  Result := StreamActive and not SB.Playing;
end;

procedure Speaker_Tone(Freq, DurationMS: Word);
var Div2: Word; Start, Cur: LongWord;
begin
  if Freq = 0 then Exit;
  Div2 := 1193180 div Freq;
  outportb($43, $B6);
  outportb($42, Lo(Div2));
  outportb($42, Hi(Div2));
  outportb($61, inportb($61) or $03);
  Start := MemL[$0040:$006C];
  repeat Cur := MemL[$0040:$006C]; until ((Cur - Start) * 55) >= DurationMS;
  Speaker_Off;
end;

procedure Speaker_Off;
begin
  outportb($61, inportb($61) and $FC);
end;

procedure SB_Beep(Freq, DurationMS: Word);
begin
  Speaker_Tone(Freq, DurationMS);
end;

{$ELSE}
// ================================================================
// Non-DOS stub — compiles on all platforms, does nothing
// ================================================================
interface

type
  TSBInfo = record
    Detected: Boolean;
    Playing: Boolean;
  end;

var
  SB: TSBInfo;

function SB_Init: Boolean;
procedure SB_Done;
function SB_StreamStart(SampleRate: LongWord; Bits: Word; Channels: Word): Boolean;
procedure SB_StreamFeed(Data: PByte; Size: LongWord);
procedure SB_StreamStop;
function SB_StreamNeedsData: Boolean;
function SB_Reset: Boolean;
procedure SB_PlayPCM(Data: PByte; Size: LongWord;
  SampleRate: LongWord; Bits: Word; Channels: Word);
procedure SB_Stop;
function SB_IsPlaying: Boolean;
procedure SB_WaitDone;
procedure SB_Beep(Freq, DurationMS: Word);
procedure Speaker_Tone(Freq, DurationMS: Word);
procedure Speaker_Off;

implementation

function SB_Init: Boolean; begin Result := False; end;
function SB_StreamStart(SampleRate: LongWord; Bits: Word; Channels: Word): Boolean; begin Result := False; end;
procedure SB_StreamFeed(Data: PByte; Size: LongWord); begin end;
procedure SB_StreamStop; begin end;
function SB_StreamNeedsData: Boolean; begin Result := False; end;
procedure SB_Done; begin end;
function SB_Reset: Boolean; begin Result := False; end;
procedure SB_PlayPCM(Data: PByte; Size: LongWord;
  SampleRate: LongWord; Bits: Word; Channels: Word); begin end;
procedure SB_Stop; begin end;
function SB_IsPlaying: Boolean; begin Result := False; end;
procedure SB_WaitDone; begin end;
procedure SB_Beep(Freq, DurationMS: Word); begin end;
procedure Speaker_Tone(Freq, DurationMS: Word); begin end;
procedure Speaker_Off; begin end;

{$ENDIF}

end.

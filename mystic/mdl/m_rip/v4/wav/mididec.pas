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
{ MIDI File Decoder — Pure Pascal Standard MIDI File reader
  Parses .MID files into event streams. No playback — decode only.
  Supports Format 0 (single track) and Format 1 (multi-track).

  Usage:
    var MIDI: TMIDIFile;
    begin
      if MIDILoadFile('music.mid', MIDI) then
      begin
        // MIDI.Tracks[0].Events[0].EventType = metNoteOn
        // MIDI.TicksPerQN = 120
        MIDIFree(MIDI);
      end;
    end;
}
unit MIDIDec;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  MAX_MIDI_TRACKS = 64;

type
  TMIDIEventType = (
    metNoteOff,        // $80
    metNoteOn,         // $90
    metPolyPressure,   // $A0
    metControlChange,  // $B0
    metProgramChange,  // $C0
    metChanPressure,   // $D0
    metPitchBend,      // $E0
    metSysEx,          // $F0
    metMeta            // $FF
  );

  TMIDIMetaType = (
    mmtSequenceNum  = $00,
    mmtText         = $01,
    mmtCopyright    = $02,
    mmtTrackName    = $03,
    mmtInstrument   = $04,
    mmtLyric        = $05,
    mmtMarker       = $06,
    mmtCuePoint     = $07,
    mmtChannelPfx   = $20,
    mmtEndOfTrack   = $2F,
    mmtSetTempo     = $51,
    mmtSMPTEOffset  = $54,
    mmtTimeSignature = $58,
    mmtKeySignature  = $59,
    mmtOther        = $7F
  );

  TMIDIEvent = record
    DeltaTime: LongWord;   // ticks since previous event
    AbsTime: LongWord;     // absolute tick position
    EventType: TMIDIEventType;
    Channel: Byte;          // 0-15
    Status: Byte;           // raw status byte
    Data1: Byte;            // note number / controller
    Data2: Byte;            // velocity / value
    MetaType: Byte;         // for meta events
    MetaData: PByte;        // meta/sysex payload (caller frees via MIDIFree)
    MetaLen: LongWord;
  end;
  PMIDIEvent = ^TMIDIEvent;

  TMIDITrack = record
    Name: string;
    EventCount: LongWord;
    Events: array of TMIDIEvent;
  end;

  TMIDIFile = record
    Format: Word;           // 0 or 1
    TrackCount: Word;
    TicksPerQN: Word;       // ticks per quarter note
    Tracks: array of TMIDITrack;
    Valid: Boolean;
  end;

function MIDILoadFile(const FileName: string; out MIDI: TMIDIFile): Boolean;
function MIDILoadStream(AStream: TStream; out MIDI: TMIDIFile): Boolean;
function MIDILoadMem(InBuf: PByte; InSize: LongWord; out MIDI: TMIDIFile): Boolean;
procedure MIDIFree(var MIDI: TMIDIFile);

{ Helper: get tempo in BPM from a SetTempo meta event }
function MIDITempoToBPM(const Event: TMIDIEvent): Double;

{ Helper: get note name from MIDI note number }
function MIDINoteName(Note: Byte): string;

implementation

function ReadVarLen(Buf: PByte; var Pos: LongWord; MaxPos: LongWord): LongWord;
var
  B: Byte;
begin
  Result := 0;
  repeat
    if Pos >= MaxPos then Exit;
    B := Buf[Pos];
    Inc(Pos);
    Result := (Result shl 7) or (B and $7F);
  until (B and $80) = 0;
end;

function ReadBE16(Buf: PByte; Pos: LongWord): Word;
begin
  Result := (Word(Buf[Pos]) shl 8) or Buf[Pos + 1];
end;

function ReadBE32(Buf: PByte; Pos: LongWord): LongWord;
begin
  Result := (LongWord(Buf[Pos]) shl 24) or (LongWord(Buf[Pos+1]) shl 16) or
            (LongWord(Buf[Pos+2]) shl 8) or Buf[Pos+3];
end;

function ParseTrack(Buf: PByte; TrackStart, TrackLen: LongWord;
  out Track: TMIDITrack): Boolean;
var
  Pos, EndPos, AbsTime: LongWord;
  DeltaTime: LongWord;
  Status, RunningStatus: Byte;
  EventCount, EventCap: LongWord;
  Evt: TMIDIEvent;
  DataLen: LongWord;
begin
  Result := False;
  Track.Name := '';
  Track.EventCount := 0;
  SetLength(Track.Events, 0);

  Pos := TrackStart;
  EndPos := TrackStart + TrackLen;
  RunningStatus := 0;
  AbsTime := 0;
  EventCount := 0;
  EventCap := 256;
  SetLength(Track.Events, EventCap);

  while Pos < EndPos do
  begin
    FillChar(Evt, SizeOf(Evt), 0);

    // Read delta time
    DeltaTime := ReadVarLen(Buf, Pos, EndPos);
    AbsTime := AbsTime + DeltaTime;
    Evt.DeltaTime := DeltaTime;
    Evt.AbsTime := AbsTime;

    if Pos >= EndPos then Break;

    // Read status byte (or use running status)
    Status := Buf[Pos];
    if (Status and $80) <> 0 then
    begin
      Inc(Pos);
      RunningStatus := Status;
    end
    else
      Status := RunningStatus;

    Evt.Status := Status;
    Evt.Channel := Status and $0F;

    case Status and $F0 of
      $80: begin // Note Off
             Evt.EventType := metNoteOff;
             if Pos + 1 < EndPos then begin Evt.Data1 := Buf[Pos]; Evt.Data2 := Buf[Pos+1]; Inc(Pos, 2); end;
           end;
      $90: begin // Note On
             Evt.EventType := metNoteOn;
             if Pos + 1 < EndPos then begin Evt.Data1 := Buf[Pos]; Evt.Data2 := Buf[Pos+1]; Inc(Pos, 2); end;
             if Evt.Data2 = 0 then Evt.EventType := metNoteOff; // velocity 0 = note off
           end;
      $A0: begin Evt.EventType := metPolyPressure;
             if Pos + 1 < EndPos then begin Evt.Data1 := Buf[Pos]; Evt.Data2 := Buf[Pos+1]; Inc(Pos, 2); end; end;
      $B0: begin Evt.EventType := metControlChange;
             if Pos + 1 < EndPos then begin Evt.Data1 := Buf[Pos]; Evt.Data2 := Buf[Pos+1]; Inc(Pos, 2); end; end;
      $C0: begin Evt.EventType := metProgramChange;
             if Pos < EndPos then begin Evt.Data1 := Buf[Pos]; Inc(Pos); end; end;
      $D0: begin Evt.EventType := metChanPressure;
             if Pos < EndPos then begin Evt.Data1 := Buf[Pos]; Inc(Pos); end; end;
      $E0: begin Evt.EventType := metPitchBend;
             if Pos + 1 < EndPos then begin Evt.Data1 := Buf[Pos]; Evt.Data2 := Buf[Pos+1]; Inc(Pos, 2); end; end;
      $F0: begin
             case Status of
               $F0: begin // SysEx
                      Evt.EventType := metSysEx;
                      DataLen := ReadVarLen(Buf, Pos, EndPos);
                      Evt.MetaLen := DataLen;
                      if DataLen > 0 then begin
                        GetMem(Evt.MetaData, DataLen);
                        if Pos + DataLen <= EndPos then
                          Move(Buf[Pos], Evt.MetaData^, DataLen);
                        Inc(Pos, DataLen);
                      end;
                    end;
               $FF: begin // Meta event
                      Evt.EventType := metMeta;
                      if Pos < EndPos then begin Evt.MetaType := Buf[Pos]; Inc(Pos); end;
                      DataLen := ReadVarLen(Buf, Pos, EndPos);
                      Evt.MetaLen := DataLen;
                      if DataLen > 0 then begin
                        GetMem(Evt.MetaData, DataLen);
                        if Pos + DataLen <= EndPos then
                          Move(Buf[Pos], Evt.MetaData^, DataLen);
                        Inc(Pos, DataLen);
                      end;
                      // Extract track name
                      if (Evt.MetaType = $03) and (DataLen > 0) then
                        SetString(Track.Name, PChar(Evt.MetaData), DataLen);
                    end;
             else
               Inc(Pos); // skip unknown
             end;
           end;
    else
      Inc(Pos); // skip unknown
    end;

    // Store event
    if EventCount >= EventCap then
    begin
      EventCap := EventCap * 2;
      SetLength(Track.Events, EventCap);
    end;
    Track.Events[EventCount] := Evt;
    Inc(EventCount);

    // End of track?
    if (Evt.EventType = metMeta) and (Evt.MetaType = $2F) then Break;
  end;

  Track.EventCount := EventCount;
  SetLength(Track.Events, EventCount);
  Result := EventCount > 0;
end;

function MIDILoadMem(InBuf: PByte; InSize: LongWord; out MIDI: TMIDIFile): Boolean;
var
  Pos: LongWord;
  ChunkID: LongWord;
  ChunkLen: LongWord;
  I: Integer;
begin
  Result := False;
  FillChar(MIDI, SizeOf(MIDI), 0);

  if (InBuf = nil) or (InSize < 14) then Exit;

  // MThd header
  ChunkID := ReadBE32(InBuf, 0);
  if ChunkID <> $4D546864 then Exit; // 'MThd'
  ChunkLen := ReadBE32(InBuf, 4);
  if ChunkLen < 6 then Exit;

  MIDI.Format := ReadBE16(InBuf, 8);
  MIDI.TrackCount := ReadBE16(InBuf, 10);
  MIDI.TicksPerQN := ReadBE16(InBuf, 12);

  if MIDI.TrackCount > MAX_MIDI_TRACKS then
    MIDI.TrackCount := MAX_MIDI_TRACKS;

  SetLength(MIDI.Tracks, MIDI.TrackCount);
  Pos := 8 + ChunkLen;

  // Parse tracks
  for I := 0 to MIDI.TrackCount - 1 do
  begin
    if Pos + 8 > InSize then Break;
    ChunkID := ReadBE32(InBuf, Pos);
    ChunkLen := ReadBE32(InBuf, Pos + 4);
    Inc(Pos, 8);

    if ChunkID = $4D54726B then // 'MTrk'
    begin
      if Pos + ChunkLen <= InSize then
        ParseTrack(InBuf, Pos, ChunkLen, MIDI.Tracks[I]);
    end;

    Inc(Pos, ChunkLen);
  end;

  MIDI.Valid := True;
  Result := True;
end;

function MIDILoadStream(AStream: TStream; out MIDI: TMIDIFile): Boolean;
var
  Buf: PByte;
  Size: LongWord;
begin
  Size := AStream.Size - AStream.Position;
  GetMem(Buf, Size);
  try
    AStream.ReadBuffer(Buf^, Size);
    Result := MIDILoadMem(Buf, Size, MIDI);
  finally
    FreeMem(Buf);
  end;
end;

function MIDILoadFile(const FileName: string; out MIDI: TMIDIFile): Boolean;
var
  F: TFileStream;
begin
  Result := False;
  FillChar(MIDI, SizeOf(MIDI), 0);
  if not FileExists(FileName) then Exit;
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    Result := MIDILoadStream(F, MIDI);
  finally
    F.Free;
  end;
end;

procedure MIDIFree(var MIDI: TMIDIFile);
var
  I: Integer;
  J: LongWord;
begin
  for I := 0 to Length(MIDI.Tracks) - 1 do
    for J := 0 to MIDI.Tracks[I].EventCount - 1 do
      if MIDI.Tracks[I].Events[J].MetaData <> nil then
        FreeMem(MIDI.Tracks[I].Events[J].MetaData);
  SetLength(MIDI.Tracks, 0);
  MIDI.Valid := False;
end;

function MIDITempoToBPM(const Event: TMIDIEvent): Double;
var
  MicroPerQN: LongWord;
begin
  Result := 120.0; // default
  if (Event.EventType = metMeta) and (Event.MetaType = $51) and
     (Event.MetaLen >= 3) and (Event.MetaData <> nil) then
  begin
    MicroPerQN := (LongWord(Event.MetaData[0]) shl 16) or
                  (LongWord(Event.MetaData[1]) shl 8) or
                  Event.MetaData[2];
    if MicroPerQN > 0 then
      Result := 60000000.0 / MicroPerQN;
  end;
end;

function MIDINoteName(Note: Byte): string;
const
  Names: array[0..11] of string = (
    'C','C#','D','D#','E','F','F#','G','G#','A','A#','B');
begin
  Result := Names[Note mod 12] + IntToStr(Note div 12 - 1);
end;

end.

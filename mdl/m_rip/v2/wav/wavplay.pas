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
{ Cross-Platform WAV Player — Pure Pascal
  Plays WAV files on all supported platforms using native APIs.
  Uses pcmdec.pas for WAV decoding where needed.

  Platforms:
    Win32:   winmm.dll sndPlaySound (sync + async)
    Linux:   aplay (ALSA) or paplay (PulseAudio) subprocess
    FreeBSD: aplay or sox play subprocess
    Darwin:  afplay subprocess
    DOS:     Sound Blaster DSP/DMA via dosplay.pas
    OS/2:    MMPM/2 mciSendString via MDM.DLL
}
unit WavPlay;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, PCMDec
  {$IFDEF GO32V2}, DOSPlay{$ENDIF};

{ Play WAV file — blocks until done }
function PlayWAV(const FileName: string): Boolean;

{ Play WAV file — returns immediately (platforms with async support) }
function PlayWAVAsync(const FileName: string): Boolean;

{ Stop any active playback }
procedure StopWAV;

{ Play raw PCM buffer as WAV }
function PlayPCMBuffer(Data: PByte; Size: LongWord;
  SampleRate: LongWord; BitsPerSample, Channels: Word): Boolean;

{ Check if audio playback is available on this platform }
function AudioAvailable: Boolean;

implementation

{ Helper: write PCM data as a temporary WAV file }
function WriteTempWAV(Data: PByte; Size: LongWord;
  SampleRate: LongWord; BitsPerSample, Channels: Word): string;
var
  F: TFileStream;
  Hdr: array[0..43] of Byte;
  BlockAlign: Word;
  ByteRate, DataSize, ChunkSize: LongWord;
begin
  {$IFDEF WINDOWS}
  Result := GetEnvironmentVariable('TEMP') + '\fpc_wav_' + IntToStr(GetProcessID) + '.wav';
  {$ELSE}
  {$IFDEF GO32V2}
  Result := 'C:\TEMP\FPCWAV.WAV';
  {$ELSE}
  Result := '/tmp/fpc_wav_' + IntToStr(GetProcessID) + '.wav';
  {$ENDIF}
  {$ENDIF}

  BlockAlign := Channels * (BitsPerSample div 8);
  ByteRate := SampleRate * LongWord(BlockAlign);
  DataSize := Size;
  ChunkSize := 36 + DataSize;

  FillChar(Hdr, SizeOf(Hdr), 0);
  // RIFF header
  Hdr[0] := Ord('R'); Hdr[1] := Ord('I'); Hdr[2] := Ord('F'); Hdr[3] := Ord('F');
  PLongWord(@Hdr[4])^ := ChunkSize;
  Hdr[8] := Ord('W'); Hdr[9] := Ord('A'); Hdr[10] := Ord('V'); Hdr[11] := Ord('E');
  // fmt chunk
  Hdr[12] := Ord('f'); Hdr[13] := Ord('m'); Hdr[14] := Ord('t'); Hdr[15] := Ord(' ');
  PLongWord(@Hdr[16])^ := 16;
  PWord(@Hdr[20])^ := 1; // PCM
  PWord(@Hdr[22])^ := Channels;
  PLongWord(@Hdr[24])^ := SampleRate;
  PLongWord(@Hdr[28])^ := ByteRate;
  PWord(@Hdr[32])^ := BlockAlign;
  PWord(@Hdr[34])^ := BitsPerSample;
  // data chunk
  Hdr[36] := Ord('d'); Hdr[37] := Ord('a'); Hdr[38] := Ord('t'); Hdr[39] := Ord('a');
  PLongWord(@Hdr[40])^ := DataSize;

  F := TFileStream.Create(Result, fmCreate);
  try
    F.Write(Hdr, 44);
    F.Write(Data^, DataSize);
  finally
    F.Free;
  end;
end;

// ================================================================
// Win32: winmm.dll
// ================================================================
{$IFDEF WINDOWS}

const
  SND_SYNC     = $0000;
  SND_ASYNC    = $0001;
  SND_FILENAME = $00020000;
  SND_MEMORY   = $0004;
  SND_PURGE    = $0040;

function sndPlaySoundA(lpszSound: PChar; fuSound: LongWord): LongBool;
  stdcall; external 'winmm.dll' name 'sndPlaySoundA';

function PlayWAV(const FileName: string): Boolean;
begin
  Result := sndPlaySoundA(PChar(FileName), SND_SYNC or SND_FILENAME);
end;

function PlayWAVAsync(const FileName: string): Boolean;
begin
  Result := sndPlaySoundA(PChar(FileName), SND_ASYNC or SND_FILENAME);
end;

procedure StopWAV;
begin
  sndPlaySoundA(nil, SND_PURGE);
end;

function PlayPCMBuffer(Data: PByte; Size: LongWord;
  SampleRate: LongWord; BitsPerSample, Channels: Word): Boolean;
var
  WAVBuf: PByte;
  WAVSize: LongWord;
  BlockAlign: Word;
  ByteRate: LongWord;
  FmtSize: LongWord;
  FmtTag: Word;
begin
  BlockAlign := Channels * (BitsPerSample div 8);
  ByteRate := SampleRate * BlockAlign;
  WAVSize := 44 + Size;
  GetMem(WAVBuf, WAVSize);
  try
    Move(PChar('RIFF')^, WAVBuf[0], 4);
    PLongWord(@WAVBuf[4])^ := WAVSize - 8;
    Move(PChar('WAVE')^, WAVBuf[8], 4);
    Move(PChar('fmt ')^, WAVBuf[12], 4);
    FmtSize := 16;
    PLongWord(@WAVBuf[16])^ := FmtSize;
    FmtTag := 1;
    PWord(@WAVBuf[20])^ := FmtTag;
    PWord(@WAVBuf[22])^ := Channels;
    PLongWord(@WAVBuf[24])^ := SampleRate;
    PLongWord(@WAVBuf[28])^ := ByteRate;
    PWord(@WAVBuf[32])^ := BlockAlign;
    PWord(@WAVBuf[34])^ := BitsPerSample;
    Move(PChar('data')^, WAVBuf[36], 4);
    PLongWord(@WAVBuf[40])^ := Size;
    Move(Data^, WAVBuf[44], Size);
    Result := sndPlaySoundA(PChar(WAVBuf), SND_SYNC or SND_MEMORY);
  finally
    FreeMem(WAVBuf);
  end;
end;

function AudioAvailable: Boolean;
begin
  Result := True; // winmm.dll always available on Win32
end;

{$ENDIF}

// ================================================================
// Darwin (macOS): afplay
// ================================================================
{$IFDEF DARWIN}

function PlayWAV(const FileName: string): Boolean;
begin
  try
    Result := ExecuteProcess('/usr/bin/afplay', [FileName]) = 0;
  except
    Result := False;
  end;
end;

function PlayWAVAsync(const FileName: string): Boolean;
begin
  try
    Result := ExecuteProcess('/bin/sh', ['-c', '/usr/bin/afplay "' + FileName + '" &']) = 0;
  except
    Result := False;
  end;
end;

procedure StopWAV;
begin
  try
    ExecuteProcess('/usr/bin/killall', ['afplay']);
  except
  end;
end;

function PlayPCMBuffer(Data: PByte; Size: LongWord;
  SampleRate: LongWord; BitsPerSample, Channels: Word): Boolean;
var
  TmpFile: string;
begin
  TmpFile := WriteTempWAV(Data, Size, SampleRate, BitsPerSample, Channels);
  try
    Result := PlayWAV(TmpFile);
  finally
    DeleteFile(TmpFile);
  end;
end;

function AudioAvailable: Boolean;
begin
  Result := FileExists('/usr/bin/afplay');
end;

{$ENDIF}

// ================================================================
// Linux / FreeBSD: aplay (ALSA) or paplay (PulseAudio) or sox
// ================================================================
{$IFDEF UNIX}
{$IFNDEF DARWIN}

function FindPlayer: string;
begin
  if FileExists('/usr/bin/aplay') then
    Result := '/usr/bin/aplay'
  else if FileExists('/usr/bin/paplay') then
    Result := '/usr/bin/paplay'
  else if FileExists('/usr/bin/play') then  // sox
    Result := '/usr/bin/play'
  else if FileExists('/usr/local/bin/aplay') then
    Result := '/usr/local/bin/aplay'
  else
    Result := '';
end;

function PlayWAV(const FileName: string): Boolean;
var
  Player: string;
begin
  Result := False;
  Player := FindPlayer;
  if Player = '' then Exit;
  try
    if Pos('paplay', Player) > 0 then
      Result := ExecuteProcess(Player, [FileName]) = 0
    else
      Result := ExecuteProcess(Player, ['-q', FileName]) = 0;
  except
    Result := False;
  end;
end;

function PlayWAVAsync(const FileName: string): Boolean;
var
  Player: string;
begin
  Result := False;
  Player := FindPlayer;
  if Player = '' then Exit;
  try
    Result := ExecuteProcess('/bin/sh', ['-c', Player + ' "' + FileName + '" &']) = 0;
  except
    Result := False;
  end;
end;

procedure StopWAV;
var
  Player: string;
begin
  Player := FindPlayer;
  if Player = '' then Exit;
  try
    ExecuteProcess('/usr/bin/killall', [ExtractFileName(Player)]);
  except
  end;
end;

function PlayPCMBuffer(Data: PByte; Size: LongWord;
  SampleRate: LongWord; BitsPerSample, Channels: Word): Boolean;
var
  TmpFile: string;
begin
  TmpFile := WriteTempWAV(Data, Size, SampleRate, BitsPerSample, Channels);
  try
    Result := PlayWAV(TmpFile);
  finally
    DeleteFile(TmpFile);
  end;
end;

function AudioAvailable: Boolean;
begin
  Result := FindPlayer <> '';
end;

{$ENDIF}
{$ENDIF}

// ================================================================
// DOS (go32v2): Sound Blaster via dosplay.pas
// ================================================================
{$IFDEF GO32V2}

function PlayWAV(const FileName: string): Boolean;
var
  WAV: TWAVInfo;
begin
  Result := False;
  if not WAVLoadFile(FileName, WAV) then Exit;
  try
    if not SB_Init then Exit;
    try
      SB_PlayPCM(WAV.Data, WAV.DataSize, WAV.SampleRate,
                  WAV.BitsPerSample, WAV.Channels);
      SB_WaitDone;
    finally
      SB_Done;
    end;
    Result := True;
  finally
    WAVFree(WAV);
  end;
end;

function PlayWAVAsync(const FileName: string): Boolean;
begin
  Result := PlayWAV(FileName); // DOS is single-threaded
end;

procedure StopWAV;
begin
  if SB.Detected then SB_Stop;
end;

function PlayPCMBuffer(Data: PByte; Size: LongWord;
  SampleRate: LongWord; BitsPerSample, Channels: Word): Boolean;
begin
  Result := False;
  if not SB_Init then Exit;
  try
    SB_PlayPCM(Data, Size, SampleRate, BitsPerSample, Channels);
    SB_WaitDone;
  finally
    SB_Done;
  end;
  Result := True;
end;

function AudioAvailable: Boolean;
begin
  Result := SB_Init;
  if Result then SB_Done;
end;

{$ENDIF}

// ================================================================
// OS/2: MMPM/2 via mciSendString (MDM.DLL)
// ================================================================
{$IFDEF OS2}

type
  MRESULT = LongWord;

function mciSendString(lpszCommand: PChar; lpszReturnString: PChar;
  cchReturn: Word; hwndCallback: LongWord): MRESULT;
  cdecl; external 'MDM' name 'mciSendString';

function PlayWAV(const FileName: string): Boolean;
var
  Cmd: string;
  Ret: MRESULT;
begin
  // Open the WAV file
  Cmd := 'open "' + FileName + '" type waveaudio alias fpcwav wait';
  Ret := mciSendString(PChar(Cmd), nil, 0, 0);
  if Ret <> 0 then
  begin
    Result := False;
    Exit;
  end;
  // Play and wait
  Ret := mciSendString('play fpcwav wait', nil, 0, 0);
  // Close
  mciSendString('close fpcwav', nil, 0, 0);
  Result := Ret = 0;
end;

function PlayWAVAsync(const FileName: string): Boolean;
var
  Cmd: string;
  Ret: MRESULT;
begin
  Cmd := 'open "' + FileName + '" type waveaudio alias fpcwav wait';
  Ret := mciSendString(PChar(Cmd), nil, 0, 0);
  if Ret <> 0 then
  begin
    Result := False;
    Exit;
  end;
  // Play without wait
  Ret := mciSendString('play fpcwav', nil, 0, 0);
  Result := Ret = 0;
end;

procedure StopWAV;
begin
  mciSendString('stop fpcwav', nil, 0, 0);
  mciSendString('close fpcwav', nil, 0, 0);
end;

function PlayPCMBuffer(Data: PByte; Size: LongWord;
  SampleRate: LongWord; BitsPerSample, Channels: Word): Boolean;
var
  TmpFile: string;
begin
  TmpFile := WriteTempWAV(Data, Size, SampleRate, BitsPerSample, Channels);
  try
    Result := PlayWAV(TmpFile);
  finally
    DeleteFile(TmpFile);
  end;
end;

function AudioAvailable: Boolean;
begin
  // MMPM/2 installed if MDM.DLL loaded
  Result := True;
end;

{$ENDIF}

end.

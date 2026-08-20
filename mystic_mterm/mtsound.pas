{ This file is part of mterm — Mystic Terminal.
  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench. }
{$H+}
Unit mtsound;
{ SDL_mixer audio playback for RIP |1S Sound command.
  Supports WAV, MID, MOD, MP3, OGG via SDL_mixer 1.2.
  Degrade gracefully if mixer init fails — no crash, just silence. }

Interface

Procedure SoundInit;
Procedure SoundShutdown;
Procedure SoundPlay(Const FileName: String);
Procedure SoundStop;
Function  SoundReady: Boolean;

Implementation

Uses SysUtils, SDL, SDL_mixer;

Var
  MixerReady : Boolean;
  CurrentMus : PMix_Music;
  CurrentSfx : PMix_Chunk;

Procedure SoundInit;
Begin
  MixerReady := False;
  CurrentMus := Nil;
  CurrentSfx := Nil;

  { Init SDL audio subsystem if not already }
  If (SDL_WasInit(SDL_INIT_AUDIO) = 0) Then
    If SDL_InitSubSystem(SDL_INIT_AUDIO) <> 0 Then Exit;

  { Open mixer: 22050 Hz, signed 16-bit, stereo, 1024 sample buffer }
  If Mix_OpenAudio(22050, AUDIO_S16SYS, 2, 1024) < 0 Then Exit;

  { Allocate 4 mixing channels }
  Mix_AllocateChannels(4);

  MixerReady := True;
End;

Procedure SoundShutdown;
Begin
  SoundStop;
  If MixerReady Then Begin
    Mix_CloseAudio;
    MixerReady := False;
  End;
End;

Procedure SoundStop;
Begin
  If Not MixerReady Then Exit;

  { Stop all channels }
  Mix_HaltChannel(-1);
  Mix_HaltMusic;

  { Free current music/sfx }
  If CurrentMus <> Nil Then Begin
    Mix_FreeMusic(CurrentMus);
    CurrentMus := Nil;
  End;
  If CurrentSfx <> Nil Then Begin
    Mix_FreeChunk(CurrentSfx);
    CurrentSfx := Nil;
  End;
End;

Procedure SoundPlay(Const FileName: String);
Var
  Ext: String;
Begin
  If Not MixerReady Then Exit;
  If Not FileExists(FileName) Then Exit;

  { Stop any current playback }
  SoundStop;

  { Determine type by extension }
  Ext := UpperCase(ExtractFileExt(FileName));

  If (Ext = '.MID') or (Ext = '.MOD') or (Ext = '.IT') or
     (Ext = '.XM') or (Ext = '.S3M') or (Ext = '.MP3') or
     (Ext = '.OGG') Then Begin
    { Music — streamed, one at a time }
    CurrentMus := Mix_LoadMUS(PChar(FileName));
    If CurrentMus <> Nil Then
      Mix_PlayMusic(CurrentMus, 0);  { play once }
  End Else Begin
    { Default: treat as WAV/PCM chunk }
    CurrentSfx := Mix_LoadWAV(PChar(FileName));
    If CurrentSfx <> Nil Then
      Mix_PlayChannel(-1, CurrentSfx, 0);  { first free channel, play once }
  End;
End;

Function SoundReady: Boolean;
Begin
  Result := MixerReady;
End;

End.

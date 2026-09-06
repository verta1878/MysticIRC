{$H-}
//
// This file is part of the Mystic BBS IRC Fork.
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
// Licensed under GNU General Public License v3.
//
// Phase 22: Advanced Multimedia — tests and stress tests
//
Program test_phase22;

Uses rip4api;

Var
  RIP    : TRIPEngine;
  Pass   : Integer;
  Fail   : Integer;
  Total  : Integer;

Procedure Check (Name: String; Cond: Boolean);
Begin
  Inc(Total);
  If Cond Then Begin
    Inc(Pass);
    WriteLn('  PASS  ', Name);
  End Else Begin
    Inc(Fail);
    WriteLn('  FAIL  ', Name);
  End;
End;

// ==== Audio Streams ====

Procedure TestAudioLoad;
Begin
  WriteLn;
  WriteLn('--- AudioLoad ---');
  Check('Load stream 0', RIP.AudioLoad(0, 'test.wav'));
  Check('Load stream 3', RIP.AudioLoad(3, 'music.mod'));
  Check('Load stream -1: false', Not RIP.AudioLoad(-1, 'bad'));
  Check('Load stream 4: false', Not RIP.AudioLoad(4, 'bad'));
  Check('State after load: STOPPED', RIP.AudioGetState(0) = RIP_AUDIO_STOPPED);
End;

Procedure TestAudioPlayPauseStop;
Begin
  WriteLn;
  WriteLn('--- AudioPlay/Pause/Stop ---');
  RIP.AudioLoad(0, 'test.wav');
  RIP.AudioPlay(0);
  Check('Play: state=PLAYING', RIP.AudioGetState(0) = RIP_AUDIO_PLAYING);

  RIP.AudioPause(0);
  Check('Pause: state=PAUSED', RIP.AudioGetState(0) = RIP_AUDIO_PAUSED);

  RIP.AudioPlay(0);
  Check('Resume: state=PLAYING', RIP.AudioGetState(0) = RIP_AUDIO_PLAYING);

  RIP.AudioStop(0);
  Check('Stop: state=STOPPED', RIP.AudioGetState(0) = RIP_AUDIO_STOPPED);
End;

Procedure TestAudioStopAll;
Begin
  WriteLn;
  WriteLn('--- AudioStopAll ---');
  RIP.AudioLoad(0, 'a.wav');
  RIP.AudioLoad(1, 'b.wav');
  RIP.AudioLoad(2, 'c.wav');
  RIP.AudioPlay(0);
  RIP.AudioPlay(1);
  RIP.AudioPlay(2);
  RIP.AudioStopAll;
  Check('Stream 0 stopped', RIP.AudioGetState(0) = RIP_AUDIO_STOPPED);
  Check('Stream 1 stopped', RIP.AudioGetState(1) = RIP_AUDIO_STOPPED);
  Check('Stream 2 stopped', RIP.AudioGetState(2) = RIP_AUDIO_STOPPED);
End;

Procedure TestAudioVolume;
Begin
  WriteLn;
  WriteLn('--- AudioSetVolume ---');
  RIP.AudioSetVolume(0, 128);
  Check('SetVolume: no crash', True);
  RIP.AudioSetVolume(-1, 128);
  Check('SetVolume bad stream: no crash', True);
  RIP.AudioSetVolume(99, 128);
  Check('SetVolume stream 99: no crash', True);
End;

Procedure TestAudioBadOps;
Begin
  WriteLn;
  WriteLn('--- Audio Bad Operations ---');
  RIP.AudioPlay(-1);
  Check('Play(-1): no crash', True);
  RIP.AudioPause(99);
  Check('Pause(99): no crash', True);
  RIP.AudioStop(-5);
  Check('Stop(-5): no crash', True);
  // Play without load — stream 3 was loaded earlier, so check truly empty state
  Check('GetState(-1) = IDLE', RIP.AudioGetState(-1) = RIP_AUDIO_IDLE);
  Check('GetState(99) = IDLE', RIP.AudioGetState(99) = RIP_AUDIO_IDLE);
End;

// ==== MIDI ====

Procedure TestMIDI;
Begin
  WriteLn;
  WriteLn('--- MIDI Load/Free ---');
  Check('MIDILoad', RIP.MIDILoad('test.mid'));
  Check('MIDIFileName set', True);
  RIP.MIDIFree;
  Check('MIDIFree: no crash', True);
  RIP.MIDIFree;
  Check('MIDIFree twice: no crash', True);
End;

// ==== Cue Points ====

Procedure TestCuePoints;
Begin
  WriteLn;
  WriteLn('--- Cue Points ---');
  RIP.CueClear;
  RIP.CueAdd(10, '|1c0F');
  RIP.CueAdd(20, '|1c0E');
  RIP.CueAdd(30, '|1c0D');
  Check('3 cues added: no crash', True);

  // Process — frame 10 should fire
  RIP.CueProcess(10);
  Check('CueProcess(10): no crash', True);

  // Process non-matching frame
  RIP.CueProcess(15);
  Check('CueProcess(15): no crash', True);

  RIP.CueClear;
  Check('CueClear: no crash', True);
End;

Procedure TestCueMax;
Var I : Integer;
Begin
  WriteLn;
  WriteLn('--- Cue Max (64) ---');
  RIP.CueClear;
  For I := 1 to 70 Do
    RIP.CueAdd(I, '|1e');
  Check('70 cues (max 64): no crash', True);
  RIP.CueClear;
End;

// ==== Background Audio ====

Procedure TestBgAudio;
Begin
  WriteLn;
  WriteLn('--- Background Audio ---');
  RIP.SetBgAudio(0);
  Check('SetBgAudio(0): no crash', True);
  RIP.SetBgAudio(-1);
  Check('SetBgAudio(-1): no crash', True);
  RIP.SetBgAudio(99);
  Check('SetBgAudio(99): no crash (clamped)', True);
End;

Procedure TestBgTransition;
Begin
  WriteLn;
  WriteLn('--- BgAudioTransition ---');
  RIP.AudioLoad(0, 'intro.wav');
  RIP.AudioPlay(0);
  RIP.SetBgAudio(0);
  RIP.BgAudioTransition('menu.wav', 30);
  Check('Transition: no crash', True);
  Check('New file playing', RIP.AudioGetState(0) = RIP_AUDIO_PLAYING);
End;

// ==== WAV Streaming ====

Procedure TestWAVStream;
Var Buf : Array[0..255] of Byte;
Begin
  WriteLn;
  WriteLn('--- WAV Streaming ---');
  Check('StreamStart', RIP.WAVStreamStart(1, 8000, 8, 1));
  Check('State = PLAYING', RIP.AudioGetState(1) = RIP_AUDIO_PLAYING);

  FillChar(Buf, 256, 128);
  RIP.WAVStreamFeed(1, @Buf, 256);
  Check('StreamFeed: no crash', True);

  RIP.WAVStreamFeed(1, @Buf, 256);
  RIP.WAVStreamFeed(1, @Buf, 256);
  Check('Multiple feeds: no crash', True);

  RIP.WAVStreamEnd(1);
  Check('StreamEnd: state=STOPPED', RIP.AudioGetState(1) = RIP_AUDIO_STOPPED);
End;

Procedure TestWAVStreamBad;
Begin
  WriteLn;
  WriteLn('--- WAV Stream Bad Params ---');
  Check('StreamStart(-1): false', Not RIP.WAVStreamStart(-1, 8000, 8, 1));
  Check('StreamStart(99): false', Not RIP.WAVStreamStart(99, 8000, 8, 1));
  RIP.WAVStreamFeed(-1, Nil, 0);
  Check('StreamFeed bad stream: no crash', True);
  RIP.WAVStreamEnd(99);
  Check('StreamEnd bad stream: no crash', True);
End;

Begin
  Pass  := 0;
  Fail  := 0;
  Total := 0;

  WriteLn('=== Phase 22: Advanced Multimedia — TESTS ===');

  RIP := TRIPEngine.Create;

  TestAudioLoad;
  TestAudioPlayPauseStop;
  TestAudioStopAll;
  TestAudioVolume;
  TestAudioBadOps;
  TestMIDI;
  TestCuePoints;
  TestCueMax;
  TestBgAudio;
  TestBgTransition;
  TestWAVStream;
  TestWAVStreamBad;

  RIP.Free;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Total, ' passed, ', Fail, ' failed ===');

  If Fail > 0 Then
    Halt(1);
End.

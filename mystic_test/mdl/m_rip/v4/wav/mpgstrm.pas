(* mpgstrm.pas -- MPEG Streaming A/V Playback
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Synchronized audio+video streaming from MPEG system streams.
   Feeds audio to audstrm, video frames via callback.
   PTS-based A/V sync.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit mpgstrm;

interface

uses mpgdemux, mpgvdec, mpgvbuf;

type
  TMPGStreamFrameCB = procedure(RGB: PByte; Width, Height: Word;
    PTS: Int64; UserData: Pointer);

  TMPGStreamState = record
    Demux: TMPGDemuxer;
    Video: TMPGVideoDecoder;
    AudioBuf: PByte;
    AudioBufLen: LongInt;
    AudioBufPos: LongInt;
    VideoPTS: Int64;
    AudioPTS: Int64;
    SampleRate: LongWord;
    FrameCB: TMPGStreamFrameCB;
    UserData: Pointer;
    Playing: Boolean;
    Done: Boolean;
  end;

{ Open MPEG file for streaming }
function MPGStreamOpen(var S: TMPGStreamState;
  const FileName: ShortString;
  FrameCB: TMPGStreamFrameCB; UserData: Pointer): Boolean;

{ Pump: process next chunk of A/V data }
function MPGStreamPump(var S: TMPGStreamState): Boolean;

{ Get audio data for playback (feeds audstrm) }
function MPGStreamAudio(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;

{ Status }
function MPGStreamDone(var S: TMPGStreamState): Boolean;
function MPGStreamVideoWidth(var S: TMPGStreamState): Word;
function MPGStreamVideoHeight(var S: TMPGStreamState): Word;
function MPGStreamFrameCount(var S: TMPGStreamState): LongWord;

procedure MPGStreamClose(var S: TMPGStreamState);

implementation

const
  AUDIO_BUF_SIZE = 65536;

procedure DemuxCallback(var Pkt: TMPGPacket; UserData: Pointer);
var
  S: ^TMPGStreamState;
begin
  S := UserData;

  case Pkt.StreamType of
    mstVideo:
    begin
      { Feed video elementary stream to decoder }
      if Pkt.HasPTS then S^.VideoPTS := Pkt.PTS;
      MPGVideoDecode(S^.Video, Pkt.Data, Pkt.DataLen, nil, nil);
    end;
    mstAudio:
    begin
      { Buffer audio data }
      if Pkt.HasPTS then S^.AudioPTS := Pkt.PTS;
      if S^.AudioBufPos + LongInt(Pkt.DataLen) <= AUDIO_BUF_SIZE then
      begin
        Move(Pkt.Data^, S^.AudioBuf[S^.AudioBufPos], Pkt.DataLen);
        Inc(S^.AudioBufPos, Pkt.DataLen);
      end;
    end;
  end;
end;

procedure VideoFrameCB(var Frame: TMPGFrame; UserData: Pointer);
var
  S: ^TMPGStreamState;
begin
  S := UserData;
  if Assigned(S^.FrameCB) then
    S^.FrameCB(Frame.RGB, Frame.Width, Frame.Height,
      S^.VideoPTS, S^.UserData);
end;

function MPGStreamOpen(var S: TMPGStreamState;
  const FileName: ShortString;
  FrameCB: TMPGStreamFrameCB; UserData: Pointer): Boolean;
begin
  Result := False;
  FillChar(S, SizeOf(S), 0);

  MPGDemuxInit(S.Demux, @DemuxCallback, @S);
  if not MPGDemuxLoadFile(S.Demux, FileName) then Exit;

  MPGVideoInit(S.Video);
  S.FrameCB := FrameCB;
  S.UserData := UserData;
  S.SampleRate := 44100;

  GetMem(S.AudioBuf, AUDIO_BUF_SIZE);
  S.AudioBufLen := AUDIO_BUF_SIZE;
  S.AudioBufPos := 0;

  S.Playing := True;
  Result := True;
end;

function MPGStreamPump(var S: TMPGStreamState): Boolean;
begin
  Result := False;
  if S.Done then Exit;

  { Process all packets }
  MPGDemuxProcess(S.Demux);

  { Decode any buffered video with frame callback }
  { Already handled in DemuxCallback → MPGVideoDecode }

  S.Done := True;  { Single-pass for now }
  Result := not S.Done;
end;

function MPGStreamAudio(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;
var
  S: ^TMPGStreamState;
  ToRead: LongInt;
begin
  S := UserData;
  Result := 0;
  if S^.AudioBufPos <= 0 then Exit;

  ToRead := BufSize;
  if ToRead > S^.AudioBufPos then ToRead := S^.AudioBufPos;

  Move(S^.AudioBuf^, Buffer^, ToRead);

  { Shift remaining }
  if ToRead < S^.AudioBufPos then
    Move(S^.AudioBuf[ToRead], S^.AudioBuf^, S^.AudioBufPos - ToRead);
  Dec(S^.AudioBufPos, ToRead);

  Result := ToRead;
end;

function MPGStreamDone(var S: TMPGStreamState): Boolean;
begin Result := S.Done; end;

function MPGStreamVideoWidth(var S: TMPGStreamState): Word;
begin Result := S.Video.Sequence.Width; end;

function MPGStreamVideoHeight(var S: TMPGStreamState): Word;
begin Result := S.Video.Sequence.Height; end;

function MPGStreamFrameCount(var S: TMPGStreamState): LongWord;
begin Result := S.Video.FrameCount; end;

procedure MPGStreamClose(var S: TMPGStreamState);
begin
  MPGVideoFree(S.Video);
  MPGDemuxFree(S.Demux);
  if S.AudioBuf <> nil then begin FreeMem(S.AudioBuf); S.AudioBuf := nil; end;
  S.Playing := False;
end;

end.

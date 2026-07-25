(* mpgplay.pas -- MPEG File Player
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Simple MPEG-1 player: load file, decode all frames,
   deliver via callback. Integrates demuxer + decoder + streaming.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit mpgplay;

interface

uses mpgdemux, mpgvdec, mpgvbuf, mpgstrm;

type
  TMPGPlayerFrameCB = procedure(RGB: PByte; Width, Height: Word;
    FrameNum: LongWord; UserData: Pointer);

  TMPGPlayer = record
    Stream: TMPGStreamState;
    FrameCB: TMPGPlayerFrameCB;
    UserData: Pointer;
    FrameNum: LongWord;
    Width, Height: Word;
    Playing: Boolean;
  end;

{ Load and decode MPEG file, calling back for each frame }
function MPGPlayerPlay(var P: TMPGPlayer;
  const FileName: ShortString;
  FrameCB: TMPGPlayerFrameCB; UserData: Pointer): Boolean;

{ Get frame count after playback }
function MPGPlayerFrames(var P: TMPGPlayer): LongWord;

{ Get video dimensions }
function MPGPlayerWidth(var P: TMPGPlayer): Word;
function MPGPlayerHeight(var P: TMPGPlayer): Word;

procedure MPGPlayerFree(var P: TMPGPlayer);

implementation

procedure PlayerFrameAdapter(RGB: PByte; Width, Height: Word;
  PTS: Int64; UserData: Pointer);
var
  P: ^TMPGPlayer;
begin
  P := UserData;
  P^.Width := Width;
  P^.Height := Height;
  if Assigned(P^.FrameCB) then
    P^.FrameCB(RGB, Width, Height, P^.FrameNum, P^.UserData);
  Inc(P^.FrameNum);
end;

function MPGPlayerPlay(var P: TMPGPlayer;
  const FileName: ShortString;
  FrameCB: TMPGPlayerFrameCB; UserData: Pointer): Boolean;
begin
  Result := False;
  FillChar(P, SizeOf(P), 0);
  P.FrameCB := FrameCB;
  P.UserData := UserData;

  if not MPGStreamOpen(P.Stream, FileName,
    @PlayerFrameAdapter, @P) then Exit;

  P.Playing := True;

  { Process entire file }
  MPGStreamPump(P.Stream);

  P.Playing := False;
  Result := P.FrameNum > 0;
end;

function MPGPlayerFrames(var P: TMPGPlayer): LongWord;
begin Result := P.FrameNum; end;

function MPGPlayerWidth(var P: TMPGPlayer): Word;
begin Result := P.Width; end;

function MPGPlayerHeight(var P: TMPGPlayer): Word;
begin Result := P.Height; end;

procedure MPGPlayerFree(var P: TMPGPlayer);
begin
  MPGStreamClose(P.Stream);
  P.Playing := False;
end;

end.

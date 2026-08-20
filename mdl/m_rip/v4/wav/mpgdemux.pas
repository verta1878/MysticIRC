(* mpgdemux.pas -- MPEG-1 System Stream Demuxer
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Splits .mpg system streams into separate audio and video
   elementary streams. Handles pack headers, system headers,
   PES packets. Feeds audio to mp3dec and video to mpgvdec.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit mpgdemux;

interface

const
  MPG_PACK_START    = $000001BA;
  MPG_SYS_START     = $000001BB;
  MPG_VIDEO_STREAM  = $E0;
  MPG_AUDIO_STREAM  = $C0;
  MPG_END_CODE      = $000001B9;
  MPG_MAX_PACKET    = 65536;

type
  TMPGStreamType = (mstVideo, mstAudio, mstUnknown);

  TMPGPacket = record
    StreamID: Byte;
    StreamType: TMPGStreamType;
    Data: PByte;
    DataLen: LongWord;
    PTS: Int64;          { Presentation timestamp, 90kHz clock }
    DTS: Int64;          { Decode timestamp }
    HasPTS: Boolean;
    HasDTS: Boolean;
  end;

  TMPGDemuxCallback = procedure(var Pkt: TMPGPacket; UserData: Pointer);

  TMPGDemuxer = record
    Data: PByte;
    DataLen: LongInt;
    Pos: LongInt;
    OnPacket: TMPGDemuxCallback;
    UserData: Pointer;
    VideoPkts: LongWord;
    AudioPkts: LongWord;
    MuxRate: LongWord;     { bytes per second }
    Duration: Int64;       { estimated, in 90kHz ticks }
  end;

procedure MPGDemuxInit(var D: TMPGDemuxer;
  Callback: TMPGDemuxCallback; UserData: Pointer);
function MPGDemuxLoadFile(var D: TMPGDemuxer;
  const FileName: ShortString): Boolean;
function MPGDemuxLoadMem(var D: TMPGDemuxer;
  Src: PByte; SrcLen: LongInt): Boolean;
procedure MPGDemuxProcess(var D: TMPGDemuxer);
procedure MPGDemuxFree(var D: TMPGDemuxer);

{ Read next start code from stream }
function MPGFindStartCode(Data: PByte; Len: LongInt; var Pos: LongInt): LongWord;

implementation

function RB32(P: PByte): LongWord;
begin
  Result := (LongWord(P[0]) shl 24) or (LongWord(P[1]) shl 16) or
            (LongWord(P[2]) shl 8) or P[3];
end;

function RB16(P: PByte): Word;
begin
  Result := (Word(P[0]) shl 8) or P[1];
end;

function ReadPTS(P: PByte): Int64;
begin
  { PTS is 33 bits encoded across 5 bytes:
    [4bits] 1 [15bits] 1 [15bits] 1 }
  Result := Int64(P[0] and $0E) shl 29;
  Result := Result or (Int64(RB16(@P[1])) shr 1) shl 15;
  Result := Result or (Int64(RB16(@P[3])) shr 1);
end;

function MPGFindStartCode(Data: PByte; Len: LongInt; var Pos: LongInt): LongWord;
begin
  Result := 0;
  while Pos + 3 < Len do
  begin
    if (Data[Pos] = 0) and (Data[Pos + 1] = 0) and (Data[Pos + 2] = 1) then
    begin
      Result := $00000100 or Data[Pos + 3];
      Exit;
    end;
    Inc(Pos);
  end;
end;

procedure MPGDemuxInit(var D: TMPGDemuxer;
  Callback: TMPGDemuxCallback; UserData: Pointer);
begin
  FillChar(D, SizeOf(D), 0);
  D.OnPacket := Callback;
  D.UserData := UserData;
end;

function MPGDemuxLoadFile(var D: TMPGDemuxer;
  const FileName: ShortString): Boolean;
var
  F: File; FS, BR: LongInt;
begin
  Result := False;
  Assign(F, FileName); {$I-} Reset(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  FS := System.FileSize(F);
  GetMem(D.Data, FS);
  BlockRead(F, D.Data^, FS, BR);
  Close(F);
  if BR <> FS then begin FreeMem(D.Data); D.Data := nil; Exit; end;
  D.DataLen := FS;
  D.Pos := 0;
  Result := True;
end;

function MPGDemuxLoadMem(var D: TMPGDemuxer;
  Src: PByte; SrcLen: LongInt): Boolean;
begin
  GetMem(D.Data, SrcLen);
  Move(Src^, D.Data^, SrcLen);
  D.DataLen := SrcLen;
  D.Pos := 0;
  Result := True;
end;

procedure MPGDemuxProcess(var D: TMPGDemuxer);
var
  Code: LongWord;
  PktLen: Word;
  StreamID: Byte;
  Pkt: TMPGPacket;
  StuffLen: Integer;
  HdrLen: Integer;
begin
  while D.Pos + 4 < D.DataLen do
  begin
    Code := MPGFindStartCode(D.Data, D.DataLen, D.Pos);
    if Code = 0 then Exit;

    case Code of
      MPG_PACK_START:
      begin
        { Pack header: skip timing info }
        Inc(D.Pos, 4); { past start code }
        if D.Pos + 8 > D.DataLen then Exit;

        { Check MPEG-1 vs MPEG-2 }
        if (D.Data[D.Pos] and $F0) = $20 then
        begin
          { MPEG-1: 12 bytes }
          D.MuxRate := ((LongWord(D.Data[D.Pos + 5]) and $7F) shl 15) or
                       (LongWord(D.Data[D.Pos + 6]) shl 7) or
                       (D.Data[D.Pos + 7] shr 1);
          Inc(D.Pos, 8);
        end
        else
        begin
          { MPEG-2: 14+ bytes }
          Inc(D.Pos, 10);
          if D.Pos < D.DataLen then
          begin
            StuffLen := D.Data[D.Pos] and $07;
            Inc(D.Pos, 1 + StuffLen);
          end;
        end;
      end;

      MPG_SYS_START:
      begin
        Inc(D.Pos, 4);
        if D.Pos + 2 > D.DataLen then Exit;
        PktLen := RB16(@D.Data[D.Pos]);
        Inc(D.Pos, 2 + PktLen);
      end;

      MPG_END_CODE:
        Exit;

    else
      { PES packet }
      StreamID := Code and $FF;
      Inc(D.Pos, 4);
      if D.Pos + 2 > D.DataLen then Exit;
      PktLen := RB16(@D.Data[D.Pos]);
      Inc(D.Pos, 2);

      if D.Pos + PktLen > D.DataLen then
        PktLen := D.DataLen - D.Pos;

      if (StreamID >= $C0) and (StreamID <= $EF) then
      begin
        FillChar(Pkt, SizeOf(Pkt), 0);
        Pkt.StreamID := StreamID;

        if (StreamID and $F0) = $E0 then
          Pkt.StreamType := mstVideo
        else if (StreamID and $F0) = $C0 then
          Pkt.StreamType := mstAudio
        else
          Pkt.StreamType := mstUnknown;

        { Skip stuffing bytes (0xFF) }
        HdrLen := 0;
        while (HdrLen < PktLen) and (D.Data[D.Pos + HdrLen] = $FF) do
          Inc(HdrLen);

        { Check for PTS }
        if (HdrLen < PktLen) and ((D.Data[D.Pos + HdrLen] and $C0) = $80) then
        begin
          { MPEG-2 PES header }
          if HdrLen + 3 < Integer(PktLen) then
          begin
            if (D.Data[D.Pos + HdrLen + 1] and $C0) >= $80 then
            begin
              Pkt.HasPTS := True;
              if HdrLen + 8 < Integer(PktLen) then
                Pkt.PTS := ReadPTS(@D.Data[D.Pos + HdrLen + 3]);
            end;
            HdrLen := HdrLen + 3 + D.Data[D.Pos + HdrLen + 2];
          end;
        end
        else if (HdrLen < PktLen) and ((D.Data[D.Pos + HdrLen] and $F0) = $20) then
        begin
          { MPEG-1 PTS }
          Pkt.HasPTS := True;
          if HdrLen + 5 <= Integer(PktLen) then
            Pkt.PTS := ReadPTS(@D.Data[D.Pos + HdrLen]);
          Inc(HdrLen, 5);
        end
        else if (HdrLen < PktLen) and (D.Data[D.Pos + HdrLen] = $0F) then
          Inc(HdrLen, 1);

        Pkt.Data := @D.Data[D.Pos + HdrLen];
        Pkt.DataLen := PktLen - HdrLen;

        if Pkt.StreamType = mstVideo then Inc(D.VideoPkts);
        if Pkt.StreamType = mstAudio then Inc(D.AudioPkts);

        if Assigned(D.OnPacket) then
          D.OnPacket(Pkt, D.UserData);
      end;

      Inc(D.Pos, PktLen);
    end;
  end;
end;

procedure MPGDemuxFree(var D: TMPGDemuxer);
begin
  if D.Data <> nil then begin FreeMem(D.Data); D.Data := nil; end;
  D.DataLen := 0;
end;

end.

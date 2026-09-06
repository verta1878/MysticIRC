(* netaudio.pas -- Network Audio Streaming
   Copyright (C) 2026 fpc264irc contributors. License: GPLv3

   Audio streaming over TCP/telnet connections for BBS audio.
   Encodes PCM to compact stream format for transmission.
   Protocol: [SYNC:2][LEN:2][PCM data] per packet.
*)
{$MODE DELPHI}
{$H-}
{$R-}
{$Q-}

unit netaudio;

interface

uses audstrm;

const
  NET_AUDIO_SYNC = $A5A5;
  NET_AUDIO_PACKET_SIZE = 1024;

type
  TNetAudioPacket = record
    Sync: Word;
    DataLen: Word;
    Data: array[0..NET_AUDIO_PACKET_SIZE - 1] of Byte;
  end;

  TNetAudioEncoder = record
    Format: TAudioFormat;
    PacketCount: LongWord;
  end;

  TNetAudioDecoder = record
    Format: TAudioFormat;
    Buffer: array[0..NET_AUDIO_PACKET_SIZE * 4 - 1] of Byte;
    BufLen: LongInt;
    BufPos: LongInt;
    PacketCount: LongWord;
    SyncState: Byte;
  end;

{ Encoder: PCM -> network packets }
procedure NetAudioEncInit(var E: TNetAudioEncoder; var Fmt: TAudioFormat);
function NetAudioEncPacket(var E: TNetAudioEncoder;
  PCMData: PByte; PCMLen: LongInt;
  out Pkt: TNetAudioPacket): Boolean;

{ Decoder: network bytes -> PCM }
procedure NetAudioDecInit(var D: TNetAudioDecoder; var Fmt: TAudioFormat);
procedure NetAudioDecFeed(var D: TNetAudioDecoder;
  Data: PByte; Len: LongInt);
function NetAudioDecRead(var D: TNetAudioDecoder;
  Buffer: PByte; BufSize: LongInt): LongInt;

{ Streaming callback for audstrm.pas }
function NetAudioStreamDecode(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;

implementation

procedure NetAudioEncInit(var E: TNetAudioEncoder; var Fmt: TAudioFormat);
begin
  FillChar(E, SizeOf(E), 0);
  E.Format := Fmt;
end;

function NetAudioEncPacket(var E: TNetAudioEncoder;
  PCMData: PByte; PCMLen: LongInt;
  out Pkt: TNetAudioPacket): Boolean;
begin
  Result := False;
  if PCMLen <= 0 then Exit;
  if PCMLen > NET_AUDIO_PACKET_SIZE then PCMLen := NET_AUDIO_PACKET_SIZE;

  Pkt.Sync := NET_AUDIO_SYNC;
  Pkt.DataLen := PCMLen;
  Move(PCMData^, Pkt.Data[0], PCMLen);
  Inc(E.PacketCount);
  Result := True;
end;

procedure NetAudioDecInit(var D: TNetAudioDecoder; var Fmt: TAudioFormat);
begin
  FillChar(D, SizeOf(D), 0);
  D.Format := Fmt;
end;

procedure NetAudioDecFeed(var D: TNetAudioDecoder;
  Data: PByte; Len: LongInt);
var
  I: LongInt;
  PktLen: Word;
begin
  for I := 0 to Len - 1 do
  begin
    case D.SyncState of
      0: if Data[I] = $A5 then D.SyncState := 1;
      1: if Data[I] = $A5 then D.SyncState := 2 else D.SyncState := 0;
      2: begin D.BufLen := Data[I]; D.SyncState := 3; end;
      3: begin
        D.BufLen := D.BufLen or (Word(Data[I]) shl 8);
        if D.BufLen > NET_AUDIO_PACKET_SIZE then D.BufLen := NET_AUDIO_PACKET_SIZE;
        D.BufPos := 0;
        D.SyncState := 4;
      end;
      4: begin
        D.Buffer[D.BufPos] := Data[I];
        Inc(D.BufPos);
        if D.BufPos >= D.BufLen then
        begin
          Inc(D.PacketCount);
          D.SyncState := 0;
        end;
      end;
    end;
  end;
end;

function NetAudioDecRead(var D: TNetAudioDecoder;
  Buffer: PByte; BufSize: LongInt): LongInt;
var
  ToRead: LongInt;
begin
  ToRead := D.BufLen;
  if ToRead > BufSize then ToRead := BufSize;
  if ToRead > 0 then
    Move(D.Buffer[0], Buffer^, ToRead);
  Result := ToRead;
end;

function NetAudioStreamDecode(Buffer: PByte; BufSize: LongInt;
  UserData: Pointer): LongInt;
begin
  Result := NetAudioDecRead(TNetAudioDecoder(UserData^), Buffer, BufSize);
end;

end.

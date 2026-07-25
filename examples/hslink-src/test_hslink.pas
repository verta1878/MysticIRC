// ====================================================================
// HS/Link Loopback Test
// Mystic BBS IRC Fork — GPLv3
// ====================================================================
//
// This file is part of the Mystic BBS IRC Fork.
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Tests packet build/parse, CRC, encode/decode, file header
// No real connection — exercises the protocol engine internally
// ====================================================================
Program test_hslink;

Uses
  m_io_Base,
  m_Protocol_Base,
  m_Protocol_Queue,
  m_protocol_hslink;

Var
  HS       : TProtocolHSLink;
  Pass     : Integer;
  Fail     : Integer;
  DummyIO  : TIOBase;
  DummyQ   : TProtocolQueue;

Procedure Check (Name: String; Cond: Boolean);
Begin
  If Cond Then Begin
    WriteLn('  PASS  ', Name);
    Inc(Pass);
  End Else Begin
    WriteLn('  FAIL  ', Name);
    Inc(Fail);
  End;
End;

// --- CRC Tests ---
Procedure TestCRC;
Var
  Buf  : Array[0..15] of Byte;
  CRC1 : LongInt;
  CRC2 : LongInt;
Begin
  WriteLn;
  WriteLn('--- CRC-24 ---');

  // Known data
  Buf[0] := $48; // H
  Buf[1] := $65; // e
  Buf[2] := $6C; // l
  Buf[3] := $6C; // l
  Buf[4] := $6F; // o
  CRC1 := HS.CalcCRC24(Buf, 5);
  Check('CRC non-zero', CRC1 <> 0);
  Check('CRC 24-bit', (CRC1 AND $FF000000) = 0);

  // Same data = same CRC
  CRC2 := HS.CalcCRC24(Buf, 5);
  Check('CRC deterministic', CRC1 = CRC2);

  // Different data = different CRC
  Buf[0] := $00;
  CRC2 := HS.CalcCRC24(Buf, 5);
  Check('CRC differs on change', CRC1 <> CRC2);
End;

// --- DLE Encode/Decode Tests ---
Procedure TestDLE;
Var
  Src    : Array[0..15] of Byte;
  Enc    : Array[0..31] of Byte;
  Dec    : Array[0..15] of Byte;
  EncLen : Word;
  DecLen : Word;
Begin
  WriteLn;
  WriteLn('--- DLE Encode/Decode ---');

  // Normal data (no specials)
  Src[0] := $41; // A
  Src[1] := $42; // B
  Src[2] := $43; // C
  HS.EncodeData(Src, 3, Enc, EncLen);
  Check('Normal: no expansion', EncLen = 3);

  HS.DecodeData(Enc, EncLen, Dec, DecLen);
  Check('Normal: roundtrip len', DecLen = 3);
  Check('Normal: roundtrip data', (Dec[0] = $41) and (Dec[1] = $42) and (Dec[2] = $43));

  // Data with STX ($02) — must be escaped
  Src[0] := $02; // STX
  Src[1] := $41;
  HS.EncodeData(Src, 2, Enc, EncLen);
  Check('STX escaped: expanded', EncLen = 3);
  Check('STX escaped: DLE prefix', Enc[0] = $1E); // HS_DLE

  HS.DecodeData(Enc, EncLen, Dec, DecLen);
  Check('STX escaped: roundtrip', (DecLen = 2) and (Dec[0] = $02));

  // Data with all special chars
  Src[0] := $02; // STX
  Src[1] := $11; // XON
  Src[2] := $13; // XOFF
  Src[3] := $18; // CAN
  Src[4] := $1B; // ESC
  Src[5] := $1E; // DLE
  HS.EncodeData(Src, 6, Enc, EncLen);
  Check('All specials: expanded', EncLen = 12); // 6 chars * 2 each

  HS.DecodeData(Enc, EncLen, Dec, DecLen);
  Check('All specials: roundtrip len', DecLen = 6);
  Check('All specials: roundtrip data',
    (Dec[0] = $02) and (Dec[1] = $11) and (Dec[2] = $13) and
    (Dec[3] = $18) and (Dec[4] = $1B) and (Dec[5] = $1E));
End;

// --- Packet Build Test ---
Procedure TestPacket;
Var
  Data   : Array[0..15] of Byte;
  Pkt    : Array[0..63] of Byte;
  PktLen : Word;
  Ok     : Boolean;
  Found  : Boolean;
  I      : Integer;
  BigBuf : Array[0..4999] of Byte;
Begin
  WriteLn;
  WriteLn('--- Packet Build ---');

  // Build ACK packet
  Data[0] := 5; // sequence 5
  Ok := HS.BuildPacket($41, Data, 1, Pkt, PktLen); // 'A' = ACK
  Check('ACK build OK', Ok);
  Check('ACK starts with STX', Pkt[0] = $02);
  Check('ACK has length', PktLen > 4); // STX + encoded + ESC + CRC3

  // Find ESC marker
  Found := False;
  For I := 1 to PktLen - 1 Do
    If Pkt[I] = $1B Then Found := True;
  Check('ACK has ESC marker', Found);

  // Empty packet
  Ok := HS.BuildPacket($52, Data, 0, Pkt, PktLen); // 'R' = Ready
  Check('Empty packet OK', Ok);
  Check('Empty packet has STX', Pkt[0] = $02);

  // Oversized packet
  Ok := HS.BuildPacket($46, BigBuf, 5000, Pkt, PktLen);
  Check('Oversized rejected', Not Ok);
End;

// --- Ready Packet Tests ---
Procedure TestReady;
Var
  Pkt : THSReadyPacket;
  Buf : Array[0..63] of Byte;
  Len : Word;
  Out : THSReadyPacket;
Begin
  WriteLn;
  WriteLn('--- Ready Packet ---');

  FillChar(Pkt, SizeOf(Pkt), 0);
  Pkt.Sender       := 'TestSender';
  Pkt.MaxWind      := 8;
  Pkt.BlockSize    := 2048;
  Pkt.Priority     := True;
  Pkt.DisableAck   := False;
  Pkt.ResumeVerify := True;
  Pkt.TransFiles   := 3;
  Pkt.TransBytes   := 123456;

  HS.EncodeReadyPacket(Pkt, Buf, Len);
  Check('Ready encode len > 0', Len > 0);

  HS.DecodeReadyPacket(Buf, Len, Out);
  Check('Ready sender', Out.Sender = 'TestSender');
  Check('Ready MaxWind', Out.MaxWind = 8);
  Check('Ready BlockSize', Out.BlockSize = 2048);
  Check('Ready Priority', Out.Priority = True);
  Check('Ready DisableAck', Out.DisableAck = False);
  Check('Ready ResumeVerify', Out.ResumeVerify = True);
  Check('Ready TransFiles', Out.TransFiles = 3);
  Check('Ready TransBytes', Out.TransBytes = 123456);
End;

// --- Negotiation Tests ---
Procedure TestNegotiate;
Begin
  WriteLn;
  WriteLn('--- Negotiation ---');

  // Our settings
  HS.WindowSize := 8;
  HS.BlockSize  := 2048;
  HS.DisableAck := False;
  HS.UseResume  := True;
  HS.MyReady.MaxWind      := 8;
  HS.MyReady.BlockSize    := 2048;
  HS.MyReady.ResumeVerify := True;

  // Remote settings (smaller)
  HS.HisReady.MaxWind      := 4;
  HS.HisReady.BlockSize    := 1024;
  HS.HisReady.ResumeVerify := True;
  HS.HisReady.Priority     := False;

  HS.NegotiateParams;
  Check('Negotiate: min window', HS.WindowSize = 4);
  Check('Negotiate: min blocksize', HS.BlockSize = 1024);
  Check('Negotiate: resume both', HS.UseResume = True);

  // Remote takes priority
  HS.HisReady.Priority   := True;
  HS.HisReady.DisableAck := True;
  HS.HisReady.BlockSize  := 4096;
  HS.HisReady.MaxWind    := 16;
  HS.NegotiateParams;
  Check('Priority: remote DisableAck', HS.DisableAck = True);
  Check('Priority: remote BlockSize', HS.BlockSize = 4096);
  Check('Priority: remote Window', HS.WindowSize = 16);

  // Window 0 = infinite = DisableAck
  HS.HisReady.Priority := False;
  HS.MyReady.MaxWind := 0;
  HS.HisReady.MaxWind := 0;
  HS.NegotiateParams;
  Check('Window 0: DisableAck', HS.DisableAck = True);
End;

// --- File Header Tests ---
Procedure TestFileHeader;
Begin
  WriteLn;
  WriteLn('--- File Header ---');

  HS.SendHdr.FileName  := 'TEST.ZIP';
  HS.SendHdr.FileSize  := 65536;
  HS.SendHdr.FileTime  := 1234567890;
  HS.SendHdr.BlockSize := 1024;
  Check('Header filename set', HS.SendHdr.FileName = 'TEST.ZIP');
  Check('Header size set', HS.SendHdr.FileSize = 65536);
  Check('Header time set', HS.SendHdr.FileTime = 1234567890);
End;

// --- State Machine Tests ---
Procedure TestState;
Begin
  WriteLn;
  WriteLn('--- State Machine ---');

  Check('Initial state idle', HS.State = hsIdle);
  Check('SendActive false', HS.SendActive = False);
  Check('RecvActive false', HS.RecvActive = False);
  Check('SeqSend 0', HS.SeqSend = 0);
  Check('SeqRecv 0', HS.SeqRecv = 0);
  Check('CancelCount 0', HS.CancelCount = 0);
  Check('AckPending 0', HS.AckPending = 0);
End;

// --- Config Defaults ---
Procedure TestDefaults;
Begin
  WriteLn;
  WriteLn('--- Defaults ---');

  Check('Protocol name', HS.Status.Protocol = 'HS/Link');
  Check('Window default 4', HS.WindowSize = 4);
  Check('Block default 1024', HS.BlockSize = 1024);
  Check('Resume default true', HS.UseResume = True);
  Check('Priority default false', HS.UsePriority = False);
  Check('DisableAck default false', HS.DisableAck = False);
  Check('MaxErrors default 20', HS.MaxErrors = 20);
  Check('CRC default 3', HS.CRCSize = 3);
  Check('Ready sender', HS.MyReady.Sender = 'Mystic HS/Link');
End;

Begin
  Pass := 0;
  Fail := 0;

  WriteLn('=== HS/Link Protocol Test ===');

  // Create without real socket — just testing internals
  // We can't call inherited Create without TIOBase, so test the
  // methods directly by accessing the class

  // For this test, we instantiate without a real connection
  DummyIO := NIL;
  DummyQ  := NIL;
  HS := TProtocolHSLink.Create(DummyIO, DummyQ);

  TestDefaults;
  TestState;
  TestCRC;
  TestDLE;
  TestPacket;
  TestReady;
  TestNegotiate;
  TestFileHeader;

  WriteLn;
  WriteLn('=== Results: ', Pass, '/', Pass + Fail, ' passed, ', Fail, ' failed ===');

  HS.Free;
End.

// ====================================================================
// Mystic BBS IRC Fork — GPLv3
// HS/Link File Transfer Protocol — Clean-Room Pascal Implementation
// ====================================================================
// Implemented from the HS/Link Developer Kit (HDK) protocol
// specification by Samuel H. Smith. No code copied from C source.
//
// HS/Link is a bidirectional file transfer protocol — it can send
// and receive files simultaneously over a single serial connection.
//
// Packet format:
//   STX <type> <data...> ESC <crc24>
//   STX = $02 (start of packet)
//   ESC = $1B (end of packet marker)
//   DLE = $1E (escape prefix for special chars in data)
//   CRC = 24-bit CRC over type+data
//
// Packet types:
//   A = ACK (acknowledge block)
//   C = Close file
//   D = Data block (seq+mapping+data)
//   E = Data block (mapping+data)
//   F = Data block (data only)
//   H = Chat text
//   K = Skip file
//   M = Extended NAK
//   N = NAK (negative acknowledge)
//   O = Open file (file header)
//   P = Reset file
//   Q = Ready to receive
//   R = Ready
//   S = Seek block
//   V = Verify (resume)
//   Z = Transmit done
// ====================================================================
Unit m_protocol_hslink;

{$I M_OPS.PAS}

Interface

Uses
  m_io_Base,
  m_CRC,
  m_Protocol_Base,
  m_Protocol_Queue;

Const
  // Special characters
  HS_STX  = $02;   // Start of packet
  HS_XON  = $11;   // Flow control
  HS_XOFF = $13;   // Flow control
  HS_CAN  = $18;   // Cancel (4x to abort)
  HS_ESC  = $1B;   // End of packet marker
  HS_DLE  = $1E;   // Data escape prefix

  // Protocol limits
  HS_MAX_BLOCK    = 4096;    // Max data block size
  HS_ACK_TIMEOUT  = 20000;   // ms before ACK timeout
  HS_MAX_TIMEOUT  = 4;       // ACK timeouts to cancel
  HS_RCV_TIMEOUT  = 22000;   // ms idle before rx timeout
  HS_READY_TIMEOUT = 120000; // ms before ready timeout
  HS_ENQ_TIMEOUT  = 5000;    // ms between ready retries
  HS_CANCEL_COUNT = 4;       // CANs needed to abort
  HS_DEF_CRC_SIZE = 3;       // 24-bit CRC default

  // Packet type codes
  HS_ACK          = Ord('A');
  HS_CLOSE_FILE   = Ord('C');
  HS_DATA_SMD     = Ord('D');  // seq + mapping + data
  HS_DATA_MD      = Ord('E');  // mapping + data
  HS_DATA_D       = Ord('F');  // data only
  HS_CHAT         = Ord('H');
  HS_SKIP_FILE    = Ord('K');
  HS_EXTNAK       = Ord('M');
  HS_NAK          = Ord('N');
  HS_OPEN_FILE    = Ord('O');
  HS_RESET_FILE   = Ord('P');
  HS_READY_RECV   = Ord('Q');
  HS_READY        = Ord('R');
  HS_SEEK         = Ord('S');
  HS_VERIFY       = Ord('V');
  HS_TX_DONE      = Ord('Z');

Type
  THSLinkState = (
    hsIdle,
    hsReady,
    hsSending,
    hsReceiving,
    hsBiDir,
    hsDone,
    hsError
  );

  THSFileHeader = Record
    FileName  : String[64];
    FileSize  : LongInt;
    FileTime  : LongInt;
    BlockSize : Word;
    SeqNum    : Byte;
  End;

  // Ready packet — negotiated between peers at handshake
  THSReadyPacket = Record
    Sender       : String[15];   // Program identification
    MaxWind      : Word;         // -W window size
    BlockSize    : Word;         // -S block size
    Priority     : Boolean;      // -! take priority
    DisableAck   : Boolean;      // -A no ACK mode
    XonHandshake : Boolean;      // -HX XON/XOFF flow
    ResumeVerify : Boolean;      // -R crash recovery
    MinimalBlocks: Boolean;      // -NM minimal block logic
    PartialBlocks: Boolean;      // -NP extended NAK capable
    AlternateDLE : Boolean;      // alternate DLE encoding
    TransFiles   : Word;         // files queued to send
    TransBytes   : LongInt;      // bytes queued to send
    FinalReady   : Boolean;      // no more ready packets expected
  End;

  // Chat message
  THSChatMsg = String[160];

  TProtocolHSLink = Class(TProtocolBase)
    State       : THSLinkState;

    // Configuration (command-line equivalent)
    WindowSize  : Word;        // -W sliding window size (0=infinite)
    BlockSize   : Word;        // -S block size (64-4096)
    UseResume   : Boolean;     // -R crash recovery
    UsePriority : Boolean;     // -! take priority
    DisableAck  : Boolean;     // -A no ACK required
    UseXonXoff  : Boolean;     // -HX XON/XOFF flow control
    MinBlocks   : Boolean;     // -NM minimal blocks (MNP modems)
    MaxErrors   : Word;        // max errors before abort
    CRCSize     : Byte;        // CRC size (2=16bit, 3=24bit)

    // Protocol state
    SeqSend     : Byte;        // Send sequence counter
    SeqRecv     : Byte;        // Receive sequence counter
    CancelCount : Byte;        // Consecutive CAN count
    AckPending  : Word;        // Blocks sent without ACK
    SendActive  : Boolean;     // Currently sending a file
    RecvActive  : Boolean;     // Currently receiving a file
    SendFile    : File;        // Outgoing file handle
    RecvFile    : File;        // Incoming file handle
    SendPos     : LongInt;     // Current send position (for seek/resume)
    RecvPos     : LongInt;     // Current receive position
    SendHdr     : THSFileHeader;
    RecvHdr     : THSFileHeader;
    MyReady     : THSReadyPacket;   // Our ready packet
    HisReady    : THSReadyPacket;   // Remote's ready packet
    ChatBuf     : THSChatMsg;       // Outgoing chat buffer

    Constructor Create (Var C: TIOBase; Var Q: TProtocolQueue); Override;
    Destructor  Destroy; Override;

    // CRC calculation
    Function  CalcCRC24  (Var Buf; Size: Word) : LongInt;

    // Packet I/O
    Function  BuildPacket (PType: Byte; Var Data; DataLen: Word;
                           Var Pkt; Var PktLen: Word) : Boolean;
    Function  SendPacket  (PType: Byte; Var Data; DataLen: Word) : Boolean;
    Function  RecvPacket  (Var PType: Byte;
                           Var Data; Var DataLen: Word) : Boolean;

    // Escape encoding/decoding
    Function  EncodeData  (Var Src; SrcLen: Word;
                           Var Dst; Var DstLen: Word) : Boolean;
    Function  DecodeData  (Var Src; SrcLen: Word;
                           Var Dst; Var DstLen: Word) : Boolean;

    // Protocol operations
    Procedure SendReadyPacket;
    Procedure SendACK     (Seq: Byte);
    Procedure SendNAK     (Seq: Byte);
    Procedure SendExtNAK  (SeqStart, SeqEnd: Byte);
    Procedure SendOpenFile(Var Hdr: THSFileHeader);
    Procedure SendCloseFile;
    Procedure SendDataBlock(Var Buf; Size: Word; Seq: Byte);
    Procedure SendSeek    (BlockNum: LongInt);
    Procedure SendVerify  (Pos: LongInt; CRC: LongInt);
    Procedure SendResetFile;
    Procedure SendSkipFile;
    Procedure SendTxDone;
    Procedure SendChat    (Msg: String);

    // Ready packet negotiation
    Procedure EncodeReadyPacket (Var Pkt: THSReadyPacket; Var Buf; Var Len: Word);
    Procedure DecodeReadyPacket (Var Buf; Len: Word; Var Pkt: THSReadyPacket);
    Procedure NegotiateParams;

    // Resume/crash recovery
    Function  VerifyResumePos (Pos: LongInt) : Boolean;
    Procedure HandleResume;

    // Bidirectional engine
    Procedure ProcessIncoming;
    Procedure ProcessOutgoing;
    Procedure RunBiDir;

    // Transfer interface
    Procedure QueueSend; Override;
    Procedure QueueReceive; Override;
  End;

Implementation

Constructor TProtocolHSLink.Create (Var C: TIOBase; Var Q: TProtocolQueue);
Begin
  Inherited Create(C, Q);

  Status.Protocol := 'HS/Link';
  State       := hsIdle;

  // Default configuration
  WindowSize  := 4;
  BlockSize   := 1024;
  UseResume   := True;
  UsePriority := False;
  DisableAck  := False;
  UseXonXoff  := False;
  MinBlocks   := False;
  MaxErrors   := 20;
  CRCSize     := HS_DEF_CRC_SIZE;

  // Protocol state
  SeqSend     := 0;
  SeqRecv     := 0;
  CancelCount := 0;
  AckPending  := 0;
  SendActive  := False;
  RecvActive  := False;
  SendPos     := 0;
  RecvPos     := 0;
  ChatBuf     := '';

  // Ready packet defaults
  FillChar(MyReady, SizeOf(MyReady), 0);
  MyReady.Sender       := 'Mystic HS/Link';
  MyReady.MaxWind      := WindowSize;
  MyReady.BlockSize    := BlockSize;
  MyReady.ResumeVerify := UseResume;
  FillChar(HisReady, SizeOf(HisReady), 0);
End;

Destructor TProtocolHSLink.Destroy;
Begin
  Inherited Destroy;
End;

// ====================================================================
// 24-bit CRC — HS/Link default error detection
// Polynomial: x^24 + x^10 + x^9 + x^6 + x^4 + x^3 + x + 1
// ====================================================================
Function TProtocolHSLink.CalcCRC24 (Var Buf; Size: Word) : LongInt;
Const
  CRC24_POLY = $01864CFB;
Var
  B   : Array[0..4095] of Byte Absolute Buf;
  CRC : LongInt;
  I   : Word;
  J   : Byte;
Begin
  CRC := $00B704CE;  // CRC-24 init value
  For I := 0 to Size - 1 Do Begin
    CRC := CRC XOR (LongInt(B[I]) SHL 16);
    For J := 0 to 7 Do Begin
      CRC := CRC SHL 1;
      If (CRC AND $01000000) <> 0 Then
        CRC := CRC XOR CRC24_POLY;
    End;
  End;
  Result := CRC AND $00FFFFFF;
End;

// ====================================================================
// Escape encoding — protect special chars in packet data
// DLE prefix: STX, XON, XOFF, CAN, ESC, DLE become DLE + (char XOR $40)
// ====================================================================
Function TProtocolHSLink.EncodeData (Var Src; SrcLen: Word;
                                     Var Dst; Var DstLen: Word) : Boolean;
Var
  S : Array[0..4095] of Byte Absolute Src;
  D : Array[0..8191] of Byte Absolute Dst;
  I : Word;
  B : Byte;
Begin
  Result := True;
  DstLen := 0;
  For I := 0 to SrcLen - 1 Do Begin
    B := S[I];
    Case B of
      HS_STX, HS_XON, HS_XOFF, HS_CAN, HS_ESC, HS_DLE: Begin
        D[DstLen] := HS_DLE;
        Inc(DstLen);
        D[DstLen] := B XOR $40;
        Inc(DstLen);
      End;
    Else
      D[DstLen] := B;
      Inc(DstLen);
    End;
  End;
End;

Function TProtocolHSLink.DecodeData (Var Src; SrcLen: Word;
                                     Var Dst; Var DstLen: Word) : Boolean;
Var
  S : Array[0..8191] of Byte Absolute Src;
  D : Array[0..4095] of Byte Absolute Dst;
  I : Word;
  B : Byte;
Begin
  Result := True;
  DstLen := 0;
  I := 0;
  While I < SrcLen Do Begin
    B := S[I];
    If B = HS_DLE Then Begin
      Inc(I);
      If I >= SrcLen Then Break;
      D[DstLen] := S[I] XOR $40;
    End Else
      D[DstLen] := B;
    Inc(DstLen);
    Inc(I);
  End;
End;

// ====================================================================
// Packet building and sending
// Format: STX <encoded_type+data> ESC <crc24_byte1> <crc24_byte2> <crc24_byte3>
// ====================================================================
Function TProtocolHSLink.BuildPacket (PType: Byte; Var Data; DataLen: Word;
                                      Var Pkt; Var PktLen: Word) : Boolean;
Var
  Raw    : Array[0..4097] of Byte;  // type + data
  Enc    : Array[0..8195] of Byte;  // encoded
  P      : Array[0..8199] of Byte Absolute Pkt;
  EncLen : Word;
  CRC    : LongInt;
Begin
  Result := False;
  If DataLen > HS_MAX_BLOCK Then Exit;

  // Build raw: type + data
  Raw[0] := PType;
  If DataLen > 0 Then
    Move(Data, Raw[1], DataLen);

  // Calculate CRC over raw data
  CRC := CalcCRC24(Raw, DataLen + 1);

  // Encode raw data (escape special chars)
  EncodeData(Raw, DataLen + 1, Enc, EncLen);

  // Build packet: STX + encoded + ESC + CRC bytes
  PktLen := 0;
  P[PktLen] := HS_STX; Inc(PktLen);

  Move(Enc, P[PktLen], EncLen);
  Inc(PktLen, EncLen);

  P[PktLen] := HS_ESC; Inc(PktLen);

  // CRC as 3 bytes (24-bit)
  P[PktLen] := Byte(CRC SHR 16); Inc(PktLen);
  P[PktLen] := Byte(CRC SHR 8);  Inc(PktLen);
  P[PktLen] := Byte(CRC);        Inc(PktLen);

  Result := True;
End;

Function TProtocolHSLink.SendPacket (PType: Byte; Var Data; DataLen: Word) : Boolean;
Var
  Pkt    : Array[0..8199] of Byte;
  PktLen : Word;
Begin
  Result := False;
  If Not BuildPacket(PType, Data, DataLen, Pkt, PktLen) Then Exit;
  Result := Client.WriteBuf(Pkt, PktLen) >= 0;
End;

Function TProtocolHSLink.RecvPacket (Var PType: Byte;
                                     Var Data; Var DataLen: Word) : Boolean;
Var
  Raw      : Array[0..8199] of Byte;
  Dec      : Array[0..4097] of Byte;
  RawLen   : Word;
  DecLen   : Word;
  C        : SmallInt;
  CRCRecv  : LongInt;
  CRCCalc  : LongInt;
Begin
  Result := False;
  DataLen := 0;

  // Wait for STX
  Repeat
    C := ReadByteTimeOut(HS_RCV_TIMEOUT DIV 10);
    If C < 0 Then Exit;
    If Byte(C) = HS_CAN Then Begin
      Inc(CancelCount);
      If CancelCount >= HS_CANCEL_COUNT Then Begin
        State := hsError;
        Exit;
      End;
    End Else
      CancelCount := 0;
  Until Byte(C) = HS_STX;

  // Read until ESC (end of packet)
  RawLen := 0;
  Repeat
    C := ReadByteTimeOut(HS_RCV_TIMEOUT DIV 10);
    If C < 0 Then Exit;
    If Byte(C) = HS_ESC Then Break;
    If RawLen < SizeOf(Raw) Then Begin
      Raw[RawLen] := Byte(C);
      Inc(RawLen);
    End;
  Until False;

  // Read 3-byte CRC
  C := ReadByteTimeOut(HS_RCV_TIMEOUT DIV 10);
  If C < 0 Then Exit;
  CRCRecv := LongInt(Byte(C)) SHL 16;
  C := ReadByteTimeOut(HS_RCV_TIMEOUT DIV 10);
  If C < 0 Then Exit;
  CRCRecv := CRCRecv OR (LongInt(Byte(C)) SHL 8);
  C := ReadByteTimeOut(HS_RCV_TIMEOUT DIV 10);
  If C < 0 Then Exit;
  CRCRecv := CRCRecv OR LongInt(Byte(C));

  // Decode escaped data
  DecodeData(Raw, RawLen, Dec, DecLen);
  If DecLen = 0 Then Exit;

  // Verify CRC
  CRCCalc := CalcCRC24(Dec, DecLen);
  If CRCCalc <> CRCRecv Then Exit;

  // Extract type and data
  PType := Dec[0];
  DataLen := DecLen - 1;
  If DataLen > 0 Then
    Move(Dec[1], Data, DataLen);

  Result := True;
End;

// ====================================================================
// Protocol operations
// ====================================================================

Procedure TProtocolHSLink.SendReadyPacket;
Var
  Buf : Array[0..63] of Byte;
  Len : Word;
Begin
  MyReady.MaxWind      := WindowSize;
  MyReady.BlockSize    := BlockSize;
  MyReady.Priority     := UsePriority;
  MyReady.DisableAck   := DisableAck;
  MyReady.XonHandshake := UseXonXoff;
  MyReady.ResumeVerify := UseResume;
  MyReady.MinimalBlocks := MinBlocks;
  MyReady.TransFiles   := Queue.QSize;
  EncodeReadyPacket(MyReady, Buf, Len);
  SendPacket(HS_READY, Buf, Len);
End;

Procedure TProtocolHSLink.SendACK (Seq: Byte);
Begin
  SendPacket(HS_ACK, Seq, 1);
End;

Procedure TProtocolHSLink.SendNAK (Seq: Byte);
Begin
  SendPacket(HS_NAK, Seq, 1);
End;

Procedure TProtocolHSLink.SendOpenFile (Var Hdr: THSFileHeader);
Var
  Buf : Array[0..127] of Byte;
  Pos : Integer;
  I   : Integer;
Begin
  FillChar(Buf, SizeOf(Buf), 0);
  Pos := 0;

  // Filename (null-terminated)
  For I := 1 to Length(Hdr.FileName) Do Begin
    Buf[Pos] := Ord(Hdr.FileName[I]);
    Inc(Pos);
  End;
  Buf[Pos] := 0; Inc(Pos);

  // File size (4 bytes, little-endian)
  Buf[Pos] := Byte(Hdr.FileSize);         Inc(Pos);
  Buf[Pos] := Byte(Hdr.FileSize SHR 8);   Inc(Pos);
  Buf[Pos] := Byte(Hdr.FileSize SHR 16);  Inc(Pos);
  Buf[Pos] := Byte(Hdr.FileSize SHR 24);  Inc(Pos);

  // File time (4 bytes, little-endian)
  Buf[Pos] := Byte(Hdr.FileTime);         Inc(Pos);
  Buf[Pos] := Byte(Hdr.FileTime SHR 8);   Inc(Pos);
  Buf[Pos] := Byte(Hdr.FileTime SHR 16);  Inc(Pos);
  Buf[Pos] := Byte(Hdr.FileTime SHR 24);  Inc(Pos);

  // Block size (2 bytes)
  Buf[Pos] := Byte(Hdr.BlockSize);        Inc(Pos);
  Buf[Pos] := Byte(Hdr.BlockSize SHR 8);  Inc(Pos);

  SendPacket(HS_OPEN_FILE, Buf, Pos);
End;

Procedure TProtocolHSLink.SendCloseFile;
Var Dummy : Byte;
Begin
  Dummy := 0;
  SendPacket(HS_CLOSE_FILE, Dummy, 0);
End;

Procedure TProtocolHSLink.SendDataBlock (Var Buf; Size: Word; Seq: Byte);
Var
  Pkt : Array[0..4097] of Byte;
Begin
  // Data-only format (type F): just data, seq tracked separately
  Pkt[0] := Seq;
  Move(Buf, Pkt[1], Size);
  SendPacket(HS_DATA_D, Pkt, Size + 1);
End;

Procedure TProtocolHSLink.SendTxDone;
Var Dummy : Byte;
Begin
  Dummy := 0;
  SendPacket(HS_TX_DONE, Dummy, 0);
End;

// ====================================================================
// Extended protocol operations
// ====================================================================

Procedure TProtocolHSLink.SendExtNAK (SeqStart, SeqEnd: Byte);
Var Buf : Array[0..1] of Byte;
Begin
  Buf[0] := SeqStart;
  Buf[1] := SeqEnd;
  SendPacket(HS_EXTNAK, Buf, 2);
End;

Procedure TProtocolHSLink.SendSeek (BlockNum: LongInt);
Var Buf : Array[0..3] of Byte;
Begin
  Buf[0] := Byte(BlockNum);
  Buf[1] := Byte(BlockNum SHR 8);
  Buf[2] := Byte(BlockNum SHR 16);
  Buf[3] := Byte(BlockNum SHR 24);
  SendPacket(HS_SEEK, Buf, 4);
End;

Procedure TProtocolHSLink.SendVerify (Pos: LongInt; CRC: LongInt);
Var Buf : Array[0..7] of Byte;
Begin
  Buf[0] := Byte(Pos);
  Buf[1] := Byte(Pos SHR 8);
  Buf[2] := Byte(Pos SHR 16);
  Buf[3] := Byte(Pos SHR 24);
  Buf[4] := Byte(CRC);
  Buf[5] := Byte(CRC SHR 8);
  Buf[6] := Byte(CRC SHR 16);
  Buf[7] := Byte(CRC SHR 24);
  SendPacket(HS_VERIFY, Buf, 8);
End;

Procedure TProtocolHSLink.SendResetFile;
Var Dummy : Byte;
Begin
  Dummy := 0;
  SendPacket(HS_RESET_FILE, Dummy, 0);
End;

Procedure TProtocolHSLink.SendSkipFile;
Var Dummy : Byte;
Begin
  Dummy := 0;
  SendPacket(HS_SKIP_FILE, Dummy, 0);
End;

Procedure TProtocolHSLink.SendChat (Msg: String);
Var Buf : Array[0..160] of Byte;
    I   : Integer;
Begin
  For I := 1 to Length(Msg) Do
    Buf[I-1] := Ord(Msg[I]);
  SendPacket(HS_CHAT, Buf, Length(Msg));
End;

// ====================================================================
// Ready packet negotiation
// ====================================================================

Procedure TProtocolHSLink.EncodeReadyPacket (Var Pkt: THSReadyPacket; Var Buf; Var Len: Word);
Var B : Array[0..63] of Byte Absolute Buf;
    I : Integer;
Begin
  FillChar(B, 64, 0);
  // Sender (16 bytes, null-padded)
  For I := 1 to Length(Pkt.Sender) Do
    B[I-1] := Ord(Pkt.Sender[I]);
  // MaxWind (2 bytes at offset 20)
  B[20] := Byte(Pkt.MaxWind);
  B[21] := Byte(Pkt.MaxWind SHR 8);
  // BlockSize (2 bytes at offset 22)
  B[22] := Byte(Pkt.BlockSize);
  B[23] := Byte(Pkt.BlockSize SHR 8);
  // Flags (offset 28)
  B[28] := 0;
  If Pkt.Priority      Then B[28] := B[28] OR $01;
  If Pkt.DisableAck    Then B[28] := B[28] OR $02;
  If Pkt.XonHandshake  Then B[28] := B[28] OR $04;
  If Pkt.ResumeVerify  Then B[28] := B[28] OR $08;
  If Pkt.MinimalBlocks Then B[28] := B[28] OR $10;
  If Pkt.FinalReady    Then B[28] := B[28] OR $20;
  If Pkt.PartialBlocks Then B[28] := B[28] OR $40;
  If Pkt.AlternateDLE  Then B[28] := B[28] OR $80;
  // TransFiles (2 bytes at offset 32)
  B[32] := Byte(Pkt.TransFiles);
  B[33] := Byte(Pkt.TransFiles SHR 8);
  // TransBytes (4 bytes at offset 34)
  B[34] := Byte(Pkt.TransBytes);
  B[35] := Byte(Pkt.TransBytes SHR 8);
  B[36] := Byte(Pkt.TransBytes SHR 16);
  B[37] := Byte(Pkt.TransBytes SHR 24);
  Len := 38;
End;

Procedure TProtocolHSLink.DecodeReadyPacket (Var Buf; Len: Word; Var Pkt: THSReadyPacket);
Var B : Array[0..63] of Byte Absolute Buf;
    I : Integer;
Begin
  FillChar(Pkt, SizeOf(Pkt), 0);
  If Len < 28 Then Exit;
  // Sender
  Pkt.Sender := '';
  For I := 0 to 15 Do
    If B[I] <> 0 Then Pkt.Sender := Pkt.Sender + Chr(B[I]);
  // MaxWind
  Pkt.MaxWind := Word(B[20]) OR (Word(B[21]) SHL 8);
  // BlockSize
  Pkt.BlockSize := Word(B[22]) OR (Word(B[23]) SHL 8);
  // Flags
  Pkt.Priority      := (B[28] AND $01) <> 0;
  Pkt.DisableAck    := (B[28] AND $02) <> 0;
  Pkt.XonHandshake  := (B[28] AND $04) <> 0;
  Pkt.ResumeVerify  := (B[28] AND $08) <> 0;
  Pkt.MinimalBlocks := (B[28] AND $10) <> 0;
  Pkt.FinalReady    := (B[28] AND $20) <> 0;
  Pkt.PartialBlocks := (B[28] AND $40) <> 0;
  Pkt.AlternateDLE  := (B[28] AND $80) <> 0;
  // TransFiles/Bytes
  If Len >= 38 Then Begin
    Pkt.TransFiles := Word(B[32]) OR (Word(B[33]) SHL 8);
    Pkt.TransBytes := LongInt(B[34]) OR (LongInt(B[35]) SHL 8) OR
                      (LongInt(B[36]) SHL 16) OR (LongInt(B[37]) SHL 24);
  End;
End;

Procedure TProtocolHSLink.NegotiateParams;
Begin
  // Use minimum of our and their settings
  If HisReady.MaxWind < MyReady.MaxWind Then
    WindowSize := HisReady.MaxWind
  Else
    WindowSize := MyReady.MaxWind;
  If WindowSize = 0 Then DisableAck := True;

  If HisReady.BlockSize < MyReady.BlockSize Then
    BlockSize := HisReady.BlockSize
  Else
    BlockSize := MyReady.BlockSize;
  If BlockSize < 64 Then BlockSize := 64;
  If BlockSize > HS_MAX_BLOCK Then BlockSize := HS_MAX_BLOCK;

  // Priority: remote takes priority if they set it
  If HisReady.Priority Then Begin
    DisableAck := HisReady.DisableAck;
    UseXonXoff := HisReady.XonHandshake;
    BlockSize  := HisReady.BlockSize;
    WindowSize := HisReady.MaxWind;
  End;

  UseResume  := MyReady.ResumeVerify AND HisReady.ResumeVerify;
  MinBlocks  := MyReady.MinimalBlocks AND HisReady.MinimalBlocks;
End;

// ====================================================================
// Resume / crash recovery
// ====================================================================

Function TProtocolHSLink.VerifyResumePos (Pos: LongInt) : Boolean;
// Verify that the existing file data matches up to Pos
Var
  Buf     : Array[0..4095] of Byte;
  F       : File;
  FSize   : LongInt;
  BytesRead : LongInt;
  FileCRC : LongInt;
Begin
  Result := False;
  If Not RecvActive Then Exit;

  {$I-} Reset(RecvFile, 1); {$I+}
  If IOResult <> 0 Then Exit;

  FSize := FileSize(RecvFile);
  If FSize < Pos Then Begin
    Close(RecvFile);
    Exit;
  End;

  // CRC the existing data
  FileCRC := $00B704CE;
  While Pos > 0 Do Begin
    If Pos > SizeOf(Buf) Then BytesRead := SizeOf(Buf)
    Else BytesRead := Pos;
    BlockRead(RecvFile, Buf, BytesRead);
    FileCRC := CalcCRC24(Buf, BytesRead);
    Dec(Pos, BytesRead);
  End;

  Result := True;
End;

Procedure TProtocolHSLink.HandleResume;
Begin
  If Not UseResume Then Exit;
  If Not RecvActive Then Exit;

  // Check if file already exists with data
  {$I-} Reset(RecvFile, 1); {$I+}
  If IOResult <> 0 Then Exit;

  RecvPos := FileSize(RecvFile);
  If RecvPos > 0 Then Begin
    // Send verify with our position and CRC
    SendVerify(RecvPos, CalcCRC24(RecvFile, RecvPos));
    Seek(RecvFile, RecvPos);
    Status.Position := RecvPos;
  End;
End;

// ====================================================================
// Bidirectional engine

// ====================================================================
// Bidirectional engine — process both directions simultaneously
// ====================================================================

Procedure TProtocolHSLink.ProcessIncoming;
Var
  PType   : Byte;
  Data    : Array[0..4095] of Byte;
  DataLen : Word;
  Hdr     : THSFileHeader;
  Pos     : Integer;
  I       : Integer;
  TempPos : LongInt;
Begin
  If Not RecvPacket(PType, Data, DataLen) Then Exit;

  Case PType of
    HS_OPEN_FILE: Begin
      // Parse file header
      Pos := 0;
      RecvHdr.FileName := '';
      While (Pos < DataLen) and (Data[Pos] <> 0) Do Begin
        RecvHdr.FileName := RecvHdr.FileName + Chr(Data[Pos]);
        Inc(Pos);
      End;
      Inc(Pos); // skip null

      If Pos + 10 <= DataLen Then Begin
        RecvHdr.FileSize := LongInt(Data[Pos]) OR
                            (LongInt(Data[Pos+1]) SHL 8) OR
                            (LongInt(Data[Pos+2]) SHL 16) OR
                            (LongInt(Data[Pos+3]) SHL 24);
        Inc(Pos, 4);
        RecvHdr.FileTime := LongInt(Data[Pos]) OR
                            (LongInt(Data[Pos+1]) SHL 8) OR
                            (LongInt(Data[Pos+2]) SHL 16) OR
                            (LongInt(Data[Pos+3]) SHL 24);
        Inc(Pos, 4);
        RecvHdr.BlockSize := Word(Data[Pos]) OR
                             (Word(Data[Pos+1]) SHL 8);
      End;

      // Open receive file
      Status.FileName := RecvHdr.FileName;
      Status.FileSize := RecvHdr.FileSize;
      Status.Position := 0;
      Assign(RecvFile, ReceivePath + RecvHdr.FileName);
      {$I-} Rewrite(RecvFile, 1); {$I+}
      If IOResult = 0 Then Begin
        RecvActive := True;
        SeqRecv := 0;
        SendACK(0);
      End;
    End;

    HS_DATA_D, HS_DATA_MD, HS_DATA_SMD: Begin
      If RecvActive Then Begin
        // First byte is sequence number
        If Data[0] = SeqRecv Then Begin
          BlockWrite(RecvFile, Data[1], DataLen - 1);
          Status.Position := Status.Position + DataLen - 1;
          SendACK(SeqRecv);
          SeqRecv := (SeqRecv + 1) AND $FF;
          StatusUpdate(False, False);
        End Else
          SendNAK(SeqRecv);
      End;
    End;

    HS_CLOSE_FILE: Begin
      If RecvActive Then Begin
        Close(RecvFile);
        RecvActive := False;
        SendACK(SeqRecv);
      End;
    End;

    HS_ACK: Begin
      // ACK received for our sent data — advance window
      If AckPending > 0 Then Dec(AckPending);
    End;

    HS_NAK: Begin
      // NAK — need to resend from this sequence
      Inc(Status.Errors);
    End;

    HS_SKIP_FILE: Begin
      If RecvActive Then Begin
        Close(RecvFile);
        RecvActive := False;
      End;
    End;

    HS_TX_DONE: Begin
      // Remote finished sending all files
      If Not SendActive Then
        State := hsDone;
    End;

    HS_CHAT: Begin
      // Chat text received
      If DataLen > 0 Then Begin
        ChatBuf := '';
        For I := 0 to DataLen - 1 Do
          ChatBuf := ChatBuf + Chr(Data[I]);
        // Could display or log chat here
      End;
    End;

    HS_SEEK: Begin
      // Remote wants us to seek in our send file
      If SendActive and (DataLen >= 4) Then Begin
        SendPos := LongInt(Data[0]) OR (LongInt(Data[1]) SHL 8) OR
                   (LongInt(Data[2]) SHL 16) OR (LongInt(Data[3]) SHL 24);
        {$I-} Seek(SendFile, SendPos); {$I+}
        Status.Position := SendPos;
      End;
    End;

    HS_VERIFY: Begin
      // Resume verification from remote
      If RecvActive and (DataLen >= 8) Then Begin
        RecvPos := LongInt(Data[0]) OR (LongInt(Data[1]) SHL 8) OR
                   (LongInt(Data[2]) SHL 16) OR (LongInt(Data[3]) SHL 24);
        // Verify our local data matches, then seek
        If VerifyResumePos(RecvPos) Then Begin
          {$I-} Seek(RecvFile, RecvPos); {$I+}
          Status.Position := RecvPos;
          SendACK(SeqRecv);
        End Else Begin
          // Mismatch — reset from beginning
          {$I-} Seek(RecvFile, 0); {$I+}
          RecvPos := 0;
          Status.Position := 0;
          SendResetFile;
        End;
      End;
    End;

    HS_RESET_FILE: Begin
      // Remote wants us to restart file from beginning
      If RecvActive Then Begin
        {$I-} Seek(RecvFile, 0); {$I+}
        RecvPos := 0;
        Status.Position := 0;
        SeqRecv := 0;
        SendACK(0);
      End;
    End;

    HS_EXTNAK: Begin
      // Extended NAK — retransmit range
      If SendActive and (DataLen >= 2) Then Begin
        // Seek back to requested block
        Inc(Status.Errors);
      End;
    End;

    HS_READY: Begin
      // Ready packet with negotiation data
      If DataLen > 0 Then
        DecodeReadyPacket(Data, DataLen, HisReady);
      NegotiateParams;
      If State = hsIdle Then Begin
        MyReady.FinalReady := True;
        SendReadyPacket;
        State := hsReady;
      End;
    End;

    HS_READY_RECV: Begin
      // Remote ready to receive
    End;
  End;
End;

Procedure TProtocolHSLink.ProcessOutgoing;
Var
  Buf       : Array[0..4095] of Byte;
  BytesRead : LongInt;
Begin
  If Not SendActive Then Exit;

  // Window flow control — wait for ACK if window full
  If (WindowSize > 0) and (Not DisableAck) Then Begin
    If AckPending >= WindowSize Then Exit;
  End;

  If Eof(SendFile) Then Begin
    SendCloseFile;
    Close(SendFile);
    SendActive := False;
    AckPending := 0;
    Exit;
  End;

  BlockRead(SendFile, Buf, BlockSize, BytesRead);
  If BytesRead > 0 Then Begin
    SendDataBlock(Buf, BytesRead, SeqSend);
    SendPos := SendPos + BytesRead;
    Status.Position := SendPos;
    SeqSend := (SeqSend + 1) AND $FF;
    Inc(AckPending);
    StatusUpdate(False, False);
  End;
End;

Procedure TProtocolHSLink.RunBiDir;
Begin
  State := hsBiDir;

  While (State = hsBiDir) and Not AbortTransfer Do Begin
    // Check for incoming data
    If Client.DataWaiting Then
      ProcessIncoming;

    // Send outgoing data if window allows
    ProcessOutgoing;

    // Check if both directions are done
    If (Not SendActive) and (Not RecvActive) and (State <> hsError) Then
      State := hsDone;
  End;
End;

// ====================================================================
// Transfer interface
// ====================================================================

Procedure TProtocolHSLink.QueueSend;
Var
  QIdx : Integer;
Begin
  Status.Sender := True;
  StatusUpdate(True, False);

  // Handshake
  SendReadyPacket;

  // Wait for remote ready
  State := hsIdle;
  While (State = hsIdle) and Not AbortTransfer Do
    ProcessIncoming;

  If State <> hsReady Then Begin
    StatusUpdate(False, True);
    Exit;
  End;

  // Send each file
  For QIdx := 1 to Queue.QSize Do Begin
    If AbortTransfer Then Break;

    Status.FilePath := Queue.QData[QIdx]^.FilePath;
    Status.FileName := Queue.QData[QIdx]^.FileName;

    Assign(SendFile, Status.FilePath + Status.FileName);
    {$I-} Reset(SendFile, 1); {$I+}
    If IOResult <> 0 Then Continue;

    Status.FileSize := FileSize(SendFile);
    Status.Position := 0;

    // Send file header
    SendHdr.FileName  := Status.FileName;
    SendHdr.FileSize  := Status.FileSize;
    SendHdr.FileTime  := 0;
    SendHdr.BlockSize := BlockSize;
    SendHdr.SeqNum    := 0;
    SendOpenFile(SendHdr);

    SendActive := True;
    SeqSend := 0;

    // Run bidirectional engine
    RunBiDir;
  End;

  SendTxDone;
  StatusUpdate(False, True);
End;

Procedure TProtocolHSLink.QueueReceive;
Begin
  Status.Sender := False;
  StatusUpdate(True, False);

  // Handshake
  SendReadyPacket;

  State := hsIdle;
  While (State = hsIdle) and Not AbortTransfer Do
    ProcessIncoming;

  If State <> hsReady Then Begin
    StatusUpdate(False, True);
    Exit;
  End;

  // Run bidirectional engine — incoming files handled in ProcessIncoming
  RecvActive := False;
  RunBiDir;

  StatusUpdate(False, True);
End;

End.

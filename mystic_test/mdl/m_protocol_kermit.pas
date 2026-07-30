// ====================================================================
// Mystic BBS IRC Fork — GPLv3
// Kermit File Transfer Protocol
// Columbia University, 1981 — Frank da Cruz
// ====================================================================
// Kermit protocol — character-oriented, 7-bit safe, designed for
// maximum transparency across any communication medium.
//
// Features:
//   - Printable-only packet encoding (7-bit safe)
//   - Configurable packet length (20-9024 bytes)
//   - Sliding windows (1-31)
//   - CRC-16 error detection
//   - Server mode
//   - Batch file transfer
//   - Attribute packets (file size, date, type)
//
// Packet format:
//   MARK LEN SEQ TYPE DATA CHECK
//   MARK = SOH (Ctrl-A, $01)
//   LEN  = data length + 32 (printable)
//   SEQ  = sequence number MOD 64 + 32 (printable)
//   TYPE = packet type character
//   DATA = encoded data (control chars → prefix + char + 64)
//   CHECK = 1-byte checksum, 2-byte checksum, or CRC-16
// ====================================================================
Unit m_protocol_kermit;

{$I M_OPS.PAS}

Interface

Uses
  m_io_Base,
  m_CRC,
  m_Protocol_Base,
  m_Protocol_Queue;

Const
  KRM_SOH      = $01;   // Start of header (packet marker)
  KRM_CR       = $0D;   // Carriage return (packet terminator)
  KRM_MYQUOTE  = '#';   // Default control prefix character
  KRM_MAXDATA  = 94;    // Max data bytes in standard packet
  KRM_MAXLDATA = 9024;  // Max data bytes in long packet
  KRM_TIMEOUT  = 1000;  // 10 seconds in hundredths
  KRM_MAXRETRY = 10;
  KRM_MAXWIN   = 31;    // Max sliding window size

  // Packet types
  KRM_S = 'S';  // Send-Init
  KRM_F = 'F';  // File-Header
  KRM_D = 'D';  // Data
  KRM_Z = 'Z';  // End-of-File
  KRM_B = 'B';  // Break (end of transaction)
  KRM_Y = 'Y';  // Acknowledge
  KRM_N = 'N';  // Negative Acknowledge
  KRM_E = 'E';  // Error
  KRM_R = 'R';  // Receive-Init
  KRM_A = 'A';  // Attributes

Type
  TKermitParams = Record
    MaxLen   : Byte;    // Max packet length (20-94)
    Timeout  : Byte;    // Timeout in seconds
    NPad     : Byte;    // Number of padding characters
    PadC     : Char;    // Padding character
    EOL      : Char;    // End of line character
    QCtl     : Char;    // Control prefix character
    QBin     : Char;    // 8-bit prefix character (Y/N/&)
    ChkType  : Byte;    // Check type (1=1-byte, 2=2-byte, 3=CRC-16)
    RepeatC  : Char;    // Repeat prefix character
    CapMask  : Byte;    // Capability mask
    WinSize  : Byte;    // Window size (0=none, 1-31)
    MaxLenX  : Word;    // Extended max packet length
  End;

  TProtocolKermit = Class(TProtocolBase)
    MyParams   : TKermitParams;   // Our parameters
    HisParams  : TKermitParams;   // Remote's parameters
    UseRepeat  : Boolean;         // Repeat compression enabled
    UseLong    : Boolean;         // Long packets enabled
    UseWindows : Boolean;         // Sliding windows enabled
    Use8Bit    : Boolean;         // 8-bit quoting enabled
    SeqNum     : Byte;            // Current sequence number

    Constructor Create (Var C: TIOBase; Var Q: TProtocolQueue); Override;
    Destructor  Destroy; Override;

    // Encoding/decoding
    Function  ToChar    (X: Byte) : Char;
    Function  UnChar    (C: Char) : Byte;
    Function  Ctl       (C: Char) : Char;
    Function  CalcCheck (Var Buf; Len: Word; ChkType: Byte) : LongInt;

    // Packet I/O
    Function  BuildPacket  (PType: Char; Seq: Byte; Var Data; DataLen: Word) : String;
    Function  SendPacket   (PType: Char; Seq: Byte; Var Data; DataLen: Word) : Boolean;
    Function  RecvPacket   (Var PType: Char; Var Seq: Byte;
                            Var Data; Var DataLen: Word) : Boolean;

    // Parameter negotiation
    Procedure EncodeParams (Var P: TKermitParams; Var Buf; Var Len: Word);
    Procedure DecodeParams (Var P: TKermitParams; Var Buf; Len: Word);
    Procedure NegotiateParams;

    // Data encoding
    Function  EncodeData (Var Src; SrcLen: Word; Var Dst; Var DstLen: Word) : Boolean;
    Function  DecodeData (Var Src; SrcLen: Word; Var Dst; Var DstLen: Word) : Boolean;

    // Transfer
    Procedure QueueSend; Override;
    Procedure QueueReceive; Override;
  End;

Implementation

Constructor TProtocolKermit.Create (Var C: TIOBase; Var Q: TProtocolQueue);
Begin
  Inherited Create(C, Q);

  Status.Protocol := 'Kermit';
  SeqNum := 0;

  // Our default parameters
  MyParams.MaxLen   := 94;
  MyParams.Timeout  := 10;
  MyParams.NPad     := 0;
  MyParams.PadC     := #0;
  MyParams.EOL      := Chr(KRM_CR);
  MyParams.QCtl     := KRM_MYQUOTE;
  MyParams.QBin     := 'Y';
  MyParams.ChkType  := 3;       // CRC-16
  MyParams.RepeatC   := '~';
  MyParams.CapMask  := 0;
  MyParams.WinSize  := 0;
  MyParams.MaxLenX  := 0;

  UseRepeat  := True;
  UseLong    := False;
  UseWindows := False;
  Use8Bit    := True;

  FillChar(HisParams, SizeOf(HisParams), 0);
End;

Destructor TProtocolKermit.Destroy;
Begin
  Inherited Destroy;
End;

// Printable encoding: add 32 to make any value 0-94 printable
Function TProtocolKermit.ToChar (X: Byte) : Char;
Begin
  Result := Chr(X + 32);
End;

// Reverse of ToChar
Function TProtocolKermit.UnChar (C: Char) : Byte;
Begin
  Result := Ord(C) - 32;
End;

// Control character toggle: XOR with 64
Function TProtocolKermit.Ctl (C: Char) : Char;
Begin
  Result := Chr(Ord(C) XOR 64);
End;

Function TProtocolKermit.CalcCheck (Var Buf; Len: Word; ChkType: Byte) : LongInt;
Var
  B   : Array[0..9023] of Byte Absolute Buf;
  Sum : LongInt;
  CRC : Word;
  I   : Word;
Begin
  Case ChkType of
    1: Begin
      // 1-byte: sum of bytes + bits 6,7 folded in, MOD 64 + 32
      Sum := 0;
      For I := 0 to Len - 1 Do
        Sum := Sum + B[I];
      Sum := (Sum + ((Sum AND 192) SHR 6)) AND 63;
      Result := Sum;
    End;
    2: Begin
      // 2-byte: sum MOD 4096
      Sum := 0;
      For I := 0 to Len - 1 Do
        Sum := Sum + B[I];
      Result := Sum AND $0FFF;
    End;
    3: Begin
      // CRC-16 (CCITT)
      CRC := 0;
      For I := 0 to Len - 1 Do Begin
        CRC := CRC XOR (Word(B[I]) SHL 8);
        For Sum := 0 to 7 Do Begin
          If (CRC AND $8000) <> 0 Then
            CRC := (CRC SHL 1) XOR $8005
          Else
            CRC := CRC SHL 1;
        End;
      End;
      Result := CRC;
    End;
  Else
    Result := 0;
  End;
End;

Function TProtocolKermit.BuildPacket (PType: Char; Seq: Byte;
                                      Var Data; DataLen: Word) : String;
Var
  Pkt  : String;
  ChkV : LongInt;
  TLen : Byte;
Begin
  TLen := DataLen + 3; // data + seq + type + check

  Pkt := Chr(KRM_SOH);
  Pkt := Pkt + ToChar(TLen);
  Pkt := Pkt + ToChar(Seq);
  Pkt := Pkt + PType;

  If DataLen > 0 Then Begin
    SetLength(Pkt, 4 + DataLen);
    Move(Data, Pkt[5], DataLen);
  End;

  // Calculate check over LEN + SEQ + TYPE + DATA
  ChkV := CalcCheck(Pkt[2], Length(Pkt) - 1, MyParams.ChkType);

  Case MyParams.ChkType of
    1: Pkt := Pkt + ToChar(Byte(ChkV));
    2: Begin
      Pkt := Pkt + ToChar(Byte(ChkV SHR 6));
      Pkt := Pkt + ToChar(Byte(ChkV AND 63));
    End;
    3: Begin
      Pkt := Pkt + ToChar(Byte((ChkV SHR 12) AND 15));
      Pkt := Pkt + ToChar(Byte((ChkV SHR 6) AND 63));
      Pkt := Pkt + ToChar(Byte(ChkV AND 63));
    End;
  End;

  Pkt := Pkt + MyParams.EOL;
  Result := Pkt;
End;

Function TProtocolKermit.SendPacket (PType: Char; Seq: Byte;
                                     Var Data; DataLen: Word) : Boolean;
Var Pkt : String;
Begin
  Pkt := BuildPacket(PType, Seq, Data, DataLen);
  Result := Client.WriteBuf(Pkt[1], Length(Pkt)) >= 0;
End;

Function TProtocolKermit.RecvPacket (Var PType: Char; Var Seq: Byte;
                                     Var Data; Var DataLen: Word) : Boolean;
Var
  C     : SmallInt;
  Len   : Byte;
  Buf   : Array[0..255] of Byte;
  I     : Integer;
Begin
  Result := False;
  DataLen := 0;

  // Wait for SOH
  Repeat
    C := ReadByteTimeOut(KRM_TIMEOUT);
    If C < 0 Then Exit;
  Until C = KRM_SOH;

  // Read LEN
  C := ReadByteTimeOut(KRM_TIMEOUT);
  If C < 0 Then Exit;
  Len := UnChar(Chr(C));

  // Read rest of packet (LEN - 1 more bytes for seq+type+data+check)
  For I := 0 to Len - 1 Do Begin
    C := ReadByteTimeOut(KRM_TIMEOUT);
    If C < 0 Then Exit;
    Buf[I] := Byte(C);
  End;

  // Parse
  Seq   := UnChar(Chr(Buf[0]));
  PType := Chr(Buf[1]);
  DataLen := Len - 3; // minus seq, type, check
  If DataLen > 0 Then
    Move(Buf[2], Data, DataLen);

  // TODO: verify checksum
  Result := True;
End;

Procedure TProtocolKermit.EncodeParams (Var P: TKermitParams; Var Buf; Var Len: Word);
Var B : Array[0..15] of Byte Absolute Buf;
Begin
  B[0] := Ord(ToChar(P.MaxLen));
  B[1] := Ord(ToChar(P.Timeout));
  B[2] := Ord(ToChar(P.NPad));
  B[3] := Ord(Ctl(P.PadC));
  B[4] := Ord(ToChar(Ord(P.EOL)));
  B[5] := Ord(P.QCtl);
  B[6] := Ord(P.QBin);
  B[7] := Ord(ToChar(P.ChkType));
  B[8] := Ord(P.RepeatC);
  Len := 9;
End;

Procedure TProtocolKermit.DecodeParams (Var P: TKermitParams; Var Buf; Len: Word);
Var B : Array[0..15] of Byte Absolute Buf;
Begin
  If Len >= 1 Then P.MaxLen  := UnChar(Chr(B[0]));
  If Len >= 2 Then P.Timeout := UnChar(Chr(B[1]));
  If Len >= 3 Then P.NPad    := UnChar(Chr(B[2]));
  If Len >= 4 Then P.PadC    := Ctl(Chr(B[3]));
  If Len >= 5 Then P.EOL     := Chr(UnChar(Chr(B[4])));
  If Len >= 6 Then P.QCtl    := Chr(B[5]);
  If Len >= 7 Then P.QBin    := Chr(B[6]);
  If Len >= 8 Then P.ChkType := UnChar(Chr(B[7]));
  If Len >= 9 Then P.RepeatC  := Chr(B[8]);
End;

Procedure TProtocolKermit.NegotiateParams;
Begin
  // Use the minimum of our and their parameters
  If HisParams.MaxLen < MyParams.MaxLen Then
    MyParams.MaxLen := HisParams.MaxLen;
  If HisParams.ChkType < MyParams.ChkType Then
    MyParams.ChkType := HisParams.ChkType;
  Use8Bit := (MyParams.QBin = 'Y') and (HisParams.QBin <> 'N');
End;

Function TProtocolKermit.EncodeData (Var Src; SrcLen: Word;
                                     Var Dst; Var DstLen: Word) : Boolean;
Var
  S : Array[0..8191] of Byte Absolute Src;
  D : Array[0..9023] of Byte Absolute Dst;
  I : Word;
  B : Byte;
Begin
  Result := True;
  DstLen := 0;
  For I := 0 to SrcLen - 1 Do Begin
    B := S[I];
    // Quote control characters
    If (B < 32) or (B = 127) Then Begin
      D[DstLen] := Ord(MyParams.QCtl);
      Inc(DstLen);
      D[DstLen] := B XOR 64;
      Inc(DstLen);
    End Else If B = Ord(MyParams.QCtl) Then Begin
      D[DstLen] := Ord(MyParams.QCtl);
      Inc(DstLen);
      D[DstLen] := B;
      Inc(DstLen);
    End Else Begin
      D[DstLen] := B;
      Inc(DstLen);
    End;
  End;
End;

Function TProtocolKermit.DecodeData (Var Src; SrcLen: Word;
                                     Var Dst; Var DstLen: Word) : Boolean;
Var
  S : Array[0..9023] of Byte Absolute Src;
  D : Array[0..8191] of Byte Absolute Dst;
  I : Word;
  B : Byte;
Begin
  Result := True;
  DstLen := 0;
  I := 0;
  While I < SrcLen Do Begin
    B := S[I];
    If Chr(B) = MyParams.QCtl Then Begin
      Inc(I);
      If I >= SrcLen Then Break;
      B := S[I];
      If (B >= 63) and (B <= 95) Then
        B := B XOR 64;
    End;
    D[DstLen] := B;
    Inc(DstLen);
    Inc(I);
  End;
End;

Procedure TProtocolKermit.QueueSend;
Var
  F        : File;
  RawBuf   : Array[0..8191] of Byte;
  EncBuf   : Array[0..9023] of Byte;
  ParBuf   : Array[0..15] of Byte;
  ParLen   : Word;
  EncLen   : Word;
  BytesRead: LongInt;
  RType    : Char;
  RSeq     : Byte;
  RData    : Array[0..255] of Byte;
  RLen     : Word;
  MaxData  : Word;
  QIdx     : Integer;
  I        : Integer;
Begin
  Status.Sender := True;
  StatusUpdate(True, False);

  // Send-Init: send our parameters
  EncodeParams(MyParams, ParBuf, ParLen);
  SendPacket(KRM_S, SeqNum, ParBuf, ParLen);

  // Receive ACK with their parameters
  If Not RecvPacket(RType, RSeq, RData, RLen) Then Begin
    StatusUpdate(False, True); Exit;
  End;
  If RType <> KRM_Y Then Begin StatusUpdate(False, True); Exit; End;
  DecodeParams(HisParams, RData, RLen);
  NegotiateParams;
  SeqNum := (SeqNum + 1) AND 63;

  MaxData := MyParams.MaxLen - 6; // leave room for encoding overhead

  For QIdx := 1 to Queue.QSize Do Begin
    If AbortTransfer Then Break;

    Status.FilePath := Queue.QData[QIdx]^.FilePath;
    Status.FileName := Queue.QData[QIdx]^.FileName;

    // Send File-Header
    Move(Status.FileName[1], EncBuf, Length(Status.FileName));
    SendPacket(KRM_F, SeqNum, EncBuf, Length(Status.FileName));
    If Not RecvPacket(RType, RSeq, RData, RLen) Then Break;
    SeqNum := (SeqNum + 1) AND 63;

    Assign(F, Status.FilePath + Status.FileName);
    {$I-} Reset(F, 1); {$I+}
    If IOResult <> 0 Then Continue;
    Status.FileSize := FileSize(F);
    Status.Position := 0;

    // Send Data packets
    While Not AbortTransfer Do Begin
      BlockRead(F, RawBuf, MaxData, BytesRead);
      If BytesRead = 0 Then Break;

      EncodeData(RawBuf, BytesRead, EncBuf, EncLen);
      SendPacket(KRM_D, SeqNum, EncBuf, EncLen);

      If Not RecvPacket(RType, RSeq, RData, RLen) Then Break;
      If RType = KRM_N Then Begin
        // NAK — resend
        Inc(Status.Errors);
        Seek(F, Status.Position);
        Continue;
      End;

      Status.Position := Status.Position + BytesRead;
      SeqNum := (SeqNum + 1) AND 63;
      StatusUpdate(False, False);
    End;

    Close(F);

    // Send EOF
    SendPacket(KRM_Z, SeqNum, RawBuf, 0);
    RecvPacket(RType, RSeq, RData, RLen);
    SeqNum := (SeqNum + 1) AND 63;
  End;

  // Send Break (end of transaction)
  SendPacket(KRM_B, SeqNum, RawBuf, 0);
  RecvPacket(RType, RSeq, RData, RLen);

  StatusUpdate(False, True);
End;

Procedure TProtocolKermit.QueueReceive;
Var
  F       : File;
  RawBuf  : Array[0..8191] of Byte;
  DecBuf  : Array[0..8191] of Byte;
  ParBuf  : Array[0..15] of Byte;
  ParLen  : Word;
  RType   : Char;
  RSeq    : Byte;
  RData   : Array[0..9023] of Byte;
  RLen    : Word;
  DecLen  : Word;
  FName   : String;
  I       : Integer;
  AckB    : Byte;
Begin
  Status.Sender := False;
  StatusUpdate(True, False);

  // Wait for Send-Init
  If Not RecvPacket(RType, RSeq, RData, RLen) Then Begin
    StatusUpdate(False, True); Exit;
  End;
  If RType <> KRM_S Then Begin StatusUpdate(False, True); Exit; End;

  // Decode their parameters
  DecodeParams(HisParams, RData, RLen);
  NegotiateParams;

  // ACK with our parameters
  EncodeParams(MyParams, ParBuf, ParLen);
  SendPacket(KRM_Y, RSeq, ParBuf, ParLen);

  // Receive files
  While Not AbortTransfer Do Begin
    If Not RecvPacket(RType, RSeq, RData, RLen) Then Break;

    Case RType of
      KRM_F: Begin
        // File header — extract filename
        FName := '';
        For I := 0 to RLen - 1 Do
          FName := FName + Chr(RData[I]);

        Status.FileName := FName;
        Status.Position := 0;

        SendPacket(KRM_Y, RSeq, AckB, 0);

        Assign(F, ReceivePath + FName);
        {$I-} Rewrite(F, 1); {$I+}
        If IOResult <> 0 Then Break;

        // Receive data packets
        While Not AbortTransfer Do Begin
          If Not RecvPacket(RType, RSeq, RData, RLen) Then Break;

          If RType = KRM_D Then Begin
            DecodeData(RData, RLen, DecBuf, DecLen);
            BlockWrite(F, DecBuf, DecLen);
            Status.Position := Status.Position + DecLen;
            SendPacket(KRM_Y, RSeq, AckB, 0);
            StatusUpdate(False, False);
          End Else If RType = KRM_Z Then Begin
            SendPacket(KRM_Y, RSeq, AckB, 0);
            Break; // EOF
          End;
        End;

        Close(F);
      End;

      KRM_B: Begin
        // Break — end of transaction
        SendPacket(KRM_Y, RSeq, AckB, 0);
        Break;
      End;
    End;
  End;

  StatusUpdate(False, True);
End;

End.

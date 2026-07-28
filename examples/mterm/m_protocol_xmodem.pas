// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
// Updated 2026 — Mystic BBS IRC Fork Contributors (GPLv3)
// Full Xmodem implementation: Checksum, CRC-16, 1K blocks
// ====================================================================
Unit m_Protocol_XModem;

{$I M_OPS.PAS}

Interface

Uses
  m_io_Base,
  m_CRC,
  m_Protocol_Base,
  m_Protocol_Queue;

Const
  XM_SOH   = $01;  // 128-byte block header
  XM_STX   = $02;  // 1024-byte block header
  XM_EOT   = $04;  // end of transmission
  XM_ACK   = $06;  // acknowledge
  XM_NAK   = $15;  // negative acknowledge (also starts checksum mode)
  XM_CAN   = $18;  // cancel transfer
  XM_CRCCH = $43;  // 'C' — start CRC mode
  XM_SUB   = $1A;  // padding byte (CP/M EOF)

  XM_TIMEOUT   = 1000;  // 10 seconds in hundredths
  XM_MAXERRORS = 10;
  XM_MAXRETRY  = 10;

Type
  TProtocolXmodem = Class(TProtocolBase)
    DoCRC : Boolean;   // True = CRC-16, False = checksum
    Do1K  : Boolean;   // True = 1K blocks (STX), False = 128-byte (SOH)

    Constructor Create (Var C: TIOBase; Var Q: TProtocolQueue); Override;
    Destructor  Destroy; Override;

    Function  CalcChecksum  (Var Buf; Size: Word) : Byte;
    Function  CalcCRC16     (Var Buf; Size: Word) : Word;
    Procedure SendBlock     (Var Buf; Size: Word; BlockNum: Byte);
    Function  ReceiveBlock  (Var Buf; Var Size: Word; Var BlockNum: Byte) : Boolean;
    Procedure SendCAN;

    Procedure QueueSend; Override;
    Procedure QueueReceive; Override;
  End;

Implementation

Constructor TProtocolXmodem.Create (Var C: TIOBase; Var Q: TProtocolQueue);
Begin
  Inherited Create(C, Q);

  Status.Protocol := 'Xmodem';
  DoCRC := True;
  Do1K  := False;
End;

Destructor TProtocolXmodem.Destroy;
Begin
  Inherited Destroy;
End;

Function TProtocolXmodem.CalcChecksum (Var Buf; Size: Word) : Byte;
Var
  B   : Array[0..1023] of Byte Absolute Buf;
  Sum : Word;
  I   : Word;
Begin
  Sum := 0;
  For I := 0 to Size - 1 Do
    Sum := (Sum + B[I]) AND $FF;
  Result := Byte(Sum);
End;

Function TProtocolXmodem.CalcCRC16 (Var Buf; Size: Word) : Word;
Var
  B   : Array[0..1023] of Byte Absolute Buf;
  CRC : Word;
  I   : Word;
  J   : Byte;
Begin
  CRC := 0;
  For I := 0 to Size - 1 Do Begin
    CRC := CRC XOR (Word(B[I]) SHL 8);
    For J := 0 to 7 Do Begin
      If (CRC AND $8000) <> 0 Then
        CRC := (CRC SHL 1) XOR $1021
      Else
        CRC := CRC SHL 1;
    End;
  End;
  Result := CRC;
End;

Procedure TProtocolXmodem.SendCAN;
Var B : Byte;
Begin
  B := XM_CAN;
  Client.WriteBuf(B, 1);
  Client.WriteBuf(B, 1);
  Client.WriteBuf(B, 1);
End;

Procedure TProtocolXmodem.SendBlock (Var Buf; Size: Word; BlockNum: Byte);
Var
  Hdr  : Byte;
  Comp : Byte;
  ChkB : Byte;
  CRC  : Word;
Begin
  // Header
  If Size = 1024 Then Hdr := XM_STX
  Else Hdr := XM_SOH;
  Client.WriteBuf(Hdr, 1);

  // Block number + complement
  Client.WriteBuf(BlockNum, 1);
  Comp := 255 - BlockNum;
  Client.WriteBuf(Comp, 1);

  // Data
  Client.WriteBuf(Buf, Size);

  // Check value
  If DoCRC Then Begin
    CRC := CalcCRC16(Buf, Size);
    Hdr := Hi(CRC);
    Client.WriteBuf(Hdr, 1);
    Hdr := Lo(CRC);
    Client.WriteBuf(Hdr, 1);
  End Else Begin
    ChkB := CalcChecksum(Buf, Size);
    Client.WriteBuf(ChkB, 1);
  End;
End;

Function TProtocolXmodem.ReceiveBlock (Var Buf; Var Size: Word; Var BlockNum: Byte) : Boolean;
Var
  B        : Array[0..1023] of Byte Absolute Buf;
  Hdr      : SmallInt;
  BNum     : SmallInt;
  BComp    : SmallInt;
  ChkB     : Byte;
  CRCHi    : SmallInt;
  CRCLo    : SmallInt;
  RecvCRC  : Word;
  CalcCRCV : Word;
  I        : Word;
Begin
  Result := False;

  // Read header byte
  Hdr := ReadByteTimeOut(XM_TIMEOUT);
  If Hdr < 0 Then Exit;

  If Hdr = XM_EOT Then Begin
    // End of transmission
    ChkB := XM_ACK;
    Client.WriteBuf(ChkB, 1);
    EndTransfer := True;
    Result := True;
    Size := 0;
    Exit;
  End;

  If Hdr = XM_CAN Then Begin
    EndTransfer := True;
    Exit;
  End;

  If Hdr = XM_SOH Then Size := 128
  Else If Hdr = XM_STX Then Size := 1024
  Else Exit;

  // Block number
  BNum := ReadByteTimeOut(XM_TIMEOUT);
  If BNum < 0 Then Exit;
  BComp := ReadByteTimeOut(XM_TIMEOUT);
  If BComp < 0 Then Exit;

  // Verify complement
  If (BNum + BComp) AND $FF <> $FF Then Exit;
  BlockNum := Byte(BNum);

  // Read data
  For I := 0 to Size - 1 Do Begin
    Hdr := ReadByteTimeOut(XM_TIMEOUT);
    If Hdr < 0 Then Exit;
    B[I] := Byte(Hdr);
  End;

  // Verify check
  If DoCRC Then Begin
    CRCHi := ReadByteTimeOut(XM_TIMEOUT);
    CRCLo := ReadByteTimeOut(XM_TIMEOUT);
    If (CRCHi < 0) or (CRCLo < 0) Then Exit;
    RecvCRC := (Word(CRCHi) SHL 8) OR Word(CRCLo);
    CalcCRCV := CalcCRC16(Buf, Size);
    If RecvCRC <> CalcCRCV Then Exit;
  End Else Begin
    Hdr := ReadByteTimeOut(XM_TIMEOUT);
    If Hdr < 0 Then Exit;
    ChkB := CalcChecksum(Buf, Size);
    If Byte(Hdr) <> ChkB Then Exit;
  End;

  Result := True;
End;

Procedure TProtocolXmodem.QueueSend;
Var
  F        : File;
  Buf      : Array[0..1023] of Byte;
  BufSize  : Word;
  BlockNum : Byte;
  Response : SmallInt;
  Errors   : Word;
  BytesRead: LongInt;
Begin
  If Queue.QSize = 0 Then Exit;

  Status.Sender   := True;
  Status.FilePath  := Queue.QData[1]^.FilePath;
  Status.FileName  := Queue.QData[1]^.FileName;
  StatusUpdate(True, False);

  Assign(F, Status.FilePath + Status.FileName);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Begin
    StatusUpdate(False, True);
    Exit;
  End;

  Status.FileSize := FileSize(F);
  Status.Position := 0;
  BlockNum := 1;
  Errors := 0;

  If Do1K Then BufSize := 1024
  Else BufSize := 128;

  // Wait for receiver start signal
  Response := ReadByteTimeOut(6000); // 60 seconds
  If Response < 0 Then Begin Close(F); StatusUpdate(False, True); Exit; End;
  DoCRC := (Response = XM_CRCCH);

  While Not AbortTransfer Do Begin
    // Read data from file
    FillChar(Buf, BufSize, XM_SUB);
    BlockRead(F, Buf, BufSize, BytesRead);

    If BytesRead = 0 Then Begin
      // Send EOT
      Buf[0] := XM_EOT;
      Client.WriteBuf(Buf[0], 1);
      Response := ReadByteTimeOut(XM_TIMEOUT);
      Break;
    End;

    // Send block
    SendBlock(Buf, BufSize, BlockNum);
    StatusUpdate(False, False);

    // Wait for ACK
    Response := ReadByteTimeOut(XM_TIMEOUT);
    If Response = XM_ACK Then Begin
      Inc(BlockNum);
      Status.Position := Status.Position + BytesRead;
      Errors := 0;
    End Else Begin
      // NAK or timeout — resend
      Inc(Errors);
      Status.Errors := Errors;
      If Errors >= XM_MAXERRORS Then Begin
        SendCAN;
        Break;
      End;
      // Seek back
      Seek(F, Status.Position);
    End;
  End;

  Close(F);
  StatusUpdate(False, True);
End;

Procedure TProtocolXmodem.QueueReceive;
Var
  F        : File;
  Buf      : Array[0..1023] of Byte;
  BufSize  : Word;
  BlockNum : Byte;
  ExpBlock : Byte;
  Errors   : Word;
  StartB   : Byte;
  GotBlock : Boolean;
Begin
  Status.Sender := False;
  StatusUpdate(True, False);

  Assign(F, ReceivePath + 'xmodem.tmp');
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then Begin
    StatusUpdate(False, True);
    Exit;
  End;

  ExpBlock := 1;
  Errors := 0;
  Status.Position := 0;

  // Send start signal
  If DoCRC Then StartB := XM_CRCCH
  Else StartB := XM_NAK;
  Client.WriteBuf(StartB, 1);

  While Not AbortTransfer Do Begin
    GotBlock := ReceiveBlock(Buf, BufSize, BlockNum);

    If EndTransfer Then Break;  // EOT received

    If GotBlock Then Begin
      If BlockNum = ExpBlock Then Begin
        BlockWrite(F, Buf, BufSize);
        Status.Position := Status.Position + BufSize;
        Inc(ExpBlock);
        Errors := 0;
        StartB := XM_ACK;
        Client.WriteBuf(StartB, 1);
      End Else Begin
        // Duplicate block — ACK but don't write
        StartB := XM_ACK;
        Client.WriteBuf(StartB, 1);
      End;
    End Else Begin
      Inc(Errors);
      Status.Errors := Errors;
      If Errors >= XM_MAXERRORS Then Begin
        SendCAN;
        Break;
      End;
      StartB := XM_NAK;
      Client.WriteBuf(StartB, 1);
    End;

    StatusUpdate(False, False);
  End;

  Close(F);
  StatusUpdate(False, True);
End;

End.

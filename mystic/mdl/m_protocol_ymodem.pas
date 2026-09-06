// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
// Updated 2026 — Mystic BBS IRC Fork Contributors (GPLv3)
// Full Ymodem implementation: batch transfers, Block 0 file info
// Ymodem-G variant (streaming, no per-block ACK)
// ====================================================================
Unit m_Protocol_YModem;

{$I M_OPS.PAS}

Interface

Uses
  DOS,
  m_io_Base,
  m_Strings,
  m_FileIO,
  m_Protocol_Queue,
  m_Protocol_Xmodem;

Type
  TProtocolYmodem = Class(TProtocolXmodem)
    UseG : Boolean;   // Ymodem-G: streaming mode (no per-block ACK)

    Constructor Create (Var C: TIOBase; Var Q: TProtocolQueue); Override;
    Destructor  Destroy; Override;

    Procedure SendBlock0    (FName: String; FSize: Int64);
    Function  ReceiveBlock0 (Var FName: String; Var FSize: Int64) : Boolean;
    Procedure SendEndBatch;

    Procedure QueueSend; Override;
    Procedure QueueReceive; Override;
  End;

Implementation

Constructor TProtocolYModem.Create (Var C: TIOBase; Var Q: TProtocolQueue);
Begin
  Inherited Create(C, Q);

  Status.Protocol := 'Ymodem';
  DoCRC := True;
  Do1K  := True;
  UseG  := False;
End;

Destructor TProtocolYModem.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TProtocolYmodem.SendBlock0 (FName: String; FSize: Int64);
// Block 0: filename + size as null-terminated strings in 128-byte block
Var
  Buf : Array[0..127] of Byte;
  Pos : Integer;
  S   : String;
  I   : Integer;
Begin
  FillChar(Buf, 128, 0);
  Pos := 0;

  // Filename (null-terminated)
  For I := 1 to Length(FName) Do Begin
    If Pos < 127 Then Begin
      Buf[Pos] := Ord(FName[I]);
      Inc(Pos);
    End;
  End;
  Buf[Pos] := 0;
  Inc(Pos);

  // File size as decimal string (null-terminated)
  Str(FSize, S);
  For I := 1 to Length(S) Do Begin
    If Pos < 127 Then Begin
      Buf[Pos] := Ord(S[I]);
      Inc(Pos);
    End;
  End;
  Buf[Pos] := 0;

  SendBlock(Buf, 128, 0);
End;

Function TProtocolYmodem.ReceiveBlock0 (Var FName: String; Var FSize: Int64) : Boolean;
// Parse Block 0: extract filename and size
Var
  Buf      : Array[0..127] of Byte;
  Size     : Word;
  BlockNum : Byte;
  Pos      : Integer;
  SizeStr  : String;
  Code     : Integer;
Begin
  Result := False;
  FName := '';
  FSize := 0;

  Size := 128;
  If Not ReceiveBlock(Buf, Size, BlockNum) Then Exit;
  If BlockNum <> 0 Then Exit;

  // Extract filename (null-terminated)
  Pos := 0;
  While (Pos < 128) and (Buf[Pos] <> 0) Do Begin
    FName := FName + Chr(Buf[Pos]);
    Inc(Pos);
  End;

  // Empty filename = end of batch
  If FName = '' Then Begin
    Result := True;
    Exit;
  End;

  // Extract size (null-terminated decimal)
  Inc(Pos); // skip null after filename
  SizeStr := '';
  While (Pos < 128) and (Buf[Pos] <> 0) and (Buf[Pos] <> Ord(' ')) Do Begin
    SizeStr := SizeStr + Chr(Buf[Pos]);
    Inc(Pos);
  End;
  Val(SizeStr, FSize, Code);

  Result := True;
End;

Procedure TProtocolYmodem.SendEndBatch;
// Send empty Block 0 to signal end of batch
Var Buf : Array[0..127] of Byte;
Begin
  FillChar(Buf, 128, 0);
  SendBlock(Buf, 128, 0);
End;

Procedure TProtocolYmodem.QueueSend;
Var
  F        : File;
  Buf      : Array[0..1023] of Byte;
  BufSize  : Word;
  BlockNum : Byte;
  Response : SmallInt;
  Errors   : Word;
  BytesRead: LongInt;
  QIdx     : Integer;
Begin
  Status.Sender := True;
  StatusUpdate(True, False);

  If Do1K Then BufSize := 1024
  Else BufSize := 128;

  // Wait for receiver 'C'
  Response := ReadByteTimeOut(6000);
  If Response < 0 Then Begin StatusUpdate(False, True); Exit; End;
  DoCRC := (Response = XM_CRCCH);

  For QIdx := 1 to Queue.QSize Do Begin
    If AbortTransfer Then Break;

    Status.FilePath := Queue.QData[QIdx]^.FilePath;
    Status.FileName := Queue.QData[QIdx]^.FileName;

    Assign(F, Status.FilePath + Status.FileName);
    {$I-} Reset(F, 1); {$I+}
    If IOResult <> 0 Then Continue;
    Status.FileSize := FileSize(F);
    Status.Position := 0;

    // Send Block 0 with file info
    SendBlock0(Status.FileName, Status.FileSize);
    Response := ReadByteTimeOut(XM_TIMEOUT);
    If Response <> XM_ACK Then Begin Close(F); Continue; End;

    // Wait for 'C' to start data
    Response := ReadByteTimeOut(XM_TIMEOUT);
    If (Response <> XM_CRCCH) and (Response <> XM_NAK) Then Begin Close(F); Continue; End;

    BlockNum := 1;
    Errors := 0;

    While Not AbortTransfer Do Begin
      FillChar(Buf, BufSize, XM_SUB);
      BlockRead(F, Buf, BufSize, BytesRead);

      If BytesRead = 0 Then Begin
        Buf[0] := XM_EOT;
        Client.WriteBuf(Buf[0], 1);
        Response := ReadByteTimeOut(XM_TIMEOUT);
        Break;
      End;

      SendBlock(Buf, BufSize, BlockNum);

      If Not UseG Then Begin
        Response := ReadByteTimeOut(XM_TIMEOUT);
        If Response = XM_ACK Then Begin
          Inc(BlockNum);
          Status.Position := Status.Position + BytesRead;
          Errors := 0;
        End Else Begin
          Inc(Errors);
          Status.Errors := Errors;
          If Errors >= XM_MAXERRORS Then Begin SendCAN; Break; End;
          Seek(F, Status.Position);
        End;
      End Else Begin
        Inc(BlockNum);
        Status.Position := Status.Position + BytesRead;
      End;

      StatusUpdate(False, False);
    End;

    Close(F);
  End;

  // End of batch
  Response := ReadByteTimeOut(XM_TIMEOUT);
  SendEndBatch;

  StatusUpdate(False, True);
End;

Procedure TProtocolYmodem.QueueReceive;
Var
  F        : File;
  Buf      : Array[0..1023] of Byte;
  BufSize  : Word;
  BlockNum : Byte;
  ExpBlock : Byte;
  Errors   : Word;
  FName    : String;
  FSize    : Int64;
  Written  : Int64;
  StartB   : Byte;
Begin
  Status.Sender := False;
  StatusUpdate(True, False);

  While Not AbortTransfer Do Begin
    // Request Block 0
    StartB := XM_CRCCH;
    Client.WriteBuf(StartB, 1);

    If Not ReceiveBlock0(FName, FSize) Then Break;
    If FName = '' Then Break; // end of batch

    Status.FileName := FName;
    Status.FileSize := FSize;
    Status.Position := 0;

    // ACK Block 0
    StartB := XM_ACK;
    Client.WriteBuf(StartB, 1);

    // Send 'C' to start data
    StartB := XM_CRCCH;
    Client.WriteBuf(StartB, 1);

    Assign(F, ReceivePath + FName);
    {$I-} Rewrite(F, 1); {$I+}
    If IOResult <> 0 Then Begin SendCAN; Break; End;

    ExpBlock := 1;
    Errors := 0;
    Written := 0;

    While Not AbortTransfer Do Begin
      If ReceiveBlock(Buf, BufSize, BlockNum) Then Begin
        If EndTransfer Then Break; // EOT
        If BlockNum = ExpBlock Then Begin
          // Truncate last block if we know file size
          If (FSize > 0) and (Written + BufSize > FSize) Then
            BufSize := Word(FSize - Written);
          BlockWrite(F, Buf, BufSize);
          Written := Written + BufSize;
          Status.Position := Written;
          Inc(ExpBlock);
          Errors := 0;
          StartB := XM_ACK;
          Client.WriteBuf(StartB, 1);
        End Else Begin
          StartB := XM_ACK;
          Client.WriteBuf(StartB, 1);
        End;
      End Else Begin
        Inc(Errors);
        Status.Errors := Errors;
        If Errors >= XM_MAXERRORS Then Begin SendCAN; Break; End;
        StartB := XM_NAK;
        Client.WriteBuf(StartB, 1);
      End;
      StatusUpdate(False, False);
    End;

    Close(F);
    EndTransfer := False; // reset for next file
  End;

  StatusUpdate(False, True);
End;

End.

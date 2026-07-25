// ====================================================================
// HSLINK — HS/Link File Transfer Program
// Mystic BBS IRC Fork — GPLv3
// ====================================================================
// Standalone HS/Link bidirectional file transfer for use with
// Mystic BBS Protocol Editor or any BBS that supports external
// protocol programs.
//
// Usage:
//   hslink -P<port> -B<baud> [-S<blocksize>] [-W<window>] [-R] <files...>
//   hslink -P<port> -B<baud> [-S<blocksize>] [-W<window>] [-R] -U<uploaddir>
//
// Protocol Editor setup:
//   Send: hslink -P%1 -B%2 %3
//   Recv: hslink -P%1 -B%2 -U%3
//
// Exit codes:
//   0 = success
//   1 = error
// ====================================================================
Program hslink;

{$I M_OPS.PAS}

Uses
  m_Types,
  DOS,
  m_Strings,
  m_FileIO,
  m_io_Base,
  {$IFDEF GO32V2}
  m_fossil,
  m_io_STDIO,
  {$ELSE}
  m_io_Sockets,
  {$ENDIF}
  m_Protocol_Base,
  m_Protocol_Queue,
  m_protocol_hslink;

Var
  Protocol   : TProtocolHSLink;
  Queue      : TProtocolQueue;
  {$IFDEF GO32V2}
  Client     : TIOBase;
  {$ELSE}
  Client     : TIOSocket;
  {$ENDIF}
  ClientBase : TIOBase;
  Port       : Word;
  Baud       : LongInt;
  BlockSize  : Word;
  WindowSize : Word;
  UseResume  : Boolean;
  Priority   : Boolean;
  DisableAck : Boolean;
  UploadDir  : String;
  IsSend     : Boolean;
  IsRecv     : Boolean;
  FileList   : Array[1..50] of String[80];
  FileCount  : Integer;
  I          : Integer;
  Param      : String;
  ExitOK     : Boolean;

Procedure Usage;
Begin
  WriteLn('HSLINK — HS/Link Bidirectional File Transfer');
  WriteLn('Mystic BBS IRC Fork — GPLv3');
  WriteLn;
  WriteLn('Usage:');
  WriteLn('  hslink -P<port> -B<baud> [options] <files...>    (send)');
  WriteLn('  hslink -P<port> -B<baud> [options] -U<dir>       (receive)');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -P<port>    COM port number or socket handle');
  WriteLn('  -B<baud>    Baud rate');
  WriteLn('  -S<size>    Block size (64-4096, default 1024)');
  WriteLn('  -W<wind>    Window size (0=infinite, default 4)');
  WriteLn('  -R          Enable crash recovery / resume');
  WriteLn('  -A          Disable ACK (streaming mode)');
  WriteLn('  -!          Take priority');
  WriteLn('  -U<dir>     Upload/receive directory');
  WriteLn;
  WriteLn('Protocol Editor:');
  WriteLn('  Send Command: hslink -P%1 -B%2 %3');
  WriteLn('  Recv Command: hslink -P%1 -B%2 -U%3');
  WriteLn;
  WriteLn('Exit: 0=success, 1=error');
  Halt(1);
End;

Procedure ParseParams;
Var
  S    : String;
  Code : Integer;
Begin
  Port       := 0;
  Baud       := 0;
  BlockSize  := 1024;
  WindowSize := 4;
  UseResume  := False;
  Priority   := False;
  DisableAck := False;
  UploadDir  := '';
  IsSend     := False;
  IsRecv     := False;
  FileCount  := 0;

  If ParamCount = 0 Then Usage;

  For I := 1 to ParamCount Do Begin
    S := ParamStr(I);

    If (Length(S) >= 2) and (S[1] = '-') Then Begin
      Case UpCase(S[2]) of
        'P': Val(Copy(S, 3, Length(S)), Port, Code);
        'B': Val(Copy(S, 3, Length(S)), Baud, Code);
        'S': Val(Copy(S, 3, Length(S)), BlockSize, Code);
        'W': Val(Copy(S, 3, Length(S)), WindowSize, Code);
        'R': UseResume := True;
        'A': DisableAck := True;
        '!': Priority := True;
        'U': Begin
          UploadDir := Copy(S, 3, Length(S));
          If (Length(UploadDir) > 0) and
             (UploadDir[Length(UploadDir)] <> PathSep) Then
            UploadDir := UploadDir + PathSep;
          IsRecv := True;
        End;
      End;
    End Else Begin
      // Filename or @filelist
      If S[1] = '@' Then Begin
        // Read file list from file
        // For now, treat as single filename
        Inc(FileCount);
        FileList[FileCount] := Copy(S, 2, Length(S));
      End Else Begin
        Inc(FileCount);
        FileList[FileCount] := S;
      End;
      IsSend := True;
    End;
  End;

  // Validate
  If Port = 0 Then Begin
    WriteLn('Error: -P<port> required');
    Halt(1);
  End;

  If (Not IsSend) and (Not IsRecv) Then Begin
    WriteLn('Error: specify files to send or -U<dir> to receive');
    Halt(1);
  End;

  // Block size bounds
  If BlockSize < 64 Then BlockSize := 64;
  If BlockSize > 4096 Then BlockSize := 4096;
End;

Begin
  WriteLn('HSLINK v1.0 — HS/Link Bidirectional Transfer');
  WriteLn;

  ParseParams;

  // Connect to the port
  {$IFDEF GO32V2}
  // DOS: use FOSSIL driver on COM port
  If Not Fossil_Init(Port - 1) Then Begin
    WriteLn('Error: FOSSIL driver not found on COM', Port);
    Halt(1);
  End;
  Client := TIOBase.Create;
  {$ELSE}
  // Win32/Linux: socket handle passed by BBS
  Client := TIOSocket.Create;
  TIOSocket(Client).SocketHandle := Port;
  {$ENDIF}

  Queue := TProtocolQueue.Create;

  // Queue files for sending
  If IsSend Then Begin
    For I := 1 to FileCount Do Begin
      If FileExist(FileList[I]) Then
        Queue.Add(True, JustPath(FileList[I]), JustFile(FileList[I]),
                  JustFile(FileList[I]))
      Else
        WriteLn('Warning: file not found: ', FileList[I]);
    End;
  End;

  // Create protocol
  ClientBase := Client;
  Protocol := TProtocolHSLink.Create(ClientBase, Queue);

  // Apply options
  Protocol.BlockSize   := BlockSize;
  Protocol.WindowSize  := WindowSize;
  Protocol.UseResume   := UseResume;
  Protocol.UsePriority := Priority;
  Protocol.DisableAck  := DisableAck;

  If IsRecv Then
    Protocol.ReceivePath := UploadDir;

  // Status display callback
  WriteLn('Block size: ', BlockSize);
  WriteLn('Window:     ', WindowSize);
  WriteLn('Resume:     ', UseResume);
  WriteLn;

  // Run transfer
  ExitOK := True;

  If IsSend and IsRecv Then Begin
    // Bidirectional — send and receive simultaneously
    WriteLn('Bidirectional transfer...');
    Protocol.QueueSend;
  End Else If IsSend Then Begin
    WriteLn('Sending ', FileCount, ' file(s)...');
    Protocol.QueueSend;
  End Else Begin
    WriteLn('Receiving to ', UploadDir, '...');
    Protocol.QueueReceive;
  End;

  If Protocol.Status.Errors > 0 Then Begin
    WriteLn('Transfer completed with ', Protocol.Status.Errors, ' error(s)');
    ExitOK := False;
  End Else
    WriteLn('Transfer complete.');

  Protocol.Free;
  Queue.Free;
  {$IFDEF GO32V2}
  Fossil_Deinit(Port - 1);
  {$ENDIF}
  Client.Free;

  If ExitOK Then
    Halt(0)
  Else
    Halt(1);
End.

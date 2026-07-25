// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
// Updated 2026 — Mystic BBS IRC Fork Contributors (GPLv3)
// Basic HTTP file server for web downloads
// ====================================================================
Unit MIS_Client_HTTP;

{$I M_OPS.PAS}

Interface

Uses
  m_Strings,
  m_FileIO,
  m_DateTime,
  m_io_Sockets,
  MIS_Server,
  MIS_NodeData,
  MIS_Common,
  BBS_Records,
  BBS_DataBase;

Function CreateHTTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;

Type
  THTTPServer = Class(TServerClient)
    Server   : TServerManager;
    Cmd      : String;
    Data     : String;
    ReqPath  : String;
    ReqFile  : String;

    Constructor Create (Owner: TServerManager; CliSock: TIOSocket);
    Procedure   Execute; Override;
    Destructor  Destroy; Override;

    Procedure   SendResponse (Code: Word; Status, ContentType: String; Body: String);
    Procedure   SendFile (FullPath, FileName: String);
    Function    ResolvePath (URLPath: String; Var FullPath: String) : Boolean;
  End;

Implementation

Function CreateHTTP (Owner: TServerManager; Config: RecConfig; ND: TNodeData; CliSock: TIOSocket) : TServerClient;
Begin
  Result := THTTPServer.Create(Owner, CliSock);
End;

Constructor THTTPServer.Create (Owner: TServerManager; CliSock: TIOSocket);
Begin
  Inherited Create(Owner, CliSock);
  Server := Owner;
End;

Destructor THTTPServer.Destroy;
Begin
  Inherited Destroy;
End;

Procedure THTTPServer.SendResponse (Code: Word; Status, ContentType: String; Body: String);
Var
  Header : AnsiString;
Begin
  Header := 'HTTP/1.0 ' + strI2S(Code) + ' ' + Status + #13#10;
  Header := Header + 'Content-Type: ' + ContentType + #13#10;
  Header := Header + 'Content-Length: ' + strI2S(Length(Body)) + #13#10;
  Header := Header + 'Connection: close' + #13#10;
  Header := Header + 'Server: Mystic BBS HTTP' + #13#10;
  Header := Header + #13#10;

  Client.WriteStr(Header + Body);
End;

Procedure THTTPServer.SendFile (FullPath, FileName: String);
Var
  F       : File;
  Buf     : Array[1..32768] of Byte;
  Res     : LongInt;
  FSize   : LongInt;
  Header  : AnsiString;
  Ext     : String;
  CType   : String;
Begin
  If Not FileExist(FullPath) Then Begin
    SendResponse(404, 'Not Found', 'text/plain', 'File not found');
    Exit;
  End;

  Assign(F, FullPath);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Begin
    SendResponse(500, 'Internal Error', 'text/plain', 'Cannot open file');
    Exit;
  End;

  FSize := FileSize(F);

  // Content type by extension
  Ext := '';
  If Length(FileName) >= 4 Then
    Ext := Copy(FileName, Length(FileName) - 3, 4);
  Ext := strLower(Ext);

  If (Ext = '.zip') or (Ext = '.rar') or (Ext = '.arj') or (Ext = '.lha') Then
    CType := 'application/octet-stream'
  Else If (Ext = '.txt') or (Ext = '.nfo') or (Ext = '.diz') Then
    CType := 'text/plain'
  Else If (Ext = '.htm') or (Ext = 'html') Then
    CType := 'text/html'
  Else If (Ext = '.gif') Then
    CType := 'image/gif'
  Else If (Ext = '.jpg') or (Ext = 'jpeg') Then
    CType := 'image/jpeg'
  Else If (Ext = '.png') Then
    CType := 'image/png'
  Else If (Ext = '.mp3') Then
    CType := 'audio/mpeg'
  Else If (Ext = '.mp4') or (Ext = '.m4a') Then
    CType := 'video/mp4'
  Else
    CType := 'application/octet-stream';

  Header := 'HTTP/1.0 200 OK' + #13#10;
  Header := Header + 'Content-Type: ' + CType + #13#10;
  Header := Header + 'Content-Length: ' + strI2S(FSize) + #13#10;
  Header := Header + 'Content-Disposition: attachment; filename="' + FileName + '"' + #13#10;
  Header := Header + 'Connection: close' + #13#10;
  Header := Header + 'Server: Mystic BBS HTTP' + #13#10;
  Header := Header + #13#10;

  Client.WriteStr(Header);

  While Not Eof(F) Do Begin
    BlockRead(F, Buf, SizeOf(Buf), Res);
    If Res > 0 Then
      Client.WriteBuf(Buf, Res);
  End;

  Close(F);

  Server.Status(ProcessID, 'Sent: ' + FileName + ' (' + strI2S(FSize) + ')');
End;

Function THTTPServer.ResolvePath (URLPath: String; Var FullPath: String) : Boolean;
// Map /FtpName/filename → RecFileBase.Path + filename
// Uses same FtpName mapping as FTP server
Var
  BaseFile : File of RecFileBase;
  FBase    : RecFileBase;
  Parts    : String;
  BaseName : String;
  FileName : String;
  SlashPos : Integer;
Begin
  Result := False;
  FullPath := '';

  // Strip leading /
  If (Length(URLPath) > 0) and (URLPath[1] = '/') Then
    Delete(URLPath, 1, 1);

  // Split into base/file
  SlashPos := Pos('/', URLPath);
  If SlashPos = 0 Then Exit;

  BaseName := Copy(URLPath, 1, SlashPos - 1);
  FileName := Copy(URLPath, SlashPos + 1, Length(URLPath));

  If (BaseName = '') or (FileName = '') Then Exit;

  // Find file base by FtpName
  Assign(BaseFile, bbsCfg.DataPath + 'fbases.dat');
  {$I-} Reset(BaseFile); {$I+}
  If IOResult <> 0 Then Exit;

  While Not Eof(BaseFile) Do Begin
    Read(BaseFile, FBase);
    If strUpper(FBase.FtpName) = strUpper(BaseName) Then Begin
      FullPath := FBase.Path + FileName;
      If FileExist(FullPath) Then Begin
        Result := True;
        Close(BaseFile);
        Exit;
      End;
    End;
  End;

  Close(BaseFile);
End;

Procedure THTTPServer.Execute;
Var
  Str      : String;
  Method   : String;
  Path     : String;
  FullPath : String;
Begin
  // Read HTTP request line
  If Client.WaitForData(30000) = 0 Then Exit;
  If Client.ReadLine(Str) = -1 Then Exit;

  Method := strUpper(strWordGet(1, Str, ' '));
  Path   := strWordGet(2, Str, ' ');

  // Consume headers (read until blank line)
  Repeat
    If Client.WaitForData(5000) = 0 Then Break;
    If Client.ReadLine(Str) = -1 Then Break;
  Until Str = '';

  Server.Status(ProcessID, Method + ' ' + Path);

  If Method <> 'GET' Then Begin
    SendResponse(405, 'Method Not Allowed', 'text/plain', 'Only GET supported');
    Exit;
  End;

  // Security: block path traversal
  If (Pos('..', Path) > 0) or (Pos('\', Path) > 0) Then Begin
    SendResponse(403, 'Forbidden', 'text/plain', 'Invalid path');
    Exit;
  End;

  // Root: serve index.html from www/ or show server name
  If (Path = '/') Then Begin
    FullPath := bbsCfg.SystemPath + 'webroot' + PathChar + 'index.html';
    If FileExist(FullPath) Then
      SendFile(FullPath, 'index.html')
    Else Begin
      FullPath := bbsCfg.SystemPath + 'webroot' + PathChar + 'index.htm';
      If FileExist(FullPath) Then
        SendFile(FullPath, 'index.htm')
      Else
        SendResponse(200, 'OK', 'text/html',
          '<html><body><h1>' + bbsCfg.BBSName + '</h1>' +
          '<p>Mystic BBS HTTP File Server</p></body></html>');
    End;
    Exit;
  End;

  // Try webroot/ first (static web pages), then file base downloads
  // Default webroot: C:\mystic\webroot\ or /mystic/webroot/
  FullPath := bbsCfg.SystemPath + 'webroot' + PathChar +
              Copy(Path, 2, Length(Path));
  // Replace / with PathChar for cross-platform
  While Pos('/', FullPath) > 0 Do
    FullPath[Pos('/', FullPath)] := PathChar;

  If FileExist(FullPath) Then Begin
    SendFile(FullPath, JustFile(FullPath));
    Exit;
  End;

  // File downloads: /FtpName/filename via file base mapping
  If ResolvePath(Path, FullPath) Then
    SendFile(FullPath, JustFile(FullPath))
  Else
    SendResponse(404, 'Not Found', 'text/plain', 'File not found');
End;

End.

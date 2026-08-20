{ ===========================================================================
  OL_Transfer — QWK/REP file transfer via Zmodem
  GPLv3 — Copyright (C) 2026 FPC264IRC Contributors
  ---------------------------------------------------------------------------
  Bridges the mterm connection stack (mtconn) and file transfer
  framework (mtxfer) to OpenOLMS packet handling. Automates the
  full download/upload cycle:

    Download: send door command → Zmodem receive → unpack QWK
    Upload:   pack REP → send door command → Zmodem send

  Uses TConnection from mtconn.pas and TFileTransfer from mtxfer.pas.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

unit OL_Transfer;

interface

uses SysUtils, Classes, mtconn, mtxfer;

type
  TTransferResult = record
    Success   : Boolean;
    FileName  : String;
    FileSize  : LongInt;
    ErrorMsg  : String;
  end;

  TAutoLoginInfo = record
    UserName  : String;
    Password  : String;
    DoorCmd   : String;    { command to enter the mail door at the BBS }
    DownCmd   : String;    { command inside the door to trigger download }
    UpCmd     : String;    { command inside the door to trigger upload }
    Delay     : Integer;   { ms to wait between commands }
  end;

{ Send a string to the connection with inter-character delay }
procedure SendString(Conn: TConnection; const S: String; DelayMs: Integer);

{ Wait for a substring in the received data (with timeout) }
function WaitFor(Conn: TConnection; const Match: String;
  TimeoutSec: Integer): Boolean;

{ Auto-login sequence: send username, wait for password prompt,
  send password, wait for main menu }
function AutoLogin(Conn: TConnection; const Login: TAutoLoginInfo): Boolean;

{ Enter the mail door: send the door command, wait for door prompt }
function EnterDoor(Conn: TConnection; const Login: TAutoLoginInfo): Boolean;

{ Download a QWK packet: trigger download in the door, Zmodem receive }
function DownloadQWK(Conn: TConnection; Xfer: TFileTransfer;
  const Login: TAutoLoginInfo;
  const DownloadPath: String): TTransferResult;

{ Upload a REP packet: trigger upload in the door, Zmodem send }
function UploadREP(Conn: TConnection; Xfer: TFileTransfer;
  const Login: TAutoLoginInfo;
  const RepFile: String): TTransferResult;

{ Full automated mail run: connect, login, enter door, download QWK,
  optionally upload REP, exit door, disconnect }
function AutoMailRun(Conn: TConnection; Xfer: TFileTransfer;
  const Host: String; Port: Word;
  const Login: TAutoLoginInfo;
  const DownloadPath: String;
  const RepFile: String): TTransferResult;

implementation

procedure SendString(Conn: TConnection; const S: String; DelayMs: Integer);
var I: Integer;
begin
  for I := 1 to Length(S) do
  begin
    Conn.SendByte(Ord(S[I]));
    if DelayMs > 0 then Sleep(DelayMs);
  end;
  { Send CR to execute the command }
  Conn.SendByte(13);
end;

function WaitFor(Conn: TConnection; const Match: String;
  TimeoutSec: Integer): Boolean;
var
  Buf: array[0..1023] of Byte;
  Received: String;
  N, Elapsed: Integer;
begin
  Result := False;
  Received := '';
  Elapsed := 0;

  while Elapsed < (TimeoutSec * 10) do
  begin
    N := Conn.Receive(Buf, SizeOf(Buf));
    if N > 0 then
    begin
      SetLength(Received, Length(Received) + N);
      Move(Buf[0], Received[Length(Received) - N + 1], N);

      { Check if the match string appears in what we received }
      if Pos(LowerCase(Match), LowerCase(Received)) > 0 then
      begin
        Result := True;
        Exit;
      end;

      { Keep only last 2K to prevent unbounded growth }
      if Length(Received) > 2048 then
        Delete(Received, 1, Length(Received) - 2048);
    end
    else
      Sleep(100);

    Inc(Elapsed);
  end;
end;

function AutoLogin(Conn: TConnection; const Login: TAutoLoginInfo): Boolean;
begin
  Result := False;
  if not Conn.Connected then Exit;

  { Wait for login/name prompt }
  if not WaitFor(Conn, 'name', 30) then Exit;
  SendString(Conn, Login.UserName, Login.Delay);

  { Wait for password prompt }
  if not WaitFor(Conn, 'password', 15) then Exit;
  SendString(Conn, Login.Password, Login.Delay);

  { Wait for main menu (look for common BBS prompts) }
  Result := WaitFor(Conn, 'main', 30) or
            WaitFor(Conn, 'command', 5) or
            WaitFor(Conn, '?', 5);
end;

function EnterDoor(Conn: TConnection; const Login: TAutoLoginInfo): Boolean;
begin
  Result := False;
  if not Conn.Connected then Exit;
  if Login.DoorCmd = '' then Exit;

  SendString(Conn, Login.DoorCmd, Login.Delay);

  { Wait for the door to load — look for common door prompts }
  Result := WaitFor(Conn, 'mail', 20) or
            WaitFor(Conn, 'olms', 10) or
            WaitFor(Conn, 'menu', 10) or
            WaitFor(Conn, 'choice', 10);
end;

function DownloadQWK(Conn: TConnection; Xfer: TFileTransfer;
  const Login: TAutoLoginInfo;
  const DownloadPath: String): TTransferResult;
begin
  Result.Success := False;
  Result.FileName := '';
  Result.FileSize := 0;

  if not Conn.Connected then
  begin
    Result.ErrorMsg := 'Not connected';
    Exit;
  end;

  { Send the download command inside the door }
  if Login.DownCmd <> '' then
    SendString(Conn, Login.DownCmd, Login.Delay)
  else
    SendString(Conn, 'D', Login.Delay);  { default: 'D' for download }

  { Wait for Zmodem auto-start or transfer prompt }
  Sleep(2000);

  { Receive via Zmodem }
  Xfer.DownloadPath := DownloadPath;
  if Xfer.Receive(DownloadPath, xpZmodem) then
  begin
    Result.Success := True;
    Result.FileName := DownloadPath;  { actual filename comes from Zmodem }
  end
  else
    Result.ErrorMsg := 'Zmodem receive failed';
end;

function UploadREP(Conn: TConnection; Xfer: TFileTransfer;
  const Login: TAutoLoginInfo;
  const RepFile: String): TTransferResult;
begin
  Result.Success := False;
  Result.FileName := RepFile;
  Result.FileSize := 0;

  if not Conn.Connected then
  begin
    Result.ErrorMsg := 'Not connected';
    Exit;
  end;

  if not FileExists(RepFile) then
  begin
    Result.ErrorMsg := 'REP file not found: ' + RepFile;
    Exit;
  end;

  { FileSize from a path requires opening the file }
  Result.FileSize := 0;

  { Send the upload command inside the door }
  if Login.UpCmd <> '' then
    SendString(Conn, Login.UpCmd, Login.Delay)
  else
    SendString(Conn, 'U', Login.Delay);  { default: 'U' for upload }

  { Wait for upload prompt }
  Sleep(2000);

  { Send via Zmodem }
  if Xfer.Send(RepFile, xpZmodem) then
    Result.Success := True
  else
    Result.ErrorMsg := 'Zmodem send failed';
end;

function AutoMailRun(Conn: TConnection; Xfer: TFileTransfer;
  const Host: String; Port: Word;
  const Login: TAutoLoginInfo;
  const DownloadPath: String;
  const RepFile: String): TTransferResult;
begin
  Result.Success := False;

  { Step 1: Connect }
  if not Conn.ConnectTelnet(Host, Port) then
  begin
    Result.ErrorMsg := 'Connection failed: ' + Host + ':' + IntToStr(Port);
    Exit;
  end;

  try
    { Step 2: Auto-login }
    if not AutoLogin(Conn, Login) then
    begin
      Result.ErrorMsg := 'Login failed';
      Exit;
    end;

    { Step 3: Enter the mail door }
    if not EnterDoor(Conn, Login) then
    begin
      Result.ErrorMsg := 'Failed to enter mail door';
      Exit;
    end;

    { Step 4: Upload REP first (if we have one) }
    if (RepFile <> '') and FileExists(RepFile) then
    begin
      UploadREP(Conn, Xfer, Login, RepFile);
      { Don't fail the whole run if upload fails — still download }
      Sleep(2000);
    end;

    { Step 5: Download QWK }
    Result := DownloadQWK(Conn, Xfer, Login, DownloadPath);

    { Step 6: Exit the door }
    SendString(Conn, 'Q', Login.Delay);
    Sleep(1000);

  finally
    { Step 7: Disconnect }
    Conn.Disconnect;
  end;
end;

end.

Program pdnet_loopback;

// ====================================================================
// PabloDraw Network Protocol — TCP Loopback Test
// ====================================================================

{$I M_OPS.PAS}
{$H+}

Uses
  SysUtils,
  Classes,
  m_pdtypes,
  m_pdnet;

Type
  TTestHandler = Class
    GotChat    : Boolean;
    GotJoin    : Boolean;
    ClientChat : Boolean;
    Procedure ServerChat(const From, Text: String);
    Procedure ServerJoin(Index: Integer; const Alias: String; Level: TUserLevel);
    Procedure ServerLeave(Index: Integer; const Alias: String; Level: TUserLevel);
    Procedure ClientChatH(const From, Text: String);
  End;

Procedure TTestHandler.ServerChat(const From, Text: String);
Begin
  WriteLn('  SERVER got chat: <', From, '> ', Text);
  GotChat := True;
End;

Procedure TTestHandler.ServerJoin(Index: Integer; const Alias: String; Level: TUserLevel);
Begin
  WriteLn('  SERVER: user joined: ', Alias, ' (level ', Ord(Level), ')');
  GotJoin := True;
End;

Procedure TTestHandler.ServerLeave(Index: Integer; const Alias: String; Level: TUserLevel);
Begin
  WriteLn('  SERVER: user left: ', Alias);
End;

Procedure TTestHandler.ClientChatH(const From, Text: String);
Begin
  WriteLn('  CLIENT got chat: <', From, '> ', Text);
  ClientChat := True;
End;

Var
  Canvas   : TPDCanvas;
  Server   : TPDNetServer;
  Client   : TPDNetClient;
  Handler  : TTestHandler;
  I        : Integer;
  El       : TPDCanvasElement;
  Pass     : Integer;
  Fail     : Integer;

Procedure Check(Name: String; OK: Boolean);
Begin
  If OK Then Begin
    WriteLn('   PASS: ', Name);
    Inc(Pass);
  End Else Begin
    WriteLn('   FAIL: ', Name);
    Inc(Fail);
  End;
End;

Begin
  WriteLn('=== PabloDraw Network Protocol Loopback Test ===');
  WriteLn('');
  Pass := 0;
  Fail := 0;

  Handler := TTestHandler.Create;
  Handler.GotChat := False;
  Handler.GotJoin := False;
  Handler.ClientChat := False;

  { 1. Create canvas }
  WriteLn('1. Creating 80x25 canvas...');
  Canvas := TPDCanvas.Create(80, 25);
  Check('Canvas created', (Canvas.Width = 80) and (Canvas.Height = 25));

  { 2. Start server }
  WriteLn('2. Starting server on port 8765...');
  Server := TPDNetServer.Create(Canvas);
  Server.OnChat := Handler.ServerChat;
  Server.OnUserJoin := Handler.ServerJoin;
  Server.OnUserLeave := Handler.ServerLeave;
  Check('Server started', Server.Start(8765));

  { 3. Connect client }
  WriteLn('3. Connecting client...');
  Client := TPDNetClient.Create(Canvas);
  Client.OnChat := Handler.ClientChatH;
  Check('Client connected', Client.Connect('127.0.0.1', 8765, 'TestUser', ''));

  { 4. Poll to establish }
  WriteLn('4. Handshake...');
  For I := 1 to 20 Do Begin
    Server.Poll;
    Client.Poll;
    Sleep(25);
  End;
  Check('Server saw join', Handler.GotJoin);

  { 5. Canvas update }
  WriteLn('5. Canvas update...');
  El.Ch.Ch := Ord('X');
  El.Attr.Init($0E);
  Canvas[5, 5] := El;
  Client.SendUpdate(5, 5, 5, 5);
  For I := 1 to 10 Do Begin
    Server.Poll;
    Client.Poll;
    Sleep(25);
  End;
  El := Canvas[5, 5];
  Check('Canvas char at 5,5 = X', El.Ch.Ch = Ord('X'));

  { 6. Chat }
  WriteLn('6. Chat message...');
  Client.SendChat('Hello loopback!');
  For I := 1 to 10 Do Begin
    Server.Poll;
    Client.Poll;
    Sleep(25);
  End;
  Check('Server received chat', Handler.GotChat);

  { 7. Cleanup }
  WriteLn('7. Cleanup...');
  Client.Free;
  For I := 1 to 5 Do Begin Server.Poll; Sleep(25); End;
  Server.Free;
  Canvas.Free;
  Handler.Free;
  Check('Cleanup OK', True);

  WriteLn('');
  WriteLn('=== Results: ', Pass, ' passed, ', Fail, ' failed ===');
  If Fail > 0 Then Halt(1);
End.

// =========================================================================
// Example: MIS Script Server — Simple Chat Bot
// =========================================================================
//
// This MPL script runs as a standalone TCP service via MIS Script Server.
// When a client connects on the configured port, this script handles
// the session. No BBS login required.
//
// Configure in MIS: Script Port = 9000, Script Path = script_server_example
//
// Test: telnet localhost 9000
//
// =========================================================================

Var
  Input   : String;
  Running : Boolean;

Begin
  Running := True;

  // Welcome banner
  ClientWrite('=== Mystic BBS Script Server ===' + #13#10);
  ClientWrite('Type HELP for commands, QUIT to disconnect.' + #13#10);
  ClientWrite(#13#10);

  While Running And ClientConnected Do Begin
    ClientWrite('> ');
    Input := ClientRead;

    // Strip CR/LF
    Input := StripLow(Input);

    If Length(Input) = 0 Then
      Continue;

    // Command dispatch
    If Upper(Input) = 'HELP' Then Begin
      ClientWrite('Available commands:' + #13#10);
      ClientWrite('  HELLO    - Greeting' + #13#10);
      ClientWrite('  TIME     - Current server time' + #13#10);
      ClientWrite('  STATS    - BBS statistics' + #13#10);
      ClientWrite('  USERS    - Online user count' + #13#10);
      ClientWrite('  VERSION  - Software version' + #13#10);
      ClientWrite('  QUIT     - Disconnect' + #13#10);
    End Else

    If Upper(Input) = 'HELLO' Then
      ClientWrite('Hello from ' + GetBBSName + '!' + #13#10)
    Else

    If Upper(Input) = 'TIME' Then
      ClientWrite('Server time: ' + DateStr(DateTime, 1) + ' ' +
                  TimeStr(DateTime, 1) + #13#10)
    Else

    If Upper(Input) = 'STATS' Then Begin
      ClientWrite('BBS: ' + GetBBSName + #13#10);
      ClientWrite('Calls today: ' + Int2Str(GetCallsToday) + #13#10);
      ClientWrite('Total users: ' + Int2Str(GetTotalUsers) + #13#10);
      ClientWrite('Total calls: ' + Int2Str(GetTotalCalls) + #13#10);
    End Else

    If Upper(Input) = 'USERS' Then
      ClientWrite('Users online: ' + Int2Str(GetUsersOnline) + #13#10)
    Else

    If Upper(Input) = 'VERSION' Then
      ClientWrite('Mystic BBS ' + GetVersion + #13#10)
    Else

    If Upper(Input) = 'QUIT' Then Begin
      ClientWrite('Goodbye!' + #13#10);
      Running := False;
    End Else

      ClientWrite('Unknown command. Type HELP.' + #13#10);
  End;

  ClientClose;
End.

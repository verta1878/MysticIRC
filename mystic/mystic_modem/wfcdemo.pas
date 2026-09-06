// ====================================================================
// mystic_modem : legacy dialup / serial support for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// wfcdemo - a standalone driver that exercises the whole module: load
// modem.ini, open the serial port, initialise the modem, and run the
// Waiting-For-Caller loop.  On CONNECT it runs a tiny "echo" session over
// the serial line to prove end-to-end I/O, then hangs up and waits again.
//
// This is where a real integration would, instead of the echo session,
// launch a Mystic node bound to the serial handle.
// ====================================================================

Program wfcdemo;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Uses
  SysUtils,
  mdm_Serial,
  mdm_Modem,
  mdm_Config,
  mdm_Wfc,
  mdm_MisWfc;

// The connect callback: a minimal serial echo "session".  Reads what the
// caller types and echoes it back until carrier drops or they type 'Q'.
// Returns True so the WFC loop keeps waiting for the next caller.
Function OnConnect (Ser: TModemSerial; Baud: LongInt): Boolean;
Var
  Data : String;
  Done : Boolean;
Begin
  WriteLn('  [session] CONNECT at ', Baud, ' bps - starting echo session');

  Ser.WriteStr(#13#10'Connected to Mystic (serial echo demo).'#13#10);
  Ser.WriteStr('Type text; it will be echoed.  Q to disconnect.'#13#10#13#10);

  Done := False;
  While (Not Done) and Ser.GetDSR Do Begin
    Data := Ser.ReadAvail;
    If Data <> '' Then Begin
      Ser.WriteStr(Data);                 // echo
      If Pos('Q', UpperCase(Data)) > 0 Then Done := True;
    End;
    Sleep(50);
  End;

  Ser.WriteStr(#13#10'Goodbye.'#13#10);
  WriteLn('  [session] ended');
  Result := True;                          // keep waiting for the next caller
End;

Var
  Cfg : TModemConfig;
  Wfc : TWfc;
  IniPath : String;
  DemoStats : TModemWfcStats;
Begin
  WriteLn('Mystic dialup/serial WFC demo (mystic_modem module)');
  WriteLn('---------------------------------------------------');

  IniPath := 'modem.ini';
  If ParamCount >= 1 Then IniPath := ParamStr(1);

  Cfg := LoadModemConfig(IniPath);
  WriteLn('Loaded config from ', IniPath, ':');
  WriteLn('  device = ', Cfg.Device);
  WriteLn('  baud   = ', Cfg.Baud);
  WriteLn('  init   = ', Cfg.InitString);
  WriteLn('  local  = ', Cfg.LocalMode);
  WriteLn;

  // Show the MIS-style modem WFC status screen once at startup.
  DemoStats.LineState := 'WAITING';
  DemoStats.ConnBaud  := 0;
  DemoStats.Carrier   := False;
  DemoStats.Calls     := 0;
  DemoStats.LastCall  := '(none yet)';
  DrawModemWfc(Cfg, DemoStats);

  Wfc := TWfc.Create(Cfg);
  Wfc.OnConnect := @OnConnect;

  If Wfc.Start Then
    Wfc.Run
  Else
    WriteLn('WFC failed to start (see errors above).');

  Wfc.Free;
  WriteLn('WFC demo finished.');
End.

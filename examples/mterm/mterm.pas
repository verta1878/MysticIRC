{ This file is part of mterm — Mystic Terminal.
  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench. }
{$MODE OBJFPC}
{$H+}
program mterm;
{ mterm — Mystic Terminal
  DOS-first RIP/ANSI terminal emulator.
  Free Vision TUI shell. }

uses
  SysUtils, Classes,
  App, Objects, Drivers, Views, Menus, Dialogs, MsgBox,
  mtterm, mtconn, mtphone, mtconfig, mtcapture, mt_spell;

const
  cmConnect    = 100;
  cmDisconnect = 101;
  cmPhonebook  = 102;
  cmSendFile   = 103;
  cmRecvFile   = 104;
  cmCapture    = 105;
  cmViewANSI   = 106;
  cmSettings   = 107;
  cmAbout      = 108;
  cmToggleRIP  = 109;
  cmSerialConn = 110;
  cmFossilConn = 111;
  cmLocalMode  = 112;

  mtermVersion = '0.1';
  mtermBuild   = '2026.07.28';
  mtermCrew    = 'verta1878 / sysop/0 / evga / kiddo / wrench';

type
  TMTermApp = object(TApplication)
    Term: PTermView;
    Conn: TConnection;
    Capture: TCapture;
    RIPMode: Boolean;
    constructor Init;
    destructor Done; virtual;
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Idle; virtual;
    procedure DoConnect;
    procedure DoDisconnect;
    procedure DoPhonebook;
    procedure DoViewANSI;
    procedure DoToggleCapture;
    procedure DoSerialConnect;
    procedure DoFossilConnect;
    procedure DoLocalMode;
    procedure DoSettings;
    procedure ShowAbout;
  end;

constructor TMTermApp.Init;
var R: TRect;
begin
  inherited Init;
  RIPMode := False;
  Conn := TConnection.Create;
  Capture := TCapture.Create;

  GetExtent(R);
  R.A.Y := 1;
  Dec(R.B.Y);
  Term := New(PTermView, Init(R));
  Insert(Term);

  Term^.AddLine('mterm v0.1 — Mystic Terminal');
  Term^.AddLine('RIP/ANSI terminal for Mystic BBS');
  Term^.AddLine('');
  Term^.AddLine('^B=Connect  ^P=Phonebook  ^R=RIP  ^F=Full  Alt-X=Exit');
  Term^.AddLine('');
end;

destructor TMTermApp.Done;
begin
  Conn.Free;
  Capture.Free;
  inherited Done;
end;

procedure TMTermApp.InitMenuBar;
var R: TRect;
begin
  GetExtent(R); R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~C~onnect', hcNoContext, NewMenu(
      NewItem('~C~onnect...', 'Ctrl-B', $0002, cmConnect, hcNoContext,
      NewItem('~S~erial/Modem', 'Ctrl-M', $000D, cmSerialConn, hcNoContext,
      NewItem('~F~OSSIL', '', 0, cmFossilConn, hcNoContext,
      NewItem('~L~ocal Mode', '', 0, cmLocalMode, hcNoContext,
      NewItem('~D~isconnect', 'Ctrl-D', $0004, cmDisconnect, hcNoContext,
      NewItem('~P~honebook', 'Ctrl-P', $0010, cmPhonebook, hcNoContext,
      NewLine(
      NewItem('E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext, nil))))))))),
    NewSubMenu('~T~ransfer', hcNoContext, NewMenu(
      NewItem('~S~end File', 'Alt-S', kbAltS, cmSendFile, hcNoContext,
      NewItem('~R~eceive File', 'Alt-R', kbAltR, cmRecvFile, hcNoContext, nil))),
    NewSubMenu('~V~iew', hcNoContext, NewMenu(
      NewItem('View ~A~NSI File', 'Alt-A', kbAltA, cmViewANSI, hcNoContext,
      NewItem('Toggle ~R~IP Mode', 'Ctrl-R', $0012, cmToggleRIP, hcNoContext,
      NewItem('Toggle ~C~apture', 'Alt-C', kbAltC, cmCapture, hcNoContext, nil)))),
    NewSubMenu('~O~ptions', hcNoContext, NewMenu(
      NewItem('~S~ettings', 'Alt-O', kbAltO, cmSettings, hcNoContext,
      NewItem('~A~bout', '', 0, cmAbout, hcNoContext, nil))),
    nil)))))));
end;

procedure TMTermApp.InitStatusLine;
var R: TRect;
begin
  GetExtent(R); R.A.Y := R.B.Y - 1;
  StatusLine := New(PStatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~F2~ Connect', kbF2, cmConnect,
      NewStatusKey('~F3~ Discon', kbF3, cmDisconnect,
      NewStatusKey('~F4~ Phone', kbF4, cmPhonebook,
      NewStatusKey('~F9~ RIP', kbF9, cmToggleRIP,
      NewStatusKey('~Alt-X~ Exit', kbAltX, cmQuit,
      { Hidden hotkeys — Alt keys that must work without menu }
      NewStatusKey('', kbAltA, cmViewANSI,
      NewStatusKey('', kbAltC, cmCapture,
      NewStatusKey('', kbAltM, cmSerialConn,
      NewStatusKey('', kbAltO, cmSettings,
      NewStatusKey('', kbAltR, cmRecvFile,
      NewStatusKey('', kbAltS, cmSendFile,
      nil))))))))))),
    nil)));
end;

procedure TMTermApp.HandleEvent(var Event: TEvent);
var R: TRect;
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then begin
    case Event.Command of
      cmConnect:    DoConnect;
      cmDisconnect: DoDisconnect;
      cmPhonebook:  DoPhonebook;
      cmViewANSI:   DoViewANSI;
      cmCapture:    DoToggleCapture;
      cmToggleRIP: begin
        RIPMode := not RIPMode;
        if RIPMode then
          Term^.AddLine('*** RIP mode ON')
        else
          Term^.AddLine('*** RIP mode OFF (ANSI only)');
      end;
      cmSettings:   DoSettings;
      cmAbout:      ShowAbout;
      cmSerialConn: DoSerialConnect;
      cmFossilConn: DoFossilConnect;
      cmLocalMode:  DoLocalMode;
    else Exit;
    end;
    ClearEvent(Event);
  end;

  { Pass printable keys to connection }
  if (Event.What = evKeyDown) and Conn.Connected then begin
    if (Event.KeyCode < $100) then begin
      { Regular character key — not an F-key or Alt-key }
      if ((Event.CharCode >= ' ') or
         (Event.CharCode = #8) or
         (Event.CharCode = #9) or
         (Event.CharCode = #13)
         ) and
         not (Event.CharCode in [#2, #4, #6, #16, #18]) then begin
        Conn.SendByte(Byte(Event.CharCode));
        ClearEvent(Event);
      end;
    end;
  end;
end;

procedure TMTermApp.Idle;
var
  Buf: array[0..1023] of Byte;
  N, I: Integer;
begin
  inherited Idle;
  if Conn.Connected then begin
    N := Conn.Receive(Buf, SizeOf(Buf));
    if N > 0 then begin
      for I := 0 to N - 1 do begin
        { Feed to ANSI/RIP parser }
        Term^.ProcessByte(Buf[I]);
        if Capture.Active then
          Capture.WriteByte(Buf[I]);
      end;
    end;
  end;
end;

procedure TMTermApp.DoConnect;
var
  D: PDialog;
  R: TRect;
  HostInput, PortInput: PInputLine;
  Cmd: Word;
  Host: String;
  Port: String;
begin
  R.Assign(15, 5, 65, 15);
  D := New(PDialog, Init(R, 'Connect'));

  R.Assign(3, 3, 45, 4);
  HostInput := New(PInputLine, Init(R, 255));
  D^.Insert(HostInput);
  R.Assign(3, 2, 15, 3);
  D^.Insert(New(PLabel, Init(R, '~H~ost:', HostInput)));

  R.Assign(3, 6, 15, 7);
  PortInput := New(PInputLine, Init(R, 6));
  D^.Insert(PortInput);
  R.Assign(3, 5, 15, 6);
  D^.Insert(New(PLabel, Init(R, '~P~ort:', PortInput)));

  R.Assign(10, 8, 22, 10);
  D^.Insert(New(PButton, Init(R, '~O~K', cmOK, bfDefault)));
  R.Assign(25, 8, 40, 10);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));

  Cmd := Desktop^.ExecView(D);
  if Cmd = cmOK then begin
    Host := PString(HostInput^.Data)^;
    Port := PString(PortInput^.Data)^;
    { Parse host:port shorthand }
    if Pos(':', Host) > 0 then begin
      Port := Copy(Host, Pos(':', Host) + 1, Length(Host));
      Host := Copy(Host, 1, Pos(':', Host) - 1);
    end;
    if Port = '' then Port := '23';

    Term^.AddLine('Connecting to ' + Host + ':' + Port + '...');
    if Conn.ConnectTelnet(Host, StrToIntDef(Port, 23)) then
      Term^.AddLine('Connected!')
    else
      Term^.AddLine('Connection failed.');
  end;
  Dispose(D, Done);
end;

procedure TMTermApp.DoDisconnect;
begin
  if Conn.Connected then begin
    Conn.Disconnect;
    Term^.AddLine('Disconnected.');
  end;
end;

procedure TMTermApp.DoPhonebook;
begin
  ShowPhonebook(Conn, Term);
end;

procedure TMTermApp.DoViewANSI;
var
  D: PDialog;
  R: TRect;
  Input: PInputLine;
  Cmd: Word;
  FName: String;
begin
  R.Assign(15, 8, 65, 16);
  D := New(PDialog, Init(R, 'Open ANSI/RIP File'));
  R.Assign(3, 3, 45, 4);
  Input := New(PInputLine, Init(R, 255));
  D^.Insert(Input);
  R.Assign(3, 2, 15, 3);
  D^.Insert(New(PLabel, Init(R, '~F~ile:', Input)));
  R.Assign(10, 5, 22, 7);
  D^.Insert(New(PButton, Init(R, '~O~K', cmOK, bfDefault)));
  R.Assign(25, 5, 40, 7);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));
  Cmd := Desktop^.ExecView(D);
  if Cmd = cmOK then begin
    FName := PString(Input^.Data)^;
    if FName <> '' then Term^.LoadANSIFile(FName);
  end;
  Dispose(D, Done);
end;

procedure TMTermApp.DoToggleCapture;
begin
  if Capture.Active then begin
    Capture.Stop;
    Term^.AddLine('*** Capture OFF');
  end else begin
    Capture.Start('mterm.log');
    Term^.AddLine('*** Capture ON → mterm.log');
  end;
end;

procedure TMTermApp.DoSettings;
begin
  ShowSettings;
end;

procedure TMTermApp.DoSerialConnect;
var
  D: PDialog; R: TRect;
  ComInput, BaudInput: PInputLine;
  Cmd: Word;
  Com, Baud: String;
begin
  R.Assign(15, 5, 65, 15);
  D := New(PDialog, Init(R, 'Serial/Modem Connect'));
  R.Assign(3, 3, 15, 4);
  ComInput := New(PInputLine, Init(R, 2));
  D^.Insert(ComInput);
  R.Assign(3, 2, 20, 3);
  D^.Insert(New(PLabel, Init(R, '~C~OM Port (1-4):', ComInput)));
  R.Assign(3, 6, 20, 7);
  BaudInput := New(PInputLine, Init(R, 8));
  D^.Insert(BaudInput);
  R.Assign(3, 5, 20, 6);
  D^.Insert(New(PLabel, Init(R, '~B~aud:', BaudInput)));
  R.Assign(10, 8, 22, 10);
  D^.Insert(New(PButton, Init(R, '~O~K', cmOK, bfDefault)));
  R.Assign(25, 8, 40, 10);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));
  Cmd := Desktop^.ExecView(D);
  if Cmd = cmOK then begin
    Com := PString(ComInput^.Data)^;
    Baud := PString(BaudInput^.Data)^;
    if Com = '' then Com := '1';
    if Baud = '' then Baud := '9600';
    Term^.AddLine('Connecting COM' + Com + ' at ' + Baud + ' baud...');
{$IFDEF GO32V2}
    if Conn.ConnectSerial(StrToIntDef(Com, 1) - 1, StrToIntDef(Baud, 9600)) then
      Term^.AddLine('Connected!')
    else
      Term^.AddLine('Serial connection failed.');
{$ELSE}
    Term^.AddLine('Serial requires DOS. Use Telnet on this platform.');
{$ENDIF}
  end;
  Dispose(D, Done);
end;

procedure TMTermApp.DoFossilConnect;
var
  D: PDialog; R: TRect;
  ComInput: PInputLine;
  Cmd: Word; Com: String;
begin
  R.Assign(20, 7, 60, 15);
  D := New(PDialog, Init(R, 'FOSSIL Connect'));
  R.Assign(3, 3, 15, 4);
  ComInput := New(PInputLine, Init(R, 2));
  D^.Insert(ComInput);
  R.Assign(3, 2, 25, 3);
  D^.Insert(New(PLabel, Init(R, '~C~OM Port (1-4):', ComInput)));
  R.Assign(8, 5, 20, 7);
  D^.Insert(New(PButton, Init(R, '~O~K', cmOK, bfDefault)));
  R.Assign(22, 5, 35, 7);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));
  Cmd := Desktop^.ExecView(D);
  if Cmd = cmOK then begin
    Com := PString(ComInput^.Data)^;
    if Com = '' then Com := '1';
    Term^.AddLine('FOSSIL init on COM' + Com + '...');
{$IFDEF GO32V2}
    if Conn.ConnectFossil(StrToIntDef(Com, 1) - 1) then
      Term^.AddLine('FOSSIL active!')
    else
      Term^.AddLine('FOSSIL init failed.');
{$ELSE}
    Term^.AddLine('FOSSIL requires DOS. Use Telnet on this platform.');
{$ENDIF}
  end;
  Dispose(D, Done);
end;

procedure TMTermApp.DoLocalMode;
begin
  Term^.AddLine('*** Local mode — type commands directly');
  Term^.AddLine('*** No connection required');
  Term^.AddLine('');
end;

procedure TMTermApp.ShowAbout;
begin
  MessageBox(
    'mterm v' + mtermVersion + #13#13 +
    'RIP/ANSI Terminal' + #13 +
    'FPC 2.6.4irc r3.1' + #13#13 +
    mtermCrew + #13 +
    'GPLv3',
    nil, mfInformation + mfOkButton);
end;

var MApp: TMTermApp;
begin
  MApp.Init;
  MApp.Run;
  MApp.Done;
end.

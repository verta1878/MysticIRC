// ====================================================================
// mystic_modem : legacy dialup / serial support for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// mdm_wfc - the classic "Waiting For Caller" loop with a live modem
// status window.  It initialises the modem, then idles showing modem
// state (READY / RING / CONNECT nnnn) until a call arrives.  On CONNECT
// it invokes a caller-supplied callback with the open serial handle and
// the negotiated speed - that callback is where a Mystic session would be
// launched bound to the serial line instead of a telnet socket.
//
// The screen here is intentionally plain (portable console writes) so the
// module builds with no dependency on Mystic's ANSI/session engine.  A
// real integration can replace DrawWfc with Mystic's themed WFC screen.
// ====================================================================

Unit mdm_Wfc;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  SysUtils,
  mdm_Serial,
  mdm_Modem,
  mdm_Config;

Type
  // Called on a successful CONNECT.  Ser is the live serial line, Baud is
  // the negotiated connect speed.  Return True to keep the WFC running
  // afterwards (i.e. after the session ends), False to exit WFC entirely.
  TConnectCallback = Function (Ser: TModemSerial; Baud: LongInt): Boolean;

  TWfc = Class
  Private
    FCfg      : TModemConfig;
    FSer      : TModemSerial;
    FMdm      : TModem;
    FOnConnect: TConnectCallback;
    FRunning  : Boolean;
    Procedure DrawWfc (Const StatusLine: String);
  Public
    Constructor Create (Const Cfg: TModemConfig);
    Destructor  Destroy; Override;

    // Open the serial port and initialise the modem.  True on success.
    Function  Start: Boolean;

    // Run the waiting-for-caller loop until Stop is called or the connect
    // callback returns False.  Non-daemon: also watches the keyboard so a
    // local sysop can break out (handled by the host program).
    Procedure Run;
    Procedure Stop;

    Property OnConnect : TConnectCallback Read FOnConnect Write FOnConnect;
    Property Modem     : TModem Read FMdm;
    Property Serial    : TModemSerial Read FSer;
  End;

Implementation

Constructor TWfc.Create (Const Cfg: TModemConfig);
Begin
  Inherited Create;
  FCfg       := Cfg;
  FSer       := TModemSerial.Create;
  FMdm       := TModem.Create(FSer);
  FOnConnect := Nil;
  FRunning   := False;
End;

Destructor TWfc.Destroy;
Begin
  If Assigned(FMdm) Then FMdm.Free;
  If Assigned(FSer) Then FSer.Free;
  Inherited Destroy;
End;

Procedure TWfc.DrawWfc (Const StatusLine: String);
Begin
  // Minimal, portable status render.  A themed version can draw the ANSI
  // WFC screen and position a modem window (the old !7/!8 template coords).
  WriteLn;
  WriteLn('  +------------------------------------------------------+');
  WriteLn('  |            M Y S T I C   -   Waiting For Caller       |');
  WriteLn('  +------------------------------------------------------+');
  WriteLn('  | Device : ', FCfg.Device);
  WriteLn('  | Baud   : ', FCfg.Baud);
  WriteLn('  | Modem  : ', StatusLine);
  WriteLn('  +------------------------------------------------------+');
End;

Function TWfc.Start: Boolean;
Begin
  Result := False;

  If FCfg.LocalMode Then Begin
    // Local mode: no modem needed.  Report success; Run will just fire the
    // connect callback once at "console" speed.
    Result := True;
    Exit;
  End;

  If Not FSer.Open(FCfg.Device, FCfg.Baud, FCfg.HardwareFlow) Then Begin
    WriteLn('  ERROR: could not open serial device ', FCfg.Device);
    Exit;
  End;

  DrawWfc('Initializing Modem');
  If Not FMdm.Initialise(FCfg.InitString) Then Begin
    WriteLn('  ERROR: modem did not respond on ', FCfg.Device);
    FSer.Close;
    Exit;
  End;

  Result := True;
End;

Procedure TWfc.Run;
Var
  KeepGoing : Boolean;
Begin
  FRunning := True;

  // Local mode: hand straight to the session callback once.
  If FCfg.LocalMode Then Begin
    If Assigned(FOnConnect) Then FOnConnect(FSer, FCfg.Baud);
    FRunning := False;
    Exit;
  End;

  DrawWfc('Waiting for a caller');

  While FRunning Do Begin
    If FMdm.IsRinging Then Begin
      DrawWfc('Incomming caller; Answering phone');

      If FMdm.Answer(60000, FCfg.AnswerStr) Then Begin
        DrawWfc('CONNECT ' + IntToStr(FMdm.ConnBaud) + ' - Carrier detected');

        KeepGoing := True;
        If Assigned(FOnConnect) Then
          KeepGoing := FOnConnect(FSer, FMdm.ConnBaud);

        // Session over: hang up and reset for the next caller.
        FMdm.HangUp;

        If Not KeepGoing Then Begin
          FRunning := False;
          Break;
        End;

        // Re-initialise before waiting again (some modems need it).
        FMdm.Initialise(FCfg.InitString);
        DrawWfc('Waiting for a caller');
      End Else
        DrawWfc('Waiting for a caller');   // answer failed, keep waiting
    End;

    Sleep(200);   // idle tick; host program can also poll the keyboard here
  End;
End;

Procedure TWfc.Stop;
Begin
  FRunning := False;
End;

End.

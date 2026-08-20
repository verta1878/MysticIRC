{$MODE OBJFPC}
{$H+}
program m_pdserver;
{ PabloDraw Pascal — Teleconference Server (FV TUI)
  Hosts collaborative ANSI art editing session. }

uses
  SysUtils, Classes,
  App, Objects, Drivers, Views, Menus, Dialogs, MsgBox,
  m_pdtypes, pdsauce, pdansi, m_pdnet;

const
  cmStartStop = 100;
  cmKickUser  = 101;
  cmPromote   = 102;
  cmAbout     = 103;

type
  PPDLogView = ^TPDLogView;
  TPDLogView = object(TView)
    Lines: array[0..99] of String;
    Count: Integer;
    constructor Init(var Bounds: TRect);
    procedure Draw; virtual;
    procedure AddLine(const S: String);
  end;

  TPDServerApp = object(TApplication)
    Server: TPDNetServer;
    Canvas: TPDCanvas;
    Log: PPDLogView;
    IsRunning: Boolean;
    constructor Init;
    destructor Done; virtual;
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Idle; virtual;
    procedure OnChat(const From, Text: String);
    procedure OnJoin(Idx: Integer; const Alias: String; Level: TUserLevel);
    procedure OnLeave(Idx: Integer; const Alias: String; Level: TUserLevel);
    procedure LogMsg(const S: String);
  end;

constructor TPDLogView.Init(var Bounds: TRect);
begin
  inherited Init(Bounds);
  Count := 0;
  GrowMode := gfGrowHiX or gfGrowHiY;
end;

procedure TPDLogView.Draw;
var Y: Integer; B: TDrawBuffer; Start: Integer;
begin
  Start := Count - Size.Y;
  if Start < 0 then Start := 0;
  for Y := 0 to Size.Y - 1 do begin
    MoveChar(B, ' ', $07, Size.X);
    if Start + Y < Count then
      MoveStr(B, Copy(Lines[(Start + Y) mod 100], 1, Size.X), $07);
    WriteLine(0, Y, Size.X, 1, B);
  end;
end;

procedure TPDLogView.AddLine(const S: String);
begin
  Lines[Count mod 100] := S;
  Inc(Count);
  DrawView;
end;

constructor TPDServerApp.Init;
var R: TRect;
begin
  inherited Init;
  Canvas := TPDCanvas.Create(80, 25);
  Server := TPDNetServer.Create(Canvas);
  Server.OnChat := @OnChat;
  Server.OnUserJoin := @OnJoin;
  Server.OnUserLeave := @OnLeave;
  IsRunning := False;
  GetExtent(R); R.A.Y := 1; Dec(R.B.Y);
  Log := New(PPDLogView, Init(R));
  Insert(Log);
  Log^.AddLine('PabloDraw Server v0.1 — Press F2 to start');
end;

destructor TPDServerApp.Done;
begin
  Server.Free;
  Canvas.Free;
  inherited Done;
end;

procedure TPDServerApp.InitMenuBar;
var R: TRect;
begin
  GetExtent(R); R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~S~erver', hcNoContext, NewMenu(
      NewItem('~S~tart/Stop', 'F2', kbF2, cmStartStop, hcNoContext,
      NewItem('~K~ick User', 'F4', kbF4, cmKickUser, hcNoContext,
      NewItem('~P~romote', 'F5', kbF5, cmPromote, hcNoContext,
      NewLine(
      NewItem('E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext,
      nil)))))),
    NewSubMenu('~H~elp', hcNoContext, NewMenu(
      NewItem('~A~bout', '', 0, cmAbout, hcNoContext, nil)),
    nil)))));
end;

procedure TPDServerApp.InitStatusLine;
var R: TRect;
begin
  GetExtent(R); R.A.Y := R.B.Y - 1;
  StatusLine := New(PStatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~F2~ Start', kbF2, cmStartStop,
      NewStatusKey('~F4~ Kick', kbF4, cmKickUser,
      NewStatusKey('~Alt-X~ Exit', kbAltX, cmQuit, nil))),
    nil)));
end;

procedure TPDServerApp.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then begin
    case Event.Command of
      cmStartStop: begin
        if IsRunning then begin
          Server.Stop; IsRunning := False;
          LogMsg('Server stopped.');
        end else begin
          if Server.Start(PD_NET_PORT) then begin
            IsRunning := True;
            LogMsg('Server started on port ' + IntToStr(PD_NET_PORT));
          end else
            LogMsg('Failed to start server!');
        end;
      end;
      cmKickUser: begin
        if IsRunning then
          MessageBox('Enter user # to kick (0-31)', nil, mfInformation + mfOkButton);
      end;
      cmAbout:
        MessageBox('PabloDraw Server v0.1' + #13 +
          'TCP teleconference on port 3693', nil, mfInformation + mfOkButton);
    else Exit;
    end;
    ClearEvent(Event);
  end;
end;

procedure TPDServerApp.Idle;
begin
  inherited Idle;
  if IsRunning then Server.Poll;
end;

procedure TPDServerApp.OnChat(const From, Text: String);
begin LogMsg('<' + From + '> ' + Text); end;

procedure TPDServerApp.OnJoin(Idx: Integer; const Alias: String; Level: TUserLevel);
begin LogMsg('*** ' + Alias + ' joined (slot ' + IntToStr(Idx) + ')'); end;

procedure TPDServerApp.OnLeave(Idx: Integer; const Alias: String; Level: TUserLevel);
begin LogMsg('*** ' + Alias + ' left'); end;

procedure TPDServerApp.LogMsg(const S: String);
begin Log^.AddLine(FormatDateTime('hh:nn:ss', Now) + ' ' + S); end;

var PDSrv: TPDServerApp;
begin
  PDSrv.Init;
  PDSrv.Run;
  PDSrv.Done;
end.

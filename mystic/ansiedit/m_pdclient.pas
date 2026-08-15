{$MODE OBJFPC}
{$H+}
program m_pdclient;
{ PabloDraw Pascal — Teleconference Client (FV TUI)
  Connect to m_pdserver, view/edit canvas, chat. }

uses
  SysUtils, Classes,
  App, Objects, Drivers, Views, Menus, Dialogs, MsgBox,
  m_pdtypes, pdansi, m_pdnet;

const
  cmConnect    = 100;
  cmDisconnect = 101;
  cmSendChat   = 102;
  cmAbout      = 103;

type
  { Canvas display — shows shared art }
  PPDCanvasView = ^TPDCanvasView;
  TPDCanvasView = object(TView)
    Canvas: TPDCanvas;
    ScrollY: Integer;
    constructor Init(var Bounds: TRect; ACanvas: TPDCanvas);
    procedure Draw; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
  end;

  { Chat log at bottom }
  PPDChatView = ^TPDChatView;
  TPDChatView = object(TView)
    Lines: array[0..49] of String;
    Count: Integer;
    constructor Init(var Bounds: TRect);
    procedure Draw; virtual;
    procedure AddLine(const S: String);
  end;

  TPDClientApp = object(TApplication)
    Client: TPDNetClient;
    Canvas: TPDCanvas;
    CanvasView: PPDCanvasView;
    ChatView: PPDChatView;
    constructor Init;
    destructor Done; virtual;
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure Idle; virtual;
    procedure DoConnect;
    procedure OnChat(const From, Text: String);
    procedure OnUpdate(X1, Y1, X2, Y2: Integer);
    procedure ChatMsg(const S: String);
  end;

{ ---- Canvas View ---- }

constructor TPDCanvasView.Init(var Bounds: TRect; ACanvas: TPDCanvas);
begin
  inherited Init(Bounds);
  Canvas := ACanvas; ScrollY := 0;
  GrowMode := gfGrowHiX or gfGrowHiY;
  Options := Options or ofSelectable;
end;

procedure TPDCanvasView.Draw;
var X, Y, SrcY: Integer; B: TDrawBuffer; E: TPDCanvasElement;
begin
  for Y := 0 to Size.Y - 1 do begin
    SrcY := Y + ScrollY;
    MoveChar(B, ' ', $07, Size.X);
    if (Canvas <> nil) and (SrcY < Canvas.Height) then
      for X := 0 to Size.X - 1 do
        if X < Canvas.Width then begin
          E := Canvas[X, SrcY];
          if (E.Ch.Ch >= 32) and (E.Ch.Ch < 256) then
            MoveChar(B[X], Chr(E.Ch.Ch), E.Attr.ToByte, 1)
          else
            MoveChar(B[X], ' ', E.Attr.ToByte, 1);
        end;
    WriteLine(0, Y, Size.X, 1, B);
  end;
end;

procedure TPDCanvasView.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evKeyDown then begin
    case Event.KeyCode of
      kbUp: if ScrollY > 0 then begin Dec(ScrollY); DrawView; end;
      kbDown: if (Canvas<>nil)and(ScrollY<Canvas.Height-Size.Y) then begin Inc(ScrollY); DrawView; end;
      kbPgUp: begin Dec(ScrollY, Size.Y); if ScrollY<0 then ScrollY:=0; DrawView; end;
      kbPgDn: if Canvas<>nil then begin Inc(ScrollY, Size.Y);
        if ScrollY>Canvas.Height-Size.Y then ScrollY:=Canvas.Height-Size.Y;
        if ScrollY<0 then ScrollY:=0; DrawView; end;
    else Exit;
    end;
    ClearEvent(Event);
  end;
end;

{ ---- Chat View ---- }

constructor TPDChatView.Init(var Bounds: TRect);
begin inherited Init(Bounds); Count := 0; GrowMode := gfGrowHiX or gfGrowLoY or gfGrowHiY; end;

procedure TPDChatView.Draw;
var Y, Start: Integer; B: TDrawBuffer;
begin
  Start := Count - Size.Y; if Start < 0 then Start := 0;
  for Y := 0 to Size.Y - 1 do begin
    MoveChar(B, ' ', $1F, Size.X); { blue bg, white fg }
    if Start + Y < Count then
      MoveStr(B, Copy(Lines[(Start+Y) mod 50], 1, Size.X), $1F);
    WriteLine(0, Y, Size.X, 1, B);
  end;
end;

procedure TPDChatView.AddLine(const S: String);
begin Lines[Count mod 50] := S; Inc(Count); DrawView; end;

{ ---- Client App ---- }

constructor TPDClientApp.Init;
var R: TRect;
begin
  inherited Init;
  Canvas := TPDCanvas.Create(80, 25);
  Client := TPDNetClient.Create(Canvas);
  Client.OnChat := @OnChat;
  Client.OnUpdate := @OnUpdate;

  { Canvas view — upper 80% }
  GetExtent(R); R.A.Y := 1; R.B.Y := R.B.Y - 6;
  CanvasView := New(PPDCanvasView, Init(R, Canvas));
  Insert(CanvasView);

  { Chat view — bottom 5 lines }
  GetExtent(R); R.A.Y := R.B.Y - 6; Dec(R.B.Y);
  ChatView := New(PPDChatView, Init(R));
  Insert(ChatView);

  ChatMsg('PabloDraw Client v0.1 — F2 to connect');
end;

destructor TPDClientApp.Done;
begin Client.Free; Canvas.Free; inherited Done; end;

procedure TPDClientApp.InitMenuBar;
var R: TRect;
begin
  GetExtent(R); R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~C~onnect', hcNoContext, NewMenu(
      NewItem('~C~onnect...', 'F2', kbF2, cmConnect, hcNoContext,
      NewItem('~D~isconnect', 'F3', kbF3, cmDisconnect, hcNoContext,
      NewItem('~S~end Chat', 'F4', kbF4, cmSendChat, hcNoContext,
      NewLine(
      NewItem('E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext,
      nil)))))),
    NewSubMenu('~H~elp', hcNoContext, NewMenu(
      NewItem('~A~bout', '', 0, cmAbout, hcNoContext, nil)),
    nil)))));
end;

procedure TPDClientApp.InitStatusLine;
var R: TRect;
begin
  GetExtent(R); R.A.Y := R.B.Y - 1;
  StatusLine := New(PStatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~F2~ Connect', kbF2, cmConnect,
      NewStatusKey('~F4~ Chat', kbF4, cmSendChat,
      NewStatusKey('~Alt-X~ Exit', kbAltX, cmQuit, nil))),
    nil)));
end;

procedure TPDClientApp.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then begin
    case Event.Command of
      cmConnect: DoConnect;
      cmDisconnect: begin
        Client.Disconnect;
        ChatMsg('Disconnected.');
      end;
      cmSendChat: begin
        if Client.Connected then begin
          { Simple: send fixed message. Real: input dialog }
          Client.SendChat('Hello from m_pdclient!');
        end else
          ChatMsg('Not connected.');
      end;
      cmAbout:
        MessageBox('PabloDraw Client v0.1'+#13+'TCP teleconference',
          nil, mfInformation+mfOkButton);
    else Exit;
    end;
    ClearEvent(Event);
  end;
end;

procedure TPDClientApp.Idle;
begin
  inherited Idle;
  if Client.Connected then Client.Poll;
end;

procedure TPDClientApp.DoConnect;
begin
  { Simple: connect to localhost. Real: input dialog for host/alias }
  ChatMsg('Connecting to 127.0.0.1:3693...');
  if Client.Connect('127.0.0.1', PD_NET_PORT, 'Artist', '') then
    ChatMsg('Connected as ' + Client.Alias)
  else
    ChatMsg('Connection failed!');
end;

procedure TPDClientApp.OnChat(const From, Text: String);
begin ChatMsg('<' + From + '> ' + Text); end;

procedure TPDClientApp.OnUpdate(X1, Y1, X2, Y2: Integer);
begin CanvasView^.DrawView; end;

procedure TPDClientApp.ChatMsg(const S: String);
begin ChatView^.AddLine(FormatDateTime('hh:nn', Now) + ' ' + S); end;

var PDCli: TPDClientApp;
begin
  PDCli.Init;
  PDCli.Run;
  PDCli.Done;
end.

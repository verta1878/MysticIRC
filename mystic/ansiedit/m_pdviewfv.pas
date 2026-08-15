{$MODE OBJFPC}
{$H+}
program m_pdviewfv;
{ PabloDraw Pascal — Free Vision TUI Viewer }

uses
  SysUtils, Classes,
  App, Objects, Drivers, Views, Menus, Dialogs, StdDlg, MsgBox,
  m_pdtypes, m_pdsauce, m_pdansi, m_pdascii, m_pdbinary, m_pdavatar, m_pdxbin;

const
  cmLoadFile  = 100;
  cmSauceInfo = 101;
  cmAbout     = 102;

type
  PPDDisplay = ^TPDDisplay;
  TPDDisplay = object(TView)
    Canvas: TPDCanvas;
    ScrollY: Integer;
    constructor Init(var Bounds: TRect; ACanvas: TPDCanvas);
    procedure Draw; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
  end;

  TPDApp = object(TApplication)
    Canvas: TPDCanvas;
    Sauce: TSauceRecord;
    Display: PPDDisplay;
    CurFile: String;
    constructor Init;
    destructor Done; virtual;
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure LoadFile(const AName: String);
  end;

{ ---- TPDDisplay ---- }

constructor TPDDisplay.Init(var Bounds: TRect; ACanvas: TPDCanvas);
begin
  inherited Init(Bounds);
  Canvas := ACanvas;
  ScrollY := 0;
  GrowMode := gfGrowHiX or gfGrowHiY;
  Options := Options or ofSelectable;
end;

procedure TPDDisplay.Draw;
var
  X, Y, SrcY: Integer;
  B: TDrawBuffer;
  E: TPDCanvasElement;
begin
  for Y := 0 to Size.Y - 1 do begin
    SrcY := Y + ScrollY;
    MoveChar(B, ' ', $07, Size.X);
    if (Canvas <> nil) and (SrcY < Canvas.Height) then begin
      for X := 0 to Size.X - 1 do begin
        if X < Canvas.Width then begin
          E := Canvas[X, SrcY];
          if (E.Ch.Ch >= 32) and (E.Ch.Ch < 256) then
            MoveChar(B[X], Chr(E.Ch.Ch), E.Attr.ToByte, 1)
          else
            MoveChar(B[X], ' ', E.Attr.ToByte, 1);
        end;
      end;
    end;
    WriteLine(0, Y, Size.X, 1, B);
  end;
end;

procedure TPDDisplay.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evKeyDown then begin
    case Event.KeyCode of
      kbUp: if ScrollY > 0 then begin Dec(ScrollY); DrawView; end;
      kbDown: if (Canvas <> nil) and (ScrollY < Canvas.Height - Size.Y) then begin
        Inc(ScrollY); DrawView; end;
      kbPgUp: begin Dec(ScrollY, Size.Y);
        if ScrollY < 0 then ScrollY := 0; DrawView; end;
      kbPgDn: if Canvas <> nil then begin Inc(ScrollY, Size.Y);
        if ScrollY > Canvas.Height - Size.Y then ScrollY := Canvas.Height - Size.Y;
        if ScrollY < 0 then ScrollY := 0; DrawView; end;
      kbHome: begin ScrollY := 0; DrawView; end;
      kbEnd: if Canvas <> nil then begin
        ScrollY := Canvas.Height - Size.Y;
        if ScrollY < 0 then ScrollY := 0; DrawView; end;
    else Exit;
    end;
    ClearEvent(Event);
  end;
end;

{ ---- TPDApp ---- }

constructor TPDApp.Init;
var R: TRect;
begin
  inherited Init;
  Canvas := TPDCanvas.Create(80, 500);
  Sauce := TSauceRecord.Create;
  GetExtent(R); R.A.Y := 1; Dec(R.B.Y);
  Display := New(PPDDisplay, Init(R, Canvas));
  Insert(Display);
  if ParamCount >= 1 then LoadFile(ParamStr(1));
end;

destructor TPDApp.Done;
begin
  Sauce.Free;
  Canvas.Free;
  inherited Done;
end;

procedure TPDApp.InitMenuBar;
var R: TRect;
begin
  GetExtent(R); R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~F~ile', hcNoContext, NewMenu(
      NewItem('~O~pen...', 'F3', kbF3, cmLoadFile, hcNoContext,
      NewItem('~S~AUCE', 'F5', kbF5, cmSauceInfo, hcNoContext,
      NewLine(
      NewItem('E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext,
      nil))))),
    NewSubMenu('~H~elp', hcNoContext, NewMenu(
      NewItem('~A~bout', '', 0, cmAbout, hcNoContext, nil)),
    nil)))));
end;

procedure TPDApp.InitStatusLine;
var R: TRect;
begin
  GetExtent(R); R.A.Y := R.B.Y - 1;
  StatusLine := New(PStatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~F3~ Open', kbF3, cmLoadFile,
      NewStatusKey('~F5~ SAUCE', kbF5, cmSauceInfo,
      NewStatusKey('~Alt-X~ Exit', kbAltX, cmQuit, nil))),
    nil)));
end;

procedure TPDApp.HandleEvent(var Event: TEvent);
var
  D: PFileDialog;
  F: String;
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then begin
    case Event.Command of
      cmLoadFile: begin
        New(D, Init('*.ans', 'Open ANSI Art', '~N~ame', fdOpenButton, 0));
        if ExecuteDialog(D, @F) = cmOK then LoadFile(F);
      end;
      cmSauceInfo: begin
        if Sauce.Valid then
          MessageBox('Title: '+Sauce.Title+#13+
            'Author: '+Sauce.Author+#13+
            'Group: '+Sauce.Group, nil, mfInformation+mfOkButton)
        else
          MessageBox('No SAUCE record.', nil, mfWarning+mfOkButton);
      end;
      cmAbout:
        MessageBox('PabloDraw FV Viewer v0.1'+#13+
          'ANS/TXT/BIN/AVT/XBin', nil, mfInformation+mfOkButton);
    else Exit;
    end;
    ClearEvent(Event);
  end;
end;

procedure TPDApp.LoadFile(const AName: String);
var
  FS: TFileStream;
  Ext: String;
  Ansi: TAnsiParser;
  Avatar: TAvatarParser;
  Pal: TPDPalette;
  FD: array[0..8191] of Byte;
  FSz: Byte;
  HP, HF: Boolean;
  I: Integer;
begin
  CurFile := AName;
  if not FileExists(AName) then Exit;
  Canvas.Resize(80, 500);
  Sauce.LoadFromFile(AName);
  if Sauce.Valid and (Sauce.GetWidth > 0) then Canvas.Resize(Sauce.GetWidth, 500);
  Ext := LowerCase(ExtractFileExt(AName));
  FS := TFileStream.Create(AName, fmOpenRead or fmShareDenyNone);
  try
    if (Ext='.ans')or(Ext='.ansi')or(Ext='.diz')or(Ext='.ice') then begin
      Ansi:=TAnsiParser.Create; try Ansi.LoadFromStream(FS,Canvas); finally Ansi.Free; end;
    end else if (Ext='.txt')or(Ext='.asc')or(Ext='.nfo') then LoadASCII(FS,Canvas)
    else if Ext='.bin' then LoadBinary(FS,Canvas,80)
    else if Ext='.avt' then begin
      Avatar:=TAvatarParser.Create; try Avatar.LoadFromStream(FS,Canvas); finally Avatar.Free; end;
    end else if (Ext='.xb')or(Ext='.xbin') then begin
      for I:=0 to 15 do Pal[I]:=DefaultPalette[I]; LoadXBin(FS,Canvas,Pal,FD,FSz,HP,HF);
    end else begin
      Ansi:=TAnsiParser.Create; try Ansi.LoadFromStream(FS,Canvas); finally Ansi.Free; end;
    end;
  finally FS.Free; end;
  Display^.ScrollY := 0;
  Display^.DrawView;
end;

var PDApp: TPDApp;
begin
  PDApp.Init;
  PDApp.Run;
  PDApp.Done;
end.

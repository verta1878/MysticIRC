{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  Clean-room reimplementation from published documentation.

  GPLv3 — Copyright (C) 2026 FPC264IRC Contributors.
  Clean-room reimplementation. No original source code used.
  =========================================================================== }

program openolms;
{ ===========================================================================
  OpenOLMS — main offline mail door
  ---------------------------------------------------------------------------
  FV (Free Vision) text-mode application. Matches the OLMS user
  experience: area selection, message scanning, QWK packing,
  REP uploading, keyword filtering, file requesting.

  This is the door that the BBS calls. It reads the drop file
  (DORINFO1.DEF / DOOR.SYS) to learn the user's name, security
  level, time remaining, and COM port. It then presents the
  offline mail interface.

  Phase 1: skeleton with FV menus, QWK pack/unpack, config loading.
  Phase 2: Hudson/JAM message base reading, area selection.
  Phase 3: keyword filtering, twit lists, file requesting.
  Phase 4: BlueWave support, vacation mail, maintenance.
  =========================================================================== }

{$MODE OBJFPC}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils,
  App, Objects, Menus, Drivers, Views, Dialogs, MsgBox,
  OL_Config, OL_QWK;

const
  VERSION = 'OpenOLMS 1.0 — Open Offline Mail System';

  { Menu commands }
  cmScanMail   = 1001;
  cmDownload   = 1002;
  cmUpload     = 1003;
  cmSelectAreas= 1004;
  cmKeywords   = 1005;
  cmUserSetup  = 1006;
  cmAbout      = 1007;

type
  TOpenOLMS = object(TApplication)
    Config: TOLMSConfig;
    constructor Init;
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    procedure DoScanMail;
    procedure DoDownload;
    procedure DoUpload;
    procedure DoSelectAreas;
    procedure DoAbout;
  end;

constructor TOpenOLMS.Init;
begin
  inherited Init;
  OLMSDefaultConfig(Config);
  { Try to load existing config }
  OLMSLoadConfig('OLMS.CFG', Config);
end;

procedure TOpenOLMS.InitMenuBar;
var R: TRect;
begin
  GetExtent(R);
  R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~M~ail', hcNoContext, NewMenu(
      NewItem('~S~can && Download', 'F2', kbF2, cmScanMail, hcNoContext,
      NewItem('~D~ownload Only', 'F3', kbF3, cmDownload, hcNoContext,
      NewItem('~U~pload Replies', 'F4', kbF4, cmUpload, hcNoContext,
      NewLine(
      NewItem('E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext,
      nil)))))),
    NewSubMenu('~S~etup', hcNoContext, NewMenu(
      NewItem('~A~rea Selection', 'F5', kbF5, cmSelectAreas, hcNoContext,
      NewItem('~K~eywords', '', 0, cmKeywords, hcNoContext,
      NewItem('~U~ser Preferences', '', 0, cmUserSetup, hcNoContext,
      nil)))),
    NewSubMenu('~H~elp', hcNoContext, NewMenu(
      NewItem('~A~bout', '', 0, cmAbout, hcNoContext,
      nil)),
    nil))))));
end;

procedure TOpenOLMS.InitStatusLine;
var R: TRect;
begin
  GetExtent(R);
  R.A.Y := R.B.Y - 1;
  StatusLine := New(PStatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~Alt-X~ Exit', kbAltX, cmQuit,
      NewStatusKey('~F2~ Scan', kbF2, cmScanMail,
      NewStatusKey('~F4~ Upload', kbF4, cmUpload,
      nil))),
    nil)));
end;

procedure TOpenOLMS.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then
  begin
    case Event.Command of
      cmScanMail:    DoScanMail;
      cmDownload:    DoDownload;
      cmUpload:      DoUpload;
      cmSelectAreas: DoSelectAreas;
      cmAbout:       DoAbout;
    else
      Exit;
    end;
    ClearEvent(Event);
  end;
end;

procedure TOpenOLMS.DoScanMail;
begin
  MessageBox(
    #3'Scanning message areas...'#13#3 +
    'QWK packing not yet implemented.'#13#3 +
    'Phase 1 skeleton.',
    nil, mfInformation or mfOKButton);
end;

procedure TOpenOLMS.DoDownload;
begin
  MessageBox(
    #3'Download QWK packet.'#13#3 +
    'Not yet implemented.',
    nil, mfInformation or mfOKButton);
end;

procedure TOpenOLMS.DoUpload;
begin
  MessageBox(
    #3'Upload .REP reply packet.'#13#3 +
    'Not yet implemented.',
    nil, mfInformation or mfOKButton);
end;

procedure TOpenOLMS.DoSelectAreas;
begin
  MessageBox(
    #3'Area selection dialog.'#13#3 +
    'Not yet implemented.',
    nil, mfInformation or mfOKButton);
end;

procedure TOpenOLMS.DoAbout;
begin
  MessageBox(
    #3 + VERSION + #13#3 +
    'Clean-room reimplementation of OLMS'#13#3 +
    'by Peter Rocca (MCC, 1994-1998).'#13#3 +
    'With author permission.'#13#3 +
    'Free Vision TUI + Free Pascal.',
    nil, mfInformation or mfOKButton);
end;

var
  OLMSApp: TOpenOLMS;
begin
  OLMSApp.Init;
  OLMSApp.Run;
  OLMSApp.Done;
end.

{ ===========================================================================
  OpenOLMS — Open Offline Mail System (DOS Door version)
  GPLv3 — clean-room reimplementation with Peter Rocca's permission.
  =========================================================================== }

program openolms_dos;
{ ===========================================================================
  OpenOLMS — pure DOS door, no frameworks
  ---------------------------------------------------------------------------
  ANSI menus, Crt for input, CP437 box drawing. The classic BBS door
  approach. Works over COM port (remote caller) or local console.

  This is what a sysop types in their BBS menu config:
    C:\OLMS\OPENOLMS.EXE /D:C:\RA
  =========================================================================== }

{$MODE OBJFPC}{$H+}

uses
  SysUtils,
  OL_ANSI, OL_Config, OL_DropFile, OL_MsgCtl, OL_Users,
  OL_Hudson, OL_QWK, OL_Packer, OL_Filter;

const
  VERSION = 'OpenOLMS 1.0 — Open Offline Mail System';

var
  Cfg: TOLMSConfig;
  Session: TSessionInfo;
  User: TOLMSUser;
  Areas: TMsgAreaList;
  Filter: TKeywordFilter;
  Twit: TTwitList;
  Running: Boolean;

procedure ShowLogo;
begin
  ANSICls;
  ANSIColor(acCyan or acBright, acBlack);
  ANSIWriteLn('  ██████  ██      ██   ██ ███████');
  ANSIWriteLn('  ██  ██  ██      ███ ███ ██    ');
  ANSIWriteLn('  ██  ██  ██      ██ █ ██  ████ ');
  ANSIWriteLn('  ██████  ██████  ██   ██ ███████');
  ANSIColor(acWhite, acBlack);
  ANSIWriteLn('');
  ANSIWriteLn('  ' + VERSION);
  ANSIColor(acYellow, acBlack);
  ANSIWriteLn('  Clean-room reimplementation by the netmodem2irc team');
  ANSIWriteLn('  With permission from Peter Rocca (MCC, 1994-1998)');
  ANSIReset;
  ANSIWriteLn('');
end;

procedure ShowMainMenu;
begin
  ANSIHeader('Main Menu');
  ANSIWriteLn('');
  ANSIMenuItem('S', 'Scan & Download new messages');
  ANSIMenuItem('D', 'Download only (skip scan display)');
  ANSIMenuItem('U', 'Upload reply packet (.REP)');
  ANSIMenuItem('A', 'Area selection');
  ANSIMenuItem('K', 'Keyword filter setup');
  ANSIMenuItem('T', 'Twit list (blocked senders)');
  ANSIMenuItem('R', 'Reset message pointers');
  ANSIMenuItem('P', 'Preferences (archive, protocol)');
  ANSIMenuItem('?', 'Help');
  ANSIMenuItem('Q', 'Quit to BBS');
  ANSIWriteLn('');
  ANSIStatusBar('OpenOLMS | User: ' + Session.UserName +
    ' | Time: ' + IntToStr(Session.TimeLeft) + ' min');
end;

procedure DoScanDownload;
var
  PR: TPackResult;
begin
  ANSICls;
  ANSIHeader('Scanning Message Areas');
  ANSIWriteLn('');
  ANSIInfo('Scanning ' + IntToStr(Length(Areas)) + ' areas...');
  ANSIWriteLn('');

  PR := PackQWK(Cfg, Session, User, Areas, nil);

  if PR.Success then
  begin
    ANSIColor(acGreen or acBright, acBlack);
    ANSIWriteLn('Pack complete!');
    ANSIInfo('  Areas scanned: ' + IntToStr(PR.TotalAreas));
    ANSIInfo('  Messages packed: ' + IntToStr(PR.TotalMessages));
    ANSIInfo('  Packet: ' + PR.PacketFile);
  end
  else
  begin
    if PR.TotalMessages = 0 then
      ANSIInfo('No new messages to pack.')
    else
      ANSIError(PR.ErrorMsg);
  end;

  ANSIWriteLn('');
  ANSIPause;
end;

procedure DoUpload;
var
  RepFile: String;
  UR: TUnpackResult;
begin
  ANSICls;
  ANSIHeader('Upload Reply Packet');
  ANSIWriteLn('');
  ANSIPrompt('Enter .REP filename (or ENTER to cancel): ');
  RepFile := ANSIReadLn(60);
  if RepFile = '' then Exit;

  UR := UnpackREP(Cfg, Session, RepFile);

  if UR.Success then
  begin
    ANSIColor(acGreen or acBright, acBlack);
    ANSIWriteLn('Upload processed!');
    ANSIInfo('  Replies found: ' + IntToStr(UR.TotalReplies));
    ANSIInfo('  Imported: ' + IntToStr(UR.Imported));
    if UR.Duplicates > 0 then
      ANSIInfo('  Duplicates skipped: ' + IntToStr(UR.Duplicates));
  end
  else
    ANSIError(UR.ErrorMsg);

  ANSIWriteLn('');
  ANSIPause;
end;

procedure DoAreaSelection;
var
  I: Integer;
  Ch: Char;
begin
  ANSICls;
  ANSIHeader('Area Selection');
  ANSIWriteLn('');

  for I := 0 to High(Areas) do
  begin
    if AreaHasFlag(Areas[I], AF_BLOCKED) then Continue;

    if AreaHasFlag(Areas[I], AF_READONLY) then
      ANSIColor(acYellow, acBlack)
    else if User.ConfSelected[Areas[I].AreaNum] then
      ANSIColor(acGreen or acBright, acBlack)
    else
      ANSIColor(acWhite, acBlack);

    ANSIWrite(Format('  %3d ', [Areas[I].AreaNum]));
    if User.ConfSelected[Areas[I].AreaNum] then
      ANSIWrite('[X] ')
    else
      ANSIWrite('[ ] ');
    ANSIWrite(Areas[I].Name);
    if AreaHasFlag(Areas[I], AF_READONLY) then
      ANSIWrite(' (forced)');
    ANSIWriteLn('');

    if (I > 0) and ((I mod 20) = 0) then
    begin
      ANSIPrompt('More... (Q to stop, ENTER to continue) ');
      Ch := UpCase(ANSIReadKey);
      WriteLn;
      if Ch = 'Q' then Break;
    end;
  end;

  ANSIWriteLn('');
  ANSIInfo('Toggle areas by number, or A=all on, N=all off, Q=done');
  ANSIReset;
  ANSIPause;
end;

procedure DoKeywords;
var
  I: Integer;
begin
  ANSICls;
  ANSIHeader('Keyword Filter');
  ANSIWriteLn('');

  if Filter.Mode = fmNone then
    ANSIInfo('  Filter: OFF (all messages included)')
  else if Filter.Mode = fmInclude then
    ANSIInfo('  Filter: INCLUDE (only matching messages)')
  else
    ANSIInfo('  Filter: EXCLUDE (skip matching messages)');

  ANSIWriteLn('');
  if Length(Filter.Keywords) > 0 then
  begin
    ANSIInfo('  Keywords:');
    for I := 0 to High(Filter.Keywords) do
      ANSIWriteLn('    ' + Filter.Keywords[I]);
  end
  else
    ANSIInfo('  No keywords defined.');

  ANSIWriteLn('');
  ANSIPause;
end;

procedure DoTwitList;
var I: Integer;
begin
  ANSICls;
  ANSIHeader('Twit List (Blocked Senders)');
  ANSIWriteLn('');

  if Length(Twit.Names) > 0 then
  begin
    for I := 0 to High(Twit.Names) do
      ANSIWriteLn('  ' + Twit.Names[I]);
  end
  else
    ANSIInfo('  No blocked senders.');

  ANSIWriteLn('');
  ANSIPause;
end;

procedure DoResetPointers;
var Ch: Char;
begin
  ANSICls;
  ANSIHeader('Reset Message Pointers');
  ANSIWriteLn('');
  ANSIMenuItem('G', 'Reset ALL areas (rescan everything)');
  ANSIMenuItem('S', 'Reset SELECTED areas only');
  ANSIMenuItem('Q', 'Cancel');
  ANSIWriteLn('');
  ANSIPrompt('Choice: ');
  Ch := UpCase(ANSIReadKey);
  WriteLn(Ch);

  case Ch of
    'G': begin
           ResetPointers(User, 0);
           ANSIInfo('All pointers reset.');
         end;
    'S': begin
           ResetSelectedPointers(User, User.ConfSelected, 0);
           ANSIInfo('Selected area pointers reset.');
         end;
  end;
  ANSIPause;
end;

procedure DoPreferences;
begin
  ANSICls;
  ANSIHeader('User Preferences');
  ANSIWriteLn('');
  ANSIInfo('  Archive: ' + IntToStr(User.ArchivePref) +
    ' (0=ZIP, 1=ARJ, 2=LHA, 3=ARC, 4=PAK, 5=RAR)');
  ANSIInfo('  Protocol: ' + IntToStr(User.ProtocolPref) +
    ' (0=Xmodem, 1=Ymodem, 2=Zmodem)');
  ANSIInfo('  Format: ' + IntToStr(User.PacketFormat) +
    ' (0=QWK, 1=BlueWave)');
  ANSIWriteLn('');
  ANSIPause;
end;

procedure DoHelp;
begin
  ANSICls;
  ANSIHeader('Help');
  ANSIWriteLn('');
  ANSIInfo('OpenOLMS is an offline mail door. It packs messages from');
  ANSIInfo('your BBS into QWK packets that you download and read in');
  ANSIInfo('an offline reader (like BlueWave, OLX, or MultiMail).');
  ANSIWriteLn('');
  ANSIInfo('After reading, compose replies offline and upload the');
  ANSIInfo('.REP packet. Your replies are imported into the BBS.');
  ANSIWriteLn('');
  ANSIInfo('Use AREA SELECTION to choose which message areas to');
  ANSIInfo('include. Use KEYWORDS to filter by topic. Use the');
  ANSIInfo('TWIT LIST to block senders you don''t want to read.');
  ANSIWriteLn('');
  ANSIInfo('Based on Peter Rocca''s OLMS (MCC, 1994-1998).');
  ANSIInfo('Clean-room reimplementation by the netmodem2irc team.');
  ANSIWriteLn('');
  ANSIPause;
end;

procedure MainLoop;
var Ch: Char;
begin
  Running := True;
  while Running do
  begin
    ANSICls;
    ShowLogo;
    ShowMainMenu;
    ANSIWriteLn('');
    ANSIPrompt('Your choice: ');
    Ch := UpCase(ANSIReadKey);
    WriteLn(Ch);

    case Ch of
      'S': DoScanDownload;
      'D': DoScanDownload;
      'U': DoUpload;
      'A': DoAreaSelection;
      'K': DoKeywords;
      'T': DoTwitList;
      'R': DoResetPointers;
      'P': DoPreferences;
      '?': DoHelp;
      'Q': begin
             if ANSIYesNo('Quit to BBS?', True) then
               Running := False;
           end;
    end;
  end;
end;

{ === Main === }
begin
  { Load configuration }
  OLMSDefaultConfig(Cfg);
  OLMSLoadConfig('OLMS.CFG', Cfg);

  { Load drop file }
  if not LoadDropFile('.', Session) then
    DefaultSession(Session);

  { Load or create user }
  NewUser(User, Session.UserName);

  { Load areas }
  if not LoadMsgCtl('MESSAGES.CTL', Areas) then
    SetLength(Areas, 0);

  { Load filters }
  LoadKeywords(Session.UserName + '.KEY', Filter);
  LoadTwitList(Session.UserName + '.TWT', Twit);

  { Run }
  MainLoop;

  { Goodbye }
  ANSICls;
  ANSIColor(acCyan or acBright, acBlack);
  ANSIWriteLn('Thanks for using OpenOLMS!');
  ANSIReset;
end.

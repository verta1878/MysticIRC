{ ===========================================================================
  MOLMS — Mystic Offline Mail System (client)
  GPLv3 — Copyright (C) 2026 FPC264IRC Contributors
  Credits: verta1878, sysop/0, evga, kiddo, wrench, g00r00
  ---------------------------------------------------------------------------
  Complete offline mail client. Connects to a BBS via mterm's connection
  stack, downloads QWK packets via Zmodem, reads mail offline with a
  threaded message viewer, composes replies with spell check, and
  uploads .REP packets.

  Uses: mtconn (Telnet/Serial/FOSSIL), mtxfer (Zmodem/Ymodem/Xmodem),
  OL_QWK (packet format), OL_Editor (reply composer + Hunspell),
  OL_Transfer (automated mail run).
  =========================================================================== }

{$MODE OBJFPC}{$H+}

program molms;

uses
  SysUtils, Classes,
  App, Objects, Drivers, Views, Menus, Dialogs, MsgBox,
  mtconn, mtxfer,
  OL_QWK, OL_Config, OL_Packer, OL_Filter, OL_Transfer, OL_Editor;

const
  VERSION = 'MOLMS 0.1 — Mystic Offline Mail System';

  cmBBSConnect   = 200;  cmBBSDisconnect = 201;
  cmDownloadQWK  = 202;  cmUploadREP     = 203;
  cmAutoMailRun  = 204;
  cmReadMail     = 210;  cmNextMsg       = 211;
  cmPrevMsg      = 212;  cmNextArea      = 213;
  cmPrevArea     = 214;  cmReply         = 215;
  cmSearchMsg    = 216;  cmAreaList      = 217;
  cmSpellCheck   = 218;
  cmBBSList      = 220;  cmAddBBS        = 221;
  cmEditBBS      = 222;  cmPrefs         = 223;
  cmAbout        = 230;

type
  TBBSEntry = record
    Name, Address, UserName, Password, DoorCmd: String;
    Port: Word;
    PacketDir: String;
    BBSID: String;
  end;

  TMailMessage = record
    MsgNum: LongInt; ConfNum: Word; ConfName: String;
    MsgFrom, MsgTo, Subject, DateTime, Body: String;
    IsPrivate, IsPersonal, Read: Boolean;
    RefNum: LongInt;
  end;

  TMailBox = record
    Messages: array of TMailMessage;
    Replies: array of TMailMessage;
    TotalMsgs, CurMsg, CurConf: Integer;
    BBSName, BBSID, PackDate: String;
    QWKFile: String;
  end;

  TMOLMSApp = object(TApplication)
    MailBox: TMailBox;
    BBSList: array of TBBSEntry;
    CurBBS: Integer;
    Conn: TConnection;
    Xfer: TFileTransfer;
    Editor: TOLEditor;
    UserName: String;
    DataPath: String;
    constructor Init;
    destructor Done; virtual;
    procedure InitMenuBar; virtual;
    procedure InitStatusLine; virtual;
    procedure HandleEvent(var Event: TEvent); virtual;
    { Connection }
    procedure DoConnect;
    procedure DoDisconnect;
    procedure DoDownloadQWK;
    procedure DoUploadREP;
    procedure DoAutoMailRun;
    { Reader }
    procedure DoReadMail;
    procedure DoNextMsg;
    procedure DoPrevMsg;
    procedure DoNextArea;
    procedure DoPrevArea;
    procedure DoReply;
    procedure DoSpellCheck;
    procedure DoSearch;
    procedure DoAreaList;
    { Setup }
    procedure DoBBSList;
    procedure DoAddBBS;
    procedure DoPrefs;
    procedure DoAbout;
    { Helpers }
    function LoadQWKPacket(const Filename: String): Boolean;
    function GetLoginInfo: TAutoLoginInfo;
    function MsgStatus: String;
  end;

constructor TMOLMSApp.Init;
begin
  inherited Init;
  Conn := TConnection.Create;
  Xfer := TFileTransfer.Create(Conn);
  DataPath := ExtractFilePath(ParamStr(0));
  Editor := TOLEditor.Create(DataPath);
  UserName := 'User';
  CurBBS := -1;
  MailBox.TotalMsgs := 0;
  MailBox.CurMsg := 0;
  MailBox.CurConf := -1;
  SetLength(BBSList, 0);
end;

destructor TMOLMSApp.Done;
begin
  Editor.Free;
  Xfer.Free;
  Conn.Free;
  inherited Done;
end;

function TMOLMSApp.MsgStatus: String;
begin
  if MailBox.TotalMsgs = 0 then
    Result := 'No mail loaded'
  else
    Result := Format('Msg %d/%d | Area %d | Replies: %d',
      [MailBox.CurMsg + 1, MailBox.TotalMsgs,
       MailBox.Messages[MailBox.CurMsg].ConfNum,
       Length(MailBox.Replies)]);
  if Editor.SpellAvailable then
    Result := Result + ' | Spell: ON';
end;

function TMOLMSApp.GetLoginInfo: TAutoLoginInfo;
begin
  FillChar(Result, SizeOf(Result), 0);
  if CurBBS >= 0 then
  begin
    Result.UserName := BBSList[CurBBS].UserName;
    Result.Password := BBSList[CurBBS].Password;
    Result.DoorCmd  := BBSList[CurBBS].DoorCmd;
  end;
  Result.DownCmd := 'D';
  Result.UpCmd   := 'U';
  Result.Delay   := 50;
end;

procedure TMOLMSApp.InitMenuBar;
var R: TRect;
begin
  GetExtent(R);
  R.B.Y := R.A.Y + 1;
  MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~B~BS', hcNoContext, NewMenu(
      NewItem('~C~onnect', 'Alt-C', kbAltC, cmBBSConnect, hcNoContext,
      NewItem('Download ~Q~WK', 'Alt-Q', kbAltQ, cmDownloadQWK, hcNoContext,
      NewItem('~U~pload REP', 'Alt-U', kbAltU, cmUploadREP, hcNoContext,
      NewItem('Auto ~M~ail Run', 'Alt-M', kbAltM, cmAutoMailRun, hcNoContext,
      NewItem('BBS ~L~ist', 'F4', kbF4, cmBBSList, hcNoContext,
      NewItem('~A~dd BBS', '', 0, cmAddBBS, hcNoContext,
      NewItem('E~x~it', 'Alt-X', kbAltX, cmQuit, hcNoContext,
      nil)))))))),
    NewSubMenu('~M~ail', hcNoContext, NewMenu(
      NewItem('~R~ead', 'Enter', kbEnter, cmReadMail, hcNoContext,
      NewItem('~N~ext', 'PgDn', kbPgDn, cmNextMsg, hcNoContext,
      NewItem('~P~rev', 'PgUp', kbPgUp, cmPrevMsg, hcNoContext,
      NewItem('Re~p~ly', 'Alt-R', kbAltR, cmReply, hcNoContext,
      NewItem('~S~pell', 'F7', kbF7, cmSpellCheck, hcNoContext,
      NewItem('~A~reas', 'F5', kbF5, cmAreaList, hcNoContext,
      nil))))))),
    NewSubMenu('~S~etup', hcNoContext, NewMenu(
      NewItem('~P~refs', 'F9', kbF9, cmPrefs, hcNoContext,
      NewItem('A~b~out', '', 0, cmAbout, hcNoContext,
      nil))),
    nil))))));
end;

procedure TMOLMSApp.InitStatusLine;
var R: TRect;
begin
  GetExtent(R); R.A.Y := R.B.Y - 1;
  StatusLine := New(PStatusLine, Init(R,
    NewStatusDef(0, $FFFF,
      NewStatusKey('~Alt-M~ Mail Run', kbAltM, cmAutoMailRun,
      NewStatusKey('~PgDn~ Next', kbPgDn, cmNextMsg,
      NewStatusKey('~Alt-R~ Reply', kbAltR, cmReply,
      NewStatusKey('~F7~ Spell', kbF7, cmSpellCheck,
      NewStatusKey('~Alt-X~ Exit', kbAltX, cmQuit, nil))))),
    nil)));
end;

procedure TMOLMSApp.HandleEvent(var Event: TEvent);
begin
  inherited HandleEvent(Event);
  if Event.What = evCommand then begin
    case Event.Command of
      cmBBSConnect:    DoConnect;
      cmBBSDisconnect: DoDisconnect;
      cmDownloadQWK:   DoDownloadQWK;
      cmUploadREP:     DoUploadREP;
      cmAutoMailRun:   DoAutoMailRun;
      cmReadMail:      DoReadMail;
      cmNextMsg:       DoNextMsg;
      cmPrevMsg:       DoPrevMsg;
      cmNextArea:      DoNextArea;
      cmPrevArea:      DoPrevArea;
      cmReply:         DoReply;
      cmSpellCheck:    DoSpellCheck;
      cmSearchMsg:     DoSearch;
      cmAreaList:      DoAreaList;
      cmBBSList:       DoBBSList;
      cmAddBBS:        DoAddBBS;
      cmPrefs:         DoPrefs;
      cmAbout:         DoAbout;
    else Exit;
    end;
    ClearEvent(Event);
  end;
end;

{ --- Connection --- }

procedure TMOLMSApp.DoConnect;
var
  D: PDialog; R: TRect;
  Data: record Host: String[60]; PortStr: String[5]; end;
  Port: Integer;
begin
  if Conn.Connected then begin
    MessageBox(#3'Already connected.', nil, mfInformation or mfOKButton);
    Exit;
  end;

  R.Assign(12, 5, 68, 14);
  D := New(PDialog, Init(R, 'Connect to BBS'));
  R.Assign(3, 3, 53, 4);
  D^.Insert(New(PInputLine, Init(R, 60)));
  R.Assign(3, 2, 25, 3);
  D^.Insert(New(PLabel, Init(R, 'Host (or IP):', D^.Last)));
  R.Assign(3, 6, 15, 7);
  D^.Insert(New(PInputLine, Init(R, 5)));
  R.Assign(3, 5, 10, 6);
  D^.Insert(New(PLabel, Init(R, 'Port:', D^.Last)));
  R.Assign(16, 7, 26, 9);
  D^.Insert(New(PButton, Init(R, '~O~K', cmOK, bfDefault)));
  R.Assign(30, 7, 42, 9);
  D^.Insert(New(PButton, Init(R, '~C~ancel', cmCancel, bfNormal)));

  if (CurBBS >= 0) then begin
    Data.Host := BBSList[CurBBS].Address;
    Data.PortStr := IntToStr(BBSList[CurBBS].Port);
  end else begin
    Data.Host := ''; Data.PortStr := '23';
  end;
  D^.SetData(Data);

  if ExecuteDialog(D, @Data) = cmOK then begin
    Port := StrToIntDef(Data.PortStr, 23);
    if Conn.ConnectTelnet(Data.Host, Port) then
      MessageBox(#3'Connected to ' + Data.Host + ':' + IntToStr(Port),
        nil, mfInformation or mfOKButton)
    else
      MessageBox(#3'Connection failed.', nil, mfError or mfOKButton);
  end;
end;

procedure TMOLMSApp.DoDisconnect;
begin
  Conn.Disconnect;
  MessageBox(#3'Disconnected.', nil, mfInformation or mfOKButton);
end;

procedure TMOLMSApp.DoDownloadQWK;
var
  TR: TTransferResult;
  Login: TAutoLoginInfo;
begin
  if not Conn.Connected then begin
    MessageBox(#3'Not connected. Connect first (Alt-C).',
      nil, mfError or mfOKButton);
    Exit;
  end;
  Login := GetLoginInfo;
  TR := DownloadQWK(Conn, Xfer, Login, DataPath);
  if TR.Success then begin
    MessageBox(#3'QWK packet downloaded!'#13#3 + TR.FileName,
      nil, mfInformation or mfOKButton);
    LoadQWKPacket(TR.FileName);
  end else
    MessageBox(#3'Download failed: ' + TR.ErrorMsg,
      nil, mfError or mfOKButton);
end;

procedure TMOLMSApp.DoUploadREP;
var
  TR: TTransferResult;
  Login: TAutoLoginInfo;
  RepFile: String;
begin
  if Length(MailBox.Replies) = 0 then begin
    MessageBox(#3'No replies to upload.', nil, mfInformation or mfOKButton);
    Exit;
  end;
  if not Conn.Connected then begin
    MessageBox(#3'Not connected. Connect first (Alt-C).',
      nil, mfError or mfOKButton);
    Exit;
  end;
  RepFile := DataPath + MailBox.BBSID + '.REP';
  { TODO: pack replies into RepFile using OL_Packer }
  Login := GetLoginInfo;
  TR := UploadREP(Conn, Xfer, Login, RepFile);
  if TR.Success then
    MessageBox(#3'REP uploaded! ' + IntToStr(Length(MailBox.Replies)) + ' replies sent.',
      nil, mfInformation or mfOKButton)
  else
    MessageBox(#3'Upload failed: ' + TR.ErrorMsg,
      nil, mfError or mfOKButton);
end;

procedure TMOLMSApp.DoAutoMailRun;
var
  TR: TTransferResult;
  Login: TAutoLoginInfo;
  RepFile: String;
begin
  if CurBBS < 0 then begin
    MessageBox(#3'No BBS selected. Add one first.',
      nil, mfError or mfOKButton);
    Exit;
  end;
  Login := GetLoginInfo;
  RepFile := '';
  if Length(MailBox.Replies) > 0 then
    RepFile := DataPath + MailBox.BBSID + '.REP';

  TR := AutoMailRun(Conn, Xfer,
    BBSList[CurBBS].Address, BBSList[CurBBS].Port,
    Login, DataPath, RepFile);

  if TR.Success then begin
    MessageBox(#3'Mail run complete!'#13#3 + TR.FileName,
      nil, mfInformation or mfOKButton);
    LoadQWKPacket(TR.FileName);
  end else
    MessageBox(#3'Mail run failed: ' + TR.ErrorMsg,
      nil, mfError or mfOKButton);
end;

{ --- QWK Loading --- }

function TMOLMSApp.LoadQWKPacket(const Filename: String): Boolean;
var
  MsgFile: File;
  HdrBuf: array[0..QWK_BLOCK_SIZE - 1] of Byte;
  Hdr: TQWKHeader;
  BytesRead: LongInt;
  Count, BodyBlocks, I: Integer;
  BodyBuf: array[0..QWK_BLOCK_SIZE - 1] of Byte;
begin
  Result := False;
  if not FileExists(Filename) then Exit;
  SetLength(MailBox.Messages, 0);
  Count := 0;
  MailBox.QWKFile := Filename;

  AssignFile(MsgFile, Filename);
  {$I-} Reset(MsgFile, 1); {$I+}
  if IOResult <> 0 then Exit;

  try
    { Skip block 0 (copyright) }
    BlockRead(MsgFile, HdrBuf, QWK_BLOCK_SIZE, BytesRead);

    while not EOF(MsgFile) do begin
      FillChar(HdrBuf, QWK_BLOCK_SIZE, 0);
      BlockRead(MsgFile, HdrBuf, QWK_BLOCK_SIZE, BytesRead);
      if BytesRead <> QWK_BLOCK_SIZE then Break;

      Hdr := QWKParseHeader(HdrBuf);
      BodyBlocks := QWKBlockCount(Hdr) - 1;
      if BodyBlocks < 0 then BodyBlocks := 0;

      SetLength(MailBox.Messages, Count + 1);
      with MailBox.Messages[Count] do begin
        MsgNum    := QWKMsgNumber(Hdr);
        ConfNum   := Hdr.ConfNum;
        MsgFrom   := QWKFieldToStr(Hdr.MsgFrom, 25);
        MsgTo     := QWKFieldToStr(Hdr.MsgTo, 25);
        Subject   := QWKFieldToStr(Hdr.Subject, 25);
        DateTime  := QWKFieldToStr(Hdr.DateTime, 13);
        IsPrivate := Hdr.Status in [QWK_STATUS_PRIVATE, QWK_STATUS_PRIVATE_READ];
        IsPersonal:= CompareText(MsgTo, UserName) = 0;
        RefNum    := QWKRefNumber(Hdr);
        Read      := False;
        Body      := '';

        { Read body blocks }
        for I := 0 to BodyBlocks - 1 do begin
          FillChar(BodyBuf, QWK_BLOCK_SIZE, 0);
          BlockRead(MsgFile, BodyBuf, QWK_BLOCK_SIZE, BytesRead);
          if BytesRead <> QWK_BLOCK_SIZE then Break;
          Body := Body + QWKFieldToStr(BodyBuf, QWK_BLOCK_SIZE);
        end;
        { Convert QWK line endings }
        Body := StringReplace(Body, QWK_NEWLINE, #13#10, [rfReplaceAll]);
      end;
      Inc(Count);
    end;
  finally
    CloseFile(MsgFile);
  end;

  MailBox.TotalMsgs := Count;
  MailBox.CurMsg := 0;
  Result := Count > 0;
end;

{ --- Reader --- }

procedure TMOLMSApp.DoReadMail;
var
  D: PDialog; R: TRect;
  HeaderView, BodyView: PStaticText;
  HeaderText, BodyText: String;
begin
  if MailBox.TotalMsgs = 0 then begin
    MessageBox(#3'No mail loaded. Download a QWK packet (Alt-Q) or'#13#3 +
      'run Auto Mail Run (Alt-M).', nil, mfInformation or mfOKButton);
    Exit;
  end;

  with MailBox.Messages[MailBox.CurMsg] do begin
    Read := True;
    HeaderText :=
      ' From: ' + MsgFrom + #13 +
      ' To:   ' + MsgTo + #13 +
      ' Subj: ' + Subject + #13 +
      ' Date: ' + DateTime +
      '  Area: ' + IntToStr(ConfNum) +
      '  #' + IntToStr(MsgNum);
    if IsPersonal then HeaderText := HeaderText + ' [PERSONAL]';
    if IsPrivate then HeaderText := HeaderText + ' [PRIVATE]';

    BodyText := Copy(Body, 1, 2000);
  end;

  R.Assign(1, 1, 79, 23);
  D := New(PDialog, Init(R, MsgStatus));

  R.Assign(1, 1, 76, 5);
  New(HeaderView, Init(R, HeaderText));
  D^.Insert(HeaderView);

  R.Assign(1, 6, 76, 19);
  New(BodyView, Init(R, BodyText));
  D^.Insert(BodyView);

  R.Assign(2, 20, 14, 22);
  D^.Insert(New(PButton, Init(R, '~N~ext', cmNextMsg, bfNormal)));
  R.Assign(16, 20, 28, 22);
  D^.Insert(New(PButton, Init(R, '~P~rev', cmPrevMsg, bfNormal)));
  R.Assign(30, 20, 44, 22);
  D^.Insert(New(PButton, Init(R, '~R~eply', cmReply, bfNormal)));
  R.Assign(46, 20, 60, 22);
  D^.Insert(New(PButton, Init(R, '~A~rea +', cmNextArea, bfNormal)));
  R.Assign(62, 20, 76, 22);
  D^.Insert(New(PButton, Init(R, '~C~lose', cmCancel, bfDefault)));

  ExecuteDialog(D, nil);
end;

procedure TMOLMSApp.DoNextMsg;
begin
  if MailBox.CurMsg < MailBox.TotalMsgs - 1 then Inc(MailBox.CurMsg);
  DoReadMail;
end;

procedure TMOLMSApp.DoPrevMsg;
begin
  if MailBox.CurMsg > 0 then Dec(MailBox.CurMsg);
  DoReadMail;
end;

procedure TMOLMSApp.DoNextArea;
var I: Integer; CurConf: Word;
begin
  if MailBox.TotalMsgs = 0 then Exit;
  CurConf := MailBox.Messages[MailBox.CurMsg].ConfNum;
  for I := MailBox.CurMsg + 1 to MailBox.TotalMsgs - 1 do
    if MailBox.Messages[I].ConfNum <> CurConf then begin
      MailBox.CurMsg := I;
      DoReadMail;
      Exit;
    end;
  MessageBox(#3'Last area.', nil, mfInformation or mfOKButton);
end;

procedure TMOLMSApp.DoPrevArea;
var I: Integer; CurConf: Word;
begin
  if MailBox.TotalMsgs = 0 then Exit;
  CurConf := MailBox.Messages[MailBox.CurMsg].ConfNum;
  for I := MailBox.CurMsg - 1 downto 0 do
    if MailBox.Messages[I].ConfNum <> CurConf then begin
      MailBox.CurMsg := I;
      DoReadMail;
      Exit;
    end;
  MessageBox(#3'First area.', nil, mfInformation or mfOKButton);
end;

procedure TMOLMSApp.DoReply;
var
  D: PDialog; R: TRect;
  Data: record
    MsgTo: String[25]; Subject: String[25]; Body: String[255];
  end;
  Reply: TMailMessage;
begin
  if MailBox.TotalMsgs = 0 then Exit;

  R.Assign(3, 2, 77, 21);
  D := New(PDialog, Init(R, 'Reply — ' + MsgStatus));

  R.Assign(3, 3, 71, 4);
  D^.Insert(New(PInputLine, Init(R, 25)));
  R.Assign(3, 2, 8, 3);
  D^.Insert(New(PLabel, Init(R, 'To:', D^.Last)));

  R.Assign(3, 6, 71, 7);
  D^.Insert(New(PInputLine, Init(R, 25)));
  R.Assign(3, 5, 12, 6);
  D^.Insert(New(PLabel, Init(R, 'Subject:', D^.Last)));

  R.Assign(3, 9, 71, 16);
  D^.Insert(New(PInputLine, Init(R, 255)));
  R.Assign(3, 8, 12, 9);
  D^.Insert(New(PLabel, Init(R, 'Message:', D^.Last)));

  R.Assign(18, 17, 30, 19);
  D^.Insert(New(PButton, Init(R, '~S~end', cmOK, bfDefault)));
  R.Assign(34, 17, 48, 19);
  D^.Insert(New(PButton, Init(R, 'S~p~ell', cmNo, bfNormal)));
  R.Assign(52, 17, 66, 19);
  D^.Insert(New(PButton, Init(R, '~C~ancel', cmCancel, bfNormal)));

  with MailBox.Messages[MailBox.CurMsg] do begin
    Data.MsgTo := MsgFrom;
    if Copy(Subject, 1, 4) <> 'Re: ' then
      Data.Subject := 'Re: ' + Subject
    else Data.Subject := Subject;
    Data.Body := '';
  end;
  D^.SetData(Data);

  case ExecuteDialog(D, @Data) of
    cmOK: begin
      FillChar(Reply, SizeOf(Reply), 0);
      Reply.MsgTo    := Data.MsgTo;
      Reply.Subject  := Data.Subject;
      Reply.Body     := Data.Body;
      Reply.MsgFrom  := UserName;
      Reply.ConfNum  := MailBox.Messages[MailBox.CurMsg].ConfNum;
      Reply.RefNum   := MailBox.Messages[MailBox.CurMsg].MsgNum;
      Reply.DateTime := FormatDateTime('mm-dd-yyhh:nn', Now);
      SetLength(MailBox.Replies, Length(MailBox.Replies) + 1);
      MailBox.Replies[High(MailBox.Replies)] := Reply;
      MessageBox(#3'Reply saved. ' + IntToStr(Length(MailBox.Replies)) + ' pending.',
        nil, mfInformation or mfOKButton);
    end;
    cmNo: begin
      { Spell check button }
      Editor.Clear;
      Editor.AddText(Data.Body);
      DoSpellCheck;
    end;
  end;
end;

procedure TMOLMSApp.DoSpellCheck;
var Errors: Integer; Msg: String;
begin
  if not Editor.SpellAvailable then begin
    MessageBox(#3'Spell check not available.'#13#3 +
      'See SPELL_SETUP.md for Hunspell setup.',
      nil, mfInformation or mfOKButton);
    Exit;
  end;
  Errors := Editor.SpellCheckAll;
  if Errors = 0 then Msg := #3'No spelling errors found.'
  else Msg := #3 + IntToStr(Errors) + ' spelling error(s) found.';
  MessageBox(Msg, nil, mfInformation or mfOKButton);
end;

procedure TMOLMSApp.DoSearch;
begin
  MessageBox(#3'Search: not yet wired.', nil, mfInformation or mfOKButton);
end;

procedure TMOLMSApp.DoAreaList;
var
  Msg: String;
  Counts: array[0..999] of Integer;
  Seen: array[0..999] of Boolean;
  I: Integer;
begin
  FillChar(Counts, SizeOf(Counts), 0);
  FillChar(Seen, SizeOf(Seen), 0);
  for I := 0 to MailBox.TotalMsgs - 1 do
    if MailBox.Messages[I].ConfNum < 1000 then begin
      Inc(Counts[MailBox.Messages[I].ConfNum]);
      Seen[MailBox.Messages[I].ConfNum] := True;
    end;

  Msg := #3 + IntToStr(MailBox.TotalMsgs) + ' messages in packet'#13#13;
  for I := 0 to 999 do
    if Seen[I] then
      Msg := Msg + #3 + Format('  Area %3d: %d msgs', [I, Counts[I]]) + #13;

  MessageBox(Msg, nil, mfInformation or mfOKButton);
end;

{ --- Setup --- }

procedure TMOLMSApp.DoBBSList;
var Msg: String; I: Integer;
begin
  if Length(BBSList) = 0 then begin
    MessageBox(#3'No BBS entries. Use Add BBS to create one.',
      nil, mfInformation or mfOKButton);
    Exit;
  end;
  Msg := #3'BBS Address Book'#13#13;
  for I := 0 to High(BBSList) do begin
    if I = CurBBS then Msg := Msg + #3'-> '
    else Msg := Msg + #3'   ';
    Msg := Msg + IntToStr(I + 1) + '. ' + BBSList[I].Name +
      ' (' + BBSList[I].Address + ':' + IntToStr(BBSList[I].Port) + ')' + #13;
  end;
  MessageBox(Msg, nil, mfInformation or mfOKButton);
end;

procedure TMOLMSApp.DoAddBBS;
var
  D: PDialog; R: TRect;
  Data: record
    Name: String[40]; Address: String[60]; PortStr: String[5];
    Login: String[25]; Pass: String[25]; Door: String[10];
  end;
  Entry: TBBSEntry;
begin
  R.Assign(5, 2, 75, 20);
  D := New(PDialog, Init(R, 'Add BBS'));

  R.Assign(3, 3, 67, 4);
  D^.Insert(New(PInputLine, Init(R, 40)));
  R.Assign(3, 2, 15, 3);
  D^.Insert(New(PLabel, Init(R, 'BBS Name:', D^.Last)));

  R.Assign(3, 6, 50, 7);
  D^.Insert(New(PInputLine, Init(R, 60)));
  R.Assign(3, 5, 12, 6);
  D^.Insert(New(PLabel, Init(R, 'Address:', D^.Last)));

  R.Assign(52, 6, 62, 7);
  D^.Insert(New(PInputLine, Init(R, 5)));
  R.Assign(52, 5, 58, 6);
  D^.Insert(New(PLabel, Init(R, 'Port:', D^.Last)));

  R.Assign(3, 9, 30, 10);
  D^.Insert(New(PInputLine, Init(R, 25)));
  R.Assign(3, 8, 12, 9);
  D^.Insert(New(PLabel, Init(R, 'Login:', D^.Last)));

  R.Assign(32, 9, 62, 10);
  D^.Insert(New(PInputLine, Init(R, 25)));
  R.Assign(32, 8, 45, 9);
  D^.Insert(New(PLabel, Init(R, 'Password:', D^.Last)));

  R.Assign(3, 12, 20, 13);
  D^.Insert(New(PInputLine, Init(R, 10)));
  R.Assign(3, 11, 15, 12);
  D^.Insert(New(PLabel, Init(R, 'Door cmd:', D^.Last)));

  R.Assign(22, 15, 32, 17);
  D^.Insert(New(PButton, Init(R, '~O~K', cmOK, bfDefault)));
  R.Assign(36, 15, 50, 17);
  D^.Insert(New(PButton, Init(R, '~C~ancel', cmCancel, bfNormal)));

  Data.Name := ''; Data.Address := ''; Data.PortStr := '23';
  Data.Login := ''; Data.Pass := ''; Data.Door := 'O';
  D^.SetData(Data);

  if ExecuteDialog(D, @Data) = cmOK then begin
    Entry.Name := Data.Name;
    Entry.Address := Data.Address;
    Entry.Port := StrToIntDef(Data.PortStr, 23);
    Entry.UserName := Data.Login;
    Entry.Password := Data.Pass;
    Entry.DoorCmd := Data.Door;
    Entry.PacketDir := DataPath;
    SetLength(BBSList, Length(BBSList) + 1);
    BBSList[High(BBSList)] := Entry;
    CurBBS := High(BBSList);
  end;
end;

procedure TMOLMSApp.DoPrefs;
begin
  MessageBox(#3'User: ' + UserName + #13 +
    #3'Messages: ' + IntToStr(MailBox.TotalMsgs) + #13 +
    #3'Replies pending: ' + IntToStr(Length(MailBox.Replies)) + #13 +
    #3'Spell check: ' + BoolToStr(Editor.SpellAvailable, 'Available', 'Not loaded') + #13 +
    #3'Data path: ' + DataPath,
    nil, mfInformation or mfOKButton);
end;

procedure TMOLMSApp.DoAbout;
begin
  MessageBox(#3 + VERSION + #13#13 +
    #3'Connect -> Download QWK -> Read Offline -> Reply -> Upload REP'#13#13 +
    #3'mterm connection stack + Mystic protocol stack (GPLv3)'#13 +
    #3'QWK/BlueWave packet formats. Hunspell spell check.'#13#13 +
    #3'Based on Peter Rocca''s OLMS (MCC, 1994-1998).'#13 +
    #3'Team: verta1878, sysop/0, evga, kiddo, wrench, g00r00',
    nil, mfInformation or mfOKButton);
end;

var MOLMSApp: TMOLMSApp;
begin
  MOLMSApp.Init;
  MOLMSApp.Run;
  MOLMSApp.Done;
end.

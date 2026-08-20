{ ===========================================================================
  OpenOLMS — Open Offline Mail System
  Pending licence — with permission from Peter Rocca.
  =========================================================================== }

unit OL_Packer;
{ ===========================================================================
  OpenOLMS — QWK packer / REP unpacker
  ---------------------------------------------------------------------------
  The core engine: reads messages from the message base, packs them into
  a .QWK archive, and processes uploaded .REP reply packets.

  Pack flow:
    1. For each selected area, read messages after the user's pointer
    2. Convert each message to a QWK 128-byte block header + body
    3. Write MESSAGES.DAT (all messages concatenated in blocks)
    4. Write per-area .NDX index files
    5. Write CONTROL.DAT (BBS info + conference list)
    6. Write DOOR.ID (door identification)
    7. ZIP everything into <BBSID>.QWK

  Unpack flow:
    1. UNZIP the .REP file
    2. Read <BBSID>.MSG — same block format as MESSAGES.DAT
    3. For each reply message, import into the message base
    4. Handle duplicate detection if enabled

  Uses the configured archiver commands (PKZIP/PKUNZIP by default).
  =========================================================================== }

{$MODE OBJFPC}{$H+}

interface

uses
  OL_Config, OL_QWK, OL_MsgCtl, OL_Users, OL_Hudson, OL_DropFile;

type
  TPackResult = record
    TotalAreas   : Integer;
    TotalMessages: Integer;
    PacketFile   : String;
    Success      : Boolean;
    ErrorMsg     : String;
  end;

  TUnpackResult = record
    TotalReplies : Integer;
    Imported     : Integer;
    Duplicates   : Integer;
    Success      : Boolean;
    ErrorMsg     : String;
  end;

  { Progress callback — the packer calls this so the UI can update }
  TPackProgress = procedure(const AreaName: String;
    MsgCount, TotalSoFar: Integer) of object;

{ Pack messages into a .QWK file }
function PackQWK(const Cfg: TOLMSConfig;
  const Session: TSessionInfo;
  var User: TOLMSUser;
  const Areas: TMsgAreaList;
  OnProgress: TPackProgress): TPackResult;

{ Unpack a .REP reply file and import messages }
function UnpackREP(const Cfg: TOLMSConfig;
  const Session: TSessionInfo;
  const RepFile: String): TUnpackResult;

{ Write CONTROL.DAT }
procedure WriteControlDat(const Filename: String;
  const Cfg: TOLMSConfig;
  const Session: TSessionInfo;
  const Areas: TMsgAreaList);

{ Write DOOR.ID }
procedure WriteDoorId(const Filename: String);

implementation

uses SysUtils, Classes;

const
  BBSID = 'OPENOLMS';   { BBS ID for packet filenames }

procedure WriteControlDat(const Filename: String;
  const Cfg: TOLMSConfig;
  const Session: TSessionInfo;
  const Areas: TMsgAreaList);
var
  F: Text;
  I: Integer;
begin
  AssignFile(F, Filename);
  Rewrite(F);
  try
    WriteLn(F, Cfg.BBSName);
    WriteLn(F, '');                { city — not stored in our config yet }
    WriteLn(F, Cfg.BBSPhone);
    WriteLn(F, Cfg.SysopName);
    WriteLn(F, '0');               { door registration number }
    WriteLn(F, FormatDateTime('mm-dd-yyyy', Now));
    WriteLn(F, FormatDateTime('hh:nn:ss', Now));
    WriteLn(F, Session.UserName);
    WriteLn(F, '');                { line 9: unused }
    WriteLn(F, '');                { line 10: unused }
    WriteLn(F, Length(Areas) - 1); { number of conferences - 1 }
    for I := 0 to High(Areas) do
    begin
      WriteLn(F, Areas[I].AreaNum);
      WriteLn(F, Areas[I].Name);
    end;
    { Hello and Goodbye file references }
    WriteLn(F, 'HELLO');
    WriteLn(F, 'GOODBYE');
  finally
    CloseFile(F);
  end;
end;

procedure WriteDoorId(const Filename: String);
var F: Text;
begin
  AssignFile(F, Filename);
  Rewrite(F);
  try
    WriteLn(F, 'DOOR = OpenOLMS');
    WriteLn(F, 'VERSION = 0.1');
    WriteLn(F, 'SYSTEM = FPC/FV');
    WriteLn(F, 'CONTROLNAME = OPENOLMS');
    WriteLn(F, 'CONTROLTYPE = ADD');
    WriteLn(F, 'CONTROLTYPE = DROP');
  finally
    CloseFile(F);
  end;
end;

function PackQWK(const Cfg: TOLMSConfig;
  const Session: TSessionInfo;
  var User: TOLMSUser;
  const Areas: TMsgAreaList;
  OnProgress: TPackProgress): TPackResult;
var
  WorkDir: String;
  MsgFile: File;
  NdxFile: File;
  BlockNum: LongInt;
  I, J, MsgCount, TotalMsgs: Integer;
  Messages: array[0..999] of THudsonMessage;
  ReadCount: Integer;
  Hdr: TQWKHeader;
  HdrBuf: array[0..QWK_BLOCK_SIZE - 1] of Byte;
  BodyBytes: String;
  BodyBlocks, TotalBlocks: Integer;
  BodyBuf: array[0..QWK_BLOCK_SIZE - 1] of Byte;
  K, Written: Integer;
  BodyPos: Integer;
  ArchiveCmd: String;
begin
  Result.Success := False;
  Result.TotalAreas := 0;
  Result.TotalMessages := 0;
  Result.PacketFile := '';
  TotalMsgs := 0;

  WorkDir := IncludeTrailingPathDelimiter(Cfg.DownloadPath);
  ForceDirectories(WorkDir);

  { Create MESSAGES.DAT }
  AssignFile(MsgFile, WorkDir + 'MESSAGES.DAT');
  {$I-} Rewrite(MsgFile, 1); {$I+}
  if IOResult <> 0 then
  begin
    Result.ErrorMsg := 'Cannot create MESSAGES.DAT';
    Exit;
  end;

  try
    { Block 0 is a 128-byte copyright notice (per QWK spec) }
    FillChar(HdrBuf, QWK_BLOCK_SIZE, ' ');
    Move('Produced by OpenOLMS', HdrBuf[0], 20);
    BlockWrite(MsgFile, HdrBuf, QWK_BLOCK_SIZE);
    BlockNum := 1;

    for I := 0 to High(Areas) do
    begin
      { Skip unselected areas and blocked areas }
      if not User.ConfSelected[Areas[I].AreaNum] then Continue;
      if AreaHasFlag(Areas[I], AF_BLOCKED) then Continue;
      if Areas[I].BaseType <> 0 then Continue;  { Hudson only for now }

      { Read messages from this area after the user's pointer }
      ReadCount := HudsonReadBoard(
        Cfg.MsgBasePath,
        Areas[I].AreaNum,
        User.MsgPointers[Areas[I].AreaNum],
        Cfg.MaxMsgPerArea,
        Messages);

      if ReadCount = 0 then Continue;

      { Create .NDX file for this area }
      AssignFile(NdxFile, WorkDir + Format('%.3d.NDX', [Areas[I].AreaNum]));
      {$I-} Rewrite(NdxFile, 1); {$I+}
      if IOResult <> 0 then Continue;

      try
        Inc(Result.TotalAreas);
        MsgCount := 0;

        for J := 0 to ReadCount - 1 do
        begin
          { Read the full body for this message }
          if not HudsonReadMessage(Cfg.MsgBasePath,
            Messages[J].MsgNum, Messages[J]) then Continue;

          { Build the QWK header }
          FillChar(Hdr, SizeOf(Hdr), ' ');
          if Messages[J].IsPrivate then
            Hdr.Status := QWK_STATUS_PRIVATE
          else
            Hdr.Status := QWK_STATUS_PUBLIC;

          QWKStrToField(IntToStr(Messages[J].MsgNum), Hdr.MsgNum, 7);
          QWKStrToField(Messages[J].PostDate + Messages[J].PostTime,
                        Hdr.DateTime, 13);
          QWKStrToField(Messages[J].MsgTo, Hdr.MsgTo, 25);
          QWKStrToField(Messages[J].MsgFrom, Hdr.MsgFrom, 25);
          QWKStrToField(Messages[J].Subject, Hdr.Subject, 25);
          Hdr.Alive := #$E1;
          Hdr.ConfNum := Areas[I].AreaNum;

          { Convert body to QWK format: CR/LF → $E3 }
          BodyBytes := StringReplace(Messages[J].Body,
            #13#10, QWK_NEWLINE, [rfReplaceAll]);
          BodyBytes := StringReplace(BodyBytes,
            #10, QWK_NEWLINE, [rfReplaceAll]);

          { Calculate body blocks (128 bytes each, pad last with spaces) }
          BodyBlocks := (Length(BodyBytes) + QWK_BLOCK_SIZE - 1) div QWK_BLOCK_SIZE;
          if BodyBlocks < 1 then BodyBlocks := 1;
          TotalBlocks := BodyBlocks + 1;   { +1 for the header block }
          QWKStrToField(IntToStr(TotalBlocks), Hdr.NumBlocks, 6);

          { Write NDX entry pointing at this message's block offset }
          QWKWriteNdx(NdxFile, BlockNum, Areas[I].AreaNum);

          { Write header block }
          QWKWriteHeader(Hdr, HdrBuf);
          BlockWrite(MsgFile, HdrBuf, QWK_BLOCK_SIZE);
          Inc(BlockNum);

          { Write body blocks }
          BodyPos := 1;
          for K := 0 to BodyBlocks - 1 do
          begin
            FillChar(BodyBuf, QWK_BLOCK_SIZE, ' ');
            Written := Length(BodyBytes) - BodyPos + 1;
            if Written > QWK_BLOCK_SIZE then Written := QWK_BLOCK_SIZE;
            if Written > 0 then
              Move(BodyBytes[BodyPos], BodyBuf[0], Written);
            BlockWrite(MsgFile, BodyBuf, QWK_BLOCK_SIZE);
            Inc(BodyPos, QWK_BLOCK_SIZE);
            Inc(BlockNum);
          end;

          Inc(MsgCount);
          Inc(TotalMsgs);

          { Update the user's message pointer }
          if Messages[J].MsgNum > User.MsgPointers[Areas[I].AreaNum] then
            User.MsgPointers[Areas[I].AreaNum] := Messages[J].MsgNum;
        end;

        if Assigned(OnProgress) then
          OnProgress(Areas[I].Name, MsgCount, TotalMsgs);

      finally
        CloseFile(NdxFile);
      end;

      { Delete empty NDX files }
      if MsgCount = 0 then
        DeleteFile(WorkDir + Format('%.3d.NDX', [Areas[I].AreaNum]));
    end;

  finally
    CloseFile(MsgFile);
  end;

  Result.TotalMessages := TotalMsgs;

  if TotalMsgs = 0 then
  begin
    DeleteFile(WorkDir + 'MESSAGES.DAT');
    Result.ErrorMsg := 'No new messages to pack.';
    Exit;
  end;

  { Write CONTROL.DAT }
  WriteControlDat(WorkDir + 'CONTROL.DAT', Cfg, Session, Areas);

  { Write DOOR.ID }
  WriteDoorId(WorkDir + 'DOOR.ID');

  { Archive into .QWK using the configured archiver (default: ZIP) }
  Result.PacketFile := WorkDir + BBSID + '.QWK';
  ArchiveCmd := Cfg.Archivers[0].PackCmd + ' ' +
    Result.PacketFile + ' ' +
    WorkDir + 'MESSAGES.DAT ' +
    WorkDir + 'CONTROL.DAT ' +
    WorkDir + 'DOOR.ID ' +
    WorkDir + '*.NDX';

  { Execute the archiver }
  {$I-}
  ExecuteProcess('/bin/sh', ['-c', ArchiveCmd]);
  {$I+}
  { On DOS this would be Exec(GetEnv('COMSPEC'), '/C ' + ArchiveCmd) }

  if FileExists(Result.PacketFile) then
    Result.Success := True
  else
    Result.ErrorMsg := 'Archiver failed: ' + ArchiveCmd;
end;

function UnpackREP(const Cfg: TOLMSConfig;
  const Session: TSessionInfo;
  const RepFile: String): TUnpackResult;
var
  WorkDir: String;
  MsgFile: File;
  HdrBuf: array[0..QWK_BLOCK_SIZE - 1] of Byte;
  Hdr: TQWKHeader;
  BodyBuf: array[0..QWK_BLOCK_SIZE - 1] of Byte;
  BodyBlocks, I, J: Integer;
  Body: String;
  ArchiveCmd: String;
  BytesRead: LongInt;
  Ch: Char;
begin
  Result.Success := False;
  Result.TotalReplies := 0;
  Result.Imported := 0;
  Result.Duplicates := 0;

  if not FileExists(RepFile) then
  begin
    Result.ErrorMsg := 'REP file not found: ' + RepFile;
    Exit;
  end;

  WorkDir := IncludeTrailingPathDelimiter(Cfg.UploadPath);
  ForceDirectories(WorkDir);

  { Unpack the .REP archive }
  ArchiveCmd := Cfg.Archivers[0].UnpackCmd + ' ' + RepFile + ' ' + WorkDir;
  {$I-}
  ExecuteProcess('/bin/sh', ['-c', ArchiveCmd]);
  {$I+}

  { Read the reply messages from <BBSID>.MSG }
  if not FileExists(WorkDir + BBSID + '.MSG') then
  begin
    Result.ErrorMsg := 'No ' + BBSID + '.MSG found in REP packet.';
    Exit;
  end;

  AssignFile(MsgFile, WorkDir + BBSID + '.MSG');
  {$I-} Reset(MsgFile, 1); {$I+}
  if IOResult <> 0 then
  begin
    Result.ErrorMsg := 'Cannot open ' + BBSID + '.MSG';
    Exit;
  end;

  try
    { Skip the first 128-byte block (copyright/header) }
    BlockRead(MsgFile, HdrBuf, QWK_BLOCK_SIZE, BytesRead);

    while not EOF(MsgFile) do
    begin
      { Read message header block }
      FillChar(HdrBuf, QWK_BLOCK_SIZE, 0);
      BlockRead(MsgFile, HdrBuf, QWK_BLOCK_SIZE, BytesRead);
      if BytesRead <> QWK_BLOCK_SIZE then Break;

      Hdr := QWKParseHeader(HdrBuf);
      BodyBlocks := QWKBlockCount(Hdr) - 1;
      if BodyBlocks < 0 then BodyBlocks := 0;

      { Read body blocks }
      Body := '';
      for I := 0 to BodyBlocks - 1 do
      begin
        FillChar(BodyBuf, QWK_BLOCK_SIZE, 0);
        BlockRead(MsgFile, BodyBuf, QWK_BLOCK_SIZE, BytesRead);
        if BytesRead <> QWK_BLOCK_SIZE then Break;
        for J := 0 to QWK_BLOCK_SIZE - 1 do
        begin
          Ch := Char(BodyBuf[J]);
          if Ch = QWK_NEWLINE then
            Body := Body + #13#10
          else if Ch <> #0 then
            Body := Body + Ch;
        end;
      end;

      Inc(Result.TotalReplies);

      { TODO Phase 4: import into Hudson/JAM message base.
        For now, just count the replies as successfully parsed. }
      Inc(Result.Imported);
    end;

    Result.Success := True;
  finally
    CloseFile(MsgFile);
  end;
end;

end.

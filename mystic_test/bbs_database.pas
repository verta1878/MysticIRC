Unit BBS_DataBase;

// ====================================================================
// Mystic BBS Software               Copyright 1997-2013 By James Coyle
// ====================================================================
//
// This file is part of Mystic BBS.
//
// Mystic BBS is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Mystic BBS is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Mystic BBS.  If not, see <http://www.gnu.org/licenses/>.
//
// ====================================================================

// for all functions... need to go through code and remove old stuff and
// replace with this new stuff one at a time.  including moving everything
// to bbscfg.

// add generatembase/fbase/userindex functions?

{$I M_OPS.PAS}

Interface

Uses
  m_Types,
  m_Output,
  m_Input,
  BBS_Records,
  BBS_MsgBase_ABS,
  BBS_MsgBase_JAM,
  BBS_MsgBase_Squish;

Var
  bbsCfg       : RecConfig;
  bbsCfgPath   : String;
  bbsCfgStatus : Byte;
  Console      : TOutput;
  Keyboard     : TInput;

Const
  CfgOK       = 0;
  CfgNotFound = 1;
  CfgMisMatch = 2;

Type
  FileDescBuffer = Array[1..99] of String[50];

// GENERAL

Function  GetBaseConfiguration  (UseEnv: Boolean; Var TempCfg: RecConfig) : Byte;
Function  PutBaseConfiguration  (Var TempCfg: RecConfig) : Boolean;
Function  ExecuteProgram        (ExecPath: String; Command: String) : LongInt;
Function  Addr2Str              (Addr : RecEchoMailAddr) : String;
Function  Str2Addr              (S : String; Var Addr: RecEchoMailAddr) : Boolean;

// MESSAGE BASE

Function  MBaseOpenCreate       (Var Msg: PMsgBaseABS; Var Area: RecMessageBase; TP: String) : Boolean;
Function  GetOriginLine         (Var mArea: RecMessageBase) : String;
Function  GetMBaseByIndex       (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
Function  GetMBaseByQwkID       (QwkNet, QwkConf: LongInt; Var TempBase: RecMessageBase) : Boolean;
Procedure GetMessageScan        (UN: Cardinal; TempBase: RecMessageBase; Var TempScan: MScanRec);
Procedure PutMessageScan        (UN: Cardinal; TempBase: RecMessageBase; TempScan: MScanRec);
Procedure MBaseAssignData       (Var User: RecUser; Var Msg: PMsgBaseABS; Var TempBase: RecMessageBase);
Function  GetQWKNetByIndex      (Num: LongInt; Var TempNet: RecQwkNetwork) : Boolean;

// FILE BASE

Procedure ExecuteArchive        (TempP: String; FName: String; Temp: String; Mask: String; Mode: Byte);
Function  GetTotalFiles         (Var TempBase: RecFileBase) : LongInt;
Function  IsDuplicateFile       (Base: RecFileBase; FileName: String; Global: Boolean) : Boolean;
Function  ImportFileDIZ         (Var Desc: FileDescBuffer; Var DescLines: Byte; TempP, FN: String) : Boolean;

// USER

Function IsThisUser             (U: RecUser; Str: String) : Boolean;

// ECHOMAIL

Function GetFTNPKTName    : String;
Function GetFTNBundleExt  (IncOnly: Boolean; Str: String) : String;
Function GetNodeByAddress (Addr: String; Var TempNode: RecEchoMailNode) : Boolean;
Function GetNodeByIndex   (Num: LongInt; Var TempNode: RecEchoMailNode) : Boolean;
Function SaveEchoMailNode (Var TempNode: RecEchoMailNode) : Boolean;

// A39: FTN routing + echomail export management (imported for the FidoNet pass)
Function  GetUserByRec         (Num: LongInt; Var U: RecUser) : Boolean;
Function  GetNodeByRoute       (Dest: RecEchoMailAddr; Var TempNode: RecEchoMailNode) : Boolean;
Function  IsExportNode         (Var MBase: RecMessageBase; Idx: LongInt) : Boolean;
Procedure AddExportByBase      (Var MBase: RecMessageBase; Idx: LongInt);
Procedure RemoveExportFromBase (Var MBase: RecMessageBase; Idx: LongInt);
Procedure RemoveExportGlobal   (Idx: LongInt);
Function  GetMatchedAddress    (Orig, Dest: RecEchoMailAddr) : RecEchoMailAddr;

// A41: file-base equivalents for file-echo node linking (same .lnk pattern)
Function  IsFileExportNode         (Var FBase: RecFileBase; Idx: LongInt) : Boolean;
Procedure AddFileExportByBase      (Var FBase: RecFileBase; Idx: LongInt);
Procedure RemoveFileExportFromBase (Var FBase: RecFileBase; Idx: LongInt);

Implementation

Uses
  {$IFDEF UNIX}
    Unix,
  {$ENDIF}
  DOS,
  m_FileIO,
  m_DateTime,
  m_Strings;

Function Addr2Str (Addr : RecEchoMailAddr) : String;
Var
  Temp : String[20];
Begin
  Temp := strI2S(Addr.Zone) + ':' + strI2S(Addr.Net) + '/' +
          strI2S(Addr.Node);

  If Addr.Point <> 0 Then Temp := Temp + '.' + strI2S(Addr.Point);

  Result := Temp;
End;

Function Str2Addr (S: String; Var Addr: RecEchoMailAddr) : Boolean;
Var
  A     : Byte;
  B     : Byte;
  C     : Byte;
  D     : Byte;
  Point : Boolean;
Begin
  Result := False;
  Point  := True;

  D := Pos('@', S);
  A := Pos(':', S);
  B := Pos('/', S);
  C := Pos('.', S);

  If (A = 0) or (B <= A) Then Exit;

  If D > 0 Then
    Delete (S, D, 255);

  If C = 0 Then Begin
    Point      := False;
    C          := Length(S) + 1;
    Addr.Point := 0;
  End;

  Addr.Zone := strS2I(Copy(S, 1, A - 1));
  Addr.Net  := strS2I(Copy(S, A + 1, B - 1 - A));
  Addr.Node := strS2I(Copy(S, B + 1, C - 1 - B));

  If Point Then Addr.Point := strS2I(Copy(S, C + 1, Length(S)));

  Result := True;
End;

Function GetOriginLine (Var mArea: RecMessageBase) : String;
Var
  Loc   : Byte;
  FN    : String;
  TF    : Text;
  Buf   : Array[1..2048] of Char;
  Str   : String;
  Count : LongInt;
  Pick  : LongInt;
Begin
  Result := '';
  Loc    := Pos('@RANDOM=', strUpper(mArea.Origin));

  If Loc > 0 Then Begin
    FN := strStripB(Copy(mArea.Origin, Loc + 8, 255), ' ');

    If Pos(PathChar, FN) = 0 Then FN := bbsCfg.DataPath + FN;

    FileMode := 66;

    Assign     (TF, FN);
    SetTextBuf (TF, Buf, SizeOf(Buf));

    {$I-} Reset (TF); {$I+}

    If IoResult <> 0 Then Exit;

    Count := 0;

    While Not Eof(TF) Do Begin
      ReadLn (TF, Str);

      If strStripB(Str, ' ') = '' Then Continue;

      Inc (Count);
    End;

    If Count = 0 Then Begin
      Close (TF);
      Exit;
    End;

    Pick := Random(Count) + 1;

    Reset (TF);

    Count := 0;

    While Not Eof(TF) Do Begin
      ReadLn (TF, Str);

      If strStripB(Str, ' ') = '' Then Continue;

      Inc (Count);

      If Count = Pick Then Begin
        Result := Str;
        Break;
      End;
    End;

    Close (TF);
  End Else
    Result := mArea.Origin;
End;

Function GetBaseConfiguration (UseEnv: Boolean; Var TempCfg: RecConfig) : Byte;
Var
  TempFile : File;
Begin
  Result     := CfgOK;
  bbsCfgPath := '';

  If Not FileExist('mystic.dat') And UseEnv Then
    If GetENV('mysticbbs') <> '' Then
      bbsCfgPath := DirSlash(GetENV('mysticbbs'));

  Assign (TempFile, bbsCfgPath + 'mystic.dat');

  If ioReset (TempFile, SizeOf(RecConfig), fmRWDN) Then Begin
    ioRead (TempFile, TempCfg);
    Close  (TempFile);

    { Sanitize RIP fields — old mystic.dat won't have these }
    If (TempCfg.RipScreenW = 0) Or (TempCfg.RipScreenW > 4096) Then
      TempCfg.RipScreenW := 640;
    If (TempCfg.RipScreenH = 0) Or (TempCfg.RipScreenH > 4096) Then
      TempCfg.RipScreenH := 350;
  End Else Begin
    Result := CfgNotFound;

    Exit;
  End;

  If TempCfg.DataChanged <> mysDataChanged Then
    Result := CfgMisMatch;
End;

Function PutBaseConfiguration (Var TempCfg: RecConfig) : Boolean;
Var
  TempFile : File;
Begin
  Result := False;

  Assign (TempFile, bbsCfgPath + 'mystic.dat');

  If ioReset (TempFile, SizeOf(RecConfig), fmRWDW) Then Begin
    ioWrite (TempFile, TempCfg);
    Close   (TempFile);

    bbsCfg := TempCfg;
    Result := True;
  End;
End;

Function ExecuteProgram (ExecPath: String; Command: String) : LongInt;
Var
  CurDIR : String;
  Image  : TConsoleImageRec;
Begin
  If Console <> NIL Then
    Console.GetScreenImage(1, 1, 80, 25, Image);

  GetDIR (0, CurDIR);

  If ExecPath <> '' Then DirChange(ExecPath);

  {$IFDEF UNIX}
    {$IF FPC_FULLVERSION >= 30000}
      Result := fpSystem(Command);
    {$ELSE}
      Result := Shell(Command);
    {$IFEND}
  {$ENDIF}

  {$IFDEF WINDOWS}
    If Command <> '' Then Command := '/C' + Command;

    Exec (GetEnv('COMSPEC'), Command);

    Result := DosExitCode;
  {$ENDIF}

  DirChange(CurDIR);

  If Console <> NIL Then
    Console.PutScreenImage(Image);
End;

Function GetMBaseByIndex (Num: LongInt; Var TempBase: RecMessageBase) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'mbases.dat');

  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead (F, TempBase);

    If TempBase.Index = Num Then Begin
      Result := True;

      Break;
    End;
  End;

  Close (F);
End;

Function GetMBaseByQwkID (QwkNet, QwkConf: LongInt; Var TempBase: RecMessageBase) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'mbases.dat');

  If Not ioReset(F, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead (F, TempBase);

    If (TempBase.QwkNetID = QwkNet) and (TempBase.QwkConfID = QwkConf) Then Begin
      Result := True;

      Break;
    End;
  End;

  Close (F);
End;

Function GetQWKNetByIndex (Num: LongInt; Var TempNet: RecQwkNetwork) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'qwknet.dat');

  If Not ioReset(F, SizeOf(RecQwkNetwork), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead (F, TempNet);

    If TempNet.Index = Num Then Begin
      Result := True;

      Break;
    End;
  End;

  Close (F);
End;

Procedure GetMessageScan (UN: Cardinal; TempBase: RecMessageBase; Var TempScan: MScanRec);
Var
  ScanFile : File;
Begin
  TempScan.NewScan := TempBase.DefNScan;
  TempScan.QwkScan := TempBase.DefQScan;

  Assign (ScanFile, TempBase.Path + TempBase.FileName + '.scn');

  If Not ioReset(ScanFile, SizeOf(TempScan), fmRWDN) Then
    Exit;

  If FileSize(ScanFile) >= UN Then Begin
    If ioSeek (ScanFile, UN - 1) Then
      ioRead (ScanFile, TempScan);

    If TempBase.DefNScan = 2 Then TempScan.NewScan := 2;
    If TempBase.DefQScan = 2 Then TempScan.QwkScan := 2;
  End;

  Close (ScanFile);
End;

Procedure PutMessageScan (UN: Cardinal; TempBase: RecMessageBase; TempScan: MScanRec);
Var
  ScanFile : File;
  Count    : Cardinal;
  Temp     : MScanRec;
  FileName : String;
Begin
  Temp.NewScan := TempBase.DefNScan;
  Temp.QwkScan := TempBase.DefQScan;

  FileName     := TempBase.Path + TempBase.FileName + '.scn';

  Assign (ScanFile, FileName);

  If Not ioReset (ScanFile, SizeOf(TempScan), fmRWDW) Then Begin
    If FileExist(FileName) Then Exit;

    If Not ioReWrite(ScanFile, SizeOf(TempScan), fmRWDW) Then Exit;
  End;

  If FileSize(ScanFile) < UN - 1 Then Begin
    ioSeek (ScanFile, FileSize(ScanFile));

    For Count := FileSize(ScanFile) to UN - 1 Do
      ioWrite (ScanFile, Temp);
  End;

  ioSeek  (ScanFile, UN - 1);
  ioWrite (ScanFile, TempScan);
  Close   (ScanFile);
End;

Function MBaseOpenCreate (Var Msg: PMsgBaseABS; Var Area: RecMessageBase; TP: String) : Boolean;
Begin
  Result := False;

  Case Area.BaseType of
    0 : Msg := New(PMsgBaseJAM, Init);
    1 : Msg := New(PMsgBaseSquish, Init);
  End;

  Msg^.SetMsgPath  (Area.Path + Area.FileName);
  Msg^.SetTempFile (TP + 'msgbuf.');

  If Not Msg^.OpenMsgBase Then
    If Not Msg^.CreateMsgBase (Area.MaxMsgs, Area.MaxAge) Then Begin
      Dispose (Msg, Done);

      Exit;
    End Else
    If Not Msg^.OpenMsgBase Then Begin
      Dispose (Msg, Done);

      Exit;
    End;

  Result := True;
End;

Procedure MBaseAssignData (Var User: RecUser; Var Msg: PMsgBaseABS; Var TempBase: RecMessageBase);
Var
  SemFile : Text;
Begin
  Msg^.StartNewMsg;

  If TempBase.Flags And MBRealNames <> 0 Then
    Msg^.SetFrom(User.RealName)
  Else
    Msg^.SetFrom(User.Handle);

  Msg^.SetLocal (True);

  If TempBase.NetType > 0 Then Begin
    If TempBase.NetType = 3 Then
      Msg^.SetMailType(mmtNetMail)
    Else
      Msg^.SetMailType(mmtEchoMail);

    Msg^.SetOrig(bbsCfg.NetAddress[TempBase.NetAddr]);

    Case TempBase.NetType of
      1 : If TempBase.QwkConfID = 0 Then
            Assign (SemFile, bbsCfg.SemaPath + fn_SemFileEchoOut)
          Else
            Assign (SemFile, bbsCfg.SemaPath + fn_SemFileQwk);
      2 : Assign (SemFile, bbsCfg.SemaPath + fn_SemFileNews);
      3 : Assign (SemFile, bbsCfg.SemaPath + fn_SemFileNet);
    End;

    ReWrite (SemFile);
    Close   (SemFile);
  End Else
    Msg^.SetMailType(mmtNormal);

  Msg^.SetPriv (TempBase.Flags and MBPrivate <> 0);
  Msg^.SetDate (DateDos2Str(CurDateDos, 1));
  Msg^.SetTime (TimeDos2Str(CurDateDos, 0));
  Msg^.SetSent (False);
End;

Function GetTotalFiles (Var TempBase: RecFileBase) : LongInt;
Begin
  Result := 0;

  If TempBase.Name = 'None' Then Exit;

  Result := FileByteSize(bbsCfg.DataPath + TempBase.FileName + '.dir');

  If Result > 0 Then
    Result := Result DIV SizeOf(RecFileList);
End;

Function IsThisUser (U: RecUser; Str: String) : Boolean;
Begin
  Str    := strUpper(Str);
  Result := (strUpper(U.RealName) = Str) or (strUpper(U.Handle) = Str);
End;

Procedure ExecuteArchive (TempP: String; FName: String; Temp: String; Mask: String; Mode: Byte);
Var
  ArcFile : File;
  Arc     : RecArchive;
  Count   : LongInt;
  Str     : String;
  Cmd     : String;
  RC      : LongInt;
  Ext     : String;
  Tried   : LongInt;

  // Log an archiver failure so the sysop can see the built-in engine fell back.
  Procedure LogArcError (Const Msg: String);
  Var
    LF : Text;
    Y, Mo, D, DoW : Word;
    H, Mi, S, HS  : Word;
    Stamp : String;
  Begin
    GetDate (Y, Mo, D, DoW);
    GetTime (H, Mi, S, HS);
    Stamp := strZero(Mo) + '/' + strZero(D) + '/' + strI2S(Y) + ' ' +
             strZero(H) + ':' + strZero(Mi) + ':' + strZero(S);

    Assign (LF, bbsCfg.DataPath + 'archive.log');
    {$I-}
    Append (LF);
    If IOResult <> 0 Then Rewrite (LF);
    If IOResult = 0 Then Begin
      WriteLn (LF, Stamp, '  ', Msg);
      Close (LF);
    End;
    {$I+}
  End;

  // Build the command string for Arc/Mode by expanding %1/%2/%3.
  Function BuildCmd (Const A: RecArchive) : String;
  Var S, R: String; C: LongInt;
  Begin
    Case Mode of
      1 : S := A.Pack;
      2 : S := A.Unpack;
    Else
      S := A.View;
    End;

    R := '';
    C := 1;
    While C <= Length(S) Do Begin
      If S[C] = '%' Then Begin
        Inc (C);
        If      S[C] = '1' Then R := R + FName
        Else If S[C] = '2' Then R := R + Mask
        Else If S[C] = '3' Then R := R + TempP;
      End Else
        R := R + S[C];
      Inc (C);
    End;

    BuildCmd := R;
  End;

Begin
  If Temp <> '' Then
    Ext := strUpper(Temp)
  Else
    Ext := strUpper(JustFileExt(FName));

  // Pass 1: prefer the BUILT-IN engine (a marc entry) if one matches.
  // Pass 2: if it is missing or fails, fall through to external tools.
  // We scan the table twice so a working external tool still runs even if the
  // built-in entry errors (e.g. an odd format the RTL zipper can't handle).
  Tried := 0;

  For Count := 1 to 2 Do Begin
    Assign (ArcFile, bbsCfg.DataPath + 'archive.dat');
    If Not ioReset (ArcFile, SizeOf(RecArchive), fmRWDN) Then Exit;

    While Not Eof(ArcFile) Do Begin
      ioRead (ArcFile, Arc);

      If (Not Arc.Active) or ((Arc.OSType <> OSType) and (Arc.OSType <> 3)) Then Continue;
      If strUpper(Arc.Ext) <> Ext Then Continue;

      Cmd := BuildCmd (Arc);
      If Cmd = '' Then Continue;

      // Pass 1 handles ONLY the built-in engine; pass 2 handles the rest.
      If (Count = 1) <> (Pos('MARC', strUpper(Cmd)) > 0) Then Continue;

      Inc (Tried);
      RC := ExecuteProgram ('', Cmd);

      If RC = 0 Then Begin
        Close (ArcFile);
        Exit;                         // success - done
      End;

      // failed - log and let the loop try the next matching entry / pass
      LogArcError ('archive ' + Ext + ' mode ' + strI2S(Mode) +
                   ' failed (rc=' + strI2S(RC) + '): ' + Cmd);
    End;

    Close (ArcFile);
  End;

  If Tried = 0 Then
    LogArcError ('no archiver configured for ' + Ext + ' (mode ' + strI2S(Mode) + ')');
End;

Function IsDuplicateFile (Base: RecFileBase; FileName: String; Global: Boolean) : Boolean;

  Procedure CheckOneArea;
  Var
    TempFile : TFileBuffer;
    Temp     : RecFileList;
  Begin
    TempFile := TFileBuffer.Create(8 * 1024);

    If Not TempFile.OpenStream (bbsCfg.DataPath + Base.FileName + '.dir', SizeOf(RecFileList), fmOpen, fmRWDN) Then Begin
      TempFile.Free;

      Exit;
    End;

    While Not TempFile.EOF Do Begin
      TempFile.ReadRecord(Temp);

      {$IFDEF FS_SENSITIVE}
      If (Temp.FileName = FileName) And (Temp.Flags And FDirDeleted = 0) Then Begin
      {$ELSE}
      If (strUpper(Temp.FileName) = strUpper(FileName)) And (Temp.Flags And FDirDeleted = 0) Then Begin
      {$ENDIF}
        Result := True;

        Break;
      End;
    End;

    TempFile.Free;
  End;

Var
  BaseFile : File;
Begin
  Result := False;

  If Global Then Begin
    Assign (BaseFile, bbsCfg.DataPath + 'fbases.dat');

    If ioReset (BaseFile, SizeOf(RecFileBase), fmRWDN) Then Begin
      While Not EOF(BaseFile) And Not Result Do Begin
        ioRead (BaseFile, Base);

        CheckOneArea;
      End;

      Close (BaseFile);
    End;
  End Else
    CheckOneArea;
End;

Function ImportFileDIZ (Var Desc: FileDescBuffer; Var DescLines: Byte; TempP, FN: String) : Boolean;

  Procedure RemoveLine (Num: Byte);
  Var
    Count : Byte;
  Begin
    For Count := Num To DescLines - 1 Do
      Desc[Count] := Desc[Count + 1];

    Desc[DescLines] := '';

    Dec (DescLines);
  End;

Var
  DizFile : Text;
Begin
  Result    := False;
  DescLines := 0;

  ExecuteArchive (TempP, FN, '', 'file_id.diz', 2);

  Assign (DizFile, FileFind(TempP + 'file_id.diz'));

  {$I-} Reset (DizFile); {$I+}

  If IoResult = 0 Then Begin
    While Not Eof(DizFile) Do Begin
      Inc    (DescLines);
      ReadLn (DizFile, Desc[DescLines]);

      Desc[DescLines] := strStripLow(Desc[DescLines]);

      If DescLines = bbsCfg.MaxFileDesc Then Break;
    End;

    Close (DizFile);
    Erase (DizFile);

    While (Desc[1] = '') and (DescLines > 0) Do
      RemoveLine(1);

    While (Desc[DescLines] = '') And (DescLines > 0) Do
      Dec (DescLines);

    Result := True;
  End;
End;

Function GetNodeByAddress (Addr: String; Var TempNode: RecEchoMailNode) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'echonode.dat');

  If Not ioReset(F, SizeOf(RecEchoMailNode), fmRWDN) Then Exit;

  While Not Eof(F) And Not Result Do Begin
    ioRead(F, TempNode);

    Result := Addr2Str(TempNode.Address) = Addr;
  End;

  Close (F);
End;

Function GetFTNBundleExt (IncOnly: Boolean; Str: String) : String;
Var
  FN    : String;
  Ext   : String;
  Last  : Byte;
  First : Byte;
Begin
  FN  := JustFileName(Str);
  Ext := strLower(JustFileExt(Str));

  Last := Byte(Ext[Length(Ext)]);

  If Not (Last in [48..57, 97..122]) Then Last := 48;

  First := Last;

  Repeat
    Result := FN + '.' + Ext;
    Result[Length(Result)] := Char(Last);

    If IncOnly Then Begin
      If First <> Last Then
        Break;
    End Else
      If Not FileExist(Result) Then Break;

    Inc (Last);

    If Last = 58  Then Last := 97;
    If Last = 123 Then Last := 48; // loop

    If First = Last Then Begin
      Result[Length(Result)] := Char(123);
      Break;
    End;
  Until False;
End;

Function SaveEchoMailNode (Var TempNode: RecEchoMailNode) : Boolean;
Var
  F  : File;
  TN : RecEchoMailNode;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'echonode.dat');

  If Not ioReset(F, SizeOf(RecEchoMailNode), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead(F, TN);

    If TempNode.Index = TN.Index Then Begin
      Seek    (F, FilePos(F) - 1);
      ioWrite (F, TempNode);

      Result := True;

      Break;
    End;
  End;

  Close (F);
End;

(*
Function GetFTNPKTName : String;
Var
  Hour, Min, Sec, hSec  : Word;
  Year, Month, Day, DOW : Word;
Begin
  GetTime (Hour, Min, Sec, hSec);
  GetDate (Year, Month, Day, DOW);

  Result := strZero(Day) + strZero(Hour) + strZero(Min) + strZero(Sec);
End;
*)

Function GetFTNPKTName : String;
Var
  Hour, Min, Sec, hSec  : Word;
  Year, Month, Day, DOW : Word;
  SecsPast : Cardinal;
Begin

  // PKT filename format used by Mystic:
  // 2 digit day of month + seconds past midnight + hundredths of second
  //
  // This gives a max possible value of 318640099 and will create unique
  // packet names for up to one month accurate to the hundredth of a second.
  // A 1/100th second delay when generating the name guarentees uniqueness.
  //
  // This value is then converted to hex to enforce a maximum of 8 characters.

  WaitMS  (10);
  GetDate (Year, Month, Day, DOW);
  GetTime (Hour, Min, Sec, hSec);

  SecsPast := ((Hour * 60) * 60) + (Min * 60) + Sec;
  Result   := strI2H(strS2I(strZero(Day) + strPadL(strI2S(SecsPast), 5, '0') + strZero(hSec)), 8);
End;

Function GetNodeByIndex (Num: LongInt; Var TempNode: RecEchoMailNode) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'echonode.dat');

  If Not ioReset(F, SizeOf(RecEchoMailNode), fmRWDN) Then Exit;

  While Not Eof(F) Do Begin
    ioRead(F, TempNode);

    If TempNode.Index = Num Then Begin
      Result := True;

      Break;
    End;
  End;

  Close (F);
End;


// ====================================================================
// A39: FTN routing + echomail export management (FidoNet pass import).
// GetNodeByRoute routes to the right uplink by dest address; the Export*
// set manages per-base export .lnk lists; GetMatchedAddress relocated
// here from bbs_msgbase (its natural home, next to routing).
// ====================================================================

Function GetUserByRec (Num: LongInt; Var U: RecUser) : Boolean;
Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'users.dat');
  If Not ioReset(F, SizeOf(RecUser), fmRWDN) Then Exit;

  If ioSeek(F, Pred(Num)) And (ioRead(F, U)) Then
    Result := True;

  Close (F);
End;

Function IsExportNode (Var MBase: RecMessageBase; Idx: LongInt) : Boolean;
Var
  ExpFile : File of RecEchoMailExport;
  ExpNode : RecEchoMailExport;
Begin
  Result := False;

  Assign (ExpFile, MBase.Path + MBase.FileName + '.lnk');

  If Not ioReset (ExpFile, SizeOf(RecEchoMailExport), fmRWDN) Then Exit;

  While Not Eof(ExpFile) Do Begin
    Read (ExpFile, ExpNode);

    If ExpNode = Idx Then Begin
      Result := True;

      Break;
    End;
  End;

  Close (ExpFile);
End;

Procedure AddExportByBase (Var MBase: RecMessageBase; Idx: LongInt);
Var
  ExpFile : File of RecEchoMailExport;
Begin
  If IsExportNode (MBase, Idx) Then Exit;

  Assign (ExpFile, MBase.Path + MBase.FileName + '.lnk');

  If Not ioReset (ExpFile, SizeOf(RecEchoMailExport), fmRWDN) Then
    If Not ioReWrite (ExpFile, SizeOf(RecEchoMailExport), fmRWDN) Then
      Exit;

  Seek  (ExpFile, FileSize(ExpFile));
  Write (ExpFile, Idx);
  Close (ExpFile);
End;

Procedure RemoveExportFromBase (Var MBase: RecMessageBase; Idx: LongInt);
Var
  ExpFile : File of RecEchoMailExport;
  ExpNode : RecEchoMailExport;
Begin
  Assign (ExpFile, MBase.Path + MBase.FileName + '.lnk');

  If Not ioReset (ExpFile, SizeOf(RecEchoMailExport), fmRWDN) Then Exit;

  While Not Eof(ExpFile) Do Begin
    Read (ExpFile, ExpNode);

    If ExpNode = Idx Then
      KillRecord (ExpFile, FilePos(ExpFile), SizeOf(RecEchoMailExport));
  End;

  Close (ExpFile);
End;

// A41: file-base equivalents for file-echo node linking.  Identical logic to the
// message-base versions, but using FBase.Path + FBase.FileName for the .lnk path.

Function IsFileExportNode (Var FBase: RecFileBase; Idx: LongInt) : Boolean;
Var
  ExpFile : File of RecEchoMailExport;
  ExpNode : RecEchoMailExport;
Begin
  Result := False;
  Assign (ExpFile, FBase.Path + FBase.FileName + '.lnk');
  If Not ioReset (ExpFile, SizeOf(RecEchoMailExport), fmRWDN) Then Exit;
  While Not Eof(ExpFile) Do Begin
    Read (ExpFile, ExpNode);
    If ExpNode = Idx Then Begin Result := True; Break; End;
  End;
  Close (ExpFile);
End;

Procedure AddFileExportByBase (Var FBase: RecFileBase; Idx: LongInt);
Var
  ExpFile : File of RecEchoMailExport;
Begin
  If IsFileExportNode (FBase, Idx) Then Exit;
  Assign (ExpFile, FBase.Path + FBase.FileName + '.lnk');
  If Not ioReset (ExpFile, SizeOf(RecEchoMailExport), fmRWDN) Then
    If Not ioReWrite (ExpFile, SizeOf(RecEchoMailExport), fmRWDN) Then Exit;
  Seek  (ExpFile, FileSize(ExpFile));
  Write (ExpFile, Idx);
  Close (ExpFile);
End;

Procedure RemoveFileExportFromBase (Var FBase: RecFileBase; Idx: LongInt);
Var
  ExpFile : File of RecEchoMailExport;
  ExpNode : RecEchoMailExport;
Begin
  Assign (ExpFile, FBase.Path + FBase.FileName + '.lnk');
  If Not ioReset (ExpFile, SizeOf(RecEchoMailExport), fmRWDN) Then Exit;
  While Not Eof(ExpFile) Do Begin
    Read (ExpFile, ExpNode);
    If ExpNode = Idx Then
      KillRecord (ExpFile, FilePos(ExpFile), SizeOf(RecEchoMailExport));
  End;
  Close (ExpFile);
End;

Procedure RemoveExportGlobal (Idx: LongInt);
Var
  MBaseFile : File of RecMessageBase;
  MBase     : RecMessageBase;
Begin
  Assign (MBaseFile, bbsCfg.DataPath + 'mbases.dat');

  If Not ioReset(MBaseFile, SizeOf(RecMessageBase), fmRWDN) Then Exit;

  While Not Eof(MBaseFile) Do Begin
    Read (MBaseFile, MBase);

    RemoveExportFromBase(MBase, Idx);
  End;

  Close (MBaseFile);
End;

Function GetMatchedAddress (Orig, Dest: RecEchoMailAddr) : RecEchoMailAddr;
Var
  Count : Byte;
Begin
  Result := Orig;

  If Orig.Zone = Dest.Zone Then Exit;

  For Count := 1 to 30 Do
    If bbsCfg.NetAddress[Count].Zone = Dest.Zone Then Begin
      Result := bbsCfg.NetAddress[Count];

      Exit;
    End;
End;

Function GetNodeByRoute (Dest: RecEchoMailAddr; Var TempNode: RecEchoMailNode) : Boolean;

  Function IsMatch (Str: String) : Boolean;

    Function IsOneMatch (Mask: String) : Boolean;
    Var
      Zone  : String;
      Net   : String;
      Node  : String;
      Point : String;
      A     : Byte;
      B     : Byte;
      C     : Byte;
    Begin
      Result := False;
      Zone   := '';
      Net    := '';
      Node   := '';
      Point  := '';
      A      := Pos(':', Mask);
      B      := Pos('/', Mask);
      C      := Pos('.', Mask);

      If A <> 0 Then Begin
        Zone := Copy(Mask, 1, A - 1);

        If B = 0 Then B := 255;
        If C = 0 Then C := 255;

        Net   := Copy(Mask, A + 1, B - 1 - A);
        Node  := Copy(Mask, B + 1, C - 1 - B);
        Point := Copy(Mask, C + 1, 255);
      End;

      If Zone  = '' Then Zone  := '*';
      If Net   = '' Then Net   := '*';
      If Node  = '' Then Node  := '*';
      If Point = '' Then Point := '*';

      If (Zone <> '*')  and (Dest.Zone  <> strS2I(Zone))  Then Exit;
      If (Net  <> '*')  and (Dest.Net   <> strS2I(Net))   Then Exit;
      If (Node <> '*')  and (Dest.Node  <> strS2I(Node))  Then Exit;
      If (Point <> '*') and (Dest.Point <> strS2I(Point)) Then Exit;

      Result := True;
    End;

  Var
    Mask   : String = '';
    OneRes : Boolean;

    Procedure GetNextAddress;
    Begin
      If Pos('!', Str) > 0 Then Begin
        Mask := Copy(Str, 1, Pos('!', Str) - 1);

        Delete (Str, 1, Pos('!', Str) - 1);
      End Else
      If Pos(' ', Str) > 0 Then Begin
        Mask := Copy(Str, 1, Pos(' ', Str) - 1);

        Delete (Str, 1, Pos(' ', Str));
      End Else Begin
        Mask := Str;
        Str  := '';
      End;
    End;

  Begin
    Result := False;
    Str    := strStripB(Str, ' ');

    If Str = '' Then Exit;

    Repeat
      GetNextAddress;

      If Mask = '' Then Break;

      OneRes := IsOneMatch(Mask);

      While (Str[1] = '!') and (Mask <> '') Do Begin
        Delete (Str, 1, 1);

        GetNextAddress;

        OneRes := OneRes AND (NOT IsOneMatch(Mask));
      End;

      Result := Result OR OneRes;
    Until Str = '';
  End;

Var
  F : File;
Begin
  Result := False;

  Assign (F, bbsCfg.DataPath + 'echonode.dat');

  If Not ioReset(F, SizeOf(RecEchoMailNode), fmRWDN) Then Exit;

  // A40 stage 1: compare the destination address against ALL configured
  // echomail nodes.  If a node's own address is a direct match, route to that
  // node WITHOUT reviewing Route Info.
  While Not Eof(F) And Not Result Do Begin
    ioRead(F, TempNode);

    Result := (TempNode.Address.Zone = Dest.Zone) and
              (TempNode.Address.Net  = Dest.Net)  and
              (TempNode.Address.Node = Dest.Node);
  End;

  // A40 stage 2: no direct match - walk each node's Route Info (from the first
  // entry) until one matches, and redirect netmail through that system.
  If Not Result Then Begin
    Seek (F, 0);

    While Not Eof(F) And Not Result Do Begin
      ioRead(F, TempNode);

      Result := IsMatch(TempNode.RouteInfo);
    End;
  End;

  Close (F);
End;

Initialization

  bbsCfgStatus := GetBaseConfiguration(True, bbsCfg);
  Console      := NIL;
  Keyboard     := NIL;

Finalization

  If Assigned(Console)  Then Console.Free;
  If Assigned(Keyboard) Then Keyboard.Free;

End.

//
// This file is part of the Mystic BBS IRC Fork.
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
Unit m_LogRoller;

{$I M_OPS.PAS}

Interface

Uses
  m_FileIO,
  m_Strings,
  m_DateTime;

Const
  CRLF     = {$IFDEF WINDOWS} #13#10; {$ENDIF}
             {$IFDEF UNIX}    #10;    {$ENDIF}
             {$IFDEF OS2}     #13#10; {$ENDIF}
  logNormal = 1;
  logStart  = 2;
  logBlank  = 3;

Type
  TLogRoller = Class
    PreFix    : String;
    LogFile   : TFileBuffer;
    BufSize   : LongInt;
    MaxSize   : LongInt;
    MaxLogs   : Byte;
    CurLevel  : Byte;
    Suffix    : String[20];
    FormatStr : String[20];

    Constructor Create (FN: String; Max: LongInt; ML, Level: Byte);
    Destructor  Destroy; Override;
    Procedure   Add (LogType, LogLevel: Byte; LogChar: Char; LogStr: String);
  End;

Implementation

Constructor TLogRoller.Create (FN: String; Max: LongInt; ML, Level: Byte);
Begin
  Inherited Create;

  MaxSize   := Max * 1024;
  MaxLogs   := ML;
  BufSize   := 8 * 1024;
  CurLevel  := Level;
  PreFix    := JustFileName(FN);
  Suffix    := '.' + JustFileExt(FN);
  FormatStr := 'NNN DD HH:II:SS';

  LogFile := TFileBuffer.Create(BufSize);

  LogFile.OpenStream (PreFix + '.1' + Suffix, 1, fmOpenAppend, 66);
End;

Destructor TLogRoller.Destroy;
Begin
  LogFile.Free;

  Inherited Destroy;
End;

Procedure TLogRoller.Add (LogType, LogLevel: Byte; LogChar: Char; LogStr: String);
Var
  Count : Byte;
Begin
  If CurLevel < LogLevel Then Exit;

  If (MaxSize > 0) And (System.FileSize(LogFile.InFile) + LogFile.BufPos > MaxSize) Then Begin
    LogFile.CloseStream;

    FileErase (PreFix + '.' + strI2S(MaxLogs) + Suffix);

    For Count := MaxLogs - 1 DownTo 1 Do
      FileReName (PreFix + '.' + strI2S(Count) + Suffix, PreFix + '.' + strI2S(Count + 1) + Suffix);

    LogFile.OpenStream (PreFix + '.1' + Suffix, 1, fmOpenAppend, 66);
  End;

  Case LogType of
    logStart  : LogStr := strRep('-', Length(FormatStr) + 2) + '  ' + LogStr + ' ' + FormatDate(CurDateDT, 'DDD, NNN DD YYYY') + CRLF;
    logNormal : LogStr := LogChar + ' ' + FormatDate(CurDateDT, FormatStr) + '  ' + LogStr + CRLF;
    logBlank  : LogStr := CRLF;
  End;

  LogFile.WriteBlock (LogStr[1], Length(LogStr));
End;

End.

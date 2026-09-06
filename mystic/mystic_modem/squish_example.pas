{
  This file is part of the Mystic BBS IRC Fork.

  Copyright (C) 2026 Mystic BBS IRC Fork Contributors

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.
}
{ squish_example - standalone Squish message base reader
  Reads a Squish .sqd file and dumps message headers.
  Usage: squish_example <basepath>
  e.g. squish_example C:\FTN\NETMAIL }

Program squish_example;

{$IFDEF FPC}{$MODE OBJFPC}{$ENDIF}

Uses DOS;

Type
  SqFrameHdrType = Packed Record
    Id, NextFrame, PrevFrame, FrameLen, MsgLen, CtlLen: LongInt;
    FrameType, Rsvd: Word;
  End;

  SqMsgHdrType = Packed Record
    Attr: LongInt;
    MsgFrom: Array[0..35] of Char;
    MsgTo: Array[0..35] of Char;
    Subj: Array[0..71] of Char;
    OrigZone, OrigNet, OrigNode, OrigPoint: Word;
    DestZone, DestNet, DestNode, DestPoint: Word;
    DateWritten, DateArrived: LongInt;
    UtcOfs: Word;
    ReplyTo: LongInt;
    Replies: Array[0..9] of LongInt;
    UmsgId: LongInt;
    FtscDate: Array[0..19] of Char;
  End;

Var
  SqdFile: File;
  Frame: SqFrameHdrType;
  Msg: SqMsgHdrType;
  CurPos, NumMsg, BeginFrame: LongInt;
  Count: LongInt;
  BytesRead: LongInt;
  BaseHdr: Array[0..255] of Byte;

Function PCharToStr(Var P; MaxLen: Integer): String;
Var A: Array[0..255] of Char Absolute P; I: Integer;
Begin
  PCharToStr := '';
  For I := 0 to MaxLen - 1 Do Begin
    If A[I] = #0 Then Break;
    PCharToStr := PCharToStr + A[I];
  End;
End;

Begin
  If ParamCount < 1 Then Begin
    WriteLn('Usage: squish_example <basepath>'); Halt(1);
  End;

  WriteLn('Squish Reader - ', ParamStr(1));
  Assign(SqdFile, ParamStr(1) + '.sqd');
  {$I-} Reset(SqdFile, 1); {$I+}
  If IOResult <> 0 Then Begin WriteLn('Cannot open .sqd'); Halt(2); End;

  BlockRead(SqdFile, BaseHdr, 256, BytesRead);
  Move(BaseHdr[4], NumMsg, 4);
  Move(BaseHdr[20], BeginFrame, 4);
  WriteLn('Messages: ', NumMsg);

  CurPos := BeginFrame; Count := 0;
  While CurPos <> 0 Do Begin
    Seek(SqdFile, CurPos);
    BlockRead(SqdFile, Frame, SizeOf(Frame), BytesRead);
    If BytesRead < SizeOf(Frame) Then Break;
    If Frame.Id <> LongInt($AFAE4453) Then Begin WriteLn('Bad frame'); Break; End;
    If Frame.FrameType = 0 Then Begin
      BlockRead(SqdFile, Msg, SizeOf(Msg), BytesRead);
      If BytesRead >= SizeOf(Msg) Then Begin
        Inc(Count);
        WriteLn('--- #', Count, ' (UID ', Msg.UmsgId, ') ---');
        WriteLn('  From: ', PCharToStr(Msg.MsgFrom, 36));
        WriteLn('  To:   ', PCharToStr(Msg.MsgTo, 36));
        WriteLn('  Subj: ', PCharToStr(Msg.Subj, 72));
      End;
    End;
    CurPos := Frame.NextFrame;
  End;

  WriteLn('Total: ', Count);
  Close(SqdFile);
End.

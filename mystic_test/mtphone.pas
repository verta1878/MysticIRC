{ This file is part of mterm — Mystic Terminal.
  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench. }
{$H+}
Unit mtphone;
{ Phonebook — saved BBS connections.
  MDL Console/Keyboard UI (replaces Free Vision dialog). }

Interface

Const
  MaxEntries = 100;

Type
  TPhoneEntry = Record
    Name     : String[40];
    Host     : String[60];
    Port     : Word;
    ConnType : Byte;     { 0=telnet, 1=serial, 2=fossil }
    Baud     : LongInt;
    ComPort  : Byte;
    TermType : Byte;     { 0=ANSI, 1=RIP }
    InitStr  : String[40];
  End;

  TPhonebook = Record
    Count   : Integer;
    Entries : Array[0..MaxEntries - 1] of TPhoneEntry;
  End;

Procedure LoadPhonebook  (Var PB: TPhonebook);
Procedure SavePhonebook  (Const PB: TPhonebook);

{ Returns selected entry index, or -1 if cancelled }
Function  ShowPhonebook  (Var PB: TPhonebook;
             Console: TObject; Keyboard: TObject): Integer;

Implementation

Uses SysUtils, m_Strings,
  {$IFDEF WINDOWS}
    m_Output_Windows, m_Input_Windows;
  {$ENDIF}
  {$IFDEF UNIX}
    m_Output_Linux, m_Input_Linux;
  {$ENDIF}

Const
  PhoneFile = 'mterm.phn';

  { Dialog dimensions }
  DX = 5;  DY = 3;  DW = 70;  DH = 19;

Procedure LoadPhonebook(Var PB: TPhonebook);
Var F: File of TPhonebook;
Begin
  FillChar(PB, SizeOf(PB), 0);
  If Not FileExists(PhoneFile) Then Begin
    { Default entries }
    PB.Count := 2;

    PB.Entries[0].Name     := 'Cosmo Castle (RIP)';
    PB.Entries[0].Host     := 'fluph.zapto.org';
    PB.Entries[0].Port     := 3143;
    PB.Entries[0].ConnType := 0;
    PB.Entries[0].TermType := 1;

    PB.Entries[1].Name     := 'Fluph BBS (ANSI)';
    PB.Entries[1].Host     := 'fluph.zapto.org';
    PB.Entries[1].Port     := 23;
    PB.Entries[1].ConnType := 0;
    PB.Entries[1].TermType := 0;

    SavePhonebook(PB);
  End;
  If FileExists(PhoneFile) Then Begin
    Assign(F, PhoneFile);
    {$I-} Reset(F); {$I+}
    If IOResult = 0 Then Begin
      Read(F, PB);
      Close(F);
    End;
  End;
End;

Procedure SavePhonebook(Const PB: TPhonebook);
Var F: File of TPhonebook;
Begin
  Assign(F, PhoneFile);
  {$I-} Rewrite(F); {$I+}
  If IOResult = 0 Then Begin
    Write(F, PB);
    Close(F);
  End;
End;

Procedure EditEntry(Var E: TPhoneEntry;
            Console: TObject; Keyboard: TObject);
Var
  Con: {$IFDEF WINDOWS} TOutputWindows {$ELSE} TOutputLinux {$ENDIF};
  Key: {$IFDEF WINDOWS} TInputWindows {$ELSE} TInputLinux {$ENDIF};
  Field    : Integer;
  Done     : Boolean;
  Ch       : Char;
  S        : String;
  EX, EY, EW, EH: Integer;
  Row      : Integer;
  TmpNum   : LongInt;

  Procedure DrawField(Row: Integer; Lab: String; Val: String; Sel: Boolean);
  Var Attr: Byte;
  Begin
    If Sel Then Attr := $70 Else Attr := $1F;
    Con.WriteXY(EX + 2, EY + 2 + Row, $1E, StrPadR(Lab, 12, ' '));
    Con.WriteXY(EX + 14, EY + 2 + Row, Attr, StrPadR(Val, EW - 18, ' '));
  End;

  Function EditField(Var Val: String; MaxLen: Integer): Boolean;
  Var
    Buf: String;
    FCh: Char;
    FDone: Boolean;
  Begin
    Result := False;
    Buf := Val;
    FDone := False;
    Repeat
      Con.WriteXY(EX + 14, EY + 2 + Field, $4F, StrPadR(Buf + '_', EW - 18, ' '));
      Con.BufFlush;
      FCh := Key.ReadKey;
      Case FCh of
        #13: Begin Val := Buf; Result := True; FDone := True; End;
        #27: FDone := True;
        #8:  If Length(Buf) > 0 Then Delete(Buf, Length(Buf), 1);
      Else
        If (FCh >= ' ') And (Length(Buf) < MaxLen) Then
          Buf := Buf + FCh;
      End;
    Until FDone;
  End;

  Function EditNumField(Var Val: LongInt; MaxLen: Integer; Lo, Hi: LongInt): Boolean;
  Var
    Buf: String;
    FCh: Char;
    FDone: Boolean;
    N: LongInt;
  Begin
    Result := False;
    Buf := strI2S(Val);
    FDone := False;
    Repeat
      Con.WriteXY(EX + 14, EY + 2 + Field, $4F, StrPadR(Buf + '_', EW - 18, ' '));
      Con.BufFlush;
      FCh := Key.ReadKey;
      Case FCh of
        #13: Begin
          N := strS2I(Buf);
          If (N >= Lo) And (N <= Hi) Then Begin
            Val := N; Result := True;
          End;
          FDone := True;
        End;
        #27: FDone := True;
        #8:  If Length(Buf) > 0 Then Delete(Buf, Length(Buf), 1);
        '0'..'9':
          If Length(Buf) < MaxLen Then Buf := Buf + FCh;
      End;
    Until FDone;
  End;

Begin
  Con := {$IFDEF WINDOWS} TOutputWindows(Console) {$ELSE} TOutputLinux(Console) {$ENDIF};
  Key := {$IFDEF WINDOWS} TInputWindows(Keyboard) {$ELSE} TInputLinux(Keyboard) {$ENDIF};

  EX := 10; EY := 5; EW := 60; EH := 12;
  Field := 0;
  Done := False;

  Repeat
    { Frame }
    Con.WriteXY(EX, EY, $1F, #218 + StrPadR(#196 + ' Edit Entry ' + #196, EW - 2, #196) + #191);
    For Row := 1 to EH - 2 Do
      Con.WriteXY(EX, EY + Row, $1F, #179 + StrRep(' ', EW - 2) + #179);
    Con.WriteXY(EX, EY + EH - 1, $1F, #192 + StrRep(#196, EW - 2) + #217);

    { Fields }
    DrawField(0, 'Name:', E.Name, Field = 0);
    DrawField(1, 'Host:', E.Host, Field = 1);
    DrawField(2, 'Port:', strI2S(E.Port), Field = 2);
    Case E.ConnType of
      0: S := 'Telnet';
      1: S := 'Serial';
      2: S := 'FOSSIL';
    Else S := '?';
    End;
    DrawField(3, 'Type:', S, Field = 3);
    Case E.TermType of
      0: S := 'ANSI';
      1: S := 'RIP';
    Else S := '?';
    End;
    DrawField(4, 'Terminal:', S, Field = 4);
    DrawField(5, 'Baud:', strI2S(E.Baud), Field = 5);
    DrawField(6, 'COM Port:', strI2S(E.ComPort), Field = 6);
    DrawField(7, 'Init Str:', E.InitStr, Field = 7);

    Con.WriteXY(EX + 2, EY + EH - 2, $1E,
      StrPadR(' Up/Down=Move  ENTER=Edit  T=Type  M=Term  ESC=Done', EW - 4, ' '));
    Con.BufFlush;

    Ch := Key.ReadKey;
    Case Ch of
      #0: Begin
        Ch := Key.ReadKey;
        Case Ch of
          #72: If Field > 0 Then Dec(Field);       { Up }
          #80: If Field < 7 Then Inc(Field);       { Down }
        End;
      End;
      #13: Begin { Edit current field }
        Case Field of
          0: Begin S := E.Name;     If EditField(S, 40) Then E.Name := S; End;
          1: Begin S := E.Host;     If EditField(S, 60) Then E.Host := S; End;
          2: Begin TmpNum := E.Port; If EditNumField(TmpNum, 5, 1, 65535) Then E.Port := TmpNum; End;
          3: E.ConnType := (E.ConnType + 1) Mod 3;   { cycle type }
          4: E.TermType := (E.TermType + 1) Mod 2;   { cycle terminal }
          5: Begin TmpNum := E.Baud; If EditNumField(TmpNum, 6, 0, 921600) Then E.Baud := TmpNum; End;
          6: Begin TmpNum := E.ComPort; If EditNumField(TmpNum, 1, 0, 9) Then E.ComPort := TmpNum; End;
          7: Begin S := E.InitStr;  If EditField(S, 40) Then E.InitStr := S; End;
        End;
      End;
      'T', 't': Begin { Toggle connection type }
        E.ConnType := (E.ConnType + 1) Mod 3;
      End;
      'M', 'm': Begin { Toggle terminal type }
        E.TermType := (E.TermType + 1) Mod 2;
      End;
      #27: Done := True;
    End;
  Until Done;
End;

Function ShowPhonebook(Var PB: TPhonebook;
            Console: TObject; Keyboard: TObject): Integer;
Var
  Con: {$IFDEF WINDOWS} TOutputWindows {$ELSE} TOutputLinux {$ENDIF};
  Key: {$IFDEF WINDOWS} TInputWindows {$ELSE} TInputLinux {$ENDIF};
  Selected : Integer;
  TopIdx   : Integer;
  MaxShow  : Integer;
  Done     : Boolean;
  Ch       : Char;
  I, Y     : Integer;
  S        : String;
  TypeStr  : String[6];
Begin
  Con := {$IFDEF WINDOWS} TOutputWindows(Console) {$ELSE} TOutputLinux(Console) {$ENDIF};
  Key := {$IFDEF WINDOWS} TInputWindows(Keyboard) {$ELSE} TInputLinux(Keyboard) {$ENDIF};

  Result   := -1;
  Selected := 0;
  TopIdx   := 0;
  MaxShow  := DH - 6;  { visible rows for entries }
  Done     := False;

  Repeat
    { Draw frame }
    Con.WriteXY(DX, DY, $1F, #218 + StrPadR(#196 + ' Phonebook ' + #196, DW - 2, #196) + #191);
    For Y := 1 to DH - 2 Do
      Con.WriteXY(DX, DY + Y, $1F, #179 + StrRep(' ', DW - 2) + #179);
    Con.WriteXY(DX, DY + DH - 1, $1F, #192 + StrRep(#196, DW - 2) + #217);

    { Column headers }
    Con.WriteXY(DX + 2, DY + 1, $1E, StrPadR(' #  Name                       Host                    Port Type', DW - 4, ' '));
    Con.WriteXY(DX + 2, DY + 2, $1F, StrRep(#196, DW - 4));

    { Entries }
    For I := 0 to MaxShow - 1 Do Begin
      Y := DY + 3 + I;
      If (TopIdx + I) < PB.Count Then Begin
        Case PB.Entries[TopIdx + I].TermType of
          0: TypeStr := 'ANSI';
          1: TypeStr := 'RIP';
        Else TypeStr := '?';
        End;
        S := ' ' + StrPadR(strI2S(TopIdx + I + 1), 3, ' ') +
             StrPadR(PB.Entries[TopIdx + I].Name, 27, ' ') +
             StrPadR(PB.Entries[TopIdx + I].Host, 24, ' ') +
             StrPadR(strI2S(PB.Entries[TopIdx + I].Port), 5, ' ') +
             TypeStr;
        S := StrPadR(S, DW - 4, ' ');
        If (TopIdx + I) = Selected Then
          Con.WriteXY(DX + 2, Y, $70, S)  { highlighted }
        Else
          Con.WriteXY(DX + 2, Y, $1F, S);
      End Else
        Con.WriteXY(DX + 2, Y, $1F, StrRep(' ', DW - 4));
    End;

    { Bottom help }
    Con.WriteXY(DX + 2, DY + DH - 3, $1F, StrRep(#196, DW - 4));
    Con.WriteXY(DX + 2, DY + DH - 2, $1E,
      StrPadR(' ENTER=Connect  A=Add  D=Delete  E=Edit  ESC=Cancel', DW - 4, ' '));

    Con.BufFlush;

    { Input }
    Ch := Key.ReadKey;
    Case Ch of
      #0: Begin
        Ch := Key.ReadKey;
        Case Ch of
          #72: Begin { Up }
            If Selected > 0 Then Dec(Selected);
            If Selected < TopIdx Then TopIdx := Selected;
          End;
          #80: Begin { Down }
            If Selected < PB.Count - 1 Then Inc(Selected);
            If Selected >= TopIdx + MaxShow Then TopIdx := Selected - MaxShow + 1;
          End;
          #71: Begin { Home }
            Selected := 0; TopIdx := 0;
          End;
          #79: Begin { End }
            If PB.Count > 0 Then Selected := PB.Count - 1;
            If Selected >= MaxShow Then TopIdx := Selected - MaxShow + 1;
          End;
        End;
      End;
      #13: Begin { Enter = Connect }
        If PB.Count > 0 Then Begin
          Result := Selected;
          Done := True;
        End;
      End;
      #27: Done := True;  { ESC = Cancel }
      'A', 'a': Begin { Add entry }
        If PB.Count < MaxEntries Then Begin
          PB.Entries[PB.Count].Name     := 'New BBS';
          PB.Entries[PB.Count].Host     := '';
          PB.Entries[PB.Count].Port     := 23;
          PB.Entries[PB.Count].ConnType := 0;
          PB.Entries[PB.Count].TermType := 0;
          PB.Entries[PB.Count].Baud     := 0;
          PB.Entries[PB.Count].ComPort  := 0;
          PB.Entries[PB.Count].InitStr  := '';
          Selected := PB.Count;
          Inc(PB.Count);
          EditEntry(PB.Entries[Selected], Console, Keyboard);
          SavePhonebook(PB);
        End;
      End;
      'D', 'd': Begin { Delete entry }
        If (PB.Count > 0) and (Selected < PB.Count) Then Begin
          For I := Selected to PB.Count - 2 Do
            PB.Entries[I] := PB.Entries[I + 1];
          Dec(PB.Count);
          If Selected >= PB.Count Then
            Selected := PB.Count - 1;
          If Selected < 0 Then Selected := 0;
          SavePhonebook(PB);
        End;
      End;
      'E', 'e': Begin { Edit entry }
        If (PB.Count > 0) And (Selected < PB.Count) Then Begin
          EditEntry(PB.Entries[Selected], Console, Keyboard);
          SavePhonebook(PB);
        End;
      End;
    End;
  Until Done;
End;

End.

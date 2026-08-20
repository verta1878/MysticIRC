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
          SavePhonebook(PB);
          { TODO: open edit dialog for new entry }
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
        { TODO: edit dialog for selected entry }
      End;
    End;
  Until Done;
End;

End.

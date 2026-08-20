{ This file is part of mterm — Mystic Terminal.
  Copyright (C) 2026 FPC264IRC Contributors.
  License: GNU General Public License v3.0.
  Credits: verta1878, sysop/0, evga, kiddo, wrench. }
{$MODE OBJFPC}
{$H+}
unit mtphone;
{ Phonebook — saved BBS connections }

interface

uses App, Objects, Drivers, Views, Menus, Dialogs, MsgBox,
     mtterm, mtconn;

const
  MaxEntries = 100;

type
  TPhoneEntry = record
    Name: String[40];
    Host: String[60];
    Port: Word;
    ConnType: Byte;   { 0=telnet, 1=serial, 2=fossil }
    Baud: LongInt;
    ComPort: Byte;
    TermType: Byte;   { 0=ANSI, 1=RIP }
    InitStr: String[40];
  end;

  TPhonebook = record
    Count: Integer;
    Entries: array[0..MaxEntries - 1] of TPhoneEntry;
  end;

procedure ShowPhonebook(Conn: TConnection; Term: PTermView);
procedure LoadPhonebook(var PB: TPhonebook);
procedure SavePhonebook(const PB: TPhonebook);

implementation

uses SysUtils;

const
  PhoneFile = 'mterm.phn';

procedure LoadPhonebook(var PB: TPhonebook);
var F: File of TPhonebook;
begin
  FillChar(PB, SizeOf(PB), 0);
  if not FileExists(PhoneFile) then begin
    { Create default phonebook with test BBSes }
    PB.Count := 2;

    PB.Entries[0].Name := 'Cosmo Castle (RIP)';
    PB.Entries[0].Host := 'fluph.zapto.org';
    PB.Entries[0].Port := 3143;
    PB.Entries[0].ConnType := 0;
    PB.Entries[0].TermType := 1;  { RIP }

    PB.Entries[1].Name := 'Fluph BBS (ANSI)';
    PB.Entries[1].Host := 'fluph.zapto.org';
    PB.Entries[1].Port := 23;
    PB.Entries[1].ConnType := 0;
    PB.Entries[1].TermType := 0;  { ANSI }

    SavePhonebook(PB);
  end;
  if FileExists(PhoneFile) then begin
    Assign(F, PhoneFile);
    Reset(F);
    Read(F, PB);
    Close(F);
  end;
end;

procedure SavePhonebook(const PB: TPhonebook);
var F: File of TPhonebook;
begin
  Assign(F, PhoneFile);
  Rewrite(F);
  Write(F, PB);
  Close(F);
end;

procedure ShowPhonebook(Conn: TConnection; Term: PTermView);
var
  PB: TPhonebook;
  D: PDialog;
  R: TRect;
  LB: PListBox;
  SL: PStringCollection;
  I: Integer;
  Cmd: Word;
begin
  LoadPhonebook(PB);

  SL := New(PStringCollection, Init(MaxEntries, 10));
  for I := 0 to PB.Count - 1 do
    SL^.Insert(NewStr(PB.Entries[I].Name + ' — ' + PB.Entries[I].Host));

  if SL^.Count = 0 then
    SL^.Insert(NewStr('(no entries — use Settings to add)'));

  R.Assign(10, 3, 70, 20);
  D := New(PDialog, Init(R, 'Phonebook'));

  R.Assign(2, 2, 56, 13);
  LB := New(PListBox, Init(R, 1, nil));
  LB^.NewList(SL);
  D^.Insert(LB);

  R.Assign(5, 14, 20, 16);
  D^.Insert(New(PButton, Init(R, '~C~onnect', cmOK, bfDefault)));
  R.Assign(25, 14, 40, 16);
  D^.Insert(New(PButton, Init(R, 'Cancel', cmCancel, bfNormal)));

  Cmd := Desktop^.ExecView(D);
  if (Cmd = cmOK) and (PB.Count > 0) then begin
    I := LB^.Focused;
    if (I >= 0) and (I < PB.Count) then begin
      Term^.AddLine('Connecting to ' + PB.Entries[I].Name + '...');
      case PB.Entries[I].ConnType of
        0: begin
          if Conn.ConnectTelnet(PB.Entries[I].Host, PB.Entries[I].Port) then
            Term^.AddLine('Connected!')
          else
            Term^.AddLine('Failed.');
        end;
      end;
    end;
  end;

  Dispose(D, Done);
end;

end.

{$MODE OBJFPC}{$H+}
program keytest;
{ mterm Key Tester — verifies Ctrl, Alt, F1-F12 keys.
  Uses FV Drivers unit for key constants.
  Press ESC twice to exit.
  GPLv3 — FPC264IRC Contributors }

uses
  SysUtils, Crt;

const
  { Scan codes (hi byte of ReadKey extended) }
  scF1  = 59; scF2  = 60; scF3  = 61; scF4  = 62;
  scF5  = 63; scF6  = 64; scF7  = 65; scF8  = 66;
  scF9  = 67; scF10 = 68; scF11 = 133; scF12 = 134;

  scAltA = 30; scAltB = 48; scAltC = 46; scAltD = 32;
  scAltE = 18; scAltF = 33; scAltG = 34; scAltH = 35;
  scAltI = 23; scAltJ = 36; scAltK = 37; scAltL = 38;
  scAltM = 50; scAltN = 49; scAltO = 24; scAltP = 25;
  scAltQ = 16; scAltR = 19; scAltS = 31; scAltT = 20;
  scAltU = 22; scAltV = 47; scAltW = 17; scAltX = 45;
  scAltY = 21; scAltZ = 44;

  scUp = 72; scDown = 80; scLeft = 75; scRight = 77;
  scHome = 71; scEnd = 79; scPgUp = 73; scPgDn = 81;
  scIns = 82; scDel = 83;

function ScanName(Scan: Byte): String;
begin
  case Scan of
    scF1:  Result := 'F1';     scF2:  Result := 'F2';
    scF3:  Result := 'F3';     scF4:  Result := 'F4';
    scF5:  Result := 'F5';     scF6:  Result := 'F6';
    scF7:  Result := 'F7';     scF8:  Result := 'F8';
    scF9:  Result := 'F9';     scF10: Result := 'F10';
    scF11: Result := 'F11';    scF12: Result := 'F12';

    scAltA: Result := 'Alt-A'; scAltB: Result := 'Alt-B';
    scAltC: Result := 'Alt-C'; scAltD: Result := 'Alt-D';
    scAltE: Result := 'Alt-E'; scAltF: Result := 'Alt-F';
    scAltG: Result := 'Alt-G'; scAltH: Result := 'Alt-H';
    scAltI: Result := 'Alt-I'; scAltJ: Result := 'Alt-J';
    scAltK: Result := 'Alt-K'; scAltL: Result := 'Alt-L';
    scAltM: Result := 'Alt-M'; scAltN: Result := 'Alt-N';
    scAltO: Result := 'Alt-O'; scAltP: Result := 'Alt-P';
    scAltQ: Result := 'Alt-Q'; scAltR: Result := 'Alt-R';
    scAltS: Result := 'Alt-S'; scAltT: Result := 'Alt-T';
    scAltU: Result := 'Alt-U'; scAltV: Result := 'Alt-V';
    scAltW: Result := 'Alt-W'; scAltX: Result := 'Alt-X';
    scAltY: Result := 'Alt-Y'; scAltZ: Result := 'Alt-Z';

    scUp:    Result := 'Up';     scDown:  Result := 'Down';
    scLeft:  Result := 'Left';   scRight: Result := 'Right';
    scHome:  Result := 'Home';   scEnd:   Result := 'End';
    scPgUp:  Result := 'PgUp';   scPgDn:  Result := 'PgDn';
    scIns:   Result := 'Ins';    scDel:   Result := 'Del';
  else
    Result := 'Scan=$' + IntToHex(Scan, 2);
  end;
end;

var
  Ch: Char;
  Scan: Byte;
  LastESC: Boolean;
  Count: Integer;
begin
  ClrScr;
  TextColor(LightCyan);
  WriteLn('=== mterm Key Tester ===');
  TextColor(LightGray);
  WriteLn('Press keys to test. ESC twice to exit.');
  WriteLn;
  TextColor(Yellow);
  WriteLn('Key              Char  Ord   Scan  Name');
  TextColor(DarkGray);
  WriteLn('----------------------------------------------');
  TextColor(LightGray);
  WriteLn;

  WriteLn('Test these:');
  WriteLn('  F1-F12         (function keys)');
  WriteLn('  Ctrl-A..Z      (control keys, #1..#26)');
  WriteLn('  Alt-A..Z       (extended scan codes)');
  WriteLn('  Arrows         (Up/Down/Left/Right)');
  WriteLn('  Home/End       PgUp/PgDn  Ins/Del');
  WriteLn('  Enter  Tab  Backspace  Space');
  WriteLn;

  LastESC := False;
  Count := 0;

  repeat
    Ch := ReadKey;
    Inc(Count);

    if Ch = #0 then begin
      { Extended key — read scan code }
      Scan := Ord(ReadKey);
      TextColor(LightGreen);
      Write(Format('  #%-3d  %-10s', [Count, ScanName(Scan)]));
      TextColor(LightGray);
      Write(Format('  #0    0     $%02X   ', [Scan]));
      TextColor(White);
      WriteLn(ScanName(Scan));
      LastESC := False;
    end else if Ch = #27 then begin
      { ESC }
      TextColor(LightRed);
      Write(Format('  #%-3d  %-10s', [Count, 'ESC']));
      TextColor(LightGray);
      WriteLn(Format('  #27   27    --    ESC', []));
      if LastESC then begin
        TextColor(Yellow);
        WriteLn;
        WriteLn('ESC pressed twice. Exiting.');
        Break;
      end;
      LastESC := True;
    end else begin
      { Normal or Ctrl key }
      LastESC := False;
      TextColor(LightCyan);
      if Ord(Ch) < 32 then begin
        { Control character }
        Write(Format('  #%-3d  %-10s', [Count, 'Ctrl-' + Chr(Ord('A') + Ord(Ch) - 1)]));
        TextColor(LightGray);
        WriteLn(Format('  ^%s    %-5d --    Ctrl-%s', [
          Chr(Ord('A') + Ord(Ch) - 1), Ord(Ch),
          Chr(Ord('A') + Ord(Ch) - 1)]));
      end else begin
        { Printable character }
        Write(Format('  #%-3d  %-10s', [Count, '''' + Ch + '''']));
        TextColor(LightGray);
        WriteLn(Format('  %s     %-5d --    %s', [Ch, Ord(Ch), Ch]));
      end;
    end;
  until False;

  TextColor(LightGray);
  WriteLn;
  WriteLn(Count, ' keys tested.');
end.

// ====================================================================
// mystic_modem : legacy dialup / serial support for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// mdm_config - the module's own configuration, read from modem.ini.  This
// deliberately does NOT touch Mystic's MYSTIC.DAT / RecConfig, so adding
// this module changes nothing on disk for an existing board.  Uses FPC's
// standard IniFiles unit.
// ====================================================================

Unit mdm_Config;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Type
  TModemConfig = Record
    Device      : String;    // COM1 / /dev/ttyS0 / /dev/ttyUSB0
    Baud        : LongInt;    // locked DTE rate, e.g. 38400 or 115200
    InitString  : String;    // extra AT init after ATZ (e.g. AT&D2&C1)
    RingsToAns  : LongInt;    // answer after N rings
    HardwareFlow: Boolean;    // RTS/CTS
    WfcScreen   : String;     // path to the WFC screen ANSI (optional)
    LocalMode   : Boolean;    // skip modem, go straight to a local session
    UseFossil   : Boolean;    // route through the FOSSIL layer (INT14h on DOS)
    FossilPort  : LongInt;    // FOSSIL port number when UseFossil + DOS (0=COM1)
    AnswerStr   : String;     // command to answer the phone (1.07: default ATA)
    OffhookStr  : String;     // command to take the modem off-hook (1.07 field)
  End;

// Load modem.ini from the given path (or ./modem.ini).  Missing keys get
// sensible defaults.  If the file is absent, writes a documented default.
Function LoadModemConfig (Const FileName: String): TModemConfig;

// Write the given config back to FileName (preserving the documented comments).
Procedure SaveModemConfig (Const FileName: String; Const Cfg: TModemConfig);

Implementation

Uses
  m_FileIO, m_IniReader;

Procedure WriteDefault (Const FileName: String);
Var
  F : Text;
Begin
  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;
  WriteLn(F, '; ==================================================================');
  WriteLn(F, '; modem.ini - configuration for the Mystic dialup/serial add-on');
  WriteLn(F, '; ==================================================================');
  WriteLn(F, '; This file belongs to the mystic_modem module only.  It does NOT');
  WriteLn(F, '; affect MYSTIC.DAT or the main configuration.');
  WriteLn(F, ';');
  WriteLn(F, '[Modem]');
  WriteLn(F, '; Serial device.  Windows: COM1, COM2, ...  Linux: /dev/ttyS0 or');
  WriteLn(F, '; /dev/ttyUSB0 for a USB serial adapter.  macOS: /dev/cu.usbserial-*');
  WriteLn(F, '; (or /dev/cu.* for the built-in / adapter port).');
  WriteLn(F, 'device       = /dev/ttyS0');
  WriteLn(F, ';device      = COM1');
  WriteLn(F, ';');
  WriteLn(F, '; Locked DTE (computer<->modem) speed.  38400 or 115200 are typical.');
  WriteLn(F, 'baud         = 115200');
  WriteLn(F, ';');
  WriteLn(F, '; Extra AT init sent after ATZ.  &D2 = hang up on DTR drop,');
  WriteLn(F, '; &C1 = DCD follows carrier (both recommended).');
  WriteLn(F, 'init         = AT&D2&C1');
  WriteLn(F, ';');
  WriteLn(F, '; Answer the phone after this many rings.');
  WriteLn(F, 'rings        = 1');
  WriteLn(F, ';');
  WriteLn(F, '; Hardware (RTS/CTS) flow control.  true is almost always correct.');
  WriteLn(F, 'hardwareflow = true');
  WriteLn(F, ';');
  WriteLn(F, '; Optional ANSI screen shown while waiting for a caller.');
  WriteLn(F, ';wfcscreen   = wfcscrn.ans');
  WriteLn(F, ';');
  WriteLn(F, '; Start in local mode (skip the modem, log in at the console).');
  WriteLn(F, 'localmode    = false');
  WriteLn(F, ';');
  WriteLn(F, '; Route serial I/O through the FOSSIL layer.  On a DOS build this');
  WriteLn(F, '; uses a real INT 14h FOSSIL driver (X00/BNU/NetFoss); on Win32/Linux');
  WriteLn(F, '; it presents the same FOSSIL API over the native serial backend.');
  WriteLn(F, 'usefossil    = false');
  WriteLn(F, ';');
  WriteLn(F, '; FOSSIL port number when usefossil=true on a DOS build (0 = COM1).');
  WriteLn(F, 'fossilport   = 0');
  Close(F);
End;

Function LoadModemConfig (Const FileName: String): TModemConfig;
Var
  Ini : TIniReader;
  FN  : String;
Begin
  FN := FileName;
  If FN = '' Then FN := 'modem.ini';

  If Not FileExist(FN) Then WriteDefault(FN);

  Ini := TIniReader.Create(FN);
  Try
    Result.Device       := Ini.ReadString ('Modem', 'device',       '/dev/ttyS0');
    Result.Baud         := Ini.ReadInteger('Modem', 'baud',         115200);
    Result.InitString   := Ini.ReadString ('Modem', 'init',         'AT&D2&C1');
    Result.RingsToAns   := Ini.ReadInteger('Modem', 'rings',        1);
    Result.HardwareFlow := Ini.ReadBoolean('Modem', 'hardwareflow', True);
    Result.WfcScreen    := Ini.ReadString ('Modem', 'wfcscreen',    '');
    Result.LocalMode    := Ini.ReadBoolean('Modem', 'localmode',    False);
    Result.UseFossil    := Ini.ReadBoolean('Modem', 'usefossil',    False);
    Result.FossilPort   := Ini.ReadInteger('Modem', 'fossilport',   0);
    Result.AnswerStr    := Ini.ReadString ('Modem', 'answer',       'ATA');
    Result.OffhookStr   := Ini.ReadString ('Modem', 'offhook',      'ATH1');
  Finally
    Ini.Free;
  End;
End;

Procedure SaveModemConfig (Const FileName: String; Const Cfg: TModemConfig);
Var
  F  : Text;
  FN : String;

  Function B (V: Boolean): String;
  Begin If V Then B := 'true' Else B := 'false'; End;

Begin
  FN := FileName;
  If FN = '' Then FN := 'modem.ini';

  Assign(F, FN);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Exit;

  WriteLn(F, '; ==================================================================');
  WriteLn(F, '; modem.ini - configuration for the Mystic dialup/serial add-on');
  WriteLn(F, '; ==================================================================');
  WriteLn(F, '; This file belongs to the mystic_modem module only.  It does NOT');
  WriteLn(F, '; affect MYSTIC.DAT or the main configuration.  Edit it with the');
  WriteLn(F, '; modem setup tool (modemcfg) or by hand.');
  WriteLn(F, ';');
  WriteLn(F, '[Modem]');
  WriteLn(F, '; Serial device.  Windows: COM1, COM2, ...  Linux: /dev/ttyS0 or');
  WriteLn(F, '; /dev/ttyUSB0 for a USB serial adapter.');
  WriteLn(F, 'device       = ', Cfg.Device);
  WriteLn(F, ';');
  WriteLn(F, '; Locked DTE (computer<->modem) speed.  38400 or 115200 are typical.');
  WriteLn(F, 'baud         = ', Cfg.Baud);
  WriteLn(F, ';');
  WriteLn(F, '; Extra AT init sent after ATZ.  &D2 = hang up on DTR drop,');
  WriteLn(F, '; &C1 = DCD follows carrier (both recommended).');
  WriteLn(F, 'init         = ', Cfg.InitString);
  WriteLn(F, ';');
  WriteLn(F, '; Answer the phone after this many rings.');
  WriteLn(F, 'rings        = ', Cfg.RingsToAns);
  WriteLn(F, ';');
  WriteLn(F, '; Hardware (RTS/CTS) flow control.  true is almost always correct.');
  WriteLn(F, 'hardwareflow = ', B(Cfg.HardwareFlow));
  WriteLn(F, ';');
  WriteLn(F, '; Optional ANSI screen shown while waiting for a caller.');
  If Cfg.WfcScreen = '' Then
    WriteLn(F, ';wfcscreen   = wfcscrn.ans')
  Else
    WriteLn(F, 'wfcscreen    = ', Cfg.WfcScreen);
  WriteLn(F, ';');
  WriteLn(F, '; Start in local mode (skip the modem, log in at the console).');
  WriteLn(F, 'localmode    = ', B(Cfg.LocalMode));
  WriteLn(F, ';');
  WriteLn(F, '; Route serial I/O through the FOSSIL layer.  On a DOS build this');
  WriteLn(F, '; uses a real INT 14h FOSSIL driver (X00/BNU/NetFoss); on Win32/Linux');
  WriteLn(F, '; it presents the same FOSSIL API over the native serial backend.');
  WriteLn(F, 'usefossil    = ', B(Cfg.UseFossil));
  WriteLn(F, ';');
  WriteLn(F, '; FOSSIL port number when usefossil=true on a DOS build (0 = COM1).');
  WriteLn(F, 'fossilport   = ', Cfg.FossilPort);
  WriteLn(F, ';');
  WriteLn(F, '; Command sent to answer an incoming call (classic Mystic: ATA).');
  WriteLn(F, 'answer       = ', Cfg.AnswerStr);
  WriteLn(F, ';');
  WriteLn(F, '; Command to take the modem off-hook (busy).  1.07 "Offhook" field.');
  WriteLn(F, 'offhook      = ', Cfg.OffhookStr);
  Close(F);
End;

End.

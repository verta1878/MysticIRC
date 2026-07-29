Unit bbs_Cfg_Main;

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

{$I M_OPS.PAS}

Interface

Procedure Configuration_MainMenu;
Procedure Configuration_ExecuteEditor (Mode: Char);

Implementation

Uses
  m_Types,
  m_Strings,
  bbs_Records,
  bbs_Core,
  bbs_IO,
  bbs_Common,
  bbs_DataBase,
  bbs_Ansi_MenuBox,
  bbs_Ansi_MenuForm,
  bbs_cfg_SysCfg,
  bbs_cfg_Archive,
  bbs_cfg_Protocol,
  bbs_cfg_FileBase,
  bbs_cfg_MsgBase,
  bbs_cfg_Groups,
  bbs_cfg_SecLevel,
  bbs_cfg_Theme,
  bbs_cfg_UserEdit,
  bbs_cfg_EchoMail,
  bbs_cfg_MenuEdit,
  bbs_cfg_Events,
  bbs_Cfg_QwkNet,
  bbs_Edit_Ansi;

Procedure Configuration_ExecuteEditor (Mode: Char);
Var
  TmpImage : TConsoleImageRec;
Begin
  Console.GetScreenImage (1, 1, 79, 24, TmpImage);

  Case Mode of
    'A' : Configuration_ArchiveEditor;
    'B' : Configuration_MessageBaseEditor(True);
    'F' : Configuration_FileBaseEditor;
    'G' : Configuration_GroupEditor(True);
    'L' : Configuration_SecurityEditor(True);
    'M' : Configuration_MenuEditor;
    'P' : Configuration_ProtocolEditor;
    'R' : Configuration_GroupEditor(False);
    'U' : Configuration_UserEditor;
  End;

  Session.io.RemoteRestore(TmpImage);
End;

Procedure Configuration_AnsiEditor;
Var
  Editor : TEditorANSI;
  TmpImg : TConsoleImageRec;
Begin
  Console.GetScreenImage (1, 1, 79, 24, TmpImg);
  Editor := TEditorANSI.Create(Pointer(Session), '');
  Editor.DrawMode   := True;
  Editor.InsertMode := False;
  Editor.MaxMsgCols := 79;
  Editor.Edit;
  Editor.Free;
  Session.io.RemoteRestore(TmpImg);
End;

Procedure Configuration_EditFile (FName: String);
Var
  Editor : TEditorANSI;
  TmpImg : TConsoleImageRec;
Begin
  Console.GetScreenImage (1, 1, 79, 24, TmpImg);
  Editor := TEditorANSI.Create(Pointer(Session), '');
  Editor.FileMode := True;
  If FName <> '' Then
    Editor.LoadFile(FName);
  Editor.Edit;
  Editor.Free;
  Session.io.RemoteRestore(TmpImg);
End;

Procedure Configuration_ViewLogs;
Var
  Editor : TEditorANSI;
  TmpImg : TConsoleImageRec;
Begin
  Console.GetScreenImage (1, 1, 79, 24, TmpImg);
  Editor := TEditorANSI.Create(Pointer(Session), '');
  Editor.FileMode     := True;
  Editor.FileReadOnly := True;
  If Editor.LoadFile(bbsCfg.LogsPath + 'mystic.log') Then
    Editor.Edit;
  Editor.Free;
  Session.io.RemoteRestore(TmpImg);
End;

// RIP Editor removed â€” RIP requires graphical mode (640x350), not text 80x25.
// RIP scene editing handled externally. See mystic_rip/v1/ engines.

Var
  MenuPtr : Byte = 0;

Procedure DrawStatus (Item: FormItemRec);
Var
  Topic : String[30];
  Desc  : String[60];
Begin
  Case MenuPtr of
    0 : Topic := 'Main';
    1 : Topic := 'Configuration';
    2 : Topic := 'Servers';
    3 : Topic := 'Editors';
    4 : Topic := 'Other';
  End;

  Desc := Item.Help;

  If Desc = '' Then Desc := Copy(Item.Desc, 4, 255);

  Session.io.AnsiGotoXY (5, 24);
  Session.io.OutPipe ('|16|03(|09' + Topic + '|03) |01-|09> |15' + Desc + '|15.|07.|08.');
  Session.io.AnsiClrEOL;
End;

Procedure Configuration_MainMenu;
Var
  Form     : TAnsiMenuForm;
  Box      : TAnsiMenuBox;
  Image    : TConsoleImageRec;
  MenuPos  : Array[0..4] of Byte = (1, 1, 1, 1, 1);
  Res        : Char;
  ErrCode    : Integer;
  VerifyCfg  : RecConfig;
  VerifyFile : File of RecConfig;

  Procedure BoxOpen (X1, Y1, X2, Y2: Byte);
  Begin
    Box := TAnsiMenuBox.Create;
    Box.Open (X1, Y1, X2, Y2);
  End;

  Procedure CoolBoxOpen (X1: Byte; Text: String);
  Var
    Len : Byte;
  Begin
    Len := Length(Text) + 6;

    Console.GetScreenImage(X1, 1, X1 + Len, 3, Image);

    WriteXYPipe (X1, 1, 8, Len, 'Ü|15Ü|11ÜÜ|03ÜÜ|09Ü|03Ü|09' + strRep('Ü', Len - 9) + '|08Ü');
    WriteXYPipe (X1, 2, 8, Len, 'Ý|09|17² |15' + Text + ' |00°|16|08Þ');
    WriteXYPipe (X1, 3, 8, Len, 'ß|01²|17 |11À|03ÄÄ|08' + strRep('Ä', Length(Text) - 4) + '|00¿ ±|16|08ß');
  End;

  Procedure CoolBoxClose;
  Begin
    Session.io.RemoteRestore(Image);

    Box.Close;
    Box.Free;
  End;

  Procedure AboutBox;
  Var
    AboutImg : TConsoleImageRec;
    ABox     : TAnsiMenuBox;
  Begin
    // Box centered on an 80-col screen, wide enough for the 38-char copyright.
    // Interior runs col 20..61 (42 wide); text is padded/centered to 42.
    // Blue popup: white/cyan text on a blue background (fg + 1*16).
    Console.GetScreenImage (18, 8, 63, 15, AboutImg);

    ABox := TAnsiMenuBox.Create;
    ABox.BoxAttr  := 15 + 1 * 16;      // bright white on blue (frame)
    ABox.BoxAttr2 := 7  + 1 * 16;
    ABox.BoxAttr3 := 7  + 1 * 16;
    ABox.BoxAttr4 := 7  + 1 * 16;
    ABox.Open (18, 8, 63, 15);

    WriteXY (20, 10, 15 + 1 * 16, strPadC ('Mystic BBS',   42, ' '));
    WriteXY (20, 11, 11 + 1 * 16, strPadC (mysVersion,     42, ' '));
    WriteXY (20, 13, 15 + 1 * 16, strPadC (mysCopyNotice,  42, ' '));

    Session.io.GetKey;

    ABox.Close;
    ABox.Free;
    Session.io.RemoteRestore (AboutImg);
  End;

Begin
  Session.io.OutFile(bbsCfg.DataPath + 'cfgroot', False, 0);

  Form := TAnsiMenuForm.Create;

  Form.HelpProc := @DrawStatus;

  Repeat
    Form.Clear;

    Form.ItemPos := MenuPos[MenuPtr];
    MenuPos[0]   := MenuPtr;

    If MenuPtr = 0 Then Begin
      Form.HiExitChars := #80;
      Form.ExitOnFirst := False;
    End Else Begin
      Form.HiExitChars := #75#77;
      Form.ExitOnFirst := True;
    End;

    Case MenuPtr of
      0 : Begin
            Form.AddNone('C', ' Configuration ',  5, 2,  5, 2, 15, 'BBS configuration settings');
            Form.AddNone('S', ' Servers ',       26, 2, 26, 2,  9, 'Mystic Internet Server (MIS) settings');
            Form.AddNone('E', ' Editors ',       41, 2, 41, 2,  9, 'BBS configuration editors');
            Form.AddNone('O', ' Other ',         56, 2, 56, 2,  7, 'Tools, editors, and system info');
            Form.AddNone('X', ' Exit ' ,         69, 2, 69, 2,  6, 'Exit configuration');

            Res := Form.Execute;

            If Form.WasHiExit Then
              If Form.ItemPos = 5 Then
                Break
              Else
                MenuPtr := Form.ItemPos
            Else
              Case Res of
                #27,
                'X' : Break;
                'C' : MenuPtr := 1;
                'S' : MenuPtr := 2;
                'E' : MenuPtr := 3;
                'O' : MenuPtr := 4;
              End;
          End;
      1 : Begin
            BoxOpen      (4, 4, 33, 18);
            CoolBoxOpen  (3, 'Configuration');

            Form.AddNone ('S', ' S System Paths',             5,  5, 5,  5, 28, '');
            Form.AddNone ('G', ' G General Settings',         5,  6, 5,  6, 28, '');
            Form.AddNone ('L', ' L Login/Matrix Settings',    5,  7, 5,  7, 28, '');
            Form.AddNone ('1', ' 1 New User Settings 1',      5,  8, 5,  8, 28, '');
            Form.AddNone ('2', ' 2 New User Settings 2',      5,  9, 5,  9, 28, '');
            Form.AddNone ('3', ' 3 New User Optional Fields', 5, 10, 5, 10, 28, '');
            Form.AddNone ('F', ' F File Base Settings',       5, 11, 5, 11, 28, '');
            Form.AddNone ('M', ' M Message Base Settings',    5, 12, 5, 12, 28, '');
            Form.AddNone ('E', ' E EchoMail Addresses',       5, 13, 5, 13, 28, '');
            Form.AddNone ('N', ' N EchoMail Nodes',           5, 14, 5, 14, 28, '');
            Form.AddNone ('Q', ' Q QWK Networking',           5, 15, 5, 15, 28, '');
            Form.AddNone ('O', ' O Local QWK Settings',       5, 16, 5, 16, 28, '');
            Form.AddNone ('C', ' C Console Settings',         5, 17, 5, 17, 28, '');

            Res        := Form.Execute;
            MenuPos[1] := Form.ItemPos;

            CoolBoxClose;

            If Form.WasHiExit Then Begin
              Case Res of
                #75 : Begin              // Left off Configuration -> land on top-bar Exit
                        MenuPtr    := 0;
                        MenuPos[0] := 5;
                      End;
                #77 : MenuPtr := 2;
              End;
            End Else
              Case Res of
                'S' : Configuration_SysPaths;
                'G' : Configuration_GeneralSettings;
                'L' : Configuration_LoginMatrix;
                'E' : Configuration_EchoMailAddress(True);
                'N' : Configuration_EchoMailNodes(True);
                '3' : Configuration_OptionalFields;
                'F' : Configuration_FileSettings;
                'M' : Configuration_MessageSettings;
                'Q' : Configuration_QwkNetworks(True);
                'O' : Configuration_QWKSettings;
                '1' : Configuration_NewUser1Settings;
                '2' : Configuration_NewUser2Settings;
                'C' : Configuration_ConsoleSettings;
                'X' : Break;
              Else
                MenuPtr := 0;
              End;
          End;
      2 : Begin
            BoxOpen      (25, 4, 53, 12);
            CoolBoxOpen  (24, 'Servers');

            Form.AddNone ('I', ' I Internet Server Options', 26,  5, 26,  5, 27, '');
            Form.AddNone ('1', ' 1 Telnet Server Options',   26,  6, 26,  6, 27, '');
            Form.AddNone ('2', ' 2 FTP Server Options',      26,  7, 26,  7, 27, '');
            Form.AddNone ('3', ' 3 POP3 Server Options',     26,  8, 26,  8, 27, '');
            Form.AddNone ('4', ' 4 SMTP Server Options',     26,  9, 26,  9, 27, '');
            Form.AddNone ('5', ' 5 NNTP Server Options',     26, 10, 26, 10, 27, '');
            Form.AddNone ('6', ' 6 BINKP Server Options',    26, 11, 26, 11, 27, '');

            Res        := Form.Execute;
            MenuPos[2] := Form.ItemPos;

            CoolBoxClose;

            If Form.WasHiExit Then Begin
              Case Res of
                #75 : MenuPtr := 1;
                #77 : MenuPtr := 3;
              End;
            End Else
              Case Res of
                'I' : Configuration_Internet;
                '1' : Configuration_TelnetServer;
                '2' : Configuration_FTPServer;
                '3' : Configuration_POP3Server;
                '4' : Configuration_SMTPServer;
                '5' : Configuration_NNTPServer;
                '6' : Configuration_BINKPServer;
                'X' : Break;
              Else
                MenuPtr := 0;
              End;
          End;
      3 : Begin
            BoxOpen      (38, 4, 64, 16);
            CoolBoxOpen  (39, 'Editors');

            Form.AddNone ('U', ' U User Editor',           39,  5, 39,  5, 25, '');
            Form.AddNone ('M', ' M Menu Editor',           39,  6, 39,  6, 25, '');
            Form.AddNone ('T', ' T Theme/Prompt Editor',   39,  7, 39,  7, 25, '');
            Form.AddNone ('B', ' B Message Base Editor',   39,  8, 39,  8, 25, '');
            Form.AddNone ('G', ' G Message Group Editor',  39,  9, 39,  9, 25, '');
            Form.AddNone ('F', ' F File Base Editor',      39, 10, 39, 10, 25, '');
            Form.AddNone ('R', ' R File Group Editor',     39, 11, 39, 11, 25, '');
            Form.AddNone ('S', ' S Security Level Editor', 39, 12, 39, 12, 25, '');
            Form.AddNone ('A', ' A Archive Editor',        39, 13, 39, 13, 25, '');
            Form.AddNone ('P', ' P Protocol Editor',       39, 14, 39, 14, 25, '');
            Form.AddNone ('E', ' E Event Editor',          39, 15, 39, 15, 25, '');

            Res        := Form.Execute;
            MenuPos[3] := Form.ItemPos;

            CoolBoxClose;

            If Form.WasHiExit Then Begin
              Case Res of
                #75 : MenuPtr := 2;
                #77 : MenuPtr := 4;
              End;
            End Else Begin
              Case Res of
                'A' : Configuration_ArchiveEditor;
                'B' : Configuration_MessageBaseEditor(True);
                'F' : Configuration_FileBaseEditor;
                'G' : Configuration_GroupEditor(True);
                'M' : Configuration_MenuEditor;
                'P' : Configuration_ProtocolEditor;
                'R' : Configuration_GroupEditor(False);
                'S' : Configuration_SecurityEditor(True);
                'T' : Configuration_ThemeEditor(False);
                'U' : Configuration_UserEditor;
                'E' : Configuration_Events;
                'X' : Break;
              Else
                MenuPtr := 0;
              End;
            End;
          End;
      4 : Begin
            BoxOpen      (48, 4, 79, 21);
            CoolBoxOpen  (54, 'Other');

            // A4: editors disabled â€” use standalone binaries
            // Form.AddNone ('A', ' A ANSI Editor',              50,  5, 50,  5, 28, 'Launch ANSI art editor');
            // Form.AddNone ('T', ' T Text Editor',              50,  6, 50,  6, 28, 'Edit text files');
            Form.AddNone ('L', ' L View Log Files',           50,  5, 50,  5, 28, 'View system log files');
            // RIP Editor removed â€” requires graphical mode
            Form.AddNone ('-', ' --------------------------', 50,  9, 50,  9, 28, '');
            Form.AddNone ('N', ' N Edit Bad User Names',      50, 10, 50, 10, 28, 'Edit banned user names');
            Form.AddNone ('D', ' D Edit Bad E-mails',         50, 11, 50, 11, 28, 'Edit banned email list');
            Form.AddNone ('W', ' W Edit New User Welcome',    50, 12, 50, 12, 28, 'Edit new user welcome letter');
            Form.AddNone ('U', ' U Edit New User Notify',     50, 13, 50, 13, 28, 'Edit new user notification');
            Form.AddNone ('H', ' H Edit Hack Warning',        50, 14, 50, 14, 28, 'Edit hack warning message');
            Form.AddNone ('P', ' P Edit Spellcheck Words',    50, 15, 50, 15, 28, 'Edit spellcheck dictionary');
            Form.AddNone ('G', ' G Edit Global Taglines',     50, 16, 50, 16, 28, 'Edit global tagline list');
            Form.AddNone ('C', ' C Reset Caller Data',        50, 17, 50, 17, 28, 'Reset caller data');
            Form.AddNone ('-', ' --------------------------', 50, 18, 50, 18, 28, '');
            Form.AddNone ('V', ' V Version Information',      50, 19, 50, 19, 28, 'About Mystic BBS');

            Res        := Form.Execute;
            MenuPos[4] := Form.ItemPos;

            CoolBoxClose;

            If Form.WasHiExit Then Begin
              Case Res of
                #75 : MenuPtr := 3;
                #77 : Begin
                        MenuPtr     := 0;
                        MenuPos[0]  := 5;
                      End;
              End;
            End Else
              Case Res of
                // A4: ANSI/Text editors disabled â€” use standalone mystic_ansieditor/mystic_texteditor
                // 'A' : Configuration_AnsiEditor;
                // 'T' : Configuration_EditFile('');
                'L' : Configuration_ViewLogs;
                // 'R' : RIP Editor removed
                'N' : Configuration_EditFile(bbsCfg.DataPath + 'badnames.txt');
                'D' : Configuration_EditFile(bbsCfg.DataPath + 'bademail.txt');
                'W' : Configuration_EditFile(bbsCfg.DataPath + 'newletter.txt');
                'U' : Configuration_EditFile(bbsCfg.DataPath + 'newnotify.txt');
                'H' : Configuration_EditFile(bbsCfg.DataPath + 'hackwarn.txt');
                'P' : Configuration_EditFile(bbsCfg.DataPath + 'spellcheck.txt');
                'G' : Configuration_EditFile(bbsCfg.DataPath + 'taglines.txt');
                'C' : Begin
                        If ShowMsgBox(1, 'Reset system caller count to zero?') Then Begin
                          bbsCfg.SystemCalls := 0;
                          PutBaseConfiguration(bbsCfg);
                        End;
                      End;
                'V' : AboutBox;
                'X' : Break;
              Else
                MenuPtr := 0;
              End;
          End;
    End;
  Until False;

  Form.Free;

  {$I-} ReWrite (Session.ConfigFile); {$I+}
  ErrCode := IoResult;
  If ErrCode <> 0 Then
    ErrorLogWrite (bbsCfgPath + 'mystic.dat', ErrCode)
  Else Begin
    {$I-} Write (Session.ConfigFile, bbsCfg); {$I+}
    ErrCode := IoResult;

    {$I-} Close (Session.ConfigFile); {$I+}
    If IoResult <> 0 Then ;

    If ErrCode <> 0 Then
      ErrorLogWrite (bbsCfgPath + 'mystic.dat', ErrCode)
    Else Begin
      // Read-after-write verify: re-open mystic.dat and confirm the bytes
      // actually persisted, so a silent 'clean exit but nothing saved' can
      // never happen unnoticed.  Logs the outcome to mystic.log.
      Assign (VerifyFile, bbsCfgPath + 'mystic.dat');
      {$I-} Reset (VerifyFile); {$I+}
      If IoResult <> 0 Then
        ConfigLog ('WARNING: saved mystic.dat but could not reopen to verify')
      Else Begin
        {$I-} Read (VerifyFile, VerifyCfg); {$I+}
        ErrCode := IoResult;
        {$I-} Close (VerifyFile); {$I+}
        If IoResult <> 0 Then ;

        If ErrCode <> 0 Then
          ConfigLog ('WARNING: mystic.dat saved but could not be read back to verify')
        Else If CompareByte(VerifyCfg, bbsCfg, SizeOf(RecConfig)) = 0 Then
          ConfigLog ('Configuration saved and verified (' + strI2S(SizeOf(RecConfig)) + ' bytes)')
        Else
          ConfigLog ('WARNING: mystic.dat verify FAILED - save did not persist correctly');
      End;
    End;
  End;
End;

End.

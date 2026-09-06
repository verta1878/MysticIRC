// ====================================================================
// mystic_misdos : a DOS-style MIS "Waiting For Caller" example
// ====================================================================
//
// This file is part of an optional add-on EXAMPLE for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// misdos_commands - the WFC hot-key handlers.  Every option shown on the
// Waiting-For-Caller screen does something real here:
//
//   Editors (U S P E # M G A V F L) shell out to the matching Mystic
//   configuration tool.  Stock Mystic's local WFC keys launch the config
//   program (mystic -cfg / the editors inside it); this example does the
//   equivalent by running the tool if it's present next to the exe, and
//   otherwise printing exactly which editor WOULD open (so the example is
//   fully functional even in a bare checkout with no built tools).
//
//   X  Answer Modem   -> brings the modem off-hook via mystic_modem.
//   D  Drop to DOS    -> spawns a subshell; returns to the WFC on exit.
//   Q  Quit to DOS    -> leaves the WFC loop.
//   SPACE Local Login -> runs a local node session (see misdos.pas).
//
// This is the DOS-MIS example and is intentionally SEPARATE from the main
// mystic/ source (sysop decision 2026-07-08): it demonstrates the modem +
// binkp add-ons driving a WFC, not the shipping MIS server.
// ====================================================================

Unit misdos_Commands;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Type
  // returned by HandleKey so the main loop knows what to do next
  TWfcAction = (waNone, waQuit, waLocalLogin, waAnswer, waRedraw);

// Dispatch a WFC hot-key.  Returns the action for the main loop.
Function HandleKey (Ch: Char) : TWfcAction;

Implementation

Uses
  SysUtils,
  Crt;

// Run an external program if present; report what would run otherwise.
// Returns True if it actually launched something.
Function RunTool (Const ExeBase, Args, Describe: String) : Boolean;
Var
  Dir, Cand : String;
  Ext       : String;
Begin
  Result := False;

  {$IFDEF WINDOWS} Ext := '.exe'; {$ELSE} Ext := ''; {$ENDIF}

  Dir  := ExtractFilePath(ParamStr(0));
  Cand := Dir + ExeBase + Ext;

  Window (1, 1, 80, 25);
  TextAttr := 7;
  GotoXY (1, 25);

  If FileExists(Cand) Then Begin
    Writeln;
    Writeln('  Launching ', ExeBase, ' ', Args, ' ...');
    ExecuteProcess (Cand, Args);
    Result := True;
  End Else Begin
    Writeln;
    Writeln('  [', Describe, ']');
    Writeln('  (', ExeBase, Ext, ' not found next to this example - in a full');
    Writeln('   Mystic install this key opens that editor.)');
    Writeln('  Press any key to return to the WFC...');
    ReadKey;
  End;
End;

Function HandleKey (Ch: Char) : TWfcAction;
Begin
  Result := waNone;

  Case UpCase(Ch) of
    // ---- editors: these live inside the Mystic config program ----------
    'U' : RunTool ('mystic', '-CFG USER',     'User Editor');
    'S' : RunTool ('mystic', '-CFG',          'System Configuration');
    'P' : RunTool ('mystic', '-CFG PROTOCOL', 'Protocol Editor');
    'E' : RunTool ('mystic', '-CFG EVENT',    'Event Editor');
    '#' : RunTool ('mide',   '',              'Menu Editor');
    'M' : RunTool ('mystic', '-CFG MSGBASE',  'Message Base Editor');
    'G' : RunTool ('mystic', '-CFG GROUP',    'Group Editor');
    'A' : RunTool ('mystic', '-CFG ARCHIVE',  'Archive Editor');
    'V' : RunTool ('mystic', '-CFG VOTING',   'Voting Booth Editor');
    'F' : RunTool ('mystic', '-CFG FILEBASE', 'File Base Editor');
    'L' : RunTool ('mystic', '-CFG SECURITY', 'Security Levels');

    // ---- modem / session / exit ----------------------------------------
    'X' : Result := waAnswer;         // Answer Modem (handled in main loop)
    'D' : Begin                        // Drop to DOS (subshell)
            Window (1, 1, 80, 25); TextAttr := 7; GotoXY (1, 25);
            Writeln;
            Writeln('  Dropping to a shell.  Type EXIT to return to the WFC.');
            {$IFDEF WINDOWS}
              ExecuteProcess (GetEnvironmentVariable('COMSPEC'), '');
            {$ELSE}
              {$IFDEF OS2}
                ExecuteProcess (GetEnvironmentVariable('COMSPEC'), '');
              {$ELSE}
                ExecuteProcess ('/bin/sh', '');
              {$ENDIF}
            {$ENDIF}
            Result := waRedraw;
          End;
    'Q' : Result := waQuit;            // Quit to DOS
    ' ' : Result := waLocalLogin;      // SPACE = local login
  Else
    Result := waNone;
  End;

  // after any editor/subshell, the caller should repaint the WFC
  If Result = waNone Then Result := waRedraw;
End;

End.

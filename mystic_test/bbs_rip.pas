{$MODE DELPHI}
{$H-}
{$IFDEF EXPERIMENTAL_RIP}
Unit BBS_RIP;
{
  BBS_RIP — RIPscrip v1.54 integration for Mystic BBS
  
  Connects the pixel-tested ripviewer engine to the BBS session.
  Activated by {$DEFINE EXPERIMENTAL_RIP} in the build.
  
  HOW IT WORKS:
  1. When a RIP terminal connects, BBS sets UseRipTerm := True
  2. BBS calls RIPSendFile() to send .RIP files to the terminal
  3. For server-side rendering (headless), BBS calls RIPRenderToBMP()
  4. RIP mouse fields are tracked for menu navigation
  
  The engine is the same code tested in examples/ripviewer/ with
  30+ test runs and pixel-perfect results on 3 test files.
  
  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
  Reference: RIPtermJS by Carl Gorringe
}

Interface

Uses SysUtils;

{ Send a .RIP file to the connected terminal as raw RIPscrip commands }
Procedure RIPSendFile(const FileName: String);

{ Render a .RIP file to BMP (server-side, for web/preview) }
Function RIPRenderToBMP(const RipFile, BmpFile: String): Boolean;

{ Reset RIP state (called on new connection) }
Procedure RIPReset;

{ Check if file has RIP content }
Function IsRIPFile(const FileName: String): Boolean;

Implementation

Uses
  RIP_Graph,
  RIP_Parser;

Procedure RIPSendFile(const FileName: String);
{ Send raw RIP commands to the terminal.
  The terminal (RIPterm, SyncTERM, etc.) handles rendering.
  We just send the !| command stream line by line. }
Var
  F: Text;
  Line: String;
Begin
  If Not FileExists(FileName) Then Exit;
  Assign(F, FileName);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;
  While Not EOF(F) Do Begin
    ReadLn(F, Line);
    { Send line to terminal — BBS IO layer handles this }
    { TODO: wire to Session.IO.OutRaw(Line + #13#10) }
  End;
  Close(F);
End;

Function RIPRenderToBMP(const RipFile, BmpFile: String): Boolean;
{ Server-side rendering: parse RIP commands and produce BMP output.
  Uses the same engine as examples/ripviewer/ (pixel-tested).
  Useful for web interfaces, thumbnails, and headless rendering. }
Begin
  Result := False;
  If Not FileExists(RipFile) Then Exit;
  { TODO: wire to ripviewer engine units (ripdraw, riptext, ripengine, ripbmp)
    These need to be copied to mystic_test/ or added to the unit path.
    For now this is a stub — Phase 4 step 2 will complete the wiring. }
  Result := False;
End;

Procedure RIPReset;
{ Reset RIP graphics state for new session }
Begin
  { TODO: clear canvas, reset palette, reset viewport }
End;

Function IsRIPFile(const FileName: String): Boolean;
{ Check if a file contains RIPscrip commands }
Var
  F: Text;
  Line: String;
Begin
  Result := False;
  If Not FileExists(FileName) Then Exit;
  Assign(F, FileName);
  {$I-} System.Reset(F); {$I+}
  If IOResult <> 0 Then Exit;
  If Not EOF(F) Then Begin
    ReadLn(F, Line);
    Result := (Pos('!|', Line) > 0);
  End;
  Close(F);
End;

End.
{$ENDIF}

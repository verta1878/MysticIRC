{$MODE DELPHI}
{$H-}
Unit m_editor_io;
{
  TEditorIO — Abstract I/O interface for ANSI/text editors.
  Part of Mystic BBS 1.11IRC MDL.

  Decouples the ANSI editor from BBS_Core/Session so the same
  editor class works standalone (console) or inside the BBS.

  Two implementations:
    TEditorIOConsole — direct console via m_Input/m_Output (standalone)
    TEditorIOSession — wraps BBS Session.io (Mystic -cfg mode)

  Usage:
    Var IO: TEditorIO;
    IO := TEditorIOConsole.Create;  // or TEditorIOSession.Create(Session)
    Editor := TEditorANSI.Create(IO);

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Type
  TEditorIO = Class
  Public
    { Screen output }
    Procedure WriteXY(X, Y, Attr: Byte; S: String); Virtual; Abstract;
    Procedure WriteChar(Ch: Char); Virtual; Abstract;
    Procedure WriteStr(S: String); Virtual; Abstract;
    Procedure AnsiColor(Attr: Byte); Virtual; Abstract;
    Procedure AnsiGotoXY(X, Y: Byte); Virtual; Abstract;
    Procedure ClearScreen; Virtual; Abstract;
    Procedure ClearEOL; Virtual; Abstract;

    { Cursor }
    Procedure CursorOn; Virtual; Abstract;
    Procedure CursorOff; Virtual; Abstract;

    { Input }
    Function  GetKey: Char; Virtual; Abstract;
    Function  GetYN(Prompt: String; Default: Boolean): Boolean; Virtual; Abstract;
    Function  GetStr(Prompt: String; MaxLen: Byte; Default: String): String; Virtual; Abstract;
    Function  KeyPressed: Boolean; Virtual; Abstract;

    { Screen info }
    Function  ScreenWidth: Byte; Virtual; Abstract;
    Function  ScreenHeight: Byte; Virtual; Abstract;

    { Status }
    Procedure SetStatusLine(S: String); Virtual; Abstract;
  End;

Implementation

End.

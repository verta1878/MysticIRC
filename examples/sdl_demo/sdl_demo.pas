// ====================================================================
// mystic_sdl : optional SDL2 DOS-session front-end for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// sdl_demo - opens the SDL DOS-session window and renders a Waiting-For-Caller
// screen into it, demonstrating the full-screen DOS look the modem / BinkP
// front-ends would use.  Loads the modem module's WFCSCRN.ANS if present;
// otherwise draws a built-in WFC using WriteXY.
//
//   sdl_demo [wfcscrn.ans] [vga8x16.fnt]
//
// Runs a short render loop; press a key or close the window to exit.  With
// SDL_VIDEODRIVER=dummy it renders offscreen (for headless testing).
// ====================================================================

Program sdl_demo;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Uses
  SysUtils, Classes,
  sdl_Bind, sdl_DosScreen;

Var
  Scr     : TDosScreen;
  AnsFile : String;
  FntFile : String;
  Frames  : LongInt;

Function LoadFile (Const FN: String): String;
Var F : TFileStream;
Begin
  Result := '';
  If Not FileExists(FN) Then Exit;
  F := TFileStream.Create(FN, fmOpenRead);
  Try
    SetLength(Result, F.Size);
    If F.Size > 0 Then F.Read(Result[1], F.Size);
  Finally
    F.Free;
  End;
End;

Procedure DrawBuiltInWfc;
Begin
  Scr.Clear($17);                      // white on blue
  Scr.SetAttr($1F);
  Scr.WriteXY(16, 1, 'M Y S T I C   B B S   -   Waiting for a caller');
  Scr.SetAttr($1E);
  Scr.WriteXY(4, 4,  'Device  : /dev/ttyS0');
  Scr.WriteXY(4, 5,  'Baud    : 115200');
  Scr.WriteXY(4, 6,  'Status  : Waiting for a caller');
  Scr.WriteXY(4, 7,  'Carrier : none');
  Scr.SetAttr($1B);
  Scr.WriteXY(4, 10, 'ALT (C)hat  (S)plit  (E)dit  (H)angup  (J) DOS  (U)pgrade');
  Scr.WriteXY(4, 11, '(G) Offhook Modem   (L) Local Logon   (ESC) Exit Mystic');
End;

Begin
  WriteLn('Mystic SDL DOS-session demo (mystic_sdl)');
  WriteLn('----------------------------------------');

  AnsFile := '../mystic_modem/WFCSCRN.ANS';
  FntFile := 'VGA8X16.FNT';
  If ParamCount >= 1 Then AnsFile := ParamStr(1);
  If ParamCount >= 2 Then FntFile := ParamStr(2);

  Scr := TDosScreen.Create;
  Try
    If Not Scr.LoadFont(FntFile) Then
      WriteLn('Note: font ', FntFile, ' not loaded (glyphs will be blank).');

    If Not Scr.Open('Mystic - DOS Session (SDL)') Then Begin
      WriteLn('SDL not available - cannot open window.');
      WriteLn('  SDL loaded: ', SDLLoaded);
      If Assigned(SDL_GetError) Then WriteLn('  SDL error : ', SDL_GetError);
      WriteLn('This is expected with no SDL library/display; the module builds');
      WriteLn('and degrades gracefully.  Install SDL2 + run with a display to see it.');
      Halt(0);
    End;

    // Prefer the authentic ANSI screen; fall back to a built-in WFC.
    If FileExists(AnsFile) Then Begin
      WriteLn('Rendering ', AnsFile);
      Scr.LoadAnsi(LoadFile(AnsFile));
    End Else
      DrawBuiltInWfc;

    // Render loop.  Headless (dummy driver) just cycles a few frames.
    Frames := 0;
    Repeat
      Scr.Present;
      If Assigned(SDL_Delay) Then SDL_Delay(50);
      Inc(Frames);
    Until (Not Scr.Pump) or (Frames > 200);

    WriteLn('Rendered ', Frames, ' frames.');
  Finally
    Scr.Free;
  End;
End.

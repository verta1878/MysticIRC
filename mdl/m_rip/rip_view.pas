// ====================================================================
// mystic_rip : optional RIPscrip graphics example for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// rip_view - GUI demo: renders a RIPscrip stream through the
// TTermRip class onto a TRipSurface, presents it in an SDL2 window
// (rip_window.pas), and hit-tests mouse clicks against the RIP hot
// regions - a click prints the string the region would send to the
// host, which is the entire RIP button model in miniature.
//
//   rip_view <input.rip>
//   rip_view --sample          (renders rip_render's built-in sample)
//
// SDL2 is runtime-loaded; with no SDL library or display this prints
// a note and exits cleanly (the module builds and degrades gracefully,
// like sdl_demo).  With SDL_VIDEODRIVER=dummy it pumps a few frames
// offscreen for headless testing.  Press any key or close the window
// to exit.
// ====================================================================

Program rip_View;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Uses
  SysUtils,
  Classes,
  rip_Canvas,
  rip_Term,
  rip_Surface,
  rip_Window,
  rip_Sample,
  sdl_Bind;

Function LoadFile (Const FN: String): AnsiString;
Var
  F : TFileStream;
Begin
  Result := '';

  If Not FileExists(FN) Then Exit;

  F := TFileStream.Create(FN, fmOpenRead);
  Try
    SetLength (Result, F.Size);
    If F.Size > 0 Then F.Read (Result[1], F.Size);
  Finally
    F.Free;
  End;
End;

Var
  Surf   : TRipSurface;
  Canvas : TRipCanvas;
  Term   : TTermRip;
  Win    : TRipWindow;
  Data   : AnsiString;
  I      : Integer;
  Frames : LongInt;
Begin
  WriteLn ('Mystic RIP viewer (mystic_sdl)');
  WriteLn ('------------------------------');

  If ParamCount < 1 Then Begin
    WriteLn ('usage: rip_view <input.rip>');
    WriteLn ('       rip_view --sample');
    Halt (1);
  End;

  If ParamStr(1) = '--sample' Then
    Data := SampleRip
  Else Begin
    Data := LoadFile(ParamStr(1));

    If Data = '' Then Begin
      WriteLn ('cannot read ', ParamStr(1));
      Halt (1);
    End;
  End;

  Surf   := TRipSurface.Create;
  Canvas := Surf;
  Term   := TTermRip.Create(Canvas);
  Win    := TRipWindow.Create(Surf);
  Try
    // CR-frame LF-only files; terminate the final line
    If Pos(#13, Data) = 0 Then
      Data := StringReplace(Data, #10, #13, [rfReplaceAll]);

    If (Data <> '') And (Data[Length(Data)] <> #13) Then
      Data := Data + #13;

    I := 1;
    While I <= Length(Data) Do Begin
      If Length(Data) - I + 1 > 16384 Then
        Term.ProcessBuf (Data[I], 16384)
      Else
        Term.ProcessBuf (Data[I], Length(Data) - I + 1);
      Inc (I, 16384);
    End;

    WriteLn ('Mouse regions defined: ', Surf.RegionCount);

    If Not Win.Open('Mystic - RIP Viewer (SDL)') Then Begin
      WriteLn ('SDL not available - cannot open window.');
      WriteLn ('  SDL loaded: ', SDLLoaded);
      If Assigned(SDL_GetError) Then WriteLn ('  SDL error : ', SDL_GetError);
      WriteLn ('This is expected with no SDL library/display; the module builds');
      WriteLn ('and degrades gracefully.  Install SDL2 + run with a display to see it.');
      Halt (0);
    End;

    // render loop; headless (dummy driver) just cycles a few frames
    Frames := 0;

    Repeat
      Win.Present;
      If Assigned(SDL_Delay) Then SDL_Delay (50);
      Inc (Frames);
    Until (Not Win.Pump) or (Frames > 200);

    WriteLn ('Rendered ', Frames, ' frames.');
  Finally
    Win.Free;
    Term.Free;
    Surf.Free;
  End;
End.

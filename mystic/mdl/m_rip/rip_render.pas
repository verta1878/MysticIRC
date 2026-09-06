// ====================================================================
// mystic_rip : optional RIPscrip graphics example for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// rip_render - headless demo: feeds a RIPscrip stream through the REAL
// Mystic-side chain - the TTermRip terminal class (rip_term.pas) rendering onto a TRipSurface - and saves the result
// as a BMP.  No display, no SDL: this is how the pipeline is verified
// in a build container, the same idea as sdl_demo's headless mode.
//
//   rip_render <input.rip> <output.bmp>
//   rip_render --sample <output.bmp>     (built-in sample screen)
//
// It also lists the mouse hot-regions the stream defined, with the
// string each one would send to the host when clicked.
// ====================================================================

Program rip_Render;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Uses
  SysUtils,
  Classes,
  rip_Canvas,
  rip_Term,
  rip_Surface,
  rip_Sample;

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
  Data   : AnsiString;
  OutFN  : String;
  I      : Integer;
Begin
  WriteLn ('Mystic RIP headless renderer (mystic_sdl)');
  WriteLn ('-----------------------------------------');

  If ParamCount < 2 Then Begin
    WriteLn ('usage: rip_render <input.rip> <output.bmp>');
    WriteLn ('       rip_render --sample <output.bmp>');
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

  OutFN := ParamStr(2);

  // lines are CR-framed on the wire; tolerate LF-only files (some
  // editors save .RIP that way) and make sure the final line ends
  { Handle CRLF -> CR }
  Data := StringReplace(Data, #13#10, #13, [rfReplaceAll]);
  { Handle LF-only -> CR }
  If Pos(#13, Data) = 0 Then
    Data := StringReplace(Data, #10, #13, [rfReplaceAll]);

  If (Data <> '') And (Data[Length(Data)] <> #13) Then
    Data := Data + #13;

  Surf   := TRipSurface.Create;
  Canvas := Surf;
  Term   := TTermRip.Create(Canvas);
  Try
    // feed the stream in <=16K slices (ProcessBuf takes a Word count,
    // matching TTermAnsi)
    I := 1;
    While I <= Length(Data) Do Begin
      If Length(Data) - I + 1 > 16384 Then
        Term.ProcessBuf (Data[I], 16384)
      Else
        Term.ProcessBuf (Data[I], Length(Data) - I + 1);
      Inc (I, 16384);
    End;

    Surf.SaveBMP (OutFN);

    WriteLn ('Rendered to ', OutFN, ' (', Surf.Width, 'x', Surf.Height, ')');
    WriteLn ('Mouse regions defined: ', Surf.RegionCount);

    For I := 0 to Surf.RegionCount - 1 Do
      WriteLn ('  region ', I, ': (', Surf.Region(I).X0, ',', Surf.Region(I).Y0,
               ')-(', Surf.Region(I).X1, ',', Surf.Region(I).Y1, ')  sends: ',
               StringReplace(Surf.Region(I).Text, #13, '\r', [rfReplaceAll]));
  Finally
    Term.Free;
    Surf.Free;
  End;
End.

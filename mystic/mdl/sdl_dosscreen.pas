// ====================================================================
// mystic_sdl : optional SDL2 DOS-session front-end for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// sdl_dosscreen - TDosScreen: a classic 80x25 CP437 text screen (a char +
// colour attribute per cell) rendered into an SDL2 window with an 8x16 VGA
// font, giving the authentic full-screen DOS look.  This is the surface the
// modem / BinkP Waiting-For-Caller screens (and, in future, a live session)
// draw onto when the SDL front-end is enabled.
//
// The 16-colour DOS palette is used; attribute byte is standard VGA:
//   bits 0-3 = foreground, bits 4-6 = background, bit 7 = blink (rendered as
//   bright background here).
// ====================================================================

Unit sdl_DosScreen;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  SysUtils,
  sdl_Bind;

Const
  COLS = 80;
  ROWS = 25;
  CW   = 8;         // char width  (px)
  CH   = 16;        // char height (px)

Type
  TCell = Record
    Ch   : Byte;    // CP437 code
    Attr : Byte;    // VGA attribute
  End;

  TDosScreen = Class
  Private
    FWin    : PSDL_Window;
    FRen    : PSDL_Renderer;
    FTex    : PSDL_Texture;
    FFont   : Array[0..4095] of Byte;   // 256 glyphs x 16 rows
    FHaveFont : Boolean;
    FCells  : Array[0..ROWS-1, 0..COLS-1] of TCell;
    FPixels : Array of LongWord;        // COLS*CW x ROWS*CH ARGB
    FReady  : Boolean;
    FCurAttr: Byte;
    Procedure BlitGlyph (Col, Row: LongInt; Ch, Attr: Byte);
  Public
    Constructor Create;
    Destructor  Destroy; Override;

    // Load the 8x16 font file (VGA8X16.FNT, 4096 bytes).  Returns True if ok.
    Function  LoadFont (Const FileName: String): Boolean;

    // Bring up the SDL window (loads SDL if needed).  Returns True on success.
    Function  Open (Const Title: String; Const SdlLib: String = ''): Boolean;
    Procedure Close;

    Procedure Clear (Attr: Byte = $07);
    Procedure SetAttr (Attr: Byte);
    Procedure PutChar (Col, Row: LongInt; C: Char);
    Procedure WriteXY (Col, Row: LongInt; Const S: String);

    // Feed a raw CP437/ANSI byte stream (e.g. a .ANS) into the grid, honouring
    // ESC[...m colour and cursor positioning enough for WFC-style screens.
    Procedure LoadAnsi (Const Data: String);

    // Push the cell grid to the window.
    Procedure Present;

    // Poll: returns False if the user asked to quit (window close / key).
    Function  Pump: Boolean;

    // Debug: write the current pixel buffer to a PPM image (headless proof).
    Procedure DumpPPM (Const FileName: String);

    Property Ready : Boolean Read FReady;
  End;

Implementation

Const
  // 16-colour DOS palette as ARGB.
  PAL : Array[0..15] of LongWord = (
    $FF000000, $FF0000AA, $FF00AA00, $FF00AAAA,
    $FFAA0000, $FFAA00AA, $FFAA5500, $FFAAAAAA,
    $FF555555, $FF5555FF, $FF55FF55, $FF55FFFF,
    $FFFF5555, $FFFF55FF, $FFFFFF55, $FFFFFFFF);

Constructor TDosScreen.Create;
Begin
  Inherited Create;
  FWin := Nil; FRen := Nil; FTex := Nil;
  FReady := False; FHaveFont := False; FCurAttr := $07;
  SetLength(FPixels, (COLS*CW) * (ROWS*CH));
End;

Destructor TDosScreen.Destroy;
Begin
  Close;
  Inherited Destroy;
End;

Function TDosScreen.LoadFont (Const FileName: String): Boolean;
Var
  F : File;
  N : LongInt;
Begin
  Result := False;
  If Not FileExists(FileName) Then Exit;
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;
  BlockRead(F, FFont, SizeOf(FFont), N);
  System.Close(F);
  FHaveFont := (N = SizeOf(FFont));
  Result := FHaveFont;
End;

Function TDosScreen.Open (Const Title: String; Const SdlLib: String): Boolean;
Begin
  Result := False;
  If Not LoadSDL(SdlLib) Then Exit;
  If SDL_Init(SDL_INIT_VIDEO) <> 0 Then Exit;

  FWin := SDL_CreateWindow(PChar(Title),
            Integer(SDL_WINDOWPOS_CENTERED), Integer(SDL_WINDOWPOS_CENTERED),
            COLS*CW, ROWS*CH, SDL_WINDOW_SHOWN);
  If FWin = Nil Then Exit;

  FRen := SDL_CreateRenderer(FWin, -1, 0);
  If FRen = Nil Then Exit;

  FTex := SDL_CreateTexture(FRen, SDL_PIXELFORMAT_ARGB8888,
            SDL_TEXTUREACCESS_STREAMING, COLS*CW, ROWS*CH);
  If FTex = Nil Then Exit;

  Clear($07);
  FReady := True;
  Result := True;
End;

Procedure TDosScreen.Close;
Begin
  If FTex <> Nil Then Begin SDL_DestroyTexture(FTex); FTex := Nil; End;
  If FRen <> Nil Then Begin SDL_DestroyRenderer(FRen); FRen := Nil; End;
  If FWin <> Nil Then Begin SDL_DestroyWindow(FWin); FWin := Nil; End;
  If SDLLoaded and (FReady) Then SDL_Quit;
  FReady := False;
End;

Procedure TDosScreen.Clear (Attr: Byte);
Var R, C : LongInt;
Begin
  For R := 0 to ROWS-1 Do
    For C := 0 to COLS-1 Do Begin
      FCells[R,C].Ch := 32; FCells[R,C].Attr := Attr;
    End;
  FCurAttr := Attr;
End;

Procedure TDosScreen.SetAttr (Attr: Byte);
Begin FCurAttr := Attr; End;

Procedure TDosScreen.PutChar (Col, Row: LongInt; C: Char);
Begin
  If (Col < 0) or (Col >= COLS) or (Row < 0) or (Row >= ROWS) Then Exit;
  FCells[Row,Col].Ch := Byte(C);
  FCells[Row,Col].Attr := FCurAttr;
End;

Procedure TDosScreen.WriteXY (Col, Row: LongInt; Const S: String);
Var I : LongInt;
Begin
  For I := 1 to Length(S) Do PutChar(Col + I - 1, Row, S[I]);
End;

Procedure TDosScreen.BlitGlyph (Col, Row: LongInt; Ch, Attr: Byte);
Var
  gx, gy, px, py, idx : LongInt;
  rowbits : Byte;
  fg, bg  : LongWord;
Begin
  fg := PAL[Attr and $0F];
  bg := PAL[(Attr shr 4) and $07];
  For gy := 0 to CH-1 Do Begin
    rowbits := FFont[(Ch*16 + gy) and $FFF];
    py := Row*CH + gy;
    For gx := 0 to CW-1 Do Begin
      px := Col*CW + gx;
      idx := py*(COLS*CW) + px;
      If (idx >= 0) and (idx < Length(FPixels)) Then Begin
        If (rowbits and ($80 shr gx)) <> 0 Then
          FPixels[idx] := fg
        Else
          FPixels[idx] := bg;
      End;
    End;
  End;
End;

Procedure TDosScreen.Present;
Var R, C : LongInt;
Begin
  If Not FReady Then Exit;
  If FHaveFont Then
    For R := 0 to ROWS-1 Do
      For C := 0 to COLS-1 Do
        BlitGlyph(C, R, FCells[R,C].Ch, FCells[R,C].Attr);

  SDL_UpdateTexture(FTex, Nil, @FPixels[0], (COLS*CW) * 4);
  SDL_RenderClear(FRen);
  SDL_RenderCopy(FRen, FTex, Nil, Nil);
  SDL_RenderPresent(FRen);
End;

Function TDosScreen.Pump: Boolean;
Var Ev : TSDL_Event;
Begin
  Result := True;
  If Not FReady Then Exit;
  While SDL_PollEvent(Ev) <> 0 Do
    If (Ev.EventType = SDL_QUIT_EVENT) or (Ev.EventType = SDL_KEYDOWN) Then
      Result := False;
End;

Procedure TDosScreen.LoadAnsi (Const Data: String);
Var
  I, Col, Row : LongInt;
  C    : Char;
  Seq  : String;
  Semi : LongInt;

  Procedure ApplySGR (Const Params: String);
  Var
    Code : LongInt;
    Cur, Num : String;
  Begin
    Cur := Params + ';';
    While Pos(';', Cur) > 0 Do Begin
      Num := Copy(Cur, 1, Pos(';', Cur)-1);
      Delete(Cur, 1, Pos(';', Cur));
      Code := StrToIntDef(Num, 0);
      Case Code of
        0  : FCurAttr := $07;
        1  : FCurAttr := FCurAttr or $08;                     // bright fg
        30..37 : FCurAttr := (FCurAttr and $F8) or Byte(Code-30);
        40..47 : FCurAttr := (FCurAttr and $8F) or (Byte(Code-40) shl 4);
      End;
    End;
  End;

Begin
  Col := 0; Row := 0;
  I := 1;
  While I <= Length(Data) Do Begin
    C := Data[I];
    If (C = #27) and (I < Length(Data)) and (Data[I+1] = '[') Then Begin
      Inc(I, 2);
      Seq := '';
      While (I <= Length(Data)) and Not (Data[I] in ['A'..'Z','a'..'z']) Do Begin
        Seq := Seq + Data[I]; Inc(I);
      End;
      If I <= Length(Data) Then Begin
        Case Data[I] of
          'm' : ApplySGR(Seq);
          'H','f' : Begin
                      Semi := Pos(';', Seq);
                      If Semi > 0 Then Begin
                        Row := StrToIntDef(Copy(Seq,1,Semi-1),1) - 1;
                        Col := StrToIntDef(Copy(Seq,Semi+1,99),1) - 1;
                      End Else Begin Row := 0; Col := 0; End;
                    End;
          'J' : Clear(FCurAttr);
        End;
        Inc(I);
      End;
    End Else If C = #13 Then Begin Col := 0; Inc(I); End
    Else If C = #10 Then Begin Inc(Row); Inc(I); End
    Else Begin
      PutChar(Col, Row, C); Inc(Col);
      If Col >= COLS Then Begin Col := 0; Inc(Row); End;
      Inc(I);
    End;
    If Row >= ROWS Then Row := ROWS-1;
  End;
End;

Procedure TDosScreen.DumpPPM (Const FileName: String);
Var F: Text; x,y: LongInt; p: LongWord;
Begin
  Assign(F, FileName); Rewrite(F);
  WriteLn(F, 'P3'); WriteLn(F, COLS*CW, ' ', ROWS*CH); WriteLn(F, 255);
  For y := 0 to ROWS*CH-1 Do
    For x := 0 to COLS*CW-1 Do Begin
      p := FPixels[y*(COLS*CW)+x];
      WriteLn(F, (p shr 16) and $FF, ' ', (p shr 8) and $FF, ' ', p and $FF);
    End;
  System.Close(F);
End;

End.

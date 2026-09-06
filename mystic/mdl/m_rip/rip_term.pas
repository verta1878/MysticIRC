// ====================================================================
// mystic_rip : optional RIPscrip graphics example for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//

Unit rip_Term;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

// ====================================================================
// rip_term - TTermRip: a RIPscrip 1.x terminal interpreter.
//
// The direct parallel of TTermAnsi (m_term_ansi.pas): same public
// shape (Create / Process / ProcessBuf / SetReplyClient), same stream-
// interpreter role, hooked the same way (bbs_io / mis / nodespy_term
// feed it a character at a time).  The ONE difference: TTermAnsi
// renders to the text-cell TOutput; TTermRip renders to the graphics
// seam TRipCanvas (m_rip_canvas.pas), because RIP is vector graphics,
// not text cells.  See docs/RIP-INTEGRATION.md.
//
// Parser core derived from ripterm_client_v0 (RipParser.pas), the
// maintainer's clean-room RIP client engine - built once, used twice:
// the standalone client and this class share one engine.
//
// RIPscrip framing (level-1 subset):
//   Commands are introduced by '!' '|', then optional level digits,
//   then a command letter, then fixed-width numeric fields.  Numbers
//   are "mega numbers": 2 base-36 chars each (0-9, A-Z) = 0..1295.
//   Lines end at CR; a trailing '\' joins the next line (so a logical
//   line can exceed 255 chars - line buffers are AnsiString on
//   purpose; do not "simplify" them to ShortString).  Non-command
//   text is written to the canvas as text.
//
// Implemented commands (Phase 1, core drawing/menus subset):
//   c W = m X L R B C O o F @ T M K e E
// Unknown commands are ignored (extensible; Phase 2 adds fills/fonts/
// buttons per docs/RIP-INTEGRATION.md).
// ====================================================================

Interface

Uses
  SysUtils,
  rip_Canvas;

Type
  // reply channel: RIP query commands answer the host by "typing" a
  // string at it.  In-core this is TIOBase; the example keeps it an
  // FPC-native callback so the module has no mdl dependency.
  TRipClient = Procedure (Const S: AnsiString) of Object;

  TTermRip = Class
    Screen   : TRipCanvas;      // render target (graphics seam)
    WasValid : Boolean;
  Private
    Client   : TRipClient;   // reply channel (future query responses)
    LineBuf  : AnsiString;      // current logical line (CR-terminated)
    CurX     : Integer;         // current pen position (RIP 'm')
    CurY     : Integer;
    FVars    : Array[0..99] of Record
                Name  : AnsiString;
                Value : AnsiString;
              End;
    FVarCount: Integer;
    FBasePath: AnsiString;       // base path for ReadScene/FileQuery

    Function    MegaNum (Const S: AnsiString; Var Idx: Integer) : Integer;
    Procedure   HandleCommand (Level: Integer; Cmd: Char; Const Args: AnsiString);
    Procedure   ParseLine (Const Line: AnsiString);
  Public
    Constructor Create (Var Con: TRipCanvas);
    Destructor  Destroy; Override;
    Procedure   Process (Ch: Char);
    Procedure   ProcessBuf (Var Buf; BufLen: Word);
    Procedure   SetReplyClient (Cli: TRipClient);
    Procedure   SetBasePath (Const Path: AnsiString);
    Function    GetVar (Const Name: AnsiString) : AnsiString;
    Procedure   SetVar (Const Name, Value: AnsiString);
  End;

Implementation

Constructor TTermRip.Create (Var Con: TRipCanvas);
Begin
  Inherited Create;

  Screen   := Con;
  Client   := Nil;
  LineBuf  := '';
  CurX     := 0;
  CurY     := 0;
  WasValid := False;
End;

Destructor TTermRip.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TTermRip.SetReplyClient (Cli: TRipClient);
Begin
  Client := Cli;
End;

// mega-number decode: 2 base-36 chars -> integer 0..1295
Function TTermRip.MegaNum (Const S: AnsiString; Var Idx: Integer) : Integer;

  Function Base36 (C: Char) : Integer;
  Begin
    Case C of
      '0'..'9' : Base36 := Ord(C) - Ord('0');
      'A'..'Z' : Base36 := Ord(C) - Ord('A') + 10;
      'a'..'z' : Base36 := Ord(C) - Ord('a') + 10;  // tolerate lowercase
    Else
      Base36 := 0;
    End;
  End;

Begin
  Result := 0;

  If Idx + 1 <= Length(S) Then Begin
    Result := Base36(S[Idx]) * 36 + Base36(S[Idx + 1]);
    Inc (Idx, 2);
  End;
End;

Procedure TTermRip.HandleCommand (Level: Integer; Cmd: Char; Const Args: AnsiString);
Var
  I   : Integer;
  X0  : Integer;
  Y0  : Integer;
  X1  : Integer;
  Y1  : Integer;
  R   : Integer;
  XR  : Integer;
  YR  : Integer;
  Col : Integer;
  Reg : TRipMouseRegion;
  S   : AnsiString;
  PolyPts   : Array[0..50] of Record X, Y: Integer; End;
  SceneFile : File;
  SceneBuf  : Array[0..4095] of Byte;
  SceneRead : LongInt;
Begin
  I := 1;

  If Level = 0 Then
  Case Cmd of
    'c' : Begin  // RIP_COLOR: set draw color (1 field)
            Col := MegaNum(Args, I);
            Screen.SetDrawColor (Col And 15);
          End;
    'W' : Begin  // RIP_WRITE_MODE (1 field): 0=copy 1=xor
            Screen.SetWriteMode (MegaNum(Args, I));
          End;
    '=' : Begin  // RIP_LINE_STYLE: style, user pattern (thickness: Phase 2)
            X0 := MegaNum(Args, I);
            MegaNum (Args, I);  // user pattern field: skip (Phase 2)
            Screen.SetLineStyle (X0, 1);
          End;
    'm' : Begin  // RIP_MOVE: x, y
            X0 := MegaNum(Args, I);
            Y0 := MegaNum(Args, I);

            CurX := X0;
            CurY := Y0;

            Screen.MoveTo (X0, Y0);
          End;
    'X' : Begin  // RIP_PIXEL: x, y (draws in current color)
            X0 := MegaNum(Args, I);
            Y0 := MegaNum(Args, I);

            Screen.Pixel (X0, Y0, 15);
          End;
    'L' : Begin  // RIP_LINE: x0, y0, x1, y1
            X0 := MegaNum(Args, I);
            Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I);
            Y1 := MegaNum(Args, I);

            Screen.Line (X0, Y0, X1, Y1);
          End;
    'R' : Begin  // RIP_RECTANGLE (outline): x0, y0, x1, y1
            X0 := MegaNum(Args, I);
            Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I);
            Y1 := MegaNum(Args, I);

            Screen.Rectangle (X0, Y0, X1, Y1);
          End;
    'B' : Begin  // RIP_BAR (filled): x0, y0, x1, y1
            X0 := MegaNum(Args, I);
            Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I);
            Y1 := MegaNum(Args, I);

            Screen.Bar (X0, Y0, X1, Y1);
          End;
    'C' : Begin  // RIP_CIRCLE: x, y, radius
            X0 := MegaNum(Args, I);
            Y0 := MegaNum(Args, I);
            R  := MegaNum(Args, I);

            Screen.Circle (X0, Y0, R);
          End;
    'O' : Begin  // RIP_OVAL (outline): x, y, xrad, yrad
            X0 := MegaNum(Args, I);
            Y0 := MegaNum(Args, I);
            XR := MegaNum(Args, I);
            YR := MegaNum(Args, I);

            Screen.Oval (X0, Y0, XR, YR);
          End;
    'o' : Begin  // RIP_FILLED_OVAL: x, y, xrad, yrad
            X0 := MegaNum(Args, I);
            Y0 := MegaNum(Args, I);
            XR := MegaNum(Args, I);
            YR := MegaNum(Args, I);

            Screen.FilledOval (X0, Y0, XR, YR);
          End;
    'F' : Begin  // RIP_FILL: x, y, border
            X0  := MegaNum(Args, I);
            Y0  := MegaNum(Args, I);
            Col := MegaNum(Args, I);

            Screen.FloodFill (X0, Y0, Col And 15);
          End;
    '@' : Begin  // RIP_TEXT_XY: x, y, <text>
            X0 := MegaNum(Args, I);
            Y0 := MegaNum(Args, I);
            S  := Copy(Args, I, Length(Args));

            Screen.WriteText (X0, Y0, S);
          End;
    'T' : Begin  // RIP_TEXT: <text> at current position
            S := Copy(Args, I, Length(Args));

            Screen.WriteText (CurX, CurY, S);
          End;
    'M' : Begin  // RIP_MOUSE: num, x0, y0, x1, y1, clk, clr, res(5), <text>
            MegaNum (Args, I);  // num (host button id): skip

            Reg.X0 := MegaNum(Args, I);
            Reg.Y0 := MegaNum(Args, I);
            Reg.X1 := MegaNum(Args, I);
            Reg.Y1 := MegaNum(Args, I);

            // clk + clr are single base-36 chars in the field layout
            If I <= Length(Args) Then Begin
              Reg.Invert := Args[I] = '1';
              Inc (I);
            End Else
              Reg.Invert := False;

            If I <= Length(Args) Then Begin
              Reg.ResetAfter := Args[I] = '1';
              Inc (I);
            End Else
              Reg.ResetAfter := False;

            Inc (I, 5);  // res: 5 reserved chars

            Reg.Text := Copy(Args, I, Length(Args));

            Screen.AddMouseRegion (Reg);
          End;
    'K' : Screen.KillMouseRegions;  // RIP_KILL_MOUSE_FIELDS
    'e' : Screen.Clear;             // RIP_ERASE_WINDOW (simplified)
    'E' : Screen.Clear;             // RIP_ERASE_VIEW (simplified)
    // --- Phase 2 additions (ported from mterm) ---
    'v' : Begin  // RIP_VIEWPORT: x0, y0, x1, y1
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            Screen.SetViewPort (X0, Y0, X1, Y1, True);
          End;
    'w' : Begin  // RIP_TEXT_WINDOW: x0, y0, x1, y1, wrap
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            R  := MegaNum(Args, I);
            Screen.TextWindow (X0, Y0, X1, Y1, R);
          End;
    '*' : Screen.ResetWindows;
    'g' : Begin  // RIP_GOTOXY: x, y
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            Screen.GotoXY (X0, Y0);
          End;
    'H' : Screen.Home;
    '>' : Screen.EraseEOL;
    'Q' : Begin S := Copy(Args, I, Length(Args)); Screen.SetPalette (S[1]); End;
    'a' : Begin  // RIP_ONE_PALETTE: color, ega64
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            Screen.SetOnePalette (X0, Y0);
          End;
    'Y' : Begin  // RIP_FONT_STYLE: font, dir, size
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            R  := MegaNum(Args, I);
            Screen.SetFontStyle (X0, Y0, R);
          End;
    'A' : Begin  // RIP_ARC: x, y, stAng, endAng, radius
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            R  := MegaNum(Args, I);
            Screen.Arc (X0, Y0, X1, Y1, R);
          End;
    'V' : Begin  // RIP_OVAL_ARC: x, y, stAng, endAng, xRad, yRad
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            XR := MegaNum(Args, I); YR := MegaNum(Args, I);
            Screen.OvalArc (X0, Y0, X1, Y1, XR, YR);
          End;
    'I' : Begin  // RIP_PIE_SLICE: x, y, stAng, endAng, radius
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            R  := MegaNum(Args, I);
            Screen.PieSlice (X0, Y0, X1, Y1, R);
          End;
    'i' : Begin  // RIP_OVAL_PIE: x, y, stAng, endAng, xRad, yRad
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            XR := MegaNum(Args, I); YR := MegaNum(Args, I);
            Screen.OvalPieSlice (X0, Y0, X1, Y1, XR, YR);
          End;
    'Z' : Begin  // RIP_BEZIER: x1,y1,x2,y2,x3,y3,x4,y4,count
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            XR := MegaNum(Args, I); YR := MegaNum(Args, I);
            R  := MegaNum(Args, I); Col := MegaNum(Args, I);
            Screen.Bezier (X0, Y0, X1, Y1, XR, YR, R, Col, MegaNum(Args, I));
          End;
    'S' : Begin  // RIP_FILL_STYLE: pattern, color
            X0  := MegaNum(Args, I); Col := MegaNum(Args, I);
            Screen.SetFillStyle (X0, Col);
          End;
    's' : Begin S := Copy(Args, I, 16); Screen.SetFillPattern (S[1], MegaNum(Args, I)); End;
    'P' : Begin  // RIP_POLYGON: npoints, then x,y pairs
            Col := MegaNum(Args, I);
            If (Col >= 2) and (Col <= 50) Then Begin
              For R := 0 to Col - 1 Do Begin
                PolyPts[R].X := MegaNum(Args, I);
                PolyPts[R].Y := MegaNum(Args, I);
              End;
              Screen.Polygon(PolyPts, Col);
            End;
          End;
    'p' : Begin  // RIP_FILL_POLYGON: npoints, then x,y pairs
            Col := MegaNum(Args, I);
            If (Col >= 2) and (Col <= 50) Then Begin
              For R := 0 to Col - 1 Do Begin
                PolyPts[R].X := MegaNum(Args, I);
                PolyPts[R].Y := MegaNum(Args, I);
              End;
              Screen.FillPolygon(PolyPts, Col);
            End;
          End;
    'l' : Begin  // RIP_POLYLINE: npoints, then x,y pairs
            Col := MegaNum(Args, I);
            If (Col >= 2) and (Col <= 50) Then Begin
              For R := 0 to Col - 1 Do Begin
                PolyPts[R].X := MegaNum(Args, I);
                PolyPts[R].Y := MegaNum(Args, I);
              End;
              Screen.Polyline(PolyPts, Col);
            End;
          End;
    '#' : ;  // RIP_NO_MORE: end of scene
  End; // case level 0

  If Level = 1 Then
  Case Cmd of
    'B' : Begin S := Copy(Args, I, Length(Args)); Screen.SetButtonStyle (S[1]); End;
    'U' : Begin  // RIP_BUTTON: x0, y0, x1, y1, params
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            S  := Copy(Args, I, Length(Args));
            Screen.DrawButton (X0, Y0, X1, Y1, S);
          End;
    'T' : Begin  // RIP_BEGIN_TEXT: x, y, w, h
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            Screen.BeginText (X0, Y0, X1, Y1);
          End;
    't' : Begin  // RIP_REGION_TEXT: justify, text
            X0 := MegaNum(Args, I);
            S  := Copy(Args, I, Length(Args));
            Screen.RegionText (X0, S);
          End;
    'E' : Screen.EndText;
    'C' : Begin  // RIP_GET_IMAGE: x0, y0, x1, y1
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            Screen.GetImage (X0, Y0, X1, Y1);
          End;
    'P' : Begin  // RIP_PUT_IMAGE: x, y, mode
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            R  := MegaNum(Args, I);
            Screen.PutImage (X0, Y0, R);
          End;
    'W' : Screen.WriteIcon (Copy(Args, I, Length(Args)));
    'I' : Begin  // RIP_LOAD_ICON: x, y, mode, clip, filename
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            MegaNum(Args, I); MegaNum(Args, I);
            Screen.LoadIcon (X0, Y0, Copy(Args, I, Length(Args)));
          End;
    'G' : Begin  // RIP_COPY_REGION: x0,y0,x1,y1,dx,dy
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            Screen.GetImage (X0, Y0, X1, Y1);
            Screen.PutImage (MegaNum(Args, I), MegaNum(Args, I), 0);
          End;
    'K' : Screen.KillMouseRegions;
    'M' : Begin  // RIP_MOUSE (level 1)
            X0 := MegaNum(Args, I); Y0 := MegaNum(Args, I);
            X1 := MegaNum(Args, I); Y1 := MegaNum(Args, I);
            Reg.X0 := X0; Reg.Y0 := Y0;
            Reg.X1 := X1; Reg.Y1 := Y1;
            Reg.Invert     := Args[I] = '1'; Inc(I);
            MegaNum(Args, I);
            Reg.ResetAfter := Args[I] = '1'; Inc(I);
            MegaNum(Args, I); MegaNum(Args, I); MegaNum(Args, I);
            MegaNum(Args, I); MegaNum(Args, I);
            Reg.Text := Copy(Args, I, Length(Args));
            Screen.AddMouseRegion (Reg);
          End;
    'D' : Begin  // RIP_DEFINE: $name=value
            S := Copy(Args, I, Length(Args));
            If (Length(S) > 0) and (S[1] = '$') Then Begin
              Delete(S, 1, 1);
              R := Pos('=', S);
              If R > 0 Then
                SetVar(Copy(S, 1, R-1), Copy(S, R+1, Length(S)))
              Else
                SetVar(S, '');
            End;
          End;
    'R' : Begin  // RIP_READ_SCENE: load and parse another .rip file
            S := Copy(Args, I, Length(Args));
            If (S <> '') and (FBasePath <> '') Then Begin
              S := FBasePath + S;
              {$I-} Assign(SceneFile, S); Reset(SceneFile, 1); {$I+}
              If IOResult = 0 Then Begin
                While Not Eof(SceneFile) Do Begin
                  BlockRead(SceneFile, SceneBuf, SizeOf(SceneBuf), SceneRead);
                  For R := 0 to SceneRead - 1 Do
                    Process(Chr(SceneBuf[R]));
                End;
                Close(SceneFile);
              End;
            End;
          End;
    'F' : Begin  // RIP_FILE_QUERY: check file, respond with size
            S := Copy(Args, I, Length(Args));
            If (S <> '') and (FBasePath <> '') Then Begin
              S := FBasePath + S;
              {$I-} Assign(SceneFile, S); Reset(SceneFile, 1); {$I+}
              If IOResult = 0 Then Begin
                R := FileSize(SceneFile);
                Close(SceneFile);
                If Assigned(Client) Then
                  Client(IntToStr(R) + #13#10);
              End Else
                If Assigned(Client) Then
                  Client('0' + #13#10);
            End;
          End;
    'Q' : Begin  // RIP_QUERY: respond with terminal ID
            If Assigned(Client) Then
              Client ('RIPSCRIP015400' + #13#10);
          End;
  End; // case level 1
End;

Procedure TTermRip.ParseLine (Const Line: AnsiString);
Var
  P    : Integer;
  J    : Integer;
  Cmd   : Char;
  Level : Integer;
  Args  : AnsiString;
  Text  : AnsiString;
Begin
  If Line = '' Then Exit;

  P := 1;

  While P <= Length(Line) Do Begin
    If (P < Length(Line)) And (Line[P] = '!') And (Line[P + 1] = '|') Then Begin
      Inc (P, 2);

      // optional level digit(s) before the command letter
      Level := 0;
      While (P <= Length(Line)) And (Line[P] In ['0'..'9']) Do Begin
        Level := Level * 10 + (Ord(Line[P]) - Ord('0'));
        Inc (P);
      End;

      If P > Length(Line) Then Exit;

      Cmd := Line[P];
      Inc (P);

      // args run until the next '!|' or end of line
      J := P;

      While (J <= Length(Line)) And
            Not ((J < Length(Line)) And (Line[J] = '!') And (Line[J + 1] = '|')) Do
        Inc (J);

      Args := Copy(Line, P, J - P);

      HandleCommand (Level, Cmd, Args);

      WasValid := True;

      P := J;
    End Else Begin
      // plain text: accumulate until a command starts
      Text := '';

      While (P <= Length(Line)) And
            Not ((P < Length(Line)) And (Line[P] = '!') And (Line[P + 1] = '|')) Do Begin
        Text := Text + Line[P];
        Inc (P);
      End;

      If Text <> '' Then
        Screen.WriteText (CurX, CurY, Text);
    End;
  End;
End;

Procedure TTermRip.Process (Ch: Char);
Begin
  Case Ch of
    #13 : Begin
            // RIP line continuation: trailing '\' joins the next line
            If (Length(LineBuf) > 0) And (LineBuf[Length(LineBuf)] = '\') Then
              Delete (LineBuf, Length(LineBuf), 1)  // keep accumulating
            Else Begin
              ParseLine (LineBuf);
              LineBuf := '';
            End;
          End;
    #10 : ;  // LF ignored (lines are CR-framed)
  Else
    LineBuf := LineBuf + Ch;
  End;
End;

Procedure TTermRip.ProcessBuf (Var Buf; BufLen: Word);
Var
  Count : Word;
  Data  : Array[1..16384] of Char Absolute Buf;
Begin
  For Count := 1 to BufLen Do
    Process (Data[Count]);
End;

Procedure TTermRip.SetBasePath (Const Path: AnsiString);
Begin
  FBasePath := Path;
  If (FBasePath <> '') and (FBasePath[Length(FBasePath)] <> '/') and
     (FBasePath[Length(FBasePath)] <> '\') Then
    FBasePath := FBasePath + '/';
End;

Function TTermRip.GetVar (Const Name: AnsiString) : AnsiString;
Var I: Integer;
Begin
  Result := '';
  For I := 0 to FVarCount - 1 Do
    If FVars[I].Name = Name Then Begin
      Result := FVars[I].Value;
      Exit;
    End;
End;

Procedure TTermRip.SetVar (Const Name, Value: AnsiString);
Var I: Integer;
Begin
  For I := 0 to FVarCount - 1 Do
    If FVars[I].Name = Name Then Begin
      FVars[I].Value := Value;
      Exit;
    End;
  If FVarCount < 100 Then Begin
    FVars[FVarCount].Name  := Name;
    FVars[FVarCount].Value := Value;
    Inc(FVarCount);
  End;
End;

End.

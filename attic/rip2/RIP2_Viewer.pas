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
//
// RIP_Viewer — Display backend for RIP2_Parser
//
// Connects the event-driven RIP2_Parser to TRIPEngine for rendering.
// Override On* methods call the corresponding TRIPEngine API methods.
//
// Usage:
//   Viewer := TRIPViewer.Create;
//   Viewer.LoadFonts('path/to/FONTS');
//   Viewer.ProcessStr(RIPData);
//   Viewer.Engine.SaveBMP('output.bmp');
//   Viewer.Free;
//
// ====================================================================

Unit RIP2_Viewer;

Interface

Uses
  RIP2_Parser,
  rip2api;

Type
  TRIPViewer = Class(TRIPParser)
  Public
    Engine   : TRIPEngine;
    FontPath : String;
    IconPath : String;

    Constructor Create;
    Destructor  Destroy; Override;

    Procedure LoadFonts (Path: String);
    Procedure SetIconPath (Path: String);

  Protected
    Procedure OnTextWindow    (X0, Y0, X1, Y1, Wrap, Size: Integer); Override;
    Procedure OnViewport      (X0, Y0, X1, Y1: Integer); Override;
    Procedure OnResetWindows; Override;
    Procedure OnEraseWindow; Override;
    Procedure OnEraseView; Override;
    Procedure OnGotoXY        (X, Y: Integer); Override;
    Procedure OnHome; Override;
    Procedure OnEraseEOL; Override;
    Procedure OnColor         (Color: Integer); Override;
    Procedure OnSetPalette    (Pal: Array of Integer); Override;
    Procedure OnOnePalette    (Color, Value: Integer); Override;
    Procedure OnWriteMode     (Mode: Integer); Override;
    Procedure OnMove          (X, Y: Integer); Override;
    Procedure OnTextCmd       (S: String); Override;
    Procedure OnTextXY        (X, Y: Integer; S: String); Override;
    Procedure OnFontStyle     (Font, Dir, Size, Res: Integer); Override;
    Procedure OnPixel         (X, Y: Integer); Override;
    Procedure OnLine          (X0, Y0, X1, Y1: Integer); Override;
    Procedure OnRectangle     (X0, Y0, X1, Y1: Integer); Override;
    Procedure OnBar           (X0, Y0, X1, Y1: Integer); Override;
    Procedure OnCircle        (X, Y, Radius: Integer); Override;
    Procedure OnOval          (X, Y, RadX, RadY: Integer); Override;
    Procedure OnFilledOval    (X, Y, RadX, RadY: Integer); Override;
    Procedure OnArc           (X, Y, StartAng, EndAng, Radius: Integer); Override;
    Procedure OnOvalArc       (X, Y, StartAng, EndAng, RadX, RadY: Integer); Override;
    Procedure OnPieSlice      (X, Y, StartAng, EndAng, Radius: Integer); Override;
    Procedure OnOvalPieSlice  (X, Y, StartAng, EndAng, RadX, RadY: Integer); Override;
    Procedure OnBezier        (X1,Y1,X2,Y2,X3,Y3,X4,Y4,Cnt: Integer); Override;
    Procedure OnFill          (X, Y, Border: Integer); Override;
    Procedure OnLineStyle     (Style, UserPat, Thick: Integer); Override;
    Procedure OnFillStyle     (Pattern, Color: Integer); Override;
    Procedure OnFillPattern   (C1,C2,C3,C4,C5,C6,C7,C8, Color: Integer); Override;
    Procedure OnMouseRegion   (Num, X0, Y0, X1, Y1, Clk, Clr, Res: Integer; Text: String); Override;
    Procedure OnKillMouse; Override;
    Procedure OnLoadIcon      (X, Y, Mode, Clipboard, Res: Integer; FN: String); Override;
    Procedure OnCopyRegion    (X0, Y0, X1, Y1, Res, Dest: Integer); Override;
    Procedure OnNoMore; Override;

    // Phase 7: Level 1 event overrides
    Procedure OnBeginText     (X1, Y1, X2, Y2, Res: Integer); Override;
    Procedure OnRegionText    (Justify: Integer; S: String); Override;
    Procedure OnEndText; Override;
    Procedure OnGetImage      (X0, Y0, X1, Y1, Res: Integer); Override;
    Procedure OnPutImage      (X, Y, Mode, Clipboard, Res: Integer; FN: String); Override;
    Procedure OnWriteIcon     (Res: Integer; FN: String); Override;
    Procedure OnButtonStyle   (Wid, Hgt, Orient, Flags: Integer); Override;
    Procedure OnButton        (X0, Y0, X1, Y1, HotKey, Flags: Integer); Override;
    Procedure OnDefine        (Flags, Res: Integer; Text: String); Override;
    Procedure OnReadScene     (Res: Integer; FN: String); Override;
    Procedure OnFileQuery     (Mode, Res: Integer; FN: String); Override;
  End;

Implementation

Constructor TRIPViewer.Create;
Begin
  Inherited Create;

  Engine   := TRIPEngine.Create;
  FontPath := '';
  IconPath := '';
End;

Destructor TRIPViewer.Destroy;
Begin
  Engine.Free;

  Inherited Destroy;
End;

Procedure TRIPViewer.LoadFonts (Path: String);

  Function TryLoad (Slot: Byte; FN: String) : Boolean;
  Var
    F : File;
  Begin
    Assign(F, FN);
    {$I-} System.Reset(F, 1); {$I+}
    If IOResult = 0 Then Begin
      Close(F);
      Result := Engine.LoadCHR(Slot, FN);
    End Else
      Result := False;
  End;

Begin
  FontPath := Path;
  If (Length(FontPath) > 0) and (FontPath[Length(FontPath)] <> '/') and
     (FontPath[Length(FontPath)] <> '\') Then
    FontPath := FontPath + '/';

  TryLoad(1, FontPath + 'TRIP.CHR');
  TryLoad(2, FontPath + 'LITT.CHR');
  TryLoad(3, FontPath + 'SANS.CHR');
  TryLoad(4, FontPath + 'GOTH.CHR');
  TryLoad(5, FontPath + 'SCRI.CHR');
  TryLoad(6, FontPath + 'SIMP.CHR');
  TryLoad(7, FontPath + 'TSCR.CHR');
  TryLoad(8, FontPath + 'LCOM.CHR');
  TryLoad(9, FontPath + 'EURO.CHR');
  TryLoad(10, FontPath + 'BOLD.CHR');
End;

Procedure TRIPViewer.SetIconPath (Path: String);
Begin
  IconPath := Path;
  If (Length(IconPath) > 0) and (IconPath[Length(IconPath)] <> '/') and
     (IconPath[Length(IconPath)] <> '\') Then
    IconPath := IconPath + '/';
End;

// ---- Level 0: Screen ----

Procedure TRIPViewer.OnTextWindow (X0, Y0, X1, Y1, Wrap, Size: Integer);
Begin
  Engine.SetTextWindow(X0, Y0, X1, Y1, Size);
End;

Procedure TRIPViewer.OnViewport (X0, Y0, X1, Y1: Integer);
Begin
  Engine.SetViewPort(X0, Y0, X1, Y1, True);
End;

Procedure TRIPViewer.OnResetWindows;
Begin
  Engine.SetViewPort(0, 0, 639, 349, True);
  Engine.SetTextWindow(0, 0, 79, 42, 0);
End;

Procedure TRIPViewer.OnEraseWindow;
Begin
  Engine.ClearScreen;
End;

Procedure TRIPViewer.OnEraseView;
Begin
  Engine.ClearViewport;
End;

Procedure TRIPViewer.OnGotoXY (X, Y: Integer);
Begin
  Engine.MoveTo(X, Y);
End;

Procedure TRIPViewer.OnHome;
Begin
  Engine.MoveTo(0, 0);
End;

Procedure TRIPViewer.OnEraseEOL;
Var
  X : SmallInt;
Begin
  For X := Engine.GetX to 639 Do
    Engine.PutPixel(X, Engine.GetY, 0);
End;

// ---- Level 0: Color ----

Procedure TRIPViewer.OnColor (Color: Integer);
Begin
  Engine.SetColor(Color);
End;

Procedure TRIPViewer.OnSetPalette (Pal: Array of Integer);
Var
  I    : Integer;
  RPal : TRIPPalette;
Begin
  For I := 0 to 15 Do
    RPal[I] := Pal[I];
  Engine.SetAllPalette(RPal);
End;

Procedure TRIPViewer.OnOnePalette (Color, Value: Integer);
Begin
  Engine.SetPalette(Color, Value);
End;

Procedure TRIPViewer.OnWriteMode (Mode: Integer);
Begin
  Engine.SetWriteMode(Mode);
End;

// ---- Level 0: Position / Text ----

Procedure TRIPViewer.OnMove (X, Y: Integer);
Begin
  Engine.MoveTo(X, Y);
End;

Procedure TRIPViewer.OnTextCmd (S: String);
Begin
  // Phase 1: handle action text variables
  If S = '$SAVE$' Then Begin Engine.SaveScreen(0); Exit; End;
  If S = '$RESTORE$' Then Begin Engine.RestoreScreen(0); Exit; End;
  If S = '$STW$' Then Begin Engine.SaveTextWin; Exit; End;
  If S = '$RTW$' Then Begin Engine.RestoreTextWin; Exit; End;
  If S = '$SCB$' Then Begin Engine.SaveClip; Exit; End;
  If S = '$RCB$' Then Begin Engine.RestoreClip; Exit; End;
  If S = '$SMF$' Then Begin Engine.SaveMouseAll; Exit; End;
  If S = '$RMF$' Then Begin Engine.RestoreMouseAll; Exit; End;
  If S = '$SAVEALL$' Then Begin Engine.SaveAll; Exit; End;
  If S = '$RESTOREALL$' Then Begin Engine.RestoreAll; Exit; End;
  If S = '$RESET$' Then Begin Engine.Reset; Exit; End;

  // Phase 5: hotkey and tab control
  If S = '$HKEYON$' Then Begin Engine.HotKeysEnabled := True; Exit; End;
  If S = '$HKEYOFF$' Then Begin Engine.HotKeysEnabled := False; Exit; End;
  If S = '$TABON$' Then Begin Engine.TabEnabled := True; Exit; End;
  If S = '$TABOFF$' Then Begin Engine.TabEnabled := False; Engine.UnfocusField; Exit; End;

  // $SAVE0$ through $SAVE9$
  If (Length(S) = 7) and (Copy(S, 1, 5) = '$SAVE') and (S[7] = '$') and
     (S[6] >= '0') and (S[6] <= '9') Then Begin
    Engine.SaveScreen(Ord(S[6]) - Ord('0'));
    Exit;
  End;

  // $RESTORE0$ through $RESTORE9$
  If (Length(S) = 10) and (Copy(S, 1, 8) = '$RESTORE') and (S[10] = '$') and
     (S[9] >= '0') and (S[9] <= '9') Then Begin
    Engine.RestoreScreen(Ord(S[9]) - Ord('0'));
    Exit;
  End;

  Engine.OutText(S);
End;

Procedure TRIPViewer.OnTextXY (X, Y: Integer; S: String);
Begin
  Engine.OutTextXY(X, Y, S);
End;

Procedure TRIPViewer.OnFontStyle (Font, Dir, Size, Res: Integer);
Begin
  Engine.SetTextStyle(Font, Dir, Size);
End;

// ---- Level 0: Drawing ----

Procedure TRIPViewer.OnPixel (X, Y: Integer);
Begin
  Engine.PutPixel(X, Y, Engine.GetColor);
End;

Procedure TRIPViewer.OnLine (X0, Y0, X1, Y1: Integer);
Begin
  Engine.Line(X0, Y0, X1, Y1);
End;

Procedure TRIPViewer.OnRectangle (X0, Y0, X1, Y1: Integer);
Begin
  Engine.Rectangle(X0, Y0, X1, Y1);
End;

Procedure TRIPViewer.OnBar (X0, Y0, X1, Y1: Integer);
Begin
  Engine.Bar(X0, Y0, X1, Y1);
End;

Procedure TRIPViewer.OnCircle (X, Y, Radius: Integer);
Begin
  Engine.Circle(X, Y, Radius);
End;

Procedure TRIPViewer.OnOval (X, Y, RadX, RadY: Integer);
Begin
  Engine.Ellipse(X, Y, 0, 360, RadX, RadY);
End;

Procedure TRIPViewer.OnFilledOval (X, Y, RadX, RadY: Integer);
Begin
  Engine.FillEllipse(X, Y, RadX, RadY);
End;

Procedure TRIPViewer.OnArc (X, Y, StartAng, EndAng, Radius: Integer);
Begin
  Engine.Arc(X, Y, StartAng, EndAng, Radius);
End;

Procedure TRIPViewer.OnOvalArc (X, Y, StartAng, EndAng, RadX, RadY: Integer);
Begin
  Engine.Ellipse(X, Y, StartAng, EndAng, RadX, RadY);
End;

Procedure TRIPViewer.OnPieSlice (X, Y, StartAng, EndAng, Radius: Integer);
Begin
  Engine.PieSlice(X, Y, StartAng, EndAng, Radius);
End;

Procedure TRIPViewer.OnOvalPieSlice (X, Y, StartAng, EndAng, RadX, RadY: Integer);
Begin
  Engine.Sector(X, Y, StartAng, EndAng, RadX, RadY);
End;

Procedure TRIPViewer.OnBezier (X1,Y1,X2,Y2,X3,Y3,X4,Y4,Cnt: Integer);
Begin
  Engine.DrawBezier(X1, Y1, X2, Y2, X3, Y3, X4, Y4, Cnt);
End;

Procedure TRIPViewer.OnFill (X, Y, Border: Integer);
Begin
  Engine.FloodFill(X, Y, Border);
End;

// ---- Level 0: Style ----

Procedure TRIPViewer.OnLineStyle (Style, UserPat, Thick: Integer);
Begin
  Engine.SetLineStyle(Style, UserPat, Thick);
End;

Procedure TRIPViewer.OnFillStyle (Pattern, Color: Integer);
Begin
  Engine.SetFillStyle(Pattern, Color);
End;

Procedure TRIPViewer.OnFillPattern (C1,C2,C3,C4,C5,C6,C7,C8, Color: Integer);
Var
  Pat : TRIPFillPattern;
Begin
  Pat[0] := C1; Pat[1] := C2; Pat[2] := C3; Pat[3] := C4;
  Pat[4] := C5; Pat[5] := C6; Pat[6] := C7; Pat[7] := C8;
  Engine.SetFillPattern(Pat, Color);
End;

// ---- Level 1: Mouse / Icons ----

Procedure TRIPViewer.OnMouseRegion (Num, X0, Y0, X1, Y1, Clk, Clr, Res: Integer; Text: String);
Begin
  Engine.AddMouseField(X0, Y0, X1, Y1, Text, '');
End;

Procedure TRIPViewer.OnKillMouse;
Begin
  Engine.KillAllMouseFields;
End;

Procedure TRIPViewer.OnLoadIcon (X, Y, Mode, Clipboard, Res: Integer; FN: String);
Begin
  Engine.LoadIcon(IconPath + FN, X, Y, Mode);
End;

Procedure TRIPViewer.OnCopyRegion (X0, Y0, X1, Y1, Res, Dest: Integer);
Begin
  Engine.CopyRegion(X0, Y0, X1, Y1, Dest);
End;

Procedure TRIPViewer.OnNoMore;
Begin
  { no-op — marks end of RIP sequence }
End;

// ---- Phase 7: Level 1 event handlers ----

Procedure TRIPViewer.OnBeginText (X1, Y1, X2, Y2, Res: Integer);
Begin
  Engine.MoveTo(X1, Y1);
End;

Procedure TRIPViewer.OnRegionText (Justify: Integer; S: String);
Begin
  Engine.OutText(S);
  Engine.MoveTo(Engine.GetX, Engine.GetY + Engine.GetSysFontH);
End;

Procedure TRIPViewer.OnEndText;
Begin
  { no-op — marks end of text block }
End;

Procedure TRIPViewer.OnGetImage (X0, Y0, X1, Y1, Res: Integer);
Var
  Sz : LongInt;
Begin
  If Engine.Clipboard <> Nil Then
    FreeMem(Engine.Clipboard, Engine.ClipSize);
  Sz := Engine.ImageSize(X0, Y0, X1, Y1);
  GetMem(Engine.Clipboard, Sz);
  Engine.ClipSize := Sz;
  Engine.ClipW := X1 - X0 + 1;
  Engine.ClipH := Y1 - Y0 + 1;
  Engine.GetImage(X0, Y0, X1, Y1, Engine.Clipboard^);
End;

Procedure TRIPViewer.OnPutImage (X, Y, Mode, Clipboard, Res: Integer; FN: String);
Begin
  If Engine.Clipboard <> Nil Then
    Engine.PutImage(X, Y, Engine.Clipboard^, Mode);
End;

Procedure TRIPViewer.OnWriteIcon (Res: Integer; FN: String);
Begin
  { clipboard-to-file save — deferred }
End;

Procedure TRIPViewer.OnButtonStyle (Wid, Hgt, Orient, Flags: Integer);
Var
  Style : TRIPButtonStyle;
Begin
  FillChar(Style, SizeOf(Style), 0);
  Style.Width  := Wid;
  Style.Height := Hgt;
  Style.Orient := Orient;
  Style.Flags  := Flags;
  Engine.SetButtonStyle(Style);
End;

Procedure TRIPViewer.OnButton (X0, Y0, X1, Y1, HotKey, Flags: Integer);
Begin
  Engine.DrawButton(X0, Y0, X1, Y1, '', '');
End;

Procedure TRIPViewer.OnDefine (Flags, Res: Integer; Text: String);
Var
  P    : Integer;
  Name : String;
Begin
  // Parse name from Text (name,size:?question?default)
  P := 1;
  Name := '';
  While (P <= Length(Text)) and (Text[P] <> ',') and (Text[P] <> ':') Do Begin
    Name := Name + Text[P];
    Inc(P);
  End;
  Engine.DefineVar(Name, '', (Flags AND 1) <> 0, (Flags AND 2) <> 0);
End;

Procedure TRIPViewer.OnReadScene (Res: Integer; FN: String);
Begin
  Engine.LoadScene(IconPath + FN);
End;

Procedure TRIPViewer.OnFileQuery (Mode, Res: Integer; FN: String);
Begin
  Engine.FileQuery(IconPath + FN, Mode);
End;

End.

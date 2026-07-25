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
// RIPscrip v1.54 Parser
//
// Parses Remote Imaging Protocol script commands per the RIPscrip
// v1.54 specification (TeleGrafix Communications, July 1993).
//
// This unit handles protocol parsing only — decoding the !| command
// stream, MegaNum base-36 values, line continuation, and escape
// sequences.  It does NOT render graphics.  Instead it calls virtual
// event methods (OnLine, OnRectangle, OnCircle, etc.) that a display
// backend can override.
//
// Without a display backend, the parser silently consumes RIP codes
// so the user never sees raw !|L0000... sequences.  A text fallback
// is provided: plain text between RIP commands is passed through to
// OnText so it can be displayed normally (e.g. via ANSI terminal).
//
// References:
//   RIPscrip v1.54 Protocol Specification  (docs/rip/)
//   RIPscrip v3 Whitepaper                 (docs/rip/)
//
// Based on TTermAnsi state machine pattern from m_Term_Ansi.pas.
// ====================================================================

{$I M_OPS.PAS}

Unit RIP_Parser;

Interface

Const
  RIPMaxParams = 64;
  RIPMaxCmd    = 4096;

Type
  TRIPCommand = Record
    Level   : Byte;          { 0 = level 0, 1 = level 1, 9 = level 9 }
    SubLevel : Byte;         { sub-level digit, 0 if none             }
    Cmd     : Char;          { command character                      }
    Data    : String;        { raw parameter string after cmd char    }
  End;

  TRIPParser = Class
    Active   : Boolean;      { TRUE if RIP mode is active             }
  Private
    State    : Byte;         { parser state machine                   }
    CmdBuf   : String;       { accumulating command string            }
    CurCmd   : TRIPCommand;  { current command being parsed           }
    LineCont : Boolean;      { line continuation active               }

    Procedure ResetState;
    Procedure ParseCommand;
    Procedure DispatchCommand;
    Procedure DoSetPalette (D: String);

    { MegaNum decoding }
    Function  MegaVal     (Ch: Char) : Integer;
    Function  DecodeMega  (S: String; Pos, Width: Integer) : Integer;
  Protected
    { Override these in a display backend }
    Procedure OnText          (S: String); Virtual;
    Procedure OnTextWindow    (X0, Y0, X1, Y1, Wrap, Size: Integer); Virtual;
    Procedure OnViewport      (X0, Y0, X1, Y1: Integer); Virtual;
    Procedure OnResetWindows; Virtual;
    Procedure OnEraseWindow; Virtual;
    Procedure OnEraseView; Virtual;
    Procedure OnGotoXY        (X, Y: Integer); Virtual;
    Procedure OnHome; Virtual;
    Procedure OnEraseEOL; Virtual;
    Procedure OnColor         (Color: Integer); Virtual;
    Procedure OnSetPalette    (Pal: Array of Integer); Virtual;
    Procedure OnOnePalette    (Color, Value: Integer); Virtual;
    Procedure OnWriteMode     (Mode: Integer); Virtual;
    Procedure OnMove          (X, Y: Integer); Virtual;
    Procedure OnTextCmd       (S: String); Virtual;
    Procedure OnTextXY        (X, Y: Integer; S: String); Virtual;
    Procedure OnFontStyle     (Font, Dir, Size, Res: Integer); Virtual;
    Procedure OnPixel         (X, Y: Integer); Virtual;
    Procedure OnLine          (X0, Y0, X1, Y1: Integer); Virtual;
    Procedure OnRectangle     (X0, Y0, X1, Y1: Integer); Virtual;
    Procedure OnBar           (X0, Y0, X1, Y1: Integer); Virtual;
    Procedure OnCircle        (X, Y, Radius: Integer); Virtual;
    Procedure OnOval          (X, Y, RadX, RadY: Integer); Virtual;
    Procedure OnFilledOval    (X, Y, RadX, RadY: Integer); Virtual;
    Procedure OnArc           (X, Y, StartAng, EndAng, Radius: Integer); Virtual;
    Procedure OnOvalArc       (X, Y, StartAng, EndAng, RadX, RadY: Integer); Virtual;
    Procedure OnPieSlice      (X, Y, StartAng, EndAng, Radius: Integer); Virtual;
    Procedure OnOvalPieSlice  (X, Y, StartAng, EndAng, RadX, RadY: Integer); Virtual;
    Procedure OnBezier        (X1,Y1,X2,Y2,X3,Y3,X4,Y4,Cnt: Integer); Virtual;
    Procedure OnFill          (X, Y, Border: Integer); Virtual;
    Procedure OnLineStyle     (Style, UserPat, Thick: Integer); Virtual;
    Procedure OnFillStyle     (Pattern, Color: Integer); Virtual;
    Procedure OnFillPattern   (C1,C2,C3,C4,C5,C6,C7,C8, Color: Integer); Virtual;
    Procedure OnMouseRegion   (Num, X0, Y0, X1, Y1, Clk, Clr, Res: Integer; Text: String); Virtual;
    Procedure OnKillMouse; Virtual;
    Procedure OnBeginText     (X1, Y1, X2, Y2, Res: Integer); Virtual;
    Procedure OnRegionText    (Justify: Integer; S: String); Virtual;
    Procedure OnEndText; Virtual;
    Procedure OnGetImage      (X0, Y0, X1, Y1, Res: Integer); Virtual;
    Procedure OnPutImage      (X, Y, Mode, Clipboard, Res: Integer; FN: String); Virtual;
    Procedure OnWriteIcon     (Res: Integer; FN: String); Virtual;
    Procedure OnLoadIcon      (X, Y, Mode, Clipboard, Res: Integer; FN: String); Virtual;
    Procedure OnButtonStyle   (Wid, Hgt, Orient, Flags: Integer); Virtual;
    Procedure OnButton        (X0, Y0, X1, Y1, HotKey, Flags: Integer); Virtual;
    Procedure OnDefine        (Flags, Res: Integer; Text: String); Virtual;
    Procedure OnQuery         (Mode, Res: Integer; Text: String); Virtual;
    Procedure OnCopyRegion    (X0, Y0, X1, Y1, Res, Dest: Integer); Virtual;
    Procedure OnReadScene     (Res: Integer; FN: String); Virtual;
    Procedure OnFileQuery     (Mode, Res: Integer; FN: String); Virtual;
    Procedure OnNoMore; Virtual;
    Procedure OnUnknown       (Var Cmd: TRIPCommand); Virtual;
  Public
    Constructor Create;
    Destructor  Destroy; Override;
    Procedure   Process    (Ch: Char);
    Procedure   ProcessBuf (Var Buf; BufLen: Word);
    Procedure   ProcessStr (S: String);
    Procedure   Reset;
  End;

Implementation

Uses
  m_Strings;

// ====================================================================
// MegaNum base-36 decoding
//
// RIPscrip uses "MegaNums" — base-36 digits (0-9, A-Z) where each
// digit represents 0-35.  A 2-digit MegaNum encodes 0..1295.
// Coordinates are typically 2 digits (0..1295), colors 2 digits,
// angles 2 digits, etc.
// ====================================================================

Function TRIPParser.MegaVal (Ch: Char) : Integer;
Begin
  Case Ch of
    '0'..'9' : Result := Ord(Ch) - Ord('0');
    'A'..'Z' : Result := Ord(Ch) - Ord('A') + 10;
    'a'..'z' : Result := Ord(Ch) - Ord('a') + 10;
  Else
    Result := 0;
  End;
End;

Function TRIPParser.DecodeMega (S: String; Pos, Width: Integer) : Integer;
Var
  I : Integer;
Begin
  Result := 0;

  For I := 0 to Width - 1 Do
    If Pos + I <= Length(S) Then
      Result := Result * 36 + MegaVal(S[Pos + I]);
End;

// ====================================================================

Constructor TRIPParser.Create;
Begin
  Inherited Create;

  Active   := True;
  LineCont := False;

  ResetState;
End;

Destructor TRIPParser.Destroy;
Begin
  Inherited Destroy;
End;

Procedure TRIPParser.ResetState;
Begin
  State  := 0;
  CmdBuf := '';

  FillChar (CurCmd, SizeOf(CurCmd), 0);
End;

Procedure TRIPParser.Reset;
Begin
  ResetState;
  LineCont := False;
End;

// ====================================================================
// State machine
//
// State 0 : Normal text.  Looking for '!' at column 0 (or #1/#2
//           anywhere) to start a RIP sequence.
// State 1 : Got '!' — expecting '|'
// State 2 : Got '!|' — reading level digits and command char
// State 3 : Reading command parameters until end of line
// ====================================================================

Procedure TRIPParser.Process (Ch: Char);
Begin
  If Not Active Then Begin
    OnText(Ch);
    Exit;
  End;

  Case State of
    0 : Case Ch of
          '!' : State := 1;

          { SOH/STX can start RIP mid-line (host-only) }
          #1,
          #2  : Begin
                  State  := 1;
                End;

          #13 : Begin
                  If LineCont Then
                    LineCont := False
                  Else
                    OnText(Ch);
                End;

          #10 : Begin
                  If LineCont Then Begin
                    { line continuation: !| command continues on next line }
                    LineCont := False;
                    State    := 3;
                  End Else
                    OnText(Ch);
                End;
        Else
          OnText(Ch);
        End;

    1 : If Ch = '|' Then Begin
          State  := 2;
          CmdBuf := '';
          CurCmd.Level    := 0;
          CurCmd.SubLevel := 0;
          CurCmd.Cmd      := #0;
          CurCmd.Data     := '';
        End Else Begin
          { not a RIP sequence — emit the '!' we ate }
          OnText('!');
          State := 0;
          Process(Ch);  { re-process this character }
        End;

    2 : Begin
          { level digits: 0-9 before the command character }
          If (Ch >= '0') and (Ch <= '9') Then Begin
            If CurCmd.Cmd = #0 Then Begin
              { first digit = level }
              If CurCmd.Level = 0 Then
                CurCmd.Level := Ord(Ch) - Ord('0')
              Else
                CurCmd.SubLevel := Ord(Ch) - Ord('0');
            End;
          End Else Begin
            { this is the command character }
            CurCmd.Cmd := Ch;
            State      := 3;
            CmdBuf     := '';
          End;
        End;

    3 : Begin
          Case Ch of
            #13 : ; { ignore CR in command stream }

            #10 : Begin
                    { end of line — finish command unless line continuation }
                    If (Length(CmdBuf) > 0) and (CmdBuf[Length(CmdBuf)] = '\') Then Begin
                      { line continuation: remove trailing backslash }
                      Dec(CmdBuf[0]);
                      LineCont := True;
                      State    := 0;
                    End Else Begin
                      CurCmd.Data := CmdBuf;
                      DispatchCommand;
                      ResetState;
                    End;
                  End;
          Else
            { accumulate parameter data }
            If Length(CmdBuf) < RIPMaxCmd Then
              CmdBuf := CmdBuf + Ch;
          End;
        End;
  End;
End;

Procedure TRIPParser.ProcessBuf (Var Buf; BufLen: Word);
Var
  Count : Word;
  Data  : Array[1..16384] of Char Absolute Buf;
Begin
  For Count := 1 to BufLen Do
    Process(Data[Count]);
End;

Procedure TRIPParser.ProcessStr (S: String);
Var
  I : Integer;
Begin
  For I := 1 to Length(S) Do
    Process(S[I]);
End;

// ====================================================================
// Command parsing helpers
// ====================================================================

Procedure TRIPParser.ParseCommand;
Begin
  { placeholder — DispatchCommand handles everything }
End;

Procedure TRIPParser.DoSetPalette (D: String);
Var
  Pal : Array[0..15] of Integer;
  I   : Integer;
Begin
  For I := 0 to 15 Do
    Pal[I] := DecodeMega(D, 1 + I*2, 2);

  OnSetPalette(Pal);
End;

// ====================================================================
// Command dispatch
//
// Decodes MegaNum parameters and calls the appropriate On* handler.
// All coordinates are 2-digit MegaNums unless noted otherwise.
// ====================================================================

Procedure TRIPParser.DispatchCommand;
Var
  D : String;
Begin
  D := CurCmd.Data;

  Case CurCmd.Level of
    0 : Case CurCmd.Cmd of
          { ---- Text / Window ---- }
          'w' : If Length(D) >= 12 Then
                  OnTextWindow (DecodeMega(D,1,2), DecodeMega(D,3,2),
                                DecodeMega(D,5,2), DecodeMega(D,7,2),
                                DecodeMega(D,9,2), DecodeMega(D,11,2));

          'v' : If Length(D) >= 8 Then
                  OnViewport (DecodeMega(D,1,2), DecodeMega(D,3,2),
                              DecodeMega(D,5,2), DecodeMega(D,7,2));

          '*' : OnResetWindows;
          'e' : OnEraseWindow;
          'E' : OnEraseView;

          'g' : If Length(D) >= 4 Then
                  OnGotoXY (DecodeMega(D,1,2), DecodeMega(D,3,2));

          'H' : OnHome;
          '>' : OnEraseEOL;

          { ---- Color / Palette ---- }
          'c' : If Length(D) >= 2 Then
                  OnColor (DecodeMega(D,1,2));

          'Q' : If Length(D) >= 32 Then
                  DoSetPalette(D);

          'a' : If Length(D) >= 4 Then
                  OnOnePalette (DecodeMega(D,1,2), DecodeMega(D,3,2));

          'W' : If Length(D) >= 2 Then
                  OnWriteMode (DecodeMega(D,1,2));

          { ---- Drawing position ---- }
          'm' : If Length(D) >= 4 Then
                  OnMove (DecodeMega(D,1,2), DecodeMega(D,3,2));

          { ---- Text commands ---- }
          'T' : OnTextCmd (D);

          '@' : If Length(D) >= 4 Then
                  OnTextXY (DecodeMega(D,1,2), DecodeMega(D,3,2),
                            Copy(D, 5, Length(D)));

          'Y' : If Length(D) >= 8 Then
                  OnFontStyle (DecodeMega(D,1,2), DecodeMega(D,3,2),
                               DecodeMega(D,5,2), DecodeMega(D,7,2));

          { ---- Pixel / Line ---- }
          'X' : If Length(D) >= 4 Then
                  OnPixel (DecodeMega(D,1,2), DecodeMega(D,3,2));

          'L' : If Length(D) >= 8 Then
                  OnLine (DecodeMega(D,1,2), DecodeMega(D,3,2),
                          DecodeMega(D,5,2), DecodeMega(D,7,2));

          { ---- Shapes ---- }
          'R' : If Length(D) >= 8 Then
                  OnRectangle (DecodeMega(D,1,2), DecodeMega(D,3,2),
                               DecodeMega(D,5,2), DecodeMega(D,7,2));

          'B' : If Length(D) >= 8 Then
                  OnBar (DecodeMega(D,1,2), DecodeMega(D,3,2),
                         DecodeMega(D,5,2), DecodeMega(D,7,2));

          'C' : If Length(D) >= 6 Then
                  OnCircle (DecodeMega(D,1,2), DecodeMega(D,3,2),
                            DecodeMega(D,5,2));

          'O' : If Length(D) >= 12 Then
                  OnOvalArc (DecodeMega(D,1,2), DecodeMega(D,3,2),
                             DecodeMega(D,5,2), DecodeMega(D,7,2),
                             DecodeMega(D,9,2), DecodeMega(D,11,2));

          'o' : If Length(D) >= 8 Then
                  OnFilledOval (DecodeMega(D,1,2), DecodeMega(D,3,2),
                                DecodeMega(D,5,2), DecodeMega(D,7,2));

          'A' : If Length(D) >= 10 Then
                  OnArc (DecodeMega(D,1,2), DecodeMega(D,3,2),
                         DecodeMega(D,5,2), DecodeMega(D,7,2),
                         DecodeMega(D,9,2));

          'V' : If Length(D) >= 12 Then
                  OnOvalArc (DecodeMega(D,1,2), DecodeMega(D,3,2),
                             DecodeMega(D,5,2), DecodeMega(D,7,2),
                             DecodeMega(D,9,2), DecodeMega(D,11,2));

          'I' : If Length(D) >= 10 Then
                  OnPieSlice (DecodeMega(D,1,2), DecodeMega(D,3,2),
                              DecodeMega(D,5,2), DecodeMega(D,7,2),
                              DecodeMega(D,9,2));

          'i' : If Length(D) >= 12 Then
                  OnOvalPieSlice (DecodeMega(D,1,2), DecodeMega(D,3,2),
                                  DecodeMega(D,5,2), DecodeMega(D,7,2),
                                  DecodeMega(D,9,2), DecodeMega(D,11,2));

          'Z' : If Length(D) >= 18 Then
                  OnBezier (DecodeMega(D,1,2), DecodeMega(D,3,2),
                            DecodeMega(D,5,2), DecodeMega(D,7,2),
                            DecodeMega(D,9,2), DecodeMega(D,11,2),
                            DecodeMega(D,13,2), DecodeMega(D,15,2),
                            DecodeMega(D,17,2));

          { ---- Fill ---- }
          'F' : If Length(D) >= 6 Then
                  OnFill (DecodeMega(D,1,2), DecodeMega(D,3,2),
                          DecodeMega(D,5,2));

          { ---- Style ---- }
          '=' : If Length(D) >= 6 Then
                  OnLineStyle (DecodeMega(D,1,2), DecodeMega(D,3,2),
                               DecodeMega(D,5,2));

          'S' : If Length(D) >= 4 Then
                  OnFillStyle (DecodeMega(D,1,2), DecodeMega(D,3,2));

          's' : If Length(D) >= 18 Then
                  OnFillPattern (DecodeMega(D,1,2), DecodeMega(D,3,2),
                                 DecodeMega(D,5,2), DecodeMega(D,7,2),
                                 DecodeMega(D,9,2), DecodeMega(D,11,2),
                                 DecodeMega(D,13,2), DecodeMega(D,15,2),
                                 DecodeMega(D,17,2));

          { ---- No more ---- }
          '#' : OnNoMore;
        Else
          OnUnknown(CurCmd);
        End;

    { ---- Level 1 commands ---- }
    1 : Case CurCmd.Cmd of
          'M' : If Length(D) >= 10 Then
                  OnMouseRegion (DecodeMega(D,1,2),
                                 DecodeMega(D,3,2), DecodeMega(D,5,2),
                                 DecodeMega(D,7,2), DecodeMega(D,9,2),
                                 DecodeMega(D,11,2), DecodeMega(D,13,2),
                                 DecodeMega(D,15,2),
                                 Copy(D, 17, Length(D)));

          'K' : OnKillMouse;

          'T' : If Length(D) >= 10 Then
                  OnBeginText (DecodeMega(D,1,2), DecodeMega(D,3,2),
                               DecodeMega(D,5,2), DecodeMega(D,7,2),
                               DecodeMega(D,9,2));

          't' : If Length(D) >= 2 Then
                  OnRegionText (DecodeMega(D,1,2), Copy(D, 3, Length(D)));

          'E' : OnEndText;

          'C' : If Length(D) >= 10 Then
                  OnGetImage (DecodeMega(D,1,2), DecodeMega(D,3,2),
                              DecodeMega(D,5,2), DecodeMega(D,7,2),
                              DecodeMega(D,9,2));

          'P' : If Length(D) >= 12 Then
                  OnPutImage (DecodeMega(D,1,2), DecodeMega(D,3,2),
                              DecodeMega(D,5,2), DecodeMega(D,7,2),
                              DecodeMega(D,9,2),
                              Copy(D, 11, Length(D)));

          'W' : If Length(D) >= 2 Then
                  OnWriteIcon (DecodeMega(D,1,2), Copy(D, 3, Length(D)));

          'I' : If Length(D) >= 12 Then
                  OnLoadIcon (DecodeMega(D,1,2), DecodeMega(D,3,2),
                              DecodeMega(D,5,2), DecodeMega(D,7,2),
                              DecodeMega(D,9,2),
                              Copy(D, 11, Length(D)));

          'B' : If Length(D) >= 8 Then
                  OnButtonStyle (DecodeMega(D,1,2), DecodeMega(D,3,2),
                                 DecodeMega(D,5,2), DecodeMega(D,7,2));

          'U' : If Length(D) >= 12 Then
                  OnButton (DecodeMega(D,1,2), DecodeMega(D,3,2),
                            DecodeMega(D,5,2), DecodeMega(D,7,2),
                            DecodeMega(D,9,2), DecodeMega(D,11,2));

          'D' : If Length(D) >= 4 Then
                  OnDefine (DecodeMega(D,1,2), DecodeMega(D,3,2),
                            Copy(D, 5, Length(D)));

          'G' : If Length(D) >= 12 Then
                  OnCopyRegion (DecodeMega(D,1,2), DecodeMega(D,3,2),
                                DecodeMega(D,5,2), DecodeMega(D,7,2),
                                DecodeMega(D,9,2), DecodeMega(D,11,2));

          'R' : If Length(D) >= 2 Then
                  OnReadScene (DecodeMega(D,1,2), Copy(D, 3, Length(D)));

          'F' : If Length(D) >= 4 Then
                  OnFileQuery (DecodeMega(D,1,2), DecodeMega(D,3,2),
                               Copy(D, 5, Length(D)));
        Else
          OnUnknown(CurCmd);
        End;

    { ---- Level 9: file transfer ---- }
    9 : OnUnknown(CurCmd);
  Else
    OnUnknown(CurCmd);
  End;
End;

// ====================================================================
// Default virtual handlers — all empty (no-op).
//
// A display backend (RIP_Viewer.pas) would override these to render
// graphics.  Without a backend, RIP codes are silently consumed.
// ====================================================================

Procedure TRIPParser.OnText          (S: String);          Begin End;
Procedure TRIPParser.OnTextWindow    (X0, Y0, X1, Y1, Wrap, Size: Integer); Begin End;
Procedure TRIPParser.OnViewport      (X0, Y0, X1, Y1: Integer); Begin End;
Procedure TRIPParser.OnResetWindows;                       Begin End;
Procedure TRIPParser.OnEraseWindow;                        Begin End;
Procedure TRIPParser.OnEraseView;                          Begin End;
Procedure TRIPParser.OnGotoXY        (X, Y: Integer);      Begin End;
Procedure TRIPParser.OnHome;                               Begin End;
Procedure TRIPParser.OnEraseEOL;                           Begin End;
Procedure TRIPParser.OnColor         (Color: Integer);      Begin End;
Procedure TRIPParser.OnSetPalette    (Pal: Array of Integer); Begin End;
Procedure TRIPParser.OnOnePalette    (Color, Value: Integer); Begin End;
Procedure TRIPParser.OnWriteMode     (Mode: Integer);       Begin End;
Procedure TRIPParser.OnMove          (X, Y: Integer);       Begin End;
Procedure TRIPParser.OnTextCmd       (S: String);           Begin End;
Procedure TRIPParser.OnTextXY        (X, Y: Integer; S: String); Begin End;
Procedure TRIPParser.OnFontStyle     (Font, Dir, Size, Res: Integer); Begin End;
Procedure TRIPParser.OnPixel         (X, Y: Integer);       Begin End;
Procedure TRIPParser.OnLine          (X0, Y0, X1, Y1: Integer); Begin End;
Procedure TRIPParser.OnRectangle     (X0, Y0, X1, Y1: Integer); Begin End;
Procedure TRIPParser.OnBar           (X0, Y0, X1, Y1: Integer); Begin End;
Procedure TRIPParser.OnCircle        (X, Y, Radius: Integer); Begin End;
Procedure TRIPParser.OnOval          (X, Y, RadX, RadY: Integer); Begin End;
Procedure TRIPParser.OnFilledOval    (X, Y, RadX, RadY: Integer); Begin End;
Procedure TRIPParser.OnArc           (X, Y, StartAng, EndAng, Radius: Integer); Begin End;
Procedure TRIPParser.OnOvalArc       (X, Y, StartAng, EndAng, RadX, RadY: Integer); Begin End;
Procedure TRIPParser.OnPieSlice      (X, Y, StartAng, EndAng, Radius: Integer); Begin End;
Procedure TRIPParser.OnOvalPieSlice  (X, Y, StartAng, EndAng, RadX, RadY: Integer); Begin End;
Procedure TRIPParser.OnBezier        (X1,Y1,X2,Y2,X3,Y3,X4,Y4,Cnt: Integer); Begin End;
Procedure TRIPParser.OnFill          (X, Y, Border: Integer); Begin End;
Procedure TRIPParser.OnLineStyle     (Style, UserPat, Thick: Integer); Begin End;
Procedure TRIPParser.OnFillStyle     (Pattern, Color: Integer); Begin End;
Procedure TRIPParser.OnFillPattern   (C1,C2,C3,C4,C5,C6,C7,C8, Color: Integer); Begin End;
Procedure TRIPParser.OnMouseRegion   (Num, X0, Y0, X1, Y1, Clk, Clr, Res: Integer; Text: String); Begin End;
Procedure TRIPParser.OnKillMouse;                          Begin End;
Procedure TRIPParser.OnBeginText     (X1, Y1, X2, Y2, Res: Integer); Begin End;
Procedure TRIPParser.OnRegionText    (Justify: Integer; S: String); Begin End;
Procedure TRIPParser.OnEndText;                            Begin End;
Procedure TRIPParser.OnGetImage      (X0, Y0, X1, Y1, Res: Integer); Begin End;
Procedure TRIPParser.OnPutImage      (X, Y, Mode, Clipboard, Res: Integer; FN: String); Begin End;
Procedure TRIPParser.OnWriteIcon     (Res: Integer; FN: String); Begin End;
Procedure TRIPParser.OnLoadIcon      (X, Y, Mode, Clipboard, Res: Integer; FN: String); Begin End;
Procedure TRIPParser.OnButtonStyle   (Wid, Hgt, Orient, Flags: Integer); Begin End;
Procedure TRIPParser.OnButton        (X0, Y0, X1, Y1, HotKey, Flags: Integer); Begin End;
Procedure TRIPParser.OnDefine        (Flags, Res: Integer; Text: String); Begin End;
Procedure TRIPParser.OnQuery         (Mode, Res: Integer; Text: String); Begin End;
Procedure TRIPParser.OnCopyRegion    (X0, Y0, X1, Y1, Res, Dest: Integer); Begin End;
Procedure TRIPParser.OnReadScene     (Res: Integer; FN: String); Begin End;
Procedure TRIPParser.OnFileQuery     (Mode, Res: Integer; FN: String); Begin End;
Procedure TRIPParser.OnNoMore;                             Begin End;
Procedure TRIPParser.OnUnknown       (Var Cmd: TRIPCommand); Begin End;

End.

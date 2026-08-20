{$MODE DELPHI}
{$H-}
Unit RIP1Parse;
{
  RIPscrip v1.54 Parser — mega-number decoder, command enum, parser.
  Version-specific: v1.54 only.

  Copyright (C) 2026 — GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Type
  TRIPCommand = (
    rcUnknown,
    { Drawing }
    rcPixel, rcLine, rcRectangle, rcBar, rcCircle, rcOval, rcFilledOval,
    rcArc, rcOvalArc, rcPieSlice, rcOvalPieSlice,
    rcBezier, rcPolygon, rcFilledPolygon, rcPolyLine,
    rcFill,
    { Style }
    rcColor, rcFillStyle, rcFillPattern, rcLineStyle,
    rcWriteMode, rcFontStyle,
    { Text }
    rcGotoXY, rcHome, rcEraseEOL,
    rcOutText, rcOutTextXY,
    rcBeginText, rcEndText, rcRegionText,
    { Window }
    rcTextWindow, rcViewPort,
    rcEraseView, rcEraseWindow, rcResetWindows,
    { Image }
    rcGetImage, rcPutImage, rcWriteIcon, rcLoadIcon,
    { Mouse/Button }
    rcMouse, rcKillMouseFields, rcButton, rcButtonStyle,
    { Palette }
    rcSetPalette, rcOnePalette,
    { Reset }
    rcNoMore
  );

Function MegaVal(Ch: Char): Integer;
Function DecodeMega2(const S: String; Pos: Integer): Integer;
Function ParseRIPCommand(const Line: String; Var Pos: Integer): TRIPCommand;

Implementation

Function MegaVal(Ch: Char): Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then
    Result := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'Z') Then
    Result := Ord(Ch) - Ord('A') + 10
  Else If (Ch >= 'a') And (Ch <= 'z') Then
    Result := Ord(Ch) - Ord('a') + 10
  Else
    Result := 0;
End;

Function DecodeMega2(const S: String; Pos: Integer): Integer;
Begin
  Result := MegaVal(S[Pos]) * 36 + MegaVal(S[Pos+1]);
End;

Function ParseRIPCommand(const Line: String; Var Pos: Integer): TRIPCommand;
Var Ch: Char;
Begin
  Result := rcUnknown;
  If Pos > Length(Line) Then Exit;
  If Line[Pos] <> '!' Then Exit;
  Inc(Pos);
  If Pos > Length(Line) Then Exit;
  If Line[Pos] <> '|' Then Exit;
  Inc(Pos);
  If Pos > Length(Line) Then Exit;

  Ch := Line[Pos]; Inc(Pos);
  Case Ch Of
    'X': Result := rcPixel;
    'L': Result := rcLine;
    'R': Result := rcRectangle;
    'B': Result := rcBar;
    'C': Result := rcCircle;
    'O': Result := rcOval;
    'o': Result := rcFilledOval;
    'A': Result := rcArc;
    'V': Result := rcOvalArc;
    'I': Result := rcPieSlice;
    'i': Result := rcOvalPieSlice;
    'Z': Result := rcBezier;
    'P': Result := rcPolygon;
    'p': Result := rcFilledPolygon;
    'l': Result := rcPolyLine;
    'F': Result := rcFill;
    'c': Result := rcColor;
    'S': Result := rcFillStyle;
    's': Result := rcFillPattern;
    '=': Result := rcLineStyle;
    'W': Result := rcWriteMode;
    'Y': Result := rcFontStyle;
    'm': Result := rcGotoXY;
    'g': Result := rcGotoXY;
    'H': Result := rcHome;
    '>': Result := rcEraseEOL;
    'T': Result := rcOutText;
    '@': Result := rcOutTextXY;
    't': Result := rcBeginText;
    'E': Result := rcEndText;
    '1': If Pos <= Length(Line) Then Begin
           Case Line[Pos] Of
             'T': Begin Inc(Pos); Result := rcRegionText; End;
             'K': Begin Inc(Pos); Result := rcKillMouseFields; End;
             'C': Begin Inc(Pos); Result := rcGetImage; End;
             'P': Begin Inc(Pos); Result := rcPutImage; End;
             'I': Begin Inc(Pos); Result := rcLoadIcon; End;
             'M': Begin Inc(Pos); Result := rcMouse; End;
             'U': Begin Inc(Pos); Result := rcButton; End;
             'B': Begin Inc(Pos); Result := rcButtonStyle; End;
           End;
         End;
    'w': Result := rcTextWindow;
    'v': Result := rcViewPort;
    'e': Result := rcEraseView;
    '*': Result := rcEraseWindow;
    '#': Result := rcResetWindows;
    'G': Result := rcGetImage;
    'D': Result := rcLoadIcon;
    'M': Result := rcMouse;
    'K': Result := rcKillMouseFields;
    'U': Result := rcButton;
    'u': Result := rcButtonStyle;
    'Q': Result := rcSetPalette;
    'a': Result := rcOnePalette;
  End;
End;

End.

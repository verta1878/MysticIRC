{$MODE DELPHI}
{$H-}
Unit RIPState;
{
  RIPscrip Screen State Save/Restore — ported from ripscr.pas.
  Manages screen slots (0-9), text window backup, and SaveAll/RestoreAll.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}
Interface

Uses RIPEngine;

Procedure SaveScreen(Slot: Byte);
Procedure RestoreScreen(Slot: Byte);
Procedure SaveTextWin;
Procedure RestoreTextWin;
Procedure SaveAll;
Procedure RestoreAll;
Procedure FreeAllScreenSlots;

Implementation

Type
  TSavedTextWin = Record
    Active : Boolean;
    X0, Y0, X1, Y1 : Integer;
    Size : Byte;
  End;

Var
  SavedScreens : Array[0..9] Of ^TPixelBuffer;
  SavedTW      : TSavedTextWin;

Procedure SaveScreen(Slot: Byte);
Begin
  If Slot > 9 Then Exit;
  If SavedScreens[Slot] = Nil Then
    New(SavedScreens[Slot]);
  Move(Canvas.Pixels^, SavedScreens[Slot]^, SizeOf(TPixelBuffer));
End;

Procedure RestoreScreen(Slot: Byte);
Begin
  If Slot > 9 Then Exit;
  If SavedScreens[Slot] = Nil Then Exit;
  Move(SavedScreens[Slot]^, Canvas.Pixels^, SizeOf(TPixelBuffer));
  { Per RIPterm: restore deletes the save }
  Dispose(SavedScreens[Slot]);
  SavedScreens[Slot] := Nil;
End;

Procedure SaveTextWin;
Begin
  SavedTW.Active := True;
  SavedTW.X0     := Canvas.TWinX0;
  SavedTW.Y0     := Canvas.TWinY0;
  SavedTW.X1     := Canvas.TWinX1;
  SavedTW.Y1     := Canvas.TWinY1;
  SavedTW.Size   := Canvas.TWinSize;
End;

Procedure RestoreTextWin;
Begin
  If Not SavedTW.Active Then Exit;
  SetTextWindow(SavedTW.X0, SavedTW.Y0, SavedTW.X1, SavedTW.Y1, SavedTW.Size);
  SavedTW.Active := False;
End;

Procedure SaveAll;
Begin
  SaveScreen(0);
  SaveTextWin;
End;

Procedure RestoreAll;
Begin
  RestoreScreen(0);
  RestoreTextWin;
End;

Procedure FreeAllScreenSlots;
Var I: Integer;
Begin
  For I := 0 To 9 Do
    If SavedScreens[I] <> Nil Then Begin
      Dispose(SavedScreens[I]);
      SavedScreens[I] := Nil;
    End;
End;

Initialization
  FillChar(SavedScreens, SizeOf(SavedScreens), 0);
  SavedTW.Active := False;

End.

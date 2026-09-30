{$MODE DELPHI}
{$H-}
Unit VIPEngine;
{ VIPEngine — Procedural entry point for RIPscrip processing.
  Wraps TRIPEngine (ripscr.pas) behind a flat API so callers
  (mterm, mconfig, ripview) don't manage the OOP class directly.

  Usage:
    VIPInit;                    — create engine, set defaults
    VIPProcessLine(Line);       — feed a RIPscrip line
    VIPReset;                   — reset graphics state (!|#)
    VIPDone;                    — destroy engine, free memory

  The internal TRIPEngine instance is global to this unit.
  Only one engine exists at a time (matches DOS single-task model).

  Copyright (C) 2026 — GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses
  RIPEngine;  { TRIPCanvas, TRIPColor, etc. }

{ Lifecycle }
Procedure VIPInit;
Procedure VIPDone;

{ Processing }
Procedure VIPProcessLine(Line: String);
Procedure VIPReset;
Procedure VIPClearScreen;

{ State queries }
Function  VIPGetX: SmallInt;
Function  VIPGetY: SmallInt;
Function  VIPGetMaxX: SmallInt;
Function  VIPGetMaxY: SmallInt;
Function  VIPGetPixel(X, Y: SmallInt): Byte;
Function  VIPGetWidth: SmallInt;
Function  VIPGetHeight: SmallInt;

{ Drawing — direct access when callers need it }
Procedure VIPDrawPixel(X, Y: SmallInt; Color: Byte);
Procedure VIPDrawLine(X0, Y0, X1, Y1: SmallInt);
Procedure VIPDrawRect(X0, Y0, X1, Y1: SmallInt);
Procedure VIPDrawBar(X0, Y0, X1, Y1: SmallInt);
Procedure VIPDrawCircle(XC, YC, Radius: SmallInt);
Procedure VIPFloodFill(X, Y: SmallInt; Border: Byte);
Procedure VIPDrawText(X, Y: SmallInt; S: String);

{ Color }
Procedure VIPSetColor(C: TRIPColor);
Procedure VIPSetBkColor(C: TRIPColor);
Function  VIPGetColor: TRIPColor;

{ Viewport }
Procedure VIPSetViewPort(X0, Y0, X1, Y1: SmallInt);
Procedure VIPClearViewPort;

{ Mouse fields }
Function  VIPFindMouseField(X, Y: SmallInt): Integer;
Procedure VIPKillMouseFields;

{ Text variables }
Procedure VIPDefineVar(Name, Value: String; Persist, Required: Boolean);
Function  VIPGetVar(Name: String): String;

{ Font }
Function  VIPLoadCHR(FontNum: Byte; FileName: String): Boolean;

{ Screen save/restore }
Procedure VIPSaveScreen(Slot: Byte);
Procedure VIPRestoreScreen(Slot: Byte);
Procedure VIPSaveAll;
Procedure VIPRestoreAll;

{ Copy region }
Procedure VIPCopyRegion(X0, Y0, X1, Y1, DestY: SmallInt);

{ Canvas access — for direct pixel/flush operations }
Function  VIPCanvas: PRIPCanvas;

{ Status }
Function  VIPActive: Boolean;

Implementation

Uses
  RIPScr;  { TRIPEngine }

Var
  Eng     : TRIPEngine;
  IsActive: Boolean;

{ === Lifecycle === }

Procedure VIPInit;
Begin
  If IsActive Then VIPDone;
  Eng := TRIPEngine.Create;
  IsActive := True;
End;

Procedure VIPDone;
Begin
  If Not IsActive Then Exit;
  Eng.Free;
  Eng := Nil;
  IsActive := False;
End;

{ === Processing === }

Procedure VIPProcessLine(Line: String);
Begin
  If IsActive Then Eng.ProcessLine(Line);
End;

Procedure VIPReset;
Begin
  If IsActive Then Eng.Reset;
End;

Procedure VIPClearScreen;
Begin
  If IsActive Then Eng.ClearScreen;
End;

{ === State queries === }

Function VIPGetX: SmallInt;
Begin
  If IsActive Then Result := Eng.GetWidth { placeholder — CurX is private }
  Else Result := 0;
End;

Function VIPGetY: SmallInt;
Begin
  If IsActive Then Result := Eng.GetHeight { placeholder — CurY is private }
  Else Result := 0;
End;

Function VIPGetMaxX: SmallInt;
Begin
  If IsActive Then Result := Eng.GetMaxX Else Result := 0;
End;

Function VIPGetMaxY: SmallInt;
Begin
  If IsActive Then Result := Eng.GetMaxY Else Result := 0;
End;

Function VIPGetPixel(X, Y: SmallInt): Byte;
Begin
  If IsActive Then Result := Eng.GetPixel(X, Y) Else Result := 0;
End;

Function VIPGetWidth: SmallInt;
Begin
  If IsActive Then Result := Eng.GetWidth Else Result := 0;
End;

Function VIPGetHeight: SmallInt;
Begin
  If IsActive Then Result := Eng.GetHeight Else Result := 0;
End;

{ === Drawing === }

Procedure VIPDrawPixel(X, Y: SmallInt; Color: Byte);
Begin
  If IsActive Then Eng.DrawPixel(X, Y, Color);
End;

Procedure VIPDrawLine(X0, Y0, X1, Y1: SmallInt);
Begin
  If IsActive Then Eng.DrawLine(X0, Y0, X1, Y1);
End;

Procedure VIPDrawRect(X0, Y0, X1, Y1: SmallInt);
Begin
  If IsActive Then Eng.DrawRect(X0, Y0, X1, Y1);
End;

Procedure VIPDrawBar(X0, Y0, X1, Y1: SmallInt);
Begin
  If IsActive Then Eng.DrawBar(X0, Y0, X1, Y1);
End;

Procedure VIPDrawCircle(XC, YC, Radius: SmallInt);
Begin
  If IsActive Then Eng.DrawCircle(XC, YC, Radius);
End;

Procedure VIPFloodFill(X, Y: SmallInt; Border: Byte);
Begin
  If IsActive Then Eng.FloodFill(X, Y, Border);
End;

Procedure VIPDrawText(X, Y: SmallInt; S: String);
Begin
  If IsActive Then Eng.DrawText8x8(X, Y, S);
End;

{ === Color === }

Procedure VIPSetColor(C: TRIPColor);
Begin
  If IsActive Then Begin
    SetColor(C);  { procedural ripengine }
  End;
End;

Procedure VIPSetBkColor(C: TRIPColor);
Begin
  If IsActive Then SetBkColor(C);
End;

Function VIPGetColor: TRIPColor;
Begin
  If IsActive Then Result := GetColor Else Result := 0;
End;

{ === Viewport === }

Procedure VIPSetViewPort(X0, Y0, X1, Y1: SmallInt);
Begin
  If IsActive Then SetViewPort(X0, Y0, X1, Y1, True);
End;

Procedure VIPClearViewPort;
Begin
  If IsActive Then Eng.ClearViewport;
End;

{ === Mouse === }

Function VIPFindMouseField(X, Y: SmallInt): Integer;
Begin
  If IsActive Then Result := Eng.FindMouseField(X, Y) Else Result := -1;
End;

Procedure VIPKillMouseFields;
Begin
  { KillMouseFields clears the field list — OOP method }
  If IsActive Then Eng.Reset; { simplified — full kill is inside Reset }
End;

{ === Variables === }

Procedure VIPDefineVar(Name, Value: String; Persist, Required: Boolean);
Begin
  If IsActive Then Eng.DefineVar(Name, Value, Persist, Required);
End;

Function VIPGetVar(Name: String): String;
Begin
  If IsActive Then Result := Eng.GetVar(Name) Else Result := '';
End;

{ === Font === }

Function VIPLoadCHR(FontNum: Byte; FileName: String): Boolean;
Begin
  If IsActive Then Result := Eng.LoadCHR(FontNum, FileName)
  Else Result := False;
End;

{ === Screen save/restore === }

Procedure VIPSaveScreen(Slot: Byte);
Begin
  If IsActive Then Eng.SaveScreen(Slot);
End;

Procedure VIPRestoreScreen(Slot: Byte);
Begin
  If IsActive Then Eng.RestoreScreen(Slot);
End;

Procedure VIPSaveAll;
Begin
  If IsActive Then Eng.SaveAll;
End;

Procedure VIPRestoreAll;
Begin
  If IsActive Then Eng.RestoreAll;
End;

{ === Copy region === }

Procedure VIPCopyRegion(X0, Y0, X1, Y1, DestY: SmallInt);
Begin
  If IsActive Then Eng.CopyRegion(X0, Y0, X1, Y1, DestY);
End;

{ === Canvas access === }

Function VIPCanvas: PRIPCanvas;
Begin
  Result := @Canvas;  { global from RIPEngine }
End;

{ === Status === }

Function VIPActive: Boolean;
Begin
  Result := IsActive;
End;

{ === Init/Finalize === }

Initialization
  Eng := Nil;
  IsActive := False;

Finalization
  If IsActive Then VIPDone;

End.

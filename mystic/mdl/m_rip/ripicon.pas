{$MODE DELPHI}
{$H-}
Unit RIPIcon;
{
  RIPscrip Icon File I/O — ported from ripscr.pas.
  Handles ICN (4-plane EGA icon), MSK (transparency mask),
  HIC (highlight icon), GetImage/PutImage memory ops.

  ICN format: header(w-1 word, h-1 word) + 4 EGA planes per row
  Plane order: 3, 2, 1, 0 (MSB first), ceil(width/8) bytes/row

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}
Interface

Uses RIPEngine;

Const
  ICON_CACHE_SLOTS = 64;

Type
  PIconData = ^TIconData;
  TIconData = Record
    W, H    : Word;
    Pixels  : Array Of Byte;  { W*H pixel indices }
    Loaded  : Boolean;
  End;

Var
  IconCache : Array[0..ICON_CACHE_SLOTS - 1] Of TIconData;

{ Direct render — load and draw immediately }
Procedure GetImage(X0, Y0, X1, Y1: Integer; Var Buf);
Procedure PutImage(X, Y: Integer; Var Buf; Mode: Byte);
Function  LoadIcon(FileName: String; X, Y: Integer; Mode: Byte): Boolean;
Function  SaveIcon(FileName: String; X0, Y0, X1, Y1: Integer): Boolean;
Function  LoadMask(FileName: String; X, Y: Integer): Boolean;
Function  LoadIconMasked(IconFile, MaskFile: String; X, Y: Integer): Boolean;
Function  LoadHotIcon(FileName: String; X, Y: Integer): Boolean;
Function  LoadPCX(FileName: String; X, Y: Integer): Boolean;

{ Icon cache — load once, display many }
Function  IconLoadToSlot(FileName: String; Slot: Integer): Boolean;
Function  IconLoadICNToSlot(FileName: String; Slot: Integer): Boolean;
Procedure IconDisplaySlot(Slot: Integer; X, Y: Integer; Mode: Byte);
Procedure IconFreeSlot(Slot: Integer);
Procedure IconFreeAll;
Function  IconSlotWidth(Slot: Integer): Integer;
Function  IconSlotHeight(Slot: Integer): Integer;
Function  IconSlotLoaded(Slot: Integer): Boolean;

Implementation

Procedure GetImage(X0, Y0, X1, Y1: Integer; Var Buf);
Var P: ^Byte; X, Y: Integer;
Begin
  P := @Buf;
  PWord(P)^ := X1 - X0 + 1; Inc(P, 2);
  PWord(P)^ := Y1 - Y0 + 1; Inc(P, 2);
  For Y := Y0 To Y1 Do
    For X := X0 To X1 Do Begin
      P^ := GetPixel(X, Y);
      Inc(P);
    End;
End;

Procedure PutImage(X, Y: Integer; Var Buf; Mode: Byte);
Var P: ^Byte; W, H: Word; IX, IY: Integer; SaveMode: Byte;
Begin
  P := @Buf;
  W := PWord(P)^; Inc(P, 2);
  H := PWord(P)^; Inc(P, 2);
  SaveMode := Canvas.WriteMode;
  Canvas.WriteMode := Mode;
  For IY := 0 To H - 1 Do
    For IX := 0 To W - 1 Do Begin
      PutPixel(X + IX, Y + IY, P^);
      Inc(P);
    End;
  Canvas.WriteMode := SaveMode;
End;

Function LoadIcon(FileName: String; X, Y: Integer; Mode: Byte): Boolean;
Var
  F: File;
  WRaw, HRaw: Word;
  W, H, IX, IY, Plane, RowBytes: Integer;
  PlaneData: Array[0..3, 0..79] Of Byte;
  Color: Byte;
  ByteIdx, BitIdx: Integer;
  SaveMode: Byte;
Begin
  Result := False;
  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockRead(F, WRaw, 2);
  BlockRead(F, HRaw, 2);
  W := WRaw + 1;
  H := HRaw + 1;
  If (W <= 0) Or (H <= 0) Or (W > 640) Or (H > 350) Then Begin Close(F); Exit; End;

  RowBytes := (W + 7) Div 8;
  SaveMode := Canvas.WriteMode;
  Canvas.WriteMode := Mode;

  For IY := 0 To H - 1 Do Begin
    { Read planes in spec order: 3, 2, 1, 0 }
    BlockRead(F, PlaneData[3], RowBytes);
    BlockRead(F, PlaneData[2], RowBytes);
    BlockRead(F, PlaneData[1], RowBytes);
    BlockRead(F, PlaneData[0], RowBytes);

    For IX := 0 To W - 1 Do Begin
      ByteIdx := IX Div 8;
      BitIdx  := 7 - (IX Mod 8);
      Color := 0;
      For Plane := 0 To 3 Do
        If (PlaneData[Plane][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
          Color := Color Or (1 Shl Plane);
      PutPixel(X + IX, Y + IY, Color);
    End;
  End;

  Close(F);
  Canvas.WriteMode := SaveMode;
  Result := True;
End;

Function SaveIcon(FileName: String; X0, Y0, X1, Y1: Integer): Boolean;
Var
  F: File;
  WRaw, HRaw: Word;
  W, H, IX, IY, Plane, RowBytes: Integer;
  PlaneData: Array[0..3, 0..79] Of Byte;
  Color: Byte;
  ByteIdx, BitIdx: Integer;
  Trash: Byte;
Begin
  Result := False;
  W := X1 - X0 + 1;
  H := Y1 - Y0 + 1;
  If (W <= 0) Or (H <= 0) Or (W > 640) Then Exit;

  RowBytes := (W + 7) Div 8;
  WRaw := W - 1;
  HRaw := H - 1;

  Assign(F, FileName);
  {$I-} ReWrite(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockWrite(F, WRaw, 2);
  BlockWrite(F, HRaw, 2);

  For IY := Y0 To Y1 Do Begin
    FillChar(PlaneData, SizeOf(PlaneData), 0);
    For IX := 0 To W - 1 Do Begin
      Color   := GetPixel(X0 + IX, IY) And $0F;
      ByteIdx := IX Div 8;
      BitIdx  := 7 - (IX Mod 8);
      For Plane := 0 To 3 Do
        If (Color And (1 Shl Plane)) <> 0 Then
          PlaneData[Plane][ByteIdx] := PlaneData[Plane][ByteIdx] Or (1 Shl BitIdx);
    End;
    { Write planes in spec order: 3, 2, 1, 0 }
    BlockWrite(F, PlaneData[3], RowBytes);
    BlockWrite(F, PlaneData[2], RowBytes);
    BlockWrite(F, PlaneData[1], RowBytes);
    BlockWrite(F, PlaneData[0], RowBytes);
  End;

  Trash := 0;
  BlockWrite(F, Trash, 1);
  Close(F);
  Result := True;
End;

Function LoadMask(FileName: String; X, Y: Integer): Boolean;
Var
  F: File;
  WRaw, HRaw: Word;
  W, H, IX, IY, Plane, RowBytes: Integer;
  PlaneData: Array[0..3, 0..79] Of Byte;
  MaskBit: Boolean;
  ByteIdx, BitIdx: Integer;
Begin
  Result := False;
  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockRead(F, WRaw, 2);
  BlockRead(F, HRaw, 2);
  W := WRaw + 1;
  H := HRaw + 1;
  If (W <= 0) Or (H <= 0) Or (W > 640) Then Begin Close(F); Exit; End;

  RowBytes := (W + 7) Div 8;

  For IY := 0 To H - 1 Do Begin
    For Plane := 0 To 3 Do
      BlockRead(F, PlaneData[Plane], RowBytes);
    For IX := 0 To W - 1 Do Begin
      ByteIdx := IX Div 8;
      BitIdx  := 7 - (IX Mod 8);
      MaskBit := False;
      For Plane := 0 To 3 Do
        If (PlaneData[Plane][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
          MaskBit := True;
      If Not MaskBit Then
        PutPixel(X + IX, Y + IY, 0);
    End;
  End;

  Close(F);
  Result := True;
End;

Function LoadIconMasked(IconFile, MaskFile: String; X, Y: Integer): Boolean;
Begin
  Result := False;
  If Not LoadIcon(IconFile, X, Y, 0) Then Exit;
  LoadMask(MaskFile, X, Y);
  Result := True;
End;

Function LoadHotIcon(FileName: String; X, Y: Integer): Boolean;
Begin
  Result := LoadIcon(FileName, X, Y, 0);
End;

Function LoadPCX(FileName: String; X, Y: Integer): Boolean;
{ Load a 16-color EGA PCX file and render at (X,Y).
  PCX format: 128-byte header, RLE compressed, 4 bit planes.
  Ported from ripscr.pas TRIPEngine.LoadPCX. }
Var
  F: File;
  Header: Array[0..127] Of Byte;
  BPP: Byte;
  XMin, YMin, XMax, YMax: Integer;
  W, H: Integer;
  NPlanes: Byte;
  BytesPerRow: Word;
  Row, Plane, Col: Integer;
  RunByte, RunCount: Byte;
  PlaneData: Array[0..3, 0..79] Of Byte;
  ByteIdx, BitIdx: Integer;
  Color: Byte;
  BytesFilled: Integer;
Begin
  Result := False;
  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockRead(F, Header, 128);
  { Validate: manufacturer must be 0x0A (ZSoft) }
  If Header[0] <> $0A Then Begin Close(F); Exit; End;

  BPP  := Header[3];
  XMin := Header[4] Or (Header[5] Shl 8);
  YMin := Header[6] Or (Header[7] Shl 8);
  XMax := Header[8] Or (Header[9] Shl 8);
  YMax := Header[10] Or (Header[11] Shl 8);
  NPlanes     := Header[65];
  BytesPerRow := Header[66] Or (Header[67] Shl 8);

  W := XMax - XMin + 1;
  H := YMax - YMin + 1;

  { 16-color EGA only: 4 planes, 1 bit per pixel }
  If (BPP <> 1) Or (NPlanes <> 4) Then Begin Close(F); Exit; End;
  If (W <= 0) Or (H <= 0) Or (W > 640) Or (H > 350) Then Begin Close(F); Exit; End;
  If BytesPerRow > 80 Then Begin Close(F); Exit; End;

  { Decode RLE scanlines }
  For Row := 0 To H - 1 Do Begin
    For Plane := 0 To NPlanes - 1 Do Begin
      BytesFilled := 0;
      While BytesFilled < BytesPerRow Do Begin
        {$I-} BlockRead(F, RunByte, 1); {$I+}
        If IOResult <> 0 Then Begin Close(F); Exit; End;
        If (RunByte And $C0) = $C0 Then Begin
          RunCount := RunByte And $3F;
          {$I-} BlockRead(F, RunByte, 1); {$I+}
          If IOResult <> 0 Then Begin Close(F); Exit; End;
          While (RunCount > 0) And (BytesFilled < BytesPerRow) Do Begin
            PlaneData[Plane][BytesFilled] := RunByte;
            Inc(BytesFilled);
            Dec(RunCount);
          End;
        End Else Begin
          PlaneData[Plane][BytesFilled] := RunByte;
          Inc(BytesFilled);
        End;
      End;
    End;
    { Combine planes into pixel colors }
    For Col := 0 To W - 1 Do Begin
      ByteIdx := Col Div 8;
      BitIdx  := 7 - (Col Mod 8);
      Color := 0;
      For Plane := 0 To 3 Do
        If (PlaneData[Plane][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
          Color := Color Or (1 Shl Plane);
      PutPixel(X + Col, Y + Row, Color);
    End;
  End;

  Close(F);
  Result := True;
End;

{ ====================================================================
  Icon Cache — 64-slot array, load once display many
  Matches RIPterm's icon_data[64] / icon_display / icon_free_all
  ==================================================================== }

Function IconLoadICNToSlot(FileName: String; Slot: Integer): Boolean;
{ Load ICN file into cache slot as decoded pixel array }
Var
  F: File;
  WRaw, HRaw: Word;
  W, H, IX, IY, Plane, RowBytes: Integer;
  PlaneData: Array[0..3, 0..79] Of Byte;
  Color: Byte;
  ByteIdx, BitIdx: Integer;
Begin
  Result := False;
  If (Slot < 0) Or (Slot >= ICON_CACHE_SLOTS) Then Exit;

  { Free existing slot }
  IconFreeSlot(Slot);

  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  BlockRead(F, WRaw, 2);
  BlockRead(F, HRaw, 2);
  W := WRaw + 1;
  H := HRaw + 1;
  If (W <= 0) Or (H <= 0) Or (W > 640) Or (H > 350) Then Begin Close(F); Exit; End;

  RowBytes := (W + 7) Div 8;

  { Allocate pixel buffer }
  SetLength(IconCache[Slot].Pixels, W * H);
  IconCache[Slot].W := W;
  IconCache[Slot].H := H;

  For IY := 0 To H - 1 Do Begin
    BlockRead(F, PlaneData[3], RowBytes);
    BlockRead(F, PlaneData[2], RowBytes);
    BlockRead(F, PlaneData[1], RowBytes);
    BlockRead(F, PlaneData[0], RowBytes);

    For IX := 0 To W - 1 Do Begin
      ByteIdx := IX Div 8;
      BitIdx  := 7 - (IX Mod 8);
      Color := 0;
      For Plane := 0 To 3 Do
        If (PlaneData[Plane][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
          Color := Color Or (1 Shl Plane);
      IconCache[Slot].Pixels[IY * W + IX] := Color;
    End;
  End;

  Close(F);
  IconCache[Slot].Loaded := True;
  Result := True;
End;

Function IconLoadToSlot(FileName: String; Slot: Integer): Boolean;
{ Load icon file to cache — auto-detect by extension }
Var Ext: String;
Begin
  Ext := UpperCase(ExtractFileExt(FileName));
  If (Ext = '.ICN') Or (Ext = '.HIC') Or (Ext = '') Then
    Result := IconLoadICNToSlot(FileName, Slot)
  Else
    Result := False; { PCX/BMP cache not yet — render direct for now }
End;

Procedure IconDisplaySlot(Slot: Integer; X, Y: Integer; Mode: Byte);
{ Render cached icon to canvas at (X,Y) with write mode }
Var IX, IY, W, H: Integer; SaveMode: Byte;
Begin
  If (Slot < 0) Or (Slot >= ICON_CACHE_SLOTS) Then Exit;
  If Not IconCache[Slot].Loaded Then Exit;

  W := IconCache[Slot].W;
  H := IconCache[Slot].H;
  SaveMode := Canvas.WriteMode;
  Canvas.WriteMode := Mode;

  For IY := 0 To H - 1 Do
    For IX := 0 To W - 1 Do
      PutPixel(X + IX, Y + IY, IconCache[Slot].Pixels[IY * W + IX]);

  Canvas.WriteMode := SaveMode;
End;

Procedure IconFreeSlot(Slot: Integer);
Begin
  If (Slot < 0) Or (Slot >= ICON_CACHE_SLOTS) Then Exit;
  SetLength(IconCache[Slot].Pixels, 0);
  IconCache[Slot].W := 0;
  IconCache[Slot].H := 0;
  IconCache[Slot].Loaded := False;
End;

Procedure IconFreeAll;
Var I: Integer;
Begin
  For I := 0 To ICON_CACHE_SLOTS - 1 Do
    IconFreeSlot(I);
End;

Function IconSlotWidth(Slot: Integer): Integer;
Begin
  If (Slot >= 0) And (Slot < ICON_CACHE_SLOTS) And IconCache[Slot].Loaded Then
    Result := IconCache[Slot].W
  Else
    Result := 0;
End;

Function IconSlotHeight(Slot: Integer): Integer;
Begin
  If (Slot >= 0) And (Slot < ICON_CACHE_SLOTS) And IconCache[Slot].Loaded Then
    Result := IconCache[Slot].H
  Else
    Result := 0;
End;

Function IconSlotLoaded(Slot: Integer): Boolean;
Begin
  Result := (Slot >= 0) And (Slot < ICON_CACHE_SLOTS) And IconCache[Slot].Loaded;
End;

{ Unit init/finalize }
Var _I: Integer;
Initialization
  For _I := 0 To ICON_CACHE_SLOTS - 1 Do Begin
    IconCache[_I].W := 0;
    IconCache[_I].H := 0;
    IconCache[_I].Loaded := False;
  End;
Finalization
  IconFreeAll;
End.

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
Function  LoadIMG(FileName: String; X, Y: Integer): Boolean;
Function  LoadTIF(FileName: String; X, Y: Integer): Boolean;

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

Function LoadIMG(FileName: String; X, Y: Integer): Boolean;
{ Load a GEM IMG raster file (Digital Research format) at (X,Y).
  Supports 1-plane (mono) and 4-plane (16-color EGA).
  Header: big-endian 16-bit words.
  Scanline encoding: solid runs, pattern runs, literal runs, vertical rep.
  Reference: GEM Raster format (seasip.info/Gem/ff_img.html) }
Var
  F: File;
  HdrWords: Array[0..8] Of Word;
  Version, HdrSize, Planes, PatLen: Word;
  ImgW, ImgH: Word;
  Row, Plane, Col: Integer;
  PlaneData: Array[0..3] Of Array Of Byte;
  RowBytes: Integer;
  B, B2, B3, B4: Byte;
  Count: Byte;
  PatBuf: Array[0..7] Of Byte;
  FillPos: Integer;
  RepCount: Word;
  RepRow, RepPlane: Integer;
  PrevPlanes: Array[0..3] Of Array Of Byte;
  Color: Byte;
  ByteIdx, BitIdx: Integer;
  Hi, Lo: Byte;

  Function ReadBE16: Word;
  Var A, B: Byte;
  Begin
    BlockRead(F, A, 1);
    BlockRead(F, B, 1);
    ReadBE16 := (Word(A) Shl 8) Or B;
  End;

  Function ReadByte: Byte;
  Var V: Byte;
  Begin
    {$I-} BlockRead(F, V, 1); {$I+}
    If IOResult <> 0 Then V := 0;
    ReadByte := V;
  End;

  Procedure DecodeScanline(Var Dest: Array Of Byte; ByteCount: Integer);
  { Decode one GEM IMG scanline into Dest[0..ByteCount-1] }
  Var Pos, I, J: Integer;
      RB, RC: Byte;
  Begin
    Pos := 0;
    While Pos < ByteCount Do Begin
      RB := ReadByte;
      If RB = $00 Then Begin
        { Pattern run or vertical replication prefix — handled by caller }
        RC := ReadByte;
        If RC = 0 Then Begin
          { Could be vert rep 00 00 FF nn — shouldn't happen mid-scanline }
          Pos := ByteCount; { bail }
        End Else Begin
          { Pattern run: 00 count pat[PatLen] — repeat pattern count times }
          For I := 0 To PatLen - 1 Do
            PatBuf[I] := ReadByte;
          For I := 1 To RC Do
            For J := 0 To PatLen - 1 Do
              If Pos < ByteCount Then Begin
                Dest[Pos] := PatBuf[J];
                Inc(Pos);
              End;
        End;
      End Else If RB = $80 Then Begin
        { Literal run: 80 count data[count] }
        RC := ReadByte;
        For I := 1 To RC Do
          If Pos < ByteCount Then Begin
            Dest[Pos] := ReadByte;
            Inc(Pos);
          End;
      End Else Begin
        { Solid run: bit7=1 → $FF, bit7=0 → $00; bits 6..0 = count }
        RC := RB And $7F;
        If (RB And $80) <> 0 Then
          RB := $FF
        Else
          RB := $00;
        For I := 1 To RC Do
          If Pos < ByteCount Then Begin
            Dest[Pos] := RB;
            Inc(Pos);
          End;
      End;
    End;
  End;

Begin
  Result := False;
  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  { Read header (big-endian words) }
  Version := ReadBE16;
  HdrSize := ReadBE16;
  Planes  := ReadBE16;
  PatLen  := ReadBE16;
  ReadBE16; { PixelWidth — skip }
  ReadBE16; { PixelHeight — skip }
  ImgW := ReadBE16;
  ImgH := ReadBE16;

  { Skip any extra header words }
  If HdrSize > 8 Then
    For Row := 9 To HdrSize Do
      ReadBE16;

  If Version <> 1 Then Begin Close(F); Exit; End;
  If (Planes <> 1) And (Planes <> 4) Then Begin Close(F); Exit; End;
  If (ImgW = 0) Or (ImgH = 0) Or (ImgW > 640) Or (ImgH > 350) Then Begin Close(F); Exit; End;
  If PatLen > 8 Then PatLen := 8;

  RowBytes := (ImgW + 7) Div 8;

  { Allocate plane buffers }
  For Plane := 0 To 3 Do Begin
    SetLength(PlaneData[Plane], RowBytes);
    SetLength(PrevPlanes[Plane], RowBytes);
  End;

  Row := 0;
  While Row < ImgH Do Begin
    { Check for vertical replication: 00 00 FF count }
    B := ReadByte;
    If B = $00 Then Begin
      B2 := ReadByte;
      If B2 = $00 Then Begin
        B3 := ReadByte;
        If B3 = $FF Then Begin
          RepCount := ReadByte;
          { Decode one line of planes }
          For Plane := 0 To Planes - 1 Do
            DecodeScanline(PlaneData[Plane], RowBytes);
          { Render this line RepCount times }
          For RepRow := 1 To RepCount Do Begin
            If Row >= ImgH Then Break;
            For Col := 0 To ImgW - 1 Do Begin
              ByteIdx := Col Div 8;
              BitIdx  := 7 - (Col Mod 8);
              Color := 0;
              If Planes = 1 Then Begin
                If (PlaneData[0][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
                  Color := 0
                Else
                  Color := 15;
              End Else Begin
                For Plane := 0 To 3 Do
                  If (PlaneData[Plane][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
                    Color := Color Or (1 Shl Plane);
              End;
              PutPixel(X + Col, Y + Row, Color);
            End;
            Inc(Row);
          End;
          Continue;
        End Else Begin
          { It was 00 xx (not 00 00 FF) — pattern run for first plane }
          { Push back: we already consumed 00 B2 B3 — B2 is count, B3+ is pattern }
          { Decode inline: count=B2, first pat byte=B3 }
          FillChar(PlaneData[0][0], RowBytes, 0);
          FillPos := 0;
          For FillPos := 0 To PatLen - 1 Do
            If FillPos = 0 Then
              PatBuf[0] := B3
            Else
              PatBuf[FillPos] := ReadByte;
          FillPos := 0;
          For RepRow := 1 To B2 Do
            For RepPlane := 0 To PatLen - 1 Do
              If FillPos < RowBytes Then Begin
                PlaneData[0][FillPos] := PatBuf[RepPlane];
                Inc(FillPos);
              End;
          { Continue decoding rest of plane 0 scanline }
          While FillPos < RowBytes Do Begin
            B := ReadByte;
            If B = $00 Then Begin
              Count := ReadByte;
              For RepPlane := 0 To PatLen - 1 Do
                PatBuf[RepPlane] := ReadByte;
              For RepRow := 1 To Count Do
                For RepPlane := 0 To PatLen - 1 Do
                  If FillPos < RowBytes Then Begin
                    PlaneData[0][FillPos] := PatBuf[RepPlane];
                    Inc(FillPos);
                  End;
            End Else If B = $80 Then Begin
              Count := ReadByte;
              For RepRow := 1 To Count Do
                If FillPos < RowBytes Then Begin
                  PlaneData[0][FillPos] := ReadByte;
                  Inc(FillPos);
                End;
            End Else Begin
              Count := B And $7F;
              If (B And $80) <> 0 Then B := $FF Else B := $00;
              For RepRow := 1 To Count Do
                If FillPos < RowBytes Then Begin
                  PlaneData[0][FillPos] := B;
                  Inc(FillPos);
                End;
            End;
          End;
          { Decode remaining planes }
          For Plane := 1 To Planes - 1 Do
            DecodeScanline(PlaneData[Plane], RowBytes);
          { Render }
          For Col := 0 To ImgW - 1 Do Begin
            ByteIdx := Col Div 8;
            BitIdx  := 7 - (Col Mod 8);
            Color := 0;
            If Planes = 1 Then Begin
              If (PlaneData[0][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
                Color := 0
              Else
                Color := 15;
            End Else Begin
              For Plane := 0 To 3 Do
                If (PlaneData[Plane][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
                  Color := Color Or (1 Shl Plane);
            End;
            PutPixel(X + Col, Y + Row, Color);
          End;
          Inc(Row);
          Continue;
        End;
      End Else Begin
        { 00 B2 where B2<>0 — pattern run, first plane, first record }
        FillChar(PlaneData[0][0], RowBytes, 0);
        FillPos := 0;
        For RepPlane := 0 To PatLen - 1 Do
          PatBuf[RepPlane] := ReadByte;
        For RepRow := 1 To B2 Do
          For RepPlane := 0 To PatLen - 1 Do
            If FillPos < RowBytes Then Begin
              PlaneData[0][FillPos] := PatBuf[RepPlane];
              Inc(FillPos);
            End;
        While FillPos < RowBytes Do Begin
          B := ReadByte;
          If B = $00 Then Begin
            Count := ReadByte;
            For RepPlane := 0 To PatLen - 1 Do
              PatBuf[RepPlane] := ReadByte;
            For RepRow := 1 To Count Do
              For RepPlane := 0 To PatLen - 1 Do
                If FillPos < RowBytes Then Begin
                  PlaneData[0][FillPos] := PatBuf[RepPlane];
                  Inc(FillPos);
                End;
          End Else If B = $80 Then Begin
            Count := ReadByte;
            For RepRow := 1 To Count Do
              If FillPos < RowBytes Then Begin
                PlaneData[0][FillPos] := ReadByte;
                Inc(FillPos);
              End;
          End Else Begin
            Count := B And $7F;
            If (B And $80) <> 0 Then B := $FF Else B := $00;
            For RepRow := 1 To Count Do
              If FillPos < RowBytes Then Begin
                PlaneData[0][FillPos] := B;
                Inc(FillPos);
              End;
          End;
        End;
        For Plane := 1 To Planes - 1 Do
          DecodeScanline(PlaneData[Plane], RowBytes);
        For Col := 0 To ImgW - 1 Do Begin
          ByteIdx := Col Div 8;
          BitIdx  := 7 - (Col Mod 8);
          Color := 0;
          If Planes = 1 Then Begin
            If (PlaneData[0][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
              Color := 0
            Else
              Color := 15;
          End Else Begin
            For Plane := 0 To 3 Do
              If (PlaneData[Plane][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
                Color := Color Or (1 Shl Plane);
          End;
          PutPixel(X + Col, Y + Row, Color);
        End;
        Inc(Row);
        Continue;
      End;
    End Else Begin
      { First byte of plane 0 is a solid or literal run }
      FillChar(PlaneData[0][0], RowBytes, 0);
      FillPos := 0;
      { Handle first record }
      If B = $80 Then Begin
        Count := ReadByte;
        For RepRow := 1 To Count Do
          If FillPos < RowBytes Then Begin
            PlaneData[0][FillPos] := ReadByte;
            Inc(FillPos);
          End;
      End Else Begin
        Count := B And $7F;
        If (B And $80) <> 0 Then B := $FF Else B := $00;
        For RepRow := 1 To Count Do
          If FillPos < RowBytes Then Begin
            PlaneData[0][FillPos] := B;
            Inc(FillPos);
          End;
      End;
      { Rest of plane 0 }
      While FillPos < RowBytes Do Begin
        B := ReadByte;
        If B = $00 Then Begin
          Count := ReadByte;
          For RepPlane := 0 To PatLen - 1 Do
            PatBuf[RepPlane] := ReadByte;
          For RepRow := 1 To Count Do
            For RepPlane := 0 To PatLen - 1 Do
              If FillPos < RowBytes Then Begin
                PlaneData[0][FillPos] := PatBuf[RepPlane];
                Inc(FillPos);
              End;
        End Else If B = $80 Then Begin
          Count := ReadByte;
          For RepRow := 1 To Count Do
            If FillPos < RowBytes Then Begin
              PlaneData[0][FillPos] := ReadByte;
              Inc(FillPos);
            End;
        End Else Begin
          Count := B And $7F;
          If (B And $80) <> 0 Then B := $FF Else B := $00;
          For RepRow := 1 To Count Do
            If FillPos < RowBytes Then Begin
              PlaneData[0][FillPos] := B;
              Inc(FillPos);
            End;
        End;
      End;
      For Plane := 1 To Planes - 1 Do
        DecodeScanline(PlaneData[Plane], RowBytes);
      For Col := 0 To ImgW - 1 Do Begin
        ByteIdx := Col Div 8;
        BitIdx  := 7 - (Col Mod 8);
        Color := 0;
        If Planes = 1 Then Begin
          If (PlaneData[0][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
            Color := 0
          Else
            Color := 15;
        End Else Begin
          For Plane := 0 To 3 Do
            If (PlaneData[Plane][ByteIdx] And (1 Shl BitIdx)) <> 0 Then
              Color := Color Or (1 Shl Plane);
        End;
        PutPixel(X + Col, Y + Row, Color);
      End;
      Inc(Row);
    End;
  End;

  Close(F);
  For Plane := 0 To 3 Do Begin
    SetLength(PlaneData[Plane], 0);
    SetLength(PrevPlanes[Plane], 0);
  End;
  Result := True;
End;

Function LoadTIF(FileName: String; X, Y: Integer): Boolean;
{ Load a baseline TIFF file at (X,Y).
  Supports: 4-bit palette (16-color EGA), 8-bit palette, 1-bit bilevel.
  Compression: none (1) or PackBits (32773).
  Byte order: little-endian (II) or big-endian (MM).
  Reference: TIFF 6.0 specification (Adobe, 1992) }
Var
  F: File;
  Magic: Array[0..3] Of Byte;
  BigEndian: Boolean;
  IFDOfs: LongWord;
  NumTags: Word;
  TagID, TagType: Word;
  TagCount, TagValue: LongWord;
  ImgW, ImgH: LongWord;
  BitsPerSample: Word;
  Compression: Word;
  PhotoInterp: Word;
  StripOffsets: LongWord;
  StripCount: LongWord;
  RowsPerStrip: LongWord;
  StripByteCounts: LongWord;
  SamplesPerPixel: Word;
  PaletteOfs: LongWord;
  PaletteCount: LongWord;
  I, Row, Col: Integer;
  StripOfsArr: Array Of LongWord;
  StripBCArr: Array Of LongWord;
  StripData: Array Of Byte;
  Palette: Array[0..255] Of Byte; { maps TIFF palette index → EGA 0-15 }
  TIFPal: Array[0..255, 0..2] Of Word; { R,G,B 16-bit values from TIFF }
  DataPos: LongWord;
  RB, RC: Byte;
  OutRow: Array Of Byte;
  PixVal: Byte;
  CurRow, CurStrip: Integer;
  StripRowStart: LongWord;
  BytesRead: LongWord;
  SavePos: LongWord;
  ActualRead: LongInt;

  Function Read16: Word;
  Var A, B: Byte;
  Begin
    BlockRead(F, A, 1);
    BlockRead(F, B, 1);
    If BigEndian Then
      Read16 := (Word(A) Shl 8) Or B
    Else
      Read16 := (Word(B) Shl 8) Or A;
  End;

  Function Read32: LongWord;
  Var W1, W2: Word;
  Begin
    W1 := Read16;
    W2 := Read16;
    If BigEndian Then
      Read32 := (LongWord(W1) Shl 16) Or W2
    Else
      Read32 := (LongWord(W2) Shl 16) Or W1;
  End;

  Function ReadTagValue(AType: Word; ACount: LongWord): LongWord;
  { Read a tag value — inline if it fits in 4 bytes, else offset }
  Var V: LongWord;
  Begin
    Case AType Of
      1, 2: Begin { BYTE / ASCII }
        BlockRead(F, V, 4);
        If BigEndian Then
          ReadTagValue := (V Shr 24) And $FF
        Else
          ReadTagValue := V And $FF;
      End;
      3: Begin { SHORT }
        ReadTagValue := Read16;
        If ACount = 1 Then Read16; { skip padding }
      End;
      4: ReadTagValue := Read32; { LONG }
    Else
      ReadTagValue := Read32;
    End;
  End;

  Function EGAFromRGB(R16, G16, B16: Word): Byte;
  { Map 16-bit RGB to nearest EGA color (0-15).
    EGA palette: 6-bit DAC (0-63 range), 16 standard colors. }
  Var
    R, G, B: Byte;
    Best, Dist, BestDist: Integer;
    ER, EG, EB: Integer;
  Const
    { Standard EGA palette RGB values (8-bit) }
    EGAR: Array[0..15] Of Byte = (  0,   0,   0,   0, 170, 170, 170, 170,
                                    85,  85,  85,  85, 255, 255, 255, 255);
    EGAG: Array[0..15] Of Byte = (  0,   0, 170, 170,   0,   0,  85, 170,
                                    85,  85, 255, 255,  85,  85, 255, 255);
    EGAB: Array[0..15] Of Byte = (  0, 170,   0, 170,   0, 170,   0, 170,
                                    85, 255,  85, 255,  85, 255,  85, 255);
  Begin
    R := R16 Shr 8;
    G := G16 Shr 8;
    B := B16 Shr 8;
    Best := 0;
    BestDist := MaxInt;
    For I := 0 To 15 Do Begin
      ER := Integer(R) - Integer(EGAR[I]);
      EG := Integer(G) - Integer(EGAG[I]);
      EB := Integer(B) - Integer(EGAB[I]);
      Dist := ER * ER + EG * EG + EB * EB;
      If Dist < BestDist Then Begin
        BestDist := Dist;
        Best := I;
      End;
    End;
    EGAFromRGB := Best;
  End;

  Procedure DecodePackBits(Var Src: Array Of Byte; SrcLen: LongWord;
                           Var Dst: Array Of Byte; DstLen: LongWord);
  { Apple PackBits decompression }
  Var SP, DP: LongWord;
      N: ShortInt;
      J: Integer;
  Begin
    SP := 0; DP := 0;
    While (SP < SrcLen) And (DP < DstLen) Do Begin
      N := ShortInt(Src[SP]); Inc(SP);
      If N >= 0 Then Begin
        { Copy N+1 literal bytes }
        For J := 0 To N Do
          If (SP < SrcLen) And (DP < DstLen) Then Begin
            Dst[DP] := Src[SP]; Inc(SP); Inc(DP);
          End;
      End Else If N > -128 Then Begin
        { Repeat next byte 1-N+1 times }
        If SP < SrcLen Then Begin
          For J := 0 To (1 - N) - 1 Do
            If DP < DstLen Then Begin
              Dst[DP] := Src[SP]; Inc(DP);
            End;
          Inc(SP);
        End;
      End;
      { N = -128: no-op }
    End;
  End;

Begin
  Result := False;
  Assign(F, FileName);
  {$I-} System.Reset(F, 1); {$I+}
  If IOResult <> 0 Then Exit;

  { Read byte order marker }
  BlockRead(F, Magic, 4);
  If (Magic[0] = Ord('I')) And (Magic[1] = Ord('I')) Then
    BigEndian := False
  Else If (Magic[0] = Ord('M')) And (Magic[1] = Ord('M')) Then
    BigEndian := True
  Else Begin Close(F); Exit; End;

  { Check magic number 42 }
  If BigEndian Then Begin
    If (Magic[2] <> 0) Or (Magic[3] <> 42) Then Begin Close(F); Exit; End;
  End Else Begin
    If (Magic[2] <> 42) Or (Magic[3] <> 0) Then Begin Close(F); Exit; End;
  End;

  { Read IFD offset }
  IFDOfs := Read32;
  Seek(F, IFDOfs);

  { Initialize defaults }
  ImgW := 0; ImgH := 0;
  BitsPerSample := 1;
  Compression := 1;
  PhotoInterp := 0;
  StripOffsets := 0; StripCount := 1;
  RowsPerStrip := $FFFFFFFF;
  StripByteCounts := 0;
  SamplesPerPixel := 1;
  PaletteOfs := 0; PaletteCount := 0;

  { Read IFD tags }
  NumTags := Read16;
  For I := 1 To NumTags Do Begin
    TagID   := Read16;
    TagType := Read16;
    TagCount := Read32;
    Case TagID Of
      256: ImgW := ReadTagValue(TagType, TagCount);           { ImageWidth }
      257: ImgH := ReadTagValue(TagType, TagCount);           { ImageLength }
      258: BitsPerSample := ReadTagValue(TagType, TagCount);  { BitsPerSample }
      259: Compression := ReadTagValue(TagType, TagCount);    { Compression }
      262: PhotoInterp := ReadTagValue(TagType, TagCount);    { PhotometricInterp }
      273: Begin                                               { StripOffsets }
        StripCount := TagCount;
        If TagCount = 1 Then
          StripOffsets := ReadTagValue(TagType, TagCount)
        Else Begin
          StripOffsets := Read32; { offset to array }
        End;
      End;
      277: SamplesPerPixel := ReadTagValue(TagType, TagCount); { SamplesPerPixel }
      278: RowsPerStrip := ReadTagValue(TagType, TagCount);    { RowsPerStrip }
      279: Begin                                               { StripByteCounts }
        If TagCount = 1 Then
          StripByteCounts := ReadTagValue(TagType, TagCount)
        Else Begin
          StripByteCounts := Read32; { offset to array }
        End;
      End;
      320: Begin                                               { ColorMap }
        PaletteCount := TagCount Div 3;
        PaletteOfs := Read32;
      End;
    Else
      Read32; { skip unknown tag value }
    End;
  End;

  { Validate }
  If (ImgW = 0) Or (ImgH = 0) Or (ImgW > 640) Or (ImgH > 350) Then Begin Close(F); Exit; End;
  If (Compression <> 1) And (Compression <> 32773) Then Begin Close(F); Exit; End;
  If SamplesPerPixel <> 1 Then Begin Close(F); Exit; End;
  If (BitsPerSample <> 1) And (BitsPerSample <> 4) And (BitsPerSample <> 8) Then Begin Close(F); Exit; End;

  { Read palette if present }
  FillChar(Palette, SizeOf(Palette), 0);
  If (PaletteOfs <> 0) And (PaletteCount > 0) Then Begin
    Seek(F, PaletteOfs);
    If PaletteCount > 256 Then PaletteCount := 256;
    { TIFF ColorMap: R[0..N-1], G[0..N-1], B[0..N-1] as 16-bit values }
    For I := 0 To PaletteCount - 1 Do
      TIFPal[I][0] := Read16; { R }
    For I := 0 To PaletteCount - 1 Do
      TIFPal[I][1] := Read16; { G }
    For I := 0 To PaletteCount - 1 Do
      TIFPal[I][2] := Read16; { B }
    For I := 0 To PaletteCount - 1 Do
      Palette[I] := EGAFromRGB(TIFPal[I][0], TIFPal[I][1], TIFPal[I][2]);
  End Else Begin
    { No palette — bilevel or direct mapping }
    For I := 0 To 15 Do
      Palette[I] := I;
  End;

  { Read strip offsets and byte counts }
  SetLength(StripOfsArr, StripCount);
  SetLength(StripBCArr, StripCount);
  If StripCount = 1 Then Begin
    StripOfsArr[0] := StripOffsets;
    StripBCArr[0] := StripByteCounts;
  End Else Begin
    Seek(F, StripOffsets);
    For I := 0 To StripCount - 1 Do
      StripOfsArr[I] := Read32;
    Seek(F, StripByteCounts);
    For I := 0 To StripCount - 1 Do
      StripBCArr[I] := Read32;
  End;

  { Decode strips and render }
  SetLength(OutRow, ImgW);
  CurRow := 0;

  For CurStrip := 0 To StripCount - 1 Do Begin
    If CurRow >= Integer(ImgH) Then Break;
    Seek(F, StripOfsArr[CurStrip]);

    If Compression = 1 Then Begin
      { Uncompressed }
      While CurRow < Integer(ImgH) Do Begin
        If CurRow >= Integer(StripRowStart + RowsPerStrip) Then Break;
        Case BitsPerSample Of
          1: Begin
            For Col := 0 To Integer(ImgW) - 1 Do Begin
              If (Col Mod 8) = 0 Then
                BlockRead(F, RB, 1);
              If (RB And ($80 Shr (Col Mod 8))) <> 0 Then Begin
                If PhotoInterp = 0 Then PixVal := 0 Else PixVal := 15;
              End Else Begin
                If PhotoInterp = 0 Then PixVal := 15 Else PixVal := 0;
              End;
              PutPixel(X + Col, Y + CurRow, PixVal);
            End;
          End;
          4: Begin
            Col := 0;
            While Col < Integer(ImgW) Do Begin
              BlockRead(F, RB, 1);
              PixVal := Palette[(RB Shr 4) And $0F];
              PutPixel(X + Col, Y + CurRow, PixVal);
              Inc(Col);
              If Col < Integer(ImgW) Then Begin
                PixVal := Palette[RB And $0F];
                PutPixel(X + Col, Y + CurRow, PixVal);
                Inc(Col);
              End;
            End;
          End;
          8: Begin
            For Col := 0 To Integer(ImgW) - 1 Do Begin
              BlockRead(F, RB, 1);
              PutPixel(X + Col, Y + CurRow, Palette[RB]);
            End;
          End;
        End;
        Inc(CurRow);
      End;
    End Else Begin
      { PackBits compressed }
      SetLength(StripData, StripBCArr[CurStrip]);
      BlockRead(F, StripData[0], StripBCArr[CurStrip]);
      { Decompress entire strip }
      BytesRead := 0;
      Case BitsPerSample Of
        1: BytesRead := ((ImgW + 7) Div 8) * RowsPerStrip;
        4: BytesRead := ((ImgW + 1) Div 2) * RowsPerStrip;
        8: BytesRead := ImgW * RowsPerStrip;
      End;
      If BytesRead > ImgW * ImgH Then
        BytesRead := ImgW * ImgH;
      SetLength(OutRow, BytesRead);
      DecodePackBits(StripData, StripBCArr[CurStrip], OutRow, BytesRead);
      DataPos := 0;
      While (CurRow < Integer(ImgH)) And (DataPos < BytesRead) Do Begin
        Case BitsPerSample Of
          1: Begin
            For Col := 0 To Integer(ImgW) - 1 Do Begin
              RB := OutRow[DataPos + (Col Div 8)];
              If (RB And ($80 Shr (Col Mod 8))) <> 0 Then Begin
                If PhotoInterp = 0 Then PixVal := 0 Else PixVal := 15;
              End Else Begin
                If PhotoInterp = 0 Then PixVal := 15 Else PixVal := 0;
              End;
              PutPixel(X + Col, Y + CurRow, PixVal);
            End;
            Inc(DataPos, (ImgW + 7) Div 8);
          End;
          4: Begin
            Col := 0;
            While Col < Integer(ImgW) Do Begin
              RB := OutRow[DataPos]; Inc(DataPos);
              PixVal := Palette[(RB Shr 4) And $0F];
              PutPixel(X + Col, Y + CurRow, PixVal);
              Inc(Col);
              If Col < Integer(ImgW) Then Begin
                PixVal := Palette[RB And $0F];
                PutPixel(X + Col, Y + CurRow, PixVal);
                Inc(Col);
              End;
            End;
          End;
          8: Begin
            For Col := 0 To Integer(ImgW) - 1 Do Begin
              PutPixel(X + Col, Y + CurRow, Palette[OutRow[DataPos]]);
              Inc(DataPos);
            End;
          End;
        End;
        Inc(CurRow);
      End;
      SetLength(StripData, 0);
    End;
  End;

  Close(F);
  SetLength(StripOfsArr, 0);
  SetLength(StripBCArr, 0);
  SetLength(OutRow, 0);
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
  Else If Ext = '.PCX' Then
    Result := False { PCX cache not yet — render direct via LoadPCX }
  Else If Ext = '.IMG' Then
    Result := False { IMG — render direct via LoadIMG }
  Else If (Ext = '.TIF') Or (Ext = '.TIFF') Then
    Result := False { TIFF — render direct via LoadTIF }
  Else
    Result := False;
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

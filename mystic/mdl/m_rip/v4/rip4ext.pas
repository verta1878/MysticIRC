{$MODE DELPHI}
{$H-}
Unit RIP4Ext;
{ RIPscrip v4.0 Extensions — IRC fork
  Imports v1 shared base. Does NOT import v2 or v3 — flat hierarchy.
  Adds: JPEG/PNG/GIF image loading, HTML rendering, print output,
  MPEG frame rendering, streaming JPEG decode.

  HTML rendering is our IRC extension (5-unit stack, 1,814 lines):
    htmlpars → htmltree → htmllayo → htmlrip/htmlrend
  Not in any TeleGrafix spec — we built it.

  Source reference: attic/rip_v2v3v4_monolith/rip4api.pas (8633 lines)
  This unit extracts only the v4-specific extensions.

  Copyright (C) 2026 - GPLv3
  The Crew: verta1878, sysop/0, evga, kiddo, wrench
}

Interface

Uses
  RIPEngine;

{ Image Loading — renders image data into Canvas pixel buffer }
Function  LoadJPEG(FileName: String; X, Y: Integer): Boolean;
Function  LoadGIF(FileName: String; X, Y: Integer): Boolean;
Function  LoadGIFFrame(FileName: String; X, Y: Integer; Frame: Integer): Boolean;
Function  LoadPNG(FileName: String; X, Y: Integer): Boolean;

{ Streaming JPEG — for progressive decode over network }
Procedure JPEGStreamInit;
Function  JPEGStreamFeed(Data: PByte; Size: Integer; X, Y: Integer): Boolean;
Function  JPEGStreamComplete: Boolean;
Procedure JPEGStreamDone;

{ HTML Rendering — 5-unit stack, IRC extension }
Procedure HTMLRenderPage(Source: PChar; Len: LongInt);
Procedure HTMLRenderToRIP(Source: PChar; Len: LongInt);

{ Print — render Canvas to printer }
Procedure PrintPage(Driver: Byte; DPI: Word; X, Y, W, H: Integer);

{ MPEG — render single frame }
Procedure MPEGRenderFrame(FrameIdx: LongInt);

Implementation

Uses
  SysUtils,
  htmlpars, htmltree, htmllayo, htmlrend, htmlrip,
  jpgdecr, pngdecr, gifdecr,
  prnapi,
  mpgvdec, mpgdemux, mpgvbuf;

{ === JPEG — wired to jpgdecr === }

Function LoadJPEG(FileName: String; X, Y: Integer): Boolean;
Var
  Pixels: PByte;
  W, H: LongWord;
  IX, IY, I: Integer;
  R, G, B, BestCol: Byte;
  BestDist, Dist: LongInt;
  PR, PG, PB: Byte;
Begin
  Result := False;
  If Not FileExists(FileName) Then Exit;
  Pixels := Nil; W := 0; H := 0;
  If Not JPEGLoadFileRaw(FileName, Pixels, W, H) Then Exit;
  If (Pixels = Nil) Or (W = 0) Or (H = 0) Then Exit;
  { Blit RGB24 to Canvas with nearest EGA color }
  For IY := 0 To Integer(H) - 1 Do
    For IX := 0 To Integer(W) - 1 Do Begin
      I := (IY * Integer(W) + IX) * 3;
      R := Pixels[I]; G := Pixels[I+1]; B := Pixels[I+2];
      BestCol := 0; BestDist := MaxLongInt;
      For I := 0 To 15 Do Begin
        PR := Canvas.Palette[I] And $FF;
        PG := (Canvas.Palette[I] Shr 8) And $FF;
        PB := (Canvas.Palette[I] Shr 16) And $FF;
        Dist := LongInt(Abs(R-PR)) + Abs(G-PG) + Abs(B-PB);
        If Dist < BestDist Then Begin BestDist := Dist; BestCol := I; End;
      End;
      If (X+IX >= 0) And (X+IX < RIP_WIDTH) And (Y+IY >= 0) And (Y+IY < RIP_HEIGHT) Then
        Canvas.Pixels^[X+IX, Y+IY] := BestCol;
    End;
  FreeMem(Pixels);
  Result := True;
End;

{ === GIF — wired to gifdecr === }

Function LoadGIF(FileName: String; X, Y: Integer): Boolean;
Begin
  Result := LoadGIFFrame(FileName, X, Y, 0);
End;

Function LoadGIFFrame(FileName: String; X, Y: Integer; Frame: Integer): Boolean;
Var
  GIF: TGIFImage;
  RGB: PByte;
  W, H: Integer;
  IX, IY, I: Integer;
  R, G, B, BestCol: Byte;
  BestDist, Dist: LongInt;
  PR, PG, PB: Byte;
Begin
  Result := False;
  If Not FileExists(FileName) Then Exit;
  If Not GIFLoadFileRaw(FileName, GIF) Then Exit;
  W := GIF.Width; H := GIF.Height;
  GetMem(RGB, W * H * 3);
  GIFFrameToRGB(GIF, Frame, RGB, W * 3);
  For IY := 0 To H - 1 Do
    For IX := 0 To W - 1 Do Begin
      I := (IY * W + IX) * 3;
      R := RGB[I]; G := RGB[I+1]; B := RGB[I+2];
      BestCol := 0; BestDist := MaxLongInt;
      For I := 0 To 15 Do Begin
        PR := Canvas.Palette[I] And $FF;
        PG := (Canvas.Palette[I] Shr 8) And $FF;
        PB := (Canvas.Palette[I] Shr 16) And $FF;
        Dist := LongInt(Abs(R-PR)) + Abs(G-PG) + Abs(B-PB);
        If Dist < BestDist Then Begin BestDist := Dist; BestCol := I; End;
      End;
      If (X+IX >= 0) And (X+IX < RIP_WIDTH) And (Y+IY >= 0) And (Y+IY < RIP_HEIGHT) Then
        Canvas.Pixels^[X+IX, Y+IY] := BestCol;
    End;
  FreeMem(RGB);
  GIFFreeRaw(GIF);
  Result := True;
End;

{ === PNG — wired to pngdecr === }

Function LoadPNG(FileName: String; X, Y: Integer): Boolean;
Var
  Pixels: PByte;
  W, H: LongWord;
  IX, IY, I: Integer;
  R, G, B, BestCol: Byte;
  BestDist, Dist: LongInt;
  PR, PG, PB: Byte;
Begin
  Result := False;
  If Not FileExists(FileName) Then Exit;
  Pixels := Nil; W := 0; H := 0;
  If Not PNGLoadFileRaw(FileName, Pixels, W, H) Then Exit;
  If (Pixels = Nil) Or (W = 0) Or (H = 0) Then Exit;
  For IY := 0 To Integer(H) - 1 Do
    For IX := 0 To Integer(W) - 1 Do Begin
      I := (IY * Integer(W) + IX) * 3;
      R := Pixels[I]; G := Pixels[I+1]; B := Pixels[I+2];
      BestCol := 0; BestDist := MaxLongInt;
      For I := 0 To 15 Do Begin
        PR := Canvas.Palette[I] And $FF;
        PG := (Canvas.Palette[I] Shr 8) And $FF;
        PB := (Canvas.Palette[I] Shr 16) And $FF;
        Dist := LongInt(Abs(R-PR)) + Abs(G-PG) + Abs(B-PB);
        If Dist < BestDist Then Begin BestDist := Dist; BestCol := I; End;
      End;
      If (X+IX >= 0) And (X+IX < RIP_WIDTH) And (Y+IY >= 0) And (Y+IY < RIP_HEIGHT) Then
        Canvas.Pixels^[X+IX, Y+IY] := BestCol;
    End;
  FreeMem(Pixels);
  Result := True;
End;

{ === Streaming JPEG — wired to jpgdecr === }

Var
  StreamState: TJPEGStreamRaw;
  StreamActive: Boolean;

Procedure JPEGStreamInit;
Begin
  JPEGStreamInitRaw(StreamState);
  StreamActive := True;
End;

Function JPEGStreamFeed(Data: PByte; Size: Integer; X, Y: Integer): Boolean;
Begin
  Result := StreamActive;
  If Not StreamActive Then Exit;
  Result := JPEGStreamFeedRaw(StreamState, Data, Size);
  { TODO: blit partial decode to Canvas at X,Y }
End;

Function JPEGStreamComplete: Boolean;
Begin
  Result := Not StreamActive;
End;

Procedure JPEGStreamDone;
Begin
  StreamActive := False;
End;

{ === HTML — wired to 5-unit stack === }

Procedure HTMLRenderPage(Source: PChar; Len: LongInt);
{ Parse HTML and render directly to Canvas pixel buffer.
  Pipeline: htmlpars → htmltree → htmllayo → htmlrend.
  Converts RGB24 output to EGA 16-color for the Canvas. }
Var
  Parser  : THTMLParser;
  Tree    : THTMLTree;
  Layout  : THTMLLayout;
  PixBuf  : Array Of Byte;
  BufSize : LongInt;
  X, Y, I : Integer;
  R, G, B : Byte;
  BestCol : Byte;
  BestDist, Dist: LongInt;
  PR, PG, PB: Byte;
Begin
  If (Source = Nil) Or (Len <= 0) Then Exit;

  { Allocate RGB24 buffer for htmlrend output }
  BufSize := LongInt(RIP_WIDTH) * RIP_HEIGHT * 3;
  SetLength(PixBuf, BufSize);
  FillChar(PixBuf[0], BufSize, 0);

  { Run the pipeline }
  HTMLRenderToBuffer(Source, Len, @PixBuf[0], RIP_WIDTH, RIP_HEIGHT);

  { Convert RGB24 → EGA 16-color and blit to Canvas }
  For Y := 0 To RIP_HEIGHT - 1 Do
    For X := 0 To RIP_WIDTH - 1 Do Begin
      I := (Y * RIP_WIDTH + X) * 3;
      R := PixBuf[I];
      G := PixBuf[I + 1];
      B := PixBuf[I + 2];
      { Skip black pixels (background) }
      If (R = 0) And (G = 0) And (B = 0) Then Continue;
      { Find nearest EGA color }
      BestCol := 0;
      BestDist := MaxLongInt;
      For I := 0 To 15 Do Begin
        PR := Canvas.Palette[I] And $FF;
        PG := (Canvas.Palette[I] Shr 8) And $FF;
        PB := (Canvas.Palette[I] Shr 16) And $FF;
        Dist := LongInt(Abs(R - PR)) + Abs(G - PG) + Abs(B - PB);
        If Dist < BestDist Then Begin
          BestDist := Dist;
          BestCol := I;
        End;
      End;
      Canvas.Pixels^[X, Y] := BestCol;
    End;

  SetLength(PixBuf, 0);
End;

Procedure HTMLRenderToRIP(Source: PChar; Len: LongInt);
{ Convert HTML to RIP commands — delegates to HTMLRenderPage for now.
  Future: generate actual RIP command stream via htmlrip.pas. }
Begin
  HTMLRenderPage(Source, Len);
End;

{ === Print — wired to prnapi === }

Procedure PrintPage(Driver: Byte; DPI: Word; X, Y, W, H: Integer);
Var
  Cfg: TPrnConfig;
  Page: TPrnPage;
  IX, IY: Integer;
  PalEntry: LongWord;
Begin
  PrnInitConfig(Cfg, TPrnDriver(Driver), DPI);
  { Build page from Canvas region }
  Page.Width := W;
  Page.Height := H;
  Page.BPP := 24;
  GetMem(Page.Pixels, W * H * 3);
  For IY := 0 To H - 1 Do
    For IX := 0 To W - 1 Do Begin
      PalEntry := Canvas.Palette[Canvas.Pixels^[X + IX, Y + IY]];
      Page.Pixels[(IY * W + IX) * 3]     := PalEntry And $FF;         { R }
      Page.Pixels[(IY * W + IX) * 3 + 1] := (PalEntry Shr 8) And $FF; { G }
      Page.Pixels[(IY * W + IX) * 3 + 2] := (PalEntry Shr 16) And $FF;{ B }
    End;
  { TODO: call driver open/send/close once printer output path is configured }
  FreeMem(Page.Pixels);
End;

{ === MPEG — wired to mpgvdec + mpgvbuf (YUV→RGB→EGA) === }

Procedure MPEGFrameToCanvas(Var Frame: TMPGFrame; UserData: Pointer);
{ Callback from MPGVideoDecode — blits decoded RGB frame to Canvas }
Var
  IX, IY, I: Integer;
  W, H: Integer;
  R, G, B, BestCol: Byte;
  BestDist, Dist: LongInt;
  PR, PG, PB: Byte;
Begin
  If Frame.RGB = Nil Then Exit;
  W := Frame.Y.Width;
  H := Frame.Y.Height;
  If W > RIP_WIDTH Then W := RIP_WIDTH;
  If H > RIP_HEIGHT Then H := RIP_HEIGHT;
  For IY := 0 To H - 1 Do
    For IX := 0 To W - 1 Do Begin
      I := (IY * Frame.Y.Width + IX) * 3;
      R := Frame.RGB[I]; G := Frame.RGB[I+1]; B := Frame.RGB[I+2];
      BestCol := 0; BestDist := MaxLongInt;
      For I := 0 To 15 Do Begin
        PR := Canvas.Palette[I] And $FF;
        PG := (Canvas.Palette[I] Shr 8) And $FF;
        PB := (Canvas.Palette[I] Shr 16) And $FF;
        Dist := LongInt(Abs(R-PR)) + Abs(G-PG) + Abs(B-PB);
        If Dist < BestDist Then Begin BestDist := Dist; BestCol := I; End;
      End;
      Canvas.Pixels^[IX, IY] := BestCol;
    End;
End;

Procedure MPEGRenderFrame(FrameIdx: LongInt);
Begin
  { Caller must set up decoder and call MPGVideoDecode with
    MPEGFrameToCanvas as the callback. FrameIdx selects which
    picture to decode. Full pipeline:
    mpgdemux (extract video stream) → mpgvdec (decode I/P/B frames)
    → mpgvbuf (YUV→RGB via MPGYUVtoRGB) → MPEGFrameToCanvas (RGB→EGA blit) }
End;

Begin
  StreamActive := False;
End.

// ====================================================================
// mystic_rip : optional RIPscrip graphics example for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// rip_window - TRipWindow: SDL2 presenter for a TRipSurface.  Owns no
// drawing logic: it uploads the surface's 640x350 software buffer as
// an ARGB streaming texture, scales it to the window (aspect-
// correcting the non-square EGA pixels: presented at 640x480-based
// sizing), and turns mouse clicks into RIP hot-region actions.
//
// Exactly the TDosScreen present pattern (sdl_dosscreen.pas) with the
// RIP graphics buffer in place of the 80x25 text grid, and the same
// rules: SDL2 is runtime-loaded through sdl_bind (never linked),
// everything degrades gracefully when SDL or a display is absent.
//
// OnRegionClick fires with the region's send-string - the demo prints
// it; a live client wires it to the connection so the click types the
// string at the host (that is the whole RIP button model).
//
// Ported from ripterm_client_v0 (RipWindow.pas), the maintainer's
// clean-room RIP client, moved from its compile-time SDL binding onto
// the module's runtime-loading sdl_bind.
// ====================================================================

Unit rip_Window;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  SysUtils,
  rip_Canvas,
  rip_Surface,
  m_sdl_bind;

Type
  TRegionClickEvent = Procedure (Const SendText: AnsiString) of Object;

  TRipWindow = Class
  Private
    FWin  : PSDL_Window;
    FRen  : PSDL_Renderer;
    FTex  : PSDL_Texture;
    FSurf : TRipSurface;                 // the software canvas (not owned)
    FArgb : Array of LongWord;           // surface converted to ARGB
    FWinW : Integer;                     // window pixel size
    FWinH : Integer;                     //   (aspect-corrected)
    FOnRegionClick : TRegionClickEvent;

    Procedure UploadBuffer;
    Procedure HandleClick (WinX, WinY: Integer);
  Public
    Constructor Create (ASurf: TRipSurface);
    Destructor  Destroy; Override;

    Function  Open (Const Title: String): Boolean;
    Procedure Present;                   // upload + draw one frame
    Function  Pump: Boolean;             // process events; False = quit

    Property  OnRegionClick : TRegionClickEvent Read FOnRegionClick Write FOnRegionClick;
  End;

Implementation

Constructor TRipWindow.Create (ASurf: TRipSurface);
Begin
  Inherited Create;

  FSurf := ASurf;

  // EGA 640x350 has non-square pixels; present on a 640x480 square-
  // pixel basis (Y * 480/350), then scale the whole window 1.4x so it
  // is comfortable on modern displays.  Fixed size keeps the click
  // mapping exact.
  FWinW := Round(RIP_WIDTH * 1.4);
  FWinH := Round(480 * 1.4);

  FWin := Nil;
  FRen := Nil;
  FTex := Nil;

  SetLength (FArgb, RIP_WIDTH * RIP_HEIGHT);
End;

Destructor TRipWindow.Destroy;
Begin
  If SDLLoaded Then Begin
    If FTex <> Nil Then SDL_DestroyTexture (FTex);
    If FRen <> Nil Then SDL_DestroyRenderer (FRen);
    If FWin <> Nil Then SDL_DestroyWindow (FWin);
  End;

  Inherited Destroy;
End;

Function TRipWindow.Open (Const Title: String): Boolean;
Begin
  Result := False;

  If Not LoadSDL Then Exit;
  If SDL_Init(SDL_INIT_VIDEO) <> 0 Then Exit;

  FWin := SDL_CreateWindow (PChar(Title),
            SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
            FWinW, FWinH, SDL_WINDOW_SHOWN);
  If FWin = Nil Then Exit;

  FRen := SDL_CreateRenderer (FWin, -1, 0);
  If FRen = Nil Then Exit;

  // the texture is native RIP resolution; the renderer scales it to
  // the (aspect-corrected) window
  FTex := SDL_CreateTexture (FRen, SDL_PIXELFORMAT_ARGB8888,
            SDL_TEXTUREACCESS_STREAMING, RIP_WIDTH, RIP_HEIGHT);

  Result := FTex <> Nil;
End;

Procedure TRipWindow.UploadBuffer;
Var
  X, Y : Integer;
  P    : TRipRGB;
Begin
  For Y := 0 to RIP_HEIGHT - 1 Do
    For X := 0 to RIP_WIDTH - 1 Do Begin
      P := FSurf.RawPixel(X, Y);

      FArgb[Y * RIP_WIDTH + X] := $FF000000 Or (LongWord(P.R) Shl 16) Or
                                  (LongWord(P.G) Shl 8) Or LongWord(P.B);
    End;

  SDL_UpdateTexture (FTex, Nil, @FArgb[0], RIP_WIDTH * 4);
End;

Procedure TRipWindow.Present;
Begin
  If FTex = Nil Then Exit;

  UploadBuffer;

  SDL_RenderClear (FRen);
  SDL_RenderCopy (FRen, FTex, Nil, Nil);   // full texture -> full window
  SDL_RenderPresent (FRen);
End;

// Map a window-space click back to RIP 640x350 coordinates, then hit-
// test the surface's hot regions.
Procedure TRipWindow.HandleClick (WinX, WinY: Integer);
Var
  I      : Integer;
  R      : TRipMouseRegion;
  RX, RY : Integer;
Begin
  RX := Round(WinX / FWinW * RIP_WIDTH);
  RY := Round(WinY / FWinH * RIP_HEIGHT);

  For I := 0 to FSurf.RegionCount - 1 Do Begin
    R := FSurf.Region(I);

    If (RX >= R.X0) And (RX <= R.X1) And (RY >= R.Y0) And (RY <= R.Y1) Then Begin
      If Assigned(FOnRegionClick) Then
        FOnRegionClick (R.Text)
      Else
        WriteLn ('Region clicked -> sends: ',
                 StringReplace(R.Text, #13, '\r', [rfReplaceAll]));
      Exit;
    End;
  End;
End;

Function TRipWindow.Pump: Boolean;
Var
  Ev : TSDL_Event;
Begin
  Result := True;

  If Not Assigned(SDL_PollEvent) Then Exit;

  While SDL_PollEvent(Ev) <> 0 Do
    Case Ev.EventType of
      SDL_QUIT_EVENT      : Result := False;
      SDL_KEYDOWN         : Result := False;   // any key exits the demo
      SDL_MOUSEBUTTONDOWN : HandleClick (EventMouseX(Ev), EventMouseY(Ev));
    End;
End;

End.

// ====================================================================
// mystic_sdl : optional SDL2 DOS-session front-end for Mystic BBS A38
// ====================================================================
//
// This file is part of an optional add-on module for Mystic BBS and is
// released under the same GNU General Public License v3 as Mystic BBS.
// Mystic BBS is Copyright 1997-2013 By James Coyle.
//
// sdl_bind - a minimal SDL2 binding, loaded at RUNTIME (dlopen / LoadLibrary)
// so this unit compiles with no SDL present and fails gracefully if the
// library is missing.  Same drop-in-the-library model as Hunspell/cryptlib and
// the same toolkit g00r00 uses for the NetRunner terminal.
//
// Only the handful of SDL2 entry points a text/DOS emulator needs are bound:
// init, window, renderer, texture streaming, and the event queue.
// ====================================================================

Unit sdl_Bind;

{$IFDEF FPC}{$MODE OBJFPC}{$H+}{$ENDIF}

Interface

Uses
  {$IFDEF WINDOWS} Windows, {$ENDIF}
  {$IFDEF OS2} DosCalls, {$ENDIF}
  SysUtils;

{$IFDEF UNIX}
Const
  RTLD_NOW = 2;
Function dlopen (Name: PChar; Flags: LongInt): Pointer; cdecl; external 'c';
Function dlsym (Handle: Pointer; Name: PChar): Pointer; cdecl; external 'c';
Function dlclose (Handle: Pointer): LongInt; cdecl; external 'c';
{$ENDIF}

Const
  SDL_INIT_VIDEO   = $00000020;
  SDL_WINDOWPOS_CENTERED = $2FFF0000;
  SDL_WINDOW_SHOWN = $00000004;
  SDL_QUIT_EVENT   = $100;
  SDL_KEYDOWN      = $300;
  SDL_MOUSEBUTTONDOWN = $401;
  SDL_TEXTUREACCESS_STREAMING = 1;
  SDL_PIXELFORMAT_ARGB8888 = $16362004;

Type
  PSDL_Window   = Pointer;
  PSDL_Renderer = Pointer;
  PSDL_Texture  = Pointer;

  // The real SDL_Event union is 56 bytes; allocate generously (128) so
  // SDL_PollEvent never writes past our buffer.
  TSDL_Event = Record
    EventType : LongWord;
    Pad       : Array[0..127] of Byte;
  End;

  TFnInit         = Function (flags: LongWord): LongInt; cdecl;
  TFnQuit         = Procedure; cdecl;
  TFnCreateWindow = Function (title: PChar; x, y, w, h: LongInt; flags: LongWord): PSDL_Window; cdecl;
  TFnDestroyWindow= Procedure (win: PSDL_Window); cdecl;
  TFnCreateRenderer=Function (win: PSDL_Window; index: LongInt; flags: LongWord): PSDL_Renderer; cdecl;
  TFnDestroyRenderer=Procedure (r: PSDL_Renderer); cdecl;
  TFnCreateTexture= Function (r: PSDL_Renderer; fmt: LongWord; access, w, h: LongInt): PSDL_Texture; cdecl;
  TFnDestroyTexture=Procedure (t: PSDL_Texture); cdecl;
  TFnUpdateTexture= Function (t: PSDL_Texture; rect: Pointer; pixels: Pointer; pitch: LongInt): LongInt; cdecl;
  TFnRenderClear  = Function (r: PSDL_Renderer): LongInt; cdecl;
  TFnRenderCopy   = Function (r: PSDL_Renderer; t: PSDL_Texture; src, dst: Pointer): LongInt; cdecl;
  TFnRenderPresent= Procedure (r: PSDL_Renderer); cdecl;
  TFnPollEvent    = Function (Var ev: TSDL_Event): LongInt; cdecl;
  TFnDelay        = Procedure (ms: LongWord); cdecl;
  TFnGetError     = Function : PChar; cdecl;

Var
  SDL_Init            : TFnInit          = Nil;
  SDL_Quit            : TFnQuit          = Nil;
  SDL_CreateWindow    : TFnCreateWindow  = Nil;
  SDL_DestroyWindow   : TFnDestroyWindow = Nil;
  SDL_CreateRenderer  : TFnCreateRenderer= Nil;
  SDL_DestroyRenderer : TFnDestroyRenderer=Nil;
  SDL_CreateTexture   : TFnCreateTexture = Nil;
  SDL_DestroyTexture  : TFnDestroyTexture= Nil;
  SDL_UpdateTexture   : TFnUpdateTexture = Nil;
  SDL_RenderClear     : TFnRenderClear   = Nil;
  SDL_RenderCopy      : TFnRenderCopy    = Nil;
  SDL_RenderPresent   : TFnRenderPresent = Nil;
  SDL_PollEvent       : TFnPollEvent     = Nil;
  SDL_Delay           : TFnDelay         = Nil;
  SDL_GetError        : TFnGetError      = Nil;

Function LoadSDL (Const LibName: String = ''): Boolean;
Procedure UnloadSDL;
Function SDLLoaded: Boolean;

// Decode window-space mouse coordinates from an SDL_MOUSEBUTTONDOWN
// event.  TSDL_Event is kept opaque (type + padding); these read the
// SDL_MouseButtonEvent layout out of the padding: after the 4-byte
// type come timestamp(4) windowID(4) which(4) button(1) state(1)
// clicks(1) pad(1), then x and y as signed 32-bit ints (offsets 16
// and 20 into the padding).  Stable across SDL 2.0.x.
Function EventMouseX (Const Ev: TSDL_Event): LongInt;
Function EventMouseY (Const Ev: TSDL_Event): LongInt;

Implementation

Var
  {$IFDEF UNIX} LibHandle : Pointer = Nil;
  {$ELSE} {$IFDEF OS2} LibHandle : THandle = 0;
  {$ELSE} LibHandle : HModule = 0; {$ENDIF} {$ENDIF}
  Loaded : Boolean = False;

Function LibOpen: Boolean;
Begin
  {$IFDEF UNIX} LibOpen := LibHandle <> Nil; {$ELSE} LibOpen := LibHandle <> 0; {$ENDIF}
End;

Function Sym (Const Name: String): Pointer;
Begin
  {$IFDEF UNIX} Sym := dlsym(LibHandle, PChar(Name));
  {$ELSE}
    {$IFDEF OS2}
      If DosQueryProcAddr(LibHandle, 0, PChar(Name), Sym) <> 0 Then Sym := Nil;
    {$ELSE}
      Sym := GetProcAddress(LibHandle, PChar(Name));
    {$ENDIF}
  {$ENDIF}
End;

Function TryOpen (Const N: String): Boolean;
{$IFDEF OS2}
Var
  FailName : Array[0..259] of Char;
{$ENDIF}
Begin
  {$IFDEF UNIX}
    LibHandle := dlopen(PChar(N), RTLD_NOW);
  {$ELSE}
    {$IFDEF OS2}
      If DosLoadModule(FailName, SizeOf(FailName), PChar(N), LibHandle) <> 0 Then
        LibHandle := 0;
    {$ELSE}
      LibHandle := LoadLibrary(PChar(N));
    {$ENDIF}
  {$ENDIF}
  TryOpen := LibOpen;
End;

Function LoadSDL (Const LibName: String): Boolean;

  Function DefaultNames: Boolean;
  Begin
    Result := True;
    {$IFDEF UNIX}
      {$IFDEF DARWIN}
        If TryOpen('libSDL2-2.0.0.dylib') Then Exit;
        If TryOpen('libSDL2.dylib')       Then Exit;
      {$ELSE}
        If TryOpen('libSDL2-2.0.so.0')    Then Exit;
        If TryOpen('libSDL2.so')          Then Exit;
      {$ENDIF}
    {$ELSE}
      If TryOpen('SDL2.dll')              Then Exit;
    {$ENDIF}
    Result := False;
  End;

Begin
  Result := False;
  If Loaded Then Begin Result := True; Exit; End;

  If LibName <> '' Then Begin
    If Not TryOpen(LibName) Then Exit;
  End Else
    If Not DefaultNames Then Exit;

  SDL_Init            := TFnInit          (Sym('SDL_Init'));
  SDL_Quit            := TFnQuit          (Sym('SDL_Quit'));
  SDL_CreateWindow    := TFnCreateWindow  (Sym('SDL_CreateWindow'));
  SDL_DestroyWindow   := TFnDestroyWindow (Sym('SDL_DestroyWindow'));
  SDL_CreateRenderer  := TFnCreateRenderer(Sym('SDL_CreateRenderer'));
  SDL_DestroyRenderer := TFnDestroyRenderer(Sym('SDL_DestroyRenderer'));
  SDL_CreateTexture   := TFnCreateTexture (Sym('SDL_CreateTexture'));
  SDL_DestroyTexture  := TFnDestroyTexture(Sym('SDL_DestroyTexture'));
  SDL_UpdateTexture   := TFnUpdateTexture (Sym('SDL_UpdateTexture'));
  SDL_RenderClear     := TFnRenderClear   (Sym('SDL_RenderClear'));
  SDL_RenderCopy      := TFnRenderCopy    (Sym('SDL_RenderCopy'));
  SDL_RenderPresent   := TFnRenderPresent (Sym('SDL_RenderPresent'));
  SDL_PollEvent       := TFnPollEvent     (Sym('SDL_PollEvent'));
  SDL_Delay           := TFnDelay         (Sym('SDL_Delay'));
  SDL_GetError        := TFnGetError      (Sym('SDL_GetError'));

  If (SDL_Init = Nil) or (SDL_CreateWindow = Nil) or (SDL_CreateRenderer = Nil) or
     (SDL_CreateTexture = Nil) or (SDL_UpdateTexture = Nil) or
     (SDL_RenderCopy = Nil) or (SDL_RenderPresent = Nil) Then Begin
    UnloadSDL;
    Exit;
  End;

  Loaded := True;
  Result := True;
End;

Procedure UnloadSDL;
Begin
  If LibOpen Then Begin
    {$IFDEF UNIX} dlclose(LibHandle); LibHandle := Nil;
    {$ELSE}
      {$IFDEF OS2} DosFreeModule(LibHandle); {$ELSE} FreeLibrary(LibHandle); {$ENDIF}
      LibHandle := 0;
    {$ENDIF}
  End;
  SDL_Init := Nil; SDL_Quit := Nil;
  SDL_CreateWindow := Nil; SDL_DestroyWindow := Nil;
  SDL_CreateRenderer := Nil; SDL_DestroyRenderer := Nil;
  SDL_CreateTexture := Nil; SDL_DestroyTexture := Nil;
  SDL_UpdateTexture := Nil; SDL_RenderClear := Nil;
  SDL_RenderCopy := Nil; SDL_RenderPresent := Nil;
  SDL_PollEvent := Nil; SDL_Delay := Nil; SDL_GetError := Nil;
  Loaded := False;
End;

Function SDLLoaded: Boolean;
Begin SDLLoaded := Loaded; End;

Function EventMouseX (Const Ev: TSDL_Event): LongInt;
Begin
  Move (Ev.Pad[16], Result, 4);
End;

Function EventMouseY (Const Ev: TSDL_Event): LongInt;
Begin
  Move (Ev.Pad[20], Result, 4);
End;

End.

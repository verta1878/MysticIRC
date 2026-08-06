//
// This file is part of the Mystic BBS IRC Fork.
//
// Copyright (C) 2026 Mystic BBS IRC Fork Contributors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
Unit SDL;

// ====================================================================
// Minimal SDL 1.2 header — just enough types and function declarations
// for mdl/m_sdlcrt.pas to compile.  At link time the real libSDL must
// be present.  This is NOT a complete SDL binding.
// ====================================================================

Interface

Const
  SDL_INIT_VIDEO = $00000020;
  SDL_HWSURFACE  = $00000001;
  SDL_FULLSCREEN = $80000000;
  SDL_KEYDOWN    = 2;
  SDL_QUITEVENT  = 12;
  SDL_QUITEV     = SDL_QUITEVENT;

  // Key constants used by m_sdlcrt
  SDLK_1         = 49;
  SDLK_2         = 50;
  SDLK_A         = 97;
  SDLK_Z         = 122;
  SDLK_DELETE    = 127;
  SDLK_INSERT    = 277;
  SDLK_HOME      = 278;
  SDLK_END       = 279;
  SDLK_PAGEUP    = 280;
  SDLK_PAGEDOWN  = 281;
  SDLK_UP        = 273;
  SDLK_DOWN      = 274;
  SDLK_LEFT      = 276;
  SDLK_RIGHT     = 275;
  SDLK_SLASH     = 47;
  SDLK_NUMLOCK   = 300;
  SDLK_COMPOSE   = 314;

  // Key modifier flags
  KMOD_SHIFT     = $0003;
  KMOD_CTRL      = $00C0;
  KMOD_ALT       = $0300;
  KMOD_CAPS      = $2000;

Type
  UInt8  = Byte;
  UInt16 = Word;
  UInt32 = LongWord;
  SInt16 = SmallInt;
  SInt32 = LongInt;

  TSDL_Rect = Record
    x, y : SInt16;
    w, h : UInt16;
  End;

  TSDL_Color = Record
    r, g, b, unused : UInt8;
  End;

  TSDL_PixelFormat = Record
    palette    : Pointer;
    BitsPerPixel  : UInt8;
    BytesPerPixel : UInt8;
    Rloss, Gloss, Bloss, Aloss : UInt8;
    Rshift, Gshift, Bshift, Ashift : UInt8;
    Rmask, Gmask, Bmask, Amask : UInt32;
    colorkey : UInt32;
    alpha    : UInt8;
  End;

  TSDL_Surface = Record
    flags  : UInt32;
    format : ^TSDL_PixelFormat;
    w, h   : LongInt;
    pitch  : UInt16;
    pixels : Pointer;
  End;
  pSDL_Surface = ^TSDL_Surface;

  TSDL_Keysym = Record
    scancode : UInt8;
    sym      : LongInt;
    modifier : LongInt;
    unicode  : UInt16;
  End;

  TSDL_KeyboardEvent = Record
    Type_     : UInt8;
    which     : UInt8;
    state     : UInt8;
    keysym    : TSDL_Keysym;
  End;

  TSDL_Event = Record
    Case Byte of
      0 : (Type_ : UInt8);
      SDL_KEYDOWN : (key : TSDL_KeyboardEvent);
  End;
  pSDL_Event = ^TSDL_Event;

Function  SDL_Init          (flags: UInt32) : LongInt; cdecl; external 'SDL';
Procedure SDL_Quit;                                    cdecl; external 'SDL';
Function  SDL_SetVideoMode  (width, height, bpp: LongInt; flags: UInt32) : pSDL_Surface; cdecl; external 'SDL';
Function  SDL_Flip          (screen: pSDL_Surface) : LongInt; cdecl; external 'SDL';
Procedure SDL_FreeSurface   (surface: pSDL_Surface); cdecl; external 'SDL';
Function  SDL_BlitSurface   (src: pSDL_Surface; srcrect: Pointer; dst: pSDL_Surface; dstrect: Pointer) : LongInt; cdecl; external 'SDL';
Function  SDL_PollEvent     (event: pSDL_Event) : LongInt; cdecl; external 'SDL';
Function  SDL_WaitEvent     (event: pSDL_Event) : LongInt; cdecl; external 'SDL';
Procedure SDL_Delay         (ms: UInt32); cdecl; external 'SDL';
Procedure SDL_WM_SetCaption (title, icon: PChar); cdecl; external 'SDL';

// Note: m_sdlcrt calls SDL_INIT() which resolves to SDL_Init() in Delphi mode.

Implementation

End.

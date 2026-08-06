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
Unit SDL_TTF;

// ====================================================================
// Minimal SDL_ttf header — just enough for mdl/m_sdlcrt.pas to compile.
// At link time the real libSDL_ttf must be present.
// ====================================================================

Interface

Uses
  SDL;

Type
  TTF_Font = Record end;
  pTTF_Font = ^TTF_Font;

Function  TTF_Init : LongInt; cdecl; external 'SDL_ttf';
Procedure TTF_Quit; cdecl; external 'SDL_ttf';
Function  TTF_OpenFont (filename: PChar; ptsize: LongInt) : pTTF_Font; cdecl; external 'SDL_ttf';
Procedure TTF_CloseFont (font: pTTF_Font); cdecl; external 'SDL_ttf';
Function  TTF_RenderText_Shaded (font: pTTF_Font; text: PChar; fg, bg: TSDL_Color) : pSDL_Surface; cdecl; external 'SDL_ttf';

Implementation

End.

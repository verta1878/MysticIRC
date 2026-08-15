# mystic_sdl — SDL2 Graphical Terminal

SDL2-based graphical terminal for Mystic BBS. Renders the BBS
text-mode output in a resizable window with TrueType font support.

## Files
- m_sdl.pas — SDL2 bindings
- m_sdl_bind.pas — SDL2 function imports
- m_sdl_ttf.pas — SDL_ttf bindings
- m_sdl_dosscreen.pas — DOS screen emulation via SDL
- m_sdlcrt.pas — CRT replacement using SDL
- sdl_vga8x16.fnt — VGA 8x16 bitmap font data

## Dependencies
- SDL2 library (libSDL2)
- SDL2_ttf library (libSDL2_ttf)

## Status
Working. Used by the graphical terminal mode.

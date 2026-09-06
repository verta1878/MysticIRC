# FPC 2.6.4irc — v4 Preview: Unicode + Font Support

Held for v4 release. Not included in v3 repo source.

## Units

| Unit | Lines | Description |
|------|-------|-------------|
| cp437utf8.pas | 201 | CP437 to UTF-8 translation table (256 codepoints) |
| utf8render.pas | 279 | UTF-8 text renderer with bitmap glyph support |
| ttfglyph.pas | 386 | TrueType/OpenType glyph loader + rasterizer |

## Usage

```pascal
uses cp437utf8, utf8render, ttfglyph;
var
  Font: TBitmapFont;
  TTF: TTTFFont;
begin
  // Option 1: CP437 built-in font
  UTF8FontInitCP437(Font);
  UTF8RenderCP437(Font, Pixels, 640, 350, 0, 0,
    'Hello BBS!', TextColor(255,255,255), TextColor(0,0,170), False);

  // Option 2: Load TTF font
  if TTFLoadFile('font.ttf', TTF) then begin
    TTFToBitmapFont(TTF, 16, Font, 32, 127);
    UTF8RenderText(Font, Pixels, 640, 350, 0, 0,
      'Hello UTF-8!', TextColor(255,255,255), TextColor(0,0,0), True);
    TTFFree(TTF);
  end;
end.
```

## License
GPLv3 — Part of FPC 2.6.4irc

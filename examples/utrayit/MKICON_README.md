# mkicon — Pure Pascal ICO Generator

Generate .ICO files for console applications. No external dependencies.

## Usage

```
mkicon output.ico [style]

Styles:
  dos     Green >_ prompt on black (default)
  mystic  White M on blue
```

## Build

```
fpc mkicon.pas
```

## Output

32x32 pixel, 32-bit RGBA, valid Windows ICO format.
Use with utrayit or any Windows application resource.

## License

GPLv3 — Mystic BBS IRC Fork Contributors, 2026.

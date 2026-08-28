# mystic_makemenu — Mystic BBS Menu Editor

Creates, edits, and compiles .mnu and .mrp menu files.
Part of Mystic BBS, MAKEMENU, MAKETEXT.

## Programs

| Program | What |
|---------|------|
| makemenu | Menu editor — interactive (640x350) or text mode (80x25) + CLI |
| maketext | Generate 516 prompt .mrp stubs from default.txt |
| rendermrp | Render .mrp menu to 640x350 BMP (pixel-perfect test) |

## Usage

```
makemenu                    Interactive editor (640x350)
makemenu -txt               Text mode editor (80x25)
makemenu -txt menu.mnu      Edit MNU file in text mode
makemenu menu.mrp           Edit MRP file in graphics mode
makemenu -demo <name>       Create demo menu files (.mnu + .mrp)
makemenu -?                 Help

maketext default.txt prompts/    Generate all prompt stubs
rendermrp -demo demo.bmp         Render demo to BMP
```

## Build

```
fpc -Mdelphi -Fu../mdl -Fu../mdl/m_rip makemenu.pas
fpc -Mdelphi -Fu../mdl maketext.pas
fpc -Mdelphi -Fu../mdl -Fu../mdl/m_rip rendermrp.pas
```

## Dependencies

| Unit | Location | What |
|------|----------|------|
| mrpdata | mystic_makemenu/ | Menu data — load/save .mnu + .mrp |
| mripchr | mdl/m_rip/ | CHR stroked font parser |
| mripui | mdl/m_rip/ | MRP widget renderer |

## Team

| Handle | Role |
|--------|------|
| verta1878 | Project lead |
| sysop/0 | Compiler engineer, FPC, Tang Console, USB |
| bob | Compiler engineer, OpenWatcom, Glide, 3dfx drivers |
| evga | Display, Mystic, SIO rebuild |
| kiddo | Protocols, RIPscrip |
| wrench | Transport, FOSSIL, DVI/HDMI |
| hexadecimal | PCBoard, Cyclades |
| byte | Program discovery |
| DotMatrix | Documentation sourcing |

## License

GPLv3

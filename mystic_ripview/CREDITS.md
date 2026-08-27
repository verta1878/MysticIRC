# RIPView Credits & References

## Project
RIPView — RIPscrip v1.54 File Viewer
Part of Mystic BBS 1.11IRC
License: GPLv3

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

## Reference Implementation
RIPtermJS by Carl Gorringe (https://github.com/cgorringe/RIPtermJS)
- BGI.js — Borland Graphics Interface emulation in JavaScript
- ripterm.js — RIPscrip command parser and executor
- Our Bresenham line algorithm matched to BGI.js line_bresenham
- Our bezier curve rendering matched to BGI.js _drawbezier
- Our flood fill algorithm matched to BGI.js _floodfill
- Our fill patterns matched to BGI.fill_patterns
- Our font scaling matched to BGI.fontScales
- Our EGA64 palette conversion matched to BGI.ega_palette
- Our ellipse algorithm matched to BGI.ellipse_bresenham
- Our command parameter formats verified against ripterm.js parseRIPargs2

Carl Gorringe's RIPtermJS was the essential reference for pixel-accurate
RIPscrip rendering. Without it, this project would not exist.

## RIPscrip Specification
- RIPscrip v1.54 specification by TeleGrafix Communications, Inc. (1993)
- RIPscrip v2.0 working paper (RIPscrip30wp.txt)
- The RIPscrip standard defines the Remote Imaging Protocol used by
  BBS software for graphical terminal display over modem connections.

## BGI (Borland Graphics Interface)
- Original BGI specification by Borland International
- CHR vector font file format (stroke font data)
- ICN icon file format (4-bit-plane EGA planar pixel data)
- 13 standard fill patterns (empty, solid, line, slash, backslash,
  hatch, crosshatch, interleave, wide dot, close dot, user fill)
- Line dash patterns (solid, dotted, center, dashed, user)
- EGA 16-color palette with 64-color extended palette

## Test Content
- Test RIP files (F_FILL, S_FILL, L_LINE, V_ARC, Y_FONT, BUTTONS,
  COVAI, C_WELL, ICONS, v_VIEW) — source unknown, possibly from
  RIPtermJS test suite or community RIP art collections
- DRAGON01.RIP — "Ripped by Herb Dunn 5/93" (from the BBS scene)
- jsuite (JVIEW, JDRAW, JMEDIA) — J Suite by unknown author (1996)
  Sample RIPs: BURGER, PAC, PALEO, SHADOW, UFO, WIN1, WIN2
- Dpaint (Dead Paint) — RIP drawing suite (1994)
  DEAD.EXE (editor), DB.EXE (icon editor), DV.EXE (viewer)
  215 ICN icon files included

## Tools & Libraries
- Free Pascal Compiler 2.6.4irc (fpc264irc) — custom FPC fork
  https://github.com/verta1878/fpc264irc
- ImageMagick — used for pixel-accurate BMP/PNG comparison
- PabloDraw — ANSI/RIP art editor (Issue #136 for RIP support)
  https://github.com/cwensley/pablosern

## Scene Release
- ripview-v1.0.0.zip released to PabloDraw GitHub Issue #136
- pcbrevival released by hexadecimal — PCBoard 15.4 on GitHub
  https://github.com/verta1878/pcbrevival

## Phase 3 Testing
- 22 test runs, 25+ bugs fixed
- 9 of 13 test files under 3% pixel diff vs reference
- 2 test files pixel-perfect (F_FILL1, F_FILL2)
- DRAGON01 from 98.9% diff to 1.4% diff
- Full test history in PHASE3-CHANGELOG.md

## MDL Integration (Session 6)
- SDL2 units moved from mystic_sdl/ to mdl/ (evga)
- serial_ext.pas added to mdl/ (sysop/0) — 6 serial functions
- utrayit.pas bugfix deployed to all 4 repo locations (sysop/0)
- MDL-OOP-ANALYSIS.md — 76% already OOP (recovered branch 3)
- OOP protocol units (m_protocol_*) recovered from branch 3
- 3-step migration: adapter → switchover → merge (sysop/0)

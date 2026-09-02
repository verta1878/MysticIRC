# RIP v1 Homebrew Pixel Buffer Engine (pre-VIPER)

Preserved copy of the v1 RIP engine before the VIPER refactor
(V1 Integration of Proper Engine Rendering).

This code uses a homebrew 640x350 byte array pixel buffer with
custom Bresenham lines, midpoint circles, scanline fills, and
manual flood fill. It works but is not pixel-accurate against
real BGI output that RIP art was designed for.

VIPER replaces this with `uses Graph` (ptcgraph/BGI) calls.

Snapshot date: 2026-09-02, Session 9.

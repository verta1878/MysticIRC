# mystic_rip → MDL Migration Plan

## Date: 2026-08-19 (final)

## Engine Architecture

TWO engines. One server (plugin codecs), one client.

| Engine | File | Role | Architecture |
|--------|------|------|-------------|
| Server | m_rip.pas | Render RIP, produce pixel buffer | Plugin codecs via registration |
| Client | mtrip.pas | Receive RIP from BBS, draw locally | Lightweight, 946 lines |

### Why NOT three engines?

hexadecimal's insight: `m_rip_dos.pas` is unnecessary. The same
`m_rip.pas` with no codecs registered IS the DOS engine. Link-time
decision, not source fork.

Pattern from prnapi.pas (already in our code):
```pascal
Type
  TCodecRec = Record
    Load : Function(const FN: String; Var Buf): Boolean;
    Save : Function(const FN: String; Var Buf): Boolean;
    Ext  : String[4];
  End;

Var
  ImageCodecs : Array[0..15] of TCodecRec;
  AudioCodecs : Array[0..15] of TCodecRec;

// Codec registers itself on unit initialization
initialization
  RegisterImageCodec('PNG', @PNGLoad, @PNGSave);
```

Don't link the PNG unit → slot stays nil → engine skips gracefully.

### Build Configurations

| Build | Engine | Linked Codecs | Platform |
|-------|--------|---------------|----------|
| DOS i8086 mterm | mtrip.pas | none | Real-mode, 64KB segments |
| DOS i8086 server | m_rip.pas | none (v2 cmd set) | Real-mode, row-pointers |
| Modern mterm | mtrip.pas | none | Linux/Win32/macOS/BSD/OS/2 |
| ansiedit | m_rip.pas | PCX, BMP | Modern |
| ripviewer | m_rip.pas | all | Modern |
| MIS server | m_rip.pas | all | Modern |

### Server vs Client

v1-v4 are **server-side renderers** — render locally, send picture out.
mtrip.pas is a **client-side parser** — receive RIP, draw locally.
Opposite data flows. pcbterm is a client → mtrip.pas.
(hexadecimal caught this — rip4api header says it explicitly)

### 16-bit Memory Layout

```pascal
Type
  TPixelRow = Array[0..RIP_MAX_X] of Byte;  { 640 bytes }
  PPixelRow = ^TPixelRow;
  TRIPPixelBuf = Record
    Rows   : Array[0..RIP_MAX_Y] of PPixelRow;
    Width, Height : Word;
  End;
  TVisitRow = Array[0..79] of Byte;  { 640 bits = 80 bytes }
  TVisitBuf = Array[0..RIP_MAX_Y] of TVisitRow;  { 28KB }
```

Row-pointers from day one. Works i8086 real-mode through 64-bit.

### Presenter Seam

rip_surface.pas already has this: "a software raster backend for the
TRipCanvas seam" with "a presenter (rip_window.pas via sdl_bind today;
LCL/BGI later)". Engine produces buffer, presenter displays it.
pcbterm's GUI backend plugs into this seam.

## Command Count

53 v1.54 commands (37 Level 0 + 16 Level 1).
Count by spec wire entries. Settled.

## Ownership

| Area | Lines | Units | Owner |
|------|-------|-------|-------|
| m_rip.pas (server engine) | ~8,646 → rewrite | 1 | kiddo |
| mtrip.pas (client engine) | 946 | 1 | kiddo |
| img/ codecs | ~3,000 | 12 | sysop/0 |
| wav/ audio (Phase 12) | 13,597 | 44 | sysop/0 |
| pasjpeg/ | 33,843 | 58 | sysop/0 |
| gfx/ primitives | ~1,500 | 5 | sysop/0 |
| font/ Unicode+TTF | ~2,300 | 3 | sysop/0 |
| html/ HTML 1.0 | ~1,800 | 5 | sysop/0 |
| print/ drivers | 882 | 6 | sysop/0 |
| prg/ scene utils | 1,948 | 6 | sysop/0 |

## MDL Target Structure

```
mdl/
├── m_rip.pas              ← ONE engine, plugin codec registration
├── m_rip_draw.pas         ← drawing primitives (from ripdraw + rip_surface)
├── m_rip_codec.pas        ← codec registration API (function pointer table)
├── rip/                   ← RIP-specific
│   └── meganum.pas, scene utils
├── img/                   ← image codecs (register into m_rip_codec)
│   ├── bmpdec, pcxdec, tgadec, icodec, pngcodec, gifdecr, jpgdecr
│   └── pasjpeg/
├── audio/                 ← audio codecs (register into m_rip_codec)
│   └── wavdec, mp3dec, moddec, mididec, flacdec (44 units)
├── gfx/                   ← general graphics
│   └── grfill, grbezier, grclip, grfx, grtexmap
├── font/                  ← font support
│   └── cp437u8, u8render, ttfglyph
├── html/                  ← HTML 1.0 engine
│   └── htmlpars, htmltree, htmllayo, htmlrend, htmlrip
└── print/                 ← print drivers (register into prnapi)
    └── prnapi, prnbmp, prnescp, prnpcl, prnps, prnraw

examples/
├── mterm/                 ← client terminal (mtrip.pas)
├── ripviewer/             ← RIP viewer (m_rip.pas + all codecs)
└── rip/                   ← tools, fonts, icons

pcbdraw/                   ← PCBoard editor (own toolkit)
```

## Migration Phases

| Phase | What | Priority | Owner |
|-------|------|----------|-------|
| RIP-MIG-1 | Create m_rip.pas from v4, row-pointers, plugin codecs, handler registration | HIGH | kiddo |
| RIP-MIG-2 | Create m_rip_codec.pas registration API (codecs + handlers, one mechanism) | HIGH | kiddo |
| RIP-MIG-3 | Create m_rip_draw.pas from ripdraw + rip_surface | HIGH | kiddo |
| RIP-MIG-4 | Move img/ codecs, register into m_rip_codec | MEDIUM | sysop/0 |
| RIP-MIG-5 | Move wav/ audio, register into m_rip_codec | MEDIUM | sysop/0 |
| RIP-MIG-6 | Move HTML renderer to mdl/html/ | LOW | sysop/0 |
| RIP-MIG-7 | Move print drivers to mdl/print/ | LOW | sysop/0 |
| RIP-MIG-8 | Move tools to examples/rip/ | MEDIUM | kiddo |
| RIP-MIG-9 | Move remaining docs to docs/ripscrip/ | LOW | kiddo |
| RIP-MIG-10 | Update all Uses clauses + build scripts | HIGH | kiddo |
| RIP-MIG-11 | Verify all programs compile | HIGH | kiddo + sysop/0 |

### RIP-MIG-1 Checklist (hexadecimal review items)

These must be addressed IN the rewrite, not discovered during it:

**Handler registration (not just codecs):**
Command dispatch table uses same registration pattern as codecs.
v3/v4 handlers are in rip4api.pas itself — 3,250 lines DOS never calls.
Fix: handlers register via function pointers, same as codecs.
DOS links rip_cmd_v154.pas + rip_cmd_v2.pas only.
One mechanism, not two. The DOS build is described entirely as a link set.

```pascal
Type
  TRIPCmdHandler = Procedure(Engine: TRIPEngine; Params: String);
Var
  CmdHandlers : Array['A'..'z'] of TRIPCmdHandler;  { Level 0 }
  ExtHandlers : Array['A'..'z'] of TRIPCmdHandler;  { Level 1 }
```

**SavedScreens memory:**
rip4api line 593: `SavedScreens: Array[0..9] of PRIPPixelBuffer;`
10 slots × 224KB = 2.24MB. DOS has 640KB total.
Row-pointers fix per-allocation 64KB limit, NOT total memory.

Options (in order of preference):
1. Fewer slots on DOS: `{$IFDEF DOS} MAX_SAVED = 2 {$ELSE} MAX_SAVED = 10`
2. Allocate on demand, fail gracefully if GetMem returns nil
3. Future: disk-backed via EMS/XMS (Clark's VIRTUAL.C pattern)

Must be in RIP-MIG-1 because it changes the buffer type.

**Provenance markers:**
Once v1/v2/v3/v4 merge into one engine, nobody can tell documented
behaviour from best-reading. One comment per handler during the merge:

```pascal
// v1.54 spec §2.3 — documented in RIPSCRIP_v154.DOC
// v2.0 RIPaint 2.1 observation — scene file BLUEFADE.FN
// v3.0 RIPtel 3.1 confirmed — RIPTEL.EXE string analysis
```

Impossible to reconstruct after the merge. Must be done during.

## Attic Archive

| Dir | What |
|-----|------|
| attic/mystic_rip_v1/ | ripscr.pas 4186 lines — v1.54 (1.0.1-irc) |
| attic/mystic_rip_v2/ | rip2api.pas 5394 lines — v2.0 (2.0.1-irc) |
| attic/mystic_rip_v3/ | rip3api.pas 8371 lines — v3.0 (3.0.1-irc) |
| attic/mystic_rip_v4_pre_mdl/ | rip4api.pas 8646 lines — v4 pre-migration |

## DOS Targets

- DOS i8086: confirmed target (verta1878)
- Real-mode: confirmed (verta1878) — 64KB segment limit applies
- v2 is DOS ceiling — v3+ dependencies won't compile for i8086
- Row-pointers required for pixel buffer and flood fill visited buffer

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

  serial/UART, OS/2 guidance
- evga — FPC 2.6.4irc, ripviewer engine
- wrench — fossil.pas, netfosdl.pas FOSSIL driver
- hexadecimal — PCBoard integration, architecture review, plugin codec
  design (prnapi pattern), attribution audit
- verta1878 — project lead, Ecstasy BBS FTN 1:152/158

## License

GPLv3

# RIPscrip v3.0 — Progressive Rendering (prg/ directory)

## What Is Progressive Rendering?

In traditional RIPscrip, the entire scene must be received and parsed
before any pixels appear on screen. Over a slow modem connection
(2400-14400 baud), this means the user stares at a blank screen for
seconds or minutes while data transfers.

**Progressive rendering** solves this by displaying partial results
as data arrives. The client begins drawing immediately and refines
the image as more data streams in. The user sees something useful
within the first few hundred bytes.

This is the same principle used by:
- **Interlaced GIF** — displays a low-res version first, refines
- **Progressive JPEG** — shows a blurry image, sharpens with each pass
- **Adam7 interlacing in PNG** — 7-pass progressive display

RIPscrip v3.0 provides five progressive rendering strategies,
each optimized for different scene types and connection speeds.

---

## Progressive Codecs

### ripdecraw.pas — Stream Decoder (Incremental)
The simplest approach. RIP commands are parsed and rendered one at a
time as they arrive over the wire. Each command immediately updates
the pixel buffer. The client sees the scene being "drawn" in real
time, command by command.

**Best for:** Interactive sessions, simple scenes, fast connections.
**Latency:** Immediate — first pixel appears with first command.
**Overhead:** Zero — no extra data beyond the RIP commands themselves.

```
Server sends:  |1c0F|1L001401000A|1B002000400200...
Client draws:  SetColor → Line → Bar → ... (each rendered immediately)
```

### ripbindec.pas — Binary Scene Decoder
Compact binary encoding of drawing commands. More efficient than text
RIP commands (fewer bytes per command), but requires the full binary
block to be received before rendering. Used for pre-compiled scenes
stored on the BBS as binary assets.

**Best for:** Pre-compiled menu screens, splash pages, file areas.
**Latency:** Must receive full block, but blocks are small (1-4KB typical).
**Overhead:** 30-50% smaller than equivalent text RIP commands.

### riptile.pas — Tile-Based Scene Decoder
Splits the rendered scene into rectangular tiles (e.g., 64x64 pixels).
Each tile is independently compressed and transmitted. The client
renders tiles as they arrive, filling in the screen like a mosaic.

**Best for:** Full-screen graphics, photo-quality images, large scenes.
**Latency:** First tile appears within 0.5-2KB of data.
**Overhead:** Small — tile headers add ~4 bytes per tile.

```
Scene (640x350) split into tiles:
  ┌──┬──┬──┬──┬──┬──┬──┬──┬──┬──┐
  │01│02│03│04│05│06│07│08│09│10│  ← received first
  ├──┼──┼──┼──┼──┼──┼──┼──┼──┼──┤
  │11│12│  │  │  │  │  │  │  │20│  ← arriving...
  ├──┼──┼──┼──┼──┼──┼──┼──┼──┼──┤
  │  │  │  │  │  │  │  │  │  │  │  ← not yet received
  └──┴──┴──┴──┴──┴──┴──┴──┴──┴──┘
```

### riplayerdec.pas — Layer-Based Scene Decoder
Renders the scene in layers: background first, then overlays.
Each layer is a complete drawing pass. The client displays the
background immediately, then composites additional layers as they
arrive.

**Best for:** Scenes with distinct visual layers (background art +
UI elements + text), animated overlays, translucent effects.
**Latency:** Background visible within first layer (1-4KB).
**Overhead:** Layer headers add ~8 bytes per layer.

```
Layer 0 (background): solid fills, large shapes  ← visible first
Layer 1 (midground):  detailed art, textures     ← composited on top
Layer 2 (foreground): buttons, text, UI elements ← final layer
```

### ripchange.pas — Changed-Region Patch Decoder
Dirty rectangle tracking and changed-region encoding. Only changed
regions are transmitted when updating a scene. The client applies
patches to the existing pixel buffer.

**Best for:** Scene updates, animation frames, live displays,
chat windows where only a small region changes per frame.
**Latency:** Patches are tiny (10-200 bytes typical).
**Overhead:** Patch header + rectangle coordinates (8 bytes per patch).

```
Frame 1: Full scene rendered (10KB)
Frame 2: Only the clock region changed (50 bytes)
Frame 3: Chat line added at bottom (120 bytes)
```

---

## Codec Selection Guide

| Scenario | Codec | Why |
|----------|-------|-----|
| Interactive BBS session | ripdecraw | Real-time command rendering |
| Cached menu screens | ripbindec | Small, fast binary format |
| Full-screen art/photos | riptile | Progressive tile display |
| Complex UI with background | riplayerdec | Layer compositing |
| Animations, live updates | ripchange | Only sends changed regions |
| Slow modem (2400 baud) | riptile or riplayerdec | Partial display fast |
| Fast connection (TCP/IP) | ripdecraw or ripbindec | Low overhead |

---

## Integration with rip3api.pas

The progressive codecs are standalone units in the `prg/` directory.
They operate on the engine's pixel buffer through the public API:

- All codecs call `DrawPixel`, `DrawLine`, `Bar`, etc. from TRIPEngine
- Tile and layer codecs write directly to the pixel buffer arrays
- Changed-region codec reads the pixel buffer to find what changed
- Stream decoder uses `ProcessLine` for incremental RIP parsing

To use progressive rendering, the host application:
1. Selects the appropriate codec for the connection/scene type
2. Feeds incoming data to the codec as it arrives
3. Calls `SaveBMP` or reads the pixel buffer after each update
4. The client displays the updated buffer (partial scene)

---

## Directory Structure

```
prg/
├── ripdecraw.pas     — incremental RIP stream decoder
├── ripbindec.pas     — binary scene decoder
├── riptile.pas       — tile-based progressive decoder
├── riplayerdec.pas   — layer-based progressive decoder
└── ripchange.pas      — changed-region patch decoder
```

All codecs: `{$H-}` compatible, pure Pascal, GPLv3, no external
dependencies, compile on all FPC 2.6.4irc targets.

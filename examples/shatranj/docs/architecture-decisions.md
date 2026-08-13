# Shatranj Architecture Decisions

## 0001 - Project Name

Decision: visible product name is Shatranj.

Reason: Shatranj is the visible product name; protocol/internal prefixes stay
stable for compatibility.

Current generated names:

- Spectrum TAP: `SHATRANJ.tap`
- PC client: `shatranj-client.exe`
- Protocol prefix: `netchesszx/v1`

## 0002 - Chess Core Layout

Decision: keep chess rules owned by Shatranj, not vendored around `mcu-max`.

Use this layout instead:

```text
src/
  common/
    chess/
    mqtt/
    protocol/
  pc/
    client/
  spectrum/
    app/
    board/
    overlay/
    platform/
    transport/
    ui/
asm/
  spectrum/
  uart/
  esxdos/
  platform/
  overlay/rules/
client/
tests/
```

Reason: Shatranj has separate responsibilities: Spectrum transport, PC GUI,
protocol, build outputs, and MQTT. The old vendored `mcu-max` copy is no longer
used by the build; keeping it would only preserve dead source.

Current contract:

- The vendored `mcu-max` copy was removed after the project stopped
  consuming it directly.
- `src/common/chess`: Shatranj-owned rules, position, and coordinate APIs.
- `src/common/chess/rules_compact.c`: shared compact rules path used by Spectrum and desktop clients.
- `tests/rules`: perft and special-rule tests against the owned rules layer.
- `src/pc/client`: consumes the owned common/Spectrum-compatible rules behavior.
- `docs/source-layout.md`: canonical source map for current paths.

## 0003 - One Cross-Platform Desktop Client

Decision: Windows, macOS, and Linux use one Qt client and one shared desktop
core. They are build/package variants, not independent applications.

Dependency direction is enforced with separate CMake targets:

```text
shatranj-common -> shatranj-desktop-core -> shatranj-client
```

- `shatranj-common` is portable C and has no Qt dependency.
- `shatranj-desktop-core` contains chess helpers, session adapters and
  controller, transport framing, and save-game persistence. It uses Qt Core
  and Network but not Widgets.
- `shatranj-client` contains the Widgets UI and platform packaging resources.

Reason: a single implementation prevents behavior drift between desktop
platforms while target boundaries catch accidental UI/platform dependencies in
the shared core at compile time. Platform-specific code is added only when a
real OS API requires it; speculative interface hierarchies are rejected.

## 0004 - Spectrum Renderer

Decision: Spectrum screen rendering starts in ASM.

Reason: the C `printf` board was useful for transport proof but too slow and too
large. Screen clear, board drawing, cursor, attributes, and later piece blits
need direct VRAM writes from the beginning.

Boundary:

- C keeps protocol/network orchestration while it remains cheap enough.
- ASM owns rendering hot paths.
- ChessZX is a reference for UI/piece organization, not vendored code.

## 0005 - Spectrum Cold Overlays

Decision: keep the Spectrum resident core 48K-first and add a Spectalk-style
cold overlay file, `SHATRANJ.OVL`.

Reason: legal move validation, storage, options, and reconnect/resume logic are
cold paths. Keeping them resident would force a premature 128K-only boundary and
make later memory recovery harder.

Current contract:

- Resident owns UI, board drawing, network/protocol, timers, and turn state.
- `asm/esxdos/overlay_loader.asm` loads fixed 2048-byte blocks from `SHATRANJ.OVL`
  into `_overlay_code_slot`.
- Overlay 0 is reserved for chess rules.
- Local Spectrum moves are not applied locally until the PC returns `ACK <ply>`.
  If the PC rejects a move, it sends `NACK <ply> ...`; the Spectrum keeps the
  turn and board state.

This gives a safe protocol guard immediately while the full rules overlay is
filled in.


## 0006 - One Semantics, Two Implementations, One Judge

Decision: the portable reducers are the canonical PC/reference implementation,
while Spectrum and Next retain compact state machines optimized for their memory
budget. Both implementations must satisfy the same transcript corpus and wire
contract.

Reason: linking the generic reducer into Spectrum was measured at roughly
31 KiB of additional resident code and is not a viable way to obtain parity.
Shared judges enforce behavior without imposing the same runtime layout.
Target-specific expected results are forbidden: disagreement means one
implementation or the contract is wrong. Transport and UI adapters translate
events and execute actions; they do not decide session policy.

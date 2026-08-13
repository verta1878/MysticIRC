# Shatranj Source Layout

This is the canonical source map. Keep new files inside the matching domain;
do not place loose `.c`, `.h`, or `.asm` files at the old root paths.

## Common Code

- `src/common/chess/`: chess position, FEN, legal-move wrapper, and compact
  rules code shared by Spectrum and desktop clients.
- `src/common/mqtt/`: MQTT packet encoder/parser used by host tests and PC
  code. Spectrum has its own size-constrained MQTT path.
- `src/common/protocol/`: Shatranj game/session message grammar parse/build
  helpers shared by clients where practical and kept host-testable.
- `src/common/savegame/`: portable save-game wire format shared by desktop and
  Spectrum; filesystem storage remains a desktop-core concern.
- `src/common/session/`: portable DIRECT/MQTT reducers and the canonical
  PC/reference session-policy implementation; host-only and never linked into
  Spectrum targets.

## Spectrum Code

- `src/spectrum/app/`: top-level Spectrum state machine, input flow, turn
  control, and application orchestration.
- `src/spectrum/config/`: Spectrum session/options configuration shared by
  app, transport, UI overlays, and tests without depending on `app/`.
- `src/spectrum/fileui/`: resident file-list navigation and action dispatch
  around the FILEUI overlay; owns selection state and the shared list metadata.
- `src/spectrum/restore/`: resident bridge that passes board snapshots and
  save metadata to the RESTORE overlay for base64 frame build/decode.
- `src/spectrum/saveload/`: resident bridge for SAVELOAD overlay NCZS file
  write, read, and erase operations.
- `src/spectrum/session/`: compact production DIRECT/MQTT FSMs and connection
  helpers for ZX/Next. They own equivalent Z80 decisions and are judged against
  the canonical reducers by shared transcripts.
- `src/spectrum/board/`: Spectrum board state, parsed move application, and
  compact rules reference code. It may dispatch cold board/rules overlays only
  through `spectrum/overlay/overlay.h`; overlay internals stay private.
- `src/spectrum/ui/`: GUI state, status bar, timers, chat/move rendering, and
  input rendering. Product UI reads the board only through the immutable
  fixed-low-RAM view owned by `ui/gui.c`; it must not include board internals,
  mutate that storage, or cache board-owned pointers. Host judges replace that
  view with a copied snapshot through the test-only GUI adapter.
- `src/spectrum/transport/`: app-facing link facade, ESP AT networking, raw TCP
  bridge mode, MQTT packet transport, direct keepalive grammar, and link-level
  buffers. Text protocol parse/build belongs in `src/common/protocol/`. It may
  dispatch cold network overlays only through `spectrum/overlay/overlay.h`;
  overlay internals stay private.
- `src/spectrum/platform/`: Spectrum platform wrappers for frame wait, UART,
  text append helpers, and cold-path runtime hooks used by networking.
- `src/spectrum/lowram_map.h`: fixed low-RAM addresses and sizes for resident
  rings, logs, status, board/context storage, and overlay scratch, with compile-
  time overlap checks.
- `src/spectrum/render_status.h`: narrow declaration surface for the resident
  error-status renderer implemented by `asm/spectrum/screen.asm`.
- `src/spectrum/overlay/`: C bridge for cold overlays. UI includes are
  allowlisted: cold overlays may use `ui/layout.h` for coordinates,
  `overlay_api.h` may expose the minimal info-panel ABI, and `overlay.c` may use
  `ui/gui.h` as resident dispatch glue.

## Desktop Code

- `src/pc/client/`: the single Qt implementation for Windows, macOS, and Linux.
  `DesktopSessionController` owns session reducers and timers;
  `DesktopTransportCodec` owns TCP/MQTT framing; `SaveGameStore` owns desktop
  persistence. `main.cpp` is the executable entrypoint; `main_window.cpp`,
  `AppBanner`, and `PieceRenderer` are the Widgets UI.
- `client/`: cross-platform desktop build wrappers, CMake targets, resources,
  and packaging metadata only.

CMake enforces the dependency direction:

```text
shatranj-common (portable C, no Qt)
    -> shatranj-desktop-core (Qt Core/Network, no Widgets)
        -> shatranj-client (Qt Widgets/Svg and OS packaging)
```

## Assembly

- `asm/spectrum/`: direct ZX screen and text rendering.
- `asm/uart/`: DIVMMC/divTIESUS UART backend.
- `asm/esxdos/`: esxDOS file/overlay loader code.
- `asm/platform/`: small platform primitives such as HALT.
- `asm/overlay/rules/`: cold rules overlay entry and implementation.

ChessZX is a visual/architectural reference for board/UI flow and piece asset
organization; do not vendor its source without a clear license.

## Assets

- `assets/spectrum/`: Spectrum-specific binary and ASM assets.

## Tests

- `tests/rules/`: chess wrapper tests.
- `tests/net/`: MQTT, game-protocol, MQTT-session, and keepalive grammar host
  tests.
- `tests/session/`: shared DIRECT/MQTT transcripts, common judges, and canonical
  plus host-compiled Spectrum runners.
- `tests/spectrum/`: Spectrum board/rules, config, and session host checks.
- `tests/pc/`: desktop-core adapters, controller, persistence, framing, and
  failure-path tests.

## Boundaries

- Transport decides how bytes move, not whether a chess move is legal.
- Protocol defines payload grammar, not UI state.
- UI renders state and input feedback, not session negotiation rules.
- Operating-system differences belong in packaging and deployment unless an
  actual platform API requires a small adapter; there are no separate Windows,
  macOS, or Linux application forks.
- Overlays hold cold Spectrum logic that should not inflate resident 48K code.

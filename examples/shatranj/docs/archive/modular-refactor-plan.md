# Shatranj Modular Refactor Closure

The modular refactor is closed. Phases 0-5 acceptance gates were green,
`known_violations` was empty, overlay capability debt was zero, and the SDCC/IY
build passed hardware testing when this closure was recorded.

The guard files now encode the architecture:

- `tools/check_layering.py`
- `docs/layering_allowlist.json`
- `tools/check_overlay_caps.py`
- `docs/overlay_capabilities.json`
- `docs/overlay_state_allowlist.json`
- `make abi-check`
- `make size-check`

Any new layering violation, overlay capability debt, or unjustified overlay
resident-state import is a regression.

## Current Boundaries

- `app.c` owns game/UI side effects after session events.
- `session_poll()` owns cooperative link reads, ping timeout/send, retained
  filtering, and payload classification.
- `src/common/protocol/` is pure parse/build code and must stay host-testable.
- `transport` knows links and bytes/payloads, not GUI or chess legality.
- `ui` is push-only from `app`/game where practical; it receives copied board
  snapshots and does not cache board-owned pointers.
- Cold overlays use explicit, policy-checked capabilities instead of arbitrary
  resident imports.

## Accepted Design Constraints

- Keep the `app.c` event-dispatch switch unless a new design keeps `session`
  free of UI/game dependencies.
- Board snapshots are acceptable at human move cadence. Per-square pushes are a
  future optimization only with measured need.
- The overlay resident-state allowlist is intentional. Do not replace shared
  resident singletons with byte-expensive accessors merely for purity.
- The `board_view` capability is a documented zero-cost alias over GUI-owned
  presentation entry points. New aliases need policy entries and justification.

## Do Not Touch Without A New Reason

- `HINTS`, `DIRECT`, `MENU_CONFIG`, and `MENU_LOGIC` overlays are size-sensitive.
  Add behavior there only after freeing bytes or splitting an overlay.
- Do not move the `app.c` event switch into `session` if it creates
  `session -> game/ui` dependency.
- Do not shrink `overlay_state_allowlist.json` by adding unmeasured accessors
  just for purity.

## Rejected For This 48K Target

- Dynamic event buses, vtables, heap-backed queues, or runtime-pluggable UART.
- Per-byte function-pointer dispatch in hot paths.
- Further modular splits that increase resident code without removing a real
  bug or enabling a required feature.

# Maintenance Contract

This document is the current entry point for changing Shatranj safely. It
describes process, not product behavior; the contracts below remain
source-of-truth for their own domains.

## Authoritative Documents

- `wire-contract.md`: bytes, routes, verbs, limits, and compatibility rules.
- `session-core-contract.md`: session states, timers, correlation, and actions.
- `source-layout.md`: ownership and allowed dependency direction.
- `architecture-decisions.md`: accepted structural decisions and rejected
  alternatives.
- `post-refactor-backlog.md`: active, optional, and hardware-only follow-up.

`docs/archive/` contains selected historical evidence. Removed handoffs,
versioned proposals, review logs, and scratch notes remain available in Git
history; none override the current contracts.

## Change Workflow

Protocol or session behavior changes in this order:

1. Amend the wire/session contract and state any mixed-version consequence.
2. Add one shared transcript that fails for the missing behavior; do not add
   target-specific expected outcomes.
3. Update the canonical portable reducer.
4. Update the compact Spectrum state machine to satisfy the same transcript.
5. Keep adapters mechanical: translate inputs and execute actions, but do not
   own protocol policy.
6. Run `make full-check`; run `make client-test` when desktop code is affected.

Do not weaken a judge to make an implementation pass. A newly exposed defect
stops the change until it is understood.

## Validation Matrix

| Change | Minimum local validation |
|---|---|
| Documentation or cosmetic text | Review the diff |
| Qt UI or desktop core | `make client-test` |
| Protocol, chess, or session semantics | Focused test, then `make full-check`; add `make client-test` for desktop changes |
| Spectrum resident, overlay, banking, ABI, or size | `make full-check` |
| Release candidate | `make full-check`, `make client-test`, and green CI |

`make full-check` is the canonical Spectrum/host gate: module boundaries,
shared transcript tests, classic and Next overlay ABI, size contracts, and NEX
packaging. CI also runs the Qt client on Linux, macOS, and Windows.

A software gate cannot stand in for real hardware. Missing hardware evidence is
reported as pending, never inferred as passing.

## Version Source

`VERSION` at the repository root is the only editable product version. It
accepts `major.minor[-devNNN|-devESP]` or
`major.minor.patch[-devNNN|-devESP]`; CMake keeps numeric desktop bundle
metadata while showing the suffix in About. Spectrum
shows development versions directly in its fixed banner slot and keeps the
`version` prefix for releases. Do not duplicate a version literal in source
code or build files.

## Real-Hardware Validation

Real-hardware results belong in the release notes, issue, or commit they
support, not in a permanent directory of run logs. Record concise pass, fail,
or pending results together with:

- commit and artifact hashes;
- 48K, Next-TAP, or NEX target and Next core/firmware when applicable;
- ESP firmware, UART backend, transport, and host/guest role;
- boot, asset load, palette, piece set, and About-screen results;
- LOCAL/IP/port editing, cursor behavior, themes, hints, and START;
- DIRECT and MQTT in both roles;
- MOVE, chat, DRAW, RESET, RESIGN, TAKEBACK, RESTORE, reconnect, and liveness.

Keep raw logs, captures, and photographs outside the repository unless one is
required as durable evidence for a specific defect.

For Next banking changes, repeat palette/set changes and About open/close cycles
to exercise bank restoration and interrupt state.

## Refactoring Threshold

Large files alone are not a reason to add layers. Extract another component only
when it creates a testable ownership boundary needed by an actual change. The
next likely seam is the Qt broker/socket lifecycle, but it remains deferred
until a feature or defect cannot be isolated cleanly with the current desktop
controller and adapters.

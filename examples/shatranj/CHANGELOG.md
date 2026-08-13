# Changelog

All notable changes to Shatranj are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com). This file is
the complete product and engineering record. Public GitHub release notes are
intentionally shorter and concentrate on changes that matter directly to a
player.

---

## [1.1] - 2026-08-04 - Across the Board

Shatranj 1.1 transforms the original ZX Spectrum 48K and Windows pairing into
one interoperable chess system for ZX Spectrum 48K, ZX Spectrum Next, Windows,
macOS, and Linux. Every supported client can play over Direct TCP or MQTT.
Alongside a native Next edition and a unified Qt desktop client, this release
adds takebacks, portable saved games and synchronized restore, greatly expands
visual customization, and substantially strengthens session reliability.

### Highlights

- Unified five supported targets in one interoperable chess system:
  Classic Spectrum, Spectrum Next, Windows, macOS, and Linux can play each other
  through either Direct TCP or MQTT.
- Added a native Spectrum Next client as a self-contained NEX application, with
  internal UART networking, hardware-sprite chess graphics, RGB333 themes, and
  a full-screen Layer 2 About screen.
- Promoted the Qt client to one supported desktop implementation for Windows,
  macOS, and Linux, with the same features, assets, session behavior, and saved
  games on every desktop platform.
- Expanded the game itself with negotiated takebacks, stalemate detection,
  desktop underpromotion, ten local save slots, portable `.stj` saved games,
  synchronized restore, and synchronized post-game rematches.
- Expanded presentation and customization across desktop and Next: five
  packaged desktop piece sets and five board textures, three hardware-sprite
  sets and five RGB333 themes on Next, plus extensive board, status, chat, menu,
  and feedback polish.
- Rebuilt Direct and MQTT session handling around explicit shared contracts,
  canonical reducers, parity transcripts, bounded retransmission, idempotent
  controls, role-aware liveness, and robust reconnect and peer-loss behavior.

### Added

#### ZX Spectrum Next

- Native ZX Spectrum Next build using the machine's internal UART and the same
  ESP-AT transport contract as the Classic client.
- Self-contained `SHATRANJ.nex` release artifact. Overlays, DAT payloads,
  compressed pages, sprite patterns, palettes, About graphics, and the cold
  graphics bank are embedded in the NEX instead of distributed beside it.
- Hardware-sprite board, pieces, selection markers, legal-move markers, and
  redraw paths, including correct handling when the board is flipped.
- Three 16×16 Next piece sets derived from Lichess artwork: **California**,
  **MPChess**, and **TotoY**.
- Five Next board themes: **Black & White**, **Blue 3**, **Green**, **Brown**,
  and **Wood**.
- Full-screen Layer 2 About presentation with its own 256-entry palette.
- Next RTC timestamp source for saved games, with SNTP fallback when the RTC is
  unavailable.
- Next-specific ESP hard-reset recovery after an unresponsive or stale modem
  session.
- Banked Next runtime with guarded MMU mappings and a cold graphics service
  outside the resident 48K-style application image.
- Generated 12,800-byte sprite bank containing 36 piece patterns, 10 board
  patterns, and four marker patterns, plus a quantized palette of up to 160
  RGB333 entries.
- Dedicated RGB333 colors for board coordinates, focus, selection, and theme
  previews without requiring ULANext mode for the standard ULA UI.
- Classic and Next launcher definitions for the local ZXESPEmu/ZEsarUX
  integration workflow.

#### Desktop platforms and appearance

- One Qt Widgets client and desktop core for Windows, macOS, and Linux; platform
  differences are restricted to packaging and operating-system integration.
- Five packaged selectable desktop piece sets: **California**, **Gioco**,
  **Kiwen-Suwi**, **Merida**, and **MPChess**.
- Five packaged selectable board textures, plus the untextured default board.
- Custom in-window Shatranj banner.
- Persistent connection settings and a deduplicated history of up to eight
  valid Direct guest IP addresses.
- Saved-IP menu embedded in the Direct address field.
- Visible live character count for the Spectrum-compatible 42-character chat
  envelope.
- Explicit confirmation before a user-requested desktop disconnect.
- Native macOS application bundles for Apple Silicon (`arm64`) and Intel
  (`x86_64`).
- macOS bundle metadata declaring Direct-play access to the local network.
- Supported Linux build against the system Qt installation and a GitHub Actions
  workflow that produces and inspects a self-contained x86_64 AppImage.
- Linux desktop entry and application icon metadata for menu integration.

#### Gameplay and saved games

- `/takeback` request flow for Direct and MQTT. The receiving player can accept
  or reject the request; an accepted takeback restores the previous position
  and synchronizes the ply on both peers.
- Stalemate detection and draw presentation.
- Desktop promotion choice for queen, rook, bishop, or knight, while preserving
  queen-only automatic promotion on Spectrum.
- Shared version-1 saved-game record containing the board, side to move, ply,
  castling rights, en-passant square, host color, active/check/game-over flags,
  game and move clocks, and board orientation.
- Compact 45-byte binary saved-game format with semantic validation and CRC-8,
  encoded as 60 unpadded Base64URL characters for transport.
- Ten local saved-game slots on Spectrum, displayed through the FILE browser
  with filename, date, time, selection, save, load, and erase actions.
- Timestamped Spectrum filenames sourced from Next RTC or network time where
  available.
- Desktop Saved Games dialog using the same `.stj` state model and ten-slot
  naming convention as Spectrum.
- Filename normalization, extension handling, duplicate-slot detection, corrupt
  record rejection, semantic validation, and oversized-file rejection in the
  desktop save store.
- Explicit host-led restore exchange for both transports. The guest must accept
  before a snapshot is sent or applied.
- Two bounded restore data frames (`RS00` and `RS01`), completion acknowledgement,
  timeout, retry, cancellation, duplicate, and conflicting-chunk handling.

#### Session core and protocol verification

- Portable event/action session reducers for Direct and MQTT, with transport,
  timing, persistence, and UI effects kept in adapters.
- Qt `DirectSessionAdapter`, `MqttSessionAdapter`, and desktop session controller
  driven by the shared reducers.
- Compact Spectrum production state machines preserved for resident-size
  reasons and compared with the canonical reducers through transcript parity
  tests.
- Explicit peer-presence routes and side-aware MQTT output actions.
- Formal RESTORE grammar and behavior in the wire and session contracts.
- Bounded, idempotent control retransmission for DRAW, RESET, TAKEBACK, RESIGN,
  RESTORE, and keepalive exchanges.
- Direct Classic and Next parity runners plus a common Direct reference runner.
- MQTT canonical/Spectrum parity corpus covering startup, moves, rejected
  moves, promotion, chat interleaving, liveness, crossed controls, takeback,
  resignation, BYE, link loss, retained payloads, and restore.
- Session-boundary guards that prevent UI, transport, or platform code from
  taking ownership of shared Direct/MQTT policy again.
- Dedicated guards for transport contracts, MQTT client identity, Direct policy,
  overlay capabilities, overlay entry ABI, layer ownership, and session routes.

#### Build, CI, and release engineering

- Root `VERSION` source accepted as `major.minor`, `major.minor.patch`, and
  supported development suffixes; generated platform metadata derives from the
  same value.
- `make nex` target and guarded NEX generator for the Next bundle, graphics
  definitions, compressed pages, and embedded payload offsets.
- `make client-test` as the single supported incremental Qt build-and-test path
  on Windows, macOS, and Linux.
- MSVC CMake presets and `client\build-pc.cmd` for repeatable Windows builds
  outside synchronized source directories.
- Cross-platform CI matrix: full Spectrum/host contracts under z88dk, plus Qt
  builds and tests on Ubuntu, macOS, and Windows.
- Windows x86_64 packaging workflow that deploys the Qt and MSVC runtimes,
  validates the published asset subset, smoke-starts the portable client, and
  uploads a versioned ZIP.
- Separate macOS packaging workflow for arm64 and x86_64 application archives.
- Linux AppImage workflow that installs the application, checks bundled assets
  and shared-library resolution, smoke-starts the package offscreen, uploads a
  versioned workflow artifact for release publication.
- Host tests for the shared saved-game wire format, compact chess-rule parity,
  Direct `+IPD` bounds, Classic/Next UART behavior, ESP-AT recovery, Next
  graphics banks, RGB333 colors, sprite-slot flipping, NEX packaging, and TAP
  integrity.

### Changed

#### Architecture and ownership

- Reorganized the source tree into explicit common, Spectrum, desktop-core, Qt,
  assembly, asset, tool, and test layers.
- Made portable common C the owner of chess rules, payload grammar, MQTT grammar,
  saved-game serialization, and canonical session semantics.
- Moved Qt networking/session policy out of the main window and into reusable
  desktop adapters and a transport-neutral controller.
- Kept the Spectrum firmware on compact state machines instead of linking the
  larger canonical reducers into resident RAM; equivalence is enforced by
  tests rather than duplicate undocumented behavior.
- Replaced client-type-dependent protocol behavior with payload grammar, route,
  role, side, and session identity.
- Isolated the Spectrum transport link contract from Classic/Next platform
  selection.

#### Session behavior

- Made resignation unilateral: receipt ends the game immediately and every
  retransmission is acknowledged without asking the opponent to approve it.
- Allowed RESIGN to pre-empt an unanswered move and removed stale retry state
  once both peers are already in game-over state.
- Made duplicate control requests idempotent instead of showing repeated prompts
  or producing false rejections.
- Reworked RESET so accepted requests restart both peers through one explicit
  ACK handoff; fresh later requests are not suppressed by an obsolete latch.
- Synchronized post-resignation rematches through RESET/ACK RESET when both
  peers implement the 1.1 session contract.
- Kept the desktop reducer alive after game over so rematch, reset, restore, and
  disconnect behavior remains available.
- Made Direct liveness role-aware and based on elapsed protocol activity rather
  than arbitrary UI or socket callbacks.
- Shortened Direct silent-peer recovery while preserving the required retry
  window for a listener whose remote application is not ready yet.
- Made MQTT peer presence, seat ownership, rejoin, retained bootstrap, BYE, and
  link-loss cleanup explicit.
- Enforced the inbound side route for MQTT MOVE frames; cross-topic moves are
  inert and do not earn liveness credit.
- Preserved broker connectivity when a remote MQTT peer leaves, allowing a new
  guest to join without forcing the remaining player to reconnect.
- Widened the room-code editor from four to eight characters while keeping the
  internal protocol buffer bounded.
- Retained human-readable, client-neutral Direct and MQTT payloads and backward
  parsing of advisory message details.

#### Spectrum runtime and user interface

- Repacked cold code into a variable overlay atlas and expanded the overlay set
  for ABOUT, CONTROL, FILEUI, INPUT_EDIT, RESTORE, SAVELOAD, and SETUP behavior.
- Kept overlay-only functionality out of resident memory and guarded every
  fixed 2,048-byte overlay slot and public entry signature.
- Moved connection preflight, setup, file browsing, save/load, restore, input
  editing, notices, and additional transport work into cold overlays.
- Made keyboard input frame-latched to prevent one physical key press from being
  consumed by multiple UI states.
- Prioritized incoming opponent decisions by closing or suspending FILE and
  ABOUT views when an immediate answer is required.
- Reworked FILE navigation as resident cursor movement with attribute-only
  selection repaint, avoiding repeated SD reads and visible flicker.
- Reworked the in-game tab menu around the compact Ikkle font and clarified
  DRAW, RESIGN, RESET, disconnect, and opponent-request wording.
- Preserved chat while starting a new game and clarified local/opponent control
  events in the game log.
- Centralized board, chat, status, clock, menu, and text-rendering contracts
  shared by Classic and Next.

#### Desktop client

- Replaced platform forks and legacy qmake fallback paths with one CMake target
  graph and one Qt source implementation.
- Split the portable desktop core from Qt Widgets/SVG presentation and operating
  system packaging.
- Reworked the main-window layout around native window chrome, a compact title,
  wider connection controls, and a predictable fixed board and side-panel
  geometry.
- Aligned role and color controls with the actual Host/Guest session rules.
- Kept the host color choice authoritative and prevented guest-side controls
  from implying ownership they do not have.
- Improved connection, pending-operation, peer-loss, restore, rematch, and
  terminal-game feedback.
- Improved game-status feedback, input history, opponent-chat emphasis, board
  coordinate contrast, and move-number column sizing.
- Updated the About presentation, product title, icons, platform metadata, and
  version display for Shatranj 1.1.

#### Memory and release layout

- Reduced the Classic DAT pack by moving or compressing About and UI resources;
  the tracked guard baseline changed from 4,707 to 2,670 bytes.
- Expanded the Classic overlay atlas from nine functional blocks to dedicated
  feature overlays while keeping every loaded block within the fixed 2 KiB
  execution slot.
- Increased the tracked Classic stack-pointer gap from 1,616 to 1,935 bytes and
  the guarded stack gap from 1,272 to 1,591 bytes despite the additional 1.1
  features.
- Separated the Classic TAP/OVL/DAT release layout from the self-contained Next
  NEX layout.

### Fixed

#### Direct TCP

- Fixed rejected or unrelated peers being able to disturb an active Direct
  session.
- Fixed guest handling of duplicate HELLO frames and host/listener retry timing.
- Fixed valid `+IPD` frame bounds, line-buffer capacity, payload bursts, and
  stale/ghost event storms.
- Fixed keepalive replies, liveness credit, silent-peer timeout, early reconnect,
  and link-down cleanup.
- Fixed Next Direct receive paths incorrectly reporting a disconnect.
- Fixed delayed peers being rejected while the listener or Qt socket was still
  completing the expected handshake.
- Fixed desktop lookup/retry races and the test race between TCP acceptance and
  Direct host readiness.

#### MQTT

- Fixed host/guest startup, duplicate JOIN, JOIN send-failure cleanup, host
  reannouncement, guest rejoin, and retained-room conflict handling.
- Fixed stale retained state and cross-topic messages mutating or crediting the
  wrong peer session.
- Fixed peer liveness correlation, poisoned seat ownership, and local seat
  release after MOVE or PING transmission failure.
- Fixed remote BYE, link-down, and finish cleanup so presence and session state
  converge without unnecessarily dropping the broker connection.
- Fixed GAME START send/reply topic handling and guest acknowledgement ordering.
- Fixed crossed DRAW, RESET, RESIGN, TAKEBACK, MOVE, and busy-state handling.
- Fixed MQTT restore bootstrap, chunk retries, completion cleanup, and rejoin
  after a restored game.
- Fixed oversized MQTT chat frames being accepted beyond the Spectrum chat
  envelope.
- Fixed non-atomic subscription changes and MQTT client-ID collisions that could
  cause the broker to replace another Shatranj client.

#### Gameplay, restore, and UI

- Fixed duplicate DRAW, RESET, TAKEBACK, and RESIGN requests causing false
  rejection or repeated decisions.
- Fixed controls being accepted while a conflicting move, restore, or control
  operation was pending.
- Fixed peer-loss input gating so a disconnected board cannot continue accepting
  local moves.
- Fixed accepted-reset auto-start, reset-before-start, and fresh-reset behavior.
- Fixed takeback snapshots, timers, local/remote state application, and
  retransmitted acknowledgements.
- Fixed Classic and Next chat logs omitting accepted TAKEBACK events; the
  requesting player is now identified, matching the desktop presentation.
- Fixed restore chunk length, missing-chunk, invalid board, castling,
  en-passant-rank, CRC, Base64URL, filename, duplicate-slot, and oversized-file
  validation paths.
- Fixed FILE browser buffer overflow, selection reset, list refresh, timestamp,
  prompt priority, and erase behavior.
- Fixed board flip redraw, last-row move-log flicker, hint display, black-turn
  label rendering, and status/message clarity.
- Fixed game-end state transitions, stalemate presentation, move notation,
  promotion, and move-history formatting on desktop.

#### Spectrum Next and hardware-facing paths

- Fixed Next board sprite redraw after FLIP and after restoring a saved position.
- Fixed Next badge palette behavior under ULA+ and board-coordinate colors for
  every theme.
- Fixed palette bounds and trimmed the Next About path without changing the
  visible screen.
- Fixed divMMC UART initialization register clobbering and increased UART drain
  coverage around esxDOS file operations.
- Fixed ESP-AT parsing and recovery around stale responses, hard reset, IP/SNTP
  queries, and modem sessions that stop responding.
- Fixed TAP BSS initialization and pinned the SDCC/IY stack ABI used by C/ASM
  boundaries.

#### Desktop stability and packaging

- Fixed shutdown-time Qt socket callbacks reaching partially destroyed session
  state.
- Fixed hints, Direct keepalive, role/color controls, host/guest readiness,
  game-over reducer lifetime, MQTT reply failures, and side-directed controls.
- Fixed Windows build-tree placement, Qt test runtime lookup, runner portability,
  and generated-file cleanup.
- Fixed application geometry and native window decorations after the layout
  refactor.

### Optimized

- Repeatedly reduced Classic resident code and rebuilt the overlay distribution
  so save/restore, takeback, Next support, and stronger session recovery fit
  without weakening stack and ABI guards.
- Converted hot copy, move, prefix, coordinate, text, MQTT, ESP, and screen
  helpers to compact Z80 assembly where measured savings justified it.
- Used `LDIR`/`LDDR` for bounded Spectrum memory moves and deduplicated protocol
  strings, notices, and send paths.
- Moved setup, connection preflight, radio preparation, IP queries, About,
  input editing, GUI log, file UI, save/load, restore, and Next RTC work out of
  resident code.
- Banked cold Next graphics code and avoided rebuilding a redundant Next TAP
  when producing the NEX artifact.
- Reduced rules, DIRECT, MQTT receive/transmit, restore, setup, hints, GUI log,
  and common Spectrum paths while retaining focused size baselines for each
  independently constrained overlay.
- Optimized board repaint, move-log scroll, selection attributes, keyboard
  scanning, piece upload, and board-flip paths to reduce visible latency and
  flicker.
- Removed dead session ABI, obsolete overlay entries, stale wrappers, duplicate
  protocol code, legacy build projects, and completed development scaffolding.

### Documentation

- Added normative Direct/MQTT wire and session-core contracts, including topic
  routing, duplicate behavior, RESTORE, liveness, control deadlines, and
  compatibility rules.
- Added canonical source-layout, architecture-decision, maintenance, overlay ABI,
  size-policy, and hardware-evidence documentation.
- Added the ZEsarUX/ZXESPEmu Classic and Next integration guide.
- Added English and Spanish documentation indexes and Qt client guides.
- Rebuilt the public README in English and Spanish with download instructions,
  quick start, exact controls, commands, build targets, artifact layout,
  developer entry points, credits, and protocol/platform positioning.
- Added transparent, theme-adaptive README branding for GitHub light and dark
  themes.
- Added normalized screenshots for Qt on macOS, Windows, and Linux and for live
  Classic and Next game screens without emulator window decoration.
- Added compact visual catalogs for Classic and Next piece sets and board
  themes. The Next catalog is decoded from the shipped RGB333 sprite bank.
- Archived completed refactor plans and audit records while keeping maintained
  contracts separate from historical design notes.

### Release Artifacts

ZX Spectrum Classic:

- `release/SHATRANJ.tap`
- `release/SHATRANJ.OVL`
- `release/SHATRANJ.DAT`

ZX Spectrum Next:

- `release/Next/SHATRANJ.nex`

Desktop:

- Windows deployed executable and Qt runtime under `release/shatranj-client/`.
- macOS `Shatranj.app`, with arm64 and x86_64 archives produced by the packaging
  workflow.
- Linux system-Qt executable and self-contained x86_64 AppImage.

### Compatibility and Migration

- Classic and Next use the same game, Direct, MQTT, save-state, and session
  contracts; desktop-to-desktop, Spectrum-to-desktop, and Spectrum-to-Spectrum
  combinations remain supported.
- Existing 1.0 MOVE, CHAT, DRAW, RESET, RESIGN, PING, BYE, Direct HELLO, and MQTT
  startup payloads remain parseable. New optional details remain advisory.
- Automatic post-resignation rematch is guaranteed only when both peers run the
  current session contract; an older peer may still show its legacy RESET
  decision.
- RESTORE and TAKEBACK require peers that implement those 1.1 exchanges.
- The three Classic piece sets and five Classic board themes remain available
  and unchanged; Next uses its own hardware-sprite sets and RGB333 themes.
- Do not mix Classic TAP, OVL, or DAT files from different builds. The Next NEX
  is self-contained and must be replaced as one file.

### Validation Status

- The complete `make full-check` software gate passed for the release-candidate
  tree. It covers host tests, Classic and Next builds, session parity, module
  boundaries, transport contracts, overlay capabilities, public ABI,
  resident/BSS/stack limits, overlay sizes, NEX packaging, and Qt tests.
- Direct Classic/Next parity passed, together with all 61 MQTT
  canonical/Spectrum transcript scenarios.
- Physical Classic and Next release artifacts booted successfully on 2026-08-04.
  The bounded hardware smoke test passed Direct Spectrum-host/Qt-guest play on
  Classic, Direct Qt-host/Spectrum-guest play on Next, and MQTT Qt-host/Next-guest
  play, including game start, one move per side, bidirectional chat, and clean
  disconnect in every exercised session.
- Repeated Qt MQTT disconnect/reconnect cycles while the current Next client
  remained in the room re-established stable sessions. An earlier anomaly from
  an obsolete Next binary is excluded from release-candidate evidence.
- Accepted TAKEBACK presentation in the chat log passed on physical Classic and
  Next hardware. The transport, requester direction, and repetition count were
  not recorded for that focused check.
- The remaining physical matrix is explicitly **PENDING** for the complete
  palette/piece/theme/About/settings sweep; DRAW, RESET, RESIGN, RESTORE, and
  liveness expiry; reconnect timing calibration; dirty-link loss; and Next ESP
  hard-reset recovery.

### Known Limitations

- Spectrum promotion remains queen-only; the Qt client supports queen, rook,
  bishop, and knight.
- Saved-game restoration is host-led. A guest cannot initiate RESTORE.
- MQTT retained messages are used for bootstrap/presence, not as an implicit
  saved-game service; restoration always uses the explicit exchange.
- Direct TCP still requires the guest to reach the host through local routing,
  port forwarding, or another reachable path.
- The packaged Linux AppImage target is x86_64.
- The Classic build still requires matching TAP, OVL, and DAT files plus
  divMMC/esxDOS; the Next target distributes only its self-contained NEX.
- Spectrum network play targets ESP-AT 1.7.6. Older modem firmware may exhibit
  UART or command-recovery behavior outside the supported hardware contract.
- Resident RAM, the 2 KiB overlay slot, stack headroom, UART timing, banking, and
  real-hardware behavior remain explicit release constraints.

---

## [1.0] - 2026-06-25 - Opening Move

Initial public release of Shatranj, an online chess application for a real ZX
Spectrum 48K. The release includes the Spectrum client, the Qt PC client, Direct
TCP play, MQTT play, runtime assets, build guards, and the hardware-facing work
needed to make the application usable on the 48K target.

### Added

- Full ZX Spectrum 48K client with board rendering, cursor input, text input,
  move entry, clocks, move history, chat, status notices, setup screens, and
  game-state transitions.
- Spectrum-to-Spectrum and Spectrum-to-PC play using the same application-level
  protocol.
- Qt PC client with interactive board, legal-target display, move history, chat,
  clocks, connection setup, status messages, RX/TX protocol log, and About
  dialog.
- Direct TCP transport for reachable peers.
- MQTT transport for broker-mediated games across NAT or CGNAT.
- Host and Guest roles with side negotiation, game-start acknowledgement, session
  identity, generated room codes, and reconnect handling.
- Human-readable wire messages for setup, join, game start, moves, ACK/NACK,
  chat, ping, reset, draw, resign, BYE, and reconnect paths.
- Application-level ACK/NACK handling so peers agree on game state instead of
  relying only on transport delivery.
- Connection Setup and Game Setup menus for transport, endpoint, port, room code,
  role, side/color policy, notation, board theme, piece set, and hints.
- Spectrum-native chat with side icon, timestamp, wrapping, and a fixed two-line
  message envelope shared by Spectrum and PC input limits.
- `/draw` and `/resign` commands with confirmation and opponent notification.
- Restart, reset, disconnect, opponent-ready, check, checkmate, and rematch
  flows in the Spectrum UI and PC client.
- Independent Spectrum SAN notation, move display, and pending-move feedback.
- Optional Spectrum legal-move hints with explicit Send Move confirmation.
- Check indicators and terminal status presentation for checkmate/rematch states.
- Three 16x16 piece sets: BRRY, SPCY, and PIXL.
- Five board palettes: Classic, Blue, Green, Cyan, and Magenta.
- DAT-backed runtime asset pack for Spectrum UI data, piece graphics, logo/about
  artwork, and runtime resources.
- esxDOS/divMMC overlay system for cold code paths within a fixed 2 KB overlay
  slot.
- Handwritten Z80 support for screen rendering, input polling, UART, text paths,
  overlays, board helpers, and rules-facing glue.
- Fixed low-RAM layout for move log, chat log, clocks, board state, overlay
  context, hints, and transport-visible state.
- Build guards for overlay size, overlay entry ABI, SDCC/IY contract, module
  layering, low-RAM overlap, resident size, BSS tail, and stack margin.
- Windows PC packaging path plus macOS/Linux Qt build support through CMake/qmake
  paths.

### Changed

- Renamed the project from its development name, NetChessZX, to Shatranj.
- Standardized application versioning at `1.0` for both Spectrum and PC builds.
- Made the SDCC/IY Spectrum backend the supported build path.
- Dropped the legacy sccz80 Spectrum build path.
- Unified Direct and MQTT session handling behind a shared game/session layer.
- Split common game payload grammar, MQTT session grammar, and keepalive grammar
  out of transport-specific code.
- Reworked MQTT peer identity around role and session id instead of machine
  origin.
- Moved transport liveness ownership into the net/session layer.
- Moved resident setup logic, board apply paths, move/chat log paths, MQTT
  connect/tx helpers, and other cold paths into overlays.
- Externalized runtime art and UI data into the DAT asset pack instead of keeping
  it in resident code.
- Centralized Spectrum layout constants and named screen zones for board, chat,
  clocks, status, setup, and move log areas.
- Centralized fixed low-RAM addresses and tightened overlay include/import
  boundaries.
- Unified user-facing notice strings across Direct and MQTT paths.
- Preserved pre-game chat when a game starts; game start now resets game state
  and move history, not the conversation that led to the game.
- Made board cursor mode and text-input mode explicit so setup editing and board
  play do not fight for input.
- Improved PC move-history formatting, pending-state feedback, disconnect status,
  and chat UI text.

### Fixed

- Fixed false Direct disconnects caused by valid peer message bursts and chat
  payloads near the Spectrum message envelope limit.
- Fixed Direct move delivery and Direct setup display/status handling.
- Fixed Direct HELLO/session handshake recovery without ping-pong loops.
- Fixed Direct guest early reconnect, reset, reconnect, and connection-wait
  cancellation paths.
- Fixed MQTT CONNECT packet header copy and MQTT host/guest negotiation.
- Fixed MQTT room-conflict recovery and stale retained-payload recovery.
- Fixed MQTT session startup, session IDs, publish acknowledgement handling,
  unusable publish ACKs, and background UART draining.
- Fixed game-start acknowledgement and reset-before-game-start edge cases.
- Fixed mate rematch flow, terminal status, check/checkmate presentation, and
  remote move validation.
- Fixed promotion handling and queen-only promotion error feedback.
- Fixed Spectrum game-loop state recovery after communication failures and UI
  transitions.
- Fixed Spectrum UI state recovery, board snapshots at game start, status overlay
  rendering, status clock clearing, setup hints visibility, setup sprites, notice
  bounds, and chat text rendering.
- Fixed hint repaint and validation workflow around Send Move confirmation.
- Fixed PC client pending-state feedback, move notation display, move-history
  table formatting, peer timeout, and session handling.
- Hardened chat input limits so the PC client cannot send more text than the
  Spectrum two-line chat envelope can display.
- Hardened AT command construction, IP/SNTP parsing, setup rendering, line buffer
  sizing, and malformed modem response handling.
- Hardened UART receive caching and bounded background drain paths around overlay
  latency and short bursts.
- Hardened overlay loading, overlay seek paths, overlay ABI guards, resident
  state imports, and build portability checks.
- Hardened architecture boundary checks, size report metrics, integration guard
  baselines, and SDCC/IY migration gates.

### Optimized

- Shrunk the resident Spectrum binary repeatedly to keep the 48K target viable.
- Shrunk rules, board apply, session dispatch, status, SAN, SNTP, MQTT buffers,
  MQTT warm-up, setup logic, and resident protocol/text paths.
- Optimized keyboard scanning, horizontal-line loops, fast 64-column line
  rendering, screen address calculation, render hints, setup painting, and text
  helpers.
- Optimized piece sprite lookup and piece sprite blitting with measured Z80
  hot-path improvements.
- Moved additional transport and setup work into overlays to reduce resident RAM
  pressure.
- Removed obsolete feature fallbacks, dead inline MQTT transport forks, unused
  MQTT RX overlay code, and legacy info-panel exports.

### Release Artifacts

Spectrum release files:

- `SHATRANJ.tap`
- `SHATRANJ.OVL`
- `SHATRANJ.DAT`

PC client package:

- `shatranj-client.exe`

### Known Limitations

- Spectrum promotion UI supports queen promotion only in 1.0.
- MQTT retained game-state restoration is not part of 1.0.
- The Spectrum build targets 48K machines, so contended RAM, overlay latency, and
  tight resident memory remain deliberate constraints.
- Direct TCP still requires reachable peers; MQTT is the intended path when NAT
  or CGNAT prevents direct connectivity.

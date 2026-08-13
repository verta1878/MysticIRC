<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/shatranj-logo-dark.png">
    <source media="(prefers-color-scheme: light)" srcset="docs/assets/shatranj-logo-light.png">
    <img src="docs/assets/shatranj-logo-light.png" alt="Shatranj" width="520">
  </picture>
</p>

<p align="center">
  <strong>Network chess from 48K to modern desktops.</strong><br>
  Direct TCP or MQTT · ZX Spectrum Classic and Next · Windows, macOS, and Linux
</p>

<p align="center">
  <img src="https://img.shields.io/badge/version-1.1-blue" alt="Version 1.1">
  <img src="https://img.shields.io/badge/protocols-Direct%20TCP%20%7C%20MQTT-2ea44f" alt="Protocols: Direct TCP and MQTT">
  <img src="https://img.shields.io/badge/desktop-Windows%20%7C%20macOS%20%7C%20Linux-41cd52" alt="Desktop: Windows, macOS, and Linux">
  <img src="https://img.shields.io/badge/Spectrum-Classic%20%7C%20Next-d52b1e" alt="Spectrum: Classic and Next">
  <img src="https://img.shields.io/badge/license-GPL--2.0-555" alt="License: GPL 2.0">
</p>

<p align="center">
  <a href="README.es.md">Español</a> ·
  <a href="https://github.com/IgnacioMonge/Shatranj/releases/latest">Download</a> ·
  <a href="docs/README.md">Developer documentation</a> ·
  <a href="client/README.md">Qt client guide</a>
</p>

---

Shatranj lets two people play network chess from an original 48K Spectrum, a
Spectrum Next, or the Qt desktop client on Windows, macOS, and Linux. Every
client uses the same game protocol and chess rules, so any supported platform
can play against any other.

Play Spectrum-to-Spectrum, Spectrum-to-desktop, or desktop-to-desktop. Use a
direct connection when the guest can reach the host, or meet in an MQTT room
when a direct connection is impractical. No account or central game server is
required.

## Why Shatranj

|  |  |
| --- | --- |
| **Play** | Spectrum ↔ Spectrum, Spectrum ↔ desktop, or desktop ↔ desktop |
| **Connect** | Direct TCP without a broker, or MQTT through a shared broker and room |
| **Platforms** | ZX Spectrum Classic, Spectrum Next, Windows, macOS, and Linux |
| **In game** | Legal-move hints, clocks, history, chat, draw, resign, takeback, and save/restore |
| **Consistent play** | The same rules, protocol, saved games, and session behavior on every client |
| **Native retro builds** | TAP + OVL + DAT for Classic; one self-contained NEX for Next |

## Contents

- [Platforms and protocols](#platforms-and-protocols)
- [Download](#download)
- [Quick start](#quick-start)
- [Gallery](#gallery)
- [Piece sets and board themes](#piece-sets-and-board-themes)
- [Using Shatranj](#using-shatranj)
- [Build from source](#build-from-source)
- [Documentation for developers](#documentation-for-developers)
- [Credits and license](#credits-and-license)

## Platforms and protocols

| Client | Platforms | Network modes | Distribution |
| --- | --- | --- | --- |
| Qt desktop | Windows, macOS, Linux | Direct TCP, MQTT | Platform package or executable |
| ZX Spectrum Classic | 48K ZX Spectrum | Direct TCP, MQTT | `SHATRANJ.tap` + `SHATRANJ.OVL` + `SHATRANJ.DAT` |
| Spectrum Next | ZX Spectrum Next | Direct TCP, MQTT | `SHATRANJ.nex` |

Direct TCP is a peer connection: the guest must be able to reach the host's
address and port. MQTT avoids requiring a direct inbound connection; both
clients connect to the same broker and room instead.

### Spectrum hardware

Network play on Spectrum uses a supported UART-to-ESP link with ESP-AT firmware
1.7.6. The Classic build also needs divMMC/esxDOS to load its OVL and DAT
companions. The Next release is self-contained, so only its NEX file needs to
be copied to the target.

## Download

Download ready-to-run builds from the
[latest public release](https://github.com/IgnacioMonge/Shatranj/releases/latest).
Choose the desktop package for your operating system, the three-file Classic
set, or the self-contained Next NEX.

## Quick start

1. Start Shatranj on both clients.
2. Choose **Host** on one client and **Guest** on the other.
3. Select **Direct** or **MQTT** on both sides.
4. For Direct, enter the host address and port on the guest. For MQTT, enter
   the same broker, port, and room on both clients.
5. The host chooses the game color and starts the game. The guest waits for the
   connection and then plays when the turn indicator allows it.
6. Use the chat panel or the Spectrum text input to communicate during the game.

### Direct TCP

The host listens on the configured TCP port. Share that endpoint with the
guest and make sure firewalls and routing allow the connection. Direct mode
does not use an MQTT broker.

### MQTT

Both clients connect to the same broker and room. MQTT is useful when a direct
peer connection is inconvenient, provided both clients can reach that broker.

## Gallery

### Desktop

| macOS — MQTT game | Windows — MQTT game | Linux — takeback |
| --- | --- | --- |
| ![Shatranj 1.1 Qt client on macOS during an MQTT game](docs/screenshots/shatranj-qt-macos.png) | ![Shatranj 1.1 Qt client on Windows during an MQTT game](docs/screenshots/shatranj-qt-windows.jpg) | ![Shatranj 1.1 Qt client on Linux confirming a takeback](docs/screenshots/shatranj-qt-linux.jpg) |

### Spectrum

| ZX Spectrum Classic — Direct | Spectrum Next — MQTT |
| --- | --- |
| ![Shatranj 1.1 Direct game on ZX Spectrum Classic](docs/screenshots/shatranj-classic-game.png) | ![Shatranj 1.1 MQTT game on Spectrum Next](docs/screenshots/shatranj-next-game.png) |

## Piece sets and board themes

Themes and pieces are selected during Spectrum game setup.

### ZX Spectrum Classic

The classic client includes three 16×16 piece sets — **BRRY**, **SPCY**, and
**PIXL** — plus five board palettes: **Classic**, **Blue**, **Green**, **Cyan**,
and **Magenta**.

<table>
  <tr>
    <th>Piece sets</th>
    <th>Board themes</th>
  </tr>
  <tr>
    <td align="center" width="34%"><img src="docs/assets/piece-sets.png" alt="BRRY, SPCY, and PIXL piece sets" width="280"></td>
    <td align="center" width="66%"><img src="docs/assets/board-themes.png" alt="Classic, Blue, Green, Cyan, and Magenta board themes" width="620"></td>
  </tr>
</table>

### ZX Spectrum Next

The Next client uses 16×16 hardware sprites with three Lichess-derived piece
sets — **California**, **MPChess**, and **TotoY** — and five RGB333 board themes:
**Black & White**, **Blue 3**, **Green**, **Brown**, and **Wood**.

<table>
  <tr>
    <th>Next piece sets</th>
    <th>Next board themes</th>
  </tr>
  <tr>
    <td align="center" width="36%"><img src="docs/assets/next-piece-sets.png" alt="California, MPChess, and TotoY piece sets on Spectrum Next" width="300"></td>
    <td align="center" width="64%"><img src="docs/assets/next-board-themes.png" alt="Black & White, Blue 3, Green, Brown, and Wood board themes on Spectrum Next" width="620"></td>
  </tr>
</table>

## Using Shatranj

The host owns game start and reset; the guest joins the running session.
Moves are accepted only from the side whose turn is shown.

### Desktop controls

| Action | Control |
| --- | --- |
| Configure a session | Select Direct or MQTT, Host or Guest, then enter the host address/port or broker/room |
| Move a piece | Click the source square and then the destination square |
| Send text or a coordinate move | Type in the chat/input line and press Enter |
| Save or restore | Use the save/load buttons or `/save [name]` and `/load [name]` |
| Inspect traffic | Open **Log** to view readable RX/TX protocol messages |
| Change appearance | Open **Settings** for board, pieces, notation, and hints |

The client remembers connection settings and recent valid Direct guest
addresses. It also shows game, turn, and move clocks.

### Spectrum controls

| Context | Control |
| --- | --- |
| Setup: move between rows | Cursor Up/Down or `Q`/`A` |
| Setup: change an option | Cursor Left/Right or `O`/`P` |
| Setup: edit or confirm | Space or Enter |
| Board: move the cursor | Cursor keys (`5`/`6`/`7`/`8`) or `Q`/`A`/`O`/`P` |
| Board: select source/destination | Space |
| Open and submit text input | Enter |
| Open the in-game menu | **EDIT** (`Caps Shift` + `1` on a classic keyboard) |
| FILE menu | `Q`/`A` selects a slot; Enter/Space loads or saves; `E` erases |

The in-game menu provides **FILE**, **DISCONNECT**, **RESET**, **FLIP**,
**THEME**, and **ABOUT**. In the menu, use Left/Right or `O`/`P`, then
Space/Enter.

### Text commands

| Input | Result | Availability |
| --- | --- | --- |
| `e2e4` | Submit a coordinate move | Qt and Spectrum |
| `/draw` | Offer a draw | Qt and Spectrum |
| `/resign` | Resign the current game | Qt and Spectrum |
| `/takeback` | Request undo of the last move | Qt and Spectrum |
| `/save [name]` | Save the current position locally | Qt; use FILE on Spectrum |
| `/load [name]` | Request restoration of a saved position | Qt host; use FILE as host on Spectrum |

Any other submitted text is sent as chat. Qt asks for `q`, `r`, `b`, or `n`
on promotion; Spectrum clients promote to a queen automatically.

## Build from source

The repository Makefile is the supported entry point:

```sh
make tap              # classic TAP + OVL + DAT
make nex              # self-contained Spectrum Next NEX
make client-test      # Qt build and tests
make client           # Qt release packaging
make test             # shared and Spectrum host tests
```

`make tap` writes the Classic files to `release/`; keep its TAP, OVL, and DAT
together. `make nex` writes the self-contained Next image to
`release/Next/SHATRANJ.nex`. Configured Spectrum builds accept:

```sh
PORT=5000 MQTT_HOST=broker.example MQTT_PORT=1883 MQTT_CODE=ABC123 make tap
```

For prerequisites, the Qt development loop, and platform-specific packaging,
see [`client/README.md`](client/README.md). The complete validation and release
procedure lives in [`docs/maintenance.md`](docs/maintenance.md).

## Documentation for developers

### Layering

```text
user input
  -> Spectrum app FSM or Qt controller
  -> Direct/MQTT session policy
  -> shared payload grammar and chess rules
  -> ESP-UART or Qt TCP/MQTT transport
  -> peer validation, ACK/NACK, and board update
  -> UI feedback
```

Portable common C owns chess, protocol construction/parsing, MQTT grammar,
session reducers, and the save-game wire format. The Spectrum clients keep
compact production FSMs; the Qt application adapts the same contracts to
desktop networking, persistence, and Widgets UI. Transcript tests judge the
implementations against the same target-neutral behavior.

### Repository map

| Path | Responsibility |
| --- | --- |
| `src/common/` | Shared chess, protocol, MQTT, session, and save-game code |
| `src/spectrum/` | Classic/Next application, board, setup, session, transport, UI, and overlays |
| `asm/` | Z80 rendering, UART, esxDOS, overlay, and low-level runtime code |
| `src/pc/`, `client/` | Desktop core, Qt Widgets client, build presets, and packaging |
| `assets/` | Runtime fonts, sprites, piece sets, and generated asset sources |
| `tests/` | Host, transcript, layering, ABI, size, and desktop tests |
| `tools/` | Asset generation, guards, packaging helpers, and size reports |

### Canonical documents

- [`docs/README.md`](docs/README.md): documentation index and reading order.
- [`docs/wire-contract.md`](docs/wire-contract.md): normative Direct/MQTT wire contract.
- [`docs/session-core-contract.md`](docs/session-core-contract.md): shared session semantics and state transitions.
- [`docs/source-layout.md`](docs/source-layout.md): source ownership and layer boundaries.
- [`docs/architecture-decisions.md`](docs/architecture-decisions.md): durable architectural decisions.
- [`docs/maintenance.md`](docs/maintenance.md): validation, release, and hardware-test policy.
- [`docs/zesarux-zxespemu.md`](docs/zesarux-zxespemu.md): local software integration loop for Classic and Next.

The wire and session contracts are authoritative; this README intentionally
does not duplicate their complete grammar. A lost link ends the active
session, and a later connection starts a fresh handshake.

## Credits and license

- **BRRY pieces:** based on [Chess Pieces 16×16 One-bit](https://berryarray.itch.io/chess-pieces-16x16-one-bit) by [BerryArray](https://berryarray.itch.io).
- **SPCY pieces:** based on [Chess Pieces](https://spicygame.itch.io/chess-pieces) by [Spicy Game](https://spicygame.itch.io).
- **PIXL pieces:** based on [Pixel Art Chess Pieces](https://benrosen.github.io/posts/pixel-art-chess-pieces/) by [Ben Rosen](https://benrosen.github.io).
- **Ikkle font:** [Ikkle 4](https://www.dafont.com/es/ikkle-4.font) by Brixdee, used as the basis for the compact Spectrum UI text.
- **mcu-max:** MIT-licensed low-resource chess engine by [Gissio](https://github.com/Gissio), retained with its upstream license.
- Third-party source and art retain their upstream licenses and notices.

Shatranj is free software released under the
[GNU General Public License v2.0](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html).

## Author

**M. Ignacio Monge Garcia — 2026**

Issues and contributions are welcome in the
[official repository](https://github.com/IgnacioMonge/Shatranj).

<p align="center"><sub>Connecting the ZX Spectrum to online chess since 2026.</sub></p>

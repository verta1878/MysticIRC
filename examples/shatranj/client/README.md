# Shatranj desktop client

[Español](README.es.md) · [Project documentation](../docs/README.md)

Qt desktop client for Shatranj 1.1. Windows, macOS, and Linux use the same
implementation and support both transports:

- **Direct TCP**: a host listens for one guest; the guest connects to the
  host's address and port.
- **MQTT**: both peers join a room through a broker; the broker carries the
  session payloads and presence messages.

The transport-neutral payloads and topic rules are defined in
[`docs/wire-contract.md`](../docs/wire-contract.md). Do not copy that grammar
into client documentation: this file describes how to use and build the Qt
adapter.

## Using the Qt client

1. Select `Direct` or `MQTT` and enter the required endpoint/room settings.
2. Choose `Host` or `Guest`; the host selects the colour and starts the game.
3. Click a source square and a target square on your turn.
4. Use the chat box for messages; pressing Enter sends the current line.
5. Use the command forms below when a session control action is needed:

   ```text
   /draw       offer a draw or rematch
   /resign     resign the current game
   /takeback   request undo of the last applied ply
   /save [name] save the current position locally
   /load [name] load a local position and request peer restore
   ```

   Restore is an explicit host-led exchange; MQTT retained state is not a
   substitute for the restore protocol. The Qt client asks for a promotion
   piece; Spectrum clients currently auto-promote to a queen.

The client remembers connection settings and recent Direct guest addresses,
shows turn/game/move clocks, and exposes an RX/TX log. A hardware Spectrum host
can be tested with the steps in [Test Direct TCP with hardware](#test-direct-tcp-with-hardware).

## Architecture

```text
portable common C -> desktop core -> Qt Widgets application
```

The common layer owns chess rules, protocol parsing/building, MQTT grammar,
session reducers, and the save-game wire format. The desktop core adapts those
contracts to TCP/MQTT, timing, persistence, and Qt helpers. The Qt application
owns presentation and packaging. CMake target boundaries prevent a
platform-specific client fork.

## Build and test

Use the repository `Makefile` entry points from the project root:

```sh
make client-test   # configure, build, and run Qt tests
make client        # release packaging for the current desktop platform
make tap           # Classic ZX: SHATRANJ.tap, .OVL, and .DAT
make nex           # Spectrum Next: self-contained SHATRANJ.nex
make full-check    # host, Spectrum, ABI, and size guards
```

`make client-test` is the supported desktop development loop on Windows,
macOS, and Linux. On Windows, `client\build-pc.cmd` is an equivalent
interactive wrapper; the MSVC CMake presets keep the build tree outside the
repository and provide Qt DLLs to CTest. Do not use a qmake fallback or an
ad-hoc in-tree/raw CMake build.

`make client` produces the Windows executable, deploys a macOS application
bundle, or builds the supported and tested Linux executable against the system
Qt installation. The **Build Linux AppImage** GitHub Actions workflow packages
and inspects a self-contained x86_64 AppImage, uploads it as a workflow
artifact, and attaches it to a published release. On macOS,
the command also installs the current bundle at `/Applications/Shatranj.app`;
set `CLIENT_MAC_APPLICATIONS_DIR` to choose another Applications directory.

The Spectrum targets accept these configuration variables when a configured
build is required:

```sh
PORT=5000 MQTT_HOST=broker.example MQTT_PORT=1883 MQTT_CODE=1234 make tap
```

## Test Direct TCP with hardware

1. Build the matching Classic or Next target (`make tap` or `make nex`).
2. On a Classic host, copy `SHATRANJ.tap`, `SHATRANJ.OVL`, and `SHATRANJ.DAT`
   together; on Next, copy the self-contained `SHATRANJ.nex`.
3. Start the host and note its LAN address and configured port (the default is
   `5000` for the Classic build).
4. Start the Qt client, select `Direct` and `Guest`, enter the address/port,
   and connect.
5. Wait for the host to start the game, then play when the status says it is
   your turn; chat is available in the same window.

For Spectrum-specific input, the command line accepts `/draw`, `/resign`, and
`/takeback`; saving and loading are available from the FILE menu. The
protocol-level expectations remain in the canonical
[`wire contract`](../docs/wire-contract.md) and
[`session contract`](../docs/session-core-contract.md).

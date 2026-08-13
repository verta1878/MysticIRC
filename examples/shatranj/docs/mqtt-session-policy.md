# MQTT Session Policy

Current implementation target: deterministic HOST/GUEST startup over MQTT
without starting a game before both peers are visible.

## Ownership

`docs/session-core-contract.md` is authoritative: PC MQTT policy runs in the
canonical common reducer; ZX and Next retain the compact Spectrum MQTT FSM.
Both are judged against the same target-neutral transcript expectations.

## Roles

- The Spectrum MQTT build is now a single package:
  `MQTT/SHATRANJ.TAP` plus `MQTT/SHATRANJ.OVL`.
- The setup menu selects host/join at runtime.
- Only the host selects color and session id. A guest learns both from
  `H W/B <sid>` and then uses the opposite local color.
- Host publishes `H ...`; joiner publishes `J ...`.
- Move, ACK, presence, client id, and peer detection topics are selected from
  the runtime local color after the role/color handshake.

## Subscriptions

Each MQTT client subscribes to:

- incoming move topic (`w2b` or `b2w`)
- incoming app ACK topic (`ack_w` or `ack_b`)
- peer retained presence topic (`pres_w` or `pres_b`)
- shared `meta`

Own presence is published retained as:

```text
O W <sid>
O B <sid>
```

Host publishes retained setup as color/config hint:

```text
H W <sid>
H B <sid>
```

Joiner publishes live join setup:

```text
J <sid>
```

## Peer Ready

A retained payload never proves that the peer is alive. Retained `HOST` is
ignored as authoritative setup; the guest waits for a live host setup.

A client marks the peer ready only from live role-complementary messages:

- host receives live `J <sid>`
- guest receives live `H <color> <sid>`

After a host receives live `J ...`, it republishes `H ...` live on `meta`
as an acknowledgement so the guest can leave `Waiting host`.

`O <opponent_color> <sid>` is soft presence only. It can update status,
but it must not set peer-ready because retained presence may be stale.

Own retained `HOST`, own retained `ONLINE`, retained `JOIN`, and own repeated
`JOIN` are ignored for peer-ready.

## Seat Occupancy

A guest uses retained `H <color> <sid>` only to select the session whose seat
it probes. It subscribes to its own presence topic without publishing a claim.
`BUSY` is proven only by retained `O <own_color> <sid>` with that exact session
id. Missing/different ids and non-retained echoes are ignored. After `BUSY`, the
attempt stops and returns to setup; it does not reconnect and overwrite the
notice with `CONNECTING`.

## Disconnect

Presence is retained:

```text
O W <sid>
O B <sid>
F W <sid>
F B <sid>
```

The PC host installs retained `F <side> <sid>` as its MQTT CONNECT Last Will in
`mqttHandshake()`. CONNECT precedes linked reducer events, so this exact
formatter is the sole allowlisted pre-link `H/J/O/F` construction outside the
canonical reducer. A guest has no validated session id at CONNECT and uses
session liveness instead. All post-connect presence/session decisions remain
reducer-owned.

MQTT clients publish retained `F W/B <sid>` before a clean disconnect once
their side is known. A host additionally clears retained `meta` with an empty
retained publish so the next guest does not see stale setup.

Empty retained payloads are ignored by both clients.

Transport loss during an active game terminates the session and discards the
game and its move history, matching the session-core link-loss contract, which
takes precedence (Ignacio, 2026-07-15). The current wire contract has no
board/ply reconciliation, so a later reconnect begins a new handshake, session,
and game from initial state; no state is suspended, resumed, or replayed.

## Connect Robustness

The Spectrum MQTT overlay first tries a fast `AT` probe and only resets the ESP
if command mode cannot be recovered. TCP/MQTT session open is retried once after
returning to command mode and re-preparing the single-link settings.

## Start

- A game is inactive after MQTT broker connection.
- No board move is accepted before `GAME START`.
- Only the host starts the game.
- Either host or guest may send `RESET`. The receiver prompts the user and
  answers `ACK RESET` to accept or `NACK RESET` to decline.
- A joiner pressing SPACE before `GAME START` sees `Waiting host start`.
- A host pressing SPACE before peer detection sees `Waiting peer`.
- A host with peer ready sees `Peer ready - START` on Spectrum.
- A guest with live host ready sees `Host ready - wait START` on Spectrum.
- The PC MQTT client enables Start Game only when it is the host and the peer is
  ready.
- A guest accepts `GAME START` only after a live `H <color> <sid>` has selected
  color/session and marked the host ready.
- An active guest accepts duplicate `GAME START` without restarting the board;
  an `OVER` guest starts fresh only when no control operation is pending.

Start payload:

```text
GAME START
```

On receipt, the peer starts locally and answers with app ACK:

```text
ACK GAME START
```

MQTT `PUBACK` is never treated as game acceptance.

## RESTORE

MQTT RESTORE is host-initiated and uses the directional game topic
(`w2b`/`b2w`) for every live, non-retained frame. Its grammar is:

```text
RQ
RY | RN
RS00 <30 Base64URL chars>
RS01 <30 Base64URL chars>
RA
```

Each `RS00`/`RS01` frame is exactly 35 wire bytes: the four-byte tag, one space,
and 30 ASCII Base64URL characters. Together they carry the fixed 60-character,
unpadded Base64URL encoding of the 45-byte binary save record; no NUL terminator
is transmitted. The host sends `RQ`; the guest accepts with `RY` or rejects
with `RN`. After `RY`, the host sends `RS00` then `RS01`. The guest applies only
the complete snapshot and answers `RA` on success or `RN` on failure.

The control timer bounds every wait. The host retries `RQ` while awaiting `RY`
and retries the ordered chunk pair while awaiting `RA`. The guest re-sends `RY`
for a duplicate accepted `RQ`, waits a bounded time for incomplete chunks, and
sends `RN` when that receive window expires. A host may cancel with `RN` only
before `RY`; cancellation after chunk transmission begins is ignored. Exact
post-apply chunk duplicates re-send `RA` without another apply; conflicting
chunks receive `RN`.

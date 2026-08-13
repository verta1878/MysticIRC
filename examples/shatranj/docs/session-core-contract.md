# Session Core Contract

Status: amended by the explicit 2026-07-11 architecture pivot. Semantic and
wire behavior remain frozen; the event/action ABI is the canonical PC/reference
implementation contract, not a required Spectrum runtime ABI.

## Purpose

PC, ZX, and Next implement one session semantics judged by one executable
transcript corpus. PC uses the portable session core as the canonical reference
implementation. ZX and Next retain their compact production FSM because the
generic event/action plumbing cannot fit the Spectrum 48K memory layout.

DIRECT and MQTT have separate reducers behind one public `session_step()` API.
That API is used by the PC/reference path. The Spectrum implementation is not
required to expose or link it; a host-only runner must instead translate the
same transcript inputs and normalize its observable outputs for the common
judge.

There are exactly two implementation families and one judge:

- canonical common reducers used by PC;
- compact Spectrum/Next FSMs used by the Z80 targets;
- one shared set of transcript inputs and expected semantic observations.

No target-specific transcript, expected result, or semantic exception is
allowed. The remainder of this document describes the reference ABI in detail;
its wire behavior, ordering, timeout meaning, ACK distinction, and state
transitions are normative for both implementations.

## Purity Boundary

The core may depend only on fixed-width C types and common protocol grammar.
It must compile and pass its tests with native GCC and MSVC without Qt, z88dk,
SDCC runtime helpers, UART, overlays, sockets, UI, board, or platform headers.

The reference core owns all PC decisions about roles, colors, readiness, session ids,
control retries, duplicate handling, liveness, BUSY, game start, link-loss
termination, and session end. PC adapters must not query the core to make those
decisions. The Spectrum FSM owns the equivalent Z80 decisions directly and is
judged by the same transcripts rather than by object-code identity.

A read-only view may be emitted for rendering. UI code must not use that view
to decide transitions, timers, or wire output.

## Public Operation

Conceptual API:

```text
session_init(state, config)
session_step(state, event, workspace, tx_scratch, tx_capacity,
             actions, action_capacity)
```

All storage is caller-owned. There is no allocation and no callback from the
core into an adapter.

`SessionWorkspace` is persistent caller-owned storage shared with the core. It
holds the pending five-byte move, the pending local chat text, or the 60-byte
restore payload across later TX-result events. These uses are mutually
exclusive. It replaces equivalent target-local pending buffers; it is not
additive scratch.

## Initial Configuration

The immutable session configuration contains:

```text
transport: DIRECT | MQTT
role: HOST | GUEST
host_color: WHITE | BLACK | UNKNOWN
session_id: uint16_t
```

Reducers never rewrite this configuration. A color learned from a DIRECT peer
is mutable session state only, so ending a session and reconnecting cannot
inherit the previous peer's side.

The explicit mutable state contains the current phase, role/color readiness,
peer readiness, session id, pending control operation, duplicate/idempotency
state, liveness counters, armed timer identifiers, and pending local
transmission state. No session decision may depend on hidden application
globals.

## Input Events

```text
EV_LINK_UP
EV_LINK_DOWN
EV_RX
EV_LOCAL_REQUEST
EV_USER_DECISION
EV_TX_RESULT
EV_TIMEOUT
EV_GAME_RESULT
```

Event data:

- `EV_LINK_UP` / `EV_LINK_DOWN`: opaque link id. `0..254` are valid, including
  the ESP-AT raw id `0`; `SESSION_LINK_NONE` is `0xff`. Only loss of the active
  link ends the session; closure of a rejected candidate link does not affect
  the game.
- `EV_RX`: link id, route, retained/live flags, pointer, and `uint8_t` payload
  length.
- `EV_LOCAL_REQUEST`: START, MOVE, CHAT, RESET, DRAW, RESIGN, TAKEBACK, BYE, or
  RESTORE, plus any caller-owned payload needed for that request. A local
  RESTORE carries the decoded position phase (`READY`, `ACTIVE`, or `OVER`) in
  `phase` and ply in `value` alongside the fixed 60-character, unpadded
  Base64URL encoding of its 45-byte binary save record. RESTORE with zero
  payload length cancels only an already-pending local restore
  while waiting for RY, before either snapshot chunk has been sent. Once the
  reducer waits for RA, cancellation is ignored because the peer may already
  have applied both chunks. A valid early cancellation emits RN and reports
  completion after local TX handoff; it also cancels the RESTORE control timer
  so the old deadline cannot consume a later prompt. The receiver treats that RN as a typed
  rejected RESTORE both while its decision prompt is open and while it waits
  for the first chunk, closes the prompt/receive state, and rearms liveness.
- `EV_USER_DECISION`: request id plus ACCEPT or REJECT.
- `EV_TX_RESULT`: transmission id plus OK or FAILED.
- `EV_TIMEOUT`: timer id previously armed by the core.
- `EV_GAME_RESULT`: delivery id, accepted/rejected/failed result, optional
  notation/reason slice, and `uint16_t` value. It returns board legality,
  takeback application, or restore decode/application results to the core so
  the core alone builds the corresponding ACK/NACK/RA. An accepted remote
  RESTORE returns the decoded position ply in `value` and exactly one phase
  byte (`READY`, `ACTIVE`, or `OVER`) in `detail`; the reducer adopts both
  before acknowledging the restore. A rejected restore keeps `detail` as its
  optional error text.

Transport framing is outside the core. DIRECT removes TCP/ESP framing and the
line terminator; MQTT extracts the PUBLISH payload plus route and retained
metadata. `EV_RX` still contains uninterpreted application-payload bytes: the
core parses HELLO, H/J/O/F, BUSY, PING, GAME START, and every other wire verb.

`SESSION_ROUTE_PRESENCE` addresses the local retained presence topic.
`SESSION_ROUTE_PRESENCE_PEER` addresses the peer retained presence topic and
is used when the host releases a timed-out peer with `F <peer> <sid>`. Adapters
map both routes from session/color state; they must not inspect the payload to
choose `pres_w` or `pres_b`. Incoming O/F remains `SESSION_ROUTE_PRESENCE`.

`SESSION_ROUTE_META` addresses the side-neutral room `meta` topic. Every MQTT
`H <color> <session>` and `J <session>` bootstrap send uses this route; adapters
map it to `meta` without inspecting payload or requiring a known local side.
Lateral control remains `SESSION_ROUTE_CONTROL` on the directional side topic.

### Spectrum MOVE Parser Integrity Boundary

`spectrum_input_parse_move(text, move)` is a Z80-only adapter parser, not an
atomic core operation.  Its destination contract is:

- the caller supplies at least six writable bytes;
- return 1 produces a NUL-terminated coordinate move of four or five bytes;
- return 0 leaves the destination contents undefined and may have written a
  valid prefix, but never writes beyond the six-byte destination;
- callers must branch on the return value before reading or forwarding the
  destination.  Failed output must be discarded, not cleared, interpreted, or
  replayed.

The current Spectrum product has one caller. `input_submit()` passes a
six-byte stack local and calls `send_local_move()` only on success; its failure
path does not read that local.  The fixed low-RAM `local_input` at `0x5eb2` is
the source, not the destination.  Its editor caps content at 42 bytes and
maintains a NUL inside the 43-byte region ending at `0x5edd`.  Compile-time
layout guards keep input history and status between that source and
`chess_board` at `0x5f60`, followed by the rules board at `0x5fa0`, the overlay
context at `0x5fe0`, and overlay code at `0x6800`.  The target wrapper passes
the stack destination through the context; it does not alias either board.

Both ZX and Next overlay loaders enter this parser under DI and return through
their EI trampoline.  The parser makes no call that re-enables interrupts, so
its context read and bounded destination writes remain in that DI window.
This interrupt window does not make partial output valid and is not relied on
for bounds safety; the six-byte branch bound and success-before-use rule do.

## Output Actions

```text
ACT_SEND
ACT_TIMER_SET
ACT_TIMER_CANCEL
ACT_LINK_CLOSE
ACT_REQUEST_DECISION
ACT_DELIVER_GAME
ACT_SESSION_CHANGED
ACT_SIDE_CHANGED
```

Action data:

- `ACT_SEND`: transmission id, route, retained flag, payload pointer, and
  `uint8_t` payload length, directed to a link id.
- `ACT_TIMER_SET`: timer id and `uint16_t` duration in protocol ticks.
- `ACT_TIMER_CANCEL`: timer id. SET or CANCEL invalidates every older schedule
  for that timer id; the adapter must never deliver a stale timeout.
- `ACT_REQUEST_DECISION`: request id and control kind.
- `ACT_LINK_CLOSE`: link id to close.
- `ACT_DELIVER_GAME`: typed delivery id, `uint16_t` ply/request value, and an
  already-parsed payload slice. The adapter must not parse a wire verb.
- `ACT_SESSION_CHANGED`: READY, BUSY, STARTED, or ENDED.
- `ACT_SIDE_CHANGED`: local color and session id.

There may be multiple actions per step, but at most one `ACT_SEND`. A
transition requiring another transmission emits it after the corresponding
`EV_TX_RESULT`. This keeps output-buffer ownership unambiguous and requires no
dynamic action queue.

An accepted local MOVE emits the workspace-backed move delivery followed by a
typed result delivery carrying the already-parsed peer notation. TAKEBACK is
not ACKed until its correlated domain delivery has returned
`EV_GAME_RESULT`. These ordered actions keep board application and wire policy
inside the same reducer transcript without extending the action ABI.

For an accepted remote TAKEBACK, the decision is followed by the correlated
domain apply and only an accepted apply result permits `ACK <ply>`. A rejected
or failed apply emits `NACK <ply> [reason]` and leaves that ply eligible for a
fresh request. PC v1.0 emitted the same successful ACK before its synchronous
snapshot restore; that field wire remains interoperable, but its internal
ordering is not normative because it can acknowledge a state change before
application succeeds. Both current implementations therefore apply before
ACK while preserving the deployed wire payload.

The compact Spectrum implementation restores a prevalidated five-byte undo
snapshot through a void operation; after the request guards pass, that apply
has no runtime failure source. Its parity runner therefore marks the
post-decision apply-failure branch as a visible `KNOWN` non-physical vector,
while still executing real product C for prompt, user rejection, apply-before-
ACK, duplicate re-ACK, and the accepted-ply latch. Implementations with a
fallible apply boundary, including the canonical/PC reducer, must retain the
correlated rejected-result coverage and emit NACK before allowing a retry.

For `SESSION_DELIVER_CONTROL_RESULT`, `data.game.value` identifies the
`SESSION_REQUEST_*` control and the existing `data.game.delivery_id` byte is
`SESSION_CONTROL_ACCEPTED` or `SESSION_CONTROL_REJECTED`. Any payload remains
optional peer detail. Other delivery kinds retain their normal correlation-id
meaning; no action field or ABI size is added.

A CHAT delivery stores `SESSION_CHAT_LOCAL` or `SESSION_CHAT_REMOTE` in its
existing `value` field. The adapter uses that origin only to choose the visible
speaker label; it does not infer origin from TX timing or hidden reducer state.

## DIRECT Normalization Decisions

The pre-refactor PC and Spectrum paths disagree on several crossed controls.
The common reducer freezes one explicit behavior for every disagreement. A busy
GAME START is NACKed without disturbing the operation already pending; crossed
DRAW is ACKed and advances to RESET; crossed RESET during an active game is
NACKed BUSY; and a HOST receiving RQ responds RN without prompting. PING is
always ACKed once the peer is ready, including while another control is pending.
RESIGN is unilateral and idempotent: every received RESIGN is ACKed, it is
applied at most once, and a crossed RESIGN ACK handoff clears the local RESIGN
retry because both peers are already in the game-over state. After a normal
`ACK RESIGN`, the resigning peer changes the same pending control to RESET and
sends `RESET`; the peer that applied the RESIGN accepts that RESET
automatically, replies `ACK RESET` without emitting `ACT_REQUEST_DECISION`, and
both sides start a fresh game after their respective RESET handoffs. A crossed
RESIGN uses the immutable role as a tie-break: only HOST sends the automatic
RESET and GUEST waits to accept it, preventing two simultaneous rematch
requests. The automatic RESET remains correlated and retried as the one pending
control operation; it does not suspend or replace the independent liveness
timer. If that RESET cannot complete, the session remains connected in OVER
with chat available and reports a failed automatic restart rather than closing
the link. A local RESIGN is
the only local control that may preempt a locally originated MOVE after its TX
handoff while that MOVE awaits its numeric ACK. The MOVE control timer is
cancelled, the MOVE is not applied locally, and no later numeric ACK/NACK can
apply, reject, or revive it. Such peer traffic retains the transport's normal
liveness semantics. RESIGN does not preempt an in-flight TX, remote domain
delivery, prompt, RESTORE, or any other pending control.
Duplicate HELLO is consumed without another HELLO, preventing an echo loop.
An otherwise valid MOVE whose ply is not the next expected ply is rejected as
`NACK <ply> SYNC`; `SYNC` is the normative reason token for this divergence.
Older peers may treat the reason as advisory, as required by the wire grammar.

DIRECT liveness is intentionally role-asymmetric and uses elapsed protocol
time, not a raw count of polling calls. A ready guest sends PING after 150 idle
ticks, waits 450 ticks for ACK PING, retransmits PING once after the first
missed window, and ends the session after the second missed 450-tick window.
A ready host does not send PING; it ends the session after two consecutive
450-tick windows without peer data. Any valid peer payload resets the miss
count and rearms the role's initial liveness deadline. Thus an entirely silent
peer ends at 1050 ticks (21 seconds) for a guest and 900 ticks (18 seconds) for
a host. The guest actively probes while the listening host waits for peer
activity; 21 seconds is therefore the worst-case dirty-disconnect deadline,
not a role-symmetric value.

A local handoff failure is also asymmetric by keepalive direction.  Failure to
handoff an outbound `PING` ends the session immediately: the active probe was
not sent, and both the field PC client and normal application sends treat that
transport failure as link loss.  Failure to handoff `ACK PING` is treated as a
lost acknowledgement rather than peer loss: the inbound PING has just proved
the peer and receive path alive, so the session stays live and the peer may
repeat its bounded probe.  MQTT retains its existing fail-hard send policy.

For the compact PAL adapter, the 40 ms polling quantum is derived from product
code: `src/spectrum/overlay/direct_ovl.c` defines `WAIT_POLL` as 2,
`direct_read_payload_ovl()` drains for exactly that count, and
`direct_drain_uart_ovl()` calls `net_wait_frame()` once per iteration. One empty
`SPECTRUM_LINK_READ_TIMEOUT` therefore advances two 20 ms protocol ticks. A
hardware clock must confirm the 3/12/21-second guest cadence and 18-second host
loss. Next 60 Hz cadence is not inferred from this PAL polling seam;
the compact Next runtime must select 75 two-frame polling quanta at 50 Hz and
90 at 60 Hz from the actual video-timing mode.  The same production `ping.c`
must be compiled and tested against both values; testing only the common-core
`ceil(ticks * 6 / 5)` helper does not cover this compact FSM.

Only one control operation may be pending. While a local MOVE, DRAW, or TAKEBACK
is awaiting its peer result, a fresh RESET or DRAW which would create a second
operation is NACKed BUSY (DRAW uses its existing NACK form). This deliberately
differs from the PC legacy path, which can open a second prompt, and prevents one
wire operation from overwriting the correlation, retry timer, or workspace of
another.

CHAT is not a control operation and remains available while START, RESET, DRAW,
RESIGN, or TAKEBACK is pending. A pending MOVE or RESTORE still blocks local
CHAT because both use the shared retry workspace. Adapters must reject a second
control command as pending rather than reporting that the game has not started.

An incoming TAKEBACK while a local MOVE is awaiting its peer result is rejected
as bare `NACK <ply>`; neither the committed ply nor the in-flight move is
applied or undone. PC v1.0 could open a second TAKEBACK prompt in this crossing
because its field gate omitted the pending MOVE. That prompt behavior is
rejected by the one-operation invariant. The bare NACK preserves the deployed
Spectrum rejection wire and avoids adding an advisory reason to the target.

An active guest accepts GAME START with either side, publishes a side change if
needed, and ACKs without restarting the running game. An idle game-over guest
accepts GAME START as a fresh game and emits STARTED after the ACK handoff.

RESET and rejected DRAW do not retain a duplicate latch after their reply has
been handed off: a later request prompts again. An accepted TAKEBACK retains its
ply latch until a move or reset so a lost ACK can be replayed without applying
the takeback twice. An accepted DRAW retains its latch only during the rematch
RESET exchange.

While the accepted TAKEBACK latch is live, the same ply is a duplicate and is
re-ACKed without decision or apply. A different ply is a new operation, not a
duplicate, but the one-ply undo snapshot was consumed by the accepted takeback;
it is therefore rejected as bare `NACK <ply>` without replacing the accepted
latch. An applied MOVE or RESET clears that latch and creates the normal fresh
context; the same numeric ply may then be requested and applied as a new
operation.

After duplicate handling, every fresh TAKEBACK must name the current committed
ply. A different value is bare-NACKed without a decision. This makes RESET at
ply zero invalidate an old TAKEBACK value while still allowing an accepted
duplicate ACK to be replayed even though the successful takeback already
rewound `current_ply`.

A completed restore does not make the next RQ a duplicate. Each accepted RQ
clears the receive mask, both fresh chunks are required before one domain
delivery, and only an exact retransmission of the just-applied chunk may be
re-ACKed with RA.

RS00/RS01 are accepted only after the receiver has handed off RY.  A duplicate
RQ while the decision prompt is open is ignored; after RY and before apply it
re-sends RY without opening a second prompt.  Once applied, either exact cached
RS00 or exact cached RS01 independently re-sends RA without decoding or applying
again.  A conflicting post-apply chunk sends RN without mutating the cached
snapshot.  A later RQ clears the applied duplicate latch and starts a fresh
operation whose two chunks cannot reuse the previous mask.

PC v1.0 retained the same applied snapshot and rejected unsolicited or
conflicting chunks, but delayed duplicate RA until both exact chunks had been
seen again.  That internal batching is not normative: after the complete
snapshot has already been applied, either exact cached chunk proves that RA was
lost, and waiting for its sibling can strand recovery when only one application
frame is retransmitted.  The deployed RQ/RY/RN/RS/RA payloads remain unchanged.

## MQTT Normalization Decisions

The host setup-reannounce timer before peer readiness is internal scheduling,
not an observable session action. The canonical reducer represents its set and
cancel explicitly; the compact Spectrum FSM stores the equivalent countdown in
`mqtt_setup_reannounce_wait`. MQTT parity normalizes those two bookkeeping
actions out of both traces. The timeout event remains a corpus input, and the
resulting host publish, TX guard and all liveness actions remain observable.

The application-reply timer is likewise private scheduling rather than an
observable interoperability action. The compact Spectrum FSM retries after 120
poll iterations; the canonical reducer and PC v1.0 use 125 ticks (2500 ms).
Both cadences conform to the required 2-3 second reply-retry band. MQTT parity
normalizes only the timer SET/CANCEL bookkeeping; the timeout input, resulting
wire retransmission, TX guard and liveness effects remain observable. Any
hardware-visible cadence effect reopens this decision.

Locally originated MQTT GAME START uses the same bounded five-retry
application-reply ladder as the other controls. If no ACK or NACK arrives after
those retransmissions, the sender releases its retained presence and ends the
session; a late reply before exhaustion remains valid.

The peer detail on a rejected MQTT GAME START is optional. Parity requires the
typed `SESSION_DELIVER_CONTROL_RESULT(REJECTED, START)` but does not compare its
payload: the canonical/PC path preserves a wire reason such as `BUSY`, while the
compact Spectrum product surfaces the same rejection without that reason.

Rejected remote MOVE validation is synchronous in both deployed field
products, while the canonical reducer exposes a delivery followed by
`EV_GAME_RESULT`. MQTT parity projects the real Spectrum rules-rejection notice
onto that neutral delivery/result boundary. For that exact rejected-MOVE tuple,
the optional NACK reason and the ACK-versus-GAME MQTT topic are not compared:
receivers dispatch ACK/NACK by payload and the deployed clients use both topic
families. The `NACK` verb, exact ply, TX handoff, absence of board/ply advance,
and duplicate re-NACK remain mandatory and target-neutral.

MQTT topic route is authoritative for `MOVE`. Adapters preserve whether a
PUBLISH arrived on the inbound lateral game topic, and both reducers reject a
`MOVE` from every other topic before liveness, state, UI, or wire side
effects. Transport maps that topic metadata but never parses application
verbs. Other payload families retain their existing route-blind behavior; any
additional per-verb route gates require a separately measured change.

A valid live duplicate `J <session>` received by a host before GAME START is a
recovery probe. The host sends exactly one live `H <color> <session>` again and
does not repeat READY, board or UI state. Send failure retains MQTT fail-hard
teardown. Retained JOIN, stale session, conflicting host and active-game guards
remain unchanged.

For a guest that is READY but has not started a game, a valid live
`H <color> <new-session>` replaces the dead bootstrap identity. The guest
cancels liveness for the old id, adopts the new side/session, performs a fresh
retained-ONLINE/live-JOIN claim and reaches READY once. This is a fresh
pre-game handshake, never game resume or replay. A different session remains
stale and inert in ACTIVE or OVER.

## Link Loss Contract

`EV_LINK_DOWN` for the active link always terminates the current session. The reducer cancels its
armed session timers, invalidates pending transmissions and controls, clears
session-scoped state, and emits `ACT_SESSION_CHANGED(ENDED)`.

An event for another link is a candidate/intruder event. Rejecting or losing
that link must not alter the active session. DIRECT BUSY is emitted and closed
against that candidate link only.

Once the active peer has completed HELLO validation, candidate RX emits
directed BUSY and then closes only the candidate even while a control decision,
TAKEBACK, or RESTORE RECEIVE operation is pending.  Those operations and any
partial RESTORE chunks remain owned by the active link.  Before peer validation,
the candidate is closed without BUSY so an incomplete handshake is not
misreported as an occupied game.  Adapter serialization completes any current
TX handoff before delivering the candidate RX; it never creates a second
simultaneous owner of the single DIRECT TX scratch.

`ACT_SESSION_CHANGED(ENDED)` requires the caller to discard the active game and
its move history. A later `EV_LINK_UP` begins a new handshake, session, and game
from initial state. No state, action, or transition may suspend, resume, restore,
or replay a previous game after link loss.

MQTT retained/live flags are broker metadata for presence and control payloads
only. They never authorize retaining a game position or move history.

While the Spectrum/Next UI is waiting without a ready peer, TABOPTION is not
available. This includes the MQTT host wait after peer loss, where the board and
game have already been discarded. `BREAK` remains the local escape to setup;
FILE/load and every other TABOPTION action stay unreachable until a peer is
ready again. DIRECT and MQTT use the same UI gate.

## Time Contract

One protocol tick is exactly 20 ms, matching one PAL 50 Hz frame.

- PC schedules `duration_ticks * 20` milliseconds.
- ZX PAL schedules one video frame per protocol tick.
- Next 50 Hz schedules one video frame per protocol tick.
- Next 60 Hz compensates instead of accepting 20% drift: it schedules
  `ceil(duration_ticks * 6 / 5)` video frames.
- An adapter for any other refresh rate must round up so a timeout never fires
  earlier than the requested protocol duration.

The core never reads a clock and receives no platform tick counter. It requests
a timer with `ACT_TIMER_SET`; the adapter later injects exactly one current
`EV_TIMEOUT(timer_id)`. PC performs duration multiplication in at least 32-bit
arithmetic.

MQTT peer liveness is application protocol, never broker keepalive. After live
peer activity the reducer requests 250 ticks (5 seconds) of idle time, emits
application `PING`, and only after successful local handoff requests the
remaining 350 ticks to the 12-second total peer deadline used by PC v1.0. A
matching live application `ACK PING` restarts the 250-tick idle interval. An
MQTT payload credit is deliberately narrower than payload acceptance: only a
non-retained, recognized game/control event, application `PING`, or matching
outstanding `ACK PING` proves liveness. Presence and setup traffic never
credits the watchdog, even when current; retained replay, stale-session
presence, local presence echoes and foreign setup therefore remain inert.
PINGRESP belongs entirely to adapter/broker framing and must never be converted
into a session event or used as evidence that the peer is alive. Expiry of the
application peer deadline ends and discards the session without requesting
closure of a still-live broker transport. Before that logical end, a current
room HOST with an established peer publishes retained
`F <peer-side> <session-id>` to the peer presence topic. A guest never reclaims
the peer seat. Failed peer release is fail-hard cleanup, not successful room
recovery; it does not relax the deadline or resume/replay the ended game.

The compact Spectrum/Next adapter implements the same bounded PING-to-ENDED
semantic frontier with its frame-polled watchdog: one application PING every
120 read-wait iterations, four outstanding misses, and `LOST` at the fifth
frontier. At two PAL frames per read wait this models about 24 seconds; physical
peer-kill and stale-ACK runs repeatedly measured 18–26 seconds. Its private
deadline bookkeeping is therefore not required to reproduce the reducer's
250/350 timer actions, but it must still send application PING, remain bounded,
discard the game at `LOST`, and perform the same retained-seat cleanup policy.

## Payload Ownership

`EV_RX`, `EV_LOCAL_REQUEST`, and `EV_GAME_RESULT` input pointers are valid through the current
`session_step()` call and synchronous execution of its returned actions. The
core may borrow an RX payload only for `ACT_DELIVER_GAME`; it must never retain
an input pointer in `SessionState`. The adapter executes or copies such an
action before mutating the input buffer or re-entering the core.

Except for the two fixed binary cases below, every input slice has a readable
NUL sentinel at `payload[length]` and contains no embedded NUL byte. The
sentinel is outside the counted payload. This lets the core reuse the existing
common C-string grammar without copying or adding a second parser.

The first exception is the fixed 60-byte local restore buffer. It holds the 60
ASCII characters of the unpadded Base64URL encoding, not the 45-byte binary
save record, and is validated byte-for-byte without reading `payload[60]`.
This allows the existing 60-byte save buffer to become `SessionWorkspace`
without one extra BSS byte.
The other exception is the exactly one-byte phase detail on an accepted remote
RESTORE result. It is range-checked directly as `READY`, `ACTIVE`, or `OVER`
and never passed to a string parser.

RESTORE remains core session policy for both DIRECT and MQTT:
RQ/RY/RN/RS00/RS01/RA are parsed and sequenced by the reducer. File I/O,
snapshot encoding/decoding, and applying the delivered snapshot remain domain
work reported through `EV_GAME_RESULT`.
The host's local request phase/value and the guest's accepted game-result
phase/value keep `SessionState.phase` and `SessionState.current_ply`
synchronized with the restored board. While a local restore waits for RY/RA,
its phase is packed into unused high bits of `restore_mask`; this adds no state
or event-union bytes. The next request therefore uses both the restored game
phase and ply rather than either pre-restore value.

For MQTT, only the host initiates RESTORE and every frame uses
`SESSION_ROUTE_GAME` on the directional game topic, live and non-retained.
`RQ`, `RY`, `RN`, and `RA` are exact two-byte ASCII frames. `RS00` and `RS01`
are each exactly 35 wire bytes: a five-byte `RS0n ` prefix followed by 30 ASCII
Base64URL characters, with no padding or NUL terminator. The ordered success
path is `RQ -> RY -> RS00 -> RS01 -> RA`; the receiver emits one 60-character
encoded domain delivery only after both chunks arrive.

The CONTROL timer bounds the exchange. A local sender retries `RQ` while
waiting for `RY`, then retries the ordered chunk pair while waiting for `RA`.
A receiver re-sends `RY` for an accepted duplicate `RQ`, waits a bounded number
of control deadlines for missing chunks, and sends `RN` on rejection, apply
failure, or receive expiry. A zero-length local RESTORE cancels only the
pre-`RY` wait by sending `RN`; cancellation is ignored after `RY`. After apply,
either exact cached chunk independently re-sends `RA`; a conflicting chunk
sends `RN` without decoding or applying again.

Once a DIRECT link is up, local BYE may preempt handshake or any pending
control. It still follows TX-result ownership: the session ends and the link
closes only after successful local handoff, or through the failed-TX path.

An active-peer BYE ends the game immediately without a BYE reply. Both local
and remote BYE discard every pending control, cached RESTORE chunk, applied
duplicate latch, move/takeback retry, and game history. DIRECT tears down the
logical adapter. MQTT remote BYE instead preserves the broker connection and
the local retained seat, marks the peer absent, and waits for a new opponent on
the same link. Before waiting, an MQTT HOST publishes retained
`F <peer-side> <session-id>` so a delivered BYE remains authoritative even if
the departing peer's own retained cleanup is lost. Failure to release that
peer seat is fail-hard cleanup: the host attempts to clear its local retained
seat, then ends the broker session. MQTT GUEST does not reclaim the host seat.
This uses existing wire frames and remains mixed-version compatible; an older
host still depends on the departing peer's own `F` reaching the broker. CLOSE denotes
logical adapter teardown and does not by itself claim that ESP-AT emitted or
accepted `AT+CIPCLOSE`. An explicit active `EV_LINK_DOWN` is already physical
closure and therefore ends without requesting a second close.

The core builds every outgoing application payload in caller-provided
`tx_scratch`. An `ACT_SEND` payload points into that scratch and remains valid
only until the next `session_step()` call. The adapter must completely transmit
it or copy it to adapter-owned storage before re-entering the core.

The adapter must not retain an `ACT_SEND` pointer, rebuild its payload, or let a
later RX/event overwrite the scratch while transmission is in progress.

DIRECT requires one caller-owned TX scratch of at least 48 bytes for the whole
session. The reducer rejects a smaller capacity before mutating state; this
covers later restore chunks and rematch replies, not only the first verb.

## Transmission Result Semantics

`EV_TX_RESULT(OK)` means only that the local adapter accepted or drained the
bytes according to its transport contract. It never means that the peer
received or accepted the message.

PC reports OK after equivalent local socket handoff. The host Spectrum runner
normalizes completion of the real UART/ESP send path to the same observation;
the production Z80 runtime does not instantiate `EV_TX_RESULT`. MQTT PUBACK,
where present, remains transport delivery evidence, not application acceptance.
Peer acceptance is proven only by a received wire ACK.

Reference-core adapters serialize reducer reentry. After executing `ACT_SEND`,
they inject its `EV_TX_RESULT` as soon as the local handoff completes and before
dispatching a later socket/UART/UI event. If the platform handoff is
asynchronous, those later
events remain queued. This preserves the single TX scratch lifetime and lets an
incidental PING, BUSY reply, or RN complete before the correlated user/domain
result is dispatched.

## C Dialect And Cost Rules

The public header must carry this implementation contract:

- C shaped as C89, with `<stdint.h>` for fixed-width types.
- Store tags, states, flags, and booleans as `uint8_t`; use `uint16_t` only
  where the protocol requires it.
- Do not store C `enum` values in state/action structs; use byte constants.
- No heap, recursion, VLA, bitfields, variadics, platform types, or C++ types.
- No function pointers unless measured generated ASM proves them cheaper than
  the direct alternative.
- No heavy libc calls in Spectrum paths.
- All buffers have explicit byte capacities and caller-owned lifetime.
- The C API is exposed to C++ through `extern "C"` only.
- Tables and switches are selected by measured size/codegen, not preference.

## Spectrum Budget

Every phase that changes code destined for ZX or Next records linked CODE,
DATA, BSS, overlay sizes, and SP/BSS gap against tag
`baseline-pre-refactor` during that same phase.

- Final resident CODE: no more than baseline plus 128 bytes.
- Final BSS: no larger than baseline.
- No overlay may exceed its baseline size or the 2048-byte hard limit.
- The SP/BSS gap may not shrink.
- New state replaces old globals; it must not remain additive after migration.
- `src/common/session/` and its generic action executor are not linked into the
  Spectrum targets.

Fast iterations may use host tests and the existing inner-loop ASM check, but
neither is size evidence. A target phase is not accepted until the production
link, map, BSS/stack calculation, and overlay measurements pass.

If target code exceeds the allowance, the authorized path is:

1. Remove all replaced legacy logic and duplicated strings first.
2. Run `shrink-z80` on the actual Z80 implementation and generated call sites.
3. Select smaller measured switch/table/builder forms without changing the
   frozen behavior.
4. Stop for an explicit architecture decision if it still does not fit.

Moving the hot reducer into an overlay or silently increasing the allowance is
not authorized as an in-flight workaround.

## Acceptance Invariants

- PC executes the common DIRECT/MQTT reducers; ZX and Next execute their compact
  production FSMs.
- One judge runs the same transcript objects and expected observations against
  the canonical reducer and the host-compiled Spectrum implementation.
- PC session policy exists only in common reducers. Spectrum session policy
  remains only in its guarded compact implementation, never in a generic
  adapter alongside it.
- PC application/UI code never parses session wire verbs. Spectrum parsing and
  decisions stay inside the existing compact session/application boundary.
- Transport mechanics do not add a third session-policy implementation.
- On the reference path, time enters only through current `EV_TIMEOUT` events
  and outgoing payloads obey the scratch lifetime.
- Application ACK and local TX completion remain distinct facts.
- Link loss ends the game; no game position or move history is resumable.
- Native host tests and the shared judge require neither Qt nor z88dk.

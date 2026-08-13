# Session Core Phase 6 Ledger

## Scope and immutable gate

- Worktree: `experiments/phase6-mqtt`
- Branch: `refactor/session-core-phase6-mqtt`
- Base HEAD: `2762c566032e36a9d9994edf94798a58553bb4ef`
- Initial tree: clean
- Open phase: Phase 6 only; Phase 5 remains closed.
- Ownership: target-neutral MQTT transcripts plus the canonical host/PC reducer
  behind `session_step()`; no Qt adapter, broker framing, Spectrum source,
  z88dk build, target artifact, DIRECT change, or hardware claim.

## Cost model

- Preserve deployed H/J/O/F, session/seat, start/game/control, liveness, and
  link-loss semantics with one expectation per neutral transcript.
- Preserve the public event/action ABI, caller-owned buffers, one `ACT_SEND`
  maximum per step, and local TX completion distinct from application ACK.
- Phase 6 target cost is exactly zero CODE/BSS/stack/overlay bytes because the
  reducer is host-only and is not linked into ZX/Next.
- Smallest relevant checks: focused MQTT transcript first; then canonical
  DIRECT suites and host boundary/source guards. No target build.

## Option ledger

| Opción | Evidencia | Coste/riesgo | Verificación | Decisión |
|---|---|---|---|---|
| Corpus neutral + reducer C host-only detrás del ABI actual | Plan Phase 6 | Superficie mínima | suites nativas | do |
| Reutilizar gramática común MQTT ya instalada | `mqtt_session_protocol.*` | Evita parser/policy duplicada | test protocolo + corpus | do |
| Reutilizar lógica Qt o introducir broker framing en core | PC v1.0 | dependencia/plataforma y tercera policy | guard de fuentes | reject |
| Enlazar/probar Spectrum o z88dk ahora | Plan Phase 8 | mezcla de fases y coste target | no comandos target | reject |
| Cambiar wire o ampliar ABI público para resolver carreras de broker | contrato congelado | rompe compatibilidad/fase | stop condition | reject |

## Claude vectors — non-blocking

- Two guests simultaneously probing the same seat: MQTT v1 has no atomic
  compare-and-claim primitive. Phase 6 records and exercises deterministic
  retained/live filtering, but does not invent a lease, broker transaction, or
  target-specific winner. This is a concurrency vector, not a blocker for the
  canonical single-event reducer.
- A second host in the same room: a live `H` with a different session is a host
  conflict and must not make either host peer-ready or start a game. Phase 6
  covers the reducer observation without changing topic/wire policy. This is a
  non-blocking hostile/concurrent-client vector.

## Block 1 — `mqtt-seat-acquire-retained-vs-live`

State: closed.

Evidence:

- MQTT policy: retained `H` selects only the prospective session/seat probe;
  only exact retained `O <own-color> <sid>` proves BUSY.
- PC v1.0 `handleMqttSessionPayload`: retained `H` changes the prospective side
  and subscribes without claiming; exact retained own-seat `O` reports BUSY;
  live own `O` and wrong-session `O` do not.
- Live `H` is authoritative for a guest. Canonical core serializes the seat
  claim as retained `O`, then live `J`, one send per TX-result step.
- DIRECT canonical BUSY normalization is `BUSY`, link close, then `ENDED`;
  MQTT seat occupancy uses the same normalized terminal observations without
  sending a wire `BUSY` payload.

Planned neutral scenarios:

1. retained valid `H`: prospective side/session only; no READY and no send;
2. exact retained own-seat `O`: `BUSY`, close active link, `ENDED`;
3. live own `O`: ignored as an echo, no false BUSY;
4. retained own-seat `O` with another session: ignored;
5. live valid `H`: side/session fixed, retained `O` then live `J` serialized;
6. duplicate H/J/O: idempotent observations;
7. failed TX: fail-hard; if own retained `O` was handed off, publish retained
   `F` before ending so the reducer does not deliberately leave a zombie seat.

Acceptance/rollback:

- Accept when all seven scenarios are green through the neutral corpus and
  canonical runner, with no target-specific expectation.
- If the ABI cannot express the required probe/side/send sequence, archive the
  red and stop with `ARBITRO`; do not leak subscription or broker policy into
  the reducer.

## Block 2 — MQTT bootstrap, presence, session and stale traffic

State: closed.

Transcript decisions before product:

- Retained or id-less `F`, wrong-side/session H/J/O/F, and retained peer O/F
  remain non-authoritative and cannot set READY or end the current session.
- Live exact opponent `F <side> <sid>` is a semantic peer disconnect: cancel
  session timers, emit `ENDED`, discard all session state, and require a new
  `EV_LINK_UP`. It does not close the still-live broker transport; this matches
  PC v1.0 while preserving the contract's fresh-session rule.
- Live exact own-side `F` during a current session republishes retained own O;
  TX completion only restores liveness and is not peer acceptance.
- Host setup timeout republishes canonical H through the same control route,
  still one send per step, and rearms setup only after local TX completion.
- Empty retained payload is ignored.

Acceptance: neutral stale/presence/offline/reannounce transcripts green; then
focused MQTT plus the three canonical host suites. No target or broker run.

## Block 3 — MQTT side, readiness and start

State: closed.

Transcript decisions before product:

- Guest/local START and host START before READY are no-ops; only a READY host
  emits canonical plain `GAME START` on the control route.
- `EV_TX_RESULT(OK)` for GAME START is local handoff only and arms the
  application-reply timer. Host becomes ACTIVE/STARTED only after live
  `ACK GAME START`; NACK returns a typed rejected START result.
- READY guest accepts only live GAME START after authoritative live H, becomes
  STARTED, and sends `ACK GAME START`. Retained start and host-received start
  are ignored.
- Duplicate live GAME START is idempotently re-ACKed without a second STARTED.
  Optional start detail is accepted, but canonical host output stays plain.

Acceptance: neutral role/readiness/ACK/NACK/duplicate transcripts green with
one send per step and explicit TX-vs-app-ACK separation.

## Block 4 — MQTT MOVE/ACK and TX completion

State: closed.

Transcript decisions before product:

- Local MOVE copies its coordinate into caller workspace, sends `MOVE <ply>
  <move>`, and waits. TX OK only arms the application reply; matching live ACK
  emits ordered LOCAL_MOVE then accepted result and advances ply. NACK reports
  a typed rejected result without advancing.
- Remote live MOVE on the game route is parsed by common grammar and delivered
  to the domain. Only correlated `EV_GAME_RESULT` may advance ply and emit
  ACK/NACK; application result precedes wire acknowledgement.
- Retained MOVE, wrong route, wrong ply, unsolicited/wrong ACK, and invalid
  local coordinates cannot mutate play state. Accepted/rejected remote
  duplicates are answered idempotently.
- MOVE send failure remains fail-hard and uses the already-proven retained-F
  cleanup path if own O was handed off.

Acceptance: local ACK/NACK, remote accepted/rejected, duplicate, sync/route,
and TX-failure transcripts green; one ACT_SEND maximum and all game actions
ordered exactly.

## Block 5 — MQTT controls and duplicates

State: closed.

Transcript decisions before product:

- CHAT is target-neutral game traffic: local display follows successful TX
  handoff, remote live chat is delivered once, retained/malformed chat is
  neutral, and a receive-only chat delivery may coexist with an outstanding
  TX without taking ownership of the shared transmit scratch.
- RESET, DRAW, RESIGN, and TAKEBACK retain the frozen common-core ordering and
  duplicate rules. TX completion only advances the local handoff stage; peer
  ACK and correlated domain results remain distinct events.
- RESET/DRAW decisions use `ACT_REQUEST_DECISION`; accepted remote TAKEBACK is
  applied through `EV_GAME_RESULT` before ACK. Rejected/failed TAKEBACK remains
  eligible for a fresh request; accepted same-ply duplicate is re-ACKed and a
  different ply is bare-NACKed until MOVE/RESET clears the latch.
- Crossed DRAW converges through ACK then RESET; active crossed RESET is BUSY;
  RESIGN is unilateral/idempotent and every duplicate is ACKed. A pending MOVE
  is not overwritten by incoming RESET, DRAW, or TAKEBACK.
- Local controls retransmit unchanged after reply timeout. No control path may
  emit more than one send in a step or parse topic/client identity.

Acceptance: neutral CHAT, local/remote RESET/DRAW/RESIGN/TAKEBACK, prompt,
domain-result, retry, crossed-control, BUSY, and duplicate transcripts green;
then canonical host regressions.

## Block 6 — MQTT liveness

State: closed.

Transcript decisions before product:

- Application liveness is reducer-owned `PING`/`ACK PING`; broker PINGREQ,
  keepalive packets, topic framing, and clocks stay in the adapter. PC v1.0
  fixes 5 s idle and 12 s total peer deadline, represented as 250 protocol
  ticks idle then 350 remaining ticks after local PING handoff.
- Idle timeout sends one PING and arms only the TX guard. Successful local
  handoff arms the remaining peer deadline; retained/stale ACK PING is neutral,
  matching live ACK PING clears the outstanding probe and rearms 250 ticks.
- Every live PING from a ready peer is ACKed, including while a game control is
  pending. The serialized ACK handoff must preserve that control and its reply
  timer. Live peer activity clears an outstanding probe and restarts idle time.
- Expiry of the outstanding peer deadline emits ENDED and discards session
  state without closing the still-live broker transport. TX-guard expiry is
  fail-hard and uses retained-F cleanup before close/ENDED when own O was
  handed off.

Acceptance: idle probe, live/stale ACK, incoming PING during control, activity
reset, peer deadline, and TX-guard cleanup transcripts green; then canonical
host regressions.

## Block 7 — MQTT link loss, BYE, and fresh session

State: closed.

Transcript decisions before product:

- `EV_LINK_DOWN` for another link is neutral. Loss of the active broker link
  cancels every armed reducer timer, invalidates pending TX/control/domain work,
  emits ENDED without a redundant CLOSE, and makes all late results and old
  traffic inert until a new `EV_LINK_UP`.
- The post-loss link must repeat side/session selection, retained online claim,
  join/readiness, and game start. Ply, duplicate-result latches, user decisions,
  retry counters, and game state start empty; retained traffic from the old
  session cannot resume or replay it.
- Local BYE may preempt handshake or a pending control when no TX handoff owns
  the scratch. It sends live BYE first; after successful handoff it serializes
  retained own-side F when a seat was claimed, then requests logical adapter
  CLOSE and emits ENDED. Failed BYE handoff uses the same retained-F cleanup.
- A live, non-retained control-route BYE from the validated peer ends
  immediately without replying: all timers/work are discarded, then CLOSE and
  ENDED are emitted. Retained, wrong-route, wrong-link, or pre-peer BYE is
  neutral.

Acceptance: active/wrong-link loss, late-event invalidation, full fresh-session
cycle, duplicate/ply reset, local BYE success/failure staging, and remote BYE
preemption transcripts green; then canonical host regressions and formal Phase
6 purity/target-scope gate.

## Formal Phase 6 closure

State: closed by Codex validation; independent mailbox verdict pending.

- Corpus: 40 target-neutral MQTT transcripts cover retained/live H/J/O/F,
  seat/session/side selection, stale filters, readiness/start, MOVE/ACK/NACK,
  retries and duplicates, CHAT/RESET/DRAW/RESIGN/TAKEBACK, application PING,
  TX completion/failure/guard, active link loss, BYE, and mandatory fresh game.
  Every step compares ordered actions exactly; the runner independently rejects
  more than one `ACT_SEND` in any step.
- ABI: MQTT is dispatched behind existing `session_step()` through an internal
  reducer entry. Public `session.h` is unchanged; canonical host measurement is
  still `SessionState=36`, `SessionEvent=24`, `SessionAction=24`, and
  `SessionWorkspace=60` bytes.
- Validation: focused MQTT, canonical core, DIRECT core, DIRECT parity, and all
  module guards exit 0. `git diff --check` exits 0 apart from existing Windows
  LF→CRLF notices.
- Purity: the MQTT reducer/corpus/runner include only common session/protocol
  headers plus C stdlib. A forbidden-token search for Qt, broker-client,
  Spectrum, z88dk/esxDOS, ESP-AT, PC/client, and target paths returns no match.
- Scope: target-root diff for `src/spectrum`, `src/pc`, `client`, `asm`, and
  `assets` is empty. No Qt, broker, Spectrum, z88dk, packaging, size, or
  hardware build ran; no commit was made. Module guards prove the generic core
  remains excluded from Spectrum, so Phase 6 target CODE/BSS/stack/overlay cost
  is zero by linkage.
- Arbiter/divergence: PC v1.0 owns canonical 5 s idle/12 s total application
  PING policy. The compact target's current 120-tick/four-miss cadence is Phase
  8 reconciliation evidence, not a second Phase 6 expectation. Simultaneous
  seat claim and second-host races remain recorded non-blocking wire-policy
  vectors; Phase 6 invents no broker transaction or lease.
- Remaining risk: adapters and hardware have not consumed this reducer yet by
  design. Next gate is Phase 7 PC/adapter mapping against this corpus, followed
  by Phase 8 target-policy reconciliation, target builds, size/ABI guards, and
  hardware validation.

## Evidence log

- 2026-07-14 19:20 — gate — branch/HEAD/tree matched; Phase 6 handoff and
  allowed normative surfaces read in order; Phase 6 review mailbox absent.
- 2026-07-14 19:31 — RED `mqtt-seat-acquire-retained-vs-live` —
  `make NO_COLOR=1 session-mqtt-core-test` compiled the neutral corpus and
  canonical runner, then exited 1 at `retained host selects probe only`:
  expected exactly `ACT_SIDE_CHANGED(BLACK, 77)`, observed zero actions.
  Cause: `session_step()` has no MQTT reducer dispatch and returns zero for the
  event. Classification: product missing, not instrument or contract gap.
  Next accepted patch: minimum MQTT dispatch/reducer behavior for retained `H`.
- 2026-07-14 19:31 — GREEN first transcript —
  `make NO_COLOR=1 session-mqtt-core-test` exited 0; one neutral transcript
  passed. Product delta is limited to MQTT dispatch, link ownership, validated
  retained `H`, prospective side/session state, and one `SIDE_CHANGED` action.
  No peer-ready state or send is produced by retained setup.
- 2026-07-14 19:31 — RED full seat block —
  `make NO_COLOR=1 session-mqtt-core-test` compiled five neutral transcripts
  and exited 1 with 20 action-count divergences. The first was `live host
  starts serialized seat claim`; the last was `duplicate peer online only
  refreshes liveness`. The already-implemented retained-H probe steps remained
  green. Classification: missing product semantics for exact retained BUSY,
  live H/O/J serialization, host setup, duplicate refresh, TX fail-hard, and
  retained F cleanup; corpus/instrument and frozen contract are consistent.
- 2026-07-14 19:40 — Claude review — OK to gate, seven seat scenarios,
  terminal MQTT BUSY observations without wire BUSY, retained `F` cleanup, and
  both concurrency vectors as non-blocking. No blocker or contract objection.
- 2026-07-14 19:40 — RED validation instrument — parallel host validation
  reached `session-direct-parity-test` link failure: duplicate definitions of
  all `mqtt_session_protocol.c` parser symbols. Cause: the Makefile parity
  source list already contained that C file and the Phase 6 source insertion
  added it a second time. Classification: instrument/build-list defect, not a
  reducer or transcript divergence. Fix is deletion of the duplicate entry;
  all four checks will be rerun explicitly.
- 2026-07-14 19:40 — GREEN seat block — five target-neutral transcripts and
  31 steps pass: retained-H probe, exact retained-O BUSY terminal path, own-live
  and wrong-session filters, serialized O/J, duplicate H/J/O, host conflict
  non-readiness, TX fail-hard, and retained-F zombie-seat cleanup.
  `make NO_COLOR=1 session-mqtt-core-test` exited 0.
- 2026-07-14 19:40 — regression/guard gate — parallel commands all exited 0:
  `make NO_COLOR=1 session-core-test`,
  `make NO_COLOR=1 session-direct-core-test`,
  `make NO_COLOR=1 session-direct-parity-test`, and
  `make NO_COLOR=1 module-guards`. DIRECT parity reports semantic scenarios OK;
  module guards report zero layering debt and keep the generic core excluded
  from Spectrum.
- 2026-07-14 19:40 — RED block 2 —
  `make NO_COLOR=1 session-mqtt-core-test` compiled seven transcripts and
  exited 1 with six exact action-count divergences: own live-F repair, its TX
  completion, exact peer live-F end, subsequent fresh retained-H selection,
  host setup-timeout reannounce, and its TX completion. All empty, retained,
  id-less, wrong-side, and wrong-session filters passed. Classification:
  product lacks F and timeout handlers; instrument and contract are consistent.
- 2026-07-14 19:50 — Claude review — OK close block 1 and authorize block 2;
  specifically requires explicit old-session retained traffic and id-less F
  poison coverage. Both are present and green in the block-2 red corpus. No
  blocker.
- 2026-07-14 19:50 — GREEN block 2 — two new neutral transcripts/24 steps
  pass (seven transcripts total): empty/retained/id-less/wrong-session stale
  filters, own-F online repair, exact peer live-F terminal ENDED, same broker
  link requiring fresh LINK_UP/session selection, and host retained-H timeout
  reannounce serialized through TX_RESULT. `make NO_COLOR=1
  session-mqtt-core-test` exited 0.
- 2026-07-14 19:50 — block-2 regressions — parallel
  `session-core-test`, `session-direct-core-test`, and
  `session-direct-parity-test` all exited 0; state ABI remains 36 bytes and
  DIRECT semantic parity remains green.
- 2026-07-14 19:50 — RED block 3 —
  `make NO_COLOR=1 session-mqtt-core-test` compiled eleven transcripts and
  exited 1 with ten exact action-count divergences, limited to host START send,
  TX-result reply arm, live ACK/NACK result, guest STARTED+ACK, and duplicate
  re-ACK completion. Guest/host role, pre-ready, retained-start, duplicate-ACK,
  and active-start guards already passed. Classification: missing product
  START handlers; corpus and existing bootstrap reducer are consistent.
- 2026-07-14 20:00 — Claude review — OK close block 2 and authorize block 3;
  confirms plain canonical GAME START output, side/session exclusively from
  presence, and ACK/NACK dispatch by payload rather than topic. No blocker.
- 2026-07-14 20:00 — RED validation instrument — START reducer compiled but
  focused link failed with undefined `netchess_proto_parse_game_start` because
  its existing implementation is in `game_protocol_extra.c`, while the new
  target listed only `game_protocol.c`. Classification: build-list instrument;
  fix is adding the existing common grammar source, no semantic change.
- 2026-07-14 20:00 — GREEN block 3 — four new neutral transcripts/34 steps
  pass (eleven transcripts/89 steps total): host/guest readiness gates, plain
  canonical GAME START, local TX completion distinct from live app ACK, typed
  NACK result, retained/role guards, forward-compatible received detail, and
  idempotent duplicate re-ACK. `session-mqtt-core-test` exited 0.
- 2026-07-14 20:00 — block-3 regressions/guards — parallel core, DIRECT core,
  DIRECT parity, and module-guards all exited 0. State ABI remains 36 bytes;
  generic core remains excluded from Spectrum.
- 2026-07-14 20:00 — RED block 4 —
  `make NO_COLOR=1 session-mqtt-core-test` compiled sixteen transcripts and
  exited 1 with twenty action-count divergences, exactly across local MOVE
  send/app ACK/NACK, remote domain delivery/result ACK/NACK, duplicate replies,
  SYNC reply, and MOVE TX fail cleanup. Active-session prefixes plus retained,
  wrong-route, wrong-ACK and invalid-local guards passed. Classification:
  missing MOVE product handlers; corpus/START/bootstrap remain consistent.
- 2026-07-14 20:15 — Claude review — OK close block 3 and authorize block 4;
  requires MOVE retry/idempotent duplicate, app-ACK-only local apply,
  payload-based ACK dispatch, and q/r/b/n promotion grammar. No blocker.
- 2026-07-14 20:15 — RED block-4 extension — after adding timeout retry and
  explicit q/r/b/n promotion transcript, focused test compiled seventeen
  transcripts and exited 1 with 34 action-count divergences. The additional
  fourteen reds are the new retry/completion and four three-step promotion
  cycles; classification remains missing MOVE product, not instrument.
- 2026-07-14 20:15 — GREEN block 4 — six new neutral MOVE transcripts pass
  (seventeen total): local MOVE is staged until matching live app ACK, NACK is
  typed without advancing, reply timeout retransmits the identical payload,
  remote app result precedes wire ACK/NACK, accepted/rejected duplicates are
  idempotent, retained/wrong-route/wrong-ply traffic is neutral, TX failure
  uses retained-F cleanup, and q/r/b/n promotions round-trip through the common
  grammar. `make NO_COLOR=1 session-mqtt-core-test` exited 0.
- 2026-07-14 20:15 — block-4 regressions/guards — parallel
  `session-core-test`, `session-direct-core-test`,
  `session-direct-parity-test`, and `module-guards` all exited 0. State ABI
  remains 36 bytes; DIRECT semantic parity and transport/layering policies
  remain green. Claude mailbox still has no blocker or objection after the
  archived reds and before closure.
- 2026-07-14 20:30 — RED block 5 —
  `make NO_COLOR=1 session-mqtt-core-test` compiled 28 target-neutral
  transcripts and exited 1 with 81 action-count divergences. Failures are
  confined to the eleven new CHAT/control transcripts: local/remote
  RESET/DRAW/RESIGN/TAKEBACK, prompt and game-result stages, retries, crossed
  controls, BUSY preservation, and duplicate replies. The prior seventeen
  bootstrap/start/MOVE transcripts remain green; retained controls, open-prompt
  duplicate no-ops, and stale/wrong domain-result guards also remain neutral.
  Classification: product lacks control handlers; corpus/instrument and frozen
  contract are consistent.
- 2026-07-14 20:35 — Claude review — OK close block 4 and authorize block 5;
  confirms accepted-request re-ACK, unconditional duplicate RESIGN ACK,
  generic numeric TAKEBACK replies, advisory RESET/DRAW reasons, and requires
  precise TAKEBACK expiry/rejection coverage. The corpus now includes requester
  retransmission while confirmation is outstanding plus typed NACK cleanup,
  receiver rejection/fresh re-prompt, and domain rejection/fresh re-prompt.
- 2026-07-14 20:35 — RED block-5 expiry extension — after adding explicit
  TAKEBACK request retransmission while confirmation is outstanding, focused
  test still compiles 28 transcripts and exits 1 with 83 missing-product
  divergences. The two additional reds are the unchanged TAKEBACK retry send
  and its TX-completion reply rearm. Classification remains missing control
  product semantics; no corpus or instrument defect.
- 2026-07-14 20:45 — GREEN block 5 — eleven new target-neutral control
  transcripts pass (28 total): local/remote CHAT, RESET, DRAW, RESIGN and
  TAKEBACK; typed ACK/NACK results; prompt and domain gates; unchanged retry
  payloads; crossed DRAW→RESET and RESIGN convergence; BUSY serialization;
  accepted duplicate re-ACK; rejection/failure re-prompt; and explicit
  TAKEBACK confirmation-expiry retry/NACK cleanup. `make NO_COLOR=1
  session-mqtt-core-test` exited 0.
- 2026-07-14 20:45 — block-5 regressions — parallel
  `session-core-test`, `session-direct-core-test`, and
  `session-direct-parity-test` all exited 0. State ABI remains 36 bytes and
  DIRECT semantic parity remains green. No Makefile/layout/guard file changed
  in this block, so the already-green module guard gate was not repeated.
  Claude mailbox has no blocker or objection before closure.
- 2026-07-14 21:00 — RED block 6 —
  `make NO_COLOR=1 session-mqtt-core-test` compiled 33 target-neutral
  transcripts and exited 1 with 17 action-count divergences, exactly in idle
  PING emission/handoff, live ACK PING state, peer-deadline termination,
  incoming PING serialization during a pending control, and TX-guard retained-F
  cleanup. The prior 28 transcripts remain green; retained/stale ACK/PING,
  wrong-route PING, and live CHAT delivery/activity expectations are neutral.
  Classification: product lacks liveness and TX-guard timeout handlers;
  corpus/instrument and PC-derived 5 s/12 s timing are consistent.
- 2026-07-14 21:20 — Claude review — OK close block 5 and authorize block 6;
  requires explicit separation of broker PINGRESP from application peer PING,
  notes host-only will policy, retained traffic as non-liveness, and records
  the compact target's current 120-tick/four-miss field policy. Per the Phase 6
  handoff, PC v1.0 arbitrates unspecified canonical MQTT behavior: its 5 s idle
  and 12 s total peer deadline is now explicit in the common contract and sole
  corpus expectation. Target cadence reconciliation remains Phase 8 work, not
  a target-specific Phase 6 branch.
- 2026-07-14 21:25 — GREEN block 6 — five new target-neutral liveness
  transcripts pass (33 total): 250-tick idle application PING, 350-tick
  remaining peer deadline, live/stale/retained ACK PING, broker PINGRESP
  neutrality, PING ACK serialization during a pending MOVE, live activity
  reset, peer-deadline ENDED without broker close, and TX-guard retained-F
  cleanup. `make NO_COLOR=1 session-mqtt-core-test` exited 0.
- 2026-07-14 21:25 — block-6 regressions — parallel
  `session-core-test`, `session-direct-core-test`, and
  `session-direct-parity-test` all exited 0. State ABI remains 36 bytes and
  DIRECT semantic parity remains green. No Makefile/layout/guard source changed
  in this block. Claude mailbox has no blocker or objection before closure.
- 2026-07-14 21:45 — block-7 transcript instrument correction — the first
  transcript-only run reported 12 divergences. Two new remote-RESET setup steps
  had incorrectly expected timer cancellation/arming around a user prompt,
  whereas the already-green canonical control corpus preserves liveness and
  emits only `REQUEST_DECISION` until the user answers. Correcting those two
  expectations before any product edit removed the three downstream false
  divergences. Classification: corpus expectation defect, fixed in corpus.
- 2026-07-14 21:45 — credible RED block 7 —
  `make NO_COLOR=1 session-mqtt-core-test` compiled 39 target-neutral
  transcripts and exited 1 with nine action-count divergences, all in local or
  remote BYE staging/termination. Active-vs-wrong-link loss, pending TX and
  decision invalidation, late-event filtering, complete new-link/new-session
  handshake, ply reset, and duplicate-latch reset are already green through
  shared `session_end()`. Classification: MQTT product lacks BYE handling;
  corrected corpus, runner, and frozen link-loss contract are consistent.
- 2026-07-14 21:55 — GREEN block 7 — seven new target-neutral transcripts pass
  (40 total). They cover wrong/active broker link loss; invalidated TX, user
  decision, and late results; explicit new LINK_UP; complete new session/seat/
  ready/start cycle; ply-one restart; cleared accepted-MOVE duplicate latch;
  local BYE preemption before peer readiness and during a pending control, with
  successful/failed BYE→retained-F→CLOSE staging;
  and guarded remote BYE with immediate no-reply CLOSE/ENDED. `make NO_COLOR=1
  session-mqtt-core-test` exited 0.
- 2026-07-14 21:55 — block-7 regressions/guards —
  `make NO_COLOR=1 session-core-test`, `session-direct-core-test`,
  `session-direct-parity-test`, and `module-guards` each exited 0. State ABI is
  36 bytes; DIRECT semantic parity, layering, overlay capability/ABI,
  transport isolation, and PC/Spectrum DIRECT ownership checks are green. No
  target build ran.
- 2026-07-14 22:00 — closure invariant — the focused runner now rejects any
  step that emits more than one `ACT_SEND`; all 40 transcripts remain green.
- 2026-07-14 22:05 — formal close gate — `session-mqtt-core-test`,
  `session-core-test`, `session-direct-core-test`, `session-direct-parity-test`,
  `module-guards`, and `git diff --check` exit 0. Forbidden platform/broker
  token search returns no match; include inspection contains common/std headers
  only; target-root diff is empty. Branch remains
  `refactor/session-core-phase6-mqtt`; only Phase 6 common/docs/tests/Makefile
  surfaces plus the read-only Claude mailbox appear in status. No target build
  or commit.

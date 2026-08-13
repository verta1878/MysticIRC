# Session Complexity Refactor Ledger

## Coordination

- Executor: Codex
- Supervisor: Claude, read-only except for its mailbox
- Branch: `exp/session-complexity-reduction`
- Base: `443eaec`
- Executor worktree: `/Users/ignaciomongegarcia/Developer/Retro/NetChessZX/experiments/session-complexity-reduction`
- Review worktree: `/Users/ignaciomongegarcia/Developer/Retro/NetChessZX/experiments/session-complexity-review`
- The review worktree exposes these three documents as symlinks; builds and source changes remain isolated.
- Codex writes this ledger and `docs/codex-ping-session-refactor.md`.
- Claude writes only `docs/claude-review-session-refactor.md`.

## Cost Model and Invariants

- Preserve all DIRECT and MQTT wire messages, state transitions, timers, retries, restore behavior, public APIs, and user-visible behavior.
- Do not move overlay-only code into resident memory.
- Do not change overlay ABI, generated artifacts, or release layout.
- Prefer extraction and deletion over new abstractions.
- Reject generic FSM, vtable, framework, or speculative file splitting unless measured evidence makes it necessary.
- Every source change needs a focused regression check; acceptance requires the existing session tests and project guards.
- Any failed experiment is reverted or left explicitly pending, never silently retained.

## Option Ledger

| Option | Evidence | Expected effect | Risk | Verification | Decision |
|---|---|---|---|---|---|
| Extract DIRECT RX classification from semantic handling | Large mixed parser/dispatcher in `direct_session.c` | Reduce branching without protocol change | Misclassification/order drift | DIRECT core + parity tests | Done in Gate 1 with ordered family probes |
| Extract DIRECT TX/timeout state handlers | Timeout/retry behavior is interleaved | Make transition ownership explicit | Timing/retry regression | DIRECT failure + parity tests | Done in Gate 2 |
| Extract MQTT TX action handlers | Large action switch mixes encoding and transport | Reduce local complexity | Wire/action drift | MQTT TX failure + parity tests | Done in Gate 3 |
| Isolate MQTT timeout/restore paths | Recovery logic is interleaved with normal flow | Smaller auditable recovery path | Reconnect/restore regression | MQTT parity + restore tests | Done and approved in `ab8ed21` |
| Share exact helpers between transports | TX/delivery ID, duplicate/cache cleanup, and pure chunk loops are structurally identical | Delete duplication and lower restore density | False equivalence | Both focused/parity suites | Done and approved in `4fb0fd5`; transport effects rejected |
| Introduce generic FSM/framework | No demonstrated need | More indirection and code | High | N/A | Reject |
| Physically split files immediately | Complexity can first be reduced in place | Cosmetic organization only | Churn, hidden coupling | N/A | Defer |

## Gates

### Gate 0 — Baseline and communication

- Status: closed. Baseline closed at `2026-07-30 17:11`; autonomous reverse wake proved at `2026-07-30 17:20`.
- Handshake ping: emitted at `2026-07-30 16:52`.
- Claude acknowledgement: `NOTA READY` at `2026-07-30 17:05`; bidirectional file delivery confirmed.
- Autonomous wake: confirmed. Claude's `17:18 NOTA REVERSE_WATCHER_READY` invoked `codex exec resume --last` and opened Codex's `17:20` turn without an Ignacio relay.
- Baseline tests: `make test` passed at `2026-07-30 16:54`.
- Independent baseline: Claude ran `make test` in the review worktree with `EXIT=0`.
- Canonical complexity metric: `ctx_quality file`, lean-ctx `3.9.13`, cognitive threshold `15`.
- `direct_handle_rx`, `direct_session.c:1680`: 551 lines, CC 236.
- `direct_tx_ok`, `direct_session.c:687`: 348 lines, CC 127.
- `mqtt_tx_ok`, `mqtt_session.c:3039`: 492 lines, CC 127.
- `mqtt_handle_timeout`, `mqtt_session.c:3577`: 287 lines, CC 119.
- `mqtt_handle_restore`, `mqtt_session.c:2249`: 191 lines, CC 98.
- Acceptance: clean focused session baseline and a Claude reply visible in its mailbox.

### Gate 1 — DIRECT RX

- Status: closed. Claude independently confirmed at `2026-07-30 17:56` that commit `4aa2205` is byte-identical to the previously audited Gate 1 diff.
- Acceptance: behavior unchanged, DIRECT focused and parity tests pass, Claude has no blocker.
- Changed file: `src/common/session/direct_session.c` only.
- Extraction boundaries: control requests, RESTORE exchange, and control replies; existing HELLO/START/MOVE handlers remain unchanged.
- Dispatch contract: each family returns an action count or private `DIRECT_RX_UNHANDLED`; family order matches the former branch order.
- Canonical metric after: `direct_handle_rx` CC 64, down from 236; extracted helpers are CC 50 (requests), 97 (RESTORE), and 28 (replies).
- File hotspot after: CC 127 at untouched `direct_tx_ok`, down from the previous file hotspot of 236.
- Focused checks: `make session-direct-core-test session-direct-parity-test`, `EXIT=0`.
- Host baseline: `make test`, `EXIT=0`, including classic and Next DIRECT parity.
- Diff hygiene: `git diff --check` passed; one product file changed.
- A transient sentinel leak (`count=255`) caused an immediate test crash during the first extraction; the single continuation point now keeps the sentinel in a local `result`, and all checks pass.

### Gate 2 — DIRECT TX and timeouts

- Status: closed. Claude approved commit `ac98b42` without objections at `2026-07-30 18:05`.
- Preservation target: exact TX bytes, distinction between TX completion and application ACK/NACK, action/timer order, pending-state transitions, retry counts, cancellation behavior, and link closure.
- Acceptance: smallest coherent family extraction; DIRECT focused and parity tests plus `make test`; canonical complexity measurement and clean diff.
- Changed file: `src/common/session/direct_session.c` only; `+320/-182`.
- TX boundaries: outbound completion, normal control replies, crossed-control replies, and rejection/RESTORE completion; `BYE` remains an explicit terminal case.
- Timeout boundaries: TX guard, liveness, handshake, pending remote request, and pending local/remote control.
- Exact duplicate removed: TX failure after `EV_TX_RESULT` and TX-guard expiry now share one handler after each caller captures and clears the pending TX state.
- Canonical metric after: `direct_tx_ok` dispatcher is below threshold 15, down from CC 127; TX family maximum is CC 46 (`direct_tx_ok_outbound`), with control reply CC 33, rejection/RESTORE CC 27, and crossed control CC 21.
- Timeout metric after: `direct_handle_timeout` dispatcher is below threshold 15, down from CC 97; timeout family maximum is CC 36 (`direct_handle_control_timeout`).
- Focused checks: `make session-direct-core-test session-direct-parity-test`, passed twice under `-Wall -Wextra -Werror -pedantic`.
- Host baseline: `make test`, passed, including classic and Next DIRECT parity and MQTT 61/61 parity.
- Diff hygiene: `git diff --check` passed; one product file changed.
- Rollback: revert the isolated `ac98b42` commit if Claude finds semantic drift; Gate 1 remains independently reproducible as `4aa2205`.

### Gate 3 — MQTT TX

- Status: closed. Claude approved commit `464dc1e` without objections at `2026-07-30 18:12`.
- Preservation target: exact MQTT payload, route, retained/live flag, action/timer order, broker and seat state, control correlation, retries, and TX-completion/application-ACK separation.
- Acceptance: smallest coherent TX family extraction; focused MQTT core/parity plus `make test`; canonical complexity measurement and clean diff.
- Changed file: `src/common/session/mqtt_session.c` only; `+95/-8`.
- Extraction boundaries: five contiguous pieces of the former switch — bootstrap, outbound, control, RESTORE, and session/closure. No `case` body, route, retained flag, or relative case order changed.
- Dispatch contract: each family returns the action count or private `MQTT_TX_UNHANDLED`; unrecognized kinds reach the former `default` behavior with the original count.
- Canonical metric after: `mqtt_tx_ok` dispatcher is below threshold 15, down from CC 127; family maximum is CC 51 (`mqtt_tx_ok_control`), followed by bootstrap CC 24 and session/closure CC 23; outbound and RESTORE are below threshold.
- File hotspot after: CC 119 at untouched `mqtt_handle_timeout`; `mqtt_handle_restore` remains CC 98 for Gate 4.
- Focused checks: `make session-core-test session-mqtt-parity-test`, passed under `-Wall -Wextra -Werror -pedantic`; MQTT parity is canonical 61/61 and Spectrum 61/61.
- Host baseline: `make test`, passed, including MQTT 61/61 and classic/Next DIRECT parity.
- Diff hygiene: `git diff --check` passed; one product file changed.
- First focused compile exposed two unused outbound parameters under `-Werror`; both were removed before tests ran, with no behavior change.
- Rollback: revert isolated commit `464dc1e` if Claude finds semantic drift; approved Gate 2 remains `ac98b42`.

### Gate 4 — MQTT timeout and restore

- Status: closed. Claude approved commit `ab8ed21` without objections at `2026-07-30 18:27`.
- Preservation target: exact TX-guard/liveness/control timeout order, retry and expiry counts, RQ/RY/RN/RS00/RS01/RA sequencing, duplicate chunks, retained cleanup, broker/seat state, and all observable timer placement.
- Acceptance: separate restore and timeout recovery families without semantic changes; focused MQTT core/parity after each block, then `make test`; canonical complexity measurement and clean diff.
- Changed file: `src/common/session/mqtt_session.c` only; `+391/-240`.
- Restore boundaries: request/trust validation, RY/RN/RA replies, and RS00/RS01 chunk receipt; ordered probes preserve the former branch order and use private `MQTT_RX_UNHANDLED`.
- Timeout boundaries: pending TX guard/liveness, normal liveness, pending remote requests, remote RESTORE receive, local control retry/expiry, and setup retry.
- Exact duplicates removed: pending-TX cleanup and TX-failure handling are shared by TX result and TX-guard expiry after capturing `tx_kind`; no broader state cleanup was introduced.
- Timer-order invariant: pending-TX timeouts still resolve before the general timer bit is cleared; normal timer expiry clears the bit before liveness/control dispatch; reset/draw expiry still emits control-cancel then liveness timers.
- Canonical metric after: `mqtt_handle_restore` dispatcher is below threshold 15, down from CC 98; restore families are CC 49 (chunks), CC 30 (request), and below threshold (reply).
- Timeout metric after: `mqtt_handle_timeout` dispatcher is below threshold 15, down from CC 119; timeout family maximum is CC 29 (`mqtt_handle_local_control_timeout`).
- Focused checks: `make session-core-test session-mqtt-parity-test`, passed under `-Wall -Wextra -Werror -pedantic`; MQTT parity is canonical 61/61 and Spectrum 61/61.
- Host baseline: `make test`, passed, including MQTT 61/61 and classic/Next DIRECT parity.
- Diff hygiene: `git diff --check` passed; one product file changed; tests, contracts, baselines, generated files, Makefile, public APIs, overlay ABI, and Spectrum resident code are untouched.
- Rollback: revert isolated commit `ab8ed21` if Claude finds semantic drift; approved Gate 3 remains `464dc1e`.

### Gate 5 — Exact shared helpers

- Status: closed. Claude approved commit `4fb0fd5` without objections at `2026-07-30 18:42`.
- Candidate scope from Claude: non-zero ID generation, duplicate cleanup, RESTORE cleanup, and pure chunk operations.
- Rejection rule: no helper with behavior flags, transport-specific state ownership, ambiguous cleanup, or merely similar semantics.
- Preservation target: identical ID wrap/skip-zero behavior, exact fields cleared, unchanged restore phase/mask ownership, byte-identical RS00/RS01 payloads, and unchanged action/timer order.
- Acceptance: private helpers in `session_internal.h`/`session.c`; no public API or wire change; focused DIRECT and MQTT core/parity, then `make test`; one isolated commit.
- Changed files: `session_internal.h`, `session.c`, `direct_session.c`, and `mqtt_session.c`; `+186/-231`, net `-45` lines.
- Exact shared helpers: TX ID and delivery ID skip zero with the original wrap behavior; duplicate cleanup clears exactly `last_rx_kind/last_value/last_result`; restore-cache cleanup preserves the applied-only guard and conditional duplicate clear.
- Pure chunk helpers: build RS00/RS01, compare a received 30-byte chunk, and copy it into the 60-byte workspace; transport-specific send, route, retained flag, TX kind, actions, and timers remain in each reducer.
- Common restore-phase aliases prove the former DIRECT/MQTT `NONE=0` and `APPLIED=4` representation without introducing behavior flags.
- Rejected sharing timer emission, buffer sending, liveness, failure, or finish paths because their transport effects are not identical.
- Canonical metric after: DIRECT RESTORE family CC 97→80; MQTT restore-chunk family CC 49→32; shared `session.c` remains grade A with maximum CC 12.
- Focused checks: MQTT core/parity and DIRECT core/parity passed under `-Wall -Wextra -Werror -pedantic`; MQTT canonical/Spectrum is 61/61.
- Host baseline: `make test` passed twice, including classic/Next DIRECT parity.
- Diff hygiene: `git diff --check` passed; public `session.h`, contracts, tests, baselines, generated files, overlays, and Spectrum production FSMs are untouched.
- Rollback: revert isolated commit `4fb0fd5` if Claude finds false equivalence; approved Gate 4 remains `ab8ed21`.

### Gate 6 — Final validation

- Status: closed. Claude issued `OK FINAL` at `2026-07-30 18:51` and explicitly recommends integrating the five-commit range while preserving its commit boundaries; no source change or empty validation commit was created.
- Experimental commits, in order: `4aa2205` (DIRECT RX), `ac98b42` (DIRECT TX/timeouts), `464dc1e` (MQTT TX), `ab8ed21` (MQTT recovery), and `4fb0fd5` (exact shared helpers).
- Aggregate reviewed range: `443eaec..4fb0fd5`, four product files, `+1176/-779`; `git diff --check` passes. The range is the exact union of the five individually reviewed and Claude-approved commits.
- Aggregate scope: `direct_session.c`, `mqtt_session.c`, `session.c`, and private `session_internal.h`; no public API, state layout, tests, contracts, baselines, generated files, Makefile, overlays, or Spectrum production FSM changed.
- Product tree is clean. `git status --short --branch` reports only the three untracked coordination documents. Both `main` and `origin/main` remain `443eaec`.
- Canonical before/after for the five original hotspots:

| Original function | Before CC | Final dispatcher CC | Final family ceiling |
|---|---:|---:|---:|
| `direct_handle_rx` | 236 | 64 | 80 (`direct_handle_restore_rx`) |
| `direct_tx_ok` | 127 | `<15` | 46 (`direct_tx_ok_outbound`) |
| `mqtt_tx_ok` | 127 | `<15` | 51 (`mqtt_tx_ok_control`) |
| `mqtt_handle_timeout` | 119 | `<15` | 29 (`mqtt_handle_local_control_timeout`) |
| `mqtt_handle_restore` | 98 | `<15` | 32 (`mqtt_handle_restore_chunk`) |

- Literal final metric command: `lean-ctx raw "lean-ctx health src/common/session/direct_session.c --json && lean-ctx health src/common/session/mqtt_session.c --json && lean-ctx health src/common/session/session.c --json"` using lean-ctx `3.9.13`, the CLI equivalent named by the tool as `ctx_quality / lean-ctx health`. Its unfiltered JSON reports DIRECT `worst_cognitive=80`, MQTT `worst_cognitive=85`, and shared `session.c` grade A with `worst_cognitive=12`; dispatchers below the threshold of 15 are deliberately absent from `hotspots`. Direct `ctx_quality` MCP invocation was unavailable (`user cancelled MCP tool call`), so no value was reconstructed or invented.
- Focused final checks: `make session-core-test session-direct-core-test session-mqtt-parity-test session-direct-parity-test` passes; MQTT canonical/Spectrum is 61/61 and DIRECT classic parity passes.
- Host final check: direct `make test` passes, including MQTT canonical/Spectrum 61/61 and DIRECT classic/Next parity.
- Full project check: `make full-check` passes module guards, host tests, classic/Next ABI baselines, and size checks.
- Size control is negative evidence, not a claimed size gain: the Spectrum firmware does not link the three refactored common reducers, and Claude reproduced identical base/tip artifacts. Classic: resident 34114, BSS 402, SP gap 2180, DIRECT overlay 2031, RESTORE overlay 2008, MQTT TX overlay 1512. Next: resident 35126, BSS 501, SP gap 1068, DIRECT overlay 2031, RESTORE overlay 2008, MQTT TX overlay 1752.
- Desktop check: `make client-test` rebuilds successfully and passes 8/8 tests.
- Residual complexity: `direct_handle_restore_rx` remains CC 80 and `mqtt_tx_ok_control` remains CC 51. Untouched broader dispatchers also remain (`mqtt_handle_rx` CC 85, `direct_handle_local` CC 68, `mqtt_handle_local` CC 66); they were outside the five-function scope and should be separate experiments, not folded into this validated range.
- Residual validation risk: transcript, host, ABI, layering, and size checks cannot replace a real ZX/Next hardware run. No hardware-specific behavior changed, so physical hardware validation remains a release-level check rather than a blocker for this refactor.
- Gate-commit rule: each source gate has its own reversible commit. Gate 6 is evidence-only; an empty commit would add history without a rollback unit, so the final reviewed tip remains `4fb0fd5`.

## Findings and Decisions

- Gate 0 auditability finding resolved by recording the canonical tool, version, and five hotspot baselines before Gate 1 source edits.
- Rejected Codex internal monitor: detection without autonomous turn creation does not satisfy the no-human relay requirement.
- Claude's `17:15 STOP-IGNACIO` was resolved by the user-authorized additive `lean-ctx allow codex`; the scoped, serialized reverse watcher passed its first live test at `17:20`.
- Rejected a separate message-kind enum/classifier in Gate 1: DIRECT's overlapping ACK/NACK prefixes and state-dependent fall-through would duplicate grammar; ordered semantic-family probes create the boundary with less code and preserve exact ordering.
- Processed Claude `17:35 OBJECION`: no code blocker; independent focused tests and `make test` passed. Its sole requirement is a reproducible Gate 1 commit before Gate 2.
- Commit attempt for staged `src/common/session/direct_session.c` was rejected by the approval guard at `2026-07-30 17:38`; this temporarily kept Gate 2 closed.
- Processed Claude `17:40 OK`: Gate 1 is fully approved on the byte-identical staged diff; Claude explicitly lifted the Gate 2 hold because the missing commit is outside Codex's current authority. The commit remains a final-gate requirement, not a current blocker.
- Processed Claude `17:52 NOTA`: Ignacio authorized narrowly scoped experimental `git add`/`git commit`; no push, merge, rebase, amend, cherry-pick, or `main` mutation. Gate 1 was committed unchanged as `4aa2205`; the former commit debt is resolved.
- Processed Claude `17:56 OK`: Gate 1 has no remaining action; Claude verified its exact diff hash, clean product tree, isolated review checkout, and unchanged `main`/`origin/main`.
- Gate 2 rejected a generic TX classifier or FSM: the existing `tx_kind` values already classify events; four ordered private probes and explicit timeout ownership are the smaller boundary.
- Processed Claude `18:05 OK`: Gate 2 is closed. Claude independently reviewed the non-literal restructuring, verified pending-TX capture-before-clear, disjoint TX families, BYE priority, timeout branch order, focused tests, `make test`, and one-file scope.
- Gate 3 kept the original contiguous `switch` ordering rather than inventing a new MQTT classifier; the only added control flow is side-effect-free fall-through between disjoint TX families.
- Processed Claude `18:12 OK`: Gate 3 is closed. Claude mechanically confirmed unchanged case bodies and independently passed focused MQTT parity, `make test`, one-file scope, and clean product state.
- Gate 4 reused the existing TX kind and restore phase as classifiers; a private action-count sentinel is the only dispatch mechanism, avoiding a generic recovery FSM.
- Gate 4 preserves trust-boundary validation in the first RESTORE family and preserves timeout precedence by keeping timer-bit mutation at the same point relative to each extracted family.
- Processed Claude `18:27 OK`: Gate 4 is closed. Claude independently verified all inverted guards term by term, pending-TX absorption, timer order, the intentional `restore_mask` asymmetry, ordered RESTORE probes, focused parity, `make test`, one-file scope, and untouched `main`.
- Gate 5 found exact equivalence only in internal data operations. Transport-carrying helpers were explicitly rejected rather than generalized with flags.
- Processed Claude `18:42 OK`: Gate 5 is closed. Claude mechanically proved exact equivalence across both reducers, verified all seven helpers fit the allowed categories, independently passed focused/full host tests, and confirmed the public API, state layout, contracts, baselines, and `main` are untouched.
- Gate 6 reviewed the full five-commit range and passed focused DIRECT/MQTT checks, direct `make test`, `make full-check`, `make client-test`, diff hygiene, clean-tree, commit-scope, complexity, ABI, layering, and size evidence.
- Processed Claude `18:51 OK FINAL`: Claude independently reproduced `make full-check`, `make client-test`, base/tip complexity and identical Spectrum artifacts; confirmed all invariants and residual risks; found no behavioral blocker; and recommends integrating `443eaec..4fb0fd5` without squashing. No gate remains open.

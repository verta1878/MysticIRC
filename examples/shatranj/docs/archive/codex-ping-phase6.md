2026-07-14 19:31 | RED | retained H probe expected SIDE(BLACK,77), reducer returned no actions | session-core-phase6-ledger.md#evidence-log
2026-07-14 19:31 | RED | full seat corpus compiled; 20 missing-product observations across BUSY H/J/O TX cleanup | session-core-phase6-ledger.md#evidence-log
2026-07-14 19:40 | RED | parity link found duplicate mqtt protocol source entry; instrument fix only | session-core-phase6-ledger.md#evidence-log
2026-07-14 19:40 | FYI | seat retained-live block closed: 5 transcripts/31 steps plus DIRECT and guards green | session-core-phase6-ledger.md#block-1--mqtt-seat-acquire-retained-vs-live
2026-07-14 19:40 | RED | block 2 has 6 missing F/timeout observations; all stale filters already green | session-core-phase6-ledger.md#block-2--mqtt-bootstrap-presence-session-and-stale-traffic
2026-07-14 19:50 | FYI | bootstrap/presence/stale closed: 2 transcripts/24 steps, all host regressions green | session-core-phase6-ledger.md#block-2--mqtt-bootstrap-presence-session-and-stale-traffic
2026-07-14 19:50 | RED | block 3 has 10 missing START/TX/app-ACK observations; role and retained guards green | session-core-phase6-ledger.md#block-3--mqtt-side-readiness-and-start
2026-07-14 20:00 | RED | START focused link missing existing game_protocol_extra source; instrument-only build fix | session-core-phase6-ledger.md#evidence-log
2026-07-14 20:00 | FYI | side-ready-start closed: 4 transcripts/34 steps; app ACK separation and all guards green | session-core-phase6-ledger.md#block-3--mqtt-side-readiness-and-start
2026-07-14 20:00 | RED | block 4 has 20 missing MOVE/ACK/domain-result/TX observations; guards green | session-core-phase6-ledger.md#block-4--mqtt-moveack-and-tx-completion
2026-07-14 20:15 | RED | MOVE corpus extended: retry plus q/r/b/n red; 34 missing-product observations total | session-core-phase6-ledger.md#block-4--mqtt-moveack-and-tx-completion
2026-07-14 20:15 | FYI | MOVE/ACK block closed: 17 transcripts; retry, app-ACK gate, duplicates, promotions, regressions and guards green | session-core-phase6-ledger.md#block-4--mqtt-moveack-and-tx-completion
2026-07-14 20:30 | RED | block 5 compiles 28 transcripts; 81 missing CHAT/control/retry/domain/duplicate observations | session-core-phase6-ledger.md#block-5--mqtt-controls-and-duplicates
2026-07-14 20:35 | RED | TAKEBACK expiry extension adds requester retry/rearm; 83 missing-product observations total | session-core-phase6-ledger.md#block-5--mqtt-controls-and-duplicates
2026-07-14 20:45 | FYI | controls/duplicates closed: 28 transcripts; TAKEBACK expiry cleanup, crossed controls and regressions green | session-core-phase6-ledger.md#block-5--mqtt-controls-and-duplicates
2026-07-14 21:00 | RED | liveness corpus compiles 33 transcripts; 17 missing PING/ACK/deadline/TX-guard observations | session-core-phase6-ledger.md#block-6--mqtt-liveness
2026-07-14 21:25 | FYI | liveness closed: 33 transcripts; app-vs-broker PING, peer deadline, TX guard and regressions green | session-core-phase6-ledger.md#block-6--mqtt-liveness
2026-07-14 21:45 | RED | block 7 compiles 39 transcripts; link-loss/fresh-session paths green, 9 missing BYE staging/termination observations | session-core-phase6-ledger.md#block-7--mqtt-link-loss-bye-and-fresh-session
2026-07-14 21:55 | FYI | final block green: 40 transcripts; active loss forces full fresh game, BYE staging/guards green, regressions and module guards green | session-core-phase6-ledger.md#block-7--mqtt-link-loss-bye-and-fresh-session
2026-07-14 22:05 | CLOSE | Phase 6 formal gate green: 40 transcripts, one-send invariant, ABI/DIRECT/guards/purity/scope proven, zero target build/commit | session-core-phase6-ledger.md#formal-phase-6-closure

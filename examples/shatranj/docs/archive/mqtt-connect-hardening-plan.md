# MQTT Connect Hardening Plan

Current target: Spectrum MQTT connects deterministically, proves peer liveness
from live session traffic, and avoids warm-path shortcuts that were not reliable
on hardware.

## Current Flow

`spectrum_net_mqtt_start()` loads `MQTT_CONNECT` and runs:

1. Recover ESP command mode with `AT`.
2. Configure deterministic single-link mode:
   `ATE0`, `CWMODE`, `CWAUTOCONN`, `CIPSERVER=0`, `CIPCLOSE`, `CIPMUX=0`,
   `CIPMODE=0`.
3. Query IP with `AT+CIFSR`.
4. Optionally sync SNTP only if the clock is not already ready.
5. Open broker TCP with `AT+CIPSTART`.
6. Enter transparent mode with `CIPMODE=1` and `CIPSEND`.
7. Send MQTT CONNECT and wait CONNACK.
8. Subscribe to `meta`.
9. Subscribe to side topics after side is known.
10. Publish presence/setup metadata.

Timeout constants are failure ceilings, not normal path costs:

- `WAIT_FAST=50` frames, about 1s.
- `WAIT_SHORT=150` frames, about 3s.
- `WAIT_MED=500` frames, about 10s.
- `WAIT_RESET=700` frames, about 14s.
- `WAIT_LONG=2000` frames, about 40s.

## Accepted Diagnostics

`CONNECT_DIAG=1` builds compile in timing diagnostics. Normal builds compile
them out. Diagnostic summaries are emitted as persistent `D:` chat/log lines.

Stage names:

- `CMD`: command mode recovery / transparent escape / optional reset
- `CFG`: ESP command setup
- `IP`: local IP acquisition
- `NTP`: optional SNTP setup/query
- `TCP`: broker TCP open
- `STR`: transparent stream mode
- `ACK`: MQTT CONNECT to CONNACK
- `MET`: subscribe to `meta`
- `SID`: subscribe to side topics
- `PUB`: publish presence/setup
- `RDY`: MQTT transport ready
- `WAIT`: waiting for peer evidence
- `PEER`: first peer-live evidence

Final accepted hardware trace after rejecting the warm-IP shortcut:

```text
D: CMD0 CFG0 IP1
D: A0 WM0 AU0
D: SV0 CL0 MX0 MD1
D: NTP1 TCP2 STR2
D: ACK2 MET3 M0
D: SID3 S1 PUB3 PEER3
```

Real values vary. Stable connection around 3-5 seconds with WiFi already up and
PC peer ready is the target.

## Completed / Rejected

- Done: command-level `CFG` marks.
- Done: SUBACK must match the packet id of the SUBSCRIBE just sent.
- Done: deferred PUBLISH counters for `MET` and `SID`.
- Rejected: warm-IP shortcut. Hardware showed valid `CIFSR` did not imply clean
  TCP/transparent-mode state; `CIPSTART` still failed.

## Remaining Work

1. Keep peer-live semantics strict: retained `HOST` or `ONLINE` must not prove a
   live peer.
2. Make Spectrum MOVE handling idempotent by ply: ACK safe duplicates, NACK gaps
   or conflicts.
3. Defer SNTP from the critical path if gameplay does not need it.
4. Consider batching MQTT SUBSCRIBE packets only if packet size and SUBACK
   parsing remain small enough.

## Do Not Do

- Do not shrink `WAIT_LONG` as a primary speed fix.
- Do not accept retained MQTT presence as fresh liveness.
- Do not add large reconnect/session managers before measuring.
- Do not adopt external MQTT libraries without size, license, and API review.
- Do not reintroduce warm-IP skip without a stronger state probe and hardware
  proof.

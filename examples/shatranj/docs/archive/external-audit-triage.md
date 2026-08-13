# External Audit Triage

Working triage for external reports received after fresh artifacts were generated
on `main @ 53086d8`.

## Confirmed Fixes

### FIX-1 - esxDOS F_SEEK whence register

- Source: Gemini report; confirmed locally against esxDOS `F_SEEK` ABI.
- File: `asm/esxdos/overlay_loader.asm`
- Evidence:
  - `F_SEEK` uses `A=handle`, `BCDE=offset`, `L=whence`.
  - z88dk reference: `C:\z88dk\libsrc\target\zx\esxdos\z80\asm_esxdos_f_seek.asm`.
  - Current about seek sets `DE`, `BC`, `IX`, but not `L`.
  - Current overlay-block seek sets `DE`, `BC`, `A`, `IX`, but not `L`.
- Impact:
  - Random seek origin depending on stale `L`.
  - Can affect about-board DAT seek and OVL block seek.
- Minimal fix:
  - Add `ld l, 0` before each `rst 8 / defb 0x9f` seek call.
- Expected cost:
  - +4 resident bytes.
- Validation:
  - `make NO_COLOR=1 tap`
  - HW: open ABOUT, exercise multiple overlays (menu, hints, move apply, direct/mqtt path as available).

### FIX-2 - ABOUT can be overwritten by timer/clock redraw

- Source: Gemini report; later rejected as false positive.
- File: `src/spectrum/ui/gui.c`
- Evidence:
  - `spectrum_gui_tick()` updates and renders game timer / clock.
  - `spectrum_gui_show_about()` sets `about_visible = 1`.
  - `spectrum_gui_tick()` does not guard render calls with `about_visible`.
- Final decision:
  - Rejected as false positive after layout review/user confirmation.
  - ABOUT only covers the board area. Timer, clock, status, notice, and side
    panels are outside the ABOUT-covered board region.
  - `spectrum_gui_tick()` must keep rendering timer/clock while ABOUT is
    visible.
- Validation:
  - Do not add an `about_visible` guard around timer/clock/notice redraws.

### FIX-3 - taboption focus 4 has no ENTER action

- Source: Gemini report, confirmed locally.
- File: `src/spectrum/ui/gui.c`
- Evidence:
  - `MENU_OPTION_COUNT = 5`.
  - `spectrum_gui_poll_menu_key()` handles ENTER for focus 0..3 only.
  - focus 4 returns no action.
- Impact:
  - Last taboption item (THEME) can be focused but ENTER/SPACE does nothing.
- Decision:
  - Closed as intentional.
  - THEME is reserved for imminent theme work.
  - Do not remove, hide, or add behavior until the theme task is explicitly
    started.

## Confirmed Build/Guard Issues

### GUARD-1 - ABI baseline drift

- Source: Grok addendum, confirmed locally.
- Files:
  - `docs/abi_manifest.baseline.json`
  - `build/abi_manifest.json`
  - `build/SHATRANJ.map`
- Evidence:
  - `make NO_COLOR=1 abi-check size-check` fails `abi-check`.
  - Removed baseline symbols:
    - `_direct_tx_payload`
    - `_direct_rx_queue`
  - Symbols remain in baseline but not current map.
- Impact:
  - Current code is self-consistent, but ABI baseline is stale.
  - Future ABI checks fail until baseline is deliberately refreshed.
- Fix:
  - `docs/abi_manifest.baseline.json` refreshed deliberately from the current
    generated manifest after accepting that these resident symbols are removed.
- Validation:
  - `make NO_COLOR=1 abi-check`
  - `make NO_COLOR=1 module-guards`

### GUARD-2 - stack gap hard floor

- Source: Claude/Grok reports, accepted as useful.
- Current size:
  - stack guard gap: 1722 bytes
  - SP gap: 2066 bytes
- Minimal fix:
  - Add hard failure when stack guard gap drops below 1024 bytes.
- Impact:
  - Build/CI hardening only; no binary behavior change.

### GUARD-3 - Dropbox conflict copies in generated build output

- Source: Claude report, confirmed locally.
- Files:
  - `build/*(Copia en conflicto de DESKTOP-Q209LIE 2026-06-11)*`
  - `build/*(Copia en conflicto de DESKTOP-Q209LIE 2026-06-12)*`
- Evidence:
  - Conflict copies exist for `.DAT`, `.tap`, `.map`, `.bin`, `overlay_defs.asm`,
    `overlay_sizes.json`, and `size_report.json`.
- Impact:
  - External auditors can accidentally inspect stale generated artifacts.
  - Normal build names are still unambiguous, but the directory is noisy.
- Minimal fix:
  - Delete only the conflict-copy files after explicit approval.
- Validation:
  - `Get-ChildItem build -Recurse -File | Where-Object { $_.Name -like '*Copia en conflicto*' }`
    should return nothing.

## Reviewed Policy Decisions

### REVIEW-1 - fast reconnect during active game

- Source: Gemini report; rejected as stale/unsupported for current policy.
- Evidence:
  - `MQTT_PEER_READY` while `game_status_active` sends `BYE` and reports "Game already active".
- Risk:
  - A legitimate reconnect before LWT/offline may be rejected.
- Decision:
  - Do not change reconnect semantics now.
  - Existing active-game peer-ready rejection remains in place.

### REVIEW-2 - simultaneous RESET requests

- Source: Gemini report.
- Evidence:
  - Before the fix, incoming `RESET` while `reset_pending` or already confirming
    reset sent `NACK RESET`.
  - Docs say only host resets; UI currently allows REST during active game for both roles.
- Risk:
  - Symmetric resets do not reset, but this may be acceptable policy.
- Decision:
  - If a local reset is pending and peer also sends `RESET`, both sides want the
    same reset; accept it, clear the pending state, restore once, and send
    `ACK RESET`.

### REVIEW-3 - incoming peer RESET before game start

- Source: Claude report.
- Evidence:
  - Commit `53086d8` blocks local REST before game start.
  - Before the fix, incoming peer `RESET` before `GAME START` was accepted as an idempotent
    state restore/no-op.
- Risk:
  - Not a crash; it is a product/protocol decision.
- Decision:
  - Peer `RESET` before active game is invalid; answer `NACK RESET`.

## Rejected / Not Actionable

- Gemini: long chat session drop.
  - Rejected.
  - `LOCAL_INPUT_MAX = SPECTRUM_LINK_PAYLOAD_MAX - 6`; `"CHAT "` + text + NUL fits.
- Gemini: residual `_append_u16` resident.
  - Rejected as stale.
  - Spectrum build uses `-DNETCHESSZX_PROTOCOL_BUILDERS=0`.
  - Current map contains only `_spectrum_append_u16`.
- Grok: no new bugs.
  - Not accepted as complete; it missed `F_SEEK` and taboption focus 4.
- Runtime OVL checksum/CRC.
  - Robustness-only; costs resident bytes and format churn.
- Fatal loop `jr` -> `halt`.
  - Rejected; `halt` under DI can resume on NMI unless followed by loop.
- Generic Z80 tricks without local byte proof.
  - Rejected.
- Claude: `DEVROOM` literal dedup in `app.c`.
  - Rejected as stale for current tree.
  - No `DEVROOM` literal found in `src/`.
- Removing apparently dead `jr c, ovl_fail` in overlay dispatch.
  - Rejected.
  - Defensive guard against manipulated/corrupt OVL entry data is worth 2 bytes.
- `ACK PING` lax match.
  - Low-value parser polish, not a bug.
  - Tightened so `"ACK PING"` without sequence is no longer classified as
    `ACK_PING`.
- `wait_after_notice()` does not drain UART during notice wait.
  - Cosmetic/robustness-only; framer can resync.
  - Do not change without product need.

## Shrink Candidates To Measure

### SHRINK-1 - ESP AT parser `strstr` removal

- Source: Codex own audit.
- File: `src/spectrum/transport/esp_at.c`
- Evidence:
  - `capture_ip_from_line()` and `capture_time_from_line()` use `strstr`.
  - Current map includes string helper code for `strstr`.
- Result:
  - Rejected after measurement.
  - Full local replacement of `strstr`/`strchr`/`strcmp` in `esp_at.c` grew
    resident size by 131 bytes (`34400 -> 34531`), then was reverted.
- Risk:
  - Low if tests cover IP/time parser cases.
- Validation:
  - Add/run nearest ESP-AT host tests.
  - `make NO_COLOR=1 tap`
  - compare `build/SHATRANJ.map` and `build/size_report.json`.

### SHRINK-2 - `BYE` literal dedup inside `app.c`

- Source: Claude report, confirmed locally.
- File: `src/spectrum/app/app.c`
- Evidence:
  - `"BYE"` appears at local disconnect confirm and active-game peer-ready reject.
- Idea:
  - Use one `static const char msg_bye[] = "BYE";`.
- Expected impact:
  - About 4 resident bytes.
- Risk:
  - Very low; no behavior change.
- Validation:
  - `make NO_COLOR=1 tap`
  - compare size report.

### SHRINK-3 - key-repeat suppress helper

- Source: Claude report, confirmed locally.
- File: `src/spectrum/app/app.c`
- Evidence:
  - `poll_repeating_key()` and `poll_menu_repeating_key()` share the same
    suppression tail shape.
- Result:
  - Applied as `filter_repeating_key()`.
  - Measured net win: 3 resident bytes (`34400 -> 34397`).
- Risk:
  - Low but requires build measurement; helper call overhead can erase the gain.
- Validation:
  - `make NO_COLOR=1 tap`
  - HW: setup menu key repeat, game/input key repeat, ABOUT close key.

### SHRINK-4 - protocol token consolidation

- Source: Claude report.
- Files:
  - `src/common/protocol/messages.c`
  - `src/common/protocol/outgoing.c`
  - Spectrum session/app users.
- Idea:
  - Consolidate duplicated protocol text tokens such as ACK/NACK reset/start
    forms where layering permits.
- Expected impact:
  - Estimate 50-70 resident bytes only if linker/string layout cooperates.
- Risk:
  - Medium; common/spectrum layering can turn this negative.
- Validation:
  - `make NO_COLOR=1 module-guards`
  - `make NO_COLOR=1 tap`
  - protocol/session host tests.

## Audit Quality Notes

- Codex own audit missed confirmed bug `FIX-1` and the intentional taboption
  policy check `FIX-3`.
  Treat it as partial coverage only.
- Grok second report also missed `FIX-1` and `FIX-3`, but added useful
  confirmation of ABI baseline drift.
- Gemini found `FIX-1`; its ABOUT/timer item was a false positive.
- Claude latest report also missed `FIX-1`; it did confirm `FIX-3`
  and added useful cleanup/product/shrink notes.

## Pending External Reports

- None.

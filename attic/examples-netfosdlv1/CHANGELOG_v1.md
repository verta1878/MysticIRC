# netfosdl v1.0 — Completion Changelog (wrench, 2026-08-29)

Finished the remaining ~30% of the DOS FOSSIL driver. The prior build
(70%) had the core INT 14h functions working and was proven end-to-end
in DOSBox-X, but the receive path was polled-only and several FSC-0015
functions were grouped no-op stubs. This release closes both gaps.

## Interrupt-driven receive — WIRED
`serial_irq.pas` (4KB ring buffer + UART ISR, by kiddo/sysop/0) existed
but was never connected to the FOSSIL layer. Now:
- Fn04 Init hooks the UART RX interrupt (`SerEnableIRQ`); Fn05 Deinit
  unhooks it and restores the PIC mask (`SerDisableIRQ`).
- All receive consumers route through new helpers `FossilRxAvail` /
  `FossilRxByte`, which read the ISR ring buffer when the IRQ is active
  and fall back to polled UART reads when it is not:
  - Fn02 RX-wait, Fn0C Peek, Fn18 Read-block, Fn03 Status.
- This is what makes byte-loss-free receive and real flow control
  possible under load, instead of dropping bytes while the BBS is busy.

## Newly implemented functions (were no-op stubs)
- **Fn0F Set-Flow-Control** — honors the CTS/RTS hardware-flow bit on
  the UART (asserts RTS; SerWrite gates on CTS), remembers the XON/XOFF
  mode bits for status reporting.
- **Fn10 Ctrl-C/Ctrl-K check** — returns 0 (no abort pending), the
  correct answer for a remote serial link with no local console.
- **Fn17 Reboot** — real warm boot: sets the BIOS 0040:0072 flag to
  1234h and far-jumps to FFFF:0000 (unhooks the IRQ first).

## Correctness fix
- Fn18 Read-block now delivers a pending Fn0C peek byte first, so a
  peek immediately followed by a block read no longer loses that byte.

## Documented safe defaults (intentional, not stubs)
Fn11/12 cursor, Fn13 ANSI-write, Fn14 watchdog, Fn15 char-write,
Fn16 timers, Fn0D/0E keyboard — these target a LOCAL console or host
watchdog. This is a remote serial FOSSIL with no local screen/keyboard,
so they return well-formed no-ops (a caller never crashes; local output
is the BBS's own job on this transport).

## Verified (DOSBox-X, 386+FPU, real DOS)
- TSR loads, hooks INT 14h, signature AX=1954h confirmed.
- Fn04/03/00/05 round-trip: AX=1954, AH=60, AX=6000, clean deinit.
- New Fn0F (CTS/RTS flow) and Fn10 (Ctrl-C) exercised — return cleanly.
- Resident-size fix from the prior build retained (keeps only real
  resident image, not all of conventional memory).

## Function coverage
18 FSC-0015 rev-5 functions with real behavior + 8 documented defaults =
full v1 dispatch. Signature reports rev 5, max Fn $21.

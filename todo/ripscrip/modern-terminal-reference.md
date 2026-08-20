# Modern Terminal Baseline: SyncTERM and icy_term

[◀ Prev: ANSI-BBS / VT-x Emulation in RIPterm and RIPtel](ansi-vt-support.md) · [Contents](README.md) · [Next: Contents ▶](README.md)

What a _modern_ BBS terminal implements on the text side, using SyncTERM (C, `~/src/rip-tools/sbbs/`) and icy_term (Rust, `~/src/rip-tools/icy_tools/`) as reference points. **Everything here is a MODERN capability description** - what users of a RIP-capable terminal will expect in 2026, never evidence of what the historical products did; for most of the features below, the RIPterm/RIPtel materials contain no evidence at all.

## SyncTERM / cterm

SyncTERM's terminal core (cterm) has its own maintained sequence manual, `sbbs:src/conio/cterm.adoc` - the modern analogue of RIPterm 1.54's Appendix B, and the best single reference for the modern ANSI-BBS dialect. Highlights:

- **Emulation modes**: ANSI-BBS plus retro-platform emulations - `CTERM_EMULATION_ANSI_BBS`, `PETASCII`, `ATASCII`, `PRESTEL`, `BEEB` (BBC Mode 7 teletext), `ATARIST_VT52` (`sbbs:src/conio/cterm.h`, `cterm_emulation_t`). Screen modes cover C64/C128, Atari, Atari ST, Prestel, and classic 80×25 through 132×60 grids (`sbbs:src/syncterm/bbslist.c`, screen-mode list). RIP is layered on top by `sbbs:src/syncterm/ripper.c` (~19k lines, claims RIP 3.0 compatibility).
- **"ANSI" music**: `CSI M` / `CSI N` / `CSI |` music strings (IBM BASIC `PLAY` subset), gated by the `CSI = Ps M` CTerm Set ANSI Music extension (0 = only `CSI |`, 1 = `+ CSI N`, 2 = `+ CSI M`, sacrificing Delete Line) - `sbbs:src/conio/cterm.adoc` ("ANSI" Music section and `CTSAM`); dispatch table in `sbbs:src/conio/cterm.c` (`cterm_handle_ansi_music` and friends). cterm.adoc's own history note attributes the invention of ANSI music to **TeleMate or QModem** - BBS _terminal_ vendors contemporary with, but distinct from, TeleGrafix.
- **Sixel graphics**: `DCS [p1[;p2]] q … ST` sixel sequences, plus sixel display/scrolling modes (`DECSET/DECRST 80`) and pixel-operation capability reporting ("currently, sixel and PPM graphics") - `sbbs:src/conio/cterm.adoc` (Sixel Sequence section).
- **DoorWay mode**: `CSI = 255 h` / `CSI = 255 l` with `NUL` + scancode keyboard encoding - `sbbs:src/conio/cterm.adoc` (`BCSET`/`BCRST`), input side in `sbbs:src/syncterm/term.c` and `sbbs:src/conio/cterm.c`. This is the same DOORWAY interface RIPterm 1.53+ implemented.
- **Extended color**: SGR `38;5`/`48;5` indexed color against the xterm 256-color palette, SGR `38;2`/`48;2` direct RGB, and the non-standard `CSI Ps;Pn1;Pn2;Pn3 t` 24-bit color selection - `sbbs:src/conio/cterm.adoc` (SGR and `CT24BC` sections).
- **xterm-lineage extensions**: X10/normal/button/any-event mouse reporting incl. SGR 1006-style and pixel-position (`DECSET 1016`) encodings, focus events, bracketed paste (`DECSET 2004`), OSC 8 hyperlinks - `sbbs:src/conio/cterm.adoc` (DECSET mode tables, OSC section).
- **Loadable fonts**: `CSI Ps1 ; Ps2 SP D` font selection over a large built-in set (CP437 variants, Amiga/Atari/C64 fonts, many national code pages) and `DCS CTerm:Font:p1:<b64> ST` for host-supplied fonts - `sbbs:src/conio/cterm.adoc` (FNT and CTLF sections).
- **Audio beyond the BEL**: audio availability/format query-reports (`CSI = 7 … n`, libsndfile/OGG-Opus feature probes) - `sbbs:src/conio/cterm.adoc`.
- **UTF-8**: modern builds negotiate/display UTF-8 alongside CP437 handling (see `sbbs:src/syncterm/` generally); classic ANSI-BBS content remains CP437.

## icy_term

icy_term is built on the `icy_engine`/`icy_parser_core` crates, which implement each emulation as a separate parser:

- **Emulations selectable per dialing-directory entry** (11 total): ANSI, UTF8-ANSI, Avatar, ASCII, RIP, PETSCII, ATASCII, Atari ST (VT-52), Skypix, ViewData, and BBC Mode 7 - `icy_tools:crates/icy_term/src/data/addresses.rs` (`ALL_TERMINALS`). Parser sources: `icy_tools:crates/icy_parser_core/src/` (`ansi/`, `avatar.rs`, `rip/`, `petscii.rs`, `atascii.rs`, `vt52.rs`, `viewdata.rs`, `mode7.rs`, `skypix/`, `igs/`, plus BBS @-code display parsers `pcboard.rs`, `ctrla.rs`, `renegade.rs`).
- **"ANSI" music**: implemented in the ANSI parser (`icy_tools:crates/icy_parser_core/src/ansi/music.rs`) with a per-BBS `MusicOption` of `Off` (default) / `Conflicting` (`CSI M`) / `Banana` (`CSI N`) / `Both` - stored per address (`icy_tools:crates/icy_term/src/data/addresses.rs`, `ansi_music` field).
- **Sixel**: the ANSI parser recognizes `ESC P … q … ESC \` and hands off sixel data (`icy_tools:crates/icy_parser_core/src/ansi/mod.rs`, Sixel branch); rendering in `icy_tools:crates/icy_engine/src/sixel_mod.rs`.
- **RIP**: dedicated parser (`icy_tools:crates/icy_parser_core/src/rip/`) targeting RIPscrip 1.54, with the classic auto-sense reply baked in (see below).
- **UTF-8 ANSI**: a first-class emulation variant (`Utf8Ansi`), reflecting modern telnet/ssh hosts; classic ANSI remains CP437-mapped.

## Feature matrix: modern capability vs historical evidence

The right-hand column is the load-bearing one: it states what the TeleGrafix materials (RIPterm 1.54/2.0/2.30 manuals, WHATSNEW/README docs, RIPtel 3.1 help files, and `strings` over every shipped executable listed on the [previous page](ansi-vt-support.md)) actually contain.

| Feature | SyncTERM | icy_term | Evidence in RIPterm/RIPtel materials |
| --- | --- | --- | --- |
| ANSI-BBS text emulation (SGR 16-color, cursor addressing, ED/EL, DSR/CPR) | Yes | Yes | **Yes** - documented sequence-by-sequence in RIPterm 1.54 `RIPTERM.DOC` Appendix B; ANSI Emulation toggle in 2.x; ANSI setting in RIPtel |
| VT-102 additions (ICH/DCH/IL/DL/CBT, G0/G1 charsets, scroll region) | Yes (part of ANSI-BBS core) | Yes (ANSI parser) | **Yes** - VT-102 mode since RIPterm 1.51 (`WHATSNEW.DOC`); sequences in 1.54 Appendix B |
| DoorWay mode (`CSI = 255 h/l`, NUL+scancode keys) | Yes | No evidence found in icy_term sources | **Yes** - complete implementation since RIPterm 1.53 (`WHATSNEW.DOC`, 1.54 `RIPTERM.DOC` "DOORWAY MODE" + Appendix B); `$DWAYON$`/`$DWAYOFF$` in RIPtel help |
| "ANSI" music (`CSI M` / `CSI N` / `CSI \|`) | Yes (with `CSI = Ps M` gating) | Yes (per-address option, default Off) | **None.** No RIPterm or RIPtel document or binary examined mentions ANSI music: zero matches for "ansi music" in any manual, and the only "music" strings are RIPscrip's `$MUSIC$` canned local sound effect (1.54 `RIPTERM.DOC` text-variable list: "Makes a musical (cheerful) sound") and local UI "musical sounds" (2.30 `RIPTERM.DOC` alarm-sounds option). RIP-era audio was RIPscrip-level (tones, WAV playback in 2.x), not an ANSI escape extension |
| Sixel graphics (`DCS … q`) | Yes | Yes | **None.** Zero matches for "sixel" across all RIPterm 1.54/2.0/2.30 manuals and `strings` of `RIPTERM.EXE` (all three), `RIPTEL.EXE`, `RIPTEL.HLP`, `MESSAGES.HLP`. Raster graphics in the RIP world were RIPscrip commands (icons, `.BMP`/JPEG display), never sixel |
| 256-color / 24-bit SGR (`38;5`, `38;2`, `CSI … t`) | Yes | Yes | **None at the ANSI layer.** 1.54 Appendix B documents only classic attribute SGR. RIPterm 2.x's 256-color/direct-RGB support is RIPscrip-command-level (SVGA palette commands - see [2.x techspecs](../../2.0/techspecs/README.md)), not an SGR extension |
| xterm mouse reporting (X10/1000/1002/1003/1006/1016) | Yes | (ANSI parser scope; not verified feature-by-feature) | **None.** Mouse support in RIPterm/RIPtel is RIPscrip-protocol-level (mouse fields/buttons transmitting host command strings), not CSI mouse-event reporting; 1.54 Appendix B lists no mouse DECSET modes |
| Bracketed paste (`DECSET 2004`) | Yes | - | **None** - no mention in any TeleGrafix material examined |
| OSC 8 hyperlinks | Yes | - | **None** - no mention in any TeleGrafix material examined |
| Host-loadable text fonts (`DCS CTerm:Font…`, `CSI Ps1;Ps2 SP D`) | Yes | Font handling via engine | **None at the ANSI layer.** RIPterm's text-window fonts are its own MicroANSI containers selected via RIPscrip/system settings, not via escape sequences |
| UTF-8 text | Yes | Yes (`Utf8Ansi`) | **None.** DOS/Win16-era products; the 2.x manuals explicitly state translation tables / international character support were _not yet implemented_ (`RIPTerm2.0/extracted/RIPTERM.DOC` §4.5) |
| Retro emulations (PETSCII, ATASCII, ViewData, Mode 7, VT-52, Skypix, IGS, Avatar) | PETSCII/ATASCII/Prestel/Mode 7/Atari ST VT-52 | All listed | **None.** RIPterm/RIPtel documents describe exactly two text emulations: ANSI and VT-102 |
| Audio capability queries (`CSI = 7 … n`) | Yes | - | **None.** RIPterm 2.x WAV/sound playback is driven by RIPscrip commands and text variables, not by ANSI queries |

## How the modern terminals handle the RIP auto-sense

- SyncTERM answers `CSI !`/`CSI 0 !` with `RIPSCRIP015410` (RIP1 mode) or `RIPSCRIP030001` (RIP3 mode) - `sbbs:src/syncterm/ripper.c` (`ripver[]` table). Note the RIP3 reply advertises vendor `0` (generic), unlike RIPtel.
- icy_term answers with the RIPterm 1.54 identity string `RIPSCRIP015410` - `icy_tools:crates/icy_engine/src/palette_screen_buffer/rip_impl.rs` (`RIP_TERMINAL_ID`).
- qodem (no RIP support) demonstrates the non-RIP side of the contract: it recognizes the query and silently discards it rather than letting it print - `qodem:source/ansi.c` ("This is a RIPScript query command, discard it").

## Guidance for implementers

- The historical text baseline a RIPscrip host could assume is exactly the [1.54 Appendix B sequence set plus VT-102 mode](ansi-vt-support.md) - nothing more. A faithful "RIPterm-class" text window needs no music, sixel, mouse reporting, or extended color.
- A modern RIP-capable terminal, however, will be judged against the SyncTERM/cterm baseline (`sbbs:src/conio/cterm.adoc`), where ANSI music, sixel, 256/24-bit color, mouse reporting, and DoorWay mode are all table stakes for BBS use. Implementing the modern set does not conflict with RIPscrip - these extensions live in CSI/DCS space RIPscrip never used (RIPscrip's only ANSI-layer footprint is the `CSI … !` family).
- When emulating the _historical_ products for fidelity (e.g., rendering archived sessions), disable the modern extensions: a real RIPterm would have printed a sixel or music payload into the text window as garbage, and faithful replay should too.

---

[◀ Prev: ANSI-BBS / VT-x Emulation in RIPterm and RIPtel](ansi-vt-support.md) · [Contents](README.md) · [Next: Contents ▶](README.md)

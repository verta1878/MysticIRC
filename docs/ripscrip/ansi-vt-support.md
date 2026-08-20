# ANSI-BBS / VT-x Emulation in RIPterm and RIPtel

[◀ Prev: Contents](README.md) · [Contents](README.md) · [Next: Modern Terminal Baseline: SyncTERM and icy_term ▶](modern-terminal-reference.md)

The ANSI/VT-x text-terminal emulation that TeleGrafix's own RIPscrip clients actually shipped: RIPterm 1.54, RIPterm 2.x and RIPtel 3.1. **RIPterm 2.30 - the last 2.x release - is treated throughout as the definitive 2.x reference**; the recovered 2.0 and 2.30 installs document the same emulation feature set, so sub-version distinctions within 2.x are noted only where something actually differed. Every claim is cited to a TeleGrafix document, a specification section, or direct binary evidence from a shipped executable.

## The two-window model: where ANSI text goes

RIPscrip's design assumption is that the byte stream is a _mixture_ of RIPscrip commands and ordinary ANSI/ASCII text, disambiguated per line:

- A line beginning with `!|` in column 1 is a RIPscrip command line; "A line that does not begin with `!|` is considered raw text and is routed to the TTY text window" - [RIPscrip 1.54 spec, "HOW DOES RIPscrip WORK?" items 6-7](../../1.54/text/RIPScrip-1.54.txt).
- "The Text Window is where raw text appears. Raw Text includes ANSI color and cursor movement codes (**a subset of VT-100 terminal emulation**)" - same section. This is TeleGrafix's own characterization of the baseline: ANSI-BBS color/cursor handling described as a VT-100 subset.
- `RIP_TEXT_WINDOW` defines "the virtual TTY window that will display all ASCII/ANSI (non-RIPscrip) data coming across the modem"; the window can also be made invisible, discarding non-RIPscrip data - [1.54 spec, RIP_TEXT_WINDOW](../../1.54/text/RIPScrip-1.54.txt). `RIP_RESET_WINDOWS` resets to "a full 80x43 EGA hi-res text mode" screen.
- The RIPscrip 3.x whitepaper keeps the same model: "TTY and ANSI information will appear only in text windows … much like a normal MS-DOS screen", with up to 36 text windows defined and one active at a time - [3.x whitepaper, "Text Windows"](../../3.0/text/RIPScrip-3.x-technical-whitepaper.txt).

So the "terminal emulation" documented below always operates _inside_ the currently active text window, not on the full screen, whenever RIPscrip graphics mode is active.

## Emulation modes by product

| Product | Emulation modes documented | Source |
| --- | --- | --- |
| RIPterm 1.54 (DOS) | ANSI text handling always on (no separate toggle); **VT-102 Emulation** on/off; **Doorway** mode; RIPscrip processing on/off (host-controlled via `ESC[1!`/`ESC[2!`) | `~/src/rip-tools/RIPterm154/DOS/RIPTERM/RIPTERM.DOC` - Options list ("VT-102 Emulation … utilize VT-102 extensions of ANSI text graphics"), "VT-102 MODE", "DOORWAY MODE" sections, Appendix B |
| RIPterm 2.x (DOS; 2.30 final) | Four independent Options-menu toggles: **ANSI Emulation** (Ctrl-Alt-A), **RIPscrip Emulation** (Ctrl-Alt-Z), **Doorway Emulation** (Alt-=), **VT-102 Emulation** | `~/src/rip-tools/artifacts/ripterm-2.30/extracted/RIPTERM.DOC` §3.4 Options Menu (emulation entries quoted below; identical in the 2.0 manual) |
| RIPtel 3.1 (Win16) | Per-Setup / per-Bookmark **Terminal Emulation: ANSI or VT-102** ("Full VT-102 and ANSI terminal emulation built-in!"); Doorway mode via `$DWAYON$`/`$DWAYOFF$` | `strings` on `~/src/rip-tools/artifacts/RIPtel/MESSAGES.HLP` and `RIPTEL.HLP` (Terminal Emulation help topics); [RIPtel help research](../../3.0/research/riptel-help-extraction.md) |

Notes on the individual modes:

- **ANSI** - In 1.54 ANSI interpretation is simply how the text window works; there is no user toggle for it in the documented options list. 2.0 makes it a toggle: "To make RIPterm ignore any ANSI commands, you can de-select ANSI Emulation. Any ANSI commands received will appear in the text window" (`RIPTerm2.0/extracted/RIPTERM.DOC` §3.4). The dialing directory stores a per-host "Terminal Emulation (ANSI or VT-102)" field from 2.0 on (same manual, dialing-directory field list).
- **VT-102** - A _modifier_ on top of ANSI, not a separate parser: "many ANSI escape sequences function slightly differently than in normal ANSI mode. When in this mode, RIPterm tries to act like a VT-102 compatible terminal" (1.54 `RIPTERM.DOC`, "VT-102 MODE"). It also remaps the keyboard (see below). The 2.0 manual adds: "TeleGrafix worked closely with Digital Equipment Corp. (DEC) to develop and test RIPterm's VT-102 emulation. It adheres to the true VT-102 specification" (`RIPTerm2.0/extracted/RIPTERM.DOC` §3.4). VT-102 operation first appeared in RIPterm 1.51: "RIPterm now adheres to ANSI SCO/UNIX VT-102 compatibility … In VT-102 mode, backspaces are now non-destructive … Supports VT-102 character sets G0 and G1 (US, UK or Special Sets)" (`~/src/rip-tools/RIPterm154/DOS/RIPTERM/WHATSNEW.DOC`, "Version 1.51.00 … Released 03/29/93").
- **Doorway** - A keyboard/printer passthrough mode implementing Marshall Dudley's DOORWAY interface, "a complete implementation of the Doorway interface … Printer Re-direction … Special Character Overiding for non-printable ASCII characters" (1.54 `RIPTERM.DOC`, "DOORWAY MODE"). Keystrokes are sent as raw BIOS scancodes: extended keys go out as `NUL` + scancode (or `NUL`, `0xE0`, scancode for enhanced 101-key codes) - the "PROGRAMMER'S NOTE" in the same section spells out the exact encoding. Doorway is remotely controllable via `ESC[=255h` / `ESC[=255l` and the `$DWAYON$`/`$DWAYOFF$` text variables (1.54 `RIPTERM.DOC` Appendix B and text-variable list). Full Doorway support (printer redirection, `ESC[Pn;LnP` string printing) was added in 1.53 (`WHATSNEW.DOC`, "Version 1.53.00").
- **RIPscrip** - RIPscrip processing itself is toggleable: locally in 2.0+ (Ctrl-Alt-Z), and remotely in all versions via `ESC[1!` (disable) / `ESC[2!` (enable) - [1.54 spec, "ANSI SEQUENCES (AUTO-SENSING)"](../../1.54/text/RIPScrip-1.54.txt). When disabled, RIPscrip sequences display as raw text in the text window.
- **Keystroke macro emulation sets (2.x)** - RIPterm 2.0 ships `ANSI.MAC` and `VT100.MAC` keystroke-macro files, and the macro file format has `TYPE=EMULATION RIPSCRIP`, `TYPE=EMULATION ANSI`, and `TYPE=EMULATION VT-100` types, loaded automatically per the current terminal-emulation setting (`~/src/rip-tools/RIPTerm2.0/extracted/ANSI.MAC` header comments; `RIPTERM.DOC` §5.3 Keystroke Macro Editor: "RIPterm supports two Terminal Emulation Macro sets: VT-102 and ANSI"). The same `ANSI.MAC`/`VT100.MAC` pair ships with 2.30 (`~/src/rip-tools/artifacts/ripterm-2.30/extracted/`). The macro-type keyword calls the set "VT-100" while the UI toggle is "VT-102" - TeleGrafix used the terms loosely.

## The documented ESC/CSI sequence set (RIPterm 1.54, Appendix B)

RIPterm 1.54's manual is the only TeleGrafix document that enumerates the honored sequences: "All ANSI sequences supported by RIPterm are now documented in Appendix B of the RIPTERM.DOC file" was itself a 1.54 change (`WHATSNEW.DOC`, "Version 1.54.00"). The complete Appendix B ("Supported ANSI Sequences", `~/src/rip-tools/RIPterm154/DOS/RIPTERM/RIPTERM.DOC`) is reproduced here as a table:

| Sequence | Function |
| --- | --- |
| `ESC [ !` | Auto-sense RIPscrip terminal |
| `ESC [ 0 !` | Auto-sense RIPscrip terminal |
| `ESC [ 1 !` | Disable RIPscrip processing |
| `ESC [ 2 !` | Enable RIPscrip processing |
| `ESC [ Pn @` | Insert Pn spaces at cursor position |
| `ESC [ Pn P` | Delete Pn characters at cursor position |
| `ESC [ Pn ; Ln P` | Doorway mode - print Ln chars to LPT (Pn) (LPT number is ignored) |
| `ESC [ Pn L` | Insert Pn lines at cursor position |
| `ESC [ Pn M` | Delete Pn lines at cursor position |
| `ESC [ Pn A` | Cursor up Pn lines (no scrolling) |
| `ESC [ Pn B` | Cursor down Pn lines (no scrolling) |
| `ESC [ Pn D` | Cursor left Pn columns (no wrapping) |
| `ESC [ Pn C` | Cursor right Pn columns (no wrapping) |
| `ESC [ Pn Z` | Backtab Pn times |
| `ESC [ An ; Fn ; Bn m` | Display attributes (SGR) |
| `ESC [ J` / `ESC [ 0 J` | Clear from cursor to lower-right of screen |
| `ESC [ 1 J` | Clear from cursor to upper-left of screen |
| `ESC [ 2 J` | Clear entire screen and home cursor |
| `ESC [ K` / `ESC [ 0 K` | Clear to end of line |
| `ESC [ 1 K` | Clear from beginning of line to cursor |
| `ESC [ 2 K` | Clear entire line, cursor unchanged |
| `ESC [ g` / `ESC [ 0 g` | Clear tab stop at current column |
| `ESC [ 3 g` | Clear all tab stops |
| `ESC [ Py ; Px H` | Move cursor to (Px,Py) |
| `ESC [ Py ; Px f` | Move cursor to (Px,Py) |
| `ESC [ s` | Save cursor position |
| `ESC [ u` | Restore saved cursor position |
| `ESC [ 5 n` | Device status report - returns `ESC [ 0 n` |
| `ESC [ 6 n` | Cursor position report - returns `ESC [ y ; x R` |
| `ESC [ c` | Device attribute report |
| `ESC [ Pl ; Pn r` | Set scrolling region between lines Pl-Pn |
| `ESC [ S` | Scroll screen up one line |
| `ESC [ ? 6 l` | Set home position to upper-left of screen |
| `ESC [ ? 7 l` | Line wrapping off |
| `ESC [ ? 7 h` | Line wrapping on |
| `ESC [ ? 15 n` | Printer status report - reports NO printer |
| `ESC 7` / `ESC 8` | Save / restore cursor position |
| `ESC c` | Reset terminal emulation to initial state |
| `ESC Z` | Same as `ESC [ c` |
| `ESC D` | Cursor down (scroll if at bottom) |
| `ESC E` | Cursor to next line, column 1, with scroll |
| `ESC M` | Cursor up (scroll if at top) |
| `ESC H` | Set tab stop at current column |
| `ESC ( A` / `ESC ( B` / `ESC ( 0` | Select UK / US / line-drawing character set as G0 |
| `ESC ) A` / `ESC ) B` / `ESC ) 0` | Select UK / US / line-drawing character set as G1 |
| `ESC [ = 255 h` | Enter Doorway mode |
| `ESC [ = 255 l` | Exit Doorway mode |

Provenance of individual entries, from `WHATSNEW.DOC`:

- `ESC[<n>@`, `ESC[<n>P`, `ESC[<n>L`, `ESC[<n>M`, `ESC[<n>Z` were added in 1.51 as "several VT-102 commands" ("Version 1.51.00" section).
- The G0/G1 character-set selection and non-destructive VT-102 backspace also date to 1.51; a 1.54 fix made G0/G1 reset on manual screen clear ("Version 1.54.00" section).
- The Doorway sequences (`ESC[=255h/l`, `ESC[Pn;LnP`) were completed in 1.53 ("Added enhanced Doorway (tm) support … the ANSI sequences to enable/disable Doorway mode are supported along with the ANSI sequences to print strings").

**The 2.0 and 2.30 manuals do not reproduce this appendix** (their appendices are troubleshooting, keyboard shortcuts, and support - verified against both `RIPTERM.DOC` files), and no TeleGrafix 2.x/3.x document examined publishes a revised sequence list. The 2.20.00/2.20.01/2.30 change logs (`~/src/rip-tools/artifacts/ripterm-2.30/extracted/README.DOC` §3) record **no additions or removals to the ANSI/VT sequence set** - so the 1.54 Appendix B is the last known authoritative TeleGrafix statement of the honored sequences, with no evidence of change through 2.30.

## VT-102 keyboard mode

Enabling VT-102 emulation remaps the keyboard (identical tables in 1.54 `RIPTERM.DOC` "VT-102 MODE" and `WHATSNEW.DOC` "Version 1.51.00"): F1-F10 send `ESC [ M` through `ESC [ V`, PgUp/PgDn send `ESC [ I` / `ESC [ G`, Home/End send `ESC [ H` / `ESC [ F`, Insert sends `ESC [ L`, and the cursor keys send `ESC [ A` / `ESC [ B` / `ESC [ C` / `ESC [ D`. (These are RIPterm's own non-DEC codes - TeleGrafix's "VT-102" keyboard is IBM-PC-flavored, not a literal DEC keymap.) In 2.x the VT-102 keyboard lives in the editable `VT100.MAC` macro file instead of being hardcoded (`RIPTerm2.0/extracted/RIPTERM.DOC` §3.4: "look at the file VT102.MAC in the RIPterm directory" - the shipped file is actually named `VT100.MAC`). RIPtel 3.1 keeps the ANSI-vs-VT-102 distinction for the backspace key: "the backspace character is what's transmitted … Under VT-102 environments though, the delete character is expected" (`strings` on `~/src/rip-tools/artifacts/RIPtel/MESSAGES.HLP`), matching the 2.x dialing-directory "Backspace Sends DEL (BS or DL)" per-host option (`RIPTerm2.0/extracted/RIPTERM.DOC`, dialing-directory field list).

## Auto-sense: `ESC[!` and the `RIPSCRIPxxyyvs` response

The RIPscrip specs define a small family of ANSI-style sequences for capability negotiation (the 1.54 spec counts "three", the 2.0α4 spec "four" - same list, with `ESC[0!` counted differently) ([1.54 spec, "ANSI SEQUENCES (AUTO-SENSING)"](../../1.54/text/RIPScrip-1.54.txt); [2.0α4 spec §3.1](../../2.0/text/RIPScrip-2.0-alpha-4.txt)):

- `ESC[!` (and the equivalent `ESC[0!`) - query the RIPscrip version. A RIPscrip terminal responds with `RIPSCRIPxxyyvs`: `xx` = zero-padded major version, `yy` = zero-padded minor version, `v` = vendor code, `s` = vendor sub-version. A non-RIPscrip terminal simply ignores the sequence - that is the whole auto-sense trick.
- `ESC[1!` - disable RIPscrip processing (sequences render as raw text); `ESC[2!` - re-enable it.
- Vendor codes in the 1.54 spec: 0 = generic, 1 = RIPterm, 2 = Qmodem Pro. The 2.0α4 spec adds 3 = deltaComm (Telix) and 4 = Qmodem Pro for Windows, and marks vendor determination via the response "obsolete in RIPscrip 2.0" in favor of the `$TERMINFO()$`, `$IFS()$` and `$LANGUAGE$` text variables - `ESC[!` remains the way to detect RIPscrip capability itself ([2.0α4 spec §3.1, NOTE](../../2.0/text/RIPScrip-2.0-alpha-4.txt)).

Observed responses in the shipped TeleGrafix binaries (direct binary evidence, via `strings`):

| Client | Response string | Evidence |
| --- | --- | --- |
| RIPterm 1.54 | `RIPSCRIP015410` (v1.54, vendor 1 = RIPterm, sub-version 0) | `strings ~/src/rip-tools/RIPterm154/DOS/RIPTERM/RIPTERM.EXE`; also given as the worked example in the 1.54 spec and as `$RIPVER$` sample output in 1.54 `RIPTERM.DOC` §5 ("$RIPVER$ … e.g., RIPSCRIP015400") |
| RIPterm 2.0 | `RIPSCRIP020000` | `strings ~/src/rip-tools/RIPTerm2.0/extracted/RIPTERM.EXE` |
| RIPterm 2.30 | `RIPSCRIP020000` (unchanged from 2.0 - the terminal still identifies as RIPscrip 2.0) | `strings ~/src/rip-tools/artifacts/ripterm-2.30/extracted/RIPTERM.EXE` |
| RIPtel 3.1 | `RIPSCRIP03000…` - the help FAQ quotes the string a user sees when a host times out mid-handshake: "you will see the phrase 'RIPSCRIP03000' displayed on the logon screen" | `strings ~/src/rip-tools/artifacts/RIPtel/RIPTEL.HLP` (FAQ topic on MajorBBS/WorldGroup auto-sense timeouts) |

Operational details from the TeleGrafix docs:

- A 1.51 bug fix confirms the response is typed _into the input stream at the cursor_: "If the auto-sensing ANSI command was received and the cursor was still in column #1, it would not respond with any return sequence" (`WHATSNEW.DOC`, "Version 1.51.00"). This is why stray `RIPSCRIP…` text appears at login prompts when a host mis-times the handshake - RIPtel's own FAQ tells users to just backspace over it (`RIPTEL.HLP`, above).
- 1.54's "Data security" option gates host queries: "prevents any BBS from querying info from your terminal without you being given the opportunity to approve the information transfer" (1.54 `RIPTERM.DOC`, options list).
- RIPtel 3.1 additionally negotiates a conventional telnet terminal type: the executable's resources contain `TerminalEmulation` and telnet-subnegotiation-shaped `vt100` strings (`strings ~/src/rip-tools/artifacts/RIPtel/RIPTEL.EXE`: `%c%c%c%cvt100`, `%c%c%c%cVT100`) - i.e., at the telnet layer RIPtel identifies as a VT100-class terminal.

## Text modes and status display

- RIPterm 1.54 runs the text window on the EGA 640×350 hi-res text grid; the reset state is "a full 80x43 EGA hi-res text mode" ([1.54 spec, RIP_RESET_WINDOWS](../../1.54/text/RIPScrip-1.54.txt)). The status bar's third field shows "What terminal emulation is in use" (normally `RIPscrip`), doubling as the log-file/printer indicator (1.54 `RIPTERM.DOC` §7.2 "The Status Bar").
- RIPterm 2.x renders the text window with the MicroANSI bitmap-font container (`RIPTERM.FNT` 2.0, `RIPTERM.MAF` 2.20/2.30) backing five selectable System Font grids: **80×25, 80×43, 91×25, 91×43, 40×25** (`RIPTerm2.0/extracted/RIPTERM.DOC` §4.4; format details in [version/2.x techspecs](../../2.0/techspecs/README.md) and the [2.x fonts asset README](../../2.0/assets/fonts/README.md)).
- RIPtel 3.1 offers the same five text grids - "80x43, 91x43, 80x25, 91x25, 40x25" - plus screen modes Normal / Full screen / 640×480 / 800×600 / 1024×768, and a user-selectable default text-window font ("five choices", `~/src/rip-tools/artifacts/RIPtel/readme.txt` §2.0; grid list from `MESSAGES.HLP` strings via the [help research](../../3.0/research/riptel-help-extraction.md)).
- Scrollback and log files are text-side features that _filter out_ the graphics layer: "The scrollback buffer filters out ANSI color codes and RIPscrip graphics" and log files capture text with "ANSI color codes and RIPscrip graphics commands … filtered out" (1.54 `RIPTERM.DOC`, scrollback and "OPEN LOG FILE" sections; the 2.x manuals add Doorway commands to the filtered list).

## Character set

- The RIPscrip command language itself is deliberately 7-bit: "The script language conforms to 7-bit ASCII, avoiding the use of Extended ASCII characters" ([1.54 spec, "WHAT IS RIPscrip?"](../../1.54/text/RIPScrip-1.54.txt)).
- The _text window_, by contrast, displays the full 8-bit IBM PC character set: the 3.x whitepaper describes a text window as "much like a normal MS-DOS screen" ([3.x whitepaper, "Text Windows"](../../3.0/text/RIPScrip-3.x-technical-whitepaper.txt)), and the display glyphs come from RIPterm's own bitmap fonts (`RIPTERM.FNT`/`.MAF` MicroANSI containers), not the video BIOS.
- The code page is **CP437**, the standard IBM PC/DOS character set - as was typical for DOS-based BBS terminals and host software, the TeleGrafix docs assume it without naming it; RIPterm supplies the glyphs from its own bitmap fonts (`RIPTERM.FNT`/`.MAF` MicroANSI containers) rather than the video BIOS. The 2.x manuals explicitly defer internationalization: "Translation tables are used for international character set support … Currently, RIPterm does not support Translation Tables" (`RIPTERM.DOC` §4.5, 2.30). In VT-102 mode the separate G0/G1 US/UK/line-drawing sets from the sequence table above apply (1.54 `RIPTERM.DOC` Appendix B; `WHATSNEW.DOC` 1.51).

## Per-version summary

| Capability | RIPterm 1.54 | RIPterm 2.x (2.30 final) | RIPtel 3.1 |
| --- | --- | --- | --- |
| ANSI-BBS text handling | Always on | Toggle (Ctrl-Alt-A) | Setup/bookmark emulation = ANSI |
| VT-102 mode | Toggle (since 1.51) | Toggle + per-host dialing-directory flag | Setup/bookmark emulation = VT-102 |
| Doorway mode | Yes (complete, since 1.53) | Yes (Alt-=) | `$DWAYON$`/`$DWAYOFF$` documented in help |
| Documented sequence list | Appendix B (authoritative) | Not republished; 2.x change logs show no sequence changes | Not published; help documents behavior only |
| Auto-sense response | `RIPSCRIP015410` | `RIPSCRIP020000` (identical in the 2.0 and 2.30 binaries) | `RIPSCRIP03000…` (help FAQ) |
| Text grids | 80×43 EGA (reset state) | 80×25/80×43/91×25/91×43/40×25 | Same five grids + VGA/SVGA screen modes |
| Keyboard macro emulation sets | - (hardcoded VT-102 keymap) | `ANSI.MAC`/`VT100.MAC`, `TYPE=EMULATION` | n/a (Windows client) |

Sources for the table are the per-product citations above. The 2.x column reflects RIPterm 2.30, the final release, as the definitive 2.x reference; the recovered 2.0 install and the 2.30 change logs (`README.DOC` §3) show the same emulation feature set across the line.

---

[◀ Prev: Contents](README.md) · [Contents](README.md) · [Next: Modern Terminal Baseline: SyncTERM and icy_term ▶](modern-terminal-reference.md)

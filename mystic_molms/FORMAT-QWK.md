# QWK packet format (as implemented by OpenOLMS)

Original format by Mark "Sparky" Herring. This describes the on-disk layout
OpenOLMS reads/writes (see src/olms_qwk.pas, src/olms_rep.pas).

## Files
- `CONTROL.DAT` — text manifest: BBS name, city, phone, sysop, "serial,BBSID",
  date/time, USER (uppercase), a blank line, `0`, total messages,
  (conference count - 1), then per-conference (number, name) pairs, then the
  welcome/news/goodbye file names.
- `MESSAGES.DAT` — 128-byte blocks. Block 0 is a 128-char identifier string.
  Each message = 1 header block + ceil(textlen/128) text blocks.
- `<conf>.NDX` — per-conference index of message header positions.

## Header block (128 bytes; 1-based byte positions)
| Pos     | Len | Field |
|---------|-----|-------|
| 1       | 1   | status flag (' ' public) |
| 2-8     | 7   | message number (ASCII) |
| 9-16    | 8   | date `MM-DD-YY` |
| 17-21   | 5   | time `HH:MM` |
| 22-46   | 25  | To |
| 47-71   | 25  | From |
| 72-96   | 25  | Subject |
| 97-108  | 12  | password |
| 109-116 | 8   | reference number |
| 117-122 | 6   | number of 128-byte blocks incl. header (ASCII) |
| 123     | 1   | active flag (225 active / 226 deleted) |
| 124-125 | 2   | conference number (16-bit LE) |
| 126-127 | 2   | packet message number (16-bit LE) |
| 128     | 1   | net-tag indicator |

Message text uses 0xE3 as the line separator (not CRLF), space-padded to the
128-byte block boundary.

## Replies (.REP)
`<BBSID>.REP` is the compressed reply packet; its payload `<BBSID>.MSG` uses the
same 128-byte-block layout as MESSAGES.DAT but WITHOUT the leading identifier
block (it begins at the first message header). See src/olms_rep.pas.

# Mystic BBS 1.11 — Porting Checklist

Source: https://wiki.mysticbbs.com/doku.php?id=whats_new_111
g00r00 released 1.11 A1-A6 (Oct-Nov 2015), then marked A6 as stable.

## Alpha 1 (Oct 16, 2015) — 13 items

| # | Type | Description | Status |
|---|------|-------------|--------|
| 1 | + | FIDOPOLL blank hostname check | |
| 2 | + | MPL records passed by VAR reference | |
| 3 | + | ANSI abort waits for sequence completion (10+ chars) | |
| 4 | + | ANSI abort time-based (half second) | |
| 5 | + | File listing buffer rework (performance) | |
| 6 | ! | Message base editor menu command shown in list | |
| 7 | ! | /topic in node chat lockup | |
| 8 | ! | /topic reset to blank | |
| 9 | + | Install F2/ESC selectable with arrow keys | |
| 10 | + | ENTER on send node message aborts | |
| 11 | + | Embedded ANSI in message base reading | |
| 12 | + | Full ANSI/Pipe upload and editing in FSE | |
| 13 | + | ANSI art auto-converts to 79-char on save | |

## Alpha 2 (Oct 17, 2015) — 3 items

| # | Type | Description | Status |
|---|------|-------------|--------|
| 1 | + | TZUTC kludge on echomail messages | |
| 2 | ! | Message quoting broken with ANSI embedded messages | |
| 3 | ! | Editor kludge quirkiness from A1 | |

## Alpha 3 (Oct 24, 2015) — 11 items

| # | Type | Description | Status |
|---|------|-------------|--------|
| 1 | + | MUTIL mass upload better logs during .diz import | ✅ |
| 2 | ! | MUTIL mass upload purge temp dir (case sensitive OS) | ✅ |
| 3 | ! | TZUTC bug from A2 | ✅ Fixed with FTS-4008 |
| 4 | + | MPL record function result types | ✅ Full: declare, assign, call site Var := Func() |
| 5 | + | MPL TimerMS : LongInt function | ✅ fn 562 |
| 6 | + | MCI code |Y — force Yes/No default to Yes | ✅ |-Y |
| 7 | + | MCI code |N — force Yes/No default to No | ✅ |-N |
| 8 | ! | Reset inactivity timeout after Zmodem transfer | ✅ |
| 9 | ! | Auto signature weirdness with ANSI messages | ✅ Already handled |
| 10 | + | Searchlight-style prompt menus rework | ⚠️ Not certain — existing code has screen size handling, may not fully match g00r00 rework |
| 11 | + | MPL formatDate(dosDate, mask) function | ✅ fn 563, fully wired |
| 12 | + | MPL dateDos2Str/dateJulian2Str format 4/5/6 (4-digit year) | ✅ |
| 13 | ! | File description editing disabled | ✅ Already working |
| 14 | ! | MsgEditor MPL function disabled | ✅ Already working |

## Alpha 4 (Nov 5, 2015) — 3 items

| # | Type | Description | Status |
|---|------|-------------|--------|
| 1 | + | MUTIL echomail export resume tracking | |
| 2 | ! | False duplicate during TIC toss with REPLACES | |
| 3 | + | Strip tear/origin/kludge in editor, regenerate on save | |
| 4 | ! | Quoting message > 10,000 lines crash | |

## Alpha 5 (Nov 5, 2015) — 2 items

| # | Type | Description | Status |
|---|------|-------------|--------|
| 1 | + | Forward message strips network info, recalculates | |
| 2 | ! | MPL multi-dim arrays in records wrong value | |

## Alpha 6 (Nov 6, 2015) — 2 items (STABLE)

| # | Type | Description | Status |
|---|------|-------------|--------|
| 1 | + | ANSI draw mode cleanup in FSE (ESC menu) | |
| 2 | ! | Amiga font switching blocked in Linux parser | |

## Summary

| Alpha | Items | Key Features |
|-------|-------|-------------|
| A1 | 13 | MPL VAR records, embedded ANSI, ANSI in FSE |
| A2 | 3 | TZUTC, ANSI quote fix |
| A3 | 14 | MPL record functions, formatDate, TimerMS, MCI |Y |N |
| A4 | 4 | MUTIL export resume, strip kludge in editor |
| A5 | 2 | Forward strips network, MPL array fix |
| A6 | 2 | ANSI draw mode, Amiga font fix |
| **Total** | **38** | |

## Priority for 1.11IRC

High:
- MPL records by VAR reference (A1)
- MPL record function results (A3)
- Embedded ANSI in messages (A1)
- ANSI upload/edit in FSE (A1)

Medium:
- ANSI art 79-char convert (A1)
- formatDate MPL function (A3)
- MUTIL export resume (A4)
- Strip kludge in editor (A4)
- ANSI draw mode FSE (A6)

Low:
- Small bug fixes (A1-A6)
- MCI |Y |N (A3)
- TimerMS (A3)
- Install arrow keys (A1)


## Phase 2 — IRC Fork Items (1.11IRC A7)

| # | Type | Description | Status |
|---|------|-------------|--------|
| 1 | + | FTP download prompt wiring (prompts 528-531) | Pending |
| 2 | + | HTTP server configuration in mystic.dat | Pending |
| 3 | + | FOSSIL wired into mystic.exe (TIOFossil, -COM, -FOSSIL) | ✅ No config UI yet |
| 4 | + | m_io_fossil.pas: TIOBase adapter for FOSSIL/serial | ✅ MIS not needed |
| 5 | + | Print API backport v1-v4 (6 drivers, any resolution) | ✅ |
| 6 | + | MDL refactor Phase 1: MIS wrappers to FPC RTL | Pending |
| 7 | + | MDL refactor Phase 2: mystic core | Pending |
| 8 | + | MDL refactor Phase 3: cleanup | Pending |
| 9 | + | OS/2 target via fpc264irc EMX linker | ✅ Working (slow compile) |


## ANSI to RIP Converter (chg2rip v2.3)

| Tool | Status | Output |
|------|--------|--------|
| chg2rip.pas | ✅ 100% pixel-perfect | .rip (44KB) |
| ans2png.pas | ✅ 100% pixel-perfect | .bmp |
| vgafont.inc | ✅ | VGA 8x16 font ROM |

Reference: examples/ripterm154/ (DOS), examples/riptermJS/ (JS viewer)

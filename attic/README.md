# attic — retired files (not part of the build)

Files kept here for historical/reference purposes only.  Nothing in `attic/`
is compiled or referenced by the live source (the source branches are
`mdl/` and `mystic/`).  Items here may be deleted in future.

## Contents
- **m_resolve_address.c** — Unix C glue for the old IPv6-capable
  `ResolveAddress_IPv6`.  Retired when the socket layer was converted to
  IPv4 and `TIOSocket.ResolveAddress` was rewritten in pure Pascal
  (GetHostByName) in `mdl/m_io_sockets.pas`, matching A39.  No longer linked.

## Candidates to move here later
- **mdl/m_socket_class.pas** (TSocketClass) — legacy/unused socket class;
  only referenced by mdl/mdltest5.pas.  Left in mdl/ for now (test still
  references it) but flagged for retirement.

- **CHANGELOG.TXT** — Vincent Chapman's 2013 changelog documenting the
  original IPv6 socket layer and `m_resolve_address.c` -- i.e., the very C
  resolver we just retired.  It's upstream history, kept here for reference
  now that the code it describes has been retired / converted to IPv4.

## g00r00 upstream reference (retired 2026-07-07)

Original Mystic history/changelog files, kept for reference:

- `HISTORY_g00r00_v105-v110.txt` - upstream history, Mystic v1.05 through v1.10
- `fullhistory_g00r00.txt` - upstream full changelog from v1.05
- `whatsnew_g00r00_upto_A38.txt` - g00r00's whatsnew ending at `<ALPHA 38 RELEASED>`
  (our exact base version). This fork's own whatsnew now lives only in `mystic/whatsnew.txt`
  (the single canonical copy).
- `README_ORIGINAL_SOURCE_DIST.txt` - the original Mystic source-distribution README
  (superseded by this fork's root `INSTALL` + `build.sh`/`build-win32.bat`).

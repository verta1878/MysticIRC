# Configuring OpenOLMS

Run `CONFIG.EXE` in the door's directory. It reads and writes `OLMS.CFG` (a
plain key=value text file olms.exe also reads).

## Menu
- **(1) System Information** — system name, sysop name, board ID (1-8 chars,
  used as the QWK packet name), phone, internet gateway address.
- **(2) Archiver Programs** — the compress/decompress command lines. Point
  these at your archiver. Macros: `%ARCHIVE%` = the .QWK file, `%FILES%` = the
  packet files. Example:
      Compress:   PKZIP.EXE -ex %ARCHIVE% %FILES%
      Decompress: PKUNZIP.EXE -o %ARCHIVE%
  The archiver MUST be on the DOS PATH or in the door directory.
- **(3) Limits** — max messages per packet, max packet KB, max conferences.
- **(4) Message Areas** — the conferences the door offers. For each area:
  number, name, type (JAM or Hudson), path, and (Hudson only) board number.
  UP/DN to select, E=edit, A=add, D=delete.
- **(S) Save and exit** — writes OLMS.CFG.

## Message areas
- **JAM**: set Path to the base path WITHOUT extension. Relative paths are
  resolved against the door directory; absolute paths (e.g. `C:\RA\MSG\GENERAL`)
  are used as-is. OpenOLMS reads `<path>.JHR` and `<path>.JDT`.
- **Hudson**: set Path to the directory containing `MSGHDR.BBS` / `MSGTXT.BBS`,
  and set Board # to the Hudson area number.

## OLMS.CFG format (for reference / hand-editing)
    SystemName=Ecstasy BBS
    SysopName=reapern66
    BoardID=ECSTASY
    Archiver=ZIP|PKZIP.EXE -ex %ARCHIVE% %FILES%|PKUNZIP.EXE -o %ARCHIVE%|1
    MaxMessages=1000
    MaxPacketKB=500
    MaxConfs=2000
    Area=1|General|J|GENERAL|0|1
    Area=2|Mystic|J|MYSTIC|0|1
    Area=5|Fido News|H|C:\RA\MSG|12|1

Area fields: number | name | type(J/H) | path | board | active(1/0)

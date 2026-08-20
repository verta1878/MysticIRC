# OpenOLMS → MOLMS Migration Plan

## Date: 2026-08-20

## What Is OpenOLMS?

OpenOLMS is a clean-room offline mail system (QWK/BlueWave/Hudson/JAM).
Currently lives inside examples/mterm/ as 24 files, ~6,200 lines.
Goal: rename to MOLMS (Mystic Offline Mail System), use mdl/ instead
of its own library, and give it its own directory.

## Current Files (in examples/mterm/)

### Library Units (OL_*.pas)
| File | Lines | What | MDL Replacement |
|------|-------|------|-----------------|
| OL_ANSI.pas | 244 | ANSI console output | m_output_linux/windows |
| OL_BlueWave.pas | 199 | BlueWave packet format | KEEP (format-specific) |
| OL_Compat.pas | 421 | OLMS binary record types | KEEP (compatibility layer) |
| OL_Config.pas | 176 | Config file reader | m_inireader.pas |
| OL_DropFile.pas | 275 | Drop file reader | m_door.pas |
| OL_Editor.pas | 231 | Text editor | m_editor_*.pas |
| OL_Filter.pas | 275 | Message filtering | KEEP (app-specific) |
| OL_Hudson.pas | 328 | Hudson message base | KEEP (format-specific) |
| OL_JAM.pas | 425 | JAM message base | KEEP (format-specific) |
| OL_MDL.pas | 225 | MDL interface stub | DELETE (use mdl/ directly) |
| OL_MsgCtl.pas | 195 | Message control | KEEP (app-specific) |
| OL_Packer.pas | 423 | Archive pack/unpack | KEEP (app-specific) |
| OL_QWK.pas | 259 | QWK packet format | KEEP (format-specific) |
| OL_Transfer.pas | 281 | File transfer | m_prot_zmodem + m_protocol_* |
| OL_Users.pas | 141 | User management | KEEP (app-specific) |

### Programs
| File | Lines | What |
|------|-------|------|
| molms.pas | 742 | MOLMS — Mystic MDL version |
| openolms.pas | 176 | Standalone version |
| openolms_dos.pas | 353 | DOS version |
| olmscfg.pas | 307 | Config editor |
| olmsmnt.pas | 132 | Maintenance tool |

### Support
| File | Lines | What |
|------|-------|------|
| editor.pas | 221 | Built-in text editor |
| mt_spell.pas | 179 | Spell check |
| upgrade1.pas | 245 | OLMS → MOLMS upgrade |
| upgrade2.pas | 247 | Data migration |
| userconf.pas | 376 | User config UI |

## Migration Phases

| Phase | What | Priority |
|-------|------|----------|
| MOLMS-1 | Create examples/molms/ directory, move all 24 files | HIGH |
| MOLMS-2 | Replace OL_ANSI.pas with mdl/ m_output | HIGH |
| MOLMS-3 | Replace OL_DropFile.pas with mdl/ m_door | HIGH |
| MOLMS-4 | Replace OL_Transfer.pas with mdl/ m_prot_zmodem | MEDIUM |
| MOLMS-5 | Replace OL_Editor.pas with mdl/ m_editor_* | MEDIUM |
| MOLMS-6 | Replace OL_Config.pas with mdl/ m_inireader | LOW |
| MOLMS-7 | Delete OL_MDL.pas — use mdl/ directly | HIGH |
| MOLMS-8 | Rename OL_*.pas → m_olms_*.pas (MDL naming) | LOW |
| MOLMS-9 | Verify all 3 programs compile (molms, openolms, openolms_dos) | HIGH |
| MOLMS-10 | Test with QWK packet round-trip | HIGH |

## What STAYS (format-specific, no MDL equivalent)

- OL_BlueWave.pas — BlueWave offline mail format
- OL_Hudson.pas — Hudson message base format
- OL_JAM.pas — JAM message base format
- OL_QWK.pas — QWK packet format
- OL_Compat.pas — binary-compatible OLMS record types (Turbo Pascal layout)
- OL_Filter.pas — message filtering rules
- OL_MsgCtl.pas — message control
- OL_Packer.pas — archive compression
- OL_Users.pas — user record management

These are app-specific. No MDL equivalent exists or should.

## What GOES (replaced by mdl/)

| Delete | Replace With |
|--------|-------------|
| OL_ANSI.pas (244 lines) | m_output_linux/windows (already in mdl/) |
| OL_DropFile.pas (275 lines) | m_door.pas (already in mdl/) |
| OL_Transfer.pas (281 lines) | m_prot_zmodem + m_protocol_* (already in mdl/) |
| OL_Editor.pas (231 lines) | m_editor_console/io/session (already in mdl/) |
| OL_MDL.pas (225 lines) | Direct mdl/ usage |
| OL_Config.pas (176 lines) | m_inireader.pas (already in mdl/) |

Total removed: ~1,432 lines replaced by existing mdl/ units.

## Credits

- verta1878 — project lead
- wrench — OL_Compat.pas binary record verification
- Peter Rocca — original OLMS (permission granted for clean-room reimplementation)
- kiddo — migration planning

## License

GPLv3

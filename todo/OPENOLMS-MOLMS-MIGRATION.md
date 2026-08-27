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
| MOLMS-1 | Create mystic_molms/ directory, move all files | DONE |
| MOLMS-2 | Replace OL_ANSI.pas with mdl/ m_output | HIGH |
| MOLMS-3 | Replace OL_DropFile.pas with mdl/ m_door | HIGH |
| MOLMS-4 | Replace OL_Transfer.pas with mdl/ m_prot_zmodem | MEDIUM |
| MOLMS-5 | Delete OL_MDL.pas — use mdl/ directly | HIGH |
| MOLMS-6 | Study OL_Editor.pas vs m_editor_* — decide merge or keep | LOW |
| MOLMS-7 | Study OL_Config.pas vs m_inireader — decide merge or keep | LOW |
| MOLMS-8 | Evaluate mt_spell.pas for MDL promotion | LOW |
| MOLMS-9 | Evaluate mail formats (JAM/QWK/BlueWave/Hudson) for MDL | DISCUSS |
| MOLMS-10 | Verify all 3 programs compile (molms, openolms, openolms_dos) | HIGH |
| MOLMS-11 | Test with QWK packet round-trip | HIGH |

## What STAYS (format-specific, no MDL equivalent)

- OL_BlueWave.pas — BlueWave offline mail format
- OL_Hudson.pas — Hudson message base format
- OL_JAM.pas — JAM message base format
- OL_QWK.pas — QWK packet format
- OL_Compat.pas — binary-compatible OLMS record types (Turbo Pascal layout)
- OL_Filter.pas — keyword filtering + twit lists (per-user .KEY/.TWT files)
- OL_MsgCtl.pas — message area control (MESSAGES.CTL)
- OL_Packer.pas — QWK pack/unpack engine (core offline mail logic)
- OL_Users.pas — USERS.DAT per-user settings (OLMS binary format)

These are app-specific. No MDL equivalent exists or should.

## What GOES (replaced by mdl/)

| Delete | Replace With |
|--------|-------------|
| OL_ANSI.pas (244 lines) | m_output_linux/windows (already in mdl/) |
| OL_DropFile.pas (275 lines) | m_door.pas (already in mdl/) |
| OL_Transfer.pas (281 lines) | m_prot_zmodem + m_protocol_* (already in mdl/) |
| OL_MDL.pas (225 lines) | Direct mdl/ usage |

Total removed: ~1,025 lines replaced by existing mdl/ units.

## What STAYS (keep for now — learn from before replacing)

| Unit | Lines | Why Keep |
|------|-------|----------|
| OL_Editor.pas | 231 | Different design than m_editor_*. Study first. |
| OL_Config.pas | 176 | Different approach than m_inireader. Study first. |
| mt_spell.pas | 179 | Spell checker. Useful beyond OLMS. MDL candidate. |

## What STAYS (format-specific — future MDL candidates)

These are app-specific now, but could become MDL units.
Adding mail format support to MDL means ANY Mystic program
can read/write offline mail packets, not just OLMS.

| Unit | Lines | What | MDL Potential |
|------|-------|------|---------------|
| OL_BlueWave.pas | 199 | BlueWave offline mail | m_mail_bluewave.pas |
| OL_Hudson.pas | 328 | Hudson message base | m_mail_hudson.pas |
| OL_JAM.pas | 425 | JAM message base | m_mail_jam.pas (Mystic uses JAM already) |
| OL_QWK.pas | 259 | QWK packet format | m_mail_qwk.pas |
| OL_Compat.pas | 421 | OLMS binary record types (Turbo Pascal layout) | KEEP in MOLMS |
| OL_Filter.pas | 275 | Keyword filtering + twit lists. Per-user .KEY/.TWT files reduce QWK packet size. OLMS signature feature. | KEEP in MOLMS |
| OL_MsgCtl.pas | 195 | Message control (MESSAGES.CTL — area config, pointers) | KEEP in MOLMS |
| OL_Packer.pas | 423 | QWK pack/unpack engine. Reads msgbase → MESSAGES.DAT + .NDX + CONTROL.DAT → ZIP. Unpacks .REP replies. | MDL candidate |
| OL_Users.pas | 141 | USERS.DAT reader/writer. Per-user pointers, conference selection, archive prefs. OLMS binary format. | KEEP in MOLMS |

Discussion needed: which of these should move to mdl/ as shared
mail format libraries? JAM is the strongest candidate since Mystic
already uses JAM internally — one implementation instead of two.

## Team

| Handle | Role |
|--------|------|
| verta1878 | Project lead |
| sysop/0 | Compiler engineer, FPC, Tang Console, USB |
| bob | Compiler engineer, OpenWatcom, Glide, 3dfx drivers |
| evga | Display, Mystic, SIO rebuild |
| kiddo | Protocols, RIPscrip |
| wrench | Transport, FOSSIL, DVI/HDMI |
| hexadecimal | PCBoard, Cyclades |
| byte | Program discovery |
| DotMatrix | Documentation sourcing |


## License

GPLv3

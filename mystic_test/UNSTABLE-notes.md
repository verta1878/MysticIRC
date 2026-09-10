# mystic_test — Unstable Branch Notes

## Features in mystic_test NOT in mystic (stable)

| File                | Feature                                    |
|---------------------|--------------------------------------------|
| bbs_hunspell.pas    | Hunspell spell check integration           |
| bbs_crypt.pas       | Encryption / crypto module                 |
| bbs_rip.pas         | RIP graphics integration                   |
| mis_ansiwfc_110.pas | Updated ANSI WFC (Waiting For Caller)      |

### maketheme.pas improvements (not yet promoted)

- CFGPATH command — set DataPath directly without loading Mystic
- RIP field sanitization — validates RipScreenW/H on load
- Updated copyright line for IRC fork

## Features in mystic (stable) NOT in mystic_test

| File                   | Feature                         |
|------------------------|---------------------------------|
| m_protocol_base.pas    | Protocol base class             |
| m_protocol_kermit.pas  | Kermit file transfer            |
| m_protocol_queue.pas   | Protocol transfer queue         |
| m_protocol_xmodem.pas  | XModem file transfer            |
| m_protocol_ymodem.pas  | YModem file transfer            |
| m_protocol_zmodem.pas  | ZModem file transfer            |

These 6 protocol units need porting to mystic_test.

## MDL Test Status

| Test       | What                          | Compile | Run     |
|------------|-------------------------------|---------|---------|
| mdltest0   | CRT basic                     | untested| untested|
| mdltest1   | m_Input, m_Output, m_Strings  | untested| untested|
| mdltest2   | m_Types, m_Strings, m_Input   | untested| untested|
| mdltest3   | m_io_Sockets                  | untested| untested|
| mdltest4   | m_io_Sockets                  | untested| untested|
| mdltest5   | RecConfig size (5282 bytes)   | PASS    | PASS    |
| mdltest6   | m_Input, m_Output             | untested| untested|
| mdltest7   | m_Types, m_Strings, m_Output  | untested| untested|
| mdltest8   | m_Output, m_DateTime          | untested| untested|
| mdltest9   | m_sdlcrt (SDL console)        | PASS    | needs SDL libs |
| mdltest10  | m_mouse                       | PASS    | interactive    |
| mdltest11  | m_fossil (FOSSIL driver)      | PASS    | 15/15 PASS     |

## Recent Fixes (Session 10)

- m_io_base.pas: PurgeInputData and PurgeOutputData made Virtual
  (fixes m_fossil_io.pas Override errors)
- m_protocol_binkp.pas: A42 ARGUS null terminator fix, A44 actual
  file timestamp fix. Old m_prot_binkp.pas retired to attic/
- m_sdl.pas + m_sdl_bind.pas + m_sdl_ttf.pas + m_sdl_dosscreen.pas
  copied into mdl/ (were only in mystic_sdl/)
- mdltest5 created (was test_recconfig.pas at root)
- mdltest11 rewritten against current m_fossil API

## Build Note

mystfoss.pas requires `-Fumdl/m_serial` in the search path.

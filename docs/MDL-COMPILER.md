# MDL Compiler Abstraction Layer

`mystic/mdl/m_compiler.pas` — single unit for compiler/platform detection.

## Supported Compilers

| Symbol | Compiler | Status |
|--------|----------|--------|
| MDL_FPC | Free Pascal (2.6.4irc, 3.2.2+) | Primary |
| MDL_DELPHI | Delphi 7, 10+, 12 | Planned |
| MDL_VP | Virtual Pascal 2.1 (OS/2) | Planned |
| MDL_TP | Turbo Pascal 7 (DOS) | Planned |

## Platform Symbols

| Symbol | Platform |
|--------|----------|
| MDL_WIN | Windows (32/64) |
| MDL_UNIX | Linux, FreeBSD, OpenBSD, NetBSD, Darwin |
| MDL_DOS | DOS (go32v2, DPMI, real mode) |
| MDL_OS2 | OS/2 |

## Constants

| Constant | Example |
|----------|---------|
| MDL_COMPILER | 'FPC' |
| MDL_PLATFORM | 'UNIX' |
| MDL_PATHSEP | '/' |
| MDL_LINEENDING | #10 |
| MDL_DEFAULT_SERIAL | '/dev/ttyS0' |

## Migration

Phase 1: m_compiler.pas exists, MDL units can start using it
Phase 2: Replace {$IFDEF UNIX} with {$IFDEF MDL_UNIX} across MDL
Phase 3: Test with Delphi 7
Phase 4: Test with Virtual Pascal (OS/2)
Phase 5: Test with TP7 (Objects instead of Classes, ShortString)

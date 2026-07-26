# mystic_test — RIPscrip Integration Testing

Test harness for porting the RIPscrip engine into the Mystic BBS codebase.

## Purpose

This directory contains integration tests and bridge code for connecting
`mystic_rip/v1` (the standalone RIPscrip v1.54 engine) to the Mystic BBS
terminal I/O layer. The engine was developed standalone with zero MDL
dependencies — this directory handles the wiring.

## Integration Points

| Mystic Component | RIPscrip Hook | Status |
|------------------|---------------|--------|
| `m_term.pas` | Terminal output → ProcessLine | Pending |
| `m_pipe.pas` | Pipe code rendering → RIP commands | Pending |
| `m_socket.pas` | RIP data stream from remote | Pending |
| `m_inkey.pas` | Mouse/hotkey → FindButtonByHotkey | Pending |
| `m_output.pas` | Screen buffer → RIP pixel buffer | Pending |
| `mystic.pas` | RIP mode detection, init/free | Pending |

## Files

| File | Description |
|------|-------------|
| README.md | This file |
| NOTES.md | Integration notes and decisions |

## Build

Tests compile against both `mystic_rip/v1/` and `mystic/mdl/`:

```
ppc386 -Mdelphi -Fu../mystic_rip/v1 -Fu../mdl test_rip_integration.pas
```

## License

GNU General Public License v3.

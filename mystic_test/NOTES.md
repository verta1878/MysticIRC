# RIPscrip Integration Notes

## Architecture

```
mystic/              Main BBS codebase (CLEAN — no RIP code)
  |
mystic_rip/v1/       Standalone v1.54 engine (zero MDL deps)
mystic_rip/v2/      Standalone v2.0 engine (zero MDL deps)
  |
mystic_test/         Integration workspace
  |-- (server code)    RIP scene serving — BBS sends RIP to client
  |-- (client code)    RIP terminal detection + input routing
  |-- (bridge code)    Wires mystic_rip/v1 → Mystic terminal layer
```

## Rules

1. **mystic_rip/v1/** is STANDALONE — never uses MDL, m_Types, m_Strings
2. **mystic/** stays CLEAN — no RIP rendering code in the main tree
3. **mystic_test/** is the ONLY place engine meets BBS
4. Legacy files are REFERENCE ONLY — not compiled, not modified
5. All integration tested here BEFORE merging to mystic/

## Components to Build

### RIP Server (BBS → Client)
- Send .RIP scene files to RIP-capable terminals
- Menu system generates RIP commands for buttons/icons
- Message viewer renders with RIP formatting
- File area displays with RIP icons
- Icon/font file serving (CHR, ICN, MSK, HIC)

### RIP Client (Client → BBS)
- Terminal detection: watch for RIPSCRIP015410 capability string
- Mouse click → FindMouseField → HostCmd → BBS input
- Keyboard hotkey → FindButtonByHotkey → BBS input
- Tab navigation through form fields
- Text variable responses ($DEFINE$ prompts)

### Bridge Layer
- m_term.pas hook: route RIP lines through TRIPEngine.ProcessLine
- m_output.pas hook: pixel buffer → terminal (for local console)
- m_inkey.pas hook: mouse/hotkey events from RIP terminal
- Config: RIP icon path, font path, scene path in mystic.dat

## Data Flow

```
BBS generates RIP scene
    |
    v
TRIPEngine.ProcessLine('!|c0F!|R0A0A5HO9M')
    |
    v
Raw RIP text sent to client socket (pass-through)
    +
    v
Server-side pixel buffer rendered (for preview/logging)

Client sends mouse click (x=150, y=200)
    |
    v
FindMouseField(150, 200) → field index
    |
    v
MouseFields[index].HostCmd → 'MAIL'
    |
    v
BBS processes as menu selection
```

## RIP Mode Detection

RIPterm identifies itself during terminal negotiation:
  `RIPSCRIP015410` — v1.54, revision 10

The BBS should:
1. Send RIP query during login
2. Watch for capability response
3. Set user's terminal type to RIP
4. Switch output path to RIP command generation

## TODO

- [ ] Clean mystic/ — remove orphaned rip_graph/parser/rip2ans
- [ ] RIP terminal detection module
- [ ] RIP scene file server
- [ ] Menu → RIP command generator
- [ ] Mouse click → BBS input bridge
- [ ] Keyboard hotkey bridge
- [ ] Icon/font path configuration
- [ ] Local console RIP preview (pixel buffer → display)
- [ ] Integration tests with RIPterm154

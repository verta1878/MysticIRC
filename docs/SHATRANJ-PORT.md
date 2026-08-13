# Shatranj — Pascal Port Analysis


### What Is It
Network chess for ZX Spectrum 48K to modern desktops. Written in C + Z80 ASM.
Direct TCP or MQTT transport. GPL-2.0.

### Port Scope

The chess engine (rules + legal moves) is ~1,500 lines of portable C.
The protocol layer is ~750 lines. Total portable logic: ~2,250 lines.

| Component | C Lines | Pascal Port | Difficulty |
|-----------|---------|-------------|------------|
| Chess rules (position, legal moves) | 1,525 | ~1,200 | Medium — bitboards, arrays |
| Protocol (game messages, session) | 737 | ~600 | Easy — structs + serialize |
| Direct TCP session | 69 | ~50 | Easy — we have sockets |
| MQTT transport | 237 | Skip | Not needed for BBS |
| ZX Spectrum UI/ASM | 5,000+ | Skip | Platform-specific |
| Qt desktop client | 3,000+ | Skip | Platform-specific |

### What a BBS Chess Door Would Need

1. **Chess engine** — port position.c + legal.c + rules_compact.c to Pascal
2. **ANSI board renderer** — draw the board with CP437 block chars
3. **Input parser** — algebraic notation (e2e4, Nf3, O-O)
4. **Game protocol** — simple TCP messages for network play
5. **MPL wrapper** — or standalone door with drop file

### Estimated Effort
- Chess engine port: ~1,200 lines of Pascal, 2-3 sessions
- ANSI renderer: ~200 lines
- Input/protocol: ~300 lines
- Total: ~1,700 lines for a working network chess door

### Can It Run as an MPL Script?
The chess engine needs bitwise operations and arrays that MPL supports,
but the 255-char string limit and lack of records/structs would make it
awkward. Better as a compiled Pascal door that reads a drop file, or
as a Script Server service.

### Priority
Low — fun project but not core BBS functionality. Could be a great
community contribution / demo of the Script Server.

# RIP Graphics Phases — mystic_test, mterm, ripview

## MPL Testing Scripts (Do First)

| Phase | What |
|-------|------|
| MPL-0 | Setup: create mystic.dat, theme.dat, security.dat, users.dat via config scripts |
| MPL-1 | Login test script — automate SysOp login (ACCT-1) |
| MPL-2 | New user creation test (ACCT-2) |
| MPL-3 | Email to SysOp test (ACCT-4) |
| MPL-4 | RIP detection test — !|1Q query + R response |
| MPL-5 | RIP menu test — .rip file sent and rendered |

## Phase 0: VIPER-FIX (FIX-1 — FIX-6)

| Phase | What |
|-------|------|
| FIX-1 | Resurrect m_output_graph.pas from attic, strip ptcgraph |
| FIX-2 | Add {$IFDEF DOS} path using FPC Graph unit |
| FIX-3 | Add {$ELSE} path using pixel buffer (headless/Linux) |
| FIX-4 | Replace ripdraw.pas homebrew calls with m_output_graph calls |
| FIX-5 | Verify: ripview renders BILL.RIP + GOD-CTH.RIP — compare against ripstd |
| FIX-6 | Verify: all three programs compile clean (Linux + DOS cross-compile) |

## Phase 1: Setup (RIP-M1 — RIP-M4)

| Phase | What |
|-------|------|
| RIP-M1 | Create mystic_test/mdl/ with fonts and shared rendering stack |
| RIP-M2 | Create mystic_test/text/rip/ with test .rip display files |
| RIP-M3 | Create RIP-enabled menu (.mnu) that sends .rip files |
| RIP-M4 | Create mystic_test/icons/ with test .ICN icon files |

## Phase 2: Mystic RIP Integration (RIP-M5 — RIP-M10)

| Phase | What | Program |
|-------|------|---------|
| RIP-M5 | Display file resolution: .rip → .ans fallback | mystic_test |
| RIP-M6 | RIP terminal detection: !|1Q00000000 query + R response | mystic_test |
| RIP-M7 | Raw .rip file sending (no ANSI processing, no MCI) | mystic_test |
| RIP-M8 | Test: mterm → mystic, RIP detected, .rip menu displayed | mterm + mystic_test |
| RIP-M9 | Test FlushRIPBuf with actual !| over live TCP | mterm |
| RIP-M10 | MCI codes: \|RI (RIP reset) and \|TE (terminal type) | mystic_test |

## Phase 3: DOS VGA Display (VGA-1 — VGA-9)

| Phase | What | Program |
|-------|------|---------|
| VGA-1 | uses Graph, InitGraph(VGA, VGAMed) under {$IFDEF DOS} | mterm |
| VGA-2 | RIP engine renders to Graph framebuffer | mterm |
| VGA-3 | uses Graph for screen display on DOS | ripview |
| VGA-4 | Screen default on DOS, BMP default on Linux | ripview |
| VGA-5 | uses Graph for server-side RIP preview under {$IFDEF DOS} | mystic_test |
| VGA-6 | Cross-compile all three with fpc264irc | all |
| VGA-7 | Test mterm.exe in DOSBox → telnet → Mystic → RIP on VGA | mterm |
| VGA-8 | Test ripview.exe in DOSBox → .RIP on VGA screen | ripview |
| VGA-9 | Test mystic.exe in DOSBox → sysop sees RIP screens on VGA | mystic_test |

## Phase 4: SDL 1.2 (Future/Maybe)

| Phase | What | Program |
|-------|------|---------|
| SDL-1 | SDL 1.2 display unit for pixel framebuffer | shared |
| SDL-2 | Render to SDL surface under {$IFDEF SDL} | mterm |
| SDL-3 | Render to SDL surface under {$IFDEF SDL} | ripview |
| SDL-4 | Render to SDL surface under {$IFDEF SDL} | mystic_test |
| SDL-5 | Test on Linux — native SDL window, no DOSBox | all |

## UTF-8 Terminal Support

| Phase | What |
|-------|------|
| UTF8-1 | Study Mystic 1.12 UTF-8 implementation in bbs_io.pas |
| UTF8-2 | ESC(U (CP437) / ESC(B (UTF-8) switching in m_output |
| UTF8-3 | UTF-8 font rendering in graphics mode |
| UTF8-4 | UTF-8 terminal auto-detection |

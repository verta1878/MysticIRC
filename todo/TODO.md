# Mystic BBS 1.11IRC — TODO

## Completed ✅
- [x] SDL units renamed (sdl.pas → m_sdl.pas, etc.)
- [x] RIPView pixel-perfect (10/13 under 3%, 3 pixel-perfect)
- [x] v1-v4 engine backport (all 17 fixes)
- [x] mterm RIP engine (6 phases, 1664 lines, 49 commands)
- [x] Phase 4: bbs_rip.pas + EXPERIMENTAL_RIP ifdef
- [x] Full 213 RIP batch test — zero failures
- [x] MIS comparison (11/13 identical)
- [x] ANSI editor comparison chart
- [x] OpenOLMS synced to mterm
- [x] HS/Link protocol (clean-room, 1067 lines)
- [x] ans2rip pixel-perfect with -p flag
- [x] EGA palette standardized across all engines

## Recently Completed
- [x] MUTIL-1: -RUN, -LIST, -VER, -HELP, -NOSCREEN flags
- [x] MUTIL-2: Log roller, logcache, per-stanza loglevel, process timing
- [x] MUTIL-3: EchoNodeTracker, EchoUnlink, AutoHatch tasks
- [x] MUTIL-4: INI synced with 1.12 (26 sections, 25 task toggles)
- [x] MUTIL-5: All 25 tasks wired, 8 stub modules for missing tasks
- [x] MIS-1: 1.12 ANSI screen with tab bar
- [x] MIS-2: Tabbed panel system (6 compiled ANSI screens)
- [x] MIS-3: Enhanced logging (timestamps, MANAGER prefix, slot format)

## Pending
- [ ] Engine consolidation (9 engines → fewer)
- [ ] ANSI editor extraction phases 3.1-3.6
- [ ] MIS 1.12 rebuild (6 phases — see docs/MIS-112-REBUILD.md)
- [ ] openwatcomirc compiler fork for pcbirc
- [ ] Password migration testing
- [ ] mterm remaining gaps (BUTTONS 42%, COVAI 9.8%)

## Low Priority
- [ ] Duplicate file consolidation (v3/prg = v4/prg, font inc dupes)
- [ ] RIPscrip v2/v3/v4 protocol testing
- [ ] Printer driver testing (ESC/P, PCL, PostScript)

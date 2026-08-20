# RIPscrip v4.0 Roadmap

## Completed

| Feature | Units | Status |
|---------|-------|--------|
| Unicode CP437↔UTF-8 | cp437u8, u8render, ttfglyph, rip4uni | ✅ Wired |
| TTF font loading | ttfglyph → TTFLoadFont/TTFFreeFont | ✅ Wired |
| Full-Motion Video | mpgdemux, mpgvdec, mpgvbuf, mpgplay, mpgstrm | ✅ Wired |
| FLI/FLC Animation | flidec (320x200 FLI + arbitrary FLC) | ✅ New |
| MIDI Synthesis | midsynth (FM, 32 voices) + midiplay + midistrm | ✅ From v3 |
| HTML 1.0 Parser | htmlpars (44 tags, entities, attributes) | ✅ 30 tests |
| HTML DOM Tree | htmltree (128 nodes, parent/child/sibling) | ✅ |
| HTML Layout | htmllayo (box model, text flow, margins) | ✅ |
| HTML → RIP | htmlrip (command translator) | ✅ |
| HTML → Pixels | htmlrend (direct renderer) | ✅ Tested |
| Print API | prnapi + prnbmp, prnescp, prnpcl, prnps, prnraw | ✅ 6 drivers registered |
| DOS 8.3 filenames | All 83 codec units renamed | ✅ 0 violations |

## Known Issues

- HTMLRenderToRIP: heap crash during Dispose (fpc264irc r3.1 bug, tracked)
- PrintPage: drivers registered, full pipeline needs testing with real devices
- MPEGRenderFrame: callback wiring needs full integration test

## Remaining

- [ ] RIPforge editor/viewer (rip4edit.pas)
- [ ] HTML extended features (FONT color, TABLE layout, FORM input, IMG loading)
- [ ] Full MPEG frame decode integration test
- [ ] Print driver testing with real devices
- [ ] v4-specific test expansion

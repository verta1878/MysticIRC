# RIPtel 3.1 Demo Corpus - RIPscrip 3.0 Script Census

Source: `/home/tracker1/src/rip-tools/artifacts/RIPtel/ICONS/` - 116 script files (.RIP .FN .DEF .MNU .MSE .RET .ENT .EXT .COL) shipped with RIPtel 3.1 'Visual Telnet' (TeleGrafix, (c) 1995-1997; driver RIPscrip 3.0.7). Parser: `parse_riptel.py` in this directory; raw data: `census.json`.

**Totals:** 22921 commands parsed (0 parse errors), 72 distinct (level, opcode) pairs, 1683 comment commands (305 with prose), 269 distinct `$...$` variables.

| Classification           | distinct opcodes |
| ------------------------ | ---------------- |
| known-1.54               | 35               |
| known-2.x                | 16               |
| 2.00a4-documented        | 7                |
| SyncTERM-descriptor-only | 3                |
| COMPLETELY NEW           | 11               |

## 1. Full opcode census

Levels: no digit = level 0; `1x` = level 1; `2x` = level 2. No level-3+ commands appear in the corpus. Coordinates are MegaNums (2-char base-36) after the ubiquitous `J10` prologue.

| Lvl | Cmd | Name (spec/reconstructed) | Class | Count | Files | Example args (trunc 60) |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | `"` | RIP_BOUNDED_TEXT (hypothesized name) | COMPLETELY NEW | 1 | 1: BOUNDS.RIP | `2020A03000This is just another` |
| 0 | `#` | RIP_NO_MORE | known-1.54 | 287 | 95: NEWS.RIP, BLUEBACK.FN, BUTTONS.RIP, CURVES.RIP, DEMO-01.COL… |  |
| 0 | `&` | RIP_SKEWED_OVAL | COMPLETELY NEW | 3 | 2: SHAPES.RIP, NEWCMDS.RIP | `20151G0M1M`; `W44W281810`; `VY4Q281810` |
| 0 | `*` | RIP_RESET_WINDOWS | known-1.54 | 31 | 31: BOUNDS.RIP, BUTTONS.RIP, CURVES.RIP, DRAGON.RIP, EAGLE.RIP… |  |
| 0 | `+` | RIP_SKEWED_OVAL_CHORD | COMPLETELY NEW | 6 | 2: SHAPES.RIP, NEWCMDS.RIP | `803F1G0M20601M`; `805P1G0M20601M`; `OWKG2818006O10` |
| 0 | `-` | RIP_FILLED_SKEWED_OVAL | COMPLETELY NEW | 12 | 8: SHAPES.RIP, NEWCMDS.RIP, TELCMDS.DEF, TELDEMOS.DEF, TELDRAW.DEF… | `203F1G0M1M`; `205P1G0M1M`; `W48S281810` |
| 0 | `;` | RIP_MARKER (hypothesized name) | COMPLETELY NEW | 361 | 2: MARKER2.RIP, MARKER.RIP | `1L40001S1S0000`; `4840011S1S0000`; `6T40021S1S0000` |
| 0 | `<` | RIP_POLY_POLYGON (hypothesized name) | COMPLETELY NEW | 3 | 1: POLYPOLY.RIP | `05041010701070701070034020606020600360208040405004201K901K90`; `0304A010D010D030A03003BM1ACU2UA62U04A615CU15CU25A625`; `0304E010H010H030E03003FM1AGU2 |
| 0 | `=` | RIP_LINE_STYLE | known-1.54 | 120 | 31: ONLINE.RIP, LANDSCPE.RIP, SEABYME1.RIP, N2_BUSI.RIP, SEANITE.RIP… | `001EKF03`; `00000001`; `00000003` |
| 0 | `@` | RIP_TEXT_XY | known-1.54 | 638 | 40: SHADOW.FN, FONTS.RIP, N2_BUSI.RIP, SPECLEFX.RIP, SHOWFONT.FN… | `1010Bounded Text Example`; `HS2ARIPscrip Buttons`; `OL55Label Orientation` |
| 0 | `B` | RIP_BAR | known-1.54 | 103 | 11: TWEATHER.RIP, N2_BUSI.RIP, N2_TITLE.RIP, NEWSPAPR.RIP, SHUTTLE.RIP… | `0000HS9Q`; `0100HO7B`; `0000HRDC` |
| 0 | `D` | RIP_SET_DRAWING_PALETTE | SyncTERM-descriptor-only | 1 | 1: BLUEFADE.FN | `0W0W8000000040008000C000G000K000O000S000W000a000e000i000m000` |
| 0 | `G` | RIP_FILLED_CIRCLE* | 2.00a4-documented | 16 | 1: POLYPOLY.RIP | `DM2020`; `DM201X`; `DM201U` |
| 0 | `J` | RIP_SET_BASE_MATH (actual wire opcode) | COMPLETELY NEW | 94 | 90: NEWS.RIP, ONLINE.RIP, SEANITE.RIP, TELPORT.FN, BLUEBACK.FN… | `10`; `10                   Set base math to MegaNums (base 36)` |
| 0 | `K` | RIP_FILLED_RECTANGLE | known-2.x | 163 | 13: BLUEFADE.FN, SEABYME1.RIP, SEANITE.RIP, DEMO-01.COL, SHAPES.RIP… | `0000ZLQP`; `0000HS05`; `0004HS09` |
| 0 | `L` | RIP_LINE | known-1.54 | 7574 | 23: SHUTTLE.RIP, SAILBOAT.RIP, FOUND.RIP, SPACSHUT.RIP, HAWK.RIP… | `1C2J1H2K`; `1W2O2C2X`; `1U2Q282V` |
| 0 | `M` | RIP_SET_COLOR_MODE* | 2.00a4-documented | 94 | 90: NEWS.RIP, ONLINE.RIP, SEANITE.RIP, TELPORT.FN, BLUEBACK.FN… | `08`; `8` |
| 0 | `N` | RIP_SET_BORDER | known-2.x | 122 | 23: SHAPES.RIP, NEWCMDS.RIP, ONLINE.RIP, SEANITE.RIP, POLYGONS.RIP… | `00`; `01` |
| 0 | `O` | RIP_OVAL | known-1.54 | 6 | 4: SEABYME1.RIP, SHAPES.RIP, LANDSCPE.RIP, SEANITE.RIP | `1NLT00A00505`; `8S6400A01A1C`; `1GK400A00604` |
| 0 | `P` | RIP_POLYGON | known-1.54 | 4 | 2: POLYGONS.RIP, SHAPES.RIP | `0CLQ72PM72PM9AOI86OIC2PMAYPMD6LQD6LQAYMUC2MU86LQ9A`; `0CLK6WPG6WPG94OC80OCBWPGASPGD0LKD0LKASMOBWMO80LK94`; `0A1CF86CF858GC6CHG6CI03KI03KGW2GGW2GI01CI |
| 0 | `R` | RIP_RECTANGLE | known-1.54 | 108 | 12: TWEATHER.RIP, N2_BUSI.RIP, N2_TITLE.RIP, NEWSPAPR.RIP, SEABYME1.RIP… | `2020A030`; `0M082VW`; `2X1RGJ52` |
| 0 | `S` | RIP_FILL_STYLE | known-1.54 | 777 | 36: MARKER2.RIP, TUNNEL.RIP, SEANITE.RIP, SHAPES.RIP, LANDSCPE.RIP… | `010W`; `010X`; `010Y` |
| 0 | `U` | RIP_ROUNDED_RECT* | 2.00a4-documented | 2 | 1: SHAPES.RIP | `8K3KDK6C0K`; `8C3CDC640K` |
| 0 | `V` | RIP_OVAL_ARC | known-1.54 | 2 | 1: SHAPES.RIP | `OY4Y006O2I1E`; `OQ4Q006N2I1E` |
| 0 | `W` | RIP_WRITE_MODE | known-1.54 | 44 | 35: NEWS.RIP, SEANITE.RIP, EAGLE.RIP, HAWK.RIP, ONLINE.RIP… | `00`; `03`; `.` |
| 0 | `X` | RIP_PIXEL | known-1.54 | 7 | 2: LANDSCPE.RIP, EAGLE.RIP | `0032`; `003E`; `1B2H` |
| 0 | `Y` | RIP_FONT_STYLE | known-1.54 | 23 | 12: FONTS.RIP, DBACK.FN, DRAGON.RIP, EAGLE.RIP, HAWK.RIP… | `02000909`; `00000100`; `0000034H` |
| 0 | `Z` | RIP_BEZIER | known-1.54 | 22 | 4: LANDSCPE.RIP, ONLINE.RIP, SEABYME1.RIP, SEANITE.RIP | `CSIYDBIYDVIZEEJ014`; `D8IYDSJ1EYJ8FAJE14`; `RIGSS0GUSCGQSUGW14` |
| 0 | `[` | RIP_SKEWED_OVAL_PIE_SLICE | COMPLETELY NEW | 6 | 2: SHAPES.RIP, NEWCMDS.RIP | `503F1G0M20601M`; `505P1G0M20601M`; `W4KG2818006O10` |
| 0 | `]` | RIP_SKEWED_OVAL_ARC | COMPLETELY NEW | 3 | 2: SHAPES.RIP, NEWCMDS.RIP | `50151G0M20601M`; `W4GK2818006O10`; `VYGE2818006O10` |
| 0 | `_` | RIP_FILLED_OVAL_CHORD | COMPLETELY NEW | 6 | 2: SHAPES.RIP, NEWCMDS.RIP | `B03F90601G0M`; `B05P90601G0M`; `HYKG006O2818` |
| 0 | `a` | RIP_ONE_PALETTE | known-1.54 | 7 | 2: LANDSCPE.RIP, LGF1.RIP | `0202`; `060K`; `0B1N` |
| 0 | `c` | RIP_COLOR | known-1.54 | 359 | 49: SHAPES.RIP, ONLINE.RIP, LANDSCPE.RIP, N2_BUSI.RIP, N2_HORO.RIP… | `0F`; `09`; `0E` |
| 0 | `d` | RIP_ONE_DRAWING_PALETTE* | 2.00a4-documented | 65 | 1: TUNNEL.RIP | `0W80000`; `0X80004`; `0Y80008` |
| 0 | `f` | RIP_SET_WORLD_FRAME | known-2.x | 151 | 103: N2_BUSI.RIP, POLYPOLY.RIP, ONLINE.RIP, BUTTONS.RIP, CURVES.RIP… | `ZKQO`; `HSDC`; `HR9S` |
| 0 | `i` | RIP_OVAL_PIE_SLICE | known-1.54 | 4 | 1: SHAPES.RIP | `OY8U006O2I1E`; `OQ8M006N2I1E`; `OYCQ006O2I1E` |
| 0 | `j` | RIP_POINT (2.x) | known-2.x | 8 | 2: SEABYME1.RIP, SEANITE.RIP | `NK62`; `JQ94`; `3I8A` |
| 0 | `k` | RIP_BACK_COLOR* | 2.00a4-documented | 229 | 41: SHAPES.RIP, BLUEFADE.FN, SHADOW.FN, SEABYME1.RIP, SEANITE.RIP… | `00`; `0W`; `0X` |
| 0 | `l` | RIP_POLYLINE | known-1.54 | 6 | 3: N2_TITLE.RIP, NEWSPAPR.RIP, SHAPES.RIP | `0E0A20462046244B244B9G469G469K0A9K0A9G059G05240A240A200A20`; `0D9Q6GHD6GHD6KHI6KHI9GHD9GHD9K9Q9K9Q9G9L9G9L6K9Q6K9Q6G`; `0D9Q6CHD6CHD6GHI6GHI9GHD9GHD9 |
| 0 | `n` | RIP_SET_COORDINATE_SIZE* | 2.00a4-documented | 94 | 90: NEWS.RIP, ONLINE.RIP, SEANITE.RIP, TELPORT.FN, BLUEBACK.FN… | `2000`; `2`; `2.` |
| 0 | `o` | RIP_FILLED_OVAL | known-1.54 | 153 | 9: N2_BUSI.RIP, TUNNEL.RIP, ONLINE.RIP, SHAPES.RIP, TWEATHER.RIP… | `CH5V0201`; `332T021`; `392U021` |
| 0 | `p` | RIP_FILLED_POLYGON | known-1.54 | 228 | 13: LANDSCPE.RIP, POLYGONS.RIP, LGF1.RIP, EAGLE.RIP, TWEATHER.RIP… | `1F0000006J1G62106R1Q651C6U26691V6V2M6C2L6Z306E32733F6G3K773R`; `08006K1F631V5H2F4Y354D2Y46174I004W`; `080000003A2N1Z2W1L331I411751114M00` |
| 0 | `s` | RIP_FILL_PATTERN | known-1.54 | 69 | 5: BLUEFADE.FN, TWEATHER.RIP, BLUEBACK.FN, EAGLE.RIP, SAILBOAT.RIP | `4Q2D4Q2D4Q2D4Q2D01`; `3S0Y3S0Y3S0Y3S0Y0X`; `4Q2D4Q2D4Q2D4Q2D0X` |
| 0 | `t` | RIP_POLY_BEZIER_LINE | known-2.x | 12 | 3: ONLINE.RIP, CURVES.RIP, SHAPES.RIP | `03142JA62HA62JEA66HUA6JGA6HCEE0JCEG`; `03142J45YH45YJ8A26HOA2JAA2H6EA0J6EC`; `0414228BU2UDC40DY55SEU74FI8EGS59GHS9WI7A2J00A0JO` |
| 0 | `u` | RIP_FILLED_ROUNDED_RECT* | 2.00a4-documented | 4 | 1: SHAPES.RIP | `8K7GDKA80K`; `8C78DCA00K`; `8KBCDKE40K` |
| 0 | `v` | RIP_VIEWPORT | known-1.54 | 3 | 1: IMAGES.RIP | `1EB5GUIC`; `IIB5XYIC`; `0000ZKQO` |
| 0 | `w` | RIP_TEXT_WINDOW | known-1.54 | 14 | 14: DRAGON.RIP, EAGLE.RIP, HAWK.RIP, LGF1.RIP, MARKER.RIP… | `0000000000`; `0010271610`; `010X1B1410` |
| 0 | `x` | RIP_FILLED_POLY_BEZIER | known-2.x | 182 | 6: SEANITE.RIP, SEABYME1.RIP, LANDSCPE.RIP, CURVES.RIP, SHAPES.RIP… | `061451AA8026T2Q4E56Y4Q9D4X7S6C5E85QFX5KI6925EGAUCFBT9OB8088D`; `061451NA20H6Y2Z4R56Y5297597Q6J5DR5ZFC5THG905DYAMC2BI9HAZ085D`; `061451Y9S0U73375656Z5 |
| 0 | `y` | RIP_EXTENDED_FONT_STYLE | SyncTERM-descriptor-only | 430 | 42: SHADOW.FN, FONTS.RIP, SHOWFONT.FN, N2_BUSI.RIP, N2_TITLE.RIP… | `0000010P000000001a1a000000Marin`; `0000BW1Q080000001a1a000000Marin`; `0000BW0o040000001a1a000000Marin` |
| 0 | `z` | RIP_POLY_BEZIER | known-2.x | 2 | 1: SHAPES.RIP | `081428KGC8KESASF85CGF8E4F8BCGC5DKGCEOGCE4GW5DKHGD0I0BWI06ASI`; `081428CG48CEKAKF05C8F0DWF0B4G45DCG4EGG4DWGO5DCH8CSHSBOHS6AKH` |
| 1 | `<ESC>` | RIP_QUERY | known-1.54 | 489 | 62: SHADOW.FN, TELCMDS.DEF, MENU.DEF, SPECLEFX.RIP, TELQUEST.DEF… | `0000$COFF$$DTW$`; `0000$COMPAT$`; `0000$DTW$` |
| 1 | `A` | Unknown - text-flow settings? (single occurrence) | SyncTERM-descriptor-only | 1 | 1: NEWS.RIP | `010000` |
| 1 | `B` | RIP_BUTTON_STYLE | known-1.54 | 47 | 18: BUTTONS.RIP, FONTS.RIP, SPECLEFX.RIP, NEWS.RIP, SHOWFONT.RIP… | `0000020PVS080F000F080700000F07000000`; `00000207QQ040F000B010900060E09000000`; `00000209BK010F000B010900040E09000000` |
| 1 | `C` | RIP_GET_IMAGE | known-1.54 | 4 | 1: LANDSCPE.RIP | `EM6XFZ7U0`; `EO6XG07K0`; `EM6XFZ7W0` |
| 1 | `E` | RIP_END_TEXT | known-1.54 | 20 | 8: N2_TITLE.RIP, NEWSPAPR.RIP, DEMO-01.COL, DEMO-02.COL, DRAGON.RIP… |  |
| 1 | `K` | RIP_KILL_MOUSE_FIELDS | known-1.54 | 8 | 8: DEMO-01.COL, DEMO-02.COL, EAGLE.RIP, FONTTEXT.COL, HAWK.RIP… |  |
| 1 | `M` | RIP_MOUSE | known-1.54 | 100 | 31: DEMO-01.COL, DEMO-02.COL, NEWSPAPR.RIP, TEL3X3.MSE, MENU.MSE… | `00VT0QYY1R1000000<<if $RETURN$!="">>$<<RETURN>>$<<else>>$NUL`; `000G7Y8ICC1000000ID=2:$-=RETURN=>NEWSPAPR.RIP$$>TWEATHER.RIP`; `000GCG8GGU1000000ID=3 |
| 1 | `P` | RIP_PUT_IMAGE | known-1.54 | 1 | 1: NEWSPAPR.RIP | `V4OM000` |
| 1 | `R` | RIP_READ_SCENE | known-1.54 | 92 | 34: SHADMOVE.RIP, MENU.RET, TELCMDS.FN, TELCMDS.RET, TELDEMOS.FN… | `00000000<<IF $COLORS$<"256">>BLUEBACK.FN<<ELSE>>BLUEFADE.FN<`; `00000000$OVERFLOW(1,CUR)$`; `00000000$overflow(1,cur)$` |
| 1 | `T` | RIP_BEGIN_TEXT | known-1.54 | 12 | 2: N2_TITLE.RIP, NEWS.RIP | `0F3M434G00`; `0F58426600`; `0F6V427Q00` |
| 1 | `U` | RIP_BUTTON | known-1.54 | 75 | 17: BUTTONS.RIP, SHOWFONT.RIP, TELLISTS.MNU, IMAGES.RIP, FONTS.RIP… | `144KDNC80000<><>`; `2E5O747G2000<>Hotkeys<>`; `7S5OCI7G2000<>Hotkeys<>` |
| 1 | `b` | RIP_LOAD_BITMAP | known-2.x | 69 | 28: TEL3X3.MNU, MENU.MNU, IMAGES.RIP, TEL3X2.MNU, DBACK.FN… | `VU0QYY1S0000000000back.bmp`; `0000HS0Y000G000000STRIP6.BMP`; `561EFH6L0008000000GODRAG3.BMP` |
| 1 | `c` | RIP_SET_MOUSE_CURSOR | known-2.x | 2 | 1: FXSHWIMG.FN | `06`; `00` |
| 1 | `e` | RIP_EXTENDED_BEGIN_TEXT / text-column region (new) | COMPLETELY NEW | 21 | 8: NEWSPAPR.RIP, DEMO-01.COL, N2_HORO.RIP, DBACK.FN, DRAGON.RIP… | `3W7DGRMD0100010000000000`; `LP7DYKMD1100010000000000`; `4L3D919K0100010000000000` |
| 1 | `g` | RIP_COPY_BLIT | known-2.x | 88 | 6: DL.FN, DR.FN, WIPE00.FN, WIPE01.FN, WIPE02.FN… | `0000XCQO280000`; `2800ZKQO000000`; `0000ZKOG00280` |
| 1 | `i` | RIP_IMAGE_STYLE | known-2.x | 13 | 6: N2_PHOTO.RIP, N2_TITLE.RIP, NEWSPAPR.RIP, FXSHWIMG.FN, IMAGES.RIP… | `00009F6Q0004`; `1E4I80940004000000000000`; `1O1Z825M0000000000000000` |
| 1 | `p` | RIP_IMAGE | known-2.x | 13 | 6: N2_PHOTO.RIP, N2_TITLE.RIP, NEWSPAPR.RIP, FXSHWIMG.FN, IMAGES.RIP… | `0000<<IF $INUSE(TV,NEXT_IMG)$="0">>$-=NEXT_IMG=ASTRO.JPG$<<E`; `0000BRIDGE02.JPG`; `0000BEACH2.JPG` |
| 1 | `t` | RIP_REGION_TEXT | known-1.54 | 42 | 1: N2_TITLE.RIP | `1Southern California was pounded`; `1with nearly two weeks of rain.`; `1Hundreds left homeless as a result.` |
| 2 | `C` | RIP_PORT_COPY | known-2.x | 9104 | 46: WIPE19.FN, WIPE20.FN, WIPE12.FN, WIPE15.FN, WIPE16.FN… | `1XC00ZKQO0000028QO0`; `1V400XCQO0000028QO0`; `1SW00V4QO0000028QO0` |
| 2 | `P` | RIP_DEFINE_PORT | known-2.x | 14 | 12: SHADOW.FN, SPECLEFX.RIP, DBACK.FN, DRAGON.RIP, FONTS.RIP… | `10000ZKQO00030000`; `10000ZK7200010000`; `100009F6Q0001` |
| 2 | `p` | RIP_DELETE_PORT | known-2.x | 12 | 12: DL.FN, DR.FN, DRAGON.RIP, FONTS.RIP, FXSHWIMG.FN… | `1000`; `00`; `0000` |
| 2 | `s` | RIP_SWITCH_PORT | known-2.x | 35 | 31: FXSHWIMG.FN, SHADOW.FN, SPECLEFX.RIP, DBACK.FN, DRAGON.RIP… | `002`; `100`; `000` |

Absent but expected: level-1 `w` (PLAY_AUDIO - no audio files ship with the demo), `F` (FILE_QUERY), `D` (DEFINE), `I`/`W` (icon load/write - no .ICN files), level-2 `W R B E A T Y`, all level-3/9, and SyncTERM descriptor-only `0<ESC>`, `1O`, `1N`, `1S`.

## 2. COMPLETELY NEW / previously-unidentified opcodes

NEWCMDS.RIP is a Rosetta stone: its comments name six new level-0 drawing primitives outright.

### `0|&` - RIP_SKEWED_OVAL

- Occurrences: 3 in 2 file(s): SHAPES.RIP, NEWCMDS.RIP
- Examples: `20151G0M1M`; `W44W281810`; `VY4Q281810`
- Named explicitly in NEWCMDS.RIP comment. Args (5x meganum-pair): x, y, x_rad, y_rad, rotation. Ex `&W44W281810`.

### `0|-` - RIP_FILLED_SKEWED_OVAL

- Occurrences: 12 in 8 file(s): SHAPES.RIP, NEWCMDS.RIP, TELCMDS.DEF, TELDEMOS.DEF, TELDRAW.DEF
- Examples: `203F1G0M1M`; `205P1G0M1M`; `W48S281810`
- Named explicitly in NEWCMDS.RIP. Same 5-field args as `&`; honors RIP_SET_BORDER (`N01`/`N00` with/without border demos). NOTE: only the 6 uses in SHAPES.RIP (4) and NEWCMDS.RIP (2) are genuine; the other 6 occurrences (TELCMDS/TELDEMOS/TELDRAW/TELENGIN/TELQUEST.DEF and TELLISTS.MNU, 1 each) are authoring typos - `!|-----` separator comments missing the `!` - which the shipping driver evidently tolerates.

### `0|]` - RIP_SKEWED_OVAL_ARC

- Occurrences: 3 in 2 file(s): SHAPES.RIP, NEWCMDS.RIP
- Examples: `50151G0M20601M`; `W4GK2818006O10`; `VYGE2818006O10`
- Named explicitly in NEWCMDS.RIP. Args (7x 2#): x, y, x_rad, y_rad, start_ang, end_ang, rotation. Ex `]50151G0M20601M`.

### `0|[` - RIP_SKEWED_OVAL_PIE_SLICE

- Occurrences: 6 in 2 file(s): SHAPES.RIP, NEWCMDS.RIP
- Examples: `503F1G0M20601M`; `505P1G0M20601M`; `W4KG2818006O10`
- Named explicitly in NEWCMDS.RIP. Same 7-field args as `]`; border controlled by `N`.

### `0|+` - RIP_SKEWED_OVAL_CHORD

- Occurrences: 6 in 2 file(s): SHAPES.RIP, NEWCMDS.RIP
- Examples: `803F1G0M20601M`; `805P1G0M20601M`; `OWKG2818006O10`
- Named explicitly in NEWCMDS.RIP. Same 7-field args as `]`; draws/fills the chord segment.

### `0|_` - RIP_FILLED_OVAL_CHORD

- Occurrences: 6 in 2 file(s): SHAPES.RIP, NEWCMDS.RIP
- Examples: `B03F90601G0M`; `B05P90601G0M`; `HYKG006O2818`
- Named explicitly in NEWCMDS.RIP (note: not 'skewed'). Args (6x 2#): x, y, start_ang, end_ang, x_rad, y_rad - angle pair comes BEFORE radii here, and no rotation field. Ex `_B03F90601G0M`.

### `0|"` - RIP_BOUNDED_TEXT (hypothesized name)

- Occurrences: 1 in 1 file(s): BOUNDS.RIP
- Examples: `2020A03000This is just another`
- BOUNDS.RIP comment: 'Show the bounded text command', drawn immediately after a same-coordinate `R2020A030` rectangle labeled 'Show our bounding box'. Args: x0 y0 x1 y1 (2# each) + 2-digit flags + text; text wraps/clips inside the box. Ex `"2020A03000This is just another...`.

### `0|;` - RIP_MARKER (hypothesized name)

- Occurrences: 361 in 2 file(s): MARKER2.RIP, MARKER.RIP
- Examples: `1L40001S1S0000`; `4840011S1S0000`; `6T40021S1S0000`
- MARKER.RIP title text: 'RIPscrip Markers'. 14-char args = 7x 2#: x, y, marker_type (00-0C row 1, 0E.. in MARKER2), x_size, y_size, then 4 more digits (rotation 2# + flags 2#? - `0000`, `0003`, `8C03` observed). Draws predefined marker/symbol glyphs at a point using current fill style; MARKER2.RIP cycles fill colors S010G..S010V per marker.

### `0|<` - RIP_POLY_POLYGON (hypothesized name)

- Occurrences: 3 in 1 file(s): POLYPOLY.RIP
- Examples: `05041010701070701070034020606020600360208040405004201K901K90`; `0304A010D010D030A03003BM1ACU2UA62U04A615CU15CU25A625`; `0304E010H010H030E03003FM1AGU2UE62U04E615GU15GU25E625`
- POLYPOLY.RIP title '@1009RIP_POLY_POLYGON' and comments 'Show a couple of poly-polygons with and without borders'. Args: npoly (2#) then per-polygon [nverts (2#) + nverts x (x,y)]. Multi-contour polygon with even-odd fill (demo shows transparency through the holes); border via `N`. Ex `<0504101070...` = 5 contours.

### `0|J` - RIP_SET_BASE_MATH (actual wire opcode)

- Occurrences: 94 in 90 file(s): NEWS.RIP, ONLINE.RIP, SEANITE.RIP, TELPORT.FN, BLUEBACK.FN
- Examples: `10`; `10                   Set base math to MegaNums (base 36)`
- In 90/116 files as the standard prologue `J10|n2000|M08|fZKQO`. ONLINE.RIP carries inline comment 'Set base math to MegaNums (base 36)' after `J10` - arg `10` = 36 in base-36. The 2.00a4 spec draft lists SET_BASE_MATH as level-0 `b`, which collides with EXTENDED_TEXT_WINDOW; the shipping 3.0 driver evidently moved it to `J`.

### `1|e` - RIP_EXTENDED_BEGIN_TEXT / text-column region (new)

- Occurrences: 21 in 8 file(s): NEWSPAPR.RIP, DEMO-01.COL, N2_HORO.RIP, DBACK.FN, DRAGON.RIP
- Examples: `3W7DGRMD0100010000000000`; `LP7DYKMD1100010000000000`; `4L3D919K0100010000000000`
- FONTS.RIP carries the field map comment `!|! xxyyxxyycaffffccrrrrrrrr`: x0 y0 x1 y1 (2# each), c=column#, a=article/stream#, ffff=flags, cc=?, rrrrrrrr=reserved. Opens a flowed-text column region; raw text lines (or `1R` reads of .TXT/$OVERFLOW()$/$&VAR$ content) follow, terminated by `1E` (RIP_END_TEXT). Multi-column chains use c=0,1,2 with same stream (`01`,`11`,`21` in DBACK.FN/DEMO-01.COL); overflow pages retrieved via `$overflow(stream,prev|next|cur[,setverbose])$` and `$RESET(OVERFLOW)$`. This is the 'powerful column system' FONTSTOR.TXT advertises.

### `1|A` - Unknown - text-flow settings? (single occurrence)

- Occurrences: 1 in 1 file(s): NEWS.RIP
- Examples: `010000`
- Only `1A010000` in NEWS.RIP, issued right before building the flowed newspaper article (between a divider line `L` and the `1T...01/11/21/31` linked text columns). 6-digit args = 3x 2#. SyncTERM's descriptor says 7 words ('2#'x7), which does NOT match the observed 6 chars. Plausibly justification/hyphenation settings for the text-flow system (e.g. justify=01).

### Notes on descriptor-only / spec-name confirmations

- `0|y`: RIP_EXTENDED_FONT_STYLE - heavily used (430x). Confirms 2.00a4 name; args much richer than SyncTERM's 4-word descriptor: 26 chars + font name, e.g. `y0000BW1Q080000001a1a000000Marin`. FONTS.RIP line 114 carries the authoritative field map comment `!|!sfFFFFZZOOSSCCBBCCWWRRRRRR` = s(1) f(1) FFFF(4 flags) ZZ(2 size) OO(2 orientation) SS CC BB CC WW (2 each) RRRRRR(6 reserved); the rotation demo varies the SS field (`00`->`E4`/`gC`) with per-line labels '0 x 0', '180 x 90', '180 x 270' etc. covering all 16 char-x-text rotation combos. Fields include size/scale (`1a1a` ~ x/y scale), style flags (bold/dropshadow per TELLISTS.MNU inline comment 'Marin, centered, bold w/ dropshadow'), rotation (16 orientations per FONTSTOR.TXT). Scalable outline fonts seen: Marin, Dixon, Symbol, Cobb (+ family suffixes ' TH' thin, ' CN' condensed, ' WD' wide, ' EX' expanded, ' HO' hollow, ' HT', ' HC', ' HW', ' HE'). Font name can be a variable: `...000000$&FONT_NAME$`.
- `0|D`: RIP_SET_DRAWING_PALETTE - single use in BLUEFADE.FN: `D0W0W8000000040008000...` sets a long run of 256-color palette entries for the faded background.
- `0|<ESC>`: not observed in corpus (level-0 ESC).

## 3. Text variables ($...$)

269 distinct forms. Syntax families observed:

| Form | Distinct | Meaning | Examples |
| --- | --- | --- | --- |
| `$NAME$` | 81 | predefined/system or user variable read | `$COLORS$` `$COMPAT$` `$DTW$` `$COFF$` `$SBAROFF$` `$RESET$` `$NULL$` `$RETURN$` |
| `$FUNC(args)$` | 23 | parameterized variable/function | `$D(1)$` (delay, 197 uses) `$MCURSOR(0)$` `$RESET(OVERFLOW)$` `$RESET(PAL)$` `$overflow(1,next,setverbose)$` `$GOTOURL(WEBURL)$` `$INUSE(TV,NEXT_IMG)$` |
| `$-=NAME=value$` | 122 | set user variable (2.x `-=` set form) | `$-=RETURN=>NEWSPAPR.RIP$` `$-=WEBURL=http://...$` `$-=TITLE=Telnet Site Listings$` |
| `$>file$` | 34 | local file playback (2.x documented) | `$>newspapr.rip$` `$>demo-01.col$` `$>WIPE00.FN$` |
| `$&NAME$` | 9 | NEW: interpolate user variable value inline in command args | `$&FONT_NAME$` (as font-name arg of `y`), `$&MAIN_STORY$` (as filename of `1R`), `$&MSG<<FIELDID>>$` |

Top 20 by count:

- 197 `$D(1)$` (e.g. SHADOW.FN: 1<ESC>0000$D(1)$)
- 41 `$NULL$` (e.g. BUTTONS.RIP: 1M00VT0QYY1R1000000<<if $RETURN$!="">>$<<RETURN>>$<<else>>$NULL$<<endi)
- 22 `$RETURN$` (e.g. BUTTONS.RIP: 1M00VT0QYY1R1000000<<if $RETURN$!="">>$<<RETURN>>$<<else>>$NULL$<<endi)
- 22 `$<<RETURN>>$` (e.g. BUTTONS.RIP: 1M00VT0QYY1R1000000<<if $RETURN$!="">>$<<RETURN>>$<<else>>$NULL$<<endi)
- 21 `$COMPAT$` (e.g. BLUEBACK.FN: 1<ESC>0000$COMPAT$)
- 21 `$&FONT_NAME$` (e.g. SHOWFONT.FN: @I064$&FONT_NAME$:)
- 20 `$MCURSOR(0)$` (e.g. DEMO-01.COL: 1<ESC>6000$MCURSOR(0)$)
- 16 `$NO_WIPES$` (e.g. TELDEMOS.RET: 1<ESC>0000<<IF $NO_WIPES$="" OR $NO_WIPES$="NONE">>$>TELPORT.FN$<<ELSE>>$R)
- 15 `$COLORS$` (e.g. BUTTONS.RIP: 1R00000000<<IF $COLORS$<"256">>BLUEBACK.FN<<ELSE>>BLUEFADE.FN<<ENDIF>>)
- 15 `$TGMENU_WIPES$` (e.g. MENU.RET: 1<ESC>0000<<IF $TGMENU_WIPES$="1">>$>WIPE01.FN$<<else>>$NULL$<<ENDIF>>)
- 14 `$DTW$` (e.g. BLUEBACK.FN: 1<ESC>0000$COFF$$DTW$)
- 13 `$MCURSOR(6)$` (e.g. MENU.FN: 1<ESC>0000$MCURSOR(6)$)
- 10 `$>newspapr.rip$` (e.g. DEMO-01.COL: 1M00XWG0YYH01000000ID=8:$>newspapr.rip$)
- 8 `$GOTOURL(WEBURL)$` (e.g. TELLISTS.MSE: 1M000ZACBSE41000000ID=1:$-=WEBURL=http://duke.usask.ca/~scottp/free.ht)
- 7 `$MCURSOR(4)$` (e.g. DEMO-01.COL: 1<ESC>5000$MCURSOR(4)$)
- 7 `$SBAROFF$` (e.g. DRAGON.RIP: 1<ESC>0000$SBAROFF$)
- 6 `$dtw$` (e.g. CURVES.RIP: 1<ESC>0000$dtw$)
- 6 `$>demo-01.col$` (e.g. DEMO-01.COL: 1M00VWG0WUH01000000ID=6:$overflow(1,prev,setverbose)$$>demo-01.col$)
- 6 `$>demo-02.col$` (e.g. DEMO-01.COL: 1M00V4OMW4PM1000000ID=9:$overflow(2,prev,setverbose)$$>demo-02.col$)
- 6 `$>WIPE00.FN$` (e.g. TELCMDS.FN: 1<ESC>0000<<IF $TGMENU_WIPES$="1">>$>WIPE00.FN$<<else>>$NULL$<<ENDIF>>)

### New-in-3.0 variable machinery (not in 2.00a4 spec)

- `$GOTOURL(var)$` - launches a web URL held in a user variable; TELLISTS.MNU wires mouse fields: `1M00...ID=1:$-=WEBURL=http://duke.usask.ca/~scottp/free.html$$GOTOURL(WEBURL)$` (1997 web integration).
- `$overflow(stream, cur|next|prev [,setverbose])$` and `$RESET(OVERFLOW)$` - paging through overflow files produced by the flowed-text column system (used as `1R` read-scene filenames).
- `$&NAME$` dereference form (see table).
- `$INUSE(port,var)$` - tested in `<<IF>>` conditionals (N2_PHOTO.RIP image cycling).
- `<<NAME>>` macro expansion inside args and inside `$...$`: `$<<RETURN>>$`, `$<<CMD1>>$`, `@809U<<LAB1>>` - RIPtel-side template substitution (menu labels/commands injected from .DEF configuration).
- `<<IF expr>> ... <<ELSE>> ... <<ENDIF>>` inline conditionals, evaluated before command execution: `1R00000000<<IF $COLORS$<"256">>BLUEBACK.FN<<ELSE>>BLUEFADE.FN<<ENDIF>>` and `1M...<<if $RETURN$!="">>$<<RETURN>>$<<else>>$NULL$<<endif>>` (case-insensitive).
- `ID=n:` prefix on RIP_MOUSE host commands - numbered mouse-field identity (`1M00...1000000ID=2:$>...$`).

## 4. Comment listing (TeleGrafix's own annotations, grouped by file)

Decorative divider-only comments (dashes/blank) omitted; 305 prose comments total.

### BLUEBACK.FN

- S0101

### BOUNDS.RIP

- Show our bounding box
- Show the bounded text command

### BUTTONS.RIP

- Display the blue faded background on 256 colors+, else solid blue

### CURVES.RIP

- Display the blue faded background on 256 colors+, else solid blue

### FONTS.RIP

- Display the blue faded background on 256 colors+, else solid blue
- Create a port for the status line backup area, and copy the area where
- the status line will go into that drawing port.
- Make sure port #1 is deleted
- Define port #1
- Copy the screen image to the port
- xxyyxxyycaffffccrrrrrrrr
- sfFFFFZZOOSSCCBBCCWWRRRRRR
- 0 x 0
- 180 x 90
- 180 x 270
- 0 x 180
- 180 x 0
- 180 x 180
- 180 x 90
- 180 x 270
- 90 x 0
- 90 x 180
- 90 x 90
- 90 x 270
- 270 x 90
- 270 x 270
- 270 x 0
- 270 x 180

### FONTTEXT.COL

- K0U2WYZA8
- Copy the screen image to the port

### IMAGES.RIP

- Display the blue faded background on 256 colors+, else solid blue

### MAKEPORT.FN

- Set 2 byte X/Y coordinates
- Set color palette mode
- Delete all ports (screen is unaffected)
- Create port #1 to be full screen sized

### MARKER.RIP

- Display the blue faded background on 256 colors+, else solid blue
- ;WW200C1S1S0000

### MENU.DEF

- Define the button labels used in our 3x3 button menu
- Define the text variables commands that are executed when one of these
- nine buttons are selected
- Define the status messages displayed when the user hovers over one of
- the mouse fields on the screen

### MENU.ENT

- Paste original screen image back

### MENU.EXT

- Paste original screen image back

### MENU.FN

- Reset the screen environment
- Display the blue faded background on 256 colors+, else solid blue
- Define the variables for the main menu
- Show the menu itself
- Define the mouse fields

### MENU.MNU

- Show the nine button images. We'll put the mouse fields over them at
- the bottom of this script.
- Show the "unregistered version" notice button at the bottom

### MENU.MSE

- Create the mouse fields over top of the button images
- Create a port for the status line backup area, and copy the area where
- the status line will go into that drawing port.
- Make sure port #1 is deleted
- Define port #1
- Copy the screen image to the port
- Setup our mouse entry/exit queries to do our status line, and mouse
- cursor changing.

### MENU.RET

- Kill all mouse fields and queries
- Create full-screen drawing port with blue fade
- Define the variables for the main menu
- Show the main menu
- Wipe off the screen image if setup says so, and show the new one
- Create the mouse fields for the main menu

### N2_HORO.RIP

- END OF FILE

### N2_TITLE.RIP

- 1t1be transmitted over any online service that
- 1t1can transmit text. That is over 99.9% of
- 1t1the online community. This makes
- 1t1it perfectly suited for the Internet
- 1t1and the nearly 100,000 BBS systems
- 1t1throughout the world servicing
- 1t0millions of computer users.
- 1t1 With the addition of JPEG images,
- 1t1digitized sound, 24-bit color, and a
- 1t1high-tech font system, RIPscrip has
- 1t1the means to launch the online world
- 1t0into the 21st century.

### NEWCMDS.RIP

- Reset the screen
- Setup the fill color (blue)
- Solid line 1 pixel wide
- Show our grid (center points)
- Show horizontal lines first
- Now show the vertical lines
- Change settings for subsequent example figures
- Set color to white
- Solid line 3 pixel wide
- Show RIP_SKEWED_OVAL
- Show RIP_FILLED_SKEWED_OVAL
- With a border
- Without a border
- Show a RIP_SKEWED_OVAL_ARC
- Show a RIP_SKEWED_OVAL_PIE_SLICE
- With a border
- Without a border
- Show a RIP_SKEWED_OVAL_CHORD
- With a border
- Without a border
- Show a RIP_FILLED_OVAL_CHORD
- With a border
- Without a border
- All done

### NEWPORT.FN

- Make sure port #1 is deleted before continuing
- Create the port the full size of the screen
- Switch to port 1

### NEWSPAPR.RIP

- Change these to the values you want for your content
- Name of this RIP file
- Filename containing main story
- Author of main story
- Filename containing secondary story
- Author of secondary story
- Reset all overflow files

### ONLINE.RIP

- Display the blue faded background on 256 colors+, else solid blue
- L020000PQ
- L0002ZE00
- LZI00ZIPO

### POLYGONS.RIP

- Display the blue faded background on 256 colors+, else solid blue

### POLYPOLY.RIP

- Display the blue faded background on 256 colors+, else solid blue
- Setup the fill color (blue)
- Set color to light gray
- Solid line 3 pixel wide
- Set color to yellow
- Put in a colored circle so you can see the transparency aspect
- Setup the fill color (blue)
- Show a couple of poly-polygons with and without borders
- With borders:
- Without borders:
- Now put in some description

### SHADMOVE.RIP

- Assign what our title text should be
- Define our colors (foreground and background)

### SHAPES.RIP

- Display the blue faded background on 256 colors+, else solid blue

### SHOWFONT.FN

- wwhhooffffssffbbBBddssgg22uuccprrrrr
- wwhhooffffssffbbBBddssgg22uuccprrrrr

### SHOWFONT.RIP

- Display the blue faded background on 256 colors+, else solid blue
- wwhhooffffssffbbBBddssgg22uuccprrrrr

### SPECLEFX.RIP

- Display the blue faded background on 256 colors+, else solid blue
- 1i2K5KBZCB0004
- 1p0000<<IF $INUSE(TV,NEXT_IMG)$="0">>$-=NEXT_IMG=ASTRO.JPG$<<ENDIF>>$&NEXT_IMG$

### TEL3X2.ENT

- Paste original screen image back

### TEL3X2.EXT

- Paste original screen image back

### TEL3X2.MNU

- Draw the title at the top of the screen
- Foreground color yellow
- Background color a darkish brown/gold
- Marin, centered, bold w/ dropshadow
- Show the copyright line
- Foreground color bright blue
- Background color dark blue
- Marin centered, non-bold w/ dropshadow
- Show the six buttons and their labels

### TEL3X2.MSE

- Create a port for the status line backup area, and copy the area where
- the status line will go into that drawing port.
- Copy the screen image to the port
- Setup our mouse entry/exit queries to do our status line, and mouse
- cursor changing.

### TEL3X3.ENT

- Paste original screen image back

### TEL3X3.EXT

- Paste original screen image back

### TEL3X3.MNU

- Draw the title at the top of the screen
- Foreground color yellow
- Background color a darkish brown/gold
- Marin, centered, bold w/ dropshadow
- Show the copyright line
- Foreground color bright blue
- Background color dark blue
- Marin centered, non-bold w/ dropshadow
- Show the six buttons and their labels

### TEL3X3.MSE

- Create a port for the status line backup area, and copy the area where
- the status line will go into that drawing port.
- Make sure port #1 is deleted
- Define port #1
- Copy the screen image to the port
- Setup our mouse entry/exit queries to do our status line, and mouse
- cursor changing.

### TELCMDS.DEF

- Basic screen definitions (e.g., title)
- What RIP file do we call from our demo screens to return here?
- Labels for each of the six buttons
- Text variables to execute when one of the six buttons are clicked
- Where should we go when we click on the "back" button?
- Define the status messages displayed when the user hovers over one of
- the mouse fields on the screen

### TELCMDS.FN

- Kill all mouse fields and queries
- Create full-screen drawing port with blue fade
- Define the variables for the engineering menu
- Show the 3x2 button menu
- Wipe off the screen image if setup says so, and show the new one
- Create the mouse fields for a 3x2 menu

### TELCMDS.RET

- Kill all mouse fields and queries
- Create full-screen drawing port with blue fade
- Define the variables for the engineering menu
- Show the main menu
- Choose a random wipe to wipe off the screen image
- Create the mouse fields for the main menu

### TELDEMOS.DEF

- Basic screen definitions (e.g., title)
- What RIP file do we call from our demo screens to return here?
- Labels for each of the six buttons
- Text variables to execute when one of the six buttons are clicked
- Where should we go when we click on the "back" button?
- Define the status messages displayed when the user hovers over one of
- the mouse fields on the screen

### TELDEMOS.FN

- Kill all mouse fields and queries
- Create full-screen drawing port with blue fade
- Define the variables for the demo menu
- Show the 3x2 button menu
- Wipe off the screen image if setup says so, and show the new one
- Create the mouse fields for a 3x2 menu

### TELDEMOS.RET

- Define the variables for the main menu
- Show the main menu
- Wipe off the screen image if setup says so, and show the new one
- Create the mouse fields for the main menu

### TELDRAW.DEF

- Basic screen definitions (e.g., title)
- What RIP file do we call from our demo screens to return here?
- Labels for each of the six buttons
- Text variables to execute when one of the six buttons are clicked
- Where should we go when we click on the "back" button?
- Define the status messages displayed when the user hovers over one of
- the mouse fields on the screen

### TELDRAW.FN

- Kill all mouse fields and queries
- Create full-screen drawing port with blue fade
- Define the variables for the engineering menu
- Show the 3x2 button menu
- Wipe off the screen image if setup says so, and show the new one
- Create the mouse fields for a 3x2 menu

### TELDRAW.RET

- Kill all mouse fields and queries
- Define the variables for the engineering menu
- Show the main menu
- Choose a random wipe to wipe off the screen image
- Create the mouse fields for the main menu

### TELENGIN.DEF

- Basic screen definitions (e.g., title)
- What RIP file do we call from our demo screens to return here?
- Labels for each of the six buttons
- Text variables to execute when one of the six buttons are clicked
- Where should we go when we click on the "back" button?
- Define the status messages displayed when the user hovers over one of
- the mouse fields on the screen

### TELENGIN.FN

- Kill all mouse fields and queries
- Create full-screen drawing port with blue fade
- Define the variables for the engineering menu
- Show the 3x2 button menu
- Wipe off the screen image if setup says so, and show the new one
- Create the mouse fields for a 3x2 menu

### TELENGIN.RET

- Kill all mouse fields and queries
- Create full-screen drawing port with blue fade
- Define the variables for the engineering menu
- Show the main menu
- Choose a random wipe to wipe off the screen image
- Create the mouse fields for the main menu

### TELKILL.FN

- Kill all mouse fields and entry/exit queries

### TELLISTS.ENT

- Copy the screen image to the port

### TELLISTS.EXT

- Copy the screen image to the port

### TELLISTS.FN

- Kill all mouse fields and queries
- Create full-screen drawing port with blue fade
- Show the 3x2 button menu
- Wipe off the screen image if setup says so, and show the new one
- Create the mouse fields for a 3x2 menu

### TELLISTS.MNU

- Basic screen definitions (e.g., title)
- What RIP file do we call from our demo screens to return here?
- Draw the title at the top of the screen
- Foreground color yellow
- Background color a darkish brown/gold
- Marin, centered, bold w/ dropshadow
- Show the copyright line
- Foreground color bright blue
- Background color dark blue
- Marin centered, non-bold w/ dropshadow

### TELLISTS.MSE

- Create a port for the status line backup area, and copy the area where
- the status line will go into that drawing port.
- Make sure port #1 is deleted
- Define port #1
- Copy the screen image to the port
- Setup our mouse entry/exit queries to do our status line, and mouse
- cursor changing.

### TELPORT.FN

- Create a full-screen drawing port in port slot #1 and draw the blue
- faded background onto it.
- Choose a random wipe to wipe off the screen image
- Display the blue faded background on 256 colors+, else solid blue
- Bluefade does things at 640x350, so we need to reset out environment
- back to 1280x960 world coordinates.
- Set base math to MegaNums (36)
- Set X/Y coordinate size to 2 bytes
- Set color palette mapping mode (not RGB encoding)
- Set world coordinates to 1280x960

### TELQUEST.DEF

- Basic screen definitions (e.g., title)
- What RIP file do we call from our demo screens to return here?
- Labels for each of the six buttons
- Text variables to execute when one of the six buttons are clicked
- Where should we go when we click on the "back" button?
- Define the status messages displayed when the user hovers over one of
- the mouse fields on the screen

### TELQUEST.FN

- Kill all mouse fields and queries
- Create full-screen drawing port with blue fade
- Define the variables for the demo menu
- Show the 3x2 button menu
- Wipe off the screen image if setup says so, and show the new one
- Create the mouse fields for a 3x2 menu

### TELQUEST.RET

- Kill all mouse fields and queries
- Create full-screen drawing port with blue fade
- Define the variables for the main menu
- Show the main menu
- Wipe off the screen image if setup says so, and show the new one
- Create the mouse fields for the main menu

### WIPE00.FN

- Switch to port 0

### WIPE01.FN

- Switch to port 0

### WIPE02.FN

- Switch to port 0

### WIPE03.FN

- Switch to port 0

## 5. External file references per script

- **BUTTONS.RIP**: 28GQ3SHO1D10RADIONEW.BMP, 28HW00001E00RADIONEW.BMP, 29J400001F00RADIONEW.BMP, 7IKA00002100FILECAB1.BMP, BLUEBACK.FN, BLUEFADE.FN, BOGO00001T00CHECKBOX.BMP, BOHW00001U10CHECKBOX.BMP, BOJ400001V10CHECKBOX.BMP, VU0QYY1S0000000000BACK.BMP
- **CURVES.RIP**: BLUEBACK.FN, BLUEFADE.FN, VU0QYY1S0000000000BACK.BMP
- **DBACK.FN**: 0000HS0Y000G000000STRIP6.BMP, 042S2T840008000000TORCH.BMP, 561EFH6L0008000000GODRAG3.BMP, I02SKP840008000000TORCH.BMP, MQ1EX16L0008000000GODRAG3.BMP, VU0QYY1S0000000000BACK.BMP
- **DEMO-01.COL**: DEMO-01.COL, DEMO-02.COL, N2_BUSI.RIP, N2_HORO.RIP, N2_PHOTO.RIP, NEWSPAPR.RIP, TWEATHER.RIP
- **DEMO-02.COL**: DEMO-01.COL, DEMO-02.COL, N2_BUSI.RIP, N2_HORO.RIP, N2_PHOTO.RIP, NEWSPAPR.RIP, TWEATHER.RIP
- **DL.FN**: 00000000DBACK.FN
- **DR.FN**: 00000000DBACK.FN
- **DRAGON.RIP**: 00000000DRAGON.TXT, 0000HS0Y000G000000STRIP6.BMP, 042S2T840008000000TORCH.BMP, 561EFH6L0008000000GODRAG3.BMP, DL.FN, DR.FN, I02SKP840008000000TORCH.BMP, MQ1EX16L0008000000GODRAG3.BMP, VU0QYY1S0000000000BACK.BMP
- **FONTS.RIP**: 00000000FONTSTOR.TXT, BLUEBACK.FN, BLUEFADE.FN, FONTS.RIP, FONTTEXT.COL, SHOWFONT.RIP, VLAAYOBC0001000000NAVIGATE.BMP, VU0QYY1S0000000000BACK.BMP
- **FONTTEXT.COL**: FONTS.RIP, FONTTEXT.COL
- **FOUND.RIP**: VU0QYY1S0000000000BACK.BMP
- **FXSHWIMG.FN**: ASTRO.JPG
- **IMAGES.RIP**: 0000BRIDGE02.JPG, 20305K4K001C000000BRICK.BMP, 30306K4K000G000000BRICK.BMP, 9O4IG8940004000000256COLOR.BMP, BLUEBACK.FN, BLUEFADE.FN, H84IJM940004000000256COLOR.BMP, KO4IXY940004000000256COLOR.BMP, RSE6WYI20008000000GEAR.BMP, VU0QYY1S0000000000BACK.BMP
- **LANDSCPE.RIP**: VU0QYY1S0000000000BACK.BMP
- **LGF1.RIP**: VU0QYY1S0000000000BACK.BMP
- **MARKER.RIP**: BLUEBACK.FN, BLUEFADE.FN, VU0QYY1S0000000000BACK.BMP
- **MENU.DEF**: TELDEMOS.FN, TELQUEST.FN
- **MENU.FN**: 00000000MENU.DEF, 00000000MENU.MNU, 00000000MENU.MSE, BLUEBACK.FN, BLUEFADE.FN
- **MENU.MNU**: 3Y7YCCAY0000000000TELBUT.BMP, 3YBSCCEP0000000000TELBUT.BMP, 3YFMCCIM0000000000TELBUT.BMP, DE7YLSAY0000000000TELBUT.BMP, DEBSLSEP0000000000TELBUT.BMP, DEFMLSIM0000000000TELBUT.BMP, MU7YV8AY0000000000TELBUT.BMP, MUBSV8EP0000000000TELBUT.BMP, MUFMV8IM0000000000TELBUT.BMP, REGISTER.FN
- **MENU.MSE**: MENU.ENT, MENU.EXT, REGISTER.MSE
- **MENU.RET**: 00000000MENU.DEF, 00000000MENU.MNU, 00000000MENU.MSE, 00000000TELKILL.FN, 00000000TELPORT.FN, WIPE01.FN
- **N2_BUSI.RIP**: BACK.BMP, NEWSPAPR.RIP, VU0QYY1S0000000000BACK.BMP
- **N2_HORO.RIP**: NEWSPAPR.RIP, VU1IYY2K0001000000BACK.BMP
- **N2_PHOTO.RIP**: 0000BEACH2.JPG, 0000BRIDGE02.JPG, 0000DUSK_SEA.JPG, 0000FIRCLOUD.JPG, NEWSPAPR.RIP, W21IZ62K0001000000BACK.BMP
- **N2_TITLE.RIP**: 0000ASTRO.JPG, 0000GALAXY.JPG, 0000JUPITER.JPG
- **NEWS.RIP**: 0000JUPITER.JPG
- **NEWSPAPR.RIP**: 0000ASTRO.JPG, 0000GALAXY.JPG, 0000JUPITER.JPG, DEMO-01.COL, DEMO-02.COL, N2_BUSI.RIP, N2_HORO.RIP, N2_PHOTO.RIP, NEWSPAPR.RIP, STORY01.TXT, STORY02.TXT, TELDEMOS.RET, TWEATHER.RIP, VUG0YYH20001000000NAVIGATE.BMP
- **ONLINE.RIP**: BLUEBACK.FN, BLUEFADE.FN, VU0QYY1S0000000000BACK.BMP
- **POLYGONS.RIP**: BLUEBACK.FN, BLUEFADE.FN, VU0QYY1S0000000000BACK.BMP
- **POLYPOLY.RIP**: BLUEBACK.FN, BLUEFADE.FN, VU0QYY1S0000000000BACK.BMP
- **SAILBOAT.RIP**: VU0QYY1S0000000000BACK.BMP
- **SHADMOVE.RIP**: 00000000SHADOWDO.FN
- **SHAPES.RIP**: BLUEBACK.FN, BLUEFADE.FN, VU0QYY1S0000000000BACK.BMP
- **SHOWFONT.RIP**: 00000000SHOWFONT.FN, 38603SHO1U00RADIONEW.BMP, 38763SHO1V00RADIONEW.BMP, 388A3SHO1W00RADIONEW.BMP, 389E3SHO2100RADIONEW.BMP, 38AI3SHO1X00RADIONEW.BMP, 38BM3SHO2510RADIONEW.BMP, 38CQ3SHO2700RADIONEW.BMP, 38DU3SHO2B00RADIONEW.BMP, BLUEBACK.FN, BLUEFADE.FN, FONTS.RIP, SHOWFONT.FN, VU0QYY1S0000000000BACK.BMP
- **SHUTTLE.RIP**: VU0QYY1S0000000000BACK.BMP
- **SPACSHUT.RIP**: VU0QYY1S0000000000BACK.BMP
- **SPECLEFX.RIP**: 00000000FXSHWIMG.FN, ASTRO.JPG, BEACH2.JPG, BLUEBACK.FN, BLUEFADE.FN, FXSHWIMG.FN, JUPITER.JPG, SHADOW.FN, VU0QYY1S0000000000BACK.BMP
- **TEL3X2.MNU**: 429ACGCA0000000000TELBUT.BMP, 42D4CGG10000000000TELBUT.BMP, DI9ALWCA0000000000TELBUT.BMP, DID4LWG10000000000TELBUT.BMP, DIK4LWN10000000000TELBACK.BMP, MY9AVCCA0000000000TELBUT.BMP, MYD4VCG10000000000TELBUT.BMP
- **TEL3X2.MSE**: TEL3X2.ENT, TEL3X2.EXT
- **TEL3X3.MNU**: 3Y7YCCAY0000000000TELBUT.BMP, 3YBSCCEP0000000000TELBUT.BMP, 3YFMCCIM0000000000TELBUT.BMP, DE7YLSAY0000000000TELBUT.BMP, DEBSLSEP0000000000TELBUT.BMP, DEFMLSIM0000000000TELBUT.BMP, DILELWNY0000000000TELBACK.BMP, MU7YV8AY0000000000TELBUT.BMP, MUBSV8EP0000000000TELBUT.BMP, MUFMV8IM0000000000TELBUT.BMP
- **TEL3X3.MSE**: TEL3X3.ENT, TEL3X3.EXT
- **TELCMDS.DEF**: BUTTONS.RIP, CURVES.RIP, FONTS.RIP, IMAGES.RIP, MARKER.RIP, POLYGONS.RIP, POLYPOLY.RIP, SHAPES.RIP, SPECLEFX.RIP, TELCMDS.RET, TELDEMOS.RET
- **TELCMDS.FN**: 00000000TEL3X3.MNU, 00000000TEL3X3.MSE, 00000000TELCMDS.DEF, 00000000TELKILL.FN, 00000000TELPORT.FN, WIPE00.FN
- **TELCMDS.RET**: $.FN, 00000000TEL3X3.MNU, 00000000TEL3X3.MSE, 00000000TELCMDS.DEF, 00000000TELKILL.FN, 00000000TELPORT.FN
- **TELDEMOS.DEF**: DRAGON.RIP, MENU.RET, NEWSPAPR.RIP, ONLINE.RIP, TELCMDS.FN, TELDEMOS.RET, TELDRAW.FN, TELENGIN.FN
- **TELDEMOS.FN**: 00000000TEL3X2.MNU, 00000000TEL3X2.MSE, 00000000TELDEMOS.DEF, 00000000TELKILL.FN, 00000000TELPORT.FN, WIPE00.FN
- **TELDEMOS.RET**: 00000000TEL3X2.MNU, 00000000TEL3X2.MSE, 00000000TELDEMOS.DEF, BLUEBACK.FN, BLUEFADE.FN, TELPORT.FN, WIPE01.FN
- **TELDRAW.DEF**: LANDSCPE.RIP, LGF1.RIP, TELDEMOS.RET, TELDRAW.RET
- **TELDRAW.FN**: 00000000TEL3X2.MNU, 00000000TEL3X2.MSE, 00000000TELDRAW.DEF, 00000000TELKILL.FN, 00000000TELPORT.FN, WIPE00.FN
- **TELDRAW.RET**: $.FN, 00000000TEL3X2.MNU, 00000000TEL3X2.MSE, 00000000TELDRAW.DEF, 00000000TELKILL.FN, BLUEBACK.FN, BLUEFADE.FN, TELPORT.FN
- **TELENGIN.DEF**: FOUND.RIP, SAILBOAT.RIP, SHUTTLE.RIP, SPACSHUT.RIP, TELDEMOS.RET, TELENGIN.RET, TWEATHER.RIP
- **TELENGIN.FN**: 00000000TEL3X2.MNU, 00000000TEL3X2.MSE, 00000000TELENGIN.DEF, 00000000TELKILL.FN, 00000000TELPORT.FN, WIPE00.FN
- **TELENGIN.RET**: $.FN, 00000000TEL3X2.MNU, 00000000TEL3X2.MSE, 00000000TELENGIN.DEF, 00000000TELKILL.FN, 00000000TELPORT.FN
- **TELLISTS.FN**: 00000000TELKILL.FN, 00000000TELLISTS.MNU, 00000000TELLISTS.MSE, 00000000TELPORT.FN, WIPE00.FN
- **TELLISTS.MNU**: 1YJUAJMR0000000000TELBACK.BMP, TELLISTS.RET, TELQUEST.RET
- **TELLISTS.MSE**: TELLISTS.ENT, TELLISTS.EXT
- **TELPORT.FN**: BLUEBACK.FN, BLUEFADE.FN, NEWPORT.FN
- **TELQUEST.DEF**: MENU.RET, TELQUEST.RET
- **TELQUEST.FN**: 00000000TEL3X2.MNU, 00000000TEL3X2.MSE, 00000000TELKILL.FN, 00000000TELPORT.FN, 00000000TELQUEST.DEF, WIPE00.FN
- **TELQUEST.RET**: 00000000TEL3X2.MNU, 00000000TEL3X2.MSE, 00000000TELKILL.FN, 00000000TELPORT.FN, 00000000TELQUEST.DEF, WIPE01.FN
- **TWEATHER.RIP**: VU0QYY1S0000000000BACK.BMP

Reference totals by type: BMP 84, FN 82, RIP 41, JPG 16 (JPEG photos via `1i`/`1p` RIP_IMAGE_STYLE/RIP_IMAGE), MSE 14, MNU 13, RET 13, DEF 12, COL 8, TXT 4 (flowed into `1e` columns via `1R`), ENT 4, EXT 4. No WAV/audio and no .ICN references. The .BMH files on disk (BUTTON.BMH, CHECKBOX.BMH, RADIO*.BMH) are never referenced by script - presumably auto-paired 'highlight' variants of same-named .BMP button images.

## 6. Syntax & wire-format observations

- **Introducers:** 111 of 116 files use SOH (0x01) + `|` for exactly the FIRST command line and `!|` for all the rest (DL.FN, DR.FN, DRAGON.RIP invert this, nearly all-SOH). SOH apparently marks start-of-scene for the 3.0 stream parser; `!|` remains the 1.54-compatible introducer.
- **Line ends are CRLF** (spec says CR); `\` before the line end continues the current command (POLYPOLY.RIP splits `<`-polygon vertex lists across physical lines).
- **Standard prologue** in 90+ files: `J10|n2000|M08|fZKQO` = base-math 36, coordinate size 2000?, color mode 8bpp (256 colors), world frame 1280x960 (`ZK`=35*36+20=1280, `QO`=26*36+24=960). Alternate frames: `HSDC`=640x480, `HR9S`=639x352, `HRDC`=639x480.
- **Inline trailing comments inside args:** the driver stops reading fixed-length args, so authors append whitespace + English after them: `!|fZKQO                 Set world coordinats to 1280x960` (ONLINE.RIP), same for `J10 ... Set base math to MegaNums (base 36)`. Also `!|command|! comment` chains everywhere.
- **Field-layout crib comments** left by TeleGrafix: `!|! xxyyxxyycaffffccrrrrrrrr` for `1e` (FONTS.RIP), `!|!sfFFFFZZOOSSCCBBCCWWRRRRRR` for `y` EXTENDED_FONT_STYLE (FONTS.RIP:114), and `!|! wwhhooffffssffbbBBddssgg22uuccprrrrr` for `1B` BUTTON_STYLE (SHOWFONT.FN).
- **Authoring typos tolerated by the driver:** CURVES.RIP:88 reads `|1<ESC>0000$COMPAT$` - the `!` introducer is missing entirely; commented-out commands appear as comment text (`!|!S0101` BLUEBACK.FN, `!|!K0U2WYZA8` FONTTEXT.COL, `!|! ;WW200C1S1S0000` MARKER.RIP).
- **Flowed text**: after `1e` (or 1.54 `1T` with trailing column/stream digits, NEWS.RIP), RAW text lines with no `!|` introducer are the column content, terminated by `1E`; content can also come from `1R` reading a .TXT file, `$OVERFLOW(1,CUR)$`, or `$&MAIN_STORY$`. NEWS.RIP draws a drop-cap via `@A91G` + single char, then flows 'wo years ago...' - the article text is a 1995 TeleGrafix press essay on RIPscrip 2.0/RIPterm Professional.
- **`!|` with nothing after it** is a harmless no-op line (SHOWFONT.FN); `!|----` (missing `!`) in 6 files accidentally parses as the new filled-skewed-oval opcode `-` with dash args - the shipped driver evidently tolerates garbage args.
- **Level-2 usage is massive but narrow:** 9104x `2C` PORT_COPY (the WIPE00-24.FN transition library is almost entirely port-copy animation), plus `2P`/`2p`/`2s` define/delete/switch port. No `2W` PORT_WRITE etc.
- **Buttons** use bitmap skins (`1b` + TELBUT.BMP etc.) instead of 1.54 chiseled buttons; `1B` button-style + `1U` with `<><>` empty icon/label blocks used as chisel-frame decorations.
- **File-extension conventions:** .FN = function/subroutine scenes (wipes, backgrounds, port setup), .MNU = menu screen, .MSE = mouse-field overlay, .RET = return-to-scene stub, .ENT/.EXT = enter/exit transition, .DEF = menu definition (sets `<<CMDn>>`/`<<LABn>>` user vars), .COL = multi-column flowed-text scene.
- **2.00a4 spec collision resolved:** the draft assigns level-0 `b` to both EXTENDED_TEXT_WINDOW and SET_BASE_MATH; the shipping 3.0 driver uses `J` for SET_BASE_MATH (see section 2).

## 7. Non-RIP plain-text lines

- **CURVES.RIP**: 1 raw text line(s) (flowed column content), first: `|10000$COMPAT$`
- **N2_HORO.RIP**: 30 raw text line(s) (flowed column content), first: `Aries: Gift received represents love - beautiful, rare vase could be i`
- **NEWS.RIP**: 26 raw text line(s) (flowed column content), first: `wo years ago, TeleGrafix Communications stunned the computer industry `
- **NEWSPAPR.RIP**: 12 raw text line(s) (flowed column content), first: `Southern California was pounded`

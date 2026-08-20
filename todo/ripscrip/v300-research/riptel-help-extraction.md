# RIPtel 3.1 (TeleGrafix, 1997) - Extracted Protocol Documentation

Curated protocol-relevant excerpts from the RIPtel 3.1 install at `/home/tracker1/src/rip-tools/artifacts/RIPtel/`. Raw string dumps saved alongside: `riptel-hlp-raw.txt` (WinHelp topic text, mostly readable), `ripscrip-hlp-raw.txt` (complete string resource), `messages-hlp-raw.txt`, `ripscrip-res-raw.txt`, `riptel-exe-raw.txt`.

## 1. File format identification

| File | Actual format |
| --- | --- |
| RIPTEL.HLP (347KB) | Genuine WinHelp 3.x (`3F 5F 03 00`), built with EasyHelp/Web. Topic text is **largely uncompressed** - nearly all prose extractable via `strings`. Title: "RIPtel User's Guide". |
| RIPSCRIP.HLP (38KB) | NOT WinHelp. TeleGrafix custom format, header `\x04 RIPscrip Help File Resource \x04\n\x1a`, 32-bit offset table then **plaintext strings** - complete error-message + command-name string table for the RIPSCRIP.DLL parser. Fully extractable. |
| MESSAGES.HLP (18KB) | Same custom "RIPscrip Help File Resource" format - RIPtel UI strings, tips, terminal-emulation option strings. Fully extractable. |
| RIPSCRIP.RES (10KB) | Header `\x04 RIPterm v2.0 Resource File \x04` - dialog templates (as embedded C arrays `resource_tvopt.rsc`, `resource_tvreq.rsc` for text-variable prompt dialogs, Win16 DLGTEMPLATE data using MS Sans Serif), plus a default palette/BMP block. |
| RIPSCRIP.DB (400B) | Header `\x04 RIPscrip Text Variable Database \x04` - the persistent store for `$+VAR$` permanent text variables (empty except index scaffolding). |
| FONTS/RIPscrip.maf (271KB) | Header `\x04 RIPterm v2.0 MicroANSI Font File \x04` - bitmap ANSI-emulation fonts with per-resolution tables: "640x480 VGA" (dims 0x280x0x1E0), "800x600 - VGA" (0x320x0x258), 1024x768 (0x400x0x300); each with ~5 font-size subtables. |
| FONTS/atf.cfg | "AllType" (ATF) outline-font registry. Maps RFF outline fonts BRUSH, COBB, DEFAULT, DIXON, EUREKA, MARIN, OAKLAND, SYMBOL (.RFF files), each with 10 style variants: base, Th(in), Cn (condensed), Wd (wide), Ex (expanded), Ho (hollow), HT, HC, HW, HE (hollow+thin/condensed/wide/expanded). |
| FONTS/*.CHR | Borland BGI stroked fonts (BOLD, EURO, GOTH, LCOM, LITT, SANS, SCRI, SIMP, TRIP, TSCR) - the classic RIPscrip 1.54 vector fonts. |
| riptel.pho | "RIPterm Dialing Directory File" - bookmark records; demo entries all point to telnet.telegrafix.com ("RIP-3" demos by ASR: Photo Gallery, Graphing, News Reader, House-by-Mouse, Weather Map, Database, Yellow Pages, Poker, Backgammon, "Escape from Languour"). |
| INSTALL.LOG | Installs `RIPscrip.ttf` to Windows fonts; creates `C:\windows\RIPscrip.ini` ([CONFIG] AUDIO=TRUE, [PATHS] DLLPATH) and `RIPtel.ini`; dirs C:\RIPtel\Files, ICONS, FONTS. |

Note the internal headers say "RIPterm v2.0" - RIPscrip 3.0 is the renamed RIPscrip 2.x / RIPterm 2.0 engine (matches the 2.x spec docs already in the repo). RIPtel 3.1 ships "driver version 3.0.7" of RIPSCRIP.DLL (readme.txt).

## 2. Version strings & handshake

- Auto-detect reply to a host "are you RIP?" query: **`RIPSCRIP03000`** (RIPTEL.HLP FAQ: appears on the login line when MajorBBS/WorldGroup time out waiting; server waits only ~1-1.5 s).
- `$RIPVER$` text variable "RIPscrip version (e.g., **RIPSCRIP015300**)" - i.e. `RIPSCRIP0<major><minor*100>` zero-padded (1.54 -> 015300... sic, help's own example).
- readme.txt: "RIPtel Visual Telnet Version 3.1 (Driver version 3.0.7)"; EXE: "RIPtel Visual Telnet v3.1, a RIPscrip-enabled Telnet Browser", DLL version check message ("The RIPscrip driver (RIPSCRIP.DLL) is not the correct version... need %ld.%ld.%ld").
- Error string (RIPSCRIP.HLP): "Invalid RIPscrip revision code" - headers carry a revision code.

## 3. RIPscrip 3.0 command (function) name table - RIPSCRIP.HLP, verbatim order

The DLL's function-name string table (order preserved; this is the parser's command inventory for RIPscrip 3.0):

Drawing/state group: RIP_Arc, RIP_BackColor, RIP_Bar, RIP_Bezier, RIP_Circle, RIP_Color, RIP_EraseEOL, RIP_EraseView, RIP_ExtendedFontStyle, RIP_ExtendedTextWindow, RIP_EraseWindow, RIP_FilledCircle, RIP_FilledOval, RIP_FilledPolygon, RIP_FilledRectangle, RIP_FilledRoundedRect, RIP_FillPattern, RIP_FillStyle, RIP_FontAttrib, RIP_FontStyle, RIP_GotoXY, RIP_Home, RIP_Line, RIP_LineStyle, RIP_Move, RIP_OneDrawingPalette, RIP_OnePalette, RIP_OvalArc, RIP_OvalPieSlice, RIP_PieSlice, RIP_Pixel, RIP_Point, RIP_Polygon, RIP_Polyline, RIP_Rectangle, RIP_ResetWindows, RIP_RoundedRect, RIP_SetBaseMath, RIP_SetBorder, RIP_SetCoordinateSize, RIP_SetColorMode, RIP_SetDrawingPalette, RIP_SetPalette, RIP_SetWorldFrame, RIP_Text, RIP_TextMetric, RIP_TextWindow, RIP_TextXY, RIP_Viewport, RIP_WriteMode

UI/multimedia group: RIP_BeginText, RIP_Button, RIP_ButtonStyle, RIP_CopyBlit, RIP_Define, RIP_EndText, RIP_FileQuery, RIP_GetImage, RIP_Image, RIP_ImageStyle, RIP_KillEnclosedMouseFields, RIP_KillMouseFields, RIP_LoadBitmap, RIP_LoadIcon, RIP_Mouse, RIP_PlayAudio, RIP_PutImage, RIP_Query, RIP_ReadScene, RIP_RegionText, RIP_Scroll, RIP_SelectArticle, RIP_SetMouseCursor, RIP_WriteIcon

Port/data-table group: RIP_PortCopy, RIP_PortDefine, RIP_PortDelete, RIP_PortWrite, RIP_SetRefresh, RIP_SwitchButtonStyle, RIP_SwitchDirectory, RIP_SwitchEnvironment, RIP_SwitchPalette, RIP_SwitchPort, RIP_SwitchStyle, RIP_SwitchTextWindow, RIP_BaudEmulation, RIP_EnterBlockMode, RIP_BeginEncodedStream

(RIPTEL.HLP also references RIP_LOAD_BITMAP by name when discussing `$<file$` macro limitations. RIPTEL.EXE exports/imports a separate DLL API: RIP_InitDLL, RIP_ProcessBuffer, RIP_ProcessFile, RIP_ProcessEvent, RIP_QueryCommand, RIP_RefreshSend, RIP_FullReset, RIP_DefineTextVariable, RIP_DeleteTextVariable, RIP_RegisterTextVariable, RIP_PlaybackLocalRIPFile, RIP_ConvertIconToBmp, RIP_DecompressArchive, RIP_IsFileArchiveFile, RIP_EnterBlockMode-related RIP_GetBlockModeFilename / RIP_GetBlockModeTransferType, RIP_ShowImageWithCurrentStyle, RIP_ShowBitmapWithCurrentStyle, RIP_EchoCharacters, RIP_SetHostDirectory, RIP_GetHostDirectory, RIP_AudioSupport, etc. - client API, not wire commands.)

## 4. Limits and semantics recovered from RIPSCRIP.HLP error strings

- Polygon/polyline vertex limit: **4096 vertices** ("Enhanced RIPscrip driver, now allows polygon-type objects to have 4096 vertices" - readme.txt; errors "Vertex count is too small", "Vertex count doesn't match parameters").
- Data tables all have **36 slots (0-35)**: button styles, graphics styles, drawing ports, text windows, color palettes, environments, mouse-field entries - "Invalid ... entry number (0-35)", "Invalid button group number (>35)".
- Drawing ports: "The given port number is invalid (**1-35 only**)"; port #0 is the screen - "Can't delete graphics port #0", "Can't create drawing port #0"; snapshot ports and offscreen ports exist ("No mouse/button fields on offscreen drawing ports"); clipboard port concept.
- Slot #0 of each table is special/undeletable: "Cannot protect current text window slot when it is #0", "Can't protect environment data table entry #0", "Can't protect graphics style data table entry zero", "Can't protect color palette zero"; slots can be PROTECTed/unprotected.
- Color system: palette index range 0-255 ("Color palette base is out of range (>255)"), max **256 colors** per palette command ("Too many colors in color palette command (>256)"), system palette colors 0-63 ("Invalid system palette color value (>63)"), direct RGB currently **8 bits per channel only** ("Invalid number of bits for RGB value (must be 8)", "RGB color mode only supports 8-bit color currently", "%s: Invalid color mode bits - only 8 supported now"); palette animation exists ("Unable to animate palette").
- Fill patterns: "Pattern value exceeds 255"; pre-defined fill styles; custom line patterns "can't have blank pattern"; odd/even fill setting.
- Buttons: hotkey char <=255, label <=255 chars ("Button label too long (>255)"), types **plain, icon, snapshot** ("Invalid button type - must be plain, icon or snapshot"), colors: bright/dark/surface/corner/underline-hotkey, groups 0-35, checkbox strings, host command per mouse field.
- Header segments (the RIPscrip 3.0 scene-header mechanism): flags + entry numbers for button style / graphics style / drawing port / text window / color palette / environment / mouse field / audio / graphics screen; "Invalid coordinate size in environment header segment", "Invalid direct RGB bit count in environment header segment", "Invalid general header flags", "Invalid RIPscrip revision code".
- Poly-Bezier: segment-typed blocks; "The last segment of a poly-bezier cannot be a curve"; segment count validation.
- Backup/state system: data backup slots + a stack (PUSH/POP: "No slots available for PUSH", "No stack to pop"); per-object save/restore of button styles, graphics styles, text windows, palettes, mouse fields, environments, ports (with strip-based screen bitmap data), screens.
- Text windows: row/column positions, articles/columns ("Invalid text article number", "Invalid text column number"), wrap/chop designator, domain designator, text metric mode, write mode.
- Fonts: font size/ID validation, string & char rotation values, char spacing (0 illegal), shadowing mode, direction, horizontal/vertical orientation, "Can't change system font attributes"; MicroANSI font loading errors; BGI font files; outline-font error class ("Outline Font Error", "FONT ERROR: %s").
- File transfer: send/receive directive, numbered file-transfer protocols ("Invalid file transfer protocol number"), batch vs non-batch, file types, **encoded stream** file types (RIP_BeginEncodedStream); Zmodem is the transfer protocol used by RIPtel (RIPTEL.HLP; upload/download in FILES\ dir; CTRL-X aborts).
- 1.54 compat: "Can't convert RIP 1.54 Icon %s to 2.0 BMP format!", "1.54 icon file %s has an invalid width"; ICN->BMP conversion built in.
- JPEG support built into driver (jpegShow, LoadJPEGBuffer, JPEG scaling tables errors); BMP support incl. "Can't show compressed bitmaps".
- Sound: tone commands with frequency/duration/increment sweeps (errors for start>stop frequency, zero increment/duration) plus named sounds (see $ALARM$/$BEEP$/$BLIP$/$MUSIC$/$PHASER$/$REVPHASER$).
- Wallpaper: "Invalid wallpaper rectangles" (imageWallpaper); template chaining directive; refresh expressions (RIP_SetRefresh / $REFRESH$ / $NOREFRESH$).
- Database: RIPSCRIP.DB indexed record DB with hash table ("Database is corrupted - Try deleting RIPSCRIP.DB").
- Query system: query OBJECT keyword, OPTION keyword, resident queries (queryDefineResident), mouse-field entry/exit queries, per-port and per-text-window queries.
- Internal callback API: ripGetDisplayRect() callback, "RIPscrip callback system must be initialized first", resource file "RIPscrip.res" required.

## 5. Text variable language (RIPTEL.HLP "Text Variables" chapter - full extract)

Data-returning variables (`$NAME$`): $ADOW$ abbreviated day of week; $AMPM$; $BASEMATH$ query base math (36 vs 10 number encoding); $BAUDEMUL$ baud-rate emulation; $COLORMODE$; $COLORS$ total colors of video device; $COORDSIZE$ byte-size of X/Y coordinates; $CURSOR$ text cursor status; $CURX$ $CURY$; $DATE$ (MM/DD/YY); $DATETIME$; $DAY$; $DOW$; $DOY$; $FIELDID$ current mouse field ID; $FYEAR$ 4-digit year; $HOUR$; $ISEXTWIN$; $ISPALETTE$; $M$ mouse button status LMR; $MHOUR$ military hour; $MIN$; $MONTH$; $MONTHNUM$; $MSTAT$; $OFFSCREEN$ offscreen bitmap port pixel data; $PASSWORD$ bookmark password; $PORTH$ $PORTW$ $PORTX0$ $PORTX1$ $PORTY0$ $PORTY1$; $RAND$; $RESX$ $RESY$ device resolution; $RIPVER$ (e.g. RIPSCRIP015300); $SEC$; $STATBAR$; $TEXTXY$ last graphical text X/Y; $TIME$; $TIMEZONE$ (or "NONE"); $TWFONT$; $TWH$ $TWW$ $TWX0$ $TWX1$ $TWY0$ $TWY1$; $USERNAME$ bookmark user-ID; $WDAY$; $WORLD$ world coordinate frame; $WORLDH$ $WORLDW$; $WOY$ (Sunday-first) $WOYM$ (Monday-first); $X$ $XY$ $XYM$ $Y$ mouse location/status; $YEAR$ 2-digit year.

Command-performing variables: $ALARM$, $ATW$ activate text window, $AVP$ activate viewport, $BEEP$, $BLIP$, $CLS$, $COFF$/$CON$ cursor off/on, $COMPAT$ set environment to RIPscrip 1.54 settings, $DTW$/$DVP$ deactivate text window/viewport, $DWAYOFF$/$DWAYON$ doorway mode, $EGW$ erase graphics viewport, $ETW$ erase text window, $FILEDEL(file1,file2,...)$ delete host files, $HKEYOFF$/$HKEYON$ button hotkeys, $IMGSTYLE(cur,x0,y0,x1,y1)$ set image style, $MKILL$ kill mouse fields, $MTW$ maximize text window, $MUSIC$, $MVP$ maximize viewport, $NOREFRESH$, $NULL$, $P$ paste clipboard, $PHASER$, $RBS$ restore button style from backup, $RCB$ restore clipboard, $RCP$ restore color palette, $RENV$ activate snapshotted environment, $REFRESH$ force terminal refresh transmit, $RESET$ (keywords: SOFT, HARD, MCURSOR, KEYBOARD, SOUND, TV, QUERY, PAL - readme mentions $RESET(PAL)$), $RESTORE$ / $RESTORE0$-$RESTORE9$ restore graphics screen, $RESTOREALL$, $REVPHASER$, $RGS$ restore graphics style, $RMF$ restore mouse fields, $RTW$ restore text window, $SAVE$ / $SAVE0$-$SAVE9$ save graphics screen, $SAVEALL$, $SBS$ save button style, $SCB$ save clipboard, $SCP$ save color palette, $SENV$ record environment, $SGS$ save graphics style, $SMF$ save mouse fields, $STW$ save text window, $TABOFF$/$TABON$ TAB-key field select, $TWERASEEOL$, $TWFONT$, $TWGOTO$, $TWHOME$, $TWIN$ text window status, $VT102OFF$/$VT102ON$.

Additional processor names in RIPSCRIP.HLP not in the help tables (tvarProc*): TERMINFO, BACKSTAT, PCB, SHIFT, CTRL, D, HOSTDIR, XFER, PALENTRY, CUR, INUSE, T, ISPROT, OPTION, SBAROFF/SBARON, APP (run application; "%s: Application number..."), IFS (with LIST/category keywords), COPY, PROTECT, MCURSOR, AVP/DVP/MVP, IMGSTYLE, plus reset keyword handlers (resetKeywordSOFT/HARD/MCURSOR/KEYBOARD/SOUND/QUERY/TV).

### User-defined text variable syntax (RIPTEL.HLP, complete)

`$[directives][x,y:]NAME[(MODE[,CONV])][,width][@question][=default]$`

Directive characters (any order, between first `$` and name; each once):

- `*` answer required (can't cancel)
- `+` save variable to database permanently (RIPSCRIP.DB)
- `%` (memory table; "Save to internal memory table (lost when RIP hangs up)")
- `#` don't echo keystrokes (show #'s - passwords)
- `-` set the variable without prompting the user
- `&` retrieve the variable's contents without prompting the user

- `x,y:` popup dialog position in world coordinates; omit either value (keep comma) to center on that axis; `$,:NAME$` = center both.
- `(MODE)` = ANY | ALPHA | NUMBER | ALPHANUM; `(MODE,CONV)` CONV = TONAME | TOUPPER | TOLOWER; conversion-only `(TONAME)` legal; conversion before mode is a syntax error.
- `,width` data-entry field width in columns.
- `@question` custom prompt (no `$` allowed inside).
- `=default` default response.
- Empty response inserts `NULL`.

Limits: variable name max **20 chars** (alpha/digit/underscore, must start alpha, auto-uppercased); question/default max **100 chars**; variable content max **255 chars**. Examples from help: `$*+20,50:NAME(ToName),30@What's your name?=John Doe$`, `$*#20,10:PASSWORD,10@Please enter your password$`.

Host may delete variables (confirm prompt "The host wants to delete the variable %s. Proceed?"); data query = host sends a template like `$FULL_NAME$^m$ST_ADDR$^m$CITY$, $STATE$ $ZIP$^m` and the terminal returns the filled-in text ("Data Security Activated" message exists for protected variables).

## 6. Macro / host command language (RIPTEL.HLP)

- Control characters via `^` or backquote (interchangeable; double the char for a literal): ^@ null, ^L clear screen/top of form, ^M carriage return, break, backspace, escape, pause (^S) / resume (^Q) transmission; special keys: up/down/ right/left arrow, Home, End, Ctrl-Home.
- Local file playback commands (searched in host directory first, then ICONS\, then the configured Search Path):
  - `$>FILE.RIP$` play RIPscrip file (any text file allowed; local echo only, mouse fields in the file are created)
  - `$)FILE.WAV$` play WAV audio
  - `$<FILE.BMP$` show bitmap (auto-dither, current image style; full RIP_LoadBitmap flexibility not available from macro form)
  - `$(FILE.JPG$` show JPEG photo (only JPEG supported for photos)
  - `$IMGSTYLE(cur,x0,y0,x1,y1)$` positions subsequent image/bitmap ("cur" = current screen port).
- Popup lists: `((question::opt1,opt2,...))`, optional `x,y:` position prefix (world coordinates, omitted value = centered), `*` prefix = response required, `@description` display text vs transmitted text, `~hot~`/`_hot_` hotkey markup, `\\` escapes backslash, max **64 entries** per list; default question "Choose one of the following:".
- Command Mode menu option executes any host-command/macro-language string directly (advertised for testing RIPscrip host commands).
- The same language is the RIPscrip 3.0 "host command" / button command language (help repeatedly defers to the "RIPscrip 3.0 Protocol Reference" from TeleGrafix for "the thousands of different text variable options").

## 7. Feature list for RIPscrip 3.0 (RIPTEL.HLP "What are RIPscrip Graphics?")

- Third generation of Remote Imaging Protocol; based on RIP 1.54; text-encoded.
- Full drawing primitives; fill patterns/colors; border thickness/dash control.
- Multiple-column text displays ("news articles" - RIP_SelectArticle).
- "Adobe and TrueType style fonts" (outline fonts) with italics, bold, rotation, shadowing, spacing; multiple text windows for data-entry forms.
- JPEG anywhere on screen at any size, "even display them while they're downloading" (readme: progressive display not working in RIPtel 3.1); BMP everywhere incl. as buttons.
- Background digitized audio (WAV).
- Buttons/mouse fields: radio buttons, checkboxes.
- Client/server resource caching + remote resource updating; local scene files; data tables (styles, palettes, buttons, environments) as local cache; simple client-side database; backup system to preserve environment "state" for dialogs and door programs.
- Resolution independent (640x480 scene looks right at 1024x768); palette independent, "new 24-bit architecture".
- ANSI + VT-102 emulation built in.
- 1993 Dvorak Award for RIP 1.54; ~90% of BBS servers by 1995.

## 8. Ecosystem (RIPTEL.HLP "Other RIPscrip Products")

TeleGrafix: RIPscrip Plug-In for Netscape, RIPterm 2.0 for MS-DOS, RIPaint 2.0 for MS-DOS, RIP-2-C 3.0 developer tools, RIPscrip 3.0 protocol specification, RIPweb for Linux (upcoming); RIPmaster servers from Advanced Systems Research (ASR). Third-party RIP terminals: ProComm Plus/Win, Telix/Win, Qmodem Pro (Win+DOS), SoftTerm, WinRamp, SmartCom, ST-RIP (Atari ST), AREXX ext. (Amiga). Host systems: RIPmaster (Unix/TBBS), Searchlight, TBBS, MajorBBS/WorldGroup, Wildcat!, Remote Access, Kitten, Solaris BBS, Synchronet, Powerboard, Renegade.

## 9. Misc protocol-adjacent details

- Terminal text modes (MESSAGES.HLP): 80x43, 91x43, 80x25, 91x25, 40x25; screen modes Normal/Full screen/640x480/800x600/1024x768.
- MESSAGES.HLP backspace options: "backs up" vs "erases characters"; backspace sends backspace code vs delete code; error levels Warnings/Basic/Serious/Critical.
- Block mode (RIP_EnterBlockMode) + encoded streams (RIP_BeginEncodedStream) with file-type and protocol-number parameters; Zmodem used for actual transfers.
- "Upload file(s) '%s'?" confirmation - host-initiated transfer prompt (RIPSCRIP.HLP).
- Scene files: RIP_ReadScene + "Can't locate local RIPscrip scene file %s".
- Search path for resources beyond ICONS\ (CD-based resources for games).
- INSTALL.LOG confirms `RIPscrip.ini` [CONFIG]/[PATHS] and a `Ripscrip.ttf` TrueType font shipped to the Windows font directory.

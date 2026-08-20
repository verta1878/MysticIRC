
=====================================================================
==       SEGMENT 3: LEVEL 1 INTERACTIVE COMMANDS                   ==
=====================================================================

Level 1 commands handle interactive elements: mouse regions,
buttons, clipboard operations, icons, text blocks, file queries,
and variable definitions. They are prefixed with '1' after the
'|' delimiter.

     Format: !|1<cmd><parameters>|


---------------------------------------------------------------------
3.1  RIP_KILL_MOUSE — Clear All Mouse Regions
---------------------------------------------------------------------

     Function:     Kill All Mouse Fields
     Command:      |1K
     Arguments:    (none)
     Format:       !|1K|

Clears all registered mouse regions and buttons. Typically sent
before drawing a new screen with fresh interactive elements.


---------------------------------------------------------------------
3.2  RIP_MOUSE — Define Mouse Region
---------------------------------------------------------------------

     Function:     Define Mouse Region
     Command:      |1M
     Arguments:    num:2 x0:XY y0:XY x1:XY y1:XY clk:1 clr:1 res:2 res:3 text
     Format:       !|1M<num><x0><y0><x1><y1><clk><clr><res><res><text>|
     Example:      !|1M010A0A1E0U1000000SELECT 1\r|

Defines a rectangular mouse-clickable region on screen.

CORRECTED.  This was documented — and implemented — as carrying a
2-digit hotkey followed by a 1-digit flags field.  It carries neither.
Slot 101 records

     mega2, XY, XY, XY, XY, mega1, mega1, mega2, mega3

and the handler (RVA 0x00CEF8) loads those arguments separately.  The
1.54 specification names the two single digits 'invertable' and
'resetafter'; bbs-land names them clk and clr.  RIP_MOUSE has no hotkey
field, and the flags that were being read from column 12 are reserved —
in the shipped corpus that column is '0' on all 36 commands.  See D-15.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     num         2       0-1295    Region number
     x0,y0       XY      coords    Top-left corner
     x1,y1       XY      coords    Bottom-right corner
     clk         1       0-35      Invert the region while clicked
     clr         1       0-35      Clear the mouse-field set after
                                   this region fires
     res         5       0         Reserved (record splits this as
                                   mega2 + mega3)
     text        var     ASCII     Host command string, at offset 17

RIPlib maps clk to RIP_MF_INVERT and clr to RIP_MF_RESET.

The MF_SEND_CHAR / MF_RADIO / MF_TOGGLE flags below are carried by
RIP_BUTTON (§3.4), not by this command.

Click behavior (all mouse regions):
     1. If MF_TOGGLE: XOR-invert region visually, toggle active
     2. If MF_SEND_CHAR and hotkey != 0: send hotkey + CR
     3. Default: send text string + CR to BBS
     4. First matching region wins (top-to-bottom scan)
     5. One-shot: region deactivates after click (unless toggle)

Two distinct numbering schemes are involved, and the table here used to
conflate them.  RIP_BUTTON's flags field is a wire value whose BITS
select behaviours; rip_mouse_region_t.flags is the DLL's internal field
record byte, whose VALUES are unrelated to those bit positions.

     RIP_BUTTON flags field (wire, §3.4):

     Bit   Selects
     ---   ---------------------------------------
     0     MF_SEND_CHAR — send hotkey char, not text
     1     MF_RADIO     — radio-button group behaviour
     2     MF_TOGGLE    — toggle state on each click

     rip_mouse_region_t.flags (internal byte):

     Value   Name            Set by
     -----   -----------     ---------------------------
     0x01    MF_INVERT       |1M clk
     0x02    MF_HAS_LABEL    label present
     0x04    MF_ACTIVE       always set on registration
     0x08    MF_SEND_CHAR    |1U flags bit 0
     0x10    MF_RESET        |1M clr
     0x20    MF_RADIO        |1U flags bit 1
     0x40    MF_TOGGLE       |1U flags bit 2


---------------------------------------------------------------------
3.3  RIP_BUTTON_STYLE — Define Button Style
---------------------------------------------------------------------

     Function:     Define Button Style
     Command:      |1B
     Arguments:    wid:XY hgt:XY orient:2 flags:4 bevsize:2
                   dfore:2 dback:2 bright:2 dark:2 surface:2
                   grp_no:2 flags2:2 uline:2 corner:2 res:1 res:5
     Format:       !|1B<36 chars of params>|

Defines the visual style for subsequent RIP_BUTTON commands.

The payload is THIRTY-SIX characters, not thirty: thirty carry
meaning and a further six are reserved.  Dispatch slot 87 records
sixteen fields totalling 36, and RIPlib gates on `len >= 36`.  The
reserved tail is two fields in the record - mega1 then mega5 - which
this table previously merged into a single res:6.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     wid         2       1-639     Button width
     hgt         2       1-349     Button height
     orient      2       0-4       Orientation (0=horizontal)
     flags       4       0-65535   Style flags (16-bit)
     bevsize     2       0-10      Bevel depth in pixels
     dfore       2       0-15      Label foreground color
     dback       2       0-15      Label background color
     bright      2       0-15      Highlight color (top/left)
     dark        2       0-15      Shadow color (bottom/right)
     surface     2       0-15      Surface fill color
     grp_no      2       0-35      Radio button group number
     flags2      2       0-1295    Extended flags
     uline       2       0-15      Underline color
     corner      2       0-15      Corner color
     res         1       0         Reserved (record field 15)
     res         5       0         Reserved (record field 16)

Style flags (in flags parameter):

     Bit    Value    Name                 Description
     ---    ------   ----------------     ---------------------------
     0      0x0001   BSF_CLIPBOARD_PORT   Uses clipboard port
     7      0x0080   BSF_ICON_BUTTON      Button displays icon
     8      0x0100   BSF_PLAIN_BUTTON     Plain rectangular style
     10     0x0400   BSF_OFFSCREEN_OK     Allowed in offscreen ports
     14     0x4000   BSF_PROTECTED        Style slot is locked


---------------------------------------------------------------------
3.4  RIP_BUTTON — Create Button Instance
---------------------------------------------------------------------

     Function:     Create Button (draw + register mouse region)
     Command:      |1U
     Arguments:    x0:XY y0:XY x1:XY y1:XY hotkey:2 flags:1 res:1 text
     Format:       !|1U<x0><y0><x1><y1><hotkey><flags><res><text>|

Creates a visual button at the specified position using the
current button style, and registers a mouse region for click
handling.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x0,y0       XY      coords    Top-left corner (y0 scale_y)
     x1,y1       XY      coords    Bottom-right (y1 scale_y1)
     hotkey      2       0-255     ASCII key equivalent
     flags       1       0-15      Region flags (see §3.2)
     res         1       0         Reserved
     text        var     ASCII     icon<>label<>host_command

This command is where the hotkey and the MF_SEND_CHAR / MF_RADIO /
MF_TOGGLE flags live — slot 107 records XY, XY, XY, XY, mega2, mega1,
mega1, and the 1.54 specification and bbs-land agree.  RIPlib parsed
both fields and discarded them until v2.0.3, which left that dispatch
path unreachable from any command; see D-15.

Text segmentation: a lone segment with no '<>' is the LABEL only and
does not become the host command.  A button whose host command is empty
still registers a clickable region — every |1U in the shipped corpus is
of that shape ("<>Clear<>") — and simply sends nothing when clicked.

Button rendering:
     1. Fill surface with button style surface color
     2. Draw highlight bevel (top + left edges)
     3. Draw shadow bevel (bottom + right edges)
     4. Parse text for '<>' separators:
          - Segment 1: icon filename (looked up in flash/cache)
          - Segment 2: display label (centered on button face)
          - Segment 3: host command (sent on click)
     5. Draw icon if found (centered, or top-half if label present)
     6. Draw label centered on button face
     7. Register mouse region with host command

Text format (3 segments separated by '<>'):

     icon_name<>display_label<>host_command

     If 2 segments: icon<>label (no host command)
     If 1 segment:  label only (also used as host command)


---------------------------------------------------------------------
3.5  RIP_GET_IMAGE — Copy Screen Region to Clipboard
---------------------------------------------------------------------

     Function:     Copy Screen Region to Clipboard
     Command:      |1C
     Arguments:    x0:2 y0:2 x1:2 y1:2 res:1
     Format:       !|1C<x0><y0><x1><y1><res>|

Copies pixels from the screen rectangle to the internal clipboard
buffer. The clipboard stores raw 8bpp pixel data in PSRAM.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x0,y0       2,2     coords    Top-left (y0 scale_y)
     x1,y1       2,2     coords    Bottom-right (y1 scale_y1)
     res         1       0         Reserved


---------------------------------------------------------------------
3.6  RIP_PUT_IMAGE — Paste Clipboard to Screen
---------------------------------------------------------------------

     Function:     Paste Clipboard to Screen
     Command:      |1P
     Arguments:    x:XY y:XY mode:2 res:1
     Format:       !|1P<x><y><mode><res>|

Pastes the clipboard buffer to screen position (x,y).

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x,y         XY,XY   coords    Destination position
     mode        2       0-4       Write mode for paste
     res         1       0         Reserved

     Note: dispatch slot 102 records a fourth field, a single reserved
     digit, which this table previously omitted.  RIPlib gates on
     `len >= 7` accordingly.  (Slot 103 is the LOWERCASE '|1p', a
     different command taking one mega4.)


---------------------------------------------------------------------
3.7  RIP_BEGIN_TEXT — Begin Text Block Region
---------------------------------------------------------------------

     Function:     Begin Text Block
     Command:      |1T
     Arguments:    x0:XY y0:XY x1:XY y1:XY res:1 res:1
     Format:       !|1T<x0><y0><x1><y1><res><res>|

Defines a rectangular region for flowing text. Subsequent
RIP_REGION_TEXT commands ('t') render text lines within this
region, advancing the cursor downward after each line.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x0,y0       XY,XY   coords    Top-left of text region
     x1,y1       XY,XY   coords    Bottom-right
     res         1       0         Reserved (record field 5)
     stretch     1       0-1       Stretch to the icon-style box
                                      (bounded; above 1 the driver
                                      reports "Invalid stretch
                                      parameter" and draws nothing)

     Note: dispatch slot 105 splits the reserved tail into two single
     digits.  The total is unchanged at ten characters by default, so
     the wire bytes are the same and only the split differs; RIPlib
     reads the four coordinates and ignores both digits.


---------------------------------------------------------------------
3.8  RIP_REGION_TEXT — Text Line in Block
---------------------------------------------------------------------

     Function:     Render One Line of Text in Block
     Command:      |1t     (lowercase, Level 1 context)
     Arguments:    justify:1 text
     Format:       !|1t<justify><text>|

Renders a line of text within the active text block region.
Advances the Y cursor by one line height (16px for bitmap font).

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     justify     1       0-1       0=left, 1=justified
     text        var     ASCII     Text to render

Also appears as Level 0 't' in some protocol versions.


---------------------------------------------------------------------
3.9  RIP_END_TEXT — End Text Block
---------------------------------------------------------------------

     Function:     End Text Block
     Command:      |1E
     Arguments:    (none)
     Format:       !|1E|

Deactivates the current text block region.


---------------------------------------------------------------------
3.10  RIP_Scroll — Scroll a Region Vertically
---------------------------------------------------------------------

     Function:     Move a Screen Region Vertically
     Command:      |1G
     Arguments:    x0:XY y0:XY x1:XY y1:XY mode:1 excl:1 dest_y:XY
     Format:       !|1G<x0><y0><x1><y1><mode><excl><dest_y>|

CORRECTED from RIP_COPY_REGION, which is a different command — '|,'
at Level 0 (§4.5), ten coordinates.  This letter carried that name
too, so the name sat on two commands at once.

The handler (RVA 0x00D7E0) names itself RIP_Scroll in its own
diagnostics, and the export table already listed RIP_Scroll as
present and distinct from RIP_CopyBlit.  Its move is

     OffsetRect(&rect, 0, dest_y - y0)

with dx a hardcoded zero: the region moves vertically only, and
there is no destination X field.  That is why the record carries
one trailing coordinate rather than two, and why the twelve
characters here are not the fourteen previously documented.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x0,y0       XY      coords    Region top-left
     x1,y1       XY      coords    Region bottom-right
     mode        1       0-6       0 = plain move; 1-6 additionally
                                   run a post-scroll effect
     excl        1       0-1       0 = edges inclusive, non-zero =
                                   exclusive
     dest_y      XY      coords    Destination Y (scale_y)

The copy order flips on dest_y >= y0 so overlapping moves do not
smear.  A dest_y equal to y0 is a no-op ("Nothing to do"), and a
mode above 6 is rejected ("Invalid mode parameter").

RIPlib implements the move.  The mode 1-6 effect routines are
accepted but not performed; see D-14.


---------------------------------------------------------------------
3.11  RIP_LOAD_ICON — Load and Display Icon
---------------------------------------------------------------------

     Function:     Load Icon from Cache/Flash
     Command:      |1I
     Arguments:    x:XY y:XY mode:1 res:1 clipboard:1 stretch:1 res:1 filename
     Format:       !|1I<x><y><mode><res><clip><stretch><res><filename>|
     Example:      !|1I0A0F000000MYICON|

Looks up an icon by filename and displays it at (x,y).

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     x,y         XY,XY   coords    Display position
     mode        1       0-4       Write mode for blit
     res         1       0         Reserved (record field 4)
     clipboard   1       0-1       Copy to clipboard first
     res         1       0         Reserved (record field 6)
     res         1       0         Reserved (record field 7)
     filename    var     ASCII     Icon name (no extension)

     Note: dispatch slot 97 records FF FF 01 01 01 01 01 - after the
     two coordinates come FIVE single digits, not a 2-digit mode
     followed by a 1 and a 2.  The mode is one digit; reading it as
     mega2 spans the record's fields 3 and 4 and agrees only while
     field 4 is zero.  The filename offset is nine either way, which
     is why no shipped scene exposed the difference.

Lookup order:
     1. Flash-embedded BMP table (95 icons)
     2. Flash-embedded ICN table (3 icons)
     3. PSRAM runtime cache (64 entries)
     4. Not found → queue file request for BBS transfer


---------------------------------------------------------------------
3.12  RIP_WRITE_ICON — Write Icon to Storage
---------------------------------------------------------------------

     Function:     Write Icon to Runtime Cache
     Command:      |1W
     Arguments:    res:1 filename
     Format:       !|1W<res><filename>|

Stores the current image clipboard in RIPlib's runtime icon
cache under the given filename. Subsequent RIP_LOAD_ICON (|1I)
commands resolve the cached icon before requesting a host-side
file transfer. On embedded targets this is an in-memory cache,
not a persistent filesystem write.

     Note: dispatch slot 108 records a single mega1, so the fixed
     prefix is ONE character and the name starts at offset 1 - it is
     not an optional two-digit field.  RIPlib used to take the whole
     payload as the name and strip a leading "00" if it saw one, a
     heuristic that strips two where the record says one and strips
     nothing when the reserved digit is not '0'.  No corpus scene
     sends '|1W'.  See D-25.


---------------------------------------------------------------------
3.13  RIP_PLAY_AUDIO — Play Audio File
---------------------------------------------------------------------

     Function:     Select Article
     Command:      |1A
     Arguments:    article:2 res:4
     Format:       !|1A<article><res>|
     Example:      !|1A010000|      article=1

Selects which article (message, document) is current. The index is
bounded to 0-35 -- a 36-entry table, the same size as the port and
style tables -- and "Invalid article number" is reported above that.

**This is not an audio command.** It was documented and implemented as
RIP_PLAY_AUDIO until 2026-08-14. Slot 86 (RVA `0x00DC58`) loads ONE
argument, compares it against `0x24`, names itself `RIP_SelectArticle()`
in its own diagnostic, and never touches args[1] or any string. The
driver's real audio command is `|1w` (§3.21). "article" is a
document-navigation term throughout this driver --
`tvarProcOVERFLOW(article,PREV,SETVERBOSE)` sits beside "Beginning of
document". The single `|1A` in the shipped corpus is in NEWS.RIP and
selects article 1.

RIPlib records the index and emits nothing: choosing an article is a
session concept, not a rendering one. See 14-divergence-register.md
§14.5.

     Note: dispatch slot 86 records mega2 + mega4, so the fixed prefix
     is SIX characters and the filename starts there.  This mattered:
     NEWS.RIP sends "|1A010000" - exactly the six fixed characters and
     no filename at all - so reading the name from offset 2 took "00"
     as a filename and emitted a sound request for it.  That was the
     only host traffic any of the 35 corpus scenes produced during
     passive replay.  See D-25.

     The handler at slot 86 names itself RIP_SelectArticle in its own
     diagnostics, which does not match the RIP_PLAY_AUDIO reading this
     section documents.  The FIELD LAYOUT above is settled - both
     readings agree on mega2 + mega4 + string - but the SEMANTICS are
     not, and the name is recorded here rather than resolved.  See
     13-dll-command-table.md and 14-divergence-register.md 14.5.


---------------------------------------------------------------------
3.14  RIP_PLAY_MIDI — Play MIDI File
---------------------------------------------------------------------

     Function:     Play MIDI
     Command:      |1Z
     Arguments:    filename (free-form text)
     Format:       !|1Z<filename>|

Requests MIDI playback.  Forwarded to the host audio subsystem
via the TX FIFO; RIPlib itself does not synthesize MIDI.


---------------------------------------------------------------------
3.15  RIP_IMAGE_STYLE — Set Icon Display Mode
---------------------------------------------------------------------

     Function:     Set Icon/Image Display Mode
     Command:      |1S
     Arguments:    mode:2
     Format:       !|1S<mode>|

Sets the display mode for subsequent icon blits (normal,
stretched, tiled, etc.).


---------------------------------------------------------------------
3.16  RIP_SET_ICON_DIR — Set Icon Search Directory
---------------------------------------------------------------------

     Function:     Set Icon Directory
     Command:      |1N
     Arguments:    res:2 path
     Format:       !|1N<res><path>|

Sets the search directory for icon file lookups. Stored as a
prefix for filename resolution.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     res         2       0         Reserved
     path        var     ASCII     Directory path (max 63 chars)

     Note: '|1N' has NO dispatch entry - it is RIPlib-original.  The
     driver's only 'N' is at slot 48, which is LEVEL 0 '|N'
     RIP_SetBorder (see 04-extended-commands.md 4.22); it takes one
     mega2 and has nothing to do with icon paths.  The res:2 prefix
     documented above is RIPlib's own convention, not a record being
     conformed to.  See 14-divergence-register.md 14.3.9.

     RIPlib filters the wire-supplied path before storing it -
     directories are allowed, but '..', control characters, '\' and
     ':' are rejected.  A consumer that opens the path must still
     treat it as untrusted.  See C-013 / ADR-0003.


---------------------------------------------------------------------
3.17  RIP_FILE_QUERY — Query File Existence
---------------------------------------------------------------------

     Function:     Query File on Client
     Command:      |1F
     Arguments:    mode:2 res:4 filename
     Format:       !|1F<mode><res><filename>|
     Example:      !|1F000000MYFONT.CHR|

Queries whether a file exists on the client. The client responds
via the TX queue with the result.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     mode        2       0-3       Query type
     res         4       0         Reserved
     filename    var     ASCII     File to check

Mode values:
     0: Check if file exists
     1: Check if file exists and return size
     2: Request file transfer (initiates Zmodem)


---------------------------------------------------------------------
3.18  RIP_DEFINE — Define Text Variable
---------------------------------------------------------------------

     Function:     Define Application Variable
     Command:      |1D
     Arguments:    flags:3 res:2 text
     Format:       !|1D<flags><res><name>=<value>|
     Example:      !|1D00000MYVAR=Hello World|

Defines a text variable that can be expanded in subsequent
text commands via $MYVAR$ syntax. Stored in the application
variable table (APP0-APP9 for indexed access).

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     flags       3       0-46655   Definition flags
     res         2       0         Reserved
     text        var     ASCII     name[,width]:?prompt?[default]

     Note: dispatch slot 96 records mega3 + mega2, so FIVE fixed
     characters precede the text and the variable name starts at
     offset 5.  The record types only the numeric array; the trailing
     string is passed out of band, which is why the record's fixed
     total is exactly the string's offset.


---------------------------------------------------------------------
3.19  RIP_FONT_LOAD — Load Font File
---------------------------------------------------------------------

     Function:     Load Font
     Command:      |1O
     Arguments:    filename (free-form text)
     Format:       !|1O<filename>|
     Example:      !|1OMYFONT.CHR|

Requests loading of a BGI CHR or RFF font file. If the filename
matches one of RIPlib's built-in BGI fonts, that font becomes the
current font. Otherwise the filename is queued as a host-side file
request so an embedding application can provide a custom font.

     Note: '|1O' has NO dispatch entry in RIPSCRIP.DLL - the driver's
     26 Level 1 slots do not include the letter 'O'.  There is
     therefore no record to conform to and no reserved prefix; RIPlib
     reads the whole payload as the filename, tolerating a leading
     "00" if one is present.  See 14-divergence-register.md 14.3.9.


---------------------------------------------------------------------
3.20  RIP_QUERY_EXT — Extended Query
---------------------------------------------------------------------

     Function:     Extended Query Command
     Command:      |1Q
     Arguments:    flags:3 res:2 varname
     Format:       !|1Q<flags><res><varname>|

Extended version of the query system. Routes to the same
handler as the ESC-based QUERY command but with additional
flags for response formatting.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     flags       3       0-46655   Query flags
     res         2       0         Reserved
     varname     var     ASCII     Variable name to query



---------------------------------------------------------------------
3.21  RIP_PlayAudio — Play an Audio File
---------------------------------------------------------------------

     Function:     Play Audio
     Command:      |1w     (lowercase)
     Arguments:    mode:1 res:3 filename
     Format:       !|1w<mode><res><filename>|
     Example:      !|1w0000CHIME.WAV|

Requests playback of an audio file. RIPlib has no built-in audio path;
consumers receive the filename via the TX FIFO, prefixed with the
CMD_PLAY_SOUND marker, and dispatch it to their own sound subsystem.

     Parameter   Width   Range     Description
     ---------   -----   -------   -----------
     mode        1       0-35      Playback mode
     res         3       0         Reserved
     filename    var     ASCII     File to play, or the literal $OFF$

     The literal string `$OFF$` in place of a filename STOPS playback
     rather than naming a file.  Slot 109's handler (RVA `0x00D24E`)
     compares the string tail against `$OFF$` before doing anything
     else with it.  RIPlib forwards that as an empty name, which is
     this library's spelling of "stop".

     This section did not exist until 2026-08-14, and the command was
     a bare `break` in the parser, because the audio path had been
     attached to `|1A` — which is article selection (§3.13).  The two
     were swapped.  Slot 109 is the one that pushes the name string
     `RIP_PlayAudio` on its error path, and this driver imports
     `sndPlaySoundA` and `PlaySoundA` from WINMM.  No corpus scene
     sends `|1w`.  See 14-divergence-register.md §14.5.

=====================================================================
==                    END OF SEGMENT 3                              ==
==           Level 1 Interactive Commands                           ==
=====================================================================

Next: Segment 4 — Extended Commands (v2.0+)

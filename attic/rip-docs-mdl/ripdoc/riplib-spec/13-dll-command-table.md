
=====================================================================
==      SEGMENT 13: THE DLL COMMAND DISPATCH TABLE (VERBATIM)      ==
=====================================================================

Extracted from RIPSCRIP.DLL (MD5 bade8b1f4e467ac7ad4edb2639738d4c; the
binary self-reports version 3.00.04 — see segment 12, "Version labelling")
at RVA 0x080820 - 129 entries, 40 bytes each.  Read the raw record with:

     python scripts/dll-dispatch-table.py <path>/RIPSCRIP.DLL

That script prints the record in its own compact layout; it does not
emit this file's formatting, so it is a cross-check rather than a
generator.  To check THIS file against the binary field by field, use
scripts/check-dll-table.py (see "Verify" below).

This is a RECORD OF THE BINARY, not an interpretation of it.  Command
NAMES come from a separate evidence class: each handler that can
report an error pushes its own name string before calling the error
reporter, so the name is recovered from the handler's own code (see
segment 12, class B/C, and scripts/dll-name-handlers.py).  A '-' means
the handler has no error path and therefore carries no name string --
it is NOT a claim that the command is nameless.  Five further handlers
are unnamed because the address bound swept in neighbouring helpers and
attribution was ambiguous; those are left blank rather than guessed.

Entry layout:  [+0] index  [+1..4] handler ptr  [+15] letter
               [+16..19] argc (signed; negative = variable-length)
               [+20..] argument type codes

A CMD shown as 0x00 is not a command: it is an additional accepted
ARGUMENT SIGNATURE for the letter immediately above it, sharing the
same handler.  The driver selects among them by how many arguments
the stream supplies.  See segment 12 section 12.11.

Argument types:  XY     coordinate pair, width per SET_COORDINATE_SIZE
                 color  colour value, width per SET_COLOR_MODE
                 megaN  N-digit MegaNum

An ARGC of 0 with no argument types does NOT mean the command takes no
payload.  The record types only what passes through the numeric
argument array; a handler is free to read the raw payload itself, and
'|T' (slot 60) does exactly that - argc 0, no types, and a body that
parses a string.  Thirteen slots are argc-0-with-no-types.

Three of those thirteen have a handler that is a BARE RET, one byte,
so the driver accepts the command and does nothing at all:

     slot   0   '|!'    0x01ad36
     slot   4   '|('    0x01ca84
     slot  27   '|F'    0x01b2fd     <- flood fill

The rest have real bodies.  '|F' is the consequential one: FLOOD FILL
IS A NO-OP IN THIS DRIVER.  RIPlib implements it from the v1.54 spec
instead, taking x, y and border as three two-digit fields; see
14-divergence-register.md 14.3.10.

Validation: all 129 handler pointers resolve inside .text, and the
independently recorded anchor RIP_BOUNDED_TEXT ('"' -> RVA 0x01A0DA)
matches slot 1 exactly.

Levels below are assigned by CONTIGUOUS SLOT RUN, which is an
inference, not a field in the record - the entry format carries no
level byte.  The resulting split is 85/25/12/7:

     level 0    slots   0 ..  84     85 records
     level 1    slots  85 .. 109     25 records
     level 2    slots 110 .. 121     12 records
     level 3    slots 122 .. 128      7 records

It is not identical with the 80/25/19/5 reported by the original
reconstruction, so treat the level column as provisional and the
letter/handler/arity columns as the actual evidence.

Record counts exceed distinct-letter counts because of the
continuation rows described in 12.11 - level 0 carries eleven, and
levels 1 to 3 one apiece for their ESC form.

A HANDLER ADDRESS BAND was tried first and rejected.  It agrees with
the slot runs on 128 of 129 records and disagrees on exactly one:
slot 48, whose handler at 0x00dcf1 lies among the level-1 handlers
(0x00a529..0x00dd67) while every other level-0 handler lies in
0x019b50..0x02102c.  Three independent things place that record at
level 0 regardless of where its code sits:

  * its slot number falls inside level 0's run, and levels are
    otherwise perfectly contiguous;
  * the handler names ITSELF RIP_SetBorder, and RIP_SET_BORDER is a
    level-0 command; and
  * it types one mega2, which is exactly the 'borders:2' that
    level-0 '|N' takes.

So slot 48 is level 0 '|N', and the address band is what misfires -
the handler simply lives in a different code region from its
neighbours.  Earlier revisions of this file assigned it to level 1 as
'|1N' and reported the split as 83/26/12/8 and then 84/26/12/7; both
were wrong, and both were arrived at by grouping the rows by this
file's own level column and then measuring the groups, which cannot
discover a misplaced row.

RIPlib's own '|1N' RIP_SET_ICON_DIR is a separate, RIPlib-original
command with no dispatch entry - see 14-divergence-register.md 14.3.9.

Verify this file against the binary with:

     python scripts/check-dll-table.py <path>/RIPSCRIP.DLL


---------------------------------------------------------------------
13.1  LEVEL 0   (85 commands)
---------------------------------------------------------------------

   SLOT  CMD    HANDLER    ARGC  NAME                     ARGUMENT TYPES
      0  |!    0x01ad36     0  -                        -
      1  |"    0x01a0da     5  -                        XY, XY, XY, XY, mega2
      2  |#    0x01cf6a     0  -                        -
      3  |&    0x01f904     5  -                        XY, XY, mega2, mega2, mega2
      4  |(    0x01ca84     0  -                        -
      5  |)    0x01ca85     0  -                        -
      6  |*    0x01f2f9     0  -                        -
      7  |+    0x01fca6     7  -                        XY, XY, XY, XY, mega2, mega2, mega2
      8  |,    0x01d5c2    10  -                        XY, XY, XY, XY, XY, XY, XY, XY, XY, XY
      9  |-    0x01c348     5  -                        XY, XY, XY, XY, mega2
     10  |.    0x01d79b     6  -                        XY, XY, XY, XY, XY, XY
     11  |:    0x01dd70    11  -                        XY, XY, XY, XY, XY, XY, XY, XY, XY, XY, mega1
     12  |;    0x01e4ff     7  RIP_PolyMarker           XY, XY, mega2, XY, XY, mega2, mega2
     13  |<    0x01e80a   var  -                        mega2, mega2, XY, XY
     14  |=    0x01cd15     4  RIP_LineStyle            mega1, mega1, mega4, mega2
     15  |>    0x01ad37     0  -                        -
     16  |@    0x020cbc     2  RIP_TextXY               XY, XY
     17  |A    0x019b50     5  -                        XY, XY, mega2, mega2, XY
     18  |a    0x01d135     2  RIP_OnePalette           mega2, mega2
     19  |B    0x019d9e     4  -                        XY, XY, XY, XY
     20  |b    0x01b075     9  RIP_ExtendedTextWindow   XY, XY, XY, XY, mega2, mega2, mega1, mega4, 0x03
     21  |C    0x01aa3e     3  -                        XY, XY, XY
     22  |c    0x01abf0     1  -                        color
     23  |D    0x01f46a   var  RIP_SetDrawingPalette    mega2, mega2, mega1, mega4
     24  |d    0x01cf95     3  RIP_OneDrawingPalette    mega2, mega1, mega4
     25  |E    0x01ad6f     0  -                        -
     26  |e    0x01ad98     0  -                        -
     27  |F    0x01b2fd     0  -                        -
     28  |f    0x01f874     2  RIP_SetWorldFrame        XY, XY
     29  |G    0x01b2fe     3  -                        XY, XY, XY
     30  |g    0x01ca92     2  -                        XY, XY
     31  |H    0x01cb18     0  -                        -
     32  |h    0x01cae1     3  -                        mega2, mega4, mega2
     33  |0x00 0x01cae1     3  -                        mega1, mega2, mega1
     34  |0x00 0x01cae1     3  -                        mega1, mega4, mega1
     35  |0x00 0x01cae1     5  -                        mega1, mega4, mega1, mega1, mega1
     36  |0x00 0x01cae1     2  -                        mega1, mega2
     37  |0x00 0x01cae1     2  -                        mega1, mega2
     38  |I    0x01e066     5  -                        XY, XY, mega2, mega2, XY
     39  |i    0x01dc59     6  -                        XY, XY, mega2, mega2, XY, XY
     40  |J    0x01f32e     1  RIP_SetBaseMath          mega2
     41  |j    0x01e2f8     2  -                        XY, XY
     42  |K    0x01bee5     4  -                        XY, XY, XY, XY
     43  |k    0x019cd0     1  RIP_BackColor            color
     44  |L    0x01cb79     4  -                        XY, XY, XY, XY
     45  |l    0x01ed28   var  -                        mega2, XY
     46  |M    0x01f3fd     2  RIP_SetColorMode         mega1, mega1
     47  |m    0x01cef0     2  -                        XY, XY
     48  |N    0x00dcf1     1  RIP_SetBorder            mega2
     49  |n    0x01f39f     2  RIP_SetCoordinateSize    mega1, 0x03
     50  |O    0x01d297     6  -                        XY, XY, mega2, mega2, XY, XY
     51  |o    0x01b542     4  -                        XY, XY, XY, XY
     52  |P    0x01eb03   var  RIP_Polygon              mega2, XY
     53  |p    0x01bc78   var  RIP_FilledPolygon        mega2, XY
     54  |Q    0x01f6a7    16  RIP_SetPalette           mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2
     55  |q    0x01c799     1  RIP_FontAttrib           mega2
     56  |R    0x01ef4d     4  -                        XY, XY, XY, XY
     57  |r    0x020371     3  RIP_TextMetric           mega1, mega1, mega4
     58  |S    0x01c679     2  RIP_FillStyle            mega2, color
     59  |s    0x01c55f     9  RIP_FillPattern          mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, color
     60  |T    0x020169     0  -                        -
     61  |t    0x01e4a4     2  -                        mega2, mega2
     62  |0x00 0x01e4a4     3  -                        mega1, XY, XY
     63  |0x00 0x01e4a4     7  -                        mega1, XY, XY, XY, XY, XY, XY
     64  |U    0x01f108     5  -                        XY, XY, XY, XY, XY
     65  |u    0x01c0fe     5  -                        XY, XY, XY, XY, XY
     66  |V    0x01d497     6  -                        XY, XY, mega2, mega2, XY, XY
     67  |v    0x020f87     4  RIP_ViewPort             XY, XY, XY, XY
     68  |W    0x02102c     1  RIP_WriteMode            mega2
     69  |w    0x0209cf     6  RIP_TextWindow           mega2, mega2, mega2, mega2, mega1, mega1
     70  |X    0x01e1d1     2  -                        XY, XY
     71  |x    0x01bc1d     2  -                        mega2, mega2
     72  |0x00 0x01bc1d     3  -                        mega1, XY, XY
     73  |0x00 0x01bc1d     7  -                        mega1, XY, XY, XY, XY, XY, XY
     74  |Y    0x01c87e     4  RIP_FontStyle            mega2, mega2, mega2, mega2
     75  |y    0x01adc0    11  RIP_ExtendedFontStyle    mega1, mega1, mega4, mega2, mega2, mega2, mega2, mega2, mega2, mega2, 0x06
     76  |Z    0x019f7b     9  -                        XY, XY, XY, XY, XY, XY, XY, XY, mega2
     77  |z    0x01e449     2  -                        mega2, mega2
     78  |0x00 0x01e449     3  -                        mega1, XY, XY
     79  |0x00 0x01e449     7  -                        mega1, XY, XY, XY, XY, XY, XY
     80  |[    0x01fee1     7  -                        XY, XY, XY, XY, mega2, mega2, mega2
     81  |]    0x01fac7     7  -                        XY, XY, XY, XY, mega2, mega2, mega2
     82  |_    0x01bb18     6  -                        XY, XY, mega2, mega2, XY, XY
     83  |`    0x01d963    11  -                        XY, XY, XY, XY, XY, XY, XY, XY, XY, XY, mega1
     84  |{    0x01b89b     6  -                        XY, XY, XY, XY, XY, XY


---------------------------------------------------------------------
13.2  LEVEL 1 (prefix '1')   (25 commands)
---------------------------------------------------------------------

   SLOT  CMD    HANDLER    ARGC  NAME                     ARGUMENT TYPES
     85  |1ESC  0x00d3da     3  rip_query                mega1, mega1, mega2
     86  |1A    0x00dc58     2  RIP_SelectArticle        mega2, mega4
     87  |1B    0x00b325    16  RIP_ButtonStyle          XY, XY, mega2, mega4, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega2, mega1, 0x05
     88  |1b    0x00c569     9  RIP_LoadBitmap           XY, XY, XY, XY, mega1, mega1, mega2, mega2, mega4
     89  |1C    0x00c1cf     5  -                        XY, XY, XY, XY, mega1
     90  |1c    0x00dc96     2  RIP_SetMouseCursor       mega2, mega4
     91  |1D    0x00bd39     2  RIP_Define               0x03, mega2
     92  |1E    0x00bdbd     0  -                        -
     93  |1e    0x00a5ed     9  RIP_BeginExtendedText    XY, XY, XY, XY, mega1, mega1, mega4, mega2, 0x08
     94  |1F    0x00bde4     2  RIP_FileQuery            mega2, mega4
     95  |1G    0x00d7e0     7  -                        XY, XY, XY, XY, mega1, mega1, XY
     96  |1g    0x00b7a4     8  -                        XY, XY, XY, XY, XY, XY, mega1, mega1
     97  |1I    0x00cb38     7  RIP_LoadIcon             XY, XY, mega1, mega1, mega1, mega1, mega1
     98  |1i    0x00c39a     6  RIP_ImageStyle           XY, XY, XY, XY, mega4, 0x0c
     99  |1K    0x00c543     0  -                        -
    100  |1k    0x00c474     5  -                        XY, XY, XY, XY, mega4
    101  |1M    0x00cef8     9  RIP_Mouse                mega2, XY, XY, XY, XY, mega1, mega1, mega2, 0x03
    102  |1P    0x00d32f     4  -                        XY, XY, mega2, mega1
    103  |1p    0x00c2c6     1  -                        mega4
    104  |1R    0x00d64d     2  -                        mega2, 0x06
    105  |1T    0x00a529     6  RIP_BeginText            XY, XY, XY, XY, mega1, mega1
    106  |1t    0x00d70b     1  -                        mega1
    107  |1U    0x00a952     7  RIP_Button               XY, XY, XY, XY, mega2, mega1, mega1
    108  |1W    0x00dd67     1  -                        mega1
    109  |1w    0x00d24e     2  -                        mega1, 0x03


---------------------------------------------------------------------
13.3  LEVEL 2 (prefix '2')   (12 commands)
---------------------------------------------------------------------

   SLOT  CMD    HANDLER    ARGC  NAME                     ARGUMENT TYPES
    110  |2ESC  0x046f66     1  RIP_SwitchDirectory      mega4
    111  |2A    0x046c64     2  RIP_SwitchPalette        mega1, mega2
    112  |2B    0x046d08     2  RIP_SwitchButtonStyle    mega1, mega2
    113  |2C    0x046372    12  RIP_PortCopy             mega1, XY, XY, XY, XY, mega1, XY, XY, XY, XY, mega1, 0x05
    114  |2E    0x046da0     2  RIP_SwitchEnvironment    mega1, mega2
    115  |2P    0x0466ec     7  RIP_PortDefine           mega1, XY, XY, XY, XY, mega4, mega4
    116  |2p    0x046862     3  RIP_PortDelete           mega1, mega1, mega2
    117  |2R    0x046bd9     1  -                        mega4
    118  |2s    0x0468eb     2  RIP_SwitchPort           mega1, mega2
    119  |2T    0x046ece     2  RIP_SwitchTextWindow     mega1, mega2
    120  |2W    0x04699a     7  RIP_PortWrite            mega1, XY, XY, XY, XY, mega2, mega2
    121  |2Y    0x046e41     2  -                        mega1, mega2


---------------------------------------------------------------------
13.4  LEVEL 3 (prefix '3')   (7 commands)
---------------------------------------------------------------------

   SLOT  CMD    HANDLER    ARGC  NAME                     ARGUMENT TYPES
    122  |3D    0x038bd2     1  -                        mega4
    123  |3e    0x038be1     1  -                        mega2
    124  |3ESC  0x024b4e     5  -                        mega1, mega1, mega2, mega2, mega2
    125  |3D    0x024af4     1  -                        mega4
    126  |3G    0x0251cb     1  RIP_GotoURL              0x08
    127  |3R    0x0252f2     3  -                        mega4, mega2, 0x08
    128  |3U    0x0252c0     2  RIP_BeginEncodedStream   mega2, mega4


---------------------------------------------------------------------
13.5  RECOVERED FIELD SEMANTICS
---------------------------------------------------------------------

Each handler validates its arguments and, on failure, pushes a
diagnostic naming the field that was wrong.  Those strings identify
the arguments without guesswork -- '|d' names all three of its own
fields this way.  Regenerate with:

     python scripts/dll-handler-semantics.py <path>/Ripscrip.dll

CAVEAT: handler bounds are upper bounds, so a following helper's
strings can occasionally bleed into an entry.  Treat a diagnostic
that does not fit the command as bleed, not as evidence.

   |"   (0x01a0da, argc=5)
        - Cannot created bounded text with old-style system fonts
        - Unable to allocate temp string
        - Width of bounding box is zero - cannot draw text
        - Height of bounding box is zero - cannot draw text
        - Width of font is zero
        - Height of font is zero
        - Can't fit text in box.  Box is too small

   |;   (0x01e4ff, argc=7)
        - Invalid marker number
        - Invalid marker rotation angle (>=360)
        - Invalid marker flags value

   |<   (0x01e80a, argc=var)
        - Insufficient vertices
        - Must have at least two vertices to make a polygon
        - Insufficient vertices (2)

   |=   (0x01cd15, argc=4)
        - Illegal line type
        - Can't have a custom line style with no on bits
        - Invalid line style flags
        - Can't modify current graphics style - its protected!
        - Insufficient memory for new line style pen

   |@   (0x020cbc, argc=2)
        - Can't draw to a disabled viewport
        - Unable to allocate temp string
        - Missing string parameter

   |a   (0x01d135, argc=2)
        - Invalid Color Parameter
        - Can't modify current color palette - its protected!

   |b   (0x01b075, argc=9)
        - Flags value is out of range
        - Font number is out of range
        - Zero width value is not allowed
        - Zero height value is not allowed
        - Can't modify current text window
        - Illegal bounding rectangle
        - Can't create text windows in offscreen ports
        - Text window is completely out of bounds

   |c   (0x01abf0, argc=1)
        - Invalid Drawing Color
        - Can't modify current protected graphics style
        - Insufficient memory to create new colored pen

   |D   (0x01f46a, argc=var)
        - Invalid number of parameters
        - More than 256 entries
        - Start is out of range
        - Invalid number of bits
        - Palette slot is protected
        - Illegal RGB value

   |d   (0x01cf95, argc=3)
        - Color palette index out of range
        - Bits value out of range
        - RGB Color value is out of range!
        - Can't modify current color palette - its protected!
        - Specified color is out of color range

   |f   (0x01f874, argc=2)
        - Invalid Number of Parameters!
        - Can't modify current environment - its protected!

   |J   (0x01f32e, argc=1)
        - Can't modify current environment - its protected!

   |j   (0x01e2f8, argc=2)
        - Unable to create temp brush

   |k   (0x019cd0, argc=1)
        - Invalid Color Value!
        - Can't modify current graphics style - its protected!

   |l   (0x01ed28, argc=var)
        - Insufficient parameters
        - Wrong number of parameters
        - Can't draw to a disabled viewport

   |M   (0x01f3fd, argc=2)
        - Can't modify current environment - its protected!

   |1N   (0x00dcf1, argc=1)
        - Can't modify current graphics style - its protected

   |n   (0x01f39f, argc=2)
        - Can't modify current environment - its protected!

   |P   (0x01eb03, argc=var)
        - Insufficient parameters
        - Wrong number of parameters
        - Can't draw to a disabled viewport

   |p   (0x01bc78, argc=var)
        - Insufficient parameters
        - Wrong number of parameters
        - Can't draw to a disabled viewport

   |Q   (0x01f6a7, argc=16)
        - Can't modify current color palette - its protected!
        - Failed to set palette entries
        - Invalid Color Parameter

   |q   (0x01c799, argc=1)
        - Graphics style is protected
        - Invalid font attributes
        - Font attributes not supported for system fonts

   |r   (0x020371, argc=3)
        - Invalid text metric mode
        - Invalid text metric domain
        - Insufficient memory

   |S   (0x01c679, argc=2)
        - Invalid Color Value!
        - Can't modify current graphics style - its protected!

   |s   (0x01c55f, argc=9)
        - Invalid Color Value
        - Can't modify current graphics style - its protected!

   |v   (0x020f87, argc=4)
        - Port can't be modified - it's protected!

   |W   (0x02102c, argc=1)
        - Invalid argument
        - Can't modify current graphics style - its protected!

   |w   (0x0209cf, argc=6)
        - Invalid font typeface
        - Invalid flag value
        - Can't modify text window - its protected
        - Invalid row/column value(s)
        - Row/column values are backwards

   |Y   (0x01c87e, argc=4)
        - Illegal font number
        - Illegal direction
        - Can't modify current graphics style - its protected!
        - Too many horizontal flags
        - Too many vertical flags
        - Illegal font size

   |y   (0x01adc0, argc=11)
        - Can't modify current graphics style - its protected!
        - Illegal string rotation!
        - Character spacing percentage cannot be zero!
        - String justification out of range!
        - Invalid String shadow!
        - Unable to allocate temp string
        - No typeface name specified!

   |1ESC   (0x00d3da, argc=3)
        - Unable to allocate temp string
        - Illegal viewport slot number
        - Port isn't in use - cannot set query
        - Port is protected - can't define query
        - Illegal text window slot number
        - Text window isn't in use - cannot set query
        - Text window is protected - can't define query
        - Invalid string parameter

   |1A   (0x00dc58, argc=2)
        - Invalid article number

   |1B   (0x00b325, argc=16)
        - Invalid label orientation
        - Invalid label foreground color
        - Invalid label background color
        - Invalid bright button color
        - Invalid dark button color
        - Invalid surface button color
        - Invalid group number
        - Invalid flags2 value

   |1b   (0x00c569, argc=9)
        - Can't draw to a disabled viewport
        - Invalid flags parameter
        - Invalid color value
        - Unable to allocate temp string
        - Invalid string parameter

   |1c   (0x00dc96, argc=2)
        - Can't modify current environment - its protected!

   |1D   (0x00bd39, argc=2)
        - Unable to allocate temp string
        - Invalid string parameter

   |1e   (0x00a5ed, argc=9)
        - Invalid column number
        - Invalid flags value
        - Unable to allocate temp string
        - Invalid highlight color
        - No search words encountered
        - Too many search words (8 max)
        - Search word too long (>16 characters)
        - Invalid word search list

   |1F   (0x00bde4, argc=2)
        - Invalid mode parameter
        - Unable to allocate temp string
        - Invalid string parameter

   |1G   (0x00d7e0, argc=7)
        - Nothing to do
        - Invalid mode parameter
        - Unable to create solid brush 0

   |1g   (0x00b7a4, argc=8)
        - Illegal mode parameter

   |1I   (0x00cb38, argc=7)
        - Invalid stretch parameter
        - Unable to allocate temp string
        - Invalid Parameter!
        - Invalid string parameter

   |1i   (0x00c39a, argc=6)
        - Invalid flags parameter

   |1M   (0x00cef8, argc=9)
        - Too Many Mouse Fields
        - No Mouse Fields in Offscreen Ports
        - Unable to allocate temp string
        - Can't create mouse fields on a disabled viewport
        - Hotkey out of range
        - Mouse field outside of viewport
        - Invalid string parameter

   |1p   (0x00c2c6, argc=1)
        - Unable to allocate temp string
        - Invalid image filename

   |1R   (0x00d64d, argc=2)
        - Unable to allocate temp string
        - Invalid string parameter

   |1T   (0x00a529, argc=6)
        - Invalid column number
        - Invalid article number

   |1t   (0x00d70b, argc=1)
        - Unable to allocate temp string

   |1U   (0x00a952, argc=7)
        - Missing string parameter
        - Invalid hotkey parameter
        - Illegal Flags value
        - Cannot create buttons on an offscreen port
        - No Button Style Loaded
        - RIPscrip Error
        - No Clipboard in use!
        - Too Many Mouse Fields

   |1W   (0x00dd67, argc=1)
        - Unable to allocate temp string
        - An illegal slot value was specified
        - Provided slot number was invalid
        - Source entry cannot equal the destination entry
        - Destination entry is in use and is protected
        - The source entry isn't in use - can't perform the copy
        - One or both of the entries contain illegal values

   |1w   (0x00d24e, argc=2)
        - Unable to create temp buffer
        - Invalid string parameter

   |2ESC   (0x046f66, argc=1)
        - Unable to create temp string
        - String too long for a directory
        - Illegal characters in string parameter
        - Invalid character in host directory
        - Invalid string combination in host directory
        - Invalid string parameter
        - Can't load Windows OEM system font
        - RIPscrip Initialization Failure

   |2A   (0x046c64, argc=2)
        - Invalid palette slot number

   |2B   (0x046d08, argc=2)
        - Illegal button style slot number

   |2C   (0x046372, argc=12)
        - Invalid port number
        - Invalid destination port number
        - Invalid write mode
        - Source portBitmap is NULL
        - Destination portBitmap is NULL
        - Source port not in use - cant Copy Port!
        - Destination port not in use - cant Copy Port!
        - Source rectangle is invalid!

   |2E   (0x046da0, argc=2)
        - Illegal environment slot number

   |2P   (0x0466ec, argc=7)
        - Protected port can't be redefined!
        - Failed to initialize port!
        - Port number is out of Range!

   |2p   (0x046862, argc=3)
        - Invalid port number
        - Invalid destination port number

   |2R   (0x046bd9, argc=1)
        - Unable to allocate temp string

   |2s   (0x0468eb, argc=2)
        - Port parameter is out of range!

   |2T   (0x046ece, argc=2)
        - Illegal text window slot number

   |2W   (0x04699a, argc=7)
        - Invalid filename length
        - Invalid port number
        - Drawing port is not in use
        - Specified rectangle is empty
        - Invalid bitmap filename

   |3e   (0x038be1, argc=1)
        - Cannot protect style slot #0
        - Cannot protect graphical style slot #0
        - Current style slot is protected
        - Slot is protected X
        - Graphics Style Slot #%d is protected - cannot delete

   |3ESC   (0x024b4e, argc=5)
        - Unable to allocate temp string
        - Invalid Filename string
        - Invalid Transfer Type
        - Invalid Parameter

   |3G   (0x0251cb, argc=1)
        - No URL string present
        - Unable to create temp string
        - Invalid URL character found
        - URL too long

   |3R   (0x0252f2, argc=3)
        - Invalid RIPscrip Instance
        - Can't register text variable - invalid variable name
        - Insufficient memory to compact text variable table
        - Insufficient memory for text variable name
        - Insufficient memory to expand text variable table

   |3U   (0x0252c0, argc=2)
        - Illegal type parameter 1


=====================================================================
==                    END OF SEGMENT 13                             ==
==            The DLL Command Dispatch Table (Verbatim)             ==
=====================================================================

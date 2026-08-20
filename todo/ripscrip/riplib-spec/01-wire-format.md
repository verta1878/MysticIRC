
             ------------------------------------------
              RIPscrip Graphics Protocol Specification
                    "Remote Imaging Protocol"

             Version 3.1 — Complete Reference

                    Copyright (c) 1993-1997
                TeleGrafix Communications, Inc.

                    v3.1 / v3.2 Extensions (c) 2026
                    SimVU (Brad Hawthorne)

                     Protocol ID:   RIPSCRIP032001
                     Library:       RIPlib v2.0.1

                        May 2026
             ------------------------------------------


=====================================================================
==           SEGMENT 1: WIRE FORMAT & ENCODING                     ==
=====================================================================

This segment documents the byte-level wire format of the RIPscrip
protocol: how commands are framed, how parameters are encoded, and
how the client detects and enters RIPscrip mode.


---------------------------------------------------------------------
1.1  PROTOCOL OVERVIEW
---------------------------------------------------------------------

RIPscrip (Remote Imaging Protocol script) is a terminal graphics
protocol designed for BBS (Bulletin Board System) communication.
A remote BBS host sends RIPscrip commands embedded in the terminal
data stream. The client parses these commands and renders vector
graphics, text, and interactive UI elements locally.

The protocol operates as an in-band signaling layer on top of any
byte-oriented serial or TCP connection. RIPscrip commands coexist
with ANSI/VT100 text — the client switches between text rendering
and RIPscrip command parsing based on trigger sequences.

Protocol versions:

     Version   Year   Protocol ID         Notes
     -------   ----   ------------------  --------------------------
     v1.54     1993   RIPSCRIP015400      Original specification
     v2.0      1995   RIPSCRIP020000      Drawing Ports, extended cmds
     v3.0      1997   RIPSCRIP030001      DLL-based, never published
     v3.1      2026   RIPSCRIP031001      §A2G.1-7 (RIPlib)
     v3.2      2026   RIPSCRIP032001      §A2G.8-13 (QoL refinements)


---------------------------------------------------------------------
1.2  COMMAND FRAME FORMAT
---------------------------------------------------------------------

Every RIPscrip command begins with a trigger byte and ends with a
frame terminator. The general format is:

     !|<level><cmd><parameters>|

Where:
     !       Command trigger (0x21, ASCII exclamation mark)
     |       Frame delimiter (0x7C, ASCII pipe)
     level   Routing prefix (see §1.3)
     cmd     Single ASCII character identifying the command
     params  Zero or more MegaNum-encoded values (see §1.5)
     |       Frame terminator (0x7C)

Example — draw a line from (100,50) to (200,150):

     Wire:     !  |  L  2  S  1  E  5  K  4  6  |
     Hex:      21 7C 4C 32 53 31 45 35 4B 34 36 7C
     Decoded:  !  |  L  x0=100  y0=50  x1=200  y1=150  |

The leading '!' must appear at a line boundary (after CR, LF, FF,
or at the start of the data stream). This prevents false triggers
from '!' characters in normal text.

Multiple commands may be chained within a single frame:

     !|cmd1|cmd2|cmd3|

The parser processes each '|'-terminated segment as a separate
command. The leading '!' applies to the entire chain.


---------------------------------------------------------------------
1.3  LEVEL ROUTING
---------------------------------------------------------------------

Commands are organized into levels. The first character(s) after
'|' determine the routing:

     Prefix    Level   Description
     ------    -----   -----------
     (none)    0       Core drawing commands (v1.54)
     1         1       Interactive commands (v1.54)
     2         2       Drawing Port system (v2.0+)
     9         3       Reserved for future use

**Note (implementation):** RIPlib parses and tracks a Level 3 routing state
internally for forward compatibility with future protocol revisions. No
command letters are currently assigned to Level 3, and unrecognized Level 3
commands are silently dropped rather than triggering an error. The exact
prefix byte that selects Level 3 is currently under reconciliation between
this spec table and the implementation (tracked as candidate C-010 in
`design/decisions.md`); consumers should not yet rely on Level 3 routing
in production wire streams.

Level 0 commands have NO prefix — the command letter immediately
follows the '|' delimiter:

     !|L2S1E5K46|          Level 0: RIP_LINE

Level 1 commands are prefixed with '1':

     !|1B0200....|         Level 1: RIP_BUTTON_STYLE

Level 2 commands are prefixed with '2':

     !|2P10A000K0U|        Level 2: RIP_DEFINE_PORT


---------------------------------------------------------------------
1.4  COMMAND LETTERS
---------------------------------------------------------------------

Each command is identified by a single ASCII character. The same
letter may have different meanings at different levels:

     Level 0 'C' = RIP_CIRCLE
     Level 1 'C' = RIP_GET_IMAGE (clipboard copy)
     Level 2 'C' = RIP_PORT_COPY

Command letters are case-sensitive:

     Level 0 'O' = RIP_OVAL (elliptical arc)
     Level 0 'o' = RIP_FILLED_OVAL

The full command letter tables are in Segments 2-5.


---------------------------------------------------------------------
1.5  MEGANUM ENCODING
---------------------------------------------------------------------

RIPscrip encodes numeric parameters using "MegaNum" digits.  The
default radix is 36; a second radix of 64 exists and is mandatory for
four commands — see §1.5.1, which a decoder must read before assuming
base 36 everywhere.

In base 36 each digit is a single ASCII character, and the letters are
case-INSENSITIVE ('a' and 'A' are both 10):

     Character   Value       Character   Value
     ---------   -----       ---------   -----
     0           0           I           18
     1           1           J           19
     2           2           K           20
     3           3           L           21
     4           4           M           22
     5           5           N           23
     6           6           O           24
     7           7           P           25
     8           8           Q           26
     9           9           R           27
     A           10          S           28
     B           11          T           29
     C           12          U           30
     D           13          V           31
     E           14          W           32
     F           15          X           33
     G           16          Y           34
     H           17          Z           35

Parameters are encoded as fixed-width MegaNum fields. The width
(1, 2, 3, or 4 digits) is defined per-parameter in the command
specification. Widths are always fixed — there are no variable-
length MegaNum fields within a single parameter.

Decoding a multi-digit MegaNum (big-endian, most significant first):

     mega1(p)     = value(p[0])
     mega2(p)     = value(p[0]) * 36 + value(p[1])
     mega3(p)     = value(p[0]) * 1296 + value(p[1]) * 36 + value(p[2])
     mega4(p)     = value(p[0]) * 46656 + ... + value(p[3])

Value ranges:

     Width   Min   Max     Typical Use
     -----   ---   -----   --------------------------
     1       0     35      Color index, flags
     2       0     1295    Coordinates, sizes, counts
     3       0     46655   Large values, extended IDs
     4       0     1679615 Flags with bit fields

Examples:

     "00"   = 0           (2-digit)
     "0F"   = 15          (2-digit, EGA white)
     "2S"   = 100         (2-digit, x=100)
     "1E"   = 50          (2-digit, y=50)
     "5K"   = 200         (2-digit, x=200)


---------------------------------------------------------------------
1.5.1  THE SECOND RADIX — BASE 64
---------------------------------------------------------------------

Base 36 is not the whole story.  RIPscrip has a SECOND radix, and a
handful of commands always use it regardless of any global setting.
A decoder that assumes base 36 everywhere will mis-read them.

THE ALPHABET.  Base 64 extends the base-36 set with lowercase letters
and two punctuation symbols.  It is CASE-SENSITIVE, unlike base 36:

     Character   Value       Character   Value
     ---------   -----       ---------   -----
     0 .. 9      0 .. 9      a .. z      36 .. 61
     A .. Z      10 .. 35    #           62
                             &           63

     mega2_64(p) = value(p[0]) * 64 + value(p[1])
     mega4_64(p) = value(p[0]) * 262144 + ... + value(p[3])

     Width   Min   Max        Note
     -----   ---   --------   -------------------------------------
     2       0     4095
     4       0     16777215   exactly 0xFFFFFF — a 24-bit RGB value

That last row is not a coincidence.  The driver's palette handler
rejects an RGB argument above 0xFFFFFF ("RGB Color value is out of
range!"), and a 4-digit field only reaches 24 bits in this radix; in
base 36 it caps at 1679615 and the check could never fire.

WHICH COMMANDS.  The radix is selected PER COMMAND, not globally.
The driver's dispatch record carries a two-bit field that is consulted
before any global setting:

     always base 36    |J  |N
     always base 64    |D  |d  |h  |y
     global default    every other command (base 36 unless changed)

'|J' RIP_SET_BASE_MATH sets the global radix and accepts only 36 or 64,
forcing 36 for anything else.  It is itself permanently base 36 — the
command that SETS the radix must decode unambiguously.  A consequence
worth knowing: '|J10' means 36 in base 36 and 64 in base 64, so it
ASSERTS the current radix rather than changing it.  Every '|J' in
TeleGrafix's shipped content is '|J10'.

A single file may mix both.  TUNNEL.RIP carries base-64 '|d' palette
payloads and '|fZKQO', which is 1280x960 only in base 36.

RIPlib decodes the four always-64 commands with the base-64 helpers in
src/rip_meganum.h and everything else in base 36.  It does not
implement a global switch to base 64, because no known content selects
one; see docs/spec/12-dll-provenance.md D-12.


---------------------------------------------------------------------
1.6  TEXT PARAMETERS
---------------------------------------------------------------------

Some commands include free-form text after the numeric parameters.
Text extends from the last numeric parameter to the frame
terminator '|'. Text may contain any character except '|' and the
null byte (0x00).

Escape sequences within text:

     Sequence   Meaning
     --------   -------
     \\         Literal backslash
     \|         Literal pipe character
     \^         Literal caret
     \n         Newline (line break within text)

The '<>' separator is used in button text to delimit fields:

     icon_name<>display_label<>host_command

Example — button with icon, label, and host command:

     !|1U0A0F0U160100MYICON<>Click Here<>SELECTION 1\r|


---------------------------------------------------------------------
1.7  ESC[! AUTO-DETECTION
---------------------------------------------------------------------

BBS hosts detect RIPscrip-capable clients by sending the ANSI
probe sequence:

     ESC [ !

     Hex: 1B 5B 21

The client responds with its protocol version string:

     RIPSCRIP<version><vendor><sub>\n

     Example: RIPSCRIP015400\n   (v1.54, vendor 0, sub 0)
              RIPSCRIP031001\n   (v3.1, vendor 0, sub 1)
              RIPSCRIP032001\n   (v3.2, vendor 0, sub 1)

Format of the version string:

     Position   Length   Field
     --------   ------   -----
     0-7        8        "RIPSCRIP" literal
     8-9        2        Major version (01 = v1, 03 = v3)
     10-11      2        Minor version (54 = .54, 10 = .1)
     12-13      2        Vendor/sub code (00 = standard)

The client MUST detect the ESC[! sequence in the incoming byte
stream and respond immediately. The sequence may appear at any
point in the data stream, not just at line boundaries.

State machine for detection:

     State 0: idle
         byte == 0x1B (ESC) → State 1
     State 1: got ESC
         byte == 0x5B ([)   → State 2
         else               → flush ESC to VT100, State 0
     State 2: got ESC[
         byte == 0x21 (!)   → send response, State 0
         else               → flush ESC[ to VT100, State 0

After the BBS receives the version response, it activates RIPscrip
mode and begins sending '!' triggered commands.


---------------------------------------------------------------------
1.8  COMMAND TRIGGER RULES
---------------------------------------------------------------------

The '!' trigger character is recognized as a RIPscrip command
initiator ONLY when it appears at a "line boundary":

     1. At the very start of the data stream (first byte)
     2. After a carriage return (0x0D)
     3. After a line feed (0x0A)
     4. After a form feed (0x0C)

A '!' character appearing mid-line (after printable characters
without an intervening line break) is passed through to the
text renderer as a literal exclamation mark.

v3.1 RELAXATION: RIPlib also accepts '!'
after ANSI CSI sequence terminators. This handles BBSes that send
clear-screen followed by RIPscrip on the same line:

     ESC[2J!|*|          (clear screen + RIP reset, same line)

This relaxation is backward-compatible — it only accepts '!' in
positions where the original spec would have triggered an error
or ignored the sequence.


---------------------------------------------------------------------
1.9  FRAME TERMINATION
---------------------------------------------------------------------

A RIPscrip frame ends when:

     1. A '|' (0x7C) is encountered — end of command
     2. A CR (0x0D) or LF (0x0A) is encountered — implicit end
     3. End of data stream — implicit end (incomplete command)

If a command is interrupted by CR/LF before the terminating '|',
the parser should process the partial command if enough parameters
have been received. Missing parameters default to zero.


---------------------------------------------------------------------
1.10  MULTI-COMMAND CHAINING
---------------------------------------------------------------------

Multiple commands may be chained within a single '!' trigger:

     !|cmd1|cmd2|cmd3|

This is equivalent to:

     !|cmd1|
     !|cmd2|
     !|cmd3|

The BBS uses chaining to reduce overhead — one '!' trigger for
an entire screen of drawing commands. The parser processes each
'|'-delimited segment independently.

Example — draw a red filled rectangle then a white text label:

     !|c0F|B0A0F0U16|@0C11Hello|

     c0F        → set draw colour to index 15 (EGA white)
     B0A0F0U16  → filled bar from (10,15) to (30,42)
     @0C11Hello → text at (12,37): "Hello"

     Every field above is a 2-digit MegaNum, which is BASE 36 -- so
     '0U' is 30 and '16' is 42.  Reading these as hexadecimal is a
     standing trap: '0A' and '0F' happen to mean the same in both
     bases, which makes a hex misreading look right for exactly as
     long as the values stay below 16.


---------------------------------------------------------------------
1.11  SPECIAL COMMANDS
---------------------------------------------------------------------

RIP_NO_MORE (Level 0, '#'):

     !|#|

Marks the end of a RIPscrip scene. The client should stop
expecting additional RIPscrip commands until a new '!' trigger.
Used by BBSes to signal "this screen is complete."

RIP_RESET_WINDOWS (Level 0, '*'):

     !|*|

Full state reset: clears the screen, resets all drawing parameters
(color, fill, line style, font, viewport, palette) to defaults,
clears mouse regions, and resets the text window. This is the
"start fresh" command sent by BBSes before drawing a new screen.


=====================================================================
==                    END OF SEGMENT 1                              ==
==               Wire Format & Encoding                             ==
=====================================================================

Next: Segment 2 — Level 0 Drawing Commands

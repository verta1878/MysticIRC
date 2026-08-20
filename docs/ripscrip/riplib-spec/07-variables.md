
=====================================================================
==       SEGMENT 7: VARIABLE EXPANSION                             ==
=====================================================================

RIPscrip text commands (|T, |@, |-) support inline variable
expansion. Text strings containing $VARNAME$ tokens are expanded
to their values before rendering. The expansion occurs after
backslash unescaping and before the text is passed to the font
renderer.

Variable names are case-sensitive and delimited by '$' characters.
Unrecognized variable names are left unexpanded (passed through
as literal text including the '$' delimiters).


---------------------------------------------------------------------
7.1  EXPANSION SYNTAX
---------------------------------------------------------------------

     Input:    "Hello $USER$, today is $DATE$"
     Output:   "Hello , today is 03/21/26"

     Input:    "RIP version: $RIPVER$"
     Output:   "RIP version: RIPSCRIP032001"

     Input:    "Unknown: $FOOBAR$"
     Output:   "Unknown: $FOOBAR$"    (unrecognized, left as-is)

Processing order:
     1. Backslash unescape (\\, \|, \^, \n)
     2. Scan for $...$ delimiters
     3. Look up variable name in the built-in table
     4. If found, substitute value string
     5. If not found, leave $...$ intact
     6. Pass result to font renderer


---------------------------------------------------------------------
7.2  BUILT-IN VARIABLES — Date and Time
---------------------------------------------------------------------

$DATE$
     Format:   MM/DD/YY
     Example:  "03/21/26"
     Source:    Host-synchronized time or local RTC fallback.
     DLL RVA:  Part of ripTextVarEngine (0x026218)

$TIME$
     Format:   HH:MM
     Example:  "15:30"
     Source:    Host-synchronized time or RTC.

$YEAR$
     Format:   YYYY
     Example:  "2026"
     Source:    4-digit year. Host-synced or RTC.

$WOYM$
     Format:   WW (2-digit, zero-padded)
     Example:  "12"
     Description: ISO week-of-year (Monday start). Computed using
                  the standard ISO 8601 week numbering algorithm.
     DLL: Uses custom WOYM calculation (ripTextVarEngine).


---------------------------------------------------------------------
7.3  BUILT-IN VARIABLES — Protocol and Identity
---------------------------------------------------------------------

$RIPVER$
     Format:   RIPSCRIP<major><minor><sub>
     v1.54:    "RIPSCRIP015400"
     v3.0:     "RIPSCRIP030001"
     v3.1:     "RIPSCRIP031001"
     v3.2:     "RIPSCRIP032001"   (RIPlib current)
     Description: Protocol version string. Same format as the
                  ESC[! auto-detect response (see §1.7).

$PROT$
     Format:   Single digit (ASCII)
     Example:  "0"
     Description: Resolution mode index. 0=EGA 640×350,
                  1=VGA 640×480, etc. Reported to the BBS
                  via $PROT$ query in text commands.

$COMPAT$
     Format:   Single digit
     Value:    "1"
     Description: Basic compatibility level. Always returns "1".

$COLORMODE$
     Format:   Decimal digit
     Value:    "0" in palette-mapping mode; "1".."8" in direct-RGB
               mode to indicate bits per RGB component.
     Description: Mirrors RIP_SET_COLOR_MODE (|M). RIPlib records
                  the negotiated mode while rendering to its indexed
                  framebuffer.

$COORDSIZE$
     Format:   Decimal digit
     Value:    "2".."5"
     Description: Current variable-width coordinate byte size from
                  RIP_SET_COORDINATE_SIZE (|n). Default is "2".

$ISPALETTE$
     Format:   Single digit
     Value:    "1"
     Description: Reports that the target has an indexed palette.

$USER$
     Format:   String (may be empty)
     Value:    "" (empty on embedded — no login context)
     Description: Current user name. The original driver returned
                  the client's login identity; RIPlib has no login
                  context and always returns empty.


---------------------------------------------------------------------
7.4  BUILT-IN VARIABLES — Random Number
---------------------------------------------------------------------

$RAND$
     Format:   Unsigned integer (ASCII decimal)
     Example:  "12345"
     Range:    0-32767

     Algorithm: Knuth linear congruential generator (LCG).
     Identical to the DLL implementation for BBS compatibility.

          state = state * 1103515245 + 12345
          output = (state >> 16) & 0x7FFF

     The LCG state is seeded from the local RTC timestamp at
     session init (rip_init_first). A zero seed is valid — first
     output will be 12345.

     Each expansion of $RAND$ advances the LCG state, producing
     a different value on each use within the same session.


---------------------------------------------------------------------
7.5  BUILT-IN VARIABLES — Sound Tokens
---------------------------------------------------------------------

These variables produce no visible text output. Instead, they
trigger sound events on the host platform.

$BEEP$
     Action:   Send BEL (0x07) via TX queue.
     RIPlib:   Pushes BEL (0x07) into the TX FIFO.  The host
               is expected to ring an audible bell on receipt.
     Expands to: "" (empty string)

$BLIP$
     Action:   Send short blip sound token via TX queue.
     Expands to: "" (empty string)

$ALARM$
     Action:   Send alarm sound token via TX queue.
     Expands to: "" (empty string)

$PHASER$
     Action:   Send phaser sound token via TX queue.
     Expands to: "" (empty string)

$MUSIC$
     Action:   Send music trigger via TX queue.
     Expands to: "" (empty string)

     On the original DLL, these called a host callback function
     for sound playback.  In RIPlib, the sound token bytes are
     pushed through the TX FIFO; the host application is
     responsible for any actual audio synthesis or playback.


---------------------------------------------------------------------
7.6  BUILT-IN VARIABLES — Session Control
---------------------------------------------------------------------

$REFRESH$
     Action:   Clears the refresh_suppress flag. Marks the
               framebuffer dirty for immediate DMA refresh.
     Expands to: "" (empty string)
     Description: Used by BBSes to resume screen updates after
                  a batch of drawing commands sent with
                  $NOREFRESH$ active.

$NOREFRESH$
     Action:   Sets the refresh_suppress flag. Suppresses
               framebuffer refresh until $REFRESH$ is expanded.
     Expands to: "" (empty string)
     Description: Optimization for complex scenes — suppresses
                  intermediate refresh during batch drawing.

$RESET$
     Action:   Triggers a state reset (equivalent to |*).
     Expands to: "" (empty string)
     DLL: Part of ripTextVarEngine.

$ABORT$
     Action:   Resets the RIPscrip FSM to IDLE state. Any
               partially parsed command is discarded.
     Expands to: "" (empty string)
     v3.1 extension.

$MKILL$
     Action:   Clears all mouse regions (equivalent to |1K
               but triggered inline during text expansion).
     Expands to: "" (empty string)
     v3.1 extension.

$COPY$
     Action:   Sets write mode to COPY (mode 0).
     Expands to: "" (empty string)
     v3.1 extension.

$COFF$
     Action:   Cursor off (no-op on embedded — no visible
               text cursor in graphics mode).
     Expands to: "" (empty string)
     v3.1 extension.


---------------------------------------------------------------------
7.7  BUILT-IN VARIABLES — Text Data
---------------------------------------------------------------------

$TEXTDATA$
     Format:   String (may be empty)
     Value:    "" (empty on embedded)
     Description: Returns the contents of the bounded text buffer.
                  On the DLL, this held text from the most recent
                  text block.  In RIPlib, text is rendered
                  immediately and not buffered, so this always
                  returns empty.


---------------------------------------------------------------------
7.8  APPLICATION-DEFINED VARIABLES
---------------------------------------------------------------------

BBSes can define custom variables using the RIP_DEFINE command
(|1D). These are stored in the application variable table and
expanded in subsequent text commands.

$APP0$ through $APP9$
     Format:   String (user-defined)
     Set via:  !|1DAPP0=my value|
     Access:   $APP0$ in any text command

Indexed access (APP0-APP9) provides 10 named slots. Variables
defined with other names (via |1D) are also expanded but use
a linear search of the variable table.

     Example:
          BBS sends:  !|1DAPP0=Welcome|
          BBS sends:  !|T$APP0$ to the system!|
          Renders:    "Welcome to the system!"


---------------------------------------------------------------------
7.9  VARIABLE TABLE SUMMARY
---------------------------------------------------------------------

     Variable        Type       Version   Description
     -------------   --------   -------   -------------------------
     $DATE$          date       v1.54     MM/DD/YY
     $TIME$          time       v1.54     HH:MM
     $YEAR$          date       v1.54     YY (2-digit)
     $FYEAR$         date       v1.54     YYYY (4-digit)
     $WOYM$          date       v3.0      Week of year (ISO)
     $HOUR$          time       v3.2      HH, 12-hour (01-12)
     $MHOUR$         time       v3.2      HH, 24-hour (00-23)
     $MIN$           time       v3.2      MM from host_time or RTC
     $SEC$           time       v3.2      SS from RTC
     $WDAY$          date       v3.2      Day of week digit, Sun=0
     $DOW$           date       v3.2      Day of week name ("Friday")
     $DAY$           date       v3.2      Day of month (DD)
     $MONTHNUM$      date       v3.2      Month of year (MM)
     $MONTH$         date       v3.2      Month name ("January")

     NAMES CORRECTED 2026-08-12.  RIPSCRIP.DLL 3.0.7 carries both
     names of each pair as distinct strings (HOUR/MHOUR, DOW/WDAY,
     MONTH/MONTHNUM, YEAR/FYEAR) and has no "DOM" string at all.
     RIPlib previously returned the right values under the wrong
     names — $YEAR$ gave four digits, $HOUR$ gave 00-23, $DOW$ gave
     a Monday=0 digit, $MONTH$ gave MM, and day-of-month was $DOM$.
     Each was silently wrong against a conforming terminal rather
     than an error.  $DOM$ is removed; use $DAY$.
     $RIPVER$        protocol   v1.54     Version string
     $PROT$          protocol   v3.1      Resolution mode
     $COMPAT$        protocol   v3.1      Compatibility level
     $COLORMODE$     protocol   v2.0      Palette/RGB mode
     $COORDSIZE$     protocol   v2.0      Coordinate byte size
     $ISPALETTE$     protocol   v2.0      Palette availability
     $USER$          identity   v1.54     User name (empty)
     $RAND$          numeric    v1.54     LCG random 0-32767
     $CX$ / $CY$     layout     v3.2      Current draw cursor
     $VPW$ / $VPH$   layout     v3.2      Viewport size
     $VPCX$ / $VPCY$ layout     v3.2      Viewport center
     $CCOL$          layout     v3.2      Current draw color
     $CFCOL$         layout     v3.2      Current fill color
     $CBCOL$         layout     v3.2      Current back color
     $BLACK$..$WHITE$ color     v3.2      EGA color-name aliases
     $BEEP$          sound      v1.54     System bell
     $BLIP$          sound      v1.54     Short blip
     $ALARM$         sound      v1.54     Alarm tone
     $PHASER$        sound      v1.54     Phaser effect
     $MUSIC$         sound      v1.54     Music trigger
     $REFRESH$       session    v3.0      Resume refresh
     $NOREFRESH$     session    v3.0      Suppress refresh
     $RESET$         session    v3.0      State reset
     $ABORT$         session    v3.1      FSM reset
     $MKILL$         session    v3.1      Clear mouse regions
     $COPY$          session    v3.1      Set COPY write mode
     $COFF$          session    v3.1      Cursor off (no-op)
     $TEXTDATA$      text       v3.0      Text buffer (empty)
     $APP0-9$        user       v2.0      Application variables


=====================================================================
==                    END OF SEGMENT 7                              ==
==           Variable Expansion                                     ==
=====================================================================

Next: Segment 8 — Font Specification

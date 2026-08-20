
=====================================================================
==       SEGMENT 6A: v3.2 EXTENSIONS (§A2G.8 - §A2G.13)            ==
=====================================================================

The §A2G.8 through §A2G.13 extensions define RIPscrip v3.2: small
refinements that build on v3.1 without changing any existing wire-
format command.  Every addition is one of: a new command letter not
used in v3.0 / v3.1, a new $VARIABLE$ name, a new preprocessor
directive, or a new value for a previously-validated parameter
field.  v3.0 / v3.1 clients see the new content as either no-op
(unknown command letters are passed through the FSM accept list) or
as literal text ($XYZ$ falls through when unrecognized).

Protocol versioning:

     RIPSCRIP032001    v3.2 — adds §A2G.8 through §A2G.13
                              (state stack, layout vars, time vars,
                               color names, <<DEBUG>>, radial fill)

A client advertises its supported revision via $RIPVER$ and via the
ESC[! probe response (see §1.7).  v3.1 (§A2G.1 - §A2G.7) is
documented in `06-v31-extensions.md`; this segment covers only the
v3.2 additions on top of that baseline.


---------------------------------------------------------------------
§A2G.8  STATE PUSH/POP STACK
---------------------------------------------------------------------

Two new Level 0 commands wrap a bounded LIFO stack of "drawing
prelude" state:

     Function:     Push drawing state
     Command:      |^
     Arguments:    (none)
     Format:       !|^|

     Function:     Pop drawing state
     Command:      |~
     Arguments:    (none)
     Format:       !|~|

The stack is bounded to RIP_STATE_STACK_MAX (8) frames.  Each frame
captures the fields a typical scene most often re-sends as a prelude
before a styled draw:

     draw_color, back_color, fill_color, fill_pattern,
     line_style, line_pattern (16-bit), line_thick, write_mode,
     font_id, font_size, font_dir, font_attrib,
     font_hjust, font_vjust,
     font_ext_id, font_ext_attr, font_ext_size,
     filled_borders_enabled,
     draw_x, draw_y,
     vp_x0, vp_y0, vp_x1, vp_y1

Behavior:

     Push (|^):   If stack is full, the push is silently dropped.
                  Matches the "ignore unknown params" precedent for
                  graceful degradation.
     Pop  (|~):   If stack is empty, the pop is a no-op.  On a
                  successful pop, the full session drawing state is
                  re-applied immediately, so the next draw command
                  picks up restored color, write mode, line, fill,
                  cursor, and viewport state.

Stack lifetime:
     The stack is reset to depth=0 by:
          * RIP_RESET_WINDOWS (|*)
          * RIP_SESSION_RESET (host-driven)
          * rip_init_first / rip_session_reset C API calls

Example:

     !|c04|S0204|       sets red outline + green fill
     !|^|               push the current state
     !|c0F|S0104|       switch to white outline + blue fill
     !|R0A0A1414|       draws a blue-filled rect (white border)
     !|~|               pop — back to red outline + green fill
     !|R28281414|       another rect with the original colors


---------------------------------------------------------------------
§A2G.9  LAYOUT / INTROSPECTION VARIABLES
---------------------------------------------------------------------

These read-only variables expose current drawing state to text and
to <<IF>> expressions.  Each expands to a decimal string suitable
for direct use in IF comparison.

     Variable    Expands to                  Source
     ---------   -------------------------   ----------------------
     $CX$        current draw_x (decimal)    s->draw_x
     $CY$        current draw_y (decimal)    s->draw_y
     $VPW$       viewport width              vp_x1 - vp_x0 + 1
     $VPH$       viewport height             vp_y1 - vp_y0 + 1
     $VPCX$      viewport center X           (vp_x0 + vp_x1) / 2
     $VPCY$      viewport center Y           (vp_y0 + vp_y1) / 2
     $CCOL$      current draw color (0-15)   s->draw_color & 0x0F
     $CFCOL$     current fill color (0-15)   s->fill_color & 0x0F
     $CBCOL$     current back color (0-15)   s->back_color & 0x0F

Use case: a scene can compute its own centering without the BBS
hard-coding 320,200, surviving |v viewport changes and |2P port
definitions transparently:

     !|@$VPCX$$VPCY$Hello, world|     draws text at viewport center


---------------------------------------------------------------------
§A2G.10  TIME COMPONENT VARIABLES
---------------------------------------------------------------------

Extends the existing $DATE$ / $TIME$ / $YEAR$ / $WOYM$ family with
finer-grained accessors:

     Variable      Format     Source                 Range
     -----------   --------   --------------------   -----------
     $HOUR$        HH         host_time[0..1]        01-12
     $MHOUR$       HH         host_time[0..1]        00-23
     $MIN$         MM         host_time[3..4]        00-59
     $SEC$         SS         local RTC              00-59
     $WDAY$        D          day of week            0-6, Sun=0
     $DOW$         name       day of week            "Thursday"
     $DAY$         DD         day of month           01-31
     $MONTHNUM$    MM         month of year          01-12
     $MONTH$       name       month of year          "January"

NAMES CORRECTED 2026-08-12.  This table previously assigned the
24-hour value to $HOUR$, a Monday=0 digit to $DOW$, the numeric
month to $MONTH$, and used $DOM$ for day-of-month.  All four were
wrong against the driver, and wrong silently -- a conforming
terminal returns a different TYPE, not an error.

RIPSCRIP.DLL 3.0.7 carries BOTH names of each pair as distinct
NUL-terminated strings -- HOUR and MHOUR, DOW and WDAY, MONTH and
MONTHNUM, YEAR and FYEAR -- so they are separate variables with
separate meanings.  It contains no "DOM" string at all.  RIPlib had
the right values under the wrong names; the values moved, nothing
was lost.  $DOM$ is gone; use $DAY$.

All fall back to the local RTC (`time()` / `localtime()`) when the
host has not synced its date/time over CMD_SYNC_DATE/SYNC_TIME yet.

$WDAY$ and $DOW$ reuse the ISO-week date arithmetic already used by
$WOYM$ (rip_weekday_monday0), so day-of-week and week-of-year stay
consistent even across leap years; $WDAY$ converts to Sunday=0 for
wire compatibility.

Use case: greeting variation by time of day, or by day of week:

     <<IF $MHOUR$<12>>Good morning<<ENDIF>>
     <<IF $DOW$=Friday>>Happy Friday!<<ENDIF>>
     <<IF $WDAY$=5>>Happy Friday!<<ENDIF>>

Note the first form is what a conforming 3.x terminal expects.  The
digit comparison must use $WDAY$ -- and Friday is 5 with Sunday=0,
not 4 as the pre-correction example had it.


---------------------------------------------------------------------
§A2G.11  EGA COLOR-NAME ALIASES
---------------------------------------------------------------------

Each EGA palette index has a readable variable alias.  Names are
all uppercase, no separators.  Each expands to its 2-digit MegaNum
value (suitable as a |c, |S, |k, |a argument if pre-expanded by a
text path, or as a comparison value in <<IF>> expressions).

     Index   Variable          Expands to
     -----   ---------------   ----------
     0       $BLACK$           "00"
     1       $BLUE$            "01"
     2       $GREEN$           "02"
     3       $CYAN$            "03"
     4       $RED$             "04"
     5       $MAGENTA$         "05"
     6       $BROWN$           "06"
     7       $LIGHTGRAY$       "07"
     8       $DARKGRAY$        "08"
     9       $LIGHTBLUE$       "09"
     10      $LIGHTGREEN$      "0A"
     11      $LIGHTCYAN$       "0B"
     12      $LIGHTRED$        "0C"
     13      $LIGHTMAGENTA$    "0D"
     14      $YELLOW$          "0E"
     15      $WHITE$           "0F"

These variables expand in any context where rip_expand_variables
runs: |T, |@, |t, |", |- text bodies, and <<IF>> expression bodies.
They do NOT expand inside numeric command-argument fields such as
|c<color>, because those fields are read by mega2() directly from
the wire buffer before variable expansion is reached.  Use them
in text bodies and IF comparisons:

     !|TYour color is $LIGHTRED$|
     <<IF $CCOL$=12>>The current color is light red<<ENDIF>>


---------------------------------------------------------------------
§A2G.12  <<DEBUG msg>> PREPROCESSOR DIRECTIVE
---------------------------------------------------------------------

A new preprocessor directive joins <<IF>> / <<ELSE>> / <<ENDIF>>:

     Directive:    <<DEBUG msg>>
     Effect:       Pushes "0x3E DEBUG: <msg>\r" to the TX FIFO.
                   Suppressed by an enclosing <<IF false>> branch.

The 0x3E (>) prefix marks the line as a host-side log, distinct
from the 0x3D (=) CMD_PLAY_SOUND marker and from regular text.  A
host that does not recognize the prefix simply drops the line —
making this safe to leave in production scene scripts.

Use case: instrumenting a scene script during development:

     <<DEBUG entering menu render>>
     !|@01010Menu|
     <<IF $APP0$=>><<DEBUG no user name yet>><<ENDIF>>

Output on TX:

     >DEBUG: entering menu render\r
     >DEBUG: no user name yet\r


---------------------------------------------------------------------
§A2G.13  RADIAL GRADIENT MODE
---------------------------------------------------------------------

PROVENANCE CORRECTED 2026-08-12.  The base command |28 was
attributed to RIPSCRIP.DLL 3.0.7 and treated as part of RIPlib's
v3.0 baseline.  That attribution is disproved:

  - The DLL command dispatch table (segment 13) contains NO
    digit-letter command in the Level 2 band at all — neither |20
    nor |28 — and the published TeleGrafix tables do not use digit
    slots at Level 2 either.
  - No gradient handler name appears in any string class of the
    binary (segment 12, classes B and C).
  - No gradient command appears in the 1.54 specification, the
    2.00 Alpha 4 draft, the RIPtel 3.1 help inventory, or the
    116-file demo corpus shipped with RIPtel 3.1.

|28 is therefore a RIPlib-ORIGINAL command, not a recovered
TeleGrafix one.  It works, it is implemented and tested, and it
stays — but it must be presented as an extension in its own right
rather than as a mode added to an inherited command.  Modes 0 and 1
are likewise RIPlib's, not v3.0's; the "(v3.0)" labels below are
retained only to show the order they were added in.

Shipping 3.x content produced gradients through RIP_FILL_PATTERN
with alternating dither patterns across bands of a 256-colour fade
(the BLUEFADE.FN idiom), which is the historically faithful method.

The Level 2 gradient command |28 gains a third mode value:

     Mode 0 (v3.0):   Horizontal gradient — color varies with X.
     Mode 1 (v3.0):   Vertical gradient — color varies with Y.
     Mode 2 (§A2G):   Radial gradient — c1 at the box center,
                      c2 at the farthest box corner.  Per-pixel
                      linear interpolation by normalized squared
                      distance, using the FPU we already require
                      for §A2G.5 trig.

Backward compatibility:
     v3.0 stored mode as a bool (any non-zero = vertical), so
     existing clients sending mode=1 still get vertical output.
     Only mode=2 is new behavior.

     Wire format: !|28<x:2><y:2><w:2><h:2><c1:2><c2:2><mode:2>|

     Example:
          !|280A0A1414010202|
               x=10 y=10 w=20 h=20 c1=palette[1] c2=palette[2]
               mode=2 → radial gradient from center to corners


=====================================================================
==                    END OF SEGMENT 6A                             ==
==              v3.2 Extensions (§A2G.8 - §A2G.13)                  ==
=====================================================================

Next: Segment 7 — Variable Expansion

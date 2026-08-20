/*
 * ripscrip.c — RIPscrip v1.54+ graphics protocol parser for RIPlib
 *
 * TeleGrafix RIPscrip (1992-1994).  Vector graphics protocol for BBSes.
 * !| prefix, | terminator, base-36 MegaNum parameters; native coordinate
 * space is EGA 640×350.  Highest "wow factor" terminal protocol of the
 * BBS era — full-color vector art, buttons, mouse regions, text
 * windows, scriptable preprocessor.
 *
 * Reference: TeleGrafix RIPscrip v1.54 specification (RIPSCRIP.DOC,
 *            included in docs/historical/) and the RIPlib spec under
 *            docs/spec/.
 * Reference: RIPtermJS (JavaScript implementation, public archive).
 *
 * NOTE: This file historically carried inline "FIX *" / "Codex FIX N"
 * labels from the pre-extraction audit work.  Those have been
 * scrubbed; the label → meaning index for anyone needing to cross-
 * reference a prior commit is preserved in
 * consumer-handoff/a2gspu/integration-notes.md.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#include "ripscrip.h"
#include "ripscrip2.h"
#include "riplib_platform.h"
#include "drawing.h"
#include "bgi_font.h"
#include "font_bgi_trip.h"
#include "font_bgi_sans.h"
#include "font_bgi_goth.h"
#include "font_bgi_litt.h"
#include "font_bgi_scri.h"
#include "font_bgi_simp.h"
#include "font_bgi_tscr.h"
#include "font_bgi_lcom.h"
#include "font_bgi_euro.h"
#include "font_bgi_bold.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <time.h>  /* time_t, time(), localtime() — RTC fallback for $DATE$/$TIME$ */

#include "rip_icons.h"
#include "rip_icn.h"
#include "rip_preproc.h"    /* extracted preprocessor subsystem (C-002 step 1) */
#include "rip_variables.h"  /* extracted variable engine (C-002 step 2) */
#include "rip_meganum.h"
/* The base-36 decoders are exported by rip_meganum.h under their rip_*
 * names.  This TU uses the historical short names; the aliases are kept
 * here (C-016) rather than in the shared header so that header does not
 * leak unprefixed macros (mega2/…) into every file that includes it. */
#define mega_digit rip_mega_digit
#define mega2      rip_mega2
#define mega3      rip_mega3
#define mega4      rip_mega4    /* extracted MegaNum decoder (C-002 step 3) */
/* Base-64 forms, for the four commands the dispatch table marks as always
 * base 64 ('|D', '|d', '|h', '|y').  Never use these on any other command,
 * and never use the base-36 forms on these -- see rip_meganum.h and D-12. */
#define mega_digit64 rip_mega_digit64
#define mega2_64     rip_mega2_64
#define mega4_64     rip_mega4_64
#include "rip_clipboard.h"  /* extracted clipboard + blit (C-002 step 6) */
#include "rip_internal.h"   /* shared inline helpers (rip_strnlen, rip_filename_is_safe) */
/* rip_raf: stubbed in riplib */
#include "font_cp437_8x16.h"

/* Write/read RIPscrip palette entries to/from hardware (FORMAT_8_PAL LUT) */
extern void palette_write_rgb565(uint8_t index, uint16_t rgb565);
extern uint16_t palette_read_rgb565(uint8_t index);

/* PSRAM arena allocator for session-scoped allocations */
#include "riplib_platform.h"

/* Arena size for a single RIPscrip session: 1 MB covers the clipboard
 * (640×400 = 256 KB), uploaded icon cache, and file staging buffer. */
#define RIP_PSRAM_ARENA_SIZE (1024u * 1024u)

/* Fixed numeric prefixes that precede a trailing string argument.  The
 * dispatch record types only the numeric argument array; a string follows
 * it, so the record's fixed width IS the string's offset.  Literal type
 * codes are digit counts, never string markers -- '|1e' and '|1i' both sum
 * to exactly the 24-character payloads the corpus sends, which settles it.
 * See D-16. */
#define RIP_GOTOURL_RESERVED  8   /* |3G: slot 126, one 8-digit field       */
#define RIP_REGVAR_RESERVED  14   /* |3R: slot 127, mega4 + mega2 + 8 digits */
#define RIP_READSCENE_RESERVED 8  /* |1R: slot 104, mega2 + 6 digits         */

/* Reset the per-frame command-level prefix flags.  Used by the FSM at
 * every dispatch boundary (CR/LF, '|', error recovery) to start the
 * next command in a clean Level 0 state. */
static inline void clear_levels(rip_state_t *s) {
    s->is_level1 = false;
    s->is_level2 = false;
    s->is_level3 = false;
}

/* L15: write both s->vp_* and ports[active_port].vp_*.  The port table
 * is the source of truth on port switch (port_load_state copies from
 * the port back into rip_state_t), so viewport-setting commands ('v',
 * '1V', '*') must touch both — otherwise a subsequent !|2s revert
 * silently undoes the new viewport.  Also pushes the clip to the draw
 * layer so subsequent primitives respect it immediately. */
static inline void set_session_viewport(rip_state_t *s,
                                        int16_t x0, int16_t y0,
                                        int16_t x1, int16_t y1) {
    s->vp_x0 = x0;
    s->vp_y0 = y0;
    s->vp_x1 = x1;
    s->vp_y1 = y1;
    if (s->active_port < RIP_MAX_PORTS) {
        s->ports[s->active_port].vp_x0 = x0;
        s->ports[s->active_port].vp_y0 = y0;
        s->ports[s->active_port].vp_x1 = x1;
        s->ports[s->active_port].vp_y1 = y1;
    }
    draw_set_clip(x0, y0, x1, y1);
}

/* BGI stroke fonts (parsed at init, indexed by BGI_FONT_* ID) */
/* -- Slot protection -------------------------------------------------
 *
 * A protected slot refuses modification.  The driver enforces this at 24
 * command sites with twelve "its protected!" diagnostics.  The sites were
 * recovered mechanically -- by finding which handler body pushes each
 * diagnostic -- rather than by guessing which commands look like state
 * writes.
 *
 * Content sets protection through the Switch* commands' flag bits; see
 * src/ripscrip2.c and 14-divergence-register.md 14.3.6.  Everything starts
 * unprotected, so these guards are inert until a stream opts in, which is
 * why turning them on changes nothing for the 35 corpus scenes.
 *
 * The driver reports a diagnostic and draws nothing.  RIPlib draws nothing
 * and stays silent -- it has no diagnostic channel to report on. */
#define RIP_PROT(s, fam) \
    ((((s)->rip2_state.protected_##fam) >> ((s)->rip2_state.cur_##fam##_slot)) & 1u)

#define RIP_STYLE_PROTECTED(s)    RIP_PROT(s, style)
#define RIP_PALETTE_PROTECTED(s)  RIP_PROT(s, palette)
#define RIP_ENV_PROTECTED(s)      RIP_PROT(s, environment)
#define RIP_TEXTWIN_PROTECTED(s)  RIP_PROT(s, text_window)
#define RIP_BTNSTYLE_PROTECTED(s) RIP_PROT(s, button_style)
#define BGI_FONT_COUNT 11  /* 0=bitmap, 1-10=stroke */
static bgi_font_t bgi_fonts[BGI_FONT_COUNT];
static bool bgi_fonts_loaded = false;

/* Backward compat alias */
#define bgi_triplex         bgi_fonts[BGI_FONT_TRIPLEX]
#define bgi_triplex_loaded  bgi_fonts_loaded

/* Global parser state (one RIPscrip session at a time) */
static rip_state_t *g_rip_state = NULL;

static void apply_session_draw_state(rip_state_t *s);
static void rip_upload_reset(rip_state_t *s);
static void rip_cache_icn_if_valid(rip_state_t *s, const char *name, int name_len,
                                   const uint8_t *data, int size);
/* rip_reset_windows_state is defined non-static below so the extracted
 * rip_variables.c module can reach it from the $RESET$ text variable. */
void rip_reset_windows_state(rip_state_t *s, comp_context_t *c);

/* Library->host TX FIFO helper (implemented by the consumer's
 * platform-stubs translation unit — see examples/platform_stubs.c). */
extern void riplib_host_tx(const char *buf, int len);

/* FILE UPLOAD — receive BMP/ICN data from host for PSRAM caching */
#define FILE_UPLOAD_MAX  (128 * 1024)  /* 128KB max per file */

/* MegaNum decoder (base-36 parameter encoding) lives in
 * src/rip_meganum.h as static-inline helpers.  See that file's header
 * comment for the rationale of the header-only extraction. */


/* Scale RIPscrip Y (640×350) to card Y (640×400).
 * Two variants prevent gaps between adjacent rectangles:
 * scale_y  = floor (for top edges, y-positions, single coords)
 * scale_y1 = ceiling (for bottom edges — ensures adjacent rects touch) */
static int16_t scale_y(int16_t y) {
    return (int16_t)((y * 8) / 7);
}
static int16_t scale_y1(int16_t y) {
    return (int16_t)((y * 8 + 6) / 7);
}

/* -- Skewed-oval geometry -------------------------------------------------
 * RIPscrip's skewed-oval family ('&', '-', '[', ']', '+', '_') is rendered
 * by the driver as a point-per-degree polygon, not by a GDI ellipse call.
 * The generator at RVA 0x010160 walks start..end inclusive and emits
 *
 *     X  = rx * cos(t) >> 14         Y  = ry * sin(t) >> 14
 *     px = cx + (X * cos(skew) - Y * sin(skew)) >> 14
 *     py = cy - (X * sin(skew) + Y * cos(skew)) >> 14
 *
 * an axis-aligned ellipse point rotated by `skew` degrees, Y inverted for
 * screen coordinates.  `skew` is therefore a rotation angle in whole
 * degrees, not a shear factor.  The driver then hands the run to Polygon()
 * (filled variants) or strokes it (open variants).
 *
 * The table below is the driver's own Q14 sine table, transcribed verbatim
 * from RVA 0x07b638 by scripts/dll-disasm.py.  The driver carries a second
 * cosine table at RVA 0x07b098; it equals sin(t+90) for 358 of its 360
 * entries and differs by one LSB on the remaining two, so a single table
 * serves both with a worst-case error of 1/16384 of a radius. */
#define RIP_Q14           14
#define RIP_OVAL_MAX_PTS  121   /* a full turn at 3 deg steps */

static const int16_t rip_sin_q14[360] = {
          0,     285,     571,     857,    1142,    1427,    1712,    1996,    2280,    2563,
       2845,    3126,    3406,    3685,    3963,    4240,    4516,    4790,    5062,    5334,
       5603,    5871,    6137,    6401,    6663,    6924,    7182,    7438,    7691,    7943,
       8191,    8438,    8682,    8923,    9161,    9397,    9630,    9860,   10086,   10310,
      10531,   10748,   10963,   11173,   11381,   11585,   11785,   11982,   12175,   12365,
      12550,   12732,   12910,   13084,   13254,   13420,   13582,   13740,   13894,   14043,
      14188,   14329,   14466,   14598,   14725,   14848,   14967,   15081,   15190,   15295,
      15395,   15491,   15582,   15668,   15749,   15825,   15897,   15964,   16025,   16082,
      16135,   16182,   16224,   16261,   16294,   16321,   16344,   16361,   16374,   16381,
      16384,   16381,   16374,   16361,   16344,   16321,   16294,   16261,   16224,   16182,
      16135,   16082,   16025,   15964,   15897,   15825,   15749,   15668,   15582,   15491,
      15395,   15295,   15190,   15081,   14967,   14848,   14725,   14598,   14466,   14329,
      14188,   14043,   13894,   13740,   13582,   13420,   13254,   13084,   12910,   12732,
      12550,   12365,   12175,   11982,   11785,   11585,   11381,   11173,   10963,   10748,
      10531,   10310,   10086,    9860,    9630,    9397,    9161,    8923,    8682,    8438,
       8191,    7943,    7691,    7438,    7182,    6924,    6663,    6401,    6137,    5871,
       5603,    5334,    5062,    4790,    4516,    4240,    3963,    3685,    3406,    3126,
       2845,    2563,    2280,    1996,    1712,    1427,    1142,     857,     571,     285,
          0,    -285,    -571,    -857,   -1142,   -1427,   -1712,   -1996,   -2280,   -2563,
      -2845,   -3126,   -3406,   -3685,   -3963,   -4240,   -4516,   -4790,   -5062,   -5334,
      -5603,   -5871,   -6137,   -6401,   -6663,   -6924,   -7182,   -7438,   -7691,   -7943,
      -8191,   -8438,   -8682,   -8923,   -9161,   -9397,   -9630,   -9860,  -10086,  -10310,
     -10531,  -10748,  -10963,  -11173,  -11381,  -11585,  -11785,  -11982,  -12175,  -12365,
     -12550,  -12732,  -12910,  -13084,  -13254,  -13420,  -13582,  -13740,  -13894,  -14043,
     -14188,  -14329,  -14466,  -14598,  -14725,  -14848,  -14967,  -15081,  -15190,  -15295,
     -15395,  -15491,  -15582,  -15668,  -15749,  -15825,  -15897,  -15964,  -16025,  -16082,
     -16135,  -16182,  -16224,  -16261,  -16294,  -16321,  -16344,  -16361,  -16374,  -16381,
     -16384,  -16381,  -16374,  -16361,  -16344,  -16321,  -16294,  -16261,  -16224,  -16182,
     -16135,  -16082,  -16025,  -15964,  -15897,  -15825,  -15749,  -15668,  -15582,  -15491,
     -15395,  -15295,  -15190,  -15081,  -14967,  -14848,  -14725,  -14598,  -14466,  -14329,
     -14188,  -14043,  -13894,  -13740,  -13582,  -13420,  -13254,  -13084,  -12910,  -12732,
     -12550,  -12365,  -12175,  -11982,  -11785,  -11585,  -11381,  -11173,  -10963,  -10748,
     -10531,  -10310,  -10086,   -9860,   -9630,   -9397,   -9161,   -8923,   -8682,   -8438,
      -8192,   -7943,   -7691,   -7438,   -7182,   -6924,   -6663,   -6401,   -6137,   -5871,
      -5603,   -5334,   -5062,   -4790,   -4516,   -4240,   -3963,   -3685,   -3406,   -3126,
      -2845,   -2563,   -2280,   -1996,   -1712,   -1427,   -1142,    -857,    -571,    -285,
};

static int32_t rip_sin14(int a) {
    return rip_sin_q14[((a % 360) + 360) % 360];
}
static int32_t rip_cos14(int a) {
    return rip_sin14(a + 90);
}

/* Emit the skewed-oval outline over [start,end] degrees inclusive as x,y
 * pairs.  Steps one degree at a time where the span fits the buffer and
 * coarsens uniformly when it does not, then always lands exactly on `end`
 * so an arc terminates where the stream said it should.  Callers pass
 * coordinates already run through scale_y(); this routine is pure geometry.
 * Returns the number of POINTS written (not the number of int16_t). */
static int rip_skewed_oval_points(int16_t cx, int16_t cy,
                                  int16_t rx, int16_t ry, int16_t skew,
                                  int start, int end,
                                  int16_t *pts, int max_pts)
{
    int32_t cs, sn, X, Y;
    int span, step, n = 0, t, last = start;

    if (max_pts < 2)
        return 0;

    /* A sweep may wrap through 0.  TeleGrafix's own demo does exactly this:
     * '|_' RIP_FILLED_OVAL_CHORD is issued with start=324 end=216, meaning
     * 324 deg -> 360/0 -> 216 deg, a 252 degree arc.  Bailing out when
     * end < start drew nothing at all for that command.  The driver handles
     * it by normalising against 360 (RVA 0x100125C0); adding a turn here is
     * the same thing, and rip_sin14()/rip_cos14() already reduce mod 360. */
    if (end < start)
        end += 360;

    cs   = rip_cos14(skew);
    sn   = rip_sin14(skew);
    span = end - start;
    step = span / (max_pts - 1) + 1;

    for (t = start; t <= end && n < max_pts; t += step) {
        X = ((int32_t)rx * rip_cos14(t)) >> RIP_Q14;
        Y = ((int32_t)ry * rip_sin14(t)) >> RIP_Q14;
        pts[2 * n]     = (int16_t)(cx + ((X * cs - Y * sn) >> RIP_Q14));
        pts[2 * n + 1] = (int16_t)(cy - ((X * sn + Y * cs) >> RIP_Q14));
        last = t;
        n++;
    }
    if (n > 0 && n < max_pts && last != end) {
        X = ((int32_t)rx * rip_cos14(end)) >> RIP_Q14;
        Y = ((int32_t)ry * rip_sin14(end)) >> RIP_Q14;
        pts[2 * n]     = (int16_t)(cx + ((X * cs - Y * sn) >> RIP_Q14));
        pts[2 * n + 1] = (int16_t)(cy - ((X * sn + Y * cs) >> RIP_Q14));
        n++;
    }
    return n;
}

/* Defined further down with the other fill helpers; the skewed-oval renderer
 * needs them here so the family honours |N the same way |O and |I do. */
static bool rip_begin_filled_border(rip_state_t *s, uint8_t *saved_mode);
static void rip_end_filled_border(rip_state_t *s, uint8_t saved_mode);

/* -- Multi-contour (poly-polygon) fill ------------------------------------
 * '|<' RIP_POLY_POLYGON submits several closed contours as ONE shape, and
 * the interior is decided by the even-odd rule across all of them together:
 * where contours overlap, the overlap is a HOLE.  TeleGrafix's own demo
 * (ICONS/POLYPOLY.RIP) draws a circle behind the shape and comments "so you
 * can see the transparency aspect", so the holes are the point of the
 * command -- filling each contour independently would paint them solid and
 * lose exactly the effect being demonstrated.
 *
 * Contours are stored back-to-back in `pts` with `starts[i]`/`counts[i]`
 * delimiting each one. */
/* Sized for the stack, not for generosity.  RIPlib runs on Cortex-M parts
 * whose whole stack is 4-8 KB, and this command needs two buffers live at
 * once: the point array plus the scanline intersection list.  128 points
 * across 32 contours is comfortably more than real content uses --
 * TeleGrafix's ICONS/POLYPOLY.RIP, the only shipped scene exercising '|<',
 * submits 5 contours totalling 18 points. */
#define RIP_POLYPOLY_MAX_CONTOURS  32
#define RIP_POLYPOLY_MAX_PTS      128

static void rip_fill_poly_polygon(const int16_t *pts,
                                  const int16_t *starts, const int16_t *counts,
                                  int ncontours)
{
    int16_t xs[RIP_POLYPOLY_MAX_PTS];
    int16_t ymin = 32767, ymax = -32768;
    int c, i, y, n, a, b;

    for (c = 0; c < ncontours; c++) {
        for (i = 0; i < counts[c]; i++) {
            int16_t py = pts[2 * (starts[c] + i) + 1];
            if (py < ymin) ymin = py;
            if (py > ymax) ymax = py;
        }
    }
    if (ymin > ymax)
        return;

    for (y = ymin; y <= ymax; y++) {
        n = 0;
        for (c = 0; c < ncontours; c++) {
            int cnt = counts[c];
            for (i = 0; i < cnt && n < RIP_POLYPOLY_MAX_PTS; i++) {
                const int16_t *p0 = &pts[2 * (starts[c] + i)];
                const int16_t *p1 = &pts[2 * (starts[c] + (i + 1) % cnt)];
                int16_t y0 = p0[1], y1 = p1[1];

                /* Half-open rule: count an edge only where y0 <= y < y1 (or
                 * the mirror), so shared vertices are not counted twice. */
                if ((y0 <= y && y1 > y) || (y1 <= y && y0 > y)) {
                    int32_t dx = (int32_t)p1[0] - p0[0];
                    int32_t dy = (int32_t)y1 - y0;
                    xs[n++] = (int16_t)(p0[0] + dx * (y - y0) / dy);
                }
            }
        }
        /* Insertion sort: spans are short and this avoids pulling in qsort. */
        for (a = 1; a < n; a++) {
            int16_t v = xs[a];
            for (b = a - 1; b >= 0 && xs[b] > v; b--)
                xs[b + 1] = xs[b];
            xs[b + 1] = v;
        }
        for (a = 0; a + 1 < n; a += 2)
            draw_line(xs[a], (int16_t)y, xs[a + 1], (int16_t)y);
    }
}

/* '|P' RIP_POLYGON, '|p' RIP_FILL_POLYGON and '|l' RIP_POLYLINE.
 *
 * Vertex cap, and why it moved.  This used to allow at most 64 vertices and
 * REJECT anything larger outright -- not truncate, drop the whole command.
 * Real content exceeds that: TeleGrafix's HAWK.RIP declares a 153-vertex
 * filled polygon and LGF1.RIP two of 88 and 85, so those shapes rendered as
 * nothing at all.  The old comment justified the cap as keeping the point
 * array on the stack and "out of the malloc fallback path inside
 * draw_polygon", but draw_polygon already handles any n -- 64 intersections
 * on the stack, malloc above that -- so the cap only ever cost content.
 *
 * The array lives here rather than in the command switch for the same
 * reason '|<' does: inside the switch it would sit in execute_rip_command's
 * frame and every command in the protocol would pay for it. */
#define RIP_POLY_MAX_PTS 192      /* corpus maximum is 153 */

static void rip_exec_polygon(rip_state_t *s, char cmd, const char *p, int len)
{
    int16_t pts[2 * RIP_POLY_MAX_PTS];
    int npts, i;

    if (len < 6)
        return;
    npts = mega2(p);
    /* Two vertices is the driver's own floor -- '|<' reports "Must have at
     * least two vertices to make a polygon" -- and the ceiling is this
     * buffer.  A stream above it is still refused rather than silently
     * drawn short, because half a polygon is a wrong shape, not a partial
     * one. */
    if (npts < 2 || npts > RIP_POLY_MAX_PTS)
        return;
    if (len < 2 + npts * 4)
        return;

    for (i = 0; i < npts; i++) {
        pts[i * 2]     = mega2(p + 2 + i * 4);
        pts[i * 2 + 1] = scale_y(mega2(p + 4 + i * 4));
    }

    if (cmd == 'l') {
        draw_polyline(pts, npts);
    } else if (cmd == 'p') {
        uint8_t border_mode;
        if (s->fill_pattern != 0) {
            draw_set_color(s->palette[s->fill_color & 0x0F]);
            draw_polygon(pts, npts, true);
        }
        if (rip_begin_filled_border(s, &border_mode)) {
            draw_polygon(pts, npts, false);
            rip_end_filled_border(s, border_mode);
        } else {
            draw_set_color(s->palette[s->draw_color & 0x0F]);
        }
    } else {
        draw_polygon(pts, npts, false);
    }
}

/* '|<' RIP_POLY_POLYGON, kept out of the command switch purely for STACK.
 *
 * Its point array and contour index tables total several hundred bytes, and
 * inside the switch those bytes sit in execute_rip_command's frame — so
 * every command in the protocol pays for them on every call.  Measured with
 * arm-none-eabi-gcc -fstack-usage for cortex-m4, leaving them there pushed
 * the dispatcher from 648 to 1024 bytes.  Here they are live only while
 * this one command runs.
 *
 * Dispatch slot 13 (RVA 0x01e80a), VARIABLE length.  The handler reads
 * arg[0] as a count and walks the rest; its own diagnostics are "Must have
 * at least two vertices to make a polygon" and "Insufficient vertices (2)".
 * Wire layout read off TeleGrafix's ICONS/POLYPOLY.RIP, which labels itself
 * RIP_POLY_POLYGON on screen:
 *
 *     count:2  then per contour  nverts:2  followed by nverts * (x:2 y:2)
 */
static void rip_exec_poly_polygon(rip_state_t *s, const char *p, int len)
{
    int16_t pts[2 * RIP_POLYPOLY_MAX_PTS];
    /* int16_t, not int: 32 contours x two tables costs 256 bytes as int
     * and 128 as int16_t, and neither index can exceed
     * RIP_POLYPOLY_MAX_PTS. */
    int16_t starts[RIP_POLYPOLY_MAX_CONTOURS];
    int16_t counts[RIP_POLYPOLY_MAX_CONTOURS];
    int npolys, off = 2, ncontours = 0, total = 0, c, i;
    uint8_t border_mode;

    if (len < 2)
        return;
    npolys = mega2(p);
    if (npolys > RIP_POLYPOLY_MAX_CONTOURS)
        npolys = RIP_POLYPOLY_MAX_CONTOURS;

    for (c = 0; c < npolys; c++) {
        int nv;

        if (off + 2 > len)
            break;
        nv = mega2(p + off);
        off += 2;
        /* The driver rejects a contour with fewer than two vertices by
         * name; do the same rather than emitting a degenerate edge list. */
        if (nv < 2 || off + 4 * nv > len ||
            total + nv > RIP_POLYPOLY_MAX_PTS)
            break;

        starts[ncontours] = (int16_t)total;
        counts[ncontours] = (int16_t)nv;
        for (i = 0; i < nv; i++) {
            pts[2 * (total + i)]     = mega2(p + off + 4 * i);
            pts[2 * (total + i) + 1] = scale_y(mega2(p + off + 4 * i + 2));
        }
        total += nv;
        off   += 4 * nv;
        ncontours++;
    }

    if (ncontours == 0)
        return;

    if (s->fill_pattern != 0) {
        draw_set_color(s->palette[s->fill_color & 0x0F]);
        rip_fill_poly_polygon(pts, starts, counts, ncontours);
    }
    if (rip_begin_filled_border(s, &border_mode)) {
        for (c = 0; c < ncontours; c++)
            draw_polygon(&pts[2 * starts[c]], counts[c], false);
        rip_end_filled_border(s, border_mode);
    } else {
        draw_set_color(s->palette[s->draw_color & 0x0F]);
    }
}

/* Generated by scripts/dll-marker-glyphs.py -- do not edit by hand.
 *
 * The 36 RIP_PolyMarker glyph outlines, extracted from the driver's
 * descriptor table at RVA 0x07ca48.  Coordinates are in a normalised
 * space of +/-50 which the caller scales by the marker's half-width and
 * half-height and rotates by its skew.  Marker 0 has no outline: the
 * driver draws it with the shared ellipse generator, so it is a circle. */
static const int8_t rip_marker_pts[][2] = {
    {  -8, -50},{   8, -50},{   8,  -8},{  50,  -8},{  50,   8},{   8,   8},{   8,  50},{  -8,  50},
    {  -8,   8},{ -50,   8},{ -50,  -8},{  -8,  -8},{  -8, -50},{   8, -50},{   8, -13},{  41, -30},
    {  48, -16},{  11,   3},{  32,  36},{  23,  45},{   0,  13},{ -23,  45},{ -32,  36},{ -11,   3},
    { -48, -16},{ -41, -30},{  -8, -13},{ -50, -50},{ -34, -50},{   0,  -9},{  34, -50},{  50, -50},
    {   9,   0},{  50,  50},{  34,  50},{   0,   9},{ -34,  50},{ -50,  50},{  -9,   0},{ -34, -50},
    {  34, -50},{  34, -34},{  50, -34},{  50,  34},{  34,  34},{  34,  50},{ -34,  50},{ -34,  34},
    { -50,  34},{ -50, -34},{ -34, -34},{  -8, -50},{   8, -50},{   8, -23},{  23, -23},{  23,  -8},
    {  50,  -8},{  50,   8},{  23,   8},{  23,  23},{   8,  23},{   8,  50},{  -8,  50},{  -8,  23},
    { -23,  23},{ -23,   8},{ -50,   8},{ -50,  -8},{ -23,  -8},{ -23, -23},{  -8, -23},{   0, -25},
    {  50,  26},{ -50,  26},{   0, -50},{  35,   0},{   0,  50},{ -35,   0},{ -27, -20},{  50, -20},
    {  27,  20},{ -50,  20},{ -50, -20},{  27, -20},{  50,  20},{ -27,  20},{ -27, -20},{  27, -20},
    {  50,  20},{ -50,  20},{   0, -50},{  18, -31},{   0,   0},{  31, -18},{  50,   0},{  31,  18},
    {   0,   0},{  18,  31},{   0,  50},{ -18,  31},{   0,   0},{ -31,  18},{ -50,   0},{ -31, -18},
    {   0,   0},{ -18, -31},{ -20, -50},{  20, -50},{  10, -25},{  25, -10},{  50, -20},{  50,  20},
    {  25,  10},{  10,  25},{  20,  50},{ -20,  50},{ -10,  25},{ -25,  10},{ -50,  20},{ -50, -20},
    { -25, -10},{ -10, -25},{   0, -50},{  12, -38},{   5, -31},{   5,  -5},{  31,  -5},{  38, -12},
    {  50,   0},{  38,  12},{  31,   5},{   5,   5},{   5,  31},{  12,  38},{   0,  50},{ -12,  38},
    {  -5,  31},{  -5,   5},{ -31,   5},{ -38,  12},{ -50,   0},{ -38, -12},{ -31,  -5},{  -5,  -5},
    {  -5, -31},{ -12, -38},{   0, -50},{  29, -15},{   9, -15},{   9,  50},{  -9,  50},{  -9, -15},
    { -29, -15},{   0, -50},{  29, -15},{   9, -15},{   9,  19},{  18,  30},{  18,  50},{   9,  39},
    {  -9,  39},{ -18,  50},{ -18,  30},{  -9,  19},{  -9, -15},{ -29, -15},{   0, -50},{  50,  50},
    {   0,  30},{ -50,  50},{   0, -50},{  12, -35},{   5, -35},{   5,  35},{  12,  35},{   0,  50},
    { -12,  35},{  -5,  35},{  -5, -35},{ -12, -35},{   0, -50},{  15, -35},{   5, -35},{   5,  -5},
    {  35,  -5},{  35, -15},{  50,   0},{  35,  15},{  35,   5},{   5,   5},{   5,  35},{  15,  35},
    {   0,  50},{ -15,  35},{  -5,  35},{  -5,   5},{ -35,   5},{ -35,  15},{ -50,   0},{ -35, -15},
    { -35,  -5},{  -5,  -5},{  -5, -35},{ -15, -35},{   0, -50},{  10, -40},{   5, -40},{   5, -15},
    {  24, -32},{  21, -35},{  35, -35},{  35, -21},{  32, -24},{  15,  -5},{  40,  -5},{  40, -10},
    {  50,   0},{  40,  10},{  40,   5},{  15,   5},{  32,  24},{  35,  21},{  35,  35},{  21,  35},
    {  24,  32},{   5,  15},{   5,  40},{  10,  40},{   0,  50},{ -10,  40},{  -5,  40},{  -5,  15},
    { -24,  32},{ -21,  35},{ -35,  35},{ -35,  21},{ -32,  24},{ -15,   5},{ -40,   5},{ -40,  10},
    { -50,   0},{ -40, -10},{ -40,  -5},{ -15,  -5},{ -32, -24},{ -35, -21},{ -35, -35},{ -21, -35},
    { -24, -32},{  -5, -15},{  -5, -40},{ -10, -40},{   0, -50},{  44,  25},{ -44,  25},{ -50, -50},
    {  50, -50},{  50,  50},{ -50,  50},{   0, -50},{  48, -15},{  33,  38},{ -33,  38},{ -48, -15},
    { -25, -43},{  25, -43},{  50,   0},{  25,  43},{ -25,  43},{ -50,   0},{   0, -50},{  39, -32},
    {  48,  11},{  22,  45},{ -22,  45},{ -48,  11},{ -39, -32},{ -22, -50},{  22, -50},{  50, -22},
    {  50,  22},{  22,  50},{ -22,  50},{ -50,  22},{ -50, -22},{ -17, -47},{  17, -47},{  43, -25},
    {  49,   8},{  33,  38},{   0,  50},{ -33,  38},{ -49,   8},{ -43, -25},{ -16, -47},{  16, -47},
    {  41, -30},{  50,   0},{  41,  30},{  16,  47},{ -16,  47},{ -41,  30},{ -50,   0},{ -41, -30},
    {   0, -50},{  11, -16},{  47, -16},{  18,   6},{  29,  41},{   0,  19},{ -29,  41},{ -18,   6},
    { -47, -16},{ -11, -16},{   0, -50},{  19, -25},{  43, -25},{  28,   0},{  43,  25},{  19,  25},
    {   0,  50},{ -19,  25},{ -43,  25},{ -28,   0},{ -43, -25},{ -19, -25},{   0, -50},{  11, -30},
    {  36, -36},{  30, -11},{  50,   0},{  30,  11},{  36,  36},{  11,  30},{   0,  50},{ -11,  30},
    { -36,  36},{ -30,  11},{ -50,   0},{ -30, -11},{ -36, -36},{ -11, -30},{   0, -50},{   8, -24},
    {  29, -41},{  21, -16},{  48, -16},{  26,   0},{  48,  16},{  21,  16},{  29,  41},{   8,  24},
    {   0,  50},{  -8,  24},{ -29,  41},{ -21,  16},{ -48,  16},{ -26,   0},{ -48, -16},{ -21, -16},
    { -29, -41},{  -8, -24},{   0, -50},{   7, -25},{  26, -43},{  18, -18},{  43, -26},{  25,  -7},
    {  50,   0},{  25,   7},{  43,  26},{  18,  18},{  26,  43},{   7,  25},{   0,  50},{  -7,  25},
    { -26,  43},{ -18,  18},{ -43,  26},{ -25,   7},{ -50,   0},{ -25,  -7},{ -43, -26},{ -18, -18},
    { -26, -43},{  -7, -25},{   0, -50},{   6, -26},{  22, -46},{  16, -20},{  39, -32},{  23, -12},
    {  50, -12},{  25,   0},{  50,  12},{  23,  12},{  39,  32},{  16,  20},{  22,  46},{   6,  26},
    {   0,  50},{  -6,  26},{ -22,  46},{ -16,  20},{ -39,  32},{ -23,  12},{ -50,  12},{ -25,   0},
    { -50, -12},{ -23, -12},{ -39, -32},{ -16, -20},{ -22, -46},{  -6, -26},{   0, -50},{   5, -25},
    {  19, -46},{  14, -21},{  36, -36},{  21, -14},{  46, -19},{  25,  -5},{  50,   0},{  25,   5},
    {  46,  19},{  21,  14},{  36,  36},{  14,  21},{  19,  46},{   5,  25},{   0,  50},{  -5,  25},
    { -19,  46},{ -14,  21},{ -36,  36},{ -21,  14},{ -46,  19},{ -25,   5},{ -50,   0},{ -25,  -5},
    { -46, -19},{ -21, -14},{ -36, -36},{ -14, -21},{ -19, -46},{  -5, -25},{   0, -50},{  10, -30},
    {  50, -50},{  30, -10},{  50,   0},{  30,  10},{  50,  50},{  10,  30},{   0,  50},{ -10,  30},
    { -50,  50},{ -30,  10},{ -50,   0},{ -30, -10},{ -50, -50},{ -10, -30},
};

static const struct { uint16_t off; uint8_t n; } rip_marker_glyph[36] = {
    {    0,  0 },   /*  0 */
    {    0, 12 },   /*  1 */
    {   12, 15 },   /*  2 */
    {   27, 12 },   /*  3 */
    {   39, 12 },   /*  4 */
    {   51, 20 },   /*  5 */
    {   71,  3 },   /*  6 */
    {   74,  4 },   /*  7 */
    {   78,  4 },   /*  8 */
    {   82,  4 },   /*  9 */
    {   86,  4 },   /* 10 */
    {   90, 16 },   /* 11 */
    {  106, 16 },   /* 12 */
    {  122, 24 },   /* 13 */
    {  146,  7 },   /* 14 */
    {  153, 13 },   /* 15 */
    {  166,  4 },   /* 16 */
    {  170, 10 },   /* 17 */
    {  180, 24 },   /* 18 */
    {  204, 48 },   /* 19 */
    {  252,  3 },   /* 20 */
    {  255,  4 },   /* 21 */
    {  259,  5 },   /* 22 */
    {  264,  6 },   /* 23 */
    {  270,  7 },   /* 24 */
    {  277,  8 },   /* 25 */
    {  285,  9 },   /* 26 */
    {  294, 10 },   /* 27 */
    {  304, 10 },   /* 28 */
    {  314, 12 },   /* 29 */
    {  326, 16 },   /* 30 */
    {  342, 20 },   /* 31 */
    {  362, 24 },   /* 32 */
    {  386, 28 },   /* 33 */
    {  414, 32 },   /* 34 */
    {  446, 16 },   /* 35 */
};



/* How the point run from rip_skewed_oval_points() is closed. */
typedef enum {
    RIP_OVAL_OUTLINE,   /* open run, stroked as a polyline (arc)          */
    RIP_OVAL_CLOSED,    /* run closed end-to-start (full oval, chord)     */
    RIP_OVAL_PIE        /* run closed through the centre (pie slice)      */
} rip_oval_close_t;

/* Shared renderer for the skewed-oval family.  `fill` requests the interior
 * be painted with the current fill state before the border is stroked, which
 * mirrors the driver handing the same point run to Polygon() twice. */
static void rip_draw_skewed_oval(rip_state_t *s,
                                 int16_t cx, int16_t cy,
                                 int16_t rx, int16_t ry, int16_t skew,
                                 int start, int end,
                                 rip_oval_close_t close, bool fill)
{
    int16_t pts[2 * (RIP_OVAL_MAX_PTS + 1)];
    uint8_t border_mode;
    int n;

    n = rip_skewed_oval_points(cx, cy, rx, ry, skew, start, end,
                               pts, RIP_OVAL_MAX_PTS);
    if (n < 2)
        return;

    if (close == RIP_OVAL_PIE) {
        pts[2 * n]     = cx;          /* close through the centre */
        pts[2 * n + 1] = cy;
        n++;
    }

    if (fill && s->fill_pattern != 0) {
        draw_set_color(s->palette[s->fill_color & 0x0F]);
        draw_polygon(pts, n, true);
    }

    if (close == RIP_OVAL_OUTLINE) {
        draw_set_color(s->palette[s->draw_color & 0x0F]);
        draw_polyline(pts, n);
        return;
    }

    if (fill) {
        /* Filled variants honour the border flag the same way the other
         * filled primitives do, so |N00 suppresses the outline. */
        if (rip_begin_filled_border(s, &border_mode)) {
            draw_polygon(pts, n, false);
            rip_end_filled_border(s, border_mode);
        } else {
            draw_set_color(s->palette[s->draw_color & 0x0F]);
        }
    } else {
        draw_set_color(s->palette[s->draw_color & 0x0F]);
        draw_polygon(pts, n, false);
    }
}

/* Draw one RIP_PolyMarker glyph.
 *
 * Marker 0 has no outline in the driver's table: it is dispatched to the
 * shared ellipse generator with a full 0..360 sweep, so it is a circle.
 * Every other number indexes the table above, whose coordinates live in a
 * normalised +/-50 space; the driver scales them by the command's half-width
 * and half-height and rotates by its skew, which is what happens here. */
static void rip_draw_marker(rip_state_t *s, int16_t cx, int16_t cy,
                            int num, int16_t hw, int16_t hh, int16_t rot)
{
    int16_t pts[2 * 48];
    int32_t cs, sn;
    int n, i;

    if (num < 0 || num >= 36)
        return;

    if (rip_marker_glyph[num].n == 0) {
        /* Marker 0: the circle, drawn by the same generator the skewed-oval
         * family uses -- which is exactly what the driver does. */
        rip_draw_skewed_oval(s, cx, cy, hw, hh, rot, 0, 360,
                             RIP_OVAL_CLOSED, false);
        return;
    }

    n  = rip_marker_glyph[num].n;
    cs = rip_cos14(rot);
    sn = rip_sin14(rot);
    for (i = 0; i < n && i < 48; i++) {
        const int8_t *g = rip_marker_pts[rip_marker_glyph[num].off + i];
        /* Normalised /50, then scaled to the requested half-extent. */
        int32_t X = ((int32_t)g[0] * hw) / 50;
        int32_t Y = ((int32_t)g[1] * hh) / 50;
        pts[2 * i]     = (int16_t)(cx + ((X * cs - Y * sn) >> RIP_Q14));
        pts[2 * i + 1] = (int16_t)(cy + ((X * sn + Y * cs) >> RIP_Q14));
    }
    draw_set_color(s->palette[s->draw_color & 0x0F]);
    draw_polygon(pts, i, false);
}

static void clamp_ega_rect(int16_t *x0, int16_t *y0,
                           int16_t *x1, int16_t *y1) {
    int16_t tx0 = *x0;
    int16_t ty0 = *y0;
    int16_t tx1 = *x1;
    int16_t ty1 = *y1;

    if (tx0 > tx1) { int16_t t = tx0; tx0 = tx1; tx1 = t; }
    if (ty0 > ty1) { int16_t t = ty0; ty0 = ty1; ty1 = t; }

    if (tx0 < 0) tx0 = 0;
    if (ty0 < 0) ty0 = 0;
    if (tx1 > 639) tx1 = 639;
    if (ty1 > 349) ty1 = 349;

    *x0 = tx0;
    *y0 = ty0;
    *x1 = tx1;
    *y1 = ty1;
}



static void rip_upload_reset(rip_state_t *s) {
    if (!s) return;
    s->upload_pos = 0;
    s->upload_name[0] = '\0';
    s->upload_name_len = 0;
    s->upload_name_remaining = 0;
    s->upload_name_overflow = false;
    s->upload_reading_name = false;
}

static void rip_cache_icn_if_valid(rip_state_t *s, const char *name, int name_len,
                                   const uint8_t *data, int size) {
    uint16_t icn_w;
    uint16_t icn_h;
    size_t pixel_count;
    uint8_t *pixels;

    if (!s || !data || !rip_filename_is_safe(name, name_len))
        return;
    if (!rip_icn_measure(data, size, &icn_w, &icn_h))
        return;

    pixel_count = (size_t)icn_w * (size_t)icn_h;
    if (pixel_count == 0 || pixel_count > RIP_CLIPBOARD_MAX)
        return;
    if (rip_icon_cache_count(&s->icon_state) >= RIP_ICON_CACHE_MAX &&
        !rip_icon_cache_has_runtime(&s->icon_state, name, name_len))
        return;

    pixels = (uint8_t *)psram_arena_alloc(&s->psram_arena, (uint32_t)pixel_count);
    if (!pixels)
        return;

    if (!rip_icn_parse(data, size, pixels, &icn_w, &icn_h))
        return;

    (void)rip_icon_cache_pixels_replace(&s->icon_state, name, name_len,
                                         pixels, icn_w, icn_h);
}

/* Map an EGA colour index (0-15) to its framebuffer slot.
 * The base is a port decision, not a protocol one — see RIPLIB_PALETTE_BASE
 * in riplib_platform.h and docs/spec/12-dll-provenance.md D-6.  The default
 * (240) preserves v1.x behaviour. */
static uint8_t palette_slot(int idx) {
    return (uint8_t)(RIPLIB_PALETTE_BASE + idx);
}


static int rip_font_id_from_name(const char *name, int len) {
    static const struct {
        const char *tag;
        int id;
    } fonts[] = {
        { "TRIP", BGI_FONT_TRIPLEX },
        { "LITT", BGI_FONT_SMALL },
        { "SANS", BGI_FONT_SANS },
        { "GOTH", BGI_FONT_GOTHIC },
        { "SCRI", BGI_FONT_SCRIPT },
        { "SIMP", BGI_FONT_SIMPLEX },
        { "TSCR", BGI_FONT_TRIPLEX_SCR },
        { "LCOM", BGI_FONT_COMPLEX },
        { "EURO", BGI_FONT_EUROPEAN },
        { "BOLD", BGI_FONT_BOLD },
    };
    int start = 0;
    int end = len;

    if (!name || len <= 0)
        return -1;
    for (int i = 0; i < len; i++) {
        if (name[i] == '/' || name[i] == '\\' || name[i] == ':')
            start = i + 1;
    }
    for (int i = start; i < len; i++) {
        if (name[i] == '.') {
            end = i;
            break;
        }
    }

    for (size_t fi = 0; fi < sizeof(fonts) / sizeof(fonts[0]); fi++) {
        const char *tag = fonts[fi].tag;
        size_t tag_len = strlen(tag);
        if ((size_t)(end - start) != tag_len)
            continue;
        bool match = true;
        for (size_t j = 0; j < tag_len; j++) {
            char c = name[start + (int)j];
            if (c >= 'a' && c <= 'z')
                c = (char)(c - 32);
            if (c != tag[j]) {
                match = false;
                break;
            }
        }
        if (match)
            return fonts[fi].id;
    }
    return -1;
}

/* ══════════════════════════════════════════════════════════════════
 * DEFAULT EGA PALETTE → RGB565
 * ══════════════════════════════════════════════════════════════════ */

/* Default 16-color EGA palette as RGB565 (for draw color mapping) */
static const uint16_t ega_default_rgb565[16] = {
    0x0000, /* 0:  black */
    0x0015, /* 1:  blue */
    0x0540, /* 2:  green */
    0x0555, /* 3:  cyan */
    0xA800, /* 4:  red */
    0xA815, /* 5:  magenta */
    0xAAA0, /* 6:  brown */
    0xAD55, /* 7:  light gray */
    0x52AA, /* 8:  dark gray */
    0x52BF, /* 9:  light blue */
    0x57EA, /* 10: light green */
    0x57FF, /* 11: light cyan */
    0xFAAA, /* 12: light red */
    0xFABF, /* 13: light magenta */
    0xFFEA, /* 14: yellow */
    0xFFFF, /* 15: white */
};

/* EGA 64-color master palette → RGB565 conversion.
 * EGA 6-bit format: bits 5:0 = r'g'b'RGB where RGB are high intensity,
 * r'g'b' are secondary (2/3 intensity). Each channel is 2-bit:
 *   channel = (high_bit << 1) | low_bit → 0,1,2,3 → {0x00, 0x55, 0xAA, 0xFF} */
static uint16_t ega64_to_rgb565(uint8_t ega) {
    /* Bit layout: bit5=r' bit4=g' bit3=b' bit2=R bit1=G bit0=B */
    uint8_t R = ((ega >> 2) & 1) << 1 | ((ega >> 5) & 1);
    uint8_t G = ((ega >> 1) & 1) << 1 | ((ega >> 4) & 1);
    uint8_t B = ((ega >> 0) & 1) << 1 | ((ega >> 3) & 1);
    /* 2-bit to 8-bit: 0→0, 1→0x55, 2→0xAA, 3→0xFF */
    static const uint8_t lut[4] = {0x00, 0x55, 0xAA, 0xFF};
    uint8_t r8 = lut[R], g8 = lut[G], b8 = lut[B];
    return ((uint16_t)(r8 >> 3) << 11) |
           ((uint16_t)(g8 >> 2) << 5) |
           ((uint16_t)(b8 >> 3));
}

/* ══════════════════════════════════════════════════════════════════
 * INITIALIZATION
 * ══════════════════════════════════════════════════════════════════ */

/* Save current hardware palette indices 240-255 into rip_state_t.
 * Called by the compositor's ripscrip_deactivate() before switching away so
 * that BBS-customized colors (written by RIP_SET_PALETTE / RIP_ONE_PALETTE)
 * are not lost when xterm-256 reloads its own palette on the next protocol. */
void rip_save_palette(rip_state_t *s) {
    if (!s) return;
    for (int i = 0; i < 16; i++)
        s->saved_palette_rgb565[i] = palette_read_rgb565(palette_slot(i));
}

/* Re-apply EGA palette to hardware — called when the EMU's xterm palette
 * overwrites entries 240-255 after a mode switch back to RIPscrip.
 * Uses saved_palette_rgb565 if a snapshot exists (non-zero); otherwise
 * falls back to EGA defaults so a fresh session still has correct colors. */
void rip_apply_palette_state(rip_state_t *s) {
    if (!s) return;
    /* Check whether a non-default snapshot exists. A BBS that called
     * RIP_SET_PALETTE will have written at least one non-default value; if
     * saved_palette_rgb565 is entirely zero the snapshot has never been taken
     * (new session) and we restore EGA defaults instead. */
    bool has_snapshot = false;
    for (int i = 0; i < 16; i++) {
        if (s->saved_palette_rgb565[i] != 0) {
            has_snapshot = true;
            break;
        }
    }
    if (has_snapshot) {
        for (int i = 0; i < 16; i++)
            palette_write_rgb565(palette_slot(i), s->saved_palette_rgb565[i]);
    } else {
        for (int i = 0; i < 16; i++)
            palette_write_rgb565(palette_slot(i), ega_default_rgb565[i]);
    }
}

/* Single-session wrapper — routes through g_rip_state.
 * See SESSION SAFETY in ripscrip.h. */
void rip_apply_palette(void) {
    rip_apply_palette_state(g_rip_state);
}

/* Boot-time init — call ONCE at power-on (or on first use).
 * Performs the full memset, arena reservation, drawing defaults, and BGI
 * font parse.  Calling this on a mid-session protocol switch would wipe
 * session state (clipboard, mouse regions, text variables, PSRAM arena).
 * For protocol switches, call rip_activate() instead.
 *
 * IMPORTANT API CONTRACT: the caller MUST zero `s` before the very first
 * call (e.g. via memset or by using a static-storage instance).  The
 * function reads s->psram_arena to decide whether an arena is already
 * reserved — if the struct contains uninitialized stack garbage, that
 * read is UB and the arena allocation may be skipped.  All callers in
 * this tree (test fixtures, demo, embedded boot) honor this contract. */
void rip_init_first(rip_state_t *s) {
    psram_arena_t saved_arena;

    if (!s) return;

    /* Snapshot the arena state.  After memset we will restore it so a
     * second rip_init_first() call (mid-session re-init) does not leak
     * the previously allocated PSRAM block.  On the first call, the
     * caller-zeroed struct has saved_arena.base == NULL which is the
     * "no arena yet" signal that drives psram_arena_init() below. */
    saved_arena = s->psram_arena;
    memset(s, 0, sizeof(*s));
    s->psram_arena = saved_arena;

    /* Allocate arena on first init.  Treat (base==NULL || size==0) as
     * "needs alloc" — covers both fresh zero-init and prior failed
     * allocation states.  A previously-successful arena has base!=NULL
     * and size>0, so we preserve it across re-init. */
    if (s->psram_arena.base == NULL || s->psram_arena.size == 0)
        psram_arena_init(&s->psram_arena, RIP_PSRAM_ARENA_SIZE);

    /* Bind the icon module to this arena.  Cache is cleared because we just
     * memset'd — all PSRAM pixel pointers from a previous session are gone. */
    rip_icon_set_arena(&s->icon_state, &s->psram_arena);

    g_rip_state = s;
    s->draw_color = 15; /* white */
    s->back_color = 0;  /* Background color — default black */
    s->line_pattern = 0xFFFF;
    s->line_thick = 1;
    s->fill_pattern = 1; /* solid */
    s->fill_color = 15; /* Default fill_color is white (15), not black — matches DLL rip_defaults */
    s->font_size = 1;
    s->tw_x1 = 639;
    s->tw_y1 = 349;
    s->vp_x0 = 0; s->vp_y0 = 0;
    s->vp_x1 = 639; s->vp_y1 = 399;

    /* Default palette: map EGA indices 0-15 to framebuffer slots starting at
     * RIPLIB_PALETTE_BASE (240 by default, so the EGA block sits above an
     * xterm-256 text palette occupying 0-239).  A port that owns the whole
     * framebuffer can define RIPLIB_PALETTE_BASE=0 — see riplib_platform.h.
     * RIP draw commands write framebuffer value s->palette[color]; the host
     * converts via its own palette[] → RGB565. */
    for (int i = 0; i < 16; i++) {
        s->palette[i] = palette_slot(i);
        palette_write_rgb565(palette_slot(i), ega_default_rgb565[i]);
    }

    /* Scene/protocol mode defaults.  Rendering is always to the fixed indexed
     * framebuffer, but the v2.x commands and variables observe this state. */
    s->header_type = 0;
    s->header_id = 0;
    s->header_flags = 0;
    s->resolution_mode = 0;
    s->coordinate_size = 2;
    s->coordinate_res = 0;
    s->color_mode = 0;
    s->color_bits = 0;
    s->filled_borders_enabled = true;

    /* v3.1: application variables and overflow pagination */
    memset(s->app_vars, 0, sizeof(s->app_vars));

    /* Seed the $RAND$ LCG from the local RTC timestamp.
     * Using time() gives a different sequence per session (good enough
     * for BBS use).  The memset above zeroed rand_state; a zero seed is
     * valid for the Knuth LCG — first output will be 12345 — but we
     * prefer time entropy.  Tests override the seed for deterministic
     * replay; see test_rand_reproducibility. */
    s->rand_state = (uint32_t)time(NULL);

    /* refresh_suppress starts false (normal refresh enabled). */
    s->refresh_suppress = false;

    ripscrip2_init(&s->rip2_state);

    /* Parse all BGI stroke fonts (flash data, parsed once at boot). */
    if (!bgi_fonts_loaded) {
        bgi_font_parse(&bgi_fonts[BGI_FONT_TRIPLEX], bgi_font_trip, bgi_font_trip_size);
        bgi_font_parse(&bgi_fonts[BGI_FONT_SMALL],   bgi_font_litt, bgi_font_litt_size);
        bgi_font_parse(&bgi_fonts[BGI_FONT_SANS],    bgi_font_sans, bgi_font_sans_size);
        bgi_font_parse(&bgi_fonts[BGI_FONT_GOTHIC],  bgi_font_goth, bgi_font_goth_size);
        bgi_font_parse(&bgi_fonts[BGI_FONT_SCRIPT],  bgi_font_scri, bgi_font_scri_size);
        bgi_font_parse(&bgi_fonts[BGI_FONT_SIMPLEX],    bgi_font_simp, bgi_font_simp_size);
        bgi_font_parse(&bgi_fonts[BGI_FONT_TRIPLEX_SCR],bgi_font_tscr, bgi_font_tscr_size);
        bgi_font_parse(&bgi_fonts[BGI_FONT_COMPLEX],    bgi_font_lcom, bgi_font_lcom_size);
        bgi_font_parse(&bgi_fonts[BGI_FONT_EUROPEAN],   bgi_font_euro, bgi_font_euro_size);
        bgi_font_parse(&bgi_fonts[BGI_FONT_BOLD],       bgi_font_bold, bgi_font_bold_size);
        bgi_fonts_loaded = true;
    }

    /* ── Drawing Ports — boot-time initialization ──────────────────
     * Port 0 is permanent: full-screen viewport, protected, always active.
     * memset above already zeroed ports[]; only non-zero fields need init. */
    {
        rip_port_t *p0 = &s->ports[0];
        p0->allocated    = true;
        p0->flags        = RIP_PORT_FLAG_PERMANENT | RIP_PORT_FLAG_FULLSCREEN;
        p0->vp_x0        = 0;
        p0->vp_y0        = 0;
        p0->vp_x1        = 639;
        p0->vp_y1        = 399;   /* pixel coords (EGA 349 -> display 399 after scale_y) */
        p0->draw_color   = 15;    /* white -- matches s->draw_color default */
        p0->fill_color   = 15;
        p0->fill_pattern = 1;     /* solid */
        p0->back_color   = 0;
        p0->write_mode   = 0;     /* COPY */
        p0->line_pattern = 0xFFFF;
        p0->line_thick   = 1;
        p0->font_size    = 1;
        p0->font_hjust   = 0;
        p0->font_vjust   = 0;
        p0->font_attrib  = 0;
        p0->font_ext_id  = 0;
        p0->font_ext_attr = 0;
        p0->font_ext_size = 0;
        p0->alpha        = 35;    /* fully opaque */
    }
    s->active_port = 0;
}

/* Protocol-switch activation.
 * Called every time the host's compositor switches to RIPscrip
 * (including the first time).  Restores the EGA hardware palette and
 * marks the framebuffer dirty so the BBS screen is repainted.  Does NOT
 * memset or touch session state — clipboard, mouse regions, text
 * variables, and the PSRAM arena are all preserved across a temporary
 * switch to VT100 etc.  query_pending / query_var_name are also left
 * untouched so a pending $QUERY$ round-trip that was interrupted by a
 * protocol switch resumes correctly when RIPscrip is reactivated. */
void rip_activate(rip_state_t *s) {
    if (!s) return;
    g_rip_state = s;

    /* Restore BBS-customized palette (or EGA defaults on first activation).
     * rip_save_palette() captured saved_palette_rgb565 before the previous
     * deactivation; rip_apply_palette() writes it back to hardware. */
    rip_apply_palette();

    /* Re-apply the active session's drawing and clip state. */
    apply_session_draw_state(s);
}

/* Session disconnect reset.
 * Call this when the BBS connection is dropped (NOT on a protocol
 * switch).  Reclaims the PSRAM arena, clears mouse regions, text
 * variables, query state, icon request queue, and upload staging —
 * all the per-session data that must not carry over to the next BBS
 * connection.  The PSRAM arena block itself is NOT freed (it stays
 * reserved for the next session); psram_arena_reset() just rewinds
 * the bump pointer.  Also flushes the pending icon file request
 * queue and clears any unanswered $QUERY$ metadata so neither leaks
 * into the next session. */
void rip_session_reset(rip_state_t *s) {
    if (!s) return;
    g_rip_state = s;

    /* Reclaim all PSRAM arena allocations (clipboard pixels, cached icon
     * pixels, upload staging buffer) from the disconnected session. */
    psram_arena_reset(&s->psram_arena);

    /* Rebind the icon cache to the freshly-reset arena.  This also clears
     * the runtime cache so stale pixel pointers into the old arena are gone. */
    rip_icon_set_arena(&s->icon_state, &s->psram_arena);

    /* Flush the pending icon file request queue. */
    rip_icon_clear_requests(&s->icon_state);

    /* Clear upload staging pointer — it pointed into the now-reset arena. */
    s->upload_buf = NULL;
    rip_upload_reset(s);

    /* Clear mouse regions from the previous session. */
    memset(s->mouse_regions, 0, sizeof(s->mouse_regions));
    s->num_mouse_regions = 0;

    /* Clear text block state. */
    s->text_block.active = false;

    /* Clear query/prompt metadata — an unanswered $QUERY$ from the
     * disconnected session must not carry over to the next BBS. */
    s->query_pending = false;
    memset(s->query_var_name,  0, sizeof(s->query_var_name));
    memset(s->query_response,  0, sizeof(s->query_response));
    s->query_response_len = 0;

    /* Clear clipboard — pixel data was in the arena, now invalid. */
    s->clipboard.data  = NULL;
    s->clipboard.valid = false;
    s->clipboard.width = 0;
    s->clipboard.height = 0;
    memset(s->icon_slots, 0, sizeof(s->icon_slots));
    memset(s->icon_slot_valid, 0, sizeof(s->icon_slot_valid));
    s->icon_style_active = false;
    s->icon_style_x0 = 0;
    s->icon_style_y0 = 0;
    s->icon_style_x1 = 0;
    s->icon_style_y1 = 0;
    s->icon_style_style = 0;
    s->icon_style_align = 0;
    s->icon_style_scale = 0;

    /* Clear application variables. */
    memset(s->app_vars, 0, sizeof(s->app_vars));
    memset(s->user_var_names, 0, sizeof(s->user_var_names));
    memset(s->user_var_values, 0, sizeof(s->user_var_values));
    s->user_var_count = 0;

    /* Reset scene/protocol mode metadata for the next BBS session. */
    s->header_type = 0;
    s->header_id = 0;
    s->header_flags = 0;
    s->resolution_mode = 0;
    s->coordinate_size = 2;
    s->coordinate_res = 0;
    s->color_mode = 0;
    s->color_bits = 0;
    s->filled_borders_enabled = true;

    /* Reset stream preprocessor state. */
    rip_preproc_init(s);

    /* Reset ripscrip2 overflow state. */
    ripscrip2_init(&s->rip2_state);

    /* Reset parser and drawing defaults for the next session. */
    s->state = RIP_ST_IDLE;
    s->cmd_len = 0;
    s->cmd_char = '\0';
    clear_levels(s);
    s->last_char = 0;
    s->esc_detect = 0;
    s->utf8_pipe_pending = false;
    s->draw_x = 0;
    s->draw_y = 0;
    s->draw_color = 15;
    s->back_color = 0;
    s->write_mode = 0;
    s->line_style = 0;
    s->line_pattern = 0xFFFF;
    s->line_thick = 1;
    s->fill_pattern = 1;
    s->fill_color = 15;
    s->font_id = 0;
    s->font_dir = 0;
    s->font_size = 1;
    s->font_hjust = 0;
    s->font_vjust = 0;
    s->font_attrib = 0;
    s->font_ext_id = 0;
    s->font_ext_attr = 0;
    s->font_ext_size = 0;
    /* World coordinate frame ('f' RIP_SET_WORLD_FRAME).  Cleared on session
     * reset so a new connection does not inherit the previous scene's frame.
     * NOTE: deliberately NOT cleared by '*' RIP_RESET_WINDOWS — whether the
     * driver drops the world frame there is unverified, and guessing would
     * enshrine an unknown.  Tracked with D-1 in docs/spec/12-dll-provenance.md. */
    s->world_w = 0;
    s->world_h = 0;
    s->tw_x0 = 0;
    s->tw_y0 = 0;
    s->tw_x1 = 639;
    s->tw_y1 = 349;
    s->tw_wrap = 0;
    s->tw_font_size = 0;
    s->tw_cur_x = 0;
    s->tw_cur_y = 0;
    s->tw_active = false;
    s->rip_has_drawn = false;
    s->cursor_repositioned = false;
    s->refresh_suppress = false;

    /* Reset Drawing Port table — deallocate all ports except port 0.
     * Port 0 gets its state refreshed to defaults; other slots are cleared. */
    memset(&s->ports[0], 0, sizeof(rip_port_t));
    for (int i = 1; i < RIP_MAX_PORTS; i++)
        memset(&s->ports[i], 0, sizeof(rip_port_t));
    {
        rip_port_t *p0 = &s->ports[0];
        p0->allocated    = true;
        p0->flags        = RIP_PORT_FLAG_PERMANENT | RIP_PORT_FLAG_FULLSCREEN;
        p0->vp_x0        = 0;   p0->vp_y0 = 0;
        p0->vp_x1        = 639; p0->vp_y1 = 399;
        p0->draw_color   = 15;
        p0->fill_color   = 15;
        p0->fill_pattern = 1;
        p0->back_color   = 0;
        p0->write_mode   = 0;
        p0->line_pattern = 0xFFFF;
        p0->line_thick   = 1;
        p0->font_size    = 1;
        p0->font_hjust   = 0;
        p0->font_vjust   = 0;
        p0->font_attrib  = 0;
        p0->font_ext_id  = 0;
        p0->font_ext_attr = 0;
        p0->font_ext_size = 0;
        p0->alpha        = 35;
    }
    s->active_port = 0;
    s->vp_x0 = 0; s->vp_y0 = 0;
    s->vp_x1 = 639; s->vp_y1 = 399;
    apply_session_draw_state(s);
}

/* ══════════════════════════════════════════════════════════════════
 * BGI FILL STYLE → CARD FILL PATTERN MAPPING
 *
 * BGI fill styles (used by RIPscrip 'S' command):
 *   0=EMPTY 1=SOLID 2=LINE 3=LTSLASH 4=SLASH 5=BKSLASH
 *   6=LTBKSLASH 7=HATCH 8=XHATCH 9=INTERLEAVE 10=WIDE_DOT 11=CLOSE_DOT
 *   12=USER
 *
 * Card fill engine uses: 0=solid, 1-7=predefined, 8=user pattern.
 * BGI 0 (EMPTY) needs special handling — don't fill at all.
 * ══════════════════════════════════════════════════════════════════ */

/* Map BGI fill_style to card pattern_id. Returns -1 for EMPTY_FILL.
 *
 * BGI styles (Borland Graphics Interface):
 *   0 EMPTY 1 SOLID 2 LINE 3 LTSLASH 4 SLASH 5 BKSLASH
 *   6 LTBKSLASH 7 HATCH 8 XHATCH 9 INTERLEAVE 10 WIDE_DOT 11 CLOSE_DOT 12 USER
 *
 * Card fill_patterns[] (drawing.c): 0=solid 1=50%checker 2=diag\ 3=diag/
 *   4=horizontal 5=vertical 6=hatch 7=lightdiag 8=interleave 9=widedot
 *   10=closedot.  Slot 11 = user_pattern[].
 *
 * Previous mapping (bgi_style-1) was incorrect — BGI 2 LINE is supposed
 * to be horizontal lines but mapped to the 50% checker.  This table maps
 * each BGI style to the closest visually-matching built-in pattern.
 *
 * Exposed via include/ripscrip.h so tests and ripscrip2.c can share it. */
int8_t rip_bgi_fill_to_card(uint8_t bgi_style) {
    switch (bgi_style) {
        case 0:  return -1;  /* EMPTY  — caller skips fill */
        case 1:  return 0;   /* SOLID  → solid */
        case 2:  return 4;   /* LINE   → horizontal */
        case 3:  return 7;   /* LTSLASH→ light diagonal (sparse /) */
        case 4:  return 3;   /* SLASH  → diagonal / */
        case 5:  return 2;   /* BKSLASH→ diagonal \ */
        case 6:  return 2;   /* LTBKSLASH→ diagonal \ (no lighter variant) */
        case 7:  return 6;   /* HATCH  → cross-hatch */
        case 8:  return 1;   /* XHATCH → 50% checker (closest dense X feel) */
        case 9:  return 8;   /* INTERLEAVE → CC/33 interleave */
        case 10: return 9;   /* WIDE_DOT */
        case 11: return 10;  /* CLOSE_DOT */
        case 12: return 11;  /* USER → user_pattern */
        default: return 0;   /* unknown → solid */
    }
}

/* Internal alias retained for the rest of this TU. */
static int8_t bgi_fill_to_card(uint8_t bgi_style) {
    return rip_bgi_fill_to_card(bgi_style);
}

static uint16_t rip_reverse16(uint16_t v) {
    uint16_t r = 0;
    for (int i = 0; i < 16; i++) {
        r = (uint16_t)((r << 1) | (v & 1u));
        v = (uint16_t)(v >> 1);
    }
    return r;
}

static uint16_t rip_line_style_to_pattern(uint8_t style, uint16_t user_pat) {
    switch (style) {
    case 0:  return 0xFFFF;                /* solid */
    case 1:  return 0x3333;                /* dotted */
    case 2:  return 0xE7E7;                /* center */
    case 3:  return 0x1F1F;                /* dashed */
    case 4:  return rip_reverse16(user_pat); /* user_pat is MSB-first on wire */
    default: return 0xFFFF;
    }
}

/* ══════════════════════════════════════════════════════════════════
 * TEXT ESCAPE PROCESSING — \\ \| \^ \n inline escapes (+ \! extension)
 *
 * RIPscrip text parameters use backslash escapes (spec §1.6 / §7.1):
 *   \\ = literal '\'   \| = literal '|'   \^ = literal '^'
 *   \n = newline (0x0A)
 * RIPlib also accepts \! = literal '!' as an extension (RIPlib uses '!'
 * as the command-frame lead-in; see docs/spec/11-dll-deviations.md).
 * Returns unescaped length (always <= input length, in-place safe).
 * ══════════════════════════════════════════════════════════════════ */

/* `dst_max` is the capacity of dst and is enforced here rather than left to
 * each caller.
 *
 * It was previously left to callers, and four of the six clamped their
 * length argument by hand while two did not.  Those two wrote into a
 * 256-byte buffer and were safe only because cmd_buf happened to be 256, so
 * `len` could never exceed 255 — the sizes matched by accident, not by
 * design.  Widening cmd_buf to hold the corpus's longest command turned
 * that into an immediate stack-smash.  Bounding the function removes the
 * whole class instead of adding two more hand clamps. */
/* Request an asset whose name may contain $VARIABLE$ references.
 *
 * The driver interpolates before it uses the name.  Its scanner at RVA
 * 0x04B0E4 -- identified by the two `cmp ..., 0x24` it turns on -- is reached
 * by twelve dispatch entries, RIP_ReadScene and RIP_LoadBitmap among them, and
 * RIPlib was running that path only for TEXT.  NEWSPAPR.RIP sends
 *
 *     !|1R00000000$&MAIN_STORY$
 *
 * so the request went out as the literal string.  '&' is NOT a sigil, on
 * either side: the driver's scanner compares against '$' alone, so the
 * variable is simply named "&MAIN_STORY".
 *
 * Expansion happens BEFORE the safety check, never after, so a name assembled
 * from a variable is still subject to it.  A name with no '$' expands to
 * itself, which is why applying this to commands no shipped scene currently
 * parameterises costs nothing.  D-28.
 *
 * Lives in its own frame deliberately: a buffer declared inside the command
 * switch inflates execute_rip_command, which has a 656-byte budget and has
 * been pushed over it three times by exactly that.
 */
static void rip_request_asset_expanded(rip_state_t *s, const char *name,
                                       int name_len) {
    char raw[RIP_USER_VAR_VALUE_MAX * 2 + 2];
    char expanded[RIP_USER_VAR_VALUE_MAX * 2 + 2];
    int n;

    if (name_len <= 0)
        return;
    if (name_len > (int)sizeof(raw) - 1)
        name_len = (int)sizeof(raw) - 1;
    memcpy(raw, name, (size_t)name_len);
    raw[name_len] = '\0';

    n = rip_expand_variables(s, raw, name_len, expanded, (int)sizeof(expanded));
    if (n <= 0)
        return;
    if (rip_filename_is_safe(expanded, n))
        (void)rip_icon_request_file(&s->icon_state, expanded, n);
}

static bool rip_url_scheme_allowed(const char *u, int len);

/* Validate and store a GotoURL argument, after expanding $VARIABLE$.
 *
 * '|3G' is one of the twelve entries that reach the driver's interpolation
 * scanner (D-28), so the URL it receives is the EXPANDED one.  RIPlib checked
 * the raw text, which meant a URL assembled from a variable was judged on the
 * unexpanded string.
 *
 * ORDER IS THE WHOLE POINT HERE.  Expansion happens first and validation
 * second, never the reverse: a variable whose value carries a scheme --
 * "$X$:alert(1)" with X set to "javascript" -- must be judged on what it
 * becomes, not on what it looks like.  Checking first and expanding after
 * would let content walk a scheme straight past the allow-list.
 *
 * The rest is unchanged and stays deliberate: RIPlib launches nothing, the
 * allow-list is http/https only, and over-length is a rejection rather than a
 * truncation because silently shortening a URL can change which host it names.
 *
 * Its own frame, for the reason rip_request_asset_expanded() has one.
 */
static void rip_set_goto_url(rip_state_t *s, const char *url, int url_len) {
    char raw[RIP_USER_VAR_VALUE_MAX * 2 + 2];
    char expanded[RIP_USER_VAR_VALUE_MAX * 2 + 2];
    int n, i;

    if (url_len <= 0)
        return;                     /* the driver's "No URL string present" */
    if (url_len > (int)sizeof(raw) - 1)
        return;                     /* too long to be a URL we would store */
    memcpy(raw, url, (size_t)url_len);
    raw[url_len] = '\0';

    n = rip_expand_variables(s, raw, url_len, expanded, (int)sizeof(expanded));
    if (n <= 0 || n >= (int)sizeof(s->goto_url))
        return;

    /* "Invalid URL character found": a URL field carries no control bytes and
     * no whitespace. */
    for (i = 0; i < n; i++) {
        if ((unsigned char)expanded[i] < 0x21 ||
            (unsigned char)expanded[i] > 0x7E)
            return;
    }
    /* Scheme allow-list.  Everything except http/https is refused outright --
     * javascript:, data:, file:, vbscript: and friends are what turn "open a
     * link" into code execution, and no host policy should have to
     * re-litigate them. */
    if (!rip_url_scheme_allowed(expanded, n))
        return;

    memcpy(s->goto_url, expanded, (size_t)n);
    s->goto_url[n] = '\0';
    /* Opt-in only.  With no handler registered the URL is merely stored --
     * RIPlib itself launches nothing, ever. */
    if (s->url_handler)
        s->url_handler(s->goto_url, n);
}

static int unescape_text(const char *src, int len, char *dst, int dst_max) {
    int j = 0;
    if (dst_max <= 0) return 0;
    for (int i = 0; i < len && j < dst_max; i++) {
        if (src[i] == '\\' && i + 1 < len) {
            char next = src[i + 1];
            if (next == '!' || next == '|' || next == '\\' || next == '^') {
                dst[j++] = next;       /* literal: \| \\ \^ and the \! ext */
                i++; /* skip escaped char */
                continue;
            }
            if (next == 'n') {         /* \n → newline (spec §1.6 / §7.1) */
                dst[j++] = '\n';
                i++;
                continue;
            }
        }
        dst[j++] = src[i];
    }
    return j;
}

/* ══════════════════════════════════════════════════════════════════
 * TEXT VARIABLE EXPANSION — $VARIABLE$ substitution
 *
 * DLL ground truth (rip_textvars.c): text output layer scans for $VAR$
 * delimiters and substitutes registered variable values before rendering.
 * Recognized variables:
 *   $DATE$        — current date  (MM/DD/YY)
 *   $TIME$        — current time  (HH:MM)
 *   $USER$        — empty string  (no login name on embedded card)
 *   $PROT$        — resolution mode: "0"=EGA, "1"=VGA (DLL GFXSTYLE field)
 *   $APP0$-$APP9$ — application-defined variables (rip_state_t.app_vars)
 * Unknown variables are passed through unchanged (including $…$ delimiters).
 * ══════════════════════════════════════════════════════════════════ */

/* Expand $VARIABLE$ references in text buffer.
 * in/in_len: source (need not be NUL-terminated).
 * out: output buffer (NUL-terminated on return).
 * max_out: total capacity of out including NUL terminator.
 * Returns number of characters written (excluding NUL). */

/* ══════════════════════════════════════════════════════════════════
 * TEXT WINDOW PASSTHROUGH — render text within RIP text window bounds
 * ══════════════════════════════════════════════════════════════════ */

static void rip_tw_putchar(rip_state_t *s, uint8_t ch) {
    int16_t tw_x1_s = s->tw_x1;
    int16_t tw_y1_s = scale_y1(s->tw_y1);
    const int16_t char_w = 8;
    const int16_t char_h = 16;

    if (ch == '\r') {
        s->tw_cur_x = s->tw_x0;
        return;
    }
    if (ch == '\n') {
        s->tw_cur_y += char_h;
        /* Scroll if past bottom of text window */
        if (s->tw_cur_y + char_h > tw_y1_s) {
            int16_t tw_y0_s = scale_y(s->tw_y0);
            int16_t tw_w = (int16_t)(tw_x1_s - s->tw_x0 + 1);
            int16_t tw_h = (int16_t)(tw_y1_s - tw_y0_s + 1);
            draw_copy_rect(s->tw_x0, tw_y0_s + char_h,
                           s->tw_x0, tw_y0_s,
                           tw_w,
                           (int16_t)(tw_h - char_h));
            /* Clear the last line */
            draw_set_color(0);
            draw_rect(s->tw_x0, (int16_t)(tw_y1_s - char_h + 1),
                      tw_w, char_h, true);
            draw_set_color(s->palette[s->draw_color & 0x0F]);
            s->tw_cur_y = tw_y1_s - char_h;
        }
        return;
    }
    if (ch == '\b') {
        if (s->tw_cur_x >= s->tw_x0 + char_w)
            s->tw_cur_x -= char_w;
        return;
    }
    if (ch == '\t') {
        int spaces = 8 - ((s->tw_cur_x - s->tw_x0) / char_w % 8);
        for (int i = 0; i < spaces; i++)
            rip_tw_putchar(s, ' ');
        return;
    }
    if (ch < 0x20) return; /* ignore other control chars */

    /* Word wrap: if next char would go past right edge, newline first */
    if (s->tw_wrap && s->tw_cur_x + char_w > tw_x1_s) {
        s->tw_cur_x = s->tw_x0;
        rip_tw_putchar(s, '\n');
    }

    /* Draw the character.  L17: previously passed NULL font, which made
     * draw_text early-return — every byte routed to the text window
     * passthrough was invisible.  Use cp437_8x16 like every other
     * bitmap-font draw site. */
    uint8_t tc = s->palette[s->draw_color & 0x0F];
    draw_text(s->tw_cur_x, s->tw_cur_y, (const char *)&ch, 1,
              cp437_8x16, 16u, tc, 0xFF);
    s->tw_cur_x += char_w;

    /* Wrap if past right edge (non-wrap mode: just clip) */
    if (s->tw_cur_x > tw_x1_s) {
        if (s->tw_wrap) {
            s->tw_cur_x = s->tw_x0;
            rip_tw_putchar(s, '\n');
        }
    }
}

/* ══════════════════════════════════════════════════════════════════
 * MOUSE HIT-TEST — dispatches click to matching region
 * ══════════════════════════════════════════════════════════════════ */

void rip_mouse_event_state(rip_state_t *s, int16_t x, int16_t y, bool clicked) {
    if (!s || !clicked) return;

    for (int i = (int)s->num_mouse_regions - 1; i >= 0; i--) {
        rip_mouse_region_t *r = &s->mouse_regions[i];

        /* DLL: field must have MF_ACTIVE(0x04) set to be hit-testable.
         * rip_mouse.c field record +0x20, pFieldBuf+0x20 |= MF_ACTIVE */
        if (!(r->flags & RIP_MF_ACTIVE)) continue;
        /* L10: TOGGLE regions remain hit-testable regardless of
         * r->active because that field tracks the toggled "checked"
         * state, not the live/dead state.  For non-TOGGLE regions,
         * r->active=false means the region was retired (e.g., by a
         * one-shot click) and should not respond. */
        if (!(r->flags & RIP_MF_TOGGLE) && !r->active) continue;

        if (x >= r->x0 && x <= r->x1 && y >= r->y0 && y <= r->y1) {

            /* MF_RADIO(0x20): deselect all other regions in same group
             * before activating this one.  DLL: ripCmd_MouseRegion flags&2 → MF_RADIO */
            if (r->flags & RIP_MF_RADIO) {
                for (int j = 0; j < s->num_mouse_regions; j++) {
                    if (j != i)
                        s->mouse_regions[j].active = false;
                }
            }

            /* MF_TOGGLE(0x40): flip active state on each click rather than
             * triggering the host command immediately.
             * DLL: ripCmd_MouseRegion flags&4 → MF_TOGGLE */
            if (r->flags & RIP_MF_TOGGLE) {
                r->active = !r->active;
                /* Visual feedback: XOR-invert the region to show toggle state */
                draw_set_write_mode(DRAW_MODE_XOR);
                draw_set_color(0xFF);
                draw_rect(r->x0, r->y0,
                          (int16_t)(r->x1 - r->x0 + 1),
                          (int16_t)(r->y1 - r->y0 + 1), true);
                draw_set_write_mode(s->write_mode);
                draw_set_color(s->palette[s->draw_color & 0x0F]);
                return;
            }

            /* MF_SEND_CHAR(0x08): send the hotkey character rather than
             * the host command string.
             * DLL: ripCmd_MouseRegion flags&1 → MF_SEND_CHAR; hotkey stored at +0x2B */
            if ((r->flags & RIP_MF_SEND_CHAR) && r->hotkey != 0) {
                char hk = (char)r->hotkey;
                riplib_host_tx(&hk, 1);
                riplib_host_tx("\r", 1);
                return;
            }

            /* Default: send the host command string */
            if (r->text_len > 0) {
                riplib_host_tx(r->text, r->text_len);
                riplib_host_tx("\r", 1);
            }

            /* Deactivate region after click (one-shot button behavior) */
            r->active = false;
            return; /* first match wins */
        }
    }
}

void rip_mouse_event_ext(int16_t x, int16_t y, bool clicked) {
    rip_mouse_event_state(g_rip_state, x, y, clicked);
}

/* ══════════════════════════════════════════════════════════════════
 * FILE UPLOAD — receive BMP/ICN data from host for PSRAM caching
 * ══════════════════════════════════════════════════════════════════ */

void rip_file_upload_begin_state(rip_state_t *s, uint8_t name_len) {
    if (!s) return;
    if (!s->upload_buf)
        s->upload_buf = (uint8_t *)psram_arena_alloc(&s->psram_arena,
                                                     FILE_UPLOAD_MAX);
    rip_upload_reset(s);
    s->upload_name_remaining = name_len;
    s->upload_name_overflow = (name_len >= sizeof(s->upload_name));
    s->upload_reading_name = (name_len > 0);
    /* Name bytes follow as FILE_UPLOAD_DATA writes */
}

void rip_file_upload_byte_state(rip_state_t *s, uint8_t b) {
    if (!s) return;
    if (s->upload_reading_name) {
        if (s->upload_name_len < (int)sizeof(s->upload_name) - 1) {
            s->upload_name[s->upload_name_len++] = (char)b;
            s->upload_name[s->upload_name_len] = '\0';
        } else {
            s->upload_name_overflow = true;
        }
        if (s->upload_name_remaining > 0)
            s->upload_name_remaining--;
        if (s->upload_name_remaining == 0) {
            s->upload_reading_name = false; /* name complete, data follows */
        }
        return;
    }
    if (s->upload_buf && s->upload_pos < FILE_UPLOAD_MAX)
        s->upload_buf[s->upload_pos++] = b;
}

void rip_file_upload_end_state(rip_state_t *s) {
    if (!s) return;
    if (!s->upload_buf || s->upload_pos < 4 ||
        s->upload_reading_name || s->upload_name_remaining != 0) {
        rip_upload_reset(s);
        return;
    }

    /* RAF archive support — requires rip_raf.h (not in standalone RIPlib) */
#ifdef RIPLIB_HAS_RAF
    /* Try RAF archive first ("SQSH" magic at byte 0x10 in the 0x64-byte header).
     * DLL ground truth: ripResFileReadIndex (RVA 0x0648B9) validates the magic
     * at buf[0x10] and decodes each 0x13-byte index entry via XOR (sub_0756C4).
     * When the host transfers a .RAF archive, we unpack every member into the
     * PSRAM icon cache so subsequent LOAD_ICON commands find them immediately. */
    if (s->upload_pos >= 0x64 + 4 &&
        (uint32_t)(s->upload_buf[0x10]       |
                  ((uint32_t)s->upload_buf[0x11] << 8) |
                  ((uint32_t)s->upload_buf[0x12] << 16) |
                  ((uint32_t)s->upload_buf[0x13] << 24)) == RAF_MAGIC_SQSH) {

        raf_archive_t raf;
        if (raf_open(&raf, s->upload_buf, (uint32_t)s->upload_pos,
                     &s->psram_arena)) {

            /* Allocate a decompression scratch buffer from the arena.
             * 64 KB covers the largest icon likely to appear in a RAF archive.
             * DLL: rafDecompressEntry uses a 0x400-byte ring + 0x200 input chunk;
             * we decompress into a flat buffer and hand off to the existing BMP/ICN
             * parsers. (RVA 0x064D68 rafDecompressEntry, RVA 0x06522A rafInflateBlock) */
            const uint32_t RAF_SCRATCH_MAX = 64u * 1024u;
            uint8_t *scratch = (uint8_t *)malloc(RAF_SCRATCH_MAX);

            if (scratch) {
                for (uint16_t mi = 0; mi < raf.count; mi++) {
                    const raf_index_entry_t *me = &raf.entries[mi];

                    uint32_t nbytes = raf_decompress(&raf, me,
                                                     scratch, RAF_SCRATCH_MAX);
                    if (nbytes < 4) continue;

                    /* Route to BMP or ICN parser by magic/heuristic.
                     * DLL: ripLoadResource copies raw data and the caller
                     * (e.g. ripImageLoad) dispatches by file extension / magic. */
                    if (scratch[0] == 'B' && scratch[1] == 'M') {
                        rip_icon_cache_bmp_replace(&s->icon_state,
                                                   me->name, (int)strlen(me->name),
                                                   scratch, (int)nbytes);
                    } else if (nbytes >= 6) {
                        rip_cache_icn_if_valid(s, me->name, (int)strlen(me->name),
                                               scratch, (int)nbytes);
                    }
                }
                free(scratch);
            }
            /* raf.entries lives in the arena — no explicit free needed. */
        }
        rip_upload_reset(s);
        return;
    }
#endif /* RIPLIB_HAS_RAF */

    if (s->upload_name_overflow ||
        !rip_filename_is_safe(s->upload_name, s->upload_name_len)) {
        rip_upload_reset(s);
        return;
    }

    /* Try BMP first (check 'BM' magic) */
    if (s->upload_buf[0] == 'B' && s->upload_buf[1] == 'M') {
        rip_icon_cache_bmp_replace(&s->icon_state,
                                   s->upload_name, s->upload_name_len,
                                   s->upload_buf, s->upload_pos);
    } else {
        rip_cache_icn_if_valid(s, s->upload_name, s->upload_name_len,
                               s->upload_buf, s->upload_pos);
    }

    rip_upload_reset(s);
}

void rip_file_upload_begin(uint8_t name_len) {
    rip_file_upload_begin_state(g_rip_state, name_len);
}

void rip_file_upload_byte(uint8_t b) {
    rip_file_upload_byte_state(g_rip_state, b);
}

void rip_file_upload_end(void) {
    rip_file_upload_end_state(g_rip_state);
}

/* ══════════════════════════════════════════════════════════════════
 * PRE-PROCESSOR EXPRESSION EVALUATOR
 *
 * Used by the <<IF expr>> directive.  Expands $VARIABLE$ references in
 * the expression, then checks for comparison operators.
 *
 * DLL ground truth: ripTextVarEngine @ 0x026218 expands variables before
 * the pre-processor evaluates branch conditions — expand first, compare second.
 *
 * Operator precedence (first match wins):
 *   !=   — string inequality
 *   =    — string equality
 *   >    — integer greater-than
 *   <    — integer less-than
 *   (none) — boolean: non-empty and not literal "0"
 * ══════════════════════════════════════════════════════════════════ */


/* Preprocessor suppression-state machine lives in src/rip_preproc.c
 * (extracted as the first step of audit candidate C-002).  This file
 * keeps only the byte-level <<…>> recognition FSM (wired into the
 * parser entry point further down) and the directive-dispatch glue
 * that converts a recognised directive into a rip_preproc_*() call. */

static void rip_dispatch_byte(rip_state_t *s, void *ctx, uint8_t ch);

/* Re-emit a << ... >> run that turned out not to be a directive.
 *
 * Everything the scanner swallowed has to come back, delimiters included,
 * because the run was never a directive in the first place.  Shipped content
 * relies on this: '|1M' host-command text carries lowercase
 * "<<if $RETURN$!=\"\">>$<<RETURN>>$<<else>>$NULL$<<endif>>" -- 19 of them
 * across the corpus -- which the HOST evaluates when the region is clicked.
 * Directives are UPPERCASE; these are literal text and must reach cmd_buf
 * intact.  See D-26. */
static void preproc_emit_verbatim(rip_state_t *s, void *ctx) {
    int i;

    rip_dispatch_byte(s, ctx, '<');
    rip_dispatch_byte(s, ctx, '<');
    for (i = 0; i < s->preproc_len; i++)
        rip_dispatch_byte(s, ctx, (uint8_t)s->preproc_buf[i]);
    rip_dispatch_byte(s, ctx, '>');
    rip_dispatch_byte(s, ctx, '>');
}

static void preproc_finalize_directive(rip_state_t *s, void *ctx) {
    const char *dir;

    if (s->preproc_len < (int)sizeof(s->preproc_buf))
        s->preproc_buf[s->preproc_len] = '\0';
    else
        s->preproc_buf[sizeof(s->preproc_buf) - 1] = '\0';

    dir = s->preproc_buf;
    if (strncmp(dir, "IF ", 3) == 0 || strcmp(dir, "IF") == 0) {
        const char *expr = (dir[2] == ' ') ? dir + 3 : "";
        /* Pre-evaluate the IF expression here (the variable
         * expansion engine lives in this file); the preprocessor
         * module only needs the resulting bool.  A parent IF that
         * is already suppressing short-circuits the evaluation. */
        bool eval = s->preproc_suppress ? false : rip_eval_if_expr(s, expr);
        rip_preproc_push_if(s, eval);
    } else if (strcmp(dir, "ELSE") == 0) {
        rip_preproc_handle_else(s);
    } else if (strcmp(dir, "ENDIF") == 0) {
        rip_preproc_handle_endif(s);
    } else if (strncmp(dir, "DEBUG ", 6) == 0 || strcmp(dir, "DEBUG") == 0) {
        /* §A2G (v3.2): <<DEBUG msg>> — push "0x3E DEBUG: <msg>\r" to TX so the
         * host can log it.  Suppressed by parent IF/ELSE branches so that
         * <<IF false>>...<<DEBUG ...>>...<<ENDIF>> stays quiet.
         *
         * OFF BY DEFAULT since v2.0.0 (X7).  Two problems make unconditional
         * emission unsafe, and the README used to call it "safe to leave in
         * production", which was wrong:
         *
         *   1. It can shadow a macro.  In the 3.x layer <<NAME>> expands to
         *      the text variable NAME anywhere in a command's argument text,
         *      so <<DEBUG msg>> is syntactically indistinguishable from a
         *      reference to a variable named DEBUG.
         *   2. Unsolicited terminal-to-host traffic has no precedent.  Every
         *      other thing a 2.x/3.x terminal sends is a RESPONSE.  A BBS
         *      sitting at a prompt reads inbound bytes as keystrokes, so
         *      ">DEBUG: entering menu render" + CR is a menu selection.
         *
         * Enable deliberately, for a host written to expect it:
         *     cmake -DCMAKE_C_FLAGS=-DRIPLIB_ENABLE_DEBUG_DIRECTIVE=1
         * When disabled the directive is still PARSED and consumed, so a
         * stream containing it renders identically — it just stays silent. */
#if defined(RIPLIB_ENABLE_DEBUG_DIRECTIVE) && RIPLIB_ENABLE_DEBUG_DIRECTIVE
        if (!s->preproc_suppress) {
            const char *msg = (dir[5] == ' ') ? dir + 6 : "";
            int msg_len = (int)strlen(msg);
            char buf[160];
            int n = snprintf(buf, sizeof(buf), "%cDEBUG: %s\r",
                             (char)0x3E, msg);
            (void)msg_len;
            if (n > 0 && n < (int)sizeof(buf))
                riplib_host_tx(buf, n);
        }
#endif
    } else {
        /* Not a directive.  Put it back verbatim rather than discarding it:
         * the scanner cannot know a << ... >> run is a directive until it has
         * already eaten the whole thing, and anything it does not recognise
         * is ordinary text that some consumer was waiting for.  Discarding it
         * -- which is what this did -- silently deleted every lowercase
         * <<if>> in '|1M' host-command text and any <<foo>> a scene put in
         * display text.  D-26. */
        preproc_emit_verbatim(s, ctx);
    }

    s->preproc_len = 0;
}

/* ══════════════════════════════════════════════════════════════════
 * COMMAND EXECUTION
 * ══════════════════════════════════════════════════════════════════ */

static void apply_draw_state(rip_state_t *s) {
    draw_set_color(s->palette[s->draw_color & 0x0F]);
    draw_set_write_mode(s->write_mode);
}

/* Unescape, variable-expand, justify, and render a text parameter at the
 * session's current draw position, advancing the cursor by the rendered
 * width.  Shared by RIP_TEXT ('T') and RIP_TEXT_XY ('@') so that both
 * commands honor the same backslash escapes, variable substitution,
 * justification flags, and BGI vs bitmap font selection. */
static void rip_render_text(rip_state_t *s, const char *raw, int raw_len) {
    char tbuf[256];
    char vbuf[256];
    int tlen;

    if (raw_len <= 0) return;
    tlen = unescape_text(raw, raw_len, tbuf, (int)sizeof(tbuf));
    tlen = rip_expand_variables(s, tbuf, tlen, vbuf, sizeof(vbuf));
    if (tlen <= 0) return;

    uint8_t tc = s->palette[s->draw_color & 0x0F];
    uint8_t fid = s->font_id;
    uint8_t fscale = s->font_size ? s->font_size : 1;
    int16_t tx = s->draw_x, ty = s->draw_y;

    bool stroke = (fid > 0 && fid < BGI_FONT_COUNT && bgi_fonts_loaded &&
                   bgi_fonts[fid].strokes);
    int16_t tw = stroke
                 ? bgi_font_string_width(&bgi_fonts[fid], vbuf, tlen, fscale)
                 : (int16_t)(tlen * 8);
    int16_t th = stroke ? (int16_t)(bgi_fonts[fid].top * fscale) : 16;

    /* Apply horizontal/vertical justification (DLL: 0=left/bottom,
     * 1=center, 2=right/top, 3=baseline). */
    if (s->font_hjust == 1)      tx = (int16_t)(tx - tw / 2);
    else if (s->font_hjust == 2) tx = (int16_t)(tx - tw);
    if (s->font_vjust == 0)      ty = (int16_t)(ty - th);
    else if (s->font_vjust == 1) ty = (int16_t)(ty - th / 2);

    int16_t adv;
    if (stroke) {
        adv = bgi_font_draw_string_ex(&bgi_fonts[fid], tx, ty, vbuf, tlen,
                                       fscale, tc, s->font_dir, s->font_attrib);
    } else {
        draw_text(tx, ty, vbuf, tlen, cp437_8x16, 16, tc, 0xFF);
        adv = tw;
    }
    if (s->font_dir == 0) s->draw_x = (int16_t)(s->draw_x + adv);
    else                  s->draw_y = (int16_t)(s->draw_y + adv);
}

static void rip_render_text_box(rip_state_t *s,
                                int16_t x0, int16_t y0,
                                int16_t x1, int16_t y1,
                                uint8_t flags,
                                const char *raw, int raw_len) {
    draw_clip_state_t saved_clip;
    int16_t cx0;
    int16_t cy0;
    int16_t cx1;
    int16_t cy1;
    uint8_t old_hjust;
    uint8_t old_vjust;

    if (!s || !raw || raw_len <= 0)
        return;
    if (x0 > x1) { int16_t t = x0; x0 = x1; x1 = t; }
    if (y0 > y1) { int16_t t = y0; y0 = y1; y1 = t; }

    draw_save_clip(&saved_clip);
    cx0 = x0 > saved_clip.x0 ? x0 : saved_clip.x0;
    cy0 = y0 > saved_clip.y0 ? y0 : saved_clip.y0;
    cx1 = x1 < saved_clip.x1 ? x1 : saved_clip.x1;
    cy1 = y1 < saved_clip.y1 ? y1 : saved_clip.y1;
    if (cx0 > cx1 || cy0 > cy1) {
        draw_restore_clip(&saved_clip);
        return;
    }

    old_hjust = s->font_hjust;
    old_vjust = s->font_vjust;

    s->font_hjust = 0;
    if (flags & 0x02u) s->font_hjust = 1;
    if (flags & 0x04u) s->font_hjust = 2;

    s->font_vjust = 2; /* top, matching a bounded text box default */
    if (flags & 0x10u) s->font_vjust = 1;
    if (flags & 0x20u) s->font_vjust = 2;
    if (flags & 0x40u) s->font_vjust = 3;

    if (s->font_hjust == 1)
        s->draw_x = (int16_t)(x0 + (x1 - x0 + 1) / 2);
    else if (s->font_hjust == 2)
        s->draw_x = (int16_t)(x1 + 1);
    else
        s->draw_x = x0;

    if (s->font_vjust == 0)
        s->draw_y = (int16_t)(y1 + 1);
    else if (s->font_vjust == 1)
        s->draw_y = (int16_t)(y0 + (y1 - y0 + 1) / 2);
    else
        s->draw_y = y0;

    draw_set_clip(cx0, cy0, cx1, cy1);
    rip_render_text(s, raw, raw_len);
    draw_restore_clip(&saved_clip);

    s->font_hjust = old_hjust;
    s->font_vjust = old_vjust;
}

static void apply_session_draw_state(rip_state_t *s) {
    int8_t card_pat = bgi_fill_to_card(s->fill_pattern);

    draw_set_clip(s->vp_x0, s->vp_y0, s->vp_x1, s->vp_y1);
    draw_set_pos(s->draw_x, s->draw_y);
    draw_set_line_style(s->line_pattern, s->line_thick);
    /* The 2nd arg becomes g_fill_color in drawing.c, used by fill_span
     * for the OFF bits of patterned fills.  Per BGI/RIP semantics that
     * is back_color (set by 'k'), with fill_color (set by 'S') used
     * for the ON bits via the foreground g_color.  See M14. */
    draw_set_fill_style((card_pat >= 0) ? (uint8_t)card_pat : 0,
                        s->palette[s->back_color & 0x0F]);
    apply_draw_state(s);
}

static bool rip_begin_filled_border(rip_state_t *s, uint8_t *saved_mode) {
    if (!s || !saved_mode || !s->filled_borders_enabled)
        return false;
    *saved_mode = s->write_mode;
    draw_set_write_mode(DRAW_MODE_COPY);
    draw_set_color(s->palette[s->draw_color & 0x0F]);
    return true;
}

static void rip_end_filled_border(rip_state_t *s, uint8_t saved_mode) {
    if (!s)
        return;
    draw_set_write_mode(saved_mode);
}

void rip_reset_windows_state(rip_state_t *s, comp_context_t *c) {
    if (!s)
        return;

    /* Windows + viewport -> full defaults */
    s->tw_x0 = 0; s->tw_y0 = 0;
    s->tw_x1 = 639; s->tw_y1 = 349;
    s->tw_wrap = 0; s->tw_font_size = 0;
    s->tw_active = false;
    set_session_viewport(s, 0, 0, 639, 399);

    /* Drawing state -> defaults */
    s->draw_color = 15;
    s->draw_x = 0; s->draw_y = 0;
    s->write_mode = DRAW_MODE_COPY;
    s->line_style = 0; s->line_pattern = 0xFFFF; s->line_thick = 1;
    s->fill_pattern = 1; s->fill_color = 15;
    s->back_color = 0;
    s->font_id = 0; s->font_ext_id = 0;
    s->font_dir = 0; s->font_size = 1;
    s->font_hjust = 0; s->font_vjust = 0;
    s->font_attrib = 0;
    s->resolution_mode = 0;
    s->coordinate_size = 2;
    s->coordinate_res = 0;
    s->color_mode = 0;
    s->color_bits = 0;
    s->filled_borders_enabled = true;

    for (int i = 0; i < 16; i++) {
        s->palette[i] = palette_slot(i);
        palette_write_rgb565(palette_slot(i), ega_default_rgb565[i]);
    }

    s->num_mouse_regions = 0;
    memset(&s->button_style, 0, sizeof(s->button_style));
    s->clipboard.valid = false;
    s->clipboard.width = 0;
    s->clipboard.height = 0;
    memset(s->icon_slot_valid, 0, sizeof(s->icon_slot_valid));
    s->icon_style_active = false;
    s->icon_style_style = 0;
    s->icon_style_align = 0;
    s->icon_style_scale = 0;
    s->text_block.active = false;

    s->rip_has_drawn = false;
    s->cursor_repositioned = false;
    /* §A2G (v3.2): clear the state stack so subsequent | ~ pops cannot
     * surface state from a prior scene. */
    s->state_stack_depth = 0;
    draw_set_write_mode(DRAW_MODE_COPY);
    draw_set_line_style(0xFFFF, 1);
    draw_set_fill_style(0, s->palette[s->back_color]);
    draw_set_color(s->palette[s->draw_color & 0x0F]);
    draw_fill_screen(s->palette[s->back_color]);
    if (c)
        comp_set_cursor(c, 0, 0);
}

/* Scheme allow-list for '|3G' RIP_GotoURL.
 *
 * Only http:// and https:// are permitted.  This is a categorical refusal
 * rather than a policy knob: javascript:, data:, file:, vbscript: and the
 * like are the payloads that convert "open a link" into code execution or
 * local-file disclosure, and an embedder should not have to know that list
 * to be safe.  A host that wants a broader set can read s->goto_url itself.
 *
 * Case-insensitive, since schemes are. */
static bool rip_url_scheme_allowed(const char *u, int len) {
    static const char *const allowed[] = { "http://", "https://" };
    for (size_t k = 0; k < sizeof(allowed) / sizeof(allowed[0]); k++) {
        int n = (int)strlen(allowed[k]);
        if (len <= n)
            continue;                     /* scheme alone is not a URL */
        int match = 1;
        for (int i = 0; i < n; i++) {
            char c = u[i];
            if (c >= 'A' && c <= 'Z')
                c = (char)(c - 'A' + 'a');
            if (c != allowed[k][i]) { match = 0; break; }
        }
        if (match)
            return true;
    }
    return false;
}

void rip_set_url_handler(rip_state_t *s, rip_url_handler_t handler) {
    if (s)
        s->url_handler = handler;
}

uint32_t rip_take_delay(rip_state_t *s) {
    uint32_t d;

    if (!s)
        return 0;
    d = s->delay_ticks;
    s->delay_ticks = 0;
    return d;
}

/* Poly-bezier family — '|t' (line), '|x' (filled), '|z' (outline).
 *
 * D-2, fixed 2026-08-12.  The driver accepts THREE distinct signatures for
 * each of these letters, selected by ARGUMENT LENGTH, and their handlers sit
 * adjacent in .text with structurally identical bodies:
 *
 *      4 chars   count:2  steps:2                    header  (no geometry)
 *      5 chars   count:1  x:XY y:XY                  move-to (start point)
 *     13 chars   count:1  x:XY y:XY x:XY y:XY x:XY y:XY
 *                                                    curve-to: two control
 *                                                    points plus an endpoint,
 *                                                    continuing from the
 *                                                    current point
 *
 * That is an ordinary poly-bezier stream: a header, a move, then a run of
 * curve-to segments each contributing three points to a cubic whose first
 * point is wherever the pen already is.
 *
 * RIPlib previously bound ONE layout per letter, so every other accepted form
 * shifted each subsequent field and rendered silently wrong — a wrong length
 * does not error, it just draws the wrong picture.  Dispatching on length
 * removes that whole class of failure.
 *
 * RIPlib's own variable-length form (nsegs:2 nsteps:2 then four XY pairs per
 * segment) is what its existing content and fixtures use, so it is kept and
 * handled last.
 *
 * mode: 0 = line ('|t'), 1 = filled ('|x'), 2 = outline ('|z').
 */
/* The step count the stream asked for, or 0 to let the renderer estimate.
 *
 * '|t', '|x' and '|z' carry `nsteps` in their 4-character header form.
 * RIPlib recorded it and then ignored it: filled curves always flattened to
 * 12 segments and outlines always used draw_bezier()'s adaptive estimate,
 * so a stream asking for coarse geometry got smooth curves regardless.
 * Clamped to the range the drawing layer accepts. */
static int rip_bez_steps(const rip_state_t *s) {
    int n = (int)s->bez_steps;
    if (n <= 0)  return 0;          /* unset -- keep the adaptive estimate */
    if (n < 2)   return 2;
    if (n > 64)  return 64;
    return n;
}

static void rip_poly_bezier_family(rip_state_t *s, const char *p, int len,
                                   int mode) {
    if (len == 4) {                       /* header: count, steps */
        s->bez_steps = (uint16_t)mega2(p + 2);
        return;
    }
    if (len == 5) {                       /* move-to */
        s->bez_x = mega2(p + 1);
        s->bez_y = scale_y(mega2(p + 3));
        s->bez_valid = true;
        return;
    }
    if (len == 13) {                      /* curve-to from the current point */
        int16_t c1x = mega2(p + 1),  c1y = scale_y(mega2(p + 3));
        int16_t c2x = mega2(p + 5),  c2y = scale_y(mega2(p + 7));
        int16_t ex  = mega2(p + 9),  ey  = scale_y(mega2(p + 11));
        int16_t sx = s->bez_valid ? s->bez_x : c1x;
        int16_t sy = s->bez_valid ? s->bez_y : c1y;

        if (mode == 1) {
            /* Filled: flatten the segment and hand the closed outline to the
             * scanline filler, matching how '|x' renders its long form. */
            int16_t pts[2 * 65];
            int steps = rip_bez_steps(s);
            int n = 0;
            if (steps == 0) steps = 12;      /* unset: the historical default */
            for (int k = 0; k <= steps && n < 65; k++, n++) {
                float t = (float)k / (float)steps, mt = 1.0f - t;
                float a = mt*mt*mt, b = 3.0f*mt*mt*t, c = 3.0f*mt*t*t, d = t*t*t;
                pts[n*2]     = (int16_t)(a*sx + b*c1x + c*c2x + d*ex);
                pts[n*2 + 1] = (int16_t)(a*sy + b*c1y + c*c2y + d*ey);
            }
            if (n >= 3)
                draw_polygon(pts, n, s->fill_pattern != 0);
        } else {
            {
                int steps = rip_bez_steps(s);
                if (steps)
                    draw_bezier_steps(sx, sy, c1x, c1y, c2x, c2y, ex, ey, steps);
                else
                    draw_bezier(sx, sy, c1x, c1y, c2x, c2y, ex, ey);
            }
        }
        s->bez_x = ex;
        s->bez_y = ey;
        s->bez_valid = true;
        return;
    }

    /* RIPlib's multi-segment form: nsegs:2 nsteps:2 then 4 XY pairs each. */
    if (len >= 4) {
        int nsegs = mega2(p), offset = 4;
        for (int seg = 0; seg < nsegs && offset + 16 <= len; seg++) {
            int16_t bx0 = mega2(p + offset),      by0 = scale_y(mega2(p + offset + 2));
            int16_t bx1 = mega2(p + offset + 4),  by1 = scale_y(mega2(p + offset + 6));
            int16_t bx2 = mega2(p + offset + 8),  by2 = scale_y(mega2(p + offset + 10));
            int16_t bx3 = mega2(p + offset + 12), by3 = scale_y(mega2(p + offset + 14));
            if (mode == 1) {
                int16_t pts[2 * 65];
                int steps = rip_bez_steps(s);
                int n = 0;
                if (steps == 0) steps = 12;
                for (int k = 0; k <= steps && n < 65; k++, n++) {
                    float t = (float)k / (float)steps, mt = 1.0f - t;
                    float a = mt*mt*mt, b = 3.0f*mt*mt*t, c = 3.0f*mt*t*t, d = t*t*t;
                    pts[n*2]     = (int16_t)(a*bx0 + b*bx1 + c*bx2 + d*bx3);
                    pts[n*2 + 1] = (int16_t)(a*by0 + b*by1 + c*by2 + d*by3);
                }
                if (n >= 3)
                    draw_polygon(pts, n, s->fill_pattern != 0);
            } else {
                {
                    int steps = rip_bez_steps(s);
                    if (steps)
                        draw_bezier_steps(bx0, by0, bx1, by1, bx2, by2, bx3, by3, steps);
                    else
                        draw_bezier(bx0, by0, bx1, by1, bx2, by2, bx3, by3);
                }
            }
            s->bez_x = bx3; s->bez_y = by3; s->bez_valid = true;
            offset += 16;
        }
    }
}

/* Generated by scripts/dll-argtypes.py -- do not edit by hand.
 *
 * Commands containing at least one argument whose width is negotiated
 * rather than literal: 0xFF takes its width from '|n', 0xFE from '|M'.
 * Everything else has fixed widths and never needs rewriting, so it is
 * deliberately absent. */
#define RIP_ARGTYPE_MAX 16
typedef struct {
    uint8_t letter;   /* command character            */
    uint8_t level;    /* 0..3                         */
    uint8_t n;        /* argument count               */
    uint8_t t[RIP_ARGTYPE_MAX];
} rip_argtypes_t;

static const rip_argtypes_t rip_argtypes[] = {
    { '"', 0,  5, {0xFF,0xFF,0xFF,0xFF,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { '&', 0,  5, {0xFF,0xFF,0x02,0x02,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { '+', 0,  7, {0xFF,0xFF,0xFF,0xFF,0x02,0x02,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { ',', 0, 10, {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00} },
    { '-', 0,  5, {0xFF,0xFF,0xFF,0xFF,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { '.', 0,  6, {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { ':', 0, 11, {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x01,0x00,0x00,0x00,0x00,0x00} },
    { ';', 0,  7, {0xFF,0xFF,0x02,0xFF,0xFF,0x02,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { '@', 0,  2, {0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'A', 0,  5, {0xFF,0xFF,0x02,0x02,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'B', 0,  4, {0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'b', 0,  9, {0xFF,0xFF,0xFF,0xFF,0x02,0x02,0x01,0x04,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'C', 0,  3, {0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'c', 0,  1, {0xFE,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'f', 0,  2, {0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'G', 0,  3, {0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'g', 0,  2, {0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'I', 0,  5, {0xFF,0xFF,0x02,0x02,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'i', 0,  6, {0xFF,0xFF,0x02,0x02,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'j', 0,  2, {0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'K', 0,  4, {0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'k', 0,  1, {0xFE,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'L', 0,  4, {0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'm', 0,  2, {0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'O', 0,  6, {0xFF,0xFF,0x02,0x02,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'o', 0,  4, {0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'R', 0,  4, {0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'S', 0,  2, {0x02,0xFE,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 's', 0,  9, {0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0xFE,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'U', 0,  5, {0xFF,0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'u', 0,  5, {0xFF,0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'V', 0,  6, {0xFF,0xFF,0x02,0x02,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'v', 0,  4, {0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'X', 0,  2, {0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'Z', 0,  9, {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { '[', 0,  7, {0xFF,0xFF,0xFF,0xFF,0x02,0x02,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { ']', 0,  7, {0xFF,0xFF,0xFF,0xFF,0x02,0x02,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { '_', 0,  6, {0xFF,0xFF,0x02,0x02,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { '`', 0, 11, {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x01,0x00,0x00,0x00,0x00,0x00} },
    { '{', 1,  6, {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'B', 1, 16, {0xFF,0xFF,0x02,0x04,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x02,0x01,0x05} },
    { 'b', 1,  9, {0xFF,0xFF,0xFF,0xFF,0x01,0x01,0x02,0x02,0x04,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'C', 1,  5, {0xFF,0xFF,0xFF,0xFF,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'e', 1,  9, {0xFF,0xFF,0xFF,0xFF,0x01,0x01,0x04,0x02,0x08,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'G', 1,  7, {0xFF,0xFF,0xFF,0xFF,0x01,0x01,0xFF,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'g', 1,  8, {0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0x01,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'I', 1,  7, {0xFF,0xFF,0x01,0x01,0x01,0x01,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'i', 1,  6, {0xFF,0xFF,0xFF,0xFF,0x04,0x0C,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'k', 1,  5, {0xFF,0xFF,0xFF,0xFF,0x04,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'M', 1,  9, {0x02,0xFF,0xFF,0xFF,0xFF,0x01,0x01,0x02,0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'P', 1,  4, {0xFF,0xFF,0x02,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'T', 1,  6, {0xFF,0xFF,0xFF,0xFF,0x01,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'U', 1,  7, {0xFF,0xFF,0xFF,0xFF,0x02,0x01,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'C', 2, 12, {0x01,0xFF,0xFF,0xFF,0xFF,0x01,0xFF,0xFF,0xFF,0xFF,0x01,0x05,0x00,0x00,0x00,0x00} },
    { 'P', 2,  7, {0x01,0xFF,0xFF,0xFF,0xFF,0x04,0x04,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
    { 'W', 2,  7, {0x01,0xFF,0xFF,0xFF,0xFF,0x02,0x02,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00} },
};
#define RIP_ARGTYPES_COUNT 56

/* Rewrite a command payload so that every argument is exactly two MegaNum
 * digits, which is what RIPlib's handlers read.
 *
 * The driver resolves argument widths at decode time: a type byte of 0xFF
 * takes its width from '|n' SET_COORDINATE_SIZE and 0xFE from '|M'
 * SET_COLOR_MODE (resolver at RVA 0x039DE0).  RIPlib instead reads fixed
 * 2-digit fields at fixed offsets, in 262 places, so a stream that
 * negotiates any other width desynchronises from its first coordinate.
 *
 * Normalising here rather than making all 262 sites width-aware keeps the
 * change contained to one function, and -- more importantly -- keeps the
 * default path untouched: when the negotiated widths are already 2 this is
 * never called.
 *
 * LOSSY ONLY ABOVE 1295, the largest value two digits can hold.  That bound
 * is acceptable specifically for RIPlib: it renders into a fixed 640x400
 * device space and deliberately does not apply a world-to-device transform
 * (see D-1), so a coordinate above 1295 is off-screen whatever width
 * carried it.  A port that grows a world transform must revisit this.
 *
 * Returns the rewritten length, or -1 when the command is not in the table
 * -- variable-length commands, and every command whose widths are all
 * literal and therefore already correct.
 */
static int rip_normalise_widths(const rip_state_t *s, char *buf, int len,
                                char letter, uint8_t level)
{
    static const char DIG[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    const rip_argtypes_t *e = NULL;
    int coord_w, color_w, i, si = 0, oi = 0;

    for (i = 0; i < RIP_ARGTYPES_COUNT; i++) {
        if (rip_argtypes[i].letter == (uint8_t)letter &&
            rip_argtypes[i].level  == level) {
            e = &rip_argtypes[i];
            break;
        }
    }
    if (!e)
        return -1;

    coord_w = s->coordinate_size ? s->coordinate_size : 2;
    color_w = (s->color_mode != 0 && s->color_bits > 8) ? 4 : 2;
    if (coord_w < 2) coord_w = 2;
    if (coord_w > 5) coord_w = 5;

    /* MEASURE FIRST.  The rewrite below is in place, so a mid-way bail-out
     * would leave the payload half-converted and the handler would then
     * decode garbage.  Walk the type list once to confirm every field is
     * present at its negotiated width, and only then touch the buffer.
     * (This is not hypothetical: the first version of this function
     * rewrote as it went and corrupted any command whose payload was
     * shorter than the negotiated widths implied.) */
    for (i = 0; i < e->n; i++) {
        uint8_t ty = e->t[i];
        int w = (ty == 0xFF) ? coord_w : (ty == 0xFE) ? color_w : (int)ty;
        if (w < 1)
            return -1;
        si += w;
    }
    if (si > len)
        return -1;                             /* not a payload for these widths */
    si = 0;

    /* Rewritten IN PLACE.  Only the negotiated-width fields shrink (from
     * coord_w >= 2 down to 2); literal-width fields are copied byte for byte
     * at their own width, so the write cursor can never overtake the read
     * cursor and no scratch buffer is needed.
     *
     * Copying literals verbatim also matters for correctness, not just for
     * the buffer: re-emitting a mega1 or mega4 field as two digits would
     * corrupt it.  Only 0xFF and 0xFE are width-negotiated. */
    for (i = 0; i < e->n; i++) {
        uint8_t ty = e->t[i];
        int w, k;

        if (ty != 0xFF && ty != 0xFE) {
            w = (int)ty;                       /* literal width: copy as-is */
            if (w < 1 || si + w > len)
                return -1;
            for (k = 0; k < w; k++)
                buf[oi++] = buf[si++];
            continue;
        }

        w = (ty == 0xFF) ? coord_w : color_w;
        if (si + w > len)
            return -1;                         /* truncated: leave it alone */
        {
            int32_t v = 0;
            for (k = 0; k < w; k++)
                v = v * 36 + mega_digit(buf[si + k]);
            si += w;
            if (v > 1295) v = 1295;            /* two-digit ceiling */
            buf[oi++] = DIG[(v / 36) % 36];
            buf[oi++] = DIG[v % 36];
        }
    }

    /* Anything after the typed arguments is free text and moves verbatim. */
    while (si < len)
        buf[oi++] = buf[si++];
    return oi;
}

static void execute_rip_command(rip_state_t *s, void *ctx) {
    comp_context_t *c = (comp_context_t *)ctx;
    const char *p = s->cmd_buf;
    int len = s->cmd_len;

    /* Negotiated argument widths (D-11).  Handlers below read fixed 2-digit
     * fields at fixed offsets, so when '|n' or '|M' has selected any other
     * width the payload is rewritten to 2-digit form first and the handlers
     * never see the difference.  With the default widths this is skipped
     * entirely, so the common path is unchanged. */
    if (s->coordinate_size != 0 && s->coordinate_size != 2) {
        uint8_t lvl = s->is_level3 ? 3 : s->is_level2 ? 2 : s->is_level1 ? 1 : 0;
        int nlen = rip_normalise_widths(s, s->cmd_buf, len, s->cmd_char, lvl);
        if (nlen >= 0) {
            len = nlen;
            s->cmd_len = (uint16_t)nlen;
            s->coord_size_unsupported = false;   /* handled after all */
        }
    }

    /* Mark that RIP commands have drawn — prevents ANSI ESC[2J fallback
     * from clearing the framebuffer after the menu is rendered. */
    s->rip_has_drawn = true;

    /* Apply current drawing state */
    apply_draw_state(s);

    if (s->is_level3) {
        /* Level 3 commands (prefixed with '3').
         *
         * IMPLEMENTED 2026-08-12.  This block previously discarded every
         * Level 3 command on the grounds that the letters were "not publicly
         * documented".  They are now recovered from the driver's own dispatch
         * table (docs/spec/13-dll-command-table.md), with argument widths from
         * each entry's type bytes and field meanings from each handler's
         * validation diagnostics.  Discarding them silently meant a stream
         * using any of the five rendered nothing with no diagnosis. */
        switch (s->cmd_char) {

        case 'G': /* RIP_GotoURL — res:8 url:string
                   * Handler RVA 0x0251CB.  Diagnostics: "No URL string
                   * present", "Invalid URL character found", "URL too long".
                   *
                   * SECURITY: RIPlib does NOT launch anything.  The existing
                   * $GOTOURL$ path is deliberately neutered (see "Fix SV-2/S2"
                   * below in this file) precisely so a hostile stream cannot
                   * make the terminal open a URL or spawn a process.  That
                   * decision governs here too: the URL is validated and stored
                   * for the embedder to display or act on under its own policy,
                   * and nothing is launched.  A host that wants click-through
                   * reads s->goto_url and decides for itself. */
            /* Slot 126 records a single 8-digit field, and the URL string
             * follows it.  Literal type codes are digit COUNTS, never string
             * markers -- '|1e' (XY XY XY XY 1 1 4 2 8 = 24) and '|1i'
             * (XY XY XY XY 4 12 = 24) both sum to exactly the 24-character
             * payloads the corpus sends, which settles the encoding.  RIPlib
             * read the URL from offset 0 and so would have folded those eight
             * reserved digits into the front of the URL.  See D-16. */
            rip_set_goto_url(s, p + RIP_GOTOURL_RESERVED,
                             len - RIP_GOTOURL_RESERVED);
            break;

        case 'U': /* RIP_BeginEncodedStream — type:2 length:4
                   * Handler RVA 0x0252C0.  "Illegal type parameter 1".
                   * The encoded-stream payload format is not recovered, so
                   * RIPlib records the announcement rather than attempting to
                   * decode a stream it cannot interpret. */
            if (len >= 6) {
                s->encoded_stream_type = (uint16_t)mega2(p);
                s->encoded_stream_len  = (uint32_t)mega4(p + 2);
            }
            break;

        case 'R': /* Register text variable — id:4 flags:2 res:8 name:string
                   * Handler RVA 0x0252F2.  Diagnostics: "Can't register text
                   * variable - invalid variable name".  Maps onto RIPlib's
                   * existing user-variable store.
                   *
                   * CORRECTED: slot 127 records mega4, mega2 and an 8-DIGIT
                   * field, so the fixed prefix is 14 characters and the name
                   * starts there.  RIPlib read the name from offset 6, which
                   * lands inside the reserved field and would have prefixed
                   * every variable name with eight stray digits.  See D-16. */
            if (len > RIP_REGVAR_RESERVED) {
                const char *nm = p + RIP_REGVAR_RESERVED;
                int nlen = len - RIP_REGVAR_RESERVED;
                (void)rip_user_var_set(s, nm, nlen, "", 0);
            }
            break;

        case 'e': /* RIP_BAUD_EMULATION — rate:2
                   *
                   * CORRECTED 2026-08-12.  This was implemented as
                   * "style-slot protection" on the strength of diagnostics
                   * ("Cannot protect style slot #0") that turned out to have
                   * bled in from a neighbouring handler when the extraction
                   * used loose bounds.  The bbs-land reconstruction binds
                   * level 3 'e' to RIP_BAUD_EMULATION (evidence: 2.A0), and
                   * RIP_BaudEmulation is present in the driver's own function
                   * name table, so the letter is theirs.
                   *
                   * Sets a baud-rate emulation for local RIP playback — the
                   * driver throttles rendering to simulate a slower link.
                   * RIPlib renders as fast as its host drives it and applies
                   * no artificial delay, so the requested rate is recorded
                   * for an embedder that wants to honour it.
                   *
                   * Width: RESOLVED 2026-08-13.  The reference documents
                   * rate:4, from the 2.0 draft; slot 123 records a single
                   * mega2 and the handler (RVA 0x038BE1) loads exactly ONE
                   * argument -- mov edi,[eax] -- and stores it.  There is no
                   * second field to read.  RIPlib previously preferred a
                   * mega4 whenever four characters were available, which read
                   * two of the driver's fields as one; it is now mega2, per
                   * the arbiter.  A 2.0-era scene emitting four digits has
                   * its trailing two ignored, which is what the 3.0 driver
                   * does with them.  No corpus scene sends '|3e' at all. */
            if (len >= 2) s->baud_emulation = (uint32_t)mega2(p);
            break;

        case 'D': /* RIP_DELAY — ticks:4, in sixtieths of a second.
                   *
                   * RESOLVED 2026-08-12.  Two slots carry 'D' (122 and 125).
                   * Slot 122 (RVA 0x038BD2) is a five-instruction thunk that
                   * passes arg[0] straight to 0x100282CA, which busy-waits on
                   * WINMM!timeGetTime.  Its arithmetic fixes the unit beyond
                   * doubt: it splits the count into chunks of 3900, waits
                   * 0xFDE8 = 65000 ms per chunk (3900/60 = 65 s), then waits
                   * remainder * 1000 / 60 ms.  So the field is 1/60 s ticks.
                   *
                   * Slot 125 (RVA 0x024AF4) is a different command: it copies
                   * a TEXT parameter into a 256-byte buffer, looks it up, and
                   * on a result of 2 calls RIP_Suspend (0x10006C01, which
                   * names itself).  It never touches the decoded argument
                   * array, so it does not match its own argc=1/mega4 row —
                   * that row is the mis-associated one, and slot 122 is the
                   * reading '|3D' actually supports.  See §12.12.
                   *
                   * RIPlib does NOT busy-wait.  A rendering library that
                   * blocks the caller for up to 65 seconds a chunk is
                   * unusable on a cooperative or single-threaded host, which
                   * is most of RIPlib's targets.  The request is recorded and
                   * the host decides; rip_take_delay() hands it over. */
            /* Slot 122 records a single mega4.  The mega2 fallback that used
             * to follow accepted a truncated record the driver rejects --
             * the same leniency removed from '|3e'.  D-18. */
            if (len >= 4)
                s->delay_ticks = (uint32_t)mega4(p);
            break;

        /* RIPlib extensions.  '&' and '-' were previously bound at Level 0,
         * where the driver's dispatch table assigns the skewed-oval family
         * instead.  The two capabilities are kept here rather than dropped;
         * neither letter appears among the driver's Level 3 commands
         * (D, e, ESC, G, R, U), so nothing in the protocol is displaced. */
        case '&': /* icon display style -- x0:2 y0:2 x1:2 y1:2 style:2 align:2 scale:2 */
            if (len >= 14) {
                int16_t x0 = mega2(p),     y0 = scale_y(mega2(p + 2));
                int16_t x1 = mega2(p + 4), y1 = scale_y1(mega2(p + 6));
                if (x0 > x1) { int16_t tmp = x0; x0 = x1; x1 = tmp; }
                if (y0 > y1) { int16_t tmp = y0; y0 = y1; y1 = tmp; }
                s->icon_style_x0 = x0;
                s->icon_style_y0 = y0;
                s->icon_style_x1 = x1;
                s->icon_style_y1 = y1;
                s->icon_style_style = (uint8_t)(mega2(p + 8) & 0x03);
                s->icon_style_align = (uint8_t)(mega2(p + 10) & 0x03);
                s->icon_style_scale = (uint8_t)(mega2(p + 12) & 0xFF);
                s->icon_style_active = true;
            } else {
                s->icon_style_active = false;
            }
            break;

        case 'J': /* save current clipboard into an icon slot -- slot:2
                   * Displaced from Level 0 '|J', which the driver defines as
                   * RIP_SetBaseMath.  The slot mechanism is RIPlib's own (it
                   * backs '.' RIP_STAMP_ICON and the SLOTnn load alias), so
                   * it keeps a home here rather than being dropped. */
            if (len >= 2)
                (void)rip_save_clipboard_slot(s, (uint16_t)mega2(p));
            break;

        case '-': /* bounded text box -- x0:2 y0:2 x1:2 y1:2 flags:2 text */
            if (len >= 10) {
                int16_t bx0 = mega2(p),     by0 = scale_y(mega2(p + 2));
                int16_t bx1 = mega2(p + 4), by1 = scale_y1(mega2(p + 6));
                uint8_t bflags = (uint8_t)(mega2(p + 8) & 0xFF);
                rip_render_text_box(s, bx0, by0, bx1, by1, bflags,
                                    p + 10, len - 10);
            }
            break;

        default:
            /* Unknown Level 3 letter: consume without poisoning the stream. */
            break;
        }
        return;
    }

    if (s->is_level2) {
        /* Level 2 commands (prefixed with '2') — RIPscrip 2.0 / port extensions.
         * Pass both the raw buffer (for port commands that need 1-digit/4-digit
         * MegaNum fields) and the pre-decoded mega2 params (for legacy handlers). */
        int16_t params[16];
        int nparams = 0;
        for (int i = 0; i + 1 < len && nparams < 16; i += 2)
            params[nparams++] = mega2(p + i);
        ripscrip2_execute(&s->rip2_state, s, ctx, s->cmd_char,
                          p, len, params, nparams);
        return;
    }

    if (s->is_level1) {
        /* Level 1 commands (prefixed with '1') */
        switch (s->cmd_char) {

        /* ── Mouse regions ─────────────────────────────────────── */
        case 'K': /* RIP_KILL_MOUSE — clear all mouse regions */
            s->num_mouse_regions = 0;
            break;
        case 'M': /* RIP_MOUSE — define mouse region
                   * num:2 x0:XY y0:XY x1:XY y1:XY clk:1 clr:1 res:2 res:3 text
                   * (17 characters of fixed params, then text for host command)
                   *
                   * DLL field record layout (rip_mouse.c +0x20 flags byte):
                   *   flags bit 0 → MF_SEND_CHAR(0x08)
                   *   flags bit 1 → MF_RADIO(0x20)
                   *   flags bit 2 → MF_TOGGLE(0x40)
                   *   always set  → MF_ACTIVE(0x04)  — DLL: *pFlagByte |= MF_ACTIVE */
            if (len >= 17 && s->num_mouse_regions < RIP_MAX_MOUSE_REGIONS) {
                rip_mouse_region_t *r = &s->mouse_regions[s->num_mouse_regions];
                r->x0 = mega2(p + 2);  r->y0 = scale_y(mega2(p + 4));
                r->x1 = mega2(p + 6);  r->y1 = scale_y1(mega2(p + 8));
                /* CORRECTED.  args[5] and args[6] are two SEPARATE single
                 * digits -- the 1.54 spec's 'invertable' and 'resetafter',
                 * which bbs-land names clk and clr.  RIPlib read them as one
                 * 2-digit hotkey and then took its flag bits from p[12], which
                 * the record types as reserved.  RIP_MOUSE has no hotkey field.
                 *
                 * Three independent sources agree on the 1+1 split: slot 101's
                 * record (mega2, XY x4, mega1, mega1, mega2, mega3), the
                 * handler at RVA 0x00CEF8 (which loads args[1..7] separately),
                 * and the 1.54 specification.  The corpus settles the impact:
                 * across 36 commands in 22 scenes p[10] is '1' 35 times (and
                 * '3' once) while p[11] and p[12..16] are uniformly '0' -- so
                 * the old hotkey was always the constant 36, the old flags were
                 * always 0, and the clk flag was never captured at all.
                 * The text offset (17) was and remains correct. */
                r->hotkey = 0;
                r->flags  = RIP_MF_ACTIVE;
                if (mega_digit(p[10])) r->flags |= RIP_MF_INVERT;
                if (mega_digit(p[11])) r->flags |= RIP_MF_RESET;
                /* Skip reserved bytes (spec says 4 reserved after flags digit) */
                int text_start = 17; /* num:2 + x0:2 + y0:2 + x1:2 + y1:2 + hotkey:2 + flags:1 + res:4 */
                int tlen = len - text_start;
                if (tlen < 0) tlen = 0;
                if (tlen > 127) tlen = 127;
                if (tlen > 0) memcpy(r->text, p + text_start, (size_t)tlen);
                r->text_len = (uint8_t)tlen;
                r->icon_path[0] = '\0';
                r->active = true;
                r->hover  = false;
                s->num_mouse_regions++;
            }
            break;

        /* ── Button style + buttons ────────────────────────────── */
        case 'B': /* RIP_BUTTON_STYLE -- wid:XY hgt:XY orient:2 flags:4 bevsize:2
                   *                    dfore:2 dback:2 bright:2 dark:2 surface:2
                   *                    grp_no:2 flags2:2 uline:2 corner:2 res:1 res:5
                   *
                   * Signature first, prose after -- see '|1U' above for why.
                   * The reserved tail is TWO fields in the record, mega1 then
                   * mega5, which this comment merged into one res:6.
                   *
                   * Define the style for subsequent RIP_BUTTON commands.
                   * v1.54 spec: !|1B = RIP_BUTTON_STYLE.  The DLL's internal
                   * function name (ripCmd_Button) is misleading -- the
                   * command letter is 'B'.
                   * Total: 36 chars (30 meaningful + 6 reserved) */
            if (RIP_BTNSTYLE_PROTECTED(s)) break;  /* protected slot */
            if (len >= 36) {
                rip_button_style_t *bs = &s->button_style;
                bs->width      = mega2(p);
                bs->height     = mega2(p + 2);
                bs->orient     = (uint8_t)mega2(p + 4);
                bs->flags      = (uint16_t)mega4(p + 6); /* 4-digit MegaNum */
                bs->bev_size   = (uint8_t)mega2(p + 10);
                bs->dfore      = (uint8_t)(mega2(p + 12) & 0x0F);
                bs->dback      = (uint8_t)(mega2(p + 14) & 0x0F);
                bs->bright     = (uint8_t)(mega2(p + 16) & 0x0F);
                bs->dark       = (uint8_t)(mega2(p + 18) & 0x0F);
                bs->surface    = (uint8_t)(mega2(p + 20) & 0x0F);
                bs->grp_no     = (uint8_t)mega2(p + 22);
                bs->flags2     = (uint16_t)mega2(p + 24);
                bs->uline_col  = (uint8_t)(mega2(p + 26) & 0x0F);
                bs->corner_col = (uint8_t)(mega2(p + 28) & 0x0F);
            }
            break;
        case 'U': /* RIP_BUTTON -- x0:XY y0:XY x1:XY y1:XY hotkey:2 flags:1 res:1 text
                   *
                   * The signature has to be on the FIRST line to be machine
                   * readable: ref-compare.py stops collecting at the first
                   * sentence break, so a field list sitting below two lines
                   * of prose is invisible to it.  This command had the list
                   * all along, three lines down, and was uncomparable
                   * because of where it sat.
                   *
                   * Create a button instance: draw it and register a mouse
                   * region.  v1.54 spec: !|1U = RIP_BUTTON.  The DLL's
                   * internal function name (ripCmd_MouseRegion) is
                   * misleading -- the command letter is 'U'.
                   * text format (spec §3.4): icon_file<>display_label<>host_command.
                   * A single segment with no <> is the label only; it does NOT
                   * become the host command.  (The comment here previously
                   * claimed a fallback that has never existed in the code.) */
            if (len >= 12) {
                int16_t bx0 = mega2(p), by0 = scale_y(mega2(p + 2));
                int16_t bx1 = mega2(p + 4), by1 = scale_y1(mega2(p + 6));
                rip_button_style_t *bs = &s->button_style;
                uint8_t surf = s->palette[bs->surface & 0x0F];
                uint8_t hi   = s->palette[bs->bright & 0x0F];
                uint8_t dk   = s->palette[bs->dark & 0x0F];
                int16_t bw = (int16_t)(bx1 - bx0 + 1);
                int16_t bh = (int16_t)(by1 - by0 + 1);
                int16_t bev = bs->bev_size ? (int16_t)bs->bev_size : 2;

                /* Surface fill */
                draw_set_color(surf);
                draw_rect(bx0, by0, bw, bh, true);

                /* Bevel rendering — corrected corner geometry (Fix 5).
                 * Each pass draws one pixel inset from the last.  Adjacent
                 * horizontal and vertical segments must not share a corner pixel
                 * or the wrong color bleeds into the corner.  Convention:
                 *   Highlight owns top-left corners; shadow owns bottom-right.
                 *
                 *   Highlight top:  x=[bx0+i .. bx1-i],     y=by0+i
                 *   Highlight left: x=bx0+i, y=[by0+i+1 .. by1-i-1]  (skip top corner)
                 *   Shadow bottom:  x=[bx0+i+1 .. bx1-i],   y=by1-i  (skip left corner)
                 *   Shadow right:   x=bx1-i, y=[by0+i+1 .. by1-i-1]  (skip top corner)
                 */
                draw_set_color(hi);
                for (int16_t i = 0; i < bev; i++) {
                    draw_hline((int16_t)(bx0 + i), (int16_t)(by0 + i),
                               (int16_t)(bw - 2 * i - 1)); /* top, full */
                    draw_vline((int16_t)(bx0 + i), (int16_t)(by0 + i + 1),
                               (int16_t)(bh - 2 * i - 2)); /* left, skip top corner */
                }
                /* Shadow (bottom + right) */
                draw_set_color(dk);
                for (int16_t i = 0; i < bev; i++) {
                    draw_hline((int16_t)(bx0 + i + 1), (int16_t)(by1 - i),
                               (int16_t)(bw - 2 * i - 1)); /* bottom, skip left corner */
                    draw_vline((int16_t)(bx1 - i), (int16_t)(by0 + i + 1),
                               (int16_t)(bh - 2 * i - 2)); /* right, skip top corner */
                }

                /* Parse text: icon_file<>text_label<>host_command
                 * Per RIPscrip 1.54 spec, three segments separated by <>:
                 *   [icon][<>label[<>host_cmd]]
                 * If no icon (plain button): <>label<>host or <>label */
                int text_off = 12; /* after x0:2+y0:2+x1:2+y1:2+hotkey:2+flags:1+res:1 */
                const char *text_raw = p + text_off;
                int text_len = len - text_off;
                /* Find all <> separators (up to 2) */
                int sep[2] = {-1, -1};
                int nsep = 0;
                for (int i = 0; i + 1 < text_len && nsep < 2; i++) {
                    if (text_raw[i] == '<' && text_raw[i + 1] == '>') {
                        sep[nsep++] = i;
                        i++; /* skip '>' */
                    }
                }
                /* Extract label and host command from segments */
                const char *icon_text = text_raw;
                int icon_len = (nsep > 0) ? sep[0] : text_len;
                const char *label_text = text_raw;
                int label_len = text_len;
                const char *host_text = NULL;
                int host_len = 0;
                if (nsep == 2) {
                    /* icon<>label<>host */
                    label_text = text_raw + sep[0] + 2;
                    label_len = sep[1] - sep[0] - 2;
                    host_text = text_raw + sep[1] + 2;
                    host_len = text_len - sep[1] - 2;
                } else if (nsep == 1) {
                    /* icon<>label (no host) or label<>host */
                    label_text = text_raw + sep[0] + 2;
                    label_len = text_len - sep[0] - 2;
                } else {
                    /* No separator — text is both icon/label */
                    label_text = text_raw;
                    label_len = text_len;
                }
                /* Icon lookup and blit */
                bool icon_drawn = false;
                int16_t label_y = (int16_t)(by0 + (bh - 16) / 2); /* default: label centered */
                if (icon_len > 0) {
                    char icon_name[RIP_FILE_NAME_MAX + 1];
                    int nlen = icon_len < RIP_FILE_NAME_MAX ? icon_len : RIP_FILE_NAME_MAX;
                    memcpy(icon_name, icon_text, (size_t)nlen);
                    icon_name[nlen] = '\0';

                    rip_icon_t icon;
                    if (rip_icon_lookup(&s->icon_state, icon_name, nlen, &icon)) {
                        int16_t ix = (int16_t)(bx0 + (bw - (int16_t)icon.width) / 2);
                        int16_t iy = (int16_t)(by0 + (bh - (int16_t)icon.height) / 2);
                        if (label_len > 0) {
                            /* Icon in upper half; label drawn below */
                            iy = (int16_t)(by0 + bev + 2);
                            label_y = (int16_t)(iy + (int16_t)icon.height + 2);
                        }
                        draw_restore_region(ix, iy, (int16_t)icon.width,
                                            (int16_t)icon.height, icon.pixels);
                        icon_drawn = true;
                    } else {
                        /* Icon not in cache — queue request for file transfer */
                        rip_icon_request_file(&s->icon_state, icon_name, nlen);
                    }
                }
                (void)icon_drawn;

                /* Draw display label centered (or below icon if icon present) */
                if (label_len > 0) {
                    char lbuf[128];
                    int llen = unescape_text(label_text, label_len, lbuf, (int)sizeof(lbuf));
                    if (llen > 0) {
                        uint8_t tc = s->palette[bs->dfore & 0x0F];
                        int16_t tx = (int16_t)(bx0 + (bw - llen * 8) / 2);
                        draw_text(tx, label_y, lbuf, llen, cp437_8x16, 16u, tc, 0xFF);
                    }
                }
                /* Register mouse region for button click.
                 * DLL: ripCmd_MouseRegion always sets MF_ACTIVE(0x04) on the field
                 * record (rip_mouse.c: *pFlagByte |= MF_ACTIVE).
                 *
                 * CORRECTED: this was gated on host_len > 0, so a button with
                 * no host command drew but never became clickable.  Every one
                 * of the 39 '|1U' commands in the shipped corpus is of exactly
                 * that shape -- they carry two separators with an empty third
                 * segment ("<>Clear<>") -- so button hit-testing was dead for
                 * all shipped content.  The region is registered regardless;
                 * the dispatch already guards on text_len before sending, so a
                 * hostless button simply sends nothing while still supporting
                 * hover, SEND_CHAR and TOGGLE.  See D-15. */
                if (s->num_mouse_regions < RIP_MAX_MOUSE_REGIONS) {
                    rip_mouse_region_t *r = &s->mouse_regions[s->num_mouse_regions];
                    r->x0 = bx0; r->y0 = by0; r->x1 = bx1; r->y1 = by1;
                    /* The hotkey and flag fields at p+8 and p[10] were parsed
                     * and then discarded, which left RIPlib's SEND_CHAR/RADIO/
                     * TOGGLE dispatch unreachable from any command: '|1M' was
                     * its only writer and took its bits from a reserved column
                     * that is uniformly '0' in the corpus.  '|1U' is where the
                     * spec, the record (slot 107: XY XY XY XY mega2 mega1
                     * mega1) and bbs-land all agree they live.
                     *
                     * The bit mapping is the one RIPlib already carried on
                     * '|1M'; it is moved here rather than re-derived. */
                    r->flags  = RIP_MF_ACTIVE; /* always active per DLL ground truth */
                    r->hotkey = (uint8_t)(mega2(p + 8) & 0xFF);
                    {
                        int bflags = mega_digit(p[10]);
                        if (bflags & 1) r->flags |= RIP_MF_SEND_CHAR;
                        if (bflags & 2) r->flags |= RIP_MF_RADIO;
                        if (bflags & 4) r->flags |= RIP_MF_TOGGLE;
                    }
                    r->icon_path[0] = '\0';
                    r->hover = false;
                    if (host_len > 127) host_len = 127;
                    /* host_text is NULL when the button's label carries no
                     * host command -- which is every '|1U' in the shipped
                     * corpus ("<>Clear<>").  memcpy's source must be a valid
                     * pointer even when the length is zero (C11 7.24.1p2),
                     * so this needs a guard, not merely a correct size.
                     *
                     * The registration gate above used to be host_len > 0,
                     * which made the call unreachable; removing that gate so
                     * hostless buttons become clickable (D-15) is what
                     * exposed it.  ASan cannot see this -- nothing is read --
                     * and neither can UBSan on Windows, because the check is
                     * nonnull-attribute and only glibc annotates memcpy that
                     * way.  It reproduces on the Linux sanitizer job only. */
                    if (host_len > 0)
                        memcpy(r->text, host_text, (size_t)host_len);
                    r->text_len = (uint8_t)host_len;
                    r->active = true;
                    s->num_mouse_regions++;
                }
                draw_set_color(s->palette[s->draw_color & 0x0F]);
            }
            break;

        /* ── Clipboard (GET_IMAGE / PUT_IMAGE) ─────────────────── */
        case 'C': /* RIP_GET_IMAGE — copy screen region to clipboard
                   * x0:2 y0:2 x1:2 y1:2 res:1 */
            if (len >= 9) {
                int16_t gx0 = mega2(p), gy0 = scale_y(mega2(p + 2));
                int16_t gx1 = mega2(p + 4), gy1 = scale_y1(mega2(p + 6));
                int16_t gw = gx1 - gx0 + 1, gh = gy1 - gy0 + 1;
                (void)rip_clipboard_capture(s, gx0, gy0, gw, gh);
            }
            break;
        case 'P': /* RIP_PUT_IMAGE — paste clipboard to screen
                   * x:2 y:2 mode:2 res:1 */
            if (len >= 7 && s->clipboard.valid && s->clipboard.data) {
                int16_t px = mega2(p), py = scale_y(mega2(p + 2));
                /* mode at p+4: 0=COPY, 1=XOR, 2=OR, 3=AND, 4=NOT — the
                 * RIPscrip wire encoding, confirmed against RIPSCRIP.DLL
                 * 3.0.7 (see docs/spec/12-dll-provenance.md §12.10).
                 * NOTE: trace item T-004 changed this comment the WRONG
                 * way in 2026-05, to match an incorrect drawing.h; both
                 * were corrected 2026-08-12. */
                uint8_t mode = (len >= 6) ? mega2(p + 4) : 0;
                if (mode > 4) mode = 0;
                rip_blit_pixels(s, px, py, s->clipboard.data,
                                (uint16_t)s->clipboard.width,
                                (uint16_t)s->clipboard.height,
                                s->clipboard.width, s->clipboard.height, mode);
            }
            break;

        /* ── Text blocks (BEGIN_TEXT / REGION_TEXT / END_TEXT) ──── */
        case 'T': /* RIP_BeginText — define text region
                   * x0:XY y0:XY x1:XY y1:XY res:1 res:1
                   * Slot 105 splits the trailing reserved field into two
                   * single digits; the total (10 at default widths) is
                   * unchanged, and RIPlib reads only the four coordinates,
                   * so this is a notation correction with no behaviour
                   * attached. */
            if (len >= 10) {
                s->text_block.x0 = mega2(p);
                s->text_block.y0 = scale_y(mega2(p + 2));
                s->text_block.x1 = mega2(p + 4);
                s->text_block.y1 = scale_y1(mega2(p + 6));
                s->text_block.cur_y = s->text_block.y0;
                s->text_block.active = true;
            }
            break;
        case 't': /* RIP_REGION_TEXT — one line in text block (Level 1).
                   * justify:1, text.
                   * L16: previously passed NULL font to draw_text, which made
                   * draw_text early-return — every byte in the bitmap path
                   * was silently dropped.  Also missed $variable expansion.
                   * Now matches the Level 0 't' code path. */
            if (s->text_block.active && len >= 1) {
                int tstart = 1;
                if (tstart < len) {
                    char tbuf[256];
                    char vbuf[256];
                    int tlen = unescape_text(p + tstart, len - tstart, tbuf, (int)sizeof(tbuf));
                    tlen = rip_expand_variables(s, tbuf, tlen, vbuf, sizeof(vbuf));
                    uint8_t tc = s->palette[s->draw_color & 0x0F];
                    draw_text(s->text_block.x0, s->text_block.cur_y,
                              vbuf, tlen, cp437_8x16, 16, tc, 0xFF);
                    s->text_block.cur_y += 16;
                }
            }
            break;
        case 'E': /* RIP_END_TEXT */
            s->text_block.active = false;
            break;

        /* ── Vertical scroll ───────────────────────────────────── */
        case 'G': /* RIP_Scroll — x0:XY y0:XY x1:XY y1:XY mode:1 excl:1 dest_y:XY
                   *
                   * Slot 95 records  FF FF FF FF 01 01 FF  -> 12 characters, and
                   * the handler (RVA 0x00D7E0) names itself in its own
                   * diagnostics: "RIP_Scroll" with "Invalid mode parameter" and
                   * "Nothing to do".  It is NOT RIP_COPY_REGION -- that command
                   * is '|,' (slot 8, ten coordinates), handled at Level 0.
                   *
                   * RIPlib previously required 14 characters and read a
                   * destination *pair* at offsets 10 and 12, on the strength of
                   * the old reconstruction's "8 args".  The handler settles it:
                   *
                   *     SetRect(&r, args[0], args[1], args[2], args[3])
                   *     if (args[5] == 0) { r.right++; r.bottom++; }
                   *     if (args[4] > 6) -> "Invalid mode parameter"
                   *     if (args[6] == r.top) -> "Nothing to do"
                   *     OffsetRect(&r, 0, args[6] - args[1])
                   *
                   * dx is a hardcoded zero, so the move is vertical only and
                   * there is no destination X at all; args[6] is a destination
                   * Y rather than a delta.  args[5] selects whether the rect
                   * edges are inclusive (0) or exclusive (non-zero).  The
                   * driver flips its pixel loop on  dest_y >= y0  so that
                   * overlapping moves do not smear, which draw_copy_rect
                   * already does for us.
                   *
                   * Modes 1..6 additionally run a post-scroll effect routine;
                   * mode 0 exits straight after the move.  Only the move is
                   * implemented here -- see D-14. */
            if (len >= 12) {
                int16_t rx0 = mega2(p), ry0 = scale_y(mega2(p + 2));
                int16_t rx1 = mega2(p + 4), ry1 = scale_y1(mega2(p + 6));
                uint8_t smode = (uint8_t)mega_digit(p[8]);
                uint8_t excl  = (uint8_t)mega_digit(p[9]);
                int16_t dest_y = scale_y(mega2(p + 10));
                int16_t bump = (excl == 0) ? 1 : 0;
                int16_t rw = (int16_t)(rx1 - rx0 + bump);
                int16_t rh = (int16_t)(ry1 - ry0 + bump);
                if (smode <= 6 && dest_y != ry0 && rw > 0 && rh > 0)
                    draw_copy_rect(rx0, ry0, rx0, dest_y, rw, rh);
            }
            break;

        /* ── Icon loading ──────────────────────────────────────── */
        case 'I': /* RIP_LOAD_ICON -- x:XY y:XY mode:1 res:1 clipboard:1
                   *                 stretch:1 res:1 filename
                   *
                   * args[5] is named STRETCH here because that is what the
                   * driver calls it -- "Invalid stretch parameter".  The
                   * bound was implemented two commits before this rename,
                   * and the field went on being called 'res' in the
                   * signature the whole time: the behaviour was corrected
                   * and the NAME was not.  check-field-names.py caught it
                   * by asking whether a concept the driver complains about
                   * has a field to complain about. */
            if (len >= 9) {
                int16_t ix = mega2(p), iy = scale_y(mega2(p + 2));
                /* Dispatch slot 97 records FF FF 01 01 01 01 01 -- after the
                 * two coordinates come FIVE single-digit fields, not a 2-digit
                 * mode.  RIPlib read mega2(p+4), which spans the driver's
                 * args[2] and args[3] and agrees only while args[3] is 0.
                 * The filename offset (9) was already correct. */
                uint8_t mode = (uint8_t)mega_digit(p[4]);
                bool copy_to_clipboard = (mega_digit(p[6]) != 0);
                /* args[5] -- p[7] -- IS NOT RESERVED.  It is a stretch flag
                 * and the handler bounds it:
                 *     cmp dword [ebp-0x10],1
                 *     jbe ok
                 *     push "Invalid stretch parameter"
                 * so above one the driver reports and draws NOTHING.  This
                 * comment used to call p[7] reserved "meaning not
                 * recovered", which was true only in the sense that nobody
                 * had looked.  Found 2026-08-14 disassembling slot 97.
                 *
                 * The stretch behaviour itself is not implemented -- RIPlib
                 * blits at native size -- but refusing what the driver
                 * refuses costs nothing and keeps a malformed icon command
                 * from drawing where the driver would not.  args[3] at p[5]
                 * and args[6] at p[8] remain genuinely unexamined. */
                if (mega_digit(p[7]) > 1)
                    break;
                int fname_start = 9;
                int fname_len = len - fname_start;
                if (fname_len > 0) {
                    const char *path = p + fname_start;
                    if (!rip_filename_is_safe(path, fname_len))
                        break;
                    if (mode > DRAW_MODE_NOT)
                        mode = DRAW_MODE_COPY;

                    rip_icon_t icon;
                    if (rip_icon_lookup(&s->icon_state, path, fname_len, &icon)) {
                        rip_draw_icon_pixels(s, ix, iy, icon.pixels,
                                             icon.width, icon.height,
                                             0, 0, mode);
                        if (copy_to_clipboard)
                            (void)rip_clipboard_store_pixels(s, icon.pixels,
                                                             icon.width,
                                                             icon.height);
                    } else {
                        /* Icon not found — queue file request + draw placeholder */
                        rip_icon_request_file(&s->icon_state, path, fname_len);
                        draw_set_color(s->palette[8]);
                        draw_rect(ix, iy, 32, 32, false);
                        draw_set_color(s->palette[s->draw_color & 0x0F]);
                    }
                }
            }
            break;
        /* ── Level 1 commands recovered from the driver 2026-08-12 ──────
         *
         * These eight were in the driver's dispatch table but absent from
         * RIPlib.  Argument widths come from each entry's type bytes, field
         * meanings from each handler's validation diagnostics
         * (docs/spec §13.5).  Where RIPlib has the machinery the command is
         * performed; where the command is a host filesystem or windowing
         * operation the library deliberately does not have, it is validated
         * the way the driver validates it and recorded, not faked. */

        case 'g': /* RIP_CopyBlit — sx0:XY sy0:XY sx1:XY sy1:XY dx:XY dy:XY
                   *                mode:1 res:1
                   *
                   * Slot 96 records  FF FF FF FF FF FF 01 01  -> 14 characters.
                   * The handler (RVA 0x00B7A4) names itself
                   * "riprocmd - RIP_CopyBlit()" and loads args[0..6]; args[7] is
                   * never read, so the trailing digit is accepted and reserved.
                   * RIPlib gated on 12 characters and treated the mode as
                   * optional, which let a truncated command blit with mode 0.
                   *
                   * Two further corrections from the handler (D-14):
                   *   - it orders both source pairs through 0x1003112E -- the
                   *     same helper '|K' RIP_FILLED_RECTANGLE uses -- rather
                   *     than discarding an inverted rect, which RIPlib did;
                   *   - the mode check is  cmp ebx,5 / jbe, so modes 0..5 are
                   *     legal.  RIPlib's raster ops stop at DRAW_MODE_NOT (4),
                   *     so 5 is accepted per the driver and drawn as COPY. */
            if (len >= 14) {
                int16_t sx0 = mega2(p),      sy0 = scale_y(mega2(p + 2));
                int16_t sx1 = mega2(p + 4),  sy1 = scale_y1(mega2(p + 6));
                int16_t dx  = mega2(p + 8),  dy  = scale_y(mega2(p + 10));
                uint8_t bmode = (uint8_t)mega_digit(p[12]);
                if (sx1 < sx0) { int16_t t = sx0; sx0 = sx1; sx1 = t; }
                if (sy1 < sy0) { int16_t t = sy0; sy0 = sy1; sy1 = t; }
                if (bmode <= 5) {
                    uint8_t saved = s->write_mode;
                    draw_set_write_mode(bmode > DRAW_MODE_NOT
                                        ? DRAW_MODE_COPY : bmode);
                    draw_copy_rect(sx0, sy0, dx, dy,
                                   (int16_t)(sx1 - sx0 + 1),
                                   (int16_t)(sy1 - sy0 + 1));
                    draw_set_write_mode(saved);
                }
            }
            break;

        case 'i': /* RIP_ImageStyle — x0:XY y0:XY x1:XY y1:XY flags:4 res:12
                   * Handler RVA 0x00C39A, "Invalid flags parameter".
                   * This is the command B8 established exists, against
                   * RIPlib's previous (non-existent) '1S'.
                   *
                   * Slot 98 records XY, XY, XY, XY, mega4 and a 12-DIGIT
                   * reserved field -- 24 characters, which is exactly the
                   * width of every payload in the corpus.  RIPlib reads the
                   * meaningful 12-character prefix and ignores the reserved
                   * tail, which is right; but it gated on 12 rather than 24,
                   * so a truncated command was acted on where the driver
                   * would reject it -- the same defect class as '|1g'.
                   * The reserved field is now documented rather than left
                   * implicit, so the field list matches the record.  D-16. */
            if (len >= 24) {
                /* Reuse the existing icon-style rect, which is exactly this
                 * concept: an image area plus a presentation mode. */
                s->icon_style_active = true;
                s->icon_style_x0 = mega2(p);
                s->icon_style_y0 = scale_y(mega2(p + 2));
                s->icon_style_x1 = mega2(p + 4);
                s->icon_style_y1 = scale_y1(mega2(p + 6));
                s->image_style   = (uint8_t)(mega4(p + 8) & 0xFF);
            }
            break;

        case 'c': /* RIP_SetMouseCursor — cursor:2 res:4
                   * Handler RVA 0x00DC96.  RIPlib renders no pointer, so the
                   * selection is recorded for an embedder that does.
                   *
                   * Guarded by ENVIRONMENT protection, which is not a guess:
                   * the handler calls the environment protection query at
                   * 0x1003D9E1 and refuses with "Can't modify current
                   * environment - its protected!" while naming itself
                   * RIP_SetMouseCursor().  The pointer is environment state
                   * in this driver's model. */
            if (RIP_ENV_PROTECTED(s)) break;      /* protected slot */
            if (len >= 6)
                s->mouse_cursor_id = (uint8_t)(mega2(p) & 0xFF);
            break;

        case 'b': /* RIP_LoadBitmap — rect + flags/colour + <filename>
                   * Handler RVA 0x00C569.  Diagnostics include "Invalid
                   * flags parameter", "Invalid colour value", "Invalid string
                   * parameter".  Loading a file needs a filesystem RIPlib
                   * does not have; the name is validated and queued through
                   * the same host-request path as the other file commands. */
            /* CORRECTED: slot 88 records XY, XY, XY, XY, mega1, mega1,
             * mega2, mega2, mega4 -- an EIGHTEEN-character fixed prefix, and
             * the filename starts there.  RIPlib read it from 14, so every
             * bitmap request carried four stray leading zeros:
             *     BUTTONS.RIP  "VU0QYY1S0000000000back.bmp"
             *                   ^--- 18 fixed ---^^-- name --^
             * asked the host for "0000back.bmp".  36 '|1b' commands across
             * the shipped corpus, every one requesting a name no host could
             * match -- the same defect as '|1R' (D-19), in the command that
             * loads the actual artwork.  D-25. */
            if (len >= 18) {
                rip_request_asset_expanded(s, p + 18, len - 18);
                /* rip_filename_is_safe rejects '..', path separators and
                 * control characters at ingest, so the name that reaches the
                 * host queue is already constrained to a bare filename.  The
                 * consumer still owns the trust boundary: RIPlib does not
                 * open files, and a host that does MUST re-validate against
                 * its own root.  Same contract as '|1N' (C-013 / ADR-0003). */
            }
            break;

        case 'p': /* Image-by-name — res:4 <filename>
                   * Handler RVA 0x00C2C6, "Invalid image filename". */
            /* Reaches the driver's interpolation scanner like '|1R' and
             * '|1b' do, so its name expands too.  D-28. */
            if (len >= 4) {
                rip_request_asset_expanded(s, p + 4, len - 4);
            }
            break;

        case 'e': /* RIP_BeginExtendedText — rect + font/flags + search words
                   * Handler RVA 0x00A5ED.  Diagnostics: "Invalid column
                   * number", "Invalid highlight colour", "No search words
                   * encountered", "Too many search words (8 max)".
                   * The search-word highlighting layer is not implemented;
                   * the text block itself reuses the existing '1T' path so
                   * the text still renders rather than vanishing. */
            if (len >= 24) {
                s->text_block.active = true;
                s->text_block.x0 = mega2(p);
                s->text_block.y0 = scale_y(mega2(p + 2));
                s->text_block.x1 = mega2(p + 4);
                s->text_block.y1 = scale_y1(mega2(p + 6));
                s->text_block.cur_y = s->text_block.y0;
            }
            break;

        case 'k': /* RIP_KILL_ENCLOSED_MOUSE_FIELDS — x0:XY y0:XY x1:XY y1:XY res:4
                   *
                   * IDENTIFIED 2026-08-12 from RIPSCRIP.HLP, the driver's own
                   * help resource, which carries an ordered function-name
                   * table grouped by level.  Its Level 1 group contains
                   * RIP_KillEnclosedMouseFields alongside RIP_KillMouseFields
                   * (the plain '|1K' RIPlib already had), and the handler
                   * (RVA 0x00C474) matches exactly: it orders the two
                   * coordinate pairs, applies the same transform '|j' uses,
                   * assembles a RECT via USER32!SetRect and passes it to a
                   * routine, bracketed by the drawing lock/dirty pair.
                   *
                   * Kills every mouse field wholly enclosed by the rectangle,
                   * leaving the rest registered — the selective counterpart
                   * to '|1K', which kills all of them. */
                  /*
                   * The flags:4 field selects WHICH fields to destroy, and
                   * the TeleGrafix reference (bbs-land, 2.0 §4.2, evidence
                   * "2.00a4") documents the bits:
                   *
                   *     1  kill only fields completely contained
                   *     2  kill only fields that intersect the rectangle
                   *     4  kill fields entirely outside the rectangle
                   *
                   * "If 1, 2 and 4 are not present, then NO fields are
                   * deleted."  That default matters: a first implementation
                   * here ignored the flags and always killed the enclosed
                   * set, which destroys fields on a command whose documented
                   * behaviour with flags=0 is to destroy nothing. */
            if (len >= 12) {
                int16_t kx0 = mega2(p),     ky0 = scale_y(mega2(p + 2));
                int16_t kx1 = mega2(p + 4), ky1 = scale_y1(mega2(p + 6));
                uint32_t kflags = (uint32_t)mega4(p + 8);
                if (kx1 < kx0) { int16_t t = kx0; kx0 = kx1; kx1 = t; }
                if (ky1 < ky0) { int16_t t = ky0; ky0 = ky1; ky1 = t; }

                if (kflags & 0x07u) {          /* none of 1/2/4 -> kill nothing */
                    uint16_t kept = 0;
                    for (uint16_t i = 0; i < s->num_mouse_regions; i++) {
                        rip_mouse_region_t *r = &s->mouse_regions[i];
                        bool contained = (r->x0 >= kx0 && r->x1 <= kx1 &&
                                          r->y0 >= ky0 && r->y1 <= ky1);
                        bool overlaps  = !(r->x1 < kx0 || r->x0 > kx1 ||
                                           r->y1 < ky0 || r->y0 > ky1);
                        bool intersects = overlaps && !contained;
                        bool outside    = !overlaps;

                        bool kill = ((kflags & 1u) && contained)
                                 || ((kflags & 2u) && intersects)
                                 || ((kflags & 4u) && outside);
                        if (!kill) {
                            if (kept != i)
                                s->mouse_regions[kept] = *r;
                            kept++;
                        }
                    }
                    s->num_mouse_regions = kept;
                }
            }
            break;

        case 'w': /* RIP_PlayAudio — mode:1 res:3 <filename>
                   *
                   * IMPLEMENTED 2026-08-14.  This letter really is the
                   * driver's audio command, and RIPlib had it as a bare
                   * 'break' while emitting sound requests from '|1A', which
                   * is article selection.  The two were swapped.
                   *
                   * Slot 109, RVA 0x00D24E.  The handler takes the string
                   * tail, rejects it when null or empty, compares it to
                   * "$OFF$" -- which stops playback rather than naming a
                   * file -- and otherwise buffers the name, reporting
                   * "Unable to create temp buffer" against the name string
                   * "RIP_PlayAudio".  The driver imports sndPlaySoundA and
                   * PlaySoundA from WINMM.
                   *
                   * RIPlib performs no audio itself: the request goes to the
                   * host over the TX FIFO behind the CMD_PLAY_SOUND marker,
                   * exactly as '|1Z' does for MIDI, and the host decides.
                   * "$OFF$" is forwarded as an empty name, which is this
                   * library's spelling of "stop".
                   *
                   * No corpus scene sends '|1w'. */
            if (len > 4) {
                const char *fname = p + 4;
                int fname_len = len - 4;
                bool off = (fname_len == 5 && memcmp(fname, "$OFF$", 5) == 0);
                if (off) {
                    char snd_buf[2];
                    snd_buf[0] = (char)0x3D;  /* CMD_PLAY_SOUND marker */
                    snd_buf[1] = '\0';        /* empty name == stop        */
                    riplib_host_tx(snd_buf, 2);
                } else if (fname_len > 0 && fname_len <= 64) {
                    char snd_buf[70];
                    int copy = fname_len < 68 ? fname_len : 68;
                    snd_buf[0] = (char)0x3D;
                    memcpy(snd_buf + 1, fname, (size_t)copy);
                    snd_buf[1 + copy] = '\0';
                    riplib_host_tx(snd_buf, 2 + copy);
                }
            }
            break;

        case 'W': /* RIP_WRITE_ICON — res:1 filename
                   *
                   * Cache the current clipboard under a filename.  Slot 108
                   * records a single mega1, so the fixed prefix is ONE
                   * character and the name starts at offset 1.
                   *
                   * CORRECTED: this used to take the whole payload as the
                   * name and then strip a leading "00" if it happened to see
                   * one -- a heuristic standing in for the record, which
                   * strips two characters where the record says one and
                   * strips nothing when the reserved digit is not '0'.  No
                   * corpus scene sends '|1W', so nothing shipped depended on
                   * either reading.  D-25. */
            if (len > 1 && s->clipboard.valid && s->clipboard.data) {
                const char *name = p + 1;
                int name_len = len - 1;
                (void)rip_cache_clipboard_as_icon(s, name, name_len, NULL);
            }
            break;

        /* ── Audio playback commands ───────────────────────────── */
        case 'A': /* RIP_SelectArticle — article:2 res:4
                   *
                   * IDENTIFIED 2026-08-14 from the handler body, correcting a
                   * reading that had survived every previous audit because
                   * nothing disassembled it.  This was implemented as
                   * RIP_PLAY_AUDIO, taking a filename after the fixed prefix
                   * and pushing a sound request for it.  It is not audio at
                   * all.
                   *
                   * Slot 86, RVA 0x00DC58, does exactly this:
                   *     mov  edi,[eax]        ; args[0] only
                   *     cmp  edi,0x24         ; 36
                   *     jb   ok
                   *     push "Invalid article number"
                   *     push "RIP_SelectArticle()"
                   * ok: push edi / push esi / call 0x1003C399
                   *
                   * It loads ONE argument, bounds it to 36 -- an index into a
                   * 36-entry table, the same size as the port and style
                   * tables -- and never touches args[1] or any string.  The
                   * callee walks an instance-held table at [inst+0x2A]+0x16.
                   * There is no filename, no buffer, no sound API.
                   *
                   * Corroboration, three ways:
                   *   - the driver's real audio command is '|1w', whose
                   *     handler pushes the name string "RIP_PlayAudio" and
                   *     imports sndPlaySoundA/PlaySoundA from WINMM;
                   *   - "article" appears in the driver's text-navigation
                   *     strings, tvarProcOVERFLOW(article,PREV,SETVERBOSE)
                   *     beside "Beginning of document";
                   *   - the one '|1A' in the shipped corpus is in NEWS.RIP
                   *     and selects article 1, which is what a news reader
                   *     would do.
                   *
                   * RIPlib records the index for a host that wants it and
                   * emits nothing.  Selecting an article is a session
                   * concept, not a rendering one. */
            if (len >= 6) {
                /* Gate on SIX, not two.  The handler reads only args[0],
                 * but slot 86 records mega2 + mega4 and the driver will not
                 * dispatch a record it cannot parse in full -- accepting a
                 * truncated one would act where the driver stays silent.
                 * Same discipline as '|1g', '|2p' and '|2s'. */
                int16_t article = mega2(p);
                if (article >= 0 && article < 36)
                    s->selected_article = (uint8_t)article;
                /* else: "Invalid article number" -- the driver rejects it
                 * and draws nothing, so neither do we. */
            }
            break;

        case 'Z': /* RIP_PLAY_MIDI — MIDI file playback.
                   * DLL ground truth: sends to the Windows MIDI sequencer via
                   * CB_PLAY_MIDI.  Format: mode:2 res:2 filename.
                   * RIPlib:same TX FIFO path as RIP_PLAY_AUDIO. */
            if (len >= 4) {
                const char *fname = p + 4;
                int fname_len = len - 4;
                if (fname_len > 0 && fname_len <= 64) {
                    char snd_buf[70];
                    snd_buf[0] = (char)0x3D; /* CMD_PLAY_SOUND marker */
                    int copy = fname_len < 68 ? fname_len : 68;
                    memcpy(snd_buf + 1, fname, (size_t)copy);
                    snd_buf[1 + copy] = '\0';
                    riplib_host_tx(snd_buf, 2 + copy);
                }
            }
            break;

        /* ── Image display style ────────────────────────────────── */
        /* '1S' is NOT a command.  Neither 'S' nor 's' appears anywhere in
         * the driver's Level 1 band, and image style is '|1i'
         * RIP_ImageStyle (slot 98, RVA 0x00c39a, 6 args) — handled above,
         * and the form real scenes actually use.  The duplicate handler
         * that lived here is removed rather than kept as an alias:
         * accepting an opcode the protocol does not define is how a stream
         * desynchronises silently. */

        /* ── Icon search path ────────────────────────────────────── */
        case 'N': /* RIP_SET_ICON_DIR — set icon search directory.
                   * DLL stores in RIPINST.IconPath (rip_instance.c init cascade
                   * step 11, "IconPath" string at 0x10026218 region).
                   * Format: res:2 path (free text).
                   * RIPlib:store the path tag; consult on future icon requests. */
            if (len >= 2) {
                int plen = len - 2;
                if (plen >= (int)sizeof(s->icon_dir))
                    plen = (int)sizeof(s->icon_dir) - 1;
                /* C-013/ADR-0003: filter the wire-supplied path before
                 * storing it.  Allows '/' (directories) but rejects '..',
                 * control chars, '\\', ':'.  A consumer that opens the
                 * path must still treat it as untrusted. */
                if (rip_dirpath_is_safe(p + 2, plen)) {
                    memcpy(s->icon_dir, p + 2, (size_t)plen);
                    s->icon_dir[plen] = '\0';
                } else {
                    s->icon_dir[0] = '\0';
                }
            }
            break;

        /* ── Font loading ───────────────────────────────────────── */
        case 'O': /* RIP_FONT_LOAD — load BGI/RFF font from file.
                   * DLL: loads font into the per-instance font table.
                   * RIPlib:built-in BGI fonts are pre-compiled in flash.
                   * If the requested CHR name matches one, make it active;
                   * otherwise queue a file request for the host side. */
            if (len > 0) {
                int off = 0;
                int fid;
                if (len > 2 && p[0] == '0' && p[1] == '0')
                    off = 2;
                fid = rip_font_id_from_name(p + off, len - off);
                if (fid >= 0 && fid < BGI_FONT_COUNT) {
                    s->font_id = (uint8_t)fid;
                    s->font_ext_id = (uint8_t)fid;
                } else if (rip_filename_is_safe(p + off, len - off)) {
                    rip_icon_request_file(&s->icon_state, p + off, len - off);
                }
            }
            break;

        /* ── Extended query routing ─────────────────────────────── */
        case 'Q': /* RIP_QUERY_EXT — extended query command.
                   * DLL: routes to the same handler as the ESC-char (0x1B)
                   * QUERY command but with extended flags.  Format: flags:3 res:2 varname.
                   * RIPlib:route to the same handler inline — identical logic. */
            if (len >= 5) {
                const char *vname = p + 5;
                int vlen = len - 5;
                char resp[64];
                int rlen = 0;
                /* $APPn$ query — mirrors the ESC-char QUERY case above */
                if (vlen >= 6 && vname[0] == '$' && vname[1] == 'A' &&
                    vname[2] == 'P' && vname[3] == 'P' &&
                    vname[4] >= '0' && vname[4] <= '9' && vname[5] == '$') {
                    int idx = vname[4] - '0';
                    rlen = (int)rip_strnlen(s->app_vars[idx], sizeof(s->app_vars[0]));
                    if (rlen > 0)
                        riplib_host_tx(s->app_vars[idx], rlen);
                    else
                        (void)rip_query_prompt_begin(s, vname, vlen);
                } else {
                    char key[RIP_USER_VAR_NAME_MAX + 1];
                    if (rip_var_name_copy(vname, vlen, key, sizeof(key))) {
                        int uidx = rip_user_var_find(s, key, (int)strlen(key));
                        if (uidx >= 0) {
                            rlen = (int)rip_strnlen(s->user_var_values[uidx],
                                                    sizeof(s->user_var_values[uidx]));
                            if (rlen > 0)
                                riplib_host_tx(s->user_var_values[uidx], rlen);
                        } else {
                            (void)rip_query_prompt_begin(s, vname, vlen);
                        }
                    } else {
                        (void)resp; (void)rlen;
                        riplib_host_tx("\r", 1);
                    }
                }
            }
            break;

        /* ── Extended viewport with scale ───────────────────────── */
        case 'V': /* RIP_SET_VIEWPORT_EXT — viewport + scale factor.
                   * DLL: sets both the clipping rectangle and a zoom/scale
                   * factor for subsequent coordinate calculations.
                   * Format: x0:2 y0:2 x1:2 y1:2 scale:1
                   * RIPlib:set viewport rect (same as 'v'), store scale field.
                   * The fixed 640×400 framebuffer cannot actually scale, but
                   * we store the field so future capability queries are correct. */
            if (len >= 9) {
                int16_t vx0 = mega2(p), vy0 = mega2(p + 2);
                int16_t vx1 = mega2(p + 4), vy1 = mega2(p + 6);
                clamp_ega_rect(&vx0, &vy0, &vx1, &vy1);
                set_session_viewport(s, vx0, scale_y(vy0),
                                        vx1, scale_y1(vy1));
                s->viewport_scale = (uint8_t)mega_digit(p[8]);
            }
            break;

        /* ── Extended clipboard operations ──────────────────────── */
        case 'X': /* RIP_CLIPBOARD_OP — extended clipboard operations.
                   * DLL: provides compound clipboard operations (blend, mask,
                   * flip, rotate) beyond the basic GET/PUT_IMAGE pair.
                   * Format: op:2 [params vary by op].
                   * Embedded fallback ops:
                   *   0=clear, 1=flip horizontal, 2=flip vertical,
                   *   3=rotate 180, 4=invert palette bytes,
                   *   5=capture x0/y0/x1/y1, 6=paste x/y/mode. */
            if (len >= 2) {
                uint8_t op = (uint8_t)(mega2(p) & 0xFF);
                if (op == 0) {
                    s->clipboard.valid = false;
                    s->clipboard.width = 0;
                    s->clipboard.height = 0;
                } else if (s->clipboard.valid && s->clipboard.data &&
                           op >= 1 && op <= 4) {
                    int16_t cw = s->clipboard.width;
                    int16_t ch = s->clipboard.height;
                    if (op == 1 || op == 3) {
                        for (int16_t yy = 0; yy < ch; yy++) {
                            uint8_t *row = s->clipboard.data + (size_t)yy * (uint16_t)cw;
                            for (int16_t xx = 0; xx < cw / 2; xx++) {
                                uint8_t t = row[xx];
                                row[xx] = row[cw - 1 - xx];
                                row[cw - 1 - xx] = t;
                            }
                        }
                    }
                    if (op == 2 || op == 3) {
                        for (int16_t yy = 0; yy < ch / 2; yy++) {
                            uint8_t *top = s->clipboard.data + (size_t)yy * (uint16_t)cw;
                            uint8_t *bot = s->clipboard.data + (size_t)(ch - 1 - yy) * (uint16_t)cw;
                            for (int16_t xx = 0; xx < cw; xx++) {
                                uint8_t t = top[xx];
                                top[xx] = bot[xx];
                                bot[xx] = t;
                            }
                        }
                    }
                    if (op == 4) {
                        size_t n = (size_t)(uint16_t)cw * (size_t)(uint16_t)ch;
                        for (size_t i = 0; i < n; i++)
                            s->clipboard.data[i] = (uint8_t)~s->clipboard.data[i];
                    }
                } else if (op == 5 && len >= 10) {
                    int16_t x0 = mega2(p + 2);
                    int16_t y0 = scale_y(mega2(p + 4));
                    int16_t x1 = mega2(p + 6);
                    int16_t y1 = scale_y1(mega2(p + 8));
                    (void)rip_clipboard_capture(s, x0, y0,
                                                (int16_t)(x1 - x0 + 1),
                                                (int16_t)(y1 - y0 + 1));
                } else if (op == 6 && len >= 8 &&
                           s->clipboard.valid && s->clipboard.data) {
                    int16_t x = mega2(p + 2);
                    int16_t y = scale_y(mega2(p + 4));
                    uint8_t mode = (uint8_t)(mega2(p + 6) & 0xFF);
                    if (mode > DRAW_MODE_NOT) mode = DRAW_MODE_COPY;
                    rip_blit_pixels(s, x, y, s->clipboard.data,
                                    (uint16_t)s->clipboard.width,
                                    (uint16_t)s->clipboard.height,
                                    s->clipboard.width, s->clipboard.height,
                                    mode);
                }
            }
            break;

        /* ── Scene / file operations (no filesystem) ──────────── */
        case 'R': /* RIP_READ_SCENE — res:2 res:6 filename
                   *
                   * CORRECTED.  Slot 104 records mega2 + a 6-digit field, so
                   * the fixed prefix is EIGHT characters and the filename
                   * starts there (D-16: the record types only the numeric
                   * argument array; a trailing string follows it).
                   *
                   * The corpus is unambiguous -- every one of the 25 '|1R'
                   * commands in it begins with exactly eight zeros:
                   *     DRAGON.RIP   "00000000dragon.txt"
                   *     BUTTONS.RIP  "00000000<<IF $COLORS$..."
                   * RIPlib took the filename from offset 0, so it requested
                   * "00000000dragon.txt" -- every scene-file request it made
                   * was for a name no host could match.  D-19. */
            if (len > RIP_READSCENE_RESERVED) {
                rip_request_asset_expanded(s, p + RIP_READSCENE_RESERVED,
                                           len - RIP_READSCENE_RESERVED);
            }
            break;
        case 'F': /* RIP_FILE_QUERY — mode:2 res:4 filename
                   * E5: DLL extended response format (rip_images.c):
                   *   "1 filename size timestamp\r"  (file present, with metadata)
                   *   "1\r"                          (file present, no metadata)
                   *   "0\r"                          (file absent)
                   * size is decimal pixel-data byte count; timestamp 0 (unknown). */
            if (len >= 6) {
                int mode = mega2(p);
                /* Null-terminate filename for response formatting */
                char fname_buf[64];
                const char *fname = p + 6;
                int flen = len - 6;
                if (flen <= 0) break;
                /* Slot 94 (RVA 0x00BDE4) bounds the mode:
                 *     cmp ebx,4 / jbe ok
                 *     push "Invalid mode parameter"
                 * so the driver ANSWERS NOTHING above four.  RIPlib decoded
                 * the mode and then discarded it -- there was a literal
                 * "(void)mode;" below -- and replied to queries the driver
                 * refuses.  A query is host-visible traffic, so replying
                 * where the driver stays silent is the same defect class as
                 * a loose length gate.  Found 2026-08-14 by disassembling a
                 * handler nothing had ever read. */
                if (mode > 4) break;
                if (!rip_filename_is_safe(fname, flen)) {
                    riplib_host_tx("0\r", 2);
                    break;
                }
                if (flen > (int)sizeof(fname_buf) - 1)
                    flen = (int)sizeof(fname_buf) - 1;
                memcpy(fname_buf, fname, (size_t)flen);
                fname_buf[flen] = '\0';

                rip_icon_t icon;
                if (rip_icon_lookup(&s->icon_state, fname, flen, &icon)) {
                    /* E5: Extended response — include pixel-data size when available.
                     * width * height is the raw 8bpp pixel byte count, which matches
                     * what the BBS uses to decide whether to re-send the file. */
                    if (icon.width > 0 && icon.height > 0) {
                        char resp[128];
                        unsigned long file_size = (unsigned long)icon.width * icon.height;
                        snprintf(resp, sizeof(resp), "1 %s %lu 0\r",
                                 fname_buf, file_size);
                        riplib_host_tx(resp, (int)strlen(resp));
                    } else {
                        /* Icon present but no dimension metadata — abbreviated form */
                        riplib_host_tx("1\r", 2);
                    }
                } else {
                    riplib_host_tx("0\r", 2);
                    rip_icon_request_file(&s->icon_state, fname, flen);
                }
                (void)mode; /* bounded above; no per-mode behaviour yet */
            }
            break;

        /* ── Text variables (DEFINE / QUERY) ──────────────────── */
        case 'D': /* RIP_DEFINE — define text variable
                   * flags:3 res:2 text (format: varname[,width]:?prompt?[default])
                   * For $APP0$-$APP9$: store default value in app_vars[].
                   * For other variables: display the prompt/default as text. */
            if (len >= 5) {
                /* Skip flags:3 + res:2, process remaining text */
                int tstart = (len >= 5) ? 5 : 0;
                if (tstart < len) {
                    char tbuf[128];
                    int tlen = unescape_text(p + tstart, len - tstart, tbuf, (int)sizeof(tbuf));
                    int eq = -1;
                    bool handled_define = false;
                    for (int i = 0; i < tlen; i++) {
                        if (tbuf[i] == '=') { eq = i; break; }
                        if (tbuf[i] == '?') break;
                    }
                    if (eq > 0) {
                        handled_define = rip_user_var_set(s, tbuf, eq,
                                                          tbuf + eq + 1,
                                                          tlen - eq - 1);
                    }
                    /* Find default value between last pair of ? marks */
                    const char *display = tbuf;
                    int dlen = tlen;
                    /* Look for ?prompt?default — extract default */
                    int q1 = -1, q2 = -1;
                    for (int i = 0; i < tlen; i++) {
                        if (tbuf[i] == '?') {
                            if (q1 < 0) q1 = i;
                            else { q2 = i; break; }
                        }
                    }
                    if (q2 > 0 && q2 + 1 < tlen) {
                        display = tbuf + q2 + 1;
                        dlen = tlen - q2 - 1;
                    }

                    /* L18: Only run the legacy "$APPn$:?prompt?default" /
                     * "$NAME$" parsing if the "name=value" path above didn't
                     * already store the variable.  Without this guard the
                     * $APPn$ branch would re-overwrite app_vars[idx] with
                     * the raw, unparsed "$APPn$=value" string. */
                    int colon = -1;
                    for (int i = 0; i < tlen; i++) {
                        if (tbuf[i] == ':' || tbuf[i] == '?') { colon = i; break; }
                    }
                    int name_end = (colon >= 0) ? colon : tlen;
                    if (!handled_define) {
                        if (name_end >= 6 && tbuf[0] == '$' && tbuf[1] == 'A' &&
                            tbuf[2] == 'P' && tbuf[3] == 'P' &&
                            tbuf[4] >= '0' && tbuf[4] <= '9' && tbuf[5] == '$') {
                            /* Store default value into app_vars[idx] */
                            int idx = tbuf[4] - '0';
                            int vlen = dlen < 31 ? dlen : 31;
                            memcpy(s->app_vars[idx], display, (size_t)vlen);
                            s->app_vars[idx][vlen] = '\0';
                            handled_define = true;
                        } else if (name_end >= 3 && tbuf[0] == '$' &&
                                   tbuf[name_end - 1] == '$') {
                            handled_define = rip_user_var_set(s, tbuf, name_end,
                                                              display, dlen);
                        }
                    }
                    if (!handled_define) {
                        char rawbuf[128];
                        int rawlen = unescape_text(p, len, rawbuf,
                                                   (int)sizeof(rawbuf));
                        int raw_eq = -1;
                        for (int i = 0; i < rawlen; i++) {
                            if (rawbuf[i] == '=') { raw_eq = i; break; }
                            if (rawbuf[i] == '?') break;
                        }
                        if (raw_eq > 0) {
                            handled_define = rip_user_var_set(s, rawbuf, raw_eq,
                                                              rawbuf + raw_eq + 1,
                                                              rawlen - raw_eq - 1);
                        }
                    }
                    if (!handled_define) {
                        /* L17: same NULL-font silent-drop bug as L14/L16.
                         * Render the prompt with cp437_8x16. */
                        if (dlen > 0) {
                            uint8_t tc = s->palette[s->draw_color & 0x0F];
                            draw_text(s->draw_x, s->draw_y, display, dlen,
                                      cp437_8x16, 16, tc, 0xFF);
                        }
                    }
                }
            }
            break;
        case 0x1B: /* rip_query -- mode:1 target:1 res:2 varname
                    *
                    * Query/send a text variable.  Slot 85 records
                    * mega1 + mega1 + mega2, so the fixed prefix is FOUR
                    * characters.  This line read "flags:3 res:2 varname"
                    * and the code read from offset five, which swallowed
                    * the leading '$' of every name.
                    *
                    * Recognized variables: $APP0$-$APP9$, $OVERFLOW$,
                    *   $OVERFLOW(NEXT)$, $OVERFLOW(PREV)$, $OVERFLOW(RESET)$
                    *
                    * CB_INPUT_TEXT callback equivalent.
                    * When a RIP_QUERY targets a $APPn$ variable AND the variable
                    * is empty (BBS wants user to fill it in), instead of returning
                    * the empty string we start a parser→host→parser round-trip:
                    *   1. Push CMD_QUERY_PROMPT marker (0x3E) + prompt text + NUL
                    *      via TX FIFO so the host can display an input form.
                    *   2. Set query_pending and record the target variable name.
                    *   3. Do NOT send a response to the BBS yet; wait for the host
                    *      to send response bytes via rip_query_response_byte().
                    * If the variable already has content, return it immediately
                    * (BBS is just querying a stored value, not requesting input).
                    *
                    * CORRECTED 2026-08-15.  The fixed prefix is FOUR
                    * characters, not five.  Reading five swallowed the
                    * leading '$' of every variable name -- "0000$DTW$" was
                    * parsed as "DTW$" -- so every vname[0] == '$' test below
                    * failed and the query silently did nothing.
                    *
                    * Two independent confirmations.  Slot 85 records
                    * mega1 + mega1 + mega2 = four.  And all EIGHTY
                    * '|1<ESC>' commands in the shipped corpus carry exactly
                    * four leading characters before the name: "0000$DTW$",
                    * "0000$COMPAT$", "0000$SBAROFF$".
                    *
                    * It survived because ref-compare.py could not see it:
                    * the extractor matches `case 'X':` and this arm is
                    * `case 0x1B:`, so the Level 1 command with the MOST
                    * corpus traffic was the one the comparison skipped.
                    *
                    * '|1Q' RIP_QUERY_EXT below keeps its five-character
                    * prefix: it has no dispatch entry at all, so that width
                    * is RIPlib's own convention rather than a record to
                    * conform to. */
            if (len >= 4) {
                const char *vname = p + 4;
                int vlen = len - 4;
                char resp[64];
                int rlen = 0;

                /* $APPn$ — return stored application variable, or request input */
                if (vlen >= 6 && vname[0] == '$' && vname[1] == 'A' &&
                    vname[2] == 'P' && vname[3] == 'P' &&
                    vname[4] >= '0' && vname[4] <= '9' && vname[5] == '$') {
                    int idx = vname[4] - '0';
                    rlen = (int)rip_strnlen(s->app_vars[idx], sizeof(s->app_vars[0]));
                    if (rlen == 0 && rip_query_prompt_begin(s, vname, vlen)) {
                        /* Do not push a response to the BBS yet */
                        rlen = -1;  /* sentinel: skip riplib_host_tx below */
                    } else {
                        memcpy(resp, s->app_vars[idx], (size_t)rlen);
                    }

                /* $OVERFLOW(RESET)$ — reset to first page */
                } else if (vlen >= 18 &&
                    memcmp(vname, "$OVERFLOW(RESET)$", 17) == 0) {
                    s->rip2_state.overflow_page = 0;
                    rlen = 0;

                /* $OVERFLOW(NEXT)$ — advance one page */
                } else if (vlen >= 17 &&
                    memcmp(vname, "$OVERFLOW(NEXT)$", 16) == 0) {
                    if (s->rip2_state.overflow_page + 1 < s->rip2_state.overflow_total)
                        s->rip2_state.overflow_page++;
                    rlen = 0;

                /* $OVERFLOW(PREV)$ — back one page */
                } else if (vlen >= 17 &&
                    memcmp(vname, "$OVERFLOW(PREV)$", 16) == 0) {
                    if (s->rip2_state.overflow_page > 0)
                        s->rip2_state.overflow_page--;
                    rlen = 0;

                /* $OVERFLOW$ — return "page/total" string */
                } else if (vlen >= 11 &&
                    memcmp(vname, "$OVERFLOW$", 10) == 0) {
                    rlen = snprintf(resp, sizeof(resp), "%u/%u",
                                   s->rip2_state.overflow_page + 1,
                                   s->rip2_state.overflow_total);
                    if (rlen < 0) rlen = 0;

                /* Fix SV-1/S1: $FILEDEL$ — intentionally not implemented.
                 * Remote file deletion is a security vulnerability. Log and ignore. */
                } else if (vlen >= 10 &&
                    memcmp(vname, "$FILEDEL$", 9) == 0) {
                    /* Received $FILEDEL$ — silently ignore, do not delete anything */
                    rlen = 0;

                /* Fix SV-2/S2: $GOTOURL$ — RIPlib never launches a process or
                 * opens a URL itself.  Since 2026-08-12 this route is routed
                 * through the SAME opt-in path as '|3G', so the two ways a
                 * stream can ask for a URL behave identically instead of one
                 * being a dead end and the other not:
                 *   - same scheme allow-list (http/https only),
                 *   - same control-character rejection,
                 *   - stored in s->goto_url,
                 *   - handler invoked ONLY if the embedder registered one.
                 * The response to the stream stays zero-length either way, so
                 * a hostile host learns nothing about whether a handler
                 * exists. */
                } else if (vlen >= 10 &&
                    memcmp(vname, "$GOTOURL$", 9) == 0) {
                    const char *u = vname + 9;
                    int ulen = vlen - 9;
                    if (ulen > 0 && ulen < (int)sizeof(s->goto_url)) {
                        int ok = 1;
                        for (int i = 0; i < ulen; i++) {
                            if ((unsigned char)u[i] < 0x21 ||
                                (unsigned char)u[i] > 0x7E) { ok = 0; break; }
                        }
                        if (ok && rip_url_scheme_allowed(u, ulen)) {
                            memcpy(s->goto_url, u, (size_t)ulen);
                            s->goto_url[ulen] = '\0';
                            if (s->url_handler)
                                s->url_handler(s->goto_url, ulen);
                        }
                    }
                    rlen = 0;

                } else {
                    char key[RIP_USER_VAR_NAME_MAX + 1];
                    if (rip_var_name_copy(vname, vlen, key, sizeof(key))) {
                        int uidx = rip_user_var_find(s, key, (int)strlen(key));
                        if (uidx >= 0) {
                            rlen = (int)rip_strnlen(s->user_var_values[uidx],
                                                    sizeof(s->user_var_values[uidx]));
                            if (rlen > (int)sizeof(resp))
                                rlen = (int)sizeof(resp);
                            memcpy(resp, s->user_var_values[uidx], (size_t)rlen);
                        } else {
                            /* UNDEFINED variable: say nothing.  Do NOT prompt.
                             *
                             * This branch used to call
                             * rip_query_prompt_begin(), asking the host to
                             * put up an input form for any name it did not
                             * recognise.  With the offset bug above that
                             * never fired; correcting the offset fired it
                             * eighty times across eleven corpus scenes.
                             *
                             * It is wrong independently of the harness.  The
                             * names shipped content actually queries --
                             * $DTW$, $COMPAT$, $SBAROFF$ -- are CAPABILITY
                             * queries, and the driver carries "DTW",
                             * "COMPAT" and "SBAROFF" as known strings.  A
                             * terminal answers those from its own state; it
                             * does not interrupt the user to ask what DTW
                             * should be.
                             *
                             * RIPlib implements none of them, so it has
                             * nothing to say and says nothing.  Prompting is
                             * reserved for variables the STREAM defined,
                             * which is the '$APPn$' path above. */
                            rlen = 0;
                        }
                    } else {
                        rlen = 0;
                    }
                }

                /* rlen == -1 means query_pending was set; don't respond to BBS yet. */
                if (rlen > 0)
                    riplib_host_tx(resp, rlen);
            }
            break;

        default:
            break;
        }
        return;
    }

    /* Level 0 commands */
    switch (s->cmd_char) {

    /* ── Comment ─────────────────────────────────────────────── */
    case '!': /* RIP_COMMENT — slot 0, argc 0; the rest of the line is text
               * with no rendering effect.
               *
               * This is the most frequent command in shipped content: 709
               * occurrences across the corpus, 544 of them empty, the rest
               * carrying prose or rule-off lines ("!|! Show our bounding
               * box", "!|!------").  RIPlib consumed them correctly before
               * this case existed -- the Level 0 switch has no default, so an
               * unmatched letter simply falls out and does nothing -- but it
               * did so by accident rather than by intent, and a coverage
               * audit could not tell the two apart.  Stated explicitly so the
               * command is implemented rather than merely survived.  D-19. */
        break;

    /* ── Drawing state ───────────────────────────────────────── */
    case 'c': /* RIP_COLOR -- color:CM */
        if (RIP_STYLE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 2) s->draw_color = mega2(p) & 0x0F;
        break;
    case 'S': /* v1.54 spec: 'S' = RIP_FILL_STYLE — pattern:2 color:2 */
        if (RIP_STYLE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 4) {
            /* spec §2.4: pattern range 0-12.  A malformed out-of-range
             * value maps to 0 (no fill) rather than a wrapped junk pattern
             * that would fill with a stale card style (C-012). */
            int fp = mega2(p);
            s->fill_pattern = (uint8_t)((fp < 0 || fp > 12) ? 0 : fp);
            s->fill_color = (uint8_t)(mega2(p + 2) & 0x0F);
            int8_t card_pat = bgi_fill_to_card(s->fill_pattern);
            if (card_pat >= 0)
                draw_set_fill_style((uint8_t)card_pat, s->palette[s->back_color]);
        }
        break;
    /* Dispatch slot 14, argc 4: mega1, mega1, mega4, mega2 -- FOUR fields.
     * RIPlib read the first two digits as a single mega2 style, which
     * coincides with the correct reading whenever off_draw is 0 (every
     * payload in TeleGrafix's shipped content) and silently mis-reads the
     * style otherwise.  The handler validates args[1] <= 4, which is the
     * BGI line-style range, confirming args[1] is the style and args[0] is
     * the separate off/draw selector.  bbs-land documents this correctly as
     * `off_draw:1 style:1 user_pat:4 thick:2`. */
    case '=': /* RIP_LINE_STYLE -- off_draw:1 style:1 user_pat:4 thick:2
               *
               * Slot 14 records eight characters, and this gate admits four.
               * That is a DELIBERATE tolerance, matched to what shipped
               * scenes actually send: of 116 '|=' commands in the corpus,
               * 107 are the full eight, 2 are seven and 7 are four.  The
               * short forms are real content, so the handler reads
               * progressively -- off_draw and style at four, the user
               * pattern at six, the thickness at eight -- rather than
               * rejecting a record the driver would reject.
               *
               * Same class as '|k' (D-18): the record says what the driver
               * accepts, not what content exists.  See 14.3.3. */
        if (RIP_STYLE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 4) {
            s->line_off_draw = (uint8_t)mega_digit(p[0]);
            s->line_style    = (uint8_t)mega_digit(p[1]);
            if (len >= 8) {
                int16_t thick = scale_y(mega2(p + 6)); /* Fix B6: scale thickness to card Y */
                if (thick < 1) thick = 1;
                if (thick > 255) thick = 255;
                s->line_thick = (uint8_t)thick;
            }
            s->line_pattern = rip_line_style_to_pattern(
                s->line_style, (len >= 6) ? (uint16_t)mega4(p + 2) : 0xFFFFu);
            draw_set_line_style(s->line_pattern, s->line_thick);
        }
        break;
    case 'W': /* v1.54 spec: 'W' = RIP_WRITE_MODE — mode:2 */
        if (RIP_STYLE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 2) {
            uint8_t wm = (uint8_t)mega2(p);
            if (wm > 4) wm = 0;
            s->write_mode = wm;
            draw_set_write_mode(wm);
        }
        break;
    case 'Y': /* RIP_FONT_STYLE — font:2 dir:2 size:2 flags:2 */
        if (RIP_STYLE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 8) {
            uint8_t fid = (uint8_t)mega2(p);
            uint8_t fdir = (uint8_t)mega2(p + 2);
            uint8_t fsize = (uint8_t)mega2(p + 4);
            /* Validate: dir 0-3, size 1-10.
             * 0 = horizontal
             * 1 = BGI VERT_DIR, bottom-to-top (the 1.54 documented value)
             * 2 = vertical CCW glyphs, top-to-bottom  (RIPlib)
             * 3 = vertical CW  glyphs, top-to-bottom  (RIPlib; this is what
             *     dir=1 did before the 2026-08-12 X3 correction) */
            /* The handler (RVA 0x01C87E) validates all three:
             *     cmp ebx,0xA   jbe   -> font 0..10  "Illegal font number"
             *     cmp [ebp-8],1 jbe   -> dir  0..1   "Illegal direction"
             *     [ebp-0xc] in 1..10  -> size 1..10  (silent reject)
             * RIPlib enforced the size but not the font number, so a font
             * the driver rejects outright was accepted and fell through to
             * the 8x16 bitmap fallback -- the driver keeps the previous font
             * instead.  Corpus fonts run 0..10, so nothing shipped is
             * affected.  Directions 2 and 3 are RIPlib extensions and are
             * deliberately kept; see 14.3 and the note above.  D-21. */
            if (fid > 10) break;
            if (fdir > 3) break;
            if (fsize < 1 || fsize > 10) break;
            s->font_id = fid;
            s->font_dir = fdir;
            s->font_size = fsize;
            /* v3.0 extension: justification flags in arg[3] (reserved in v1.54) */
            if (len >= 8) {
                uint8_t flags = (uint8_t)mega2(p + 6);
                s->font_hjust = 0;
                if (flags & 0x02) s->font_hjust = 1; /* center */
                if (flags & 0x04) s->font_hjust = 2; /* right */
                s->font_vjust = 0;
                if (flags & 0x10) s->font_vjust = 1; /* center */
                if (flags & 0x20) s->font_vjust = 2; /* top */
                if (flags & 0x40) s->font_vjust = 3; /* baseline */
            }
        }
        break;

    /* ── Cursor / position ───────────────────────────────────── */
    case 'm': /* RIP_MOVE */
        if (len >= 4) {
            s->draw_x = mega2(p);
            s->draw_y = scale_y(mega2(p + 2));
        }
        break;
    case 'g': /* RIP_GOTOXY (text cursor).  col/row are MegaNum-bounded to
               * 0..1295.  Unlike graphics coordinates, RIPlib does NOT clamp
               * these here: it does not own the text grid — the host's
               * comp_set_cursor callback must clamp to its own dimensions. */
        if (len >= 4) {
            comp_set_cursor(c, mega2(p), mega2(p + 2));
        }
        break;
    case 'H': /* RIP_HOME */
        comp_set_cursor(c, 0, 0);
        break;

    /* ── Screen operations ───────────────────────────────────── */
    case '*': /* RIP_RESET_WINDOWS — full state reset per spec */
        rip_reset_windows_state(s, c);
        break;
    case 'e': /* v1.54 spec §3.1: '|e' = RIP_ERASE_WINDOW — clear text window to background,
               * move cursor to upper-left of text window. IcyTerm: EraseWindow (0 args).
               * Note: previous "Fix B5" had this backwards; 'e' is always text-window clear. */
        comp_clear_screen(c, 2);
        break;
    case 'E': /* v1.54 spec §3.2: '|E' = RIP_ERASE_VIEW — clear graphics viewport
               * to background color (RIP_BACK_COLOR).  Previously hard-coded to
               * palette index 0 which only matches the default back_color. */
        {
            uint8_t bg = s->palette[s->back_color & 0x0F];
            uint8_t fg = s->palette[s->draw_color & 0x0F];
            draw_set_color(bg);
            draw_rect(s->vp_x0, s->vp_y0,
                      (int16_t)(s->vp_x1 - s->vp_x0 + 1),
                      (int16_t)(s->vp_y1 - s->vp_y0 + 1), true);
            draw_set_color(fg);
        }
        break;
    case '>': /* v1.54 spec §3.3: '|>' = RIP_ERASE_EOL — erase from text cursor to end of line.
               * IcyTerm: EraseEOL (0 args).
               * Note: previous code had '>' as NoMore and '#' as EraseWindow — both wrong. */
        comp_clear_line(c, 0);
        break;
    case 'w': /* RIP_TEXT_WINDOW — pixel coordinates for text region */
        if (RIP_TEXTWIN_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 10) {
            int16_t tw_x0 = mega2(p);
            int16_t tw_y0 = mega2(p + 2);
            int16_t tw_x1 = mega2(p + 4);
            int16_t tw_y1 = mega2(p + 6);
            clamp_ega_rect(&tw_x0, &tw_y0, &tw_x1, &tw_y1);
            s->tw_x0 = tw_x0;
            s->tw_y0 = tw_y0;
            s->tw_x1 = tw_x1;
            s->tw_y1 = tw_y1;
            s->tw_wrap = (uint8_t)mega_digit(p[8]);
            s->tw_font_size = (uint8_t)mega_digit(p[9]);
            /* Initialize cursor to top-left of text window (scaled) */
            s->tw_cur_x = s->tw_x0;
            s->tw_cur_y = scale_y(s->tw_y0);
            /* A text window SMALLER than the full screen activates RIPlib's
             * own text renderer (rip_tw_putchar → draw_text, honouring
             * tw_wrap and tw_font_size).  A full-screen rect is treated as
             * "no special window", so subsequent text falls through to the
             * host VT100/ANSI path (comp_passthrough_vt100) — the normal
             * terminal flow.  NOTE: these are DIFFERENT render paths, not
             * "the same renderer": comp_passthrough_vt100 is a host callback
             * (inert in the standalone build), while rip_tw_putchar renders
             * glyphs into the framebuffer.  Consequence: in a build with no
             * host compositor, a BBS that sets a *full-screen* RIP text
             * window and then sends text produces no visible glyphs.  This
             * heuristic is intentional (full-screen = terminal default) but
             * ambiguous for streams that expect graphics-mode rendering of a
             * full-screen window. */
            s->tw_active = (s->tw_x0 != 0 || s->tw_y0 != 0 ||
                            s->tw_x1 != 639 || s->tw_y1 != 349);
        }
        break;
    case 'v': /* RIP_VIEWPORT
               *
               * Refuses when the CURRENT port is protected, per slot 62's
               * query at 0x10033821: index -1 means "the current entry", and
               * it tests the protected bit at +0x17 of a 0x78-stride table.
               * The diagnostic is "Port can't be modified - it's protected!".
               *
               * This guard was held back until port PERMANENCE was separated
               * from port PROTECTION.  RIPlib marked port 0 PROTECTED, and
               * all three '|v' commands in IMAGES.RIP run with port 0 active
               * -- so guarding on the old flag would have refused content the
               * driver renders, and nothing would have caught it, since
               * protection is inert until content opts in. */
        /* One line, deliberately.  dll-conformance.py reads a handler body
         * only as far as a bare `break;` on its own line, so writing this
         * guard across two lines hid the `len >= 8` gate below it from the
         * gate check -- a guard I added silently reduced a checker's
         * coverage.  Every other protection guard in this file is one line
         * for the same reason. */
        if (s->ports[s->active_port].flags & RIP_PORT_FLAG_PROTECTED) break;
        if (len >= 8) {
            int16_t vx0 = mega2(p), vy0 = mega2(p + 2);
            int16_t vx1 = mega2(p + 4), vy1 = mega2(p + 6);
            clamp_ega_rect(&vx0, &vy0, &vx1, &vy1);
            set_session_viewport(s, vx0, scale_y(vy0),
                                    vx1, scale_y1(vy1));
        }
        break;

    /* ── Palette ─────────────────────────────────────────────── */
    case 'Q': /* RIP_SET_PALETTE — 16 entries, values are EGA 64-color indices.
               * EGA indices map to framebuffer values 240-255 (see rip_init_first). */
        if (RIP_PALETTE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 32) {
            for (int i = 0; i < 16; i++) {
                uint8_t ega64 = mega2(p + i * 2) & 0x3F;
                palette_write_rgb565(palette_slot(i), ega64_to_rgb565(ega64));
            }
        }
        break;
    case 'a': /* RIP_ONE_PALETTE — set one entry to EGA 64-color index
               *
               * The handler (RVA 0x019BF0) validates the colour with
               * cmp ebx,0x3F / jbe and reports "Invalid Color Parameter"
               * otherwise -- it REJECTS the command rather than clamping.
               * RIPlib masked with & 0x3F, which silently folds 64 onto 0
               * and paints the wrong colour instead of doing nothing.
               *
               * That is the same choice already made for '|d' ("out-of-range
               * values are an error, not something to clamp into a wrong
               * colour") and for '|q' font attributes; '|a' was the one place
               * still masking.  Every '|a' in the corpus is in range -- the
               * values used are 2, 9, 20, 52, 54, 59 and 61 -- so nothing
               * shipped depends on the fold.  D-21. */
        if (RIP_PALETTE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 4) {
            uint16_t idx = (uint16_t)mega2(p);
            uint16_t ega64 = (uint16_t)mega2(p + 2);
            if (ega64 <= 63)
                palette_write_rgb565(palette_slot(idx & 0x0F),
                                     ega64_to_rgb565((uint8_t)ega64));
        }
        break;

    /* ── Line ────────────────────────────────────────────────── */
    case 'L': /* RIP_LINE -- x0:XY y0:XY x1:XY y1:XY
               *
               * The signature line above is not decoration: without one,
               * ref-compare.py cannot extract this command and cannot
               * compare it against the record.  '|L' is the most-used
               * command in the shipped corpus -- 7565 occurrences -- and
               * was invisible to that comparison until 2026-08-15, exactly
               * as '|1<ESC>' was.  It describes what the CODE READS, which
               * is the only way the comparison means anything; copying the
               * record here would make it agree with itself. */
        if (len >= 8) {
            int16_t x0 = mega2(p), y0 = scale_y(mega2(p + 2));
            int16_t x1 = mega2(p + 4), y1 = scale_y(mega2(p + 6));
            if (s->line_thick > 1)
                draw_thick_line(x0, y0, x1, y1);
            else
                draw_line(x0, y0, x1, y1);
        }
        break;

    /* ── Rectangle ───────────────────────────────────────────── */
    case 'R': /* RIP_RECTANGLE -- x0:XY y0:XY x1:XY y1:XY (outline) */
        if (len >= 8) {
            int16_t x0 = mega2(p), y0 = scale_y(mega2(p + 2));
            int16_t x1 = mega2(p + 4), y1 = scale_y1(mega2(p + 6));
            draw_rect(x0, y0,
                      (int16_t)(x1 - x0 + 1),
                      (int16_t)(y1 - y0 + 1), false);
        }
        break;
    case 'B': /* RIP_BAR -- x0:XY y0:XY x1:XY y1:XY (filled, no border) */
        if (len >= 8) {
            int16_t x0 = mega2(p), y0 = scale_y(mega2(p + 2));
            int16_t x1 = mega2(p + 4), y1 = scale_y1(mega2(p + 6));
            /* Fill pattern 00 is NOT "no fill".  The 1.54 specification is
             * explicit: "Fill pattern 00 will set the entire fill area to the
             * background color."  RIPlib skipped the fill entirely until
             * 2026-08-12 (B9), so `!|S0000|` + a bar — the idiom a scene uses
             * to blank a region — did nothing.
             *
             * Scope note: this is corrected for the BAR, which is the
             * corpus's blanking primitive.  The polygon case is deliberately
             * left as-is: implementations genuinely disagree there (SyncTERM's
             * scanline polygon filler also skips style 0 while its bars and
             * floods paint colour 0), so changing it would be a guess. */
            if (s->fill_pattern == 0) {
                draw_set_fill_style(0, s->palette[s->back_color & 0x0F]);
                draw_set_color(s->palette[s->back_color & 0x0F]);
            } else {
                draw_set_color(s->palette[s->fill_color & 0x0F]);
            }
            draw_rect(x0, y0,
                      (int16_t)(x1 - x0 + 1),
                      (int16_t)(y1 - y0 + 1), true);
            draw_set_color(s->palette[s->draw_color & 0x0F]);
            if (s->fill_pattern == 0)
                apply_session_draw_state(s);   /* restore the session fill style */
        }
        break;

    /* ── Circle ──────────────────────────────────────────────── */
    case 'C': /* RIP_CIRCLE */
        if (len >= 6) {
            draw_circle(mega2(p), scale_y(mega2(p + 2)),
                        scale_y(mega2(p + 4)), false);
        }
        break;

    /* ── Ellipse ─────────────────────────────────────────────── */
    case 'O': /* v1.54 spec: '|O' = RIP_OVAL — elliptical arc from st_ang to end_ang.
               * Args: cx:2 cy:2 st_ang:2 end_ang:2 x_rad:2 y_rad:2 (6 params, 12 chars).
               * IcyTerm: Oval { x, y, st_ang, end_ang, x_rad, y_rad } — parse_params.rs line 277.
               * Note: previous code had O/o swapped, mapping O to filled-oval (wrong). */
        /* fall through — 'O' and 'V' share an implementation */
    case 'V': /* RIP_OVAL_ARC — same field layout and renderer as 'O'. */
        if (len >= 12) {
            int16_t cx = mega2(p), cy = scale_y(mega2(p + 2));
            int16_t sa = mega2(p + 4), ea = mega2(p + 6);
            int16_t rx = mega2(p + 8), ry = scale_y(mega2(p + 10));
            draw_elliptical_arc(cx, cy, rx, ry, sa, ea);
        }
        break;
    case 'o': /* RIP_FILLED_OVAL -- cx:XY cy:XY x_rad:XY y_rad:XY
               *
               * Filled ellipse, full 360 degrees; no angle arguments.
               * Args: cx:2 cy:2 x_rad:2 y_rad:2 (4 params, 8 chars). No angle args.
               * IcyTerm: FilledOval { x, y, x_rad, y_rad } — parse_params.rs line 248.
               * Note: previous code had O/o swapped, mapping o to oval-arc (wrong). */
        if (len >= 8) {
            int16_t cx = mega2(p), cy = scale_y(mega2(p + 2));
            int16_t rx = mega2(p + 4), ry_s = scale_y(mega2(p + 6));
            uint8_t border_mode;
            if (s->fill_pattern != 0) {
                draw_set_color(s->palette[s->fill_color & 0x0F]);
                draw_ellipse(cx, cy, rx, ry_s, true);
            }
            if (rip_begin_filled_border(s, &border_mode)) {
                draw_ellipse(cx, cy, rx, ry_s, false);
                rip_end_filled_border(s, border_mode);
            } else {
                draw_set_color(s->palette[s->draw_color & 0x0F]);
            }
        }
        break;

    /* ── Arc ──────────────────────────────────────────────────── */
    case 'A': /* RIP_ARC — DLL scales radius via ripScaleCoordY (EGA 350→400) */
        if (len >= 10) {
            int16_t cx = mega2(p), cy = scale_y(mega2(p + 2));
            int16_t sa = mega2(p + 4), ea = mega2(p + 6);
            int16_t r = scale_y(mega2(p + 8));
            draw_arc(cx, cy, r, sa, ea);
        }
        break;
    /* 'V' was previously a duplicate handler for RIP_OVAL_ARC.
     * Merged with 'O' above via case fall-through. */

    /* ── Pie slices ──────────────────────────────────────────── */
    case 'I': /* RIP_PIE_SLICE — outline in draw_color, fill in fill_color.
               * DLL scales radius via ripScaleCoordY (EGA 350→400).
               *
               * Order matters: draw_pie(fill=true) paints the sector with
               * g_color over the arc/radii it drew first, so we must fill
               * before outlining or the outline gets wiped.  The optional
               * outline is controlled by RIP_SET_BORDER and drawn in COPY. */
        if (len >= 10) {
            int16_t cx = mega2(p), cy = scale_y(mega2(p + 2));
            int16_t sa = mega2(p + 4), ea = mega2(p + 6);
            int16_t r  = scale_y(mega2(p + 8));
            uint8_t border_mode;
            if (s->fill_pattern != 0) {
                draw_set_color(s->palette[s->fill_color & 0x0F]);
                draw_pie(cx, cy, r, sa, ea, true);
            }
            if (rip_begin_filled_border(s, &border_mode)) {
                draw_pie(cx, cy, r, sa, ea, false);
                rip_end_filled_border(s, border_mode);
            } else {
                draw_set_color(s->palette[s->draw_color & 0x0F]);
            }
        }
        break;
    case 'i': /* RIP_OVAL_PIE_SLICE — fill before outline (see 'I' comment). */
        if (len >= 12) {
            int16_t cx = mega2(p), cy = scale_y(mega2(p + 2));
            int16_t sa = mega2(p + 4), ea = mega2(p + 6);
            int16_t rx = mega2(p + 8), ry_s = scale_y(mega2(p + 10));
            uint8_t border_mode;
            if (s->fill_pattern != 0) {
                draw_set_color(s->palette[s->fill_color & 0x0F]);
                draw_elliptical_pie(cx, cy, rx, ry_s, sa, ea, true);
            }
            if (rip_begin_filled_border(s, &border_mode)) {
                draw_elliptical_pie(cx, cy, rx, ry_s, sa, ea, false);
                rip_end_filled_border(s, border_mode);
            } else {
                draw_set_color(s->palette[s->draw_color & 0x0F]);
            }
        }
        break;

    /* ── Bezier ──────────────────────────────────────────────── */
    case 'Z': /* RIP_BEZIER — x0:2 y0:2 x1:2 y1:2 x2:2 y2:2 x3:2 y3:2 steps:2
               * DLL command table (ripscrip_text.asm): 9 args. The 9th argument
               * (steps) is a curve quality / subdivision depth hint. draw_bezier()
               * uses a fixed subdivision depth internally; we read steps here so
               * the parser correctly consumes the full 18-char parameter field.
               * If draw_bezier is later extended to accept a step count, pass it. */
        if (len >= 18) {
            /* steps available at p+16 when len >= 18; reserved for future use */
            /* int steps = (len >= 18) ? mega2(p + 16) : 8; */
            draw_bezier(
                mega2(p),      scale_y(mega2(p + 2)),
                mega2(p + 4),  scale_y(mega2(p + 6)),
                mega2(p + 8),  scale_y(mega2(p + 10)),
                mega2(p + 12), scale_y(mega2(p + 14)));
        }
        break;

    /* ── Polygon / Polyline ──────────────────────────────────── */
    case 'P': /* RIP_POLYGON (outline) */
    case 'p': /* RIP_FILL_POLYGON */
    case 'l': /* RIP_POLYLINE */
        rip_exec_polygon(s, s->cmd_char, p, len);
        break;

    /* ── Flood fill ──────────────────────────────────────────── */
    case 'F': /* v1.54 spec: '|F' = RIP_FILL — flood fill from (x,y) until hitting border color.
               * Args: x:2 y:2 border:2 (3 params, 6 chars).
               * IcyTerm: Fill { x, y, border } — command.rs line 190, parse_params.rs line 245
               *   (0, b'F') → parse_base36_complete(..., 5) = 6 digits = 3 two-digit params.
               * Previous "Fix B3" used 0 args flooding at draw cursor (DLL internal behavior,
               * not the wire protocol). Spec and IcyTerm both confirm 3 args. */
        if (len >= 6) {
            int16_t fx = mega2(p), fy = scale_y(mega2(p + 2));
            int16_t border_idx = mega2(p + 4) & 0x0F;
            draw_set_color(s->palette[s->fill_color & 0x0F]);
            draw_flood_fill(fx, fy, s->palette[border_idx]);
            draw_set_color(s->palette[s->draw_color & 0x0F]);
        }
        break;

    /* ── Text ────────────────────────────────────────────────── */
    case 'T': /* RIP_TEXT — draw text at current position, advance draw_x */
        if (len > 0)
            rip_render_text(s, p, len);
        break;
    /* '@' = RIP_TEXT_XY.  Slot 16 records XY, XY and the handler (RVA
     * 0x020CBC) names itself RIP_TextXY(); its text is the out-of-band
     * string tail the record cannot express (D-16), which is why an
     * argc of 2 describes a command that plainly carries a string.
     *
     * A comment above the Line case used to assert that '@' was RIP_PIXEL
     * and that 'X' "is not in the DLL command table".  Both claims were
     * wrong -- 'X' is slot 70, and its handler calls GDI32!SetPixel -- and
     * the comment described a `case '@'` that was not beneath it.  The code
     * was right throughout; only the note was wrong.  D-27. */
    case '@': /* RIP_TEXT_XY — x:XY y:XY text */
        if (len >= 4) {
            s->draw_x = mega2(p);
            s->draw_y = scale_y(mega2(p + 2));
            rip_render_text(s, p + 4, len - 4);
        }
        break;
    /* 'X' = RIP_PIXEL.  Slot 70 records XY, XY and its handler (RVA
     * 0x01E1D1) calls GDI32!SetPixel, so the letter is confirmed from the
     * driver and not only from the 1.54 specification.  D-27. */
    case 'X': /* RIP_PIXEL — x:XY y:XY */
        if (len >= 4) {
            draw_pixel(mega2(p), scale_y(mega2(p + 2)));
        }
        break;
    /* v1.54 spec: 't' = RIP_REGION_TEXT — display a line of text in a
     * previously defined text region (Level 0, used with 'T' begin/end).
     * L16: also missed $variable expansion before this fix. */
    case 't': /* RIP_POLY_BEZIER_LINE — the third member of the bezier family.
               *
               * CORRECTED 2026-08-12 (B8).  RIPlib had RIP_REGION_TEXT here.
               * The driver's '|t' handler (RVA 0x01E4A4) sits adjacent to
               * '|z' (0x01E449) with a structurally identical body — same
               * call sequence, plus a write-mode apply — and carries the same
               * three argument signatures as '|x' and '|z'.  It is a drawing
               * command, not a text command.
               *
               * Region text is '|1t' (Level 1), which RIPlib already
               * implements, so nothing is lost by correcting this letter. */
        rip_poly_bezier_family(s, p, len, 0);
        break;

    /* ── Fill style + custom fill pattern ───────────────────── */
    case 's': /* RIP_FILL_PATTERN -- c1:2 c2:2 c3:2 c4:2 c5:2 c6:2 c7:2 c8:2 col:CM
               *
               * Custom 8x8 fill pattern plus colour; 9 params, 18 chars.
               * Signature first so ref-compare.py can read it -- the list
               * was already here, one line lower, where the extractor stops
               * at the preceding sentence break and never saw it.
               * IcyTerm: FillPattern { c1..c8, col } — parse_params.rs line 323:
               *   (0, b's') → parse_base36_complete(..., 17) = 18 digits = 9 two-digit params.
               * 's' is strictly this command; dual-dispatch by len was wrong. */
        if (RIP_STYLE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 18) {
            uint8_t pat[8];
            for (int i = 0; i < 8; i++)
                pat[i] = (uint8_t)mega2(p + i * 2);
            draw_set_user_fill_pattern(pat);
            s->fill_color = mega2(p + 16) & 0x0F;
            s->fill_pattern = 12; /* BGI USER_FILL */
            draw_set_fill_style(11, s->palette[s->back_color]);
        }
        break;

    /* ── Scene control ───────────────────────────────────────── */
    case '#': /* v1.54 spec §3.4: '|#' = RIP_NO_MORE — end of RIPscrip scene.
               * IcyTerm: NoMore (0 args). BBS sends 3+ consecutive '#' commands for noise immunity.
               * Note: previous code had '#' as EraseWindow and '>' as NoMore — both wrong.
               * Correct mapping confirmed by v1.54 spec and IcyTerm command.rs:NoMore → "|#". */
        /* Scene terminator; mouse regions already activated incrementally.
         * Defensively close any open text block so a malformed stream that
         * omits '|1E' before '|#' cannot bleed stale text into the next
         * scene's '|t'/'|1t' (REGION_TEXT) commands.  Well-formed streams
         * send '|1E' first, so this is a no-op for them.  ('|#' is only a
         * scene-boundary marker — full state reset remains '|*'.) */
        s->text_block.active = false;
        break;

    /* §A2G (v3.2): state push/pop — backward-compatible QoL extension. */
    case '^': /* RIP_PUSH_STATE — snapshot drawing/cursor/viewport state.
               * Stack is bounded to RIP_STATE_STACK_MAX frames; overflow
               * silently drops the push (matches the "ignore unknown
               * params" precedent for graceful degradation). */
        if (s->state_stack_depth < RIP_STATE_STACK_MAX) {
            uint8_t i = s->state_stack_depth;
            s->state_stack[i].draw_color   = s->draw_color;
            s->state_stack[i].back_color   = s->back_color;
            s->state_stack[i].fill_color   = s->fill_color;
            s->state_stack[i].fill_pattern = s->fill_pattern;
            s->state_stack[i].line_style   = s->line_style;
            s->state_stack[i].line_pattern = s->line_pattern;
            s->state_stack[i].line_thick   = s->line_thick;
            s->state_stack[i].write_mode   = s->write_mode;
            s->state_stack[i].font_id      = s->font_id;
            s->state_stack[i].font_size    = s->font_size;
            s->state_stack[i].font_dir     = s->font_dir;
            s->state_stack[i].font_attrib  = s->font_attrib;
            s->state_stack[i].font_hjust   = s->font_hjust;
            s->state_stack[i].font_vjust   = s->font_vjust;
            s->state_stack[i].font_ext_id  = s->font_ext_id;
            s->state_stack[i].font_ext_attr = s->font_ext_attr;
            s->state_stack[i].font_ext_size = s->font_ext_size;
            s->state_stack[i].filled_borders_enabled = s->filled_borders_enabled;
            s->state_stack[i].draw_x       = s->draw_x;
            s->state_stack[i].draw_y       = s->draw_y;
            s->state_stack[i].vp_x0        = s->vp_x0;
            s->state_stack[i].vp_y0        = s->vp_y0;
            s->state_stack[i].vp_x1        = s->vp_x1;
            s->state_stack[i].vp_y1        = s->vp_y1;
            s->state_stack_depth++;
        }
        break;

    case '~': /* RIP_POP_STATE — restore the most recently pushed state.
               * Pop on empty stack is a no-op (also matches the
               * graceful-degradation precedent). */
        if (s->state_stack_depth > 0) {
            uint8_t i = (uint8_t)(--s->state_stack_depth);
            s->draw_color   = s->state_stack[i].draw_color;
            s->back_color   = s->state_stack[i].back_color;
            s->fill_color   = s->state_stack[i].fill_color;
            s->fill_pattern = s->state_stack[i].fill_pattern;
            s->line_style   = s->state_stack[i].line_style;
            s->line_pattern = s->state_stack[i].line_pattern;
            s->line_thick   = s->state_stack[i].line_thick;
            s->write_mode   = s->state_stack[i].write_mode;
            s->font_id      = s->state_stack[i].font_id;
            s->font_size    = s->state_stack[i].font_size;
            s->font_dir     = s->state_stack[i].font_dir;
            s->font_attrib  = s->state_stack[i].font_attrib;
            s->font_hjust   = s->state_stack[i].font_hjust;
            s->font_vjust   = s->state_stack[i].font_vjust;
            s->font_ext_id  = s->state_stack[i].font_ext_id;
            s->font_ext_attr = s->state_stack[i].font_ext_attr;
            s->font_ext_size = s->state_stack[i].font_ext_size;
            s->filled_borders_enabled = s->state_stack[i].filled_borders_enabled;
            s->draw_x       = s->state_stack[i].draw_x;
            s->draw_y       = s->state_stack[i].draw_y;
            s->vp_x0        = s->state_stack[i].vp_x0;
            s->vp_y0        = s->state_stack[i].vp_y0;
            s->vp_x1        = s->state_stack[i].vp_x1;
            s->vp_y1        = s->state_stack[i].vp_y1;
            /* Apply restored draw state immediately so subsequent draws
             * pick up the popped color, write mode, line, fill, cursor,
             * and viewport state. */
            apply_session_draw_state(s);
        }
        break;

    /* ── E1: Undocumented command stubs ─────────────────────────
     * These command letters appear in the DLL command-letter accept
     * table (ripscrip_text.asm).  Recognising them prevents
     * ERROR_RECOVERY from consuming the rest of the frame when a
     * BBS sends one of these commands.  Full implementation deferred.
     * ─────────────────────────────────────────────────────────── */
    /* -- Filled circle (v2.0+) ----------------------------------------- */
    /* DLL command table entry 29: 'G' = RIP_FILLED_CIRCLE (3 args: XY,XY,XY) */
    case 'G': /* RIP_FILLED_CIRCLE -- cx:2 cy:2 radius:2.
               * DLL scales radius via ripScaleCoordY (EGA 350→400). */
        if (len >= 6) {
            int16_t cx = mega2(p), cy = scale_y(mega2(p + 2));
            int16_t r = scale_y(mega2(p + 4));
            uint8_t border_mode;
            if (s->fill_pattern != 0) {
                draw_set_color(s->palette[s->fill_color & 0x0F]);
                draw_circle(cx, cy, r, true);
            }
            if (rip_begin_filled_border(s, &border_mode)) {
                draw_circle(cx, cy, r, false);
                rip_end_filled_border(s, border_mode);
            } else {
                draw_set_color(s->palette[s->draw_color & 0x0F]);
            }
        }
        break;

    /* -- Rounded rectangle (v2.0+) --------------------------------------- */
    /* DLL command table entry 64: 'U' = RIP_ROUNDED_RECT (5 args: XY,XY,XY,XY,XY) */
    case 'U': /* RIP_ROUNDED_RECT -- x0:2 y0:2 x1:2 y1:2 radius:2 */
        if (len >= 10) {
            int16_t x0 = mega2(p),      y0 = scale_y(mega2(p + 2));
            int16_t x1 = mega2(p + 4),  y1 = scale_y1(mega2(p + 6));
            int16_t r  = scale_y(mega2(p + 8));
            draw_rounded_rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1, r, false);
        }
        break;

    /* DLL command table entry 65: 'u' = RIP_FILLED_ROUNDED_RECT (5 args: XY,XY,XY,XY,XY) */
    case 'u': /* RIP_FILLED_ROUNDED_RECT -- x0:2 y0:2 x1:2 y1:2 radius:2 */
        if (len >= 10) {
            int16_t x0 = mega2(p),      y0 = scale_y(mega2(p + 2));
            int16_t x1 = mega2(p + 4),  y1 = scale_y1(mega2(p + 6));
            int16_t r  = scale_y(mega2(p + 8));
            uint8_t border_mode;
            if (s->fill_pattern != 0) {
                draw_set_color(s->palette[s->fill_color & 0x0F]);
                draw_rounded_rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1, r, true);
            }
            if (rip_begin_filled_border(s, &border_mode)) {
                draw_rounded_rect(x0, y0, x1 - x0 + 1, y1 - y0 + 1, r, false);
                rip_end_filled_border(s, border_mode);
            } else {
                draw_set_color(s->palette[s->draw_color & 0x0F]);
            }
        }
        break;

    /* -- Background color (v2.0+) ---------------------------------------- */
    /* DLL command table entry 43: 'k' = RIP_BACK_COLOR (1 arg: COL) */
    /* Dispatch slot 43, argc 1, type 0xFE -- a COLOUR argument, whose width
     * comes from '|M' SET_COLOR_MODE and is 2 by default.  RIPlib read a
     * single digit, so '|k04' set background 0 instead of 4 and '|k3K' set
     * 3 instead of 128; 132 uses across 22 shipped scenes were affected.
     * bbs-land documents this correctly as `color:CM`. */
    case 'k': /* RIP_BACK_COLOR -- color:CM (2 digits at the default mode).
               * Per BGI/RIP semantics, back_color is the OFF-bit color in
               * patterned fills and the clear color for RIP_ERASE_VIEW.
               * Push the new value into the draw layer so subsequent fills
               * pick it up without waiting for the next 'S'/'s'/'D'. */
        if (RIP_STYLE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 1) {
            /* Width-negotiated: the payload is normalised to 2 digits before
             * dispatch when '|M' has selected anything else (D-11).
             *
             * The single-digit fallback is a DELIBERATE tolerance, not an
             * oversight, and was briefly removed before the corpus corrected
             * the assumption: of 133 '|k' commands in shipped scenes, 132 are
             * two characters and one (N2_BUSI.RIP, "|k0") is one.  Rejecting
             * the short form to match the record exactly would drop a command
             * real content sends, for no gain -- the defect that mattered was
             * reading ONE digit when TWO were present, which is fixed.  D-18. */
            s->back_color = (uint8_t)((len >= 2 ? mega2(p) : mega_digit(p[0])) & 0x0F);
            int8_t card_pat = bgi_fill_to_card(s->fill_pattern);
            draw_set_fill_style((card_pat >= 0) ? (uint8_t)card_pat : 0,
                                s->palette[s->back_color & 0x0F]);
        }
        break;

    /* -- Save icon (v2.0+) ----------------------------------------------- */
    /* DLL command table entry 40: 'J' = RIP_SAVE_ICON (1 arg: 2-digit slot) */
    /* Dispatch slot 40 (RVA 0x01f32e), argc 1, mega2.  The handler names
     * itself RIP_SetBaseMath and accepts exactly two values -- 0x24 (36)
     * and 0x40 (64) -- forcing 36 for anything else, then stores the byte
     * in engine state.  It selects the MegaNum radix for everything after
     * it, which is why it appears near the top of most real scenes.
     *
     * RIPlib records the value and reproduces the driver's validation, but
     * its decoders stay base 36: the base-64 DIGIT ALPHABET has not been
     * recovered ('0'-'9' 'A'-'Z' 'a'-'z' is 62 symbols and the remaining
     * two are unknown), and guessing it would corrupt every numeric field
     * on a base-64 stream.  All 24 uses in TeleGrafix's shipped corpus are
     * '|J10' -- base 36 -- so no real content is affected.  See D-10.
     *
     * This letter previously ran a clipboard slot save, which had no basis
     * in the dispatch table and consumed a slot on each of those 24 uses. */
    case 'J': /* RIP_SET_BASE_MATH -- base:2, accepts 36 or 64 */
        if (RIP_ENV_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 2) {
            int16_t base = mega2(p);
            s->mega_base = (uint8_t)((base == 36 || base == 64) ? base : 36);
        }
        break;

    /* -- Skewed-oval family (v2.0+) ---------------------------------------
     * Six letters share one geometry generator in the driver (RVA 0x010160);
     * see rip_draw_skewed_oval().  Command identities and argument layouts
     * come from TeleGrafix's own commented demo ICONS/NEWCMDS.RIP, which
     * draws a coordinate grid and places each shape on an intersection,
     * corroborated by the dispatch table's arities and argument-type bytes.
     * See docs/spec/12-dll-provenance.md section 12.14. */

    /* Dispatch slot 7, argc 7: XY, XY, XY, XY, mega2, mega2, mega2. */
    case '+': /* RIP_SKEWED_OVAL_CHORD -- cx:2 cy:2 rx:2 ry:2 start:2 end:2 skew:2 */
        if (len >= 14) {
            int16_t cx = mega2(p),      cy = scale_y(mega2(p + 2));
            int16_t rx = mega2(p + 4),  ry = scale_y(mega2(p + 6));
            int16_t sa = mega2(p + 8),  ea = mega2(p + 10);
            int16_t sk = mega2(p + 12);
            rip_draw_skewed_oval(s, cx, cy, rx, ry, sk, sa, ea,
                                 RIP_OVAL_CLOSED, true);
        }
        break;

    /* -- Copy region (v2.0+) --------------------------------------------- */
    /* DLL command table entry 8: ',' = RIP_COPY_REGION (10 args: XY*10) */
    case ',': /* RIP_COPY_REGION -- sx0:XY sy0:XY sx1:XY sy1:XY dx:XY dy:XY
               *                   dx1:XY dy1:XY p4x:XY p4y:XY
               *
               * The trailing pair is NOT reserved.  Slot 8 (RVA 0x01D5C2)
               * loads all ten arguments and passes FIVE pairs through the
               * coordinate transform at 0x10031084 -- (a0,a1) (a2,a3)
               * (a4,a5) (a6,a7) and (a8,a9) -- so the driver treats the
               * last two as a coordinate pair like the rest, not as
               * padding.  This comment called them 'res:2 res:2'.
               *
               * WHAT they mean is NOT established.  Five pairs for a
               * region copy could be source rect, destination rect and an
               * anchor, but that is a guess and guessing is what
               * 14-divergence-register.md exists to prevent.  Recorded
               * rather than invented; no shipped scene sends '|,' at all,
               * so nothing observable depends on it today.  See 14.7. */
        if (len >= 20) {
            int16_t sx0 = mega2(p),      sy0 = scale_y(mega2(p + 2));
            int16_t sx1 = mega2(p + 4),  sy1 = scale_y1(mega2(p + 6));
            int16_t dx0 = mega2(p + 8),  dy0 = scale_y(mega2(p + 10));
            int16_t rw  = sx1 - sx0 + 1, rh  = sy1 - sy0 + 1;
            int16_t dw = rw, dh = rh;
            if (len >= 16) {
                int16_t dx1 = mega2(p + 12);
                int16_t dy1 = scale_y1(mega2(p + 14));
                if (!(dx1 == 0 && dy1 == 0)) {
                    if (dx0 > dx1) { int16_t t = dx0; dx0 = dx1; dx1 = t; }
                    if (dy0 > dy1) { int16_t t = dy0; dy0 = dy1; dy1 = t; }
                    dw = (int16_t)(dx1 - dx0 + 1);
                    dh = (int16_t)(dy1 - dy0 + 1);
                }
            }
            rip_copy_screen_region_scaled(s, sx0, sy0, rw, rh,
                                          dx0, dy0, dw, dh, DRAW_MODE_COPY);
        }
        break;

    /* Dispatch slot 9, argc 5: XY, XY, XY, XY, mega2.  The handler at RVA
     * 0x01c348 is instruction-for-instruction identical to '&' at 0x01f904
     * apart from frame size -- the filled/outline pair of one shape. */
    case '-': /* RIP_FILLED_SKEWED_OVAL -- cx:2 cy:2 rx:2 ry:2 skew:2 */
        if (len >= 10) {
            int16_t cx = mega2(p),     cy = scale_y(mega2(p + 2));
            int16_t rx = mega2(p + 4), ry = scale_y(mega2(p + 6));
            int16_t sk = mega2(p + 8);
            rip_draw_skewed_oval(s, cx, cy, rx, ry, sk, 0, 360,
                                 RIP_OVAL_CLOSED, true);
        }
        break;

    /* -- Header (v2.0+) -------------------------------------------------- */
    /* DLL command table entry 32: 'h' = RIP_HEADER (3 args: 2,4,2) */
    case 'h': /* RIP_HEADER — six accepted signatures, selected by length.
               *
               * D-2, 2026-08-12.  The driver's '|h' carries SIX dispatch
               * entries on one handler (RVA 0x01CAE1), the most overloaded
               * command in the table:
               *
               *     8 chars  type:2 id:4 flags:2      (RIPlib's original)
               *     8 chars  a:1 id:4 b:1 c:1 d:1     (ambiguous with above)
               *     6 chars  a:1 id:4 b:1
               *     4 chars  a:1 id:2 b:1
               *     3 chars  a:1 id:2                 (two entries, identical)
               *
               * Reading a 4- or 6-character header with the 8-character layout
               * pulls fields from past the end of the parameters, so the id
               * and flags came out as noise.  Each length now reads its own
               * layout.  The two 8-char forms and the two 3-char forms are not
               * separable by length alone; the driver must select between them
               * on state we have not recovered, so the first (documented) form
               * is kept for those and the ambiguity is recorded rather than
               * guessed — see docs/spec §12.12. */
        /* Base 64: '|h' carries flag value 2 in its dispatch entry, the same
         * as '|d', '|D' and '|y' -- see D-12.  No shipped scene uses '|h',
         * so this is unverified against real content, but decoding it with
         * the base-36 helpers would contradict the table for no reason. */
        if (len >= 8) {
            s->header_type  = (uint8_t)(mega2_64(p) & 0xFF);
            s->header_id    = (uint32_t)mega4_64(p + 2);
            s->header_flags = (uint8_t)(mega2_64(p + 6) & 0xFF);
            s->filled_borders_enabled = true;
        } else if (len == 6) {
            s->header_type  = (uint8_t)mega_digit64(p[0]);
            s->header_id    = (uint32_t)mega4_64(p + 1);
            s->header_flags = (uint8_t)mega_digit64(p[5]);
            s->filled_borders_enabled = true;
        } else if (len == 4) {
            s->header_type  = (uint8_t)mega_digit64(p[0]);
            s->header_id    = (uint32_t)mega2_64(p + 1);
            s->header_flags = (uint8_t)mega_digit64(p[3]);
            s->filled_borders_enabled = true;
        } else if (len == 3) {
            s->header_type  = (uint8_t)mega_digit64(p[0]);
            s->header_id    = (uint32_t)mega2_64(p + 1);
            s->filled_borders_enabled = true;
        }
        break;

    /* -- Coordinate size (v2.0+) ----------------------------------------- */
    /* DLL command table entry 49: 'n' = RIP_SET_COORDINATE_SIZE (2 args: 1,3) */
    case 'n': /* RIP_SET_COORDINATE_SIZE -- byte_size:1 res:3
               *
               * This field is the width of every argument the dispatch table
               * types 0xFF.  The driver resolves it at RVA 0x039DE0:
               *
               *     t = argtype[i]
               *     t >= 0    -> t                    literal digit count
               *     t == 0xFF -> (state+2)->[0x39]    this field
               *     t == 0xFE -> (state+2)->[0x3a]    colour mode, 2 or 4
               *
               * RIPlib's decoders are fixed at 2 digits (rip_meganum.h keeps
               * them stateless static inlines), so any width but 2 would be
               * mis-read from the first coordinate onward.  Rather than
               * mis-parse silently, an unsupported width is recorded: a host
               * can check coord_size_unsupported and stop rather than render
               * garbage.  All 24 uses of '|n' in TeleGrafix's shipped corpus
               * request 2, so no real content trips this.  See D-11. */
        if (RIP_ENV_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 4) {
            uint8_t size = (uint8_t)mega_digit(p[0]);
            if (size >= 2 && size <= 5) {
                s->coordinate_size = size;
                if (size != 2)
                    s->coord_size_unsupported = true;
            }
            s->coordinate_res = (uint32_t)mega3(p + 1);
        }
        break;

    /* -- Color mode (v2.0+) ---------------------------------------------- */
    /* DLL command table entry 46: 'M' = RIP_SET_COLOR_MODE (2 args: 1,1) */
    case 'M': /* RIP_SET_COLOR_MODE -- mode:1 bits:1 */
        if (RIP_ENV_PROTECTED(s)) break;   /* protected slot: driver refuses */
        /* mode=0: palette mapping. mode!=0: direct RGB with bits/component.
         * The card remains palette-backed, but mode tracking is observable
         * through $COLORMODE$ and future color-parameter handlers. */
        if (len >= 2) {
            uint8_t mode = (uint8_t)mega_digit(p[0]);
            uint8_t bits = (uint8_t)mega_digit(p[1]);
            s->color_mode = mode;
            if (mode == 0) {
                s->color_bits = 0;
            } else {
                if (bits < 1) bits = 1;
                if (bits > 8) bits = 8;
                s->color_bits = bits;
            }
        }
        break;

    /* -- Filled-object border control (v2.A3+) ---------------------------- */
    /* DLL command table entry 48: 'N' = RIP_SET_BORDER (1 arg: 2-digit) */
    case 'N': /* RIP_SET_BORDER -- borders:2, 00=off, nonzero=on */
        if (RIP_STYLE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 2)
            s->filled_borders_enabled = (mega2(p) != 0);
        break;

    /* -- Poly-Bezier (v2.0+) --------------------------------------------- */
    /* DLL command table entry 77: 'z' = RIP_POLY_BEZIER (nsegs:2 nsteps:2, then XY pairs) */
    case 'x': /* RIP_FILLED_POLY_BEZIER — filled.
               * Driver slot 71 (RVA 0x01BC1D), adjacent to RIP_FilledPolygon;
               * spec §11.2 Erratum 2 had the letters right ('x' filled,
               * 'z' unfilled).  All three driver signatures plus RIPlib's
               * long form go through the shared family helper (D-2). */
        rip_poly_bezier_family(s, p, len, 1);
        break;

    case 'z': /* RIP_POLY_BEZIER — outline.
               * All three driver signatures plus RIPlib's long form are
               * handled by the shared family helper; see D-2. */
        rip_poly_bezier_family(s, p, len, 2);
        break;

    /* -- Group markers (v2.0+) ------------------------------------------- */
    /* DLL command table entry 4/5: '(' / ')' RIP_GROUP_BEGIN / END.
     *
     * The wire protocol takes 0 args, so there is no group identifier we
     * could match against a client-side cache.  Real "skip if cached"
     * grouping in the original DLL was driven by an out-of-band header/
     * checksum table that RIPlib does not expose.  We therefore accept
     * the markers (so a stream that bracket-wraps frames doesn't fall
     * into ERROR_RECOVERY) and otherwise treat them as no-ops; every
     * group is rendered every time.  Wire-format compatible, no
     * bandwidth optimization. */
    case '(':
    case ')':
        break;

    /* -- Undocumented commands (confirmed in DLL binary) ----------------- */

    /* DLL command table entry 1: '"' = RIP_BOUNDED_TEXT (5 args: XY,XY,XY,XY,2 + text) */
    case '"': /* RIP_BOUNDED_TEXT -- x0:2 y0:2 x1:2 y1:2 flags:2 text */
        /* Renders text within a bounding rectangle with word-wrap.
         * DLL rejects the 8x8 bitmap font (no character metrics).
         * We use the active font and perform simple greedy word-wrap. */
        if (len >= 10) {
            int16_t bx0 = mega2(p),      by0 = scale_y(mega2(p + 2));
            int16_t bx1 = mega2(p + 4),  by1 = scale_y1(mega2(p + 6));
            const char *tp = p + 10;
            int tlen = len - 10;
            if (tlen > 0 && bx1 > bx0 && by1 > by0) {
                char tbuf[256];
                char vbuf[256];
                draw_clip_state_t saved_clip;
                int16_t cx0, cy0, cx1, cy1;
                int outlen = unescape_text(tp, tlen, tbuf, (int)sizeof(tbuf));
                outlen = rip_expand_variables(s, tbuf, outlen, vbuf, sizeof(vbuf));
                uint8_t tc = s->palette[s->draw_color & 0x0F];
                int char_w = 8, char_h = 16;
                int cur_x = bx0, cur_y = by0;
                int i = 0;
                draw_save_clip(&saved_clip);
                cx0 = bx0 > saved_clip.x0 ? bx0 : saved_clip.x0;
                cy0 = by0 > saved_clip.y0 ? by0 : saved_clip.y0;
                cx1 = bx1 < saved_clip.x1 ? bx1 : saved_clip.x1;
                cy1 = by1 < saved_clip.y1 ? by1 : saved_clip.y1;
                if (cx0 <= cx1 && cy0 <= cy1) {
                    draw_set_clip(cx0, cy0, cx1, cy1);
                    while (i < outlen && cur_y + char_h <= by1) {
                        int word_end = i;
                        while (word_end < outlen && vbuf[word_end] != ' ') word_end++;
                        int word_w = (word_end - i) * char_w;
                        if (cur_x + word_w > bx1 && cur_x > bx0) {
                            cur_x = bx0;
                            cur_y += char_h;
                            if (cur_y + char_h > by1) break;
                        }
                        draw_text(cur_x, cur_y, vbuf + i, word_end - i,
                                  cp437_8x16, char_h, tc, 0xFF);
                        cur_x += word_w;
                        i = word_end;
                        if (i < outlen && vbuf[i] == ' ') {
                            cur_x += char_w;
                            i++;
                        }
                    }
                }
                draw_restore_clip(&saved_clip);
            }
        }
        break;

    /* Dispatch slot 62, argc 7: XY, XY, XY, XY, mega2, mega2, mega2. */
    case '[': /* RIP_SKEWED_OVAL_PIE_SLICE -- cx:2 cy:2 rx:2 ry:2 start:2 end:2 skew:2 */
        if (len >= 14) {
            int16_t cx = mega2(p),      cy = scale_y(mega2(p + 2));
            int16_t rx = mega2(p + 4),  ry = scale_y(mega2(p + 6));
            int16_t sa = mega2(p + 8),  ea = mega2(p + 10);
            int16_t sk = mega2(p + 12);
            rip_draw_skewed_oval(s, cx, cy, rx, ry, sk, sa, ea,
                                 RIP_OVAL_PIE, true);
        }
        break;

    /* Dispatch slot 63, argc 7: XY, XY, XY, XY, mega2, mega2, mega2.
     * An arc is the open member of the family -- stroked, never filled. */
    case ']': /* RIP_SKEWED_OVAL_ARC -- cx:2 cy:2 rx:2 ry:2 start:2 end:2 skew:2 */
        if (len >= 14) {
            int16_t cx = mega2(p),      cy = scale_y(mega2(p + 2));
            int16_t rx = mega2(p + 4),  ry = scale_y(mega2(p + 6));
            int16_t sa = mega2(p + 8),  ea = mega2(p + 10);
            int16_t sk = mega2(p + 12);
            rip_draw_skewed_oval(s, cx, cy, rx, ry, sk, sa, ea,
                                 RIP_OVAL_OUTLINE, false);
        }
        break;

    /* Dispatch slot 95, argc 6: XY, XY, mega2, mega2, XY, XY.  The angles
     * sit in the middle here, matching the layout riplib already uses for
     * 'V' RIP_OVAL_ARC.  Not a skewed variant -- there is no skew field. */
    case '_': /* RIP_FILLED_OVAL_CHORD -- cx:2 cy:2 start:2 end:2 rx:2 ry:2 */
        if (len >= 12) {
            int16_t cx = mega2(p),     cy = scale_y(mega2(p + 2));
            int16_t sa = mega2(p + 4), ea = mega2(p + 6);
            int16_t rx = mega2(p + 8), ry = scale_y(mega2(p + 10));
            rip_draw_skewed_oval(s, cx, cy, rx, ry, 0, sa, ea,
                                 RIP_OVAL_CLOSED, true);
        }
        break;

    /* DLL binary: 0x60 (backtick) = RIP_COMPOSITE_ICON (11 args: XY x 10, 1) */
    case 0x60: /* RIP_COMPOSITE_ICON -- 5 src/dst rect pairs (XY x 10) + mode:1 */
        /* Multi-region screen compositing: 5 rect pairs blit source regions
         * to destination regions using the specified raster op.  Historical
         * docs disagree on whether later entries are 12-byte rect records or
         * 8-byte point pairs; accept complete rect records and use the first
         * rect size for trailing point pairs. */
        if (len >= 12) {
            int offset = 0;
            int pairs = 0;
            int mode_pos = (len >= 41) ? 40 : len;
            uint8_t mode = (len >= 41) ? (uint8_t)mega_digit(p[40])
                                       : s->write_mode;
            int16_t cx0 = mega2(p),      cy0 = scale_y(mega2(p + 2));
            int16_t cx1 = mega2(p + 4),  cy1 = scale_y1(mega2(p + 6));
            int16_t cw  = cx1 - cx0 + 1, ch  = cy1 - cy0 + 1;
            if (mode > DRAW_MODE_NOT)
                mode = DRAW_MODE_COPY;
            while (offset + 12 <= mode_pos && pairs < 5) {
                int16_t sx0 = mega2(p + offset);
                int16_t sy0 = scale_y(mega2(p + offset + 2));
                int16_t sx1 = mega2(p + offset + 4);
                int16_t sy1 = scale_y1(mega2(p + offset + 6));
                int16_t dx = mega2(p + offset + 8);
                int16_t dy = scale_y(mega2(p + offset + 10));
                int16_t sw = (int16_t)(sx1 - sx0 + 1);
                int16_t sh = (int16_t)(sy1 - sy0 + 1);
                rip_copy_screen_region_scaled(s, sx0, sy0, sw, sh,
                                              dx, dy, sw, sh, mode);
                cw = sw;
                ch = sh;
                offset += 12;
                pairs++;
            }
            while (offset + 8 <= mode_pos && pairs < 5 && cw > 0 && ch > 0) {
                int16_t sx = mega2(p + offset);
                int16_t sy = scale_y(mega2(p + offset + 2));
                int16_t dx = mega2(p + offset + 4);
                int16_t dy = scale_y(mega2(p + offset + 6));
                rip_copy_screen_region_scaled(s, sx, sy, cw, ch,
                                              dx, dy, cw, ch, mode);
                offset += 8;
                pairs++;
            }
        }
        break;

    /* DLL binary: '{' = RIP_ANIMATION_FRAME (6 args: XY x 6 = 3 vertex pairs) */
    case '{': /* RIP_ANIMATION_FRAME -- 3 coordinate pairs */
        /* Draws filled polygon interior AND outline in one operation
         * (DLL calls GDI Polygon + Polyline in sequence).
         * With 3 points this is a filled+outlined triangle. */
        if (len >= 12) {
            int16_t pts[6];
            uint8_t border_mode;
            pts[0] = mega2(p);     pts[1] = scale_y(mega2(p + 2));
            pts[2] = mega2(p + 4); pts[3] = scale_y(mega2(p + 6));
            pts[4] = mega2(p + 8); pts[5] = scale_y(mega2(p + 10));
            if (s->fill_pattern != 0) {
                draw_set_color(s->palette[s->fill_color & 0x0F]);
                draw_polygon(pts, 3, true);
            }
            if (rip_begin_filled_border(s, &border_mode)) {
                draw_polygon(pts, 3, false);
                rip_end_filled_border(s, border_mode);
            } else {
                draw_set_color(s->palette[s->draw_color & 0x0F]);
            }
        }
        break;

    /* ── Kill mouse fields in region (Level 0) ───────────────── */
    /* DLL command table entry 42: 'K' = RIP_KILL_MOUSE_FIELDS (4 args: XY,XY,XY,XY).
     * Level 0 'K' removes all mouse regions whose rect intersects (x0,y0)-(x1,y1).
     * Level 1 'K' (above) kills ALL regions unconditionally. */
    /* Dispatch slot 42 (RVA 0x01bee5), argc 4, all XY — a rectangle, not a
     * mouse operation.  The handler orders (arg0,arg2) and then (arg1,arg3)
     * through the pair-ordering helper at 0x1003112e, i.e. it normalises
     * x0/x1 and y0/y1, which is rectangle setup.  SyncTERM's ripper.c and
     * bbs-land's reference both bind 'K' to RIP_FILLED_RECTANGLE.
     *
     * RIPlib previously ran a mouse-field kill here.  Nothing is lost: the
     * real killer is '|1k' RIP_KILL_ENCLOSED_MOUSE_FIELDS, which RIPlib
     * already implements with the flags semantics bbs-land documents. */
    case 'K': /* RIP_FILLED_RECTANGLE — x0:2 y0:2 x1:2 y1:2 */
        if (len >= 8) {
            int16_t kx0 = mega2(p),     ky0 = scale_y(mega2(p + 2));
            int16_t kx1 = mega2(p + 4), ky1 = scale_y1(mega2(p + 6));
            uint8_t border_mode;

            if (kx0 > kx1) { int16_t t = kx0; kx0 = kx1; kx1 = t; }
            if (ky0 > ky1) { int16_t t = ky0; ky0 = ky1; ky1 = t; }

            if (s->fill_pattern != 0) {
                draw_set_color(s->palette[s->fill_color & 0x0F]);
                draw_rect(kx0, ky0, (int16_t)(kx1 - kx0 + 1),
                          (int16_t)(ky1 - ky0 + 1), true);
            }
            if (rip_begin_filled_border(s, &border_mode)) {
                draw_rect(kx0, ky0, (int16_t)(kx1 - kx0 + 1),
                          (int16_t)(ky1 - ky0 + 1), false);
                rip_end_filled_border(s, border_mode);
            } else {
                draw_set_color(s->palette[s->draw_color & 0x0F]);
            }
        }
        break;

    /* ── Fill pattern data block ─────────────────────────────── */
    /* DLL command table entry 23: 'D' = RIP_FILL_PATTERN (var, data block).
     * Level 0 'D' supplies a custom 8×8 fill pattern as raw bytes.
     * Level 1 'D' (above) is RIP_DEFINE — distinct command. */
    /* Dispatch slot 23 (RVA 0x01f46a), VARIABLE length.  The handler names
     * itself RIP_SetDrawingPalette and its validation chain gives the whole
     * layout:
     *
     *     argc == count + 3     "Invalid number of parameters"
     *     count <= 256          "More than 256 entries"
     *     start <= 255          "Start is out of range"
     *     bits  == 8            "Invalid number of bits"
     *
     * so it is start:2 count:2 bits:1 followed by count × rgb:4 — the block
     * form of '|d' RIP_OneDrawingPalette, which handles a single entry.
     *
     * The 8×8 user fill pattern this letter used to carry is not lost: that
     * is '|s' RIP_FILL_PATTERN, which RIPlib already implements. */
    case 'D': /* RIP_SET_DRAWING_PALETTE — start:2 count:2 bits:1 (rgb:4)×count */
        if (RIP_PALETTE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 5) {
            /* Base 64, same flag as '|d' -- see D-12. */
            /* FIELD ORDER, from the handler's own validation: args[0] is
             * checked against 0x100 ("More than 256 entries") and against
             * argc ("Invalid number of parameters", argc == count + 3),
             * while args[1] is checked against 0xFF ("Start is out of
             * range").  So COUNT comes first.  RIPlib had these swapped;
             * bbs-land documents the correct order as `num:2 start:2`. */
            int      count = mega2_64(p);
            uint16_t start = (uint16_t)mega2_64(p + 2);
            uint8_t  bits  = (uint8_t)mega_digit64(p[4]);
            int i;

            /* Reject rather than clamp, matching the driver: a truncated or
             * over-long block is an error, not a partial palette write. */
            if (start <= 0xFF && count > 0 && count <= 256 && bits == 8 &&
                len >= 5 + 4 * count) {
                for (i = 0; i < count && (int)start + i <= 0xFF; i++) {
                    uint32_t rgb = (uint32_t)mega4_64(p + 5 + 4 * i);
                    uint8_t  r8  = (uint8_t)((rgb >> 16) & 0xFF);
                    uint8_t  g8  = (uint8_t)((rgb >> 8) & 0xFF);
                    uint8_t  b8  = (uint8_t)(rgb & 0xFF);
                    uint16_t rgb565 = (uint16_t)(((r8 & 0xF8) << 8) |
                                                 ((g8 & 0xFC) << 3) |
                                                 ((b8 & 0xF8) >> 3));
                    palette_write_rgb565((uint8_t)(start + i), rgb565);
                }
            }
        }
        break;

    /* ── Get image (clipboard capture) ──────────────────────── */
    /* DLL command table entry 13: '<' = RIP_GET_IMAGE (var, data block).
     * Captures a screen region into the clipboard for later PUT_IMAGE.
     * Minimum data block: x0:2 y0:2 x1:2 y1:2 (8 MegaNum chars). */
    /* Dispatch slot 13 (RVA 0x01e80a), VARIABLE length.  The handler reads
     * arg[0] as a count and then walks the remaining arguments, and its own
     * diagnostics are "Must have at least two vertices to make a polygon"
     * and "Insufficient vertices (2)" — it is a polygon command, not the
     * fixed rectangle read RIPlib had here.  TeleGrafix's ICONS/POLYPOLY.RIP
     * exercises it and labels itself RIP_POLY_POLYGON on screen.
     *
     * Wire layout, read off that file:
     *     count:2  then per contour  nverts:2  followed by nverts * (x:2 y:2)
     *
     * Clipboard capture is unaffected — '|1G' and the port path still call
     * rip_clipboard_capture(). */
    case '<': /* RIP_POLY_POLYGON — count:2 { nverts:2 (x:2 y:2)* }* */
        if (len >= 2) {
            rip_exec_poly_polygon(s, p, len);
        }
        break;

    /* Dispatch slot 3, argc 5, types ff ff 02 02 02.  The handler at RVA
     * 0x01f904 is instruction-for-instruction identical to '-' at 0x01c348
     * — the outline member of the same shape — and passes (arg0,arg1) and
     * then (arg2,arg3) to the same coordinate mapper at 0x10031084.
     *
     * That the radii are typed mega2 here and coordinate-width in '-' is
     * not a contradiction: the type byte gives the WIRE WIDTH, the mapper
     * is SEMANTIC scaling after decode.  '|&' always transmits its radii
     * as 2 digits; '|-' transmits them at the current coordinate size.  At
     * the default size of 2 both are 10 characters, which is why
     * TeleGrafix's demo shows the same payload shape for the pair.
     * See docs/spec/12 §12.14 and defects D-9 (withdrawn) and D-11. */
    case '&': /* RIP_SKEWED_OVAL — cx:2 cy:2 rx:2 ry:2 skew:2 */
        if (len >= 10) {
            int16_t cx = mega2(p),     cy = scale_y(mega2(p + 2));
            int16_t rx = mega2(p + 4), ry = scale_y(mega2(p + 6));
            int16_t sk = mega2(p + 8);
            rip_draw_skewed_oval(s, cx, cy, rx, ry, sk, 0, 360,
                                 RIP_OVAL_CLOSED, false);
        }
        break;

    /* ── Stamp icon from slot (v2.0+) ───────────────────────── */
    /* DLL command table entry 10: '.' = RIP_STAMP_ICON (6 args: XY×6). */
    case '.': /* RIP_STAMP_ICON — slot:2 x:2 y:2 w:2 h:2 flags:2 */
        if (len >= 12) {
            uint16_t slot = (uint16_t)mega2(p);
            int16_t dx = mega2(p + 2);
            int16_t dy = scale_y(mega2(p + 4));
            int16_t dw = 0;
            int16_t dh = 0;
            rip_icon_t icon;
            bool have_icon = false;

            if (len >= 10) {
                dw = mega2(p + 6);
                dh = scale_y(mega2(p + 8));
            }

            if (slot < RIP_ICON_SLOT_MAX && s->icon_slot_valid[slot]) {
                icon = s->icon_slots[slot];
                have_icon = true;
            } else if (s->clipboard.valid && s->clipboard.data) {
                icon.pixels = s->clipboard.data;
                icon.width = (uint16_t)s->clipboard.width;
                icon.height = (uint16_t)s->clipboard.height;
                have_icon = true;
            }

            if (have_icon) {
                rip_draw_icon_pixels(s, dx, dy, icon.pixels,
                                     icon.width, icon.height,
                                     dw, dh, s->write_mode);
            }
        }
        break;

    /* ── Extended mouse region (v2.0+) ──────────────────────── */
    /* DLL command table entry 11: ':' = RIP_MOUSE_REGION_EXT. */
    case ':': /* RIP_MOUSE_REGION_EXT — five (x,y) pairs + one digit.
               *
               * Slot 11 records  XY×10, mega1  -> 21 characters, and the
               * handler (RVA 0x01DD70) loads args[0..10] and coordinate-maps
               * exactly five consecutive pairs:
               *
               *     0x10031084(ctx, &args[0], &args[1])
               *     0x10031084(ctx, &args[2], &args[3])
               *     0x10031084(ctx, &args[4], &args[5])
               *     0x10031084(ctx, &args[6], &args[7])
               *     0x10031084(ctx, &args[8], &args[9])
               *
               * So this is a five-vertex region, not a rectangle carrying a
               * hotkey and flags.  RIPlib had two defects here (D-14): it
               * required 22 characters, so every valid 21-character command was
               * dropped in full, and it read args[4] and args[5] -- which the
               * record types as coordinates and the handler maps as a pair --
               * as a hotkey and a flag byte.
               *
               * rip_mouse_region_t has no home for a vertex list, so the region
               * registers as the bounding box of the five vertices: a
               * conservative over-approximation for hit-testing, rather than a
               * rectangle invented from two of the coordinates. */
        if (len >= 21 && s->num_mouse_regions < RIP_MAX_MOUSE_REGIONS) {
            rip_mouse_region_t *r = &s->mouse_regions[s->num_mouse_regions];
            int16_t minx = mega2(p),               maxx = minx;
            int16_t miny = scale_y(mega2(p + 2)),  maxy = miny;
            int i;
            for (i = 1; i < 5; i++) {
                int16_t vx = mega2(p + i * 4);
                int16_t vy = scale_y(mega2(p + i * 4 + 2));
                if (vx < minx) minx = vx;
                if (vx > maxx) maxx = vx;
                if (vy < miny) miny = vy;
                if (vy > maxy) maxy = vy;
            }
            memset(r, 0, sizeof(*r));
            r->x0     = minx;
            r->y0     = miny;
            r->x1     = maxx;
            r->y1     = maxy;
            r->flags  = (uint8_t)mega_digit(p[20]) | RIP_MF_ACTIVE;
            r->active = true;
            s->num_mouse_regions++;
        }
        break;

    /* ── Extended button (v2.0+) ─────────────────────────────── */
    /* DLL command table entry 12: ';' = RIP_BUTTON_EXT (7 args: XY,XY,2,XY,XY,2,2).
     * Registers a clickable visual region only; this variant carries no
     * host-command text (text_len stays 0 via the memset), unlike 1U/1M —
     * intentional per the DLL tables (C-016). */
    /* Dispatch slot 12 (RVA 0x01e4ff), argc 7:
     *     XY, XY, mega2, XY, XY, mega2, mega2
     * The handler names itself RIP_PolyMarker() and validates each field
     * with its own diagnostic, which gives the whole signature:
     *
     *     cmp marker,   0x24  -> "Invalid marker number"
     *     cmp rotation, 0x168 -> "Invalid marker rotation angle (>=360)"
     *     cmp flags,    3     -> "Invalid marker flags value"
     *
     * so marker < 36, rotation < 360, flags <= 3.  TeleGrafix's own
     * ICONS/MARKER.RIP ("RIPscrip Markers") exercises exactly numbers
     * 0..35, rotations 0..300 and sizes from 1x1 upward, which matches.
     *
     * RIPlib previously read this letter as a button, adding a MOUSE
     * REGION per call and stroking a rectangle.  That was not merely a
     * wrong shape: the corpus issues 361 of these, so a scene of markers
     * manufactured hundreds of phantom clickable areas.
     *
     * GLYPH SHAPES ARE NOT RECOVERED.  The 36 marker designs live behind
     * the handler's polygon builder and have not been extracted, so every
     * marker number currently renders the same neutral glyph, correctly
     * placed, sized and rotated.  Position and geometry are faithful;
     * which of the 36 shapes you get is not.  See docs/spec/12 §12.15. */
    case ';': /* RIP_POLY_MARKER — x:2 y:2 marker:2 w:2 h:2 rotation:2 flags:2 */
        if (len >= 14) {
            int16_t mx  = mega2(p),     my = scale_y(mega2(p + 2));
            int16_t num = mega2(p + 4);
            int16_t mw  = mega2(p + 6), mh = scale_y(mega2(p + 8));
            int16_t rot = mega2(p + 10);
            int16_t mfl = mega2(p + 12);

            /* Reject exactly what the driver rejects, rather than clamping
             * a bad field into a plausible-looking marker. */
            if (num < 36 && rot < 360 && mfl <= 3 && mw > 0 && mh > 0) {
                int16_t hw = (int16_t)(mw / 2), hh = (int16_t)(mh / 2);

                if (hw < 1) hw = 1;
                if (hh < 1) hh = 1;
                rip_draw_marker(s, mx, my, num, hw, hh, rot);
            }
        }
        break;

    /* ── Extended text window (v2.0+) ───────────────────────── */
    /* DLL command table entry 20: 'b' = RIP_EXT_TEXT_WINDOW
     * (9 args: XY,XY,XY,XY,2,2,1,4,3). */
    case 'b': /* RIP_EXT_TEXT_WINDOW -- x0:XY y0:XY x1:XY y1:XY
               *                        width:2 height:2 font:1 flags:4 res:3
               *
               * The driver spells it RIP_ExtendedTextWindow; the upper-snake
               * form is RIPlib's convention and the difference is cosmetic
               * (14-divergence-register.md 14.5).
               *
               * CORRECTED 2026-08-14 from slot 20's handler (RVA 0x01B075),
               * which names itself RIP_ExtendedTextWindow() in five separate
               * diagnostics and validates four fields:
               *
               *     args[7] > 0x3FF        "Flags value is out of range"
               *     args[6] >= 5           "Font number is out of range"
               *       (unless flags bit 3 is set)
               *     args[4] == 0           "Zero width value is not allowed"
               *     args[5] == 0           "Zero height value is not allowed"
               *   then the text-window protection query at 0x10027642,
               *                            "Can't modify current text window"
               *
               * This table read args[4]/args[5] as foreground and background
               * COLOURS and args[7] as a font SIZE.  A colour index does not
               * produce "Zero width value is not allowed".  Nothing rendered
               * from the mistake -- both colour fields were write-only -- and
               * no corpus scene sends '|b'. */
        if (RIP_TEXTWIN_PROTECTED(s)) break;   /* protected slot */
        if (len >= 20) {
            int16_t tw_x0 = mega2(p);
            int16_t tw_y0 = mega2(p + 2);
            int16_t tw_x1 = mega2(p + 4);
            int16_t tw_y1 = mega2(p + 6);
            clamp_ega_rect(&tw_x0, &tw_y0, &tw_x1, &tw_y1);
            s->tw_x0        = tw_x0;
            s->tw_y0        = tw_y0;
            s->tw_x1        = tw_x1;
            s->tw_y1        = tw_y1;
            {
                uint16_t w  = (uint16_t)mega2(p + 8);
                uint16_t h  = (uint16_t)mega2(p + 10);
                uint8_t  fn = (uint8_t)mega_digit(p[12]);
                uint32_t fl = (uint32_t)mega4(p + 13);

                /* The driver's own order: flags, then font, then width,
                 * then height.  Each refuses the whole command rather than
                 * clamping, so RIPlib does the same. */
                if (fl > 0x3FF)              break;
                if (fn >= 5 && !(fl & 0x08)) break;
                if (w == 0 || h == 0)        break;

                s->etw_cell_w  = w;
                s->etw_cell_h  = h;
                s->etw_font_id = fn;
                s->etw_flags   = fl;
            }
            s->tw_cur_x = s->tw_x0;
            s->tw_cur_y = scale_y(s->tw_y0);
            s->tw_active = true;
        }
        break;

    /* ── Extended font style (v2.0+) ────────────────────────── */
    /* DLL command table entry 24: 'd' = RIP_EXT_FONT_STYLE (3 args: 2,1,4). */
    case 'd': /* RIP_ONE_DRAWING_PALETTE — index:2 bits:1 rgb:4
               *
               * CORRECTED 2026-08-12 (B6).  This letter implemented
               * RIP_EXT_FONT_STYLE until the driver's handler was
               * disassembled.  It is a palette command, and the handler
               * (RVA 0x01CF95, which names itself RIP_OneDrawingPalette)
               * validates all three fields with distinct error strings:
               *
               *   arg0  index  <= 0xFF        "Color palette index out of range"
               *   arg1  bits   == 8 exactly   "Bits value out of range"
               *   arg2  rgb    <= 0xFFFFFF    "RGB Color value is out of range!"
               *
               * Extended font style is command '|y' (RIP_ExtendedFontStyle,
               * slot 75, 11 arguments) — see docs/spec/12-dll-provenance.md
               * D-5.  '|y' IS implemented, at Level 0 below; this note used
               * to say it was not, and was left behind when it landed on
               * 2026-08-12.  Parsing '|d' as font style actively corrupted
               * font state on any stream that set a palette entry, so that
               * behaviour was removed. */
        if (RIP_PALETTE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 7) {
            /* Base 64: the dispatch entry's flag word marks '|d' as always
             * using the extended radix.  Decoded as base 36 this command is
             * wrong in three ways at once -- 'a'..'z' fold onto 10..35,
             * '#'/'&' become 0, and a 4-digit field can only reach
             * 1679615 instead of the full 0xFFFFFF the handler validates
             * against.  TeleGrafix's TUNNEL.RIP writes a 64-entry ramp that
             * only decodes monotonically this way.  See D-12. */
            uint16_t pal_index = (uint16_t)mega2_64(p);
            uint8_t  pal_bits  = (uint8_t)mega_digit64(p[2]);
            uint32_t pal_rgb   = (uint32_t)mega4_64(p + 3);

            /* Match the driver's validation: out-of-range values are an
             * error, not something to clamp into a wrong colour. */
            if (pal_index <= 0xFF && pal_bits == 8 && pal_rgb <= 0xFFFFFFu) {
                uint8_t r8 = (uint8_t)((pal_rgb >> 16) & 0xFF);
                uint8_t g8 = (uint8_t)((pal_rgb >> 8) & 0xFF);
                uint8_t b8 = (uint8_t)(pal_rgb & 0xFF);
                uint16_t rgb565 = (uint16_t)(((r8 & 0xF8) << 8) |
                                             ((g8 & 0xFC) << 3) |
                                             ((b8 & 0xF8) >> 3));
                palette_write_rgb565((uint8_t)pal_index, rgb565);
            }
        }
        break;

    case 'j': /* RIP_POINT — x:XY y:XY
               *
               * Added 2026-08-12 (D-5).  Identified by disassembly: the
               * handler (RVA 0x01E2F8) transforms the two coordinates, then
               * fills a 1x1 rectangle with a brush ("Unable to create temp
               * brush"), and the RIP_Point name string is referenced from
               * inside its body at 0x1001E3D9.  Distinct from '|X'
               * RIP_PIXEL, which writes with the draw colour; this plots
               * through the fill/brush path. */
        if (len >= 4) {
            int16_t jx = mega2(p), jy = scale_y(mega2(p + 2));
            draw_set_color(s->palette[s->fill_color & 0x0F]);
            draw_pixel(jx, jy);
            draw_set_color(s->palette[s->draw_color & 0x0F]);
        }
        break;

    case 'r': /* RIP_TEXT_METRIC — mode:1 domain:1 res:4
               *
               * Added 2026-08-12 (D-5).  Argument widths come from the
               * dispatch entry's type bytes (01 01 04) and the ranges from
               * the handler's own validation at RVA 0x020371:
               *     mode   < 4   "Invalid text metric mode"
               *     domain < 2   "Invalid text metric domain"
               *
               * The driver computes a metric and makes it available to the
               * host.  WHERE it delivers the result has not been recovered,
               * so RIPlib validates and records the request without
               * inventing a delivery channel — see docs/spec §12.12 D-5.
               * Recording it is still better than the previous behaviour,
               * which dropped '|r' into error recovery and could desync the
               * rest of the frame. */
        if (len >= 6) {
            uint8_t tm_mode   = (uint8_t)mega_digit(p[0]);
            uint8_t tm_domain = (uint8_t)mega_digit(p[1]);
            if (tm_mode < 4 && tm_domain < 2) {
                s->text_metric_mode   = tm_mode;
                s->text_metric_domain = tm_domain;
            }
        }
        break;

    case 'y': /* RIP_EXTENDED_FONT_STYLE — 26 characters total
               *
               * Added 2026-08-12 (D-5).  This is the driver's real extended
               * font-style command (slot 75, RVA 0x01ADC0); RIPlib had the
               * feature on '|d', which is RIP_OneDrawingPalette.
               *
               * The dispatch entry's argument-width bytes are
               *     01 01 04 02 02 02 02 02 02 02 06
               * i.e. 1+1+4+(2*7)+6 = 26 characters — which independently
               * matches the "26-digit layout" recovered from FONTS.RIP by
               * the bbs-land reconstruction.
               *
               * Fields identified from the handler's validation branches:
               *     arg5  string rotation     0 / 90 / 180 / 270
               *     arg6  character rotation  same set
               *     arg8  character spacing %  must be non-zero
               * (the driver compares rotations against 0/900/1800/2700,
               * i.e. tenths of a degree, after scaling the 2-digit wire
               * field by 10.)
               *
               * The remaining fields are parsed at their correct widths but
               * NOT interpreted: their meanings have not been recovered, and
               * assigning them would be a guess.  See docs/spec §12.12. */
        if (RIP_STYLE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 26) {
            /* Base 64: the dispatch entry marks '|y' as always using the
             * extended radix, and real content proves it -- every |y in the
             * shipped corpus carries '1a1a' in its two scale fields, which
             * is 100,100 in base 64 (a clean percentage) and a meaningless
             * 46,46 in base 36.  See D-12. */
            uint8_t  y_font    = (uint8_t)mega_digit64(p[0]);
            uint16_t y_srot    = (uint16_t)mega2_64(p + 10);   /* arg5 */
            uint16_t y_crot    = (uint16_t)mega2_64(p + 12);   /* arg6 */
            uint16_t y_spacing = (uint16_t)mega2_64(p + 16);   /* arg8 */

            bool rot_ok = (y_srot == 0 || y_srot == 90 ||
                           y_srot == 180 || y_srot == 270) &&
                          (y_crot == 0 || y_crot == 90 ||
                           y_crot == 180 || y_crot == 270);

            if (rot_ok && y_spacing != 0) {
                if (y_font < BGI_FONT_COUNT)
                    s->font_id = y_font;
                s->font_ext_id  = y_font;
                s->char_spacing = y_spacing;
                /* Percentage of each glyph's natural advance; the driver
                 * rejects zero, which is why the guard above tests it. */
                bgi_font_set_char_spacing(y_spacing);
                /* Same rotation->direction mapping as '|26' SCALABLE_TEXT:
                 * 90 = CW (dir 3), 270 = CCW (dir 2), 180 unsupported by the
                 * stroke renderer so it falls back to horizontal. */
                if (y_srot == 90)       s->font_dir = 3;
                else if (y_srot == 270) s->font_dir = 2;
                else                    s->font_dir = 0;
            }
        }
        break;

    /* ── World frame / font attributes ──────────────────────── */
    /* DLL command table slot 28: 'f' = RIP_SetWorldFrame, 2 args (XY,XY).
     * DLL command table slot 55: 'q' = RIP_FontAttrib,   1 arg  (mega2).
     * Both confirmed by name from the handlers' own error strings; see
     * docs/spec/13-dll-command-table.md. */
    case 'f': /* RIP_SET_WORLD_FRAME — x_dim:XY y_dim:XY
               *
               * CORRECTED 2026-08-12.  This letter previously implemented
               * RIP_FONT_ATTRIB, which mis-parsed the prologue of most
               * shipping 3.x scenes: '|fZKQO' (the corpus standard, base-36
               * "ZK"=1280, "QO"=960) was read as a font-attribute byte and
               * silently corrupted font state.
               *
               * The driver's handler at RVA 0x01F874 names itself
               * RIP_SetWorldFrame, reads two coordinate values, and rejects
               * any argument count other than 2 with "Invalid argument".
               * Font attributes live on 'q' (RIP_FontAttrib) — see below.
               *
               * RIPlib stores the frame; it does not yet apply a
               * world->device transform (tracked as D-1 in
               * docs/spec/12-dll-provenance.md).  Storing it is strictly
               * better than the previous behaviour, which mis-applied it. */
        if (RIP_ENV_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 4) {
            s->world_w = (int16_t)mega2(p);
            s->world_h = (int16_t)mega2(p + 2);
        }
        break;

    case 'q': /* RIP_FONT_ATTRIB — attrib:2
               *
               * bit0=bold, bit1=italic, bit2=underline, bit3=shadow.
               * Stored in s->font_attrib and applied by the BGI stroke
               * renderer.  Moved here from 'f' on 2026-08-12.
               *
               * The driver's handler (RVA 0x01C799) range-checks the value
               * with `cmp ebx,0xF / jbe`, i.e. a 4-bit field, and sends
               * anything larger down the invalid-argument path rather than
               * masking it.  Match that: ignore out-of-range values instead
               * of silently truncating them. */
        if (RIP_STYLE_PROTECTED(s)) break;   /* protected slot: driver refuses */
        if (len >= 2) {
            uint16_t attrib = mega2(p);
            if (attrib <= 0x0F)
                s->font_attrib = (uint8_t)attrib;
        }
        break;

    }
}

/* ══════════════════════════════════════════════════════════════════
 * BYTE PROCESSING — 14-state FSM (DLL has 13; RIPlib adds LEVEL3)
 *
 * DLL ground truth: ripParseStateMachine @ 0x10039E90
 * Jump table: 0x1003AB9C  (states 0-12, stored at pContext+0x00)
 * State 13 (LEVEL3_LETTER) is a RIPlib addition for the '3' prefix.
 * prevState saved at pContext+0x04 for line-continuation restore.
 * lastChar  saved at pContext+0x9F for '!' line-boundary detection.
 * ══════════════════════════════════════════════════════════════════ */

/* One byte, past the pre-processor.  rip_process() below is the public entry
 * point: it runs the << … >> filter first and calls this for whatever
 * survives.  Splitting them is what lets a directive be recognised INSIDE a
 * command payload as well as between commands -- see D-26. */
static void rip_dispatch_byte(rip_state_t *s, void *ctx, uint8_t ch) {
    comp_context_t *c = (comp_context_t *)ctx;
    g_rip_state = s;

    /* DLL: suppress DEL (0x7F) only.  High bytes (0x80-0xFE) must pass through
     * for CP437 box-drawing characters in ANSI passthrough mode.  The original
     * DLL filter (ch >= 0x7F) was for a Windows environment where high bytes
     * were handled by the GDI text renderer; on our framebuffer we need them.
     * UTF-8 → CP437 decoding is handled at the telnet receive level
     * (a2gspu_emu_telnet_poll) before bytes reach this parser. */
    if (ch == 0x7F) return;

reprocess:
    switch (s->state) {

    /* ── State 0: IDLE ──────────────────────────────────────────
     * Scanning for '!' to begin a RIPscrip escape sequence.
     * DLL handler @ 0x1003A5CA.
     * Also handles: SOH swallow, ESC[! probe response,
     * text-window routing, and ANSI passthrough.
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_IDLE:

        /* Syntax rule 12: SOH (0x01) is an alternate command introducer,
         * accepted ANYWHERE in a line — deliberately host-only, since a BBS
         * user cannot readily type a control character.  Equivalent to '!',
         * so enter GOT_BANG and wait for '|'.
         *
         * CORRECTED 2026-08-12 (B12).  This previously read
         *     if (ch == 0x01) return;      // "DLL: swallow SOH"
         * which silently DISCARDED the introducer, so a scene opening with
         * the SOH form ("\x01|*|") never started.  The shipped 2.x corpus
         * opens exactly that way, and SyncTERM implements this split, so the
         * swallow was a real interoperability defect rather than a
         * simplification.  See design/bbs-land-alignment.md B12. */
        if (ch == 0x01) {
            s->state = RIP_ST_GOT_BANG;
            break;
        }

        /* When RIP graphics have been drawn and we return to ANSI
         * passthrough, position the VT100 cursor near the bottom so
         * the BBS status bar renders below the graphics area. One-shot. */
        if (s->rip_has_drawn && !s->cursor_repositioned && ch != '!') {
            s->cursor_repositioned = true;
            comp_set_cursor(c, 0, 23);
        }

        /* ESC[! auto-detect: BBSes send ESC[! to probe for RIPscrip
         * capability.  Track the 3-byte sequence; respond with the
         * current v3.2 identification string when confirmed. */
        if (ch == 0x1B) {
            s->esc_detect = 1;
            break;
        } else if (s->esc_detect == 1 && ch == '[') {
            s->esc_detect = 2;
            break;
        } else if (s->esc_detect == 2 && ch == '!') {
            /* ESC[! confirmed — reply with RIPSCRIP<ver><vendor>
             * 032001 = version 3.2, vendor 0, sub 1 */
            s->esc_detect = 0;
            riplib_host_tx("RIPSCRIP032001\n", 15);
            break;
        } else if (s->esc_detect > 0) {
            /* Not ESC[! — flush deferred bytes to VT100 then continue */
            uint8_t ed = s->esc_detect;
            s->esc_detect = 0;
            if (ed >= 1) comp_passthrough_vt100(c, 0x1B);
            if (ed >= 2) comp_passthrough_vt100(c, '[');
        }

        if (ch == '!' && (s->last_char == 0    || s->last_char == '\r' ||
                          s->last_char == '\n' || s->last_char == '\f')) {
            /* '!' introduces a command ONLY at a line boundary: start of
             * stream, or immediately after CR, LF or FF.  The driver enforces
             * this via lastChar (pContext+0x9F).
             *
             * RELAXATION WITHDRAWN 2026-08-12 (X5).  RIPlib previously fired on
             * ANY '!', so ordinary prose parsed as a command whenever an
             * exclamation mark happened to follow an ANSI sequence -- e.g.
             * "\x1b[32m!" in running text.  The line-boundary rule exists
             * precisely to make that impossible.
             *
             * The portable way to start a scene mid-line is the SOH/STX
             * introducer below (syntax rule 12): host-only, valid back to
             * 1.54, and what the shipping 2.x corpus actually uses. */
            s->state = RIP_ST_GOT_BANG;
        } else if (ch == 0x02) {
            /* Syntax rule 12: STX (0x02) is an alternate command introducer,
             * accepted ANYWHERE in a line — deliberately host-only, since a
             * BBS user cannot readily type a control character.  Equivalent to
             * '!', so fall straight through to waiting for '|'.
             * Added 2026-08-12 (B12); the shipped 2.x corpus opens with the
             * SOH form and would not start a scene without this. */
            s->state = RIP_ST_GOT_BANG;
        } else if (s->tw_active) {
            rip_tw_putchar(s, ch);
            s->last_char = ch;
        } else {
            /* Pass through to VT100. Use comp_passthrough_vt100, NOT
             * comp_write_raw — the latter re-enters via the RIPscrip hook. */
            comp_passthrough_vt100(c, ch);
            s->last_char = ch;
        }
        break;

    /* ── State 1: GOT_BANG ──────────────────────────────────────
     * Received '!'.  Waiting for '|' to confirm "!|" escape.
     * DLL handler @ 0x1003A628.
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_GOT_BANG:
        if (ch == '|') {
            s->cmd_len   = 0;
            s->cmd_char  = 0;
            clear_levels(s);
            s->state = RIP_ST_COMMAND;
        } else {
            /* False alarm — emit '!' then re-process current byte in IDLE */
            comp_passthrough_vt100(c, '!');
            s->state = RIP_ST_IDLE;
            goto reprocess;
        }
        break;

    /* ── State 2: CMD_LETTER ────────────────────────────────────
     * Collecting command identifier and parameters after "!|".
     * DLL handler @ 0x10039EB8.
     *
     * DLL dispatch order:
     *   ch >= 0x7F  → ignore  (filtered at function entry)
     *   ch == '\\'  → prevState=state; state=LINE_CONT(5)
     *   ch CR/LF/FF → dispatch; return to IDLE
     *   ch == '|'   → dispatch; reset for next command in frame
     *   cmd_char==0, '1'-'9' → level-prefix states 10/11
     *   cmd_char==0, letter  → record cmd_char, stay here
     *   cmd_char==0, other   → ERROR_RECOVERY(12)
     *   cmd_char!=0          → accumulate parameter byte
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_COMMAND:
        if (ch == '\\') {
            /* Line continuation — save state, enter LINE_CONT.
             * DLL: pContext->prevState = state; state = LINE_CONT (6) */
            s->prev_state = s->state;
            s->state = RIP_ST_LINE_CONT;
            break;
        }

        if (ch == '\r' || ch == '\n') {
            /* Line terminator — dispatch pending command; return to IDLE */
            if (s->cmd_char)
                execute_rip_command(s, ctx);
            s->cmd_char  = 0;
            s->cmd_len   = 0;
            clear_levels(s);
            s->last_char = ch;
            s->state     = RIP_ST_IDLE;
            break;
        }

        if (ch == '|') {
            /* '|' terminates current command; more may follow in frame.
             * Execute, reset, stay in CMD_LETTER for next command — unless
             * the dispatched command (e.g. via $ABORT$) reset state to IDLE,
             * in which case honor that. */
            if (s->cmd_char)
                execute_rip_command(s, ctx);
            bool aborted = (s->state == RIP_ST_IDLE);
            s->cmd_char  = 0;
            s->cmd_len   = 0;
            clear_levels(s);
            if (aborted)
                s->state = RIP_ST_IDLE;
            /* else stay in RIP_ST_COMMAND */
            break;
        }

        if (s->cmd_char == 0) {
            /* First byte after !| or after a '|' separator — command letter only.
             * A1: once cmd_char is set we transition to ARG_COLLECT (state 3) so
             * that parameter accumulation lives in its own dedicated state arm. */
            if (ch == '1') {
                s->is_level1 = true;
                s->state = RIP_ST_LEVEL1_LETTER;
            } else if (ch == '2') {
                s->is_level2 = true;
                s->state = RIP_ST_LEVEL2_LETTER;
            } else if (ch == '3') {
                s->is_level3 = true;
                s->state = RIP_ST_LEVEL3_LETTER;
            } else if ((ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') ||
                       ch == '*' || ch == '#' || ch == '@' || ch == '>' ||
                       ch == '=' || ch == '!' ||
                       ch == '(' || ch == ')' || ch == '+' || ch == ',' ||
                       ch == '-' || ch == '.' || ch == ':' || ch == ';' ||
                       ch == '<' || ch == '[' || ch == ']' || ch == '_' ||
                       ch == '&' || ch == '`' || ch == '{' || ch == '"' ||
                       ch == '^' || ch == '~') {
                /* Valid Level 0 command letter */
                s->cmd_char = (char)ch;
                /* A3: '!' as the command letter is the comment marker (!|!…|).
                 * Transition directly to COMMENT (state 9); no args to collect. */
                if (ch == '!') {
                    s->state = RIP_ST_COMMENT;
                } else {
                    /* A1: transition to ARG_COLLECT for parameter byte accumulation */
                    s->state = RIP_ST_ARG_COLLECT;
                }
            } else {
                /* Unknown command-letter byte — resync.
                 * DLL: table lookup fails → state = ERROR_RECOVERY (12) */
                s->state = RIP_ST_ERROR_RECOVERY;
            }
        }
        /* cmd_char != 0 no longer reached here: once cmd_char is set this state
         * transitions to ARG_COLLECT, so the else branch is unreachable.
         * Retained for robustness should prev_state restoration ever land here. */
        break;

    /* ── State 3: ARG_COLLECT ───────────────────────────────────
     * cmd_char is set; accumulate MegaNum parameter bytes until
     * '|' (next command in frame) or CR/LF (end of frame line).
     * DLL handler @ 0x10039EB8 (shares dispatch with CMD_LETTER
     * via the "cmd_char != 0" branch — split out here for clarity).
     *
     * A1: This state was previously handled inline in CMD_LETTER.
     * Separating it makes the FSM match the 13-state DLL layout.
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_ARG_COLLECT:
        if (ch == '\\') {
            /* Line continuation inside a parameter sequence */
            s->prev_state = s->state;
            s->state = RIP_ST_LINE_CONT;
            break;
        }

        if (ch == '\r' || ch == '\n') {
            /* End of frame line — dispatch pending command, return to IDLE */
            if (s->cmd_char)
                execute_rip_command(s, ctx);
            s->cmd_char  = 0;
            s->cmd_len   = 0;
            clear_levels(s);
            s->last_char = ch;
            s->state     = RIP_ST_IDLE;
            break;
        }

        if (ch == '|') {
            /* Command terminator — dispatch, then accept next command letter.
             * If the dispatched command (e.g. via $ABORT$) reset state to
             * IDLE, honor that rather than overriding back to COMMAND. */
            if (s->cmd_char)
                execute_rip_command(s, ctx);
            bool aborted = (s->state == RIP_ST_IDLE);
            s->cmd_char  = 0;
            s->cmd_len   = 0;
            clear_levels(s);
            s->state = aborted ? RIP_ST_IDLE : RIP_ST_COMMAND;
            break;
        }

        /* Accumulate parameter byte */
        if (s->cmd_len < (int)sizeof(s->cmd_buf) - 1)
            s->cmd_buf[s->cmd_len++] = (char)ch;
        break;

    /* ── State 5: LINE_CONT ─────────────────────────────────────
     * '\' received mid-command.  Waiting for CR or LF.
     * DLL handler @ 0x1003A400.
     *
     * CR        → state = LINE_WAIT_LF(6)   [wait for optional CRLF pair]
     * LF        → restore prevState          [bare-LF continuation done]
     * !|\       → escape pair: push both bytes literally to cmd_buf so
     *             unescape_text() can resolve them.  Without this, '\|'
     *             inside a text parameter would split the command on '|'.
     * other     → restore prevState; emit '\' literal; re-process char
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_LINE_CONT:
        if (ch == '\r') {
            s->state = RIP_ST_LINE_WAIT_LF;
        } else if (ch == '\n') {
            s->state = s->prev_state;
        } else if (ch == '!' || ch == '|' || ch == '\\') {
            /* Escape pair: keep both bytes in cmd_buf so unescape_text()
             * decodes \! → !, \| → |, \\ → \ at command-execute time.
             * Stay in prev_state so subsequent bytes resume normally. */
            s->state = s->prev_state;
            if (s->cmd_char != 0 &&
                s->cmd_len + 1 < (int)sizeof(s->cmd_buf) - 1) {
                s->cmd_buf[s->cmd_len++] = '\\';
                s->cmd_buf[s->cmd_len++] = (char)ch;
            }
        } else {
            /* Non-escape, non-newline: '\' was literal; reprocess ch. */
            s->state = s->prev_state;
            if (s->cmd_char != 0 &&
                s->cmd_len < (int)sizeof(s->cmd_buf) - 1)
                s->cmd_buf[s->cmd_len++] = '\\';
            goto reprocess;
        }
        break;

    /* ── State 6: LINE_WAIT_LF ──────────────────────────────────
     * CR received after '\'.  Waiting for LF (CRLF continuation).
     * DLL handler @ 0x1003A469.
     *
     * LF  → restore prevState   [CRLF pair consumed]
     * other → restore prevState; re-process char
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_LINE_WAIT_LF:
        if (ch == '\n') {
            s->state = s->prev_state;
        } else {
            s->state = s->prev_state;
            goto reprocess;
        }
        break;

    /* ── State 7: TEXT_COLLECT ──────────────────────────────────
     * Free-text parameter collection until '|', CR, or LF.
     * DLL handler @ 0x1003A525.
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_TEXT_COLLECT:
        if (ch == '\\') {
            s->prev_state = s->state;
            s->state = RIP_ST_LINE_CONT;
        } else if (ch == '|' || ch == '\r' || ch == '\n') {
            if (s->cmd_char)
                execute_rip_command(s, ctx);
            s->cmd_char  = 0;
            s->cmd_len   = 0;
            clear_levels(s);
            if (ch == '\r' || ch == '\n') {
                s->last_char = ch;
                s->state = RIP_ST_IDLE;
            } else {
                s->state = RIP_ST_COMMAND;
            }
        } else {
            if (s->cmd_len < (int)sizeof(s->cmd_buf) - 1)
                s->cmd_buf[s->cmd_len++] = (char)ch;
        }
        break;

    /* ── State 8: SUPPRESS ──────────────────────────────────────
     * Suppress ANSI fallback text after an unrecognized command.
     * Consume printable bytes; stop on '|', CR/LF, or '!'.
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_SUPPRESS:
        if (ch == '\r' || ch == '\n') {
            s->last_char = ch;
            s->state = RIP_ST_IDLE;
        } else if (ch == '!') {
            s->state = RIP_ST_IDLE;
            goto reprocess;
        } else if (ch == '|') {
            s->cmd_char  = 0;
            s->cmd_len   = 0;
            clear_levels(s);
            s->state = RIP_ST_COMMAND;
        } else if (ch < 0x20) {
            s->state = RIP_ST_IDLE;
            goto reprocess;
        }
        /* Printable chars silently consumed */
        break;

    /* ── State 9: COMMENT ───────────────────────────────────────
     * Inside a !|! comment.  Skip bytes until closing '|'.
     * DLL Level 0 '!' command handler swallows until next '|'.
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_COMMENT:
        if (ch == '|') {
            s->cmd_char  = 0;
            s->cmd_len   = 0;
            clear_levels(s);
            s->state = RIP_ST_COMMAND;
        } else if (ch == '\r' || ch == '\n') {
            s->last_char = ch;
            s->state = RIP_ST_IDLE;
        }
        break;

    /* ── State 10: LEVEL1_LETTER ────────────────────────────────
     * After '1' prefix — waiting for Level 1 sub-command letter.
     * DLL: secondary dispatch table for level-prefix routing.
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_LEVEL1_LETTER:
        if (ch == '\r' || ch == '\n') {
            s->last_char = ch;
            s->is_level1 = false;
            s->state = RIP_ST_IDLE;
        } else if (ch == '|') {
            s->is_level1 = false;
            s->state = RIP_ST_COMMAND;
        } else {
            /* Sub-command letter acquired; collect parameters in ARG_COLLECT */
            s->cmd_char = (char)ch;
            s->state = RIP_ST_ARG_COLLECT;
        }
        break;

    /* ── State 11: LEVEL2_LETTER ────────────────────────────────
     * After '2' prefix — waiting for Level 2 sub-command letter.
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_LEVEL2_LETTER:
        if (ch == '\r' || ch == '\n') {
            s->last_char = ch;
            s->is_level2 = false;
            s->state = RIP_ST_IDLE;
        } else if (ch == '|') {
            s->is_level2 = false;
            s->state = RIP_ST_COMMAND;
        } else {
            s->cmd_char = (char)ch;
            s->state = RIP_ST_ARG_COLLECT;
        }
        break;

    /* ── State 13: LEVEL3_LETTER ────────────────────────────────
     * After '3' prefix — waiting for Level 3 sub-command letter.
     * DLL has 5 Level 3 commands; letters not fully documented.
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_LEVEL3_LETTER:
        if (ch == '\r' || ch == '\n') {
            s->last_char = ch;
            s->is_level3 = false;
            s->state = RIP_ST_IDLE;
        } else if (ch == '|') {
            s->is_level3 = false;
            s->state = RIP_ST_COMMAND;
        } else {
            s->cmd_char = (char)ch;
            s->state = RIP_ST_ARG_COLLECT;
        }
        break;

    /* ── State 12: ERROR_RECOVERY ───────────────────────────────
     * Invalid command or argument overflow.  Consume until resync.
     * DLL handler @ 0x1003A581.
     * ─────────────────────────────────────────────────────────── */
    case RIP_ST_ERROR_RECOVERY:
        if (ch == '|') {
            s->cmd_char  = 0;
            s->cmd_len   = 0;
            clear_levels(s);
            s->state = RIP_ST_COMMAND;
        } else if (ch == '\r' || ch == '\n') {
            s->last_char = ch;
            s->state = RIP_ST_IDLE;
        }
        /* Other bytes discarded */
        break;
    }
}

/* ══════════════════════════════════════════════════════════════════
 * HOST CALLBACK SHIMS — called from the consumer's command handlers
 *
 * These replace the RIPSCRIP.DLL host-app callback slots (the 75-slot
 * FARPROC table) that riptel.exe filled at startup.  Each function
 * operates on g_rip_state directly; consumers call them by extern decl
 * to keep rip_state_t opaque outside this compilation unit.
 * ══════════════════════════════════════════════════════════════════ */

/* CMD_SYNC_DATE byte handler (CB_GET_TIME / date half).
 * Called by the host once per byte of the date string.
 * data_byte: next date character from the host's wall-clock source,
 *   or 0x00 to commit the accumulated buffer to host_date.
 * The *_state form is reentrant across distinct rip_state_t instances;
 * rip_sync_date_byte() wraps the single active session (g_rip_state). */

/* Public entry point: the << >> pre-processor filter, then dispatch.
 *
 * The scanner used to sit inside `case RIP_ST_IDLE`, which meant a
 * directive was only recognised BETWEEN commands.  Shipped content puts
 * them inside a payload -- BUTTONS.RIP selects a font with
 *     !|1R00000000<<IF $COLORS$<"256">>BLUEBACK.FN<<ELSE>>BLUEFADE.FN<<ENDIF>>
 * -- so the filter has to run for every byte, whatever state the FSM is
 * in.  Directives are UPPERCASE; the lowercase <<if>> that appears in
 * '|1M' host-command text is not a directive and passes through
 * untouched, which is what preproc_finalize_directive() now guarantees
 * by emitting anything it does not recognise verbatim.  See D-26. */
void rip_process(rip_state_t *s, void *ctx, uint8_t ch) {
    /* E4: <<IF>>/<<ELSE>>/<<ENDIF>> stream-level pre-processor.
     * Evaluated before all other IDLE-state logic so that suppressed
     * content (preproc_suppress==true) is swallowed before it can
     * reach the VT100 passthrough or the '!' detector.
     *
     * State machine for the << … >> wrapper:
     *   preproc_state 0 = normal — watch for first '<'
     *   preproc_state 1 = got one '<' — watch for second '<'
     *   preproc_state 2 = inside <<…>> — collect directive bytes
     *   preproc_state 3 = saw one '>' inside <<…>> — confirm closing >>
     *
     * Directive evaluation is intentionally minimal: the DLL supports
     * only simple string comparisons of $VARIABLE$ values, so we do
     * the same. Unknown directives are ignored. */
    if (s->preproc_state == 0 && ch == '<') {
        s->preproc_state = 1;
        return; /* swallow first '<', wait for second */
    }
    if (s->preproc_state == 1) {
        if (ch == '<') {
            /* Got <<  — start collecting directive bytes */
            s->preproc_state = 2;
            s->preproc_len   = 0;
            return;
        }
        /* False alarm — was a lone '<'; emit it and re-process ch */
        /* Re-dispatch, so the character reaches whichever consumer is
         * active: the VT100 or text window at IDLE, cmd_buf inside a
         * command.  Emitting straight to the terminal here -- which is
         * what this did -- dropped a lone '<' whenever one appeared in a
         * command payload. */
        s->preproc_state = 0;
        if (!s->preproc_suppress)
            rip_dispatch_byte(s, ctx, '<');
        /* Fall through to normal processing of ch below */
    }
    if (s->preproc_state == 2) {
        if (ch == '\r' || ch == '\n') {
            s->preproc_state = 0;
            s->preproc_len = 0;
        } else if (ch == '>') {
            s->preproc_state = 3;
            return;
        } else {
            /* Bail out on malformed oversized directives rather than
             * wedging the parser until a later literal >> appears. */
            if (s->preproc_len >= (int)sizeof(s->preproc_buf) - 1) {
                s->preproc_state = 0;
                s->preproc_len = 0;
                return;
            }
            s->preproc_buf[s->preproc_len++] = (char)ch;
            return;
        }
    }
    if (s->preproc_state == 3) {
        if (ch == '\r' || ch == '\n') {
            s->preproc_state = 0;
            s->preproc_len = 0;
        } else if (ch == '>') {
            s->preproc_state = 0;
            preproc_finalize_directive(s, ctx);
            return;
        } else {
            if (s->preproc_len >= (int)sizeof(s->preproc_buf) - 2) {
                s->preproc_state = 0;
                s->preproc_len = 0;
                return;
            }
            s->preproc_buf[s->preproc_len++] = '>';
            s->preproc_buf[s->preproc_len++] = (char)ch;
            s->preproc_state = 2;
            return;
        }
    }

    /* When suppressing, swallow all output bytes except '<' (which could
     * start a new << sequence via preproc_state machinery above). */
    if (s->preproc_suppress && ch != '<') return;

    rip_dispatch_byte(s, ctx, ch);
}

void rip_sync_date_byte_state(rip_state_t *s, uint8_t data_byte) {
    if (!s) return;
    if (data_byte == '\0') {
        /* NUL — commit accumulated buffer to host_date */
        int len = s->sync_date_len;
        if (len > (int)sizeof(s->host_date) - 1)
            len = (int)sizeof(s->host_date) - 1;
        memcpy(s->host_date, s->sync_date_buf, (size_t)len);
        s->host_date[len] = '\0';
        s->sync_date_len = 0;
    } else {
        if (s->sync_date_len < (int)sizeof(s->sync_date_buf) - 1)
            s->sync_date_buf[s->sync_date_len++] = (char)data_byte;
    }
}

/* CMD_SYNC_TIME byte handler (CB_GET_TIME / time half).
 * Called by the host once per byte of the time string.
 * data_byte: next time character, or 0x00 to commit to host_time.
 * rip_sync_time_byte() wraps the single active session. */
void rip_sync_time_byte_state(rip_state_t *s, uint8_t data_byte) {
    if (!s) return;
    if (data_byte == '\0') {
        int len = s->sync_time_len;
        if (len > (int)sizeof(s->host_time) - 1)
            len = (int)sizeof(s->host_time) - 1;
        memcpy(s->host_time, s->sync_time_buf, (size_t)len);
        s->host_time[len] = '\0';
        s->sync_time_len = 0;
    } else {
        if (s->sync_time_len < (int)sizeof(s->sync_time_buf) - 1)
            s->sync_time_buf[s->sync_time_len++] = (char)data_byte;
    }
}

/* CMD_QUERY_RESPONSE byte handler (CB_INPUT_TEXT callback equivalent).
 * Called by the host once per byte of the query response.
 * data_byte: next response character typed by the user on the host,
 *   or 0x00 to commit and send the response to the BBS.
 * On NUL: stores response in the target user variable, pushes it to the
 * BBS via TX FIFO, and clears query_pending.
 * rip_query_response_byte() wraps the single active session. */
void rip_query_response_byte_state(rip_state_t *s, uint8_t data_byte) {
    if (!s || !s->query_pending) return;

    if (data_byte == '\0') {
        /* Commit: identify target variable from query_var_name and store result. */
        const char *vn = s->query_var_name;
        if (vn[0] == '$' && vn[1] == 'A' && vn[2] == 'P' && vn[3] == 'P' &&
            vn[4] >= '0' && vn[4] <= '9' && vn[5] == '$') {
            int idx = vn[4] - '0';
            int rlen = s->query_response_len;
            if (rlen > 31) rlen = 31;
            memcpy(s->app_vars[idx], s->query_response, (size_t)rlen);
            s->app_vars[idx][rlen] = '\0';
            /* Send response to BBS now that we have it */
            if (rlen > 0)
                riplib_host_tx(s->app_vars[idx], rlen);
        } else {
            int rlen = s->query_response_len;
            if (rip_user_var_set(s, vn, (int)strlen(vn),
                                 s->query_response, rlen) && rlen > 0) {
                riplib_host_tx(s->query_response, rlen);
            }
        }
        s->query_pending = false;
        s->query_response_len = 0;
    } else {
        if (s->query_response_len < (int)sizeof(s->query_response) - 1)
            s->query_response[s->query_response_len++] = (char)data_byte;
    }
}

/* Single-session wrappers — route through g_rip_state.
 * See SESSION SAFETY in ripscrip.h. */
void rip_sync_date_byte(uint8_t data_byte) {
    rip_sync_date_byte_state(g_rip_state, data_byte);
}

void rip_sync_time_byte(uint8_t data_byte) {
    rip_sync_time_byte_state(g_rip_state, data_byte);
}

void rip_query_response_byte(uint8_t data_byte) {
    rip_query_response_byte_state(g_rip_state, data_byte);
}

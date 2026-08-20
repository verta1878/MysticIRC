/*
 * ripscrip.h — RIPscrip v1.54 graphics protocol parser for RIPlib
 *
 * TeleGrafix RIPscrip (Remote Imaging Protocol Scripting Language).
 * Vector graphics + text overlay for BBS systems.  Native coordinate
 * space is 640×350 (EGA); consumers that render to other resolutions
 * apply scale_y() to translate the Y axis (e.g., 8/7 to reach 640×400).
 * Base-36 "MegaNum" parameter encoding.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "rip_icons.h"
#include "riplib_platform.h"

/* Maximum mouse regions (RIPscrip spec: 128) */
#define RIP_MAX_MOUSE_REGIONS 128

/* Maximum clipboard size (640×400 = 256000 bytes, stored in PSRAM) */
#define RIP_CLIPBOARD_MAX     (640 * 400)

/* Numbered icon slots used by v2.0 SAVE_ICON / STAMP_ICON. */
#define RIP_ICON_SLOT_MAX     36

/* Maximum text block lines */
#define RIP_MAX_TEXT_LINES    64

/* Application-defined variables beyond the standard $APP0$-$APP9$ slots. */
#define RIP_USER_VAR_MAX       16
#define RIP_USER_VAR_NAME_MAX  15
#define RIP_USER_VAR_VALUE_MAX 63

/* Maximum nested <<IF>> depth tracked by the stream preprocessor. */
#define RIP_PREPROC_MAX_DEPTH 8

/* Parser states — 14 states.  States 0-12 match the historical
 * RIPSCRIP.DLL parser (see consumer-handoff/a2gspu/dll-reference.md for
 * the binary-level cross-reference); state 13 (LEVEL3_LETTER) is a
 * RIPlib addition for the '3' prefix.
 *
 * State 0  IDLE         — scanning for '!'  (was PASSTHROUGH)
 * State 1  GOT_BANG     — got '!', looking for '|'
 * State 2  CMD_LETTER   — collecting command letter / level prefix
 * State 3  ARG_COLLECT  — accumulating MegaNum parameter bytes
 * State 4  ARG_DISPATCH — args complete, ready to call handler
 * State 5  LINE_CONT    — received '\' mid-command, waiting for CR/LF
 * State 6  LINE_WAIT_LF — got CR after '\', waiting for LF to complete
 * State 7  TEXT_COLLECT — free-text parameter until '|'  (commands like T/@)
 * State 8  SUPPRESS     — suppress ANSI fallback until CR/LF or '!'
 * State 9  COMMENT      — inside !|! comment, skip until next '|'
 * State 10 LEVEL1_LETTER — after '1' prefix, waiting for sub-command letter
 * State 11 LEVEL2_LETTER — after '2' prefix, waiting for sub-command letter
 * State 12 ERROR_RECOVERY — resync on '|' or newline after bad command
 * State 13 LEVEL3_LETTER — after '3' prefix (forward-compat; see §1.3)
 */
#define RIP_ST_IDLE          0  /* Scanning for '!' (was PASSTHROUGH) */
#define RIP_ST_PASSTHROUGH   0  /* Alias for back-compat */
#define RIP_ST_GOT_BANG      1  /* Received '!' */
#define RIP_ST_COMMAND       2  /* Collecting command letter (CMD_LETTER) */
#define RIP_ST_ARG_COLLECT   3  /* Accumulating MegaNum parameter bytes */
#define RIP_ST_ARG_DISPATCH  4  /* Args complete — dispatch handler */
#define RIP_ST_LINE_CONT     5  /* '\' received — waiting for CR/LF */
#define RIP_ST_LINE_WAIT_LF  6  /* CR received after '\' — waiting for LF */
#define RIP_ST_TEXT_COLLECT  7  /* Free-text param until '|' */
#define RIP_ST_SUPPRESS      8  /* Suppress ANSI fallback until CR/LF */
#define RIP_ST_COMMENT       9  /* !|! comment — skip until '|' */
#define RIP_ST_LEVEL1_LETTER 10 /* After '1', waiting for sub-command */
#define RIP_ST_LEVEL2_LETTER 11 /* After '2', waiting for sub-command */
#define RIP_ST_ERROR_RECOVERY 12 /* Resync on '|' or newline */
#define RIP_ST_LEVEL3_LETTER 13 /* After '3', waiting for sub-command */

/* Mouse field flags.  Historical DLL field-offset cross-reference for
 * these bits and the mouse-region struct below lives in
 * consumer-handoff/a2gspu/dll-reference.md. */
#define RIP_MF_ACTIVE      0x04  /* field is live / hit-testable */
#define RIP_MF_SEND_CHAR   0x08  /* send hotkey char on click, not host string */
#define RIP_MF_RADIO       0x20  /* radio-button group: deselect others on click */
#define RIP_MF_TOGGLE      0x40  /* toggle state on each click */
#define RIP_MF_HAS_LABEL   0x02  /* field has a visible label */
#define RIP_MF_INVERT      0x01  /* invert the region while clicked (|1M clk) */
#define RIP_MF_RESET       0x10  /* clear the mouse-field set after this one
                                  * fires (|1M clr) */

/* Mouse region entry. */
typedef struct {
    int16_t x0, y0, x1, y1;       /* Bounding rectangle (pixel coords) */
    uint8_t flags;                  /* MF_ACTIVE | MF_SEND_CHAR | MF_RADIO | MF_TOGGLE */
    uint8_t hotkey;                 /* ASCII hotkey (0=none) */
    uint8_t line_style;             /* Line style when drawn */
    uint8_t line_thick;             /* Line thickness */
    uint8_t highlight_color;        /* Highlight/hover color index */
    uint8_t event_code;             /* Event type code */
    char    text[128];              /* Host command string */
    uint8_t text_len;
    char    icon_path[64];          /* Icon file path (truncated from spec's 97 bytes) */
    bool    active;                 /* true when MF_ACTIVE is set and region is registered */
    bool    hover;                  /* true when cursor is currently inside region */
} rip_mouse_region_t;

/* Button style (set by 1U, used by 1B button instances). */
typedef struct {
    int16_t  width, height;     /* Button dimensions */
    uint8_t  orient;            /* 0=horizontal, 1=vertical */
    uint16_t flags;             /* Style flags (beveled, chisel, etc.) */
    uint8_t  bev_size;          /* Bevel size in pixels */
    uint8_t  dfore, dback;      /* Dark foreground/background */
    uint8_t  bright, dark;      /* Highlight/shadow colors */
    uint8_t  surface;           /* Surface color */
    uint8_t  grp_no;            /* Group number (0-35) */
    uint16_t flags2;            /* Extended flags */
    uint8_t  uline_col;         /* Underline color */
    uint8_t  corner_col;        /* Corner color */
} rip_button_style_t;

/* Clipboard for GET_IMAGE/PUT_IMAGE */
typedef struct {
    uint8_t *data;              /* Pixel data (arena-allocated) */
    int16_t  width, height;     /* Dimensions of stored region */
    bool     valid;             /* true if clipboard contains data */
} rip_clipboard_t;

/* Handler for '|3G' RIP_GotoURL.
 *
 * RIPlib NEVER opens a URL or spawns a process itself.  A stream is untrusted
 * input, and a terminal that acts on it directly is a remote-code-execution
 * surface -- which is why the $GOTOURL$ text-variable path has been neutered
 * since SV-2/S2.
 *
 * But refusing to expose the request at all just means the feature cannot
 * work.  The compromise is that the EMBEDDER opts in explicitly:
 *
 *   - No handler registered (the default) -- the URL is validated and stored
 *     in rip_state_t.goto_url and nothing else happens.  A host can poll it.
 *   - Handler registered -- it is invoked with a URL that has already passed
 *     RIPlib's own checks, and the host applies its own policy on top
 *     (prompting the user, checking an allow-list, whatever it needs).
 *
 * RIPlib's checks are a floor, not a substitute for the host's judgement:
 * the URL must be printable with no control characters or whitespace, must
 * fit the buffer, and must begin with http:// or https://.  Every other
 * scheme is refused outright -- javascript:, data:, file:, vbscript: and
 * friends are exactly the payloads that turn "open a link" into code
 * execution, and no host policy should have to re-litigate them.
 *
 * The handler is still called with attacker-influenced data.  Treat it as
 * such: do not pass it to a shell. */
struct rip_state_s;
typedef struct rip_state_s rip_state_t;

typedef void (*rip_url_handler_t)(const char *url, int len);

/* Register (or clear, with NULL) the URL handler for this session.
 * Call after rip_init_first(), which zeroes the state. */
void rip_set_url_handler(rip_state_t *s, rip_url_handler_t handler);

/* Take any pending '|3D' RIP_DELAY request, in sixtieths of a second, and
 * clear it.  Returns 0 when none is pending.
 *
 * The original driver implements this by busy-waiting on timeGetTime().
 * RIPlib deliberately does not: blocking a caller for up to 65 seconds per
 * chunk is unusable on the cooperative and single-threaded hosts RIPlib
 * targets.  Poll this after feeding a frame and honour it however suits the
 * host — sleep, defer the next feed, or ignore it.  Ignoring it is safe;
 * the delay is a pacing hint, not a rendering instruction. */
uint32_t rip_take_delay(rip_state_t *s);

/* Text block state (1T/1t/1E) */
typedef struct {
    int16_t  x0, y0, x1, y1;   /* Text region bounds */
    int16_t  cur_y;             /* Current Y position in block */
    bool     active;            /* Currently inside a text block */
} rip_text_block_t;

typedef struct {
    /* 256-color VGA palette */
    uint8_t vga_palette[256];   /* Palette index → RGB332 mapping */
    bool    palette_custom;     /* true if palette has been modified */

    /* GUI widget state */
    bool    window_active;
    int16_t win_x, win_y, win_w, win_h;

    /* Scalable text */
    uint8_t text_scale;     /* 1-8x scale factor */
    int16_t text_rotation;  /* degrees */

    /* Extended button table */
    uint16_t num_buttons;

    /* v3.1: Overflow pagination */
    uint8_t *overflow_buf;        /* Arena-backed article buffer */
    uint32_t overflow_len;        /* Current article length */
    uint16_t overflow_page;       /* Current page number */
    uint16_t overflow_total;      /* Total pages */

    /* v3.1: Engine capabilities */
    uint8_t  caps_mask;           /* Capability bitmask */

    /* v3.1: Per-port extended attributes (36 slots, one per port index).
     * Added to match ripscrip2.c init/dispatch that references these arrays. */
    uint8_t  port_alpha[36];      /* 0=transparent, 35=fully opaque */
    uint8_t  port_comp_mode[36];  /* Compositing mode per port (0=COPY) */
    uint8_t  port_zorder[36];     /* Z-order per port */

    /* Level 2 resource-slot selection (added 2026-08-12).
     *
     * The driver keeps a table of slots for each of these resources and
     * switches between them with '|2A' / '|2B' / '|2E' / '|2T'.  RIPlib keeps
     * exactly ONE of each resource, so switching cannot swap a backing store;
     * what it can do is validate the slot the way the driver does ("Invalid
     * palette slot number", "Illegal button style slot number", …) and record
     * which slot the stream believes is active, so the selection is visible
     * to an embedder and does not silently vanish.
     *
     * This is a deliberate partial implementation, not a claim of parity —
     * see docs/spec §12.12. */
    uint8_t  cur_palette_slot;
    uint8_t  cur_button_style_slot;
    uint8_t  cur_environment_slot;
    uint8_t  cur_text_window_slot;
    uint8_t  cur_style_slot;      /* '|2Y' RIP_SwitchStyle — graphics style slot */

    /* SLOT PROTECTION.  Bit N of each mask means "slot N is protected";
     * a protected slot refuses modification, the way the driver's
     * "Can't modify current color palette - its protected!" path does.
     *
     * A stream sets these through the Switch* commands' second field,
     * which is a flags word and not the reserved pair this project used
     * to call it (14-divergence-register.md 14.3.6):
     *
     *     bit 2  protect the slot being LEFT
     *     bit 3  unprotect the slot being LEFT
     *     bit 0  protect the slot being ENTERED
     *     bit 1  unprotect the slot being ENTERED
     *
     * Driver side, verified at both ends: paletteSlotProtect() writes
     * <inst>+0x1A -> +5, stride 0x302, flag at +0x300 bit 0, slots
     * 1..36; the query at 0x10044508 reads it; '|Q' honours it.
     *
     * Everything starts unprotected, so these are inert until content
     * opts in -- exactly as the driver behaves, and why enabling this
     * changes nothing for the 35 corpus scenes. */
    uint64_t protected_palette;
    uint64_t protected_style;
    uint64_t protected_environment;
    uint64_t protected_text_window;
    uint64_t protected_button_style;
} ripscrip2_state_t;

/* ── Drawing Ports (v2.0 / v3.0) ─────────────────────────────────── *
 *
 * The spec defines 36 independent drawing surfaces (one per port slot).
 * RIPlib runs against a single shared framebuffer, so per-port pixel
 * data is not maintained — instead each port stores its drawing state
 * (clip region, color, line style, etc.) and that state is saved on
 * switch-away and restored on switch-in.  All drawing targets the
 * single framebuffer; the active port's viewport becomes the clip
 * rectangle.
 *
 * Port 0 is permanent: full-screen viewport, cannot be deleted,
 * allocated at rip_init_first() time.
 *
 * PORT_FLAG_* bits stored in rip_port_t.flags:
 *   bit 0 = RIP_PORT_FLAG_PROTECTED   — cannot be deleted or redefined
 *   bit 1 = RIP_PORT_FLAG_FULLSCREEN  — viewport covers entire screen
 */
#define RIP_MAX_PORTS              36
#define RIP_PORT_FLAG_PROTECTED    0x01
#define RIP_PORT_FLAG_FULLSCREEN   0x02
/* PERMANENT is not PROTECTED, and conflating them was a bug.  Port 0 cannot
 * be deleted or redefined, but it is NOT protected against modification --
 * all three '|v' RIP_ViewPort commands in IMAGES.RIP run with port 0 active
 * and the driver renders that scene, so a port-0-is-protected reading would
 * refuse content the driver accepts.
 *
 * The driver keeps them apart: '|v's query (0x10033821, with index -1
 * meaning "the current entry") tests a protected bit at +0x17 of a
 * 0x78-stride table, while delete and redefine refuse port 0 for a
 * different reason.  PROTECTED is set by CONTENT, through the Switch* flag
 * bits; PERMANENT belongs to slot 0 alone and no stream can set or clear
 * it. */
#define RIP_PORT_FLAG_PERMANENT    0x04

typedef struct {
    bool     allocated;          /* Port slot is in use */
    uint8_t  flags;              /* RIP_PORT_FLAG_* bitmask */

    /* Viewport — pixel coordinates (Y already scaled by scale_y() from
     * the EGA 350-row coordinate space the spec defines). */
    int16_t  vp_x0, vp_y0, vp_x1, vp_y1;

    /* Coordinate origin offset (v2.0 world-space translation; 0,0 normally) */
    int16_t  origin_x, origin_y;

    /* Saved drawing state — written on switch-away, loaded on switch-in */
    int16_t  draw_x, draw_y;     /* Per-port current drawing position */
    uint8_t  draw_color;
    uint8_t  fill_color;
    uint8_t  fill_pattern;
    uint8_t  back_color;
    uint8_t  write_mode;
    uint8_t  line_style;
    uint16_t line_pattern;
    uint8_t  line_thick;
    uint8_t  font_id;
    uint8_t  font_size;
    uint8_t  font_dir;
    uint8_t  font_hjust;   /* 0=left, 1=center, 2=right (v3.0 extension) */
    uint8_t  font_vjust;   /* 0=bottom, 1=center, 2=top, 3=baseline */
    uint8_t  font_attrib;  /* bit0=bold, bit1=italic, bit2=underline, bit3=shadow */
    uint8_t  font_ext_id;
    uint8_t  font_ext_attr;
    uint32_t font_ext_size;

    /* v3.1 extended attributes (set by !|2F port-flags command) */
    uint8_t  alpha;              /* 0=transparent, 35=fully opaque */
    uint8_t  comp_mode;          /* Compositing mode (0=COPY) */
    uint8_t  zorder;             /* Z-order for compositor layering */
} rip_port_t;

/* ─────────────────────────────────────────────────────────────────
 *  rip_state_t — INTERNAL by policy (ADR-0001, opaque-by-policy).
 *
 *  This struct is publicly visible for backwards compatibility, but
 *  its field layout is NOT part of the stable ABI.  Direct field
 *  access from consumer code is **discouraged** — use the public
 *  rip_*() API instead.
 *
 *  Why this matters:
 *    - Field order, types, and inclusion may change between
 *      minor releases.  A consumer that reads s->draw_color today
 *      may compile fine but read garbage tomorrow if the field
 *      moves, gets re-typed, or is replaced by a sub-struct.
 *    - The internal modules under src/ (rip_preproc.c,
 *      rip_variables.c, rip_clipboard.c, ripscrip2.c) DO touch
 *      fields directly; the library's own test suite also does
 *      extensive white-box assertions.  Both are inside the
 *      library's discipline boundary and accept the maintenance
 *      cost.  Code outside src/ and tests/ should not be.
 *    - A future major version will promote this struct to a true
 *      opaque type (see design/decisions.md C-003 → variant B,
 *      and design/adr/0001-rip-state-opaque-by-policy.md for the
 *      decision record).  Consumers doing direct field access
 *      today will be broken by that promotion; the lead time is
 *      this comment.
 *
 *  New fields added to this struct are INTERNAL by default.  If a
 *  new field needs to be visible to external consumers, add an
 *  explicit getter/setter to ripscrip.h and document it as part
 *  of the public API.
 * ───────────────────────────────────────────────────────────────── */

/* RIPscrip parser state */
struct rip_state_s {
    uint8_t  state;          /* Current FSM state (RIP_ST_* constants, 0-13) */
    uint8_t  prev_state;     /* Saved state for line-continuation restore */
    char     cmd_buf[1024];  /* Command parameter accumulator */
    uint16_t cmd_len;        /* Bytes used in cmd_buf; widened from uint8_t
                              * (C-014) so the type range cannot coincide
                              * with sizeof(cmd_buf) == 256 */
    char     cmd_char;       /* Current command letter */
    bool     is_level1;      /* Currently parsing a Level 1 command */
    bool     is_level2;      /* Currently parsing a Level 2 command */
    bool     is_level3;      /* Currently parsing a Level 3 command */

    /* Drawing state */
    int16_t  draw_x, draw_y; /* Current drawing position */
    uint8_t  draw_color;     /* Current drawing color (0-15) */
    uint8_t  back_color;     /* Background color index */
    uint8_t  write_mode;     /* 0=COPY, 1=XOR, 2=OR, 3=AND, 4=NOT
                              * (RIPscrip wire order; see drawing.h
                              * DRAW_MODE_* and docs/spec §2.3) */
    /* '|=' arg0: the off/draw selector that precedes the style.  Recorded
     * rather than applied -- the dash pattern RIPlib builds already carries
     * the on/off bits, and what the driver does with this field separately
     * has not been established. */
    uint8_t  line_off_draw;
    uint8_t  line_style;     /* 0=solid, 1=dotted, 2=center, 3=dashed, 4=user */
    uint16_t line_pattern;   /* Active 16-bit dash pattern passed to drawing.c */
    uint8_t  line_thick;     /* 1 or 3 */
    uint8_t  fill_pattern;   /* 0-11 predefined, 12=custom */
    uint8_t  fill_color;     /* Fill color index */
    uint8_t  font_id;        /* 0-10 */
    uint8_t  font_dir;       /* 0=horizontal, 1=vertical */
    uint8_t  font_size;      /* 1-10 */
    uint8_t  font_hjust;     /* 0=left, 1=center, 2=right (v3.0 ext) */
    uint8_t  font_vjust;     /* 0=bottom, 1=center, 2=top, 3=baseline */
    uint8_t  font_attrib;    /* bit0=bold, bit1=italic, bit2=underline,
                              * bit3=shadow.  Set by the 'q' command
                              * (RIP_FontAttrib).  NOTE: this was on 'f'
                              * until 2026-08-12; 'f' is RIP_SetWorldFrame
                              * in the shipping driver.  See docs/spec/
                              * 12-dll-provenance.md D-1. */
    uint8_t  font_ext_id;    /* RIP_EXT_FONT_STYLE: 2-digit font selector */
    uint8_t  font_ext_attr;  /* RIP_EXT_FONT_STYLE: 1-digit attribute */
    uint32_t font_ext_size;  /* RIP_EXT_FONT_STYLE: 4-digit point size */

    /* World coordinate frame (RIP_SET_WORLD_FRAME 'f').
     * The driver's handler (RVA 0x01F874) takes exactly two coordinate
     * values and rejects any other argument count.  The corpus standard
     * is '|fZKQO' = 1280x960.  RIPlib stores the frame but does not yet
     * apply a world->device transform; see docs/spec/12-dll-provenance.md
     * D-1.  Zero means "never set". */
    int16_t  world_w, world_h;

    /* RIP_TEXT_METRIC ('r').  The driver validates mode < 4 and
     * domain < 2 (RVA 0x020371) and computes a metric; the channel it
     * delivers the result on has not been recovered, so RIPlib records the
     * request rather than inventing one.  See docs/spec §12.12 D-5. */
    uint8_t  text_metric_mode;
    uint8_t  text_metric_domain;

    /* Level 3 state (added 2026-08-12 with the Level 3 dispatch).
     *
     * goto_url: the URL from '|3G' RIP_GotoURL, validated but NEVER acted on.
     * RIPlib does not launch URLs or spawn processes -- see the $GOTOURL$
     * policy note in ripscrip.c.  An embedder that wants click-through reads
     * this and applies its own policy.  Empty means "none received". */
    char     goto_url[128];
    /* Opt-in handler; NULL (the default) means the URL is stored only. */
    rip_url_handler_t url_handler;
    /* '|3U' RIP_BeginEncodedStream announcement. The payload format has not
     * been recovered, so the announcement is recorded, not decoded. */
    uint16_t encoded_stream_type;
    uint32_t encoded_stream_len;
    /* '|3e' RIP_BAUD_EMULATION — requested playback rate.  The driver
     * throttles rendering to simulate a slower link; RIPlib renders as fast
     * as its host drives it and applies no artificial delay, so the rate is
     * recorded for an embedder that wants to honour it.  0 = never set. */
    uint32_t baud_emulation;
    /* '|1A' RIP_SelectArticle — index 0..35 into the driver's 36-entry
     * article table.  Selecting an article is a session concept rather than
     * a rendering one, so RIPlib records the choice and emits nothing; an
     * embedder that presents documents can act on it.  0 = never set.
     *
     * This command was implemented as RIP_PLAY_AUDIO until 2026-08-14 and
     * pushed a sound request for text it read as a filename.  The handler
     * loads one argument, bounds it to 36 and names itself
     * RIP_SelectArticle; the driver's real audio command is '|1w'. */
    uint8_t  selected_article;
    /* '|1c' RIP_SetMouseCursor selection. RIPlib renders no pointer, so the
     * choice is recorded for an embedder that does. */
    uint8_t  mouse_cursor_id;

    /* Poly-bezier family pen state ('|t' '|x' '|z').  The driver's 5-char
     * signature is a move-to and its 13-char signature is a curve-to that
     * continues from wherever the pen is, so the current point has to
     * persist between commands.  See D-2 in docs/spec §12.12. */
    int16_t  bez_x, bez_y;
    bool     bez_valid;
    uint16_t bez_steps;

    /* RIP_EXTENDED_FONT_STYLE ('y') character spacing percentage.
     * Non-zero is enforced by the driver ("Character spacing percentage
     * cannot be zero!"). 0 means "never set". */
    uint16_t char_spacing;

    /* Extended text window state (RIP_EXT_TEXT_WINDOW 'b')
     *
     * CORRECTED 2026-08-14.  args[4] and args[5] were read as foreground and
     * background colours.  They are a CELL WIDTH and HEIGHT: slot 20's
     * handler rejects either being zero with "Zero width value is not
     * allowed" / "Zero height value is not allowed", which is not something
     * a colour index would say.  args[7] was read as a font size; it is the
     * FLAGS word, bounded to 0x3FF with "Flags value is out of range".
     *
     * Nothing rendered from the mistake -- etw_fore_col and etw_back_col
     * were written here and read nowhere -- and no corpus scene sends '|b',
     * so the correction is inert.  It is still a correction: the fields now
     * hold what the driver says they hold. */
    uint8_t  etw_font_id;    /* Font ID for extended text window */
    uint16_t etw_cell_w;     /* Cell width  (args[4]); zero is refused */
    uint16_t etw_cell_h;     /* Cell height (args[5]); zero is refused */
    uint32_t etw_flags;      /* args[7], bounded to 0x3FF by the driver */

    /* Text window */
    int16_t  tw_x0, tw_y0, tw_x1, tw_y1;
    uint8_t  tw_wrap;
    uint8_t  tw_font_size;
    int16_t  tw_cur_x, tw_cur_y;   /* Pixel cursor within text window */
    bool     tw_active;             /* true when non-default text window set */

    /* Viewport (clip region) */
    int16_t  vp_x0, vp_y0, vp_x1, vp_y1;

    /* Mouse regions */
    rip_mouse_region_t mouse_regions[RIP_MAX_MOUSE_REGIONS];
    uint16_t num_mouse_regions;  /* Fix S5/FB-4: uint8_t wraps at 256, bypassing the 128 limit check */

    /* 16-color EGA palette → card palette index mapping */
    uint8_t  palette[16];

    /* Saved hardware palette RGB565 values for indices 240-255.
     * Populated by rip_save_palette() before protocol deactivation so that
     * rip_apply_palette() can restore BBS-customized colors (not just EGA
     * defaults) when switching back from VT100 or another protocol. */
    uint16_t saved_palette_rgb565[16];

    /* Level 1 state */
    rip_button_style_t button_style;   /* Current button style (set by 1B) */
    rip_clipboard_t    clipboard;      /* Image clipboard (GET/PUT_IMAGE) */
    rip_icon_t         icon_slots[RIP_ICON_SLOT_MAX];  /* SAVE_ICON slot table */
    bool               icon_slot_valid[RIP_ICON_SLOT_MAX];
    rip_text_block_t   text_block;     /* Active text block (1T/1t/1E) */
    rip_icon_state_t   icon_state;     /* Session-scoped runtime icon cache + request queue */
    ripscrip2_state_t  rip2_state;     /* Per-session RIPscrip 2.0 / v3.x state */

    /* Previous byte received in PASSTHROUGH state — needed for the
     * '!' line-boundary check (see §1.8). */
    uint8_t  last_char;

    /* ESC[! auto-detect tracking (Synchronet sends this to probe for RIP) */
    uint8_t  esc_detect;               /* 0=idle, 1=got ESC, 2=got ESC[ */
    /* NOT IMPLEMENTED.  Intended to accept a UTF-8 transcoded introducer,
     * where '|' has become U+00A6 (0xC2 0xA6).  Nothing in the FSM ever
     * sets or reads this, so a stream using the broken bar is not
     * recognised.  See docs/spec/12-dll-provenance.md D-13. */
    bool     utf8_pipe_pending;
    bool     rip_has_drawn;            /* true after RIP cmds draw; cleared by '*' reset */
    bool     cursor_repositioned;     /* true after VT100 cursor moved to bottom for status bar */

    /* E4: <<IF>>/<<ELSE>>/<<ENDIF>> pre-processor state (IDLE/PASSTHROUGH).
     * Directives are detected before normal byte routing.  When preproc_suppress
     * is true all output bytes (and command bytes) are swallowed except for
     * additional << directive starts needed to maintain nesting depth. */
    uint8_t  preproc_state;    /* 0=normal, 1=got first '<', 2=collecting, 3=got first '>' */
    char     preproc_buf[32];  /* Directive name accumulator */
    uint8_t  preproc_len;      /* Bytes written into preproc_buf */
    bool     preproc_suppress; /* true = inside false <<IF>> branch — suppress output */
    uint8_t  preproc_depth;    /* Active stack depth, capped at RIP_PREPROC_MAX_DEPTH */
    uint16_t preproc_overflow; /* Nested levels beyond RIP_PREPROC_MAX_DEPTH; widened
                                * from uint8_t per audit C-007: at uint8_t the counter
                                * wrapped after 256 over-deep <<IF>>s, letting suppressed
                                * branches resume. uint16_t + saturation in the increment
                                * site (src/ripscrip.c) makes overflow non-reachable for
                                * any realistic adversarial stream. */
    bool     preproc_parent_suppress[RIP_PREPROC_MAX_DEPTH];
    bool     preproc_branch_active[RIP_PREPROC_MAX_DEPTH];
    bool     preproc_branch_taken[RIP_PREPROC_MAX_DEPTH];

    /* v3.1: Application variables */
    char app_vars[10][32];   /* $APP0$ through $APP9$ */
    char user_var_names[RIP_USER_VAR_MAX][RIP_USER_VAR_NAME_MAX + 1];
    char user_var_values[RIP_USER_VAR_MAX][RIP_USER_VAR_VALUE_MAX + 1];
    uint8_t user_var_count;

    /* Scene/protocol mode metadata.  The framebuffer remains indexed
     * 640x400, but these fields track the RIPscrip v2.x mode commands
     * so text variables and state save/restore can report them accurately. */
    uint8_t header_type;
    uint32_t header_id;
    uint8_t header_flags;
    uint8_t resolution_mode;
    uint8_t coordinate_size;      /* RIP_SET_COORDINATE_SIZE byte size, default 2 */
    uint32_t coordinate_res;      /* reserved/extension field from '|n' */
    uint8_t color_mode;           /* 0=palette mapping, 1=direct RGB encoding */
    uint8_t color_bits;           /* RGB bits/component when color_mode != 0 */
    bool filled_borders_enabled;  /* RIP_SET_BORDER, default enabled */

    /* Host-supplied date/time (CB_GET_TIME callback equivalent).
     * Populated one byte at a time via rip_sync_date_byte() /
     * rip_sync_time_byte() — a host that has access to a wall-clock
     * source (e.g. the user's host computer's RTC) pushes
     * "MM/DD/YY\0" and "HH:MM:SS\0" through those entrypoints, and
     * the strings are then used by $DATE$ / $TIME$ expansion in
     * preference to the local time() / localtime() fallback.
     * Empty strings → local time fallback. */
    char host_date[12];   /* "MM/DD/YY" supplied by the host (NUL-terminated) */
    char host_time[12];   /* "HH:MM:SS" supplied by the host (NUL-terminated) */

    /* In-progress accumulator for the rip_sync_date_byte() /
     * rip_sync_time_byte() per-byte host callbacks.  Bytes are
     * appended one at a time; the accumulator is committed to
     * host_date / host_time on the NUL terminator. */
    char sync_date_buf[12];   /* staging buffer — written to host_date on NUL */
    uint8_t sync_date_len;
    char sync_time_buf[12];   /* staging buffer — written to host_time on NUL */
    uint8_t sync_time_len;

    /* $QUERY$ round-trip state (CB_INPUT_TEXT equivalent).
     * When the parser encounters a RIP_QUERY command requiring user
     * text input it sets query_pending, pushes a CMD_QUERY_PROMPT
     * stream via the TX FIFO, and pauses variable expansion.  The
     * host sends back the typed response via rip_query_response_byte()
     * one byte per call; on the NUL terminator the response is stored
     * in the target user variable and query_pending is cleared.
     * query_response is the staging accumulator. */
    bool    query_pending;         /* true while waiting for host response */
    char    query_var_name[32];    /* $APPn$ or generic variable being queried */
    char    query_response[RIP_USER_VAR_VALUE_MAX + 1]; /* incoming response accumulator */
    uint8_t query_response_len;

    /* Per-session PSRAM arena — 1 MB reserved once at boot by
     * rip_init_first(), reset on BBS disconnect by rip_session_reset().
     * Never reset on a mid-session protocol switch (rip_activate). */
    psram_arena_t psram_arena;

    /* Per-session file-upload staging for dynamic BMP/ICN cache fills. */
    uint8_t *upload_buf;
    int      upload_pos;
    char     upload_name[16];
    int      upload_name_len;
    uint8_t  upload_name_remaining;
    bool     upload_name_overflow;
    bool     upload_reading_name;

    /* $RAND$ LCG seed — seeded at rip_init_first() time.
     * Uses the same Knuth/POSIX LCG as MSVC rand(): multiplier
     * 1103515245, addend 12345.  Same per-session sequence given the
     * same seed (see test_rand_reproducibility). */
    uint32_t rand_state;

    /* $NOREFRESH$ / $REFRESH$ suppress-refresh flag.
     * When true, the BBS has requested that the host suppress automatic
     * screen refresh while compositing a complex scene.  $REFRESH$
     * clears it and marks all rows dirty (CB_REFRESH equivalent). */
    bool refresh_suppress;

    /* 1N RIP_SET_ICON_DIR — icon search path override.
     * Consumers that have a real filesystem can honor the path; those
     * that use a flat icon archive (no real FS) store it as a tag for
     * future dynamic icon requests but otherwise ignore it.
     * SECURITY (C-013/ADR-0003): the stored path is conservatively
     * filtered at ingest via rip_dirpath_is_safe (rejects '..', control
     * chars, '\\', ':'), but a consumer that opens it MUST still treat it
     * as untrusted input — RIPlib does not own the filesystem. */
    char icon_dir[64];

    /* 1S RIP_IMAGE_STYLE — image display mode (0=stretch, 1=tile,
     * 2=center).  Stored so subsequent icon-load / PUT_IMAGE calls
     * can honour the BBS-requested presentation. */
    uint8_t image_style;
    /* MegaNum radix selected by '|J' RIP_SET_BASE_MATH: 36 or 64.  Recorded
     * for capability queries; the decoders are base 36 unconditionally
     * because the base-64 digit alphabet has not been recovered.  See
     * docs/spec/12-dll-provenance.md D-10. */
    uint8_t mega_base;
    /* '|2R' RIP_SetRefresh reserved field (slot 117, one mega4). */
    uint32_t refresh_res;
    /* '|3D' RIP_DELAY request, in sixtieths of a second.  RIPlib never
     * blocks; read and clear it with rip_take_delay(). */
    uint32_t delay_ticks;
    /* Set when '|n' requested a coordinate width RIPlib cannot decode
     * (anything but 2).  Everything parsed after that point is unreliable,
     * so a host that cares should stop rather than render it.  See
     * docs/spec/12-dll-provenance.md D-11. */
    bool coord_size_unsupported;

    /* RIP_ICON_STYLE ('&') parameters for subsequent icon rendering.
     * Coordinates are stored in pixels.  style follows 1S where possible:
     * 0=stretch-to-box, 1=tile, 2=center, 3=proportional fit. */
    bool     icon_style_active;
    int16_t  icon_style_x0, icon_style_y0, icon_style_x1, icon_style_y1;
    uint8_t  icon_style_style;
    uint8_t  icon_style_align;
    uint8_t  icon_style_scale;

    /* 1V extended viewport scale factor (0=none, 1-35 in MegaNum).
     * Stored alongside the viewport rect for state introspection and
     * for host-side scaling on renderers that support it. */
    uint8_t viewport_scale;

    /* ── Drawing Ports (v2.0 / v3.0) ─────────────────────────────── *
     * Port 0 is always allocated (full-screen, permanent).
     * Ports 1-35 are created on demand by !|2P and destroyed by !|2p.
     * active_port tracks the current drawing port (0-35).
     * On switch: active port's drawing fields are snapshotted into
     * ports[active_port], then new port's fields are loaded back into
     * the rip_state_t drawing fields and its viewport clip is applied. */
    rip_port_t ports[RIP_MAX_PORTS];
    uint8_t    active_port;           /* Index of current active port (0-35) */

    /* §A2G (v3.2): state push/pop stack (|^ pushes, |~ pops).
     * Captures the drawing fields a BBS most often wraps a styled draw in:
     * colors, write/fill/line state, font fields, draw cursor, viewport.
     * Stack is bounded (8 frames); overflow silently drops the push, and
     * pop on empty is a no-op. */
    struct {
        uint8_t draw_color, back_color, fill_color, fill_pattern;
        uint8_t line_style, line_thick, write_mode;
        uint16_t line_pattern;
        uint8_t font_id, font_size, font_dir, font_attrib;
        uint8_t font_hjust, font_vjust;
        uint8_t font_ext_id, font_ext_attr;
        uint32_t font_ext_size;
        bool filled_borders_enabled;
        int16_t draw_x, draw_y;
        int16_t vp_x0, vp_y0, vp_x1, vp_y1;
    } state_stack[8];
    uint8_t state_stack_depth;
};

#define RIP_STATE_STACK_MAX 8

/* Map a BGI fill style (0=EMPTY .. 12=USER) to the card-native fill
 * pattern index used by drawing.c::fill_span().  Returns -1 for EMPTY
 * (caller must skip the fill entirely). */
int8_t rip_bgi_fill_to_card(uint8_t bgi_style);

/* Boot-time init — call ONCE at power-on.
 * Does memset, arena reservation, BGI font parse, and drawing defaults.
 *
 * CONTRACT: caller MUST zero `*s` (e.g. via memset, calloc, or static
 * storage) before the FIRST call.  The implementation snapshots the
 * existing psram_arena before memset so re-initialization does not
 * leak the allocated block; that snapshot reads from `*s` and would
 * be UB on uninitialized memory. */
void rip_init_first(rip_state_t *s);

/* Protocol-switch activation — called every time the host's compositor
 * switches to RIPscrip.  Restores the EGA palette and marks the
 * framebuffer dirty.  Does NOT memset or touch session state. */
void rip_activate(rip_state_t *s);

/* Session disconnect reset — call on BBS disconnect.
 * Resets the PSRAM arena, clears mouse regions, text variables,
 * query state, icon request queue, and upload staging.
 * Does NOT re-init drawing defaults (rip_init_first already did that). */
void rip_session_reset(rip_state_t *s);

void rip_process(rip_state_t *s, void *ctx, uint8_t ch);

/* Stateful host-event helpers for multi-session integrations.  This is
 * the complete reentrant surface: every globals-based wrapper further
 * down has a fully reentrant *_state() form declared here. */
void rip_mouse_event_state(rip_state_t *s, int16_t x, int16_t y, bool clicked);
void rip_file_upload_begin_state(rip_state_t *s, uint8_t name_len);
void rip_file_upload_byte_state(rip_state_t *s, uint8_t data_byte);
void rip_file_upload_end_state(rip_state_t *s);
void rip_sync_date_byte_state(rip_state_t *s, uint8_t data_byte);      /* CB_GET_TIME date half */
void rip_sync_time_byte_state(rip_state_t *s, uint8_t data_byte);      /* CB_GET_TIME time half */
void rip_query_response_byte_state(rip_state_t *s, uint8_t data_byte); /* CB_INPUT_TEXT */
void rip_apply_palette_state(rip_state_t *s);                          /* palette coexistence */

/* Single-session host-event wrappers.  Route through the global
 * g_rip_state set by the most recent rip_init_first() call.
 * Convenient for the common embedded case where one BBS connection
 * drives one RIPlib instance; **not thread-safe and not
 * multi-session safe** — see the SESSION SAFETY note at the top of
 * this header.  Use the *_state() variants above for multi-session
 * deployments. */
void rip_mouse_event_ext(int16_t x, int16_t y, bool clicked);
void rip_file_upload_begin(uint8_t name_len);
void rip_file_upload_byte(uint8_t data_byte);
void rip_file_upload_end(void);

/* Host callback shims — these accumulate one byte per call and commit
 * on the NUL terminator, letting a host without a true callback API
 * still feed responses to RIPscrip's CB_GET_TIME / CB_INPUT_TEXT
 * surfaces.  They operate on the single active session (set by the
 * most recent rip_init_first), which makes them convenient for
 * single-session embedders but unsafe for multi-session ones — see
 * the *_state() variants above. */
void rip_sync_date_byte(uint8_t data_byte);      /* CB_GET_TIME date half */
void rip_sync_time_byte(uint8_t data_byte);      /* CB_GET_TIME time half */
void rip_query_response_byte(uint8_t data_byte); /* CB_INPUT_TEXT */

/* Palette coexistence helpers — called by the host's compositor on
 * protocol switch.  rip_save_palette() snapshots hardware indices
 * 240-255 into s->saved_palette_rgb565 so BBS-customized colors (set
 * via RIP_SET_PALETTE / RIP_ONE_PALETTE) survive a temporary switch
 * to VT100 or another protocol.  rip_apply_palette() writes
 * saved_palette_rgb565 back to hardware; falls back to EGA defaults
 * if no snapshot has been taken yet.
 *
 * rip_save_palette(s) and rip_apply_palette_state(s) (declared above
 * with the reentrant family) form the explicit-state pair;
 * rip_apply_palette() is the single-session wrapper over g_rip_state.
 * See SESSION SAFETY below. */
void rip_save_palette(rip_state_t *s);
void rip_apply_palette(void);

/* ── SESSION SAFETY ─────────────────────────────────────────────── *
 *
 * RIPlib is **single-session by design**.  Every public entrypoint
 * comes in two flavours:
 *
 *   1. *_state(rip_state_t *s, ...) — explicit state, fully reentrant
 *      across distinct rip_state_t instances.  Use these in any
 *      multi-session embedding (e.g. a multi-line BBS server, an
 *      emulator with several virtual machines, a test harness
 *      running parallel sessions).
 *
 *   2. globals-based variants (rip_mouse_event_ext, rip_file_upload_*,
 *      rip_sync_date_byte, rip_sync_time_byte, rip_query_response_byte,
 *      rip_apply_palette) — operate on the **single global session**
 *      set by the most recent rip_init_first() call.  These exist for
 *      embedded targets where there really is only one BBS connection
 *      ever.  They are NOT thread-safe and they are NOT multi-session
 *      safe; calling rip_init_first(&sessionB) silently flips the
 *      global pointer away from sessionA, so any subsequent globals-
 *      based call will operate on the wrong session.
 *
 * Embedders running more than one concurrent session MUST use only
 * the *_state() variants, or serialise all calls behind a single
 * mutex.  Auditing whether this constraint should be relaxed (i.e.,
 * is multi-session a real scenario worth a breaking API change?) is
 * tracked as `design/decisions.md` candidate C-004.
 */

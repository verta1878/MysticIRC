/*
 * ripscrip2.c -- RIPscrip 2.0+ protocol extensions for RIPlib
 *
 * TeleGrafix Communications, 1994-1997.  Extends v1.54 with 256-color
 * VGA, scalable text, GUI widgets, gradient fills, and the Drawing
 * Ports system (v2.0/v3.0).  Also implements the v3.x §A2G extensions
 * (see docs/spec/06-v31-extensions.md and 06a-v32-extensions.md).
 *
 * Level 2 command dispatch (called from ripscrip.c on '2' prefix):
 *
 *   Drawing Port commands (v2.0/v3.0):
 *     'P'  RIP_DEFINE_PORT   -- create/redefine a port with viewport rect
 *     'p'  RIP_DELETE_PORT   -- deallocate a port
 *     's'  RIP_SWITCH_PORT   -- switch the active drawing port
 *     'C'  RIP_PORT_COPY     -- blit pixels between port viewports
 *     'F'  RIP_PORT_FLAGS    -- set extended attributes (alpha/comp/zorder)
 *
 *   Other 2.0 commands:
 *     '0'  Set VGA palette entry
 *     '8'  Gradient fill
 *     '6'  Scalable text
 *     '2'  Define window region
 *     'R'  Host-triggered screen refresh
 *     'c'  Chord drawing (lowercase -- 'C' is now PORT_COPY)
 *
 * Port implementation notes (single-framebuffer architecture):
 *
 *   The spec defines 36 independent drawing surfaces; RIPlib runs
 *   against a single shared framebuffer with no off-screen surfaces.
 *   The port system instead:
 *     - Stores per-port drawing state (clip region, color, fill, etc.)
 *     - Saves/restores that state on port switch
 *     - Applies the new port's viewport as the hardware clip rectangle
 *       via draw_set_clip()
 *     - draw_copy_rect() implements port-to-port pixel copy within the
 *       single shared framebuffer
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License. See LICENSE.
 */

#include "ripscrip2.h"
#include "riplib_platform.h"
#include "drawing.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

extern void palette_write_rgb565(uint8_t index, uint16_t rgb565);
extern void riplib_host_tx(const char *buf, int len);

#define RIP2_PI_F 3.14159265358979323846f

static int16_t rip2_round_to_i16(float v) {
    return (int16_t)(v >= 0.0f ? v + 0.5f : v - 0.5f);
}

static void rip2_circle_point(int16_t cx, int16_t cy, int16_t r,
                              int16_t deg, int16_t *ox, int16_t *oy) {
    int d = deg % 360;
    float rad;

    if (d < 0)
        d += 360;
    rad = (float)d * (RIP2_PI_F / 180.0f);
    *ox = (int16_t)(cx + rip2_round_to_i16(cosf(rad) * (float)r));
    *oy = (int16_t)(cy - rip2_round_to_i16(sinf(rad) * (float)r));
}

static uint8_t rip2_rgb332_r(uint8_t rgb) {
    return (uint8_t)((((rgb >> 5) & 0x07u) * 255u) / 7u);
}

static uint8_t rip2_rgb332_g(uint8_t rgb) {
    return (uint8_t)((((rgb >> 2) & 0x07u) * 255u) / 7u);
}

static uint8_t rip2_rgb332_b(uint8_t rgb) {
    return (uint8_t)(((rgb & 0x03u) * 255u) / 3u);
}

static uint8_t rip2_nearest_palette_index(const ripscrip2_state_t *s,
                                          uint8_t rgb332) {
    int best_idx = 0;
    int best_dist = 32767;
    int tr = (rgb332 >> 5) & 7;
    int tg = (rgb332 >> 2) & 7;
    int tb = rgb332 & 3;

    for (int i = 0; i < 256; i++) {
        uint8_t pal = s->vga_palette[i];
        int dr = ((pal >> 5) & 7) - tr;
        int dg = ((pal >> 2) & 7) - tg;
        int db = (pal & 3) - tb;
        int dist = dr * dr * 4 + dg * dg * 4 + db * db * 9;
        if (dist < best_dist) {
            best_dist = dist;
            best_idx = i;
            if (dist == 0)
                break;
        }
    }
    return (uint8_t)best_idx;
}

static bool rip2_clipboard_alloc(rip_state_t *rs) {
    if (!rs)
        return false;
    if (!rs->clipboard.data) {
        rs->clipboard.data = (uint8_t *)psram_arena_alloc(&rs->psram_arena,
                                                          RIP_CLIPBOARD_MAX);
    }
    return rs->clipboard.data != NULL;
}

static bool rip2_clipboard_capture(rip_state_t *rs,
                                   int16_t x, int16_t y,
                                   int16_t w, int16_t h) {
    size_t bytes;

    if (!rs || w <= 0 || h <= 0)
        return false;
    bytes = (size_t)(uint16_t)w * (size_t)(uint16_t)h;
    if (bytes == 0 || bytes > RIP_CLIPBOARD_MAX)
        return false;
    if (!rip2_clipboard_alloc(rs))
        return false;

    draw_save_region(x, y, w, h, rs->clipboard.data);
    rs->clipboard.width = w;
    rs->clipboard.height = h;
    rs->clipboard.valid = true;
    return true;
}

static void rip2_blit_pixels(rip_state_t *rs,
                             int16_t dx, int16_t dy,
                             const uint8_t *pixels,
                             uint16_t src_w, uint16_t src_h,
                             int16_t dst_w, int16_t dst_h,
                             uint8_t write_mode) {
    uint8_t old_color;

    if (!pixels || src_w == 0 || src_h == 0 || dst_w <= 0 || dst_h <= 0)
        return;
    if (write_mode > DRAW_MODE_NOT)
        write_mode = DRAW_MODE_COPY;

    old_color = draw_get_color();
    draw_set_write_mode(write_mode);
    if (dst_w == (int16_t)src_w && dst_h == (int16_t)src_h) {
        draw_restore_region(dx, dy, dst_w, dst_h, pixels);
    } else {
        for (int16_t yy = 0; yy < dst_h; yy++) {
            uint16_t sy = (uint16_t)(((uint32_t)(uint16_t)yy * src_h) /
                                     (uint16_t)dst_h);
            for (int16_t xx = 0; xx < dst_w; xx++) {
                uint16_t sx = (uint16_t)(((uint32_t)(uint16_t)xx * src_w) /
                                         (uint16_t)dst_w);
                draw_set_color(pixels[(size_t)sy * src_w + sx]);
                draw_pixel((int16_t)(dx + xx), (int16_t)(dy + yy));
            }
        }
    }
    draw_set_write_mode(rs ? rs->write_mode : DRAW_MODE_COPY);
    draw_set_color(old_color);
}

static void rip2_copy_scaled(rip_state_t *rs,
                             int16_t sx, int16_t sy,
                             int16_t sw, int16_t sh,
                             int16_t dx, int16_t dy,
                             int16_t dw, int16_t dh,
                             uint8_t write_mode) {
    size_t bytes;
    uint8_t *scratch;

    if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0)
        return;
    if (write_mode > DRAW_MODE_NOT)
        write_mode = DRAW_MODE_COPY;

    if (sw == dw && sh == dh && write_mode == DRAW_MODE_COPY) {
        draw_copy_rect(sx, sy, dx, dy, sw, sh);
        return;
    }

    bytes = (size_t)(uint16_t)sw * (size_t)(uint16_t)sh;
    if (bytes == 0)
        return;
    scratch = (uint8_t *)malloc(bytes);
    if (!scratch)
        return;

    draw_save_region(sx, sy, sw, sh, scratch);
    rip2_blit_pixels(rs, dx, dy, scratch, (uint16_t)sw, (uint16_t)sh,
                     dw, dh, write_mode);
    free(scratch);
}

/* =====================================================================
 * MegaNum helpers (local -- not exported from ripscrip.c)
 * ===================================================================== */

static inline int mega_dig(char ch) {
    if (ch >= '0' && ch <= '9') return ch - '0';
    if (ch >= 'A' && ch <= 'Z') return ch - 'A' + 10;
    if (ch >= 'a' && ch <= 'z') return ch - 'a' + 10;
    return 0;
}

/* 1-digit MegaNum: single base-36 character, value 0-35 */
static inline int mega1(const char *p) {
    return mega_dig(p[0]);
}

/* 2-digit MegaNum: two base-36 characters, value 0-1295 */
static inline int mega2l(const char *p) {
    return mega_dig(p[0]) * 36 + mega_dig(p[1]);
}

/* Four-digit MegaNum.  Needed because several Level 2 records type a field
 * as mega4, and reading only its first two digits takes the HIGH half --
 * the opposite of the low-order bits a flags word actually carries. */
static inline long mega4l(const char *p) {
    return ((long)mega_dig(p[0]) * 46656L) + ((long)mega_dig(p[1]) * 1296L)
         + ((long)mega_dig(p[2]) * 36L)    + (long)mega_dig(p[3]);
}

/* Scale RIPscrip EGA Y-coordinate (0-349) to card display Y (0-399).
 * MUST match ripscrip.c::scale_y so the same EGA coord lands on the
 * same card pixel whether reached via Level 0 or Level 2 commands. */
static inline int16_t scale_y(int16_t y) {
    return (int16_t)((y * 8) / 7);
}

/* Scale Y for bottom edges -- ceiling so adjacent rects touch.
 * Matches ripscrip.c::scale_y1. */
static inline int16_t scale_y1(int16_t y) {
    return (int16_t)((y * 8 + 6) / 7);
}

static void clamp_ega_rect(int16_t *x0, int16_t *y0,
                           int16_t *x1, int16_t *y1) {
    int16_t tx0 = *x0, ty0 = *y0, tx1 = *x1, ty1 = *y1;
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

/* Delegate to the canonical implementation in ripscrip.c so the BGI →
 * card pattern mapping has one source of truth. */
static int8_t bgi_fill_to_card(uint8_t bgi_style) {
    return rip_bgi_fill_to_card(bgi_style);
}


/* =====================================================================
 * ripscrip2_init
 * ===================================================================== */

void ripscrip2_init(ripscrip2_state_t *s) {
    memset(s->vga_palette, 0, sizeof(s->vga_palette));
    s->palette_custom = false;
    s->window_active  = false;
    s->win_x  = 0;
    s->win_y  = 0;
    s->win_w  = 640;
    s->win_h  = 400;
    s->text_scale    = 1;
    s->text_rotation = 0;
    s->num_buttons   = 0;

    /* Overflow pagination */
    s->overflow_buf   = NULL;
    s->overflow_len   = 0;
    s->overflow_page  = 0;
    s->overflow_total = 0;

    /* Engine capabilities */
    s->caps_mask = 0x7F;

    /* Per-port extended attributes (backward compat mirror; authoritative
     * values live in rip_port_t.alpha / .comp_mode / .zorder).
     *
     * Match rip_init_first()'s rip_port_t initialization:
     *   port 0       : alpha=35 (fully opaque), comp=0, z=0   — protected fullscreen
     *   ports 1..35  : alpha=0 (transparent),   comp=0, z=0   — unallocated
     *
     * Previously this loop wrote alpha=35 to all 36 slots, diverging from
     * rip_port_t for the unallocated ports.  !|2F (RIP_PORT_FLAGS) keeps
     * both sides in sync after that. */
    memset(s->port_alpha,     0, sizeof(s->port_alpha));
    memset(s->port_comp_mode, 0, sizeof(s->port_comp_mode));
    memset(s->port_zorder,    0, sizeof(s->port_zorder));
    s->port_alpha[0] = 35;

    /* Default VGA palette: first 16 = EGA colors as RGB332 */
    static const uint8_t ega16[16] = {
        0x00, 0x02, 0x10, 0x12, 0x80, 0x82, 0x90, 0xB6,
        0x49, 0x03, 0x1C, 0x1F, 0xE0, 0xE3, 0xFC, 0xFF
    };
    memcpy(s->vga_palette, ega16, 16);

    /* Colors 16-255: RGB332 identity */
    for (int i = 16; i < 256; i++)
        s->vga_palette[i] = (uint8_t)i;
}


/* =====================================================================
 * PORT SYSTEM INTERNALS
 *
 * All helpers operate on rs->ports[] in rip_state_t.  They are called
 * only from ripscrip2_execute().
 * ===================================================================== */

/*
 * port_save_state -- snapshot rip_state_t drawing fields into ports[idx].
 *
 * Called before switching away from the active port so its drawing
 * state is preserved for when it becomes active again.
 *
 * The viewport rect (vp_x0/y0/x1/y1) is authoritative in rip_port_t
 * and is NOT copied back from rip_state_t -- all viewport-setting
 * commands (RIP_VIEWPORT 'v', !|2P) write to both simultaneously.
 */
static void port_save_state(rip_state_t *rs, uint8_t idx)
{
    rip_port_t *p = &rs->ports[idx];
    p->draw_x       = rs->draw_x;
    p->draw_y       = rs->draw_y;
    p->draw_color   = rs->draw_color;
    p->fill_color   = rs->fill_color;
    p->fill_pattern = rs->fill_pattern;
    p->back_color   = rs->back_color;
    p->write_mode   = rs->write_mode;
    p->line_style   = rs->line_style;
    p->line_pattern = rs->line_pattern;
    p->line_thick   = rs->line_thick;
    p->font_id      = rs->font_id;
    p->font_size    = rs->font_size;
    p->font_dir     = rs->font_dir;
    p->font_hjust   = rs->font_hjust;
    p->font_vjust   = rs->font_vjust;
    p->font_attrib  = rs->font_attrib;
    p->font_ext_id   = rs->font_ext_id;
    p->font_ext_attr = rs->font_ext_attr;
    p->font_ext_size = rs->font_ext_size;
}

/*
 * port_load_state -- restore rip_state_t drawing fields from ports[idx]
 * and apply the port's viewport as the hardware clip rectangle.
 *
 * Called after switching to a new port.
 */
static void port_load_state(rip_state_t *rs, uint8_t idx)
{
    rip_port_t *p = &rs->ports[idx];
    int8_t card_pat;

    rs->draw_x       = p->draw_x;
    rs->draw_y       = p->draw_y;
    rs->draw_color   = p->draw_color;
    rs->fill_color   = p->fill_color;
    rs->fill_pattern = p->fill_pattern;
    rs->back_color   = p->back_color;
    rs->write_mode   = p->write_mode;
    rs->line_style   = p->line_style;
    rs->line_pattern = p->line_pattern;
    rs->line_thick   = p->line_thick;
    rs->font_id      = p->font_id;
    rs->font_size    = p->font_size;
    rs->font_dir     = p->font_dir;
    rs->font_hjust   = p->font_hjust;
    rs->font_vjust   = p->font_vjust;
    rs->font_attrib  = p->font_attrib;
    rs->font_ext_id   = p->font_ext_id;
    rs->font_ext_attr = p->font_ext_attr;
    rs->font_ext_size = p->font_ext_size;

    /* Sync rip_state_t viewport from port */
    rs->vp_x0 = p->vp_x0;
    rs->vp_y0 = p->vp_y0;
    rs->vp_x1 = p->vp_x1;
    rs->vp_y1 = p->vp_y1;

    /* Apply viewport as hardware clip rectangle */
    draw_set_clip(p->vp_x0, p->vp_y0, p->vp_x1, p->vp_y1);

    /* Sync draw layer state */
    draw_set_color(rs->palette[p->draw_color & 0x0F]);
    draw_set_write_mode(p->write_mode);
    draw_set_pos(p->draw_x, p->draw_y);
    draw_set_line_style(p->line_pattern, p->line_thick);
    card_pat = bgi_fill_to_card(p->fill_pattern);
    draw_set_fill_style((card_pat >= 0) ? (uint8_t)card_pat : 0,
                        rs->palette[p->back_color & 0x0F]);
}

/*
 * port_set_defaults -- initialize a newly-allocated port's drawing state
 * to the RIPscrip v1.54 defaults (matching DLL RIP_SetDefaultSettings).
 * Viewport is set by the caller from command arguments.
 */
static void port_set_defaults(rip_port_t *p)
{
    p->draw_x       = 0;
    p->draw_y       = 0;
    p->draw_color   = 15;  /* white  -- DLL GFXSTYLE+0x00 = 0x0F */
    p->fill_color   = 15;  /* white  -- DLL GFXSTYLE+0x1A = 0x0F */
    p->fill_pattern = 1;   /* solid */
    p->back_color   = 0;   /* black  -- DLL GFXSTYLE+0x02 = 0x00 */
    p->write_mode   = 0;   /* COPY */
    p->line_style   = 0;   /* solid */
    p->line_pattern = 0xFFFF;
    p->line_thick   = 1;   /* 1 pixel */
    p->font_id      = 0;
    p->font_size    = 1;
    p->font_dir     = 0;   /* horizontal */
    p->font_hjust   = 0;
    p->font_vjust   = 0;
    p->font_attrib  = 0;
    p->font_ext_id  = 0;
    p->font_ext_attr = 0;
    p->font_ext_size = 0;
    p->origin_x     = 0;
    p->origin_y     = 0;
    p->alpha        = 35;  /* fully opaque */
    p->comp_mode    = 0;   /* COPY */
    p->zorder       = 0;
}

/*
 * rip_port_create -- allocate a port and set its viewport rectangle.
 *
 * Mirrors DLL portInit / sub_03326F behavior:
 *   - Rejects port 0 (permanent, cannot be redefined by BBS)
 *   - Rejects protected ports
 *   - If the slot is already allocated, clears existing state first
 *   - Viewport coordinates are in EGA (640x350) space; scaled here
 *
 * port_flags bits (from !|2P command, 4-digit MegaNum):
 *   bit 0 (1) = clipboard/offscreen port (informational on single-framebuffer targets)
 *   bit 1 (2) = make active immediately  (handled by caller)
 *   bit 2 (4) = deactivate viewport on create (set fullscreen flag)
 *   bit 3 (8) = protect immediately
 *
 * Returns true on success.
 */
static bool rip_port_create(rip_state_t *rs, uint8_t idx,
                             int16_t x0, int16_t y0,
                             int16_t x1, int16_t y1,
                             uint8_t port_flags)
{
    if (idx == 0 || idx >= RIP_MAX_PORTS)
        return false;

    rip_port_t *p = &rs->ports[idx];

    if (p->flags & (RIP_PORT_FLAG_PROTECTED | RIP_PORT_FLAG_PERMANENT))
        return false;  /* DLL: "Port is protected - cannot redefine it" */

    memset(p, 0, sizeof(*p));
    port_set_defaults(p);
    p->allocated = true;

    /* Scale EGA (640x350) viewport to card (640x400) pixel coords */
    clamp_ega_rect(&x0, &y0, &x1, &y1);
    p->vp_x0 = x0;
    p->vp_y0 = scale_y(y0);
    p->vp_x1 = x1;
    p->vp_y1 = scale_y1(y1);

    /* CORRECTED.  This used to set FULLSCREEN from wire bit 2 and PROTECTED
     * from wire bit 3, which are '|2s' RIP_SwitchPort's bit meanings applied
     * to the wrong command.  '|2P' RIP_PortDefine is a different handler
     * (RVA 0x0466EC) and tests only two bits:
     *
     *     and  eax, 1                 -> passed into port initialisation
     *                                    (0x1003326F) as a boolean
     *     test byte ptr [ebp-0x10], 2 -> selects whether the active port
     *                                    becomes this one; that is the
     *                                    "make active immediately" bit,
     *                                    which '|2P' above handles
     *
     * Bits 2 and 3 are never read here, so inferring FULLSCREEN or
     * PROTECTED from them invented behaviour the driver does not have.
     * That was harmless only because the flags field was being decoded from
     * the wrong half and always came out zero (D-17); with the field read
     * correctly the invented bits would start firing.
     *
     * Wire bit 0 IS consumed -- it reaches port initialisation as a boolean
     * -- but what it selects there is not recovered, so it is not acted on.
     * Every '|2P' in the shipped corpus sets exactly this bit and nothing
     * else, and those scenes render correctly without it.  D-22.
     *
     * '|2s' bits 2 and 3 remain protect/unprotect: that handler really does
     * test bl,4 and test bl,8, and RIPlib matches it. */

    return true;
}

/*
 * rip_port_destroy -- deallocate a port slot.
 *
 * Port 0 cannot be deleted unless force is set.
 * Protected ports cannot be deleted unless force is set.
 * If the active port is destroyed, falls back to port 0.
 *
 * Returns true on success.
 */
static bool rip_port_destroy(rip_state_t *rs, uint8_t idx, bool force)
{
    if (idx >= RIP_MAX_PORTS)
        return false;

    if (idx == 0 && !force)
        return false;  /* DLL: "Cannot delete port #0 deliberately" */

    rip_port_t *p = &rs->ports[idx];
    if (!p->allocated)
        return true;   /* already empty -- not an error */

    if ((p->flags & RIP_PORT_FLAG_PERMANENT) ||
        ((p->flags & RIP_PORT_FLAG_PROTECTED) && !force))
        return false;  /* DLL: "Specified port is protected - not deleted" */

    memset(p, 0, sizeof(*p));

    /* If the destroyed port was active, fall back to port 0 */
    if (rs->active_port == idx) {
        rs->active_port = 0;
        port_load_state(rs, 0);
    }

    return true;
}

/*
 * rip_port_switch -- save current port state and load new port state.
 *
 * Mirrors DLL ripSwitchPort / sub_03393C:
 *   - If the target port is not allocated, auto-create it with a full-screen
 *     viewport (DLL creates a screen-type stub on demand)
 *   - Saves active port's drawing state before switching
 *   - Loads new port's drawing state and applies its viewport clip
 *
 * switch_flags (2-digit MegaNum from !|2s command):
 *   bit 0 (1) = protect destination port
 *   bit 1 (2) = unprotect destination port
 *   bit 2 (4) = protect source (current) port
 *   bit 3 (8) = unprotect source (current) port
 *
 * Returns true on success.
 */
static bool rip_port_switch(rip_state_t *rs, uint8_t new_idx,
                             uint8_t switch_flags)
{
    if (new_idx >= RIP_MAX_PORTS)
        return false;

    uint8_t old_idx = rs->active_port;

    /* Apply source-port protection flags before saving state */
    if (switch_flags & 0x04)
        rs->ports[old_idx].flags |= RIP_PORT_FLAG_PROTECTED;
    if (switch_flags & 0x08)
        rs->ports[old_idx].flags &= (uint8_t)~RIP_PORT_FLAG_PROTECTED;

    /* Snapshot current port's drawing state */
    port_save_state(rs, old_idx);

    /* Auto-create the target if not allocated (DLL stub behavior) */
    if (!rs->ports[new_idx].allocated) {
        rip_port_t *p = &rs->ports[new_idx];
        memset(p, 0, sizeof(*p));
        port_set_defaults(p);
        p->allocated = true;
        p->vp_x0     = 0;
        p->vp_y0     = 0;
        p->vp_x1     = 639;
        p->vp_y1     = 399;
        p->flags     = RIP_PORT_FLAG_FULLSCREEN;
    }

    /* Apply destination-port protection flags */
    if (switch_flags & 0x01)
        rs->ports[new_idx].flags |= RIP_PORT_FLAG_PROTECTED;
    if (switch_flags & 0x02)
        rs->ports[new_idx].flags &= (uint8_t)~RIP_PORT_FLAG_PROTECTED;

    rs->active_port = new_idx;
    port_load_state(rs, new_idx);

    return true;
}

/*
 * rip_port_copy -- copy pixels from one port's viewport to another.
 *
 * Maps to DLL RIP_PORT_COPY (!|2C).  On RIPlib's single-framebuffer
 * architecture both source and destination reside in the same framebuffer,
 * so draw_copy_rect() provides the necessary memmove-safe blit.
 *
 * Source/dest coords of all zeros = use entire viewport of that port.
 * If dx1,dy1 = 0 -- no scaling (verbatim copy to dx0,dy0 position).
 * If the destination rectangle has a different size, scale nearest-neighbor
 * through a scratch copy so overlapping source/dest regions remain stable.
 * Input coordinates are in EGA (640x350) space; scaled to card here.
 */
static void rip_port_copy(rip_state_t *rs,
                          uint8_t src_idx,
                          int16_t sx0, int16_t sy0,
                          int16_t sx1, int16_t sy1,
                          uint8_t dst_idx,
                          int16_t dx0, int16_t dy0,
                          int16_t dx1, int16_t dy1,
                          uint8_t write_mode)
{
    if (src_idx >= RIP_MAX_PORTS || dst_idx >= RIP_MAX_PORTS)
        return;
    if (!rs->ports[src_idx].allocated || !rs->ports[dst_idx].allocated)
        return;

    rip_port_t *sp = &rs->ports[src_idx];
    rip_port_t *dp = &rs->ports[dst_idx];

    /* Resolve source rectangle (all-zero = entire source viewport) */
    int16_t rsx0, rsy0, rsx1, rsy1;
    if (sx0 == 0 && sy0 == 0 && sx1 == 0 && sy1 == 0) {
        rsx0 = sp->vp_x0; rsy0 = sp->vp_y0;
        rsx1 = sp->vp_x1; rsy1 = sp->vp_y1;
    } else {
        rsx0 = sx0;         rsy0 = scale_y(sy0);
        rsx1 = sx1;         rsy1 = scale_y1(sy1);
    }

    /* Resolve destination position/rectangle (all-zero = upper-left). */
    int16_t rdx, rdy, rdx1, rdy1;
    bool dest_rect = false;
    if (dx0 == 0 && dy0 == 0 && dx1 == 0 && dy1 == 0) {
        rdx = dp->vp_x0; rdy = dp->vp_y0;
        rdx1 = 0; rdy1 = 0;
    } else {
        rdx = dx0; rdy = scale_y(dy0);
        rdx1 = dx1; rdy1 = scale_y1(dy1);
        dest_rect = !(dx1 == 0 && dy1 == 0);
    }

    int16_t w = (int16_t)(rsx1 - rsx0 + 1);
    int16_t h = (int16_t)(rsy1 - rsy0 + 1);
    int16_t dw = w;
    int16_t dh = h;
    if (w <= 0 || h <= 0)
        return;

    if (dest_rect) {
        if (rdx > rdx1) { int16_t t = rdx; rdx = rdx1; rdx1 = t; }
        if (rdy > rdy1) { int16_t t = rdy; rdy = rdy1; rdy1 = t; }
        dw = (int16_t)(rdx1 - rdx + 1);
        dh = (int16_t)(rdy1 - rdy + 1);
    }

    rip2_copy_scaled(rs, rsx0, rsy0, w, h, rdx, rdy, dw, dh, write_mode);

    /* Restore active port's write mode */
    draw_set_write_mode(rs->ports[rs->active_port].write_mode);
}


/* =====================================================================
 * ripscrip2_execute -- Level 2 command dispatcher
 * ===================================================================== */

void ripscrip2_execute(ripscrip2_state_t *s, rip_state_t *rs, void *ctx,
                       char cmd,
                       const char *raw, int raw_len,
                       const int16_t *params, int param_count)
{
    comp_context_t *c = (comp_context_t *)ctx;
    (void)c;
    (void)param_count;

    switch (cmd) {

    /* ── !|2P -- RIP_DEFINE_PORT ───────────────────────────────────
     *
     * Wire format: !|2P<port_num:1><x0:2><y0:2><x1:2><y1:2>
     *                   <flags:4><reserved:4>|
     *
     * Field widths (MegaNum digits):
     *   port_num : 1 digit  (value 0-35)
     *   x0,y0,x1,y1 : 2 digits each (EGA 640x350 coords)
     *   flags    : 4 digits  (read low 2 = enough for bits 0-3)
     *
     * Raw offsets: port_num@0, x0@1, y0@3, x1@5, y1@7, flags@9
     */
    case RIP2_CMD_PORT_DEFINE: {
        if (raw_len < 9)
            break;
        uint8_t port_num   = (uint8_t)mega1(raw + 0);
        int16_t x0         = (int16_t)mega2l(raw + 1);
        int16_t y0         = (int16_t)mega2l(raw + 3);
        int16_t x1         = (int16_t)mega2l(raw + 5);
        int16_t y1         = (int16_t)mega2l(raw + 7);
        /* CORRECTED.  Slot 115 types this field mega4, so its four digits
         * span offsets 9..12 and the low-order bits sit at the END.  Reading
         * mega2l(raw + 9) took the HIGH two digits: every |2P in the corpus
         * carries flags "0001", which that reading decoded as 0.  Port flags
         * were therefore always zero, and no |2P could ever set a flag bit.
         *   FONTS.RIP     '10000ZK7200010000'  flags "0001"
         *   SPECLEFX.RIP  '10000Q04K0001'      flags "0001"
         * Masked to a byte: the record permits values a flag byte cannot
         * hold, and only the low bits are defined.  See D-17. */
        uint8_t port_flags = (raw_len >= 13)
                             ? (uint8_t)(mega4l(raw + 9) & 0xFF) : 0;

        if (port_num == 0 || port_num >= RIP_MAX_PORTS)
            break;

        bool ok = rip_port_create(rs, port_num, x0, y0, x1, y1, port_flags);
        if (!ok)
            break;

        /* Flag bit 1 (value 2) = make active immediately */
        if (port_flags & 0x02)
            rip_port_switch(rs, port_num, 0);
        break;
    }

    /* ── !|2p -- RIP_DELETE_PORT ───────────────────────────────────
     *
     * Wire format: !|2p<port_num:1><dest_port:1><reserved:2>|
     *
     * port_num: specific port in the on-wire 0-35 range
     * dest_port: ignored (DLL ignores it too)
     */
    case RIP2_CMD_PORT_DELETE: {
        /* Slot 116 records mega1, mega1, mega2 -- four characters.  The one
         * 2-character '|2p' in the corpus (SPECLEFX.RIP, "!|2p00") targets
         * port 0, which is protected and refused either way, so rejecting a
         * truncated record costs nothing and matches the driver.  D-17. */
        if (raw_len < 4)
            break;
        uint8_t port_num = (uint8_t)mega1(raw + 0);

        rip_port_destroy(rs, port_num, false);
        break;
    }

    /* ── !|2s -- RIP_SWITCH_PORT ───────────────────────────────────
     *
     * Wire format: !|2s<port_num:1><flags:2><reserved:3>|
     *
     * port_num: 0-35
     * flags (2-digit MegaNum, OR of):
     *   1 = protect dest, 2 = unprotect dest
     *   4 = protect src,  8 = unprotect src
     */
    /* ── Resource-slot switching: !|2A !|2B !|2E !|2T !|2Y ──────────
     *
     * All five share the signature slot:1 flags:2.  The driver validates the
     * slot ("Invalid palette slot number", "Illegal button style slot
     * number", "Illegal environment slot number", "Illegal text window slot
     * number") and switches a backing table.  RIPlib keeps one of each
     * resource, so it validates identically and records the selection rather
     * than pretending to swap a store it does not have.  Added 2026-08-12;
     * see docs/spec §12.12 for the parity caveat. */
    case RIP2_CMD_SWITCH_PALETTE:
    case RIP2_CMD_SWITCH_BUTTON_STYLE:
    case RIP2_CMD_SWITCH_ENVIRONMENT:
    case RIP2_CMD_SWITCH_TEXT_WINDOW:
    case RIP2_CMD_SWITCH_STYLE: {
        /* Slots 111, 112, 114, 119 and 121 all record  mega1, mega2  -- three
         * characters.  The gate was one character, so a truncated command was
         * acted on where the driver rejects it; the corpus sends three
         * ("!|2s000", "!|2s100").  Same defect class as '|1g' and '|1i' in
         * D-14/D-16.  See D-17.
         *
         * THE SECOND FIELD IS NOT RESERVED.  This comment used to call it a
         * "reserved pair", and 14.3.6 used to call slot protection inert on
         * the strength of that.  Disassembly on 2026-08-14 showed the driver
         * acting on four of its bits -- from slot 111:
         *
         *     test esi,4 -> paletteSlotProtect(inst,-1,1)   before switch
         *     test esi,8 -> paletteSlotProtect(inst,-1,0)   before switch
         *                   (the switch itself)
         *     test esi,1 -> paletteSlotProtect(inst,-1,1)   after switch
         *     test esi,2 -> paletteSlotProtect(inst,-1,0)   after switch
         *
         * so bits 2/3 protect and unprotect the slot being LEFT and bits 0/1
         * the slot being ENTERED.  Each family has its own protector
         * (styleSlotProtect, textWindowSlotProtect, environmentProtect,
         * colorTableProtect, and 0x100454C4 for button styles).
         *
         * RIPlib honours these bits for '|2s' and ports only.  For the other
         * five families the flags are still ignored, which means RIPlib
         * completes writes the driver would refuse -- the tolerable
         * direction under 14.6, but a real divergence.  Implementing it
         * needs a protected flag per slot per family plus checks at the 24
         * write sites the driver guards; that is a feature, not a patch, and
         * it is recorded in 14.3.6 rather than half-done here. */
        if (raw_len < 3)
            break;
        uint8_t slot = (uint8_t)mega1(raw + 0);
        if (slot >= RIP_MAX_PORTS)      /* same 36-slot table size as ports */
            break;                        /* driver rejects out-of-range slots */
        {
            /* IMPLEMENTED 2026-08-14.  Pick the family's current-slot field
             * and protection mask together, so the flag bits below act on
             * the right pair without a second switch. */
            uint8_t  *cur;
            uint64_t *mask;
            switch (cmd) {
            case RIP2_CMD_SWITCH_PALETTE:
                cur = &s->cur_palette_slot;      mask = &s->protected_palette;      break;
            case RIP2_CMD_SWITCH_BUTTON_STYLE:
                cur = &s->cur_button_style_slot; mask = &s->protected_button_style; break;
            case RIP2_CMD_SWITCH_ENVIRONMENT:
                cur = &s->cur_environment_slot;  mask = &s->protected_environment;  break;
            case RIP2_CMD_SWITCH_TEXT_WINDOW:
                cur = &s->cur_text_window_slot;  mask = &s->protected_text_window;  break;
            default:
                cur = &s->cur_style_slot;        mask = &s->protected_style;        break;
            }
            {
                uint8_t  fl   = (uint8_t)mega2l(raw + 1);
                uint64_t from = (uint64_t)1u << *cur;
                uint64_t to   = (uint64_t)1u << slot;
                if (fl & 0x04) *mask |=  from;   /* protect the slot being left  */
                if (fl & 0x08) *mask &= ~from;   /* unprotect it                 */
                *cur = slot;                      /* the switch itself            */
                if (fl & 0x01) *mask |=  to;     /* protect the slot entered     */
                if (fl & 0x02) *mask &= ~to;     /* unprotect it                 */
            }
            break;
        }
    }

    /* ── !|2W -- RIP_PortWrite ──────────────────────────────────────
     *
     * port:1 x0:2 y0:2 x1:2 y1:2 flags:2 res:2 <filename>
     * Writes a port's rectangle out to a bitmap FILE.  Diagnostics:
     * "Invalid port number", "Drawing port is not in use", "Specified
     * rectangle is empty", "Invalid bitmap filename".
     *
     * This is a host filesystem operation.  RIPlib has no filesystem and
     * deliberately performs no file I/O, so it validates the request the way
     * the driver does and stops there — consistent with how the library
     * treats every other storage-oriented command. */
    case RIP2_CMD_PORT_WRITE: {
        /* Slot 120 records mega1, XY, XY, XY, XY, mega2, mega2 -- thirteen
         * characters, with the bitmap filename following as a string tail
         * (D-16).  RIPlib gated on nine, the width of the port and rect
         * alone, so a record truncated before its flags was still acted on.
         * No corpus scene sends '|2W'.  D-19. */
        if (raw_len < 13)
            break;
        uint8_t port_num = (uint8_t)mega1(raw + 0);
        int16_t wx0 = (int16_t)mega2l(raw + 1), wy0 = (int16_t)mega2l(raw + 3);
        int16_t wx1 = (int16_t)mega2l(raw + 5), wy1 = (int16_t)mega2l(raw + 7);
        if (port_num >= RIP_MAX_PORTS) break;   /* "Invalid port number"      */
        if (wx1 <= wx0 || wy1 <= wy0)   break;   /* "rectangle is empty"        */
        /* No file is written; a filename with no filesystem behind it is not
         * something this library should pretend to honour. */
        break;
    }

    case RIP2_CMD_PORT_SWITCH: {
        /* Slot 118 records mega1, mega2 -- three characters, which is what
         * every '|2s' in the corpus sends ("!|2s000", "!|2s100").  D-17. */
        if (raw_len < 3)
            break;
        uint8_t port_num     = (uint8_t)mega1(raw + 0);
        uint8_t switch_flags = (uint8_t)mega2l(raw + 1);
        rip_port_switch(rs, port_num, switch_flags);
        break;
    }

    /* ── !|2C -- RIP_PORT_COPY ─────────────────────────────────────
     *
     * Wire format: !|2C<src:1><sx0:2><sy0:2><sx1:2><sy1:2>
     *                    <dst:1><dx0:2><dy0:2><dx1:2><dy1:2>
     *                    <write_mode:1><reserved:5>|
     *
     * Raw offsets: src@0, sx0@1, sy0@3, sx1@5, sy1@7,
     *              dst@9, dx0@10, dy0@12, dx1@14, dy1@16,
     *              write_mode@18
     */
    case RIP2_CMD_PORT_COPY: {
        if (raw_len < 18)
            break;
        uint8_t src_port = (uint8_t)mega1(raw + 0);
        int16_t sx0      = (int16_t)mega2l(raw + 1);
        int16_t sy0      = (int16_t)mega2l(raw + 3);
        int16_t sx1      = (int16_t)mega2l(raw + 5);
        int16_t sy1      = (int16_t)mega2l(raw + 7);
        uint8_t dst_port = (uint8_t)mega1(raw + 9);
        int16_t dx0      = (int16_t)mega2l(raw + 10);
        int16_t dy0      = (int16_t)mega2l(raw + 12);
        int16_t dx1      = (int16_t)mega2l(raw + 14);
        int16_t dy1      = (int16_t)mega2l(raw + 16);
        uint8_t wmode    = (raw_len >= 19) ? (uint8_t)mega1(raw + 18) : 0;

        rip_port_copy(rs, src_port, sx0, sy0, sx1, sy1,
                          dst_port, dx0, dy0, dx1, dy1, wmode);
        break;
    }

    /* ── !|2F -- RIP_PORT_FLAGS (v3.1 extension) ──────────────────
     *
     * Wire format: !|2F<port_num:1><alpha:1><comp_mode:2><zorder:2>|
     * Sets extended compositor attributes stored in rip_port_t.
     */
    case RIP2_CMD_PORT_FLAGS: {
        if (raw_len < 1)
            break;
        uint8_t port_num = (uint8_t)mega1(raw + 0);
        if (port_num >= RIP_MAX_PORTS)
            break;
        if (!rs->ports[port_num].allocated)
            break;

        if (raw_len >= 2)
            rs->ports[port_num].alpha     = (uint8_t)mega1(raw + 1);
        if (raw_len >= 4)
            rs->ports[port_num].comp_mode = (uint8_t)mega2l(raw + 2);
        if (raw_len >= 6)
            rs->ports[port_num].zorder    = (uint8_t)mega2l(raw + 4);

        /* Mirror into ripscrip2_state_t for backward compat */
        s->port_alpha[port_num]     = rs->ports[port_num].alpha;
        s->port_comp_mode[port_num] = rs->ports[port_num].comp_mode;
        s->port_zorder[port_num]    = rs->ports[port_num].zorder;
        break;
    }

    /* ── !|20 -- Set VGA palette entry ────────────────────────────
     * params[0]=index, [1]=R, [2]=G, [3]=B  (all mega2 values)
     */
    case RIP2_CMD_SET_PALETTE: {
        if (param_count < 4)
            break;
        uint8_t idx = (uint8_t)(params[0] & 0xFF);
        uint8_t r   = (uint8_t)(params[1] & 0xFF);
        uint8_t g   = (uint8_t)(params[2] & 0xFF);
        uint8_t b   = (uint8_t)(params[3] & 0xFF);
        s->vga_palette[idx] = (uint8_t)(((r >> 5) << 5) |
                                         ((g >> 5) << 2) |
                                          (b >> 6));
        palette_write_rgb565(idx,
            (uint16_t)(((uint16_t)(r >> 3) << 11) |
                       ((uint16_t)(g >> 2) << 5)  |
                       ((uint16_t)(b >> 3))));
        s->palette_custom = true;
        break;
    }

    /* ── !|22 -- Define window region ───────────────────────────── */
    case RIP2_CMD_SET_WINDOW: {
        if (param_count < 4)
            break;
        uint8_t old_color = draw_get_color();
        s->win_x = params[0];
        s->win_y = scale_y(params[1]);
        s->win_w = params[2];
        s->win_h = scale_y(params[3]);
        s->window_active = true;
        draw_set_color(7);
        draw_rect(s->win_x, s->win_y, s->win_w, s->win_h, false);
        draw_set_color(1);
        draw_rect(s->win_x + 1, s->win_y + 1, s->win_w - 2, 14, true);
        draw_set_color(old_color);
        break;
    }

    /* ── !|26 -- Scalable text ──────────────────────────────────────
     *
     * Stores text_scale and text_rotation in ripscrip2_state_t for
     * introspection AND projects them onto the BGI rendering knobs
     * that subsequent text commands actually read:
     *   - text_scale (1..10) → rs->font_size (BGI integer scale 1-10)
     *   - text_rotation snapped to the nearest 90° quadrant →
     *     rs->font_dir (0=horizontal, 3=vertical CW, 2=vertical CCW)
     *
     * NOTE (2026-08-12, X3): 90° maps to font_dir 3, not 1.  Direction 1
     * was restored to its documented BGI VERT_DIR meaning (bottom-to-top),
     * and the CW top-to-bottom rendering a 90° rotation actually wants
     * moved to direction 3.  Mapping 90° to 1 would now render the text
     * running upward.
     *
     * Scale is clamped to the renderer's real range 1-10 (bgi_font.c caps
     * scale at 10), matching the 'Y' RIP_FONT_STYLE handler's clamp.  An
     * out-of-range value falls back to 1 rather than being bit-masked —
     * masking would silently corrupt valid scales (e.g. 10 & 0x07 == 2).
     *
     * 180° has no font_dir mapping — the BGI renderer doesn't support
     * upside-down text — so it falls back to horizontal, matching what
     * legacy clients did with the unsupported angle. */
    case RIP2_CMD_SCALE_TEXT: {
        if (param_count >= 1) {
            int sc = params[0];
            s->text_scale = (uint8_t)((sc >= 1 && sc <= 10) ? sc : 1);
            if (rs)
                rs->font_size = s->text_scale;
        }
        if (param_count >= 2) {
            s->text_rotation = params[1];
            if (rs) {
                int rot = ((int)s->text_rotation % 360 + 360) % 360;
                if (rot < 45 || rot >= 315)       rs->font_dir = 0;
                else if (rot < 135)               rs->font_dir = 3;  /* 90°  = CW  */
                else if (rot >= 225)              rs->font_dir = 2;  /* 270° = CCW */
                else                              rs->font_dir = 0;
            }
        }
        break;
    }

    /* ── !|28 -- Gradient fill ──────────────────────────────────── */
    case RIP2_CMD_GRADIENT: {
        if (param_count < 7)
            break;
        int16_t gx = params[0];
        int16_t gy = scale_y(params[1]);
        int16_t gw = params[2];
        int16_t gh = scale_y(params[3]);
        uint8_t c1 = s->vga_palette[params[4] & 0xFF];
        uint8_t c2 = s->vga_palette[params[5] & 0xFF];
        /* mode: 0=horizontal (vary X), 1=vertical (vary Y), 2=radial (§A2G.13).
         * v3.0 used a bool here (any non-zero = vertical) so values 0/1 keep
         * their original semantics; mode 2 is the new backward-compatible
         * radial gradient added in v3.2. */
        int mode = params[6];
        if (mode != 2) mode = (mode != 0) ? 1 : 0;
        uint8_t old_color = draw_get_color();

        int r1 = (c1 >> 5) & 7, g1 = (c1 >> 2) & 7, b1 = c1 & 3;
        int r2 = (c2 >> 5) & 7, g2 = (c2 >> 2) & 7, b2 = c2 & 3;

        if (mode == 2) {
            /* Radial: c1 at center, c2 at the farthest box corner.
             * Per-pixel interpolation by normalized distance.  Uses
             * the FPU we already require for §A2G.5. */
            int16_t cx = (int16_t)(gx + gw / 2);
            int16_t cy = (int16_t)(gy + gh / 2);
            float max_d2 = (float)((gw * gw + gh * gh) / 4);
            if (max_d2 <= 0.0f) max_d2 = 1.0f;
            for (int16_t y = gy; y < gy + gh; y++) {
                for (int16_t x = gx; x < gx + gw; x++) {
                    float dx = (float)(x - cx);
                    float dy = (float)(y - cy);
                    float t = (dx * dx + dy * dy) / max_d2;
                    if (t > 1.0f) t = 1.0f;
                    int r = r1 + (int)((r2 - r1) * t);
                    int g = g1 + (int)((g2 - g1) * t);
                    int b = b1 + (int)((b2 - b1) * t);
                    uint8_t color = (uint8_t)(((r & 7) << 5) |
                                              ((g & 7) << 2) | (b & 3));
                    draw_set_color(rip2_nearest_palette_index(s, color));
                    draw_pixel(x, y);
                }
            }
        } else {
            bool vertical = (mode == 1);
            int steps = vertical ? gh : gw;
            if (steps <= 0) steps = 1;
            int denom = (steps > 1) ? (steps - 1) : 1;
            for (int i = 0; i < steps; i++) {
                int r = r1 + (r2 - r1) * i / denom;
                int g = g1 + (g2 - g1) * i / denom;
                int b = b1 + (b2 - b1) * i / denom;
                uint8_t color = (uint8_t)(((r & 7) << 5) |
                                          ((g & 7) << 2) | (b & 3));
                draw_set_color(rip2_nearest_palette_index(s, color));
                if (vertical)
                    draw_hline(gx, (int16_t)(gy + i), gw);
                else
                    draw_vline((int16_t)(gx + i), gy, gh);
            }
        }
        draw_set_color(old_color);
        break;
    }

    /* ── !|2c -- Chord drawing (v3.1 extension) ────────────────────
     * Lowercase 'c' to avoid collision with RIP2_CMD_PORT_COPY ('C').
     * params[0]=cx, [1]=cy, [2]=r, [3]=start_angle, [4]=end_angle
     */
    case RIP2_CMD_CHORD: {
        if (param_count < 5)
            break;
        int16_t cx = params[0];
        int16_t cy = scale_y(params[1]);
        int16_t r  = scale_y(params[2]);
        int16_t sa = params[3];
        int16_t ea = params[4];
        draw_arc(cx, cy, r, sa, ea);

        int16_t x0, y0, x1, y1;
        rip2_circle_point(cx, cy, r, sa, &x0, &y0);
        rip2_circle_point(cx, cy, r, ea, &x1, &y1);
        draw_line(x0, y0, x1, y1);
        break;
    }

    /* ── !|2R -- Host-triggered screen refresh ──────────────────── */
    case RIP2_CMD_SET_REFRESH: {
        /* Dispatch slot 117 (RVA 0x046bd9), argc 1, mega4.  RIPlib read this
         * as a zero-argument command.  The reserved field is consumed so the
         * frame stays in sync and recorded for capability queries; the
         * driver does not otherwise act on it. */
        if (raw_len >= 4)
            rs->refresh_res = (uint32_t)(mega1(raw + 0) * 46656 +
                                         mega1(raw + 1) * 1296 +
                                         mega1(raw + 2) * 36 +
                                         mega1(raw + 3));
        /* Mark all rows dirty for refresh — platform-specific */
        draw_mark_all_dirty();
        break;
    }

    /* ── !|23 -- Scrollbar widget ──────────────────────────────────
     * params: x, y, w, h, min, max, value, page_size
     * Draws a vertical scrollbar track + proportional thumb.
     */
    case RIP2_CMD_SCROLLBAR: {
        if (param_count < 8)
            break;
        uint8_t old_color = draw_get_color();
        int16_t sx = params[0], sy = scale_y(params[1]);
        int16_t sw = params[2], sh = scale_y(params[3]);
        /* Draw track */
        draw_set_color(7);  /* light gray */
        draw_rect(sx, sy, sw, sh, true);
        /* Draw thumb */
        int range = params[5] - params[4];
        if (range > 0) {
            int thumb_h = sh * params[7] / range;
            if (thumb_h < 8) thumb_h = 8;
            int thumb_y = sy + (sh - thumb_h) * (params[6] - params[4]) / range;
            draw_set_color(8);  /* dark gray */
            draw_rect(sx, (int16_t)thumb_y, sw, (int16_t)thumb_h, true);
        }
        /* Draw border */
        draw_set_color(0);
        draw_rect(sx, sy, sw, sh, false);
        draw_set_color(old_color);
        break;
    }

    /* ── !|24 -- Menu bar widget ────────────────────────────────────
     * params: y, height, bg_color, text_color [, num_items]
     * Draws a full-width menu bar with bottom border.
     */
    case RIP2_CMD_MENU: {
        if (param_count < 4)
            break;
        uint8_t old_color = draw_get_color();
        int16_t my = scale_y(params[0]);
        int16_t mh = scale_y(params[1]);
        draw_set_color((uint8_t)(params[2] & 0xFF));
        draw_rect(0, my, 640, mh, true);
        /* Bottom border */
        draw_set_color(0);
        draw_hline(0, (int16_t)(my + mh - 1), 640);
        draw_set_color(old_color);
        break;
    }

    /* ── !|25 -- Dialog box widget ──────────────────────────────────
     * params: x, y, w, h, title_color, bg_color
     * Draws a shadowed dialog with title bar and outer border.
     */
    case RIP2_CMD_DIALOG: {
        if (param_count < 6)
            break;
        uint8_t old_color = draw_get_color();
        int16_t dx = params[0], dy = scale_y(params[1]);
        int16_t dw = params[2], dh = scale_y(params[3]);
        /* Shadow */
        draw_set_color(0);
        draw_rect((int16_t)(dx + 2), (int16_t)(dy + 2), dw, dh, true);
        /* Background */
        draw_set_color((uint8_t)(params[5] & 0xFF));
        draw_rect(dx, dy, dw, dh, true);
        /* Title bar */
        draw_set_color((uint8_t)(params[4] & 0xFF));
        draw_rect(dx, dy, dw, 16, true);
        /* Border */
        draw_set_color(0);
        draw_rect(dx, dy, dw, dh, false);
        draw_set_color(old_color);
        break;
    }

    /* ── !|21 -- Query VGA palette entry ───────────────────────── */
    case RIP2_CMD_QUERY_PALETTE: {
        if (param_count >= 1) {
            uint8_t idx = (uint8_t)(params[0] & 0xFF);
            uint8_t rgb = s->vga_palette[idx];
            char resp[32];
            int n = snprintf(resp, sizeof(resp), "%u %u %u %u\r",
                             (unsigned)idx,
                             (unsigned)rip2_rgb332_r(rgb),
                             (unsigned)rip2_rgb332_g(rgb),
                             (unsigned)rip2_rgb332_b(rgb));
            if (n > 0)
                riplib_host_tx(resp, n);
        }
        break;
    }

    /* ── !|27 -- Level 2 clipboard operations ────────────────────
     * params: op [x y w h mode]
     * op 0=clear, 1=capture rect, 2=paste at x/y, 3=paste scaled. */
    case RIP2_CMD_CLIPBOARD: {
        if (param_count < 1)
            break;
        {
            uint8_t op = (uint8_t)(params[0] & 0xFF);
            if (op == 0) {
                rs->clipboard.valid = false;
                rs->clipboard.width = 0;
                rs->clipboard.height = 0;
            } else if (op == 1 && param_count >= 5) {
                int16_t x = params[1];
                int16_t y = scale_y(params[2]);
                int16_t w = params[3];
                int16_t h = scale_y(params[4]);
                (void)rip2_clipboard_capture(rs, x, y, w, h);
            } else if (op == 2 && param_count >= 3 &&
                       rs->clipboard.valid && rs->clipboard.data) {
                int16_t x = params[1];
                int16_t y = scale_y(params[2]);
                uint8_t mode = (param_count >= 4)
                             ? (uint8_t)(params[3] & 0xFF)
                             : DRAW_MODE_COPY;
                rip2_blit_pixels(rs, x, y, rs->clipboard.data,
                                 (uint16_t)rs->clipboard.width,
                                 (uint16_t)rs->clipboard.height,
                                 rs->clipboard.width, rs->clipboard.height,
                                 mode);
            } else if (op == 3 && param_count >= 5 &&
                       rs->clipboard.valid && rs->clipboard.data) {
                int16_t x = params[1];
                int16_t y = scale_y(params[2]);
                int16_t w = params[3];
                int16_t h = scale_y(params[4]);
                uint8_t mode = (param_count >= 6)
                             ? (uint8_t)(params[5] & 0xFF)
                             : DRAW_MODE_COPY;
                rip2_blit_pixels(rs, x, y, rs->clipboard.data,
                                 (uint16_t)rs->clipboard.width,
                                 (uint16_t)rs->clipboard.height,
                                 w, h, mode);
            }
        }
        break;
    }

    /* ── !|29 -- Alpha fill approximation ────────────────────────
     * params: x y w h color alpha.  The framebuffer is indexed-color, so
     * this uses ordered coverage instead of true RGB blending. */
    case RIP2_CMD_ALPHA_BLEND: {
        if (param_count >= 6) {
            int16_t ax = params[0];
            int16_t ay = scale_y(params[1]);
            int16_t aw = params[2];
            int16_t ah = scale_y(params[3]);
            uint8_t color = (uint8_t)(params[4] & 0xFF);
            int alpha = params[5];
            uint8_t old_color = draw_get_color();
            if (alpha > 35)
                alpha = (alpha * 35) / 255;
            if (alpha < 0) alpha = 0;
            if (alpha > 35) alpha = 35;

            draw_set_write_mode(DRAW_MODE_COPY);
            draw_set_color(color);
            if (alpha == 35) {
                draw_rect(ax, ay, aw, ah, true);
            } else if (alpha > 0 && aw > 0 && ah > 0) {
                for (int16_t yy = 0; yy < ah; yy++) {
                    for (int16_t xx = 0; xx < aw; xx++) {
                        int threshold = ((xx * 17 + yy * 31) % 35);
                        if (threshold < alpha)
                            draw_pixel((int16_t)(ax + xx), (int16_t)(ay + yy));
                    }
                }
            }
            draw_set_write_mode(rs->write_mode);
            draw_set_color(old_color);
        }
        break;
    }

    default:
        break;
    }
}

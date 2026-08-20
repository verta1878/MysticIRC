/*
 * ripscrip2.h — RIPscrip 2.0+ protocol extensions for RIPlib
 *
 * TeleGrafix Communications, 1994-1995.  Extends RIPscrip 1.54 with:
 *   - 256-color VGA palette (up from 16-color EGA)
 *   - Enhanced GUI widgets (windows, scrollbars, menus, dialogs)
 *   - Scalable text with rotation
 *   - Improved button/mouse region system
 *   - Clipboard operations
 *
 * RIPscrip 2.0 was never widely deployed.  TeleGrafix went defunct
 * circa 1996.  No complete implementation exists in the wild besides
 * the original never-released RIPterm 2.0 client.
 *
 * This parser extends ripscrip.c (1.54) with 2.0+ commands and the
 * v3.x §A2G extensions (see docs/spec/06-v31-extensions.md and
 * 06a-v32-extensions.md).  The base !| frame detection and MegaNum
 * decoding are shared with ripscrip.c.
 *
 * Copyright (c) 2026 SimVU (Brad Hawthorne)
 * Licensed under the MIT License.  See LICENSE.
 */

#pragma once

#include <stdint.h>
#include <stdbool.h>
#include "ripscrip.h"   /* rip_state_t, rip_port_t, RIP_MAX_PORTS */

/* RIPscrip 2.0 command prefixes (Level 2) */
#define RIP2_CMD_SET_PALETTE    '0'  /* Set VGA palette entry */
#define RIP2_CMD_QUERY_PALETTE  '1'  /* Query palette */
#define RIP2_CMD_SET_WINDOW     '2'  /* Define window region */
#define RIP2_CMD_SCROLLBAR      '3'  /* Define scrollbar widget */
#define RIP2_CMD_MENU           '4'  /* Define menu bar */
#define RIP2_CMD_DIALOG         '5'  /* Define dialog box */
#define RIP2_CMD_SCALE_TEXT     '6'  /* Scalable text with size/rotation */
#define RIP2_CMD_CLIPBOARD      '7'  /* Clipboard copy/paste */
#define RIP2_CMD_GRADIENT       '8'  /* Gradient fill */
#define RIP2_CMD_ALPHA_BLEND    '9'  /* Alpha transparency */

/* Drawing Port commands (v2.0/v3.0) */
#define RIP2_CMD_PORT_DEFINE    'P'  /* !|2P — define/create a port */
#define RIP2_CMD_PORT_DELETE    'p'  /* !|2p — delete a port */
#define RIP2_CMD_PORT_COPY      'C'  /* !|2C — copy pixels between ports */
#define RIP2_CMD_PORT_SWITCH    's'  /* !|2s — switch active port */

/* RIPlib v3.1 (§A2G.1-7) extensions */
#define RIP2_CMD_CHORD          'c'  /* Chord drawing */
#define RIP2_CMD_SET_REFRESH    'R'  /* Host-triggered screen refresh */
#define RIP2_CMD_PORT_FLAGS     'F'  /* Extended port attributes (alpha/mode/zorder) */

/* Resource-slot switching (recovered from the driver's dispatch table
 * 2026-08-12; all take slot:1 flags:2, and each names its own slot in the
 * handler's validation diagnostic). */
#define RIP2_CMD_SWITCH_PALETTE      'A'  /* !|2A — RIP_SwitchPalette      */
#define RIP2_CMD_SWITCH_BUTTON_STYLE 'B'  /* !|2B — RIP_SwitchButtonStyle  */
#define RIP2_CMD_SWITCH_ENVIRONMENT  'E'  /* !|2E — RIP_SwitchEnvironment  */
#define RIP2_CMD_SWITCH_TEXT_WINDOW  'T'  /* !|2T — RIP_SwitchTextWindow   */
#define RIP2_CMD_SWITCH_STYLE        'Y'  /* !|2Y — RIP_SwitchStyle (graphics style slot) */
#define RIP2_CMD_PORT_WRITE          'W'  /* !|2W — RIP_PortWrite (to bitmap) */

void ripscrip2_init(ripscrip2_state_t *s);

/* Process a Level 2 command (called from ripscrip.c when '2' prefix detected).
 * cmd     — command character after the level prefix
 * raw     — raw parameter bytes from cmd_buf (before MegaNum decode)
 * raw_len — number of bytes in raw
 * params  — MegaNum-decoded parameters (mega2 pairs, for backward compat)
 * param_count — number of decoded params
 *
 * Port commands (P, p, s, C, F) parse raw directly for 1-digit and 4-digit
 * MegaNum fields.  All other commands continue to use the params array. */
void ripscrip2_execute(ripscrip2_state_t *s, rip_state_t *rs, void *ctx,
                       char cmd,
                       const char *raw, int raw_len,
                       const int16_t *params, int param_count);

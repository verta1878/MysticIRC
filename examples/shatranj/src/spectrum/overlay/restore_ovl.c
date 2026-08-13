#include "spectrum/overlay/overlay_context.h"
#include "spectrum/board/board.h"
#include "common/savegame/savegame_format.h"

static uint8_t restore_wire[NETCHESSZX_SAVE_WIRE_SIZE];

static const char restore_piece_table[] = ".PNBRQK?pnbrqk";
static const char restore_b64_table[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

static uint8_t restore_find_char(const char *table, uint8_t len,
                                 char ch, uint8_t *out)
{
    uint8_t i;

    for (i = 0u; i < len; ++i) {
        if (table[i] == ch) {
            *out = i;
            return 1u;
        }
    }
    return 0u;
}

static uint8_t restore_nibble_to_piece(uint8_t nibble, char *out)
{
    if (nibble >= 14u || restore_piece_table[nibble] == '?') {
        return 0u;
    }
    *out = restore_piece_table[nibble];
    return 1u;
}

static uint8_t restore_crc8(const uint8_t *data, uint8_t len)
{
    uint8_t crc = 0u;
    uint8_t i;
    uint8_t bit;

    for (i = 0u; i < len; ++i) {
        crc ^= data[i];
        for (bit = 0u; bit < 8u; ++bit) {
            crc = (crc & 0x80u) != 0u ?
                (uint8_t)((crc << 1) ^ 0x07u) : (uint8_t)(crc << 1);
        }
    }
    return crc;
}

static uint8_t restore_b64_value(char ch, uint8_t *out)
{
    return restore_find_char(restore_b64_table, 64u, ch, out);
}

static uint8_t restore_pack_wire(const spectrum_board_snapshot_t *snap,
                                 const netchesszx_save_meta_t *meta)
{
    uint8_t i;
    uint8_t hi;
    uint8_t lo;


    for (i = 0u; i < 32u; ++i) {
        if (!restore_find_char(restore_piece_table, 14u,
                               snap->cells[(uint8_t)(i * 2u)], &hi) ||
            hi == 7u ||
            !restore_find_char(restore_piece_table, 14u,
                               snap->cells[(uint8_t)(i * 2u + 1u)], &lo) ||
            lo == 7u) {
            return 0u;
        }
        restore_wire[i] = (uint8_t)((hi << 4) | lo);
    }
    restore_wire[32] = (uint8_t)((snap->side & 1u) |
                                 ((meta->host_color & 1u) << 1) |
                                 ((snap->castle & 0x0fu) << 2) |
                                 ((meta->view_flags & NETCHESSZX_SAVE_VIEW_FLIPPED) << 6));
    restore_wire[33] = snap->ep < 0 ? NETCHESSZX_SAVE_EP_NONE : (uint8_t)snap->ep;
    restore_wire[34] = (uint8_t)meta->ply;
    restore_wire[35] = (uint8_t)(meta->ply >> 8);
    restore_wire[36] = meta->flags;
    restore_wire[37] = meta->timers[0];
    restore_wire[38] = meta->timers[1];
    restore_wire[39] = meta->timers[2];
    restore_wire[40] = meta->timers[3];
    restore_wire[41] = meta->timers[4];
    restore_wire[42] = meta->timers[5];
    restore_wire[43] = NETCHESSZX_SAVE_WIRE_VERSION;
    restore_wire[44] = restore_crc8(restore_wire, 44u);
    return 1u;
}

static uint8_t restore_unpack_wire(spectrum_board_snapshot_t *snap,
                                   netchesszx_save_meta_t *meta)
{
    uint8_t i;
    uint8_t packed;
    uint8_t white_kings = 0u;
    uint8_t black_kings = 0u;
    char piece;

    if (snap == 0 || meta == 0 || restore_wire[43] != NETCHESSZX_SAVE_WIRE_VERSION ||
        restore_crc8(restore_wire, 44u) != restore_wire[44] ||
        restore_wire[37] > 99u || restore_wire[38] >= 60u ||
        restore_wire[39] >= 60u || restore_wire[40] > 99u ||
        restore_wire[41] >= 60u || restore_wire[42] >= 60u) {
        return 0u;
    }
    for (i = 0u; i < 32u; ++i) {
        packed = restore_wire[i];
        if (!restore_nibble_to_piece((uint8_t)(packed >> 4),
                                     &snap->cells[(uint8_t)(i * 2u)]) ||
            !restore_nibble_to_piece((uint8_t)(packed & 0x0fu),
                                     &snap->cells[(uint8_t)(i * 2u + 1u)])) {
            return 0u;
        }
    }
    for (i = 0u; i < 64u; ++i) {
        piece = snap->cells[i];
        if (piece == 'K') {
            ++white_kings;
        } else if (piece == 'k') {
            ++black_kings;
        } else if ((i < 8u || i >= 56u) &&
                   (piece == 'P' || piece == 'p')) {
            return 0u;
        }
    }
    if (white_kings != 1u || black_kings != 1u) {
        return 0u;
    }
    packed = restore_wire[32];
    if ((packed & 0x80u) != 0u ||
        (restore_wire[36] & (uint8_t)~NETCHESSZX_SAVE_FLAGS_MASK) != 0u) {
        return 0u;
    }
    snap->side = (uint8_t)(packed & 1u);
    meta->host_color = (uint8_t)((packed >> 1) & 1u);
    snap->castle = (uint8_t)((packed >> 2) & 0x0fu);
    meta->view_flags = (uint8_t)((packed >> 6) & NETCHESSZX_SAVE_VIEW_FLIPPED);
    packed = restore_wire[33];
    if (!NETCHESSZX_SAVE_EP_VALID(snap->side, packed)) {
        return 0u;
    }
    snap->ep = packed == NETCHESSZX_SAVE_EP_NONE ? -1 : (int8_t)packed;
    meta->ply = (uint16_t)restore_wire[34] | ((uint16_t)restore_wire[35] << 8);
    if (snap->side != (uint8_t)(meta->ply & 1u)) {
        return 0u;
    }
    meta->flags = restore_wire[36];
    meta->timers[0] = restore_wire[37];
    meta->timers[1] = restore_wire[38];
    meta->timers[2] = restore_wire[39];
    meta->timers[3] = restore_wire[40];
    meta->timers[4] = restore_wire[41];
    meta->timers[5] = restore_wire[42];
    return 1u;
}

static void restore_b64_encode(char *out) __z88dk_fastcall
{
    uint8_t i;
    uint8_t j = 0u;
    uint8_t a;
    uint8_t b;
    uint8_t c;

    for (i = 0u; i < NETCHESSZX_SAVE_WIRE_SIZE; i = (uint8_t)(i + 3u)) {
        a = restore_wire[i];
        b = restore_wire[(uint8_t)(i + 1u)];
        c = restore_wire[(uint8_t)(i + 2u)];
        out[j++] = restore_b64_table[(uint8_t)(a >> 2)];
        out[j++] = restore_b64_table[(uint8_t)(((a & 0x03u) << 4) | (b >> 4))];
        out[j++] = restore_b64_table[(uint8_t)(((b & 0x0fu) << 2) | (c >> 6))];
        out[j++] = restore_b64_table[(uint8_t)(c & 0x3fu)];
    }
}

static uint8_t restore_b64_decode(const char *text)
{
    uint8_t i;
    uint8_t j = 0u;
    uint8_t a;
    uint8_t b;
    uint8_t c;
    uint8_t d;

    for (i = 0u; i < NETCHESSZX_SAVE_WIRE_B64_SIZE; i = (uint8_t)(i + 4u)) {
        if (!restore_b64_value(text[i], &a) ||
            !restore_b64_value(text[(uint8_t)(i + 1u)], &b) ||
            !restore_b64_value(text[(uint8_t)(i + 2u)], &c) ||
            !restore_b64_value(text[(uint8_t)(i + 3u)], &d)) {
            return 0u;
        }
        restore_wire[j++] = (uint8_t)((a << 2) | (b >> 4));
        restore_wire[j++] = (uint8_t)((b << 4) | (c >> 2));
        restore_wire[j++] = (uint8_t)((c << 6) | d);
    }
    return 1u;
}

#ifndef NETCHESSZX_HOST_TEST
uint8_t restore_build_frame_ovl(uint8_t *ctx) __z88dk_fastcall
{
    const spectrum_board_snapshot_t *snap =
        (const spectrum_board_snapshot_t *)((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_SNAP_LO] |
        ((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_SNAP_HI] << 8));
    const netchesszx_save_meta_t *meta =
        (const netchesszx_save_meta_t *)((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_META_LO] |
        ((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_META_HI] << 8));
    char *b64 = (char *)((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_TEXT_LO] |
        ((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_TEXT_HI] << 8));
    if (b64 == 0 || !restore_pack_wire(snap, meta)) {
        return 0u;
    }
    restore_b64_encode(b64);
    return 1u;
}

uint8_t restore_decode_ovl(uint8_t *ctx) __z88dk_fastcall
{
    const char *text = (const char *)((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_TEXT_LO] |
        ((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_TEXT_HI] << 8));
    spectrum_board_snapshot_t *snap =
        (spectrum_board_snapshot_t *)((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_SNAP_LO] |
        ((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_SNAP_HI] << 8));
    netchesszx_save_meta_t *meta =
        (netchesszx_save_meta_t *)((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_META_LO] |
        ((uint16_t)ctx[SPECTRUM_OVL_CTX_RESTORE_META_HI] << 8));

    if (text == 0 || !restore_b64_decode(text)) {
        return 0u;
    }
    return restore_unpack_wire(snap, meta);
}
#else
uint8_t spectrum_restore_build_b64(const spectrum_board_snapshot_t *snap,
                                   const netchesszx_save_meta_t *meta,
                                   char *b64)
{
    if (snap == 0 || meta == 0 || b64 == 0 ||
        !restore_pack_wire(snap, meta)) {
        return 0u;
    }
    restore_b64_encode(b64);
    return 1u;
}

uint8_t spectrum_restore_decode(const char *b64,
                                spectrum_board_snapshot_t *snap,
                                netchesszx_save_meta_t *meta)
{
    if (b64 == 0 || snap == 0 || meta == 0 || !restore_b64_decode(b64)) {
        return 0u;
    }
    return restore_unpack_wire(snap, meta);
}
#endif

#include "common/chess/move_coords.h"

#ifndef NETCHESSZX_SDCC_IY

uint16_t netchesszx_move_parse_coords(const char *move) NETCHESSZX_FASTCALL
{
    uint8_t fc = (uint8_t)(move[0] - 'a');
    uint8_t fr = (uint8_t)('8' - move[1]);
    uint8_t tc = (uint8_t)(move[2] - 'a');
    uint8_t tr = (uint8_t)('8' - move[3]);

    if (fc >= 8u || fr >= 8u || tc >= 8u || tr >= 8u ||
        (fr == tr && fc == tc)) {
        return NETCHESSZX_MOVE_COORDS_INVALID;
    }

    fc = (uint8_t)((fr << 3) + fc);
    tc = (uint8_t)((tr << 3) + tc);
    return (uint16_t)((((uint16_t)tc) << 8) | fc);
}
#endif

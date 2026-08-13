#ifndef NETCHESSZX_SAVEGAME_FORMAT_H
#define NETCHESSZX_SAVEGAME_FORMAT_H

#include <stdint.h>


#define NETCHESSZX_SAVE_HOST_WHITE 0u
#define NETCHESSZX_SAVE_HOST_BLACK 1u

#define NETCHESSZX_SAVE_SIDE_WHITE 0u
#define NETCHESSZX_SAVE_SIDE_BLACK 1u

#define NETCHESSZX_SAVE_FLAG_ACTIVE 0x01u
#define NETCHESSZX_SAVE_FLAG_GAME_OVER 0x02u
#define NETCHESSZX_SAVE_FLAG_CHECK 0x04u
#define NETCHESSZX_SAVE_FLAGS_MASK 0x07u

#define NETCHESSZX_SAVE_VIEW_FLIPPED 0x01u
#define NETCHESSZX_SAVE_VIEW_MASK 0x01u

#define NETCHESSZX_SAVE_EP_NONE 0xffu
#define NETCHESSZX_SAVE_EP_VALID(side, ep) \
    ((ep) == NETCHESSZX_SAVE_EP_NONE || \
     ((ep) < 64u && ((ep) >> 3) == \
      ((side) == NETCHESSZX_SAVE_SIDE_WHITE ? 2u : 5u)))

#define NETCHESSZX_SAVE_WIRE_VERSION 1u
#define NETCHESSZX_SAVE_WIRE_SIZE 45u
#define NETCHESSZX_SAVE_WIRE_B64_SIZE 60u
#define NETCHESSZX_SAVE_WIRE_CHUNK_SIZE 30u
#define NETCHESSZX_SAVE_RESTORE_FRAME_MAX 35u

typedef struct {
    char cells[64];
    uint16_t ply;
    uint8_t side;
    uint8_t castle;
    uint8_t ep;
    uint8_t host_color;
    uint8_t flags;
    uint8_t game_hour;
    uint8_t game_minute;
    uint8_t game_second;
    uint8_t move_hour;
    uint8_t move_minute;
    uint8_t move_second;
    uint8_t view_flags;
} netchesszx_save_state_t;

typedef struct {
    uint16_t ply;
    uint8_t flags;
    uint8_t host_color;
    uint8_t view_flags;
    uint8_t timers[6];
} netchesszx_save_meta_t;

enum {
    NETCHESSZX_SAVE_OK = 0,
    NETCHESSZX_SAVE_ERR_NULL = -1,
    NETCHESSZX_SAVE_ERR_BUFFER = -2,
    NETCHESSZX_SAVE_ERR_TOKEN = -3,
    NETCHESSZX_SAVE_ERR_FIELD = -4,
    NETCHESSZX_SAVE_ERR_BOARD = -5,
    NETCHESSZX_SAVE_ERR_CRC = -6
};

#endif

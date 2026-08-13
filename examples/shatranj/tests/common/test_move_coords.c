#include "common/chess/move_coords.h"

#include <stdio.h>
#include <stdlib.h>

static void check(int condition, const char *message)
{
    if (!condition) {
        fprintf(stderr, "FAIL: %s\n", message);
        exit(1);
    }
}

static void expect_valid(const char *move,
                         uint8_t from_row,
                         uint8_t from_col,
                         uint8_t to_row,
                         uint8_t to_col)
{
    uint16_t coords = netchesszx_move_parse_coords(move);
    uint8_t from_idx = NETCHESSZX_MOVE_FROM_INDEX(coords);
    uint8_t to_idx = NETCHESSZX_MOVE_TO_INDEX(coords);

    check(coords != NETCHESSZX_MOVE_COORDS_INVALID, "valid move");
    check((from_idx >> 3) == from_row && (from_idx & 7u) == from_col &&
          (to_idx >> 3) == to_row && (to_idx & 7u) == to_col,
          "valid move coords");
}

static void expect_invalid(const char *move)
{
    check(netchesszx_move_parse_coords(move) == NETCHESSZX_MOVE_COORDS_INVALID,
          "invalid move");
}

static void check_all_squares(void)
{
    char move[5];
    uint8_t from_idx;
    uint8_t to_idx;

    move[4] = '\0';
    for (from_idx = 0u; from_idx < 64u; ++from_idx) {
        move[0] = (char)('a' + (from_idx & 7u));
        move[1] = (char)('8' - (from_idx >> 3));
        for (to_idx = 0u; to_idx < 64u; ++to_idx) {
            uint16_t coords;

            move[2] = (char)('a' + (to_idx & 7u));
            move[3] = (char)('8' - (to_idx >> 3));
            coords = netchesszx_move_parse_coords(move);
            if (from_idx == to_idx) {
                check(coords == NETCHESSZX_MOVE_COORDS_INVALID,
                      "same square invalid");
            } else {
                check(NETCHESSZX_MOVE_FROM_INDEX(coords) == from_idx &&
                      NETCHESSZX_MOVE_TO_INDEX(coords) == to_idx,
                      "all square pairs");
            }
        }
    }
}

int main(void)
{
    expect_valid("a8h1", 0u, 0u, 7u, 7u);
    expect_valid("e2e4", 6u, 4u, 4u, 4u);
    expect_valid("h1a8", 7u, 7u, 0u, 0u);
    expect_valid("a7a8q", 1u, 0u, 0u, 0u);
    expect_valid("a7a8x", 1u, 0u, 0u, 0u);
    check(netchesszx_move_parse_coords("a8h1") == 0x3f00u,
          "packed layout is 0xTTFF");

    expect_invalid("a8a8");
    expect_invalid("h1h1");
    expect_invalid("a1a1");
    expect_invalid("A1B2");
    expect_invalid("`1a1");
    expect_invalid("a9a8");
    expect_invalid("i1a1");
    expect_invalid("a0a1");
    expect_invalid("a1a9");
    expect_invalid("a1i1");

    check_all_squares();

    puts("move coords tests ok");
    return 0;
}

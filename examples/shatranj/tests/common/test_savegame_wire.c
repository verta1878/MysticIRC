#include "common/savegame/savegame_wire.h"
#include "spectrum/restore/restore.h"

#include <stdio.h>
#include <string.h>

static int failures;

typedef struct {
    const char *name;
    uint8_t offset;
    uint8_t and_mask;
    uint8_t or_mask;
    int expected_error;
} negative_restore_vector_t;

static const negative_restore_vector_t negative_restore_vectors[] = {
    {"game hour 100", 37u, 0u, 100u, NETCHESSZX_SAVE_ERR_FIELD},
    {"game minute 60", 38u, 0u, 60u, NETCHESSZX_SAVE_ERR_FIELD},
    {"move second 60", 42u, 0u, 60u, NETCHESSZX_SAVE_ERR_FIELD},
    {"missing black king", 2u, 0x0fu, 0u, NETCHESSZX_SAVE_ERR_BOARD},
    {"missing white king", 30u, 0x0fu, 0u, NETCHESSZX_SAVE_ERR_BOARD},
    {"duplicate black king", 8u, 0x0fu, 0xd0u, NETCHESSZX_SAVE_ERR_BOARD},
    {"duplicate white king", 8u, 0x0fu, 0x60u, NETCHESSZX_SAVE_ERR_BOARD},
    {"white pawn on rank 8", 0u, 0x0fu, 0x10u, NETCHESSZX_SAVE_ERR_BOARD},
    {"black pawn on rank 1", 31u, 0xf0u, 0x08u, NETCHESSZX_SAVE_ERR_BOARD}
};

static void expect_int(const char *name, int got, int want)
{
    if (got != want) {
        printf("FAIL %s: got %d want %d\n", name, got, want);
        ++failures;
    }
}

static void expect_true(const char *name, int got)
{
    if (!got) {
        printf("FAIL %s\n", name);
        ++failures;
    }
}

static uint8_t test_crc8(const uint8_t *data, uint8_t len)
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

static netchesszx_save_state_t sample_state(void)
{
    netchesszx_save_state_t state;
    static const char board[] =
        "rnbqkbnr"
        "pppp.ppp"
        "........"
        "....p..."
        "....P..."
        "........"
        "PPPP.PPP"
        "RNBQKBNR";

    memset(&state, 0, sizeof(state));
    memcpy(state.cells, board, 64u);
    state.ply = 3u;
    state.side = 1u;
    state.castle = 0x0fu;
    state.ep = NETCHESSZX_SAVE_EP_NONE;
    state.host_color = NETCHESSZX_SAVE_HOST_BLACK;
    state.flags = NETCHESSZX_SAVE_FLAG_ACTIVE | NETCHESSZX_SAVE_FLAG_CHECK;
    state.game_hour = 1u;
    state.game_minute = 2u;
    state.game_second = 3u;
    state.move_hour = 0u;
    state.move_minute = 4u;
    state.move_second = 5u;
    state.view_flags = NETCHESSZX_SAVE_VIEW_FLIPPED;
    return state;
}

static void test_rejects_bad_state(void)
{
    uint8_t wire[NETCHESSZX_SAVE_WIRE_SIZE];
    netchesszx_save_state_t state = sample_state();

    expect_int("short wire pack", netchesszx_save_wire_pack(wire, 4u, &state),
               NETCHESSZX_SAVE_ERR_BUFFER);

    state = sample_state();
    state.side = 0u;
    expect_int("bad ply side", netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_ERR_FIELD);

    state = sample_state();
    state.cells[0] = 'x';
    expect_int("bad piece", netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_ERR_BOARD);

    state = sample_state();
    state.castle = 0x10u;
    expect_int("bad castle", netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_ERR_FIELD);

    state = sample_state();
    state.ep = 64u;
    expect_int("bad ep", netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_ERR_FIELD);

    state = sample_state();
    state.move_second = 60u;
    expect_int("bad timer", netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_ERR_FIELD);

    state = sample_state();
    state.view_flags = 0x02u;
    expect_int("bad view flags", netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_ERR_FIELD);
}

static void test_wire_roundtrip(void)
{
    uint8_t wire[NETCHESSZX_SAVE_WIRE_SIZE];
    uint8_t decoded_wire[NETCHESSZX_SAVE_WIRE_SIZE];
    char b64[NETCHESSZX_SAVE_WIRE_B64_SIZE];
    netchesszx_save_state_t in = sample_state();
    netchesszx_save_state_t out;

    expect_int("wire pack", netchesszx_save_wire_pack(wire, sizeof(wire), &in),
               NETCHESSZX_SAVE_OK);
    expect_int("wire unpack", netchesszx_save_wire_unpack(&out, wire, sizeof(wire)),
               NETCHESSZX_SAVE_OK);
    expect_true("wire state", memcmp(&out, &in, sizeof(in)) == 0);

    expect_int("b64 encode",
               netchesszx_save_wire_b64_encode(b64, sizeof(b64), wire, sizeof(wire)),
               NETCHESSZX_SAVE_OK);
    expect_int("b64 decode",
               netchesszx_save_wire_b64_decode(decoded_wire, sizeof(decoded_wire),
                                               b64, sizeof(b64)),
               NETCHESSZX_SAVE_OK);
    expect_true("b64 wire", memcmp(decoded_wire, wire, sizeof(wire)) == 0);
    expect_true("chunk frame length",
                NETCHESSZX_SAVE_RESTORE_FRAME_MAX <= 47u &&
                (2u + 2u + 1u + NETCHESSZX_SAVE_WIRE_CHUNK_SIZE) ==
                    NETCHESSZX_SAVE_RESTORE_FRAME_MAX);
}

static void test_spectrum_golden_vector(void)
{
    static const char expected_b64[] =
        "uazam4iIiIgAAAAAAAAAAAAAAAAAAAAAEREREUI1YyR8_wAAAQEAAAAAOwGm";
    static const char initial_board[] =
        "rnbqkbnr"
        "pppppppp"
        "........"
        "........"
        "........"
        "........"
        "PPPPPPPP"
        "RNBQKBNR";
    uint8_t wire[NETCHESSZX_SAVE_WIRE_SIZE];
    uint8_t decoded_wire[NETCHESSZX_SAVE_WIRE_SIZE];
    char b64[NETCHESSZX_SAVE_WIRE_B64_SIZE];
    netchesszx_save_state_t source;
    netchesszx_save_state_t decoded;

    memset(&source, 0, sizeof(source));
    memcpy(source.cells, initial_board, sizeof(source.cells));
    source.side = NETCHESSZX_SAVE_SIDE_WHITE;
    source.castle = 0x0fu;
    source.ep = NETCHESSZX_SAVE_EP_NONE;
    source.host_color = NETCHESSZX_SAVE_HOST_WHITE;
    source.flags = NETCHESSZX_SAVE_FLAG_ACTIVE;
    source.game_hour = 1u;
    source.move_second = 59u;
    source.view_flags = NETCHESSZX_SAVE_VIEW_FLIPPED;

    expect_int("golden wire pack",
               netchesszx_save_wire_pack(wire, sizeof(wire), &source),
               NETCHESSZX_SAVE_OK);
    expect_int("golden b64 encode",
               netchesszx_save_wire_b64_encode(b64, sizeof(b64),
                                               wire, sizeof(wire)),
               NETCHESSZX_SAVE_OK);
    expect_true("Spectrum golden encode",
                sizeof(expected_b64) - 1u == sizeof(b64) &&
                memcmp(b64, expected_b64, sizeof(b64)) == 0);
    expect_int("golden b64 decode",
               netchesszx_save_wire_b64_decode(decoded_wire,
                                               sizeof(decoded_wire),
                                               expected_b64,
                                               sizeof(expected_b64) - 1u),
               NETCHESSZX_SAVE_OK);
    expect_int("golden wire unpack",
               netchesszx_save_wire_unpack(&decoded, decoded_wire,
                                           sizeof(decoded_wire)),
               NETCHESSZX_SAVE_OK);
    expect_true("Spectrum golden state",
                memcmp(&decoded, &source, sizeof(source)) == 0);
}

static void test_rejects_bad_wire(void)
{
    uint8_t wire[NETCHESSZX_SAVE_WIRE_SIZE];
    uint8_t decoded_wire[NETCHESSZX_SAVE_WIRE_SIZE];
    char b64[NETCHESSZX_SAVE_WIRE_B64_SIZE];
    netchesszx_save_state_t state = sample_state();
    netchesszx_save_state_t out;

    expect_int("wire pack good", netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_OK);

    wire[0] ^= 0x01u;
    expect_int("bad crc", netchesszx_save_wire_unpack(&out, wire, sizeof(wire)),
               NETCHESSZX_SAVE_ERR_CRC);

    expect_int("wire repack", netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_OK);
    wire[0] = 0x70u;
    wire[44] = 0u;
    expect_true("force crc update",
                netchesszx_save_wire_pack(wire, sizeof(wire), &state) ==
                    NETCHESSZX_SAVE_OK);
    wire[0] = 0x70u;
    wire[44] = test_crc8(wire, 44u);
    expect_int("reserved nibble", netchesszx_save_wire_unpack(&out, wire, sizeof(wire)),
               NETCHESSZX_SAVE_ERR_BOARD);

    expect_int("wire repack 2", netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_OK);
    expect_int("b64 encode good",
               netchesszx_save_wire_b64_encode(b64, sizeof(b64), wire, sizeof(wire)),
               NETCHESSZX_SAVE_OK);
    b64[3] = '=';
    expect_int("bad b64",
               netchesszx_save_wire_b64_decode(decoded_wire, sizeof(decoded_wire),
                                               b64, sizeof(b64)),
               NETCHESSZX_SAVE_ERR_TOKEN);
}

static void test_ep_rank(void)
{
    uint8_t wire[NETCHESSZX_SAVE_WIRE_SIZE];
    netchesszx_save_state_t state = sample_state();

    state = sample_state();
    state.ep = 44u;
    expect_int("black ep rank5 ok",
               netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_OK);

    state = sample_state();
    state.ep = 20u;
    expect_int("black ep rank2 rejected",
               netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_ERR_FIELD);

    state = sample_state();
    state.side = NETCHESSZX_SAVE_SIDE_WHITE;
    state.ply = 2u;
    state.ep = 20u;
    expect_int("white ep rank2 ok",
               netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_OK);

    state = sample_state();
    state.side = NETCHESSZX_SAVE_SIDE_WHITE;
    state.ply = 2u;
    state.ep = 44u;
    expect_int("white ep rank5 rejected",
               netchesszx_save_wire_pack(wire, sizeof(wire), &state),
               NETCHESSZX_SAVE_ERR_FIELD);
}

static void test_negative_restore_vectors(void)
{
    uint8_t wire[NETCHESSZX_SAVE_WIRE_SIZE];
    uint8_t decoded_wire[NETCHESSZX_SAVE_WIRE_SIZE];
    char b64[NETCHESSZX_SAVE_WIRE_B64_SIZE];
    netchesszx_save_state_t source = sample_state();
    netchesszx_save_state_t decoded;
    spectrum_board_snapshot_t spectrum_snapshot;
    netchesszx_save_meta_t spectrum_meta;
    size_t i;
    int rc;

    for (i = 0u;
         i < sizeof(negative_restore_vectors) /
                 sizeof(negative_restore_vectors[0]);
         ++i) {
        const negative_restore_vector_t *vector = &negative_restore_vectors[i];

        expect_int("negative vector base pack",
                   netchesszx_save_wire_pack(wire, sizeof(wire), &source),
                   NETCHESSZX_SAVE_OK);
        wire[vector->offset] =
            (uint8_t)((wire[vector->offset] & vector->and_mask) |
                      vector->or_mask);
        wire[44] = test_crc8(wire, 44u);
        expect_int("negative vector b64 encode",
                   netchesszx_save_wire_b64_encode(b64, sizeof(b64),
                                                  wire, sizeof(wire)),
                   NETCHESSZX_SAVE_OK);
        expect_int("negative vector b64 decode",
                   netchesszx_save_wire_b64_decode(decoded_wire,
                                                  sizeof(decoded_wire),
                                                  b64, sizeof(b64)),
                   NETCHESSZX_SAVE_OK);
        rc = netchesszx_save_wire_unpack(&decoded, decoded_wire,
                                         sizeof(decoded_wire));
        if (rc != vector->expected_error) {
            printf("FAIL common rejects %s: got %d want %d\n",
                   vector->name, rc, vector->expected_error);
            ++failures;
        }
        if (spectrum_restore_decode(b64, &spectrum_snapshot, &spectrum_meta)) {
            printf("FAIL Spectrum rejects %s\n", vector->name);
            ++failures;
        }
    }
}

int main(void)
{
    test_rejects_bad_state();
    test_wire_roundtrip();
    test_spectrum_golden_vector();
    test_rejects_bad_wire();
    test_ep_rank();
    test_negative_restore_vectors();

    if (failures != 0) {
        printf("%d failure(s)\n", failures);
        return 1;
    }
    printf("savegame wire tests ok\n");
    return 0;
}

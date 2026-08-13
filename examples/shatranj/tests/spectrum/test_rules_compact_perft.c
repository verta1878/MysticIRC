#include "spectrum/board/board.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TEST_WHITE 0u
#define TEST_BLACK 1u
#define TEST_CASTLE_WK 1u
#define TEST_CASTLE_WQ 2u
#define TEST_CASTLE_BK 4u
#define TEST_CASTLE_BQ 8u
#define TEST_NO_EP (-1)

typedef struct perft_case {
    const char *name;
    const char *fen;
    uint64_t expected[5];
    uint8_t depths;
} perft_case_t;

static int failures;

static void expect_u64(const char *name, uint8_t depth,
                       uint64_t got, uint64_t want)
{
    if (got != want) {
        printf("FAIL %s depth %u: got %llu want %llu\n",
               name,
               (unsigned)depth,
               (unsigned long long)got,
               (unsigned long long)want);
        ++failures;
    }
}

static uint8_t parse_fen(const char *fen)
{
    char cells[64];
    uint8_t row = 0u;
    uint8_t col = 0u;
    uint8_t side = TEST_WHITE;
    uint8_t castle = 0u;
    int8_t ep = TEST_NO_EP;
    const char *p = fen;
    uint8_t i;

    for (i = 0u; i < 64u; ++i) {
        cells[i] = '.';
    }

    while (*p != '\0' && *p != ' ') {
        if (*p == '/') {
            if (col != 8u || row >= 7u) {
                return 0u;
            }
            ++row;
            col = 0u;
        } else if (*p >= '1' && *p <= '8') {
            uint8_t empty = (uint8_t)(*p - '0');
            if ((uint8_t)(col + empty) > 8u) {
                return 0u;
            }
            col = (uint8_t)(col + empty);
        } else {
            if (row >= 8u || col >= 8u) {
                return 0u;
            }
            cells[(uint8_t)((row << 3) + col)] = *p;
            ++col;
        }
        ++p;
    }
    if (row != 7u || col != 8u || *p != ' ') {
        return 0u;
    }
    ++p;

    if (*p == 'w') {
        side = TEST_WHITE;
    } else if (*p == 'b') {
        side = TEST_BLACK;
    } else {
        return 0u;
    }
    ++p;
    if (*p != ' ') {
        return 0u;
    }
    ++p;

    if (*p == '-') {
        ++p;
    } else {
        while (*p != '\0' && *p != ' ') {
            switch (*p) {
            case 'K':
                castle |= TEST_CASTLE_WK;
                break;
            case 'Q':
                castle |= TEST_CASTLE_WQ;
                break;
            case 'k':
                castle |= TEST_CASTLE_BK;
                break;
            case 'q':
                castle |= TEST_CASTLE_BQ;
                break;
            default:
                return 0u;
            }
            ++p;
        }
    }
    if (*p != ' ') {
        return 0u;
    }
    ++p;

    if (*p == '-') {
        ++p;
    } else {
        if (p[0] < 'a' || p[0] > 'h' || p[1] < '1' || p[1] > '8') {
            return 0u;
        }
        ep = (int8_t)((('8' - p[1]) << 3) + (p[0] - 'a'));
        p += 2;
    }

    spectrum_board_test_set(cells, side, castle, ep);
    return 1u;
}

static void make_move_text(uint8_t from, uint8_t to, char promo, char out[6])
{
    out[0] = (char)('a' + (from & 7u));
    out[1] = (char)('8' - (from >> 3));
    out[2] = (char)('a' + (to & 7u));
    out[3] = (char)('8' - (to >> 3));
    out[4] = promo;
    out[5] = '\0';
}

static uint8_t is_promotion_target(uint8_t from, uint8_t to)
{
    const char piece = spectrum_board_cell((uint8_t)(from >> 3),
                                           (uint8_t)(from & 7u));
    const uint8_t to_row = (uint8_t)(to >> 3);

    return (uint8_t)((piece == 'P' && to_row == 0u) ||
                     (piece == 'p' && to_row == 7u));
}

static void dump_legal_moves(const char *name)
{
    uint8_t from;
    uint8_t to;

    printf("legal moves for %s:", name);
    for (from = 0u; from < 64u; ++from) {
        for (to = 0u; to < 64u; ++to) {
            char move[6];
            static const char promos[] = {'q', 'r', 'b', 'n'};
            const uint8_t promote = is_promotion_target(from, to);
            const uint8_t promo_count = promote ? 4u : 1u;
            uint8_t i;

            for (i = 0u; i < promo_count; ++i) {
                const char promo = promote ? promos[i] : '\0';

                make_move_text(from, to, promo, move);
                if (spectrum_board_is_legal_move(move)) {
                    printf(" %s", move);
                }
            }
        }
    }
    printf("\n");
}

static uint64_t perft(uint8_t depth)
{
    uint64_t nodes = 0u;
    uint8_t from;
    uint8_t to;

    if (depth == 0u) {
        return 1u;
    }

    for (from = 0u; from < 64u; ++from) {
        for (to = 0u; to < 64u; ++to) {
            char move[6];
            static const char promos[] = {'q', 'r', 'b', 'n'};
            const uint8_t promote = is_promotion_target(from, to);
            uint8_t promo_count = promote ? 4u : 1u;
            uint8_t i;

            for (i = 0u; i < promo_count; ++i) {
                spectrum_board_snapshot_t snapshot;
                const char promo = promote ? promos[i] : '\0';

                make_move_text(from, to, promo, move);
                if (!spectrum_board_is_legal_move(move)) {
                    continue;
                }
                if (depth == 1u) {
                    ++nodes;
                    continue;
                }

                spectrum_board_snapshot_save(&snapshot);
                if (!spectrum_board_apply_move(move)) {
                    printf("FAIL apply legal move %s at depth %u\n",
                           move, (unsigned)depth);
                    ++failures;
                    spectrum_board_snapshot_restore(&snapshot);
                    continue;
                }
                nodes += perft((uint8_t)(depth - 1u));
                spectrum_board_snapshot_restore(&snapshot);
            }
        }
    }

    return nodes;
}

static void run_case(const perft_case_t *test)
{
    uint8_t depth;

    if (!parse_fen(test->fen)) {
        printf("FAIL %s: bad FEN fixture\n", test->name);
        ++failures;
        return;
    }

    for (depth = 1u; depth <= test->depths; ++depth) {
        uint64_t got;

        if (!parse_fen(test->fen)) {
            printf("FAIL %s: bad FEN reload\n", test->name);
            ++failures;
            return;
        }
        got = perft(depth);
        if (depth == 1u && got != test->expected[depth - 1u]) {
            dump_legal_moves(test->name);
        }
        expect_u64(test->name, depth, got, test->expected[depth - 1u]);
    }
}

static void run_optional_deep(void)
{
    const char *deep = getenv("NETCHESSZX_DEEP_PERFT");
    if (deep == NULL || deep[0] == '\0' || deep[0] == '0') {
        return;
    }

    {
        static const perft_case_t deeper[] = {
            {
                "startpos-deep",
                "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
                {20ULL, 400ULL, 8902ULL, 197281ULL, 4865609ULL},
                5u
            },
            {
                "kiwipete-deep",
                "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
                {48ULL, 2039ULL, 97862ULL, 4085603ULL, 193690690ULL},
                4u
            }
        };
        uint8_t i;

        for (i = 0u; i < sizeof(deeper) / sizeof(deeper[0]); ++i) {
            run_case(&deeper[i]);
        }
    }
}

static int run_single_perft(const char *fen, uint8_t depth)
{
    uint64_t got;

    if (!parse_fen(fen)) {
        printf("bad FEN\n");
        return 2;
    }
    got = perft(depth);
    printf("%llu\n", (unsigned long long)got);
    return failures == 0 ? 0 : 1;
}

static int run_single_moves(const char *fen)
{
    uint8_t from;
    uint8_t to;

    if (!parse_fen(fen)) {
        printf("bad FEN\n");
        return 2;
    }
    for (from = 0u; from < 64u; ++from) {
        for (to = 0u; to < 64u; ++to) {
            char move[6];
            static const char promos[] = {'q', 'r', 'b', 'n'};
            const uint8_t promote = is_promotion_target(from, to);
            const uint8_t promo_count = promote ? 4u : 1u;
            uint8_t i;

            for (i = 0u; i < promo_count; ++i) {
                const char promo = promote ? promos[i] : '\0';

                make_move_text(from, to, promo, move);
                if (spectrum_board_is_legal_move(move)) {
                    printf("%s\n", move);
                }
            }
        }
    }
    return failures == 0 ? 0 : 1;
}

static int run_static_cases(void)
{
    static const perft_case_t cases[] = {
        {
            "startpos",
            "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
            {20ULL, 400ULL, 8902ULL, 197281ULL, 0ULL},
            4u
        },
        {
            "kiwipete",
            "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
            {48ULL, 2039ULL, 97862ULL, 0ULL, 0ULL},
            3u
        },
        {
            "promotion-castle",
            "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
            {6ULL, 264ULL, 9467ULL, 0ULL, 0ULL},
            3u
        },
        {
            "promotion-checks",
            "rnbq1k1r/pp1Pbppp/2p5/8/2B1P3/8/PPP2PPP/RNBQK1NR b KQ - 1 8",
            {28ULL, 1264ULL, 36366ULL, 0ULL, 0ULL},
            3u
        },
        {
            "middlegame-pins",
            "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/2NP1N2/PPP2PPP/R2Q1RK1 w - - 0 10",
            {40ULL, 1809ULL, 70450ULL, 0ULL, 0ULL},
            3u
        }
    };
    uint8_t i;

    for (i = 0u; i < sizeof(cases) / sizeof(cases[0]); ++i) {
        run_case(&cases[i]);
    }
    run_optional_deep();

    if (failures != 0) {
        printf("%d failure(s)\n", failures);
        return 1;
    }
    printf("rules compact perft tests ok\n");
    return 0;
}

int main(int argc, char **argv)
{
    if (argc == 3 && strcmp(argv[1], "--moves") == 0) {
        return run_single_moves(argv[2]);
    }
    if (argc == 3) {
        int depth = atoi(argv[2]);
        if (depth < 0 || depth > 5) {
            printf("bad depth\n");
            return 2;
        }
        return run_single_perft(argv[1], (uint8_t)depth);
    }
    if (argc != 1) {
        printf("usage: netchesszx_rules_compact_perft_test [fen depth]|[--moves fen]\n");
        return 2;
    }
    return run_static_cases();
}
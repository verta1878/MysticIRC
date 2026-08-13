#include "common/chess/position.h"
#include "common/chess/legal.h"
#include "common/chess/rules_compact.h"

#include <stdio.h>
#include <string.h>

static int failures;

static void expect_int(const char *name, int got, int want)
{
    if (got != want) {
        printf("FAIL %s: got %d want %d\n", name, got, want);
        ++failures;
    }
}

static void expect_str(const char *name, const char *got, const char *want)
{
    if (strcmp(got, want) != 0) {
        printf("FAIL %s:\n  got  %s\n  want %s\n", name, got, want);
        ++failures;
    }
}

static void roundtrip(const char *name, const char *fen)
{
    netchesszx_position_t pos;
    char out[128];
    int rc;

    rc = netchesszx_fen_import(&pos, fen);
    if (rc != NETCHESSZX_OK) {
        printf("FAIL %s import: %s\n", name, netchesszx_error_string(rc));
        ++failures;
        return;
    }

    rc = netchesszx_fen_export(&pos, out, sizeof(out));
    if (rc != NETCHESSZX_OK) {
        printf("FAIL %s export: %s\n", name, netchesszx_error_string(rc));
        ++failures;
        return;
    }

    expect_str(name, out, fen);
}

static void test_square_mapping(void)
{
    char coord[3];

    expect_int("a1 index", netchesszx_square_index('a', '1'), 21);
    expect_int("h1 index", netchesszx_square_index('h', '1'), 28);
    expect_int("a8 index", netchesszx_square_index('a', '8'), 91);
    expect_int("h8 index", netchesszx_square_index('h', '8'), 98);
    expect_int("bad file", netchesszx_square_index('i', '1'), NETCHESSZX_NO_SQUARE);
    expect_int("bad rank", netchesszx_square_index('a', '9'), NETCHESSZX_NO_SQUARE);

    expect_int("coord e4", netchesszx_square_to_coord(55, coord), NETCHESSZX_OK);
    expect_str("coord e4 text", coord, "e4");
}

static void test_roundtrip(void)
{
    roundtrip("startpos",
              "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1");
    roundtrip("kiwipete",
              "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1");
    roundtrip("ep",
              "rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 3");
    roundtrip("empty castle",
              "8/8/8/8/8/8/8/8 b - - 99 42");
}

static void test_invalid(void)
{
    netchesszx_position_t pos;

    expect_int("bad board short",
               netchesszx_fen_import(&pos, "8/8/8/8/8/8/8 w - - 0 1"),
               NETCHESSZX_ERR_BOARD);
    expect_int("bad board wide",
               netchesszx_fen_import(&pos, "9/8/8/8/8/8/8/8 w - - 0 1"),
               NETCHESSZX_ERR_BOARD);
    expect_int("bad side",
               netchesszx_fen_import(&pos, "8/8/8/8/8/8/8/8 x - - 0 1"),
               NETCHESSZX_ERR_SIDE);
    expect_int("bad castle duplicate",
               netchesszx_fen_import(&pos, "8/8/8/8/8/8/8/8 w KK - 0 1"),
               NETCHESSZX_ERR_CASTLE);
    expect_int("bad ep rank",
               netchesszx_fen_import(&pos, "8/8/8/8/8/8/8/8 w - e4 0 1"),
               NETCHESSZX_ERR_EP);
    expect_int("bad fullmove zero",
               netchesszx_fen_import(&pos, "8/8/8/8/8/8/8/8 w - - 0 0"),
               NETCHESSZX_ERR_NUMBER);
}

static void test_legal_moves(void)
{
    char targets[64];

    expect_int("rules reset", netchesszx_rules_reset(), NETCHESSZX_OK);
    expect_int("start e2e4 legal", netchesszx_rules_can_play("e2e4"), NETCHESSZX_OK);
    expect_int("start g1f3 legal", netchesszx_rules_can_play("g1f3"), NETCHESSZX_OK);
    expect_int("start e2e5 illegal", netchesszx_rules_can_play("e2e5"), NETCHESSZX_ERR_ILLEGAL);
    expect_int("start e7e8n illegal", netchesszx_rules_can_play("e7e8n"), NETCHESSZX_ERR_MOVE);
    expect_int("targets e2", netchesszx_rules_legal_targets("e2", targets, sizeof(targets)), NETCHESSZX_OK);
    expect_str("targets e2 text", targets, "e3 e4");
    expect_int("targets e7 empty", netchesszx_rules_legal_targets("e7", targets, sizeof(targets)), NETCHESSZX_OK);
    expect_str("targets e7 text", targets, "");
    expect_int("initial check state", netchesszx_rules_check_state(),
               NETCHESSZX_RULE_CHECK_NONE);
    expect_int("initial legal replies", netchesszx_rules_has_legal_moves(), 1);

    expect_int("play e2e4", netchesszx_rules_play("e2e4"), NETCHESSZX_OK);
    expect_int("black e7e5 legal", netchesszx_rules_can_play("e7e5"), NETCHESSZX_OK);
    expect_int("white second move illegal", netchesszx_rules_can_play("g1f3"), NETCHESSZX_ERR_ILLEGAL);
    expect_int("play e7e5", netchesszx_rules_play("e7e5"), NETCHESSZX_OK);
    expect_int("white g1f3 after black", netchesszx_rules_can_play("g1f3"), NETCHESSZX_OK);
    expect_int("play g1f3", netchesszx_rules_play("g1f3"), NETCHESSZX_OK);
    expect_int("play d7d5", netchesszx_rules_play("d7d5"), NETCHESSZX_OK);
    expect_int("e4xd5 legal", netchesszx_rules_can_play("e4d5"), NETCHESSZX_OK);
    expect_int("e4 targets", netchesszx_rules_legal_targets("e4", targets, sizeof(targets)), NETCHESSZX_OK);
    expect_str("e4 targets text", targets, "d5");
    expect_int("play e4xd5", netchesszx_rules_play("e4d5"), NETCHESSZX_OK);

    expect_int("promotion reset", netchesszx_rules_reset(), NETCHESSZX_OK);
    expect_int("promo a2a4", netchesszx_rules_play("a2a4"), NETCHESSZX_OK);
    expect_int("promo h7h5", netchesszx_rules_play("h7h5"), NETCHESSZX_OK);
    expect_int("promo a4a5", netchesszx_rules_play("a4a5"), NETCHESSZX_OK);
    expect_int("promo h5h4", netchesszx_rules_play("h5h4"), NETCHESSZX_OK);
    expect_int("promo a5a6", netchesszx_rules_play("a5a6"), NETCHESSZX_OK);
    expect_int("promo h4h3", netchesszx_rules_play("h4h3"), NETCHESSZX_OK);
    expect_int("promo a6b7", netchesszx_rules_play("a6b7"), NETCHESSZX_OK);
    expect_int("promo h3g2", netchesszx_rules_play("h3g2"), NETCHESSZX_OK);
    expect_int("promo missing suffix", netchesszx_rules_can_play("b7c8"), NETCHESSZX_ERR_MOVE);
    expect_int("promo knight legal", netchesszx_rules_can_play("b7c8n"), NETCHESSZX_OK);
    expect_int("promo knight play", netchesszx_rules_play("b7c8n"), NETCHESSZX_OK);

    expect_int("check reset", netchesszx_rules_reset(), NETCHESSZX_OK);
    expect_int("check e2e4", netchesszx_rules_play("e2e4"), NETCHESSZX_OK);
    expect_int("check d7d5", netchesszx_rules_play("d7d5"), NETCHESSZX_OK);
    expect_int("check f1b5", netchesszx_rules_play("f1b5"), NETCHESSZX_OK);
    expect_int("check state", netchesszx_rules_check_state(),
               NETCHESSZX_RULE_CHECK);
    expect_int("check has replies", netchesszx_rules_has_legal_moves(), 1);

    expect_int("mate reset", netchesszx_rules_reset(), NETCHESSZX_OK);
    expect_int("mate f2f3", netchesszx_rules_play("f2f3"), NETCHESSZX_OK);
    expect_int("mate e7e5", netchesszx_rules_play("e7e5"), NETCHESSZX_OK);
    expect_int("mate g2g4", netchesszx_rules_play("g2g4"), NETCHESSZX_OK);
    expect_int("mate d8h4", netchesszx_rules_play("d8h4"), NETCHESSZX_OK);
    expect_int("mate check state", netchesszx_rules_check_state(),
               NETCHESSZX_RULE_CHECK_MATE);
    expect_int("mate no legal replies", netchesszx_rules_has_legal_moves(), 0);
}

int main(void)
{
    test_square_mapping();
    test_roundtrip();
    test_invalid();
    test_legal_moves();

    if (failures != 0) {
        printf("%d failure(s)\n", failures);
        return 1;
    }

    printf("rules fen tests ok\n");
    return 0;
}

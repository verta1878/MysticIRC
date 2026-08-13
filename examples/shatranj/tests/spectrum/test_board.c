#include "spectrum/board/board.h"
#include "spectrum/board/san.h"
#include "common/chess/legal.h"

#include <stdio.h>
#include <string.h>

#define TEST_WHITE 0u
#define TEST_BLACK 1u
#define TEST_CASTLE_WK 1u
#define TEST_CASTLE_WQ 2u
#define TEST_CASTLE_BK 4u
#define TEST_CASTLE_BQ 8u
#define TEST_NO_EP (-1)
#define TEST_SQ(row, col) ((int8_t)(((row) << 3) + (col)))

static int failures;

static void expect_true(const char *name, uint8_t got)
{
    if (!got) {
        printf("FAIL %s: got false\n", name);
        ++failures;
    }
}

static void expect_false(const char *name, uint8_t got)
{
    if (got) {
        printf("FAIL %s: got true\n", name);
        ++failures;
    }
}

static void expect_cell(const char *name, uint8_t row, uint8_t col, char want)
{
    char got = spectrum_board_cell(row, col);

    if (got != want) {
        printf("FAIL %s: got %c want %c\n", name, got, want);
        ++failures;
    }
}

static void expect_text(const char *name, const char *got, const char *want)
{
    if (strcmp(got, want) != 0) {
        printf("FAIL %s: got %s want %s\n", name, got, want);
        ++failures;
    }
}

static void expect_san_base(const char *name, const char *move,
                            const char *want)
{
    char san[SPECTRUM_SAN_TEXT_MAX];

    if (spectrum_board_move_san_base(move, san) == 0u) {
        printf("FAIL %s: SAN generation failed for %s\n", name, move);
        ++failures;
        return;
    }
    expect_text(name, san, want);
}

static void expect_san_after_apply(const char *name, const char *move,
                                   const char *want)
{
    char san[SPECTRUM_SAN_TEXT_MAX];

    if (spectrum_board_move_san_base(move, san) == 0u) {
        printf("FAIL %s: SAN generation failed for %s\n", name, move);
        ++failures;
        return;
    }
    if (!spectrum_board_apply_move(move)) {
        printf("FAIL %s: apply failed for %s\n", name, move);
        ++failures;
        return;
    }
    (void)spectrum_board_san_append_suffix(san);
    expect_text(name, san, want);
}

static void set_test_board_state(const char *cells,
                                 uint8_t side,
                                 uint8_t castle,
                                 int8_t ep)
{
    spectrum_board_test_set(cells, side, castle, ep);
}

static void set_test_board(const char *cells, uint8_t side, int8_t ep)
{
    set_test_board_state(cells, side, 0u, ep);
}

static void expect_undo_roundtrip(const char *name, const char *move)
{
    spectrum_board_snapshot_t before;
    spectrum_board_snapshot_t after;
    spectrum_board_undo_t undo;

    spectrum_board_snapshot_save(&before);
    if (!spectrum_board_apply_trusted_move_with_undo(move, &undo)) {
        printf("FAIL %s: apply failed for %s\n", name, move);
        ++failures;
        return;
    }
    spectrum_board_undo_restore(&undo);
    spectrum_board_snapshot_save(&after);
    if (memcmp(&before, &after, sizeof(before)) != 0) {
        printf("FAIL %s: undo mismatch for %s\n", name, move);
        ++failures;
    }
}

static void compare_with_common_rules(const char *name, const char *move)
{
    uint8_t compact_legal = spectrum_board_is_legal_move(move);
    int rules_rc = netchesszx_rules_can_play(move);
    uint8_t rules_legal = (uint8_t)(rules_rc == NETCHESSZX_OK);

    if (compact_legal != rules_legal) {
        printf("FAIL %s: compact=%u common=%u rc=%d move=%s\n",
               name, compact_legal, rules_legal, rules_rc, move);
        ++failures;
        return;
    }

    if (compact_legal) {
        if (!spectrum_board_apply_move(move)) {
            printf("FAIL %s: compact apply failed %s\n", name, move);
            ++failures;
        }
        if (netchesszx_rules_play(move) != NETCHESSZX_OK) {
            printf("FAIL %s: common rules apply failed %s\n", name, move);
            ++failures;
        }
    }
}

static void test_reset_and_clear_representation(void)
{
    static const char start_cells[] =
        "rnbqkbnr"
        "pppppppp"
        "........"
        "........"
        "........"
        "........"
        "PPPPPPPP"
        "RNBQKBNR";
    static const int8_t start_rules[64] = {
        -4, -2, -3, -5, -6, -3, -2, -4,
        -1, -1, -1, -1, -1, -1, -1, -1,
         0,  0,  0,  0,  0,  0,  0,  0,
         0,  0,  0,  0,  0,  0,  0,  0,
         0,  0,  0,  0,  0,  0,  0,  0,
         0,  0,  0,  0,  0,  0,  0,  0,
         1,  1,  1,  1,  1,  1,  1,  1,
         4,  2,  3,  5,  6,  3,  2,  4
    };
    spectrum_board_snapshot_t snapshot;
    uint8_t i;

    spectrum_board_reset();
    spectrum_board_snapshot_save(&snapshot);
    if (memcmp(snapshot.cells, start_cells, 64u) != 0 ||
        snapshot.side != TEST_WHITE ||
        snapshot.castle != (TEST_CASTLE_WK | TEST_CASTLE_WQ |
                            TEST_CASTLE_BK | TEST_CASTLE_BQ) ||
        snapshot.ep != TEST_NO_EP) {
        printf("FAIL reset snapshot representation\n");
        ++failures;
    }
    for (i = 0u; i < 64u; ++i) {
        if (spectrum_board_test_rule_cell(i) != start_rules[i]) {
            printf("FAIL reset rules cell %u\n", i);
            ++failures;
        }
    }
    if (spectrum_board_test_rule_cell(64u) != 0) {
        printf("FAIL rules cell bounds\n");
        ++failures;
    }

    spectrum_board_clear();
    spectrum_board_snapshot_save(&snapshot);
    if (snapshot.side != TEST_WHITE || snapshot.castle != 0u ||
        snapshot.ep != TEST_NO_EP) {
        printf("FAIL clear snapshot state\n");
        ++failures;
    }
    for (i = 0u; i < 64u; ++i) {
        if (snapshot.cells[i] != '.' ||
            spectrum_board_test_rule_cell(i) != 0) {
            printf("FAIL clear cell %u\n", i);
            ++failures;
        }
    }
}

static void test_start_position(void)
{
    spectrum_board_reset();
    expect_true("e2e4 legal", spectrum_board_is_legal_move("e2e4"));
    expect_true("g1f3 legal", spectrum_board_is_legal_move("g1f3"));
    expect_false("e2e5 illegal", spectrum_board_is_legal_move("e2e5"));
    expect_false("black first illegal", spectrum_board_is_legal_move("e7e5"));
    expect_false("rook blocked", spectrum_board_is_legal_move("a1a3"));
}

static void test_turn_and_check(void)
{
    spectrum_board_reset();
    expect_true("play f2f3", spectrum_board_apply_move("f2f3"));
    expect_true("play e7e5", spectrum_board_apply_move("e7e5"));
    expect_true("play g2g4", spectrum_board_apply_move("g2g4"));
    expect_true("black queen check", spectrum_board_apply_move("d8h4"));
    expect_false("ignore check illegal", spectrum_board_is_legal_move("a2a3"));
}

static void test_castling(void)
{
    spectrum_board_reset();
    expect_true("play e2e4", spectrum_board_apply_move("e2e4"));
    expect_true("play e7e5", spectrum_board_apply_move("e7e5"));
    expect_true("play g1f3", spectrum_board_apply_move("g1f3"));
    expect_true("play b8c6", spectrum_board_apply_move("b8c6"));
    expect_true("play f1c4", spectrum_board_apply_move("f1c4"));
    expect_true("play g8f6", spectrum_board_apply_move("g8f6"));
    expect_true("white castles", spectrum_board_is_legal_move("e1g1"));
    expect_true("apply castle", spectrum_board_apply_move("e1g1"));
    expect_cell("king on g1", 7u, 6u, 'K');
    expect_cell("rook on f1", 7u, 5u, 'R');
}

static void test_trusted_castle_shape_guard(void)
{
    spectrum_board_reset();
    expect_true("guard g2g3", spectrum_board_apply_move("g2g3"));
    expect_true("guard a7a6", spectrum_board_apply_move("a7a6"));
    expect_true("guard e2e4", spectrum_board_apply_move("e2e4"));
    expect_true("guard a6a5", spectrum_board_apply_move("a6a5"));
    expect_true("guard e1e2", spectrum_board_apply_move("e1e2"));
    expect_true("guard a5a4", spectrum_board_apply_move("a5a4"));
    expect_true("trusted non-home king move", spectrum_board_apply_trusted_move("e2g2"));
    expect_cell("trusted h2 unchanged", 6u, 7u, 'P');
    expect_cell("trusted f2 unchanged", 6u, 5u, 'P');
}

static void test_en_passant(void)
{
    spectrum_board_reset();
    expect_true("play e2e4", spectrum_board_apply_move("e2e4"));
    expect_true("play a7a6", spectrum_board_apply_move("a7a6"));
    expect_true("play e4e5", spectrum_board_apply_move("e4e5"));
    expect_true("play d7d5", spectrum_board_apply_move("d7d5"));
    expect_true("ep legal", spectrum_board_is_legal_move("e5d6"));
    expect_true("apply ep", spectrum_board_apply_move("e5d6"));
    expect_cell("ep pawn on d6", 2u, 3u, 'P');
    expect_cell("ep captured d5", 3u, 3u, '.');

    spectrum_board_reset();
    expect_true("play e2e4 b", spectrum_board_apply_move("e2e4"));
    expect_true("play a7a6 b", spectrum_board_apply_move("a7a6"));
    expect_true("play e4e5 b", spectrum_board_apply_move("e4e5"));
    expect_true("play d7d5 b", spectrum_board_apply_move("d7d5"));
    expect_true("play h2h3 b", spectrum_board_apply_move("h2h3"));
    expect_true("play a6a5 b", spectrum_board_apply_move("a6a5"));
    expect_false("delayed ep illegal", spectrum_board_is_legal_move("e5d6"));
}

static void test_normal_pawn_capture_after_double_push(void)
{
    spectrum_board_reset();
    expect_true("capture setup e2e4", spectrum_board_apply_move("e2e4"));
    expect_true("capture setup e7e5", spectrum_board_apply_move("e7e5"));
    expect_true("capture setup g1f3", spectrum_board_apply_move("g1f3"));
    expect_true("capture setup d7d5", spectrum_board_apply_move("d7d5"));
    expect_true("normal pawn capture e4d5 legal",
                spectrum_board_is_legal_move("e4d5"));
    expect_true("normal pawn capture e4d5 apply",
                spectrum_board_apply_move("e4d5"));
    expect_cell("normal pawn capture pawn on d5", 3u, 3u, 'P');
    expect_cell("normal pawn capture e4 empty", 4u, 4u, '.');
}

static void test_promotion(void)
{
    spectrum_board_snapshot_t snapshot;

    spectrum_board_reset();
    expect_true("a2a4", spectrum_board_apply_move("a2a4"));
    expect_true("h7h5", spectrum_board_apply_move("h7h5"));
    expect_true("a4a5", spectrum_board_apply_move("a4a5"));
    expect_true("h5h4", spectrum_board_apply_move("h5h4"));
    expect_true("a5a6", spectrum_board_apply_move("a5a6"));
    expect_true("h4h3", spectrum_board_apply_move("h4h3"));
    expect_true("a6b7", spectrum_board_apply_move("a6b7"));
    expect_true("h3g2", spectrum_board_apply_move("h3g2"));
    spectrum_board_snapshot_save(&snapshot);
    expect_true("promote queen legal", spectrum_board_is_legal_move("b7c8q"));
    expect_true("promote rook legal", spectrum_board_is_legal_move("b7c8r"));
    expect_true("promote bishop legal", spectrum_board_is_legal_move("b7c8b"));
    expect_true("promote knight legal", spectrum_board_is_legal_move("b7c8n"));
    expect_false("promote missing illegal", spectrum_board_is_legal_move("b7c8"));
    spectrum_board_snapshot_restore(&snapshot);
    expect_true("promote knight apply", spectrum_board_apply_move("b7c8n"));
    expect_cell("promote knight on c8", 0u, 2u, 'N');
    expect_cell("promote source empty", 1u, 1u, '.');
}

static void test_snapshot_restore(void)
{
    spectrum_board_snapshot_t snapshot;

    spectrum_board_reset();
    expect_true("snapshot e2e4", spectrum_board_apply_move("e2e4"));
    spectrum_board_snapshot_save(&snapshot);
    expect_true("snapshot a7a6", spectrum_board_apply_move("a7a6"));
    spectrum_board_snapshot_restore(&snapshot);
    expect_cell("snapshot e4 pawn", 4u, 4u, 'P');
    expect_cell("snapshot a7 restored", 1u, 0u, 'p');
    expect_true("snapshot black turn", spectrum_board_is_legal_move("e7e5"));
    expect_false("snapshot white waits", spectrum_board_is_legal_move("g1f3"));

    set_test_board_state(".....k.."
                         "........"
                         "........"
                         "........"
                         "........"
                         "........"
                         "........"
                         "....K..R",
                         TEST_WHITE,
                         TEST_CASTLE_WK,
                         TEST_NO_EP);
    spectrum_board_snapshot_save(&snapshot);
    spectrum_board_clear();
    spectrum_board_snapshot_restore(&snapshot);
    expect_true("snapshot castle rights", spectrum_board_is_legal_move("e1g1"));

    set_test_board(".......k"
                   "........"
                   "........"
                   "...pP..."
                   "........"
                   "........"
                   "........"
                   "K.......",
                   TEST_WHITE,
                   TEST_SQ(2, 3));
    spectrum_board_snapshot_save(&snapshot);
    spectrum_board_clear();
    spectrum_board_snapshot_restore(&snapshot);
    expect_true("snapshot ep square", spectrum_board_is_legal_move("e5d6"));
}

static void test_compact_undo(void)
{
    spectrum_board_snapshot_t before;
    spectrum_board_snapshot_t after;
    spectrum_board_undo_t undo = {1u, 2u, 'x', 3u, 4};
    spectrum_board_undo_t undo_before = undo;

    spectrum_board_reset();
    expect_undo_roundtrip("undo quiet double push", "e2e4");

    set_test_board("....k..."
                   "........"
                   "........"
                   "...p...."
                   "....P..."
                   "........"
                   "........"
                   "....K...",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_undo_roundtrip("undo normal capture", "e4d5");

    set_test_board(".......k"
                   ".N......"
                   "........"
                   "........"
                   "........"
                   "........"
                   "........"
                   "K.......",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_undo_roundtrip("undo non-pawn to back rank", "b7c8");

    set_test_board("....k..."
                   "........"
                   "........"
                   "........"
                   "........"
                   "........"
                   "....K..R"
                   "........",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_undo_roundtrip("undo non-home king shape", "e2g2");

    set_test_board(".......k"
                   "........"
                   "........"
                   "...pP..."
                   "........"
                   "........"
                   "........"
                   "K.......",
                   TEST_WHITE,
                   TEST_SQ(2, 3));
    expect_undo_roundtrip("undo en passant", "e5d6");

    set_test_board_state("....k..."
                         "........"
                         "........"
                         "........"
                         "........"
                         "........"
                         "........"
                         "....K..R",
                         TEST_WHITE,
                         TEST_CASTLE_WK,
                         TEST_NO_EP);
    expect_undo_roundtrip("undo white kingside castle", "e1g1");

    set_test_board_state("r...k..."
                         "........"
                         "........"
                         "........"
                         "........"
                         "........"
                         "........"
                         "....K...",
                         TEST_BLACK,
                         TEST_CASTLE_BQ,
                         TEST_NO_EP);
    expect_undo_roundtrip("undo black queenside castle", "e8c8");

    set_test_board_state("..r....k"
                         ".P......"
                         "........"
                         "........"
                         "........"
                         "........"
                         "........"
                         "K.......",
                         TEST_WHITE,
                         (uint8_t)(TEST_CASTLE_WK | TEST_CASTLE_BK),
                         TEST_NO_EP);
    expect_undo_roundtrip("undo promote capture queen", "b7c8q");
    expect_undo_roundtrip("undo promote capture rook", "b7c8r");
    expect_undo_roundtrip("undo promote capture bishop", "b7c8b");
    expect_undo_roundtrip("undo promote capture knight", "b7c8n");
    spectrum_board_snapshot_save(&before);
    expect_false("undo missing promotion rejected",
                 spectrum_board_apply_trusted_move_with_undo("b7c8", &undo));
    spectrum_board_snapshot_save(&after);
    if (memcmp(&before, &after, sizeof(before)) != 0 ||
        memcmp(&undo, &undo_before, sizeof(undo)) != 0) {
        printf("FAIL undo rejected promotion mutated state\n");
        ++failures;
    }

    set_test_board(".......k"
                   "........"
                   "........"
                   "........"
                   "........"
                   "........"
                   "......p."
                   "K......R",
                   TEST_BLACK,
                   TEST_NO_EP);
    expect_undo_roundtrip("undo black promote capture", "g2h1q");
}

static void test_san_basic(void)
{
    spectrum_board_reset();
    expect_san_base("san e4", "e2e4", "e4");
    expect_san_base("san Nf3", "g1f3", "Nf3");

    expect_true("san castle e2e4", spectrum_board_apply_move("e2e4"));
    expect_true("san castle e7e5", spectrum_board_apply_move("e7e5"));
    expect_true("san castle g1f3", spectrum_board_apply_move("g1f3"));
    expect_true("san castle b8c6", spectrum_board_apply_move("b8c6"));
    expect_true("san castle f1c4", spectrum_board_apply_move("f1c4"));
    expect_true("san castle g8f6", spectrum_board_apply_move("g8f6"));
    expect_san_base("san O-O", "e1g1", "O-O");
}

static void test_san_disambiguation(void)
{
    set_test_board(".......k"
                   "........"
                   "........"
                   "........"
                   "........"
                   ".....N.."
                   "........"
                   "KN......",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_san_base("san Nbd2", "b1d2", "Nbd2");

    set_test_board(".......k"
                   "........"
                   "........"
                   "........"
                   "........"
                   ".....N.."
                   "...p...."
                   "KN......",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_san_base("san Nbxd2", "b1d2", "Nbxd2");

    set_test_board(".......k"
                   "........"
                   "........"
                   "........"
                   "........"
                   "R......."
                   "........"
                   "R......K",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_san_base("san R1a2", "a1a2", "R1a2");

    set_test_board(".......k"
                   "........"
                   "........"
                   "........"
                   ".Q.....Q"
                   "........"
                   "........"
                   "K......Q",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_san_base("san Qh4e1", "h4e1", "Qh4e1");

    set_test_board("....r..k"
                   "........"
                   "........"
                   "........"
                   "........"
                   "........"
                   "R...R..."
                   "....K...",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_san_base("san pinned rook no disambig", "a2d2", "Rd2");
}

static void test_san_pawns_and_suffix(void)
{
    set_test_board(".......k"
                   "........"
                   "........"
                   "...p...."
                   "....P..."
                   "........"
                   "........"
                   "K.......",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_san_base("san exd5", "e4d5", "exd5");

    set_test_board(".......k"
                   "........"
                   "........"
                   "...pP..."
                   "........"
                   "........"
                   "........"
                   "K.......",
                   TEST_WHITE,
                   TEST_SQ(2, 3));
    expect_san_base("san ep exd6", "e5d6", "exd6");

    set_test_board(".......k"
                   "....P..."
                   "........"
                   "........"
                   "........"
                   "........"
                   "........"
                   "K.......",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_san_base("san e8=Q", "e7e8q", "e8=Q");

    set_test_board("...r...k"
                   "....P..."
                   "........"
                   "........"
                   "........"
                   "........"
                   "........"
                   "K.......",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_san_after_apply("san exd8=Q+", "e7d8q", "exd8=Q+");
}

static void test_san_check_and_mate(void)
{
    set_test_board("....k..."
                   "........"
                   "........"
                   "........"
                   "........"
                   "........"
                   "........"
                   "K...R...",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_san_after_apply("san Re7+", "e1e7", "Re7+");

    set_test_board_state(".....k.."
                         "........"
                         "........"
                         "........"
                         "........"
                         "........"
                         "........"
                         "....K..R",
                         TEST_WHITE,
                         TEST_CASTLE_WK,
                         TEST_NO_EP);
    expect_san_after_apply("san O-O+", "e1g1", "O-O+");

    spectrum_board_reset();
    expect_true("mate f2f3", spectrum_board_apply_move("f2f3"));
    expect_true("mate e7e5", spectrum_board_apply_move("e7e5"));
    expect_true("mate g2g4", spectrum_board_apply_move("g2g4"));
    expect_san_after_apply("san Qh4#", "d8h4", "Qh4#");

    set_test_board("....k..."
                   ".....p.."
                   "....P..."
                   "........"
                   "........"
                   "........"
                   "........"
                   "K.......",
                   TEST_WHITE,
                   TEST_NO_EP);
    expect_san_after_apply("san pawn check exf7+", "e6f7", "exf7+");
    /* Right-diagonal pawn check (king e8 attacked by pawn f7 = king+9).
       Guards the rules engine directly; NOTE host build exercises
       rules_compact.c, not the RULES ASM overlay where this regressed. */
    expect_true("check_state CHECK after exf7+",
                (uint8_t)(spectrum_board_check_state() == SPECTRUM_BOARD_CHECK));
}

static void test_stalemate_state(void)
{
    set_test_board(".......k"
                   ".....Q.."
                   "......K."
                   "........"
                   "........"
                   "........"
                   "........"
                   "........",
                   TEST_BLACK,
                   TEST_NO_EP);
    expect_true("check_state STALEMATE",
                (uint8_t)(spectrum_board_check_state() == SPECTRUM_BOARD_STALEMATE));
}

static void test_against_common_rules_opening(void)
{
    spectrum_board_reset();
    (void)netchesszx_rules_reset();
    compare_with_common_rules("common start e2e5", "e2e5");
    compare_with_common_rules("common start e2e4", "e2e4");
    compare_with_common_rules("common black e7e5", "e7e5");
    compare_with_common_rules("common white g1f3", "g1f3");
    compare_with_common_rules("common black b8c6", "b8c6");
    compare_with_common_rules("common white f1c4", "f1c4");
    compare_with_common_rules("common black g8f6", "g8f6");
    compare_with_common_rules("common white castle", "e1g1");
}

static void test_against_common_rules_check(void)
{
    spectrum_board_reset();
    (void)netchesszx_rules_reset();
    compare_with_common_rules("common f2f3", "f2f3");
    compare_with_common_rules("common e7e5", "e7e5");
    compare_with_common_rules("common g2g4", "g2g4");
    compare_with_common_rules("common d8h4", "d8h4");
    compare_with_common_rules("common ignore check", "a2a3");
}

static void test_against_common_rules_en_passant(void)
{
    spectrum_board_reset();
    (void)netchesszx_rules_reset();
    compare_with_common_rules("common ep e2e4", "e2e4");
    compare_with_common_rules("common ep a7a6", "a7a6");
    compare_with_common_rules("common ep e4e5", "e4e5");
    compare_with_common_rules("common ep d7d5", "d7d5");
    compare_with_common_rules("common ep e5d6", "e5d6");
}

static void test_against_common_rules_promotion(void)
{
    spectrum_board_reset();
    (void)netchesszx_rules_reset();
    compare_with_common_rules("common promo a2a4", "a2a4");
    compare_with_common_rules("common promo h7h5", "h7h5");
    compare_with_common_rules("common promo a4a5", "a4a5");
    compare_with_common_rules("common promo h5h4", "h5h4");
    compare_with_common_rules("common promo a5a6", "a5a6");
    compare_with_common_rules("common promo h4h3", "h4h3");
    compare_with_common_rules("common promo a6b7", "a6b7");
    compare_with_common_rules("common promo h3g2", "h3g2");
    compare_with_common_rules("common promo b7c8q", "b7c8q");
}

int main(void)
{
    test_reset_and_clear_representation();
    test_start_position();
    test_turn_and_check();
    test_castling();
    test_trusted_castle_shape_guard();
    test_en_passant();
    test_normal_pawn_capture_after_double_push();
    test_promotion();
    test_snapshot_restore();
    test_compact_undo();
    test_san_basic();
    test_san_disambiguation();
    test_san_pawns_and_suffix();
    test_san_check_and_mate();
    test_stalemate_state();
    test_against_common_rules_opening();
    test_against_common_rules_check();
    test_against_common_rules_en_passant();
    test_against_common_rules_promotion();

    if (failures != 0) {
        printf("%d failure(s)\n", failures);
        return 1;
    }
    printf("spectrum board tests ok\n");
    return 0;
}

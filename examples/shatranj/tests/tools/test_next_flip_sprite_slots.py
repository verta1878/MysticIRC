from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
GUI_SOURCE = ROOT / "src/spectrum/ui/gui.c"
EMPTY = "."
SLOT_LIMIT = 32


def flipped_redraw(board, order):
    slots = {index for index, piece in enumerate(board) if piece != EMPTY}
    missing = set()
    for logical in order:
        screen = 63 - logical
        if board[logical] == EMPTY:
            slots.discard(screen)
        elif screen not in slots:
            if len(slots) == SLOT_LIMIT:
                missing.add(logical)
            else:
                slots.add(screen)
    return missing


def main():
    board = list(
        "rnbqkbnr"
        "pppppppp"
        "........"
        "........"
        "........"
        "........"
        "PPPPPPPP"
        "RNBQKBNR"
    )
    board[6 * 8 + 4] = EMPTY
    board[4 * 8 + 4] = "P"

    assert flipped_redraw(board, range(64)) == {1 * 8 + 3}
    empty_first = sorted(range(64), key=lambda index: board[index] != EMPTY)
    assert flipped_redraw(board, empty_first) == set()

    source = GUI_SOURCE.read_text(encoding="utf-8")
    start = source.index("static void spectrum_gui_redraw_board_flip_squares")
    end = source.index("\nvoid spectrum_gui_mark_cursor", start)
    implementation = source[start:end]
    assert "for (pass = 0u; pass < 2u; ++pass)" in implementation
    assert "!= '.') == pass" in implementation
    print("Next flip sprite-slot ordering ok")


if __name__ == "__main__":
    main()

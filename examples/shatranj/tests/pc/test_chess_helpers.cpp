#include "pc/client/chess_helpers.h"

#include <cstdio>

static int failures;

static void check(bool ok, const char *label)
{
    if (!ok) {
        std::printf("FAIL: %s\n", label);
        ++failures;
    }
}

int main()
{
    int fromRow;
    int fromCol;
    int toRow;
    int toCol;

    check(ChessHelpers::squareName(7, 4) == QStringLiteral("e1"),
          "square name");
    check(ChessHelpers::moveCoords(QStringLiteral("e2e4"),
                                   &fromRow, &fromCol, &toRow, &toCol) &&
              fromRow == 6 && fromCol == 4 && toRow == 4 && toCol == 4,
          "move coordinates");
    check(!ChessHelpers::moveCoords(QStringLiteral("e9e4"),
                                    &fromRow, &fromCol, &toRow, &toCol),
          "invalid move coordinates");
    check(ChessHelpers::isMoveSyntaxOk(QStringLiteral("a7a8q")),
          "promotion syntax");
    check(!ChessHelpers::isMoveSyntaxOk(QStringLiteral("a7a8k")),
          "invalid promotion syntax");
    check(ChessHelpers::isMqttRoomSyntaxOk(QStringLiteral("NC12ABCD")),
          "eight-character room syntax");
    check(!ChessHelpers::isMqttRoomSyntaxOk(QStringLiteral("NC12ABCDE")),
          "overlong room syntax");
    check(!ChessHelpers::isMqttRoomSyntaxOk(QStringLiteral("nc12af")),
          "lowercase room syntax");
    check(ChessHelpers::isDirectIpSyntaxOk(QStringLiteral("127.0.0.1")),
          "IPv4 syntax");
    check(!ChessHelpers::isDirectIpSyntaxOk(QStringLiteral("localhost")),
          "hostname is not direct IPv4");

    if (failures != 0) {
        return 1;
    }
    std::printf("chess helper tests ok\n");
    return 0;
}

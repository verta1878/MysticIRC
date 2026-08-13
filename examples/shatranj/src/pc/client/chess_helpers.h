#ifndef CHESS_HELPERS_H
#define CHESS_HELPERS_H

#include <QString>
#include <cstdint>

struct CompactRulesState {
    int8_t board[64];
    uint8_t side;
    uint8_t castle;
    int8_t ep;
};

namespace ChessHelpers {

int8_t compactPieceFromAscii(char piece);

QString squareName(int row, int col);

bool moveCoords(const QString &move, int *fromRow, int *fromCol,
                int *toRow, int *toCol);

char lowerPiece(char piece);
QString sanPieceLetter(char piece);

bool isMoveSyntaxOk(const QString &move);
bool isMqttRoomSyntaxOk(const QString &room);
bool isDirectIpSyntaxOk(const QString &host);

} // namespace ChessHelpers

#endif // CHESS_HELPERS_H

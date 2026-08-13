#include "chess_helpers.h"
#include "common/chess/rules_compact.h"
#include <QHostAddress>
#include <QNetworkInterface>

namespace ChessHelpers {

static bool isMoveFile(QChar ch)
{
    return ch >= QLatin1Char('a') && ch <= QLatin1Char('h');
}

static bool isMoveRank(QChar ch)
{
    return ch >= QLatin1Char('1') && ch <= QLatin1Char('8');
}

static bool isPromotionPiece(QChar ch)
{
    return ch == QLatin1Char('q') || ch == QLatin1Char('r') ||
           ch == QLatin1Char('b') || ch == QLatin1Char('n');
}

static bool moveCoreSyntaxOk(const QString &move)
{
    return (move.size() == 4 || move.size() == 5) &&
           isMoveFile(move.at(0)) && isMoveRank(move.at(1)) &&
           isMoveFile(move.at(2)) && isMoveRank(move.at(3));
}

int8_t compactPieceFromAscii(char piece)
{
    switch (piece) {
    case 'P': return NETCHESSZX_RULE_WP;
    case 'N': return NETCHESSZX_RULE_WN;
    case 'B': return NETCHESSZX_RULE_WB;
    case 'R': return NETCHESSZX_RULE_WR;
    case 'Q': return NETCHESSZX_RULE_WQ;
    case 'K': return NETCHESSZX_RULE_WK;
    case 'p': return NETCHESSZX_RULE_BP;
    case 'n': return NETCHESSZX_RULE_BN;
    case 'b': return NETCHESSZX_RULE_BB;
    case 'r': return NETCHESSZX_RULE_BR;
    case 'q': return NETCHESSZX_RULE_BQ;
    case 'k': return NETCHESSZX_RULE_BK;
    default: return NETCHESSZX_RULE_EMPTY;
    }
}

QString squareName(int row, int col)
{
    const QChar file('a' + col);
    const QChar rank('8' - row);
    return QString(file) + QString(rank);
}

bool moveCoords(const QString &move, int *fromRow, int *fromCol, int *toRow, int *toCol)
{
    if (!moveCoreSyntaxOk(move)) return false;
    *fromCol = move[0].unicode() - 'a';
    *fromRow = '8' - move[1].unicode();
    *toCol = move[2].unicode() - 'a';
    *toRow = '8' - move[3].unicode();
    return true;
}

char lowerPiece(char piece)
{
    return piece >= 'A' && piece <= 'Z'
        ? static_cast<char>(piece + ('a' - 'A')) : piece;
}

QString sanPieceLetter(char piece)
{
    switch (lowerPiece(piece)) {
    case 'n': return QStringLiteral("N");
    case 'b': return QStringLiteral("B");
    case 'r': return QStringLiteral("R");
    case 'q': return QStringLiteral("Q");
    case 'k': return QStringLiteral("K");
    default: return QString();
    }
}

bool isMoveSyntaxOk(const QString &move)
{
    if (!moveCoreSyntaxOk(move)) return false;
    if (move.size() == 4) return true;
    return isPromotionPiece(move.at(4));
}

bool isMqttRoomSyntaxOk(const QString &room)
{
    if (room.isEmpty() || room.size() > 8) return false;
    for (const QChar ch : room) {
        const ushort c = ch.unicode();
        if ((c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9')) continue;
        return false;
    }
    return true;
}

bool isDirectIpSyntaxOk(const QString &host)
{
    QHostAddress address;
    return address.setAddress(host) && address.protocol() == QAbstractSocket::IPv4Protocol && !address.isNull();
}

} // namespace ChessHelpers

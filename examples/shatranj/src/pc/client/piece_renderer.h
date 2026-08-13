#ifndef PIECE_RENDERER_H
#define PIECE_RENDERER_H

#include <QIcon>
#include <QImage>
#include <QStringList>
#include <QPainter>
#include <QString>

namespace PieceRenderer {

QString assetPath(const QString &relativePath);

void setPieceSet(const QString &name);
QString pieceSet();
QStringList pieceSets();

void setBoardTexture(const QString &name);
QString boardTexture();
QStringList boardTextures();
QString boardSquareStyle(int row, int col, int squareSize,
                         const QString &background, const QString &foreground,
                         const QString &border);
QIcon boardSquareIcon(char piece, int row, int col, int squareSize,
                      int pieceIconSize, bool pieceVisible, bool legalHint,
                      bool targetHighlight);

QString pieceAssetName(char piece);
QString pieceAssetPath(char piece);
QString pieceSvgPath(char piece);
QIcon pieceIcon(char piece);
void prewarmPieceIcons();
void clearIconCache();

QIcon makeShatranjIcon();

QImage boardTextureImage(int squareSize);

// Procedural rendering fallback
QPainterPath roundedRectPath(double x, double y, double w, double h, double r);
void drawBase(QPainter &p, const QBrush &fill, const QPen &stroke);
void drawPawn(QPainter &p, const QBrush &fill, const QPen &stroke);
void drawRook(QPainter &p, const QBrush &fill, const QPen &stroke);
void drawKnight(QPainter &p, const QBrush &fill, const QPen &stroke);
void drawBishop(QPainter &p, const QBrush &fill, const QPen &stroke, const QPen &detail);
void drawQueen(QPainter &p, const QBrush &fill, const QPen &stroke);
void drawKing(QPainter &p, const QBrush &fill, const QPen &stroke);

} // namespace PieceRenderer

#endif // PIECE_RENDERER_H

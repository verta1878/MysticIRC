#ifndef SAVE_GAME_STORE_H
#define SAVE_GAME_STORE_H

#include <QDateTime>
#include <QString>
#include <QVector>

extern "C" {
#include "common/savegame/savegame_wire.h"
}

struct SaveSlotEntry {
    QString baseName;
    QDateTime when;
    bool used = false;
    bool duplicate = false;
};

namespace SaveGameStore {

constexpr int kSlotCount = 10;

QString defaultDirectory();
QString ensureExtension(QString path);
QString normalizedName(const QString &name);
QString pathForName(const QString &directory, const QString &name);
QString slotBaseName(int slot, const QDateTime &when);
QString slotFilePath(const QString &directory, const QString &baseName);
QVector<SaveSlotEntry> scanSlots(const QString &directory);

bool write(const QString &path, const netchesszx_save_state_t &state);
bool read(const QString &path, netchesszx_save_state_t *state);
bool remove(const QString &path);

} // namespace SaveGameStore

#endif // SAVE_GAME_STORE_H

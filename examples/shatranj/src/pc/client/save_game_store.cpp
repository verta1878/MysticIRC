#include "save_game_store.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSaveFile>
#include <QStandardPaths>

namespace {

constexpr const char *kSaveExtension = ".stj";

QChar slotB32(int value)
{
    return QChar(value < 10 ? '0' + value : 'A' + value - 10);
}

int slotB32Value(QChar c)
{
    if (c >= QLatin1Char('0') && c <= QLatin1Char('9')) {
        return c.unicode() - '0';
    }
    if (c >= QLatin1Char('A') && c <= QLatin1Char('V')) {
        return c.unicode() - 'A' + 10;
    }
    return -1;
}

bool parseSlotBaseName(const QString &base, int *slot, QDateTime *when)
{
    if (base.size() != 8 || !base.at(0).isDigit() || !base.at(1).isDigit() ||
        !base.at(6).isDigit() || !base.at(7).isDigit()) {
        return false;
    }
    const int slotValue = base.mid(0, 2).toInt();
    const int year = slotB32Value(base.at(2));
    const int month = slotB32Value(base.at(3));
    const int day = slotB32Value(base.at(4));
    const int hour = slotB32Value(base.at(5));
    const int minute = base.mid(6, 2).toInt();

    if (slotValue < 1 || slotValue > SaveGameStore::kSlotCount ||
        year < 0 || month < 1 || month > 12 || day < 1 || day > 31 ||
        hour < 0 || hour > 23 || minute > 59) {
        return false;
    }
    *slot = slotValue;
    *when = QDateTime(QDate(2020 + year, month, day), QTime(hour, minute));
    return when->isValid();
}

} // namespace

namespace SaveGameStore {

QString defaultDirectory()
{
    const QString docs =
        QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    QDir dir(docs.isEmpty() ? QDir::homePath() : docs);
    (void)dir.mkpath(QStringLiteral("Shatranj/Saves"));
    return dir.filePath(QStringLiteral("Shatranj/Saves"));
}

QString ensureExtension(QString path)
{
    path = path.trimmed();
    if (path.isEmpty() ||
        path.endsWith(QString::fromLatin1(kSaveExtension), Qt::CaseInsensitive)) {
        return path;
    }
    const QFileInfo info(path);
    if (info.suffix().isEmpty()) {
        return path + QString::fromLatin1(kSaveExtension);
    }
    return info.dir().filePath(info.completeBaseName() +
                               QString::fromLatin1(kSaveExtension));
}

QString normalizedName(const QString &name)
{
    QString safe;
    for (const QChar ch : name.trimmed()) {
        const ushort u = ch.unicode();
        if ((u >= 'a' && u <= 'z') || (u >= 'A' && u <= 'Z') ||
            (u >= '0' && u <= '9') || u == '_' || u == '-' || u == '.') {
            safe += QChar(u);
        } else if (u == ' ') {
            safe += '_';
        }
    }
    while (safe.startsWith('.')) {
        safe.remove(0, 1);
    }
    if (safe.isEmpty()) {
        return QString();
    }
    if (!safe.endsWith(QString::fromLatin1(kSaveExtension),
                       Qt::CaseInsensitive)) {
        safe += QString::fromLatin1(kSaveExtension);
    }
    return safe;
}

QString pathForName(const QString &directory, const QString &name)
{
    const QString safe = normalizedName(name);
    return safe.isEmpty() ? QString() : QDir(directory).filePath(safe);
}

QString slotBaseName(int slot, const QDateTime &when)
{
    const QDate date = when.date();
    const QTime time = when.time();
    QString name;

    name += QChar('0' + slot / 10);
    name += QChar('0' + slot % 10);
    name += slotB32(date.year() - 2020);
    name += slotB32(date.month());
    name += slotB32(date.day());
    name += slotB32(time.hour());
    name += QStringLiteral("%1").arg(time.minute(), 2, 10, QLatin1Char('0'));
    return name;
}

QString slotFilePath(const QString &directory, const QString &baseName)
{
    return QDir(directory).filePath(baseName + QString::fromLatin1(kSaveExtension));
}

QVector<SaveSlotEntry> scanSlots(const QString &directory)
{
    QVector<SaveSlotEntry> entries(kSlotCount);
    const QStringList files = QDir(directory).entryList(
        QStringList() << QStringLiteral("*.stj"), QDir::Files);

    for (const QString &file : files) {
        const QString base = QFileInfo(file).completeBaseName().toUpper();
        int slot = 0;
        QDateTime when;

        if (!parseSlotBaseName(base, &slot, &when)) {
            continue;
        }
        SaveSlotEntry &entry = entries[slot - 1];
        if (entry.used) {
            entry.duplicate = true;
            continue;
        }
        entry.baseName = base;
        entry.when = when;
        entry.used = true;
    }
    return entries;
}

bool write(const QString &path, const netchesszx_save_state_t &state)
{
    const QString fullPath = ensureExtension(path);
    uint8_t wire[NETCHESSZX_SAVE_WIRE_SIZE];
    char b64[NETCHESSZX_SAVE_WIRE_B64_SIZE];

    if (fullPath.isEmpty() ||
        netchesszx_save_wire_pack(wire, sizeof(wire), &state) != NETCHESSZX_SAVE_OK ||
        netchesszx_save_wire_b64_encode(b64, sizeof(b64), wire, sizeof(wire)) !=
            NETCHESSZX_SAVE_OK) {
        return false;
    }
    const QFileInfo info(fullPath);
    QDir directory = info.dir();
    if (!directory.exists() && !directory.mkpath(QStringLiteral("."))) {
        return false;
    }
    QSaveFile file(fullPath);
    return file.open(QIODevice::WriteOnly) &&
           file.write(b64, sizeof(b64)) == static_cast<qint64>(sizeof(b64)) &&
           file.commit();
}

bool read(const QString &path, netchesszx_save_state_t *state)
{
    const QString fullPath = ensureExtension(path);
    if (fullPath.isEmpty() || state == nullptr) {
        return false;
    }
    QFile file(fullPath);
    if (!file.open(QIODevice::ReadOnly)) {
        return false;
    }
    if (file.size() != static_cast<qint64>(NETCHESSZX_SAVE_WIRE_B64_SIZE)) {
        return false;
    }
    const QByteArray data = file.readAll();
    uint8_t wire[NETCHESSZX_SAVE_WIRE_SIZE];

    if (data.size() != NETCHESSZX_SAVE_WIRE_B64_SIZE ||
        netchesszx_save_wire_b64_decode(wire, sizeof(wire), data.constData(),
                                        static_cast<size_t>(data.size())) !=
            NETCHESSZX_SAVE_OK) {
        return false;
    }
    return netchesszx_save_wire_unpack(state, wire, sizeof(wire)) ==
           NETCHESSZX_SAVE_OK;
}

bool remove(const QString &path)
{
    return QFile::remove(path);
}

} // namespace SaveGameStore

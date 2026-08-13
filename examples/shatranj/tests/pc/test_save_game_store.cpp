#include "pc/client/save_game_store.h"

#include <QFile>
#include <QTemporaryDir>

#include <cstdio>
#include <cstring>

static int failures;

static void check(bool ok, const char *label)
{
    if (!ok) {
        std::printf("FAIL: %s\n", label);
        ++failures;
    }
}

static uint8_t crc8(const uint8_t *data, uint8_t length)
{
    uint8_t crc = 0u;

    for (uint8_t i = 0u; i < length; ++i) {
        crc ^= data[i];
        for (uint8_t bit = 0u; bit < 8u; ++bit) {
            crc = (crc & 0x80u) != 0u
                      ? static_cast<uint8_t>((crc << 1) ^ 0x07u)
                      : static_cast<uint8_t>(crc << 1);
        }
    }
    return crc;
}

static netchesszx_save_state_t sampleState()
{
    static const char board[] =
        "rnbqkbnr"
        "pppp.ppp"
        "........"
        "....p..."
        "....P..."
        "........"
        "PPPP.PPP"
        "RNBQKBNR";
    netchesszx_save_state_t state;

    std::memset(&state, 0, sizeof(state));
    std::memcpy(state.cells, board, 64u);
    state.ply = 3u;
    state.side = 1u;
    state.castle = 0x0fu;
    state.ep = NETCHESSZX_SAVE_EP_NONE;
    state.host_color = NETCHESSZX_SAVE_HOST_BLACK;
    state.flags = NETCHESSZX_SAVE_FLAG_ACTIVE;
    return state;
}

int main()
{
    QTemporaryDir temporary;
    check(temporary.isValid(), "temporary directory");

    check(SaveGameStore::normalizedName(QStringLiteral("../ game one")) ==
              QStringLiteral("_game_one.stj"),
          "safe normalized name");
    check(SaveGameStore::ensureExtension(QStringLiteral("game.old"))
              .endsWith(QStringLiteral("game.stj")),
          "replace extension");

    const QDateTime when(QDate(2026, 7, 22), QTime(9, 5));
    const QString base = SaveGameStore::slotBaseName(1, when);
    check(base == QStringLiteral("0167M905"), "slot base name");

    const QString path = SaveGameStore::slotFilePath(temporary.path(), base);
    const netchesszx_save_state_t expected = sampleState();
    netchesszx_save_state_t actual;
    check(SaveGameStore::write(path, expected), "write save");
    check(SaveGameStore::read(path, &actual), "read save");
    check(std::memcmp(&actual, &expected, sizeof(actual)) == 0,
          "save round trip");
    check(!SaveGameStore::read(temporary.filePath(QStringLiteral("missing.stj")),
                               &actual),
          "reject missing save");
    check(!SaveGameStore::read(path, nullptr), "reject null output");

    QVector<SaveSlotEntry> entries = SaveGameStore::scanSlots(temporary.path());
    check(entries.size() == SaveGameStore::kSlotCount && entries[0].used &&
              entries[0].baseName == base,
          "scan slot");

    QFile corrupt(temporary.filePath(QStringLiteral("corrupt.stj")));
    check(corrupt.open(QIODevice::WriteOnly) && corrupt.write("bad") == 3,
          "write corrupt save");
    corrupt.close();
    check(!SaveGameStore::read(corrupt.fileName(), &actual),
          "reject corrupt save");

    QFile oversized(temporary.filePath(QStringLiteral("oversized.stj")));
    const QByteArray oversizedData(
        static_cast<int>(NETCHESSZX_SAVE_WIRE_B64_SIZE) + 1, 'x');
    check(oversized.open(QIODevice::WriteOnly) &&
              oversized.write(oversizedData) == oversizedData.size(),
          "write oversized save");
    oversized.close();
    check(!SaveGameStore::read(oversized.fileName(), &actual),
          "reject oversized save");

    QFile invalidBase64(
        temporary.filePath(QStringLiteral("invalid-base64.stj")));
    const QByteArray invalidBase64Data(
        static_cast<int>(NETCHESSZX_SAVE_WIRE_B64_SIZE), '!');
    check(invalidBase64.open(QIODevice::WriteOnly) &&
              invalidBase64.write(invalidBase64Data) == invalidBase64Data.size(),
          "write invalid base64 save");
    invalidBase64.close();
    check(!SaveGameStore::read(invalidBase64.fileName(), &actual),
          "reject invalid base64 save");

    uint8_t invalidWire[NETCHESSZX_SAVE_WIRE_SIZE] = {};
    char invalidPayload[NETCHESSZX_SAVE_WIRE_B64_SIZE] = {};
    check(netchesszx_save_wire_pack(invalidWire, sizeof(invalidWire), &expected) ==
              NETCHESSZX_SAVE_OK,
          "pack invalid semantic seed");
    invalidWire[37] = 100u;
    invalidWire[44] = crc8(invalidWire, 44u);
    check(netchesszx_save_wire_b64_encode(invalidPayload, sizeof(invalidPayload),
                                         invalidWire, sizeof(invalidWire)) ==
              NETCHESSZX_SAVE_OK,
          "encode semantically invalid save");
    QFile invalidSemantic(
        temporary.filePath(QStringLiteral("invalid-semantic.stj")));
    check(invalidSemantic.open(QIODevice::WriteOnly) &&
              invalidSemantic.write(invalidPayload, sizeof(invalidPayload)) ==
                  static_cast<qint64>(sizeof(invalidPayload)),
          "write semantically invalid save");
    invalidSemantic.close();
    check(!SaveGameStore::read(invalidSemantic.fileName(), &actual),
          "reject semantically invalid save");

    check(SaveGameStore::remove(path) && !QFile::exists(path), "remove save");

    if (failures != 0) {
        return 1;
    }
    std::printf("save game store tests ok\n");
    return 0;
}

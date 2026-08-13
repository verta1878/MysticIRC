#ifndef NETCHESSZX_PC_DESKTOP_TRANSPORT_CODEC_H
#define NETCHESSZX_PC_DESKTOP_TRANSPORT_CODEC_H

#include <QByteArray>
#include <QHash>
#include <QVector>

#include <cstdint>
#include <functional>

class DesktopTransportCodec final {
public:
    struct DirectFeedResult {
        bool delivered = false;
        bool overflow = false;
    };

    enum class MqttPacketType {
        Other,
        Connack,
        Publish,
        Suback,
        Unsuback
    };

    struct MqttPacket {
        MqttPacketType type = MqttPacketType::Other;
        uint8_t returnCode = 0u;
        uint16_t packetId = 0u;
        bool retained = false;
        QByteArray topic;
        QByteArray payload;
    };

    DirectFeedResult feedDirect(
        uint8_t linkId,
        const QByteArray &data,
        const std::function<void(const QByteArray &)> &deliver);
    void clearDirect(uint8_t linkId);
    void clearMqtt();
    void clear();

    QVector<QByteArray> feedMqtt(const QByteArray &data, bool *malformed);
    static bool decodeMqttPacket(const QByteArray &raw, MqttPacket *packet);

    static QByteArray encodeMqttConnect(const QByteArray &clientId,
                                        uint16_t keepAliveSeconds,
                                        const QByteArray &willTopic = QByteArray(),
                                        const QByteArray &willPayload = QByteArray(),
                                        bool retainWill = false);
    static QByteArray encodeMqttSubscribe(uint16_t packetId,
                                          const QByteArray &topic);
    static QByteArray encodeMqttUnsubscribe(uint16_t packetId,
                                            const QByteArray &topic);
    static QByteArray encodeMqttPublish(uint16_t packetId,
                                        const QByteArray &topic,
                                        const QByteArray &payload,
                                        bool retain);
    static QByteArray encodeMqttPuback(uint16_t packetId);
    static QByteArray encodeMqttPing();

private:
    int availableMqttPacketLength() const;

    QHash<uint8_t, QByteArray> directBuffers_;
    QByteArray mqttBuffer_;
};

#endif

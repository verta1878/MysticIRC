#include "desktop_transport_codec.h"

extern "C" {
#include "common/mqtt/mqtt.h"
#include "common/session/session.h"
}

#include <limits>

namespace {

QByteArray encodedPacket(size_t length, QByteArray packet)
{
    if (length == 0u || length > static_cast<size_t>(packet.size())) {
        return {};
    }
    packet.resize(static_cast<int>(length));
    return packet;
}

} // namespace

DesktopTransportCodec::DirectFeedResult DesktopTransportCodec::feedDirect(
    uint8_t linkId,
    const QByteArray &data,
    const std::function<void(const QByteArray &)> &deliver)
{
    DirectFeedResult result;
    QByteArray &buffer = directBuffers_[linkId];
    buffer.append(data);
    constexpr qsizetype kMaxLineBytes =
        static_cast<qsizetype>(SESSION_PAYLOAD_MAX);

    while (true) {
        const qsizetype eol = buffer.indexOf('\n');
        if (eol < 0) {
            break;
        }
        const bool hasCr = eol > 0 && buffer.at(eol - 1) == '\r';
        const qsizetype payloadLength = eol - (hasCr ? 1 : 0);
        if (payloadLength > kMaxLineBytes) {
            buffer.clear();
            result.overflow = true;
            return result;
        }

        QByteArray line = buffer.left(eol);
        buffer.remove(0, eol + 1);
        if (hasCr) {
            line.chop(1);
        }
        if (!line.isEmpty()) {
            deliver(line);
            result.delivered = true;
        }
    }

    const bool pendingCr = buffer.size() == kMaxLineBytes + 1 &&
                           buffer.endsWith('\r');
    if (buffer.size() > kMaxLineBytes && !pendingCr) {
        buffer.clear();
        result.overflow = true;
    }
    return result;
}

void DesktopTransportCodec::clearDirect(uint8_t linkId)
{
    directBuffers_.remove(linkId);
}

void DesktopTransportCodec::clearMqtt()
{
    mqttBuffer_.clear();
}

void DesktopTransportCodec::clear()
{
    directBuffers_.clear();
    clearMqtt();
}

QVector<QByteArray> DesktopTransportCodec::feedMqtt(const QByteArray &data,
                                                     bool *malformed)
{
    QVector<QByteArray> packets;
    if (malformed != nullptr) {
        *malformed = false;
    }
    mqttBuffer_.append(data);
    while (true) {
        const int packetLength = availableMqttPacketLength();
        if (packetLength == 0) {
            return packets;
        }
        if (packetLength < 0) {
            mqttBuffer_.clear();
            if (malformed != nullptr) {
                *malformed = true;
            }
            return packets;
        }
        packets.append(mqttBuffer_.left(packetLength));
        mqttBuffer_.remove(0, packetLength);
    }
}

int DesktopTransportCodec::availableMqttPacketLength() const
{
    if (mqttBuffer_.size() < 2) {
        return 0;
    }
    int multiplier = 1;
    int remaining = 0;
    int used = 0;
    for (int i = 1; i < mqttBuffer_.size() && i < 5; ++i) {
        const auto encoded = static_cast<unsigned char>(mqttBuffer_.at(i));
        remaining += (encoded & 0x7f) * multiplier;
        multiplier *= 128;
        used = i;
        if ((encoded & 0x80) == 0) {
            const int total = used + 1 + remaining;
            if (total > static_cast<int>(NETCHESSZX_MQTT_PACKET_MAX)) {
                return -1;
            }
            return mqttBuffer_.size() >= total ? total : 0;
        }
    }
    return mqttBuffer_.size() >= 5 ? -1 : 0;
}

bool DesktopTransportCodec::decodeMqttPacket(const QByteArray &raw,
                                              MqttPacket *result)
{
    if (result == nullptr) {
        return false;
    }
    netchess_mqtt_packet_t packet = {};
    netchess_mqtt_parser_t parser = {};
    netchess_mqtt_parser_init(&parser);
    int parseResult = NETCHESSZX_MQTT_NEED_MORE;
    for (unsigned char byte : raw) {
        parseResult = netchess_mqtt_parser_feed(&parser, byte, &packet);
        if (parseResult == NETCHESSZX_MQTT_ERROR) {
            return false;
        }
    }
    if (parseResult == NETCHESSZX_MQTT_NEED_MORE) {
        return false;
    }

    *result = MqttPacket{};
    if (packet.type == NETCHESS_MQTT_CONNACK) {
        result->type = MqttPacketType::Connack;
    } else if (packet.type == NETCHESS_MQTT_SUBACK) {
        result->type = MqttPacketType::Suback;
    } else if (packet.type == NETCHESS_MQTT_UNSUBACK) {
        result->type = MqttPacketType::Unsuback;
    } else if (packet.type == NETCHESS_MQTT_PUBLISH) {
        result->type = MqttPacketType::Publish;
    }
    result->returnCode = packet.return_code;
    result->packetId = packet.packet_id;
    result->retained = packet.retain != 0u;
    result->topic = QByteArray(packet.topic);
    result->payload = QByteArray(reinterpret_cast<const char *>(packet.payload),
                                 packet.payload_len);
    return true;
}

QByteArray DesktopTransportCodec::encodeMqttConnect(
    const QByteArray &clientId,
    uint16_t keepAliveSeconds,
    const QByteArray &willTopic,
    const QByteArray &willPayload,
    bool retainWill)
{
    QByteArray packet(static_cast<int>(NETCHESSZX_MQTT_PACKET_MAX), '\0');
    const bool useWill = !willTopic.isEmpty();
    const size_t length = netchess_mqtt_encode_connect(
        reinterpret_cast<uint8_t *>(packet.data()),
        static_cast<size_t>(packet.size()),
        clientId.constData(),
        keepAliveSeconds,
        useWill ? willTopic.constData() : nullptr,
        useWill ? willPayload.constData() : nullptr,
        useWill && retainWill ? 1 : 0);
    return encodedPacket(length, packet);
}

QByteArray DesktopTransportCodec::encodeMqttSubscribe(uint16_t packetId,
                                                       const QByteArray &topic)
{
    QByteArray packet(static_cast<int>(NETCHESSZX_MQTT_PACKET_MAX), '\0');
    const size_t length = netchess_mqtt_encode_subscribe(
        reinterpret_cast<uint8_t *>(packet.data()),
        static_cast<size_t>(packet.size()), packetId, topic.constData(), 1);
    return encodedPacket(length, packet);
}

QByteArray DesktopTransportCodec::encodeMqttUnsubscribe(uint16_t packetId,
                                                         const QByteArray &topic)
{
    QByteArray packet(static_cast<int>(NETCHESSZX_MQTT_PACKET_MAX), '\0');
    const size_t length = netchess_mqtt_encode_unsubscribe(
        reinterpret_cast<uint8_t *>(packet.data()),
        static_cast<size_t>(packet.size()), packetId, topic.constData());
    return encodedPacket(length, packet);
}

QByteArray DesktopTransportCodec::encodeMqttPublish(uint16_t packetId,
                                                     const QByteArray &topic,
                                                     const QByteArray &payload,
                                                     bool retain)
{
    if (payload.size() > std::numeric_limits<uint16_t>::max()) {
        return {};
    }
    QByteArray packet(static_cast<int>(NETCHESSZX_MQTT_PACKET_MAX), '\0');
    const size_t length = netchess_mqtt_encode_publish(
        reinterpret_cast<uint8_t *>(packet.data()),
        static_cast<size_t>(packet.size()), packetId, topic.constData(),
        reinterpret_cast<const uint8_t *>(payload.constData()),
        static_cast<uint16_t>(payload.size()), 1, retain ? 1 : 0);
    return encodedPacket(length, packet);
}

QByteArray DesktopTransportCodec::encodeMqttPuback(uint16_t packetId)
{
    QByteArray packet(4, '\0');
    const size_t length = netchess_mqtt_encode_puback(
        reinterpret_cast<uint8_t *>(packet.data()),
        static_cast<size_t>(packet.size()), packetId);
    return encodedPacket(length, packet);
}

QByteArray DesktopTransportCodec::encodeMqttPing()
{
    QByteArray packet(4, '\0');
    const size_t length = netchess_mqtt_encode_pingreq(
        reinterpret_cast<uint8_t *>(packet.data()),
        static_cast<size_t>(packet.size()));
    return encodedPacket(length, packet);
}

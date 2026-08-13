#include "pc/client/desktop_transport_codec.h"

extern "C" {
#include "common/session/session.h"
}

#include <QByteArray>
#include <QVector>

#include <cstdio>

namespace {

bool check(bool condition, const char *message)
{
    if (!condition) {
        std::fprintf(stderr, "FAIL: %s\n", message);
    }
    return condition;
}

bool testDirectFraming()
{
    DesktopTransportCodec codec;
    QVector<QByteArray> lines;
    auto deliver = [&lines](const QByteArray &line) { lines.append(line); };

    const auto first = codec.feedDirect(7u, QByteArray("HEL"), deliver);
    const auto second = codec.feedDirect(7u, QByteArray("LO\r\n\nWORLD\n"), deliver);
    bool ok = check(!first.delivered && !first.overflow, "fragment must wait") &&
              check(second.delivered && !second.overflow, "complete lines expected") &&
              check(lines == QVector<QByteArray>({"HELLO", "WORLD"}),
                    "CRLF and empty-line handling");

    const QByteArray oversized(SESSION_PAYLOAD_MAX + 1, 'x');
    const auto overflow = codec.feedDirect(8u, oversized, deliver);
    ok = check(overflow.overflow, "oversized direct line rejected") && ok;
    return ok;
}

bool testMqttFramingAndDecode()
{
    DesktopTransportCodec codec;
    const QByteArray encoded = DesktopTransportCodec::encodeMqttPublish(
        42u, QByteArray("netchesszx/v1/ROOM/w2b"), QByteArray("M 1 e2e4"), true);
    if (!check(!encoded.isEmpty(), "publish encoding")) {
        return false;
    }

    bool malformed = false;
    QVector<QByteArray> packets = codec.feedMqtt(encoded.left(2), &malformed);
    bool ok = check(packets.isEmpty() && !malformed, "fragmented MQTT packet waits");
    packets = codec.feedMqtt(encoded.mid(2), &malformed);
    ok = check(packets.size() == 1 && !malformed, "MQTT packet completed") && ok;

    DesktopTransportCodec::MqttPacket packet;
    ok = check(DesktopTransportCodec::decodeMqttPacket(packets.value(0), &packet),
               "publish decoding") && ok;
    ok = check(packet.type == DesktopTransportCodec::MqttPacketType::Publish,
               "publish type") && ok;
    ok = check(packet.packetId == 42u && packet.retained,
               "publish metadata") && ok;
    ok = check(packet.topic == "netchesszx/v1/ROOM/w2b" &&
               packet.payload == "M 1 e2e4", "publish contents") && ok;

    const QByteArray emptyRetained = DesktopTransportCodec::encodeMqttPublish(
        43u, QByteArray("netchesszx/v1/ROOM/meta"), QByteArray(), true);
    ok = check(!emptyRetained.isEmpty() &&
                   DesktopTransportCodec::decodeMqttPacket(emptyRetained, &packet) &&
                   packet.type == DesktopTransportCodec::MqttPacketType::Publish &&
                   packet.retained &&
                   packet.topic == "netchesszx/v1/ROOM/meta" &&
                   packet.payload.isEmpty(),
               "empty retained publish clears metadata") && ok;

    const QByteArray unsuback = QByteArray::fromHex("b002002b");
    ok = check(DesktopTransportCodec::decodeMqttPacket(unsuback, &packet),
               "UNSUBACK decoding") && ok;
    ok = check(packet.type == DesktopTransportCodec::MqttPacketType::Unsuback &&
                   packet.packetId == 43u,
               "UNSUBACK metadata") && ok;

    const QByteArray malformedLength = QByteArray::fromHex("3080808080");
    packets = codec.feedMqtt(malformedLength, &malformed);
    ok = check(packets.isEmpty() && malformed, "malformed remaining length rejected") && ok;
    return ok;
}

bool testMqttControlEncoding()
{
    return check(!DesktopTransportCodec::encodeMqttConnect(
                     QByteArray("client"), 20u).isEmpty(), "CONNECT encoding") &&
           check(!DesktopTransportCodec::encodeMqttSubscribe(
                     3u, QByteArray("topic")).isEmpty(), "SUBSCRIBE encoding") &&
           check(!DesktopTransportCodec::encodeMqttUnsubscribe(
                     4u, QByteArray("topic")).isEmpty(), "UNSUBSCRIBE encoding") &&
           check(!DesktopTransportCodec::encodeMqttPuback(3u).isEmpty(),
                 "PUBACK encoding") &&
           check(!DesktopTransportCodec::encodeMqttPing().isEmpty(),
                 "PINGREQ encoding");
}

} // namespace

int main()
{
    return testDirectFraming() && testMqttFramingAndDecode() &&
                   testMqttControlEncoding()
               ? 0
               : 1;
}

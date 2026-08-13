#include "mqtt_session_adapter.h"

#include <utility>

bool MqttSessionAdapter::init(uint8_t role,
                              uint8_t hostColor,
                              uint16_t sessionId)
{
    SessionConfig config = {};

    config.transport = SESSION_TRANSPORT_MQTT;
    config.role = role;
    config.host_color = hostColor;
    config.session_id = sessionId;
    events_.clear();
    return session_init(&state_, &config) != 0u;
}

void MqttSessionAdapter::enqueue(OwnedEvent event, bool first)
{
    if (first) {
        events_.prepend(std::move(event));
    } else {
        events_.enqueue(std::move(event));
    }
}

void MqttSessionAdapter::enqueueLinkUp(uint8_t linkId)
{
    OwnedEvent owned;

    owned.event.type = SESSION_EV_LINK_UP;
    owned.event.data.link.link_id = linkId;
    enqueue(std::move(owned));
}

void MqttSessionAdapter::enqueueLinkDown(uint8_t linkId)
{
    OwnedEvent owned;

    owned.event.type = SESSION_EV_LINK_DOWN;
    owned.event.data.link.link_id = linkId;
    enqueue(std::move(owned), true);
}

bool MqttSessionAdapter::routeForTopic(const QByteArray &topic, uint8_t *route)
{
    const int slash = topic.lastIndexOf('/');
    const QByteArray suffix = slash < 0 ? topic : topic.mid(slash + 1);

    if (route == nullptr) {
        return false;
    }
    if (suffix == "meta") {
        *route = SESSION_ROUTE_META;
    } else if (suffix == "pres_w" || suffix == "pres_b") {
        *route = SESSION_ROUTE_PRESENCE;
    } else if (suffix == "w2b" || suffix == "b2w") {
        *route = SESSION_ROUTE_GAME;
    } else if (suffix == "ack_w" || suffix == "ack_b") {
        *route = SESSION_ROUTE_ACK;
    } else {
        return false;
    }
    return true;
}

bool MqttSessionAdapter::enqueueRx(uint8_t linkId,
                                   const QByteArray &topic,
                                   bool retained,
                                   const QByteArray &payload)
{
    OwnedEvent owned;
    uint8_t route;

    if (payload.size() > SESSION_PAYLOAD_MAX ||
        !routeForTopic(topic, &route)) {
        return false;
    }
    owned.event.type = SESSION_EV_RX;
    owned.event.data.rx.length = static_cast<uint8_t>(payload.size());
    owned.event.data.rx.route = route;
    owned.event.data.rx.flags = retained ? SESSION_RX_RETAINED : SESSION_RX_LIVE;
    owned.event.data.rx.link_id = linkId;
    owned.payload = payload;
    enqueue(std::move(owned));
    return true;
}

QByteArray MqttSessionAdapter::topicSuffixForRoute(uint8_t route) const
{
    const bool white = state_.local_color == SESSION_COLOR_WHITE;

    if (route == SESSION_ROUTE_META) {
        return "meta";
    }

    if (state_.local_color == SESSION_COLOR_UNKNOWN) {
        return {};
    }
    switch (route) {
    case SESSION_ROUTE_CONTROL:
        return white ? "w2b" : "b2w";
    case SESSION_ROUTE_PRESENCE:
        return white ? "pres_w" : "pres_b";
    case SESSION_ROUTE_PRESENCE_PEER:
        return white ? "pres_b" : "pres_w";
    case SESSION_ROUTE_GAME:
        return white ? "w2b" : "b2w";
    case SESSION_ROUTE_ACK:
        return white ? "ack_b" : "ack_w";
    default:
        return {};
    }
}

void MqttSessionAdapter::enqueueLocalRequest(uint8_t request,
                                             uint16_t value,
                                             const QByteArray &payload,
                                             uint8_t phase)
{
    OwnedEvent owned;

    if (payload.size() > SESSION_PAYLOAD_MAX) {
        return;
    }
    owned.event.type = SESSION_EV_LOCAL_REQUEST;
    owned.event.data.local.value = value;
    owned.event.data.local.length = static_cast<uint8_t>(payload.size());
    owned.event.data.local.request = request;
    owned.event.data.local.phase = phase;
    owned.payload = payload;
    enqueue(std::move(owned));
}

void MqttSessionAdapter::enqueueUserDecision(uint8_t requestId,
                                             uint8_t decision)
{
    OwnedEvent owned;

    owned.event.type = SESSION_EV_USER_DECISION;
    owned.event.data.user.request_id = requestId;
    owned.event.data.user.decision = decision;
    enqueue(std::move(owned));
}

void MqttSessionAdapter::enqueueTxResult(uint8_t txId, uint8_t result)
{
    OwnedEvent owned;

    owned.event.type = SESSION_EV_TX_RESULT;
    owned.event.data.tx.tx_id = txId;
    owned.event.data.tx.result = result;
    enqueue(std::move(owned), true);
}

void MqttSessionAdapter::enqueueTimeout(uint8_t timerId)
{
    OwnedEvent owned;

    owned.event.type = SESSION_EV_TIMEOUT;
    owned.event.data.timeout.timer_id = timerId;
    enqueue(std::move(owned));
}

void MqttSessionAdapter::enqueueGameResult(uint8_t deliveryId,
                                           uint16_t value,
                                           uint8_t result,
                                           const QByteArray &detail)
{
    OwnedEvent owned;

    if (detail.size() > SESSION_PAYLOAD_MAX) {
        return;
    }
    owned.event.type = SESSION_EV_GAME_RESULT;
    owned.event.data.game.value = value;
    owned.event.data.game.detail_length =
        static_cast<uint8_t>(detail.size());
    owned.event.data.game.delivery_id = deliveryId;
    owned.event.data.game.result = result;
    owned.detail = detail;
    enqueue(std::move(owned), true);
}

bool MqttSessionAdapter::takeNextBatch(MqttActionBatch *batch)
{
    OwnedEvent owned;
    uint8_t count;

    if (batch == nullptr || events_.isEmpty()) {
        return false;
    }
    owned = events_.dequeue();
    if (owned.event.type == SESSION_EV_RX) {
        owned.event.data.rx.payload =
            reinterpret_cast<const uint8_t *>(owned.payload.constData());
    } else if (owned.event.type == SESSION_EV_LOCAL_REQUEST) {
        owned.event.data.local.payload =
            reinterpret_cast<const uint8_t *>(owned.payload.constData());
    } else if (owned.event.type == SESSION_EV_GAME_RESULT) {
        owned.event.data.game.detail =
            reinterpret_cast<const uint8_t *>(owned.detail.constData());
    }

    count = session_step(&state_, &owned.event, &workspace_, txScratch_,
                         sizeof(txScratch_), actions_,
                         SESSION_ACTION_CAPACITY);
    batch->count = count;
    for (uint8_t i = 0u; i < count; ++i) {
        MqttOwnedAction &out = batch->actions[i];

        out.payload.clear();
        out.action = actions_[i];
        if (out.action.type == SESSION_ACT_SEND) {
            out.payload = QByteArray(
                reinterpret_cast<const char *>(out.action.data.send.payload),
                out.action.data.send.length);
            out.action.data.send.payload =
                reinterpret_cast<const uint8_t *>(out.payload.constData());
        } else if (out.action.type == SESSION_ACT_DELIVER_GAME &&
                   out.action.data.game.length != 0u) {
            out.payload = QByteArray(
                reinterpret_cast<const char *>(out.action.data.game.payload),
                out.action.data.game.length);
            out.action.data.game.payload =
                reinterpret_cast<const uint8_t *>(out.payload.constData());
        }
    }
    return true;
}

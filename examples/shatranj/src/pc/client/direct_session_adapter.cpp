#include "direct_session_adapter.h"

#include <utility>

bool DirectSessionAdapter::init(uint8_t role, uint8_t hostColor)
{
    SessionConfig config = {};

    config.transport = SESSION_TRANSPORT_DIRECT;
    config.role = role;
    config.host_color = hostColor;
    config.session_id = 0u;
    events_.clear();
    return session_init(&state_, &config) != 0u;
}

void DirectSessionAdapter::enqueue(OwnedEvent event, bool first)
{
    /* Correlated TX/domain completions must run before external events that
       may already be queued behind the action batch which created them. */
    if (first) {
        events_.prepend(std::move(event));
    } else {
        events_.enqueue(std::move(event));
    }
}

void DirectSessionAdapter::enqueueLinkUp(uint8_t linkId)
{
    OwnedEvent owned;

    owned.event.type = SESSION_EV_LINK_UP;
    owned.event.data.link.link_id = linkId;
    enqueue(std::move(owned));
}

void DirectSessionAdapter::enqueueLinkDown(uint8_t linkId)
{
    OwnedEvent owned;

    owned.event.type = SESSION_EV_LINK_DOWN;
    owned.event.data.link.link_id = linkId;
    enqueue(std::move(owned));
}

void DirectSessionAdapter::enqueueRx(uint8_t linkId,
                                     const QByteArray &payload)
{
    OwnedEvent owned;

    if (payload.size() > SESSION_PAYLOAD_MAX) {
        return;
    }
    owned.event.type = SESSION_EV_RX;
    owned.event.data.rx.length = static_cast<uint8_t>(payload.size());
    owned.event.data.rx.route = SESSION_ROUTE_DEFAULT;
    owned.event.data.rx.flags = SESSION_RX_LIVE;
    owned.event.data.rx.link_id = linkId;
    owned.payload = payload;
    enqueue(std::move(owned));
}

void DirectSessionAdapter::enqueueLocalRequest(uint8_t request,
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

void DirectSessionAdapter::enqueueUserDecision(uint8_t requestId,
                                               uint8_t decision)
{
    OwnedEvent owned;

    owned.event.type = SESSION_EV_USER_DECISION;
    owned.event.data.user.request_id = requestId;
    owned.event.data.user.decision = decision;
    enqueue(std::move(owned));
}

void DirectSessionAdapter::enqueueTxResult(uint8_t txId, uint8_t result)
{
    OwnedEvent owned;

    owned.event.type = SESSION_EV_TX_RESULT;
    owned.event.data.tx.tx_id = txId;
    owned.event.data.tx.result = result;
    enqueue(std::move(owned), true);
}

void DirectSessionAdapter::enqueueTimeout(uint8_t timerId)
{
    OwnedEvent owned;

    owned.event.type = SESSION_EV_TIMEOUT;
    owned.event.data.timeout.timer_id = timerId;
    enqueue(std::move(owned));
}

void DirectSessionAdapter::enqueueGameResult(uint8_t deliveryId,
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

bool DirectSessionAdapter::takeNextBatch(DirectActionBatch *batch)
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
        DirectOwnedAction &out = batch->actions[i];

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

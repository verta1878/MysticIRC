#ifndef NETCHESSZX_PC_DIRECT_SESSION_ADAPTER_H
#define NETCHESSZX_PC_DIRECT_SESSION_ADAPTER_H

#include <array>

#include <QByteArray>
#include <QQueue>

extern "C" {
#include "common/session/session.h"
}

struct DirectOwnedAction {
    SessionAction action = {};
    QByteArray payload;
};

struct DirectActionBatch {
    std::array<DirectOwnedAction, SESSION_ACTION_CAPACITY> actions = {};
    uint8_t count = 0u;
};

class DirectSessionAdapter final {
public:
    bool init(uint8_t role, uint8_t hostColor);

    void enqueueLinkUp(uint8_t linkId);
    void enqueueLinkDown(uint8_t linkId);
    void enqueueRx(uint8_t linkId, const QByteArray &payload);
    void enqueueLocalRequest(uint8_t request,
                             uint16_t value = 0u,
                             const QByteArray &payload = QByteArray(),
                             uint8_t phase = SESSION_PHASE_IDLE);
    void enqueueUserDecision(uint8_t requestId, uint8_t decision);
    void enqueueTxResult(uint8_t txId, uint8_t result);
    void enqueueTimeout(uint8_t timerId);
    void enqueueGameResult(uint8_t deliveryId,
                           uint16_t value,
                           uint8_t result,
                           const QByteArray &detail = QByteArray());

    bool takeNextBatch(DirectActionBatch *batch);
    bool hasPendingEvents() const { return !events_.isEmpty(); }

private:
    struct OwnedEvent {
        SessionEvent event = {};
        QByteArray payload;
        QByteArray detail;
    };

    void enqueue(OwnedEvent event, bool first = false);

    SessionState state_ = {};
    SessionWorkspace workspace_ = {};
    uint8_t txScratch_[SESSION_PAYLOAD_MAX + 1u] = {};
    SessionAction actions_[SESSION_ACTION_CAPACITY] = {};
    QQueue<OwnedEvent> events_;
};

#endif

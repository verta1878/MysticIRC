#include "pc/client/direct_session_adapter.h"

#include <cstdio>
#include <cstring>

#include <QCoreApplication>
#include <QHostAddress>
#include <QTcpServer>
#include <QTcpSocket>

static int failures;

static void check(bool ok, const char *label)
{
    if (!ok) {
        std::printf("FAIL: %s\n", label);
        ++failures;
    }
}

static const DirectOwnedAction *findAction(const DirectActionBatch &batch,
                                           uint8_t type)
{
    for (uint8_t i = 0u; i < batch.count; ++i) {
        if (batch.actions[i].action.type == type) {
            return &batch.actions[i];
        }
    }
    return nullptr;
}

static uint8_t sendId(const DirectActionBatch &batch)
{
    const DirectOwnedAction *send = findAction(batch, SESSION_ACT_SEND);

    return send == nullptr ? 0u : send->action.data.send.tx_id;
}

struct LoopbackState {
    bool ready = false;
    bool started = false;
    bool moveAccepted = false;
    bool closed = false;
};

static bool writeFrame(QTcpSocket &socket, const QByteArray &payload)
{
    QByteArray frame = payload;

    frame.append('\n');
    if (socket.write(frame) != frame.size()) {
        return false;
    }
    socket.flush();
    return socket.bytesToWrite() == 0 || socket.waitForBytesWritten(2000);
}

static QByteArray readFrame(QTcpSocket &socket)
{
    QByteArray frame;

    if (!socket.canReadLine() && !socket.waitForReadyRead(2000)) {
        return frame;
    }
    frame = socket.readLine();
    if (!frame.endsWith('\n')) {
        return QByteArray();
    }
    frame.chop(1);
    if (frame.endsWith('\r')) {
        frame.chop(1);
    }
    return frame;
}

static bool drainAdapter(DirectSessionAdapter &adapter,
                         QTcpSocket &socket,
                         LoopbackState &state)
{
    DirectActionBatch batch;
    uint8_t transitions = 0u;

    while (adapter.takeNextBatch(&batch)) {
        if (++transitions > 16u) {
            return false;
        }
        for (uint8_t i = 0u; i < batch.count; ++i) {
            const DirectOwnedAction &owned = batch.actions[i];
            const SessionAction &action = owned.action;

            if (action.type == SESSION_ACT_SEND) {
                const bool sent = writeFrame(socket, owned.payload);

                adapter.enqueueTxResult(
                    action.data.send.tx_id,
                    sent ? SESSION_TX_OK : SESSION_TX_FAILED);
                if (!sent) {
                    return false;
                }
            } else if (action.type == SESSION_ACT_SESSION_CHANGED) {
                state.ready |= action.data.session.status ==
                    SESSION_CHANGED_READY;
                state.started |= action.data.session.status ==
                    SESSION_CHANGED_STARTED;
                state.closed |= action.data.session.status ==
                    SESSION_CHANGED_ENDED;
            } else if (action.type == SESSION_ACT_DELIVER_GAME) {
                state.moveAccepted |=
                    action.data.game.kind == SESSION_DELIVER_CONTROL_RESULT &&
                    action.data.game.value == SESSION_REQUEST_MOVE &&
                    action.data.game.delivery_id == SESSION_GAME_ACCEPTED;
            } else if (action.type == SESSION_ACT_LINK_CLOSE ||
                       action.type == SESSION_ACT_REQUEST_DECISION) {
                state.closed = true;
            } else if (action.type != SESSION_ACT_TIMER_SET &&
                       action.type != SESSION_ACT_TIMER_CANCEL &&
                       action.type != SESSION_ACT_SIDE_CHANGED) {
                return false;
            }
        }
    }
    return true;
}

static bool peerSend(QTcpSocket &peer,
                     QTcpSocket &client,
                     DirectSessionAdapter &adapter,
                     LoopbackState &state,
                     const QByteArray &payload)
{
    if (!writeFrame(peer, payload)) {
        return false;
    }
    const QByteArray received = readFrame(client);

    if (received != payload) {
        return false;
    }
    adapter.enqueueRx(1u, received);
    return drainAdapter(adapter, client, state);
}

static void testLoopbackSilentPeer()
{
    QTcpServer server;
    QTcpSocket client;
    DirectSessionAdapter adapter;
    LoopbackState state;

    if (!server.listen(QHostAddress::LocalHost, 0u)) {
        check(false, "loopback server listens");
        return;
    }
    client.connectToHost(QHostAddress::LocalHost, server.serverPort());
    if (!client.waitForConnected(2000) ||
        !server.waitForNewConnection(2000)) {
        check(false, "loopback TCP connects");
        return;
    }
    QTcpSocket *peer = server.nextPendingConnection();
    if (peer == nullptr ||
        !adapter.init(SESSION_ROLE_HOST, SESSION_COLOR_WHITE)) {
        check(false, "loopback peer and host adapter initialize");
        return;
    }

    adapter.enqueueLinkUp(1u);
    check(drainAdapter(adapter, client, state) &&
              readFrame(*peer) == QByteArray("HELLO DIRECT HOST WHITE=HOST"),
          "loopback sends host HELLO");
    check(peerSend(*peer, client, adapter, state,
                   QByteArray("HELLO DIRECT GUEST")) &&
              state.ready &&
              readFrame(*peer) == QByteArray("HELLO DIRECT HOST WHITE=HOST"),
          "loopback reaches DIRECT ready");

    adapter.enqueueLocalRequest(SESSION_REQUEST_START);
    check(drainAdapter(adapter, client, state) &&
              readFrame(*peer) == QByteArray("GAME START WHITE=HOST"),
          "loopback sends game start");
    check(peerSend(*peer, client, adapter, state,
                   QByteArray("ACK GAME START")) && state.started,
          "loopback starts game");

    adapter.enqueueLocalRequest(SESSION_REQUEST_MOVE, 0u,
                                QByteArray("d2d4"));
    check(drainAdapter(adapter, client, state) &&
              readFrame(*peer) == QByteArray("MOVE 1 d2d4"),
          "loopback sends first move");
    check(peerSend(*peer, client, adapter, state,
                   QByteArray("ACK 1 d4")) && state.moveAccepted,
          "loopback accepts first move");

    const bool clientSilent = !client.waitForReadyRead(50);
    const bool peerSilent = !peer->waitForReadyRead(50);
    check(clientSilent && peerSilent &&
              client.state() == QAbstractSocket::ConnectedState &&
              peer->state() == QAbstractSocket::ConnectedState &&
              client.bytesToWrite() == 0 && peer->bytesToWrite() == 0 &&
              !adapter.hasPendingEvents() && !state.closed,
          "loopback remains TCP connected and silent");
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    DirectSessionAdapter adapter;
    DirectActionBatch hello;
    DirectActionBatch batch;
    DirectActionBatch remoteChat;
    DirectActionBatch localChat;
    const DirectOwnedAction *action;
    const DirectOwnedAction *remoteAction;
    QByteArray bad("PING\0TAIL", 9);

    check(adapter.init(SESSION_ROLE_GUEST, SESSION_COLOR_UNKNOWN),
          "adapter init");
    adapter.enqueueLinkUp(0u);
    check(adapter.takeNextBatch(&hello), "link-up event drained");
    action = findAction(hello, SESSION_ACT_SEND);
    check(action != nullptr && action->action.data.send.link_id == 0u &&
              action->payload == QByteArray("HELLO DIRECT GUEST") &&
              std::memcmp(action->action.data.send.payload,
                          "HELLO DIRECT GUEST",
                          action->action.data.send.length) == 0,
          "directed HELLO is copied into owned batch");

    adapter.enqueueRx(0u, QByteArray("NOISE"));
    adapter.enqueueTxResult(sendId(hello), SESSION_TX_OK);
    check(adapter.takeNextBatch(&batch) &&
              findAction(batch, SESSION_ACT_TIMER_SET) != nullptr,
          "tx result precedes already-queued external RX");
    check(action != nullptr && action->payload == QByteArray("HELLO DIRECT GUEST"),
          "later step cannot overwrite earlier SEND payload");
    check(adapter.takeNextBatch(&batch) && batch.count == 0u,
          "queued RX remains behind correlated tx result");

    adapter.enqueueRx(0u, bad);
    check(adapter.takeNextBatch(&batch) && batch.count == 0u,
          "embedded NUL remains visible to reducer validation");

    adapter.enqueueRx(0u, QByteArray("HELLO DIRECT HOST WHITE=HOST"));
    check(adapter.takeNextBatch(&batch), "host HELLO event drained");
    adapter.enqueueTxResult(sendId(batch), SESSION_TX_OK);
    check(adapter.takeNextBatch(&batch), "HELLO reply result drained");

    adapter.enqueueRx(0u, QByteArray("RQ"));
    check(adapter.takeNextBatch(&batch), "restore request drained");
    action = findAction(batch, SESSION_ACT_REQUEST_DECISION);
    check(action != nullptr &&
              action->action.data.decision.control == SESSION_REQUEST_RESTORE,
          "restore request exposes typed decision");
    const uint8_t restoreRequestId = action == nullptr
        ? 0u : action->action.data.decision.request_id;
    adapter.enqueueUserDecision(restoreRequestId, SESSION_DECISION_ACCEPT);
    check(adapter.takeNextBatch(&batch) &&
              findAction(batch, SESSION_ACT_SEND) != nullptr,
          "restore decision sends RY");
    adapter.enqueueTxResult(sendId(batch), SESSION_TX_OK);
    check(adapter.takeNextBatch(&batch), "restore RY result drained");
    adapter.enqueueRx(
        0u, QByteArray("RS00 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"));
    check(adapter.takeNextBatch(&batch), "restore first chunk drained");
    adapter.enqueueRx(
        0u, QByteArray("RS01 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"));
    check(adapter.takeNextBatch(&batch), "restore second chunk drained");
    action = findAction(batch, SESSION_ACT_DELIVER_GAME);
    check(action != nullptr &&
              action->action.data.game.kind == SESSION_DELIVER_RESTORE &&
              action->payload.size() == SESSION_RESTORE_BYTES,
          "restore snapshot is copied into owned batch");
    const uint8_t restoreDeliveryId = action == nullptr
        ? 0u : action->action.data.game.delivery_id;
    adapter.enqueueGameResult(
        restoreDeliveryId, 7u, SESSION_GAME_ACCEPTED,
        QByteArray(1, static_cast<char>(SESSION_PHASE_ACTIVE)));
    check(adapter.takeNextBatch(&batch) &&
              findAction(batch, SESSION_ACT_SEND) != nullptr,
          "restore phase and ply produce RA");
    action = findAction(batch, SESSION_ACT_SEND);
    check(action != nullptr && action->payload == QByteArray("RA"),
          "restore apply acknowledgement is owned");
    adapter.enqueueTxResult(sendId(batch), SESSION_TX_OK);
    check(adapter.takeNextBatch(&batch), "restore RA result drained");

    adapter.enqueueLocalRequest(SESSION_REQUEST_MOVE, 0u,
                                QByteArray("e2e4"));
    check(adapter.takeNextBatch(&batch), "post-restore move drained");
    action = findAction(batch, SESSION_ACT_SEND);
    check(action != nullptr && action->payload == QByteArray("MOVE 8 e2e4"),
          "restored phase and ply drive next move");
    adapter.enqueueTxResult(sendId(batch), SESSION_TX_OK);
    check(adapter.takeNextBatch(&batch), "post-restore move handoff drained");
    adapter.enqueueRx(0u, QByteArray("ACK 8"));
    check(adapter.takeNextBatch(&batch), "post-restore move ACK drained");

    adapter.enqueueRx(0u, QByteArray("CHAT hi"));
    check(adapter.takeNextBatch(&remoteChat), "temporary RX event drained");
    remoteAction = findAction(remoteChat, SESSION_ACT_DELIVER_GAME);
    check(remoteAction != nullptr && remoteAction->payload == QByteArray("hi") &&
              remoteAction->action.data.game.value == SESSION_CHAT_REMOTE &&
              std::memcmp(remoteAction->action.data.game.payload, "hi", 2u) == 0,
          "borrowed DELIVER payload and origin are copied");

    adapter.enqueueLocalRequest(SESSION_REQUEST_CHAT, 0u, QByteArray("yo"));
    check(adapter.takeNextBatch(&batch) &&
              findAction(batch, SESSION_ACT_SEND) != nullptr,
          "local CHAT send is exposed");
    adapter.enqueueTxResult(sendId(batch), SESSION_TX_OK);
    check(adapter.takeNextBatch(&localChat), "local CHAT result drained");
    action = findAction(localChat, SESSION_ACT_DELIVER_GAME);
    check(action != nullptr && action->payload == QByteArray("yo") &&
              action->action.data.game.value == SESSION_CHAT_LOCAL &&
              std::memcmp(action->action.data.game.payload, "yo", 2u) == 0,
          "workspace DELIVER payload and local origin are copied");

    adapter.enqueueLinkDown(0u);
    check(adapter.takeNextBatch(&hello) &&
              findAction(hello, SESSION_ACT_SESSION_CHANGED) != nullptr,
          "link-down translates to ended action");
    check(remoteAction != nullptr && remoteAction->payload == QByteArray("hi") &&
              action != nullptr && action->payload == QByteArray("yo"),
          "later steps cannot invalidate copied DELIVER payloads");

    testLoopbackSilentPeer();

    if (failures != 0) {
        std::printf("PC direct adapter tests failed: %d\n", failures);
        return 1;
    }
    std::printf("PC direct adapter tests ok\n");
    return 0;
}

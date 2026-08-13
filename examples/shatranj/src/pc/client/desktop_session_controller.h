#ifndef DESKTOP_SESSION_CONTROLLER_H
#define DESKTOP_SESSION_CONTROLLER_H

#include "direct_session_adapter.h"
#include "mqtt_session_adapter.h"

#include <array>
#include <cstdint>
#include <functional>

#include <QObject>
#include <QTimer>
#include <QVector>

struct DesktopSessionFollowup {
    uint8_t type = 0u;
    uint8_t id = 0u;
    uint8_t result = 0u;
    uint16_t value = 0u;
    QByteArray detail;
};

class DesktopSessionController final : public QObject {
public:
    enum class Mode {
        Direct,
        Mqtt,
    };

    struct Callbacks {
        std::function<bool(Mode, const SessionAction &, const QByteArray &)> send;
        std::function<bool()> mqttTransportReady;
        std::function<void(Mode, uint8_t)> closeLink;
        std::function<void(uint8_t, uint8_t, uint16_t)> decision;
        std::function<void(Mode, uint8_t, uint8_t, uint16_t,
                           const QByteArray &, QVector<DesktopSessionFollowup> &)> game;
        std::function<void(uint8_t)> sessionChanged;
        std::function<void(Mode, uint8_t, uint16_t)> sideChanged;
        std::function<void(const QString &)> error;
    };

    explicit DesktopSessionController(QObject *parent = nullptr);

    void setCallbacks(Callbacks callbacks);
    bool initializeDirect(uint8_t role, uint8_t hostColor);
    bool initializeMqtt(uint8_t role, uint8_t hostColor, uint16_t sessionId);
    void stop();
    bool initialized() const { return initialized_; }
    Mode mode() const { return mode_; }

    bool linkUp(uint8_t linkId);
    bool linkDown(uint8_t linkId);
    void receiveDirect(uint8_t linkId, const QByteArray &payload);
    bool receiveMqtt(uint8_t linkId, const QByteArray &topic, bool retained,
                     const QByteArray &payload);
    void txResult(uint8_t txId, uint8_t result);

    bool submitLocalRequest(uint8_t request,
                            uint16_t value = 0u,
                            const QByteArray &payload = QByteArray(),
                            uint8_t phase = SESSION_PHASE_IDLE);
    void submitUserDecision(uint8_t requestId, uint8_t decision);
    void submitGameResult(uint8_t deliveryId,
                          uint16_t value,
                          uint8_t result,
                          const QByteArray &detail = QByteArray());

    QByteArray mqttTopicSuffixForRoute(uint8_t route) const;
    bool pump();

private:
    void cancelTimer(uint8_t timerId);
    void setTimer(uint8_t timerId, uint16_t durationTicks);
    void stopTimers();
    void dispatch(const SessionAction &action, const QByteArray &payload,
                  QVector<DesktopSessionFollowup> &followups);
    void applyFollowups(const QVector<DesktopSessionFollowup> &followups);
    bool dispatchMqttBatch(const MqttActionBatch &batch,
                           uint8_t *next,
                           QVector<DesktopSessionFollowup> &followups,
                           uint32_t generation);
    void clearDeferredMqttActions();
    void invalidateDeferredMqttActions();

    DirectSessionAdapter direct_;
    MqttSessionAdapter mqtt_;
    Callbacks callbacks_;
    std::array<QTimer *, SESSION_TIMER_COUNT> timers_ = {};
    std::array<quint32, SESSION_TIMER_COUNT> timerGeneration_ = {};
    MqttActionBatch deferredMqttBatch_ = {};
    QVector<DesktopSessionFollowup> deferredMqttFollowups_;
    uint8_t deferredMqttNext_ = 0u;
    bool mqttBatchDeferred_ = false;
    uint32_t mqttDispatchGeneration_ = 0u;
    Mode mode_ = Mode::Direct;
    bool initialized_ = false;
    bool pumping_ = false;
};

#endif // DESKTOP_SESSION_CONTROLLER_H
